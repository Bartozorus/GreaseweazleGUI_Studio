# ============================== FONCTIONS : CALIBRATION RAPIDE ADAPTATIVE ======

# 12.8 (lot 1c) : calibration rapide adaptative (LevelAlgo 'lvl2', variante prudente V3, c1-design.md § 3). Deroulement
# lvl1 inchange tant que la forme est conforme. Forme non conforme (declencheur A : bascule anticipee de la passe 1 ;
# declencheur B : forme non conforme a f = 1 en fin de passe 1 ou 2, confirmee a la passe 2 par les zeros a la pente de
# reference) : passe de mesure a une deuxieme precompensation (pente propre et vrai zero de chaque cylindre), ajustement
# niveau / echelle / pente (moindres carres ponderes, choix par validation croisee ; ecart isole nomme et ecarte, jamais
# absorbe ; residus peu lisses : reserve ; au-dela : refus), puis passe de verification sur les cylindres ajustes et 2
# cylindres de controle hors ajustement. Au plus 3 ecritures par piste. Get-CalibZero, Limit-CalibZero, Get-ResidualTol,
# LevelTauOk et LevelTauMax sont lus, jamais modifies. Reference executable : v128\c1\v3-prudent.py (meme calcul,
# memes decisions ; oracle sans interface : suite calib-lvl2). Aucun Add-Type : systemes 3 x 3 resolus en PowerShell.
# 12.8 corrigee (F3R, decisions du 21/10/2026, reference v128\c3\final\v3f.py, oracle impl128\f3rport\oracle\calib-f3r.ps1) :
# terme de centre hc ((c - 60)+ / 19)^2 ajuste sur les controles a la passe de verification (Get-LevelCenterEval) ou
# repris d un refus de la passe de mesure (e3, Get-LevelCenterRescue) ; controle juge par la corde de ses deux ecritures
# (e1) ; courbe adaptee gardee avec reserve apres un refus par un controle (e2) ; derive corrigee avant le plafond (e4),
# gardee et niveau dit verifie dans la tolerance par cylindre (Bk) ; plafond par disquette jusqu a CalHardMaxNs
# (Get-LevelAdaptHard) ; libelle neutre de la fatigue pour une forme non conforme ; reserve de controle ou de centre
# jamais memorisee pour la marque. Au plus 3 passes et 3 ecritures par piste ; disquettes habituelles inchangees.
# F3R-FIX (21/10/2026, reference alignee v128\c3\final2\v3f.py, oracle impl128\f3rfix\oracle\calib-f3r.ps1) : cylindres
# Clip hors du declenchement du plafond par disquette et qui le suivent quand il est porte au-dela de CalHardNs ; seuil
# max(400, CalHardNs) ; controle neuf au plus au dernier cylindre de l image.

function New-LevelShape($ref) {
    # Colonnes du modele de forme d une tete, relatives a sa reference : a (niveau), s (echelle centree sur la moyenne
    # RBar de la reference), b (pente du premier au dernier cylindre, centree)
    $vals = [double[]]@(@($ref) | ForEach-Object { [double]$_ })
    $sum = 0.0; foreach ($x in $vals) { $sum += $x }
    return @{ V = $vals; N = $vals.Count; RBar = $sum / $vals.Count }
}

function Get-LevelShapeRow($sh, [string[]]$names, [int]$c) {
    # 12.8 (F3R) : colonne hc, terme de centre ((c - LevelCenterC0)+ / (n - 1 - LevelCenterC0))^2, 0 jusqu a c60 et 1 au
    # dernier cylindre ; b (pente) explicite
    $row = New-Object double[] $names.Count
    for ($i = 0; $i -lt $names.Count; $i++) {
        if ($names[$i] -eq 'a') { $row[$i] = 1.0 }
        elseif ($names[$i] -eq 's') { $row[$i] = [double]$sh.V[$c] - [double]$sh.RBar }
        elseif ($names[$i] -eq 'hc') { $t = [math]::Max(0.0, $c - [double]$script:LevelCenterC0) / [double]($sh.N - 1 - $script:LevelCenterC0); $row[$i] = [math]::Pow($t, 2) }
        else { $row[$i] = ($c - ($sh.N - 1) / 2.0) / [double]($sh.N - 1) }
    }
    return ,$row
}

function Invoke-LevelSolve($A, $y) {
    # Resout A x = y (petit systeme, Gauss-Jordan a pivot partiel, comme v3-prudent.py) ; $null si singulier
    $n = $A.Count
    $M = New-Object 'object[]' $n
    for ($i = 0; $i -lt $n; $i++) { $r = New-Object double[] ($n + 1); for ($j = 0; $j -lt $n; $j++) { $r[$j] = [double]$A[$i][$j] }; $r[$n] = [double]$y[$i]; $M[$i] = $r }
    for ($col = 0; $col -lt $n; $col++) {
        $piv = $col; $best = [math]::Abs($M[$col][$col])
        for ($r = $col + 1; $r -lt $n; $r++) { if ([math]::Abs($M[$r][$col]) -gt $best) { $best = [math]::Abs($M[$r][$col]); $piv = $r } }
        if ($best -lt 1e-12) { return $null }
        $tmp = $M[$col]; $M[$col] = $M[$piv]; $M[$piv] = $tmp
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $col) { continue }
            $f = $M[$r][$col] / $M[$col][$col]
            for ($k = $col; $k -le $n; $k++) { $M[$r][$k] -= $f * $M[$col][$k] }
        }
    }
    $x = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $x[$i] = $M[$i][$n] / $M[$i][$i] }
    return ,$x
}

function Get-LevelInverse($A) {
    $n = $A.Count
    $cols = @()
    for ($j = 0; $j -lt $n; $j++) {
        $e = New-Object double[] $n; $e[$j] = 1.0
        $x = Invoke-LevelSolve $A $e
        if ($null -eq $x) { return $null }
        $cols += ,$x
    }
    $inv = New-Object 'object[]' $n
    for ($i = 0; $i -lt $n; $i++) { $r = New-Object double[] $n; for ($j = 0; $j -lt $n; $j++) { $r[$j] = $cols[$j][$i] }; $inv[$i] = $r }
    return ,$inv
}

function Get-LevelWls($sh, [string[]]$names, [int[]]$cs, $d, $sig) {
    # Moindres carres ponderes (poids 1 / (sig^2 + LevelShapeFloor^2)) des ecarts d(c) a la reference : coefficients,
    # covariance (echelle max(1, chi2 / ddl)), residus, ecart de forme residuel tau ; $null si sous-determine ou singulier
    $p = $names.Count; $n = $cs.Count
    if ($n -lt $p) { return $null }
    $t02 = [math]::Pow([double]$script:LevelShapeFloor, 2)
    $w = @{}; foreach ($c in $cs) { $w[$c] = 1.0 / ([math]::Pow([double]$sig[$c], 2) + $t02) }
    $A = New-Object 'object[]' $p; for ($i = 0; $i -lt $p; $i++) { $A[$i] = New-Object double[] $p }
    $y = New-Object double[] $p
    foreach ($c in $cs) {
        $x = Get-LevelShapeRow $sh $names $c
        for ($i = 0; $i -lt $p; $i++) {
            $y[$i] += $w[$c] * $x[$i] * [double]$d[$c]
            for ($j = 0; $j -lt $p; $j++) { $A[$i][$j] += $w[$c] * $x[$i] * $x[$j] }
        }
    }
    $beta = Invoke-LevelSolve $A $y
    $inv = Get-LevelInverse $A
    if ($null -eq $beta -or $null -eq $inv) { return $null }
    $res = @{}
    foreach ($c in $cs) { $x = Get-LevelShapeRow $sh $names $c; $s = 0.0; for ($i = 0; $i -lt $p; $i++) { $s += $beta[$i] * $x[$i] }; $res[$c] = [double]$d[$c] - $s }
    $dof = $n - $p
    $chi = 0.0; foreach ($c in $cs) { $chi += $w[$c] * [math]::Pow($res[$c], 2) }
    $scale = if ($dof -gt 0) { [math]::Max(1.0, $chi / $dof) } else { 1.0 }
    $cov = New-Object 'object[]' $p
    for ($i = 0; $i -lt $p; $i++) { $r = New-Object double[] $p; for ($j = 0; $j -lt $p; $j++) { $r[$j] = $inv[$i][$j] * $scale }; $cov[$i] = $r }
    $ss = 0.0; foreach ($c in $cs) { $ss += [math]::Pow($res[$c], 2) }
    $ms = 0.0; foreach ($c in $cs) { $ms += [math]::Pow([double]$sig[$c], 2) }
    $tau = if ($dof -gt 0) { [math]::Sqrt([math]::Max(0.0, $ss / $dof - $ms / $n)) } else { 0.0 }
    $coef = @{}; for ($i = 0; $i -lt $p; $i++) { $coef[$names[$i]] = $beta[$i] }
    return @{ Names = $names; Coef = $coef; Beta = $beta; Cov = $cov; Res = $res; Cs = $cs; Tau = $tau; W = $w; N = $n; P = $p }
}

function Get-LevelPredict($sh, $fit, [int]$c) {
    # Valeur du modele au cylindre c (ecart a la reference) et son ecart-type
    $x = Get-LevelShapeRow $sh ([string[]]$fit.Names) $c
    $v = 0.0; for ($i = 0; $i -lt $x.Count; $i++) { $v += $fit.Beta[$i] * $x[$i] }
    $var = 0.0
    for ($i = 0; $i -lt $x.Count; $i++) { for ($j = 0; $j -lt $x.Count; $j++) { $var += $x[$i] * $fit.Cov[$i][$j] * $x[$j] } }
    return ,@($v, [math]::Sqrt([math]::Max(0.0, $var)))
}

function Get-LevelLoo($sh, [string[]]$names, [int[]]$cs, $d, $sig) {
    # Validation croisee, un cylindre retire : residu de prevision et son ecart-type ; $null si un ajustement manque
    $t02 = [math]::Pow([double]$script:LevelShapeFloor, 2)
    $out = @{}
    foreach ($c in $cs) {
        $rest = [int[]]@($cs | Where-Object { $_ -ne $c })
        $f = Get-LevelWls $sh $names $rest $d $sig
        if (-not $f) { return $null }
        $pr = Get-LevelPredict $sh $f $c
        $out[$c] = @{ R = [double]$d[$c] - $pr[0]; Sd = [math]::Sqrt([math]::Pow([double]$sig[$c], 2) + $t02 + [math]::Pow($pr[1], 2)) }
    }
    return $out
}

function Get-LevelMinFit([int]$p) {
    if ($p -eq 1) { return 3 }
    if ($p -eq 2) { return 5 }
    return [int]$script:LevelAdaptMinFit
}

function Select-LevelModel($sh, [int[]]$cs, $d, $sig) {
    # Choix du modele M0 {a}, Ms {a,s}, Mb {a,b}, Msb {a,s,b} : validation croisee ponderee (PRESS) penalisee par terme de
    # forme ; terme de forme retenu au-dela de LevelAdaptCoefZ erreurs-types ; modele admissible si aucun residu ne depasse
    # max(CalDevNs ; 4 et.). Renvoie @{ Best ; Cand } ou $null
    $models = @(@('M0', @('a')), @('Ms', @('a', 's')), @('Mb', @('a', 'b')), @('Msb', @('a', 's', 'b')))
    $cand = @()
    foreach ($m in $models) {
        $name = [string]$m[0]; $names = [string[]]@($m[1])
        if ($cs.Count -lt (Get-LevelMinFit $names.Count)) { continue }
        $f = Get-LevelWls $sh $names $cs $d $sig
        if (-not $f) { continue }
        $lv = Get-LevelLoo $sh $names $cs $d $sig
        if (-not $lv) { continue }
        $press = 0.0; foreach ($c in $cs) { $press += $f.W[$c] * [math]::Pow($lv[$c].R, 2) }
        $signif = $true
        for ($i = 0; $i -lt $names.Count; $i++) {
            if ($names[$i] -eq 'a') { continue }
            $se = [math]::Sqrt([math]::Max(1e-12, $f.Cov[$i][$i]))
            if ([math]::Abs($f.Beta[$i]) -lt $script:LevelAdaptCoefZ * $se) { $signif = $false }
        }
        $admit = $true; foreach ($c in $cs) { if ([math]::Abs($f.Res[$c]) -gt [math]::Max([double]$script:CalDevNs, 4.0 * [double]$sig[$c])) { $admit = $false } }
        $cand += ,@{ Name = $name; Fit = $f; Loo = $lv; Press = $press; Score = $press * (1.0 + $script:LevelAdaptParsimony * ($names.Count - 1)); Signif = $signif; Admit = $admit }
    }
    $ok = @($cand | Where-Object { $_.Signif -or $_.Name -eq 'M0' })
    if (@($ok | Where-Object { $_.Admit }).Count -gt 0) { $ok = @($ok | Where-Object { $_.Admit }) }
    if ($ok.Count -eq 0) { return $null }
    $best = $ok[0]; foreach ($x in $ok) { if ($x.Score -lt $best.Score) { $best = $x } }
    return @{ Best = $best; Cand = $cand }
}

function Get-LevelOwnSlope($pts) {
    # Pente propre (decalage par ns ecrit) entre les deux valeurs ecrites extremes, et leur ecart ; $null sous 2 mesures
    if (-not $pts) { return $null }
    $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($xs.Count -lt 2) { return $null }
    return @{ A = ([double]$pts[$xs[-1]].Shift - [double]$pts[$xs[0]].Shift) / [double]($xs[-1] - $xs[0]); Span = $xs[-1] - $xs[0] }
}

function Get-LevelNearest($pts) {
    # Valeur ecrite dont le decalage est le plus proche de zero (premiere dans l ordre croissant en cas d egalite)
    $best = $null; $bv = 0.0
    foreach ($x in @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object)) { $a = [math]::Abs([double]$pts[$x].Shift); if ($null -eq $best -or $a -lt $bv) { $best = $x; $bv = $a } }
    return $best
}

function Get-LevelAdaptZero($pts, [double]$k) {
    # Zero d un cylindre : Get-CalibZero (inchange) si les valeurs ecrites sont ecartees d au moins LevelAdaptDeltaMin ;
    # sinon point le plus proche du zero et pente donnee (une petite base rend la pente propre trop bruitee)
    if (-not $pts) { return $null }
    $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($xs.Count -eq 0) { return $null }
    if ($xs.Count -ge 2 -and ($xs[-1] - $xs[0]) -ge $script:LevelAdaptDeltaMin) { return (Get-CalibZero $pts (-$k)) }
    $x = Get-LevelNearest $pts
    return (Get-LevelZero @{ $x = $pts[$x] } $k)
}

function Get-LevelFitCyls($u) {
    # Cylindres d ajustement : cylindres de niveau et temoins de marche (les cylindres de controle en sont exclus). 12.8
    # (F3R, e3) : plus les controles integres a l ajustement par une reprise avec un terme de centre (CtlFit)
    return ,[int[]]@(@(@($u.LCyls) + @($u.Wit) + @($u.CtlFit)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
}

function Get-LevelCtlCyls($units, [int]$maxCyl) {
    # Cylindres de controle hors ajustement, communs aux deux tetes : mesures fiables de la reference (memes regles que
    # Get-LevelCands, sans les bornes de 20 a 260 ns), hors cylindres de niveau, temoins et leurs voisins ; le premier dans
    # LevelAdaptCtlLo..(dernier - 4), au plus loin des cylindres de niveau et temoins, le second en bout de face (dernier - 1,
    # dernier, dernier - 2). Dernier : fin de la reference, au plus le dernier cylindre de l image (MaxCyl)
    # 12.8 (FIX1C, constat 1) : valeurs de la reference du lecteur (V0), jamais du point de depart d une marque (V') : un
    # seul choix, celui que l avertissement annonce (c1-design.md § 3.2 : controles choisis avant le point de depart)
    $us = @($units)
    if ($us.Count -eq 0) { return ,[int[]]@() }
    $last = [int](@($us | ForEach-Object { @($_.V).Count } | Measure-Object -Minimum).Minimum) - 1
    if ($maxCyl -ge 0) { $last = [math]::Min($last, $maxCyl) }
    $taken = @{}
    foreach ($u in $us) { foreach ($c in @(@($u.LCyls) + @($u.Wit))) { $taken[[int]$c] = $true } }
    $hard = [double]$script:CalHardNs
    $okc = {
        param([int]$c)
        if ($taken.ContainsKey($c) -or $taken.ContainsKey($c - 1) -or $taken.ContainsKey($c + 1)) { return $false }
        foreach ($u in $us) {
            $cv = $u.Cv
            $cyls = @(@($cv.Cyls) | ForEach-Object { [int]$_ })
            $i = -1; for ($q = 0; $q -lt $cyls.Count; $q++) { if ($cyls[$q] -eq $c) { $i = $q; break } }
            if ($i -lt 0) { return $false }
            if ($cv.Kinds -and $i -lt @($cv.Kinds).Count -and [string]$cv.Kinds[$i] -ne 'interp') { return $false }
            if (Test-CurvePointFlag $cv $i) { return $false }
            $vc = if ($null -ne $u.V0) { [double]$u.V0[$c] } else { [double]$u.V[$c] }
            if ($vc -le 5 -or $vc -ge $hard - 15) { return $false }
            foreach ($b in @(@($cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })) { if ([math]::Abs($c - $b) -le 1 -or [math]::Abs($c - ($b + 1)) -le 1) { return $false } }
        }
        return $true
    }
    $out = @()
    $end = @(@(($last - 1), $last, ($last - 2)) | Where-Object { $_ -ge 0 -and (& $okc $_) })
    $mid = @(); for ($c = [int]$script:LevelAdaptCtlLo; $c -lt $last - 3; $c++) { if (& $okc $c) { $mid += $c } }
    if ($mid.Count -gt 0) {
        $best = $null; $bd = -1
        foreach ($c in $mid) {
            $dm = [int]::MaxValue; foreach ($t in @($taken.Keys)) { $dt = [math]::Abs($c - [int]$t); if ($dt -lt $dm) { $dm = $dt } }
            if ($dm -gt $bd -or ($dm -eq $bd -and $c -gt $best)) { $bd = $dm; $best = $c }
        }
        $out += $best
    }
    if ($end.Count -gt 0) { $out += $end[0] }
    $out = @($out | Select-Object -First ([int]$script:LevelAdaptCtlCyls))
    return ,[int[]]@($out | Sort-Object)
}

function Get-LevelKrefEstimate($u) {
    # Estimation du niveau a la pente de reference sur le point le plus proche du zero de chaque cylindre : une derive
    # entre deux passes proches n y cree pas de forme fictive (la pente propre sur 4 a 20 ns l amplifierait). Meme forme
    # que Get-LevelEstimate pour Test-LevelShape
    $ds = @{}; $sg = @{}
    foreach ($c in @($u.LCyls)) {
        $pts = $u.Results[[int]$c]
        if (-not $pts -or $pts.Count -eq 0) { continue }
        $x = Get-LevelNearest $pts
        $z = Get-LevelZero @{ $x = $pts[$x] } ([double]$u.KRef)
        if ($z -and $z.Kind -ne 'cap') { $ds[[int]$c] = [double]$z.Est - [double]$u.V[[int]$c]; $sg[[int]$c] = [double]$z.Sig }
    }
    $e = Get-LevelStats $ds $sg
    $e.Wit = @{}
    foreach ($c in @($u.Wit)) {
        $pts = $u.Results[[int]$c]
        if (-not $pts -or $pts.Count -eq 0) { continue }
        $x = Get-LevelNearest $pts
        $z = Get-LevelZero @{ $x = $pts[$x] } ([double]$u.KRef)
        if ($z -and $z.Kind -ne 'cap') { $e.Wit[[int]$c] = @{ D = [double]$z.Est - [double]$u.V[[int]$c]; Sig = [double]$z.Sig; Z = [double]$z.Est } }
    }
    return $e
}

function Test-LevelAdaptEligible($cal, $u, $e) {
    # Garde-fous du declenchement (c1-design.md § 3.2, G6). Renvoie @{ Ok ; Why ; G6 } (G6 : courbe commune ou temoin du
    # plafond, comportement lvl1 avec une reserve)
    if ($null -eq $u.Head) { return @{ Ok = $false; G6 = $true; Why = (T "courbe commune aux deux faces : l'écriture lente adapte la courbe de chaque face") } }
    if ($null -ne $u.Probe) { return @{ Ok = $false; G6 = $true; Why = ((T 'référence plafonnée vers le centre (témoin c{0})') -f "$($u.Probe)") } }
    if ($cal.SurfGross) { return @{ Ok = $false; G6 = $false; Why = (T 'défaut grossier de surface à la première passe') } }
    if ($cal.Surf -and $cal.Surf.Faces -and $cal.Surf.Faces[[int]$u.Head] -and $cal.Surf.Faces[[int]$u.Head].Defective) { return @{ Ok = $false; G6 = $false; Why = (T 'disquette douteuse sur cette face à la première passe') } }
    if ($u.Fail -or $u.Sat -or $u.Low -or $u.Few -or [int]$e.N -lt 4 -or (@($e.Capped).Count + @($e.Floored).Count) -gt 2) { return @{ Ok = $false; G6 = $false; Why = (T 'trop peu de cylindres mesurables') } }
    foreach ($c in @(@($u.LCyls) + @($u.Wit))) { if ([int]$u.Writes[[int]$c] -gt 2) { return @{ Ok = $false; G6 = $false; Why = (T "budget d'écritures atteint") } } }
    return @{ Ok = $true; G6 = $false; Why = '' }
}

function Add-LevelCalCyls($cal, [int[]]$cyls) {
    # Cylindres de controle ajoutes aux cylindres lus de la calibration (Invoke-CalibAnalysis ne lit que $cal.Cyls)
    $all = @{}; foreach ($c in @($cal.Cyls)) { $all[[int]$c] = $true }
    foreach ($c in $cyls) { $all[[int]$c] = $true }
    $cal.Cyls = [int[]]@($all.Keys | Sort-Object)
}

function Set-LevelAdaptTargets($cal, $u, $e) {
    # Passe de mesure (declenchement a la passe 1) : chaque cylindre de niveau et temoin ecrit a w1 + LevelAdaptOvershoot
    # x (zero de la passe 1 - w1), a LevelAdaptDeltaMin au moins de w1, borne a 0..CalHardNs ; cylindres de controle a la
    # prediction d un ajustement des zeros de la passe 1 a la pente de reference (placement seulement)
    $t = @{}; $mx = [int]$script:CalHardNs; $dmin = [int]$script:LevelAdaptDeltaMin
    foreach ($c in (Get-LevelFitCyls $u)) {
        $pts = $u.Results[$c]
        if (-not $pts -or $pts.Count -eq 0) { continue }
        $w1 = [int](@($pts.Keys | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum)
        $z = Get-LevelZero $pts ([double]$u.KRef)
        $z1 = if ($z) { [double]$z.Est } else { [double]$w1 }
        $dz = ($z1 - $w1) * [double]$script:LevelAdaptOvershoot
        $sg = [math]::Sign($dz); if ($sg -eq 0) { $sg = $(if ([double]$pts[$w1].Shift -ge 0) { 1 } else { -1 }) }
        $w2 = if ([math]::Abs($dz) -ge $dmin) { [int][math]::Round($w1 + $dz) } else { $w1 + $sg * $dmin }
        if ($w2 -gt $mx -or $w2 -lt 0) {
            $w2 = [math]::Max(0, [math]::Min($mx, $w2))
            if ([math]::Abs($w2 - $w1) -lt $dmin) { $w2 = $w1 - $sg * $dmin }
        }
        $t[$c] = [int][math]::Max(0, [math]::Min($mx, $w2))
    }
    # Controles : modele ajuste sur les zeros de la passe 1 (pente de reference), sans garde-fou
    $sh = $u.ShapeV; $cs = @(); $d = @{}; $sgm = @{}
    foreach ($c in (Get-LevelFitCyls $u)) {
        $z = Get-LevelZero $u.Results[$c] ([double]$u.KRef)
        if ($z -and $z.Kind -ne 'cap') { $cs += $c; $d[$c] = [double]$z.Est - $sh.V[$c]; $sgm[$c] = [double]$z.Sig }
    }
    $sel = if ($cs.Count -ge 3) { Select-LevelModel $sh ([int[]]$cs) $d $sgm } else { $null }
    foreach ($x in @($u.Ctl)) {
        $v = if ($sel) { (Get-LevelPredict $sh $sel.Best.Fit ([int]$x))[0] } elseif (-not [double]::IsNaN([double]$e.Delta)) { [double]$e.Delta } else { [double]$u.D }
        $t[[int]$x] = [int][math]::Max(0, [math]::Min($mx, [math]::Round($sh.V[[int]$x] + $v)))
    }
    $u.LTarget = $t
    $u.Mode = 'meas'
    Add-LevelCalCyls $cal ([int[]]@($u.Ctl))
    $cal.TotalPasses = [math]::Max([int]$cal.TotalPasses, [int]$script:LevelMaxPasses)
}

function Format-LevelSigned([double]$x) { return ('{0:+0;-0;0}' -f [math]::Round($x, 0)) }

function Get-LevelAdaptFit($u) {
    # Zeros de toutes les passes, pente propre, choix et controle de la forme (analyse_fit de v3-prudent.py). Renvoie
    # @{ Ok ; Why ('nowrite' : pente nulle sur la base large) ; KPool ; Ks ; Named ; Model ; Fit ; Cs ; Eff ; Loo ; M0 ;
    # Reserve ; Zs ; D ; Sig ; Cap ; BadK ; Iso }
    $sh = $u.ShapeV; $mx = [int]$script:CalHardNs; $kref = [double]$u.KRef
    $klo = [double]$script:LevelAdaptKRatioLo * $kref; $khi = [double]$script:LevelAdaptKRatioHi * $kref
    $fc = Get-LevelFitCyls $u
    $ks = @{}; $kOrder = @()
    foreach ($c in $fc) {
        $os = Get-LevelOwnSlope $u.Results[$c]
        if ($os -and $os.Span -ge $script:LevelAdaptDeltaMin) { $ks[$c] = -[double]$os.A; $kOrder += $c }
    }
    $kv = @($kOrder | ForEach-Object { $ks[$_] } | Where-Object { $klo -le $_ -and $_ -le $khi })
    $kpool = if ($kv.Count -gt 0) { [math]::Max($klo, [math]::Min($khi, [double](Get-Median $kv))) } else { $kref }
    $out = @{ Ok = $false; Why = ''; WhyCode = 'other'; KPool = $kpool; Ks = $ks; KOrder = $kOrder; Named = @{}; Model = $null; Excl = @(); Reserve = @(); Iso = @{}; Zs = @{}; D = @{}; Sig = @{}; Cap = @(); BadK = @() }
    # Pente nulle : meme critere que Invoke-LevelStep, sur la base large de la passe de mesure
    $sl = @($kOrder | ForEach-Object { -$ks[$_] })
    if ($sl.Count -ge 3 -and [double](Get-Median $sl) -ge [math]::Max(-0.2, -0.5 * $kref) -and $kref * $script:LevelAdaptDeltaMin -ge 4.0) { $out.Why = 'nowrite'; return $out }
    $badK = @($kOrder | Where-Object { -not ($klo -le $ks[$_] -and $ks[$_] -le $khi) } | Sort-Object)
    $dOrder = @()
    foreach ($c in $fc) {
        $kk = if ($ks.ContainsKey($c) -and $badK -notcontains $c) { $ks[$c] } else { $kpool }
        $z = Get-LevelAdaptZero $u.Results[$c] $kk
        if (-not $z) { continue }
        $out.Zs[$c] = $z
        if ($z.Kind -eq 'cap') { $out.Cap += $c; continue }
        $out.D[$c] = [double]$z.Est - $sh.V[$c]; $out.Sig[$c] = [double]$z.Sig; $dOrder += $c
    }
    $out.BadK = $badK
    $d = $out.D; $sg = $out.Sig
    if ($badK.Count -ge 2) {
        $out.Why = (T 'pente propre invraisemblable aux cylindres {0} ({1} fois la référence)') -f (Format-CylList ([int[]]$badK)), ((@($badK | ForEach-Object { Format-UiNum ([math]::Round($ks[$_] / $kref, 1)) '0.#' })) -join ', ')
        return $out
    }
    foreach ($c in $badK) { $out.Named[$c] = (T 'pente propre invraisemblable ({0} fois la référence)') -f (Format-UiNum ([math]::Round($ks[$c] / $kref, 1)) '0.#') }
    $pre = @($fc | Where-Object { $u.Named -and $u.Named.ContainsKey($_) })
    $cs = @($dOrder | Where-Object { $badK -notcontains $_ -and $pre -notcontains $_ })
    if ($pre.Count + $badK.Count -ge 2) {
        $out.WhyCode = 'scatter'
        $out.Why = (T 'écarts dispersés ({0} cylindres signalés : {1})') -f "$($pre.Count + $badK.Count)", (Format-CylList ([int[]]@(@($pre) + @($badK))))
        return $out
    }
    $nexc = $pre.Count + $badK.Count
    if ($out.Cap.Count -gt 2) { $out.Why = (T 'besoin hors de 0 à {0} ns à {1} cylindres mesurés') -f "$mx", "$($out.Cap.Count)"; return $out }
    if ($cs.Count -lt $script:LevelAdaptMinFit) { $out.Why = (T 'trop peu de cylindres mesurables ({0})') -f "$($cs.Count)"; return $out }
    $sel = Select-LevelModel $sh ([int[]]$cs) $d $sg
    if (-not $sel) { $out.Why = (T 'forme impossible à ajuster'); return $out }
    $best = $sel.Best
    # Ecart isole en validation croisee : un seul, nomme et ecarte, puis nouveau choix ; deux ou plus : dispersion
    $outl = {
        param($b)
        $o = @()
        foreach ($c in @($b.Fit.Cs)) {
            $lv = $b.Loo[$c]
            $thr = [math]::Min([math]::Max([double]$script:LevelAdaptLooFloor, [double]$script:LevelAdaptLooK * $lv.Sd), [double]$script:LevelAdaptLooCap)
            if ([math]::Abs($lv.R) -gt $thr) { $o += ,@{ Q = [math]::Abs($lv.R) / $thr; C = [int]$c; R = [double]$lv.R; Thr = $thr } }
        }
        return ,@($o | Sort-Object -Property @{ Expression = { $_.Q }; Descending = $true }, @{ Expression = { $_.C }; Descending = $true })
    }
    $o = & $outl $best
    if ($o.Count -gt 0 -and $nexc -ge 1) {
        $out.WhyCode = 'scatter'
        $out.Why = (T 'écarts dispersés ({0} signalé, c{1} hors de la forme ajustée)') -f (Format-CylList ([int[]]@(@($pre) + @($badK)))), "$($o[0].C)"
        $out.Named[$o[0].C] = (T 'écart dispersé')
        return $out
    }
    if ($o.Count -gt 0) {
        $c0 = $o[0].C
        $cs2 = @($cs | Where-Object { $_ -ne $c0 })
        if ($cs2.Count -lt $script:LevelAdaptMinFit) {
            $out.WhyCode = 'iso'
            $out.Why = (T 'écart isolé à c{0} et trop peu de cylindres restants') -f "$c0"
            $out.Named[$c0] = (T 'écart isolé'); $out.Iso[$c0] = $o[0].R
            return $out
        }
        $sel2 = Select-LevelModel $sh ([int[]]$cs2) $d $sg
        if ($sel2) { $o2 = & $outl $sel2.Best } else { $o2 = @(@{ C = -1 }) }
        if ($o2.Count -gt 0) {
            $oc = @($o2 | Where-Object { $_.C -ge 0 } | ForEach-Object { $_.C })
            $out.WhyCode = 'scatter'
            $out.Why = (T 'écarts dispersés ({0} cylindres hors de la forme ajustée : {1})') -f "$(1 + $o2.Count)", (Format-CylList ([int[]]@(@($c0) + @($oc))))
            $out.Named[$c0] = (T 'écart isolé')
            foreach ($x in $oc) { $out.Named[$x] = (T 'écart dispersé') }
            return $out
        }
        $out.Iso[$c0] = $o[0].R; $out.Named[$c0] = (T 'écart isolé'); $out.Excl += $c0
        $best = $sel2.Best; $sel = $sel2
        $cs = $cs2
    }
    $f = $best.Fit
    $out.Cand = @($sel.Cand | ForEach-Object { "$($_.Name):$($_.Press):$($_.Signif)" })
    if ($f.Tau -gt [double]$script:LevelTauMax) {
        $out.WhyCode = 'tau'
        $out.Why = (T 'écart de forme résiduel {0} ns (au plus {1})') -f (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'), (Format-UiNum ([math]::Round([double]$script:LevelTauMax, 1)) '0.#')
        return $out
    }
    $s = if ($f.Coef.ContainsKey('s')) { [double]$f.Coef['s'] } else { 0.0 }
    $b = if ($f.Coef.ContainsKey('b')) { [double]$f.Coef['b'] } else { 0.0 }
    if ([math]::Abs($s) -gt $script:LevelAdaptSMax -or [math]::Abs($b) -gt $script:LevelAdaptBMax) {
        $out.WhyCode = 'bounds'
        $out.Why = (T 'forme hors des bornes (échelle {0} %, pente {1} ns)') -f (Format-UiNum ([math]::Round(100 * $s, 1)) '+0.0;-0.0;0.0'), (Format-LevelSigned $b)
        return $out
    }
    # Effet de la forme par rapport au niveau seul, sur toute la face ; sous LevelAdaptEffMin : niveau seul
    $m0 = Get-LevelWls $sh ([string[]]@('a')) ([int[]]$cs) $d $sg
    $eff = 0.0
    for ($c = 0; $c -lt $sh.N; $c++) { $ef = [math]::Abs((Get-LevelPredict $sh $f $c)[0] - $m0.Coef['a']); if ($ef -gt $eff) { $eff = $ef } }
    $name = [string]$best.Name
    $loo = $best.Loo
    if ($name -ne 'M0' -and $eff -lt $script:LevelAdaptEffMin) { $name = 'M0'; $f = $m0; $loo = Get-LevelLoo $sh ([string[]]@('a')) ([int[]]$cs) $d $sg }
    $out.Ok = $true; $out.Model = $name; $out.Fit = $f; $out.Cs = [int[]]$cs; $out.Eff = $eff; $out.Loo = $loo; $out.M0 = $m0
    # Zone de reserve : ecart de forme residuel au-dela de LevelTauOk (LevelTauMax pour le niveau seul), ou residu au-dela
    # de LevelAdaptResOk : courbe adaptee, cylindre du plus grand residu nomme « suspect », alerte
    $tok = if ($name -ne 'M0') { [double]$script:LevelTauOk } else { [double]$script:LevelTauMax }
    $cw = $null; $rw = -1.0
    foreach ($c in @($f.Cs)) { $ar = [math]::Abs($f.Res[$c]); if ($ar -gt $rw) { $rw = $ar; $cw = [int]$c } }
    $rs = @()
    if ($f.Tau -gt $tok) { $rs += ((T 'écart de forme résiduel {0} ns (au-delà de {1})') -f (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'), (Format-UiNum ([math]::Round($tok, 1)) '0.#')) }
    if ($rw -gt $script:LevelAdaptResOk) { $rs += ((T 'c{0} à {1} ns de la forme ajustée') -f "$cw", (Format-LevelSigned $f.Res[$cw])) }
    if ($rs.Count -gt 0) {
        $out.Reserve = $rs; $out.Suspect = $cw
        $out.Named[$cw] = (T 'suspect ({0} ns de la forme ajustée) : défaut local possible') -f (Format-LevelSigned $f.Res[$cw])
    }
    return $out
}

function Get-LevelModelText([string]$model) {
    # 12.8 (F3R) : suffixe '+c' (terme de centre) : texte du modele de base, puis « , centre »
    if ($model -like '*+c') { return (Get-LevelModelText ($model -replace '\+c$', '')) + (T ', centre') }
    switch ($model) { 'Ms' { return (T 'niveau et échelle') } 'Mb' { return (T 'niveau et pente') } 'Msb' { return (T 'niveau, échelle et pente') } default { return (T 'niveau seul') } }
}

function Get-LevelShapeTerms($fit, [int]$last) {
    # « niveau +45 ns, échelle +19,0 %, pente +22 ns de c0 à c79 » ; 12.8 (F3R) : « , centre +24 ns à c79 »
    $co = $fit.Coef
    $terms = @((T 'niveau {0} ns') -f (Format-LevelSigned $co['a']))
    if ($co.ContainsKey('s')) { $terms += ((T 'échelle {0} %') -f (Format-UiNum ([math]::Round(100 * [double]$co['s'], 1)) '+0.0;-0.0;0.0')) }
    if ($co.ContainsKey('b')) { $terms += ((T 'pente {0} ns de c0 à c{1}') -f (Format-LevelSigned $co['b']), "$last") }
    if ($co.ContainsKey('hc')) { $terms += ((T 'centre {0} ns à c{1}') -f (Format-LevelSigned $co['hc']), "$last") }
    return ($terms -join ', ')
}

function Write-LevelAdaptFitLog($u, $an) {
    $pfx = $u.Prefix; $kref = [double]$u.KRef
    if ($an.KOrder.Count -gt 0 -and $an.D.Count -gt 0) {
        $kk = @($an.KOrder | ForEach-Object { $an.Ks[$_] }) | Measure-Object -Minimum -Maximum
        $dd = @($an.D.Values) | Measure-Object -Minimum -Maximum
        Append-Log ($pfx + ((T 'Zéros mesurés à deux précompensations : pente propre de {0} à {1} fois celle de la référence ; écarts à la référence de {2} à {3} ns.') -f (Format-UiNum ([math]::Round($kk.Minimum / $kref, 1)) '0.#'), (Format-UiNum ([math]::Round($kk.Maximum / $kref, 1)) '0.#'), (Format-LevelSigned $dd.Minimum), (Format-LevelSigned $dd.Maximum)))
    }
    foreach ($c in @($an.Iso.Keys | Sort-Object)) {
        Append-Log ($pfx + ((T "Écart isolé à c{0} ({1} ns par rapport à la forme ajustée sans lui) : défaut ponctuel probable de cette disquette, écarté de l'ajustement et non compensé.") -f "$c", (Format-LevelSigned $an.Iso[$c])))
    }
    if (-not $an.Ok) { return }
    $f = $an.Fit
    $worst = $null; $wq = -1.0
    foreach ($c in @($f.Cs)) { $lv = $an.Loo[$c]; $q = [math]::Abs($lv.R) / [math]::Max([double]$script:LevelAdaptLooFloor, [double]$script:LevelAdaptLooK * $lv.Sd); if ($q -gt $wq) { $wq = $q; $worst = [int]$c } }
    $thr = [math]::Min([math]::Max([double]$script:LevelAdaptLooFloor, [double]$script:LevelAdaptLooK * $an.Loo[$worst].Sd), [double]$script:LevelAdaptLooCap)
    if ($an.Model -eq 'M0') {
        Append-Log ($pfx + ((T 'Forme de la référence confirmée par les zéros mesurés (écart de forme {0} ns) : niveau seul, {1} ns.') -f (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'), (Format-LevelSigned $f.Coef['a'])))
    } else {
        Append-Log ($pfx + ((T 'Forme ajustée ({0}) : {1} ; écart de forme résiduel {2} ns ; validation croisée : écart maximal {3} ns à c{4} (tolérance {5}).') -f (Get-LevelModelText $an.Model), (Get-LevelShapeTerms $f ($u.ShapeV.N - 1)), (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'), (Format-LevelSigned $an.Loo[$worst].R), "$worst", (Format-UiNum ([math]::Round($thr, 1)) '0.#')))
    }
}

function Get-LevelAdaptHard($u, [string]$model, $raw, [double]$delta = 0.0, $clip = @()) {
    # 12.8 (F3R, decision 2 du 21/10/2026) : plafond de la courbe adaptee d une tete. CalHardNs (write.precompMaxNs) par
    # defaut ; porte a CalHardMaxNs (470 ns, borne haute de precompMaxNs) quand le besoin modelise de cette disquette (Raw
    # + delta, arrondi) depasse CalHardNs sur un cylindre de reference non nulle hors Clip, pour une forme adaptee (modele
    # autre que M0, M0+c compris) seulement. Une borne precompMaxNs deja egale a CalHardMaxNs reste telle quelle ; la
    # reference, le niveau seul (M0), la courbe de refus et toute calibration complete restent bornes a CalHardNs.
    # 12.8 (F3R-FIX, constat 4) : seuil de declenchement max(CalHardNsDefault, CalHardNs) : besoin au-dela de 400 ns, ou de
    # la borne reglee si elle est plus haute ; une borne abaissee sous 400 ns reste le plafond des disquettes dont le besoin
    # ne depasse pas 400 ns
    $base = [int]$script:CalHardNs; $ext = [int]$script:CalHardMaxNs
    if ($ext -le $base -or -not $model -or $model -eq 'M0') { return $base }
    $thr = [math]::Max([int]$script:CalHardNsDefault, $base)
    $V = $u.ShapeV.V; $need = $null
    for ($c = 0; $c -lt @($raw).Count; $c++) {
        if ([double]$V[$c] -le 0 -or @($clip) -contains $c) { continue }
        $x = [math]::Round([double]$raw[$c] + $delta)
        if ($null -eq $need -or $x -gt $need) { $need = $x }
    }
    if ($null -ne $need -and $need -gt $thr) { return $ext }
    return $base
}

function Build-LevelAdaptValues($u, $fit, [string]$model = '') {
    # Courbe adaptee : reference du lecteur + modele, bornee a 0..plafond ; valeur de reference a la borne de son calcul
    # (Get-CurveMaxNs) jamais abaissee, comme Build-LevelValues. Sat : besoin du modele au-dela du plafond ; Clip :
    # reference elle-meme au-dela de la borne actuelle (borne reglable, pas un besoin de cette disquette), ramenee a
    # CalHardNs. 12.8 (F3R, decision 2) : plafond de la tete (Get-LevelAdaptHard, Hard), CalHardNs sans modele ou pour M0.
    # 12.8 (F3R-FIX, constat 1) : Clip ne declenche jamais le plafond par disquette ; plafond porte au-dela de CalHardNs par
    # un autre cylindre : les cylindres Clip suivent ce plafond (Sat au-dela), au lieu de retomber a CalHardNs
    $sh = $u.ShapeV; $base = [int]$script:CalHardNs; $rmax = Get-CurveMaxNs $u.Cv
    $n = $sh.N
    $vals = New-Object int[] $n; $raw = New-Object double[] $n
    $sat = @(); $floor = @(); $clip = @()
    for ($c = 0; $c -lt $n; $c++) {
        $rv = [double]$sh.V[$c]
        $v = $rv + (Get-LevelPredict $sh $fit $c)[0]
        if ($rv -ge $rmax) { $v = [math]::Max($v, $rv) }
        $raw[$c] = $v
        if ($rv -gt $base) { $clip += $c }
    }
    $mx = Get-LevelAdaptHard $u $model $raw 0.0 $clip
    for ($c = 0; $c -lt $n; $c++) {
        $rv = [double]$sh.V[$c]; $v = $raw[$c]
        if ($mx -le $base -and $clip -contains $c) { $vals[$c] = [int][math]::Max(0, [math]::Min($base, [math]::Round($v))); continue }
        if ($v -gt $mx) { $sat += $c }
        elseif ($v -lt 0 -and $rv -gt 0) { $floor += $c }
        $vals[$c] = if ($rv -gt 0) { [int][math]::Max(0, [math]::Min($mx, [math]::Round($v))) } else { 0 }
    }
    return @{ Values = $vals; Raw = $raw; Sat = $sat; Floor = $floor; Clip = $clip; Hard = $mx }
}

function Set-LevelVerifTargets($cal, $u, $an) {
    # Passe de verification : courbe adaptee ecrite sur les cylindres d ajustement (controles integres d une reprise e3
    # compris) et les cylindres de controle
    $bv = Build-LevelAdaptValues $u $an.Fit ([string]$an.Model)
    $u.AV = $bv
    $t = @{}
    $fc = Get-LevelFitCyls $u
    foreach ($c in @(@($fc) + @($u.Ctl) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)) { $t[$c] = [int]$bv.Values[$c] }
    $u.LTarget = $t
    $u.Mode = 'verif'
    Add-LevelCalCyls $cal ([int[]]@($u.Ctl))
}

function Get-LevelSE($m) {
    # Erreur-type d une mesure, 2 ns si elle n est pas mesuree (comme Get-LevelZero)
    if ($null -eq $m -or $null -eq $m.SE -or [double]::IsNaN([double]$m.SE) -or [double]$m.SE -le 0) { return 2.0 }
    return [double]$m.SE
}

function Test-LevelAdaptVerify($u, [int]$p) {
    # Passe de verification : niveau (decalage residuel moyen des cylindres ajustes, tolerance de Get-LevelEstimate),
    # acceptation cylindre par cylindre (Get-ResidualTol, sinon ecart a la forme), controles d extrapolation. Ligne de
    # journal ; Why non vide : refus (ou, depuis F3R, correction du centre, courbe gardee avec reserve : Invoke-LevelStep).
    # 12.8 (F3R, v3f.py analyse_verif) :
    #  - Bk : decalage moyen dans la moyenne des Get-ResidualTol des cylindres ajustes : correction delta gardee, niveau dit
    #    verifie (Corr) ; premier palier juge contre le decalage moyen quand delta n est pas nul ;
    #  - e1 : controle ecrit deux fois (passe de mesure et verification) : pente de la corde, la verification ramenee a
    #    l epoque de la mesure par la derive de la tete (Drift = decalage moyen / pente commune) ;
    #  - plafond de la courbe ecrite (Hv, AV.Hard) : controle et controle integre ecrits a ce plafond, besoin au-dela :
    #    non verifiables (au plafond) ;
    #  - aucune mesure (NoMeas) : refus, ni centre ni reserve
    $pfx = $u.Prefix; $an = $u.AN; $sh = $u.ShapeV; $kp = [double]$an.KPool; $kref = [double]$u.KRef
    $hv = if ($u.AV -and $null -ne $u.AV.Hard) { [int]$u.AV.Hard } else { [int]$script:CalHardNs }
    $klo = [double]$script:LevelAdaptKRatioLo * $kref; $khi = [double]$script:LevelAdaptKRatioHi * $kref
    $cfit = @(@($u.CtlFit) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    $raw = @{}
    foreach ($c in @($u.LTarget.Keys | ForEach-Object { [int]$_ })) { $lst = $u.Raw[$c]; if ($lst -and @($lst).Count -gt 0 -and [int]$lst[-1][0] -eq $p) { $raw[$c] = $lst[-1] } }
    $fitc = @($an.Cs | Where-Object { $raw.ContainsKey([int]$_) -and -not ($cfit -contains [int]$_ -and [int]$raw[[int]$_][1] -ge $hv -and [double]$raw[[int]$_][2].Shift -gt 0) })
    $rs = @($fitc | ForEach-Object { [double]$raw[[int]$_][2].Shift })
    $vr = @{ Tier = @{}; Dev = @{}; Ctl = @{}; Conv = $false; RBar = [double]::NaN; RTol = [double]::NaN; Delta = 0.0; NewBad = @(); Confirmed = @(); NonRep = @(); BadCtl = @(); Why = ''
             NoMeas = $false; Corr = $false; GMean = [double]::NaN; Drift = 0.0; T1 = @(); T2 = @(); Hv = $hv; Pass = $p }
    if ($rs.Count -eq 0) { $vr.Why = (T 'aucune mesure à la vérification'); $vr.NoMeas = $true; return $vr }
    $sum = 0.0; foreach ($x in $rs) { $sum += $x }
    $rbar = $sum / $rs.Count
    $rtol = [double]$script:CalResidual * [math]::Min(1.0, $kp / 2.0)
    if ($rs.Count -ge 2) {
        $q = 0.0; foreach ($x in $rs) { $q += [math]::Pow($x - $rbar, 2) }
        $sd = [math]::Sqrt($q / ($rs.Count - 1))
        $rtol = [math]::Max($rtol, 2.0 * $sd / [math]::Sqrt($rs.Count))
    }
    $conv = ([math]::Abs($rbar) -le $rtol)
    $delta = if ($conv) { 0.0 } else { $rbar / $kp }
    # Bk : tolerance par cylindre de la verification (Get-ResidualTol), moyenne sur les cylindres ajustes
    $gs = 0.0; foreach ($c in $fitc) { $gs += [double](Get-ResidualTol $raw[[int]$c][2]) }
    $gmean = $gs / $fitc.Count
    $corr = $false
    if (-not $conv -and [math]::Abs($rbar) -le $gmean) { $conv = $true; $corr = $true }
    $vr.RBar = $rbar; $vr.RTol = $rtol; $vr.Conv = $conv; $vr.Delta = $delta; $vr.Corr = $corr; $vr.GMean = $gmean; $vr.Drift = $rbar / $kp
    foreach ($c in @($raw.Keys | Sort-Object)) {
        if (@($u.Ctl) -contains $c) { continue }
        $w = [int]$raw[$c][1]; $m = $raw[$c][2]
        $k = if ($an.Ks.ContainsKey($c)) { [double]$an.Ks[$c] } else { $kp }
        if (-not ($klo -le $k -and $k -le $khi)) { $k = $kp }
        $dev = [double]$m.Shift / $k - $delta
        $sgc = [math]::Max(1.0, (Get-LevelSE $m) / $k)
        $tol1 = Get-ResidualTol $m
        $tier = if ([math]::Abs([double]$m.Shift - $(if ($delta -ne 0) { $rbar } else { 0.0 })) -le $tol1) { 1 } elseif ([math]::Abs($dev) -gt [math]::Max([double]$script:CalDevNs, 4.0 * $sgc)) { 3 } else { 2 }
        # Controle integre (e3) ecrit au plafond, besoin au-dela : non verifiable (plafond)
        if ($tier -eq 3 -and $cfit -contains $c -and $w -ge $hv -and [double]$m.Shift -gt 0) { $tier = 2 }
        $vr.Tier[$c] = $tier; $vr.Dev[$c] = $dev
        if ($an.Named.ContainsKey($c)) { if ($tier -eq 3) { $vr.Confirmed += $c } else { $vr.NonRep += $c } }
        elseif ($tier -eq 3) { $vr.NewBad += $c }
    }
    foreach ($x in @($u.Ctl | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })) {
        if (-not $raw.ContainsKey($x)) { continue }
        $m = $raw[$x][2]
        # e1 : pente de la corde de ses deux ecritures (passe de mesure, verification ramenee a l epoque de la mesure)
        $kx = $kp
        $prev = @(@($u.Raw[$x]) | Where-Object { [int]$_[0] -lt $p })
        if ($prev.Count -gt 0) {
            $w0 = [double]$prev[-1][1]; $s0 = [double]$prev[-1][2].Shift
            $w1 = [double]$raw[$x][1] - [double]$vr.Drift
            if ([math]::Abs([int]$raw[$x][1] - [int]$prev[-1][1]) -ge $script:LevelAdaptDeltaMin -and [math]::Abs($w1 - $w0) -gt 1e-6) {
                $kc = ($s0 - [double]$m.Shift) / ($w1 - $w0)
                if ($klo -le $kc -and $kc -le $khi) { $kx = $kc }
            }
        }
        $dev = [double]$m.Shift / $kx - $delta
        $sp = (Get-LevelPredict $sh $an.Fit $x)[1]
        $tol = [math]::Min([double]$script:LevelAdaptCtlCap, [math]::Max([double]$script:LevelAdaptCtlFloor, [double]$script:LevelAdaptCtlK * [math]::Sqrt([math]::Pow($sp, 2) + [math]::Pow([double]$script:LevelShapeFloor, 2) + [math]::Pow((Get-LevelSE $m) / $kx, 2))))
        $capped = ([int]$u.LTarget[$x] -ge $hv -and [double]$m.Shift -gt 0)
        $vr.Ctl[$x] = @{ Dev = $dev; Tol = $tol; Ok = ([math]::Abs($dev) -le $tol -or $capped); Cap = $capped; K = $kx }
    }
    $vr.BadCtl = @($vr.Ctl.Keys | Sort-Object | Where-Object { -not $vr.Ctl[$_].Ok })
    $t1 = @($vr.Tier.Keys | Sort-Object | Where-Object { $vr.Tier[$_] -eq 1 -and -not $an.Named.ContainsKey($_) })
    $t2 = @($vr.Tier.Keys | Sort-Object | Where-Object { $vr.Tier[$_] -eq 2 -and -not $an.Named.ContainsKey($_) })
    $vr.T1 = $t1; $vr.T2 = $t2
    $ctlTxt = ''
    foreach ($x in @($vr.Ctl.Keys | Sort-Object)) { $ctlTxt += ' ; ' + ((T 'contrôle c{0} {1} ns (tolérance {2})') -f "$x", (Format-LevelSigned $vr.Ctl[$x].Dev), (Format-UiNum ([math]::Round($vr.Ctl[$x].Tol, 1)) '0.#')) }
    $none = '-'
    Append-Log ($pfx + ((T 'Vérification de la courbe adaptée à la passe {0} : décalage résiduel moyen {1} ns (tolérance {2}) ; cylindres vérifiés : {3} ; dans la forme : {4}{5}.') -f "$p", (Format-UiNum ([math]::Round($rbar, 1)) '0.#'), (Format-UiNum ([math]::Round($rtol, 1)) '0.#'), $(if ($t1.Count) { Format-CylList ([int[]]$t1) } else { $none }), $(if ($t2.Count) { Format-CylList ([int[]]$t2) } else { $none }), $ctlTxt))
    if ($vr.NewBad.Count -gt 0) {
        $vr.Why = (T 'vérification hors de la forme ajustée aux cylindres {0} ({1} ns)') -f (Format-CylList ([int[]]$vr.NewBad)), ((@($vr.NewBad | ForEach-Object { Format-LevelSigned $vr.Dev[$_] })) -join ', ')
    } elseif ($vr.BadCtl.Count -gt 0) {
        $vr.Why = ((@($vr.BadCtl | ForEach-Object { (T "contrôle d'extrapolation hors tolérance à c{0} ({1} ns, tolérance {2})") -f "$_", (Format-LevelSigned $vr.Ctl[$_].Dev), (Format-UiNum ([math]::Round($vr.Ctl[$_].Tol, 1)) '0.#') })) -join ', ')
    }
    return $vr
}

function Get-LevelPtsEpoch($u, [int]$c, $dmap) {
    # 12.8 (F3R, v3f.py _pts_epoch) : mesures d un cylindre, toutes passes : W (valeur ecrite ramenee a l epoque de la passe
    # de mesure par la derive de la passe, dmap), S (decalage), E (erreur-type), P (passe), WW (valeur ecrite)
    $out = @()
    if (-not $u.Raw.ContainsKey($c)) { return ,$out }
    foreach ($t in @($u.Raw[$c])) {
        if ($null -eq $t) { continue }
        $pp = [int]$t[0]; $dd = if ($dmap -and $dmap.ContainsKey($pp)) { [double]$dmap[$pp] } else { 0.0 }
        $out += ,@{ W = [double][int]$t[1] - $dd; S = [double]$t[2].Shift; E = (Get-LevelSE $t[2]); P = $pp; WW = [int]$t[1] }
    }
    return ,$out
}

function Get-LevelZeroPts($pts, [double]$kref, [double]$kp) {
    # 12.8 (F3R, v3f.py zero_pts) : zero d un cylindre sans borne a CalHardNs : corde des deux points qui encadrent le zero
    # si leurs valeurs ecrites sont a LevelAdaptDeltaMin au moins et la pente plausible ; sinon point le plus proche du zero,
    # pente de la corde la plus large (LevelAdaptDeltaMin, plausible) ou pente commune. Incertitude : erreurs-types, plus
    # 10 % (pente propre) ou 25 % (pente commune) du chemin
    if (-not $pts -or @($pts).Count -eq 0) { return $null }
    $xs = @(@($pts) | Sort-Object -Property @{ Expression = { $_.W } }, @{ Expression = { $_.S } }, @{ Expression = { $_.E } }, @{ Expression = { $_.P } }, @{ Expression = { $_.WW } })
    $lo = [double]$script:LevelAdaptKRatioLo * $kref; $hi = [double]$script:LevelAdaptKRatioHi * $kref
    for ($i = 0; $i -lt $xs.Count - 1; $i++) {
        $a1 = $xs[$i]; $a2 = $xs[$i + 1]
        if ($a1.S -gt 0 -and 0 -ge $a2.S -and [math]::Abs($a2.WW - $a1.WW) -ge $script:LevelAdaptDeltaMin -and $a2.W - $a1.W -gt 1e-6) {
            $a = ($a1.S - $a2.S) / ($a2.W - $a1.W)
            if ($lo -le $a -and $a -le $hi) { return @{ Est = $a1.W + $a1.S / $a; Sig = [math]::Max(1.0, [math]::Sqrt([math]::Pow($a1.E, 2) + [math]::Pow($a2.E, 2)) / $a); K = $a; Own = $true } }
        }
    }
    $best = $xs[0]; foreach ($t in $xs) { if ([math]::Abs($t.S) -lt [math]::Abs($best.S)) { $best = $t } }
    $far = $xs[0]; foreach ($t in $xs) { if ([math]::Abs($t.WW - $best.WW) -gt [math]::Abs($far.WW - $best.WW)) { $far = $t } }
    $k = $null
    if ([math]::Abs($far.WW - $best.WW) -ge $script:LevelAdaptDeltaMin -and [math]::Abs($far.W - $best.W) -gt 1e-6) {
        $a = ($far.S - $best.S) / ($best.W - $far.W)
        if ($lo -le $a -and $a -le $hi) { $k = $a }
    }
    $kk = if ($null -ne $k) { [double]$k } else { $kp }
    $z = $best.W + $best.S / $kk
    $sig = [math]::Sqrt([math]::Pow($best.E / $kk, 2) + [math]::Pow($(if ($null -ne $k) { 0.10 } else { 0.25 }) * [math]::Abs($best.S / $kk), 2))
    return @{ Est = $z; Sig = [math]::Max(1.0, $sig); K = $kk; Own = ($null -ne $k) }
}

function Get-LevelFreshCtl($u, $taken, [int]$maxCyl = -1) {
    # 12.8 (F3R, v3f.py fresh_ctl) : controle neuf apres une reprise avec un terme de centre : cylindre jamais ecrit de
    # LevelAdaptCtlLo au dernier, hors cylindres pris et leurs voisins, point de reference interpole et fiable, valeur de
    # 5 a CalHardNs - 15 ns ; le plus proche du centre. $null s il n y en a aucun. 12.8 (F3R-FIX, constat 2) : dernier :
    # fin de la reference, au plus le dernier cylindre de l image ($maxCyl, MaxCyl de la calibration), comme
    # Get-LevelCtlCyls
    $cv = $u.Cv; $last = @($u.V).Count - 1
    if ($maxCyl -ge 0) { $last = [math]::Min($last, $maxCyl) }
    $cyls = @(@($cv.Cyls) | ForEach-Object { [int]$_ })
    $tk = @{}; foreach ($t in @($taken)) { if ($null -ne $t) { $tk[[int]$t] = $true } }
    $best = $null
    for ($c = [int]$script:LevelAdaptCtlLo; $c -le $last; $c++) {
        if ($tk.ContainsKey($c) -or $tk.ContainsKey($c - 1) -or $tk.ContainsKey($c + 1) -or [int]$u.Writes[$c] -gt 0) { continue }
        $i = -1; for ($q = 0; $q -lt $cyls.Count; $q++) { if ($cyls[$q] -eq $c) { $i = $q; break } }
        if ($i -lt 0) { continue }
        if ($cv.Kinds -and $i -lt @($cv.Kinds).Count -and [string]$cv.Kinds[$i] -ne 'interp') { continue }
        if (Test-CurvePointFlag $cv $i) { continue }
        if ([double]$u.V[$c] -le 5 -or [double]$u.V[$c] -ge [double]$script:CalHardNs - 15) { continue }
        $best = $c
    }
    return $best
}

function Get-LevelCenterCtl($u) {
    # Controles de la tete ayant des mesures : integres (CtlFit), puis hors ajustement (Ctl)
    return ,@(@(@($u.CtlFit) + @($u.Ctl)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Where-Object { $u.Raw.ContainsKey($_) -and @($u.Raw[$_]).Count -gt 0 })
}

function Test-LevelCenterFit($u, $an, $names, [int[]]$cs2, $d, $sg, [int]$xs, [double]$s, [int[]]$reinc, [switch]$Bounds) {
    # Ajustement de la forme avec le terme de centre et ses refus (v3f.py center_eval / center_rescue) : significativite et
    # sens du terme, lissage, ecart de forme residuel, bornes, regularite (controle le plus ecarte et reintegres predits
    # sans eux). Renvoie @{ Fit ; Bh ; Se ; Why } (Why vide : retenu) ou $null (ajustement impossible)
    $sh = $u.ShapeV; $t0 = [double]$script:LevelShapeFloor
    $f = Get-LevelWls $sh ([string[]]$names) $cs2 $d $sg
    if (-not $f) { return $null }
    $ih = [array]::IndexOf([string[]]$names, 'hc')
    $bh = [double]$f.Beta[$ih]
    $seh = [math]::Sqrt([math]::Max(1e-12, [double]$f.Cov[$ih][$ih]))
    $o = @{ Fit = $f; Bh = $bh; Se = $seh; Why = '' }
    if ($bh * $s -le 0 -or [math]::Abs($bh) -lt [double]$script:LevelAdaptCoefZ * $seh) { $o.Why = (T 'terme de centre non significatif ({0} ± {1} ns)') -f (Format-LevelSigned $bh), (Format-UiNum ([math]::Round($seh, 1)) '0.#'); return $o }
    $cw = $null
    foreach ($c in $cs2) { $ar = [math]::Abs([double]$f.Res[$c]); if ($ar -gt [math]::Max([double]$script:LevelCenterResOk, 3.0 * [double]$sg[$c]) -and ($null -eq $cw -or $ar -gt [math]::Abs([double]$f.Res[$cw]))) { $cw = $c } }
    if ($null -ne $cw) { $o.Why = (T 'forme avec terme de centre peu lisse (c{0} à {1} ns)') -f "$cw", (Format-LevelSigned $f.Res[$cw]); return $o }
    if ([double]$f.Tau -gt [double]$script:LevelTauMax) { $o.Why = (T 'écart de forme résiduel {0} ns avec le terme de centre') -f (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'); return $o }
    $cs = if ($f.Coef.ContainsKey('s')) { [double]$f.Coef['s'] } else { 0.0 }
    $cb = if ($f.Coef.ContainsKey('b')) { [double]$f.Coef['b'] } else { 0.0 }
    if ([math]::Abs($cs) -gt $script:LevelAdaptSMax -or [math]::Abs($cb) -gt $script:LevelAdaptBMax) {
        $o.Why = if ($Bounds) { (T 'forme avec terme de centre hors des bornes (échelle {0} %, pente {1} ns)') -f (Format-UiNum ([math]::Round(100 * $cs, 1)) '+0.0;-0.0;0.0'), (Format-LevelSigned $cb) } else { (T 'forme avec terme de centre hors des bornes') }
        return $o
    }
    foreach ($c in @(@($xs) + @($reinc))) {
        $rest = [int[]]@($cs2 | Where-Object { $_ -ne $c })
        $g = Get-LevelWls $sh ([string[]]$names) $rest $d $sg
        if (-not $g) { $o.Why = (T 'régularité non vérifiable à c{0}') -f "$c"; return $o }
        $pr = Get-LevelPredict $sh $g $c
        $rl = [double]$d[$c] - $pr[0]
        $thr = [math]::Min([math]::Max([double]$script:LevelAdaptLooFloor, [double]$script:LevelAdaptLooK * [math]::Sqrt([math]::Pow([double]$sg[$c], 2) + [math]::Pow($t0, 2) + [math]::Pow($pr[1], 2))), [double]$script:LevelCenterLooCap)
        if ([math]::Abs($rl) -gt $thr) { $o.Why = (T 'écart à c{0} non prédit par les autres cylindres du centre ({1} ns, tolérance {2})') -f "$c", (Format-LevelSigned $rl), (Format-UiNum ([math]::Round($thr, 1)) '0.#'); return $o }
    }
    return $o
}

function Get-LevelCenterEval($u, $an, [int]$stage, $vr) {
    # 12.8 (F3R, v3f.py center_eval, stage 3) : correction du centre par les controles a la passe de verification.
    # Declenchement : controle hors tolerance (vr.BadCtl) sans nouveau cylindre hors de la forme ; appui : un autre
    # cylindre du centre (controle, cylindre ajuste ou ecart isole, c >= LevelCenterC0) ecarte dans le meme sens, aucun en
    # sens contraire ; ajustement de la forme retenue + terme de centre hc sur les cylindres ajustes, les controles et
    # l ecart isole du centre de meme sens (reintegre) ; zeros de toutes les passes, la verification ramenee a l epoque de
    # la mesure par la derive de la tete. Renvoie $null (rien a faire) ou @{ Ok ; Why ; Stage ; AN ; Drift }
    $sh = $u.ShapeV; $kref = [double]$u.KRef; $kp = [double]$an.KPool; $f0 = $an.Fit
    $c0 = [int]$script:LevelCenterC0; $t0 = [double]$script:LevelShapeFloor
    $dd = if ($stage -ge 3 -and $vr -and $null -ne $vr.Drift) { [double]$vr.Drift } else { 0.0 }
    $dmap = @{ 3 = $dd; 4 = $dd }
    $ctl = Get-LevelCenterCtl $u
    if ($ctl.Count -eq 0) { return $null }
    $iso = if ($an.Iso) { $an.Iso } else { @{} }
    $named = if ($u.Named) { $u.Named } else { @{} }
    $d = @{}; $sg = @{}; $ks = @{}
    foreach ($k in @($an.Ks.Keys)) { $ks[[int]$k] = [double]$an.Ks[$k] }
    $fcs = Get-LevelFitCyls $u
    foreach ($c in @(@(@($fcs) + @($ctl)) | Sort-Object -Unique)) {
        $z = Get-LevelZeroPts (Get-LevelPtsEpoch $u ([int]$c) $dmap) $kref $kp
        if ($null -eq $z) { continue }
        $d[[int]$c] = [double]$z.Est - [double]$sh.V[[int]$c]; $sg[[int]$c] = [double]$z.Sig
        if ($z.Own) { $ks[[int]$c] = [double]$z.K }
    }
    # Ecarts de la verification (besoin - courbe adaptee, epoque de la verification) : controles par la corde (e1), puis
    # cylindres ecrits, dans l ordre de v3f.py
    $r = @{}; $sd = @{}; $ro = @()
    foreach ($x in @($vr.Ctl.Keys | ForEach-Object { [int]$_ } | Sort-Object)) { $r[$x] = [double]$vr.Ctl[$x].Dev; $sd[$x] = [double]$vr.Ctl[$x].Tol / [double]$script:LevelAdaptCtlK; $ro += $x }
    foreach ($c in @($vr.Dev.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        $m = $u.Raw[$c][-1][2]
        $k = if ($an.Ks.ContainsKey($c)) { [double]$an.Ks[$c] } else { $kp }
        $r[$c] = [double]$vr.Dev[$c]; $sd[$c] = [math]::Max(1.0, (Get-LevelSE $m) / $k); $ro += $c
    }
    $over = @($vr.BadCtl | ForEach-Object { [int]$_ })
    if ($over.Count -eq 0) { return $null }
    $xs = $over[0]; foreach ($x in $over) { if ([math]::Abs($r[$x]) / [double]$vr.Ctl[$x].Tol -gt [math]::Abs($r[$xs]) / [double]$vr.Ctl[$xs].Tol) { $xs = $x } }
    $s = if ($r[$xs] -gt 0) { 1.0 } else { -1.0 }
    $out = @{ Ok = $false; Why = ''; Stage = $stage; Xs = $xs; Drift = $dd; AN = $null }
    $zone = @($ro | Where-Object { $_ -ge $c0 -and $_ -ne $xs -and ($ctl -contains $_ -or @($an.Cs) -contains $_ -or $iso.ContainsKey($_)) })
    $sup = @($zone | Where-Object { $s * $r[$_] -ge [math]::Max([double]$script:LevelCenterMinOther, $(if ($ctl -contains $_) { $sd[$_] } else { 0.0 })) })
    $opp = @($zone | Where-Object { $s * $r[$_] -le -[math]::Max([double]$script:LevelCenterOpp, 2.0 * $sd[$_]) })
    if ($sup.Count -eq 0) { $out.Why = (T "écart du contrôle c{0} ({1} ns) sans appui d'un autre cylindre du centre") -f "$xs", (Format-LevelSigned $r[$xs]); return $out }
    if ($opp.Count -gt 0) { $out.Why = (T 'écarts de sens contraires au centre (c{0} {1} ns, c{2} {3} ns)') -f "$xs", (Format-LevelSigned $r[$xs]), "$($opp[0])", (Format-LevelSigned $r[$opp[0]]); return $out }
    $reinc = [int[]]@(@($iso.Keys | ForEach-Object { [int]$_ } | Sort-Object) | Where-Object { $d.ContainsKey($_) -and $r.ContainsKey($_) -and $s * $r[$_] -gt 0 -and $_ -ge $c0 })
    $cs2 = [int[]]@($d.Keys | ForEach-Object { [int]$_ } | Sort-Object | Where-Object { -not ($named.ContainsKey($_) -and $reinc -notcontains $_) -and (@($an.Cs) -contains $_ -or $ctl -contains $_ -or $reinc -contains $_) })
    $names = [string[]]@($f0.Names)
    if ($names -notcontains 'hc') { $names = [string[]]@(@($names) + @('hc')) }
    $tf = Test-LevelCenterFit $u $an $names $cs2 $d $sg $xs $s $reinc
    if ($null -eq $tf) { $out.Why = (T 'terme de centre impossible à ajuster'); return $out }
    if ($tf.Why) { $out.Why = $tf.Why; return $out }
    $f = $tf.Fit
    $an2 = $an.Clone()
    $m0 = Get-LevelWls $sh ([string[]]@('a')) $cs2 $d $sg
    $eff = 0.0
    for ($c = 0; $c -lt $sh.N; $c++) { $ef = [math]::Abs((Get-LevelPredict $sh $f $c)[0] - [double]$m0.Coef['a']); if ($ef -gt $eff) { $eff = $ef } }
    $loo = Get-LevelLoo $sh $names $cs2 $d $sg
    $an2.Fit = $f; $an2.Cs = $cs2; $an2.Model = $(if ([string]$an.Model -like '*+c') { [string]$an.Model } else { [string]$an.Model + '+c' })
    $an2.D = $d; $an2.Sig = $sg; $an2.Ks = $ks; $an2.Eff = $eff; $an2.Loo = $(if ($loo) { $loo } else { $an.Loo }); $an2.Reserve = @($an.Reserve)
    $rc = @{}; foreach ($x in $ctl) { if ($r.ContainsKey($x)) { $rc[$x] = $r[$x] } }
    $an2.Center = @{ Stage = $stage; Xs = $xs; R = $rc; Reinc = $reinc; Hc = $tf.Bh; Se = $tf.Se; Verified = $null; Drift = $dd; Sup = $sup; Rescue = '' }
    $nm = @{}; foreach ($k in @($an.Named.Keys)) { if ($reinc -notcontains [int]$k) { $nm[[int]$k] = $an.Named[$k] } }
    $an2.Named = $nm
    $out.Ok = $true; $out.AN = $an2
    return $out
}

function Get-LevelCenterRescue($u, $an, $cal) {
    # 12.8 (F3R, e3, v3f.py center_rescue) : adaptation refusee a la passe de mesure (ecarts disperses, ecart isole avec trop
    # peu de cylindres, ecart de forme residuel, forme hors des bornes) alors que les controles (un point, passe de mesure)
    # s ecartent dans le meme sens que les cylindres du centre ecartes : forme niveau, echelle, pente et centre ajustee sur
    # les cylindres non signales, les controles et les cylindres du centre de meme sens ; memes tests que la correction du
    # centre ; les cylindres signales sous LevelCenterC0, les pistes de la surface et les pentes invraisemblables restent
    # ecartes. Verification a la passe 3. Renvoie $null (rien a faire) ou @{ Ok ; Why ; Stage ; AN }
    if (@('scatter', 'iso', 'tau', 'bounds') -notcontains [string]$an.WhyCode -or -not $an.D -or $an.D.Count -eq 0) { return $null }
    $sh = $u.ShapeV; $kref = [double]$u.KRef; $kp = [double]$an.KPool
    $c0 = [int]$script:LevelCenterC0; $t0 = [double]$script:LevelShapeFloor
    $ctl = @(@($u.Ctl) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Where-Object { $u.Raw.ContainsKey($_) -and @($u.Raw[$_]).Count -gt 0 })
    if ($ctl.Count -lt 2) { return $null }
    $d = @{}; foreach ($k in @($an.D.Keys)) { $d[[int]$k] = [double]$an.D[$k] }
    $sg = @{}; foreach ($k in @($an.Sig.Keys)) { $sg[[int]$k] = [double]$an.Sig[$k] }
    foreach ($x in $ctl) {
        $z = Get-LevelZeroPts (Get-LevelPtsEpoch $u $x @{}) $kref $kp
        if ($null -eq $z) { return $null }
        $d[$x] = [double]$z.Est - [double]$sh.V[$x]; $sg[$x] = [double]$z.Sig
    }
    $named = @{}
    foreach ($k in @($u.Named.Keys)) { $named[[int]$k] = $u.Named[$k] }
    foreach ($k in @($an.Named.Keys)) { $named[[int]$k] = $an.Named[$k] }
    # Ecartes pour de bon : pistes signalees par le controle de surface de cette face, pentes propres invraisemblables
    $hard = @{}
    foreach ($c in @($an.BadK)) { if ($null -ne $c) { $hard[[int]$c] = $true } }
    if ($cal -and $cal.Surf -and $cal.Surf.Faces -and $null -ne $u.Head -and $cal.Surf.Faces[[int]$u.Head]) { foreach ($b in @($cal.Surf.Faces[[int]$u.Head].Bad)) { if ($b) { $hard[[int]$b.C] = $true } } }
    $inner = @(@($named.Keys | ForEach-Object { [int]$_ } | Sort-Object) | Where-Object { $_ -ge $c0 -and -not $hard.ContainsKey($_) -and $d.ContainsKey($_) })
    $cs0 = [int[]]@((Get-LevelFitCyls $u) | Where-Object { $d.ContainsKey($_) -and -not $named.ContainsKey($_) -and $ctl -notcontains $_ })
    $out = @{ Ok = $false; Why = ''; Stage = 2; AN = $null }
    if ($cs0.Count -lt $script:LevelAdaptMinFit) { $out.Why = (T 'trop peu de cylindres non signalés ({0})') -f "$($cs0.Count)"; return $out }
    $f0 = Get-LevelWls $sh ([string[]]@('a', 's', 'b')) $cs0 $d $sg
    if (-not $f0) { return $null }
    $r = @{}; $sd = @{}; $ro = @()
    foreach ($c in @(@($ctl) + @($inner) + @($cs0 | Where-Object { $_ -ge $c0 }))) {
        $pr = Get-LevelPredict $sh $f0 $c
        $r[$c] = [double]$d[$c] - $pr[0]; $sd[$c] = [math]::Sqrt([math]::Pow([double]$sg[$c], 2) + [math]::Pow($t0, 2) + [math]::Pow($pr[1], 2)); $ro += $c
    }
    $tol = @{}; foreach ($x in $ctl) { $tol[$x] = [math]::Min([double]$script:LevelAdaptCtlCap, [math]::Max([double]$script:LevelAdaptCtlFloor, [double]$script:LevelAdaptCtlK * $sd[$x])) }
    $over = @($ctl | Where-Object { [math]::Abs($r[$_]) -gt $tol[$_] })
    if ($over.Count -eq 0) { $out.Why = (T 'contrôles dans la tolérance de la forme sans centre'); return $out }
    $xs = $over[0]; foreach ($x in $over) { if ([math]::Abs($r[$x]) / $tol[$x] -gt [math]::Abs($r[$xs]) / $tol[$xs]) { $xs = $x } }
    $s = if ($r[$xs] -gt 0) { 1.0 } else { -1.0 }
    $zone = @($ro | Where-Object { $_ -ne $xs })
    $sup = @($zone | Where-Object { $s * $r[$_] -ge [math]::Max([double]$script:LevelCenterMinOther, $(if ($ctl -contains $_) { $sd[$_] } else { 0.0 })) })
    $opp = @($zone | Where-Object { $s * $r[$_] -le -[math]::Max([double]$script:LevelCenterOpp, 2.0 * $sd[$_]) })
    if ($sup.Count -eq 0 -or $opp.Count -gt 0) { $out.Why = (T 'écart du centre irrégulier (c{0} {1} ns)') -f "$xs", (Format-LevelSigned $r[$xs]); return $out }
    $reinc = [int[]]@($inner | Where-Object { $s * $r[$_] -gt 0 })
    $cs2 = [int[]]@(@(@($cs0) + @($ctl) + @($reinc)) | Sort-Object -Unique)
    $names = [string[]]@('a', 's', 'b', 'hc')
    $tf = Test-LevelCenterFit $u $an $names $cs2 $d $sg $xs $s $reinc -Bounds
    if ($null -eq $tf) { return $null }
    if ($tf.Why) { $out.Why = $tf.Why; return $out }
    $f = $tf.Fit
    $m0 = Get-LevelWls $sh ([string[]]@('a')) $cs2 $d $sg
    $eff = 0.0
    for ($c = 0; $c -lt $sh.N; $c++) { $ef = [math]::Abs((Get-LevelPredict $sh $f $c)[0] - [double]$m0.Coef['a']); if ($ef -gt $eff) { $eff = $ef } }
    $loo = Get-LevelLoo $sh $names $cs2 $d $sg
    $an2 = $an.Clone()
    $an2.Ok = $true; $an2.Why = ''; $an2.WhyCode = ''; $an2.Fit = $f; $an2.Cs = $cs2; $an2.Model = 'Msb+c'; $an2.D = $d; $an2.Sig = $sg; $an2.Eff = $eff; $an2.M0 = $m0
    $an2.Loo = $(if ($loo) { $loo } else { @{} }); $an2.Reserve = @()
    $nm = @{}; foreach ($k in @($named.Keys)) { if ($reinc -notcontains [int]$k) { $nm[[int]$k] = $named[$k] } }
    $an2.Named = $nm
    $rc = @{}; foreach ($x in $ctl) { $rc[$x] = $r[$x] }
    $an2.Center = @{ Stage = 2; Xs = $xs; R = $rc; Reinc = $reinc; Hc = $tf.Bh; Se = $tf.Se; Verified = $null; Drift = 0.0; Sup = $sup; Rescue = [string]$an.Why }
    $out.Ok = $true; $out.AN = $an2
    return $out
}

function Write-LevelCenterLog($u, $ce) {
    # 12.8 (F3R) : correction du centre retenue (terme de centre, controles, appui, cylindres reintegres) ou non retenue
    if (-not $ce) { return }
    $pfx = $u.Prefix
    if (-not $ce.Ok) { Append-Log ($pfx + ((T 'Correction du centre non retenue : {0}.') -f "$($ce.Why)")); return }
    $cn = $ce.AN.Center
    $ctxt = (@(@($cn.R.Keys | ForEach-Object { [int]$_ } | Sort-Object) | ForEach-Object { "c$_ $(Format-LevelSigned $cn.R[$_]) ns" })) -join ', '
    $stxt = (@(@($cn.Sup) | ForEach-Object { "c$_" })) -join ', '
    $rtxt = if (@($cn.Reinc).Count -gt 0) { (T ' ; c{0} réintégré (écart de même sens, pas un défaut ponctuel)') -f ((@($cn.Reinc) | ForEach-Object { "$_" }) -join ',') } else { '' }
    $fmt = if ([double]$cn.Hc -gt 0) { (T 'Besoin plus fort vers le centre : contrôles {0}, appui {1}{2} ; terme de centre {3} ns à c{4} (± {5}), ajusté sur {6}.') } else { (T 'Besoin plus faible vers le centre : contrôles {0}, appui {1}{2} ; terme de centre {3} ns à c{4} (± {5}), ajusté sur {6}.') }
    Append-Log ($pfx + ($fmt -f "$ctxt", "$stxt", "$rtxt", (Format-LevelSigned $cn.Hc), "$($u.ShapeV.N - 1)", (Format-UiNum ([math]::Round([double]$cn.Se, 1)) '0.#'), (Format-CylList ([int[]]@($ce.AN.Cs)))))
}

function Set-LevelLevelOnly($u, $an) {
    # Refus d adaptation : niveau seul sur les zeros mesures (courbe de la reference decalee), non verifie
    $d = if ($an -and $an.D) { $an.D } else { @{} }
    $named = if ($an -and $an.Named) { $an.Named } else { @{} }
    $cs = @((Get-LevelFitCyls $u) | Where-Object { $d.ContainsKey($_) -and -not $named.ContainsKey($_) })
    if ($cs.Count -gt 0) {
        $m0 = Get-LevelWls $u.ShapeV ([string[]]@('a')) ([int[]]$cs) $d $an.Sig
        $u.Level = [int][math]::Round([double]$m0.Coef['a'])
    } elseif ($u.Est -and -not [double]::IsNaN([double]$u.Est.Delta)) { $u.Level = [int][math]::Round([double]$u.Est.Delta) }
    $u.Conv = $false
}

function Set-LevelNwcTargets($u) {
    # Pente apparente nulle sur une base etroite : confirmation sur LevelNwcDelta ns (zero de la passe 1 a la pente de
    # reference s il est assez loin, sinon premiere valeur ecrite +/- LevelNwcDelta, du cote du zero)
    $t = @{}; $mx = [int]$script:CalHardNs; $nd = [int]$script:LevelNwcDelta
    foreach ($c in (Get-LevelFitCyls $u)) {
        $pts = $u.Results[$c]
        if (-not $pts -or $pts.Count -eq 0 -or -not $u.Raw[$c]) { continue }
        $w1 = [int]$u.Raw[$c][0][1]
        $x = Get-LevelNearest $pts
        $z = Get-LevelZero @{ $x = $pts[$x] } ([double]$u.KRef)
        $z1 = if ($z) { [double]$z.Est } else { [double]$w1 }
        $sg = [math]::Sign($z1 - $w1); if ($sg -eq 0) { $sg = $(if ([double]$pts[$x].Shift -ge 0) { 1 } else { -1 }) }
        $w = if ([math]::Abs($z1 - $w1) -ge $nd) { [int][math]::Round($z1) } else { $w1 + $sg * $nd }
        if ($w -gt $mx -or $w -lt 0) { $w = $w1 - $sg * $nd }
        $t[$c] = [int][math]::Max(0, [math]::Min($mx, $w))
    }
    $u.LTarget = $t
    $u.Mode = 'nwc'
}

function Get-LevelAdaptOutcome($cal, $u) {
    # Bilan d une tete adaptee (Mode 'adapte' : forme ajustee et verifiee, ou niveau seul confirme a deux
    # precompensations) ou refusee (Mode 'refus' : courbe de la reference decalee), pour Complete-LevelCalib : courbe,
    # verdict, forme, reserves (Info : reserve « information » de la fenetre de decision), lignes du journal.
    # 12.8 (F3R, v3f.py complete) : tete adaptee :
    #  - e4 : correction de derive appliquee AVANT le plafond (cylindre plafonne a la verification : besoin + delta) ;
    #  - plafond par disquette (decision 2) : courbe adaptee jusqu a CalHardMaxNs quand son besoin depasse CalHardNs
    #    (Get-LevelAdaptHard) : reserve d information « au-dela de la borne », controle apres ecriture (G1, modele) ;
    #  - Bk : niveau corrige de la derive et dit verifie (J2) ;
    #  - reserve de centre (terme de centre non verifie par une ecriture du motif) et de controle (e2) : J3, R1 ;
    #  - reserves dans l ordre de v3f.py (niveau, centre ou controle, au-dela de la borne, forme, a surveiller, plafond)
    $pfx = $u.Prefix; $e = $u.Est; $an = $u.AN; $mx = [int]$script:CalHardNs
    $iss = New-Object System.Collections.Generic.List[object]
    $r = @{ Values = $null; Sat = @(); Floor = @(); Clip = @(); Verdict = ''; Shape = $null; Issues = $iss; Model = 'M0'; S = 0.0; B = 0.0; Hc = $null; K = $null; Hard = $mx; Over = @(); Corr = $false }
    if ([string]$u.Mode -eq 'refus') {
        $bv = Build-LevelValues $u ([int]$u.Level) $e
        $r.Values = $bv.Values; $r.Sat = @($bv.Sat); $r.Floor = @($bv.Floor); $r.Clip = @($bv.Clip)
        $sh = if ($e) { Test-LevelShape $e $u 1.0 } else { @{ Reasons = @() } }
        $r.Shape = @{ Verdict = 'mismatch'; Reasons = @($sh.Reasons); Tilt = $sh.Tilt; Step = $sh.Step }
        $r.Verdict = 'mismatch'
        Append-Log ($pfx + ((T 'Forme non conforme à la référence et non adaptée : {0}.') -f "$($u.Refus)"))
        $iss.Add(@{ Text = $pfx + ((T 'adaptation refusée : {0}') -f "$($u.Refus)"); Info = $false })
        if (-not $u.Conv) { $iss.Add(@{ Text = $pfx + ((T "niveau non vérifié par une écriture du motif ({0} passe(s))") -f "$($u.Passes)"); Info = $false }) }
        if ($r.Sat.Count -gt 0 -and $u.Memo -and $mx -ge [int]$script:CalHardMaxNs) {
            # 12.8 (F3R-FIX, constat 9) : borne precompMaxNs deja a CalHardMaxNs : plus de conseil de la relever
            Append-Log ($pfx + ((T 'Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés.') -f "$mx", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T 'plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés') -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        } elseif ($r.Sat.Count -gt 0 -and $u.Memo) {
            # 12.8 (FIX1C, constat 5) : courbe de refus partie de la forme d une marque (V' + niveau) : libelle neutre
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs).") -f "$mx", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs)") -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        } elseif ($r.Sat.Count -gt 0) {
            # 12.8 (F3R, decision du 21/10/2026) : forme non conforme : libelle neutre, autre type de disquette ou usure
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence), de forme différente : autre type de disquette ou usure, non distingués ; ces cylindres resteront sous-compensés.") -f "$mx", (Format-CylList ([int[]]$r.Sat)), ('{0:+0;-0;0}' -f [int]$u.Level)))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} (autre type de disquette ou usure ?)") -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        }
        if ($r.Floor.Count -gt 0) { $iss.Add(@{ Text = $pfx + ((T "précompensation nulle encore excessive aux cylindres {0}") -f (Format-CylList ([int[]]$r.Floor))); Info = $false }) }
        if ($an -and $an.KPool) { $r.K = [double]$an.KPool }
    } else {
        $bv = $u.AV; $vr = $u.VR; $sh = $u.ShapeV
        $vals = [int[]]@($bv.Values)
        $clip = @($bv.Clip)
        $hv = if ($null -ne $bv.Hard) { [int]$bv.Hard } else { $mx }
        $dl = [double]$vr.Delta
        $hh = Get-LevelAdaptHard $u ([string]$an.Model) $bv.Raw $dl $clip
        # 12.8 (F3R-FIX, constat 1) : plafond de la disquette porte au-dela de CalHardNs : les cylindres Clip le suivent
        # (e4 et Sat compris) ; sinon, comportement d avant (ramenes a CalHardNs, hors Sat)
        $cf = ($hh -gt $mx)
        if ($dl -ne 0 -or $hh -ne $hv) {
            $dd = [int][math]::Round($dl)
            for ($c = 0; $c -lt $vals.Count; $c++) {
                if ([double]$sh.V[$c] -le 0) { $vals[$c] = 0 }
                elseif (-not $cf -and $clip -contains $c) { $vals[$c] = [int][math]::Max(0, [math]::Min($mx, $vals[$c] + $dd)) }
                elseif ([double]$bv.Raw[$c] -gt $hv) { $vals[$c] = [int][math]::Max(0, [math]::Min($hh, [math]::Round([double]$bv.Raw[$c] + $dl))) }
                else { $vals[$c] = [int][math]::Max(0, [math]::Min($hh, $vals[$c] + $dd)) }
            }
        }
        $r.Values = $vals
        # Affectation par branche : « $x = if (...) { @() } » donnerait $null, et @($null).Count vaut 1
        if ($cf) { $r.Clip = @() } else { $r.Clip = $clip }
        $r.Sat = @(0..($vals.Count - 1) | Where-Object { ($cf -or $clip -notcontains $_) -and [double]$bv.Raw[$_] + $dl -gt $hh })
        $r.Floor = @($bv.Floor)
        $r.K = [double]$an.KPool
        $r.Hard = $hh
        $r.Over = @(if ($hh -gt $mx) { 0..($vals.Count - 1) | Where-Object { $vals[$_] -gt $mx } })
        $r.Corr = [bool]$vr.Corr
        $j2 = (T 'Niveau de la courbe adaptée corrigé de {0} ns (dérive entre deux passes ; décalage résiduel moyen {1} ns, dans la tolérance par cylindre {2}).') -f (Format-LevelSigned $dl), (Format-UiNum ([math]::Round([double]$vr.RBar, 1)) '0.#'), (Format-UiNum ([math]::Round([double]$vr.GMean, 1)) '0.#')
        if (-not $u.Conv) {
            $iss.Add(@{ Text = $pfx + ((T 'niveau de la courbe adaptée non vérifié (décalage résiduel moyen {0} ns, tolérance {1}) : décalé de {2} ns sans nouvelle écriture') -f (Format-UiNum ([math]::Round([double]$vr.RBar, 1)) '0.#'), (Format-UiNum ([math]::Round([double]$vr.RTol, 1)) '0.#'), (Format-LevelSigned $vr.Delta)); Info = $true })
        }
        if ([string]$an.Model -eq 'M0') {
            $r.Shape = @{ Verdict = $(if ([double]$an.Fit.Tau -gt [double]$script:LevelTauOk) { 'approx' } else { 'ok' }); Reasons = @() }
            $r.Verdict = $r.Shape.Verdict
            Append-Log ($pfx + ((T 'Forme de la référence confirmée après mesure à deux précompensations : niveau {0} ns{1}.') -f ('{0:+0;-0;0}' -f [int]$u.Level), $(if ($u.Conv) { '' } else { ' ' + (T '(non vérifié)') })))
            if ($vr.Corr) { Append-Log ($pfx + $j2) }
        } else {
            $r.Shape = @{ Verdict = 'adapte'; Reasons = @() }
            $r.Verdict = 'adapte'
            $r.Model = [string]$an.Model
            $r.S = if ($an.Fit.Coef.ContainsKey('s')) { [double]$an.Fit.Coef['s'] } else { 0.0 }
            $r.B = if ($an.Fit.Coef.ContainsKey('b')) { [double]$an.Fit.Coef['b'] } else { 0.0 }
            if ($an.Fit.Coef.ContainsKey('hc')) { $r.Hc = [double]$an.Fit.Coef['hc'] }
            # Reserve de centre (correction par les controles non verifiee par une ecriture du motif) ou de controle (e2)
            $cres = @()
            if ($an.Center -and $an.Center.Verified -eq $false) {
                $ct = (@(@($an.Center.R.Keys | ForEach-Object { [int]$_ } | Sort-Object) | ForEach-Object { "c$_ $(Format-LevelSigned $an.Center.R[$_]) ns" })) -join ', '
                $cres += ((T 'centre corrigé par les contrôles ({0}), non vérifié par une écriture du motif') -f "$ct")
            }
            if ($u.CtlReserve) { $cres += [string]$u.CtlReserve }
            if ($cres.Count -gt 0) {
                Append-Log ($pfx + ((T "Forme adaptée avec réserve : {0} : vers le centre, la courbe peut s'écarter du besoin de cette disquette ; contrôle après écriture imposé.") -f ($cres -join ' ; ')))
                $iss.Add(@{ Text = $pfx + ((T "forme adaptée avec réserve ({0}) : vers le centre, la courbe peut s'écarter du besoin ; contrôle après écriture imposé") -f ($cres -join ' ; ')); Info = $false })
            }
            if ($vr.Corr) { Append-Log ($pfx + $j2) }
            if ($r.Over.Count -gt 0) {
                # Plafond par disquette : reserve d information (comme le plafond atteint), controle apres ecriture deja impose
                $top = ($vals | Measure-Object -Maximum).Maximum
                Append-Log ($pfx + ((T "Courbe adaptée au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns) : le besoin de cette disquette dépasse la borne precompMaxNs ; plafond porté à {3} ns pour cette disquette seulement ; contrôle après écriture imposé.") -f "$mx", (Format-CylList ([int[]]$r.Over)), "$top", "$hh"))
                $iss.Add(@{ Text = $pfx + ((T "courbe adaptée au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns, plafond porté à {3} ns pour cette disquette seulement) : contrôle après écriture imposé") -f "$mx", (Format-CylList ([int[]]$r.Over)), "$top", "$hh"); Info = $true })
            }
            if (@($an.Reserve).Count -gt 0) {
                # 12.8 (G7) : reserve de forme : controle apres ecriture impose, et non calibration complete (elle ferait de
                # cette disquette la reference du lecteur)
                Append-Log ($pfx + ((T 'Forme adaptée avec réserve : {0} ; défaut local possible ou forme mal identifiée sur {1} cylindres : contrôle après écriture imposé.') -f (@($an.Reserve) -join ' ; '), "$(@($an.Cs).Count)"))
                $iss.Add(@{ Text = $pfx + ((T 'forme adaptée avec réserve ({0}) : défaut local possible ; contrôle après écriture imposé') -f (@($an.Reserve) -join ' ; ')); Info = $false })
            }
            $a0 = [double]$an.Fit.Coef['a']; $last = $sh.N - 1
            $dEnd = (Get-LevelPredict $sh $an.Fit $last)[0] - $a0
            $dLo = (Get-LevelPredict $sh $an.Fit 2)[0] - $a0
            $txt = if ($dEnd -gt 0) { (T 'Courbe adaptée retenue : besoin plus fort vers le centre ({0} ns à c{1}, {2} ns à c2) : autre type de disquette ou usure, non distingués ; à surveiller.') } else { (T 'Courbe adaptée retenue : besoin plus faible vers le centre ({0} ns à c{1}, {2} ns à c2) : autre type de disquette ou usure, non distingués ; à surveiller.') }
            Append-Log ($pfx + ($txt -f (Format-LevelSigned $dEnd), "$last", (Format-LevelSigned $dLo)))
            if ([double]$an.Eff -ge $script:LevelAdaptBigEffect) {
                $it = if ($dEnd -gt 0) { (T 'courbe adaptée à cette disquette (besoin plus fort vers le centre, {0} ns à c{1}) : autre type de disquette ou usure, non distingués ; à surveiller') } else { (T 'courbe adaptée à cette disquette (besoin plus faible vers le centre, {0} ns à c{1}) : autre type de disquette ou usure, non distingués ; à surveiller') }
                $iss.Add(@{ Text = $pfx + ($it -f (Format-LevelSigned $dEnd), "$last"); Info = $true })
            }
        }
        if ($r.Sat.Count -gt 0 -and $hh -ge [int]$script:CalHardMaxNs) {
            # Plafond de la disquette (CalHardMaxNs) atteint : borne haute, plus reglable (12.8, F3R-FIX, constat 9 : aussi
            # quand precompMaxNs vaut deja CalHardMaxNs)
            Append-Log ($pfx + ((T 'Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés.') -f "$hh", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T 'plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés') -f "$hh", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        } elseif ($r.Sat.Count -gt 0) {
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs).") -f "$hh", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs)") -f "$hh", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        }
        if (@($r.Clip).Count -gt 0) { Append-Log ($pfx + ((T "Référence calculée avec une borne de {0} ns, au-delà de la borne actuelle (precompMaxNs = {1} ns) aux cylindres {2} : valeurs ramenées à {1} ns.") -f "$(Get-CurveMaxNs $u.Cv)", "$mx", (Format-CylList ([int[]]$r.Clip)))) }
    }
    if ($u.Named -and $u.Named.Count -gt 0) {
        $nl = @($u.Named.Keys | ForEach-Object { [int]$_ } | Sort-Object | ForEach-Object { "c$_ $($u.Named[$_])" })
        $iss.Add(@{ Text = $pfx + ((T 'cylindres signalés : {0}') -f ($nl -join ' ; ')); Info = $false })
    }
    return $r
}

function Get-LevelBrandKey([string]$name) { return ([string]$name).Trim().ToLowerInvariant() }

function Find-LevelBrand([string]$name, [string]$drive, [string]$refKey, [string]$tag) {
    # Entree de la memoire de marque : meme marque (casse ignoree), meme lecteur, meme cle de reference et meme tete
    $k = Get-LevelBrandKey $name
    if (-not $k) { return $null }
    foreach ($en in @($script:LevelBrands)) {
        if ($en -and (Get-LevelBrandKey $en.Brand) -eq $k -and [string]$en.Drive -eq $drive -and [string]$en.RefKey -eq $refKey -and [string]$en.Tag -eq $tag) { return $en }
    }
    return $null
}

function Test-LevelBrandValid($en, $cv, [string]$fam) {
    # Entree valable comme point de depart : mesuree avec la reference en place (meme date) et de la meme famille
    return [bool]($en -and $cv -and [string]$en.RefDate -eq [string]$cv.Date -and [string]$en.Family -eq $fam)
}

function Update-LevelBrandStats($en) {
    # Point de depart d une entree : niveau = mediane des niveaux, echelle et pente = medianes des formes mesurees
    $lv = @(@($en.Levels) | Where-Object { $_ } | ForEach-Object { [double]$_.Delta })
    $sp = @(@($en.Shapes) | Where-Object { $_ })
    $en.A = if ($lv.Count -gt 0) { [double](Get-Median $lv) } else { 0.0 }
    $en.S = if ($sp.Count -gt 0) { [double](Get-Median @($sp | ForEach-Object { [double]$_.S })) } else { 0.0 }
    $en.B = if ($sp.Count -gt 0) { [double](Get-Median @($sp | ForEach-Object { [double]$_.B })) } else { 0.0 }
    $en.N = $lv.Count
}

function Get-LevelBrandItems([string]$drive, $units, [string]$fam) {
    # Elements de la liste de marques de l avertissement : marques valables pour ce lecteur et cette reference (« memorisee
    # le »), puis marques d une autre reference (« a remesurer »). Renvoie @{ Items ; Map (texte affiche -> marque) }
    $map = @{}; $ok = @(); $old = @()
    $keys = @{}; foreach ($u in @($units)) { if ($null -ne $u.Head) { $keys["$($u.RefKey)|$($u.Tag)"] = $u.Cv } }
    $seen = @{}
    foreach ($en in @(@($script:LevelBrands) | Where-Object { $_ } | Sort-Object { Get-CurveDate $_ } -Descending)) {
        if ([string]$en.Drive -ne $drive) { continue }
        $kk = "$($en.RefKey)|$($en.Tag)"; if (-not $keys.ContainsKey($kk)) { continue }
        $bk = Get-LevelBrandKey $en.Brand; if ($seen.ContainsKey($bk)) { continue }
        $seen[$bk] = $true
        $valid = Test-LevelBrandValid $en $keys[$kk] $fam
        $txt = if ($valid) { (T '{0} - mémorisée le {1}') -f "$($en.Brand)", "$($en.Date)" } else { (T '{0} - à remesurer (référence du lecteur changée)') -f "$($en.Brand)" }
        $map[$txt] = [string]$en.Brand
        if ($valid) { $ok += $txt } else { $old += $txt }
    }
    $none = (T '(non précisée)'); $map[$none] = ''
    return @{ Items = @(@($none) + $ok + $old); Map = $map }
}

function Get-LevelBrandName([string]$text, $map) {
    # Marque saisie ou choisie : texte d un element de la liste ramene a la marque ; « (non precisee) » : aucune
    $t = ([string]$text).Trim()
    if ($map -and $map.ContainsKey($t)) { return [string]$map[$t] }
    return $t
}

function Set-LevelBrandStart($cal, $u, [string]$brand) {
    # 12.8 (lot 1c, § 10.3) : point de depart d une marque memorisee avec la reference en place (meme lecteur, meme cle,
    # meme date de reference, meme famille) et dont la forme n est pas celle de la reference (echelle ou pente non
    # nulle) : V' = V + s (V - RBar) + b (c - (n-1)/2) / (n-1), niveau de depart = mediane des niveaux de la marque,
    # historique de l alerte de fatigue = niveaux de la marque (G4). Sinon : V et niveau de depart de la 12.7 (une entree
    # de niveau seul, comme un enregistrement lvl1 relu avec s = b = 0, n a aucun effet). La forme memorisee ne remplace
    # jamais une mesure : le declencheur B l ecarte si la disquette ne lui ressemble pas
    if (-not $brand -or $null -eq $u.Head) { return }
    $en = Find-LevelBrand $brand ([string]$cal.Drive) ([string]$u.RefKey) ([string]$u.Tag)
    if (-not (Test-LevelBrandValid $en $u.Cv ([string]$cal.Family))) { return }
    Update-LevelBrandStats $en
    $u.BrandEntry = $en
    if ([double]$en.S -eq 0 -and [double]$en.B -eq 0) { return }
    $sh = New-LevelShape $u.V
    $vals = New-Object int[] $sh.N
    for ($c = 0; $c -lt $sh.N; $c++) { $vals[$c] = [int][math]::Round($sh.V[$c] + [double]$en.S * (Get-LevelShapeRow $sh ([string[]]@('s')) $c)[0] + [double]$en.B * (Get-LevelShapeRow $sh ([string[]]@('b')) $c)[0]) }
    $u.V = $vals
    $u.D0 = [int][math]::Round([double]$en.A); $u.D = $u.D0
    $ld = @(@($en.Levels) | Where-Object { $_ } | Sort-Object { Get-CurveDate $_ })
    $u.Memo = @{ Brand = [string]$en.Brand; A = [double]$en.A; S = [double]$en.S; B = [double]$en.B; N = [int]$en.N; Model = [string]$en.Model
                 Hist = @(@($en.Levels) | Where-Object { $_ } | ForEach-Object { @{ Date = [string]$_.Date; Delta = [int]$_.Delta } })
                 LastDate = $(if ($ld.Count -gt 0) { [string]$ld[-1].Date } else { [string]$en.Date }) }
}

function Get-LevelBrandVerified($u) {
    # Tete verifiee pour la memoire de marque : forme adaptee sans reserve et niveau verifie, ou niveau verifie sans nouvelle
    # adaptation (forme conforme ou approximative, sans bascule ni borne)
    # 12.8 (F3R, G5) : jamais une tete avec reserve de controle (e2) ni terme de centre, meme verifie (le format a, s, b de
    # la memoire de marque le perdrait) ; une courbe au-dela de CalHardNs (plafond par disquette) n en est pas exclue
    if ($null -eq $u.Head -or $u.Fail -or -not $u.Conv -or $u.Early -or $u.Sat -or $u.Low -or $u.Few) { return $false }
    if ([string]$u.Mode -eq 'adapte') { return [bool](@($u.AN.Reserve).Count -eq 0 -and -not $u.CtlReserve -and -not $u.AN.Center) }
    if ([string]$u.Mode -eq 'refus') { return $false }
    return [bool]($u.Shape -and @('ok', 'approx') -contains [string]$u.Shape.Verdict)
}

function Get-LevelBrandPlan($cal, [string]$brand) {
    # Effet de la marque sur chaque tete verifiee (§ 10.4, G5) : Differs : la disquette s ecarte de la marque memorisee
    # (nouvelle adaptation par rapport a la reference, ou niveau a plus de LevelFatigueNs de la mediane de la marque)
    # 12.8 (FIX1C, constat 2) : tete partie de la forme de cette marque (Memo) qui a declenche une adaptation (Trig) : la
    # forme de la marque n a pas ete retrouvee sur cette disquette, quel que soit le modele obtenu (forme de la reference
    # confirmee, M0, comprise) : nouvelle adaptation par rapport a la reference, donc Differs
    $plan = @()
    if (-not $brand) { return }
    foreach ($u in @($cal.Units)) {
        if (-not (Get-LevelBrandVerified $u)) { continue }
        $adapted = ([string]$u.Mode -eq 'adapte' -and [string]$u.AN.Model -ne 'M0')
        $fromBrand = [bool]($u.Memo -and $u.Trig -and (Get-LevelBrandKey ([string]$u.Memo.Brand)) -eq (Get-LevelBrandKey $brand))
        $en = Find-LevelBrand $brand ([string]$cal.Drive) ([string]$u.RefKey) ([string]$u.Tag)
        $valid = Test-LevelBrandValid $en $u.Cv ([string]$cal.Family)
        $why = ''
        if ($valid) {
            Update-LevelBrandStats $en
            if ($adapted) { $why = (T 'nouvelle adaptation : {0}') -f (Get-LevelShapeTerms $u.AN.Fit ($u.ShapeV.N - 1)) }
            elseif ($fromBrand -and [string]$u.Mode -eq 'adapte') { $why = (T "forme de la référence confirmée : cette disquette n'a pas la forme de la marque") }
            elseif ($fromBrand) { $why = (T "forme de la marque non retrouvée à la passe {0}") -f "$($u.Trig.Pass)" }
            elseif ([math]::Abs([int]$u.Level - [double]$en.A) -gt [double]$script:LevelFatigueNs) { $why = (T 'niveau {0} ns, médiane de la marque {1} ns') -f ('{0:+0;-0;0}' -f [int]$u.Level), (Format-LevelSigned $en.A) }
        }
        $plan += ,@{ U = $u; Entry = $(if ($valid) { $en } else { $null }); Old = $en; Adapted = $adapted; Differs = [bool]$why; Why = $why }
    }
    return $plan
}

function Update-LevelBrands($cal, [string]$brand, [bool]$explicit) {
    # 12.8 (lot 1c, § 10.4, G5) : memoire de la marque mise a jour apres un resultat accepte, tete par tete verifiee :
    # disquette conforme a la marque : niveau ajoute (forme ajoutee si elle a ete mesuree) ; disquette qui s en ecarte :
    # rien, sauf marque nommee dans la fenetre de decision (explicit : l entree est remplacee) ; marque sans entree pour
    # cette reference (nouvelle, ou reference changee) : entree creee ou remplacee. Tete refusee, avec reserve ou non
    # verifiee : rien
    if (-not $brand) { return }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    foreach ($pl in @(Get-LevelBrandPlan $cal $brand)) {
        $u = $pl.U; $pfx = $u.Prefix
        if ($pl.Differs -and -not $explicit) {
            # 12.8 (FIX1C, constat 6) : la ligne n est ecrite que sans champ de marque dans la fenetre de decision (champ
            # affiche : marque nommee, donc explicit, ou laissee vide, donc rien) : conseil faisable, la prochaine fois
            Append-Log ($pfx + ((T "Forme non mémorisée pour la marque « {0} » : cette disquette s'en écarte ({1}). Si elle est d'une autre marque, choisissez celle-ci, ou « (non précisée) », dans l'avertissement de la prochaine calibration rapide.") -f "$brand", "$($pl.Why)"))
            continue
        }
        $s = 0.0; $b = 0.0; $model = 'M0'
        if ($pl.Adapted) { $co = $u.AN.Fit.Coef; $s = if ($co.ContainsKey('s')) { [double]$co['s'] } else { 0.0 }; $b = if ($co.ContainsKey('b')) { [double]$co['b'] } else { 0.0 }; $model = [string]$u.AN.Model }
        $en = $pl.Entry
        if (-not $en -or $pl.Differs) {
            # Entree creee, ou remplacee (reference changee, ou disquette differente nommee dans la fenetre)
            if ($pl.Old) { $old = $pl.Old; $script:LevelBrands = @(@($script:LevelBrands) | Where-Object { -not [object]::ReferenceEquals($_, $old) }) }
            $en = @{ Brand = $brand; Drive = [string]$cal.Drive; RefKey = [string]$u.RefKey; Tag = [string]$u.Tag; Head = $u.Head; Family = [string]$cal.Family
                     RefDate = [string]$u.Cv.Date; LevelAlgo = 'lvl2'; Model = $model; A = 0.0; S = 0.0; B = 0.0; N = 0; Date = $date; Levels = @(); Shapes = @() }
            $script:LevelBrands = @(@($script:LevelBrands) + @($en))
        }
        $en.Levels = @(@(@($en.Levels) + @(@{ Date = $date; Delta = [int]$u.Level })) | Select-Object -Last ([int]$script:LevelBrandKeepLevels))
        if ($pl.Adapted) { $en.Shapes = @(@(@($en.Shapes) + @(@{ Date = $date; S = [math]::Round($s, 4); B = [math]::Round($b, 2) })) | Select-Object -Last ([int]$script:LevelBrandKeepShapes)); $en.Model = $model }
        $en.Date = $date; $en.Brand = $brand
        Update-LevelBrandStats $en
        Append-Log ((T '{0}Forme mémorisée pour la marque « {1} » : niveau {2} ns, échelle {3} %, pente {4} ns ({5} mesure(s)).') -f "$pfx", "$brand", (Format-LevelSigned $en.A), (Format-UiNum ([math]::Round(100 * [double]$en.S, 1)) '+0.0;-0.0;0.0'), (Format-LevelSigned $en.B), "$($en.N)")
    }
    $script:LevelBrand = $brand
    # Entrees gardees : les LevelBrandMax plus recentes
    $all = @(@($script:LevelBrands) | Where-Object { $_ })
    if ($all.Count -gt $script:LevelBrandMax) { $script:LevelBrands = @($all | Sort-Object { Get-CurveDate $_ } -Descending | Select-Object -First ([int]$script:LevelBrandMax)) }
}

function Test-LevelAdaptedSpec([string[]]$specs) {
    # 12.8 (FIX1C, constat 3, G1) : un profil --precomp ecrit est-il la courbe adaptee d une calibration rapide
    # (enregistrement de $script:LevelShifts au modele autre que M0 : forme ajustee, ou forme d une marque au depart) ?
    # G1 suit la courbe ecrite, pas le chemin : bouton Calibrer au test rapide, puis ECRIRE sans nouvelle mesure (test
    # standard ou fin, profil Manuel) ; un profil modifie a la main n est plus cette courbe
    $set = @{}
    foreach ($s in @($specs)) { if ($s -and ([string]$s).Trim()) { $set[([string]$s).Trim()] = $true } }
    if ($set.Count -eq 0 -or -not $script:LevelShifts) { return $false }
    foreach ($k in @($script:LevelShifts.Keys)) {
        $r = $script:LevelShifts[$k]
        if ($r -and $r.Model -and [string]$r.Model -ne 'M0' -and $r.Spec -and $set.ContainsKey(([string]$r.Spec).Trim())) { return $true }
    }
    return $false
}

function Get-LevelBrandsOfRef([string]$key, [string]$refDate, [string]$drive) {
    # Marques memorisees avec une reference (cle, date, lecteur) : invalidees par une nouvelle reference (§ 10.5)
    return @(@($script:LevelBrands) | Where-Object { $_ -and [string]$_.RefKey -eq $key -and [string]$_.RefDate -eq $refDate -and [string]$_.Drive -eq $drive } | ForEach-Object { [string]$_.Brand } | Sort-Object -Unique)
}
