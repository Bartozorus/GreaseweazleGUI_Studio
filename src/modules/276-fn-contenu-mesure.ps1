# ============================== FONCTIONS : MESURE SUR L IMAGE, DEROULE ==========

# 12.8.1 (lot B, spec-1281.md § A et B.3) : mesure de la disquette sur l image avant une ecriture lente (liste « Mesure :
# sur l image a ecrire », reglage levelBeforeWriteMode = content). Eligibilite de l image et du contexte
# (Test-ContentMeasurable), confirmation frmConfirm, etat de calibration au mode 'content' ($script:Cal : barre, bouton
# Arreter, prechauffage et minuteur de la calibration complete ; New-CalibPass renvoie le stade 'content' a
# New-ContentPass), 3 passes des 40 cylindres du plan ecrits avec l image elle-meme a k x V (carre latin, Get-ContentPlan),
# une commande gw write par tete puis une relecture de 3 tours ; arret « Failed to verify Track » de gw (110, 600) : piste
# gardee a son niveau, reprise de la tete une fois par passe ; marge fixe de chaque piste relue (Get-ContentPassStats),
# exclusions, facteur k* par tete (Get-ContentFactorNs depuis la 12.9), enregistrements de mesure, puis facteur de
# l ecriture qui suit ($script:WriteFactorNext, lu une fois par Start-ImageWrite) et ecriture de l image. Calcul : 192 et
# 274 (lot A) ; constantes et etat : 565 ; textes : 012.
# 12.9 (critique de la phase A, § 3.3) : marque de la disquette dans la fenetre (sautee en ecriture sans surveillance,
# $script:CalibUnattended, 560), 4e passe adaptative, relectures gardees et fichier compagnon JSON (D6) ; textes : 016.

function Get-ContentLevels {
    # Niveaux k du plan (A.4) : 1, k_mid, k_low ; reglages contentKMid et contentKLow (variables ContentKMid et ContentKLow,
    # controlees au chargement par Load-Config), sinon defauts de 565. Garde : 0 <= k_low <= k_mid - 0,2 et k_mid <= 0,8
    $d = [double[]]@($script:ContentLevelsDefault)
    $m = ConvertTo-FiniteOrNull $script:ContentKMid; $l = ConvertTo-FiniteOrNull $script:ContentKLow
    if ($null -eq $m -or $null -eq $l -or $l -lt 0 -or $l -gt $m - 0.2 + 1e-9 -or $m -gt 0.8 + 1e-9) { return ,$d }
    return ,([double[]]@(1.0, [double]$m, [double]$l))
}

function Format-ContentLevels([double[]]$levels) {
    # Niveaux au format de la langue, separes par « ; » (confirmation et journal) : « 1 ; 0,6 ; 0,25 »
    return ((@($levels) | ForEach-Object { Format-UiNum ([double]$_) '0.##' }) -join ' ; ')
}

function Format-CylRanges([int[]]$cyls) {
    # Cylindres en plages, syntaxe de gw (« 0-4,10-14,20-24 ») : --tracks=c= des commandes de la mesure et journal
    $s = @($cyls | Sort-Object -Unique)
    if ($s.Count -eq 0) { return '' }
    $parts = @(); $a = [int]$s[0]; $b = [int]$s[0]
    for ($i = 1; $i -le $s.Count; $i++) {
        if ($i -lt $s.Count -and [int]$s[$i] -eq $b + 1) { $b = [int]$s[$i]; continue }
        $parts += $(if ($a -eq $b) { "$a" } else { "$a-$b" })
        if ($i -lt $s.Count) { $a = [int]$s[$i]; $b = $a }
    }
    return ($parts -join ',')
}

function Test-ContentMeasurable([string]$img, [string]$fmt) {
    # Image et contexte de la mesure sur l image (A.2), conditions dans l ordre du tableau ; ecriture lente hors
    # restauration, profil Auto et --precomp coche, image a deux faces : controles des appelants (Start-LevelBeforeWrite,
    # Start-WriteTabWrite, Start-PresetWrite, Get-LevelWriteSkip) :
    #  - image double densite MFM calibrable (Get-WriteLevelKind 'dd' : ni flux, ni haute densite, ni secteurs durs ou
    #    TG43, densite etablie, cellule de 1 700 a 2 300 ns, module ScpStats), famille std ou long ;
    #  - champ Pistes vide (c=, h=, step= deja ecartes par Get-LevelWriteSkip ; hswap, h0.off... : pistes physiques que le
    #    plan, sans ces elements, ne viserait pas) ;
    #  - courbe(s) V du lecteur du bandeau (Get-FamilyCurves : par tete a jour, sinon la courbe commune pour les deux
    #    tetes, comme Set-PrecompFields), d au moins min(80, NCyl) valeurs ;
    #  - 20 cylindres au moins dans l image (4 blocs), et 20 par tete apres les exclusions d avant l ecriture.
    # Sortie : @{ Ok ; Why (raison du journal, T-B22) ; Img ; Drive ; Fam ; V = @{ 0 ; 1 } (int[]) ; RefKeys ; RefDates ;
    # Common ; NCyl ; Ncell0 ; PreSkip ; Levels ; Hard ; Plan } (plan construit ici pour compter les pistes par tete)
    $r = @{ Ok = $false; Why = ''; Img = $img; Drive = [string]$cmbDrive.Text; Fam = ''; V = @{}; RefKeys = @{}; RefDates = @{}; Common = $false
            NCyl = 0; Ncell0 = 0; PreSkip = @{}; Levels = [double[]]@(); Hard = 0; Plan = $null }
    $whyKind = (T 'image non mesurable sur son contenu (haute densité, flux, FM ou GCR)')
    if ((Get-WriteLevelKind $img $fmt) -ne 'dd') { $r.Why = $whyKind; return $r }
    $fam = Get-ImageFamily $img $fmt
    if (@('std', 'long') -notcontains $fam) { $r.Why = $whyKind; return $r }
    $r.Fam = $fam
    $ts = ([string]$txtWTracks.Text).Trim()
    if ($ts) { $r.Why = (T 'champ Pistes : {0}') -f "$ts"; return $r }
    $nc = (Get-CalibCylinders $img $fmt).NCyl
    $nc = if ($null -eq $nc) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$nc)) }
    $r.NCyl = $nc
    # Get-FamilyCurves : tableau protege (pas de @() autour)
    $cvs = Get-FamilyCurves $fam $true
    if ($cvs.Count -eq 0) { $r.Why = (T 'aucune courbe du lecteur {0}') -f "$($r.Drive)"; return $r }
    foreach ($cv in $cvs) { if ([string]$cv.Drive -ne $r.Drive) { $r.Why = (T "courbe d'un autre lecteur ({0})") -f "$($cv.Drive)"; return $r } }
    $need = [math]::Min([int]$script:ContentMaxCyl, $nc)
    # Valeurs des courbes par Get-RecValues (274) : une courbe sans cle Values compte 0 valeur
    foreach ($cv in $cvs) {
        $nv = @(Get-RecValues $cv).Count
        if ($nv -lt $need) { $r.Why = (T "courbe du lecteur plus courte que l'image ({0} cylindres, {1} dans l'image)") -f "$nv", "$nc"; return $r }
    }
    if ($nc -lt [int]$script:ContentMinCyl) { $r.Why = (T "moins de 20 cylindres dans l'image"); return $r }
    $common = ($cvs.Count -eq 1)
    $c0 = $cvs[0]; $c1 = if ($common) { $cvs[0] } else { $cvs[1] }
    $bl = Get-ContentBlocks $nc ([int]$script:ContentBlocks) ([int]$script:ContentBlockLen) ([int]$script:ContentMaxCyl) ([int]$script:ContentMinBlocks)
    if (-not $bl.Ok) { $r.Why = (T "moins de 20 cylindres dans l'image"); return $r }
    # Borne des valeurs ecrites : precompMaxNs de la double densite (CalHardNsUser, comme Get-WriteFactorPlan), a defaut
    # CalHardNs (bareme d une calibration haute densite pas encore retabli par le minuteur)
    $hard = [int]$script:CalHardNsUser; if ($hard -le 0) { $hard = [int]$script:CalHardNs }
    $lv = Get-ContentLevels
    $pre = Get-ContentImageSkip $img ([int[]]$bl.Cyls)
    $plan = Get-ContentPlan ([int[]]@(Get-RecValues $c0)) ([int[]]@(Get-RecValues $c1)) $nc $lv $hard $pre
    if (-not $plan.Ok -or [int]$plan.NCylHead[0] -lt [int]$script:ContentMinCyl -or [int]$plan.NCylHead[1] -lt [int]$script:ContentMinCyl) {
        $r.Why = (T "trop de pistes exclues de l'image (protégées, longues ou vides)"); return $r
    }
    $r.V = @{ 0 = [int[]]@(Get-RecValues $c0); 1 = [int[]]@(Get-RecValues $c1) }
    $r.RefKeys = @{ 0 = $(if ($common) { $fam } else { "${fam}_h0" }); 1 = $(if ($common) { $fam } else { "${fam}_h1" }) }
    $r.RefDates = @{ 0 = [string]$c0.Date; 1 = [string]$c1.Date }
    $r.Common = $common; $r.Ncell0 = [int](Get-PatternBits $fam $img).Bits; $r.PreSkip = $pre; $r.Levels = $lv; $r.Hard = $hard; $r.Plan = $plan
    $r.Ok = $true
    return $r
}

function Get-ContentWriteArgs($cal, $w) {
    # Commande gw write d une tete a la passe en cours (A.5) : memes options que l ecriture lente (Start-ImageWrite,
    # 140:135-162 : --pre-erase, --erase-empty et --no-verify selon les cases, --retries, Get-WriteFormatArgs), puis le
    # --precomp du plan de la passe et de la tete restreint aux cylindres de la commande ($w = @{ H ; Cyls ; Resume } :
    # commande complete, ou reprise apres un arret de gw), --tracks=c=<cylindres>:h=<tete> et l image. Jamais --tracks=h=
    # seul : ces commandes ne se confondent pas avec l ecriture finale (regex de rpm_analyse.precomp_journal).
    # 12.8.2 : double densite (Content.EraseMode 'hfreq', Start-ContentMeasure) : jamais --pre-erase, la passe commence par
    # un effacement haute frequence de ses pistes (New-ContentPass) ; autre mode : --pre-erase selon la case, comme avant
    $ct = $cal.Content
    $ph = $ct.Plan.Pass[[int]$ct.Pass].H[[int]$w.H]
    $sel = @{}
    foreach ($c in @($w.Cyls)) { $sel[[int]$c] = [int]$ph.W[[int]$c] }
    $a = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked -and [string]$ct.EraseMode -ne 'hfreq') { $a += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $a += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $a += '--no-verify' }
    $a += "--retries=$($numWRetries.Value)"
    $a += Get-WriteFormatArgs
    $a += @('--precomp', (Get-BracketSpec $sel), "--tracks=c=$(Format-CylRanges ([int[]]@($w.Cyls))):h=$([int]$w.H)", "`"$($cal.Image)`"")
    return ,([string[]]$a)
}

function Get-ContentMeasureMinutes([int]$nTracks, [int]$passes = 3, [switch]$NoWarmup) {
    # Duree estimee de la mesure avant l ecriture de l image (A.6) : 3 passes de nTracks pistes ecrites (ContentEstWrite,
    # 1,25 s par piste, ecriture verifiee) et relues (ContentEstRead, 0,85 s par piste, 3 tours), plus le prechauffage du
    # reglage warmFullCalib (borne haute : reduit ou saute si le lecteur vient de servir). 12.8.2 (revue) : effacement haute
    # frequence de chaque passe compris (Get-ContentEraseEst). 12.9 : $passes (1 : 4e passe adaptative), NoWarmup : sans
    # le prechauffage
    $wu = if (-not $NoWarmup -and [bool](Get-Setting 'warmFullCalib')) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    return [int][math]::Max(1, [math]::Round($passes * $nTracks * ([double]$script:ContentEstWrite + [double]$script:ContentEstRead + (Get-ContentEraseEst)) / 60 + $wu, 0))
}

function Get-ContentEraseEst {
    # 12.8.2 (revue) : duree estimee, en s par piste et par passe, de l effacement haute frequence de la mesure sur l image
    # (New-ContentPass : case « Effacer avant d ecrire » cochee, double densite, seule densite mesuree ici) ; 0 sinon
    if ($chkWPreErase.Checked -and (Get-EraseMode $false) -eq 'hfreq') { return [double]$script:EraseEstTrack }
    return 0.0
}

function Format-ContentNum($x, [string]$fmt) {
    # 12.9 : nombre du journal de la mesure au format de la langue (Format-UiNum), « - » s il n est pas fini
    $d = ConvertTo-FiniteOrNull $x
    if ($null -eq $d) { return '-' }
    return (Format-UiNum ([double]$d) $fmt)
}

function Format-ContentBrand([string]$brand) {
    # 12.9 : marque dans les textes, « (non precisee) » quand elle est vide
    $b = ([string]$brand).Trim()
    if ($b) { return $b }
    return (T '(non précisée)')
}

function Get-ContentBrandKText($dr) {
    # 12.9 : origine du k memorise (Get-DriveK, par marque) dans le journal de la mesure : mediane des N >= 2 dernieres
    # mesures, derniere mesure, mesures d un autre calcul a refaire, ou aucune mesure de la marque (nombre de mesures
    # d autres marques, jamais empruntees)
    $kTxt = Format-UiNum ([double]$dr.K) '0.00'; $bn = Format-ContentBrand ([string]$dr.Brand)
    if ([string]$dr.Src -eq 'lecteur') {
        if ([int]$dr.N -ge 2) { return ((T 'k {0}, médiane des {1} dernières mesures du lecteur pour la marque « {2} »') -f "$kTxt", "$($dr.N)", "$bn") }
        return ((T 'k {0} de la dernière mesure du lecteur pour la marque « {1} », du {2}') -f "$kTxt", "$bn", $(if ($dr.Rec -and $dr.Rec.Date) { [string]$dr.Rec.Date } else { '?' }))
    }
    # Revue de la phase B (mineur 1) : mesures ecartees seulement par ContentCalc (OldContent) : calcul de la mesure change,
    # calibration inchangee
    if ([int]$dr.Old -gt 0 -and [int]$dr.OldContent -ge [int]$dr.Old) { return ((T 'k 1, mesures de ce lecteur faites avant la {0} (calcul de la mesure changé), à refaire pour la marque « {1} »') -f "$($script:ContentCalc)", "$bn") }
    if ([int]$dr.Old -gt 0) { return (T 'k 1, mesures de ce lecteur faites avec un autre calcul de calibration, à refaire') }
    $oth = if ([int]$dr.Other -gt 0) { (T ' ; {0} mesure(s) d''autres marques') -f "$($dr.Other)" } else { '' }
    return ((T 'k 1, aucune mesure de ce lecteur pour la marque « {0} »{1}') -f "$bn", "$oth")
}

function Start-ContentMeasure($chk) {
    # Lancement de la mesure sur l image (A.8, A.9), $chk : Test-ContentMeasurable. Refus si gw tourne ; confirmation
    # frmConfirm sans case ni compte a rebours, reponse notee au journal par Show-AppConfirm : « Mesurer puis ecrire »
    # (mesure), « Ecrire sans mesure » (ecriture avec le facteur du lecteur), Fermer (ecriture annulee). Etat $script:Cal
    # au mode et au stade 'content' (barre, bouton Arreter, prechauffage et minuteur communs ; champs lus par
    # Update-CalibProgress, Start-CalibWarmup, Invoke-CalibWarmup, Stop-PrecompCalib), ecriture apres la mesure
    # (AfterCalib 'write', Complete-ContentMeasure), puis prechauffage s il y a lieu et premiere passe. Refus (gw en cours,
    # avant ou apres la confirmation) : ecriture annulee, une ligne de journal (revue 12.8.1, point 7)
    $refusTxt = (T 'Écriture annulée : une commande gw est déjà en cours, mesure de la disquette non lancée.')
    if ($script:GwProc -and -not $script:GwProc.HasExited) { $script:AfterCalib = ''; Append-Log $refusTxt; return }
    $drive = [string]$chk.Drive; $img = [string]$chk.Img; $fam = [string]$chk.Fam; $plan = $chk.Plan
    $lv = [double[]]@($chk.Levels)
    $cyls = [int[]]@($plan.Cyls | Sort-Object -Unique)
    $min = Get-ContentMeasureMinutes ([int]$plan.NCylHead[0] + [int]$plan.NCylHead[1])
    $lvTxt = Format-ContentLevels $lv
    # 12.9 (D3) : duree d une 4e passe adaptative, annoncee en plus
    $min4 = Get-ContentMeasureMinutes ([int]$plan.NCylHead[0] + [int]$plan.NCylHead[1]) 1 -NoWarmup
    if ([bool]$script:CalibUnattended) {
        # 12.9 (S1, decision du 30/10/2026) : ecriture sans surveillance : fenetre non affichee, mesure avec la derniere marque
        $go = $true
        Append-Log ((T "Mesure de la disquette : fenêtre non affichée (écriture sans surveillance) : mesure sur l'image, marque « {0} ».") -f (Format-ContentBrand ([string]$script:LevelBrand)))
    } else {
        # 12.9 (N13) : marque de la disquette inseree (liste pre-remplie avec la derniere marque, Get-ContentBrandItems)
        $bi = Get-ContentBrandItems $drive $fam
        $cq = @{ Title = (T 'Mesure de la disquette'); Heading = (T "Mesure de la disquette sur l'image"); Level = 'info'; Picto = 'data'
                 Text = ((T "Avant l'écriture lente, la précompensation est mesurée sur le contenu même de l'image, sur le lecteur {0} : {1} cylindres répartis sur le disque sont écrits 3 fois, à 3 niveaux de la courbe du lecteur ({2}), et relus après chaque passe. L'image est ensuite écrite avec, pour chaque tête, le niveau qui donne la meilleure marge de lecture.`n`nDurée : environ {3} min avant l'écriture de l'image (+ environ {4} min si l'optimum dépasse le plan). Ces pistes reçoivent 3 écritures de plus (4 si l'optimum dépasse le plan).`n`n« Écrire sans mesure » : facteur mémorisé pour ce lecteur et la marque choisie ci-dessous ; sans mesure de cette marque, courbe du lecteur telle quelle (× 1).") -f "$drive", "$($cyls.Count)", "$lvTxt", "$min", "$min4")
                 GoText = (T 'Mesurer puis écrire'); GoGlyph = 'Diagnostic'; AltText = (T 'Écrire sans mesure')
                 Combo = @{ Label = (T 'Marque de la disquette insérée :'); Items = $bi.Items; Text = [string]$script:LevelBrand
                            Tip = (T "Nom libre : marque, année ou lot. Le facteur mesuré est mémorisé pour ce lecteur et cette marque ; « Écrire sans mesure » applique celui de la marque choisie (courbe du lecteur telle quelle si la marque n'a pas de mesure).") } }
        # 12.8.2 (revue) : effacement haute frequence de chaque passe (New-ContentPass), compris dans la duree
        if ((Get-ContentEraseEst) -gt 0) { $cq.Text += "`n`n" + (T "Case « Effacer avant d'écrire » cochée : ces pistes sont effacées en haute fréquence avant chaque passe, durée comprise.") }
        $script:ConfirmChoice = $null
        $go = [bool](Show-AppConfirm @cq)
        if ($go -or [string]$script:ConfirmChoice -eq 'alt') { $script:LevelBrand = Get-LevelBrandName ([string]$script:ConfirmComboText) $bi.Map }
    }
    if (-not $go) {
        $script:AfterCalib = ''
        if ([string]$script:ConfirmChoice -eq 'alt') {
            # Ecriture sans mesure : facteur memorise du lecteur pour la marque choisie (Start-ImageWrite, Get-DriveK)
            $script:WriteFactorNext = @{ Drive = $drive; Fam = $fam; Img = $img; Brand = [string]$script:LevelBrand; K = $null }
            Append-Log (T "Mesure sur l'image non faite à votre demande : écriture avec le facteur du lecteur.")
            Start-ImageWrite
            return
        }
        Append-Log (T 'Écriture annulée : mesure de la disquette non lancée.')
        return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { $script:AfterCalib = ''; Append-Log $refusTxt; return }
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $cylList = Format-CylRanges $cyls
    # 12.9 (D6) : relectures gardees, une par passe, dans TempDir\mesures-image, plus un fichier compagnon JSON ; mesures
    # au-dela de contentKeepMeasures supprimees au lancement (celle-ci comprise) ; 0 : relecture unique (12.8.2)
    $keep = [math]::Max(0, [math]::Min(20, [int]$script:ContentKeepMeasures))
    $mDir = Join-Path $script:TempDir ([string]$script:ContentScpDir)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    try {
        if (Test-Path -LiteralPath $mDir) {
            $old = @(Get-ChildItem -LiteralPath $mDir -File -ErrorAction Stop | ForEach-Object { $_.FullName })
            foreach ($f in @(Get-ContentKeepPlan $old ([math]::Max(0, $keep - 1)))) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
        }
        if ($keep -gt 0 -and -not (Test-Path -LiteralPath $mDir)) { [void](New-Item -ItemType Directory -Path $mDir -Force -ErrorAction Stop) }
    } catch { $keep = 0 }
    $scp = if ($keep -gt 0) { Get-ContentScpPath $mDir $stamp $drive 1 } else { Join-Path $script:TempDir $script:ContentScpName }
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    # Etat propre de la mesure : plan, passe en cours (0..2), file des commandes de la passe et commande en cours, reprises
    # par passe et tete ('p|h'), cylindres non ecrits ('p|c|h' -> 'nonecrite'), exclusions d avant l ecriture ('c.h'),
    # lectures de toutes les passes (List : jamais @() autour, pwsh 7.6), courbes V, references et bornes. 12.8.2 : mode
    # de l effacement avant les ecritures (EraseMode, 150 : 'hfreq' en double densite, seule densite mesuree ici)
    $ct = @{ Plan = $plan; Pass = 0; Todo = [System.Collections.Generic.List[hashtable]]::new(); Current = $null; Resumes = @{}; Skip = @{}
             PreSkip = $chk.PreSkip; Obs = [System.Collections.Generic.List[object]]::new(); Ncell0 = [int]$chk.Ncell0; Levels = $lv
             KMin = [double](@($lv) | Measure-Object -Minimum).Minimum; V = $chk.V; RefKeys = $chk.RefKeys; RefDates = $chk.RefDates
             Common = [bool]$chk.Common; Fam = $fam; Img = $img; Hard = [int]$chk.Hard
             EraseMode = (Get-EraseMode (Test-ImageHighDensity $img ([string]$cmbWFmt.Text)))
             # 12.9 : marque de la mesure, relectures gardees (Keep mesures, dossier, horodatage), 4e passe faite, resultat
             Brand = [string]$script:LevelBrand; Keep = $keep; Dir = $mDir; Stamp = $stamp; Fourth = $false; Res = $null }
    $script:Cal = @{
        Mode = 'content'; Stage = 'content'; Drive = $drive; Family = $fam; Slow = $true; Image = $img; Cyls = $cyls; CylList = $cylList
        TSpec = "c=${cylList}:h=0-1"; Scp = $scp; Writes = (New-Object System.Collections.Queue)
        ReadArgs = @(@('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=c=${cylList}:h=0-1", "`"$scp`""))
        # Progression : passes faites / prevues, durees mesurees par phase ; estimation initiale par piste et par phase :
        # moyenne de l ecriture et de la relecture (Update-CalibProgress compte Cyls x 2 pistes par phase)
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'; Value = 0; ValueTxt = (T 'tête 0 puis tête 1'); Spec = ''
        PassesDone = 0; TotalPasses = $lv.Count; WriteDurs = @(); ReadDurs = @(); EstTrack = (([double]$script:ContentEstWrite + [double]$script:ContentEstRead) / 2); EstErase = (Get-ContentEraseEst)
        Home = $false; Geom = $null; NoWarmup = (-not [bool](Get-Setting 'warmFullCalib')); Hold = $false; Redo = $false; DiskOnly = $false
        Units = @(); Swap = $false; LevelAfter = $false; VerifyCount = 0; Retests = 0; Content = $ct
    }
    $script:AfterCalib = 'write'
    Append-Log ((T "=== Mesure de la disquette sur l'image : lecteur {0}, marque « {1} », image {2} ({3}) ; {4} cylindres ({5}), niveaux {6} × courbe du lecteur ; calibration du lecteur inchangée ===") -f "$drive", (Format-ContentBrand $ct.Brand), "$([System.IO.Path]::GetFileName($img))", (Get-CalibFamilyName $fam), "$($cyls.Count)", "$cylList", "$lvTxt")
    # Revue des correctifs du 30/10/2026 (m2) : une seule mesure gardee (contentKeepMeasures 1) : texte au singulier
    if ($keep -gt 1) { Append-Log ((T "Mesure sur l'image : relectures gardées dans {0} ({1} ; {2} dernières mesures conservées).") -f "$mDir", "contenu-$stamp-$(([string]$drive) -replace '[^A-Za-z0-9]', '')-p*.scp, .json", "$keep") }
    elseif ($keep -eq 1) { Append-Log ((T "Mesure sur l'image : relectures gardées dans {0} ({1} ; seule cette mesure est conservée).") -f "$mDir", "contenu-$stamp-$(([string]$drive) -replace '[^A-Za-z0-9]', '')-p*.scp, .json") }
    $dates = if ($ct.Common) { [string]$ct.RefDates[0] } else { "$($ct.RefDates[0]) / $($ct.RefDates[1])" }
    $kind = if ($ct.Common) { (T 'courbe commune') } else { (T 'une courbe par tête') }
    Append-Log ((T "Mesure sur l'image : courbe du lecteur du {0} ({1}) ; précompensation écrite bornée à 0..{2} ns.") -f "$dates", "$kind", "$($ct.Hard)")
    if ($chkWPreErase.Checked -and [string]$ct.EraseMode -eq 'hfreq') { Append-Log (T "Mesure sur l'image : disquette double densité, chaque passe commence par un effacement haute fréquence de ses pistes (gw erase --hfreq) ; écritures sans pré-effacement.") }
    $pbWCal.Value = 0; $pbWCal.Visible = $true; $lblWCal.Visible = $true
    Update-CalibProgress
    Start-CalibWarmup      # prechauffage du lecteur s il y a lieu, puis premiere passe (New-CalibPass, stade 'content')
}

function New-ContentPass {
    # Passe suivante de la mesure (New-CalibPass au stade 'content', apres le prechauffage ou la passe precedente) : file des
    # commandes, tete 0 puis tete 1 comme l ecriture lente (cylindres de la passe dans le plan, sans les pistes exclues
    # avant l ecriture), journal (passe, niveau de chaque bloc), phase d ecriture, premiere commande
    $cal = $script:Cal
    if (-not $cal -or -not $cal.Content) { return }
    $ct = $cal.Content; $p = [int]$ct.Pass
    $ct.Todo.Clear(); $ct.Current = $null
    # 12.9 (D6) : relecture de la passe dans son propre fichier (contentKeepMeasures > 0), commande de relecture refaite
    if ([int]$ct.Keep -gt 0) {
        $cal.Scp = Get-ContentScpPath ([string]$ct.Dir) ([string]$ct.Stamp) ([string]$cal.Drive) ($p + 1)
        $cal.ReadArgs = @(@('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=c=$($cal.CylList):h=0-1", "`"$($cal.Scp)`""))
    }
    foreach ($h in 0, 1) {
        $cs = [int[]]@($ct.Plan.Pass[$p].H[$h].Cyls)
        if ($cs.Count -gt 0) { $ct.Todo.Add(@{ H = $h; Cyls = $cs; Resume = $false }) }
    }
    # 12.8.2 : double densite, case « Effacer avant d ecrire » cochee : effacement haute frequence des pistes de la passe
    # (cylindres de chaque tete dans le plan, sans les pistes exclues avant l ecriture), en tete de file (@{ Erase }) ;
    # champ Pistes vide (Test-ContentMeasurable) : aucun element de lecteur
    if ($chkWPreErase.Checked -and [string]$ct.EraseMode -eq 'hfreq') {
        $ks = @(foreach ($t in $ct.Todo) { foreach ($c in @($t.Cyls)) { "$c.$($t.H)" } })
        $ers = New-HfreqEraseCmds $ks ''
        for ($i = $ers.Count - 1; $i -ge 0; $i--) { $ct.Todo.Insert(0, @{ Erase = [string[]]$ers[$i] }) }
    }
    $bc = @($ct.Plan.Cyls); $nb = @($ct.Plan.Blocks).Count
    $len = if ($nb -gt 0) { [int]($bc.Count / $nb) } else { 0 }
    # 12.9 (D3) : 4e passe, niveau de chaque bloc dans la passe (BlockK, Get-ContentFourthPass)
    $pk = @($ct.Plan.Pass[$p].BlockK | Where-Object { $null -ne $_ })
    $bk = @(for ($bi = 0; $bi -lt $nb; $bi++) { $c0 = [int]$bc[$bi * $len]; $lk = if ($pk.Count -gt $bi) { [double]$pk[$bi] } else { Get-ContentLevel $bi $p ([double[]]$ct.Levels) }; "c$c0-$($c0 + $len - 1) × $(Format-UiNum $lk '0.##')" })
    $cal.ValueTxt = (T 'tête 0 puis tête 1')
    Append-Log ((T "Mesure sur l'image : passe {0}/{1}, {2}") -f "$($p + 1)", "$($cal.TotalPasses)", "$($cal.ValueTxt), $($bk -join ' ; ')")
    $cal.Phase = 'write'; $cal.PassStart = Get-Date; $cal.PhaseStart = $cal.PassStart
    Update-CalibProgress
    $script:Chain.Clear()
    Invoke-ContentWriteNext
}

function Invoke-ContentWriteNext {
    # Etape de la chaine apres chaque commande gw write de la mesure (et au debut de la passe) : (1) bilan de la commande
    # finie : arret « Failed to verify Track » de gw ($script:GwVerifyFail, pose par Read-GwOutput, la commande ayant ete
    # traitee comme une lecture de prechauffage par le minuteur, 600) lu et remis a $null, Register-ContentWriteStop ;
    # (2) commande suivante de la file ; (3) file vide : relecture de 3 tours des cylindres du plan, deux tetes (SCP
    # supprime avant, il garde la derniere passe), puis Invoke-ContentAnalysis
    $cal = $script:Cal
    if (-not $cal -or [string]$cal.Mode -ne 'content') { return }
    $ct = $cal.Content
    if ($null -ne $ct.Current) {
        # $vStop, jamais $stop : meme nom que $stOp (barre d etat) pour PowerShell, qui ignore la casse ; Start-Progress,
        # appele par Start-Gw plus bas, lirait cette variable locale (portee dynamique) au lieu du libelle
        $vStop = $script:GwVerifyFail; $script:GwVerifyFail = $null
        if ($vStop) { Register-ContentWriteStop $cal $ct.Current $vStop }
        $ct.Current = $null
    }
    if ($ct.Todo.Count -gt 0) {
        $w = $ct.Todo[0]; $ct.Todo.RemoveAt(0)
        $script:Chain.Enqueue({ Invoke-ContentWriteNext })
        # 12.8.2 : effacement haute frequence de la passe (New-ContentPass) : aucun arret de verification a relever ensuite
        if ($w.Erase) { $ct.Current = $null; Start-Gw ([string[]]$w.Erase); return }
        $ct.Current = $w
        Start-Gw (Get-ContentWriteArgs $cal $w)
        return
    }
    $cal.WriteDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.Phase = 'read'; $cal.PhaseStart = Get-Date
    # 12.9 (D6) : relecture unique supprimee avant la relecture seulement sans relectures gardees (contentKeepMeasures 0)
    if ([int]$ct.Keep -le 0 -and (Test-Path -LiteralPath $cal.Scp)) { Remove-Item -LiteralPath $cal.Scp -Force }
    $script:Chain.Enqueue({ Invoke-ContentAnalysis })
    Start-Gw ([string[]]$cal.ReadArgs)
}

function Register-ContentWriteStop($cal, $w, $vStop) {
    # Arret de gw sur une piste refusee a la verification apres les nouveaux essais (A.7), $w : commande finie, $vStop :
    # @{ C ; H } (Get-GwVerifyStop). La piste en echec reste dans la mesure, a son niveau (sa marge basse est
    # l information cherchee ; l exclure favoriserait les niveaux qui reussissent). Cylindres suivants de la commande, non
    # ecrits : premier arret de la tete a cette passe (ContentResumeMax reprises), commande de reprise en tete de file,
    # memes valeurs, cylindres restants ; arret suivant : cylindres restants ecartes de cette passe (Skip 'nonecrite').
    # Arret annonce hors de la commande (autre tete ou cylindre absent, incoherence) : tous ses cylindres ecartes de cette
    # passe
    $ct = $cal.Content; $p = [int]$ct.Pass; $h = [int]$w.H
    $cs = [int[]]@($w.Cyls | Sort-Object)
    $sc = [int]$vStop.C; $sh = [int]$vStop.H
    if ($sh -ne $h -or $cs -notcontains $sc) {
        foreach ($c in $cs) { $ct.Skip["$p|$c|$h"] = 'nonecrite' }
        Append-Log ((T "Mesure sur l'image : arrêt de gw annoncé sur la piste {0}.{1}, hors de la commande de la tête {2} : cylindres {3} non écrits à cette passe, écartés de la mesure.") -f "$sc", "$sh", "$h", (Format-CylRanges $cs))
        return
    }
    $rest = [int[]]@($cs | Where-Object { $_ -gt $sc })
    if ($rest.Count -eq 0) {
        Append-Log ((T "Mesure sur l'image : gw s'est arrêté sur la piste {0}.{1} (vérification refusée après les nouveaux essais), dernière de la commande ; elle reste dans la mesure, à son niveau.") -f "$sc", "$h")
        return
    }
    $key = "$p|$h"
    $n = [int]$ct.Resumes[$key]
    if ($n -lt [int]$script:ContentResumeMax) {
        $ct.Resumes[$key] = $n + 1
        $ct.Todo.Insert(0, @{ H = $h; Cyls = $rest; Resume = $true })
        Append-Log ((T "Mesure sur l'image : gw s'est arrêté sur la piste {0}.{1} (vérification refusée après les nouveaux essais) ; elle reste dans la mesure, à son niveau. Reprise de la tête {1} aux cylindres {2}.") -f "$sc", "$h", (Format-CylRanges $rest))
        return
    }
    foreach ($c in $rest) { $ct.Skip["$p|$c|$h"] = 'nonecrite' }
    Append-Log ((T "Mesure sur l'image : nouvel arrêt de gw sur la tête {0} à cette passe (piste {1}.{0}) : cylindres {2} non écrits à cette passe, écartés de la mesure.") -f "$h", "$sc", (Format-CylRanges $rest))
}

function Get-ContentPassStats([string]$scp, $ct, [int]$pass) {
    # Bilan de la relecture d une passe (point de substitution des fins de test) : tours bruts du SCP (Read-ScpTrackRevs,
    # ScpStats.Decode), puis, pour chaque piste ecrite a la passe (cylindres de chaque tete dans le plan, sans les
    # cylindres non ecrits apres un arret de gw), marge fixe et comptes (Get-ContentTrackStats). Ecrit dans le pipeline une
    # lecture @{ C ; H ; P ; K ; W ; NRev ; Mfix ; N ; Z ; ZFrac ; Cells ; Flux } par piste ; piste absente du SCP : NRev = 0.
    # Fichier sans en-tete SCP : exception (relecture illisible, T-B25 dans Invoke-ContentAnalysis)
    $revs = Read-ScpTrackRevs $scp
    if ($null -eq $revs) { throw (T 'fichier sans en-tête SCP') }
    $ph = $ct.Plan.Pass[$pass]
    foreach ($h in 0, 1) {
        foreach ($c in @($ph.H[$h].Cyls)) {
            if ($ct.Skip.ContainsKey("$pass|$c|$h")) { continue }
            $tn = [int]$c * 2 + $h
            $tr = if ($revs.Tracks.ContainsKey($tn)) { $revs.Tracks[$tn] } else { $null }
            $st = Get-ContentTrackStats $tr ([int]$revs.Res) ([int]$ct.Ncell0)
            @{ C = [int]$c; H = $h; P = $pass; K = [double]$ph.H[$h].K[[int]$c]; W = [int]$ph.H[$h].W[[int]$c]; NRev = [int]$st.NRev; Mfix = [double]$st.Mfix
               N = [int64]$st.N; Z = [int64]$st.Z; ZFrac = [double]$st.ZFrac; Cells = $st.Cells; Flux = $st.Flux }
        }
    }
}

function Invoke-ContentAnalysis {
    # Fin de la relecture d une passe : SCP absent, sans en-tete SCP ou exception de lecture : T-B25 et arret
    # (Stop-PrecompCalib -GwError : Restore-CalibRetestPre rend $false hors du stade 'verify', mesure arretee, ecriture
    # annulee, rien n est enregistre, comme la mesure complete) ; sinon lectures ajoutees a la mesure, journal par tete,
    # passe suivante ou fin
    $cal = $script:Cal
    if (-not $cal -or [string]$cal.Mode -ne 'content') { return }
    $ct = $cal.Content
    $cal.ReadDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $fail = (T "Mesure sur l'image : relecture absente ou illisible ({0}) : mesure arrêtée.")
    if (-not (Test-Path -LiteralPath $cal.Scp)) { Append-Log ($fail -f (T 'fichier absent')); Stop-PrecompCalib -GwError; return }
    try { $stats = @(Get-ContentPassStats ([string]$cal.Scp) $ct ([int]$ct.Pass)) }
    catch { Append-Log ($fail -f "$($_.Exception.Message)"); Stop-PrecompCalib -GwError; return }
    foreach ($s in $stats) { if ($null -ne $s) { $ct.Obs.Add($s) } }
    Write-ContentPassLog $cal $stats
    $cal.PassesDone++
    $ct.Pass = [int]$ct.Pass + 1
    # 12.9 (D6) : fichier compagnon a jour apres chaque passe (statut « en cours » si la mesure s arrete ensuite)
    Save-ContentCompanion $cal 'en cours'
    if ([int]$ct.Pass -lt [int]$cal.TotalPasses) { New-ContentPass; return }
    # 12.9 (D3, critique § 3.3.4) : apres les 3 passes du plan, 4e passe aux niveaux 1,6 et 1 (alternes par bloc) si une
    # tete a un optimum k >= 0,9 ou pas de sommet (Test-ContentNeedFourth) ; une seule fois
    if ([int]$cal.TotalPasses -eq 3 -and -not $ct.Fourth) {
        # Revue de la phase B (mineur 5) : ajustements gardes pour Complete-ContentMeasure tant qu aucune passe ne s ajoute
        $hf = Get-ContentHeadFits $ct
        $ct.HF = $hf; $ct.HFPass = [int]$ct.Pass
        $nf = Test-ContentNeedFourth $hf.Fit
        if ($nf.Need) {
            $fp = Get-ContentFourthPass $ct.Plan ([int[]]@($ct.V[0])) ([int[]]@($ct.V[1])) ([int]$ct.Hard) $ct.PreSkip
            $ct.Plan.Pass = @(@($ct.Plan.Pass) + @($fp))
            $ct.Fourth = $true; $cal.TotalPasses = 4
            $m4 = Get-ContentMeasureMinutes ([int]$fp.NCylHead[0] + [int]$fp.NCylHead[1]) 1 -NoWarmup
            # Banc 12.9 (30/10/2026, defaut 3) : les deux tetes concernees : une seule ligne qui les nomme, groupees par
            # raison (deux lignes laissaient lire deux passes et le double de la duree) ; une tete : ligne inchangee
            $hs = [int[]]@($nf.Heads)
            if ($hs.Count -ge 2) {
                $hp = [int[]]@($hs | Where-Object { -not [double]::IsNaN([double]$nf.K[$_]) }); $hn = [int[]]@($hs | Where-Object { [double]::IsNaN([double]$nf.K[$_]) })
                if ($hp.Count -eq 0) { Append-Log ((T "Mesure sur l'image : marge sans sommet dans les niveaux mesurés (têtes {0} et {1}) : 4e passe aux niveaux 1,6 et 1 (environ {2} min de plus).") -f "$($hn[0])", "$($hn[1])", "$m4") }
                elseif ($hn.Count -eq 0) { Append-Log ((T "Mesure sur l'image : optimum au-dessus des niveaux mesurés (tête {0} : k ≈ {1} ; tête {2} : k ≈ {3}) : 4e passe aux niveaux 1,6 et 1 (environ {4} min de plus).") -f "$($hp[0])", (Format-UiNum ([double]$nf.K[$hp[0]]) '0.00'), "$($hp[1])", (Format-UiNum ([double]$nf.K[$hp[1]]) '0.00'), "$m4") }
                else { Append-Log ((T "Mesure sur l'image : optimum au-dessus des niveaux mesurés (tête {0} : k ≈ {1}) et marge sans sommet (tête {2}) : 4e passe aux niveaux 1,6 et 1 (environ {3} min de plus).") -f "$($hp[0])", (Format-UiNum ([double]$nf.K[$hp[0]]) '0.00'), "$($hn[0])", "$m4") }
            }
            else {
                foreach ($h in $hs) {
                    $kh = [double]$nf.K[$h]
                    if ([double]::IsNaN($kh)) { Append-Log ((T "Mesure sur l'image : marge sans sommet dans les niveaux mesurés (tête {0}) : 4e passe aux niveaux 1,6 et 1 (environ {1} min de plus).") -f "$h", "$m4") }
                    else { Append-Log ((T "Mesure sur l'image : optimum au-dessus des niveaux mesurés (tête {0} : k ≈ {1}) : 4e passe aux niveaux 1,6 et 1 (environ {2} min de plus).") -f "$h", (Format-UiNum $kh '0.00'), "$m4") }
                }
            }
            New-ContentPass
            return
        }
    }
    Complete-ContentMeasure $cal
}

function Get-ContentHeadFits($ct) {
    # 12.9 : exclusions apres la relecture (Get-ContentExclusions, a tous les niveaux) et lignes retenues par tete @{ P ; C ;
    # K ; W (precomp ecrite) ; V (courbe du lecteur au cylindre, bornee a 0..Hard comme le plan) ; Y = Mfix }, sans les
    # pistes exclues ni les lectures sans tour ; puis, par tete aux donnees suffisantes (Get-ContentHeadCheck), poids de
    # Huber et ajustement « K-ns » (Get-ContentFactorNs, etat compris). Rend @{ Ex ; Rows ; HC ; W ; Fit } (tables par tete,
    # Fit $null sans donnees suffisantes)
    $ex = Get-ContentExclusions $ct.Obs ([double]$script:ContentZMax) ([double]$script:ContentCellsTol) ([double]$script:ContentFluxMin)
    $rows = @{ 0 = @(); 1 = @() }
    foreach ($o in $ct.Obs) {
        if ($null -eq $o) { continue }
        $h = [int]$o.H; $c = [int]$o.C
        if ($ex.ContainsKey("$c.$h") -or [int]$o.NRev -le 0 -or [double]::IsNaN([double]$o.Mfix)) { continue }
        $vv = @($ct.V[$h]); $vc = 0.0
        if ($vv.Count -gt 0) { $vc = if ($c -lt $vv.Count) { [double]$vv[$c] } else { [double]$vv[$vv.Count - 1] } }
        $vc = [math]::Max(0.0, [math]::Min([double]$ct.Hard, $vc))
        $rows[$h] += ,@{ P = [string]$o.P; C = $c; K = [double]$o.K; W = [int]$o.W; V = $vc; Y = [double]$o.Mfix }
    }
    $hc = @{}; $wts = @{}; $fit = @{ 0 = $null; 1 = $null }
    foreach ($h in 0, 1) {
        $hc[$h] = Get-ContentHeadCheck $rows[$h] ([int]$script:ContentMinCyl) ([int]$script:ContentMinLevelCyl)
        if ($hc[$h].Ok) { $wts[$h] = Get-ContentHuberWeights $rows[$h]; $fit[$h] = Get-ContentFactorNs $rows[$h] $wts[$h] }
    }
    return @{ Ex = $ex; Rows = $rows; HC = $hc; W = $wts; Fit = $fit }
}

function Get-ContentCompanion($cal, [string]$status) {
    # 12.9 (D6) : contenu du fichier compagnon JSON d une mesure sur l image : versions, lecteur, marque, image, famille,
    # niveaux, plan (k et precomp ecrite par passe, tete et cylindre), lectures (Mfix, N, Z, tours par piste et par passe),
    # exclusions (avant l ecriture, cylindres non ecrits), resultat par tete (Content.Res, Complete-ContentMeasure) et
    # statut ('en cours', 'terminee', 'arretee'). Nombres non finis ecrits null ; aucune cle numerique (ConvertTo-Json de
    # Windows PowerShell 5.1). Revue de la phase B (mineur 6) : low, liste vide (et non [""]) pour une tete non mesuree
    $ct = $cal.Content
    $plan = @(for ($p = 0; $p -lt @($ct.Plan.Pass).Count; $p++) {
        foreach ($h in 0, 1) {
            $ph = $ct.Plan.Pass[$p].H[$h]; $cs = [int[]]@($ph.Cyls)
            [ordered]@{ p = $p + 1; h = $h; c = $cs; k = [double[]]@($cs | ForEach-Object { [double]$ph.K[$_] }); w = [int[]]@($cs | ForEach-Object { [int]$ph.W[$_] }) }
        }
    })
    $reads = @(foreach ($o in $ct.Obs) {
        if ($null -eq $o) { continue }
        [ordered]@{ p = [int]$o.P + 1; c = [int]$o.C; h = [int]$o.H; k = [double]$o.K; w = [int]$o.W; nRev = [int]$o.NRev
                    mfix = (ConvertTo-FiniteOrNull $o.Mfix); n = [int64]$o.N; z = [int64]$o.Z }
    })
    $res = @(foreach ($r in @($ct.Res)) {
        if ($null -eq $r) { continue }
        [ordered]@{ h = [int]$r.H; etat = [string]$r.Etat; k = (ConvertTo-FiniteOrNull $r.K); seK = (ConvertTo-FiniteOrNull $r.SeK); q = (ConvertTo-FiniteOrNull $r.Q)
                    tQ = (ConvertTo-FiniteOrNull $r.TQ); chi2Ddl = (ConvertTo-FiniteOrNull $r.Chi2Ddl); s = (ConvertTo-FiniteOrNull $r.S); nCyl = [int]$r.NCyl; nObs = [int]$r.N
                    kApplied = (ConvertTo-FiniteOrNull $r.KApplied); src = [string]$r.Src; low = [string[]]@(@($r.LowTxt) | Where-Object { $_ })
                    zones = @(@($r.Zones) | Where-Object { $null -ne $_ } | ForEach-Object { [ordered]@{ z = [int]$_.Z; v = (ConvertTo-FiniteOrNull $_.V); x = (ConvertTo-FiniteOrNull $_.X); seX = (ConvertTo-FiniteOrNull $_.SeX) } }) }
    })
    $ne = @(@($ct.Skip.Keys) | Sort-Object | ForEach-Object { [string]$_ })
    $pre = @(@($ct.PreSkip.Keys) | Sort-Object | ForEach-Object { "$_=$($ct.PreSkip[$_])" })
    return [ordered]@{ status = $status; version = [string]$script:Version; contentCalc = [string]$script:ContentCalc; calibCalc = [string]$script:CalibCalc
                       drive = [string]$cal.Drive; brand = [string]$ct.Brand; image = [System.IO.Path]::GetFileName([string]$cal.Image); family = [string]$ct.Fam
                       stamp = [string]$ct.Stamp; levels = [double[]]@($ct.Levels); fourth = [bool]$ct.Fourth; hard = [int]$ct.Hard
                       curves = [ordered]@{ h0 = [int[]]@($ct.V[0]); h1 = [int[]]@($ct.V[1]) }
                       plan = $plan; reads = $reads; preSkip = $pre; notWritten = $ne; result = $res }
}

function Save-ContentCompanion($cal, [string]$status) {
    # 12.9 (D6) : ecrit le fichier compagnon JSON (Get-ContentCompanion) a cote des relectures gardees, UTF-8 sans BOM ;
    # rien sans relectures gardees (contentKeepMeasures 0) ; echec d ecriture ignore (la mesure continue). Appele apres
    # chaque passe ('en cours'), en fin de mesure ('terminee') et a l arret (Stop-PrecompCalib, 'arretee')
    if (-not $cal -or -not $cal.Content -or [int]$cal.Content.Keep -le 0) { return }
    $ct = $cal.Content
    try {
        $path = Get-ContentScpPath ([string]$ct.Dir) ([string]$ct.Stamp) ([string]$cal.Drive) 0
        $js = ConvertTo-Json -InputObject (Get-ContentCompanion $cal $status) -Depth 6
        [System.IO.File]::WriteAllText($path, $js, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function Write-ContentPassLog($cal, $stats) {
    # Lectures d une passe au journal, une ligne par tete, format stable lu par script (T-B10) : elements
    # « c<cylindre> <niveau k> <precomp ecrite> -> <marge fixe> », en ns, k a deux decimales et Mfix a une, au format de la
    # langue (Format-UiNum) ; piste sans tour exploitable : « -> - » ; cylindres croissants, separes par « ; »
    $p = [int]$cal.Content.Pass
    foreach ($h in 0, 1) {
        $items = @(@($stats) | Where-Object { $null -ne $_ -and [int]$_.H -eq $h } | Sort-Object { [int]$_.C } | ForEach-Object {
            $m = if ([int]$_.NRev -le 0 -or [double]::IsNaN([double]$_.Mfix)) { '-' } else { Format-UiNum ([double]$_.Mfix) '0.0' }
            "c$($_.C) $(Format-UiNum ([double]$_.K) '0.00') $($_.W) -> $m"
        })
        if ($items.Count -eq 0) { continue }
        Append-Log ((T "[tête {0}] Mesure sur l'image, passe {1}/{2} (cylindre, niveau, précomp écrite -> marge fixe, ns) : {3}") -f "$h", "$($p + 1)", "$($cal.TotalPasses)", ($items -join ' ; '))
    }
}

function Complete-ContentMeasure($cal) {
    # Fin de la mesure (A.10). Exclusions apres la relecture (Get-ContentExclusions, aux 3 niveaux), puis lignes retenues
    # par tete (sans les pistes exclues, avant ou apres l ecriture, ni les cylindres non ecrits, ni les lectures sans tour)
    # ; donnees minimales (Get-ContentHeadCheck), puis facteur k* (Get-ContentFactorNs, 12.9) ; tete non
    # mesuree : k du lecteur (Get-DriveK). Journal : pistes ecartees par raison (T-B14), facteur et reserves de chaque tete
    # (T-B15 a T-B19). Pas de fenetre de decision : le resultat est applique. Enregistrements de mesure des tetes mesurees
    # (C.2 : k du lecteur des ecritures suivantes, Add-ContentMeasure, Save-Config), puis facteur de l ecriture qui suit
    # ($script:WriteFactorNext, lu une fois par Start-ImageWrite) et ecriture de l image ; prechauffage de l ecriture lente
    # reduit ou saute, le lecteur venant de servir (comme Complete-DiskMeasure)
    # 12.9 (critique § 3.3.5) : lignes avec la precomp ecrite et la courbe, poids de Huber, ajustement « K-ns » et etat de
    # chaque tete (Get-ContentHeadFits) ; journal : resultat, optimums par zone, etat, pistes peu prises en compte ;
    # facteur applique selon l etat (Get-ContentAppliedK : k borne a [0 ; 2], sinon k memorise de la marque, sinon 1) ;
    # enregistrements avec la marque et l etat ; fichier compagnon JSON (D6)
    $ct = $cal.Content; $drive = [string]$cal.Drive; $fam = [string]$cal.Family
    # Revue de la phase B (mineur 5) : ajustements du test de la 4e passe repris s ils portent sur les memes passes
    $hf = if ($ct.HF -and [int]$ct.HFPass -eq [int]$ct.Pass) { $ct.HF } else { Get-ContentHeadFits $ct }
    $ex = $hf.Ex
    # Pistes ecartees, par raison : avant l ecriture (PreSkip), apres la relecture (exclusions), non ecrites a une passe
    $byWhy = [ordered]@{ absente = @(); longue = @(); protegee = @(); vide = @(); longueur = @(); nonmfm = @(); nonecrite = @() }
    foreach ($k in @($ct.PreSkip.Keys)) { $wy = [string]$ct.PreSkip[$k]; if ($byWhy.Contains($wy)) { $byWhy[$wy] += [string]$k } }
    foreach ($k in @($ex.Keys)) { $wy = [string]$ex[$k]; if ($byWhy.Contains($wy)) { $byWhy[$wy] += [string]$k } }
    $ne = @{}
    foreach ($k in @($ct.Skip.Keys)) { $pp = ([string]$k) -split '\|'; $ne["$($pp[1]).$($pp[2])"] = $true }
    $byWhy['nonecrite'] = @($ne.Keys)
    $whyTxt = @{ absente = (T "absentes de l'image : {0}"); longue = (T 'longues : {0}'); protegee = (T 'protégées (IPF) : {0}'); vide = (T 'vides ou effacées : {0}')
                 longueur = (T 'longueur hors norme : {0}'); nonmfm = (T 'non MFM ou illisibles à tous les niveaux : {0}'); nonecrite = (T 'non écrites (arrêt de gw) : {0}') }
    $parts = @(foreach ($wy in @($byWhy.Keys)) { if (@($byWhy[$wy]).Count -gt 0) { $whyTxt[$wy] -f (Format-TrackList (Sort-TrackKeys @($byWhy[$wy]))) } })
    if ($parts.Count -gt 0) { Append-Log ((T "Mesure sur l'image : pistes écartées : {0}.") -f ($parts -join ' ; ')) }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $brand = [string]$ct.Brand
    $kk = @{ 0 = 1.0; 1 = 1.0 }; $src = @{ 0 = 'defaut'; 1 = 'defaut' }; $recs = @(); $res = @(); $sum = @{}
    $kMax = if ([double]$script:ContentKMax -gt 0) { [double]$script:ContentKMax } else { 2.0 }
    foreach ($h in 0, 1) {
        $pre = (T '[tête {0}] ') -f "$h"
        $hc = $hf.HC[$h]; $fit = $hf.Fit[$h]
        # k memorise du lecteur pour la marque (avant l enregistrement de cette mesure), repli des etats plate, peu, echec
        $dr = Get-DriveK $drive $fam $h $brand
        $mem = if ([string]$dr.Src -eq 'lecteur') { [double]$dr.K } else { $null }
        if ($fit -and $fit.Ok) {
            $etat = [string]$fit.Etat
            $ap = Get-ContentAppliedK $etat ([double]$fit.K) $mem $kMax
            $kk[$h] = [double]$ap.K; $src[$h] = [string]$ap.Src
            Append-Log ((T '{0}Facteur mesuré : k = {1} ± {2} (courbure commune en ns {3} /ns, t = {4} ; écart entre zones χ²/ddl {5} ; {6} cylindres, {7} pistes dont {8} pondérées ; écart-type résiduel {9} ns).') -f "$pre", (Format-ContentNum $fit.K '0.00'), (Format-ContentNum $fit.SeK '0.00'), (Format-ContentNum $fit.Q '0.0000'), (Format-ContentNum $fit.TQ '0.0'), (Format-ContentNum $fit.Chi2Ddl '0.0'), "$($fit.NCyl)", "$($fit.N)", "$($fit.NPond)", (Format-ContentNum $fit.S '0.0'))
            if (@($fit.Zones).Count -gt 0) { Append-Log ((T '{0}Optimums par zone (cylindres : k) : {1}.') -f "$pre", ((@($fit.Zones) | ForEach-Object { "c$($_.Cyl) : $(Format-ContentNum $_.K '0.00')" }) -join ' ; ')) }
            $kAp = Format-UiNum ([double]$ap.K) '0.00'
            $apTxt = Get-ContentBrandKText $dr
            switch ($etat) {
                'plate' { Append-Log ((T '{0}Marge plate : la marge de lecture varie trop peu avec le niveau de précompensation pour situer l''optimum (t = {1}, il faut au moins 2). Facteur appliqué : {2}.') -f "$pre", (Format-ContentNum $fit.TQ '0.0'), "$apTxt") }
                'peu' { Append-Log ((T '{0}Facteur peu déterminé : k = {1} ± {2} (incertitude au-delà de 0,25). Facteur appliqué : {3}.') -f "$pre", (Format-ContentNum $fit.K '0.00'), (Format-ContentNum $fit.SeK '0.00'), "$apTxt") }
                'haute' { Append-Log ((T '{0}Optimum au-delà de la borne {1} du facteur : k = {1} retenu.') -f "$pre", (Format-UiNum $kMax '0.##')) }
                'basse' { Append-Log ((T '{0}Optimum au-delà de la borne {1} du facteur : k = {1} retenu.') -f "$pre", (Format-UiNum 0.0 '0.##')) }
            }
            $lowTxt = [string[]]@(@($fit.Low) | ForEach-Object { "c$($_.C) p$([int]$_.P + 1)" })
            if ($lowTxt.Count -gt 0) { Append-Log ((T '{0}Pistes à marge anormale, moins prises en compte : {1}.') -f "$pre", ($lowTxt -join ' ; ')) }
            $sum[$h] = switch ($etat) {
                'plate' { if ([string]$ap.Src -eq 'lecteur') { (T 'marge plate, k {0} de la marque') -f "$kAp" } else { (T 'k 1 par défaut') } }
                'peu' { if ([string]$ap.Src -eq 'lecteur') { (T 'peu déterminé, k {0} de la marque') -f "$kAp" } else { (T 'k 1 par défaut') } }
                default { (T 'k {0} mesuré') -f "$kAp" }
            }
            # Enregistrement de mesure (C.2) avec la marque et l etat : k mesure (borne a [0 ; kMax] sauf marge plate ou peu
            # determinee), courbe ecrite W_h = facteur applique x V_h, bornee a 0..max(borne, v) (Get-ContentScaledValues)
            $f = [double](Limit-WriteFactor ([double]$ap.K) ([double]$script:ContentFMax)).F   # 12.10 : sans la correction Dk
            $vals = Get-ContentScaledValues @($ct.V[$h]) $f ([int]$ct.Hard)
            $nEx = @(@(@($ct.PreSkip.Keys) + @($ex.Keys)) | Where-Object { (([string]$_) -split '\.')[1] -eq "$h" }).Count
            $kr = [double]$fit.K
            if (@('mesure', 'haute', 'basse') -contains $etat) { $kr = [math]::Min([math]::Max($kr, 0.0), $kMax) }
            $recs += ,@{ Model = 'contenu'; Drive = $drive; Family = $fam; Head = $h; Date = $date; Image = [System.IO.Path]::GetFileName([string]$cal.Image)
                         K = $(if ([double]::IsNaN($kr)) { $kr } else { [math]::Round($kr, 3) }); KVertex = $(if ([double]::IsNaN([double]$fit.K)) { $null } else { [math]::Round([double]$fit.K, 3) })
                         Bound = $(switch ($etat) { 'haute' { 'high' } 'basse' { 'low' } default { '' } }); Flat = ($etat -eq 'plate')
                         SeK = [double]$fit.SeK; B1 = [double]::NaN; B2 = [double]::NaN; Gain = [double]::NaN; S = [double]$fit.S
                         NCyl = [int]$fit.NCyl; NObs = [int]$fit.N; NExcl = [int]$nEx; Levels = [double[]]@($ct.Levels); F = $f
                         Values = $vals; Spec = (Build-CurveProfile $vals); RefKey = [string]$ct.RefKeys[$h]; RefDate = [string]$ct.RefDates[$h]
                         Calc = [string]$script:CalibCalc; ContentCalc = [string]$script:ContentCalc; Version = [string]$script:Version
                         Brand = $brand; Etat = $etat; Q = [double]$fit.Q; TQ = [double]$fit.TQ; Chi2Ddl = [double]$fit.Chi2Ddl; NPass = @($ct.Plan.Pass).Count
                         Zones = @(@($fit.Zones) | ForEach-Object { @{ Z = [int]$_.Z; K = [double]$_.K } }) }
            $res += ,@{ H = $h; Etat = $etat; K = [double]$fit.K; SeK = [double]$fit.SeK; Q = [double]$fit.Q; TQ = [double]$fit.TQ; Chi2Ddl = [double]$fit.Chi2Ddl
                        S = [double]$fit.S; NCyl = [int]$fit.NCyl; N = [int]$fit.N; KApplied = [double]$ap.K; Src = [string]$ap.Src; LowTxt = $lowTxt; Zones = @($fit.Zones) }
        } else {
            # Tete non mesuree (donnees insuffisantes ou ajustement impossible) : k memorise du lecteur pour la marque, 1 sans
            # mesure de la marque (jamais celui d une autre marque)
            $kk[$h] = [double]$dr.K; $src[$h] = [string]$dr.Src
            $why = if (-not $hc.Ok -and [string]$hc.Why -eq 'peu') { (T 'trop peu de pistes exploitables ({0} cylindres)') -f "$($hc.NCyl)" } else { (T 'ajustement impossible') }
            Append-Log ((T '{0}Facteur non mesuré ({1}) : facteur du lecteur appliqué ({2}).') -f "$pre", "$why", (Get-ContentBrandKText $dr))
            $sum[$h] = if ([string]$dr.Src -eq 'lecteur') { (T 'non mesuré, k {0} de la marque') -f (Format-UiNum ([double]$dr.K) '0.00') } else { (T 'k 1 par défaut') }
            $res += ,@{ H = $h; Etat = 'echec'; K = [double]::NaN; KApplied = [double]$dr.K; Src = [string]$dr.Src }
        }
    }
    $ct.Res = $res
    foreach ($rc in $recs) { Add-ContentMeasure $rc }
    if ($recs.Count -gt 0 -and -not $script:Restore) { [void](Save-Config) }
    # Complement « facteur applique » du libelle du profil refait avec le nouveau k du lecteur (revue 12.8.1, point 6)
    if ($recs.Count -gt 0) { Update-WriteFactorNote }
    Save-ContentCompanion $cal 'terminee'
    $el = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $durTxt = Format-CalDuration $el
    $pbWCal.Visible = $false
    $lblWCal.Text = ((T "Mesure sur l'image terminée en {0} : tête 0 {1}, tête 1 {2}.") -f "$durTxt", "$($sum[0])", "$($sum[1])")
    $script:Cal = $null
    if ($script:AfterCalib -ne 'write') { $script:WriteFactorNext = $null; return }
    $script:AfterCalib = ''
    $script:WriteFactorNext = @{ Drive = $drive; Fam = $fam; Img = [string]$cal.Image; K = @{ 0 = [double]$kk[0]; 1 = [double]$kk[1] }
                                 Src = @{ 0 = [string]$src[0]; 1 = [string]$src[1] }; Date = $date; Brand = $brand }
    Append-Log ((T "Mesure de la disquette sur l'image terminée en {0} : écriture de l'image avec le facteur mesuré.") -f "$durTxt")
    Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip)
}
