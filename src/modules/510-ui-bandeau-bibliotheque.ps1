# --- Bandeau (logo, titre, lecteur) --------------------------------------------
$pnlTop = New-Object System.Windows.Forms.Panel
$pnlTop.Size = New-Object System.Drawing.Size(790, 64)
$pnlTop.Dock = 'Top'
$pnlTop.BackgroundImageLayout = 'None'
$pnlTop.Add_Resize({ Render-Banner })

$lblGwStatus = New-BannerLabel '' '556,10'
$lblGwStatus.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
if (Test-Path -LiteralPath $script:GwExe) {
    $lblGwStatus.Text = (T '●  gw.exe prêt'); $lblGwStatus.ForeColor = [System.Drawing.Color]::FromArgb(150, 235, 160)
} else {
    $lblGwStatus.Text = (T '●  gw.exe introuvable'); $lblGwStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 150)
}
$tip.SetToolTip($lblGwStatus, $script:GwExe)

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = '556,34'; $cmbDrive.Width = 45; $cmbDrive.DropDownStyle = 'DropDownList'
$cmbDrive.Anchor = 'Top,Right'
[void]$cmbDrive.Items.AddRange(@('A','B','0','1','2','3'))
$tip.SetToolTip($cmbDrive, (T "A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0 à 3 = bus Shugart (nappe droite) - typiquement le lecteur Amiga`nAu démarrage, l'application sélectionne le premier lecteur qui répond."))
Register-SettingCtl 'drive' $cmbDrive          # 12.8 (point 7) : lecteur de toute l application (fenetre de nettoyage comprise)

$txtDev = New-Object System.Windows.Forms.TextBox
$txtDev.Location = '652,34'; $txtDev.Width = 50; $txtDev.Anchor = 'Top,Right'
$tip.SetToolTip($txtDev, (T 'Port COM du Greaseweazle. Vide = détection automatique.'))

$chkTime = New-Object System.Windows.Forms.CheckBox
$chkTime.Text = (T 'Chrono'); $chkTime.Location = '712,35'; $chkTime.Width = 70; $chkTime.Anchor = 'Top,Right'
$chkTime.BackColor = [System.Drawing.Color]::Transparent; $chkTime.ForeColor = [System.Drawing.Color]::White
$tip.SetToolTip($chkTime, (T 'Affiche le temps écoulé après chaque commande gw (option --time).'))

# Mode expert : affiche aussi les onglets techniques (Conversion, Comparaison, Outils, Délais, Commande libre)
$chkExpert = New-Object System.Windows.Forms.CheckBox
$chkExpert.Text = (T 'Mode expert'); $chkExpert.Location = '404,9'; $chkExpert.AutoSize = $true; $chkExpert.Anchor = 'Top,Right'
$chkExpert.BackColor = [System.Drawing.Color]::Transparent; $chkExpert.ForeColor = [System.Drawing.Color]::White
$tip.SetToolTip($chkExpert, (T "Décoché : seuls les onglets utiles au quotidien sont affichés (Accueil, Restauration, Bibliothèque, Écriture, Lecture, Qualité).`nCoché : tous les onglets, y compris Conversion, Comparaison, Outils, Délais et Commande libre."))

# Aide en ligne (wiki) pour l onglet affiche ; touche F1
$btnHelpTop = New-Object System.Windows.Forms.Button
$btnHelpTop.Text = (T 'Aide'); $btnHelpTop.Location = '404,33'; $btnHelpTop.Size = '84,26'; $btnHelpTop.Anchor = 'Top,Right'
$btnHelpTop.Add_Click({ Open-HelpForTab })
$tip.SetToolTip($btnHelpTop, (T 'Ouvre le guide en ligne de l''onglet affiché (touche F1).'))

$pnlTop.Controls.AddRange(@($lblGwStatus, (New-BannerLabel (T 'Lecteur :') '500,37'), $cmbDrive,
    (New-BannerLabel (T 'COM :') '612,37'), $txtDev, $chkTime, $chkExpert, $btnHelpTop))

# --- Separateur onglets / journal ----------------------------------------------
$split = New-Object System.Windows.Forms.SplitContainer
$split.Orientation = 'Horizontal'
$split.Size = New-Object System.Drawing.Size(790, 644)
$split.Panel1MinSize = 300
$split.Panel2MinSize = 80
$split.SplitterWidth = 6
$split.SplitterDistance = 372
$split.Dock = 'Fill'

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Padding = New-Object System.Drawing.Point(12, 5)

# ============================== BIBLIOTHEQUE ===================================
$tabL = New-TabPage (T 'Bibliothèque')

$txtLibRoot = New-Object System.Windows.Forms.TextBox
$txtLibRoot.Location = '85,11'; $txtLibRoot.Width = 610; $txtLibRoot.Anchor = 'Top,Left,Right'

$btnLibRoot = New-Object System.Windows.Forms.Button
$btnLibRoot.Text = (T 'Choisir le dossier racine'); $btnLibRoot.Location = '700,10'; $btnLibRoot.Width = 36; $btnLibRoot.Anchor = 'Top,Right'
$btnLibRoot.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = (T 'Répertoire racine de la bibliothèque d''images')
    if ($txtLibRoot.Text -and (Test-Path -LiteralPath $txtLibRoot.Text)) { $d.SelectedPath = $txtLibRoot.Text }
    if ($d.ShowDialog() -eq 'OK') { $txtLibRoot.Text = $d.SelectedPath; Update-Library }
})

$btnLibRefresh = New-Object System.Windows.Forms.Button
$btnLibRefresh.Text = (T 'Actualiser l''arborescence'); $btnLibRefresh.Location = '742,10'; $btnLibRefresh.Width = 36; $btnLibRefresh.Anchor = 'Top,Right'
$btnLibRefresh.Add_Click({ Update-Library })

$txtLibFilter = New-Object System.Windows.Forms.TextBox
$txtLibFilter.Location = '85,41'; $txtLibFilter.Width = 230
$tip.SetToolTip($txtLibFilter, (T "Recherche dans l'index : plusieurs mots = tous requis (ex. : monkey 2 fr).`nRésultats au fil de la frappe une fois l'index construit. Vide = arborescence."))
$txtLibFilter.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $script:LibSearchAt = $null; Update-Library } })
$txtLibFilter.Add_TextChanged({ $script:LibSearchAt = (Get-Date).AddMilliseconds(350) })

$btnLibFilter = New-Object System.Windows.Forms.Button
$btnLibFilter.Text = (T 'Chercher'); $btnLibFilter.Location = '320,40'; $btnLibFilter.Width = 36
$btnLibFilter.Add_Click({ $script:LibSearchAt = $null; Update-Library })

$chkLibImgOnly = New-Object System.Windows.Forms.CheckBox
$chkLibImgOnly.Text = (T 'Images seulement'); $chkLibImgOnly.Location = '398,42'; $chkLibImgOnly.Width = 130
$chkLibImgOnly.Add_CheckedChanged({ Update-Library })

$lblLibCount = New-Object System.Windows.Forms.Label
$lblLibCount.Location = '530,44'; $lblLibCount.Size = '148,18'; $lblLibCount.Anchor = 'Top,Left,Right'; $lblLibCount.Text = ''; $lblLibCount.ForeColor = 'DimGray'

$btnLibReindex = New-Object System.Windows.Forms.Button
$btnLibReindex.Text = (T 'Réindexer'); $btnLibReindex.Location = '683,40'; $btnLibReindex.Width = 95; $btnLibReindex.Anchor = 'Top,Right'
$tip.SetToolTip($btnLibReindex, (T "Reconstruit l'index de la racine (en arrière-plan). À faire après l'ajout ou le déplacement de fichiers."))
$btnLibReindex.Add_Click({ Start-LibIndex $true })

$treeLib = New-Object System.Windows.Forms.TreeView
$treeLib.Location = '10,70'; $treeLib.Size = '445,250'
$treeLib.Anchor = 'Top,Bottom,Left,Right'
$treeLib.HideSelection = $false
$treeLib.Add_BeforeExpand({ Expand-LibNode $_.Node })
$treeLib.Add_AfterSelect({ Show-LibSelection $_.Node })

$txtLibInfo = New-Object System.Windows.Forms.TextBox
$txtLibInfo.Location = '465,70'; $txtLibInfo.Size = '313,135'
$txtLibInfo.Anchor = 'Top,Bottom,Right'
$txtLibInfo.Multiline = $true; $txtLibInfo.ReadOnly = $true; $txtLibInfo.Font = $mono; $txtLibInfo.ForeColor = [System.Drawing.Color]::FromArgb(40,44,52)
$txtLibInfo.ScrollBars = 'Vertical'
$txtLibInfo.BackColor = [System.Drawing.SystemColors]::Control

$btnLibFast = New-Object System.Windows.Forms.Button
$btnLibFast.Text = (T 'Écriture rapide'); $btnLibFast.Location = '465,213'; $btnLibFast.Size = '154,38'; $btnLibFast.Font = $bold
$btnLibFast.Anchor = 'Bottom,Right'; $btnLibFast.Enabled = $false
$tip.SetToolTip($btnLibFast, (T "Écrit l'image sélectionnée en une passe, les deux têtes ensemble : image entière, profil de précompensation Auto,`npré-effacement, effacement des pistes vides, vérification gw, 10 essais, sans contrôle complet des pistes.`nSans calibration commune pour la famille de l'image, le lecteur est d'abord calibré : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibFast, $tip.GetToolTip($btnLibFast) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$btnLibFast.Add_Click({ Start-LibWrite 'fast' })
$btnLibSlow = New-Object System.Windows.Forms.Button
$btnLibSlow.Text = (T 'Écriture lente'); $btnLibSlow.Location = '624,213'; $btnLibSlow.Size = '154,38'; $btnLibSlow.Font = $bold
$btnLibSlow.Anchor = 'Bottom,Right'; $btnLibSlow.Enabled = $false
$tip.SetToolTip($btnLibSlow, (T "Écrit la tête 0 puis la tête 1, chacune avec sa précompensation, puis contrôle toutes les pistes`net réécrit les pistes faibles, 3 passes au plus. Mêmes paramètres que l'écriture rapide.`nSans calibration par tête pour la famille de l'image, chaque tête est d'abord calibrée : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T "Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."))
$btnLibSlow.Add_Click({ Start-LibWrite 'slow' })

$btnLibOpen = New-Object System.Windows.Forms.Button
$btnLibOpen.Text = (T 'Ouvrir (application par défaut)'); $btnLibOpen.Location = '465,250'; $btnLibOpen.Size = '313,32'
$btnLibOpen.Anchor = 'Bottom,Right'; $btnLibOpen.Enabled = $false
$btnLibOpen.Add_Click({
    $sel = Resolve-LibSelection
    if (-not $sel) { return }
    try { Start-Process -FilePath $sel.Path } catch { Append-Log ((T "Ouverture impossible : {0}") -f "$($_.Exception.Message)") }
})

$btnLibExplore = New-Object System.Windows.Forms.Button
$btnLibExplore.Text = (T 'Ouvrir le dossier'); $btnLibExplore.Location = '465,287'; $btnLibExplore.Size = '313,32'
$btnLibExplore.Anchor = 'Bottom,Right'
$btnLibExplore.Add_Click({
    $n = $treeLib.SelectedNode
    if (-not $n -or -not $n.Tag) { return }
    $p = $n.Tag.Path
    if ($n.Tag.Kind -eq 'zipentry') { $p = $n.Tag.ZipPath }
    if ($p -and (Test-Path -LiteralPath $p)) {
        if ((Get-Item -LiteralPath $p).PSIsContainer) { Start-Process explorer.exe "`"$p`"" }
        else { Start-Process explorer.exe "/select,`"$p`"" }
    }
})

$tabL.Controls.AddRange(@((New-Label (T 'Racine :') '10,14'), $txtLibRoot, $btnLibRoot, $btnLibRefresh,
    (New-Label (T 'Recherche :') '10,44'), $txtLibFilter, $btnLibFilter, $chkLibImgOnly, $lblLibCount, $btnLibReindex,
    $treeLib, $txtLibInfo, $btnLibFast, $btnLibSlow, $btnLibOpen, $btnLibExplore))

