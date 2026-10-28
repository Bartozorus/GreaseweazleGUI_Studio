# ============================== FONCTIONS : QUALITE ET ALIGNEMENT ==============

# ============================== ALIGNEMENT : LOGIQUE ===========================
function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger, [switch]$NoIndexZone) {
    # cellsPerRev > 0 : motif de test connu (calibration) ; la cellule vaut alors duree du tour / nombre de cellules,
    # au lieu de la mediane des intervalles de deux cellules, qui derive quand le decalage residuel est grand.
    # 12.8.2 (S10 a S12) : hors calibration, post-traitement de chaque piste (Set-ScpTrackPost) : premier intervalle de
    # la lecture et zone de l index non comptes, stabilite sur tours alignes ; la calibration (cellsPerRev > 0) garde
    # le comptage d avant (courbes inchangees). -NoIndexZone : index synthetique connu de l appelant (--fake-index) :
    # zone de l index comptee comme le reste de la piste ; de meme pour un SCP non cale sur l index (en-tete, bit 0 des
    # drapeaux, comme gw : image/scp.py) et pour des tours plus courts qu une rotation (secteurs durs lus comme des
    # index : Set-ScpTrackPost, ScpIdxMinRevNs). Revue 12.8.2 : echec du post-traitement d une piste (comptage d avant
    # pour cette piste) : une ligne de journal par fichier, avec le premier message.
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $zone = (-not $NoIndexZone) -and ((($d[8] -band 1) -eq 1) -or $revs -eq 1)
    $script:ScpPostFail = @{ N = 0; Msg = '' }
    $tracks = @{}
    for ($t = 0; $t -lt 168; $t++) {
        $o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0) { continue }
        $tn = $d[$o + 3]; $list = @()
        $fl = New-Object 'System.Collections.Generic.List[int[]]'
        for ($r = 0; $r -lt $revs; $r++) {
            $idx  = [BitConverter]::ToUInt32($d, $o + 4 + 12 * $r)
            $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
            $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
            $flux = [ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res)
            $fl.Add($flux)
            $list += [ScpStats]::Analyze($flux, [double]$idx * $res, $cellsPerRev)
        }
        # Stabilite d un tour a l autre (zones instables : bits faibles d une protection, defaut localise) et, sur
        # demande, empreinte de la piste ; pas pour la calibration (motif connu, une passe par valeur de precomp)
        # Double densite seulement (cellule de 1,7 a 2,3 us, long tracks compris) : en haute densite, la cellule estimee
        # sur les intervalles de 3 a 5 us est fausse et les classes aussi
        if ($cellsPerRev -le 0 -and $list.Count -gt 0 -and -not [double]::IsNaN($list[0].Cell) -and $list[0].Cell -ge 1700 -and $list[0].Cell -le 2300) {
            $ins = [ScpStats]::Instability($fl, [double]$list[0].Cell)
            $list[0].Blocks = $ins[0]; $list[0].Unstable = $ins[1]; $list[0].MaxRun = $ins[2]; $list[0].RunPos = $ins[3]
            if ($Finger) { $list[0].Finger = [ScpStats]::Fingerprint($fl[0], [double]$list[0].Cell, 8); $list[0].Rich = [ScpStats]::RichCount($fl[0], [double]$list[0].Cell) }
        }
        if ($cellsPerRev -le 0 -and $list.Count -gt 0) { Set-ScpTrackPost $fl $list $zone }
        $tracks[[int]$tn] = $list
    }
    if ($script:ScpPostFail.N -gt 0) {
        Append-Log ((T "Analyse SCP : calcul 12.8.2 des erreurs et de la stabilité en échec sur {0} piste(s), jugée(s) comme dans les versions précédentes : {1}") -f "$($script:ScpPostFail.N)", "$($script:ScpPostFail.Msg)")
    }
    return $tracks
}

function Read-ScpTrackFlux([string]$path, [int]$tn) {
    # Flux brut de chaque tour d une piste d un SCP (sonde de la restauration en flux)
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
    $fl = New-Object 'System.Collections.Generic.List[int[]]'
    if ($tn -lt 0 -or $tn -ge 168) { return ,$fl }
    $o = [BitConverter]::ToUInt32($d, 16 + 4 * $tn)
    if ($o -eq 0) { return ,$fl }
    for ($r = 0; $r -lt $revs; $r++) {
        $ln   = [BitConverter]::ToUInt32($d, $o + 8 + 12 * $r)
        $doff = [BitConverter]::ToUInt32($d, $o + 12 + 12 * $r)
        $fl.Add([ScpStats]::Decode($d, [int]($o + $doff), [int]$ln, $res))
    }
    return ,$fl
}

# --- 12.8.2 (S10 a S12) : premier intervalle, zone de l index, stabilite sur tours alignes ----------------------------
# Post-traitement en PowerShell des tours lus par Read-ScpFile (le C# de 030 n est pas modifie) : classes des seuls
# segments utiles (ScpStats.Classes, meme regle que Analyze), sommes de flux en code natif (Linq), aucune boucle
# PowerShell sur tous les intervalles d une piste. Constantes : 040 (ScpIdxZoneNs, ScpIdxMinRevNs, ScpPostWin,
# ScpRevWin, ScpZoneWin, ScpAnchor).
function Get-ScpClassText($flux, [int]$start, [int]$len, [double]$cell, [int]$start2 = 0, [int]$len2 = 0) {
    # Classes de $flux[$start .. $start + $len - 1], suivies de celles de $flux[$start2 .. $start2 + $len2 - 1] : '2' a
    # '5', 'x' hors classe ou trou (ScpStats.Classes, une seule fois pour les deux segments)
    if ($len2 -le 0 -and $start -eq 0 -and $len -eq $flux.Length) { return [ScpStats]::Classes($flux, $cell) }
    $seg = [int[]]::new($len + [math]::Max(0, $len2))
    [Array]::Copy($flux, $start, $seg, 0, $len)
    if ($len2 -gt 0) { [Array]::Copy($flux, $start2, $seg, $len, $len2) }
    return [ScpStats]::Classes($seg, $cell)
}

function Get-ScpEdgeClasses($f, [double]$cell, [int]$k) {
    # Classes des $k premiers et des $k derniers intervalles d un tour : @(debut, fin, indice du premier intervalle de la
    # fin, tour entier). Tour entier si le tour est court, ou si les ScpZoneWin intervalles d un bout ($k >= ScpZoneWin)
    # durent moins de ScpIdxZoneNs (intervalles tres courts : la zone de l index doit etre couverte)
    $n = $f.Length; $zw = [int]$script:ScpZoneWin
    if ($n -le 2 * $k -or [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, 0, $zw)) -lt $script:ScpIdxZoneNs -or
        [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, $n - $zw + 1, $zw - 1)) -lt $script:ScpIdxZoneNs) {
        $s = Get-ScpClassText $f 0 $n $cell
        return @($s, $s, 0, $true)
    }
    $s = Get-ScpClassText $f 0 $k $cell ($n - $k) $k
    return @($s.Substring(0, $k), $s.Substring($k), ($n - $k), $false)
}

function Get-ScpZoneOoc($f, [string]$hs, [string]$ts, [int]$to, [int]$first) {
    # S11 : intervalles hors classe (pas les trous) qui commencent a moins de ScpIdxZoneNs de l index (debut du tour, a
    # partir de l intervalle $first) ou qui finissent a moins de ScpIdxZoneNs de l index suivant (fin du tour : apres
    # T - ScpIdxZoneNs). $hs : classes du debut du tour, $ts : de la fin, dont le premier intervalle a l indice $to.
    # Revue 12.8.2 : par bout, ecartes seulement s ils forment une seule grappe (raccord d ecriture) : ScpIdxClusterMax
    # intervalles au plus, du debut du premier a la fin du dernier en ScpIdxClusterNs au plus ; sinon aucun (defaut du
    # support a l index : compte). Verification du 27/10/2026 : une grappe qui se prolonge au-dela de la zone (hors classe
    # hors zone a ScpIdxClusterNs au plus de la fin de la grappe) fait compter le bout ; grappes aux deux bouts du tour (de
    # part et d autre de l index) : ScpIdxClusterMax intervalles au plus au total et distances a l index (bout le plus
    # lointain de chaque grappe) de ScpIdxClusterNs au plus en somme, sinon les deux bouts sont comptes. Rend @(hors classe
    # ecartes, distance a l index du bout le plus lointain d une grappe ecartee, en ns). Seuls les intervalles hors classe
    # sont visites, et pas au-dela d une grappe impossible ni de ScpIdxZoneNs + ScpIdxClusterNs ; durees cumulees entre
    # deux d entre eux en code natif.
    $zn = $script:ScpIdxZoneNs; $cn = $script:ScpIdxClusterNs; $cm = [int]$script:ScpIdxClusterMax; $n = $f.Length
    $z = 0; $far = 0
    # Debut du tour : $cum = debut de l intervalle $p ; grappe de $t0 (debut du premier) a $t1 (fin du dernier)
    $p = $hs.IndexOf([char]'x', $first); $last = 0; $cum = 0; $c = 0; $t0 = -1; $t1 = 0; $ok = $true
    while ($p -ge 0) {
        if ($p -gt $last) { $cum += [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, $last, $p - $last)) }
        $last = $p
        if ($cum -ge $zn) {
            if ($c -gt 0 -and $f[$p] -lt 20000 -and $cum - $t1 -le $cn) { $ok = $false }
            if (-not $ok -or $c -eq 0 -or $cum -ge $zn + $cn) { break }
        } elseif ($f[$p] -lt 20000) {
            $c++; if ($t0 -lt 0) { $t0 = $cum }; $t1 = $cum + $f[$p]
            if ($c -gt $cm -or $t1 - $t0 -gt $cn) { $ok = $false; break }
        }
        $p = $hs.IndexOf([char]'x', $p + 1)
    }
    $hc = $c; $hf = $t1; $hok = $ok
    # Fin du tour : $tail = duree de la fin de l intervalle $a a la fin du tour ; grappe de $u0 a $u1 avant l index
    $q = $ts.LastIndexOf([char]'x'); $hi = $n; $tail = 0; $c = 0; $u0 = -1; $u1 = 0; $ok = $true
    while ($q -ge 0) {
        $a = $to + $q
        if ($hi - $a - 1 -gt 0) { $tail += [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, $a + 1, $hi - $a - 1)) }
        $hi = $a + 1
        if ($tail -ge $zn) {
            if ($c -gt 0 -and $f[$a] -lt 20000 -and $a -ge $first -and $tail - $u1 -le $cn) { $ok = $false }
            if (-not $ok -or $c -eq 0 -or $tail -ge $zn + $cn) { break }
        } elseif ($f[$a] -lt 20000 -and $a -ge $first) {
            $c++; if ($u0 -lt 0) { $u0 = $tail }; $u1 = $tail + $f[$a]
            if ($c -gt $cm -or $u1 - $u0 -gt $cn) { $ok = $false; break }
        }
        if ($q -eq 0) { break }
        $q = $ts.LastIndexOf([char]'x', $q - 1)
    }
    if ($hok -and $ok -and $hc -gt 0 -and $c -gt 0 -and ($hc + $c -gt $cm -or $hf + $u1 -gt $cn)) { $hok = $false; $ok = $false }
    if ($hok -and $hc -gt 0) { $z += $hc; $far = $hf }
    if ($ok -and $c -gt 0) { $z += $c; $far = [math]::Max($far, $u1) }
    return @($z, $far)
}

function Get-ScpZoneEnd($f, [bool]$head, [int]$lim) {
    # Limite de la zone de l index d un tour, par dichotomie (sommes en code natif). Debut : nombre d intervalles qui
    # commencent avant ScpIdxZoneNs, au plus $lim (classes connues) ; fin : indice du premier intervalle qui finit apres
    # T - ScpIdxZoneNs, au moins $n - $lim.
    $n = $f.Length; $zn = $script:ScpIdxZoneNs
    if ($head) {
        $lo = 0; $hi = [math]::Min($n, $lim)
        while ($lo -lt $hi) {
            $mid = [int][math]::Floor(($lo + $hi) / 2)
            if ([System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, 0, $mid)) -ge $zn) { $hi = $mid } else { $lo = $mid + 1 }
        }
        return $lo
    }
    $lo = [math]::Max(0, $n - $lim); $hi = $n
    while ($lo -lt $hi) {
        $mid = [int][math]::Ceiling(($lo + $hi) / 2)
        if ([System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f, $mid, $n - $mid)) -ge $zn) { $lo = $mid } else { $hi = $mid - 1 }
    }
    return $lo
}

function Test-ScpZoneData($f0, [string]$hs, [string]$ts, [int]$to, [double]$cell) {
    # Revue 12.8.2 : zone de l index du tour 0 qui contient des donnees (le raccord n y est pas : image IPF, bloc WRSP,
    # original non cale sur l index ou ecrit par un Amiga, index simule) : un bloc de Len intervalles entierement dans la
    # zone, sans hors classe, au motif varie (aucune classe sur plus de 80 % du bloc) et present une seule fois a
    # +/- Win2 (critere des ancres, Find-ScpAnchor), dont les deux moities sont aussi uniques : un bloc a cheval sur la
    # rupture de phase d un remplissage periodique (gap 4E coupe par le raccord) a une moitie periodique. Vide (2T),
    # remplissage periodique et raccord : faux ; debut d un secteur (synchro et en-tete) ou secteur coupe : vrai. Suites
    # de 2T sautees d un coup ; pas de ZoneStep apres un bloc trop uniforme ou dont une moitie se repete, de Len / 2 apres
    # un motif periodique ; ZoneTries blocs au plus par bout. $hs, $ts, $to : classes des bouts du tour 0
    # (Get-ScpEdgeClasses) ; $cell : cellule du tour 0. Verification du 27/10/2026 : sans bloc retenu, synchro MFM pres de
    # l index (Test-ScpZoneSync) : un defaut dans le seul bloc riche de la zone, ou un secteur a donnees uniformes (zeros :
    # suites de 2T) a cheval sur l index, ne font plus prendre la zone pour du vide.
    $A = $script:ScpAnchor; $L = [int]$A.Len; $W2 = [int]$A.Win2; $mx = [math]::Floor(0.8 * $L); $h = [int]($L / 2)
    $ord = [System.StringComparison]::Ordinal; $chars = [char[]]'345x'; $cs = @('2', '3', '4', '5')
    foreach ($head in $true, $false) {
        # Zone [$za, $zb) dans $s (noms distincts de $A : PowerShell ne distingue pas la casse)
        if ($head) { $s = $hs; $za = 0; $zb = Get-ScpZoneEnd $f0 $true $hs.Length }
        else { $s = $ts; $za = (Get-ScpZoneEnd $f0 $false $ts.Length) - $to; $zb = $ts.Length }
        $p = $za; $tries = 0
        while ($tries -lt [int]$A.ZoneTries -and $p + $L -le $zb) {
            $p = $s.IndexOfAny($chars, $p)
            if ($p -lt 0 -or $p + $L -gt $zb) { break }
            $tries++
            $blk = $s.Substring($p, $L)
            $ix = $blk.LastIndexOf([char]'x')
            if ($ix -ge 0) { $p += $ix + 1; continue }
            $ok = $true
            foreach ($c in $cs) { if ($L - $blk.Replace($c, '').Length -gt $mx) { $ok = $false; break } }
            if (-not $ok) { $p += [int]$A.ZoneStep; continue }
            $lo = [math]::Max(0, $p - $W2); $hi = [math]::Min($s.Length, $p + $L + $W2)
            if ($s.IndexOf($blk, $lo, $hi - $lo, $ord) -eq $p -and $s.IndexOf($blk, $p + 1, $hi - $p - 1, $ord) -lt 0) {
                $u = $true
                foreach ($o in 0, $h) {
                    $hb = $blk.Substring($o, $h); $q = $p + $o
                    $lo = [math]::Max(0, $q - $W2); $hi = [math]::Min($s.Length, $q + $h + $W2)
                    if ($s.IndexOf($hb, $lo, $hi - $lo, $ord) -ne $q -or $s.IndexOf($hb, $q + 1, $hi - $q - 1, $ord) -ge 0) { $u = $false; break }
                }
                if ($u) { return $true }
                $p += [int]$A.ZoneStep
            } else { $p += $h }
        }
    }
    return (Test-ScpZoneSync $f0 $hs $ts $to $cell)
}

function Test-ScpZoneSync($f0, [string]$hs, [string]$ts, [int]$to, [double]$cell) {
    # Verification du 27/10/2026 : le tour 0 contient-il une double synchro MFM 0x4489 (classes ScpIdxSync) qui commence a
    # moins de ScpIdxZoneNs apres l index (debut du tour, a partir de l intervalle 1) ou a moins de ScpIdxSyncBeforeNs de
    # la fin du tour 0 (secteur a cheval sur l index) ? Seule la premiere synchro du debut et la derniere de la fin sont
    # jugees (les plus proches de l index). Fin du tour 0 classee sur moins de ScpIdxSyncBeforeNs (suites de 2T) et sans
    # synchro : ScpRevWin intervalles de plus avant elle (tout le debut du tour au besoin), raccordes a ses classes.
    # Recherches par les surcharges a quatre arguments (chaine, debut, longueur, Ordinal) : une seule candidate en 5.1.
    $sy = [string]$script:ScpIdxSync; $bn = $script:ScpIdxSyncBeforeNs; $n = $f0.Length; $ord = [System.StringComparison]::Ordinal
    $p = $hs.IndexOf($sy, 1, $hs.Length - 1, $ord)
    if ($p -ge 1 -and [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, 0, $p)) -lt $script:ScpIdxZoneNs) { return $true }
    $q = $ts.LastIndexOf($sy, $ts.Length - 1, $ts.Length, $ord)
    if ($q -ge 0) { return ([System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, $to + $q, $n - $to - $q)) -lt $bn) }
    if ($to -le 0 -or [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, $to, $n - $to)) -ge $bn) { return $false }
    $s0 = [math]::Max(0, $to - [int]$script:ScpRevWin)
    if ($s0 -gt 0 -and [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, $s0, $n - $s0)) -lt $bn) { $s0 = 0 }
    $e0 = [math]::Min($n, $to + $sy.Length - 1)
    $seg = Get-ScpClassText $f0 $s0 ($e0 - $s0) $cell
    $q = $seg.LastIndexOf($sy, $seg.Length - 1, $seg.Length, $ord)
    return ($q -ge 0 -and [System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, $s0 + $q, $n - $s0 - $q)) -lt $bn)
}

function Find-ScpAnchor($fl, $list, $edges, [string]$s, [int]$to, [bool]$head, [int]$minAbs) {
    # S12 : ancre du tour 0 et sa position dans chaque tour ; tableau des positions absolues, ou $null.
    #  Candidats du tour 0, dans l ordre ($s : classes du debut du tour 0 pour A, de la fin pour B, premier intervalle
    #  d indice $to) : A, premiers blocs de Len intervalles qui commencent apres ScpIdxZoneNs ; B, derniers blocs qui
    #  finissent avant T - ScpIdxZoneNs et commencent apres $minAbs (fin de A). Bloc retenu : aucun intervalle hors
    #  classe ni trou, motif varie (aucune classe sur plus de 80 % du bloc, comme le bloc « riche » de
    #  ScpStats.Instability), une seule fois a +/- Win2 dans le tour 0. Suites de 2T (vide, remplissage) sautees d un
    #  coup ; apres un refus, bloc suivant ; Tries positions et Cand candidats au plus.
    #  Chaque candidat est cherche par sa suite exacte de classes dans chaque tour, autour de la position attendue
    #  (position au tour precedent, plus la derive des deux tours precedents : index synthetique), a +/- Win puis a
    #  +/- Win2, sur les classes du seul segment cherche (prises dans les bouts du tour deja classes, $edges, ou classees
    #  a part) ; retenu s il y est une seule fois dans tous les tours. Revue 12.8.2 : trouve a plus de Win de sa position
    #  attendue dans un tour (derive d un index simule), le bloc doit aussi etre unique dans le tour 0 sur la fenetre
    #  elargie de cet ecart : sinon un double du bloc, pris pour lui dans un tour ou il est abime, fausserait AB ou BA.
    $A = $script:ScpAnchor; $L = [int]$A.Len; $W = [int]$A.Win; $W2 = [int]$A.Win2; $mx = [math]::Floor(0.8 * $L)
    $ord = [System.StringComparison]::Ordinal; $chars = [char[]]'345x'; $cs = @('2', '3', '4', '5')
    $f0 = $fl[0]; $n0 = $f0.Length; $nr = $fl.Count; $zn = $script:ScpIdxZoneNs
    $zl = [int][math]::Ceiling($zn / [math]::Floor(1.65 * [double]$list[0].Cell))
    if ($head) { $p = $zl } else { $e = $s.Length - 1 - $zl }
    $tries = 0; $cand = 0
    while ($tries -lt $A.Tries -and $cand -lt $A.Cand) {
        if ($head) {
            if ($p -ge $s.Length) { break }
            $p = $s.IndexOfAny($chars, $p)
            if ($p -lt 0 -or $p + $L + $W -gt $s.Length) { break }
        } else {
            if ($e -lt 0) { break }
            $e = $s.LastIndexOfAny($chars, $e)
            $p = $e - $L + 1
            if ($e -lt 0 -or $p - $W -lt 0 -or $to + $p -lt $minAbs) { break }
        }
        $tries++
        $b = $s.Substring($p, $L)
        if ($head) { $ix = $b.IndexOf([char]'x'); if ($ix -ge 0) { $p = $p + $ix + 1; continue } }
        else { $ix = $b.LastIndexOf([char]'x'); if ($ix -ge 0) { $e = $p + $ix - 1; continue } }
        $ok = $true
        foreach ($c in $cs) { if ($L - $b.Replace($c, '').Length -gt $mx) { $ok = $false; break } }
        if ($ok) {
            $lo = [math]::Max(0, $p - $W2); $hi = [math]::Min($s.Length, $p + $L + $W2)
            $ok = ($s.IndexOf($b, $lo, $hi - $lo, $ord) -eq $p -and $s.IndexOf($b, $p + 1, $hi - $p - 1, $ord) -lt 0)
        }
        $abs = $to + $p
        if ($ok) {
            if ($head) { $ok = ([System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, 0, $abs)) -ge $zn) }
            else { $ok = ([System.Linq.Enumerable]::Sum([System.ArraySegment[int]]::new($f0, $abs + $L, $n0 - $abs - $L)) -ge $zn) }
        }
        if (-not $ok) { if ($head) { $p += $L } else { $e -= $L }; continue }
        # Candidat retenu : position dans les autres tours
        $cand++
        $pos = [int[]]::new($nr); $pos[0] = $abs; $dev = 0
        for ($r = 1; $r -lt $nr -and $ok; $r++) {
            $f = $fl[$r]
            $ex = $pos[$r - 1]; if ($r -ge 2) { $ex += $pos[$r - 1] - $pos[$r - 2] }
            $lo = [math]::Max(0, $ex - $W2); $hi = [math]::Min($f.Length, $ex + $L + $W2)
            $q = -1
            if ($hi - $lo -ge $L) {
                $ed = $edges[$r]; $eh = [string]$ed[0]; $et = [string]$ed[1]; $eo = [int]$ed[2]
                if ($hi -le $eh.Length) { $seg = $eh.Substring($lo, $hi - $lo) }
                elseif ($lo -ge $eo) { $seg = $et.Substring($lo - $eo, $hi - $lo) }
                else { $seg = Get-ScpClassText $f $lo ($hi - $lo) ([double]$list[$r].Cell) }
                $a1 =[math]::Max(0, $ex - $W - $lo); $b1 = [math]::Min($seg.Length, $ex + $L + $W - $lo)
                if ($b1 - $a1 -ge $L) {
                    $q = $seg.IndexOf($b, $a1, $b1 - $a1, $ord)
                    if ($q -ge 0 -and $seg.IndexOf($b, $q + 1, $b1 - $q - 1, $ord) -ge 0) { $q = -2 }
                }
                if ($q -eq -1) {
                    $q = $seg.IndexOf($b, $ord)
                    if ($q -ge 0 -and $seg.IndexOf($b, $q + 1, $ord) -ge 0) { $q = -2 }
                }
            }
            if ($q -lt 0) { $ok = $false } else { $pos[$r] = $lo + $q; $dev = [math]::Max($dev, [math]::Abs($pos[$r] - $ex)) }
        }
        if ($ok -and $dev -gt $W) {
            $lo = [math]::Max(0, $p - $W2 - $dev); $hi = [math]::Min($s.Length, $p + $L + $W2 + $dev)
            $ok = ($s.IndexOf($b, $lo, $hi - $lo, $ord) -eq $p -and $s.IndexOf($b, $p + 1, $hi - $p - 1, $ord) -lt 0)
        }
        if ($ok) { return ,$pos }
        if ($head) { $p += $L } else { $e = $p - 1 }
    }
    return $null
}

function Set-ScpTrackPost($fl, $list, [bool]$zone) {
    # Post-traitement d une piste lue par Read-ScpFile hors calibration. $fl : flux de chaque tour ; $list : ScpRev de
    # chaque tour (Analyze) ; $zone : index reel, cale par gw (S11 permise). Pistes illisibles (jitter non mesure) : rien.
    #  S10 : le premier intervalle du tour 0, tronque par gw (flux.py, cue_at_index), n est pas compte hors classe ; un
    #        premier intervalle de 20 us ou plus reste un trou (verification du 27/10/2026 : gw le tronque, c est un vrai
    #        trou d au moins 20 us). NFlux ne change pas.
    #  S11 : hors classe a moins de ScpIdxZoneNs d un index (Get-ScpZoneOoc), non comptes : jonction d ecriture de gw,
    #        dans l espace entre le dernier et le premier secteur ; trous comptes partout. Double densite (cellule de 1,7
    #        a 2,3 us, classes justes ; verification : et hors classe du tour 0 au plus 5 % des flux, sinon haute densite a
    #        cellule mal estimee ou piste critique de toute facon), tours d au moins ScpIdxMinRevNs (un index par
    #        rotation). Revue 12.8.2 : pas si la zone du tour 0 contient des donnees (Test-ScpZoneData, synchro MFM
    #        comprise) ; par tour et par bout, une seule grappe ecartee.
    #  S12 : stabilite sur tours alignes : ancres A (debut du corps de piste) et B (fin) du tour 0, retrouvees dans chaque
    #        tour (Find-ScpAnchor ; bouts du tour 0, puis tout le tour 0 si aucun couple n y est trouve). StabAl =
    #        max(ecart des comptes de flux de A a B des tours, ecart des comptes de B a A du tour suivant, a travers
    #        l index) : un deplacement de l index ne change aucun compte. Au moins 3 tours (2 : un seul compte de B a A)
    #        d au moins ScpIdxMinRevNs, double densite ; ancre introuvable ou ambigue dans un tour : StabAl -1, Stab
    #        d avant (NFlux) ; Tried : alignement tente (repli signale au journal par l appelant).
    # Ecrit OutOfClass des tours et ajoute au tour 0 la propriete Post = @{ ZoneOoc (hors classe ecartes, tous tours) ;
    # ZoneFarNs (distance a l index de la grappe ecartee la plus lointaine) ; First ('ooc' ou '') ;
    # StabAl ; Tried ; Zone (S11 appliquee) ; ZoneData (zone avec des donnees : S11 non appliquee) ; PA ; PB (positions
    # des ancres) }. Toute erreur : piste laissee au comptage d avant, comptee dans ScpPostFail (journal : Read-ScpFile).
    $nr = $list.Count
    if ($nr -eq 0 -or $fl.Count -ne $nr -or $fl[0].Length -eq 0) { return }
    foreach ($x in $list) { if ([double]::IsNaN([double]$x.Jitter)) { return } }
    $post = @{ ZoneOoc = 0; ZoneFarNs = 0; First = ''; StabAl = -1; Tried = $false; Zone = $false; ZoneData = $false; PA = $null; PB = $null }
    $dOoc = [int[]]::new($nr)
    try {
        $c0 = [double]$list[0].Cell; $v = $fl[0][0]
        if ($v -lt 20000) {
            $q = $v / $c0; $k = [math]::Round($q)
            if ([math]::Abs($q - $k) -gt 0.35 -or $k -lt 2 -or $k -gt 5) { $dOoc[0] = 1; $post.First = 'ooc' }
        }
        if ($c0 -ge 1700 -and $c0 -le 2300 -and 20 * [int]$list[0].OutOfClass -le [int]$list[0].NFlux) {
            # Classes des bouts de chaque tour : ScpPostWin intervalles au tour 0 (ancres), ScpRevWin aux autres (zone de
            # l index et recherche des ancres)
            $edges = New-Object object[] $nr
            for ($r = 0; $r -lt $nr; $r++) { $edges[$r] = Get-ScpEdgeClasses $fl[$r] ([double]$list[$r].Cell) $(if ($r -eq 0) { [int]$script:ScpPostWin } else { [int]$script:ScpRevWin }) }
            $e0 = $edges[0]
            $hs0 = [string]$e0[0]; $ts0 = [string]$e0[1]; $to0 = [int]$e0[2]; $full0 = [bool]$e0[3]
            # Un index par rotation (secteurs durs lus sans --hard-sectors : plusieurs) : zone de l index et tours alignes
            $oneIdx = $true
            foreach ($x in $list) { if ([double]$x.IndexMs * 1e6 -lt $script:ScpIdxMinRevNs) { $oneIdx = $false } }
            if ($zone -and $oneIdx) {
                if (Test-ScpZoneData $fl[0] $hs0 $ts0 $to0 $c0) { $post.ZoneData = $true }
                else {
                    $post.Zone = $true
                    for ($r = 0; $r -lt $nr; $r++) {
                        $e = $edges[$r]
                        $z = Get-ScpZoneOoc $fl[$r] ([string]$e[0]) ([string]$e[1]) ([int]$e[2]) $(if ($r -eq 0) { 1 } else { 0 })
                        $dOoc[$r] += [int]$z[0]; $post.ZoneOoc += [int]$z[0]
                        if ([int]$z[1] -gt $post.ZoneFarNs) { $post.ZoneFarNs = [int]$z[1] }
                    }
                }
            }
            if ($nr -ge 3 -and $oneIdx) {
                $post.Tried = $true
                $L = [int]$script:ScpAnchor.Len; $pa = $null; $pb = $null
                foreach ($att in 0, 1) {
                    $pb = $null
                    $pa = Find-ScpAnchor $fl $list $edges $hs0 0 $true 0
                    if ($null -ne $pa) { $pb = Find-ScpAnchor $fl $list $edges $ts0 $to0 $false ($pa[0] + $L) }
                    if (($null -ne $pa -and $null -ne $pb) -or $full0) { break }
                    # Aucun couple d ancres dans les bouts du tour 0 (secteurs vides, long remplissage) : tout le tour 0
                    $hs0 = Get-ScpClassText $fl[0] 0 $fl[0].Length $c0; $ts0 = $hs0; $to0 = 0; $full0 = $true
                }
                if ($null -ne $pa -and $null -ne $pb) {
                    $aMin = [int]::MaxValue; $aMax = [int]::MinValue; $bMin = [int]::MaxValue; $bMax = [int]::MinValue
                    for ($r = 0; $r -lt $nr; $r++) {
                        $ab = $pb[$r] - $pa[$r]
                        if ($ab -lt $aMin) { $aMin = $ab }; if ($ab -gt $aMax) { $aMax = $ab }
                        if ($r -lt $nr - 1) {
                            $ba = $fl[$r].Length - $pb[$r] + $pa[$r + 1]
                            if ($ba -lt $bMin) { $bMin = $ba }; if ($ba -gt $bMax) { $bMax = $ba }
                        }
                    }
                    if ($aMin -gt 0 -and $bMin -gt 0) { $post.StabAl = [int][math]::Max($aMax - $aMin, $bMax - $bMin); $post.PA = $pa; $post.PB = $pb }
                }
            }
        }
        # Propriete ajoutee avant toute correction : en cas d echec, la piste reste entiere au comptage d avant
        $list[0].PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('Post', $post))
    } catch {
        if ($script:ScpPostFail) { $script:ScpPostFail.N++; if (-not $script:ScpPostFail.Msg) { $script:ScpPostFail.Msg = [string]$_.Exception.Message } }
        return
    }
    for ($r = 0; $r -lt $nr; $r++) { if ($dOoc[$r] -ne 0) { $list[$r].OutOfClass = [int]$list[$r].OutOfClass - $dOoc[$r] } }
}

function Get-AlignCyls {
    $vals = @()
    foreach ($tok in ($txtAlCyls.Text -split '[,; ]+')) {
        if ($tok -match '^\d+$') { $v = [int]$tok; if ($v -ge 0 -and $v -le 83) { $vals += $v } }
    }
    return ($vals | Sort-Object -Unique)
}

function Start-AlignCycle {
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $cyls = @(Get-AlignCyls)
    if ($cyls.Count -eq 0) {
        [void](Show-AppMessage (T 'Indiquez au moins un cylindre valide (0-83).') (T 'Alignement') 'OK' 'Warning')
        $script:AlignLoop = $false; return
    }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:AlignTmp = Join-Path $script:TempDir 'align.scp'
    if (Test-Path -LiteralPath $script:AlignTmp) { Remove-Item -LiteralPath $script:AlignTmp -Force }
    $cspec = ($cyls -join ',')
    $hspec = if ($cmbAlHead.Text -eq '0+1') { '0-1' } else { $cmbAlHead.Text }
    $script:AlignArgs = @('read') + (Get-CommonArgs) + @("--revs=$($numAlRevs.Value)", "--tracks=c=${cspec}:h=$hspec", "`"$($script:AlignTmp)`"")
    # 12.8 (lot 3a) : resultat precedent grise et marque « en cours » jusqu a la fin de l analyse (D16)
    Set-QualityPending 'measure' @{ Drive = [string]$cmbDrive.Text; Heads = [string]$cmbAlHead.Text; Revs = [int]$numAlRevs.Value; NCyl = $cyls.Count }
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:AlignArgs })
    $script:Chain.Enqueue({ Invoke-AlignAnalysis })
    Invoke-NextChainStep
}

function Get-AlLevel([string]$kind, [double]$v) {
    switch ($kind) {
        'score'  { if ($v -lt 100) { 0 } elseif ($v -lt 200) { 1 } elseif ($v -lt 400) { 2 } else { 3 } }
        'jitter' { if ($v -lt $script:JitterOk * 0.5) { 0 } elseif ($v -lt $script:JitterOk) { 1 } elseif ($v -lt (Get-JitterRedBound)) { 2 } else { 3 } }
        'asym'   { if ($v -lt 0.02){ 0 } elseif ($v -lt 0.05){ 1 } elseif ($v -lt 0.10){ 2 } else { 3 } }
        'err'    { if ($v -le 0)   { 0 } elseif ($v -le $script:HealthErrOk) { 1 } elseif ($v -le 20)  { 2 } else { 3 } }   # 12.8.2 : borne SAIN de Get-HealthLevel
        'stab'   { if ($v -le 2)   { 0 } elseif ($v -le 5)   { 1 } elseif ($v -le 10)  { 2 } else { 3 } }
        'delta'  { if ($v -le 10)  { 0 } elseif ($v -le 30)  { 1 } elseif ($v -le 100) { 2 } else { 3 } }   # ecart % vs reference
        default  { 3 }
    }
}

function Draw-AlignBars($g, $size) {
    # 12.8 (lot 3) : police, stylo et pinceaux en cache (Get-QualFont, Get-QualPen, Get-QualBrush) ; barres grises tant
    # que le resultat affiche n est pas le resultat courant (mesure en cours, perime : D16)
    $g.Clear([System.Drawing.Color]::White)
    $font = Get-QualFont 'Segoe UI' 8
    $grey = ($script:QualView.State -ne 'result')
    if (-not $script:AlignLast -or $script:AlignLast.Count -eq 0) {
        $g.DrawString((T 'Barres de score par cylindre : apparaissent après la première mesure.'), $font, [System.Drawing.Brushes]::Gray, 8, 26); return
    }
    $keys = @($script:AlignLast.Keys | Sort-Object { [double]$_ })
    $n = $keys.Count; $left = 44; $w = [math]::Max(10, ($size.Width - $left - 10) / $n); $h = $size.Height
    # echelle auto : la plus grande valeur affichee (mesure, reference, meilleur) + 15 %, arrondie a 50, minimum 100
    $peak = 0.0
    foreach ($v in $script:AlignLast.Values) { if ($v.Score -lt 2000 -and $v.Score -gt $peak) { $peak = $v.Score } }
    if ($script:AlignRef) { foreach ($v in $script:AlignRef.Values) { if ($v.Score -lt 2000 -and $v.Score -gt $peak) { $peak = $v.Score } } }
    foreach ($k in $script:AlignBest.Keys) { if ($k -ne '_global' -and $script:AlignBest[$k] -lt 2000 -and $script:AlignBest[$k] -gt $peak) { $peak = $script:AlignBest[$k] } }
    $maxScore = [math]::Max(100.0, [math]::Ceiling($peak * 1.15 / 50) * 50)
    # axe
    $pen = Get-QualPen ([System.Drawing.Color]::Gainsboro) 1
    foreach ($frac in 0.25,0.5,0.75) { $y = [int]($h - 14 - ($h - 24) * $frac); $g.DrawLine($pen, $left, $y, $size.Width - 6, $y) }
    $g.DrawString('0', $font, [System.Drawing.Brushes]::Gray, 2, $h - 22)
    $g.DrawString([string][int]$maxScore, $font, [System.Drawing.Brushes]::Gray, 2, 2)
    $i = 0
    foreach ($k in $keys) {
        $st = $script:AlignLast[$k]
        $x = [int]($left + $i * $w + 4); $bw = [int]($w - 8)
        $sc = [math]::Min($st.Score, $maxScore)
        $bh = [int](($h - 24) * ($sc / $maxScore)); if ($bh -lt 2) { $bh = 2 }
        $lvl = Get-AlLevel 'score' $st.Score
        $brush = Get-QualBrush $(if ($grey) { [System.Drawing.Color]::FromArgb(196, 201, 210) } else { $script:AlColors[$lvl] })
        $g.FillRectangle($brush, $x, $h - 14 - $bh, $bw, $bh)
        $g.DrawRectangle([System.Drawing.Pens]::DimGray, $x, $h - 14 - $bh, $bw, $bh)
        # repere reference (trait noir) et meilleur (trait bleu)
        if ($script:AlignRef -and $script:AlignRef.ContainsKey($k)) {
            $ry = [int]($h - 14 - ($h - 24) * ([math]::Min($script:AlignRef[$k].Score, $maxScore) / $maxScore))
            $g.DrawLine([System.Drawing.Pens]::Black, $x - 2, $ry, $x + $bw + 2, $ry)
            $g.DrawLine([System.Drawing.Pens]::Black, $x - 2, $ry + 1, $x + $bw + 2, $ry + 1)
        }
        if ($script:AlignBest.ContainsKey($k)) {
            $by = [int]($h - 14 - ($h - 24) * ([math]::Min($script:AlignBest[$k], $maxScore) / $maxScore))
            $g.DrawLine([System.Drawing.Pens]::RoyalBlue, $x - 2, $by, $x + $bw + 2, $by)
        }
        $label = if ($cmbAlHead.Text -eq '0+1') { "c$k" } else { "c$($k -replace '\.\d+$','')" }
        $ink = if ($grey) { Get-QualBrush $script:Theme.Muted } else { [System.Drawing.Brushes]::Black }
        $g.DrawString($label, $font, $ink, $x, $h - 14)
        $g.DrawString(('{0:N0}' -f $st.Score), $font, $ink, $x, [math]::Max(0, $h - 14 - $bh - 14))
        $i++
    }
}

function Update-AlignGuide([double]$avg) {
    if ($null -eq $script:AlPos) { $lblAlPos.Text = ''; return }
    $pos = [int]$script:AlPos
    if (-not $script:AlPosScores.ContainsKey($pos) -or $avg -lt $script:AlPosScores[$pos]) { $script:AlPosScores[$pos] = $avg }
    $bestPos = $pos; $bestScore = [double]::PositiveInfinity
    foreach ($k in $script:AlPosScores.Keys) { if ($script:AlPosScores[$k] -lt $bestScore) { $bestScore = $script:AlPosScores[$k]; $bestPos = [int]$k } }
    $lblAlPos.Text = ((T "Position {0}  |  meilleure position : {1} (score {2})") -f "$pos", "$bestPos", "$([math]::Round($bestScore,0))")

    $sens = @{ 1 = "'+'"; -1 = "'-'" }
    $color = 'DimGray'; $txt = ''
    if ($script:AlLastMove -eq 0) {
        if ($script:AlPosScores.Count -le 1) {
            $txt = ((T "Position 0 mesurée (score {0}). Tournez le stepper d'UN PETIT cran dans un sens, puis cliquez sur le bouton correspondant.") -f "$([math]::Round($avg,0))")
            $color = 'RoyalBlue'
        } else {
            $txt = ((T "Position {0} re-mesurée. Meilleure position connue : {1}.") -f "$pos", "$bestPos")
            if ($pos -ne $bestPos) { $txt += ((T " Revenez de {0} cran(s) vers le sens {1} pour la retrouver.") -f "$([math]::Abs($pos-$bestPos))", "$($sens[[math]::Sign($bestPos-$pos)])") }
        }
    } else {
        $prev = $pos - $script:AlLastMove
        $prevScore = if ($script:AlPosScores.ContainsKey($prev)) { $script:AlPosScores[$prev] } else { $null }
        if ($null -eq $prevScore) {
            $txt = ((T "Position {0} mesurée. Pas de mesure à la position précédente : impossible de conclure, continuez.") -f "$pos")
        } elseif ($avg -lt $prevScore * 0.97) {
            $txt = ((T "AMÉLIORATION ({0} -> {1}) : CONTINUEZ dans le sens {2}, encore un cran, puis mesurez.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[$script:AlLastMove])")
            $color = 'Green'
        } elseif ($avg -gt $prevScore * 1.03) {
            # le pas precedent etait-il un optimum (moins bon des deux cotes) ?
            $other = $prev - $script:AlLastMove
            $otherWorse = $script:AlPosScores.ContainsKey($other) -and ($script:AlPosScores[$other] -gt $prevScore * 1.03)
            if ($otherWorse -and $prev -eq $bestPos) {
                $txt = ((T "OPTIMUM TROUVÉ à la position {0} (score {1}) : RECULEZ d'un cran (sens {2}), resserrez les vis, re-mesurez pour contrôle.") -f "$prev", "$([math]::Round($prevScore,0))", "$($sens[-$script:AlLastMove])")
                $color = 'DarkGreen'
            } else {
                $txt = ((T "DÉGRADATION ({0} -> {1}) : RECULEZ d'un cran (sens {2}) pour revenir à la position {3}, puis essayez l'autre sens.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[-$script:AlLastMove])", "$prev")
                $color = 'DarkOrange'
            }
        } else {
            $txt = ((T "Pas de changement net ({0} -> {1}) : cran trop petit ou plateau. Encore un cran dans le sens {2}.") -f "$([math]::Round($prevScore,0))", "$([math]::Round($avg,0))", "$($sens[$script:AlLastMove])")
            $color = 'DimGray'
        }
        if ($pos -ne $bestPos -and $color -ne 'DarkGreen' -and $avg -gt $bestScore * 1.10) {
            $txt += ((T "  (Meilleur connu : position {0}.)") -f "$bestPos")
        }
    }
    $lblAlReco.Text = $txt; $lblAlReco.ForeColor = $color
    Append-Log ((T "Guide alignement : {0}") -f "$txt")
}

function Render-AlignBars { $pnlAlBars.Invalidate() }

function Get-HealthLevel([double]$err, [double]$drop, [double]$stab, [double]$jit, [double]$okT = $script:JitterOk, [double]$watchT = $script:JitterWatch) {
    # Seuils de jitter reglables (Accueil, « Regler le jitter ») ; l asymetrie n entre pas dans l etat. Seuils explicites
    # (Standard 120 / 250 ns) pour juger un ORIGINAL et pour le garde-fou du controle : un reglage strict ne doit faire
    # que reecrire davantage de pistes de la copie, pas rejeter une source lisible ni bloquer les reecritures.
    # 12.8.2 : SAIN jusqu a HealthErrOk erreurs par tour (2 ; 3 jusqu en 12.8.1), meme seuil pour tous les appelants.
    if ($err -le $script:HealthErrOk -and $drop -le 0 -and $stab -le 2 -and $jit -lt $okT) { return 0 }
    if ($err -le 20 -and $drop -le 1 -and $stab -le 10 -and $jit -lt $watchT) { return 1 }
    return 2
}

function Get-JitterRedBound {
    # Borne orange / rouge de la colonne Jitter : toujours au-dessus du seuil SAIN (bande orange non vide)
    return [math]::Max($script:JitterWatch * 0.8, ($script:JitterOk + $script:JitterWatch) / 2)
}

function Update-QualityTip {
    # 12.8.2 : definition des erreurs (premier intervalle et zone de l index non comptes) et de la stabilite (tours alignes),
    # en derniere ligne
    $tip.SetToolTip($lvAl, ((T "État par piste : SAIN / À SURVEILLER / CRITIQUE, d'après les erreurs, les trous, la stabilité et le jitter.`nJitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns (onglet Accueil, « Régler le jitter »).`nCouleurs de la colonne Jitter : <{2} / <{0} / <{3} ns. Asymétrie : <0,02 / <0,05 / <0,10 (couleur et score seulement, sans effet sur l'état).`nErreurs : intervalles hors classe par tour, sans le premier intervalle de la lecture ; en double densité, sans le raccord d'écriture de gw quand il tient dans la zone de ± 1 ms autour de l'index (sauf index simulé ou données dans cette zone) ; les trous sont comptés partout. Stabilité : écart du nombre de flux entre les tours ; en double densité et à partir de 3 tours, comparés alignés sur les mêmes données.") -f "$($script:JitterOk)", "$($script:JitterWatch)", "$([math]::Round($script:JitterOk * 0.5))", "$([math]::Round((Get-JitterRedBound)))"))
}

function Set-JitterThresholds([int]$ok, [int]$watch) {
    # Bornes : SAIN de 30 a 300 ns, A SURVEILLER au moins 10 ns au-dessus, 600 ns au plus
    $ok = [math]::Max(30, [math]::Min(300, $ok))
    $watch = [math]::Max($ok + 10, [math]::Min(600, $watch))
    $changed = ($ok -ne [int]$script:JitterOk -or $watch -ne [int]$script:JitterWatch)
    $script:JitterOk = $ok; $script:JitterWatch = $watch
    Update-QualityTip
    # 12.8 (lot 3a) : etats affiches calcules avec les anciens seuils, non recalculables (AlignLast ne garde ni les trous ni
    # les zones instables) : resultat declare perime ; sans effet sans resultat affiche (chargement, Set-Defaults).
    # 12.8 (FIX3) : ni pendant une mesure ou un controle en cours (Reinitialiser des parametres pendant la pause d une
    # mesure continue, passe suivante lancee par le minuteur sous la boite) : son analyse prendra les nouveaux seuils, et
    # l etat « en cours » garde les arrets sur erreur gw de la mesure continue
    if ($changed -and $script:QualView.State -ne 'run') { Set-QualityStale 'thresholds' }
}

function Get-JitterPresets {
    return @(
        @{ Name = (T 'Standard (120 / 250 ns)'); Ok = $script:JitterStdOk; Watch = $script:JitterStdWatch },   # 12.8 : constante unique
        @{ Name = (T 'Strict (90 / 180 ns)'); Ok = 90; Watch = 180 },
        @{ Name = (T 'Très strict (70 / 140 ns)'); Ok = 70; Watch = 140 }
    )
}

function Show-JitterSettings {
    # Reglage des seuils de jitter (etat SAIN / A SURVEILLER / CRITIQUE) : onglet Qualite, controle apres ecriture,
    # restauration. Refuse pendant une operation (un controle en cours changerait de criteres en route) ; 12.8 (D20) :
    # Get-AppBusy, donc aussi pendant un prechauffage, une detection ou la mesure continue de l onglet Qualite
    if (Get-AppBusy) {
        [void](Show-AppMessage (T "Opération en cours : modifiez le réglage du jitter une fois l'opération terminée.") (T 'Réglage du jitter') 'OK' 'Information'); return
    }
    # 12.8 (lot 5, A4 R1 a R8, D15, D17) : bandeau d information, legende des etats avec les icones du lot 3 (✓ SAIN,
    # ! A SURVEILLER, ✗ CRITIQUE) dans l encre de leur niveau (Get-QualInk), options en rangees de 34 px, erreur de saisie
    # dans le texte d etat lblJitState (R7) au lieu d une boite, aucun AcceptButton, images liberees (Clear-DlgGdi)
    $W = 600
    $presets = Get-JitterPresets
    $gdi = New-Object System.Collections.Generic.List[object]
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmJitter'; $dlg.Text = (T 'Réglage du jitter')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $text = (T "Le jitter mesure la dispersion des intervalles entre les transitions magnétiques d'une piste, en nanosecondes : plus il est faible, plus la piste est nette.`n`nCes seuils fixent l'état de chaque piste dans l'onglet « Qualité & alignement », dans le contrôle après écriture et dans la restauration. Une piste n'est SAINE que si son jitter est sous le premier seuil, et si ses erreurs, ses trous et sa stabilité sont bons. Au-delà du second seuil, elle est CRITIQUE. Les erreurs ne comptent pas le premier intervalle de la lecture ni, en double densité, le raccord d'écriture de gw dans la zone de ± 1 ms autour de l'index ; en double densité et à partir de 3 tours, la stabilité compare les tours alignés sur les mêmes données.`n`nAprès une écriture avec contrôle de toutes les pistes (écriture lente, restauration), une piste qui n'est pas SAINE est réécrite, dans la limite des passes de réécriture : un réglage plus strict fait réécrire davantage de pistes, donc davantage d'écritures sur la disquette. Le jugement de la disquette d'origine en restauration et le garde-fou (plus de la moitié des pistes faibles : aucune réécriture) gardent les seuils Standard.")
    $ban = New-DlgBanner $dlg 16 $W (T 'Seuils de jitter des pistes') $text 'info' (New-DlgPicto 'jitter') $gdi 'lblJitText'
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $y = $ban.Bottom + 14
    # Libelles en x = 16 (legende : icone en x = 16, texte en x = 38), controles alignes apres le plus long libelle
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = (T 'Préréglage :'); $l1.AutoSize = $true; $l1.Font = $dlg.Font
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = (T 'SAIN si le jitter est inférieur à :'); $l2.AutoSize = $true; $l2.Font = $dlg.Font; $l2.ForeColor = Get-QualInk 0
    $l3 = New-Object System.Windows.Forms.Label; $l3.Text = (T "À SURVEILLER s'il est inférieur à :"); $l3.AutoSize = $true; $l3.Font = $dlg.Font; $l3.ForeColor = Get-QualInk 2
    $cx = [math]::Max(16 + $l1.PreferredWidth, 38 + [math]::Max($l2.PreferredWidth, $l3.PreferredWidth)) + 12
    $l1.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Name = 'cmbJitPreset'; $cmb.DropDownStyle = 'DropDownList'; $cmb.Location = New-Object System.Drawing.Point($cx, $y); $cmb.Width = 240
    foreach ($pr in $presets) { [void]$cmb.Items.Add($pr.Name) }
    [void]$cmb.Items.Add((T 'Personnalisé'))
    $y += 34
    $i2 = New-Object System.Windows.Forms.PictureBox; $i2.Image = Get-QualityIcon 'h0' 16; $i2.Location = New-Object System.Drawing.Point(16, ($y + 4)); $i2.Size = New-Object System.Drawing.Size(16, 16)
    $l2.Location = New-Object System.Drawing.Point(38, ($y + 3))
    $numOk = New-Object System.Windows.Forms.NumericUpDown
    $numOk.Name = 'numJitOk'; $numOk.Minimum = 30; $numOk.Maximum = 300; $numOk.Increment = 5; $numOk.Width = 80; $numOk.Location = New-Object System.Drawing.Point($cx, $y)
    $u1 = New-Object System.Windows.Forms.Label; $u1.Text = 'ns'; $u1.AutoSize = $true; $u1.Location = New-Object System.Drawing.Point(($cx + 86), ($y + 3))
    $y += 34
    $i3 = New-Object System.Windows.Forms.PictureBox; $i3.Image = Get-QualityIcon 'h1' 16; $i3.Location = New-Object System.Drawing.Point(16, ($y + 4)); $i3.Size = New-Object System.Drawing.Size(16, 16)
    $l3.Location = New-Object System.Drawing.Point(38, ($y + 3))
    $numWatch = New-Object System.Windows.Forms.NumericUpDown
    $numWatch.Name = 'numJitWatch'; $numWatch.Minimum = 40; $numWatch.Maximum = 600; $numWatch.Increment = 10; $numWatch.Width = 80; $numWatch.Location = New-Object System.Drawing.Point($cx, $y)
    $u2 = New-Object System.Windows.Forms.Label; $u2.Text = 'ns'; $u2.AutoSize = $true; $u2.Location = New-Object System.Drawing.Point(($cx + 86), ($y + 3))
    $y += 34
    $i4 = New-Object System.Windows.Forms.PictureBox; $i4.Image = Get-QualityIcon 'h2' 16; $i4.Location = New-Object System.Drawing.Point(16, ($y + 1)); $i4.Size = New-Object System.Drawing.Size(16, 16)
    $l4 = New-Object System.Windows.Forms.Label; $l4.Text = (T 'Au-delà : CRITIQUE.'); $l4.AutoSize = $true; $l4.ForeColor = Get-QualInk 3; $l4.Location = New-Object System.Drawing.Point(38, $y)
    $y += 26
    $l5 = New-Object System.Windows.Forms.Label; $l5.Text = (T 'Les nouvelles valeurs valent pour les prochaines mesures.'); $l5.AutoSize = $true; $l5.ForeColor = $script:Theme.Muted; $l5.Location = New-Object System.Drawing.Point(16, $y)
    $y += 26
    # Texte d etat (R7) : erreur de saisie, en Semibold et dans l encre du danger ; hauteur de son texte, mesuree
    $fS = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fS)
    $errTxt = (T "Le seuil À SURVEILLER doit dépasser le seuil SAIN d'au moins 10 ns.")
    $lblSt = New-Object System.Windows.Forms.Label
    $lblSt.Name = 'lblJitState'; $lblSt.AutoSize = $false; $lblSt.UseMnemonic = $false; $lblSt.Font = $fS; $lblSt.ForeColor = Get-QualInk 3
    $lblSt.Location = New-Object System.Drawing.Point(16, $y)
    $lblSt.Size = New-Object System.Drawing.Size($W, ([System.Windows.Forms.TextRenderer]::MeasureText($errTxt, $fS, (New-Object System.Drawing.Size($W, 10000)), $tf).Height + 2))
    $y = $lblSt.Bottom + 8
    $btnDef = New-Object System.Windows.Forms.Button; $btnDef.Name = 'btnJitDefault'; $btnDef.Text = (T 'Valeurs par défaut'); $btnDef.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $btnDef.Text 'Refresh' 150), 34)
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Name = 'btnJitOk'; $btnOk.Text = (T 'Enregistrer'); $btnOk.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $btnOk.Text 'Save' 140), 34)
    $btnNo = New-Object System.Windows.Forms.Button; $btnNo.Name = 'btnJitCancel'; $btnNo.Text = (T 'Annuler'); $btnNo.Size = New-Object System.Drawing.Size(110, 34)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnDef 'Refresh' 'normal'; Set-Btn $btnOk 'Save' 'primary'; Set-Btn $btnNo '' 'normal'
    $btnDef.Location = New-Object System.Drawing.Point(16, $y)
    $btnNo.Location = New-Object System.Drawing.Point((16 + $W - $btnNo.Width), $y)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + $btnOk.Height + 16))
    $dlg.CancelButton = $btnNo                        # pas d AcceptButton : Entree n enregistre pas
    $dlg.Controls.AddRange(@($l1, $cmb, $i2, $l2, $numOk, $u1, $i3, $l3, $numWatch, $u2, $i4, $l4, $l5, $lblSt, $btnDef, $btnOk, $btnNo))
    $dlg.ActiveControl = $cmb
    [void](Set-DlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))
    # Etat partage avec les gestionnaires (portee script) : prereglage <-> valeurs, sans boucle ; texte d etat efface a
    # chaque changement de valeur
    $script:JitDlg = @{ Presets = $presets; Cmb = $cmb; Ok = $numOk; Watch = $numWatch; Busy = $false; Dlg = $dlg; State = $lblSt; Err = $errTxt }
    $numOk.Value = $script:JitterOk; $numWatch.Value = $script:JitterWatch
    $sync = {
        $s = $script:JitDlg
        if (-not $s -or $s.Busy) { return }
        $s.State.Text = ''
        $s.Busy = $true
        $i = -1
        for ($k = 0; $k -lt $s.Presets.Count; $k++) { if ($s.Presets[$k].Ok -eq [int]$s.Ok.Value -and $s.Presets[$k].Watch -eq [int]$s.Watch.Value) { $i = $k } }
        $s.Cmb.SelectedIndex = $(if ($i -ge 0) { $i } else { $s.Presets.Count })
        $s.Busy = $false
    }
    & $sync
    $numOk.Add_ValueChanged($sync); $numWatch.Add_ValueChanged($sync)
    $cmb.Add_SelectedIndexChanged({
        $s = $script:JitDlg
        if (-not $s -or $s.Busy -or $s.Cmb.SelectedIndex -lt 0 -or $s.Cmb.SelectedIndex -ge $s.Presets.Count) { return }
        $s.Busy = $true; $s.State.Text = ''
        $pr = $s.Presets[$s.Cmb.SelectedIndex]
        $s.Ok.Value = $pr.Ok; $s.Watch.Value = $pr.Watch
        $s.Busy = $false
    })
    $btnDef.Add_Click({ $script:JitDlg.Cmb.SelectedIndex = 0 })
    $btnOk.Add_Click({
        $s = $script:JitDlg
        # Seuils incoherents : texte d etat (R7), la fenetre reste ouverte
        if ([int]$s.Watch.Value -lt [int]$s.Ok.Value + 10) { $s.State.Text = $s.Err; return }
        $s.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    try {
        $dr = $dlg.ShowDialog($form)
        if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
            Set-JitterThresholds ([int]$numOk.Value) ([int]$numWatch.Value)
            [void](Save-Config)
            Append-Log ((T "Réglage du jitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns, CRITIQUE au-delà (prochaines mesures).") -f "$($script:JitterOk)", "$($script:JitterWatch)")
        }
    } finally {
        $script:JitDlg = $null
        Clear-DlgGdi $dlg $gdi
    }
}

# Metriques d une piste (liste de ScpRev, un par tour) : base commune de l onglet Qualite et du
# controle apres ecriture, pour que « piste faible » ait partout la meme definition.
function Get-TrackMetrics($st) {
    # 12.8.2 : Ooc sans le premier intervalle de la lecture ni les hors classe de la zone de l index, Stab sur tours
    # alignes (Read-ScpFile, Set-ScpTrackPost : propriete Post du tour 0) ; ZoneOoc : hors classe ecartes (tous tours) ;
    # ZoneFarNs : distance a l index de la grappe ecartee la plus lointaine ; StabAligned : faux = ecart du nombre de flux
    # (moins de 3 tours, haute densite, secteurs durs, piste sans post-traitement : calibration) ; StabFallback :
    # alignement tente mais sans ancres communes (repli sur l ecart du nombre de flux, signale au journal)
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 2
            Weak = $false; ShortUnstable = $false; Blocks = 0; Unstable = 0; MaxRun = 0; RunPos = -1; ZoneOoc = 0; ZoneFarNs = 0; StabAligned = $false; StabFallback = $false }
    $list = @($st)
    if ($list.Count -eq 0) { $m.Bad = $true; return $m }
    foreach ($x in $list) { if ([double]::IsNaN($x.Jitter)) { $m.Bad = $true } }
    if ($m.Bad) { return $m }
    $m.J    = ($list | Measure-Object -Property Jitter -Average).Average
    $m.R3   = ($list | Measure-Object -Property R3 -Average).Average
    $m.R4   = ($list | Measure-Object -Property R4 -Average).Average
    $m.Ooc  = ($list | Measure-Object -Property OutOfClass -Average).Average
    $m.Dr   = ($list | Measure-Object -Property Dropouts -Average).Average
    $m.Cell = ($list | Measure-Object -Property Cell -Average).Average
    $nf     = $list | ForEach-Object { $_.NFlux }
    $m.Stab = ($nf | Measure-Object -Maximum).Maximum - ($nf | Measure-Object -Minimum).Minimum
    $pp = $list[0].PSObject.Properties['Post']
    if ($pp -and $pp.Value) {
        $m.ZoneOoc = [int]$pp.Value.ZoneOoc; $m.ZoneFarNs = [int]$pp.Value.ZoneFarNs
        if ([int]$pp.Value.StabAl -ge 0) { $m.Stab = [int]$pp.Value.StabAl; $m.StabAligned = $true }
        elseif ($pp.Value.Tried) { $m.StabFallback = $true }
    }
    $m.Asym = [math]::Abs($m.R3 - 1.5) + [math]::Abs($m.R4 - 2.0)
    $m.Score = [math]::Round($m.J + 2000 * $m.Asym + 5 * $m.Ooc + 50 * $m.Dr + $m.Stab, 0)
    $m.Level = Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J
    # Stabilite d un tour a l autre (Read-ScpFile, premier tour) : blocs de 32 intervalles absents d au moins deux autres
    # tours. Weak : au moins 3 blocs consecutifs (une dizaine d octets), au plus le quart de la piste = bits faibles d une
    # protection probable, ou defaut localise ; non reproductible par une copie, qui n ecrit qu un tour. ShortUnstable :
    # 2 blocs, raccord d ecriture a cheval sur deux blocs ou courte zone de protection : pas d alerte, mais jamais reecrite
    # sur une disquette identique a l original.
    $r0 = $list[0]
    if ($r0.Blocks -gt 0) {
        $m.Blocks = $r0.Blocks; $m.Unstable = $r0.Unstable; $m.MaxRun = $r0.MaxRun; $m.RunPos = $r0.RunPos
        $m.Weak = ($r0.MaxRun -ge 3 -and $r0.Unstable * 4 -le $r0.Blocks)
        $m.ShortUnstable = ($r0.MaxRun -ge 2 -and -not $m.Weak)
    }
    return $m
}

# Ligne du tableau de l onglet Qualite pour une piste ; $mark complete l etat (ex. « (reecrite x2) »)
function New-AlignRow([string]$lab, $m, [string]$mark, [string]$delta, [int]$deltaLvl) {
    $healthNames = @{ 0=(T 'SAIN'); 1=(T 'À SURVEILLER'); 2=(T 'CRITIQUE') }
    $healthColor = @{ 0=$script:AlColors[0]; 1=$script:AlColors[2]; 2=$script:AlColors[3] }
    $it = New-Object System.Windows.Forms.ListViewItem($lab)
    $it.UseItemStyleForSubItems = $false
    if ($m.Bad) {
        $state = if ($m.Missing) { (T 'ABSENTE') } else { (T 'ILLISIBLE') }
        foreach ($v in @(($state + $mark),'-','-','-','-','-','-','-','-')) { [void]$it.SubItems.Add([string]$v) }
        $it.SubItems[1].BackColor = $script:AlColors[3]; $it.SubItems[1].ForeColor = [System.Drawing.Color]::White; $it.SubItems[1].Font = $bold
        $it.Tag = @{ State = $(if ($m.Missing) { 'h2a' } else { 'h2' }); Score = '' }   # 12.8 (lot 3b) : icones 16 px (DrawSubItem)
        return $it
    }
    $hl = [int]$m.Level
    $wk = if ($m.Weak) { (T ' (zone instable)') } else { '' }
    # Zone instable non jugee (controle d une copie dont la source peut porter des zones faibles) : ni SAINE ni faible
    $stTxt = if ($m.Unjudged -and $hl -eq 0) { (T 'NON JUGÉE') } else { $healthNames[$hl] }
    foreach ($v in @(($stTxt + $wk + $mark), ('{0:N1}' -f $m.Ooc), ('{0:N1}' -f $m.Dr), [string]$m.Stab, ('{0:N0}' -f $m.J), ('{0:N0}' -f $m.Score), $delta, ('{0:N3}' -f $m.Asym), ('{0:N0}' -f $m.Cell))) { [void]$it.SubItems.Add($v) }
    $it.SubItems[1].BackColor = $healthColor[$hl]; $it.SubItems[1].ForeColor = $script:AlFg[$(@{0=0;1=2;2=3}[$hl])]
    if ($m.Unjudged -and $hl -eq 0) { $it.SubItems[1].BackColor = $script:AlColors[1]; $it.SubItems[1].ForeColor = $script:AlFg[1] }
    $it.SubItems[1].Font = $bold
    $lvErr = Get-AlLevel 'err' $m.Ooc;    $it.SubItems[2].BackColor = $script:AlColors[$lvErr];  $it.SubItems[2].ForeColor = $script:AlFg[$lvErr]
    $lvDr  = $(if ($m.Dr -le 0) { 0 } elseif ($m.Dr -le 1) { 2 } else { 3 }); $it.SubItems[3].BackColor = $script:AlColors[$lvDr]; $it.SubItems[3].ForeColor = $script:AlFg[$lvDr]
    $lvStb = Get-AlLevel 'stab' $m.Stab;  $it.SubItems[4].BackColor = $script:AlColors[$lvStb];  $it.SubItems[4].ForeColor = $script:AlFg[$lvStb]
    $lvJit = Get-AlLevel 'jitter' $m.J;   $it.SubItems[5].BackColor = $script:AlColors[$lvJit];  $it.SubItems[5].ForeColor = $script:AlFg[$lvJit]
    $lvSc  = Get-AlLevel 'score' $m.Score; $it.SubItems[6].BackColor = $script:AlColors[$lvSc];  $it.SubItems[6].ForeColor = $script:AlFg[$lvSc]
    if ($deltaLvl -ge 0) { $it.SubItems[7].BackColor = $script:AlColors[$deltaLvl]; $it.SubItems[7].ForeColor = $script:AlFg[$deltaLvl] }
    $lvAs  = Get-AlLevel 'asym' $m.Asym;  $it.SubItems[8].BackColor = $script:AlColors[$lvAs];   $it.SubItems[8].ForeColor = $script:AlFg[$lvAs]
    # 12.8 (lot 3b, D15) : icone d etat (colonne Etat) et icone de score (colonne Score), 16 px, dessinees par DrawSubItem
    $it.Tag = @{ State = $(if ($m.Unjudged -and $hl -eq 0) { 'hq' } else { "h$hl" }); Score = "q$lvSc" }
    return $it
}

function Set-UnstableBanner([string[]]$parts) {
    # Bandeau orange des zones instables (onglet Qualite) ; vide : efface un bandeau orange reste d une mesure precedente,
    # sauf pendant le guide d alignement qui utilise la meme ligne
    $parts = @($parts | Where-Object { $_ })
    if ($parts.Count -gt 0) {
        $lblAlReco.Text = ($parts -join '   |   '); $lblAlReco.ForeColor = 'DarkOrange'; $lblAlReco.Visible = $true
        $script:UnstableBannerText = $lblAlReco.Text
    } elseif ($script:UnstableBannerText -and $lblAlReco.Text -eq $script:UnstableBannerText) { $lblAlReco.Text = ''; $script:UnstableBannerText = $null }
    elseif (-not $chkAlGuide.Checked -and $lblAlReco.ForeColor -eq [System.Drawing.Color]::DarkOrange) { $lblAlReco.Text = '' }
}

function Get-UnstableClusters([string[]]$keys, [int]$minRun = 3) {
    # Suites d au moins $minRun cylindres consecutifs instables sur une meme face (« c58-c61 tete 1 ») : une rayure ou une
    # usure touche des pistes voisines, une protection a bits faibles tient en general sur une piste isolee
    $out = @()
    foreach ($h in 0, 1) {
        $cs = @($keys | Where-Object { $_ -match "^\d+\.$h$" } | ForEach-Object { [int](($_ -split '\.')[0]) } | Sort-Object -Unique)
        $i = 0
        while ($i -lt $cs.Count) {
            $j = $i
            while ($j + 1 -lt $cs.Count -and $cs[$j + 1] -eq $cs[$j] + 1) { $j++ }
            if ($j - $i + 1 -ge $minRun) { $out += ((T "c{0}-c{1} tête {2}") -f "$($cs[$i])", "$($cs[$j])", "$h") }
            $i = $j + 1
        }
    }
    return $out
}

function Invoke-AlignAnalysis {
    # 12.8 (lot 3a) : analyse impossible : resultat affiche declare perime (ou carte vide avec la raison)
    if (-not $script:AlignTmp -or -not (Test-Path -LiteralPath $script:AlignTmp)) {
        Append-Log (T 'Mesure : fichier SCP absent, analyse impossible.'); $script:AlignLoop = $false; Set-QualityStale 'noscp'; return
    }
    try { $tracks = Read-ScpFile $script:AlignTmp } catch { Append-Log ((T "Mesure : {0}") -f "$($_.Exception.Message)"); $script:AlignLoop = $false; Set-QualityStale 'noscp'; return }

    $last = @{}; $watch = @(); $crit = @(); $weakL = @(); $critK = @(); $nBad = 0
    $res = @{ Kind = 'measure'; Score = $null; Lvl = 3; Count = 0; Bad = 0; Health = 0; NTracks = 0; WatchKeys = @(); CritKeys = @()
              HealthText = ''; ScoreText = ''; Prev = $null; Best = $null; RefAvg = $null }
    $lvAl.Columns[1].Width = 222                          # 12.8 (lot 3b) : icone d etat de 16 px devant le texte
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        $total = 0.0; $count = 0; $zo = 0; $zt = 0; $zf = 0; $fb = @()
        foreach ($tn in ($tracks.Keys | Sort-Object)) {
            $st = $tracks[$tn]; $cyl = [math]::Floor($tn / 2); $hd = $tn % 2; $key = "$cyl.$hd"
            $lab = "$cyl.$hd"
            $m = Get-TrackMetrics $st
            if ($m.ZoneOoc -gt 0) { $zo += $m.ZoneOoc; $zt++; if ($m.ZoneFarNs -gt $zf) { $zf = $m.ZoneFarNs } }
            if ($m.StabFallback) { $fb += $lab }
            if ($m.Bad) {
                [void]$lvAl.Items.Add((New-AlignRow $lab $m '' '-' -1))
                $last[$key] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }
                $crit += ((T "{0} (illisible)") -f "$lab"); $critK += $lab; $nBad++; continue
            }
            # Zone instable : la piste ne se relit pas pareil d un tour a l autre, elle n est pas propre (protection ou
            # defaut du support, l application ne peut pas trancher sur une disquette inconnue) : au moins A SURVEILLER
            if ($m.Weak -and $m.Level -lt 1) { $m.Level = 1 }
            $sc = $m.Score
            if (-not $script:AlignBest.ContainsKey($key) -or $sc -lt $script:AlignBest[$key]) { $script:AlignBest[$key] = $sc }
            $last[$key] = @{ Score = $sc; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $hl = $m.Level
            if ($m.Weak) { $weakL += $lab }
            if ($hl -eq 1) { $watch += $lab } elseif ($hl -eq 2) { $crit += ((T "{0} ({1} err/tour)") -f "$lab", "$([math]::Round($m.Ooc,0))"); $critK += $lab }

            $delta = '-'; $deltaLvl = -1
            if ($script:AlignRef -and $script:AlignRef.ContainsKey($key) -and $script:AlignRef[$key].Score -gt 0) {
                $pct = ($sc - $script:AlignRef[$key].Score) / $script:AlignRef[$key].Score * 100
                $delta = ('{0:+0;-0;0} %' -f $pct); $deltaLvl = Get-AlLevel 'delta' $pct
            }
            [void]$lvAl.Items.Add((New-AlignRow $lab $m '' $delta $deltaLvl))
            $total += $sc; $count++
        }
        $script:AlignLast = $last
        $nTracks = $tracks.Count

        # --- Verdict 1 : etat du support (12.8, lot 3b : carte de resultat ; texte complet dans l infobulle et le journal)
        $res.NTracks = $nTracks; $res.WatchKeys = @($watch); $res.CritKeys = @($critK); $res.Bad = $nBad
        if ($crit.Count -gt 0) {
            $res.Health = 2; $res.HealthText = ((T "SUPPORT CRITIQUE  -  {0} piste(s) en erreur : {1}   ->  dump flux immédiat conseillé") -f "$($crit.Count)", "$($crit -join ', ')")
        } elseif ($watch.Count -gt 0) {
            $res.Health = 1; $res.HealthText = ((T "SUPPORT À SURVEILLER  -  {0}/{1} piste(s) marginale(s) : {2}   ->  dump flux recommandé") -f "$($watch.Count)", "$nTracks", "$($watch -join ', ')")
        } else {
            $res.Health = 0; $res.HealthText = ((T "SUPPORT SAIN  -  {0}/{1} pistes propres (erreurs, trous, stabilité, jitter dans les normes)") -f "$nTracks", "$nTracks")
        }
        Append-Log ((T "Mesure : {0}") -f "$($res.HealthText)")
        # 12.8.2 (S11, S12) : hors classe du raccord ecartes (distance a l index la plus grande), pistes sans tours alignes ;
        # mesure continue : a la premiere passe seulement (revue : le compte change a chaque relecture)
        if (-not $script:AlignLoop -or [int]$script:QualView.Pass -le 1) {
            if ($zo -gt 0) { Append-Log ((T "Mesure : {0} intervalle(s) hors classe du raccord d'écriture, dans la zone de ± 1 ms autour de l'index (jusqu'à {2} ms), non compté(s), sur {1} piste(s).") -f "$zo", "$zt", (Format-UiNum ($zf / 1e6) '0.00')) }
            if ($fb.Count -gt 0) { Append-Log ((T "Mesure : stabilité de {0} piste(s) jugée sur l'écart du nombre de flux entre les tours, faute de repère commun pour les aligner : {1}.") -f "$($fb.Count)", "$($fb -join ', ')") }
        }
        if ($weakL.Count -gt 0) { Append-Log ((T "Mesure : zone instable d'un tour à l'autre sur {0} piste(s) : {1}. Bits faibles d'une protection contre la copie probable, ou défaut localisé du support : une copie faite depuis un flux n'en écrit qu'un tour et ne les reproduit pas fidèlement.") -f "$($weakL.Count)", "$($weakL -join ', ')") }
        $clu = @(Get-UnstableClusters $weakL)
        if ($clu.Count -gt 0) { Append-Log ((T "Mesure : pistes instables sur des cylindres voisins d'une même face ({0}) : défaut du support probable (rayure, usure) plutôt qu'une protection.") -f "$($clu -join ', ')") }

        # --- Verdict 2 : score de lecture
        if ($count -gt 0) {
            $avg = [math]::Round($total / $count, 0)
            if (-not $script:AlignBest.ContainsKey('_global') -or $avg -lt $script:AlignBest['_global']) { $script:AlignBest['_global'] = $avg }
            $trend = ''
            if ($null -ne $script:AlignPrev) {
                if ($avg -lt $script:AlignPrev - 2) { $trend = (T '   MIEUX (v)') } elseif ($avg -gt $script:AlignPrev + 2) { $trend = (T '   MOINS BIEN (^)') } else { $trend = (T '   stable') }
            }
            $res.Prev = $script:AlignPrev
            $script:AlignPrev = $avg
            $lvlAvg = Get-AlLevel 'score' $avg
            $refTxt = ''
            if ($script:AlignRef) {
                $refScores = @($script:AlignRef.Values | ForEach-Object { $_.Score } | Where-Object { $_ -lt 9999 })
                if ($refScores.Count -gt 0) { $refAvg = [math]::Round(($refScores | Measure-Object -Average).Average, 0); $refTxt = ((T "   |   référence {0}") -f "$refAvg"); $res.RefAvg = $refAvg }
            }
            $res.Score = $avg; $res.Lvl = $lvlAvg; $res.Count = $count; $res.Best = $script:AlignBest['_global']
            $res.ScoreText = ((T "Qualité de lecture : score {0} - {1}{2}{3}   |   meilleur {4}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend", "$refTxt", "$($script:AlignBest['_global'])")
            Append-Log ((T "Mesure : score moyen {0} ({1}){2}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend")
            Update-AlignGuide $avg
            $bn = if ($weakL.Count -gt 0) { ((T "Zone instable d'un tour à l'autre (protection contre la copie ou défaut du support) : {0}") -f "$($weakL -join ', ')") + $(if ($clu.Count -gt 0) { (T " ; cylindres voisins {0} : défaut du support probable") -f "$($clu -join ', ')" } else { '' }) } else { '' }
            Set-UnstableBanner @($bn)
        } else {
            $res.ScoreText = (T 'Aucune piste analysable')
            Set-UnstableBanner @('')                      # 12.8 (FIX3) : bandeau d une mesure precedente retire
        }
    } finally { $lvAl.EndUpdate() }
    Render-AlignBars
    Set-QualityResult $res                                # 12.8 (lot 3a) : carte, tableau et barres en couleurs

    if ($script:AlignLoop) { $script:AlignNextAt = (Get-Date).AddSeconds([int]$numAlPause.Value) }
}
