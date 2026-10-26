# ============================== FONCTIONS : CALIBRATION : MESURE, DERIVE, REPRISE ===

function New-CalibUnit($head) {
    # Unite de calibration : les deux tetes ensemble (Head = $null, profil commun) ou une seule tete (ecriture lente).
    # 12.7 : Face (tete -> cylindre -> mesures des passes de mesure, sans effet sur la courbe) ; OneFace ('c|tete' : cylindre
    # de la courbe commune mesure sans cette face a une passe au moins)
    $prefix = if ($null -eq $head) { '' } else { ((T '[tête {0}] ') -f "$head") }
    return @{ Head = $head; Prefix = $prefix; Results = @{}; Est = @{}; Sig = @{}; Kind = @{}; Bracket = @{}; Warn = $null; Fit = $null; Slope = $null; Profile = ''; Verify = @{}
              Dense = @{}; VerifyList = $null; VerifyP = @{}; Outliers = @(); Own = @{}; Trend = @{}; VerifyPrev = @{}; Witness = @(); ReadLast = @{}; Writes = @{}; WitCand = 0; WitMin = 0
              EstPass = @{}; Face = @{}; OneFace = @{} }
}

function Get-PatternBits([string]$family, [string]$img) {
    # Cellules par piste du motif de test (voir New-CalibPattern) : densite de l image ; la calibration rapide compare
    # celle de l image a celle de sa reference
    $bits = 100000; $src = (T 'format à secteurs, 2 us par cellule')
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    try {
        switch ($ext) {
            '.adf' {
                $len = (Get-Item -LiteralPath $img).Length
                if ($len % 22528 -eq 0 -and $len / 11264 -gt 84) { $bits = 202688; $src = (T 'ADF haute densité, horloge AmigaDOS de gw') }
                else { $bits = 101344; $src = (T 'ADF, horloge AmigaDOS de gw') }
            }
            '.ipf' { $info = Get-IpfCellInfo $img; if ($info.Bits -ge 50000 -and $info.Bits -le 260000) { $bits = [int]$info.Bits; $src = (T 'IPF, bits par piste de l''image') } }
            '.hfe' { $info = Get-HfeCellInfo $img; if ($info.Bits -ge 50000 -and $info.Bits -le 260000) { $bits = [int]$info.Bits; $src = (T 'HFE, bits par piste de l''image') } }
        }
    } catch { }
    if ($family -eq 'long' -and $bits -eq 100000) { $bits = 105820; $src = (T 'long track, 1,89 us par cellule') }
    elseif ($family -eq 'hd' -and $bits -eq 100000) { $bits = 200000; $src = (T 'format à secteurs haute densité, 1 us par cellule') }   # 12.7
    $bits -= $bits % 16
    return @{ Bits = $bits; Source = $src }
}

function New-CalibPattern([string]$family, [string]$img, [int]$nCyl, [int]$Rpm = 300) {
    # Motif de test independant du contenu de l image : HFE de donnees pseudo-aleatoires codees MFM (graine fixe, contenu
    # reproductible) a la DENSITE de l image. gw cale chaque piste ecrite sur un tour du lecteur (write.py, facteur
    # drive_ticks_per_rev / ticks_to_index) : la densite ne depend que du nombre de cellules par piste.
    #  ADF : celui du codec AmigaDOS de gw, horloge 14/7 093 790 s, (int(0,2 / horloge) + 31) & ~31 = 101 344 cellules
    #        (1 973,5 ns) en DD, 202 688 en HD ;
    #  IPF et HFE : bits par piste de l image (mediane ; HFE v3 : 400 x debit) ;
    #  autres formats a secteurs (IMG, ST...) : 100 000 cellules de 2 us ; long track illisible : 1,89 us ; haute densite
    #  (12.7) : 200 000 cellules de 1 us.
    # Rpm : vitesse du type de disquette (300 tr/min pour toutes les familles calibrees en 12.7) : debit de l en-tete HFE,
    # bits x tr/min / 120 000 (regle generale), et cellule d un tour.
    # Une piste pauvre en motifs (secteurs vides) reduit la mesure du decalage de pic a quelques dizaines d occurrences
    # (en-tetes, syncs) : resultat plus bruite et biaise de quelques ns (jusqu a ~15 ns en simulation). Ici toutes les
    # pistes ont la meme richesse de motifs : calibration reproductible, independante de l image.
    $pb = Get-PatternBits $family $img
    $bits = $pb.Bits; $src = $pb.Source
    # Debit de l en-tete HFE (kbit/s) : un tour a Rpm tr/min ; 300 tr/min : expression d origine
    $rate = if ($Rpm -eq 300) { [int][math]::Round($bits / 400.0) } else { [int][math]::Round($bits * $Rpm / 120000.0) }
    $path = Join-Path $script:TempDir 'precomp-pattern.hfe'
    [CalibPattern]::WriteHfe($path, $nCyl, $bits, $rate, 20261014)
    $cell = if ($Rpm -eq 300) { 200000000.0 / $bits } else { (60000000000.0 / $Rpm) / $bits }
    return @{ Path = $path; Bits = $bits; Rate = $rate; CellNs = $cell; Source = $src; Rpm = $Rpm }
}

function Get-CalibDriveArgs {
    # Options de lecteur de l ecriture reprises par la calibration, sans --format ni --diskdefs : le motif est un HFE
    return @(Get-WriteFormatArgs | Where-Object { $_ -notmatch '^--(format|diskdefs)=' })
}

function Get-CurveKeyLabel([string]$key) {
    # 'std' -> « Standard 2 us (commune) », 'long_h1' -> « Long track 1,89 us (tête 1) »
    $fam = if ($key -like 'hd*') { 'hd' } elseif ($key -like 'long*') { 'long' } else { 'std' }
    $kind = if ($key -match '_h(\d)$') { (T "tête {0}") -f "$($Matches[1])" } else { (T 'commune') }
    return ("{0} ({1})" -f (Get-CalibFamilyName $fam), $kind)
}

function Resolve-OldCalibrations {
    # Calibrations d un autre calcul (Load-Config) : conserver ou recalibrer. Fermeture de la fenetre : decision remise au
    # prochain demarrage, calibrations gardees dans la configuration mais non utilisees d ici la.
    $o = $script:OldCalib
    if (-not $o) { return }
    $items = @(@($o.Curves.Keys) | ForEach-Object { $cv = $o.Curves[$_]; (T "{0} : calcul {1}, lecteur {2}, {3}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $cv -Plain), "$($cv.Drive)", "$($cv.Date)" })
    $txt = ((T "Ces calibrations ont été faites avec un autre calcul de calibration que le calcul actuel (v{0}) :") -f "$($script:CalibCalc)") + "`n" + ((@($items) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" +
           (T "Recalibrer (conseillé) : ces calibrations sont abandonnées et le lecteur reprend ses profils d'origine. Recalibrez-le depuis la carte « Calibrer le lecteur » de l'Accueil, sur une disquette sacrifiée ; d'ici là, en « Test rapide », l'écriture d'une image calibrable est refusée.`nConserver ces courbes : elles restent utilisées telles quelles ; la fenêtre Courbe et le journal rappellent leur calcul. Le calcul ayant changé, une nouvelle calibration peut donner une courbe plus juste. Une courbe antérieure à la 12.3 ne peut pas servir de référence au test rapide (pente et densité non enregistrées).`nFermer la fenêtre (ou Échap) : décision au prochain démarrage ; d'ici là, ces calibrations ne sont pas utilisées.")
    # Courbe a la borne de son calcul : conservee, elle y reste (le calcul actuel admet des valeurs plus hautes)
    $atMax = @(@($o.Curves.Keys) | Where-Object { Test-CurveAtMax $o.Curves[$_] })
    foreach ($mx in @($atMax | ForEach-Object { Get-CurveMaxNs $o.Curves[$_] } | Where-Object { $_ -lt $script:CalHardNs } | Sort-Object -Unique)) {
        $kl = @($atMax | Where-Object { (Get-CurveMaxNs $o.Curves[$_]) -eq $mx } | ForEach-Object { Get-CurveKeyLabel $_ })
        $ct = if ($kl.Count -gt 1) { (T "Courbes au plafond de {0} ns de leur calcul : {1}. Conservées, elles y restent ; le calcul actuel va jusqu'à {2} ns.") } else { (T "Courbe au plafond de {0} ns de son calcul : {1}. Conservée, elle y reste ; le calcul actuel va jusqu'à {2} ns.") }
        $txt += "`n`n" + ($ct -f "$mx", ($kl -join ', '), "$($script:CalHardNs)")
    }
    if ($o.Bak -and (Test-Path -LiteralPath $o.Bak)) { $txt += "`n`n" + ((T "Copie de la configuration d'avant ce choix : {0}") -f "$([System.IO.Path]::GetFileName([string]$o.Bak))") }
    # 12.8 (lot 5, A4 R1 a R8, modele frmClean) : bandeau (texte lblOldText, Label de premier niveau), boutons a la largeur
    # de leur texte, « Fermer » (decision remise, comme la croix) en CancelButton et focus initial, aucun AcceptButton :
    # Entree n abandonne plus les courbes ; images liberees (Clear-DlgGdi) ; ajustement aux petits ecrans (Set-DlgFit)
    $W = 700
    $gdi = New-Object System.Collections.Generic.List[object]
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmOldCalib'; $dlg.Text = (T 'Calibrations d''un autre calcul'); $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false; $dlg.BackColor = [System.Drawing.Color]::White
    $ban = New-DlgBanner $dlg 16 $W (T 'Recalibrer ou conserver ces courbes ?') $txt 'warn' (New-DlgPicto 'curve') $gdi 'lblOldText'
    $y = $ban.Bottom + 14
    $btnCl = New-Object System.Windows.Forms.Button
    $btnCl.Name = 'btnOldClose'; $btnCl.Text = (T 'Fermer'); $btnCl.Size = New-Object System.Drawing.Size(110, 34); $btnCl.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnRedo = New-Object System.Windows.Forms.Button
    $btnRedo.Name = 'btnOldRedo'; $btnRedo.Text = (T 'Recalibrer (conseillé)'); $btnRedo.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $btnRedo.Text 'Diagnostic' 170), 34)
    $btnRedo.DialogResult = [System.Windows.Forms.DialogResult]::Abort
    $btnKeep = New-Object System.Windows.Forms.Button
    $btnKeep.Name = 'btnOldKeep'; $btnKeep.Text = (T 'Conserver ces courbes'); $btnKeep.Size = New-Object System.Drawing.Size((Get-DlgButtonWidth $btnKeep.Text '' 150), 34)
    $btnKeep.DialogResult = [System.Windows.Forms.DialogResult]::OK
    Set-Btn $btnRedo 'Diagnostic' 'primary'; Set-Btn $btnKeep '' 'normal'; Set-Btn $btnCl '' 'normal'
    $btnCl.Location = New-Object System.Drawing.Point((16 + $W - $btnCl.Width), $y)
    $btnRedo.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnRedo.Width), $y)
    $btnKeep.Location = New-Object System.Drawing.Point(($btnRedo.Left - 8 - $btnKeep.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + 34 + 16))
    $dlg.Controls.AddRange(@($btnKeep, $btnRedo, $btnCl))
    $dlg.CancelButton = $btnCl; $dlg.ActiveControl = $btnCl   # Echap, croix et Fermer : decision remise ; Entree : Fermer
    [void](Set-DlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))
    $dlg.Add_Shown({ $this.Activate(); try { [System.Media.SystemSounds]::Exclamation.Play() } catch { } })
    try { $dr = $dlg.ShowDialog($form) } finally { Clear-DlgGdi $dlg $gdi }
    $list = (@($o.Curves.Keys | ForEach-Object { (T "{0}, calcul {1}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $o.Curves[$_] -Plain) })) -join ' ; '
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        # Conservees pour le calcul actuel : reprises sans question aux demarrages suivants, calcul rappele a l usage
        foreach ($k in @($o.Curves.Keys)) { $cv = $o.Curves[$k]; $cv.KeptFor = (Get-CurveCalcRef $cv); $script:PrecompCurves[$k] = $cv }
        if ($o.Std) { $script:PrecompStd = $o.Std }
        if ($o.Long) { $script:PrecompLong = $o.Long }
        foreach ($k in @($o.Levels.Keys)) { $script:LevelShifts[$k] = $o.Levels[$k] }
        $script:OldCalib = $null
        if ($cmbWProfile.Text -ne (T 'Manuel')) {
            # Champs enregistres (faits avec ces courbes), puis recalcules pour l image choisie le cas echeant
            if ($null -ne $o.P0) { $txtWPrecomp.Text = $o.P0; $txtWPrecomp1.Text = $o.P1 }
            if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text }
        }
        Append-Log ((T "Calibrations d'un autre calcul conservées à votre demande : {0}. Elles sont utilisées telles quelles (calcul actuel v{1}).") -f "$list", "$($script:CalibCalc)")
    } elseif ($dr -eq [System.Windows.Forms.DialogResult]::Abort) {
        $script:OldCalib = $null
        Append-Log ((T "Calibrations d'un autre calcul abandonnées : {0}. Courbes et profils calibrés remis aux valeurs d'origine ; recalibrez le lecteur depuis la carte « Calibrer le lecteur » de l'Accueil (en « Test rapide », l'écriture d'une image calibrable est refusée d'ici là).") -f "$list")
    } else {
        Append-Log (T 'Calibrations d''un autre calcul : décision remise au prochain démarrage ; elles ne sont pas utilisées d''ici là.')
        return
    }
    Update-CurveButton $txtWFile.Text
    [void](Save-Config)
}

function Reset-CalibProfiles {
    # Efface toutes les calibrations : courbes communes et par tete de toutes les familles (haute densite comprise, 12.7) ;
    # profils de famille remis aux valeurs d origine. Refuse pendant une operation (calibration, ecriture, controle, sequence en cours) ;
    # 12.8 (D20) : Get-AppBusy, donc aussi pendant une detection des lecteurs, un prechauffage ou la mesure continue
    if (Get-AppBusy) {
        [void](Show-AppMessage (T 'Opération en cours : attendre la fin de la calibration ou de l''écriture.') (T 'Effacer les calibrations') 'OK' 'Warning'); return
    }
    $curves = @($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] })
    # Calibrations d un autre calcul en attente du choix : effacees aussi
    $pend = @(if ($script:OldCalib) { @($script:OldCalib.Curves.Keys | Where-Object { -not $script:PrecompCurves[$_] }) })
    $curves = @(@($curves) + $pend | Sort-Object -Unique)
    $changed = ($script:PrecompStd -ne $script:PrecompStdDefault) -or ($script:PrecompLong -ne $script:PrecompLongDefault)
    # 12.8.1 (spec-1281 § B.5, decision du 25/10/2026) : facteurs mesures des lecteurs (mesure de la disquette sur l image)
    # effaces avec les calibrations ; la correction « lecteur cible » ($script:TargetCorr), reglee a la main, est gardee
    $nCm = @(@($script:ContentMeasures) | Where-Object { $_ }).Count
    if ($curves.Count -eq 0 -and -not $changed -and $nCm -eq 0) {
        [void](Show-AppMessage (T 'Aucune calibration enregistrée : les profils sont déjà ceux d''origine.') (T 'Effacer les calibrations') 'OK' 'Information'); return
    }
    $list = if ($curves.Count -gt 0) { (@($curves | ForEach-Object { Get-CurveKeyLabel $_ }) -join ', ') } else { (T 'aucune') }
    # 12.8 (L6-TEXTES) : texte aligne sur le comportement reel. Copie de la configuration (Backup-ConfigBeforeRef, seulement
    # s il y a une courbe) ; ensuite : Bibliotheque au test standard ou fin, calibration automatique (Start-PresetWrite) ;
    # bouton ECRIRE, jamais de calibration (Start-WriteTabWrite) ; test rapide, ecriture refusee sans reference
    # (Start-LevelBeforeWrite) ; restauration secteur en double densite, calibration par tete en test fin (Start-RestoreWrite)
    $msg = (T "Effacer toutes les calibrations de précompensation ?`n`nCourbes : {0}.`nProfils de famille remis aux valeurs d'origine : standard {1}, long track {2}.`nLes niveaux de la calibration rapide et la mémoire par marque sont effacés aussi.") -f "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)"
    if ($curves.Count -gt 0) { $msg += "`n`n" + ((T "L'application ne peut pas annuler cet effacement. Elle copie d'abord la configuration dans « {0}.ref-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {0} ».") -f [System.IO.Path]::GetFileName([string]$script:ConfigFile)) }
    $msg += "`n`n" + (T "Ensuite, le mode Auto applique les profils d'origine :`n- « Test standard » ou « Test fin » : « Écriture rapide » et « Écriture lente » de la Bibliothèque calibrent d'abord le lecteur ; « ÉCRIRE LA DISQUETTE » écrit sans calibrer ;`n- « Test rapide » : l'écriture d'une image calibrable en double densité est refusée sans nouvelle calibration complète du lecteur, à faire sur une disquette sacrifiée depuis la carte « Calibrer le lecteur » de l'Accueil ;`n- restauration d'une copie secteur par secteur en double densité : chaque tête est d'abord calibrée en test fin.")
    # 12.7 : courbe haute densite effacee : profil d origine haute densite, jamais de calibration automatique
    if (@($curves | Where-Object { "$_" -like 'hd*' }).Count -gt 0) { $msg += "`n" + ((T "Haute densité : profil d'origine {0}, sans calibration automatique ; recalibrez depuis la carte « Calibrer le lecteur » de l'Accueil.") -f "$($script:PrecompHdDefault)") }
    if ($nCm -gt 0) { $msg += "`n" + ((T "Les {0} facteur(s) mesuré(s) des lecteurs (mesure de la disquette sur l'image) sont effacés aussi : les écritures suivantes reprennent le facteur 1 jusqu'à une nouvelle mesure. La correction « lecteur cible » est gardée.") -f "$nCm") }
    # 12.7 : boite par Show-AppMessage (code modifie), comme les autres messages de la 12.7
    $r = Show-AppMessage $msg (T 'Effacer les calibrations') 'YesNo' 'Warning'
    if ($r -ne 'Yes') { return }
    # 12.8 (lot 1c, point 4) : copie du fichier de configuration avant l effacement des courbes (sans courbe : rien)
    [void](Backup-ConfigBeforeRef @($curves) 'reset')
    foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = $null }
    $script:LevelShifts = @{}; $script:OldCalib = $null
    # 12.8 (lot 1c, § 10.5) : memoires par marque effacees avec les calibrations (apres la copie ci-dessus)
    $script:LevelBrands = @()
    $script:ContentMeasures = @()                                     # 12.8.1 : facteurs mesures ; Dk garde
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    Update-PrecompForImage $txtWFile.Text
    $pbWCal.Visible = $false; $lblWCal.Visible = $true; $lblWCal.Text = (T 'Calibrations effacées.')
    Append-Log ((T "Calibrations effacées : {0} courbe(s) ({1}) ; profils standard et long track remis aux valeurs d'origine ({2} ; {3}).") -f "$($curves.Count)", "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)")
    if ($nCm -gt 0) { Append-Log ((T "Facteurs mesurés des lecteurs effacés avec les calibrations ({0}) ; la correction « lecteur cible » est gardée.") -f "$nCm") }
    [void](Save-Config)
}

function Get-CalibTrackMeasure($st) {
    # Decalage de pic d une piste (moyenne des tours mesurables) et son erreur-type (ns) ; $null si aucun tour mesurable.
    # Erreur-type : celle d Analyze (dispersion dans les quatre contextes) combinee sur les tours, a defaut la
    # dispersion entre tours.
    $vals = @(); $ses = @()
    foreach ($x in @($st)) {
        if ($null -eq $x -or $null -eq $x.Shift -or [double]::IsNaN([double]$x.Shift)) { continue }
        $vals += [double]$x.Shift
        $se = $x.ShiftSE
        if ($null -ne $se -and -not [double]::IsNaN([double]$se) -and [double]$se -gt 0) { $ses += [double]$se }
    }
    if ($vals.Count -eq 0) { return $null }
    $m = ($vals | Measure-Object -Average).Average
    $se = [double]::NaN
    if ($ses.Count -eq $vals.Count) { $q = 0.0; foreach ($s in $ses) { $q += $s * $s }; $se = [math]::Sqrt($q) / $vals.Count }
    elseif ($vals.Count -ge 2) { $q = 0.0; foreach ($v in $vals) { $q += ($v - $m) * ($v - $m) }; $se = [math]::Sqrt($q / ($vals.Count - 1)) / [math]::Sqrt($vals.Count) }
    return @{ Shift = $m; SE = $se }
}

function Add-CalibPoint($points, [int]$x, $m) {
    # Mesure (Shift, SE, Score) a la precomp x pour un cylindre ; deux mesures a la meme valeur sont moyennees
    if ($points.ContainsKey($x)) {
        $o = $points[$x]
        $se = if (-not [double]::IsNaN([double]$o.SE) -and -not [double]::IsNaN([double]$m.SE)) { [math]::Sqrt($o.SE * $o.SE + $m.SE * $m.SE) / 2 } else { [double]::NaN }
        $points[$x] = @{ Shift = ($o.Shift + $m.Shift) / 2; SE = $se; Score = $m.Score }
    } else { $points[$x] = $m }
}

function Limit-CalibZero([double]$x0, [double]$sig, [string]$kind, [double]$a, [bool]$own) {
    # Zero borne a 0..CalHardNs (« plafonnee » au-dela). Au-dela du plafond des passes de mesure (CalMaxNs), il garde son
    # type (encadre ou extrapole) : la verification ecrit la courbe a cette valeur et la mesure.
    $k = $kind; $v = $x0
    if ($v -lt 0) { $v = 0.0; $k = 'cap' }
    if ($v -gt $script:CalHardNs) { $v = [double]$script:CalHardNs; $k = 'cap' }
    return @{ Est = $v; Sig = [math]::Min($script:CalSigMax, [math]::Max(1.0, $sig)); Kind = $k; Slope = $a; Own = $own }
}

function Get-CalibZero($points, [double]$pooledSlope) {
    # Precomp qui annule le decalage d un cylindre, d apres ses mesures (precomp -> Shift, SE) :
    #  - encadree : deux mesures de signes opposes -> interpolation lineaire entre elles (pente locale) ;
    #  - sinon extrapolee depuis les deux mesures les plus proches du zero (pente locale, ou pente commune si elle
    #    n est pas nettement negative) : la pente s aplatit au-dela de la plage mesuree, d ou une incertitude
    #    elargie de 25 % de la distance extrapolee ; si la mesure la plus proche est deja sur le zero (decalage dans
    #    2 erreurs-types), le zero est mesure et non extrapole : « encadree », sans l incertitude minimale de 5 ns ;
    #  - bornee a 0..CalHardNs : « plafonnee » (Limit-CalibZero).
    # Renvoie @{ Est; Sig; Kind = interp|extrap|cap; Slope; Own } ou $null (moins de deux mesures).
    $xs = @($points.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($xs.Count -lt 2) { return $null }
    $s = @($xs | ForEach-Object { [double]$points[$_].Shift })
    $e = @($xs | ForEach-Object { $v = $points[$_].SE; if ($null -eq $v -or [double]::IsNaN([double]$v) -or [double]$v -le 0) { 2.0 } else { [double]$v } })
    for ($i = 0; $i -lt $xs.Count - 1; $i++) {
        if ($s[$i] -gt 0 -and $s[$i + 1] -le 0) {
            $a = ($s[$i + 1] - $s[$i]) / ($xs[$i + 1] - $xs[$i])
            $x0 = $xs[$i] + $s[$i] / (-$a)
            $sig = [math]::Sqrt($e[$i] * $e[$i] + $e[$i + 1] * $e[$i + 1]) / [math]::Abs($a)
            return (Limit-CalibZero $x0 $sig 'interp' $a ($a -lt -0.2))
        }
    }
    $under = $s[-1] -gt 0
    $j = if ($under) { $xs.Count - 2 } else { 0 }
    $a = ($s[$j + 1] - $s[$j]) / ($xs[$j + 1] - $xs[$j])
    $own = $a -lt -0.2
    if (-not $own) { $a = $pooledSlope }
    $xr = if ($under) { $xs[-1] } else { $xs[0] }
    $sr = if ($under) { $s[-1] } else { $s[0] }
    $er = if ($under) { $e[-1] } else { $e[0] }
    $x0 = $xr + $sr / (-$a)
    $sig = [math]::Sqrt([math]::Pow($er / [math]::Abs($a), 2) + [math]::Pow(0.25 * [math]::Abs($x0 - $xr), 2))
    if ([math]::Abs($sr) -le 2.0 * $er) { return (Limit-CalibZero $x0 $sig 'interp' $a $own) }
    return (Limit-CalibZero $x0 ([math]::Max($script:CalExtrapSigMin, $sig)) 'extrap' $a $own)
}

function Get-BracketSpec($bracket) {
    # Profil --precomp d une passe d encadrement : une entree c=ns par cylindre a encadrer (seuls ceux-la sont ecrits)
    return ((@($bracket.Keys | ForEach-Object { [int]$_ } | Sort-Object) | ForEach-Object { "$_=$($bracket[$_])" }) -join ':')
}

function Get-InterpEst($u, [int]$c) {
    # Estimation interpolee lineairement entre les cylindres estimes qui encadrent c, cible d une passe de mesure : bornee
    # a 0..CalMaxNs (plafond des passes de mesure)
    $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($cs.Count -eq 0) { return $script:CalInterpDefault }
    $v = if ($c -le $cs[0]) { [double]$u.Est[$cs[0]] } elseif ($c -ge $cs[-1]) { [double]$u.Est[$cs[-1]] } else {
        $j = 0; while ($cs[$j + 1] -lt $c) { $j++ }
        [double]$u.Est[$cs[$j]] + ($c - $cs[$j]) / [double]($cs[$j + 1] - $cs[$j]) * ([double]$u.Est[$cs[$j + 1]] - [double]$u.Est[$cs[$j]])
    }
    return [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round($v, 0)))
}

function Start-CalibDensify($cal) {
    # Test standard : une chute du besoin entre deux cylindres testes voisins (plus de 15 ns et de 3 incertitudes), ou
    # une estimation loin de la courbe provisoire, declenche des mesures complementaires sur les cylindres intermediaires
    # (chute : tous ceux entre les deux, plus 2 de part et d autre ; ecart : c-4, c-2, c-1, c+1, c+2, c+4), en deux
    # passes : A a la valeur interpolee, B de l autre cote du zero (pente commune). Les cylindres qui bordent la zone
    # sont remesures a leur estimation. 2 zones et 30 cylindres au plus. Renvoie $true si une passe est lancee.
    if ($cal.Mode -eq 'fine' -or $cal.Densified) { return $false }
    $zones = New-Object System.Collections.Generic.List[object]
    foreach ($u in $cal.Units) {
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        if ($cs.Count -lt 3) { continue }
        for ($i = 0; $i -lt $cs.Count - 1; $i++) {
            $ci = $cs[$i]; $cj = $cs[$i + 1]
            $thr = [math]::Max($script:CalDevNs, 3.0 * [math]::Sqrt([double]$u.Sig[$ci] * [double]$u.Sig[$ci] + [double]$u.Sig[$cj] * [double]$u.Sig[$cj]))
            $drop = [double]$u.Est[$ci] - [double]$u.Est[$cj]
            if ($drop -gt $thr -and $cj - $ci -gt 1) { $zones.Add(@{ Lo = $ci; Hi = $cj; Kind = 'drop'; Sev = $drop }) }
        }
        $fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl $u.Kind $false
        if ($fit) {
            foreach ($c in $cs) {
                $dv = $fit.Values[$c] - [double]$u.Est[$c]
                if ([math]::Abs($dv) -gt [math]::Max($script:CalDevNs, 3.0 * [double]$u.Sig[$c])) { $zones.Add(@{ Lo = $c; Hi = $c; Kind = 'dev'; Sev = [math]::Abs($dv) }) }
            }
        }
    }
    if ($zones.Count -eq 0) { return $false }
    $tested = @{}; foreach ($c in $cal.Cyls) { $tested[[int]$c] = $true }
    $new = @{}; $bounds = @{}; $kept = 0; $skipped = @(); $names = @(); $drops = @()
    # Chutes d abord (par severite), puis ecarts ; un ecart deja couvert par une chute retenue (a 2 cylindres pres)
    # ne compte pas : il ne doit pas prendre la place d une autre chute
    foreach ($z in @($zones | Sort-Object @{ Expression = { [int]($_.Kind -ne 'drop') } }, @{ Expression = { -[double]$_.Sev } })) {
        if ($z.Kind -ne 'drop' -and @($drops | Where-Object { [int]$z.Lo -ge [int]$_.Lo - 2 -and [int]$z.Lo -le [int]$_.Hi + 2 }).Count -gt 0) { continue }
        # (parentheses : la virgule est prioritaire sur l addition en PowerShell)
        $cand = if ($z.Kind -eq 'drop') { @(@(([int]$z.Lo + 1)..([int]$z.Hi - 1)) + @(([int]$z.Lo - 2), ([int]$z.Hi + 2))) } else { @(([int]$z.Lo - 4), ([int]$z.Lo - 2), ([int]$z.Lo - 1), ([int]$z.Lo + 1), ([int]$z.Lo + 2), ([int]$z.Lo + 4)) }
        $add = @($cand | Where-Object { $_ -ge 0 -and $_ -le $cal.MaxCyl -and -not $tested.ContainsKey([int]$_) -and -not $new.ContainsKey([int]$_) })
        $nm = if ($z.Kind -eq 'drop') { (T "chute entre c{0} et c{1}") -f "$($z.Lo)", "$($z.Hi)" } else { (T "écart à c{0}") -f "$($z.Lo)" }
        if ($add.Count -eq 0) { continue }                                   # zone deja couverte (autre tete)
        if ($kept -ge 2 -or $new.Count + $add.Count -gt 30) { $skipped += $nm; continue }
        foreach ($c in $add) { $new[[int]$c] = $true }
        $bounds[[int]$z.Lo] = $true; $bounds[[int]$z.Hi] = $true
        $kept++; $names += $nm
        if ($z.Kind -eq 'drop') { $drops += $z }
    }
    foreach ($s in $skipped) { Append-Log ((T "Calibration : zone {0} non complétée (2 zones et 30 cylindres au plus) : test fin conseillé.") -f "$s") }
    if ($new.Count -eq 0) { return $false }
    $newL = [int[]]@($new.Keys | Sort-Object)
    $bndL = [int[]]@($bounds.Keys | Where-Object { $tested.ContainsKey([int]$_) } | Sort-Object)
    $cal.Densified = $true; $cal.DenseNew = $newL; $cal.DensePass = 'A'
    $cal.Cyls = [int[]]@(@($cal.Cyls) + @($newL) | Sort-Object -Unique)
    $cal.CylList = Format-CylList $cal.Cyls; $cal.TSpec = "c=$($cal.CylList):h=0-1"
    foreach ($u in $cal.Units) {
        foreach ($c in $newL) { $u.Results[$c] = @{} }
        $u.Dense = @{}
        foreach ($c in $newL) { $u.Dense[$c] = Get-InterpEst $u $c }
        foreach ($c in $bndL) { if ($u.Est.ContainsKey($c)) { $u.Dense[$c] = [int][math]::Max(0, [math]::Min($script:CalMaxNs, [math]::Round([double]$u.Est[$c], 0))) } }
    }
    Append-Log ((T "Calibration : anomalie de la courbe ({0}) : mesures complémentaires des cylindres {1}, en deux passes, pour distinguer une marche, une rampe ou un point isolé.") -f "$($names -join ' ; ')", "$(Format-CylList $newL)")
    $cal.Stage = 'densify'; $cal.TotalPasses += 2
    New-CalibPass
    return $true
}

function Set-CalibDenseB($cal) {
    # Passe B : chaque cylindre ajoute est ecrit de l autre cote du zero predit par sa mesure A (pente commune),
    # a 15 ns au moins de la valeur A (CalDenseStep, 12.7) ; les cylindres qui bordent la zone sont remesures a la meme
    # valeur (repetition)
    foreach ($u in $cal.Units) {
        $slope = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
        $nd = @{}
        foreach ($c in @($u.Dense.Keys | ForEach-Object { [int]$_ })) {
            if ($cal.DenseNew -notcontains $c) { $nd[$c] = [int]$u.Dense[$c]; continue }
            $x1 = [int]$u.Dense[$c]; $pts = $u.Results[$c]
            if (-not $pts -or -not $pts.ContainsKey($x1)) { continue }
            $z = $x1 + [double]$pts[$x1].Shift / (-$slope)
            $dir = if ($z -ge $x1) { 1 } else { -1 }
            $x2 = [int][math]::Round($z + $script:CalDenseStep * $dir)
            if ([math]::Abs($x2 - $x1) -lt $script:CalDenseStep) { $x2 = $x1 + $script:CalDenseStep * $dir }
            $x2 = [int][math]::Max(0, [math]::Min($script:CalMaxNs, $x2))
            if ($x2 -eq $x1) { $x2 = if ($x1 -ge $script:CalDenseStep) { $x1 - $script:CalDenseStep } else { $x1 + $script:CalDenseStep } }
            $nd[$c] = $x2
        }
        $u.Dense = $nd
    }
}

function Get-TrendEstimates($u, [int]$maxCyl, [bool]$dense) {
    # Zero d un cylindre encore sous-compense au plafond des passes de mesure (CalMaxNs), extrapole de ses mesures : garde
    # tel quel s il est proche (incertitude <= CalTrendSig) avec une pente propre. Sinon combine (moyenne ponderee par
    # l inverse des variances) avec la tendance de la courbe : droite ponderee de pente >= 0 sur les CalTrendN derniers
    # cylindres fiables (incertitude <= 6 ns, ni plafonnes, ni isoles, ni eux-memes combines) qui le precedent dans le meme
    # segment croissant, a CalTrendSpan cylindres au plus (3 fois plus en test standard). Incertitude de la tendance :
    # erreur-type de la prediction (elargie si les points s ecartent de la droite) et 25 % de la hausse extrapolee depuis
    # le dernier cylindre fiable (meme regle qu une extrapolation propre).
    # Copies : u.Est, u.Sig et u.Kind restent la mesure propre (controle Dev, journal, courbe enregistree) ; type
    # transitoire 'trend' (non fiable pour SegFit), jamais enregistre. Renvoie @{ Est; Sig; Kind; Info (c -> detail) }.
    $est = @{}; $sig = @{}; $kind = @{}; $info = @{}
    foreach ($k in @($u.Est.Keys)) { $est[[int]$k] = [double]$u.Est[$k]; $sig[[int]$k] = [double]$u.Sig[$k]; $kind[[int]$k] = [string]$u.Kind[$k] }
    $res = @{ Est = $est; Sig = $sig; Kind = $kind; Info = $info }
    # 12.8 (S3-HIGH) : cylindres mesures autour de leur besoin par la mesure directe (Reach, mesure complete de cette
    # disquette seulement) : zero de la corde de leurs deux ecritures, jamais combine avec la tendance
    $cand = @($est.Keys | ForEach-Object { [int]$_ } | Where-Object { $kind[$_] -eq 'extrap' -and $est[$_] -gt $script:CalMaxNs -and ($sig[$_] -gt $script:CalTrendSig -or ($u.Own -and $u.Own.ContainsKey($_) -and -not $u.Own[$_])) -and -not ($u.Reach -and $u.Reach.ContainsKey($_)) } | Sort-Object)
    if ($cand.Count -eq 0) { return $res }                      # cas courant : aucune combinaison
    $f0 = Fit-PrecompCurve $u.Est $u.Sig $maxCyl $u.Kind $dense
    $segs = @(if ($f0 -and $f0.Segs) { @($f0.Segs) } else { @{ Lo = 0; Hi = $maxCyl; Dir = 1 } })
    $outl = @{}; if ($f0) { foreach ($c in @($f0.Outliers)) { if ($null -ne $c) { $outl[[int]$c] = $true } } }
    $cs = @($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $span = if ($dense) { [int]$script:CalTrendSpan } else { 3 * [int]$script:CalTrendSpan }
    $minRef = if ($dense) { 3 } else { 2 }
    foreach ($c in $cand) {
        $sg = @($segs | Where-Object { $c -ge [int]$_.Lo -and $c -le [int]$_.Hi })
        if ($sg.Count -eq 0 -or [int]$sg[0].Dir -ne 1) { continue }        # segment decroissant : pas de tendance montante
        $lo = [math]::Max([int]$sg[0].Lo, $c - $span)
        $ref = @($cs | Where-Object { $_ -lt $c -and $_ -ge $lo -and -not $outl.ContainsKey($_) -and $kind[$_] -ne 'cap' -and $kind[$_] -ne 'trend' -and [double]$u.Sig[$_] -le $script:CalTrendRefSig } | Select-Object -Last ([int]$script:CalTrendN))
        if ($ref.Count -lt $minRef) { continue }
        $sw = 0.0; $sx = 0.0; $sy = 0.0
        foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $sw += $w; $sx += $w * $r; $sy += $w * [double]$u.Est[$r] }
        $mx = $sx / $sw; $my = $sy / $sw; $sxx = 0.0; $sxy = 0.0
        foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $sxx += $w * ($r - $mx) * ($r - $mx); $sxy += $w * ($r - $mx) * ([double]$u.Est[$r] - $my) }
        if ($sxx -le 0) { continue }
        $b = [math]::Max(0.0, $sxy / $sxx); $a = $my - $b * $mx
        $chi = 0.0; foreach ($r in $ref) { $w = 1.0 / [math]::Pow([math]::Max(1.0, [double]$u.Sig[$r]), 2); $chi += $w * [math]::Pow([double]$u.Est[$r] - ($a + $b * $r), 2) }
        $chi = $chi / [math]::Max(1, $ref.Count - 2)
        $pred = $a + $b * $c
        $rise = [math]::Max(0.0, $pred - [double]$u.Est[$ref[-1]])
        $sT = [math]::Max(1.0, [math]::Sqrt((1.0 / $sw + [math]::Pow($c - $mx, 2) / $sxx) * [math]::Max(1.0, $chi) + [math]::Pow(0.25 * $rise, 2)))
        $wo = 1.0 / [math]::Pow([math]::Max(1.0, $sig[$c]), 2); $wt = 1.0 / ($sT * $sT)
        # Plancher : la plus forte precomp ecrite au cylindre, encore sous-compensee (zero extrapole au-dela)
        $xr = 0.0
        if ($u.Results -and $u.Results.ContainsKey($c) -and $u.Results[$c].Count -gt 0) { $xr = [double](@($u.Results[$c].Keys | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum }
        $v = [math]::Max($xr, [math]::Min([double]$script:CalHardNs, ($wo * $est[$c] + $wt * $pred) / ($wo + $wt))); $sv = 1.0 / [math]::Sqrt($wo + $wt)
        $info[$c] = @{ Own = $est[$c]; OwnSig = $sig[$c]; Trend = $pred; TrendSig = $sT; Est = $v; Sig = $sv }
        $est[$c] = $v; $sig[$c] = $sv; $kind[$c] = 'trend'
    }
    return $res
}

function Start-CalibFit($cal) {
    # Courbe par unite d apres les estimations (points isoles ecartes sur des donnees denses ; zero extrapole incertain
    # au-dela du plafond des passes de mesure combine avec la tendance de la courbe, Get-TrendEstimates), puis premiere
    # passe de verification de tous les cylindres estimes
    $dense = ($cal.Mode -eq 'fine' -or [bool]$cal.Densified)
    foreach ($u in $cal.Units) {
        # Estimation des seules passes de mesure (apres encadrement et mesures complementaires, avant toute verification et
        # sans la tendance) : troisieme mesure des verifications contradictoires (Get-VerifyDrift)
        $u.EstPass = @{}; foreach ($k in @($u.Est.Keys)) { $u.EstPass[[int]$k] = [double]$u.Est[$k] }
        $tr = Get-TrendEstimates $u $cal.MaxCyl $dense
        $u.Trend = $tr.Info
        if ($tr.Info.Count -gt 0) {
            $tt = (@($tr.Info.Keys | Sort-Object | ForEach-Object { $ti = $tr.Info[$_]; (T "c{0} : extrapolation {1} ± {2} ns, tendance {3} ± {4} ns, retenu {5} ns") -f "$_", (Format-LevelNum $ti.Own), (Format-LevelNum $ti.OwnSig), (Format-LevelNum $ti.Trend), (Format-LevelNum $ti.TrendSig), (Format-LevelNum $ti.Est) })) -join ' ; '
            Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, zéro extrapolé incertain (loin des mesures ou sans pente propre) : combiné avec la tendance de la courbe ({1}). La vérification écrit la courbe à ces cylindres et la mesure.") -f "$($script:CalMaxNs)", "$tt"))
            $u.Fit = Fit-PrecompCurve $tr.Est $tr.Sig $cal.MaxCyl $tr.Kind $dense
        } else { $u.Fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl $u.Kind $dense }
        $u.Outliers = @($u.Fit.Outliers | ForEach-Object { [int]$_ } | Sort-Object)
        foreach ($c in $u.Outliers) { if ($u.Kind.ContainsKey($c)) { $u.Kind[$c] = 'outlier' } }
        $u.Profile = Build-CurveProfile $u.Fit.Values
        Append-Log ($u.Prefix + ((T "Courbe ajustée : {0} (écart réduit {1}), de {2} ns au cylindre 0 à {3} ns au cylindre {4} ; profil : {5}") -f (Get-CurveModelName $u.Fit.Model), "$([math]::Round($u.Fit.Chi, 2))", "$($u.Fit.Values[0])", "$($u.Fit.Values[-1])", "$($cal.MaxCyl)", "$($u.Profile)"))
        if ($u.Outliers.Count -gt 0) { Append-Log ($u.Prefix + ((T "Point(s) isolé(s) écarté(s) de la courbe : {0} : écart avec les cylindres voisins, défaut ponctuel probable de la disquette de calibration, non suivi.") -f (($u.Outliers | ForEach-Object { "c$_" }) -join ', '))) }
        $u.Verify = @{}; $u.VerifyP = @{}; $u.VerifyList = $null; $u.VerifyPrev = @{}; $u.Witness = @(); $u.ReadLast = @{}; $u.WitCand = 0; $u.WitMin = 0
    }
    $cal.Stage = 'verify'; $cal.VerifyCount = 1
    New-CalibPass
}

function Get-ResidualTol($meas) {
    # Tolerance du residu d une verification : CalResidual, elargie a 3 erreurs-types quand la mesure est plus bruitee
    # (un residu dans le bruit ne justifie ni une correction ni une alerte de non-convergence)
    $se = [double]::NaN
    if ($null -ne $meas -and $null -ne $meas.SE) { $se = [double]$meas.SE }
    if ([double]::IsNaN($se)) { return [double]$script:CalResidual }
    return [math]::Max([double]$script:CalResidual, 3.0 * $se)
}

function Add-DriftWitnesses($u) {
    # Verification ciblee : des cylindres non modifies sont reecrits a leur valeur inchangee et relus avec les cylindres
    # modifies. Leur valeur ecrite ne change pas : l ecart de leur residu d une verification a l autre mesure directement la
    # derive du lecteur entre les deux passes (temperature, contact de la tete), sans dependre de la pente. Repartis sur la
    # piste, sans condition sur leur residu (pas de biais de selection), et seulement s ils ne depassent pas le nombre
    # maximal d ecritures par piste que la calibration atteint de toute facon.
    $u.Witness = @(); $u.WitCand = 0
    # Minimum de temoins : 4 en test standard (peu de cylindres non modifies), sinon CalDriftMinWit ; garde avec l unite
    $u.WitMin = if ($script:Cal -and $script:Cal.Mode -ne 'fine' -and -not [bool]$script:Cal.Densified) { 4 } else { [int]$script:CalDriftMinWit }
    if (@($u.VerifyList).Count -eq 0) { return }
    $vals = @($u.Fit.Values)
    $cand = @($u.Verify.Keys | ForEach-Object { [int]$_ } | Where-Object {
        @($u.VerifyList) -notcontains $_ -and @($u.Outliers) -notcontains $_ -and $u.VerifyP.ContainsKey($_) -and $_ -lt $vals.Count -and
        [int]$vals[$_] -eq [int]$u.VerifyP[$_] -and [int]$vals[$_] -gt 0 -and [int]$vals[$_] -lt $script:CalHardNs } | Sort-Object)
    # 12.8 (lot 1b) : jamais au-dela du nombre d ecritures par piste annonce par l avertissement (WriteMax), repli compris.
    # Sans effet a la verification 2 (une piste n est ecrite qu une fois par passe) ; passe du nouvel essai : piste deja
    # ecrite WriteMax fois exclue
    if ($script:Cal -and [int]$script:Cal.WriteMax -gt 0 -and $null -ne $u.Writes) {
        $wcap = [int]$script:Cal.WriteMax
        $cand = @($cand | Where-Object { 1 + [int]$u.Writes[[int]$_] -le $wcap })
    }
    if ($null -ne $u.Writes -and $u.Writes.Count -gt 0) {
        $wmax = [int](@($u.Writes.Values) | Measure-Object -Maximum).Maximum
        $vmax = [int](@(@($u.VerifyList) | ForEach-Object { 1 + [int]$u.Writes[[int]$_] }) | Measure-Object -Maximum).Maximum
        $lim = [math]::Max($wmax, $vmax)
        $low = @($cand | Where-Object { 1 + [int]$u.Writes[[int]$_] -le $lim })
        # Repli : une ecriture de plus sur quelques pistes plutot qu aucune mesure de derive
        if ($low.Count -ge [int]$u.WitMin) { $cand = $low }
    }
    $u.WitCand = $cand.Count
    $k = [math]::Min([int]$script:CalDriftWitness, $cand.Count)
    if ($k -lt [int]$u.WitMin) { return }
    $w = @(for ($i = 0; $i -lt $k; $i++) { [int]$cand[[int][math]::Floor(($i + 0.5) * $cand.Count / $k)] })
    $u.Witness = $w
    $u.VerifyList = @(@($u.VerifyList) + $w | Sort-Object -Unique)
}

function Get-VerifyDrift($u) {
    # Derive du lecteur entre les deux dernieres verifications, mesuree sur les temoins (meme valeur ecrite les deux fois) :
    # D = mediane de (residu nouveau - residu precedent), incertitude E = 1,2533 S / racine du nombre de temoins. Les residus
    # des cylindres relus a la derniere verification sont juges sans ce decalage (ramenes au repere de la verification
    # precedente, sur laquelle la courbe a ete corrigee).
    # Verifications contradictoires (Contra) : cylindre corrige (p1 -> p2) dont le residu de la derniere verification r2'
    # (derive D retiree, 0 si non mesuree) est hors de sa tolerance du cote de p1, et dont le residu de la verification
    # precedente r1 est du cote de p2 (hors de sa tolerance), ou dans sa tolerance (cylindre deplace avec ses voisins par le
    # lissage, sans que la verification 1 l ait demande) : les deux verifications placent le besoin entre p1 et p2 mais leurs
    # estimations se contredisent. Valeur retenue Z : mediane de l estimation des passes de mesure (EstPass) et des
    # zeros des deux verifications (pente commune), moyenne des deux zeros sans EstPass, bornee a [min(p1,p2) ; max(p1,p2)] ;
    # E = ecart entre les deux zeros. Toujours traite ainsi, quelle que soit la longueur de la suite (Set-VerifyContra).
    # Ecart minimal : un candidat dont E ne depasse pas la tolerance de la verification 1 convertie en ns de precomp par la
    # meme pente (CalContraMinNs si elle n est pas convertible) est en accord. Zone : suite de candidats voisins (comme les
    # suites ci-dessous) dont un au moins depasse ce seuil, candidats en accord compris ; une suite dont tous les candidats
    # sont en accord (cylindre isole, typiquement) n est pas une contradiction : jugee par les regles qui suivent (non
    # reproductible, ecart local ou non converge), residu enregistre.
    # Non reproductible : temoin dont l ecart s eloigne de D de plus de max(3 tolerances ; 4 S) ; cylindre corrige dont le
    # residu, derive retiree, va a l inverse du changement prevu par la pente commune de plus de cette limite, ou au-dela du
    # changement prevu entier de plus de cette limite alors que r2' reste hors de sa tolerance (hors contradiction : r1 a
    # l oppose de la correction, comme le c81 de U5). Une reponse
    # plus faible que prevu, ou nulle, n est pas une non-reproductibilite : le cylindre est juge normalement. Une suite d au
    # moins 3 candidats voisins (2 cylindres au plus, ou consecutifs parmi les cylindres relus) de meme sens est un ecart
    # systematique, jugee normalement elle aussi. DC / NC : ecart median des cylindres corriges a leur prediction (derive
    # comprise), a comparer a D (les temoins isoles derivent-ils comme les blocs corriges ?). Sys : candidats d une suite
    # systematique ; un temoin qui en fait partie est juge sur sa relecture, derive retiree, et non sur sa mesure precedente.
    $res = @{ Use = $false; D = 0.0; S = [double]::NaN; SRaw = [double]::NaN; E = [double]::NaN; NW = 0; NC = 0; DC = [double]::NaN; NonRepro = @{}; Sys = @{}; Contra = @{} }
    if (-not $u.VerifyPrev -or $u.VerifyPrev.Count -eq 0) { return $res }
    $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
    $wit = @(); $cor = @()
    foreach ($k in @($u.VerifyPrev.Keys)) {
        $c = [int]$k
        if (-not $u.Verify.ContainsKey($c) -or -not $u.VerifyP.ContainsKey($c) -or @($u.Outliers) -contains $c) { continue }
        $p1 = [double]$u.VerifyPrev[$c].P; $r1 = [double]$u.VerifyPrev[$c].Shift
        $p2 = [double]$u.VerifyP[$c]; $r2 = [double]$u.Verify[$c].Shift
        if ([double]::IsNaN($r1) -or [double]::IsNaN($r2)) { continue }
        $o = @{ C = $c; Obs = $r2 - $r1; Exp = $sl * ($p2 - $p1); P1 = $p1; R1 = $r1; P2 = $p2; R2 = $r2 }
        # 12.8 (lot 1b) : temoin = cylindre choisi par Add-DriftWitnesses (Witness). Passe du nouvel essai : cylindres vises
        # ou voisins relus a leur valeur inchangee, choisis pour leur residu : ni temoins ni corriges (juges sur leur
        # relecture, derive retiree). Verification 2 : tout cylindre relu a sa valeur inchangee est un temoin (inchange)
        if ($p2 -eq $p1) { if (@($u.Witness) -contains $c) { $wit += ,$o } } else { $cor += ,$o }
    }
    $res.NW = $wit.Count
    $wm = if ($u.WitMin) { [int]$u.WitMin } else { [int]$script:CalDriftMinWit }
    $d = 0.0; $s = 1.0
    if ($wit.Count -ge $wm) {
        $dw = @($wit | ForEach-Object { [double]$_.Obs })
        $d = [double](Get-Median $dw)
        $sr = 1.4826 * [double](Get-Median @($dw | ForEach-Object { [math]::Abs($_ - $d) }))
        $s = [math]::Max(1.0, $sr)
        $res.Use = $true; $res.D = $d; $res.S = $s; $res.SRaw = $sr; $res.E = 1.2533 * $s / [math]::Sqrt([double]$wit.Count)
    }
    # Verifications contradictoires (derive retiree si elle est mesuree) : candidats, puis zones
    $cnd = @{}
    foreach ($o in $cor) {
        $c = [int]$o.C; $p1 = [double]$o.P1; $p2 = [double]$o.P2; $r1 = [double]$o.R1; $r2 = [double]$o.R2 - $d
        $dir = [math]::Sign($p2 - $p1)
        # r2' hors tolerance du cote de p1 ; r1 hors tolerance : du cote de p2 (dans sa tolerance : tout signe)
        if ([math]::Sign($r2) -ne -$dir -or [math]::Abs($r2) -le (Get-ResidualTol $u.Verify[$c])) { continue }
        if ([math]::Abs($r1) -gt (Get-ResidualTol $u.VerifyPrev[$c].Meas) -and [math]::Sign($r1) -ne $dir) { continue }
        $z1 = $p1 - $r1 / $sl; $z2 = $p2 - $r2 / $sl
        # Ecart minimal : zeros a moins de la tolerance de la verification 1 (ns de precomp, pente sl comme E) : accord
        $tp = [double](Get-ResidualTol $u.VerifyPrev[$c].Meas) / [math]::Abs($sl)
        if ([double]::IsNaN($tp) -or [double]::IsInfinity($tp) -or $tp -le 0) { $tp = [double]$script:CalContraMinNs }
        $zp = $null
        if ($u.EstPass -and $u.EstPass.ContainsKey($c) -and -not [double]::IsNaN([double]$u.EstPass[$c])) { $zp = [double]$u.EstPass[$c] }
        $zm = if ($null -ne $zp) { [double](Get-Median @($zp, $z1, $z2)) } else { ($z1 + $z2) / 2.0 }
        $zm = [math]::Max([math]::Min($p1, $p2), [math]::Min([math]::Max($p1, $p2), $zm))
        $zc = [int][math]::Max(0, [math]::Min($script:CalHardNs, [math]::Round($zm, 0)))
        $cnd[$c] = @{ Z = $zc; Z1 = $z1; Z2 = $z2; ZP = $zp; E = [math]::Abs($z2 - $z1); P1 = $p1; P2 = $p2; Low = ([math]::Abs($z2 - $z1) -le $tp) }
    }
    # Zone : suite de candidats voisins (2 cylindres au plus, ou consecutifs parmi les cylindres relus) dont un au moins
    # depasse l ecart minimal ; une suite dont tous les candidats sont en accord n est pas une contradiction
    $rl = @(@($wit + $cor) | ForEach-Object { [int]$_.C } | Sort-Object)
    $kc = @($cnd.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $ia = 0
    while ($ia -lt $kc.Count) {
        $ja = $ia
        while ($ja -lt $kc.Count - 1 -and (($kc[$ja + 1] - $kc[$ja] -le 2) -or ([array]::IndexOf($rl, $kc[$ja + 1]) - [array]::IndexOf($rl, $kc[$ja]) -eq 1))) { $ja++ }
        $hi = $false; for ($q = $ia; $q -le $ja; $q++) { if (-not $cnd[$kc[$q]].Low) { $hi = $true } }
        if ($hi) { for ($q = $ia; $q -le $ja; $q++) { $ce = $cnd[$kc[$q]]; $res.Contra[$kc[$q]] = @{ Z = $ce.Z; Z1 = $ce.Z1; Z2 = $ce.Z2; ZP = $ce.ZP; E = $ce.E; P1 = $ce.P1; P2 = $ce.P2 } } }
        $ia = $ja + 1
    }
    if (-not $res.Use) { return $res }
    $lim = [math]::Max(3.0 * [double]$script:CalResidual, 4.0 * $s)
    $cand = @{}
    foreach ($o in @($wit + $cor)) {
        if ($res.Contra.ContainsKey([int]$o.C)) { continue }                 # verifications contradictoires : mediane
        $ob = [double]$o.Obs - $d; $ex = [double]$o.Exp
        # A l inverse du changement prevu ; ou au-dela du changement prevu entier, r2' encore hors tolerance
        $nr = if ($ex -eq 0) { [math]::Abs($ob) -gt $lim } else {
            $sgx = [math]::Sign($ex)
            (($ob * $sgx) -lt (-$lim)) -or ((($ob * $sgx) -gt ([math]::Abs($ex) + $lim)) -and ([math]::Abs([double]$o.R2 - $d) -gt (Get-ResidualTol $u.Verify[[int]$o.C])))
        }
        if ($nr) { $cand[[int]$o.C] = $o }
    }
    # Suites de candidats voisins de meme sens : ecart systematique, pas une mesure non reproductible
    $cs = @($cand.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    # Voisins : 2 cylindres au plus, ou consecutifs parmi les cylindres relus (test standard, un cylindre sur 10)
    $all = @(@($wit + $cor) | ForEach-Object { [int]$_.C } | Sort-Object)
    $i = 0
    while ($i -lt $cs.Count) {
        $j = $i
        while ($j -lt $cs.Count - 1 -and (($cs[$j + 1] - $cs[$j] -le 2) -or ([array]::IndexOf($all, $cs[$j + 1]) - [array]::IndexOf($all, $cs[$j]) -eq 1)) -and [math]::Sign([double]$cand[$cs[$j + 1]].Obs - $d - [double]$cand[$cs[$j + 1]].Exp) -eq [math]::Sign([double]$cand[$cs[$i]].Obs - $d - [double]$cand[$cs[$i]].Exp)) { $j++ }
        if ($j - $i + 1 -lt 3) {
            for ($q = $i; $q -le $j; $q++) { $o = $cand[$cs[$q]]; $res.NonRepro[[int]$cs[$q]] = @{ Z1 = [double]$o.P1 - [double]$o.R1 / $sl; Z2 = [double]$o.P2 - ([double]$o.R2 - $d) / $sl } }
        }
        else { for ($q = $i; $q -le $j; $q++) { $res.Sys[[int]$cs[$q]] = $true } }   # ecart systematique : juge sur la relecture
        $i = $j + 1
    }
    $kc = @($cor | Where-Object { -not $res.NonRepro.ContainsKey([int]$_.C) } | ForEach-Object { [double]$_.Obs - [double]$_.Exp })
    if ($kc.Count -gt 0) { $res.NC = $kc.Count; $res.DC = [double](Get-Median $kc) }
    return $res
}

function Set-VerifyContra($u) {
    # Apres la derniere verification, avant le bilan : cylindres aux verifications contradictoires (Get-VerifyDrift) ramenes
    # a leur valeur retenue (mediane bornee a l intervalle des deux valeurs ecrites). Correction par segments de la courbe
    # (Add-CurveCorrection : 0 aux autres cylindres verifies, monotonie par segments conservee), nouveau profil ; pas de
    # nouvelle passe d ecriture. Les cylindres verifies hors zone sont des points fixes (residu mesure a leur valeur) : la
    # cible d un cylindre de la zone est bornee par ses voisins fixes du meme segment, dans le sens du segment, pour que le
    # lissage croissant ne deplace aucun d eux sans mesure. Filet : un cylindre fixe deplace malgre tout (test standard :
    # cylindre interpole entre la zone et lui) est releve dans ContraMoved (residu non enregistre, ligne de journal).
    # Renvoie le nombre de cylindres de la zone dont la valeur change.
    $u.ContraMoved = @()
    if (-not $u.Fit -or -not $u.Profile) { return 0 }
    $dft = Get-VerifyDrift $u
    if ($dft.Contra.Count -eq 0) { return 0 }
    $vals = @($u.Fit.Values); $delta = @{}; $n = 0
    foreach ($k in @($u.Verify.Keys)) {
        $c = [int]$k
        if (@($u.Outliers) -contains $c -or $c -ge $vals.Count) { continue }
        $delta[$c] = 0.0
    }
    $segs = if ($u.Fit.Segs) { @($u.Fit.Segs) } else { @(@{ Lo = 0; Hi = $vals.Count - 1; Dir = 1 }) }
    $fix = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { -not $dft.Contra.ContainsKey($_) } | Sort-Object)
    foreach ($k in @($dft.Contra.Keys)) {
        $c = [int]$k
        if (-not $delta.ContainsKey($c)) { continue }
        $sg = $null; foreach ($g in $segs) { if ($c -ge [int]$g.Lo -and $c -le [int]$g.Hi) { $sg = $g; break } }
        $t = [double]$dft.Contra[$c].Z
        if ($sg) {
            # Voisins fixes du segment, a gauche et a droite ; segment decroissant : bornes inversees
            $fl = @($fix | Where-Object { $_ -ge [int]$sg.Lo -and $_ -lt $c }); $fr = @($fix | Where-Object { $_ -gt $c -and $_ -le [int]$sg.Hi })
            $a = if ($fl.Count) { [double]$vals[$fl[-1]] } else { $null }; $b = if ($fr.Count) { [double]$vals[$fr[0]] } else { $null }
            if ([int]$sg.Dir -lt 0) { $x = $a; $a = $b; $b = $x }
            if ($null -ne $a) { $t = [math]::Max($t, $a) }
            if ($null -ne $b) { $t = [math]::Min($t, $b) }
        }
        $delta[$c] = $t - [double]$vals[$c]; if ($delta[$c] -ne 0) { $n++ }
    }
    if ($n -eq 0) { return 0 }
    $newVals = Add-CurveCorrection $u.Fit.Values $delta $u.Fit.Segs
    $newProfile = Build-CurveProfile $newVals
    if ($newProfile -eq $u.Profile) { return 0 }
    $base = ([string]$u.Fit.Model) -replace '\+c$', ''
    $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
    $u.Profile = $newProfile
    $u.ContraMoved = [int[]]@($fix | Where-Object { [int]$newVals[$_] -ne [int]$vals[$_] })
    return $n
}

function Get-ResidualFlags($u) {
    # Residus de la derniere verification. Bad : residu retenu (correction a la verification, non-convergence au bilan) ;
    # Spot : residu hors tolerance non retenu (ecart local, signale sans correction).
    # Voisinage d un cylindre : cylindres juges a 2 cylindres au plus (distance en cylindres, pas en rang) ; fenetre
    # tronquee, jamais decalee, la ou il en manque (debut ou fin de piste, cylindre non verifie, point isole, cylindre au
    # plafond ou au plancher). Points isoles et limites physiques (plafond, plancher) hors du jugement ; cylindres non
    # reproductibles et verifications contradictoires (Get-VerifyDrift) aussi, mais comptes comme voisins verifies.
    #  - Bruit : ecart-type robuste (MAD) des differences de residu entre cylindres juges consecutifs distants de 2 au
    #    plus, dans le meme segment de la courbe. Moins de CalNoiseMinDiffs differences (test standard, un cylindre sur
    #    10) : regle d origine, tout residu hors de sa tolerance est retenu.
    #  - Seuil d une moyenne de n residus : T(n) = max(CalResidual ; 3 bruits / racine de n). Residu tres grand :
    #    Hard = max(3 CalResidual ; 6 bruits).
    #  - Ecart : suite de cylindres juges consecutifs, distants de 2 au plus, hors tolerance, du meme
    #    signe ; un seul verdict par ecart. Retenu si l un de ses cylindres a moins de 2 voisins (cylindre epars : regle
    #    d origine, la courbe suit sa correction par interpolation entre cylindres verifies), une moyenne de voisinage
    #    au-dela de T, ou un residu au-dela de Hard ; ou si l ecart compte au moins 3 cylindres, ou 2 au bord (aucun
    #    cylindre juge du meme segment au-dela, a 2 cylindres au plus, d un cote : bout de piste, changement de sens,
    #    plafond : marche que la courbe peut suivre et que la fenetre ne peut pas confirmer), avec une moyenne au-dela de
    #    T(longueur) ; ou s il compte 2 cylindres de moyenne au-dela de Hard / racine de 2 (exigence d un residu seul
    #    au-dela de Hard, ramenee a la moyenne de 2).
    $vals = @($u.Fit.Values)
    $segs = @($u.Fit.Segs | Where-Object { $null -ne $_ })
    $pts = New-Object System.Collections.Generic.List[object]
    $dft = Get-VerifyDrift $u
    foreach ($c in @($u.Verify.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        # Non reproductible, ou verifications contradictoires (zone non reproductible) : hors du jugement
        if (@($u.Outliers) -contains $c -or $dft.NonRepro.ContainsKey($c) -or $dft.Contra.ContainsKey($c)) { continue }
        $r = [double]$u.Verify[$c].Shift; $mz = $u.Verify[$c]
        # Temoin : valeur inchangee, juge sur sa mesure precedente (repere de la verification precedente, comme les cylindres
        # corriges une fois la derive retiree) ; sa relecture ne sert qu a mesurer la derive. Autre cylindre relu a la
        # derniere verification : juge sans la derive du lecteur mesuree sur les temoins
        if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $mz = $u.VerifyPrev[$c].Meas; $r = [double]$u.VerifyPrev[$c].Shift }
        elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
        # Limites physiques (courbe au plafond encore sous-compensee, au plancher encore sur-compensee) : hors du jugement
        if ($c -lt $vals.Count -and (($r -gt 0 -and [int]$vals[$c] -ge $script:CalHardNs) -or ($r -lt 0 -and [int]$vals[$c] -le 0))) { continue }
        $sg = if ($segs.Count -gt 0) { -1 } else { 0 }
        for ($g = 0; $g -lt $segs.Count; $g++) { if ($c -ge [int]$segs[$g].Lo -and $c -le [int]$segs[$g].Hi) { $sg = $g; break } }
        $pts.Add(@{ C = $c; R = $r; S = $sg; Out = ([math]::Abs($r) -gt (Get-ResidualTol $mz)) })
    }
    $n = $pts.Count
    $bad = @{}; $spot = @()
    $res = @{ Bad = $bad; Spot = $spot; Sigma = [double]::NaN; NDiff = 0; Hard = [double]::NaN; HardPair = [double]::NaN }
    $d = @(for ($i = 1; $i -lt $n; $i++) { if ($pts[$i].S -eq $pts[$i - 1].S -and $pts[$i].C - $pts[$i - 1].C -le 2) { [double]$pts[$i].R - [double]$pts[$i - 1].R } })
    $res.NDiff = $d.Count
    if ($d.Count -lt $script:CalNoiseMinDiffs) {
        foreach ($p in $pts) { if ($p.Out) { $bad[$p.C] = $true } }
        return $res
    }
    $md = [double](Get-Median $d)
    $sig = 1.4826 * [double](Get-Median @($d | ForEach-Object { [math]::Abs($_ - $md) })) / [math]::Sqrt(2.0)
    $t0 = [double]$script:CalResidual
    $hard = [math]::Max(3.0 * $t0, 6.0 * $sig)
    # Voisinage : premier et dernier indice des cylindres juges a 2 cylindres au plus (fenetre tronquee, jamais decalee)
    $lo = New-Object int[] $n; $hi = New-Object int[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $a = $i; while ($a -gt 0 -and $pts[$i].C - $pts[$a - 1].C -le 2) { $a-- }
        $b = $i; while ($b -lt $n - 1 -and $pts[$b + 1].C - $pts[$i].C -le 2) { $b++ }
        $lo[$i] = $a; $hi[$i] = $b
    }
    # Jugement de chaque cylindre hors tolerance d apres son voisinage
    $flag = New-Object bool[] $n
    for ($i = 0; $i -lt $n; $i++) {
        if (-not $pts[$i].Out) { continue }
        $k = $hi[$i] - $lo[$i] + 1
        # Un cylindre non reproductible (ou d une zone non reproductible), hors des moyennes, reste un voisin verifie (pas de
        # bascule dans la regle d origine)
        $kx = @(@($dft.NonRepro.Keys) + @($dft.Contra.Keys) | Where-Object { [math]::Abs([int]$_ - [int]$pts[$i].C) -le 2 }).Count
        if ($k + $kx -lt 3) { $flag[$i] = $true; continue }
        $s = 0.0; for ($j = $lo[$i]; $j -le $hi[$i]; $j++) { $s += [double]$pts[$j].R }
        $tl = [math]::Max($t0, 3.0 * $sig / [math]::Sqrt([double]$k))
        if ([math]::Abs($s / $k) -gt $tl -or [math]::Abs([double]$pts[$i].R) -gt $hard) { $flag[$i] = $true }
    }
    # Ecarts : suites de cylindres consecutifs, hors tolerance, du meme signe, qui peuvent franchir un bord de segment
    # (segment d un seul cylindre au pied d une chute franche) ; un seul verdict par ecart
    $i = 0
    while ($i -lt $n) {
        if (-not $pts[$i].Out) { $i++; continue }
        $j = $i
        while ($j -lt $n - 1 -and $pts[$j + 1].Out -and $pts[$j + 1].C - $pts[$j].C -le 2 -and [math]::Sign([double]$pts[$j + 1].R) -eq [math]::Sign([double]$pts[$i].R)) { $j++ }
        $k = $j - $i + 1
        $keep = $false; $s = 0.0
        for ($q = $i; $q -le $j; $q++) { if ($flag[$q]) { $keep = $true }; $s += [double]$pts[$q].R }
        if (-not $keep -and $k -ge 2) {
            # Au bord : aucun cylindre juge du meme segment au-dela de l ecart, a 2 cylindres au plus, d un cote
            $edge = ($i -eq 0 -or $pts[$i - 1].S -ne $pts[$i].S -or $pts[$i].C - $pts[$i - 1].C -gt 2 -or
                     $j -eq $n - 1 -or $pts[$j + 1].S -ne $pts[$j].S -or $pts[$j + 1].C - $pts[$j].C -gt 2)
            $thr = if ($edge -or $k -ge 3) { [math]::Max($t0, 3.0 * $sig / [math]::Sqrt([double]$k)) } else { $hard / [math]::Sqrt(2.0) }
            if ([math]::Abs($s / $k) -gt $thr) { $keep = $true }
        }
        for ($q = $i; $q -le $j; $q++) { if ($keep) { $bad[$pts[$q].C] = $true } else { $spot += $pts[$q].C } }
        $i = $j + 1
    }
    $res.Spot = $spot; $res.Sigma = $sig; $res.Hard = $hard; $res.HardPair = $hard / [math]::Sqrt(2.0)
    return $res
}

function Get-CalibWarnings($u, [int]$maxCyl) {
    # Bilan de fiabilite d une unite apres la derniere verification :
    #  NonConv : cylindres dont le residu de la derniere verification est retenu par Get-ResidualFlags (ecart regional,
    #            marche au bord, residu tres grand, cylindre epars) ; ou cylindres mesures que la derniere verification
    #            n a pas pu relire (correction eventuelle jamais verifiee) ;
    #  Spot    : ecarts locaux, hors tolerance mais non retenus par Get-ResidualFlags (signales, non corriges) ;
    #  Dev     : cylindres ou la courbe retenue s ecarte de l estimation de plus de max(15 ns ; 3 incertitudes),
    #            typiquement un besoin non croissant lisse par la contrainte croissante ;
    #  Sat     : cylindres encore sous-compenses alors que la valeur ecrite a la derniere verification est a la borne
    #            absolue CalHardNs : le besoin depasse la precomp maximale, une nouvelle calibration n y changera rien
    #            (exclus de NonConv) ;
    #  Floor   : cylindres encore sur-compenses avec une valeur ecrite a la derniere verification a 0 ns (plancher) : meme
    #            principe ;
    #  Beyond  : cylindres dont la courbe depasse le plafond des passes de mesure CalMaxNs (valeurs deduites des mesures,
    #            puis verifiees), information seulement ;
    #  Extrap / Cap : estimations extrapolees au-dela des mesures, ou plafonnees.
    #  Drift / NonRepro : derive du lecteur entre les deux verifications (temoins) et cylindres non reproductibles d une
    #            passe a l autre (Get-VerifyDrift) ; les residus relus a la derniere verification sont juges sans la derive.
    #  Contra  : zone non reproductible, verifications contradictoires (Get-VerifyDrift) : courbe a la mediane des passes de
    #            mesure et des deux verifications (Set-VerifyContra), hors du jugement de convergence (jamais Sat ni Floor :
    #            besoin entre les deux valeurs ecrites). Liste lue par Complete-PrecompCalib (journal, Res, champ contra).
    #  NonConvC / NonConvR (12.8, lot 1b) : cylindres de NonConv, et pour ceux qui ont un residu, le residu juge (R) et la
    #            valeur ecrite a sa mesure (P) : nouvel essai automatique (Get-CalibRetestPlan). Sans effet sur le reste.
    #  12.8 (FIXVAL01) : cylindre dont la valeur d avant le nouvel essai a ete retablie (RtKept, correction sans effet,
    #            Restore-CalibRetestNoEffect) et encore hors tolerance : NON CONVERGE (decisions128.md, « Lot 1b termine »),
    #            quel que soit le jugement de son voisinage apres la passe (ecart local, bruit) ; ni Spot, ni converge.
    $nonConv = @(); $sat = @(); $floor = @(); $dev = @(); $extrap = @(); $cap = @(); $spot = @(); $beyond = @(); $nonRepro = @(); $contra = @()
    $ncC = @(); $ncR = @{}
    $outl = @{}; foreach ($c in @($u.Outliers)) { $outl[[int]$c] = $true }
    $kept = @{}; if ($u.RtKept) { foreach ($c in @($u.RtKept)) { if ($null -ne $c) { $kept[[int]$c] = $true } } }
    $vals = @($u.Fit.Values)
    $fl = Get-ResidualFlags $u
    $dft = Get-VerifyDrift $u
    foreach ($c in @($u.Verify.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if ($outl.ContainsKey($c)) { continue }
        $r = [double]$u.Verify[$c].Shift; $mz = $u.Verify[$c]
        if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $mz = $u.VerifyPrev[$c].Meas; $r = [double]$u.VerifyPrev[$c].Shift }
        elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
        $out = [math]::Abs($r) -gt (Get-ResidualTol $mz)
        # Limites physiques jugees a la valeur ecrite quand le residu a ete mesure (avant Set-VerifyContra) : une zone
        # non reproductible (besoin entre p1 et p2) n est jamais au plafond ni au plancher. VerifyP est rempli avec Verify ;
        # sans lui (unite sans valeurs ecrites), valeur de la courbe ; jamais de comparaison avec $null ($null -le 0 est vrai)
        $pw = $null
        if ($u.VerifyP -and $u.VerifyP.ContainsKey($c)) { $pw = [int]$u.VerifyP[$c] } elseif ($c -lt $vals.Count) { $pw = [int]$vals[$c] }
        if ($out -and $null -ne $pw -and $r -gt 0 -and $pw -ge $script:CalHardNs) { $sat += ("c{0} ({1:+0.0;-0.0})" -f $c, $r); continue }
        if ($out -and $null -ne $pw -and $r -lt 0 -and $pw -le 0) { $floor += ("c{0} ({1:+0.0;-0.0})" -f $c, $r); continue }
        if ($dft.Contra.ContainsKey($c)) { $contra += $c; continue }
        if ($dft.NonRepro.ContainsKey($c)) { $z = $dft.NonRepro[$c]; $nonRepro += ((T "c{0} ({1} puis {2} ns)") -f "$c", (Format-LevelNum $z.Z1), (Format-LevelNum $z.Z2)); continue }
        if ($out) {
            $txt = "c{0} ({1:+0.0;-0.0})" -f $c, $r
            if ($fl.Bad.ContainsKey($c) -or $kept.ContainsKey($c)) { $nonConv += $txt; $ncC += $c; $ncR[$c] = @{ R = $r; P = $pw } }
            else { $spot += $txt }            # ecart local non retenu par Get-ResidualFlags
        }
    }
    foreach ($c in @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if (-not $u.Verify.ContainsKey($c) -and -not $outl.ContainsKey($c)) { $nonConv += ("c{0} ({1})" -f $c, (T 'non relu')); $ncC += $c }
    }
    foreach ($c in @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if ($c -lt $vals.Count -and -not $outl.ContainsKey($c)) {
            $dv = $vals[$c] - [double]$u.Est[$c]
            if ([math]::Abs($dv) -gt [math]::Max($script:CalDevNs, 3.0 * [double]$u.Sig[$c])) { $dev += ("c{0} ({1:+0;-0})" -f $c, $dv) }
        }
        if ($u.Kind[$c] -eq 'extrap') { $extrap += "c$c" } elseif ($u.Kind[$c] -eq 'cap') { $cap += "c$c" }
    }
    # Cylindres a la borne absolue avec Sat : couverts par le message du plafond, ce ne sont pas des valeurs deduites
    for ($c = 0; $c -lt $vals.Count; $c++) { $x = [int]$vals[$c]; if ($x -gt $script:CalMaxNs -and ($x -lt $script:CalHardNs -or $sat.Count -eq 0)) { $beyond += $c } }
    return @{ NonConv = $nonConv; Sat = $sat; Floor = $floor; Dev = $dev; Extrap = $extrap; Cap = $cap; Isolated = @($u.Outliers | ForEach-Object { "c$_" }); Breaks = @($u.Fit.Breaks)
              Spot = $spot; Sigma = $fl.Sigma; NDiff = $fl.NDiff; Hard = $fl.Hard; HardPair = $fl.HardPair; Beyond = [int[]]$beyond
              Drift = $dft; NonRepro = $nonRepro; Contra = [int[]]$contra; NonConvC = [int[]]@($ncC | Sort-Object -Unique); NonConvR = $ncR }
}

function Get-KindName([string]$k) {
    switch ($k) { 'interp' { return (T 'encadrée') } 'extrap' { return (T 'extrapolée') } 'cap' { return (T 'plafonnée') } 'outlier' { return (T 'isolée') } default { return '' } }
}

function Test-CurvePointFlag($cv, [int]$i) {
    # Point dont la courbe s ecarte de plus de max(15 ns ; 3 incertitudes) ; 12.7 : 15 ns en double densite, ecart notable
    # du bareme de sa famille (Get-CurveDevNs)
    $c = [int]$cv.Cyls[$i]; $v = @($cv.Values)
    if ($c -ge $v.Count) { return $false }
    if ($cv.Kinds -and $i -lt @($cv.Kinds).Count -and [string]$cv.Kinds[$i] -eq 'outlier') { return $false }
    return ([math]::Abs($v[$c] - [double]$cv.Ys[$i]) -gt [math]::Max((Get-CurveDevNs $cv), 3.0 * [double]$cv.Sig[$i]))
}

# 12.7 point 2 : comparaison de deux calibrations (« Refaire sur une autre disquette ») : fonctions pures, appelees
# par Complete-PrecompCalib, Complete-CalibRedo et Start-PrecompCalib. Aucune valeur de courbe n en depend.
function ConvertTo-EstRecords($cv) {
    # Estimations d une courbe enregistree : cylindre -> @{ Est ; Sig ; Kind }
    $d = @{}
    if (-not $cv -or -not $cv.Cyls -or -not $cv.Ys) { return $d }
    for ($i = 0; $i -lt @($cv.Cyls).Count; $i++) {
        $k = if ($cv.Kinds -and $i -lt @($cv.Kinds).Count) { [string]$cv.Kinds[$i] } else { 'interp' }
        $s = if ($cv.Sig -and $i -lt @($cv.Sig).Count) { [double]$cv.Sig[$i] } else { 5.0 }
        $d[[int]$cv.Cyls[$i]] = @{ Est = [double]$cv.Ys[$i]; Sig = $s; Kind = $k }
    }
    return $d
}

function Get-UnitEstRecords($u) {
    # Estimations d une unite de calibration (toutes passes) : cylindre -> @{ Est ; Sig ; Kind }
    $d = @{}
    foreach ($c in @($u.Est.Keys)) {
        $s = if ($u.Sig.ContainsKey($c)) { [double]$u.Sig[$c] } else { 5.0 }
        $d[[int]$c] = @{ Est = [double]$u.Est[$c]; Sig = $s; Kind = [string]$u.Kind[$c] }
    }
    return $d
}

function Get-FaceEstimates($u) {
    # Zero de chaque face d une unite d apres les seules passes de mesure gardees par face (u.Face : face -> cylindre ->
    # precomp -> @{ Shift ; SE }), pente commune de l unite ; comparaison de deux calibrations seulement, sans effet sur
    # la courbe. Renvoie face -> (cylindre -> @{ Est ; Sig ; Kind }).
    $res = @{}
    $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
    foreach ($h in @($u.Face.Keys)) {
        $d = @{}
        foreach ($c in @($u.Face[$h].Keys)) {
            $z = Get-CalibZero $u.Face[$h][$c] $sl
            if ($z) { $d[[int]$c] = @{ Est = [double]$z.Est; Sig = [double]$z.Sig; Kind = [string]$z.Kind } }
        }
        $res[[int]$h] = $d
    }
    return $res
}

function Compare-CurveRecords($X, $Y) {
    # Ecart de Y a X (ns de precomp) sur leurs cylindres encadres communs : niveau (moyenne des differences), forme
    # (ecart-type apres retrait du niveau), bruit sigma (1,4826 MAD des differences d ecart entre cylindres distants de 2
    # au plus, divise par racine 2, 10 differences au moins ; a defaut, mediane des incertitudes combinees), zones de
    # desaccord (CalCmpMinN cylindres consecutifs ou plus, meme signe, chacun au-dela de CalCmpPointNs, moyenne au-dela de
    # max(CalCmpZoneNs ; 3 sigma / racine n)) et ecarts ponctuels (au-dela de max(CalCmpSpotNs ; 4 sigma), hors zone).
    # $null si moins de 4 cylindres communs.
    $cs = @(@($X.Keys) | ForEach-Object { [int]$_ } | Where-Object { $Y.ContainsKey($_) -and [string]$X[$_].Kind -eq 'interp' -and [string]$Y[$_].Kind -eq 'interp' } | Sort-Object)
    if ($cs.Count -lt 4) { return $null }
    $d = @{}; foreach ($c in $cs) { $d[$c] = [double]$Y[$c].Est - [double]$X[$c].Est }
    $lvl = (@($cs | ForEach-Object { $d[$_] }) | Measure-Object -Average).Average
    $e = @{}; $q = 0.0
    foreach ($c in $cs) { $e[$c] = $d[$c] - $lvl; $q += $e[$c] * $e[$c] }
    $sd = [math]::Sqrt($q / ($cs.Count - 1))
    $df = @(); for ($i = 0; $i -lt $cs.Count - 1; $i++) { if ($cs[$i + 1] - $cs[$i] -le 2) { $df += $e[$cs[$i + 1]] - $e[$cs[$i]] } }
    if ($df.Count -ge 10) { $m = Get-Median $df; $sig = 1.4826 * (Get-Median @($df | ForEach-Object { [math]::Abs($_ - $m) })) / [math]::Sqrt(2.0) }
    else { $sig = Get-Median @($cs | ForEach-Object { [math]::Sqrt([double]$X[$_].Sig * [double]$X[$_].Sig + [double]$Y[$_].Sig * [double]$Y[$_].Sig) }) }
    $zones = @(); $run = @()
    foreach ($c in @($cs + @(-1))) {   # -1 : sentinelle de fin
        $ok = ($c -ge 0) -and ([math]::Abs($e[$c]) -gt $script:CalCmpPointNs)
        if ($ok -and $run.Count -gt 0 -and (($e[$c] -gt 0) -eq ($e[$run[-1]] -gt 0))) { $run += $c; continue }
        if ($run.Count -ge $script:CalCmpMinN) {
            $ma = (@($run | ForEach-Object { [math]::Abs($e[$_]) }) | Measure-Object -Average).Average
            if ($ma -gt [math]::Max($script:CalCmpZoneNs, 3.0 * $sig / [math]::Sqrt($run.Count))) {
                $zones += @{ Lo = [int]$run[0]; Hi = [int]$run[-1]; N = $run.Count; Mean = (@($run | ForEach-Object { $e[$_] }) | Measure-Object -Average).Average }
            }
        }
        $run = @(); if ($ok) { $run = @($c) }   # affectation directe : un if deroulerait le tableau d un element
    }
    $spotT = [math]::Max($script:CalCmpSpotNs, 4.0 * $sig)
    $spots = @($cs | Where-Object { $cc = $_; [math]::Abs($e[$cc]) -gt $spotT -and @($zones | Where-Object { $cc -ge $_.Lo -and $cc -le $_.Hi }).Count -eq 0 } | ForEach-Object { @{ C = [int]$_; E = $e[$_] } })
    # Ecart maximal : a egalite, le plus petit cylindre (Sort-Object n est pas stable sous Windows PowerShell 5.1)
    $mc = @($cs | Sort-Object @{ Expression = { -[math]::Abs($e[$_]) } }, @{ Expression = { $_ } })[0]
    return @{ N = $cs.Count; Level = $lvl; Shape = $sd; Sigma = $sig; Zones = $zones; Spots = $spots; MaxC = [int]$mc; MaxE = $e[$mc] }
}

function Test-CalibRedoOffer([bool]$restore, [bool]$redoActive, [string[]]$kinds) {
    # Bouton « Refaire sur une autre disquette » : hors restauration et hors calibration B, pour une reserve qui peut venir
    # du support (toutes sauf la derive du lecteur, la courbe eloignee des mesures et, 12.7, la vitesse du lecteur)
    if ($restore -or $redoActive) { return $false }
    return (@(@($kinds) | Where-Object { $_ -and @('drift', 'dev', 'speed') -notcontains $_ }).Count -gt 0)
}

function Get-CalibRedoPick($dA, $dB, $sA, $sB, $surfA, $surfB, [int]$supA, [int]$supB, [int]$ncA, [int]$ncB, [bool]$zone) {
    # Courbe conseillee. Zone de desaccord entre A et B ($zone) : 1) ecart local moyen a la calibration precedente sur les
    # cylindres de la zone, niveau retire ($dA, $dB ; $null : non comparable), plus faible d au moins CalCmpLocalNs ; sinon
    # 2) seule disquette sans defaut au controle de surface ; sinon aucune (zone non attribuable). Sans zone : 1) forme
    # globale la plus proche de la calibration precedente ($sA, $sB), plus faible d au moins max(CalCmpPrefNs ;
    # CalCmpPrefFrac x l autre) ; 2) controle de surface ; 3) moins de reserves liees au support ; 4) moins de cylindres non
    # converges. Renvoie @{ Pick = 'A' | 'B' | $null ; By = 'zone' | 'prev' | 'surface' | 'support' | 'nonconv' | '' }
    $dfA = [bool]($surfA -and $surfA.Defective); $dfB = [bool]($surfB -and $surfB.Defective)
    $surfPick = $null
    if ($surfA -and $surfB -and $dfA -ne $dfB) { $surfPick = if ($dfA) { 'B' } else { 'A' } }
    if ($zone) {
        if ($null -ne $dA -and $null -ne $dB) {
            if ([double]$dA - [double]$dB -ge $script:CalCmpLocalNs) { return @{ Pick = 'B'; By = 'zone' } }
            if ([double]$dB - [double]$dA -ge $script:CalCmpLocalNs) { return @{ Pick = 'A'; By = 'zone' } }
        }
        if ($surfPick) { return @{ Pick = $surfPick; By = 'surface' } }
        return @{ Pick = $null; By = '' }
    }
    if ($null -ne $sA -and $null -ne $sB) {
        if ([double]$sB -le [double]$sA - [math]::Max($script:CalCmpPrefNs, $script:CalCmpPrefFrac * [double]$sA)) { return @{ Pick = 'B'; By = 'prev' } }
        if ([double]$sA -le [double]$sB - [math]::Max($script:CalCmpPrefNs, $script:CalCmpPrefFrac * [double]$sB)) { return @{ Pick = 'A'; By = 'prev' } }
    }
    if ($surfPick) { return @{ Pick = $surfPick; By = 'surface' } }
    if ($supA -ne $supB) { return @{ Pick = $(if ($supA -lt $supB) { 'A' } else { 'B' }); By = 'support' } }
    if ($ncA -ne $ncB) { return @{ Pick = $(if ($ncA -lt $ncB) { 'A' } else { 'B' }); By = 'nonconv' } }
    return @{ Pick = $null; By = '' }
}

function Get-CalibUnitKey($cal, $u) {
    # Cle de courbe d une unite de calibration : famille (courbe commune) ou famille_hN (une courbe par tete)
    if ($null -eq $u.Head) { return [string]$cal.Family }
    return "$($cal.Family)_h$($u.Head)"
}

function Get-CalibRedoMismatch($A, [string]$family, [int[]]$cyls, [bool]$slow, [bool]$fine, [string]$drive, [string]$img, $geom) {
    # Controle d identite de la calibration B avant le premier gw : '' si ses reglages sont ceux de la calibration A,
    # sinon le nom du premier reglage different
    if ([string]$A.Drive -ne $drive) { return (T 'lecteur') }
    if (([string]$A.Mode -eq 'fine') -ne $fine) { return (T 'mode de test') }
    if ([bool]$A.Slow -ne $slow) { return (T 'courbe par tête') }
    if ([string]$A.Family -ne $family) { return (T 'famille') }
    # Cylindres de test de depart de A (Cyls0) : Cyls s etend aux mesures complementaires du test standard (Start-CalibDensify)
    $a0 = if ($null -ne $A.Cyls0) { @($A.Cyls0) } else { @($A.Cyls) }
    if (($a0 -join ',') -ne (@($cyls) -join ',')) { return (T 'cylindres de test') }
    if ([bool]$A.Home -ne [bool]$geom) { return (T 'type de disquette') }
    if ($A.Home -and [string]$A.Geom.Fmt -ne [string]$geom.Fmt) { return (T 'type de disquette') }
    if (-not $A.Home -and [string]$A.Image -ne $img) { return (T 'image') }
    return ''
}

function Format-CalibSurfaceState($sf) {
    # Etat du controle de surface d une calibration, pour la fenetre de comparaison
    if (-not $sf) { return (T 'non fait') }
    $nb = @($sf.Bad).Count
    if ($sf.Defective) { return ((T "disquette douteuse, {0} piste(s) défectueuse(s)") -f "$nb") }
    if ($nb -gt 0) { return ((T "{0} piste(s) défectueuse(s)") -f "$nb") }
    return (T 'aucun défaut')
}

function Get-CalibRedoReport($r, $cal, [string[]]$issues, [string[]]$kinds) {
    # Comparaison des calibrations A ($r = $script:CalRedo : objet $cal de A, courbes et reserves) et B ($cal, deja
    # enregistree dans PrecompCurves), sans fusion : par face, niveau, forme, zones de desaccord et ecarts ponctuels sur
    # les estimations des passes de mesure (Get-FaceEstimates) ; par courbe, ecart des valeurs appliquees ; forme de A et
    # de B face a la calibration d avant A ; courbe conseillee (Get-CalibRedoPick). Rien n est enregistre : journal seul.
    # Renvoie @{ Text ; Log ; Curves (copies A puis B, champ Series) ; Zones (@{ Lo ; Hi ; Head }) ; Pick }.
    $A = $r.ACal
    $sup = @('nonconv', 'sat', 'floor', 'contra', 'contra-nodrift', 'surface')
    $k0 = Get-CalibUnitKey $cal $cal.Units[0]
    $bDate = if ($script:PrecompCurves[$k0]) { [string]$script:PrecompCurves[$k0].Date } else { '' }
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add(((T "Comparaison des calibrations A ({0}) et B ({1}) du lecteur {2}, faites avec les mêmes réglages sur deux disquettes :") -f "$($r.ADate)", "$bDate", "$($cal.Drive)"))
    $zd = @(); $flag = @(); $maxShape = 0.0; $maxLvl = 0.0; $nCmp = 0
    for ($i = 0; $i -lt @($A.Units).Count; $i++) {
        $ua = $A.Units[$i]; $ub = $cal.Units[$i]
        $fa = Get-FaceEstimates $ua; $fb = Get-FaceEstimates $ub
        foreach ($h in 0, 1) {
            # Face absente des deux calibrations (unite de l autre tete) : rien ; absente d une seule : trop peu de cylindres
            if (-not $fa.ContainsKey($h) -and -not $fb.ContainsKey($h)) { continue }
            $c = if ($fa.ContainsKey($h) -and $fb.ContainsKey($h)) { Compare-CurveRecords $fa[$h] $fb[$h] } else { $null }
            if (-not $c) { $L.Add('  ' + ((T "face {0} : trop peu de cylindres encadrés par les deux calibrations pour les comparer") -f "$h")); continue }
            $nCmp++
            $zt = if (@($c.Zones).Count) { (T "zones de désaccord : {0}") -f ((@($c.Zones) | ForEach-Object { "c$($_.Lo)-c$($_.Hi) ($('{0:+0;-0;0}' -f [math]::Round($_.Mean)) ns)" }) -join ', ') } else { (T 'aucune zone de désaccord') }
            if (@($c.Spots).Count) { $zt += ' ; ' + ((T "écarts ponctuels : {0}") -f ((@($c.Spots) | ForEach-Object { "c$($_.C) ($('{0:+0;-0;0}' -f [math]::Round($_.E)) ns)" }) -join ', ')) }
            $L.Add('  ' + ((T "face {0} : niveau B − A {1} ns, écart de forme {2} ns (au plus {3} ns à c{4}), {5}") -f "$h", ('{0:+0;-0;0}' -f [math]::Round($c.Level)), (Format-UiNum $c.Shape), (Format-UiNum ([math]::Round([double]$c.MaxE, 1)) '+0.#;-0.#;0'), "$($c.MaxC)", $zt))
            foreach ($z in @($c.Zones)) { $zd += @{ Lo = [int]$z.Lo; Hi = [int]$z.Hi; Head = $h; Unit = $i }; $flag += ((T "face {0} : {1}") -f "$h", "c$($z.Lo)-c$($z.Hi)") }
            foreach ($s in @($c.Spots)) { $zd += @{ Lo = [int]$s.C; Hi = [int]$s.C; Head = $h; Unit = $i }; $flag += ((T "face {0} : {1}") -f "$h", "c$($s.C)") }
            if ($c.Shape -gt $maxShape) { $maxShape = $c.Shape }
            if ([math]::Abs($c.Level) -gt $maxLvl) { $maxLvl = [math]::Abs($c.Level) }
        }
        $key = Get-CalibUnitKey $cal $ub
        $cvA = $r.ACurves[$key]; $cvB = $script:PrecompCurves[$key]
        if ($cvA -and $cvB) {
            $pa = @($cvA.Values); $pb = @($cvB.Values); $nn = [math]::Min($pa.Count, $pb.Count)
            if ($nn -gt 0) {
                $dd = @(for ($k = 0; $k -lt $nn; $k++) { [int]$pb[$k] - [int]$pa[$k] }) | Measure-Object -Average -Minimum -Maximum
                $L.Add('  ' + ((T "{0}courbe B − A : de {1} à {2} ns, {3} ns en moyenne") -f "$($ub.Prefix)", ('{0:+0;-0;0}' -f $dd.Minimum), ('{0:+0;-0;0}' -f $dd.Maximum), ('{0:+0;-0;0}' -f [math]::Round($dd.Average))))
            }
        }
    }
    if ([string]$A.Mode -eq 'std') { $L.Add((T "Test standard : la comparaison ne porte que sur les cylindres testés ; un défaut situé entre deux cylindres testés n'est pas vu.")) }
    $L.Add(((T "Réserves de A : {0}") -f $(if (@($r.AIssues).Count) { @($r.AIssues) -join ' ; ' } else { (T 'aucune') })))
    $L.Add(((T "Réserves de B : {0}") -f $(if (@($issues).Count) { @($issues) -join ' ; ' } else { (T 'aucune') })))
    $L.Add(((T "Contrôle de surface de la première passe : A {0} ; B {1}.") -f (Format-CalibSurfaceState $A.Surf), (Format-CalibSurfaceState $cal.Surf)))
    # Calibration d avant A (meme lecteur, motif de test) : forme de A et de B, niveau retire
    $sA = @(); $sB = @(); $pvWhy = ''; $pvDate = ''; $pvDrive = ''; $lA = @(); $lB = @()
    for ($i = 0; $i -lt @($A.Units).Count; $i++) {
        $pv = $r.PrevA.Curves[(Get-CalibUnitKey $cal $cal.Units[$i])]
        if (-not $pv) { $pvWhy = 'none'; break }
        if ([string]$pv.Drive -ne [string]$A.Drive) { $pvWhy = 'drive'; $pvDrive = [string]$pv.Drive; break }
        if ($pv.Method -and [string]$pv.Method -ne 'motif') { $pvWhy = 'content'; break }
        $pr = ConvertTo-EstRecords $pv; $xa = Get-UnitEstRecords $A.Units[$i]; $xb = Get-UnitEstRecords $cal.Units[$i]
        $ca = Compare-CurveRecords $pr $xa; $cb = Compare-CurveRecords $pr $xb
        if (-not $ca -or -not $cb) { $pvWhy = 'few'; break }
        $sA += $ca.Shape; $sB += $cb.Shape; $pvDate = [string]$pv.Date
        # Zones et ecarts ponctuels de cette unite : ecart local de A et de B a la calibration precedente, niveau retire
        foreach ($z in @($zd | Where-Object { $_.Unit -eq $i })) {
            for ($c = $z.Lo; $c -le $z.Hi; $c++) {
                if (-not $pr.ContainsKey($c) -or -not $xa.ContainsKey($c) -or -not $xb.ContainsKey($c)) { continue }
                if ([string]$pr[$c].Kind -ne 'interp' -or [string]$xa[$c].Kind -ne 'interp' -or [string]$xb[$c].Kind -ne 'interp') { continue }
                $lA += [math]::Abs(([double]$xa[$c].Est - [double]$pr[$c].Est) - $ca.Level)
                $lB += [math]::Abs(([double]$xb[$c].Est - [double]$pr[$c].Est) - $cb.Level)
            }
        }
    }
    $mA = $null; $mB = $null; $dA = $null; $dB = $null
    if (-not $pvWhy) {
        $mA = ($sA | Measure-Object -Average).Average; $mB = ($sB | Measure-Object -Average).Average
        $L.Add(((T "Écart de forme avec la calibration précédente du {0} : A {1} ns, B {2} ns.") -f "$pvDate", (Format-UiNum $mA), (Format-UiNum $mB)))
        if ($lA.Count -gt 0) {
            $dA = ($lA | Measure-Object -Average).Average; $dB = ($lB | Measure-Object -Average).Average
            $L.Add(((T "Sur les cylindres en désaccord, écart à la calibration précédente du {0}, niveau retiré : A {1} ns, B {2} ns.") -f "$pvDate", (Format-UiNum $dA), (Format-UiNum $dB)))
        }
    } else {
        switch ($pvWhy) {
            'none'    { $L.Add((T 'Aucune calibration précédente de cette famille : pas de comparaison de forme avec elle.')) }
            'drive'   { $L.Add(((T "La calibration précédente de cette famille vient du lecteur {0} : elle ne sert pas de comparaison.") -f "$pvDrive")) }
            'content' { $L.Add((T "La calibration précédente a été mesurée sur le contenu d'une image : elle ne sert pas de comparaison.")) }
            default   { $L.Add((T 'Trop peu de cylindres encadrés en commun avec la calibration précédente : pas de comparaison de forme avec elle.')) }
        }
    }
    if ($flag.Count) { $L.Add(((T "Écart propre à une disquette ({0}) : défaut probable de l'une des deux disquettes ; la comparaison seule ne dit pas laquelle.") -f ($flag -join ' ; '))) }
    elseif ($nCmp -eq 0) { $L.Add((T "Aucune face n'a pu être comparée : pas de verdict de forme.")) }
    elseif ($maxShape -le $script:LevelTauOk) { $L.Add((T 'Forme commune aux deux disquettes : elle vient du lecteur.')) }
    elseif ($maxShape -le $script:LevelTauMax) { $L.Add(((T "Formes proches sur les deux disquettes (écart de forme jusqu'à {0} ns), sans zone de désaccord.") -f (Format-UiNum $maxShape))) }
    else { $L.Add(((T "Formes différentes sur les deux disquettes (écart de forme jusqu'à {0} ns), sans zone localisée : lecteur instable, ou supports très différents.") -f (Format-UiNum $maxShape))) }
    # Niveau tres different : seuil de la calibration rapide (double densite) ; haute densite : seuil x CalHdK, et pas de
    # calibration rapide pour mesurer ce niveau (12.7)
    $hdCmp = ([string]$cal.Family -eq 'hd')
    $fatNs = if ($hdCmp) { $script:LevelFatigueNs * $script:CalHdK } else { $script:LevelFatigueNs }
    if ($maxLvl -gt $fatNs) {
        if ($hdCmp) { $L.Add(((T "Niveau très différent d'une disquette à l'autre (jusqu'à {0} ns) : la haute densité n'a pas encore de calibration rapide pour mesurer ce niveau sur chaque disquette à écrire.") -f "$([math]::Round($maxLvl))")) }
        else { $L.Add(((T "Niveau très différent d'une disquette à l'autre (jusqu'à {0} ns) : la calibration rapide mesure ce niveau sur chaque disquette à écrire.") -f "$([math]::Round($maxLvl))")) }
    }
    $supA = @(@($r.AKinds) | Where-Object { $sup -contains $_ }).Count; $supB = @(@($kinds) | Where-Object { $sup -contains $_ }).Count
    if ($supA -gt 0 -and $supB -gt 0) { $L.Add((T 'Les deux calibrations ont des réserves liées au support : deux disquettes défectueuses, ou un lecteur instable (préchauffage, têtes à nettoyer).')) }
    if (@(@($r.AKinds) + @($kinds)) -contains 'drift') { $L.Add(((T "Une des deux calibrations a une dérive du lecteur de plus de {0} ns : la comparaison est peu concluante.") -f "$(2 * $script:CalResidual)")) }
    $ncA = [int](@($A.Units | ForEach-Object { @($_.Warn.NonConv).Count }) | Measure-Object -Sum).Sum
    $ncB = [int](@($cal.Units | ForEach-Object { @($_.Warn.NonConv).Count }) | Measure-Object -Sum).Sum
    $pk = Get-CalibRedoPick $dA $dB $mA $mB $A.Surf $cal.Surf $supA $supB $ncA $ncB ($flag.Count -gt 0)
    switch ($pk.By) {
        'zone'    { $L.Add(((T "Courbe {0} conseillée : sur les cylindres en désaccord, elle est la plus proche de la calibration précédente du {1}. Ce critère suppose que cette calibration a été faite sur une disquette saine.") -f "$($pk.Pick)", "$pvDate")) }
        'prev'    { $L.Add(((T "Courbe {0} conseillée : sa forme est la plus proche de la calibration précédente du {1}. Ce critère suppose que cette calibration a été faite sur une disquette saine.") -f "$($pk.Pick)", "$pvDate")) }
        'surface' { $L.Add(((T "Courbe {0} conseillée : sa disquette n'a pas de défaut au contrôle de surface, contrairement à l'autre.") -f "$($pk.Pick)")) }
        'support' { $L.Add(((T 'Courbe {0} conseillée : elle a moins de réserves liées au support.') -f "$($pk.Pick)")) }
        'nonconv' { $L.Add(((T 'Courbe {0} conseillée : elle a moins de cylindres non convergés.') -f "$($pk.Pick)")) }
        default   {
            if ($flag.Count) { $L.Add((T "Aucune courbe n'est conseillée : rien ne permet d'attribuer la zone de désaccord à l'une des deux disquettes. Une troisième calibration, sur une autre disquette, peut trancher.")) }
            else { $L.Add((T "Aucune courbe n'est conseillée : choisissez d'après la comparaison et les réserves.")) }
        }
    }
    $log = @($L.ToArray())
    $L.Add('')
    $L.Add((T "Conserver la courbe B : elle reste enregistrée.`nConserver la courbe A : la courbe A est rétablie et enregistrée.`nAbandonner les deux : la calibration d'avant la calibration A est rétablie.`nFermer la fenêtre : la courbe B est conservée."))
    $cv = @()
    foreach ($k in @($r.AKeys)) { if ($r.ACurves[$k]) { $x = $r.ACurves[$k].Clone(); $x.Series = 'A'; $cv += $x } }
    foreach ($k in @($r.AKeys)) { if ($script:PrecompCurves[$k]) { $x = $script:PrecompCurves[$k].Clone(); $x.Series = 'B'; $cv += $x } }
    return @{ Text = ($L.ToArray() -join "`n"); Log = $log; Curves = $cv; Zones = $zd; Pick = $pk.Pick }
}
