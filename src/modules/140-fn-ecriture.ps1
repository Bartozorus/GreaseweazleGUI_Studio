# ============================== FONCTIONS : ECRITURE ===========================

function Get-WarmMinutesText([double]$wm) {
    # Duree du prechauffage dans les textes des cases : « 5 min », sinon minutes et secondes (« 2 min 30 s »)
    if ($wm -eq [math]::Floor($wm)) { return "$([int]$wm) min" }
    return (Format-CalDuration (60 * $wm))
}

function Update-SlowUi {
    # Ecriture lente : champ --precomp de la tete 1 actif, le premier champ devient celui de la tete 0
    $on = $chkWSlow.Checked
    $txtWPrecomp1.Enabled = $on; $lblWPrecomp1.Enabled = $on
    $chkWPrecomp.Text = if ($on) { (T 'Précomp. tête 0 (--precomp) :') } else { (T 'Précompensation (--precomp) :') }
    # Prechauffages (12.8, D6) : avant l ecriture lente (case inactive sans ecriture lente) et avant une calibration
    # complete, duree commune (reglage warmMinutes, variable CalWarmupMinutes) ; cases inactives a 0 min. Champ de la duree
    # recopie de la variable sous la garde des liaisons, sans changer le reglage
    $wm = [double]$script:CalWarmupMinutes
    $mt = Get-WarmMinutesText $wm
    $chkWWarm.Text = if ($wm -gt 0) { (T "Préchauffer le lecteur avant l'écriture lente ({0} au plus de lecture sans écriture)") -f "$mt" } else { (T "Préchauffer le lecteur avant l'écriture lente (désactivé : durée du préchauffage à 0)") }
    $chkWWarm.Enabled = ($on -and $wm -gt 0)
    $chkWCalWarm.Text = if ($wm -gt 0) { (T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f "$mt" } else { (T "Préchauffer le lecteur avant la calibration complète (désactivé : durée du préchauffage à 0)") }
    $chkWCalWarm.Enabled = ($wm -gt 0)
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        $nv = [decimal][math]::Max(0.0, [math]::Min(30.0, $wm))
        if ($numWWarmMin.Value -ne $nv) { $numWWarmMin.Value = $nv }
        # 12.7 point 5 : mesure de la disquette, ecriture lente seulement. 12.8 (D5) : liste au « Test rapide » : la
        # disquette est mesuree (ecriture rapide ou lente, quel que soit le point de depart, memes exclusions partout :
        # Get-LevelWriteSkip) : case cochee et verrouillee, le reglage levelBeforeWrite est garde pour les autres modes
        $quick = ($cmbWCalMode.SelectedIndex -eq 2)
        $show = if ($quick) { $true } else { [bool](Get-Setting 'levelBeforeWrite') }
        if ($chkWLevel.Checked -ne $show) { $chkWLevel.Checked = $show }
    } finally { $script:SettingSync = $sv }
    $chkWLevel.Text = if ($quick) { (T "Mesurer la disquette avant l'écriture : toujours en « Test rapide » (niveau de précompensation et état de la surface)") } else { (T "Mesurer la disquette avant l'écriture lente : niveau de précompensation et état de la surface (environ 1 min)") }
    $chkWLevel.Enabled = ($on -and -not $quick)
}

# Options "comment ecrire" de l ecriture ; la calibration les reprend sans --format ni --diskdefs (Get-CalibDriveArgs, motif HFE)
function Get-WriteFormatArgs {
    $a = @()
    if ($chkWReverse.Checked)    { $a += '--reverse' }
    if ($chkWHard.Checked)       { $a += '--hard-sectors' }
    if ($chkWTG43.Checked)       { $a += '--gen-tg43' }
    if ($cmbWFmt.Text -and $cmbWFmt.Text -ne '(auto)')      { $a += "--format=$($cmbWFmt.Text)" }
    if ($cmbWDensel.Text -ne '(non)') { $a += "--densel=$($cmbWDensel.Text)" }
    if ($txtWFakeIdx.Text.Trim())     { $a += "--fake-index=$($txtWFakeIdx.Text.Trim())" }
    if ($txtWDiskdefs.Text.Trim())    { $a += "--diskdefs=`"$($txtWDiskdefs.Text.Trim())`"" }
    return $a
}

function Start-ImageWrite([switch]$NoWarmup) {
    # Ecriture de l image avec les parametres de l onglet (bouton ECRIRE, ecriture rapide ou lente, fin de calibration automatique)
    # Ecriture lente : prechauffage du lecteur avant la premiere ecriture (Start-WriteWarmup, chaine d ecriture prete) ;
    # NoWarmup : prechauffage passe a la demande de l utilisateur pendant la calibration qui precede
    # 12.8 (lot 1c, G1) : courbe adaptee a cette disquette par la calibration rapide qui precede : controle apres ecriture
    # impose, meme case decochee (drapeau lu une fois)
    $postForce = [bool]$script:LevelPostForce; $script:LevelPostForce = $false
    if (-not (Test-Path -LiteralPath $txtWFile.Text)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier image introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    # Image flux a plusieurs tours : pistes dont le contenu change d un tour a l autre (bits faibles d une protection),
    # que gw ne reproduit pas (il n ecrit que le premier tour) : avertissement, confirmation, pas de reecriture au controle
    $script:ImageUnstable = $null; $script:ImageSrcWeak = $null; $script:ImageNoJudge = $null; $script:ImageScpFailed = $false
    if (-not $script:Restore -and $script:ScpStatsOk -and [System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp') {
        # Analyse (quelques secondes pour un flux complet) mise en cache par fichier, taille et date
        $uk = @{}; $ck = @{}; $nj = @{}; $failed = $false
        $fi = Get-Item -LiteralPath $txtWFile.Text
        $ckey = "$($fi.FullName)|$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)"
        if ($script:ScpWeakCache -and $script:ScpWeakCache.Key -eq $ckey) { $uk = $script:ScpWeakCache.Weak.Clone(); $ck = $script:ScpWeakCache.Crit.Clone(); $nj = $script:ScpWeakCache.NoJudge.Clone(); $failed = [bool]$script:ScpWeakCache.Failed }
        else {
            $oldTxt = $stOp.Text; $stOp.Text = (T "Analyse de l'image flux..."); $status.Refresh()
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            try {
                $ts = Read-ScpFile $txtWFile.Text
                foreach ($tn in @($ts.Keys)) {
                    $m = Get-TrackMetrics $ts[$tn]
                    $key = "$([math]::Floor([int]$tn / 2)).$([int]$tn % 2)"
                    # Image jugee aux seuils Standard, comme un original en restauration
                    $lv = if ($m.Bad) { 2 } else { Get-HealthLevel $m.Ooc $m.Dr $m.Stab $m.J $script:JitterStdOk $script:JitterStdWatch }
                    if ($m.Weak) { $uk[$key] = $true } elseif ($lv -ge 2) { $ck[$key] = $true }
                    # Courte zone instable (raccord ou protection) ou stabilite non mesurable (un seul tour, densite) : une
                    # zone instable relue sur la copie n y sera pas jugee
                    elseif ($m.ShortUnstable -or $m.Blocks -eq 0) { $nj[$key] = $true }
                }
                $script:ScpWeakCache = @{ Key = $ckey; Weak = $uk.Clone(); Crit = $ck.Clone(); NoJudge = $nj.Clone(); Failed = $false }
            } catch { $failed = $true } finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default; $stOp.Text = $oldTxt }
        }
        if ($uk.Count -gt 0) {
            $lst = Format-TrackList (Sort-TrackKeys @($uk.Keys))
            Append-Log ((T "Image flux : {0} piste(s) changent d'un tour à l'autre ({1}) : bits faibles d'une protection contre la copie probable. gw n'en écrit que le premier tour : la protection risque de ne pas fonctionner sur la disquette écrite. Ces pistes ne sont pas réécrites par le contrôle.") -f "$($uk.Count)", "$lst")
            # 12.8 (D3) : confirmation par frmConfirm, case qui nomme le lecteur
            $cq = @{ Title = (T 'Protection contre la copie'); Heading = (T 'Image protégée contre la copie'); Level = 'warn'; Picto = 'forbid'
                     Text = ((T "L'image {0} contient {1} piste(s) dont le contenu change d'un tour à l'autre ({2}) : bits faibles d'une protection contre la copie probable.`n`ngw n'écrit que le premier tour de chaque piste : ces bits seront figés et la protection risque de ne pas fonctionner sur la disquette écrite. N'écrivez jamais cette image sur une disquette d'origine.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))", "$($uk.Count)", "$lst")
                     Check = ((T "La disquette du lecteur {0} n'est pas une disquette d'origine") -f "$($cmbDrive.Text)"); GoText = (T 'Écrire quand même'); GoGlyph = 'Save' }
            if (-not (Show-AppConfirm @cq)) { Append-Log (T 'Écriture annulée : image protégée non écrite.'); return }
        }
        if ($ck.Count -gt 0) {
            Append-Log ((T "Image flux : {0} piste(s) déjà critique(s) ou illisible(s) dans l'image ({1}) : piste non formatée, protection ou défaut de l'original. gw en écrit le premier tour tel quel : ces pistes ne sont ni réécrites ni comptées par le contrôle.") -f "$($ck.Count)", "$(Format-TrackList (Sort-TrackKeys @($ck.Keys)))")
        }
        $ign = @{}
        foreach ($k in @(@($uk.Keys) + @($ck.Keys))) { $ign[[string]$k] = $true }
        if ($ign.Count -gt 0) { $script:ImageUnstable = $ign }
        $script:ImageSrcWeak = $uk; $script:ImageNoJudge = $nj; $script:ImageScpFailed = $failed
    }
    $slow = $chkWSlow.Checked
    $userTs = $txtWTracks.Text.Trim()
    $heads = @(0, 1)
    if ($slow) {
        $heads = Get-TSpecHeads $userTs
        if ($heads.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show((T 'Écriture lente : le champ Pistes ne sélectionne ni la tête 0 ni la tête 1.'),(T 'Erreur'),'OK','Warning'); return
        }
        if (-not [regex]::IsMatch(":$userTs", ':\s*h\s*=')) {
            # Sans h= explicite : faces de l image. gw part des pistes du format et h=1 ajouterait la tete 1 d un format
            # simple face (D64, IMG simple face, IPF une face) : avec --erase-empty, toute la face 1 serait effacee.
            $imgSet = Get-ImageTrackSet $txtWFile.Text
            if ($null -ne $imgSet) {
                $present = @{}
                foreach ($k in @($imgSet.Keys)) { $present[[int](($k -split '\.')[1])] = $true }
                $heads = @(@(0, 1) | Where-Object { $present.ContainsKey($_) })
                if ($heads.Count -eq 1) { Append-Log ((T "Écriture lente : image à une seule face, seule la tête {0} est écrite.") -f "$($heads[0])") }
            } elseif ($chkWEraseEmpty.Checked) {
                [void][System.Windows.Forms.MessageBox]::Show(((T "Écriture lente : nombre de faces de l'image inconnu ({0}).`nIndiquer les têtes dans le champ Pistes (h=0-1 pour une image double face, h=0 pour une simple face)`nou décocher « Effacer les pistes vides » : la tête 1 d'un format simple face serait effacée.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))"),(T 'Erreur'),'OK','Warning'); return
            }
        }
    }
    # $base : toutes les options sauf --tracks et l image (reprises telles quelles par les reecritures ciblees) ;
    # en ecriture lente, sans --precomp : chaque tete a sa commande et sa valeur
    $base = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked)   { $base += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $base += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $base += '--no-verify' }
    $base += "--retries=$($numWRetries.Value)"
    # Mode Auto, image haute densite (format choisi apres l image, par exemple) : champs attendus de la branche haute densite
    # d Update-PrecompForImage (12.7 : famille hd calibrable : sa courbe, sinon le profil d origine haute densite ; haute
    # densite non calibrable : profil d origine de sa famille, jamais une courbe double densite) ; format revenu en double
    # densite apres coup : profil calibre de nouveau
    if ($cmbWProfile.SelectedIndex -eq 0 -and $chkWPrecomp.Checked) {
        if (Get-HighDensityReason $txtWFile.Text $cmbWFmt.Text) {
            $hf = Get-HdCalibFamily $txtWFile.Text $cmbWFmt.Text
            if ($hf) { $af = Get-HdAutoFields $hf ([bool]$chkWSlow.Checked); $e0 = $af.P0; $e1 = $af.P1 }
            else { $e0 = if ((Get-ImageFamily $txtWFile.Text $cmbWFmt.Text) -eq 'long') { $script:PrecompLongDefault } else { $script:PrecompStdDefault }; $e1 = $e0 }
            if ($txtWPrecomp.Text.Trim() -ne $e0 -or $txtWPrecomp1.Text.Trim() -ne $e1) { Update-PrecompForImage $txtWFile.Text }
        } elseif ($script:WProfileHd) { Update-PrecompForImage $txtWFile.Text }
    }
    $pc0 = if ($chkWPrecomp.Checked -and $txtWPrecomp.Text.Trim()) { $txtWPrecomp.Text.Trim() } else { $null }
    $pc1 = if ($chkWPrecomp.Checked -and $txtWPrecomp1.Text.Trim()) { $txtWPrecomp1.Text.Trim() } else { $null }
    if (-not $slow -and $pc0) { $base += '--precomp'; $base += $pc0 }
    $base += Get-WriteFormatArgs
    $a = $base
    if ($userTs)      { $a += "--tracks=$userTs" }
    $a += "`"$($txtWFile.Text)`""
    $headPc = $null
    $script:WriteQueue.Clear()
    if ($slow) {
        # Ecriture lente : tete 0 sur tout le disque, puis tete 1 (gw applique --precomp par cylindre seulement).
        # Les champs correspondent aux tetes physiques (calibration) ; hswap : la tete logique h est ecrite par la tete 1 - h.
        $swap = (Get-TSpecExtras $userTs) -match '(^|:)\s*hswap\s*(:|$)'
        $headPc = @{}
        foreach ($h in 0, 1) { $phys = if ($swap) { 1 - $h } else { $h }; $headPc[$h] = if ($phys -eq 0) { $pc0 } else { $pc1 } }
        foreach ($h in $heads) {
            $cmd = @($base); if ($headPc[$h]) { $cmd += '--precomp'; $cmd += $headPc[$h] }
            $script:WriteQueue.Enqueue([string[]]($cmd + @("--tracks=$(Set-TSpecHead $userTs $h)", "`"$($txtWFile.Text)`"")))
        }
        $none = (T 'aucune')
        Append-Log ((T "Écriture lente : {0} commande(s) gw write, tête 0 puis tête 1 ; precomp tête 0 : {1} ; tête 1 : {2}") -f "$($heads.Count)", "$(if ($headPc[0]) { $headPc[0] } else { $none })", "$(if ($headPc[1]) { $headPc[1] } else { $none })")
    }
    # Prechauffage de l ecriture lente (Start-WriteWarmup) : un cylindre sur 10 des pistes ecrites, tetes ecrites
    $warmTs = if ($slow) { Get-WriteWarmupTSpec $userTs ([int[]]$heads) $txtWFile.Text } else { $null }
    # 12.8 (FIX1C, constat 3, G1) : controle impose aussi quand un profil ecrit est la courbe adaptee d une calibration
    # rapide (bouton Calibrer au test rapide, puis ECRIRE sans nouvelle mesure), meme case decochee ; la ligne de journal
    # est celle de Complete-LevelCalib, ecrite ici quand le drapeau n a pas ete pose
    if (-not $postForce) {
        $wsp = if ($slow) { @($heads | ForEach-Object { $headPc[$_] }) } else { @($pc0) }
        if (Test-LevelAdaptedSpec ([string[]]@($wsp | Where-Object { $_ }))) { $postForce = $true; Append-Log (T 'Contrôle après écriture imposé : courbe adaptée à cette disquette.') }
    }
    $post = ([bool]$chkWPostCheck.Checked -or $postForce)
    $blocker = if ($post) { Get-WriteCheckBlocker $txtWFile.Text $cmbWFmt.Text } else { $null }
    if ($blocker) {
        Append-Log ((T "Contrôle de toutes les pistes non applicable ({0}) : l'analyse de flux est calibrée pour le MFM double densité. Écriture sans contrôle.") -f "$blocker")
    }
    if ($post -and -not $blocker) {
        # Options de lecteur reprises par les relectures de controle (gw read les accepte toutes)
        $readOpts = @(Get-DriveReadArgs)
        New-WriteCheck $base $txtWFile.Text $userTs ([int]$numWRepair.Value) $readOpts $headPc
        if ($script:ImageUnstable) { $script:Rep.Ignore = $script:ImageUnstable }
        $script:Rep.SrcWeak = $script:ImageSrcWeak; $script:Rep.NoJudge = $script:ImageNoJudge
        # SCP non analyse (module absent, restauration : voir Start-RestoreWrite) ou analyse en echec : rien n est juge
        if ([System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp' -and ($script:ImageScpFailed -or ((-not $script:Restore) -and $null -eq $script:ImageNoJudge))) { $script:Rep.UnstDefect = $false }
        $script:Chain.Clear()
        if ($slow) { for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) } }
        else { $script:WriteArgs = $a; $script:Chain.Enqueue({ Start-Gw $script:WriteArgs }) }
        $script:Chain.Enqueue({ Start-WriteCheck })
        if ($slow) { Start-WriteWarmup $warmTs ([bool]$NoWarmup) } else { Invoke-NextChainStep }
    } elseif ($slow) {
        $script:Chain.Clear()
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        if ($script:Restore) { $script:Chain.Enqueue({ Invoke-RestoreNext }) }   # restauration sans controle complet
        Start-WriteWarmup $warmTs ([bool]$NoWarmup)
    } else {
        if ($script:Restore) { $script:Chain.Clear(); $script:Chain.Enqueue({ Invoke-RestoreNext }) }
        Start-Gw $a
    }
}

function Get-CalibState([string]$fam, [bool]$heads, [int]$nCyl = 0) {
    # Etat de la calibration utilisee par l ecriture rapide (courbe commune) ou lente (courbes par tete) :
    #  'ok'      : mesuree sur le motif de test (Method = 'motif') et, par tete, au moins aussi recente que la courbe
    #              commune : sinon Get-FamilyCurves applique la courbe commune aux deux tetes ;
    #  'content' : courbe anterieure au motif, mesuree sur le contenu d une image (biaisee) : refaite ;
    #  'stale'   : courbes par tete anterieures a la calibration commune ;
    #  'short'   : courbe plus courte que l image de nCyl cylindres (> 0) de plus de 4 cylindres (seuil de Get-LevelRef) :
    #              gw appliquerait la valeur de son dernier cylindre a tous les suivants ; refaite. Une courbe plus longue
    #              couvre l image (memes cylindres physiques) : conservee ;
    #  'none'    : absente ou incomplete.
    $keys = @(if ($heads) { "${fam}_h0", "${fam}_h1" } else { $fam })
    $missing = $false
    foreach ($k in $keys) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv) { $missing = $true } elseif ($cv.Method -ne 'motif') { return 'content' }
    }
    if ($missing) { return 'none' }
    if ($heads -and -not (Test-HeadCurvesCurrent $fam)) { return 'stale' }
    if ($nCyl -gt 0) { foreach ($k in $keys) { if (@($script:PrecompCurves[$k].Values).Count -lt $nCyl - 4) { return 'short' } } }
    return 'ok'
}

function Test-CalibCurrent([string]$fam, [bool]$heads) {
    # Calibration utilisable telle quelle par l ecriture rapide ou lente (voir Get-CalibState)
    return ((Get-CalibState $fam $heads) -eq 'ok')
}

function Set-WritePreset([string]$mode, [string]$path, [string]$source = '') {
    # Parametres d une ecriture rapide ou lente : image entiere, profil Auto, pre-effacement, effacement des pistes vides,
    # verification gw, 10 essais, precomp transmise. Rapide : une commande pour les deux tetes, sans controle complet.
    # Lente : tete 0 puis tete 1 (profils par tete), controle de toutes les pistes, 3 passes de reecriture. Les options
    # de lecteur (flippy, densel, fake index, diskdefs, secteurs durs, TG43) decrivent le materiel : conservees, comme
    # les elements step, h0.off, h1.off et hswap du champ Pistes (seuls c= et h= sont retires : image entiere).
    # Format : ADF -> amiga.amigados, ou amiga.amigados_hd d apres la taille ; image secteur brute (IMG, IMA, ST, DSK
    # sans signature CPC) : format conserve si la meme source (fichier, ou entree d archive : deux ZIP peuvent extraire
    # le meme nom) est deja celle de l onglet Ecriture, sinon (auto) et Start-PresetWrite demande de le choisir ;
    # autres images : (auto), gw deduit le format.
    if (-not $source) { $source = $path }
    $same = ($txtWFile.Text -eq $path -and $script:PresetSource -eq $source)
    $txtWFile.Text = $path; $script:PresetSource = $source
    if ($path -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $path) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) }
    elseif (-not ($same -and (Test-NeedsFormat $path))) { $cmbWFmt.SelectedIndex = 0 }
    $cmbWProfile.SelectedIndex = 0
    # Faces de l image (Get-ImageTrackSet) : inconnues -> pas d effacement des pistes vides, qui effacerait la face 1
    # d une image simple face (gw n ecrit alors que les pistes presentes) ; une seule face en ecriture rapide -> h= de
    # cette face dans Pistes (en lente, Start-ImageWrite n ecrit deja que les faces de l image).
    $extras = Get-TSpecExtras $txtWTracks.Text
    $set = Get-ImageTrackSet $path
    $facesUnknown = ($null -eq $set)
    $oneHead = $null
    if (-not $facesUnknown) {
        $hs = @(@($set.Keys) | ForEach-Object { [int](([string]$_ -split '\.')[1]) } | Sort-Object -Unique)
        if ($hs.Count -eq 1) { $oneHead = $hs[0] }
    }
    $chkWPreErase.Checked = $true; $chkWEraseEmpty.Checked = (-not $facesUnknown); $chkWNoVerify.Checked = $false
    $numWRetries.Value = 10; $chkWPrecomp.Checked = $true
    $txtWTracks.Text = $(if ($mode -ne 'slow' -and $null -ne $oneHead) { "h=$oneHead" + $extras } else { $extras.TrimStart(':') })
    $chkWSlow.Checked = ($mode -eq 'slow')
    if ($mode -eq 'slow') {
        $chkWPostCheck.Checked = $true; $numWRepair.Value = 3
        Append-Log (T 'Écriture lente : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, tête 0 puis tête 1, contrôle de toutes les pistes, 3 passes de réécriture.')
    } else {
        $chkWPostCheck.Checked = $false
        Append-Log (T 'Écriture rapide : image entière, profil Auto, pré-effacement, effacement des pistes vides, vérification gw, 10 essais, les deux têtes ensemble, sans contrôle complet des pistes.')
        if ($null -ne $oneHead) { Append-Log ((T "Image à une seule face : seule la tête {0} est écrite (h={0} dans Pistes).") -f "$oneHead") }
    }
    if ($facesUnknown) { Append-Log (T "Nombre de faces de l'image inconnu : effacement des pistes vides désactivé (seules les pistes présentes dans l'image sont écrites).") }
    if ($extras) { Append-Log ((T "Champ Pistes : éléments de lecteur conservés ({0}).") -f $extras.TrimStart(':')) }
}

# --- Surcharge d operation (12.8, D4) -------------------------------------------
# Une ecriture depuis la Bibliotheque applique son prereglage aux controles de l onglet Ecriture (Set-WritePreset), le
# temps de l operation seulement : l etat d avant (Save-WriteTabState) est ecrit a sa place dans la configuration
# (Save-Config, Set-OpOverrideConfig), puis retabli quand plus rien ne tourne (Update-OpOverride, minuteur principal).
# 12.7 : le prereglage devenait la configuration de l onglet Ecriture.

function Enter-OpOverride([string]$kind) {
    # Surcharge deja active (operation precedente non terminee) : l etat d origine est garde
    if ($script:OpOverride) { return }
    $script:OpOverride = @{ Kind = $kind; Saved = (Save-WriteTabState); Started = $false }
}

function Exit-OpOverride([switch]$Keep) {
    # Fin de la surcharge : onglet Ecriture retabli et configuration enregistree. Keep : prereglage garde dans l onglet,
    # sans rien retablir (image secteur dont le format est a choisir dans l onglet Ecriture, comme en 12.7)
    $o = $script:OpOverride
    if (-not $o) { return }
    $script:OpOverride = $null
    if ($Keep) { return }
    Restore-WriteTabState $o.Saved
    Append-Log (T "Bibliothèque : opération terminée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré).")
    [void](Save-Config)
}

function Test-OpIdle {
    # Rien ne tourne (gw, etapes, calibration, calibration B, controle, prechauffage, detection, restauration ; la mesure
    # continue de l onglet Qualite n est pas une suite de l operation) et aucune fenetre modale n est ouverte
    if ($script:GwProc -or $script:Cal -or $script:CalRedo -or $script:LevelFieldsPending) { return $false }
    if (@('', 'quality') -notcontains (Get-AppBusy)) { return $false }
    return (@([System.Windows.Forms.Application]::OpenForms | Where-Object { $_.Modal -and $_.Visible -and -not [object]::ReferenceEquals($_, $form) }).Count -eq 0)
}

function Update-OpOverride([bool]$gwDone) {
    # Minuteur principal : fin de l operation surchargee. Verifiee juste apres le traitement de la fin d une commande gw
    # (gwDone), ou a tout autre tick si la fenetre principale peut recevoir le focus (aucune boite de message ouverte)
    $o = $script:OpOverride
    if (-not $o -or -not $o.Started) { return }
    if (-not (Test-OpIdle)) { return }
    if (-not $gwDone -and -not $form.CanFocus) { return }
    Exit-OpOverride
}

function Set-OpOverrideConfig($cfg) {
    # Save-Config pendant une operation surchargee : reglages de l onglet Ecriture d avant l operation
    $s = $script:OpOverride.Saved; $w = $cfg['write']
    $w['file'] = [string]$s.File; $w['format'] = [string]$s.Fmt; $w['preErase'] = [bool]$s.Pre; $w['eraseEmpty'] = [bool]$s.Empty
    $w['noVerify'] = [bool]$s.NoVer; $w['retries'] = [int]$s.Retries; $w['precompOn'] = [bool]$s.Precomp; $w['precomp'] = [string]$s.P0
    $w['precomp1'] = [string]$s.P1; $w['tracks'] = [string]$s.Tracks; $w['postCheck'] = [bool]$s.Post; $w['repairMax'] = [int]$s.Repair
    $w['slowWrite'] = [bool]$s.Slow; $w['calMode'] = [int][math]::Max(0, [int]$s.CalMode)
    $codes = $script:SettingDefs['precompProfile'].Codes
    $pc = $codes[[math]::Max(0, [math]::Min($codes.Count - 1, [int]$s.Profile))]
    $w['precompProfileCode'] = $pc; $w['precompProfile'] = Get-SettingText 'precompProfile' $pc
}

function Start-PresetWrite([string]$mode, [switch]$NoCalib, [switch]$LevelOnly) {
    # Calibration automatique si elle manque pour la famille de l image (commune en rapide, par tete en lente), puis
    # ecriture. Ecriture directe, sans calibration automatique : flux ecrit tel quel (sans --format, gw ne lui applique
    # pas la precompensation), image haute densite (12.7 : famille hd calibrable : sa courbe si elle existe, sinon le
    # profil d origine haute densite, jamais de calibration automatique), secteurs durs ou lecteur 8 pouces, densite non
    # etablie (conteneur a geometrie libre : IMD, TD0, D88, D64... ; IPF ou HFE dont la cellule sort des plages
    # mesurables), module d analyse SCP indisponible. NoCalib (restauration) : la calibration existante est conservee,
    # jamais refaite.
    $img = $txtWFile.Text
    if (-not $img -or -not (Test-Path -LiteralPath $img)) {
        [void][System.Windows.Forms.MessageBox]::Show((T 'Fichier image introuvable.'),(T 'Erreur'),'OK','Warning'); return
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    $fmt = $cmbWFmt.Text
    $explicit = ($fmt -and $fmt -ne '(auto)')
    if ((Test-NeedsFormat $img) -and -not $explicit) {
        # Avant toute calibration : gw refuserait l ecriture apres coup (« Sector image requires a disk format »)
        [void][System.Windows.Forms.MessageBox]::Show(((T "Image secteur sans géométrie ({0}) : gw exige le format.`nChoisir le format dans l'onglet Écriture, puis relancer l'écriture.") -f "$ext"),(T 'Format requis'),'OK','Warning'); return
    }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { Start-ImageWrite; return }
    $hd = Get-HighDensityReason $img $fmt
    if ($hd) {
        # 12.7 : haute densite calibrable (hd) : courbe de la famille appliquee par le mode Auto si elle existe, profil
        # d origine sinon ; jamais de calibration automatique ni de test rapide avant l ecriture (bareme haute densite
        # provisoire). Haute densite non calibrable : comme en 12.6.
        $hf = Get-HdCalibFamily $img $fmt
        if (-not $hf) { Append-Log ((T "Image haute densité ({0}) : pas de calibration automatique, écriture avec le profil courant.") -f "$hd"); Start-ImageWrite; return }
        $heads = ($mode -eq 'slow')
        $kind = if ($heads) { (T 'par tête') } else { (T 'commune') }
        $nc = (Get-CalibCylinders $img $fmt).NCyl
        $nc = if ($null -eq $nc) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$nc)) }
        $st = Get-CalibState $hf $heads $nc
        $k0 = if ($heads) { "${hf}_h0" } else { $hf }
        $af = Get-HdAutoFields $hf $heads
        $pt = if ($af.P0 -eq $af.P1) { $af.P0 } else { (T "tête 0 : {0} ; tête 1 : {1}") -f "$($af.P0)", "$($af.P1)" }
        if ($st -eq 'ok') { Append-Log ((T "Image haute densité ({0}) : calibration {1} de la famille {2} du {3} appliquée par le mode Auto ; jamais de calibration automatique en haute densité.") -f "$hd", "$kind", (Get-CalibFamilyName $hf), "$($script:PrecompCurves[$k0].Date)") }
        else {
            # Ecriture lente sans courbes par tete, courbe commune presente : la courbe commune est ecrite pour les deux tetes
            $hcv = if ($heads) { Get-HdCommonCurve $hf } else { $null }
            $why = switch ($st) { 'stale' { (T 'courbes par tête antérieures à la courbe commune') } 'short' { (T "courbe plus courte que l'image de {0} cylindres") -f "$nc" } default { if ($hcv) { (T "aucune courbe par tête : courbe commune du {0} pour les deux têtes") -f "$($hcv.Date)" } else { (T 'aucune courbe') } } }
            Append-Log ((T "Image haute densité ({0}) : pas de calibration {1} à jour pour la famille {2} ({3}) : écriture avec le profil {4}, sans calibration automatique (jamais en haute densité). Pour calibrer : carte « Calibrer le lecteur » de l'Accueil, ou bouton « Calibrer » de l'onglet Écriture, avec une disquette haute densité sacrifiée.") -f "$hd", "$kind", (Get-CalibFamilyName $hf), "$why", "$pt")
        }
        if (Test-WriteLevelWanted $mode) { Write-LevelHdNote $hf $heads }    # 12.7 point 5 : pas de mesure en haute densite
        Start-ImageWrite; return
    }
    if ($chkWHard.Checked -or $chkWTG43.Checked) { Append-Log (T 'Secteurs durs ou lecteur 8 pouces (TG43) : pas de calibration automatique, écriture avec le profil courant.'); Start-ImageWrite; return }
    # Format gw explicite de la table non calibrable (FM, codage propre, secteurs durs, 360 tr/min, cellule hors plage :
    # Get-FormatCalibInfo, memes regles que la carte Calibration de l Accueil) : pas de calibration automatique ; GCR :
    # ligne « densite non etablie » ci-dessous, inchangee
    $fci = if ($explicit -and $script:GwFormats.Contains($fmt)) { Get-FormatCalibInfo $fmt } else { $null }
    if ($fci -and -not $fci.Cal -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)') { Append-Log ((T "Format {0} non calibrable ({1}) : pas de calibration automatique, écriture avec le profil courant.") -f "$fmt", "$($fci.Why)"); Start-ImageWrite; return }
    $ddKnown =(@('.adf', '.ipf', '.hfe') -contains $ext) -or ($explicit -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)')
    if (-not $ddKnown) { Append-Log ((T "Densité de l'image non établie ({0}, format déduit par gw) : pas de calibration automatique, écriture avec le profil courant.") -f "$ext"); Start-ImageWrite; return }
    $oor = Get-CellOutOfRange $img
    if ($null -ne $oor) { Append-Log ((T "Cellule de l'image hors des plages mesurables ({0} ns ; 900 à 1 100 ns en haute densité, 1 700 à 2 300 ns en double densité) : pas de calibration automatique, écriture avec le profil courant.") -f "$oor"); Start-ImageWrite; return }
    if (-not $script:ScpStatsOk) { Append-Log (T "Module d'analyse SCP indisponible : pas de calibration automatique, écriture avec le profil courant."); Start-ImageWrite; return }
    if ($NoCalib) {
        if ($LevelOnly) {
            # 12.7 point 5 (arbitrage 15) : mesure exclue quand l image ne recouvrirait pas tout le motif. 12.8 (D5) : avec la
            # liste au test rapide aussi (LevelOnly : restauration avec la case cochee ou la liste au test rapide) :
            # cylindres preserves (c= du champ Pistes), image a une seule face, step=
            $sk = Get-LevelWriteSkip $img $fmt $txtWTracks.Text
            if ($sk) { if ($sk.Why) { Append-Log $sk.Why }; Start-ImageWrite; return }
            Start-LevelBeforeWrite $mode -Restore; return
        }
        Start-ImageWrite; return
    }
    # Test rapide : niveau mesure sur la disquette a ecrire, sur la forme de la calibration complete du lecteur. 12.8 (D5) :
    # memes exclusions que le bouton ECRIRE (Get-LevelWriteSkip : une seule face, h= pose par Set-WritePreset ; c=, step=)
    if ($cmbWCalMode.SelectedIndex -eq 2) {
        $sk = Get-LevelWriteSkip $img $fmt $txtWTracks.Text
        if ($sk) { if ($sk.Why) { Append-Log $sk.Why }; Start-ImageWrite; return }
        Start-LevelBeforeWrite $mode; return
    }
    $fam = Get-ImageFamily $img
    $heads = ($mode -eq 'slow')
    # Cylindres de l image, comme la calibration les prendrait (Test-CalibImage) : courbe plus courte refaite ('short')
    $imgCyl = (Get-CalibCylinders $img $fmt).NCyl
    $imgCyl = if ($null -eq $imgCyl) { 80 } else { [math]::Max(2, [math]::Min(84, [int]$imgCyl)) }
    $state = Get-CalibState $fam $heads $imgCyl
    $kind = if ($heads) { (T 'par tête') } else { (T 'commune') }
    if ($state -eq 'ok') {
        # Courbe non convergee gardee apres un « Annuler » : reutilisee, mais signalee
        $nc = @(@($(if ($heads) { @("${fam}_h0", "${fam}_h1") } else { @($fam) })) | Where-Object { $script:PrecompCurves[$_] -and $script:PrecompCurves[$_].Converged -eq $false })
        $kc = @(@($(if ($heads) { @("${fam}_h0", "${fam}_h1") } else { @($fam) })) | Where-Object { $script:PrecompCurves[$_] -and (Get-CurveCalc $script:PrecompCurves[$_]) -ne (Get-CurveCalcRef $script:PrecompCurves[$_]) })
        if ($kc.Count -gt 0) { Append-Log ((T "Calibration {0} de la famille {1} faite avec le calcul {2} : écriture avec cette courbe, conservée à votre demande. Pour la refaire avec le calcul actuel, bouton « Calibrer » de l'onglet Écriture.") -f "$kind", (Get-CalibFamilyName $fam), (Get-CurveCalcText $script:PrecompCurves[$kc[0]] -Plain)) }
        if ($nc.Count -gt 0) { Append-Log ((T "Calibration {0} de la famille {1} non convergée ({2}) : écriture avec cette courbe. Pour la refaire, bouton « Calibrer » de l'onglet Écriture, de préférence en test fin.") -f "$kind", (Get-CalibFamilyName $fam), "$($script:PrecompCurves[$nc[0]].Date)") }
        # 12.7 point 5 : ecriture lente, case « Mesurer la disquette » : niveau et surface mesures sur la disquette a ecrire
        if (Test-WriteLevelWanted $mode) {
            # Arbitrage 15 : pas de mesure si l image ne recouvre pas tout le motif (une face, step= garde par Set-WritePreset)
            $sk = Get-LevelWriteSkip $img $fmt $txtWTracks.Text
            if ($sk) { if ($sk.Why) { Append-Log $sk.Why }; Start-ImageWrite; return }
            Start-LevelBeforeWrite $mode -Measure; return
        }
        Start-ImageWrite; return
    }
    switch ($state) {
        'content' { Append-Log ((T "La calibration {0} de la famille {1} a été mesurée sur le contenu d'une image, avant le motif de test : elle est refaite.") -f "$kind", (Get-CalibFamilyName $fam)) }
        'stale'   { Append-Log ((T "Courbes par tête de la famille {0} antérieures à la calibration commune : elles sont refaites.") -f (Get-CalibFamilyName $fam)) }
        'short'   {
            $sk = @(if ($heads) { "${fam}_h0", "${fam}_h1" } else { $fam }) | ForEach-Object { @($script:PrecompCurves[$_].Values).Count } | Measure-Object -Minimum
            Append-Log ((T "Calibration {0} de la famille {1} mesurée sur {2} cylindres seulement, image de {3} cylindres : elle est refaite.") -f "$kind", (Get-CalibFamilyName $fam), "$($sk.Minimum)", "$imgCyl")
        }
        default   { Append-Log ((T "Aucune calibration {0} pour la famille {1} : calibration automatique, puis écriture.") -f "$kind", (Get-CalibFamilyName $fam)) }
    }
    $script:AfterCalib = 'write'
    Start-PrecompCalib
    if (-not $script:Cal) { $script:AfterCalib = ''; Append-Log (T 'Écriture annulée : la calibration n''a pas été lancée.') }
}

function Test-WriteLevelWanted([string]$mode) {
    # 12.7 point 5 : mesure de la disquette avant une ecriture lente demandee (case chkWLevel) : ecriture lente, liste
    # « Calibration precomp » au test standard ou au test fin (au test rapide : chemins de la 12.6, inchanges) ; en
    # restauration, liste de l onglet Ecriture d avant la restauration (Restore.Saved, la restauration la met au test fin)
    if ($mode -ne 'slow' -or -not $chkWLevel.Checked) { return $false }
    $cm = if ($script:Restore -and $script:Restore.Saved) { [int]$script:Restore.Saved.CalMode } else { [int]$cmbWCalMode.SelectedIndex }
    return ($cm -ne 2)
}

function Get-WriteLevelKind([string]$img, [string]$fmt) {
    # 12.7 point 5 : image de l onglet Ecriture pour la mesure avant l ecriture lente, memes regles que Start-PresetWrite :
    # 'dd' (calibrable en double densite, calibration rapide possible), 'hd' (haute densite calibrable : pas de
    # calibration rapide, arbitrage 8), '' (non calibrable : flux, image secteur sans format, secteurs durs, TG43, format
    # non calibrable, densite non etablie, cellule hors plage, module d analyse SCP absent)
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    $explicit = ($fmt -and $fmt -ne '(auto)')
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) { return '' }
    if ((Test-NeedsFormat $img) -and -not $explicit) { return '' }
    if (Get-HighDensityReason $img $fmt) { if (Get-HdCalibFamily $img $fmt) { return 'hd' }; return '' }
    if ($chkWHard.Checked -or $chkWTG43.Checked) { return '' }
    $fci = if ($explicit -and $script:GwFormats.Contains($fmt)) { Get-FormatCalibInfo $fmt } else { $null }
    if ($fci -and -not $fci.Cal -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)') { return '' }
    if (-not ((@('.adf', '.ipf', '.hfe') -contains $ext) -or ($explicit -and $fmt -notmatch '^(commodore\.15[47]1|mac\.|apple2\.)'))) { return '' }
    if ($null -ne (Get-CellOutOfRange $img)) { return '' }
    if (-not $script:ScpStatsOk) { return '' }
    return 'dd'
}

function Write-LevelHdNote([string]$hf, [bool]$heads) {
    # 12.7 point 5 : pas de calibration rapide en haute densite (arbitrage 8) : ligne de journal, puis ecriture avec les
    # champs du mode Auto (Get-HdAutoFields : courbes par tete a jour en ecriture lente, sinon courbe commune, sinon
    # profil d origine haute densite)
    $cur = ($heads -and (Test-HeadCurvesCurrent $hf)) -or [bool](Get-HdCommonCurve $hf)
    if ($cur) { Append-Log (T 'Mesure de la disquette non disponible en haute densité : écriture avec la courbe HD du lecteur.') }
    else { Append-Log (T "Mesure de la disquette non disponible en haute densité : écriture avec le profil d'origine.") }
}

function Get-LevelWriteSkip([string]$img, [string]$fmt, [string]$ts) {
    # 12.7 point 5 (arbitrage 15) : mesure de la disquette avant l ecriture lente exclue quand l image ne recouvrirait pas
    # tout le motif. La mesure ecrit le motif sur 4 a 9 cylindres par tete, sur tout le disque et les deux tetes
    # (Start-LevelCalib : c=...:h=0-1), sans le champ Pistes. Renvoie $null (mesure possible) ou @{ Why } : ligne de
    # journal, vide quand Start-ImageWrite refusera l ecriture lente (son message s affiche alors avant toute ecriture du
    # motif). Cas, dans cet ordre :
    #  - champ Pistes avec c=, h= ou step= (step= : pistes physiques que la mesure, sans le pas, ne vise pas) ;
    #  - faces de l image inconnues avec « Effacer les pistes vides » : refus de Start-ImageWrite (memes regles, sans h=) ;
    #  - image a une seule face : faces de l image (Get-ImageTrackSet), sinon tetes du format gw d une image secteur.
    $ts = "$ts".Trim()
    if ($ts -and [regex]::IsMatch(":$ts", ':\s*(c|h|step)\s*=')) { return @{ Why = ((T "Mesure de la disquette avant l'écriture non faite : le champ Pistes (« {0} ») limite les pistes écrites ; le motif de test resterait sur des cylindres que l'image ne recouvre pas. Écriture sans mesure.") -f "$ts") } }
    $set = Get-ImageTrackSet $img
    if ($null -eq $set) {
        if ($chkWEraseEmpty.Checked) { return @{ Why = '' } }
        $fe = if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) { $script:GwFormats[$fmt] } else { $null }
        $hs = @(if ($fe -and [int]$fe.Heads -eq 1) { 0 } else { 0, 1 })
    } else { $hs = @(@($set.Keys) | ForEach-Object { [int](([string]$_ -split '\.')[1]) } | Sort-Object -Unique) }
    if ($hs.Count -eq 1) { return @{ Why = (T "Mesure de la disquette avant l'écriture non faite : image à une seule face ; le motif de test resterait sur l'autre face, que l'image n'écrit pas. Écriture sans mesure.") } }
    return $null
}

function Start-WriteTabWrite {
    # 12.7 point 5 : bouton ECRIRE de l onglet Ecriture. Ecriture lente avec la case « Mesurer la disquette avant
    # l ecriture lente » (Test-WriteLevelWanted), image calibrable en double densite, profil Auto, --precomp coche, image
    # qui recouvre tout le motif (Get-LevelWriteSkip) : niveau et etat de la surface mesures sur la disquette inseree
    # (Start-LevelBeforeWrite -Measure), puis ecriture. Haute densite : ligne de journal, puis ecriture. Sinon :
    # Start-ImageWrite, comme en 12.6 (jamais de calibration automatique depuis ce bouton en test standard ou fin).
    # 12.8 (D5) : liste au « Test rapide » : meme regle que la Bibliotheque, ecriture rapide ou lente : niveau mesure sur
    # la disquette a ecrire (Start-LevelBeforeWrite ; sans reference utilisable : ecriture refusee, jamais de calibration
    # complete depuis ce bouton, validation du 19/10), memes conditions (densite, profil Auto, --precomp, image qui
    # recouvre le motif)
    $img = $txtWFile.Text
    $mode = if ($chkWSlow.Checked) { 'slow' } else { 'fast' }
    $quick = ((Get-Setting 'calMode') -eq 'level')
    if (-not ($quick -or (Test-WriteLevelWanted $mode)) -or -not $img -or -not (Test-Path -LiteralPath $img)) { Start-ImageWrite; return }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    $k = Get-WriteLevelKind $img $cmbWFmt.Text
    if (-not $k) { Start-ImageWrite; return }
    $auto = ($cmbWProfile.SelectedIndex -eq 0)
    # Haute densite avant le profil : la mesure n y existe pas, quel que soit le profil ; ligne de la courbe ou du profil
    # d origine seulement quand le mode Auto les applique (profil Auto, --precomp coche)
    if ($k -eq 'hd') {
        if ($auto -and $chkWPrecomp.Checked) { Write-LevelHdNote (Get-HdCalibFamily $img $cmbWFmt.Text) ($mode -eq 'slow') }
        else { Append-Log (T 'Mesure de la disquette non disponible en haute densité.') }
        Start-ImageWrite; return
    }
    # Profil choisi a la main (Manuel, ou profil force) : la mesure decalerait la courbe calibree du profil Auto
    if (-not $auto) { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : profil précomp. « {0} » choisi ; la mesure ne se fait qu'avec le profil Auto.") -f "$($cmbWProfile.Text)"); Start-ImageWrite; return }
    # --precomp decoche : la mesure le cocherait (Set-LevelFields) ; ecriture sans precompensation, comme en 12.6
    if (-not $chkWPrecomp.Checked) { Append-Log (T "Mesure de la disquette avant l'écriture non faite : précompensation désactivée (case --precomp décochée) ; écriture sans précompensation."); Start-ImageWrite; return }
    $sk = Get-LevelWriteSkip $img $cmbWFmt.Text $txtWTracks.Text
    if ($sk) { if ($sk.Why) { Append-Log $sk.Why }; Start-ImageWrite; return }
    if ($quick) { Start-LevelBeforeWrite $mode; return }
    Start-LevelBeforeWrite 'slow' -Measure
}
