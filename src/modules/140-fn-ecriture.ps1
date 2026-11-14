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
    # 12.10 (relecture de la RC) : texte, etat actif et infobulle de la case de la mesure, etat de la liste « Mesure : » :
    # Update-WLevelUi, d apres l effet du lecteur cible sur l ecriture et la mesure que ferait Start-LevelBeforeWrite
    Update-WLevelUi
}

function Update-WLevelUi {
    # 12.10 (relecture de la RC) : case « Mesurer la disquette » (texte, etat actif, infobulle) et liste « Mesure : » (etat
    # actif), d apres les decisions de l ecriture : effet du lecteur cible sur l ecriture de l onglet (Get-TargetWriteInfo,
    # celui de Start-WriteTabWrite et de Start-PresetWrite, qui ne mesurent pas une ecriture pour un lecteur cible) et
    # mesure que ferait Start-LevelBeforeWrite (Get-LevelBeforeWriteKind : mesure complete d une ecriture lente au « Test
    # rapide »). Appels : Update-SlowUi, sortie d Update-PrecompForImage (image, format, profil, lecteur cible), case
    # --precomp (520). Lecteur cible sans effet (profil Manuel, --precomp decoche, flux ecrit tel quel, FM, GCR) : case
    # ordinaire, infobulle qui le dit (texte du journal de Start-ImageWrite) ; ecriture refusee pour le lecteur cible :
    # infobulle qui le dit. Avant : d apres le seul choix (Get-TargetDrive) : case verrouillee et courbe croisee annoncee
    # dans ces cas, texte du « Test rapide » sans exception pour le lecteur cible, rien de refait au changement de
    # profil, de case --precomp ou d image. Avant l affichage de la fenetre : aucun acces au fichier (racine reseau
    # possible), comme Update-CurveButton ; WLevelTip : infobulle d origine, gardee par 520
    if (-not $chkWLevel -or -not $chkWSlow -or -not $cmbWCalMode) { return }
    $on = [bool]$chkWSlow.Checked
    $quick = ($cmbWCalMode.SelectedIndex -eq 2)
    $p = if ($script:UiReady) { [string]$txtWFile.Text } else { '' }
    $tw = Get-TargetWriteInfo $p ([string]$cmbWFmt.Text) $on
    $ta = [bool]$tw.Applies
    # 12.8 (S3) : mesure complete choisie : duree de la case retiree (celle de la liste fait foi). 12.8.1 (spec-1281 § D.1) :
    # mesure sur l image a ecrire (defaut) : texte propre
    $lm = [string](Get-Setting 'levelBeforeWriteMode')
    $full = ($lm -eq 'complete')
    $lk = Get-LevelBeforeWriteKind $(if ($on) { 'slow' } else { 'fast' }) $false $false
    # 12.11 (lot LN-b) : un lecteur enregistre en jeu (lecteur qui ecrit ou lecteur cible) : texte court, sans les deux
    # lecteurs (avec un nom, le texte a deux lecteurs depasserait la case) ; l infobulle les nomme
    $chkWLevel.Text = if ($quick -and $ta -and $script:DriveReg.Count -gt 0 -and ((Test-DriveRegistered ([string]$tw.Tgt)) -or (Test-DriveRegistered ([string]$tw.Src)))) { (T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour un lecteur cible") } elseif ($quick -and $ta) { (T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (elle relirait avec le lecteur {1})") -f "$($tw.Tgt)", "$($tw.Src)" } elseif ($quick -and $lk -eq 'complete') { (T "Mesurer la disquette avant l'écriture : toujours en « Test rapide » (mesure complète de cette disquette en écriture lente)") } elseif ($quick) { (T "Mesurer la disquette avant l'écriture : toujours en « Test rapide » (niveau de précompensation et état de la surface)") } elseif ($lm -eq 'content') { (T "Mesurer la disquette avant l'écriture lente : précompensation mesurée sur l'image (environ 12 min)") } elseif ($full) { (T "Mesurer la disquette avant l'écriture lente : précompensation et état de la surface") } else { (T "Mesurer la disquette avant l'écriture lente : niveau de précompensation et état de la surface (environ 1 min)") }
    $chkWLevel.Enabled = ($on -and -not $quick -and -not $ta)
    # 12.8 (S3) : liste du mode de la mesure (rapide ou complete) : active en ecriture lente quand la disquette est mesuree
    # (case cochee, ou verrouillee au « Test rapide »)
    if ($cmbWLevelMode) { $cmbWLevelMode.Enabled = ($on -and $chkWLevel.Checked -and -not $ta); $lblWLevelMode.Enabled = $cmbWLevelMode.Enabled }
    if ($script:WLevelTip) {
        $tt = if ($ta -and $tw.Block) { (T "Mesure de la disquette non disponible pour un lecteur cible : elle relirait avec le lecteur {0}, pas avec le lecteur cible {1}. Écriture refusée : {2}") -f "$($tw.Src)", "$($tw.Tgt)", "$($tw.Block)" }
              elseif ($ta) { (T "Mesure de la disquette non disponible pour un lecteur cible : elle relirait avec le lecteur {0}, pas avec le lecteur cible {1}. L'image est écrite avec la courbe croisée telle quelle.") -f "$($tw.Src)", "$($tw.Tgt)" }
              elseif ($tw.Tgt -and $tw.Why) { ((T "Lecteur cible {0} sans effet sur cette écriture : {1}.") -f "$($tw.Tgt)", "$($tw.Why)") + "`n" + [string]$script:WLevelTip }
              else { [string]$script:WLevelTip }
        $tip.SetToolTip($chkWLevel, $tt)
    }
    # 12.11 (L10) : ligne « Ce qui va se passer » (Update-WritePlanUi, 145) : memes appels que la case de la mesure (image,
    # format, profil et courbes, ecriture lente, liste « Calibration precomp », case --precomp, lecteurs, reglages)
    if ($lblWPlan) { Update-WritePlanUi }
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

# --- Decisions de l ecriture (12.11, L10) -------------------------------
# Extraites de Start-ImageWrite sans changement de comportement : Start-ImageWrite les appelle, puis ecrit les memes lignes
# de journal et ouvre les memes fenetres, dans le meme ordre ; la ligne « Ce qui va se passer » (Get-WritePlan, 145) tire
# ses segments des memes fonctions. Aucune ligne de journal, aucune fenetre ici.

function Get-WriteHeads([string]$img, [string]$userTs, [bool]$slow, [bool]$eraseEmpty) {
    # Tetes ecrites : @{ Heads ; Err ; OneFace }. Ecriture rapide : 0 et 1 (gw ecrit les tetes du format). Ecriture lente :
    # tetes du champ Pistes (Get-TSpecHeads) ; sans h= explicite, faces de l image (gw part des pistes du format et h=1
    # ajouterait la tete 1 d un format simple face, D64, IMG simple face, IPF une face : avec --erase-empty, toute la face
    # 1 serait effacee). OneFace : image a une seule face (ligne de journal). Err : texte du refus (fenetre de
    # Start-ImageWrite) : aucune tete choisie par le champ Pistes, ou faces de l image inconnues avec « Effacer les pistes
    # vides »
    # 12.11 (L10, revue J) : Gw, tetes que gw ecrit, pour la ligne « Ce qui va se passer » : ecriture rapide, tetes du
    # champ Pistes (h=0 : tete 0 seule ; image a une face gardee apres une ecriture rapide de la Bibliotheque,
    # Get-FaceSafeWrite) ; Heads reste @(0, 1) en ecriture rapide (pistes de l effacement, Get-WriteEraseKeys)
    $r = @{ Heads = @(0, 1); Err = ''; OneFace = $false; Gw = @(0, 1) }
    if (-not $slow) { $r.Gw = Get-TSpecHeads $userTs; return $r }
    $heads = Get-TSpecHeads $userTs
    if ($heads.Count -eq 0) {
        $r.Heads = $heads; $r.Err = (T 'Écriture lente : le champ Pistes ne sélectionne ni la tête 0 ni la tête 1.'); return $r
    }
    if (-not [regex]::IsMatch(":$userTs", ':\s*h\s*=')) {
        $imgSet = Get-ImageTrackSet $img
        if ($null -ne $imgSet) {
            $present = @{}
            foreach ($k in @($imgSet.Keys)) { $present[[int](($k -split '\.')[1])] = $true }
            $heads = @(@(0, 1) | Where-Object { $present.ContainsKey($_) })
            if ($heads.Count -eq 1) { $r.OneFace = $true }
        } elseif ($eraseEmpty) {
            $r.Heads = $heads
            # 12.11 (L12a) : champ Pistes et case « Effacer les pistes vides » dans les options avancees (lot L9) : le refus le dit.
            # Relecture de L12a : emplacement en tete de la consigne, lisible dans les trois lignes de « Ce qui va se passer »
            $r.Err = (T "Écriture lente : nombre de faces de l'image inconnu ({0}).`nDans les options avancées, indiquer les têtes dans le champ Pistes (h=0-1 : double face, h=0 : simple face)`nou décocher « Effacer les pistes vides » : la tête 1 d'un format simple face serait effacée.") -f "$([System.IO.Path]::GetFileName($img))"
            return $r
        }
    }
    $r.Heads = $heads; $r.Gw = $heads
    return $r
}

function Get-WriteErasePlan([string]$img, [string]$fmt, [string]$userTs, [int[]]$heads, [bool]$on) {
    # Effacement avant l ecriture (case « Effacer avant d ecrire », $on) : @{ Mode ; Check ; EraseKeys ; Hd ; Note ; Fb }.
    # Hd : Test-ImageHighDensity ; Check : effacement des reecritures du controle (Get-EraseMode, selon la densite et les
    # options de lecteur seules). Mode : 'none' (case decochee), 'hfreq' (double densite : effacement haute frequence des
    # pistes EraseKeys, Get-WriteEraseKeys, memes elements du champ Pistes), 'pre' (--pre-erase : haute densite, secteurs
    # durs, TG43, --densel, ou pistes de l image inconnues). Note, ligne de journal du repli : 'keys' (pistes inconnues),
    # 'scp' (flux SCP de densite inconnue), 'fb' (options de lecteur, texte Fb de Get-EraseFallbackNote). Cle EraseKeys et
    # non Keys : $r.Keys rendrait les cles de la table
    $r = @{ Mode = 'none'; Check = ''; EraseKeys = $null; Hd = $false; Note = ''; Fb = '' }
    $r.Hd = Test-ImageHighDensity $img $fmt
    $r.Check = Get-EraseMode $r.Hd
    if ($on -and $r.Check -eq 'hfreq') {
        $r.EraseKeys = Get-WriteEraseKeys $img $fmt $userTs ([int[]]$heads)
        if ($null -eq $r.EraseKeys) { $r.Mode = 'pre'; $r.Note = 'keys' } else { $r.Mode = 'hfreq' }
    } elseif ($on) {
        $r.Mode = 'pre'
        if (Test-ScpDensityUnknown $img) { $r.Note = 'scp' }
        elseif (-not $r.Hd) { $fb = Get-EraseFallbackNote; if ($fb) { $r.Note = 'fb'; $r.Fb = $fb } }
    }
    return $r
}

function Get-WriteSpecPlan([string]$img, [string]$fmt, [bool]$slow, $ie) {
    # Profils --precomp transmis (champs de l onglet, case --precomp cochee) : @{ P0 ; P1 ; Flux ; NonMfm ; Nt }, avant la
    # mise a l echelle par le facteur ($ie : Get-ImageEncoding de l image).
    #  - 12.8 (S3-FLUX, decision 2 du 21/10/2026) : image flux ecrite sans --format : gw l ecrit telle quelle et n applique
    #    --precomp qu aux pistes MasterTrack (Test-RawFluxWrite) : --precomp n est plus transmis, ligne de journal (Flux).
    #  - 12.10 (lot 1, B1) : image FM, GCR ou a codage propre : la precompensation de gw (regle du MFM sans type=) et la
    #    courbe du lecteur ne valent que pour le MFM : --precomp n est plus transmis en profil Auto ou force (decision
    #    B-D1), ligne de journal (NonMfm) ; profil Manuel : champ transmis tel quel, avertissement s il ne precise pas
    #    type= (Nt : profils sans type=)
    $r = @{ P0 = $null; P1 = $null; Flux = $false; NonMfm = $false; Nt = @() }
    $pc0 = if ($chkWPrecomp.Checked -and $txtWPrecomp.Text.Trim()) { $txtWPrecomp.Text.Trim() } else { $null }
    $pc1 = if ($chkWPrecomp.Checked -and $txtWPrecomp1.Text.Trim()) { $txtWPrecomp1.Text.Trim() } else { $null }
    if (($pc0 -or $pc1) -and (Test-RawFluxWrite $img $fmt)) { $r.Flux = $true; $pc0 = $null; $pc1 = $null }
    if (($pc0 -or $pc1) -and $ie.NonMfm) {
        if ($cmbWProfile.SelectedIndex -eq 3) {
            $r.Nt = @(@($(if ($slow) { @($pc0, $pc1) } else { @($pc0) })) | Where-Object { $_ -and $_ -notmatch '(^|:)\s*type\s*=' } | Select-Object -Unique)
        } else { $r.NonMfm = $true; $pc0 = $null; $pc1 = $null }
    }
    $r.P0 = $pc0; $r.P1 = $pc1
    return $r
}

function Get-WriteHeadSpecs([string]$userTs, $p0, $p1) {
    # Profil de chaque tete logique d une ecriture lente (0, 1 -> profil ou $null) : les profils $p0 et $p1 sont ceux des
    # tetes physiques (calibration) ; hswap dans le champ Pistes : la tete logique h est ecrite par la tete 1 - h
    $swap = (Get-TSpecExtras $userTs) -match '(^|:)\s*hswap\s*(:|$)'
    $m = @{}
    foreach ($h in 0, 1) { $phys = if ($swap) { 1 - $h } else { $h }; $m[$h] = if ($phys -eq 0) { $p0 } else { $p1 } }
    return $m
}

function Get-WriteCheckPlan([string]$img, [string]$fmt, [bool]$slow, $heads, $headRaw, $p0Raw, [bool]$forced) {
    # Controle de toutes les pistes apres l ecriture : @{ Post ; Forced ; ByCurve ; Blocker }. Demande par la case
    # « Controler toutes les pistes » ou impose : $forced (courbe adaptee par la calibration rapide qui precede, drapeau
    # LevelPostForce) ou, 12.8 (FIX1C, constat 3, G1), profil ecrit qui est la courbe adaptee d une calibration rapide
    # (Test-LevelAdaptedSpec sur les profils non mis a l echelle : $headRaw par tete en ecriture lente, $p0Raw sinon ;
    # ByCurve, ligne de journal). Blocker : raison pour laquelle l analyse de flux ne s applique pas (Get-WriteCheckBlocker),
    # ecriture sans controle
    $r = @{ Post = $false; Forced = [bool]$forced; ByCurve = $false; Blocker = $null }
    if (-not $r.Forced) {
        $wsp = if ($slow) { @($heads | ForEach-Object { $headRaw[$_] }) } else { @($p0Raw) }
        if (Test-LevelAdaptedSpec ([string[]]@($wsp | Where-Object { $_ }))) { $r.Forced = $true; $r.ByCurve = $true }
    }
    $r.Post = ([bool]$chkWPostCheck.Checked -or $r.Forced)
    $r.Blocker = if ($r.Post) { Get-WriteCheckBlocker $img $fmt } else { $null }
    return $r
}

function Start-ImageWrite([switch]$NoWarmup) {
    # Ecriture de l image avec les parametres de l onglet (bouton ECRIRE, ecriture rapide ou lente, fin de calibration automatique)
    # Ecriture lente : prechauffage du lecteur avant la premiere ecriture (Start-WriteWarmup, chaine d ecriture prete) ;
    # NoWarmup : prechauffage passe a la demande de l utilisateur pendant la calibration qui precede
    # 12.8 (lot 1c, G1) : courbe adaptee a cette disquette par la calibration rapide qui precede : controle apres ecriture
    # impose, meme case decochee (drapeau lu une fois)
    $postForce = [bool]$script:LevelPostForce; $script:LevelPostForce = $false
    # 12.8.1 (spec-1281 § A.10) : facteur mesure sur l image par la mesure qui precede (Complete-ContentMeasure, 276), lu
    # une fois, comme LevelPostForce : il ne vaut que pour cette ecriture
    $wfNext = $script:WriteFactorNext; $script:WriteFactorNext = $null
    if (-not (Test-Path -LiteralPath $txtWFile.Text)) {
        [void](Show-AppMessage (T 'Fichier image introuvable.') (T 'Erreur') 'OK' 'Warning'); return
    }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    # 12.10 : ecriture pour un lecteur cible (liste « Lecteur cible » de l onglet) refusee sans courbe croisee de la famille
    # (Test-TargetWriteAllowed : journal et fenetre) ; $tgtDrive : lecteur cible dont les courbes croisees sont ecrites ('' :
    # meme lecteur, ou lecteur cible sans effet sur cette ecriture, Get-TargetWriteInfo : ligne de journal)
    if (-not (Test-TargetWriteAllowed $txtWFile.Text $cmbWFmt.Text ([bool]$chkWSlow.Checked))) { return }
    # 12.11 (lot LN-b) : avec des lecteurs enregistres, lecteur branche confirme s il y a lieu et ligne « Lecteur qui
    # ecrit » au journal (Confirm-DriveIdentity, 112) ; refus : rien n est ecrit
    if ($script:DriveReg.Count -gt 0 -and -not (Confirm-DriveIdentity -Write)) { return }
    $tw = Get-TargetWriteInfo $txtWFile.Text $cmbWFmt.Text ([bool]$chkWSlow.Checked)
    $tgtDrive = if ($tw.Applies) { [string]$tw.Tgt } else { '' }
    if ($tw.Tgt -and -not $tw.Applies -and $tw.Why) { Append-Log ((T "Lecteur cible {0} sans effet sur cette écriture : {1}.") -f "$($tw.Tgt)", "$($tw.Why)") }
    # Image flux a plusieurs tours : pistes dont le contenu change d un tour a l autre (bits faibles d une protection),
    # que gw ne reproduit pas (il n ecrit que le premier tour) : avertissement, confirmation, pas de reecriture au controle
    $script:ImageUnstable = $null; $script:ImageSrcWeak = $null; $script:ImageNoJudge = $null; $script:ImageScpFailed = $false; $script:ImageSrcOver = $null
    if (-not $script:Restore -and $script:ScpStatsOk -and [System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp') {
        # Analyse (quelques secondes pour un flux complet) mise en cache par fichier, taille et date. 12.8.2 (decision du
        # 27/10/2026) : $ov, pistes deja hors norme par leurs erreurs (Test-SrcOverErr), ni reecrites ni comptees au controle
        $uk = @{}; $ck = @{}; $nj = @{}; $ov = @{}; $failed = $false
        $fi = Get-Item -LiteralPath $txtWFile.Text
        $ckey = "$($fi.FullName)|$($fi.Length)|$($fi.LastWriteTimeUtc.Ticks)"
        if ($script:ScpWeakCache -and $script:ScpWeakCache.Key -eq $ckey -and $null -ne $script:ScpWeakCache.Over) { $uk = $script:ScpWeakCache.Weak.Clone(); $ck = $script:ScpWeakCache.Crit.Clone(); $nj = $script:ScpWeakCache.NoJudge.Clone(); $ov = $script:ScpWeakCache.Over.Clone(); $failed = [bool]$script:ScpWeakCache.Failed }
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
                    elseif (Test-SrcOverErr $m) { $ov[$key] = $true }
                    # Courte zone instable (raccord ou protection) ou stabilite non mesurable (un seul tour, densite) : une
                    # zone instable relue sur la copie n y sera pas jugee
                    elseif ($m.ShortUnstable -or $m.Blocks -eq 0) { $nj[$key] = $true }
                }
                $script:ScpWeakCache = @{ Key = $ckey; Weak = $uk.Clone(); Crit = $ck.Clone(); NoJudge = $nj.Clone(); Over = $ov.Clone(); Failed = $false }
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
        foreach ($k in @(@($uk.Keys) + @($ck.Keys) + @($ov.Keys))) { $ign[[string]$k] = $true }
        if ($ign.Count -gt 0) { $script:ImageUnstable = $ign }
        $script:ImageSrcWeak = $uk; $script:ImageNoJudge = $nj; $script:ImageScpFailed = $failed; $script:ImageSrcOver = $ov
    }
    $slow = $chkWSlow.Checked
    $userTs = $txtWTracks.Text.Trim()
    # 12.11 (L10) : tetes ecrites et refus decides par Get-WriteHeads, dont la ligne « Ce qui va se passer » tire aussi son
    # segment ; memes fenetres et ligne de journal, dans le meme ordre
    $wh = Get-WriteHeads $txtWFile.Text $userTs ([bool]$slow) ([bool]$chkWEraseEmpty.Checked)
    if ($wh.Err) { [void](Show-AppMessage $wh.Err (T 'Erreur') 'OK' 'Warning'); return }
    $heads = $wh.Heads
    if ($wh.OneFace) { Append-Log ((T "Écriture lente : image à une seule face, seule la tête {0} est écrite.") -f "$($heads[0])") }
    # 12.8.2 : case « Effacer avant d ecrire » (150, Get-EraseMode). Disquette double densite : effacement haute frequence
    # des pistes ecrites par l operation (Get-WriteEraseKeys, memes elements du champ Pistes), commandes gw erase --hfreq en
    # tete de la file WriteQueue, avant la premiere ecriture (apres le prechauffage de l ecriture lente), puis ecriture
    # sans --pre-erase ; pistes inconnues : pre-effacement, comme avant. Haute densite, flux SCP de densite inconnue,
    # secteurs durs, TG43, --densel : --pre-erase, comme en 12.8.1. Case decochee : aucun effacement.
    # Revue 12.8.2 : $em, effacement de l ecriture (repli 'pre' si ses pistes sont inconnues) ; $emCheck, effacement des
    # reecritures du controle apres ecriture (New-WriteCheck) : selon la densite et les options de lecteur seules, les
    # pistes faibles etant toujours connues. EraseLog : pistes effacees et ecrites par l operation (Read-GwOutput), pour
    # signaler celles qui restent effacees apres un arret (Fail-Restore). 12.11 (L10) : effacement decide par
    # Get-WriteErasePlan (Mode, Check, EraseKeys), dont la ligne « Ce qui va se passer » tire aussi son segment ; memes
    # lignes de journal, dans le meme ordre
    $ep = Get-WriteErasePlan $txtWFile.Text $cmbWFmt.Text $userTs ([int[]]$heads) ([bool]$chkWPreErase.Checked)
    $emCheck = $ep.Check
    $em = $ep.Mode
    $eraseKeys = $ep.EraseKeys; $eraseCmds = @(); $script:EraseLog = $null
    if ($em -eq 'hfreq') {
        $eraseCmds = New-HfreqEraseCmds $eraseKeys (Get-TSpecExtras $userTs)
        if (@($eraseCmds).Count -gt 0) { $script:EraseLog = @{ Owner = 'write'; Round = 0; Erased = @{}; Written = @{} } }
    } elseif ($ep.Note -eq 'keys') {
        Append-Log ((T "Effacement avant l'écriture : pistes de l'image {0} inconnues, l'effacement haute fréquence ne peut pas les viser : pré-effacement de chaque piste (--pre-erase), comme avant.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))")
    } elseif ($ep.Note -eq 'scp') {
        Append-Log ((T "Effacement avant l'écriture : densité du flux {0} inconnue (module d'analyse SCP indisponible) : pré-effacement de chaque piste (--pre-erase), comme avant.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))")
    } elseif ($ep.Note -eq 'fb') { Append-Log $ep.Fb }
    # $base : toutes les options sauf --tracks et l image (reprises telles quelles par les reecritures ciblees) ;
    # en ecriture lente, sans --precomp : chaque tete a sa commande et sa valeur
    $base = @('write') + (Get-CommonArgs)
    if ($chkWPreErase.Checked -and $em -ne 'hfreq') { $base += '--pre-erase' }
    if ($chkWEraseEmpty.Checked) { $base += '--erase-empty' }
    if ($chkWNoVerify.Checked)   { $base += '--no-verify' }
    $base += "--retries=$($numWRetries.Value)"
    # Mode Auto, image haute densite (format choisi apres l image, par exemple) : champs attendus de la branche haute densite
    # d Update-PrecompForImage (12.7 : famille hd calibrable : sa courbe, sinon le profil d origine haute densite ; haute
    # densite non calibrable : profil d origine de sa famille, jamais une courbe double densite) ; format revenu en double
    # densite apres coup : profil calibre de nouveau. 12.10 (lot 1, B1) : sauf image FM, GCR ou a codage propre
    # (Get-ImageEncoding), ecrite sans --precomp ci-dessous
    $ie = Get-ImageEncoding $txtWFile.Text $cmbWFmt.Text
    if ($cmbWProfile.SelectedIndex -eq 0 -and $chkWPrecomp.Checked -and -not $ie.NonMfm) {
        if (Get-HighDensityReason $txtWFile.Text $cmbWFmt.Text) {
            $hf = Get-HdCalibFamily $txtWFile.Text $cmbWFmt.Text
            if ($hf) { $af = Get-HdAutoFields $hf ([bool]$chkWSlow.Checked); $e0 = $af.P0; $e1 = $af.P1 }
            else { $e0 = if ((Get-ImageFamily $txtWFile.Text $cmbWFmt.Text) -eq 'long') { $script:PrecompLongDefault } else { $script:PrecompStdDefault }; $e1 = $e0 }
            if ($txtWPrecomp.Text.Trim() -ne $e0 -or $txtWPrecomp1.Text.Trim() -ne $e1) { Update-PrecompForImage $txtWFile.Text }
        } elseif ($script:WProfileHd) { Update-PrecompForImage $txtWFile.Text }
    }
    # 12.10 : ecriture pour un lecteur cible : champs --precomp attendus, ceux des courbes croisees (Set-PrecompFields : par
    # tete en ecriture lente si elles sont a jour, sinon la commune pour les deux tetes) ; champs differents (courbe adaptee
    # d une calibration rapide, champ modifie a la main, case « Ecriture lente » changee depuis) : profil de l image recalcule
    $tc = @($tw.Curves)
    if ($tgtDrive -and $tc.Count -gt 0) {
        if ($txtWPrecomp.Text.Trim() -ne [string]$tc[0].Spec -or ($slow -and $txtWPrecomp1.Text.Trim() -ne [string]$tc[$tc.Count - 1].Spec)) { Update-PrecompForImage $txtWFile.Text }
    }
    # 12.11 (L10) : profils --precomp transmis decides par Get-WriteSpecPlan (flux ecrit tel quel, FM, GCR, profil Manuel),
    # dont la ligne « Ce qui va se passer » tire aussi le controle impose ; memes lignes de journal, dans le meme ordre
    $sp = Get-WriteSpecPlan $txtWFile.Text $cmbWFmt.Text ([bool]$slow) $ie
    if ($sp.Flux) { Append-Log ((T "Image flux {0} écrite telle quelle (sans --format) : gw n'applique pas la précompensation à un flux, --precomp n'est pas transmis.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))") }
    $nt = @($sp.Nt)
    if ($nt.Count -gt 0) { Append-Log ((T "Profil manuel sur une image en codage {0} : --precomp {1} est transmis tel quel ; sans type=fm ou type=gcr, gw y applique la règle du MFM.") -f "$($ie.Name)", "$($nt -join ' / ')") }
    if ($sp.NonMfm) { Append-Log ((T "Image {0} en codage {1} ({2}) : écrite sans précompensation, --precomp n'est pas transmis. La précompensation de gw et la courbe du lecteur ne valent que pour le MFM.") -f "$([System.IO.Path]::GetFileName($txtWFile.Text))", "$($ie.Name)", "$($ie.Src)") }
    $pc0 = $sp.P0; $pc1 = $sp.P1
    # 12.8.1 (spec-1281 § A.10, decisions du 25/10/2026) : facteur de precompensation de cette ecriture
    # (Get-WriteFactorPlan : k mesure sur l image, sinon k du lecteur ; 12.10 : facteur 1 pour un lecteur cible), applique aux
    # profils des champs --precomp par ConvertTo-ScaledSpec (facteur 1 : profils identiques a l octet a ceux de la v12.8) ;
    # ecriture lente : champs des tetes physiques, donc avant le hswap ; rapide : facteur moyen des deux tetes sur le profil
    # commun. Lignes de journal avant « Ecriture lente : ... » (format inchange, profils mis a l echelle). Profils non mis a
    # l echelle gardes pour Test-LevelAdaptedSpec (compares aux enregistrements de la calibration rapide)
    $pc0Raw = $pc0; $pc1Raw = $pc1
    $wf = Get-WriteFactorPlan $txtWFile.Text $cmbWFmt.Text $slow $wfNext
    if ($wf.Apply) {
        if ($slow) {
            if ($pc0) { $pc0 = ConvertTo-ScaledSpec $pc0 $wf.F0 $wf.Hard }
            if ($pc1) { $pc1 = ConvertTo-ScaledSpec $pc1 $wf.F1 $wf.Hard }
        } elseif ($pc0) { $pc0 = ConvertTo-ScaledSpec $pc0 $wf.FMean $wf.Hard }
    }
    foreach ($wl in @($wf.Lines)) { Append-Log $wl }
    if (-not $slow -and $pc0) { $base += '--precomp'; $base += $pc0 }
    $base += Get-WriteFormatArgs
    $a = $base
    if ($userTs)      { $a += "--tracks=$userTs" }
    $a += "`"$($txtWFile.Text)`""
    $headPc = $null; $headPcRaw = $null
    $script:WriteQueue.Clear()
    # 12.8.2 : effacement haute frequence en tete de la file (Invoke-WriteQueueNext), avant toute ecriture. Revue 12.8.2 :
    # ecriture lente sur une disquette identique a l original (restauration, « Ecraser quand meme ») : chaque tete est
    # effacee juste avant son ecriture (un arret de gw n expose que la tete en cours ; Fail-Restore cite les pistes restees
    # effacees)
    $perHead = ($slow -and $script:Restore -and $script:Restore.OnOriginal -and @($eraseCmds).Count -gt 0)
    if (-not $perHead) { foreach ($ec in $eraseCmds) { $script:WriteQueue.Enqueue([string[]]$ec) } }
    if (@($eraseCmds).Count -gt 0) {
        Append-Log ((T "Effacement haute fréquence avant l'écriture (disquette double densité, lecteur {0}) : pistes {1}, puis écriture sans pré-effacement.") -f "$($cmbDrive.Text)", (Format-EraseTracks $eraseCmds))
        if ($perHead) { Append-Log (T "Écriture sur une disquette identique à l'original : chaque tête est effacée juste avant son écriture.") }
    }
    if ($slow) {
        # Ecriture lente : tete 0 sur tout le disque, puis tete 1 (gw applique --precomp par cylindre seulement).
        # Les champs correspondent aux tetes physiques (calibration) ; hswap : la tete logique h est ecrite par la tete 1 - h
        # (12.11, L10 : Get-WriteHeadSpecs)
        $headPc = Get-WriteHeadSpecs $userTs $pc0 $pc1; $headPcRaw = Get-WriteHeadSpecs $userTs $pc0Raw $pc1Raw
        foreach ($h in $heads) {
            if ($perHead) {
                $hk = @(@($eraseKeys) | Where-Object { ([string]$_ -split '\.')[1] -eq "$h" })
                foreach ($ec in (New-HfreqEraseCmds $hk (Get-TSpecExtras $userTs))) { $script:WriteQueue.Enqueue([string[]]$ec) }
            }
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
    # est celle de Complete-LevelCalib, ecrite ici quand le drapeau n a pas ete pose. 12.11 (L10) : controle decide par
    # Get-WriteCheckPlan (Post, ByCurve, Blocker), dont la ligne « Ce qui va se passer » tire aussi son segment
    $cp = Get-WriteCheckPlan $txtWFile.Text $cmbWFmt.Text ([bool]$slow) $heads $headPcRaw $pc0Raw ([bool]$postForce)
    if ($cp.ByCurve) { $postForce = $true; Append-Log (T 'Contrôle après écriture imposé : courbe adaptée à cette disquette.') }
    $post = [bool]$cp.Post
    $blocker = $cp.Blocker
    if ($blocker) {
        Append-Log ((T "Contrôle de toutes les pistes non applicable ({0}) : l'analyse de flux est calibrée pour le MFM double densité. Écriture sans contrôle.") -f "$blocker")
    }
    # 12.11 (L11) : barre de l onglet pendant l ecriture et son controle (Start-WriteProgress, 160) : plan des commandes de
    # l ecriture (file : effacements, ecritures par tete ; ou ecriture rapide), pose avant le lancement de la premiere ;
    # affichage seulement, file et commandes inchangees
    $wpCmds = @($script:WriteQueue.ToArray()); if (-not $slow) { $wpCmds += ,$a }
    Start-WriteProgress $wpCmds ([bool]($post -and -not $blocker))
    if ($post -and -not $blocker) {
        # Options de lecteur reprises par les relectures de controle (gw read les accepte toutes)
        $readOpts = @(Get-DriveReadArgs)
        New-WriteCheck $base $txtWFile.Text $userTs ([int]$numWRepair.Value) $readOpts $headPc $emCheck
        # 12.10 : ecriture pour un lecteur cible : le controle relit avec le lecteur qui a ecrit (pas de relecture par la
        # cible) ; reecritures gardees (les pistes faibles pour la source le sont tres probablement pour la cible) ; verdict
        # complete par Complete-WriteCheck (170)
        if ($tgtDrive) { $script:Rep.Target = $tgtDrive; $script:Rep.TargetSrc = [string]$cmbDrive.Text; Append-Log ((T "Contrôle après écriture pour le lecteur cible {0} : relecture par le lecteur {1}, pas par le lecteur cible ; les pistes faibles pour le lecteur {1} sont réécrites (elles le sont très probablement aussi pour le lecteur {0}).") -f "$tgtDrive", "$($cmbDrive.Text)") }
        if ($script:ImageUnstable) { $script:Rep.Ignore = $script:ImageUnstable }
        $script:Rep.SrcWeak = $script:ImageSrcWeak; $script:Rep.NoJudge = $script:ImageNoJudge; $script:Rep.SrcOver = $script:ImageSrcOver
        # SCP non analyse (module absent, restauration : voir Start-RestoreWrite) ou analyse en echec : rien n est juge
        if ([System.IO.Path]::GetExtension($txtWFile.Text).ToLower() -eq '.scp' -and ($script:ImageScpFailed -or ((-not $script:Restore) -and $null -eq $script:ImageNoJudge))) { $script:Rep.UnstDefect = $false }
        $script:Chain.Clear()
        # File WriteQueue : effacement haute frequence (12.8.2), puis en ecriture lente une ecriture par tete
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        if (-not $slow) { $script:WriteArgs = $a; $script:Chain.Enqueue({ Start-Gw $script:WriteArgs }) }
        $script:Chain.Enqueue({ Start-WriteCheck })
        if ($slow) { Start-WriteWarmup $warmTs ([bool]$NoWarmup) } else { Invoke-NextChainStep }
    } elseif ($slow) {
        $script:Chain.Clear()
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        if ($script:Restore) { $script:Chain.Enqueue({ Invoke-RestoreNext }) }   # restauration sans controle complet
        Start-WriteWarmup $warmTs ([bool]$NoWarmup)
    } elseif ($script:WriteQueue.Count -gt 0) {
        # 12.8.2 : ecriture rapide precedee de l effacement haute frequence (file WriteQueue), puis la restauration ;
        # etapes deja en attente gardees apres l ecriture, comme sans effacement
        $rest = if ($script:Restore) { @() } else { @($script:Chain.ToArray()) }
        $script:Chain.Clear()
        for ($i = 0; $i -lt $script:WriteQueue.Count; $i++) { $script:Chain.Enqueue({ Invoke-WriteQueueNext }) }
        $script:WriteArgs = $a; $script:Chain.Enqueue({ Start-Gw $script:WriteArgs })
        if ($script:Restore) { $script:Chain.Enqueue({ Invoke-RestoreNext }) }
        foreach ($s in $rest) { $script:Chain.Enqueue($s) }
        Invoke-NextChainStep
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
    # Parametres d une ecriture rapide ou lente : image entiere, profil Auto, effacement avant l ecriture (case « Effacer
    # avant d ecrire » ; 12.8.2 : haute frequence en double densite, pre-effacement en haute densite), effacement des
    # pistes vides, verification gw, 10 essais, precomp transmise. Rapide : une commande pour les deux tetes, sans controle complet.
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
    # 12.10 (relecture de la RC) : format pose sous la garde des liaisons : gestionnaires de la liste (520) sans effet,
    # l appelant recalcule le profil (Start-LibWrite, Start-RestoreWrite : Update-PrecompForImage) : plus de calcul du au
    # format (avant, la meme image reprise avec un autre format etait calculee une fois de plus : ligne « Profil precomp » en
    # double au journal) ; le profil et la case « Ecriture lente », poses plus bas hors de la garde, gardent leurs liaisons
    # (un calcul chacun quand ils changent, comme en 12.9)
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        if ($path -match '\.adf$') { $cmbWFmt.SelectedItem = $(if (Test-AdfHd $path) { 'amiga.amigados_hd' } else { 'amiga.amigados' }) }
        elseif (-not ($same -and (Test-NeedsFormat $path))) { $cmbWFmt.SelectedIndex = 0 }
    } finally { $script:SettingSync = $sv }
    $cmbWProfile.SelectedIndex = 0
    # Faces de l image : effacement des pistes vides et h= d une image a une face (Get-FaceSafeWrite). 12.10 (lot 1,
    # E9-image, constat I-3) : calcul sorti dans Get-ImageFaces et Get-FaceSafeWrite, repris pour l image gardee a la fin
    # d une operation de la Bibliotheque (Merge-LibKeepState)
    $extras = Get-TSpecExtras $txtWTracks.Text
    $fc = Get-ImageFaces $path
    $fw = Get-FaceSafeWrite $fc ($mode -eq 'slow') $extras $true
    $chkWPreErase.Checked = $true; $chkWEraseEmpty.Checked = $fw.Empty; $chkWNoVerify.Checked = $false
    $numWRetries.Value = 10; $chkWPrecomp.Checked = $true
    $txtWTracks.Text = $fw.Tracks
    $chkWSlow.Checked = ($mode -eq 'slow')
    if ($mode -eq 'slow') {
        $chkWPostCheck.Checked = $true; $numWRepair.Value = 3
        Append-Log (T "Écriture lente : image entière, profil Auto, effacement avant l'écriture (haute fréquence en double densité, pré-effacement en haute densité), effacement des pistes vides, vérification gw, 10 essais, tête 0 puis tête 1, contrôle de toutes les pistes, 3 passes de réécriture.")
    } else {
        $chkWPostCheck.Checked = $false
        Append-Log (T "Écriture rapide : image entière, profil Auto, effacement avant l'écriture (haute fréquence en double densité, pré-effacement en haute densité), effacement des pistes vides, vérification gw, 10 essais, les deux têtes ensemble, sans contrôle complet des pistes.")
        if ($null -ne $fw.Head) { Append-Log ((T "Image à une seule face : seule la tête {0} est écrite (h={0} dans Pistes).") -f "$($fw.Head)") }
    }
    if ($fc.Unknown) { Append-Log (T "Nombre de faces de l'image inconnu : effacement des pistes vides désactivé (seules les pistes présentes dans l'image sont écrites).") }
    if ($extras) { Append-Log ((T "Champ Pistes : éléments de lecteur conservés ({0}).") -f $extras.TrimStart(':')) }
}

function Get-FaceSafeWrite($faces, [bool]$slow, [string]$extras, [bool]$empty) {
    # 12.10 (lot 1, E9-image, constat I-3) : reglages de securite des faces d une image (faces : Get-ImageFaces), communs a
    # Set-WritePreset et a l image gardee apres la Bibliotheque (Merge-LibKeepState). Faces inconnues -> pas d effacement
    # des pistes vides, qui effacerait la face 1 d une image simple face (gw n ecrit alors que les pistes presentes) ; une
    # seule face en ecriture rapide -> h= de cette face dans Pistes (en lente, Start-ImageWrite n ecrit deja que les faces
    # de l image). extras : elements de lecteur du champ Pistes (Get-TSpecExtras) ; empty : effacement voulu sinon.
    # Renvoie @{ Tracks : champ Pistes ; Empty : effacement des pistes vides ; Head : tete de h= pose, $null sinon }
    $r = @{ Tracks = "$extras".TrimStart(':'); Empty = ($empty -and -not $faces.Unknown); Head = $null }
    if (-not $slow -and $null -ne $faces.OneHead) { $r.Head = $faces.OneHead; $r.Tracks = "h=$($faces.OneHead)" + "$extras" }
    return $r
}

# --- Surcharge d operation (12.8, D4) -------------------------------------------
# Une ecriture depuis la Bibliotheque applique son prereglage aux controles de l onglet Ecriture (Set-WritePreset), le
# temps de l operation seulement : l etat d avant (Save-WriteTabState) est ecrit a sa place dans la configuration
# (Save-Config, Set-OpOverrideConfig), puis retabli quand plus rien ne tourne (Update-OpOverride, minuteur principal).
# 12.7 : le prereglage devenait la configuration de l onglet Ecriture. 12.8, lot 2 : la restauration passe aussi par
# cette surcharge (Kind 'restore', Started jamais pose : seule Close-Restore la termine). 12.10 (lot 1, E9-image,
# decisions E9-1 a E9-3) : operation de la Bibliotheque lancee : l onglet garde l image de l operation (Save-LibKeepImg,
# Merge-LibKeepState), dans l onglet comme dans la configuration ; le reste du prereglage reste temporaire.
# 12.10 (lot 1, R1-corrections-revue, constat d) : image gardee seulement si elle a ete ecrite (Written, pose par Start-Gw
# au premier gw write de l image, Set-LibImageWritten) : un arret pendant la calibration, la mesure ou le prechauffage
# retablit tout (E9-2). Constat e : Start-LibWrite refuse une seconde operation tant que la surcharge est active.

function Enter-OpOverride([string]$kind) {
    # Surcharge deja active (operation precedente non terminee) : l etat d origine est garde
    # Finalisation 12.10 : Refused, ecriture pour un lecteur cible refusee pendant l operation (Test-TargetWriteAllowed),
    # pour l avis de fin de la Bibliotheque (Show-LibEndNotice)
    if ($script:OpOverride) { $script:OpOverride.Stopped = $false; $script:OpOverride.Refused = $false; return }
    $script:OpOverride = @{ Kind = $kind; Saved = (Save-WriteTabState); Started = $false; Written = $false; Stopped = $false; Refused = $false }
}

function Exit-OpOverride([switch]$Keep) {
    # Fin de la surcharge : onglet Ecriture retabli et configuration enregistree. Keep : prereglage garde dans l onglet,
    # sans rien retablir (image secteur dont le format est a choisir dans l onglet Ecriture, comme en 12.7)
    $o = $script:OpOverride
    if (-not $o) { return }
    $script:OpOverride = $null
    if ($Keep) { return }
    $opImg = $txtWFile.Text                                   # image de l operation, avant le retour de celle de l onglet
    # 12.10 (lot 1, E9-image) : Bibliotheque : image de l operation gardee si elle a ete ecrite (Merge-LibKeepState ;
    # R1, constat d : Written, et non plus Started)
    $m = if ($o.Kind -eq 'library') { Merge-LibKeepState $o.Saved $o.KeepImg ([bool]$o.Written) } else { $null }
    Restore-WriteTabState $(if ($m) { $m.State } else { $o.Saved })
    # Restauration (12.8, lot 2) : reglages retablis sans ligne de journal, comme en 12.7
    if ($o.Kind -eq 'library') { Show-LibEndNotice $o $opImg $m }
    [void](Save-Config)
}

function Save-LibKeepImg {
    # 12.10 (lot 1, E9-image) : apres Set-WritePreset (Start-LibWrite) : image de l operation de la Bibliotheque, son format,
    # sa source et ses faces (Get-ImageFaces), memorises dans la surcharge pour Merge-LibKeepState
    $o = $script:OpOverride
    if (-not $o -or $o.Kind -ne 'library') { return }
    # 12.10 (lot 1, R1-corrections-revue, constat b) : entree d une archive ZIP (source « archive|entree ») : fichier extrait
    # dans TempDir sous le nom de l entree, qu une autre archive peut remplacer : Archive, image jamais gardee (tout
    # retabli, comme en 12.8), dit par l avis de fin (Show-LibEndNotice)
    $o.KeepImg = @{ File = $txtWFile.Text; Fmt = $cmbWFmt.Text; Source = $script:PresetSource; Faces = (Get-ImageFaces $txtWFile.Text)
                    Archive = "$($script:PresetSource)".Contains('|') }
}

function Set-LibImageWritten([string[]]$gwArgs) {
    # 12.10 (lot 1, R1-corrections-revue, constat d) : Start-Gw, avant le lancement : commande gw write de l image memorisee
    # de l operation de la Bibliotheque (Save-LibKeepImg ; le motif de calibration et la mesure s ecrivent depuis TempDir)
    # -> Written. Renvoie vrai si cette commande l a pose, pour le retirer si gw ne demarre pas
    $o = $script:OpOverride
    if (-not $o -or $o.Kind -ne 'library' -or $o.Written -or -not $o.KeepImg) { return $false }
    if ($gwArgs.Count -eq 0 -or $gwArgs[0] -ne 'write' -or $gwArgs -notcontains "`"$($o.KeepImg.File)`"") { return $false }
    $o.Written = $true
    return $true
}

function Merge-LibKeepState($saved, $keep, [bool]$written) {
    # 12.10 (lot 1, E9-image, decisions E9-1 (a) et E9-2) : etat de l onglet Ecriture a la fin d une operation de la
    # Bibliotheque (Restore-WriteTabState), et a sa place dans la configuration pendant l operation (E9-3). Image ecrite
    # (written : R1, constat d) et memorisee (keep, Save-LibKeepImg) : image, format et source de l operation gardes ; champ
    # Pistes de l onglet d avant sans c= ni h=, qui visaient l image precedente ; le reste retabli de l onglet d avant (saved).
    # Constat I-3 : effacement des pistes vides et h= d une image a une face recalcules pour l image gardee, dans le mode
    # de l onglet d avant (Get-FaceSafeWrite, comme Set-WritePreset) : sinon ECRIRE pourrait effacer la face 1. Non ecrite
    # (refus, calibration annulee ou arretee) : tout retabli. R1, constat b : entree d archive ZIP (keep.Archive) : tout
    # retabli, Archive vrai si l image a ete ecrite. R1, constat c : l onglet d avant avait deja cette image et cette source :
    # son champ Pistes est garde (c= et h= visent la meme image), securite des faces seule (h= ajoute s il n en a pas).
    # Renvoie @{ State : etat a retablir ; Kept : image gardee ; Cut : c= et h= retires du champ d avant ; Head : tete de
    # h= pose, $null sinon ; EmptyOff : effacement des pistes vides de l onglet d avant desactive (faces inconnues) ;
    # Archive : image ecrite d une archive ZIP, non gardee }
    $r = @{ State = $saved; Kept = $false; Cut = ''; Head = $null; EmptyOff = $false; Archive = $false }
    if (-not $written -or -not $keep -or -not $saved) { return $r }
    if ($keep.Archive) { $r.Archive = $true; return $r }
    $s = $saved.Clone()
    $s.File = $keep.File; $s.Fmt = $keep.Fmt; $s.Source = $keep.Source
    # Meme image : meme fichier et meme source (source vide : onglet relu de la configuration, qui ne garde pas la source ;
    # une entree d archive est deja ecartee ci-dessus)
    # 12.10 (lot 1, revue2, R-4) : source comparee seulement si celle de l onglet d avant designe une entree d archive ou
    # une restauration (« | ») : hors archive, la source est le chemin du fichier (Resolve-LibSelection, Parcourir), et
    # une saisie a la main du chemin ne la met pas a jour. Entree d archive ou restauration dans l onglet d avant : pas la
    # meme image (keep.Source n a pas de « | » ici)
    $same = ("$($saved.File)" -eq "$($keep.File)" -and -not "$($saved.Source)".Contains('|'))
    if ($same) {
        $t = "$($saved.Tracks)"
        $hasH = [regex]::IsMatch(":$t", ':\s*h\s*=')
        $fw = Get-FaceSafeWrite $keep.Faces ([bool]$saved.Slow) '' ([bool]$saved.Empty)
        if ($null -ne $fw.Head -and -not $hasH) { $t = if ($t.Trim()) { "h=$($fw.Head):$($t.Trim())" } else { "h=$($fw.Head)" } }
        else { $fw.Head = $null }
        # 12.10 (lot 1, revue2, R-3) : h= explicite garde dans le champ Pistes : gw n ecrit et n efface que les pistes des
        # faces choisies, l effacement des pistes vides de l onglet d avant est garde meme si les faces sont inconnues
        if ($hasH) { $fw.Empty = [bool]$saved.Empty }
        $s.Tracks = $t; $s.Empty = $fw.Empty
    } else {
        $fw = Get-FaceSafeWrite $keep.Faces ([bool]$saved.Slow) (Get-TSpecExtras "$($saved.Tracks)") ([bool]$saved.Empty)
        $s.Tracks = $fw.Tracks; $s.Empty = $fw.Empty
        $r.Cut = Get-TSpecCH "$($saved.Tracks)"
    }
    $r.State = $s; $r.Kept = $true; $r.Head = $fw.Head
    $r.EmptyOff = ([bool]$saved.Empty -and -not $fw.Empty)
    return $r
}

function Get-WriteModeText($s) {
    # 12.10 (lot 1, E9-image) : mode d ecriture d un etat de l onglet Ecriture (Save-WriteTabState), pour l avis de fin de
    # la Bibliotheque
    $t = if ($s.Slow) { (T 'écriture lente') } else { (T 'écriture rapide') }
    if ($s.Post) { $t += (T ', contrôle de toutes les pistes') }
    return $t
}

function Show-LibEndNotice($o, [string]$opImg, $m = $null) {
    # 12.8 (FIX-PISTES, essai du 21/10/2026) : fin d une operation de la Bibliotheque, terminee ou arretee (Stopped : bouton
    # Arreter) : l onglet Ecriture a repris SON image et SON champ Pistes (D4). Ligne de journal et avis a cote du bouton
    # ECRIRE (Set-WTabNotice), qui nomment l image retablie ; apres un arret, comment reprendre : depuis la Bibliotheque,
    # le bouton ECRIRE ecrivant l image de l onglet
    # 12.10 (lot 1, E9-image) : operation lancee (m.Kept, Merge-LibKeepState) : l onglet garde l image de l operation, avec
    # ses autres reglages ; lignes de journal du retrait de c= et h= et de la securite des faces (constat I-3), reprises
    # dans l avis. Non lancee : textes de la 12.8 (tout retabli)
    if ($m -and $m.Kept) {
        $k = $m.State
        $img = if ("$($k.File)".Trim()) { [System.IO.Path]::GetFileName("$($k.File)") } else { (T '(aucune image)') }
        $md = Get-WriteModeText $k
        $fx = ''
        if ($null -ne $m.Head) { $fx += (T " ; h={0} dans le champ Pistes (image à une seule face)") -f "$($m.Head)" }
        if ($m.EmptyOff) { $fx += (T " ; effacement des pistes vides désactivé (faces de l'image inconnues)") }
        if ($o.Stopped) {
            Append-Log ((T "Bibliothèque : opération arrêtée. L'onglet Écriture garde l'image de l'opération, {0} ; ses autres réglages sont rétablis ({1}) et le préréglage de la Bibliothèque n'est pas enregistré. L'écriture de {0} n'est peut-être pas complète : pour la reprendre avec le préréglage de la Bibliothèque, relancez-la depuis la Bibliothèque ; le bouton ÉCRIRE LA DISQUETTE l'écrirait avec les réglages de l'onglet Écriture.") -f "$img", "$md")
        } else {
            Append-Log ((T "Bibliothèque : opération terminée. L'onglet Écriture garde l'image de l'opération, {0} ; ses autres réglages sont rétablis ({1}) et le préréglage de la Bibliothèque n'est pas enregistré.") -f "$img", "$md")
        }
        if ($m.Cut) {
            # Image precedente nommee si l onglet en avait une
            if ("$($o.Saved.File)".Trim()) { Append-Log ((T "Champ Pistes : « {0} » retiré, il visait l'image précédente ({1}).") -f "$($m.Cut)", "$([System.IO.Path]::GetFileName("$($o.Saved.File)"))") }
            else { Append-Log ((T "Champ Pistes : « {0} » retiré, il visait l'image précédente.") -f "$($m.Cut)") }
        }
        if ($null -ne $m.Head) { Append-Log ((T "Image {0} à une seule face : h={1} placé dans le champ Pistes, le bouton ÉCRIRE LA DISQUETTE n'écrit que la tête {1}.") -f "$img", "$($m.Head)") }
        if ($m.EmptyOff) { Append-Log ((T "Nombre de faces de {0} inconnu : effacement des pistes vides désactivé dans l'onglet Écriture (il effacerait la face 1 d'une image à une seule face).") -f "$img") }
        if ($o.Stopped) {
            Set-WTabNotice ((T "Bibliothèque arrêtée : l'image {0} n'est peut-être pas entièrement écrite ; pour reprendre, relancez l'écriture depuis la Bibliothèque. Onglet Écriture : vos réglages d'écriture ({1}){2}.") -f "$img", "$md", "$fx")
        } else {
            Set-WTabNotice ((T "Bibliothèque terminée : l'image {0} reste dans l'onglet Écriture, avec vos réglages d'écriture ({1}){2}.") -f "$img", "$md", "$fx")
        }
        return
    }
    $s = $o.Saved
    $tab = if ("$($s.File)".Trim()) { [System.IO.Path]::GetFileName("$($s.File)") } else { (T '(aucune image)') }
    $trk = if ("$($s.Tracks)".Trim()) { (T ", champ Pistes « {0} »") -f "$("$($s.Tracks)".Trim())" } else { '' }
    $op = if ("$opImg".Trim()) { [System.IO.Path]::GetFileName("$opImg") } else { (T '(aucune image)') }
    # 12.10 (lot 1, R1-corrections-revue, constat b) : image ecrite d une archive ZIP, non gardee (Merge-LibKeepState) :
    # ligne de journal en plus, avis qui le dit. Finalisation 12.10 : ecriture pour un lecteur cible refusee (Refused, pose par
    # Test-TargetWriteAllowed) : rien n a ete lance, journal et avis le disent (avant : operation terminee)
    $arc = ($m -and $m.Archive)
    if ($o.Refused) {
        Append-Log ((T "Bibliothèque : écriture refusée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : {0}{1}.") -f "$tab", "$trk")
    } elseif ($o.Stopped) {
        Append-Log ((T "Bibliothèque : opération arrêtée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : {0}{1}. Pour reprendre l'écriture de {2}, relancez-la depuis la Bibliothèque : le bouton ÉCRIRE LA DISQUETTE écrit l'image de l'onglet Écriture.") -f "$tab", "$trk", "$op")
    } else {
        Append-Log ((T "Bibliothèque : opération terminée, réglages de l'onglet Écriture rétablis (le préréglage de la Bibliothèque n'est pas enregistré) : {0}{1}.") -f "$tab", "$trk")
    }
    if ($arc) { Append-Log ((T "Image {0} extraite d'une archive ZIP : l'onglet Écriture ne la garde pas, son fichier extrait est temporaire et une autre archive peut le remplacer. Pour l'écrire de nouveau, relancez-la depuis la Bibliothèque.") -f "$op") }
    if ($o.Refused) { Set-WTabNotice ((T "Bibliothèque : écriture refusée. Onglet Écriture rétabli : {0}{1}.") -f "$tab", "$trk") }
    elseif ($o.Stopped) {
        if ($arc) { Set-WTabNotice ((T "Bibliothèque arrêtée : l'image {0}, extraite d'une archive ZIP, n'est pas gardée dans l'onglet Écriture ; pour reprendre, relancez l'écriture depuis la Bibliothèque. Onglet Écriture rétabli : {1}{2}.") -f "$op", "$tab", "$trk") }
        else { Set-WTabNotice ((T "Bibliothèque arrêtée : pour reprendre, relancez l'écriture depuis la Bibliothèque. Onglet Écriture rétabli : {0}{1}.") -f "$tab", "$trk") }
    } else {
        if ($arc) { Set-WTabNotice ((T "Bibliothèque terminée : l'image {0}, extraite d'une archive ZIP, n'est pas gardée dans l'onglet Écriture. Onglet Écriture rétabli : {1}{2}.") -f "$op", "$tab", "$trk") }
        else { Set-WTabNotice ((T "Bibliothèque terminée. Onglet Écriture rétabli : {0}{1}.") -f "$tab", "$trk") }
    }
}

function Set-WTabNotice([string]$text) {
    # 12.8 (FIX-PISTES) : avis dans le libelle a cote du bouton ECRIRE (lblWProfileInfo), a l encre du niveau warn de
    # frmConfirm, coupe par des points de suspension (texte complet en infobulle) ; libelle rendu a son style des qu il
    # prend un autre texte (TextChanged : profil d une autre image, calibration...)
    $script:WTabNotice = $text
    $lblWProfileInfo.AutoEllipsis = $true
    $lblWProfileInfo.ForeColor = [System.Drawing.Color]::FromArgb(138, 74, 0)
    $lblWProfileInfo.Text = $text
}

function Clear-WTabNotice {
    if (-not $script:WTabNotice -or $lblWProfileInfo.Text -eq $script:WTabNotice) { return }
    $script:WTabNotice = $null
    # 12.10 (relecture des captures) : points de suspension gardes (520 : tout texte de plus de deux lignes), encre grise
    $lblWProfileInfo.ForeColor = [System.Drawing.Color]::DimGray
}

function Update-WProfileTip {
    # 12.10 (relecture des captures) : texte complet du libelle du profil en infobulle quand il depasse ses deux lignes,
    # aucune infobulle sinon (texte, avis de la Bibliotheque ou largeur changes : 520). L infobulle propre d un Label a
    # points de suspension ne vient pas ici : sa mesure est bornee a la taille du libelle (40 px de haut au plus) ; hauteur
    # mesuree ici a la largeur du libelle, sans borne. 12.11 (L9) : trois lignes, 58 px de haut
    $h = $lblWProfileInfo.GetPreferredSize((New-Object System.Drawing.Size($lblWProfileInfo.Width, 0))).Height
    $tip.SetToolTip($lblWProfileInfo, $(if ($h -gt $lblWProfileInfo.Height) { [string]$lblWProfileInfo.Text } else { '' }))
}

function Update-WCalTip {
    # 12.10 (relecture de la RC) : texte complet du libelle de calibration de l onglet Ecriture ($lblWCal, 520 : une ligne a
    # largeur fixe, points de suspension) en infobulle quand il depasse la largeur du libelle (marge de l icone du verdict
    # comprise), aucune infobulle sinon ; appelee au changement de texte, de taille, de police et de marge (520)
    $tip.SetToolTip($lblWCal, $(if ($lblWCal.PreferredWidth -gt $lblWCal.Width) { [string]$lblWCal.Text } else { '' }))
}

function Get-WProfileText {
    # 12.8 (FIX-PISTES-2) : texte du profil de lblWProfileInfo pour les copies d etat des calibrations (Get-CalibSnapshot,
    # champs d avant une calibration rapide) ; $null quand le libelle porte l avis de fin de la Bibliotheque
    # (Set-WTabNotice) : apres un refus, Update-PrecompForImage pose le texte du profil, l avis n est pas repris
    if ($script:WTabNotice -and $lblWProfileInfo.Text -eq $script:WTabNotice) { return $null }
    return $lblWProfileInfo.Text
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
    # Save-Config pendant une operation surchargee : reglages de l onglet Ecriture d avant l operation. 12.10 (lot 1,
    # E9-image, decision E9-3) : operation de la Bibliotheque lancee : image de l operation, comme a sa fin (Merge-LibKeepState ;
    # R1, constat d : des le premier gw write de l image, Written pose par Start-Gw avant son Save-Config)
    $o = $script:OpOverride; $s = $o.Saved; $w = $cfg['write']
    if ($o.Kind -eq 'library') { $s = (Merge-LibKeepState $s $o.KeepImg ([bool]$o.Written)).State }
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
        [void](Show-AppMessage (T 'Fichier image introuvable.') (T 'Erreur') 'OK' 'Warning'); return
    }
    $ext = [System.IO.Path]::GetExtension($img).ToLower()
    $fmt = $cmbWFmt.Text
    $explicit = ($fmt -and $fmt -ne '(auto)')
    if ((Test-NeedsFormat $img) -and -not $explicit) {
        # Avant toute calibration : gw refuserait l ecriture apres coup (« Sector image requires a disk format »)
        [void](Show-AppMessage ((T "Image secteur sans géométrie ({0}) : gw exige le format.`nChoisir le format dans l'onglet Écriture, puis relancer l'écriture.") -f "$ext") (T 'Format requis') 'OK' 'Warning'); return
    }
    # 12.10 (relecture de l etape 3) : lecteur cible choisi (Get-TargetWriteInfo) ; ecriture refusee (haute densite, aucune
    # courbe croisee de la famille, courbes croisees par tete en ecriture rapide) : refus de Start-ImageWrite
    # (Test-TargetWriteAllowed) avant toute ligne de calibration ou de mesure (avant : la branche haute densite disait la
    # calibration appliquee, puis l ecriture etait refusee)
    $tw = Get-TargetWriteInfo $img $fmt ($mode -eq 'slow')
    if ($tw.Block) { Start-ImageWrite; return }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains $ext) {
        # 12.8 (S3-FLUX, decision 2) : aucune mesure avant l ecriture d une image flux ; ligne de journal quand une mesure
        # aurait ete faite pour une image calibrable (test rapide, ou case « Mesurer la disquette » en ecriture lente) ;
        # restauration : ligne de Start-RestoreWrite
        if (-not $script:Restore -and ($cmbWCalMode.SelectedIndex -eq 2 -or (Test-WriteLevelWanted $mode))) { Write-FluxLevelSkip $img $fmt }
        Start-ImageWrite; return
    }
    # 12.10 (lot 1, B1) : image FM, GCR ou a codage propre (Get-ImageEncoding : format, extension ou en-tete, HFE FM
    # compris) : ni calibration ni mesure, elles ne mesurent que le MFM ; Start-ImageWrite ne transmet pas --precomp
    if (Test-NonMfmWrite $img $fmt) { Write-NonMfmSkip $img $fmt; Start-ImageWrite; return }
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
    # 12.10 : lecteur cible choisi, avec effet sur cette ecriture (Get-TargetWriteInfo) : ni calibration automatique, ni test
    # rapide, ni mesure de la disquette (ils reliraient avec le lecteur du bandeau) : ecriture avec la courbe croisee telle
    # quelle (refus : plus haut, $tw)
    if ($tw.Applies) { Append-Log ((T "Écriture pour le lecteur cible {0} : ni calibration automatique ni mesure de la disquette (elles reliraient avec le lecteur {1}) ; écriture avec la courbe croisée telle quelle.") -f "$($tw.Tgt)", "$($cmbDrive.Text)"); Start-ImageWrite; return }
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
    if (Test-NonMfmWrite $img $fmt) { return '' }    # 12.10 (lot 1, B1) : FM, GCR ou codage propre (HFE FM compris)
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

function Test-FluxImage([string]$img) {
    # Image flux (SCP, KryoFlux, A2R, CTR) : transitions enregistrees, et non pistes de bits ou secteurs
    return (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains [System.IO.Path]::GetExtension("$img").ToLower())
}

function Test-RawFluxWrite([string]$img, [string]$fmt) {
    # 12.8 (S3-FLUX, decision 2 du 21/10/2026) : image flux ecrite sans --format (meme regle que Get-WriteFormatArgs) :
    # gw l ecrit telle quelle et n applique --precomp qu aux pistes MasterTrack (tools/write.py de gw 1.23 : images a
    # cellules ou a secteurs, flux decode par --format) : precompensation ignoree
    return ((Test-FluxImage $img) -and -not ($fmt -and $fmt -ne '(auto)'))
}

function Write-FluxLevelSkip([string]$img, [string]$fmt) {
    # 12.8 (S3-FLUX, decision 2) : aucune mesure de la disquette (calibration rapide ou mesure complete) avant l ecriture
    # d une image flux, depuis le bouton ECRIRE et la Bibliotheque (restauration : Start-RestoreWrite) : ligne de journal.
    # Flux decode par --format : gw lui applique la precompensation, mais la mesure ne se fait pas non plus
    $n = [System.IO.Path]::GetFileName("$img")
    if (Test-RawFluxWrite $img $fmt) { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : image flux {0}, écrite telle quelle, à laquelle gw n'applique pas la précompensation (flux sans --format). Écriture sans mesure.") -f "$n") }
    else { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : image flux {0}, décodée par --format={1} ; la disquette n'est pas mesurée avant l'écriture d'une image flux. Écriture sans mesure.") -f "$n", "$fmt") }
}

function Write-NonMfmSkip([string]$img, [string]$fmt) {
    # 12.10 (lot 1, B1) : ni calibration ni mesure de la disquette avant l ecriture d une image FM, GCR ou a codage propre
    # (Start-PresetWrite, bouton ECRIRE) : ligne de journal. Profil Manuel avec --precomp coche : la ligne de Start-ImageWrite
    # (champ transmis tel quel) la remplace, l ecriture n etant pas sans precompensation
    if (Test-ManualPrecomp) { return }
    $ie = Get-ImageEncoding $img $fmt
    Append-Log ((T "Image {0} en codage {1} : pas de calibration (elle ne mesure que le MFM), écriture sans précompensation.") -f "$([System.IO.Path]::GetFileName("$img"))", "$($ie.Name)")
}

function Test-ManualPrecomp {
    # 12.10 (lot 1, revue2, R-6) : profil Manuel avec --precomp coche : Start-ImageWrite transmet le champ tel quel, meme sur
    # une image FM, GCR ou a codage propre. Textes « ecrite sans precompensation » omis dans ce cas (Write-NonMfmSkip,
    # refus de Test-CalibImage, et raisons de Get-FormatCalibInfo qu il demande, parametre manual)
    return ($cmbWProfile.SelectedIndex -eq 3 -and $chkWPrecomp.Checked)
}

function Get-LevelWriteSkip([string]$img, [string]$fmt, [string]$ts) {
    # 12.7 point 5 (arbitrage 15) : mesure de la disquette avant l ecriture lente exclue quand l image ne recouvrirait pas
    # tout le motif. La mesure ecrit le motif sur 4 a 9 cylindres par tete, sur tout le disque et les deux tetes
    # (Start-LevelCalib : c=...:h=0-1), sans le champ Pistes. Renvoie $null (mesure possible) ou @{ Why } : ligne de
    # journal, vide quand Start-ImageWrite refusera l ecriture lente (son message s affiche alors avant toute ecriture du
    # motif). Cas, dans cet ordre :
    #  - champ Pistes avec c=, h= ou step= (step= : pistes physiques que la mesure, sans le pas, ne vise pas) ;
    #  - faces de l image inconnues avec « Effacer les pistes vides », en ecriture lente : refus de Start-ImageWrite (memes
    #    regles, sans h=). 12.8 (lot 2, PRE-BANC § 4) : en ecriture rapide, ce refus n existe pas (gw ecrit toutes les
    #    pistes du format) : faces du format, comme sans la case (12.8 avant ce correctif : mesure sautee sans ligne) ;
    #  - image a une seule face : faces de l image (Get-ImageTrackSet), sinon tetes du format gw d une image secteur.
    # 12.11 (L10) : Code, cas rendu ('tracks', 'faces', 'face'), lu par Get-WriteLevelPlan ; appelants inchanges
    $ts = "$ts".Trim()
    if ($ts -and [regex]::IsMatch(":$ts", ':\s*(c|h|step)\s*=')) { return @{ Code = 'tracks'; Why = ((T "Mesure de la disquette avant l'écriture non faite : le champ Pistes (« {0} ») limite les pistes écrites ; le motif de test resterait sur des cylindres que l'image ne recouvre pas. Écriture sans mesure.") -f "$ts") } }
    $set = Get-ImageTrackSet $img
    if ($null -eq $set) {
        if ($chkWEraseEmpty.Checked -and $chkWSlow.Checked) { return @{ Code = 'faces'; Why = '' } }
        $fe = if ($fmt -and $fmt -ne '(auto)' -and $script:GwFormats.Contains($fmt)) { $script:GwFormats[$fmt] } else { $null }
        $hs = @(if ($fe -and [int]$fe.Heads -eq 1) { 0 } else { 0, 1 })
    } else { $hs = @(@($set.Keys) | ForEach-Object { [int](([string]$_ -split '\.')[1]) } | Sort-Object -Unique) }
    if ($hs.Count -eq 1) { return @{ Code = 'face'; Why = (T "Mesure de la disquette avant l'écriture non faite : image à une seule face ; le motif de test resterait sur l'autre face, que l'image n'écrit pas. Écriture sans mesure.") } }
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
    # 12.8 (FIX-PISTES, essai du 21/10/2026) : champ Pistes qui retire des pistes de l image (c=, h=) : confirmation qui
    # nomme l image et les pistes (Confirm-PartialWrite), avant toute mesure ou ecriture ; le champ reste enregistre dans
    # la configuration, comme en 12.7. FIX-PISTES-2 : aussi pour step= autre que 1 (pas du lecteur par cylindre)
    # 12.10 : lecteur cible choisi (Get-TargetDrive) : ni mesure de la disquette ni calibration rapide (elles reliraient avec
    # le lecteur du bandeau) : ecriture avec la courbe croisee telle quelle ; refusee sans courbe croisee de la famille
    # (Test-TargetWriteAllowed), avant la confirmation d une ecriture partielle
    # 12.11 (L10) : cascade de la mesure decidee par Get-WriteLevelPlan (Kind, Skip), dont la ligne « Ce qui va se passer »
    # tire aussi son segment ; memes lignes de journal, dans le meme ordre, et memes appels
    $img = $txtWFile.Text
    $mode = if ($chkWSlow.Checked) { 'slow' } else { 'fast' }
    $tgt = Get-TargetDrive
    if ($img -and (Test-Path -LiteralPath $img) -and -not ($script:GwProc -and -not $script:GwProc.HasExited)) {
        if ($tgt -and -not (Test-TargetWriteAllowed $img $cmbWFmt.Text ($mode -eq 'slow'))) { return }
        if (-not (Confirm-PartialWrite $img $cmbWFmt.Text $txtWTracks.Text)) { return }
    }
    $wp = Get-WriteLevelPlan $img $cmbWFmt.Text $mode
    # Lecteur cible sans effet sur cette ecriture (profil Manuel, --precomp decoche, flux, FM, GCR : Get-TargetWriteInfo) :
    # deroule ordinaire, qui ne mesure pas ces ecritures (Start-ImageWrite le dit au journal)
    if ($wp.Skip -eq 'target') {
        if ($wp.Asked) { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : écriture pour le lecteur cible {0} (la mesure relirait avec le lecteur {1}). Écriture avec la courbe croisée telle quelle.") -f "$tgt", "$($cmbDrive.Text)") }
        Start-ImageWrite; return
    }
    if ($wp.Kind -eq 'none' -and -not $wp.Skip) { Start-ImageWrite; return }
    if ($script:GwProc -and -not $script:GwProc.HasExited) { return }
    # 12.8 (S3-FLUX, decision 2 du 21/10/2026) : image flux : jamais de mesure avant l ecriture, ligne de journal
    if ($wp.Skip -eq 'flux') { Write-FluxLevelSkip $img $cmbWFmt.Text; Start-ImageWrite; return }
    # 12.10 (lot 1, B1) : image FM, GCR ou a codage propre : jamais de mesure avant l ecriture, ligne de journal
    if ($wp.Skip -eq 'nonmfm') { Write-NonMfmSkip $img $cmbWFmt.Text; Start-ImageWrite; return }
    if ($wp.Skip -eq 'kind') { Start-ImageWrite; return }
    # Haute densite avant le profil : la mesure n y existe pas, quel que soit le profil ; ligne de la courbe ou du profil
    # d origine seulement quand le mode Auto les applique (profil Auto, --precomp coche)
    if ($wp.Skip -eq 'hd') {
        if ($wp.HdNote) { Write-LevelHdNote $wp.Hf ($mode -eq 'slow') }
        else { Append-Log (T 'Mesure de la disquette non disponible en haute densité.') }
        Start-ImageWrite; return
    }
    # Profil choisi a la main (Manuel, ou profil force) : la mesure decalerait la courbe calibree du profil Auto
    if ($wp.Skip -eq 'profile') { Append-Log ((T "Mesure de la disquette avant l'écriture non faite : profil précomp. « {0} » choisi ; la mesure ne se fait qu'avec le profil Auto.") -f "$($cmbWProfile.Text)"); Start-ImageWrite; return }
    # --precomp decoche : la mesure le cocherait (Set-LevelFields) ; ecriture sans precompensation, comme en 12.6
    if ($wp.Skip -eq 'precomp') { Append-Log (T "Mesure de la disquette avant l'écriture non faite : précompensation désactivée (case --precomp décochée) ; écriture sans précompensation."); Start-ImageWrite; return }
    # Champ Pistes, faces de l image (Get-LevelWriteSkip)
    if ($wp.Skip) { if ($wp.Why) { Append-Log $wp.Why }; Start-ImageWrite; return }
    Start-LevelBeforeWrite $wp.LbMode -Measure:([bool]$wp.LbMeasure)
}

function Get-WriteLevelPlan([string]$img, [string]$fmt, [string]$mode) {
    # 12.11 (L10, extraite de Start-WriteTabWrite sans changement de comportement) : mesure de la disquette avant une
    # ecriture du bouton ECRIRE, decision commune a Start-WriteTabWrite et a la ligne « Ce qui va se passer »
    # (Get-WritePlan, 145) ; aucune ligne de journal, aucune fenetre. Rend @{ Kind ; Skip ; Asked ; Tgt ; Why ; HdNote ; Hf ;
    # LbMode ; LbMeasure } :
    #  - Kind 'quick' (liste « Calibration precomp » au « Test rapide » : Start-LevelBeforeWrite $mode), 'measure' (case
    #    « Mesurer la disquette » en ecriture lente, liste au test standard ou fin : Start-LevelBeforeWrite 'slow' -Measure),
    #    'none' (ecriture sans mesure) ; LbMode et LbMeasure : arguments de Start-LevelBeforeWrite ;
    #  - Skip, mesure demandee (Asked) mais non faite, dans l ordre des tests : 'target' (lecteur cible avec effet ; ligne
    #    de journal seulement si Asked), 'flux', 'nonmfm' (FM, GCR, codage propre), 'kind' (image non calibrable,
    #    Get-WriteLevelKind), 'hd' (HdNote : ligne de la courbe HD, Hf sa famille), 'profile' (profil autre qu Auto),
    #    'precomp' (case --precomp decochee), 'tracks', 'faces' ou 'face' (Get-LevelWriteSkip : Code, Why, ligne de
    #    journal) ; '' avec Kind 'none' : mesure non demandee, ou fichier absent
    $r = @{ Kind = 'none'; Skip = ''; Asked = $false; Tgt = ''; Why = ''; HdNote = $false; Hf = ''; LbMode = $mode; LbMeasure = $false }
    $quick = ((Get-Setting 'calMode') -eq 'level')
    $r.Asked = [bool]($quick -or (Test-WriteLevelWanted $mode))
    $tgt = Get-TargetDrive
    if ($tgt -and (Get-TargetWriteInfo $img $fmt ($mode -eq 'slow')).Applies) { $r.Skip = 'target'; $r.Tgt = $tgt; return $r }
    if (-not $r.Asked -or -not $img -or -not (Test-Path -LiteralPath $img)) { return $r }
    if (Test-FluxImage $img) { $r.Skip = 'flux'; return $r }
    if (Test-NonMfmWrite $img $fmt) { $r.Skip = 'nonmfm'; return $r }
    $k = Get-WriteLevelKind $img $fmt
    if (-not $k) { $r.Skip = 'kind'; return $r }
    $auto = ($cmbWProfile.SelectedIndex -eq 0)
    if ($k -eq 'hd') {
        $r.Skip = 'hd'
        if ($auto -and $chkWPrecomp.Checked) { $r.HdNote = $true; $r.Hf = Get-HdCalibFamily $img $fmt }
        return $r
    }
    if (-not $auto) { $r.Skip = 'profile'; return $r }
    if (-not $chkWPrecomp.Checked) { $r.Skip = 'precomp'; return $r }
    $sk = Get-LevelWriteSkip $img $fmt $txtWTracks.Text
    if ($sk) { $r.Skip = [string]$sk.Code; $r.Why = [string]$sk.Why; return $r }
    if ($quick) { $r.Kind = 'quick'; return $r }
    $r.Kind = 'measure'; $r.LbMode = 'slow'; $r.LbMeasure = $true
    return $r
}

function Confirm-PartialWrite([string]$img, [string]$fmt, [string]$tspec) {
    # 12.8 (FIX-PISTES, essai du 21/10/2026) : bouton ECRIRE avec un champ Pistes qui retire des pistes de l image
    # (Get-WritePartial) : ligne de journal, puis frmConfirm sans case, « Ecrire ces pistes » ou « Fermer » (reponse notee
    # au journal par Show-AppConfirm). La Bibliotheque et la restauration n y passent pas : Set-WritePreset retire c= et h=
    # du champ (h= d une image a une face seulement, qui couvre l image), et la restauration ne pose c= que pour ses
    # cylindres preserves. Renvoie $true quand l ecriture continue.
    # 12.8 (FIX-PISTES-2) : aucune piste de l image dans le champ (Kept 0 : piste vide de l image, cylindres hors de
    # l image) : texte propre, gw n ecrit aucune donnee mais efface ces pistes avec --erase-empty (essai du 21/10/2026 :
    # « T0.0: Erasing Track ») ; step= autre que 1 : texte propre (aucune piste retiree, pas du lecteur par cylindre),
    # seul (titre « Pas du lecteur modifie ») ou apres celui de c= et h=
    $pw = Get-WritePartial $img $fmt $tspec
    if (-not $pw) { return $true }
    $name = [System.IO.Path]::GetFileName($img)
    $logs = @(); $parts = @()
    if ($pw.Partial -and [int]$pw.Kept -eq 0) {
        $er = if ($chkWEraseEmpty.Checked) { ' ' + (T "« Effacer les pistes vides » est cochée : ces pistes de la disquette seront effacées.") } else { '' }
        $logs += ((T "Écriture partielle : aucune piste de {1} dans le champ Pistes ({0}), aucune donnée de l'image ne sera écrite.") -f "$($pw.Spec)", "$name") + $er
        $parts += ((T "Aucune piste de {1} n'est dans le champ Pistes ({0}) : aucune donnée de l'image ne sera écrite.") -f "$($pw.Spec)", "$name") + $er
    } elseif ($pw.Partial) {
        $cnt = if ([int]$pw.Total -ge 0) { (T " ({0} piste(s) sur les {1} de l'image)") -f "$($pw.Kept)", "$($pw.Total)" } else { '' }
        $logs += (T "Écriture partielle : seules les pistes {0} de {1} seront écrites{2} (champ Pistes de l'onglet Écriture).") -f "$($pw.Spec)", "$name", "$cnt"
        $parts += (T "Seules les pistes {0} de {1} seront écrites{2}.") -f "$($pw.Spec)", "$name", "$cnt"
    }
    if ($pw.Step) {
        $logs += (T "Pas du lecteur : {1} sera écrite avec step={0} ({0} pas du lecteur par cylindre au lieu d'un, champ Pistes de l'onglet Écriture).") -f "$($pw.Step)", "$name"
        if ($pw.Partial) { $parts += (T "Le champ Pistes contient aussi step={0} : {0} pas du lecteur par cylindre au lieu d'un.") -f "$($pw.Step)" }
        else { $parts += (T "Le champ Pistes contient step={0} : {1} sera écrite avec {0} pas du lecteur par cylindre au lieu d'un (step=2 sert à écrire une disquette 40 pistes dans un lecteur 80 pistes).") -f "$($pw.Step)", "$name" }
    }
    foreach ($l in $logs) { Append-Log $l }
    if ($pw.Partial) {
        $ttl = (T 'Écriture partielle'); $go = (T 'Écrire ces pistes'); $no = (T "Écriture annulée : écriture partielle non confirmée, rien n'a été écrit.")
        $tail = (T "Le champ Pistes des options avancées de l'onglet Écriture limite l'écriture à ces pistes ; il est gardé d'une session à l'autre. Pour écrire toute l'image, fermez cette fenêtre et videz ce champ.")
    } else {
        $ttl = (T 'Pas du lecteur modifié'); $go = (T 'Écrire avec ce pas'); $no = (T "Écriture annulée : pas du lecteur non confirmé, rien n'a été écrit.")
        $tail = (T "Le champ Pistes des options avancées de l'onglet Écriture est gardé d'une session à l'autre. Pour écrire au pas normal du lecteur, fermez cette fenêtre et retirez step= de ce champ.")
    }
    $cq = @{ Title = $ttl; Heading = $ttl; Level = 'warn'; Picto = 'warn'; Text = ($parts -join ' ') + "`n`n" + $tail; GoText = $go; GoGlyph = 'Save' }
    if (Show-AppConfirm @cq) { return $true }
    Append-Log $no
    return $false
}

# --- Facteur de precompensation et lecteur cible (12.8.1, 12.10) ------
# Courbe ecrite = k_h x courbe, par tete (spec-1281 § A.10, C.3 ; decisions de l utilisateur du 25/10/2026). k_h : mesure
# sur l image qui precede l ecriture (276, $script:WriteFactorNext), sinon k du lecteur : mediane des 3 derniers k* mesures
# pour ce lecteur, cette famille et cette tete (Get-DriveK, 274), garde apres une recalibration du lecteur, 1 sans mesure
# (ecriture de la v12.8). Il s applique a la courbe que la v12.8 aurait ecrite : courbe du lecteur, courbe adaptee d une
# calibration rapide, courbe d une mesure complete ou d une marque. Haute densite, flux, FM, GCR, profil autre qu Auto :
# jamais de facteur. 12.9 (N13) : k du lecteur par marque (marque de la mesure qui precede, sinon derniere marque choisie),
# nommee dans les lignes de journal.
# 12.10 : la correction « lecteur cible » Dk de la 12.8.1 (valeur par tete ajoutee au facteur, champs de l onglet Ecriture,
# bloc targetCorrection de la configuration) est retiree : a sa place, la liste « Lecteur cible » (cmbWTarget, 520) choisit
# le lecteur qui relira la disquette ecrite par le lecteur du bandeau (la source) ; les courbes croisees « source>cible » de
# la calibration croisee (270) sont alors appliquees telles quelles (Set-PrecompFields, 220), sans facteur
# (Get-WriteFactorPlan : le facteur de marque, mesure par la relecture de la source, ne vaut pas pour la cible) ; sans
# courbe croisee pour la famille de l image, l ecriture est refusee (Test-TargetWriteAllowed). Choix memorise par lecteur
# source ($script:TargetDrives, 560 ; write.targetDrive, 120).

function Get-WriteFactorSrcText([string]$drive, [string]$fam, [int]$h, [double]$k, [string]$src, $brand = $null) {
    # Origine du facteur d une tete dans les lignes de journal : mesure sur cette disquette ('mesure'), mesures du lecteur
    # ('lecteur' : derniere, ou mediane des 3 dernieres avec leurs valeurs), aucune mesure ('defaut' : k = 1).
    # 12.9 (N13) : mesures du lecteur pour la marque $brand ($null : derniere marque choisie, Get-DriveK), nommee ; sans
    # mesure de la marque, nombre de mesures d autres marques (jamais empruntees). 12.10 : sans la correction Dk
    $kt = Format-UiNum $k '0.00'
    if ($src -eq 'mesure') { return ((T 'k {0} mesuré sur cette disquette') -f "$kt") }
    $dr = Get-DriveK $drive $fam $h $brand
    $bn = [string]$dr.Brand; if (-not $bn.Trim()) { $bn = (T '(non précisée)') } else { $bn = $bn.Trim() }
    if ($src -eq 'lecteur') {
        if ([int]$dr.N -ge 2) { return ((T 'k {0}, médiane des {1} dernières mesures du lecteur pour la marque « {2} » ({3})') -f "$kt", "$($dr.N)", "$bn", ((@($dr.Ks) | ForEach-Object { Format-UiNum ([double]$_) '0.00' }) -join ' ; ')) }
        $md = if ($dr.Rec -and $dr.Rec.Date) { [string]$dr.Rec.Date } else { '?' }
        return ((T 'k {0} de la dernière mesure du lecteur pour la marque « {1} » (du {2})') -f "$kt", "$bn", "$md")
    }
    # Revue 12.8.2 : mesures de ce lecteur ecartees parce qu elles viennent d un autre calcul (Get-DriveK, Old). 12.9
    # (revue de la phase B, mineur 1) : ecartees seulement par ContentCalc (OldContent) : calcul de la mesure change
    if ([int]$dr.Old -gt 0 -and [int]$dr.OldContent -ge [int]$dr.Old) { return ((T 'k 1 (mesures de ce lecteur faites avant la {0}, calcul de la mesure changé, à refaire pour la marque « {1} »)') -f "$($script:ContentCalc)", "$bn") }
    if ([int]$dr.Old -gt 0) { return (T 'k 1 (mesures de ce lecteur faites avec un autre calcul de calibration, à refaire)') }
    $oth = if ([int]$dr.Other -gt 0) { (T ' ; {0} mesure(s) d''autres marques') -f "$($dr.Other)" } else { '' }
    return ((T 'k 1 (aucune mesure de ce lecteur pour la marque « {0} »{1})') -f "$bn", "$oth")
}

function Get-WriteFactorPlan([string]$img, [string]$fmt, [bool]$slow, $next = $null, [switch]$Peek) {
    # Facteur de precompensation d une ecriture de l onglet Ecriture (Start-ImageWrite), par tete : f_h = k_h, ramene a
    # [0 ; ContentFMax] (Limit-WriteFactor, plafond : 040) ; ecriture rapide : FMean, moyenne des facteurs des deux tetes
    # (decision du 25/10/2026). $next : facteur mesure sur l image ($script:WriteFactorNext), retenu pour le meme lecteur,
    # la meme famille et la meme image seulement. Apply faux, raison Why : fichier absent, profil autre qu Auto, --precomp
    # decoche, image non calibrable en double densite (haute densite, flux, FM, GCR...), famille sans courbe, courbe d un
    # autre lecteur. Lines : lignes de journal, dans l ordre (T-C10 par tete bornee, puis T-C8 ou T-C9 ; sans facteur :
    # facteur du lecteur non applique si k != 1). Hard : borne des profils mis a l echelle (ConvertTo-ScaledSpec : une
    # valeur deja au-dessus, venue d une mesure complete, n est jamais augmentee). Peek : calcul seul, sans les lignes d un
    # facteur non applique (libelle du profil, texte « Ecrire sans mesure » de la confirmation de la mesure sur l image, 276).
    # 12.10 : lecteur cible avec effet sur cette ecriture (Get-TargetWriteInfo : profil Auto ou force, --precomp coche, image
    # MFM a laquelle --precomp est transmis) : facteur 1, jamais applique (Apply faux, Target = cible, Fam, Curves = courbes
    # croisees ecrites) ; lignes « Ecriture pour le lecteur cible ... : courbe croisee ..., facteur 1,00 » et « Facteur de
    # marque non applique » ; sans courbe croisee (ou haute densite) : Why « aucune courbe croisee », Target vide (l ecriture
    # est refusee par Test-TargetWriteAllowed). Lecteur cible sans effet : facteur comme pour le meme lecteur
    $drive = [string]$cmbDrive.Text
    $hard = [int]$script:CalHardNsUser; if ($hard -le 0) { $hard = [int]$script:CalHardNs }
    $fMax = [double]$script:ContentFMax
    $r = @{ Apply = $false; Why = ''; F0 = 1.0; F1 = 1.0; FMean = 1.0; K = @{ 0 = 1.0; 1 = 1.0 }; Src = @{ 0 = 'defaut'; 1 = 'defaut' }
            Hard = $hard; Fam = ''; Line = ''; Lines = @(); Target = ''; Curves = @() }
    $tw = Get-TargetWriteInfo $img $fmt $slow
    if ($tw.Applies) {
        $r.Fam = [string]$tw.Fam
        $tc = @($tw.Curves)
        if ($tc.Count -eq 0) { $r.Why = (T 'aucune courbe croisée {0} → {1}') -f "$drive", "$($tw.Tgt)"; return $r }
        $r.Target = [string]$tw.Tgt; $r.Curves = $tc
        if ($Peek) { return $r }
        $r.Line = (T "Écriture pour le lecteur cible {0} : {1}, facteur 1,00.") -f "$($tw.Tgt)", (Get-TargetCurvesText $drive ([string]$tw.Tgt) ([string]$tw.Fam) $tc)
        $r.Lines = @($r.Line, ((T "Facteur de marque non appliqué : écriture pour le lecteur cible {0} (le facteur est mesuré par la relecture du lecteur {1}, il ne vaut pas pour le lecteur cible).") -f "$($tw.Tgt)", "$drive"))
        return $r
    }
    $fam = ''
    if (-not $img -or -not (Test-Path -LiteralPath $img)) { $r.Why = (T 'Fichier image introuvable.') }
    elseif ($cmbWProfile.SelectedIndex -ne 0) { $r.Why = (T 'profil précomp. « {0} »') -f "$($cmbWProfile.Text)" }
    elseif (-not $chkWPrecomp.Checked) { $r.Why = (T 'précompensation désactivée') }
    else {
        $kind = Get-WriteLevelKind $img $fmt
        if ($kind -ne 'dd') {
            $r.Why = if ($kind -eq 'hd' -or (Get-HighDensityReason $img $fmt)) { (T 'image haute densité') } else { (T 'image non calibrable en double densité') }
        } else {
            # Courbes que le mode Auto ecrit (Set-PrecompFields : par tete a jour en ecriture lente, sinon commune) ; tableau
            # protege par Get-FamilyCurves (pas de @() autour de l appel)
            $fam = Get-ImageFamily $img $fmt
            $cvs = Get-FamilyCurves $fam $slow
            $oth = @(@($cvs) | Where-Object { [string]$_.Drive -ne $drive } | ForEach-Object { if ($_.Drive) { [string]$_.Drive } else { '?' } } | Sort-Object -Unique)
            if (@($cvs).Count -eq 0) { $r.Why = (T 'aucune courbe du lecteur') }
            elseif ($oth.Count -gt 0) { $r.Why = (T "courbe d'un autre lecteur ({0})") -f ($oth -join ', ') }
            else { $r.Apply = $true; $r.Fam = $fam }
        }
    }
    if (-not $r.Apply) {
        if ($Peek) { return $r }
        if ($img -and (Test-Path -LiteralPath $img)) {
            $fk = Get-ImageFamily $img $fmt
            if (@('std', 'long') -contains $fk) {
                $k0 = [double](Get-DriveK $drive $fk 0).K; $k1 = [double](Get-DriveK $drive $fk 1).K
                if ($k0 -ne 1 -or $k1 -ne 1) { $r.Line = (T 'Facteur mesuré du lecteur {0} (tête 0 × {1}, tête 1 × {2}) non appliqué à cette écriture : {3}.') -f "$drive", (Format-UiNum $k0 '0.00'), (Format-UiNum $k1 '0.00'), "$($r.Why)" }
            }
        }
        if ($r.Line) { $r.Lines = @($r.Line) }
        return $r
    }
    $useNext = ($null -ne $next -and [string]$next.Drive -eq $drive -and [string]$next.Fam -eq $fam -and [string]$next.Img -eq $img)
    # 12.9 (N13) : marque de la mesure ou de la fenetre « Mesure de la disquette » qui precede ($next.Brand), sinon derniere
    # marque choisie (ecritures sans fenetre : rapide, Bibliotheque, restauration, test rapide)
    $brand = if ($useNext -and $null -ne $next.Brand) { [string]$next.Brand } else { [string]$script:LevelBrand }
    $bn = if ($brand.Trim()) { $brand.Trim() } else { (T '(non précisée)') }
    $txt = @{}; $lines = @()
    foreach ($h in 0, 1) {
        $k = $null; $src = 'defaut'
        if ($useNext -and $next.K) {
            $kv = $next.K[$h]; if ($null -eq $kv) { $kv = $next.K["$h"] }
            if ($null -ne $kv) {
                $k = [double]$kv; $sv = $null
                if ($next.Src) { $sv = $next.Src[$h]; if ($null -eq $sv) { $sv = $next.Src["$h"] } }
                $src = if ($sv) { [string]$sv } else { 'mesure' }
            }
        }
        if ($null -eq $k -or [double]::IsNaN($k) -or [double]::IsInfinity($k)) { $dr = Get-DriveK $drive $fam $h $brand; $k = [double]$dr.K; $src = [string]$dr.Src }
        $lim = Limit-WriteFactor $k $fMax
        if ($lim.Clamped) { $lines += (T 'Facteur de la tête {0} ramené de {1} à {2} (il va de 0 à {3}).') -f "$h", (Format-UiNum $k '0.00'), (Format-UiNum ([double]$lim.F) '0.00'), (Format-UiNum $fMax '0.0#') }
        $r.K[$h] = $k; $r.Src[$h] = $src
        if ($h -eq 0) { $r.F0 = [double]$lim.F } else { $r.F1 = [double]$lim.F }
        $txt[$h] = Get-WriteFactorSrcText $drive $fam $h $k $src $brand
    }
    $r.FMean = [double](Limit-WriteFactor (($r.F0 + $r.F1) / 2) $fMax).F
    $r.Brand = $brand
    if ($slow) {
        $r.Line = (T "Facteur de précompensation de cette écriture (lecteur {0}, marque « {1} ») : tête 0 × {2} ({3}) ; tête 1 × {4} ({5}). Courbe écrite = facteur × courbe, bornée à 0..{6} ns ; une valeur déjà au-dessus n'est jamais augmentée.") -f "$drive", "$bn", (Format-UiNum $r.F0 '0.00'), "$($txt[0])", (Format-UiNum $r.F1 '0.00'), "$($txt[1])", "$hard"
    } else {
        $r.Line = (T "Facteur de précompensation de cette écriture rapide (lecteur {0}, marque « {1} ») : × {2}, moyenne des deux têtes (tête 0 × {3}, {4} ; tête 1 × {5}, {6}). Courbe écrite = facteur × courbe, bornée à 0..{7} ns ; une valeur déjà au-dessus n'est jamais augmentée.") -f "$drive", "$bn", (Format-UiNum $r.FMean '0.00'), (Format-UiNum $r.F0 '0.00'), "$($txt[0])", (Format-UiNum $r.F1 '0.00'), "$($txt[1])", "$hard"
    }
    $r.Lines = @($lines) + @($r.Line)
    # Finalisation 12.10 : conseil de mesure de la disquette apres la ligne du facteur (Get-WriteFactorHint) ; jamais pour
    # -Peek (libelle du profil, confirmation de la mesure : ni ligne, ni test de la mesure possible)
    if (-not $Peek) {
        $hint = Get-WriteFactorHint $img $fmt $slow $drive $fam $brand $r.Src
        if ($hint) { $r.Lines = @($r.Lines) + @($hint) }
    }
    return $r
}

function Get-WriteFactorHint([string]$img, [string]$fmt, [bool]$slow, [string]$drive, [string]$fam, [string]$brand, $src) {
    # Finalisation 12.10 (analyse long track du 08/11/2026 : le meilleur facteur varie de +/- 0,2 d une disquette a l autre
    # d une meme marque) : ligne de journal qui conseille de mesurer la disquette, rendue a Get-WriteFactorPlan quand le
    # facteur s applique (profil Auto, --precomp coche, double densite, courbe du lecteur, sans lecteur cible), chaine vide
    # sinon :
    #  - facteur tire de la memoire de la marque (Src lecteur : aucune mesure de cette disquette dans cette ecriture), et
    #    mesures listees au journal pour une tete (Get-DriveK : 2 ou 3, arrondies a 0,01 comme au journal) ecartees de 0,2
    #    ou plus ;
    #  - image long track ecrite avec k 1 faute de toute mesure de la marque sur ce lecteur (Src defaut aux deux tetes).
    # Seulement si la mesure sur l image est possible pour cette ecriture et n y est pas deja demandee : ni restauration, ni
    # liste Calibration precomp au Test rapide (mesure au motif, ligne de Start-LevelBeforeWrite), case Mesurer la disquette
    # non cochee pour cette ecriture (Test-WriteLevelWanted), image qui recouvre tout le motif (Get-LevelWriteSkip) et
    # mesurable sur son contenu (Test-ContentMeasurable : MFM double densite, champ Pistes vide, courbe du lecteur assez
    # longue, 20 cylindres)
    if ($script:Restore -or $cmbWCalMode.SelectedIndex -eq 2) { return '' }
    if (Test-WriteLevelWanted $(if ($slow) { 'slow' } else { 'fast' })) { return '' }
    $spread = -1.0
    foreach ($h in 0, 1) {
        if ([string]$src[$h] -ne 'lecteur') { continue }
        $dr = Get-DriveK $drive $fam $h $brand
        if ([int]$dr.N -lt 2) { continue }
        $ks = @(@($dr.Ks) | ForEach-Object { [math]::Round([double]$_, 2) })
        $sp = [math]::Round([double]($ks | Measure-Object -Maximum).Maximum - [double]($ks | Measure-Object -Minimum).Minimum, 2)
        if ($sp -gt $spread) { $spread = $sp }
    }
    $bn = if ($brand.Trim()) { $brand.Trim() } else { (T '(non précisée)') }
    # Relecture de la finalisation : consigne selon l ecriture. Ecriture lente : case Mesurer la disquette decochee (sinon
    # Test-WriteLevelWanted ci-dessus) : la cocher. Ecriture rapide : jamais mesuree, case cochee ou non (Test-WriteLevelWanted
    # rend faux hors ecriture lente) : ecrire en ecriture lente, sans demander de cocher une case peut-etre deja cochee
    $how = if ($slow) { (T "cochez « Mesurer la disquette avant l'écriture lente », avec la mesure « sur l'image à écrire »") } else { (T "écrivez l'image en écriture lente, avec « Mesurer la disquette avant l'écriture lente » cochée et la mesure « sur l'image à écrire »") }
    $line = ''
    if ($spread -ge 0.2) { $line = (T "Les mesures de la marque « {0} » sur ce lecteur varient de {1} d'une disquette à l'autre : pour mesurer celle-ci avant l'écriture, {2}.") -f "$bn", (Format-UiNum $spread '0.00'), "$how" }
    elseif ($fam -eq 'long' -and [string]$src[0] -eq 'defaut' -and [string]$src[1] -eq 'defaut') { $line = (T "Aucun facteur mesuré pour la marque « {0} » sur ce lecteur : en long track, le meilleur facteur s'écarte souvent de 1 ; pour le mesurer, {1}.") -f "$bn", "$how" }
    if (-not $line) { return '' }
    if (Get-LevelWriteSkip $img $fmt $txtWTracks.Text) { return '' }
    try { if (-not (Test-ContentMeasurable $img $fmt).Ok) { return '' } } catch { return '' }
    return $line
}

function Get-WriteFactorNote([string]$path) {
    # Complement du libelle du profil Auto double densite (Update-PrecompForImage, T-C12) : facteur different de 1 que
    # recevrait une ecriture de l onglet (Get-WriteFactorPlan -Peek, ecriture lente ou rapide selon la case) ; vide avec un
    # facteur 1 (libelle de la v12.8) ; 12.10 : vide pour un lecteur cible (facteur 1, la courbe croisee est nommee entre les
    # parentheses du libelle : Get-WProfileSpec, 220)
    $wf = Get-WriteFactorPlan $path $cmbWFmt.Text ([bool]$chkWSlow.Checked) $null -Peek
    if (-not $wf.Apply) { return '' }
    if ($chkWSlow.Checked) {
        if ($wf.F0 -eq 1.0 -and $wf.F1 -eq 1.0) { return '' }
        return ((T " ; facteur appliqué à l'écriture : tête 0 × {0}, tête 1 × {1}") -f (Format-UiNum $wf.F0 '0.00'), (Format-UiNum $wf.F1 '0.00'))
    }
    if ($wf.FMean -eq 1.0) { return '' }
    return ((T " ; facteur appliqué à l'écriture rapide : × {0}, moyenne des deux têtes") -f (Format-UiNum $wf.FMean '0.00'))
}

function Update-WriteFactorNote {
    # Complement du libelle refait apres un changement du facteur (lecteur du bandeau), sans refaire le profil ni les champs
    # --precomp : seulement si le libelle est encore celui qu a pose Update-PrecompForImage
    $n = $script:WFactorNote
    if (-not $n -or [string]$lblWProfileInfo.Text -ne ([string]$n.Base + [string]$n.Note)) { return }
    $x = Get-WriteFactorNote $txtWFile.Text
    if ($x -eq [string]$n.Note) { return }
    $n.Note = $x; $lblWProfileInfo.Text = [string]$n.Base + $x
}

# --- Lecteur cible des ecritures (12.10, conception-croisee § 4) ------

function Get-DriveIds {
    # 12.10 : lecteurs de la liste du bandeau (codes du reglage drive, 040 : A, B, 0 a 3), source unique des lecteurs cibles ;
    # tableau protege par la virgule
    # 12.11 : lecteurs connus : les six connexions (lecteurs non enregistres), puis les lecteurs enregistres, dans l ordre
    # du registre ($script:DriveReg, 040 : noms lus par enumeration, sans fonction du module 112 ; la garde « registre non
    # vide » lit Count, qu aucun nom ne peut masquer : mots reserves de Test-DriveName). Registre vide ou absent : la
    # ligne de la 12.10
    if ($script:DriveReg -and $script:DriveReg.Count -gt 0) { return ,@(@([string[]]$script:SettingDefs['drive'].Codes) + @($script:DriveReg.GetEnumerator() | ForEach-Object { [string]$_.Key })) }
    return ,@([string[]]$script:SettingDefs['drive'].Codes)
}

function Get-TargetDrive([string]$src = '') {
    # 12.10 : lecteur cible des ecritures du lecteur source $src (vide : lecteur du bandeau) : '' sans lecteur cible (meme
    # lecteur), ou si le choix memorise est la source elle-meme ou un lecteur inconnu de la liste du bandeau (Get-DriveIds) ;
    # avant la creation de l etat (520 s execute avant 560) : ''
    if (-not $src) { $src = [string]$cmbDrive.Text }
    if (-not $src -or $null -eq $script:TargetDrives -or -not $script:TargetDrives.ContainsKey($src)) { return '' }
    $t = [string]$script:TargetDrives[$src]
    if (-not $t -or $t -eq $src -or (Get-DriveIds) -notcontains $t) { return '' }
    return $t
}

function Set-TargetDrive([string]$src, [string]$tgt) {
    # 12.10 : lecteur cible des ecritures du lecteur source : $tgt vide, egal a la source ou inconnu : entree retiree (meme
    # lecteur). Rend l ancien choix ('' : meme lecteur). Enregistre par Save-Config (write.targetDrive), comme les reglages
    $old = Get-TargetDrive $src
    if (-not $src) { return $old }
    if ($null -eq $script:TargetDrives) { $script:TargetDrives = @{} }
    if (-not $tgt -or $tgt -eq $src -or (Get-DriveIds) -notcontains $tgt) { [void]$script:TargetDrives.Remove($src) } else { $script:TargetDrives[$src] = $tgt }
    return $old
}

function Get-TargetDriveItems([string]$src) {
    # 12.10 : elements de la liste « Lecteur cible » : « (meme lecteur) », puis les lecteurs du bandeau sauf la source
    # (Get-CrossCalibTargets, 240, tableau protege par la virgule : entre parentheses, pas dans @()) ; tableau protege par
    # la virgule
    return ,@(@((T '(même lecteur)')) + (Get-CrossCalibTargets (Get-DriveIds) $src))
}

function Get-TargetCurves([string]$fam, [bool]$slow, [string]$src = '', [string]$tgt = '') {
    # 12.10 : courbes croisees « source>cible » de la famille appliquees a une ecriture pour le lecteur cible : par tete en
    # ecriture lente si elles sont presentes et au moins aussi recentes que la courbe commune, sinon la courbe commune
    # (Get-DriveFamilyCurves, 220). Courbes rendues une par une dans le pipeline : l appelant les recueille par @() (aucune
    # sans lecteur cible ou sans courbe croisee : tableau vide)
    if (-not $src) { $src = [string]$cmbDrive.Text }
    if (-not $tgt) { $tgt = Get-TargetDrive $src }
    if (-not $tgt) { return }
    $cv = Get-DriveFamilyCurves "$src>$tgt" $fam $slow
    foreach ($c in @($cv)) { if ($c) { $c } }
}

function Get-TargetCurvesText([string]$src, [string]$tgt, [string]$fam, $cvs) {
    # 12.10 : courbes croisees appliquees a une ecriture, dans les lignes de journal : « courbe croisee A → 0 (Standard 2 us,
    # test fin, 01/11/2026 17:49, calcul v12.10) », ou « courbes croisees A → 0 par tete (Standard 2 us, test fin, tete 0 du ...,
    # tete 1 du ..., calcul v12.10) » ; test (champ Test de la courbe) et calcul de la premiere courbe
    $l = @($cvs | Where-Object { $_ })
    if ($l.Count -eq 0) { return ((T 'aucune courbe croisée {0} → {1}') -f "$src", "$tgt") }
    $c0 = $l[0]
    $test = if ([string]$c0.Test -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
    $calc = Get-CurveCalcText $c0 -Plain
    if ($l.Count -ge 2) { return ((T "courbes croisées {0} → {1} par tête ({2}, {3}, tête 0 du {4}, tête 1 du {5}, calcul {6})") -f "$src", "$tgt", (Get-CalibFamilyName $fam), "$test", "$($c0.Date)", "$($l[1].Date)", "$calc") }
    return ((T "courbe croisée {0} → {1} ({2}, {3}, {4}, calcul {5})") -f "$src", "$tgt", (Get-CalibFamilyName $fam), "$test", "$($c0.Date)", "$calc")
}

function Get-WriteImageFamily([string]$img, [string]$fmt) {
    # 12.10 (relecture de la RC, fix2) : famille de calibration d une image ecrite en profil Auto, commune a l ecriture pour
    # un lecteur cible (Get-TargetWriteInfo : courbes croisees ecrites) et au bouton « Courbe » de l onglet Ecriture
    # (Update-CurveButton) : Get-ImageFamily (haute densite calibrable, cellule d un IPF ou d un HFE), puis pour un flux SCP
    # decode par un format, cellule mesuree par Get-ScpCellInfo (module d analyse present) sous le seuil des long tracks,
    # comme Update-PrecompForImage. Lit le fichier (appelants : fichier present, fenetre affichee)
    $f = Get-ImageFamily $img $fmt
    if ($f -eq 'std' -and $script:ScpStatsOk -and [System.IO.Path]::GetExtension($img).ToLower() -eq '.scp') {
        try { $ci = Get-ScpCellInfo $img; if ($ci -and [double]$ci.CellNs -lt $script:PrecompThresholdNs) { $f = 'long' } } catch { }
    }
    return $f
}

function Get-TargetWriteInfo([string]$img, [string]$fmt, [bool]$slow) {
    # 12.10 : lecteur cible d une ecriture de l onglet Ecriture (Start-ImageWrite, Get-WriteFactorPlan, Start-WriteTabWrite,
    # Start-PresetWrite, Get-TargetWriteBlock) : @{ Src (lecteur du bandeau, qui ecrit) ; Tgt (lecteur cible, '' : meme
    # lecteur) ; Applies (courbes croisees ecrites) ; Why (raison d un lecteur cible sans effet) ; Fam ; Curves (courbes
    # croisees appliquees, Get-TargetCurves) ; Block (raison du refus de l ecriture, '' sinon) }. Sans effet : profil Manuel
    # (champ de l utilisateur transmis tel quel), --precomp decoche, fichier absent, image a laquelle --precomp n est pas
    # transmis (flux ecrit tel quel, FM, GCR, codage propre : Start-ImageWrite). Famille : celle du profil force (standard,
    # long track), sinon celle de l image comme le mode Auto (Get-ImageFamily ; flux SCP : cellule mesuree par
    # Get-ScpCellInfo, comme Update-PrecompForImage). Refus : image haute densite en Auto (la calibration croisee n existe
    # qu en double densite), aucune courbe croisee « source>cible » de la famille (par tete a jour en ecriture lente, sinon
    # commune, comme Set-PrecompFields). Relecture de l etape 3 : ecriture rapide avec des courbes croisees par tete
    # seulement (calibration croisee faite avec « Ecriture lente » cochee) : refus qui le dit (avant : « aucune courbe
    # croisee... lancez Calibrer pour un lecteur cible », qu une calibration faite de meme n aurait pas leve). 12.10
    # (relecture de la RC) : BlockKind, nature du refus ('hd', 'head' : courbes par tete seulement, 'none' : aucune courbe
    # croisee ; '' sans refus) : refus annonce en tete du libelle du profil (Get-WTargetHead, 220)
    $src = [string]$cmbDrive.Text
    $r = @{ Src = $src; Tgt = (Get-TargetDrive $src); Applies = $false; Why = ''; Fam = ''; Curves = @(); Block = ''; BlockKind = '' }
    if (-not $r.Tgt) { return $r }
    if ($cmbWProfile.SelectedIndex -eq 3) { $r.Why = (T 'profil Manuel, champ --precomp transmis tel quel'); return $r }
    if (-not $chkWPrecomp.Checked) { $r.Why = (T 'précompensation désactivée'); return $r }
    if (-not $img -or -not (Test-Path -LiteralPath $img)) { return $r }
    if (Test-RawFluxWrite $img $fmt) { $r.Why = (T 'image flux écrite telle quelle, sans précompensation'); return $r }
    $ie = Get-ImageEncoding $img $fmt
    if ($ie.NonMfm) { $r.Why = (T 'image en codage {0}, écrite sans précompensation') -f "$($ie.Name)"; return $r }
    $r.Applies = $true
    $p = [int]$cmbWProfile.SelectedIndex
    if ($p -eq 1) { $r.Fam = 'std' }
    elseif ($p -eq 2) { $r.Fam = 'long' }
    elseif (Get-HighDensityReason $img $fmt) {
        $r.Block = (T "Écriture pour le lecteur cible {0} impossible en haute densité : la calibration croisée n'existe qu'en double densité (standard, long track). Choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture, ou le profil Manuel.") -f "$($r.Tgt)"; $r.BlockKind = 'hd'
        return $r
    } else {
        # 12.10 (relecture de la RC, fix2) : famille commune avec le bouton « Courbe » (Update-CurveButton)
        $r.Fam = Get-WriteImageFamily $img $fmt
    }
    $r.Curves = @(Get-TargetCurves $r.Fam $slow $src $r.Tgt)
    if ($r.Curves.Count -eq 0 -and -not $slow -and @(Get-TargetCurves $r.Fam $true $src $r.Tgt).Count -ge 2) { $r.Block = (T "Les courbes croisées {0} → {1} de la famille {2} sont par tête (calibration croisée faite avec « Écriture lente » cochée) : elles ne servent qu'à une écriture lente. Cochez « Écriture lente » dans l'onglet Écriture, ou choisissez « Écriture lente » dans la Bibliothèque ; pour une écriture rapide, relancez « Calibrer pour un lecteur cible… » avec « Écriture lente » décochée (courbe commune).") -f "$src", "$($r.Tgt)", (Get-CalibFamilyName $r.Fam); $r.BlockKind = 'head' }
    elseif ($r.Curves.Count -eq 0) { $r.Block = (T "Aucune courbe croisée {0} → {1} pour la famille {2} : lancez « Calibrer pour un lecteur cible… » (onglet Écriture, lecteur {0} dans le bandeau, lecteur cible {1}), ou choisissez « (même lecteur) » dans la liste « Lecteur cible ».") -f "$src", "$($r.Tgt)", (Get-CalibFamilyName $r.Fam); $r.BlockKind = 'none' }
    return $r
}

function Get-TargetWriteBlock([string]$img, [string]$fmt, [bool]$slow) {
    # 12.10 : raison du refus d une ecriture pour un lecteur cible (Test-TargetWriteAllowed, Start-RestoreWrite), '' quand
    # l ecriture est possible ou que le lecteur cible est sans effet sur elle (Get-TargetWriteInfo)
    return [string](Get-TargetWriteInfo $img $fmt $slow).Block
}

function Test-TargetWriteAllowed([string]$img, [string]$fmt, [bool]$slow) {
    # 12.10 : debut de Start-ImageWrite (bouton ECRIRE, Bibliotheque, restauration, fin d une calibration automatique) :
    # ecriture pour un lecteur cible refusee sans courbe croisee de la famille (Get-TargetWriteBlock) : fenetre
    # (Show-AppMessage, qui ecrit aussi le texte au journal, repondue par le banc), rien n est ecrit. Vrai quand l ecriture
    # continue
    $why = Get-TargetWriteBlock $img $fmt $slow
    if (-not $why) { return $true }
    # Finalisation 12.10 : refus note dans la surcharge d une operation de la Bibliotheque (avis de fin : Show-LibEndNotice)
    if ($script:OpOverride) { $script:OpOverride.Refused = $true }
    [void](Show-AppMessage ((T "Écriture refusée : {0}") -f "$why") (T 'Écriture refusée') 'OK' 'Warning')
    return $false
}

function Set-TargetDriveLayout {
    # 12.10 : positions de la liste « Lecteur cible » sur la ligne de la liste « Mesure : » : libelle 14 px apres la liste,
    # puis la liste, largeur du libelle mesuree dans la police de la fenetre (anglais compris) ; bas de la liste a celui de
    # la liste « Mesure : ». 12.10 (relecture des captures) : bas a 513 px, 3 px au-dessus du bas de l onglet (516 px a la
    # taille par defaut, journal replie) : pas de defilement ; a 517 px, la barre de defilement apparaissait
    if (-not $cmbWTarget -or -not $lblWTarget) { return }
    $x = $cmbWLevelMode.Right + 14
    $lblWTarget.Location = New-Object System.Drawing.Point($x, $lblWLevelMode.Top)
    $x += [System.Windows.Forms.TextRenderer]::MeasureText($lblWTarget.Text, $form.Font).Width + 6
    $cmbWTarget.Location = New-Object System.Drawing.Point($x, $cmbWLevelMode.Top)
}

function Update-TargetDriveUi {
    # 12.10 : liste « Lecteur cible » de l onglet Ecriture : elements (« (meme lecteur) », puis les lecteurs du bandeau sauf
    # celui du bandeau, la source : Get-TargetDriveItems) et choix memorise pour cette source (Get-TargetDrive), sous la
    # garde des liaisons (gestionnaire sans effet), infobulle, positions. Creation de l onglet (520), Load-Config,
    # Set-Defaults, changement de lecteur du bandeau (520, suivi d Update-SlowUi pour la case de la mesure)
    if (-not $cmbWTarget -or -not $lblWTarget) { return }
    $src = [string]$cmbDrive.Text
    $tgt = Get-TargetDrive $src
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        $items = [string[]](Get-TargetDriveItems $src)   # tableau protege par la virgule : pas de @() autour de l appel
        $cur = @($cmbWTarget.Items | ForEach-Object { [string]$_ })
        if (($cur -join "`n") -ne ($items -join "`n")) { $cmbWTarget.Items.Clear(); foreach ($it in $items) { [void]$cmbWTarget.Items.Add([string]$it) } }
        $i = 0
        if ($tgt) { $j = [array]::IndexOf([string[]]$items, $tgt); if ($j -gt 0) { $i = $j } }
        if ($cmbWTarget.SelectedIndex -ne $i) { $cmbWTarget.SelectedIndex = $i }
    } finally { $script:SettingSync = $sv }
    # 12.10 (relecture de la RC) : cas sans effet et refus (Get-TargetWriteInfo) dits dans l infobulle ; fix1 : refus de la
    # haute densite en profil Auto seulement (un profil force ecrit avec la courbe croisee de sa famille), codage propre
    # (M2FM, Data General) parmi les cas sans effet, famille du profil force
    $tt = (T "Lecteur qui relira la disquette écrite par le lecteur {0}, celui du bandeau.`n« (même lecteur) » : écriture ordinaire, avec la courbe du lecteur {0} et le facteur de marque.`nUn autre lecteur : l'image est écrite avec la courbe croisée « {0} → lecteur cible » mesurée par « Calibrer pour un lecteur cible… », telle quelle (facteur 1) ; sans courbe croisée pour la famille de l'image (ou du profil forcé), l'écriture est refusée. La mesure de la disquette avant l'écriture et la calibration automatique ne sont pas proposées (elles reliraient avec le lecteur {0}) ; le contrôle après écriture relit avec le lecteur {0}.`nSans effet sur l'écriture (le journal le dit) avec le profil Manuel, la case --precomp décochée, une image flux écrite telle quelle ou une image FM, GCR ou à codage propre ; écriture refusée en haute densité avec le profil Auto, et en écriture rapide quand les courbes croisées sont par tête seulement.`nLe choix est mémorisé pour le lecteur {0}.") -f "$src"
    $tip.SetToolTip($lblWTarget, $tt); $tip.SetToolTip($cmbWTarget, $tt)
    Set-TargetDriveLayout
    # 12.11 (L9) : libelle « Lecteur qui ecrit » du cadre 2, au-dessus de la liste (Update-WSourceLabel, 145)
    if ($lblWSource) { Update-WSourceLabel }
}

function Set-TargetDriveFromUi {
    # 12.10 : gestionnaire SelectedIndexChanged de la liste « Lecteur cible » : choix memorise pour le lecteur du bandeau
    # (Set-TargetDrive ; element 0 : meme lecteur), ligne de journal quand il change, case de la mesure (Update-SlowUi) et
    # profil de l image recalcule (Update-PrecompForImage : courbes croisees, ou courbes du lecteur). Rien sous la garde des
    # liaisons (Update-TargetDriveUi)
    if ($script:SettingSync -or -not $cmbWTarget) { return }
    $src = [string]$cmbDrive.Text
    if (-not $src) { return }
    $tgt = if ($cmbWTarget.SelectedIndex -gt 0) { [string]$cmbWTarget.SelectedItem } else { '' }
    $old = Set-TargetDrive $src $tgt
    $new = Get-TargetDrive $src
    if ($new -ne $old) {
        $same = (T '(même lecteur)')
        Append-Log ((T 'Lecteur cible des écritures du lecteur {0} : {1} (avant : {2}).') -f "$src", $(if ($new) { $new } else { $same }), $(if ($old) { $old } else { $same }))
    }
    Update-SlowUi
    Update-PrecompForImage $txtWFile.Text
}
