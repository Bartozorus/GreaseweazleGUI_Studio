# ============================== FONCTIONS : CALIBRATION : MESURE, DERIVE, REPRISE ===

function New-CalibUnit($head) {
    # Unite de calibration : les deux tetes ensemble (Head = $null, profil commun) ou une seule tete (ecriture lente).
    # 12.7 : Face (tete -> cylindre -> mesures des passes de mesure, sans effet sur la courbe) ; OneFace ('c|tete' : cylindre
    # de la courbe commune mesure sans cette face a une passe au moins)
    # 12.9 (correction 2) : Coarse (cylindre -> mesures brutes des passes de mesure par face, carre latin), CoarseZ (cylindre ->
    # mesures de l unite par passe, decalage de passe retire : Get-CalibDents), PassAlpha (face -> decalages estimes)
    # 12.9 : VOff (decalage commun de l ecriture de la derniere verification complete, Get-VerifyOffset : @{ V ; M ; E ; N ;
    # Removed }, pose par Invoke-CalibAnalysis ; $null tant qu aucune verification complete n a ete jugee)
    # 12.10 : VSlope (erreur de modele aux forts besoins de la derniere verification complete, Get-VerifySlope : @{ V ; B ;
    # SB ; A ; N ; Ok ; Why }) ; SlopeBad : cylindres de la tendance a corriger a cette verification (consomme par le jugement)
    $prefix = if ($null -eq $head) { '' } else { ((T '[tête {0}] ') -f "$head") }
    return @{ Head = $head; Prefix = $prefix; Results = @{}; Est = @{}; Sig = @{}; Kind = @{}; Bracket = @{}; Warn = $null; Fit = $null; Slope = $null; Profile = ''; Verify = @{}
              Dense = @{}; VerifyList = $null; VerifyP = @{}; Outliers = @(); Own = @{}; Trend = @{}; VerifyPrev = @{}; Witness = @(); ReadLast = @{}; Writes = @{}; WitCand = 0; WitMin = 0
              EstPass = @{}; Face = @{}; OneFace = @{}; DriftHold = $null; Coarse = @{}; CoarseZ = @{}; PassAlpha = @{}; VOff = $null; VSlope = $null; SlopeBad = $null }
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

# --- Calibration croisee (12.10) ---------------------------------------------------
# La source (lecteur du bandeau, $cal.Drive) ecrit le motif, la cible le relit ; la disquette passe de l un a l autre a la
# main (Invoke-CalibSwap, 270). Courbe enregistree sous « source>cible|cle » (Get-CalibStoreDrive), champ Target = cible.

function Get-CalibDriveArgsFor([string]$verb) {
    # 12.10 : arguments de lecteur (--drive, --device) des commandes gw d une calibration. Calibration croisee
    # ($script:Cal.Cross = @{ Src ; Tgt }) : erase, write et prechauffage sur la source, le lecteur qui ecrit ; read sur
    # la cible, le lecteur qui relit ; port du bandeau. Sinon Get-CommonArgs (lecteur du bandeau), comme avant
    $cal = $script:Cal
    if (-not $cal -or -not $cal.Cross) { return @(Get-CommonArgs) }
    $d = if ($verb -eq 'read') { [string]$cal.Cross.Tgt } else { [string]$cal.Cross.Src }
    $a = @("--drive=$d")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    return $a
}

function Get-CalibStoreDrive($cal) {
    # 12.10 : lecteur de magasin des courbes d une calibration (Set-DriveCurve, Get-CalibSnapshot, Backup-ConfigBeforeRef) :
    # « source>cible » pour une calibration croisee, sinon le lecteur de la calibration
    if ($cal -and $cal.Cross) { return "$($cal.Cross.Src)>$($cal.Cross.Tgt)" }
    return [string]$cal.Drive
}

function Split-CrossDrive([string]$drive) {
    # 12.10 : lecteur de magasin « source>cible » d une courbe croisee -> @{ Src ; Tgt } ; $null pour un lecteur ordinaire
    if ($drive -match '^([^>|]+)>([^>|]+)$') { return @{ Src = [string]$Matches[1]; Tgt = [string]$Matches[2] } }
    return $null
}

function Get-CrossCalibTargets([string[]]$ids, [string]$src) {
    # 12.10 : lecteurs cibles possibles d une calibration croisee : ceux de la liste du bandeau, sauf la source ; tableau
    # protege par la virgule (pas de @() autour de l appel)
    return ,@(@($ids) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -ne $src })
}

function Get-CrossSwapEstimate([int]$nPassEst, [bool]$fine, [int]$maxRetest) {
    # 12.10 : echanges de disquette d une calibration croisee (E) : deux par passe (vers la cible avant la relecture, retour
    # vers la source avant l ecriture suivante), sauf apres la derniere relecture ; au plus, avec l encadrement, les
    # mesures complementaires du test standard (2) et le nouvel essai
    $n = [math]::Max(1, $nPassEst)
    $extra = 1 + $(if ($fine) { 0 } else { 2 }) + [math]::Max(0, $maxRetest)
    return @{ Min = (2 * $n - 1); Max = (2 * ($n + $extra) - 1) }
}

function Get-CurveKeyLabel([string]$key) {
    # 'std' -> « Standard 2 us (commune) », 'long_h1' -> « Long track 1,89 us (tete 1) » ; 12.10 : une cle de magasin
    # (« lecteur|cle ») donne le libelle de sa cle de courbe, sans le lecteur (Get-DriveCurveLabel l ajoute)
    $k = (Split-DriveCurveKey $key).Key
    $fam = if ($k -like 'hd*') { 'hd' } elseif ($k -like 'long*') { 'long' } else { 'std' }
    $kind = if ($k -match '_h(\d)$') { (T "tête {0}") -f "$($Matches[1])" } else { (T 'commune') }
    return ("{0} ({1})" -f (Get-CalibFamilyName $fam), $kind)
}

# --- Courbes par lecteur (12.10) ----------------------------------------------------
# Magasin $script:DriveCurves (560) : « lecteur|cle » -> courbe ; $script:PrecompCurves : vue du lecteur courant (bandeau),
# que tout le code existant continue de lire. Toute ecriture d une courbe passe par Set-DriveCurve ; la vue est reconstruite
# par Sync-PrecompCurves au chargement (Load-Config), au changement de lecteur du bandeau (520) et a la remise a zero.

function Get-DriveCurveKey([string]$drive, [string]$key) {
    # Cle de magasin d une courbe : « lecteur|cle » (lecteur qui ecrit ; courbe croisee : « source>cible|cle »)
    return "$drive|$key"
}

function Split-DriveCurveKey([string]$storeKey) {
    # Cle de magasin -> @{ Drive ; Key } ; une cle de courbe seule (sans « | ») est celle du lecteur courant
    $i = $storeKey.LastIndexOf('|')
    if ($i -lt 0) { return @{ Drive = [string]$cmbDrive.Text; Key = $storeKey } }
    return @{ Drive = $storeKey.Substring(0, $i); Key = $storeKey.Substring($i + 1) }
}

function Get-DriveCurve([string]$drive, [string]$key) {
    # Courbe du magasin pour un lecteur et une cle de courbe ; $null sans courbe
    if ($null -eq $script:DriveCurves) { return $null }
    return $script:DriveCurves[(Get-DriveCurveKey $drive $key)]
}

function Set-DriveCurve([string]$drive, [string]$key, $cv) {
    # Seule ecriture d une courbe : magasin (entree retiree quand $cv est $null), puis vue du lecteur courant quand $drive
    # est celui du bandeau. Appelee a la fin d une calibration (270), a la conservation des courbes d un autre calcul
    # (Resolve-OldCalibrations), au retablissement (Restore-CalibState) et au chargement (Import-DriveCurves)
    if ($null -eq $script:DriveCurves) { $script:DriveCurves = @{} }
    $sk = Get-DriveCurveKey $drive $key
    if ($null -eq $cv) { $script:DriveCurves.Remove($sk) } else { $script:DriveCurves[$sk] = $cv }
    if ($drive -eq [string]$cmbDrive.Text) { $script:PrecompCurves[$key] = $cv }
}

function Sync-PrecompCurves([string]$drive = '') {
    # Vue du lecteur courant (ou de $drive) reconstruite pour les neuf cles : PrecompCurves[k] = DriveCurves["lecteur|k"],
    # sinon $null. Profils de famille standard et long track : Spec de la courbe commune de ce lecteur, sinon profil
    # d origine (un lecteur sans calibration ecrit avec le profil d origine, jamais avec la courbe d un autre lecteur ;
    # la haute densite tire deja son profil de sa courbe, Get-HdProfile)
    if (-not $drive) { $drive = [string]$cmbDrive.Text }
    foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = Get-DriveCurve $drive $k }
    $cs = $script:PrecompCurves['std']; $cl = $script:PrecompCurves['long']
    $script:PrecompStd = $(if ($cs -and $cs.Spec) { [string]$cs.Spec } else { $script:PrecompStdDefault })
    $script:PrecompLong = $(if ($cl -and $cl.Spec) { [string]$cl.Spec } else { $script:PrecompLongDefault })
}

function Get-DriveCurveKeys([string]$drive = '') {
    # Cles de magasin des courbes presentes, triees ; $drive : celles de ce lecteur seulement
    if ($null -eq $script:DriveCurves) { return @() }
    $ks = @($script:DriveCurves.Keys | Where-Object { $script:DriveCurves[$_] })
    if ($drive) { $ks = @($ks | Where-Object { (Split-DriveCurveKey $_).Drive -eq $drive }) }
    return @($ks | Sort-Object)
}

function Get-DriveCurveLabel([string]$storeKey) {
    # « Standard 2 us (commune), lecteur A » : libelle d une cle de magasin (listes de Load-Config, Resolve-OldCalibrations,
    # Reset-CalibProfiles) ; cle croisee « source>cible » (12.10) : « ..., ecriture par le lecteur A pour le lecteur 0 »
    $p = Split-DriveCurveKey $storeKey
    $x = Split-CrossDrive ([string]$p.Drive)
    if ($x) { return ((T "{0}, écriture par le lecteur {1} pour le lecteur {2}") -f (Get-CurveKeyLabel $p.Key), "$($x.Src)", "$($x.Tgt)") }
    return ((T "{0}, lecteur {1}") -f (Get-CurveKeyLabel $p.Key), "$($p.Drive)")
}

function Resolve-OldCalibrations {
    # Calibrations d un autre calcul (Load-Config) : conserver ou recalibrer. Fermeture de la fenetre : decision remise au
    # prochain demarrage, calibrations gardees dans la configuration mais non utilisees d ici la.
    $o = $script:OldCalib
    if (-not $o) { return }
    $items = @(@($o.Curves.Keys) | ForEach-Object { $cv = $o.Curves[$_]; (T "{0} : calcul {1}, lecteur {2}, {3}") -f (Get-CurveKeyLabel $_), (Get-CurveCalcText $cv -Plain), "$($cv.Drive)", "$($cv.Date)" })
    $txt = ((T "Ces calibrations ont été faites avec un autre calcul de calibration que le calcul actuel (v{0}) :") -f "$($script:CalibCalc)") + "`n" + ((@($items) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" +
           (T "Recalibrer (conseillé) : ces calibrations sont abandonnées et leurs profils reviennent aux valeurs d'origine. Recalibrez chaque lecteur concerné depuis la carte « Calibrer le lecteur » de l'Accueil, sur une disquette sacrifiée ; d'ici là, en « Test rapide », l'écriture d'une image calibrable est refusée.`nConserver ces courbes : elles restent utilisées telles quelles ; la fenêtre Courbe et le journal rappellent leur calcul. Le calcul ayant changé, une nouvelle calibration peut donner une courbe plus juste.")
    # 12.10 (relecture des captures) : phrase de la 12.3 (reference du test rapide) seulement pour une courbe d un calcul
    # anterieur a 12.3 (Test-CurveCalcBefore, 230) ; elle s affichait pour toute courbe, celles du calcul 12.9 comprises
    if (@(@($o.Curves.Keys) | Where-Object { Test-CurveCalcBefore $o.Curves[$_] '12.3' }).Count -gt 0) { $txt += ' ' + (T "Une courbe antérieure à la 12.3 ne peut pas servir de référence au test rapide (pente et densité non enregistrées).") }
    $txt += "`n" + (T "Fermer la fenêtre (ou Échap) : décision au prochain démarrage ; d'ici là, ces calibrations ne sont pas utilisées.")
    # 12.9 : courbes double densite d un calcul anterieur : ce que le calcul 12.9 change (conseil de recalibrer).
    # 12.10 (captures du wiki) : paragraphe reserve aux courbes d un calcul anterieur a 12.9 (il s affichait aussi pour
    # des courbes du calcul 12.9, celles de tout utilisateur de la 12.9) ; paragraphe du calcul 12.10 pour les courbes
    # d un calcul anterieur a 12.10 ; courbe d un calcul posterieur (configuration d une version plus recente) : aucun
    if (@(@($o.Curves.Keys) | Where-Object { -not (Test-CurveHd $o.Curves[$_]) -and (Test-CurveCalcBefore $o.Curves[$_] '12.9') }).Count -gt 0) { $txt += "`n`n" + (T "Depuis le calcul 12.9, la calibration double densité conditionne le lecteur par une écriture avant de mesurer, répartit ses niveaux de mesure sur les cylindres et suit une baisse locale du besoin propre au lecteur. Les courbes double densité d'un calcul antérieur pouvaient être trop hautes de quelques nanosecondes sur les premiers cylindres, et rester non convergées autour d'une telle baisse : recalibrer est conseillé.") }
    # 12.10 (relecture des captures) : paragraphe du calcul 12.10 juste aussi pour une courbe anterieure a 12.9 (mesuree a
    # 0, 100 et 200 ns) : niveaux 0, 30 et 100 ns attribues au calcul 12.9, extrapolations du long track au calcul 12.9
    if (@(@($o.Curves.Keys) | Where-Object { -not (Test-CurveHd $o.Curves[$_]) -and (Test-CurveCalcBefore $o.Curves[$_] '12.10') }).Count -gt 0) { $txt += "`n`n" + (T "Depuis le calcul 12.10, la vérification corrige l'erreur de modèle d'un lecteur à fort besoin au-delà du plus fort niveau mesuré, et les passes de mesure du long track écrivent 0, 60 et 200 ns (0, 30 et 100 ns avec le calcul 12.9). Une courbe long track du calcul 12.9 reposait surtout sur des extrapolations ; sur un lecteur à fort besoin, une courbe double densité d'un calcul antérieur pouvait rester trop haute d'environ 3 ns aux cylindres intérieurs : recalibrer est conseillé.") }
    # Courbe a la borne de son calcul : conservee, elle y reste (le calcul actuel admet des valeurs plus hautes)
    $atMax = @(@($o.Curves.Keys) | Where-Object { Test-CurveAtMax $o.Curves[$_] })
    foreach ($mx in @($atMax | ForEach-Object { Get-CurveMaxNs $o.Curves[$_] } | Where-Object { $_ -lt $script:CalHardNs } | Sort-Object -Unique)) {
        $kl = @($atMax | Where-Object { (Get-CurveMaxNs $o.Curves[$_]) -eq $mx } | ForEach-Object { Get-DriveCurveLabel $_ })   # 12.10 : cle de magasin, lecteur nomme
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
    $list = (@($o.Curves.Keys | ForEach-Object { (T "{0}, calcul {1}") -f (Get-DriveCurveLabel $_), (Get-CurveCalcText $o.Curves[$_] -Plain) })) -join ' ; '   # 12.10 : lecteur nomme
    if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        # Conservees pour le calcul actuel : reprises sans question aux demarrages suivants, calcul rappele a l usage
        # 12.10 : cles de magasin « lecteur|cle » : chaque courbe retourne sous son lecteur (vue du lecteur courant mise a jour)
        foreach ($k in @($o.Curves.Keys)) { $cv = $o.Curves[$k]; $cv.KeptFor = (Get-CurveCalcRef $cv); $p = Split-DriveCurveKey $k; Set-DriveCurve $p.Drive $p.Key $cv }
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
        Append-Log ((T "Calibrations d'un autre calcul abandonnées : {0}. Ces courbes sont retirées et leurs profils reviennent aux valeurs d'origine ; recalibrez chaque lecteur concerné depuis la carte « Calibrer le lecteur » de l'Accueil (en « Test rapide », l'écriture d'une image calibrable est refusée d'ici là).") -f "$list")
        # 12.10 : les courbes du calcul actuel (haute densite du calcul 12.7, courbes deja recalibrees) restent : les nommer
        $kept = @(Get-DriveCurveKeys)
        if ($kept.Count -gt 0) { Append-Log ((T "Calibrations du calcul actuel gardées : {0}.") -f ((@($kept | ForEach-Object { Get-DriveCurveLabel $_ })) -join ' ; ')) }
    } else {
        Append-Log (T 'Calibrations d''un autre calcul : décision remise au prochain démarrage ; elles ne sont pas utilisées d''ici là.')
        return
    }
    Update-CurveButton $txtWFile.Text
    [void](Save-Config)
}

function Get-CalibResetAfterText {
    # 12.10 (relecture de la RC, fix1) : suite de l effacement des calibrations (calibrations automatiques et refus qui
    # suivent : Start-PresetWrite, Start-WriteTabWrite, Start-LevelBeforeWrite, Start-RestoreWrite), texte commun au message
    # de Reset-CalibProfiles et a l infobulle du bouton (520) ; avant : infobulle a part, sans la restauration
    return (T "Ensuite, le mode Auto applique les profils d'origine :`n- « Test standard » ou « Test fin » : « Écriture rapide » et « Écriture lente » de la Bibliothèque calibrent d'abord le lecteur ; « ÉCRIRE LA DISQUETTE » écrit sans calibrer ;`n- « Test rapide » : l'écriture d'une image calibrable en double densité est refusée sans nouvelle calibration complète du lecteur, à faire sur une disquette sacrifiée depuis la carte « Calibrer le lecteur » de l'Accueil ;`n- restauration d'une copie secteur par secteur en double densité : chaque tête est d'abord calibrée en test fin.")
}

function Reset-CalibProfiles {
    # Efface toutes les calibrations : courbes communes et par tete de toutes les familles (haute densite comprise, 12.7) ;
    # profils de famille remis aux valeurs d origine. Refuse pendant une operation (calibration, ecriture, controle, sequence en cours) ;
    # 12.8 (D20) : Get-AppBusy, donc aussi pendant une detection des lecteurs, un prechauffage ou la mesure continue
    if (Get-AppBusy) {
        [void](Show-AppMessage (T 'Opération en cours : attendre la fin de la calibration ou de l''écriture.') (T 'Effacer les calibrations') 'OK' 'Warning'); return
    }
    # 12.10 : courbes de tous les lecteurs (magasin), cles « lecteur|cle »
    $curves = @(Get-DriveCurveKeys)
    # Calibrations d un autre calcul en attente du choix : effacees aussi
    $pend = @(if ($script:OldCalib) { @($script:OldCalib.Curves.Keys | Where-Object { -not $script:DriveCurves.ContainsKey($_) }) })
    $curves = @(@($curves) + $pend | Sort-Object -Unique)
    $changed = ($script:PrecompStd -ne $script:PrecompStdDefault) -or ($script:PrecompLong -ne $script:PrecompLongDefault)
    # 12.8.1 (spec-1281 § B.5, decision du 25/10/2026) : facteurs mesures des lecteurs (mesure de la disquette sur l image)
    # effaces avec les calibrations ; 12.10 : les courbes croisees sont effacees avec les autres, le lecteur cible choisi
    # ($script:TargetDrives) est garde
    $nCm = @(@($script:ContentMeasures) | Where-Object { $_ }).Count
    if ($curves.Count -eq 0 -and -not $changed -and $nCm -eq 0) {
        [void](Show-AppMessage (T 'Aucune calibration enregistrée : les profils sont déjà ceux d''origine.') (T 'Effacer les calibrations') 'OK' 'Information'); return
    }
    $list = if ($curves.Count -gt 0) { (@($curves | ForEach-Object { Get-DriveCurveLabel $_ }) -join ' ; ') } else { (T 'aucune') }   # 12.10 : lecteur nomme
    # 12.8 (L6-TEXTES) : texte aligne sur le comportement reel. Copie de la configuration (Backup-ConfigBeforeRef, seulement
    # s il y a une courbe) ; ensuite : Bibliotheque au test standard ou fin, calibration automatique (Start-PresetWrite) ;
    # bouton ECRIRE, jamais de calibration (Start-WriteTabWrite) ; test rapide, ecriture refusee sans reference
    # (Start-LevelBeforeWrite) ; restauration secteur en double densite, calibration par tete en test fin (Start-RestoreWrite)
    $msg = (T "Effacer toutes les calibrations de précompensation ?`n`nCourbes : {0}.`nProfils de famille remis aux valeurs d'origine : standard {1}, long track {2}.`nLes niveaux de la calibration rapide et la mémoire par marque sont effacés aussi.") -f "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)"
    if ($curves.Count -gt 0) { $msg += "`n`n" + ((T "L'application ne peut pas annuler cet effacement. Elle copie d'abord la configuration dans « {0}.ref-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {0} ».") -f [System.IO.Path]::GetFileName([string]$script:ConfigFile)) }
    $msg += "`n`n" + (Get-CalibResetAfterText)
    # 12.10 (relecture de la RC) : lecteurs cibles gardes (Get-TargetDrive de chaque lecteur du bandeau) : leurs courbes
    # croisees sont effacees, les ecritures et restaurations pour eux refusees (Get-TargetWriteInfo, Get-RestoreTargetInfo) ;
    # avant : non dit, a cote des calibrations automatiques annoncees. 12.10 (relecture de la RC, fix1) : refus limites aux
    # ecritures precompensees hors profil Manuel et aux restaurations en copie secteur (cas sans effet de ces fonctions)
    $kept = @((Get-DriveIds) | ForEach-Object { $tk = Get-TargetDrive ([string]$_); if ($tk) { "$_ → $tk" } })
    if ($kept.Count -gt 0) { $msg += "`n" + ((T "- lecteur cible gardé ({0}) : les écritures précompensées pour ce lecteur cible (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée (« Calibrer pour un lecteur cible… »), ou choisissez « (même lecteur) » dans la liste « Lecteur cible ».") -f ($kept -join ', ')) }
    # 12.7 : courbe haute densite effacee : profil d origine haute densite, jamais de calibration automatique
    if (@($curves | Where-Object { (Split-DriveCurveKey "$_").Key -like 'hd*' }).Count -gt 0) { $msg += "`n" + ((T "Haute densité : profil d'origine {0}, sans calibration automatique ; recalibrez depuis la carte « Calibrer le lecteur » de l'Accueil.") -f "$($script:PrecompHdDefault)") }
    if ($nCm -gt 0) { $msg += "`n" + ((T "Les {0} facteur(s) mesuré(s) des lecteurs (mesure de la disquette sur l'image) sont effacés aussi : les écritures suivantes reprennent le facteur 1 jusqu'à une nouvelle mesure.") -f "$nCm") }
    # 12.7 : boite par Show-AppMessage (code modifie), comme les autres messages de la 12.7
    $r = Show-AppMessage $msg (T 'Effacer les calibrations') 'YesNo' 'Warning'
    if ($r -ne 'Yes') { return }
    # 12.8 (lot 1c, point 4) : copie du fichier de configuration avant l effacement des courbes (sans courbe : rien)
    [void](Backup-ConfigBeforeRef @($curves) 'reset')
    $script:DriveCurves = @{}; Sync-PrecompCurves          # 12.10 : magasin vide, vue du lecteur courant vide, profils d origine
    $script:LevelShifts = @{}; $script:OldCalib = $null
    # 12.8 (lot 1c, § 10.5) : memoires par marque effacees avec les calibrations (apres la copie ci-dessus)
    $script:LevelBrands = @()
    $script:ContentMeasures = @()                                     # 12.8.1 : facteurs mesures
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    if ($script:CurveForm -and -not $script:CurveForm.IsDisposed) { $script:CurveForm.Close() }
    Update-PrecompForImage $txtWFile.Text
    $pbWCal.Visible = $false; $lblWCal.Visible = $true; $lblWCal.Text = (T 'Calibrations effacées.')
    Append-Log ((T "Calibrations effacées : {0} courbe(s) ({1}) ; profils standard et long track remis aux valeurs d'origine ({2} ; {3}).") -f "$($curves.Count)", "$list", "$($script:PrecompStdDefault)", "$($script:PrecompLongDefault)")
    if ($nCm -gt 0) { Append-Log ((T "Facteurs mesurés des lecteurs effacés avec les calibrations ({0}).") -f "$nCm") }
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

function Get-CalibLatinW([int[]]$cyls, [int[]]$levels, [int]$pass) {
    # 12.9 (correction 2) : niveau ecrit a chaque cylindre de test a la passe de mesure $pass (0..n-1), carre latin : le
    # cylindre de rang i (cylindres de test tries) recoit levels[(i + pass) mod n] ; sur les n passes, chaque cylindre recoit
    # chaque niveau une fois, et deux cylindres de test voisins n ont jamais le meme niveau a une passe (regle de
    # Get-ContentLevel, 274, appliquee cylindre par cylindre). Meme niveau pour les deux tetes. Fonction pure. Renvoie
    # cylindre -> niveau (ns)
    $w = @{}
    $cs = [int[]]@($cyls | Sort-Object -Unique)
    $n = @($levels).Count
    if ($n -eq 0) { return $w }
    for ($i = 0; $i -lt $cs.Count; $i++) { $w[$cs[$i]] = [int]$levels[($i + $pass) % $n] }
    return $w
}

function Get-ProjOrth([double[]]$v, [double[]]$e1, [double[]]$e2) {
    # Projection de v sur l orthogonal de deux vecteurs orthonormes e1 et e2 : v - (v.e1) e1 - (v.e2) e2. Fonction pure
    $d1 = 0.0; $d2 = 0.0
    for ($i = 0; $i -lt $v.Count; $i++) { $d1 += $v[$i] * $e1[$i]; $d2 += $v[$i] * $e2[$i] }
    $w = New-Object double[] $v.Count
    for ($i = 0; $i -lt $v.Count; $i++) { $w[$i] = $v[$i] - $d1 * $e1[$i] - $d2 * $e2[$i] }
    return ,$w
}

function Get-CalibPassOffsets($obs, [int[]]$levels, [int]$nPass, [int]$minCyl = 6) {
    # 12.9 (correction 2 ; modele M2 de v129\cal2\donnees\sim.py, estimate_offsets) : decalage propre a chaque passe de
    # mesure d une face. Par cylindre c et passe p : y = a_c + b_c W + somme_j g_j 1[W = L_j] (j = 2..n-1, niveaux tries)
    # + alpha_p (alpha_0 = 0). Ordonnee et pente propres retirees par projection, cylindre par cylindre, sur l orthogonal de
    # (1, W) ; restent n - 2 effets de niveau et n - 1 decalages, moindres carres non ponderes (equations normales,
    # Solve-ContentLinear, 274). Un cylindre compte s il a n mesures a n niveaux distincts (passes uniformes : systeme
    # singulier). Decalages rendus centres (somme nulle) : leur moyenne, commune a toutes les mesures, ne s identifie pas.
    # Fonction pure. $obs : lignes @{ C ; P ; W ; Y } d une face (Y : decalage lu, ns). Renvoie @{ Ok ; Why ('passes',
    # 'cylindres', 'singulier', 'ddl') ; Alpha (double[n], centres) ; SE (double[n]) ; NCyl ; Df ; S (ecart-type residuel) }
    $n = [int]$nPass
    $out = @{ Ok = $false; Why = ''; Alpha = (New-Object double[] ([math]::Max(1, $n))); SE = (New-Object double[] ([math]::Max(1, $n))); NCyl = 0; Df = 0; S = [double]::NaN }
    $lv = [int[]]@(@($levels) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $ng = [math]::Max(0, $lv.Count - 2)
    $q = $ng + $n - 1
    if ($n -lt 2 -or $q -le 0) { $out.Why = 'passes'; return $out }
    # Tableaux simples (et non List[object]) : @() sur une liste generique de hashtables echoue sous pwsh 7 (.NET 10)
    $byC = @{}
    foreach ($o in @($obs | Where-Object { $null -ne $_ })) {
        $c = [int]$o.C
        if (-not $byC.ContainsKey($c)) { $byC[$c] = @() }
        $byC[$c] += ,$o
    }
    $Gm = New-Object 'double[][]' $q
    for ($a = 0; $a -lt $q; $a++) { $Gm[$a] = New-Object double[] $q }
    $gv = New-Object double[] $q
    $kept = New-Object System.Collections.Generic.List[object]
    foreach ($c in @($byC.Keys | Sort-Object)) {
        $ob = @($byC[$c])
        $m = $ob.Count
        if ($m -ne $n) { continue }
        $wv = [double[]]@($ob | ForEach-Object { [double]$_.W })
        if (@($wv | Sort-Object -Unique).Count -ne $m) { continue }
        # Base orthonormee de (1, W)
        $e1 = New-Object double[] $m; $e2 = New-Object double[] $m
        $mw = 0.0; foreach ($x in $wv) { $mw += $x }; $mw /= $m
        $nn = 0.0
        for ($i = 0; $i -lt $m; $i++) { $e1[$i] = 1.0 / [math]::Sqrt($m); $e2[$i] = $wv[$i] - $mw; $nn += $e2[$i] * $e2[$i] }
        $nn = [math]::Sqrt($nn)
        for ($i = 0; $i -lt $m; $i++) { $e2[$i] = $e2[$i] / $nn }
        # Colonnes projetees : effets de niveau (indicatrices des niveaux 2..n-1), puis passes 1..n-1 (indicatrices)
        $Zc = New-Object 'double[][]' $q
        for ($j = 0; $j -lt $q; $j++) {
            $col = New-Object double[] $m
            for ($i = 0; $i -lt $m; $i++) {
                if ($j -lt $ng) { $col[$i] = [double]([int]$ob[$i].W -eq $lv[$j + 2]) }
                else { $col[$i] = [double]([int]$ob[$i].P -eq ($j - $ng + 1)) }
            }
            $Zc[$j] = Get-ProjOrth $col $e1 $e2
        }
        $yv = Get-ProjOrth ([double[]]@($ob | ForEach-Object { [double]$_.Y })) $e1 $e2
        for ($a = 0; $a -lt $q; $a++) {
            for ($i = 0; $i -lt $m; $i++) { $gv[$a] += $Zc[$a][$i] * $yv[$i] }
            for ($b = 0; $b -lt $q; $b++) { $s = 0.0; for ($i = 0; $i -lt $m; $i++) { $s += $Zc[$a][$i] * $Zc[$b][$i] }; $Gm[$a][$b] += $s }
        }
        $kept.Add(@{ Z = $Zc; Y = $yv })
    }
    $out.NCyl = $kept.Count
    if ($kept.Count -lt [math]::Max($minCyl, $q + 3)) { $out.Why = 'cylindres'; return $out }
    $sol = Solve-ContentLinear $Gm $gv
    if ($null -eq $sol) { $out.Why = 'singulier'; return $out }
    $ssr = 0.0
    foreach ($k in $kept) {
        for ($i = 0; $i -lt $k.Y.Count; $i++) { $r = [double]$k.Y[$i]; for ($j = 0; $j -lt $q; $j++) { $r -= $k.Z[$j][$i] * $sol[$j] }; $ssr += $r * $r }
    }
    $df = $kept.Count * ($n - 2) - $q
    if ($df -le 0) { $out.Why = 'ddl'; return $out }
    $s2 = $ssr / $df
    # Inverse de G (colonnes), pour l erreur-type des decalages centres : Var(alpha_p - moyenne) = s2 c' G^-1 c,
    # c_k = 1[k = p] - 1/n sur les decalages k = 1..n-1 (alpha_0 = 0)
    $inv = New-Object 'double[][]' $q
    for ($j = 0; $j -lt $q; $j++) {
        $ej = New-Object double[] $q; $ej[$j] = 1.0
        $colj = Solve-ContentLinear $Gm $ej
        if ($null -eq $colj) { $out.Why = 'singulier'; return $out }
        $inv[$j] = $colj
    }
    $al = New-Object double[] $n
    for ($p = 1; $p -lt $n; $p++) { $al[$p] = [double]$sol[$ng + $p - 1] }
    $mean = 0.0; foreach ($x in $al) { $mean += $x }; $mean /= $n
    for ($p = 0; $p -lt $n; $p++) {
        $v = 0.0
        for ($k1 = 1; $k1 -lt $n; $k1++) {
            $f1 = [double]($k1 -eq $p) - 1.0 / $n
            for ($k2 = 1; $k2 -lt $n; $k2++) { $f2 = [double]($k2 -eq $p) - 1.0 / $n; $v += $f1 * $f2 * $inv[$ng + $k1 - 1][$ng + $k2 - 1] }
        }
        $out.SE[$p] = [math]::Sqrt([math]::Max(0.0, $s2 * $v))
        $out.Alpha[$p] = $al[$p] - $mean
    }
    $out.Ok = $true; $out.Df = $df; $out.S = [math]::Sqrt([math]::Max(0.0, $s2))
    return $out
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

function Get-TrendEstimates($u, [int]$maxCyl, [bool]$dense, $dents = $null) {
    # Zero d un cylindre encore sous-compense au plafond des passes de mesure (CalMaxNs), extrapole de ses mesures : garde
    # tel quel s il est proche (incertitude <= CalTrendSig) avec une pente propre. Sinon combine (moyenne ponderee par
    # l inverse des variances) avec la tendance de la courbe : droite ponderee de pente >= 0 sur les CalTrendN derniers
    # cylindres fiables (incertitude <= 6 ns, ni plafonnes, ni isoles, ni eux-memes combines) qui le precedent dans le meme
    # segment croissant, a CalTrendSpan cylindres au plus (3 fois plus en test standard). Incertitude de la tendance :
    # erreur-type de la prediction (elargie si les points s ecartent de la droite) et 25 % de la hausse extrapolee depuis
    # le dernier cylindre fiable (meme regle qu une extrapolation propre).
    # Copies : u.Est, u.Sig et u.Kind restent la mesure propre (controle Dev, journal, courbe enregistree) ; type
    # transitoire 'trend' (non fiable pour SegFit), jamais enregistre. Renvoie @{ Est; Sig; Kind; Info (c -> detail) }.
    # 12.9 (correction 4) : $dents, dents de la courbe (Start-CalibFit) : segments de la courbe provisoire coupes a chaque
    # dent, la tendance ne traverse pas une dent
    $est = @{}; $sig = @{}; $kind = @{}; $info = @{}
    foreach ($k in @($u.Est.Keys)) { $est[[int]$k] = [double]$u.Est[$k]; $sig[[int]$k] = [double]$u.Sig[$k]; $kind[[int]$k] = [string]$u.Kind[$k] }
    $res = @{ Est = $est; Sig = $sig; Kind = $kind; Info = $info }
    # 12.8 (S3-HIGH) : cylindres mesures autour de leur besoin par la mesure directe (Reach, mesure complete de cette
    # disquette seulement) : zero de la corde de leurs deux ecritures, jamais combine avec la tendance
    $cand = @($est.Keys | ForEach-Object { [int]$_ } | Where-Object { $kind[$_] -eq 'extrap' -and $est[$_] -gt $script:CalMaxNs -and ($sig[$_] -gt $script:CalTrendSig -or ($u.Own -and $u.Own.ContainsKey($_) -and -not $u.Own[$_])) -and -not ($u.Reach -and $u.Reach.ContainsKey($_)) } | Sort-Object)
    if ($cand.Count -eq 0) { return $res }                      # cas courant : aucune combinaison
    $f0 = Fit-PrecompCurve $u.Est $u.Sig $maxCyl $u.Kind $dense -Dents $dents
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
        # 12.9 (correction 4) : dents locales du besoin, mesurees par les passes de mesure (cylindres testes voisins dont les
        # passes encadrent le zero : test fin en pratique), appliquees par Fit-PrecompCurve (segments croissants de SegFit,
        # CalDentMax au plus) ; Get-CalibDents en rend CalDentMax + 2 : la chute de la rupture c43/c44, rendue aussi puis
        # ecartee par Split-CurveDents, n evince pas une vraie dent
        $dc = @()
        if ($cal.Dent -and $u.CoarseZ -and $u.CoarseZ.Count -gt 0) {
            $stp = [math]::Max([double]$script:CalDevNs / [double]$script:CalStepDevDiv, [double]$script:CalResidual)
            $zk = @{}; foreach ($k in @($u.CoarseZ.Keys)) { if ([string]$u.Kind[[int]$k] -eq 'interp') { $zk[[int]$k] = $u.CoarseZ[$k] } }
            $dc = @(Get-CalibDents $zk ([double]$u.Slope) @($cal.Values).Count $stp ([int]$script:CalDentGap) ([int]$script:CalDentMax + 2))
        }
        $tr = Get-TrendEstimates $u $cal.MaxCyl $dense $dc
        $u.Trend = $tr.Info
        if ($tr.Info.Count -gt 0) {
            $tt = (@($tr.Info.Keys | Sort-Object | ForEach-Object { $ti = $tr.Info[$_]; (T "c{0} : extrapolation {1} ± {2} ns, tendance {3} ± {4} ns, retenu {5} ns") -f "$_", (Format-LevelNum $ti.Own), (Format-LevelNum $ti.OwnSig), (Format-LevelNum $ti.Trend), (Format-LevelNum $ti.TrendSig), (Format-LevelNum $ti.Est) })) -join ' ; '
            Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, zéro extrapolé incertain (loin des mesures ou sans pente propre) : combiné avec la tendance de la courbe ({1}). La vérification écrit la courbe à ces cylindres et la mesure.") -f "$($script:CalMaxNs)", "$tt"))
            $u.Fit = Fit-PrecompCurve $tr.Est $tr.Sig $cal.MaxCyl $tr.Kind $dense -Dents $dc
        } else { $u.Fit = Fit-PrecompCurve $u.Est $u.Sig $cal.MaxCyl $u.Kind $dense -Dents $dc }
        $u.Outliers = @($u.Fit.Outliers | ForEach-Object { [int]$_ } | Sort-Object)
        foreach ($c in $u.Outliers) { if ($u.Kind.ContainsKey($c)) { $u.Kind[$c] = 'outlier' } }
        $u.Profile = Build-CurveProfile $u.Fit.Values
        Append-Log ($u.Prefix + ((T "Courbe ajustée : {0} (écart réduit {1}), de {2} ns au cylindre 0 à {3} ns au cylindre {4} ; profil : {5}") -f (Get-CurveModelName $u.Fit.Model), "$([math]::Round($u.Fit.Chi, 2))", "$($u.Fit.Values[0])", "$($u.Fit.Values[-1])", "$($cal.MaxCyl)", "$($u.Profile)"))
        if ($u.Outliers.Count -gt 0) { Append-Log ($u.Prefix + ((T "Point(s) isolé(s) écarté(s) de la courbe : {0} : écart avec les cylindres voisins, défaut ponctuel probable de la disquette de calibration, non suivi.") -f (($u.Outliers | ForEach-Object { "c$_" }) -join ', '))) }
        # 12.9 (correction 4) : seules les dents appliquees par la courbe (la chute de la rupture c43/c44, ecartee, ne l est pas)
        foreach ($d in @(Get-FitDents $u.Fit)) { Append-Log ($u.Prefix + ((T "Dent locale du besoin entre c{0} et c{1} : baisse de {2} ns mesurée par les passes de mesure (au moins {3} ns à chaque passe), qui persiste au cylindre suivant : la courbe la suit ; la vérification la contrôlera.") -f "$($d.C1)", "$($d.C2)", (Format-LevelNum $d.Drop), (Format-LevelNum $d.Min))) }
        $u.Verify = @{}; $u.VerifyP = @{}; $u.VerifyList = $null; $u.VerifyPrev = @{}; $u.Witness = @(); $u.ReadLast = @{}; $u.WitCand = 0; $u.WitMin = 0; $u.DriftHold = $null; $u.VOff = $null
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

function Get-VerifyOffset($u, [int]$minCyl, [double]$sigK, [double]$maxNs, [double]$maxLevel = -1.0, [double]$homNs = -1.0) {
    # 12.9 : decalage commun de l ecriture d une verification complete (une commande gw par unite : tous les cylindres
    # estimes ecrits a la suite, comme l image). Chaque commande d ecriture decale de quelques ns tous les cylindres qu elle
    # ecrit (journal du 01/11/2026 : +3,85 ns en mediane sur 80 cylindres, 76 residus positifs sur 80) : juge cylindre par
    # cylindre, ce decalage passait pour une erreur de la courbe (24 cylindres retenus, 32 reajustes a tort). Estimateur :
    # mediane des residus bruts des cylindres verifies hors points isoles et hors limites physiques (plafond encore
    # sous-compense, plancher encore sur-compense : saturation, pas decalage d ecriture) ; erreur-type E = 1,2533 x
    # max(1 ; 1,4826 MAD) / racine de n, comme la derive des temoins (Get-VerifyDrift). Retire (Ok) si n >= minCyl, |m| > sigK E
    # et |m| <= maxNs ; sinon Why : 'cylindres' (trop peu), 'nonsig' (dans le bruit), 'borne' (au-dela de maxNs : lecteur ou
    # support instable depuis les passes de mesure, residus juges tels quels). Fonction pure : ne modifie pas l unite.
    # Banc 129-voff (N1, C5) : seuls les cylindres dont le zero est interpole entre deux niveaux mesures comptent (valeur
    # ecrite <= $maxLevel, niveau maximal des passes de mesure de la famille par defaut, et Kind 'interp' quand l unite le
    # connait) : au-dela, le residu porte l erreur de modele de l extrapolation ou de l encadrement (reponse non lineaire,
    # fort besoin), qui passerait pour un decalage d ecriture et ne serait plus corrigee. Le decalage estime vaut pour
    # toute la commande : il est retire de tous les cylindres de l unite (Invoke-CalibAnalysis).
    # Banc 129-voff2 (U4-U12, X1) : les cylindres retenus sont groupes sur la piste (besoins les plus faibles) : une erreur
    # regionale de la courbe a cet endroit passerait pour un decalage commun. Garde d homogeneite : le decalage n est retire
    # que s il est le meme ailleurs, ecart <= $homNs (CalVOffHomNs par defaut) entre la mediane des retenus et celle des
    # autres cylindres verifies (5 au moins), et entre les deux moities de la piste parmi les retenus (4 au moins chacune) ;
    # sinon Why 'regional' (Dz : ecart maximal constate, Mn : mediane des autres cylindres).
    # Renvoie @{ Ok ; Why ; M ; E ; N ; Mn ; Dz } (N : cylindres retenus pour l estimation)
    $vals = @($u.Fit.Values)
    if ($maxLevel -lt 0) { $maxLevel = [double](@($script:CalCoarse) | Measure-Object -Maximum).Maximum }
    $rn = @(); $rc = @()
    $r = @(foreach ($k in @($u.Verify.Keys)) {
        $c = [int]$k
        if (@($u.Outliers) -contains $c) { continue }
        $m = $u.Verify[$k]
        if ($null -eq $m -or $null -eq $m.Shift) { continue }
        $x = [double]$m.Shift
        if ([double]::IsNaN($x)) { continue }
        $p = $null
        if ($u.VerifyP -and $u.VerifyP.ContainsKey($c)) { $p = [int]$u.VerifyP[$c] } elseif ($c -lt $vals.Count) { $p = [int]$vals[$c] }
        if ($null -ne $p -and (($x -gt 0 -and $p -ge $script:CalHardNs) -or ($x -lt 0 -and $p -le 0))) { continue }
        if ($null -eq $p -or [double]$p -gt $maxLevel -or ($u.Kind -and $u.Kind.ContainsKey($c) -and [string]$u.Kind[$c] -ne 'interp')) { $rn += $x; continue }
        $rc += $c
        $x
    })
    $res = @{ Ok = $false; Why = ''; M = 0.0; E = [double]::NaN; N = $r.Count; Mn = [double]::NaN; Dz = 0.0 }
    if ($r.Count -lt [math]::Max(1, $minCyl)) { $res.Why = 'cylindres'; return $res }
    $m = [double](Get-Median $r)
    $s = [math]::Max(1.0, 1.4826 * [double](Get-Median @($r | ForEach-Object { [math]::Abs([double]$_ - $m) })))
    $res.M = $m; $res.E = 1.2533 * $s / [math]::Sqrt([double]$r.Count)
    if ([math]::Abs($m) -gt $maxNs) { $res.Why = 'borne'; return $res }
    if ([math]::Abs($m) -le $sigK * $res.E) { $res.Why = 'nonsig'; return $res }
    if ($homNs -lt 0) { $homNs = [double]$script:CalVOffHomNs }
    $dz = 0.0
    if ($rn.Count -ge 5) { $res.Mn = [double](Get-Median $rn); $dz = [math]::Abs($m - [double]$res.Mn) }
    $ord = @($rc | Sort-Object); $half = [int][math]::Floor($ord.Count / 2)
    if ($half -ge 4) {
        $lo = @(); $hi = @()
        for ($i = 0; $i -lt $ord.Count; $i++) { $v = [double]$u.Verify[[int]$ord[$i]].Shift; if ($i -lt $half) { $lo += $v } else { $hi += $v } }
        $dz = [math]::Max($dz, [math]::Abs([double](Get-Median $lo) - [double](Get-Median $hi)))
    }
    $res.Dz = $dz
    if ($dz -gt $homNs) { $res.Why = 'regional'; return $res }
    $res.Ok = $true
    return $res
}

function Get-VerifyOffsetM($u) {
    # 12.9 : decalage commun retire des residus de la derniere verification complete de l unite (VOff, Invoke-CalibAnalysis) ;
    # 0 sans retrait (dans le bruit, au-dela de la borne, trop peu de cylindres, haute densite, aucune verification complete)
    if ($null -ne $u -and $null -ne $u.VOff -and [bool]$u.VOff.Removed) { return [double]$u.VOff.M }
    return 0.0
}

function Get-CalLevels([string]$family) {
    # 12.10 : niveaux des passes de mesure de la famille : CalCoarse (bareme pose par Set-CalibScale), multiplies par
    # CalLevelKLong en long track, arrondis a l entier ; standard et haute densite : CalCoarse tel quel
    $k = if ($family -eq 'long') { [double]$script:CalLevelKLong } else { 1.0 }
    return [int[]]@(@($script:CalCoarse) | ForEach-Object { [int][math]::Round([double]$_ * $k) })
}

function Get-TracksAsym($tracks) {
    # 12.10 : asymetrie de reference : par piste (numero gw : 2 x cylindre + tete), moyenne sur les tours des rapports
    # 3T/2T - 1,5 et 4T/2T - 2 du motif relu (ScpStats), tours sans valeur ignores ; piste sans valeur : absente
    $out = @{}
    foreach ($tn in @($tracks.Keys)) {
        $d3 = @(); $d4 = @()
        foreach ($x in @($tracks[$tn])) {
            if ($null -eq $x -or [double]::IsNaN([double]$x.R3) -or [double]::IsNaN([double]$x.R4)) { continue }
            $d3 += ([double]$x.R3 - 1.5); $d4 += ([double]$x.R4 - 2.0)
        }
        if ($d3.Count -eq 0) { continue }
        $out[[int]$tn] = @((($d3 | Measure-Object -Average).Average), (($d4 | Measure-Object -Average).Average))
    }
    return $out
}

function Get-UnitAsymRef($cal, $u) {
    # 12.10 : asymetrie de reference de l unite pour la courbe enregistree : cylindres mesures (ordre croissant), ecarts
    # arrondis a 4 decimales ; tete de l unite, ou moyenne des deux tetes pour l unite commune ; sans releve : tableaux vides
    $res = @{ Cyl = [int[]]@(); D3 = [double[]]@(); D4 = [double[]]@() }
    if ($null -eq $cal.AsymRef -or $cal.AsymRef.Count -eq 0) { return $res }
    $heads = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
    $cyl = @(); $d3 = @(); $d4 = @()
    foreach ($c in @($cal.AsymRef.Keys | ForEach-Object { [int]([math]::Floor([int]$_ / 2)) } | Sort-Object -Unique)) {
        $a3 = @(); $a4 = @()
        foreach ($h in $heads) { $tn = 2 * $c + $h; if ($cal.AsymRef.ContainsKey($tn)) { $a3 += [double]$cal.AsymRef[$tn][0]; $a4 += [double]$cal.AsymRef[$tn][1] } }
        if ($a3.Count -eq 0) { continue }
        $cyl += $c; $d3 += [math]::Round((($a3 | Measure-Object -Average).Average), 4); $d4 += [math]::Round((($a4 | Measure-Object -Average).Average), 4)
    }
    $res.Cyl = [int[]]$cyl; $res.D3 = [double[]]$d3; $res.D4 = [double[]]$d4
    return $res
}

function Get-VerifySlope($u, [double]$maxLevel, [int]$minCyl, [double]$sigK, [double]$minSlope, [double]$minNs) {
    # 12.10 : erreur de modele aux forts besoins. Au-dela du niveau maximal des passes de mesure (CalCoarse, 100 ns), le zero
    # d un cylindre est extrapole ou encadre. Calibration TEAC du 01/11/2026 et essai 5 du 02/11/2026 (4 ecritures aux
    # profils calibres) : le residu suit la valeur ecrite, -0,045 ns/ns de 100 a 215 ns sur la tete 0 (rien sur la tete 1),
    # soit 3 ns de surcompensation aux cylindres interieurs, sous la tolerance cylindre par cylindre (CalResidual) et
    # classes ecarts locaux isoles par Get-ResidualFlags, donc jamais corriges. Estimateur : pente de Theil-Sen (mediane des
    # pentes par paires) du residu juge (Shift, centre du decalage commun) en fonction de la valeur ecrite, sur les cylindres
    # verifies ecrits au-dela de $maxLevel, hors points isoles et limites physiques (memes exclusions que Get-VerifyOffset) ;
    # niveau A = mediane de (residu - B (p - maxLevel)) ; incertitude SB = 1,2533 x max(1 ; 1,4826 MAD des residus a la
    # droite) / racine de la somme des carres des ecarts en p. Ok si n >= minCyl, |B| >= minSlope et |B| > sigK SB ; sinon
    # Why : 'cylindres' (trop peu), 'faible' (pente negligeable), 'nonsig' (dans le bruit). Fit : residu de la droite par
    # cylindre ; Bad : cylindres dont |Fit| > minNs, a corriger a leur zero mesure meme dans la tolerance
    # (Invoke-CalibAnalysis, avec les residus retenus de Get-ResidualFlags). PMin, PMax, FMin, FMax : valeurs ecrites
    # extremes et residus de la droite a ces valeurs (journal). Fonction pure : ne modifie pas l unite.
    $vals = @($u.Fit.Values)
    if ($maxLevel -lt 0) { $maxLevel = [double](@($script:CalCoarse) | Measure-Object -Maximum).Maximum }
    $pts = @()
    foreach ($k in @($u.Verify.Keys)) {
        $c = [int]$k
        if (@($u.Outliers) -contains $c) { continue }
        $m = $u.Verify[$k]
        if ($null -eq $m -or $null -eq $m.Shift) { continue }
        $x = [double]$m.Shift
        if ([double]::IsNaN($x)) { continue }
        $p = $null
        if ($u.VerifyP -and $u.VerifyP.ContainsKey($c)) { $p = [int]$u.VerifyP[$c] } elseif ($c -lt $vals.Count) { $p = [int]$vals[$c] }
        if ($null -eq $p -or [double]$p -le $maxLevel) { continue }
        if (($x -gt 0 -and $p -ge $script:CalHardNs) -or ($x -lt 0 -and $p -le 0)) { continue }
        $pts += ,@($c, [double]$p, $x)
    }
    $res = @{ Ok = $false; Why = ''; B = 0.0; SB = [double]::NaN; A = 0.0; X0 = $maxLevel; N = $pts.Count; Fit = @{}; Bad = @{}; PMin = 0.0; PMax = 0.0; FMin = 0.0; FMax = 0.0 }
    if ($pts.Count -lt [math]::Max(3, $minCyl)) { $res.Why = 'cylindres'; return $res }
    $sl = @()
    for ($i = 0; $i -lt $pts.Count; $i++) {
        for ($j = $i + 1; $j -lt $pts.Count; $j++) {
            $dx = [double]$pts[$j][1] - [double]$pts[$i][1]
            if ([math]::Abs($dx) -gt 1e-9) { $sl += (([double]$pts[$j][2] - [double]$pts[$i][2]) / $dx) }
        }
    }
    if ($sl.Count -eq 0) { $res.Why = 'cylindres'; return $res }
    $b = [double](Get-Median $sl)
    $a = [double](Get-Median @($pts | ForEach-Object { [double]$_[2] - $b * ([double]$_[1] - $maxLevel) }))
    $xm = ($pts | ForEach-Object { [double]$_[1] } | Measure-Object -Average).Average
    $sxx = 0.0; foreach ($q in $pts) { $sxx += ([double]$q[1] - $xm) * ([double]$q[1] - $xm) }
    $rr = @($pts | ForEach-Object { [double]$_[2] - ($a + $b * ([double]$_[1] - $maxLevel)) })
    $mr = [double](Get-Median $rr)
    $mad = [double](Get-Median @($rr | ForEach-Object { [math]::Abs([double]$_ - $mr) }))
    $res.B = $b; $res.A = $a
    $res.SB = if ($sxx -gt 0) { 1.2533 * [math]::Max(1.0, 1.4826 * $mad) / [math]::Sqrt($sxx) } else { [double]::NaN }
    $res.PMin = ($pts | ForEach-Object { [double]$_[1] } | Measure-Object -Minimum).Minimum
    $res.PMax = ($pts | ForEach-Object { [double]$_[1] } | Measure-Object -Maximum).Maximum
    $res.FMin = $a + $b * ([double]$res.PMin - $maxLevel); $res.FMax = $a + $b * ([double]$res.PMax - $maxLevel)
    foreach ($q in $pts) { $res.Fit[[int]$q[0]] = $a + $b * ([double]$q[1] - $maxLevel) }
    if ([math]::Abs($b) -lt $minSlope) { $res.Why = 'faible'; return $res }
    if ([double]::IsNaN($res.SB) -or [math]::Abs($b) -le $sigK * $res.SB) { $res.Why = 'nonsig'; return $res }
    foreach ($q in $pts) { if ([math]::Abs([double]$res.Fit[[int]$q[0]]) -gt $minNs) { $res.Bad[[int]$q[0]] = $true } }
    $res.Ok = $true
    return $res
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
    # 12.9 (revue RT7, M1) : passe du nouvel essai : cylindres gardes (zone non reproductible, cylindres non reproductibles :
    # DriftHold.P) exclus des temoins, leur relecture mesure la zone et non la derive du lecteur (Get-VerifyDrift calcule D
    # avant de les remettre dans Contra ou NonRepro) ; sans nouvel essai, DriftHold vide : aucun effet
    $hold = if ($u.DriftHold -and $u.DriftHold.P) { $u.DriftHold.P } else { @{} }
    $cand = @($u.Verify.Keys | ForEach-Object { [int]$_ } | Where-Object {
        @($u.VerifyList) -notcontains $_ -and @($u.Outliers) -notcontains $_ -and $u.VerifyP.ContainsKey($_) -and $_ -lt $vals.Count -and
        [int]$vals[$_] -eq [int]$u.VerifyP[$_] -and [int]$vals[$_] -gt 0 -and [int]$vals[$_] -lt $script:CalHardNs -and -not $hold.ContainsKey($_) } | Sort-Object)
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
    # 12.9 (RT7) : apres un nouvel essai, zone et cylindres non reproductibles de la verification d avant gardes
    # (DriftHold, Add-VerifyDriftHold) ; sans nouvel essai, aucun effet.
    $res = @{ Use = $false; D = 0.0; S = [double]::NaN; SRaw = [double]::NaN; E = [double]::NaN; NW = 0; NC = 0; DC = [double]::NaN; NonRepro = @{}; Sys = @{}; Contra = @{} }
    if (-not $u.VerifyPrev -or $u.VerifyPrev.Count -eq 0) { return (Add-VerifyDriftHold $u $res @('Contra', 'NonRepro')) }
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
    # 12.9 (RT7) : zone gardee avant les cylindres non reproductibles, comme une zone de cette verification
    [void](Add-VerifyDriftHold $u $res @('Contra'))
    if (-not $res.Use) { return (Add-VerifyDriftHold $u $res @('NonRepro')) }
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
    return (Add-VerifyDriftHold $u $res @('NonRepro'))
}

function Add-VerifyDriftHold($u, $res, [string[]]$fields) {
    # 12.9 (RT7, L2-b) : un nouvel essai part malgre une zone non reproductible (Contra) ou des cylindres non reproductibles
    # (NonRepro) loin des cylindres vises ; sa passe ne garde dans VerifyPrev que les cylindres qu elle relit, et
    # Get-VerifyDrift ne verrait plus ces cylindres. Start-CalibRetest les garde (DriftHold : Contra, NonRepro, et P,
    # valeur ecrite de chacun a la derniere verification d avant) ; ils sont remis dans le resultat ($res, champs $fields)
    # tant que leur valeur ecrite n a pas change : cylindre non relu, ou relu a la meme valeur (temoin de derive, voisin
    # d un cylindre vise : rien de nouveau sur la contradiction). Relu a une autre valeur : juge sur la passe. Un cylindre
    # deja dans Contra ou NonRepro de $res y reste. Zone gardee trouvee sans derive mesuree (DriftHold.Use faux) :
    # ContraNoDrift, lu par la reserve de la zone (Complete-PrecompCalib, Get-CalibUnitReserve) a la place de Use, qui ne
    # vaut que pour la passe du nouvel essai. Sans DriftHold (aucun nouvel essai) : $res inchange. Renvoie $res
    $h = $u.DriftHold
    if (-not $h -or -not $h.P) { return $res }
    foreach ($f in @($fields)) {
        if (-not $h[$f]) { continue }
        foreach ($k in @($h[$f].Keys)) {
            $c = [int]$k
            if ($res.Contra.ContainsKey($c) -or $res.NonRepro.ContainsKey($c)) { continue }
            if (-not $h.P.ContainsKey($c) -or -not $u.VerifyP -or -not $u.VerifyP.ContainsKey($c) -or [int]$u.VerifyP[$c] -ne [int]$h.P[$c]) { continue }
            $res[$f][$c] = $h[$f][$k]
            if ($f -eq 'Contra' -and -not $h.Use) { $res.ContraNoDrift = $true }
        }
    }
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
    $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers; Dents = @(Get-FitDents $u.Fit) }
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
    #  12.9 (banc cal2, RT8, G4-02 ; revue fix2) : idem pour un cylindre exclu du nouvel essai, quel que soit le motif, et
    #            absent de la relecture de son jugement (RtFull, Start-CalibRetest : piste deja ecrite WriteMax fois, valeur
    #            visee hors des limites, proximite d une zone ou de cylindres non reproductibles, valeur visee inchangee de
    #            la mesure complete) : il garde le residu de la derniere verification d avant le nouvel essai.
    $nonConv = @(); $sat = @(); $floor = @(); $dev = @(); $extrap = @(); $cap = @(); $spot = @(); $beyond = @(); $nonRepro = @(); $contra = @()
    $ncC = @(); $ncR = @{}
    $rAll = @{}                         # 12.9 (L2-a) : residu juge de chaque cylindre verifie (Get-CalibNeedSteps)
    $outl = @{}; foreach ($c in @($u.Outliers)) { $outl[[int]$c] = $true }
    $kept = @{}; foreach ($c in @(@($u.RtKept) + @($u.RtFull))) { if ($null -ne $c) { $kept[[int]$c] = $true } }
    $vals = @($u.Fit.Values)
    $fl = Get-ResidualFlags $u
    $dft = Get-VerifyDrift $u
    foreach ($c in @($u.Verify.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if ($outl.ContainsKey($c)) { continue }
        $r = [double]$u.Verify[$c].Shift; $mz = $u.Verify[$c]
        if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $mz = $u.VerifyPrev[$c].Meas; $r = [double]$u.VerifyPrev[$c].Shift }
        elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
        $out = [math]::Abs($r) -gt (Get-ResidualTol $mz)
        $rAll[$c] = $r
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
    # 12.9 (L2-a) : marches du besoin non suivies par la courbe autour des cylindres non converges (conseil seulement) ;
    # seuil de rupture de la courbe (Get-CalibCurve, 230) : max(CalDevNs ; 3 x racine de 2 x incertitude mediane)
    $ncS = [int[]]@($ncC | Sort-Object -Unique)
    $steps = @(); $brk = [double]$script:CalDevNs
    # 12.9 (correction 4) : dents presentes dans la courbe (confirmees, en attente, ou non confirmees a la derniere
    # verification et gardees) : suivies par la courbe, ni marche ni conseil L2-a. Toujours un tableau (unite convergee :
    # vide), jamais $null
    $dCur = @(Get-FitDents $u.Fit)
    if ($ncS.Count -gt 0 -and $u.Est) {
        $estOk = @{}; $sgs = @()
        foreach ($k in @($u.Est.Keys)) {
            $c = [int]$k
            if ($outl.ContainsKey($c)) { continue }
            $estOk[$c] = [double]$u.Est[$k]
            $sgs += $(if ($u.Sig -and $u.Sig.ContainsKey($k)) { [math]::Max(1.0, [double]$u.Sig[$k]) } else { 5.0 })
        }
        $brk = [math]::Max([double]$script:CalDevNs, 3.0 * [math]::Sqrt(2.0) * (Get-Median $sgs))
        $steps = @(Get-CalibNeedSteps $estOk $ncS $rAll $brk)
        if ($dCur.Count -gt 0) { $steps = @($steps | Where-Object { $st = $_; @($dCur | Where-Object { [int]$st.C1 -le [int]$_.C1 -and [int]$st.C2 -ge [int]$_.C2 }).Count -eq 0 }) }
    }
    return @{ NonConv = $nonConv; Sat = $sat; Floor = $floor; Dev = $dev; Extrap = $extrap; Cap = $cap; Isolated = @($u.Outliers | ForEach-Object { "c$_" }); Breaks = @($u.Fit.Breaks)
              Spot = $spot; Sigma = $fl.Sigma; NDiff = $fl.NDiff; Hard = $fl.Hard; HardPair = $fl.HardPair; Beyond = [int[]]$beyond
              Drift = $dft; NonRepro = $nonRepro; Contra = [int[]]$contra; NonConvC = $ncS; NonConvR = $ncR
              Steps = $steps; StepBreak = $brk; Dents = $dCur }
}

function Get-CalibNeedSteps($est, [int[]]$nc, $resid, [double]$maxDrop) {
    # 12.9 (L2-a, journaux du 27 et du 28/10/2026) : « marche non suivie ». Groupe de cylindres non converges contigus
    # (ecart de 2 au plus entre deux d entre eux, CalStepMaxCyl cylindres au plus d un bout a l autre), contre une baisse du
    # besoin estime entre deux cylindres voisins (2 au plus) d au moins max(CalDevNs / CalStepDevDiv ; CalResidual), soit
    # 5 ns en double densite et 4 ns en haute densite (synthese C, D3 : une marche plus petite que la tolerance des
    # residus n explique pas un residu hors tolerance)
    # et sous le seuil de rupture de la courbe ($maxDrop) : la courbe croissante garde un palier, les residus changent de
    # signe de part et d autre (moyenne des 3 cylindres verifies de chaque cote : positive avant, negative apres). Fonction
    # pure. $est, $resid : cylindre -> besoin estime, residu juge. Renvoie @( @{ C1 ; C2 ; Drop ; Cyls ; Dev } ) : marche
    # entre C1 et C2, baisse (ns), cylindres non converges du groupe, ecart absolu maximal de leurs residus
    $out = @()
    $s = [int[]]@($nc | Sort-Object -Unique)
    if ($s.Count -eq 0 -or -not $est) { return $out }
    $minStep = [math]::Max([double]$script:CalDevNs / [double]$script:CalStepDevDiv, [double]$script:CalResidual)
    $ek = [int[]]@($est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    $groups = @(); $g = @($s[0])
    for ($i = 1; $i -lt $s.Count; $i++) { if ($s[$i] - $s[$i - 1] -le 2) { $g += $s[$i] } else { $groups += , @($g); $g = @($s[$i]) } }
    $groups += , @($g)
    foreach ($gr in $groups) {
        $a = [int]$gr[0]; $b = [int]$gr[-1]
        if ($b - $a + 1 -gt [int]$script:CalStepMaxCyl) { continue }
        $best = $null
        for ($i = 0; $i -lt $ek.Count - 1; $i++) {
            $c1 = $ek[$i]; $c2 = $ek[$i + 1]
            if ($c2 - $c1 -gt 2 -or $c1 -lt $a - 1 -or $c1 -gt $b) { continue }
            $drop = [double]$est[$c1] - [double]$est[$c2]
            if ($drop -lt $minStep -or $drop -ge $maxDrop) { continue }
            $bef = @(); $aft = @()
            for ($q = $c1 - 2; $q -le $c1; $q++) { if ($resid.ContainsKey($q)) { $bef += [double]$resid[$q] } }
            for ($q = $c2; $q -le $c2 + 2; $q++) { if ($resid.ContainsKey($q)) { $aft += [double]$resid[$q] } }
            if ($bef.Count -eq 0 -or $aft.Count -eq 0) { continue }
            if (($bef | Measure-Object -Average).Average -le 0 -or ($aft | Measure-Object -Average).Average -ge 0) { continue }
            if (-not $best -or $drop -gt $best.Drop) { $best = @{ C1 = $c1; C2 = $c2; Drop = $drop } }
        }
        if (-not $best) { continue }
        $dev = 0.0
        foreach ($c in $gr) { if ($resid.ContainsKey([int]$c)) { $dev = [math]::Max($dev, [math]::Abs([double]$resid[[int]$c])) } }
        # Synthese C (D4) : cylindres non relus (sans residu) hors de l explication, ils gardent le conseil « refaire » ;
        # groupe sans aucun cylindre relu : pas de marche
        $rc = [int[]]@($gr | Where-Object { $resid.ContainsKey([int]$_) })
        if ($rc.Count -eq 0) { continue }
        $best.Cyls = $rc; $best.Dev = $dev
        $out += , $best
    }
    return $out
}

function Get-CalibDents($coarse, [double]$pooled, [int]$nPass, [double]$step, [int]$gap = 2, [int]$maxN = 4) {
    # 12.9 (correction 4 ; regle de v129\cal2\donnees\dent.py, find_dents, avec les correctifs de la revue du 31/10/2026) :
    # dents locales du besoin d une unite, mesurees par ses passes de mesure. $coarse : cylindre -> @( @{ P ; W ; Shift } ),
    # mesures de chaque passe (decalage de passe retire). Un cylindre compte s il a ses n mesures et si elles encadrent son
    # zero (au moins un decalage > 0 et un <= 0) : ailleurs le zero ponctuel serait extrapole loin des mesures (lecteur a fort
    # besoin) et sa chute ne se comparerait plus. Zero ponctuel de chaque passe : W + Shift / |pente propre du cylindre|
    # (moindres carres sur ses passes ; pente commune $pooled si elle n est pas nettement negative). Deux cylindres comptes
    # voisins c < c2 (ecart $gap au plus) : chute par passe d_p = z_p(c) - z_p(c2), insensible au decalage commun de la
    # passe. Dent si la chute moyenne atteint $step (seuil de marche), chaque passe $step / 2, et si la chute de c au
    # cylindre compte suivant c3 (ecart $gap au plus de c2) atteint encore $step / 2 : un point bas isole n est pas une
    # dent, et sans c3 (fin de liste) la persistance ne se controle pas : pas de dent. Aucune borne haute : une chute que
    # SegFit prend a son changement de sens (c43/c44) est rendue aussi, puis ecartee par Split-CurveDents (hors d un segment
    # croissant). $maxN dents au plus (les plus fortes). Fonction pure. Renvoie les dents @{ C1 ; C2 ; Drop ; Min ;
    # Conf = $null ; V = 0 ; DV = NaN }, par cylindre croissant
    $zp = @{}
    foreach ($k in @($coarse.Keys)) {
        $c = [int]$k
        $rs = @(@($coarse[$k]) | Where-Object { $null -ne $_ } | Sort-Object { [int]$_.P })
        if ($rs.Count -ne $nPass) { continue }
        $xs = [double[]]@($rs | ForEach-Object { [double]$_.W }); $ys = [double[]]@($rs | ForEach-Object { [double]$_.Shift })
        # Zero encadre par les passes de mesure elles-memes (un decalage de chaque signe)
        if (@($ys | Where-Object { $_ -gt 0 }).Count -eq 0 -or @($ys | Where-Object { $_ -le 0 }).Count -eq 0) { continue }
        $mx = 0.0; $my = 0.0; for ($i = 0; $i -lt $xs.Count; $i++) { $mx += $xs[$i]; $my += $ys[$i] }; $mx /= $xs.Count; $my /= $ys.Count
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $sxx += ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += ($xs[$i] - $mx) * ($ys[$i] - $my) }
        $kc = if ($sxx -gt 0 -and $sxy / $sxx -lt -0.2) { $sxy / $sxx } else { $pooled }
        if ([math]::Abs($kc) -lt 1e-9) { continue }
        $zp[$c] = [double[]]@(for ($i = 0; $i -lt $xs.Count; $i++) { $xs[$i] + $ys[$i] / [math]::Abs($kc) })
    }
    $cs = [int[]]@($zp.Keys | Sort-Object)
    $found = @()
    for ($i = 0; $i -lt $cs.Count - 1; $i++) {
        $c = $cs[$i]; $c2 = $cs[$i + 1]
        if ($c2 - $c -gt $gap) { continue }
        $d = [double[]]@(for ($p = 0; $p -lt $nPass; $p++) { $zp[$c][$p] - $zp[$c2][$p] })
        $dm = ($d | Measure-Object -Average).Average; $dn = ($d | Measure-Object -Minimum).Minimum
        if ($dm -lt $step -or $dn -lt $step / 2.0) { continue }
        if ($i + 2 -ge $cs.Count -or $cs[$i + 2] - $c2 -gt $gap) { continue }
        $c3 = $cs[$i + 2]
        $d3 = (@(for ($p = 0; $p -lt $nPass; $p++) { $zp[$c][$p] - $zp[$c3][$p] }) | Measure-Object -Average).Average
        if ($d3 -lt $step / 2.0) { continue }
        $found += ,@{ C1 = $c; C2 = $c2; Drop = $dm; Min = $dn; Conf = $null; V = 0; DV = [double]::NaN }
    }
    $sel = @($found | Sort-Object @{ Expression = { -[double]$_.Drop } }, @{ Expression = { [int]$_.C1 } } | Select-Object -First ([math]::Max(0, $maxN)))
    return @($sel | Sort-Object @{ Expression = { [int]$_.C1 } })
}

function Update-CalibDents($u, [int]$vNum, [bool]$last, [int[]]$readNow) {
    # 12.9 (correction 4) : confirmation des dents de la courbe par la verification $vNum : dent en attente (Conf $null)
    # dont les deux cylindres ont ete relus a cette passe ; zeros de la verification (valeur ecrite - residu / pente de
    # l unite), baisse z(C1) - z(C2) : confirmee a partir de CalDentConfNs, sinon retiree (segments fusionnes,
    # Merge-CurveDentSegs) ; le decalage commun de la passe s annule dans la difference. Derniere verification : dent non
    # confirmee gardee dans la courbe (aucune passe pour la corriger), marquee non confirmee. Renvoie $true si une dent a ete
    # retiree avant la derniere verification (courbe a reajuster)
    $dl = @(Get-FitDents $u.Fit)
    if ($dl.Count -eq 0) { return $false }
    $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
    $thr = [double]$script:CalDentConfNs
    $keep = @(); $redo = $false
    foreach ($d in $dl) {
        if ($null -ne $d.Conf) { $keep += ,$d; continue }
        $c1 = [int]$d.C1; $c2 = [int]$d.C2
        if ($readNow -notcontains $c1 -or $readNow -notcontains $c2 -or -not $u.Verify.ContainsKey($c1) -or -not $u.Verify.ContainsKey($c2) -or -not $u.VerifyP.ContainsKey($c1) -or -not $u.VerifyP.ContainsKey($c2)) { $keep += ,$d; continue }
        $dv = ([double]$u.VerifyP[$c1] - [double]$u.Verify[$c1].Shift / $sl) - ([double]$u.VerifyP[$c2] - [double]$u.Verify[$c2].Shift / $sl)
        $d.V = $vNum; $d.DV = $dv
        if ($dv -ge $thr) {
            $d.Conf = $true; $keep += ,$d
            Append-Log ($u.Prefix + ((T "Dent entre c{0} et c{1} confirmée par la vérification {2} : baisse de {3} ns entre leurs zéros mesurés (au moins {4} ns exigés).") -f "$c1", "$c2", "$vNum", (Format-LevelNum $dv), (Format-LevelNum $thr)))
            continue
        }
        $d.Conf = $false
        if ($last) {
            $keep += ,$d
            Append-Log ($u.Prefix + ((T "Dent entre c{0} et c{1} non confirmée par la dernière vérification ({2} ns, moins de {3} ns) : la courbe reste telle quelle, ses résidus sont jugés normalement.") -f "$c1", "$c2", (Format-LevelNum $dv), (Format-LevelNum $thr)))
            continue
        }
        Append-Log ($u.Prefix + ((T "Dent entre c{0} et c{1} non confirmée par la vérification {2} : baisse de {3} ns entre leurs zéros mesurés, moins de {4} ns ; elle est retirée et la courbe est réajustée sans elle.") -f "$c1", "$c2", "$vNum", (Format-LevelNum $dv), (Format-LevelNum $thr)))
        $u.Fit.Segs = @(Merge-CurveDentSegs $u.Fit.Segs $c1 $c2)
        $redo = $true
    }
    $u.Fit.Dents = $keep
    return $redo
}

function Get-CalibUnitReserve($w) {
    # 12.9 (L2-d) : cylindres en reserve d une unite (Get-CalibWarnings) : non converges (NC), et cylindres de la zone non
    # reproductible (Zone) quand ils figurent aux reserves (Complete-PrecompCalib : ecart entre les verifications au-dela
    # de CalContraMaxNs, ou derive du lecteur non mesuree). Renvoie @{ NC ; Zone }
    $res = @{ NC = [int[]]@(); Zone = [int[]]@() }
    if (-not $w) { return $res }
    $res.NC = [int[]]@(@($w.NonConvC) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $cn = [int[]]@(@($w.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    if ($cn.Count -gt 0) {
        $dft = $w.Drift; $em = 0.0
        foreach ($c in $cn) { if ($dft -and $dft.Contra -and $dft.Contra.ContainsKey($c)) { $em = [math]::Max($em, [double]$dft.Contra[$c].E) } }
        # 12.9 (RT7) : zone gardee d avant un nouvel essai, trouvee sans derive mesuree (ContraNoDrift, Add-VerifyDriftHold)
        if ($em -gt [double]$script:CalContraMaxNs -or -not ($dft -and $dft.Use -and -not $dft.ContraNoDrift)) { $res.Zone = $cn }
    }
    return $res
}

function Get-CalibCommonReserve($ra, $rb) {
    # 12.9 (L2-d) : reserves des calibrations A et B (Get-CalibUnitReserve, meme unite) aux memes cylindres, a 1 pres : un
    # cylindre non converge de l une a 1 cylindre au plus d un cylindre en reserve de l autre (non converge, ou zone non
    # reproductible en reserve ; deux zones seules ne suffisent pas). Les groupes de cylindres non converges touches
    # (ecart de 2 au plus) sont repris en entier. Fonction pure. Renvoie les cylindres tries (vide : aucun)
    $mark = @{}
    foreach ($pair in @(@($ra, $rb), @($rb, $ra))) {
        $x = $pair[0]; $y = $pair[1]
        $yAll = @(@($y.NC) + @($y.Zone) | ForEach-Object { [int]$_ })
        $xs = [int[]]@(@($x.NC) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        $hit = @{}
        foreach ($c in $xs) {
            foreach ($d in $yAll) {
                if ([math]::Abs($c - $d) -le 1) { $hit[$c] = $true; $mark[$c] = $true; if (@($y.NC) -contains $d -or @($y.Zone) -contains $d) { $mark[$d] = $true } }
            }
        }
        # Groupes de non converges de $x touches : repris en entier
        if ($xs.Count -gt 0) {
            $g = @($xs[0])
            for ($i = 1; $i -le $xs.Count; $i++) {
                if ($i -lt $xs.Count -and $xs[$i] - $xs[$i - 1] -le 2) { $g += $xs[$i]; continue }
                if (@($g | Where-Object { $hit.ContainsKey([int]$_) }).Count -gt 0) { foreach ($c in $g) { $mark[[int]$c] = $true } }
                if ($i -lt $xs.Count) { $g = @($xs[$i]) }
            }
        }
    }
    return [int[]]@($mark.Keys | ForEach-Object { [int]$_ } | Sort-Object)
}

function Split-CalibRetestZone([int[]]$nc, [int[]]$zone, [int]$reach = 2) {
    # 12.9 (L2-b) : nouvel essai d une unite qui a une zone non reproductible (ou des cylindres non reproductibles) : seuls
    # les cylindres non converges a $reach cylindres au plus d un cylindre de la zone en sont exclus, et non plus toute
    # l unite. Fonction pure. Renvoie @{ Keep ; Excl ; Near (cylindres de la zone qui excluent) }
    $keep = @(); $excl = @(); $near = @{}
    foreach ($c in @($nc)) {
        $z = @(@($zone) | Where-Object { [math]::Abs([int]$_ - [int]$c) -le $reach })
        if ($z.Count -gt 0) { $excl += [int]$c; foreach ($d in $z) { $near[[int]$d] = $true } } else { $keep += [int]$c }
    }
    return @{ Keep = [int[]]$keep; Excl = [int[]]$excl; Near = [int[]]@($near.Keys | ForEach-Object { [int]$_ } | Sort-Object) }
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
    # 12.9 (L2-d) : reserves de A et de B aux memes cylindres (a 1 pres, Get-CalibCommonReserve) : l ecart vient du lecteur ;
    # plus de conseil « deux disquettes defectueuses » dans ce cas (verdict et courbe conseillee inchanges)
    $cmnTxt = @()
    for ($i = 0; $i -lt [math]::Min(@($A.Units).Count, @($cal.Units).Count); $i++) {
        $ua = $A.Units[$i]; $ub = $cal.Units[$i]
        if (-not $ua.Warn -or -not $ub.Warn) { continue }
        $cm = [int[]]@(Get-CalibCommonReserve (Get-CalibUnitReserve $ua.Warn) (Get-CalibUnitReserve $ub.Warn))
        if ($cm.Count -gt 0) { $cmnTxt += "$(Format-CylList $cm)$(if ($ub.Prefix) { ' ' + ([string]$ub.Prefix).Trim() })" }
    }
    if ($cmnTxt.Count -gt 0) { $L.Add(((T "Même écart aux cylindres {0} sur les deux disquettes : il vient du lecteur, pas du support.") -f ($cmnTxt -join ' ; '))) }
    elseif ($supA -gt 0 -and $supB -gt 0) { $L.Add((T 'Les deux calibrations ont des réserves liées au support : deux disquettes défectueuses, ou un lecteur instable (préchauffage, têtes à nettoyer).')) }
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
