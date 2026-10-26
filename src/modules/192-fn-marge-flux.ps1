# ============================== FONCTIONS : MARGE COMPTEE DES FLUX ==============

# 12.8.1 (lot A, spec-1281.md § B.1) : marge fixe Mfix d une piste relue, pour la mesure de la disquette sur l image (276).
# Les intervalles d un tour (ns, multiples de la resolution du SCP, ScpStats.Decode) sont tries une fois (tri natif, sur
# une copie) ; chaque comptage est une recherche dichotomique native (Array.BinarySearch) sur une cle entiere decalee,
# jamais egale a un element. Horloge fixe du tour : T0 = duree / cellules de l image (ncell0, Get-PatternBits), sauf a plus
# de 5 % de la cellule des 2T (comme ScpStats.Analyze sans motif) ; cellules du tour = somme des arrondis f / T0, une
# recherche par classe ; T = duree / cellules. Marge d un intervalle de classe 2 a 4 : (1/2 - |f/T - k|) T, nulle hors de
# [1,5 T ; 4,5 T[ ; Mfix = quantile 1e-3 des marges des tours regroupes (rang exact, comme rpm_analyse.q1e3), par
# dichotomie sur m. Reference executable : v1281\verif_spec1281.py (ecart de 9,3e-7 ns a rpm_analyse sur 240 pistes
# reelles). Aucun Add-Type ni boucle sur les octets : Decode (C#) reste la seule conversion d octets en intervalles.

function Get-ScpRevTable([byte[]]$d) {
    # Table des tours d un SCP deja lu (memes champs que Read-ScpFile, 190) : resolution (ns par tic), tours par piste et,
    # par numero de piste, la liste des tours @{ Off (octet des donnees) ; Len (mots de 16 bits) ; DurNs (index x res) }.
    # Piste absente (decalage nul), en-tete de piste ou tour hors du fichier : ignores. $null : fichier trop court ou
    # sans signature SCP. Sans type C# : testable au niveau 2 du banc (logic-1281.ps1)
    if ($null -eq $d -or $d.Length -lt 16 + 4 * 168 -or [System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { return $null }
    $revs = [int]$d[5]; $res = ([int]$d[11] + 1) * 25
    $tracks = @{}
    for ($t = 0; $t -lt 168; $t++) {
        [int64]$o = [BitConverter]::ToUInt32($d, 16 + 4 * $t)
        if ($o -eq 0 -or $o + 4 + 12 * $revs -gt $d.Length -or [System.Text.Encoding]::ASCII.GetString($d, [int]$o, 3) -ne 'TRK') { continue }
        $list = @()
        for ($r = 0; $r -lt $revs; $r++) {
            [int64]$idx  = [BitConverter]::ToUInt32($d, [int]($o + 4 + 12 * $r))
            [int64]$ln   = [BitConverter]::ToUInt32($d, [int]($o + 8 + 12 * $r))
            [int64]$doff = [BitConverter]::ToUInt32($d, [int]($o + 12 + 12 * $r))
            if ($o + $doff + 2 * $ln -gt $d.Length) { continue }
            $list += @{ Off = [int]($o + $doff); Len = [int]$ln; DurNs = [double]$idx * $res }
        }
        $tracks[[int]$d[$o + 3]] = $list
    }
    return @{ Res = $res; Revs = $revs; Tracks = $tracks }
}

function Read-ScpTrackRevs([string]$path) {
    # Tours bruts de chaque piste d un SCP (relecture de la mesure sur l image) : memes lectures que Read-ScpFile (190),
    # sans Analyze ni Instability. Sortie : @{ Res ; Revs ; Tracks = @{ numero de piste -> List[object] des tours
    # @{ Flux = [int[]] (ns) ; DurNs } } } ; $null : fichier trop court ou sans signature SCP
    $d = [System.IO.File]::ReadAllBytes($path)
    $tt = Get-ScpRevTable $d
    if ($null -eq $tt) { return $null }
    $tracks = @{}
    foreach ($tn in @($tt.Tracks.Keys)) {
        $l = New-Object 'System.Collections.Generic.List[object]'
        foreach ($rv in @($tt.Tracks[$tn])) { $l.Add(@{ Flux = [ScpStats]::Decode($d, [int]$rv.Off, [int]$rv.Len, [int]$tt.Res); DurNs = [double]$rv.DurNs }) }
        $tracks[$tn] = $l
    }
    return @{ Res = $tt.Res; Revs = $tt.Revs; Tracks = $tracks }
}

function Get-SortedCountLe([int[]]$s, [double]$y, [int]$res) {
    # #{f <= y} dans le tableau trie : cle floor(y/res)*res + 1, jamais egale a un element (multiples de res)
    $key = [math]::Floor($y / $res) * $res + 1
    if ($key -ge [int]::MaxValue) { return $s.Length }
    if ($key -le 0) { return 0 }
    $r = [Array]::BinarySearch($s, [int]$key)    # [int] obligatoire : une cle Int64 ferait echouer le comparateur
    return (-$r - 1)
}

function Get-SortedCountLt([int[]]$s, [double]$y, [int]$res) {
    # #{f < y} dans le tableau trie : cle ceil(y/res)*res - 1
    $key = [math]::Ceiling($y / $res) * $res - 1
    if ($key -ge [int]::MaxValue) { return $s.Length }
    if ($key -lt 0) { return 0 }
    $r = [Array]::BinarySearch($s, [int]$key)
    return (-$r - 1)
}

function Get-FluxRevPrep([int[]]$flux, [double]$durNs, [int]$res, [int]$ncell0, [double]$t0Tol = 0.05) {
    # Tour prepare : intervalles tries (S), horloge fixe T0 (duree / ncell0, ou cellule des 2T a plus de t0Tol d ecart :
    # piste d une autre longueur, faux gw du banc), cellules, T, intervalles hors classe Z (hors de [1,5 T ; 4,5 T[) et
    # rangs des bornes 1,5 T et 4,5 T. $null : moins de 3 intervalles, duree ou cellules nulles, plus de 4 096 classes
    if ($null -eq $flux -or $flux.Length -lt 3 -or $durNs -le 0 -or $ncell0 -le 0) { return $null }
    $s = [int[]]$flux.Clone(); [Array]::Sort($s)                       # tri natif, copie : le flux de Decode reste intact
    $n = $s.Length
    $t0 = $durNs / $ncell0; $src = 'duree'
    # Cellule des 2T, comme ScpStats.Analyze a cellsPerRev = 0 : element de rang floor(n2/2) des intervalles de 3 000 a
    # 5 000 ns exclus, divise par 2, si n2 >= 50
    $a = Get-SortedCountLe $s 3000.0 $res; $b = Get-SortedCountLt $s 5000.0 $res
    if ($b - $a -ge 50) {
        $med = [double]$s[$a + [int][math]::Floor(($b - $a) / 2)] / 2.0
        if ([math]::Abs($t0 / $med - 1.0) -gt $t0Tol) { $t0 = $med; $src = 'mediane' }
    }
    # Cellules = somme des arrondis f/T0 (classe k : (k - 1/2) T0 <= f < (k + 1/2) T0), une recherche par classe non vide :
    # k = classe du plus petit intervalle restant, tous les intervalles de cette classe comptes d un coup
    [int64]$cells = 0
    $lo = Get-SortedCountLt $s (0.5 * $t0) $res
    $g = 0
    while ($lo -lt $n -and $g -lt 4096) {
        $k = [math]::Floor($s[$lo] / $t0 + 0.5)
        $hi = Get-SortedCountLt $s (($k + 0.5) * $t0) $res
        $cells += [int64]$k * ($hi - $lo); $lo = $hi; $g++
    }
    if ($lo -lt $n -or $cells -le 0) { return $null }                 # plus de 4 096 classes : bruit, piste vide
    $T = $durNs / $cells
    $lt15 = Get-SortedCountLt $s (1.5 * $T) $res; $lt45 = Get-SortedCountLt $s (4.5 * $T) $res
    return @{ S = $s; N = $n; T = $T; T0 = $t0; T0Src = $src; Cells = $cells; Z = [int64]($lt15 + ($n - $lt45)); Lt15 = $lt15; Lt45 = $lt45 }
}

function Get-FluxMarginCount($r, [double]$m, [int]$res) {
    # Nombre d intervalles de marge <= m dans le tour prepare $r : marge nulle (Z), puis les quatre fenetres de demi-largeur
    # m autour des limites de decodage 1,5 T, 2,5 T, 3,5 T et 4,5 T (disjointes tant que m < T/2)
    $s = $r.S; $T = [double]$r.T
    [int64]$c = $r.Z                                                              # marge nulle
    $c += (Get-SortedCountLe $s (1.5 * $T + $m) $res) - $r.Lt15                   # au-dessus de 1,5 T
    $c += $r.Lt45 - (Get-SortedCountLt $s (4.5 * $T - $m) $res)                   # au-dessous de 4,5 T
    $c += (Get-SortedCountLe $s (2.5 * $T + $m) $res) - (Get-SortedCountLt $s (2.5 * $T - $m) $res)
    $c += (Get-SortedCountLe $s (3.5 * $T + $m) $res) - (Get-SortedCountLt $s (3.5 * $T - $m) $res)
    return $c
}

function Get-FluxMarginQ($preps, [int]$res, [double]$q = 1e-3, [double]$tol = 1e-6, [int]$maxIt = 50) {
    # Quantile q de la marge sur les tours regroupes, rang exact : (k + 1)-ieme plus petite marge, k = floor(q n), comme
    # rpm_analyse.q1e3 ; dichotomie sur m dans [0 ; T/2[ (les quatre fenetres ne se recouvrent pas tant que m < T/2).
    # Sortie : Mfix (0 si les marges nulles suffisent au rang, NaN sans tour), N, Z, K (rang), It (iterations)
    $rs = @($preps | Where-Object { $null -ne $_ })
    if ($rs.Count -eq 0) { return @{ Mfix = [double]::NaN; N = 0; Z = 0; K = 0; It = 0 } }
    [int64]$n = 0; [int64]$z = 0; $tMax = 0.0
    foreach ($r in $rs) { $n += $r.N; $z += $r.Z; if ([double]$r.T -gt $tMax) { $tMax = [double]$r.T } }
    [int64]$k = [math]::Floor($q * $n)
    [int64]$c0 = 0; foreach ($r in $rs) { $c0 += Get-FluxMarginCount $r 0.0 $res }
    if ($c0 -ge $k + 1) { return @{ Mfix = 0.0; N = $n; Z = $z; K = $k; It = 0 } }
    $lo = 0.0; $hi = 0.5 * $tMax; $it = 0
    while (($hi - $lo) -gt $tol -and $it -lt $maxIt) {
        $mid = ($lo + $hi) / 2; [int64]$c = 0
        foreach ($r in $rs) { $c += Get-FluxMarginCount $r $mid $res }
        if ($c -ge $k + 1) { $hi = $mid } else { $lo = $mid }
        $it++
    }
    return @{ Mfix = $hi; N = $n; Z = $z; K = $k; It = $it }
}

function Get-ContentTrackStats($revs, [int]$res, [int]$ncell0) {
    # Bilan d une piste relue (ses tours, Read-ScpTrackRevs) : tours exploitables (Get-FluxRevPrep), marge fixe Mfix de
    # leurs intervalles regroupes, intervalles N et hors classe Z (marge nulle), cellules et intervalles par tour, T moyen,
    # iterations de la dichotomie ; T0Src : origine de l horloge de chaque tour ('duree' ou 'mediane'). Sans tour
    # exploitable : NRev = 0, Mfix = NaN
    $preps = New-Object 'System.Collections.Generic.List[object]'
    foreach ($rv in $revs) {
        if ($null -eq $rv -or $null -eq $rv.Flux) { continue }
        $p = Get-FluxRevPrep ([int[]]$rv.Flux) ([double]$rv.DurNs) $res $ncell0
        if ($null -ne $p) { $preps.Add($p) }
    }
    if ($preps.Count -eq 0) { return @{ NRev = 0; Mfix = [double]::NaN; N = [int64]0; Z = [int64]0; ZFrac = [double]::NaN; Cells = [int64[]]@(); Flux = [int[]]@(); T = [double]::NaN; It = 0; T0Src = [string[]]@() } }
    $mq = Get-FluxMarginQ $preps $res
    $sumT = 0.0; foreach ($p in $preps) { $sumT += [double]$p.T }
    return @{ NRev = $preps.Count; Mfix = [double]$mq.Mfix; N = [int64]$mq.N; Z = [int64]$mq.Z; ZFrac = [double]$mq.Z / [double]$mq.N
              Cells = [int64[]]@($preps | ForEach-Object { [int64]$_.Cells }); Flux = [int[]]@($preps | ForEach-Object { [int]$_.N })
              T = $sumT / $preps.Count; It = [int]$mq.It; T0Src = [string[]]@($preps | ForEach-Object { [string]$_.T0Src }) }
}
