# ============================== FONCTIONS : MESURE SUR L IMAGE, CALCUL ==========

# 12.8.1 (lot A, spec-1281.md § A et B.2) : calcul de la mesure de la disquette sur l image, sans interface ni texte T().
# Blocs de cylindres et plan en carre latin (A.3, A.4) ; pistes exclues avant l ecriture (IPF) et apres la relecture
# (A.2) ; donnees minimales et facteur k* de chaque tete (effets fixes passe + cylindre, quadratique en k, comme
# revue_sony.Jeu et motif_analyse.py) ; facteur applique a un profil --precomp (A.10, C.3) ; k du lecteur, mediane des
# 3 derniers k* mesures du lecteur, de la famille et de la tete (decision de l utilisateur du 25/10/2026, au lieu du
# dernier de la spec) ; correction « lecteur cible » Dk (C.4) ; conversions de la configuration (C.5) ; arret « Failed to
# verify Track » de gw (A.7). Constantes en parametres, defauts de 565 (B.4). References executables :
# v1281\verif_spec1281.py (plan, ajustement) et v1281\verif_scaled.py (profils mis a l echelle).

function Get-ContentBlocks([int]$nCyl, [int]$nBlocks = 8, [int]$len = 5, [int]$maxCyl = 80, [int]$minBlocks = 4) {
    # Blocs de len cylindres mesures (A.3) : B = floor(min(nCyl, maxCyl) / len) ; B >= nBlocks : blocs
    # floor(i (B - 1) / (nBlocks - 1) + 1/2), i = 0..nBlocks-1 (les deux bords et des blocs repartis entre eux) ;
    # minBlocks <= B < nBlocks : tous ; moins : image non mesurable (Ok = $false). Cylindres maxCyl et au-dela jamais
    # mesures (pistes vides de l IPF, courbe V prolongee). Cyls : cylindres des blocs, dans l ordre des blocs
    if ($len -le 0 -or $nBlocks -le 0) { return @{ Ok = $false; Idx = [int[]]@(); Cyls = [int[]]@() } }
    $nb = [int][math]::Floor([math]::Min($nCyl, $maxCyl) / [double]$len)
    if ($nb -lt [math]::Max(1, $minBlocks)) { return @{ Ok = $false; Idx = [int[]]@(); Cyls = [int[]]@() } }
    if ($nb -ge $nBlocks -and $nBlocks -ge 2) { $idx = @(0..($nBlocks - 1) | ForEach-Object { [int][math]::Floor($_ * ($nb - 1) / [double]($nBlocks - 1) + 0.5) } | Sort-Object -Unique) }
    elseif ($nb -ge $nBlocks) { $idx = @(0) }
    else { $idx = @(0..($nb - 1)) }
    $cyls = foreach ($b in $idx) { for ($j = 0; $j -lt $len; $j++) { $len * $b + $j } }
    return @{ Ok = $true; Idx = [int[]]$idx; Cyls = [int[]]@($cyls) }
}

function Get-ContentLevel([int]$b, [int]$p, [double[]]$levels) {
    # Niveau k du bloc de rang b (0..B-1) a la passe p (0..2) : carre latin, chaque bloc recoit chaque niveau une fois et
    # deux blocs voisins n ont jamais le meme niveau a une passe
    return [double]$levels[($b + $p) % $levels.Count]
}

function Get-ContentPlan([int[]]$v0, [int[]]$v1, [int]$nCyl, [double[]]$levels, [int]$hard, $preSkip = @{}) {
    # Plan de la mesure (A.4), meme plan pour les deux tetes : passe p (une par niveau), tete h, cylindres de la tete (sans
    # les cles 'c.h' de $preSkip), niveau du bloc levels[(rang + p) mod n] et valeur ecrite w = max(0, min(hard,
    # round(k x V_h(c)))) (arrondi au pair), V bornee a 0..hard (comme Get-LevelRef ; au-dela de la courbe, sa derniere
    # valeur) ; Spec : profil --precomp de la passe et de la tete (Get-BracketSpec : entrees c=w triees, jointes par :).
    # NCylHead : cylindres ecrits par tete a chaque passe
    $bl = Get-ContentBlocks $nCyl
    $lv = [double[]]@($levels)
    $vs = @{ 0 = [int[]]@($v0); 1 = [int[]]@($v1) }
    if (-not $bl.Ok -or $lv.Count -eq 0 -or $vs[0].Count -eq 0 -or $vs[1].Count -eq 0) { return @{ Ok = $false; Blocks = $bl.Idx; Cyls = $bl.Cyls; Levels = $lv; Pass = @(); NCylHead = @{ 0 = 0; 1 = 0 } } }
    if ($null -eq $preSkip) { $preSkip = @{} }
    $len = [int]($bl.Cyls.Count / $bl.Idx.Count)
    $passes = @(); $nh = @{ 0 = 0; 1 = 0 }
    for ($p = 0; $p -lt $lv.Count; $p++) {
        $hh = @{}
        foreach ($h in 0, 1) {
            $v = $vs[$h]; $cs = New-Object 'System.Collections.Generic.List[int]'; $w = @{}; $kk = @{}
            for ($bi = 0; $bi -lt $bl.Idx.Count; $bi++) {
                $k = Get-ContentLevel $bi $p $lv
                for ($j = 0; $j -lt $len; $j++) {
                    $c = [int]$bl.Cyls[$bi * $len + $j]
                    if ($preSkip.Contains("$c.$h")) { continue }
                    $vc = if ($c -lt $v.Count) { $v[$c] } else { $v[$v.Count - 1] }
                    $vc = [math]::Max(0, [math]::Min($hard, $vc))
                    $w[$c] = [int][math]::Max(0.0, [math]::Min([double]$hard, [math]::Round($k * $vc)))
                    $kk[$c] = $k; $cs.Add($c)
                }
            }
            $cyls = [int[]]@($cs | Sort-Object)
            $hh[$h] = @{ Cyls = $cyls; W = $w; K = $kk; Spec = $(if ($cyls.Count) { Get-BracketSpec $w } else { '' }) }
            $nh[$h] = $cyls.Count
        }
        $passes += @{ H = $hh }
    }
    return @{ Ok = $true; Blocks = $bl.Idx; Cyls = $bl.Cyls; Levels = $lv; Pass = $passes; NCylHead = $nh }
}

function Get-IpfTrackInfo([string]$path) {
    # Enregistrements IMGE d un IPF (meme parcours que Get-ImageTrackSet, 150 ; lecture des champs seulement) :
    # 'c.h' -> @{ Bits (trkbits) ; Blocks (blkcnt, 0 = piste vide) ; Den (densite, offset 8 des donnees : 1 bruit, 2 auto,
    # 3 et plus protections Copylock, Speedlock... valeurs a confirmer, spec § H.13) } ; $null : illisible ou sans CAPS
    try {
        $d = [System.IO.File]::ReadAllBytes($path)
        if ($d.Length -lt 12 -or [System.Text.Encoding]::ASCII.GetString($d, 0, 4) -ne 'CAPS') { return $null }
        $info = @{}; $pos = 0
        while ($pos + 12 -le $d.Length) {
            $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
            if ($ln -lt 12) { break }
            if ($id -eq 'IMGE' -and $pos + 12 + 44 -le $d.Length) {
                $cyl  = Get-BE32 $d ($pos + 12)          # piste (cylindre)
                $side = Get-BE32 $d ($pos + 16)          # face
                $den  = Get-BE32 $d ($pos + 20)          # densite
                $bits = Get-BE32 $d ($pos + 12 + 36)     # bits de la piste
                $blk  = Get-BE32 $d ($pos + 12 + 40)     # nombre de blocs : 0 = piste vide
                if ($cyl -lt 200 -and $side -le 1) { $info["$cyl.$side"] = @{ Bits = [int64]$bits; Blocks = [int64]$blk; Den = [int64]$den } }
            } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
            $pos += $ln
        }
        return $info
    } catch { return $null }
}

function Get-ContentImageSkip([string]$img, [int[]]$cyls) {
    # Pistes des cylindres mesures exclues avant l ecriture (A.2), 'c.h' -> raison : 'absente' (hors de Get-ImageTrackSet :
    # IPF blkcnt ou trkbits nul, cylindre hors de l image), 'longue' (IPF : trkbits > 1,02 x mediane des trkbits de
    # l image, meme rang que Get-IpfCellInfo), 'protegee' (IPF : densite autre que 2, auto). Image sans table de pistes
    # lisible (IMG, ST, DSK...) : aucune exclusion, gw encode lui-meme du MFM standard
    $skip = @{}
    $set = Get-ImageTrackSet $img
    $ipf = $null; $med = 0
    if ([System.IO.Path]::GetExtension($img).ToLower() -eq '.ipf') {
        $ipf = Get-IpfTrackInfo $img
        if ($ipf) {
            $bs = @($ipf.Values | Where-Object { $_.Blocks -gt 0 -and $_.Bits -gt 0 } | ForEach-Object { [int64]$_.Bits } | Sort-Object)
            if ($bs.Count) { $med = [int64]$bs[[int]($bs.Count / 2)] }
        }
    }
    foreach ($c in @($cyls)) {
        foreach ($h in 0, 1) {
            $key = "$c.$h"
            if ($set -and -not $set.ContainsKey($key)) { $skip[$key] = 'absente'; continue }
            if ($ipf -and $ipf.ContainsKey($key)) {
                $r = $ipf[$key]
                if ($r.Blocks -le 0 -or $r.Bits -le 0) { $skip[$key] = 'absente' }
                elseif ($med -gt 0 -and $r.Bits -gt 1.02 * $med) { $skip[$key] = 'longue' }
                elseif ($r.Den -ne 2) { $skip[$key] = 'protegee' }
            }
        }
    }
    return $skip
}

function Get-ContentExclusions($obs, [double]$zMax = 5e-4, [double]$cellsTol = 0.02, [double]$fluxMin = 0.5) {
    # Pistes exclues apres la relecture (A.2), pour toute la mesure (aux 3 niveaux), 'c.h' -> raison, d apres les lectures
    # de la piste aux passes ($obs : @{ C ; H ; P ; NRev ; N ; Z ; Cells ; Flux }) ; medianes prises sur toutes les lectures
    # a tour exploitable de la mesure :
    #  - 'vide' : aucune lecture a tour exploitable, ou intervalles moyens par tour sous fluxMin x la mediane a CHAQUE
    #    lecture (piste effacee ou non formatee) ;
    #  - 'longueur' : mediane des cellules par tour de la piste hors de [1 - cellsTol ; 1 + cellsTol] x la mediane ;
    #  - 'nonmfm' : MINIMUM sur les lectures de Z/N au-dessus de zMax (une piste mal ecrite a un seul niveau reste dans
    #    la mesure : sa marge basse est l information cherchee).
    $per = [ordered]@{}
    $fl = New-Object 'System.Collections.Generic.List[double]'; $ce = New-Object 'System.Collections.Generic.List[double]'
    foreach ($o in $obs) {
        if ($null -eq $o) { continue }
        $key = "$([int]$o.C).$([int]$o.H)"
        if (-not $per.Contains($key)) { $per[$key] = New-Object 'System.Collections.Generic.List[object]' }
        $fx = @($o.Flux | Where-Object { $null -ne $_ }); $cx = @($o.Cells | Where-Object { $null -ne $_ })
        if ([int]$o.NRev -gt 0 -and [double]$o.N -gt 0 -and $fx.Count -gt 0 -and $cx.Count -gt 0) {
            $f = 0.0; foreach ($x in $fx) { $f += [double]$x }; $f /= $fx.Count
            $mc = Get-Median $cx
            $per[$key].Add(@{ Flux = $f; Cells = $mc; ZFrac = [double]$o.Z / [double]$o.N })
            $fl.Add($f); $ce.Add($mc)
        }
    }
    $mFlux = Get-Median $fl; $mCells = Get-Median $ce
    $ex = @{}
    foreach ($key in $per.Keys) {
        $rs = $per[$key]
        if ($rs.Count -eq 0) { $ex[$key] = 'vide'; continue }
        $fMax = 0.0; $zMin = [double]::PositiveInfinity; $cs = @()
        foreach ($r in $rs) { if ($r.Flux -gt $fMax) { $fMax = $r.Flux }; if ($r.ZFrac -lt $zMin) { $zMin = $r.ZFrac }; $cs += $r.Cells }
        if ($fMax -lt $fluxMin * $mFlux) { $ex[$key] = 'vide' }
        elseif ($mCells -gt 0 -and [math]::Abs((Get-Median $cs) / $mCells - 1.0) -gt $cellsTol) { $ex[$key] = 'longueur' }
        elseif ($zMin -gt $zMax) { $ex[$key] = 'nonmfm' }
    }
    return $ex
}

function Get-ContentHeadCheck($rows, [int]$minCyl = 20, [int]$minLevelCyl = 6) {
    # Donnees minimales d une tete (A.2), lignes retenues @{ P ; C ; K ; Y } : au moins minCyl cylindres a 2 lectures ou
    # plus ('peu' sinon) ; parmi eux, 3 niveaux au moins (la quadratique en k en demande 3), chacun sur minLevelCyl
    # cylindres au moins ('niveaux' sinon)
    $byC = @{}
    foreach ($r in $rows) {
        if ($null -eq $r) { continue }
        $c = [int]$r.C
        if (-not $byC.ContainsKey($c)) { $byC[$c] = New-Object 'System.Collections.Generic.List[object]' }
        $byC[$c].Add($r)
    }
    $cs = @($byC.Keys | Where-Object { $byC[$_].Count -ge 2 })
    if ($cs.Count -lt $minCyl) { return @{ Ok = $false; NCyl = $cs.Count; Why = 'peu' } }
    $lv = @{}
    foreach ($c in $cs) { foreach ($k in @($byC[$c] | ForEach-Object { [int64][math]::Round([double]$_.K * 1e6) } | Sort-Object -Unique)) { $lv[$k] = 1 + [int]$lv[$k] } }
    if ($lv.Count -lt 3 -or @($lv.Values | Where-Object { $_ -lt $minLevelCyl }).Count -gt 0) { return @{ Ok = $false; NCyl = $cs.Count; Why = 'niveaux' } }
    return @{ Ok = $true; NCyl = $cs.Count; Why = '' }
}

function Get-ContentFactor($rows, [double]$kMin, [double]$kMax = 1.0) {
    # Facteur k* d une tete (B.2) : y = a_passe + g_cylindre + b1 u + b2 u^2, u = k - 1, sur les lignes @{ P ; C ; K ; Y }
    # retenues. Passes dans l ordre de premiere apparition, la premiere en reference ; cylindre absorbe exactement
    # (colonnes et y centres dans chaque cylindre, cylindre a moins de 2 lignes ignore). Sommet de la parabole si b2 < 0
    # (erreur-type par la methode delta), sinon +Inf ou -Inf du cote ou la marge augmente ; K = sommet borne a
    # [kMin ; kMax] ; Gain = marge a K moins marge a k = 1 (ns) ; Flat : |b1| < 2 SeB1 et |b2| < 2 SeB2. Avec 3 niveaux, la
    # quadratique passe par les 3 moyennes ajustees. Rend toujours une table avec Ok (Why : 'niveaux', 'singulier', 'ddl')
    $rs = @($rows | Where-Object { $null -ne $_ })
    $passes = New-Object 'System.Collections.Generic.List[string]'
    foreach ($r in $rs) { $p = [string]$r.P; if (-not $passes.Contains($p)) { $passes.Add($p) } }
    $nan = [double]::NaN
    $out = @{ Ok = $false; Why = ''; K = $nan; KVertex = $nan; Ext = $false; Bound = ''; Flat = $false; B1 = $nan; B2 = $nan; SeB1 = $nan; SeB2 = $nan
              SeK = $nan; Gain = $nan; S = $nan; N = 0; NCyl = 0; Passes = [string[]]$passes.ToArray(); PassEff = @{} }
    $np = $passes.Count; $q = [math]::Max(0, $np - 1) + 2; $iu = $q - 2; $iu2 = $q - 1
    # Groupes par cylindre (ordre des lignes garde dans chaque groupe), cylindres croissants
    $byC = @{}
    foreach ($r in $rs) { $c = [int]$r.C; if (-not $byC.ContainsKey($c)) { $byC[$c] = New-Object 'System.Collections.Generic.List[object]' }; $byC[$c].Add($r) }
    $Gm = New-Object 'double[][]' $q; for ($i = 0; $i -lt $q; $i++) { $Gm[$i] = New-Object double[] $q }
    $gv = New-Object double[] $q; $yy = 0.0; $n = 0; $ncyl = 0
    foreach ($c in @($byC.Keys | Sort-Object)) {
        $grp = $byC[$c]; $m = $grp.Count
        if ($m -lt 2) { continue }
        $ncyl++
        $Xr = New-Object 'double[][]' $m; $Yr = New-Object double[] $m
        for ($j = 0; $j -lt $m; $j++) {
            $r = $grp[$j]; $row = New-Object double[] $q
            for ($i = 1; $i -lt $np; $i++) { if ([string]$r.P -eq $passes[$i]) { $row[$i - 1] = 1.0 } }
            $u = [double]$r.K - 1.0; $row[$iu] = $u; $row[$iu2] = $u * $u
            $Xr[$j] = $row; $Yr[$j] = [double]$r.Y
        }
        $mx = New-Object double[] $q; $my = 0.0
        for ($i = 0; $i -lt $q; $i++) { $sx = 0.0; for ($j = 0; $j -lt $m; $j++) { $sx += $Xr[$j][$i] }; $mx[$i] = $sx / $m }
        for ($j = 0; $j -lt $m; $j++) { $my += $Yr[$j] }; $my /= $m
        for ($j = 0; $j -lt $m; $j++) {
            $zr = New-Object double[] $q; for ($i = 0; $i -lt $q; $i++) { $zr[$i] = $Xr[$j][$i] - $mx[$i] }
            $zy = $Yr[$j] - $my
            for ($i = 0; $i -lt $q; $i++) { $gv[$i] += $zr[$i] * $zy; for ($jj = 0; $jj -lt $q; $jj++) { $Gm[$i][$jj] += $zr[$i] * $zr[$jj] } }
            $yy += $zy * $zy; $n++
        }
    }
    $out.N = $n; $out.NCyl = $ncyl
    $keep = @(0..($q - 1) | Where-Object { $Gm[$_][$_] -gt 1e-9 })
    if ($keep -notcontains $iu -or $keep -notcontains $iu2) { $out.Why = 'niveaux'; return $out }
    $nk = $keep.Count
    # Noms distincts sans tenir compte de la casse (variables PowerShell) : matrice $Gkm, second membre $gkv
    $Gkm = New-Object 'double[][]' $nk; $gkv = New-Object double[] $nk
    for ($i = 0; $i -lt $nk; $i++) { $Gkm[$i] = New-Object double[] $nk; for ($j = 0; $j -lt $nk; $j++) { $Gkm[$i][$j] = $Gm[$keep[$i]][$keep[$j]] }; $gkv[$i] = $gv[$keep[$i]] }
    $sol = Solve-ContentLinear $Gkm $gkv
    if ($null -eq $sol) { $out.Why = 'singulier'; return $out }
    $sg = 0.0; for ($i = 0; $i -lt $nk; $i++) { $sg += $sol[$i] * $gkv[$i] }
    $ssr = $yy - $sg
    $df = $n - $ncyl - $nk
    if ($df -le 0) { $out.Why = 'ddl'; return $out }
    $s2 = [math]::Max(0.0, $ssr) / $df
    # Inverse de G (colonnes de l identite) : variances et covariance de b1 et b2
    $inv = New-Object 'double[][]' $nk; for ($i = 0; $i -lt $nk; $i++) { $inv[$i] = New-Object double[] $nk }
    for ($j = 0; $j -lt $nk; $j++) {
        $e = New-Object double[] $nk; $e[$j] = 1.0
        $col = Solve-ContentLinear $Gkm $e
        if ($null -eq $col) { $out.Why = 'singulier'; return $out }
        for ($i = 0; $i -lt $nk; $i++) { $inv[$i][$j] = $col[$i] }
    }
    $pu = [array]::IndexOf($keep, $iu); $pu2 = [array]::IndexOf($keep, $iu2)
    $vb1 = [math]::Max(0.0, $s2 * $inv[$pu][$pu]); $vb2 = [math]::Max(0.0, $s2 * $inv[$pu2][$pu2]); $cb = $s2 * $inv[$pu][$pu2]
    $b1 = $sol[$pu]; $b2 = $sol[$pu2]
    $uMin = $kMin - 1.0; $uMax = $kMax - 1.0
    if ($b2 -lt 0) {
        $kv = 1.0 - $b1 / (2 * $b2); $ext = $true
        $g1 = -1.0 / (2 * $b2); $g2 = $b1 / (2 * $b2 * $b2)
        $seK = [math]::Sqrt([math]::Max(0.0, $g1 * $g1 * $vb1 + $g2 * $g2 * $vb2 + 2 * $g1 * $g2 * $cb))
    } else {
        $ext = $false; $seK = $nan
        $kv = if (($b1 * $uMax + $b2 * $uMax * $uMax) -gt ($b1 * $uMin + $b2 * $uMin * $uMin)) { [double]::PositiveInfinity } else { [double]::NegativeInfinity }
    }
    $k = [math]::Min([math]::Max($kv, $kMin), $kMax)
    $bound = if ($kv -le $kMin) { 'low' } elseif ($kv -ge $kMax) { 'high' } else { '' }
    $uk = $k - 1.0
    $pe = @{}; for ($i = 1; $i -lt $np; $i++) { $pi = [array]::IndexOf($keep, $i - 1); $pe[$passes[$i]] = $(if ($pi -ge 0) { $sol[$pi] } else { 0.0 }) }
    $seB1 = [math]::Sqrt($vb1); $seB2 = [math]::Sqrt($vb2)
    $out.Ok = $true; $out.K = $k; $out.KVertex = $kv; $out.Ext = $ext; $out.Bound = $bound; $out.B1 = $b1; $out.B2 = $b2
    $out.SeB1 = $seB1; $out.SeB2 = $seB2; $out.SeK = $seK; $out.Gain = $b1 * $uk + $b2 * $uk * $uk; $out.S = [math]::Sqrt($s2)
    $out.Flat = ([math]::Abs($b1) -lt 2 * $seB1 -and [math]::Abs($b2) -lt 2 * $seB2); $out.PassEff = $pe
    return $out
}

function Solve-ContentLinear([double[][]]$a, [double[]]$b) {
    # Systeme a x = b (petit, dense) : elimination de Gauss a pivot partiel puis remontee (port de revue_sony.solve) ;
    # $null si un pivot est inferieur a 1e-10 en valeur absolue. a et b ne sont pas modifies
    $n = $b.Count
    $M = New-Object 'double[][]' $n
    for ($i = 0; $i -lt $n; $i++) { $row = New-Object double[] ($n + 1); for ($j = 0; $j -lt $n; $j++) { $row[$j] = $a[$i][$j] }; $row[$n] = $b[$i]; $M[$i] = $row }
    for ($c = 0; $c -lt $n; $c++) {
        $piv = $c
        for ($r = $c + 1; $r -lt $n; $r++) { if ([math]::Abs($M[$r][$c]) -gt [math]::Abs($M[$piv][$c])) { $piv = $r } }
        if ([math]::Abs($M[$piv][$c]) -lt 1e-10) { return $null }
        $t = $M[$c]; $M[$c] = $M[$piv]; $M[$piv] = $t
        for ($r = $c + 1; $r -lt $n; $r++) {
            $f = $M[$r][$c] / $M[$c][$c]
            for ($k = $c; $k -le $n; $k++) { $M[$r][$k] -= $f * $M[$c][$k] }
        }
    }
    $x = New-Object double[] $n
    for ($c = $n - 1; $c -ge 0; $c--) {
        $s = 0.0; for ($k = $c + 1; $k -lt $n; $k++) { $s += $M[$c][$k] * $x[$k] }
        $x[$c] = ($M[$c][$n] - $s) / $M[$c][$c]
    }
    return ,$x
}

function Limit-WriteFactor([double]$f, [double]$fMax = 0) {
    # Facteur d une ecriture (k + Dk) ramene a [0 ; fMax] ; fMax absent ou nul : ContentFMax (plafond unique, 040) ; NaN :
    # 1 (courbe telle quelle). Clamped : valeur changee
    if (-not ($fMax -gt 0)) { $fMax = [double]$script:ContentFMax }
    if ([double]::IsNaN($f)) { return @{ F = 1.0; Clamped = $true } }
    $v = [math]::Min([math]::Max($f, 0.0), $fMax)
    return @{ F = $v; Clamped = ($v -ne $f) }
}

function ConvertTo-ScaledSpec([string]$spec, [double]$f, [int]$hard) {
    # Profil --precomp mis a l echelle (C.3) : chaque entree c=v devient c=w, w = round(f x v) (arrondi au pair), au plus
    # max(hard, v) (une valeur au-dessus de la borne, venue d une mesure complete, n est jamais augmentee), au moins 0 ;
    # cylindres et ordre des entrees gardes, entree illisible gardee telle quelle. f = 1 : $spec rendu tel quel (meme
    # chaine : profils transmis a gw identiques a l octet a ceux de la v12.8)
    if ($f -eq 1.0 -or -not $spec) { return $spec }
    $parts = foreach ($e in ($spec -split ':')) {
        if ($e -match '^\s*(\d+)\s*=\s*(\d+)\s*$') {
            $v = [int]$Matches[2]
            $w = [math]::Max(0.0, [math]::Min([math]::Round($f * $v), [double][math]::Max($hard, $v)))
            "$([int]$Matches[1])=$([int]$w)"
        } else { $e }
    }
    return (@($parts) -join ':')
}

function Get-DriveK([string]$drive, [string]$fam, [int]$h) {
    # k du lecteur pour une ecriture sans mesure sur l image (C.3 ; decision de l utilisateur du 25/10/2026) : MEDIANE des
    # k* des 3 derniers enregistrements de ce lecteur, de cette famille et de cette tete (date de mesure, ordre d ajout a
    # date egale), de version ContentCalc et de calcul CalibCalc courants ; date de la courbe V non exigee (k garde apres
    # une recalibration du lecteur). Rec : le plus recent ; N : enregistrements retenus (3 au plus), Ks : leurs k*.
    # Sans enregistrement : K = 1, Src 'defaut' (ecriture de la v12.8)
    $cand = @(); $i = 0
    foreach ($r in $script:ContentMeasures) {
        $i++
        if ($null -eq $r -or $null -eq $r.Head -or $null -eq $r.K) { continue }
        if ([string]$r.Drive -ne $drive -or [string]$r.Family -ne $fam -or [int]$r.Head -ne $h) { continue }
        if ([string]$r.ContentCalc -ne [string]$script:ContentCalc -or [string]$r.Calc -ne [string]$script:CalibCalc) { continue }
        $k = [double]$r.K
        if ([double]::IsNaN($k) -or [double]::IsInfinity($k)) { continue }
        $cand += @{ R = $r; D = (Get-CurveDate $r); I = $i; K = $k }
    }
    if ($cand.Count -eq 0) { return @{ K = 1.0; Src = 'defaut'; Rec = $null; N = 0; Ks = [double[]]@() } }
    $last = @($cand | Sort-Object -Property @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First 3)
    $ks = [double[]]@($last | ForEach-Object { $_.K })
    return @{ K = [double](Get-Median $ks); Src = 'lecteur'; Rec = $last[0].R; N = $last.Count; Ks = $ks }
}

function Add-ContentMeasure($rec) {
    # Ajoute un enregistrement de mesure (C.2) a $script:ContentMeasures et garde les ContentRecMax (20 par defaut) plus
    # recents (date de mesure, ordre d ajout a date egale), ranges du plus ancien au plus recent
    if ($null -eq $rec) { return }
    $all = @($script:ContentMeasures | Where-Object { $null -ne $_ })
    $all += $rec
    $max = 20; if ($null -ne $script:ContentRecMax -and [int]$script:ContentRecMax -gt 0) { $max = [int]$script:ContentRecMax }
    if ($all.Count -gt $max) {
        $ix = for ($j = 0; $j -lt $all.Count; $j++) { @{ R = $all[$j]; D = (Get-CurveDate $all[$j]); I = $j } }
        $keep = @($ix | Sort-Object -Property @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First $max)
        $all = @($keep | Sort-Object -Property @{ Expression = { $_.D } }, @{ Expression = { $_.I } } | ForEach-Object { $_.R })
    }
    $script:ContentMeasures = $all
}

function Get-DriveDk([string]$drive, [int]$h) {
    # Correction « lecteur cible » Dk d une tete du lecteur (C.4) : 0 par defaut (lecteur ou tete inconnus)
    if ($h -lt 0 -or $h -gt 1 -or -not $drive -or $null -eq $script:TargetCorr -or -not $script:TargetCorr.ContainsKey($drive)) { return 0.0 }
    $v = if ($h -eq 0) { $script:TargetCorr[$drive].Dk0 } else { $script:TargetCorr[$drive].Dk1 }
    if ($null -eq $v) { return 0.0 }
    return [double]$v
}

function Set-DriveDk([string]$drive, [int]$h, [double]$v) {
    # Regle Dk d une tete du lecteur : bornee a [-TargetCorrMax ; TargetCorrMax] (borne unique, 040), arrondie a 0,01
    # (NaN : 0) ; rend l ancienne valeur. Date de la correction mise a jour quand la valeur change
    $old = Get-DriveDk $drive $h
    if (-not $drive -or $h -lt 0 -or $h -gt 1) { return $old }
    if ([double]::IsNaN($v)) { $v = 0.0 }
    $m = [double]$script:TargetCorrMax
    $v = [math]::Round([math]::Min($m, [math]::Max(-$m, $v)), 2)
    if ($v -eq 0) { $v = 0.0 }                                          # -0 ecrit 0
    if ($null -eq $script:TargetCorr) { $script:TargetCorr = @{} }
    if (-not $script:TargetCorr.ContainsKey($drive)) { $script:TargetCorr[$drive] = @{ Dk0 = 0.0; Dk1 = 0.0; Date = ''; Note = '' } }
    $e = $script:TargetCorr[$drive]
    if ($h -eq 0) { $e.Dk0 = $v } else { $e.Dk1 = $v }
    if ($v -ne $old) { $e.Date = Get-Date -Format 'dd/MM/yyyy HH:mm' }
    return $old
}

function ConvertTo-FiniteOrNull($x) {
    # Nombre fini (double), sinon $null (absent, texte illisible, NaN, infini : le JSON n admet ni NaN ni l infini)
    if ($null -eq $x -or $x -is [bool]) { return $null }
    try { $d = [double]$x } catch { return $null }
    if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { return $null }
    return $d
}

function Get-ConfigDouble($x, [double]$def) {
    # Nombre de la configuration : valeur finie, sinon $def
    $d = ConvertTo-FiniteOrNull $x
    if ($null -eq $d) { return $def }
    return [double]$d
}

function Get-RecValues($o) {
    # Champ Values d un enregistrement (mesure C.2, courbe V, entree de write.driveFactors) : lu par l index sur une table
    # (IDictionary). Sans la cle, $o.Values rendrait la propriete Values de la Hashtable, c est-a-dire toutes les valeurs
    # de l enregistrement (revue 12.8.1, I1) ; objet de ConvertFrom-Json : propriete. Champ absent ou $null : rien dans
    # le pipeline (@(Get-RecValues $x) vide)
    if ($null -eq $o) { return }
    $v = $null
    if ($o -is [System.Collections.IDictionary]) { $v = $o['Values'] } else { $v = $o.Values }
    if ($null -eq $v) { return }
    return $v
}

function ConvertTo-ContentConfig($rec) {
    # Enregistrement de mesure (C.2) -> entree de write.driveFactors (C.5) ; nombres non finis ecrits null ; Values par
    # Get-RecValues (enregistrement sans cle Values : liste vide)
    if ($null -eq $rec) { return $null }
    return [ordered]@{ model = [string]$rec.Model; drive = [string]$rec.Drive; family = [string]$rec.Family; head = [int]$rec.Head
                       date = [string]$rec.Date; image = [string]$rec.Image; k = (ConvertTo-FiniteOrNull $rec.K); kVertex = (ConvertTo-FiniteOrNull $rec.KVertex)
                       bound = [string]$rec.Bound; flat = [bool]$rec.Flat; seK = (ConvertTo-FiniteOrNull $rec.SeK); b1 = (ConvertTo-FiniteOrNull $rec.B1)
                       b2 = (ConvertTo-FiniteOrNull $rec.B2); gain = (ConvertTo-FiniteOrNull $rec.Gain); s = (ConvertTo-FiniteOrNull $rec.S)
                       nCyl = [int]$rec.NCyl; nObs = [int]$rec.NObs; nExcl = [int]$rec.NExcl
                       levels = @($rec.Levels | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
                       dk = (ConvertTo-FiniteOrNull $rec.Dk); f = (ConvertTo-FiniteOrNull $rec.F)
                       values = @(Get-RecValues $rec | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }); spec = [string]$rec.Spec
                       refKey = [string]$rec.RefKey; refDate = [string]$rec.RefDate; calc = [string]$rec.Calc; contentCalc = [string]$rec.ContentCalc
                       version = [string]$rec.Version }
}

function ConvertFrom-ContentConfig($o) {
    # Entree de write.driveFactors -> enregistrement de mesure (C.2) ; $null (ignoree par Load-Config, ligne T-C14) sans
    # drive ou family, avec head autre que 0 ou 1, ou avec k non fini ou hors de [0 ; 1]. KVertex : $null sans sommet ;
    # autres nombres absents : NaN (Dk : 0, F : k)
    if ($null -eq $o) { return $null }
    try {
        $k = ConvertTo-FiniteOrNull $o.k; $hd = ConvertTo-FiniteOrNull $o.head
        if (-not [string]$o.drive -or -not [string]$o.family -or $null -eq $hd -or ($hd -ne 0 -and $hd -ne 1) -or $null -eq $k -or $k -lt 0 -or $k -gt 1) { return $null }
        $nan = [double]::NaN
        return @{ Model = $(if ($o.model) { [string]$o.model } else { 'contenu' }); Drive = [string]$o.drive; Family = [string]$o.family; Head = [int]$hd
                  Date = [string]$o.date; Image = [string]$o.image; K = [double]$k; KVertex = (ConvertTo-FiniteOrNull $o.kVertex); Bound = [string]$o.bound
                  Flat = ($o.flat -eq $true); SeK = (Get-ConfigDouble $o.seK $nan); B1 = (Get-ConfigDouble $o.b1 $nan); B2 = (Get-ConfigDouble $o.b2 $nan)
                  Gain = (Get-ConfigDouble $o.gain $nan); S = (Get-ConfigDouble $o.s $nan); NCyl = [int]$o.nCyl; NObs = [int]$o.nObs; NExcl = [int]$o.nExcl
                  Levels = [double[]]@($o.levels | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ }); Dk = (Get-ConfigDouble $o.dk 0.0)
                  F = (Get-ConfigDouble $o.f ([double]$k)); Values = [int[]]@(Get-RecValues $o | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
                  Spec = [string]$o.spec; RefKey = [string]$o.refKey; RefDate = [string]$o.refDate; Calc = [string]$o.calc
                  ContentCalc = [string]$o.contentCalc; Version = [string]$o.version }
    } catch { return $null }
}

function ConvertTo-TargetCorrConfig {
    # Dk de chaque lecteur -> write.targetCorrection (C.5), trie par lecteur ; l appelant l enveloppe dans @(), comme
    # levelBrands (une seule entree serait sinon rendue seule)
    if ($null -eq $script:TargetCorr) { return @() }
    return @(@($script:TargetCorr.Keys | Sort-Object) | ForEach-Object {
        [ordered]@{ drive = [string]$_; dk0 = (Get-DriveDk ([string]$_) 0); dk1 = (Get-DriveDk ([string]$_) 1); date = [string]$script:TargetCorr[$_].Date; note = [string]$script:TargetCorr[$_].Note }
    })
}

function ConvertFrom-TargetCorrConfig($arr) {
    # write.targetCorrection -> @{ Map (lecteur -> @{ Dk0 ; Dk1 ; Date ; Note }) ; Bad (entrees illisibles : sans lecteur,
    # ou avec une valeur qui n est pas un nombre, comptee 0) } ; valeur hors bornes ramenee a [-TargetCorrMax ;
    # TargetCorrMax] (borne unique, 040), arrondie a 0,01
    $map = @{}; $bad = 0; $m = [double]$script:TargetCorrMax
    foreach ($o in $arr) {
        if ($null -eq $o) { continue }
        $d = ([string]$o.drive).Trim()
        if (-not $d) { $bad++; continue }
        $ok = $true; $e = @{ Dk0 = 0.0; Dk1 = 0.0; Date = [string]$o.date; Note = [string]$o.note }
        foreach ($pr in @(@('Dk0', $o.dk0), @('Dk1', $o.dk1))) {
            if ($null -eq $pr[1]) { continue }
            $v = ConvertTo-FiniteOrNull $pr[1]
            if ($null -eq $v) { $ok = $false; continue }
            $v = [math]::Round([math]::Min($m, [math]::Max(-$m, $v)), 2); if ($v -eq 0) { $v = 0.0 }
            $e[$pr[0]] = $v
        }
        if (-not $ok) { $bad++ }
        $map[$d] = $e
    }
    return @{ Map = $map; Bad = $bad }
}

function Get-GwVerifyStop([string[]]$lines) {
    # Arret de gw 1.23 sur une piste refusee a la verification apres les nouveaux essais (A.7) : @{ C ; H } de la premiere
    # ligne « Failed to verify Track C.H » (sans ancre : « ** FATAL ERROR: » peut la preceder), $null sinon
    foreach ($l in @($lines)) {
        if ($null -eq $l) { continue }
        $m = [regex]::Match($l, 'Failed to verify Track (\d+)\.([01])')
        if ($m.Success) { return @{ C = [int]$m.Groups[1].Value; H = [int]$m.Groups[2].Value } }
    }
    return $null
}
