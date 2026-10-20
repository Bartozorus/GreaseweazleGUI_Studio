$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    $gwDoneTick = $false                                  # 12.8 (D4) : fin d une commande gw traitee a ce tick
    # Sortie de gw
    if ($script:GwProc) {
        if ($script:GwProc.HasExited) {
            $gwDoneTick = $true
            Read-GwOutput $true
            $code = $script:GwProc.ExitCode
            # Lecture de prechauffage : code retour et pistes manquantes sans effet, l etape suivante a toujours lieu
            $soft = [bool]$script:GwSoft; $script:GwSoft = $false; $script:GwLastCode = $code
            # Activite du lecteur : seulement si le moteur a tourne (code 0, ou au moins une piste lue ou ecrite) ;
            # nouvelle serie si la commande a commence CalWarmupGapMin apres la fin de la precedente
            if ($script:GwDriveKey -and ($code -eq 0 -or ($script:ProgSeen -and $script:ProgSeen.Count -gt 0))) {
                $actNow = Get-Date; $actCur = $script:DriveActivity[$script:GwDriveKey]
                if (-not $actCur -or ($script:GwStart - $actCur.End).TotalMinutes -ge $script:CalWarmupGapMin) { $script:DriveActivity[$script:GwDriveKey] = @{ Start = $script:GwStart; End = $actNow } }
                else { $actCur.End = $actNow }
            }
            $script:GwDriveKey = $null
            $script:OutStdoutReader = $null; $script:OutStderrReader = $null
            $script:OutStdoutTask = $null; $script:OutStderrTask = $null
            Stop-Progress $code
            $wasWrite = [bool]$script:GwIsWrite
            if ($script:GwIsWrite) {
                if ($script:WriteRetries.Count -gt 0) {
                    Append-Log ((T "Pistes ayant nécessité de nouveaux essais : ") + (($script:WriteRetries.Keys | Sort-Object | ForEach-Object { ((T "{0} (x{1})") -f "$_", "$($script:WriteRetries[$_])") }) -join ', '))
                } elseif ($code -eq 0 -and $script:GwWriteSummary) { Append-Log (T 'Écriture : aucune piste n''a nécessité de nouvel essai.') }
                $script:GwIsWrite = $false
            }
            $elapsed = if ($script:GwStart -is [datetime]) { [math]::Round(((Get-Date) - $script:GwStart).TotalSeconds, 1) } else { 0 }
            if ($script:Detect) { Stop-Progress 0 }
            else { Append-Log ((T "<<< Terminé (code retour : {0}, {1} s, {2} ligne(s) reçues)") -f "$code", "$elapsed", "$($script:GwLines)") }
            # Arret silencieux avec le code 0 (ex. « Command Failed: WriteProtected ») : pas de controle ni d etape suivante,
            # ils masqueraient le probleme. Ecriture : gw imprime toujours une ligne de bilan quand il va au bout (verification
            # comprise), quel que soit le nombre de pistes de l image. Autres commandes : moins de la moitie des pistes annoncees.
            $incomplete = if ($wasWrite) { $code -eq 0 -and -not $script:GwWriteSummary }
                          else { $code -eq 0 -and $script:ProgTotal -gt 0 -and $script:ProgSeen.Count * 2 -lt $script:ProgTotal }
            $script:GwLastIncomplete = [bool]$incomplete
            if ($incomplete -and -not $soft) {
                Append-Log ((T "ERREUR : opération incomplète, gw s'est arrêté après {0} piste(s) sur {1} annoncées avec le code 0. Vérifier le lecteur, le câble USB et l'alimentation, puis relancer.") -f "$($script:ProgSeen.Count)", "$($script:ProgTotal)")
                $script:Chain.Clear(); $script:WriteQueue.Clear()
                Stop-WriteWarmup        # defensif : une lecture de prechauffage est « soft »
                $why = (T 'opération gw incomplète : disquette protégée en écriture, absente, ou lecteur en défaut ? Voir le journal')
                if ($script:Restore -and $script:Restore.Stage -eq 'probe') { Restore-ProbeFailed }
                else {
                    # Restauration : raison exacte d abord, sauf si le controle a deja un bilan (il l ecrira dans le rapport)
                    if ($script:Restore -and -not ($script:Rep -and $script:Rep.Round -gt 0)) { Stop-Restore $why }
                    if ($script:Rep) { Stop-WriteCheck -GwError }
                    if ($script:Cal) { Stop-PrecompCalib -GwError }       # 12.8 (VAL01) : passe du nouvel essai : jugement garde
                    if ($script:Restore) { Stop-Restore $why }
                }
                # 12.8 (lot 3a) : mesure de qualite incomplete (pas d analyse) : erreur gw, resultat affiche perime
                if ($script:QualView.State -eq 'run' -and $script:QualView.Kind -eq 'measure') { $script:AlignLoop = $false; $script:AlignNextAt = $null; Set-QualityStale 'gwerror' }
            }
            if (-not $script:Detect) { Append-Log '' }
            $script:GwProc = $null
            Set-Busy $false
            if ($script:Detect) { Complete-DriveProbe $code }
            if ($script:Chain.Count -gt 0) {
                if ($code -eq 0 -or $soft) {
                    Invoke-NextChainStep
                } else {
                    $why = ((T "gw a retourné le code {0}, voir le journal") -f "$code")
                    if ($script:Restore -and $script:Restore.Stage -eq 'probe') { Restore-ProbeFailed }
                    elseif ($script:Restore -and -not ($script:Rep -and $script:Rep.Round -gt 0)) { Stop-Restore $why }
                    $script:Chain.Clear(); $script:WriteQueue.Clear()
                    Stop-WriteWarmup    # defensif : une lecture de prechauffage est « soft »
                    Append-Log (T 'Séquence interrompue : gw a retourné une erreur.')
                    if ($txtCmpResult.Text -like ((T 'Comparaison en cours') + '*')) { $txtCmpResult.Text = ((T "ÉCHEC : gw a retourné le code {0}. Voir le journal.") -f "$code") }
                    # 12.8 (lot 3a) : toute mesure de qualite (et non plus la seule mesure continue) : resultat affiche perime
                    if ($script:AlignLoop) { $script:AlignLoop = $false; $script:AlignNextAt = $null }
                    if ($script:QualView.State -eq 'run' -and $script:QualView.Kind -eq 'measure') { Set-QualityStale 'gwerror' }
                    if ($script:Rep) { Stop-WriteCheck -GwError }
                    if ($script:Cal) { Stop-PrecompCalib -GwError }       # 12.8 (VAL01) : passe du nouvel essai : jugement garde
                }
            }
            if ($code -ne 0 -and -not $soft -and $script:Restore -and -not $script:Restore.Waiting) { Stop-Restore ((T "gw a retourné le code {0}, voir le journal") -f "$code") }
        } else {
            Read-GwOutput $false
        }
    }
    # Ecriture apres une calibration rapide de la Bibliotheque, terminee (gw, etapes, controle et calibration finis) :
    # champs --precomp remis au profil de la reference, le profil decale ne valait que pour la disquette ecrite
    if ($script:LevelFieldsPending -and -not $script:GwProc -and $script:Chain.Count -eq 0 -and -not $script:Rep -and -not $script:Cal -and -not $script:WriteWarm) {
        $script:LevelFieldsPending = $false
        if ($cmbWProfile.SelectedIndex -eq 0 -and -not $script:Restore) {
            Update-PrecompForImage $txtWFile.Text
            Append-Log (T 'Calibration rapide : écriture terminée, champs --precomp remis au profil de la référence (le profil décalé ne valait que pour la disquette écrite).')
        }
    }
    # 12.8 (D4) : ecriture depuis la Bibliotheque terminee : onglet Ecriture retabli (prereglage non enregistre)
    if ($script:OpOverride) { Update-OpOverride $gwDoneTick }
    # Calibration precomp : barre globale et temps restant ; prechauffage d une ecriture lente
    if ($script:Cal) { Update-CalibProgress } elseif ($script:WriteWarm) { Update-WriteWarmupProgress }
    if ($script:HomeCalBusy) { Update-HomeCalibCard }     # carte Calibration de l Accueil : progression, puis bilan
    # 12.7 : bareme de calibration remis a la double densite une fois l application au repos (filet de securite ; chaque
    # calibration pose le sien a son debut). Fenetre principale (ShowDialog, donc modale) exclue, comme pour Resume-CalibRedo
    if ($script:CalScaleFam -ne 'dd' -and -not (Get-AppBusy) -and -not $script:CalRedo -and @([System.Windows.Forms.Application]::OpenForms | Where-Object { $_.Modal -and $_.Visible -and -not [object]::ReferenceEquals($_, $form) }).Count -eq 0) { Set-CalibScale '' }
    # 12.7 point 2 : calibration B arretee avant sa fin (Stop-PrecompCalib) : decision sur la courbe A, ouverte ici une fois
    # l application au repos et sans autre fenetre modale (Stop-PrecompCalib est appele pendant le traitement de la fin
    # de gw, ou une fenetre modale le bloquerait). La fenetre principale, affichee par ShowDialog, est modale : exclue
    if ($script:CalRedo -and $script:CalRedo.Stage -eq 'interrupted' -and -not (Get-AppBusy) -and @([System.Windows.Forms.Application]::OpenForms | Where-Object { $_.Modal -and $_.Visible -and -not [object]::ReferenceEquals($_, $form) }).Count -eq 0) { Resume-CalibRedo }
    # 12.8 (VAL01) : erreur gw pendant la passe du nouvel essai (Stop-PrecompCalib -GwError) : fin de la calibration sur le
    # jugement de la derniere verification, ici une fois gw fini, sans etape en attente ni autre fenetre modale (la fin peut
    # ouvrir la fenetre de decision, jamais pendant le traitement de la fin de gw). Bouton Arreter entre-temps : abandon
    if ($script:Cal -and $script:Cal.RetestEnd -and -not $script:GwProc -and $script:Chain.Count -eq 0 -and @([System.Windows.Forms.Application]::OpenForms | Where-Object { $_.Modal -and $_.Visible -and -not [object]::ReferenceEquals($_, $form) }).Count -eq 0) { Complete-CalibRetestEnd }
    Update-HomeProgress                                   # 12.7 : zone de progression de l Accueil, puis bilan
    # Bouton « Passer le prechauffage » : visible pendant tout prechauffage (ecriture lente, calibration), inactif une fois
    # clique ; Enregistrer et Reinitialiser (inactifs pendant une operation) lui cedent leur place dans la barre
    $wcur = if ($script:WriteWarm) { $script:WriteWarm } elseif ($script:Cal -and $script:Cal.Stage -eq 'warmup') { $script:Cal } else { $null }
    $wshow = [bool]$wcur
    if ($script:WarmSkipShown -ne $wshow) { $script:WarmSkipShown = $wshow; $btnWarmSkip.Visible = $wshow; $btnCfgSave.Visible = -not $wshow; $btnCfgReset.Visible = -not $wshow }
    if ($wshow -and $btnWarmSkip.Enabled -eq [bool]$wcur.WarmSkip) { $btnWarmSkip.Enabled = -not [bool]$wcur.WarmSkip }
    # Restauration : etape en cours et chien de garde
    if ($script:Restore) { Update-RestoreProgress }
    # Detection des lecteurs au demarrage, fenetre affichee et aucune operation en cours (12.8, D20 : Get-AppBusy, comme
    # Start-DriveDetect ; detection gardee en attente, et non abandonnee, pendant un prechauffage ou la mesure continue)
    if ($script:DetectAt -and (Get-Date) -ge $script:DetectAt -and -not $script:GwProc -and -not (Get-AppBusy)) {
        $script:DetectAt = $null
        Start-DriveDetect 'auto'
    }
    # Alignement : passe suivante en mode continu
    if ($script:AlignLoop -and $script:AlignNextAt -and -not $script:GwProc -and -not $script:Cal -and -not $script:Rep -and -not $script:Restore -and $script:Chain.Count -eq 0 -and (Get-Date) -ge $script:AlignNextAt) {
        $script:AlignNextAt = $null
        Start-AlignCycle
    }
    # Recherche bibliotheque terminee ?
    if ($script:LibAsync -and $script:LibAsync.IsCompleted) { Complete-LibSearch }
    # Indexation en cours / terminee
    if ($script:LibIndexing) {
        if ([FastIndex]::Busy) {
            $lblLibCount.Text = ((T "indexation : {0} fichiers...") -f "$('{0:N0}' -f [FastIndex]::Scanned)")
        } else {
            $script:LibIndexing = $false; $btnLibReindex.Enabled = $true
            if ([FastIndex]::Error) { Append-Log ((T "Indexation : ERREUR {0}") -f "$([FastIndex]::Error)") }
            else { Append-Log ((T "Bibliothèque : index construit, {0} fichiers en {1} s.") -f "$('{0:N0}' -f [FastIndex]::Count)", "$([math]::Round([FastIndex]::LastBuildSeconds,0))") }
            Show-LibIndexStatus
            if ($script:LibPendingSearch) { $script:LibPendingSearch = $false; Update-Library }
        }
    }
    # Recherche au fil de la frappe (seulement si l'index est pret : sinon on attend Entree)
    if ($script:LibSearchAt -and (Get-Date) -ge $script:LibSearchAt) {
        $script:LibSearchAt = $null
        if (Test-LibIndexReady $txtLibRoot.Text) { Update-Library }
    }
})
$timer.Start()

$form.KeyPreview = $true
$form.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::F1) { Open-HelpForTab; $_.Handled = $true } })
$form.Add_FormClosing({
    if ($script:Restore) {
        $q = [System.Windows.Forms.MessageBox]::Show((T "Une restauration est en cours. Quitter quand même ? La disquette de destination restera incomplète."), (T 'Restauration'), 'YesNo', 'Warning')
        if ($q -ne 'Yes') { $_.Cancel = $true; return }
        if ($script:GwProc -and -not $script:GwProc.HasExited) { try { $script:GwProc.Kill() } catch { } }
        Stop-Restore (T 'fenêtre fermée pendant la restauration')   # rapport ecrit, onglet Ecriture et lecteur remis avant Save-Config
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) {
        try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
    }
    [void](Save-Config)
    Stop-LibSearch
    if ($script:LibRunspace) { try { $script:LibRunspace.Close(); $script:LibRunspace.Dispose() } catch { } }
    $timer.Stop()
})
# 12.8 (lot 3) : pinceaux, stylos, polices, formats et pictogrammes de l affichage de la qualite liberes avec la fenetre
$form.Add_FormClosed({ Clear-QualityGdi })

# Position du separateur : appliquee une fois la fenetre affichee (taille connue)
$script:PendingSplit = 0
$script:PendingLogVisible = $true
$form.Add_Shown({
    $script:UiReady = $true
    Render-Banner
    Apply-Cues
    Set-LogVisible $script:PendingLogVisible
    if ($script:PendingSplit -gt 0) {
        $max = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
        if ($script:PendingSplit -ge $split.Panel1MinSize -and $script:PendingSplit -le $max) {
            $split.SplitterDistance = $script:PendingSplit
        }
    }
    # Bibliotheque chargee une fois la fenetre visible (racine reseau possible)
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try { Update-Library; if ($txtWFile.Text) { Update-PrecompForImage $txtWFile.Text } else { Update-CurveButton '' } } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    # Calibrations d un autre calcul : choix de l utilisateur, puis detection des lecteurs (qui lance gw)
    Resolve-OldCalibrations
    if (Test-Path -LiteralPath $script:GwExe) { $script:DetectAt = (Get-Date).AddSeconds(1) }   # detection des lecteurs
})
Fit-ControlText $form

# --- Demarrage -----------------------------------------------------------------
Set-Defaults
$loaded = Load-Config
Update-TabSet
Update-CurveButton ''

Append-Log "Greaseweazle Studio v$($script:Version)"
Append-Log ((T "Répertoire  : {0}") -f "$($script:AppDir)")
if (Test-Path -LiteralPath $script:GwExe) { Append-Log (T 'gw.exe      : trouvé') }
else { Append-Log (T 'gw.exe      : ABSENT - placez ce script dans le répertoire de gw.exe') }
if ($loaded) { Append-Log (T 'Config      : chargée depuis GreaseweazleGUI.json') }
else         { Append-Log (T 'Config      : aucune, valeurs par défaut') }
Append-Log ((T "Extraction  : {0}") -f "$($script:TempDir)")
Append-Log ((T "Index       : {0}") -f "$(if ($script:FastIndexOk) { $script:IndexDir } else { (T 'module indisponible, recherche directe') })")
Append-Log ''

[void]$form.ShowDialog()
