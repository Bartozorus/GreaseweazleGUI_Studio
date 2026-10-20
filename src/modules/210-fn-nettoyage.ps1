# ============================== FONCTIONS : NETTOYAGE DES TETES ================

# ============================== NETTOYAGE DES TETES : PICTOGRAMMES =============
# Vignettes 120 x 84 des etapes du nettoyage, dessinees en GDI+ comme le logo (aucun fichier image) : disquette 3,5
# pouces du logo, facade de lecteur, fleches, gouttes, horloge. Couleurs du theme.

function Draw-PictoFloppy($g, [single]$x, [single]$y, [single]$s, [bool]$cleaning, [bool]$flip = $false) {
    # Disquette 3,5 pouces du logo (repere 0..64) en ($x, $y), cote $s, volet en haut ; $flip : volet en bas (vers la
    # fente du lecteur). Nettoyage : corps bleu, tissu dans la fenetre du volet, etiquette CLEAN ; donnees : flux du logo
    $st = $g.Save()
    if ($flip) { $g.TranslateTransform([single]($x + $s), [single]($y + $s)); $g.RotateTransform([single]180) }
    else { $g.TranslateTransform($x, $y) }
    $g.ScaleTransform([single]($s / 64.0), [single]($s / 64.0))
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(5, 4)), (New-Object System.Drawing.PointF(53, 4)),
        (New-Object System.Drawing.PointF(60, 11)), (New-Object System.Drawing.PointF(60, 58)), (New-Object System.Drawing.PointF(57, 61)),
        (New-Object System.Drawing.PointF(8, 61)), (New-Object System.Drawing.PointF(5, 58))))
    $cBody = if ($cleaning) { [System.Drawing.Color]::FromArgb(58, 104, 160) } else { $script:Theme.Floppy }
    $bBody = New-Object System.Drawing.SolidBrush($cBody)
    $bMetal = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 212, 222))
    $bLabel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 249, 252))
    $g.FillPath($bBody, $body)
    $pShutter = New-RoundRect 17 4 30 20 2; $g.FillPath($bMetal, $pShutter); $pShutter.Dispose()   # 12.8 (FIX5) : chemin libere
    if ($cleaning) {
        $hb = New-Object System.Drawing.Drawing2D.HatchBrush([System.Drawing.Drawing2D.HatchStyle]::Weave, [System.Drawing.Color]::FromArgb(170, 188, 214), [System.Drawing.Color]::White)
        $g.FillRectangle($hb, [single]34, [single]7, [single]11, [single]14); $hb.Dispose()
    } else { $g.FillRectangle($bBody, [single]36, [single]8, [single]7, [single]12) }
    $pLabel = New-RoundRect 11 31 42 26 2.5; $g.FillPath($bLabel, $pLabel); $pLabel.Dispose()
    if ($cleaning) {
        $f = New-Object System.Drawing.Font('Segoe UI', [single]11, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        # disquette retournee : etiquette lisible quand meme (dernier trace avant Restore)
        $rc = New-Object System.Drawing.RectangleF(11, 31, 42, 26)
        if ($flip) { $g.TranslateTransform([single]32, [single]44); $g.RotateTransform([single]180); $rc = New-Object System.Drawing.RectangleF(-21, -13, 42, 26) }
        $g.DrawString('CLEAN', $f, $bBody, $rc, $sf)
        $f.Dispose(); $sf.Dispose()
    } else {
        $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]2.6); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $xs = @(14, 18, 18, 22, 22, 28, 28, 31, 31, 37, 37, 41, 41, 45, 45, 50); $ys = @(48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39)
        $g.DrawLines($pen, [System.Drawing.PointF[]]@(for ($i = 0; $i -lt $xs.Count; $i++) { New-Object System.Drawing.PointF($xs[$i], $ys[$i]) }))
        $pen.Dispose()
    }
    $bBody.Dispose(); $bMetal.Dispose(); $bLabel.Dispose(); $body.Dispose()
    $g.Restore($st)
}

function Draw-PictoDrive($g, [bool]$on) {
    # Facade de lecteur 3,5 pouces en bas de la vignette : fente, voyant (vert : moteur en marche), bouton d ejection
    # 12.8 (FIX5) : chemins de New-RoundRect liberes
    $p = New-RoundRect 6 56 108 26 4
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(64, 70, 84)); $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(18, 22, 30)); $g.FillRectangle($b, [single]20, [single]62, [single]80, [single]5); $b.Dispose()
    $p = New-RoundRect 80 72 16 5 2
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 156, 168)); $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
    $cl = if ($on) { [System.Drawing.Color]::FromArgb(90, 220, 110) } else { [System.Drawing.Color]::FromArgb(48, 78, 58) }
    $b = New-Object System.Drawing.SolidBrush($cl); $g.FillRectangle($b, [single]24, [single]73, [single]10, [single]3); $b.Dispose()
}

function Draw-PictoArrow($g, [System.Drawing.Color]$c, [single]$x1, [single]$y1, [single]$x2, [single]$y2) {
    $pen = New-Object System.Drawing.Pen($c, [single]3)
    $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(3, 3)
    $g.DrawLine($pen, $x1, $y1, $x2, $y2); $pen.Dispose()
}

function Fill-PictoDrop($g, $brush, [single]$cx, [single]$cy, [single]$r) {
    # Goutte : cercle de rayon $r centre en ($cx, $cy), pointe 2,2 $r au-dessus du centre
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]-27, [single]234)
    $p.AddLine($p.GetLastPoint(), (New-Object System.Drawing.PointF($cx, [single]($cy - 2.2 * $r))))
    $p.CloseFigure(); $g.FillPath($brush, $p); $p.Dispose()
}

function Draw-PictoClock($g, [single]$cx, [single]$cy, [single]$r, $color = $null) {
    # 12.8 (lot 3) : couleur du trait en parametre (Theme.Accent par defaut) : pictogrammes de qualite en cours et perimes
    $pen = New-Object System.Drawing.Pen($(if ($color) { [System.Drawing.Color]$color } else { $script:Theme.Accent }), [single]2.5)
    $g.FillEllipse([System.Drawing.Brushes]::White, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $g.DrawLine($pen, $cx, $cy, $cx, [single]($cy - 0.65 * $r)); $g.DrawLine($pen, $cx, $cy, [single]($cx + 0.5 * $r), $cy)
    $pen.Dispose()
}

function New-CleanPicto([string]$kind) {
    # Vignette d une etape : disk (disquette de nettoyage), drops (alcool sur le tissu), insert, run (zigzag de la tete),
    # dry (retirer, laisser secher), forbid (disquette de donnees barree : avertissement)
    $bmp = New-Object System.Drawing.Bitmap(120, 84, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    switch ($kind) {
        'disk' { Draw-PictoFloppy $g 26 2 80 $true }
        'drops' {
            Draw-PictoFloppy $g 2 18 66 $true
            # flacon incline vers la fenetre du volet, trois gouttes
            $st = $g.Save(); $g.TranslateTransform([single]96, [single]30); $g.RotateTransform([single]-100)
            $bw = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White); $pen = New-Object System.Drawing.Pen($script:Theme.Accent, [single]2)
            $bp = New-RoundRect -13 -10 26 30 4; $g.FillPath($bw, $bp); $g.DrawPath($pen, $bp)
            $g.FillRectangle($bw, [single]-5, [single]-19, [single]10, [single]9); $g.DrawRectangle($pen, [single]-5, [single]-19, [single]10, [single]9)
            $g.Restore($st)
            $f = New-Object System.Drawing.Font('Segoe UI', [single]10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
            $bt = New-Object System.Drawing.SolidBrush($script:Theme.Accent)
            $g.DrawString('IPA', $f, $bt, (New-Object System.Drawing.RectangleF(84, 50, 30, 14)), $sf)
            $bd = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 150, 230))
            Fill-PictoDrop $g $bd 70 32 3.2; Fill-PictoDrop $g $bd 60 26 3.2; Fill-PictoDrop $g $bd 50 34 3.2
            $bw.Dispose(); $pen.Dispose(); $f.Dispose(); $sf.Dispose(); $bt.Dispose(); $bd.Dispose(); $bp.Dispose()
        }
        'insert' {
            Draw-PictoFloppy $g 38 0 44 $true $true
            Draw-PictoDrive $g $false
            Draw-PictoArrow $g $script:Theme.Accent 98 10 98 50
        }
        'run' {
            Draw-PictoDrive $g $true
            # va-et-vient de la tete sur toute la surface : zigzag termine par une fleche
            $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]3); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(3, 3)
            $xs = @(12, 26, 40, 54, 68, 82, 96, 110); $pts = for ($i = 0; $i -lt $xs.Count; $i++) { New-Object System.Drawing.PointF($xs[$i], $(if ($i % 2) { 12 } else { 40 })) }
            $g.DrawLines($pen, [System.Drawing.PointF[]]$pts); $pen.Dispose()
        }
        'dry' {
            Draw-PictoFloppy $g 10 0 44 $true $true
            Draw-PictoDrive $g $false
            Draw-PictoArrow $g $script:Theme.Accent 62 46 62 8
            Draw-PictoClock $g 92 26 18
        }
        'forbid' {
            Draw-PictoFloppy $g 24 2 72 $false
            $pen = New-Object System.Drawing.Pen($script:Theme.Danger, [single]7)
            $g.DrawEllipse($pen, [single]22, [single]4, [single]76, [single]76); $g.DrawLine($pen, [single]35, [single]17, [single]85, [single]67)
            $pen.Dispose()
        }
    }
    $g.Dispose()
    return $bmp
}

function Get-CleanSeconds([int]$passes, [int]$linger, [int]$cyls) {
    # Duree estimee de gw clean avec les delais d usine du firmware (pas 10 ms, stabilisation 15 ms, moteur 750 ms) :
    # meme parcours que clean.py, tete partant du cylindre 0. Estimation : les reglages de l onglet Delais l allongent
    $step = [math]::Max([math]::Floor($cyls / 8), 2)
    $pos = 0; $steps = 0; $stops = 0
    for ($p = 0; $p -lt $passes; $p++) {
        for ($c = 0; $c -lt $cyls; $c += $step) {
            foreach ($t in @([math]::Min($c + $step - 1, $cyls - 1), $c)) { $steps += [math]::Abs($t - $pos); $pos = $t; $stops++ }
        }
    }
    return 0.75 + 0.010 * $steps + $stops * (0.015 + $linger / 1000.0)
}

function Get-CleanPresets {
    # Standard : 3 passes de 500 ms, environ 30 s (un cycle de la notice 3M) ; Courte : reglage de gw ; Longue : 8 passes
    return @(
        @{ Name = (T 'Standard : 3 passes, 500 ms par position'); Passes = 3; Linger = 500 },
        @{ Name = (T 'Courte : 3 passes, 100 ms par position (réglage de gw)'); Passes = 3; Linger = 100 },
        @{ Name = (T 'Longue : 8 passes, 500 ms par position'); Passes = 8; Linger = 500 }
    )
}

function Test-GwIdle {
    # Aucune operation en cours (12.8, D20 : Get-AppBusy, test unique : gw, chaine d etapes, controle, calibration,
    # restauration, detection, prechauffage d ecriture, mesure continue de l onglet Qualite). Garde pour frmClean et le banc
    return -not (Get-AppBusy)
}

function Get-CleanStepTexts([bool]$wet, [string]$drive, [string]$dur) {
    # Textes des cinq vignettes de la procedure ; sechage : notice du kit d abord, CleanDryMinutes a defaut. Espaces
    # insecables dans la duree, apres « et devant : ; % » : aucun signe isole en debut de ligne dans les vignettes etroites
    $nb = [string][char]0x00A0
    $t = @(
        (T 'Une disquette à tissu, vendue pour cet usage. Jamais une disquette de données.'),
        $(if ($wet) { (T "Quelques gouttes d'alcool isopropylique (90 % ou plus) sur le tissu, par la fenêtre du volet : humide, pas détrempé.") } else { (T 'Disquette sèche : rien à faire à cette étape.') }),
        ((T 'Insérez-la dans le lecteur {0}, volet en avant, comme une disquette ordinaire.') -f "$drive"),
        ((T 'Cochez la case, puis « Lancer le nettoyage ». La tête va et vient pendant {0} environ ; le bruit est normal.') -f "$($dur.Replace(' ', $nb))"),
        $(if ($wet) { ((T "Retirez-la, puis laissez sécher les têtes le temps indiqué par la notice du kit (à défaut, {0} min par prudence) avant d'insérer une disquette de données.") -f "$($script:CleanDryMinutes)") } else { (T 'Retirez-la : le lecteur est prêt.') })
    )
    return @($t | ForEach-Object { (($_ -replace ' ([:;%»])', "$nb`$1") -replace '« ', "«$nb") })
}

function Start-HeadClean([string]$drive, [int]$cyls, [int]$passes, [int]$linger, [bool]$wet) {
    # gw clean sur le lecteur $drive ; $script:CleanRun suit la commande (Update-Progress : passes vues, autres lignes).
    # --cyls seulement s il differe du defaut de gw (80). $false si gw n a pas demarre
    $est = Get-CleanSeconds $passes $linger $cyls
    $kind = if ($wet) { (T 'humide') } else { (T 'sèche') }
    Append-Log ((T 'Nettoyage des têtes du lecteur {0} : {1} passe(s) en zigzag sur {2} cylindres, {3} ms à chaque position, durée estimée {4} ; disquette de nettoyage {5}.') -f "$drive", "$passes", "$cyls", "$linger", (Format-CalDuration ([math]::Round($est))), "$kind")
    $a = @('clean', "--drive=$drive")
    if ($txtDev.Text.Trim()) { $a += "--device=$($txtDev.Text.Trim())" }
    if ($cyls -ne 80) { $a += "--cyls=$cyls" }
    $a += @("--passes=$passes", "--linger=$linger")
    Start-Gw $a
    if (-not ($script:GwProc -and $script:GwProc.StartInfo.Arguments -match '(^|\s)clean\s')) { return $false }
    $script:CleanRun = @{ Drive = $drive; Passes = $passes; Done = 0; Lines = (New-Object System.Collections.Generic.List[string])
                          Stopped = $false; Wet = $wet; Est = $est; Start = Get-Date }
    return $true
}

function Stop-HeadClean {
    # Arreter (fenetre de nettoyage) ou fermeture de la fenetre pendant le nettoyage. gw tue ne coupe pas le moteur :
    # le firmware le coupe a la fin du delai watchdog (10 s par defaut, onglet Delais). gw deja termine : bilan normal
    $r = $script:CleanRun
    if (-not $r -or $r.Stopped) { return }
    if (-not ($script:GwProc -and -not $script:GwProc.HasExited)) { return }
    $r.Stopped = $true
    try { $script:GwProc.Kill($true) } catch { try { $script:GwProc.Kill() } catch { } }
    Append-Log (T '*** Interrompu par l''utilisateur ***')
}

function Complete-HeadClean {
    # Fin de gw clean : bilan dans le journal et texte de fin de la fenetre. Renvoie @{ Ok ; Text ; Color }
    $r = $script:CleanRun; $script:CleanRun = $null
    if (-not $r) { return @{ Ok = $false; Text = ''; Color = $null } }
    $code = [int]$script:GwLastCode
    $lines = @($r.Lines | Where-Object { $_.Trim() })
    $failed = (-not $r.Stopped) -and ($code -ne 0 -or @($lines | Where-Object { $_ -match 'Command Failed|FATAL' }).Count -gt 0 -or $r.Done -lt $r.Passes)
    $ok = (-not $r.Stopped) -and (-not $failed)
    $dryAt = (Get-Date).AddMinutes($script:CleanDryMinutes).ToString('HH:mm')
    $parts = @()
    if ($ok) { $parts += (T 'Nettoyage terminé : retirez la disquette de nettoyage.') }
    elseif ($r.Stopped) { $parts += (T "Nettoyage interrompu. Le moteur du lecteur peut tourner encore jusqu'à la fin du délai de sécurité du Greaseweazle (watchdog, 10 s par défaut) : attendez qu'il s'arrête, puis retirez la disquette de nettoyage.") }
    else {
        # Raison : deux dernieres lignes utiles, sans le debut de la ligne de passe ni les prefixes d erreur de gw ; code 0
        # sans erreur signalee mais passes manquantes : nombre de passes vues, puis la derniere ligne de gw
        $useful = @($lines | ForEach-Object { ((($_ -replace '^Pass \d+:[\d ]*', '') -replace 'FATAL ERROR:?|Command Failed:?', '') -replace '\*', '').Trim() } | Where-Object { $_ })
        if ($code -eq 0 -and @($lines | Where-Object { $_ -match 'Command Failed|FATAL' }).Count -eq 0) {
            $why = ((T "gw s'est arrêté après {0} passe(s) sur {1}") -f "$($r.Done)", "$($r.Passes)")
            if ($useful.Count -gt 0) { $why += ' / ' + $useful[-1] }
        } else {
            $why = (@($useful) | Select-Object -Last 2) -join ' / '
            if (-not $why) { $why = ((T "gw a retourné le code {0}, voir le journal") -f "$code") }
        }
        Append-Log ((T 'ÉCHEC du nettoyage des têtes : {0}') -f "$why")
        $parts += (T "Le nettoyage n'a pas abouti : retirez la disquette de nettoyage, vérifiez le lecteur choisi et son câblage (carte « Tester le Greaseweazle » de l'Accueil), puis relancez.")
    }
    if ($r.Wet -and ($ok -or $r.Done -gt 0 -or $r.Stopped)) { $parts += ((T "Disquette humide : laissez sécher les têtes le temps indiqué par la notice du kit avant d'insérer une disquette de données ; à défaut, attendez par prudence jusqu'à {0}.") -f "$dryAt") }
    elseif ($ok) { $parts += (T 'Le lecteur est prêt.') }
    if ($ok) { $parts += (T "Comptez cette utilisation sur l'étiquette de la disquette de nettoyage : elle s'use.") }
    $text = $parts -join ' '
    Append-Log $text
    $color = if ($ok) { $script:Theme.Ok } elseif ($r.Stopped) { $script:Theme.Warn } else { $script:Theme.Danger }
    return @{ Ok = $ok; Text = $text; Color = $color; Outcome = $(if ($ok) { 'ok' } elseif ($r.Stopped) { 'stop' } else { 'fail' }) }
}

function Get-CleanDlgOptions {
    # Options choisies dans la fenetre de nettoyage, avec la duree estimee
    $s = $script:CleanDlg
    $pr = $s.Presets[[math]::Max(0, $s.Dur.SelectedIndex)]
    $cyls = if ($s.Cyls.SelectedIndex -eq 1) { 40 } else { 80 }
    return @{ Drive = [string]$s.Drive.SelectedItem; Cyls = $cyls; Passes = [int]$pr.Passes; Linger = [int]$pr.Linger; Wet = [bool]$s.Wet.Checked
              Est = (Get-CleanSeconds ([int]$pr.Passes) ([int]$pr.Linger) $cyls) }
}

function Set-CleanTiles([int]$cur, [string]$endTag = '') {
    # Vignettes : avant $cur faites (vert), $cur en cours (bleu), apres a faire ; etape 2 grisee avec une disquette seche.
    # endTag 'stop' ou 'fail' (fin du nettoyage interrompu ou en echec) : la vignette juste avant $cur (4, « Lancer le
    # nettoyage ») est marquee interrompue (orange) ou en echec (rouge), et non faite
    $s = $script:CleanDlg
    for ($i = 0; $i -lt $s.Tiles.Count; $i++) {
        $t = $s.Tiles[$i]
        $tag = if ($cur -lt 0 -or $i -gt $cur) { 'todo' } elseif ($i -lt $cur) { 'done' } else { 'cur' }
        if ($i -eq $cur - 1 -and @('stop', 'fail') -contains $endTag) { $tag = $endTag }
        if ($i -eq 1 -and -not $s.Wet.Checked) { $tag = 'skip' }
        $t.Panel.Tag = $tag
        $t.Panel.BackColor = switch ($tag) {
            'done' { [System.Drawing.Color]::FromArgb(236, 247, 240) }
            'cur'  { [System.Drawing.Color]::FromArgb(234, 241, 251) }
            'skip' { [System.Drawing.Color]::FromArgb(244, 245, 247) }
            'stop' { [System.Drawing.Color]::FromArgb(253, 243, 228) }
            'fail' { [System.Drawing.Color]::FromArgb(253, 236, 234) }
            default { [System.Drawing.Color]::White }
        }
        $t.Title.ForeColor = if ($tag -eq 'skip') { $script:Theme.Muted } else { $script:Theme.Accent2 }
        $t.Panel.Invalidate()
    }
}

function Update-CleanDlg {
    # Textes des etapes et duree estimee d apres les options ; vignettes selon la case de confirmation
    $s = $script:CleanDlg
    if (-not $s -or $s.Phase -eq 'run') { return }
    $o = Get-CleanDlgOptions
    $dur = Format-CalDuration ([math]::Round($o.Est))
    $txt = Get-CleanStepTexts $o.Wet $o.Drive $dur
    for ($i = 0; $i -lt 5; $i++) { $s.Tiles[$i].Desc.Text = $txt[$i] }
    $s.Est.Text = ((T 'durée estimée : {0}') -f "$dur")
    # Case de confirmation : elle nomme le lecteur choisi (decochee a chaque changement de lecteur ou de type)
    $s.Chk.Text = ((T "J'ai inséré une disquette de nettoyage dans le lecteur {0}") -f "$($o.Drive)")
    if ($s.Phase -eq 'ready') { Set-CleanTiles $(if ($s.Chk.Checked) { 3 } else { -1 }) }
}

function Set-CleanGo([bool]$on) {
    # Bouton « Lancer le nettoyage » : bleu seulement quand il est actif (case cochee), sinon style normal grise ; style
    # (et icone) refait seulement quand il change
    $s = $script:CleanDlg; $b = $s.Go
    $b.Enabled = $on
    $st = if ($on) { 'primary' } else { 'normal' }
    if ($s.GoStyle -ne $st) { $s.GoStyle = $st; Set-Btn $b 'Repair' $st }
}

function Set-CleanDlgPhase([string]$phase, [string]$text = '', $color = $null, [string]$outcome = '') {
    # Etat de la fenetre : ready (options modifiables), run (gw clean en cours), end (termine, arrete ou en echec ;
    # outcome 'ok', 'stop' ou 'fail' de Complete-HeadClean : vignette 4 faite, interrompue ou en echec)
    $s = $script:CleanDlg
    if (-not $s) { return }
    if ($phase -eq 'end' -and $s.Chk.Checked) { $s.Busy = $true; $s.Chk.Checked = $false; $s.Busy = $false }   # nouvelle confirmation pour relancer
    $s.Phase = $phase
    $run = ($phase -eq 'run')
    foreach ($c in @($s.Drive, $s.Cyls, $s.Wet, $s.Dry, $s.Dur, $s.Chk)) { $c.Enabled = -not $run }
    $s.Go.Visible = -not $run; $s.Stop.Visible = $run; $s.Bar.Visible = $run
    Set-CleanGo ((-not $run) -and $s.Chk.Checked)
    if ($run) { $s.Bar.Value = 0 }
    $s.State.ForeColor = if ($color) { $color } else { $script:Theme.Accent2 }
    $s.State.Text = $text
    if ($phase -eq 'end') { Set-CleanTiles 4 $outcome } else { Set-CleanTiles $(if ($run -or $s.Chk.Checked) { 3 } else { -1 }) }
}

function Set-CleanDlgFit($dlg, [System.Drawing.Rectangle]$wa) {
    # Ecran trop petit pour la fenetre de nettoyage (zone de travail $wa) : hauteur ramenee a celle de l ecran avec un
    # defilement vertical, largeur augmentee de la barre de defilement (pas de defilement horizontal). $true si ajustee
    if ($dlg.Height -le $wa.Height) { return $false }
    $dlg.AutoScroll = $true
    $dlg.Size = New-Object System.Drawing.Size(($dlg.Width + [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth), $wa.Height)
    return $true
}

function New-CleanDialog([int]$Passes = 0, [int]$Linger = 0) {
    # Construit la fenetre de nettoyage (sans l afficher) et $script:CleanDlg. $Passes > 0 : reglage de l onglet Outils.
    # Hauteurs des textes (vignettes, avertissement, etat) mesurees dans la langue de l interface
    $W = 880; $tw = 168; $gap = [int](($W - 5 * $tw) / 4)    # largeur : hauteur de la fenetre sous 720 px (ecran 1366 x 768)
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $gdi = New-Object System.Collections.Generic.List[object]       # images et polices liberees avec la fenetre
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmClean'; $dlg.Text = (T 'Nettoyage des têtes')
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    $ctip = New-Object System.Windows.Forms.ToolTip
    $ctip.AutoPopDelay = 30000; $ctip.InitialDelay = 400; $ctip.ReshowDelay = 100

    # Avertissement, en tete et en rouge
    $pnlW = New-Object System.Windows.Forms.Panel
    $pnlW.Name = 'pnlCleanWarn'; $pnlW.Location = New-Object System.Drawing.Point(16, 16); $pnlW.BackColor = [System.Drawing.Color]::FromArgb(253, 236, 234)
    $picW = New-Object System.Windows.Forms.PictureBox
    $picW.Image = New-CleanPicto 'forbid'; $gdi.Add($picW.Image); $picW.SizeMode = 'Zoom'; $picW.Location = New-Object System.Drawing.Point(8, 10); $picW.Size = New-Object System.Drawing.Size(100, 70)
    $fWT = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $gdi.Add($fWT)
    $lblWT = New-Object System.Windows.Forms.Label
    $lblWT.Name = 'lblCleanWarnTitle'; $lblWT.Text = (T 'NE LANCEZ JAMAIS LE NETTOYAGE AVEC UNE VRAIE DISQUETTE'); $lblWT.UseMnemonic = $false; $lblWT.AutoEllipsis = $true
    $lblWT.Font = $fWT; $lblWT.ForeColor = [System.Drawing.Color]::FromArgb(160, 32, 26)
    $lblWT.Location = New-Object System.Drawing.Point(118, 10); $lblWT.Size = New-Object System.Drawing.Size(($W - 128), 24)
    $wTxt = (T "Pendant le nettoyage, la tête balaie toute la surface en va-et-vient, moteur en marche, pour frotter sa saleté contre le tissu. Une vraie disquette (données, original ou disquette vierge à garder) risquerait d'être rayée par cette saleté et de perdre ses données, sans retour possible. N'insérez qu'une disquette de nettoyage, et suivez d'abord la notice de son kit.")
    $lblW = New-Object System.Windows.Forms.Label
    $lblW.Name = 'lblCleanWarn'; $lblW.Text = $wTxt; $lblW.UseMnemonic = $false; $lblW.ForeColor = [System.Drawing.Color]::FromArgb(110, 24, 20)
    $hw = [System.Windows.Forms.TextRenderer]::MeasureText($wTxt, $dlg.Font, (New-Object System.Drawing.Size(($W - 128), 10000)), $tf).Height
    $lblW.Location = New-Object System.Drawing.Point(118, 38); $lblW.Size = New-Object System.Drawing.Size(($W - 128), ($hw + 4))
    $pnlW.Size = New-Object System.Drawing.Size($W, [math]::Max(90, $lblW.Bottom + 10))
    $pnlW.Controls.AddRange(@($picW, $lblWT, $lblW))
    $pnlW.Add_Paint({ $pen = New-Object System.Drawing.Pen($script:Theme.Danger, [single]2); $_.Graphics.DrawRectangle($pen, 1, 1, $this.Width - 2, $this.Height - 2); $pen.Dispose() })

    # Procedure en cinq vignettes ; hauteur des textes : la plus grande de toutes les variantes (humide / seche)
    $titles = @((T '1. Disquette de nettoyage'), (T '2. Humidifier le tissu'), (T '3. Insérer'), (T '4. Lancer le nettoyage'), (T '5. Retirer, laisser sécher'))
    $kinds = @('disk', 'drops', 'insert', 'run', 'dry')
    $fT = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fT)
    $tsz = New-Object System.Drawing.Size(($tw - 8), 10000)
    $hT = 0; foreach ($s in $titles) { $hT = [math]::Max($hT, [System.Windows.Forms.TextRenderer]::MeasureText($s, $fT, $tsz, $tf).Height) }
    $hD = 0
    foreach ($v in @((Get-CleanStepTexts $true 'A' '88 min 88 s'), (Get-CleanStepTexts $false 'A' '88 min 88 s'))) {   # duree la plus large
        foreach ($s in $v) { $hD = [math]::Max($hD, [System.Windows.Forms.TextRenderer]::MeasureText($s, $dlg.Font, $tsz, $tf).Height) }
    }
    $yT = $pnlW.Bottom + 14
    $tiles = @()
    for ($i = 0; $i -lt 5; $i++) {
        $p = New-Object System.Windows.Forms.Panel
        $p.Name = "pnlCleanStep$($i + 1)"; $p.Tag = 'todo'; $p.BackColor = [System.Drawing.Color]::White
        $p.Location = New-Object System.Drawing.Point((16 + $i * ($tw + $gap)), $yT); $p.Size = New-Object System.Drawing.Size($tw, (92 + $hT + 4 + $hD + 8))
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = New-CleanPicto $kinds[$i]; $gdi.Add($pic.Image); $pic.Location = New-Object System.Drawing.Point([int](($tw - 120) / 2), 4); $pic.Size = New-Object System.Drawing.Size(120, 84)
        $lt = New-Object System.Windows.Forms.Label
        $lt.Name = "lblCleanTitle$($i + 1)"; $lt.Text = $titles[$i]; $lt.UseMnemonic = $false; $lt.Font = $fT; $lt.ForeColor = $script:Theme.Accent2
        $lt.Location = New-Object System.Drawing.Point(4, 92); $lt.Size = New-Object System.Drawing.Size(($tw - 8), $hT)
        $ld = New-Object System.Windows.Forms.Label
        $ld.Name = "lblCleanStep$($i + 1)"; $ld.UseMnemonic = $false; $ld.ForeColor = [System.Drawing.Color]::FromArgb(70, 76, 88)
        $ld.Location = New-Object System.Drawing.Point(4, (96 + $hT)); $ld.Size = New-Object System.Drawing.Size(($tw - 8), $hD)
        $p.Controls.AddRange(@($pic, $lt, $ld))
        $p.Add_Paint({
            $c = switch ([string]$this.Tag) { 'cur' { $script:Theme.Accent } 'done' { $script:Theme.Ok } 'stop' { $script:Theme.Warn } 'fail' { $script:Theme.Danger } default { [System.Drawing.Color]::FromArgb(205, 212, 224) } }
            $pen = New-Object System.Drawing.Pen($c, [single]$(if (@('cur', 'stop', 'fail') -contains [string]$this.Tag) { 2 } else { 1 }))
            $_.Graphics.DrawRectangle($pen, 0, 0, $this.Width - 1, $this.Height - 1); $pen.Dispose()
        })
        $tiles += @(@{ Panel = $p; Title = $lt; Desc = $ld })
    }

    # Options
    $y = $yT + $tiles[0].Panel.Height + 14
    $l1 = New-Label (T 'Lecteur :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $cmbD = New-Object System.Windows.Forms.ComboBox
    $cmbD.Name = 'cmbCleanDrive'; $cmbD.DropDownStyle = 'DropDownList'; $cmbD.Width = 56; $cmbD.Location = New-Object System.Drawing.Point(110, $y)
    # 12.8 (point 7) : reglage « drive » lu a l ouverture, ecrit au lancement du nettoyage (lecteur du bandeau)
    [void]$cmbD.Items.AddRange([string[]]$script:SettingDefs['drive'].Codes)
    $cmbD.SelectedItem = [string](Get-Setting 'drive'); if ($cmbD.SelectedIndex -lt 0) { $cmbD.SelectedIndex = 0 }
    $l2 = New-Label (T 'Type :') (New-Object System.Drawing.Point(190, ($y + 3)))
    $cmbC = New-Object System.Windows.Forms.ComboBox
    $cmbC.Name = 'cmbCleanCyls'; $cmbC.DropDownStyle = 'DropDownList'; $cmbC.Location = New-Object System.Drawing.Point(250, $y); $cmbC.Width = ($W + 16 - 250)
    [void]$cmbC.Items.AddRange(@((T 'Lecteur 80 pistes : 3,5 pouces, ou 5,25 pouces haute densité'), (T 'Lecteur 40 pistes : 5,25 pouces double densité (360 Ko)')))
    $cmbC.SelectedIndex = $(if ([int]$script:CleanPrefs.Cyls -eq 40) { 1 } else { 0 })
    $ctip.SetToolTip($cmbC, (T "Course de la tête pendant le nettoyage (--cyls). Un lecteur 40 pistes ne doit pas être envoyé au-delà de sa butée."))
    $y += 34
    $l3 = New-Label (T 'Disquette :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $rbWet = New-Object System.Windows.Forms.RadioButton
    $rbWet.Name = 'rbCleanWet'; $rbWet.Text = (T 'humide (alcool isopropylique)'); $rbWet.AutoSize = $true; $rbWet.Checked = [bool]$script:CleanPrefs.Wet
    $rbWet.Location = New-Object System.Drawing.Point(110, ($y + 1))
    $rbDry = New-Object System.Windows.Forms.RadioButton
    $rbDry.Name = 'rbCleanDry'; $rbDry.Text = (T 'sèche'); $rbDry.AutoSize = $true; $rbDry.Checked = -not $rbWet.Checked
    $rbDry.Location = New-Object System.Drawing.Point((110 + [System.Windows.Forms.TextRenderer]::MeasureText($rbWet.Text, $dlg.Font).Width + 40), ($y + 1))
    $y += 34
    $l4 = New-Label (T 'Durée :') (New-Object System.Drawing.Point(16, ($y + 3)))
    $presets = @(Get-CleanPresets)
    if ($Passes -gt 0) { $presets += @(@{ Name = ((T 'Réglage de l''onglet Outils : {0} passe(s), {1} ms par position') -f "$Passes", "$Linger"); Passes = $Passes; Linger = $Linger }) }
    $cmbT = New-Object System.Windows.Forms.ComboBox
    $cmbT.Name = 'cmbCleanDur'; $cmbT.DropDownStyle = 'DropDownList'; $cmbT.Location = New-Object System.Drawing.Point(110, $y); $cmbT.Width = 420
    foreach ($pr in $presets) { [void]$cmbT.Items.Add($pr.Name) }
    $cmbT.SelectedIndex = $(if ($Passes -gt 0) { $presets.Count - 1 } else { [math]::Max(0, [math]::Min(2, [int]$script:CleanPrefs.Preset)) })
    $lEst = New-Label '' (New-Object System.Drawing.Point(542, ($y + 3))); $lEst.Name = 'lblCleanEst'; $lEst.ForeColor = $script:Theme.Muted
    $y += 36
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Name = 'chkCleanOk'; $chk.Text = ((T "J'ai inséré une disquette de nettoyage dans le lecteur {0}") -f "$($cmbD.Text)"); $chk.AutoSize = $true; $chk.Font = $bold; $chk.UseMnemonic = $false
    $chk.Location = New-Object System.Drawing.Point(16, $y)
    $y += 28
    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Name = 'pbClean'; $bar.Location = New-Object System.Drawing.Point(16, $y); $bar.Size = New-Object System.Drawing.Size($W, 16); $bar.Maximum = 1000; $bar.Visible = $false
    # Etat : hauteur du plus long texte de fin (echec ou arret suivi du sechage, succes humide), 3 lignes au moins
    $fS = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75); $gdi.Add($fS)
    $wetEnd = ((T "Disquette humide : laissez sécher les têtes le temps indiqué par la notice du kit avant d'insérer une disquette de données ; à défaut, attendez par prudence jusqu'à {0}.") -f '00:00')
    $hS = 0
    foreach ($e in @(((T 'Nettoyage terminé : retirez la disquette de nettoyage.') + ' ' + $wetEnd + ' ' + (T "Comptez cette utilisation sur l'étiquette de la disquette de nettoyage : elle s'use.")),
                     ((T "Nettoyage interrompu. Le moteur du lecteur peut tourner encore jusqu'à la fin du délai de sécurité du Greaseweazle (watchdog, 10 s par défaut) : attendez qu'il s'arrête, puis retirez la disquette de nettoyage.") + ' ' + $wetEnd),
                     ((T "Le nettoyage n'a pas abouti : retirez la disquette de nettoyage, vérifiez le lecteur choisi et son câblage (carte « Tester le Greaseweazle » de l'Accueil), puis relancez.") + ' ' + $wetEnd))) {
        $hS = [math]::Max($hS, [System.Windows.Forms.TextRenderer]::MeasureText($e, $fS, (New-Object System.Drawing.Size($W, 10000)), $tf).Height)
    }
    $hS = [math]::Max($hS, 3 * $fS.Height)
    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Name = 'lblCleanState'; $lblS.UseMnemonic = $false; $lblS.Font = $fS
    $lblS.Location = New-Object System.Drawing.Point(16, ($y + 20)); $lblS.Size = New-Object System.Drawing.Size($W, ($hS + 4))
    $y = $lblS.Bottom + 8
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Name = 'btnCleanStart'; $btnGo.Text = (T 'Lancer le nettoyage'); $btnGo.Size = New-Object System.Drawing.Size(230, 34); $btnGo.Enabled = $false
    $btnStp = New-Object System.Windows.Forms.Button
    $btnStp.Name = 'btnCleanStop'; $btnStp.Text = (T 'Arrêter'); $btnStp.Size = New-Object System.Drawing.Size(130, 34); $btnStp.Visible = $false
    $btnCl = New-Object System.Windows.Forms.Button
    $btnCl.Name = 'btnCleanClose'; $btnCl.Text = (T 'Fermer'); $btnCl.Size = New-Object System.Drawing.Size(110, 34)
    $btnCl.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnGo 'Repair' 'primary'; Set-Btn $btnStp 'Stop' 'danger'; Set-Btn $btnCl '' 'normal'
    $btnCl.Location = New-Object System.Drawing.Point((16 + $W - $btnCl.Width), $y)
    $btnGo.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnGo.Width), $y)
    $btnStp.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnStp.Width), $y)
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + $btnCl.Height + 16))
    $dlg.CancelButton = $btnCl                        # pas d AcceptButton : Entree ne lance pas le nettoyage
    $dlg.Controls.AddRange(@($pnlW) + @($tiles | ForEach-Object { $_.Panel }) + @($l1, $cmbD, $l2, $cmbC, $l3, $rbWet, $rbDry, $l4, $cmbT, $lEst, $chk, $bar, $lblS, $btnGo, $btnStp, $btnCl))
    [void](Set-CleanDlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))

    $script:CleanDlg = @{ Dlg = $dlg; Tiles = $tiles; Drive = $cmbD; Cyls = $cmbC; Wet = $rbWet; Dry = $rbDry; Dur = $cmbT; Est = $lEst
                          Chk = $chk; Bar = $bar; State = $lblS; Go = $btnGo; Stop = $btnStp; Close = $btnCl; Presets = $presets
                          Phase = 'ready'; Busy = $false; Tmr = $null; Tip = $ctip; Gdi = $gdi; GoStyle = 'primary' }
    $upd = { Update-CleanDlg }
    # Lecteur ou type change apres la confirmation : case decochee (son gestionnaire desactive « Lancer le nettoyage »),
    # la disquette de nettoyage doit etre confirmee pour le nouveau lecteur. Avant Update-CleanDlg (vignettes a jour)
    $reset = { $s = $script:CleanDlg; if ($s -and $s.Phase -ne 'run' -and $s.Chk.Checked) { $s.Chk.Checked = $false } }
    $cmbD.Add_SelectedIndexChanged($reset); $cmbC.Add_SelectedIndexChanged($reset)
    $cmbD.Add_SelectedIndexChanged($upd); $cmbC.Add_SelectedIndexChanged($upd); $cmbT.Add_SelectedIndexChanged($upd); $rbWet.Add_CheckedChanged($upd)
    $chk.Add_CheckedChanged({
        $s = $script:CleanDlg
        if (-not $s -or $s.Busy -or $s.Phase -eq 'run') { return }
        $s.Phase = 'ready'; $s.State.Text = ''
        Set-CleanGo $this.Checked
        Set-CleanTiles $(if ($this.Checked) { 3 } else { -1 })
    })
    $btnGo.Add_Click({
        $s = $script:CleanDlg
        if (-not $s -or -not $s.Chk.Checked -or $script:CleanRun) { return }
        if (-not (Test-GwIdle)) { $s.State.ForeColor = $script:Theme.Warn; $s.State.Text = (T "Une commande gw est en cours : attendez qu'elle se termine, puis relancez."); return }
        $o = Get-CleanDlgOptions
        # choix memorises (enregistres par Start-Gw) ; le reglage de l onglet Outils n est pas un prereglage. 12.8 (point 7) :
        # lecteur choisi ecrit dans le reglage « drive » (bandeau), comme tout choix d une fenetre au lancement de l action :
        # avant Start-HeadClean (l enregistrement fait par Start-Gw le contient), lecteur d avant remis si gw n a pas demarre
        $script:CleanPrefs = @{ Wet = $o.Wet; Cyls = $o.Cyls; Preset = $(if ($s.Dur.SelectedIndex -le 2) { $s.Dur.SelectedIndex } else { $script:CleanPrefs.Preset }) }
        $prevDrive = Get-Setting 'drive'
        Set-Setting 'drive' $o.Drive
        if (-not (Start-HeadClean $o.Drive $o.Cyls $o.Passes $o.Linger $o.Wet)) { Set-Setting 'drive' $prevDrive; $s.State.ForeColor = $script:Theme.Danger; $s.State.Text = (T "gw n'a pas pu être lancé : voir le journal."); return }
        Set-CleanDlgPhase 'run' ((T 'Nettoyage en cours sur le lecteur {0}...') -f "$($o.Drive)")
    })
    $btnStp.Add_Click({ Stop-HeadClean })
    # Fermer, Echap ou la croix pendant le nettoyage : arret, et la fenetre reste ouverte sur le texte de fin (retirer,
    # laisser secher). Fermer et Echap passent par DialogResult (CloseReason None), la croix par UserClosing
    $dlg.Add_FormClosing({
        if (-not $script:CleanRun) { return }
        Stop-HeadClean
        if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing -or $_.CloseReason -eq [System.Windows.Forms.CloseReason]::None) { $_.Cancel = $true }
    })
    # Suivi : barre (passes terminees ou temps ecoule sur la duree estimee, 99 % au plus tant que gw tourne), puis bilan
    # quand le minuteur principal a traite la fin de gw ($script:GwProc remis a $null)
    $tmr = New-Object System.Windows.Forms.Timer
    $tmr.Interval = 250
    $tmr.Add_Tick({
        $s = $script:CleanDlg; $r = $script:CleanRun
        if (-not $s -or -not $r -or $s.Phase -ne 'run') { return }
        if ($script:GwProc) {
            $el = ((Get-Date) - $r.Start).TotalSeconds
            $v = [math]::Max(1000.0 * $r.Done / [math]::Max(1, $r.Passes), 1000.0 * $el / [math]::Max(1.0, $r.Est))
            $s.Bar.Value = [int][math]::Min(990.0, $v)
            $s.State.Text = ((T 'Nettoyage en cours sur le lecteur {0} : passe {1} sur {2}, reste environ {3}.') -f "$($r.Drive)", "$([math]::Min($r.Passes, $r.Done + 1))", "$($r.Passes)", (Format-CalDuration ([math]::Round([math]::Max(0.0, $r.Est - $el)))))
            return
        }
        $res = Complete-HeadClean
        Set-CleanDlgPhase 'end' $res.Text $res.Color $res.Outcome
    })
    $script:CleanDlg.Tmr = $tmr
    Set-CleanGo $false
    Update-CleanDlg
    return $dlg
}

function Show-CleanDialog([int]$Passes = 0, [int]$Linger = 0) {
    # Nettoyage des tetes : carte de l Accueil ; bouton NETTOYER de l onglet Outils ($Passes / $Linger de cet onglet)
    if (-not (Test-GwIdle)) {
        [void](Show-AppMessage (T "Opération en cours : lancez le nettoyage une fois l'opération terminée ou arrêtée.") (T 'Nettoyage des têtes') 'OK' 'Information'); return
    }
    $dlg = New-CleanDialog $Passes $Linger
    $s = $script:CleanDlg
    $s.Tmr.Start()
    try { [void]$dlg.ShowDialog($form) }
    finally {
        $s.Tmr.Stop(); $s.Tmr.Dispose()
        if ($script:CleanRun) { Stop-HeadClean; [void](Complete-HeadClean) }   # fenetre fermee par le systeme pendant le nettoyage
        $script:CleanDlg = $null
        $s.Tip.Dispose(); $dlg.Dispose()
        foreach ($o in $s.Gdi) { try { $o.Dispose() } catch { } }
    }
}
