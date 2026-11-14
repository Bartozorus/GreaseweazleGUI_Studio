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
    # 12.10 : calibration croisee ($script:CalCrossAsk = @{ Src ; Tgt }, pose par Start-CrossCalib ; lu et remis a $null ici,
    # avant toute sortie) : la source (lecteur du bandeau) ecrit, la cible relit, la disquette passe de l un a l autre a la
    # main (Invoke-CalibSwap) ; avertissement sans compte a rebours, case « disquette sacrifiee dans la source » obligatoire
    $cx = $script:CalCrossAsk; $script:CalCrossAsk = $null
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $script:Cal = $null
    # 12.11 (lot LN-b) : avec des lecteurs enregistres, lecteur branche confirme s il y a lieu (Confirm-DriveIdentity, 112) ;
    # refus : calibration non lancee ($script:Cal vide, que lisent les appelants)
    if ($script:DriveReg.Count -gt 0 -and -not (Confirm-DriveIdentity)) { return }
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
    # 12.8.2 (revue) : effacement haute frequence de chaque passe en double densite compris (Get-CalibEraseEst, 150)
    $wu = if ($noWarm) { 0.0 } else { [math]::Max(0.0, [double]$script:CalWarmupMinutes) }
    $estEr = Get-CalibEraseEst ([string]$family -eq 'hd')
    # 12.9 (correction 1) : conditionnement du lecteur avant la passe 1 (double densite, bareme de la famille : Set-CalibScale
    # n est appele qu apres l avertissement) : une ecriture sans relecture de tous les cylindres de l image (2 faces),
    # effacement haute frequence compris, au rythme de la duree estimee (0,7 s par piste et par phase)
    $cond = [bool]$(if ([string]$family -eq 'hd') { $script:CalScaleHd.CalCondPass } else { $script:CalScaleDd.CalCondPass })
    $condMin = if ($cond) { ($maxCyl + 1) * 2 * (0.7 + $estEr) / 60 } else { 0.0 }
    $minutes = [math]::Max(1, [math]::Round($cyls.Count * 2 * (1.4 + $estEr) * $nPassEst / 60 + $condMin + $wu, 0))
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
    $minRetest = Get-CalibRetestMinutes $cyls.Count $maxCyl $fine $estEr
    $body += "`n" + ((T "Si des cylindres restent non convergés, un nouvel essai automatique ajoute au plus {0} min (une passe de vérification ciblée).") -f "$minRetest")
    if ($wu -gt 0) { $body += "`n" + ((T "Préchauffage du lecteur avant la première passe : jusqu'à {0} de lecture sans écriture (moins si le lecteur vient de servir), compris dans la durée estimée.") -f (Format-CalDuration (60 * $wu))) }
    if ($cond) { $body += "`n" + ((T "Avant la première passe, le lecteur est conditionné par une écriture du motif sur les cylindres {0} (2 faces), sans relecture : environ {1} min, comprises dans la durée estimée.") -f "0-$maxCyl", "$([math]::Max(1, [math]::Round($condMin, 0)))") }
    # Courbe remplacee d un autre nombre de cylindres (plus de 4 d ecart, seuil de Get-LevelRef) : la nouvelle s applique
    # ensuite a toutes les images de la famille (meme phrase que la fenetre de la carte Calibration de l Accueil)
    $cvr = $script:PrecompCurves[$(if ($slow) { "${family}_h0" } else { $family })]
    if ($cx) { $cvr = Get-DriveCurve "$($cx.Src)>$($cx.Tgt)" $(if ($slow) { "${family}_h0" } else { $family }) }   # 12.10 : courbe croisee precedente
    if ($cvr -and [math]::Abs(@($cvr.Values).Count - $nCyl) -gt 4) { $body += "`n" + ((T "La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}.") -f "$(@($cvr.Values).Count)", "$nCyl", "$famTxt") }
    # Passes supplementaires possibles : encadrement (1), mesures complementaires du test standard (2, 30 cylindres au plus).
    # Ecritures par piste au plus : $nPassMax, celui de la 12.7. 12.8 (lot 1b) : le nouvel essai des cylindres non converges
    # le respecte (decisions128.md : « nombre d ecritures par piste respecte ») : WriteMax, garde de Get-CalibRetestPlan et
    # de Add-DriftWitnesses ; une piste deja ecrite $nPassMax fois n est ni visee, ni relue, ni temoin. 12.9 (correction 1) :
    # une ecriture de plus par piste, celle du conditionnement du lecteur. 12.9 (banc cal2, G3-01 et G4-01, option A) :
    # calcul 12.9 de la double densite, reconnu au meme indicateur que le conditionnement ($cond : CalCondPass du bareme de
    # la famille, faux en haute densite) : l encadrement commence a 100 ns et prenait l ecriture que la 12.8 partageait
    # entre l encadrement et le nouvel essai, refuse alors aux cylindres encadres. Le nouvel essai est compte a part,
    # CalMaxRetest ecritures de plus (comme les nouveaux essais de la mesure complete, ci-dessous) : fin 7 -> 8, standard
    # 9 -> 10, texte « un encadrement et un nouvel essai ». Haute densite (CalibCalcHd 12.7) : plafond (6, 8) et texte
    # inchanges
    $nPassMax = $nPassEst + 1 + $(if ($fine) { 0 } else { 2 }) + $(if ($cond) { 1 } else { 0 }) + $(if ($cond) { [int]$script:CalMaxRetest } else { 0 })
    $extra = if ($cond -and $fine) { (T 'si la courbe demande un encadrement et un nouvel essai des cylindres non convergés') }
             elseif ($cond) { (T 'si la courbe demande un encadrement, des mesures complémentaires (30 cylindres au plus) et un nouvel essai des cylindres non convergés') }
             elseif ($fine) { (T 'si la courbe demande un encadrement ou un nouvel essai des cylindres non convergés') }
             else { (T 'si la courbe demande un encadrement, des mesures complémentaires (30 cylindres au plus) ou un nouvel essai des cylindres non convergés') }
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
        $nPassMax = $nPassEst + 2 + [int]$script:CalDiskMaxRetest + $(if ($cond) { 1 } else { 0 })
        $extra = (T 'si la courbe demande un encadrement, une mesure directe au-delà de {0} ns ou de nouveaux essais des cylindres non convergés') -f "$mxDisk"
        $minDisk = $minutes + (2 + [int]$script:CalDiskMaxRetest) * $minRetest
    }
    # 12.9 (correction 1) : l ecriture de conditionnement du lecteur est nommee
    $wear = if ($cond) { (T "ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues et une écriture de conditionnement du lecteur ; jusqu'à {1} écritures par piste {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer.") -f "$nPassEst", "$nPassMax", "$extra" }
            else { (T "ATTENTION : la calibration écrit le motif de test sur les mêmes pistes à chaque passe ({0} passes prévues, jusqu'à {1} {2}). Ces écritures répétées sollicitent le support magnétique et peuvent le fatiguer.") -f "$nPassEst", "$nPassMax", "$extra" }
    # 12.9 (S1) : delai de l avertissement (Get-CalibConfirmSeconds) : sans delai, pas de mention du compte a rebours
    $cfSec = Get-CalibConfirmSeconds ([string]$script:AfterCalib) ([bool]$script:CalibUnattended)
    $choice = if ($toWrite -and $cfSec -gt 0) { (T "Pour épargner {0}, cochez la case ci-dessous (le compte à rebours s'arrête), remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée.") -f "$target" }
              elseif ($toWrite) { (T "Pour épargner {0}, cochez la case ci-dessous, remplacez-la par une disquette sacrifiée (sans valeur, jamais l'original), puis cliquez sur « Lancer la calibration » : après la calibration, l'application vous demandera de remettre {0}. Sinon, la calibration utilise la disquette insérée.") -f "$target" }
              else { (T 'Insérez de préférence une disquette sacrifiée (vierge ou sans valeur), puis validez.') }
    $swapLabel = if ($toWrite) { (T "J'ai inséré une disquette sacrifiée : me redemander {0} après la calibration") -f "$target" } else { '' }
    if ($cx) {
        # 12.10 : calibration croisee : texte en tete (lecteurs, echanges de disquette estimes, duree hors echanges), case
        # obligatoire (la disquette est dans la source), jamais de demarrage automatique ; reponse au journal
        $sw = Get-CrossSwapEstimate $nPassEst $fine ([int]$script:CalMaxRetest) ([int]$script:CalMaxVerify)   # 12.11 : au moins : une seule verification
        $ci = ((T "Calibration croisée : le lecteur {0} écrit le motif de test, le lecteur {1} le relit. Avant chaque relecture, puis avant l'écriture suivante, l'application vous demande de déplacer la disquette d'un lecteur à l'autre : {2} échanges au moins, {3} au plus. La durée estimée ne compte pas ces échanges. La courbe obtenue sert aux écritures du lecteur {0} destinées au lecteur {1} ; la courbe propre du lecteur {0} n'est pas modifiée.") -f "$($cx.Src)", "$($cx.Tgt)", "$($sw.Min)", "$($sw.Max)") + "`n`n"
        $rc = Show-TimedConfirm 'frmCalibConfirm' (T 'Calibration precomp') ($Intro + $ci + $body + "`n`n" + $wear) (T 'Lancer la calibration') 'Diagnostic' '' ((T "J'ai inséré une disquette sacrifiée (sans valeur, jamais l'original) dans le lecteur {0}, celui qui écrit") -f "$($cx.Src)") '' (T "Pas de démarrage automatique : cochez la case, puis cliquez sur « Lancer la calibration ».") -Seconds 0 -NeedCheck -Heading (T 'Calibration croisée : la disquette sacrifiée reçoit le motif de test') -Level 'warn' -Picto 'warn'
        $ans = @{ Ok = ($rc.Ok -and $rc.Checked); Swap = $false; Auto = $false }
        Append-Log $(if ($ans.Ok) { (T "Calibration croisée : lancée (case « disquette sacrifiée dans le lecteur {0} » cochée).") -f "$($cx.Src)" } else { (T 'Calibration croisée : annulée.') })
    } elseif ($redo) {
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
    } else { $ans = Show-CalibConfirm ($Intro + $auto + $body + "`n`n" + $wear + "`n`n" + $choice) $swapLabel -Seconds $cfSec }
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
    # 400 ns) pendant la mesure complete, retablie a sa fin (Reset-DiskHardNs). 12.11 : calculee ici, le motif cree, sur les cellules de la piste ecrite (CapBits, Get-DiskCapBits : piste la plus longue de l image, codec du format, ou format gw au-dela de 250 kbit/s ; 0 si elle n est pas connue : 470 ns, comme en 12.10)
    if ($do) { $do.CapBits = Get-DiskCapBits ([int]$pat.CapBits) ([string]$cmbWFmt.Text) ([bool]$pat.Known); $do.HardNs = Get-DiskHardNs ([int]$do.CapBits); Set-DiskHardNs @{ DiskOnly = $true; HardNs = [int]$do.HardNs } }
    $units = @(if ($slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $script:Cal = @{
        Mode = $(if ($fine) { 'fine' } else { 'std' }); Cyls = $cyls; MaxCyl = $maxCyl; Family = $family; Slow = $slow
        Image = $img; Pattern = $pat.Path; PatternBits = $pat.Bits; MaxCoarse = [int](@(Get-CalLevels $family) | Measure-Object -Maximum).Maximum; Drive = $cmbDrive.Text; TSpec = "c=${cylList}:h=0-1"; CylList = $cylList
        # 12.10 : niveaux de la famille (Get-CalLevels, dans le litteral : les bancs l extraient tel quel)
        Stage = 'coarse'; Values = @(Get-CalLevels $family); Index = 0; Value = 0; ValueTxt = ''; Spec = ''
        Units = $units; VerifyCount = 0; Swap = [bool]$ans.Swap; LevelAfter = [bool]$LevelAfter
        Scp = (Join-Path $script:TempDir 'precomp-calib.scp'); Writes = (New-Object System.Collections.Queue); ReadArgs = @()
        # Progression globale : passes faites / prevues, durees mesurees par phase, estimation initiale 0,7 s par piste et par phase
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'
        PassesDone = 0; TotalPasses = $nPassEst; WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; EstErase = $estEr
        Home = [bool]$Geom; Geom = $Geom; NoWarmup = [bool]$noWarm   # carte Calibration de l Accueil ; 12.8 : reglage warmFullCalib
        # 12.7 : controle de surface de la passe 1 (Invoke-CalibAnalysis) : avertissement valide seul, numero de la disquette
        # (Restart-PrecompCalib), bilan, defaut grossier, fenetre ouverte (Hold) ; Redo : calibration B (point 2) ; Cyls0 :
        # cylindres de test de depart, controle d identite de la calibration B (Cyls s etend aux mesures complementaires du
        # test standard, Start-CalibDensify)
        AutoStart = [bool]$ans.Auto; Disk = 1; SurfDone = $false; Surf = $null; Medium = $null; SurfGross = $false; SurfKept = $false; Hold = $false; Redo = $redo
        Cyls0 = [int[]]@($cyls)
        # 12.8 (lot 1b) : passes de nouvel essai faites (Start-CalibRetest) ; ecritures par piste annoncees au plus
        Retests = 0; WriteMax = [int]$nPassMax
        # 12.9 : conditionnement du lecteur (Cond, CondRun pendant ses ecritures, CondDone, CondSec duree mesuree, CondTracks
        # pistes ecrites), carre latin et decalages de passe (Latin, PassW : valeur ecrite par cylindre a la passe en cours),
        # dents (Dent) ; drapeaux du bareme de la famille, poses par Set-CalibScale (appel ci-dessus, apres les sorties anticipees)
        Cond = $cond; CondRun = $false; CondDone = $false; CondSec = 0.0; CondStart = $null; CondTracks = $(if ($cond) { 2 * ($maxCyl + 1) } else { 0 })
        # Carre latin seulement avec CalLatinMinCyl cylindres de test au moins : en dessous (image de 40 cylindres en test
        # standard : c0, 10, 20, 30, 39), les decalages de passe ne s estiment pas et des niveaux repartis sans estimation
        # donneraient une erreur par cylindre plus forte que des passes uniformes (validation C)
        Latin = ([bool]$script:CalLatin -and @($cyls).Count -ge [math]::Max([int]$script:CalLatinMinCyl, 2 * @($script:CalCoarse).Count))
        Dent = [bool]$script:CalDentOn; PassW = @{}
        # 12.9 : decalage commun de l ecriture d une verification complete retire des residus avant le jugement
        # (Get-VerifyOffset, Invoke-CalibAnalysis), bareme de la famille (double densite seulement)
        VOff = [bool]$script:CalVOffOn
        # 12.10 : erreur de modele aux forts besoins corrigee a la verification complete (Get-VerifySlope,
        # Invoke-CalibAnalysis), meme bareme que VOff (double densite)
        Slope = [bool]$script:CalSlopeOn
    }
    if ($cx) {
        # 12.10 : calibration croisee : source (Drive, le lecteur qui ecrit) et cible (le lecteur qui relit) ; disquette dans
        # la source au depart (DiskAt 'S', 'T' dans la cible), echanges comptes (Swaps), invite en cours (SwapHold) ; pas une
        # calibration de l Accueil, meme avec une image de geometrie (Home faux : ni carte ni bilan de l Accueil)
        $script:Cal.Cross = @{ Src = [string]$cx.Src; Tgt = [string]$cx.Tgt }
        $script:Cal.DiskAt = 'S'; $script:Cal.Swaps = 0; $script:Cal.SwapHold = $null; $script:Cal.Home = $false
        if ($Geom -and $Geom.BitsSrc) { $pat.Source = [string]$Geom.BitsSrc }
        if ($Geom) { Append-Log ((T "=== Calibration croisée : écriture par le lecteur {0}, relecture par le lecteur {1}, type {2} ({3}, {4}) ===") -f "$($cx.Src)", "$($cx.Tgt)", "$($chk.Label)", "$famTxt", "$modeTxt") }
        else { Append-Log ((T "=== Calibration croisée : écriture par le lecteur {0}, relecture par le lecteur {1}, image {2} ({3}, {4}) ===") -f "$($cx.Src)", "$($cx.Tgt)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt") }
        Append-Log ((T "Cylindres de test : {0} ({1})") -f "$cylList", "$cylSrc")
        Append-Log ((T "Motif de test : HFE de données pseudo-aléatoires généré, {0} cylindres, {1} cellules par piste ({2}), soit {3} ns par cellule à 300 tr/min. L'image ne fixe que la densité et le nombre de cylindres, son contenu n'est pas écrit.") -f "$nCyl", "$($pat.Bits)", "$($pat.Source)", "$([math]::Round($pat.CellNs, 1))")
        Append-Log ((T "Calibration croisée : la courbe mesure le besoin du lecteur {1} à la relecture des écritures du lecteur {0} ; elle est enregistrée sous la clé « {0}>{1} », pour les écritures du lecteur {0} destinées au lecteur {1}. Pour ces écritures, le contrôle après écriture relit avec le lecteur {0} (pas avec le lecteur cible) ; la mesure de la disquette et la calibration rapide ne sont pas faites.") -f "$($cx.Src)", "$($cx.Tgt)")
    }
    elseif ($do) {
        # 12.8 (S3) : mesure complete de cette disquette : marque, borne (12.11 : au-dela du seuil, quart de la cellule de la piste ecrite, Get-DiskCapNs et Get-DiskCapBits), reference en place (Get-LevelRef)
        $script:Cal.DiskOnly = $true; $script:Cal.Brand = [string]$do.Brand; $script:Cal.HardNs = [int]$do.HardNs; $script:Cal.DiskRef = $do.Ref
        Append-Log ((T "=== Mesure complète de cette disquette : lecteur {0}, image {1} ({2}, {3}) ; référence du lecteur inchangée ===") -f "$($cmbDrive.Text)", "$([System.IO.Path]::GetFileName($img))", "$famTxt", "$modeTxt")
        if ($do.Brand) { Append-Log ((T 'Marque de la disquette insérée : « {0} ».') -f "$($do.Brand)") }
        # 12.11 (lot L4b) : ligne de la borne tiree de la decision du plafond (Get-DiskBoundText, 265) : quart de la cellule de la
        # piste ecrite si elle est connue (CapBits), ligne de la 12.10 sinon (470 ns), borne precompMaxNs au plus au seuil
        Append-Log (Get-DiskBoundText ([int]$do.HardNs) ([int]$do.CapBits))
        # 12.8 (S3-HIGH) : duree estimee et ecritures par piste au plus (avertissement M1)
        Append-Log ((T "Durée estimée de la mesure : environ {0} min ; {1} min au plus avec la mesure directe des cylindres dont le besoin dépasse {2} ns et {3} nouveaux essais au plus des cylindres non convergés.") -f "$minutes", "$minDisk", "$mxDisk", "$($script:CalDiskMaxRetest)")
        # 12.9 (correction 1) : l ecriture de conditionnement du lecteur est comptee
        $wpl = if ($cond) { (T "Écritures du motif de test par piste : {0} au plus (conditionnement du lecteur, {1} passes de mesure, encadrement, mesure directe, {2} vérifications, {3} nouveaux essais). La disquette mesurée est celle à écrire, réécrite ensuite par l'image : aucune disquette sacrifiée à épargner, chaque passe de plus reste bornée.") }
               else { (T "Écritures du motif de test par piste : {0} au plus ({1} passes de mesure, encadrement, mesure directe, {2} vérifications, {3} nouveaux essais). La disquette mesurée est celle à écrire, réécrite ensuite par l'image : aucune disquette sacrifiée à épargner, chaque passe de plus reste bornée.") }
        Append-Log ($wpl -f "$nPassMax", "$(@($script:CalCoarse).Count)", "$($script:CalMaxVerify)", "$($script:CalDiskMaxRetest)")
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

function Start-CrossCalib {
    # 12.10 : bouton a icone « Calibrer pour un lecteur cible... » de l onglet Ecriture (btnWCross) : calibration croisee, le
    # lecteur du bandeau (source) ecrit le motif, un autre lecteur (cible) le relit, la disquette passant de l un a l autre
    # a la main (Invoke-CalibSwap). Fenetre de choix (Show-CrossCalibDialog, 250) : cible parmi les lecteurs du bandeau,
    # famille (preselectionnee d apres l image de l onglet, Get-CalibImageCheck : standard ou long track), test (liste
    # « Calibration precomp »). Avec l image de l onglet de la famille choisie : ses cylindres, comme « Calibrer » ; sinon
    # image de geometrie de 80 cylindres du type de la famille (amiga.amigados, app.long : New-CalibGeometry, comme la carte
    # de l Accueil). Demande posee dans $script:CalCrossAsk, lue par Start-PrecompCalib (signature inchangee : enveloppes
    # de make-test), qui affiche l avertissement d usure avec la case « disquette sacrifiee dans la source » obligatoire.
    # Pas de fenetre ici hors des refus (testable) : renvoie @{ Started ; Why }
    $res = @{ Started = $false; Why = '' }
    $busy = Get-AppBusy -Text
    if ($busy) { $res.Why = "$busy"; [void](Show-AppMessage ((T "Calibration croisée impossible : opération en cours ({0}).") -f "$busy") (T 'Calibration precomp') 'OK' 'Warning'); return $res }
    if ($script:CalRedo) { $res.Why = (T 'calibration B'); [void](Show-AppMessage (T "Calibration croisée impossible : une calibration B (« Refaire sur une autre disquette ») est en cours ou en attente de décision.") (T 'Calibration precomp') 'OK' 'Warning'); return $res }
    $src = [string]$cmbDrive.Text
    # 12.11 (lot LN-b) : -OtherConn : avec des lecteurs enregistres, les lecteurs de la connexion de la source ne sont pas
    # proposes (les deux lecteurs sont branches en meme temps, chacun sur sa connexion) ; la fenetre de choix le dit
    $targets = Get-CrossCalibTargets @($cmbDrive.Items | ForEach-Object { [string]$_ }) $src -OtherConn
    if ($targets.Count -eq 0) { $res.Why = (T 'aucun autre lecteur'); [void](Show-AppMessage (T 'Calibration croisée impossible : aucun autre lecteur dans la liste du bandeau.') (T 'Calibration precomp') 'OK' 'Warning'); return $res }
    # 12.10 (relecture de la RC) : image de l onglet Ecriture d apres le controle de la calibration elle-meme
    # (Get-CalibImageCheck, 260, celui de Test-CalibImage au debut de Start-PrecompCalib) : annoncee et reprise seulement si
    # elle est calibrable en standard ou en long track, sinon image de geometrie de 80 cylindres ; secteurs durs ou lecteur
    # 8 pouces (refus de toute calibration) : refus avant la fenetre. Avant : famille de Get-WriteTabFamily, une image FM,
    # GCR, a codage propre ou hors des plages mesurables etait annoncee, puis la calibration refusee apres « Continuer »
    # 12.10 (relecture de la RC, fix1) : reglages tires de Get-CalibSettingBlock (260), avant le controle de l image : refus
    # avant la fenetre quelle que soit l image (avant : seulement apres une image acceptee, Get-CalibImageCheck ne regardant
    # les cases qu apres les controles de l image)
    # 12.10 (verification finale de la RC) : installation sans module d analyse SCP ou sans gw.exe (Get-CalibEnvBlock, 260,
    # celui de Test-CalibImage) : refus avant la fenetre (avant : apres « Continuer », rien n etant ecrit)
    $eb = Get-CalibEnvBlock
    if ($eb) { $res.Why = [string]$eb.Why; [void](Show-AppMessage ([string]$eb.Why) ([string]$eb.Title) 'OK' ([string]$eb.Icon)); return $res }
    $sb = Get-CalibSettingBlock
    if ($sb) { $res.Why = $sb; [void](Show-AppMessage $sb (T 'Calibration precomp') 'OK' 'Warning'); return $res }
    $ic = Get-CalibImageCheck
    $imgFam = if ($ic.Ok) { [string]$ic.Family } else { '' }
    if (@('std', 'long') -notcontains $imgFam) { $imgFam = '' }
    $imgInfo = if ($imgFam) { (T "Image de l'onglet Écriture : {0} ({1}) ; avec cette famille, ses cylindres sont ceux de la calibration ; avec l'autre, 80 cylindres à la densité de la famille.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))", (Get-CalibFamilyName $imgFam) }
               else { (T "Aucune image calibrable dans l'onglet Écriture : 80 cylindres, à la densité de la famille choisie.") }
    if ($script:DriveReg.Count -gt 0) {
        $allT = Get-CrossCalibTargets @($cmbDrive.Items | ForEach-Object { [string]$_ }) $src
        $sameC = @($allT | Where-Object { $targets -cnotcontains $_ })
        if ($sameC.Count -gt 0) { $imgInfo += "`n" + ((T 'Non proposés, parce qu''ils sont sur la connexion {0} du lecteur qui écrit : {1}. Les deux lecteurs d''une calibration croisée sont branchés en même temps, chacun sur sa connexion.') -f (Get-DriveConn $src), (Format-ConnDrives $sameC)) }
    }
    $nPassEst = @($script:CalCoarse).Count + [int]$script:CalMaxVerify
    $swF = Get-CrossSwapEstimate $nPassEst $true ([int]$script:CalMaxRetest) ([int]$script:CalMaxVerify); $swS = Get-CrossSwapEstimate $nPassEst $false ([int]$script:CalMaxRetest) ([int]$script:CalMaxVerify)   # 12.11 : au moins : une seule verification
    $ch = Show-CrossCalibDialog $src $targets $(if ($imgFam) { $imgFam } else { 'std' }) ($cmbWCalMode.SelectedIndex -eq 1) $imgInfo ([bool]$chkWSlow.Checked) ([int]$swF.Min) ([int]$swS.Max) (Get-TargetDrive $src)   # 12.11 : lecteur cible de l onglet Ecriture preselectionne
    if (-not $ch.Ok) { $res.Why = (T 'annulée'); Append-Log (T "Calibration croisée : fenêtre de choix fermée, rien n'est lancé."); return $res }
    $tgt = [string]$ch.Target; $fam = [string]$ch.Family; $test = $(if ($ch.Fine) { 'fine' } else { 'std' })
    # 12.11 (lot LN-b) : lecteur cible confirme quand sa connexion porte plusieurs lecteurs (Confirm-DriveIdentity -Target,
    # 112), avant que la demande soit posee : refus, rien n est lance
    if ($script:DriveReg.Count -gt 0 -and -not (Confirm-DriveIdentity -Target $tgt)) { $res.Why = (T 'Opération annulée : lecteur branché non confirmé.'); return $res }
    Append-Log ((T "Calibration croisée demandée : écriture par le lecteur {0}, relecture par le lecteur {1}, famille {2}, {3}.") -f "$src", "$tgt", (Get-CalibFamilyName $fam), $(if ($ch.Fine) { (T 'test fin') } else { (T 'test standard') }))
    $geom = $null
    if ($fam -ne $imgFam) {
        # Image de geometrie du type de la famille (comme Start-HomeCalib) : amiga.amigados (standard, 101 344 cellules),
        # app.long (long track) ; seuil de famille de la configuration respecte (Get-ImageFamily)
        $name = if ($fam -eq 'long') { 'app.long' } else { 'amiga.amigados' }
        $info = Get-HomeCalibInfo $name
        try { $gimg = New-CalibGeometry $info 80 }
        catch { $res.Why = "$($_.Exception.Message)"; [void](Show-AppMessage ((T "Calibration croisée impossible : image de géométrie impossible à créer : {0}") -f "$($_.Exception.Message)") (T 'Calibration precomp') 'OK' 'Error'); return $res }
        if ((Get-ImageFamily $gimg) -ne $fam) { $res.Why = (T 'seuil de famille'); [void](Show-AppMessage ((T "Calibration croisée impossible : avec le seuil de famille precompThresholdNs de {0} ns, ce type serait calibré dans une autre famille que {1}.") -f "$($script:PrecompThresholdNs)", (Get-CalibFamilyName $fam)) (T 'Calibration precomp') 'OK' 'Warning'); return $res }
        # Origine des cylindres sans parentheses : la ligne de journal des cylindres de test la met deja entre parentheses
        $geom = @{ Img = $gimg; Label = [string]$info.Label; Fmt = $name; BitsSrc = [string]$info.BitsSrc; CylSrc = (T "80 cylindres, faute d'image de cette famille dans l'onglet Écriture") }
    }
    $script:AfterCalib = ''
    $script:CalCrossAsk = @{ Src = $src; Tgt = $tgt }
    if ($geom) { Start-PrecompCalib -Geom $geom -Test $test } else { Start-PrecompCalib -Test $test }
    $script:CalCrossAsk = $null
    $res.Started = [bool]($script:Cal -and $script:Cal.Cross)
    return $res
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
    $script:CalDiskOnly = @{ Brand = [string]$brand; HardNs = 0; Ref = $lr }   # 12.11 : HardNs pose par Start-PrecompCalib (Get-DiskHardNs des cellules de la piste ecrite, qu il garde dans CapBits)
    $script:AfterCalib = 'write'
    Start-PrecompCalib -ForceFine -Heads $true
    $script:CalDiskOnly = $null      # deja remis a $null par Start-PrecompCalib (premiere instruction)
    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T "Écriture annulée : la mesure complète de cette disquette n'a pas été lancée.") }
}

function Get-DiskMeasureMinutes([int]$nCyl, [bool]$hd = $false) {
    # 12.8 (S3) : duree estimee de la mesure complete de cette disquette (W-M1, W-M2), au calcul de Start-PrecompCalib en
    # test fin : passes de mesure et de verification sur tous les cylindres, prechauffage du reglage warmFullCalib compris ;
    # 12.8.2 (revue) : effacement haute frequence de chaque passe en double densite compris (Get-CalibEraseEst) ; 12.9
    # (correction 1) : conditionnement du lecteur en double densite compris (ecriture sans relecture de tous les cylindres)
    $n = [math]::Max(2, [math]::Min(84, $nCyl))
    $wu = if ([bool](Get-Setting 'warmFullCalib')) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    $np = @($script:CalCoarse).Count + [int]$script:CalMaxVerify
    $cm = if (-not $hd -and [bool]$script:CalScaleDd.CalCondPass) { $n * 2 * (0.7 + (Get-CalibEraseEst $hd)) / 60 } else { 0.0 }
    return [int][math]::Max(1, [math]::Round($n * 2 * (1.4 + (Get-CalibEraseEst $hd)) * $np / 60 + $cm + $wu, 0))
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

function Get-CalibRetestMinutes([int]$nCyls, [int]$maxCyl, [bool]$fine, [double]$estErase = 0.0) {
    # 12.8 (lot 1b) : duree au plus du nouvel essai automatique des cylindres non converges (avertissement de
    # Start-PrecompCalib), au rythme de la duree estimee (2 pistes par cylindre, 1,4 s par piste et par passe) : une passe
    # de verification ciblee, bornee par une passe sur tous les cylindres que la calibration peut tester (test standard :
    # 30 cylindres complementaires au plus, Start-CalibDensify), arrondie a la minute superieure ; sans prechauffage (il
    # precede la premiere passe) ; 12.8.2 (revue) : $estErase, effacement haute frequence par piste (Get-CalibEraseEst)
    $n = [math]::Min($maxCyl + 1, $nCyls + $(if ($fine) { 0 } else { 30 }))
    return [int][math]::Max(1, [math]::Ceiling($n * 2 * (1.4 + $estErase) / 60))
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
    # 12.10 (relecture de la RC) : texte court, entier sur la ligne de lblWCal (520 : largeur fixe, 439 px a la taille
    # minimale de la fenetre) : « controle de surface, decision demandee (lecteur A). » mesurait 445 px, la lettre du
    # lecteur passait sous les points de suspension
    # 12.11 (lot LN-b) : lecteur enregistre : texte court, le nom en tete (en fin de texte, il passerait sous les points de
    # suspension) ; de meme pour l echange de disquette ci-dessous
    if ($cal.Hold -and $script:DriveReg.Count -gt 0 -and (Test-DriveRegistered ([string]$cal.Drive))) { $lblWCal.Text = (T '{0} : contrôle de surface, décision demandée') -f "$($cal.Drive)"; return }
    if ($cal.Hold) { $lblWCal.Text = (T "Calibration en attente : décision sur le contrôle de surface (lecteur {0}).") -f "$($cal.Drive)"; return }
    # 12.10 : calibration croisee en attente d un echange de disquette (Invoke-CalibSwap). 12.10 (relecture des captures) :
    # texte court, sur une ligne a la taille minimale de la fenetre (439 px a x = 320), anglais compris
    if ($cal.SwapHold -and $script:DriveReg.Count -gt 0 -and ((Test-DriveRegistered ([string]$cal.SwapHold.From)) -or (Test-DriveRegistered ([string]$cal.SwapHold.To)))) { $lblWCal.Text = (T '{0} → {1} : déplacez la disquette') -f "$($cal.SwapHold.From)", "$($cal.SwapHold.To)"; return }
    if ($cal.SwapHold) { $lblWCal.Text = (T "Calibration croisée : déplacez la disquette du lecteur {0} vers le lecteur {1}") -f "$($cal.SwapHold.From)", "$($cal.SwapHold.To)"; return }
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
    # 12.8.2 (revue) : avant la premiere passe, effacement haute frequence de la phase d ecriture compris (EstErase)
    $avgW = if ($cal.WriteDurs.Count -gt 0) { ($cal.WriteDurs | Measure-Object -Average).Average } else { $nTracks * ($cal.EstTrack + [double]$cal.EstErase) }
    $avgR = if ($cal.ReadDurs.Count -gt 0)  { ($cal.ReadDurs  | Measure-Object -Average).Average } else { $nTracks * $cal.EstTrack }
    if ($avgW -lt 1) { $avgW = 1 }; if ($avgR -lt 1) { $avgR = 1 }
    $pass = $avgW + $avgR
    # Finalisation 12.10 (N4 du banc) : PhaseStart absent (etat de calibration simule par un test) : phase en cours a 0, sans
    # erreur ; toujours pose en usage normal (creation de l etat, chaque passe, chaque phase)
    $elapsed = if ($cal.PhaseStart -is [datetime]) { ((Get-Date) - $cal.PhaseStart).TotalSeconds } else { 0.0 }
    # 12.9 (correction 1) : conditionnement (ecriture sans relecture avant la passe 1), compte en fraction de passe : duree
    # estimee, puis mesuree, rapportee a celle d une passe ; libelle propre pendant ses ecritures
    $cw = 0.0
    if ($cal.Cond) {
        $csec = if ($cal.CondDone -and [double]$cal.CondSec -gt 0) { [double]$cal.CondSec } else { [double]$cal.CondTracks * ($cal.EstTrack + [double]$cal.EstErase) }
        $cw = $csec / $pass
    }
    $tp = [math]::Max(1, [int]$cal.TotalPasses)
    $total = $tp + $cw
    # 12.11 : avancement de l etape en cours (passe ou conditionnement) d apres les pistes que gw efface, ecrit puis relit
    # (plan de l etape, Get-ProgPlanFrac, 110), a la place du temps ecoule rapporte aux durees des passes precedentes, qui
    # restait a 98 % ou sautait quand une passe portait sur moins de pistes. $null sans plan, ou tant que le plan n a recu
    # aucune commande : calcul par le temps de la 12.10, a l identique. Passes comptees a parts egales et temps restant
    # inchanges ; affichage seulement
    $pf = if ($script:ProgPlan) { Get-ProgPlanFrac } else { $null }
    if ($cal.CondRun) { $done = $(if ($null -ne $pf) { [double]$pf } else { [math]::Min(0.98, $elapsed / [math]::Max(1.0, $cw * $pass)) }) * $cw }
    else {
        $frac = if ($null -ne $pf) { [double]$pf }
                elseif ($cal.Phase -eq 'write') { [math]::Min(0.98, $elapsed / $avgW) * ($avgW / $pass) }
                else { ($avgW / $pass) + [math]::Min(0.98, $elapsed / $avgR) * ($avgR / $pass) }
        $done = [math]::Min($total, $(if ($cal.Cond) { $cw } else { 0.0 }) + $cal.PassesDone + $frac)
    }
    $pct = [int][math]::Floor(100 * $done / $total)
    $remaining = $pass * ($total - $done)
    $pbWCal.Value = [math]::Max(0, [math]::Min(100, $pct))
    if ($cal.CondRun) {
        $fmtC = if ($cal.Redo) { (T "Calibration B : {0} %, reste environ {1} (conditionnement du lecteur, écriture sans relecture)") }
                elseif ($cal.DiskOnly) { (T "Mesure complète de cette disquette : {0} %, reste environ {1} (conditionnement du lecteur, écriture sans relecture)") }
                elseif ($cal.Cross) { (T "Calibration croisée : {0} %, reste environ {1} (conditionnement du lecteur, écriture sans relecture)") }   # 12.10
                else { (T "Calibration : {0} %, reste environ {1} (conditionnement du lecteur, écriture sans relecture)") }
        $lblWCal.Text = ($fmtC -f "$pct", (Format-CalDuration $remaining)); return
    }
    # 12.11 : « effacement » pendant un gw erase de la passe (commande en cours : $script:GwProc et $script:GwIsErase, 110) ;
    # avant, la phase d ecriture disait « ecriture » pendant son effacement haute frequence
    $phaseTxt = if ($script:GwProc -and $script:GwIsErase) { (T 'effacement') } elseif ($cal.Phase -eq 'write') { (T 'écriture') } else { (T 'relecture') }
    # 12.8.1 : mesure de la disquette sur l image (276) : ValueTxt « tete 0 puis tete 1 »
    $fmt = if ($cal.Mode -eq 'content') { (T "Mesure de la disquette sur l'image : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Mode -eq 'level') { (T "Calibration rapide : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Redo) { (T "Calibration B : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.DiskOnly) { (T "Mesure complète de cette disquette : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
           elseif ($cal.Cross) { (T "Calibration croisée : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }   # 12.10
           else { (T "Calibration : {4} %, reste environ {5} (passe {0}/{1}, {2}, {3})") }
    $lblWCal.Text = ($fmt -f "$([math]::Min($tp, $cal.PassesDone + 1))", "$tp", "$($cal.ValueTxt)", "$phaseTxt", "$pct", (Format-CalDuration $remaining))
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
    $script:ProgPlan = $null                              # 12.11 : plan de la passe interrompue retire (barre de progression)
    if ($cal -and $cal.DiskOnly) { Reset-DiskHardNs }     # 12.8 (S3) : borne de precompMaxNs retablie
    # 12.9 (D6) : statut du JSON compagnon ; synthese C (A5) : seulement apres une passe analysee (arret pendant le
    # prechauffage ou erreur gw a la premiere ecriture : aucun JSON seul, qui compterait comme une mesure gardee)
    if ($cal -and [string]$cal.Mode -eq 'content' -and [int]$cal.PassesDone -gt 0) { Save-ContentCompanion $cal 'arretee' }
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
    # 12.9 (correction 1) : nouvelle disquette, nouveau conditionnement ; unites recreees ci-dessus (Coarse vide)
    $cal.CondRun = $false; $cal.CondDone = $false; $cal.CondSec = 0.0; $cal.PassW = @{}
    $cal.AutoStart = $false; $cal.Disk = 1 + [int]$cal.Disk; $cal.Retests = 0
    # 12.10 : calibration croisee : la nouvelle disquette est dans la source (le lecteur qui ecrit) ; echanges comptes gardes
    if ($cal.Cross) { $cal.DiskAt = 'S'; Append-Log ((T "Calibration croisée reprise : la nouvelle disquette est dans le lecteur {0}, celui qui écrit.") -f "$($cal.Cross.Src)") }
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
    $plan = Get-CalWarmupPlan (Get-GwDriveKey (@('read') + (Get-CalibDriveArgsFor 'warmup'))) ([double]$script:CalWarmupMinutes)   # 12.10 : calibration croisee : la source (le lecteur qui ecrit) est prechauffee
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
    $cal.WarmArgs = @('read') + (Get-CalibDriveArgsFor 'warmup') + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$($cal.TSpec)", "`"$($cal.WarmScp)`"")
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
            Append-Log ((T "Préchauffage du lecteur {0} arrêté après {1} lectures de suite sans aboutir (Greaseweazle, lecteur ou disquette absent ?) : la calibration commence, sa première commande signalera le défaut s'il persiste.") -f "$($cal.Drive)", "$($cal.WarmFailRun)")
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

function Set-CalibCoarsePlan($cal) {
    # 12.9 (corrections 2 et 3) : valeur ecrite par cylindre a la passe de mesure $cal.Index (PassW), profil --precomp
    # (Spec) et libelle de la barre (ValueTxt). Carre latin ($cal.Latin, double densite) : Get-CalibLatinW, une entree c=ns
    # par cylindre de test (Get-BracketSpec, comme l encadrement : gw applique chaque valeur a partir de son cylindre, et
    # seuls les cylindres de --tracks sont ecrits) ; sinon (haute densite) meme valeur pour tous, profil « 0=v » (12.8.2)
    $p = [int]$cal.Index
    $cal.Value = [int]$cal.Values[$p]
    if ($cal.Latin) {
        $cal.PassW = Get-CalibLatinW ([int[]]@($cal.Cyls)) ([int[]]@($cal.Values)) $p
        $cal.Spec = Get-BracketSpec $cal.PassW
        $cal.ValueTxt = "$(@($cal.Values) -join '/') ns"
    } else {
        $cal.PassW = @{}; foreach ($c in @($cal.Cyls)) { $cal.PassW[[int]$c] = $cal.Value }
        $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns"
    }
}

function Add-CalibWriteCmds($cal, $writes) {
    # Commandes d ecriture d une passe dans la file $cal.Writes ($writes : @(TSPEC, profil) par commande). 12.8.2 : double
    # densite (Get-EraseMode : famille autre que hd, motif de moins de 150 000 cellules comme Test-CurveHd, ni secteurs durs
    # ni TG43) : toutes les pistes ecrites (TSPEC des ecritures, Get-TSpecKeys) d abord effacees en haute frequence (gw erase
    # --hfreq, TSPEC exacts), puis motif sans --pre-erase ; haute densite : --pre-erase. 12.9 : partage par New-CalibPass et
    # le conditionnement du lecteur (Start-CalibCondition) ; texte deplace de New-CalibPass, inchange
    $cal.Writes.Clear()
    $hf = ((Get-EraseMode ([string]$cal.Family -eq 'hd' -or [int]$cal.PatternBits -ge 150000)) -eq 'hfreq')
    $ek = @{}
    if ($hf) {
        foreach ($w in $writes) {
            $wk = Get-TSpecKeys ([string]$w[0])
            if (@($wk).Count -eq 0) { $hf = $false; break }        # TSPEC illisible : pre-effacement pour cette passe
            foreach ($k in $wk) { $ek[[string]$k] = $true }
        }
    }
    if ($hf) {
        foreach ($ec in (New-HfreqEraseCmds @($ek.Keys) '' (@(Get-CalibDriveArgsFor 'erase') + @(Get-EraseDriveArgs)))) { $cal.Writes.Enqueue([string[]]$ec) }   # 12.10 : lecteur source en croise
        if (-not $cal.EraseNoted) { $cal.EraseNoted = $true; Append-Log (T "Calibration : disquette double densité, chaque passe efface d'abord en haute fréquence les pistes qu'elle écrit (gw erase --hfreq), puis écrit le motif sans pré-effacement.") }
    }
    $pe = if ($hf) { @('--no-verify') } else { @('--pre-erase', '--no-verify') }
    foreach ($w in $writes) {
        $cal.Writes.Enqueue([string[]](@('write') + (Get-CalibDriveArgsFor 'write') + $pe + (Get-CalibDriveArgs) + @("--tracks=$($w[0])", '--precomp', $w[1], "`"$($cal.Pattern)`"")))   # 12.10 : lecteur source en croise
    }
}

function Start-CalibCondition($cal) {
    # 12.9 (correction 1) : conditionnement du lecteur juste avant la premiere passe de mesure. La premiere ecriture qui
    # suit une periode sans ecriture (prechauffage en lecture seule compris) peut porter un transitoire de quelques ns de
    # decalage sur ses premieres pistes (emulation 80 cylindres du 31/10/2026 : jusqu a +5,5 ns sur c0-c19 ; intermittent) :
    # effacement haute frequence puis ecriture du motif sur tous les cylindres de l image (2 faces), avec le profil de la
    # passe 1, sans relecture ni analyse, pour que les passes de mesure partent d un lecteur en ecriture. Une fois par
    # disquette (CondDone ; Restart-PrecompCalib le remet a faux). Erreur gw : abandon, comme a la passe 1
    # (Stop-PrecompCalib -GwError)
    Set-CalibCoarsePlan $cal
    $cal.CondRun = $true; $cal.CondStart = Get-Date
    $cal.CondTSpec = "c=0-$([int]$cal.MaxCyl):h=0-1"
    # 12.9 (revue du 31/10/2026, m3) : texte selon l effacement que feront les commandes (meme expression que
    # Add-CalibWriteCmds) : pre-effacement (--pre-erase, sans gw erase) sous les options de lecteur que gw erase ne prend
    # pas en charge (Get-EraseFallbackNote : secteurs durs, TG43, --densel)
    $hfC = ((Get-EraseMode ([string]$cal.Family -eq 'hd' -or [int]$cal.PatternBits -ge 150000)) -eq 'hfreq')
    if ($hfC) { Append-Log ((T "Calibration : conditionnement du lecteur {0} avant la première passe de mesure : effacement haute fréquence puis écriture du motif sur les cylindres {1} (2 faces), sans relecture, pour que les passes de mesure partent d'un lecteur en écriture.") -f "$($cal.Drive)", "0-$([int]$cal.MaxCyl)") }
    else { Append-Log ((T "Calibration : conditionnement du lecteur {0} avant la première passe de mesure : écriture du motif avec pré-effacement sur les cylindres {1} (2 faces), sans relecture, pour que les passes de mesure partent d'un lecteur en écriture.") -f "$($cal.Drive)", "0-$([int]$cal.MaxCyl)") }
    Add-CalibWriteCmds $cal @(,@($cal.CondTSpec, $cal.Spec))
    New-ProgPlan @($cal.Writes.ToArray())   # 12.11 : plan du conditionnement pour la barre de progression (110)
    $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart; $cal.Phase = 'write'
    Update-CalibProgress
    $script:Chain.Clear()
    if ($cal.Cross) { $script:Chain.Enqueue({ Invoke-CalibSwap 'S' }) }   # 12.10 : disquette dans la source avant d ecrire (sans effet si elle y est)
    $nCmd = $cal.Writes.Count
    for ($i = 0; $i -lt $nCmd; $i++) { $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.Writes.Dequeue()) }) }
    $script:Chain.Enqueue({ Complete-CalibCondition })
    Invoke-NextChainStep
}

function Complete-CalibCondition {
    # 12.9 (correction 1) : fin du conditionnement : une ecriture de plus par piste conditionnee (garde WriteMax :
    # Get-CalibRetestPlan, Add-DriftWitnesses), duree mesuree (barre de progression), puis premiere passe de mesure
    $cal = $script:Cal
    if (-not $cal -or -not $cal.CondRun) { return }
    $cal.CondRun = $false; $cal.CondDone = $true
    $cal.CondSec = ((Get-Date) - $cal.CondStart).TotalSeconds
    foreach ($u in @($cal.Units)) { for ($c = 0; $c -le [int]$cal.MaxCyl; $c++) { $u.Writes[$c] = 1 + [int]$u.Writes[$c] } }
    Append-Log ((T "Calibration : conditionnement du lecteur terminé en {0}.") -f (Format-CalDuration $cal.CondSec))
    New-CalibPass
}

function Invoke-CalibSwap([string]$to) {
    # 12.10 : etape de la chaine d une calibration croisee : la disquette doit etre dans la source ('S', le lecteur qui ecrit)
    # avant un effacement ou une ecriture, dans la cible ('T', le lecteur qui relit) avant une relecture. Deja au bon
    # endroit (ecritures consecutives : conditionnement puis passe 1) : etape suivante sans invite. Sinon invite frmCalibSwap
    # (Show-TimedConfirm sans compte a rebours, comme frmReinsert ; le banc y repond par OpenForms), libelle de la barre
    # fige pendant l attente (SwapHold, Update-CalibProgress), echange compte (Swaps), duree de l attente retiree de la
    # phase en cours (PhaseStart : durees des phases et estimation de la barre), puis etape suivante. Annuler, Echap ou la
    # croix : chaine videe, calibration arretee (Stop-PrecompCalib), la disquette reste ou elle est.
    # Configuration (constat du banc du 09/11/2026 : fichier reecrit apres une annulation, contenu identique hors _saved) :
    # ni cette annulation ni Stop-PrecompCalib n enregistrent rien ; le fichier a ete reecrit avant l invite, par Start-Gw
    # (110), qui appelle Save-Config avant chaque commande gw de toute operation hors restauration et detection (reglages
    # enregistres a chaque commande lancee, calibrations ordinaires comprises). Voulu, et laisse tel quel : retirer cet
    # enregistrement pour la seule calibration croisee changerait une regle commune a toutes les operations
    $cal = $script:Cal
    if (-not $cal) { return }
    if (-not $cal.Cross -or [string]$cal.DiskAt -eq $to) { Invoke-NextChainStep; return }
    $from = if ($to -eq 'T') { [string]$cal.Cross.Src } else { [string]$cal.Cross.Tgt }
    $dest = if ($to -eq 'T') { [string]$cal.Cross.Tgt } else { [string]$cal.Cross.Src }
    $role = if ($to -eq 'T') { (T 'celui qui relit') } else { (T 'celui qui écrit') }
    $n = 1 + [int]$cal.Swaps
    $txt = (T "Échange {0} : retirez la disquette du lecteur {1} et insérez-la dans le lecteur {2}, {3}, puis cliquez sur « J'ai déplacé la disquette ».`nAnnuler : la calibration s'arrête, rien de plus n'est écrit.") -f "$n", "$from", "$dest", "$role"
    Append-Log ((T "Calibration croisée, échange {0} : déplacez la disquette du lecteur {1} vers le lecteur {2} ({3}).") -f "$n", "$from", "$dest", "$role")
    $cal.SwapHold = @{ From = $from; To = $dest }
    Update-CalibProgress
    $t0 = Get-Date
    try { $q = Show-TimedConfirm 'frmCalibSwap' (T 'Calibration precomp') $txt (T "J'ai déplacé la disquette") 'Check' '' '' '' '' -Seconds 0 -Heading ((T 'Déplacez la disquette vers le lecteur {0}') -f "$dest") -Level 'info' -Picto 'drive' }
    finally { $cal.SwapHold = $null }
    if ($cal.PhaseStart -is [datetime]) { $cal.PhaseStart = $cal.PhaseStart.Add((Get-Date) - $t0) }
    if (-not $q.Ok) {
        $script:Chain.Clear()
        Append-Log ((T "Calibration croisée arrêtée à votre demande (échange {0} annulé) ; la disquette est dans le lecteur {1}.") -f "$n", "$from")
        Stop-PrecompCalib
        return
    }
    $cal.DiskAt = $to; $cal.Swaps = $n
    Append-Log ((T "Échange {0} fait : disquette dans le lecteur {1}.") -f "$n", "$dest")
    Invoke-NextChainStep
}

function New-CalibPass {
    # Une passe = une ou deux commandes gw write puis une relecture en flux.
    #  - mesure : une valeur par cylindre de test (carre latin en double densite, Set-CalibCoarsePlan), la meme pour les deux tetes, une commande ;
    #  - encadrement : cylindres encore sous-compenses a la plus forte valeur mesuree, ecrits a leur estimation +
    #    CalBracketMargin (une valeur par cylindre ; par tete en ecriture lente), relus seuls ;
    #  - verification : le profil obtenu ; en ecriture lente tete 0 puis tete 1, chacune avec son profil.
    # 12.8.1 (spec-1281.md § A.9) : mesure de la disquette sur l image (stade 'content' : premiere passe apres les fins du
    # prechauffage, Start-CalibWarmup et Invoke-CalibWarmup) : passes propres (New-ContentPass, 276)
    if ($script:Cal -and $script:Cal.Stage -eq 'content') { New-ContentPass; return }
    $cal = $script:Cal
    $writes = @(); $readTs = $cal.TSpec
    if ($cal.Stage -eq 'coarse') {
        # 12.9 (correction 1) : conditionnement du lecteur juste avant la premiere passe de mesure (une fois par disquette)
        if ($cal.Cond -and [int]$cal.Index -eq 0 -and -not $cal.CondDone) { Start-CalibCondition $cal; return }
        Set-CalibCoarsePlan $cal
        if ($cal.Latin) { Append-Log ((T "Calibration : passe de mesure {0}/{1}, niveaux {2} ns répartis sur les cylindres (chaque cylindre reçoit chaque niveau une fois en {1} passes)") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$(@($cal.Values) -join '/')") }
        else { Append-Log ((T "Calibration : passe de mesure {0}/{1}, precomp {2} ns") -f "$($cal.Index + 1)", "$($cal.Values.Count)", "$($cal.Value)") }
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
    # 12.8.2 : en double densite, les pistes que la passe ecrit sont d abord effacees en haute frequence (TSPEC exacts : une
    # piste non reecrite a cette passe garde son motif), puis le motif est ecrit sans --pre-erase ; haute densite :
    # --pre-erase. Toutes les calibrations passent ici : complete, test rapide, mesure complete de la disquette, carte de
    # l Accueil, calibration B, refaire, nouvel essai, verifications et temoins de derive. 12.9 : commandes construites par
    # Add-CalibWriteCmds, partagee avec le conditionnement du lecteur (Start-CalibCondition)
    Add-CalibWriteCmds $cal $writes
    $cal.ReadArgs  = @('read') + (Get-CalibDriveArgsFor 'read') + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=$readTs", "`"$($cal.Scp)`"")   # 12.10 : lecteur cible en croise
    # 12.11 : plan de la passe pour la barre de progression (110) : ses effacements, ses ecritures, puis sa relecture,
    # tels qu ils viennent d etre construits ; ne lance rien et ne modifie aucune commande
    New-ProgPlan (@($cal.Writes.ToArray()) + ,$cal.ReadArgs)
    $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart; $cal.Phase = 'write'
    Update-CalibProgress
    $script:Chain.Clear()
    # 12.10 : calibration croisee : disquette ramenee dans la source avant les ecritures, portee dans la cible avant la
    # relecture (Invoke-CalibSwap : invite seulement si elle n y est pas deja) ; calibration ordinaire : chaine inchangee
    $nCmd = $cal.Writes.Count
    if ($cal.Cross -and $nCmd -gt 0) { $script:Chain.Enqueue({ Invoke-CalibSwap 'S' }) }
    for ($i = 0; $i -lt $nCmd; $i++) { $script:Chain.Enqueue({ Start-Gw ([string[]]$script:Cal.Writes.Dequeue()) }) }
    if ($cal.Cross) { $script:Chain.Enqueue({ Invoke-CalibSwap 'T' }) }
    $script:Chain.Enqueue({
        $script:Cal.WriteDurs += ((Get-Date) - $script:Cal.PhaseStart).TotalSeconds
        $script:Cal.Phase = 'read'; $script:Cal.PhaseStart = Get-Date
        Start-Gw $script:Cal.ReadArgs
    })
    $script:Chain.Enqueue({ Invoke-CalibAnalysis })
    Invoke-NextChainStep
}

function Set-CalibEstimates($u, [string]$when = '') {
    # Valeur de precomp par cylindre teste (Get-CalibZero) d apres toutes ses mesures : passes de mesure, passe
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

function Set-CalibPassOffsets($cal) {
    # 12.9 (correction 2) : apres la derniere passe de mesure en carre latin (Invoke-CalibAnalysis), decalage propre a chaque
    # passe, par face (Get-CalibPassOffsets), retire de chaque mesure brute de la face (u.Coarse) ; puis, comme en 12.8.2,
    # point de chaque passe dans Results (moyenne des faces lues, erreur-type combinee), mesures de chaque face dans Face
    # (Get-FaceEstimates) et mesures de l unite par passe dans CoarseZ (Get-CalibDents). Estimation impossible pour une face
    # (trop peu de cylindres mesures a tous les niveaux, systeme singulier) : decalages nuls, ligne de journal.
    $n = @($cal.Values).Count
    $lv = [int[]]@($cal.Values)
    foreach ($u in @($cal.Units)) {
        $heads = if ($null -eq $u.Head) { @(0, 1) } else { @([int]$u.Head) }
        $u.PassAlpha = @{}; $u.CoarseZ = @{}
        foreach ($h in $heads) {
            $obs = @(foreach ($k in @($u.Coarse.Keys)) { foreach ($r in @($u.Coarse[$k])) { if ($r.F.ContainsKey([int]$h)) { @{ C = [int]$k; P = [int]$r.P; W = [int]$r.W; Y = [double]$r.F[[int]$h].Shift } } } })
            $fit = Get-CalibPassOffsets $obs $lv $n ([int]$script:CalLatinMinCyl)
            if ($fit.Ok) { $u.PassAlpha[[int]$h] = $fit; continue }
            $why = if ($fit.Why -eq 'singulier') { (T 'système singulier') } else { (T 'trop peu de cylindres mesurés à tous les niveaux') }
            Append-Log ($u.Prefix + ((T "Calibration : décalage des passes de mesure non estimé sur la face {0} ({1}) : mesures prises telles quelles.") -f "$h", "$why"))
        }
        foreach ($k in @($u.Coarse.Keys | ForEach-Object { [int]$_ } | Sort-Object)) {
            foreach ($r in @(@($u.Coarse[$k]) | Sort-Object { [int]$_.P })) {
                $sv = @(); $ev = @()
                foreach ($h in $heads) {
                    if (-not $r.F.ContainsKey([int]$h)) { continue }
                    $a = if ($u.PassAlpha.ContainsKey([int]$h)) { [double]$u.PassAlpha[[int]$h].Alpha[[int]$r.P] } else { 0.0 }
                    $s = [double]$r.F[[int]$h].Shift - $a
                    $sv += $s; $ev += $r.F[[int]$h].SE
                    if (-not $u.Face.ContainsKey([int]$h)) { $u.Face[[int]$h] = @{} }
                    if (-not $u.Face[[int]$h].ContainsKey($k)) { $u.Face[[int]$h][$k] = @{} }
                    Add-CalibPoint $u.Face[[int]$h][$k] ([int]$r.W) @{ Shift = $s; SE = $r.F[[int]$h].SE; Score = [double]::NaN }
                }
                if ($sv.Count -eq 0) { continue }
                $sh = ($sv | Measure-Object -Average).Average
                $se = [double]::NaN
                if (@($ev | Where-Object { [double]::IsNaN([double]$_) }).Count -eq 0) { $q = 0.0; foreach ($x in $ev) { $q += $x * $x }; $se = [math]::Sqrt($q) / $ev.Count }
                Add-CalibPoint $u.Results[$k] ([int]$r.W) @{ Shift = $sh; SE = $se; Score = $r.Score }
                if (-not $u.CoarseZ.ContainsKey($k)) { $u.CoarseZ[$k] = @() }
                $u.CoarseZ[$k] += ,@{ P = [int]$r.P; W = [int]$r.W; Shift = $sh }
            }
        }
        if ($u.PassAlpha.Count -eq 0) { continue }
        # Journal : decalages par face et par passe, erreur-type ; premiere passe encore nettement au-dessus des suivantes
        $faces = @(foreach ($h in @($u.PassAlpha.Keys | Sort-Object)) {
            $fa = $u.PassAlpha[$h]
            (T 'face {0} : {1}') -f "$h", ((@(for ($p = 0; $p -lt $n; $p++) { (T 'passe {0} {1}') -f "$($p + 1)", (Format-UiNum ([double]$fa.Alpha[$p]) '+0.0;-0.0;0.0') })) -join ', ')
        })
        $seMax = [double](@(foreach ($fa in @($u.PassAlpha.Values)) { foreach ($x in @($fa.SE)) { [double]$x } }) | Measure-Object -Maximum).Maximum
        Append-Log ($u.Prefix + ((T "Calibration : décalage propre à chaque passe de mesure, retiré des mesures avant le calcul des zéros (ns de décalage, erreur-type {1} au plus) : {0}. La moyenne de ces décalages, commune à toute la courbe, ne se mesure pas : elle reste dans le niveau de la courbe, que la vérification ne distingue pas de son propre décalage d'écriture.") -f ($faces -join ' ; '), (Format-UiNum $seMax '0.0')))
        foreach ($h in @($u.PassAlpha.Keys | Sort-Object)) {
            $fa = $u.PassAlpha[$h]
            $d1 = [double]$fa.Alpha[0] * $n / ($n - 1); $s1 = [double]$fa.SE[0] * $n / ($n - 1)
            if ($d1 -le [math]::Max([double]$script:CalCondWarnNs, 3.0 * $s1)) { continue }
            # Part commune restante : d1 / n ns de decalage sur toute la courbe, en ns de precompensation par la pente mediane
            # des cylindres (u.Slope n est pose qu ensuite, par Set-CalibEstimates)
            $sls = @(foreach ($k in @($u.CoarseZ.Keys)) {
                $rs = @($u.CoarseZ[$k]); if ($rs.Count -lt 2) { continue }
                $mx = 0.0; $my = 0.0; foreach ($r in $rs) { $mx += [double]$r.W; $my += [double]$r.Shift }; $mx /= $rs.Count; $my /= $rs.Count
                $sxx = 0.0; $sxy = 0.0; foreach ($r in $rs) { $sxx += ([double]$r.W - $mx) * ([double]$r.W - $mx); $sxy += ([double]$r.W - $mx) * ([double]$r.Shift - $my) }
                if ($sxx -gt 0 -and $sxy / $sxx -lt -0.2) { $sxy / $sxx }
            })
            $slp = if ($sls.Count -gt 0) { [math]::Abs([double](Get-Median $sls)) } else { 1.55 }
            Append-Log ($u.Prefix + ((T "Calibration : sur la face {1}, la première passe de mesure lit un décalage plus fort de {0} ns que les suivantes (effet possible de la première écriture). La différence entre les passes est retirée ; la part restante, 1/{3} de cet écart, soit environ {2} ns de précompensation, reste dans le niveau de toute la courbe, que la vérification ne distingue pas de son propre décalage d'écriture.") -f (Format-UiNum $d1 '0.0'), "$h", (Format-LevelNum ($d1 / $n / $slp)), "$n"))
        }
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
    $script:ProgPlan = $null   # 12.11 : passe comptee : son plan est retire (la barre ne compte pas la passe deux fois)
    # 12.10 : releve de l asymetrie du motif (12.11 : garde pour l etude, plus lu par l onglet Qualite) : rapports 3T/2T et
    # 4T/2T du motif relu a la premiere verification complete (tous les cylindres ecrits a la courbe), par piste
    if ($cal.Stage -eq 'verify' -and [int]$cal.VerifyCount -eq 1 -and [int]$cal.Retests -eq 0 -and $null -eq $cal.AsymRef) { $cal.AsymRef = Get-TracksAsym $tracks }
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
                'coarse'  {
                    # 12.9 (correction 2) : carre latin : mesure brute gardee par face et par passe, decalage propre a chaque
                    # passe retire apres la derniere (Set-CalibPassOffsets) ; haute densite : point ajoute tout de suite
                    if ($cal.Latin) { if (-not $u.Coarse.ContainsKey([int]$c)) { $u.Coarse[[int]$c] = @() }; $u.Coarse[[int]$c] += ,@{ P = [int]$cal.Index; W = [int]$cal.PassW[[int]$c]; F = $fm; Score = $jt } }
                    else { Add-CalibPoint $u.Results[[int]$c] ([int]$cal.PassW[[int]$c]) $meas }
                }
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
            $xv = switch ($cal.Stage) { 'coarse' { [int]$cal.PassW[[int]$c] } 'bracket' { [int]$u.Bracket[[int]$c] } 'densify' { [int]$u.Dense[[int]$c] } 'reach' { [int]$u.Reach[[int]$c] } 'level' { [int]$u.LTarget[[int]$c] } default { [int]$u.VerifyP[[int]$c] } }
            $role = if ($cal.Stage -eq 'level') { Get-LevelCylRole $u ([int]$c) } elseif ($cal.Stage -eq 'verify' -and $null -ne $u.VerifyList -and @($u.Witness) -contains [int]$c) { ' ' + (T '(témoin)') } else { '' }
            foreach ($h in @($fm.Keys)) {
                if (-not $plog.ContainsKey([int]$h)) { $plog[[int]$h] = @() }
                $plog[[int]$h] += ,@{ C = [int]$c; W = $xv; Role = $role; Shift = [double]$fm[$h].Shift; SE = $fm[$h].SE }
            }
            # 12.7 : mesures des passes de mesure gardees par face (comparaison de deux calibrations, Get-FaceEstimates) ;
            # sans effet sur la courbe. 12.9 (correction 2) : passes de mesure en carre latin : faces remplies, decalage de
            # passe retire, par Set-CalibPassOffsets
            $xw = $null
            if ($cal.Stage -eq 'coarse') { $xw = [int]$cal.PassW[[int]$c] } elseif ($cal.Stage -eq 'bracket') { $xw = [int]$u.Bracket[[int]$c] } elseif ($cal.Stage -eq 'densify') { $xw = [int]$u.Dense[[int]$c] } elseif ($cal.Stage -eq 'reach') { $xw = [int]$u.Reach[[int]$c] }
            if ($null -ne $xw -and -not ($cal.Stage -eq 'coarse' -and $cal.Latin)) {
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
        # 12.9 : verification complete (VerifyList nul : une commande gw par unite, tous les cylindres estimes ecrits a la
        # suite) en double densite (VOff, bareme) : le decalage commun de cette ecriture (Get-VerifyOffset : mediane des
        # residus bruts) est retire de chaque residu avant le jugement et toute correction (Shift centre ; Raw brut : ligne
        # « Residu apres verification », Res de la courbe enregistree) ; la courbe n est pas deplacee. Ecrit apres les mesures
        # brutes de la passe (synthese, Write-CalibPassLog) : les donnees avant la conclusion ; une ligne de journal dans
        # chaque cas (retire, dans le bruit, au-dela de la borne, trop peu de cylindres exploitables). Verifications ciblees
        # (verification 2, nouvel essai) : rien ici, les temoins (Get-VerifyDrift) centrent deja leurs residus par rapport a ce
        # repere, desormais centre (D = decalage commun absolu de la passe ; Get-CalibDriftStep rend la difference)
        if ($cal.Stage -eq 'verify' -and $null -eq $u.VerifyList -and [bool]$cal.VOff -and $null -ne $u.Fit) {
            $vo = Get-VerifyOffset $u ([int]$script:CalVOffMinCyl) ([double]$script:CalVOffSigK) ([double]$script:CalVOffMaxNs) ([double]$cal.MaxCoarse)   # 12.10 : niveau maximal de la famille
            $u.VOff = @{ V = [int]$cal.VerifyCount; M = [double]$vo.M; E = [double]$vo.E; N = [int]$vo.N; Removed = [bool]$vo.Ok }
            if ($vo.Ok) {
                foreach ($k in @($u.Verify.Keys)) { $m = $u.Verify[$k]; $u.Verify[$k] = @{ Shift = [double]$m.Shift - [double]$vo.M; SE = $m.SE; Score = $m.Score; Raw = [double]$m.Shift } }
                Append-Log ($u.Prefix + ((T "Vérification {0} : décalage commun de l'écriture {1} ns de décalage (médiane des résidus de {2} cylindres, erreur-type {3}) : retiré des résidus avant le jugement et toute correction ; la courbe n'est pas déplacée.") -f "$($cal.VerifyCount)", ('{0:+0.0;-0.0;0.0}' -f [double]$vo.M), "$($vo.N)", (Format-LevelNum $vo.E)))
            }
            elseif ($vo.Why -eq 'borne') { Append-Log ($u.Prefix + ((T "Vérification {0} : décalage commun de l'écriture {1} ns de décalage (médiane des résidus de {2} cylindres), au-delà de {3} ns : non retiré, les résidus sont jugés tels quels (lecteur ou support instable depuis les passes de mesure ?) ; la vérification suivante contrôle la correction.") -f "$($cal.VerifyCount)", ('{0:+0.0;-0.0;0.0}' -f [double]$vo.M), "$($vo.N)", (Format-LevelNum ([double]$script:CalVOffMaxNs)))) }
            elseif ($vo.Why -eq 'nonsig') { Append-Log ($u.Prefix + ((T "Vérification {0} : décalage commun de l'écriture {1} ns de décalage (médiane des résidus de {2} cylindres, erreur-type {3}) : dans le bruit, non retiré.") -f "$($cal.VerifyCount)", ('{0:+0.0;-0.0;0.0}' -f [double]$vo.M), "$($vo.N)", (Format-LevelNum $vo.E))) }
            # 'cylindres' (moins de CalVOffMinCyl cylindres exploitables : image courte en test standard, ou test standard
            # dont un cylindre est un point isole, au plafond ou au plancher) : residus bruts, dit au journal
            elseif ($vo.Why -eq 'cylindres') { Append-Log ($u.Prefix + ((T "Vérification {0} : décalage commun de l'écriture non évalué ({1} cylindres exploitables, {2} au moins nécessaires) : les résidus sont jugés tels quels.") -f "$($cal.VerifyCount)", "$($vo.N)", "$([int]$script:CalVOffMinCyl)")) }
            # 'regional' (banc 129-voff2) : decalage des cylindres retenus different de celui du reste de la piste, ou d une moitie
            # a l autre : erreur regionale de la courbe, pas un decalage de l ecriture ; residus bruts, dit au journal
            elseif ($vo.Why -eq 'regional') { Append-Log ($u.Prefix + ((T "Vérification {0} : décalage de l'écriture {1} ns de décalage sur {2} cylindres, mais {3} ns d'écart avec le reste de la piste : il n'est pas commun à toute l'écriture, non retiré ; les résidus sont jugés tels quels.") -f "$($cal.VerifyCount)", ('{0:+0.0;-0.0;0.0}' -f [double]$vo.M), "$($vo.N)", (Format-LevelNum ([double]$vo.Dz)))) }
        }
        # 12.10 : erreur de modele aux forts besoins (Get-VerifySlope) : a la verification complete en double densite, pente du
        # residu juge avec la valeur ecrite sur les cylindres ecrits au-dela du niveau mesure ; etablie : les cylindres que la
        # droite ecarte de plus de CalSlopeMinNs sont retenus (SlopeBad, rejoint Get-ResidualFlags ci-dessous) et corriges a
        # leur zero mesure, puis controles par la verification suivante comme toute correction. Journal dans les deux cas
        # des qu il y a assez de cylindres au-dela du niveau mesure ; rien sur un lecteur a faible besoin
        $u.SlopeBad = $null
        if ($cal.Stage -eq 'verify' -and $null -eq $u.VerifyList -and [bool]$cal.Slope -and $null -ne $u.Fit) {
            $sp = Get-VerifySlope $u ([double]$cal.MaxCoarse) ([int]$script:CalSlopeMinCyl) ([double]$script:CalSlopeSigK) ([double]$script:CalSlopeMinNsNs) ([double]$script:CalSlopeMinNs)
            $u.VSlope = @{ V = [int]$cal.VerifyCount; B = [double]$sp.B; SB = [double]$sp.SB; A = [double]$sp.A; N = [int]$sp.N; Ok = [bool]$sp.Ok; Why = [string]$sp.Why }
            if ($sp.Ok -and $sp.Bad.Count -gt 0) {
                $u.SlopeBad = $sp.Bad
                $bc = @($sp.Bad.Keys | ForEach-Object { [int]$_ } | Sort-Object)
                Append-Log ($u.Prefix + ((T "Vérification {0} : erreur de modèle aux forts besoins : au-delà de {1} ns écrits, le résidu suit la valeur écrite, pente {2} ns/ns (incertitude {3}, {4} cylindres), de {5} ns à {6} ns d'une extrémité à l'autre ({7} à {8} ns écrits) : {9} cylindre(s) corrigé(s) à leur zéro mesuré, même dans la tolérance ({10}).") -f "$($cal.VerifyCount)", (Format-UiNum ([double]$sp.X0) '0'), (Format-UiNum ([double]$sp.B) '0.000'), (Format-UiNum ([double]$sp.SB) '0.000'), "$($sp.N)", (Format-UiNum ([double]$sp.FMin) '0.0'), (Format-UiNum ([double]$sp.FMax) '0.0'), (Format-UiNum ([double]$sp.PMin) '0'), (Format-UiNum ([double]$sp.PMax) '0'), "$($bc.Count)", (($bc | ForEach-Object { "c$_" }) -join ', ')))
            }
            # banc 1210-a (N1) : pente etablie mais aucun residu de la droite au-dela de CalSlopeMinNs : rien a corriger, dit tel quel
            elseif ($sp.Ok) { Append-Log ($u.Prefix + ((T "Vérification {0} : pente du résidu avec la valeur écrite au-delà de {1} ns : {2} ns/ns (incertitude {3}, {4} cylindres), établie mais sans résidu de la droite au-delà de {5} ns : aucune correction.") -f "$($cal.VerifyCount)", (Format-UiNum ([double]$sp.X0) '0'), (Format-UiNum ([double]$sp.B) '0.000'), (Format-UiNum ([double]$sp.SB) '0.000'), "$($sp.N)", (Format-UiNum ([double]$script:CalSlopeMinNs) '0'))) }
            elseif ($sp.Why -ne 'cylindres') { Append-Log ($u.Prefix + ((T "Vérification {0} : pas d'erreur de modèle aux forts besoins : pente du résidu avec la valeur écrite {1} ns/ns (incertitude {2}, {3} cylindres au-delà de {4} ns écrits), dans le bruit ou négligeable.") -f "$($cal.VerifyCount)", (Format-UiNum ([double]$sp.B) '0.000'), (Format-UiNum ([double]$sp.SB) '0.000'), "$($sp.N)", (Format-UiNum ([double]$sp.X0) '0'))) }
        }
        if ($cal.Stage -eq 'level') { Write-LevelPassLog $cal $u ([int]$cal.LPass) }
    }
    if ($cal.Stage -eq 'level') { Invoke-LevelStep $cal $tracks; return }
    if ($cal.Stage -eq 'coarse') {
        # 12.7 : controle de surface de la disquette de calibration sur la relecture de la passe 1 (motif ecrit aux niveaux
        # de la passe 1, 3 tours),
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
            foreach ($l in (Format-CalibSurfaceLog $sf $std $(if ($gross) { 'none' } else { 'reserve' }) -Mixed ([bool]$cal.Latin))) { Append-Log $l }
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
                # 12.10 : calibration croisee : la disquette est dans la cible ; une autre disquette va dans la source
                if ($cal.Cross) { $notes += ((T "Calibration croisée : la disquette est dans le lecteur {0}, celui qui relit. Pour changer de disquette, insérez l'autre disquette sacrifiée dans le lecteur {1}, celui qui écrit.") -f "$($cal.Cross.Tgt)", "$($cal.Cross.Src)") }
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
                    $txt = Get-CalibSurfaceText $sf $opt $std ([bool]$cal.AutoStart) -Extra @($mc.Lines) -Notes @($notes) -Medium $mc -Hd $hdFam -Mixed ([bool]$cal.Latin)
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
        if ($cal.Latin) { Set-CalibPassOffsets $cal }        # 12.9 (correction 2)
        foreach ($u in $cal.Units) {
            if (-not (Set-CalibEstimates $u)) { $cal.TotalPasses = $cal.PassesDone; Complete-PrecompCalib; return }
        }
        # Encadrement : un cylindre encore sous-compense a la plus forte valeur mesuree a un zero extrapole, peu sur (la
        # pente varie hors de la plage mesuree) : une passe le mesure a son estimation + marge pour l encadrer, au plus au
        # plafond des passes de mesure (CalMaxNs) ; au-dela, zero extrapole de ces mesures, ecrit puis mesure par la verification.
        $cal.MaxCoarse = [int](@($cal.Values) | Measure-Object -Maximum).Maximum   # 12.10 : niveaux de la famille
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
        # 12.9 (correction 4) : confirmation des dents par cette verification (hors passe du nouvel essai). Cylindres relus a
        # cette passe, temoins de derive compris (relus a leur valeur inchangee : leur zero vaut pour la baisse entre deux
        # cylindres, le decalage commun de la passe s annulant dans la difference) ; $readNow, lui, exclut les temoins (points
        # de Results). VerifyList est encore celle de la passe (remise a vide a la ligne suivante)
        $dentRedo = $false
        if ([int]$cal.Retests -eq 0 -and @(Get-FitDents $u.Fit).Count -gt 0) {
            $readAll = if ($null -ne $u.VerifyList) { [int[]]@(@($u.VerifyList) | ForEach-Object { [int]$_ }) } else { [int[]]@($u.Verify.Keys | ForEach-Object { [int]$_ }) }
            $dentRedo = Update-CalibDents $u ([int]$cal.VerifyCount) ([int]$cal.VerifyCount -ge $script:CalMaxVerify) $readAll
        }
        $u.VerifyList = @()
        $corr = 0; $delta = @{}
        $fl = Get-ResidualFlags $u           # residus retenus : ecart regional, marche au bord, residu tres grand ou cylindre epars (pas un ecart local)
        # 12.10 : cylindres de la tendance des forts besoins (Get-VerifySlope, SlopeBad) retenus meme dans la tolerance, et
        # retires des ecarts locaux isoles ; consomme ici (une verification)
        if ($u.SlopeBad -and $u.SlopeBad.Count -gt 0) {
            foreach ($c in @($u.SlopeBad.Keys)) { if ($u.Est.ContainsKey([int]$c)) { $fl.Bad[[int]$c] = $true } }
            $fl.Spot = @($fl.Spot | Where-Object { -not $u.SlopeBad.ContainsKey([int]$_) })
            $u.SlopeBad = $null
        }
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
        if (($corr -eq 0 -and -not $dentRedo) -or $cal.VerifyCount -ge $script:CalMaxVerify -or [int]$cal.Retests -gt 0) { continue }
        # Courbe monotone par segments : pres d un changement de sens, les mesures des premieres passes (cylindres ecrits
        # seuls, loin du zero) et celles de la verification (profil complet ecrit dans l ordre, comme l image) peuvent
        # differer bien au-dela de leur incertitude. Une correction par l estimation combinee, dans des segments figes,
        # fondrait alors le sommet et ses voisins en palier (PAVA). La courbe est reajustee sur les zeros locaux de la
        # verification : precomp appliquee - residu / pente, mesures prises au plus pres du zero et dans les conditions
        # de l ecriture ; les changements de sens peuvent se deplacer.
        # 12.9 (correction 4) : aussi avec une dent dans la courbe, ou une dent retiree par cette verification (Update-CalibDents)
        if (@($u.Fit.Breaks).Count -gt 0 -or @(Get-FitDents $u.Fit).Count -gt 0 -or $dentRedo) {
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
            $dk = @(Get-FitDents $u.Fit -Admitted)
            if ($zv.Count -ge 4) { $re = Fit-PrecompCurve $zv $zs $cal.MaxCyl $null ($cal.Mode -eq 'fine' -or [bool]$cal.Densified) -Dents $dk }
            # 12.9 : dent que le reajustement ne coupe plus (hors d un segment croissant de la courbe reajustee, ou cylindres
            # non voisins dans les zeros de la verification) : journal
            if ($re) { foreach ($d in $dk) { if (@($re.Dents) -notcontains $d) { Append-Log ($u.Prefix + ((T "Dent entre c{0} et c{1} non reprise par le réajustement de la courbe sur la vérification (dent hors d'un segment croissant de la courbe réajustée, ou cylindres non voisins) : la courbe ne la suit plus.") -f "$($d.C1)", "$($d.C2)")) } } }
            if ($re -and (@($re.Breaks).Count -gt 0 -or @(Get-FitDents $re).Count -gt 0)) {
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
                $u.Fit = @{ Model = 'seg+c'; A = $null; B = $null; Chi = $re.Chi; Values = $re.Values; Breaks = $re.Breaks; Segs = $re.Segs; Outliers = $u.Fit.Outliers; Dents = @(Get-FitDents $re) }
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
        $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $newVals; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers; Dents = @(Get-FitDents $u.Fit) }
        $u.Profile = $newProfile
        # 12.9 (revue du 31/10/2026, m2) : dent retiree par cette verification sans cylindre a corriger, courbe sans
        # changement de sens (reajustement sur les zeros de la verification ecarte ci-dessus, faute de Breaks et de dent) :
        # la courbe est seulement lissee, sans la dent, dans ses segments fusionnes (Merge-CurveDentSegs)
        if ($corr -eq 0 -and $dentRedo) { Append-Log ($u.Prefix + ((T "Courbe lissée sans la dent retirée, nouveau profil : {0}") -f "$($u.Profile)")) }
        else { Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}") -f "$corr", "$($u.Profile)")) }
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

function Get-CalibRetestCause([bool]$surf, [bool]$dftUse, [double]$driftStep, [bool]$hasPrev) {
    # 12.9 (L2-c) : cause qui exclut toute une unite du nouvel essai automatique (Get-CalibRetestPlan) : disquette douteuse
    # au controle de surface, ou forte derive du lecteur (au-dela de 2 tolerances) sur le dernier intervalle. Derive non
    # retiree faute de temoins : plus d exclusion (journaux du 27/10/2026) ; la passe du nouvel essai a ses propres temoins
    # (Add-DriftWitnesses) et son jugement retire la derive qu ils mesurent (NoDrift : ligne de journal). Fonction pure.
    # Renvoie @{ Why ('' : pas d exclusion) ; NoDrift }
    if ($surf) { return @{ Why = (T 'disquette de calibration douteuse au contrôle de surface'); NoDrift = $false } }
    if ($dftUse -and [math]::Abs($driftStep) -gt 2.0 * [double]$script:CalResidual) {
        return @{ Why = ((T 'forte dérive du lecteur entre deux vérifications ({0} ns)') -f ('{0:+0.0;-0.0;0.0}' -f $driftStep)); NoDrift = $false }
    }
    return @{ Why = ''; NoDrift = ((-not $dftUse) -and $hasPrev) }
}

function Get-CalibRetestPlan($cal) {
    # 12.8 (lot 1b, decisions128.md) : plan du nouvel essai automatique apres la derniere verification, sans rien modifier.
    # Par unite, cylindres non converges (Get-CalibWarnings : NonConvC, residu juge NonConvR) dont la cause n est pas
    # exclue. Causes exclues pour toute l unite : disquette douteuse au controle de surface de la premiere passe (reserve
    # « support » ; defaut de vitesse seul : non), derive du lecteur forte (au-dela de 2 tolerances, reserve « derive »).
    # 12.9 (L2-b, L2-c) : derive non retiree : plus exclue (Get-CalibRetestCause) ; zone non reproductible (Contra) et
    # cylindres non reproductibles : seuls les cylindres a 2 cylindres au plus d eux (Split-CalibRetestZone).
    # Pour un cylindre : valeur visee au plafond (CalHardNs) ou au plancher (0), ou piste deja ecrite le
    # nombre de fois annonce par l avertissement (WriteMax, maximum de la 12.7 : le nouvel essai ne le releve pas).
    # 12.9 (banc cal2, option A) : en double densite au calcul 12.9, WriteMax compte le nouvel essai a part
    # (Start-PrecompCalib) : un cylindre encadre n est plus refuse ; haute densite : maximum de la 12.7, inchange.
    # Valeur visee : zero de la mesure jugee, valeur ecrite - residu juge / pente de l unite (residu juge : derive retiree,
    # temoin sur sa mesure precedente, comme Get-CalibWarnings), bornee par les cylindres verifies non vises voisins dans le
    # sens du segment ; cylindre « non relu » : relu a sa valeur. Courbe corrigee comme a la verification
    # (Add-CurveCorrection : 0 aux autres cylindres verifies, monotonie par segments). Relus :
    # cylindres vises, leurs voisins immediats parmi les cylindres mesures (hors points isoles) et les cylindres dont la
    # valeur change ; temoins de derive ajoutes par Start-CalibRetest (Add-DriftWitnesses).
    # Renvoie @{ Go ; Skip } : plans @{ U ; NonConv ; Targets ; Why ; Values ; Profile ; List ; Corr ; NcR } (Skip : NonConv,
    # Why). NcR (12.8, VAL01) : residus juges et valeurs ecrites avant le nouvel essai (NonConvR), pour la correction sans
    # effet (Restore-CalibRetestNoEffect). 12.9 (banc cal2, G4-02 ; revue fix2) : cylindres de Skip, quel que soit le
    # motif, ni vises ni corriges, gardes par Start-CalibRetest (RtFull) s ils ne sont pas relus ; Full (piste deja
    # ecrite WriteMax fois, jamais relue) et Lim (valeur visee hors des limites) nomment deux de ces motifs.
    $go = @(); $skip = @()
    $surf = [bool](($cal.SurfKept -and $cal.Surf -and -not (Test-CalibSpeedOnly $cal.Surf $cal.Medium)) -or ($cal.Surf -and $cal.Surf.Defective -and -not $cal.SurfGross))
    $wmax = [int]$cal.WriteMax
    foreach ($u in @($cal.Units)) {
        if (-not $u.Fit -or -not $u.Profile) { continue }
        $w = Get-CalibWarnings $u ([int]$cal.MaxCyl)
        $nc = [int[]]@(@($w.NonConvC) | Where-Object { $null -ne $_ })
        if ($nc.Count -eq 0) { continue }
        $p = @{ U = $u; NonConv = $nc; Targets = @(); Why = ''; Values = $null; Profile = ''; List = @(); Corr = 0; NcR = $w.NonConvR; NoDrift = $false; Bound = @{}; Raw = @{}; Same = [int[]]@() }
        $dft = $w.Drift
        # 12.8 (S3-HIGH) : derive du dernier intervalle (Get-CalibDriftStep : apres un nouvel essai, la derive mesuree est
        # cumulee depuis le repere du jugement ; avant le premier, DriftBase est vide : derive mesuree telle quelle).
        # 12.9 (L2-c) : Get-CalibRetestCause (derive non retiree : nouvel essai juge sur ses propres temoins)
        $dStep = if ($dft.Use) { [double](Get-CalibDriftStep $u $dft) } else { 0.0 }
        $cz = Get-CalibRetestCause $surf ([bool]$dft.Use) $dStep ([bool]($u.VerifyPrev -and $u.VerifyPrev.Count -gt 0))
        $p.Why = $cz.Why; $p.NoDrift = $cz.NoDrift
        if ($p.Why) { $skip += $p; continue }
        # 12.9 (L2-b) : zone non reproductible (Contra), puis cylindres non reproductibles : seuls les cylindres non converges
        # a 2 cylindres au plus de l un d eux sont exclus (Split-CalibRetestZone), avec un message qui leur est propre
        $zc = [int[]]@(@($w.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
        if ($zc.Count -gt 0) {
            $sp = Split-CalibRetestZone $nc $zc 2
            if ($sp.Excl.Count -gt 0) { $skip += @{ U = $u; NonConv = [int[]]$sp.Excl; Why = ((T "à 2 cylindres au plus de la zone non reproductible d'une vérification à l'autre (c{0})") -f (Format-CylList $sp.Near)) } }
            $nc = [int[]]$sp.Keep
        }
        $nr = if ($dft.NonRepro) { [int[]]@(@($dft.NonRepro.Keys) | ForEach-Object { [int]$_ }) } else { [int[]]@() }
        if ($nr.Count -gt 0 -and $nc.Count -gt 0) {
            $sp = Split-CalibRetestZone $nc $nr 2
            if ($sp.Excl.Count -gt 0) { $skip += @{ U = $u; NonConv = [int[]]$sp.Excl; Why = ((T "à 2 cylindres au plus de cylindres non reproductibles d'une vérification à l'autre (c{0})") -f (Format-CylList $sp.Near)) } }
            $nc = [int[]]$sp.Keep
        }
        if ($nc.Count -eq 0) { continue }
        $p.NonConv = $nc
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
        if ($lim.Count) { $skip += @{ U = $u; NonConv = [int[]]$lim; Why = $lTxt; Lim = $true } }
        if ($full.Count) { $skip += @{ U = $u; NonConv = [int[]]$full; Why = $wTxt; Full = $true } }
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
            $p.Raw[[int]$c] = $t                                         # 12.9 : valeur visee avant les bornes (journal)
            $fl = @($fix | Where-Object { $_ -ge [int]$sg.Lo -and $_ -lt $c }); $fr = @($fix | Where-Object { $_ -gt $c -and $_ -le [int]$sg.Hi })
            $a = if ($fl.Count) { [double]$vals[$fl[-1]] } else { $null }; $b = if ($fr.Count) { [double]$vals[$fr[0]] } else { $null }
            $ca = if ($fl.Count) { [int]$fl[-1] } else { $null }; $cb = if ($fr.Count) { [int]$fr[0] } else { $null }
            if ([int]$sg.Dir -lt 0) { $x = $a; $a = $b; $b = $x; $x = $ca; $ca = $cb; $cb = $x }
            $by = $null
            if ($null -ne $a -and $t -lt $a) { $t = $a; $by = $ca }
            if ($null -ne $b -and $t -gt $b) { $t = $b; $by = $cb }
            $delta[$c] = $t - [double]$vals[$c]
            if ($null -ne $by) { $p.Bound[[int]$c] = [int]$by }            # 12.9 : voisin verifie qui borne la valeur visee
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
        $p.Same = [int[]]@($p.Targets | Where-Object { $w.NonConvR -and $w.NonConvR.ContainsKey([int]$_) -and [int]$newVals[$_] -eq [int]$vals[$_] })      # 12.9 : journal ; cibles non relues (ecart nul par construction, ligne « non relu : relu a sa valeur ») exclues
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
    # 12.9 (banc cal2, RT8, G4-02 ; revue fix2) : cylindres non converges exclus du nouvel essai, quel que soit le motif
    # (piste deja ecrite WriteMax fois, Full : ni reecrits ni relus ; valeur visee hors des limites, Lim ; proximite d une
    # zone ou de cylindres non reproductibles ; mesure complete : valeur visee inchangee, correction sans effet), et absents
    # des cylindres relus du plan de leur unite (cibles, voisins immediats, cylindres modifies ; un temoin de derive est
    # juge sur sa mesure precedente). Ils gardent le residu de la derniere verification : NON CONVERGES tant qu ils sont
    # hors tolerance (RtFull, Get-CalibWarnings, comme RtKept, FIXVAL01), meme si le voisinage corrige par la passe en
    # ferait un ecart local non retenu. Unite sans nouvel essai : ni relue ni jugee a nouveau, sans effet (ses cylindres
    # exclus sont deja non converges). Champ de l unite, recree avec elle comme RtKept (New-CalibUnit : nouvelle
    # calibration, calibration B, mesure complete, changement de disquette) ; jamais enregistre
    foreach ($p in @($plan.Skip)) {
        $rtRead = @(foreach ($gp in @($plan.Go)) { if ([object]::ReferenceEquals($gp.U, $p.U)) { @($gp.List) } })
        $rtNew = [int[]]@(@($p.NonConv) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Where-Object { $p.Full -or $rtRead -notcontains $_ })
        if ($rtNew.Count -gt 0) { $p.U.RtFull = [int[]]@(@(@($p.U.RtFull) + @($rtNew)) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique) }
    }
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
    # 12.9 : cylindres vises relus a leur valeur inchangee : bornes par leurs voisins verifies (dans le sens du segment), ou
    # ramenes par le lissage monotone ou l arrondi ; journal seulement
    foreach ($p in @($plan.Go)) {
        $ov = @($p.U.Fit.Values)
        $sm = [int[]]@(@($p.Same) | Where-Object { $null -ne $_ })
        foreach ($bd in $true, $false) {
            $l = [int[]]@($sm | Where-Object { $p.Bound.ContainsKey([int]$_) -eq $bd })
            if ($l.Count -eq 0) { continue }
            $vv = @($l | ForEach-Object { [int]$ov[$_] } | Sort-Object -Unique)
            $rv = @($l | ForEach-Object { [int][math]::Round([double]$p.Raw[[int]$_]) } | Sort-Object -Unique)
            $vTxt = if ($vv.Count -eq 1) { "$($vv[0])" } else { (T '{0} à {1}') -f "$($vv[0])", "$($vv[-1])" }
            $rTxt = if ($rv.Count -eq 1) { "$($rv[0])" } else { (T '{0} à {1}') -f "$($rv[0])", "$($rv[-1])" }
            if ($bd) {
                $byTxt = (@($l | ForEach-Object { [int]$p.Bound[[int]$_] } | Sort-Object -Unique | ForEach-Object { "c$_" })) -join ', '
                Append-Log ($p.U.Prefix + ((T "Calibration : nouvel essai des cylindres {0} à leur valeur inchangée ({1} ns) : valeur visée {2} ns, ramenée à la valeur écrite par les cylindres vérifiés voisins {3}, pour que la courbe reste monotone dans ce segment ; ils sont relus pour confirmer leur résidu, sans correction possible à ce nouvel essai.") -f (Format-CylList $l), $vTxt, $rTxt, $byTxt))
            }
            else { Append-Log ($p.U.Prefix + ((T "Calibration : nouvel essai des cylindres {0} à leur valeur inchangée ({1} ns) : valeur visée {2} ns, ramenée à la valeur écrite par le lissage monotone de la courbe ou par l'arrondi ; ils sont relus pour confirmer leur résidu.") -f (Format-CylList $l), $vTxt, $rTxt)) }
        }
    }
    # 12.9 (L2-c) : derive non retiree a la derniere verification : ligne ecrite apres le choix des temoins du nouvel essai (ci-dessous)
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
                      DriftBase = $u.DriftBase; DriftBaseV = $u.DriftBaseV; DriftOrigV = $u.DriftOrigV    # 12.8 (S3-HIGH)
                      DriftHold = $u.DriftHold }                                                          # 12.9 (RT7)
        $dft = Get-VerifyDrift $u
        # 12.9 (RT7) : zone non reproductible et cylindres non reproductibles de cette verification (nouvel essai lance loin
        # d eux, Split-CalibRetestZone) gardes avec leur valeur ecrite pour le jugement final (Add-VerifyDriftHold) : la
        # passe du nouvel essai ne les compare plus ; zone ramenee a sa mediane par Set-VerifyContra, comme sans nouvel essai.
        # Use : derive mesuree a cette verification (zone trouvee sans derive mesuree : reserve « contra-nodrift » gardee).
        # Cylindre non reproductible au plafond ou au plancher, hors tolerance : Sat ou Floor de Get-CalibWarnings (jugees
        # avant NonRepro ; jamais une zone, besoin entre les deux valeurs ecrites), pas garde. Aucun cylindre garde : aucun
        # DriftHold (cas ou la 12.8.2 lancait deja le nouvel essai)
        $hp = @{}
        foreach ($k in @($dft.Contra.Keys)) { if ($u.VerifyP.ContainsKey([int]$k)) { $hp[[int]$k] = [int]$u.VerifyP[[int]$k] } }
        foreach ($k in @($dft.NonRepro.Keys)) {
            $c = [int]$k
            if (-not $u.VerifyP.ContainsKey($c) -or -not $u.Verify.ContainsKey($c)) { continue }
            $pw = [int]$u.VerifyP[$c]
            if ($pw -ge $script:CalHardNs -or $pw -le 0) {
                $r = [double]$u.Verify[$c].Shift; if ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $r -= [double]$dft.D }
                if ([math]::Abs($r) -gt (Get-ResidualTol $u.Verify[$c]) -and (($r -gt 0 -and $pw -ge $script:CalHardNs) -or ($r -lt 0 -and $pw -le 0))) { continue }
            }
            $hp[$c] = $pw
        }
        $u.DriftHold = if ($hp.Count -gt 0) { @{ Contra = $dft.Contra; NonRepro = $dft.NonRepro; P = $hp; Use = ([bool]$dft.Use -and -not [bool]$dft.ContraNoDrift) } } else { $null }
        # Derive deja mesuree a la derniere verification (DriftBase, DriftBaseV) : celle du nouvel essai se compte depuis le
        # meme repere, cumulee ; la reserve « derive » de Complete-PrecompCalib juge le dernier intervalle seul. Sans derive
        # mesuree : aucune (chemins de la 12.7). 12.8 (S3-HIGH) : DriftOrigV, verification du repere (celle d avant la
        # premiere verification ciblee), gardee d un nouvel essai a l autre (mesure complete de cette disquette)
        $u.DriftBase = $null; $u.DriftBaseV = $null
        if ($dft.Use) { $u.DriftBase = [double]$dft.D; $u.DriftBaseV = $vLast; if ($null -eq $u.DriftOrigV) { $u.DriftOrigV = $vLast - 1 } }
        foreach ($k in @($u.Verify.Keys)) {
            $c = [int]$k
            # Temoin : jugement sur sa mesure precedente ; sa derniere mesure brute reste celle du journal (LogRaw, lu
            # seulement par la ligne « Residu apres verification » ; Res de la courbe : mesure precedente, comme en 12.7).
            # 12.9 : Raw deja pose (decalage commun de l ecriture retire a la verification complete, Invoke-CalibAnalysis) : garde
            # brut, jamais une valeur centree
            if (@($u.Witness) -contains $c -and $u.VerifyPrev -and $u.VerifyPrev.ContainsKey($c) -and -not $dft.Sys.ContainsKey($c)) { $m = $u.VerifyPrev[$c].Meas.Clone(); $m.LogRaw = [double]$u.Verify[$c].Shift; $u.Verify[$c] = $m; $u.VerifyP[$c] = [int]$u.VerifyPrev[$c].P }
            elseif ($dft.Use -and $u.ReadLast -and $u.ReadLast.ContainsKey($c)) { $m = $u.Verify[$c]; $u.Verify[$c] = @{ Shift = [double]$m.Shift - [double]$dft.D; SE = $m.SE; Score = $m.Score; Raw = $(if ($null -ne $m.Raw) { [double]$m.Raw } else { [double]$m.Shift }) } }
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
            $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $p.Values; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers; Dents = @(Get-FitDents $u.Fit) }
            $u.Profile = $p.Profile
            Append-Log ($u.Prefix + ((T "{0} cylindre(s) corrigé(s), résidu hors tolérance, nouveau profil : {1}") -f "$($p.Corr)", "$($u.Profile)"))
        }
        $u.VerifyList = @($p.List)
        Add-DriftWitnesses $u
        # 12.9 (L2-c, banc final D-L2c) : derive non retiree a la derniere verification : ligne ecrite apres le choix des
        # temoins du nouvel essai (Add-DriftWitnesses : aucun temoin sous WitMin candidats)
        if ($p.NoDrift) {
            if (@($u.Witness).Count -gt 0) { Append-Log ($u.Prefix + (T "Calibration : dérive du lecteur non retirée à la dernière vérification (témoins insuffisants) : le nouvel essai est jugé sur ses propres témoins de dérive.")) }
            else { Append-Log ($u.Prefix + (T "Calibration : dérive du lecteur non retirée à la dernière vérification (témoins insuffisants), et aucun témoin possible pour le nouvel essai : il est jugé sans correction de dérive.")) }
        }
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
    # DriftBase : derive mesuree telle quelle (12.7). 12.9 : la verification complete d avant etant centree par son decalage
    # commun (VOff, Invoke-CalibAnalysis), D est le decalage commun absolu de la passe ciblee (repere des passes de mesure) ;
    # la derive entre les deux verifications, difference de leurs decalages, en retire celui de la verification complete
    # (Get-VerifyOffsetM : 0 sans retrait, chemins inchanges) ; avec DriftBase, D - DriftBase est deja une difference
    if ($null -ne $u.DriftBase) { return [double]$dft.D - [double]$u.DriftBase }
    return [double]$dft.D - (Get-VerifyOffsetM $u)
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
            $u.Fit = @{ Model = "$base+c"; A = $u.Fit.A; B = $u.Fit.B; Chi = $u.Fit.Chi; Values = $new; Breaks = $u.Fit.Breaks; Segs = $u.Fit.Segs; Outliers = $u.Fit.Outliers; Dents = @(Get-FitDents $u.Fit) }
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
        $u.DriftHold = $s.DriftHold         # 12.9 (RT7) : zone gardee d avant cette passe (vide avant le premier nouvel essai)
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

function Write-CalibDentLog($u) {
    # 12.9 (correction 4) : bilan des dents locales du besoin suivies par la courbe d une unite (Warn.Dents, Get-CalibWarnings :
    # toujours un tableau ; filtre par securite : unite ou fixture sans ce champ, ou @($null) compte 1)
    if (-not $u -or -not $u.Warn) { return }
    foreach ($d in @(@($u.Warn.Dents) | Where-Object { $null -ne $_ })) {
        if ($d.Conf -eq $true) { Append-Log ($u.Prefix + ((T "Dent locale du besoin admise entre c{0} et c{1} ({2} ns) : mesurée par les passes de mesure, confirmée par la vérification {3}. La calibration mesure le besoin tel que le lecteur relit ses propres écritures : la courbe la suit, que la dent vienne de l'écriture ou de la lecture.") -f "$($d.C1)", "$($d.C2)", (Format-LevelNum $d.Drop), "$($d.V)")) }
        elseif ($null -ne $d.Conf) { Append-Log ($u.Prefix + ((T "Dent locale du besoin entre c{0} et c{1} ({2} ns), mesurée par les passes de mesure et suivie par la courbe, non confirmée par la dernière vérification ({3} ns entre leurs zéros) : ses résidus sont jugés normalement.") -f "$($d.C1)", "$($d.C2)", (Format-LevelNum $d.Drop), (Format-LevelNum $d.DV))) }
        else { Append-Log ($u.Prefix + ((T "Dent locale du besoin entre c{0} et c{1} ({2} ns), mesurée par les passes de mesure et suivie par la courbe, non confirmée : la vérification n'a pas relu ces deux cylindres.") -f "$($d.C1)", "$($d.C2)", (Format-LevelNum $d.Drop))) }
    }
}

function Complete-PrecompCalib {
    $cal = $script:Cal; $script:Cal = $null
    if (-not $cal) { return }
    $pbWCal.Value = 100
    $elapsedTotal = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $lblWCal.Text = ((T "Calibration terminée en {0}") -f (Format-CalDuration $elapsedTotal))
    if ($cal.Cross) { $lblWCal.Text = ((T "Calibration croisée terminée en {0}, {1} échange(s) de disquette") -f (Format-CalDuration $elapsedTotal), "$([int]$cal.Swaps)") }   # 12.10
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
            # 12.9 : decalage commun de l ecriture retire a la verification complete (VOff) : les residus de cette ligne restent
            # bruts (Raw), le rappel du decalage retire explique l ecart avec les residus juges des lignes de reserve
            $resNote = if ($null -ne $u.VOff -and [bool]$u.VOff.Removed) { (T " Résidus bruts, décalage commun de chaque écriture compris (vérification {0} : {1} ns, retiré avant le jugement).") -f "$($u.VOff.V)", ('{0:+0.0;-0.0;0.0}' -f [double]$u.VOff.M) } else { '' }
            Append-Log ($u.Prefix + ((T "Résidu après vérification (ns, tolérance {0}, élargie à 3 erreurs-types si la mesure est plus bruitée) : {1}") -f "$($script:CalResidual)", "$resTxt") + $resNote)
        }
        $u.Warn = Get-CalibWarnings $u $cal.MaxCyl
        $dft = $u.Warn.Drift
        if ($dft.Use) {
            $sla = if ($null -ne $u.Slope -and [double]$u.Slope -lt -0.2) { [math]::Abs([double]$u.Slope) } else { 2.0 }
            $dsp = if ([double]$dft.SRaw -ge 1.0) { "$(Format-LevelNum $dft.SRaw) ns" } else { (T 'moins de 1 ns') }
            # 12.8 (lot 1b) : apres un nouvel essai, derive comptee depuis le repere du jugement (DriftBase : part deja mesuree
            # a la derniere verification d avant le nouvel essai) ; $dIv : dernier intervalle seul, juge par la reserve
            $dIv = Get-CalibDriftStep $u $dft
            # 12.9 : la verification complete etant centree par son decalage commun m1 (VOff, Invoke-CalibAnalysis), D est le
            # decalage commun absolu de la derniere passe ; les lignes gardent leur sens (derive = difference des decalages des
            # deux verifications) : D - m1 en tout, DriftBase - m1 jusqu a la verification d avant le nouvel essai, $dIv pour le
            # dernier intervalle, DC - m1 pour les cylindres corriges ; le decalage absolu de la passe est ajoute a la fin quand
            # m1 a ete retire. Sans retrait (m1 = 0) : lignes identiques a celles d avant
            $m1 = Get-VerifyOffsetM $u; $dAll = [double]$dft.D - $m1
            if ($null -ne $u.DriftBase) {
                $lt = (T "Dérive du lecteur depuis la vérification {0}, nouvel essai compris : {1} ± {2} ns de décalage commun sur {3} cylindres témoins (dispersion {4}), soit {5} ns jusqu'à la vérification {6}, puis {7} ns jusqu'à la vérification {8}.") -f "$(if ($null -ne $u.DriftOrigV) { [int]$u.DriftOrigV } else { [int]$u.DriftBaseV - 1 })", ('{0:+0.0;-0.0;0.0}' -f $dAll), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp", ('{0:+0.0;-0.0;0.0}' -f ([double]$u.DriftBase - $m1)), "$([int]$u.DriftBaseV)", ('{0:+0.0;-0.0;0.0}' -f $dIv), "$($cal.VerifyCount)"
            }
            else { $lt = (T "Dérive du lecteur entre les deux vérifications : {0} ± {1} ns de décalage commun sur {2} cylindres témoins (dispersion {3}).") -f ('{0:+0.0;-0.0;0.0}' -f $dAll), (Format-LevelNum $dft.E), "$($dft.NW)", "$dsp" }
            $pdv = [math]::Round([math]::Abs($dAll) / $sla, 1); $pd = Format-LevelNum $pdv
            if ($pdv -le 0) { }
            elseif ($dAll -gt 0) { $lt += (T " Le besoin de précompensation était plus élevé de {0} ns à la dernière vérification.") -f "$pd" }
            elseif ($dAll -lt 0) { $lt += (T " Le besoin de précompensation était plus faible de {0} ns à la dernière vérification.") -f "$pd" }
            if ([int]$dft.NC -gt 0) { $lt += (T " Écart des cylindres corrigés à leur prédiction, dérive comprise : {0} ns en médiane sur {1}.") -f ('{0:+0.0;-0.0;0.0}' -f ([double]$dft.DC - $m1)), "$($dft.NC)" }
            $lt += (T " Les résidus des cylindres relus à la dernière vérification sont jugés sans ce décalage ; les témoins, inchangés, sur leur mesure précédente, sauf ceux d'un écart systématique, jugés sur leur relecture.")
            if ($null -ne $u.VOff -and [bool]$u.VOff.Removed) { $lt += (T " Décalage commun de la vérification {0} : {1} ns, retiré de ses résidus.") -f "$($cal.VerifyCount)", ('{0:+0.0;-0.0;0.0}' -f [double]$dft.D) }
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
            elseif (-not $dft.Use -or $dft.ContraNoDrift) { $issues.Add($u.Prefix + ((T "vérifications contradictoires aux cylindres {0} sans mesure de la dérive du lecteur (écart jusqu'à {1} ns : dérive du lecteur ou zone non reproductible ?)") -f "$cl", (Format-LevelNum $em))); $kinds.Add('contra-nodrift') }
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
        # 12.10 (lot 1, A13a) : mesure de la disquette seule : plafond de cette disquette (Get-DiskHardNs), libelle neutre
        # de la calibration rapide (autre type de disquette ou usure), sans mettre en cause une disquette sacrifiee
        if ($u.Warn.Sat.Count -gt 0) {
            $satTxt = if ($cal.DiskOnly) { (T "plafond de {0} ns atteint aux cylindres {1} (autre type de disquette ou usure ?)") } else { (T "plafond de {0} ns atteint aux cylindres {1} (support fatigué ?)") }
            $issues.Add($u.Prefix + ($satTxt -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', '))); $kinds.Add('sat')
        }
        if ($u.Warn.Floor.Count -gt 0) { $issues.Add($u.Prefix + ((T "précompensation nulle encore excessive aux cylindres {0}") -f ($u.Warn.Floor -join ', '))); $kinds.Add('floor') }
        if ($u.Warn.Dev.Count -gt 0) { $issues.Add($u.Prefix + ((T "courbe éloignée des mesures (courbe moins mesure) : {0}") -f ($u.Warn.Dev -join ', '))); $kinds.Add('dev') }
        if ($u.Warn.NonConv.Count -gt 0) {
            $allConv = $false
            # 12.8 (S3) : mesure complete de cette disquette : pas de disquette sacrifiee a conseiller
            if ($cal.DiskOnly) { Append-Log ($u.Prefix + ((T "Mesure non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure de cette disquette à ces cylindres.") -f ($u.Warn.NonConv -join ', '))) }
            else {
                # 12.9 (L2-a, L2-d) : conseil selon la cause, verdict inchange. Marche du besoin non suivie par la courbe
                # (Get-CalibNeedSteps) ou meme ecart que la calibration A aux memes cylindres (calibration B,
                # Get-CalibCommonReserve) : signature du lecteur, pas de conseil de refaire sur une autre disquette
                $stC = @(); foreach ($st in @($u.Warn.Steps)) { if ($st) { $stC += @($st.Cyls) } }
                $ncU = [int[]]@(@($u.Warn.NonConvC) | Where-Object { $null -ne $_ })
                $cmn = [int[]]@()
                if ($cal.Redo -and $script:CalRedo -and $script:CalRedo.ACal) {
                    $ui = [array]::IndexOf(@($cal.Units), $u)
                    $ua = if ($ui -ge 0 -and $ui -lt @($script:CalRedo.ACal.Units).Count) { @($script:CalRedo.ACal.Units)[$ui] } else { $null }
                    if ($ua -and $ua.Warn) { $cmn = [int[]]@(Get-CalibCommonReserve (Get-CalibUnitReserve $ua.Warn) (Get-CalibUnitReserve $u.Warn)) }
                }
                $drv = @($ncU | Where-Object { $stC -notcontains $_ -and $cmn -notcontains $_ }).Count -eq 0
                if ($drv) { Append-Log ($u.Prefix + ((T "Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres.") -f ($u.Warn.NonConv -join ', '))) }
                else { Append-Log ($u.Prefix + ((T "Calibration non convergée aux cylindres {0} : résidu hors tolérance après la dernière vérification, la courbe ne suit pas la mesure à ces cylindres. Refaire la calibration en test fin, ou sur une autre disquette sacrifiée.") -f ($u.Warn.NonConv -join ', '))) }
                foreach ($st in @($u.Warn.Steps)) {
                    if (-not $st) { continue }
                    Append-Log ($u.Prefix + ((T "Marche du besoin de {0} ns entre c{1} et c{2}, sous le seuil de rupture de la courbe ({3} ns) : la courbe garde un palier, écart de {4} ns au plus sur ces cylindres. Signature du lecteur si elle revient sur une autre disquette ; refaire la calibration n'y change rien.") -f (Format-LevelNum $st.Drop), "$($st.C1)", "$($st.C2)", (Format-LevelNum $u.Warn.StepBreak), (Format-LevelNum $st.Dev)))
                }
                if ($cmn.Count -gt 0) { Append-Log ($u.Prefix + ((T "Même écart aux cylindres {0} sur les deux disquettes : il vient du lecteur, pas du support.") -f (Format-CylList $cmn))) }
            }
        }
        if ($u.Warn.Sat.Count -gt 0) {
            $anySat = $true; $anyCeil = $true
            # 12.10 (lot 1, A13a) : mesure de la disquette seule : libelle neutre, l usure n est pas presumee
            if ($cal.DiskOnly) { Append-Log ($u.Prefix + ((T "Plafond de {0} ns atteint aux cylindres {1} : le besoin de cette disquette dépasse la précompensation maximale, la courbe reste au plafond et une nouvelle mesure n'y changera rien. Autre type de disquette ou usure, non distingués ; si d'autres disquettes saturent aussi, c'est le lecteur.") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', '))) }
            else { Append-Log ($u.Prefix + ((T "Plafond de {0} ns atteint aux cylindres {1} : le besoin dépasse la précompensation maximale, la courbe reste au plafond et une nouvelle calibration n'y changera rien. Si une disquette en bon état sature aussi, c'est le lecteur ; sinon, c'est le support, probablement fatigué.") -f "$($script:CalHardNs)", ($u.Warn.Sat -join ', '))) }
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
                Append-Log ($u.Prefix + (Get-DiskOverAdviceText $thr))   # 12.11 : conseil d essai sur la machine cible
                $issues.Add($u.Prefix + ((T "courbe de cette disquette au-delà de {0} ns aux cylindres {1} (jusqu'à {2} ns, plafond porté à {3} ns pour cette disquette seulement) : contrôle après écriture imposé") -f "$thr", (Format-CylList $ov), "$top", "$($cal.HardNs)")); $kinds.Add('over')
            }
        }
        $bk = @($u.Warn.Breaks)
        if ($bk.Count -ge 2) { Append-Log ($u.Prefix + ((T "Changement de sens du besoin entre c{0} et c{1} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])", "$($bk[1])")) }
        elseif ($bk.Count -eq 1) { Append-Log ($u.Prefix + ((T "Le besoin redescend à partir de c{0} : courbe monotone par segments. La même signature sur une autre disquette désigne le lecteur, sinon le support.") -f "$($bk[0])")) }
        Write-CalibDentLog $u        # 12.9 (correction 4)
        if ($u.Warn.Dev.Count -gt 0) { Append-Log ($u.Prefix + ((T "Écart à la courbe de plus de {1} ns et de trois incertitudes (courbe moins mesure) : {0}.") -f ($u.Warn.Dev -join ', '), (Format-UiNum $script:CalDevNs))) }
        # Calibration precedente du meme lecteur (encore en memoire, remplacee plus bas) : la forme de la courbe tient au
        # lecteur, son niveau au support ; un ecart net, ou un plafond nouveau, designe le support de calibration
        $pkey = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $prev = $script:PrecompCurves[$pkey]   # 12.10 : vue du lecteur courant, lecteur de la courbe controle ci-dessous (les bancs remettent la vue a zero)
        if ($cal.Cross) { $prev = Get-DriveCurve (Get-CalibStoreDrive $cal) $pkey }   # 12.10 : courbe croisee precedente (meme source, meme cible)
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
    # 12.10 : cles de magasin du lecteur de la calibration (courbes par lecteur)
    # Calibration croisee : lecteur de magasin « source>cible » (Get-CalibStoreDrive)
    [void](Backup-ConfigBeforeRef @($cal.Units | ForEach-Object { Get-DriveCurveKey (Get-CalibStoreDrive $cal) (Get-CalibUnitKey $cal $_) }) 'replace')
    # Etat precedent (courbes et profils remplaces ci-dessous) : retabli si l utilisateur refuse un resultat douteux
    $prevCal = Get-CalibSnapshot @($cal.Units | ForEach-Object { Get-DriveCurveKey (Get-CalibStoreDrive $cal) (Get-CalibUnitKey $cal $_) })
    # Profil commun : remplace celui de la famille. Ecriture lente : courbes par tete, le profil commun est conserve.
    # 12.10 : courbe croisee : le profil de famille du lecteur (sa courbe propre) n est pas touche
    if (-not $cal.Slow -and -not $cal.Cross) {
        $spec = $cal.Units[0].Profile
        # 12.7 : haute densite : profil tire de sa courbe commune (Get-HdProfile), aucun profil de famille a remplacer
        # 12.10 : profil de la vue du lecteur du bandeau seulement ; pour un autre lecteur (lecteur change dans le bandeau
        # pendant la calibration), Sync-PrecompCurves le tire de la courbe commune au retour sur ce lecteur
        if ([string]$cal.Drive -eq [string]$cmbDrive.Text) {
            if ($cal.Family -eq 'long') { $script:PrecompLong = $spec } elseif ([string]$cal.Family -ne 'hd') { $script:PrecompStd = $spec }
        }
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
        $maxX = 0
        foreach ($c in $cs) { foreach ($x in @($u.Results[$c].Keys)) { if ([int]$x -gt $maxX) { $maxX = [int]$x } } }
        $asym = Get-UnitAsymRef $cal $u     # 12.10 : asymetrie de reference (motif relu a la verification 1)
        # 12.10 : courbe rangee sous le lecteur de la calibration (Set-DriveCurve : magasin, puis vue du lecteur courant) ;
        # calibration croisee : sous « source>cible » (Get-CalibStoreDrive), Drive = source (qui ecrit), Target = cible (qui relit)
        Set-DriveCurve (Get-CalibStoreDrive $cal) $key @{
            Family = $famTxt; Head = $u.Head; Drive = $cal.Drive; Target = $(if ($cal.Cross) { [string]$cal.Cross.Tgt } else { '' }); Date = $date; Model = $u.Fit.Model; Spec = $u.Profile; Method = 'motif'
            Version = $script:Version; Algo = $script:CalibAlgo; Calc = $(if ([string]$cal.Family -eq 'hd') { $script:CalibCalcHd } else { $script:CalibCalc }); Breaks = [int[]]@($u.Fit.Breaks)
            Values = [int[]]@($u.Fit.Values); Cyls = [int[]]$cs
            Ys = [double[]]@($cs | ForEach-Object { [math]::Round([double]$u.Est[$_], 1) })
            Sig = [double[]]@($cs | ForEach-Object { [math]::Round($(if ($u.Sig.ContainsKey($_)) { [double]$u.Sig[$_] } else { 5.0 }), 1) })
            Kinds = [string[]]@($cs | ForEach-Object { [string]$u.Kind[$_] })
            # 12.9 (voff, revue M2) : Res = residu juge (Shift centre du decalage commun de l ecriture ; temoin : son jugement
            # precedent), lu comme tel par la calibration rapide (260), Test-CurveAtMax et la fenetre Courbe (230) ; le brut
            # reste au journal (« Residu apres verification ») ; hors VOff (haute densite, calcul 12.7) : regle de la 12.8, brut des relus
            Res = [double[]]@($cs | ForEach-Object { if (@($u.Warn.Contra) -contains $_ -or @($u.ContraMoved) -contains $_) { [double]::NaN } elseif (@($u.Witness) -contains $_ -and $u.VerifyPrev.ContainsKey($_) -and -not $u.Warn.Drift.Sys.ContainsKey($_)) { [math]::Round($(if ([bool]$cal.VOff) { [double]$u.VerifyPrev[$_].Shift } elseif ($u.VerifyPrev[$_].Meas -and $null -ne $u.VerifyPrev[$_].Meas.Raw) { [double]$u.VerifyPrev[$_].Meas.Raw } else { [double]$u.VerifyPrev[$_].Shift }), 1) } elseif ($u.Verify.ContainsKey($_)) { [math]::Round($(if ([bool]$cal.VOff -or $null -eq $u.Verify[$_].Raw) { [double]$u.Verify[$_].Shift } else { [double]$u.Verify[$_].Raw }), 1) } else { [double]::NaN } })
            Converged = ($u.Warn.NonConv.Count -eq 0); MaxX = $maxX; MaxNs = [int]$script:CalHardNs
            # 12.10 : asymetrie de reference de la famille sur ce lecteur (Get-UnitAsymRef) : cylindres, ecarts 3T/2T - 1,5 et
            # 4T/2T - 2 du motif relu a la verification 1 ; 12.11 : gardes pour l etude, plus lus par l onglet Qualite
            AsymCyl = [int[]]@($asym.Cyl); AsymD3 = [double[]]@($asym.D3); AsymD4 = [double[]]@($asym.D4)
            Contra = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
            # 12.9 (correction 4) : toutes les dents de la courbe (confirmees, en attente, ou non confirmees a la derniere
            # verification et gardees), memes regles que Contra
            DentLo = [int[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_.C1 })
            DentHi = [int[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_.C2 })
            DentNs = [double[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [math]::Round([double]$_.Drop, 1) })
            Slope =$(if ($null -ne $u.Slope) { [math]::Round([double]$u.Slope, 3) } else { $null }); Bits = [int]$cal.PatternBits; Test = [string]$cal.Mode
        }
    }
    # 12.8 (lot 1c, § 10.5) : marques memorisees avec la reference remplacee : gardees, mais plus point de depart (date de
    # reference differente) ; une copie .bak retablie ou l abandon de la nouvelle courbe les rend de nouveau valables
    $brOld = @()
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        $pc = $prevCal.Curves[$key]
        if ($pc -and -not $cal.Cross) { $brOld += @(Get-LevelBrandsOfRef $key ([string]$pc.Date) ([string]$cal.Drive)) }   # 12.10 : aucune marque liee a une courbe croisee
    }
    $brOld = @($brOld | Sort-Object -Unique)
    if ($brOld.Count -gt 0) { Append-Log ((T 'Marques mémorisées avec la référence précédente ({0}) : elles seront mesurées de nouveau à leur prochaine calibration rapide.') -f ($brOld -join ', ')) }
    # Nouvelle reference de forme : les niveaux mesures avec la precedente sont abandonnes
    $dropped = @()
    foreach ($u in $cal.Units) {
        $key = if ($null -eq $u.Head) { $cal.Family } else { "$($cal.Family)_h$($u.Head)" }
        # 12.10 : niveaux de ce lecteur seulement (courbes par lecteur : la reference de l autre lecteur ne change pas) ; une
        # courbe croisee n est la reference d aucun niveau : rien d abandonne
        foreach ($k in @($script:LevelShifts.Keys)) { if (-not $cal.Cross -and $script:LevelShifts[$k] -and $script:LevelShifts[$k].RefKey -eq $key -and [string]$script:LevelShifts[$k].Drive -eq [string]$cal.Drive) { $script:LevelShifts.Remove($k); $dropped += $key } }
    }
    if ($dropped.Count -gt 0) { Append-Log ((T "Nouvelle référence de forme ({0}) : les niveaux mesurés avec la précédente sont abandonnés.") -f ((@($dropped | Sort-Object -Unique | ForEach-Object { Get-CurveKeyLabel $_ })) -join ', ')) }
    # Auto : applique le profil de la famille de l image ; carte Calibration de l Accueil : profil choisi dans l onglet
    # Ecriture respecte (Manuel compris), libelle du profil seulement pour une image de l onglet de la famille calibree
    # 12.10 : courbe croisee : profil de l image et champs --precomp inchanges (la courbe propre du lecteur ne change pas)
    if (-not $cal.Home -and -not $cal.Cross) { $cmbWProfile.SelectedIndex = 0 }
    if (-not $cal.Cross) { Update-PrecompForImage $txtWFile.Text }
    else {
        # 12.10 (relecture de la RC, fix2) : courbe croisee enregistree : bouton « Courbe » de l onglet (Update-CurveButton :
        # courbes que l ecriture applique, Get-WCurveSet ; cadre « Calibration du lecteur » de la restauration avec lui,
        # Update-RsCalib) et case de la mesure (Update-WLevelUi : infobulle du refus) recalcules d apres le refus de
        # l ecriture refait (Get-TargetWriteInfo), comme apres les autres changements de courbes ; libelle du profil (bilan
        # ci-dessous) et champs --precomp inchanges. Avant : rien de refait, bouton grise et infobulle « Ecriture refusee »
        # apres la calibration croisee qui leve ce refus
        Update-CurveButton $txtWFile.Text; Update-WLevelUi
    }
    $convTxt = if (-not $allConv) { (T ' NON CONVERGÉE : voir le journal et la fenêtre Courbe.') } elseif ($anySat) { ((T ' Limite de précompensation atteinte (0 ou {0} ns) : voir le journal.') -f "$($script:CalHardNs)") } else { '' }
    # 12.10 (relecture de la RC) : avertissement en tete des libelles de fin ($convHead), et non a leur suite : apres un
    # texte long (calibration croisee, profils par tete), il etait cache par les points de suspension de lblWCal (une
    # ligne, 520) et du libelle du profil (deux lignes)
    $convHead = if ($convTxt) { $convTxt.Trim() + ' ' } else { '' }
    $showLbl = (-not $cal.Home) -or ($cmbWProfile.SelectedIndex -eq 0 -and (Get-WriteTabFamily) -eq $cal.Family)
    # 12.10 (relecture de la RC) : lecteur cible choisi pour ce lecteur (Get-TargetDrive ; sans etat des lecteurs cibles,
    # 560 : aucun) : avec effet sur l image de l onglet (Get-TargetWriteInfo, celui de Start-ImageWrite), le libelle
    # d Update-PrecompForImage (courbe croisee nommee, ou refus en tete) reste : l ecriture suivante n applique pas la
    # courbe propre que la calibration vient de mesurer ; ligne de journal qui le dit. Avant : libelle « Profil ... calibre
    # ... (bouton Courbe) » a la place, refus du lecteur cible compris, et « applique par le mode Auto a toute image »
    $tgtC = if ($cal.Cross -or $null -eq $script:TargetDrives) { '' } else { [string](Get-TargetDrive ([string]$cal.Drive)) }
    if ($tgtC -and (Get-TargetWriteInfo $txtWFile.Text $cmbWFmt.Text ([bool]$chkWSlow.Checked)).Applies) { $showLbl = $false }
    if ($cal.Cross -and $cal.Slow) {
        # 12.10 : courbes croisees par tete
        $v0 = @($cal.Units[0].Fit.Values); $v1 = @($cal.Units[1].Fit.Values)
        $lblWProfileInfo.Text = $convHead + ((T "Courbes croisées {0} par tête calibrées le {1}, écriture par le lecteur {2} pour le lecteur {3} : tête 0 de {4} à {5} ns, tête 1 de {6} à {7} ns ; courbe propre du lecteur {2} inchangée.") -f "$famTxt", "$date", "$($cal.Cross.Src)", "$($cal.Cross.Tgt)", "$($v0[0])", "$($v0[-1])", "$($v1[0])", "$($v1[-1])")
    } elseif ($cal.Cross) {
        $v = @($cal.Units[0].Fit.Values)
        $lblWProfileInfo.Text = $convHead + ((T "Courbe croisée {0} calibrée le {1}, écriture par le lecteur {2} pour le lecteur {3} : de {4} à {5} ns, une valeur par cylindre ; courbe propre du lecteur {2} inchangée.") -f "$famTxt", "$date", "$($cal.Cross.Src)", "$($cal.Cross.Tgt)", "$($v[0])", "$($v[-1])")
    } elseif ($showLbl -and $cal.Slow) {
        $v0 = @($cal.Units[0].Fit.Values); $v1 = @($cal.Units[1].Fit.Values)
        $lblWProfileInfo.Text = $convHead + ((T "Profils {0} par tête calibrés le {1} sur le lecteur {2} : tête 0 de {3} à {4} ns, tête 1 de {5} à {6} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", "$($v0[0])", "$($v0[-1])", "$($v1[0])", "$($v1[-1])")
    } elseif ($showLbl) {
        $v = @($cal.Units[0].Fit.Values)
        $lblWProfileInfo.Text = $convHead + ((T "Profil {0} calibré le {1} sur le lecteur {2} : courbe {3}, de {4} à {5} ns, une valeur par cylindre (bouton Courbe).") -f "$famTxt", "$date", "$($cal.Drive)", (Get-CurveModelName $cal.Units[0].Fit.Model), "$($v[0])", "$($v[-1])")
    }
    if ($convTxt) { $lblWCal.Text = $convHead + $lblWCal.Text }
    foreach ($u in $cal.Units) {
        if ($cal.Cross) { Append-Log ($u.Prefix + ((T "Calibration croisée terminée : courbe {0} {1} → {2} = {3}") -f "$famTxt", "$($cal.Cross.Src)", "$($cal.Cross.Tgt)", "$($u.Profile)")) }   # 12.10
        else { Append-Log ($u.Prefix + ((T "Calibration terminée : profil {0} = {1}") -f "$famTxt", "$($u.Profile)")) }
        $v = @($u.Fit.Values)
        for ($c0 = 0; $c0 -lt $v.Count; $c0 += 10) {
            $hi = [math]::Min($v.Count - 1, $c0 + 9)
            $line = ((T "  Précomp cylindres {0}-{1} : {2} ns") -f "$c0", "$hi", "$((@($v[$c0..$hi])) -join ' ')")
            if ($u.Prefix) { $line = '  ' + $u.Prefix + $line.TrimStart() }
            Append-Log $line
        }
    }
    Append-Log ((T "Courbe obtenue avec le calcul de calibration v{0}.") -f "$(if ([string]$cal.Family -eq 'hd') { $script:CalibCalcHd } else { $script:CalibCalc })")
    if ($cal.Cross) {
        # 12.10 : bilan de la calibration croisee : cle de magasin, echanges de disquette, lecteur ou se trouve la disquette
        Append-Log ((T "Courbe croisée {0} enregistrée dans la configuration (clé « {1}>{2} ») pour les écritures du lecteur {1} destinées au lecteur {2} ; {3} échange(s) de disquette ; la disquette sacrifiée est dans le lecteur {4}.") -f "$famTxt", "$($cal.Cross.Src)", "$($cal.Cross.Tgt)", "$([int]$cal.Swaps)", $(if ([string]$cal.DiskAt -eq 'T') { "$($cal.Cross.Tgt)" } else { "$($cal.Cross.Src)" }))
    }
    elseif ($script:Restore) {
        if ($cal.Slow) { Append-Log ((T "Profils par tête appliqués par le mode Auto en écriture lente à toute image {0} ; ils seront enregistrés dans la configuration à la fin de la restauration.") -f "$famTxt") }
        else { Append-Log ((T "Profil appliqué par le mode Auto à toute image {0} ; il sera enregistré dans la configuration à la fin de la restauration.") -f "$famTxt") }
    }
    # 12.10 (relecture de la RC, fix1) : famille haute densite : ses ecritures haute densite en profil Auto pour le lecteur
    # cible sont refusees (Get-TargetWriteInfo, BlockKind 'hd' : la calibration croisee n existe qu en double densite),
    # courbe croisee double densite presente ou non ; avant : « appliquent la courbe croisee, et sont refusees sans elle »
    elseif ($tgtC -and [string]$cal.Family -eq 'hd' -and $cal.Slow) { Append-Log ((T "Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0} écrite par le lecteur {1} sans lecteur cible ; lecteur cible {2} choisi pour le lecteur {1} : ses écritures haute densité en profil Auto sont refusées, la calibration croisée n'existant qu'en double densité (liste « Lecteur cible » de l'onglet Écriture).") -f "$famTxt", "$($cal.Drive)", "$tgtC") }
    elseif ($tgtC -and [string]$cal.Family -eq 'hd') { Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0} écrite par le lecteur {1} sans lecteur cible ; lecteur cible {2} choisi pour le lecteur {1} : ses écritures haute densité en profil Auto sont refusées, la calibration croisée n'existant qu'en double densité (liste « Lecteur cible » de l'onglet Écriture).") -f "$famTxt", "$($cal.Drive)", "$tgtC") }
    elseif ($tgtC -and $cal.Slow) { Append-Log ((T "Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image {0} écrite par le lecteur {1} sans lecteur cible ; lecteur cible {2} choisi pour le lecteur {1} : ses écritures précompensées appliquent la courbe croisée {1} → {2}, et sont refusées sans elle (liste « Lecteur cible » de l'onglet Écriture).") -f "$famTxt", "$($cal.Drive)", "$tgtC") }
    elseif ($tgtC) { Append-Log ((T "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0} écrite par le lecteur {1} sans lecteur cible ; lecteur cible {2} choisi pour le lecteur {1} : ses écritures précompensées appliquent la courbe croisée {1} → {2}, et sont refusées sans elle (liste « Lecteur cible » de l'onglet Écriture).") -f "$famTxt", "$($cal.Drive)", "$tgtC") }
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
        if ($cal.Cross) { $offerRedo = $false }   # 12.10 : pas de calibration B (« Refaire sur une autre disquette ») en croise
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
    # 12.10 : courbes croisees « source>cible » (Show-CurvesWindow), sinon courbes du lecteur courant
    if ($cal.Cross) { Show-CurvesWindow (Get-DriveFamilyCurves (Get-CalibStoreDrive $cal) $cal.Family $cal.Slow) } else { Show-PrecompCurve $cal.Family $cal.Slow }
}
