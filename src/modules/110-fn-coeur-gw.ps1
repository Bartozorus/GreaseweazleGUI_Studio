# ============================== FONCTIONS : COEUR, GW ET DETECTION DES LECTEURS ===

# ============================== COMPARAISON : LOGIQUE ==========================
function Invoke-NextChainStep {
    if ($script:Chain.Count -eq 0) { return }
    $step = $script:Chain.Dequeue()
    try {
        & $step
    } catch {
        $script:Chain.Clear(); $script:WriteQueue.Clear()
        Stop-WriteWarmup
        if ($script:Rep) { Stop-WriteCheck }
        Append-Log ((T "ERREUR étape : {0}") -f "$($_.Exception.Message)")
        # Etape de calibration en echec : calibration abandonnee, avec l ecriture qu elle devait preceder
        if ($script:Cal) { Stop-PrecompCalib }
        $script:AfterCalib = ''
        if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f "$($_.Exception.Message)") }
        if ($script:Restore) { Stop-Restore ((T "erreur interne : {0}") -f "$($_.Exception.Message)") }
        # 12.8 (lot 3a) : mesure de qualite en cours sans analyse : resultat affiche perime
        if ($script:QualView.State -eq 'run' -and $script:QualView.Kind -eq 'measure') { $script:AlignLoop = $false; Set-QualityStale 'error' }
    }
}

# --- Coeur ---------------------------------------------------------------------
function Get-CommonArgs {
    $a = @("--drive=$($cmbDrive.Text)")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    return $a
}

function Set-Busy([bool]$busy) {
    $tabs.Enabled = -not $busy
    $btnStop.Enabled = $busy
    $btnCfgSave.Enabled = -not $busy -and -not $script:Restore
    $btnCfgReset.Enabled = -not $busy -and -not $script:Restore
}

function Get-AppBusy([switch]$Text) {
    # 12.8 (D20) : test unique « operation en cours » de toutes les entrees qui lancent gw ou changent un reglage en cours
    # d usage. Renvoie '' au repos, sinon la raison du refus : un code (restore, calib, check, warmup, detect, gw, chain,
    # quality), ou avec -Text son libelle dans la langue de l interface (« commande gw », « calibration »...). Ordre : la
    # raison la plus precise d abord ; quality (mesure continue de l onglet Qualite) seulement quand rien d autre ne tourne.
    $k = ''
    if ($script:Restore) { $k = 'restore' }
    elseif ($script:Cal) { $k = 'calib' }
    elseif ($script:Rep) { $k = 'check' }
    elseif ($script:WriteWarm) { $k = 'warmup' }
    elseif ($script:Detect) { $k = 'detect' }
    elseif ($script:GwProc -and -not $script:GwProc.HasExited) { $k = 'gw' }
    elseif ($script:Chain.Count -gt 0) { $k = 'chain' }
    elseif ($script:AlignLoop) { $k = 'quality' }
    if (-not $Text -or -not $k) { return $k }
    switch ($k) {
        'restore' { return (T 'restauration') }
        'calib'   { return (T 'calibration') }
        'check'   { return (T 'contrôle après écriture') }
        'warmup'  { return (T 'préchauffage du lecteur') }
        'detect'  { return (T 'détection des lecteurs') }
        'gw'      { return (T 'commande gw') }
        'chain'   { return (T 'séquence d''étapes') }
        default   { return (T 'mesure continue de la qualité') }
    }
}

function Get-LogColor([string]$line) {
    if ($line -match '^>>>') { return $script:LogColors.cmd }
    # 12.8 (lot 1c, point 1) : mesures par cylindre d une passe de calibration (« erreur-type », « standard error ») :
    # donnees, jamais une erreur (le journal masque ne s ouvre pas pour elles)
    if ($line -match '^\[[^\]]+\] (Mesures de la passe .+ \(valeur écrite -> |Pass .+ measurements \(written value -> )') { return $script:LogColors.dim }
    # Lignes de synthese du controle apres ecriture : simples comptes par etat (« 0 critique(s) » n est pas une erreur)
    if ($line -match '^(Contrôle complet|Full check|Remesure après réécriture|Re-measure after rewrite)\b') { return $script:LogColors.std }
    # 12.8 (lot 3a) : lignes de qualite, une couleur par niveau. « erreurs » / « errors » du texte de SUPPORT SAIN et
    # « critique(s) non comptee(s) » d un controle sans piste faible ne les font plus passer en rouge (motifs generaux
    # ci-dessous) : etat du support SAIN / A SURVEILLER / CRITIQUE ; score moyen EXCELLENT ou BON / MOYEN / MAUVAIS ;
    # bilan du controle apres ecriture sans piste faible
    if ($line -match '^(Mesure : SUPPORT SAIN|Measurement: MEDIA HEALTHY)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((EXCELLENT|BON|GOOD)\)|^(CONTRÔLE APRÈS ÉCRITURE : \d+/\d+ pistes saines|POST-WRITE CHECK: \d+/\d+ healthy tracks)') { return $script:LogColors.ok }
    if ($line -match '^(Mesure : SUPPORT À SURVEILLER|Measurement: MEDIA TO WATCH)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((MOYEN|AVERAGE)\)') { return $script:LogColors.warn }
    if ($line -match '^(Mesure : SUPPORT CRITIQUE|Measurement: MEDIA CRITICAL)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((MAUVAIS|POOR)\)') { return $script:LogColors.err }
    if ($line -match 'FATAL|ERREUR|ERROR|ECHEC|ÉCHEC|FAILED|Command Failed|Write ?Protect|CRITIQUE|CRITICAL|ILLISIBLE|UNREADABLE|introuvable|not found|code retour : [1-9]|exit code: [1-9]|support fatigué|worn media|réécriture automatique non lancée|automatic rewrite not started|RESTAURATION ÉCHOUÉE|RESTORE FAILED') { return $script:LogColors.err }
    if ($line -match 'Verify Failure|Retry #|nécessité de nouveaux essais|needed retries|À SURVEILLER|TO WATCH|marginal|DIFF[EÉ]RENT|Interrompu|Interrupted|aborted|non applicable|not applicable|réécriture automatique désactivée|automatic rewrite disabled|Aucune réécriture automatique|No automatic rewrite|non convergée|not converged|NON CONVERGÉE|NOT CONVERGED|Valeurs peu fiables|Unreliable values|Écart à la courbe|Deviation from the curve|Giving up|zone instable|unstable zone|non jugée|not judged|probablement fatigué|probably worn') { return $script:LogColors.warn }
    if ($line -match 'All tracks verified|code retour : 0|exit code: 0|SAIN|HEALTHY|IDENTIQUE|IDENTICAL|EXCELLENT|aucune piste n|no track needed|RESTAURATION RÉUSSIE|RESTORE SUCCEEDED') { return $script:LogColors.ok }
    if ($line -match '^T\d+\.\d+\b[^:]*:') { return $script:LogColors.dim }
    return $script:LogColors.std
}

function Append-Log([string]$text) {
    foreach ($line in ($text -split "`r?`n")) {
        $c = Get-LogColor $line
        $txtLog.SelectionStart = $txtLog.TextLength; $txtLog.SelectionLength = 0
        $txtLog.SelectionColor = $c
        $txtLog.AppendText($line + "`n")
        if ($c -eq $script:LogColors.err -and $split.Panel2Collapsed) { Set-LogVisible $true }
    }
    if ($txtLog.TextLength -gt 400000) {
        $txtLog.ReadOnly = $false; $txtLog.Select(0, 150000); $txtLog.SelectedText = ''; $txtLog.ReadOnly = $true
    }
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
}

function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') {
    # 12.7 : boite de message du code nouveau ou modifie depuis la 12.7 : message ecrit dans le journal, puis affiche. Point
    # unique que les fins de test redefinissent (message enregistre sans affichage : aucune boite modale sur le bureau
    # pendant un banc). Renvoie le DialogResult de la boite.
    Append-Log $text
    return [System.Windows.Forms.MessageBox]::Show($text, $title, $buttons, $icon)
}

function Get-SpecCount([string]$spec) {
    $n = 0
    foreach ($part in ($spec -split ',')) {
        if ($part -match '^(\d+)-(\d+)$') { $n += [int]$Matches[2] - [int]$Matches[1] + 1 }
        elseif ($part -match '^\d+$') { $n++ }
    }
    return $n
}

function Start-Progress([string]$verb) {
    $script:ProgOp = $verb; $script:ProgTotal = 0
    $script:ProgSeen = New-Object 'System.Collections.Generic.HashSet[string]'
    $stOp.Text = ((T "{0} en cours...") -f "$verb"); $stTrack.Text = ''; $stOp.Image = $script:StIcons.run
    $stBar.Style = 'Marquee'; $stBar.Visible = $true
}

function Update-Progress([string]$line) {
    # Nettoyage des tetes (Start-HeadClean) : « Pass N: ... » a la fin de chaque passe (passes faites) ; une ligne de passe
    # interrompue par « Command Failed » et les autres lignes sont gardees pour le bilan (Complete-HeadClean)
    if ($script:CleanRun) {
        if ($line -match '^Pass (\d+):') {
            $pn = [int]$Matches[1]
            if ($line -notmatch 'Command Failed|FATAL') { $script:CleanRun.Done = [math]::Max([int]$script:CleanRun.Done, $pn + 1); return }
        }
        $script:CleanRun.Lines.Add($line)
        return
    }
    if ($line -match '^(Reading|Writing|Erasing)\s+c=([\d,\-]+):h=([\d,\-]+)') {
        $script:ProgTotal = (Get-SpecCount $Matches[2]) * (Get-SpecCount $Matches[3])
        if ($script:ProgTotal -gt 0) { $stBar.Style = 'Continuous'; $stBar.Minimum = 0; $stBar.Maximum = $script:ProgTotal; $stBar.Value = 0 }
        return
    }
    if ($line -match '^T(\d+)\.(\d+)\b[^:]*:') {
        $key = "$($Matches[1]).$($Matches[2])"
        [void]$script:ProgSeen.Add($key)
        if ($script:ProgTotal -gt 0) {
            $v = [math]::Min($script:ProgSeen.Count, $script:ProgTotal)
            $stBar.Value = $v
            $pct = [math]::Round(100 * $v / $script:ProgTotal, 0)
            $stTrack.Text = ((T "piste {0}  ({1}/{2}, {3} %)") -f "$key", "$v", "$($script:ProgTotal)", "$pct")
        } else { $stTrack.Text = ((T "piste {0}") -f "$key") }
        if ($line -match 'Retry #(\d+)(?:\.(\d+))?') { $stTrack.Text += ((T "  -  essai {0}") -f "$(if ($Matches[2]) { $Matches[2] } else { $Matches[1] })") }
    }
}

function Stop-Progress([int]$code) {
    $stBar.Style = 'Continuous'
    if ($code -eq 0) {
        if ($script:ProgTotal -gt 0) { $stBar.Value = $stBar.Maximum }
        $stOp.Text = ((T "{0} terminé(e)  -  {1}") -f "$($script:ProgOp)", "$(Get-Date -Format 'HH:mm:ss')"); $stOp.Image = $script:StIcons.ok
    } else {
        $stOp.Text = ((T "{0} en échec (code {1})  -  {2}") -f "$($script:ProgOp)", "$code", "$(Get-Date -Format 'HH:mm:ss')"); $stOp.Image = $script:StIcons.err
    }
    $stBar.Visible = ($code -eq 0 -and $script:ProgTotal -gt 0)
}

function Reset-GwSequence {
    # gw n a pas pu etre lance : la sequence en cours (ecriture controlee, calibration, comparaison)
    # est abandonnee, sinon le prochain gw termine avec le code 0 reprendrait ses etapes, ecritures comprises.
    $script:Chain.Clear(); $script:WriteQueue.Clear(); $script:Detect = $null
    Stop-WriteWarmup
    if ($script:Rep) { Stop-WriteCheck }
    if ($script:Cal) { Stop-PrecompCalib -GwError }       # 12.8 (VAL01) : passe du nouvel essai : jugement garde
    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : {0}") -f (T 'gw n''a pas pu être lancé.')) }
    if ($script:Restore) { Stop-Restore (T 'gw n''a pas pu être lancé') }
    # 12.8 (lot 3a) : mesure de qualite sans lecture : erreur gw, resultat affiche perime
    if ($script:QualView.State -eq 'run' -and $script:QualView.Kind -eq 'measure') { $script:AlignLoop = $false; $script:AlignNextAt = $null; Set-QualityStale 'gwerror' }
}

function Start-DriveDetect([string]$mode) {
    if (-not (Test-Path -LiteralPath $script:GwExe)) { return }
    if (Get-AppBusy) { return }                           # 12.8 (D20) : aussi pendant un prechauffage ou la mesure continue
    $script:DetectAt = $null
    $cur = [string]$cmbDrive.Text
    $order = @(@($cur) + @($script:DriveIds | Where-Object { $_ -ne $cur }) | Where-Object { $_ })
    if ($mode -eq 'auto' -and $script:DetectNone) {
        $order = @($cur)
        Append-Log ((T "Détection des lecteurs : aucun lecteur au dernier démarrage, seul le lecteur {0} est testé (carte « Tester le Greaseweazle » de l'Accueil : tous les lecteurs).") -f "$cur")
    }
    $script:Detect = @{ Mode = $mode; Queue = (New-Object System.Collections.Queue); Found = @(); Tried = @(); Cur = $cur; Drive = '' }
    foreach ($d in $order) { $script:Detect.Queue.Enqueue($d) }
    Append-Log ((T "Détection des lecteurs : recherche de la piste 0 sur {0} (gw seek : la tête se déplace, sans rotation ni écriture).") -f "$($order -join ', ')")
    Invoke-DriveProbe
}

function Invoke-DriveProbe {
    $dt = $script:Detect
    if (-not $dt) { return }
    if ($dt.Queue.Count -eq 0) { Complete-DriveDetect; return }
    $d = [string]$dt.Queue.Dequeue(); $dt.Drive = $d; $dt.Tried += $d
    $script:GwCapture = New-Object System.Collections.Generic.List[string]
    $a = @('seek', "--drive=$d")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    $a += '0'
    Start-Gw $a
}

function Complete-DriveProbe([int]$code) {
    # Fin d un gw seek de la detection (appele par le timer, quel que soit le code retour)
    $dt = $script:Detect
    if (-not $dt) { return }
    $lines = @(); if ($script:GwCapture) { $lines = @($script:GwCapture) }
    $script:GwCapture = $null
    $txt = $lines -join "`n"
    if ($code -eq 0 -and $txt -notmatch 'Command Failed|FATAL|Track ?0') {
        $dt.Found += $dt.Drive
        if ($dt.Mode -eq 'auto') { Complete-DriveDetect; return }
    } elseif ($txt -match 'Invalid unit number') {
        # Firmware ACK_BAD_UNIT : ligne de selection non cablee sur cette carte (V4 Slim, F7 Slim, F1 de base, F7 v1)
        Append-Log ((T "Lecteur {0} : non pris en charge par cette carte (ligne de sélection absente).") -f "$($dt.Drive)")
    } elseif ($txt -notmatch 'Track 0 not found|Track0 signal') {
        # Erreur sans rapport avec le lecteur (carte absente, port occupe...) : detection abandonnee, cause en clair
        $why = (@($lines | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' / ') -replace 'FATAL ERROR:?|Command Failed:?', '' -replace '\*', ''
        Append-Log ((T "Détection des lecteurs interrompue : {0}") -f "$($why.Trim())")
        if ($dt.Found.Count -gt 0) { Complete-DriveDetect } else { $script:Detect = $null }
        return
    }
    Invoke-DriveProbe
}

function Complete-DriveDetect {
    $dt = $script:Detect; $script:Detect = $null
    if (-not $dt) { return }
    $script:DetectNone = ($dt.Found.Count -eq 0)
    # A et 2 (broche 14), B et 1 (broche 12) partagent une ligne de selection : gw seek, sans moteur, ne les distingue
    # pas. Une seule entree par paire : A ou B, sauf si 2 ou 1 etait deja le reglage ; l identifiant prefere qui a ete
    # sonde sans repondre cede la place a celui de la paire qui a repondu
    $found = @($dt.Found)
    foreach ($pp in @(@('A', '2'), @('B', '1'))) {
        if (-not (($found -contains $pp[0]) -or ($found -contains $pp[1]))) { continue }
        $keepId = if ($dt.Cur -eq $pp[1]) { $pp[1] } else { $pp[0] }
        $other = if ($keepId -eq $pp[0]) { $pp[1] } else { $pp[0] }
        if ($found -notcontains $keepId -and @($dt.Tried) -contains $keepId) { $sw = $keepId; $keepId = $other; $other = $sw }
        $found = @($found | Where-Object { $_ -ne $other })
        if ($found -notcontains $keepId) { $found += $keepId }
        if ($dt.Mode -ne 'auto') { Append-Log ((T "{0} et {1} utilisent la même ligne de sélection : la détection ne peut pas les distinguer (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite).") -f $pp[0], $pp[1]) }
    }
    $dt.Found = $found
    if ($dt.Found.Count -eq 0) {
        Append-Log (T "Aucun lecteur détecté : vérifiez l'alimentation du lecteur, la nappe et son sens, puis le type de nappe (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite).")
        return
    }
    $pick = if ($dt.Found -contains $dt.Cur) { $dt.Cur } else { [string]$dt.Found[0] }
    if ($dt.Mode -ne 'auto') { Append-Log ((T "Lecteur(s) détecté(s) : {0}.") -f "$($dt.Found -join ', ')") }
    if ($pick -ne $dt.Cur) {
        # 12.8 (D10) : la restauration suit le lecteur du bandeau, sans reglage propre a recaler
        Set-Combo $cmbDrive $pick
        Append-Log ((T "Lecteur {0} sélectionné : le lecteur {1} ne répond pas.") -f "$pick", "$($dt.Cur)")
    } else { Append-Log ((T "Lecteur {0} détecté.") -f "$pick") }
}

function Get-GwDriveKey([string[]]$gwArgs) {
    # Lecteur d une commande gw qui fait tourner le moteur (read, write, erase, clean, rpm) : 'peripherique|lecteur' ;
    # $null pour les autres commandes (seek, info...) ou sans --drive
    $line = ' ' + (($gwArgs | Where-Object { $null -ne $_ }) -join ' ')
    $verb = @($line.Trim() -split '\s+')[0]
    if (@('read', 'write', 'erase', 'clean', 'rpm') -notcontains $verb) { return $null }
    if ($line -notmatch '\s--drive=(\S+)') { return $null }
    $drv = $Matches[1]
    $dev = if ($line -match '\s--device=(\S+)') { $Matches[1] } else { '' }
    return "$dev|$drv"
}

function Start-Gw([string[]]$gwArgs, [switch]$Soft) {
    # Soft : lecture de prechauffage d une ecriture lente (Invoke-WriteWarmup), marquee par appel
    $exe = $script:GwExe
    if (-not (Test-Path -LiteralPath $exe)) {
        Reset-GwSequence
        [void][System.Windows.Forms.MessageBox]::Show(((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$exe"),(T 'Erreur'),'OK','Error'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        Append-Log ((T "gw déjà en cours : commande ignorée ({0}).") -f "$($gwArgs -join ' ')")
        if ($script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:WriteWarm) { Reset-GwSequence }
        return
    }

    if (-not $script:Restore -and -not $script:Detect) { [void](Save-Config) }      # restauration : reglages temporaires ; detection : pas d ecriture a chaque sonde

    $script:GwIsWrite = ($gwArgs.Count -gt 0 -and $gwArgs[0] -eq 'write')
    $verbs = @{ write=(T 'Écriture'); read=(T 'Lecture'); erase=(T 'Effacement'); convert='Conversion'; clean=(T 'Nettoyage'); rpm=(T 'Mesure de vitesse'); update=(T 'Mise à jour firmware') }
    $first = if ($gwArgs.Count -gt 0) { ($gwArgs[0] -split ' ')[0] } else { '' }
    # Lecture de prechauffage (calibration : etape 'warmup' ; ecriture lente : -Soft) : son code retour n arrete pas la
    # sequence ; lecteur de la commande pour DriveActivity (serie d activite mise a jour par le minuteur a la fin de la
    # commande, seulement si le moteur a tourne). Nom distinct du parametre Soft (PowerShell ignore la casse).
    $warmRead = [bool]([bool]$Soft -or ($script:Cal -and $script:Cal.Stage -eq 'warmup' -and $first -eq 'read'))
    Start-Progress $(if ($warmRead) { (T 'Préchauffage') } elseif ($verbs.ContainsKey($first)) { $verbs[$first] } else { "gw $first" })
    if ($script:GwIsWrite) { $script:WriteRetries = @{}; $script:WriteTracks = @{} }
    $script:GwWriteSummary = $false
    $driveKey = if ($script:Detect) { $null } else { Get-GwDriveKey $gwArgs }
    if ($chkTime.Checked) { $gwArgs = @('--time') + $gwArgs }
    $argLine = $gwArgs -join ' '
    if (-not $script:Detect) { Append-Log ">>> gw $argLine" }
    $script:GwStart = Get-Date; $script:GwLines = 0

    # gw.exe est appele directement (aucun cmd.exe intermediaire) ; sa sortie est redirigee
    # dans le processus et lue par des gestionnaires d'evenements qui remplissent une file
    # thread-safe, videe par le timer de l'interface. Pas de fichier temporaire.
    $script:OutPending = ''
    $script:OutQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $exe
    $psi.Arguments = $argLine
    $psi.WorkingDirectory       = $script:AppDir
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    $psi.EnvironmentVariables['PYTHONUNBUFFERED'] = '1'
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    try {
        [void]$p.Start()
        $script:GwProc = $p
        $script:GwSoft = $warmRead; $script:GwDriveKey = $driveKey
        # Lecture asynchrone des deux flux : chaque ReadLineAsync rend une Task que le timer
        # inspecte sans bloquer l'interface. Pas de bloc -Action (inactif sous ShowDialog).
        $script:OutStdoutReader = $p.StandardOutput
        $script:OutStderrReader = $p.StandardError
        $script:OutStdoutTask = $script:OutStdoutReader.ReadLineAsync()
        $script:OutStderrTask = $script:OutStderrReader.ReadLineAsync()
        Set-Busy $true
        # 12.8 (lot 3a) : disquette ecrite ou effacee hors d un controle apres ecriture (calibration, ecriture sans controle,
        # effacement) : le resultat de l onglet Qualite ne la decrit plus
        # 12.8 (FIX3) : verdict du controle precedent (onglet Ecriture) masque
        if (($first -eq 'write' -or $first -eq 'erase') -and -not $script:Rep) { Set-QualityStale 'written'; Hide-WCalVerdict }
    } catch {
        Append-Log ((T "ERREUR lancement : {0}") -f "$($_.Exception.Message)")
        $script:GwProc = $null; $script:GwSoft = $false; $script:GwDriveKey = $null
        Reset-GwSequence
        Set-Busy $false
    }
}

function Drain-GwReader($reader, [ref]$task) {
    # Vide les lignes disponibles d'un flux ; relance une tache tant qu'elle se complete tout de suite.
    if (-not $reader -or $null -eq $task.Value) { return }
    while ($task.Value.IsCompleted) {
        $line = $null
        try { $line = $task.Value.Result } catch { $task.Value = $null; return }
        if ($null -eq $line) { $task.Value = $null; return }   # fin de flux
        if ($line -ne '') { $script:OutQueue.Enqueue($line) }
        $task.Value = $reader.ReadLineAsync()
    }
}

function Read-GwOutput([bool]$flush) {
    if (-not $script:OutQueue) { return }
    if ($flush) {
        # Processus termine : attendre la fin de flux (EOF) de stdout puis stderr, sinon les dernieres
        # lignes (dont un eventuel message d erreur de gw) restent dans le tube et sont perdues.
        $deadline = (Get-Date).AddSeconds(5)
        foreach ($which in 'out', 'err') {
            while ((Get-Date) -lt $deadline) {
                $t = if ($which -eq 'out') { $script:OutStdoutTask } else { $script:OutStderrTask }
                if ($null -eq $t) { break }
                try { [void]$t.Wait(500) } catch { break }
                if (-not $t.IsCompleted) { continue }
                if ($which -eq 'out') { Drain-GwReader $script:OutStdoutReader ([ref]$script:OutStdoutTask) }
                else                  { Drain-GwReader $script:OutStderrReader ([ref]$script:OutStderrTask) }
            }
        }
    }
    Drain-GwReader $script:OutStdoutReader ([ref]$script:OutStdoutTask)
    Drain-GwReader $script:OutStderrReader ([ref]$script:OutStderrTask)
    $lines = @()
    while ($script:OutQueue.Count -gt 0) {
        $l = [string]$script:OutQueue.Dequeue()
        if ($l -ne '') { $lines += $l }
    }
    if ($lines.Count -eq 0) { return }
    $script:GwLines += $lines.Count
    foreach ($l in $lines) { Update-Progress $l }
    if ($null -ne $script:GwCapture) { foreach ($l in $lines) { $script:GwCapture.Add($l) } }
    if ($script:Detect) { return }                      # detection des lecteurs : sortie analysee, pas affichee
    if ($script:GwIsWrite) {
        foreach ($l in $lines) {
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*:.*Retry #(\d+)') {
                $k = "$($Matches[1]).$($Matches[2])"; $n = [int]$Matches[3]
                if (-not $script:WriteRetries.ContainsKey($k) -or $n -gt $script:WriteRetries[$k]) { $script:WriteRetries[$k] = $n }
            }
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*: Writing Track') { $script:WriteTracks["$($Matches[1]).$($Matches[2])"] = $true }
            if ($l -match '^(All tracks verified|No tracks verified|\d+ tracks verified)') { $script:GwWriteSummary = $true }
        }
    }
    if ($lines.Count -gt 0) { Append-Log ($lines -join [Environment]::NewLine) }
}
