# ============================== FONCTIONS : CALIBRATION COMPLETE ===============

function Start-PrecompCalib([switch]$ForceFine, [string]$Intro = '', [switch]$LevelAfter, $Geom = $null, $Heads = $null, [string]$Test = '', [switch]$NoWarmup) {
    # ForceFine : test fin impose (reference de la calibration rapide) ; Intro : texte place en tete de l avertissement ;
    # LevelAfter : apres une calibration sur disquette sacrifiee, le niveau de la disquette a ecrire est mesure.
    # Carte Calibration de l Accueil : Geom (type de disquette, image de geometrie), Heads (une courbe par tete) et Test
    # ('std' ou 'fine') a la place de l image, de la case Ecriture lente et du mode de l onglet Ecriture ; NoWarmup :
    # prechauffage du lecteur desactive pour cette calibration (case de la fenetre de la carte).
    # 12.8 (lot 1c, point 3) : repli « Calibration complete » de la calibration rapide ($script:CalFallbackAsk, pose par
    # Start-LevelFallback ; lu et remis a $null ici, avant toute sortie) : confirmation commune frmConfirm (Show-AppConfirm),
    # sans compte a rebours, case « disquette sacrifiee » obligatoire. Variable et non parametre : signature inchangee
    # (enveloppes de make-test et des fins de test)
    $fb = $script:CalFallbackAsk; $script:CalFallbackAsk = $null
    # 12.8 (S3, decision du 21/10/2026) : « Mesure complete de cette disquette » ($script:CalDiskOnly, pose par
    # Start-DiskMeasure ; lu et remis a $null ici, avant toute sortie) : test fin, une courbe par tete, sur la disquette a
    # ecrire, borne par disquette ; confirmation frmConfirm sans compte a rebours, case « Cette disquette sera effacee »
    # obligatoire, marque de la disquette ; la reference du lecteur n est pas modifiee (Complete-DiskMeasure)
    $do = $script:CalDiskOnly; $script:CalDiskOnly = $null
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
    # 12.8 (S3-HIGH) : mesure complete de cette disquette (test fin) : passe de mesure directe des cylindres dont le besoin
    # depasse le plafond des passes de mesure (Start-DiskReach) et CalDiskMaxRetest nouveaux essais au plus : une ecriture
    # de plus par piste pour chacune (la disquette mesuree est celle a ecrire, reecrite ensuite par l image). Duree : passes
    # ciblees, chacune bornee par une passe sur tous les cylindres (Get-CalibRetestMinutes), en supplement de la duree estimee
    # (plafond des passes de mesure du bareme de la famille : Set-CalibScale n est appele qu apres l avertissement). Au plus :
    # encadrement (il precede toujours la mesure directe, les passes de mesure s arretant sous ce plafond), mesure directe et
    # CalDiskMaxRetest nouveaux essais, soit 2 + CalDiskMaxRetest passes ciblees (la duree estimee n en compte aucune)
    $minDisk = 0; $mxDisk = 0
    if ($do) {
        $mxDisk = [int]$(if ($family -eq 'hd') { $script:CalScaleHd.CalMaxNs } else { $script:CalScaleDd.CalMaxNs })
        $nPassMax = $nPassEst + 2 + [int]$script:CalDiskMaxRetest
        $extra = (T 'si la courbe demande un encadrement, une mesure directe au-delà de {0} ns ou de nouveaux essais des cylindres non convergés') -f "$mxDisk"
        $minDisk = $minutes + (2 + [int]$script:CalDiskMaxRetest) * $minRetest
    }
    $wear = (T "ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues, jusqu'à {1} {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer.") -f "$nPassEst", "$nPassMax", "$extra"
    $choice = if ($toWrite) { (T "Pour épargner {0}, cochez la case ci-dessous (le compte à rebours s'arrête), remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée.") -f "$target" }
              else { (T 'Insérez de préférence une disquette sacrifiée (vierge ou sans valeur), puis validez.') }
    $swapLabel = if ($toWrite) { (T "J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration") -f "$target" } else { '' }
    if ($redo) {
        # Confirmation sans compte a rebours : la case est obligatoire (une disquette de valeur est peut-etre inseree)
        $rc = Show-TimedConfirm 'frmCalibRedo' (T 'Calibration sur une autre disquette') ($Intro + $body + "`n`n" + $wear) (T 'Lancer la calibration B') 'Diagnostic' '' (T "J'ai retiré la disquette de la calibration A et inséré une autre disquette sacrifiée") '' (T "Pas de démarrage automatique : cochez la case, puis cliquez sur « Lancer la calibration B ».") -Seconds 0 -NeedCheck -Heading (T 'Calibration B : insérez une autre disquette sacrifiée') -Level 'warn' -Picto 'warn'
        $ans = @{ Ok = ($rc.Ok -and $rc.Checked); Swap = $false; Auto = $false }
    } elseif ($do) {
        # Mesure complete de cette disquette (M1, M2) : la disquette inseree est celle a ecrire ; marque proposee (champ
        # modifiable, liste de l avertissement de la calibration rapide, L-M)
        $bi = Get-LevelBrandItems ([string]$cmbDrive.Text) @($do.Ref.Units) $family
        # 12.8 (S3-HIGH) : duree avec la mesure directe et les nouveaux essais, au plus ($minDisk)
        $m1 = (T "Mesure complète de cette disquette sur le lecteur {0} : la précompensation est mesurée sur ses {1} cylindres (2 faces), environ {2} min ({3} min au plus si des cylindres demandent plus de {4} ns ou restent non convergés), puis l'image est écrite. La référence du lecteur n'est pas modifiée. La courbe obtenue est mémorisée pour la marque choisie ci-dessous ; sans marque, elle ne sert qu'à cette écriture.") -f "$($cmbDrive.Text)", "$nCyl", "$minutes", "$minDisk", "$mxDisk"
        # Texte : M1 et usure du support (le detail de la calibration, $body, reste au journal)
        $cq = @{ Title = (T 'Calibration precomp'); Heading = (T 'Mesure complète de cette disquette'); Level = 'warn'; Picto = 'warn'
                 Text = ($m1 + "`n`n" + $wear)
                 Check = (T "Cette disquette sera effacée, puis l'image y sera écrite.")
                 GoText = (T 'Lancer la mesure complète'); GoGlyph = 'Diagnostic'
                 Combo = @{ Label = (T 'Marque de la disquette insérée :'); Items = $bi.Items; Text = [string]$do.Brand
                            Tip = (T "Nom libre : marque, année ou lot. La courbe mesurée est mémorisée pour cette marque : les disquettes suivantes de cette marque en partent, avec une calibration rapide. Sans marque, elle ne sert qu'à cette écriture.") } }
        $okD = [bool](Show-AppConfirm @cq)
        if ($okD) { $do.Brand = Get-LevelBrandName ([string]$script:ConfirmComboText) $bi.Map; $script:LevelBrand = [string]$do.Brand }
        $ans = @{ Ok = $okD; Swap = $false; Auto = $false }
    } elseif ($fb) {
        # Repli apres la calibration rapide : la disquette inseree est peut-etre celle a ecrire ; jamais de demarrage
        # automatique. Reponse au journal (Show-AppConfirm), puis ligne du point 3
        $cq = @{ Title = (T 'Calibration precomp'); Heading = (T 'Calibration complète sur une disquette sacrifiée'); Level = 'warn'; Picto = 'warn'
                 Text = ($Intro + $body + "`n`n" + $wear + "`n`n" + (T "Pas de démarrage automatique : cochez la case, puis cliquez sur « Lancer la calibration complète »."))
                 Check = (T "J'ai retiré la disquette à écrire et inséré une disquette sacrifiée, de la marque de mes disquettes habituelles : elle deviendra la référence du lecteur")
                 GoText = (T 'Lancer la calibration complète'); GoGlyph = 'Diagnostic' }
        $okFb = [bool](Show-AppConfirm @cq)
        Append-Log $(if ($okFb) { (T "Calibration complète après la calibration rapide : lancée (case « disquette sacrifiée » cochée).") } else { (T 'Calibration complète après la calibration rapide : annulée.') })
        $ans = @{ Ok = $okFb; Swap = ($okFb -and [bool]$fb.Swap); Auto = $false }
    } else { $ans = Show-CalibConfirm ($Intro + $auto + $body + "`n`n" + $wear + "`n`n" + $choice) $swapLabel }
    if (-not $ans.Ok) { return }
    if ($ans.Auto) { Append-Log ((T "Calibration : avertissement validé automatiquement après {0} s sans réponse.") -f "$($script:CalibConfirmSeconds)") }
    if ($ans.Swap) { Append-Log ((T "Calibration sur une disquette sacrifiée : {0} sera redemandée avant l'écriture.") -f "$target") }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    try { $pat = New-CalibPattern $family $img $nCyl }
    catch { [void](Show-AppMessage ((T "Calibration : motif de test impossible à créer : {0}") -f "$($_.Exception.Message)") (T 'Calibration precomp') 'OK' 'Error'); return }
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
    # 12.8 (S3) : borne de la courbe de cette disquette (Get-DiskHardNs : plafond par disquette, ou precompMaxNs reglee sous
    # 400 ns) pendant la mesure complete, retablie a sa fin (Reset-DiskHardNs)
    if ($do) { Set-DiskHardNs @{ DiskOnly = $true; HardNs = [int]$do.HardNs } }
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
    if ($do) {
        # 12.8 (S3) : mesure complete de cette disquette : marque, borne de la courbe, reference en place (Get-LevelRef)
        $script:Cal.DiskOnly = $true; $script:Cal.Brand = [string]$do.Brand; $script:Cal.HardNs = [int]$do.HardNs; $script:Cal.DiskRef = $do.Ref
        Append-Log ((T "=== Mesure complète de cette disquette : lecteur {0}, image {1} ({2}, {3}) ; référence du lecteur inchangée ===") -f "$($cmbDrive.Text)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt")
        if ($do.Brand) { Append-Log ((T 'Marque de la disquette insérée : « {0} ».') -f "$($do.Brand)") }
        $thr = Get-DiskOverNs
        if ([int]$do.HardNs -gt $thr) { Append-Log ((T "Borne de la courbe de cette disquette : {0} ns ; au-delà de {1} ns, contrôle après écriture imposé.") -f "$($do.HardNs)", "$thr") }
        else { Append-Log ((T "Borne de la courbe de cette disquette : {0} ns (precompMaxNs).") -f "$($do.HardNs)") }
        # 12.8 (S3-HIGH) : duree estimee et ecritures par piste au plus (avertissement M1)
        Append-Log ((T "Durée estimée de la mesure : environ {0} min ; {1} min au plus avec la mesure directe des cylindres dont le besoin dépasse {2} ns et {3} nouveaux essais au plus des cylindres non convergés.") -f "$minutes", "$minDisk", "$mxDisk", "$($script:CalDiskMaxRetest)")
        Append-Log ((T "Écritures du motif de test par piste : {0} au plus ({1} passes de mesure, encadrement, mesure directe, {2} vérifications, {3} nouveaux essais). La disquette mesurée est celle à écrire, réécrite ensuite par l'image : aucune disquette sacrifiée à épargner, chaque passe de plus reste bornée.") -f "$nPassMax", "$(@($script:CalCoarse).Count)", "$($script:CalMaxVerify)", "$($script:CalDiskMaxRetest)")
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min. L'image ne fixe que la densité et le nombre de cylindres, son contenu n'est pas écrit.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
    }
    elseif ($Geom) {
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

function Start-DiskMeasure($lr, [string]$brand) {
    # 12.8 (S3, decision du 21/10/2026, c4-design § 4.2) : « Mesure complete de cette disquette » avant une ecriture lente :
    # calibration complete en test fin, une courbe par tete, sur la disquette a ecrire, puis ecriture de l image avec ces
    # courbes ; la reference du lecteur ($lr : Get-LevelRef, une unite par tete) n est pas modifiee. Appelants : fenetre de
    # decision de la calibration rapide (W-M1), garde de la passe 1 (W-M2), liste « Mesure : complete » de l onglet
    # Ecriture (Start-LevelBeforeWrite). Marque proposee dans l avertissement (M1) : $brand
    if (-not $lr -or -not $lr.Ok -or @($lr.Units).Count -ne 2 -or $null -eq @($lr.Units)[0].Head) {
        $script:AfterCalib = ''
        Append-Log (T "Mesure complète de cette disquette impossible : elle demande la référence du lecteur par tête (écriture lente). Écriture annulée.")
        return
    }
    $script:CalDiskOnly = @{ Brand = [string]$brand; HardNs = (Get-DiskHardNs); Ref = $lr }
    $script:AfterCalib = 'write'
    Start-PrecompCalib -ForceFine -Heads $true
    $script:CalDiskOnly = $null      # deja remis a $null par Start-PrecompCalib (premiere instruction)
    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T "Écriture annulée : la mesure complète de cette disquette n'a pas été lancée.") }
}

function Get-DiskMeasureMinutes([int]$nCyl) {
    # 12.8 (S3) : duree estimee de la mesure complete de cette disquette (W-M1, W-M2), au calcul de Start-PrecompCalib en
    # test fin : passes de mesure et de verification sur tous les cylindres, prechauffage du reglage warmFullCalib compris
    $n = [math]::Max(2, [math]::Min(84, $nCyl))
    $wu = if ([bool](Get-Setting 'warmFullCalib')) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    $np = @($script:CalCoarse).Count + [int]$script:CalMaxVerify
    return [int][math]::Max(1, [math]::Round($n * 2 * 1.4 * $np / 60 + $wu, 0))
}

function Set-DiskHardNs($x) {
    # 12.8 (S3) : borne de la courbe pendant la mesure complete de cette disquette (Get-DiskHardNs : plafond par
    # disquette, ou precompMaxNs reglee sous 400 ns), posee apres Set-CalibScale ; retablie par Reset-DiskHardNs
    if ($x -and $x.DiskOnly -and [int]$x.HardNs -gt 0) { $script:CalHardNs = [int]$x.HardNs }
}

function Reset-DiskHardNs {
    # 12.8 (S3) : borne de precompMaxNs retablie a la fin de la mesure complete de cette disquette (fin, arret, aucune
    # mesure exploitable) : bareme de la famille en cours
    Set-CalibScale $(if ([string]$script:CalScaleFam -eq 'hd') { 'hd' } else { '' })
}

function Start-DiskReach($cal) {
    # 12.8 (S3-HIGH, essai E1 du 23/10/2026) : mesure complete de cette disquette seulement. Un cylindre encore
    # sous-compense au plafond des passes de mesure (CalMaxNs), dont le zero estime depasse ce plafond, est MESURE autour
    # de son besoin au lieu d etre extrapole : une passe de plus l ecrit a cette estimation, au plus a la borne de cette
    # disquette (CalHardNs, posee par Set-DiskHardNs : Get-DiskHardNs). Sur une disquette a reponse convexe (pente qui
    # baisse quand le besoin monte, E1), l extrapolation depuis CalMaxNs sous-estime le besoin. Le zero est ensuite
    # recalcule par Get-CalibZero sur la corde des deux ecritures les plus proches (Invoke-CalibAnalysis, etape 'reach'),
    # sans tendance de la courbe (Get-TrendEstimates). Une seule passe (Reach pose sur chaque unite, meme vide) ; la
    # calibration complete de reference n en a aucune. Renvoie $true si la passe est lancee.
    if (-not $cal -or -not $cal.DiskOnly) { return $false }
    if (@($cal.Units | Where-Object { $null -ne $_.Reach }).Count -gt 0) { return $false }
    $hard = [int]$script:CalHardNs; $need = $false
    foreach ($u in $cal.Units) {
        $u.Reach = @{}
        foreach ($c in @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
            if ([string]$u.Kind[$c] -eq 'interp' -or [double]$u.Est[$c] -le [double]$script:CalMaxNs) { continue }
            $pts = $u.Results[$c]
            if (-not $pts -or $pts.Count -eq 0) { continue }
            $top = [int](@($pts.Keys | ForEach-Object { [int]$_ }) | Measure-Object -Maximum).Maximum
            if ([double]$pts[$top].Shift -le 0) { continue }          # deja encadre : zero mesure
            $v = [int][math]::Min($hard, [math]::Round([double]$u.Est[$c], 0))
            if ($v -le $top) { continue }                              # borne de cette disquette deja ecrite
            $u.Reach[$c] = $v; $need = $true
        }
    }
    if (-not $need) { return $false }
    $cal.Stage = 'reach'; $cal.TotalPasses++
    New-CalibPass
    return $true
}

function Write-DiskReachLog($u) {
    # 12.8 (S3-HIGH) : journal de la mesure directe (Start-DiskReach), une ligne par tete : pour chaque cylindre mesure, les
    # deux ecritures retenues par Get-CalibZero (paire qui encadre le zero, sinon les deux plus fortes) et le zero de leur
    # corde ; « prolonge » : encore sous-compense a l estimation, zero au-dela de la derniere ecriture sur la meme corde ;
    # « borne » : besoin au-dela de la borne de cette disquette (Limit-CalibZero)
    $items = @()
    foreach ($c in @($u.Reach.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
        if (-not $u.Est.ContainsKey($c) -or -not $u.Results.ContainsKey($c)) { continue }
        $pts = $u.Results[$c]
        $xs = @($pts.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        if ($xs.Count -lt 2) { continue }
        $j = $xs.Count - 2
        for ($i = 0; $i -lt $xs.Count - 1; $i++) { if ([double]$pts[$xs[$i]].Shift -gt 0 -and [double]$pts[$xs[$i + 1]].Shift -le 0) { $j = $i; break } }
        $k = [string]$u.Kind[$c]
        $tag = if ($k -eq 'cap') { ', ' + (T 'borné') } elseif ($k -eq 'extrap') { ', ' + (T 'prolongé') } else { '' }
        $items += ((T 'c{0} {1} -> {2} et {3} -> {4} : {5} ns{6}') -f "$c", "$($xs[$j])", (Format-UiNum ([double]$pts[$xs[$j]].Shift) '+0.0;-0.0;0.0'), "$($xs[$j + 1])", (Format-UiNum ([double]$pts[$xs[$j + 1]].Shift) '+0.0;-0.0;0.0'), "$([math]::Round([double]$u.Est[$c], 0))", "$tag")
    }
    if ($items.Count -eq 0) { return }
    Append-Log ($u.Prefix + ((T "Mesure directe : zéro recalculé par la corde des deux écritures les plus proches (valeur écrite -> décalage, ns) : {0}. Prolongé : encore sous-compensé à l'estimation, zéro au-delà de la dernière écriture sur la même corde ; borné : besoin au-delà de la borne de {1} ns de cette disquette.") -f ($items -join ' ; '), "$($script:CalHardNs)"))
}

function New-DiskMeasureRecord($cal, $u, $ru, [string]$date) {
    # 12.8 (S3, c4-design § 4.2) : enregistrement de $script:LevelShifts d une tete mesuree par la mesure complete de cette
    # disquette : Model et Mode 'mesure', courbe = Fit.Values de la mesure, profil, reference en place (RefKey, Tag,
    # RefDate) ; niveau = ecart moyen a la reference (M4), historique de la reference garde (niveau de depart des
    # disquettes suivantes, Get-LevelRef) ; LevelAlgo 'lvl2' : une 12.7 l ignore (G2)
    $vals = [int[]]@($u.Fit.Values); $vref = @($ru.Cv.Values)
    $n = [math]::Min($vals.Count, $vref.Count)
    $dd = @(for ($c = 0; $c -lt $n; $c++) { [double]$vals[$c] - [double]$vref[$c] })
    $avg = if ($dd.Count -gt 0) { [double]($dd | Measure-Object -Average).Average } else { 0.0 }
    $sd = 0.0
    if ($dd.Count -ge 2) { $ss = 0.0; foreach ($x in $dd) { $ss += [math]::Pow($x - $avg, 2) }; $sd = [math]::Sqrt($ss / ($dd.Count - 1)) }
    $hk = "$($ru.RefKey)|$($ru.Tag)"; $old = $script:LevelShifts[$hk]
    $hist = @(); if ($old -and [string]$old.RefDate -eq [string]$ru.Cv.Date) { $hist = @($old.Hist) }
    $over = [int[]]@(0..($vals.Count - 1) | Where-Object { [int]$vals[$_] -gt [int]$script:CalHardNsUser })
    return @{ RefKey = [string]$ru.RefKey; Tag = [string]$ru.Tag; Head = $u.Head; Drive = [string]$cal.Drive; Date = $date; RefDate = [string]$ru.Cv.Date; RefTest = [string]$ru.Cv.Test
              Delta = [int][math]::Round($avg); Est = [math]::Round($avg, 1); SE = 0.0; Tau = [math]::Round($sd, 1)
              Verdict = 'mesure'; Shape = 'mesure'; Reasons = [string[]]@(); Conv = [bool]($u.Warn.NonConv.Count -eq 0); Passes = [int]$cal.PassesDone
              Cyls = [int[]]@(); Zs = [double[]]@(); Ds = [double[]]@(); Sigs = [double[]]@(); Kinds = [string[]]@()
              Values = $vals; Spec = (Build-CurveProfile $vals); Sat = [int[]]@(); Floor = [int[]]@()
              Hist = $hist; Version = $script:Version; Algo = $script:CalibAlgo; LevelAlgo = 'lvl2'; Model = 'mesure'; S = 0.0; B = 0.0
              Hc = $null; Hard = [int]$cal.HardNs; Over = $over; Mode = 'mesure'; Brand = [string]$cal.Brand; Ctl = [int[]]@()
              K = $(if ($null -ne $u.Slope) { [math]::Round([double]$u.Slope, 3) } else { $null })
              Calc = [string]$script:CalibCalc; MaxNs = [int]$cal.HardNs
              DevMin = $(if ($dd.Count) { [int](($dd | Measure-Object -Minimum).Minimum) } else { 0 }); DevMax = $(if ($dd.Count) { [int](($dd | Measure-Object -Maximum).Maximum) } else { 0 }) }
}

function Complete-DiskMeasure($cal, $issues, $kinds, [string]$surfIssue) {
    # 12.8 (S3, c4-design § 4.2) : fin de la mesure complete de cette disquette (Complete-PrecompCalib, apres les
    # diagnostics). Ni copie .bak, ni PrecompCurves, ni profil de famille, ni abandon des niveaux ou des marques : la
    # reference du lecteur reste en place. Un enregistrement 'mesure' par tete dans $script:LevelShifts (New-DiskMeasureRecord),
    # profils dans les champs --precomp (pour cette disquette seulement). Reserves : fenetre de decision ; « Arreter » :
    # enregistrements d avant retablis, ecriture annulee. Resultat accepte : memoire de la marque (Update-LevelBrandCurve,
    # tetes sans reserve), puis ecriture (chemin AfterCalib) ; courbe au-dela de 400 ns : controle apres ecriture impose.
    # Ecriture annulee pendant la mesure (S3-FIX) : mesure non conservee, rien n est modifie ni enregistre
    Reset-DiskHardNs
    $famTxt = Get-CalibFamilyName $cal.Family
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $toWrite = ($script:AfterCalib -eq 'write')
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Mesure complète de cette disquette terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    # 12.8 (S3-FIX) : ecriture annulee pendant la mesure (erreur gw pendant la passe du nouvel essai, Stop-PrecompCalib
    # -GwError ; restauration deja arretee) : la mesure, faite pour cette ecriture seulement, n est pas conservee : ni
    # enregistrement 'mesure', ni champs --precomp, ni marque, ni fenetre de decision ; rien n est enregistre (en
    # restauration, l onglet Ecriture de l utilisateur, retabli par Close-Restore, reste tel quel) ; reference intacte
    if (-not $toWrite) {
        $pbWCal.Visible = $false
        $lblWCal.Text = (T 'Mesure complète de cette disquette non conservée : écriture annulée.')
        Append-Log (T "Mesure complète de cette disquette non conservée : l'écriture a été annulée. Ni la courbe de cette disquette ni la marque ne sont enregistrées ; la référence du lecteur, inchangée, reste en place.")
        Set-HomeProgDone $cal 'stop'
        if ($script:Restore) { Stop-Restore (T 'écriture annulée pendant la mesure complète de cette disquette') }
        return
    }
    # Reserve de surface ou de vitesse (disquette douteuse, poursuivie a votre demande) : rien n est memorise pour la marque
    $surfBad = [bool]($surfIssue -or @(@($kinds) | Where-Object { $_ -eq 'surface' -or $_ -eq 'speed' }).Count -gt 0)
    $prevRecs = @{}; $recs = @()
    foreach ($u in $cal.Units) {
        $ru = Get-DiskRefUnit $cal $u
        if (-not $ru) {
            Append-Log (T "Mesure complète de cette disquette : référence du lecteur introuvable pour une tête, mesure non conservée.")
            foreach ($k in @($prevRecs.Keys)) { if ($prevRecs[$k]) { $script:LevelShifts[$k] = $prevRecs[$k] } else { $script:LevelShifts.Remove($k) } }
            if ($toWrite) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : calibration sans mesure exploitable.') }
            $pbWCal.Visible = $false
            if ($script:Restore) { Stop-Restore (T 'calibration sans mesure exploitable') }     # 12.8 (S3-FLUX) : restauration, copie secteur
            return
        }
        $hk = "$($ru.RefKey)|$($ru.Tag)"
        $prevRecs[$hk] = $script:LevelShifts[$hk]
        $rec = New-DiskMeasureRecord $cal $u $ru $date
        $script:LevelShifts[$hk] = $rec
        $recs += ,$rec
        if ($surfBad) { $u.DiskOk = $false }
    }
    Append-Log (T "Mesure complète de cette disquette : courbe appliquée à cette écriture ; référence du lecteur inchangée.")
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
    Append-Log ((T "Courbe obtenue avec le calcul de calibration v{0}.") -f "$($script:CalibCalc)")
    # Champs --precomp : profil de chaque tete de cette disquette (mode Auto ; remis a la reference apres l ecriture)
    $fieldsPrev = @{ Prof = $cmbWProfile.SelectedIndex; On = $chkWPrecomp.Checked; P0 = $txtWPrecomp.Text; P1 = $txtWPrecomp1.Text; Lbl = (Get-WProfileText) }
    if ($cmbWProfile.SelectedIndex -ne 0) { $cmbWProfile.SelectedIndex = 0 }
    Set-LevelFields $recs $true
    $r0 = @($recs | Where-Object { $_.Head -eq 0 })[0]; $r1 = @($recs | Where-Object { $_.Head -eq 1 })[0]
    $lblWProfileInfo.Text = ((T "Profils {0} de cette disquette (mesure complète du {1}, lecteur {2}) : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre ; référence du lecteur inchangée. À n'utiliser que pour cette disquette (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$(@($r0.Values)[0])", "$(@($r0.Values)[-1])", "$(@($r1.Values)[0])", "$(@($r1.Values)[-1])")
    if (-not $script:Restore) { [void](Save-Config) }
    if ($issues.Count -gt 0) {
        Append-Log ((T "Calibration : résultat douteux ({0}) : courbe affichée, décision demandée.") -f ($issues -join ' ; '))
        if ($script:Restore) { $script:Restore.InCall = $true }
        try { $choice = Show-CalibReview $cal @($issues) $toWrite $false $false $false $null }
        finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($choice -eq 'stop') {
            # « Arreter » : enregistrements d avant retablis, champs ramenes, reference intacte
            foreach ($k in @($prevRecs.Keys)) { if ($prevRecs[$k]) { $script:LevelShifts[$k] = $prevRecs[$k] } else { $script:LevelShifts.Remove($k) } }
            if ($cmbWProfile.SelectedIndex -ne $fieldsPrev.Prof) { $cmbWProfile.SelectedIndex = $fieldsPrev.Prof }
            Update-PrecompForImage $txtWFile.Text
            $chkWPrecomp.Checked = $fieldsPrev.On; $txtWPrecomp.Text = $fieldsPrev.P0; $txtWPrecomp1.Text = $fieldsPrev.P1
            if ($null -ne $fieldsPrev.Lbl) { $lblWProfileInfo.Text = $fieldsPrev.Lbl }
            if (-not $script:Restore) { [void](Save-Config) }
            $pbWCal.Visible = $false
            $lblWCal.Text = (T 'Mesure complète de cette disquette abandonnée : référence du lecteur inchangée.')
            Append-Log (T "Mesure complète de cette disquette abandonnée à votre demande : courbe non conservée ; la référence du lecteur, inchangée, reste en place.")
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
    # Memoire de la marque (c4-design § 4.2) : tetes sans reserve seulement
    if ([string]$cal.Brand) {
        Update-LevelBrandCurve $cal ([string]$cal.Brand)
        if (-not $script:Restore) { [void](Save-Config) }
    }
    else { Append-Log (T "Mesure complète de cette disquette sans marque : la courbe ne sert qu'à cette écriture, rien n'est mémorisé.") }
    Set-HomeProgDone $cal $(if ($issues.Count -gt 0 -or $surfIssue) { 'warn' } else { 'ok' }) $(if ($issues.Count -gt 0) { $issues[0] } else { $surfIssue })
    if ($script:Restore) {
        # 12.8 (S3-FLUX, decision 2) : restauration en copie secteur : etape 4 et ligne « Niveau » du rapport (Set-RsCalibDone,
        # Write-RestoreReport), comme apres la calibration rapide de la destination (Complete-LevelCalib)
        $r = $script:Restore
        $base = if ($r.CalibUsed) { ((T "calibration existante ({0}), pas de recalibration") -f "$($r.CalibUsed.Text)") + $(if ($r.CalibUsed.Notes.Count -gt 0) { ' ; ' + ($r.CalibUsed.Notes -join ' ; ') } else { '' }) }
                elseif ($r.CalSwap) { (T "faite sur une disquette sacrifiée ({0})") -f "$($r.Calib)" } else { '' }
        $lt = (T "courbe mesurée sur la destination (mesure complète de cette disquette, {0} passe(s))") -f "$($cal.PassesDone)"
        if ($issues.Count -gt 0) { $lt += ' ; ' + ($issues -join ' ; ') }
        $r.Level = @{ State = $(if ($issues.Count -gt 0 -or $surfIssue -or ($r.CalibUsed -and $r.CalibUsed.Notes.Count -gt 0)) { 'warn' } else { 'ok' }); Text = $(if ($base) { "$base ; $lt" } else { $lt }); Report = $lt }
    }
    if ($toWrite) {
        $script:AfterCalib = ''
        # G1 : courbe de cette disquette au-dela de 400 ns (ou de precompMaxNs reglee plus haut) : controle apres ecriture impose
        $thr = Get-DiskOverNs
        if (@($recs | Where-Object { @(@($_.Values) | Where-Object { [int]$_ -gt $thr }).Count -gt 0 }).Count -gt 0) {
            $script:LevelPostForce = $true
            Append-Log ((T "Contrôle après écriture imposé : courbe de cette disquette au-delà de {0} ns.") -f "$thr")
        }
        Append-Log (T "Mesure complète de cette disquette terminée : écriture de l'image avec la courbe de cette disquette.")
        if ($script:Restore) { $script:Restore.InCall = $true }
        try { Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip) } finally { if ($script:Restore) { $script:Restore.InCall = $false; $script:Restore.Idle = Get-Date } }
        if ($script:Restore -and -not ($script:GwProc -and -not $script:GwProc.HasExited) -and $script:Chain.Count -eq 0) { Stop-Restore (T 'l''écriture n''a pas démarré après la calibration, voir le journal') }
        # Profils de cette disquette remis a ceux de la reference apres l ecriture (minuteur principal), comme apres une
        # calibration rapide ; pose apres Start-ImageWrite, qui peut ouvrir une fenetre avant de lancer gw
        if (-not $script:Restore) { $script:LevelFieldsPending = $true }
        return
    }
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
    # 12.8.1 : mesure de la disquette sur l image (276) : ValueTxt « tete 0 puis tete 1 »
    $fmt = if ($cal.Mode -eq 'content') { (T "Mesure de la disquette sur l'image : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Mode -eq 'level') { (T "Calibration rapide : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Redo) { (T "Calibration B : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.DiskOnly) { (T "Mesure complète de cette disquette : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           else { (T "Calibration : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
    $lblWCal.Text = ($fmt -f "$([math]::Min($total, $cal.PassesDone + 1))", "$total", "$($cal.ValueTxt)", "$phaseTxt", "$pct", (Format-CalDuration $remaining))
}

function Stop-PrecompCalib([switch]$GwError) {
    # Abandon (bouton Arreter, erreur gw, fichier manquant) : etat remis a zero, barre masquee ; bilan de l Accueil (12.7)
    # 12.7 point 2 : calibration B arretee : decision sur la courbe A seule, differee au minuteur principal (Resume-CalibRedo)
    # 12.8 (VAL01, decisions128.md) : GwError (code retour de gw, operation incomplete, gw non lance, releve absent ou
    # illisible) pendant la passe du nouvel essai : etat de la derniere verification retabli (Restore-CalibRetestPre), son
    # jugement est garde ; fin differee au minuteur principal (Complete-CalibRetestEnd : aucune fenetre modale pendant le
    # traitement de la fin de gw), sans ecrire l image. Calibration B : elle reste en cours, la comparaison A/B suit sa fin.
    # Restauration : deja arretee par l appelant, sinon arretee ici. Bouton Arreter (sans GwError) : abandon, comme en 12.7
    if ($GwError -and $script:Cal -and -not $script:Cal.RetestEnd -and (Restore-CalibRetestPre $script:Cal)) {
        $script:Cal.RetestEnd = $true
        Append-Log ((T "Calibration : erreur gw pendant la passe du nouvel essai : jugement de la vérification {0} conservé, la calibration se termine sans le nouvel essai.") -f "$($script:Cal.VerifyCount)")
        if ($script:AfterCalib) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : erreur gw pendant le nouvel essai de la calibration.') }
        if ($script:Restore) { Stop-Restore (T 'erreur gw pendant le nouvel essai de la calibration') }
        return
    }
    if ($script:CalRedo -and $script:CalRedo.Stage -eq 'running') { $script:CalRedo.Stage = 'interrupted'; if (-not $script:CalRedo.Why) { $script:CalRedo.Why = (T 'calibration interrompue') } }
    $cal = $script:Cal
    $script:Cal = $null
    if ($cal -and $cal.DiskOnly) { Reset-DiskHardNs }     # 12.8 (S3) : borne de precompMaxNs retablie
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
    if ($cal.DiskOnly) { Set-DiskHardNs $cal }   # 12.8 (S3) : borne de cette disquette, de nouveau apres Set-CalibScale
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
    elseif ($cal.Mode -eq 'content') {
        # 12.8.1 : mesure de la disquette sur l image (276), avant l ecriture lente ; retour au stade 'content' (WarmNext)
        if ($plan.Reduced) { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la mesure de la disquette sur l'image et l'écriture lente (durée réduite : lecteur déjà en activité pendant {2}, dernière commande terminée il y a {3}).") -f "$($cal.Drive)", "$durTxt", "$actTxt", "$idleTxt") }
        else { Append-Log ((T "Préchauffage du lecteur {0} : {1} de lecture sans écriture avant la mesure de la disquette sur l'image et l'écriture lente.") -f "$($cal.Drive)", "$durTxt") }
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
    # 12.8.1 (spec-1281.md § A.9) : mesure de la disquette sur l image (stade 'content' : premiere passe apres les fins du
    # prechauffage, Start-CalibWarmup et Invoke-CalibWarmup) : passes propres (New-ContentPass, 276)
    if ($script:Cal -and $script:Cal.Stage -eq 'content') { New-ContentPass; return }
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
    } elseif ($cal.Stage -eq 'reach') {
        # 12.8 (S3-HIGH) : mesure complete de cette disquette : passe de mesure directe (Start-DiskReach) des cylindres dont
        # le zero estime depasse le plafond des passes de mesure, ecrits a cette estimation, au plus a la borne de cette
        # disquette (une valeur par cylindre ; par tete en ecriture lente), relus seuls
        $cal.ValueTxt = (T 'mesure directe')
        $all = @{}
        foreach ($u in $cal.Units) { foreach ($c in @($u.Reach.Keys)) { $all[[int]$c] = $true } }
        $cyls = [int[]]@($all.Keys | Sort-Object)
        if ($cal.Slow) {
            foreach ($u in $cal.Units) { if ($u.Reach.Count -gt 0) { $writes += ,@("c=$(Format-CylList ([int[]]@($u.Reach.Keys))):h=$($u.Head)", (Get-BracketSpec $u.Reach)) } }
        } else {
            $writes += ,@("c=$(Format-CylList $cyls):h=0-1", (Get-BracketSpec $cal.Units[0].Reach))
        }
        $readTs = "c=$(Format-CylList $cyls):h=0-1"
        $specTxt = (@($cal.Units | ForEach-Object { "$($_.Prefix)$(Get-BracketSpec $_.Reach)" } | Where-Object { $_ -match '=' })) -join ' ; '
        Append-Log ((T "Mesure complète : passe de mesure directe des cylindres {0}, besoin estimé au-delà de {1} ns (plafond des passes de mesure), écrits à leur estimation, au plus {2} ns : precomp {3}") -f (Format-CylList $cyls), "$($script:CalMaxNs)", "$($script:CalHardNs)", "$specTxt")
    } elseif ($cal.Stage -eq 'level') {
        # Calibration rapide : reference decalee du niveau courant sur les seuls cylindres de mesure ; ecriture rapide une
        # commande (h=0-1), ecriture lente une commande par tete non terminee
        $all = @{}; $parts = @()
        foreach ($u in $cal.Units) {
            if ($u.Done) { continue }
            $lc = [int[]]@($u.LTarget.Keys | ForEach-Object { [int]$_ } | Sort-Object)
            foreach ($c in $lc) { $all[$c] = $true }
            $lv = '{0:+0;-0;0}' -f [int]$u.D
            # 12.8 (lot 1c, § 11.2) : tete en passe de mesure, de verification ou de confirmation de la pente
            $md = [string]$u.Mode
            if ($null -eq $u.Head) { $parts += ((T "niveau {0} ns") -f "$lv") }
            elseif ($md -eq 'meas') { $parts += ((T 'tête {0} mesure adaptative') -f "$($u.Head)") }
            elseif ($md -eq 'verif') { $parts += ((T 'tête {0} courbe adaptée') -f "$($u.Head)") }
            elseif ($md -eq 'nwc') { $parts += ((T 'tête {0} confirmation de la pente') -f "$($u.Head)") }
            else { $parts += ((T "tête {0} {1} ns") -f "$($u.Head)", "$lv") }
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

function Write-CalibPassLog($plog, [string]$label) {
    # 12.8 (lot 1c, point 1, etendu a la calibration complete) : mesures par cylindre d une passe de calibration, rapide
    # ou complete, au journal seulement (ni courbe, ni niveaux, ni historique). $plog : face -> mesures @{ C ; W ; Role ;
    # Shift ; SE } (Invoke-CalibAnalysis). Une ligne par face lue, prefixe « [tete h] », courbe commune comprise (la courbe
    # commune prend la moyenne des deux faces). Element « c<cyl>[ (role)] <valeur ecrite> -> <decalage> ± <erreur-type> »,
    # en ns, une decimale au format de la langue (Format-UiNum), « - » sans erreur-type ; cylindres croissants, separes
    # par « ; ». Format stable, lu par un script (c1\lin\analyze_percyl.py)
    foreach ($h in @($plog.Keys | Sort-Object)) {
        $items = @(@($plog[$h]) | Sort-Object { [int]$_.C } | ForEach-Object {
            $se = if ($null -eq $_.SE -or [double]::IsNaN([double]$_.SE)) { '-' } else { Format-UiNum ([double]$_.SE) '0.0' }
            "c$($_.C)$($_.Role) $($_.W) -> $(Format-UiNum ([double]$_.Shift) '+0.0;-0.0;0.0') ± $se"
        })
        if ($items.Count -eq 0) { continue }
        Append-Log ((T "{0}Mesures de la passe {1} (valeur écrite -> décalage ± erreur-type, ns) : {2}.") -f ((T '[tête {0}] ') -f "$h"), "$label", ($items -join ' ; '))
    }
}

function Invoke-CalibAnalysis {
    $cal = $script:Cal
    if (-not $cal) { return }
    # 12.8 (VAL01) : releve absent ou illisible : erreur de la passe (GwError : passe du nouvel essai, jugement de la
    # derniere verification garde ; sinon abandon, comme en 12.7)
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log (T 'Calibration : fichier SCP absent, analyse impossible.'); Stop-PrecompCalib -GwError; return }
    try { $tracks = Read-ScpFile $cal.Scp ([int]$cal.PatternBits) } catch { Append-Log ((T "Calibration : {0}") -f "$($_.Exception.Message)"); Stop-PrecompCalib -GwError; return }
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
        $plog = @{}      # 12.8 (lot 1c, point 1) : face -> mesures de la passe (Write-CalibPassLog), journal seulement
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
            if ($cal.Stage -eq 'reach' -and -not $u.Reach.ContainsKey([int]$c)) { continue }     # 12.8 (S3-HIGH)
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
                'reach'   { Add-CalibPoint $u.Results[[int]$c] ([int]$u.Reach[[int]$c]) $meas }      # 12.8 (S3-HIGH)
                'level'   {
                    Add-CalibPoint $u.Results[[int]$c] ([int]$u.LTarget[[int]$c]) $meas
                    # 12.8 (lot 1c) : mesures brutes de chaque passe (passe, valeur ecrite, mesure) : passe de verification
                    # de la calibration rapide adaptative
                    if ($null -ne $u.Raw) { if (-not $u.Raw.ContainsKey([int]$c)) { $u.Raw[[int]$c] = @() }; $u.Raw[[int]$c] += ,@([int]$cal.LPass, [int]$u.LTarget[[int]$c], $meas) }
                }
                default   { $u.Verify[[int]$c] = $meas; $u.VerifyP[[int]$c] = Get-SpecValue $u.Profile ([int]$c) }
            }
            # 12.8 (lot 1c, point 1) : mesure de chaque face lue avec la valeur ecrite a cette passe (journal seulement :
            # ni courbe, ni niveaux, ni historique) ; role du cylindre : temoin de marche ou du plafond (calibration rapide),
            # temoin de derive (verification ciblee)
            $xv = switch ($cal.Stage) { 'coarse' { [int]$cal.Value } 'bracket' { [int]$u.Bracket[[int]$c] } 'densify' { [int]$u.Dense[[int]$c] } 'reach' { [int]$u.Reach[[int]$c] } 'level' { [int]$u.LTarget[[int]$c] } default { [int]$u.VerifyP[[int]$c] } }
            $role = if ($cal.Stage -eq 'level') { Get-LevelCylRole $u ([int]$c) } elseif ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.Witness) -contains [int]$c) { ' ' + (T '(témoin)') } else { '' }
            foreach ($h in @($fm.Keys)) {
                if (-not $plog.ContainsKey([int]$h)) { $plog[[int]$h] = @() }
                $plog[[int]$h] += ,@{ C = [int]$c; W = $xv; Role = $role; Shift = [double]$fm[$h].Shift; SE = $fm[$h].SE }
            }
            # 12.7 : mesures des passes de mesure gardees par face (comparaison de deux calibrations, Get-FaceEstimates) ;
            # sans effet sur la courbe
            $xw = $null
            if ($cal.Stage -eq 'coarse') { $xw = [int]$cal.Value } elseif ($cal.Stage -eq 'bracket') { $xw = [int]$u.Bracket[[int]$c] } elseif ($cal.Stage -eq 'densify') { $xw = [int]$u.Dense[[int]$c] } elseif ($cal.Stage -eq 'reach') { $xw = [int]$u.Reach[[int]$c] }
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
        } elseif (($cal.Stage -ne 'bracket' -or $u.Bracket.Count -gt 0) -and ($cal.Stage -ne 'densify' -or $u.Dense.Count -gt 0) -and ($cal.Stage -ne 'reach' -or $u.Reach.Count -gt 0) -and ($cal.Stage -ne 'verify' -or $null -eq $u.VerifyList -or @($u.VerifyList).Count -gt 0)) {
            Append-Log ((T "  {0} : aucun cylindre mesurable{1}") -f "$($u.Prefix)$($cal.ValueTxt)", "$badTxt$oneTxt")
        }
        # 12.8 (lot 1c, point 1, etendu a la calibration complete) : mesures par cylindre de la passe, une ligne par face,
        # ecrites avant toute decision ; calibration rapide : zeros des cylindres mesures deux fois ou plus
        $plab = switch ($cal.Stage) { 'coarse' { "$([int]$cal.Index + 1)" } 'level' { "$($cal.LPass)" } 'verify' { (T "vérification {0}") -f "$($cal.VerifyCount)" } default { "$($cal.ValueTxt)" } }
        Write-CalibPassLog $plog $plab
        if ($cal.Stage -eq 'level') { Write-LevelPassLog $cal $u ([int]$cal.LPass) }
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
                elseif ($cal.DiskOnly) { Append-Log ((T 'Contrôle de surface : disquette à écrire défectueuse ({0}) : décision demandée.') -f (Format-CalibSurfaceVerdict $sf $mc)) }
                else { Append-Log ((T "Contrôle de surface : disquette de calibration douteuse ({0}) : décision demandée.") -f (Format-CalibSurfaceVerdict $sf $mc)) }
                $redo = [bool]($script:CalRedo -and $script:CalRedo.Stage -eq 'running')
                if ($cal.DiskOnly) {
                    # 12.8 (S3) : mesure complete de cette disquette : la disquette mesuree est celle a ecrire, ni disquette
                    # sacrifiee ni changement de disquette : fenetre « Disquette a ecrire defectueuse » de la calibration
                    # rapide (« Ecrire quand meme », « Arreter », fermeture = Arreter)
                    $opt = @{ Change = $false; SwapBox = $false; Variant = 'level'; Title = $(if ($spd) { (T 'Contrôle de surface') } else { (T 'Disquette à écrire défectueuse') }); GoText = (T 'Écrire quand même')
                              Speed = $spd; States = (Get-CalibSurfaceStates $sf $mc) }
                    $txt = Get-LevelSurfaceText $sf $mc ([bool]$script:Restore) $spd $notes -Disk
                }
                else {
                    $opt = Get-CalibSurfaceOptions ([bool]$script:Restore) $redo ($script:AfterCalib -eq 'write') ([bool]$cal.Swap)
                    if ($spd) { $opt.Speed = $true; $opt.Change = $false; $opt.SwapBox = $false }
                    $opt.States = Get-CalibSurfaceStates $sf $mc    # 12.8 (lot 5, D15) : icones d etat de frmCalibSurface
                    $txt = Get-CalibSurfaceText $sf $opt $std ([bool]$cal.AutoStart) -Extra @($mc.Lines) -Notes @($notes) -Medium $mc -Hd $hdFam
                }
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
        if (Start-DiskReach $cal) { return }       # 12.8 (S3-HIGH) : mesure complete de cette disquette seulement
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'bracket') {
        foreach ($u in $cal.Units) { if ($u.Bracket.Count -gt 0) { [void](Set-CalibEstimates $u (T 'Après encadrement : ')) } }
        if (Start-DiskReach $cal) { return }       # 12.8 (S3-HIGH) : mesure complete de cette disquette seulement
        if (Start-CalibDensify $cal) { return }
        Start-CalibFit $cal; return
    }
    if ($cal.Stage -eq 'reach') {
        # 12.8 (S3-HIGH) : apres la mesure directe, zero recalcule par Get-CalibZero sur la corde des deux ecritures les plus
        # proches (plafond des passes de mesure et estimation ecrite), au lieu de l extrapolation au-dela de CalMaxNs
        foreach ($u in $cal.Units) { if ($u.Reach.Count -gt 0) { [void](Set-CalibEstimates $u (T 'Après mesure directe : ')); Write-DiskReachLog $u } }
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
    # 12.8 (VAL01) : apres la passe du nouvel essai : correction sans effet, valeur d avant retablie (Restore-CalibRetestNoEffect)
    if ([int]$cal.Retests -gt 0) { Restore-CalibRetestNoEffect $cal }
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
    # Renvoie @{ Go ; Skip } : plans @{ U ; NonConv ; Targets ; Why ; Values ; Profile ; List ; Corr ; NcR } (Skip : NonConv,
    # Why). NcR (12.8, VAL01) : residus juges et valeurs ecrites avant le nouvel essai (NonConvR), pour la correction sans
    # effet (Restore-CalibRetestNoEffect).
    $go = @(); $skip = @()
    $surf = [bool](($cal.SurfKept -and $cal.Surf -and -not (Test-CalibSpeedOnly $cal.Surf $cal.Medium)) -or ($cal.Surf -and $cal.Surf.Defective -and -not $cal.SurfGross))
    $wmax = [int]$cal.WriteMax
    foreach ($u in @($cal.Units)) {
        if (-not $u.Fit -or -not $u.Profile) { continue }
        $w = Get-CalibWarnings $u ([int]$cal.MaxCyl)
        $nc = [int[]]@(@($w.NonConvC) | Where-Object { $null -ne $_ })
        if ($nc.Count -eq 0) { continue }
        $p = @{ U = $u; NonConv = $nc; Targets = @(); Why = ''; Values = $null; Profile = ''; List = @(); Corr = 0; NcR = $w.NonConvR }
        $dft = $w.Drift
        if ($surf) { $p.Why = (T 'disquette de calibration douteuse au contrôle de surface') }
        # 12.8 (S3-HIGH) : derive du dernier intervalle (Get-CalibDriftStep : apres un nouvel essai, la derive mesuree est
        # cumulee depuis le repere du jugement ; avant le premier, DriftBase est vide : derive mesuree telle quelle)
        elseif ($dft.Use -and [math]::Abs((Get-CalibDriftStep $u $dft)) -gt 2.0 * [double]$script:CalResidual) { $p.Why = (T 'forte dérive du lecteur entre deux vérifications ({0} ns)') -f ('{0:+0.0;-0.0;0.0}' -f (Get-CalibDriftStep $u $dft)) }
        elseif (-not $dft.Use -and $u.VerifyPrev -and $u.VerifyPrev.Count -gt 0) { $p.Why = (T 'dérive du lecteur non retirée (témoins insuffisants)') }
        elseif (@(@($w.Contra) | Where-Object { $null -ne $_ }).Count -gt 0) { $p.Why = (T "zone non reproductible d'une vérification à l'autre") }
        elseif (@($w.NonRepro).Count -gt 0) { $p.Why = (T "cylindres non reproductibles d'une vérification à l'autre") }
        if ($p.Why) { $skip += $p; continue }
        $sl = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [double]$u.Slope } else { -2.0 }
        $vals = @($u.Fit.Values)
        $delta = @{}
        foreach ($k in @($u.Verify.Keys)) { $c = [int]$k; if (@($u.Outliers) -notcontains $c -and $c -lt $vals.Count) { $delta[$c] = 0.0 } }
        $lim = @(); $full = @(); $kept = @()
        foreach ($c in $nc) {
            if ($c -ge $vals.Count) { continue }
            if ($wmax -gt 0 -and $null -ne $u.Writes -and 1 + [int]$u.Writes[$c] -gt $wmax) { $full += $c; continue }
            # 12.8 (S3-HIGH) : mesure complete de cette disquette : cylindre d une correction sans effet a un nouvel essai
            # precedent (RtKept) : aucun progres, plus de nouvel essai
            if ($cal.DiskOnly -and @($u.RtKept) -contains $c) { $kept += $c; continue }
            if ($w.NonConvR -and $w.NonConvR.ContainsKey($c)) {
                $r = [double]$w.NonConvR[$c].R
                $z = [math]::Round([double]$w.NonConvR[$c].P - $r / $sl, 0)
                if (($r -gt 0 -and $z -ge [double]$script:CalHardNs) -or ($r -lt 0 -and $z -le 0)) {
                    # 12.8 (S3-HIGH) : mesure complete de cette disquette : valeur visee ramenee a la borne de cette disquette
                    # (ou a 0) si la valeur ecrite n y est pas encore ; au-dela, reserve « plafond atteint » (Get-CalibWarnings)
                    $pw = [double]$w.NonConvR[$c].P
                    if ($cal.DiskOnly -and $r -gt 0 -and $pw -lt [double]$script:CalHardNs) { $z = [double]$script:CalHardNs }
                    elseif ($cal.DiskOnly -and $r -lt 0 -and $pw -gt 0) { $z = 0.0 }
                    else { $lim += $c; continue }
                }
                $delta[$c] = $z - [double]$vals[$c]
            } else { $delta[$c] = 0.0 }               # non relu : relu a sa valeur
            $p.Targets += $c
        }
        $wTxt = (T 'pistes déjà écrites le nombre maximal de fois annoncé ({0})') -f "$wmax"
        $lTxt = (T 'précompensation visée hors de ses limites (0 ou {0} ns)') -f "$($script:CalHardNs)"
        if ($lim.Count) { $skip += @{ U = $u; NonConv = [int[]]$lim; Why = $lTxt } }
        if ($full.Count) { $skip += @{ U = $u; NonConv = [int[]]$full; Why = $wTxt } }
        if ($kept.Count) { $skip += @{ U = $u; NonConv = [int[]]$kept; Why = (T "correction sans effet au nouvel essai précédent : aucun progrès") } }
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
        # 12.8 (S3-HIGH) : mesure complete de cette disquette, a partir du deuxieme nouvel essai : cylindre vise dont la
        # valeur ne change pas (bornee par ses voisins verifies dans le sens du segment) : aucun progres possible, plus de
        # nouvel essai (le premier nouvel essai le relit a sa valeur, comme la calibration de reference)
        if ($cal.DiskOnly -and [int]$cal.Retests -ge 1) {
            $same = [int[]]@($p.Targets | Where-Object { [int]$newVals[$_] -eq [int]$vals[$_] })
            if ($same.Count -gt 0) {
                $skip += @{ U = $u; NonConv = $same; Why = (T "valeur visée inchangée, bornée par les cylindres vérifiés voisins : aucun progrès") }
                $p.Targets = @($p.Targets | Where-Object { $same -notcontains [int]$_ })
                if ($p.Targets.Count -eq 0) { continue }
            }
        }
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
    # 12.8 (S3-HIGH) : mesure complete de cette disquette : CalDiskMaxRetest nouveaux essais au plus, jusqu a la convergence ;
    # arret des que tous les cylindres sont dans la tolerance (plan vide), ou sans progres (cylindres d une correction sans
    # effet, RtKept : exclus du plan). Calibration complete de reference : CalMaxRetest, inchange
    if (-not $cal) { return $false }
    $maxRt = if ($cal.DiskOnly) { [int]$script:CalDiskMaxRetest } else { [int]$script:CalMaxRetest }
    if ([int]$cal.Retests -ge $maxRt) {
        if ($cal.DiskOnly -and [int]$cal.Retests -gt 0) {
            $left = @(foreach ($u in @($cal.Units)) { if (-not $u.Fit -or -not $u.Profile) { continue }; $nc = [int[]]@(@((Get-CalibWarnings $u ([int]$cal.MaxCyl)).NonConvC) | Where-Object { $null -ne $_ }); if ($nc.Count) { "$($u.Prefix)$(Format-CylList $nc)" } })
            if ($left.Count -gt 0) { Append-Log ((T "Mesure complète : nombre maximal de nouveaux essais atteint ({0}) ; cylindres encore non convergés : {1}.") -f "$maxRt", ($left -join ' ; ')) }
        }
        return $false
    }
    $plan = Get-CalibRetestPlan $cal
    foreach ($p in @($plan.Skip)) { Append-Log ($p.U.Prefix + ((T "Calibration : pas de nouvel essai automatique des cylindres non convergés {0} : {1}.") -f (Format-CylList ([int[]]@($p.NonConv))), "$($p.Why)")) }
    if (@($plan.Go).Count -eq 0) { return $false }
    $cal.Retests = 1 + [int]$cal.Retests
    $vLast = [int]$cal.VerifyCount             # derniere verification avant le nouvel essai
    $cal.VerifyCount++
    $cal.TotalPasses = $cal.PassesDone + 1
    $lt = (@($plan.Go | ForEach-Object { "$($_.U.Prefix)$(Format-CylList ([int[]]@($_.Targets)))" })) -join ' ; '
    if ($cal.DiskOnly) {
        # 12.8 (S3-HIGH) : une ligne par passe de nouvel essai, numerotee, avec les cylindres vises et leurs valeurs (avant -> apres)
        $lv = (@($plan.Go | ForEach-Object { $pp = $_; $ov = @($pp.U.Fit.Values); "$($pp.U.Prefix)" + ((@($pp.Targets | ForEach-Object { "c$_ $([int]$ov[[int]$_]) -> $([int]$pp.Values[[int]$_])" })) -join ', ') })) -join ' ; '
        Append-Log ((T "Mesure complète : nouvel essai automatique {0}/{1} des cylindres non convergés (vérification {2}), valeurs écrites (ns, avant -> après) : {3}") -f "$($cal.Retests)", "$maxRt", "$($cal.VerifyCount)", "$lv")
    }
    else { Append-Log ((T "Calibration : nouvel essai automatique des cylindres non convergés {0} (vérification {1})") -f "$lt", "$($cal.VerifyCount)") }
    foreach ($u in @($cal.Units)) { $u.InRetest = $false; $u.VerifyList = @() }
    # 12.8 (VAL01) : derniere verification d avant le nouvel essai (erreur gw pendant la passe : Restore-CalibRetestPre)
    $cal.RtVLast = $vLast
    foreach ($p in @($plan.Go)) {
        $u = $p.U
        # 12.8 (VAL01) : etat de la derniere verification, avant le repere du jugement et la correction (RtPre : erreur gw
        # pendant la passe, jugement de cette verification garde) ; references gardees, chaque champ est remplace ci-dessous
        # (jamais modifie en place), Verify et VerifyP copies
        $u.RtPre = @{ Verify = $u.Verify.Clone(); VerifyP = $u.VerifyP.Clone(); VerifyPrev = $u.VerifyPrev; ReadLast = $u.ReadLast; Witness = @($u.Witness)
                      Fit = $u.Fit; Profile = $u.Profile; WitCand = $u.WitCand; WitMin = $u.WitMin
                      DriftBase = $u.DriftBase; DriftBaseV = $u.DriftBaseV; DriftOrigV = $u.DriftOrigV }    # 12.8 (S3-HIGH)
        $dft = Get-VerifyDrift $u
        # Derive deja mesuree a la derniere verification (DriftBase, DriftBaseV) : celle du nouvel essai se compte depuis le
        # meme repere, cumulee ; la reserve « derive » de Complete-PrecompCalib juge le dernier intervalle seul. Sans derive
        # mesuree : aucune (chemins de la 12.7). 12.8 (S3-HIGH) : DriftOrigV, verification du repere (celle d avant la
        # premiere verification ciblee), gardee d un nouvel essai a l autre (mesure complete de cette disquette)
        $u.DriftBase = $null; $u.DriftBaseV = $null
        if ($dft.Use) { $u.DriftBase = [double]$dft.D; $u.DriftBaseV = $vLast; if ($null -eq $u.DriftOrigV) { $u.DriftOrigV = $vLast - 1 } }
        foreach ($k in @($u.Verify.Keys)) {
            $c = [int]$k
            # Temoin : jugement sur sa mesure precedente ; sa derniere mesure brute reste celle du journal (LogRaw, lu
            # seulement par la ligne « Residu apres verification » ; Res de la courbe : mesure precedente, comme en 12.7)
            if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $m = $u.VerifyPrev[$c].Meas.Clone(); $m.LogRaw = [double]$u.Verify[$c].Shift; $u.Verify[$c] = $m; $u.VerifyP[$c] = [int]$u.VerifyPrev[$c].P }
            elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $m = $u.Verify[$c]; $u.Verify[$c] = @{ Shift = [double]$m.Shift - [double]$dft.D; SE = $m.SE; Score = $m.Score; Raw = [double]$m.Shift } }
        }
        $u.VerifyPrev = @{}; $u.ReadLast = @{}; $u.Witness = @()
        # 12.8 (VAL01) : avant la correction, pour la correction sans effet (Restore-CalibRetestNoEffect) : courbe, estimations
        # (Set-CalibEstimates les remplace), residus juges des cylindres vises (NcR) et, pour chaque cylindre relu, mesure dans
        # le repere du jugement, valeur ecrite et mesures des passes (Add-CalibPoint les complete en place : copie)
        $cy = @{}
        foreach ($c in @($p.List)) {
            $ci = [int]$c; $has = $u.Verify.ContainsKey($ci)
            $rs = @{}; if ($u.Results.ContainsKey($ci)) { foreach ($x in @($u.Results[$ci].Keys)) { $rs[$x] = $u.Results[$ci][$x] } }
            $cy[$ci] = @{ Has = $has; M = $(if ($has) { $u.Verify[$ci] } else { $null }); P = $(if ($u.VerifyP.ContainsKey($ci)) { $u.VerifyP[$ci] } else { $null }); Res = $rs }
        }
        $bf = @{}
        foreach ($c in @($p.Targets)) { $ci = [int]$c; if ($p.NcR -and $p.NcR.ContainsKey($ci) -and $u.Verify.ContainsKey($ci)) { $bf[$ci] = @{ R = [double]$p.NcR[$ci].R; P = $p.NcR[$ci].P; SE = $u.Verify[$ci].SE } } }
        $u.RtSnap = @{ Fit = $u.Fit; Profile = $u.Profile; Est = $u.Est; Sig = $u.Sig; Kind = $u.Kind; Own = $u.Own; Slope = $u.Slope; Cyl = $cy; Before = $bf
                       VKeys = [int[]]@($u.Verify.Keys | ForEach-Object { [int]$_ } | Where-Object { @($u.Outliers) -notcontains $_ }) }
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

function Restore-CalibRetestNoEffect($cal) {
    # 12.8 (VAL01, decisions128.md) : apres la passe du nouvel essai, correction sans effet : un cylindre vise encore non
    # converge dont le residu juge n a pas bouge, au bruit pres, alors que sa valeur ecrite a change, reprend sa valeur
    # d avant le nouvel essai, avec la mesure, les mesures des passes et l estimation qui vont avec (RtSnap,
    # Start-CalibRetest) : il reste non converge, juge sur sa derniere verification d avant (repere du jugement).
    # Critere, par cylindre : dP = valeur ecrite a la passe - valeur d avant, dR = residu juge apres - residu juge avant ;
    # seuil s = max(2 ns ; 2 x ecart-type de dR), ecart-type de dR = racine(SE avant^2 + SE apres^2), au moins racine(2) x
    # bruit de mesure estime de l unite (Get-ResidualFlags : dispersion des residus voisins, bien plus forte que l erreur-type
    # d une piste) ; sans effet si |dR| < s et si la correction devait deplacer le residu d au moins s (|pente x dP| >= s ;
    # sinon, effet trop faible pour etre distingue du bruit : rien n est retabli). Courbe : valeurs d avant si aucun
    # cylindre vise n a repondu, sinon corrections des seuls cylindres qui ont repondu (Add-CurveCorrection, segments
    # d avant) ; retablissement abandonne si un cylindre mesure ne garde ni sa valeur de la passe ni celle d avant
    # (monotonie avec un voisin corrige : ligne de journal). Ecritures par piste : inchangees (pistes ecrites).
    # FIXVAL01 : cylindres retablis gardes dans RtKept : Get-CalibWarnings les juge NON CONVERGES tant qu ils sont hors
    # tolerance, meme si leur voisinage apres la passe (cylindres corriges, bruit) en ferait un ecart local non retenu.
    foreach ($u in @($cal.Units)) {
        $s = $u.RtSnap
        if ($null -ne $u.RtSnap) { $u.RtSnap = $null }
        if ($null -ne $u.RtPre) { $u.RtPre = $null }
        if (-not $u.InRetest -or -not $s -or $s.Before.Count -eq 0) { continue }
        $w = Get-CalibWarnings $u ([int]$cal.MaxCyl)
        $sl = if ($null -ne $s.Slope -and [double]$s.Slope -lt -0.2) { [double]$s.Slope } else { -2.0 }
        $sig = [double]$w.Sigma
        $old = [int[]]@($s.Fit.Values); $cur = [int[]]@($u.Fit.Values)
        $no = @(); $thrMax = 0.0
        foreach ($c in @($s.Before.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
            if (-not $w.NonConvR -or -not $w.NonConvR.ContainsKey($c) -or $c -ge $cur.Count) { continue }
            $b = $s.Before[$c]; $a = $w.NonConvR[$c]
            if ($null -eq $a.P -or $null -eq $b.P) { continue }
            $dP = [double]$a.P - [double]$b.P
            if ([math]::Abs($dP) -lt 1) { continue }
            $q = 0.0
            foreach ($x in @($b.SE, $u.Verify[$c].SE)) { if ($null -ne $x -and -not [double]::IsNaN([double]$x)) { $q += [double]$x * [double]$x } }
            $sd = [math]::Sqrt($q)
            if (-not [double]::IsNaN($sig)) { $sd = [math]::Max($sd, [math]::Sqrt(2.0) * $sig) }
            $thr = [math]::Max(2.0, 2.0 * $sd)
            if ([math]::Abs([double]$a.R - [double]$b.R) -lt $thr -and [math]::Abs($sl * $dP) -ge $thr) { $no += $c; $thrMax = [math]::Max($thrMax, $thr) }
        }
        if ($no.Count -eq 0) { continue }
        $resp = @(@($s.Before.Keys) | ForEach-Object { [int]$_ } | Where-Object { $no -notcontains $_ -and $_ -lt $cur.Count -and $cur[$_] -ne $old[$_] })
        $full = ($resp.Count -eq 0)
        if ($full) { $new = [int[]]$old.Clone() }
        else {
            $delta = @{}
            foreach ($c in @($s.VKeys)) { if ($c -lt $old.Count) { $delta[[int]$c] = 0.0 } }
            foreach ($c in $resp) { $delta[$c] = [double]$cur[$c] - [double]$old[$c] }
            $new = [int[]](Add-CurveCorrection $old $delta $s.Fit.Segs)
        }
        # Coherence : chaque cylindre mesure garde la valeur de sa mesure (celle de la passe, ou celle d avant retablie)
        $ok = ($new.Count -eq $cur.Count)
        foreach ($c in @($no)) { if ($ok -and $new[$c] -ne $old[$c]) { $ok = $false } }
        foreach ($k in @($u.Verify.Keys)) {
            $c = [int]$k
            if (-not $ok -or $c -ge $new.Count -or $new[$c] -eq $cur[$c]) { continue }
            if (-not ($new[$c] -eq $old[$c] -and $s.Cyl.ContainsKey($c))) { $ok = $false }
        }
        if (-not $ok) {
            Append-Log ($u.Prefix + ((T "Calibration : correction du nouvel essai sans effet aux cylindres {0}, valeur d'avant le nouvel essai non rétablie : la courbe ne resterait pas monotone avec les cylindres corrigés voisins.") -f (Format-CylList ([int[]]$no))))
            continue
        }
        for ($c = 0; $c -lt $new.Count; $c++) {
            if ($new[$c] -eq $cur[$c] -or -not $s.Cyl.ContainsKey($c)) { continue }
            $y = $s.Cyl[$c]
            if ($y.Has) { $u.Verify[$c] = $y.M; if ($null -ne $y.P) { $u.VerifyP[$c] = $y.P } } else { [void]$u.Verify.Remove($c); [void]$u.VerifyP.Remove($c) }
            [void]$u.VerifyPrev.Remove($c); [void]$u.ReadLast.Remove($c)
            $u.VerifyList = @(@($u.VerifyList) | Where-Object { [int]$_ -ne $c })
            $u.Results[$c] = $y.Res
            foreach ($f in 'Est', 'Sig', 'Kind', 'Own') { if ($s[$f].ContainsKey($c)) { $u[$f][$c] = $s[$f][$c] } }
        }
        if ($full) { $u.Fit = $s.Fit; $u.Profile = $s.Profile; $u.Slope = $s.Slope }
        else {
            $base = ([string]$u.Fit.Model) -replace '\+c$', ''
            $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $new; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers }
            $u.Profile = Build-CurveProfile $new
        }
        # 12.8 (S3-HIGH) : mesure complete de cette disquette, plusieurs nouveaux essais : cylindres retablis aux essais
        # precedents gardes (union ; un seul nouvel essai : $no, comme avant)
        $u.RtKept = [int[]]@(@(@($u.RtKept) + @($no)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        Append-Log ($u.Prefix + ((T "Calibration : correction du nouvel essai sans effet aux cylindres {0} (résidu inchangé à {1} ns près alors que la valeur écrite a changé) : valeur d'avant le nouvel essai rétablie, ces cylindres restent non convergés.") -f (Format-CylList ([int[]]$no)), (Format-LevelNum $thrMax)))
    }
}

function Restore-CalibRetestPre($cal) {
    # 12.8 (VAL01) : passe du nouvel essai interrompue par une erreur gw (Stop-PrecompCalib -GwError) : unites remises dans
    # l etat de leur derniere verification (RtPre, Start-CalibRetest), avant le repere du jugement et la correction ; les
    # mesures des passes n ont pas change (la passe n a pas ete analysee). $true si une passe du nouvel essai etait en cours.
    if (-not $cal -or [string]$cal.Stage -ne 'verify' -or [int]$cal.Retests -le 0 -or $null -eq $cal.RtVLast) { return $false }
    $us = @($cal.Units | Where-Object { $_.RtPre })
    if ($us.Count -eq 0) { return $false }
    foreach ($u in $us) {
        $s = $u.RtPre
        $u.Verify = $s.Verify; $u.VerifyP = $s.VerifyP; $u.VerifyPrev = $s.VerifyPrev; $u.ReadLast = $s.ReadLast; $u.Witness = @($s.Witness)
        # 12.8 (S3-HIGH) : derive de repere d avant cette passe (vide avant le premier nouvel essai, comme avant)
        $u.Fit = $s.Fit; $u.Profile = $s.Profile; $u.WitCand = $s.WitCand; $u.WitMin = $s.WitMin; $u.DriftBase = $s.DriftBase; $u.DriftBaseV = $s.DriftBaseV; $u.DriftOrigV = $s.DriftOrigV
        $u.RtPre = $null; $u.RtSnap = $null
    }
    foreach ($u in @($cal.Units)) { $u.InRetest = $false; $u.VerifyList = @() }
    $cal.VerifyCount = [int]$cal.RtVLast; $cal.RtVLast = $null
    $cal.TotalPasses = $cal.PassesDone
    return $true
}

function Complete-CalibRetestEnd {
    # 12.8 (VAL01) : fin differee d une calibration dont la passe du nouvel essai a echoue (Stop-PrecompCalib -GwError),
    # appelee par le minuteur principal une fois gw fini et sans autre fenetre modale : comme la fin d une derniere
    # verification sans nouvel essai (zones contradictoires, puis Complete-PrecompCalib et sa fenetre de decision)
    $cal = $script:Cal
    if (-not $cal -or -not $cal.RetestEnd) { return }
    $cal.RetestEnd = $false
    foreach ($u in $cal.Units) { [void](Set-VerifyContra $u) }
    $cal.TotalPasses = $cal.PassesDone
    Complete-PrecompCalib
}

function Complete-PrecompCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Calibration terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    if (@($cal.Units | Where-Object { -not $_.Profile -or -not $_.Fit }).Count -gt 0) {
        if ($cal.DiskOnly) { Reset-DiskHardNs }     # 12.8 (S3) : borne de precompMaxNs retablie
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
        $kn0 = $kinds.Count      # 12.8 (S3) : reserves de cette unite (memoire de la marque, Complete-DiskMeasure)
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
                $lt = (T "Dérive du lecteur depuis la vérification {0}, nouvel essai compris : {1} ± {2} ns de décalage commun sur {3} cylindres témoins (dispersion {4}), soit {5} ns jusqu'à la vérification {6}, puis {7} ns jusqu'à la vérification {8}.") -f "$(if ($null -ne $u.DriftOrigV) { [int]$u.DriftOrigV } else { [int]$u.DriftBaseV - 1 })", ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp", ('{0:+0.0;-0.0;0.0}' -f [double]$u.DriftBase), "$([int]$u.DriftBaseV)", ('{0:+0.0;-0.0;0.0}' -f $dIv), "$($cal.VerifyCount)"
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
            # 12.8 (S3) : mesure complete de cette disquette : pas de disquette sacrifiee a conseiller
            if ($cal.DiskOnly) { Append-Log ($u.Prefix + ((T "Mesure non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure de cette disquette à ces cylindres.") -f ($u.Warn.NonConv -join ', '))) }
            else { Append-Log ($u.Prefix + ((T "Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres. Refaire la calibration en test fin, ou sur une autre disquette sacrifiée.") -f ($u.Warn.NonConv -join ', '))) }
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
            # 12.8 (S3) : mesure complete de cette disquette : pas de support de calibration a mettre en cause
            # 12.8 (S3-HIGH) : cylindres mesures autour de leur besoin par la mesure directe (Start-DiskReach)
            $rch = [int[]]@(if ($u.Reach) { @($u.Reach.Keys | ForEach-Object { [int]$_ } | Sort-Object) })
            if ($cal.DiskOnly -and $rch.Count -gt 0) { Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe de cette disquette jusqu'à {2} ns, mesurée directement autour du besoin aux cylindres {3} (mesure directe), puis contrôlée par la vérification.") -f "$($script:CalMaxNs)", (Format-CylList ([int[]]$u.Warn.Beyond)), "$bmax", (Format-CylList $rch))) }
            elseif ($cal.DiskOnly) { Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe de cette disquette jusqu'à {2} ns, déduite par extrapolation des mesures{3}, puis contrôlée par la vérification.") -f "$($script:CalMaxNs)", (Format-CylList ([int[]]$u.Warn.Beyond)), "$bmax", "$how")) }
            else { Append-Log ($u.Prefix + ((T "Besoin au-delà de {0} ns, plafond des passes de mesure, aux cylindres {1} : courbe jusqu'à {2} ns, déduite par extrapolation des mesures{3}, puis contrôlée par la vérification. Un besoin aussi fort est inhabituel : si une disquette en bon état ne l'atteint pas, le support de calibration est probablement fatigué.") -f "$($script:CalMaxNs)", (Format-CylList ([int[]]$u.Warn.Beyond)), "$bmax", "$how")) }
        }
        if ($cal.DiskOnly) {
            # 12.8 (S3) : courbe de cette disquette au-dela de 400 ns (Get-DiskOverNs) : reserve d information, controle apres
            # ecriture impose (Complete-DiskMeasure) ; plafond porte par disquette (Get-DiskHardNs)
            $thr = Get-DiskOverNs
            $ov = [int[]]@(0..(@($u.Fit.Values).Count - 1) | Where-Object { [int]$u.Fit.Values[$_] -gt $thr })
            if ($ov.Count -gt 0) {
                $top = [int](@($u.Fit.Values) | Measure-Object -Maximum).Maximum
                Append-Log ($u.Prefix + ((T "Courbe de cette disquette au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns) : plafond porté à {3} ns pour cette disquette seulement ; contrôle après écriture imposé.") -f "$thr", (Format-CylList $ov), "$top", "$($cal.HardNs)"))
                $issues.Add($u.Prefix + ((T "courbe de cette disquette au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns, plafond porté à {3} ns pour cette disquette seulement) : contrôle après écriture imposé") -f "$thr", (Format-CylList $ov), "$top", "$($cal.HardNs)")); $kinds.Add('over')
            }
        }
        $bk = @($u.Warn.Breaks)
        if ($bk.Count -ge 2) { Append-Log ($u.Prefix + ((T "Changement de sens du besoin entre c{0} et c{1} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])", "$($bk[1])")) }
        elseif ($bk.Count -eq 1) { Append-Log ($u.Prefix + ((T "Le besoin redescend à partir de c{0} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])")) }
        if ($u.Warn.Dev.Count -gt 0) { Append-Log ($u.Prefix + ((T "Écart à la courbe de plus de {1} ns et de trois incertitudes (courbe moins mesure) : {0}.") -f ($u.Warn.Dev -join ', '), (Format-UiNum $script:CalDevNs))) }
        # Calibration precedente du meme lecteur (encore en memoire, remplacee plus bas) : la forme de la courbe tient au
        # lecteur, son niveau au support ; un ecart net, ou un plafond nouveau, designe le support de calibration
        $pkey = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $prev = $script:PrecompCurves[$pkey]
        # 12.8 (S3-FIX, M4) : mesure complete de cette disquette : reference reellement utilisee par la mesure (Get-DiskRefUnit :
        # courbe par tete, ou courbe commune pour les deux tetes en restauration), celle de l enregistrement 'mesure'
        if ($cal.DiskOnly) { $ru = Get-DiskRefUnit $cal $u; $prev = if ($ru) { $ru.Cv } else { $null } }
        if ($prev -and [string]$prev.Drive -eq [string]$cal.Drive -and @($prev.Values).Count -gt 0 -and $u.Fit) {
            $pv = @($prev.Values); $nv = @($u.Fit.Values); $nn = [math]::Min($pv.Count, $nv.Count)
            if ($nn -gt 0) {
                $dd = @(for ($c = 0; $c -lt $nn; $c++) { [int]$nv[$c] - [int]$pv[$c] })
                $ds = $dd | Measure-Object -Average -Minimum -Maximum
                if ($cal.DiskOnly) {
                    # 12.8 (S3, M4) : la courbe en place est la reference du lecteur, gardee ; ecart de cette disquette, sans
                    # diagnostic du support de calibration
                    Append-Log ($u.Prefix + ((T "Écart de cette disquette à la référence du lecteur ({0}) : {1} ns en moyenne (de {2} à {3} ns).") -f "$($prev.Date)", ('{0:+0;-0;0}' -f [math]::Round($ds.Average, 0)), ('{0:+0;-0;0}' -f $ds.Minimum), ('{0:+0;-0;0}' -f $ds.Maximum)))
                    $nn = 0
                }
                else { Append-Log ($u.Prefix + ((T "Écart avec la calibration précédente du lecteur {0} ({1}) : {2} ns en moyenne (de {3} à {4} ns).") -f "$($cal.Drive)", "$($prev.Date)", ('{0:+0;-0;0}' -f [math]::Round($ds.Average, 0)), ('{0:+0;-0;0}' -f $ds.Minimum), ('{0:+0;-0;0}' -f $ds.Maximum))) }
            }
            if ($nn -gt 0) {
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
        # et ecart de forme (dispersion apres retrait du niveau) ; donnees pour recaler les seuils sur materiel reel. 12.8 (S3) :
        # pas pour une mesure complete de cette disquette (M4 ci-dessus)
        if (-not $cal.DiskOnly -and $prev -and [string]$prev.Drive -eq [string]$cal.Drive -and $prev.Cyls -and $prev.Ys) {
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
        # 12.8 (S3) : tete sans reserve pour la memoire de la marque (Update-LevelBrandCurve) : aucune reserve de cette unite,
        # sauf la courbe au-dela de 400 ns (reserve d information), convergee
        if ($cal.DiskOnly) {
            $own = @(); for ($ki = $kn0; $ki -lt $kinds.Count; $ki++) { if ($kinds[$ki] -ne 'over') { $own += $kinds[$ki] } }
            $u.DiskOk = [bool]($own.Count -eq 0 -and $u.Warn.NonConv.Count -eq 0)
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
    # 12.8 (S3, c4-design § 4.2) : mesure complete de cette disquette : la reference du lecteur n est pas modifiee (ni
    # copie .bak, ni PrecompCurves, ni abandon des niveaux et des marques) ; fin propre (Complete-DiskMeasure)
    if ($cal.DiskOnly) { Complete-DiskMeasure $cal $issues $kinds $surfIssue; return }
    # 12.8 (lot 1c, point 4) : copie du fichier de configuration avant le remplacement de la reference (toute calibration
    # complete : bouton Calibrer, carte de l Accueil, calibration avant une ecriture, repli du point 3, calibration B,
    # restauration) ; sans courbe a remplacer : rien
    [void](Backup-ConfigBeforeRef @($cal.Units | ForEach-Object { Get-CalibUnitKey $cal $_ }) 'replace')
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
    # 12.8 (lot 1c, § 10.5) : marques memorisees avec la reference remplacee : gardees, mais plus point de depart (date de
    # reference differente) ; une copie .bak retablie ou l abandon de la nouvelle courbe les rend de nouveau valables
    $brOld = @()
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $pc = $prevCal.Curves[$key]
        if ($pc) { $brOld += @(Get-LevelBrandsOfRef $key ([string]$pc.Date) ([string]$cal.Drive)) }
    }
    $brOld = @($brOld | Sort-Object -Unique)
    if ($brOld.Count -gt 0) { Append-Log ((T 'Marques mémorisées avec la référence précédente ({0}) : elles seront mesurées de nouveau à leur prochaine calibration rapide.') -f ($brOld -join ', ')) }
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
            # Calibration faite sur une disquette sacrifiee : la disquette a ecrire est redemandee (frmReinsert). 12.8 (D7) :
            # sans compte a rebours : une ecriture lancee seule ne peut pas savoir quelle disquette est dans le lecteur ;
            # restauration : remise sans delai depuis le lot 2, puis nouvelle sonde de la destination avant l ecriture
            if ($script:Restore) { Enter-RestoreSwapBack; return }
            $lrA = if ($cal.LevelAfter) { Get-LevelRef $cal.Family $cal.Slow $cal.Drive $cal.Image $false -NCyl ([int]$cal.MaxCyl + 1) } else { $null }
            if ($lrA -and -not $lrA.Ok) { Append-Log ((T "Calibration rapide impossible : {0}. Écriture avec la nouvelle calibration complète.") -f "$($lrA.Why)") }
            if ($lrA -and $lrA.Ok) {
                # Reference faite sur la disquette sacrifiee : le niveau de la disquette a ecrire est mesure apres sa remise
                $lr = $lrA
                $lc = if ($lr.Ok) { (@($lr.Units | ForEach-Object { Format-CylList ([int[]]@(@(@($_.LCyls) + @($_.Wit) + @($(if ($null -ne $_.Probe) { $_.Probe }))) | Sort-Object -Unique)) } | Sort-Object -Unique)) -join ' ; ' } else { '-' }
                $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée : elle devient la référence de forme du lecteur {0}.`n`nRetirez la disquette sacrifiée et insérez la disquette à écrire, puis cliquez sur « Mesurer le niveau et écrire » : son niveau de précompensation est mesuré sur les cylindres {1} (2 faces, 1 à 3 écritures du motif par piste), puis l'image est écrite.`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)", "$lc") (T 'Mesurer le niveau et écrire') 'Diagnostic' '' '' '' '' -Seconds 0 -Heading (T 'Insérez la disquette à écrire') -Level 'info' -Picto 'data'
                if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
                if ($lr.Ok) {
                    $script:AfterCalib = 'write'
                    Start-LevelCalib $lr -NoConfirm -NoFallback
                    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration rapide n''a pas été lancée.') }
                    return
                }
            } else {
            $q = Show-TimedConfirm 'frmReinsert' (T 'Calibration precomp') ((T "Calibration terminée.`n`nRetirez la disquette sacrifiée du lecteur {0} et insérez la disquette à écrire, puis cliquez sur « Écrire l'image ».`nAnnuler : l'image n'est pas écrite.") -f "$($cal.Drive)") (T "Écrire l'image") 'Save' '' '' '' '' -Seconds 0 -Heading (T 'Insérez la disquette à écrire') -Level 'info' -Picto 'data'
            if (-not $q.Ok) { Append-Log (T 'Écriture annulée : la disquette à écrire n''a pas été remise après la calibration.'); return }
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
