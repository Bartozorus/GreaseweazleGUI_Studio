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
$txtLibRoot.Location = '85,11'; $txtLibRoot.Width = 240; $txtLibRoot.Anchor = 'Top,Left,Right'

$btnLibRoot = New-Object System.Windows.Forms.Button
$btnLibRoot.Text = (T 'Choisir le dossier racine'); $btnLibRoot.Location = '330,10'; $btnLibRoot.Width = 36; $btnLibRoot.Anchor = 'Top,Right'
$btnLibRoot.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = (T 'Répertoire racine de la bibliothèque d''images')
    if ($txtLibRoot.Text -and (Test-Path -LiteralPath $txtLibRoot.Text)) { $d.SelectedPath = $txtLibRoot.Text }
    if ($d.ShowDialog() -eq 'OK') { $txtLibRoot.Text = $d.SelectedPath; Update-Library }
})

$btnLibRefresh = New-Object System.Windows.Forms.Button
$btnLibRefresh.Text = (T 'Actualiser l''arborescence'); $btnLibRefresh.Location = '372,10'; $btnLibRefresh.Width = 36; $btnLibRefresh.Anchor = 'Top,Right'
$btnLibRefresh.Add_Click({ Update-Library })

# 12.8 (lot 4b, D19, A3 § 3.4 B) : liste de reference (DAT) choisie par l utilisateur sur son ordinateur ; etat a cote du
# bouton (aucune, nom et nombre d entrees, illisible) ; retrait par la croix (le fichier n est pas supprime)
$btnLibDat = New-Object System.Windows.Forms.Button
$btnLibDat.Text = (T 'Liste de référence…'); $btnLibDat.Location = '414,10'; $btnLibDat.Width = 168; $btnLibDat.Anchor = 'Top,Right'
$tip.SetToolTip($btnLibDat, (T "Choisit une liste de référence (fichier DAT) sur votre ordinateur : format Logiqx XML (TOSEC, No-Intro) ou clrmamepro.`nLes images et les archives ZIP sont identifiées par leur taille puis leur empreinte (CRC-32, MD5 ou SHA-1) :`nofficiel (identique à une entrée de la liste), modifié (même nom qu'une entrée, contenu différent) ou inconnu.`nAucune liste n'est fournie ni téléchargée par l'application."))
$btnLibDat.Add_Click({ Select-LibDatFile })

$lblLibDat = New-Object System.Windows.Forms.Label
$lblLibDat.Location = '586,14'; $lblLibDat.Size = '164,18'; $lblLibDat.Anchor = 'Top,Right'; $lblLibDat.AutoEllipsis = $true
$lblLibDat.Font = New-Object System.Drawing.Font('Segoe UI', 9); $lblLibDat.ForeColor = $script:Theme.Muted; $lblLibDat.Text = (T 'aucune')

$btnLibDatClear = New-Object System.Windows.Forms.Button
$btnLibDatClear.Text = (T 'Retirer la liste de référence (le fichier n''est pas supprimé).'); $btnLibDatClear.Location = '752,10'; $btnLibDatClear.Width = 26
$btnLibDatClear.Anchor = 'Top,Right'; $btnLibDatClear.Visible = $false
$btnLibDatClear.Add_Click({ Set-LibDatPath '' })

$txtLibFilter = New-Object System.Windows.Forms.TextBox
$txtLibFilter.Location = '85,41'; $txtLibFilter.Width = 210
$tip.SetToolTip($txtLibFilter, (T "Recherche sur le nom des fichiers : plusieurs mots = tous requis (ex. : monkey 2 fr). La casse est ignorée ; la ponctuation compte : king quest trouve KingsQuest et King's Quest, kings ne trouve pas King's.`nCase « Aussi dans les dossiers » : les mots peuvent aussi être dans le nom des dossiers.`nRésultats au fil de la frappe une fois l'index construit, groupés par jeu. Vide = arborescence."))
$txtLibFilter.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $script:LibSearchAt = $null; Update-Library } })
$txtLibFilter.Add_TextChanged({ $script:LibSearchAt = (Get-Date).AddMilliseconds(350) })

$btnLibFilter = New-Object System.Windows.Forms.Button
$btnLibFilter.Text = (T 'Chercher'); $btnLibFilter.Location = '300,40'; $btnLibFilter.Width = 36
$btnLibFilter.Add_Click({ $script:LibSearchAt = $null; Update-Library })

# 12.8 (lot 4a, A3 § 4.2 n° 8) : recherche sur le nom du fichier par defaut ; ancienne regle (chemin complet) sur demande
$chkLibInDirs = New-Object System.Windows.Forms.CheckBox
$chkLibInDirs.Text = (T 'Aussi dans les dossiers'); $chkLibInDirs.Location = '344,42'; $chkLibInDirs.Width = 170
$tip.SetToolTip($chkLibInDirs, (T 'Cherche aussi les mots dans le nom des dossiers (chemin complet depuis la racine), comme avant la version 12.8.'))
$chkLibInDirs.Add_CheckedChanged({ if ($txtLibFilter.Text.Trim()) { Update-Library } })

$chkLibImgOnly = New-Object System.Windows.Forms.CheckBox
$chkLibImgOnly.Text = (T 'Images seulement'); $chkLibImgOnly.Location = '520,42'; $chkLibImgOnly.Width = 140
$chkLibImgOnly.Add_CheckedChanged({ Update-Library })

$btnLibReindex = New-Object System.Windows.Forms.Button
$btnLibReindex.Text = (T 'Réindexer'); $btnLibReindex.Location = '683,40'; $btnLibReindex.Width = 95; $btnLibReindex.Anchor = 'Top,Right'
$tip.SetToolTip($btnLibReindex, (T "Reconstruit l'index de la racine (en arrière-plan). À faire après l'ajout ou le déplacement de fichiers."))
$btnLibReindex.Add_Click({ Start-LibIndex $true })

# 12.8 (lot 4a, A3 § 4.2 n° 7) : filtres de la liste des resultats (inactifs dans l arborescence), en ligne
# (FlowLayoutPanel : largeurs ajustees aux textes francais et anglais) ; compteur sous la liste (FIX4B)
$flpLib = New-Object System.Windows.Forms.FlowLayoutPanel
$flpLib.Location = '6,68'; $flpLib.Size = '776,28'; $flpLib.Anchor = 'Top,Left,Right'; $flpLib.WrapContents = $false

$lblLibFmt = New-Object System.Windows.Forms.Label
$lblLibFmt.Text = (T 'Format :'); $lblLibFmt.AutoSize = $true; $lblLibFmt.Margin = New-Object System.Windows.Forms.Padding(4, 6, 0, 0)
$cmbLibFmt = New-Object System.Windows.Forms.ComboBox
$cmbLibFmt.DropDownStyle = 'DropDownList'; $cmbLibFmt.Width = 76; $cmbLibFmt.Margin = New-Object System.Windows.Forms.Padding(3, 2, 10, 0)
[void]$cmbLibFmt.Items.Add((T 'Tous')); $cmbLibFmt.SelectedIndex = 0
$tip.SetToolTip($cmbLibFmt, (T 'Formats présents dans les résultats de la recherche.'))
$cmbLibFmt.Add_SelectedIndexChanged({ Update-LibFilters })

$lblLibLang = New-Object System.Windows.Forms.Label
$lblLibLang.Text = (T 'Langue :'); $lblLibLang.AutoSize = $true; $lblLibLang.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$cmbLibLang = New-Object System.Windows.Forms.ComboBox
$cmbLibLang.DropDownStyle = 'DropDownList'; $cmbLibLang.Width = 66; $cmbLibLang.Margin = New-Object System.Windows.Forms.Padding(3, 2, 10, 0)
[void]$cmbLibLang.Items.Add((T 'Toutes')); $cmbLibLang.SelectedIndex = 0
$tip.SetToolTip($cmbLibLang, (T "Langues indiquées dans le nom (TOSEC : (fr), (en-de) ; No-Intro : (En,Fr)), ou langue du pays (TOSEC : (DE) ; en gris dans la liste). « M3 » : trois langues, non détaillées."))
$cmbLibLang.Add_SelectedIndexChanged({ Update-LibFilters })

$chkLibHideMod = New-Object System.Windows.Forms.CheckBox
$chkLibHideMod.Text = (T 'Masquer les copies modifiées'); $chkLibHideMod.AutoSize = $true; $chkLibHideMod.Margin = New-Object System.Windows.Forms.Padding(0, 4, 8, 0)
$tip.SetToolTip($chkLibHideMod, (T 'Masque les copies dont le nom porte une mention TOSEC de modification : [cr] déplombée, [f] corrigée, [h] et [m] modifiée, [p] pirate, [t] entraîneur, [tr] traduite.'))
$chkLibHideMod.Add_CheckedChanged({ Update-LibFilters })

$chkLibOrig = New-Object System.Windows.Forms.CheckBox
$chkLibOrig.Text = (T 'Originaux seulement'); $chkLibOrig.AutoSize = $true; $chkLibOrig.Margin = New-Object System.Windows.Forms.Padding(0, 4, 8, 0)
$tip.SetToolTip($chkLibOrig, (T "Sans liste de référence : ne garde que les IPF de structure SPS (bloc INFO lu dans le fichier : publication, révision, disquette). C'est un indice d'origine, pas une preuve.`nAvec une liste de référence (bouton « Liste de référence… ») : ne garde que les fichiers officiels, identiques à une entrée de la liste."))
$chkLibOrig.Add_CheckedChanged({ Update-LibFilters })

$flpLib.Controls.AddRange(@($lblLibFmt, $cmbLibFmt, $lblLibLang, $cmbLibLang, $chkLibHideMod, $chkLibOrig))

# FIX4B (revue du lot 4) : compteur sous la liste, sur toute sa largeur (dans la ligne des filtres, il ne restait que
# 142 px a 800 px de large : « 2 affiché(s), 3 masqué(s) » et l avancement de l analyse etaient coupes)
$lblLibCount = New-Object System.Windows.Forms.Label
$lblLibCount.Location = '10,316'; $lblLibCount.Size = '448,18'; $lblLibCount.Anchor = 'Bottom,Left,Right'; $lblLibCount.AutoEllipsis = $true
$lblLibCount.Text = ''; $lblLibCount.ForeColor = 'DimGray'

$treeLib = New-Object System.Windows.Forms.TreeView
$treeLib.Location = '10,98'; $treeLib.Size = '448,214'
$treeLib.Anchor = 'Top,Bottom,Left,Right'
$treeLib.HideSelection = $false
$treeLib.Add_BeforeExpand({ Expand-LibNode $_.Node })
$treeLib.Add_AfterSelect({ Show-LibSelection $_.Node })

# 12.8 (lot 4a, A3 § 4.2 n° 2 et 3, D18) : resultats de la recherche en liste groupee par titre court (groupes non
# repliables), colonnes et tri par colonne ; badge de format et d etat (pictogrammes du lot 3) dans la premiere colonne
$imgLibBadge = New-Object System.Windows.Forms.ImageList
$imgLibBadge.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$imgLibBadge.ImageSize = New-Object System.Drawing.Size(42, 16)

$lvLib = New-Object System.Windows.Forms.ListView
$lvLib.Location = '10,98'; $lvLib.Size = '448,214'
$lvLib.Anchor = 'Top,Bottom,Left,Right'
$lvLib.View = [System.Windows.Forms.View]::Details
$lvLib.FullRowSelect = $true; $lvLib.HideSelection = $false; $lvLib.MultiSelect = $false
$lvLib.ShowGroups = $true; $lvLib.ShowItemToolTips = $true; $lvLib.Visible = $false
$lvLib.SmallImageList = $imgLibBadge
$script:LibColTitles = @((T 'Variante'), (T 'Disq.'), (T 'Version'), (T 'Langue'), (T 'État'), (T 'Format'), (T 'Taille'), (T 'Dossier'))
# FIX4B (revue du lot 4) : largeur au moins celle du titre (« Language » en anglais ; colonne triee : Set-LibSort) ;
# « Etat » de 100 px (« officiel SPS », « manque 3 ») ; les cinq premieres colonnes tiennent a 800 px de large
$libColW = @(150, 44, 56, 50, 100, 50, 62, 140)
for ($libColI = 0; $libColI -lt $script:LibColTitles.Count; $libColI++) { [void]$lvLib.Columns.Add($script:LibColTitles[$libColI], (Get-LibColumnWidth $script:LibColTitles[$libColI] $libColW[$libColI])) }
$script:LibColW = @($lvLib.Columns | ForEach-Object { $_.Width })      # largeurs de depart, rendues par Set-LibSort
$lvLib.Columns[6].TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$lvLib.Add_SelectedIndexChanged({
    if ($lvLib.SelectedItems.Count -gt 0) { Show-LibDetails $lvLib.SelectedItems[0].Tag }
    elseif (-not $script:LibRendering) { Clear-LibDetails }
})
$lvLib.Add_ColumnClick({ Set-LibSort $_.Column })

# 12.8 (lot 4a, A3 § 4.1) : panneau de details : titre, vignette, informations, documents associes et entrees d archive
$lblLibTitle = New-Object System.Windows.Forms.Label
$lblLibTitle.Location = '466,98'; $lblLibTitle.Size = '312,18'; $lblLibTitle.Anchor = 'Top,Right'
$lblLibTitle.Font = $bold; $lblLibTitle.AutoEllipsis = $true; $lblLibTitle.ForeColor = $script:Theme.Accent2

# FIX4B (revue du lot 4) : position et taille de la vignette, du texte et de la liste du bas calculees d apres la hauteur
# de la page (Update-LibPanelLayout) ; vignette de 72 px reduite au besoin
$picLibThumb = New-Object System.Windows.Forms.PictureBox
$picLibThumb.Location = '466,121'; $picLibThumb.Size = '72,72'; $picLibThumb.Anchor = 'Top,Right'; $picLibThumb.Visible = $false
$picLibThumb.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom

$txtLibInfo = New-Object System.Windows.Forms.TextBox
$txtLibInfo.Location = '466,121'; $txtLibInfo.Size = '312,97'
$txtLibInfo.Anchor = 'Top,Bottom,Right'
$txtLibInfo.Multiline = $true; $txtLibInfo.ReadOnly = $true; $txtLibInfo.Font = New-Object System.Drawing.Font('Segoe UI', 9); $txtLibInfo.ForeColor = [System.Drawing.Color]::FromArgb(40,44,52)
$txtLibInfo.ScrollBars = 'Vertical'
$txtLibInfo.BackColor = [System.Drawing.SystemColors]::Control

$lstLibDocs = New-Object System.Windows.Forms.ListBox
$lstLibDocs.Location = '466,222'; $lstLibDocs.Size = '312,36'; $lstLibDocs.Anchor = 'Bottom,Right'
$lstLibDocs.IntegralHeight = $false; $lstLibDocs.HorizontalScrollbar = $true
$lstLibDocs.Font = New-Object System.Drawing.Font('Segoe UI', 9)      # FIX4B : comme le texte ; deux lignes entieres en 36 px
$tip.SetToolTip($lstLibDocs, (T "Documents associés au jeu (même titre, dossier du jeu, ou media\<titre>\) et entrées d'une archive ZIP.`nDouble-clic : ouvre le document. Entrée image d'une archive : choisie pour l'écriture."))
$lstLibDocs.Add_SelectedIndexChanged({ Show-LibSubSelection })
$lstLibDocs.Add_DoubleClick({ if (Get-LibOpenTarget) { Open-LibDoc } })

$btnLibFast = New-Object System.Windows.Forms.Button
$btnLibFast.Text = (T 'Écriture rapide'); $btnLibFast.Location = '466,262'; $btnLibFast.Size = '154,34'; $btnLibFast.Font = $bold
$btnLibFast.Anchor = 'Bottom,Right'; $btnLibFast.Enabled = $false
$tip.SetToolTip($btnLibFast, (T "Écrit l'image sélectionnée en une passe, les deux têtes ensemble : image entière, profil de précompensation Auto,`npré-effacement, effacement des pistes vides, vérification gw, 10 essais, sans contrôle complet des pistes.`nSans calibration commune pour la famille de l'image, le lecteur est d'abord calibré : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibFast, $tip.GetToolTip($btnLibFast) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$btnLibFast.Add_Click({ Start-LibWrite 'fast' })
$btnLibSlow = New-Object System.Windows.Forms.Button
$btnLibSlow.Text = (T 'Écriture lente'); $btnLibSlow.Location = '624,262'; $btnLibSlow.Size = '154,34'; $btnLibSlow.Font = $bold
$btnLibSlow.Anchor = 'Bottom,Right'; $btnLibSlow.Enabled = $false
$tip.SetToolTip($btnLibSlow, (T "Écrit la tête 0 puis la tête 1, chacune avec sa précompensation, puis contrôle toutes les pistes`net réécrit les pistes faibles, 3 passes au plus. Mêmes paramètres que l'écriture rapide.`nSans calibration par tête pour la famille de l'image, chaque tête est d'abord calibrée : la disquette reçoit le motif de test, puis l'image."))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T 'Test rapide choisi dans l''onglet Écriture : avant l''écriture, le niveau de la courbe est mesuré sur la disquette à écrire (4 à 9 cylindres par tête, 1 à 3 écritures du motif par piste).'))
$tip.SetToolTip($btnLibSlow, $tip.GetToolTip($btnLibSlow) + "`n" + (T "Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."))
$btnLibSlow.Add_Click({ Start-LibWrite 'slow' })

$btnLibOpen = New-Object System.Windows.Forms.Button
$btnLibOpen.Text = (T 'Ouvrir'); $btnLibOpen.Location = '466,300'; $btnLibOpen.Size = '154,34'
$btnLibOpen.Anchor = 'Bottom,Right'; $btnLibOpen.Enabled = $false
$tip.SetToolTip($btnLibOpen, (T 'Ouvre le document sélectionné (liste ou documents associés) avec l''application par défaut.'))
$btnLibOpen.Add_Click({ Open-LibDoc })

$btnLibExplore = New-Object System.Windows.Forms.Button
$btnLibExplore.Text = (T 'Ouvrir le dossier'); $btnLibExplore.Location = '624,300'; $btnLibExplore.Size = '154,34'
$btnLibExplore.Anchor = 'Bottom,Right'
$btnLibExplore.Add_Click({
    # 12.8 (lot 4a) : element du panneau de details (liste des resultats ou arborescence) ; entree d archive : l archive
    $c = $script:LibCur
    if (-not $c) { return }
    $p = if ($c.Kind -eq 'zipentry') { $c.ZipPath } else { $c.Path }
    if ($p -and (Test-Path -LiteralPath $p)) {
        if ((Get-Item -LiteralPath $p).PSIsContainer) { Start-Process explorer.exe "`"$p`"" }
        else { Start-Process explorer.exe "/select,`"$p`"" }
    }
})

$tabL.Controls.AddRange(@((New-Label (T 'Racine :') '10,14'), $txtLibRoot, $btnLibRoot, $btnLibRefresh, $btnLibDat, $lblLibDat, $btnLibDatClear,
    (New-Label (T 'Recherche :') '10,44'), $txtLibFilter, $btnLibFilter, $chkLibInDirs, $chkLibImgOnly, $btnLibReindex, $flpLib,
    $treeLib, $lvLib, $lblLibCount, $lblLibTitle, $picLibThumb, $txtLibInfo, $lstLibDocs, $btnLibFast, $btnLibSlow, $btnLibOpen, $btnLibExplore))
# FIX4B : colonne de droite recalculee a chaque changement de taille de la page (apres l ancrage des boutons)
$tabL.Add_Resize({ Update-LibPanelLayout })
# 12.8 (lot 4b) : liste de reference enregistree, lue a la premiere ouverture de l onglet (etat affiche a cote du bouton)
$tabs.Add_SelectedIndexChanged({ if ($tabs.SelectedTab -eq $tabL) { [void](Get-LibDat) } })

