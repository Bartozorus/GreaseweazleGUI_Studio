# ============================== FONCTIONS : ONGLET ECRITURE ====================
# 12.11 (L9) : onglet Ecriture en trois etapes (cadre « 1. Image a ecrire », cadre « 2. Disquette et lecteur », bouton
# ECRIRE avec le lien et la ligne de ses options avancees), toujours visibles et a la meme place dans les deux vues ; le
# cadre « Options avancees » ($grpWAdv, 520) vient dessous, affiche avec la case « Mode expert » seulement. Une option
# avancee repliee garde sa valeur et son effet : le lien la compte, la ligne a droite du bouton la nomme
# (Get-WriteAdvChanges, seule decision). Controles crees par 520 ; positions « a la suite » posees ici, une fois la
# fenetre construite (600, apres Fit-ControlText) et a chaque changement de « Mode expert »

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

function Update-WAdvLink {
    # 12.11 (L9) : texte du lien des options avancees : « Masquer les options avancees » quand elles sont affichees (case
    # « Mode expert »), sinon « Options avancees… », avec le compte des options modifiees ; ligne a droite du bouton
    # ECRIRE : leurs noms (« Options avancees : Sans verification, Pistes : c=0-39. »), vide sans option modifiee. Appels :
    # changement d une option avancee (gestionnaires de Register-WAdvCtl), Set-WriteTabLayout
    if (-not $lnkWAdv -or -not $lblWPlan) { return }
    $ch = @(Get-WriteAdvChanges)
    $lnkWAdv.Text = if ($chkExpert.Checked) { (T 'Masquer les options avancées') } elseif ($ch.Count -gt 0) { (T 'Options avancées : {0} modifiée(s)…') -f "$($ch.Count)" } else { (T 'Options avancées…') }
    $t = ''
    if ($ch.Count -gt 0) {
        $t = (T 'options avancées : {0}') -f ($ch -join ', ')
        $t = $t.Substring(0, 1).ToUpper() + $t.Substring(1) + '.'
    }
    if ($lblWPlan.Text -cne $t) { $lblWPlan.Text = $t }
}

function Update-WPlanTip {
    # 12.11 (L9) : texte complet de la ligne a droite du bouton ECRIRE en infobulle quand il depasse ses trois lignes,
    # aucune infobulle sinon (texte ou taille changes : 520), comme Update-WProfileTip (140)
    $h = $lblWPlan.GetPreferredSize((New-Object System.Drawing.Size($lblWPlan.Width, 0))).Height
    $tip.SetToolTip($lblWPlan, $(if ($h -gt $lblWPlan.Height) { [string]$lblWPlan.Text } else { '' }))
}

function Register-WAdvCtl($c) {
    # 12.11 (L9) : gestionnaire ajoute a une option avancee (520) : lien et ligne a jour a chaque changement de sa valeur,
    # et de son texte pour une case (texte de l ecriture lente, duree du prechauffage) ; sans effet sur la valeur
    if ($c -is [System.Windows.Forms.CheckBox]) { $c.Add_CheckedChanged({ Update-WAdvLink }); $c.Add_TextChanged({ Update-WAdvLink }) }
    elseif ($c -is [System.Windows.Forms.NumericUpDown]) { $c.Add_ValueChanged({ Update-WAdvLink }) }
    elseif ($c -is [System.Windows.Forms.ComboBox]) { $c.Add_SelectedIndexChanged({ Update-WAdvLink }) }
    elseif ($c -is [System.Windows.Forms.TextBox]) { $c.Add_TextChanged({ Update-WAdvLink }) }
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
