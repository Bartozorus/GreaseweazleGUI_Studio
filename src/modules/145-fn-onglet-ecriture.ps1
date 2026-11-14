# ============================== FONCTIONS : ONGLET ECRITURE ====================
# 12.11 (L9) : onglet Ecriture en trois etapes (cadre « 1. Image a ecrire », cadre « 2. Disquette et lecteur », bouton
# ECRIRE avec le lien et la ligne de ses options avancees), toujours visibles et a la meme place dans les deux vues ; le
# cadre « Options avancees » ($grpWAdv, 520) vient dessous, affiche avec la case « Mode expert » seulement. Une option
# avancee repliee garde sa valeur et son effet : le lien la compte, la ligne a droite du bouton la nomme
# (Get-WriteAdvChanges, seule decision). Controles crees par 520 ; positions « a la suite » posees ici, une fois la
# fenetre construite (600, apres Fit-ControlText) et a chaque changement de « Mode expert »
# 12.11 (L10) : la ligne a droite du bouton devient « Ce qui va se passer » (Get-WritePlan) : lecteur qui ecrit,
# effacement, mesure de la disquette, tetes, controle, lecteur cible, options avancees ; un refus la remplace. Chaque
# segment vient de la fonction qui decide l ecriture (140, 260) ; plan garde en memoire par signature des entrees
# (Get-WritePlanCached) ; coupe qui ne retire que des segments descriptifs (Show-WritePlan)

function Get-WriteAdvDefs {
    # 12.11 (L9) : options avancees de l ecriture, dans l ordre du cadre : @{ Ctl (controle) ; Def (valeur par defaut :
    # case, nombre, rang de la liste ou texte) ; Label (libelle qui la nomme, cle du libelle de 520 ; case : son propre
    # texte) }. Valeurs par defaut de Set-Defaults (120) ; reglages lies (profil, prechauffages et leur duree) : celles de
    # $script:SettingDefs (040). Les champs --precomp n y sont pas : le profil les remplit. Table rendue a l appel : les
    # controles n existent qu apres 520
    $pp = [array]::IndexOf([string[]]$script:SettingDefs['precompProfile'].Codes, [string]$script:SettingDefs['precompProfile'].Def)
    return @(
        @{ Ctl = $chkWEraseEmpty; Def = $true; Label = '' }
        @{ Ctl = $chkWNoVerify; Def = $false; Label = '' }
        @{ Ctl = $numWRetries; Def = 10; Label = (T 'Essais :') }
        @{ Ctl = $numWRepair; Def = 3; Label = (T 'Passes de réécriture :') }
        @{ Ctl = $cmbWProfile; Def = $pp; Label = (T 'Profil précomp. :') }
        @{ Ctl = $chkWPrecomp; Def = $true; Label = '' }
        @{ Ctl = $txtWTracks; Def = ''; Label = (T 'Pistes :') }
        @{ Ctl = $cmbWDensel; Def = 0; Label = (T 'Densel :') }
        @{ Ctl = $txtWFakeIdx; Def = ''; Label = (T 'Fake index :') }
        @{ Ctl = $chkWReverse; Def = $false; Label = '' }
        @{ Ctl = $txtWDiskdefs; Def = ''; Label = (T 'Diskdefs :') }
        @{ Ctl = $chkWHard; Def = $false; Label = '' }
        @{ Ctl = $chkWTG43; Def = $false; Label = '' }
        @{ Ctl = $chkWWarm; Def = [bool]$script:SettingDefs['warmSlowWrite'].Def; Label = '' }
        @{ Ctl = $chkWCalWarm; Def = [bool]$script:SettingDefs['warmFullCalib'].Def; Label = '' }
        @{ Ctl = $numWWarmMin; Def = [double]$script:SettingDefs['warmMinutes'].Def; Label = (T 'Durée du préchauffage :') }
    )
}

function Get-WriteAdvChanges {
    # 12.11 (L9) : options avancees differentes de leur valeur par defaut (Get-WriteAdvDefs), seule decision du compte du
    # lien et des noms de la ligne a droite du bouton ECRIRE (Update-WAdvLink), dans les deux vues : une option repliee
    # s applique quand meme. Rend leurs noms, dans l ordre du cadre : case cochee, son texte ; case decochee, son texte
    # suivi de « : decochee » ; liste, nombre ou champ, son libelle et sa valeur (« Pistes : c=0-39 »). Champs compares
    # sans les espaces des bords, comme Start-ImageWrite et Get-WriteFormatArgs (140) les transmettent. Noms rendus un a un :
    # l appelant les recueille par @()
    $names = @()
    foreach ($d in @(Get-WriteAdvDefs)) {
        $c = $d.Ctl
        if (-not $c) { continue }
        if ($c -is [System.Windows.Forms.CheckBox]) {
            if ([bool]$c.Checked -eq [bool]$d.Def) { continue }
            $n = ([string]$c.Text).TrimEnd(' ', ':')
            $names += $(if ($c.Checked) { $n } else { (T '{0} : décochée') -f $n })
        } elseif ($c -is [System.Windows.Forms.NumericUpDown]) {
            if ([double]$c.Value -eq [double]$d.Def) { continue }
            $v = if ([object]::ReferenceEquals($c, $numWWarmMin)) { Get-WarmMinutesText ([double]$c.Value) } else { [string]$c.Value }
            $names += ('{0} {1}' -f [string]$d.Label, $v)
        } elseif ($c -is [System.Windows.Forms.ComboBox]) {
            if ([int]$c.SelectedIndex -eq [int]$d.Def) { continue }
            $names += ('{0} {1}' -f [string]$d.Label, [string]$c.Text)
        } else {
            $v = ([string]$c.Text).Trim()
            if ($v -eq [string]$d.Def) { continue }
            $names += ('{0} {1}' -f [string]$d.Label, $v)
        }
    }
    return $names
}

function Update-WAdvLink([switch]$Typing) {
    # 12.11 (L9) : texte du lien des options avancees : « Masquer les options avancees » quand elles sont affichees (case
    # « Mode expert »), sinon « Options avancees… », avec le compte des options modifiees. Appels : changement d une option
    # avancee (gestionnaires de Register-WAdvCtl), Set-WriteTabLayout. 12.11 (L10) : ligne a droite du bouton ECRIRE par
    # Update-WritePlanUi (« Ce qui va se passer », ou, sans image, les options modifiees nommees, texte du lot L9) ;
    # Typing : frappe dans un champ ou texte d une case change, la phrase deja affichee n est pas recalculee
    if (-not $lnkWAdv -or -not $lblWPlan) { return }
    $ch = @(Get-WriteAdvChanges)
    $lnkWAdv.Text = if ($chkExpert.Checked) { (T 'Masquer les options avancées') } elseif ($ch.Count -gt 0) { (T 'Options avancées : {0} modifiée(s)…') -f "$($ch.Count)" } else { (T 'Options avancées…') }
    Update-WritePlanUi -Typing:$Typing
}

function Update-WPlanTip {
    # 12.11 (L9) : texte complet de la ligne a droite du bouton ECRIRE en infobulle quand il depasse ses trois lignes,
    # aucune infobulle sinon (texte ou taille changes : 520), comme Update-WProfileTip (140). 12.11 (L10) : phrase dont la
    # coupe a retire des segments (Show-WritePlan) : texte complet en infobulle
    $full = [string]$script:WPlanFull
    if ($full -and [string]$lblWPlan.Text -cne $full) { $tip.SetToolTip($lblWPlan, $full); return }
    $h = $lblWPlan.GetPreferredSize((New-Object System.Drawing.Size($lblWPlan.Width, 0))).Height
    $tip.SetToolTip($lblWPlan, $(if ($h -gt $lblWPlan.Height) { [string]$lblWPlan.Text } else { '' }))
}

function Register-WAdvCtl($c) {
    # 12.11 (L9) : gestionnaire ajoute a une option avancee (520) : lien et ligne a jour a chaque changement de sa valeur,
    # et de son texte pour une case (texte de l ecriture lente, duree du prechauffage) ; sans effet sur la valeur. 12.11
    # (L10) : texte d une case (Update-SlowUi, qui finit par Update-WLevelUi) et frappe dans un champ : lien seul tant que
    # la phrase est affichee (Typing) ; champ quitte : phrase recalculee
    if ($c -is [System.Windows.Forms.CheckBox]) { $c.Add_CheckedChanged({ Update-WAdvLink }); $c.Add_TextChanged({ Update-WAdvLink -Typing }) }
    elseif ($c -is [System.Windows.Forms.NumericUpDown]) { $c.Add_ValueChanged({ Update-WAdvLink }) }
    elseif ($c -is [System.Windows.Forms.ComboBox]) { $c.Add_SelectedIndexChanged({ Update-WAdvLink }) }
    elseif ($c -is [System.Windows.Forms.TextBox]) { $c.Add_TextChanged({ Update-WAdvLink -Typing:([bool]$this.Focused) }); $c.Add_Leave({ Update-WritePlanUi }) }
}

function Register-WPlanCtl($c) {
    # 12.11 (L10) : gestionnaire ajoute a un controle de l onglet qui change l ecriture sans passer par Update-WLevelUi
    # (520) : case « Effacer avant d ecrire », case « Controler toutes les pistes », champs --precomp ; frappe dans un champ :
    # phrase recalculee quand il est quitte ; champs remplis par Update-PrecompForImage (WProfileBuilding) : phrase
    # recalculee une fois, par Update-WLevelUi a sa sortie
    if ($c -is [System.Windows.Forms.CheckBox]) { $c.Add_CheckedChanged({ Update-WritePlanUi }) }
    elseif ($c -is [System.Windows.Forms.TextBox]) { $c.Add_TextChanged({ Update-WritePlanUi -Typing:([bool]$this.Focused) }); $c.Add_Leave({ Update-WritePlanUi }) }
}

function Get-WritePlan {
    # 12.11 (L10, specification « onglet-ecriture » § 2.5, corrigee par B1 du plan) : ce que ferait le bouton ECRIRE
    # (Start-WriteTabWrite) avec l onglet tel qu il est : @{ Refuse ; Segs }. Refuse : texte d un refus connu, dans l ordre
    # ou le clic les rencontre (fichier image absent, Start-ImageWrite ; lecteur cible, Get-TargetWriteInfo ; « Test
    # rapide » sans reference, Get-LevelBeforeWritePlan ; tetes, Get-WriteHeads) : il remplace la phrase. Segs : segments
    # @{ T ; Crit }, dans l ordre : lecteur qui ecrit (Get-WriteSourceText), effacement (Get-WriteErasePlan), mesure
    # (Get-WriteLevelPlan puis Get-LevelBeforeWritePlan : texte de la liste « Mesure : » de la mesure faite), tetes
    # (Get-WriteHeads), controle (Get-WriteCheckPlan, sur les profils de Get-WriteSpecPlan et Get-WriteHeadSpecs), lecteur
    # cible (Get-TargetWriteInfo, Get-TargetCurvesText), options avancees (Get-WriteAdvChanges). Crit : mesure refusee
    # (sans mesure, avec sa raison), mesure autre que celle de la liste (repli), controle impose ou non applicable, lecteur
    # cible sans effet : jamais retires par la coupe ; S, leur forme courte (le fait sans sa raison). Aucune ligne de
    # journal, aucune fenetre ; lit l image (appelant : Get-WritePlanCached)
    $img = [string]$txtWFile.Text; $fmt = [string]$cmbWFmt.Text
    $slow = [bool]$chkWSlow.Checked
    $mode = if ($slow) { 'slow' } else { 'fast' }
    $userTs = ([string]$txtWTracks.Text).Trim()
    $r = @{ Refuse = ''; Segs = @() }
    $ex = $false; try { $ex = [bool](Test-Path -LiteralPath $img) } catch { }
    if (-not $ex) { $r.Refuse = (T 'Fichier image introuvable.'); return $r }
    $tw = Get-TargetWriteInfo $img $fmt $slow
    if ($tw.Block) { $r.Refuse = (T "Écriture refusée : {0}") -f "$($tw.Block)"; return $r }
    $wp = Get-WriteLevelPlan $img $fmt $mode
    $lp = $null
    if ($wp.Kind -ne 'none') {
        $lp = Get-LevelBeforeWritePlan ([string]$wp.LbMode) $false ([bool]$wp.LbMeasure)
        if ($lp.Refuse) { $r.Refuse = (T "Écriture refusée : le test rapide n'a pas de référence utilisable pour cette image ({0}).") -f "$($lp.Why)"; return $r }
    }
    $wh = Get-WriteHeads $img $userTs $slow ([bool]$chkWEraseEmpty.Checked)
    if ($wh.Err) { $r.Refuse = ([string]$wh.Err).Replace("`n", ' '); return $r }
    $sg = New-Object System.Collections.ArrayList
    [void]$sg.Add(@{ T = (Get-WriteSourceText); Crit = $false })
    # Effacement
    $ep = Get-WriteErasePlan $img $fmt $userTs ([int[]]@($wh.Heads)) ([bool]$chkWPreErase.Checked)
    $et = if ($ep.Mode -eq 'hfreq') { (T 'effacement haute fréquence des pistes') } elseif ($ep.Mode -eq 'pre') { (T 'pré-effacement de chaque piste') } else { (T 'sans effacement') }
    [void]$sg.Add(@{ T = $et; Crit = $false })
    # Mesure de la disquette : omise quand aucune n est demandee. Forme courte d un segment critique (S, sans sa raison) :
    # employee par la coupe quand les segments critiques ne tiennent pas entiers (Show-WritePlan)
    $mt = ''; $mc = $true; $ms = ''; $nw = ''
    $sk = [string]$wp.Skip
    if ($sk -eq 'target') { if ($wp.Asked) { $nw = (T 'lecteur cible {0}') -f "$($wp.Tgt)" } }
    elseif ($sk -eq 'flux') { $nw = (T 'image flux') }
    elseif ($sk -eq 'nonmfm') { $nw = (T 'image en codage {0}') -f "$((Get-ImageEncoding $img $fmt).Name)" }
    elseif ($sk -eq 'kind') { $nw = (T 'image non calibrable') }
    elseif ($sk -eq 'hd') { $nw = (T 'haute densité') }
    elseif ($sk -eq 'profile') { $nw = (T 'profil « {0} »') -f "$($cmbWProfile.Text)" }
    elseif ($sk -eq 'precomp') { $nw = (T 'précompensation désactivée') }
    elseif ($sk -eq 'tracks') { $nw = (T 'champ Pistes') }
    elseif ($sk -eq 'face') { $nw = (T 'image à une seule face') }
    elseif (-not $sk -and $lp) {
        if ($lp.Kind -eq 'none') { $nw = [string]$lp.Why }
        else {
            $kt = Get-SettingText 'levelBeforeWriteMode' ([string]$lp.Kind)
            if ($lp.Cm -and $lp.Kind -ne 'content') {
                $mt = (T "mesure de la disquette : {0}, au lieu de la mesure sur l'image ({1})") -f "$kt", "$($lp.Cm.Why)"
                $ms = (T "mesure de la disquette : {0}, au lieu de la mesure sur l'image") -f "$kt"
            } else { $mt = (T 'mesure de la disquette : {0}') -f "$kt" }
            $mc = ([string]$lp.Kind -ne [string](Get-Setting 'levelBeforeWriteMode'))
        }
    }
    if ($nw) { $mt = (T 'sans mesure de la disquette ({0})') -f "$nw"; $ms = (T 'sans mesure de la disquette') }
    if ($mt) { [void]$sg.Add(@{ T = $mt; Crit = $mc; S = $ms }) }
    # Tetes
    $hs = @($wh.Heads)
    $ht = if (-not $slow) { (T 'écriture des deux têtes ensemble') } elseif ($hs.Count -eq 1) { (T 'écriture de la tête {0} seule') -f "$($hs[0])" } elseif ($hs.Count -ge 2) { (T 'écriture tête 0 puis tête 1') } else { '' }
    if ($ht) { [void]$sg.Add(@{ T = $ht; Crit = $false }) }
    # Controle : profils transmis par Start-ImageWrite (avant le facteur), pour la courbe adaptee qui l impose ; drapeau
    # de la calibration rapide qui precede (LevelPostForce), lu comme Start-ImageWrite le lit
    $sp = Get-WriteSpecPlan $img $fmt $slow (Get-ImageEncoding $img $fmt)
    $hr = if ($slow) { Get-WriteHeadSpecs $userTs $sp.P0 $sp.P1 } else { $null }
    $cp = Get-WriteCheckPlan $img $fmt $slow $wh.Heads $hr $sp.P0 ([bool]$script:LevelPostForce)
    $rep = [int]$numWRepair.Value
    if ($cp.Blocker) { [void]$sg.Add(@{ T = ((T 'contrôle de toutes les pistes non applicable ({0})') -f "$($cp.Blocker)"); Crit = $true; S = (T 'contrôle de toutes les pistes non applicable') }) }
    elseif ($cp.Forced -and -not $chkWPostCheck.Checked) { [void]$sg.Add(@{ T = $(if ($rep -gt 0) { (T 'contrôle de toutes les pistes imposé par la courbe adaptée à cette disquette, {0} passe(s) de réécriture au plus') -f "$rep" } else { (T 'contrôle de toutes les pistes imposé par la courbe adaptée à cette disquette, sans réécriture') }); Crit = $true; S = (T 'contrôle de toutes les pistes imposé') }) }
    elseif ($cp.Post) { [void]$sg.Add(@{ T = $(if ($rep -gt 0) { (T 'contrôle de toutes les pistes, {0} passe(s) de réécriture au plus') -f "$rep" } else { (T 'contrôle de toutes les pistes, sans réécriture') }); Crit = $false }) }
    else { [void]$sg.Add(@{ T = (T 'contrôle complet non demandé'); Crit = $false }) }
    # Lecteur cible : courbes croisees ecrites (texte du journal de Start-ImageWrite), ou sans effet (meme texte)
    if ($tw.Applies) { [void]$sg.Add(@{ T = ((T 'pour le lecteur cible {0} : {1}') -f "$($tw.Tgt)", (Get-TargetCurvesText ([string]$tw.Src) ([string]$tw.Tgt) ([string]$tw.Fam) $tw.Curves)); Crit = $false }) }
    elseif ($tw.Tgt -and $tw.Why) {
        $x = (T "Lecteur cible {0} sans effet sur cette écriture : {1}.") -f "$($tw.Tgt)", "$($tw.Why)"
        if ($x.EndsWith('.')) { $x = $x.Substring(0, $x.Length - 1) }
        [void]$sg.Add(@{ T = ($x.Substring(0, 1).ToLower() + $x.Substring(1)); Crit = $true; S = ((T 'lecteur cible {0} sans effet') -f "$($tw.Tgt)") })
    }
    # Options avancees modifiees (le lien les compte)
    $ch = @(Get-WriteAdvChanges)
    if ($ch.Count -gt 0) { [void]$sg.Add(@{ T = ((T 'options avancées : {0}') -f ($ch -join ', ')); Crit = $false }) }
    $r.Segs = @($sg)
    return $r
}

function Get-WritePlanSig {
    # 12.11 (L10) : signature des entrees de Get-WritePlan, cle de la memoire de Get-WritePlanCached : langue ; image, sa
    # taille et sa date (un seul acces au fichier, Get-Item : racine reseau possible) ; format ; lecteur du bandeau et son
    # libelle (Get-DriveLabel : identite et connexion) ; lecteur cible ; cases, listes et champs de l onglet qui changent
    # l ecriture ou la phrase (dont la liste « Calibration precomp » et la liste « Mesure : », par leurs reglages) ; options
    # avancees modifiees ; restauration en cours ; controle impose par la calibration rapide qui precede (LevelPostForce) ;
    # module d analyse SCP ; borne precompMaxNs ; courbes du magasin par
    # lecteur et de la vue du lecteur courant (cle, date, lecteur, methode, nombre de valeurs) ; courbes adaptees des
    # calibrations rapides (cle, modele, profil)
    $img = [string]$txtWFile.Text
    $fi = 'absent'
    try { $it = Get-Item -LiteralPath $img -ErrorAction Stop; $fi = "$($it.GetType().Name)|$($it.Length)|$($it.LastWriteTimeUtc.Ticks)" } catch { }
    $cv = New-Object System.Text.StringBuilder
    foreach ($st in @($script:DriveCurves, $script:PrecompCurves)) {
        if ($st) { foreach ($k in @(@($st.Keys) | Sort-Object)) { $c = $st[$k]; if ($c) { [void]$cv.Append("$k=$($c.Date)|$($c.Drive)|$($c.Method)|$(@($c.Values).Count);") } } }
        [void]$cv.Append('#')
    }
    $ls = ''
    if ($script:LevelShifts) { $ls = (@(@($script:LevelShifts.Keys) | Sort-Object | ForEach-Object { $x = $script:LevelShifts[$_]; if ($x) { "$_=$($x.Model)|$($x.Spec)|$(@($x.Values).Count)" } }) -join ';') }
    $rs = if ($script:Restore) { "1|$(if ($script:Restore.Saved) { $script:Restore.Saved.CalMode })" } else { '0' }
    $rs += "|$([bool]$script:LevelPostForce)"
    $parts = @([string]$script:Lang, $img, $fi, [string]$cmbWFmt.Text, [string]$cmbDrive.Text, (Get-DriveLabel ([string]$cmbDrive.Text)), (Get-TargetDrive),
               "$($chkWSlow.Checked)|$($chkWPreErase.Checked)|$($chkWEraseEmpty.Checked)|$($chkWPostCheck.Checked)|$($numWRepair.Value)|$($chkWLevel.Checked)|$($cmbWCalMode.SelectedIndex)",
               "$($cmbWProfile.SelectedIndex)|$($chkWPrecomp.Checked)|$($chkWHard.Checked)|$($chkWTG43.Checked)", [string]$txtWPrecomp.Text, [string]$txtWPrecomp1.Text, [string]$txtWTracks.Text, [string]$cmbWDensel.Text,
               [string](Get-Setting 'calMode'), [string](Get-Setting 'levelBeforeWriteMode'), (@(Get-WriteAdvChanges) -join '|'),
               $rs, "$($script:ScpStatsOk)|$($script:CalHardNsUser)", $cv.ToString(), $ls)
    return ($parts -join "`n")
}

function Get-WritePlanCached {
    # 12.11 (L10) : plan de la ligne (Get-WritePlan) garde en memoire avec la signature de ses entrees (Get-WritePlanSig) :
    # recalcule seulement quand l une d elles change (image remplacee ou modifiee, format, lecteur ou sa connexion, lecteur
    # cible, reglages de l onglet, courbes) ; sinon, un seul acces au fichier (date de l image)
    $sig = Get-WritePlanSig
    if ($script:WPlanMemo -and [string]$script:WPlanMemo.Sig -ceq $sig) { return $script:WPlanMemo.Plan }
    $p = Get-WritePlan
    $script:WPlanMemo = @{ Sig = $sig; Plan = $p }
    return $p
}

function Format-WritePlan($segs, [switch]$Cut) {
    # 12.11 (L10) : phrase de la ligne : segments separes par « ; », majuscule au premier ; Cut : segments retires par la
    # coupe, phrase finie par « ; … » (texte complet en infobulle)
    $j = (@(@($segs) | ForEach-Object { [string]$_.T }) -join (T ' ; '))
    if ($j.Length -gt 0) { $j = $j.Substring(0, 1).ToUpper() + $j.Substring(1) }
    if ($Cut) { return ((T 'Ce qui va se passer : {0} ; …') -f $j) }
    return ((T 'Ce qui va se passer : {0}.') -f $j)
}

function Get-WPlanHeight([string]$t) {
    # 12.11 (L10) : hauteur du texte $t dans la ligne (meme police, meme largeur, memes options de dessin que $lblWPlan),
    # mesuree sur un libelle de mesure jamais affiche ni ajoute a la fenetre, comme Update-WPlanTip mesure la ligne
    if (-not $script:WPlanMeasure) { $script:WPlanMeasure = New-Object System.Windows.Forms.Label }
    $m = $script:WPlanMeasure
    $m.Font = $lblWPlan.Font; $m.UseMnemonic = $lblWPlan.UseMnemonic; $m.AutoEllipsis = $lblWPlan.AutoEllipsis
    $m.Text = $t
    return $m.GetPreferredSize((New-Object System.Drawing.Size($lblWPlan.Width, 0))).Height
}

function Show-WritePlan {
    # 12.11 (L10) : affiche le plan courant ($script:WPlanCur) dans la ligne, a sa largeur (appel aussi au changement de
    # taille, 520 : sans recalcul du plan). Refus : seul, a l encre d avertissement, en tete ; ses derniers mots peuvent
    # passer sous les points de suspension, texte complet en infobulle. Phrase : entiere si elle tient dans les trois
    # lignes ; sinon, segments descriptifs retires du dernier au premier jusqu a ce qu elle tienne, jamais un segment
    # critique (Crit : mesure refusee ou repliee, controle impose ou non applicable, lecteur cible sans effet) ; s ils ne
    # tiennent pas encore, segments critiques ramenes a leur forme courte (S : le fait sans sa raison), du dernier au
    # premier ; phrase finie par « ; … » et texte complet en infobulle (Update-WPlanTip)
    if (-not $lblWPlan) { return }
    $p = $script:WPlanCur
    if (-not $p) { Update-WPlanTip; return }
    if ($p.Refuse) {
        $full = [string]$p.Refuse; $shown = $full
        $lblWPlan.ForeColor = $script:Theme.WarnInk
    } else {
        $segs = @($p.Segs)
        $full = Format-WritePlan $segs
        $shown = $full
        if ((Get-WPlanHeight $full) -gt $lblWPlan.Height) {
            $keep = New-Object System.Collections.ArrayList
            foreach ($s in $segs) { [void]$keep.Add($s) }
            for ($i = $keep.Count - 1; $i -ge 0 -and $keep.Count -gt 1; $i--) {
                if ($keep[$i].Crit) { continue }
                $keep.RemoveAt($i)
                $shown = Format-WritePlan @($keep) -Cut
                if ((Get-WPlanHeight $shown) -le $lblWPlan.Height) { break }
            }
            for ($i = $keep.Count - 1; $i -ge 0 -and (Get-WPlanHeight $shown) -gt $lblWPlan.Height; $i--) {
                if (-not $keep[$i].Crit -or -not $keep[$i].S) { continue }
                $keep[$i] = @{ T = [string]$keep[$i].S; Crit = $true; S = '' }
                $shown = Format-WritePlan @($keep) -Cut
            }
        }
        $lblWPlan.ResetForeColor()
    }
    $script:WPlanFull = $full
    if ($lblWPlan.Text -cne $shown) { $lblWPlan.Text = $shown } else { Update-WPlanTip }
}

function Update-WritePlanUi([switch]$Typing) {
    # 12.11 (L10) : ligne a droite du bouton ECRIRE. Avant l affichage de la fenetre (aucun acces au fichier au demarrage,
    # racine reseau possible, comme Update-WLevelUi) ou sans image : options avancees modifiees seules, texte du lot L9
    # (« Options avancees : Sans verification. », vide sans option modifiee). Sinon : plan de Get-WritePlanCached, affiche
    # par Show-WritePlan. Typing (frappe dans un champ) ou profil en cours de calcul (Update-PrecompForImage, qui finit par
    # Update-WLevelUi) : phrase deja affichee gardee. Erreur du calcul : texte du lot L9, rien au journal ni a l ecran
    # ($script:WPlanError la garde). Appels : fin d Update-WLevelUi (140), Update-WAdvLink, Register-WAdvCtl,
    # Register-WPlanCtl
    if (-not $lblWPlan) { return }
    if ($script:UiReady -and [string]$txtWFile.Text) {
        if (($Typing -or $script:WProfileBuilding) -and $script:WPlanCur) { return }
        $p = $null
        try { $p = Get-WritePlanCached; $script:WPlanError = '' } catch { $script:WPlanError = [string]$_.Exception.Message; $script:WPlanMemo = $null }
        if ($p) { $script:WPlanCur = $p; Show-WritePlan; return }
    }
    $script:WPlanCur = $null; $script:WPlanFull = ''
    $ch = @(Get-WriteAdvChanges)
    $t = ''
    if ($ch.Count -gt 0) {
        $t = (T 'options avancées : {0}') -f ($ch -join ', ')
        $t = $t.Substring(0, 1).ToUpper() + $t.Substring(1) + '.'
    }
    $lblWPlan.ResetForeColor()
    if ($lblWPlan.Text -cne $t) { $lblWPlan.Text = $t } else { Update-WPlanTip }
}

function Switch-WAdvView {
    # 12.11 (L9) : clic du lien des options avancees : inverse la case « Mode expert » du bandeau (reglage ui.expert de la
    # configuration, qui affiche aussi les onglets techniques), sauf quand elle est inactive (restauration en cours, 300)
    if (-not $chkExpert.Enabled) { return }
    $chkExpert.Checked = -not $chkExpert.Checked
}

function Update-WSourceLabel {
    # 12.11 (L9, decision DL4) : libelle « Lecteur qui ecrit » du cadre « 2. Disquette et lecteur » : texte de
    # Get-WriteSourceText (112 : lecteur du bandeau, nom et connexion de sa fiche), sur la ligne du titre du cadre, aligne
    # sur son bord droit (ancre a droite : il suit la largeur de la fenetre). Appel : Update-TargetDriveUi (140), au
    # changement de lecteur du bandeau, a Load-Config, a Set-Defaults et apres une action de la fenetre « Lecteurs
    # enregistres » (connexion changee sans que le texte du bandeau change)
    if (-not $lblWSource -or -not $grpWOpt) { return }
    $lblWSource.Text = Get-WriteSourceText
    $lblWSource.Left = $grpWOpt.DisplayRectangle.Right - $lblWSource.PreferredWidth
}

function Set-WriteTabLayout {
    # 12.11 (L9) : disposition de l onglet Ecriture. Places a la suite, mesurees dans la police de la fenetre : rangee 1
    # du cadre 2 (quatre cases, 24 px entre elles), liste « Mesure : » apres son libelle, liste « Lecteur cible »
    # (Set-TargetDriveLayout, 140), libelle du lecteur qui ecrit (Update-WSourceLabel) ; champs des options avancees apres
    # leur libelle, cases du materiel apres le bouton de « Diskdefs : ». Vue : cadre des options avancees affiche avec
    # « Mode expert » (seule difference entre les deux vues),
    # lien et ligne (Update-WAdvLink), onglet remis en haut. Seules les places dans les cadres changent : cadres, bouton,
    # lien et ligne gardent celles de 520 (un onglet defile ne decale rien). Appels : demarrage (600, apres Fit-ControlText,
    # qui fixe la largeur des cases), changement de « Mode expert » (520)
    if (-not $grpWAdv -or -not $lnkWAdv) { return }
    $f = $form.Font
    $x = 12
    foreach ($c in @($chkWPreErase, $chkWSlow, $chkWPostCheck, $chkWUnattended)) {
        $c.Location = New-Object System.Drawing.Point($x, 22)
        $x += $c.PreferredSize.Width + 24
    }
    $cmbWLevelMode.Left = $lblWLevelMode.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWLevelMode.Text, $f).Width + 8
    Set-TargetDriveLayout
    Update-WSourceLabel
    $numWRetries.Left = $lblWRetries.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWRetries.Text, $f).Width + 6
    $numWRepair.Left = $lblWRepair.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWRepair.Text, $f).Width + 6
    # Rangee de « Diskdefs : » : cases du materiel a 8 px du bouton et l une de l autre ; en mode expert, l onglet defile a
    # la taille par defaut et sa barre verticale retire 17 px au cadre : la case TG43 tient dans le cadre (maquette : 314 et
    # 525, case TG43 coupee de 5 px par la barre)
    $chkWHard.Left = $btnWDiskdefs.Right + 8
    $chkWTG43.Left = $chkWHard.Left + $chkWHard.PreferredSize.Width + 8
    $numWWarmMin.Left = $lblWWarmMin.Left + [System.Windows.Forms.TextRenderer]::MeasureText($lblWWarmMin.Text, $f).Width + 8
    $lblWWarmMinU.Left = $numWWarmMin.Right + 6
    $grpWAdv.Visible = [bool]$chkExpert.Checked
    Update-WAdvLink
    $tabW.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
}
