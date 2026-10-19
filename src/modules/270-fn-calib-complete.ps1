# ============================== FONCTIONS : CALIBRATION COMPLETE ===============

function Start-PrecompCalib([switch]$ForceFine, [string]$Intro = '', [switch]$LevelAfter, $Geom = $null, $Heads = $null, [string]$Test = '', [switch]$NoWarmup) {
    # ForceFine : test fin impose (reference de la calibration rapide) ; Intro : texte place en tete de l avertissement ;
    # LevelAfter : apres une calibration sur disquette sacrifiee, le niveau de la disquette a ecrire est mesure.
    # Carte Calibration de l Accueil : Geom (type de disquette, image de geometrie), Heads (une courbe par tete) et Test
    # ('std' ou 'fine') a la place de l image, de la case Ecriture lente et du mode de l onglet Ecriture ; NoWarmup :
    # prechauffage du lecteur desactive pour cette calibration (case de la fenetre de la carte)
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    $chk = Test-CalibImage $Geom
    if (-not $chk) { return }
    $img = $chk.Img; $family = $chk.Family; $nCyl = $chk.NCyl; $maxCyl = $chk.MaxCyl; $cylSrc = $chk.CylSrc
    $fine = ([bool]$ForceFine -or $(if ($Test) { $Test -eq 'fine' } else { $cmbWCalMode.SelectedIndex -eq 1 }))
    $slow = if ($null -ne $Heads) { [bool]$Heads } else { [bool]$chkWSlow.Checked }
    if ($fine) { $cyls = @(0..$maxCyl) }
    else { $cyls = @(0..$maxCyl | Where-Object { $_ % 10 -eq 0 }); if ($cyls -notcontains $maxCyl) { $cyls += $maxCyl } }
    $cyls = @($cyls | Sort-Object -Unique)
    # 12.7 : calibration B (« Refaire sur une autre disquette ») : reglages de la calibration A controles avant le premier gw
    $redo = [bool]($script:CalRedo -and $script:CalRedo.Stage -eq 'confirm')
    if ($redo) {
        $why = Get-CalibRedoMismatch $script:CalRedo.ACal $family $cyls $slow $fine "$($cmbDrive.Text)" $img $Geom
        if ($why) { [void](Show-AppMessage ((T "Calibration B impossible : réglage différent de la calibration A ({0}). La décision sur la courbe A est rouverte.") -f "$why") (T 'Calibration precomp') 'OK' 'Warning'); return }
    }
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    # 12.8 (D6) : prechauffage avant une calibration complete : choix de l appelant (case de la carte « Calibrer le
    # lecteur », calibration B : celui de A), sinon reglage warmFullCalib (case de l onglet Ecriture : bouton Calibrer,
    # calibration automatique avant une ecriture, restauration)
    $noWarm = if ($PSBoundParameters.ContainsKey('NoWarmup')) { [bool]$NoWarmup } else { -not [bool](Get-Setting 'warmFullCalib') }
    # Duree estimee : passes d ecriture et de relecture, plus le prechauffage du lecteur (borne haute : il est reduit ou
    # saute si le lecteur vient de servir, plan recalcule apres l avertissement par Start-CalibWarmup)
    $wu = if ($noWarm) { 0.0 } else { [math]::Max(0.0, [double]$script:CalWarmupMinutes) }
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * 1.4 * $nPassEst / 60 + $wu, 0))
    $modeTxt = if ($fine) { (T 'test fin, tous les cylindres') } else { (T 'test standard, un cylindre sur 10') }
    if ($slow) { $modeTxt += (T ', une courbe par tête (écriture lente)') }
    $famTxt = Get-CalibFamilyName $family
    $cylList = Format-CylList $cyls
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    # Avertissement (usure du support) : validation automatique au bout du delai ; avant une ecriture, case « disquette
    # sacrifiee » : la disquette a ecrire est redemandee apres la calibration (Complete-PrecompCalib)
    $toWrite = ($script:AfterCalib -eq 'write')
    $target = if ($script:Restore) { (T 'la disquette de destination') } else { (T 'la disquette à écrire') }
    $auto = if ($toWrite) { (T "Calibration automatique avant l'écriture : la disquette insérée reçoit d'abord le motif de test, puis l'image.") + "`n`n" } else { '' }
    $bodyFmt = if ($Geom) { (T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nType de disquette : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de ce type.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.") }
               else { (T "Calibration de la précompensation sur le lecteur {0} ({1}).`n`nImage : {2}, famille {3}, {4}.`nMotif de test : données pseudo-aléatoires générées à la densité de l'image, son contenu n'est pas écrit.`nCylindres de test : {5} (2 faces), ÉCRASÉS à chaque passe. Durée estimée : {6} min pour {7} passes.") }
    $body = $bodyFmt -f "$($cmbDrive.Text)", "$modeTxt", "$($chk.Label)", "$famTxt", "$cylSrc", "$cylList", "$minutes", "$nPassEst"
    # 12.8 (lot 1b) : nouvel essai automatique des cylindres non converges : supplement borne d une passe de verification
    # ciblee (Get-CalibRetestMinutes), et non un total (la duree estimee ne compte ni l encadrement ni les mesures
    # complementaires du test standard)
    $minRetest = Get-CalibRetestMinutes $cyls.Count $maxCyl $fine
    $body += "`n" + ((T "Si des cylindres restent non convergés, un nouvel essai automatique ajoute au plus {0} min (une passe de vérification ciblée).") -f "$minRetest")
    if ($wu -gt 0) { $body += "`n" + ((T "Préchauffage du lecteur avant la première passe : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée.") -f (Format-CalDuration (60 * $wu))) }
    # Courbe remplacee d un autre nombre de cylindres (plus de 4 d ecart, seuil de Get-LevelRef) : la nouvelle s applique
    # ensuite a toutes les images de la famille (meme phrase que la fenetre de la carte Calibration de l Accueil)
    $cvr = $script:PrecompCurves[$(if ($slow) { "${family}_h0" } else { $family })]
    if ($cvr -and [math]::Abs(@($cvr.Values).Count - $nCyl) -gt 4) { $body += "`n" + ((T "La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}.") -f "$(@($cvr.Values).Count)", "$nCyl", "$famTxt") }
    # Passes supplementaires possibles : encadrement (1), mesures complementaires du test standard (2, 30 cylindres au plus).
    # Ecritures par piste au plus : $nPassMax, celui de la 12.7. 12.8 (lot 1b) : le nouvel essai des cylindres non converges
    # le respecte (decisions128.md : « nombre d ecritures par piste respecte ») : WriteMax, garde de Get-CalibRetestPlan et
    # de Add-DriftWitnesses ; une piste deja ecrite $nPassMax fois n est ni visee, ni relue, ni temoin
    $nPassMax = $nPassEst + 1 + $(if ($fine) { 0 } else { 2 })
    $extra = if ($fine) { (T 'si la courbe demande un encadrement ou un nouvel essai des cylindres non convergés') } else { (T 'si la courbe demande un encadrement, des mesures complémentaires (30 cylindres au plus) ou un nouvel essai des cylindres non convergés') }
    $wear = (T "ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues, jusqu'à {1} {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer.") -f "$nPassEst", "$nPassMax", "$extra"
    $choice = if ($toWrite) { (T "Pour épargner {0}, cochez la case ci-dessous (le compte à rebours s'arrête), remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée.") -f "$target" }
              else { (T 'Insérez de préférence une disquette sacrifiée (vierge ou sans valeur), puis validez.') }
    $swapLabel = if ($toWrite) { (T "J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration") -f "$target" } else { '' }
    if ($redo) {
        # Confirmation sans compte a rebours : la case est obligatoire (une disquette de valeur est peut-etre inseree)
        $rc = Show-TimedConfirm 'frmCalibRedo' (T 'Calibration sur une autre disquette') ($Intro + $body + "`n`n" + $wear) (T 'Lancer la calibration B') 'Diagnostic' '' (T "J'ai retiré la disquette de la calibration A et inséré une autre disquette sacrifiée") '' (T "Pas de démarrage automatique : cochez la case, puis cliquez sur « Lancer la calibration B ».") -Seconds 0 -NeedCheck
        $ans = @{ Ok = ($rc.Ok -and $rc.Checked); Swap = $false; Auto = $false }
    } else { $ans = Show-CalibConfirm ($Intro + $auto + $body + "`n`n" + $wear + "`n`n" + $choice) $swapLabel }
    if (-not $ans.Ok) { return }
    if ($ans.Auto) { Append-Log ((T "Calibration : avertissement validé automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
    if ($ans.Swap) { Append-Log ((T "Calibration sur une disquette sacrifiée : {0} sera redemandée avant l'écriture.") -f "$target") }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    try { $pat = New-CalibPattern $family $img $nCyl }
    catch { [void][System.Windows.Forms.MessageBox]::Show(((T "Calibration : motif de test impossible à créer : {0}") -f "$($_.Exception.Message)"),(T 'Calibration precomp'),'OK','Error'); return }
    if ($redo -and [int]$pat.Bits -ne [int]$script:CalRedo.ACal.PatternBits) {
        [void](Show-AppMessage ((T "Calibration B impossible : réglage différent de la calibration A ({0}). La décision sur la courbe A est rouverte.") -f (T 'densité du motif')) (T 'Calibration precomp') 'OK' 'Warning'); return
    }
    if ($redo) {
        $script:CalRedo.Stage = 'running'
        Append-Log ((T "=== Calibration B sur une autre disquette, mêmes réglages que la calibration A du {0} : les deux courbes seront comparées ===") -f "$($script:CalRedo.ADate)")
        Append-Log (T "Calibration B : autre disquette sacrifiée déclarée insérée (case cochée) ; l'application ne peut pas distinguer deux disquettes.")
    }
    # Ecriture lente : une unite par tete (mesures, courbe et verification separees) ; sinon une unite pour les deux tetes
    # @() autour du if : une seule unite resterait sinon une hashtable nue ($cal.Units[0] = $null)
    Set-CalibScale $family     # 12.7 : bareme de la famille (amplitudes haute densite), apres les sorties anticipees
    $units = @(if ($slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $script:Cal = @{
        Mode = $(if ($fine) { 'fine' } else { 'std' }); Cyls = $cyls; MaxCyl = $maxCyl; Family = $family; Slow = $slow
        Image = $img; Pattern = $pat.Path; PatternBits = $pat.Bits; MaxCoarse = [int](@($script:CalCoarse) | Measure-Object -Maximum).Maximum; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        Stage = 'coarse'; Values = @($script:CalCoarse); Index = 0; Value = 0; ValueTxt = ''; Spec = ''
        Units = $units; VerifyCount = 0; Swap = [bool]$ans.Swap; LevelAfter = [bool]$LevelAfter
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        # Progression globale : passes faites / prevues, durees mesurees par phase, estimation initiale 0,7 s par piste et par phase
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = $nPassEst; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7
        Home = [bool]$Geom; Geom = $Geom; NoWarmup = [bool]$noWarm   # carte Calibration de l Accueil ; 12.8 : reglage warmFullCalib
        # 12.7 : controle de surface de la passe 1 (Invoke-CalibAnalysis) : avertissement valide seul, numero de la disquette
        # (Restart-PrecompCalib), bilan, defaut grossier, fenetre ouverte (Hold) ; Redo : calibration B (point 2) ; Cyls0 :
        # cylindres de test de depart, controle d identite de la calibration B (Cyls s etend aux mesures complementaires du
        # test standard, Start-CalibDensify)
        AutoStart = [bool]$ans.Auto; Disk = 1; SurfDone = $false; Surf = $null; Medium = $null; SurfGross = $false; SurfKept = $false; Hold = $false; Redo = $redo
        Cyls0 = [int[]]@($cyls)
        # 12.8 (lot 1b) : passes de nouvel essai faites (Start-CalibRetest) ; ecritures par piste annoncees au plus
        Retests = 0; WriteMax = [int]$nPassMax
    }
    if ($Geom) {
        # Densite du type choisi (source de Get-FormatCalibInfo), et non « HFE, bits par piste de l image » de la geometrie
        if ($Geom.BitsSrc) { $pat.Source = [string]$Geom.BitsSrc }
        Append-Log ((T "=== Calibration precomp : lecteur {0}, type {1} ({2}, {3}) ===") -f "$($cmbDrive.Text)", "$($chk.Label)", "$famTxt", "$modeTxt")
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min, d'après le type de disquette choisi.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
    } else {
        Append-Log ((T "=== Calibration precomp : lecteur {0}, image {1} ({2}, {3}) ===") -f "$($cmbDrive.Text)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt")
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min. L'image ne fixe que la densité et le nombre de cylindres, son contenu n'est pas écrit.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
    }
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    Start-CalibWarmup      # prechauffage du lecteur s il y a lieu, puis premiere passe de mesure
}

function Get-CalibRetestMinutes([int]$nCyls, [int]$maxCyl, [bool]$fine) {
    # 12.8 (lot 1b) : duree au plus du nouvel essai automatique des cylindres non converges (avertissement de
    # Start-PrecompCalib), au rythme de la duree estimee (2 pistes par cylindre, 1,4 s par piste et par passe) : une passe
    # de verification ciblee, bornee par une passe sur tous les cylindres que la calibration peut tester (test standard :
    # 30 cylindres complementaires au plus, Start-CalibDensify), arrondie a la minute superieure ; sans prechauffage (il
    # precede la premiere passe)
    $n = [math]::Min($maxCyl + 1, $nCyls + $(if ($fine) { 0 } else { 30 }))
    return [int][math]::Max(1, [math]::Ceiling($n * 2 * 1.4 / 60))
}

function Format-CalDuration([double]$sec) {
    if ($sec -lt 0) { $sec = 0 }
    $m = [math]::Floor($sec / 60); $s = [math]::Round($sec - 60 * $m, 0)
    if ($m -gt 0) { return "$m min $('{0:00}' -f $s) s" }
    return "$s s"
}

function Update-CalibProgress {
    # Barre globale : passes terminees + fraction de la passe en cours, d apres les durees moyennes
    # mesurees (ecriture et relecture separees) ; avant toute mesure, 0,7 s par piste et par phase.
    $cal = $script:Cal
    if (-not $cal) { return }
    # 12.7 : fenetre du controle de surface ouverte (Invoke-CalibAnalysis) : libelle fige (la minuterie principale appelle
    # cette fonction pendant la boucle modale : la barre avancerait et le temps restant baisserait)
    if ($cal.Hold) { $lblWCal.Text = (T "Calibration en attente : contrôle de surface, décision demandée (lecteur {0}).") -f "$($cal.Drive)"; return }
    # Libelles au format court du prechauffage de l ecriture : avancement et temps restant en tete, details ensuite entre
    # parentheses (libelle coupe a la largeur de l onglet a la taille minimale de la fenetre)
    if ($cal.Stage -eq 'warmup') {
        # Prechauffage : duree ecoulee sur la duree prevue (Get-WarmupLeft) ; passe a la demande : fin de la lecture en cours
        $g = Get-WarmupLeft $cal
        $pbWCal.Value = $g.Pct
        $lblWCal.Text = if ($cal.WarmSkip) { (T 'Préchauffage du lecteur {0} passé : fin de la lecture en cours.') -f "$($cal.Drive)" }
                        else { (T "Préchauffage avant la calibration : {2} %, reste environ {3} (lecteur {0}, lecture {1}, sans écriture)") -f "$($cal.Drive)", "$($cal.WarmReads)", "$($g.Pct)", (Format-CalDuration ([math]::Round($g.Left))) }
        return
    }
    $nTracks = $cal.Cyls.Count * 2
    $avgW = if ($cal.WriteDurs.Count -gt 0) { ($cal.WriteDurs | Measure-Object -Average).Average } else { $nTracks * $cal.EstTrack }
    $avgR = if ($cal.ReadDurs.Count -gt 0)  { ($cal.ReadDurs  | Measure-Object -Average).Average } else { $nTracks * $cal.EstTrack }
    if ($avgW -lt 1) { $avgW = 1 }; if ($avgR -lt 1) { $avgR = 1 }
    $pass = $avgW + $avgR
    $elapsed = ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $frac = if ($cal.Phase -eq 'write') { [math]::Min(0.98, $elapsed / $avgW) * ($avgW / $pass) }
            else { ($avgW / $pass) + [math]::Min(0.98, $elapsed / $avgR) * ($avgR / $pass) }
    $total = [math]::Max(1, [int]$cal.TotalPasses)
    $done = [math]::Min($total, $cal.PassesDone + $frac)
    $pct = [int][math]::Floor(100 * $done / $total)
    $remaining = $pass * ($total - $done)
    $phaseTxt = if ($cal.Phase -eq 'write') { (T 'écriture') } else { (T 'relecture') }
    $pbWCal.Value = [math]::Max(0, [math]::Min(100, $pct))
    $fmt = if ($cal.Mode -eq 'level') { (T "Calibration rapide : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Redo) { (T "Calibration B : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           else { (T "Calibration : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
    $lblWCal.Text = ($fmt -f "$([math]::Min($total, $cal.PassesDone + 1))", "$total", "$($cal.ValueTxt)", "$phaseTxt", "$pct", (Format-CalDuration $remaining))
}

function Stop-PrecompCalib {
    # Abandon (bouton Arreter, erreur gw, fichier manquant) : etat remis a zero, barre masquee ; bilan de l Accueil (12.7)
    # 12.7 point 2 : calibration B arretee : decision sur la courbe A seule, differee au minuteur principal (Resume-CalibRedo)
    if ($script:CalRedo -and $script:CalRedo.Stage -eq 'running') { $script:CalRedo.Stage = 'interrupted'; if (-not $script:CalRedo.Why) { $script:CalRedo.Why = (T 'calibration interrompue') } }
    $cal = $script:Cal
    $script:Cal = $null
    $pbWCal.Visible = $false
    $lblWCal.Text = (T 'Calibration precomp interrompue.')
    Append-Log (T 'Calibration precomp interrompue.')
    Set-HomeProgDone $cal 'stop'
    if ($script:AfterCalib) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : calibration interrompue.') }
    if ($script:Restore) { Stop-Restore (T 'calibration interrompue') }
}

function Restart-PrecompCalib($cal, [bool]$swap) {
    # Controle de surface, « Changer de disquette » : meme calibration reprise a la premiere passe sur la disquette
    # nouvellement inseree, sans nouvel avertissement (la case de la fenetre l a confirme) ; seuls les unites, le compte des
    # passes et l heure de debut repartent de zero ; prechauffage selon l activite du lecteur (Get-CalWarmupPlan).
    Set-CalibScale ([string]$cal.Family)     # 12.7 : bareme de la famille (deja pose par Start-PrecompCalib)
    $units = @(if ($cal.Slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cal.Cyls) { $u.Results[[int]$c] = @{} } }
    $cal.Units = $units; $cal.Stage = 'coarse'; $cal.Index = 0; $cal.Value = 0; $cal.ValueTxt = ''; $cal.Spec = ''; $cal.VerifyCount = 0
    $cal.PassesDone = 0; $cal.TotalPasses = $script:CalCoarse.Count + $script:CalMaxVerify; $cal.StartTime = Get-Date
    $cal.SurfDone = $false; $cal.Surf = $null; $cal.Medium = $null; $cal.SurfGross = $false; $cal.SurfKept = $false; $cal.Hold = $false
    $cal.AutoStart = $false; $cal.Disk = 1 + [int]$cal.Disk; $cal.Retests = 0
    Append-Log ((T "=== Calibration precomp reprise sur une autre disquette (disquette {0}) : mêmes réglages, cylindres {1} ===") -f "$($cal.Disk)", "$($cal.CylList)")
    if ($swap -and -not $cal.Swap) {
        $cal.Swap = $true
        Append-Log ((T "Calibration sur une disquette sacrifiée : {0} sera redemandée avant l'écriture.") -f (T 'la disquette à écrire'))
    }
    $pbWCal.Value = 0
    Update-CalibProgress
    Start-CalibWarmup
}

function Get-CalWarmupPlan([string]$key, [double]$minutes) {
    # Duree du prechauffage (s) pour le lecteur 'peripherique|lecteur' : reglage en minutes, reduit de la duree de la
    # derniere serie d activite continue du lecteur si sa derniere commande gw qui a fait tourner le moteur (code 0, ou au
    # moins une piste lue ou ecrite : une commande en echec immediat ne compte pas) s est terminee il y a moins de
    # CalWarmupGapMin (Active, Idle : depuis cette fin) ; Skip : il en reste moins de CalWarmupSkipMin. Reduced : duree
    # annoncee comme reduite (activite d au moins 1 s une fois arrondie : une commande tres courte, gw rpm ou nettoyage
    # arrete tout de suite, ne raccourcit le prechauffage que d une fraction de seconde)
    $p = @{ Sec = [math]::Max(0.0, 60.0 * $minutes); Recent = $false; Active = 0.0; Idle = 0.0; Skip = $false; Reduced = $false }
    if ($p.Sec -le 0) { return $p }
    $a = if ($key) { $script:DriveActivity[$key] } else { $null }
    if (-not $a -or $a.Start -isnot [datetime] -or $a.End -isnot [datetime]) { return $p }
    $idle = ((Get-Date) - $a.End).TotalSeconds
    if ($idle -ge 60.0 * $script:CalWarmupGapMin) { return $p }
    $p.Recent = $true; $p.Idle = [math]::Max(0.0, $idle); $p.Active = [math]::Max(0.0, ($a.End - $a.Start).TotalSeconds)
    $p.Sec = [math]::Max(0.0, $p.Sec - $p.Active)
    $p.Reduced = ([math]::Round($p.Active) -ge 1)
    if ($p.Sec -lt 60.0 * $script:CalWarmupSkipMin) { $p.Skip = $true }
    return $p
}

function Get-WarmupLeft($w) {
    # Prechauffage (calibration ou ecriture lente) : avancement (%) et temps restant (s) ; la lecture en cours peut depasser
    # la duree prevue (duree moyenne des lectures)
    $now = Get-Date
    $el = ($now - $w.WarmStart).TotalSeconds
    $left = [math]::Max(0.0, $w.WarmSec - $el)
    if (@($w.WarmDurs).Count -gt 0 -and $w.WarmReadStart -is [datetime]) {
        $avg = (@($w.WarmDurs) | Measure-Object -Average).Average
        $left = [math]::Max($left, $avg - ($now - $w.WarmReadStart).TotalSeconds)
    }
    $pct = [int][math]::Floor(100 * $el / [math]::Max(1.0, $el + $left))
    return @{ Pct = [math]::Max(0, [math]::Min(100, $pct)); Left = $left }
}

function Start-CalibWarmup {
    # Prechauffage du lecteur avant la premiere passe de mesure d une calibration complete (Start-PrecompCalib, apres
    # l avertissement et la remise eventuelle de la disquette sacrifiee) : lectures sans ecriture des cylindres de test,
    # deux tetes, vers un fichier temporaire, en boucle jusqu a la duree (Get-CalWarmupPlan). Etape 'warmup' de la
    # calibration : « Arreter » l interrompt comme une passe ; une lecture en echec (disquette vierge ou illisible) est
    # sans effet (GwSoft) ; seul l echec du lancement de gw arrete la calibration (Start-Gw, Reset-GwSequence). Apres
    # CalWarmupMaxFails lectures de suite sans aboutir (code non nul, ou code 0 et lecture incomplete : Greaseweazle,
    # lecteur ou disquette absent), le prechauffage est abrege et la calibration commence (Invoke-CalibWarmup).
    # Aussi appele par Start-LevelCalib avant une ecriture lente (mode 'level') : retour a l etape d appel (WarmNext).
    # Bouton « Passer le prechauffage » : fin apres la lecture en cours (WarmSkip).
    $cal = $script:Cal
    if (-not $cal) { return }
    if ([double]$script:CalWarmupMinutes -le 0) { New-CalibPass; return }
    # Case « Prechauffer » decochee dans la fenetre de la carte Calibration (Start-PrecompCalib -NoWarmup)
    if ($cal.NoWarmup) { Append-Log ((T "Préchauffage du lecteur {0} désactivé pour cette calibration.") -f "$($cal.Drive)"); New-CalibPass; return }
    $plan = Get-CalWarmupPlan (Get-GwDriveKey (@('read') + (Get-CommonArgs))) ([double]$script:CalWarmupMinutes)
    $actTxt = Format-CalDuration ([math]::Round($plan.Active)); $idleTxt = Format-CalDuration ([math]::Round($plan.Idle))
    if ($plan.Skip) {
        Append-Log ((T "Préchauffage du lecteur {0} sauté : lecteur déjà en activité pendant {1} (dernière commande terminée il y a {2}).") -f "$($cal.Drive)", "$actTxt", "$idleTxt")
        New-CalibPass; return
    }
    $durTxt = Format-CalDuration ([math]::Round($plan.Sec))
    if ($cal.Mode -eq 'level') {
        if ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$($cal.Drive)", "$durTxt", "$actTxt", "$idleTxt") }
        else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration rapide et l'écriture lente, pour que le niveau soit mesuré dans l'état du lecteur au moment de l'écriture.") -f "$($cal.Drive)", "$durTxt") }
    }
    elseif ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$($cal.Drive)", "$durTxt", "$actTxt", "$idleTxt") }
    else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la calibration, pour stabiliser sa température.") -f "$($cal.Drive)", "$durTxt") }
    $cal.WarmNext = [string]$cal.Stage
    $cal.Stage = 'warmup'; $cal.WarmSec = [double]$plan.Sec; $cal.WarmStart = Get-Date; $cal.WarmReads = 0; $cal.WarmFails = 0
    $cal.WarmFailRun = 0; $cal.WarmSkip = $false
    $cal.WarmDurs = @(); $cal.WarmReadStart = $null
    $cal.WarmScp = Join-Path $script:TempDir 'precomp-warmup.scp'
    $cal.WarmArgs = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$($cal.TSpec)", "`"$($cal.WarmScp)`"")
    Invoke-CalibWarmup
}

function Invoke-CalibWarmup {
    # Lecture de prechauffage suivante, ou premiere passe de mesure : CalWarmupMinReads lectures au moins, puis arret a la
    # duree, ou avant une lecture qui la depasserait de plus de la moitie de la duree moyenne d une lecture. Lecture sans
    # aboutir : code non nul, ou code 0 et lecture incomplete (GwLastIncomplete) ; CalWarmupMaxFails de suite : defaut
    # materiel probable (Greaseweazle, lecteur ou disquette absent), prechauffage abrege, la calibration commence et sa
    # premiere ecriture signale le defaut s il persiste
    $cal = $script:Cal
    if (-not $cal -or $cal.Stage -ne 'warmup') { return }
    if ($cal.WarmReadStart -is [datetime]) {
        $cal.WarmDurs += ((Get-Date) - $cal.WarmReadStart).TotalSeconds; $cal.WarmReadStart = $null
        $code = [int]$script:GwLastCode
        if ($code -ne 0 -or [bool]$script:GwLastIncomplete) {
            $cal.WarmFails++; $cal.WarmFailRun++
            if ($cal.WarmFails -eq 1) { Append-Log ((T "Préchauffage du lecteur {0} : la lecture n'a pas abouti (code {1}) ; sans effet sur la calibration, le préchauffage continue.") -f "$($cal.Drive)", "$code") }
        } else { $cal.WarmFailRun = 0 }
        if ($cal.WarmFailRun -ge $script:CalWarmupMaxFails) {
            if (Test-Path -LiteralPath $cal.WarmScp) { Remove-Item -LiteralPath $cal.WarmScp -Force -ErrorAction SilentlyContinue }
            Append-Log ((T "Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : la calibration commence, sa première écriture signalera le défaut s'il persiste.") -f "$($cal.Drive)", "$($cal.WarmFailRun)")
            $cal.Stage = if ($cal.WarmNext) { [string]$cal.WarmNext } else { 'coarse' }
            New-CalibPass; return
        }
    }
    $left = $cal.WarmSec - ((Get-Date) - $cal.WarmStart).TotalSeconds
    $avg = if (@($cal.WarmDurs).Count -gt 0) { (@($cal.WarmDurs) | Measure-Object -Average).Average } else { 0.0 }
    if (Test-Path -LiteralPath $cal.WarmScp) { Remove-Item -LiteralPath $cal.WarmScp -Force -ErrorAction SilentlyContinue }
    # Fin : duree atteinte, ou prechauffage passe a la demande (bouton « Passer le prechauffage », apres la lecture en cours)
    if (($cal.WarmSkip -and $cal.WarmReads -ge 1) -or ($cal.WarmReads -ge $script:CalWarmupMinReads -and ($left -le 0 -or $left -lt $avg / 2))) {
        $elTxt = Format-CalDuration ([math]::Round(((Get-Date) - $cal.WarmStart).TotalSeconds))
        if ($cal.WarmFails -gt 0) { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}, dont {3} sans aboutir (sans effet sur la calibration).") -f "$($cal.Drive)", "$($cal.WarmReads)", "$elTxt", "$($cal.WarmFails)") }
        else { Append-Log ((T "Préchauffage du lecteur {0} terminé : {1} lecture(s) en {2}.") -f "$($cal.Drive)", "$($cal.WarmReads)", "$elTxt") }
        $cal.Stage = if ($cal.WarmNext) { [string]$cal.WarmNext } else { 'coarse' }
        New-CalibPass; return
    }
    $cal.WarmReads++; $cal.WarmReadStart = Get-Date; $script:GwLastCode = 0; $script:GwLastIncomplete = $false
    Update-CalibProgress
    $script:Chain.Clear()
    $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.WarmArgs) })
    $script:Chain.Enqueue({ Invoke-CalibWarmup })
    Invoke-NextChainStep
}

function New-CalibPass {
    # Une passe = une ou deux commandes gw write puis une relecture en flux.
    #  - mesure : meme valeur pour tous les cylindres de test et les deux tetes, une commande ;
    #  - encadrement : cylindres encore sous-compenses a la plus forte valeur mesuree, ecrits a leur estimation +
    #    CalBracketMargin (une valeur par cylindre ; par tete en ecriture lente), relus seuls ;
    #  - verification : le profil obtenu ; en ecriture lente tete 0 puis tete 1, chacune avec son profil.
    $cal = $script:Cal
    $writes = @(); $readTs = $cal.TSpec
    if ($cal.Stage -eq 'coarse') {
        $cal.Value = [int]$cal.Values[$cal.Index]; $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns"
        Append-Log ((T "Calibration : passe de mesure {0}/{1}, precomp {2} ns") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$($cal.Value)")
        $writes += ,@($cal.TSpec, $cal.Spec)
    } elseif ($cal.Stage -eq 'bracket') {
        $cal.ValueTxt = (T 'encadrement')
        $all = @{}
        foreach ($u in $cal.Units) { foreach ($c in @($u.Bracket.Keys)) { $all[[int]$c] = $true } }
        $cyls = [int[]]@($all.Keys | Sort-Object)
        if ($cal.Slow) {
            foreach ($u in $cal.Units) { if ($u.Bracket.Count -gt 0) { $writes += ,@("c=$(Format-CylList ([int[]]@($u.Bracket.Keys))):h=$($u.Head)", (Get-BracketSpec $u.Bracket)) } }
        } else {
            $writes += ,@("c=$(Format-CylList $cyls):h=0-1", (Get-BracketSpec $cal.Units[0].Bracket))
        }
        $readTs = "c=$(Format-CylList $cyls):h=0-1"
        $specTxt = (@($cal.Units | ForEach-Object { "$($_.Prefix)$(Get-BracketSpec $_.Bracket)" } | Where-Object { $_ -match '=' })) -join ' ; '
        Append-Log ((T "Calibration : passe d'encadrement des cylindres {0}, encore sous-compensés à {1} ns : precomp {2}") -f (Format-CylList $cyls), "$($cal.MaxCoarse)", "$specTxt")
    } elseif ($cal.Stage -eq 'densify') {
        $cal.ValueTxt = (T "mesure complémentaire {0}") -f "$($cal.DensePass)"
        $all = @{}
        foreach ($u in $cal.Units) { foreach ($c in @($u.Dense.Keys)) { $all[[int]$c] = $true } }
        $cyls = [int[]]@($all.Keys | Sort-Object)
        if ($cal.Slow) {
            foreach ($u in $cal.Units) { if ($u.Dense.Count -gt 0) { $writes += ,@("c=$(Format-CylList ([int[]]@($u.Dense.Keys))):h=$($u.Head)", (Get-BracketSpec $u.Dense)) } }
        } else {
            $writes += ,@("c=$(Format-CylList $cyls):h=0-1", (Get-BracketSpec $cal.Units[0].Dense))
        }
        $readTs = "c=$(Format-CylList $cyls):h=0-1"
        $specTxt = (@($cal.Units | ForEach-Object { "$($_.Prefix)$(Get-BracketSpec $_.Dense)" } | Where-Object { $_ -match '=' })) -join ' ; '
        Append-Log ((T "Calibration : mesure complémentaire {0} des cylindres {1} : precomp {2}") -f "$($cal.DensePass)", (Format-CylList $cyls), "$specTxt")
    } elseif ($cal.Stage -eq 'level') {
        # Calibration rapide : reference decalee du niveau courant sur les seuls cylindres de mesure ; ecriture rapide une
        # commande (h=0-1), ecriture lente une commande par tete non terminee
        $all = @{}; $parts = @()
        foreach ($u in $cal.Units) {
            if ($u.Done) { continue }
            $lc = [int[]]@($u.LTarget.Keys | ForEach-Object { [int]$_ } | Sort-Object)
            foreach ($c in $lc) { $all[$c] = $true }
            $lv = '{0:+0;-0;0}' -f [int]$u.D
            if ($null -eq $u.Head) { $parts += ((T "niveau {0} ns") -f "$lv") } else { $parts += ((T "tête {0} {1} ns") -f "$($u.Head)", "$lv") }
            if ($cal.Slow) { $writes += ,@("c=$(Format-CylList $lc):h=$($u.Head)", (Get-BracketSpec $u.LTarget)); $cal.TrackWrites += $lc.Count }
            else { $writes += ,@("c=$(Format-CylList $lc):h=0-1", (Get-BracketSpec $u.LTarget)); $cal.TrackWrites += 2 * $lc.Count }
        }
        $cal.ValueTxt = $parts -join ', '
        $readTs = "c=$(Format-CylList ([int[]]@($all.Keys | Sort-Object))):h=0-1"
        Append-Log ((T "Calibration rapide : passe {0}/{1}, {2}") -f "$($cal.LPass)", "$($script:LevelMaxPasses)", "$($cal.ValueTxt)")
    } elseif ($cal.Slow) {
        # Verification : tous les cylindres estimes (V1), puis seulement ceux dont la valeur a change (V2, VerifyList)
        $cal.ValueTxt = (T 'profil')
        $all = @{}
        foreach ($u in $cal.Units) {
            $lst = if ($null -ne $u.VerifyList) { @($u.VerifyList) } else { @($cal.Cyls) }
            if ($lst.Count -eq 0) { continue }
            foreach ($c in $lst) { $all[[int]$c] = $true }
            $writes += ,@("c=$(Format-CylList ([int[]]$lst)):h=$($u.Head)", $u.Profile)
        }
        if ($null -ne $cal.Units[0].VerifyList) {
            $vlTxt = (@($cal.Units | Where-Object { @($_.VerifyList).Count -gt 0 } | ForEach-Object { $uu = $_; "$($uu.Prefix)$(Format-CylList ([int[]]@(@($uu.VerifyList) | Where-Object { @($uu.Witness) -notcontains $_ })))" })) -join ' ; '
            # 12.8 (lot 1b) : passe du nouvel essai (Start-CalibRetest), numerotee apres les verifications prevues
            if ([int]$cal.Retests -gt 0) { Append-Log ((T "Calibration : passe de vérification {0}/{1} du nouvel essai, cylindres relus (non convergés, voisins immédiats et cylindres modifiés) : {2}") -f "$($cal.VerifyCount)", "$([int]$cal.VerifyCount)", "$vlTxt") }
            else { Append-Log ((T "Calibration : passe de vérification {0}/{1} ciblée sur les cylindres modifiés : {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$vlTxt") }
            # 12.8 (lot 1b) : unites ecrites a cette passe seulement (passe du nouvel essai : une tete hors nouvel essai garde
            # les temoins de son jugement, sans etre ecrite)
            $wt = @($cal.Units | Where-Object { @($_.Witness).Count -gt 0 -and @($_.VerifyList).Count -gt 0 } | ForEach-Object { "$($_.Prefix)$(Format-CylList ([int[]]@($_.Witness)))" })
            if ($wt.Count -gt 0) { Append-Log ((T "Calibration : témoins de dérive, réécrits à leur valeur inchangée et relus pour mesurer l'écart du lecteur entre deux vérifications : {0}") -f ($wt -join ' ; ')) }
        } else {
            Append-Log ((T "Calibration : passe de vérification {0}/{1}, tête 0 puis tête 1, profils {2} et {3}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Units[0].Profile)", "$($cal.Units[1].Profile)")
        }
        $readTs = "c=$(Format-CylList ([int[]]@($all.Keys | Sort-Object))):h=0-1"
    } else {
        $cal.Spec = $cal.Units[0].Profile; $cal.ValueTxt = (T 'profil')
        $u0 = $cal.Units[0]
        if ($null -ne $u0.VerifyList) {
            $lst = [int[]]@($u0.VerifyList)
            $vlTxt = Format-CylList ([int[]]@($lst | Where-Object { @($u0.Witness) -notcontains $_ }))
            # 12.8 (lot 1b) : passe du nouvel essai (Start-CalibRetest), numerotee apres les verifications prevues
            if ([int]$cal.Retests -gt 0) { Append-Log ((T "Calibration : passe de vérification {0}/{1} du nouvel essai, cylindres relus (non convergés, voisins immédiats et cylindres modifiés) : {2}") -f "$($cal.VerifyCount)", "$([int]$cal.VerifyCount)", "$vlTxt") }
            else { Append-Log ((T "Calibration : passe de vérification {0}/{1} ciblée sur les cylindres modifiés : {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$vlTxt") }
            if (@($u0.Witness).Count -gt 0) { Append-Log ((T "Calibration : témoins de dérive, réécrits à leur valeur inchangée et relus pour mesurer l'écart du lecteur entre deux vérifications : {0}") -f (Format-CylList ([int[]]@($u0.Witness)))) }
            $writes += ,@("c=$(Format-CylList $lst):h=0-1", $cal.Spec)
            $readTs = "c=$(Format-CylList $lst):h=0-1"
        } else {
            Append-Log ((T "Calibration : passe de vérification {0}/{1}, profil {2}") -f "$($cal.VerifyCount)", "$($script:CalMaxVerify)", "$($cal.Spec)")
            $writes += ,@($cal.TSpec, $cal.Spec)
        }
    }
    if (Test-Path -LiteralPath $cal.Scp) { Remove-Item -LiteralPath $cal.Scp -Force }
    $cal.Writes.Clear()
    foreach ($w in $writes) {
        $cal.Writes.Enqueue([string[]](@('write') + (Get-CommonArgs) + @('--pre-erase', '--no-verify') + (Get-CalibDriveArgs) + @("--tracks=$($w[0])", '--precomp', $w[1], "`"$($cal.Pattern)`"")))
    }
    $cal.ReadArgs  = @('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$readTs", "`"$($cal.Scp)`"")
    $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart; $cal.Phase = 'write'
    Update-CalibProgress
    $script:Chain.Clear()
    for ($i = 0; $i -lt $writes.Count; $i++) { $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.Writes.Dequeue()) }) }
    $script:Chain.Enqueue({
        $script:Cal.WriteDurs += ((Get-Date) - $script:Cal.PhaseStart).TotalSeconds
        $script:Cal.Phase = 'read'; $script:Cal.PhaseStart = Get-Date
        Start-Gw $script:Cal.ReadArgs
    })
    $script:Chain.Enqueue({ Invoke-CalibAnalysis })
    Invoke-NextChainStep
}

function Set-CalibEstimates($u, [string]$when = '') {
    # Valeur de precomp par cylindre teste (Get-CalibZero) d apres toutes ses mesures : passes 0/100/200, passe
    # d encadrement et passes de verification. Pente commune = mediane des pentes nettement negatives (-2 a defaut,
    # valeur theorique), utilisee seulement pour extrapoler un cylindre dont la pente locale n est pas fiable.
    $cal = $script:Cal
    $slopes = @(); $measured = 0
    foreach ($c in $cal.Cyls) {
        $pts = $u.Results[[int]$c]
        if ($pts.Count -lt 2) { continue }
        $measured++
        $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object); $ys = @($xs | ForEach-Object { [double]$pts[$_].Shift })
        $mx = ($xs | Measure-Object -Average).Average; $my = ($ys | Measure-Object -Average).Average
        $sxx = 0.0; $sxy = 0.0
        for ($i = 0; $i -lt $xs.Count; $i++) { $sxx += ($xs[$i] - $mx) * ($xs[$i] - $mx); $sxy += ($xs[$i] - $mx) * ($ys[$i] - $my) }
        if ($sxx -gt 0 -and $sxy / $sxx -lt -0.2) { $slopes += $sxy / $sxx }
    }
    if ($measured -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : aucune mesure exploitable pour estimer la précompensation.')); return $false }
    # Tete seule sans aucune pente propre : le decalage ne suit pas la precomp ecrite, la face lue n a pas ete ecrite
    # (tete ou circuit d ecriture defaillant : le motif HFE a toujours deux faces) ; une pente de repli serait sans signification.
    if ($null -ne $u.Head -and $slopes.Count -eq 0) { Append-Log ($u.Prefix + (T 'Calibration : le décalage ne varie pas avec la précompensation écrite, cette face n''a pas été écrite (tête ou circuit d''écriture défaillant ?).')); return $false }
    $pooled = -2.0
    if ($slopes.Count -gt 0) { $sl = @($slopes | Sort-Object); $pooled = $sl[[int][math]::Floor($sl.Count / 2)] }
    $u.Slope = $pooled; $u.Est = @{}; $u.Sig = @{}; $u.Kind = @{}; $u.Own = @{}
    foreach ($c in $cal.Cyls) {
        $z = Get-CalibZero $u.Results[[int]$c] $pooled
        if (-not $z) { continue }
        $u.Est[[int]$c] = $z.Est; $u.Sig[[int]$c] = $z.Sig; $u.Kind[[int]$c] = $z.Kind
        $u.Own[[int]$c] = [bool]$z.Own             # pente propre fiable (sinon pente commune) : Get-TrendEstimates
    }
    foreach ($c in @($u.Outliers)) { if ($u.Kind.ContainsKey([int]$c)) { $u.Kind[[int]$c] = 'outlier' } }
    $mark = @{ interp = ''; extrap = '*'; cap = '^'; outlier = '!' }
    $estTxt = (@($u.Est.Keys | Sort-Object | ForEach-Object { "c$_=$([math]::Round($u.Est[$_], 0))$($mark[$u.Kind[$_]])" })) -join ' '
    Append-Log ($u.Prefix + $when + ((T "Pente moyenne : {0} ns de décalage par ns de precomp ; estimation par cylindre : {1}") -f "$([math]::Round($u.Slope, 2))", "$estTxt"))
    if (@($u.Kind.Values | Where-Object { $_ -ne 'interp' }).Count -gt 0) { Append-Log ($u.Prefix + ((T '  * extrapolée au-delà des mesures, ^ plafonnée à 0 ou {0} ns : valeur peu fiable.') -f "$($script:CalHardNs)")) }
    return $true
}

function Invoke-CalibAnalysis {
    $cal = $script:Cal
    if (-not $cal) { return }
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log (T 'Calibration : fichier SCP absent, analyse impossible.'); Stop-PrecompCalib; return }
    try { $tracks = Read-ScpFile $cal.Scp ([int]$cal.PatternBits) } catch { Append-Log ((T "Calibration : {0}") -f "$($_.Exception.Message)"); Stop-PrecompCalib; return }
    $cal.ReadDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.PassesDone++
    foreach ($u in $cal.Units) {
        if ($cal.Stage -eq 'level' -and $u.Done) { continue }
        # 12.8 (lot 1b) : passe du nouvel essai : seules les unites concernees (InRetest) ; les autres gardent l etat de leur
        # derniere verification (VerifyPrev, ReadLast, temoins : jugement inchange)
        if ($cal.Stage -eq 'verify' -and [int]$cal.Retests -gt 0 -and -not $u.InRetest) { continue }
        # Moyenne des deux faces (profil commun) ou face de l unite seule (ecriture lente) ; erreur-type combinee
        $heads = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
        $shifts = @(); $scores = @(); $bad = @(); $one = @()
        if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList) {
            # Verification ciblee : la mesure de la passe precedente, prise a l ancienne valeur, ne vaut plus pour ces
            # cylindres ; non relus a cette passe, ils restent « non relus » (jamais juges sur un residu perime)
            # Mesure precedente gardee a part : la derive entre deux verifications (Get-VerifyDrift) la compare a la nouvelle
            $u.VerifyPrev = @{}; $u.ReadLast = @{}
            foreach ($c in @($u.VerifyList)) {
                $u.ReadLast[[int]$c] = $true
                if ($u.Verify.ContainsKey([int]$c) -and $u.VerifyP.ContainsKey([int]$c)) { $u.VerifyPrev[[int]$c] = @{ Shift = [double]$u.Verify[[int]$c].Shift; P = [double]$u.VerifyP[[int]$c]; Meas = $u.Verify[[int]$c] } }
                [void]$u.Verify.Remove([int]$c); [void]$u.VerifyP.Remove([int]$c)
            }
        }
        foreach ($c in $cal.Cyls) {
            if ($cal.Stage -eq 'bracket' -and -not $u.Bracket.ContainsKey([int]$c)) { continue }
            if ($cal.Stage -eq 'densify' -and -not $u.Dense.ContainsKey([int]$c)) { continue }
            if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.VerifyList) -notcontains [int]$c) { continue }
            if ($cal.Stage -eq 'level' -and -not $u.LTarget.ContainsKey([int]$c)) { continue }
            if ($null -ne $u.Writes) { $u.Writes[[int]$c] = 1 + [int]$u.Writes[[int]$c] }   # piste ecrite a cette passe
            $sv = @(); $ev = @(); $jv = @(); $fm = @{}; $miss = @()
            foreach ($h in $heads) {
                $tn = [int]$c * 2 + $h
                if (-not $tracks.ContainsKey($tn)) { $miss += $h; continue }
                $m = Get-CalibTrackMeasure $tracks[$tn]; if ($m) { $sv += $m.Shift; $ev += $m.SE; $fm[[int]$h] = $m } else { $miss += $h }
                $j = Get-CalibTrackScore $tracks[$tn]; if ($j -lt 9999) { $jv += $j }
            }
            if ($sv.Count -eq 0) { $bad += $c; continue }
            # 12.7 : courbe commune mesuree sur une seule face a cette passe (l autre illisible) : valeur inchangee (celle de la
            # face lue), signalee sur la ligne de la passe et au bilan
            if ($heads.Count -gt 1 -and $miss.Count -eq 1) { $one += ,@([int]$c, [int]$miss[0]); $u.OneFace["$c|$($miss[0])"] = $true }
            $sh = ($sv | Measure-Object -Average).Average
            $se = [double]::NaN
            if (@($ev | Where-Object { [double]::IsNaN([double]$_) }).Count -eq 0) { $q = 0.0; foreach ($x in $ev) { $q += $x * $x }; $se = [math]::Sqrt($q) / $ev.Count }
            $jt = if ($jv.Count -gt 0) { ($jv | Measure-Object -Average).Average } else { [double]::NaN }
            $meas = @{ Shift = $sh; SE = $se; Score = $jt }
            switch ($cal.Stage) {
                'coarse'  { Add-CalibPoint $u.Results[[int]$c] ([int]$cal.Value) $meas }
                'bracket' { Add-CalibPoint $u.Results[[int]$c] ([int]$u.Bracket[[int]$c]) $meas }
                'densify' { Add-CalibPoint $u.Results[[int]$c] ([int]$u.Dense[[int]$c]) $meas }
                'level'   { Add-CalibPoint $u.Results[[int]$c] ([int]$u.LTarget[[int]$c]) $meas }
                default   { $u.Verify[[int]$c] = $meas; $u.VerifyP[[int]$c] = Get-SpecValue $u.Profile ([int]$c) }
            }
            # 12.7 : mesures des passes de mesure gardees par face (comparaison de deux calibrations, Get-FaceEstimates) ;
            # sans effet sur la courbe
            $xw = $null
            if ($cal.Stage -eq 'coarse') { $xw = [int]$cal.Value } elseif ($cal.Stage -eq 'bracket') { $xw = [int]$u.Bracket[[int]$c] } elseif ($cal.Stage -eq 'densify') { $xw = [int]$u.Dense[[int]$c] }
            if ($null -ne $xw) {
                foreach ($h in @($fm.Keys)) {
                    if (-not $u.Face.ContainsKey($h)) { $u.Face[$h] = @{} }
                    if (-not $u.Face[$h].ContainsKey([int]$c)) { $u.Face[$h][[int]$c] = @{} }
                    Add-CalibPoint $u.Face[$h][[int]$c] $xw @{ Shift = [double]$fm[$h].Shift; SE = $fm[$h].SE; Score = [double]::NaN }
                }
            }
            $shifts += $sh; if (-not [double]::IsNaN($jt)) { $scores += $jt }
        }
        if ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.Witness).Count -gt 0) {
            foreach ($c in @($u.Witness)) {
                $ci = [int]$c
                if ($u.Verify.ContainsKey($ci) -or -not $u.VerifyPrev.ContainsKey($ci)) { continue }
                $u.Verify[$ci] = $u.VerifyPrev[$ci].Meas; $u.VerifyP[$ci] = [int]$u.VerifyPrev[$ci].P
                [void]$u.VerifyPrev.Remove($ci); [void]$u.ReadLast.Remove($ci)
                $u.VerifyList = @(@($u.VerifyList) | Where-Object { [int]$_ -ne $ci })
            }
        }
        $badTxt = if ($bad.Count -gt 0) { ((T ", illisibles : {0}") -f "$($bad -join ',')") } else { '' }
        $oneTxt = ''
        foreach ($hm in @($one | ForEach-Object { $_[1] } | Sort-Object -Unique)) { $oneTxt += (T ", mesurés sans la face {0} : {1}") -f "$hm", (Format-CylList ([int[]]@($one | Where-Object { $_[1] -eq $hm } | ForEach-Object { $_[0] }))) }
        if ($shifts.Count -gt 0) {
            $st = $shifts | Measure-Object -Average -Minimum -Maximum
            $scTxt = if ($scores.Count -gt 0) { "$([math]::Round(($scores | Measure-Object -Average).Average, 0))" } else { '-' }
            Append-Log ((T "  {0} : décalage résiduel moyen {1} ns (de {2} à {3}), score jitter moyen {4}, {5} cylindre(s){6}") -f "$($u.Prefix)$($cal.ValueTxt)", (Format-LevelNum $st.Average), (Format-LevelNum $st.Minimum), (Format-LevelNum $st.Maximum), "$scTxt", "$($shifts.Count)", "$badTxt$oneTxt")
        } elseif (($cal.Stage -ne 'bracket' -or $u.Bracket.Count -gt 0) -and ($cal.Stage -ne 'densify' -or $u.Dense.Count -gt 0) -and ($cal.Stage -ne 'verify' -or $null -eq $u.VerifyList -or @($u.VerifyList).Count -gt 0)) {
            Append-Log ((T "  {0} : aucun cylindre mesurable{1}") -f "$($u.Prefix)$($cal.ValueTxt)", "$badTxt$oneTxt")
        }
    }
    if ($cal.Stage -eq 'level') { Invoke-LevelStep $cal $tracks; return }
    if ($cal.Stage -eq 'coarse') {
        # 12.7 : controle de surface de la disquette de calibration sur la relecture de la passe 1 (motif ecrit a 0 ns, 3 tours),
        # avec la vitesse du lecteur et la densite relue : bilan au journal a chaque calibration. Defaut grossier
        # (arbitrage 1) : fenetre sans compte a rebours (Show-CalibSurface) ; disquette douteuse sans defaut grossier :
        # reserve de la fenetre de decision (Complete-PrecompCalib), sans fenetre pendant la calibration
        if ([int]$cal.Index -eq 0 -and -not $cal.SurfDone) {
            $cal.SurfDone = $true
            $std = ([string]$cal.Mode -eq 'std')
            $rpm = if ($cal.Rpm) { [int]$cal.Rpm } else { 300 }
            $sf = Get-CalibSurface $tracks ([int[]]$cal.Cyls)
            $mc = Get-CalibMediumCheck $tracks ([int[]]$cal.Cyls) ([int]$cal.PatternBits) $rpm
            $gross = Test-CalibSurfaceGross $sf $mc
            $cal.Surf = $sf; $cal.Medium = $mc; $cal.SurfGross = $gross
            # Format-CalibSurfaceLog rend son tableau de lignes protege (operateur virgule) : pas de @() autour
            foreach ($l in (Format-CalibSurfaceLog $sf $std $(if ($gross) { 'none' } else { 'reserve' }))) { Append-Log $l }
            if ($mc.Log) { Append-Log $mc.Log }
            # Haute densite : decalage hors de la plage de mesure a la premiere passe (addendum HD de la 12.7)
            $hdFam = (@('hd', 'hd360') -contains [string]$cal.Family)
            if ($hdFam) {
                $lim = $script:CalHdShiftCells * 60000000000.0 / ([double]$rpm * [double]$cal.PatternBits)
                $oc = @()
                foreach ($c in $cal.Cyls) { foreach ($h in 0, 1) { $tn = [int]$c * 2 + $h; if ($tracks.ContainsKey($tn)) { $m = Get-CalibTrackMeasure $tracks[$tn]; if ($m -and [math]::Abs([double]$m.Shift) -gt $lim) { $oc += [int]$c } } } }
                if ($oc.Count) { Append-Log ((T "Haute densité : décalage de plus de {0} ns à la première passe (précompensation nulle) aux cylindres {1} : la mesure y sort de sa plage de validité (0,2 cellule) et sous-estime le besoin, qui dépasse probablement la borne de {2} ns.") -f (Format-UiNum $lim '0'), (Format-CylList ([int[]]@($oc | Sort-Object -Unique))), "$($script:CalHardNs)") }
            }
            if ($gross) {
                # 12.7 : defaut de vitesse seul : lecteur en cause, pas la disquette (Test-CalibSpeedOnly)
                $spd = Test-CalibSpeedOnly $sf $mc
                $notes = @()
                if ($mc.Rot) { $notes += (T "Vitesse du lecteur différente de celle du type de disquette : un format à 300 tr/min demande un lecteur à 300 tr/min (3,5 pouces, ou 5,25 pouces double densité), un format à 360 tr/min un lecteur à 360 tr/min (5,25 pouces haute densité, ou 3,5 pouces réglé à 360 tr/min). Changer de disquette n'y change rien.") }
                if ($hdFam -and -not $spd) { $notes += (T "En haute densité, ce résultat vient le plus souvent d'une disquette double densité (sans trou de densité), d'un lecteur sans mode haute densité, ou d'un lecteur resté en double densité (option « Densel » de l'onglet Écriture, pour un lecteur qui suit la broche 2). Utilisez une disquette haute densité sacrifiée dans un lecteur haute densité.") }
                if ($spd) { Append-Log ((T 'Contrôle de vitesse et de densité : {0} : décision demandée.') -f (Format-CalibSurfaceVerdict $sf $mc)) }
                else { Append-Log ((T "Contrôle de surface : disquette de calibration douteuse ({0}) : décision demandée.") -f (Format-CalibSurfaceVerdict $sf $mc)) }
                $redo = [bool]($script:CalRedo -and $script:CalRedo.Stage -eq 'running')
                $opt = Get-CalibSurfaceOptions ([bool]$script:Restore) $redo ($script:AfterCalib -eq 'write') ([bool]$cal.Swap)
                if ($spd) { $opt.Speed = $true; $opt.Change = $false; $opt.SwapBox = $false }
                $txt = Get-CalibSurfaceText $sf $opt $std ([bool]$cal.AutoStart) -Extra @($mc.Lines) -Notes @($notes) -Medium $mc -Hd $hdFam
                $cal.Hold = $true; Update-CalibProgress; if ($cal.Home) { Update-HomeCalibCard }
                if ($script:Restore) { $script:Restore.InCall = $true }
                try { $ch = Show-CalibSurface $opt $txt }
                finally { $cal.Hold = $false; if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
                if ($ch.Choice -eq 'change') { Restart-PrecompCalib $cal ([bool]$ch.Swap); return }
                if ($ch.Choice -eq 'stop') {
                    if ($redo) { $script:CalRedo.Why = $(if ($spd) { (T 'vitesse du lecteur différente de celle du type de disquette') } else { (T 'disquette B défectueuse au contrôle de surface') }) }
                    Append-Log (T "Contrôle de surface : calibration arrêtée à votre demande, rien de plus n'est écrit.")
                    Stop-PrecompCalib; return
                }
                $cal.SurfKept = $true
                Append-Log (T 'Contrôle de surface : calibration poursuivie sur cette disquette à votre demande.')
            }
        }
        $cal.Index++
        if ($cal.Index -lt $cal.Values.Count) { New-CalibPass; return }
        foreach ($u in $cal.Units) {
            if (-not (Set-CalibEstimates $u)) { $cal.TotalPasses = $cal.PassesDone; Complete-PrecompCalib; return }
        }
        # Encadrement : un cylindre encore sous-compense a la plus forte valeur mesuree a un zero extrapole, peu sur (la
        # pente varie hors de la plage mesuree) : une passe le mesure a son estimation + marge pour l encadrer, au plus au
        # plafond des passes de mesure (CalMaxNs) ; au-dela, zero extrapole de ces mesures, ecrit puis mesure par la verification.
        $cal.MaxCoarse = [int](@($script:CalCoarse) | Measure-Object -Maximum).Maximum
        $need = $false
        foreach ($u in $cal.Units) {
            $u.Bracket = @{}
            foreach ($c in @($u.Est.Keys)) {
                $pts = $u.Results[[int]$c]
                $top = [int](@($pts.Keys | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum
                if ($u.Kind[[int]$c] -ne 'interp' -and [double]$pts[$top].Shift -gt 0 -and $top -lt $script:CalMaxNs) {
                    $u.Bracket[[int]$c] = [int][math]::Min($script:CalMaxNs, [math]::Max($top + $script:CalBracketStep, [math]::Round([double]$u.Est[[int]$c] + $script:CalBracketMargin)))
                    $need = $true
                }
            }
        }
        if ($need) { $cal.Stage = 'bracket'; $cal.TotalPasses++; New-CalibPass; return }
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'bracket') {
        foreach ($u in $cal.Units) { if ($u.Bracket.Count -gt 0) { [void](Set-CalibEstimates $u (T 'Après encadrement : ')) } }
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'densify') {
        if ($cal.DensePass -eq 'A') { Set-CalibDenseB $cal; $cal.DensePass = 'B'; New-CalibPass; return }
        foreach ($u in $cal.Units) { [void](Set-CalibEstimates $u (T 'Après mesures complémentaires : ')) }
        Start-CalibFit $cal; return
    }
    # Verification : la mesure au profil applique devient un point de plus pour chaque cylindre verifie ; l estimation
    # est recalculee (en general encadree, donc interpolee avec la pente locale). Correction locale de la courbe aux
    # cylindres hors tolerance (estimation - valeur appliquee), interpolee entre cylindres verifies, lissage croissant.
    # Ecriture lente : chaque tete est corrigee d apres sa propre mesure ; une nouvelle passe reverifie les deux.
    $again = $false
    foreach ($u in $cal.Units) {
        # 12.8 (lot 1b) : apres la passe du nouvel essai, unites non concernees laissees telles quelles
        if ([int]$cal.Retests -gt 0 -and -not $u.InRetest) { continue }
        # Points de la passe : seulement les cylindres relus a cette passe (verification ciblee : VerifyList)
        $readNow = if ($null -ne $u.VerifyList) { @(@($u.VerifyList) | Where-Object { @($u.Witness) -notcontains [int]$_ }) } else { @($u.Verify.Keys | ForEach-Object { [int]$_ }) }
        foreach ($c in @($u.Verify.Keys)) { if ($readNow -contains [int]$c) { Add-CalibPoint $u.Results[[int]$c] ([int]$u.VerifyP[[int]$c]) $u.Verify[$c] } }
        [void](Set-CalibEstimates $u ((T "Vérification {0} : ") -f "$($cal.VerifyCount)"))
        $u.VerifyList = @()
        $corr = 0; $delta = @{}
        $fl = Get-ResidualFlags $u           # residus retenus : ecart regional, marche au bord, residu tres grand ou cylindre epars (pas un ecart local)
        foreach ($c in @($u.Verify.Keys)) {
            if (@($u.Outliers) -contains [int]$c) { continue }              # point isole : la courbe ne le suit pas
            $d = 0.0
            if ($fl.Bad.ContainsKey([int]$c) -and $u.Est.ContainsKey([int]$c)) {
                $d = [double]$u.Est[[int]$c] - (Get-SpecValue $u.Profile ([int]$c))
                if ([math]::Abs($d) -ge 0.5) { $corr++ } else { $d = 0.0 }
            }
            $delta[[int]$c] = $d
        }
        # 12.8 (lot 1b) : aucune correction apres la passe du nouvel essai : jugement final
        if ($corr -eq 0 -or $cal.VerifyCount -ge $script:CalMaxVerify -or [int]$cal.Retests -gt 0) { continue }
        # Courbe monotone par segments : pres d un changement de sens, les mesures des premieres passes (cylindres ecrits
        # seuls, loin du zero) et celles de la verification (profil complet ecrit dans l ordre, comme l image) peuvent
        # differer bien au-dela de leur incertitude. Une correction par l estimation combinee, dans des segments figes,
        # fondrait alors le sommet et ses voisins en palier (PAVA). La courbe est reajustee sur les zeros locaux de la
        # verification : precomp appliquee - residu / pente, mesures prises au plus pres du zero et dans les conditions
        # de l ecriture ; les changements de sens peuvent se deplacer.
        if (@($u.Fit.Breaks).Count -gt 0) {
            $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
            $zv = @{}; $zs = @{}
            foreach ($c in @($u.Verify.Keys)) {
                $ci = [int]$c
                if (@($u.Outliers) -contains $ci -or -not $u.VerifyP.ContainsKey($ci)) { continue }
                $zv[$ci] = [math]::Max(0.0, [math]::Min([double]$script:CalHardNs, [double]$u.VerifyP[$ci] - [double]$u.Verify[$c].Shift / $sl))
                $se = $u.Verify[$c].SE
                $zs[$ci] = if ($null -ne $se -and -not [double]::IsNaN([double]$se)) { [math]::Max(1.0, [double]$se / [math]::Abs($sl)) } else { 2.0 }
            }
            $re = $null
            if ($zv.Count -ge 4) { $re = Fit-PrecompCurve $zv $zs $cal.MaxCyl $null ($cal.Mode -eq 'fine' -or [bool]$cal.Densified) }
            if ($re -and @($re.Breaks).Count -gt 0) {
                # Forme reajustee, puis ancrage dans les nouveaux segments : un cylindre dans la tolerance garde sa valeur
                # appliquee (pas de reecriture inutile), un cylindre hors tolerance va a son zero mesure
                $dz = @{}
                foreach ($ci in @($zv.Keys)) {
                    $inTol = -not $fl.Bad.ContainsKey($ci)
                    $target = if ($inTol) { [double]$u.VerifyP[$ci] } else { [double]$zv[$ci] }
                    $dz[$ci] = $target - [double]$re.Values[$ci]
                }
                $re.Values = Add-CurveCorrection $re.Values $dz $re.Segs
                $newProfile = Build-CurveProfile $re.Values
                if ($newProfile -eq $u.Profile) { continue }
                $oldB = (@($u.Fit.Breaks) | ForEach-Object { "c$_" }) -join '/'
                $newB = (@($re.Breaks) | ForEach-Object { "c$_" }) -join '/'
                $u.Fit = @{ Model = 'seg+c'; A = $null; B = $null; Chi = $re.Chi; Values = $re.Values; Breaks = $re.Breaks; Segs = $re.Segs; Outliers = $u.Fit.Outliers }
                $u.Profile = $newProfile
                $bTxt = if ($oldB -ne $newB) { (T "changement de sens déplacé de {0} à {1}") -f "$oldB", "$newB" } else { (T "changements de sens {0}") -f "$newB" }
                Append-Log ($u.Prefix + ((T "Vérification : {0} cylindre(s) hors tolérance, courbe réajustée sur les zéros mesurés par la vérification ({1}) : {2}") -f "$corr", "$bTxt", "$($u.Profile)"))
                $u.VerifyList = @($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt @($re.Values).Count -and (-not $u.VerifyP.ContainsKey($_) -or [int]$re.Values[$_] -ne [int]$u.VerifyP[$_]) } | Sort-Object)
                Add-DriftWitnesses $u
                if ($u.VerifyList.Count -gt 0) { $again = $true }
                continue
            }
        }
        $newVals = Add-CurveCorrection $u.Fit.Values $delta $u.Fit.Segs
        $newProfile = Build-CurveProfile $newVals
        if ($newProfile -eq $u.Profile) { continue }
        $base = ([string]$u.Fit.Model) -replace '\+c$', ''
        $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
        $u.Profile = $newProfile
        Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}") -f "$corr", "$($u.Profile)"))
        # Verification suivante ciblee : cylindres estimes dont la valeur appliquee change (au moins 1 ns)
        $u.VerifyList = @($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt $newVals.Count -and (-not $u.VerifyP.ContainsKey($_) -or [int]$newVals[$_] -ne [int]$u.VerifyP[$_]) } | Sort-Object)
        Add-DriftWitnesses $u
        if ($u.VerifyList.Count -gt 0) { $again = $true }
    }
    if ($again) {
        $cal.VerifyCount++
        New-CalibPass; return
    }
    # 12.8 (lot 1b) : cylindres encore non converges sans cause exclue : une passe de nouvel essai au plus, puis jugement
    # final (Start-CalibRetest). Sans cylindre non converge, rien ne change
    if (Start-CalibRetest $cal) { return }
    # Derniere verification : zones aux verifications contradictoires ramenees a la mediane (sans nouvelle passe)
    foreach ($u in $cal.Units) { [void](Set-VerifyContra $u) }
    $cal.TotalPasses = $cal.PassesDone
    Complete-PrecompCalib
}

function Get-CalibRetestPlan($cal) {
    # 12.8 (lot 1b, decisions128.md) : plan du nouvel essai automatique apres la derniere verification, sans rien modifier.
    # Par unite, cylindres non converges (Get-CalibWarnings : NonConvC, residu juge NonConvR) dont la cause n est pas
    # exclue. Causes exclues pour toute l unite : disquette douteuse au controle de surface de la premiere passe (reserve
    # « support » ; defaut de vitesse seul : non), derive du lecteur forte (au-dela de 2 tolerances, reserve « derive »)
    # ou non retiree (verification ciblee sans assez de temoins), zone non reproductible (Contra), cylindres non
    # reproductibles. Pour un cylindre : valeur visee au plafond (CalHardNs) ou au plancher (0), ou piste deja ecrite le
    # nombre de fois annonce par l avertissement (WriteMax, maximum de la 12.7 : le nouvel essai ne le releve pas).
    # Valeur visee : zero de la mesure jugee, valeur ecrite - residu juge / pente de l unite (residu juge : derive retiree,
    # temoin sur sa mesure precedente, comme Get-CalibWarnings), bornee par les cylindres verifies non vises voisins dans le
    # sens du segment ; cylindre « non relu » : relu a sa valeur. Courbe corrigee comme a la verification
    # (Add-CurveCorrection : 0 aux autres cylindres verifies, monotonie par segments). Relus :
    # cylindres vises, leurs voisins immediats parmi les cylindres mesures (hors points isoles) et les cylindres dont la
    # valeur change ; temoins de derive ajoutes par Start-CalibRetest (Add-DriftWitnesses).
    # Renvoie @{ Go ; Skip } : plans @{ U ; NonConv ; Targets ; Why ; Values ; Profile ; List ; Corr } (Skip : NonConv, Why).
    $go = @(); $skip = @()
    $surf = [bool](($cal.SurfKept -and $cal.Surf -and -not (Test-CalibSpeedOnly $cal.Surf $cal.Medium)) -or ($cal.Surf -and $cal.Surf.Defective -and -not $cal.SurfGross))
    $wmax = [int]$cal.WriteMax
    foreach ($u in @($cal.Units)) {
        if (-not $u.Fit -or -not $u.Profile) { continue }
        $w = Get-CalibWarnings $u ([int]$cal.MaxCyl)
        $nc = [int[]]@(@($w.NonConvC) | Where-Object { $null -ne $_ })
        if ($nc.Count -eq 0) { continue }
        $p = @{ U = $u; NonConv = $nc; Targets = @(); Why = ''; Values = $null; Profile = ''; List = @(); Corr = 0 }
        $dft = $w.Drift
        if ($surf) { $p.Why = (T 'disquette de calibration douteuse au contrôle de surface') }
        elseif ($dft.Use -and [math]::Abs([double]$dft.D) -gt 2.0 * [double]$script:CalResidual) { $p.Why = (T 'forte dérive du lecteur entre deux vérifications ({0} ns)') -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D) }
        elseif (-not $dft.Use -and $u.VerifyPrev -and $u.VerifyPrev.Count -gt 0) { $p.Why = (T 'dérive du lecteur non retirée (témoins insuffisants)') }
        elseif (@(@($w.Contra) | Where-Object { $null -ne $_ }).Count -gt 0) { $p.Why = (T "zone non reproductible d'une vérification à l'autre") }
        elseif (@($w.NonRepro).Count -gt 0) { $p.Why = (T "cylindres non reproductibles d'une vérification à l'autre") }
        if ($p.Why) { $skip += $p; continue }
        $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
        $vals = @($u.Fit.Values)
        $delta = @{}
        foreach ($k in @($u.Verify.Keys)) { $c = [int]$k; if (@($u.Outliers) -notcontains $c -and $c -lt $vals.Count) { $delta[$c] = 0.0 } }
        $lim = @(); $full = @()
        foreach ($c in $nc) {
            if ($c -ge $vals.Count) { continue }
            if ($wmax -gt 0 -and $null -ne $u.Writes -and 1 + [int]$u.Writes[$c] -gt $wmax) { $full += $c; continue }
            if ($w.NonConvR -and $w.NonConvR.ContainsKey($c)) {
                $r = [double]$w.NonConvR[$c].R
                $z = [math]::Round([double]$w.NonConvR[$c].P - $r / $sl, 0)
                if (($r -gt 0 -and $z -ge [double]$script:CalHardNs) -or ($r -lt 0 -and $z -le 0)) { $lim += $c; continue }
                $delta[$c] = $z - [double]$vals[$c]
            } else { $delta[$c] = 0.0 }               # non relu : relu a sa valeur
            $p.Targets += $c
        }
        $wTxt = (T 'pistes déjà écrites le nombre maximal de fois annoncé ({0})') -f "$wmax"
        $lTxt = (T 'précompensation visée hors de ses limites (0 ou {0} ns)') -f "$($script:CalHardNs)"
        if ($lim.Count) { $skip += @{ U = $u; NonConv = [int[]]$lim; Why = $lTxt } }
        if ($full.Count) { $skip += @{ U = $u; NonConv = [int[]]$full; Why = $wTxt } }
        if ($p.Targets.Count -eq 0) { continue }
        # Valeur visee bornee par les cylindres verifies non vises les plus proches dans son segment, dans le sens du segment
        # (points fixes, meme regle que Set-VerifyContra) : le lissage croissant ne deplace aucun cylindre deja juge, et un
        # besoin que la courbe monotone ne peut pas suivre reste non converge sans degrader ses voisins (derniere passe :
        # aucun cylindre deplace ne pourrait etre corrige ensuite)
        $segs = if ($u.Fit.Segs) { @($u.Fit.Segs) } else { @(@{ Lo = 0; Hi = $vals.Count - 1; Dir = 1 }) }
        $fix = @($delta.Keys | ForEach-Object { [int]$_ } | Where-Object { @($p.Targets) -notcontains $_ } | Sort-Object)
        foreach ($c in @($p.Targets)) {
            $sg = $null; foreach ($g in $segs) { if ($c -ge [int]$g.Lo -and $c -le [int]$g.Hi) { $sg = $g; break } }
            if (-not $sg) { continue }
            $t = [double]$vals[$c] + [double]$delta[$c]
            $fl = @($fix | Where-Object { $_ -ge [int]$sg.Lo -and $_ -lt $c }); $fr = @($fix | Where-Object { $_ -gt $c -and $_ -le [int]$sg.Hi })
            $a = if ($fl.Count) { [double]$vals[$fl[-1]] } else { $null }; $b = if ($fr.Count) { [double]$vals[$fr[0]] } else { $null }
            if ([int]$sg.Dir -lt 0) { $x = $a; $a = $b; $b = $x }
            if ($null -ne $a) { $t = [math]::Max($t, $a) }
            if ($null -ne $b) { $t = [math]::Min($t, $b) }
            $delta[$c] = $t - [double]$vals[$c]
        }
        $newVals = Add-CurveCorrection $u.Fit.Values $delta $u.Fit.Segs
        $p.Values = $newVals; $p.Profile = Build-CurveProfile $newVals
        $p.Corr = @($p.Targets | Where-Object { [int]$newVals[$_] -ne [int]$vals[$_] }).Count
        $cs = [int[]]@($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { @($u.Outliers) -notcontains $_ } | Sort-Object)
        $set = @{}
        foreach ($c in $p.Targets) {
            $set[[int]$c] = $true
            $i = [array]::IndexOf($cs, [int]$c)
            if ($i -gt 0) { $set[$cs[$i - 1]] = $true }
            if ($i -ge 0 -and $i + 1 -lt $cs.Count) { $set[$cs[$i + 1]] = $true }
        }
        $chg = @($u.Est.Keys | ForEach-Object { [int]$_ } | Where-Object { $_ -lt $newVals.Count -and (-not $u.VerifyP.ContainsKey($_) -or [int]$newVals[$_] -ne [int]$u.VerifyP[$_]) })
        foreach ($c in $chg) { $set[[int]$c] = $true }
        # Garde : un cylindre dont la valeur change doit etre relu ; voisin deja ecrit WriteMax fois : non relu
        $over = @($set.Keys | ForEach-Object { [int]$_ } | Where-Object { $wmax -gt 0 -and $null -ne $u.Writes -and 1 + [int]$u.Writes[$_] -gt $wmax })
        if (@($over | Where-Object { $chg -contains $_ }).Count -gt 0) { $skip += @{ U = $u; NonConv = [int[]]$p.Targets; Why = $wTxt }; continue }
        $p.List = [int[]]@($set.Keys | ForEach-Object { [int]$_ } | Where-Object { $over -notcontains $_ } | Sort-Object)
        $go += $p
    }
    return @{ Go = $go; Skip = $skip }
}

function Start-CalibRetest($cal) {
    # 12.8 (lot 1b) : nouvel essai automatique des cylindres non converges (Get-CalibRetestPlan), CalMaxRetest fois au plus :
    # passe de verification ciblee avec la correction tiree de la verification precedente, puis jugement final
    # (Invoke-CalibAnalysis, sans autre correction). Mesures des unites concernees ramenees au repere de leur jugement :
    # temoin juge sur sa mesure precedente, cylindre relu a la derniere verification derive retiree (residu brut garde dans
    # Raw : journal et courbe enregistree) ; la derive mesuree a la passe se compte depuis ce repere. Unites sans nouvel
    # essai : ni ecrites, ni relues, ni jugees a nouveau (InRetest). Le controle de surface reste celui de la premiere passe
    # (a6verify, synthese par. 44). Renvoie $true si la passe est lancee.
    if (-not $cal -or [int]$cal.Retests -ge [int]$script:CalMaxRetest) { return $false }
    $plan = Get-CalibRetestPlan $cal
    foreach ($p in @($plan.Skip)) { Append-Log ($p.U.Prefix + ((T "Calibration : pas de nouvel essai automatique des cylindres non convergés {0} : {1}.") -f (Format-CylList ([int[]]@($p.NonConv))), "$($p.Why)")) }
    if (@($plan.Go).Count -eq 0) { return $false }
    $cal.Retests = 1 + [int]$cal.Retests
    $vLast = [int]$cal.VerifyCount             # derniere verification avant le nouvel essai
    $cal.VerifyCount++
    $cal.TotalPasses = $cal.PassesDone + 1
    $lt = (@($plan.Go | ForEach-Object { "$($_.U.Prefix)$(Format-CylList ([int[]]@($_.Targets)))" })) -join ' ; '
    Append-Log ((T "Calibration : nouvel essai automatique des cylindres non convergés {0} (vérification {1})") -f "$lt", "$($cal.VerifyCount)")
    foreach ($u in @($cal.Units)) { $u.InRetest = $false; $u.VerifyList = @() }
    foreach ($p in @($plan.Go)) {
        $u = $p.U
        $dft = Get-VerifyDrift $u
        # Derive deja mesuree a la derniere verification (DriftBase, DriftBaseV) : celle du nouvel essai se compte depuis le
        # meme repere, cumulee ; la reserve « derive » de Complete-PrecompCalib juge le dernier intervalle seul. Sans derive
        # mesuree : aucune (chemins de la 12.7)
        $u.DriftBase = $null; $u.DriftBaseV = $null
        if ($dft.Use) { $u.DriftBase = [double]$dft.D; $u.DriftBaseV = $vLast }
        foreach ($k in @($u.Verify.Keys)) {
            $c = [int]$k
            # Temoin : jugement sur sa mesure precedente ; sa derniere mesure brute reste celle du journal (LogRaw, lu
            # seulement par la ligne « Residu apres verification » ; Res de la courbe : mesure precedente, comme en 12.7)
            if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $m = $u.VerifyPrev[$c].Meas.Clone(); $m.LogRaw = [double]$u.Verify[$c].Shift; $u.Verify[$c] = $m; $u.VerifyP[$c] = [int]$u.VerifyPrev[$c].P }
            elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $m = $u.Verify[$c]; $u.Verify[$c] = @{ Shift = [double]$m.Shift - [double]$dft.D; SE = $m.SE; Score = $m.Score; Raw = [double]$m.Shift } }
        }
        $u.VerifyPrev = @{}; $u.ReadLast = @{}; $u.Witness = @()
        if ($p.Profile -ne $u.Profile) {
            $base = ([string]$u.Fit.Model) -replace '\+c$', ''
            $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $p.Values; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
            $u.Profile = $p.Profile
            Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}") -f "$($p.Corr)", "$($u.Profile)"))
        }
        $u.VerifyList = @($p.List)
        Add-DriftWitnesses $u
        $u.InRetest = $true
    }
    New-CalibPass
    return $true
}

function Get-CalibDriftStep($u, $dft) {
    # 12.8 (lot 1b) : derive du lecteur du dernier intervalle entre deux verifications (ns de decalage), jugee par la
    # reserve « derive » de Complete-PrecompCalib (seuil fait pour un intervalle, comme l exclusion du nouvel essai). Apres
    # un nouvel essai, la derive mesuree (Get-VerifyDrift) se compte depuis le repere du jugement, cumulee : la part deja
    # mesuree a la derniere verification d avant le nouvel essai (DriftBase, Start-CalibRetest) en est retiree. Sans
    # DriftBase : derive mesuree telle quelle (12.7)
    if ($null -ne $u.DriftBase) { return [double]$dft.D - [double]$u.DriftBase }
    return [double]$dft.D
}

function Complete-PrecompCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Calibration terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    if (@($cal.Units | Where-Object { -not $_.Profile -or -not $_.Fit }).Count -gt 0) {
        Append-Log (T 'Calibration precomp : aucune mesure exploitable, profil inchangé.')
        Set-HomeProgDone $cal 'stop' (T 'Calibration precomp : aucune mesure exploitable, profil inchangé.')
        if ($script:AfterCalib) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : calibration sans mesure exploitable.') }
        if ($script:Restore) { Stop-Restore (T 'calibration sans mesure exploitable') }
        # 12.7 point 2 : calibration B sans mesure exploitable : decision sur la courbe A seule, ouverte tout de suite
        if ($script:CalRedo -and $script:CalRedo.Stage -eq 'running') { $script:CalRedo.Stage = 'interrupted'; $script:CalRedo.Why = (T 'aucune mesure exploitable'); Resume-CalibRedo }
        return
    }
    $famTxt = Get-CalibFamilyName $cal.Family
    $allConv = $true; $anySat = $false; $anyCeil = $false
    $issues = New-Object System.Collections.Generic.List[string]
    # 12.7 : nature de chaque reserve, tenue en parallele de $issues (drift, contra, contra-nodrift, nonconv, sat, floor,
    # dev, surface) : reserves liees au support (« Refaire sur une autre disquette », point 2)
    $kinds = New-Object System.Collections.Generic.List[string]
    foreach ($u in $cal.Units) {
        if ($u.Verify.Count -gt 0) {
            # 12.8 (lot 1b) : derniere mesure brute d une mesure ramenee au repere du jugement avant un nouvel essai (LogRaw :
            # temoin, Raw : cylindre relu, derive retiree)
            $resTxt = (@($u.Verify.Keys | Sort-Object | ForEach-Object { "c$_=$('{0:+0.0;-0.0;0.0}' -f $(if ($null -ne $u.Verify[$_].LogRaw) { [double]$u.Verify[$_].LogRaw } elseif ($null -ne $u.Verify[$_].Raw) { [double]$u.Verify[$_].Raw } else { [double]$u.Verify[$_].Shift }))" + $(if (@($u.Outliers) -contains [int]$_) { " ($(Get-KindName 'outlier'))" } else { '' }) })) -join ' '
            Append-Log ($u.Prefix + ((T "Résidu après vérification (ns, tolérance {0}, élargie à 3 erreurs-types si la mesure est plus bruitée) : {1}") -f "$($script:CalResidual)", "$resTxt"))
        }
        $u.Warn = Get-CalibWarnings $u $cal.MaxCyl
        $dft = $u.Warn.Drift
        if ($dft.Use) {
            $sla = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [math]::Abs([double]$u.Slope) } else { 2.0 }
            $dsp = if ([double]$dft.SRaw -ge 1.0) { "$(Format-LevelNum $dft.SRaw) ns" } else { (T 'moins de 1 ns') }
            # 12.8 (lot 1b) : apres un nouvel essai, derive comptee depuis le repere du jugement (DriftBase : part deja mesuree
            # a la derniere verification d avant le nouvel essai) ; $dIv : dernier intervalle seul, juge par la reserve
            $dIv = Get-CalibDriftStep $u $dft
            if ($null -ne $u.DriftBase) {
                $lt = (T "Dérive du lecteur depuis la vérification {0}, nouvel essai compris : {1} ± {2} ns de décalage commun sur {3} cylindres témoins (dispersion {4}), soit {5} ns jusqu'à la vérification {6}, puis {7} ns jusqu'à la vérification {8}.") -f "$([int]$u.DriftBaseV - 1)", ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp", ('{0:+0.0;-0.0;0.0}' -f [double]$u.DriftBase), "$([int]$u.DriftBaseV)", ('{0:+0.0;-0.0;0.0}' -f $dIv), "$($cal.VerifyCount)"
            }
            else { $lt = (T "Dérive du lecteur entre les deux vérifications : {0} ± {1} ns de décalage commun sur {2} cylindres témoins (dispersion {3}).") -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp" }
            $pdv = [math]::Round([math]::Abs([double]$dft.D) / $sla, 1); $pd = Format-LevelNum $pdv
            if ($pdv -le 0) { }
            elseif ([double]$dft.D -gt 0) { $lt += (T " Le besoin de précompensation était plus élevé de {0} ns à la dernière vérification.") -f "$pd" }
            elseif ([double]$dft.D -lt 0) { $lt += (T " Le besoin de précompensation était plus faible de {0} ns à la dernière vérification.") -f "$pd" }
            if ([int]$dft.NC -gt 0) { $lt += (T " Écart des cylindres corrigés à leur prédiction, dérive comprise : {0} ns en médiane sur {1}.") -f ('{0:+0.0;-0.0;0.0}' -f [double]$dft.DC), "$($dft.NC)" }
            $lt += (T " Les résidus des cylindres relus à la dernière vérification sont jugés sans ce décalage ; les témoins, inchangés, sur leur mesure précédente, sauf ceux d'un écart systématique, jugés sur leur relecture.")
            Append-Log ($u.Prefix + $lt)
            # Derive forte : retiree du jugement, mais signalee (lecteur ou support instable d une passe a l autre) ; seuil
            # fait pour un intervalle entre deux verifications (12.8 : le dernier, apres un nouvel essai)
            if ([math]::Abs($dIv) -gt 2.0 * [double]$script:CalResidual) { $issues.Add($u.Prefix + ((T "dérive du lecteur de {0} ns entre deux vérifications (lecteur ou support instable ?)") -f ('{0:+0.0;-0.0;0.0}' -f $dIv))); $kinds.Add('drift') }
        }
        elseif (@($u.Witness).Count -gt 0 -and $u.VerifyPrev.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Dérive du lecteur non mesurée : {0} témoin(s) exploitable(s) sur {1}, {2} au moins nécessaires ; résidus jugés sans correction de dérive, témoins sur leur mesure précédente.") -f "$($dft.NW)", "$(@($u.Witness).Count)", "$([int]$u.WitMin)"))
        }
        elseif (@($u.Witness).Count -eq 0 -and $u.VerifyPrev -and $u.VerifyPrev.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Dérive du lecteur non mesurée : {0} cylindre(s) non modifié(s) disponible(s) comme témoins, {1} au moins nécessaires ; résidus jugés sans correction de dérive.") -f "$([int]$u.WitCand)", "$([int]$u.WitMin)"))
        }
        # Zone non reproductible : verifications contradictoires, courbe a la mediane (Set-VerifyContra) ; liste de
        # Get-CalibWarnings (jamais un cylindre deja signale au plafond ou au plancher). Fenetre de decision si les deux
        # verifications s ecartent de plus de CalContraMaxNs, ou si la derive du lecteur n a pas ete mesuree (sans temoins,
        # une derive entre les deux verifications ne se distingue pas d une contradiction : l utilisateur tranche)
        $cn = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
        if ($cn.Count -gt 0) {
            $em = [double](@($cn | ForEach-Object { [double]$dft.Contra[$_].E }) | Measure-Object -Maximum).Maximum
            $cl = Format-CylList $cn
            Append-Log ($u.Prefix + ((T "Zone non reproductible d'une vérification à l'autre aux cylindres {0} : les deux vérifications placent le besoin de part et d'autre de la valeur écrite. La courbe y prend la médiane des passes de mesure et des deux vérifications, dans l'intervalle des deux valeurs écrites et sans dépasser les cylindres vérifiés voisins (écart entre les vérifications jusqu'à {1} ns de précompensation).") -f "$cl", (Format-LevelNum $em)))
            if ($em -gt [double]$script:CalContraMaxNs) { $issues.Add($u.Prefix + ((T "vérifications contradictoires aux cylindres {0} (écart jusqu'à {1} ns : lecteur ou support instable ?)") -f "$cl", (Format-LevelNum $em))); $kinds.Add('contra') }
            elseif (-not $dft.Use) { $issues.Add($u.Prefix + ((T "vérifications contradictoires aux cylindres {0} sans mesure de la dérive du lecteur (écart jusqu'à {1} ns : dérive du lecteur ou zone non reproductible ?)") -f "$cl", (Format-LevelNum $em))); $kinds.Add('contra-nodrift') }
        }
        # Filet du lissage de la zone : cylindre verifie hors zone deplace malgre tout (test standard : cylindre interpole
        # entre la zone et lui), sans nouvelle mesure ; son residu n est pas enregistre
        $mv = [int[]]@(@($u.ContraMoved) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
        if ($mv.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Cylindres vérifiés {0} déplacés par le lissage croissant de la courbe autour de la zone non reproductible, sans nouvelle mesure : leur résidu n'est pas enregistré avec la courbe.") -f (Format-CylList $mv)))
        }
        if (@($u.Warn.NonRepro).Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Cylindres non reproductibles d'une vérification à l'autre (zéro estimé à la pente commune par la vérification précédente, puis par la dernière, dérive retirée) : {0}. Ils ne comptent pas pour la convergence ; une nouvelle calibration peut leur donner une autre valeur.") -f (@($u.Warn.NonRepro) -join ', ')))
        }
        if (-not [double]::IsNaN([double]$u.Warn.Sigma)) {
            Append-Log ($u.Prefix + ((T "Bruit de mesure estimé : {0} ns, sur {1} écarts entre cylindres vérifiés distants de 2 au plus. Un écart est retenu si la moyenne des résidus voisins (2 cylindres au plus) dépasse {2} ns, si un résidu dépasse {3} ns, s'il s'étend sur 3 cylindres ou plus, ou 2 en bord de piste ou de segment, au-delà de {2} ns, ou s'il couvre 2 cylindres au-delà de {4} ns. Seuils relevés quand le bruit est fort. Un écart dont un cylindre a moins de 2 autres cylindres vérifiés à 2 cylindres au plus est retenu sur sa seule tolérance ; les points isolés et les cylindres au plafond ou au plancher ne comptent ni dans le bruit ni dans le voisinage, les cylindres non reproductibles ni dans le bruit ni dans les moyennes.") -f (Format-LevelNum $u.Warn.Sigma), "$($u.Warn.NDiff)", (Format-LevelNum $script:CalResidual), (Format-LevelNum $u.Warn.Hard), (Format-LevelNum $u.Warn.HardPair)))
        }
        if (@($u.Warn.Spot).Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Écarts locaux non retenus : {0}. Hors tolérance, mais sous les seuils ci-dessus : ces écarts ne sont pas corrigés.") -f (@($u.Warn.Spot) -join ', ')))
        }
        if ($u.Warn.NonConv.Count -gt 0) { $issues.Add($u.Prefix + ((T "non convergée aux cylindres {0}") -f ($u.Warn.NonConv -join ', '))); $kinds.Add('nonconv') }
        if ($u.Warn.Sat.Count -gt 0) { $issues.Add($u.Prefix + ((T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', '))); $kinds.Add('sat') }
        if ($u.Warn.Floor.Count -gt 0) { $issues.Add($u.Prefix + ((T "précompensation nulle encore excessive aux cylindres {0}") -f ($u.Warn.Floor -join ', '))); $kinds.Add('floor') }
        if ($u.Warn.Dev.Count -gt 0) { $issues.Add($u.Prefix + ((T "courbe éloignée des mesures (courbe moins mesure) : {0}") -f ($u.Warn.Dev -join ', '))); $kinds.Add('dev') }
        if ($u.Warn.NonConv.Count -gt 0) {
            $allConv = $false
            Append-Log ($u.Prefix + ((T "Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres. Refaire la calibration en test fin, ou sur une autre disquette sacrifiée.") -f ($u.Warn.NonConv -join ', ')))
        }
        if ($u.Warn.Sat.Count -gt 0) {
            $anySat = $true; $anyCeil = $true
            Append-Log ($u.Prefix + ((T "Plafond de {0} ns atteint aux cylindres {1} : le besoin dépasse la précompensation maximale, la courbe reste au plafond et une nouvelle calibration n'y changera rien. Si une disquette en bon état sature aussi, c'est le lecteur ; sinon, c'est le support, probablement fatigué.") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', ')))
        }
        if ($u.Warn.Floor.Count -gt 0) {
            $anySat = $true
            Append-Log ($u.Prefix + ((T "Précompensation nulle encore excessive aux cylindres {0} : la courbe reste à 0 ns et une nouvelle calibration n'y changera rien. La même mesure sur une autre disquette désigne le lecteur, sinon le support.") -f ($u.Warn.Floor -join ', ')))
        }
        if (@($u.Warn.Beyond).Count -gt 0) {
            # Courbe au-dela du plafond des passes de mesure : information (valeurs verifiees), sans fenetre de decision
            $anyCeil = $true
            $bmax = [int](@($u.Warn.Beyond | ForEach-Object { [int]$u.Fit.Values[$_] }) | Measure-Object -Maximum).Maximum
            $how = if ($u.Trend -and @($u.Trend.Keys).Count -gt 0) { (T ' et par la tendance de la courbe') } else { '' }
            Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe jusqu'à {2} ns, déduite par extrapolation des mesures{3}, puis contrôlée par la vérification. Un besoin aussi fort est inhabituel : si une disquette en bon état ne l'atteint pas, le support de calibration est probablement fatigué.") -f "$($script:CalMaxNs)", (Format-CylList ([int[]]$u.Warn.Beyond)), "$bmax", "$how"))
        }
        $bk = @($u.Warn.Breaks)
        if ($bk.Count -ge 2) { Append-Log ($u.Prefix + ((T "Changement de sens du besoin entre c{0} et c{1} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])", "$($bk[1])")) }
        elseif ($bk.Count -eq 1) { Append-Log ($u.Prefix + ((T "Le besoin redescend à partir de c{0} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])")) }
        if ($u.Warn.Dev.Count -gt 0) { Append-Log ($u.Prefix + ((T "Écart à la courbe de plus de {1} ns et de trois incertitudes (courbe moins mesure) : {0}.") -f ($u.Warn.Dev -join ', '), (Format-UiNum $script:CalDevNs))) }
        # Calibration precedente du meme lecteur (encore en memoire, remplacee plus bas) : la forme de la courbe tient au
        # lecteur, son niveau au support ; un ecart net, ou un plafond nouveau, designe le support de calibration
        $pkey = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $prev = $script:PrecompCurves[$pkey]
        if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and @($prev.Values).Count -gt 0 -and $u.Fit) {
            $pv = @($prev.Values); $nv = @($u.Fit.Values); $nn = [math]::Min($pv.Count, $nv.Count)
            if ($nn -gt 0) {
                $dd = @(for ($c = 0; $c -lt $nn; $c++) { [int]$nv[$c] - [int]$pv[$c] })
                $ds = $dd | Measure-Object -Average -Minimum -Maximum
                Append-Log ($u.Prefix + ((T "Écart avec la calibration précédente du lecteur {0} ({1}) : {2} ns en moyenne (de {3} à {4} ns).") -f "$($cal.Drive)", "$($prev.Date)", ('{0:+0;-0;0}' -f [math]::Round($ds.Average, 0)), ('{0:+0;-0;0}' -f $ds.Minimum), ('{0:+0;-0;0}' -f $ds.Maximum)))
                # Plafond de la courbe precedente : borne de SON calcul (300 ns avant le calcul 12.4)
                $pmax = [math]::Min((Get-CurveMaxNs $prev), [int]$script:CalHardNs)   # ramenee a la borne actuelle
                $ptop = [int](@($pv[0..($nn - 1)]) | Measure-Object -Maximum).Maximum
                if ($u.Warn.Sat.Count -gt 0 -and $ptop -lt $pmax) {
                    Append-Log ($u.Prefix + (T "Plafond atteint alors que la calibration précédente du même lecteur ne l'atteignait pas : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre)."))
                }
                # Besoin au-dela du plafond des mesures : signale seulement une hausse nette (plus de CalDevNs, 15 ns en double
                # densite, sur le maximum des cylindres communs), pas une courbe qui passe de 298 a 305 ns
                elseif (@($u.Warn.Beyond).Count -gt 0 -and $ptop -le $script:CalMaxNs -and $ptop -lt $pmax -and [int](@($nv[0..($nn - 1)]) | Measure-Object -Maximum).Maximum - $ptop -gt $script:CalDevNs) {
                    Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns alors que la calibration précédente du même lecteur ne dépassait pas cette valeur : support de calibration probablement fatigué (sinon têtes à nettoyer, ou autre lecteur sous la même lettre).") -f "$($script:CalMaxNs)"))
                }
            }
        }
        # Diagnostic de forme (calibration rapide) : sur les cylindres mesures par les deux calibrations, ecart de niveau
        # et ecart de forme (dispersion apres retrait du niveau) ; donnees pour recaler les seuils sur materiel reel
        if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and $prev.Cyls -and $prev.Ys) {
            $dd2 = @{}
            for ($i = 0; $i -lt @($prev.Cyls).Count; $i++) {
                $c = [int]$prev.Cyls[$i]
                $pk2 = if ($prev.Kinds -and $i -lt @($prev.Kinds).Count) { [string]$prev.Kinds[$i] } else { 'interp' }
                if ($pk2 -ne 'interp' -or -not $u.Est.ContainsKey($c) -or [string]$u.Kind[$c] -ne 'interp') { continue }
                $dd2[$c] = [double]$u.Est[$c] - [double]$prev.Ys[$i]
            }
            if ($dd2.Count -ge 4) {
                $mv = (@($dd2.Values) | Measure-Object -Average).Average
                $sdv = [math]::Sqrt((@($dd2.Values | ForEach-Object { [math]::Pow($_ - $mv, 2) }) | Measure-Object -Sum).Sum / ($dd2.Count - 1))
                $wc = @($dd2.Keys | Sort-Object { -[math]::Abs($dd2[$_] - $mv) })[0]
                Append-Log ($u.Prefix + ((T "Forme comparée à la calibration précédente du lecteur {0} ({1}), sur {2} cylindres mesurés par les deux : niveau {3} ns, écart de forme {4} ns (au plus {5} ns, à c{6}).") -f "$($cal.Drive)", "$($prev.Date)", "$($dd2.Count)", ('{0:+0;-0;0}' -f [math]::Round($mv, 0)), ('{0:0.#}' -f [math]::Round($sdv, 1)), ('{0:+0;-0;0}' -f [math]::Round($dd2[$wc] - $mv, 0)), "$wc"))
            }
        }
        # 12.7 : courbe commune mesuree sur une seule face a au moins une passe (valeur de l autre face, ecart des tetes non compense)
        if ($null -eq $u.Head -and $u.OneFace -and $u.OneFace.Count -gt 0) {
            foreach ($hm in 0, 1) {
                $oc = [int[]]@(@($u.OneFace.Keys) | Where-Object { $_ -like "*|$hm" } | ForEach-Object { [int](($_ -split '\|')[0]) } | Sort-Object -Unique)
                if ($oc.Count) { Append-Log ($u.Prefix + ((T "Cylindres mesurés sans la face {0} à au moins une passe : {1}. En courbe commune, leur valeur vient de l'autre face seule : l'écart entre les têtes n'y est pas compensé. Refaire la calibration en écriture lente (une courbe par tête), ou sur une autre disquette.") -f "$hm", (Format-CylList $oc))) }
            }
        }
        if ($u.Warn.Extrap.Count + $u.Warn.Cap.Count -gt 0) {
            Append-Log ($u.Prefix + ((T "Valeurs peu fiables : {0} extrapolée(s) au-delà des mesures ({1}), {2} plafonnée(s) à 0 ou {3} ns ({4}).") -f "$($u.Warn.Extrap.Count)", ($(if ($u.Warn.Extrap.Count) { $u.Warn.Extrap -join ',' } else { '-' })), "$($u.Warn.Cap.Count)", "$($script:CalHardNs)", ($(if ($u.Warn.Cap.Count) { $u.Warn.Cap -join ',' } else { '-' }))))
        }
    }
    # 12.7 : controle de surface de la passe 1. Defaut grossier, calibration poursuivie a la demande de l utilisateur :
    # journal, et reserve si la fenetre de decision s ouvre pour une autre raison. Disquette douteuse sans defaut grossier
    # (arbitrage 1) : reserve « support », qui ouvre la fenetre de decision
    # Defaut de vitesse seul (Test-CalibSpeedOnly) : bilan et reserve qui nomment le lecteur, reserve 'speed' (pas liee au
    # support : pas de « Refaire sur une autre disquette » pour elle seule). $surfIssue : bilan de l Accueil
    $surfIssue = ''
    if ($cal.SurfKept -and $cal.Surf) {
        $st = Format-CalibSurfaceVerdict $cal.Surf $cal.Medium
        if (Test-CalibSpeedOnly $cal.Surf $cal.Medium) {
            Append-Log ((T 'Contrôle de vitesse et de densité de la première passe : {0} ; calibration poursuivie à votre demande : la courbe a été mesurée avec un lecteur qui ne tourne pas à la vitesse de ce type de disquette.') -f "$st")
            $surfIssue = (T 'contrôle de vitesse et de densité : {0}, calibration poursuivie à votre demande') -f "$st"; $surfKind = 'speed'
        } else {
            Append-Log ((T "Contrôle de surface de la première passe : disquette jugée douteuse ({0}), calibration poursuivie à votre demande : la courbe peut refléter ce support plutôt que le lecteur.") -f "$st")
            $surfIssue = (T "contrôle de surface : disquette de calibration douteuse ({0}), calibration poursuivie à votre demande") -f "$st"; $surfKind = 'surface'
        }
        if ($issues.Count -gt 0) { $issues.Add($surfIssue); $kinds.Add($surfKind) }
    }
    elseif ($cal.Surf -and $cal.Surf.Defective -and -not $cal.SurfGross) { $issues.Add((Format-CalibSurfaceReserve $cal.Surf)); $kinds.Add('surface') }
    if ($anyCeil -and $cal.Swap) { Append-Log ((T "Calibration faite sur une disquette sacrifiée dont le besoin dépasse {0} ns : si elle est fatiguée, la courbe surestime le besoin de la disquette à écrire. Préférez une disquette sacrifiée en bon état.") -f "$($script:CalMaxNs)") }
    # Etat precedent (courbes et profils remplaces ci-dessous) : retabli si l utilisateur refuse un resultat douteux
    $prevCal = Get-CalibSnapshot @($cal.Units | ForEach-Object { Get-CalibUnitKey $cal $_ })
    # Profil commun : remplace celui de la famille. Ecriture lente : courbes par tete, le profil commun est conserve.
    if (-not $cal.Slow) {
        $spec = $cal.Units[0].Profile
        # 12.7 : haute densite : profil tire de sa courbe commune (Get-HdProfile), aucun profil de famille a remplacer
        if ($cal.Family -eq 'long') { $script:PrecompLong = $spec } elseif ([string]$cal.Family -ne 'hd') { $script:PrecompStd = $spec }
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        $maxX = 0
        foreach ($c in $cs) { foreach ($x in @($u.Results[$c].Keys)) { if ([int]$x -gt $maxX) { $maxX = [int]$x } } }
        $script:PrecompCurves[$key] = @{
            Family = $famTxt; Head = $u.Head; Drive = $cal.Drive; Date = $date; Model = $u.Fit.Model; Spec = $u.Profile; Method = 'motif'
            Version = $script:Version; Algo = $script:CalibAlgo; Calc = $(if ([string]$cal.Family -eq 'hd') { $script:CalibCalcHd } else { $script:CalibCalc }); Breaks = [int[]]@($u.Fit.Breaks)
            Values = [int[]]@($u.Fit.Values); Cyls = [int[]]$cs
            Ys = [double[]]@($cs | ForEach-Object { [math]::Round([double]$u.Est[$_], 1) })
            Sig = [double[]]@($cs | ForEach-Object { [math]::Round($(if ($u.Sig.ContainsKey($_)) { [double]$u.Sig[$_] } else { 5.0 }), 1) })
            Kinds = [string[]]@($cs | ForEach-Object { [string]$u.Kind[$_] })
            Res = [double[]]@($cs | ForEach-Object { if (@($u.Warn.Contra) -contains $_ -or @($u.ContraMoved) -contains $_) { [double]::NaN } elseif (@($u.Witness) -contains $_ -and $u.VerifyPrev.ContainsKey($_) -and -not $u.Warn.Drift.Sys.ContainsKey($_)) { [math]::Round($(if ($u.VerifyPrev[$_].Meas -and $null -ne $u.VerifyPrev[$_].Meas.Raw) { [double]$u.VerifyPrev[$_].Meas.Raw } else { [double]$u.VerifyPrev[$_].Shift }), 1) } elseif ($u.Verify.ContainsKey($_)) { [math]::Round($(if ($null -ne $u.Verify[$_].Raw) { [double]$u.Verify[$_].Raw } else { [double]$u.Verify[$_].Shift }), 1) } else { [double]::NaN } })
            Converged = ($u.Warn.NonConv.Count -eq 0); MaxX = $maxX; MaxNs = [int]$script:CalHardNs
            Contra = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
            Slope =$(if ($null -ne $u.Slope) { [math]::Round([double]$u.Slope, 3) } else { $null }); Bits = [int]$cal.PatternBits; Test = [string]$cal.Mode
        }
    }
    # Nouvelle reference de forme : les niveaux mesures avec la precedente sont abandonnes
    $dropped = @()
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        foreach ($k in @($script:LevelShifts.Keys)) { if ($script:LevelShifts[$k] -and $script:LevelShifts[$k].RefKey -eq $key) { $script:LevelShifts.Remove($k); $dropped += $key } }
    }
    if ($dropped.Count -gt 0) { Append-Log ((T "Nouvelle référence de forme ({0}) : les niveaux mesurés avec la précédente sont abandonnés.") -f ((@($dropped | Sort-Object -Unique | ForEach-Object { Get-CurveKeyLabel $_ })) -join ', ')) }
    # Auto : applique le profil de la famille de l image ; carte Calibration de l Accueil : profil choisi dans l onglet
    # Ecriture respecte (Manuel compris), libelle du profil seulement pour une image de l onglet de la famille calibree
    if (-not $cal.Home) { $cmbWProfile.SelectedIndex = 0 }
    Update-PrecompForImage $txtWFile.Text
    $convTxt = if (-not $allConv) { (T ' NON CONVERGÉE : voir le journal et la fenêtre Courbe.') } elseif ($anySat) { ((T ' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.') -f "$($script:CalHardNs)") } else { '' }
    $showLbl = (-not $cal.Home) -or ($cmbWProfile.SelectedIndex -eq 0 -and (Get-WriteTabFamily) -eq $cal.Family)
    if ($showLbl -and $cal.Slow) {
        $v0 = @($cal.Units[0].Fit.Values); $v1 = @($cal.Units[1].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profils {0} par tête calibrés le {1} sur le lecteur {2} : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($v0[0])", "$($v0[-1])", "$($v1[0])", "$($v1[-1])") + $convTxt
    } elseif ($showLbl) {
        $v = @($cal.Units[0].Fit.Values)
        $lblWProfileInfo.Text = ((T "Profil {0} calibré le {1} sur le lecteur {2} : courbe {3}, de {4} à {5} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", (Get-CurveModelName $cal.Units[0].Fit.Model), "$($v[0])", "$($v[-1])") + $convTxt
    }
    if ($convTxt) { $lblWCal.Text += $convTxt }
    foreach ($u in $cal.Units) {
        Append-Log ($u.Prefix + ((T "Calibration terminée : profil {0} = {1}") -f "$famTxt", "$($u.Profile)"))
        $v = @($u.Fit.Values)
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $hi = [math]::Min($v.Count - 1, $c0 + 9)
            $line = ((T "  Précomp cylindres {0}-{1} : {2} ns") -f "$c0", "$hi", "$((@($v[$c0..$hi])) -join ' ')")
            if ($u.Prefix) { $line = '  ' + $u.Prefix + $line.TrimStart() }
            Append-Log $line
        }
    }
    Append-Log ((T "Courbe obtenue avec le calcul de calibration v{0}.") -f "$(if ([string]$cal.Family -eq 'hd') { $script:CalibCalcHd } else { $script:CalibCalc })")
    if ($script:Restore) {
        if ($cal.Slow) { Append-Log ((T "Profils par tête appliqués par le mode Auto en écriture lente à toute image {0} ; ils seront enregistrés dans la configuration à la fin de la restauration.") -f "$famTxt") }
        else { Append-Log ((T "Profil appliqué par le mode Auto à toute image {0} ; il sera enregistré dans la configuration à la fin de la restauration.") -f "$famTxt") }
    }
    elseif ($cal.Slow) { Append-Log ((T "Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0}.") -f "$famTxt") }
    else { Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}.") -f "$famTxt") }
    if (-not $script:Restore) { [void](Save-Config) }      # restauration : enregistree par Close-Restore, onglet Ecriture retabli
    # 12.7 : fin de la calibration B : comparaison avec la courbe A et choix, meme sans reserve
    if ($script:CalRedo -and $script:CalRedo.Stage -eq 'running') { Complete-CalibRedo $cal @($issues) @($kinds) $prevCal; return }
    if ($issues.Count -gt 0) {
        # Resultat douteux : courbe montree, l utilisateur choisit de continuer (ecrire, ou conserver la courbe), d arreter
        # (calibration precedente retablie) ou, pour une reserve qui peut venir du support, de refaire la calibration sur une
        # autre disquette (Start-CalibRedo). Restauration : sequence occupee pendant la fenetre (chien de garde).
        $toWrite = ($script:AfterCalib -eq 'write')
        Append-Log ((T "Calibration : résultat douteux ({0}) : courbe affichée, décision demandée.") -f ($issues -join ' ; '))
        $offerRedo = Test-CalibRedoOffer ([bool]$script:Restore) ([bool]$script:CalRedo) @($kinds)
        while ($true) {
            if ($script:Restore) { $script:Restore.InCall = $true }
            try { $choice = Show-CalibReview $cal @($issues) $toWrite $false $false $offerRedo $null }
            finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
            if ($choice -ne 'redo') { break }
            # B lancee : la suite (comparaison, choix) a lieu a la fin de B ; sinon la fenetre de A se rouvre
            if (Start-CalibRedo $cal @($issues) @($kinds) $prevCal $toWrite) { return }
        }
        if ($choice -eq 'stop') {
            Restore-CalibState $prevCal
            $lblWCal.Text = (T 'Calibration abandonnée : la calibration précédente est rétablie.')
            Append-Log (T 'Calibration abandonnée à votre demande : courbe non conservée, calibration précédente rétablie.')
            if ($toWrite) {
                $script:AfterCalib = ''
                Append-Log (T 'Écriture annulée : résultat de calibration refusé.')
                if ($script:Restore) { Stop-Restore (T 'résultat de calibration refusé') }
            }
            Set-HomeProgDone $cal 'abandon' $issues[0]
            return
        }
        Append-Log (T 'Calibration : résultat accepté malgré les réserves.')
    }
    # Accueil : bilan avec reserves aussi apres « Continuer » sur un defaut grossier, sans autre reserve (12.7)
    Set-HomeProgDone $cal $(if ($issues.Count -gt 0 -or $surfIssue) { 'warn' } else { 'ok' }) $(if ($issues.Count -gt 0) { $issues[0] } else { $surfIssue })
    if ($script:AfterCalib -eq 'write') {
        # Ecriture rapide ou lente : l image est ecrite tout de suite avec le profil obtenu (courbe visible par le bouton Courbe)
        $script:AfterCalib = ''
        if ($cal.Swap) {
            # Calibration faite sur une disquette sacrifiee : la disquette a ecrire est redemandee, avec le meme delai que
            # l avertissement (sans reponse, l image est ecrite sur la disquette inseree) ; restauration : attente a delai,
            # puis nouvelle sonde de la destination avant l ecriture
            if ($script:Restore) { Enter-RestoreSwapBack; return }
            $lrA = if ($cal.LevelAfter) { Get-LevelRef $cal.Family $cal.Slow $cal.Drive $cal.Image $false -NCyl ([int]$cal.MaxCyl + 1) } else { $null }
            if ($lrA -and -not $lrA.Ok) { Append-Log ((T "Calibration rapide impossible : {0}. Écriture avec la nouvelle calibration complète.") -f "$($lrA.Why)") }
            if ($lrA -and $lrA.Ok) {
                # Reference faite sur la disquette sacrifiee : le niveau de la disquette a ecrire est mesure apres sa remise
                $lr = $lrA
                $lc = if ($lr.Ok) { (@($lr.Units | ForEach-Object { Format-CylList ([int[]]@(@(@($_.LCyls) + @($_.Wit) + @($(if ($null -ne $_.Probe) { $_.Probe }))) | Sort-Object -Unique)) } | Sort-Object -Unique)) -join ' ; ' } else { '-' }
                $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée : elle devient la référence de forme du lecteur {0}.`n`nRetirez la disquette sacrifiée et insérez la disquette à écrire, puis cliquez sur « Mesurer le niveau et écrire » : son niveau de précompensation est mesuré sur les cylindres {1} (2 faces, 1 à 3 écritures du motif par piste), puis l'image est écrite.`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)", "$lc") (T 'Mesurer le niveau et écrire') 'Diagnostic' (T "Sans réponse, la mesure du niveau puis l'écriture démarrent automatiquement dans {0} s.") '' '' ''
                if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
                if ($q.Auto) { Append-Log ((T "Calibration : remise de la disquette validée automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
                if ($lr.Ok) {
                    $script:AfterCalib = 'write'
                    Start-LevelCalib $lr -NoConfirm -NoFallback
                    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.') }
                    return
                }
            } else {
            $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée.`n`nRetirez la disquette sacrifiée du lecteur {0} et insérez la disquette à écrire, puis cliquez sur « Écrire l'image ».`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)") (T "Écrire l'image") 'Save' (T "Sans réponse, l'écriture de l'image démarre automatiquement dans {0} s.") '' '' ''
            if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
            if ($q.Auto) { Append-Log ((T "Calibration : remise de la disquette validée automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
            }
        }
        Append-Log (T 'Calibration terminée : écriture de l''image avec le profil obtenu.')
        if ($script:Restore) { $script:Restore.InCall = $true }
        # Prechauffage passe pendant la calibration (bouton « Passer le prechauffage ») : pas de second prechauffage
        try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip) } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
        return
    }
    Show-PrecompCurve $cal.Family $cal.Slow
}
