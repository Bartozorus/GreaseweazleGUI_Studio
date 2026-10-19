# ============================== FONCTIONS : QUALITE ET ALIGNEMENT ==============

# ============================== ALIGNEMENT : LOGIQUE ===========================
function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger) {
    # cellsPerRev > 0 : motif de test connu (calibration) ; la cellule vaut alors duree du tour / nombre de cellules,
    # au lieu de la mediane des intervalles de deux cellules, qui derive quand le decalage residuel est grand.
    $d = [System.IO.File]::ReadAllBytes($path)
    if ([System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'SCP') { throw (T 'Fichier SCP invalide') }
    $revs = $d[5]; $res = ($d[11] + 1) * 25
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
        $tracks[[int]$tn] = $list
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

function Get-AlignCyls {
    $vals = @()
    foreach ($tok in ($txtAlCyls.Text -split '[,; ]+')) {
        if ($tok -match '^\d+$') { $v = [int]$tok; if ($v -ge 0 -and $v -le 83) { $vals += $v } }
    }
    return ($vals | Sort-Object -Unique)
}

function Start-AlignCycle {
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $cyls = Get-AlignCyls
    if (-not $cyls -or $cyls.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez au moins un cylindre valide (0-83).'),(T 'Alignement'),'OK','Warning')
        $script:AlignLoop = $false; return
    }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $script:AlignTmp = Join-Path $script:TempDir 'align.scp'
    if (Test-Path -LiteralPath $script:AlignTmp) { Remove-Item -LiteralPath $script:AlignTmp -Force }
    $cspec = ($cyls -join ',')
    $hspec = if ($cmbAlHead.Text -eq '0+1') { '0-1' } else { $cmbAlHead.Text }
    $script:AlignArgs = @('read') + (Get-CommonArgs) + @("--revs=$($numAlRevs.Value)", "--tracks=c=${cspec}:h=$hspec", "`"$($script:AlignTmp)`"")
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
        'err'    { if ($v -le 0)   { 0 } elseif ($v -le 3)   { 1 } elseif ($v -le 20)  { 2 } else { 3 } }
        'stab'   { if ($v -le 2)   { 0 } elseif ($v -le 5)   { 1 } elseif ($v -le 10)  { 2 } else { 3 } }
        'delta'  { if ($v -le 10)  { 0 } elseif ($v -le 30)  { 1 } elseif ($v -le 100) { 2 } else { 3 } }   # ecart % vs reference
        default  { 3 }
    }
}

function Draw-AlignBars($g, $size) {
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font('Segoe UI', 8)
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
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Gainsboro)
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
        $brush = New-Object System.Drawing.SolidBrush($script:AlColors[$lvl])
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
        $g.DrawString($label, $font, [System.Drawing.Brushes]::Black, $x, $h - 14)
        $g.DrawString(('{0:N0}' -f $st.Score), $font, [System.Drawing.Brushes]::Black, $x, [math]::Max(0, $h - 14 - $bh - 14))
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
    if ($err -le 3 -and $drop -le 0 -and $stab -le 2 -and $jit -lt $okT) { return 0 }
    if ($err -le 20 -and $drop -le 1 -and $stab -le 10 -and $jit -lt $watchT) { return 1 }
    return 2
}

function Get-JitterRedBound {
    # Borne orange / rouge de la colonne Jitter : toujours au-dessus du seuil SAIN (bande orange non vide)
    return [math]::Max($script:JitterWatch * 0.8, ($script:JitterOk + $script:JitterWatch) / 2)
}

function Update-QualityTip {
    $tip.SetToolTip($lvAl, ((T "État par piste : SAIN / À SURVEILLER / CRITIQUE, d'après les erreurs, les trous, la stabilité et le jitter.`nJitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns (onglet Accueil, « Régler le jitter »).`nCouleurs de la colonne Jitter : <{2} / <{0} / <{3} ns. Asymétrie : <0,02 / <0,05 / <0,10 (couleur et score seulement, sans effet sur l'état).") -f "$($script:JitterOk)", "$($script:JitterWatch)", "$([math]::Round($script:JitterOk * 0.5))", "$([math]::Round((Get-JitterRedBound)))"))
}

function Set-JitterThresholds([int]$ok, [int]$watch) {
    # Bornes : SAIN de 30 a 300 ns, A SURVEILLER au moins 10 ns au-dessus, 600 ns au plus
    $ok = [math]::Max(30, [math]::Min(300, $ok))
    $watch = [math]::Max($ok + 10, [math]::Min(600, $watch))
    $script:JitterOk = $ok; $script:JitterWatch = $watch
    Update-QualityTip
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
    $w = 540
    $presets = Get-JitterPresets
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmJitter'; $dlg.Text = (T 'Réglage du jitter')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $text = (T "Le jitter mesure la dispersion des intervalles entre les transitions magnétiques d'une piste, en nanosecondes : plus il est faible, plus la piste est nette.`n`nCes seuils fixent l'état de chaque piste dans l'onglet « Qualité & alignement », dans le contrôle après écriture et dans la restauration. Une piste n'est SAINE que si son jitter est sous le premier seuil, et si ses erreurs, ses trous et sa stabilité sont bons. Au-delà du second seuil, elle est CRITIQUE.`n`nAprès une écriture avec contrôle de toutes les pistes (écriture lente, restauration), une piste qui n'est pas SAINE est réécrite, dans la limite des passes de réécriture : un réglage plus strict fait réécrire davantage de pistes, donc davantage d'écritures sur la disquette. Le jugement de la disquette d'origine en restauration et le garde-fou (plus de la moitié des pistes faibles : aucune réécriture) gardent les seuils Standard.")
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $text; $lbl.Location = New-Object System.Drawing.Point(16, 16)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($text, $dlg.Font, (New-Object System.Drawing.Size($w, 10000)), $tf).Height
    $lbl.Size = New-Object System.Drawing.Size($w, ($h + 4))
    $y = $lbl.Bottom + 14
    $l1 = New-Object System.Windows.Forms.Label; $l1.Text = (T 'Préréglage :'); $l1.AutoSize = $true; $l1.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Name = 'cmbJitPreset'; $cmb.DropDownStyle = 'DropDownList'; $cmb.Location = New-Object System.Drawing.Point(290, $y); $cmb.Width = 240
    foreach ($pr in $presets) { [void]$cmb.Items.Add($pr.Name) }
    [void]$cmb.Items.Add((T 'Personnalisé'))
    $y += 36
    $l2 = New-Object System.Windows.Forms.Label; $l2.Text = (T 'SAIN si le jitter est inférieur à :'); $l2.AutoSize = $true; $l2.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $numOk = New-Object System.Windows.Forms.NumericUpDown
    $numOk.Name = 'numJitOk'; $numOk.Minimum = 30; $numOk.Maximum = 300; $numOk.Increment = 5; $numOk.Width = 80; $numOk.Location = New-Object System.Drawing.Point(290, $y)
    $u1 = New-Object System.Windows.Forms.Label; $u1.Text = 'ns'; $u1.AutoSize = $true; $u1.Location = New-Object System.Drawing.Point(376, ($y + 3))
    $y += 34
    $l3 = New-Object System.Windows.Forms.Label; $l3.Text = (T "À SURVEILLER s'il est inférieur à :"); $l3.AutoSize = $true; $l3.Location = New-Object System.Drawing.Point(16, ($y + 3))
    $numWatch = New-Object System.Windows.Forms.NumericUpDown
    $numWatch.Name = 'numJitWatch'; $numWatch.Minimum = 40; $numWatch.Maximum = 600; $numWatch.Increment = 10; $numWatch.Width = 80; $numWatch.Location = New-Object System.Drawing.Point(290, $y)
    $u2 = New-Object System.Windows.Forms.Label; $u2.Text = 'ns'; $u2.AutoSize = $true; $u2.Location = New-Object System.Drawing.Point(376, ($y + 3))
    $y += 34
    $l4 = New-Object System.Windows.Forms.Label; $l4.Text = (T 'Au-delà : CRITIQUE. Les nouvelles valeurs valent pour les prochaines mesures.'); $l4.AutoSize = $true; $l4.ForeColor = $script:Theme.Muted; $l4.Location = New-Object System.Drawing.Point(16, $y)
    $y += 34
    $btnDef = New-Object System.Windows.Forms.Button; $btnDef.Name = 'btnJitDefault'; $btnDef.Text = (T 'Valeurs par défaut'); $btnDef.Size = New-Object System.Drawing.Size(170, 34)
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Name = 'btnJitOk'; $btnOk.Text = (T 'Enregistrer'); $btnOk.Size = New-Object System.Drawing.Size(140, 34)
    $btnNo = New-Object System.Windows.Forms.Button; $btnNo.Name = 'btnJitCancel'; $btnNo.Text = (T 'Annuler'); $btnNo.Size = New-Object System.Drawing.Size(110, 34)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnDef 'Refresh' 'normal'; Set-Btn $btnOk 'Save' 'primary'; Set-Btn $btnNo '' 'normal'
    $btnDef.Location = New-Object System.Drawing.Point(16, $y)
    $btnNo.Location = New-Object System.Drawing.Point((16 + $w - $btnNo.Width), $y)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($w + 32), ($y + $btnOk.Height + 16))
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnNo
    $dlg.Controls.AddRange(@($lbl, $l1, $cmb, $l2, $numOk, $u1, $l3, $numWatch, $u2, $l4, $btnDef, $btnOk, $btnNo))
    # Etat partage avec les gestionnaires (portee script) : prereglage <-> valeurs, sans boucle
    $script:JitDlg = @{ Presets = $presets; Cmb = $cmb; Ok = $numOk; Watch = $numWatch; Busy = $false; Dlg = $dlg }
    $numOk.Value = $script:JitterOk; $numWatch.Value = $script:JitterWatch
    $sync = {
        $s = $script:JitDlg
        if (-not $s -or $s.Busy) { return }
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
        $s.Busy = $true
        $pr = $s.Presets[$s.Cmb.SelectedIndex]
        $s.Ok.Value = $pr.Ok; $s.Watch.Value = $pr.Watch
        $s.Busy = $false
    })
    $btnDef.Add_Click({ $script:JitDlg.Cmb.SelectedIndex = 0 })
    $btnOk.Add_Click({
        $s = $script:JitDlg
        if ([int]$s.Watch.Value -lt [int]$s.Ok.Value + 10) {
            [void][System.Windows.Forms.MessageBox]::Show((T "Le seuil À SURVEILLER doit dépasser le seuil SAIN d'au moins 10 ns."), (T 'Réglage du jitter'), 'OK', 'Warning'); return
        }
        $s.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $dr = $dlg.ShowDialog($form)
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-JitterThresholds ([int]$numOk.Value) ([int]$numWatch.Value)
        [void](Save-Config)
        Append-Log ((T "Réglage du jitter : SAIN sous {0} ns, À SURVEILLER sous {1} ns, CRITIQUE au-delà (prochaines mesures).") -f "$($script:JitterOk)", "$($script:JitterWatch)")
    }
    $script:JitDlg = $null
    $dlg.Dispose()
}

# Metriques d une piste (liste de ScpRev, un par tour) : base commune de l onglet Qualite et du
# controle apres ecriture, pour que « piste faible » ait partout la meme definition.
function Get-TrackMetrics($st) {
    $m = @{ Bad = $false; Missing = $false; J = 0.0; R3 = 0.0; R4 = 0.0; Ooc = 0.0; Dr = 0.0; Cell = 0.0; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 2
            Weak = $false; ShortUnstable = $false; Blocks = 0; Unstable = 0; MaxRun = 0; RunPos = -1 }
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
    if (-not $script:AlignTmp -or -not (Test-Path -LiteralPath $script:AlignTmp)) {
        Append-Log (T 'Mesure : fichier SCP absent, analyse impossible.'); $script:AlignLoop = $false; return
    }
    try { $tracks = Read-ScpFile $script:AlignTmp } catch { Append-Log ((T "Mesure : {0}") -f "$($_.Exception.Message)"); $script:AlignLoop = $false; return }

    $last = @{}; $watch = @(); $crit = @(); $weakL = @()
    $lvAl.Columns[1].Width = 200
    $lvAl.BeginUpdate()
    try {
        $lvAl.Items.Clear()
        $total = 0.0; $count = 0
        foreach ($tn in ($tracks.Keys | Sort-Object)) {
            $st = $tracks[$tn]; $cyl = [math]::Floor($tn / 2); $hd = $tn % 2; $key = "$cyl.$hd"
            $lab = "$cyl.$hd"
            $m = Get-TrackMetrics $st
            if ($m.Bad) {
                [void]$lvAl.Items.Add((New-AlignRow $lab $m '' '-' -1))
                $last[$key] = @{ Score = 9999; Jitter = 0; Asym = 0; Err = 0; Stab = 0; Cell = 0 }
                $crit += ((T "{0} (illisible)") -f "$lab"); continue
            }
            # Zone instable : la piste ne se relit pas pareil d un tour a l autre, elle n est pas propre (protection ou
            # defaut du support, l application ne peut pas trancher sur une disquette inconnue) : au moins A SURVEILLER
            if ($m.Weak -and $m.Level -lt 1) { $m.Level = 1 }
            $sc = $m.Score
            if (-not $script:AlignBest.ContainsKey($key) -or $sc -lt $script:AlignBest[$key]) { $script:AlignBest[$key] = $sc }
            $last[$key] = @{ Score = $sc; Jitter = $m.J; Asym = $m.Asym; Err = $m.Ooc; Stab = $m.Stab; Cell = $m.Cell }
            $hl = $m.Level
            if ($m.Weak) { $weakL += $lab }
            if ($hl -eq 1) { $watch += $lab } elseif ($hl -eq 2) { $crit += ((T "{0} ({1} err/tour)") -f "$lab", "$([math]::Round($m.Ooc,0))") }

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

        # --- Verdict 1 : etat du support
        if ($crit.Count -gt 0) {
            $lblAlHealth.Text = ((T "SUPPORT CRITIQUE  -  {0} piste(s) en erreur : {1}   ->  dump flux immédiat conseillé") -f "$($crit.Count)", "$($crit -join ', ')")
            $lblAlHealth.BackColor = $script:AlColors[3]; $lblAlHealth.ForeColor = $script:AlFg[3]
        } elseif ($watch.Count -gt 0) {
            $lblAlHealth.Text = ((T "SUPPORT À SURVEILLER  -  {0}/{1} piste(s) marginale(s) : {2}   ->  dump flux recommandé") -f "$($watch.Count)", "$nTracks", "$($watch -join ', ')")
            $lblAlHealth.BackColor = $script:AlColors[2]; $lblAlHealth.ForeColor = $script:AlFg[2]
        } else {
            $lblAlHealth.Text = ((T "SUPPORT SAIN  -  {0}/{1} pistes propres (erreurs, trous, stabilité, jitter dans les normes)") -f "$nTracks", "$nTracks")
            $lblAlHealth.BackColor = $script:AlColors[0]; $lblAlHealth.ForeColor = $script:AlFg[0]
        }
        Append-Log ((T "Mesure : {0}") -f "$($lblAlHealth.Text)")
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
            $script:AlignPrev = $avg
            $lvlAvg = Get-AlLevel 'score' $avg
            $refTxt = ''
            if ($script:AlignRef) {
                $refScores = @($script:AlignRef.Values | ForEach-Object { $_.Score } | Where-Object { $_ -lt 9999 })
                if ($refScores.Count -gt 0) { $refAvg = [math]::Round(($refScores | Measure-Object -Average).Average, 0); $refTxt = ((T "   |   référence {0}") -f "$refAvg") }
            }
            $lblAlVerdict.Text = ((T "Qualité de lecture : score {0} - {1}{2}{3}   |   meilleur {4}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend", "$refTxt", "$($script:AlignBest['_global'])")
            $lblAlVerdict.BackColor = $script:AlColors[$lvlAvg]; $lblAlVerdict.ForeColor = $script:AlFg[$lvlAvg]
            Append-Log ((T "Mesure : score moyen {0} ({1}){2}") -f "$avg", "$($script:AlNames[$lvlAvg])", "$trend")
            Update-AlignGuide $avg
            $bn = if ($weakL.Count -gt 0) { ((T "Zone instable d'un tour à l'autre (protection contre la copie ou défaut du support) : {0}") -f "$($weakL -join ', ')") + $(if ($clu.Count -gt 0) { (T " ; cylindres voisins {0} : défaut du support probable") -f "$($clu -join ', ')" } else { '' }) } else { '' }
            Set-UnstableBanner @($bn)
        } else {
            $lblAlVerdict.Text = (T 'Aucune piste analysable'); $lblAlVerdict.BackColor = $script:AlColors[3]; $lblAlVerdict.ForeColor = $script:AlFg[3]
        }
    } finally { $lvAl.EndUpdate() }
    Render-AlignBars

    if ($script:AlignLoop) { $script:AlignNextAt = (Get-Date).AddSeconds([int]$numAlPause.Value) }
}
