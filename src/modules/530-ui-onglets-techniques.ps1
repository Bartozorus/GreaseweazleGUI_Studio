# ============================== LECTURE ========================================
$tabR = New-TabPage (T 'Lecture / Dump')

$txtRFile = New-Object System.Windows.Forms.TextBox
$txtRFile.Location = '90,13'; $txtRFile.Width = 650; $txtRFile.Anchor = 'Top,Left,Right'
$btnRFile = New-Object System.Windows.Forms.Button
$btnRFile.Text = '...'; $btnRFile.Location = '745,12'; $btnRFile.Width = 30; $btnRFile.Anchor = 'Top,Right'

$cmbRFmt = New-Object System.Windows.Forms.ComboBox
$cmbRFmt.Location = '90,43'; $cmbRFmt.Width = 200
[void]$cmbRFmt.Items.AddRange($Formats)

$btnRFile.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'Flux SCP (préservation)|*.scp|ADF (AmigaDOS)|*.adf|Kryoflux stream|*.raw|HFE|*.hfe|Tous|*.*')
    if ($txtRFile.Text) { $p = Split-Path -Parent $txtRFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    elseif ($txtLibRoot.Text -and (Test-Path -LiteralPath $txtLibRoot.Text)) { $d.InitialDirectory = $txtLibRoot.Text }
    if ($d.ShowDialog() -eq 'OK') {
        $txtRFile.Text = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbRFmt.SelectedItem = 'amiga.amigados' } else { $cmbRFmt.SelectedIndex = 0 }
    }
})

$numRevs = New-Object System.Windows.Forms.NumericUpDown
$numRevs.Location = '110,74'; $numRevs.Width = 55
$numRevs.Minimum = 1; $numRevs.Maximum = 30
$tip.SetToolTip($numRevs, (T 'Tours lus par piste. 5 recommandés pour l''archivage flux (SCP).'))

$numRRetries = New-Object System.Windows.Forms.NumericUpDown
$numRRetries.Location = '255,74'; $numRRetries.Width = 55
$numRRetries.Minimum = 0; $numRRetries.Maximum = 50

$txtRTracks = New-Object System.Windows.Forms.TextBox
$txtRTracks.Location = '415,74'; $txtRTracks.Width = 160

$chkRRaw = New-Object System.Windows.Forms.CheckBox
$chkRRaw.Text = (T 'Flux brut (--raw)'); $chkRRaw.Location = '90,105'; $chkRRaw.Width = 290
$chkRRev = New-Object System.Windows.Forms.CheckBox
$chkRRev.Text = (T 'Face B flippy (--reverse)'); $chkRRev.Location = '390,105'; $chkRRev.Width = 100

$cmbRDensel = New-Object System.Windows.Forms.ComboBox
$cmbRDensel.Location = '90,135'; $cmbRDensel.Width = 60; $cmbRDensel.DropDownStyle = 'DropDownList'
[void]$cmbRDensel.Items.AddRange(@('(non)','H','L'))

$txtRDiskdefs = New-Object System.Windows.Forms.TextBox
$txtRDiskdefs.Location = '250,135'; $txtRDiskdefs.Width = 325
$btnRDiskdefs = New-Object System.Windows.Forms.Button
$btnRDiskdefs.Text = '...'; $btnRDiskdefs.Location = '580,134'; $btnRDiskdefs.Width = 30
$btnRDiskdefs.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'diskdefs|*.cfg|Tous|*.*'); $d.InitialDirectory = $script:AppDir
    if ($d.ShowDialog() -eq 'OK') { $txtRDiskdefs.Text = $d.FileName }
})

$btnRead = New-Object System.Windows.Forms.Button
$btnRead.Text = (T 'LIRE LA DISQUETTE'); $btnRead.Location = '90,175'; $btnRead.Size = '250,40'; $btnRead.Font = $bold
$btnRead.Add_Click({
    if (-not $txtRFile.Text.Trim()) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez un fichier de sortie.'),(T 'Erreur'),'OK','Warning'); return
    }
    $a = @('read') + (Get-CommonArgs)
    $a += "--revs=$($numRevs.Value)"
    $a += "--retries=$($numRRetries.Value)"
    $outExt = [System.IO.Path]::GetExtension($txtRFile.Text.Trim().Trim('"')).ToLower()
    $fmtSet = ($cmbRFmt.Text -and $cmbRFmt.Text -ne '(auto)')
    $raw = $chkRRaw.Checked
    if (@('.scp', '.raw') -contains $outExt -and $fmtSet -and -not $raw) {
        # Sans --raw, gw enregistre un flux reconstitue a partir des secteurs decodes (read.py) : choix laisse a l utilisateur
        Append-Log (T 'Lecture : flux avec un format, sans « Flux brut » : gw enregistre un flux reconstitué à partir des secteurs décodés ; les pistes protégées ou illisibles ne sont pas conservées telles quelles. Cochez « Flux brut (--raw) » pour garder le flux réel.')
    }
    if (@('.adf', '.img', '.ima', '.st', '.dsk') -contains $outExt -and $raw) { $raw = $false; Append-Log (T 'Lecture : image secteur, --raw ignoré (gw le refuse pour ce type de fichier).') }
    if ($raw) { $a += '--raw' }
    if ($chkRRev.Checked) { $a += '--reverse' }
    if ($cmbRFmt.Text -and $cmbRFmt.Text -ne '(auto)') { $a += "--format=$($cmbRFmt.Text)" }
    if ($txtRTracks.Text.Trim())      { $a += "--tracks=$($txtRTracks.Text.Trim())" }
    if ($cmbRDensel.Text -ne '(non)') { $a += "--densel=$($cmbRDensel.Text)" }
    if ($txtRDiskdefs.Text.Trim())    { $a += "--diskdefs=`"$($txtRDiskdefs.Text.Trim())`"" }
    $a += "`"$($txtRFile.Text)`""
    Start-Gw $a
})

$tabR.Controls.AddRange(@((New-Label (T 'Sortie :') '10,17'), $txtRFile, $btnRFile,
    (New-Label (T 'Format :') '10,47'), $cmbRFmt,
    (New-Label (T 'Tours :') '10,77'), $numRevs,
    (New-Label (T 'Essais :') '190,77'), $numRRetries,
    (New-Label (T 'Pistes :') '355,77'), $txtRTracks,
    $chkRRaw, $chkRRev,
    (New-Label (T 'Densel :') '10,138'), $cmbRDensel,
    (New-Label (T 'Diskdefs :') '165,138'), $txtRDiskdefs, $btnRDiskdefs,
    $btnRead))

# ============================== CONVERSION =====================================
$tabCv = New-TabPage 'Conversion'

$txtCvIn = New-Object System.Windows.Forms.TextBox
$txtCvIn.Location = '90,13'; $txtCvIn.Width = 650; $txtCvIn.Anchor = 'Top,Left,Right'
$btnCvIn = New-Object System.Windows.Forms.Button
$btnCvIn.Text = '...'; $btnCvIn.Location = '745,12'; $btnCvIn.Width = 30; $btnCvIn.Anchor = 'Top,Right'
$btnCvIn.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.scp;*.raw;*.ipf;*.adf;*.hfe;*.img;*.st;*.dsk|Tous|*.*')
    if ($txtCvIn.Text) { $p = Split-Path -Parent $txtCvIn.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') { $txtCvIn.Text = $d.FileName }
})

$cmbCvFmt = New-Object System.Windows.Forms.ComboBox
$cmbCvFmt.Location = '90,75'; $cmbCvFmt.Width = 200
[void]$cmbCvFmt.Items.AddRange($Formats)
$tip.SetToolTip($cmbCvFmt, (T 'Format de décodage. Nécessaire pour passer d''un flux (SCP/RAW) à un format secteur (ADF).'))

$txtCvOut = New-Object System.Windows.Forms.TextBox
$txtCvOut.Location = '90,43'; $txtCvOut.Width = 650; $txtCvOut.Anchor = 'Top,Left,Right'
$btnCvOut = New-Object System.Windows.Forms.Button
$btnCvOut.Text = '...'; $btnCvOut.Location = '745,42'; $btnCvOut.Width = 30; $btnCvOut.Anchor = 'Top,Right'
$btnCvOut.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'ADF|*.adf|SCP|*.scp|HFE|*.hfe|IMG|*.img|Tous|*.*')
    if ($d.ShowDialog() -eq 'OK') {
        $txtCvOut.Text = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbCvFmt.SelectedItem = 'amiga.amigados' }
    }
})

$txtCvTracks = New-Object System.Windows.Forms.TextBox
$txtCvTracks.Location = '415,75'; $txtCvTracks.Width = 160

$btnConvert = New-Object System.Windows.Forms.Button
$btnConvert.Text = (T 'CONVERTIR'); $btnConvert.Location = '90,120'; $btnConvert.Size = '250,40'; $btnConvert.Font = $bold
$btnConvert.Add_Click({
    if (-not (Test-Path -LiteralPath $txtCvIn.Text)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier source introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    if (-not $txtCvOut.Text.Trim()) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Indiquez un fichier de destination.'),(T 'Erreur'),'OK','Warning'); return
    }
    # convert ne pilote pas le lecteur : pas de --drive ni --device
    $a = @('convert')
    if ($cmbCvFmt.Text -and $cmbCvFmt.Text -ne '(auto)') { $a += "--format=$($cmbCvFmt.Text)" }
    if ($txtCvTracks.Text.Trim()) { $a += "--tracks=$($txtCvTracks.Text.Trim())" }
    $a += "`"$($txtCvIn.Text)`""
    $a += "`"$($txtCvOut.Text)`""
    Start-Gw $a
})

$tabCv.Controls.AddRange(@((New-Label (T 'Source :') '10,17'), $txtCvIn, $btnCvIn,
    (New-Label (T 'Destination :') '10,47'), $txtCvOut, $btnCvOut,
    (New-Label (T 'Format :') '10,78'), $cmbCvFmt,
    (New-Label (T 'Pistes :') '355,78'), $txtCvTracks, $btnConvert))

# ============================== COMPARAISON ====================================
$tabCmp = New-TabPage (T 'Comparaison')

$txtCmpRef = New-Object System.Windows.Forms.TextBox
$txtCmpRef.Location = '90,13'; $txtCmpRef.Width = 650; $txtCmpRef.Anchor = 'Top,Left,Right'
$btnCmpRef = New-Object System.Windows.Forms.Button
$btnCmpRef.Text = '...'; $btnCmpRef.Location = '745,12'; $btnCmpRef.Width = 30; $btnCmpRef.Anchor = 'Top,Right'
$btnCmpRef.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtCmpRef.Text) { $p = Split-Path -Parent $txtCmpRef.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') { $txtCmpRef.Text = $d.FileName }
})

# 12.8 (lot 2) : ligne du format detecte (Update-CmpFmtFound, Compare-Images), creee avant la liste liee
$lblCmpFmtFound = New-Object System.Windows.Forms.Label
$lblCmpFmtFound.Location = '350,84'; $lblCmpFmtFound.Size = '425,34'; $lblCmpFmtFound.Anchor = 'Top,Left,Right'
$lblCmpFmtFound.AutoEllipsis = $true; $lblCmpFmtFound.ForeColor = $script:Theme.Muted
$cmbCmpFmt = New-Object System.Windows.Forms.ComboBox
$cmbCmpFmt.Location = '90,43'; $cmbCmpFmt.Width = 200
# 12.8 (lot 2, D13) : « (detection automatique) » en tete, puis les formats, dans l ordre des codes du reglage
# compareFormat (compare.formatChoice) ; liste modifiable : un autre format de gw peut etre saisi, comme en 12.7
$script:CmpAutoItem = (T '(détection automatique)')
foreach ($cmpCode in @($script:SettingDefs['compareFormat'].Codes | Select-Object -First (1 + @($Formats | Where-Object { $_ -ne '(auto)' }).Count))) {
    [void]$cmbCmpFmt.Items.Add($(if ($cmpCode -eq 'auto') { $script:CmpAutoItem } else { $cmpCode }))
}
Register-SettingCtl 'compareFormat' $cmbCmpFmt
# Format saisi : reglage mis a jour des que le texte est un format de gw (une saisie incomplete ou inconnue ne change pas
# le reglage ; la comparaison prend le texte affiche, Get-CmpFormatChoice) ; element choisi : meme code que la liaison
$cmbCmpFmt.Add_TextChanged({
    if ($script:SettingSync) { return }
    $v = Get-CmpFormatChoice
    if ($v -and (ConvertTo-SettingValue 'compareFormat' $v) -ceq $v) { Set-Setting 'compareFormat' $v $this }
    else { $lblCmpFmtFound.Text = ''; $tip.SetToolTip($lblCmpFmtFound, '') }
})
$tip.SetToolTip($cmbCmpFmt, (T "Format de décodage commun : la référence est convertie dans ce format,`nla disquette est lue dans ce format, puis les deux sont comparées octet par octet.`n(détection automatique) : format déduit de la référence (taille et BPB d'un ADF, d'un ST ou d'un IMG ; décodage de deux pistes d'un IPF, d'un SCP ou d'un HFE), puis vérifié sur deux pistes de la disquette avant la lecture complète."))

$numCmpRetries = New-Object System.Windows.Forms.NumericUpDown
$numCmpRetries.Location = '365,43'; $numCmpRetries.Width = 55
$numCmpRetries.Minimum = 0; $numCmpRetries.Maximum = 50

$btnCmpFromWrite = New-Object System.Windows.Forms.Button
$btnCmpFromWrite.Text = (T 'Reprendre l''image de l''onglet Écriture'); $btnCmpFromWrite.Location = '440,41'; $btnCmpFromWrite.Size = '280,26'
$btnCmpFromWrite.Add_Click({
    if ($txtWFile.Text) {
        $txtCmpRef.Text = $txtWFile.Text
        # 12.8 (A1 § 4.2) : onglet Ecriture sur « (auto) » : detection automatique
        if ($cmbWFmt.Text -and $cmbWFmt.Text -ne '(auto)') { Set-Combo $cmbCmpFmt $cmbWFmt.Text } else { $cmbCmpFmt.SelectedIndex = 0 }
    }
})

$btnCompare = New-Object System.Windows.Forms.Button
$btnCompare.Text = (T 'COMPARER LA DISQUETTE'); $btnCompare.Location = '90,80'; $btnCompare.Size = '250,40'; $btnCompare.Font = $bold
$btnCompare.Add_Click({ try { Start-Compare } catch { Append-Log ((T "ERREUR comparaison : {0}") -f "$($_.Exception.Message)") } })

$txtCmpResult = New-Object System.Windows.Forms.TextBox
$txtCmpResult.Location = '10,130'; $txtCmpResult.Size = '768,190'
$txtCmpResult.Anchor = 'Top,Bottom,Left,Right'
$txtCmpResult.Multiline = $true; $txtCmpResult.ReadOnly = $true; $txtCmpResult.Font = $monoBig; $txtCmpResult.ForeColor = [System.Drawing.Color]::FromArgb(40,44,52)
$txtCmpResult.ScrollBars = 'Vertical'; $txtCmpResult.WordWrap = $false
$txtCmpResult.BackColor = [System.Drawing.SystemColors]::Control

$tabCmp.Controls.AddRange(@((New-Label (T 'Référence :') '10,17'), $txtCmpRef, $btnCmpRef,
    (New-Label (T 'Format :') '10,47'), $cmbCmpFmt, (New-Label (T 'Essais :') '305,47'), $numCmpRetries, $btnCmpFromWrite,
    $btnCompare, $lblCmpFmtFound, $txtCmpResult))

# ============================== QUALITE & ALIGNEMENT ===========================
$tabAl = New-TabPage (T 'Qualité & alignement')

$script:AlColors = @{
    0 = [System.Drawing.Color]::FromArgb(86, 196, 108)    # excellent (vert franc)
    1 = [System.Drawing.Color]::FromArgb(188, 214, 94)    # bon (vert-jaune)
    2 = [System.Drawing.Color]::FromArgb(245, 176, 66)    # moyen (orange)
    3 = $script:Theme.Danger                              # mauvais (rouge) ; 12.8 (D17) : texte blanc a 5,19:1 (233,86,80 : 3,55:1)
}
# texte lisible (noir ou blanc) sur chaque couleur d'etat
$script:AlFg = @{
    0 = [System.Drawing.Color]::FromArgb(14, 46, 20)
    1 = [System.Drawing.Color]::FromArgb(40, 44, 10)
    2 = [System.Drawing.Color]::FromArgb(54, 32, 0)
    3 = [System.Drawing.Color]::White
}
$script:AlNames = @{ 0='EXCELLENT'; 1=(T 'BON'); 2=(T 'MOYEN'); 3=(T 'MAUVAIS') }

$cmbAlPreset = New-Object System.Windows.Forms.ComboBox
$cmbAlPreset.Location = '70,11'; $cmbAlPreset.Width = 160; $cmbAlPreset.DropDownStyle = 'DropDownList'
[void]$cmbAlPreset.Items.AddRange(@((T 'Rapide (5 cylindres)'),(T 'Standard (0-70 pas 10)'),(T 'Complet (0-79)'),(T 'Personnalisé')))
$tip.SetToolTip($cmbAlPreset, (T "Rapide : contrôle en 30 s. Standard : tri de collection. Complet : état exhaustif d'une disquette (2-3 min)."))
$cmbAlPreset.Add_SelectedIndexChanged({
    switch ($cmbAlPreset.SelectedIndex) {
        0 { $txtAlCyls.Text = '0,20,40,60,79' }
        1 { $txtAlCyls.Text = '0,10,20,30,40,50,60,70' }
        2 { $txtAlCyls.Text = (0..79) -join ',' }
    }
})
Register-SettingCtl 'alignPreset' $cmbAlPreset   # 12.8 (point 7) : enregistre par son code (align.presetCode), plus par son texte traduit

$txtAlCyls = New-Object System.Windows.Forms.TextBox
$txtAlCyls.Location = '305,11'; $txtAlCyls.Width = 170
$tip.SetToolTip($txtAlCyls, (T 'Cylindres mesurés (0-83), séparés par des virgules.'))
$txtAlCyls.Add_TextChanged({ if ($cmbAlPreset.SelectedIndex -ne 3 -and $txtAlCyls.Focused) { $cmbAlPreset.SelectedIndex = 3 } })

$cmbAlHead = New-Object System.Windows.Forms.ComboBox
$cmbAlHead.Location = '530,11'; $cmbAlHead.Width = 55; $cmbAlHead.DropDownStyle = 'DropDownList'
[void]$cmbAlHead.Items.AddRange(@('0','1','0+1'))

$numAlRevs = New-Object System.Windows.Forms.NumericUpDown
$numAlRevs.Location = '645,11'; $numAlRevs.Width = 45
$numAlRevs.Minimum = 1; $numAlRevs.Maximum = 10
$tip.SetToolTip($numAlRevs, (T 'Tours lus par piste. 3 suffit ; 5 pour une disquette douteuse.'))

$chkAlLoop = New-Object System.Windows.Forms.CheckBox
$chkAlLoop.Text = (T 'Continu'); $chkAlLoop.Location = '700,12'; $chkAlLoop.Width = 75
$tip.SetToolTip($chkAlLoop, (T 'Répète la mesure en boucle (réglage mécanique). STOP pour arrêter.'))
$numAlPause = New-Object System.Windows.Forms.NumericUpDown
$numAlPause.Location = '700,36'; $numAlPause.Width = 45; $numAlPause.Visible = $false
$numAlPause.Minimum = 0; $numAlPause.Maximum = 60

$btnAlStart = New-Object System.Windows.Forms.Button
$btnAlStart.Text = (T 'MESURER LA DISQUETTE'); $btnAlStart.Location = '10,40'; $btnAlStart.Size = '220,40'; $btnAlStart.Font = $bold
$tip.SetToolTip($btnAlStart, (T 'Lit les cylindres choisis avec le lecteur sélectionné en haut et évalue l''état du support et la qualité de lecture.'))
$btnAlStart.Add_Click({
    if (-not $script:ScpStatsOk) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Le module d''analyse SCP n''a pas pu être compilé (Add-Type).'),(T 'Mesure'),'OK','Warning'); return
    }
    $script:AlignLoop = [bool]$chkAlLoop.Checked
    $script:AlLastMove = 0
    $script:QualView.Pass = 0                             # 12.8 (lot 3a) : nouvelle serie, passes de la mesure continue depuis 1
    Start-AlignCycle
})

$btnAlRef = New-Object System.Windows.Forms.Button
$btnAlRef.Text = (T 'Fixer comme référence'); $btnAlRef.Location = '240,40'; $btnAlRef.Size = '175,40'
$tip.SetToolTip($btnAlRef, (T "Mémorise la dernière mesure comme référence (ex. : lecteur Amiga sur la même disquette).`nLes mesures suivantes affichent l'écart en %."))
$btnAlRef.Add_Click({
    if (-not $script:AlignLast) { [void][System.Windows.Forms.MessageBox]::Show((T 'Faites d''abord une mesure.'),(T 'Référence'),'OK','Information'); return }
    $script:AlignRef = $script:AlignLast.Clone()
    $script:AlignRefLabel = ((T "lecteur {0}, tête {1}, {2}") -f "$($cmbDrive.Text)", "$($cmbAlHead.Text)", "$(Get-Date -Format 'dd/MM HH:mm')")
    $lblAlRef.Text = ((T "Référence : {0} ({1} piste(s))") -f "$($script:AlignRefLabel)", "$($script:AlignRef.Count)")
    Append-Log ((T "Mesure : référence fixée ({0}).") -f "$($script:AlignRefLabel)")
    [void](Save-Config)
    Render-AlignBars
})

$btnAlReset = New-Object System.Windows.Forms.Button
$btnAlReset.Text = (T 'Réinitialiser'); $btnAlReset.Location = '424,40'; $btnAlReset.Size = '120,40'
$tip.SetToolTip($btnAlReset, (T 'Efface le meilleur score, la tendance, la référence et le guide.'))
$btnAlReset.Add_Click({
    $script:AlignBest = @{}; $script:AlignPrev = $null; $script:AlignRef = $null; $script:AlignLast = $null
    $script:AlPos = $null; $script:AlLastMove = 0; $script:AlPosScores = @{}; $script:AlignRefLabel = ''
    $lblAlRef.Text = (T 'Aucune référence')
    $lblAlPos.Text = ''; $lblAlReco.Text = ''
    $lvAl.Items.Clear(); $pnlAlBars.Invalidate()
    Reset-QualityView                                     # 12.8 (lot 3a) : carte vide, plus aucun resultat
})

$chkAlGuide = New-Object System.Windows.Forms.CheckBox
$chkAlGuide.Text = (T 'Mode réglage du lecteur (guide)'); $chkAlGuide.Location = '556,48'; $chkAlGuide.Width = 220
$tip.SetToolTip($chkAlGuide, (T 'Affiche les boutons du guide d''alignement (positions du stepper, recommandations avancer/reculer).'))
$chkAlGuide.Add_CheckedChanged({
    $v = $chkAlGuide.Checked
    $btnAlPos0.Visible = $v; $btnAlPlus.Visible = $v; $btnAlMinus.Visible = $v; $lblAlPos.Visible = $v; $lblAlReco.Visible = $v
    $numAlPause.Visible = $v
})

$lblAlRef = New-Object System.Windows.Forms.Label
$lblAlRef.Location = '10,78'; $lblAlRef.AutoSize = $true; $lblAlRef.Text = (T 'Aucune référence'); $lblAlRef.ForeColor = 'Gray'

# --- Guide (visible en mode reglage)
$btnAlPos0 = New-Object System.Windows.Forms.Button
$btnAlPos0.Text = (T 'Repère (position 0)'); $btnAlPos0.Location = '10,96'; $btnAlPos0.Size = '155,26'; $btnAlPos0.Visible = $false
$tip.SetToolTip($btnAlPos0, (T "Point de départ : stepper à sa position d'origine (trait de repère). Mesure la position 0 et démarre le guide."))
$btnAlPos0.Add_Click({ $script:AlPos = 0; $script:AlLastMove = 0; $script:AlPosScores = @{}; $script:AlignLoop = $false; Start-AlignCycle })
$btnAlPlus = New-Object System.Windows.Forms.Button
$btnAlPlus.Text = (T "J'ai tourné +1 cran"); $btnAlPlus.Location = '172,96'; $btnAlPlus.Size = '160,26'; $btnAlPlus.Visible = $false
$tip.SetToolTip($btnAlPlus, (T "À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '+'. Lance la mesure."))
$btnAlPlus.Add_Click({ if ($null -eq $script:AlPos) { $script:AlPos = 0 }; $script:AlPos += 1; $script:AlLastMove = 1; $script:AlignLoop = $false; Start-AlignCycle })
$btnAlMinus = New-Object System.Windows.Forms.Button
$btnAlMinus.Text = (T "J'ai tourné -1 cran"); $btnAlMinus.Location = '339,96'; $btnAlMinus.Size = '160,26'; $btnAlMinus.Visible = $false
$tip.SetToolTip($btnAlMinus, (T "À cliquer APRÈS avoir tourné le stepper d'un petit cran dans le sens '-'. Lance la mesure."))
$btnAlMinus.Add_Click({ if ($null -eq $script:AlPos) { $script:AlPos = 0 }; $script:AlPos -= 1; $script:AlLastMove = -1; $script:AlignLoop = $false; Start-AlignCycle })
$lblAlPos = New-Object System.Windows.Forms.Label
$lblAlPos.Location = '508,101'; $lblAlPos.AutoSize = $true; $lblAlPos.Text = ''; $lblAlPos.ForeColor = 'Gray'; $lblAlPos.Visible = $false

# --- Carte de resultat (12.8, lot 3b, variante A : D14) : score de lecture (barres de signal, niveau, tendance) a gauche,
# etat du support a droite, pastille « en cours » ou « perime » (D16). Remplace le bandeau d etat et la ligne de score de
# la 12.7. Dessinee dans un bitmap par Render-QualityCard (module 195), d apres $script:QualView ; textes complets dans
# l infobulle (Update-QualityView)
$pnlQualCard = New-Object System.Windows.Forms.Panel
$pnlQualCard.Name = 'pnlQualCard'
$pnlQualCard.Location = '10,126'; $pnlQualCard.Size = '768,58'; $pnlQualCard.Anchor = 'Top,Left,Right'
$pnlQualCard.BackColor = [System.Drawing.Color]::White; $pnlQualCard.BackgroundImageLayout = 'None'
$pnlQualCard.AccessibleRole = 'StaticText'
$pnlQualCard.Add_Resize({ Render-QualityCard })

$lblAlReco = New-Object System.Windows.Forms.Label
$lblAlReco.Location = '10,188'; $lblAlReco.Size = '768,20'; $lblAlReco.Anchor = 'Top,Left,Right'
$lblAlReco.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblAlReco.TextAlign = 'MiddleCenter'; $lblAlReco.Text = ''; $lblAlReco.ForeColor = 'DimGray'; $lblAlReco.Visible = $false

$pnlAlBars = New-Object System.Windows.Forms.Panel
$pnlAlBars.Location = '10,210'; $pnlAlBars.Size = '768,50'; $pnlAlBars.Anchor = 'Top,Left,Right'
$pnlAlBars.BackColor = 'White'; $pnlAlBars.BorderStyle = 'FixedSingle'
$pnlAlBars.Add_Paint({ Draw-AlignBars $_.Graphics $pnlAlBars.ClientSize })
$pnlAlBars.Add_Resize({ $pnlAlBars.Invalidate() })
$tip.SetToolTip($pnlAlBars, (T 'Score par cylindre : barre courte = bon. Trait noir = référence, trait bleu = meilleur vu.'))

$lvAl = New-Object System.Windows.Forms.ListView
$lvAl.Location = '10,266'; $lvAl.Size = '768,60'; $lvAl.Anchor = 'Top,Bottom,Left,Right'
$lvAl.View = 'Details'; $lvAl.FullRowSelect = $true; $lvAl.GridLines = $false; $lvAl.Font = $monoBig
$lvAl.OwnerDraw = $true; $lvAl.HeaderStyle = 'Nonclickable'
$lvAl.BackColor = [System.Drawing.Color]::White
# 12.8 (lot 3) : pinceaux, stylo et formats en cache (Get-QualBrush, Get-QualPen, Get-QualSf : plus d allocation a chaque
# dessin) ; cases grises tant que le resultat affiche n est pas le resultat courant (mesure en cours, perime : D16) ;
# icones de 16 px (D15) devant l etat et devant le score, d apres Item.Tag (New-AlignRow)
$lvAl.Add_DrawColumnHeader({
    param($s0, $e)
    $e.Graphics.FillRectangle((Get-QualBrush $script:Theme.Accent2), $e.Bounds)
    $r = [System.Drawing.RectangleF]::new($e.Bounds.X + 4, $e.Bounds.Y, $e.Bounds.Width - 8, $e.Bounds.Height)
    $e.Graphics.DrawString($e.Header.Text, $bold, [System.Drawing.Brushes]::White, $r, (Get-QualSf $(if ($e.ColumnIndex -eq 0) { 'hnear' } else { 'hcenter' })))
})
$lvAl.Add_DrawSubItem({ param($s0, $e) Draw-AlSubItem $e $lvAl.Font })
$imgRow = New-Object System.Windows.Forms.ImageList
$imgRow.ImageSize = New-Object System.Drawing.Size(1, 24)
$lvAl.SmallImageList = $imgRow
# 12.8 (lot 3b) : colonnes Etat et Score elargies pour l icone de 16 px (140 -> 162, 65 -> 80)
foreach ($c in @(@((T 'Piste'),60),@((T 'État'),162),@((T 'Erreurs'),70),@((T 'Trous'),78),@('Stab',55),@((T 'Jitter ns'),80),@('Score',80),@((T 'vs réf'),70),@('Asym.',70),@((T 'Cell ns'),75))) {
    [void]$lvAl.Columns.Add($c[0], $c[1])
}

$tabAl.Controls.AddRange(@((New-Label (T 'Mesure :') '10,14'), $cmbAlPreset, (New-Label (T 'Cylindres :') '238,14'), $txtAlCyls,
    (New-Label (T 'Têtes :') '488,14'), $cmbAlHead, (New-Label (T 'Tours :') '598,14'), $numAlRevs, $chkAlLoop, $numAlPause,
    $btnAlStart, $btnAlRef, $btnAlReset, $chkAlGuide, $lblAlRef,
    $btnAlPos0, $btnAlPlus, $btnAlMinus, $lblAlPos, $pnlQualCard, $lblAlReco, $pnlAlBars, $lvAl))
Update-QualityView                                        # 12.8 (lot 3) : carte vide (« Aucune mesure »)

# ============================== OUTILS =========================================
$tabT = New-TabPage (T 'Outils')

$btnInfo  = New-ToolButton (T 'Tester la carte (info)')   '15,15'  { $a = @('info'); if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }; Start-Gw $a }
$btnRpm   = New-ToolButton (T 'Mesurer la vitesse (rpm)') '15,52'  { Start-Gw (@('rpm') + (Get-CommonArgs)) }
$btnBw    = New-ToolButton (T 'Débit USB (bandwidth)')    '15,89'  { Start-Gw @('bandwidth') }
$btnReset = New-ToolButton (T 'Réinitialiser la carte (reset)') '15,126' { Start-Gw @('reset') }

$btnUpdate = New-ToolButton (T 'Mise à jour firmware') '15,163' {
    # 12.8 (D3) : confirmation par frmConfirm (materiel), sans case
    $cq = @{ Title = (T 'Mise à jour firmware'); Heading = (T 'Mettre à jour le firmware du Greaseweazle'); Level = 'warn'; Picto = 'warn'
             Text = (T "gw update installe un nouveau firmware sur la carte. Ne débranchez pas le Greaseweazle pendant l'opération."); GoText = (T 'Mettre à jour'); GoGlyph = 'Sync' }
    if (Show-AppConfirm @cq) { Start-Gw @('update') }
}

$numSeek = New-Object System.Windows.Forms.NumericUpDown
$numSeek.Location = '355,18'; $numSeek.Width = 60
$numSeek.Minimum = -8; $numSeek.Maximum = 85
$tip.SetToolTip($numSeek, (T 'Cylindre cible. Valeurs négatives possibles sur lecteur flippy.'))

$btnSeek = New-Object System.Windows.Forms.Button
$btnSeek.Text = 'Seek'; $btnSeek.Location = '425,17'; $btnSeek.Size = '80,26'
$btnSeek.Add_Click({ Start-Gw (@('seek') + (Get-CommonArgs) + @("$($numSeek.Value)")) })

$txtEraseTracks = New-Object System.Windows.Forms.TextBox
$txtEraseTracks.Location = '355,55'; $txtEraseTracks.Width = 150
$tip.SetToolTip($txtEraseTracks, (T 'TSPEC optionnel. Vide = toute la disquette.'))

$btnErase = New-Object System.Windows.Forms.Button
$btnErase.Text = (T 'EFFACER'); $btnErase.Location = '515,54'; $btnErase.Size = '100,26'
$btnErase.Add_Click({
    # 12.8 (D3) : confirmation par frmConfirm (effacement irreversible), case qui nomme le lecteur
    $tr = $txtEraseTracks.Text.Trim(); $drv = "$($cmbDrive.Text)"
    $txt = if ($tr) { (T "Les pistes {0} de la disquette du lecteur {1} seront effacées : leur contenu ne pourra pas être récupéré.") -f "$tr", $drv }
           else { (T "Toute la disquette du lecteur {0} sera effacée : son contenu ne pourra pas être récupéré.") -f $drv }
    $cq = @{ Title = (T 'Confirmation effacement'); Heading = (T 'Effacement irréversible'); Text = $txt; Level = 'danger'; Picto = 'erase'
             Check = ((T 'La disquette du lecteur {0} peut être effacée') -f $drv); GoText = (T 'Effacer la disquette'); GoGlyph = 'Delete' }
    if (Show-AppConfirm @cq) {
        $a = @('erase') + (Get-CommonArgs)
        if ($tr) { $a += "--tracks=$tr" }
        Start-Gw $a
    }
})

$numPasses = New-Object System.Windows.Forms.NumericUpDown
$numPasses.Location = '355,92'; $numPasses.Width = 50
$numPasses.Minimum = 1; $numPasses.Maximum = 20

$numLinger = New-Object System.Windows.Forms.NumericUpDown
$numLinger.Location = '470,92'; $numLinger.Width = 60
$numLinger.Minimum = 0; $numLinger.Maximum = 5000
$tip.SetToolTip($numLinger, (T 'Temps de contact par pas, en millisecondes.'))
# 12.8 (point 7, D9) : passes et linger enregistres (tools.passes, tools.linger), defaut 3 x 500 ms, celui du prereglage
# « Standard » de la fenetre de nettoyage (12.7 : 3 x 100 ms ici)
Register-SettingCtl 'cleanPasses' $numPasses
Register-SettingCtl 'cleanLinger' $numLinger

$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = (T 'NETTOYER'); $btnClean.Location = '540,91'; $btnClean.Size = '100,26'
# Fenetre de nettoyage de l Accueil (avertissement, procedure, case obligatoire, suivi), avec les passes et le linger
# de cet onglet en 4e duree
$btnClean.Add_Click({ Show-CleanDialog -Passes ([int]$numPasses.Value) -Linger ([int]$numLinger.Value) })

$numPin = New-Object System.Windows.Forms.NumericUpDown
$numPin.Location = '355,129'; $numPin.Width = 50
$numPin.Minimum = 1; $numPin.Maximum = 34

$cmbPinLvl = New-Object System.Windows.Forms.ComboBox
$cmbPinLvl.Location = '420,129'; $cmbPinLvl.Width = 55; $cmbPinLvl.DropDownStyle = 'DropDownList'
[void]$cmbPinLvl.Items.AddRange(@('H','L'))

$btnPin = New-Object System.Windows.Forms.Button
$btnPin.Text = (T 'Appliquer'); $btnPin.Location = '485,128'; $btnPin.Size = '100,26'
$btnPin.Add_Click({ Start-Gw (@('pin') + (Get-CommonArgs) + @("$($numPin.Value)", $cmbPinLvl.Text)) })

$tabT.Controls.AddRange(@($btnInfo,$btnRpm,$btnBw,$btnReset,$btnUpdate,
    (New-Label (T 'Seek cylindre :') '250,21'), $numSeek, $btnSeek,
    (New-Label (T 'Erase tracks :') '250,58'), $txtEraseTracks, $btnErase,
    (New-Label (T 'Clean passes :') '250,95'), $numPasses, (New-Label (T 'linger :') '415,95'), $numLinger, $btnClean,
    (New-Label (T 'Pin :') '250,132'), $numPin, $cmbPinLvl, $btnPin))

# ============================== DELAIS =========================================
$tabD = New-TabPage (T 'Délais')

$delayDefs = @(
    @{Key='select';     Label=(T 'Select Delay (us) :'); Def=10},
    @{Key='step';       Label=(T 'Step Delay (us) :');   Def=10000},
    @{Key='settle';     Label=(T 'Settle Time (ms) :');  Def=15},
    @{Key='motor';      Label=(T 'Motor Delay (ms) :');  Def=750},
    @{Key='watchdog';   Label=(T 'Watchdog (ms) :');     Def=10000},
    @{Key='pre-write';  Label=(T 'Pre-Write (us) :');    Def=100},
    @{Key='post-write'; Label=(T 'Post-Write (us) :');   Def=1000},
    @{Key='index-mask'; Label=(T 'Index Mask (us) :');   Def=200}
)
$script:DelayCtrls = [ordered]@{}
$y = 15
foreach ($d in $delayDefs) {
    $tabD.Controls.Add((New-Label $d.Label "15,$($y+3)"))
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Location = "175,$($y+2)"; $chk.Width = 18
    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Location = "200,$y"; $num.Width = 85
    $num.Minimum = 0; $num.Maximum = 1000000
    $num.Enabled = $false
    $chk.Tag = $num
    $chk.Add_CheckedChanged({ $this.Tag.Enabled = $this.Checked })
    $tabD.Controls.AddRange(@($chk,$num))
    $script:DelayCtrls[$d.Key] = @{Chk=$chk; Num=$num; Def=$d.Def}
    $y += 32
}

$btnDelaysShow = New-Object System.Windows.Forms.Button
$btnDelaysShow.Text = (T 'Afficher les délais actuels'); $btnDelaysShow.Location = '330,15'; $btnDelaysShow.Size = '230,32'
$btnDelaysShow.Add_Click({ Start-Gw @('delays') })

$btnDelaysSet = New-Object System.Windows.Forms.Button
$btnDelaysSet.Text = (T 'Appliquer les valeurs cochées'); $btnDelaysSet.Location = '330,55'; $btnDelaysSet.Size = '230,32'
$btnDelaysSet.Add_Click({
    $a = @('delays')
    foreach ($k in $script:DelayCtrls.Keys) {
        $c = $script:DelayCtrls[$k]
        if ($c.Chk.Checked) { $a += "--$k=$($c.Num.Value)" }
    }
    if ($a.Count -eq 1) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Cochez au moins un paramètre à modifier.'),(T 'Rien à faire'),'OK','Information'); return
    }
    Start-Gw $a
})

$lblDelayNote = New-Object System.Windows.Forms.Label
$lblDelayNote.Text = (T "Valeurs pré-remplies = défauts usine, à titre indicatif.`n") +
                     (T "Cochez une case pour transmettre le paramètre à gw.`n`n") +
                     (T "Seek en échec / Track 0 not found : augmenter Step`n") +
                     (T "(20000 à 40000 us) puis Settle (40 ms).`n`n") +
                     (T "Les modifications ne survivent pas à un reset ni à un`n") +
                     (T "débranchement du Greaseweazle.")
$lblDelayNote.Location = '330,100'; $lblDelayNote.Size = '400,150'

$tabD.Controls.AddRange(@($btnDelaysShow,$btnDelaysSet,$lblDelayNote))

# ============================== COMMANDE LIBRE =================================
$tabC = New-TabPage (T 'Commande libre')

$txtC = New-Object System.Windows.Forms.TextBox
$txtC.Location = '10,40'; $txtC.Width = 768; $txtC.Font = $mono; $txtC.Anchor = 'Top,Left,Right'

$btnC = New-Object System.Windows.Forms.Button
$btnC.Text = (T 'EXÉCUTER'); $btnC.Location = '10,75'; $btnC.Size = '150,40'; $btnC.Font = $bold
$btnC.Add_Click({ if ($txtC.Text.Trim()) { Start-Gw @($txtC.Text.Trim()) } })

$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Text = 'gw help'; $btnHelp.Location = '175,75'; $btnHelp.Size = '110,34'
$btnHelp.Add_Click({ Start-Gw @('help') })

$cmbHelpAct = New-Object System.Windows.Forms.ComboBox
$cmbHelpAct.Location = '300,79'; $cmbHelpAct.Width = 130; $cmbHelpAct.DropDownStyle = 'DropDownList'
[void]$cmbHelpAct.Items.AddRange(@('info','read','write','convert','erase','clean','seek','delays','update','pin','reset','bandwidth','rpm'))

$btnHelpAct = New-Object System.Windows.Forms.Button
$btnHelpAct.Text = '--help'; $btnHelpAct.Location = '440,75'; $btnHelpAct.Size = '90,34'
$btnHelpAct.Add_Click({ Start-Gw @($cmbHelpAct.Text, '--help') })

$tabC.Controls.AddRange(@((New-Label (T 'Arguments passés à gw (sans "gw") :') '10,17'), $txtC, $btnC,
    $btnHelp, $cmbHelpAct, $btnHelpAct))

