# ============================== FONCTIONS : CALIBRATION B ======================

# ============================== CALIBRATION B (12.7) ===========================
# « Refaire sur une autre disquette » (fenetre de decision d une calibration complete) : la courbe A est mise de cote en
# memoire, la calibration d avant A est retablie, la meme calibration (B) est refaite sur une autre disquette sacrifiee,
# puis les deux courbes sont comparees face par face et l utilisateur choisit A, B ou aucune, sans fusion des mesures.
# Sur disque pendant B : la calibration d avant A (A perdue si l application est fermee, limite acceptee). Etat :
# $script:CalRedo (Stage 'confirm', 'running', 'interrupted'), en memoire seulement.

function Start-CalibRedo($cal, [string[]]$issues, [string[]]$kinds, $prevCal, [bool]$toWrite) {
    # « Refaire sur une autre disquette » (fenetre de decision de la calibration A, Complete-PrecompCalib) : courbe A mise de
    # cote en memoire, calibration d avant A retablie, meme calibration (B) relancee sur une autre disquette sacrifiee apres
    # une confirmation sans compte a rebours ; aucune fusion des mesures. Ecriture qui suivait A : annulee si B est lancee.
    # $true : B lancee ; $false : B non lancee, courbe A retablie (la fenetre de A se rouvre).
    $keys = @($cal.Units | ForEach-Object { Get-CalibUnitKey $cal $_ })
    $aCurves = @{}; foreach ($k in $keys) { if ($script:PrecompCurves[$k]) { $aCurves[$k] = $script:PrecompCurves[$k].Clone() } }
    $aDate = if ($script:PrecompCurves[$keys[0]]) { [string]$script:PrecompCurves[$keys[0]].Date } else { '' }
    $script:CalRedo = @{ Stage = 'confirm'; ACal = $cal; AIssues = @($issues); AKinds = @($kinds); AKeys = $keys; ACurves = $aCurves
                         AState = (Get-CalibSnapshot $keys); PrevA = $prevCal; ADate = $aDate; Why = '' }
    Restore-CalibState $prevCal
    Append-Log ((T "Calibration : « Refaire sur une autre disquette » : courbe A du {0} mise de côté, calibration précédente rétablie pendant la calibration B.") -f "$aDate")
    $svAfter = $script:AfterCalib; $script:AfterCalib = ''
    # Arbitrage 2 : courbe A perdue si l application est fermee pendant B, dit dans la confirmation
    $intro = ((T "Calibration B sur une autre disquette sacrifiée, avec les réglages de la calibration A du {0}.`n`nRetirez la disquette de la calibration A et insérez une AUTRE disquette sacrifiée : sans valeur, jamais l'original ni la disquette à écrire. L'application ne peut pas distinguer deux disquettes : la case ci-dessous fait foi. Les deux courbes seront ensuite comparées face par face, et vous choisirez celle à conserver.") -f "$aDate") + "`n`n" +
             (T "Pendant la calibration B, la configuration garde la calibration d'avant la calibration A : si vous fermez l'application avant la fin de la calibration B, la courbe A est perdue.") + "`n`n"
    if ($cal.Home) {
        if ($cal.Geom -and -not (Test-Path -LiteralPath ([string]$cal.Geom.Img))) { try { [void](New-CalibGeometry (Get-HomeCalibInfo ([string]$cal.Geom.Fmt)) ([int]$cal.MaxCyl + 1)) } catch { } }
        Start-PrecompCalib -Intro $intro -Geom $cal.Geom -Heads ([bool]$cal.Slow) -Test ([string]$cal.Mode) -NoWarmup:([bool]$cal.NoWarmup)
    } else {
        Start-PrecompCalib -Intro $intro -Heads ([bool]$cal.Slow) -Test ([string]$cal.Mode) -NoWarmup:([bool]$cal.NoWarmup)
    }
    if ($script:Cal) {
        if ($toWrite) { Append-Log (T "Écriture annulée : calibration refaite sur une autre disquette ; relancez l'écriture depuis la Bibliothèque une fois la courbe choisie.") }
        if ($cal.Home) { $script:HomeCalBusy = $true }
        return $true
    }
    Restore-CalibState $script:CalRedo.AState
    $script:CalRedo = $null; $script:AfterCalib = $svAfter
    Append-Log (T 'Calibration B non lancée : la courbe A est rétablie, décision sur la courbe A.')
    return $false
}

function Complete-CalibRedo($cal, [string[]]$issues, [string[]]$kinds, $prevCal) {
    # Fin de la calibration B (Complete-PrecompCalib, B deja enregistree) : comparaison avec la courbe A, toujours montree, puis
    # choix : courbe B (rien a faire), courbe A (etat « A appliquee » retabli) ou aucune (calibration d avant A retablie).
    # Bilan de la zone de progression de l Accueil (Set-HomeProgDone) selon le choix.
    $r = $script:CalRedo; $script:CalRedo = $null
    $rep = Get-CalibRedoReport $r $cal @($issues) @($kinds)
    foreach ($l in @($rep.Log)) { Append-Log $l }
    $choice = Show-CalibReview $cal @($issues) $false $false $false $false @{ Mode = 'ab'; Curves = $rep.Curves; Zones = $rep.Zones; Text = $rep.Text; Pick = $rep.Pick }
    switch ($choice) {
        'keepA' { Restore-CalibState $r.AState; $lblWCal.Text = (T "Courbe A conservée : la calibration B n'est pas retenue."); Append-Log (T 'Calibration B : courbe A conservée à votre demande, courbe B abandonnée.'); $hk = 'warn' }
        'stop'  { Restore-CalibState $prevCal; $lblWCal.Text = (T 'Calibrations A et B abandonnées : la calibration précédente est rétablie.'); Append-Log (T 'Calibrations A et B abandonnées à votre demande : la calibration précédente est rétablie.'); $hk = 'abandon' }
        default { $lblWCal.Text = (T 'Courbe B conservée : calibration refaite sur une autre disquette.'); Append-Log (T 'Calibration B : courbe B conservée.'); $hk = $(if (@($issues).Count -gt 0) { 'warn' } else { 'ok' }) }
    }
    Set-HomeProgDone $cal $hk
    if ($r.ACal.Home) { Update-HomeCalibCard }
    if ($choice -ne 'stop') { Show-PrecompCurve $cal.Family $cal.Slow }
}

function Resume-CalibRedo {
    # Calibration B arretee avant sa fin (bouton Arreter, erreur gw, controle de surface, aucune mesure exploitable) : decision
    # sur la courbe A seule. Minuteur principal (application au repos, aucune fenetre modale) ou Complete-PrecompCalib.
    $r = $script:CalRedo
    if (-not $r -or $r.Stage -ne 'interrupted') { return }
    $script:CalRedo = $null                                   # avant la fenetre : le minuteur ne la rouvre pas
    Append-Log ((T "Calibration B arrêtée avant sa fin ({0}) : décision sur la courbe A.") -f "$($r.Why)")
    $iss = @($r.AIssues)
    $txt = ((T "La calibration B s'est arrêtée avant sa fin ({0}) : aucune comparaison n'est possible.") -f "$($r.Why)") + "`n" + ((T "Réserves de la courbe A ({0}) :") -f "$($r.ADate)") + "`n" +
           ((@($iss) | ForEach-Object { "  - $_" }) -join "`n") + "`n`n" + (T "Conserver la courbe A : elle est rétablie et enregistrée.`nAbandonner la courbe : la calibration d'avant la calibration A reste en place.`nFermer la fenêtre : la courbe A est conservée.")
    $cvs = @($r.AKeys | ForEach-Object { $r.ACurves[$_] } | Where-Object { $_ })
    $choice = Show-CalibReview $r.ACal $iss $false $false $false $false @{ Mode = 'aonly'; Curves = $cvs; Zones = @(); Text = $txt; Pick = $null }
    if ($choice -eq 'stop') { $lblWCal.Text = (T 'Calibration B arrêtée : la courbe A est abandonnée, la calibration précédente reste en place.'); Append-Log (T 'Courbe A abandonnée à votre demande : la calibration précédente reste en place.'); $hk = 'abandon' }
    else { Restore-CalibState $r.AState; $lblWCal.Text = (T 'Calibration B arrêtée : la courbe A est conservée.'); Append-Log (T 'Courbe A conservée à votre demande.'); $hk = 'warn' }
    Set-HomeProgDone $r.ACal $hk
    if ($r.ACal.Home) { Update-HomeCalibCard }
}
