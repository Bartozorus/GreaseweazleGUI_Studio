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
# 12.10 (relecture de la RC) : format change apres l image (SCP ou KryoFlux ecrit avec --format : la fenetre « Image »
# remet (auto) pour tout fichier autre qu un ADF) : profil, champs et libelle recalcules (Update-PrecompForImage : refus
# du lecteur cible en tete, complement flux, FM, GCR, haute densite, bouton « Courbe »), comme au changement d image ou de
# profil ; avant, le libelle gardait ceux de l ancien format. Choix dans la liste (SelectedIndexChanged) ou saisie libre
# (Leave, texte compare a celui de l entree). Seulement quand le libelle est celui de l image du champ ($script:WProfilePath,
# image non vide) : un format pose par le code juste apres une nouvelle image (fenetre « Image », Set-WritePreset,
# Restore-WriteTabState, Set-Defaults) ne refait pas le calcul, ni la ligne « Profil precomp » du journal, avant le
# Update-PrecompForImage de ce code ; une image saisie est recalculee a la sortie du champ Image, avant la liste. 12.10
# (relecture de la RC) : format pose par le code qui recalcule ensuite le profil (bouton dossier, Set-WritePreset,
# Restore-WriteTabState, Start-RestoreWrite) : sous la garde des liaisons ($script:SettingSync), meme image comprise ;
# avant, la meme image reprise avec un autre format etait calculee deux fois (ligne « Profil precomp » en double)
$cmbWFmt.Add_Enter({ $script:WFmtOnEnter = $cmbWFmt.Text })
$cmbWFmt.Add_SelectedIndexChanged({ if ($script:UiReady -and -not $script:SettingSync -and $txtWFile.Text -and $txtWFile.Text -eq [string]$script:WProfilePath) { Update-PrecompForImage $txtWFile.Text; $script:WFmtOnEnter = $cmbWFmt.Text } })
$cmbWFmt.Add_Leave({ if ($script:UiReady -and -not $script:SettingSync -and $cmbWFmt.Text -ne $script:WFmtOnEnter -and $txtWFile.Text -and $txtWFile.Text -eq [string]$script:WProfilePath) { Update-PrecompForImage $txtWFile.Text } })

$cmbWProfile = New-Object System.Windows.Forms.ComboBox
$cmbWProfile.Location = '440,52'; $cmbWProfile.Width = 170; $cmbWProfile.DropDownStyle = 'DropDownList'
[void]$cmbWProfile.Items.AddRange(@((T 'Auto (selon image)'),(T 'Standard 2 us'),(T 'Long track 1,89 us'),(T 'Manuel')))
$tip.SetToolTip($cmbWProfile, (T "Auto : la cellule de l'image est mesurée (IPF et HFE : bits par piste ; SCP : flux)`net le profil --precomp correspondant est appliqué.`nManuel : le champ --precomp n'est jamais modifié."))
$cmbWProfile.Add_SelectedIndexChanged({ Update-PrecompForImage $txtWFile.Text })

$btnWCurve = New-Object System.Windows.Forms.Button
$btnWCurve.Text = (T 'Courbe'); $btnWCurve.Location = '620,46'; $btnWCurve.Size = '130,34'; $btnWCurve.Enabled = $false   # 12.8 (lot 5) : 34 px
# 12.10 (relecture de la RC) : courbe que l ecriture applique : famille du profil force, sinon de l image, haute densite comprise
# (Update-CurveButton, 230) ; avant : « famille de l image (standard ou long track) »
$tip.SetToolTip($btnWCurve, (T 'Affiche la courbe de précompensation calibrée que l''écriture applique, pour la famille du profil forcé, sinon de l''image (standard, long track ou haute densité) : mesures, courbe ajustée et valeur retenue pour chaque cylindre.') + "`n" + (T 'Écriture lente cochée : une courbe par tête, si la calibration a été faite en écriture lente.'))
# 12.10 (relecture de la RC) : courbes croisees ecrites pour un lecteur cible avec effet (Get-WCurveSet, Show-WCurve, 230)
$tip.SetToolTip($btnWCurve, $tip.GetToolTip($btnWCurve) + "`n" + (T "Lecteur cible choisi (liste « Lecteur cible »), avec effet sur l'écriture : la courbe croisée que l'écriture applique ; inactif quand cette écriture est refusée (le libellé du profil dit pourquoi)."))   # 12.10 (relecture de la RC, fix1) : inactif sur un refus (Get-WCurveSet, 230)
# 12.10 (relecture de la RC) : profil Manuel : courbe calibree du lecteur montree, champ --precomp transmis tel quel ; image
# FM, GCR, a codage propre ou haute densite non calibrable : courbe MFM de la famille de Get-WriteImageFamily (double
# densite, ou hd pour un HFE de cellule 900 a 1 100 ns ; Update-CurveButton, 230) ; Start-ImageWrite (140) n avertit que
# pour une image FM, GCR ou a codage propre dont le champ n a pas de type=
$tip.SetToolTip($btnWCurve, $tip.GetToolTip($btnWCurve) + "`n" + (T "Profil Manuel : la courbe calibrée du lecteur pour la famille de l'image ; le champ --precomp est transmis tel quel. Pour une image FM, GCR, à codage propre ou haute densité non calibrable, c'est une courbe MFM du lecteur, sans objet pour cette image."))
$btnWCurve.Add_Click({ Show-WCurve })

$btnWFile.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = (T 'Images disquette|*.ipf;*.adf;*.scp;*.hfe;*.img;*.st;*.dsk;*.raw;*.d64;*.imd|Tous|*.*')
    if ($txtWFile.Text) { $p = Split-Path -Parent $txtWFile.Text; if ($p -and (Test-Path -LiteralPath $p)) { $d.InitialDirectory = $p } }
    if ($d.ShowDialog() -eq 'OK') {
        $txtWFile.Text = $d.FileName; $script:PresetSource = $d.FileName
        $sv = $script:SettingSync; $script:SettingSync = $true      # 12.10 (relecture de la RC) : un seul calcul, ci-dessous
        try { if ($d.FileName -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $d.FileName) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) } else { $cmbWFmt.SelectedIndex = 0 } } finally { $script:SettingSync = $sv }
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
# 12.8.2 : « Effacer avant d ecrire » (meme case, meme cle write.preErase) : effacement haute frequence en double densite,
# pre-effacement en haute densite (Start-ImageWrite, 150 : Get-EraseMode)
$chkWPreErase.Text = (T "Effacer avant d'écrire"); $chkWPreErase.Location = '12,24'; $chkWPreErase.Width = 170
$tip.SetToolTip($chkWPreErase, (T "Efface les pistes avant de les écrire (cochée par défaut).`nDisquette double densité : les pistes de l'image sont d'abord effacées en haute fréquence par le lecteur qui écrit (gw erase --hfreq), puis écrites sans pré-effacement.`nDisquette haute densité : chaque piste est pré-effacée juste avant son écriture (--pre-erase), comme avant ; de même avec les secteurs durs, un lecteur 8 pouces (TG43), --densel ou une image dont l'application ne connaît pas les pistes (ligne au journal).`nMesuré sur un lecteur haute densité qui écrit des disquettes double densité : la marge de lecture sur un lecteur double densité est nettement meilleure qu'avec le pré-effacement (environ 60 ns de plus).`nLes calibrations et les réécritures du contrôle après écriture effacent toujours leurs pistes selon cette règle, même case décochée."))
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
$chkWWarm.Location = '12,390'; $chkWWarm.AutoSize = $true; $chkWWarm.Checked = $true; $chkWWarm.Enabled = $false
$chkWWarm.Text = (T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f '5 min'
$tip.SetToolTip($chkWWarm, (T "Écriture lente (onglet Écriture, Bibliothèque, restauration) : avant d'écrire, le lecteur est préchauffé par des lectures sans écriture (un cylindre sur 10 des pistes écrites, têtes écrites), comme avant une calibration complète, pour écrire dans l'état du lecteur où la précompensation a été calibrée.`nDurée : champ « Durée du préchauffage » (5 min par défaut, 0 : aucun) ; réduite ou sautée si le lecteur vient de servir, calibration qui précède comprise. Une calibration rapide avant l'écriture lente est précédée de ce préchauffage : le niveau est mesuré dans le même état du lecteur.`nUne disquette protégée en écriture n'est signalée qu'à la première écriture, après le préchauffage.`nDécochée : écriture tout de suite. Pendant le préchauffage, le bouton « Passer le préchauffage » lance l'écriture après la lecture en cours."))
# 12.8 (D6) : prechauffage avant une calibration complete, reglage warmFullCalib (write.calibWarmup), le meme que la case
# de la carte « Calibrer le lecteur » ; inactive quand la duree vaut 0 (Update-SlowUi)
$chkWCalWarm = New-Object System.Windows.Forms.CheckBox
$chkWCalWarm.Name = 'chkWCalWarm'; $chkWCalWarm.Location = '12,414'; $chkWCalWarm.AutoSize = $true; $chkWCalWarm.Checked = $true
$chkWCalWarm.Text = (T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f '5 min'
$tip.SetToolTip($chkWCalWarm, (T "Avant une calibration complète (bouton « Calibrer », carte « Calibrer le lecteur » de l'Accueil, calibration automatique avant une écriture) : lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite.`nMême réglage dans l'onglet Écriture et dans la fenêtre de la carte « Calibrer le lecteur ». Durée : champ « Durée du préchauffage » de l'onglet Écriture.`nLa calibration rapide (test rapide) n'a pas de préchauffage propre : avant une écriture lente, elle suit la case « Préchauffer le lecteur avant l'écriture lente »."))
# 12.8 (D6) : duree commune des prechauffages, reglage warmMinutes (write.calWarmupMinutes, 0 a 30 min, decimales
# admises), jusqu ici dans la configuration seulement ; la position du champ suit la largeur du libelle (apres l ajout a
# l onglet, police de la fenetre)
$lblWWarmMin = New-Label (T 'Durée du préchauffage :') '29,442'
$numWWarmMin = New-Object System.Windows.Forms.NumericUpDown
$numWWarmMin.Name = 'numWWarmMin'; $numWWarmMin.Minimum = 0; $numWWarmMin.Maximum = 30; $numWWarmMin.DecimalPlaces = 1; $numWWarmMin.Increment = 0.5
$numWWarmMin.Width = 60; $numWWarmMin.Location = '190,439'; $numWWarmMin.Value = 5
$lblWWarmMinU = New-Label (T 'min au plus (0 : aucun préchauffage)') '256,442'
$tip.SetToolTip($numWWarmMin, (T "Durée maximale du préchauffage du lecteur avant une écriture lente ou une calibration complète, en minutes : 5 par défaut, de 0 à 30, 0 : aucun préchauffage. Le préchauffage est réduit, ou sauté, si le lecteur vient de servir.`nEnregistrée dans la configuration (calWarmupMinutes)."))
# 12.9 (S1) : ecriture sans surveillance, case a la suite du champ de la duree du prechauffage (position apres l ajout a
# l onglet). Etat $script:CalibUnattended, pour la session : ni reglage ni configuration, decochee au demarrage et a la fin
# de la sequence d ecriture (Update-CalibUnattended). Seul effet : avertissement de calibration de la disquette a ecrire
# valide seul apres CalibConfirmSeconds (Get-CalibConfirmSeconds) et fenetre « Mesure de la disquette » sautee (276)
$chkWUnattended = New-Object System.Windows.Forms.CheckBox
$chkWUnattended.Name = 'chkWUnattended'; $chkWUnattended.Location = '480,441'; $chkWUnattended.AutoSize = $true; $chkWUnattended.Checked = $false
$chkWUnattended.Text = (T 'Écriture sans surveillance')     # texte court : meme ligne que la duree (pas de defilement, P10)
$tip.SetToolTip($chkWUnattended, ((T "Prochaine écriture (onglet Écriture, Bibliothèque, restauration) : l'avertissement de calibration de la disquette à écrire est validé seul après {0} s sans réponse, et la mesure sur l'image se fait sans afficher la fenêtre « Mesure de la disquette », avec la dernière marque choisie. La disquette insérée reçoit le motif de test, puis l'image.`nJamais pour une calibration seule (bouton « Calibrer », carte « Calibrer le lecteur » de l'Accueil) : son avertissement attend toujours votre réponse.`nLa case se décoche à la fin de l'écriture, à son annulation ou à une erreur ; elle n'est pas enregistrée.") -f '120'))   # 120 : CalibConfirmSeconds (560, defini apres l interface)
$chkWUnattended.Add_CheckedChanged({
    $script:CalibUnattended = [bool]$this.Checked
    # Revue de la phase B (mineur 3) : case cochee pendant une operation (Test-OpIdle faux), sauf une calibration seule
    # (AfterCalib vide : jamais de delai, la case vaut pour l ecriture suivante) : la sequence en cours devient sans
    # surveillance des maintenant, elle est donc suivie et la case se decoche a sa fin
    if (-not $this.Checked) { $script:UnattendedRun = $false }
    elseif (-not (Test-OpIdle) -and -not (($script:Cal -or $script:CalRedo) -and -not [string]$script:AfterCalib)) { Start-UnattendedWrite -Running }
})
# 12.7 point 5 : mesure de la disquette a ecrire avant une ecriture lente (Start-WriteTabWrite, Start-PresetWrite,
# restauration) : reglage levelBeforeWrite (write.levelBeforeWrite), case sous les prechauffages, active en ecriture lente.
# 12.8 (D5) : liste au « Test rapide » : la disquette est toujours mesuree, la case est cochee et verrouillee (Update-SlowUi)
$chkWLevel = New-Object System.Windows.Forms.CheckBox
$chkWLevel.Name = 'chkWLevel'; $chkWLevel.Location = '12,464'; $chkWLevel.AutoSize = $true; $chkWLevel.Checked = $true; $chkWLevel.Enabled = $false
$chkWLevel.Text = (T "Mesurer la disquette avant l'écriture lente : niveau de précompensation et état de la surface (environ 1 min)")
# 12.8.1 (spec-1281 § D.1) : infobulle des trois mesures de la liste « Mesure : », du facteur du lecteur et des exceptions
$tip.SetToolTip($chkWLevel, (T "Avant d'écrire l'image, l'application mesure la disquette insérée avec la mesure choisie dans la liste « Mesure : ».`nSur l'image à écrire : la marge de lecture est mesurée sur le contenu même de l'image, à trois niveaux de la courbe du lecteur, et l'image est écrite avec le meilleur, tête par tête. Au motif : le niveau de précompensation et l'état de la surface sont mesurés sur le motif de test.`nSans mesure sur l'image (case décochée, « Test rapide », restauration, image qui ne s'y prête pas), le facteur du lecteur s'applique : médiane des 3 derniers facteurs mesurés pour ce lecteur et cette tête, 1 tant qu'aucun n'est mesuré.`nPas de mesure en haute densité, pour une image flux, à une seule face, ou quand le champ Pistes limite l'écriture, ni avec un profil autre qu'Auto ou la case --precomp décochée.") + "`n" + (T "Liste « Calibration précomp » au « Test rapide » : la disquette est toujours mesurée au motif avant l'écriture, rapide ou lente (bouton ÉCRIRE, Bibliothèque, restauration) ; la case est alors cochée et verrouillée."))
# 12.8 (S3, decision du 21/10/2026) : mode de la mesure avant une ecriture lente, reglage levelBeforeWriteMode
# (write.levelBeforeWriteMode) : calibration rapide ou mesure complete de cette disquette ; liste active en ecriture lente
# quand la disquette est mesuree (Update-SlowUi). Position du champ : a la suite du libelle (police de la fenetre) ; bas
# de la liste (25 px de haut) a 517 px, hauteur de l onglet a la taille par defaut, journal replie : pas de defilement
# (P10 de write-level) ; case de la mesure remontee de 2 px pour cela (468 au lieu de 470). 12.10 (captures du wiki) :
# sans marge, un onglet de 516 px affichait la barre de defilement et coupait le bas des listes : bouton « ECRIRE LA
# DISQUETTE » et son texte remontes de 2 px, cases et listes du bas de 4 px (bas des listes a 513 px)
$lblWLevelMode = New-Label (T 'Mesure :') '29,491'
$lblWLevelMode.Name = 'lblWLevelMode'
$cmbWLevelMode = New-Object System.Windows.Forms.ComboBox
# 12.8.1 (spec-1281 § D.1) : trois elements, dans l ordre des codes (content, quick, complete) ; largeur 260
$cmbWLevelMode.Name = 'cmbWLevelMode'; $cmbWLevelMode.DropDownStyle = 'DropDownList'; $cmbWLevelMode.Width = 260; $cmbWLevelMode.Location = '100,488'
[void]$cmbWLevelMode.Items.AddRange(@((T "sur l'image à écrire (environ 12 min)"), (T 'rapide, au motif (1 à 2 min)'), (T 'complète, au motif (26 à 31 min)')))
$cmbWLevelMode.SelectedIndex = 0
# 12.10 (relecture de la RC) : mesure complete au « Test rapide » et en restauration (Get-LevelBeforeWriteKind, 260)
$tip.SetToolTip($cmbWLevelMode, (T "Mesure de la disquette avant une écriture lente.`nSur l'image à écrire : 40 cylindres de l'image sont écrits à 3 niveaux de la courbe du lecteur et relus ; l'image est écrite avec le niveau qui donne la meilleure marge de lecture, pour chaque tête (environ 12 min). Images double densité MFM seulement ; sinon, calibration rapide au motif.`nRapide, au motif : calibration rapide sur le motif de test, 4 à 9 cylindres par tête (1 à 2 min).`nComplète, au motif : mesure complète de cette disquette sur tous ses cylindres (26 à 31 min), puis écriture de l'image ; la courbe obtenue est mémorisée pour la marque de la disquette.`n« Test rapide » et restauration : calibration rapide au motif, ou, avec « complète, au motif », mesure complète de cette disquette avant une écriture lente (une restauration écrit toujours en écriture lente)."))
# 12.10 : liste « Lecteur cible » du lecteur du bandeau (la source), sur la ligne de la liste « Mesure : », a la place des
# champs de la correction « lecteur cible » Dk de la 12.8.1 (retires) : « (meme lecteur) », puis les lecteurs du bandeau
# sauf la source ; choix memorise par source ($script:TargetDrives, 560 ; write.targetDrive, 120). Elements, choix,
# infobulle et positions (a la suite de la liste) : Update-TargetDriveUi (140) ; choix change : Set-TargetDriveFromUi
# (journal, case de la mesure, profil de l image recalcule avec les courbes croisees), une fois la fenetre affichee
# (UiReady : avant, seul Update-TargetDriveUi change le choix, sous la garde des liaisons). Banc : Name cmbWTarget
$lblWTarget = New-Label (T 'Lecteur cible :') '374,491'
$lblWTarget.Name = 'lblWTarget'
$cmbWTarget = New-Object System.Windows.Forms.ComboBox
$cmbWTarget.Name = 'cmbWTarget'; $cmbWTarget.DropDownStyle = 'DropDownList'; $cmbWTarget.Width = 150; $cmbWTarget.Location = '470,488'
$cmbWTarget.Add_SelectedIndexChanged({ if ($script:UiReady) { Set-TargetDriveFromUi } })

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
# 12.10 (relecture de la RC) : refus du lecteur cible en tete du libelle du profil accorde a la case (decochee : l ecriture
# n est plus refusee, lecteur cible sans effet, Get-TargetWriteInfo), quand le libelle est celui du profil (Sync-WTargetHead,
# 220) ; inactif pendant Update-PrecompForImage, qui recoche la case et accorde le libelle en sortie. Complement « facteur »
# accorde de meme (Update-WriteFactorNote, 140 : case decochee, aucun facteur applique, Get-WriteFactorPlan ; il restait)
# 12.10 (relecture de la RC, fixB) : case de la mesure accordee de meme (Update-WLevelUi, 140 : lecteur cible avec ou sans
# effet sur l ecriture)
# 12.10 (relecture de la RC, fix1) : bouton « Courbe » accorde de meme (Update-CurveButton, Get-WCurveSet, 230 : case
# decochee, lecteur cible sans effet, courbes du lecteur ; recochee, courbe croisee ou refus) ; avant : bouton actif sans
# courbe a montrer, ou grise alors que l ecriture applique la courbe croisee
$chkWPrecomp.Add_CheckedChanged({ if ($script:UiReady -and -not $script:SettingSync -and -not $script:WProfileBuilding) { Sync-WTargetHead -IfOwn; Update-WriteFactorNote; Update-WLevelUi; Update-CurveButton $txtWFile.Text } })
$lblWPrecomp1 = New-Label (T 'Précomp. tête 1 (--precomp) :') '29,81'
$txtWPrecomp1 = New-Object System.Windows.Forms.TextBox
$txtWPrecomp1.Location = '225,78'; $txtWPrecomp1.Width = 260
$tip.SetToolTip($txtWPrecomp1, (T "Écriture lente : --precomp de la tête 1 (la tête 0 utilise le champ du dessus).`nRempli par le profil calibré pour la tête 1 ; modifiable en mode Manuel. Vide : tête 1 écrite sans --precomp."))
$chkWSlow.Add_CheckedChanged({ Update-SlowUi; if ($script:UiReady) { Update-PrecompForImage $txtWFile.Text } })

$chkWPostCheck = New-Object System.Windows.Forms.CheckBox
$chkWPostCheck.Text = (T 'Contrôler toutes les pistes'); $chkWPostCheck.Location = '500,50'; $chkWPostCheck.Width = 255
$tip.SetToolTip($chkWPostCheck, (T "Après une écriture réussie, relit en flux toutes les pistes écrites et classe chacune avec les critères de l'onglet Qualité & alignement.`nUne piste À SURVEILLER, CRITIQUE ou illisible est réécrite seule (après un effacement haute fréquence de la piste en double densité, avec pré-effacement en haute densité), puis seule remesurée,`njusqu'au nombre de passes de réécriture choisi. Résultat dans l'onglet Qualité & alignement."))

$lblWRepair = New-Label (T 'Passes de réécriture :') '560,81'
$numWRepair = New-Object System.Windows.Forms.NumericUpDown
$numWRepair.Location = '695,78'; $numWRepair.Width = 50
$numWRepair.Minimum = 0; $numWRepair.Maximum = 10; $numWRepair.Value = 3
$tip.SetToolTip($numWRepair, (T 'Nombre maximal de passes de réécriture des pistes faibles détectées par le contrôle. 0 = contrôle seul, sans réécriture.'))
$chkWPostCheck.Add_CheckedChanged({ $numWRepair.Enabled = $chkWPostCheck.Checked; $lblWRepair.Enabled = $chkWPostCheck.Checked })

# --- Ligne 3 : calibration automatique de la precompensation pour le lecteur d ecriture
$cmbWCalMode = New-Object System.Windows.Forms.ComboBox
# 12.10 : rangee resserree pour le bouton a icone de la calibration croisee (btnWCross, ci-dessous) : liste a 226 px (liste
# deroulee a 280 px, textes entiers), « Calibrer » a 106 px (icone et texte, francais et anglais) ; « Effacer les
# calibrations » (193 px de texte et d icone) et la ligne 4 ne bougent pas, bas de la liste « Mesure : » inchange (517 px au
# banc de la RC). 12.10 (relecture des captures) : bas des listes a 513 px depuis (voir lblWLevelMode)
# 12.11 (L7) : geometrie provisoire (jusqu a la refonte de l onglet, lot L9) pour le bouton a icone du retour a une
# calibration precedente (btnWCalBack, ci-dessous) : liste a 184 px (liste deroulee a 280 px inchangee), « Calibrer » en
# 357, calibration croisee en 471, retour en 513 ; « Effacer les calibrations » garde sa place (555)
$cmbWCalMode.Location = '165,111'; $cmbWCalMode.Width = 184; $cmbWCalMode.DropDownWidth = 280; $cmbWCalMode.DropDownStyle = 'DropDownList'
[void]$cmbWCalMode.Items.AddRange(@((T 'Test standard : 1 cylindre sur 10'), (T 'Test fin : tous les cylindres'), (T 'Test rapide : niveau et forme par disquette')))
$cmbWCalMode.SelectedIndex = 0
# 12.8 (D5) : case « Mesurer la disquette » cochee et verrouillee au « Test rapide » (Update-SlowUi), a chaque changement
# de la liste
$cmbWCalMode.Add_SelectedIndexChanged({ Update-SlowUi })
$tip.SetToolTip($cmbWCalMode, (T "Test standard (un cylindre sur 10) ou test fin (tous les cylindres) : calibration complète, qui mesure la courbe de précompensation du lecteur ; elle est faite une fois, puis réutilisée.`nTest rapide : la forme de la courbe vient de la dernière calibration complète du lecteur (la référence). Avant chaque écriture (bouton ÉCRIRE, Bibliothèque, restauration), et avec « Calibrer », son niveau est mesuré sur la disquette insérée, et sa forme aussi si elle diffère de la référence : 4 à 9 cylindres par tête (2 de plus si la forme est adaptée), 1 à 3 écritures du motif par piste. Sans référence utilisable, l'écriture est refusée (bouton ÉCRIRE, Bibliothèque) : calibrez d'abord le lecteur sur une disquette sacrifiée, par la carte « Calibrer le lecteur » de l'Accueil ; « Calibrer » propose alors une calibration complète en test fin, qui devient la référence.`nMême réglage que le test choisi dans la fenêtre de la carte « Calibrer le lecteur » de l'Accueil, retenu quand la calibration y est lancée."))
# 12.10 (relecture de la RC) : mesure complete d une ecriture lente au « Test rapide » (Get-LevelBeforeWriteKind, 260),
# lecteur cible avec effet : ni mesure ni calibration rapide (Start-WriteTabWrite, Start-LevelCalibButton)
$tip.SetToolTip($cmbWCalMode, $tip.GetToolTip($cmbWCalMode) + "`n" + (T "« Test rapide » avant une écriture lente, avec « complète, au motif » dans la liste « Mesure : » : mesure complète de cette disquette, sur tous ses cylindres (26 à 31 min), à la place de la calibration rapide. Lecteur cible choisi (liste « Lecteur cible »), avec effet sur l'écriture : ni mesure de la disquette ni calibration rapide, qui reliraient avec le lecteur du bandeau."))
$btnWCalib = New-Object System.Windows.Forms.Button
# 12.8 (lot 5) : boutons de 34 px (deux hauteurs, 34 et 40 px), sous les champs de la ligne 2 (bas a 103 px), liste et
# libelle de la ligne 3 descendus pour rester centres. FIX5 : rangee descendue de 3 px de plus (3 px d ecart avec les
# champs du dessus, comme en 12.7), ligne 4 (progression, verdict) de 5 px : 2 px sous les boutons
$btnWCalib.Text = (T 'Calibrer'); $btnWCalib.Location = '357,106'; $btnWCalib.Size = '106,34'
$tip.SetToolTip($btnWCalib, (T "Calibre la précompensation pour ce lecteur d'écriture : chaque passe écrit sur les cylindres de test un motif de test pseudo-aléatoire, à la densité de l'image, avec, aux passes de mesure, une valeur de precomp (une par cylindre en double densité) puis, en vérification, le profil obtenu ; elle le relit en flux et mesure le décalage de pic. Une courbe donne ensuite une valeur par cylindre ; le profil est enregistré pour la famille de l'image (standard ou long track) et appliqué ensuite par le mode Auto. Le contenu de l'image n'est pas écrit. La disquette insérée est écrasée. Durées en double densité, sans le préchauffage : test standard (un cylindre sur 10) environ 6 min, test fin (tous les cylindres) environ 26 min."))
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Écriture lente cochée : une courbe par tête, vérifiée en écrivant la tête 0 puis la tête 1, chacune avec son profil.'))
$btnWCalib.Add_Click({ $script:AfterCalib = ''; if ($cmbWCalMode.SelectedIndex -eq 2) { Start-LevelCalibButton } else { Start-PrecompCalib } })
$tip.SetToolTip($btnWCalib, $tip.GetToolTip($btnWCalib) + "`n" + (T 'Test rapide : mesure le niveau de la disquette insérée, et sa forme si elle diffère de la dernière calibration complète du lecteur ; le profil obtenu est placé dans les champs --precomp, pour cette disquette.'))
# 12.10 : calibration croisee pour un lecteur cible (Start-CrossCalib, 270 ; fenetre de choix Show-CrossCalibDialog, 250) :
# bouton a icone seule (glyphe Switch, 34 px : la rangee ne peut pas loger un texte de plus sans deplacer la ligne 4 ni les
# cases du bas), entre « Calibrer » et « Effacer les calibrations » ; son texte sert d infobulle courte (Set-Btn -IconOnly),
# remplacee par l explication complete ; style pose ici (540 ne le connait pas)
$btnWCross = New-Object System.Windows.Forms.Button
$btnWCross.Name = 'btnWCross'; $btnWCross.Text = (T 'Calibrer pour un lecteur cible…'); $btnWCross.Location = '471,106'; $btnWCross.Size = '34,34'
Set-Btn $btnWCross 'Switch' -IconOnly
$tip.SetToolTip($btnWCross, (T 'Calibrer pour un lecteur cible…') + "`n" + (T "Calibration croisée : ce lecteur écrit le motif de test sur une disquette sacrifiée, un autre lecteur (le lecteur cible) le relit ; à chaque demande de l'application, vous déplacez la disquette d'un lecteur à l'autre. La courbe obtenue (par exemple « A → 0 ») mesure le besoin du lecteur cible à la relecture des écritures de ce lecteur : elle est enregistrée pour les écritures de ce lecteur destinées au lecteur cible, sans modifier sa courbe propre. Famille (standard ou long track) et test (standard ou fin) au choix ; une courbe par tête selon la case « Écriture lente »."))
$btnWCross.Add_Click({ [void](Start-CrossCalib) })
# 12.11 (L7) : retour a une calibration precedente (Start-CalibBack, 240 ; fenetre Show-CalibBackDialog, 250) : bouton a
# icone seule (glyphe History), juste a gauche de « Effacer les calibrations » ; son texte sert d infobulle courte
# (Set-Btn -IconOnly), remplacee par l explication complete
$btnWCalBack = New-Object System.Windows.Forms.Button
$btnWCalBack.Name = 'btnWCalBack'; $btnWCalBack.Text = (T 'Revenir à une calibration précédente…'); $btnWCalBack.Location = '513,106'; $btnWCalBack.Size = '34,34'
Set-Btn $btnWCalBack 'History' -IconOnly
$tip.SetToolTip($btnWCalBack, (T 'Revenir à une calibration précédente…') + "`n" + ((T "Liste les calibrations complètes gardées dans les copies de la configuration (fichiers « {0}.….bak » du dossier de l'application, faites avant chaque remplacement ou effacement d'une calibration) et rétablit celle que vous choisissez. Seules ses courbes reviennent : les autres courbes, les réglages, la mémoire par marque et les facteurs mesurés ne changent pas. L'état actuel est d'abord sauvegardé.") -f [System.IO.Path]::GetFileName([string]$script:ConfigFile)))
$btnWCalBack.Add_Click({ [void](Start-CalibBack) })
$btnWCalReset = New-Object System.Windows.Forms.Button
$btnWCalReset.Text = (T 'Effacer les calibrations'); $btnWCalReset.Location = '555,106'; $btnWCalReset.Size = '195,34'
# 12.10 (relecture de la RC) : infobulle alignee sur Reset-CalibProfiles (240) : tous les lecteurs et toutes les courbes,
# calibration automatique seulement depuis la Bibliotheque au test standard ou fin, lecteur cible garde. 12.10 (relecture
# de la RC, fix1) : suite de l effacement tiree du message (Get-CalibResetAfterText, 240 : restauration comprise, refus du
# « Test rapide » limite aux images calibrables en double densite) ; refus du lecteur cible garde limites aux ecritures
# precompensees hors profil Manuel et aux restaurations en copie secteur
$tip.SetToolTip($btnWCalReset, (T "Efface toutes les calibrations de précompensation, de tous les lecteurs : courbes communes et par tête de toutes les familles (standard, long track, haute densité) et courbes croisées, avec les niveaux de la calibration rapide, la mémoire par marque et les facteurs mesurés.") + "`n" + (Get-CalibResetAfterText) + "`n" + (T "Le lecteur cible choisi est gardé : les écritures précompensées pour lui (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée."))
$btnWCalReset.Add_Click({ Reset-CalibProfiles })

# --- Ligne 4 : progression globale de la calibration (toutes passes), visible pendant et apres
$pbWCal = New-Object System.Windows.Forms.ProgressBar
$pbWCal.Location = '12,141'; $pbWCal.Size = '300,16'; $pbWCal.Minimum = 0; $pbWCal.Maximum = 100; $pbWCal.Visible = $false
$lblWCal = New-Object System.Windows.Forms.Label
$lblWCal.Location = '320,142'; $lblWCal.ForeColor = 'DimGray'; $lblWCal.Visible = $false
# 12.10 (relecture de la RC) : largeur fixe jusqu au bord interieur du groupe, ancree a droite, une ligne, points de
# suspension, texte complet en infobulle (Update-WCalTip, 140) : en AutoSize, un texte long (etape ou fin d une calibration,
# verdict du controle pour un lecteur cible) depassait le cadre « Options d ecriture » et sa fin etait coupee ; hauteur
# d une ligne de la police heritee (FontChanged)
$lblWCal.AutoSize = $false; $lblWCal.AutoEllipsis = $true; $lblWCal.Anchor = 'Top,Left,Right'
$lblWCal.Size = New-Object System.Drawing.Size(($grpWOpt.DisplayRectangle.Right - 320), $lblWCal.PreferredHeight)
$lblWCal.Add_FontChanged({ $lblWCal.Height = $lblWCal.PreferredHeight; Update-WCalTip })
$lblWCal.Add_SizeChanged({ Update-WCalTip })
$lblWCal.Add_PaddingChanged({ Update-WCalTip })
# 12.8 (lot 3b) : verdict du controle apres ecriture avec son icone d etat de 16 px et son encre (Set-WCalVerdict) ; tout
# autre texte (calibration, prechauffage...) les retire
$lblWCal.Add_Paint({ param($s, $e) Draw-WCalIcon $s $e })
$lblWCal.Add_TextChanged({ if ($script:WCalIcon -and $lblWCal.Text -ne $script:WCalIcon.Text) { Clear-WCalVerdict }; Update-WCalTip })

$grpWOpt.Controls.AddRange(@($chkWPreErase, $chkWEraseEmpty, $chkWNoVerify, (New-Label (T 'Essais :') '500,26'), $numWRetries, $chkWSlow, $chkWPrecomp, $txtWPrecomp, $chkWPostCheck,
    $lblWPrecomp1, $txtWPrecomp1, (New-Label (T 'Calibration précomp :') '12,115'), $cmbWCalMode, $btnWCalib, $btnWCross, $btnWCalBack, $btnWCalReset, $pbWCal, $lblWCal, $lblWRepair, $numWRepair))

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
# 12.8 (lot 5, D9) : meme libelle que la case de l onglet Lecture ; cases suivantes decalees (texte plus long)
$chkWReverse.Text = (T 'Face B flippy (--reverse)'); $chkWReverse.Location = '12,46'; $chkWReverse.Width = 170
$chkWHard = New-Object System.Windows.Forms.CheckBox
$chkWHard.Text = (T 'Secteurs durs (--hard-sectors)'); $chkWHard.Location = '190,46'; $chkWHard.Width = 205
$chkWTG43 = New-Object System.Windows.Forms.CheckBox
$chkWTG43.Text = (T 'TG43 lecteur 8 pouces (--gen-tg43)'); $chkWTG43.Location = '405,46'; $chkWTG43.Width = 250

$grpWAdv.Controls.AddRange(@((New-Label (T 'Pistes :') '12,23'), $txtWTracks, (New-Label (T 'Densel :') '232,23'), $cmbWDensel,
    (New-Label (T 'Fake index :') '365,23'), $txtWFakeIdx, (New-Label (T 'Diskdefs :') '540,23'), $txtWDiskdefs, $btnWDiskdefs,
    $chkWReverse, $chkWHard, $chkWTG43))

# --- Action
$btnWrite = New-Object System.Windows.Forms.Button
$btnWrite.Text = (T 'ÉCRIRE LA DISQUETTE'); $btnWrite.Location = '10,346'; $btnWrite.Size = '250,40'; $btnWrite.Font = $bold

# 12.9 (S1, synthese C) : ecriture refusee faute d image (Start-ImageWrite : « Fichier image introuvable. ») : sequence non
# suivie, la case « Ecriture sans surveillance » reste cochee, sans ligne de journal, comme un refus pendant une commande gw
$btnWrite.Add_Click({ if ($txtWFile.Text -and (Test-Path -LiteralPath $txtWFile.Text)) { Start-UnattendedWrite }; Start-WriteTabWrite })

$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblWProfileInfo.Location = '270,346'; $lblWProfileInfo.Size = '502,40'; $lblWProfileInfo.Anchor = 'Top,Left,Right'
$lblWProfileInfo.ForeColor = 'DimGray'; $lblWProfileInfo.Text = (T 'Choisissez une image : le format et la précompensation seront déduits automatiquement.')
# 12.10 (relecture des captures) : points de suspension en permanence, et non plus pour le seul avis de la Bibliotheque :
# un texte de plus de deux lignes (profil long, facteur par tete, haute densite non calibree, lecteur cible) finit par des
# points de suspension au lieu d une 3e ligne coupee par le bas, texte complet en infobulle (Update-WProfileTip, 140) ;
# un texte qui tient en deux lignes est dessine comme avant
$lblWProfileInfo.AutoEllipsis = $true
# 12.8 (FIX-PISTES) : avis de fin d une operation de la Bibliotheque (Set-WTabNotice) retire au texte suivant
$lblWProfileInfo.Add_TextChanged({ Clear-WTabNotice; Update-WProfileTip })
$lblWProfileInfo.Add_SizeChanged({ Update-WProfileTip })

$tabW.Controls.AddRange(@($grpWImage, $grpWOpt, $grpWAdv, $btnWrite, $lblWProfileInfo, $chkWWarm, $chkWCalWarm, $lblWWarmMin, $numWWarmMin, $lblWWarmMinU, $chkWLevel, $lblWLevelMode, $cmbWLevelMode))
$tabW.AutoScroll = $true                                  # fenetre basse ou journal agrandi : defilement plutot que bouton masque
# Champ de la duree du prechauffage et son unite : a la suite du libelle, mesure dans la police de la fenetre (anglais compris)
$numWWarmMin.Left = $lblWWarmMin.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWWarmMin.Text, $form.Font).Width + 8
$lblWWarmMinU.Left = $numWWarmMin.Right + 6
# 12.9 (S1) : case « Sans surveillance » a 24 px de l unite de la duree (texte mesure dans la police de la fenetre)
$tabW.Controls.Add($chkWUnattended)
$chkWUnattended.Left = $lblWWarmMinU.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWWarmMinU.Text, $form.Font).Width + 24
$cmbWLevelMode.Left = $lblWLevelMode.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWLevelMode.Text, $form.Font).Width + 8
# 12.10 : liste « Lecteur cible », a la suite de la liste « Mesure : » (Set-TargetDriveLayout) ; infobulle de la case de
# la mesure gardee, remplacee quand un lecteur cible est choisi (Update-SlowUi)
$tabW.Controls.AddRange(@($lblWTarget, $cmbWTarget))
$script:WLevelTip = $tip.GetToolTip($chkWLevel)
Update-TargetDriveUi

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
Register-SettingCtl 'levelBeforeWriteMode' $cmbWLevelMode
# 12.10 : courbes par lecteur : vue du lecteur choisi (Sync-PrecompCurves), liste « Lecteur cible » de ce lecteur
# (Update-TargetDriveUi, puis case de la mesure : Update-SlowUi), fenetre Courbe fermee (elle dessinait l autre lecteur),
# profil de l image recalcule une fois la fenetre affichee (avant : Set-Defaults et Load-Config, puis Shown le fait)
$cmbDrive.Add_TextChanged({
    Update-TargetDriveUi; Update-SlowUi
    Sync-PrecompCurves
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    if ($form.Visible) { Update-PrecompForImage $txtWFile.Text }
})

