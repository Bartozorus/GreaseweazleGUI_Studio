# ============================== FONCTIONS : MESURE SUR L IMAGE, DEROULE ==========

# 12.8.1 (lot B, spec-1281.md § A et B.3) : mesure de la disquette sur l image avant une ecriture lente (liste « Mesure :
# sur l image a ecrire », reglage levelBeforeWriteMode = content). Eligibilite de l image et du contexte
# (Test-ContentMeasurable), confirmation frmConfirm, etat de calibration au mode 'content' ($script:Cal : barre, bouton
# Arreter, prechauffage et minuteur de la calibration complete ; New-CalibPass renvoie le stade 'content' a
# New-ContentPass), 3 passes des 40 cylindres du plan ecrits avec l image elle-meme a k x V (carre latin, Get-ContentPlan),
# une commande gw write par tete puis une relecture de 3 tours ; arret « Failed to verify Track » de gw (110, 600) : piste
# gardee a son niveau, reprise de la tete une fois par passe ; marge fixe de chaque piste relue (Get-ContentPassStats),
# exclusions, facteur k* par tete (Get-ContentFactor), enregistrements de mesure, puis facteur de l ecriture qui suit
# ($script:WriteFactorNext, lu une fois par Start-ImageWrite) et ecriture de l image. Calcul : 192 et 274 (lot A) ;
# constantes et etat : 565 ; textes : 012.

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
    # seul : ces commandes ne se confondent pas avec l ecriture finale (regex de rpm_analyse.precomp_journal)
    $ct = $cal.Content
    $ph = $ct.Plan.Pass[[int]$ct.Pass].H[[int]$w.H]
    $sel = @{}
    foreach ($c in @($w.Cyls)) { $sel[[int]$c] = [int]$ph.W[[int]$c] }
    $a = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked)   { $a += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $a += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $a += '--no-verify' }
    $a += "--retries=$($numWRetries.Value)"
    $a += Get-WriteFormatArgs
    $a += @('--precomp', (Get-BracketSpec $sel), "--tracks=c=$(Format-CylRanges ([int[]]@($w.Cyls))):h=$([int]$w.H)", "`"$($cal.Image)`"")
    return ,([string[]]$a)
}

function Get-ContentMeasureMinutes([int]$nTracks) {
    # Duree estimee de la mesure avant l ecriture de l image (A.6) : 3 passes de nTracks pistes ecrites (ContentEstWrite,
    # 1,25 s par piste, ecriture verifiee) et relues (ContentEstRead, 0,85 s par piste, 3 tours), plus le prechauffage du
    # reglage warmFullCalib (borne haute : reduit ou saute si le lecteur vient de servir)
    $wu = if ([bool](Get-Setting 'warmFullCalib')) { [math]::Max(0.0, [double]$script:CalWarmupMinutes) } else { 0.0 }
    return [int][math]::Max(1, [math]::Round(3 * $nTracks * ([double]$script:ContentEstWrite + [double]$script:ContentEstRead) / 60 + $wu, 0))
}

function Get-ContentPeekFactors([string]$img, [string]$fmt, [string]$fam) {
    # Facteurs d une ecriture sans mesure sur l image, par tete (texte « Ecrire sans mesure » de la confirmation, A.8) :
    # plan de Start-ImageWrite (Get-WriteFactorPlan -Peek, 140) ; a defaut, k du lecteur (Get-DriveK) plus Dk, ramene a
    # 0..ContentFMax (Limit-WriteFactor), le meme calcul
    $f = @{ 0 = 1.0; 1 = 1.0 }
    $wf = $null
    try { $wf = Get-WriteFactorPlan $img $fmt $true $null -Peek } catch { $wf = $null }
    if ($wf -and $wf.Apply) { $f[0] = [double]$wf.F0; $f[1] = [double]$wf.F1; return $f }
    $drv = [string]$cmbDrive.Text
    foreach ($h in 0, 1) { $f[$h] = [double](Limit-WriteFactor ([double](Get-DriveK $drv $fam $h).K + (Get-DriveDk $drv $h)) ([double]$script:ContentFMax)).F }
    return $f
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
    $pk = Get-ContentPeekFactors $img ([string]$cmbWFmt.Text) $fam
    $cq = @{ Title = (T 'Mesure de la disquette'); Heading = (T "Mesure de la disquette sur l'image"); Level = 'info'; Picto = 'data'
             Text = ((T "Avant l'écriture lente, la précompensation est mesurée sur le contenu même de l'image, sur le lecteur {0} : {1} cylindres répartis sur le disque sont écrits 3 fois, à 3 niveaux de la courbe du lecteur ({2}), et relus après chaque passe. L'image est ensuite écrite avec, pour chaque tête, le niveau qui donne la meilleure marge de lecture.`n`nDurée : environ {3} min avant l'écriture de l'image. Ces pistes reçoivent 3 écritures de plus.`n`n« Écrire sans mesure » : facteur actuel du lecteur, tête 0 × {4}, tête 1 × {5}.") -f "$drive", "$($cyls.Count)", "$lvTxt", "$min", (Format-UiNum ([double]$pk[0]) '0.00'), (Format-UiNum ([double]$pk[1]) '0.00'))
             GoText = (T 'Mesurer puis écrire'); GoGlyph = 'Diagnostic'; AltText = (T 'Écrire sans mesure') }
    $script:ConfirmChoice = $null
    $go = [bool](Show-AppConfirm @cq)
    if (-not $go) {
        $script:AfterCalib = ''
        if ([string]$script:ConfirmChoice -eq 'alt') {
            # Ecriture sans mesure : facteur du lecteur (Start-ImageWrite, Get-DriveK + Dk), aucun facteur mesure en attente
            $script:WriteFactorNext = $null
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
    $scp = Join-Path $script:TempDir $script:ContentScpName
    $script:AlignLoop = $false; $script:AlignNextAt = $null
    # Etat propre de la mesure : plan, passe en cours (0..2), file des commandes de la passe et commande en cours, reprises
    # par passe et tete ('p|h'), cylindres non ecrits ('p|c|h' -> 'nonecrite'), exclusions d avant l ecriture ('c.h'),
    # lectures de toutes les passes (List : jamais @() autour, pwsh 7.6), courbes V, references et bornes
    $ct = @{ Plan = $plan; Pass = 0; Todo = [System.Collections.Generic.List[hashtable]]::new(); Current = $null; Resumes = @{}; Skip = @{}
             PreSkip = $chk.PreSkip; Obs = [System.Collections.Generic.List[object]]::new(); Ncell0 = [int]$chk.Ncell0; Levels = $lv
             KMin = [double](@($lv) | Measure-Object -Minimum).Minimum; V = $chk.V; RefKeys = $chk.RefKeys; RefDates = $chk.RefDates
             Common = [bool]$chk.Common; Fam = $fam; Img = $img; Hard = [int]$chk.Hard }
    $script:Cal = @{
        Mode = 'content'; Stage = 'content'; Drive = $drive; Family = $fam; Slow = $true; Image = $img; Cyls = $cyls; CylList = $cylList
        TSpec = "c=${cylList}:h=0-1"; Scp = $scp; Writes = (New-Object System.Collections.Queue)
        ReadArgs = @(@('read') + (Get-CommonArgs) + @(Get-DriveReadArgs) + @('--revs=3', "--tracks=c=${cylList}:h=0-1", "`"$scp`""))
        # Progression : passes faites / prevues, durees mesurees par phase ; estimation initiale par piste et par phase :
        # moyenne de l ecriture et de la relecture (Update-CalibProgress compte Cyls x 2 pistes par phase)
        StartTime = (Get-Date); PassStart = (Get-Date); PhaseStart = (Get-Date); Phase = 'write'; Value = 0; ValueTxt = (T 'tête 0 puis tête 1'); Spec = ''
        PassesDone = 0; TotalPasses = $lv.Count; WriteDurs = @(); ReadDurs = @(); EstTrack = (([double]$script:ContentEstWrite + [double]$script:ContentEstRead) / 2)
        Home = $false; Geom = $null; NoWarmup = (-not [bool](Get-Setting 'warmFullCalib')); Hold = $false; Redo = $false; DiskOnly = $false
        Units = @(); Swap = $false; LevelAfter = $false; VerifyCount = 0; Retests = 0; Content = $ct
    }
    $script:AfterCalib = 'write'
    Append-Log ((T "=== Mesure de la disquette sur l'image : lecteur {0}, image {1} ({2}) ; {3} cylindres ({4}), niveaux {5} × courbe du lecteur ; calibration du lecteur inchangée ===") -f "$drive", "$([System.IO.Path]::GetFileName($img))", (Get-CalibFamilyName $fam), "$($cyls.Count)", "$cylList", "$lvTxt")
    $dates = if ($ct.Common) { [string]$ct.RefDates[0] } else { "$($ct.RefDates[0]) / $($ct.RefDates[1])" }
    $kind = if ($ct.Common) { (T 'courbe commune') } else { (T 'une courbe par tête') }
    Append-Log ((T "Mesure sur l'image : courbe du lecteur du {0} ({1}) ; précompensation écrite bornée à 0..{2} ns.") -f "$dates", "$kind", "$($ct.Hard)")
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
    foreach ($h in 0, 1) {
        $cs = [int[]]@($ct.Plan.Pass[$p].H[$h].Cyls)
        if ($cs.Count -gt 0) { $ct.Todo.Add(@{ H = $h; Cyls = $cs; Resume = $false }) }
    }
    $bc = @($ct.Plan.Cyls); $nb = @($ct.Plan.Blocks).Count
    $len = if ($nb -gt 0) { [int]($bc.Count / $nb) } else { 0 }
    $bk = @(for ($bi = 0; $bi -lt $nb; $bi++) { $c0 = [int]$bc[$bi * $len]; "c$c0-$($c0 + $len - 1) × $(Format-UiNum (Get-ContentLevel $bi $p ([double[]]$ct.Levels)) '0.##')" })
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
        $w = $ct.Todo[0]; $ct.Todo.RemoveAt(0); $ct.Current = $w
        $script:Chain.Enqueue({ Invoke-ContentWriteNext })
        Start-Gw (Get-ContentWriteArgs $cal $w)
        return
    }
    $cal.WriteDurs += ((Get-Date) - $cal.PhaseStart).TotalSeconds
    $cal.Phase = 'read'; $cal.PhaseStart = Get-Date
    if (Test-Path -LiteralPath $cal.Scp) { Remove-Item -LiteralPath $cal.Scp -Force }
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
    if ([int]$ct.Pass -lt [int]$cal.TotalPasses) { New-ContentPass; return }
    Complete-ContentMeasure $cal
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
    # ; donnees minimales (Get-ContentHeadCheck), puis facteur k* borne a [k_min ; 1] (Get-ContentFactor) ; tete non
    # mesuree : k du lecteur (Get-DriveK). Journal : pistes ecartees par raison (T-B14), facteur et reserves de chaque tete
    # (T-B15 a T-B19). Pas de fenetre de decision : le resultat est applique. Enregistrements de mesure des tetes mesurees
    # (C.2 : k du lecteur des ecritures suivantes, Add-ContentMeasure, Save-Config), puis facteur de l ecriture qui suit
    # ($script:WriteFactorNext, lu une fois par Start-ImageWrite) et ecriture de l image ; prechauffage de l ecriture lente
    # reduit ou saute, le lecteur venant de servir (comme Complete-DiskMeasure)
    $ct = $cal.Content; $drive = [string]$cal.Drive; $fam = [string]$cal.Family
    $ex = Get-ContentExclusions $ct.Obs ([double]$script:ContentZMax) ([double]$script:ContentCellsTol) ([double]$script:ContentFluxMin)
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
    # Lignes retenues par tete : @{ P ; C ; K ; Y = Mfix }
    $rows = @{ 0 = @(); 1 = @() }
    foreach ($o in $ct.Obs) {
        if ($null -eq $o) { continue }
        $h = [int]$o.H
        if ($ex.ContainsKey("$([int]$o.C).$h") -or [int]$o.NRev -le 0 -or [double]::IsNaN([double]$o.Mfix)) { continue }
        $rows[$h] += ,@{ P = [string]$o.P; C = [int]$o.C; K = [double]$o.K; Y = [double]$o.Mfix }
    }
    $date = Get-Date -Format 'dd/MM/yyyy HH:mm'
    $kk = @{ 0 = 1.0; 1 = 1.0 }; $src = @{ 0 = 'defaut'; 1 = 'defaut' }; $recs = @()
    $kMinTxt = Format-UiNum ([double]$ct.KMin) '0.##'
    foreach ($h in 0, 1) {
        $pre = (T '[tête {0}] ') -f "$h"
        $hc = Get-ContentHeadCheck $rows[$h] ([int]$script:ContentMinCyl) ([int]$script:ContentMinLevelCyl)
        $fit = if ($hc.Ok) { Get-ContentFactor $rows[$h] ([double]$ct.KMin) 1.0 } else { $null }
        if ($fit -and $fit.Ok) {
            $k = [math]::Round([double]$fit.K, 3)
            $kk[$h] = $k; $src[$h] = 'mesure'
            $vx = if ($fit.Ext) { Format-UiNum ([double]$fit.KVertex) '0.00' } else { '-' }
            $se = if ([double]::IsNaN([double]$fit.SeK)) { '-' } else { Format-UiNum ([double]$fit.SeK) '0.00' }
            Append-Log ((T '{0}Facteur mesuré : k = {1} (sommet {2} ± {3} ; marge à k : {4} ns par rapport à k = 1 ; {5} cylindres, {6} pistes ; écart-type résiduel {7} ns).') -f "$pre", (Format-UiNum $k '0.00'), "$vx", "$se", (Format-UiNum ([double]$fit.Gain) '+0.0;-0.0;0.0'), "$($fit.NCyl)", "$($fit.N)", (Format-UiNum ([double]$fit.S) '0.0'))
            if ([string]$fit.Bound -eq 'low') { Append-Log ((T '{0}Optimum à la borne basse du plan ({1}) ou en dessous : k = {1} retenu.') -f "$pre", "$kMinTxt") }
            elseif ([string]$fit.Bound -eq 'high') { Append-Log ((T '{0}Optimum à la borne haute du plan (1) ou au-dessus : k = 1 retenu, comme la courbe du lecteur.') -f "$pre") }
            if ($fit.Flat) { Append-Log ((T '{0}Marge peu sensible au niveau dans le plan : facteur peu déterminé.') -f "$pre") }
            # Enregistrement de mesure (C.2) : courbe ecrite W_h = facteur x V_h, bornee a 0..max(borne, v) (ConvertTo-ScaledSpec)
            $dk = [double](Get-DriveDk $drive $h)
            $f = [double](Limit-WriteFactor ($k + $dk) ([double]$script:ContentFMax)).F
            $vals = [int[]]@(foreach ($v in @($ct.V[$h])) { [int][math]::Max(0.0, [math]::Min([math]::Round($f * [double]$v), [double][math]::Max([int]$ct.Hard, [int]$v))) })
            $nEx = @(@(@($ct.PreSkip.Keys) + @($ex.Keys)) | Where-Object { (([string]$_) -split '\.')[1] -eq "$h" }).Count
            $recs += ,@{ Model = 'contenu'; Drive = $drive; Family = $fam; Head = $h; Date = $date; Image = [System.IO.Path]::GetFileName([string]$cal.Image)
                         K = $k; KVertex = $(if ($fit.Ext) { [math]::Round([double]$fit.KVertex, 3) } else { $null }); Bound = [string]$fit.Bound; Flat = [bool]$fit.Flat
                         SeK = [double]$fit.SeK; B1 = [double]$fit.B1; B2 = [double]$fit.B2; Gain = [double]$fit.Gain; S = [double]$fit.S
                         NCyl = [int]$fit.NCyl; NObs = [int]$fit.N; NExcl = [int]$nEx; Levels = [double[]]@($ct.Levels); Dk = $dk; F = $f
                         Values = $vals; Spec = (Build-CurveProfile $vals); RefKey = [string]$ct.RefKeys[$h]; RefDate = [string]$ct.RefDates[$h]
                         Calc = [string]$script:CalibCalc; ContentCalc = [string]$script:ContentCalc; Version = [string]$script:Version }
        } else {
            # Tete non mesuree : k du lecteur (mediane des 3 derniers k* du lecteur, de la famille et de la tete ; 1 sans mesure)
            $dr = Get-DriveK $drive $fam $h
            $kk[$h] = [double]$dr.K; $src[$h] = [string]$dr.Src
            $why = if (-not $hc.Ok -and [string]$hc.Why -eq 'peu') { (T 'trop peu de pistes exploitables ({0} cylindres)') -f "$($hc.NCyl)" } else { (T 'ajustement impossible') }
            # Origine du k du lecteur, comme T-C8b (Get-WriteFactorSrcText, 140) : mediane de N >= 2 mesures, ou derniere mesure
            $kTxt = Format-UiNum ([double]$dr.K) '0.00'
            $kt = if ([string]$dr.Src -ne 'lecteur') { (T 'k 1, aucune mesure de ce lecteur') }
                  elseif ([int]$dr.N -ge 2) { (T 'k {0}, médiane des {1} dernières mesures du lecteur') -f "$kTxt", "$($dr.N)" }
                  else { (T 'k {0} de la dernière mesure du lecteur, du {1}') -f "$kTxt", $(if ($dr.Rec -and $dr.Rec.Date) { [string]$dr.Rec.Date } else { '?' }) }
            Append-Log ((T '{0}Facteur non mesuré ({1}) : facteur du lecteur appliqué ({2}).') -f "$pre", "$why", "$kt")
        }
    }
    foreach ($rc in $recs) { Add-ContentMeasure $rc }
    if ($recs.Count -gt 0 -and -not $script:Restore) { [void](Save-Config) }
    # Complement « facteur applique » du libelle du profil refait avec le nouveau k du lecteur (revue 12.8.1, point 6)
    if ($recs.Count -gt 0) { Update-WriteFactorNote }
    $el = if ($cal.StartTime -is [datetime]) { ((Get-Date) - $cal.StartTime).TotalSeconds } else { 0 }
    $durTxt = Format-CalDuration $el
    $pbWCal.Visible = $false
    $lblWCal.Text = ((T "Mesure sur l'image terminée en {0}") -f "$durTxt")
    $script:Cal = $null
    if ($script:AfterCalib -ne 'write') { $script:WriteFactorNext = $null; return }
    $script:AfterCalib = ''
    $script:WriteFactorNext = @{ Drive = $drive; Fam = $fam; Img = [string]$cal.Image; K = @{ 0 = [double]$kk[0]; 1 = [double]$kk[1] }
                                 Src = @{ 0 = [string]$src[0]; 1 = [string]$src[1] }; Date = $date }
    Append-Log ((T "Mesure de la disquette sur l'image terminée en {0} : écriture de l'image avec le facteur mesuré.") -f "$durTxt")
    Start-ImageWrite -NoWarmup:([bool]$cal.WarmSkip)
}
