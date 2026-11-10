# ============================== FONCTIONS : MESURE SUR L IMAGE, CALCUL ==========

# 12.8.1 (lot A, spec-1281.md § A et B.2) : calcul de la mesure de la disquette sur l image, sans interface ni texte T().
# Blocs de cylindres et plan en carre latin (A.3, A.4) ; pistes exclues avant l ecriture (IPF) et apres la relecture
# (A.2) ; donnees minimales et facteur k* de chaque tete (effets fixes passe + cylindre, quadratique en k, comme
# revue_sony.Jeu et motif_analyse.py) ; facteur applique a un profil --precomp (A.10, C.3) ; k du lecteur, mediane des
# 3 derniers k* mesures du lecteur, de la famille et de la tete (decision de l utilisateur du 25/10/2026, au lieu du
# dernier de la spec) ; conversions de la configuration (C.5) ; arret « Failed to verify Track » de gw (A.7).
# Constantes en parametres, defauts de 565 (B.4). References executables : v1281\verif_spec1281.py (plan, ajustement)
# et v1281\verif_scaled.py (profils mis a l echelle).
# 12.9 (critique de la phase A, § 3.2) : ajustement « K-ns » (courbure commune en ns, sommet k = besoin / courbe, borne a
# [0 ; 2]) pondere par Huber, optimums par zone de 5 cylindres (idee de l utilisateur), etats de la tete, 4e passe
# adaptative (niveaux 1,6 et 1), memoire par marque (etat 'mesure' seulement, jamais d emprunt), plafonds 5 / 80 / 20,
# relectures gardees (D6). Reference executable : v129\calib\modeles\modele_mesure.py.
# 12.10 : la correction « lecteur cible » Dk (C.4 : valeur par tete et par lecteur, bloc targetCorrection de la
# configuration) est retiree ; une ecriture pour un autre lecteur applique la courbe croisee (140, 220).

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
    # plus ('peu' sinon) ; parmi eux, 3 niveaux au moins (la quadratique en k en demande 3) sur minLevelCyl cylindres
    # chacun ('niveaux' sinon). 12.9 (synthese C, D2) : un niveau moins represente (4e passe tronquee par un arret de gw)
    # reste dans l ajustement sans le faire refuser
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
    if (@($lv.Values | Where-Object { $_ -ge $minLevelCyl }).Count -lt 3) { return @{ Ok = $false; NCyl = $cs.Count; Why = 'niveaux' } }
    return @{ Ok = $true; NCyl = $cs.Count; Why = '' }
}

function Get-ContentFeFit($rows, [string]$mode = 'K', $w = $null, $zones = $null, [int]$zoneLen = 5) {
    # 12.9 (critique § 3.2, reference modele_mesure.fit_fe) : y = a_passe + g_cylindre + somme b_j f_j + e, moindres carres
    # ponderes par $w (un poids par ligne, $null : 1), sur les lignes @{ P ; C ; W ; V ; Y } (W : precomp ecrite, V : courbe
    # du lecteur, ns). Passes en indicatrices dans l ordre de premiere apparition (la premiere en reference) ; cylindre
    # absorbe exactement (colonnes et y centres dans le cylindre par moyenne ponderee ; cylindre a moins de 2 lignes ou de
    # poids nul ignore). Regresseurs : mode 'K' W^2 et V W ; mode 'U' (idee de l utilisateur) W^2 puis W x 1(zone z) pour
    # chaque zone de zoneLen cylindres ($zones : numeros floor(C / zoneLen), tous ceux des lignes par defaut). Rend Ok, Why
    # ('vide', 'niveaux', 'singulier', 'ddl'), B (coefficients des regresseurs), Cov (s^2 G^-1 des regresseurs), S, Df, N
    # (lignes de poids non nul), NCyl, Res (residus centres, non ponderes) et Idx (lignes correspondantes), PassEff, Zones
    $rs = @($rows | Where-Object { $null -ne $_ })
    $nan = [double]::NaN
    $out = @{ Ok = $false; Why = ''; B = [double[]]@(); Cov = $null; S = $nan; Df = 0; N = 0; NCyl = 0; Res = [double[]]@(); Idx = [int[]]@(); PassEff = @{}; Zones = [int[]]@() }
    if ($rs.Count -eq 0) { $out.Why = 'vide'; return $out }
    if ($zoneLen -le 0) { $zoneLen = 5 }
    $zs = [int[]]@()
    if ($mode -eq 'U') {
        if ($null -eq $zones) { $zs = [int[]]@($rs | ForEach-Object { [int][math]::Floor([int]$_.C / [double]$zoneLen) } | Sort-Object -Unique) } else { $zs = [int[]]@($zones) }
    }
    $out.Zones = $zs
    $passes = New-Object 'System.Collections.Generic.List[string]'
    foreach ($r in $rs) { $p = [string]$r.P; if (-not $passes.Contains($p)) { $passes.Add($p) } }
    $np = $passes.Count
    $nf = if ($mode -eq 'U') { 1 + $zs.Count } else { 2 }
    $q = $np - 1 + $nf; $nr = $rs.Count
    # Noms distincts sans tenir compte de la casse (variables PowerShell) : $Xm (lignes), $xw (precomp ecrite)
    $Xm = New-Object 'double[][]' $nr; $Yv = New-Object double[] $nr; $wt = New-Object double[] $nr
    for ($i = 0; $i -lt $nr; $i++) {
        $r = $rs[$i]; $row = New-Object double[] $q
        for ($j = 1; $j -lt $np; $j++) { if ([string]$r.P -eq $passes[$j]) { $row[$j - 1] = 1.0 } }
        $xw = [double]$r.W
        $row[$np - 1] = $xw * $xw
        if ($mode -eq 'U') { $zi = [array]::IndexOf($zs, [int][math]::Floor([int]$r.C / [double]$zoneLen)); if ($zi -ge 0) { $row[$np + $zi] = $xw } }
        else { $row[$np] = [double]$r.V * $xw }
        $Xm[$i] = $row; $Yv[$i] = [double]$r.Y
        $wt[$i] = if ($null -eq $w) { 1.0 } else { [double]$w[$i] }
    }
    $byC = @{}
    for ($i = 0; $i -lt $nr; $i++) { $c = [int]$rs[$i].C; if (-not $byC.ContainsKey($c)) { $byC[$c] = New-Object 'System.Collections.Generic.List[int]' }; $byC[$c].Add($i) }
    $Gm = New-Object 'double[][]' $q; for ($i = 0; $i -lt $q; $i++) { $Gm[$i] = New-Object double[] $q }
    $gv = New-Object double[] $q; $n = 0; $ncyl = 0
    $zl = New-Object 'System.Collections.Generic.List[object]'
    foreach ($c in @($byC.Keys | Sort-Object)) {
        $ix = $byC[$c]; $sw = 0.0; foreach ($i in $ix) { $sw += $wt[$i] }
        if ($ix.Count -lt 2 -or $sw -le 0) { continue }
        $ncyl++
        $mx = New-Object double[] $q; $my = 0.0
        for ($j = 0; $j -lt $q; $j++) { $sx = 0.0; foreach ($i in $ix) { $sx += $wt[$i] * $Xm[$i][$j] }; $mx[$j] = $sx / $sw }
        foreach ($i in $ix) { $my += $wt[$i] * $Yv[$i] }; $my /= $sw
        foreach ($i in $ix) {
            $wk = $wt[$i]; $zr = New-Object double[] $q
            for ($j = 0; $j -lt $q; $j++) { $zr[$j] = $Xm[$i][$j] - $mx[$j] }
            $zy = $Yv[$i] - $my
            $zl.Add(@{ I = $i; Z = $zr; Zy = $zy; Wk = $wk })
            if ($wk -gt 0) { $n++ }
            for ($a = 0; $a -lt $q; $a++) {
                if ($zr[$a] -eq 0) { continue }
                $gv[$a] += $wk * $zr[$a] * $zy; $za = $wk * $zr[$a]; $ga = $Gm[$a]
                for ($b = 0; $b -lt $q; $b++) { $ga[$b] += $za * $zr[$b] }
            }
        }
    }
    $out.N = $n; $out.NCyl = $ncyl
    $keep = [int[]]@(0..($q - 1) | Where-Object { $Gm[$_][$_] -gt 1e-9 })
    for ($j = $np - 1; $j -lt $q; $j++) { if ($keep -notcontains $j) { $out.Why = 'niveaux'; return $out } }
    $nk = $keep.Count
    $Gkm = New-Object 'double[][]' $nk; $gkv = New-Object double[] $nk
    for ($i = 0; $i -lt $nk; $i++) { $Gkm[$i] = New-Object double[] $nk; for ($j = 0; $j -lt $nk; $j++) { $Gkm[$i][$j] = $Gm[$keep[$i]][$keep[$j]] }; $gkv[$i] = $gv[$keep[$i]] }
    $sol = Solve-ContentLinear $Gkm $gkv
    if ($null -eq $sol) { $out.Why = 'singulier'; return $out }
    $beta = New-Object double[] $q
    for ($i = 0; $i -lt $nk; $i++) { $beta[$keep[$i]] = $sol[$i] }
    $ssr = 0.0; $res = New-Object double[] $zl.Count; $idx = New-Object int[] $zl.Count
    for ($t = 0; $t -lt $zl.Count; $t++) {
        $e = $zl[$t]; $rv = [double]$e.Zy
        for ($j = 0; $j -lt $q; $j++) { $rv -= $e.Z[$j] * $beta[$j] }
        $res[$t] = $rv; $idx[$t] = [int]$e.I; $ssr += [double]$e.Wk * $rv * $rv
    }
    $df = $n - $ncyl - $nk
    if ($df -le 0) { $out.Why = 'ddl'; return $out }
    $s2 = $ssr / $df
    $inv = New-Object 'double[][]' $nk; for ($i = 0; $i -lt $nk; $i++) { $inv[$i] = New-Object double[] $nk }
    for ($j = 0; $j -lt $nk; $j++) {
        $ej = New-Object double[] $nk; $ej[$j] = 1.0
        $col = Solve-ContentLinear $Gkm $ej
        if ($null -eq $col) { $out.Why = 'singulier'; return $out }
        for ($i = 0; $i -lt $nk; $i++) { $inv[$i][$j] = $col[$i] }
    }
    # Regresseurs (tous gardes) : positions $np - 1 .. $q - 1 dans $keep
    $fp = [int[]]@(for ($j = $np - 1; $j -lt $q; $j++) { [array]::IndexOf($keep, $j) })
    $cov = New-Object 'double[][]' $nf
    for ($i = 0; $i -lt $nf; $i++) { $cov[$i] = New-Object double[] $nf; for ($j = 0; $j -lt $nf; $j++) { $cov[$i][$j] = $s2 * $inv[$fp[$i]][$fp[$j]] } }
    $pe = @{ ([string]$passes[0]) = 0.0 }; for ($i = 1; $i -lt $np; $i++) { $pe[[string]$passes[$i]] = $beta[$i - 1] }
    $out.Ok = $true; $out.B = [double[]]@(for ($j = $np - 1; $j -lt $q; $j++) { $beta[$j] }); $out.Cov = $cov
    $out.S = [math]::Sqrt([math]::Max($s2, 0.0)); $out.Df = $df; $out.Res = $res; $out.Idx = $idx; $out.PassEff = $pe
    return $out
}

function Get-ContentMad($v) {
    # Ecart absolu median ramene a un ecart-type (1,4826 x MAD, loi normale) ; 0 sans valeur
    $a = @($v | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
    if ($a.Count -eq 0) { return 0.0 }
    $m = [double](Get-Median $a)
    return 1.4826 * [double](Get-Median @($a | ForEach-Object { [math]::Abs($_ - $m) }))
}

function Get-ContentHuberWeights($rows) {
    # 12.9 (D4, critique § 3.2, reference modele_mesure.poids_robustes) : poids de Huber des lignes d une tete, par
    # moindres carres ponderes iteres sur le modele 'K' (Get-ContentFeFit) : residu centre corrige du centrage dans le
    # cylindre (x racine(m / (m - 1)), m lignes du cylindre), sigma = 1,4826 x MAD des residus, poids min(1, c / |z|),
    # c = ContentHuberC (1,345) ; au plus ContentHuberIt iterations (10), arret quand les poids varient de moins de 1e-4.
    # Ajustement impossible ou sigma nul : poids de l iteration precedente (1 au depart). Rend un double[] aligne sur $rows
    $rs = @($rows | Where-Object { $null -ne $_ })
    $hc = if ([double]$script:ContentHuberC -gt 0) { [double]$script:ContentHuberC } else { 1.345 }
    $nIt = if ([int]$script:ContentHuberIt -gt 0) { [int]$script:ContentHuberIt } else { 10 }
    $nr = $rs.Count
    $wv = New-Object double[] $nr; for ($i = 0; $i -lt $nr; $i++) { $wv[$i] = 1.0 }
    $mc = @{}; foreach ($r in $rs) { $c = [int]$r.C; $mc[$c] = 1 + [int]$mc[$c] }
    for ($it = 0; $it -lt $nIt; $it++) {
        $fit = Get-ContentFeFit $rs 'K' $(if ($it -gt 0) { $wv } else { $null })
        if (-not $fit.Ok) { return ,$wv }
        $sc = New-Object double[] $fit.Idx.Count
        for ($t = 0; $t -lt $fit.Idx.Count; $t++) {
            $m = [int]$mc[[int]$rs[$fit.Idx[$t]].C]; $rv = [double]$fit.Res[$t]
            if ($m -gt 1) { $rv *= [math]::Sqrt($m / ($m - 1.0)) }
            $sc[$t] = $rv
        }
        $sig = Get-ContentMad $sc
        if (-not ($sig -gt 0)) { return ,$wv }
        $nw = New-Object double[] $nr; for ($i = 0; $i -lt $nr; $i++) { $nw[$i] = 1.0 }
        for ($t = 0; $t -lt $fit.Idx.Count; $t++) { $zz = [math]::Abs($sc[$t]) / $sig; $nw[$fit.Idx[$t]] = $(if ($zz -le $hc) { 1.0 } else { $hc / $zz }) }
        $dm = 0.0; for ($i = 0; $i -lt $nr; $i++) { $d = [math]::Abs($wv[$i] - $nw[$i]); if ($d -gt $dm) { $dm = $d } }
        $wv = $nw
        if ($dm -lt 1e-4) { break }
    }
    return ,$wv
}

function Get-ContentFactorNs($rows, $w = $null, [double]$kMax = 0, [int]$zoneLen = 5) {
    # 12.9 (modele « K-ns », critique § 3.2, reference modele_mesure.profil_tete) : y = a_passe + g_cylindre - Q (W - k V)^2,
    # soit les regresseurs W^2 (b0) et V W (b1) ; Q = -b0 (courbure commune en ns, ns^-1), k = -b1 / (2 b0) si Q > 0 (NaN
    # sinon), SeMod par la methode delta (dk/db0 = b1 / (2 b0^2), dk/db1 = -1 / (2 b0)), TQ = Q / se(Q). Idee de
    # l utilisateur (variante U) : courbure commune et terme propre a chaque zone de zoneLen cylindres, optimum x*_z = b_z /
    # 2Q (ns, methode delta), puis droite x* = k V par l origine, ponderee par 1 / max(var, 1 ns^2) (optimums hors de
    # -400..800 ns ecartes ; 2 zones au moins), variance x max(1, chi2 / ddl) : SeU, Chi2Ddl, KZones, Zones (@{ Z ; Cyl ; V
    # (moyenne de la zone) ; X ; SeX ; K = X / V ; Se = SeX / V }, vide si la variante echoue). SeK = max(SeMod, SeU).
    # $w : poids de Huber (Get-ContentHuberWeights) ; NPond : lignes de poids < 1 ; Low / NLow : lignes de poids <
    # ContentLowWeight (0,5), @{ C ; P ; W } par cylindre et passe. Etat : Get-ContentHeadState
    if (-not ($kMax -gt 0)) { $kMax = if ([double]$script:ContentKMax -gt 0) { [double]$script:ContentKMax } else { 2.0 } }
    if ($zoneLen -le 0) { $zoneLen = 5 }
    $nan = [double]::NaN
    $rs = @($rows | Where-Object { $null -ne $_ })
    $out = @{ Ok = $false; Why = ''; K = $nan; SeK = $nan; SeMod = $nan; SeU = $nan; Q = $nan; SeQ = $nan; TQ = $nan; S = $nan; Chi2Ddl = $nan; KZones = $nan
              Zones = @(); N = 0; NCyl = 0; NPond = 0; NLow = 0; Low = @(); Etat = 'echec'; PassEff = @{} }
    $lowW = if ([double]$script:ContentLowWeight -gt 0) { [double]$script:ContentLowWeight } else { 0.5 }
    if ($null -ne $w) {
        $low = @()
        for ($i = 0; $i -lt $rs.Count; $i++) {
            $wi = [double]$w[$i]
            if ($wi -lt 1.0 -and $wi -gt 0) { $out.NPond++ }
            if ($wi -lt $lowW) { $low += ,@{ C = [int]$rs[$i].C; P = [string]$rs[$i].P; W = $wi } }
        }
        $out.Low = @($low | Sort-Object { [int]$_.C }, { [string]$_.P }); $out.NLow = $low.Count
    }
    $fit = Get-ContentFeFit $rs 'K' $w
    if (-not $fit.Ok) { $out.Why = [string]$fit.Why; return $out }
    $b0 = [double]$fit.B[0]; $b1 = [double]$fit.B[1]; $cv = $fit.Cov
    $qq = -$b0; $seQ = [math]::Sqrt([math]::Max([double]$cv[0][0], 0.0))
    $k = $nan; $seMod = $nan
    if ($qq -gt 0) {
        $k = $b1 / (2.0 * $qq)
        $g0 = $b1 / (2.0 * $b0 * $b0); $g1 = -1.0 / (2.0 * $b0)
        $seMod = [math]::Sqrt([math]::Max(0.0, $g0 * $g0 * $cv[0][0] + $g1 * $g1 * $cv[1][1] + 2.0 * $g0 * $g1 * $cv[0][1]))
    }
    $out.Ok = $true; $out.K = $k; $out.SeMod = $seMod; $out.Q = $qq; $out.SeQ = $seQ; $out.TQ = $(if ($seQ -gt 0) { $qq / $seQ } else { $nan })
    $out.S = [double]$fit.S; $out.N = [int]$fit.N; $out.NCyl = [int]$fit.NCyl; $out.PassEff = $fit.PassEff
    # Variante U : optimums par zone, puis droite par l origine
    # Synthese C (D1) : zones identifiables seulement (un cylindre au moins ecrit a 2 precomp distinctes) : une zone sans
    # variation de W (courbe nulle, cylindres lus une seule fois) ne fait plus echouer toute la variante U
    $byCW = @{}; foreach ($ru in $rs) { $cc = [int]$ru.C; if (-not $byCW.ContainsKey($cc)) { $byCW[$cc] = @{} }; $byCW[$cc][[int]$ru.W] = $true }
    $zid = @{}; foreach ($cc in @($byCW.Keys)) { if ($byCW[$cc].Count -ge 2) { $zid[[int][math]::Floor($cc / [double]$zoneLen)] = $true } }
    $fu = Get-ContentFeFit $rs 'U' $w ([int[]]@($zid.Keys | Sort-Object)) $zoneLen
    $seU = $nan
    if ($fu.Ok) {
        $bq = [double]$fu.B[0]; $cu = $fu.Cov
        $zl = @(); $pts = @()
        for ($iz = 0; $iz -lt $fu.Zones.Count; $iz++) {
            $z = [int]$fu.Zones[$iz]
            $vz = @($rs | Where-Object { [int][math]::Floor([int]$_.C / [double]$zoneLen) -eq $z } | ForEach-Object { [double]$_.V })
            $vm = 0.0; foreach ($v in $vz) { $vm += $v }; if ($vz.Count) { $vm /= $vz.Count }
            $bz = [double]$fu.B[1 + $iz]; $xs = $nan; $vx = $nan
            if ($bq -lt 0) {
                $xs = $bz / (-2.0 * $bq)
                $h0 = $bz / (2.0 * $bq * $bq); $h1 = -1.0 / (2.0 * $bq)
                $vx = [math]::Max(0.0, $h0 * $h0 * $cu[0][0] + $h1 * $h1 * $cu[1 + $iz][1 + $iz] + 2.0 * $h0 * $h1 * $cu[0][1 + $iz])
            }
            $sx = if ([double]::IsNaN($vx)) { $nan } else { [math]::Sqrt($vx) }
            $zl += ,@{ Z = $z; Cyl = "$($z * $zoneLen)-$($z * $zoneLen + $zoneLen - 1)"; V = $vm; X = $xs; SeX = $sx
                       K = $(if ($vm -gt 0) { $xs / $vm } else { $nan }); Se = $(if ($vm -gt 0) { $sx / $vm } else { $nan }) }
            if (-not [double]::IsNaN($xs) -and -not [double]::IsNaN($vx) -and $vx -gt 0 -and $xs -ge -400 -and $xs -le 800) { $pts += ,@{ V = $vm; X = $xs; Var = $vx } }
        }
        if ($pts.Count -ge 2) {
            $sa = 0.0; $sb = 0.0
            foreach ($pt in $pts) { $pw = 1.0 / [math]::Max([double]$pt.Var, 1.0); $sa += $pw * $pt.V * $pt.V; $sb += $pw * $pt.V * $pt.X }
            if ([math]::Abs($sa) -ge 1e-12) {
                $kU = $sb / $sa; $chi = 0.0
                foreach ($pt in $pts) { $pw = 1.0 / [math]::Max([double]$pt.Var, 1.0); $dd = $pt.X - $kU * $pt.V; $chi += $pw * $dd * $dd }
                $ddl = $pts.Count - 1
                $scl = if ($ddl -gt 0) { [math]::Max(1.0, $chi / $ddl) } else { 1.0 }
                $seU = [math]::Sqrt([math]::Max($scl / $sa, 0.0))
                $out.KZones = $kU; $out.Chi2Ddl = $(if ($ddl -gt 0) { $chi / $ddl } else { $nan }); $out.Zones = $zl
            }
        }
    }
    $out.SeU = $seU
    $out.SeK = if ([double]::IsNaN($seU)) { $seMod } else { [math]::Max($seMod, $seU) }
    $out.Etat = Get-ContentHeadState $out $kMax
    return $out
}

function Get-ContentHeadState($fit, [double]$kMax = 0) {
    # 12.9 (critique § 3.2.4) : etat d une tete apres Get-ContentFactorNs : 'echec' (ajustement impossible), 'plate' (Q <= 0,
    # k NaN ou TQ < ContentFlatT, 2 : critere de Fieller, l intervalle de k n est pas borne), 'peu' (SeK > ContentSeKMax,
    # 0,25), 'haute' (k > kMax, 2), 'basse' (k < 0), sinon 'mesure'
    if (-not ($kMax -gt 0)) { $kMax = if ([double]$script:ContentKMax -gt 0) { [double]$script:ContentKMax } else { 2.0 } }
    if (-not $fit -or -not $fit.Ok) { return 'echec' }
    $ft = if ([double]$script:ContentFlatT -gt 0) { [double]$script:ContentFlatT } else { 2.0 }
    $sm = if ([double]$script:ContentSeKMax -gt 0) { [double]$script:ContentSeKMax } else { 0.25 }
    $k = [double]$fit.K
    if (-not ([double]$fit.TQ -ge $ft) -or -not ([double]$fit.Q -gt 0) -or [double]::IsNaN($k)) { return 'plate' }
    if (-not ([double]$fit.SeK -le $sm)) { return 'peu' }
    if ($k -gt $kMax) { return 'haute' }
    if ($k -lt 0) { return 'basse' }
    return 'mesure'
}

function Get-ContentAppliedK([string]$etat, [double]$k, $memK = $null, [double]$kMax = 0) {
    # 12.9 : facteur applique a une tete selon son etat : k borne a [0 ; kMax] ('mesure', 'haute', 'basse' ; Src 'mesure') ;
    # sinon k memorise du lecteur pour la marque ($memK, Get-DriveK ; Src 'lecteur'), a defaut 1 (Src 'defaut')
    if (-not ($kMax -gt 0)) { $kMax = if ([double]$script:ContentKMax -gt 0) { [double]$script:ContentKMax } else { 2.0 } }
    if (@('mesure', 'haute', 'basse') -contains $etat -and -not [double]::IsNaN($k)) { return @{ K = [math]::Min([math]::Max($k, 0.0), $kMax); Src = 'mesure' } }
    $m = ConvertTo-FiniteOrNull $memK
    if ($null -ne $m) { return @{ K = [double]$m; Src = 'lecteur' } }
    return @{ K = 1.0; Src = 'defaut' }
}

function Get-ContentScaledValues($v, [double]$f, [int]$hard) {
    # Courbe ecrite d une tete : w = round(f x v) (arrondi au pair), au plus max(hard, v), au moins 0 (comme
    # ConvertTo-ScaledSpec) ; enregistrement de mesure et profil des tests
    return ,([int[]]@(foreach ($x in @($v)) { [int][math]::Max(0.0, [math]::Min([math]::Round($f * [double]$x), [double][math]::Max($hard, [int]$x))) }))
}

function Test-ContentNeedFourth($fits, [double]$trigger = 0) {
    # 12.9 (D3, critique § 3.2.5) : 4e passe adaptative apres les 3 premieres : une tete dont l ajustement (Get-ContentFactorNs,
    # $fits : @{ 0 ; 1 }) a un k >= ContentFourthTrigger (0,9) ou pas de sommet (Q <= 0), quel que soit son etat. Tete sans
    # ajustement : non. Rend @{ Need ; Heads (tetes concernees) ; K (tete -> k, NaN sans sommet) }
    if (-not ($trigger -gt 0)) { $trigger = if ([double]$script:ContentFourthTrigger -gt 0) { [double]$script:ContentFourthTrigger } else { 0.9 } }
    $heads = @(); $ks = @{}
    foreach ($h in 0, 1) {
        $f = if ($fits) { $fits[$h] } else { $null }
        if (-not $f -or -not $f.Ok) { continue }
        $k = [double]$f.K
        if (-not ([double]$f.Q -gt 0) -or [double]::IsNaN($k) -or $k -ge $trigger) { $heads += $h; $ks[$h] = $k }
    }
    return @{ Need = ($heads.Count -gt 0); Heads = [int[]]$heads; K = $ks }
}

function Get-ContentFourthPass($plan, [int[]]$v0, [int[]]$v1, [int]$hard, $preSkip = @{}, $levels = $null) {
    # 12.9 (D3, critique § 3.2.6) : 4e passe du plan, memes cylindres que les passes precedentes (blocs du plan, sans les
    # cles 'c.h' de $preSkip), bloc de rang bi au niveau levels[bi mod n] (ContentFourthLevels : 1,6 et 1, alternes : l effet
    # de passe reste identifie par la repetition du niveau 1), valeur ecrite w = max(0, min(hard, round(k x V_h(c)))) comme
    # Get-ContentPlan. Rend la passe @{ H = @{ 0 ; 1 } (Cyls ; W ; K ; Spec) ; BlockK (niveau de chaque bloc) ; NCylHead }
    $lv = if ($null -ne $levels) { [double[]]@($levels) } else { [double[]]@($script:ContentFourthLevels) }
    if ($lv.Count -eq 0) { $lv = [double[]]@(1.6, 1.0) }
    if ($null -eq $preSkip) { $preSkip = @{} }
    $bi0 = @($plan.Blocks); $cy = @($plan.Cyls); $nb = $bi0.Count
    $len = if ($nb -gt 0) { [int]($cy.Count / $nb) } else { 0 }
    $bk = [double[]]@(for ($bi = 0; $bi -lt $nb; $bi++) { $lv[$bi % $lv.Count] })
    $vs = @{ 0 = [int[]]@($v0); 1 = [int[]]@($v1) }
    $hh = @{}; $nh = @{ 0 = 0; 1 = 0 }
    foreach ($h in 0, 1) {
        $v = $vs[$h]; $cs = New-Object 'System.Collections.Generic.List[int]'; $wv = @{}; $kk = @{}
        for ($bi = 0; $bi -lt $nb; $bi++) {
            for ($j = 0; $j -lt $len; $j++) {
                $c = [int]$cy[$bi * $len + $j]
                if ($preSkip.Contains("$c.$h") -or $v.Count -eq 0) { continue }
                $vc = if ($c -lt $v.Count) { $v[$c] } else { $v[$v.Count - 1] }
                $vc = [math]::Max(0, [math]::Min($hard, $vc))
                $wv[$c] = [int][math]::Max(0.0, [math]::Min([double]$hard, [math]::Round($bk[$bi] * $vc)))
                $kk[$c] = $bk[$bi]; $cs.Add($c)
            }
        }
        $cyls = [int[]]@($cs | Sort-Object)
        $hh[$h] = @{ Cyls = $cyls; W = $wv; K = $kk; Spec = $(if ($cyls.Count) { Get-BracketSpec $wv } else { '' }) }
        $nh[$h] = $cyls.Count
    }
    return @{ H = $hh; BlockK = $bk; NCylHead = $nh }
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
    # Facteur d une ecriture (k) ramene a [0 ; fMax] ; fMax absent ou nul : ContentFMax (plafond unique, 040) ; NaN :
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

function Get-DriveK([string]$drive, [string]$fam, [int]$h, $brand = $null) {
    # k du lecteur pour une ecriture sans mesure sur l image (C.3 ; decision de l utilisateur du 25/10/2026) : MEDIANE des
    # k* des 3 derniers enregistrements de ce lecteur, de cette famille et de cette tete (date de mesure, ordre d ajout a
    # date egale), de version ContentCalc et de calcul CalibCalc courants ; date de la courbe V non exigee (k garde apres
    # une recalibration du lecteur). Rec : le plus recent ; N : enregistrements retenus (3 au plus), Ks : leurs k*.
    # Sans enregistrement : K = 1, Src 'defaut' (ecriture de la v12.8). Revue 12.8.2 : Old, enregistrements de ce lecteur,
    # de cette famille et de cette tete ecartes parce qu ils viennent d un autre calcul (CalibCalc ou ContentCalc) : textes
    # « mesures faites avec un autre calcul, a refaire » au lieu de « aucune mesure ».
    # 12.9 (N13, critique § 3.2.7) : par marque ($brand ; $null : derniere marque choisie, $script:LevelBrand ; '' :
    # « non precisee », distincte de toute marque nommee ; Get-LevelBrandKey : casse et espaces des bords ignores), seuls
    # les enregistrements d etat 'mesure' ; jamais le facteur d une autre marque (k = 1). Old : enregistrements d un autre
    # calcul de cette marque ou sans marque (12.8.x) ; Other : mesures d autres marques pour ce lecteur, cette famille et
    # cette tete, OtherBrands leurs noms (bruts : '' pour « non precisee », a afficher par Format-ContentBrand, 276) ;
    # Brand : marque cherchee. Revue de la phase B (mineur 1) : OldContent, ceux de Old ecartes seulement par ContentCalc
    # (CalibCalc courant : mesures d avant la 12.9, calibration inchangee ; texte « calcul de la mesure change »)
    $br = if ($null -eq $brand) { [string]$script:LevelBrand } else { [string]$brand }
    $bk = Get-LevelBrandKey $br
    $cand = @(); $i = 0; $old = 0; $oldC = 0; $nOth = 0; $oth = @{}
    foreach ($r in $script:ContentMeasures) {
        $i++
        if ($null -eq $r -or $null -eq $r.Head -or $null -eq $r.K) { continue }
        if ([string]$r.Drive -ne $drive -or [string]$r.Family -ne $fam -or [int]$r.Head -ne $h) { continue }
        $rk = Get-LevelBrandKey ([string]$r.Brand)
        if ([string]$r.ContentCalc -ne [string]$script:ContentCalc -or [string]$r.Calc -ne [string]$script:CalibCalc) {
            if ($rk -eq $bk -or -not $rk) { $old++; if ([string]$r.Calc -eq [string]$script:CalibCalc) { $oldC++ } }
            continue
        }
        if ([string]$r.Etat -ne 'mesure') { continue }
        $k = [double]$r.K
        if ([double]::IsNaN($k) -or [double]::IsInfinity($k)) { continue }
        if ($rk -ne $bk) { $nOth++; if (-not $oth.ContainsKey($rk)) { $oth[$rk] = ([string]$r.Brand).Trim() }; continue }
        $cand += @{ R = $r; D = (Get-CurveDate $r); I = $i; K = $k }
    }
    $ob = [string[]]@($oth.Values | Sort-Object)
    if ($cand.Count -eq 0) { return @{ K = 1.0; Src = 'defaut'; Rec = $null; N = 0; Ks = [double[]]@(); Old = $old; OldContent = $oldC; Other = $nOth; OtherBrands = $ob; Brand = $br } }
    $last = @($cand | Sort-Object -Property @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First 3)
    $ks = [double[]]@($last | ForEach-Object { $_.K })
    return @{ K = [double](Get-Median $ks); Src = 'lecteur'; Rec = $last[0].R; N = $last.Count; Ks = $ks; Old = $old; OldContent = $oldC; Other = $nOth; OtherBrands = $ob; Brand = $br }
}

function Get-StaleDriveFactors {
    # Revue 12.8.2 : lecteurs dont les facteurs mesures ne sont plus appliques (Get-DriveK) : enregistrements d un autre
    # calcul (CalibCalc ou ContentCalc) pour un lecteur, une famille et une tete sans aucun enregistrement du calcul
    # actuel. Renvoie @{ N : enregistrements ecartes ; Drives : lecteurs concernes, tries } (ligne de journal de Load-Config).
    # 12.9 : Content, ceux d un autre ContentCalc (texte « facteurs mesures avant la 12.9 » de Load-Config)
    $cur = @{}; $old = @{}; $oc = @{}
    foreach ($r in @($script:ContentMeasures)) {
        if ($null -eq $r -or $null -eq $r.Head -or $null -eq $r.K) { continue }
        $key = "$($r.Drive)|$($r.Family)|$([int]$r.Head)"
        if ([string]$r.ContentCalc -eq [string]$script:ContentCalc -and [string]$r.Calc -eq [string]$script:CalibCalc) { $cur[$key] = $true }
        else {
            if (-not $old.ContainsKey($key)) { $old[$key] = 0; $oc[$key] = 0 }
            $old[$key]++; if ([string]$r.ContentCalc -ne [string]$script:ContentCalc) { $oc[$key]++ }
        }
    }
    $n = 0; $nc = 0; $drv = @{}
    foreach ($key in @($old.Keys)) { if (-not $cur.ContainsKey($key)) { $n += [int]$old[$key]; $nc += [int]$oc[$key]; $drv[($key -split '\|')[0]] = $true } }
    return @{ N = $n; Content = $nc; Drives = @($drv.Keys | Sort-Object) }
}

function Add-ContentMeasure($rec) {
    # Ajoute un enregistrement de mesure (C.2) a $script:ContentMeasures. 12.9 (critique § 3.2.8) : plafonds, du plus recent
    # au plus ancien (date de mesure, ordre d ajout a date egale) : ContentRecPerKey (5) par lecteur, famille, tete, marque
    # (Get-LevelBrandKey) et ContentCalc, les enregistrements d etat 'mesure' gardes avant les autres (la memoire de la
    # marque n en perd aucun au profit d une marge plate) ; ContentRecOldMax (20) d un autre calcul (ContentCalc ou
    # CalibCalc) ; ContentRecMax (80) en tout. Ordre des enregistrements gardes inchange
    if ($null -eq $rec) { return }
    $all = @($script:ContentMeasures | Where-Object { $null -ne $_ })
    $all += $rec
    $perKey = if ([int]$script:ContentRecPerKey -gt 0) { [int]$script:ContentRecPerKey } else { 5 }
    $max = if ([int]$script:ContentRecMax -gt 0) { [int]$script:ContentRecMax } else { 80 }
    $oldMax = if ($null -ne $script:ContentRecOldMax -and [int]$script:ContentRecOldMax -ge 0) { [int]$script:ContentRecOldMax } else { 20 }
    $ix = @(for ($j = 0; $j -lt $all.Count; $j++) {
        $r = $all[$j]
        @{ R = $r; D = (Get-CurveDate $r); I = $j; M = ([string]$r.Etat -eq 'mesure')
           Key = "$($r.Drive)|$($r.Family)|$([int]$r.Head)|$(Get-LevelBrandKey ([string]$r.Brand))|$($r.ContentCalc)"
           Old = ([string]$r.ContentCalc -ne [string]$script:ContentCalc -or [string]$r.Calc -ne [string]$script:CalibCalc) }
    })
    $kept = @(); $grp = @{}
    foreach ($e in $ix) { if (-not $grp.ContainsKey($e.Key)) { $grp[$e.Key] = @() }; $grp[$e.Key] += ,$e }
    foreach ($g in @($grp.Keys)) {
        $kept += @($grp[$g] | Sort-Object -Property @{ Expression = { $_.M }; Descending = $true }, @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First $perKey)
    }
    $ko = @($kept | Where-Object { $_.Old } | Sort-Object -Property @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First $oldMax)
    $kept = @(@($kept | Where-Object { -not $_.Old }) + $ko)
    # Synthese C (A3) : les 3 derniers enregistrements 'mesure' de chaque cle du calcul courant (fenetre de la mediane de
    # Get-DriveK) passent avant les autres au plafond ContentRecMax : une marque mesuree n est pas evincee par des mesures
    # plus recentes d autres marques ou d autres lecteurs, ni par des marges plates
    $pk = @{}
    foreach ($e in @($kept | Where-Object { -not $_.Old -and $_.M } | Sort-Object -Property @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true })) {
        if (-not $pk.ContainsKey($e.Key)) { $pk[$e.Key] = 0 }
        if ($pk[$e.Key] -lt 3) { $pk[$e.Key]++; $e.P = $true }
    }
    $kept = @($kept | Sort-Object -Property @{ Expression = { [bool]$_.P }; Descending = $true }, @{ Expression = { $_.D }; Descending = $true }, @{ Expression = { $_.I }; Descending = $true } | Select-Object -First $max)
    $ki = @{}; foreach ($e in $kept) { $ki[[int]$e.I] = $true }
    $script:ContentMeasures = @($ix | Where-Object { $ki.ContainsKey([int]$_.I) } | ForEach-Object { $_.R })
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
                       f = (ConvertTo-FiniteOrNull $rec.F)   # 12.10 : plus de champ dk (correction Dk retiree)
                       values = @(Get-RecValues $rec | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }); spec = [string]$rec.Spec
                       refKey = [string]$rec.RefKey; refDate = [string]$rec.RefDate; calc = [string]$rec.Calc; contentCalc = [string]$rec.ContentCalc
                       version = [string]$rec.Version
                       # 12.9 : marque, etat de la tete, courbure en ns, t, dispersion des zones, passes, k par zone (2 decimales)
                       brand = [string]$rec.Brand; etat = [string]$rec.Etat; q = (ConvertTo-FiniteOrNull $rec.Q); tQ = (ConvertTo-FiniteOrNull $rec.TQ)
                       chi2Ddl = (ConvertTo-FiniteOrNull $rec.Chi2Ddl); nPass = [int]$rec.NPass
                       zones = @(@($rec.Zones) | Where-Object { $null -ne $_ } | ForEach-Object { $zk = ConvertTo-FiniteOrNull $_.K; [ordered]@{ z = [int]$_.Z; k = $(if ($null -ne $zk) { [math]::Round([double]$zk, 2) } else { $null }) } }) }
}

function ConvertFrom-ContentConfig($o) {
    # Entree de write.driveFactors -> enregistrement de mesure (C.2) ; $null (ignoree par Load-Config, ligne T-C14) sans
    # drive ou family, avec head autre que 0 ou 1, ou avec k non fini ou hors de [0 ; 1]. KVertex : $null sans sommet ;
    # autres nombres absents : NaN (F : k ; 12.10 : le champ dk n est plus lu). 12.9 : k de 0 a ContentKMax (2) pour les
    # etats 'mesure', 'haute', 'basse' et les enregistrements sans etat (avant la 12.9) ; autre etat (marge plate, peu
    # determine) : k absent admis (NaN). Marque absente : '' (« non precisee ») ; Zones : @{ Z ; K }
    if ($null -eq $o) { return $null }
    try {
        $k = ConvertTo-FiniteOrNull $o.k; $hd = ConvertTo-FiniteOrNull $o.head
        $etat = [string]$o.etat
        $kMax = if ([double]$script:ContentKMax -gt 0) { [double]$script:ContentKMax } else { 2.0 }
        $kBad = if (@('', 'mesure', 'haute', 'basse') -contains $etat) { $null -eq $k -or $k -lt 0 -or $k -gt $kMax } else { $false }
        if (-not [string]$o.drive -or -not [string]$o.family -or $null -eq $hd -or ($hd -ne 0 -and $hd -ne 1) -or $kBad) { return $null }
        $nan = [double]::NaN
        $kd = if ($null -ne $k) { [double]$k } else { $nan }
        return @{ Model = $(if ($o.model) { [string]$o.model } else { 'contenu' }); Drive = [string]$o.drive; Family = [string]$o.family; Head = [int]$hd
                  Date = [string]$o.date; Image = [string]$o.image; K = $kd; KVertex = (ConvertTo-FiniteOrNull $o.kVertex); Bound = [string]$o.bound
                  Flat = ($o.flat -eq $true); SeK = (Get-ConfigDouble $o.seK $nan); B1 = (Get-ConfigDouble $o.b1 $nan); B2 = (Get-ConfigDouble $o.b2 $nan)
                  Gain = (Get-ConfigDouble $o.gain $nan); S = (Get-ConfigDouble $o.s $nan); NCyl = [int]$o.nCyl; NObs = [int]$o.nObs; NExcl = [int]$o.nExcl
                  Levels = [double[]]@($o.levels | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
                  F = (Get-ConfigDouble $o.f $kd); Values = [int[]]@(Get-RecValues $o | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
                  Spec = [string]$o.spec; RefKey = [string]$o.refKey; RefDate = [string]$o.refDate; Calc = [string]$o.calc
                  ContentCalc = [string]$o.contentCalc; Version = [string]$o.version
                  Brand = ([string]$o.brand).Trim(); Etat = $etat; Q = (Get-ConfigDouble $o.q $nan); TQ = (Get-ConfigDouble $o.tQ $nan)
                  Chi2Ddl = (Get-ConfigDouble $o.chi2Ddl $nan); NPass = [int]$o.nPass
                  Zones = @(@($o.zones) | Where-Object { $null -ne $_ } | ForEach-Object { @{ Z = [int]$_.z; K = (Get-ConfigDouble $_.k $nan) } }) }
    } catch { return $null }
}

function Get-ContentBrandItems([string]$drive, [string]$fam) {
    # 12.9 (code-et-calibration § 2.1) : elements de la liste « Marque » de la fenetre « Mesure de la disquette », dans
    # l ordre : « (non precisee) » ; marques mesurees (etat 'mesure') avec le calcul actuel pour ce lecteur et cette famille,
    # de la plus recente a la plus ancienne (« {0} - facteur memorise le {1} ») ; marques mesurees avec un autre calcul
    # seulement (« {0} - a remesurer (calcul change) ») ; autres marques des mesures, puis noms de la memoire de marque
    # (levelBrands, tous lecteurs). Dedoublonnage par Get-LevelBrandKey. Rend @{ Items ; Map (texte -> marque) }
    $none = (T '(non précisée)'); $map = @{ $none = '' }; $items = @($none); $seen = @{ '' = $true }
    $ok = [ordered]@{}; $stale = [ordered]@{}; $plain = [ordered]@{}
    $recs = @(@($script:ContentMeasures) | Where-Object { $null -ne $_ -and [string]$_.Drive -eq $drive -and [string]$_.Family -eq $fam } | Sort-Object { Get-CurveDate $_ } -Descending)
    foreach ($r in $recs) {
        $bk = Get-LevelBrandKey ([string]$r.Brand); if (-not $bk) { continue }
        $nm = ([string]$r.Brand).Trim()
        $cur = ([string]$r.ContentCalc -eq [string]$script:ContentCalc -and [string]$r.Calc -eq [string]$script:CalibCalc)
        if ($cur -and [string]$r.Etat -eq 'mesure') { if (-not $ok.Contains($bk)) { $ok[$bk] = @{ Name = $nm; Date = [string]$r.Date } } }
        elseif (-not $cur) { if (-not $stale.Contains($bk)) { $stale[$bk] = $nm } }
        elseif (-not $plain.Contains($bk)) { $plain[$bk] = $nm }
    }
    foreach ($bk in @($ok.Keys)) { $t = (T '{0} - facteur mémorisé le {1}') -f "$($ok[$bk].Name)", "$($ok[$bk].Date)"; $map[$t] = [string]$ok[$bk].Name; $items += $t; $seen[$bk] = $true }
    foreach ($bk in @($stale.Keys)) { if ($seen.ContainsKey($bk)) { continue }; $t = (T '{0} - à remesurer (calcul changé)') -f "$($stale[$bk])"; $map[$t] = [string]$stale[$bk]; $items += $t; $seen[$bk] = $true }
    foreach ($bk in @($plain.Keys)) { if ($seen.ContainsKey($bk)) { continue }; $map[[string]$plain[$bk]] = [string]$plain[$bk]; $items += [string]$plain[$bk]; $seen[$bk] = $true }
    foreach ($en in @(@($script:LevelBrands) | Where-Object { $_ } | Sort-Object { Get-CurveDate $_ } -Descending)) {
        $nm = ([string]$en.Brand).Trim(); $bk = Get-LevelBrandKey $nm
        if (-not $bk -or $seen.ContainsKey($bk)) { continue }
        $map[$nm] = $nm; $items += $nm; $seen[$bk] = $true
    }
    return @{ Items = $items; Map = $map }
}

function Get-ContentScpPath([string]$dir, [string]$stamp, [string]$drive, [int]$pass) {
    # 12.9 (D6) : relecture gardee de la passe $pass (1..4) d une mesure sur l image, contenu-AAAAMMJJ-HHMMSS-<lecteur>-p<n>.scp
    # dans $dir (TempDir\mesures-image) ; $pass <= 0 : fichier compagnon contenu-AAAAMMJJ-HHMMSS-<lecteur>.json
    $d = ([string]$drive) -replace '[^A-Za-z0-9]', ''
    if ($pass -le 0) { return (Join-Path $dir "contenu-$stamp-$d.json") }
    return (Join-Path $dir "contenu-$stamp-$d-p$pass.scp")
}

function Get-ContentKeepPlan($files, [int]$n) {
    # 12.9 (D6) : fichiers a supprimer pour ne garder que les $n mesures les plus recentes (0 : toutes supprimees) ; seuls
    # les fichiers contenu-AAAAMMJJ-HHMMSS-<lecteur>-p<n>.scp et contenu-AAAAMMJJ-HHMMSS-<lecteur>.json comptent (autres
    # noms ignores), regroupes par mesure (horodatage et lecteur), la plus recente d abord
    $grp = @{}
    foreach ($f in @($files)) {
        if (-not $f) { continue }
        $m = [regex]::Match([System.IO.Path]::GetFileName([string]$f), '^contenu-(\d{8}-\d{6})-([A-Za-z0-9]+)(?:-p\d+\.scp|\.json)$')
        if (-not $m.Success) { continue }
        $g = "$($m.Groups[1].Value)-$($m.Groups[2].Value)"
        if (-not $grp.ContainsKey($g)) { $grp[$g] = New-Object 'System.Collections.Generic.List[string]' }
        $grp[$g].Add([string]$f)
    }
    # Rendu dans le pipeline, un chemin par element (l appelant l enveloppe dans @() ; aucun : rien)
    $ks = @($grp.Keys | Sort-Object -Descending)
    $del = @(); for ($i = [math]::Max(0, $n); $i -lt $ks.Count; $i++) { $del += @($grp[$ks[$i]]) }
    return $del
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
