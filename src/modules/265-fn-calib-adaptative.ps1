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

function New-LevelShape($ref) {
    # Colonnes du modele de forme d une tete, relatives a sa reference : a (niveau), s (echelle centree sur la moyenne
    # RBar de la reference), b (pente du premier au dernier cylindre, centree)
    $vals = [double[]]@(@($ref) | ForEach-Object { [double]$_ })
    $sum = 0.0; foreach ($x in $vals) { $sum += $x }
    return @{ V = $vals; N = $vals.Count; RBar = $sum / $vals.Count }
}

function Get-LevelShapeRow($sh, [string[]]$names, [int]$c) {
    $row = New-Object double[] $names.Count
    for ($i = 0; $i -lt $names.Count; $i++) {
        if ($names[$i] -eq 'a') { $row[$i] = 1.0 }
        elseif ($names[$i] -eq 's') { $row[$i] = [double]$sh.V[$c] - [double]$sh.RBar }
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
    # Cylindres d ajustement : cylindres de niveau et temoins de marche (les cylindres de controle en sont exclus)
    return ,[int[]]@(@(@($u.LCyls) + @($u.Wit)) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
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
    $out = @{ Ok = $false; Why = ''; KPool = $kpool; Ks = $ks; KOrder = $kOrder; Named = @{}; Model = $null; Excl = @(); Reserve = @(); Iso = @{}; Zs = @{}; D = @{}; Sig = @{}; Cap = @(); BadK = @() }
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
        $out.Why = (T 'écarts dispersés ({0} signalé, c{1} hors de la forme ajustée)') -f (Format-CylList ([int[]]@(@($pre) + @($badK)))), "$($o[0].C)"
        $out.Named[$o[0].C] = (T 'écart dispersé')
        return $out
    }
    if ($o.Count -gt 0) {
        $c0 = $o[0].C
        $cs2 = @($cs | Where-Object { $_ -ne $c0 })
        if ($cs2.Count -lt $script:LevelAdaptMinFit) {
            $out.Why = (T 'écart isolé à c{0} et trop peu de cylindres restants') -f "$c0"
            $out.Named[$c0] = (T 'écart isolé'); $out.Iso[$c0] = $o[0].R
            return $out
        }
        $sel2 = Select-LevelModel $sh ([int[]]$cs2) $d $sg
        if ($sel2) { $o2 = & $outl $sel2.Best } else { $o2 = @(@{ C = -1 }) }
        if ($o2.Count -gt 0) {
            $oc = @($o2 | Where-Object { $_.C -ge 0 } | ForEach-Object { $_.C })
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
        $out.Why = (T 'écart de forme résiduel {0} ns (au plus {1})') -f (Format-UiNum ([math]::Round($f.Tau, 1)) '0.#'), (Format-UiNum ([math]::Round([double]$script:LevelTauMax, 1)) '0.#')
        return $out
    }
    $s = if ($f.Coef.ContainsKey('s')) { [double]$f.Coef['s'] } else { 0.0 }
    $b = if ($f.Coef.ContainsKey('b')) { [double]$f.Coef['b'] } else { 0.0 }
    if ([math]::Abs($s) -gt $script:LevelAdaptSMax -or [math]::Abs($b) -gt $script:LevelAdaptBMax) {
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
    switch ($model) { 'Ms' { return (T 'niveau et échelle') } 'Mb' { return (T 'niveau et pente') } 'Msb' { return (T 'niveau, échelle et pente') } default { return (T 'niveau seul') } }
}

function Get-LevelShapeTerms($fit, [int]$last) {
    # « niveau +45 ns, échelle +19,0 %, pente +22 ns de c0 à c79 »
    $co = $fit.Coef
    $terms = @((T 'niveau {0} ns') -f (Format-LevelSigned $co['a']))
    if ($co.ContainsKey('s')) { $terms += ((T 'échelle {0} %') -f (Format-UiNum ([math]::Round(100 * [double]$co['s'], 1)) '+0.0;-0.0;0.0')) }
    if ($co.ContainsKey('b')) { $terms += ((T 'pente {0} ns de c0 à c{1}') -f (Format-LevelSigned $co['b']), "$last") }
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

function Build-LevelAdaptValues($u, $fit) {
    # Courbe adaptee : reference du lecteur + modele, bornee a 0..CalHardNs ; valeur de reference a la borne de son calcul
    # (Get-CurveMaxNs) jamais abaissee, comme Build-LevelValues. Sat : besoin du modele au-dela de la borne ; Clip :
    # reference elle-meme au-dela de la borne actuelle (borne reglable, pas un besoin de cette disquette)
    $sh = $u.ShapeV; $mx = [int]$script:CalHardNs; $rmax = Get-CurveMaxNs $u.Cv
    $n = $sh.N
    $vals = New-Object int[] $n; $raw = New-Object double[] $n
    $sat = @(); $floor = @(); $clip = @()
    for ($c = 0; $c -lt $n; $c++) {
        $rv = [double]$sh.V[$c]
        $v = $rv + (Get-LevelPredict $sh $fit $c)[0]
        if ($rv -ge $rmax) { $v = [math]::Max($v, $rv) }
        $raw[$c] = $v
        if ($rv -gt $mx) { $clip += $c }
        elseif ($v -gt $mx) { $sat += $c }
        elseif ($v -lt 0 -and $rv -gt 0) { $floor += $c }
        $vals[$c] = if ($rv -gt 0) { [int][math]::Max(0, [math]::Min($mx, [math]::Round($v))) } else { 0 }
    }
    return @{ Values = $vals; Raw = $raw; Sat = $sat; Floor = $floor; Clip = $clip }
}

function Set-LevelVerifTargets($cal, $u, $an) {
    # Passe de verification : courbe adaptee ecrite sur les cylindres d ajustement et les cylindres de controle
    $bv = Build-LevelAdaptValues $u $an.Fit
    $u.AV = $bv
    $t = @{}
    $fc = Get-LevelFitCyls $u
    foreach ($c in @(@($fc) + @($u.Ctl) | ForEach-Object { [int]$_ } | Sort-Object -Unique)) { $t[$c] = [int]$bv.Values[$c] }
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
    # journal ; Why non vide : refus
    $pfx = $u.Prefix; $an = $u.AN; $sh = $u.ShapeV; $kp = [double]$an.KPool; $kref = [double]$u.KRef
    $raw = @{}
    foreach ($c in @($u.LTarget.Keys | ForEach-Object { [int]$_ })) { $lst = $u.Raw[$c]; if ($lst -and @($lst).Count -gt 0 -and [int]$lst[-1][0] -eq $p) { $raw[$c] = $lst[-1] } }
    $fitc = @($an.Cs | Where-Object { $raw.ContainsKey([int]$_) })
    $rs = @($fitc | ForEach-Object { [double]$raw[[int]$_][2].Shift })
    $vr = @{ Tier = @{}; Dev = @{}; Ctl = @{}; Conv = $false; RBar = [double]::NaN; RTol = [double]::NaN; Delta = 0.0; NewBad = @(); Confirmed = @(); NonRep = @(); BadCtl = @(); Why = '' }
    if ($rs.Count -eq 0) { $vr.Why = (T 'aucune mesure à la vérification'); return $vr }
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
    $vr.RBar = $rbar; $vr.RTol = $rtol; $vr.Conv = $conv; $vr.Delta = $delta
    foreach ($c in @($raw.Keys | Sort-Object)) {
        if (@($u.Ctl) -contains $c) { continue }
        $m = $raw[$c][2]
        $k = if ($an.Ks.ContainsKey($c)) { [double]$an.Ks[$c] } else { $kp }
        if (-not ([double]$script:LevelAdaptKRatioLo * $kref -le $k -and $k -le [double]$script:LevelAdaptKRatioHi * $kref)) { $k = $kp }
        $dev = [double]$m.Shift / $k - $delta
        $sgc = [math]::Max(1.0, (Get-LevelSE $m) / $k)
        $tol1 = Get-ResidualTol $m
        $tier = if ([math]::Abs([double]$m.Shift - $(if ($conv) { 0.0 } else { $rbar })) -le $tol1) { 1 } elseif ([math]::Abs($dev) -gt [math]::Max([double]$script:CalDevNs, 4.0 * $sgc)) { 3 } else { 2 }
        $vr.Tier[$c] = $tier; $vr.Dev[$c] = $dev
        if ($an.Named.ContainsKey($c)) { if ($tier -eq 3) { $vr.Confirmed += $c } else { $vr.NonRep += $c } }
        elseif ($tier -eq 3) { $vr.NewBad += $c }
    }
    foreach ($x in @($u.Ctl | ForEach-Object { [int]$_ })) {
        if (-not $raw.ContainsKey($x)) { continue }
        $m = $raw[$x][2]
        $dev = [double]$m.Shift / $kp - $delta
        $sp = (Get-LevelPredict $sh $an.Fit $x)[1]
        $tol = [math]::Min([double]$script:LevelAdaptCtlCap, [math]::Max([double]$script:LevelAdaptCtlFloor, [double]$script:LevelAdaptCtlK * [math]::Sqrt([math]::Pow($sp, 2) + [math]::Pow([double]$script:LevelShapeFloor, 2) + [math]::Pow((Get-LevelSE $m) / $kp, 2))))
        $capped = ([int]$u.LTarget[$x] -ge [int]$script:CalHardNs -and [double]$m.Shift -gt 0)
        $vr.Ctl[$x] = @{ Dev = $dev; Tol = $tol; Ok = ([math]::Abs($dev) -le $tol -or $capped); Cap = $capped }
    }
    $vr.BadCtl = @($vr.Ctl.Keys | Sort-Object | Where-Object { -not $vr.Ctl[$_].Ok })
    $t1 = @($vr.Tier.Keys | Sort-Object | Where-Object { $vr.Tier[$_] -eq 1 -and -not $an.Named.ContainsKey($_) })
    $t2 = @($vr.Tier.Keys | Sort-Object | Where-Object { $vr.Tier[$_] -eq 2 -and -not $an.Named.ContainsKey($_) })
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
    # verdict, forme, reserves (Info : reserve « information » de la fenetre de decision), lignes du journal
    $pfx = $u.Prefix; $e = $u.Est; $an = $u.AN; $mx = [int]$script:CalHardNs
    $iss = New-Object System.Collections.Generic.List[object]
    $r = @{ Values = $null; Sat = @(); Floor = @(); Clip = @(); Verdict = ''; Shape = $null; Issues = $iss; Model = 'M0'; S = 0.0; B = 0.0; K = $null }
    if ([string]$u.Mode -eq 'refus') {
        $bv = Build-LevelValues $u ([int]$u.Level) $e
        $r.Values = $bv.Values; $r.Sat = @($bv.Sat); $r.Floor = @($bv.Floor); $r.Clip = @($bv.Clip)
        $sh = if ($e) { Test-LevelShape $e $u 1.0 } else { @{ Reasons = @() } }
        $r.Shape = @{ Verdict = 'mismatch'; Reasons = @($sh.Reasons); Tilt = $sh.Tilt; Step = $sh.Step }
        $r.Verdict = 'mismatch'
        Append-Log ($pfx + ((T 'Forme non conforme à la référence et non adaptée : {0}.') -f "$($u.Refus)"))
        $iss.Add(@{ Text = $pfx + ((T 'adaptation refusée : {0}') -f "$($u.Refus)"); Info = $false })
        if (-not $u.Conv) { $iss.Add(@{ Text = $pfx + ((T "niveau non vérifié par une écriture du motif ({0} passe(s))") -f "$($u.Passes)"); Info = $false }) }
        if ($r.Sat.Count -gt 0 -and $u.Memo) {
            # 12.8 (FIX1C, constat 5) : courbe de refus partie de la forme d une marque (V' + niveau) : libelle neutre
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs).") -f "$mx", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs)") -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        } elseif ($r.Sat.Count -gt 0) {
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence) : support probablement fatigué, ces cylindres resteront sous-compensés.") -f "$mx", (Format-CylList ([int[]]$r.Sat)), ('{0:+0;-0;0}' -f [int]$u.Level)))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
        }
        if ($r.Floor.Count -gt 0) { $iss.Add(@{ Text = $pfx + ((T "précompensation nulle encore excessive aux cylindres {0}") -f (Format-CylList ([int[]]$r.Floor))); Info = $false }) }
        if ($an -and $an.KPool) { $r.K = [double]$an.KPool }
    } else {
        $bv = $u.AV; $vr = $u.VR; $sh = $u.ShapeV
        $vals = [int[]]@($bv.Values)
        if ([double]$vr.Delta -ne 0) {
            $dd = [int][math]::Round([double]$vr.Delta)
            for ($c = 0; $c -lt $vals.Count; $c++) { $vals[$c] = if ($sh.V[$c] -gt 0) { [int][math]::Max(0, [math]::Min($mx, $vals[$c] + $dd)) } else { 0 } }
        }
        $r.Values = $vals
        $r.Clip = @($bv.Clip)
        $r.Sat = @(0..($vals.Count - 1) | Where-Object { $r.Clip -notcontains $_ -and [double]$bv.Raw[$_] + [double]$vr.Delta -gt $mx })
        $r.Floor = @($bv.Floor)
        $r.K = [double]$an.KPool
        if (-not $u.Conv) {
            $iss.Add(@{ Text = $pfx + ((T 'niveau de la courbe adaptée non vérifié (décalage résiduel moyen {0} ns, tolérance {1}) : décalé de {2} ns sans nouvelle écriture') -f (Format-UiNum ([math]::Round([double]$vr.RBar, 1)) '0.#'), (Format-UiNum ([math]::Round([double]$vr.RTol, 1)) '0.#'), (Format-LevelSigned $vr.Delta)); Info = $true })
        }
        if ([string]$an.Model -eq 'M0') {
            $r.Shape = @{ Verdict = $(if ([double]$an.Fit.Tau -gt [double]$script:LevelTauOk) { 'approx' } else { 'ok' }); Reasons = @() }
            $r.Verdict = $r.Shape.Verdict
            Append-Log ($pfx + ((T 'Forme de la référence confirmée après mesure à deux précompensations : niveau {0} ns{1}.') -f ('{0:+0;-0;0}' -f [int]$u.Level), $(if ($u.Conv) { '' } else { ' ' + (T '(non vérifié)') })))
        } else {
            $r.Shape = @{ Verdict = 'adapte'; Reasons = @() }
            $r.Verdict = 'adapte'
            $r.Model = [string]$an.Model
            $r.S = if ($an.Fit.Coef.ContainsKey('s')) { [double]$an.Fit.Coef['s'] } else { 0.0 }
            $r.B = if ($an.Fit.Coef.ContainsKey('b')) { [double]$an.Fit.Coef['b'] } else { 0.0 }
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
        if ($r.Sat.Count -gt 0) {
            Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs).") -f "$mx", (Format-CylList ([int[]]$r.Sat))))
            $iss.Add(@{ Text = $pfx + ((T "plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs)") -f "$mx", (Format-CylList ([int[]]$r.Sat))); Info = $true })
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
    if ($null -eq $u.Head -or $u.Fail -or -not $u.Conv -or $u.Early -or $u.Sat -or $u.Low -or $u.Few) { return $false }
    if ([string]$u.Mode -eq 'adapte') { return [bool](@($u.AN.Reserve).Count -eq 0) }
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
