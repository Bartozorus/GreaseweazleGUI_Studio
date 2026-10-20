# ============================== ECRITURE =======================================
$tabW = New-TabPage (T 'Écriture')
$bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
$script:BtnFont     = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:BtnFontBold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)

# --- Groupe 1 : image et profil
$grpWImage = New-Group (T 'Image à écrire') '10,6' '762,86'

$txtWFile = New-Object System.Windows.Forms.TextBox
$txtWFile.Location = '80,20'; $txtWFile.Width = 630; $txtWFile.Anchor = 'Top,Left,Right'
$btnWFile = New-Object System.Windows.Forms.Button
$btnWFile.Text = '...'; $btnWFile.Location = '715,19'; $btnWFile.Width = 36; $btnWFile.Anchor = 'Top,Right'
$tip.SetToolTip($btnWFile, (T 'Choisir une image (IPF, ADF, SCP, HFE...). Le format et le profil de précompensation sont déduits automatiquement.'))

$cmbWFmt = New-Object System.Windows.Forms.ComboBox
$cmbWFmt.Location = '80,52'; $cmbWFmt.Width = 200
[void]$cmbWFmt.Items.AddRange($Formats)
$tip.SetToolTip($cmbWFmt, (T "(auto) = aucun --format transmis : obligatoire pour IPF, SCP, HFE.`nUn ADF a besoin de amiga.amigados (rempli automatiquement). Saisie libre possible."))

$cmbWProfile = New-Object System.Windows.Forms.ComboBox
$cmbWProfile.Location = '440,52'; $cmbWProfile.Width = 170; $cmbWProfile.DropDownStyle = 'DropDownList'
[void]$cmbWProfile.Items.AddRange(@((T 'Auto (selon image)'),(T 'Standard 2 us'),(T 'Long track 1,89 us'),(T 'Manuel')))
$tip.SetToolTip($cmbWProfile, (T "Auto : la cellule de l'image est mesurée (IPF et HFE : bits par piste ; SCP : flux)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."))
$cmbWProfile.Add_SelectedIndexChanged({ Update-PrecompForImage $txtWFile.Text })

$btnWCurve = New-Object System.Windows.Forms.Button
$btnWCurve.Text = (T 'Courbe'); $btnWCurve.Location = '620,50'; $btnWCurve.Size = '130,26'; $btnWCurve.Enabled = $false
$tip.SetToolTip($btnWCurve, (T 'Affiche la courbe de précompensation calibrée pour la famille de l''image (standard ou long track) : mesures, courbe ajustée et valeur retenue pour chaque cylindre.') + "`n" + (T 'Écriture lente cochée : une courbe par tête, si la calibration a été faite en écriture lente.'))
$btnWCurve.Add_Click({ Show-PrecompCurve $script:CurveFamily $chkWSlow.Checked })

$btnWFile.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtWFile.Text) { $p = Split-Path -Parent $txtWFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') {
        $txtWFile.Text = $d.FileName; $script:PresetSource = $d.FileName
        if ($d.FileName -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $d.FileName) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) } else { $cmbWFmt.SelectedIndex = 0 }
        Update-PrecompForImage $d.FileName
    }
})
$txtWFile.Add_Enter({ $script:WFileOnEnter = $txtWFile.Text })
$txtWFile.Add_Leave({ if ($txtWFile.Text -ne $script:WFileOnEnter) { Update-PrecompForImage $txtWFile.Text } })   # profil d une calibration rapide garde sans changement d image

$grpWImage.Controls.AddRange(@((New-Label (T 'Image :') '12,23'), $txtWFile, $btnWFile,
    (New-Label (T 'Format :') '12,55'), $cmbWFmt, (New-Label (T 'Profil précomp. :') '320,55'), $cmbWProfile, $btnWCurve))

# --- Groupe 2 : options d'ecriture courantes
$grpWOpt = New-Group (T 'Options d''écriture') '10,98' '762,162'

$chkWPreErase = New-Object System.Windows.Forms.CheckBox
$chkWPreErase.Text = (T 'Pré-effacer chaque piste'); $chkWPreErase.Location = '12,24'; $chkWPreErase.Width = 170
$tip.SetToolTip($chkWPreErase, (T '--pre-erase : efface la piste juste avant de l''écrire. Recommandé sur une disquette déjà utilisée.'))
$chkWEraseEmpty = New-Object System.Windows.Forms.CheckBox
$chkWEraseEmpty.Text = (T 'Effacer les pistes vides'); $chkWEraseEmpty.Location = '190,24'; $chkWEraseEmpty.Width = 165
$tip.SetToolTip($chkWEraseEmpty, (T '--erase-empty : efface les pistes vides de l''image au lieu de les sauter. Supprime les résidus de l''ancien contenu.'))
$chkWNoVerify = New-Object System.Windows.Forms.CheckBox
$chkWNoVerify.Text = (T 'Sans vérification'); $chkWNoVerify.Location = '365,24'; $chkWNoVerify.Width = 130
$tip.SetToolTip($chkWNoVerify, (T '--no-verify : DÉCONSEILLÉ. Supprime la relecture de contrôle de chaque piste.'))
$chkWSlow = New-Object System.Windows.Forms.CheckBox
$chkWSlow.Text = (T 'Écriture lente'); $chkWSlow.Location = '625,24'; $chkWSlow.Width = 125
$tip.SetToolTip($chkWSlow, (T "Écriture lente : toutes les pistes de la tête 0, puis toutes celles de la tête 1 (une commande gw write par tête),`nchacune avec sa propre précompensation. Deux balayages complets du disque : plus long.`nCochée, la calibration mesure et vérifie une courbe de précompensation par tête."))
$tip.SetToolTip($chkWSlow, $tip.GetToolTip($chkWSlow) + "`n" + (T "Écriture lente : le lecteur est d'abord préchauffé par des lectures sans écriture (case « Préchauffer le lecteur avant l'écriture lente » de l'onglet Écriture ; bouton « Passer le préchauffage » pendant l'attente)."))
# Prechauffage du lecteur avant une ecriture lente (Start-WriteWarmup) : reglage warmSlowWrite (write.slowWarmup), case
# placee sous le bouton ECRIRE ; inactive sans ecriture lente ou quand la duree vaut 0 (Update-SlowUi)
$chkWWarm = New-Object System.Windows.Forms.CheckBox
$chkWWarm.Location = '12,394'; $chkWWarm.AutoSize = $true; $chkWWarm.Checked = $true; $chkWWarm.Enabled = $false
$chkWWarm.Text = (T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f '5 min'
$tip.SetToolTip($chkWWarm, (T "Écriture lente (onglet Écriture, Bibliothèque, restauration) : avant d'écrire, le lecteur est préchauffé par des lectures sans écriture (un cylindre sur 10 des pistes écrites, têtes écrites), comme avant une calibration complète, pour écrire dans l'état du lecteur où la précompensation a été calibrée.`nDurée : champ « Durée du préchauffage » (5 min par défaut, 0 : aucun) ; réduite ou sautée si le lecteur vient de servir, calibration qui précède comprise. Une calibration rapide avant l'écriture lente est précédée de ce préchauffage : le niveau est mesuré dans le même état du lecteur.`nUne disquette protégée en écriture n'est signalée qu'à la première écriture, après le préchauffage.`nDécochée : écriture tout de suite. Pendant le préchauffage, le bouton « Passer le préchauffage » lance l'écriture après la lecture en cours."))
# 12.8 (D6) : prechauffage avant une calibration complete, reglage warmFullCalib (write.calibWarmup), le meme que la case
# de la carte « Calibrer le lecteur » ; inactive quand la duree vaut 0 (Update-SlowUi)
$chkWCalWarm = New-Object System.Windows.Forms.CheckBox
$chkWCalWarm.Name = 'chkWCalWarm'; $chkWCalWarm.Location = '12,418'; $chkWCalWarm.AutoSize = $true; $chkWCalWarm.Checked = $true
$chkWCalWarm.Text = (T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f '5 min'
$tip.SetToolTip($chkWCalWarm, (T "Avant une calibration complète (bouton « Calibrer », carte « Calibrer le lecteur » de l'Accueil, calibration automatique avant une écriture) : lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite.`nMême réglage dans l'onglet Écriture et dans la fenêtre de la carte « Calibrer le lecteur ». Durée : champ « Durée du préchauffage » de l'onglet Écriture.`nLa calibration rapide (test rapide) n'a pas de préchauffage propre : avant une écriture lente, elle suit la case « Préchauffer le lecteur avant l'écriture lente »."))
# 12.8 (D6) : duree commune des prechauffages, reglage warmMinutes (write.calWarmupMinutes, 0 a 30 min, decimales
# admises), jusqu ici dans la configuration seulement ; la position du champ suit la largeur du libelle (apres l ajout a
# l onglet, police de la fenetre)
$lblWWarmMin = New-Label (T 'Durée du préchauffage :') '29,446'
$numWWarmMin = New-Object System.Windows.Forms.NumericUpDown
$numWWarmMin.Name = 'numWWarmMin'; $numWWarmMin.Minimum = 0; $numWWarmMin.Maximum = 30; $numWWarmMin.DecimalPlaces = 1; $numWWarmMin.Increment = 0.5
$numWWarmMin.Width = 60; $numWWarmMin.Location = '190,443'; $numWWarmMin.Value = 5
$lblWWarmMinU = New-Label (T 'min au plus (0 : aucun préchauffage)') '256,446'
$tip.SetToolTip($numWWarmMin, (T "Durée maximale du préchauffage du lecteur avant une écriture lente ou une calibration complète, en minutes : 5 par défaut, de 0 à 30, 0 : aucun préchauffage. Le préchauffage est réduit, ou sauté, si le lecteur vient de servir.`nEnregistrée dans la configuration (calWarmupMinutes)."))
# 12.7 point 5 : mesure de la disquette a ecrire avant une ecriture lente (Start-WriteTabWrite, Start-PresetWrite,
# restauration) : reglage levelBeforeWrite (write.levelBeforeWrite), case sous les prechauffages, active en ecriture lente.
# 12.8 (D5) : liste au « Test rapide » : la disquette est toujours mesuree, la case est cochee et verrouillee (Update-SlowUi)
$chkWLevel = New-Object System.Windows.Forms.CheckBox
$chkWLevel.Name = 'chkWLevel'; $chkWLevel.Location = '12,470'; $chkWLevel.AutoSize = $true; $chkWLevel.Checked = $true; $chkWLevel.Enabled = $false
$chkWLevel.Text = (T "Mesurer la disquette avant l'écriture lente : niveau de précompensation et état de la surface (environ 1 min)")
$tip.SetToolTip($chkWLevel, (T "Avant d'écrire l'image, l'application reprend la forme de la dernière calibration complète en test fin du lecteur.`nElle mesure, sur la disquette insérée, son niveau de précompensation propre et l'état de sa surface : le motif de test y est écrit au plus 3 fois, sur 4 à 9 cylindres par tête, puis l'image les recouvre.`nSans calibration de référence utilisable, l'écriture se fait avec la courbe du lecteur, ou avec le profil d'origine s'il n'en a pas, et le journal en donne la raison.`nNon disponible en haute densité.") + "`n" + (T "Liste « Calibration précomp » au « Test rapide » : la disquette est mesurée avant l'écriture, rapide ou lente, quel que soit le point de départ (bouton ÉCRIRE, Bibliothèque, restauration) ; la case est alors cochée et verrouillée.`nMêmes exceptions partout, avec leur raison dans le journal : pas de mesure quand l'image ne recouvrirait pas tout le motif de test (image à une seule face, champ Pistes avec c=, h= ou step=), ni avec un profil autre qu'Auto ou la case --precomp décochée."))

$numWRetries = New-Object System.Windows.Forms.NumericUpDown
$numWRetries.Location = '560,22'; $numWRetries.Width = 50
$numWRetries.Minimum = 0; $numWRetries.Maximum = 50
$tip.SetToolTip($numWRetries, (T '--retries : nombre de réécritures d''une piste dont la vérification échoue.'))

$chkWPrecomp = New-Object System.Windows.Forms.CheckBox
$chkWPrecomp.Text = (T 'Précompensation (--precomp) :'); $chkWPrecomp.Location = '12,50'; $chkWPrecomp.Width = 210
$txtWPrecomp = New-Object System.Windows.Forms.TextBox
$txtWPrecomp.Location = '225,48'; $txtWPrecomp.Width = 260
$tip.SetToolTip($txtWPrecomp, (T "--precomp : cylindre=nanosecondes, paliers séparés par ':'.`nRempli automatiquement selon le profil ; modifiable en mode Manuel."))
$tip.SetToolTip($chkWPrecomp, (T 'Transmet --precomp à gw. Coché automatiquement quand un profil est appliqué.'))
$lblWPrecomp1 = New-Label (T 'Précomp. tête 1 (--precomp) :') '29,81'
$txtWPrecomp1 = New-Object System.Windows.Forms.TextBox
$txtWPrecomp1.Location = '225,78'; $txtWPrecomp1.Width = 260
$tip.SetToolTip($txtWPrecomp1, (T "Écriture lente : --precomp de la tête 1 (la tête 0 utilise le champ du dessus).`nRempli par le profil calibré pour la tête 1 ; modifiable en mode Manuel. Vide : tête 1 écrite sans --precomp."))
$chkWSlow.Add_CheckedChanged({ Update-SlowUi; if ($script:UiReady) { Update-PrecompForImage $txtWFile.Text } })

$chkWPostCheck = New-Object System.Windows.Forms.CheckBox
$chkWPostCheck.Text = (T 'Contrôler toutes les pistes'); $chkWPostCheck.Location = '500,50'; $chkWPostCheck.Width = 255
$tip.SetToolTip($chkWPostCheck, (T "Après une écriture réussie, relit en flux toutes les pistes écrites et classe chacune avec les critères de l'onglet Qualité & alignement.`nUne piste À SURVEILLER, CRITIQUE ou illisible est réécrite seule (avec pré-effacement), puis seule remesurée,`njusqu'au nombre de passes de réécriture choisi. Résultat dans l'onglet Qualité & alignement."))

$lblWRepair = New-Label (T 'Passes de réécriture :') '560,81'
$numWRepair = New-Object System.Windows.Forms.NumericUpDown
$numWRepair.Location = '695,78'; $numWRepair.Width = 50
$numWRepair.Minimum = 0; $numWRepair.Maximum = 10; $numWRepair.Value = 3
$tip.SetToolTip($numWRepair, (T 'Nombre maximal de passes de réécriture des pistes faibles détectées par le contrôle. 0 = contrôle seul, sans réécriture.'))
$chkWPostCheck.Add_CheckedChanged({ $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked })

# --- Ligne 3 : calibration automatique de la precompensation pour le lecteur d ecriture
$cmbWCalMode = New-Object System.Windows.Forms.ComboBox
$cmbWCalMode.Location = '165,105'; $cmbWCalMode.Width = 250; $cmbWCalMode.DropDownStyle = 'DropDownList'
[void]$cmbWCalMode.Items.AddRange(@((T 'Test standard : 1 cylindre sur 10'), (T 'Test fin : tous les cylindres'), (T 'Test rapide : niveau et forme par disquette')))
$cmbWCalMode.SelectedIndex = 0
# 12.8 (D5) : case « Mesurer la disquette » cochee et verrouillee au « Test rapide » (Update-SlowUi), a chaque changement
# de la liste
$cmbWCalMode.Add_SelectedIndexChanged({ Update-SlowUi })
$tip.SetToolTip($cmbWCalMode, (T "Test standard (un cylindre sur 10) ou test fin (tous les cylindres) : calibration complète, qui mesure la courbe de précompensation du lecteur ; elle est faite une fois, puis réutilisée.`nTest rapide : la forme de la courbe vient de la dernière calibration complète du lecteur (la référence). Avant chaque écriture (bouton ÉCRIRE, Bibliothèque, restauration), et avec « Calibrer », son niveau est mesuré sur la disquette insérée, et sa forme aussi si elle diffère de la référence : 4 à 9 cylindres par tête (2 de plus si la forme est adaptée), 1 à 3 écritures du motif par piste. Sans référence utilisable, l'écriture est refusée (bouton ÉCRIRE, Bibliothèque) : calibrez d'abord le lecteur sur une disquette sacrifiée, par la carte « Calibrer le lecteur » de l'Accueil ; « Calibrer » propose alors une calibration complète en test fin, qui devient la référence.`nMême réglage que le test choisi dans la fenêtre de la carte « Calibrer le lecteur » de l'Accueil, retenu quand la calibration y est lancée."))
$btnWCalib = New-Object System.Windows.Forms.Button
$btnWCalib.Text = (T 'Calibrer'); $btnWCalib.Location = '425,104'; $btnWCalib.Size = '120,26'
$tip.SetToolTip($btnWCalib, (T "Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit sur les cylindres de test un motif de test pseudo-aléatoire, à la densité de l'image, avec une valeur de precomp puis, en vérification, le profil obtenu ; elle le relit en flux et mesure le décalage de pic. Une courbe donne ensuite une valeur par cylindre ; le profil est enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. Le contenu de l'image n'est pas écrit. La disquette insérée est écrasée. Test standard : un cylindre sur 10, quelques minutes. Test fin : tous les cylindres, un quart d'heure environ."))
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Écriture lente cochée : une courbe par tête, vérifiée en écrivant la tête 0 puis la tête 1, chacune avec son profil.'))
$btnWCalib.Add_Click({ $script:AfterCalib = ''; if ($cmbWCalMode.SelectedIndex -eq 2) { Start-LevelCalibButton } else { Start-PrecompCalib } })
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Test rapide : mesure le niveau de la disquette insérée, et sa forme si elle diffère de la dernière calibration complète du lecteur ; le profil obtenu est placé dans les champs --precomp, pour cette disquette.'))
$btnWCalReset = New-Object System.Windows.Forms.Button
$btnWCalReset.Text = (T 'Effacer les calibrations'); $btnWCalReset.Location = '555,104'; $btnWCalReset.Size = '195,26'
$tip.SetToolTip($btnWCalReset, (T "Efface toutes les calibrations de précompensation : courbes communes et par tête des familles standard et long track.`nLes profils de famille reprennent leurs valeurs d'origine. Une écriture rapide ou lente recalibre ensuite automatiquement."))
$btnWCalReset.Add_Click({ Reset-CalibProfiles })

# --- Ligne 4 : progression globale de la calibration (toutes passes), visible pendant et apres
$pbWCal = New-Object System.Windows.Forms.ProgressBar
$pbWCal.Location = '12,136'; $pbWCal.Size = '300,16'; $pbWCal.Minimum = 0; $pbWCal.Maximum = 100; $pbWCal.Visible = $false
$lblWCal = New-Object System.Windows.Forms.Label
$lblWCal.Location = '320,137'; $lblWCal.AutoSize = $true; $lblWCal.ForeColor = 'DimGray'; $lblWCal.Visible = $false
# 12.8 (lot 3b) : verdict du controle apres ecriture avec son icone d etat de 16 px et son encre (Set-WCalVerdict) ; tout
# autre texte (calibration, prechauffage...) les retire
$lblWCal.Add_Paint({ param($s, $e) Draw-WCalIcon $s $e })
$lblWCal.Add_TextChanged({ if ($script:WCalIcon -and $lblWCal.Text -ne $script:WCalIcon.Text) { Clear-WCalVerdict } })

$grpWOpt.Controls.AddRange(@($chkWPreErase, $chkWEraseEmpty, $chkWNoVerify, (New-Label (T 'Essais :') '500,26'), $numWRetries, $chkWSlow, $chkWPrecomp, $txtWPrecomp, $chkWPostCheck,
    $lblWPrecomp1, $txtWPrecomp1, (New-Label (T 'Calibration précomp :') '12,109'), $cmbWCalMode, $btnWCalib, $btnWCalReset, $pbWCal, $lblWCal, $lblWRepair, $numWRepair))

# --- Groupe 3 : options avancees (rarement utiles)
$grpWAdv = New-Group (T 'Options avancées') '10,266' '762,74'

$txtWTracks = New-Object System.Windows.Forms.TextBox
$txtWTracks.Location = '70,20'; $txtWTracks.Width = 150
$tip.SetToolTip($txtWTracks, (T "--tracks : sous-ensemble de pistes, ex : c=0-79:h=0-1`nc=0:h=0 pour réécrire uniquement la piste 0 face 0."))
$cmbWDensel = New-Object System.Windows.Forms.ComboBox
$cmbWDensel.Location = '290,20'; $cmbWDensel.Width = 60; $cmbWDensel.DropDownStyle = 'DropDownList'
[void]$cmbWDensel.Items.AddRange(@('(non)','H','L'))
$tip.SetToolTip($cmbWDensel, (T '--densel : force le signal density select (pin 2) sur les lecteurs qui l''exploitent.'))
$txtWFakeIdx = New-Object System.Windows.Forms.TextBox
$txtWFakeIdx.Location = '445,20'; $txtWFakeIdx.Width = 80
$tip.SetToolTip($txtWFakeIdx, (T '--fake-index : simule des impulsions d''index, ex : 300rpm ou 200ms (lecteurs sans capteur d''index).'))
$txtWDiskdefs = New-Object System.Windows.Forms.TextBox
$txtWDiskdefs.Location = '605,20'; $txtWDiskdefs.Width = 110
$btnWDiskdefs = New-Object System.Windows.Forms.Button
$btnWDiskdefs.Text = '...'; $btnWDiskdefs.Location = '718,19'; $btnWDiskdefs.Width = 32
$btnWDiskdefs.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'diskdefs|*.cfg|Tous|*.*'); $d.InitialDirectory = $script:AppDir
    if ($d.ShowDialog() -eq 'OK') { $txtWDiskdefs.Text = $d.FileName }
})
$chkWReverse = New-Object System.Windows.Forms.CheckBox
$chkWReverse.Text = (T 'Flippy (--reverse)'); $chkWReverse.Location = '12,46'; $chkWReverse.Width = 150
$chkWHard = New-Object System.Windows.Forms.CheckBox
$chkWHard.Text = (T 'Secteurs durs (--hard-sectors)'); $chkWHard.Location = '170,46'; $chkWHard.Width = 210
$chkWTG43 = New-Object System.Windows.Forms.CheckBox
$chkWTG43.Text = (T 'TG43 lecteur 8 pouces (--gen-tg43)'); $chkWTG43.Location = '390,46'; $chkWTG43.Width = 250

$grpWAdv.Controls.AddRange(@((New-Label (T 'Pistes :') '12,23'), $txtWTracks, (New-Label (T 'Densel :') '232,23'), $cmbWDensel,
    (New-Label (T 'Fake index :') '365,23'), $txtWFakeIdx, (New-Label (T 'Diskdefs :') '540,23'), $txtWDiskdefs, $btnWDiskdefs,
    $chkWReverse, $chkWHard, $chkWTG43))

# --- Action
$btnWrite = New-Object System.Windows.Forms.Button
$btnWrite.Text = (T 'ÉCRIRE LA DISQUETTE'); $btnWrite.Location = '10,348'; $btnWrite.Size = '250,40'; $btnWrite.Font = $bold

$btnWrite.Add_Click({ Start-WriteTabWrite })

$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Location = '270,348'; $lblWProfileInfo.Size = '502,40'; $lblWProfileInfo.Anchor = 'Top,Left,Right'
$lblWProfileInfo.ForeColor = 'DimGray'; $lblWProfileInfo.Text = (T 'Choisissez une image : le format et la précompensation seront déduits automatiquement.')

$tabW.Controls.AddRange(@($grpWImage, $grpWOpt, $grpWAdv, $btnWrite, $lblWProfileInfo, $chkWWarm, $chkWCalWarm, $lblWWarmMin, $numWWarmMin, $lblWWarmMinU, $chkWLevel))
$tabW.AutoScroll = $true                                  # fenetre basse ou journal agrandi : defilement plutot que bouton masque
# Champ de la duree du prechauffage et son unite : a la suite du libelle, mesure dans la police de la fenetre (anglais compris)
$numWWarmMin.Left = $lblWWarmMin.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWWarmMin.Text, $form.Font).Width + 8
$lblWWarmMinU.Left = $numWWarmMin.Right + 6

# --- Reglages a source unique (12.8, point 7) : liaisons des controles de l onglet (Register-SettingCtl), apres leurs
# gestionnaires propres (Update-SlowUi, Update-PrecompForImage), qui s executent avant la liaison. Valeurs posees au
# demarrage par Set-Defaults puis Load-Config
Register-SettingCtl 'slowWrite' $chkWSlow
Register-SettingCtl 'calMode' $cmbWCalMode
Register-SettingCtl 'precompProfile' $cmbWProfile
Register-SettingCtl 'warmSlowWrite' $chkWWarm
Register-SettingCtl 'warmFullCalib' $chkWCalWarm
Register-SettingCtl 'warmMinutes' $numWWarmMin
Register-SettingCtl 'levelBeforeWrite' $chkWLevel

