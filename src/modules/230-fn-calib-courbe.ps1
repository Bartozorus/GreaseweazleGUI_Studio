# ============================== FONCTIONS : CALIBRATION : COURBES ==============

function Set-CalibScale([string]$fam) {
    # 12.7 : bareme de la famille calibree ('hd' : CalScaleHd ; autre ou vide : double densite, objets d origine) et borne
    # CalHardNs (haute densite : moitie de la borne configuree CalHardNsUser). Appele avant la creation de $script:Cal
    # (Start-PrecompCalib, Start-LevelCalib, Restart-PrecompCalib), au chargement de la configuration, par Set-Defaults et,
    # au repos, par le minuteur principal (filet de securite). Affectations explicites : pas de Set-Variable (portee des
    # tests).
    $hd = ($fam -eq 'hd')
    $t = if ($hd) { $script:CalScaleHd } else { $script:CalScaleDd }
    $script:CalCoarse = $t.CalCoarse; $script:CalMaxNs = $t.CalMaxNs; $script:CalBracketMargin = $t.CalBracketMargin
    $script:CalBracketStep = $t.CalBracketStep; $script:CalTrendSig = $t.CalTrendSig; $script:CalTrendRefSig = $t.CalTrendRefSig
    $script:CalContraMaxNs = $t.CalContraMaxNs; $script:CalDevNs = $t.CalDevNs; $script:CalDenseStep = $t.CalDenseStep
    $script:CalExtrapSigMin = $t.CalExtrapSigMin; $script:CalSigMax = $t.CalSigMax; $script:CalInterpDefault = $t.CalInterpDefault
    $script:CalSurfShiftMax = $t.CalSurfShiftMax; $script:CalCmpPointNs = $t.CalCmpPointNs; $script:CalCmpZoneNs = $t.CalCmpZoneNs
    $script:CalCmpSpotNs = $t.CalCmpSpotNs; $script:CalCmpPrefNs = $t.CalCmpPrefNs; $script:CalCmpLocalNs = $t.CalCmpLocalNs
    $script:LevelTauOk = $t.LevelTauOk; $script:LevelTauMax = $t.LevelTauMax
    $script:CalHardNs = if ($hd) { [int][math]::Round([double]$script:CalHardNsUser * $script:CalHdK) } else { $script:CalHardNsUser }
    $script:CalScaleFam = if ($hd) { 'hd' } else { 'dd' }
}

function Test-CurveHd($cv) {
    # 12.7 : courbe de la famille haute densite : motif de plus de 150 000 cellules (200 000, 202 688 ; DD 105 820 au plus)
    return [bool]($cv -and $null -ne $cv.Bits -and [int]$cv.Bits -ge 150000)
}

function Get-CurveDevNs($cv) {
    # 12.7 : ecart notable d une courbe enregistree (point marque, legende) : bareme de sa famille, hors de toute calibration
    if (Test-CurveHd $cv) { return [double]$script:CalScaleHd.CalDevNs }
    return [double]$script:CalScaleDd.CalDevNs
}

function Get-ImageCylinders([string]$path) {
    # Nombre de cylindres de l image, $null si non determinable
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    try {
        switch ($ext) {
            '.adf' {
                $len = (Get-Item -LiteralPath $path).Length
                if ($len % 11264 -eq 0) {                                   # 11264 = 2 faces x 11 secteurs x 512 (DD)
                    $c = $len / 11264
                    if ($c -gt 84 -and $len % 22528 -eq 0) { $c = $len / 22528 }   # HD : 22 secteurs
                    return [int]$c
                }
            }
            '.ipf' {
                $d = [System.IO.File]::ReadAllBytes($path); $max = -1; $pos = 0
                while ($pos + 12 -le $d.Length) {
                    $id = [System.Text.Encoding]::ASCII.GetString($d, $pos, 4); $ln = Get-BE32 $d ($pos + 4)
                    if ($ln -lt 12) { break }
                    if ($id -eq 'IMGE' -and $pos + 16 -le $d.Length) {
                        $t = Get-BE32 $d ($pos + 12)                       # champ track = cylindre
                        if ($t -gt $max -and $t -lt 200) { $max = $t }
                    } elseif ($id -eq 'DATA' -and $pos + 16 -le $d.Length) { $ln += Get-BE32 $d ($pos + 12) }
                    $pos += $ln
                }
                if ($max -ge 0) { return [int]($max + 1) }
            }
            '.hfe' {
                $fs = [System.IO.File]::OpenRead($path)
                try { $h = New-Object byte[] 16; [void]$fs.Read($h, 0, 16) } finally { $fs.Dispose() }
                if ($h[9] -gt 0) { return [int]$h[9] }                     # number_of_track
            }
        }
    } catch { }
    return $null
}

function Get-ImageFamily([string]$path, [string]$fmt = '') {
    # 12.7 : 'hd' pour une haute densite calibrable (Get-HdCalibFamily, format explicite ou implicite compris), sinon 'long'
    # si la cellule de l image est sous le seuil (long tracks), 'std' sinon : meme logique que le mode Auto
    $hf = Get-HdCalibFamily $path $fmt; if ($hf) { return $hf }
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    $info = $null
    try {
        switch ($ext) {
            '.ipf' { $info = Get-IpfCellInfo $path }
            '.hfe' { $info = Get-HfeCellInfo $path }
        }
    } catch { $info = $null }
    if ($null -ne $info -and $info.CellNs -lt $script:PrecompThresholdNs) { return 'long' }
    return 'std'
}

function Format-CylList([int[]]$cyls) {
    $s = @($cyls | Sort-Object -Unique)
    $contig = $true
    for ($i = 1; $i -lt $s.Count; $i++) { if ($s[$i] -ne $s[$i - 1] + 1) { $contig = $false; break } }
    if ($contig -and $s.Count -gt 1) { return "$($s[0])-$($s[-1])" }
    return ($s -join ',')
}

function Get-CalibTrackScore($st) {
    # Score de qualite (jitter 2T + asymetrie 3T/4T + hors classe) sur les tours lisibles ; 9999 = illisible
    foreach ($x in $st) { if ([double]::IsNaN($x.Jitter) -or [double]::IsNaN($x.R3) -or [double]::IsNaN($x.R4)) { return 9999 } }
    $j   = ($st | Measure-Object -Property Jitter -Average).Average
    $r3  = ($st | Measure-Object -Property R3 -Average).Average
    $r4  = ($st | Measure-Object -Property R4 -Average).Average
    $ooc = ($st | Measure-Object -Property OutOfClass -Average).Average
    return ($j + 2000 * ([math]::Abs($r3 - 1.5) + [math]::Abs($r4 - 2.0)) + 5 * $ooc)
}


function Get-CalibFamilyName([string]$family) {
    if ($family -eq 'long') { return (T 'Long track 1,89 us') }
    if ($family -eq 'hd') { return (T 'Haute densité 1 us') }
    return (T 'Standard 2 us')
}

function Get-SpecValue([string]$spec, [int]$cyl) {
    # Valeur de precomp appliquee par gw au cylindre : derniere entree c=ns dont c <= cylindre (entrees croissantes)
    $v = 0
    foreach ($m in [regex]::Matches($spec, '(\d+)\s*=\s*(\d+)')) { if ([int]$m.Groups[1].Value -le $cyl) { $v = [int]$m.Groups[2].Value } }
    return $v
}

function Get-CurveX([string]$model, [double]$c, [int]$maxCyl) {
    # Abscisse du modele pour le cylindre c. u = 0 (exterieur) a 1 (dernier cylindre de l image).
    # Rayon relatif : 3,5" de 39,5 a 24,7 mm (rapport 0,625) ; 5,25" 40 ou 80 pistes : rapport voisin (0,63).
    $u = $c / [math]::Max(1, $maxCyl)
    $r = 1.0 - 0.375 * $u
    switch ($model) {
        'inv'  { return 1.0 / $r }
        'inv2' { return 1.0 / ($r * $r) }
        default { return $u }
    }
}

function Get-Median($a) {
    $s = @($a | ForEach-Object { [double]$_ } | Sort-Object)
    if ($s.Count -eq 0) { return 0.0 }
    if ($s.Count % 2 -eq 1) { return [double]$s[[int][math]::Floor($s.Count / 2)] }
    return ([double]$s[$s.Count / 2 - 1] + [double]$s[$s.Count / 2]) / 2
}

function Get-IsolatedPoints($cs, $est, $sig) {
    # Donnees denses (test fin, mesures complementaires) : point isole = au moins un voisin mesure a 3 cylindres au plus
    # de chaque cote (2 au plus par cote), ecart a la mediane des voisins > max(15 ns ; 4 incertitudes) alors que les
    # deux cotes s accordent (ecart < meme seuil) : defaut ponctuel de la disquette de calibration, non suivi par la
    # courbe. 10 % des points et 4 au plus, jamais le premier ni le dernier. 15 ns : CalDevNs (bareme de la famille, 12.7).
    $cand = @()
    for ($i = 1; $i -lt $cs.Count - 1; $i++) {
        $c = [int]$cs[$i]
        $left = @(); for ($j = $i - 1; $j -ge 0 -and $left.Count -lt 2; $j--) { if ($c - [int]$cs[$j] -le 3) { $left += [double]$est[[int]$cs[$j]] } else { break } }
        $right = @(); for ($j = $i + 1; $j -lt $cs.Count -and $right.Count -lt 2; $j++) { if ([int]$cs[$j] - $c -le 3) { $right += [double]$est[[int]$cs[$j]] } else { break } }
        if ($left.Count -eq 0 -or $right.Count -eq 0) { continue }
        $s = if ($sig -and $sig.ContainsKey($c)) { [double]$sig[$c] } else { 5.0 }
        $thr = [math]::Max($script:CalDevNs, 4.0 * $s)
        $r = [double]$est[$c] - (Get-Median (@($left) + @($right)))
        if ([math]::Abs($r) -gt $thr -and [math]::Abs((Get-Median $left) - (Get-Median $right)) -lt $thr) { $cand += ,@($c, $r) }
    }
    $max = [int][math]::Min(4, [math]::Floor($cs.Count * 0.1))
    $out = @{}
    if ($max -le 0) { return $out }
    foreach ($x in @($cand | Sort-Object { -[math]::Abs([double]$_[1]) } | Select-Object -First $max)) { $out[[int]$x[0]] = [double]$x[1] }
    return $out
}

function Fit-PrecompCurve($est, $sig, [int]$maxCyl, $kinds = $null, [bool]$dense = $false) {
    # Courbe de precompensation par cylindre a partir des estimations des cylindres testes.
    # Moindres carres ponderes (poids = 1 / incertitude^2) de p = A + B.x, B >= 0, pour trois formes
    # physiquement plausibles (densite lineaire croissante vers l interieur) : x = cylindre, 1/rayon,
    # 1/rayon^2 ; la forme de plus faible ecart pondere est retenue. Si elle n explique pas les mesures
    # (chi2 reduit > 4 avec au moins 4 points), interpolation monotone des mesures lissees (PAVA).
    # Donnees denses : points isoles ecartes (poids nul : la courbe passe par l interpolation de leurs voisins)
    $csAll = @($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($csAll.Count -eq 0) { return $null }
    $outl = @{}
    if ($dense -and $csAll.Count -ge 8) { $outl = Get-IsolatedPoints $csAll $est $sig }
    $cs = @($csAll | Where-Object { -not $outl.ContainsKey($_) })
    $ys = @($cs | ForEach-Object { [double]$est[$_] })
    $ws = @($cs | ForEach-Object { $s = if ($sig -and $sig.ContainsKey($_)) { [math]::Max(1.0, [double]$sig[$_]) } else { 5.0 }; 1.0 / ($s * $s) })
    $best = $null
    foreach ($model in 'lin', 'inv', 'inv2') {
        $xs = @($cs | ForEach-Object { Get-CurveX $model $_ $maxCyl })
        $sw = 0.0; $sx = 0.0; $sy = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $sw += $ws[$i]; $sx += $ws[$i] * $xs[$i]; $sy += $ws[$i] * $ys[$i] }
        $mx = $sx / $sw; $my = $sy / $sw
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $sxx += $ws[$i] * ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += $ws[$i] * ($xs[$i] - $mx) * ($ys[$i] - $my) }
        $b = if ($cs.Count -ge 2 -and $sxx -gt 0) { [math]::Max(0.0, $sxy / $sxx) } else { 0.0 }
        $a = $my - $b * $mx
        $ssr = 0.0
        for ($i = 0; $i -lt $cs.Count; $i++) { $e = $ys[$i] - ($a + $b * $xs[$i]); $ssr += $ws[$i] * $e * $e }
        if ($null -eq $best -or $ssr -lt $best.Ssr) { $best = @{ Model = $model; A = $a; B = $b; Ssr = $ssr } }
    }
    $chi = $best.Ssr / [math]::Max(1, $cs.Count - 2)
    $vals = New-Object int[] ($maxCyl + 1)
    if ($cs.Count -ge 4 -and $chi -gt 4.0) {
        # Monotone par segments (CurveFit) : le besoin peut redescendre une ou deux fois, seulement sur une chute nette
        # (plus de 15 ns et de 3 incertitudes) entre deux mesures encadrees ; sinon croissant (PAVA). Puis lineaire
        # entre cylindres testes.
        $fyS = $null; $model = 'iso'; $breaks = @(); $segs = $null
        if ($script:CurveFitOk) {
            $rel = [bool[]]@($cs | ForEach-Object { -not $kinds -or -not $kinds.ContainsKey($_) -or $kinds[$_] -eq 'interp' })
            $sg = @($cs | ForEach-Object { if ($sig -and $sig.ContainsKey($_)) { [math]::Max(1.0, [double]$sig[$_]) } else { 5.0 } })
            $minDrop = [math]::Max($script:CalDevNs, 3.0 * [math]::Sqrt(2.0) * (Get-Median $sg))
            $r = [CurveFit]::SegFit([double[]]$ys, [double[]]$ws, $rel, 4.0 * [math]::Log($cs.Count), $minDrop)
            $K = [int]$r[0]
            $fyS = @($r[4..($r.Count - 1)])
            if ($K -ge 1) {
                $pk = [int]$cs[[int]$r[1] - 1]
                $tr = if ($K -eq 2) { [int]$cs[[int]$r[2] - 1] } else { $maxCyl }
                $model = 'seg'
                $breaks = if ($K -eq 2) { @($pk, $tr) } else { @($pk) }
                $segs = @(@{ Lo = 0; Hi = $pk; Dir = 1 }, @{ Lo = $pk + 1; Hi = $tr; Dir = -1 })
                if ($K -eq 2 -and $tr -lt $maxCyl) { $segs += @{ Lo = $tr + 1; Hi = $maxCyl; Dir = 1 } }
            }
        }
        if ($null -ne $fyS) {
            $fy = $fyS
            for ($c = 0; $c -le $maxCyl; $c++) {
                if ($c -le $cs[0]) { $v = $fy[0] }
                elseif ($c -ge $cs[-1]) { $v = $fy[-1] }
                else {
                    $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
                    $tt = ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j])
                    $v = $fy[$j] + $tt * ($fy[$j + 1] - $fy[$j])
                }
                $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
            }
            return @{ Model = $model; A = $null; B = $null; Chi = $chi; Values = $vals; Breaks = $breaks; Segs = $segs; Outliers = @($outl.Keys) }
        }
        # Repli sans CurveFit : interpolation monotone croissante (PAVA pondere sur les mesures)
        $blocks = New-Object System.Collections.Generic.List[object]
        for ($i = 0; $i -lt $cs.Count; $i++) {
            $blocks.Add(@{ SW = $ws[$i]; SWY = $ws[$i] * $ys[$i]; N = 1 })
            while ($blocks.Count -ge 2) {
                $p = $blocks[$blocks.Count - 2]; $q = $blocks[$blocks.Count - 1]
                if ($p.SWY / $p.SW -le $q.SWY / $q.SW) { break }
                $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
                $blocks.Add(@{ SW = $p.SW + $q.SW; SWY = $p.SWY + $q.SWY; N = $p.N + $q.N })
            }
        }
        $fy = @(); foreach ($bk in $blocks) { for ($k = 0; $k -lt $bk.N; $k++) { $fy += $bk.SWY / $bk.SW } }
        for ($c = 0; $c -le $maxCyl; $c++) {
            if ($c -le $cs[0]) { $v = $fy[0] }
            elseif ($c -ge $cs[-1]) { $v = $fy[-1] }
            else {
                $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
                $t = ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j])
                $v = $fy[$j] + $t * ($fy[$j + 1] - $fy[$j])
            }
            $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
        }
        return @{ Model = 'iso'; A = $null; B = $null; Chi = $chi; Values = $vals; Breaks = @(); Segs = $null; Outliers = @($outl.Keys) }
    }
    for ($c = 0; $c -le $maxCyl; $c++) {
        $v = $best.A + $best.B * (Get-CurveX $best.Model $c $maxCyl)
        $vals[$c] = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($v, 0)))
    }
    return @{ Model = $best.Model; A = $best.A; B = $best.B; Chi = $chi; Values = $vals; Breaks = @(); Segs = $null; Outliers = @($outl.Keys) }
}

function Add-CurveCorrection($values, $delta, $segs = $null) {
    # Valeurs par cylindre + corrections locales (ns) mesurees aux cylindres verifies, segment par segment (courbe
    # monotone par segments : jamais d interpolation ni de lissage a travers un changement de sens) : interpolation
    # lineaire des corrections des cylindres verifies du segment (0 la ou le residu est dans la tolerance), constante
    # jusqu aux bords du segment, puis lissage monotone dans le sens du segment (PAVA) et arrondi a l entier.
    $v = @($values); $n = $v.Count
    if (-not $segs) { $segs = @(@{ Lo = 0; Hi = $n - 1; Dir = 1 }) }
    $out = New-Object int[] $n
    for ($c = 0; $c -lt $n; $c++) { $out[$c] = [int]$v[$c] }
    foreach ($sg in @($segs)) {
        $lo = [math]::Max(0, [int]$sg.Lo); $hi = [math]::Min($n - 1, [int]$sg.Hi)
        if ($hi -lt $lo) { continue }
        $ks = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -ge $lo -and $_ -le $hi } | Sort-Object)
        if ($ks.Count -gt 0 -and @($segs).Count -gt 1) {
            # Ancrage aux bords : cylindre verifie le plus proche dans le segment voisin (sommet ou creux), pour que la
            # correction parte de la sienne au lieu de s appliquer telle quelle jusqu au changement de sens
            $kl = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt $lo } | Sort-Object)
            $kr = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -gt $hi } | Sort-Object)
            if ($kl.Count -gt 0) { $ks = @(@($kl[-1]) + $ks) }
            if ($kr.Count -gt 0) { $ks = @($ks + @($kr[0])) }
        }
        $raw = New-Object double[] ($hi - $lo + 1)
        for ($c = $lo; $c -le $hi; $c++) {
            $d = 0.0
            if ($ks.Count -gt 0) {
                if ($c -le $ks[0]) { $d = [double]$delta[$ks[0]] }
                elseif ($c -ge $ks[-1]) { $d = [double]$delta[$ks[-1]] }
                else {
                    $j = 0; while ($ks[$j + 1] -lt $c) { $j++ }
                    $tt = ($c - $ks[$j]) / [double]($ks[$j + 1] - $ks[$j])
                    $d = [double]$delta[$ks[$j]] + $tt * ([double]$delta[$ks[$j + 1]] - [double]$delta[$ks[$j]])
                }
            }
            $raw[$c - $lo] = ([double]$v[$c] + $d) * [int]$sg.Dir
        }
        $blocks = New-Object System.Collections.Generic.List[object]
        foreach ($x in $raw) {
            $blocks.Add(@{ S = $x; N = 1 })
            while ($blocks.Count -ge 2) {
                $p = $blocks[$blocks.Count - 2]; $q = $blocks[$blocks.Count - 1]
                if ($p.S / $p.N -le $q.S / $q.N) { break }
                $blocks.RemoveAt($blocks.Count - 1); $blocks.RemoveAt($blocks.Count - 1)
                $blocks.Add(@{ S = $p.S + $q.S; N = $p.N + $q.N })
            }
        }
        $c = $lo
        foreach ($bk in $blocks) { $m = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($bk.S / $bk.N * [int]$sg.Dir, 0))); for ($k = 0; $k -lt $bk.N; $k++) { $out[$c++] = $m } }
    }
    return ,$out
}

function Build-CurveProfile($values) {
    # Valeurs par cylindre -> profil --precomp : une entree c=ns a chaque changement (gw : valeur pour c et au-dela)
    $v = @($values)
    if ($v.Count -eq 0) { return '' }
    $parts = @("0=$($v[0])")
    for ($c = 1; $c -lt $v.Count; $c++) { if ($v[$c] -ne $v[$c - 1]) { $parts += "$c=$($v[$c])" } }
    return ($parts -join ':')
}

function Get-CurveModelName([string]$model) {
    if ($model -match '^(.+)\+c$') { return (Get-CurveModelName $Matches[1]) + (T ' + corrections locales') }
    switch ($model) {
        'lin'  { return (T 'linéaire') }
        'inv'  { return (T '1/rayon') }
        'inv2' { return (T '1/rayon²') }
        'iso'  { return (T 'monotone interpolée') }
        'seg'  { return (T 'monotone par segments') }
        default { return $model }
    }
}

function Format-CurveTable($cvs) {
    # Tableau texte des valeurs par cylindre (10 par ligne), profil --precomp, puis mesures avec leur origine, l ecart
    # de la courbe et le residu de la derniere verification, pour chaque courbe
    $lines = @()
    $kn = @{ witness = (T 'témoin de marche'); probe = (T 'témoin du plafond') }
    foreach ($cv in @($cvs)) {
        if ($lines.Count -gt 0) { $lines += ''; $lines += '' }
        $lrs = Get-CurveLevelRecs $cv
        foreach ($rec in @($lrs)) {
            $vk = if ([string]$rec.Shape -eq 'mismatch') { 'mismatch' } else { [string]$rec.Verdict }
            $vt = @{ ok = (T 'conforme'); approx = (T 'approximative'); mismatch = (T 'NON CONFORME'); sat = (T 'non vérifiée, plafond atteint'); low = (T 'non vérifiée, plancher atteint'); few = (T 'non vérifiée, trop peu de cylindres mesurés'); adapte = (T 'adaptée à cette disquette'); mesure = (T 'mesurée sur cette disquette') }[$vk]
            $hp = if ($null -eq $rec.Head) { '' } else { (T '[tête {0}] ') -f "$($rec.Head)" }
            # 12.8 (S3) : courbe d une mesure complete de cette disquette : ecart moyen a la reference, sans niveau mesure
            if ([string]$rec.Model -eq 'mesure') { $lines += ($hp + ((T "Dernière mesure complète d'une disquette ({0}, lecteur {1}) : courbe mesurée sur tous ses cylindres, écart moyen à cette référence {2} ns ; {3} passe(s) ; profil appliqué : {4}") -f "$($rec.Date)", "$($rec.Drive)", ('{0:+0;-0;0}' -f [int]$rec.Delta), "$($rec.Passes)", "$($rec.Spec)")) }
            else { $lines += ($hp + ((T "Dernière calibration rapide ({0}, lecteur {1}) : niveau {2} ns ± {3} ; écart de forme {4} ns ; forme {5} ; {6} passe(s) ; profil appliqué : {7}") -f "$($rec.Date)", "$($rec.Drive)", ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), (Format-LevelNum $rec.Tau), "$vt", "$($rec.Passes)", "$($rec.Spec)")) }
            for ($i = 0; $i -lt @($rec.Cyls).Count; $i++) {
                $kd = [string]$rec.Kinds[$i]; $kt = if ($kn.ContainsKey($kd)) { $kn[$kd] } else { Get-KindName $kd }
                $lines += ((T "  c{0,-3} zéro {1,6:0.0} ± {2,4:0.0}  écart à la forme {3,6:+0.0;-0.0;0.0}  {4}") -f [int]$rec.Cyls[$i], [double]$rec.Zs[$i], [double]$rec.Sigs[$i], $(if ([double]::IsNaN([double]$rec.Est)) { '-' } else { [double]$rec.Ds[$i] - [double]$rec.Est }), "$kt")
            }
            $hv = @(@($rec.Hist) | ForEach-Object { [double]$_.Delta })
            if ($hv.Count -gt 0) { $lines += ((T "Niveaux mesurés avec cette référence : médiane {0} ns, de {1} à {2} ns, {3} disquette(s).") -f ('{0:+0;-0;0}' -f [math]::Round((Get-Median $hv), 0)), ('{0:+0;-0;0}' -f ($hv | Measure-Object -Minimum).Minimum), ('{0:+0;-0;0}' -f ($hv | Measure-Object -Maximum).Maximum), "$($hv.Count)") }
            $lines += ''
        }
        if ($null -ne $cv.Head) { $lines += ((T "Tête {0} : courbe {1}") -f "$($cv.Head)", (Get-CurveModelName $cv.Model)) }
        $lines += ((T "Calcul de calibration : {0}") -f (Get-CurveCalcText $cv))
        if ($cv.Converged -eq $false) { $lines += (T 'NON CONVERGÉE : résidu hors tolérance après la dernière vérification (voir « résidu »).') }
        $v = @($cv.Values)
        $lines += @(((T "Profil --precomp : {0}") -f "$($cv.Spec)"), '', ('cyl  ' + ((0..9 | ForEach-Object { '{0,5}' -f "+$_" }) -join '')))
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $row = @(); for ($c = $c0; $c -lt [math]::Min($v.Count, $c0 + 10); $c++) { $row += ('{0,5}' -f $v[$c]) }
            $lines += ('{0,3}  ' -f $c0) + ($row -join '')
        }
        $lines += ''
        $lines += (T "Mesures (cylindre : estimation ± incertitude en ns, origine, courbe retenue et écart, résidu de vérification) :")
        for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
            $c = [int]$cv.Cyls[$i]
            $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { Get-KindName $cv.Kinds[$i] } else { '' }
            $cur = if ($c -lt $v.Count) { $v[$c] } else { $null }
            $dev = if ($null -ne $cur) { '{0:+0;-0;0}' -f ($cur - [double]$cv.Ys[$i]) } else { '' }
            # Zone non reproductible (verifications contradictoires) : valeur retenue sans mesure a cette valeur
            $res = if (@($cv.Contra) -contains $c) { (T 'zone non reproductible') }
                   elseif ($cv.Res -and $i -lt @($cv.Res).Count -and -not [double]::IsNaN([double]$cv.Res[$i])) { (T 'résidu {0}') -f ('{0:+0.0;-0.0;0.0}' -f [double]$cv.Res[$i]) } else { '' }
            $lines += ("  c{0,-3} {1,6:0.0} ± {2,4:0.0}  {3,-11} {4} {5,4} ({6,4})  {7}" -f $c, [double]$cv.Ys[$i], [double]$cv.Sig[$i], $kind, (T 'courbe'), $cur, $dev, $res).TrimEnd()
        }
    }
    return ($lines -join "`r`n")
}

function Draw-PrecompCurve($g, $size) {
    # Une courbe (profil commun) ou une par tete (ecriture lente). Mesures selon leur origine : point plein = encadree
    # par deux mesures, cercle creux = extrapolee, carre creux = plafonnee ; anneau rouge = ecart a la courbe > max(15 ns ; 3 incertitudes).
    # Zone hachuree : au-dessus de la plus forte precomp mesuree (extrapolation).
    $cvs = @(@($script:CurveData) | Where-Object { $_ })
    if ($cvs.Count -eq 0) { return }
    $multi = $cvs.Count -gt 1
    # 12.7 point 2 : comparaison des calibrations A et B (copies marquees Series 'A' ou 'B', Show-CalibReview) : couleur par
    # tete, B en tirets, zones de desaccord ($script:CurveZones) en bandes verticales. Sans Series : dessin inchange
    $cmp = (@($cvs | Where-Object { $_.Series }).Count -gt 0)
    # Niveaux de la derniere calibration rapide, superposes a chaque courbe (Set-CurveLevelData)
    $lvls = @{}; $hasLevel = $false
    for ($k = 0; $k -lt $cvs.Count; $k++) {
        # Affectation directe : un if renverrait un enregistrement seul deroule (table de hachage, pas tableau)
        $lvls[$k] = @()
        if ($script:CurveLevel -and $script:CurveLevel.ContainsKey($k)) { $lvls[$k] = @($script:CurveLevel[$k]) }
        if ($lvls[$k].Count -gt 0) { $hasLevel = $true }
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)
    $W = $size.Width; $H = $size.Height
    $nRec = @(@($lvls.Values) | ForEach-Object { $_ }).Count       # un enregistrement de niveau par ligne de legende
    $L = 56; $R = 20; $Tp = $(if ($hasLevel) { 92 + 20 * [math]::Max(0, $nRec - 1) } else { 72 }); $Bm = 40
    $zones = @(@($script:CurveZones) | Where-Object { $_ })
    if ($cmp) {
        # Legende : une ligne par tete (A puis B), plus une ligne pour les zones de desaccord
        $nh = @($cvs | Where-Object { $null -ne $_.Head } | ForEach-Object { [int]$_.Head } | Sort-Object -Unique).Count
        $Tp = 72 + 20 * ([math]::Max(1, $nh) - 1) + $(if ($zones.Count) { 20 } else { 0 })
    }
    $pw = $W - $L - $R; $ph = $H - $Tp - $Bm
    if ($pw -lt 60 -or $ph -lt 40) { return }
    $nC = 2; foreach ($cv in $cvs) { $nC = [math]::Max($nC, @($cv.Values).Count) }
    $maxC = $nC - 1
    $top = 0.0; $maxX = 0
    foreach ($cv in $cvs) {
        foreach ($x in @($cv.Values)) { if ($x -gt $top) { $top = $x } }
        for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) { $t = [double]$cv.Ys[$i] + [double]$cv.Sig[$i]; if ($t -gt $top) { $top = $t } }
        if ($cv.MaxX -and [int]$cv.MaxX -gt $maxX) { $maxX = [int]$cv.MaxX }
    }
    foreach ($k in @($lvls.Keys)) { foreach ($rec in $lvls[$k]) {
        foreach ($x in @($rec.Values)) { if ($x -gt $top) { $top = $x } }
        for ($i = 0; $i -lt @($rec.Zs).Count; $i++) { $tz = [double]$rec.Zs[$i] + [double]$rec.Sigs[$i]; if ($tz -gt $top) { $top = $tz } }
    } }
    $step = if ($top -le 120) { 20 } elseif ($top -le 400) { 50 } else { 100 }      # pas de 50 jusqu a la borne CalHardNs
    $ymax = [math]::Max(2 * $step, [math]::Ceiling($top / $step) * $step)
    $fx = { param($c) $L + $pw * $c / $maxC }
    $fy = { param($v) $Tp + $ph * (1.0 - $v / $ymax) }
    $font = New-Object System.Drawing.Font('Segoe UI', 8.25)
    $fontB = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
    $grid = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(228, 232, 238), 1)
    $axis = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 156, 166), 1)
    $err = New-Object System.Drawing.Pen($script:Theme.Muted, 1.2)
    $flag = New-Object System.Drawing.Pen($script:Theme.Danger, 1.8)
    $txt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 76, 88))
    $red = New-Object System.Drawing.SolidBrush($script:Theme.Danger)
    $gray = New-Object System.Drawing.SolidBrush($script:Theme.Muted)
    $grayPen = New-Object System.Drawing.Pen($script:Theme.Muted, 1.6)
    $hatch = New-Object System.Drawing.Drawing2D.HatchBrush([System.Drawing.Drawing2D.HatchStyle]::BackwardDiagonal, [System.Drawing.Color]::FromArgb(222, 226, 232), [System.Drawing.Color]::White)
    $colors = @($script:Theme.Accent, $script:Theme.Flux)
    $pens = @(); $dots = @(); $hollow = @()
    for ($i = 0; $i -lt $cvs.Count; $i++) {
        $col = if ($cmp) { $colors[[math]::Min($(if ($null -ne $cvs[$i].Head) { [int]$cvs[$i].Head } else { 0 }), 1)] } else { $colors[[math]::Min($i, 1)] }
        $dc = if ($multi) { $col } else { $script:Theme.Flux }
        $pn = New-Object System.Drawing.Pen($col, 2.2)
        if ($cmp -and [string]$cvs[$i].Series -eq 'B') { $pn.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
        $pens += $pn
        $dots += (New-Object System.Drawing.SolidBrush($dc))
        $hollow += (New-Object System.Drawing.Pen($dc, 1.6))
    }
    try {
        if ($maxX -gt 0 -and $maxX -lt $ymax) {
            $yh = & $fy $maxX
            $g.FillRectangle($hatch, [float]$L, [float]$Tp, [float]$pw, [float]($yh - $Tp))
        }
        # Zones de desaccord entre A et B : bande verticale de Lo - 0,5 a Hi + 0,5 cylindre
        if ($cmp -and $zones.Count) {
            $zb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56, $script:Theme.Warn))
            try {
                foreach ($z in $zones) {
                    $xa = & $fx ([math]::Max(0.0, [double]$z.Lo - 0.5)); $xb = & $fx ([math]::Min([double]$maxC, [double]$z.Hi + 0.5))
                    $g.FillRectangle($zb, [float]$xa, [float]$Tp, [float]([math]::Max(2.0, $xb - $xa)), [float]$ph)
                }
            } finally { $zb.Dispose() }
        }
        for ($v = 0; $v -le $ymax; $v += $step) {
            $y = & $fy $v
            $g.DrawLine($grid, $L, $y, $L + $pw, $y)
            $s = "$v"; $sz = $g.MeasureString($s, $font)
            $g.DrawString($s, $font, $txt, $L - 6 - $sz.Width, $y - $sz.Height / 2)
        }
        $ticks = @(0..$maxC | Where-Object { $_ % 10 -eq 0 }); if ($ticks -notcontains $maxC) { $ticks += $maxC }
        foreach ($c in $ticks) {
            $x = & $fx $c
            $g.DrawLine($grid, $x, $Tp, $x, $Tp + $ph)
            $s = "$c"; $sz = $g.MeasureString($s, $font)
            $g.DrawString($s, $font, $txt, $x - $sz.Width / 2, $Tp + $ph + 4)
        }
        $g.DrawLine($axis, $L, $Tp + $ph, $L + $pw, $Tp + $ph); $g.DrawLine($axis, $L, $Tp, $L, $Tp + $ph)
        $g.DrawString('ns', $font, $txt, 8, $Tp - 16)
        $s = (T 'cylindre'); $sz = $g.MeasureString($s, $font); $g.DrawString($s, $font, $txt, $L + $pw - $sz.Width, $Tp + $ph + 20)
        # Changements de sens du besoin (courbe monotone par segments) : trait vertical pointille
        $dash = New-Object System.Drawing.Pen($script:Theme.Muted, 1)
        $dash.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
        try { foreach ($cv in $cvs) { foreach ($bc in @($cv.Breaks)) { if ($null -ne $bc -and [int]$bc -le $maxC) { $xb = & $fx ([int]$bc); $g.DrawLine($dash, $xb, $Tp, $xb, $Tp + $ph) } } } } finally { $dash.Dispose() }
        for ($k = 0; $k -lt $cvs.Count; $k++) {
            $cv = $cvs[$k]; $vals = @($cv.Values)
            $pts = New-Object 'System.Drawing.PointF[]' $vals.Count
            for ($c = 0; $c -lt $vals.Count; $c++) { $pts[$c] = New-Object System.Drawing.PointF([float](& $fx $c), [float](& $fy $vals[$c])) }
            if ($pts.Count -ge 2) { $g.DrawLines($pens[$k], $pts) }
            for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
                $x = & $fx $cv.Cyls[$i]; $yv = [double]$cv.Ys[$i]; $sg = [double]$cv.Sig[$i]
                $y1 = & $fy ([math]::Min($ymax, $yv + $sg)); $y2 = & $fy ([math]::Max(0, $yv - $sg))
                $g.DrawLine($err, $x, $y1, $x, $y2); $g.DrawLine($err, $x - 3, $y1, $x + 3, $y1); $g.DrawLine($err, $x - 3, $y2, $x + 3, $y2)
                $y = & $fy $yv
                $kind = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { [string]$cv.Kinds[$i] } else { 'interp' }
                switch ($kind) {
                    'outlier' { $g.DrawLine($hollow[$k], $x - 4, $y - 4, $x + 4, $y + 4); $g.DrawLine($hollow[$k], $x - 4, $y + 4, $x + 4, $y - 4) }
                    'extrap' { $g.FillEllipse([System.Drawing.Brushes]::White, $x - 3.5, $y - 3.5, 7, 7); $g.DrawEllipse($hollow[$k], $x - 3.5, $y - 3.5, 7, 7) }
                    'cap'    { $g.FillRectangle([System.Drawing.Brushes]::White, $x - 3.5, $y - 3.5, 7, 7); $g.DrawRectangle($hollow[$k], $x - 3.5, $y - 3.5, 7, 7) }
                    default  { $g.FillEllipse($dots[$k], $x - 3.5, $y - 3.5, 7, 7) }
                }
                if (Test-CurvePointFlag $cv $i) { $g.DrawEllipse($flag, $x - 7, $y - 7, 14, 14) }
            }
            # Courbe decalee de la derniere disquette (tirets) et mesures du niveau (losanges)
            foreach ($rec in $lvls[$k]) {
                $col = if ($null -ne $rec.Head -and -not $multi) { $colors[[math]::Min([int]$rec.Head, 1)] } else { $colors[[math]::Min($k, 1)] }
                $dp = New-Object System.Drawing.Pen($col, 1.6); $dp.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
                $mp = New-Object System.Drawing.Pen($col, 1.4)
                try {
                    $rv = @($rec.Values)
                    $lp = New-Object 'System.Drawing.PointF[]' $rv.Count
                    for ($c = 0; $c -lt $rv.Count; $c++) { $lp[$c] = New-Object System.Drawing.PointF([float](& $fx $c), [float](& $fy $rv[$c])) }
                    if ($lp.Count -ge 2) { $g.DrawLines($dp, $lp) }
                    for ($i = 0; $i -lt @($rec.Cyls).Count; $i++) {
                        $x = & $fx ([int]$rec.Cyls[$i]); $zv = [double]$rec.Zs[$i]; $sz2 = [double]$rec.Sigs[$i]; $y = & $fy $zv
                        if ($sz2 -gt 0) { $y1 = & $fy ([math]::Min($ymax, $zv + $sz2)); $y2 = & $fy ([math]::Max(0, $zv - $sz2)); $g.DrawLine($err, $x, $y1, $x, $y2) }
                        $kd = [string]$rec.Kinds[$i]
                        if ($kd -eq 'outlier') { $g.DrawLine($mp, $x - 4, $y - 4, $x + 4, $y + 4); $g.DrawLine($mp, $x - 4, $y + 4, $x + 4, $y - 4) }
                        elseif ($kd -eq 'cap') { $g.DrawRectangle($mp, $x - 3.5, $y - 3.5, 7, 7) }
                        else {
                            $dm = @((New-Object System.Drawing.PointF([float]$x, [float]($y - 5))), (New-Object System.Drawing.PointF([float]($x + 5), [float]$y)), (New-Object System.Drawing.PointF([float]$x, [float]($y + 5))), (New-Object System.Drawing.PointF([float]($x - 5), [float]$y)))
                            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]$dm); $g.DrawPolygon($mp, [System.Drawing.PointF[]]$dm)
                        }
                    }
                } finally { $dp.Dispose(); $mp.Dispose() }
            }
        }
        # Titre (non convergence en rouge) et legende sur deux lignes
        $cv0 = $cvs[0]; $v0 = @($cv0.Values)
        if ($cmp) {
            $cA = @($cvs | Where-Object { [string]$_.Series -eq 'A' }); $cB = @($cvs | Where-Object { [string]$_.Series -eq 'B' })
            $title = ((T "{0} : lecteur {1}, calibrations A ({2}) et B ({3})") -f "$($cv0.Family)", "$($cv0.Drive)", "$(if ($cA.Count) { $cA[0].Date })", "$(if ($cB.Count) { $cB[0].Date })")
        }
        elseif ($multi) { $title = ((T "{0} : lecteur {1}, {2}, une courbe par tête") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)") }
        else { $title = ((T "{0} : lecteur {1}, {2}, courbe {3}, de {4} à {5} ns") -f "$($cv0.Family)", "$($cv0.Drive)", "$($cv0.Date)", (Get-CurveModelName $cv0.Model), "$($v0[0])", "$($v0[-1])") }
        $title += ', ' + ((T "calcul {0}") -f (Get-CurveCalcText $cv0))     # version du calcul de calibration de la courbe
        $g.DrawString($title, $fontB, $txt, $L, 8)
        $tx = $L + 12 + $g.MeasureString($title, $fontB).Width
        if ($cmp) {
            # Non convergence de chaque calibration, nommee
            foreach ($sr in @(@('A', $cA), @('B', $cB))) {
                if (@($sr[1] | Where-Object { $_.Converged -eq $false }).Count -eq 0) { continue }
                $s = if ($sr[0] -eq 'A') { (T 'A NON CONVERGÉE') } else { (T 'B NON CONVERGÉE') }
                $g.DrawString($s, $fontB, $red, $tx, 8); $tx += 12 + $g.MeasureString($s, $fontB).Width
            }
        }
        elseif (@($cvs | Where-Object { $_.Converged -eq $false }).Count -gt 0) {
            $g.DrawString((T 'NON CONVERGÉE'), $fontB, $red, $tx, 8); $tx += 12 + $g.MeasureString((T 'NON CONVERGÉE'), $fontB).Width
        }
        if (@(@($lvls.Values) | ForEach-Object { $_ } | Where-Object { $_.Verdict -eq 'mismatch' -or $_.Shape -eq 'mismatch' }).Count -gt 0) { $g.DrawString((T 'FORME NON CONFORME'), $fontB, $red, $tx, 8) }
        $ly = 30; $x2 = $L
        $g.FillEllipse($gray, $x2, $ly + 3, 7, 7); $s = (T 'mesure encadrée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        $g.DrawEllipse($grayPen, $x2, $ly + 3, 7, 7); $s = (T 'extrapolée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        $g.DrawRectangle($grayPen, $x2, $ly + 3, 7, 7); $s = (T 'plafonnée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width
        if (@($cvs | Where-Object { @($_.Kinds) -contains 'outlier' }).Count -gt 0) { $g.DrawLine($grayPen, $x2, $ly + 3, $x2 + 7, $ly + 10); $g.DrawLine($grayPen, $x2, $ly + 10, $x2 + 7, $ly + 3); $s = (T 'isolée'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width }
        if (@($cvs | Where-Object { @($_.Breaks).Count -gt 0 }).Count -gt 0) { $dl = New-Object System.Drawing.Pen($script:Theme.Muted, 1); $dl.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash; $g.DrawLine($dl, $x2 + 3, $ly + 1, $x2 + 3, $ly + 12); $dl.Dispose(); $s = (T 'changement de sens'); $g.DrawString($s, $font, $txt, $x2 + 11, $ly); $x2 += 24 + $g.MeasureString($s, $font).Width }
        $g.DrawEllipse($flag, $x2 - 1, $ly + 1, 11, 11); $s = (T 'écart > {0} ns et > 3 incertitudes') -f (Format-UiNum (Get-CurveDevNs $cvs[0])); $g.DrawString($s, $font, $txt, $x2 + 13, $ly); $x2 += 26 + $g.MeasureString($s, $font).Width
        $g.FillRectangle($hatch, $x2, $ly + 2, 16, 10); $g.DrawRectangle($grid, $x2, $ly + 2, 16, 10); $g.DrawString((T 'au-delà des mesures'), $font, $txt, $x2 + 20, $ly)
        $ly = 50; $x2 = $L
        if ($cmp) {
            # Une ligne par tete (courbe commune : une seule), A puis B ; puis les zones de desaccord
            $hk = @(@($cvs | ForEach-Object { if ($null -ne $_.Head) { "$([int]$_.Head)" } else { 'c' } }) | Sort-Object -Unique)
            foreach ($hh in $hk) {
                $x2 = $L
                foreach ($sr in 'A', 'B') {
                    for ($k = 0; $k -lt $cvs.Count; $k++) {
                        $cv = $cvs[$k]
                        if ([string]$cv.Series -ne $sr -or $(if ($null -ne $cv.Head) { "$([int]$cv.Head)" } else { 'c' }) -ne $hh) { continue }
                        $vals = @($cv.Values)
                        $lab = if ($null -eq $cv.Head) { $sr } else { (T "{0}, tête {1}") -f "$sr", "$($cv.Head)" }
                        $g.DrawLine($pens[$k], $x2, $ly + 7, $x2 + 22, $ly + 7)
                        $s = (T "{0} : courbe {1}, de {2} à {3} ns") -f "$lab", (Get-CurveModelName $cv.Model), "$($vals[0])", "$($vals[-1])"
                        $g.DrawString($s, $font, $txt, $x2 + 28, $ly)
                        $x2 += 28 + $g.MeasureString($s, $font).Width + 24
                    }
                }
                $ly += 20
            }
            if ($zones.Count) {
                $zb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56, $script:Theme.Warn))
                try { $g.FillRectangle($zb, $L, $ly + 2, 16, 10) } finally { $zb.Dispose() }
                $g.DrawString((T 'désaccord entre A et B'), $font, $txt, $L + 20, $ly)
            }
        }
        else {
            for ($k = 0; $k -lt $cvs.Count; $k++) {
                $cv = $cvs[$k]; $vals = @($cv.Values)
                $g.DrawLine($pens[$k], $x2, $ly + 7, $x2 + 22, $ly + 7)
                $s = if ($multi) { ((T "tête {0} : courbe {1}, de {2} à {3} ns") -f "$($cv.Head)", (Get-CurveModelName $cv.Model), "$($vals[0])", "$($vals[-1])") } else { (T 'précompensation retenue par cylindre') }
                $g.DrawString($s, $font, $txt, $x2 + 28, $ly)
                $x2 += 28 + $g.MeasureString($s, $font).Width + 24
            }
        }
        if ($hasLevel) {
            # Troisieme ligne : courbe decalee, mesure du niveau, niveau par enregistrement
            $ly = 70; $x2 = $L
            $dl = New-Object System.Drawing.Pen($script:Theme.Muted, 1.6); $dl.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
            $g.DrawLine($dl, $x2, $ly + 7, $x2 + 22, $ly + 7); $dl.Dispose()
            # 12.8 (S3) : courbe d une mesure complete de cette disquette (enregistrements 'mesure' seulement)
            $allMes = (@(@($lvls.Values) | ForEach-Object { $_ } | Where-Object { [string]$_.Model -ne 'mesure' }).Count -eq 0)
            $s = if ($allMes) { (T 'courbe mesurée (dernière disquette)') } else { (T 'courbe décalée (dernière disquette)') }; $g.DrawString($s, $font, $txt, $x2 + 28, $ly); $x2 += 28 + $g.MeasureString($s, $font).Width + 16
            $dm = @((New-Object System.Drawing.PointF([float]($x2 + 4), [float]($ly + 2))), (New-Object System.Drawing.PointF([float]($x2 + 9), [float]($ly + 7))), (New-Object System.Drawing.PointF([float]($x2 + 4), [float]($ly + 12))), (New-Object System.Drawing.PointF([float]($x2 - 1), [float]($ly + 7))))
            $g.DrawPolygon($grayPen, [System.Drawing.PointF[]]$dm)
            $s = (T 'mesure du niveau'); $g.DrawString($s, $font, $txt, $x2 + 13, $ly); $x2 += 13 + $g.MeasureString($s, $font).Width + 24
            # 12.8 (L6-TEXTES) : verdict 'adapte' (calibration rapide adaptative), meme libelle que Format-CurveTable
            $vn = @{ ok = (T 'conforme'); approx = (T 'approximative'); mismatch = (T 'NON CONFORME'); sat = (T 'non vérifiée, plafond atteint'); low = (T 'non vérifiée, plancher atteint'); few = (T 'non vérifiée, trop peu de cylindres mesurés'); adapte = (T 'adaptée à cette disquette'); mesure = (T 'mesurée sur cette disquette') }
            $ri = 0
            # 12.8 (L6-POLISH) : lignes dans l ordre des courbes (tete 0, puis tete 1), comme les lignes des courbes ; les
            # valeurs d une table de hachage ne suivent pas l ordre de ses cles (la tete 1 venait avant la tete 0)
            foreach ($rec in @(@($lvls.Keys) | Sort-Object | ForEach-Object { $lvls[$_] })) {
                if ($ri -gt 0) { $ly += 20; $x2 = $L }; $ri++
                $vk = if ([string]$rec.Shape -eq 'mismatch') { 'mismatch' } else { [string]$rec.Verdict }
                $vt = if ($vn.ContainsKey($vk)) { $vn[$vk] } else { $vk }
                $s = if ([string]$rec.Model -eq 'mesure') { (T "tête {0} : courbe mesurée sur cette disquette, écart moyen {1} ns ({2})") -f "$($rec.Head)", ('{0:+0;-0;0}' -f [int]$rec.Delta), "$($rec.Date)" }
                     elseif ($null -eq $rec.Head) { (T "niveau de la dernière disquette : {0} ns ± {1}, forme {2} ({3})") -f ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), "$vt", "$($rec.Date)" }
                     else { (T "tête {0} : niveau {1} ns ± {2}, forme {3} ({4})") -f "$($rec.Head)", ('{0:+0;-0;0}' -f [int]$rec.Delta), (Format-LevelNum $rec.SE), "$vt", "$($rec.Date)" }
                $g.DrawString($s, $font, $txt, $x2, $ly); $x2 += $g.MeasureString($s, $font).Width + 20
            }
        }
    } finally {
        foreach ($o in @($font, $fontB, $grid, $axis, $err, $flag, $txt, $red, $gray, $grayPen, $hatch) + $pens + $dots + $hollow) { $o.Dispose() }
    }
}

function Show-PrecompCurve([string]$family, [bool]$preferHeads, $Owner = $null) {
    # Owner : fenetre proprietaire (carte Calibration de l Accueil : sa fenetre modale ; sinon la fenetre principale)
    $cvs = Get-FamilyCurves $family $preferHeads
    if ($cvs.Count -eq 0) { return }
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    $script:CurveData = $cvs
    Set-CurveLevelData $cvs
    # 12.8 (lot 5, A4 P6) : Name frmCurve (banc : minuteur de securite de make-test), police de la fenetre principale,
    # bouton Fermer en bas a droite (Echap). Fenetre non modale et redimensionnable, comme en 12.7 ; hauteur augmentee de
    # celle de la rangee du bouton (courbe de meme taille)
    $f = New-Object System.Windows.Forms.Form
    $f.Name = 'frmCurve'
    $f.Text = if ($cvs.Count -gt 1) { ((T "Courbe de précompensation - {0}, une courbe par tête") -f "$($cvs[0].Family)") } else { ((T "Courbe de précompensation - {0}") -f "$($cvs[0].Family)") }
    $f.Size = New-Object System.Drawing.Size(920, 610); $f.MinimumSize = New-Object System.Drawing.Size(520, 410)
    # 12.8 (FIX5) : hauteur ramenee a celle de la zone de travail (1366 x 768 a 125 % : environ 566 px) ; la courbe (Fill)
    # se reduit, la rangee du bouton Fermer reste visible
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    if ($f.Height -gt $wa.Height) { $f.Height = $wa.Height }
    $f.StartPosition = 'CenterParent'; $f.Icon = $form.Icon; $f.Font = $form.Font; $f.BackColor = [System.Drawing.Color]::White
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'; $tb.Dock = 'Bottom'; $tb.Height = 170
    $tb.TabStop = $false; $tb.HideSelection = $true          # pas de texte tout selectionne a l ouverture
    $tb.Font = New-Object System.Drawing.Font('Consolas', 9.75); $tb.BackColor = $script:Theme.Page
    $tb.Text = Format-CurveTable $cvs
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.BackColor = [System.Drawing.Color]::White
    $pb.Add_Paint({ Draw-PrecompCurve $_.Graphics $this.ClientSize })
    $pb.Add_Resize({ $this.Invalidate() })
    $pnlBtn = New-Object System.Windows.Forms.Panel
    $pnlBtn.Dock = 'Bottom'; $pnlBtn.Height = 50; $pnlBtn.BackColor = [System.Drawing.Color]::White
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Name = 'btnCurveClose'; $btnClose.Text = (T 'Fermer'); $btnClose.Size = New-Object System.Drawing.Size(110, 34)
    $btnClose.Location = New-Object System.Drawing.Point(($pnlBtn.ClientSize.Width - 122), 8); $btnClose.Anchor = 'Top,Right'
    Set-Btn $btnClose '' 'normal'
    $btnClose.Add_Click({ $this.FindForm().Close() })     # fenetre non modale : DialogResult ne la fermerait pas
    $pnlBtn.Controls.Add($btnClose)
    $f.CancelButton = $btnClose
    # Ancrage dans l ordre inverse de la pile : rangee du bouton tout en bas, puis tableau, puis courbe (Fill)
    $f.Controls.Add($tb); $f.Controls.Add($pb); $f.Controls.Add($pnlBtn); $pb.BringToFront()
    $script:CurveForm = $f
    if ($null -eq $Owner) { $Owner = $form }
    $f.Show($Owner)
    $tb.Select(0, 0); $pb.Focus() | Out-Null
}

function Update-CurveButton([string]$path) {
    # Bouton « Courbe » : actif si une courbe calibree (commune ou par tete) existe pour la famille de l image courante
    # Avant l affichage de la fenetre : aucun acces au fichier (racine reseau possible) ; le gestionnaire Shown recalcule.
    # 12.8 (lot 2) : cadre « 2. Calibration du lecteur » de la restauration mis a jour en meme temps (memes courbes)
    Update-RsCalib
    if (-not $script:UiReady) { $path = '' }
    $fam = 'std'
    $ext = if ($path) { [System.IO.Path]::GetExtension($path).ToLower() } else { '' }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { $script:CurveFamily = 'std'; $btnWCurve.Enabled = $false; return }
    if ($path -and (Test-Path -LiteralPath $path)) { try { $fam = Get-ImageFamily $path $cmbWFmt.Text } catch { $fam = 'std' } }
    $script:CurveFamily = $fam
    $btnWCurve.Enabled = (Get-FamilyCurves $fam ([bool]$chkWSlow.Checked)).Count -gt 0
}

function Get-CurveCalc($cv) {
    # Version du calcul de calibration d une courbe ; courbe anterieure a ce champ : version de l application qui l a
    # faite (le calcul changeait alors avec chaque version) ; '' si aucune (anterieure a 12.1)
    if (-not $cv) { return '' }
    if ($cv.Calc) { return [string]$cv.Calc }
    return [string]$cv.Version
}

function Get-CurveCalcRef($cv) {
    # 12.7 : version du calcul attendue pour une courbe : CalibCalcHd (famille haute densite), sinon CalibCalc
    if (Test-CurveHd $cv) { return $script:CalibCalcHd }
    return $script:CalibCalc
}

function Test-CurveCalcOk($cv) {
    # Courbe utilisable : faite avec le calcul actuel de sa famille, ou conservee par l utilisateur pour ce calcul
    if (-not $cv) { return $false }
    $ref = Get-CurveCalcRef $cv
    return ((Get-CurveCalc $cv) -eq $ref -or [string]$cv.KeptFor -eq $ref)
}

function Get-CurveCalcText($cv, [switch]$Plain) {
    # « v12.3 » ; courbe d un autre calcul conservee : « v12.2, conservé (calcul actuel v12.3) » (calcul de sa famille)
    $c = Get-CurveCalc $cv
    $ref = Get-CurveCalcRef $cv
    $ct = if ($c) { "v$c" } else { (T 'antérieur à 12.1') }
    if ($Plain -or $c -eq $ref) { return $ct }
    return ((T "{0}, conservé (calcul actuel v{1})") -f "$ct", "$ref")
}

function Get-CurveMaxNs($cv) {
    # Borne des valeurs d une courbe : enregistree depuis le calcul 12.4 (CalHardNs au moment du calcul, champ MaxNs) ;
    # 300 ns pour une courbe qui ne l a pas (toutes les courbes jusqu au calcul 12.3, valeurs bornees a 300)
    if ($cv -and $null -ne $cv.MaxNs -and [int]$cv.MaxNs -gt 0) { return [int]$cv.MaxNs }
    return 300
}

function Test-CurveAtMax($cv) {
    # Courbe qui atteint la borne de son calcul : valeur a la borne avec un residu de verification positif (encore
    # sous-compensee), ou mesure plafonnee au-dessus (type 'cap' haut)
    if (-not $cv -or $null -eq $cv.Cyls) { return $false }
    $mx = Get-CurveMaxNs $cv; $v = @($cv.Values); $cs = @($cv.Cyls)
    $ks = @(); if ($null -ne $cv.Kinds) { $ks = @($cv.Kinds) }
    $ys = @(); if ($null -ne $cv.Ys) { $ys = @($cv.Ys) }
    $rs = @(); if ($null -ne $cv.Res) { $rs = @($cv.Res) }
    for ($i = 0; $i -lt $cs.Count; $i++) {
        $c = [int]$cs[$i]
        if ($i -lt $ks.Count -and $i -lt $ys.Count -and [string]$ks[$i] -eq 'cap' -and [double]$ys[$i] -ge $mx - 0.5) { return $true }
        if ($c -lt $v.Count -and [int]$v[$c] -ge $mx -and $i -lt $rs.Count -and $null -ne $rs[$i]) {
            $r = [double]$rs[$i]
            if (-not [double]::IsNaN($r) -and $r -gt 0) { return $true }
        }
    }
    return $false
}

function ConvertTo-CurveConfig($cv) {
    if (-not $cv) { return $null }
    $o = [ordered]@{ family = $cv.Family; head = $cv.Head; drive = $cv.Drive; date = $cv.Date; model = $cv.Model; spec = $cv.Spec; method = $cv.Method
                       values = @($cv.Values); cyls = @($cv.Cyls); ys = @($cv.Ys); sig = @($cv.Sig)
                       kinds = @($cv.Kinds); res = @(@($cv.Res) | ForEach-Object { if ($null -eq $_ -or [double]::IsNaN([double]$_)) { $null } else { [double]$_ } })
                       converged = $(if ($null -eq $cv.Converged) { $null } else { [bool]$cv.Converged }); maxx = $cv.MaxX; version = $cv.Version
                       algo = $cv.Algo; calc = $cv.Calc; keptFor = $cv.KeptFor; breaks = @($cv.Breaks); slope = $cv.Slope; bits = $cv.Bits; test = $cv.Test
                       maxNs = $(if ($null -ne $cv.MaxNs) { [int]$cv.MaxNs } else { $null }) }
    # Zone non reproductible (calcul 12.6) : enregistree seulement si elle existe
    $ct = @(@($cv.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    if ($ct.Count -gt 0) { $o.contra = $ct }
    return $o
}

function ConvertTo-LevelConfig($r) {
    # Resultat d une calibration rapide (tableau plat dans la configuration, profondeur JSON limitee)
    if (-not $r) { return $null }
    return [ordered]@{ refKey = $r.RefKey; tag = $r.Tag; head = $r.Head; drive = $r.Drive; date = $r.Date; refDate = $r.RefDate; refTest = $r.RefTest
                       delta = $r.Delta; est = $r.Est; se = $r.SE; tau = $r.Tau; verdict = $r.Verdict; shape = $r.Shape; reasons = @($r.Reasons); conv = [bool]$r.Conv; passes = $r.Passes
                       cyls = @($r.Cyls); zs = @($r.Zs); ds = @($r.Ds); sigs = @($r.Sigs); kinds = @($r.Kinds); values = @($r.Values); spec = $r.Spec
                       sat = @($r.Sat); floor = @($r.Floor); hist = @(@($r.Hist) | ForEach-Object { [ordered]@{ date = $_.Date; delta = $_.Delta } })
                       version = $r.Version; algo = $r.Algo; levelAlgo = $r.LevelAlgo
                       # 12.8 (lot 1c, § 12.1) : forme adaptee (s, b, modele), mode, marque, cylindres de controle, pente
                       s = $(if ($null -ne $r.S) { [double]$r.S } else { 0.0 }); b = $(if ($null -ne $r.B) { [double]$r.B } else { 0.0 })
                       model = $(if ($r.Model) { [string]$r.Model } else { 'M0' }); mode = $(if ($r.Mode) { [string]$r.Mode } else { 'lvl1' })
                       brand = [string]$r.Brand; ctl = @(@($r.Ctl) | Where-Object { $null -ne $_ }); k = $r.K }
}

function ConvertTo-LevelBrandConfig($en) {
    # 12.8 (lot 1c, § 10.2) : entree de la memoire de marque (tableau plat dans la configuration, profondeur JSON limitee)
    # 12.8 (S3) : courbe complete d une tete mesuree par « Mesure complete de cette disquette » (curve, curveDate,
    # curveCalc, curveMaxNs, curveSrc), ecrite seulement quand elle existe : une entree (a, s, b) s ecrit comme avant
    if (-not $en) { return $null }
    $o = [ordered]@{ brand = [string]$en.Brand; drive = [string]$en.Drive; refKey = [string]$en.RefKey; tag = [string]$en.Tag; head = $en.Head
                     family = [string]$en.Family; refDate = [string]$en.RefDate; levelAlgo = 'lvl2'; model = [string]$en.Model
                     a = [double]$en.A; s = [double]$en.S; b = [double]$en.B; n = [int]$en.N; date = [string]$en.Date
                     levels = @(@($en.Levels) | Where-Object { $_ } | ForEach-Object { [ordered]@{ date = [string]$_.Date; delta = [int]$_.Delta } })
                     shapes = @(@($en.Shapes) | Where-Object { $_ } | ForEach-Object { [ordered]@{ date = [string]$_.Date; s = [double]$_.S; b = [double]$_.B } }) }
    if ($null -ne $en.Curve -and @($en.Curve).Count -ge 2) {
        $o.curve = @(@($en.Curve) | ForEach-Object { [int]$_ }); $o.curveDate = [string]$en.CurveDate; $o.curveCalc = [string]$en.CurveCalc
        $o.curveMaxNs = [int]$en.CurveMaxNs; $o.curveSrc = [string]$en.CurveSrc
    }
    return $o
}

function ConvertFrom-LevelBrandConfig($o) {
    # Entree illisible : $null (ignoree par Load-Config, une ligne de journal)
    if (-not $o) { return $null }
    try {
        $en = @{ Brand = ([string]$o.brand).Trim(); Drive = [string]$o.drive; RefKey = [string]$o.refKey; Tag = [string]$o.tag
                 Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Family = [string]$o.family; RefDate = [string]$o.refDate
                 LevelAlgo = [string]$o.levelAlgo; Model = $(if ($o.model) { [string]$o.model } else { 'M0' }); A = [double]$o.a; S = [double]$o.s; B = [double]$o.b
                 N = [int]$o.n; Date = [string]$o.date
                 Levels = @(@($o.levels) | Where-Object { $_ } | ForEach-Object { @{ Date = [string]$_.date; Delta = [int]$_.delta } })
                 Shapes = @(@($o.shapes) | Where-Object { $_ } | ForEach-Object { @{ Date = [string]$_.date; S = [double]$_.s; B = [double]$_.b } })
                 # 12.8 (S3) : courbe complete d une tete (absente d une entree a, s, b : $null)
                 Curve = $null; CurveDate = ''; CurveCalc = ''; CurveMaxNs = 0; CurveSrc = '' }
        if ($null -ne $o.curve -and @($o.curve).Count -ge 2) {
            $en.Curve = [int[]]@(@($o.curve) | ForEach-Object { [int]$_ }); $en.CurveDate = [string]$o.curveDate; $en.CurveCalc = [string]$o.curveCalc
            $en.CurveMaxNs = $(if ($null -ne $o.curveMaxNs) { [int]$o.curveMaxNs } else { 0 }); $en.CurveSrc = [string]$o.curveSrc
        }
        if (-not $en.Brand -or -not $en.RefKey -or -not $en.RefDate) { return $null }
        return $en
    } catch { return $null }
}

function ConvertFrom-LevelConfig($o) {
    if (-not $o) { return $null }
    try {
        $r = @{ RefKey = [string]$o.refKey; Tag = [string]$o.tag; Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Drive = [string]$o.drive
                Date = [string]$o.date; RefDate = [string]$o.refDate; RefTest = [string]$o.refTest; Delta = [int]$o.delta; Est = [double]$o.est; SE = [double]$o.se
                Tau = [double]$o.tau; Verdict = [string]$o.verdict; Shape = [string]$o.shape; Reasons = [string[]]@($o.reasons); Conv = [bool]$o.conv; Passes = [int]$o.passes
                Cyls = [int[]]@($o.cyls); Zs = [double[]]@($o.zs); Ds = [double[]]@($o.ds); Sigs = [double[]]@($o.sigs); Kinds = [string[]]@($o.kinds)
                Values = [int[]]@($o.values); Spec = [string]$o.spec; Sat = [int[]]@(@($o.sat) | Where-Object { $null -ne $_ }); Floor = [int[]]@(@($o.floor) | Where-Object { $null -ne $_ })
                Hist = @(@($o.hist) | Where-Object { $_ } | ForEach-Object { @{ Date = [string]$_.date; Delta = [int]$_.delta } })
                Version = [string]$o.version; Algo = [string]$o.algo; LevelAlgo = [string]$o.levelAlgo
                # 12.8 (lot 1c, § 12.1) : champs absents d un enregistrement lvl1 : s = b = 0, M0, lvl1, sans marque
                S = $(if ($null -ne $o.s) { [double]$o.s } else { 0.0 }); B = $(if ($null -ne $o.b) { [double]$o.b } else { 0.0 })
                Model = $(if ($o.model) { [string]$o.model } else { 'M0' }); Mode = $(if ($o.mode) { [string]$o.mode } else { 'lvl1' })
                Brand = [string]$o.brand; Ctl = [int[]]@(@($o.ctl) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
                K = $(if ($null -ne $o.k) { [double]$o.k } else { $null }) }
        if (-not $r.RefKey -or $r.Values.Count -lt 2 -or $r.Cyls.Count -ne $r.Zs.Count) { return $null }
        return $r
    } catch { return $null }
}

function ConvertFrom-CurveConfig($o) {
    if (-not $o) { return $null }
    try {
        $cv = @{ Family = [string]$o.family; Head = $(if ($null -ne $o.head) { [int]$o.head } else { $null }); Drive = [string]$o.drive; Date = [string]$o.date
                 Model = [string]$o.model; Spec = [string]$o.spec; Method = $(if ($o.method) { [string]$o.method } else { 'image' })
                 Values = [int[]]@($o.values); Cyls = [int[]]@($o.cyls); Ys = [double[]]@($o.ys); Sig = [double[]]@($o.sig)
                 Kinds = $null; Res = $null; Converged = $null; MaxX = 0; Version = [string]$o.version; Algo = [string]$o.algo
                 Calc = [string]$o.calc; KeptFor = [string]$o.keptFor
                 Breaks = [int[]]@(@($o.breaks) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ }) }
        if ($cv.Values.Count -lt 2 -or $cv.Cyls.Count -ne $cv.Ys.Count -or $cv.Cyls.Count -ne $cv.Sig.Count) { return $null }
        # Champs ajoutes en v11.9 : absents d une courbe plus ancienne
        if ($o.kinds -and @($o.kinds).Count -eq $cv.Cyls.Count) { $cv.Kinds = [string[]]@($o.kinds) }
        if ($o.res -and @($o.res).Count -eq $cv.Cyls.Count) { $cv.Res = [double[]]@(@($o.res) | ForEach-Object { if ($null -eq $_) { [double]::NaN } else { [double]$_ } }) }
        if ($null -ne $o.converged) { $cv.Converged = [bool]$o.converged }
        if ($o.maxx) { $cv.MaxX = [int]$o.maxx }
        # Champs de la calibration rapide (12.3) : absents d une courbe plus ancienne
        $cv.Slope = $(if ($null -ne $o.slope) { [double]$o.slope } else { $null })
        $cv.Bits = $(if ($o.bits) { [int]$o.bits } else { 0 })
        $cv.Test = [string]$o.test
        # Borne des valeurs (calcul 12.4) : absente d une courbe plus ancienne, qui vaut alors 300 (Get-CurveMaxNs)
        $cv.MaxNs = $(if ($null -ne $o.maxNs) { [int]$o.maxNs } else { $null })
        # Zone non reproductible, verifications contradictoires (calcul 12.6) : absente d une courbe plus ancienne
        $cv.Contra = [int[]]@(@($o.contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
        return $cv
    } catch { return $null }
}
