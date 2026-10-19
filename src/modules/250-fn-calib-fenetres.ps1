# ============================== FONCTIONS : CALIBRATION : FENETRES =============

function Show-CalibReview($cal, [string[]]$issues, [bool]$toWrite, [bool]$offerFull = $false, [bool]$noFields = $false, [bool]$offerRedo = $false, $compare = $null, [bool]$warnKeep = $false, $lvl2 = $null) {
    # Calibration au resultat douteux (non convergee, limite de 0 ou CalHardNs, ecart aux mesures, forme qui ne colle pas en
    # mode rapide) : la courbe obtenue est montree et l utilisateur decide. Pas de validation automatique : la decision
    # demande de regarder la courbe. Renvoie 'keep' (conserver / ecrire), 'stop' (abandonner) ou 'full' (calibration
    # complete, mode rapide seulement). Fermeture de la fenetre : arreter avant une ecriture, conserver sinon. noFields :
    # calibration rapide de la carte Calibration de l Accueil dont le profil n est pas place dans les champs --precomp.
    # 12.8 (lot 1c, point 2) : warnKeep (calibration rapide avant une ecriture, Complete-LevelCalib : niveau non verifie et
    # forme non conforme) : « Ecrire l image » sans le style principal, avertissement lblRevWarn au-dessus des boutons.
    # 12.7 point 2 : offerRedo : bouton « Refaire sur une autre disquette » ('redo'). compare = @{ Mode = 'ab' | 'aonly' ;
    # Curves ; Zones ; Text ; Pick } : fenetre de comparaison des calibrations A et B ('keep' : courbe B, 'keepA' : courbe
    # A, 'stop' : aucune ; fermeture : 'keep') ou decision sur la courbe A seule apres une calibration B interrompue
    # ('keep' : courbe A, 'stop' : aucune ; fermeture : 'keep'). Courbes dessinees : copies de $compare.Curves.
    # Get-FamilyCurves renvoie deja un tableau protege (operateur virgule) : pas de @() autour, sinon tableau imbrique
    # 12.8 (lot 1c, § 7 et 10.1) : lvl2 = @{ WarnText ; Info ; BrandAsk ; Brand ; Brands } (Get-LevelReviewPlan) : texte de
    # l avertissement (forme non conforme ou forme adaptee avec reserve) ; fenetre « information » (courbe adaptee et
    # verifiee : en-tete propre, « Ecrire l image » principal) ; champ de marque cmbRevBrand (« Memoriser cette forme pour
    # la marque »), lu dans $script:CalReviewBrand a la fermeture
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }   # elle dessine ces memes donnees
    if ($compare) { $script:CurveData = @($compare.Curves); $script:CurveLevel = @{}; $script:CurveZones = @($compare.Zones) }
    else {
        $script:CurveData = Get-FamilyCurves $cal.Family $cal.Slow
        Set-CurveLevelData $script:CurveData
        $script:CurveZones = @()
    }
    $ab = [bool]($compare -and $compare.Mode -eq 'ab'); $aonly = [bool]($compare -and $compare.Mode -eq 'aonly')
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmCalibReview'; $dlg.Text = (T 'Calibration precomp')
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $dlg.ShowInTaskbar = $false; $dlg.MinimizeBox = $false
    $dlg.Size = New-Object System.Drawing.Size(980, 760); $dlg.MinimumSize = New-Object System.Drawing.Size(700, 520)
    # Comparaison : texte plus long (une ligne par face, reserves, verdict), fenetre plus haute si l ecran le permet
    if ($compare) { $dlg.Size = New-Object System.Drawing.Size(980, [math]::Max(520, [math]::Min(860, [System.Windows.Forms.Screen]::FromControl($form).WorkingArea.Height - 40))) }
    $dlg.KeyPreview = $true                        # Echap : comme la croix de la fenetre
    $dlg.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $_.Handled = $true; $this.Close() } })
    $lvl = ($cal.Mode -eq 'level')
    $infoWin = [bool]($lvl2 -and $lvl2.Info -and $lvl -and -not $compare)
    # 12.8 (FIX1C, constat 7) : « verifiee » seulement si le niveau de chaque tete adaptee a ete verifie (Verified) ; sinon
    # la reserve « niveau de la courbe adaptee non verifie » de la meme fenetre est rappelee
    $head = if ($toWrite -and $lvl -and $infoWin -and $lvl2.Verified -ne $false) { (T "Écrire l'image : l'image est écrite avec la courbe adaptée à cette disquette, vérifiée par une écriture du motif.`nArrêter : l'image n'est pas écrite ; le niveau n'est pas conservé et les profils de la référence sont rétablis.") }
            elseif ($toWrite -and $lvl -and $infoWin) { (T "Écrire l'image : l'image est écrite avec la courbe adaptée à cette disquette ; son niveau a été décalé sans nouvelle écriture du motif (voir ci-dessus).`nArrêter : l'image n'est pas écrite ; le niveau n'est pas conservé et les profils de la référence sont rétablis.") }
            elseif ($toWrite -and $lvl) { (T "Écrire l'image : l'image est écrite avec le niveau mesuré.`nArrêter : l'image n'est pas écrite ; le niveau n'est pas conservé et les profils de la référence sont rétablis.") }
            elseif ($toWrite) { (T "Écrire l'image : la courbe est conservée et l'image est écrite avec elle.`nArrêter : l'image n'est pas écrite et cette calibration n'est pas conservée (la calibration précédente est rétablie).") }
            elseif ($lvl -and $noFields) { (T "Conserver le niveau : il est enregistré pour cette disquette et reste affiché dans la fenêtre Courbe ; les champs --precomp ne sont pas modifiés.`nAbandonner le niveau : il n'est pas enregistré.") }
            elseif ($lvl) { (T "Conserver le niveau : le profil décalé reste dans les champs --precomp, pour cette disquette seulement.`nAbandonner le niveau : les champs --precomp reprennent leurs valeurs d'avant la calibration rapide.") }
            else { (T "Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie.") }
    if ($offerFull) { $head += "`n" + (T "Calibration complète : la courbe du lecteur est mesurée de nouveau en test fin, après un avertissement ; elle devient la nouvelle référence de forme.") }
    # 12.7 : ligne placee apres les autres (les fins de test n impriment que les premieres lignes, ou celles qui commencent
    # par Conserver, Abandonner ou Calibration complete)
    if ($offerRedo -and -not $compare) { $head += "`n" + $(if ($toWrite) { (T "Refaire sur une autre disquette : l'écriture est annulée ; cette courbe est mise de côté, la même calibration est refaite sur une autre disquette sacrifiée, puis vous choisissez la courbe. Relancez ensuite l'écriture depuis la Bibliothèque.") } else { (T "Refaire sur une autre disquette : cette courbe est mise de côté et la calibration précédente rétablie ; la même calibration est refaite sur une autre disquette sacrifiée, puis les deux courbes sont comparées et vous choisissez celle à conserver.") }) }
    $intro = if ($infoWin) { (T 'La calibration rapide a adapté la courbe à cette disquette :') } else { (T "La calibration ne donne pas un bon résultat :") }
    $txt = $intro + "`n" + ((@($issues) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" + $head
    if ($compare) { $txt = [string]$compare.Text }
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Name = 'lblRevText'; $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $txt; $lbl.Dock = 'Top'
    $lbl.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 6); $lbl.ForeColor = $script:Theme.Warn
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $lbl.Height = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $dlg.Font, (New-Object System.Drawing.Size(930, 10000)), $tf).Height + 20
    # Comparaison (texte long) : hauteur du texte recalculee a la largeur de la fenetre (taille minimale : texte entier,
    # dessin reduit)
    if ($compare) {
        $dlg.Add_Resize({
            $l = $this.Controls['lblRevText']; if (-not $l) { return }
            $f = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
            $h = [System.Windows.Forms.TextRenderer]::MeasureText($l.Text, $l.Font, (New-Object System.Drawing.Size([math]::Max(100, $l.ClientSize.Width - 24), 10000)), $f).Height + 20
            if ($l.Height -ne $h) { $l.Height = $h }
        })
    }
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.BackColor = [System.Drawing.Color]::White
    $pb.Add_Paint({ Draw-PrecompCurve $_.Graphics $this.ClientSize })
    $pb.Add_Resize({ $this.Invalidate() })
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Bottom'; $bar.Height = 56; $bar.BackColor = $script:Theme.Page
    $bar.Width = $dlg.ClientSize.Width             # avant les boutons : leur ancrage a droite se mesure sur cette largeur
    # 12.8 (lot 1c, point 2) : avertissement au-dessus des boutons, hauteur mesuree a la largeur minimale de la fenetre ;
    # boutons places dessous ($by), barre de 78 px au moins
    $warn = ($warnKeep -and $toWrite -and $lvl -and -not $compare)
    $by = 11
    if ($warn) {
        $lblWarn = New-Object System.Windows.Forms.Label
        $lblWarn.Name = 'lblRevWarn'; $lblWarn.AutoSize = $false; $lblWarn.UseMnemonic = $false; $lblWarn.Font = $bold; $lblWarn.ForeColor = $script:Theme.WarnInk
        $lblWarn.Text = if ($lvl2 -and $lvl2.WarnText) { [string]$lvl2.WarnText } else { (T "Attention : niveau non vérifié et forme non conforme. La courbe que « Écrire l'image » utiliserait n'a pas été vérifiée sur cette disquette ; vers le centre, elle peut s'écarter de son besoin de plusieurs dizaines de ns.") }
        $wMin = [math]::Max(200, $dlg.MinimumSize.Width - ($dlg.Width - $dlg.ClientSize.Width) - 32)
        $hW = [System.Windows.Forms.TextRenderer]::MeasureText($lblWarn.Text, $bold, (New-Object System.Drawing.Size($wMin, 10000)), $tf).Height
        $lblWarn.Location = New-Object System.Drawing.Point(16, 8); $lblWarn.Size = New-Object System.Drawing.Size(($dlg.ClientSize.Width - 32), ($hW + 2)); $lblWarn.Anchor = 'Top,Left,Right'
        $bar.Controls.Add($lblWarn)
        $by = $lblWarn.Bottom + 8
        $bar.Height = [math]::Max(78, $by + 34 + 11)
    }
    # 12.8 (lot 1c, § 10.1) : fenetre « information » d une courbe adaptee et verifiee sur toutes les tetes : marque a
    # memoriser (champ libre, preremplie par la marque choisie, vide si la disquette s en ecarte), au-dessus des boutons
    $cmbBrand = $null
    if ($infoWin -and $lvl2.BrandAsk -and -not $warn) {
        $lblBrand = New-Object System.Windows.Forms.Label
        $lblBrand.Name = 'lblRevBrand'; $lblBrand.AutoSize = $true; $lblBrand.UseMnemonic = $false; $lblBrand.Text = (T 'Mémoriser cette forme pour la marque :')
        # 12.8 (FIX1C, constat 8) : police de la fenetre posee avant la mesure (la barre n est pas encore dans la fenetre :
        # sinon PreferredWidth est mesure dans la police par defaut et le libelle recouvre la liste)
        $lblBrand.Font = $dlg.Font
        $lblBrand.Location = New-Object System.Drawing.Point(16, 14)
        $bar.Controls.Add($lblBrand)
        $cmbBrand = New-Object System.Windows.Forms.ComboBox
        $cmbBrand.Name = 'cmbRevBrand'; $cmbBrand.DropDownStyle = 'DropDown'; $cmbBrand.Width = 300
        foreach ($bn in @($lvl2.Brands)) { if ($bn) { [void]$cmbBrand.Items.Add([string]$bn) } }
        $cmbBrand.Text = [string]$lvl2.Brand
        $cmbBrand.Location = New-Object System.Drawing.Point((16 + $lblBrand.PreferredWidth + 8), 10)
        $bar.Controls.Add($cmbBrand)
        if ($tip) { $tip.SetToolTip($cmbBrand, (T "Nom libre : marque, année ou lot. Une marque déjà mesurée sert de point de départ : sa forme et son niveau, mémorisés avec la référence actuelle du lecteur. La mesure reste faite sur la disquette insérée.")) }
        $by = 44
        $bar.Height = [math]::Max(78, $by + 34 + 11)
    }
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Name = 'btnRevKeep'; $btnOk.Size = New-Object System.Drawing.Size(200, 34); $btnOk.Anchor = 'Top,Right'
    $btnOk.Text = if ($ab) { (T 'Conserver la courbe B') } elseif ($aonly) { (T 'Conserver la courbe A') } elseif ($toWrite) { (T "Écrire l'image") } elseif ($lvl) { (T 'Conserver le niveau') } else { (T 'Conserver la courbe') }
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Name = 'btnRevStop'; $btnNo.Size = New-Object System.Drawing.Size(180, 34); $btnNo.Anchor = 'Top,Right'
    $btnNo.Text = if ($ab) { (T 'Abandonner les deux') } elseif ($aonly) { (T 'Abandonner la courbe') } elseif ($toWrite) { (T 'Arrêter') } elseif ($lvl) { (T 'Abandonner le niveau') } else { (T 'Abandonner la courbe') }
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    # Comparaison : style principal pour la courbe conseillee seulement (aucune mise en avant sans courbe conseillee)
    # 12.8 (lot 1c, point 2) : avertissement : « Ecrire l image » sans le style principal
    Set-Btn $btnOk $(if ($toWrite -and -not $compare) { 'Save' } else { '' }) $(if (($ab -and $compare.Pick -ne 'B') -or $warn) { 'normal' } else { 'primary' }); Set-Btn $btnNo '' 'normal'
    $btnNo.Location = New-Object System.Drawing.Point(($dlg.ClientSize.Width - 16 - $btnNo.Width), $by)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $by)
    $bar.Controls.AddRange(@($btnOk, $btnNo))
    if ($offerFull) {
        $btnFull = New-Object System.Windows.Forms.Button
        $btnFull.Name = 'btnRevFull'; $btnFull.Size = New-Object System.Drawing.Size(200, 34); $btnFull.Anchor = 'Top,Right'
        $btnFull.Text = (T 'Calibration complète'); $btnFull.DialogResult = [System.Windows.Forms.DialogResult]::Retry
        Set-Btn $btnFull '' 'normal'
        $btnFull.Location = New-Object System.Drawing.Point(($btnOk.Left - 8 - $btnFull.Width), $by)
        $bar.Controls.Add($btnFull)
    }
    # 12.7 point 2 : « Refaire sur une autre disquette » (reserve qui peut venir du support), a gauche de btnRevKeep ;
    # comparaison A / B : « Conserver la courbe A » a gauche de « Conserver la courbe B ». Largeur a la taille minimale :
    # 16 + 180 + 8 + 200 + 8 + 240 = 652 px sur environ 684 utiles
    if ($offerRedo -and -not $compare) {
        $btnRedo = New-Object System.Windows.Forms.Button
        $btnRedo.Name = 'btnRevRedo'; $btnRedo.Size = New-Object System.Drawing.Size(240, 34); $btnRedo.Anchor = 'Top,Right'
        $btnRedo.Text = (T 'Refaire sur une autre disquette'); $btnRedo.DialogResult = [System.Windows.Forms.DialogResult]::Ignore
        Set-Btn $btnRedo '' 'normal'
        $btnRedo.Location = New-Object System.Drawing.Point(($btnOk.Left - 8 - $btnRedo.Width), $by)
        $bar.Controls.Add($btnRedo)
    }
    if ($ab) {
        $btnKeepA = New-Object System.Windows.Forms.Button
        $btnKeepA.Name = 'btnRevKeepA'; $btnKeepA.Size = New-Object System.Drawing.Size(200, 34); $btnKeepA.Anchor = 'Top,Right'
        $btnKeepA.Text = (T 'Conserver la courbe A'); $btnKeepA.DialogResult = [System.Windows.Forms.DialogResult]::Yes
        Set-Btn $btnKeepA '' $(if ($compare.Pick -eq 'A') { 'primary' } else { 'normal' })
        $btnKeepA.Location = New-Object System.Drawing.Point(($btnOk.Left - 8 - $btnKeepA.Width), $by)
        $bar.Controls.Add($btnKeepA)
    }
    if ($compare) {
        # Arbitrage 3 : la fermeture de la fenetre est dite sous les boutons (courbe B deja enregistree ; decision sur A seule :
        # courbe A retablie)
        $bar.Height = 78
        $lblClose = New-Object System.Windows.Forms.Label
        $lblClose.Name = 'lblRevClose'; $lblClose.AutoSize = $false; $lblClose.UseMnemonic = $false; $lblClose.ForeColor = $script:Theme.Muted
        $lblClose.Text = if ($ab) { (T 'Fermer la fenêtre conserve la courbe B, déjà enregistrée.') } else { (T 'Fermer la fenêtre conserve la courbe A, qui est rétablie et enregistrée.') }
        $lblClose.TextAlign = 'MiddleRight'; $lblClose.Anchor = 'Top,Left,Right'
        $lblClose.Location = New-Object System.Drawing.Point(16, 50); $lblClose.Size = New-Object System.Drawing.Size(($dlg.ClientSize.Width - 32), 20)
        $bar.Controls.Add($lblClose)
    }
    $dlg.Controls.Add($pb); $dlg.Controls.Add($lbl); $dlg.Controls.Add($bar); $pb.BringToFront()
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    # 12.7 : zone de progression de l Accueil gardee pendant la decision (Update-HomeProgress, mode 'hold')
    $script:HomeProgHold = $true
    try { $dr = $dlg.ShowDialog($form); if ($cmbBrand) { $script:CalReviewBrand = [string]$cmbBrand.Text } } finally { $dlg.Dispose(); $script:HomeProgHold = $false; $script:CurveZones = @() }
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) { return 'keep' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Retry) { return 'full' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Ignore) { return 'redo' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Yes) { return 'keepA' }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Abort) { return 'stop' }
    if ($compare) { return 'keep' }
    return $(if ($toWrite) { 'stop' } else { 'keep' })
}

function Get-CalibSnapshot([string[]]$keys) {
    # Etat des courbes et profils (retabli par Restore-CalibState) : courbes des cles donnees, niveaux, profil, champs --precomp
    $s = @{ Std = $script:PrecompStd; Long = $script:PrecompLong; Curves = @{}; Levels = $script:LevelShifts.Clone()
            Prof = $cmbWProfile.SelectedIndex; On = $chkWPrecomp.Checked; P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Lbl = $lblWProfileInfo.Text }
    foreach ($k in @($keys)) { $s.Curves[$k] = $script:PrecompCurves[$k] }
    return $s
}

function Restore-CalibState($prev) {
    # Retablit les courbes et profils d avant une calibration refusee par l utilisateur
    $script:PrecompStd = $prev.Std; $script:PrecompLong = $prev.Long
    foreach ($k in @($prev.Curves.Keys)) { $script:PrecompCurves[$k] = $prev.Curves[$k] }
    if ($prev.Levels) { $script:LevelShifts = $prev.Levels }      # niveaux mesures avec la reference retablie
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    # Choix du profil et champs --precomp d avant la calibration (profil Manuel compris)
    if ($null -ne $prev.Prof -and $cmbWProfile.SelectedIndex -ne $prev.Prof) { $cmbWProfile.SelectedIndex = $prev.Prof }
    Update-PrecompForImage $txtWFile.Text
    if ($null -ne $prev.P0) { $chkWPrecomp.Checked = $prev.On; $txtWPrecomp.Text = $prev.P0; $txtWPrecomp1.Text = $prev.P1; $lblWProfileInfo.Text = $prev.Lbl }
    if (-not $script:Restore) { [void](Save-Config) }
}

function Show-TimedConfirm([string]$name, [string]$title, [string]$text, [string]$okText, [string]$okGlyph, [string]$countFmt, [string]$checkLabel, [string]$stopOn, [string]$stopOff, [int]$Seconds = -1, [switch]$NeedCheck, $Combo = $null) {
    # Fenetre d avertissement a compte a rebours : $okText / Annuler ; sans reponse, validation automatique au bout de
    # $script:CalibConfirmSeconds (0 = pas de delai), pour qu une sequence sans surveillance ne reste pas bloquee.
    # $countFmt : ligne du decompte ({0} = secondes). $checkLabel : case facultative ; la cocher ou la decocher arrete le
    # decompte (l utilisateur est present), la ligne affiche alors $stopOn ou $stopOff. Renvoie @{ Ok ; Checked ; Auto }.
    # 12.7 : Seconds : delai propre a cette fenetre (-1 : CalibConfirmSeconds ; 0 : aucun) ; NeedCheck : $okText inactif tant
    # que la case n est pas cochee (calibration B : la disquette inseree doit etre une autre disquette sacrifiee)
    $w = 560
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = $name; $dlg.Text = $title
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap(); $pic.SizeMode = 'AutoSize'; $pic.Location = New-Object System.Drawing.Point(16, 16)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $text; $lbl.Location = New-Object System.Drawing.Point(64, 16)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $h = [System.Windows.Forms.TextRenderer]::MeasureText($text, $dlg.Font, (New-Object System.Drawing.Size($w, 10000)), $tf).Height
    $lbl.Size = New-Object System.Drawing.Size($w, ($h + 4))
    $y = $lbl.Bottom + 12
    $chk = $null
    if ($checkLabel) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Name = 'chkCalSwap'; $chk.Text = $checkLabel; $chk.AutoSize = $false; $chk.UseMnemonic = $false
        $chk.CheckAlign = 'TopLeft'; $chk.TextAlign = 'TopLeft'
        $hc = [System.Windows.Forms.TextRenderer]::MeasureText($checkLabel, $dlg.Font, (New-Object System.Drawing.Size(($w - 24), 10000)), $tf).Height
        $chk.Size = New-Object System.Drawing.Size($w, [math]::Max(24, ($hc + 6))); $chk.Location = New-Object System.Drawing.Point(64, $y)
        $y = $chk.Bottom + 8
    }
    # 12.8 (lot 1c, § 10.1) : liste modifiable facultative ($Combo = @{ Label ; Items ; Text ; Tip }) : marque de la
    # disquette inseree (cmbCalBrand) ; saisir ou choisir arrete le compte a rebours, comme la case
    $cmb = $null; $lblCmb = $null
    if ($Combo) {
        $lblCmb = New-Object System.Windows.Forms.Label
        $lblCmb.Name = 'lblCalBrand'; $lblCmb.AutoSize = $true; $lblCmb.UseMnemonic = $false; $lblCmb.Text = [string]$Combo.Label
        # 12.8 (FIX1C, constat 8) : police de la fenetre posee avant la mesure de PreferredWidth (libelle ajoute plus tard)
        $lblCmb.Font = $dlg.Font
        $lblCmb.Location = New-Object System.Drawing.Point(64, ($y + 4))
        $cmb = New-Object System.Windows.Forms.ComboBox
        $cmb.Name = 'cmbCalBrand'; $cmb.DropDownStyle = 'DropDown'
        foreach ($it in @($Combo.Items)) { if ($it) { [void]$cmb.Items.Add([string]$it) } }
        $cmb.Text = [string]$Combo.Text
        $lx = 64 + $lblCmb.PreferredWidth + 8
        $cmb.Location = New-Object System.Drawing.Point($lx, $y); $cmb.Width = [math]::Max(160, 64 + $w - $lx)
        if ($Combo.Tip -and $tip) { $tip.SetToolTip($cmb, [string]$Combo.Tip) }
        $y = $cmb.Bottom + 10
    }
    $lblCount = New-Object System.Windows.Forms.Label
    $lblCount.Name = 'lblCalCount'; $lblCount.AutoSize = $false; $lblCount.Font = $bold
    $lblCount.Location = New-Object System.Drawing.Point(64, $y); $lblCount.ForeColor = $script:Theme.Warn
    $hCount = 22
    foreach ($s in @(($countFmt -f '999'), $stopOn, $stopOff)) {
        if (-not $s) { continue }
        $lblCount.Text = $s
        $hCount = [math]::Max($hCount, $lblCount.GetPreferredSize((New-Object System.Drawing.Size($w, 0))).Height)
    }
    $lblCount.Text = ''
    $lblCount.Size = New-Object System.Drawing.Size($w, $hCount)
    $y = $lblCount.Bottom + 10
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Name = 'btnCalOk'; $btnOk.Text = $okText; $btnOk.Size = New-Object System.Drawing.Size(200, 34)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Name = 'btnCalCancel'; $btnNo.Text = (T 'Annuler'); $btnNo.Size = New-Object System.Drawing.Size(110, 34)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnOk $okGlyph 'primary'; Set-Btn $btnNo '' 'normal'
    $btnNo.Location = New-Object System.Drawing.Point((64 + $w - $btnNo.Width), $y)
    $btnOk.Location = New-Object System.Drawing.Point(($btnNo.Left - 8 - $btnOk.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size((64 + $w + 16), ($y + $btnOk.Height + 16))
    $dlg.AcceptButton = $btnOk; $dlg.CancelButton = $btnNo
    $dlg.Controls.AddRange(@($pic, $lbl, $lblCount, $btnOk, $btnNo))
    if ($chk) { $dlg.Controls.Add($chk) }
    if ($cmb) { $dlg.Controls.Add($lblCmb); $dlg.Controls.Add($cmb) }
    $sec = if ($Seconds -ge 0) { $Seconds } else { [int]$script:CalibConfirmSeconds }
    $script:CalConfirm = @{ Left = $sec; Auto = $false; Dlg = $dlg; Count = $lblCount; Tmr = $null; Fmt = $countFmt; StopOn = $stopOn; StopOff = $stopOff }
    # Bouton inactif : fond gris (le style principal, plat, ne grise que le texte)
    if ($NeedCheck -and $chk) {
        $btnOk.Enabled = $false; $btnOk.BackColor = [System.Drawing.Color]::FromArgb(176, 186, 200); $script:CalConfirm.OkBtn = $btnOk
        $chk.Add_CheckedChanged({ $c = $script:CalConfirm; if ($c -and $c.OkBtn) { $c.OkBtn.Enabled = $this.Checked; $c.OkBtn.BackColor = $(if ($this.Checked) { $script:Theme.Accent } else { [System.Drawing.Color]::FromArgb(176, 186, 200) }) } })
    }
    if ($NeedCheck -and $sec -le 0 -and $stopOff) { $lblCount.Text = $stopOff }
    $tmr = $null
    if ($sec -gt 0) {
        $lblCount.Text = ($countFmt -f "$sec")
        $tmr = New-Object System.Windows.Forms.Timer
        $tmr.Interval = 1000
        $script:CalConfirm.Tmr = $tmr
        $tmr.Add_Tick({
            $c = $script:CalConfirm
            if (-not $c) { return }
            $c.Left--
            if ($c.Left -le 0) { $c.Auto = $true; $c.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK; return }
            $c.Count.Text = ($c.Fmt -f "$($c.Left)")
        })
    }
    if ($chk -and $tmr) {
        $chk.Add_CheckedChanged({
            $c = $script:CalConfirm
            if (-not $c) { return }
            if ($c.Tmr) { $c.Tmr.Stop() }
            $c.Count.Text = if ($this.Checked) { $c.StopOn } else { $c.StopOff }
        })
    }
    if ($cmb -and $tmr) {
        # Gestionnaires poses apres le texte initial : seule une saisie ou un choix de l utilisateur arrete le decompte
        $script:CalConfirm.Chk = $chk
        $stopCmb = {
            $c = $script:CalConfirm
            if (-not $c -or -not $c.Tmr -or -not $c.Tmr.Enabled) { return }
            $c.Tmr.Stop()
            $c.Count.Text = if ($c.Chk -and $c.Chk.Checked) { $c.StopOn } else { $c.StopOff }
        }
        $cmb.Add_TextUpdate($stopCmb); $cmb.Add_SelectionChangeCommitted($stopCmb)
    }
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    if ($tmr) { $tmr.Start() }
    try { $dr = $dlg.ShowDialog($form) }
    finally { if ($tmr) { $tmr.Stop(); $tmr.Dispose() } }
    $res = @{ Ok = ($dr -eq [System.Windows.Forms.DialogResult]::OK); Checked = [bool]($chk -and $chk.Checked); Auto = [bool]$script:CalConfirm.Auto; ComboText = $(if ($cmb) { [string]$cmb.Text } else { $null }) }
    $script:CalConfirm = $null
    $dlg.Dispose()
    return $res
}

function Show-CalibConfirm([string]$text, [string]$swapLabel, $brand = $null) {
    # Avertissement avant une calibration : la disquette inseree recoit le motif de test a chaque passe, ce qui use le
    # support. $swapLabel : case « disquette sacrifiee » (la disquette a ecrire est redemandee apres la calibration),
    # absente pour une calibration seule. 12.8 (lot 1c) : $brand = @{ Label ; Items ; Text ; Tip } : champ de la marque
    # de la disquette (calibration rapide). Renvoie @{ Ok ; Swap ; Auto ; Brand }.
    $r = Show-TimedConfirm 'frmCalibConfirm' (T 'Calibration precomp') $text (T 'Lancer la calibration') 'Diagnostic' (T "Sans réponse, la calibration démarre automatiquement dans {0} s.") $swapLabel (T "Compte à rebours arrêté : insérez la disquette sacrifiée, puis cliquez sur « Lancer la calibration ».") (T "Compte à rebours arrêté : cliquez sur « Lancer la calibration » pour calibrer avec la disquette insérée.") -Combo $brand
    return @{ Ok = $r.Ok; Swap = $r.Checked; Auto = $r.Auto; Brand = $r.ComboText }
}

function Show-CalibSurface($opt, [string]$text) {
    # Controle de surface : disquette de calibration douteuse a la premiere passe (Invoke-CalibAnalysis). Pas de compte a
    # rebours ni de decision automatique : la disquette inseree est peut-etre celle a ecrire. Fermeture (croix, Echap) :
    # Arreter. Renvoie @{ Choice = 'change' | 'continue' | 'stop' ; Swap }. 12.7 point 5 : $opt.Title, $opt.GoText (titre
    # et bouton « Continuer » de la variante 'level' : « Disquette a ecrire defectueuse », « Ecrire quand meme »)
    $w = 600
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmCalibSurface'; $dlg.Text = $(if ($opt.Title) { [string]$opt.Title } else { (T 'Contrôle de surface') })
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap(); $pic.SizeMode = 'AutoSize'; $pic.Location = New-Object System.Drawing.Point(16, 16)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Name = 'lblSurfText'; $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $text; $lbl.Location = New-Object System.Drawing.Point(64, 16)
    $lbl.Size = New-Object System.Drawing.Size($w, ([System.Windows.Forms.TextRenderer]::MeasureText($text, $dlg.Font, (New-Object System.Drawing.Size($w, 10000)), $tf).Height + 4))
    $dlg.Controls.AddRange(@($pic, $lbl))
    $y = $lbl.Bottom + 12
    $chkNew = $null; $chkSwap = $null
    if ($opt.Change) {
        $chkNew = New-Object System.Windows.Forms.CheckBox
        $chkNew.Name = 'chkSurfNew'; $chkNew.Text = (T "J'ai inséré une autre disquette"); $chkNew.AutoSize = $true; $chkNew.UseMnemonic = $false
        $chkNew.Location = New-Object System.Drawing.Point(64, $y); $dlg.Controls.Add($chkNew); $y += 28
        if ($opt.SwapBox) {
            $sl = (T "J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration") -f (T 'la disquette à écrire')
            $chkSwap = New-Object System.Windows.Forms.CheckBox
            $chkSwap.Name = 'chkSurfSwap'; $chkSwap.Text = $sl; $chkSwap.AutoSize = $false; $chkSwap.UseMnemonic = $false; $chkSwap.Enabled = $false
            $chkSwap.CheckAlign = 'TopLeft'; $chkSwap.TextAlign = 'TopLeft'
            $hs = [System.Windows.Forms.TextRenderer]::MeasureText($sl, $dlg.Font, (New-Object System.Drawing.Size(($w - 44), 10000)), $tf).Height
            $chkSwap.Size = New-Object System.Drawing.Size(($w - 20), [math]::Max(24, ($hs + 6))); $chkSwap.Location = New-Object System.Drawing.Point(84, $y)
            $dlg.Controls.Add($chkSwap); $y = $chkSwap.Bottom + 4
        }
        $y += 6
    }
    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Name = 'btnSurfStop'; $btnStop.Text = (T 'Arrêter'); $btnStop.Size = New-Object System.Drawing.Size(110, 34); $btnStop.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Name = 'btnSurfContinue'; $btnGo.Text = $(if ($opt.GoText) { [string]$opt.GoText } else { (T 'Continuer') }); $btnGo.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnGo.Size = New-Object System.Drawing.Size([math]::Max(130, [System.Windows.Forms.TextRenderer]::MeasureText($btnGo.Text, $dlg.Font).Width + 36), 34)
    Set-Btn $btnStop '' 'normal'; Set-Btn $btnGo '' 'normal'
    $btnStop.Location = New-Object System.Drawing.Point((64 + $w - $btnStop.Width), $y)
    $btnGo.Location = New-Object System.Drawing.Point(($btnStop.Left - 8 - $btnGo.Width), $y)
    $dlg.Controls.AddRange(@($btnGo, $btnStop))
    if ($opt.Change) {
        $btnCh = New-Object System.Windows.Forms.Button
        $btnCh.Name = 'btnSurfChange'; $btnCh.Text = (T 'Changer de disquette'); $btnCh.Size = New-Object System.Drawing.Size(200, 34)
        $btnCh.DialogResult = [System.Windows.Forms.DialogResult]::Retry; $btnCh.Enabled = $false
        Set-Btn $btnCh '' 'normal'
        $btnCh.Location = New-Object System.Drawing.Point(($btnGo.Left - 8 - $btnCh.Width), $y)
        $dlg.Controls.Add($btnCh)
        $chkNew.Add_CheckedChanged({
            $f = $this.FindForm()
            $b = $f.Controls.Find('btnSurfChange', $true); if ($b.Count) { $b[0].Enabled = $this.Checked }
            $s = $f.Controls.Find('chkSurfSwap', $true); if ($s.Count) { $s[0].Enabled = $this.Checked; if (-not $this.Checked) { $s[0].Checked = $false } }
        })
    }
    $dlg.ClientSize = New-Object System.Drawing.Size((64 + $w + 16), ($y + 34 + 16))
    $dlg.CancelButton = $btnStop                   # Echap : Arreter ; croix : DialogResult Cancel, traite comme Arreter
    $dlg.Add_Shown({ $this.Activate(); $b = $this.Controls.Find('btnSurfStop', $true); if ($b.Count) { $this.ActiveControl = $b[0] }; try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    $swap = $false
    # Image de l icone (ToBitmap) liberee avec la fenetre : PictureBox.Dispose ne libere pas son Image
    $img = $pic.Image
    try { $dr = $dlg.ShowDialog($form); $swap = [bool]($chkSwap -and $chkSwap.Checked) } finally { $dlg.Dispose(); if ($img) { $img.Dispose() } }
    if ($dr -eq [System.Windows.Forms.DialogResult]::Retry) { return @{ Choice = 'change'; Swap = $swap } }
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) { return @{ Choice = 'continue'; Swap = $false } }
    return @{ Choice = 'stop'; Swap = $false }
}
