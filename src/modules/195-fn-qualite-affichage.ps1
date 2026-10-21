# ============================== FONCTIONS : QUALITE, AFFICHAGE (12.8, LOT 3) ===
# Etat unique de l affichage de l onglet Qualite & alignement ($script:QualView, A2 § 2.2) : vide, en cours, resultat,
# perime ; jamais efface pendant une mesure, mais grise et marque (D16). Carte de resultat de la variante A (D14), dessinee
# dans un bitmap (fond de pnlQualCard) : pas de grisage des libelles quand Set-Busy desactive les onglets, pas de
# clignotement en mesure continue. Pictogrammes de score (barres de signal) et d etat (coche, !, croix) en GDI+ (D15),
# couleurs Theme.Ok / Good / WarnInk / Danger (D17). Ressources GDI+ (pinceaux, stylos, polices, formats, icones) en cache
# dans $script:QualGdi, liberees a la fermeture de la fenetre (Clear-QualityGdi).

# --- Ressources GDI+ en cache -----------------------------------------------------------------------------------------
function Get-QualBrush([System.Drawing.Color]$c) {
    $k = 'b' + $c.ToArgb()
    $o = $script:QualGdi[$k]
    if (-not $o) { $o = New-Object System.Drawing.SolidBrush($c); $script:QualGdi[$k] = $o }
    return $o
}

function Get-QualPen([System.Drawing.Color]$c, [single]$w = 1) {
    $k = 'p' + $c.ToArgb() + '|' + $w
    $o = $script:QualGdi[$k]
    if (-not $o) { $o = New-Object System.Drawing.Pen($c, $w); $script:QualGdi[$k] = $o }
    return $o
}

function Get-QualFont([string]$fam, [single]$size, [string]$style = 'Regular') {
    $k = "f$fam|$size|$style"
    $o = $script:QualGdi[$k]
    if (-not $o) { $o = New-Object System.Drawing.Font($fam, $size, [System.Drawing.FontStyle]$style); $script:QualGdi[$k] = $o }
    return $o
}

function Get-QualSf([string]$kind) {
    # Formats du tableau : 'near' / 'center' (cellules : une ligne, points de suspension), 'hnear' / 'hcenter' (en-tetes)
    $k = "s$kind"
    $o = $script:QualGdi[$k]
    if (-not $o) {
        $o = New-Object System.Drawing.StringFormat
        $o.LineAlignment = [System.Drawing.StringAlignment]::Center
        $o.Alignment = $(if ($kind -match 'near$') { [System.Drawing.StringAlignment]::Near } else { [System.Drawing.StringAlignment]::Center })
        if ($kind -notmatch '^h') { $o.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap; $o.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter }
        $script:QualGdi[$k] = $o
    }
    return $o
}

function Clear-QualityGdi {
    # Fermeture de la fenetre : pinceaux, stylos, polices, formats et icones du cache, bitmap de la carte
    foreach ($o in @($script:QualGdi.Values)) { try { $o.Dispose() } catch { } }
    $script:QualGdi.Clear()
    if ($pnlQualCard -and $pnlQualCard.BackgroundImage) { $b = $pnlQualCard.BackgroundImage; $pnlQualCard.BackgroundImage = $null; $b.Dispose() }
}

# --- Couleurs et noms des niveaux -------------------------------------------------------------------------------------
function Get-QualLevelColor([int]$lvl) {
    # Couleur d un niveau de score (barres, bord de la carte) : EXCELLENT Ok, BON Good, MOYEN WarnInk, MAUVAIS Danger (D17)
    switch ($lvl) { 0 { return $script:Theme.Ok } 1 { return $script:Theme.Good } 2 { return $script:Theme.WarnInk } default { return $script:Theme.Danger } }
}

function Get-QualInk([int]$lvl) {
    # Encre du texte d un niveau sur fond blanc ou teinte (contraste >= 4,5:1, WCAG 2.1 SC 1.4.3) : vert 20,90,45 (8,3:1),
    # vert-jaune 62,96,26 (7,3:1), Theme.WarnInk (5,3:1), rouge 140,30,25 (9,1:1)
    switch ($lvl) {
        0 { return [System.Drawing.Color]::FromArgb(20, 90, 45) }
        1 { return [System.Drawing.Color]::FromArgb(62, 96, 26) }
        2 { return $script:Theme.WarnInk }
        default { return [System.Drawing.Color]::FromArgb(140, 30, 25) }
    }
}

function Get-QualDimInk {
    # 12.8 (FIX3) : encre grise du texte secondaire pose sur une teinte (carte en cours ou perimee, tableau grise, lignes
    # paires 243,246,250) : 100,106,118, contraste >= 4,5:1 (4,78:1 sur la teinte « cur », 4,98:1 sur « skip », 5,01:1 sur
    # les lignes paires) ; Theme.Muted n y fait que 4,13:1 a 4,33:1 (il reste sur fond blanc : 4,69:1)
    return [System.Drawing.Color]::FromArgb(100, 106, 118)
}

function Get-AlName([int]$lvl) {
    # Nom d un niveau de score dans la langue courante (la table $script:AlNames est fixee au demarrage)
    switch ($lvl) { 0 { return 'EXCELLENT' } 1 { return (T 'BON') } 2 { return (T 'MOYEN') } default { return (T 'MAUVAIS') } }
}

# --- Pictogrammes -----------------------------------------------------------------------------------------------------
function Draw-QualityState($g, [string]$kind, [single]$ring) {
    # Etat sur la grille de 64 : h0 cercle Ok et coche, h1 triangle WarnInk et « ! », h2 cercle Danger et croix, h2a anneau
    # et croix Danger (piste absente), hq cercle Muted et « ? », pend anneau Muted (etape en attente), skip anneau Muted et
    # tiret (etape sans objet). Liseré blanc de $ring unites : lisible sur les cases colorees du tableau.
    $th = $script:Theme; $wh = [System.Drawing.Color]::White
    if ($kind -eq 'h1') {
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(32, 7)), (New-Object System.Drawing.PointF(59, 56)), (New-Object System.Drawing.PointF(5, 56))))
        $pr = New-Object System.Drawing.Pen($wh, [single](8 + 2 * $ring)); $pr.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pr, $p); $pr.Dispose()
        $pc = New-Object System.Drawing.Pen($th.WarnInk, [single]8); $pc.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pc, $p); $pc.Dispose()
        $g.FillPath((Get-QualBrush $th.WarnInk), $p); $p.Dispose()
        $rr = New-RoundRect 28.5 20 7 22 3.5; $g.FillPath((Get-QualBrush $wh), $rr); $rr.Dispose()
        $g.FillEllipse((Get-QualBrush $wh), [single]28.25, [single]45, [single]7.5, [single]7.5)
        return
    }
    $c = switch ($kind) { 'h0' { $th.Ok } 'hq' { $th.Muted } 'pend' { $th.Muted } 'skip' { $th.Muted } default { $th.Danger } }
    $g.FillEllipse((Get-QualBrush $wh), [single](4 - $ring), [single](4 - $ring), [single](56 + 2 * $ring), [single](56 + 2 * $ring))
    if (@('h2a', 'pend', 'skip') -contains $kind) {
        $pen = New-Object System.Drawing.Pen($c, [single]6)
        $g.DrawEllipse($pen, [single]7, [single]7, [single]50, [single]50); $pen.Dispose()
    } else { $g.FillEllipse((Get-QualBrush $c), [single]4, [single]4, [single]56, [single]56) }
    $sc = if (@('h2a') -contains $kind) { $c } else { $wh }
    $pen = New-Object System.Drawing.Pen($sc, [single]7)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    switch ($kind) {
        'h0' { $g.DrawLines($pen, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(18, 33)), (New-Object System.Drawing.PointF(28, 43)), (New-Object System.Drawing.PointF(46, 23)))) }
        'skip' { $pen.Color = $c; $g.DrawLine($pen, [single]21, [single]32, [single]43, [single]32) }
        'hq' {
            $f = New-Object System.Drawing.Font('Segoe UI Semibold', [single]40, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = [System.Drawing.StringAlignment]::Center; $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString('?', $f, (Get-QualBrush $wh), (New-Object System.Drawing.RectangleF(4, 6, 56, 56)), $sf)
            $f.Dispose(); $sf.Dispose()
        }
        'pend' { }
        default { $g.DrawLine($pen, [single]22, [single]22, [single]42, [single]42); $g.DrawLine($pen, [single]42, [single]22, [single]22, [single]42) }
    }
    $pen.Dispose()
}

function Draw-QualityBars16($g, [int]$filled, [System.Drawing.Color]$fill) {
    # Score a 16 px (A2 § 3.1) : 4 barres alignees sur les pixels, x = 0, 4, 8, 12, largeur 3, hauteurs 4, 7, 10, 13, base
    # a la ligne 14, $filled pleines dans $fill, les autres 205,212,224 ; anticrenelage coupe (bords nets). 12.8 (FIX3) :
    # liseré blanc de 1 px autour de chaque barre, a la place de la pastille blanche qui reduisait les barres a 2 px de
    # large et 9 px de haut : lisible sur les cases colorees du tableau (barre pleine de la couleur de la case)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $wh = Get-QualBrush ([System.Drawing.Color]::White)
    $empty = [System.Drawing.Color]::FromArgb(205, 212, 224)
    for ($i = 0; $i -lt 4; $i++) { $hh = 4 + 3 * $i; $g.FillRectangle($wh, [int](4 * $i - 1), [int](14 - $hh), 5, [int]($hh + 2)) }
    for ($i = 0; $i -lt 4; $i++) {
        $hh = 4 + 3 * $i
        $g.FillRectangle((Get-QualBrush $(if ($i -lt $filled) { $fill } else { $empty })), [int](4 * $i), [int](15 - $hh), 3, [int]$hh)
    }
}

function Draw-QualityBars48($g, [int]$filled, [System.Drawing.Color]$fill, [bool]$outline) {
    # Score sur la grille de 64 : pastille blanche en bas a droite (24,22 ; 40 x 40), 4 barres de 6 unites (hauteurs 8 a 29),
    # $filled pleines dans $fill ; $outline : barres en contour de $fill (mesure en cours)
    $rr = New-RoundRect 24 22 40 40 6
    $g.FillPath((Get-QualBrush ([System.Drawing.Color]::White)), $rr)
    $g.DrawPath((Get-QualPen ([System.Drawing.Color]::FromArgb(205, 212, 224)) 2), $rr); $rr.Dispose()
    $empty = [System.Drawing.Color]::FromArgb(215, 220, 229)
    for ($i = 0; $i -lt 4; $i++) {
        $hh = 8 + 7 * $i; $x = 27.5 + 9 * $i
        if ($outline) { $g.DrawRectangle((Get-QualPen $fill 2), [single]$x, [single](56 - $hh), [single]6, [single]$hh) }
        else { $g.FillRectangle((Get-QualBrush $(if ($i -lt $filled) { $fill } else { $empty })), [single]$x, [single](56 - $hh), [single]6, [single]$hh) }
    }
}

function New-QualityPicto([string]$kind, [int]$size, [string]$badge = '') {
    # Pictogramme de qualite (A2 § 3.1, D15) en GDI+, comme New-CleanPicto (aucune image externe, aucun Add-Type) :
    #  q0..q3 : score EXCELLENT, BON, MOYEN, MAUVAIS, barres de signal (4 a 1 pleine(s)) dans la couleur du niveau ;
    #  s0..s3 : resultat precedent ou perime (barres du niveau en gris) ; none : aucune mesure (barres vides) ;
    #  run : mesure en cours (horloge) ; bad : aucune piste lisible ; h0, h1, h2, h2a, hq, pend, skip : etats (Draw-QualityState).
    # 16 px : jeu de pixels propre (barres sans anticrenelage) ; 48 px : disquette du logo, pastille de barres, horloge ou
    # badge d etat $badge (h1, h2) en haut a droite ; autres tailles (20 px) : etats a l echelle de la grille de 64.
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $th = $script:Theme
        $lvl = if ($kind -match '^[qs]([0-3])$') { [int]$Matches[1] } else { -1 }
        if ($size -le 16) {
            if ($kind -match '^q[0-3]$') { Draw-QualityBars16 $g (4 - $lvl) (Get-QualLevelColor $lvl) }
            elseif ($kind -match '^s[0-3]$') { Draw-QualityBars16 $g (4 - $lvl) ([System.Drawing.Color]::FromArgb(150, 156, 168)) }
            elseif ($kind -eq 'none') { Draw-QualityBars16 $g 0 $th.Muted }
            elseif ($kind -eq 'run') {
                $pen = Get-QualPen $th.Accent 1.6
                $g.FillEllipse((Get-QualBrush ([System.Drawing.Color]::White)), [single]1.5, [single]1.5, [single]13, [single]13)
                $g.DrawEllipse($pen, [single]1.5, [single]1.5, [single]13, [single]13)
                $g.DrawLine($pen, [single]8, [single]8, [single]8, [single]4.2); $g.DrawLine($pen, [single]8, [single]8, [single]10.8, [single]8)
            } else {
                $g.ScaleTransform([single]($size / 64.0), [single]($size / 64.0))
                Draw-QualityState $g $(if ($kind -eq 'bad') { 'h2' } else { $kind }) ([single](64.0 / $size))
            }
            return $bmp
        }
        $g.ScaleTransform([single]($size / 64.0), [single]($size / 64.0))
        if ($size -lt 40 -or $kind -match '^h|^pend$|^skip$') { Draw-QualityState $g $kind ([single](64.0 / $size)); return $bmp }
        # 48 px : disquette « donnees » du logo (grisee hors resultat), pastille de barres, horloge ou badge d etat
        Draw-PictoFloppy $g 0 1 42 $false
        if ($kind -match '^s[0-3]$|^none$') { $g.FillRectangle((Get-QualBrush ([System.Drawing.Color]::FromArgb(160, 255, 255, 255))), [single]0, [single]0, [single]44, [single]46) }
        switch -regex ($kind) {
            '^q[0-3]$' { Draw-QualityBars48 $g (4 - $lvl) (Get-QualLevelColor $lvl) $false }
            '^s[0-3]$' { Draw-QualityBars48 $g (4 - $lvl) ([System.Drawing.Color]::FromArgb(160, 166, 178)) $false; Draw-PictoClock $g 52 12 10 $th.Muted }
            '^none$' { Draw-QualityBars48 $g 0 $th.Muted $false }
            '^run$' { Draw-QualityBars48 $g 0 $th.Accent $true; Draw-PictoClock $g 52 12 10 $th.Accent }
            '^bad$' {
                $rr = New-RoundRect 24 22 40 40 6; $g.FillPath((Get-QualBrush $th.Danger), $rr); $rr.Dispose()
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, [single]6)
                $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                $g.DrawLine($pen, [single]35, [single]33, [single]53, [single]51); $g.DrawLine($pen, [single]53, [single]33, [single]35, [single]51); $pen.Dispose()
            }
        }
        if ($badge -and $kind -match '^q') {
            $st = $g.Save()
            $g.TranslateTransform([single]40, [single]0); $g.ScaleTransform([single](24 / 64.0), [single](24 / 64.0))
            Draw-QualityState $g $badge ([single]8)
            $g.Restore($st)
        }
        return $bmp
    } finally { $g.Dispose() }
}

function New-QualityGreyBitmap($src) {
    # Copie grisee et attenuee d un pictogramme (tableau et carte hors resultat : D16, griser et marquer)
    $bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = [single]0.3; $cm.Matrix01 = [single]0.3; $cm.Matrix02 = [single]0.3
    $cm.Matrix10 = [single]0.59; $cm.Matrix11 = [single]0.59; $cm.Matrix12 = [single]0.59
    $cm.Matrix20 = [single]0.11; $cm.Matrix21 = [single]0.11; $cm.Matrix22 = [single]0.11
    $cm.Matrix33 = [single]0.55
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetColorMatrix($cm)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $ia.Dispose(); $g.Dispose()
    return $bmp
}

function Get-QualityIcon([string]$kind, [int]$size, [string]$badge = '', [switch]$Grey) {
    # Pictogramme en cache (cree une fois, libere par Clear-QualityGdi)
    $k = "i$kind|$size|$badge|$([bool]$Grey)"
    $o = $script:QualGdi[$k]
    if ($o) { return $o }
    if ($Grey) { $o = New-QualityGreyBitmap (Get-QualityIcon $kind $size $badge) } else { $o = New-QualityPicto $kind $size $badge }
    $script:QualGdi[$k] = $o
    return $o
}

# --- Etat de l affichage ($script:QualView) ---------------------------------------------------------------------------
# State : empty | run | result | stale ; Kind : measure (mesure, continue ou non) ou check (controle apres ecriture) ;
# Has : un resultat existe (Res) ; Reason : code de la raison (stop, error, gwerror, noscp, thresholds, written,
# checkabort, checknone) ; Pass : passe de la mesure continue ; Drive, Heads, Revs, NCyl : mesure en cours ; RunText : etape du
# controle en cours ; Res : dernier resultat (Kind, At, Score, Lvl, Count, Bad, Health, HealthText, ScoreText...).

function Set-QualityPending([string]$kind, $ctx = $null) {
    # Debut d une mesure ou d un controle apres ecriture : resultat precedent grise, marque « en cours », jamais efface
    $v = $script:QualView
    $v.State = 'run'; $v.Kind = $kind; $v.Reason = ''; $v.RunText = ''
    if ($kind -eq 'measure') {
        $v.Pass = $(if ($script:AlignLoop) { [int]$v.Pass + 1 } else { 0 })
        if ($ctx) { $v.Drive = [string]$ctx.Drive; $v.Heads = [string]$ctx.Heads; $v.Revs = [int]$ctx.Revs; $v.NCyl = [int]$ctx.NCyl }
    } else { $v.Pass = 0; $v.RunText = (T "Contrôle après écriture : en attente de la fin de l'écriture") }
    Update-QualityView
}

function Set-QualityRunText([string]$text) {
    # Etape du controle apres ecriture en cours (relecture, reecriture, remesure), sur la carte
    $v = $script:QualView
    if ($v.State -ne 'run' -or $v.Kind -ne 'check' -or -not $text -or $v.RunText -eq $text) { return }
    $v.RunText = $text
    Update-QualityView
}

function Set-QualityResult($res) {
    # Fin d une mesure (Invoke-AlignAnalysis) ou d un controle (Show-WriteCheckTable) : nouveau resultat affiche
    $v = $script:QualView
    if (-not $res.Kind) { $res.Kind = 'measure' }
    $res.At = Get-Date
    if ($res.Kind -eq 'measure' -and $v.State -eq 'run' -and $v.Kind -eq 'measure' -and $v.Drive) { $res.Ctx = @{ Drive = $v.Drive; Heads = $v.Heads; Revs = $v.Revs } }
    $v.Res = $res; $v.State = 'result'; $v.Has = $true; $v.At = $res.At; $v.Reason = ''; $v.Kind = $res.Kind; $v.RunText = ''
    Update-QualityView
}

function Set-QualityStale([string]$reason) {
    # Resultat affiche qui ne correspond plus a la disquette ou aux reglages (arret, erreur, seuils, ecriture) : grise et
    # marque « perime », avec la raison ; sans resultat, la carte reste vide avec la raison d un echec
    $v = $script:QualView
    if ($v.State -eq 'empty') { return }
    $v.Reason = $reason; $v.RunText = ''
    $v.State = $(if ($v.Has) { 'stale' } else { 'empty' })
    Update-QualityView
}

function Reset-QualityView {
    # Bouton Reinitialiser de l onglet : plus aucun resultat
    $v = $script:QualView
    $v.State = 'empty'; $v.Kind = ''; $v.Reason = ''; $v.At = $null; $v.Has = $false; $v.Pass = 0; $v.Res = $null; $v.RunText = ''
    Update-QualityView
}

function Set-QualityCheckState([int]$lvl, [string]$text, [string]$short, [int]$nWeak) {
    # Verdict du controle apres ecriture (Complete-WriteCheck, niveau 0, 2 ou 3) sur le resultat du controle
    $r = $script:QualView.Res
    if (-not $r -or $r.Kind -ne 'check') { return }
    $r.CheckLvl = $lvl; $r.Health = $(if ($lvl -le 0) { 0 } elseif ($lvl -le 2) { 1 } else { 2 }); $r.HealthText = $text; $r.HealthSub = $short; $r.Weak = $nWeak
    Update-QualityView
}

function Get-QualStaleText([string]$reason, [string]$at) {
    # Texte de la raison d un resultat perime ($at : heure du resultat) ou d une carte vide apres un echec
    switch ($reason) {
        'gwerror'    { return (T 'Mesure interrompue (erreur gw)') }
        'noscp'      { return (T 'Mesure impossible : fichier de lecture absent ou illisible') }
        'thresholds' { return (T 'Seuils de jitter modifiés : relancez la mesure') }
        'written'    { return (T 'Disquette écrite depuis la mesure') }
        'checkabort' { return (T 'Contrôle après écriture interrompu.') }
        'checknone'  { return (T 'Contrôle après écriture : aucune piste à relire.') }   # 12.8 (FIX-PISTES) : champ Pistes
        default      { if ($at) { return ((T 'Mesure interrompue : résultat de {0}') -f $at) } else { return '' } }
    }
}

function Get-QualStateTitle($r) {
    if ([int]$r.Health -lt 0) { return '' }
    if ($r.Kind -eq 'check') {
        if ([int]$r.CheckLvl -le 0) { return (T 'COPIE SAINE') }
        if ([int]$r.Weak -gt 0) { return ((T '{0} PISTE(S) FAIBLE(S)') -f "$($r.Weak)") }
        return (T 'Aucune piste analysable')
    }
    switch ([int]$r.Health) { 0 { return (T 'SUPPORT SAIN') } 1 { return (T 'SUPPORT À SURVEILLER') } default { return (T 'SUPPORT CRITIQUE') } }
}

function Get-QualityCardModel($v) {
    # Contenu de la carte (textes, couleurs, pictogrammes) pour l etat $v : fonction sans interface (niveau 2 du banc)
    $th = $script:Theme; $wh = [System.Drawing.Color]::White
    $edge = [System.Drawing.Color]::FromArgb(205, 212, 224)
    $m = @{ Back = $wh; Bar = $edge; Icon = 'none'; Badge = ''; GreyIcon = $false; Score = [string][char]0x2013; ScoreInk = $th.Muted
            Caption = (T 'score · plus bas = mieux'); CaptionInk = $th.Muted; Level = ''; LevelInk = $th.Muted; Line2 = ''; Line2Short = ''; Line2More = @()
            Line2Ink = $th.Muted; StateIcon = ''; State = ''; StateInk = $th.Muted; Sub = ''; SubShort = ''; SubInk = $th.Muted; Chip = ''; ChipBack = $th.Muted
            Tip = ''; Access = '' }
    $r = $v.Res
    $at = if ($r -and $r.At -is [datetime]) { $r.At.ToString('HH:mm') } else { '' }
    # 12.8 (FIX3) : etape d un controle apres ecriture en cours, forme courte sans le prefixe « Controle apres ecriture : »
    # (la pastille « CONTROLE EN COURS » le dit) ; infobulle : resultat precedent remplace a la fin du controle ; ligne 2
    # complete d un resultat avec des pistes illisibles (D15), quand la carte n en montre qu une forme courte
    $runShort = [string]$v.RunText -replace '^[^:]*:\s*', ''
    if ($runShort) { $runShort = $runShort.Substring(0, 1).ToUpper() + $runShort.Substring(1) }
    $prevTip = ''; $fullL2 = ''
    $chipRun = if ($v.Kind -eq 'check') { (T 'CONTRÔLE EN COURS') } elseif ($script:AlignLoop -and [int]$v.Pass -gt 0) { (T 'MESURE CONTINUE · PASSE {0}') -f "$($v.Pass)" } else { (T 'MESURE EN COURS') }
    $show = $null                       # resultat a afficher : $true en couleurs, $false grise
    switch ($v.State) {
        'run' {
            $m.Chip = $chipRun; $m.ChipBack = $th.Accent; $m.Bar = $th.Accent
            if ($v.Has -and $r) { $show = $false }
            else {
                $m.Back = [System.Drawing.Color]::FromArgb(234, 241, 251); $m.Icon = 'run'; $m.Score = [string][char]0x2026; $m.ScoreInk = $th.Accent
                $m.LevelInk = $th.Accent2; $m.Line2Ink = $th.Accent
                if ($v.Kind -eq 'check') { $m.Level = (T 'Contrôle après écriture en cours'); $m.Line2 = $v.RunText; $m.Line2Short = $runShort }
                else {
                    $m.Level = (T 'Mesure en cours')
                    $m.Line2 = (T 'Lecture de {0} cylindre(s), tête(s) {1}, {2} tour(s) (lecteur {3})') -f "$($v.NCyl)", "$($v.Heads)", "$($v.Revs)", "$($v.Drive)"
                }
            }
        }
        'stale' {
            $show = $false
            $m.Back = [System.Drawing.Color]::FromArgb(244, 245, 247); $m.Chip = (T 'PÉRIMÉ'); $m.ChipBack = $th.Muted; $m.Bar = $th.Muted
        }
        'result' { if ($r) { $show = $true } }
        default {
            $m.Level = (T 'Aucune mesure')
            $m.Line2 = Get-QualStaleText $v.Reason ''
            if (-not $m.Line2 -or @('stop', 'error', 'thresholds', 'written') -contains $v.Reason) { $m.Line2 = (T 'Insérez une disquette, puis cliquez sur « MESURER LA DISQUETTE ».') }
            $m.State = (T 'État du support : après la mesure')
        }
    }
    if ($null -ne $show -and $r) {
        $count = [int]$r.Count; $bad = [int]$r.Bad; $lvl = [int]$r.Lvl; $hl = [int]$r.Health
        $m.State = Get-QualStateTitle $r
        $m.StateIcon = $(if ($hl -ge 0) { "h$hl" } else { '' })
        if ($r.Kind -eq 'check') { $m.Sub = [string]$r.HealthSub; $m.SubShort = $m.Sub }
        else {
            $keys = if ($hl -eq 2) { @($r.CritKeys) } elseif ($hl -eq 1) { @($r.WatchKeys) } else { @() }
            $part = switch ($hl) {
                0 { (T '{0}/{1} pistes propres') -f "$($r.NTracks)", "$($r.NTracks)" }
                1 { (T '{0}/{1} piste(s) marginale(s) : {2}') -f "$($keys.Count)", "$($r.NTracks)", "$($keys -join ', ')" }
                default { (T '{0} piste(s) en erreur : {1}') -f "$($keys.Count)", "$($keys -join ', ')" }
            }
            $m.SubShort = $part + ' · ' + $at
            $m.Sub = if ($r.Ctx) { $part + ' · ' + ((T 'lecteur {0}, têtes {1}, {2} tours · {3}') -f "$($r.Ctx.Drive)", "$($r.Ctx.Heads)", "$($r.Ctx.Revs)", $at) } else { $m.SubShort }
        }
        if ($count -le 0) {
            $m.Icon = 'bad'; $m.Level = (T 'Aucune piste analysable'); $m.Line2 = (T 'Vérifiez la disquette, le lecteur et le format')
            $lvl = 3
        } else {
            $m.Score = "$($r.Score)"; $m.Level = Get-AlName $lvl
            $m.Icon = "q$lvl"
            if ($hl -ge 2 -or $bad -gt 0) { $m.Badge = 'h2' } elseif ($hl -eq 1) { $m.Badge = 'h1' }
            if ($r.Kind -eq 'check') {
                # 12.8 (FIX3) : formes courtes (ligne 2 de 272 a 283 px a la taille minimale de la fenetre) : sans le prefixe,
                # puis le nombre de pistes illisibles non comptees seul (D15)
                if ($bad -gt 0) {
                    $m.Line2 = (T 'Contrôle après écriture : sur {0} piste(s) lisible(s), {1} illisible(s) non comptée(s)') -f "$count", "$bad"
                    $m.Line2Short = (T 'sur {0} piste(s) lisible(s), {1} illisible(s) non comptée(s)') -f "$count", "$bad"
                    $m.Line2More = @((T '{0} piste(s) illisible(s) non comptée(s)') -f "$bad")
                } else { $m.Line2 = (T 'Contrôle après écriture : sur {0} piste(s) lisible(s)') -f "$count"; $m.Line2Short = $m.Line2 }
            } else {
                $p1 = @(); $p2 = @()
                if ($null -ne $r.Prev) {
                    if ([double]$r.Score -lt [double]$r.Prev - 2) { $p1 += ((T 'Mieux que la mesure précédente ({0})') -f "$($r.Prev)") }
                    elseif ([double]$r.Score -gt [double]$r.Prev + 2) { $p1 += ((T 'Moins bien que la mesure précédente ({0})') -f "$($r.Prev)") }
                    else { $p1 += (T 'Stable') }
                }
                $p2 += $(if ($null -ne $r.RefAvg) { (T 'meilleur {0} · réf. {1}') -f "$($r.Best)", "$($r.RefAvg)" } else { (T 'meilleur {0}') -f "$($r.Best)" })
                $p3 = @(); if ($bad -gt 0) { $p3 += ((T 'sur {0} piste(s) lisible(s), {1} illisible(s) non comptée(s)') -f "$count", "$bad") }
                $m.Line2 = @(@($p1) + @($p2) + @($p3)) -join ' · '
                # 12.8 (FIX3) : formes courtes, la phrase des pistes illisibles d abord (D15) : sans « meilleur / réf. », puis
                # cette phrase seule, puis le nombre de pistes illisibles non comptees seul
                $m.Line2Short = @(@($p3) + @($p1)) -join ' · '
                if ($bad -gt 0) { $m.Line2More = @($p3[0], ((T '{0} piste(s) illisible(s) non comptée(s)') -f "$bad")) }
            }
            if ($bad -gt 0) { $fullL2 = $m.Line2 }
        }
        if ($show) {
            $m.Bar = $(if ($count -le 0) { $th.Danger } else { Get-QualLevelColor $lvl })
            $m.ScoreInk = Get-QualInk $lvl; $m.LevelInk = Get-QualInk $lvl
            $m.StateInk = Get-QualInk $(if ($hl -le 0) { 0 } elseif ($hl -eq 1) { 2 } else { 3 })
        } else {
            # Resultat precedent (mesure en cours) ou perime : memes textes en gris, pictogrammes gris ; ligne 2 : la raison
            $m.GreyIcon = $true
            $m.Icon = $(if ($count -le 0) { 'bad' } else { "s$lvl" }); $m.Badge = ''; $m.Line2More = @()
            if ($v.State -eq 'stale') { $m.Line2 = Get-QualStaleText $v.Reason $at; $m.Line2Short = $m.Line2 }
            elseif ($v.Kind -eq 'check' -and $v.RunText) {
                # 12.8 (FIX3) : controle apres ecriture en cours : son etape (en attente de l ecriture, relecture, reecriture,
                # remesure) en Accent, comme pour un premier controle ; le resultat precedent grise est explique dans l infobulle
                $m.Line2 = [string]$v.RunText; $m.Line2Short = $runShort; $m.Line2Ink = $th.Accent
                $prevTip = (T 'Résultat précédent ({0}), remplacé à la fin du contrôle') -f $at
            } else {
                $m.Line2 = (T 'Résultat précédent ({0}), remplacé à la fin de la mesure') -f $at
                $m.Line2Short = (T 'Résultat précédent ({0}), remplacé à la fin') -f $at      # 12.8 (FIX3) : tient sur 272 px
            }
        }
    }
    if (-not $m.Line2Short) { $m.Line2Short = $m.Line2 }
    if (-not $m.SubShort) { $m.SubShort = $m.Sub }
    # 12.8 (FIX3) : texte gris pose sur une teinte (en cours, premiere mesure : « cur » 234,241,251 ; perime : « skip »
    # 244,245,247) : gris plus fonce (Get-QualDimInk), pour un contraste >= 4,5:1 ; sur fond blanc, Theme.Muted (4,69:1)
    if ($m.Back.ToArgb() -ne $wh.ToArgb()) {
        $dim = Get-QualDimInk
        foreach ($k in @('ScoreInk', 'CaptionInk', 'LevelInk', 'Line2Ink', 'StateInk', 'SubInk')) { if ($m[$k].ToArgb() -eq $th.Muted.ToArgb()) { $m[$k] = $dim } }
    }
    # Infobulle : etat d affichage, textes complets du resultat (listes de pistes), puis les deux definitions
    $tips = @()
    if ($m.Chip) { $tips += ($m.Chip + ' : ' + $m.Line2) } elseif ($v.State -eq 'empty' -and $m.Line2) { $tips += $m.Line2 }
    if ($prevTip) { $tips += $prevTip }
    if ($show -eq $true -and $fullL2) { $tips += $fullL2 }
    if ($r -and $null -ne $show) { if ($r.HealthText) { $tips += [string]$r.HealthText }; if ($r.ScoreText) { $tips += [string]$r.ScoreText } }
    $tips += ''
    $tips += (T "État du support : basé uniquement sur les erreurs, les trous de signal, la stabilité entre tours et le jitter.`nIndépendant du contenu : comparable d'une disquette à l'autre.")
    $tips += (T "Score de qualité de lecture (plus bas = mieux). Dépend du contenu : à comparer uniquement sur une même image`n(deux lecteurs, deux précompensations, deux réglages).")
    $m.Tip = ($tips -join "`n").Trim()
    $m.Access = @(@($m.Chip, "$($m.Score) $($m.Level)".Trim(), $m.State) | Where-Object { $_ -and $_ -ne [string][char]0x2013 }) -join ' ; '
    return $m
}

# --- Rendu ------------------------------------------------------------------------------------------------------------
function Update-QualityView {
    # Rendu de $script:QualView : carte de resultat, infobulle, tableau et barres (grises hors resultat, D16)
    $script:QualCard = Get-QualityCardModel $script:QualView
    # 12.8 (FIX3) : bandeau orange des zones instables de la derniere mesure (Set-UnstableBanner) grise comme la carte tant
    # que ce resultat n est pas le resultat courant (mesure en cours, perime) ; le guide d alignement, qui utilise la meme
    # ligne, garde ses couleurs
    if ($lblAlReco -and $script:UnstableBannerText -and $lblAlReco.Text -eq $script:UnstableBannerText) {
        $lblAlReco.ForeColor = $(if ($script:QualView.State -eq 'result') { [System.Drawing.Color]::DarkOrange } else { $script:Theme.Muted })
    }
    if (-not $pnlQualCard) { return }
    Render-QualityCard
    $tip.SetToolTip($pnlQualCard, $script:QualCard.Tip)
    $pnlQualCard.AccessibleName = $script:QualCard.Access
    if ($lvAl) { $lvAl.Invalidate() }
    if ($pnlAlBars) { $pnlAlBars.Invalidate() }
}

function Get-QualFitText([string]$long, [string]$short, $font, [int]$w, [string[]]$more = @()) {
    # Texte long s il tient sur $w px, sinon sa forme courte (sans les details repris dans l infobulle) ; 12.8 (FIX3) : puis
    # les formes plus courtes $more, dans l ordre ; aucune ne tient : la derniere (coupee par des points de suspension)
    if (-not $long) { return $short }
    $tf = [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
    $sz = New-Object System.Drawing.Size(32000, 100)
    $cands = @(@($long, $short) + @($more) | Where-Object { $_ })
    foreach ($s in $cands) { if ([System.Windows.Forms.TextRenderer]::MeasureText($s, $font, $sz, $tf).Width -le $w) { return $s } }
    return $cands[-1]
}

function Get-QualityCardLayout([int]$w, [int]$lx, [bool]$hasState, [bool]$hasSub = $true) {
    # Zones de la carte de $w px de large (768 au minimum de la fenetre) : pictogramme et score a gauche, niveau et ligne 2
    # a partir de $lx, separateur et zone d etat a droite ; sans etat a afficher (premiere mesure en cours), pas de
    # separateur : la ligne 2 prend toute la largeur ; etat sans detail (carte vide) : separateur court, ligne 2 aussi
    if (-not $hasState) { return @{ Lx = $lx; Sep = -1; SepBottom = 0; L2W = $w - $lx - 10; StX = $w; StW = 0 } }
    $sep = [int]($lx + ($w - $lx) * 0.5)
    if (-not $hasSub) { return @{ Lx = $lx; Sep = $sep; SepBottom = 28; L2W = $w - $lx - 10; StX = $sep + 12; StW = $w - $sep - 22 } }
    return @{ Lx = $lx; Sep = $sep; SepBottom = 50; L2W = $sep - $lx - 10; StX = $sep + 12; StW = $w - $sep - 22 }
}

function Render-QualityCard {
    # Carte (A2 § 3.2) dessinee dans un bitmap, fond de pnlQualCard : barre de couleur a gauche, pictogramme 48 px, score,
    # legende, niveau, ligne 2, separateur, etat (pictogramme 20 px, titre, detail), pastille d etat d affichage
    $m = $script:QualCard
    if (-not $m -or -not $pnlQualCard) { return }
    $w = [math]::Max(200, [int]$pnlQualCard.ClientSize.Width); $h = [math]::Max(40, [int]$pnlQualCard.ClientSize.Height)
    $fScore = Get-QualFont 'Segoe UI Semibold' 22; $fSmall = Get-QualFont 'Segoe UI' 8.25; $fLevel = Get-QualFont 'Segoe UI Semibold' 12
    $fState = Get-QualFont 'Segoe UI Semibold' 10.5; $fChip = Get-QualFont 'Segoe UI Semibold' 8.25
    $one = [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
    # Colonne du niveau apres la legende du score (« score · plus bas = mieux », plus longue en francais)
    $capW = [System.Windows.Forms.TextRenderer]::MeasureText($m.Caption, $fSmall, (New-Object System.Drawing.Size(32000, 100)), $one).Width
    $lay = Get-QualityCardLayout $w ([math]::Max(180, 66 + $capW + 8)) ([bool]($m.State -or $m.StateIcon)) ([bool]$m.Sub)
    # Bitmap sans canal alpha : le texte GDI (TextRenderer) y est opaque
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear($m.Back)
        $edge = [System.Drawing.Color]::FromArgb(205, 212, 224)
        $g.DrawRectangle((Get-QualPen $edge 1), 0, 0, ($w - 1), ($h - 1))
        $g.FillRectangle((Get-QualBrush $m.Bar), 0, 0, 5, $h)
        $tf = $one -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis
        if ($m.Icon) { $g.DrawImage((Get-QualityIcon $m.Icon 48 $m.Badge -Grey:([bool]$m.GreyIcon)), 12, 5, 48, 48) }
        [System.Windows.Forms.TextRenderer]::DrawText($g, $m.Score, $fScore, (New-Object System.Drawing.Rectangle(64, 0, ($lay.Lx - 68), 40)), $m.ScoreInk, $m.Back, $tf)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $m.Caption, $fSmall, (New-Object System.Drawing.Rectangle(66, 38, ($lay.Lx - 70), 17)), $m.CaptionInk, $m.Back, $tf)
        # Pastille « en cours » / « perime » : au bout de la ligne du niveau, avant le separateur ; en haut a droite de la carte
        # sans zone d etat
        $right = $(if ($lay.Sep -gt 0) { $lay.Sep - 10 } else { $w - 8 })
        $lvW = $right - $lay.Lx
        if ($m.Chip) {
            $cw = [System.Windows.Forms.TextRenderer]::MeasureText($m.Chip, $fChip).Width + 14
            $chipX = $right - $cw
            $rr = New-RoundRect $chipX 8 $cw 18 9; $g.FillPath((Get-QualBrush $m.ChipBack), $rr); $rr.Dispose()
            [System.Windows.Forms.TextRenderer]::DrawText($g, $m.Chip, $fChip, (New-Object System.Drawing.Rectangle($chipX, 8, $cw, 18)), [System.Drawing.Color]::White, $m.ChipBack,
                ($one -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::HorizontalCenter))
            $lvW = $chipX - 6 - $lay.Lx
        }
        [System.Windows.Forms.TextRenderer]::DrawText($g, $m.Level, $fLevel, (New-Object System.Drawing.Rectangle($lay.Lx, 4, [math]::Max(10, $lvW), 26)), $m.LevelInk, $m.Back, $tf)
        $l2 = Get-QualFitText $m.Line2 $m.Line2Short $fSmall $lay.L2W $m.Line2More
        [System.Windows.Forms.TextRenderer]::DrawText($g, $l2, $fSmall, (New-Object System.Drawing.Rectangle($lay.Lx, 32, $lay.L2W, 20)), $m.Line2Ink, $m.Back, $tf)
        if ($lay.Sep -gt 0) {
            $g.DrawLine((Get-QualPen $edge 1), $lay.Sep, 8, $lay.Sep, [math]::Min(($h - 8), $lay.SepBottom))
            $tx = $lay.StX
            if ($m.StateIcon) { $g.DrawImage((Get-QualityIcon $m.StateIcon 20 -Grey:([bool]$m.GreyIcon)), $lay.StX, 8, 20, 20); $tx = $lay.StX + 26 }
            [System.Windows.Forms.TextRenderer]::DrawText($g, $m.State, $fState, (New-Object System.Drawing.Rectangle($tx, 6, [math]::Max(10, $w - 10 - $tx), 24)), $m.StateInk, $m.Back, $tf)
            $sub = Get-QualFitText $m.Sub $m.SubShort $fSmall $lay.StW
            [System.Windows.Forms.TextRenderer]::DrawText($g, $sub, $fSmall, (New-Object System.Drawing.Rectangle($lay.StX, 32, $lay.StW, 20)), $m.SubInk, $m.Back, $tf)
        }
    } finally { $g.Dispose() }
    $old = $pnlQualCard.BackgroundImage
    $pnlQualCard.BackgroundImage = $bmp
    if ($old) { $old.Dispose() }
}

function Draw-AlSubItem($e, $font) {
    # Case du tableau de l onglet Qualite (DrawSubItem de $lvAl ; fonction pour la tester sans afficher la fenetre : une
    # ListView hors ecran ne recoit jamais ce dessin). Fond de la case (couleur du niveau) ou de la ligne ; gris tant que
    # le resultat affiche n est pas le resultat courant (mesure en cours, perime : D16) ; icone de 16 px (D15) devant
    # l etat (colonne 1) et devant le score (colonne 6), d apres Item.Tag (New-AlignRow) ; pinceaux, stylo et formats en
    # cache (plus d allocation a chaque case)
    $row = $e.Item.Index
    $grey = ($script:QualView.State -ne 'result')
    $baseBg = if ($row % 2) { [System.Drawing.Color]::FromArgb(243, 246, 250) } else { [System.Drawing.Color]::White }
    $bg = if (-not $grey -and $e.SubItem.BackColor -ne [System.Drawing.Color]::Empty -and $e.SubItem.BackColor.ToArgb() -ne [System.Drawing.SystemColors]::Window.ToArgb() -and $e.SubItem.BackColor.ToArgb() -ne 0) { $e.SubItem.BackColor } else { $baseBg }
    $e.Graphics.FillRectangle((Get-QualBrush $bg), $e.Bounds)
    $e.Graphics.DrawLine((Get-QualPen ([System.Drawing.Color]::FromArgb(225, 229, 235)) 1), $e.Bounds.Right - 1, $e.Bounds.Top, $e.Bounds.Right - 1, $e.Bounds.Bottom)
    $fg = if ($grey) { Get-QualDimInk } elseif ($e.SubItem.ForeColor -ne [System.Drawing.Color]::Empty) { $e.SubItem.ForeColor } else { [System.Drawing.Color]::FromArgb(32, 36, 44) }
    $fnt = if ($e.SubItem.Font) { $e.SubItem.Font } else { $font }
    $r = [System.Drawing.RectangleF]::new($e.Bounds.X + 4, $e.Bounds.Y, $e.Bounds.Width - 8, $e.Bounds.Height)
    $ik = ''
    if ($e.Item.Tag -is [hashtable]) { if ($e.ColumnIndex -eq 1) { $ik = [string]$e.Item.Tag.State } elseif ($e.ColumnIndex -eq 6) { $ik = [string]$e.Item.Tag.Score } }
    if ($ik) {
        $e.Graphics.DrawImage((Get-QualityIcon $ik 16 -Grey:$grey), ($e.Bounds.X + 3), ($e.Bounds.Y + [int][math]::Floor(($e.Bounds.Height - 16) / 2)), 16, 16)
        $r = [System.Drawing.RectangleF]::new($e.Bounds.X + 22, $e.Bounds.Y, [math]::Max(1, $e.Bounds.Width - 26), $e.Bounds.Height)
    }
    $e.Graphics.DrawString($e.SubItem.Text, $fnt, (Get-QualBrush $fg), $r, (Get-QualSf $(if ($e.ColumnIndex -eq 0) { 'near' } else { 'center' })))
}

# --- Icones d etat hors de l onglet Qualite : onglet Ecriture, etapes et verdict de la restauration --------------------
function Set-WCalVerdict([string]$text, [string]$kind) {
    # Verdict du controle apres ecriture dans le libelle de l onglet Ecriture : icone d etat 16 px a gauche (h0, h1, h2) et
    # encre de l etat ; retires des que le libelle prend un autre texte (TextChanged de $lblWCal : Clear-WCalVerdict)
    $script:WCalIcon = @{ Kind = $kind; Text = $text }
    $lblWCal.Padding = New-Object System.Windows.Forms.Padding(20, 0, 0, 0)
    $lblWCal.ForeColor = Get-QualInk $(switch ($kind) { 'h0' { 0 } 'h1' { 2 } default { 3 } })
    $lblWCal.Text = $text; $lblWCal.Visible = $true
    $lblWCal.Invalidate()
}

function Clear-WCalVerdict {
    if (-not $script:WCalIcon) { return }
    $script:WCalIcon = $null
    $lblWCal.Padding = New-Object System.Windows.Forms.Padding(0); $lblWCal.ForeColor = [System.Drawing.Color]::DimGray
}

function Hide-WCalVerdict {
    # 12.8 (FIX3) : disquette ecrite ou effacee sans controle apres ecriture (Start-Gw), ou prechauffage d une ecriture
    # (Start-WriteWarmup, qui retablit ensuite le libelle) : le verdict affiche du controle precedent ne la decrit plus ;
    # libelle masque, icone et encre retirees. Sans effet sans verdict affiche (calibration : le libelle a deja change)
    if (-not $script:WCalIcon) { return }
    $lblWCal.Visible = $false
    Clear-WCalVerdict
}

function Draw-WCalIcon($l, $e) {
    if (-not $script:WCalIcon -or $l.Text -ne $script:WCalIcon.Text) { return }
    $e.Graphics.DrawImage((Get-QualityIcon $script:WCalIcon.Kind 16), 1, [int][math]::Max(0, [math]::Floor(($l.Height - 16) / 2)), 16, 16)
}

function Draw-RsStepLabel($l, $e) {
    # Etape de la restauration : icone d etat 16 px (D15, a la place des glyphes), puis le texte sans son glyphe, dans sa
    # couleur, aussi quand Set-Busy desactive les onglets. Le texte du libelle garde son glyphe (infobulle, fins de test).
    $g = $e.Graphics
    $g.FillRectangle((Get-QualBrush $l.BackColor), $l.ClientRectangle)
    $kind = switch ([string]$l.Tag) { 'run' { 'run' } 'ok' { 'h0' } 'fail' { 'h2' } 'warn' { 'h1' } 'skip' { 'skip' } default { 'pend' } }
    $g.DrawImage((Get-QualityIcon $kind 16), 0, [int][math]::Max(0, [math]::Floor(($l.Height - 16) / 2)), 16, 16)
    $txt = [string]$l.Text -replace '^\S+\s+', ''
    $tf = [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis
    [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, $l.Font, (New-Object System.Drawing.Rectangle(21, 0, [math]::Max(1, $l.Width - 21), $l.Height)), $l.ForeColor, $tf)
}

function Draw-RsResultIcon($e) {
    # Verdict de la restauration : icone d etat 48 px dans la marge gauche (RESTAUREE h0, avec reserve h1, ECHOUEE h2)
    if ($script:RsResultIcon) { $e.Graphics.DrawImage((Get-QualityIcon $script:RsResultIcon 48), 8, 8, 48, 48) }
}
