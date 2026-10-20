# ============================== ACCUEIL ========================================
# Point d entree pour un debutant : une carte par tache courante, qui ouvre l onglet adapte ou lance l action.
$tabH = New-TabPage (T 'Accueil')
$tabH.AutoScroll = $true

$lblHTitle = New-Object System.Windows.Forms.Label
$lblHTitle.Text = (T 'Que voulez-vous faire ?'); $lblHTitle.Location = '14,8'; $lblHTitle.AutoSize = $true
$lblHTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13); $lblHTitle.ForeColor = $script:Theme.Accent2
$lblHSub = New-Object System.Windows.Forms.Label
$lblHSub.Text = (T "Choisissez une tâche : l'application règle les options pour vous. F1 ouvre l'aide de l'onglet affiché.")
$lblHSub.Location = '16,38'; $lblHSub.AutoSize = $true; $lblHSub.ForeColor = $script:Theme.Muted

# 12.7 : zone de progression de la calibration, a la place du titre et du sous-titre (14,4, largeur des deux colonnes de
# cartes, 56 px au-dessus de la premiere rangee en 14,64) : titre et liens, barre, detail. Update-HomeProgress (minuterie)
$pnlHomeProg = New-Object System.Windows.Forms.Panel
$pnlHomeProg.Name = 'pnlHomeProg'; $pnlHomeProg.Location = '14,4'; $pnlHomeProg.Size = '756,56'; $pnlHomeProg.Visible = $false
$lblHProgTitle = New-Object System.Windows.Forms.Label
$lblHProgTitle.Name = 'lblHProgTitle'; $lblHProgTitle.AutoSize = $false; $lblHProgTitle.UseMnemonic = $false; $lblHProgTitle.Location = '0,0'; $lblHProgTitle.Size = '756,20'
$lblHProgTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $lblHProgTitle.ForeColor = $script:Theme.Accent2
$pbHProg = New-Object System.Windows.Forms.ProgressBar
$pbHProg.Name = 'pbHProg'; $pbHProg.Location = '0,22'; $pbHProg.Size = '756,12'; $pbHProg.Minimum = 0; $pbHProg.Maximum = 100
$lblHProgDetail = New-Object System.Windows.Forms.Label
$lblHProgDetail.Name = 'lblHProgDetail'; $lblHProgDetail.AutoSize = $false; $lblHProgDetail.UseMnemonic = $false; $lblHProgDetail.Location = '0,37'; $lblHProgDetail.Size = '756,19'
$lblHProgDetail.ForeColor = $script:Theme.Muted
# Titre et detail dans leurs couleurs pendant une commande gw (Set-Busy desactive les onglets : texte grise sinon)
$lblHProgTitle.Add_Paint({ Draw-HomeProgText $this $_ }); $lblHProgDetail.Add_Paint({ Draw-HomeProgText $this $_ })
$lnkHProgLog = New-Object System.Windows.Forms.LinkLabel; $lnkHProgLog.Name = 'lnkHProgLog'
$lnkHProgCurve = New-Object System.Windows.Forms.LinkLabel; $lnkHProgCurve.Name = 'lnkHProgCurve'
$lnkHProgClose = New-Object System.Windows.Forms.LinkLabel; $lnkHProgClose.Name = 'lnkHProgClose'
foreach ($lk in @($lnkHProgLog, $lnkHProgCurve, $lnkHProgClose)) { $lk.AutoSize = $true; $lk.UseMnemonic = $false; $lk.Visible = $false; $lk.Location = '0,1'; $lk.LinkColor = $script:Theme.Accent; $lk.ActiveLinkColor = $script:Theme.Accent2 }
$lnkHProgLog.Text = (T 'Afficher le journal'); $lnkHProgCurve.Text = (T 'Afficher la courbe'); $lnkHProgClose.Text = (T 'Fermer')
# Journal : affiche comme par le bouton « Afficher journal » de la barre (jamais force par la zone elle-meme)
$lnkHProgLog.Add_LinkClicked({ Set-LogVisible $true; Update-HomeProgress })
$lnkHProgCurve.Add_LinkClicked({ $d = $script:HomeProgDone; if ($d) { Show-PrecompCurve ([string]$d.Family) ([bool]$d.Slow) } })
$lnkHProgClose.Add_LinkClicked({ Clear-HomeProgress })
$pnlHomeProg.Controls.AddRange(@($lblHProgTitle, $pbHProg, $lblHProgDetail, $lnkHProgLog, $lnkHProgCurve, $lnkHProgClose))
foreach ($lk in @($lnkHProgLog, $lnkHProgCurve, $lnkHProgClose)) { $lk.BringToFront() }

$cardRestore = New-HomeCard 'History' (T 'Restaurer une disquette') (T "Copier une disquette d'origine sur une disquette vierge, avec les contrôles les plus stricts.") '14,64' { Show-Tab $tabRs }
$cardWrite   = New-HomeCard 'Save' (T 'Écrire une image sur une disquette') (T "Choisir un fichier (ADF, IPF, SCP...) dans votre bibliothèque et l'écrire sur une disquette.") '397,64' { Show-Tab $tabL }
$cardRead    = New-HomeCard 'Download' (T 'Sauvegarder une disquette') (T "Lire une disquette et l'enregistrer dans un fichier : SCP pour archiver, ADF pour un émulateur.") '14,156' { Show-Tab $tabR }
$cardCheck   = New-HomeCard 'Diagnostic' (T 'Vérifier une disquette ou un lecteur') (T 'Mesurer la qualité de lecture piste par piste, ou guider le réglage de l''alignement.') '397,156' { Show-Tab $tabAl }
# Carte Calibration a la place de l ancienne carte Courbe (courbe affichee depuis sa fenetre) ; 397,248 : carte Nettoyage
$cardCalib   = New-HomeCard 'Stopwatch' (T 'Calibrer le lecteur') (T 'Choisir un type de disquette, voir sa courbe et calibrer le lecteur : complète ou rapide.') '14,248' { Show-HomeCalib }
$cardTest    = New-HomeCard 'Usb' (T 'Tester le Greaseweazle') (T 'Vérifier que la carte répond (gw info), puis détecter les lecteurs branchés (A, B, 0 à 3).') '14,340' {
    if (Get-AppBusy) { return }                           # 12.8 (D20) : aussi pendant un prechauffage ou la mesure continue
    $script:DetectAt = $null                              # la detection complete remplace la detection automatique en attente
    $script:InfoArgs = @('info'); if ($txtDev.Text.Trim()) { $script:InfoArgs += "--device=$($txtDev.Text.Trim())" }
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:InfoArgs })
    $script:Chain.Enqueue({ Start-DriveDetect 'full' })
    Invoke-NextChainStep
}
$cardHelp    = New-HomeCard 'Help' (T 'Guide pas à pas') (T 'Ouvrir l''aide en ligne : premiers pas, glossaire des termes, dépannage.') '397,340' { Open-Help 'Premiers-pas' }
$cardClean   = New-HomeCard 'Repair' (T 'Nettoyer les têtes du lecteur') (T 'Procédure en images. Disquette de nettoyage uniquement, jamais une vraie disquette.') '397,248' { Show-CleanDialog }
$cardJitter  = New-HomeCard 'Setting' (T 'Régler le jitter') (T "Choisir le jitter maximal d'une piste saine : plus il est strict, plus l'écriture lente réécrit de pistes.") '14,432' { Show-JitterSettings }
$script:HomeCalDesc = $cardCalib.Controls[3].Text      # description d origine, remplacee par la progression (Update-HomeCalibCard)
$tabH.Controls.AddRange(@($lblHTitle, $lblHSub, $pnlHomeProg, $cardRestore, $cardWrite, $cardRead, $cardCheck, $cardCalib, $cardClean, $cardTest, $cardHelp, $cardJitter))

# ============================== RESTAURATION : INTERFACE =======================
# Assistant : lecture de l original, changement de disquette, ecriture stricte, controle et comparaison. La logique
# (machine d etats $script:Restore) est dans la section RESTAURATION : LOGIQUE.
$tabRs = New-TabPage (T 'Restauration')
$tabRs.AutoScroll = $true
$script:RsFluxItem = (T 'Copie exacte du flux (disquette protégée ou format inconnu)')
$script:RsAutoItem = (T 'Détection automatique (conseillée)')

# 12.8 (D10, D11) : un seul lecteur, celui du bandeau ; maquette d A1 § 2.6 (cadre 1 : lecteur et format, cadre 2 :
# calibration du lecteur, cadre 3 : sauvegarde)
$grpRsSrc = New-Group (T '1. Disquette d''origine') '10,4' '380,118'; $grpRsSrc.Anchor = 'Top,Left'
$lblRsDrive = New-Object System.Windows.Forms.Label
$lblRsDrive.Location = '78,24'; $lblRsDrive.Size = '290,20'; $lblRsDrive.AutoEllipsis = $true
$tip.SetToolTip($lblRsDrive, (T "Lecteur qui lit l'original puis écrit la copie : le choix « Lecteur » du bandeau. L'application vous demande de changer de disquette entre la lecture et l'écriture."))
$cmbRsFmt = New-Object System.Windows.Forms.ComboBox
$cmbRsFmt.Location = '78,48'; $cmbRsFmt.Width = 290; $cmbRsFmt.DropDownWidth = 360; $cmbRsFmt.DropDownStyle = 'DropDownList'
# Elements dans l ordre des codes du reglage restoreFormat (D13) : l index 0 est la detection automatique, pas le flux
foreach ($rsCode in $script:SettingDefs['restoreFormat'].Codes) {
    [void]$cmbRsFmt.Items.Add($(if ($rsCode -eq 'auto') { $script:RsAutoItem } elseif ($rsCode -eq 'flux') { $script:RsFluxItem } else { $rsCode }))
}
Register-SettingCtl 'restoreFormat' $cmbRsFmt
$tip.SetToolTip($cmbRsFmt, (T "Format de la disquette d'origine.`nDétection automatique (conseillée) : le format est identifié à la lecture de l'original. Format non reconnu ou disquette protégée contre la copie : copie exacte du flux.`nAvec un format (amiga.amigados pour une disquette Amiga, par exemple) : chaque secteur est lu et vérifié, la copie est écrite avec la précompensation calibrée puis comparée secteur par secteur à l'original.`nCopie exacte du flux : pour une disquette protégée contre la copie ou d'un format absent de la liste ; le signal est recopié tel quel, sans précompensation ni comparaison par secteur."))
$lblRsFmtFound = New-Object System.Windows.Forms.Label
$lblRsFmtFound.Location = '12,76'; $lblRsFmtFound.Size = '360,20'; $lblRsFmtFound.AutoEllipsis = $true; $lblRsFmtFound.ForeColor = $script:Theme.Muted
$lblRsSrcHint = New-Object System.Windows.Forms.Label
$lblRsSrcHint.Text = (T 'Conseil : protégez-la en écriture avant de commencer.')
$lblRsSrcHint.Location = '12,96'; $lblRsSrcHint.Size = '360,20'; $lblRsSrcHint.ForeColor = $script:Theme.Muted
$tip.SetToolTip($lblRsSrcHint, (T 'Disquette 3,5" : fenêtre de protection ouverte. 5,25" : encoche couverte. Ainsi, même une erreur de manipulation ne peut pas l''effacer.'))
$grpRsSrc.Controls.AddRange(@((New-Label (T 'Lecteur :') '12,24'), $lblRsDrive, (New-Label (T 'Format :') '12,51'), $cmbRsFmt, $lblRsFmtFound, $lblRsSrcHint))

$grpRsCal = New-Group (T '2. Calibration du lecteur') '10,126' '380,80'; $grpRsCal.Anchor = 'Top,Left'
$lblRsCal = New-Object System.Windows.Forms.Label
$lblRsCal.Location = '12,20'; $lblRsCal.Size = '262,54'; $lblRsCal.AutoEllipsis = $true
$btnRsCurve = New-Object System.Windows.Forms.Button
$btnRsCurve.Text = (T 'Courbe'); $btnRsCurve.Location = '280,22'; $btnRsCurve.Size = '90,28'; $btnRsCurve.Anchor = 'Top,Right'; $btnRsCurve.Enabled = $false
$tip.SetToolTip($btnRsCurve, (T "Affiche la courbe de précompensation appliquée par la restauration, une courbe par tête si elle existe : haute densité pour un format haute densité choisi, sinon double densité."))
$btnRsCurve.Add_Click({ Show-RsCurve })
$grpRsCal.Controls.AddRange(@($lblRsCal, $btnRsCurve))

$grpRsDir = New-Group (T '3. Sauvegarde (original lu, copie relue, rapport)') '10,210' '380,82'; $grpRsDir.Anchor = 'Top,Left'
$txtRsDir = New-Object System.Windows.Forms.TextBox
$txtRsDir.Location = '78,21'; $txtRsDir.Width = 256
$btnRsDir = New-Object System.Windows.Forms.Button
$btnRsDir.Text = '...'; $btnRsDir.Location = '340,20'; $btnRsDir.Width = 30
$btnRsDir.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = (T 'Dossier où enregistrer la lecture de l''original, la relecture de la copie et le rapport')
    if ($txtRsDir.Text -and (Test-Path -LiteralPath $txtRsDir.Text)) { $d.SelectedPath = $txtRsDir.Text }
    if ($d.ShowDialog() -eq 'OK') { $txtRsDir.Text = $d.SelectedPath }
})
$txtRsName = New-Object System.Windows.Forms.TextBox
$txtRsName.Location = '78,51'; $txtRsName.Width = 292
$tip.SetToolTip($txtRsDir, (T "Dossier où sont enregistrés la lecture de l'original, la relecture de la copie et le rapport de restauration."))
$tip.SetToolTip($txtRsName, (T 'Nom des fichiers enregistrés, par exemple « Workbench 1.3 ». Vide : date et heure.'))
$grpRsDir.Controls.AddRange(@((New-Label (T 'Dossier :') '12,24'), $txtRsDir, $btnRsDir, (New-Label (T 'Nom :') '12,54'), $txtRsName))
Set-Cue $txtRsDir (T 'Documents\Greaseweazle Studio\Restaurations')
Set-Cue $txtRsName (T 'vide = date et heure')

$btnRsStart = New-Object System.Windows.Forms.Button
$btnRsStart.Text = (T 'RESTAURER LA DISQUETTE'); $btnRsStart.Location = '10,300'; $btnRsStart.Size = '250,40'; $btnRsStart.Font = $bold
$btnRsStart.Add_Click({ try { Start-Restore } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$lblRsRules = New-Object System.Windows.Forms.Label
$lblRsRules.Location = '404,232'; $lblRsRules.Size = '372,100'; $lblRsRules.ForeColor = $script:Theme.Muted
$tip.SetToolTip($btnRsStart, (T "Lit l'original, vous demande de changer de disquette, puis écrit et contrôle la copie avec les règles les plus strictes.`nDurée : de quelques minutes à plus d'une demi-heure selon la calibration et l'état des disquettes."))

$lblRsStepsTitle = New-Object System.Windows.Forms.Label
$lblRsStepsTitle.Text = (T 'Étapes'); $lblRsStepsTitle.Location = '402,8'; $lblRsStepsTitle.AutoSize = $true
$lblRsStepsTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $lblRsStepsTitle.ForeColor = $script:Theme.Accent2
$script:RsStepNames = @((T 'Lire la disquette d''origine'), (T 'Vérifier la lecture'), (T 'Changer de disquette'),
    (T 'Vérifier la disquette de destination'), (T 'Calibrer le lecteur si nécessaire'), (T 'Écrire la tête 0 puis la tête 1'),
    (T 'Contrôler toutes les pistes'), (T 'Comparer la copie à l''original'))
$script:RsStepLabels = @()
for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) {
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point(404, (32 + 21 * $i)); $l.Size = '372,20'; $l.AutoEllipsis = $true
    $l.ForeColor = $script:Theme.Muted; $l.Text = "○  " + $script:RsStepNames[$i]
    $script:RsStepLabels += $l
}
$lblRsNow = New-Object System.Windows.Forms.Label
$lblRsNow.Location = '404,204'; $lblRsNow.Size = '372,22'; $lblRsNow.AutoEllipsis = $true; $lblRsNow.ForeColor = $script:Theme.Accent

# Attente du changement de disquette : la sequence est en pause, sans commande gw en cours
$pnlRsWait = New-Object System.Windows.Forms.Panel
$pnlRsWait.Location = '402,230'; $pnlRsWait.Size = '374,104'; $pnlRsWait.BackColor = [System.Drawing.Color]::FromArgb(255, 246, 220); $pnlRsWait.Visible = $false
$lblRsWait = New-Object System.Windows.Forms.Label
$lblRsWait.Location = '8,6'; $lblRsWait.AutoSize = $true; $lblRsWait.MaximumSize = New-Object System.Drawing.Size(358, 0); $lblRsWait.ForeColor = [System.Drawing.Color]::FromArgb(90, 60, 0)
$btnRsGo = New-Object System.Windows.Forms.Button
$btnRsGo.Text = (T 'Continuer'); $btnRsGo.Location = '8,68'; $btnRsGo.Size = '120,30'
$btnRsGo.Add_Click({ try { Resume-Restore $false } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$btnRsForce = New-Object System.Windows.Forms.Button
$btnRsForce.Text = (T 'Écraser quand même'); $btnRsForce.Location = '134,68'; $btnRsForce.Size = '140,30'; $btnRsForce.Visible = $false
$btnRsForce.Add_Click({ try { Resume-Restore $true } catch { Append-Log ((T "ERREUR restauration : {0}") -f "$($_.Exception.Message)") } })
$btnRsCancel = New-Object System.Windows.Forms.Button
$btnRsCancel.Text = (T 'Annuler'); $btnRsCancel.Location = '280,68'; $btnRsCancel.Size = '86,30'
$btnRsCancel.Add_Click({ Stop-Restore (T 'annulée par l''utilisateur') })
$pnlRsWait.Controls.AddRange(@($lblRsWait, $btnRsGo, $btnRsForce, $btnRsCancel))

# Verdict final
$lblRsResult = New-Object System.Windows.Forms.Label
$lblRsResult.Location = '402,230'; $lblRsResult.AutoSize = $true; $lblRsResult.MaximumSize = New-Object System.Drawing.Size(374, 0); $lblRsResult.MinimumSize = New-Object System.Drawing.Size(374, 60)
$lblRsResult.Visible = $false; $lblRsResult.Padding = New-Object System.Windows.Forms.Padding(8)
$lblRsResult.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)

$tabRs.Controls.AddRange(@($grpRsSrc, $grpRsCal, $grpRsDir, $btnRsStart, $lblRsRules, $lblRsStepsTitle) + $script:RsStepLabels + @($lblRsNow, $pnlRsWait, $lblRsResult))
Set-Btn $btnRsStart 'History' 'primary'
Set-Btn $btnRsDir 'FolderOpen' -IconOnly
Set-Btn $btnRsCurve 'Diagnostic'
Set-Btn $btnRsGo 'Play' 'primary'
Set-Btn $btnRsForce 'Delete' 'danger'
Set-Btn $btnHelpTop 'Help'

# Aide en ligne : page du wiki de chaque onglet (F1, bouton Aide)
$tabH.Tag = 'Premiers-pas'; $tabRs.Tag = 'Restaurer-une-disquette'; $tabL.Tag = 'Autres-onglets'; $tabW.Tag = 'Écriture'
$tabR.Tag = 'Autres-onglets'; $tabCv.Tag = 'Autres-onglets'; $tabCmp.Tag = 'Autres-onglets'; $tabAl.Tag = 'Qualité-et-alignement'
$tabT.Tag = 'Autres-onglets'; $tabD.Tag = 'Autres-onglets'; $tabC.Tag = 'Autres-onglets'

# Onglets affiches : usage courant, ou tous en mode expert
$script:AllTabs = @($tabH, $tabRs, $tabL, $tabW, $tabR, $tabCv, $tabCmp, $tabAl, $tabT, $tabD, $tabC)
$script:NoviceTabs = @($tabH, $tabRs, $tabL, $tabW, $tabR, $tabAl)
$chkExpert.Add_CheckedChanged({ Update-TabSet })

# Textes indicatifs des champs vides et infobulles des champs qui n en avaient pas
Set-Cue $txtLibRoot   (T 'Dossier qui contient vos images disque (bouton à droite pour le choisir)')
Set-Cue $txtLibFilter (T 'Nom d''image à rechercher')
Set-Cue $txtWFile     (T 'Image à écrire : ADF, IPF, SCP, HFE, IMG... (bouton à droite)')
Set-Cue $txtWTracks   (T 'vide = toutes les pistes')
Set-Cue $txtWFakeIdx  (T 'vide = lecteur normal')
Set-Cue $txtWDiskdefs (T 'vide = formats intégrés à gw')
Set-Cue $txtDev       (T 'auto')
Set-Cue $txtRFile     (T 'Fichier à créer : .scp pour archiver, .adf pour un émulateur')
Set-Cue $txtRTracks   (T 'vide = toutes')
Set-Cue $txtRDiskdefs (T 'vide = formats intégrés à gw')
Set-Cue $txtCvIn      (T 'Fichier à convertir')
Set-Cue $txtCvOut     (T 'Fichier à créer (son extension fixe le type)')
Set-Cue $txtCvTracks  (T 'vide = toutes')
Set-Cue $txtCmpRef    (T 'Image de référence : ADF, IPF, SCP...')
Set-Cue $txtEraseTracks (T 'vide = toutes les pistes')
$tip.SetToolTip($txtRFile, (T "Fichier où enregistrer la disquette lue.`n.scp : flux exact, pour archiver (protections comprises).`n.adf, .img, .st : secteurs décodés, pour un émulateur (un format est alors nécessaire)."))
$tip.SetToolTip($cmbRFmt, (T "Format de la disquette. (auto) : flux sans décodage.`nAvec un format, gw vérifie chaque secteur et relit les pistes incomplètes (Essais)."))
$tip.SetToolTip($numRRetries, (T 'Nombre de relectures d''une piste dont des secteurs manquent (avec un format seulement).'))
$tip.SetToolTip($txtRTracks, (T 'Pistes à lire, par exemple c=0-79:h=0-1. Vide : toutes les pistes du format.'))
$tip.SetToolTip($chkRRaw, (T "Enregistre le flux réel du disque ; avec un format, celui-ci sert alors au contrôle des secteurs et aux relectures.`nSans cette case, un .scp lu avec un format contient un flux reconstitué à partir des secteurs décodés.`nAvec des essais, les tours relus sont ajoutés après les premiers, mais la plupart des logiciels ne lisent que les premiers tours."))
$tip.SetToolTip($chkRRev, (T 'Face B d''une disquette flippy (5,25" retournée) : le flux est lu à l''envers.'))
$tip.SetToolTip($cmbRDensel, (T 'Force le signal de densité du lecteur (H = haute, L = basse). (non) : laissé au lecteur.'))
$tip.SetToolTip($txtRDiskdefs, (T 'Fichier de définitions de formats personnalisés. Vide : formats intégrés à gw.'))
$tip.SetToolTip($btnRead, (T 'Lit la disquette insérée et enregistre le fichier.'))
$tip.SetToolTip($btnWrite, (T 'Écrit l''image sur la disquette insérée avec les options de cet onglet. Tout le contenu de la disquette est remplacé.'))
$tabs.TabPages.AddRange([System.Windows.Forms.TabPage[]]$script:AllTabs)   # tous attaches : Fit-ControlText les ajuste ; Update-TabSet apres la configuration
$split.Panel1.Controls.Add($tabs)
# 12.8 (lot 2) : onglet Restauration : cadre « 2. Calibration du lecteur » a jour a l entree dans l onglet
$tabs.Add_SelectedIndexChanged({ if ($tabs.SelectedTab -eq $tabRs) { Update-RsCalib } })
# Onglet Ecriture defilant (fenetre basse) : il s ouvre en haut, sur l image. Selectionne par le code (bibliotheque),
# WinForms y place le focus sur un controle du bas et fait defiler jusqu a lui. Reprise une fois ce focus pose.
$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -ne $tabW -or -not $form.IsHandleCreated) { return }
    [void]$form.BeginInvoke([System.Action]{
        if ($tabs.SelectedTab -ne $tabW -or -not $tabW.VerticalScroll.Visible) { return }
        if ($tabW.ContainsFocus) { [void]$txtWFile.Focus() }
        $tabW.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
    })
})

# --- Barre de boutons + barre d'etat (hors du separateur : toujours visibles) ---
$flowButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$flowButtons.Size = New-Object System.Drawing.Size(790, 44)
$flowButtons.BackColor = $script:Theme.Window; $flowButtons.Dock = 'Bottom'; $flowButtons.Padding = New-Object System.Windows.Forms.Padding(6,4,6,2); $flowButtons.WrapContents = $false

$btnStop = New-BarButton (T 'Arrêter') 105
$btnStop.Enabled = $false; $btnStop.Font = $bold
$btnStop.Add_Click({
    $script:Detect = $null; $script:DetectAt = $null
    # 12.8 (D20) : Get-AppBusy ; la mesure continue seule (quality) s arrete plus bas, sans « Interrompu ». $script:GwProc
    # seul : gw termine mais pas encore traite par le minuteur, chaine et operations arretees quand meme
    $busy = Get-AppBusy
    if ($script:GwProc -or ($busy -and $busy -ne 'quality')) {
        if ($script:GwProc -and -not $script:GwProc.HasExited) {
            try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
        }
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        Stop-WriteWarmup       # prechauffage d une ecriture lente : chaine d ecriture mise de cote abandonnee, rien n est ecrit
        if ($script:Restore) { Stop-Restore (T 'interrompue par l''utilisateur') }
        if ($script:Rep) { Stop-WriteCheck }
        if ($script:Cal) { Stop-PrecompCalib }
        Append-Log (T '*** Interrompu par l''utilisateur ***')
    }
    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null; Append-Log (T 'Mesure continue arrêtée.') }
})

$btnLogToggle = New-BarButton (T 'Masquer journal') 140
$btnLogToggle.Add_Click({ Set-LogVisible ($split.Panel2Collapsed) })

$btnClear = New-BarButton (T 'Vider') 95
$btnClear.Add_Click({ $txtLog.Clear() })

$btnSaveLog = New-BarButton (T 'Exporter') 100
$btnSaveLog.Add_Click({
    $d = New-Object System.Windows.Forms.SaveFileDialog
    $d.Filter = (T 'Texte|*.txt'); $d.InitialDirectory = $script:AppDir
    $d.FileName = "gw-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($d.ShowDialog() -eq 'OK') { $txtLog.Text | Set-Content -LiteralPath $d.FileName -Encoding UTF8 }
})

$btnCfgSave = New-BarButton (T 'Enregistrer') 115
$btnCfgSave.Add_Click({ if (Save-Config) { Append-Log ((T "Paramètres enregistrés : {0}") -f "$($script:ConfigFile)") } })

$btnCfgReset = New-BarButton (T 'Réinitialiser') 120
$btnCfgReset.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        (T "Remettre tous les paramètres de l'interface à leurs valeurs par défaut et supprimer le fichier de configuration ?`n`n(Aucun effet sur le Greaseweazle, ni sur vos fichiers image, ni sur l'index de la bibliothèque.)"),
        (T 'Réinitialiser les paramètres'), 'YesNo', 'Question')
    if ($r -eq 'Yes') {
        Set-Defaults
        Update-Library
        if (Test-Path -LiteralPath $script:ConfigFile) {
            try { Remove-Item -LiteralPath $script:ConfigFile -Force; Append-Log (T 'Configuration supprimée, valeurs par défaut restaurées.') }
            catch { Append-Log ((T "Impossible de supprimer la configuration : {0}") -f "$($_.Exception.Message)") }
        } else { Append-Log (T 'Valeurs par défaut restaurées.') }
    }
})

# Prechauffage en cours (ecriture lente ou calibration) : fin apres la lecture en cours, sans tuer gw. Visible pendant
# tout prechauffage (minuteur) ; Enregistrer et Reinitialiser, inactifs pendant une operation, lui cedent leur place
# (la barre ne passe pas a la ligne)
$btnWarmSkip = New-BarButton (T 'Passer le préchauffage') 175
$btnWarmSkip.Visible = $false
$btnWarmSkip.Add_Click({
    $w = if ($script:WriteWarm) { $script:WriteWarm } elseif ($script:Cal -and $script:Cal.Stage -eq 'warmup') { $script:Cal } else { $null }
    if (-not $w -or $w.WarmSkip) { return }
    $w.WarmSkip = $true; $btnWarmSkip.Enabled = $false
    Append-Log ((T "Préchauffage du lecteur {0} passé à votre demande après {1} : la lecture en cours se termine, puis l'opération continue.") -f "$($w.Drive)", (Format-CalDuration ([math]::Round(((Get-Date) - $w.WarmStart).TotalSeconds))))
    if ($script:WriteWarm) { Update-WriteWarmupProgress } else { Update-CalibProgress }
})

$flowButtons.Controls.AddRange(@($btnStop, $btnWarmSkip, $btnLogToggle, $btnClear, $btnSaveLog, $btnCfgSave, $btnCfgReset))

$status = New-Object System.Windows.Forms.StatusStrip
$status.SizingGrip = $false
$status.BackColor = [System.Drawing.Color]::FromArgb(222, 227, 235)
$status.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$status.ImageScalingSize = New-Object System.Drawing.Size(18, 18)
$status.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel
$stOp.Spring = $true; $stOp.TextAlign = 'MiddleLeft'; $stOp.Text = (T 'Prêt.')
$stOp.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
$stTrack = New-Object System.Windows.Forms.ToolStripStatusLabel
$stTrack.Text = ''; $stTrack.AutoSize = $true; $stTrack.ForeColor = $script:Theme.Accent2
$stTrack.Font = New-Object System.Drawing.Font('Consolas', 9.75, [System.Drawing.FontStyle]::Bold)
$stBar = New-Object System.Windows.Forms.ToolStripProgressBar
$stBar.Size = New-Object System.Drawing.Size(280, 18); $stBar.Visible = $false; $stBar.MarqueeAnimationSpeed = 30
[void]$status.Items.AddRange(@($stOp, $stTrack, $stBar))

# --- Journal (panneau bas du separateur, repliable) ---
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Dock = 'Fill'; $txtLog.ReadOnly = $true; $txtLog.DetectUrls = $false; $txtLog.WordWrap = $false
$txtLog.Font = $monoBig; $txtLog.BorderStyle = 'None'
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 31)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(232, 234, 238)
$script:LogColors = @{
    cmd  = [System.Drawing.Color]::FromArgb(130, 190, 255)
    err  = [System.Drawing.Color]::FromArgb(255, 110, 95)
    warn = [System.Drawing.Color]::FromArgb(255, 200, 100)
    ok   = [System.Drawing.Color]::FromArgb(120, 230, 130)
    dim  = [System.Drawing.Color]::FromArgb(165, 170, 178)
    std  = [System.Drawing.Color]::FromArgb(232, 234, 238)
}
$split.Panel2.Controls.Add($txtLog)

# ============================== HABILLAGE (icones) =============================
$form.Icon = [System.Drawing.Icon]::FromHandle($script:LogoIcon.GetHicon())

# Onglets
$imgTabs = New-Object System.Windows.Forms.ImageList
$imgTabs.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$imgTabs.ImageSize = New-Object System.Drawing.Size(16, 16)
foreach ($n in @('Home','History','Library','Save','Download','Switch','Copy','Diagnostic','Repair','Stopwatch','Cmd')) {
    $imgTabs.Images.Add($n, (New-GlyphBitmap $n 16 $script:Theme.Accent))
}
$tabs.ImageList = $imgTabs
$tabH.ImageKey = 'Home'; $tabRs.ImageKey = 'History'
$tabL.ImageKey = 'Library'; $tabW.ImageKey = 'Save'; $tabR.ImageKey = 'Download'; $tabCv.ImageKey = 'Switch'
$tabCmp.ImageKey = 'Copy'; $tabAl.ImageKey = 'Diagnostic'; $tabT.ImageKey = 'Repair'; $tabD.ImageKey = 'Stopwatch'; $tabC.ImageKey = 'Cmd'

# Arborescence de la bibliotheque
$imgTree = New-Object System.Windows.Forms.ImageList
$imgTree.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$imgTree.ImageSize = New-Object System.Drawing.Size(16, 16)
$imgTree.Images.Add('blank', (New-Object System.Drawing.Bitmap(16, 16)))
$imgTree.Images.Add('dir',   (New-GlyphBitmap 'Folder'   16 $script:Theme.Folder))
$imgTree.Images.Add('zip',   (New-GlyphBitmap 'Package'  16 $script:Theme.Zip))
$imgTree.Images.Add('image', (New-GlyphBitmap 'Save'     16 $script:Theme.Accent))
$imgTree.Images.Add('doc',   (New-GlyphBitmap 'Document' 16 $script:Theme.Muted))
$imgTree.Images.Add('other', (New-GlyphBitmap 'Page'     16 ([System.Drawing.Color]::FromArgb(170, 175, 185))))
$treeLib.ImageList = $imgTree
$treeLib.ItemHeight = 20

# Boutons : actions principales en bleu, action destructive en rouge, parcours en icone seule
Set-Btn $btnLibRoot    'FolderOpen' -IconOnly
Set-Btn $btnLibRefresh 'Refresh'    -IconOnly
Set-Btn $btnLibFilter  'Search'     -IconOnly
Set-Btn $btnLibReindex 'Sync'
Set-Btn $btnLibFast    'Save' 'primary'
Set-Btn $btnLibSlow    'Save' 'primary'
Set-Btn $btnLibOpen    'OpenFile'
Set-Btn $btnLibExplore 'FolderOpen'
Set-Btn $btnWFile      'FolderOpen' -IconOnly
Set-Btn $btnWDiskdefs  'FolderOpen' -IconOnly
Set-Btn $btnWrite      'Save' 'primary'
Set-Btn $btnWCalib     'Diagnostic'
Set-Btn $btnWCalReset  'Delete' 'danger'
Set-Btn $btnWCurve     'Diagnostic'
Set-Btn $btnRFile      'FolderOpen' -IconOnly
Set-Btn $btnRDiskdefs  'FolderOpen' -IconOnly
Set-Btn $btnRead       'Download' 'primary'
Set-Btn $btnCvIn       'FolderOpen' -IconOnly
Set-Btn $btnCvOut      'FolderOpen' -IconOnly
Set-Btn $btnConvert    'Switch' 'primary'
Set-Btn $btnCmpRef     'FolderOpen' -IconOnly
Set-Btn $btnCmpFromWrite 'Save'
Set-Btn $btnCompare    'Copy' 'primary'
Set-Btn $btnAlStart    'Diagnostic' 'primary'
Set-Btn $btnAlRef      'Pin'
Set-Btn $btnAlReset    'Refresh'
Set-Btn $btnAlPos0     'Pin'
Set-Btn $btnAlPlus     'Add'
Set-Btn $btnAlMinus    'Remove'
Set-Btn $btnInfo       'Info'
Set-Btn $btnRpm        'Stopwatch'
Set-Btn $btnBw         'Usb'
Set-Btn $btnReset      'Refresh'
Set-Btn $btnUpdate     'Download'
Set-Btn $btnSeek       'Play'
Set-Btn $btnErase      'Delete' 'danger'
Set-Btn $btnClean      'Repair'
Set-Btn $btnPin        'Pin'
Set-Btn $btnDelaysShow 'Stopwatch'
Set-Btn $btnDelaysSet  'Check'
Set-Btn $btnC          'Play' 'primary'
Set-Btn $btnHelp       'Info'
Set-Btn $btnHelpAct    'Info'
Set-Btn $btnStop       'Stop' -IconColor $script:Theme.Danger
Set-Btn $btnWarmSkip   'Play'
Set-Btn $btnLogToggle  'Page'
Set-Btn $btnClear      'Delete'
Set-Btn $btnSaveLog    'Save'
Set-Btn $btnCfgSave    'Setting'
Set-Btn $btnCfgReset   'Refresh'
$tip.SetToolTip($btnClear,   (T 'Effacer le contenu du journal.'))
$tip.SetToolTip($btnSaveLog, (T 'Exporter le journal dans un fichier texte.'))
$tip.SetToolTip($btnCfgSave, (T 'Enregistrer maintenant tous les paramètres de l''interface.'))
$tip.SetToolTip($btnCfgReset,(T 'Remettre les paramètres de l''interface à leurs valeurs par défaut.'))
$tip.SetToolTip($btnStop, (T 'Arrête la commande ou la séquence en cours.'))
$tip.SetToolTip($btnWarmSkip, (T "Termine le préchauffage du lecteur après la lecture en cours : l'écriture lente (ou la calibration) commence aussitôt."))
$tip.SetToolTip($btnLogToggle, (T 'Affiche ou masque le journal des commandes gw.'))

# Barre d'etat : pictogramme d'etat
$script:StIcons = @{
    idle = New-GlyphBitmap 'Info'  16 $script:Theme.Muted
    run  = New-GlyphBitmap 'Play'  16 $script:Theme.Accent
    ok   = New-GlyphBitmap 'Check' 16 $script:Theme.Ok
    err  = New-GlyphBitmap 'Error' 16 $script:Theme.Danger
}
$stOp.Image = $script:StIcons.idle

$form.Controls.Add($flowButtons)
$form.Controls.Add($status)
$form.Controls.Add($pnlTop)
$form.Controls.Add($split)
$split.BringToFront()
