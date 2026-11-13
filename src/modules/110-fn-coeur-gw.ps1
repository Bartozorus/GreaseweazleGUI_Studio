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
    # 12.11 : la liste du bandeau porte l identite du lecteur (le code d une connexion, ou le nom d un lecteur enregistre) ;
    # --drive recoit sa connexion (Get-DriveConn, 112 : un code y rend lui-meme, un nom n atteint jamais gw)
    $a = @("--drive=$(Get-DriveConn ([string]$cmbDrive.Text))")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    return $a
}

function Set-Busy([bool]$busy) {
    # 12.8 (lot 5, D20) : barre alignee sur Get-AppBusy. Pause d une mesure continue de l onglet Qualite (Get-AppBusy
    # 'quality', aucune commande gw) : « Arreter » actif (il arrete la mesure continue) et « Reinitialiser » inactif,
    # comme pendant la mesure ; onglets actifs, comme en 12.7. Entree dans la pause et sortie sans commande gw : le
    # minuteur principal rappelle Set-Busy quand Get-AppBusy ne correspond plus a $script:QualPauseBar
    $loop = (-not $busy) -and (Get-AppBusy) -eq 'quality'
    $script:QualPauseBar = $loop
    $tabs.Enabled = -not $busy
    $btnStop.Enabled = $busy -or $loop
    $btnCfgSave.Enabled = -not $busy -and -not $script:Restore
    $btnCfgReset.Enabled = -not $busy -and -not $script:Restore -and -not $loop
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
    # 12.8.1 : mesure de la disquette sur l image : lectures par cylindre d une passe (donnees) ; arrets de gw repris,
    # pistes ecartees (« illisibles »), facteur borne, peu determine ou non mesure : reserves, jamais une erreur
    if ($line -match '^\[[^\]]+\] (Mesure sur l''image, passe |Measurement on the image, pass )') { return $script:LogColors.dim }
    if ($line -match '^Mesure sur l''image : (gw s''est arrêté|nouvel arrêt de gw|arrêt de gw annoncé|pistes écartées)|^Measurement on the image: (gw stop|tracks left out)|^\[[^\]]+\] (Optimum à la borne|Marge peu sensible|Facteur non mesuré|Optimum at the|Margin barely|Factor not measured)') { return $script:LogColors.warn }
    # Lignes de synthese du controle apres ecriture : simples comptes par etat (« 0 critique(s) » n est pas une erreur)
    if ($line -match '^(Contrôle complet|Full check|Remesure après réécriture|Re-measure after rewrite)\b') { return $script:LogColors.std }
    # 12.8 (lot 3a) : lignes de qualite, une couleur par niveau. « erreurs » / « errors » du texte de SUPPORT SAIN et
    # « critique(s) non comptee(s) » d un controle sans piste faible ne les font plus passer en rouge (motifs generaux
    # ci-dessous) : etat du support SAIN / A SURVEILLER / CRITIQUE ; score moyen EXCELLENT ou BON / MOYEN / MAUVAIS ;
    # bilan du controle apres ecriture sans piste faible
    # 12.10 (lot 1, I-5) : verdict neutre du controle (pistes encore faibles apres reecriture) rouge par son propre motif,
    # sans « support fatigue » ; libelles neutres « non distingues » (plafond, besoin, courbe adaptee) en orange, comme
    # les libelles « probablement fatigue » qu ils remplacent
    if ($line -match '^(Mesure : SUPPORT SAIN|Measurement: MEDIA HEALTHY)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((EXCELLENT|BON|GOOD)\)|^(CONTRÔLE APRÈS ÉCRITURE : \d+/\d+ pistes saines|POST-WRITE CHECK: \d+/\d+ healthy tracks)') { return $script:LogColors.ok }
    if ($line -match '^(Mesure : SUPPORT À SURVEILLER|Measurement: MEDIA TO WATCH)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((MOYEN|AVERAGE)\)') { return $script:LogColors.warn }
    if ($line -match '^(Mesure : SUPPORT CRITIQUE|Measurement: MEDIA CRITICAL)\b|^(Mesure : score moyen|Measurement: average score) \d+ \((MAUVAIS|POOR)\)') { return $script:LogColors.err }
    if ($line -match 'FATAL|ERREUR|ERROR|ECHEC|ÉCHEC|FAILED|Command Failed|Write ?Protect|CRITIQUE|CRITICAL|ILLISIBLE|UNREADABLE|introuvable|not found|code retour : [1-9]|exit code: [1-9]|support fatigué|worn media|encore faible\(s\) après|still weak after|réécriture automatique non lancée|automatic rewrite not started|RESTAURATION ÉCHOUÉE|RESTORE FAILED') { return $script:LogColors.err }
    if ($line -match 'Verify Failure|Retry #|nécessité de nouveaux essais|needed retries|À SURVEILLER|TO WATCH|marginal|DIFF[EÉ]RENT|Interrompu|Interrupted|aborted|non applicable|not applicable|réécriture automatique désactivée|automatic rewrite disabled|Aucune réécriture automatique|No automatic rewrite|non convergée|not converged|NON CONVERGÉE|NOT CONVERGED|Valeurs peu fiables|Unreliable values|Écart à la courbe|Deviation from the curve|Giving up|zone instable|unstable zone|non jugée|not judged|probablement fatigué|probably worn|non distingués|not distinguished') { return $script:LogColors.warn }
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
    # 12.11 : journal borne par Limit-LogText : debut retire a une fin de ligne, marque de troncature en premiere ligne
    # (avant : au-dela de 400 000 caracteres, les 150 000 premiers retires sans trace, une ligne coupee en son milieu)
    Limit-LogText
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

function Start-Progress([string]$verb, [string[]]$gwArgs = $null) {
    $script:ProgOp = $verb; $script:ProgTotal = 0
    $script:ProgSeen = New-Object 'System.Collections.Generic.HashSet[string]'
    # 12.11 : etat de la commande remis a zero (progression par piste) ; une commande suit : etat de fin de sequence en
    # attente annule (calibration puis ecriture, Set-SeqEnd), commande comptee dans la sequence (Update-SeqEnd)
    $script:ProgHead = ''; $script:ProgKey = ''; $script:ProgRetry = ''; $script:ProgDone = 0
    $script:ProgDirty = $false; $script:ProgFailed = $false
    $script:SeqEnd = $null; $script:SeqCmds = 1 + [int]$script:SeqCmds
    # 12.11 : poids de la commande dans le plan de l etape en cours (New-ProgPlan), d apres ses arguments ; second parametre
    # absent (appels a un argument, lecture de prechauffage, detection des lecteurs) : commande hors de tout plan
    $script:ProgCmd = $null
    if ($script:ProgPlan -and $gwArgs -and $gwArgs.Count -gt 0) { $script:ProgCmd = Get-GwCmdUnits $gwArgs; $script:ProgPlan.Got = 1 + [int]$script:ProgPlan.Got }
    $stOp.Text = ((T "{0} en cours...") -f "$verb"); $stTrack.Text = ''; $stOp.Image = $script:StIcons.run
    $stBar.Style = 'Marquee'; $stBar.Visible = $true
}

function Update-Progress([string]$line, [switch]$Defer) {
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
    # 12.11 : etat de la commande d apres la seule lecture de la ligne (Get-GwLineInfo), sans toucher a l interface ;
    # affichage par Show-GwProgress : aussitot, ou une fois par lot de lignes avec -Defer (Read-GwOutput). ProgTotal et
    # ProgSeen gardent leur sens (regle de fin d une commande, 600) ; l annonce « Converting » donne aussi un total, que
    # la regle de fin ne compte pas (Get-EndRuleTotal)
    $i = Get-GwLineInfo $line
    if ($null -ne $i) {
        if ($i.Kind -eq 'head') {
            $script:ProgHead = [string]$i.Verb; $script:ProgTotal = [int]$i.Total
            # Commande d un plan dont les arguments ne donnaient pas les pistes (--tracks=h=0, ou pas de --tracks) : poids
            # complete par l annonce de gw, dans la commande et dans le total du plan si elle y etait prevue
            $pc = $script:ProgCmd
            if ($pc -and [int]$pc.Tracks -le 0 -and [int]$i.Total -gt 0 -and [double]$pc.Per -gt 0) {
                $add = [int]$i.Total * [double]$pc.Per
                $pc.Tracks = [int]$i.Total; $pc.Units = [double]$pc.Units + $add
                if ($script:ProgPlan -and [int]$script:ProgPlan.Got -le @($script:ProgPlan.Cmds).Count) { $script:ProgPlan.Units = [double]$script:ProgPlan.Units + $add }
            }
        } else {
            [void]$script:ProgSeen.Add([string]$i.Key)
            $script:ProgKey = [string]$i.Key; $script:ProgRetry = [string]$i.Retry
            # Pistes terminees : gw read et gw convert impriment la ligne apres la piste, gw write et gw erase avant de
            # l ecrire ou de l effacer (piste commencee, non finie) ; jamais decroissant pendant une commande
            $d = $script:ProgSeen.Count; if ([string]$i.Op -ne 'read') { $d-- }
            if ($d -gt [int]$script:ProgDone) { $script:ProgDone = $d }
        }
        $script:ProgDirty = $true
    }
    if (-not $Defer) { Show-GwProgress }
}

function Stop-Progress([int]$code) {
    $stBar.Style = 'Continuous'
    # 12.11 : fin de la commande. Echec garde pour la fin de sequence (Update-SeqEnd ne remplace pas « ... en echec ») ;
    # poids de la commande credite au plan de l etape : entier avec le code 0, sinon sa part fixe et ses pistes terminees.
    # Second appel pour la detection des lecteurs (600) : plus de poids a crediter
    $script:ProgFailed = ($code -ne 0)
    $pc = $script:ProgCmd; $script:ProgCmd = $null
    if ($pc -and $script:ProgPlan) {
        $u = [double]$pc.Fixed + (Get-GwProgress).Done * [double]$pc.Per
        if ($code -eq 0 -and $u -lt [double]$pc.Units) { $u = [double]$pc.Units }
        $script:ProgPlan.Done = [double]$script:ProgPlan.Done + $u
    }
    if ($code -eq 0) {
        # 12.11 : commande terminee, la derniere piste vue est finie : pistes terminees = pistes vues (« (82/82, 100 %) »
        # apres une ecriture ou un effacement complets ; image plus courte que l annonce : compte reel, barre pleine)
        if ($script:ProgSeen -and $script:ProgSeen.Count -gt [int]$script:ProgDone) { $script:ProgDone = $script:ProgSeen.Count; $script:ProgDirty = $true }
        Show-GwProgress
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
    $cur = Get-DriveConn ([string]$cmbDrive.Text)         # 12.11 : la detection sonde des connexions (celle du lecteur du bandeau d abord)
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
    # 12.11 : barre d etat apres la recherche des lecteurs : « Pret. », sans heure (avant : « gw seek termine(e) »)
    Set-SeqEnd (T 'Prêt.') 'idle' -NoTime
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
        [void](Show-AppMessage ((T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$exe") (T 'Erreur') 'OK' 'Error'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        Append-Log ((T "gw déjà en cours : commande ignorée ({0}).") -f "$($gwArgs -join ' ')")
        if ($script:Chain.Count -gt 0 -or $script:Rep -or $script:Cal -or $script:WriteWarm) { Reset-GwSequence }
        return
    }

    # 12.10 (lot 1, R1-corrections-revue, constat d) : premier gw write de l image d une operation de la Bibliotheque
    # (Set-LibImageWritten) : pose avant Save-Config (configuration de la fin de l operation, E9-3), retire si gw ne demarre pas
    $libWr = Set-LibImageWritten $gwArgs
    if (-not $script:Restore -and -not $script:Detect) { [void](Save-Config) }      # restauration : reglages temporaires ; detection : pas d ecriture a chaque sonde

    $script:GwIsWrite = ($gwArgs.Count -gt 0 -and $gwArgs[0] -eq 'write')
    $verbs = @{ write=(T 'Écriture'); read=(T 'Lecture'); erase=(T 'Effacement'); convert='Conversion'; clean=(T 'Nettoyage'); rpm=(T 'Mesure de vitesse'); update=(T 'Mise à jour firmware') }
    $first = if ($gwArgs.Count -gt 0) { ($gwArgs[0] -split ' ')[0] } else { '' }
    # Lecture de prechauffage (calibration : etape 'warmup' ; ecriture lente : -Soft) : son code retour n arrete pas la
    # sequence ; lecteur de la commande pour DriveActivity (serie d activite mise a jour par le minuteur a la fin de la
    # commande, seulement si le moteur a tourne). Nom distinct du parametre Soft (PowerShell ignore la casse).
    $warmRead = [bool]([bool]$Soft -or ($script:Cal -and $script:Cal.Stage -eq 'warmup' -and $first -eq 'read'))
    # 12.11 : arguments transmis a la progression (poids de la commande dans le plan de l etape, New-ProgPlan), sauf pour
    # une lecture de prechauffage et pour la detection des lecteurs, qui n entrent dans aucun plan
    Start-Progress $(if ($warmRead) { (T 'Préchauffage') } elseif ($verbs.ContainsKey($first)) { $verbs[$first] } else { "gw $first" }) $(if ($warmRead -or $script:Detect) { $null } else { $gwArgs })
    # 12.8.1 (spec-1281.md § A.7) : arret « Failed to verify Track C.H » de la commande, pose par Read-GwOutput (ecriture)
    $script:GwVerifyFail = $null
    if ($script:GwIsWrite) { $script:WriteRetries = @{}; $script:WriteTracks = @{} }
    $script:GwWriteSummary = $false
    # Revue 12.8.2 : gw erase 1.23 intercepte l erreur du Greaseweazle, imprime « Command Failed: ... » et rend le code 0
    # (tools/erase.py) : drapeau pose par Read-GwOutput, lu par la regle de fin (Get-GwEndRule : commande incomplete)
    $script:GwIsErase = ($first -eq 'erase'); $script:GwCmdFailed = $false
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

    # 12.11 : lancement en trois temps. Jusqu a la 12.10, un seul try couvrait Process.Start et la suite du demarrage :
    # une exception apres le demarrage (flux, Set-Busy, onglet Qualite) passait pour un echec du lancement, et gw
    # tournait sans suivi (sortie non lue, fin non traitee, « Arreter » sans effet, autre commande possible).
    # Temps 1 : Process.Start seul ; son echec est le seul cas « gw n a pas pu etre lance »
    try {
        [void]$p.Start()
    } catch {
        Append-Log ((T "ERREUR lancement : {0}") -f "$($_.Exception.Message)")
        if ($libWr -and $script:OpOverride) { $script:OpOverride.Written = $false }
        $script:GwProc = $null; $script:GwSoft = $false; $script:GwDriveKey = $null
        Reset-GwSequence
        Set-GwLaunchFailedStatus
        Set-Busy $false
        return
    }
    # 12.11 (temps 2) : gw tourne ; suivi du processus pose aussitot, hors de tout try : Start-Gw ne le defait plus
    $script:GwProc = $p
    $script:GwSoft = $warmRead; $script:GwDriveKey = $driveKey
    # 12.11 (temps 3) : suite du demarrage. Une exception ici n est pas un echec du lancement : une ligne au journal,
    # sans toucher au suivi, a la sequence en cours ni a la barre d etat (« ... en cours... »). Le minuteur suit la
    # commande jusqu a sa fin et applique sa regle de fin, « Arreter » l interrompt, Get-AppBusy refuse toute autre
    # operation. Si les flux ont echoue, la sortie de gw n est pas lue (Drain-GwReader accepte une tache nulle)
    try {
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
        Append-Log ((T "gw est lancé, mais une erreur a suivi son démarrage : {0}. La commande reste suivie jusqu'à sa fin ; « Arrêter » l'interrompt.") -f "$($_.Exception.Message)")
        try { Set-Busy $true } catch { }
        try { $btnStop.Enabled = $true } catch { }   # 12.11 : « Arreter » actif meme si Set-Busy a leve avant de l activer (sa deuxieme instruction)
    }
}

function Set-GwLaunchFailedStatus {
    # 12.10 (relecture de la RC10) : gw.exe n a pas pu etre lance (Process.Start en echec, apres Start-Progress) : barre
    # d etat de l echec, comme Stop-Progress pour un code non nul, au lieu de « … en cours... » avec l icone run et la barre
    # animee. Appelee apres Reset-GwSequence (fin de la sequence, dont Close-Restore) : la cause est au journal
    $stOp.Text = ((T "{0} : gw n'a pas pu être lancé, voir le journal  -  {1}") -f "$($script:ProgOp)", "$(Get-Date -Format 'HH:mm:ss')"); $stOp.Image = $script:StIcons.err
    $stTrack.Text = ''; $stBar.Style = 'Continuous'; $stBar.Visible = $false
    # 12.11 : etat d echec : l etat de fin de sequence pose par Reset-GwSequence (restauration, calibration, controle) est
    # annule, et Update-SeqEnd ne remplace pas cet affichage, qui dit la cause
    $script:SeqEnd = $null; $script:ProgFailed = $true; $script:ProgCmd = $null
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
    # 12.11 : etat de la progression mis a jour ligne par ligne, barre d etat peinte une seule fois pour le lot
    foreach ($l in $lines) { Update-Progress $l -Defer }
    Show-GwProgress
    if ($null -ne $script:GwCapture) { foreach ($l in $lines) { $script:GwCapture.Add($l) } }
    if ($script:Detect) { return }                      # detection des lecteurs : sortie analysee, pas affichee
    if ($script:GwIsWrite) {
        foreach ($l in $lines) {
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*:.*Retry #(\d+)') {
                $k = "$($Matches[1]).$($Matches[2])"; $n = [int]$Matches[3]
                if (-not $script:WriteRetries.ContainsKey($k) -or $n -gt $script:WriteRetries[$k]) { $script:WriteRetries[$k] = $n }
            }
            if ($l -match '^T(\d+)\.(\d+)\b[^:]*: Writing Track') {
                $script:WriteTracks["$($Matches[1]).$($Matches[2])"] = $true
                if ($script:EraseLog) { $script:EraseLog.Written["$($Matches[1]).$($Matches[2])"] = $true }   # 12.8.2 (Start-ImageWrite, 170)
            }
            if ($l -match '^(All tracks verified|No tracks verified|\d+ tracks verified)') { $script:GwWriteSummary = $true }
        }
        # 12.8.1 (A.7) : gw 1.23 arrete la commande sur une piste refusee a la verification apres les nouveaux essais
        # (« ** FATAL ERROR: » puis « Failed to verify Track C.H », sur stderr) : premiere occurrence gardee, lue par la
        # mesure sur l image (Invoke-ContentWriteNext) et par la regle douce du minuteur principal (600)
        $vs = Get-GwVerifyStop $lines
        if ($vs -and -not $script:GwVerifyFail) { $script:GwVerifyFail = $vs }
    }
    if ($script:GwIsErase) {
        # Revue 12.8.2 : gw erase imprime « Tc.h: Erasing Track » avant d effacer chaque piste (pistes logiques, comme
        # « Writing Track ») : pistes touchees par l effacement de l operation en cours (EraseLog) ; « Command Failed » :
        # echec avec le code 0
        foreach ($l in $lines) {
            if ($l -match '^Command Failed') { $script:GwCmdFailed = $true }
            elseif ($script:EraseLog -and $l -match '^T(\d+)\.(\d+)\b[^:]*: Erasing Track') { $script:EraseLog.Erased["$($Matches[1]).$($Matches[2])"] = $true }
        }
    }
    if ($lines.Count -gt 0) { Append-Log ($lines -join [Environment]::NewLine) }
}

function Get-GwEndRule([int]$code, [bool]$soft, [bool]$isWrite, [bool]$summary, [int]$progTotal, [int]$progSeen, $verifyFail, [string]$calMode, [bool]$cmdFailed = $false) {
    # Regle de fin d une commande gw (minuteur principal, 600), sans etat : arguments releves par le minuteur apres le
    # dernier Read-GwOutput. Soft : lecture de prechauffage ($soft), ou 12.8.1 (spec-1281.md § A.7) ecriture de la mesure
    # sur l image ($calMode 'content') arretee sur une piste refusee a la verification ($verifyFail, Read-GwOutput), quel
    # que soit le code retour (1 en gw 1.23 ; 0 admis : revue 12.8.1, point 1). Incomplete : arret silencieux avec le code 0
    # (ecriture sans ligne de bilan ; autre commande : moins de la moitie des pistes annoncees), sans effet si Soft.
    # Next : etape suivante de la chaine (code 0 ou Soft). Revue 12.8.2 : $cmdFailed, gw erase arrete par « Command
    # Failed » avec le code 0 (Read-GwOutput) : incomplete quel que soit le nombre de pistes vues (effacement d une ou deux
    # pistes, ou echec sur la derniere) ; l ecriture qui suit n est pas lancee
    if (-not $soft -and $isWrite -and $verifyFail -and $calMode -eq 'content') { $soft = $true }
    $inc = if ($isWrite) { $code -eq 0 -and -not $summary } else { $code -eq 0 -and (($progTotal -gt 0 -and $progSeen * 2 -lt $progTotal) -or $cmdFailed) }
    return @{ Soft = $soft; Incomplete = [bool]$inc; Next = ($code -eq 0 -or $soft) }
}

# --- Journal : borne et export (12.11) -----------------------------------------

function Limit-LogText {
    # 12.11 : journal borne a $script:LogMaxChars caracteres (400 000, 540), appelee par Append-Log apres chaque ajout.
    # Au-dela, le debut est retire pour n en garder que $script:LogKeepChars (250 000 : les 150 000 premiers caracteres au
    # premier depassement, comme avant), mais la coupe est ramenee au debut d une ligne (derniere fin de ligne de la partie
    # retiree ; sans fin de ligne dans cette partie : coupe au caractere) et une marque, premiere ligne du journal, dit
    # combien de caracteres ont ete retires. Depassements suivants : la marque en place est retiree avec le debut sans etre
    # comptee, et son compte est cumule ($script:LogCut : N caracteres retires, Mark marque en place) ; si elle n est plus
    # en tete (journal vide par « Vider »), le compte repart de zero. Seule fonction qui ecrit la marque
    $max = [int]$script:LogMaxChars
    if ($txtLog.TextLength -le $max) { return }
    $t = [string]$txtLog.Text
    $st = $script:LogCut
    $old = 0
    if ($st.Mark -and $t.StartsWith([string]$st.Mark + "`n", [System.StringComparison]::Ordinal)) { $old = ([string]$st.Mark).Length + 1 } else { $st.N = 0 }
    $cut = [math]::Max($old, $t.Length - [int]$script:LogKeepChars)
    # Debut de ligne : derniere fin de ligne de la partie retiree, marque precedente exclue ; ecartee si le journal garde
    # depassait alors la borne, marque comprise (ligne de plus de 150 000 caracteres) : coupe au caractere
    $p = $t.LastIndexOf([char]10, $cut - 1)
    if ($p + 1 -gt $old -and ($t.Length - $p - 1) -le ($max - 1000)) { $cut = $p + 1 }
    $st.N = [int]$st.N + ($cut - $old)
    $st.Mark = (T "[Journal tronqué : les {0} premiers caractères ont été retirés (400 000 au plus sont gardés). Exportez le journal après chaque opération longue.]") -f "$($st.N)"
    $txtLog.ReadOnly = $false
    $txtLog.Select(0, $cut); $txtLog.SelectedText = ''
    $txtLog.Select(0, 0); $txtLog.SelectionColor = $script:LogColors.warn; $txtLog.SelectedText = [string]$st.Mark + "`n"
    $txtLog.ReadOnly = $true
}

function Get-LogExportHeader([datetime]$when = (Get-Date)) {
    # 12.11 : en-tete du journal exporte (Export-LogFile), deux lignes ecrites en tete du fichier seulement, jamais dans le
    # journal affiche : date de l export et versions (application, calcul de calibration, mesure sur l image), puis lecteur
    # du bandeau et lecteur cible de ses ecritures (Get-TargetDrive, 140 ; « (meme lecteur) » sans lecteur cible). Apres
    # « Vider », la ligne de version du demarrage n est plus dans le journal : l en-tete la remplace. Ni chemin, ni nom de
    # compte, ni nom de poste. Tableau protege par la virgule (pas de @() autour de l appel). Date en culture invariante :
    # « / » et « : » d un format .NET sont sinon les separateurs de la culture du poste (13.11.2026 en de-DE, 14.05.09 en
    # fi-FI) ; la ligne s ecrit de la meme facon sur tout poste
    $tgt = Get-TargetDrive
    $l1 = (T "Journal exporté le {0} par Greaseweazle Studio v{1} ; calcul de calibration v{2}, mesure sur l'image v{3}.") -f $when.ToString('dd/MM/yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture), "$($script:Version)", "$($script:CalibCalc)", "$($script:ContentCalc)"
    $l2 = (T "Lecteur du bandeau : {0} ; lecteur cible de ses écritures : {1}.") -f "$($cmbDrive.Text)", $(if ($tgt) { $tgt } else { (T '(même lecteur)') })
    return ,@($l1, $l2)
}

function Export-LogFile([string]$path) {
    # 12.11 : export du journal (bouton « Exporter », 540) : les deux lignes de Get-LogExportHeader, puis le texte du
    # journal tel qu il est affiche (marque de troncature comprise, Limit-LogText), avec ses fins de ligne ; codage
    # inchange (Set-Content -Encoding UTF8)
    (((Get-LogExportHeader) -join "`n") + "`n" + $txtLog.Text) | Set-Content -LiteralPath $path -Encoding UTF8
}

# --- Progression par piste : ligne de gw, commande, plan d une etape, fin de sequence (12.11) ---
# Une source, trois niveaux. La ligne : Get-GwLineInfo, seule lecture d une ligne de gw pour la progression. La commande :
# Update-Progress tient l etat (040), Show-GwProgress le peint dans la barre d etat. Le plan : une etape de plusieurs
# commandes (passe de calibration, conditionnement, passe de la mesure sur l image) declare ses commandes par New-ProgPlan ;
# Get-ProgPlanFrac rend son avancement d apres les pistes annoncees par gw, lu par Update-CalibProgress (270) a la place
# du temps ecoule. Affichage seulement : rien ici ne lance, n arrete ni ne juge une operation.

function Get-GwLineInfo([string]$line) {
    # Lecture d une ligne de gw 1.23, sans etat ni interface. $null : ligne sans effet sur la progression. Annonce du jeu
    # de pistes : @{ Kind = 'head' ; Verb = Reading, Writing, Erasing ou Converting ; Total = pistes annoncees }. Ligne de
    # piste « Tc.h...: » : @{ Kind = 'track' ; Key = 'c.h' ; Op = 'erase' (« Erasing Track »), 'write' (« Writing Track »)
    # ou 'read' (toute autre : lecture, conversion, piste sautee) ; Retry = numero d essai, ou '' }. Premier caractere
    # teste avant toute expression ; memes expressions que la 12.10, plus « Converting ». Piste renumerotee (« T1.0 ->
    # Drive 2.0: ») : cle de la piste de l image
    if ($line.Length -lt 5) { return $null }
    $c = $line[0]
    if ($c -ceq 'T') {
        if ($line -notmatch '^T(\d+)\.(\d+)\b[^:]*: ?(Erasing Track|Writing Track)?') { return $null }
        $key = $Matches[1] + '.' + $Matches[2]
        $op = if ($Matches[3] -ceq 'Erasing Track') { 'erase' } elseif ($Matches[3]) { 'write' } else { 'read' }
        $retry = ''
        if ($line.IndexOf('Retry #') -ge 0 -and $line -match 'Retry #(\d+)(?:\.(\d+))?') { $retry = [string]$(if ($Matches[2]) { $Matches[2] } else { $Matches[1] }) }
        return @{ Kind = 'track'; Key = $key; Op = $op; Retry = $retry }
    }
    if ($c -ceq 'R' -or $c -ceq 'W' -or $c -ceq 'E' -or $c -ceq 'C') {
        if ($line -match '^(Reading|Writing|Erasing|Converting)\s+c=([\d,\-]+):h=([\d,\-]+)') {
            return @{ Kind = 'head'; Verb = [string]$Matches[1]; Total = ((Get-SpecCount $Matches[2]) * (Get-SpecCount $Matches[3])) }
        }
    }
    return $null
}

function Get-GwProgress {
    # Etat de la commande gw en cours, ou de la derniere : @{ Known (total annonce par gw) ; Total ; Seen (pistes
    # distinctes vues) ; Done (pistes terminees, au plus le total annonce) ; Key (derniere piste vue) ; Retry (numero
    # d essai, ou '') }. Pour l affichage seulement : la regle de fin d une commande lit ProgTotal et ProgSeen (600)
    $t = [int]$script:ProgTotal
    $d = [int]$script:ProgDone
    if ($t -gt 0 -and $d -gt $t) { $d = $t }
    return @{ Known = ($t -gt 0); Total = $t; Seen = $(if ($script:ProgSeen) { [int]$script:ProgSeen.Count } else { 0 }); Done = $d; Key = [string]$script:ProgKey; Retry = [string]$script:ProgRetry }
}

function Show-GwProgress {
    # Peint la barre et le compteur de la barre d etat d apres l etat de la commande, seulement s il a change (ProgDirty) :
    # une fois par lot de lignes de gw, et non a chaque ligne. Compteur « piste {0}  ({1}/{2}, {3} %) » : {0} piste en
    # cours, {1} et {3} pistes terminees (une ecriture ou un effacement n affiche plus 100 % pendant sa derniere piste).
    # Plus de pistes vues qu annoncees : barre et compteur restent au total annonce, la piste en cours continue de
    # s afficher. Sans annonce reconnue : barre animee, « piste {0} » seul, comme en 12.10
    if (-not $script:ProgDirty) { return }
    $script:ProgDirty = $false
    $g = Get-GwProgress
    if ($g.Known) {
        if ([string]$stBar.Style -ne 'Continuous' -or $stBar.Maximum -ne $g.Total) { $stBar.Style = 'Continuous'; $stBar.Minimum = 0; $stBar.Maximum = $g.Total }
        if ($stBar.Value -ne $g.Done) { $stBar.Value = $g.Done }
    }
    if (-not $g.Key) { return }
    $txt = if ($g.Known) { (T "piste {0}  ({1}/{2}, {3} %)") -f "$($g.Key)", "$($g.Done)", "$($g.Total)", "$([math]::Round(100 * $g.Done / $g.Total, 0))" }
           else { (T "piste {0}") -f "$($g.Key)" }
    if ($g.Retry) { $txt += ((T "  -  essai {0}") -f "$($g.Retry)") }
    if ([string]$stTrack.Text -ne $txt) { $stTrack.Text = $txt }
}

function Get-EndRuleTotal {
    # Total des pistes annoncees que le minuteur principal (600) passe a la regle de fin d une commande (Get-GwEndRule :
    # « moins de la moitie des pistes annoncees » = operation incomplete). 0 pour gw convert : son annonce donne depuis
    # la 12.11 un total a la barre d etat, mais une image peut porter moins de pistes que le jeu annonce ; la regle reste
    # celle de la 12.10, ou ce total n etait pas lu. Autres commandes : $script:ProgTotal, inchange
    if ([string]$script:ProgHead -ceq 'Converting') { return 0 }
    return [int]$script:ProgTotal
}

function Get-GwCmdUnits([string[]]$gwArgs, [int]$tracks = -1) {
    # Poids estime d une commande gw dans le plan d une etape, d apres ses arguments (tableau, ou une seule chaine) :
    # @{ Fixed ; Per ; Tracks ; Units }, Units = Fixed + Tracks x Per, en secondes estimees ($script:ProgCost, 040 :
    # proportions relevees sur les lecteurs d un seul utilisateur, jamais affichees comme des durees). Par piste :
    # effacement ; ecriture, plus le pre-effacement (--pre-erase), plus la verification (sans --no-verify) ; relecture selon
    # --revs. Pistes : c= et h= de --tracks (Get-SpecCount), 0 si elles ne s y lisent pas (l annonce de gw complete alors
    # le poids, Update-Progress) ; $tracks >= 0 : nombre impose. Autre commande (clean, rpm, seek, info...) : poids nul
    $c = $script:ProgCost
    $line = ' ' + ((@($gwArgs) | Where-Object { $null -ne $_ }) -join ' ') + ' '
    $verb = ''
    foreach ($t in @($line.Trim() -split '\s+')) { if ($t -and -not $t.StartsWith('--')) { $verb = $t; break } }
    $per = -1.0
    if ($verb -ceq 'erase') { $per = [double]$c.Erase }
    elseif ($verb -ceq 'write') {
        $per = [double]$c.Write
        if ($line -match '\s--pre-erase\s') { $per += [double]$c.PreErase }
        if ($line -notmatch '\s--no-verify\s') { $per += [double]$c.Verify }
    }
    elseif ($verb -ceq 'read') {
        $per = if ($line -match '\s--revs=(\d+)\s') { [double]$c.ReadBase + [double]$c.ReadRev * [int]$Matches[1] } else { [double]$c.ReadNoRevs }
    }
    if ($per -lt 0) { return @{ Fixed = 0.0; Per = 0.0; Tracks = 0; Units = 0.0 } }
    $n = $tracks
    if ($n -lt 0) {
        $n = 0
        if ($line -match '\s--tracks=(\S+)') {
            $ts = [string]$Matches[1]
            if ($ts -match '(?:^|:)c=([\d,\-]+)') {
                $nc = Get-SpecCount $Matches[1]
                if ($ts -match '(?:^|:)h=([\d,\-]+)') { $n = $nc * (Get-SpecCount $Matches[1]) }
            }
        }
    }
    return @{ Fixed = [double]$c.Fixed; Per = $per; Tracks = [int]$n; Units = ([double]$c.Fixed + [int]$n * $per) }
}

function New-ProgPlan($cmds) {
    # Plan d une etape faite de plusieurs commandes gw ($cmds : tableaux d arguments, dans l ordre de leur lancement) :
    # $script:ProgPlan = @{ Units (poids prevu) ; Done (poids des commandes finies) ; Max (plus grande fraction rendue) ;
    # Cmds (poids prevus, par commande) ; Got (commandes recues de Start-Progress) }. Pose la ou l etape construit ses
    # commandes (New-CalibPass, Start-CalibCondition, New-ContentPass) ; retire quand la passe est comptee, a l arret d une
    # calibration et au repos (Update-SeqEnd). Ne lance rien et ne modifie aucune commande
    $u = 0.0
    $l = New-Object System.Collections.Generic.List[object]
    foreach ($c in @($cmds)) {
        if ($null -eq $c) { continue }
        $w = Get-GwCmdUnits ([string[]]@($c))
        $u += [double]$w.Units
        $l.Add($w)
    }
    $script:ProgPlan = @{ Units = $u; Done = 0.0; Max = 0.0; Cmds = $l.ToArray(); Got = 0 }
    $script:ProgCmd = $null
}

function Get-ProgPlanFrac {
    # Avancement de l etape en cours, de 0 a 1 ; $null sans plan, ou tant que le plan n a recu aucune commande (Start-Gw
    # remplace par un banc de test : l appelant garde alors son calcul par le temps). (poids fini + part de la commande en
    # cours) / max(poids prevu, poids fini + poids de la commande en cours). Part de la commande en cours : des sa
    # premiere ligne de piste, part fixe + pistes terminees x cout par piste ; avant (4 a 6 s en pratique, ou toute la
    # commande si gw n imprime aucune ligne de piste), temps ecoule depuis son lancement, borne a 98 % de son poids.
    # Jamais decroissant dans un plan (Max), 1 au plus : une commande non prevue (reprise d une tete), ou plus de pistes
    # vues que prevu, allonge le plan sans faire reculer la barre, qui attend alors sur place
    $p = $script:ProgPlan
    if (-not $p -or [int]$p.Got -le 0) { return $null }
    $done = [double]$p.Done; $cur = 0.0; $w = 0.0
    $pc = $script:ProgCmd
    if ($pc) {
        $w = [double]$pc.Units
        if ($script:ProgSeen -and $script:ProgSeen.Count -gt 0) {
            $cur = [double]$pc.Fixed + (Get-GwProgress).Done * [double]$pc.Per
            if ($cur -gt $w) { $w = $cur }
        } else {
            $el = if ($script:GwStart -is [datetime]) { ((Get-Date) - $script:GwStart).TotalSeconds } else { 0.0 }
            $cur = [math]::Max(0.0, [math]::Min($el, 0.98 * $w))
        }
    }
    $den = [math]::Max([double]$p.Units, $done + $w)
    $f = if ($den -gt 0) { [math]::Min(1.0, ($done + $cur) / $den) } else { 0.0 }
    if ($f -lt [double]$p.Max) { $f = [double]$p.Max } else { $p.Max = $f }
    return [double]$f
}

function Set-SeqEnd([string]$text, [string]$icon = 'idle', [switch]$NoTime, [switch]$IfNone) {
    # Etat de la barre d etat a poser a la fin de la sequence en cours : le resultat de l operation (restauration,
    # calibration, controle apres ecriture, recherche des lecteurs), sans compteur ni barre. En attente seulement :
    # Update-SeqEnd l applique au repos ; une commande gw qui suit l annule (Start-Progress), un echec du lancement aussi
    # (Set-GwLaunchFailedStatus). Icone : idle, ok ou err ($script:StIcons, 540). Sans -NoTime, l heure suit le texte
    # 12.11 : -IfNone : ne remplace pas un etat deja en attente (arret d une calibration juste apres le verdict d une
    # restauration : Stop-Restore puis Stop-PrecompCalib dans le minuteur et dans le bouton Arreter)
    if ($IfNone -and $null -ne $script:SeqEnd) { return }
    $script:SeqEnd = @{ Text = $text; Icon = $icon; NoTime = [bool]$NoTime }
}

function Clear-SeqEnd {
    # Etat de fin de sequence en attente annule sans qu une commande gw suive : la barre d etat vient de recevoir une
    # consigne qui le remplace (attente de la disquette de destination d une restauration, Enter-RestoreWait, apres une
    # calibration sur une disquette sacrifiee : sans cela, « Annuler » pendant l attente afficherait « Pret. », puis au
    # repos le titre de la calibration)
    $script:SeqEnd = $null
}

function Update-SeqEnd {
    # Minuteur principal (600) : fin de sequence, une fois l application au repos (Get-AppBusy vide). Etat pose par
    # Set-SeqEnd : texte (suivi de l heure), icone, compteur de piste efface, barre masquee. Sans etat pose, apres une
    # sequence de deux commandes gw ou plus : compteur efface et barre masquee, texte de la derniere commande garde ; une
    # commande isolee garde l affichage de la 12.10. Jamais sur un etat d echec de la derniere commande (« ... en echec
    # (code N) », gw non lance : ProgFailed), qui dit la cause : l attente est abandonnee, la barre d etat laissee.
    # Plan de l etape retire. Cout par passage : trois variables, puis Get-AppBusy tant qu une sequence est en cours
    if ($null -eq $script:SeqEnd -and [int]$script:SeqCmds -le 0 -and $null -eq $script:ProgPlan) { return }
    if (Get-AppBusy) { return }
    $e = $script:SeqEnd; $n = [int]$script:SeqCmds
    $script:SeqEnd = $null; $script:SeqCmds = 0; $script:ProgPlan = $null; $script:ProgCmd = $null
    if ($script:ProgFailed) { return }
    if ($e) {
        $stOp.Text = $(if ($e.NoTime) { [string]$e.Text } else { [string]$e.Text + '  -  ' + (Get-Date -Format 'HH:mm:ss') })
        $stOp.Image = $(if ($script:StIcons.ContainsKey([string]$e.Icon)) { $script:StIcons[[string]$e.Icon] } else { $script:StIcons.idle })
        $stTrack.Text = ''; $stBar.Visible = $false
    } elseif ($n -ge 2) { $stTrack.Text = ''; $stBar.Visible = $false }
}
