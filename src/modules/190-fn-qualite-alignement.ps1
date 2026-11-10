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

function Get-ScpEdgeOoc($f, $e, [int]$skip) {
    # 12.10 (S13, cout) : hors classe (trous exclus) d un tour aux indices que Get-ScpStructOoc ignore, [0, skip) et
    # [max(skip, n - skip), n), comptes sur les classes des bouts deja calculees par Set-ScpTrackPost (Get-ScpEdgeClasses :
    # debut, fin, indice du premier intervalle de la fin, tour entier), sans reclasser le tour. -1 si ces classes ne couvrent
    # pas les deux bouts (aucune deduction possible)
    $n = $f.Length; $hs = [string]$e[0]; $ts = [string]$e[1]; $to = [int]$e[2]
    $a = [math]::Max($skip, $n - $skip); $h = [math]::Min($skip, $n)
    if (-not [bool]$e[3] -and ($hs.Length -lt $h -or $to -gt $a)) { return -1 }
    $k = 0
    $p = $hs.IndexOf([char]'x', 0, $h)
    while ($p -ge 0) { if ($f[$p] -lt 20000) { $k++ }; $p = if ($p + 1 -lt $h) { $hs.IndexOf([char]'x', $p + 1, $h - $p - 1) } else { -1 } }
    if ($a -lt $n) {
        $p = $ts.IndexOf([char]'x', $a - $to)
        while ($p -ge 0) { if ($f[$to + $p] -lt 20000) { $k++ }; $p = $ts.IndexOf([char]'x', $p + 1) }
    }
    return $k
}

function Get-ScpStructOoc($fl, $list, [int]$skip, [int]$cap = -1, $edges = $null) {
    # 12.10 (S13) : par tour, nombre d intervalles hors classe (classe 'x' de ScpStats.Classes, trous de 20 us ou plus
    # exclus : ils sont comptes a part) presents dans TOUS les autres tours a un indice voisin : ScpStructTol intervalles,
    # plus l ecart des comptes de flux entre les deux tours (les tours sont cales sur l index par gw). Indices sous $skip
    # ou au-dela de n - $skip ignores (bouts du tour deja traites par la zone de l index, S11). Constat du 02/11/2026
    # (AlienBreed, long track, TEAC) : le raccord d ecriture d une longue piste tombe la ou l image le place, loin de
    # l index, et laisse 1 a 2 intervalles hors classe par tour, identiques sur les 3 tours : comptes comme erreurs, ils
    # faisaient reecrire 20 a 30 pistes par disquette pour rien. Un petit defaut fixe du support y passe aussi : une
    # reecriture ne le corrigerait pas davantage (au-dela de ScpStructMax par tour : Set-ScpTrackPost). Rend un int[] par tour.
    # Cout (banc scp-real : +38,9 % de calcul) : sortie immediate quand un tour n a aucun hors classe hors des bouts
    # ignores : OutOfClass brut d Analyze (030), pas encore corrige par Set-ScpTrackPost, compte exactement les x de
    # Classes hors trous (meme cellule, memes bornes 0,35 et 2 a 5), moins ceux des bouts ($edges : classes des bouts de
    # Set-ScpTrackPost, Get-ScpEdgeOoc) ; un hors classe retenu devant etre present dans tous les tours, aucun ne l est.
    # Voisin cherche par recherche dichotomique dans les indices croissants de l autre tour (Array.BinarySearch). $cap >= 0 :
    # sortie des que le compte d un tour depasse $cap ; comptes rendus alors partiels (tour en cause a $cap + 1, tours
    # suivants a 0) : ils ne servent plus qu a signaler la piste (Post.StructOver, minorant du total).
    # Relecture de la finalisation 12.10 : premier intervalle du tour 0 jamais compte (S10, Set-ScpTrackPost : meme critere,
    # classe x hors trou, deja retire) ; il reste un voisin pour les autres tours. Avant : avec $skip 0, il pouvait etre
    # retire deux fois et masquer un autre hors classe du tour 0 (aucun cas sur les 1 920 pistes de v1210\struct-cap).
    $nr = $list.Count; $out = [int[]]::new($nr)
    if ($nr -lt 2) { return $out }
    for ($r = 0; $r -lt $nr; $r++) {
        $nx = [int]$list[$r].OutOfClass
        if ($nx -gt 0 -and $skip -gt 0 -and $null -ne $edges) { $eo = Get-ScpEdgeOoc $fl[$r] $edges[$r] $skip; if ($eo -ge 0) { $nx -= $eo } }
        if ($nx -le 0) { return $out }
    }
    $tol = [int]$script:ScpStructTol
    $xs = New-Object object[] $nr
    for ($r = 0; $r -lt $nr; $r++) {
        $f = $fl[$r]; $n = $f.Length
        $s = [ScpStats]::Classes($f, [double]$list[$r].Cell)
        $ix = [System.Collections.Generic.List[int]]::new()
        $p = if ($skip -lt $n) { $s.IndexOf([char]'x', [math]::Max(0, $skip)) } else { -1 }
        while ($p -ge 0 -and $p -lt $n - $skip) {
            if ($f[$p] -lt 20000) { $ix.Add($p) }
            $p = $s.IndexOf([char]'x', $p + 1)
        }
        $xs[$r] = $ix.ToArray()
    }
    for ($r = 0; $r -lt $nr; $r++) {
        foreach ($p in $xs[$r]) {
            if ($r -eq 0 -and $p -eq 0) { continue }
            $all = $true
            for ($q = 0; $q -lt $nr; $q++) {
                if ($q -eq $r) { continue }
                $t = $tol + [math]::Abs($fl[$r].Length - $fl[$q].Length)
                # Premier indice >= p - t de l autre tour (complement du point d insertion si absent) : voisin s il est <= p + t
                $a = $xs[$q]; $i = [System.Array]::BinarySearch($a, [int]($p - $t))
                if ($i -lt 0) { $i = -$i - 1 }
                if ($i -ge $a.Length -or $a[$i] -gt $p + $t) { $all = $false; break }
            }
            if ($all) { $out[$r]++; if ($cap -ge 0 -and $out[$r] -gt $cap) { return $out } }
        }
    }
    return $out
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
    # des ancres) ; 12.10 : StructOoc (S13, retires, tous tours) ; StructOver (S13 non appliquee, plafond depasse) }. Toute erreur : piste laissee au comptage d avant, comptee dans ScpPostFail (journal : Read-ScpFile).
    $nr = $list.Count
    if ($nr -eq 0 -or $fl.Count -ne $nr -or $fl[0].Length -eq 0) { return }
    foreach ($x in $list) { if ([double]::IsNaN([double]$x.Jitter)) { return } }
    $post = @{ ZoneOoc = 0; ZoneFarNs = 0; First = ''; StabAl = -1; Tried = $false; Zone = $false; ZoneData = $false; PA = $null; PB = $null; StructOoc = 0; StructOver = 0 }
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
            # 12.10 (S13) : hors classe reproductibles d un tour a l autre a la meme position, dans tous les tours : non
            # comptes (StructOoc, Get-ScpStructOoc) ; bouts deja traites par la zone de l index non revisites. Plafond
            # (ScpStructMax, 040) : un tour qui en compte davantage -> aucun retire sur la piste, tout compte comme en
            # 12.9 ; StructOver = reproductibles trouves (tous tours, comptes partiels de Get-ScpStructOoc : au moins
            # ScpStructMax + 1), piste signalee au journal par l appelant
            if ([bool]$script:ScpStructOn -and $nr -ge 2) {
                $smax = [int]$script:ScpStructMax
                $st = if ($post.Zone) { Get-ScpStructOoc $fl $list ([int]$script:ScpRevWin) $smax $edges } else { Get-ScpStructOoc $fl $list 0 $smax }
                $sHi = 0; $sSum = 0
                for ($r = 0; $r -lt $nr; $r++) { $sSum += [int]$st[$r]; if ([int]$st[$r] -gt $sHi) { $sHi = [int]$st[$r] } }
                if ($sHi -gt $smax) { $post.StructOver = $sSum }
                else { for ($r = 0; $r -lt $nr; $r++) { $dOoc[$r] += [int]$st[$r]; $post.StructOoc += [int]$st[$r] } }
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
    for ($r = 0; $r -lt $nr; $r++) { if ($dOoc[$r] -ne 0) { $list[$r].OutOfClass = [math]::Max(0, [int]$list[$r].OutOfClass - $dOoc[$r]) } }   # 12.10 : jamais negatif
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
    # alignement tente mais sans ancres communes (repli sur l ecart du nombre de flux, signale au journal). 12.10 (S13) :
    # StructOoc : hors classe reproductibles retires (tous tours) ; StructOver : plafond ScpStructMax depasse, aucun retire
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 2
            Weak = $false; ShortUnstable = $false; Blocks = 0; Unstable = 0; MaxRun = 0; RunPos = -1; ZoneOoc = 0; ZoneFarNs = 0; StabAligned = $false; StabFallback = $false; StructOoc = 0; StructOver = 0 }
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
        if ($pp.Value.ContainsKey('StructOoc')) { $m.StructOoc = [int]$pp.Value.StructOoc }   # 12.10 (S13)
        if ($pp.Value.ContainsKey('StructOver')) { $m.StructOver = [int]$pp.Value.StructOver }
        if ([int]$pp.Value.StabAl -ge 0) { $m.Stab = [int]$pp.Value.StabAl; $m.StabAligned = $true }
        elseif ($pp.Value.Tried) { $m.StabFallback = $true }
    }
    $m.Asym = [math]::Abs($m.R3 - 1.5) + [math]::Abs($m.R4 - 2.0)
    $m.Score = Get-TrackScore $m                          # 12.10 : meme formule apres correction de l asymetrie (Set-TrackAsymRef)
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

function Get-TrackScore($m) {
    # Note de lecture d une piste (plus basse = mieux) : jitter, asymetrie (x 2000), erreurs, trous, stabilite
    return [math]::Round([double]$m.J + 2000 * [double]$m.Asym + 5 * [double]$m.Ooc + 50 * [double]$m.Dr + [double]$m.Stab, 0)
}

function Get-AsymRefTable([string]$fam, [int]$head, [string]$drive) {
    # 12.10 : asymetrie de reference d une famille pour une tete et un lecteur : courbe par tete de la famille si elle existe,
    # sinon courbe commune, a condition qu elle vienne du meme lecteur (le biais de lecture est celui du lecteur) et qu elle
    # porte le releve (AsymCyl, calibration 12.10) ; cylindre -> (3T/2T - 1,5 ; 4T/2T - 2) ; $null sans reference
    foreach ($k in @("${fam}_h$head", $fam)) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv -or [string]$cv.Drive -ne $drive) { continue }
        if (-not $cv.AsymCyl -or @($cv.AsymCyl).Count -eq 0) { continue }
        $t = @{}
        $cs = @($cv.AsymCyl); $d3 = @($cv.AsymD3); $d4 = @($cv.AsymD4)
        for ($i = 0; $i -lt $cs.Count -and $i -lt $d3.Count -and $i -lt $d4.Count; $i++) { $t[[int]$cs[$i]] = @([double]$d3[$i], [double]$d4[$i]) }
        if ($t.Count -gt 0) { return $t }
    }
    return $null
}

function Get-AsymRefs([string]$drive) {
    # 12.10 : references d asymetrie du lecteur, par famille (std, long) et par tete : cle « famille + tete »
    $r = @{}
    foreach ($fam in 'std', 'long') { foreach ($h in 0, 1) { $r["$fam$h"] = Get-AsymRefTable $fam $h $drive } }
    return $r
}

function Set-TrackAsymRef($m, [int]$cyl, [int]$hd, $refs) {
    # 12.10 : asymetrie corrigee du biais de lecture du lecteur. Constat du 02/11/2026 (TEAC, long track) : les rapports
    # 3T/2T et 4T/2T sont positifs sur toutes les pistes, autant sur le motif de calibration relu a decalage nul que sur
    # l image ecrite : biais de lecture a cette densite, pas une precompensation fausse ; le score (x 2000) en etait gonfle
    # et incomparable d une famille a l autre. Famille d apres la cellule mesuree (long track sous 1 950 ns, standard
    # au-dela ; haute densite sous 1 500 ns : sans reference) ; AsymRaw : valeur mesuree gardee, AsymRef : reference
    # appliquee ; score recalcule. L etat de la piste ne depend pas de l asymetrie : inchange. Vrai si une reference a
    # ete appliquee
    if (-not [bool]$script:QualAsymRefOn) { return $false }   # desactivee par defaut (560 : constat du 02/11/2026 au soir)
    if ($null -eq $refs -or $null -eq $m -or $m.Bad) { return $false }
    $cell = [double]$m.Cell
    if ($cell -lt 1500) { return $false }
    $fam = if ($cell -lt 1950) { 'long' } else { 'std' }
    $t = $refs["$fam$hd"]
    if ($null -eq $t -or -not $t.ContainsKey($cyl)) { return $false }
    $d = $t[$cyl]
    $m.AsymRaw = [double]$m.Asym; $m.AsymRef = @([double]$d[0], [double]$d[1])
    $m.Asym = [math]::Abs([double]$m.R3 - 1.5 - [double]$d[0]) + [math]::Abs([double]$m.R4 - 2.0 - [double]$d[1])
    $m.Score = Get-TrackScore $m
    return $true
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
        $it.Tag = @{ State = $(if ($m.Missing) { 'h2a' } else { 'h2' }); Score = ''; M = $m }   # 12.8 (lot 3b) : icones 16 px (DrawSubItem) ; 12.10 : M, metriques (export)
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
    $it.Tag = @{ State = $(if ($m.Unjudged -and $hl -eq 0) { 'hq' } else { "h$hl" }); Score = "q$lvSc"; M = $m }   # 12.10 : M, metriques de la piste (export du tableau)
    return $it
}

# 12.10 : export du tableau de l onglet Qualite (demande du 01/11/2026 : relever les resultats par piste sans capture
# d ecran). En-tete (libelle, valeur) d apres $script:QualView, puis les colonnes de l ecran et deux de plus : les ecarts
# signes des rapports moyens 3T/2T et 4T/2T a leurs valeurs nominales (1,5 et 2), dont « Asym. » est la somme des valeurs
# absolues ; le signe dit si les intervalles longs sont relus trop longs (+) ou trop courts (-). Valeurs relues dans
# Item.Tag.M (metriques de la piste gardees par New-AlignRow) et ecrites sans separateur de milliers, avec le separateur
# decimal de la langue du poste ; sans Tag.M, texte affiche tel quel
function Get-AlignTableExport {
    $v = $script:QualView
    $r = $v.Res
    $head = New-Object System.Collections.Generic.List[object]
    $head.Add(@((T 'Application'), "Greaseweazle Studio $($script:Version)"))
    $head.Add(@((T 'Export'), (Get-Date -Format 'dd/MM/yyyy HH:mm:ss')))
    $at = if ($v.At) { ([datetime]$v.At).ToString('dd/MM/yyyy HH:mm:ss') } else { '' }
    $kind = switch ([string]$v.Kind) { 'measure' { (T 'Mesure de la disquette') } 'check' { (T 'Contrôle après écriture') } default { '' } }
    if ($v.State -eq 'stale') {
        $kind = (($kind + ' ' + (T '(périmé)')).Trim())
        $why = Get-QualStaleText ([string]$v.Reason) $at
        if ($why) { $kind += " : $why" }
    }
    $head.Add(@((T 'Résultat'), $kind))
    $head.Add(@((T 'Heure du résultat'), $at))
    $ctx = if ($r -and $r.Ctx) { $r.Ctx } else { $null }
    $drive = if ($ctx -and $ctx.Drive) { [string]$ctx.Drive } else { [string]$cmbDrive.Text }
    $head.Add(@((T 'Lecteur'), $drive))
    if ($ctx) { $head.Add(@((T 'Têtes'), [string]$ctx.Heads)); $head.Add(@((T 'Tours'), [string]$ctx.Revs)) }
    if ($r -and $r.HealthText) { $head.Add(@((T 'État du support'), [string]$r.HealthText)) }
    if ($r -and $r.ScoreText) { $head.Add(@((T 'Score'), [string]$r.ScoreText)) }
    if ($script:AlignRefLabel) { $head.Add(@((T 'Référence'), [string]$script:AlignRefLabel)) }
    $cols = @((T 'Piste'), (T 'État'), (T 'Erreurs/tour'), (T 'Trous/tour'), (T 'Stabilité'), (T 'Jitter ns'), 'Score', (T 'vs réf'), 'Asym.', (T 'Écart 3T'), (T 'Écart 4T'), (T 'Cellule ns'))
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($it in @($lvAl.Items)) {
        $m = if ($it.Tag -is [hashtable] -and $it.Tag.ContainsKey('M')) { $it.Tag.M } else { $null }
        $sub = @(0..9 | ForEach-Object { if ($_ -lt $it.SubItems.Count) { [string]$it.SubItems[$_].Text } else { '' } })
        if ($m -and -not $m.Bad) {
            $rows.Add(@($sub[0], $sub[1], ('{0:0.0}' -f [double]$m.Ooc), ('{0:0.0}' -f [double]$m.Dr), ('{0:0}' -f [double]$m.Stab), ('{0:0}' -f [double]$m.J),
                       ('{0:0}' -f [double]$m.Score), $sub[7], ('{0:0.000}' -f [double]$m.Asym), ('{0:+0.000;-0.000;0.000}' -f ([double]$m.R3 - 1.5)),
                       ('{0:+0.000;-0.000;0.000}' -f ([double]$m.R4 - 2.0)), ('{0:0}' -f [double]$m.Cell)))
        } else {
            $rows.Add(@($sub[0], $sub[1], $sub[2], $sub[3], $sub[4], $sub[5], $sub[6], $sub[7], $sub[8], '-', '-', $sub[9]))
        }
    }
    $nAr = @(@($lvAl.Items) | Where-Object { $_.Tag -is [hashtable] -and $_.Tag.ContainsKey('M') -and $_.Tag.M -and $null -ne $_.Tag.M.AsymRef }).Count
    if ($nAr -gt 0) { $head.Add(@((T 'Asymétrie'), ((T "corrigée du biais de lecture du lecteur sur {0} piste(s), d'après le motif de sa calibration") -f "$nAr"))) }
    $head.Add(@((T 'Pistes'), [string]$rows.Count))
    # .ToArray() et non @() : sous PowerShell 7, @() sur une List[object] d elements tableaux echoue (liaison dynamique)
    return @{ Head = $head.ToArray(); Cols = $cols; Rows = $rows.ToArray() }
}

function Format-CsvField([string]$s, [string]$sep) {
    # Champ entre guillemets (guillemets doubles) s il contient le separateur, un guillemet ou un saut de ligne (RFC 4180)
    if ($s.IndexOf($sep) -ge 0 -or $s.IndexOf('"') -ge 0 -or $s.IndexOf("`n") -ge 0 -or $s.IndexOf("`r") -ge 0) { return '"' + $s.Replace('"', '""') + '"' }
    return $s
}

function ConvertTo-AlignTableText($x, [string]$sep) {
    # Une ligne par entree de l en-tete (libelle, valeur), puis la ligne des colonnes, puis une ligne par piste ; CRLF
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($h in $x.Head) { $lines.Add((@($h | ForEach-Object { Format-CsvField ([string]$_) $sep }) -join $sep)) }
    $lines.Add((@($x.Cols | ForEach-Object { Format-CsvField ([string]$_) $sep }) -join $sep))
    foreach ($r in $x.Rows) { $lines.Add((@($r | ForEach-Object { Format-CsvField ([string]$_) $sep }) -join $sep)) }
    return (($lines -join "`r`n") + "`r`n")
}

function Get-AlignTableSep([string]$path) {
    # Tabulation pour un fichier .txt ; sinon le separateur de liste de la langue du poste (« ; » en francais, « , » en
    # anglais), celui que le tableur du poste attend dans un .csv
    if ($path -and $path -match '\.txt$') { return "`t" }
    $s = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ListSeparator
    if (-not $s) { $s = ';' }
    return $s
}

function Export-AlignTable([string]$path) {
    # Fichier UTF-8 avec BOM (accents lus par le tableur) ; rend le nombre de pistes ecrites, 0 sans tableau
    $x = Get-AlignTableExport
    if ($x.Rows.Count -eq 0) { Append-Log (T 'Qualité : aucun tableau à exporter (lancez une mesure ou un contrôle).'); return 0 }
    [System.IO.File]::WriteAllText($path, (ConvertTo-AlignTableText $x (Get-AlignTableSep $path)), (New-Object System.Text.UTF8Encoding($true)))
    Append-Log ((T "Qualité : tableau de {0} piste(s) exporté dans {1}.") -f "$($x.Rows.Count)", "$path")
    return $x.Rows.Count
}

function Copy-AlignTable {
    # Presse-papiers, champs separes par des tabulations : se colle tel quel dans un tableur ou un message
    $x = Get-AlignTableExport
    if ($x.Rows.Count -eq 0) { Append-Log (T 'Qualité : aucun tableau à copier (lancez une mesure ou un contrôle).'); return 0 }
    [System.Windows.Forms.Clipboard]::SetText((ConvertTo-AlignTableText $x "`t"))
    Append-Log ((T "Qualité : tableau de {0} piste(s) copié dans le presse-papiers.") -f "$($x.Rows.Count)")
    return $x.Rows.Count
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
        $total = 0.0; $count = 0; $zo = 0; $zt = 0; $zf = 0; $fb = @(); $so = 0; $sot = 0; $sov = @()   # 12.10 (S13) : so / sot / sov
        $arefs = Get-AsymRefs ([string]$cmbDrive.Text); $nRef = 0     # 12.10 : asymetrie corrigee du biais de lecture
        foreach ($tn in ($tracks.Keys | Sort-Object)) {
            $st = $tracks[$tn]; $cyl = [math]::Floor($tn / 2); $hd = $tn % 2; $key = "$cyl.$hd"
            $lab = "$cyl.$hd"
            $m = Get-TrackMetrics $st
            if (Set-TrackAsymRef $m $cyl $hd $arefs) { $nRef++ }
            if ($m.ZoneOoc -gt 0) { $zo += $m.ZoneOoc; $zt++; if ($m.ZoneFarNs -gt $zf) { $zf = $m.ZoneFarNs } }
            if ($m.StructOoc -gt 0) { $so += $m.StructOoc; $sot++ }
            if ($m.StructOver -gt 0) { $sov += $lab }
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
            # 12.10 (lot 1, D8) : meilleur score par piste retire avec le graphique, seul a le lire ; meilleur global garde
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
        if ($nRef -gt 0) { Append-Log ((T "Mesure : asymétrie et score corrigés du biais de lecture du lecteur {0} sur {1} piste(s), d'après le motif de sa calibration (famille d'après la cellule mesurée).") -f "$($cmbDrive.Text)", "$nRef") }
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
            # 12.10 (S13) : raccord d ecriture d une longue piste, protection a intervalles fixes, petit defaut fixe du
            # support ; pistes au-dela du plafond ScpStructMax par tour : tout compte, liste a part
            if ($so -gt 0) { Append-Log ((T "Mesure : {0} intervalle(s) hors classe reproductibles d'un tour à l'autre à la même position, sur {1} piste(s), non compté(s) : raccord d'écriture d'une longue piste ou protection ; un petit défaut fixe du support (jusqu'à {2} intervalles par tour) y passerait aussi.") -f "$so", "$sot", "$($script:ScpStructMax)") }
            if ($sov.Count -gt 0) { Append-Log ((T "Mesure : {0} piste(s) avec plus de {1} intervalles hors classe reproductibles par tour, tous comptés comme erreurs (au-delà d'un raccord d'écriture ou d'une protection : défaut du support ou écriture à revoir) : {2}.") -f "$($sov.Count)", "$($script:ScpStructMax)", "$(Format-TrackList $sov)") }
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
    Set-QualityResult $res                                # 12.8 (lot 3a) : carte et tableau en couleurs (12.9 : sans graphique)

    if ($script:AlignLoop) { $script:AlignNextAt = (Get-Date).AddSeconds([int]$numAlPause.Value) }
}
