# ============================== FONCTIONS : CALIBRATION RAPIDE (NIVEAU) ========

# ============================== CALIBRATION RAPIDE (NIVEAU PAR DISQUETTE) ======
# Observation sur materiel reel : la forme de la courbe tient au lecteur, son niveau au support. La courbe d une
# calibration complete (reference, jamais modifiee) est decalee d un niveau uniforme mesure sur la disquette qui va
# recevoir l image : 6 cylindres de niveau pris parmi les mesures verifiees de la reference, 2 temoins de marche et
# 1 temoin du plafond au plus, 1 a 3 passes qui ecrivent la reference decalee (le niveau retenu est celui d une passe
# ecrite et verifiee). Le resultat ne va que dans les champs --precomp de l ecriture qui suit et dans
# $script:LevelShifts (affichage, historique, niveau de depart).

function Format-LevelNum($x) {
    # Nombre d un texte de la calibration rapide : une decimale au plus, au format de la culture ; '-' si non defini
    if ($null -eq $x -or [double]::IsNaN([double]$x)) { return '-' }
    return ('{0:0.#}' -f [math]::Round([double]$x, 1))
}

function Get-WeightedMedian($v, $w) {
    $n = @($v).Count
    if ($n -eq 0) { return [double]::NaN }
    $idx = @(0..($n - 1) | Sort-Object { [double]$v[$_] })
    $tot = 0.0; foreach ($x in @($w)) { $tot += [double]$x }
    $acc = 0.0
    foreach ($i in $idx) { $acc += [double]$w[$i]; if ($acc -ge $tot / 2) { return [double]$v[$i] } }
    return [double]$v[$idx[-1]]
}

function Get-LevelZero($points, [double]$k) {
    # Zero d un cylindre en precomp absolue (k = pente en valeur absolue) : Get-CalibZero avec deux mesures ou plus ;
    # avec une seule, extrapolation par la pente, encadree si le decalage est dans deux erreurs-types
    if (-not $points) { return $null }
    $xs = @($points.Keys | ForEach-Object { [int]$_ })
    if ($xs.Count -ge 2) { return (Get-CalibZero $points (-$k)) }
    if ($xs.Count -eq 0) { return $null }
    $x = $xs[0]; $m = $points[$x]
    $e = if ($null -eq $m.SE -or [double]::IsNaN([double]$m.SE) -or [double]$m.SE -le 0) { 2.0 } else { [double]$m.SE }
    $x0 = $x + [double]$m.Shift / $k
    $sig = [math]::Sqrt([math]::Pow($e / $k, 2) + [math]::Pow(0.25 * [math]::Abs($x0 - $x), 2))
    if ([math]::Abs([double]$m.Shift) -le 2.0 * $e) { return (Limit-CalibZero $x0 $sig 'interp' (-$k) $false) }
    return (Limit-CalibZero $x0 ([math]::Max(5.0, $sig)) 'extrap' (-$k) $false)
}

function Get-LevelCands($cv, [int]$last) {
    # Cylindres candidats d une reference : mesures encadrees et verifiees, loin des changements de sens, voisinage plat ;
    # zone plafonnee terminale et son temoin ; temoins de marche (sommet et cylindre mesure suivant)
    $V = @($cv.Values); $cyls = @(@($cv.Cyls) | ForEach-Object { [int]$_ })
    $brk = @(@($cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    # Zone plafonnee : fin de la reference a la borne de SON calcul (300 ns avant le calcul 12.4, Get-CurveMaxNs)
    $max = Get-CurveMaxNs $cv
    $capLo = $V.Count
    for ($c = $V.Count - 1; $c -ge 0; $c--) { if ([int]$V[$c] -ge $max) { $capLo = $c } else { break } }
    $probe = $null; if ($capLo -le $last) { $probe = $last }
    $pick = {
        param([int]$lo, [double]$vLo, [double]$vHi, [double]$resMax)
        $out = @()
        for ($i = 0; $i -lt $cyls.Count; $i++) {
            $c = $cyls[$i]
            if ($c -lt $lo -or $c -gt $last -or $c -ge $capLo) { continue }
            $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { [string]$cv.Kinds[$i] } else { 'interp' }
            if ($kind -ne 'interp' -or (Test-CurvePointFlag $cv $i)) { continue }
            $res = if ($cv.Res -and $i -lt @($cv.Res).Count) { [double]$cv.Res[$i] } else { [double]::NaN }
            if ([double]::IsNaN($res) -or [math]::Abs($res) -gt $resMax) { continue }
            $vc = [double]$V[$c]
            if ($vc -lt $vLo -or $vc -gt $vHi) { continue }
            $near = $false; foreach ($b in $brk) { if ([math]::Abs($c - $b) -le 1 -or [math]::Abs($c - ($b + 1)) -le 1) { $near = $true } }
            if ($near) { continue }
            if ($c -gt 0 -and [math]::Abs($vc - [double]$V[$c - 1]) -gt $script:LevelSteep) { continue }
            if ($c + 1 -lt $V.Count -and [math]::Abs([double]$V[$c + 1] - $vc) -gt $script:LevelSteep) { continue }
            $out += $c
        }
        return $out
    }
    $cand = @(& $pick 2 $script:LevelLo $script:LevelHi $script:CalResidual)
    $fb = $false
    if ($cand.Count -lt $script:LevelMinCyls) { $cand = @(& $pick 0 5 290 12); $fb = $true }     # repli : 10 ns sous le plafond des passes de mesure (300 ns)
    $wit = @()
    if ($brk.Count -ge 1) {
        $pk = $brk[0]; $ip = [array]::IndexOf([int[]]$cyls, [int]$pk)
        if ($ip -ge 0 -and $ip + 1 -lt $cyls.Count) {
            $nx = $cyls[$ip + 1]
            $good = { param($i) ((-not $cv.Kinds) -or [string]$cv.Kinds[$i] -eq 'interp') -and -not (Test-CurvePointFlag $cv $i) }
            if (($nx - $pk) -le 3 -and $nx -le $last -and (& $good $ip) -and (& $good ($ip + 1)) -and ([double]$V[$pk] - [double]$V[$nx]) -ge 30) { $wit = @($pk, $nx) }
        }
    }
    return @{ Cands = $cand; CapLo = $capLo; Wit = $wit; Probe = $probe; Fallback = $fb }
}

function Select-LevelCyls([int[]]$cand, [int[]]$brk, [int]$n) {
    # Selection deterministe : extremites (bras de levier), voisins de chaque changement de sens, puis le plus eloigne
    $c = @($cand | Sort-Object -Unique)
    if ($c.Count -le $n) { return ,[int[]]$c }
    $sel = New-Object System.Collections.Generic.List[int]
    $sel.Add($c[0]); if (-not $sel.Contains($c[-1])) { $sel.Add($c[-1]) }
    foreach ($b in @($brk)) {
        $l = @($c | Where-Object { $_ -le $b }); $r = @($c | Where-Object { $_ -gt $b + 1 })
        if ($l.Count -gt 0 -and -not $sel.Contains($l[-1]) -and $sel.Count -lt $n) { $sel.Add($l[-1]) }
        if ($r.Count -gt 0 -and -not $sel.Contains($r[0]) -and $sel.Count -lt $n) { $sel.Add($r[0]) }
    }
    while ($sel.Count -lt $n) {
        $best = -1; $bd = -1
        foreach ($x in $c) {
            if ($sel.Contains($x)) { continue }
            $d = (@($sel) | ForEach-Object { [math]::Abs($x - $_) } | Measure-Object -Minimum).Minimum
            if ($d -gt $bd) { $bd = $d; $best = $x }
        }
        if ($best -lt 0) { break }
        $sel.Add($best)
    }
    return ,[int[]]@($sel | Sort-Object)
}

function Get-LevelRef([string]$fam, [bool]$heads, [string]$drive, [string]$img, [bool]$restore, [int]$NCyl = 0, [int]$Bits = 0, [switch]$ForHome) {
    # Reference de forme pour la calibration rapide. Class 'redo' : calibration complete necessaire ; 'domain' : image
    # hors du domaine de la reference (geometrie, densite), Short si la reference a moins de cylindres que l image. NCyl,
    # Bits (> 0) : cylindres et cellules par piste donnes a la place de ceux de l image (format d une image secteur,
    # fenetre de la carte Calibration sans image). ForHome : carte Calibration de l Accueil (type de disquette, sans image :
    # raisons et notes parlent du type). Variables locales $nc et $pbits : $nCyl et $bits designeraient les parametres
    # types [int] (noms insensibles a la casse)
    $res = @{ Ok = $false; Class = 'redo'; Why = ''; Units = @(); Notes = @(); NCyl = 80; MaxCyl = 79; Family = $fam; Short = $false }
    # 12.7 : pas de calibration rapide en haute densite (seuils regles sur des donnees double densite, non transposes) :
    # hors domaine, sans offre de calibration complete en boucle
    if ($fam -eq 'hd') { $res.Class = 'domain'; $res.Why = (T "la haute densité n'a pas encore de calibration rapide : faites une calibration complète"); return $res }
    $nc = if ($NCyl -gt 0) { $NCyl } else { Get-ImageCylinders $img }; if ($null -eq $nc) { $nc = 80 }
    $nc = [math]::Max(2, [math]::Min(84, [int]$nc)); $res.NCyl = $nc; $res.MaxCyl = $nc - 1
    $specs = @()
    if (-not $heads) {
        $cv = $script:PrecompCurves[$fam]
        if (-not $cv) { $res.Why = (T "aucune calibration commune pour la famille {0}") -f (Get-CalibFamilyName $fam); return $res }
        $specs = @(@{ Key = $fam; Tag = 'c'; Head = $null; Cv = $cv })
    } elseif (Test-HeadCurvesCurrent $fam) {
        $specs = @(@{ Key = "${fam}_h0"; Tag = '0'; Head = 0; Cv = $script:PrecompCurves["${fam}_h0"] }, @{ Key = "${fam}_h1"; Tag = '1'; Head = 1; Cv = $script:PrecompCurves["${fam}_h1"] })
    } elseif ($restore -and $script:PrecompCurves[$fam]) {
        $cv = $script:PrecompCurves[$fam]
        $specs = @(@{ Key = $fam; Tag = '0'; Head = 0; Cv = $cv }, @{ Key = $fam; Tag = '1'; Head = 1; Cv = $cv })
    } else { $res.Why = (T "aucune calibration par tête à jour pour la famille {0}") -f (Get-CalibFamilyName $fam); return $res }
    foreach ($s in $specs) {
        $cv = $s.Cv
        if ($cv.Method -ne 'motif') { $res.Why = (T 'référence mesurée sur le contenu d''une image, avant le motif de test'); return $res }
        if ([string]$cv.Drive -ne $drive) { $res.Why = (T "référence mesurée sur le lecteur {0}, et non {1}") -f "$($cv.Drive)", "$drive"; return $res }
        if ($null -eq $cv.Slope -or -not $cv.Bits) { $res.Why = (T 'référence antérieure à la calibration rapide (pente ou densité non enregistrée)'); return $res }
    }
    $vc = @($specs[0].Cv.Values).Count
    if ([math]::Abs($nc - $vc) -gt 4) {
        $res.Class = 'domain'; $res.Short = ($vc -lt $nc)
        $res.Why = $(if ($ForHome) { (T "type de {0} cylindres, référence de {1}") } else { (T "image de {0} cylindres, référence de {1}") }) -f "$nc", "$vc"; return $res
    }
    $pbits = [double]$(if ($Bits -gt 0) { $Bits } else { (Get-PatternBits $fam $img).Bits }); $rb = [double]$specs[0].Cv.Bits
    $dev = [math]::Abs($pbits - $rb) / $rb
    $devTxt = Format-UiNum ([math]::Round(100 * $dev, 1)) '0.#'
    if ($dev -gt $script:LevelBitsMax) { $res.Class = 'domain'; $res.Why = $(if ($ForHome) { (T "densité de ce type différente de celle de la référence de {0} % (5 % au plus)") } else { (T "densité de l'image différente de celle de la référence de {0} % (5 % au plus)") }) -f "$devTxt"; return $res }
    if ($dev -gt $script:LevelBitsNote) { $res.Notes += ($(if ($ForHome) { (T "Densité de ce type différente de celle de la référence de {0} %.") } else { (T "Densité de l'image différente de celle de la référence de {0} %.") }) -f "$devTxt") }
    $last = [math]::Min($nc - 1, $vc - 1)
    $cands = @(); foreach ($s in $specs) { $cands += ,(Get-LevelCands $s.Cv $last) }
    $common = $null
    if ($specs.Count -eq 2) {
        $inter = @(@($cands[0].Cands) | Where-Object { @($cands[1].Cands) -contains $_ })
        if ($inter.Count -ge $script:LevelMinCyls) {
            $brkU = @(@(@($specs[0].Cv.Breaks) + @($specs[1].Cv.Breaks)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
            $common = Select-LevelCyls ([int[]]$inter) ([int[]]$brkU) $script:LevelCyls
        }
    }
    $units = @()
    for ($i = 0; $i -lt $specs.Count; $i++) {
        $s = $specs[$i]; $cd = $cands[$i]; $cv = $s.Cv
        $sel = if ($null -ne $common) { $common } else { Select-LevelCyls ([int[]]@($cd.Cands)) ([int[]]@(@($cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })) $script:LevelCyls }
        if (@($sel).Count -lt $script:LevelMinCyls) { $res.Why = (T "trop peu de cylindres de mesure fiables dans la référence ({0}, {1} au moins)") -f "$(@($sel).Count)", "$($script:LevelMinCyls)"; return $res }
        $kref = [math]::Max($script:LevelKMin, [math]::Min(3.0, -[double]$cv.Slope))
        $hk = "$($s.Key)|$($s.Tag)"; $old = $script:LevelShifts[$hk]
        $d0 = 0; $nh = 0
        if ($old -and [string]$old.RefDate -eq [string]$cv.Date -and @($old.Hist).Count -gt 0) {
            $hv = @(@($old.Hist) | Select-Object -Last 4 | ForEach-Object { [double]$_.Delta }); $nh = $hv.Count
            $d0 = [int][math]::Round((Get-Median (@(0.0) + $hv)))
        }
        $units += ,@{ RefKey = $s.Key; Tag = $s.Tag; Head = $s.Head; Cv = $cv; V = [int[]]@($cv.Values); KRef = $kref; LCyls = [int[]]@($sel)
                      Wit = [int[]]@($cd.Wit); Probe = $cd.Probe; CapLo = [int]$cd.CapLo; D0 = $d0; NHist = $nh }
    }
    if (@($specs | Where-Object { $_.Cv.Converged -eq $false }).Count -gt 0) { $res.Notes += (T 'Référence non convergée : ses cylindres hors tolérance sont exclus de la mesure ; une calibration complète en test fin est conseillée.') }
    $kcv = @($specs | Where-Object { (Get-CurveCalc $_.Cv) -ne (Get-CurveCalcRef $_.Cv) })
    if ($kcv.Count -gt 0) { $res.Notes += ((T "Référence faite avec le calcul de calibration {0}.") -f (Get-CurveCalcText $kcv[0].Cv)) }
    if (@($specs | Where-Object { [string]$_.Cv.Test -eq 'std' }).Count -gt 0) { $res.Notes += (T 'Référence en test standard : entre les cylindres mesurés, la forme est interpolée ; une référence en test fin est conseillée.') }
    if (@($cands | Where-Object { $_.Fallback }).Count -gt 0) { $res.Notes += (T "Trop peu de cylindres de mesure selon les règles habituelles : règles élargies (cylindres 0 et 1 admis, valeurs de 5 à 290 ns, résidu de référence jusqu'à 12 ns).") }
    $res.Ok = $true; $res.Units = $units; $res.Why = ''
    return $res
}

function Set-LevelTargets($u) {
    # Cibles de la passe : reference decalee du niveau courant (cylindres de niveau et temoins de marche) ; temoin du
    # plafond : reference decalee a la premiere passe, puis son zero estime tant qu il n est pas resolu. Valeurs ecrites
    # bornees a la borne absolue CalHardNs (le temoin d une reference plafonnee a 300 ns peut etre ecrit au-dela)
    $max = [int]$script:CalHardNs
    $t = @{}
    foreach ($c in @(@($u.LCyls) + @($u.Wit))) { $t[[int]$c] = [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.V[[int]$c] + $u.D))) }
    if ($null -ne $u.Probe -and -not $u.ProbeDone) {
        $p = [int]$u.Probe
        $t[$p] = if ($null -ne $u.ProbeZ) { [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.ProbeZ))) } else { [int][math]::Max(0, [math]::Min($max, [math]::Round([double]$u.V[$p] + $u.D))) }
    }
    $u.LTarget = $t
}

function Get-LevelEstimate($u, [int]$pass) {
    # Niveau estime (ecart entre zero mesure et reference, moyenne ponderee avec plancher tau0), ecart de forme, residu
    # moyen de la passe ecrite, temoins ; cibles a 0 ou a la borne CalHardNs (ecretees) hors pente et residu
    $max = [double]$script:CalHardNs
    $k = [double]$u.KRef; $kRaw = $null
    $kSpan = 0.0
    if ($pass -ge 2) {
        $sl = @(); $spans = @()
        foreach ($c in @($u.LCyls)) {
            $pts = $u.Results[[int]$c]; if (-not $pts) { continue }
            $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 0 -and $_ -lt $max } | Sort-Object)
            if ($xs.Count -lt 2 -or ($xs[-1] - $xs[0]) -lt 4) { continue }
            $sl += ([double]$pts[$xs[-1]].Shift - [double]$pts[$xs[0]].Shift) / ($xs[-1] - $xs[0]); $spans += ($xs[-1] - $xs[0])
        }
        if ($sl.Count -gt 0) { $kSpan = [double](Get-Median $spans); $kRaw = [double](Get-Median $sl); if ($kRaw -lt -0.2) { $k = [math]::Max($script:LevelKMin, [math]::Min(3.0, -$kRaw)) } }
    }
    $ds = @{}; $sg = @{}; $kinds = @{}; $capped = @(); $floored = @()
    foreach ($c in @($u.LCyls)) {
        $z = Get-LevelZero $u.Results[[int]$c] $k
        if (-not $z) { continue }
        # Zero borne : a la borne CalHardNs (besoin au-dela) ou au plancher de 0 ns (precompensation nulle encore excessive)
        if ($z.Kind -eq 'cap') { if ([double]$z.Est -le 0) { $floored += [int]$c } else { $capped += [int]$c }; $kinds[[int]$c] = 'cap'; continue }
        $ds[[int]$c] = [double]$z.Est - [double]$u.V[[int]$c]; $sg[[int]$c] = [double]$z.Sig; $kinds[[int]$c] = [string]$z.Kind
    }
    # 12.8 (lot 1c) : partie statistique commune avec Get-LevelKrefEstimate (Get-LevelStats, calcul inchange)
    $st = Get-LevelStats $ds $sg
    $keep = $st.Keep; $n = $st.N
    $e = @{ N = $n; K = $k; KRaw = $kRaw; KSpan = $kSpan; Ds = $ds; Sigs = $sg; Kinds = $kinds; Capped = $capped; Floored = $floored; Outliers = $st.Outliers; Scatter = $st.Scatter; Keep = $keep; W = $st.W
            Delta = $st.Delta; SE = $st.SE; Tau = $st.Tau; Rbar = [double]::NaN; RTol = [double]$script:CalResidual * [math]::Min(1.0, $k / 2.0); Wit = @{}; ProbeZ = $null; ProbeKind = '' }
    if ($n -ge 1) {
        $rs = @()
        foreach ($c in $keep) {
            $tg = [int]$u.LTarget[[int]$c]
            if ($tg -le 0 -or $tg -ge [int]$max) { continue }
            $pt = $u.Results[[int]$c][$tg]; if ($pt) { $rs += [double]$pt.Shift }
        }
        if ($rs.Count -gt 0) {
            $mr = ($rs | Measure-Object -Average).Average; $e.Rbar = [double]$mr
            if ($rs.Count -ge 2) {
                $sd = [math]::Sqrt((@($rs | ForEach-Object { [math]::Pow($_ - $mr, 2) }) | Measure-Object -Sum).Sum / ($rs.Count - 1))
                $e.RTol = [math]::Max([double]$script:CalResidual * [math]::Min(1.0, $k / 2.0), 2.0 * $sd / [math]::Sqrt($rs.Count))
            }
        }
    }
    foreach ($c in @($u.Wit)) {
        $z = Get-LevelZero $u.Results[[int]$c] $k
        if ($z -and $z.Kind -ne 'cap') { $e.Wit[[int]$c] = @{ D = [double]$z.Est - [double]$u.V[[int]$c]; Sig = [double]$z.Sig; Z = [double]$z.Est } }
    }
    if ($null -ne $u.Probe) {
        $z = Get-LevelZero $u.Results[[int]$u.Probe] $k
        if ($z) { $e.ProbeZ = [double]$z.Est; $e.ProbeKind = [string]$z.Kind }
    }
    return $e
}

function Get-LevelStats($ds, $sg) {
    # Partie statistique de Get-LevelEstimate : poids avec plancher tau0 (LevelShapeFloor), ecart isole ou dispersion
    # (mediane ponderee), niveau, erreur-type, ecart de forme tau. 12.8 (lot 1c) : aussi pour Get-LevelKrefEstimate
    $cs = @($ds.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $t0 = [math]::Pow([double]$script:LevelShapeFloor, 2)
    $w = @{}; foreach ($c in $cs) { $w[$c] = 1.0 / ([math]::Pow($sg[$c], 2) + $t0) }
    $outl = @(); $scatter = 0
    if ($cs.Count -ge 1) {
        $m = Get-WeightedMedian ([double[]]@($cs | ForEach-Object { $ds[$_] })) ([double[]]@($cs | ForEach-Object { $w[$_] }))
        $iso = @($cs | Where-Object { [math]::Abs($ds[$_] - $m) -gt [math]::Max(15.0, 4.0 * $sg[$_]) })
        if ($iso.Count -eq 1 -and $cs.Count -ge 5) { $outl = $iso } elseif ($iso.Count -ge 2) { $scatter = $iso.Count }
    }
    $keep = @($cs | Where-Object { $outl -notcontains $_ })
    $n = $keep.Count
    $st = @{ N = $n; Ds = $ds; Sigs = $sg; Outliers = $outl; Scatter = $scatter; Keep = $keep; W = $w; Delta = [double]::NaN; SE = [double]::NaN; Tau = 0.0 }
    if ($n -ge 1) {
        $sw = 0.0; $swd = 0.0; foreach ($c in $keep) { $sw += $w[$c]; $swd += $w[$c] * $ds[$c] }
        $dh = $swd / $sw; $st.Delta = $dh
        if ($n -ge 2) {
            $chi = 0.0; $ss = 0.0; $ms = 0.0
            foreach ($c in $keep) { $chi += $w[$c] * [math]::Pow($ds[$c] - $dh, 2); $ss += [math]::Pow($ds[$c] - $dh, 2); $ms += [math]::Pow($sg[$c], 2) }
            $st.SE = [math]::Sqrt(1.0 / $sw) * [math]::Sqrt([math]::Max(1.0, $chi / ($n - 1)))
            $st.Tau = [math]::Sqrt([math]::Max(0.0, $ss / ($n - 1) - $ms / $n))
        } else { $st.SE = [math]::Sqrt(1.0 / $sw) }
    }
    return $st
}

function Test-LevelShape($e, $u, [double]$f = 1.0) {
    # Forme de la disquette comparee a la reference : dispersion, ecart de forme, inclinaison radiale, hauteur de marche,
    # temoins de marche. f = 2 : seuils doubles (bascule anticipee apres la premiere passe).
    $reasons = @(); $tilt = $null; $step = $null
    if ($e.Scatter -ge 2) { $reasons += ((T "écarts dispersés ({0} cylindres hors de la forme)") -f "$($e.Scatter)") }
    if ($e.Tau -gt $script:LevelTauMax * $f) { $reasons += ((T "écart de forme {0} ns") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1))) }
    $keep = @($e.Keep); $w = $e.W; $ds = $e.Ds
    $maxC = [math]::Max(1, @($u.V).Count - 1)
    if ($keep.Count -ge 4) {
        $us = @{}; foreach ($c in $keep) { $us[$c] = [double]$c / $maxC }
        $uv = @($keep | ForEach-Object { $us[$_] })
        $range = ($uv | Measure-Object -Maximum).Maximum - ($uv | Measure-Object -Minimum).Minimum
        if ($range -ge 0.5) {
            $sw = 0.0; $su = 0.0; $sd = 0.0; foreach ($c in $keep) { $sw += $w[$c]; $su += $w[$c] * $us[$c]; $sd += $w[$c] * $ds[$c] }
            $ub = $su / $sw; $db = $sd / $sw
            $suu = 0.0; $sud = 0.0; foreach ($c in $keep) { $suu += $w[$c] * [math]::Pow($us[$c] - $ub, 2); $sud += $w[$c] * ($us[$c] - $ub) * ($ds[$c] - $db) }
            if ($suu -gt 0) {
                $b = $sud / $suu
                $chi = 0.0; foreach ($c in $keep) { $chi += $w[$c] * [math]::Pow($ds[$c] - ($db + $b * ($us[$c] - $ub)), 2) }
                $tilt = $b * $range
                $seT = [math]::Sqrt([math]::Max(1.0, $chi / [math]::Max(1, $keep.Count - 2)) / $suu) * $range
                if ([math]::Abs($tilt) -gt [math]::Max(15.0 * $f, 3.0 * $seT)) {
                    $c1 = ($keep | Measure-Object -Minimum).Minimum; $c2 = ($keep | Measure-Object -Maximum).Maximum
                    $reasons += ((T "le niveau varie avec le cylindre ({0} ns de c{1} à c{2})") -f ('{0:+0;-0;0}' -f [math]::Round($tilt, 0)), "$c1", "$c2")
                }
            }
        }
    }
    $brk = @(@($u.Cv.Breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    if ($brk.Count -ge 1) {
        $pk = $brk[0]
        $l = @($keep | Where-Object { $_ -le $pk }); $r = @($keep | Where-Object { $_ -gt $pk })
        if ($l.Count -ge 2 -and $r.Count -ge 2) {
            $wl = 0.0; $dl = 0.0; foreach ($c in $l) { $wl += $w[$c]; $dl += $w[$c] * $ds[$c] }
            $wr = 0.0; $dr = 0.0; foreach ($c in $r) { $wr += $w[$c]; $dr += $w[$c] * $ds[$c] }
            $step = $dr / $wr - $dl / $wl
            $seS = [math]::Sqrt(1.0 / $wl + 1.0 / $wr)
            if ([math]::Abs($step) -gt [math]::Max(15.0 * $f, 3.0 * $seS)) { $reasons += ((T "la marche de c{0} n'a pas la même hauteur ({1} ns d'écart de part et d'autre)") -f "$pk", ('{0:+0;-0;0}' -f [math]::Round($step, 0))) }
        }
    }
    if (@($u.Wit).Count -eq 2 -and -not [double]::IsNaN([double]$e.Delta)) {
        foreach ($c in @($u.Wit)) {
            $wz = $e.Wit[[int]$c]; if (-not $wz) { continue }
            if ([math]::Abs($wz.D - $e.Delta) -gt [math]::Max(15.0 * $f, 4.0 * $wz.Sig)) { $reasons += ((T "marche déplacée ou absente entre c{0} et c{1} (autre lecteur sous la même lettre ?)") -f "$($u.Wit[0])", "$($u.Wit[1])"); break }
        }
    }
    $verdict = if ($reasons.Count -gt 0) { 'mismatch' } elseif ($e.Tau -gt $script:LevelTauOk) { 'approx' } else { 'ok' }
    return @{ Verdict = $verdict; Reasons = $reasons; Tilt = $tilt; Step = $step }
}

function Build-LevelValues($u, [int]$d, $e, [int]$Hard = 0) {
    # Courbe appliquee : reference + niveau, bornee a 0..CalHardNs. Valeur de reference a la borne de SON calcul
    # (Get-CurveMaxNs : 300 ns avant le calcul 12.4) : borne basse du besoin, relevee d un niveau positif, jamais abaissee.
    # Zone plafonnee terminale de la reference (CapLo au temoin du plafond) :
    #  - temoin resolu (zero encadre ou extrapole, au plus CalHardNs) : zone interpolee lineairement jusqu a ce zero ;
    #  - temoin plafonne (besoin au-dela de CalHardNs) : zone portee jusqu a CalHardNs, jamais sous la reference relevee
    #    du niveau ; temoin compte dans Sat (reserve, fenetre de decision) ;
    #  - temoin non resolu, ou zero au plancher (invraisemblable a la borne) : regle generale ci-dessus.
    # Noms distincts de la reference ($ref) et de sa valeur ($rv) : PowerShell ignore la casse ($V et $v seraient une
    # seule variable)
    # 12.8 (F3R, decision 2) : Hard (> 0) : plafond des valeurs et de Sat (courbe de la forme d une marque dont le besoin
    # depasse CalHardNs : jusqu a CalHardMaxNs) ; Clip reste decide contre CalHardNs (un reglage, pas un besoin), et la zone
    # du temoin du plafond reste a CalHardNs (G6). RawMax : besoin le plus fort hors Clip (reference ou V' + niveau)
    $base = [int]$script:CalHardNs; $max = if ($Hard -gt 0) { $Hard } else { $base }
    $rmax = Get-CurveMaxNs $u.Cv; $ref = @($u.V); $n = $ref.Count
    # 12.8 (FIX1C, constat 4) : Clip decide sur la reference du lecteur (V0) ; avec le point de depart d une marque (V'),
    # une valeur de V' au-dela de la borne est un besoin de cette disquette : Sat (reserve « plafond »), jamais Clip
    $ref0 = if ($null -ne $u.V0 -and @($u.V0).Count -eq $n) { @($u.V0) } else { $ref }
    $out = New-Object int[] $n; $sat = @(); $floor = @(); $clip = @(); $rawMax = $null
    for ($c = 0; $c -lt $n; $c++) {
        $rv = [int]$ref[$c]
        # Reference au-dela de la borne actuelle (courbe calculee avec une borne plus haute) : ecretee a la borne, niveau
        # applique, sans Sat (la borne est un reglage, pas un besoin de cette disquette)
        if ([int]$ref0[$c] -gt $base) {
            $raw = if ($rv -ge $rmax) { $rv + [math]::Max(0, $d) } else { $rv + $d }
            # 12.8 (F3R-FIX, constat 1) : plafond porte au-dela de CalHardNs par le besoin d un autre cylindre (Hard) : ce
            # cylindre suit le plafond (Sat au-dela), sans entrer dans RawMax (il ne declenche rien)
            if ($max -gt $base) {
                if ($raw -gt $max) { $sat += $c }
                $out[$c] = [int][math]::Max(0, [math]::Min($max, $raw)); continue
            }
            if ($raw -gt $base) { $clip += $c }
            $out[$c] = [int][math]::Max(0, [math]::Min($base, $raw)); continue
        }
        if ($rv -ge $rmax) {
            $raw = $rv + [math]::Max(0, $d)
            if ($null -eq $rawMax -or $raw -gt $rawMax) { $rawMax = $raw }
            if ($raw -gt $max) { $sat += $c }
            $out[$c] = [int][math]::Min($max, $raw); continue
        }
        if ($rv -le 0) { $out[$c] = 0; continue }
        $raw = $rv + $d
        if ($null -eq $rawMax -or $raw -gt $rawMax) { $rawMax = $raw }
        if ($raw -gt $max) { $sat += $c } elseif ($raw -lt 0) { $floor += $c }
        $out[$c] = [int][math]::Max(0, [math]::Min($max, $raw))
    }
    $note = $null
    if ($null -ne $u.Probe -and [int]$u.CapLo -ge 1 -and [int]$u.CapLo -lt $n -and [int]$u.Probe -ge [int]$u.CapLo -and $e) {
        $p = [int]$u.Probe; $lo = [int]$u.CapLo; $y1 = $null
        if ($null -eq $e.ProbeZ -or ($e.ProbeKind -ne 'cap' -and -not $u.ProbeDone)) { $note = 'unresolved' }
        elseif ($e.ProbeKind -eq 'cap' -and [double]$e.ProbeZ -le 0) { $note = 'unresolved' }
        elseif ($e.ProbeKind -eq 'cap') { $note = 'cap'; $y1 = [double]$base }
        else { $note = 'interp'; $y1 = [double]$e.ProbeZ }
        if ($null -ne $y1) {
            # Zone recalculee : interpolation depuis le dernier cylindre hors zone ; au-dela du temoin (reference plus longue
            # que l image), valeur du temoin
            $y0 = [double]$out[$lo - 1]
            $sat = @($sat | Where-Object { $_ -lt $lo }); $clip = @($clip | Where-Object { $_ -lt $lo })
            for ($c = $lo; $c -lt $n; $c++) {
                $tt = [math]::Min(1.0, ($c - ($lo - 1)) / [double]($p - ($lo - 1)))
                $raw = [math]::Round($y0 + $tt * ($y1 - $y0))
                if ($note -eq 'cap') {
                    $lb = [double]$ref[$c] + [math]::Max(0, $d)
                    if ([double]$ref0[$c] -gt $base) { $clip += $c } elseif ($c -eq $p -or $lb -gt $base) { $sat += $c }
                    $raw = [math]::Max($raw, [math]::Min([double]$base, $lb))
                }
                $out[$c] = [int][math]::Max(0, [math]::Min($base, $raw))
            }
        }
    }
    return @{ Values = $out; Sat = $sat; Floor = $floor; ProbeNote = $note; Clip = $clip; RawMax = $rawMax; Hard = $max }
}

function New-LevelCalUnits($lr, [string]$brand, [string]$drive) {
    # Unites de la calibration rapide (Start-LevelCalib ; suite calib-lvl2, sans interface) : une par tete ou une pour la
    # courbe commune, cibles de la premiere passe. 12.8 (lot 1c) : etat de la calibration rapide adaptative ; V0 :
    # reference du lecteur (ShapeV), V : reference ou point de depart de la marque (V', Set-LevelBrandStart) ; cylindres
    # de controle (ecriture lente) choisis sur la reference du lecteur (V0, FIX1C), les memes que ceux de l avertissement
    $units = @()
    $slow = ($null -ne @($lr.Units)[0].Head)
    foreach ($lu in @($lr.Units)) {
        $u = New-CalibUnit $lu.Head
        foreach ($key in 'RefKey', 'Tag', 'Cv', 'V', 'KRef', 'LCyls', 'Wit', 'Probe', 'CapLo', 'D0', 'NHist') { $u[$key] = $lu[$key] }
        $u.D = [int]$lu.D0; $u.LTarget = @{}; $u.Done = $false; $u.Conv = $false; $u.Fail = ''; $u.Early = $false; $u.Sat = $false; $u.Low = $false; $u.Few = $false; $u.ProbeOnly = $false
        $u.Level = $null; $u.Passes = 0; $u.ProbeDone = $false; $u.ProbeZ = $null; $u.Est = $null; $u.Shape = $null
        $u.Mode = 'lvl1'; $u.Raw = @{}; $u.V0 = [int[]]@($lu.V); $u.Memo = $null; $u.BrandEntry = $null; $u.AN = $null; $u.AV = $null; $u.VR = $null
        $u.Named = @{}; $u.Refus = ''; $u.Trig = $null; $u.Note = ''; $u.AdaptNote = ''; $u.AdaptLog = $null; $u.Ctl = [int[]]@()
        # 12.8 (F3R) : controles integres a l ajustement par une reprise e3 (CtlFit), reserve de controle e2 (motif, controles)
        $u.CtlFit = [int[]]@(); $u.CtlReserve = ''; $u.CtlBad = @()
        Set-LevelBrandStart @{ Drive = $drive; Family = [string]$lr.Family } $u $brand
        $u.ShapeV = New-LevelShape $u.V0
        foreach ($c in @(@($u.LCyls) + @($u.Wit) + @($(if ($null -ne $u.Probe) { $u.Probe })))) { $u.Results[[int]$c] = @{} }
        Set-LevelTargets $u
        $units += ,$u
    }
    if ($slow) {
        $ctl = Get-LevelCtlCyls $units ([int]$lr.MaxCyl)
        foreach ($u in $units) { $u.Ctl = $ctl; foreach ($x in $ctl) { if (-not $u.Results.ContainsKey([int]$x)) { $u.Results[[int]$x] = @{} } } }
    }
    return ,$units
}

function Start-LevelCalib($lr, [switch]$NoConfirm, [switch]$NoFallback, $Geom = $null) {
    # Calibration rapide : avertissement (sauf NoConfirm), motif, unites, premiere passe. Geom : type de disquette de la
    # carte Calibration de l Accueil (image de geometrie, Start-HomeCalib) a la place de l image de l onglet Ecriture
    # 12.8 (S3) : $script:LevelNoBrand (garde de la passe 1, W-M2 : « Calibration rapide sur la reference ») : lu et remis a
    # $false ici, avant toute sortie ; aucune marque, meme sans avertissement (signature inchangee : enveloppes de make-test)
    $noBrand = [bool]$script:LevelNoBrand; $script:LevelNoBrand = $false
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    $script:LevelPostForce = $false
    $chk = Test-CalibImage $Geom
    if (-not $chk) { return }
    $img = $chk.Img; $fam = $lr.Family
    $toWrite = ($script:AfterCalib -eq 'write')
    $target = if ($script:Restore) { (T 'la disquette de destination') } else { (T 'la disquette à écrire') }
    $units0 = @($lr.Units)
    $slow = ($null -ne $units0[0].Head)
    $all = @{}
    $sets = @()
    foreach ($lu in $units0) {
        $one = @(@(@($lu.LCyls) + @($lu.Wit) + @($(if ($null -ne $lu.Probe) { $lu.Probe }))) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        foreach ($c in $one) { $all[[int]$c] = $true }
        $sets += (Format-CylList ([int[]]$one))
    }
    $cyls = [int[]]@($all.Keys | Sort-Object)
    $cylTxt = if (@($sets | Sort-Object -Unique).Count -le 1) { $sets[0] } else { ((@(0..($units0.Count - 1) | ForEach-Object { (T "tête {0} : {1}") -f "$($units0[$_].Head)", "$($sets[$_])" })) -join ' ; ') }
    # 12.8 (lot 1c) : cylindres de controle de la calibration rapide adaptative (ecriture lente, une courbe par tete ; la
    # courbe commune n est pas adaptee, G6), choisis sous le dernier cylindre de l image
    $ctl0 = if ($slow) { Get-LevelCtlCyls $units0 ([int]$lr.MaxCyl) } else { [int[]]@() }
    $ctlTxt = if ($ctl0.Count -gt 0) { Format-CylList $ctl0 } else { '-' }
    $ref0 = $units0[0].Cv
    $testTxt = if ([string]$ref0.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
    # Calibration rapide avant une ecriture lente : prechauffage du lecteur avant la mesure du niveau (case « Prechauffer le
    # lecteur ») ; duree comprise dans l estimation (borne haute : reduit ou saute si le lecteur vient de servir)
    $warm = ($toWrite -and $chkWSlow.Checked -and $chkWWarm.Checked)
    $wu = if ($warm) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    # 12.8 (lot 1c) : 2 passes en general, 3 passes avec 2 cylindres de controle de plus quand la forme est adaptee
    $minLo = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * 2 / 60 + $wu, 0))
    $minHi = [math]::Max($minLo, [math]::Round(($cyls.Count + $ctl0.Count) * 2 * 1.4 * 3 / 60 + $wu, 0))
    $minutes = if ($slow -and $minHi -gt $minLo) { (T '{0} à {1}') -f "$minLo", "$minHi" } else { "$minLo" }
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    $ans = $null                        # 12.7 : jamais celle d un appelant (portee dynamique)
    $brand = ''
    if (-not $NoConfirm) {
        $intro = if ($toWrite) { ((T "Calibration rapide avant l'écriture : {0} reçoit le motif de test sur ces seuls cylindres, au plus 3 fois, puis l'image.") -f "$target") + "`n`n" } else { '' }
        # 12.8 (lot 1c) : courbe commune (ecriture rapide) : seul le niveau est mesure (G6), textes de la 12.7
        $bodyFmt = if (-not $slow -and $Geom) { (T "Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nType de disquette : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min.") }
                   elseif (-not $slow) { (T "Calibration rapide de la précompensation sur le lecteur {0} : seul le niveau de la courbe est mesuré, sur la disquette insérée.`n`nRéférence : calibration complète du {1} ({2}), dont la forme est reprise telle quelle.`nImage : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe ; 1 à 3 passes, 2 en général. Durée estimée : {6} min.") }
                   elseif ($Geom) { (T "Calibration rapide de la précompensation sur le lecteur {0} : le niveau de la courbe est mesuré sur la disquette insérée, et sa forme aussi si elle diffère de la référence.`n`nRéférence : calibration complète du {1} ({2}) ; sa forme est reprise, puis adaptée à cette disquette si la mesure le demande.`nType de disquette : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe, plus 2 cylindres de contrôle ({7}) si la forme est adaptée ; 1 à 3 passes, 2 en général, 3 quand la forme est adaptée. Durée estimée : {6} min.") }
                   else { (T "Calibration rapide de la précompensation sur le lecteur {0} : le niveau de la courbe est mesuré sur la disquette insérée, et sa forme aussi si elle diffère de la référence.`n`nRéférence : calibration complète du {1} ({2}) ; sa forme est reprise, puis adaptée à cette disquette si la mesure le demande.`nImage : {3}, famille {4}.`nCylindres mesurés : {5} (2 faces), ÉCRASÉS à chaque passe, plus 2 cylindres de contrôle ({7}) si la forme est adaptée ; 1 à 3 passes, 2 en général, 3 quand la forme est adaptée. Durée estimée : {6} min.") }
        $body = $bodyFmt -f "$($cmbDrive.Text)", "$($ref0.Date)", "$testTxt", "$($chk.Label)", (Get-CalibFamilyName $fam), "$cylTxt", "$minutes", "$ctlTxt"
        if ($wu -gt 0) { $body += "`n" + ((T "Préchauffage du lecteur avant la mesure du niveau : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée.") -f (Format-CalDuration (60 * $wu))) }
        $tail = if ($toWrite) { (T "Le niveau dépend du support : il doit être mesuré sur la disquette qui recevra l'image. N'insérez pas de disquette sacrifiée. Une calibration complète écrit le motif 4 à 8 fois sur ses cylindres de test ; la calibration rapide, 3 fois au plus.") }
                elseif ($Geom) { (T "Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle ; il est placé dans les champs --precomp de l'onglet Écriture si son image est de la même famille.") }
                else { (T "Aucune image n'est écrite. Insérez la disquette que vous allez écrire : le profil obtenu est placé dans les champs --precomp et ne vaut que pour elle.") }
        # 12.8 (lot 1c, § 10.1) : marque de la disquette inseree (champ libre, derniere marque choisie par defaut), ecriture
        # lente seulement (la courbe commune n est pas adaptee)
        $bi = $null
        if ($slow) {
            $bi = Get-LevelBrandItems ([string]$cmbDrive.Text) $units0 $fam
            $bi.Label = (T 'Marque de la disquette insérée :'); $bi.Text = [string]$script:LevelBrand
            $bi.Tip = (T "Nom libre : marque, année ou lot. Une marque déjà mesurée sert de point de départ : sa forme et son niveau, mémorisés avec la référence actuelle du lecteur. La mesure reste faite sur la disquette insérée.")
        }
        $ans = Show-CalibConfirm ($intro + $body + "`n`n" + $tail) '' $bi
        if (-not $ans.Ok) { return }
        if ($ans.Auto) { Append-Log ((T "Calibration : avertissement validé automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
        if ($bi) { $brand = Get-LevelBrandName ([string]$ans.Brand) $bi.Map; $script:LevelBrand = $brand }
    } elseif ($slow -and -not $noBrand) {
        # Mesure apres une calibration sur disquette sacrifiee (sans avertissement) : derniere marque choisie
        $brand = [string]$script:LevelBrand
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    try { $pat = New-CalibPattern $fam $img $lr.NCyl }
    catch { [void](Show-AppMessage ((T "Calibration : motif de test impossible à créer : {0}") -f "$($_.Exception.Message)") (T 'Calibration precomp') 'OK' 'Error'); return }
    Set-CalibScale $fam     # 12.7 : bareme double densite (pas de calibration rapide en haute densite, Get-LevelRef)
    $units = New-LevelCalUnits $lr $brand ([string]$cmbDrive.Text)
    $cylList = Format-CylList $cyls
    $script:Cal = @{
        Mode = 'level'; Stage = 'level'; LPass = 1; Cyls = $cyls; MaxCyl = $lr.MaxCyl; Family = $fam; Slow = $slow
        Image = $img; Pattern = $pat.Path; PatternBits = $pat.Bits; MaxCoarse = 0; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        Values = @(); Index = 0; Value = 0; ValueTxt = ''; Spec = ''; Units = $units; VerifyCount = 0; Swap = $false; LevelAfter = $false
        CanFallback = ($toWrite -and -not $NoFallback -and -not $script:Restore); Notes = @($lr.Notes)
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = 2; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; TrackWrites = 0
        # Carte Calibration de l Accueil (progression sur la carte). 12.8 (S3-FLUX) : Geom.NoHome (geometrie de la copie de flux
        # mesuree en restauration, F3R) retire avec cette mesure
        Home = [bool]$Geom; Geom = $Geom
        # 12.7 point 5 : controle de surface de la premiere passe (Invoke-LevelSurface)
        AutoStart = [bool]($ans -and $ans.Auto); SurfDone = $false; Surf = $null; Medium = $null; SurfGross = $false; SurfKept = $false; Hold = $false
        # 12.8 (lot 1c) : marque de la disquette inseree (§ 10)
        Brand = $brand
        # 12.8 (S3) : reference de cette calibration (mesure complete de cette disquette, W-M1 et W-M2) ; mesure complete
        # proposee avant une ecriture, hors restauration
        Lr = $lr; CanDisk = [bool]($toWrite -and -not $script:Restore)
    }
    $kind = if ($slow -and $units[0].RefKey -eq $units[1].RefKey) { (T 'forme commune, niveau mesuré par tête') } elseif ($slow) { (T 'une courbe par tête') } else { (T 'courbe commune') }
    $lf = if ($Geom) { (T "=== Calibration rapide : lecteur {0}, type {1} ({2}, {3}) ===") } else { (T "=== Calibration rapide : lecteur {0}, image {1} ({2}, {3}) ===") }
    Append-Log ($lf -f "$($cmbDrive.Text)", "$($chk.Label)", (Get-CalibFamilyName $fam), "$kind")
    if ($brand) { Append-Log $(if ($NoConfirm) { (T 'Marque de la disquette insérée : « {0} » (dernière marque choisie).') -f "$brand" } else { (T 'Marque de la disquette insérée : « {0} ».') -f "$brand" }) }
    foreach ($u in $units) {
        $tt = if ([string]$u.Cv.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
        Append-Log ((T "{0}Référence de forme : calibration complète ({1}) du {2}, lecteur {3} ; cylindres de niveau : {4}.") -f "$($u.Prefix)", "$tt", "$($u.Cv.Date)", "$($u.Cv.Drive)", (Format-CylList ([int[]]@($u.LCyls))))
        if (@($u.Wit).Count -eq 2) { Append-Log ((T "{0}Témoins de marche : c{1} et c{2} (contrôle de la forme, hors calcul du niveau).") -f "$($u.Prefix)", "$($u.Wit[0])", "$($u.Wit[1])") }
        if ($null -ne $u.Probe) { Append-Log ((T "{0}Témoin du plafond : c{1} (référence au plafond de {3} ns de son calcul, de c{2} à c{1}).") -f "$($u.Prefix)", "$($u.Probe)", "$($u.CapLo)", "$(Get-CurveMaxNs $u.Cv)") }
        if ($u.Memo -and $u.Memo.Curve) {
            # 12.8 (S3) : courbe complete de la marque (mesure complete d une disquette de cette marque)
            $mm = $u.Memo
            Append-Log ((T '{0}Point de départ : courbe complète mémorisée pour la marque « {1} » le {2} (niveau {3} ns ; {4} mesure(s), dernière le {5}).') -f "$($u.Prefix)", "$($mm.Brand)", "$($mm.CurveDate)", (Format-LevelSigned $mm.A), "$($mm.N)", "$($mm.LastDate)")
        }
        elseif ($u.Memo) {
            $mm = $u.Memo
            Append-Log ((T '{0}Point de départ : forme mémorisée pour la marque « {1} » (niveau {2} ns, échelle {3} %, pente {4} ns de c0 à c{5} ; {6} mesure(s), dernière le {7}).') -f "$($u.Prefix)", "$($mm.Brand)", (Format-LevelSigned $mm.A), (Format-UiNum ([math]::Round(100 * [double]$mm.S, 1)) '+0.0;-0.0;0.0'), (Format-LevelSigned $mm.B), "$(@($u.V0).Count - 1)", "$($mm.N)", "$($mm.LastDate)")
        }
        if ($u.D0 -ne 0 -and -not $u.Memo) { Append-Log ((T "{0}Niveau de départ : {1} ns (médiane de la référence et des {2} derniers niveaux mesurés avec elle).") -f "$($u.Prefix)", ('{0:+0;-0;0}' -f $u.D0), "$($u.NHist)") }
    }
    Append-Log (T 'Cylindres de niveau choisis parmi les cylindres mesurés et vérifiés de la référence ; exclus : cylindres 0 et 1, changements de sens et leurs voisins, pentes raides, valeurs hors de 20 à 260 ns, points isolés ou hors tolérance.')
    foreach ($nt in @($lr.Notes)) { Append-Log $nt }
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    # Avant une ecriture lente : prechauffage de l ecriture fait ici, avant la mesure du niveau, pour que le niveau soit
    # mesure dans l etat du lecteur ou l image sera ecrite (Start-CalibWarmup, retour a l etape 'level') ; seule ou avant
    # une ecriture rapide : aucun prechauffage
    if ($warm) { Start-CalibWarmup } else { New-CalibPass }
}

function Invoke-LevelDecide($cal, $u, $e, [int]$p, $J) {
    # Decision 12.7 d Invoke-LevelStep pour une unite apres l estimation $e de la passe p (arret : niveau verifie, echec,
    # bascule anticipee, dernier essai ; sinon cibles de la passe suivante). 12.8 (lot 1c) : lignes du journal ajoutees a
    # $J (@{ Est ; Text }), ecrites par l appelant ; renvoie le motif : nomeas, nowrite, few, verifie, probe (niveau
    # verifie, passe du seul temoin du plafond), repli, max_passes, stable ou next
    if ($e.N + @($e.Capped).Count + @($e.Floored).Count -lt 3) { $u.Fail = 'nomeas'; $u.Done = $true; return 'nomeas' }
    if ($null -ne $u.Head -and $p -ge 2 -and $null -ne $e.KRaw -and $e.KRaw -ge [math]::Max(-0.2, -0.5 * [double]$u.KRef) -and [double]$u.KRef * [double]$e.KSpan -ge 4.0) { $u.Fail = 'nowrite'; $u.Done = $true; return 'nowrite' }
    if ($e.N -lt 3) {
        $nm = $e.N + @($e.Capped).Count + @($e.Floored).Count
        if (2 * @($e.Floored).Count -gt $nm) { $u.Low = $true } elseif (2 * @($e.Capped).Count -gt $nm) { $u.Sat = $true } else { $u.Few = $true }
        $u.Level = if ($e.N -ge 1 -and -not [double]::IsNaN([double]$e.Delta)) { [int][math]::Round([double]$e.Delta) } else { [int]$u.D }
        $u.Conv = $false; $u.Done = $true; return 'few'
    }
    $dh = [double]$e.Delta
    $dv = @($e.Keep | ForEach-Object { $e.Ds[$_] })
    $J.Add(@{ Est = $true; Text = ($u.Prefix + ((T "Niveau estimé : {0} ns ± {1} ({2} cylindres ; écarts à la forme de {3} à {4} ns ; écart de forme {5} ns).") -f ('{0:+0.0;-0.0;0.0}' -f $dh), ('{0:0.#}' -f [math]::Round($e.SE, 1)), "$($e.N)", ('{0:+0.0;-0.0;0.0}' -f (($dv | Measure-Object -Minimum).Minimum - $dh)), ('{0:+0.0;-0.0;0.0}' -f (($dv | Measure-Object -Maximum).Maximum - $dh)), ('{0:0.#}' -f [math]::Round($e.Tau, 1)))) })
    if (-not [double]::IsNaN([double]$e.Rbar) -and [math]::Abs($e.Rbar) -le $e.RTol) {
        $u.Level = [int]$u.D; $u.Conv = $true
        $J.Add(@{ Est = $false; Text = ($u.Prefix + ((T "Niveau vérifié à la passe {0} : décalage résiduel moyen {1} ns (tolérance {2}) : niveau retenu {3} ns.") -f "$p", ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $u.Level))) })
        if ($null -ne $u.Probe -and -not $u.ProbeDone -and $null -ne $u.ProbeZ -and $p -lt $script:LevelMaxPasses) {
            # Temoin du plafond non resolu : une passe de plus sur ce seul cylindre, ecrit a son zero estime
            $u.ProbeOnly = $true
            $u.LTarget = @{ ([int]$u.Probe) = [int][math]::Max(0, [math]::Min([int]$script:CalHardNs, [math]::Round([double]$u.ProbeZ))) }
            return 'probe'
        }
        $u.Done = $true
        return 'verifie'
    }
    if ($p -eq 1 -and $cal.CanFallback -and (Test-LevelShape $e $u 2.0).Verdict -eq 'mismatch') { $u.Level = [int][math]::Round($dh); $u.Conv = $false; $u.Early = $true; $u.Done = $true; return 'repli' }
    if ($p -ge $script:LevelMaxPasses) {
        $u.Level = [int][math]::Round($dh); $u.Conv = $false; $u.Done = $true
        $J.Add(@{ Est = $false; Text = ($u.Prefix + ((T "Niveau non vérifié après {0} passes (décalage résiduel moyen {1} ns, tolérance {2}) : niveau estimé {3} ns retenu.") -f "$p", ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $u.Level))) })
        return 'max_passes'
    }
    $dn = [int][math]::Round($dh)
    $mv = [math]::Max([int]$script:LevelMinMove, [int][math]::Ceiling(4.0 / [double]$u.KRef))
    if ($p -eq 1 -and [math]::Abs($dn - $u.D) -lt $mv) {
        $sg = [math]::Sign($dh - $u.D); if ($sg -eq 0) { $sg = $(if ($e.Rbar -gt 0) { 1 } else { -1 }) }
        $dn = [int]$u.D + $mv * $sg
    }
    if ($dn -eq $u.D) {
        # [1] Estimation stable mais residu hors tolerance (ou non mesure) : niveau garde, non verifie
        $u.Level = [int]$u.D; $u.Conv = $false; $u.Done = $true
        $J.Add(@{ Est = $false; Text = ($u.Prefix + ((T "Niveau stable mais non vérifié à la passe {0} (décalage résiduel moyen {1} ns, tolérance {2}) : niveau {3} ns retenu.") -f "$p", (Format-LevelNum $e.Rbar), (Format-LevelNum $e.RTol), ('{0:+0;-0;0}' -f $u.Level))) })
        return 'stable'
    }
    $J.Add(@{ Est = $false; Text = ($u.Prefix + ((T "Niveau hors tolérance (décalage résiduel moyen {0} ns, tolérance {1}) : passe suivante à {2} ns.") -f ('{0:0.#}' -f [math]::Round($e.Rbar, 1)), ('{0:0.#}' -f [math]::Round($e.RTol, 1)), ('{0:+0;-0;0}' -f $dn))) })
    $u.D = $dn
    Set-LevelTargets $u
    return 'next'
}

function Write-LevelDecideLog($J, [switch]$NoEst, [switch]$EstOnly) {
    if ($null -eq $J) { return }
    foreach ($x in $J) {
        if ($NoEst -and $x.Est) { continue }
        if ($EstOnly -and -not $x.Est) { continue }
        Append-Log $x.Text
    }
}

function Invoke-LevelStep($cal, $tracks = $null) {
    # Apres chaque passe : estimation par unite, arret (niveau verifie, echec, bascule anticipee, dernier essai) ou passe suivante.
    # 12.7 point 5 : premiere passe, pistes relues ($tracks) : etat de la surface de la disquette d abord (Invoke-LevelSurface)
    # 12.8 (lot 1c) : calibration rapide adaptative (module 265, c1-design.md § 3.2) : decision 12.7 calculee sur une copie
    # de l unite ; forme non conforme et garde-fous respectes : passe de mesure (Mode 'meas'), puis de verification
    # ('verif') ; pente nulle sur une base etroite : passe de confirmation ('nwc') ; sinon decision 12.7 appliquee telle quelle
    if ($null -ne $tracks -and [int]$cal.LPass -eq 1 -and -not $cal.SurfDone) {
        if (-not (Invoke-LevelSurface $cal $tracks)) { return }
        # Pistes signalees par le controle de surface : nommees, ecartees d un ajustement eventuel
        if ($cal.Surf -and $cal.Surf.Faces) {
            foreach ($u in $cal.Units) {
                if ($null -eq $u.Head -or $null -eq $u.Named -or -not $cal.Surf.Faces[[int]$u.Head]) { continue }
                foreach ($b in @($cal.Surf.Faces[[int]$u.Head].Bad)) { if ($b) { $u.Named[[int]$b.C] = (T 'piste signalée par le contrôle de surface') } }
            }
        }
    }
    $p = [int]$cal.LPass
    foreach ($u in $cal.Units) {
        if ($u.Done) { continue }
        $u.Passes = $p
        $pfx = $u.Prefix
        if ($u.ProbeOnly) {
            # Passe du seul temoin du plafond, ecrit a son zero estime : le niveau est deja verifie
            $z = Get-LevelZero $u.Results[[int]$u.Probe] ([double]$u.Est.K)
            $pp = $u.Results[[int]$u.Probe]; $tg = [int]$u.LTarget[[int]$u.Probe]
            if ($z) {
                $u.Est.ProbeZ = [double]$z.Est; $u.Est.ProbeKind = [string]$z.Kind; $u.ProbeZ = [double]$z.Est
                $atTol = ($pp -and $pp.ContainsKey($tg) -and [math]::Abs([double]$pp[$tg].Shift) -le (Get-ResidualTol $pp[$tg]))
                if ($z.Kind -eq 'cap' -or ($z.Kind -eq 'interp' -and @($pp.Keys).Count -ge 2) -or $atTol) { $u.ProbeDone = $true }
            }
            $u.ProbeOnly = $false; $u.Done = $true; continue
        }
        if (-not $u.Mode) { $u.Mode = 'lvl1' }
        if ($u.Mode -eq 'lvl1') {
            $e = Get-LevelEstimate $u $p
            $u.Est = $e
            if ($null -ne $u.Probe -and -not $u.ProbeDone -and $null -ne $e.ProbeZ) {
                $pp = $u.Results[[int]$u.Probe]; $tg = [int]$u.LTarget[[int]$u.Probe]
                $atTol = ($pp -and $pp.ContainsKey($tg) -and [math]::Abs([double]$pp[$tg].Shift) -le (Get-ResidualTol $pp[$tg]))
                if ($e.ProbeKind -eq 'cap' -or ($e.ProbeKind -eq 'interp' -and @($pp.Keys).Count -ge 2) -or $atTol) { $u.ProbeDone = $true }
                $u.ProbeZ = $e.ProbeZ
            }
            # Decision 12.7 sur une copie de l unite (les objets mesures sont partages, la decision ne les modifie pas)
            $uc = $u.Clone()
            $J = New-Object System.Collections.Generic.List[object]
            $dec = Invoke-LevelDecide $cal $uc $e $p $J
            if ($dec -eq 'nowrite' -and $p -lt $script:LevelMaxPasses -and [double]$e.KSpan -lt $script:LevelAdaptDeltaMin -and
                @((Get-LevelFitCyls $u) | Where-Object { [int]$u.Writes[$_] -gt 2 }).Count -eq 0) {
                # Pente apparente nulle sur une base etroite : derive du lecteur possible ; confirmation sur LevelNwcDelta ns
                Append-Log ($pfx + ((T "Pente apparente nulle sur une base de {0} ns seulement (dérive du lecteur possible) : confirmation à la passe {1} sur une base de {2} ns.") -f (Format-UiNum ([math]::Round([double]$e.KSpan, 1)) '0.#'), "$($p + 1)", "$($script:LevelNwcDelta)"))
                Set-LevelNwcTargets $u
                continue
            }
            $trig = $null
            if (-not $uc.Fail) {
                if ($dec -eq 'repli') { $trig = @{ Type = 'A'; Reasons = @((Test-LevelShape $e $u 2.0).Reasons) } }
                elseif ($p -eq 1 -and -not $cal.CanFallback -and $dec -eq 'next' -and (Test-LevelShape $e $u 2.0).Verdict -eq 'mismatch') { $trig = @{ Type = 'A'; Reasons = @((Test-LevelShape $e $u 2.0).Reasons) } }
                elseif ($script:LevelAdaptTrigF1 -and $p -eq 1 -and $dec -eq 'next' -and (Test-LevelShape $e $u 1.0).Verdict -eq 'mismatch') { $trig = @{ Type = 'A'; Reasons = @((Test-LevelShape $e $u 1.0).Reasons) } }
                elseif ($p -le 2 -and (@('verifie', 'probe', 'stable', 'max_passes') -contains $dec -or ($dec -eq 'next' -and $p -eq 2))) {
                    $sh1 = Test-LevelShape $e $u 1.0
                    if ($sh1.Verdict -eq 'mismatch') {
                        # Declencheur B a la passe 2 : forme aussi non conforme avec les zeros a la pente de reference (une
                        # derive entre deux passes proches ne cree pas de forme fictive)
                        $pers = ($p -eq 1) -or ($script:LevelAdaptPersist -lt 2) -or ((Test-LevelShape (Get-LevelKrefEstimate $u) $u 1.0).Verdict -eq 'mismatch')
                        if ($pers) { $trig = @{ Type = 'B'; Reasons = @($sh1.Reasons) } }
                    }
                }
            }
            if ($trig) {
                $el = Test-LevelAdaptEligible $cal $u $e
                if (-not $el.Ok) {
                    if ($dec -eq 'repli' -or $trig.Type -eq 'B') {
                        $u.AdaptLog = $pfx + ((T "Calibration rapide adaptative non tentée : {0}.") -f "$($el.Why)")
                        if ($el.G6) { $uc.AdaptNote = $pfx + ((T 'calibration rapide adaptative non tentée : {0}') -f "$($el.Why)") }
                    }
                    $trig = $null
                }
            }
            if (-not $trig) {
                $al = $u.AdaptLog
                foreach ($k in @($uc.Keys)) { $u[$k] = $uc[$k] }
                Write-LevelDecideLog $J
                if ($al) { Append-Log $al; $u.AdaptLog = $null }
                continue
            }
            # Declenchement : la decision 12.7 est gardee pour un refus eventuel (declenchement a la passe 2) ; seule la ligne
            # « Niveau estime » est ecrite
            Write-LevelDecideLog $J -EstOnly
            $u.Trig = @{ Type = $trig.Type; Pass = $p; Reasons = $trig.Reasons; Dec = $dec; Unit = $uc; J = $J }
            $ctlTxt = if (@($u.Ctl).Count -gt 0) { Format-CylList ([int[]]@($u.Ctl)) } else { '-' }
            if ($p -eq 1) {
                Append-Log ($pfx + ((T "Forme non conforme à la passe 1 ({0}) : calibration rapide adaptative, passe 2 de mesure à une autre précompensation sur les mêmes cylindres (pente propre et vrai zéro de chaque cylindre) ; cylindres de contrôle hors ajustement : {1}.") -f (@($trig.Reasons) -join ' ; '), "$ctlTxt"))
                Set-LevelAdaptTargets $cal $u $e
                continue
            }
            # Passe 2 : les deux passes lvl1 servent de mesure, analyse immediate, verification a la passe 3
            Append-Log ($pfx + ((T "Forme non conforme à la passe 2 ({0}) : forme ajustée sur les passes 1 et 2, vérification à la passe 3 ; cylindres de contrôle : {1}.") -f (@($trig.Reasons) -join ' ; '), "$ctlTxt"))
            $u.Mode = 'meas'
            $cal.TotalPasses = [math]::Max([int]$cal.TotalPasses, [int]$script:LevelMaxPasses)
        }
        if ($u.Mode -eq 'nwc') {
            $e = Get-LevelEstimate $u $p
            $u.Est = $e
            $kr = if ($null -ne $e.KRaw) { Format-UiNum ([math]::Round(-[double]$e.KRaw / [double]$u.KRef, 1)) '0.#' } else { '-' }
            if ($null -ne $e.KRaw -and $e.KRaw -ge [math]::Max(-0.2, -0.5 * [double]$u.KRef) -and [double]$u.KRef * [double]$e.KSpan -ge 4.0) {
                Append-Log ($pfx + ((T 'Pente nulle confirmée sur une base de {0} ns.') -f (Format-UiNum ([math]::Round([double]$e.KSpan, 1)) '0.#')))
                $u.Fail = 'nowrite'; $u.Done = $true
                continue
            }
            $u.Level = [int][math]::Round([double]$e.Delta); $u.Conv = $false; $u.Done = $true; $u.Mode = 'lvl1'
            $u.Note = $pfx + ((T 'pente nulle de la passe {0} non confirmée sur une base de {1} ns (pente {2} fois la référence) : dérive du lecteur probable, niveau {3} ns non vérifié') -f "$($p - 1)", "$($script:LevelNwcDelta)", "$kr", ('{0:+0;-0;0}' -f [int]$u.Level))
            Append-Log ($pfx + ((T "Pente de la face confirmée sur une base de {0} ns ({1} fois la référence) : la pente nulle de la passe {2} venait d'une dérive du lecteur ou du bruit ; niveau estimé {3} ns, non vérifié.") -f (Format-UiNum ([math]::Round([double]$e.KSpan, 1)) '0.#'), "$kr", "$($p - 1)", ('{0:+0;-0;0}' -f [int]$u.Level)))
            continue
        }
        if ($u.Mode -eq 'meas') {
            $an = Get-LevelAdaptFit $u
            $u.AN = $an
            Write-LevelAdaptFitLog $u $an
            foreach ($k in @($an.Named.Keys)) { $u.Named[[int]$k] = $an.Named[$k] }
            if ($an.Why -eq 'nowrite') { $u.Fail = 'nowrite'; $u.Done = $true; continue }
            if (-not $an.Ok -and [int]$u.Trig.Pass -eq 1) {
                # 12.8 (F3R, e3) : refus de la passe de mesure (ecarts disperses, ecart isole, ecart de forme, bornes) repris
                # avec un terme de centre quand les controles s ecartent dans le meme sens que le centre : controles integres a
                # l ajustement, controle neuf hors ajustement, verification a la passe 3
                $ce = Get-LevelCenterRescue $u $an $cal
                if ($ce -and $ce.Ok) {
                    Append-Log ($pfx + ((T 'Adaptation reprise avec un terme de centre ({0}).') -f "$($an.Why)"))
                    Write-LevelCenterLog $u $ce
                    foreach ($c in @($ce.AN.Center.Reinc)) { [void]$u.Named.Remove([int]$c) }
                    $u.AN = $ce.AN; $an = $ce.AN
                    $u.CtlFit = [int[]]@($u.Ctl)
                    $fr = if ($script:LevelCenterFresh) { Get-LevelFreshCtl $u (Get-LevelFitCyls $u) $(if ($null -ne $cal.MaxCyl) { [int]$cal.MaxCyl } else { -1 }) } else { $null }
                    # 12.8 (F3R-FIX) : affectation par branche ; « $x = if (...) { [int[]]@() } » donnerait $null, puis
                    # [int[]]@($null) le cylindre 0 (Add-LevelCalCyls, enregistrement Ctl)
                    if ($null -ne $fr) { $u.Ctl = [int[]]@($fr) } else { $u.Ctl = [int[]]@() }
                    if ($null -ne $fr) {
                        if (-not $u.Results.ContainsKey([int]$fr)) { $u.Results[[int]$fr] = @{} }
                        Append-Log ($pfx + ((T "Contrôles {0} intégrés à l'ajustement ; contrôle neuf hors ajustement : c{1}.") -f ((@($u.CtlFit) | ForEach-Object { "c$_" }) -join ', '), "$fr"))
                    }
                    Set-LevelVerifTargets $cal $u $an
                    continue
                }
                if ($ce) { Append-Log ($pfx + ((T 'Reprise avec un terme de centre non retenue : {0}.') -f "$($ce.Why)")) }
            }
            if (-not $an.Ok) {
                $u.Refus = [string]$an.Why
                Append-Log ($pfx + ((T 'Adaptation refusée : {0}. Courbe de la référence décalée conservée.') -f "$($an.Why)"))
                $tr = $u.Trig
                if ([int]$tr.Pass -eq 2) {
                    # Declenchement a la passe 2 : decision 12.7 d origine appliquee (niveau verifie, stable, ou passe 3)
                    $mine = @{ AN = $u.AN; Named = $u.Named; Refus = $u.Refus; Trig = $u.Trig }
                    foreach ($k in @($tr.Unit.Keys)) { $u[$k] = $tr.Unit[$k] }
                    foreach ($k in @($mine.Keys)) { $u[$k] = $mine[$k] }
                    $u.Mode = 'lvl1'
                    Write-LevelDecideLog $tr.J -NoEst
                    continue
                }
                if ($tr.Type -eq 'B') {
                    # Declenche a la passe 1 apres un niveau verifie : niveau 12.7 garde, forme non conforme
                    $u.Level = $tr.Unit.Level; $u.Conv = $tr.Unit.Conv; $u.Done = $true; $u.Mode = 'refus'
                    continue
                }
                Set-LevelLevelOnly $u $an
                $u.Early = $true; $u.Done = $true; $u.Mode = 'refus'
                continue
            }
            Set-LevelVerifTargets $cal $u $an
            continue
        }
        if ($u.Mode -eq 'verif') {
            $vr = Test-LevelAdaptVerify $u $p
            $u.VR = $vr
            $an = $u.AN
            if ($vr.Why -and $vr.NewBad.Count -eq 0 -and -not $vr.NoMeas) {
                # 12.8 (F3R) : controle hors tolerance, sans nouveau cylindre hors de la forme : correction du centre par les
                # controles si l ecart est appuye et regulier ; courbe corrigee non verifiee par une ecriture du motif (reserve)
                $ce = Get-LevelCenterEval $u $an 3 $vr
                Write-LevelCenterLog $u $ce
                if ($ce -and $ce.Ok) {
                    foreach ($c in @($ce.AN.Center.Reinc)) { [void]$u.Named.Remove([int]$c) }
                    $u.AN = $ce.AN; $an = $ce.AN
                    $vr.Why = ''; $vr.BadCtl = @(); $vr.Delta = [double]$ce.Drift
                    $u.AV = Build-LevelAdaptValues $u $an.Fit ([string]$an.Model)
                    $an.Center.Verified = $false
                    $u.Conv = [bool]$vr.Conv
                    $u.Level = [int][math]::Round([double]$an.Fit.Coef['a'] + [double]$vr.Delta)
                    $u.Done = $true; $u.Mode = 'adapte'
                    continue
                }
            }
            if ($vr.Why -and $vr.NewBad.Count -eq 0 -and -not $vr.NoMeas -and [string]$an.Model -ne 'M0') {
                # 12.8 (F3R, e2) : refus par un controle seulement : courbe adaptee gardee avec reserve (au lieu du niveau seul),
                # controle apres ecriture impose (G1, modele autre que M0) ; jamais memorisee pour la marque (G5)
                $u.Refus = ''; $u.CtlReserve = [string]$vr.Why; $u.CtlBad = @($vr.BadCtl)
                Append-Log ($pfx + ((T 'Contrôle hors tolérance : {0} ; courbe adaptée gardée avec réserve (contrôle après écriture imposé).') -f "$($vr.Why)"))
                foreach ($x in @($vr.BadCtl)) { $u.Named[[int]$x] = (T 'contrôle hors tolérance') }
                # J4 : ecart isole du centre de meme sens que le controle le plus ecarte : besoin du centre plutot qu un defaut
                $xw = $null
                foreach ($x in @($vr.BadCtl | ForEach-Object { [int]$_ })) {
                    $ax = [math]::Abs([double]$vr.Ctl[$x].Dev)
                    if ($null -eq $xw -or $ax -gt [math]::Abs([double]$vr.Ctl[$xw].Dev) -or ($ax -eq [math]::Abs([double]$vr.Ctl[$xw].Dev) -and $x -gt $xw)) { $xw = $x }
                }
                if ($null -ne $xw -and $an.Iso) {
                    $sx = [math]::Sign([double]$vr.Ctl[$xw].Dev)
                    foreach ($c in @($an.Iso.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
                        if ($c -lt $script:LevelAdaptCtlLo -or [math]::Sign([double]$an.Iso[$c]) -ne $sx) { continue }
                        $jf = if ($sx -gt 0) { (T "Écart isolé à c{0} ({1} ns) et contrôle c{2} ({3} ns) de même sens : besoin plus fort vers le centre que la forme ajustée, plutôt qu'un défaut ponctuel.") } else { (T "Écart isolé à c{0} ({1} ns) et contrôle c{2} ({3} ns) de même sens : besoin plus faible vers le centre que la forme ajustée, plutôt qu'un défaut ponctuel.") }
                        Append-Log ($pfx + ($jf -f "$c", (Format-LevelSigned $an.Iso[$c]), "$xw", (Format-LevelSigned $vr.Ctl[$xw].Dev)))
                    }
                }
                $u.Conv = [bool]$vr.Conv
                $u.Level = [int][math]::Round([double]$an.Fit.Coef['a'] + [double]$vr.Delta)
                $u.Done = $true; $u.Mode = 'adapte'
                continue
            }
            if ($vr.Why) {
                $u.Refus = [string]$vr.Why
                Append-Log ($pfx + ((T 'Adaptation refusée : {0}. Courbe de la référence décalée conservée.') -f "$($vr.Why)"))
                Set-LevelLevelOnly $u $an
                $u.Early = $true; $u.Done = $true; $u.Mode = 'refus'
                foreach ($c in @($vr.NewBad)) { $u.Named[[int]$c] = (T 'hors de la forme à la vérification') }
                foreach ($x in @($vr.BadCtl)) { $u.Named[[int]$x] = (T 'contrôle hors tolérance') }
                continue
            }
            foreach ($c in @($vr.NonRep)) { $u.Named[[int]$c] = (T 'écart non reproduit à la vérification (non reproductible)') }
            # 12.8 (F3R, e3) : forme reprise avec un terme de centre a la passe de mesure, verifiee a cette passe
            if ($an.Center -and $null -eq $an.Center.Verified) { $an.Center.Verified = $true }
            $u.Conv = [bool]$vr.Conv
            $u.Level = [int][math]::Round([double]$an.Fit.Coef['a'] + [double]$vr.Delta)
            $u.Done = $true; $u.Mode = 'adapte'
            continue
        }
    }
    # 12.8 (S3, c4-design § 4.2) : garde de la passe 1 d une tete partie de la courbe complete d une marque : une disquette
    # qui ne lui ressemble pas arrete la calibration rapide, sans adaptation a partir de cette courbe (choix W-M2)
    if ($p -eq 1 -and @($cal.Units | Where-Object { $_.Memo -and $_.Memo.Curve }).Count -gt 0) {
        $gd = Get-LevelBrandCurveGuard $cal
        if ($gd) { Stop-LevelBrandCurve $cal $gd; return }
    }
    $adapting = (@($cal.Units | Where-Object { -not $_.Done -and @('meas', 'verif', 'nwc') -contains [string]$_.Mode }).Count -gt 0)
    $early = (@($cal.Units | Where-Object { $_.Early }).Count -gt 0)
    if ((@($cal.Units | Where-Object { $_.Fail }).Count -gt 0) -or ($early -and -not $adapting)) {
        # Echec d une tete, ou bascule anticipee sans autre face en cours d adaptation : l autre tete, non terminee, garde
        # son niveau estime (non verifie) ; une face en cours d adaptation garde le niveau seul de ses zeros mesures
        foreach ($u in @($cal.Units | Where-Object { -not $_.Done })) {
            if (@('meas', 'verif') -contains [string]$u.Mode) {
                Set-LevelLevelOnly $u $u.AN
                $u.Mode = 'refus'
                if (-not $u.Refus) { $u.Refus = (T "calibration arrêtée par l'autre face") }
            } else {
                $u.Level = [int][math]::Round([double]$u.Est.Delta); $u.Conv = $false
                if ($u.Mode) { $u.Mode = 'lvl1' }
            }
            $u.Done = $true
        }
        Complete-LevelCalib; return
    }
    if ($early) {
        # Repli d une face pendant l adaptation de l autre : la face adaptee termine sa verification (une passe), une face
        # encore en lvl1 s arrete comme apres une bascule anticipee (niveau estime, non verifie)
        foreach ($u in @($cal.Units | Where-Object { -not $_.Done -and (-not $_.Mode -or [string]$_.Mode -eq 'lvl1') })) { $u.Level = [int][math]::Round([double]$u.Est.Delta); $u.Conv = $false; $u.Done = $true }
    }
    if (@($cal.Units | Where-Object { -not $_.Done }).Count -gt 0) {
        $cal.LPass++; $cal.TotalPasses = [math]::Max([int]$cal.TotalPasses, [int]$cal.LPass)
        New-CalibPass; return
    }
    Complete-LevelCalib
}

function Get-LevelCylRole($u, [int]$c) {
    # 12.8 (lot 1c, point 1) : role d un cylindre de la calibration rapide dans les lignes du journal (Write-CalibPassLog,
    # Write-LevelPassLog) : temoin de marche, temoin du plafond ; cylindre de niveau : aucun
    if (@($u.Wit) -contains $c) { return ' ' + (T '(témoin)') }
    if ($null -ne $u.Probe -and [int]$u.Probe -eq $c) { return ' ' + (T '(plafond)') }
    # 12.8 (lot 1c) : cylindre de controle de la calibration rapide adaptative (hors ajustement)
    if (@($u.Ctl) -contains $c) { return ' ' + (T '(contrôle)') }
    return ''
}

function Write-LevelPassLog($cal, $u, [int]$p) {
    # 12.8 (lot 1c, point 1) : zeros de la calibration rapide apres la passe p, des qu un cylindre a ete mesure a deux
    # valeurs ecrites ou plus, au journal seulement (ni niveaux, ni historique, ni courbe), avant toute decision
    # (Invoke-LevelStep). Element « c<cyl>[ (role)] <zero><marque> ± <incertitude> (<pente propre / pente de reference>) » :
    # zero en ns de precompensation (Get-LevelZero, pente de l estimation de la passe, comme Invoke-LevelStep), marque *
    # (extrapole) ou ^ (borne a 0 ou CalHardNs) ; pente propre : corde des deux valeurs ecrites extremes, « - » sur moins de
    # 4 ns. Prefixe de l unite : « [tete h] », aucun pour la courbe commune (moyenne des deux faces)
    $cyls = @(@(@($u.LCyls) + @($u.Wit) + @($(if ($null -ne $u.Probe) { $u.Probe })) + @($u.Ctl)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $two = @($cyls | Where-Object { $u.Results[$_] -and @($u.Results[$_].Keys).Count -ge 2 })
    if ($two.Count -eq 0) { return }
    $k = if ($u.ProbeOnly -and $u.Est) { [double]$u.Est.K } else { [double](Get-LevelEstimate $u $p).K }
    $mark = @{ interp = ''; extrap = '*'; cap = '^' }
    $items = @()
    foreach ($c in $two) {
        $pts = $u.Results[$c]
        $z = Get-LevelZero $pts $k
        if (-not $z) { continue }
        $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        $ratio = '-'
        if (($xs[-1] - $xs[0]) -ge 4 -and [double]$u.KRef -gt 0) {
            $ko = -([double]$pts[$xs[-1]].Shift - [double]$pts[$xs[0]].Shift) / ($xs[-1] - $xs[0])
            $ratio = Format-UiNum ($ko / [double]$u.KRef) '0.00'
        }
        $sg = if ($null -eq $z.Sig -or [double]::IsNaN([double]$z.Sig)) { '-' } else { Format-UiNum ([double]$z.Sig) '0.0' }
        $items += "c$c$(Get-LevelCylRole $u $c) $(Format-UiNum ([double]$z.Est) '0.0')$($mark[[string]$z.Kind]) ± $sg ($ratio)"
    }
    if ($items.Count -eq 0) { return }
    Append-Log ((T "{0}Zéros après la passe {1} (pente propre, × référence) : {2}.") -f "$($u.Prefix)", "$p", ($items -join ' ; '))
}

function Get-LevelLabel($rec) {
    # « +12 ns » (profil commun) ou « tete 0 +12 ns » ; 12.8 (lot 1c) : « (forme adaptee) » pour une courbe adaptee
    $v = '{0:+0;-0;0} ns' -f [int]$rec.Delta
    # 12.8 (S3) : courbe d une mesure complete de cette disquette (ecart moyen a la reference)
    if ([string]$rec.Model -eq 'mesure') { $v += ' ' + (T '(mesure complète)') }
    elseif ($rec.Model -and [string]$rec.Model -ne 'M0') { $v += ' ' + (T '(forme adaptée)') }
    if ($null -eq $rec.Head) { return $v }
    return ((T "tête {0} {1}") -f "$($rec.Head)", "$v")
}

function Set-LevelFields($recs, [bool]$slow) {
    # Profils decales dans les champs --precomp (tetes physiques en ecriture lente) : pour cette disquette seulement
    $chkWPrecomp.Checked = $true
    $rs = @($recs)
    if ($slow) {
        $r0 = @($rs | Where-Object { $_.Head -eq 0 }); $r1 = @($rs | Where-Object { $_.Head -eq 1 })
        if ($r0.Count -gt 0) { $txtWPrecomp.Text = $r0[0].Spec }
        if ($r1.Count -gt 0) { $txtWPrecomp1.Text = $r1[0].Spec }
    } elseif ($rs.Count -gt 0) { $txtWPrecomp.Text = $rs[0].Spec; $txtWPrecomp1.Text = $rs[0].Spec }
}

function Get-LevelUnitResults($cal, [string]$date) {
    # Bilan de chaque tete de la calibration rapide sans echec : courbe, verdict, reserves, journal, enregistrement dans
    # $script:LevelShifts (historique, niveau de depart). 12.8 (lot 1c) : tetes adaptees ou refusees par
    # Get-LevelAdaptOutcome ; tetes lvl1 : regles 12.7. Info : reserve « information » (plafond, a surveiller, niveau de
    # la courbe adaptee non verifie) de la fenetre de decision. Sans fenetre ni configuration (suite calib-lvl2)
    $issues = New-Object System.Collections.Generic.List[string]
    $info = New-Object System.Collections.Generic.List[bool]
    $recs = @(); $prevRecs = @{}; $verdicts = @()
    foreach ($u in $cal.Units) {
        $e = $u.Est; $pfx = $u.Prefix
        $ad = (@('adapte', 'refus') -contains [string]$u.Mode)
        $model = 'M0'; $cs = 0.0; $cb = 0.0; $kk = if ($e) { [double]$e.K } else { $null }
        $hard = [int]$script:CalHardNs; $over = @(); $hcv = $null
        if ($ad) {
            $ao = Get-LevelAdaptOutcome $cal $u
            $shape = $ao.Shape; $u.Shape = $shape
            $bv = @{ Values = $ao.Values; Sat = @($ao.Sat); Floor = @($ao.Floor); Clip = @($ao.Clip) }
            $verdict = [string]$ao.Verdict
            foreach ($x in $ao.Issues) { $issues.Add([string]$x.Text); $info.Add([bool]$x.Info) }
            $model = [string]$ao.Model; $cs = [double]$ao.S; $cb = [double]$ao.B; if ($null -ne $ao.K) { $kk = [double]$ao.K }
            $hard = [int]$ao.Hard; $over = @($ao.Over); $hcv = $ao.Hc
        } else {
            $shape = Test-LevelShape $e $u 1.0; $u.Shape = $shape
            $bv = Build-LevelValues $u ([int]$u.Level) $e
            # 12.8 (F3R, decision 2) : courbe de la forme d une marque (V' + niveau, courbe adaptee, G1) dont le besoin depasse
            # CalHardNs : plafond porte a CalHardMaxNs pour cette disquette ; la reference seule reste a CalHardNs. 12.8
            # (F3R-FIX, constat 4) : seuil max(CalHardNsDefault, CalHardNs), comme Get-LevelAdaptHard. 12.8 (S3-FLUX,
            # decision 3) : borne precompMaxNs reglee sous CalHardNsDefault : respectee, sans relevement par disquette
            $memoExt = $false
            $memoThr = [math]::Max([int]$script:CalHardNsDefault, [int]$script:CalHardNs)
            if ($u.Memo -and [int]$script:CalHardMaxNs -gt [int]$script:CalHardNs -and [int]$script:CalHardNs -ge [int]$script:CalHardNsDefault -and $null -ne $bv.RawMax -and [double]$bv.RawMax -gt $memoThr) {
                $bv = Build-LevelValues $u ([int]$u.Level) $e -Hard ([int]$script:CalHardMaxNs)
                $memoExt = $true; $hard = [int]$script:CalHardMaxNs
                $over = @(0..(@($bv.Values).Count - 1) | Where-Object { [int]$bv.Values[$_] -gt [int]$script:CalHardNs })
            }
            foreach ($c in @($e.Outliers)) { Append-Log ($pfx + ((T "Écart isolé à c{0} ({1} ns par rapport à la forme) : défaut ponctuel probable de cette disquette, écarté du niveau.") -f "$c", ('{0:+0;-0;0}' -f [math]::Round($e.Ds[[int]$c] - $e.Delta, 0)))) }
            $verdict = if ($u.Sat) { 'sat' } elseif ($u.Low) { 'low' } elseif ($u.Few) { 'few' } else { $shape.Verdict }
            switch ($shape.Verdict) {
                'ok'       { Append-Log ($pfx + ((T "Forme conforme à la référence (écart de forme {0} ns).") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1)))) }
                'approx'   { Append-Log ($pfx + ((T "Forme approximative (écart de forme {0} ns) : courbe décalée appliquée ; une calibration complète de cette disquette serait plus précise.") -f ('{0:0.#}' -f [math]::Round($e.Tau, 1)))) }
                'mismatch' { Append-Log ($pfx + ((T "Forme non conforme à la référence : {0}.") -f ($shape.Reasons -join ' ; '))); $issues.Add($pfx + ((T "forme non conforme à la référence : {0}") -f ($shape.Reasons -join ' ; '))); $info.Add($false) }
            }
            if (-not $u.Conv) { $issues.Add($pfx + ((T "niveau non vérifié par une écriture du motif ({0} passe(s))") -f "$($u.Passes)")); $info.Add($false) }
            if ($u.Sat) { $issues.Add($pfx + ((T 'besoin au-delà de {0} ns sur la plupart des cylindres mesurés (support fatigué ?)') -f "$($script:CalHardNs)")); $info.Add($false) }
            if ($u.Low) { $issues.Add($pfx + (T 'précompensation nulle encore excessive sur la plupart des cylindres mesurés')); $info.Add($false) }
            if ($u.Few) { $issues.Add($pfx + ((T "niveau estimé sur {0} cylindre(s) de niveau seulement ({1} au plafond ou au plancher)") -f "$($e.N)", "$(@($e.Capped).Count + @($e.Floored).Count)")); $info.Add($false) }
            # [3] Cylindres de niveau bornes (zero au-dela de CalHardNs ou sous 0 ns) loin du niveau retenu : ecartes, signales
            $bnd = @(@(@($e.Capped) | Where-Object { [int]$u.V[[int]$_] + [int]$u.Level -lt [int]$script:CalHardNs - 15 }) + @(@($e.Floored) | Where-Object { [int]$u.V[[int]$_] + [int]$u.Level -gt 15 }))
            if (-not $u.Sat -and -not $u.Low -and $bnd.Count -gt 0) {
                $bt = (T "besoin hors de 0 à {1} ns aux cylindres de niveau {0}, loin du niveau de cette disquette : écartés du niveau") -f (Format-CylList ([int[]]@($bnd | Sort-Object))), "$($script:CalHardNs)"
                Append-Log ($pfx + $bt + '.'); $issues.Add($pfx + $bt); $info.Add($false)
            }
            # 12.8 (F3R) : plafond par disquette (memoExt) : lignes et reserves plus bas, apres celles de la zone plafonnee
            if ($bv.Sat.Count -gt 0 -and $u.Memo -and -not $memoExt -and [int]$script:CalHardNs -ge [int]$script:CalHardMaxNs) {
                # 12.8 (F3R-FIX, constat 9) : borne precompMaxNs deja a CalHardMaxNs : plus de conseil de la relever
                Append-Log ($pfx + ((T 'Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés.') -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat))))
                $issues.Add($pfx + ((T 'plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés') -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)))); $info.Add($true)
            } elseif ($bv.Sat.Count -gt 0 -and $u.Memo -and -not $memoExt) {
                # 12.8 (FIX1C, constat 5) : courbe de la marque (V', forme adaptee) : libelle neutre du plafond (§ 11.2)
                Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs).") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat))))
                $issues.Add($pfx + ((T "plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés ; la borne se règle jusqu'à 470 ns (precompMaxNs)") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)))); $info.Add($true)
            } elseif ($bv.Sat.Count -gt 0 -and -not $u.Memo -and [string]$shape.Verdict -eq 'mismatch') {
                # 12.8 (F3R, decision du 21/10/2026) : forme non conforme : libelle neutre, autre type de disquette ou usure
                Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence), de forme différente : autre type de disquette ou usure, non distingués ; ces cylindres resteront sous-compensés.") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)), ('{0:+0;-0;0}' -f [int]$u.Level)))
                $issues.Add($pfx + ((T "plafond de {0} ns atteint aux cylindres {1} (autre type de disquette ou usure ?)") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)))); $info.Add($true)
            } elseif ($bv.Sat.Count -gt 0 -and -not $u.Memo) {
                Append-Log ($pfx + ((T "Plafond de {0} ns atteint aux cylindres {1} avec le niveau de cette disquette ({2} ns par rapport à la référence) : support probablement fatigué, ces cylindres resteront sous-compensés.") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)), ('{0:+0;-0;0}' -f [int]$u.Level)))
                $issues.Add($pfx + ((T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Sat)))); $info.Add($true)
            }
            if (@($bv.Clip).Count -gt 0) {
                Append-Log ($pfx + ((T "Référence calculée avec une borne de {0} ns, au-delà de la borne actuelle (precompMaxNs = {1} ns) aux cylindres {2} : valeurs ramenées à {1} ns.") -f "$(Get-CurveMaxNs $u.Cv)", "$($script:CalHardNs)", (Format-CylList ([int[]]$bv.Clip))))
            }
            if ($bv.Floor.Count -gt 0) {
                Append-Log ($pfx + ((T "Précompensation nulle encore excessive aux cylindres {0} avec le niveau de cette disquette : ces cylindres resteront sur-compensés.") -f (Format-CylList ([int[]]$bv.Floor))))
                $issues.Add($pfx + ((T "précompensation nulle encore excessive aux cylindres {0}") -f (Format-CylList ([int[]]$bv.Floor)))); $info.Add($false)
            }
            if ($bv.ProbeNote -eq 'interp') { Append-Log ($pfx + ((T "Zone plafonnée de la référence (c{0} à c{1}) : besoin mesuré au témoin c{1} : {2} ns ; zone interpolée jusqu'à cette valeur.") -f "$($u.CapLo)", "$($u.Probe)", ('{0:0.#}' -f [math]::Round($e.ProbeZ, 0)))) }
            elseif ($bv.ProbeNote -eq 'unresolved') {
                $ut = (T "témoin du plafond c{0} non résolu : zone de c{1} à c{0} laissée à la référence ({2} ns, plafond de son calcul), relevée du niveau s'il est positif, sans mesure sur cette disquette") -f "$($u.Probe)", "$($u.CapLo)", "$(Get-CurveMaxNs $u.Cv)"
                Append-Log ($pfx + $ut + '.'); $issues.Add($pfx + $ut); $info.Add($false)
            }
            elseif ($bv.ProbeNote -eq 'cap') { Append-Log ($pfx + ((T "Zone plafonnée de la référence (c{0} à c{1}) : le besoin dépasse encore {2} ns au témoin c{1} ; zone portée jusqu'à {2} ns.") -f "$($u.CapLo)", "$($u.Probe)", "$($script:CalHardNs)")) }
            if ($memoExt) {
                # Plafond par disquette (forme d une marque) : plafond de CalHardMaxNs atteint, courbe au-dela de CalHardNs
                if ($bv.Sat.Count -gt 0) {
                    Append-Log ($pfx + ((T 'Plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés.') -f "$hard", (Format-CylList ([int[]]$bv.Sat))))
                    $issues.Add($pfx + ((T 'plafond de {0} ns atteint aux cylindres {1} avec la courbe adaptée : ces cylindres resteront sous-compensés') -f "$hard", (Format-CylList ([int[]]$bv.Sat)))); $info.Add($true)
                }
                if ($over.Count -gt 0) {
                    $top = (@($bv.Values) | Measure-Object -Maximum).Maximum
                    Append-Log ($pfx + ((T "Courbe adaptée au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns) : le besoin de cette disquette dépasse la borne precompMaxNs ; plafond porté à {3} ns pour cette disquette seulement ; contrôle après écriture imposé.") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$over)), "$top", "$hard"))
                    $issues.Add($pfx + ((T "courbe adaptée au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns, plafond porté à {3} ns pour cette disquette seulement) : contrôle après écriture imposé") -f "$($script:CalHardNs)", (Format-CylList ([int[]]$over)), "$top", "$hard")); $info.Add($true)
                }
            }
            # 12.8 (lot 1c) : adaptation refusee apres un declenchement a la passe 2 (decision 12.7 appliquee), pente nulle non
            # confirmee (dérive du lecteur), adaptation non tentee (courbe commune, temoin du plafond : G6)
            if ($u.Refus) { $issues.Add($pfx + ((T 'adaptation refusée : {0}') -f "$($u.Refus)")); $info.Add($false) }
            if ($u.Note) { $issues.Add([string]$u.Note); $info.Add($false) }
            if ($u.AdaptNote) { $issues.Add([string]$u.AdaptNote); $info.Add($false) }
        }
        # Courbe de la marque (V') appliquee par une tete lvl1 ou refusee : forme de la marque enregistree
        if ([string]$u.Mode -ne 'adapte' -and $u.Memo) { $model = $(if ($u.Memo.Model) { [string]$u.Memo.Model } else { 'Msb' }); $cs = [double]$u.Memo.S; $cb = [double]$u.Memo.B }
        # Historique avec la meme reference : support fatigue (12.8, G4 : par rapport a la marque de depart), derive de la
        # reference ; courbe adaptee : libelle neutre a la place de l alerte de fatigue
        $hk = "$($u.RefKey)|$($u.Tag)"; $old = $script:LevelShifts[$hk]; $prevRecs[$hk] = $old
        $hist = @(); if ($old -and [string]$old.RefDate -eq [string]$u.Cv.Date) { $hist = @($old.Hist) }
        $fh = if ($u.Memo) { @($u.Memo.Hist) } else { $hist }
        if ($fh.Count -ge 3 -and $verdict -ne 'adapte' -and $null -ne $u.Level) {
            $hv = @($fh | Select-Object -Last 5 | ForEach-Object { [double]$_.Delta }); $med = [double](Get-Median $hv)
            if ([int]$u.Level - $med -gt $script:LevelFatigueNs) {
                $u.Fatigue = $true       # 12.8 (S3) : besoin bien plus fort que d habitude (J5) : « Mesure complete » proposee
                if ($u.Memo) { Append-Log ((T "{0}Cette disquette demande {1} ns de plus que la marque « {2} » (médiane de {3} mesures) : disquette probablement fatiguée, l'écriture y sera moins sûre.") -f "$pfx", ('{0:0.#}' -f [math]::Round([int]$u.Level - $med, 0)), "$($u.Memo.Brand)", "$($hv.Count)") }
                # 12.8 (F3R, decision du 21/10/2026) : forme non conforme, sans marque : autre type de disquette ou usure
                elseif ([string]$shape.Verdict -eq 'mismatch') { Append-Log ($pfx + ((T "Cette disquette demande {0} ns de plus que la médiane des {1} dernières disquettes mesurées avec cette référence, avec une forme différente : autre type de disquette ou usure, non distingués.") -f ('{0:0.#}' -f [math]::Round([int]$u.Level - $med, 0)), "$($hv.Count)")) }
                else { Append-Log ($pfx + ((T "Cette disquette demande {0} ns de plus que la médiane des {1} dernières disquettes mesurées avec cette référence : support probablement fatigué, l'écriture y sera moins sûre.") -f ('{0:0.#}' -f [math]::Round([int]$u.Level - $med, 0)), "$($hv.Count)")) }
            }
        }
        if (-not $ad -and -not $u.Memo -and $hist.Count -ge 3) {
            $l5 = @(@($hist | Select-Object -Last 4 | ForEach-Object { [double]$_.Delta }) + @([double]$u.Level))
            if ($l5.Count -ge 5 -and (@($l5 | Where-Object { $_ -gt $script:LevelFatigueNs }).Count -eq 5 -or @($l5 | Where-Object { $_ -lt -$script:LevelFatigueNs }).Count -eq 5)) {
                Append-Log ($pfx + ((T "Les {0} dernières disquettes s'écartent toutes de la référence dans le même sens (de {1} à {2} ns) : la référence a peut-être été mesurée sur une disquette atypique. Une nouvelle calibration complète en test fin, sur une disquette sacrifiée en bon état, est conseillée.") -f "$($l5.Count)", ('{0:+0;-0;0}' -f ($l5 | Measure-Object -Minimum).Minimum), ('{0:+0;-0;0}' -f ($l5 | Measure-Object -Maximum).Maximum)))
            }
        }
        # Niveau de depart des disquettes de cette reference (D0) : tete non adaptee, forme conforme ou approximative,
        # niveau verifie, sans forme de marque au depart (12.8 : une disquette d une autre marque ne le deplace pas)
        if (($verdict -eq 'ok' -or $verdict -eq 'approx') -and $u.Conv -and -not $u.Early -and -not $u.Memo) { $hist = @(@($hist) + @(@{ Date = $date; Delta = [int]$u.Level })) }
        if ($hist.Count -gt $script:LevelHistMax) { $hist = @($hist | Select-Object -Last $script:LevelHistMax) }
        # Mesures : cylindres de niveau, temoins de marche et du plafond ; tete adaptee : zeros mesures a deux precompensations
        $mc = @(); $mz = @(); $md = @(); $ms = @(); $mk = @()
        $an = $u.AN
        if ($ad -and $an -and $an.Zs -and $an.Zs.Count -gt 0) {
            foreach ($ci in @($an.Zs.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
                $z = $an.Zs[$ci]
                $mc += $ci; $mz += [math]::Round([double]$z.Est, 1); $md += [math]::Round([double]$z.Est - [double]$u.ShapeV.V[$ci], 1); $ms += [math]::Round([double]$z.Sig, 1)
                $mk += $(if ($u.Named.ContainsKey($ci)) { 'outlier' } elseif (@($u.Wit) -contains $ci) { 'witness' } else { [string]$z.Kind })
            }
        } else {
            foreach ($c in @($u.LCyls)) {
                $ci = [int]$c
                if ($e.Ds.ContainsKey($ci)) { $mc += $ci; $mz += [math]::Round([double]$u.V[$ci] + $e.Ds[$ci], 1); $md += [math]::Round($e.Ds[$ci], 1); $ms += [math]::Round($e.Sigs[$ci], 1); $mk += $(if (@($e.Outliers) -contains $ci) { 'outlier' } else { [string]$e.Kinds[$ci] }) }
                elseif (@($e.Capped) -contains $ci) { $mc += $ci; $mz += [double]$script:CalHardNs; $md += [math]::Round([double]$script:CalHardNs - [double]$u.V[$ci], 1); $ms += 0.0; $mk += 'cap' }
                elseif (@($e.Floored) -contains $ci) { $mc += $ci; $mz += 0.0; $md += [math]::Round(-[double]$u.V[$ci], 1); $ms += 0.0; $mk += 'cap' }
            }
            foreach ($c in @($u.Wit)) { $wz = $e.Wit[[int]$c]; if ($wz) { $mc += [int]$c; $mz += [math]::Round($wz.Z, 1); $md += [math]::Round($wz.D, 1); $ms += [math]::Round($wz.Sig, 1); $mk += 'witness' } }
            if ($null -ne $u.Probe -and $null -ne $e.ProbeZ) { $mc += [int]$u.Probe; $mz += [math]::Round([double]$e.ProbeZ, 1); $md += [math]::Round([double]$e.ProbeZ - [double]$u.V[[int]$u.Probe], 1); $ms += 0.0; $mk += 'probe' }
        }
        $rEst = [double]$e.Delta; $rSe = [double]$e.SE; $rTau = [double]$e.Tau
        if ([string]$u.Mode -eq 'adapte' -and $an -and $an.Fit) { $rEst = [double]$an.Fit.Coef['a']; $rSe = [math]::Sqrt([math]::Max(0.0, [double]$an.Fit.Cov[0][0])); $rTau = [double]$an.Fit.Tau }
        $rec = @{ RefKey = $u.RefKey; Tag = $u.Tag; Head = $u.Head; Drive = $cal.Drive; Date = $date; RefDate = [string]$u.Cv.Date; RefTest = [string]$u.Cv.Test
                  Delta = [int]$u.Level; Est = [math]::Round($rEst, 1); SE = [math]::Round($rSe, 1); Tau = [math]::Round($rTau, 1)
                  Verdict = $verdict; Shape = [string]$shape.Verdict; Reasons = [string[]]@($shape.Reasons); Conv = [bool]$u.Conv; Passes = [int]$u.Passes
                  Cyls = [int[]]$mc; Zs = [double[]]$mz; Ds = [double[]]$md; Sigs = [double[]]$ms; Kinds = [string[]]$mk
                  Values = [int[]]$bv.Values; Spec = (Build-CurveProfile $bv.Values); Sat = [int[]]@($bv.Sat); Floor = [int[]]@($bv.Floor)
                  Hist = @($hist); Version = $script:Version; Algo = $script:CalibAlgo
                  # 12.8 (lot 1c, G2) : 'lvl2' seulement pour une forme adaptee (une 12.7 relit les autres et ignore celles-ci)
                  LevelAlgo = $(if ($model -ne 'M0') { 'lvl2' } else { 'lvl1' }); Model = $model; S = [math]::Round($cs, 4); B = [math]::Round($cb, 2)
                  # 12.8 (F3R) : terme de centre (informatif), plafond de la courbe et cylindres au-dela de CalHardNs
                  Hc = $(if ($null -ne $hcv) { [math]::Round([double]$hcv, 2) } else { $null }); Hard = [int]$hard; Over = [int[]]@($over)
                  Mode = $(if ($u.Mode) { [string]$u.Mode } else { 'lvl1' }); Brand = [string]$cal.Brand; Ctl = [int[]]@($u.Ctl); K = $(if ($null -ne $kk) { [math]::Round($kk, 3) } else { $null }) }
        $script:LevelShifts[$hk] = $rec
        $recs += ,$rec; $verdicts += $verdict
    }
    # 12.7 point 5 : etat de la surface de la disquette a la premiere passe (Invoke-LevelSurface) : disquette douteuse,
    # defaut grossier poursuivi ou sans fenetre (calibration rapide sans ecriture) : reserve si la fenetre de decision
    # s ouvre pour une autre raison
    # Defaut de vitesse seul (arbitrage 12, Test-CalibSpeedOnly) : reserve qui nomme le controle de vitesse, pas le support
    if ($issues.Count -gt 0 -and $cal.Surf -and ($cal.Surf.Defective -or $cal.SurfGross)) {
        $issues.Add($(if ($cal.Surf.Defective) { Format-CalibSurfaceReserve $cal.Surf }
                      elseif (Test-CalibSpeedOnly $cal.Surf $cal.Medium) { (T "contrôle de vitesse et de densité : {0} à la première passe") -f (Format-CalibSurfaceVerdict $cal.Surf $cal.Medium) }
                      else { (T "support : {0} à la première passe") -f (Format-CalibSurfaceVerdict $cal.Surf $cal.Medium) }))
        $info.Add($false)
    }
    return @{ Issues = $issues; Info = $info; Recs = $recs; PrevRecs = $prevRecs; Verdicts = $verdicts }
}

function Get-LevelReviewPlan($cal, $res, [bool]$toWrite) {
    # 12.8 (lot 1c, § 7, G3) : fenetre de decision de la calibration rapide. Avertissement (point 2) : une tete a une forme
    # non conforme non adaptee ET un niveau non verifie, ou une forme adaptee avec reserve. « Calibration complete »
    # (G3) : seulement apres une forme non conforme non adaptee (repli ou refus), jamais pour un plafond, un « a
    # surveiller », un niveau adapte non verifie ou une reserve. Information : reserves d information seules et une tete
    # adaptee (ou partie de la forme d une marque, FIX1C) : « Ecrire l image » principal, en-tete de la courbe adaptee
    # (Verified : niveau verifie sur toutes les tetes adaptees), champ de marque si toutes les tetes sont verifiees
    # (adaptees sans reserve, ou niveau verifie)
    $units = @($cal.Units)
    $adapted = @($units | Where-Object { [string]$_.Mode -eq 'adapte' -and $_.AN -and [string]$_.AN.Model -ne 'M0' })
    # 12.8 (FIX1C, constat 5) : tete partie de la forme memorisee d une marque, sans nouvelle adaptation (courbe V' et
    # niveau) : courbe adaptee elle aussi, fenetre « information » aux memes conditions
    $memoCv = @($units | Where-Object { $_.Memo -and @('adapte', 'refus') -notcontains [string]$_.Mode })
    # 12.8 (FIX1C, constat 7) : en-tete « verifiee par une ecriture du motif » seulement si aucune tete adaptee (niveau seul
    # confirme compris) n a un niveau decale sans nouvelle ecriture
    $verified = (@($units | Where-Object { [string]$_.Mode -eq 'adapte' -and -not $_.Conv }).Count -eq 0)
    $mm = @($units | Where-Object { $_.Shape -and [string]$_.Shape.Verdict -eq 'mismatch' })
    $warnMm = (@($mm | Where-Object { -not $_.Conv }).Count -gt 0)
    $resv = @($adapted | Where-Object { $_.Conv -and @($_.AN.Reserve).Count -gt 0 })
    # 12.8 (F3R) : forme adaptee gardee avec reserve apres un controle hors tolerance (e2, W1), centre corrige par les
    # controles sans verification par une ecriture du motif (W2)
    $ctlR = @($adapted | Where-Object { $_.CtlReserve })
    $cenR = @($adapted | Where-Object { $_.AN.Center -and $_.AN.Center.Verified -eq $false })
    $warnText = if ($warnMm) { (T "Attention : niveau non vérifié et forme non conforme. La courbe que « Écrire l'image » utiliserait n'a pas été vérifiée sur cette disquette ; vers le centre, elle peut s'écarter de son besoin de plusieurs dizaines de ns.") }
                elseif ($resv.Count -gt 0) { (T "Attention : forme adaptée avec réserve (c{0} suspect). La courbe a été vérifiée, mais un défaut local de cette disquette est possible ; le contrôle après écriture sera fait.") -f "$($resv[0].AN.Suspect)" }
                elseif ($ctlR.Count -gt 0) { (T "Attention : forme adaptée avec réserve (contrôle c{0} hors tolérance). Vers le centre, la courbe peut s'écarter du besoin de cette disquette ; le contrôle après écriture sera fait.") -f "$(@(@($ctlR[0].CtlBad) | ForEach-Object { [int]$_ } | Sort-Object)[0])" }
                elseif ($cenR.Count -gt 0) { (T "Attention : forme adaptée avec réserve (centre corrigé par les contrôles {0}). Vers le centre, la courbe est extrapolée des contrôles, sans vérification par une écriture du motif ; le contrôle après écriture sera fait.") -f ((@($cenR[0].AN.Center.R.Keys | ForEach-Object { [int]$_ } | Sort-Object -Unique) | ForEach-Object { "c$_" }) -join ', ') }
                else { '' }
    $offerFull = [bool](($cal.CanFallback -or -not $toWrite) -and $mm.Count -gt 0)
    $infoOnly = ($res.Issues.Count -gt 0 -and -not ($res.Info -contains $false))
    $infoWin = [bool]($infoOnly -and -not $warnText -and -not $offerFull -and ($adapted.Count + $memoCv.Count) -gt 0)
    $brandAsk = [bool]($infoWin -and $cal.Slow -and @($units | Where-Object { -not (Get-LevelBrandVerified $_) }).Count -eq 0)
    $prefill = [string]$cal.Brand
    if ($brandAsk -and $prefill -and @(Get-LevelBrandPlan $cal $prefill | Where-Object { $_.Differs }).Count -gt 0) { $prefill = '' }
    $names = @(@($script:LevelBrands) | Where-Object { $_ -and [string]$_.Drive -eq [string]$cal.Drive } | Sort-Object { Get-CurveDate $_ } -Descending | ForEach-Object { [string]$_.Brand } | Select-Object -Unique)
    # 12.8 (S3, c4-design § 4.3) : « Mesure complete de cette disquette » (W-M1, OfferDisk) avant une ecriture lente hors
    # restauration (CanDisk), quand la disquette s ecarte de la reference : forme non conforme, forme adaptee avec reserve
    # (W1, W2, ecart suspect), courbe au-dela de CalHardNs (plafond par disquette) ou plafond atteint, besoin bien plus fort
    # que d habitude (J5, Fatigue). Complete-LevelCalib n affiche alors pas « Calibration complete » (OfferFull, inchange) :
    # elle remplacerait la reference du lecteur par une disquette d un autre type (risque G7)
    $over = @(@($res.Recs) | Where-Object { $_ -and (@($_.Over).Count -gt 0 -or @($_.Sat).Count -gt 0) })
    $fat = @($units | Where-Object { $_.Fatigue })
    $offerDisk = [bool]($toWrite -and $cal.CanDisk -and $cal.Slow -and $cal.Lr -and ($mm.Count + $resv.Count + $ctlR.Count + $cenR.Count + $over.Count + $fat.Count) -gt 0)
    $diskMin = if ($offerDisk) { Get-DiskMeasureMinutes ([int]$cal.MaxCyl + 1) } else { 0 }
    return @{ Warn = [bool]$warnText; WarnText = $warnText; OfferFull = $offerFull; Info = $infoWin; BrandAsk = $brandAsk; Brand = $prefill; Brands = $names; Adapted = $adapted; MemoCurve = $memoCv; Verified = $verified
              OfferDisk = $offerDisk; DiskMin = $diskMin }
}

function Complete-LevelCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsed = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $toWrite = ($script:AfterCalib -eq 'write')
    $famTxt = Get-CalibFamilyName $cal.Family
    $fails = @($cal.Units | Where-Object { $_.Fail })
    if ($fails.Count -gt 0) {
        foreach ($u in $fails) {
            if ($u.Fail -eq 'nowrite') { Append-Log ($u.Prefix + (T 'Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (tête ou circuit d''écriture défaillant ?).')) }
            else { Append-Log ((T "{0}Calibration rapide : moins de 3 cylindres mesurables, niveau impossible à estimer.") -f "$($u.Prefix)") }
        }
        $pbWCal.Visible = $false
        $nw = (@($fails | Where-Object { $_.Fail -eq 'nowrite' }).Count -gt 0)
        $lblWCal.Text = $(if ($nw) { (T 'Calibration rapide : une face ne réagit pas à la précompensation (voir le journal).') } else { (T 'Calibration rapide sans mesure exploitable.') })
        if ($toWrite -and $cal.SurfKept) {
            # 12.7 point 5 : « Ecrire quand meme » choisi dans la fenetre « Disquette a ecrire defectueuse » (face sans
            # cylindre mesurable, par exemple) : l image est ecrite comme annonce, avec la courbe du lecteur (champs
            # --precomp inchanges, aucun niveau mesure), comme une ecriture sans reference (decision 4)
            $script:AfterCalib = ''
            Append-Log (T "Mesure de la disquette sans niveau exploitable : écriture poursuivie à votre demande avec la courbe du lecteur, sans niveau mesuré.")
            if ($script:Restore) {
                $r = $script:Restore
                $nt = (T "niveau non mesuré : {0}") -f $(if ($nw) { (T 'une face ne réagit pas à la précompensation') } else { (T 'calibration rapide sans mesure exploitable') })
                $bt = if ($r.CalibUsed) { ((T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)") + ' ; ' } elseif ($r.CalSwap) { ((T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)") + ' ; ' } else { '' }
                $r.Level = @{ State = 'warn'; Text = "$bt$nt"; Report = $nt }
                $r.InCall = $true
            }
            try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip); if ($script:Restore) { Set-RestoreRepRules } } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
            if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
            return
        }
        Set-HomeProgDone $cal 'stop'
        if ($toWrite) { $script:AfterCalib = ''; Append-Log $(if ($nw) { (T 'Écriture annulée : une face ne réagit pas à la précompensation.') } else { (T 'Écriture annulée : calibration rapide sans mesure exploitable.') }) }
        if ($script:Restore) { Stop-Restore $(if ($nw) { (T 'une face ne réagit pas à la précompensation') } else { (T 'calibration rapide sans mesure exploitable') }) }
        return
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $res = Get-LevelUnitResults $cal $date
    $issues = $res.Issues; $recs = $res.Recs; $prevRecs = $res.PrevRecs; $verdicts = $res.Verdicts
    if (-not $script:Restore) { [void](Save-Config) }
    # 12.8 (FIX-PISTES-2) : Lbl $null quand le libelle porte l avis de la Bibliotheque (Get-WProfileText)
    $fieldsPrev = @{ Prof = $cmbWProfile.SelectedIndex; On = $chkWPrecomp.Checked; P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Lbl = (Get-WProfileText) }
    # Carte Calibration de l Accueil : profil place dans les champs --precomp seulement si l image de l onglet Ecriture est
    # de la famille calibree (sinon il reste affiche dans la fenetre Courbe, derniere calibration rapide)
    $toFields = (-not $cal.Home) -or ((Get-WriteTabFamily) -eq $cal.Family)
    if ($toFields) {
        if ($cmbWProfile.SelectedIndex -ne 0) { $cmbWProfile.SelectedIndex = 0 }   # Auto : profil decale remplace au prochain changement d image
        Set-LevelFields $recs $cal.Slow
    }
    $plan = Get-LevelReviewPlan $cal $res $toWrite
    # 12.8 (lot 1c) : courbe adaptee a cette disquette (forme ajustee, ou forme d une marque memorisee au depart)
    $adCurve = ($plan.Adapted.Count -gt 0) -or (@($cal.Units | Where-Object { $_.Memo -and [string]$_.Mode -ne 'adapte' }).Count -gt 0)
    $lvlTxt = (@($recs | ForEach-Object { Get-LevelLabel $_ })) -join ', '
    $sv = @($cal.Units | ForEach-Object { [string]$_.Shape.Verdict })
    $shapeTxt = if ($sv -contains 'mismatch') { (T 'NON CONFORME') } elseif ($verdicts -contains 'sat' -or $verdicts -contains 'low') { ((T 'non vérifiée (limite de 0 ou {0} ns atteinte)') -f "$($script:CalHardNs)") } elseif ($verdicts -contains 'few') { (T 'non vérifiée (trop peu de cylindres mesurés)') } elseif ($sv -contains 'adapte' -or @($plan.MemoCurve).Count -gt 0) { (T 'adaptée à cette disquette') } elseif ($sv -contains 'approx') { (T 'approximative') } else { (T 'conforme') }
    $lblWCal.Text = ((T "Calibration rapide terminée en {0} : niveau {1}, forme {2}.") -f (Format-CalDuration $elapsed), "$lvlTxt", "$shapeTxt")
    if ($toFields) {
        if ($adCurve) { $lblWProfileInfo.Text = ((T "Profil {0} de cette disquette (calibration rapide du {1}, lecteur {2}) : référence du {3} adaptée à cette disquette ({4}){5}. À n'utiliser que pour cette disquette (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($recs[0].RefDate)", "$lvlTxt", $(if ($cal.Brand) { (T ', marque « {0} »') -f "$($cal.Brand)" } else { '' })) }
        else { $lblWProfileInfo.Text = ((T "Profil {0} de cette disquette (calibration rapide du {1}, lecteur {2}) : référence du {3} décalée de {4}. À n'utiliser que pour cette disquette (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($recs[0].RefDate)", "$lvlTxt") }
    }
    else { Append-Log ((T "Calibration rapide depuis l'Accueil : l'image de l'onglet Écriture n'est pas de la famille {0}, le profil de cette disquette n'est pas placé dans ses champs --precomp ; il reste affiché dans la fenêtre Courbe (dernière calibration rapide).") -f "$famTxt") }
    Append-Log ((T "Calibration rapide terminée en {0} : {1} passe(s), {2} écritures de piste sur {3} cylindres (2 faces), aucune ailleurs.") -f (Format-CalDuration $elapsed), "$($cal.PassesDone)", "$($cal.TrackWrites)", "$(@($cal.Cyls).Count)")
    Append-Log ((T "Niveau retenu : {0}.") -f "$lvlTxt")
    foreach ($rec in $recs) { $pp = if ($null -eq $rec.Head) { '' } else { (T '[tête {0}] ') -f "$($rec.Head)" }; Append-Log ((T "{0}Profil {1} de cette disquette : {2}") -f "$pp", "$famTxt", "$($rec.Spec)") }
    if ($script:Restore) {
        $r = $script:Restore
        $cn = $false
        $base = if ($r.CalibUsed) { ((T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)") + $(if ($r.CalibUsed.Notes.Count -gt 0) { ' ; ' + ($r.CalibUsed.Notes -join ' ; ') } else { '' }) }
                elseif ($r.CalSwap) {
                    # Calibration faite pendant cette restauration, sur une disquette sacrifiee : sa non-convergence reste signalee
                    $fo = Get-ImageFamily $r.Orig
                    $cn = (@(@(0, 1) | Where-Object { $cvn = $script:PrecompCurves["${fo}_h$_"]; $cvn -and $cvn.Converged -eq $false }).Count -gt 0)
                    $am = @(@(0, 1) | ForEach-Object { $script:PrecompCurves["${fo}_h$_"] } | Where-Object { Test-CurveAtMax $_ })
                    $bt = if ($cn) { (T 'faite, non convergée sur une tête : voir le journal') } else { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
                    if ($am.Count -gt 0) { $bt += ' ; ' + ((T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $am[0])"); $cn = $true }
                    $bt
                } else { '' }
        $lt = (T "niveau mesuré sur la destination : {0} ({1} passe(s))") -f "$lvlTxt", "$($cal.PassesDone)"
        if ($shapeTxt -eq (T 'approximative')) { $lt += ' ; ' + ((T "forme {0}") -f "$shapeTxt") }
        if ($issues.Count -gt 0) { $lt += ' ; ' + ($issues -join ' ; ') }
        $r.Level = @{ State = $(if ($issues.Count -gt 0 -or $cn -or ($r.CalibUsed -and $r.CalibUsed.Notes.Count -gt 0)) { 'warn' } else { 'ok' }); Text = $(if ($base) { "$base ; $lt" } else { $lt }); Report = $lt }
    }
    $brandName = [string]$cal.Brand; $brandExplicit = $false
    if ($issues.Count -gt 0) {
        Append-Log ((T "Calibration : résultat douteux ({0}) : courbe affichée, décision demandée.") -f ($issues -join ' ; '))
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Carte Calibration de l Accueil sans profil dans les champs --precomp : textes de la decision sans ces champs
        $noFields = ([bool]$cal.Home -and -not $toFields)
        # 12.8 (lot 1c, point 2, § 7, G3) : avertissement, « Calibration complete » et fenetre « information » (Get-LevelReviewPlan)
        $script:CalReviewBrand = $null
        # 12.8 (S3) : « Mesure complete de cette disquette » (W-M1) a la place de « Calibration complete » quand elle est proposee
        $lv2 = @{ WarnText = $plan.WarnText; Info = $plan.Info; BrandAsk = $plan.BrandAsk; Brand = $plan.Brand; Brands = $plan.Brands; Verified = $plan.Verified
                  OfferDisk = $plan.OfferDisk; DiskMin = $plan.DiskMin }
        $showFull = [bool]($plan.OfferFull -and -not $plan.OfferDisk)
        try { $choice = Show-CalibReview $cal @($issues) $toWrite $showFull $noFields $false $null $plan.Warn $lv2 }
        finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($choice -eq 'stop' -or $choice -eq 'disk') {
            # Resultat refuse : niveaux precedents retablis, champs ramenes a la reference
            foreach ($k in @($prevRecs.Keys)) { if ($prevRecs[$k]) { $script:LevelShifts[$k] = $prevRecs[$k] } else { $script:LevelShifts.Remove($k) } }
            if (-not $script:Restore) { [void](Save-Config) }
            if ($cmbWProfile.SelectedIndex -ne $fieldsPrev.Prof) { $cmbWProfile.SelectedIndex = $fieldsPrev.Prof }
            Update-PrecompForImage $txtWFile.Text
            $chkWPrecomp.Checked = $fieldsPrev.On; $txtWPrecomp.Text = $fieldsPrev.P0; $txtWPrecomp1.Text = $fieldsPrev.P1
            if ($null -ne $fieldsPrev.Lbl) { $lblWProfileInfo.Text = $fieldsPrev.Lbl }
            if ($choice -eq 'disk') {
                # 12.8 (S3) : mesure complete de cette disquette, sur la reference en place (Start-DiskMeasure) ; la marque choisie
                # dans l avertissement de la calibration rapide est proposee de nouveau
                $pbWCal.Visible = $false
                Append-Log (T "Mesure complète de cette disquette demandée : le résultat de la calibration rapide n'est pas conservé.")
                $script:AfterCalib = ''
                Start-DiskMeasure $cal.Lr ([string]$cal.Brand)
                return
            }
            if ($script:Restore) { $script:Restore.Level = $null }     # niveau refuse : absent de l etape 4 et du rapport
            $pbWCal.Visible = $false
            if ($noFields) { $lblWCal.Text = (T 'Calibration rapide abandonnée.'); Append-Log (T 'Calibration rapide abandonnée à votre demande : niveau non conservé.') }
            else {
                $lblWCal.Text = (T 'Calibration rapide abandonnée : champs --precomp rétablis.')
                Append-Log (T 'Calibration rapide abandonnée à votre demande : niveau non conservé, champs --precomp rétablis.')
            }
            # 12.8 (lot 1c, point 1) : mesures des passes (Write-CalibPassLog, Write-LevelPassLog) gardees au journal
            Append-Log (T "Résultat refusé : les mesures ci-dessus restent au journal, rien n'est enregistré pour cette disquette.")
            if ($toWrite) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : résultat de calibration refusé.'); if ($script:Restore) { Stop-Restore (T 'résultat de calibration refusé') } }
            Set-HomeProgDone $cal 'abandon' $issues[0]
            return
        }
        # Calibration complete demandee : bilan avec reserves, remplace par la progression si elle demarre
        if ($choice -eq 'full') { Set-HomeProgDone $cal 'warn' $issues[0]; Start-LevelFallback $cal ($issues -join ' ; ') $toWrite $noFields; return }
        Append-Log (T 'Calibration : résultat accepté malgré les réserves.')
        # 12.8 (lot 1c, § 10.1) : marque nommee dans la fenetre « information » (champ vide : rien n est memorise)
        if ($plan.BrandAsk -and $null -ne $script:CalReviewBrand) {
            $brandName = ([string]$script:CalReviewBrand).Trim(); $brandExplicit = [bool]$brandName
            Append-Log $(if ($brandName) { (T 'Marque nommée dans la fenêtre de décision : « {0} ».') -f "$brandName" } else { (T 'Marque non nommée dans la fenêtre de décision : forme non mémorisée.') })
        }
    }
    # 12.8 (lot 1c, § 10.4, G5) : memoire de la marque (resultat accepte)
    if ($brandName) {
        Update-LevelBrands $cal $brandName $brandExplicit
        if (-not $script:Restore) { [void](Save-Config) }
    }
    Set-HomeProgDone $cal $(if ($issues.Count -gt 0) { 'warn' } else { 'ok' }) $(if ($issues.Count -gt 0) { $issues[0] } else { '' })
    if ($toWrite) {
        $script:AfterCalib = ''
        Append-Log (T 'Calibration rapide terminée : écriture de l''image avec le niveau mesuré.')
        # 12.8 (lot 1c, G1) : courbe adaptee a cette disquette : controle apres ecriture impose, meme case decochee (parade au
        # risque residuel d un defaut confondu avec la forme, a c2, et a l usure lisse : la consequence se voit a l ecriture)
        if ($adCurve) { $script:LevelPostForce = $true; Append-Log (T 'Contrôle après écriture imposé : courbe adaptée à cette disquette.') }
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Prechauffage passe pendant la calibration (bouton « Passer le prechauffage ») : pas de second prechauffage
        try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip); if ($script:Restore) { Set-RestoreRepRules } } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
        # Le profil decale ne vaut que pour cette disquette : remplace par celui de la reference quand l ecriture (controle
        # apres ecriture compris) est terminee (minuterie principale) ; positionne apres Start-ImageWrite, qui peut ouvrir
        # une fenetre avant de lancer gw
        if (-not $script:Restore) { $script:LevelFieldsPending = $true }
        return
    }
    $pbWCal.Visible = $false
    Show-PrecompCurve $cal.Family $cal.Slow
}

function Start-LevelFallback($cal, [string]$why, [bool]$toWrite, [bool]$noFields = $false) {
    # Calibration complete en test fin a la demande de l utilisateur, apres une calibration rapide douteuse : elle
    # devient la nouvelle reference ; sur disquette sacrifiee, le niveau de la disquette a ecrire est mesure ensuite.
    # noFields : calibration rapide de l Accueil dont le profil n est pas dans les champs --precomp (Complete-LevelCalib)
    Append-Log ((T "Calibration complète demandée après la calibration rapide ({0}).") -f "$why")
    # 12.8 (lot 1c, point 3, exception a D7 acceptee le 19/10) : confirmation sans compte a rebours, case « disquette
    # sacrifiee » obligatoire (Start-PrecompCalib, $script:CalFallbackAsk) ; avant une ecriture, la disquette a ecrire est
    # redemandee apres la calibration, puis mesuree (Swap, LevelAfter). Forme non conforme : texte du point 3 ; autre
    # reserve : texte de la 12.7, refus par « Fermer »
    $mm = (@($cal.Units | Where-Object { $_.Shape -and [string]$_.Shape.Verdict -eq 'mismatch' }).Count -gt 0)
    $introFmt = if ($mm) { (T "La forme de cette disquette ne correspond pas à la référence et n'a pas pu être adaptée ({0}). La calibration complète mesure de nouveau le lecteur sur une disquette sacrifiée : elle remplace la référence de forme du lecteur {1}, utilisée ensuite pour toutes vos disquettes. Une sauvegarde de la configuration est faite avant. Fermer : rien de plus n'est écrit.") }
                elseif ($noFields) { (T "La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Fermer : rien de plus n'est écrit.") }
                else { (T "La calibration rapide ne convient pas à cette disquette ({0}).`nCalibration complète en test fin ci-dessous : elle devient la nouvelle référence de forme du lecteur {1}. Fermer : rien de plus n'est écrit ; le profil décalé reste dans les champs --precomp.") }
    $intro = ($introFmt -f "$why", "$($cal.Drive)") + "`n`n"
    $script:CalFallbackAsk = @{ Swap = [bool]($toWrite -and -not $cal.Home) }
    # Carte Calibration de l Accueil : meme type de disquette (image de geometrie), et non l image de l onglet Ecriture
    if ($cal.Home) {
        Start-PrecompCalib -ForceFine -Intro $intro -Geom $cal.Geom -Heads ([bool]$cal.Slow)
        if ($script:Cal) { $script:HomeCalBusy = $true }
        return
    }
    if ($toWrite) { $script:AfterCalib = 'write' }
    Start-PrecompCalib -ForceFine -Intro $intro -LevelAfter:$toWrite
    if (-not $script:Cal -and $toWrite) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration n''a pas été lancée.') }
}

function Stop-LevelBrandCurve($cal, $gd) {
    # 12.8 (S3, c4-design § 4.2) : garde de la passe 1 (Get-LevelBrandCurveGuard) : calibration rapide arretee, journal
    # J-M2, fenetre W-M2 (frmConfirm) : « Calibration rapide sur la reference » (nouvelle calibration rapide sans marque,
    # budget d ecritures complet), « Mesure complete de cette disquette » (avant une ecriture, hors restauration) ou Fermer
    # (calibration interrompue, ecriture annulee). $script:Cal est encore cette calibration
    Append-Log ((T "Cette disquette ne ressemble pas à la courbe de la marque « {0} » ({1}) : calibration arrêtée après la passe 1.") -f "$($gd.Brand)", "$($gd.Why)")
    $toWrite = ($script:AfterCalib -eq 'write')
    $disk = [bool]($toWrite -and $cal.CanDisk -and $cal.Slow -and $cal.Lr)
    $min = if ($disk) { Get-DiskMeasureMinutes ([int]$cal.MaxCyl + 1) } else { 0 }
    $txt = if ($disk) { (T "Cette disquette ne ressemble pas à la marque « {0} ». Choisissez une calibration rapide sur la référence du lecteur (1 à 2 min) ou une mesure complète de cette disquette (environ {1} min).") -f "$($gd.Brand)", "$min" }
           else { (T "Cette disquette ne ressemble pas à la marque « {0} ». Relancez une calibration rapide sur la référence du lecteur (1 à 2 min), sans la marque.") -f "$($gd.Brand)" }
    $txt += "`n`n" + ((T 'Raison : {0}.') -f "$($gd.Why)") + "`n" + (T "Fermer : la calibration est interrompue et rien de plus n'est écrit.")
    $cq = @{ Title = (T 'Calibration precomp'); Heading = (T 'Disquette différente de la marque'); Level = 'warn'; Picto = 'warn'; Text = $txt
             GoText = (T 'Calibration rapide sur la référence'); GoGlyph = 'Diagnostic' }
    if ($disk) { $cq.AltText = (T 'Mesure complète de cette disquette (environ {0} min)') -f "$min" }
    $pbWCal.Visible = $false
    if ($script:Restore) { $script:Restore.InCall = $true }
    try { [void](Show-AppConfirm @cq) } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
    $choice = [string]$script:ConfirmChoice
    if ($choice -eq 'go') {
        $script:Cal = $null
        Append-Log (T 'Calibration rapide relancée sur la référence du lecteur, sans marque.')
        $script:LevelNoBrand = $true
        Start-LevelCalib $cal.Lr -NoConfirm -NoFallback:(-not $cal.CanFallback) -Geom $cal.Geom
        $script:LevelNoBrand = $false
        if (-not $script:Cal -and $toWrite) {
            $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.')
            if ($script:Restore) { Stop-Restore (T 'calibration interrompue') }
        }
        return
    }
    if ($choice -eq 'alt' -and $disk) {
        # Marque non proposee : cette disquette ne ressemble pas a la courbe de cette marque, que la mesure remplacerait
        $script:Cal = $null
        $script:AfterCalib = ''
        Start-DiskMeasure $cal.Lr ''
        return
    }
    Stop-PrecompCalib
}

function Start-LevelBeforeWrite([string]$mode, [switch]$Restore, [switch]$Measure) {
    # Ecriture depuis la Bibliotheque, le bouton ECRIRE (12.8, D5) ou la restauration avec « Test rapide » : niveau mesure
    # sur la disquette a ecrire. 12.8 (validation du 19/10) : sans reference utilisable, ecriture refusee (Bibliotheque et
    # ECRIRE ; 12.7 : calibration complete en test fin d abord, sur la disquette a ecrire) ; restauration : ecriture avec
    # la calibration existante, jamais refaite.
    # 12.7 point 5, Measure : mesure ajoutee a une ecriture lente par la case « Mesurer la disquette » (liste au test
    # standard ou fin) : sans reference utilisable, aucune calibration complete imposee, ecriture avec la courbe du lecteur
    $img = $txtWFile.Text
    $fam = Get-ImageFamily $img
    $nfc = Get-CalibCylinders $img $cmbWFmt.Text      # image secteur sans geometrie : cylindres du format choisi
    # 12.8.1 (spec-1281.md § A.1) : liste « Mesure : sur l image a ecrire » (levelBeforeWriteMode = content), ecriture
    # lente avec la case « Mesurer la disquette » (Measure), hors restauration : mesure de la disquette sur le contenu de
    # l image (276) si l image et le contexte s y pretent (Test-ContentMeasurable) ; sinon ligne de journal, puis la suite
    # de la 12.8 (calibration rapide au motif, ou courbe du lecteur sans reference). Test rapide et restauration : mesure
    # au motif, ligne de journal plus bas
    $content = ((Get-Setting 'levelBeforeWriteMode') -eq 'content')
    if ($content -and $Measure -and $mode -eq 'slow' -and -not $Restore -and -not $script:Restore) {
        $cm = Test-ContentMeasurable $img $cmbWFmt.Text
        if ($cm.Ok) { Start-ContentMeasure $cm; return }
        Append-Log ((T "Mesure sur l'image non faite ({0}) : calibration rapide au motif avant cette écriture.") -f "$($cm.Why)")
    }
    $lr = Get-LevelRef $fam ($mode -eq 'slow') $cmbDrive.Text $img ([bool]$Restore) -NCyl $(if ($null -ne $nfc.NCyl) { [int]$nfc.NCyl } else { 0 })
    if ($lr.Ok) {
        # 12.8 (S3, decision du 21/10/2026) : liste « Mesure : complète » de l onglet Ecriture (levelBeforeWriteMode) : mesure
        # complete de cette disquette avant une ecriture lente (une courbe par tete) ; ecriture rapide : calibration rapide,
        # avec une ligne de journal. 12.8 (S3-FLUX, decision 2) : aussi en restauration, copie secteur (Restore : seul appel,
        # Start-PresetWrite -LevelOnly ; une copie de flux n est jamais mesuree), ecriture lente toujours
        if ((Get-Setting 'levelBeforeWriteMode') -eq 'complete') {
            if ($mode -eq 'slow') {
                if ($Restore) { Append-Log (T "Restauration : disquette de destination mesurée sur tous ses cylindres (mesure complète de cette disquette, liste « Mesure » de l'onglet Écriture), la calibration du lecteur n'est pas refaite.") }
                Start-DiskMeasure $lr ([string]$script:LevelBrand); return
            }
            Append-Log (T "Mesure complète de cette disquette réservée à l'écriture lente (une courbe par tête) : calibration rapide avant cette écriture rapide.")
        }
        # 12.8.1 (decision 5) : avec « sur l image a ecrire », le Test rapide et la restauration gardent la mesure au motif
        if ($content -and -not $Measure) {
            if ($Restore) { Append-Log (T "Restauration : destination mesurée au motif (calibration rapide) ; la mesure sur l'image ne se fait pas en restauration.") }
            else { Append-Log (T "Test rapide : mesure au motif (calibration rapide) ; la mesure sur l'image ne se fait qu'en test standard ou fin, avec la case « Mesurer la disquette avant l'écriture lente ».") }
        }
        $script:AfterCalib = 'write'
        # 12.8 (S3-FLUX, F3R-FIX) : ligne exacte, sans « (test rapide) » : la mesure de la destination ne depend plus du test
        if ($Restore) { Append-Log (T 'Restauration : niveau et forme mesurés sur la disquette de destination (calibration rapide), la calibration du lecteur n''est pas refaite.') }
        Start-LevelCalib $lr -NoFallback:([bool]$Restore)
        if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.') }
        return
    }
    if ($Restore) {
        Append-Log ((T "Restauration : niveau non mesuré ({0}) : écriture avec la calibration existante.") -f "$($lr.Why)")
        if ($script:Restore) { $script:Restore.LevelNote = $lr.Why }
        Start-ImageWrite; return
    }
    if ($Measure) {
        # Arbitrage 16 : sans aucune courbe applicable (Get-FamilyCurves, tableau protege : pas de @() autour), le mode Auto
        # ecrit avec le profil d origine
        if ((Get-FamilyCurves $fam ($mode -eq 'slow')).Count -gt 0) { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : {0}. Écriture avec la courbe du lecteur ; une calibration complète en test fin servira de référence aux prochaines mesures.") -f "$($lr.Why)") }
        else { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : {0}. Écriture avec le profil d'origine ; une calibration complète en test fin servira de référence aux prochaines mesures.") -f "$($lr.Why)") }
        Start-ImageWrite; return
    }
    # Hors domaine : ecriture avec la courbe du lecteur, sauf si elle est plus courte que l image (gw appliquerait la valeur
    # de son dernier cylindre a tous les suivants) : refus, comme sans reference
    if ($lr.Class -eq 'domain' -and -not $lr.Short) {
        Append-Log ((T "Calibration rapide non applicable à cette image : {0}. Écriture avec la courbe du lecteur, sans mesure du niveau.") -f "$($lr.Why)")
        Start-ImageWrite; return
    }
    # 12.8 (decisions128.md, validations du 19/10) : aucune reference utilisable (aucune courbe de la famille, autre lecteur,
    # mesure sur le contenu d une image, reference trop courte...) : ecriture refusee, rien n est ecrit ni calibre sur la
    # disquette a ecrire. La reference se fait a part, sur une disquette sacrifiee, par la carte « Calibrer le lecteur » de
    # l Accueil ; Oui : Accueil affiche (Show-Tab, la carte y est). Premiere ligne du message : ligne de journal du refus
    # (Show-AppMessage ecrit le message au journal)
    $script:AfterCalib = ''
    $msg = ((T "Écriture refusée : le test rapide n'a pas de référence utilisable pour cette image ({0}). Rien n'a été écrit.") -f "$($lr.Why)") + "`n`n" +
           ((T "Le test rapide mesure la disquette à écrire à partir d'une calibration complète du lecteur {0}, faite au préalable sur une disquette sacrifiée du même type que la disquette à écrire. Calibrez d'abord le lecteur : carte « Calibrer le lecteur » de l'Accueil, avec une disquette sacrifiée.") -f "$($cmbDrive.Text)") + "`n`n" +
           (T "Afficher maintenant l'Accueil et sa carte « Calibrer le lecteur » ?")
    if ("$(Show-AppMessage $msg (T 'Calibration precomp') 'YesNo' 'Warning')" -eq 'Yes') { Show-Tab $tabH }
}

function Start-LevelCalibButton {
    # Bouton « Calibrer » avec « Test rapide » : niveau de la disquette inseree, sans ecriture d image
    $chk = Test-CalibImage
    if (-not $chk) { return }
    $lr = Get-LevelRef $chk.Family ([bool]$chkWSlow.Checked) $cmbDrive.Text $chk.Img $false -NCyl ([int]$chk.NCyl)
    if ($lr.Ok) { $script:AfterCalib = ''; Start-LevelCalib $lr; return }
    if ($lr.Class -eq 'domain' -and -not $lr.Short) {
        [void](Show-AppMessage ((T "Calibration rapide non applicable à cette image : {0}.") -f "$($lr.Why)") (T 'Calibration precomp') 'OK' 'Information'); return
    }
    # 12.8 (D3) : confirmation par frmConfirm, sans case : l avertissement de la calibration suit, avec sa confirmation
    $cq = @{ Title = (T 'Calibration precomp'); Heading = (T 'Calibration rapide impossible'); Level = 'info'; Picto = 'data'
             Text = ((T "Raison : {0}.`n`nLa calibration rapide reprend la forme d'une calibration complète du lecteur {1}. Lancez d'abord une calibration complète en test fin : elle devient la référence de forme du lecteur, reprise ensuite par chaque calibration rapide.") -f "$($lr.Why)", "$($cmbDrive.Text)")
             GoText = (T 'Calibration complète'); GoGlyph = 'Stopwatch' }
    if (Show-AppConfirm @cq) { $script:AfterCalib = ''; Start-PrecompCalib -ForceFine }
}

function Get-CurveLevelRecs($cv) {
    # Niveaux de la derniere calibration rapide faits sur cette courbe (meme date de reference, meme lecteur)
    if (-not $cv) { return ,@() }
    $key = @($script:CurveKeys | Where-Object { [object]::ReferenceEquals($script:PrecompCurves[$_], $cv) })
    if ($key.Count -eq 0) { return ,@() }
    $rs = @(@($script:LevelShifts.Values) | Where-Object { $_ -and $_.RefKey -eq $key[0] -and [string]$_.RefDate -eq [string]$cv.Date -and [string]$_.Drive -eq [string]$cv.Drive })
    if ($rs.Count -eq 0) { return ,@() }
    $latest = @($rs | Sort-Object { Get-CurveDate $_ } -Descending)[0].Date
    return ,@($rs | Where-Object { $_.Date -eq $latest } | Sort-Object { if ($null -eq $_.Head) { -1 } else { [int]$_.Head } })
}

function Set-CurveLevelData($cvs) {
    # Niveaux a superposer aux courbes affichees (index de la courbe -> enregistrements)
    $script:CurveLevel = @{}
    $i = 0
    foreach ($cv in @($cvs)) { $script:CurveLevel[$i] = Get-CurveLevelRecs $cv; $i++ }
}

function Get-CalibCylinders([string]$img, [string]$fmt) {
    # Cylindres d une image pour la calibration : lus dans l image (ADF, IPF, HFE) ; image secteur sans geometrie (IMG, ST,
    # DSK...) avec un format gw explicite de la table : cylindres de sa definition, 35 au moins comme la carte Calibration
    # de l Accueil (Get-FormatCalibInfo : une courbe de famille de 15 cylindres serait appliquee a toutes les images de 80) ;
    # sinon NCyl = $null (80 par defaut)
    $n = Get-ImageCylinders $img
    if ($null -ne $n) { return @{ NCyl = [int]$n; Src = ((T "{0} cylindres d'après l'image") -f "$n") } }
    if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) {
        $d = [int]$script:GwFormats[$fmt].Cyls; $c = [math]::Max(35, $d)
        if ($c -ne $d) { return @{ NCyl = $c; Src = ((T "{0} cylindres pour le format {1} ({2} dans la définition de gw, {0} au moins pour la calibration)") -f "$c", "$fmt", "$d") } }
        return @{ NCyl = $c; Src = ((T "{0} cylindres d'après le format {1}") -f "$c", "$fmt") }
    }
    return @{ NCyl = $null; Src = (T '80 cylindres par défaut (nombre non lisible dans l''image)') }
}

function Test-CalibImage($Geom = $null) {
    # Controles communs a la calibration complete et a la calibration rapide (memes messages) ; $null si refus. Geom :
    # type de disquette de la carte Calibration de l Accueil (image de geometrie de New-CalibGeometry, sans format gw) a la
    # place de l image et du format de l onglet Ecriture. Format gw explicite de la table non calibrable (FM, GCR, codage
    # propre, secteurs durs, ED, 360 tr/min, cellule hors plage : Get-FormatCalibInfo) : refus. 12.7 : image haute densite
    # admise si elle est calibrable (famille hd, Get-HdCalibFamily).
    if (-not $script:ScpStatsOk) {
        [void](Show-AppMessage (T 'Calibration : module d''analyse SCP indisponible (Add-Type).') (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    if (-not (Test-Path -LiteralPath $script:GwExe)) {
        [void](Show-AppMessage ((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)") (T 'Erreur') 'OK' 'Error'); return $null
    }
    $img = if ($Geom) { [string]$Geom.Img } else { $txtWFile.Text }
    $fmt = if ($Geom) { '' } else { $cmbWFmt.Text }
    if (-not $img -or -not (Test-Path -LiteralPath $img)) {
        [void](Show-AppMessage (T 'Choisissez d''abord l''image à écrire : elle fixe la famille (cellule) et le nombre de cylindres de la calibration.') (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) {
        [void](Show-AppMessage ((T "Calibration impossible sur un flux ({0}) : la calibration ne détermine la densité que d'une image à bits ou secteurs (ADF, IPF, HFE, IMG...).") -f "$ext") (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    $fci = if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) { Get-FormatCalibInfo $fmt } else { $null }
    $hd = Get-HighDensityReason $img $fmt
    # 12.7 : haute densite calibrable (famille hd) admise ; sinon refus, avec la raison du format s il est explicite
    if ($hd -and -not (Get-HdCalibFamily $img $fmt)) {
        $msg = if ($fci -and -not $fci.Cal) { (T "Calibration non prise en charge pour le format {0} : {1}.") -f "$fmt", "$($fci.Why)" }
               else { (T "Calibration non prise en charge pour cette image haute densité ({0}) : seule la haute densité MFM à 1 us par cellule et à 300 tr/min se calibre ; la très haute densité (ED), les codages propres et la haute densité à 360 tr/min ne se calibrent pas.") -f "$hd" }
        [void](Show-AppMessage $msg (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    if ($chkWHard.Checked -or $chkWTG43.Checked) {
        [void](Show-AppMessage (T 'Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43) : l''analyse de flux est calibrée pour le MFM double densité.') (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    $oor = Get-CellOutOfRange $img
    if ($null -ne $oor) {
        [void](Show-AppMessage ((T "Calibration non prise en charge : cellule de l'image de {0} ns, hors des plages mesurables (900 à 1 100 ns en haute densité, 1 700 à 2 300 ns en double densité).") -f "$oor") (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    if ($fci -and -not $fci.Cal) {
        [void](Show-AppMessage ((T "Calibration non prise en charge pour le format {0} : {1}.") -f "$fmt", "$($fci.Why)") (T 'Calibration precomp') 'OK' 'Warning'); return $null
    }
    $family = Get-ImageFamily $img $fmt
    $cc = Get-CalibCylinders $img $fmt
    $nCyl = $cc.NCyl
    $cylSrc = if ($Geom) { [string]$Geom.CylSrc } else { [string]$cc.Src }
    if ($null -eq $nCyl) { $nCyl = 80 }
    $nCyl = [math]::Max(2, [math]::Min(84, [int]$nCyl))
    $maxCyl = $nCyl - 1
    $label = if ($Geom) { [string]$Geom.Label } else { [System.IO.Path]::GetFileName($img) }
    return @{ Img = $img; Family = $family; NCyl = $nCyl; MaxCyl = $maxCyl; CylSrc = $cylSrc; Label = $label }
}
