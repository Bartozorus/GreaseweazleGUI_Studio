# ============================== FONCTIONS : ACCUEIL : CALIBRATION ET PROGRESSION ===

function Show-HomeCurve {
    # Courbe de la derniere calibration, toutes familles confondues : pour chaque famille, courbes par tete si elles sont
    # a jour, sinon la courbe commune (Get-FamilyCurves) ; on garde la famille dont cette courbe est la plus recente
    $best = $null; $bestDate = [datetime]::MinValue
    foreach ($f in @('std', 'long', 'hd')) {
        $cvs = Get-FamilyCurves $f $true
        if ($cvs.Count -eq 0) { continue }
        $d = Get-CurveDate $cvs[0]
        if ($null -eq $best -or $d -gt $bestDate) { $best = $f; $bestDate = $d }
    }
    if ($best) { Show-PrecompCurve $best $true; return }
    [void](Show-AppMessage (T "Aucune calibration enregistrée.`n`nLa courbe apparaît après une première calibration : bouton « Calibrer » de l'onglet Écriture, ou première écriture depuis la Bibliothèque.") (T 'Courbe de calibration') 'OK' 'Information')
}

# ============================== ACCUEIL : CALIBRATION ==========================
# Carte « Calibrer le lecteur » : type de disquette choisi dans la liste de tous les formats de gw 1.23 ($script:GwFormats)
# et des types d image sans format gw ; famille de calibration ou raison de l absence de calibration ; etat des courbes ;
# courbe ; calibration complete (test standard ou fin, prechauffage compris sauf case decochee) ou rapide, sans image :
# une image de geometrie (HFE du generateur du motif, New-CalibGeometry) tient lieu d image pour Test-CalibImage,
# Get-LevelRef et New-CalibPattern, qui en tirent famille, cylindres et densite comme d une image de l onglet Ecriture.

function Get-FormatCalibInfo([string]$name) {
    # Calibration d un format gw (table GwFormats). Cal = 'std' ou 'hd' (12.7 : haute densite MFM, 1 us par cellule a
    # 300 tr/min) avec Bits (cellules par piste du motif, celles que Get-PatternBits retient pour une image de ce format :
    # ADF 101 344, ADF HD 202 688, autres haute densite 200 000, autres 100 000), Rpm, NCyl (35 au moins) et Notes ;
    # sinon Why, raison affichee. Group : groupe de la liste de la carte. Ordre des refus : balayage, GCR, FM, codages
    # propres, secteurs durs, tres haute densite (ED), haute densite a 360 tr/min (famille non livree en 12.7, faute de
    # validation sur un lecteur reel), haute densite a une autre vitesse, double densite a une autre vitesse que
    # 300 tr/min, cellule hors plage. Debit de 260 ou 261 kbit/s (Atari) : famille standard, comme l ecriture d une image
    # secteur, avec une note.
    $r = @{ Name = $name; Label = $name; Group = 'other'; Cal = $null; Why = ''; Notes = @(); NCyl = 0; Heads = 0; Bits = 0; BitsSrc = ''; Rate = 0; Rpm = 300 }
    $e = $script:GwFormats[$name]
    if (-not $e) { $r.Why = (T "format absent de la table de l'application (gw plus récent ou fichier diskdefs) : calibrez depuis l'onglet Écriture, avec l'image et ce format"); return $r }
    $r.NCyl = [math]::Max(35, [int]$e.Cyls); $r.Heads = [int]$e.Heads; $r.Rpm = [int]$e.Rpm
    $rate = [int]$e.Rate; $r.Rate = $rate
    $hd = (Test-HdFormat $name) -or $rate -ge 450
    $ed = ($rate -ge 900) -or ($name -match '\.(2880|ed)$')
    $gcr = (@('c64', 'a2', 'mac') -contains $e.Enc)
    $grp = ''
    if ($e.Enc -eq 'amiga') { $grp = $(if ($hd) { 'amiga_hd' } else { 'amiga_dd' }) }
    elseif ($gcr) { $grp = 'gcr' }
    elseif ($e.Enc -eq 'fm') { $grp = 'fm' }
    elseif ($hd) { $grp = 'hd' }
    elseif ($e.Enc -eq 'mfm' -and $name -match '^(ibm|atarist)\.') { $grp = 'pc_dd' }
    if ($e.Enc -eq 'scan') { $r.Why = (T "format de balayage : gw n'écrit pas une image secteur avec ibm.scan, densité inconnue à l'avance") }
    elseif ($gcr) { $r.Why = (T 'codage GCR : la calibration ne mesure que le codage MFM') }
    elseif ($e.Enc -eq 'fm') { $r.Why = (T 'codage FM (simple densité) : la calibration ne mesure que le codage MFM') }
    elseif (@('m2fm', 'dg') -contains $e.Enc) { $r.Why = (T 'codage propre au système (M2FM, Data General) : la calibration ne mesure que le codage MFM') }
    elseif ($e.Enc -eq 'hard') { $r.Why = (T 'disquette à secteurs durs : calibration non prise en charge') }
    elseif ($ed) { $r.Why = (T "très haute densité (ED) : cellule de 500 ns, trop courte pour l'analyse de la calibration (900 à 1 100 ns en haute densité)") }
    elseif ($hd -and [int]$e.Rpm -eq 360) { $r.Why = (T 'disquette 5,25 pouces haute densité à 360 tr/min : calibration pas encore validée sur un lecteur réel') }
    elseif ($hd -and [int]$e.Rpm -ne 300) { $r.Why = ((T "format haute densité à {0} tr/min : la calibration haute densité suppose un lecteur à 300 tr/min") -f "$($e.Rpm)") }
    elseif ($hd) {
        $r.Cal = 'hd'
        if ($e.Enc -eq 'amiga') { $r.Bits = 202688; $r.BitsSrc = (T 'ADF haute densité, horloge AmigaDOS de gw') }
        elseif ($e.Enc -eq 'bit') { $r.Bits = 200000; $r.BitsSrc = (T 'image de cellules (raw), 1 us par cellule') }
        else { $r.Bits = 200000; $r.BitsSrc = (T 'format à secteurs haute densité, 1 us par cellule') }
        # 12.7 : note condensee sur une ligne (zone d information de la fenetre de la carte : etat des trois courbes visible
        # jusqu a la tete 1 sans defilement)
        $r.Notes += (T 'Disquette et lecteur HD nécessaires ; réglages provisoires.')
    }
    elseif ([int]$e.Rpm -ne 300) { $r.Why = ((T "format à {0} tr/min en double densité : aucune famille de calibration à cette vitesse") -f "$($e.Rpm)") }
    elseif ($e.Enc -eq 'bit' -and $rate -ne 250) { $r.Why = ((T "cellule de {0} ns, hors des plages mesurables (900 à 1 100 ns en haute densité, 1 700 à 2 300 ns en double densité)") -f "$([math]::Round(500000 / $rate))") }
    else {
        $r.Cal = 'std'
        if ($e.Enc -eq 'amiga') { $r.Bits = 101344; $r.BitsSrc = (T 'ADF, horloge AmigaDOS de gw') }
        else { $r.Bits = 100000; $r.BitsSrc = (T 'format à secteurs, 2 us par cellule') }
        if ($rate -gt 250) { $r.Notes += ((T "Débit de {0} kbit/s (cellule de {1} ns) : l'écriture de ce format applique la courbe {2}, mesurée à 2 us par cellule (densité plus forte de {3} %).") -f "$rate", "$([math]::Round(500000 / $rate))", (Get-CalibFamilyName 'std'), (Format-UiNum ([math]::Round(100.0 * ($rate - 250) / 250, 1)))) }
    }
    if ($r.Cal) {
        if ($e.Enc -eq 'fm0') { $r.Notes += (T 'Piste 0 en FM : non mesurée, la courbe s''y applique telle quelle.') }
        if ($r.Heads -eq 1) { $r.Notes += (T 'Format simple face : la calibration écrit aussi la face 1 (lecteur double face nécessaire).') }
        if ([int]$e.Cyls -ne 80) { $r.Notes += ((T "{0} cylindres dans la définition de gw.") -f "$($e.Cyls)") }
    }
    if (-not $grp) { $grp = $(if ($r.Cal) { 'other_dd' } else { 'other' }) }
    $r.Group = $grp
    return $r
}

function Get-HomeCalibInfo([string]$name) {
    # Type de disquette de la carte : format gw (Get-FormatCalibInfo) ou type d image de l application sans format gw
    $r = @{ Name = $name; Label = ''; Group = 'long'; Cal = $null; Why = ''; Notes = @(); NCyl = 0; Heads = 0; Bits = 0; BitsSrc = ''; Rate = 0 }
    switch ($name) {
        'app.long' {
            # 105 808 cellules : Get-PatternBits d une image long track illisible (105 820 ramene a un multiple de 16)
            $r.Label = (T 'Amiga longues pistes (IPF, HFE)'); $r.Cal = 'long'; $r.Bits = 105808; $r.NCyl = 80; $r.Heads = 2
            $r.BitsSrc = (T 'long track, 1,89 us par cellule')
            $r.Notes = @((T "Pistes longues d'une protection contre la copie : la cellule réelle et le nombre de cylindres (jusqu'à 84) se lisent dans l'image ; « Calibrer » dans l'onglet Écriture, avec l'image, les reprend exactement."))
            return $r
        }
        'app.flux' { $r.Label = (T 'Flux : SCP, RAW, KF, A2R, CTR'); $r.Why = (T "flux écrit tel quel, sans précompensation (gw ne l'applique qu'aux images à secteurs ou à bits) : pas de calibration"); return $r }
        'app.free' {
            $r.Label = (T 'Géométrie libre : IMD, TD0, D88, MSA, DSK CPC'); $r.Group = 'other'
            $r.Why = ((T "densité non établie par l'application : l'écriture ne calibre pas, elle applique la courbe {0} ; pour la calibrer, choisissez le format gw de la disquette (atarist.720 pour un MSA de 720 Ko, par exemple)") -f (Get-CalibFamilyName 'std'))
            return $r
        }
    }
    return (Get-FormatCalibInfo $name)
}

function Get-HomeCalibList {
    # Liste de la carte : types d image de l application, puis les formats de gw 1.23 dans l ordre de la table
    return @(@(@($script:HomeCalApp) + @($script:GwFormats.Keys)) | ForEach-Object { Get-HomeCalibInfo $_ })
}

function Get-HomeCurveState([string]$fam) {
    # Etat des courbes d une famille : commune et par tete (date, lecteur, test, cylindres, calcul, convergence)
    $lines = @()
    foreach ($k in @($fam, "${fam}_h0", "${fam}_h1")) {
        $cv = $script:PrecompCurves[$k]
        if (-not $cv) { $lines += ((T "{0} : aucune courbe") -f (Get-CurveKeyLabel $k)); continue }
        $tt = if ([string]$cv.Test -eq 'fine') { (T 'test fin') } elseif ([string]$cv.Test -eq 'std') { (T 'test standard') } else { (T 'test non enregistré') }
        $st = (T "{0} : {1}, lecteur {2}, {3}, {4} cylindres, calcul {5}") -f (Get-CurveKeyLabel $k), "$($cv.Date)", "$($cv.Drive)", "$tt", "$(@($cv.Values).Count)", (Get-CurveCalcText $cv)
        if ($cv.Converged -eq $false) { $st += (T ', NON CONVERGÉE') }
        $lines += $st
    }
    if ($script:PrecompCurves["${fam}_h0"] -and $script:PrecompCurves["${fam}_h1"] -and -not (Test-HeadCurvesCurrent $fam)) { $lines += (T 'Courbes par tête antérieures à la courbe commune : non appliquées.') }
    return ($lines -join "`r`n")
}

function New-CalibGeometry($info, [int]$nCyl) {
    # Image de geometrie de la carte : HFE du generateur du motif de test aux cylindres et aux cellules par piste du type
    # choisi. Get-ImageCylinders (en-tete), Get-ImageFamily, Get-PatternBits, Get-CellOutOfRange et Get-HighDensityReason
    # (table des pistes, 8 x (longueur // 2) = cellules) la lisent comme toute image HFE : la calibration complete ou
    # rapide en deduit famille, cylindres et densite. Cellules : 100 000 (2 000 ns), 101 344 (1 973,5 ns), 105 808
    # (1 890,2 ns, sous le seuil PrecompThresholdNs de 1 950 ns par defaut) ; 12.7 : 200 000 (1 000 ns) et 202 688
    # (986,7 ns, AmigaDOS HD) en haute densite. Debit de l en-tete : un tour a la vitesse du type, bits x tr/min / 120 000
    # (regle generale du motif ; 300 tr/min : expression d origine, bits / 400).
    if (-not (Test-Path -LiteralPath $script:TempDir)) { [void](New-Item -ItemType Directory -Path $script:TempDir -Force) }
    $path = Join-Path $script:TempDir 'precomp-geometry.hfe'
    $rpm = if ($info.Rpm) { [int]$info.Rpm } else { 300 }
    $rate = if ($rpm -eq 300) { [int][math]::Round($info.Bits / 400.0) } else { [int][math]::Round($info.Bits * $rpm / 120000.0) }
    [CalibPattern]::WriteHfe($path, $nCyl, [int]$info.Bits, $rate, 20261014)
    return $path
}

function Get-WriteTabFamily {
    # Famille de l image de l onglet Ecriture ; $null sans image, pour un flux ou une image haute densite non calibrable
    # (12.7 : 'hd' pour une haute densite calibrable)
    $p = $txtWFile.Text
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { return $null }
    if (@('.scp', '.raw', '.kf', '.a2r', '.ctr') -contains [System.IO.Path]::GetExtension($p).ToLower()) { return $null }
    if (Get-HighDensityReason $p $cmbWFmt.Text) { return (Get-HdCalibFamily $p $cmbWFmt.Text) }
    return (Get-ImageFamily $p $cmbWFmt.Text)
}

function Start-HomeCalib([string]$name, [string]$test, [bool]$heads, [int]$nCyl, [bool]$warm = $true) {
    # Calibration de la carte, sans image : image de geometrie du type choisi, puis calibration complete (test 'std' ou
    # 'fine' ; warm : prechauffage du lecteur s il est regle) ou rapide ('level'). Pas de fenetre ici hors de celles de la
    # calibration (testable) : renvoie @{ Started ; Why } (Why vide : avertissement refuse par l utilisateur).
    $res = @{ Started = $false; Why = '' }
    if (Get-AppBusy) { $res.Why = (T 'opération en cours'); return $res }
    if (-not $script:ScpStatsOk) { $res.Why = (T "module d'analyse SCP indisponible (Add-Type)"); return $res }
    $info = Get-HomeCalibInfo $name
    if (-not $info.Cal) { $res.Why = $info.Why; return $res }
    $nCyl = [math]::Max(2, [math]::Min(84, $nCyl))
    try { $img = New-CalibGeometry $info $nCyl }
    catch { $res.Why = ((T "image de géométrie impossible à créer : {0}") -f "$($_.Exception.Message)"); return $res }
    # Seuil de famille de la configuration (precompThresholdNs) : la famille deduite de la geometrie doit etre celle du type
    $fam = Get-ImageFamily $img
    if ($fam -ne $info.Cal) { $res.Why = ((T "seuil de famille precompThresholdNs de {0} ns : ce type serait calibré dans la famille {1}") -f "$($script:PrecompThresholdNs)", (Get-CalibFamilyName $fam)); return $res }
    $script:HomeCalFmt = $name
    $geom = @{ Img = $img; Label = [string]$info.Label; Fmt = $name; BitsSrc = [string]$info.BitsSrc; CylSrc = ((T "{0} cylindres choisis dans l'Accueil") -f "$nCyl") }
    $script:AfterCalib = ''
    $tt = switch ($test) { 'level' { (T 'calibration rapide') } 'fine' { (T 'test fin') } default { (T 'test standard') } }
    $kt = if ($heads) { (T 'une courbe par tête') } else { (T 'courbe commune') }
    Append-Log ((T "Calibration depuis l'Accueil : type {0}, famille {1}, {2} cylindres, {3}, {4}.") -f "$($info.Label)", (Get-CalibFamilyName $fam), "$nCyl", "$kt", "$tt")
    if ($test -eq 'level') {
        $lr = Get-LevelRef $fam $heads $cmbDrive.Text $img $false -ForHome
        if (-not $lr.Ok) { $res.Why = ((T "calibration rapide impossible : {0}") -f "$($lr.Why)"); return $res }
        Start-LevelCalib $lr -Geom $geom
    } else {
        Start-PrecompCalib -Geom $geom -Heads $heads -Test $(if ($test -eq 'fine') { 'fine' } else { 'std' }) -NoWarmup:(-not $warm)
    }
    if (-not $script:Cal) { return $res }
    $script:HomeCalBusy = $true
    Update-HomeCalibCard
    $res.Started = $true
    return $res
}

function Update-HomeCalibCard {
    # Carte « Calibrer le lecteur » : progression d une calibration lancee depuis l Accueil (texte de la barre de l onglet
    # Ecriture), puis son bilan jusqu a la prochaine ouverture de la carte. Minuterie principale et Start-HomeCalib.
    # Progression trop longue pour le libelle de la carte (306 x 44, deux lignes) : details de la fin entre parentheses
    # retires (format court : avancement et temps restant en tete), plutot qu une troisieme ligne coupee
    $d = $cardCalib.Controls[3]
    if ($script:Cal -and $script:Cal.Home) {
        $t = $lblWCal.Text
        $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
        if ([System.Windows.Forms.TextRenderer]::MeasureText($t, $d.Font, (New-Object System.Drawing.Size($d.Width, 10000)), $tf).Height -gt $d.Height) { $t = $t -replace '\s*\([^()]*\)\s*$', '' }
        if ($d.Text -ne $t) { $d.Text = $t }
        $d.ForeColor = $script:Theme.Accent; return
    }
    $script:HomeCalBusy = $false
    $d.Text = $lblWCal.Text; $d.ForeColor = $script:Theme.Muted
}

# ============================== ACCUEIL : PROGRESSION ==========================
# Zone de l Accueil a la place du titre et du sous-titre (12.7) : toute calibration en cours ($script:Cal, rapide et
# prechauffage compris, quel que soit le point de depart) et tout prechauffage d une ecriture lente ($script:WriteWarm) ;
# puis bilan d une calibration lancee depuis l Accueil ($script:Cal.Home), jusqu a « Fermer », l ouverture d une carte ou
# une nouvelle operation. Barre et detail recopies de $pbWCal et $lblWCal (onglet Ecriture).

function Get-HomeProgFit([string]$t, $font, [int]$w) {
    # Texte sur une ligne de $w px : tel quel s il tient, sinon sans ses details de fin entre parentheses (comme
    # Update-HomeCalibCard), sinon coupe par des points de suspension (U+2026) au plus long qui tient, a la fin d un
    # mot si possible
    if (-not $t) { return '' }
    $tf = [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
    $sz = New-Object System.Drawing.Size(32000, 100)
    if ([System.Windows.Forms.TextRenderer]::MeasureText($t, $font, $sz, $tf).Width -le $w) { return $t }
    $s = $t -replace '\s*\([^()]*\)\s*$', ''
    if ($s -ne $t -and [System.Windows.Forms.TextRenderer]::MeasureText($s, $font, $sz, $tf).Width -le $w) { return $s }
    $e = [string][char]0x2026
    $n = 0; $lo = 1; $hi = $s.Length - 1
    while ($lo -le $hi) {
        $mid = [int][math]::Floor(($lo + $hi) / 2)
        if ([System.Windows.Forms.TextRenderer]::MeasureText(($s.Substring(0, $mid).TrimEnd() + $e), $font, $sz, $tf).Width -le $w) { $n = $mid; $lo = $mid + 1 } else { $hi = $mid - 1 }
    }
    if ($n -eq 0) { return $e }
    $p = $s.Substring(0, $n)
    $sp = $p.LastIndexOf(' ')
    if ($s[$n] -ne ' ' -and $sp -gt $n / 2) { $p = $p.Substring(0, $sp) }
    return ($p.TrimEnd(' ', ',', ';', ':', '(') + $e)
}

function Draw-HomeProgText($lbl, $e) {
    # Libelle de la zone desactive avec les onglets (Set-Busy, commande gw en cours) : texte redessine dans sa couleur,
    # sur une ligne, a la place du texte grise ; libelle actif : dessin habituel
    if ($lbl.Enabled -or -not $lbl.Text) { return }
    $b = New-Object System.Drawing.SolidBrush($lbl.BackColor)
    $e.Graphics.FillRectangle($b, $lbl.ClientRectangle); $b.Dispose()
    [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $lbl.Text, $lbl.Font, $lbl.ClientRectangle, $lbl.ForeColor, ([System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine))
}

function Get-HomeProgTitle($cal, $ww) {
    # Titre de la zone pendant une calibration (lecteur, type de la carte ou famille, test, courbes) ou un prechauffage
    # d ecriture lente
    if ($cal) {
        $what = if ($cal.Home -and $cal.Geom -and $cal.Geom.Label) { [string]$cal.Geom.Label } else { Get-CalibFamilyName ([string]$cal.Family) }
        $kt = if ($cal.Slow) { (T 'une courbe par tête') } else { (T 'courbe commune') }
        # 12.8.1 : mesure de la disquette sur l image (276) : image et famille
        if ($cal.Mode -eq 'content') { return ((T 'Mesure de la disquette en cours : lecteur {0}, {1}') -f "$($cal.Drive)", "$([System.IO.Path]::GetFileName([string]$cal.Image)), $what") }
        if ($cal.Mode -eq 'level') { return ((T 'Calibration rapide en cours : lecteur {0}, {1}') -f "$($cal.Drive)", "$what, $kt") }
        $tt = if ($cal.Mode -eq 'fine') { (T 'test fin') } else { (T 'test standard') }
        return ((T 'Calibration en cours : lecteur {0}, {1}, {2}') -f "$($cal.Drive)", "$what", "$tt, $kt")
    }
    return ((T "Préchauffage avant l'écriture lente : lecteur {0}") -f "$($ww.Drive)")
}

function Set-HomeProgDone($cal, [string]$kind, [string]$detail = '') {
    # Bilan d une calibration lancee depuis l Accueil (Complete-PrecompCalib, Complete-LevelCalib, Stop-PrecompCalib) :
    # 'ok', 'warn' (reserves acceptees), 'abandon' (refusee dans la fenetre de decision), 'stop' (arretee, sans mesure
    # exploitable). Detail : premiere raison de la fenetre de decision, sinon le libelle de l onglet Ecriture. Proc : gw
    # en cours a la fin (arret), qui n est pas une nouvelle operation. Sans effet pour une calibration lancee ailleurs.
    if (-not $cal -or -not $cal.Home) { return }
    if ($detail) { $detail = $detail.Substring(0, 1).ToUpper() + $detail.Substring(1) } else { $detail = [string]$lblWCal.Text }
    $script:HomeProgDone = @{ Kind = $kind; Detail = $detail; Family = [string]$cal.Family; Slow = [bool]$cal.Slow; Proc = $script:GwProc
                              Curve = ((Get-FamilyCurves ([string]$cal.Family) ([bool]$cal.Slow)).Count -gt 0) }
}

function Clear-HomeProgress {
    # « Fermer » de la zone, ouverture d une carte : bilan efface, titre et sous-titre de l Accueil remis
    $script:HomeProgDone = $null
    Update-HomeProgress
}

function Update-HomeProgress {
    # Minuterie principale. Modes : 'prog' (calibration ou prechauffage d ecriture lente en cours), 'hold' (fenetre de
    # decision ouverte apres une progression : titre « decision demandee », barre et detail gardes), 'done' (bilan),
    # 'none' (titre et sous-titre de l Accueil).
    # Un controle n est modifie que si sa valeur change ; l etat affiche est suivi dans HomeProgUi (la propriete Visible
    # d un controle d un onglet non affiche se lit fausse)
    if (-not $tabH -or -not $pnlHomeProg) { return }
    $u = $script:HomeProgUi
    $cal = $script:Cal; $ww = $script:WriteWarm; $d = $script:HomeProgDone
    if ($cal -or $ww) { $mode = 'prog'; if ($d) { $script:HomeProgDone = $null; $d = $null } }
    elseif ($script:HomeProgHold -and (@('prog', 'hold') -contains $u.Mode)) { $mode = 'hold' }
    elseif ($d) {
        # Nouvelle operation (gw hors detection des lecteurs, sequence, controle apres ecriture, restauration) : bilan efface
        $newGw = [bool]($script:GwProc -and -not $script:Detect -and -not [object]::ReferenceEquals($script:GwProc, $d.Proc))
        if ($newGw -or $script:Chain.Count -gt 0 -or $script:Rep -or $script:Restore) { $script:HomeProgDone = $null; $d = $null; $mode = 'none' } else { $mode = 'done' }
    } else { $mode = 'none' }
    $show = ($mode -ne 'none')
    if ($u.Shown -ne $show) {
        $u.Shown = $show
        $pnlHomeProg.Visible = $show; $lblHTitle.Visible = -not $show; $lblHSub.Visible = -not $show
    }
    $u.Mode = $mode
    if (-not $show) { return }
    # Lien du journal seulement s il est utilisable : pendant une commande gw, Set-Busy desactive les onglets, donc la
    # zone ; le bouton « Afficher journal » de la barre reste disponible
    $logLink = [bool]$split.Panel2Collapsed -and [bool]$tabs.Enabled
    if ($mode -eq 'done') {
        $title = switch ([string]$d.Kind) { 'ok' { (T 'Calibration terminée : courbe convergée') } 'warn' { (T 'Calibration terminée avec réserves : voir le journal') } 'abandon' { (T 'Calibration abandonnée') } default { (T 'Calibration arrêtée') } }
        $src = [string]$d.Detail; $bar = $false; $curveLink = [bool]$d.Curve; $closeLink = $true
    } else {
        # Fenetre de decision ouverte (mode hold) : calibration terminee, barre et detail de sa fin gardes
        $title = if ($mode -eq 'prog') { Get-HomeProgTitle $cal $ww } else { (T 'Calibration terminée : décision demandée') }
        $src = [string]$lblWCal.Text; $bar = $true; $curveLink = $false; $closeLink = $false
    }
    # Liens a droite du titre (Fermer, Afficher la courbe, Afficher le journal) ; textes et place refaits a chaque
    # changement de liens ou de langue
    $lk = "$($script:Lang)|$([int]$logLink)$([int]$curveLink)$([int]$closeLink)"
    if ($u.Links -ne $lk) {
        $u.Links = $lk
        $lnkHProgLog.Text = (T 'Afficher le journal'); $lnkHProgCurve.Text = (T 'Afficher la courbe'); $lnkHProgClose.Text = (T 'Fermer')
        $x = $pnlHomeProg.Width
        foreach ($p in @(@($lnkHProgClose, $closeLink), @($lnkHProgCurve, $curveLink), @($lnkHProgLog, $logLink))) {
            $p[0].Visible = [bool]$p[1]
            if ($p[1]) { $x -= $p[0].PreferredWidth; $p[0].Left = $x; $x -= 14 }
        }
        $u.TitleW = [math]::Max(80, $x - 4)
        $lblHProgTitle.Width = $u.TitleW
        $u.RawTitle = $null; $u.Src = $null
    }
    if ($u.RawTitle -ne $title -or $null -eq $u.RawTitle) {
        $u.RawTitle = $title
        $t = Get-HomeProgFit $title $lblHProgTitle.Font ([int]$u.TitleW)
        if ($lblHProgTitle.Text -ne $t) { $lblHProgTitle.Text = $t }
    }
    if ($u.Src -ne $src -or $null -eq $u.Src) {
        $u.Src = $src
        $t = Get-HomeProgFit $src $lblHProgDetail.Font $lblHProgDetail.Width
        if ($lblHProgDetail.Text -ne $t) { $lblHProgDetail.Text = $t }
    }
    if ($u.Bar -ne $bar) { $u.Bar = $bar; $pbHProg.Visible = $bar }
    if ($bar) {
        # Barre : valeur et maximum de $pbWCal ; visible pendant toute progression (Visible de $pbWCal se lit faux quand
        # l onglet Ecriture n est pas affiche, il est vrai pendant toute calibration et tout prechauffage)
        if ($pbHProg.Maximum -ne $pbWCal.Maximum) { $pbHProg.Maximum = $pbWCal.Maximum }
        $v = [math]::Max($pbHProg.Minimum, [math]::Min($pbHProg.Maximum, [int]$pbWCal.Value))
        if ($pbHProg.Value -ne $v) { $pbHProg.Value = $v }
    }
}

function Update-HomeCalibDialog {
    # Fenetre de la carte : detail du type choisi, etat des courbes, durees, disponibilite du test rapide, prechauffage,
    # remplacement d une courbe d un autre lecteur ou d une autre geometrie (une courbe par famille, pour tous les lecteurs)
    $s = $script:HcDlg
    if (-not $s -or $s.Busy) { return }
    $s.Busy = $true
    try {
        $info = if ($s.Lv.SelectedItems.Count -gt 0) { $s.Lv.SelectedItems[0].Tag } else { $null }
        # Cylindres du type choisi ; 12.8 (point 7) : type enregistre, a sa premiere selection : cylindres de la derniere
        # calibration lancee (CylInit, reglage homeCalCyls)
        if ($info -and $s.Last -ne $info.Name) {
            $s.Last = $info.Name
            if ($info.Cal) { if ($s.CylInit -and $s.CylInit.Name -eq $info.Name) { Set-Num $s.Cyl $s.CylInit.N } else { Set-Num $s.Cyl $info.NCyl } }
            $s.CylInit = $null
        }
        $ok = [bool]($info -and $info.Cal)
        foreach ($c in @($s.Cyl, $s.Heads, $s.Std, $s.Fine, $s.Go)) { $c.Enabled = $ok }
        # « Calibrer » bleu seulement quand il est actif, sinon style normal grise (comme Set-CleanGo) ; style refait
        # seulement quand il change
        $gs = if ($ok) { 'primary' } else { 'normal' }
        if ($s.GoStyle -ne $gs) { $s.GoStyle = $gs; Set-Btn $s.Go 'Play' $gs }
        $s.Warn.Text = ''; $s.QuickTxt.Text = ''
        $wm = [double]$script:CalWarmupMinutes
        if (-not $info) { $s.Info.Text = (T 'Choisissez un type de disquette dans la liste.'); $s.Quick.Enabled = $false; $s.Curve.Enabled = $false; $s.Warm.Enabled = $false; return }
        if (-not $ok) {
            $s.Info.Text = ((T "{0}`r`n`r`nNon calibrable : {1}.") -f "$($info.Label)", "$($info.Why)")
            $s.Quick.Enabled = $false; $s.Curve.Enabled = $false; $s.Warm.Enabled = $false
            return
        }
        $fam = [string]$info.Cal; $heads = [bool]$s.Heads.Checked; $n = [int]$s.Cyl.Value
        $txt = (T "{0}`r`nFamille de calibration : {1} ({2} cellules par piste, {3} ns par cellule).") -f "$($info.Label)", (Get-CalibFamilyName $fam), "$($info.Bits)", (Format-UiNum ([math]::Round(200000000.0 / [double]$info.Bits, 1)))
        foreach ($nt in @($info.Notes)) { $txt += "`r`n" + $nt }
        $txt += "`r`n`r`n" + (Get-HomeCurveState $fam)
        $s.Info.Text = $txt
        $s.Curve.Enabled = ((Get-FamilyCurves $fam $heads).Count -gt 0)
        # Durees : memes estimations que Start-PrecompCalib (passes prevues, 1,4 s par piste et par phase, plus l effacement
        # haute frequence en double densite (12.8.2, Get-CalibEraseEst), sans le
        # prechauffage, annonce par sa case) et Start-LevelCalib (2 passes)
        $np = $script:CalCoarse.Count + $script:CalMaxVerify
        $pt = 1.4 + (Get-CalibEraseEst ($fam -eq 'hd'))
        $nStd = @(0..($n - 1) | Where-Object { $_ % 10 -eq 0 }).Count + $(if (($n - 1) % 10 -ne 0) { 1 } else { 0 })
        # 12.8 (D9) : memes noms que la liste « Calibration précomp » de l onglet Ecriture (test standard, fin, rapide)
        $s.Std.Text = ((T "Test standard (calibration complète, 1 cylindre sur 10) : environ {0} min") -f "$([math]::Max(1, [math]::Round($nStd * 2 * $pt * $np / 60, 0)))")
        # Haute densite : pas de calibration rapide (12.7), le test fin n en est pas la reference
        $fineMin = "$([math]::Max(1, [math]::Round($n * 2 * $pt * $np / 60, 0)))"
        $s.Fine.Text = if ($fam -eq 'hd') { (T "Test fin (calibration complète, tous les cylindres) : environ {0} min") -f $fineMin } else { (T "Test fin (calibration complète, tous les cylindres) : environ {0} min ; référence du test rapide") -f $fineMin }
        $lr = Get-LevelRef $fam $heads $cmbDrive.Text '' $false -NCyl $n -Bits ([int]$info.Bits) -ForHome
        if ($lr.Ok) {
            $lc = @{}
            foreach ($u in @($lr.Units)) { foreach ($c in @(@($u.LCyls) + @($u.Wit) + @($(if ($null -ne $u.Probe) { $u.Probe })))) { $lc[[int]$c] = $true } }
            $s.Quick.Enabled = $true
            # 12.8 (lot 1c) : par tete, 2 passes en general, 3 avec 2 cylindres de controle quand la forme est adaptee
            $qLo = [math]::Max(1, [math]::Round($lc.Count * 2 * $pt * 2 / 60, 0))
            if ($heads) {
                $qHi = [math]::Max($qLo, [math]::Round(($lc.Count + [int]$script:LevelAdaptCtlCyls) * 2 * $pt * 3 / 60, 0))
                $qd = if ($qHi -gt $qLo) { (T '{0} à {1}') -f "$qLo", "$qHi" } else { "$qLo" }
                $s.Quick.Text = ((T "Test rapide (niveau et forme de la disquette insérée) : {0} min") -f "$qd")
            } else { $s.Quick.Text = ((T "Test rapide (niveau de la disquette insérée) : environ {0} min") -f "$qLo") }
            $s.QuickTxt.Text = ((T "Forme reprise de la calibration complète du {0}. Insérez la disquette que vous allez écrire : le profil obtenu ne vaut que pour elle.") -f "$($lr.Units[0].Cv.Date)")
        } else {
            if ($s.Quick.Checked) { $s.Fine.Checked = $true }
            $s.Quick.Enabled = $false
            $s.Quick.Text = (T 'Test rapide (niveau de la disquette insérée)')
            $s.QuickTxt.Text = ((T "Indisponible : {0}.") -f "$($lr.Why)")
        }
        # Prechauffage : calibration complete seulement (la calibration rapide mesure le lecteur dans son etat du moment)
        $s.Warm.Enabled = ($wm -gt 0 -and -not $s.Quick.Checked)
        if (-not $s.Quick.Checked) {
            # Courbe remplacee : tete 0 par tete, sinon la courbe commune (cle calculee directement : affecter le resultat
            # d un if deroulerait un tableau d un seul element en chaine, et $keys[0] serait son premier caractere)
            $cv = $script:PrecompCurves[$(if ($heads) { "${fam}_h0" } else { $fam })]
            $w = @()
            if ($cv -and [string]$cv.Drive -ne $cmbDrive.Text) { $w += ((T "La courbe actuelle vient du lecteur {0} : elle sera remplacée, et la nouvelle s'appliquera à tous les lecteurs (une courbe par famille).") -f "$($cv.Drive)") }
            if ($cv -and [math]::Abs(@($cv.Values).Count - $n) -gt 4) { $w += ((T "La courbe actuelle couvre {0} cylindres : elle sera remplacée par une courbe de {1} cylindres, appliquée à toutes les images de la famille {2}.") -f "$(@($cv.Values).Count)", "$n", (Get-CalibFamilyName $fam)) }
            $s.Warn.Text = ($w -join "`r`n")
        }
    } finally { $s.Busy = $false }
}

function Show-HomeCalib {
    # Fenetre de la carte « Calibrer le lecteur ». Refusee pendant une operation. « Calibrer » ferme la fenetre, puis
    # Start-HomeCalib affiche l avertissement habituel de la calibration (Show-CalibConfirm) : pas de fenetres modales
    # imbriquees. Le type choisi est enregistre (ui.homeCalFormat) a la fermeture, lance ou non.
    if (Get-AppBusy) {
        [void](Show-AppMessage (T "Opération en cours : ouvrez la calibration une fois l'opération terminée.") (T 'Calibration precomp') 'OK' 'Information'); return
    }
    if ($script:HomeCalDesc) { $cardCalib.Controls[3].Text = $script:HomeCalDesc; $cardCalib.Controls[3].ForeColor = $script:Theme.Muted }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmHomeCalib'; $dlg.Text = (T 'Calibrer le lecteur')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    # Hauteur : zone d avertissement de 106 px (deux avertissements de remplacement de courbe, en francais et en anglais)
    $dlg.ClientSize = New-Object System.Drawing.Size(960, 676)
    $htip = New-Object System.Windows.Forms.ToolTip
    $htip.AutoPopDelay = 30000; $htip.InitialDelay = 400; $htip.ReshowDelay = 100
    $intro = New-Object System.Windows.Forms.Label
    $intro.AutoSize = $false; $intro.UseMnemonic = $false; $intro.Location = '16,12'; $intro.Size = '928,40'
    $intro.Text = ((T "Choisissez le type de disquette. La calibration mesure la précompensation du lecteur {0} sur une disquette sacrifiée, à la densité de ce type ; la courbe obtenue s'applique ensuite à toutes les images de sa famille. Aucune image n'est nécessaire.") -f "$($cmbDrive.Text)")
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Name = 'lvHcFmt'; $lv.Location = '16,58'; $lv.Size = '540,556'; $lv.View = 'Details'; $lv.FullRowSelect = $true
    $lv.HideSelection = $false; $lv.MultiSelect = $false; $lv.HeaderStyle = 'Nonclickable'; $lv.ShowItemToolTips = $true
    [void]$lv.Columns.Add((T 'Type'), 300); [void]$lv.Columns.Add((T 'Géométrie'), 80); [void]$lv.Columns.Add((T 'Calibration (famille)'), 136)
    $gn = [ordered]@{ amiga_dd = (T 'Amiga double densité'); amiga_hd = (T 'Amiga haute densité'); pc_dd = (T 'PC et Atari ST double densité')
                      hd = (T 'Haute densité : PC et autres'); long = (T 'Images longues pistes et protégées'); gcr = (T 'GCR : Commodore 64, Apple II, Macintosh')
                      fm = (T 'FM (simple densité)'); other_dd = (T 'Autres formats MFM double densité'); other = (T 'Autres formats') }
    $groups = @{}
    foreach ($k in @($gn.Keys)) { $g = New-Object System.Windows.Forms.ListViewGroup([string]$k, [string]$gn[$k]); [void]$lv.Groups.Add($g); $groups[$k] = $g }
    $sel = $null
    foreach ($info in @(Get-HomeCalibList)) {
        $it = New-Object System.Windows.Forms.ListViewItem([string]$info.Label)
        [void]$it.SubItems.Add($(if ($info.NCyl -gt 0) { "$($info.NCyl) × $($info.Heads)" } else { '-' }))
        [void]$it.SubItems.Add($(if ($info.Cal) { Get-CalibFamilyName $info.Cal } else { (T 'non calibrable') }))
        $it.ToolTipText = $(if ($info.Cal) { ((T "Famille {0}") -f (Get-CalibFamilyName $info.Cal)) } else { [string]$info.Why })
        if (-not $info.Cal) { $it.ForeColor = $script:Theme.Muted }
        $it.Tag = $info; $it.Group = $groups[[string]$info.Group]
        [void]$lv.Items.Add($it)
        if ($info.Name -eq $script:HomeCalFmt) { $sel = $it }
    }
    $tbInfo = New-Object System.Windows.Forms.TextBox
    $tbInfo.Name = 'tbHcInfo'; $tbInfo.Multiline = $true; $tbInfo.ReadOnly = $true; $tbInfo.ScrollBars = 'Vertical'; $tbInfo.TabStop = $false
    $tbInfo.Location = '572,58'; $tbInfo.Size = '372,196'; $tbInfo.BackColor = $script:Theme.Page
    $lblCyl = New-Object System.Windows.Forms.Label; $lblCyl.Text = (T 'Cylindres :'); $lblCyl.AutoSize = $true; $lblCyl.Location = '572,267'
    $numCyl = New-Object System.Windows.Forms.NumericUpDown
    $numCyl.Name = 'numHcCyl'; $numCyl.Minimum = 35; $numCyl.Maximum = 84; $numCyl.Value = 80; $numCyl.Width = 60; $numCyl.Location = '680,264'
    $htip.SetToolTip($numCyl, (T "Cylindres de test : ceux du format par défaut. Un lecteur 5,25 pouces 40 pistes : 40 ; un long track : jusqu'à 84 si le lecteur y accède."))
    # 12.8 (point 7) : choix de la fenetre lus a l ouverture dans les reglages, ecrits au lancement de la calibration :
    # courbe par tete (homeCalHeads, propre a la carte, D9 : cochee par defaut), prechauffage (warmFullCalib, celui de
    # l onglet Ecriture, D6), test (calMode, celui de la liste de l onglet Ecriture), cylindres (homeCalCyls, pour le type
    # enregistre)
    $chkHeads = New-Object System.Windows.Forms.CheckBox
    $chkHeads.Name = 'chkHcHeads'; $chkHeads.Text = (T 'Une courbe par tête (écriture lente et restauration)'); $chkHeads.Location = '572,292'; $chkHeads.Size = '372,24'; $chkHeads.Checked = [bool](Get-Setting 'homeCalHeads')
    $htip.SetToolTip($chkHeads, (T "Coché : une courbe par tête, celle de l'écriture lente et de la restauration.`nDécoché : une courbe commune aux deux têtes, celle de l'écriture rapide."))
    # Prechauffage de la calibration complete : reglage warmFullCalib, case inactive quand la duree vaut 0
    $wm = [double]$script:CalWarmupMinutes
    $wmt = Get-WarmMinutesText $wm
    $chkWarm = New-Object System.Windows.Forms.CheckBox
    $chkWarm.Name = 'chkHcWarm'; $chkWarm.Location = '572,318'; $chkWarm.Size = '372,36'; $chkWarm.Checked = ($wm -gt 0 -and [bool](Get-Setting 'warmFullCalib')); $chkWarm.Enabled = ($wm -gt 0)
    $chkWarm.Text = if ($wm -gt 0) { (T "Préchauffer le lecteur avant la calibration complète ({0} au plus de lecture sans écriture)") -f "$wmt" } else { (T "Préchauffer le lecteur avant la calibration complète (désactivé : durée du préchauffage à 0)") }
    $htip.SetToolTip($chkWarm, (T "Avant une calibration complète (bouton « Calibrer », carte « Calibrer le lecteur » de l'Accueil, calibration automatique avant une écriture) : lectures sans écriture des cylindres de test avant la première passe, pour stabiliser la température du lecteur ; réduites ou sautées si le lecteur vient de servir. Décochée : la calibration commence tout de suite.`nMême réglage dans l'onglet Écriture et dans la fenêtre de la carte « Calibrer le lecteur ». Durée : champ « Durée du préchauffage » de l'onglet Écriture.`nLa calibration rapide (test rapide) n'a pas de préchauffage propre : avant une écriture lente, elle suit la case « Préchauffer le lecteur avant l'écriture lente »."))
    $rbStd = New-Object System.Windows.Forms.RadioButton;   $rbStd.Name = 'rbHcStd';     $rbStd.Location = '572,356';   $rbStd.Size = '372,36'
    $rbFine = New-Object System.Windows.Forms.RadioButton;  $rbFine.Name = 'rbHcFine';   $rbFine.Location = '572,394';  $rbFine.Size = '372,36'
    $rbQuick = New-Object System.Windows.Forms.RadioButton; $rbQuick.Name = 'rbHcQuick'; $rbQuick.Location = '572,432'; $rbQuick.Size = '372,36'
    $lblQuick = New-Object System.Windows.Forms.Label
    $lblQuick.Name = 'lblHcQuick'; $lblQuick.AutoSize = $false; $lblQuick.UseMnemonic = $false; $lblQuick.Location = '590,468'; $lblQuick.Size = '354,52'; $lblQuick.ForeColor = $script:Theme.Muted
    # Hauteurs mesurees (Segoe UI 9,75) : texte du test rapide 51 px (3 lignes), deux avertissements 102 px en francais
    $lblWarn = New-Object System.Windows.Forms.Label
    $lblWarn.Name = 'lblHcWarn'; $lblWarn.AutoSize = $false; $lblWarn.UseMnemonic = $false; $lblWarn.Location = '572,522'; $lblWarn.Size = '372,104'; $lblWarn.ForeColor = $script:Theme.WarnInk   # 12.8 (FIX5, D17) : encre du texte d avertissement
    $btnCurve = New-Object System.Windows.Forms.Button; $btnCurve.Name = 'btnHcCurve'; $btnCurve.Text = (T 'Afficher la courbe'); $btnCurve.Size = New-Object System.Drawing.Size(190, 34); $btnCurve.Location = '16,628'
    $btnClose = New-Object System.Windows.Forms.Button; $btnClose.Name = 'btnHcClose'; $btnClose.Text = (T 'Fermer'); $btnClose.Size = New-Object System.Drawing.Size(110, 34); $btnClose.Location = '834,628'
    $btnGo = New-Object System.Windows.Forms.Button; $btnGo.Name = 'btnHcGo'; $btnGo.Text = (T 'Calibrer'); $btnGo.Size = New-Object System.Drawing.Size(160, 34); $btnGo.Location = '666,628'
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnCurve 'Diagnostic' 'normal'; Set-Btn $btnGo 'Play' 'primary'; Set-Btn $btnClose '' 'normal'
    $dlg.CancelButton = $btnClose                     # pas d AcceptButton : Entree dans la liste ne lance rien
    $dlg.Controls.AddRange(@($intro, $lv, $tbInfo, $lblCyl, $numCyl, $chkHeads, $chkWarm, $rbStd, $rbFine, $rbQuick, $lblQuick, $lblWarn, $btnCurve, $btnGo, $btnClose))
    # Mode par defaut : reglage calMode, celui de l onglet Ecriture (test standard, fin ou rapide) ; rapide indisponible :
    # test fin
    $prevFmt = [string]$script:HomeCalFmt
    switch ([string](Get-Setting 'calMode')) { 'level' { $rbQuick.Checked = $true } 'fine' { $rbFine.Checked = $true } default { $rbStd.Checked = $true } }
    # 12.8 (point 7) : cylindres de la derniere calibration lancee, pour le type enregistre (reglage homeCalCyls, 0 :
    # cylindres du type), appliques a sa premiere selection (Update-HomeCalibDialog)
    $hcc = [int](Get-Setting 'homeCalCyls')
    $cylInit = if ($hcc -ge $numCyl.Minimum -and $hcc -le $numCyl.Maximum) { @{ Name = [string]$script:HomeCalFmt; N = $hcc } } else { $null }
    $script:HcDlg = @{ Dlg = $dlg; Lv = $lv; Info = $tbInfo; Cyl = $numCyl; Heads = $chkHeads; Warm = $chkWarm; Std = $rbStd; Fine = $rbFine; Quick = $rbQuick
                       QuickTxt = $lblQuick; Warn = $lblWarn; Curve = $btnCurve; Go = $btnGo; GoStyle = 'primary'; Busy = $false; Last = ''; Choice = $null; CylInit = $cylInit }
    $lv.Add_SelectedIndexChanged({ Update-HomeCalibDialog })
    $numCyl.Add_ValueChanged({ Update-HomeCalibDialog })
    $chkHeads.Add_CheckedChanged({ Update-HomeCalibDialog })
    foreach ($rb in @($rbStd, $rbFine, $rbQuick)) { $rb.Add_CheckedChanged({ if ($this.Checked) { Update-HomeCalibDialog } }) }
    $btnCurve.Add_Click({
        $s = $script:HcDlg
        if ($s.Lv.SelectedItems.Count -gt 0 -and $s.Lv.SelectedItems[0].Tag.Cal) { Show-PrecompCurve ([string]$s.Lv.SelectedItems[0].Tag.Cal) ([bool]$s.Heads.Checked) -Owner $s.Dlg }
    })
    $btnGo.Add_Click({
        $s = $script:HcDlg
        if ($s.Lv.SelectedItems.Count -eq 0 -or -not $s.Lv.SelectedItems[0].Tag.Cal) { return }
        $t = if ($s.Quick.Checked) { 'level' } elseif ($s.Fine.Checked) { 'fine' } else { 'std' }
        $s.Choice = @{ Name = [string]$s.Lv.SelectedItems[0].Tag.Name; Test = $t; Heads = [bool]$s.Heads.Checked; NCyl = [int]$s.Cyl.Value; Warm = [bool]($s.Warm.Enabled -and $s.Warm.Checked)
                       WarmEn = [bool]$s.Warm.Enabled; WarmChk = [bool]$s.Warm.Checked; QuickEn = [bool]$s.Quick.Enabled }
        $s.Dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $dlg.Add_Shown({ $s = $script:HcDlg; if ($s) { if ($s.Lv.SelectedItems.Count -gt 0) { $s.Lv.SelectedItems[0].EnsureVisible() }; [void]$s.Lv.Focus() } })
    if ($sel) { $sel.Selected = $true; $sel.Focused = $true }
    Update-HomeCalibDialog
    # 12.8 (lot 5, A4 R1) : ecran plus bas que la fenetre (676 px de zone client) : hauteur de la zone de travail, defilement
    [void](Set-DlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))
    $dr = [System.Windows.Forms.DialogResult]::Cancel; $ch = $null; $last = ''
    try { $dr = $dlg.ShowDialog($form) }
    finally {
        if ($script:HcDlg) { $ch = $script:HcDlg.Choice; $last = [string]$script:HcDlg.Last }
        $script:HcDlg = $null; $htip.Dispose(); $dlg.Dispose()
    }
    if ($last) { $script:HomeCalFmt = $last }
    if ($dr -ne [System.Windows.Forms.DialogResult]::OK -or -not $ch) {
        # Type change sans calibration : cylindres retenus effaces (ils valaient pour l ancien type)
        if ($last -and $last -ne $prevFmt) { Set-Setting 'homeCalCyls' 0 }
        [void](Save-Config); return
    }
    $r = Start-HomeCalib $ch.Name $ch.Test $ch.Heads $ch.NCyl $ch.Warm
    # 12.8 (point 7) : choix de la fenetre ecrits dans les reglages une fois la calibration lancee (Start-HomeCalib les
    # recoit en parametres). Prechauffage : seulement si la case etait active (calibration complete, duree non nulle).
    # Test : celui de la liste de l onglet Ecriture, sauf quand le test rapide etait indisponible et la liste au test
    # rapide : la calibration complete en test fin lancee ici en devient la reference, le mode de l onglet est garde
    if ($r.Started) {
        Set-Setting 'homeCalHeads' $ch.Heads
        Set-Setting 'homeCalCyls' $ch.NCyl
        if ($ch.WarmEn) { Set-Setting 'warmFullCalib' $ch.WarmChk }
        if ($ch.QuickEn -or (Get-Setting 'calMode') -ne 'level') { Set-Setting 'calMode' $ch.Test }
    } elseif ($last -and $last -ne $prevFmt) { Set-Setting 'homeCalCyls' 0 }
    [void](Save-Config)
    if (-not $r.Started -and $r.Why) {
        # 12.8 (lot 5) : Show-AppMessage ecrit le message au journal (plus de ligne de journal en double)
        [void](Show-AppMessage ((T "Calibration non lancée : {0}.") -f "$($r.Why)") (T 'Calibration precomp') 'OK' 'Information')
    }
}
