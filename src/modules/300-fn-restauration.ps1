# ============================== FONCTIONS : RESTAURATION =======================

function Get-RestoreDefaultDir {
    return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) ('Greaseweazle Studio\' + (T 'Restaurations')))
}

function Get-RestoreFormat {
    # 12.8 (D13) : choix de la liste du cadre 1 (reglage restoreFormat, cle restore.formatChoice) : 'auto' (detection du
    # format a la lecture), '' (copie exacte du flux) ou le nom du format. Piege : l index 0 de cmbRsFmt designe la
    # detection automatique, et non plus le flux ($script:RsFluxItem)
    $c = [string](Get-Setting 'restoreFormat')
    if ($c -eq 'flux') { return '' }
    if (-not $c) { return 'auto' }
    return $c
}

function Get-RestoreStem([string]$dir, [string]$name) {
    # Debut commun des chemins de la restauration (« <dossier>\<nom> »), calcule une seule fois par restauration (Start-
    # Restore) ; jamais d ecrasement : suffixe (2), (3)... si une restauration du meme nom existe deja, quel que soit son
    # mode (12.8, FIX2 : rapport, original ou lecture secteur incomplete de toute extension ; avant : original de la meme
    # extension seulement, d ou un rapport ecrase apres une relance D12 ou un autre mode)
    $tails = @(' - ' + (T 'rapport') + '.txt')
    foreach ($e in @('.adf', '.st', '.img', '.scp')) { $tails += @((' - ' + (T 'original') + $e), (' - ' + (T 'lecture secteur incomplète') + $e)) }
    $stem = Join-Path $dir $name; $k = 1
    while (@($tails | Where-Object { Test-Path -LiteralPath ($stem + $_) }).Count -gt 0) { $k++; $stem = (Join-Path $dir $name) + " ($k)" }
    return $stem
}

function Set-RestoreFormat([string]$fmt) {
    # Format de la restauration ($fmt : nom du format, '' : copie exacte du flux), choisi dans la liste ou retenu par la
    # detection (Complete-RestoreDetect) : mode, extension et chemins (Orig, Back, Report, Probe). 12.8 : les chemins se
    # calculent apres la detection, l extension dependant du format ; debut des chemins fixe pour toute la restauration
    # ($r.Stem), la relance D12 ne changeant que l extension
    $r = $script:Restore
    $r.Fmt = $fmt
    $r.Mode = $(if ($fmt) { 'sector' } else { 'flux' })
    $r.Ext = $(if ($fmt) { Get-DecodedExt $fmt } else { '.scp' })
    if (-not $r.Stem) { $r.Stem = Get-RestoreStem $r.Dir $r.Name }
    $stem = $r.Stem
    $r.Orig = ($stem + ' - ' + (T 'original') + $r.Ext); $r.Back = ($stem + ' - ' + (T 'copie relue') + $r.Ext)
    $r.Report = ($stem + ' - ' + (T 'rapport') + '.txt')
    $r.Probe = (Join-Path $script:TempDir ("restore-probe-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + $r.Ext))
}

function Update-RsDrive {
    # 12.8 (D10) : lecteur de la restauration, celui du bandeau (Update-SettingDependents 'drive')
    if (-not $lblRsDrive) { return }
    $lblRsDrive.Text = (T "{0}  (choix « Lecteur » du bandeau)") -f "$(Get-Setting 'drive')"
}

function Update-RsFmtFound {
    # 12.8 (D11) : ligne sous la liste du format (Update-SettingDependents 'restoreFormat'). Detection automatique :
    # « Format detecte a la lecture », puis le resultat de la detection (Complete-RestoreDetect), garde jusqu au prochain
    # choix ou a la prochaine restauration ; format choisi ou flux : vide
    if (-not $lblRsFmtFound -or $script:Restore) { return }
    $t = $(if ((Get-RestoreFormat) -eq 'auto') { (T 'Format détecté à la lecture') } else { '' })
    $lblRsFmtFound.Text = $t; $tip.SetToolTip($lblRsFmtFound, $t)      # FIX2 : infobulle d une detection precedente retiree
}

function Get-RsFmtFoundLine($res) {
    # 12.8 (FIX2, A1 § 2.6 et 3.5) : ligne courte du cadre 1 (360 px, une ligne) apres la detection ; le texte complet de la
    # detection reste dans l infobulle, le rapport et le journal. $res : resultat de Select-DiskFormat (Name, Format,
    # Action, Why)
    if ($res.Action -eq 'stop') { return ((T "Arrêt : {0}") -f "$($res.Why)") }
    if ($res.Action -eq 'flux') {
        if ($res.Name) { return ((T "Format détecté : {0}, copie exacte du flux") -f "$($res.Name)") }
        # Sans format reconnu : raison courte en tete (« Format non reconnu », « Piste 0 non formatee »)
        $w = $(if ($res.Why) { [string]$res.Why } else { (T 'format non reconnu') })
        return ((T "{0} : copie exacte du flux") -f ($w.Substring(0, 1).ToUpper() + $w.Substring(1)))
    }
    return ((T "Format détecté : {0} ({1})") -f "$($res.Name)", "$($res.Format)")
}

function Get-RsCalibText {
    # 12.8 (D11) : cadre « 2. Calibration du lecteur » : courbes qu appliquerait la restauration (ecriture tete par tete :
    # par tete si elles sont a jour, sinon la courbe commune, Get-FamilyCurves), double densite (famille std, celle des
    # formats double densite de la liste) puis haute densite (famille hd) : type, date, lecteur, non-convergence
    $parts = @()
    foreach ($fd in @(@('std', (T 'Double densité')), @('hd', (T 'Haute densité')))) {
        $cvs = Get-FamilyCurves $fd[0] $true
        if ($cvs.Count -eq 0) { $parts += ((T "{0} : aucune courbe.") -f $fd[1]); continue }
        $d = @($(if ($cvs.Count -gt 1) { (T 'par tête') } else { (T 'commune aux deux têtes') }))
        $dt = Get-CurveDate $cvs[0]
        if ($dt -gt [datetime]::MinValue) { $d += $dt.ToString('dd/MM/yyyy') }
        if ($cvs[0].Drive) { $d += ((T 'lecteur {0}') -f "$($cvs[0].Drive)") }
        if (@($cvs | Where-Object { $_.Converged -eq $false }).Count -gt 0) { $d += (T 'non convergée') }
        $parts += ((T "{0} : {1}.") -f $fd[1], ($d -join ', '))
    }
    return ($parts -join ' ')
}

function Update-RsCalib {
    # Cadre 2 : resume des courbes et bouton « Courbe » (actif avec au moins une courbe) ; a l entree dans l onglet, a la
    # fin d une restauration et a chaque mise a jour du bouton « Courbe » de l onglet Ecriture (Update-CurveButton : fin
    # de calibration, effacement des calibrations, configuration chargee)
    if (-not $lblRsCal) { return }
    $t = Get-RsCalibText
    if ($lblRsCal.Text -ne $t) { $lblRsCal.Text = $t; $tip.SetToolTip($lblRsCal, $t + "`n`n" + (T "Une calibration existante n'est jamais refaite par la restauration. Sans courbe, le lecteur est calibré tête par tête en test fin, éventuellement sur une disquette sacrifiée, avant l'écriture de la copie.")) }
    $btnRsCurve.Enabled = ((Get-FamilyCurves 'std' $true).Count + (Get-FamilyCurves 'hd' $true).Count) -gt 0
}

function Show-RsCurve {
    # Bouton « Courbe » du cadre 2 : courbes appliquees par la restauration (par tete si elles sont a jour) ; famille du
    # format choisi s il est haute densite (Get-HdCalibFamily), sinon double densite ; a defaut, l autre famille
    $hf = Get-HdCalibFamily '' (Get-RestoreFormat)
    $fams = if ($hf) { @('hd', 'std') } else { @('std', 'hd') }
    foreach ($f in $fams) { if ((Get-FamilyCurves $f $true).Count -gt 0) { Show-PrecompCurve $f $true; return } }
}

function Get-SafeFileName([string]$s) {
    $bad = [System.IO.Path]::GetInvalidFileNameChars()
    $o = -join @($s.ToCharArray() | ForEach-Object { if ($bad -contains $_) { '_' } else { $_ } })
    return $o.Trim().TrimEnd('.')
}

function Update-RsRules {
    $r = $script:RestoreRules
    $lblRsRules.Text = ((T "Règles appliquées à la copie : disquette de destination mesurée avant l'écriture quand c'est possible (calibration rapide), écriture tête par tête avec la calibration existante du lecteur (calibration par tête si aucune n'existe), pré-effacement, vérification par gw, {0} essais par piste, contrôle de toutes les pistes ({1} passes de réécriture au plus), puis relecture et comparaison avec l'original.") -f "$($r.WriteRetries)", "$($r.RepairPasses)")
}

function Set-RsStep([int]$i, [string]$state, [string]$detail = '') {
    # 12.8 (lot 3b) : glyphe garde dans le texte (infobulle, rapport) ; l etape est dessinee avec l icone d etat de 16 px
    # (Draw-RsStepLabel, d apres Tag) ; « ! » en Theme.WarnInk (Theme.Warn : 2,75:1 sur blanc, sous le minimum du texte)
    $g = @{ pending = '○'; run = '▶'; ok = '✓'; fail = '✗'; skip = '–'; warn = '!' }[$state]
    $c = @{ pending = $script:Theme.Muted; run = $script:Theme.Accent; ok = $script:Theme.Ok; fail = $script:Theme.Danger; skip = $script:Theme.Muted; warn = $script:Theme.WarnInk }[$state]
    $l = $script:RsStepLabels[$i]
    $l.Tag = $state
    $l.Text = "$g  " + $script:RsStepNames[$i] + $(if ($detail) { "  -  $detail" } else { '' })
    $l.ForeColor = $c
    $l.Invalidate()
    $l.Font = if ($state -eq 'run') { $bold } else { $form.Font }
    $tip.SetToolTip($l, $l.Text)
    if ($script:Restore) {
        $script:Restore.Steps[$i] = @{ State = $state; Detail = $detail }
        if ($state -eq 'run') { $script:Restore.Cur = $i }
    }
}

function Reset-RsSteps {
    for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) { Set-RsStep $i 'pending' }
    $pnlRsWait.Visible = $false; $lblRsResult.Visible = $false; $lblRsNow.Text = ''; $lblRsRules.Visible = $true
}

function Set-RsLock([bool]$lock) {
    # Pendant une restauration : seuls l onglet Restauration et le bouton Arreter restent utilisables ; le lecteur du
    # bandeau, celui de la restauration (12.8, D10), ne change pas
    foreach ($p in $script:AllTabs) { if ($p -ne $tabRs) { $p.Enabled = -not $lock } }
    foreach ($c in @($grpRsSrc, $grpRsCal, $grpRsDir, $btnRsStart, $cmbDrive, $chkExpert)) { $c.Enabled = -not $lock }
    $btnCfgReset.Enabled = -not $lock -and -not ($script:GwProc -and -not $script:GwProc.HasExited)
    $btnCfgSave.Enabled = $btnCfgReset.Enabled
}

function Save-WriteTabState {
    return @{ File = $txtWFile.Text; Fmt = $cmbWFmt.Text; Slow = $chkWSlow.Checked; Pre = $chkWPreErase.Checked; Empty = $chkWEraseEmpty.Checked
              NoVer = $chkWNoVerify.Checked; Retries = $numWRetries.Value; Precomp = $chkWPrecomp.Checked; Post = $chkWPostCheck.Checked
              Repair = $numWRepair.Value; Tracks = $txtWTracks.Text; CalMode = $cmbWCalMode.SelectedIndex; Profile = $cmbWProfile.SelectedIndex
              P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Drive = $cmbDrive.Text; Source = $script:PresetSource }
}

function Restore-WriteTabState($s) {
    # Onglet Ecriture et lecteur remis tels qu avant la restauration (les calibrations obtenues restent enregistrees)
    if (-not $s) { return }
    $txtWFile.Text = $s.File; Set-Combo $cmbWFmt $s.Fmt; if ($cmbWFmt.Text -ne $s.Fmt) { $cmbWFmt.Text = $s.Fmt }
    $chkWSlow.Checked = $s.Slow; $chkWPreErase.Checked = $s.Pre; $chkWEraseEmpty.Checked = $s.Empty; $chkWNoVerify.Checked = $s.NoVer
    Set-Num $numWRetries $s.Retries; $chkWPrecomp.Checked = $s.Precomp; $chkWPostCheck.Checked = $s.Post; Set-Num $numWRepair $s.Repair
    $txtWTracks.Text = $s.Tracks; $cmbWCalMode.SelectedIndex = $s.CalMode; $cmbWProfile.SelectedIndex = $s.Profile
    $script:PresetSource = $s.Source
    $cmbDrive.SelectedItem = $s.Drive
    Update-PrecompForImage $txtWFile.Text
    if ($cmbWProfile.Text -eq (T 'Manuel')) { $txtWPrecomp.Text = $s.P0; $txtWPrecomp1.Text = $s.P1 }
    $chkWPrecomp.Checked = $s.Precomp                      # Set-PrecompFields la recoche
}

function Start-Restore {
    if ($script:Restore) { return }
    # 12.8 (D20) : test d occupation unique (Get-AppBusy) ; boites par Show-AppMessage (texte aussi ecrit au journal)
    $busy = Get-AppBusy -Text
    if ($busy) {
        Append-Log ((T "Restauration refusée : opération en cours ({0}).") -f "$busy")
        [void](Show-AppMessage (T 'Une opération est déjà en cours : attendez sa fin ou cliquez sur « Arrêter ».') (T 'Restauration') 'OK' 'Information'); return
    }
    if (-not (Test-Path -LiteralPath $script:GwExe)) {
        [void](Show-AppMessage ((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)") (T 'Erreur') 'OK' 'Error'); return
    }
    if (-not $script:ScpStatsOk) {
        [void](Show-AppMessage (T "Restauration impossible : le module d'analyse de flux n'a pas pu être compilé, le contrôle strict des pistes n'est donc pas disponible.") (T 'Restauration') 'OK' 'Warning'); return
    }
    if ($chkWHard.Checked -or $chkWTG43.Checked) {
        [void](Show-AppMessage (T 'Restauration non prise en charge avec « Secteurs durs » ou « TG43 » cochés dans les options avancées de l''onglet Écriture : le contrôle des pistes est calibré pour le MFM double densité.') (T 'Restauration') 'OK' 'Warning'); return
    }
    $fmt = Get-RestoreFormat
    $dir = $txtRsDir.Text.Trim()
    if (-not $dir) { $dir = Get-RestoreDefaultDir }
    if (-not [System.IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $script:AppDir $dir }
    try { $dir = [System.IO.Path]::GetFullPath($dir) } catch { }
    try { New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop | Out-Null }
    catch { [void](Show-AppMessage ((T "Dossier de sauvegarde inaccessible : {0}") -f "$($_.Exception.Message)") (T 'Restauration') 'OK' 'Warning'); return }
    $name = Get-SafeFileName $txtRsName.Text
    if (-not $name) { $name = (T 'disquette') + ' ' + (Get-Date -Format "yyyy-MM-dd HH'h'mm") }
    # 12.8 (D10) : un seul lecteur, celui du bandeau, fige pour toute la restauration (Set-RsLock verrouille le bandeau)
    $drv = [string]$cmbDrive.Text
    $modeTxt = if ($fmt -eq 'auto') { (T 'format détecté à la lecture') } elseif ($fmt) { (T "secteur par secteur, format {0}") -f "$fmt" } else { (T 'copie exacte du flux, sans précompensation ni comparaison par secteur') }
    $swap = (T "Le lecteur {0} lit l'original, puis vous changez de disquette quand l'application vous le demande.") -f "$drv"
    $msg = ((T "Restauration ({0}).`n`n{1}`n`n1. Insérez maintenant la disquette d'ORIGINE dans le lecteur {2}, de préférence protégée en écriture.`n2. Sa lecture est enregistrée dans :`n   {3}`n3. La disquette de destination sera entièrement effacée puis écrite.`n`nCommencer la lecture ?") -f "$modeTxt", "$swap", "$drv", "$dir")
    # 12.8 (D3) : confirmation par frmConfirm, case qui nomme le lecteur de l original
    $cq = @{ Title = (T 'Restauration'); Heading = (T 'Restaurer une disquette'); Text = $msg; Level = 'info'; Picto = 'data'
             Check = ((T "La disquette d'ORIGINE est dans le lecteur {0}") -f "$drv"); GoText = (T 'Commencer la lecture'); GoGlyph = 'Download' }
    if (-not (Show-AppConfirm @cq)) { return }
    $txtRsDir.Text = $dir
    # 12.8 (D4, L1 ecart 8) : reglages de l onglet Ecriture en surcharge d operation, ecrits a leur place dans la
    # configuration pendant la restauration, retablis par Close-Restore ; surcharge precedente terminee d abord
    if ($script:OpOverride) { Exit-OpOverride }
    Enter-OpOverride 'restore'
    # Mode, format, extension et chemins : Set-RestoreFormat, tout de suite pour un format choisi ou le flux, apres la
    # detection en mode automatique (Complete-RestoreDetect)
    $script:Restore = @{
        Mode = ''; Fmt = ''; Ext = ''; Choice = $fmt; Drive = $drv; Name = $name; Dir = $dir; Found = ''; FluxRetry = $false
        Orig = ''; Back = ''; Report = ''; Probe = ''
        # FIX2 : debut des chemins fixe des le lancement (Get-RestoreStem) ; FluxWhy : raison courte d une copie de flux
        # decidee par la detection ou par la relance D12 (etape 2 en « ! ») ; FmtName : nom court du format detecte ;
        # SectorRead : lecture secteur incomplete conservee avant une relance D12 (Path, Miss, Extra)
        Stem = (Get-RestoreStem $dir $name); FluxWhy = ''; FmtName = ''; SectorRead = $null
        Stage = 'read'; Waiting = $false; Override = $false; InCall = $false; Idle = (Get-Date); Start = (Get-Date); Cur = 0
        Steps = @{}; Saved = $script:OpOverride.Saved; Read = $null; Cmp = $null; Calib = ''; HD = ''
        CalibUsed = $null; CalibDone = $false; CalSwap = $false; SwapBack = $false
        Finger = $null; OnOriginal = $false; Preserved = @()   # flux : empreinte de l original, ecriture sur l original, cylindres preserves
        Extras = (Get-TSpecExtras $txtWTracks.Text)       # step, hswap, h0.off, h1.off : geometrie du lecteur
    }
    $script:LastCheck = $null
    Reset-RsSteps; Set-RsLock $true
    if (-not (Test-Path -LiteralPath $script:TempDir)) { New-Item -ItemType Directory -Force -Path $script:TempDir | Out-Null }
    Append-Log ''
    Append-Log ((T "=== RESTAURATION : {0} ({1}) ===") -f "$name", "$modeTxt")
    if ($fmt -eq 'auto') { $lblRsFmtFound.Text = (T 'Format détecté à la lecture'); $tip.SetToolTip($lblRsFmtFound, $lblRsFmtFound.Text); Start-RestoreDetect; return }
    Set-RestoreFormat $fmt
    Append-Log ((T "Original : lecteur {0} -> {1}") -f "$drv", "$($script:Restore.Orig)")
    Invoke-RestoreRead
}

function Start-RestoreDetect {
    # 12.8 (point 4, D12) : detection automatique du format, phase de l etape 1 (« Lire la disquette d origine ») : les
    # huit etapes et leurs index ne changent pas. Lecture de deux pistes et decodages hors ligne (Invoke-DiskFormatDetect,
    # 185), decision (Select-DiskFormat), puis Complete-RestoreDetection : format retenu, copie exacte du flux (format
    # inconnu en double densite, protection probable : D12) ou arret avant toute ecriture (disquette vierge, format haute
    # densite inconnu). Geometrie du lecteur (step, hswap) comme la lecture complete et la sonde
    $r = $script:Restore
    $r.Stage = 'detect'
    Set-RsStep 0 'run' (T 'identification du format (pistes 0.0 et 0.1)')
    Invoke-DiskFormatDetect 'restore' $r.Extras
}

function Complete-RestoreDetection($res) {
    # Fin de la detection (Complete-DiskFormatDetect) : arret (etape 1, rien n est ecrit, rapport sans chemin d original),
    # copie exacte du flux, ou lecture secteur du format retenu
    $r = $script:Restore
    if (-not $r -or $r.Stage -ne 'detect') { return }
    # FIX2 : ligne courte du cadre 1 (Get-RsFmtFoundLine), texte complet en infobulle ; raison d une copie de flux gardee
    # pour l etape 2 (« ! »)
    $short = Get-RsFmtFoundLine $res
    $r.FmtName = [string]$res.Name
    if ($res.Action -eq 'stop') { $lblRsFmtFound.Text = $short; $tip.SetToolTip($lblRsFmtFound, $res.Text); $r.Found = $res.Text; Fail-Restore 0 $res.Text; return }
    if ($res.Action -eq 'flux') { $r.FluxWhy = [string]$res.Why; Complete-RestoreDetect '' $res.Text $short; return }
    Complete-RestoreDetect $res.Format $res.Text $short
}

function Complete-RestoreDetect([string]$fmt, [string]$found, [string]$short = '') {
    # Fin de la detection, ou relance d office en copie de flux apres une lecture secteur incomplete (D12) : format retenu
    # ($fmt ; '' = copie exacte du flux), texte du rapport et de l infobulle du cadre 1 ($found), ligne courte du cadre 1
    # ($short, a defaut $found), chemins calcules (Set-RestoreFormat), puis lecture complete, comme pour un choix manuel
    $r = $script:Restore
    if (-not $r) { return }
    $r.Stage = 'read'; $r.Found = $found
    Set-RestoreFormat $fmt
    $lblRsFmtFound.Text = $(if ($short) { $short } else { $found })
    $tip.SetToolTip($lblRsFmtFound, $found)
    Append-Log ((T "Original : lecteur {0} -> {1}") -f "$($r.Drive)", "$($r.Orig)")
    Invoke-RestoreRead
}

function Invoke-RestoreRead {
    $r = $script:Restore
    Set-RsStep 0 'run'
    $a = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs)
    if ($r.Mode -eq 'sector') {
        $a += @("--format=$($r.Fmt)", "--revs=$($script:RestoreRules.ReadRevs)", "--retries=$($script:RestoreRules.ReadRetries)", "--seek-retries=$($script:RestoreRules.SeekRetries)")
    } else {
        $a += "--revs=$($script:RestoreRules.ReadRevs)"
    }
    if ($r.Extras) { $a += "--tracks=$($r.Extras.TrimStart(':'))" }
    $a += "`"$($r.Orig)`""
    $script:RestoreArgs = $a
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Invoke-RestoreNext {
    $r = $script:Restore
    if (-not $r) { return }
    $r.Idle = Get-Date
    switch ($r.Stage) {
        'read'    { Complete-RestoreRead }
        'probe'   { Complete-RestoreProbe }
        'write'   { Start-RestoreCompare }
        'compare' { Complete-RestoreCompare }
    }
}

function Get-GwSectorSummary($lines) {
    # Bilan d une lecture gw avec format : « T0.0: AmigaDOS (11/11 sectors) from ... » (derniere ligne de la piste),
    # « T0.0: Giving up: 2 sectors missing », « Found 1758 sectors of 1760 (99%) ». 12.8 (FIX2) : « T1.0: Ignoring unexpected
    # sector C:1 H:0 R:10 N:2 » (decodeur IBM a format fixe de gw : secteur valide hors du format, ni compte ni copie,
    # imprime a chaque essai) : Extra, cle « cyl.tete » -> secteurs distincts (C:H:R:N)
    $tracks = @{}; $gaveUp = @{}; $extra = @{}; $found = -1; $total = -1
    foreach ($l in @($lines)) {
        if ($l -match '^T(\d+)\.(\d+)\b[^:]*: Ignoring unexpected sector (C:\d+ H:\d+ R:\d+ N:\d+)') {
            $k = "$([int]$Matches[1]).$([int]$Matches[2])"
            if (-not $extra.ContainsKey($k)) { $extra[$k] = @{} }
            $extra[$k][$Matches[3]] = $true
        }
        elseif ($l -match '^T(\d+)\.(\d+)\b[^:]*: Giving up: (\d+) sectors? missing') { $gaveUp["$($Matches[1]).$($Matches[2])"] = [int]$Matches[3] }
        elseif ($l -match '^T(\d+)\.(\d+)\b[^:]*: .*\((\d+)/(\d+) sectors\)') { $tracks["$($Matches[1]).$($Matches[2])"] = @([int]$Matches[3], [int]$Matches[4]) }
        elseif ($l -match '^Found (\d+) sectors of (\d+)') { $found = [int]$Matches[1]; $total = [int]$Matches[2] }
    }
    $nx = 0; foreach ($k in @($extra.Keys)) { $nx += $extra[$k].Count }
    return @{ Tracks = $tracks; GaveUp = $gaveUp; Found = $found; Total = $total; Extra = $extra; ExtraCount = $nx }
}

function Get-BadSectorBlocks([string]$path) {
    # Blocs de 512 octets remplis par gw du motif « -=[BAD SECTOR]=- » (secteur manquant a la lecture) ; meme test que la
    # comparaison (Get-BadSectorIndexes, 180)
    return ,(Get-BadSectorIndexes ([System.IO.File]::ReadAllBytes($path)))
}

function Get-BlockTracks([int[]]$blocks, [string]$fmt) {
    # Pistes « cyl.tete » des blocs (image double face entrelacee, secteurs par piste du format)
    $spt = Get-SectorsPerTrack $fmt
    $set = @{}
    if ($spt -le 0) { return @() }
    foreach ($b in $blocks) { $t = [math]::Floor($b / $spt); $set["$([math]::Floor($t / 2)).$($t % 2)"] = $true }
    return (Sort-TrackKeys @($set.Keys))         # elements emis un par un : @() chez l appelant reste plat
}

function Complete-RestoreRead {
    $r = $script:Restore
    $lines = @(); if ($script:GwCapture) { $lines = @($script:GwCapture) }
    $script:GwCapture = $null
    if (-not (Test-Path -LiteralPath $r.Orig) -or (Get-Item -LiteralPath $r.Orig).Length -eq 0) {
        Fail-Restore 0 (T 'la lecture n''a produit aucun fichier (disquette absente ou lecteur incorrect ?)'); return
    }
    Set-RsStep 0 'ok' (Split-Path -Leaf $r.Orig)
    Set-RsStep 1 'run'
    if ($r.Mode -eq 'sector') {
        $sum = Get-GwSectorSummary $lines
        $bad = Get-BadSectorBlocks $r.Orig
        $miss = @($sum.GaveUp.Keys) + @(Get-BlockTracks $bad $r.Fmt)
        $miss = Sort-TrackKeys @($miss | Select-Object -Unique)
        # FIX2 : secteurs valides hors du format, ignores par gw (« Ignoring unexpected sector ») : une copie secteur par
        # secteur les perdrait, ils comptent comme des secteurs illisibles
        $nX = [int]$sum.ExtraCount
        $xTk = Sort-TrackKeys @($sum.Extra.Keys)
        $r.Read = @{ Found = $sum.Found; Total = $sum.Total; Bad = $bad.Count; Tracks = $miss; Extra = $nX; ExtraTracks = $xTk }
        if ($sum.Total -le 0) { Fail-Restore 1 (T 'gw n''a imprimé aucun bilan de secteurs : format incorrect, ou disquette illisible ?'); return }
        $nMiss = [math]::Max($bad.Count, $sum.Total - $sum.Found)
        if (($nMiss -gt 0 -or $nX -gt 0) -and $r.Choice -eq 'auto' -and -not $r.FluxRetry -and -not (Test-HdFormat $r.Fmt)) {
            # 12.8 (D12) : detection automatique, double densite : protection contre la copie hors des pistes 0.0 et 0.1
            # probable (ou tetes sales) : relance d office de la lecture en copie exacte du flux, une lecture ne detruisant
            # rien ; le flux est ensuite juge piste par piste comme une copie de flux choisie (tetes sales : pistes
            # critiques, arret avant l ecriture). Haute densite : arret de la 12.7 (copie de flux non controlable).
            # FIX2 : la lecture secteur est gardee sous « <nom> - lecture secteur incomplete.<ext> » et citee au rapport ;
            # secteurs hors du format : meme relance
            $r.FluxRetry = $true
            $all = Sort-TrackKeys @(@($miss) + @($xTk) | Select-Object -Unique)
            if ($nX -gt 0) {
                $t = (T "{0} secteur(s) hors du format {1} ignoré(s) par gw en lecture secteur (pistes {2}), {3} secteur(s) illisible(s) : protection contre la copie ou format étendu probable. Relance automatique de la lecture en copie exacte du flux, sans comparaison par secteur.") -f "$nX", "$($r.Fmt)", "$(Format-TrackList $all)", "$nMiss"
                $r.FluxWhy = (T 'relance : secteurs hors du format')
            } else {
                $t = (T "{0} secteur(s) illisible(s) en lecture secteur (pistes {1}) : protection contre la copie probable, ou têtes sales. Relance automatique de la lecture en copie exacte du flux, sans comparaison par secteur.") -f "$nMiss", "$(Format-TrackList $miss)"
                $r.FluxWhy = (T 'relance après une lecture secteur incomplète')
            }
            Append-Log ((T "Restauration : {0}") -f $t)
            $keep = $r.Stem + ' - ' + (T 'lecture secteur incomplète') + $r.Ext
            try { [System.IO.File]::Move($r.Orig, $keep) } catch { $keep = $r.Orig }
            $r.SectorRead = @{ Path = $keep; Miss = $nMiss; Extra = $nX }
            Append-Log ((T "Restauration : lecture secteur incomplète conservée : {0}") -f $keep)
            Set-RsStep 1 'pending'
            $f = $(if ($r.Found) { $r.Found + ' ' } else { '' }) + $t
            Complete-RestoreDetect '' $f (Get-RsFmtFoundLine @{ Action = 'flux'; Name = $(if ($r.FmtName) { $r.FmtName } else { $r.Fmt }) })
            return
        }
        if ($nMiss -eq 0 -and $nX -gt 0) {
            # FIX2 : choix manuel ou haute densite : arret avant toute ecriture (12.7 : copie sans ces secteurs, reussie)
            $tx = (T "{0} secteur(s) hors du format {1} ignoré(s) par gw (pistes {2}) : une copie secteur par secteur les perdrait (protection contre la copie, ou format étendu probable).") -f "$nX", "$($r.Fmt)", "$(Format-TrackList $xTk)"
            if (-not (Test-HdFormat $r.Fmt)) { $tx += ' ' + (T 'Relancez avec « Copie exacte du flux », ou choisissez le format exact de la disquette.') }
            Fail-Restore 1 $tx
            return
        }
        if ($nMiss -gt 0) {
            # Secteurs illisibles regroupes sur une ou deux pistes : protection contre la copie probable
            $nTk = @($miss).Count
            $fmtMiss = if ($nTk -ge 1 -and $nTk -le 2) { (T "{0} secteur(s) illisible(s), regroupés sur la ou les pistes {1} : c'est souvent une protection contre la copie (secteurs volontairement illisibles), qu'une copie secteur par secteur ne peut pas reproduire. Relancez avec « Copie exacte du flux ».") }
                       else { (T "{0} secteur(s) illisible(s) sur l'original (pistes {1}) : une copie fidèle est impossible. Nettoyez les têtes du lecteur et relancez, ou choisissez « Copie exacte du flux » si la disquette est protégée contre la copie.") }
            Fail-Restore 1 ($fmtMiss -f "$nMiss", "$(Format-TrackList $miss)")
            return
        }
        Set-RsStep 1 'ok' ((T "{0}/{1} secteurs lus") -f "$($sum.Found)", "$($sum.Total)")
        Append-Log ((T "Restauration : original lu en entier, {0}/{1} secteurs.") -f "$($sum.Found)", "$($sum.Total)")
    } else {
        # Flux : qualite piste par piste (MFM double densite) ; la decision revient a l utilisateur au changement de disquette
        if (Test-ScpHighDensity $r.Orig) {
            # Copie de flux HD : ni precompensation, ni verification gw, ni controle des pistes -> rien ne serait verifie
            Fail-Restore 1 (T 'flux haute densité : une copie de flux ne pourrait pas être contrôlée. Choisissez un format haute densité (amiga.amigados_hd, ibm.1440) pour une copie vérifiée secteur par secteur.'); return
        } else {
            try { $t = Read-ScpFile $r.Orig -Finger } catch { Fail-Restore 1 ((T "flux illisible : {0}") -f "$($_.Exception.Message)"); return }
            $n = 0; $sane = 0; $watch = 0; $crit = 0; $critKeys = @{}; $weakKeys = @{}; $unstKeys = @{}; $noMeas = @{}; $fp = $null; $maxTn = 0
            foreach ($tn in @($t.Keys | Sort-Object)) {
                # Original juge aux seuils Standard (120 / 250 ns), independants du reglage du jitter
                $m = Get-TrackMetrics $t[$tn]; $n++
                $lv = if ($m.Bad) { 2 } else { Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J $script:JitterStdOk $script:JitterStdWatch }
                $key = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
                if ([int]$tn -gt $maxTn) { $maxTn = [int]$tn }
                if ($lv -ge 2) { $crit++; $critKeys[$key] = $true } elseif ($lv -ge 1) { $watch++ } else { $sane++ }
                # Zone instable d un tour a l autre : bits faibles d une protection probable, non reproductibles
                if ($m.Weak) { $weakKeys[$key] = $true } elseif ($m.ShortUnstable -and $lv -lt 2) { $unstKeys[$key] = $true }
                elseif ($lv -lt 2 -and $m.Blocks -eq 0) { $noMeas[$key] = $true }
                # Empreinte : piste stable la plus riche en motifs, pour reconnaitre l original dans le lecteur de destination
                $r0 = $t[$tn][0]
                if ($lv -lt 2 -and -not $m.Weak -and $r0.Finger -and $r0.Finger.Count -ge 6 -and (-not $fp -or $r0.Rich -gt $fp.Rich)) {
                    $fp = @{ Tn = [int]$tn; Cyl = [int][math]::Floor([int]$tn / 2); Head = [int]$tn % 2; Fp = [string[]]$r0.Finger; Cell = [double]$r0.Cell; Rich = [int]$r0.Rich }
                }
            }
            if ($n -eq 0) { Fail-Restore 1 (T 'aucune piste dans le flux lu.'); return }
            if ($sane -eq 0 -or $crit * 2 -gt $n) {
                # 12.8 (L6-TEXTES) : un seul lecteur depuis le lot 2 : « lecteurs inverses » devient l original laisse dans un
                # autre lecteur que celui du bandeau (le lecteur lu porte alors une autre disquette)
                Fail-Restore 1 ((T "lecture sans données exploitables : {0} piste(s) critique(s) sur {1}. Disquette vierge, original dans un autre lecteur que le lecteur {2}, ou têtes sales ?") -f "$crit", "$n", "$($r.Drive)"); return
            }
            # Pistes deja critiques (cylindres non formates, protection) ou a zone instable (bits faibles) sur l original :
            # ni reecrites ni comptees au controle de la copie, jamais reecrites sur une disquette identique a l original
            $r.Read = @{ Tracks = $n; Sane = $sane; Watch = $watch; Crit = $crit; CritKeys = $critKeys; WeakKeys = $weakKeys; UnstKeys = $unstKeys; NoMeas = $noMeas; MaxCyl = [int][math]::Floor($maxTn / 2) }
            $r.Finger = $fp
            $txt = if ($weakKeys.Count -gt 0) { (T "{0} pistes : {1} saines, {2} à surveiller, {3} critiques, {4} à zone instable") -f "$n", "$sane", "$watch", "$crit", "$($weakKeys.Count)" }
                   else { (T "{0} pistes : {1} saines, {2} à surveiller, {3} critiques") -f "$n", "$sane", "$watch", "$crit" }
            # FIX2 (A1 § 3.5) : copie de flux decidee par la detection automatique ou par la relance D12 : etape en « ! », raison
            $st2 = $(if ($crit -gt 0 -or $weakKeys.Count -gt 0) { 'warn' } else { 'ok' }); $d2 = $txt
            if ($r.Choice -eq 'auto' -and $r.FluxWhy) { $st2 = 'warn'; $d2 = ((T "copie exacte du flux, {0}") -f "$($r.FluxWhy)") + ' ; ' + $txt }
            Set-RsStep 1 $st2 $d2
            Append-Log ((T "Restauration : flux de l'original, {0}.") -f "$txt")
            if ($weakKeys.Count -gt 0) {
                Append-Log ((T "Restauration : {0} piste(s) non reproductible(s) sur l'original, zone instable d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable, ou défaut localisé. La copie n'en recevra qu'un tour figé : la protection risque de ne pas fonctionner. Ces pistes ne sont jamais réécrites sur une disquette identique à l'original.") -f "$($weakKeys.Count)", "$(Format-TrackList (Sort-TrackKeys @($weakKeys.Keys)))")
            }
            if ($unstKeys.Count -gt 0) {
                Append-Log ((T "Restauration : {0} piste(s) avec une courte zone instable ({1}) : raccord d'écriture ou protection possible. Elles ne seront jamais réécrites sur une disquette identique à l'original.") -f "$($unstKeys.Count)", "$(Format-TrackList (Sort-TrackKeys @($unstKeys.Keys)))")
            }
            if ($fp) { Append-Log ((T "Restauration : empreinte de l'original prise sur la piste {0}.{1} ({2} blocs de référence) : la disquette de destination y sera comparée.") -f "$($fp.Cyl)", "$($fp.Head)", "$($fp.Fp.Count)") }
            else { Append-Log (T "Restauration : aucune piste de l'original ne permet une empreinte fiable : la disquette de destination ne pourra pas être comparée à l'original.") }
        }
    }
    Enter-RestoreWait ''
}

function Enter-RestoreWait([string]$extra) {
    $r = $script:Restore
    $r.Stage = 'wait'; $r.Waiting = $true
    Set-RsStep 2 'run'
    # 12.8 (D10) : un seul lecteur, le changement de disquette est toujours demande
    $msg = if ($r.SwapBack) { (T "Calibration terminée. Retirez la disquette sacrifiée du lecteur {0} et insérez la disquette de DESTINATION : tout son contenu sera remplacé. Elle sera de nouveau vérifiée avant l'écriture.") -f "$($r.Drive)" }
           else { (T "Retirez l'ORIGINAL du lecteur {0} et rangez-le. Insérez la disquette de DESTINATION : tout son contenu sera remplacé.") -f "$($r.Drive)" }
    if ($extra) { $msg = $extra + "`n" + $msg }
    if ($r.Mode -eq 'flux' -and $r.Read -and $r.Read.WeakKeys -and $r.Read.WeakKeys.Count -gt 0) { $msg = ((T "PROTECTION PROBABLE : {0} piste(s) de l'original changent d'un tour à l'autre (bits faibles) : une copie ne peut pas les reproduire et risque de ne pas fonctionner.") -f "$($r.Read.WeakKeys.Count)") + "`n" + $msg }
    if ($r.Mode -eq 'flux' -and $r.Read -and $r.Read.Crit -gt 0) { $msg = ((T "{0} piste(s) critique(s) dans la lecture : normal pour une protection, sinon nettoyez le lecteur et relancez.") -f "$($r.Read.Crit)") + "`n" + $msg }
    $lblRsWait.Text = $msg + ' ' + (T 'Puis cliquez sur « Continuer ».')
    $btnRsForce.Visible = [bool]$r.Override
    # Boutons sous le texte (hauteur variable) ; « Ecraser quand meme » seul sur une seconde ligne
    $y = $lblRsWait.Bottom + 8
    $btnRsGo.Location = New-Object System.Drawing.Point(8, $y)
    $btnRsCancel.Location = New-Object System.Drawing.Point(($btnRsGo.Right + 8), $y)
    $bottom = $btnRsGo.Bottom
    if ($r.Override) { $btnRsForce.Location = New-Object System.Drawing.Point(8, ($btnRsGo.Bottom + 8)); $bottom = $btnRsForce.Bottom }
    $pnlRsWait.Height = $bottom + 8
    $pnlRsWait.Visible = $true; $pnlRsWait.BringToFront(); $lblRsRules.Visible = $false
    $lblRsNow.Text = ''
    Show-Tab $tabRs
    $tabRs.ScrollControlIntoView($pnlRsWait)                 # fenetre basse : l encadre et son bouton Continuer restent visibles
    $stOp.Text = (T 'Restauration : changez de disquette, puis cliquez sur « Continuer » dans l''onglet Restauration.')
    Append-Log ((T "Restauration : en attente de la disquette de destination dans le lecteur {0}.") -f "$($r.Drive)")
    try { [System.Media.SystemSounds]::Exclamation.Play() } catch { }
}

function Get-RestoreKeepCyls {
    # Flux : cylindres portant une piste non reproductible (zone instable, meme courte) ou deja critique sur l original,
    # jamais reecrits sur une disquette identique a l original
    $r = $script:Restore; $set = @{}
    if (-not $r -or $r.Mode -ne 'flux' -or -not $r.Read) { return @() }
    $src = @(@($r.Read.CritKeys.Keys) + @($r.Read.WeakKeys.Keys))
    if ($r.Read.UnstKeys) { $src += @($r.Read.UnstKeys.Keys) }
    foreach ($k in $src) { $set[[int](([string]$k -split '\.')[0])] = $true }
    return @($set.Keys | Sort-Object)
}

function Resume-Restore([bool]$force) {
    # 12.8 (D7) : reprise seulement par « Continuer » ou « Ecraser quand meme » ; plus de reprise automatique apres la
    # remise de la destination qui suit une calibration sur disquette sacrifiee (la disquette inseree n est pas connue)
    $r = $script:Restore
    if (-not $r -or -not $r.Waiting) { return }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        [void](Show-AppMessage (T 'Une commande gw est encore en cours : attendez sa fin.') (T 'Restauration') 'OK' 'Information'); return
    }
    if ($force) {
        # « Ecraser quand meme » : la disquette inseree a le contenu de l original, c est peut-etre l original lui-meme.
        # Flux : les cylindres non reproductibles ne seront pas reecrits ; secteur : toute protection hors secteurs serait detruite.
        if ($r.Mode -eq 'sector') { $msg = (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nEn mode secteur, chaque piste est réécrite au format standard : si la disquette porte une protection contre la copie (piste non standard, bits faibles), elle sera définitivement détruite. Pour une disquette protégée, utilisez « Copie exacte du flux ».`n`nÉcraser quand même cette disquette ?") }
        else {
            $keep = @(Get-RestoreKeepCyls)
            # Chaque cylindre a preserver : aucune ecriture possible sans detruire la protection -> refus
            $incF = @(); if ($r.Read) { $incF = @(0..([int]$r.Read.MaxCyl) | Where-Object { $keep -notcontains $_ }) }
            if ($keep.Count -gt 0 -and $incF.Count -eq 0) {
                [void](Show-AppMessage ((T "La disquette insérée a le même contenu que l'original. Chaque cylindre ({0}) porte une piste non reproductible ou critique : aucun cylindre ne peut être réécrit sans détruire la protection. Écriture refusée : insérez une autre disquette.") -f "$(Format-CylList $keep)") (T 'Restauration') 'OK' 'Warning')
                return
            }
            $msg = if ($keep.Count -gt 0) { (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nLes cylindres qui portent des pistes non reproductibles ou déjà critiques sur l'original ({0}) ne seront pas réécrits : leur protection éventuelle est préservée. Les autres pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?") -f "$(Format-CylList $keep)" }
                   else { (T "La disquette insérée a le même contenu que l'original : c'est peut-être l'ORIGINAL lui-même.`n`nAucune piste non reproductible n'a été détectée : toutes les pistes seront effacées puis réécrites à partir de la lecture.`n`nÉcraser quand même cette disquette ?") }
        }
        # 12.8 (D3) : confirmation par frmConfirm, case qui nomme le lecteur de destination
        $cq = @{ Title = (T 'Restauration'); Heading = (T "C'est peut-être l'ORIGINAL"); Text = $msg; Level = 'danger'; Picto = 'forbid'
                 Check = ((T 'La disquette du lecteur {0} peut être écrasée') -f "$($r.Drive)"); GoText = (T 'Écraser quand même'); GoGlyph = 'Save' }
        if (-not (Show-AppConfirm @cq)) { return }
    } elseif ($r.Mode -eq 'flux' -and -not $r.Finger) {
        # Copie de flux sans empreinte exploitable : aucune sonde possible, confirmation explicite que l original a ete retire
        # (12.8, D3 : frmConfirm, case qui nomme le lecteur de destination)
        $cq = @{ Title = (T 'Restauration'); Heading = (T 'Changement de disquette non vérifiable'); Level = 'warn'; Picto = 'data'
                 Text = (T "Copie de flux : l'application ne peut pas vérifier que la disquette insérée n'est pas l'original.`n`nAvez-vous bien retiré l'ORIGINAL et inséré la disquette de DESTINATION ?")
                 Check = ((T "J'ai retiré l'ORIGINAL et inséré la disquette de DESTINATION dans le lecteur {0}") -f "$($r.Drive)"); GoText = (T 'Écrire la copie'); GoGlyph = 'Save' }
        if (-not (Show-AppConfirm @cq)) { return }
    }
    $r.Waiting = $false; $r.SwapBack = $false; $pnlRsWait.Visible = $false; $r.Idle = Get-Date; $r.Override = $false
    # 12.8 (F3R-FIX, constat 3) : une disquette jugee differente par la sonde, ou confirmee comme changee, n est plus
    # l original, meme apres un « Ecraser quand meme » sur une disquette precedente (mesure de la destination, cylindres
    # preserves d une copie de flux)
    if (-not $force) { $r.OnOriginal = $false }
    Set-RsStep 2 'ok'
    if (-not $force -and ($r.Mode -eq 'sector' -or $r.Finger)) { Start-RestoreProbe; return }
    if ($force) { $r.OnOriginal = $true; Set-RsStep 3 'warn' (T 'contrôle ignoré à votre demande') }
    else { Set-RsStep 3 'skip' (T "non vérifiable : aucune empreinte exploitable sur l'original") }
    Start-RestoreWrite
}

function Start-RestoreProbe {
    # Lecture du seul cylindre 0 de la disquette inseree (3 tours, 2 essais) : identique a l original -> c est l original
    $r = $script:Restore
    $r.Stage = 'probe'
    Set-RsStep 3 'run'
    Remove-Item -LiteralPath $r.Probe -ErrorAction SilentlyContinue
    if ($r.Mode -eq 'flux') {
        # Flux : lecture de la piste de l empreinte (2 tours), comparee aux blocs de reference de l original
        $f = $r.Finger
        $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--tracks=c=$($f.Cyl):h=$($f.Head)$($r.Extras)", '--revs=2', "`"$($r.Probe)`"")
    } else {
        $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--format=$($r.Fmt)", "--tracks=c=0:h=0-1$($r.Extras)", '--revs=3', '--retries=2', "`"$($r.Probe)`"")
    }
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Restore-ProbeFailed {
    # Sonde sans resultat (pas de disquette, pas d index) : retour a l attente plutot qu un abandon
    $r = $script:Restore
    $script:Chain.Clear()
    $r.Override = $false
    Set-RsStep 3 'pending'
    Enter-RestoreWait (T 'Aucune disquette lisible n''a été détectée dans le lecteur de destination.')
}

function Complete-RestoreProbe {
    $r = $script:Restore
    if (-not (Test-Path -LiteralPath $r.Probe)) { Restore-ProbeFailed; return }
    if ($r.Mode -eq 'flux') {
        # Empreinte : au moins les trois quarts des blocs de reference retrouves -> memes donnees que l original
        $f = $r.Finger; $fl = $null
        try { $fl = Read-ScpTrackFlux $r.Probe $f.Tn } catch { $fl = $null }
        if (-not $fl -or $fl.Count -eq 0) { Restore-ProbeFailed; return }
        $hit = [ScpStats]::Match($fl, [double]$f.Cell, [string[]]$f.Fp)
        Append-Log ((T "Restauration : empreinte de la piste {0}.{1} retrouvée {2} fois sur {3} sur la disquette insérée.") -f "$($f.Cyl)", "$($f.Head)", "$hit", "$($f.Fp.Count)")
        if ($hit * 4 -ge $f.Fp.Count * 3) {
            Set-RsStep 3 'fail' (T 'la disquette insérée semble être l''original')
            Append-Log ((T "Restauration : la disquette de destination porte les mêmes données que l'original (empreinte de la piste {0}.{1}). Écriture refusée.") -f "$($f.Cyl)", "$($f.Head)")
            $r.Override = $true
            Enter-RestoreWait (T "ATTENTION : la disquette insérée porte les mêmes données que l'original, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit d'une ancienne copie à remplacer entièrement, cliquez sur « Annuler », effacez-la (case « Mode expert », onglet Outils, bouton « EFFACER »), puis relancez la restauration. « Écraser quand même » sert à rafraîchir l'original : les cylindres non reproductibles ou critiques ne sont ni réécrits ni contrôlés.")
            return
        }
        Set-RsStep 3 'ok' (T 'ce n''est pas l''original')
        Start-RestoreWrite
        return
    }
    # Cylindre 0, secteur par secteur : un secteur non relu par la sonde (motif BAD SECTOR de gw) ne compte pas ;
    # au moins un secteur lu et tous les secteurs lus identiques a l original -> c est l original (meme abime)
    $a = [System.IO.File]::ReadAllBytes($r.Orig); $p = [System.IO.File]::ReadAllBytes($r.Probe)
    $spt = Get-SectorsPerTrack $r.Fmt
    $n = if ($spt -gt 0) { 2 * $spt * 512 } else { 1024 }
    $n = [math]::Min($n, [math]::Min($a.Length, $p.Length))
    $pat = [System.Text.Encoding]::ASCII.GetBytes('-=[BAD SECTOR]=-')
    $readable = 0; $differ = 0
    for ($s = 0; $s + 512 -le $n; $s += 512) {
        $isBad = $true
        for ($i = 0; $i -lt 512; $i++) { if ($p[$s + $i] -ne $pat[$i % 16]) { $isBad = $false; break } }
        if ($isBad) { continue }
        $readable++
        for ($i = 0; $i -lt 512; $i++) { if ($a[$s + $i] -ne $p[$s + $i]) { $differ++; break } }
    }
    $same = ($readable -gt 0 -and $differ -eq 0)
    if ($same) {
        Set-RsStep 3 'fail' (T 'la disquette insérée semble être l''original')
        Append-Log (T 'Restauration : la disquette de destination contient les mêmes données que l''original sur le cylindre 0. Écriture refusée.')
        $r.Override = $true
        Enter-RestoreWait (T "ATTENTION : la disquette insérée a le même contenu que l'original sur le cylindre 0, c'est probablement l'ORIGINAL. Changez de disquette. S'il s'agit bien d'une copie à remplacer, cliquez sur « Écraser quand même ».")
        return
    }
    Set-RsStep 3 'ok' (T 'ce n''est pas l''original')
    Start-RestoreWrite
}

function Get-RestoreCalibInfo([string]$fam, [int]$nCyl = 0) {
    # Calibration de l ecriture stricte : une calibration existante (par tete si a jour, sinon commune, comme l applique
    # l ecriture lente) n est jamais refaite ; Need seulement si la famille n en a aucune. Notes : reserves a signaler,
    # dont une courbe plus courte que l image de nCyl cylindres (> 0) de plus de 4 cylindres (Get-CalibState 'short')
    $cvs = Get-FamilyCurves $fam $true
    if ($cvs.Count -eq 0) { return @{ Need = $true; Text = (T 'aucune calibration existante'); Notes = @() } }
    $text = if ($cvs.Count -gt 1) { (T 'par tête') } else { (T 'commune aux deux têtes') }
    $notes = New-Object System.Collections.Generic.List[string]
    foreach ($cv in $cvs) {
        $n = @()
        if ($cv.Method -ne 'motif') { $n += (T 'mesurée sur le contenu d''une image, avant le motif de test') }
        if ($cv.Drive -and [string]$cv.Drive -ne $script:Restore.Drive) { $n += ((T "mesurée sur le lecteur {0}") -f "$($cv.Drive)") }
        if ($cv.Converged -eq $false) { $n += (T 'non convergée') }
        if ((Get-CurveCalc $cv) -ne (Get-CurveCalcRef $cv)) { $n += ((T "calcul de calibration {0}") -f (Get-CurveCalcText $cv)) }
        if (Test-CurveAtMax $cv) { $n += ((T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $cv)") }
        $vc = @($cv.Values).Count
        if ($nCyl -gt 0 -and $vc -lt $nCyl - 4) { $n += ((T "courbe de {0} cylindres pour une image de {1}") -f "$vc", "$nCyl") }
        foreach ($x in $n) { if (-not $notes.Contains($x)) { $notes.Add($x) } }
    }
    return @{ Need = $false; Text = $text; Notes = $notes.ToArray() }
}

function Set-RestoreRepRules {
    # Copie de flux : pistes deja critiques ou non reproductibles sur l original ni reecrites ni comptees au controle ;
    # zones instables relues sur la copie (courtes zones, pistes non mesurables de l original) non jugees. 12.8
    # (decision 3) : aussi apres la mesure de la destination (Complete-LevelCalib lance alors l ecriture)
    $r = $script:Restore
    if (-not $r -or $r.Mode -ne 'flux' -or -not $script:Rep -or -not $r.Read) { return }
    $ign = @{}
    foreach ($k in @(@($r.Read.CritKeys.Keys) + @($r.Read.WeakKeys.Keys))) { $ign[[string]$k] = $true }
    if ($ign.Count -gt 0) { $script:Rep.Ignore = $ign }
    $script:Rep.SrcWeak = $r.Read.WeakKeys
    $nj = @{}; foreach ($k in @(@($r.Read.UnstKeys.Keys) + @($(if ($r.Read.NoMeas) { $r.Read.NoMeas.Keys } else { @() })))) { $nj[[string]$k] = $true }
    $script:Rep.NoJudge = $nj
}

function Start-RestoreWrite {
    $r = $script:Restore
    $r.Stage = 'write'; $r.Idle = Get-Date
    $script:LastCheck = $null
    $r.InCall = $true
    try {
        # Regles strictes dans l onglet Ecriture (etat d origine remis en fin de restauration)
        Set-WritePreset 'slow' $r.Orig ("restore|" + $r.Orig)
        if ($r.Mode -eq 'sector') { Set-Combo $cmbWFmt $r.Fmt }
        if ($r.Mode -eq 'flux' -and $r.OnOriginal -and $r.Read) {
            # Ecriture sur une disquette identique a l original (« Ecraser quand meme ») : cylindres non reproductibles exclus
            $keep = @(Get-RestoreKeepCyls)
            if ($keep.Count -gt 0) {
                $inc = @(0..([int]$r.Read.MaxCyl) | Where-Object { $keep -notcontains $_ })
                if ($inc.Count -eq 0) {
                    # Garde : jamais d ecriture complete sur l original quand tout est a preserver
                    $r.InCall = $false
                    Fail-Restore 3 (T "aucun cylindre réécrivable sans toucher aux pistes non reproductibles : rien n'a été écrit")
                    return
                }
                if ($inc.Count -gt 0) {
                    $txtWTracks.Text = "c=$(Format-CylList $inc)$($r.Extras)"
                    $r.Preserved = $keep
                    Append-Log ((T "Restauration : écriture sur une disquette identique à l'original : cylindres {0} non réécrits (pistes non reproductibles, protection préservée).") -f "$(Format-CylList $keep)")
                }
            }
        }
        Set-Num $numWRetries $script:RestoreRules.WriteRetries
        Set-Num $numWRepair $script:RestoreRules.RepairPasses
        $chkWNoVerify.Checked = $false; $chkWPostCheck.Checked = $true; $chkWPrecomp.Checked = $true
        # 12.8 (decision 3 du 21/10/2026) : destination qui n est pas l original (empreinte non retrouvee, cylindre 0
        # different, ou changement de disquette confirme quand il n est pas verifiable) : mesuree avant l ecriture, en copie
        # secteur, quand une calibration existe (ou apres une calibration sur disquette sacrifiee) : calibration rapide
        # (adaptative, avec la marque) ou, selon la liste « Mesure » de l onglet Ecriture (write.levelBeforeWriteMode, S3-FLUX),
        # mesure complete de cette disquette (Start-LevelBeforeWrite) ; une calibration n est jamais refaite. Regles de
        # « Mesurer la disquette avant l ecriture lente » et du test rapide (D5) ; toute mesure non faite a sa ligne de
        # journal. 12.8 avant cette decision : mesure seulement avec le test rapide ou la case « Mesurer la disquette ».
        # 12.8 (S3-FLUX, decision 2 du 21/10/2026) : copie de flux jamais mesuree : gw n applique pas --precomp a un flux
        # brut (Test-RawFluxWrite) ; ligne de journal (F3R : mesure par Get-RestoreFluxLevel, sans effet sur l ecriture)
        $measure = -not $r.OnOriginal
        $r.LevelNote = ''   # 12.8 (F3R-FIX) : raison d une ecriture precedente (autre disquette) oubliee
        $skipFmt = (T "Restauration : disquette de destination non mesurée avant l'écriture : {0}.")
        if ($r.Mode -eq 'flux') { $measure = $false; Append-Log ($skipFmt -f (T "copie exacte du flux, écrite telle quelle par gw, sans précompensation ; la mesure ne servirait pas")) }
        elseif (-not $measure) { $r.LevelNote = (T "elle a le contenu de l'original, écrasée à votre demande : la mesure ne se fait que sur une autre disquette"); Append-Log ($skipFmt -f $r.LevelNote) }
        $cmbWCalMode.SelectedIndex = 1
        Update-PrecompForImage $r.Orig
        $r.SwapBack = $false
        $noCalib = $false
        if ($r.Mode -eq 'sector') {
            $r.HD = [string](Get-HighDensityReason $r.Orig $r.Fmt)
            if ($r.HD) {
                if ($measure) { $r.LevelNote = (T "haute densité ({0}), sans calibration rapide") -f "$($r.HD)"; Append-Log ($skipFmt -f $r.LevelNote) }
            } else {
                if ($r.CalibDone) { $noCalib = $true }          # calibration faite sur une disquette sacrifiee, destination remise
                else {
                    $rc = (Get-CalibCylinders $r.Orig $r.Fmt).NCyl
                    $ci = Get-RestoreCalibInfo (Get-ImageFamily $r.Orig) $(if ($null -eq $rc) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$rc)) })
                    if ($ci.Need) {
                        $r.Calib = $ci.Text; Append-Log ((T "Restauration : calibration par tête en test fin ({0}).") -f "$($ci.Text)")
                        if ($measure) { Append-Log (T "Restauration : la disquette de destination sera mesurée après la calibration si celle-ci est faite sur une disquette sacrifiée ; faite sur la destination elle-même, la calibration complète en tient lieu.") }
                    }
                    else {
                        $noCalib = $true; $r.CalibUsed = $ci
                        Append-Log ((T "Restauration : calibration existante utilisée ({0}), le lecteur n'est pas recalibré.") -f "$($ci.Text)")
                        if ($ci.Notes.Count -gt 0) { Append-Log ((T "Remarque sur cette calibration : {0}. Pour la refaire, lancez « Calibrer » dans l'onglet Écriture, « Écriture lente » cochée, avant la restauration.") -f "$($ci.Notes -join ' ; ')") }
                    }
                }
            }
        }
        Append-Log ((T "Restauration : écriture tête par tête, {0} essais par piste, contrôle de toutes les pistes ({1} passes au plus).") -f "$($script:RestoreRules.WriteRetries)", "$($script:RestoreRules.RepairPasses)")
        Start-PresetWrite 'slow' -NoCalib:$noCalib -LevelOnly:($measure -and $noCalib -and $r.Mode -eq 'sector' -and -not $r.HD)
        Set-RestoreRepRules
    } finally { $r.InCall = $false; $r.Idle = Get-Date }
    if (-not $script:Restore) { return }
    if ($script:Cal) { Set-RsStep 4 'run' }
    elseif ($script:GwProc -and -not $script:GwProc.HasExited) {
        if ($r.Mode -ne 'sector') { Set-RsStep 4 'skip' $(if ($r.LevelNote) { (T "niveau non mesuré : {0}") -f "$($r.LevelNote)" } else { (T 'non applicable à une copie de flux') }) }
        elseif ($r.HD) { Set-RsStep 4 'skip' ((T "non applicable : {0}") -f "$($r.HD)") }
        elseif ($r.CalibUsed) {
            $d = (T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)"
            if ($r.CalibUsed.Notes.Count -gt 0) { $d += ' ; ' + ($r.CalibUsed.Notes -join ' ; ') }
            if ($r.LevelNote) { $d += ' ; ' + ((T "niveau non mesuré : {0}") -f "$($r.LevelNote)") }
            Set-RsStep 4 $(if ($r.CalibUsed.Notes.Count -gt 0 -or $r.LevelNote) { 'warn' } else { 'ok' }) $d
        }
        elseif ($r.CalibDone -and $r.LevelNote) {
            $s4 = $r.Steps[4]
            $d = if ($s4 -and $s4.Detail) { $s4.Detail } else { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
            Set-RsStep 4 'warn' ($d + ' ; ' + ((T "niveau non mesuré : {0}") -f "$($r.LevelNote)"))
        }
        Set-RsStep 5 'run' $(if ($script:WriteWarm) { (T 'préchauffage du lecteur') } else { '' })
    } else {
        Fail-Restore 4 (T 'l''écriture n''a pas démarré (calibration refusée ou annulée ? voir le journal)')
    }
}

function Set-RsCalibDone {
    # Calibration terminee pendant la restauration : convergence des deux courbes par tete, courbe a la borne de son
    # calcul (meme reserve que Get-RestoreCalibInfo a la restauration suivante)
    $r = $script:Restore
    if ($r.Level) { Set-RsStep 4 $r.Level.State $r.Level.Text; return }
    $fam = Get-ImageFamily $r.Orig
    $nc = @(@(0, 1) | Where-Object { $cv = $script:PrecompCurves["${fam}_h$_"]; $cv -and $cv.Converged -eq $false })
    $am = @(@(0, 1) | ForEach-Object { $script:PrecompCurves["${fam}_h$_"] } | Where-Object { Test-CurveAtMax $_ })
    $d = if ($nc.Count -gt 0) { (T 'faite, non convergée sur une tête : voir le journal') }
         elseif ($r.CalSwap) { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" }
         elseif ($r.Calib) { (T "faite ({0})") -f "$($r.Calib)" } else { '' }
    if ($am.Count -gt 0) {
        $ct = (T "courbe au plafond de {0} ns de son calcul") -f "$(Get-CurveMaxNs $am[0])"
        $d = if ($d) { "$d ; $ct" } else { $ct }
    }
    Set-RsStep 4 $(if ($nc.Count -gt 0 -or $am.Count -gt 0) { 'warn' } else { 'ok' }) $d
}

function Enter-RestoreSwapBack {
    # Calibration faite sur une disquette sacrifiee : etape terminee, la destination est redemandee puis de nouveau
    # sondee (Resume-Restore -> Start-RestoreProbe) ; l ecriture reprend ensuite sans recalibrer (CalibDone).
    $r = $script:Restore
    $r.CalSwap = $true
    Set-RsCalibDone
    $r.CalibDone = $true; $r.SwapBack = $true
    # 12.8 (D7) : attente de « Continuer », sans compte a rebours ni reprise automatique (12.7 : reprise au bout du delai
    # de l avertissement de calibration)
    Set-RsStep 3 'pending'
    Append-Log (T 'Restauration : calibration terminée sur la disquette sacrifiée.')
    Enter-RestoreWait ''
}

function Update-RestoreProgress {
    # Appele par le timer : etape en cours pendant l ecriture deleguee, ligne d avancement, chien de garde
    $r = $script:Restore
    if (-not $r) { return }
    $busy = (($script:GwProc -and -not $script:GwProc.HasExited) -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:WriteWarm -or $r.Waiting -or $r.InCall)
    if ($busy) { $r.Idle = Get-Date }
    elseif (((Get-Date) - $r.Idle).TotalSeconds -gt 5) { Stop-Restore (T 'séquence arrêtée sans suite, voir le journal'); return }
    if ($r.Stage -eq 'write') {
        if ($script:Cal) {
            if ($r.Cur -ne 4) { Set-RsStep 4 'run' }
        } elseif ($script:Rep -and $null -ne $script:Rep.Scope) {
            if ($r.Cur -lt 6) {
                if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
                Set-RsStep 5 'ok'; Set-RsStep 6 'run'
            }
        } elseif ($script:GwProc -and $r.Cur -lt 5) {
            if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
            Set-RsStep 5 'run' $(if ($script:WriteWarm) { (T 'préchauffage du lecteur') } else { '' })
        }
    }
    $now = if ($script:Cal -or $script:WriteWarm) { $lblWCal.Text } elseif ($script:GwProc) { ($stOp.Text + '   ' + $stTrack.Text).Trim() } else { '' }
    if ($lblRsNow.Text -ne $now) { $lblRsNow.Text = $now }
}

function Start-RestoreCompare {
    # Ecriture et controle termines (accroches) : bilan, puis relecture de la copie sans nouvel essai
    $r = $script:Restore
    $chk = $script:LastCheck
    if ($r.Steps.ContainsKey(4) -and $r.Steps[4].State -eq 'run') { Set-RsCalibDone }
    Set-RsStep 5 'ok'
    if ($chk) { Set-RsStep 6 $(if ($chk.Ok) { 'ok' } else { 'fail' }) $chk.Short }
    else { Set-RsStep 6 'skip' (T 'non applicable à ce format') }
    if ($r.Mode -ne 'sector') { Set-RsStep 7 'skip' (T 'non applicable à une copie de flux'); Finish-Restore; return }
    $r.Stage = 'compare'
    Set-RsStep 7 'run'
    Remove-Item -LiteralPath $r.Back -ErrorAction SilentlyContinue
    $script:RestoreArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @("--format=$($r.Fmt)", "--retries=$($script:RestoreRules.FinalRetries)")
    if ($r.Extras) { $script:RestoreArgs += "--tracks=$($r.Extras.TrimStart(':'))" }
    $script:RestoreArgs += "`"$($r.Back)`""
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw $script:RestoreArgs })
    $script:Chain.Enqueue({ Invoke-RestoreNext })
    Invoke-NextChainStep
}

function Complete-RestoreCompare {
    $r = $script:Restore
    $script:GwCapture = $null
    if (-not (Test-Path -LiteralPath $r.Back)) {
        $r.Cmp = @{ Ok = $false; Text = (T 'relecture de la copie impossible') }
        Set-RsStep 7 'fail' $r.Cmp.Text; Finish-Restore; return
    }
    $a = [System.IO.File]::ReadAllBytes($r.Orig); $b = [System.IO.File]::ReadAllBytes($r.Back)
    if ($script:FastCompare) { $diff = @([GwCompare]::DiffSectors($a, $b, 512)) }
    else {
        $set = New-Object System.Collections.Generic.HashSet[int]
        $n = [Math]::Max($a.Length, $b.Length)
        for ($i = 0; $i -lt $n; $i++) { if ($i -ge $a.Length -or $i -ge $b.Length -or $a[$i] -ne $b[$i]) { [void]$set.Add([int][Math]::Floor($i / 512)) } }
        $diff = @($set | Sort-Object)
    }
    $unread = Get-BadSectorBlocks $r.Back
    $total = [int][math]::Ceiling([math]::Max($a.Length, $b.Length) / 512)
    if ($diff.Count -eq 0) {
        $r.Cmp = @{ Ok = $true; Text = ((T "identique, {0} secteurs") -f "$total") }
        Set-RsStep 7 'ok' $r.Cmp.Text
        Append-Log ((T "Restauration : copie IDENTIQUE à l'original, {0} secteurs relus du premier coup.") -f "$total")
    } else {
        $trk = Get-BlockTracks ([int[]]$diff) $r.Fmt
        $r.Cmp = @{ Ok = $false; Text = ((T "{0} secteur(s) différent(s) sur {1}, dont {2} non relu(s) du premier coup ; pistes {3}") -f "$($diff.Count)", "$total", "$($unread.Count)", "$(Format-TrackList $trk)") }
        Set-RsStep 7 'fail' ((T "{0} secteur(s) différent(s)") -f "$($diff.Count)")
        Append-Log ((T "Restauration : copie DIFFÉRENTE de l'original : {0}.") -f "$($r.Cmp.Text)")
    }
    Finish-Restore
}

function Write-RestoreReport([bool]$ok, [string]$verdict) {
    $r = $script:Restore
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add(((T "Greaseweazle Studio v{0} - rapport de restauration") -f "$($script:Version)"))
    $L.Add(((T "Date        : {0}, durée {1} min") -f (Get-Date -Format 'dd/MM/yyyy HH:mm'), "$([math]::Round(((Get-Date) - $r.Start).TotalMinutes, 1))"))
    $L.Add(((T "Disquette   : {0}") -f "$($r.Name)"))
    $L.Add(((T "Mode        : {0}") -f $(if ($r.Mode -eq 'sector') { (T "secteur par secteur, format {0}") -f "$($r.Fmt)" } elseif ($r.Mode -eq 'flux') { (T 'copie exacte du flux') } else { (T 'format détecté à la lecture') })))
    # 12.8 : format de la detection automatique ; un seul lecteur (D10)
    if ($r.Choice -eq 'auto' -and $r.Found) { $L.Add(((T "Détection   : {0}") -f "$($r.Found)")) }
    $L.Add(((T "Lecteur     : {0}") -f "$($r.Drive)"))
    if ($r.Orig) { $L.Add(((T "Original lu : {0}") -f "$($r.Orig)")) }
    # FIX2 : lecture secteur incomplete gardee avant la relance D12
    if ($r.SectorRead) { $L.Add(((T "Incomplète  : {0} (lecture secteur, {1} secteur(s) illisible(s), {2} hors du format ; relancée en copie exacte du flux)") -f "$($r.SectorRead.Path)", "$($r.SectorRead.Miss)", "$($r.SectorRead.Extra)")) }
    if ($r.Mode -eq 'sector') { $L.Add(((T "Copie relue : {0}") -f "$($r.Back)")) }
    if ($r.Read -and $r.Read.WeakKeys -and $r.Read.WeakKeys.Count -gt 0) { $L.Add(((T "Instables   : {0} (zone instable d'un tour à l'autre : protection contre la copie probable, non reproductible)") -f "$(Format-TrackList (Sort-TrackKeys @($r.Read.WeakKeys.Keys)))")) }
    if ($r.Level) { $L.Add(((T "Niveau      : {0}") -f "$($r.Level.Report)")) }
    if ($r.Preserved -and @($r.Preserved).Count -gt 0) { $L.Add(((T "Préservés   : cylindres {0}, non réécrits sur la disquette identique à l'original") -f "$(Format-CylList @($r.Preserved))")) }
    $rr = $script:RestoreRules
    $L.Add(((T "Règles      : lecture {0} tours, {1} essais x {2} séries ; destination mesurée avant l'écriture quand c'est possible (calibration rapide) ; écriture tête par tête, calibration existante conservée (calibration par tête en test fin si aucune n'existe), pré-effacement, vérification gw, {3} essais par piste ; contrôle de toutes les pistes, {4} passes de réécriture au plus ; relecture finale sans nouvel essai.") -f "$($rr.ReadRevs)", "$($rr.ReadRetries)", "$($rr.SeekRetries + 1)", "$($rr.WriteRetries)", "$($rr.RepairPasses)"))
    $L.Add('')
    $L.Add((T 'Étapes :'))
    $marks = @{ pending = '[ ]'; run = '[>]'; ok = '[OK]'; fail = '[ECHEC]'; skip = '[-]'; warn = '[!]' }
    for ($i = 0; $i -lt $script:RsStepNames.Count; $i++) {
        $s = if ($r.Steps.ContainsKey($i)) { $r.Steps[$i] } else { @{ State = 'pending'; Detail = '' } }
        $L.Add(("  {0,-7} {1}{2}" -f $marks[$s.State], $script:RsStepNames[$i], $(if ($s.Detail) { ' : ' + $s.Detail } else { '' })))
    }
    if ($script:LastCheck) { $L.Add(''); $L.Add($script:LastCheck.Text) }
    $L.Add('')
    $L.Add(((T "Verdict     : {0}") -f "$verdict"))
    # Echec avant la fin de la detection (format pas encore connu) : rapport sous le nom de la restauration, sans ecrasement
    if (-not $r.Report) { $r.Report = $(if ($r.Stem) { $r.Stem } else { Get-RestoreStem $r.Dir $r.Name }) + ' - ' + (T 'rapport') + '.txt' }
    try { [System.IO.File]::WriteAllLines($r.Report, $L, (New-Object System.Text.UTF8Encoding($true))); Append-Log ((T "Rapport     : {0}") -f "$($r.Report)") }
    catch { Append-Log ((T "Rapport non enregistré : {0}") -f "$($_.Exception.Message)") }
}

function Show-RestoreResult([bool]$ok, [string]$text, [string]$icon = '') {
    # 12.8 (lot 3b) : icone d etat de 48 px dans la marge gauche du verdict : h0 reussie, h1 reussie avec reserve, h2 echouee
    $script:RsResultIcon = $(if ($icon) { $icon } elseif ($ok) { 'h0' } else { 'h2' })
    $lblRsResult.Text = $text
    # 12.8 (FIX3) : reussie avec reserve (h1) : teinte « stop » de frmClean et encre Theme.WarnInk (4,84:1), comme l icone h1
    # de la carte et de l onglet Ecriture, et non le vert de la reussite
    $warnRes = ($ok -and $script:RsResultIcon -eq 'h1')
    $lblRsResult.BackColor = if ($warnRes) { [System.Drawing.Color]::FromArgb(253, 243, 228) } elseif ($ok) { [System.Drawing.Color]::FromArgb(222, 244, 228) } else { [System.Drawing.Color]::FromArgb(252, 226, 224) }
    $lblRsResult.ForeColor = if ($warnRes) { $script:Theme.WarnInk } elseif ($ok) { [System.Drawing.Color]::FromArgb(20, 90, 45) } else { [System.Drawing.Color]::FromArgb(140, 30, 25) }
    $pnlRsWait.Visible = $false; $lblRsNow.Text = ''
    $lblRsResult.Visible = $true; $lblRsResult.BringToFront(); $lblRsRules.Visible = $false
    $tabRs.ScrollControlIntoView($lblRsResult)
}

function Finish-Restore {
    $r = $script:Restore
    if (-not $r) { return }
    $chk = $script:LastCheck
    $reasons = @()
    if ($chk -and -not $chk.Ok) { $reasons += $chk.Short }
    if ($r.Mode -eq 'sector' -and -not ($r.Cmp -and $r.Cmp.Ok)) { $reasons += $(if ($r.Cmp) { $r.Cmp.Text } else { (T 'comparaison non faite') }) }
    $ok = ($reasons.Count -eq 0)
    if ($ok) {
        $verdict = (T 'RESTAURATION RÉUSSIE')
        # Pistes instables reellement reecrites (un tour fige) et pistes instables preservees (cylindres non reecrits)
        $pres = @{}; foreach ($c in @($r.Preserved)) { if ($null -ne $c) { $pres[[int]$c] = $true } }
        $weakAll = if ($r.Read -and $r.Read.WeakKeys) { @($r.Read.WeakKeys.Keys) } else { @() }
        $nWeak = @($weakAll | Where-Object { -not $pres.ContainsKey([int](([string]$_ -split '\.')[0])) }).Count
        $nKept = $weakAll.Count - $nWeak
        $nPres = $pres.Count
        if ($nWeak -gt 0 -or $nPres -gt 0) { $verdict += (T ' (avec réserve : protection non reproductible)') }
        $detail = if ($r.Mode -eq 'sector' -and -not $chk) { (T 'La copie a été écrite tête par tête et elle est identique à l''original, secteur par secteur. Le contrôle des pistes ne s''applique pas à ce format (haute densité).') }
                  elseif ($r.Mode -eq 'sector') { (T 'La copie a été écrite tête par tête, toutes ses pistes sont saines et elle est identique à l''original, secteur par secteur.') }
                  else { (T 'Le flux a été recopié et toutes les pistes de la copie sont saines. Sans format, la copie n''est pas comparée secteur par secteur : essayez-la sur la machine d''origine.') }
        if ($nWeak -gt 0) { $detail += ((T " Attention : {0} piste(s) de l'original non reproductible(s) (zone instable, protection contre la copie probable) : la copie n'en a reçu qu'un tour figé et risque de ne pas fonctionner.") -f "$nWeak") }
        if ($nKept -gt 0) { $detail += ((T " {0} piste(s) non reproductible(s) de l'original préservée(s), non réécrite(s) : protection d'origine intacte.") -f "$nKept") }
        if ($nPres -gt 0) { $detail += ((T " Cylindres {0} ni réécrits ni contrôlés (disquette reconnue comme l'original) : s'il s'agissait d'une copie, elle est incomplète ; effacez-la puis relancez la restauration.") -f "$(Format-CylList @($pres.Keys | Sort-Object))") }
    } else {
        $verdict = (T 'RESTAURATION ÉCHOUÉE') + ' : ' + ($reasons -join ' ; ')
        $detail = (T 'Essayez une autre disquette de destination ; si le problème persiste, nettoyez les têtes du lecteur. Le détail est dans le rapport.')
    }
    Append-Log $verdict
    Write-RestoreReport $ok $verdict
    Show-RestoreResult $ok ($verdict + "`n`n" + $detail) $(if ($ok -and ($nWeak -gt 0 -or $nPres -gt 0)) { 'h1' } else { '' })
    Close-Restore
}

function Fail-Restore([int]$step, [string]$why) {
    $r = $script:Restore
    if (-not $r) { return }
    $r.Stage = 'failed'
    $script:Chain.Clear(); $script:WriteQueue.Clear(); $script:GwCapture = $null; $script:AfterCalib = ''
    if ($script:FmtDetect -and $script:FmtDetect.Owner -eq 'restore') { $script:FmtDetect = $null }   # FIX2 : detection interrompue (erreur gw)
    Stop-WriteWarmup
    if ($step -ge 0) { Set-RsStep $step 'fail' $why }
    $verdict = (T 'RESTAURATION ÉCHOUÉE') + ' : ' + $why
    Append-Log $verdict
    Write-RestoreReport $false $verdict
    $note = if ($step -le 1) { (T 'Rien n''a été écrit : la disquette de destination n''a pas été touchée.') } else { (T 'Le détail est dans le journal et dans le rapport.') }
    Show-RestoreResult $false ($verdict + "`n`n" + $note)
    Close-Restore
}

function Stop-Restore([string]$why) {
    # Abandon (bouton Arreter ou Annuler, erreur gw, operation incomplete, sequence bloquee) ; sans effet hors restauration
    $r = $script:Restore
    if (-not $r) { return }
    Fail-Restore ([int]$r.Cur) $why
}

function Close-Restore {
    $r = $script:Restore
    $script:Restore = $null
    # Reglages de l onglet Ecriture retablis, puis enregistres : fin de la surcharge d operation (12.8, D4)
    if ($r) {
        if ($script:OpOverride) { Exit-OpOverride }
        else { Restore-WriteTabState $r.Saved; [void](Save-Config) }
    }
    Set-RsLock $false
    $pnlRsWait.Visible = $false
    Update-RsCalib
}
