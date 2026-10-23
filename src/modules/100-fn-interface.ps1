# ============================== FONCTIONS : INTERFACE COMMUNE ==================

function Set-Cue($tb, [string]$text) {
    $script:CueText[$tb] = $text
    if ($script:CueOk -and $tb.IsHandleCreated) { [void][GwUi.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) }
    $tb.Add_HandleCreated({ if ($script:CueOk -and $script:CueText.ContainsKey($this)) { [void][GwUi.Native]::SendMessage($this.Handle, 0x1501, [IntPtr]1, [string]$script:CueText[$this]) } })
}
function Apply-Cues {
    if (-not $script:CueOk) { return }
    foreach ($tb in @($script:CueText.Keys)) { if ($tb.IsHandleCreated) { [void][GwUi.Native]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, [string]$script:CueText[$tb]) } }
}

function Open-Help([string]$page) {
    $url = $script:WikiBase + $(if ($page) { [System.Uri]::EscapeDataString($page) } else { '' })
    try { Start-Process $url } catch { Append-Log ((T "Aide en ligne : impossible d'ouvrir {0} ({1})") -f "$url", "$($_.Exception.Message)") }
}
function Open-HelpForTab {
    $p = if ($tabs.SelectedTab -and $tabs.SelectedTab.Tag) { [string]$tabs.SelectedTab.Tag } else { 'Home' }
    Open-Help $p
}

function New-GlyphBitmap([string]$name, [int]$size, [System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush($color)
    $drawn = $false
    if ($script:IconFont -and $script:Glyph.ContainsKey($name)) {
        try {
            $fam  = New-Object System.Drawing.FontFamily($script:IconFont)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddString([string][char]$script:Glyph[$name], $fam, 0, [single]100, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericTypographic)
            $b = $path.GetBounds()
            if ($b.Width -gt 0 -and $b.Height -gt 0) {
                # Mise a l'echelle sur la boite reelle du trace, puis centrage sur CETTE boite
                # (et non sur la bounding box typographique) : sinon l'espace reserve aux jambages
                # pousse le glyphe visible vers le haut et il parait decale vers le bas dans le bouton.
                $box = [single]($size - 2)
                $sc = [math]::Min($box / $b.Width, $box / $b.Height)
                $offX = [single](($size - $b.Width * $sc) / 2)
                $offY = [single](($size - $b.Height * $sc) / 2)
                $m = New-Object System.Drawing.Drawing2D.Matrix
                $m.Translate($offX, $offY)
                $m.Scale([single]$sc, [single]$sc)
                $m.Translate([single](-$b.X), [single](-$b.Y))
                $path.Transform($m)
                $g.FillPath($brush, $path); $drawn = $true
            }
            $path.Dispose()
        } catch { }
    }
    if (-not $drawn) { $g.FillEllipse($brush, [int]($size * 0.3), [int]($size * 0.3), [int]($size * 0.4), [int]($size * 0.4)) }
    $brush.Dispose(); $g.Dispose()
    return $bmp
}

# Bitmap d'icone decale d'un pixel vers le haut pour compenser le centrage vertical des boutons WinForms.
function New-ButtonIcon([string]$glyph, [int]$size, [System.Drawing.Color]$color) {
    $src = New-GlyphBitmap $glyph $size $color
    $dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.DrawImage($src, 0, -1, $size, $size)
    $g.Dispose(); $src.Dispose()
    return $dst
}

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}

# Logo original : disquette 3,5" stylisee portant un signal de flux magnetique
function New-LogoBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $k = $size / 64.0
    function P([double]$x, [double]$y) { New-Object System.Drawing.PointF([single]($x * $k), [single]($y * $k)) }
    # corps avec coin coupe
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddPolygon([System.Drawing.PointF[]]@((P 5 4), (P 53 4), (P 60 11), (P 60 58), (P 57 61), (P 8 61), (P 5 58)))
    $g.FillPath((New-Object System.Drawing.SolidBrush($script:Theme.Floppy)), $body)
    # volet metallique et sa fenetre
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 212, 222))), (New-RoundRect (17*$k) (4*$k) (30*$k) (20*$k) (2*$k)))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($script:Theme.Floppy)), [single](36*$k), [single](8*$k), [single](7*$k), [single](12*$k))
    # etiquette
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 249, 252))), (New-RoundRect (11*$k) (31*$k) (42*$k) (26*$k) (2.5*$k)))
    # signal de flux : train d'impulsions MFM
    $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]([math]::Max(1.2, 2.6 * $k)))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $xs = @(14, 18, 18, 22, 22, 28, 28, 31, 31, 37, 37, 41, 41, 45, 45, 50)
    $ys = @(48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39, 48, 48, 39, 39)
    $pts = for ($i = 0; $i -lt $xs.Count; $i++) { P $xs[$i] $ys[$i] }
    $g.DrawLines($pen, [System.Drawing.PointF[]]$pts)
    # trou de protection en ecriture
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 28, 44))), [single](8*$k), [single](52*$k), [single](4*$k), [single](4*$k))
    $g.Dispose()
    return $bmp
}

function Set-Btn($btn, [string]$glyph, [string]$style = 'normal', [switch]$IconOnly, $IconColor = $null) {
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.UseVisualStyleBackColor = $false
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Font = $script:BtnFont
    $icColor = $null
    if ($IconOnly) { $style = 'icon' }
    switch ($style) {
        'primary' {
            $btn.BackColor = $script:Theme.Accent; $btn.ForeColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderSize = 0
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(52, 118, 196)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(28, 82, 150)
            $btn.Font = $script:BtnFontBold; $icColor = [System.Drawing.Color]::White
        }
        'danger' {
            $btn.BackColor = $script:Theme.Danger; $btn.ForeColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderSize = 0
            # 12.8 (FIX5) : survol 204,66,58 (texte blanc a 4,76:1), un peu plus clair que le repos comme le style principal
            # (12.7 : 216,80,72, 4,07:1, sous 4,5:1)
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(204, 66, 58)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(170, 44, 38)
            $btn.Font = $script:BtnFontBold; $icColor = [System.Drawing.Color]::White
        }
        'icon' {
            $btn.BackColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 204, 216)
            $btn.FlatAppearance.MouseOverBackColor = $script:BtnHoverNormal
            $icColor = $script:Theme.Accent
        }
        default {
            $btn.BackColor = [System.Drawing.Color]::White; $btn.ForeColor = [System.Drawing.Color]::FromArgb(40, 46, 58)
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 204, 216)
            $btn.FlatAppearance.MouseOverBackColor = $script:BtnHoverNormal
            $icColor = $script:Theme.Accent
        }
    }
    if ($IconColor) { $icColor = $IconColor }
    if ($glyph) { $btn.Image = New-ButtonIcon $glyph 16 $icColor } else { $btn.Image = $null }
    if ($style -eq 'icon') {
        $tipText = $btn.Text; $btn.Text = ''; $btn.ImageAlign = 'MiddleCenter'
        if ($tipText -and $tipText -ne '...') { $tip.SetToolTip($btn, $tipText) }
    } else {
        $btn.ImageAlign = 'MiddleLeft'; $btn.TextAlign = 'MiddleCenter'; $btn.TextImageRelation = 'ImageBeforeText'
        $btn.Padding = New-Object System.Windows.Forms.Padding(6, 0, 10, 0)
    }
}

function New-TabPage($text) {
    $tp = New-Object System.Windows.Forms.TabPage
    $tp.Text = $text
    $tp.Size = New-Object System.Drawing.Size($script:PageW, $script:PageH)
    $tp.UseVisualStyleBackColor = $false
    $tp.BackColor = $script:Theme.Page
    return $tp
}

function New-Label($text, $loc, $anchor) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = $loc; $l.AutoSize = $true
    if ($anchor) { $l.Anchor = $anchor }
    return $l
}

function Render-Banner {
    $w = [math]::Max(1, $pnlTop.ClientSize.Width); $h = [math]::Max(1, $pnlTop.ClientSize.Height)
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $script:Theme.Accent2, $script:Theme.Accent, [single]0)
    $g.FillRectangle($lg, $rect)
    # motif discret : pistes concentriques
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(22, 255, 255, 255), 1)
    for ($r = 30; $r -lt 260; $r += 14) { $g.DrawEllipse($pen, [single]($w - 160 - $r), [single]($h / 2 - $r), [single](2 * $r), [single](2 * $r)) }
    $g.DrawImage($script:LogoBig, 12, [int](($h - 48) / 2))
    $fTitle = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    $fSub   = New-Object System.Drawing.Font('Segoe UI', 9)
    $g.DrawString('Greaseweazle Studio', $fTitle, [System.Drawing.Brushes]::White, 68, 7)
    $g.DrawString((T 'Préservation, écriture et contrôle de disquettes'), $fSub, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(205, 220, 240))), 70, 37)
    $g.Dispose()
    $old = $pnlTop.BackgroundImage
    $pnlTop.BackgroundImage = $bmp
    if ($old) { $old.Dispose() }
}

function New-BannerLabel($text, $loc) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = $loc; $l.AutoSize = $true; $l.Anchor = 'Top,Right'
    $l.BackColor = [System.Drawing.Color]::Transparent; $l.ForeColor = [System.Drawing.Color]::White
    return $l
}

function New-Group($text, $loc, $size) {
    $g = New-Object System.Windows.Forms.GroupBox
    $g.Text = $text; $g.Location = $loc; $g.Size = $size; $g.Anchor = 'Top,Left,Right'
    return $g
}

function New-ToolButton($text, $loc, $onClick) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = $loc; $b.Size = '220,34'; $b.TextAlign = 'MiddleLeft'
    $b.Add_Click($onClick)
    return $b
}

function Get-HomeCard($ctrl) {
    # Carte (Panel) d un controle de la carte
    $c = $ctrl
    while ($c -and -not ($c -is [System.Windows.Forms.Panel] -and $c.Name -eq 'HomeCard')) { $c = $c.Parent }
    return $c
}

function New-HomeCard([string]$glyph, [string]$title, [string]$desc, [string]$loc, [scriptblock]$action) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Name = 'HomeCard'; $p.Location = $loc; $p.Size = '373,84'; $p.BackColor = [System.Drawing.Color]::White
    $p.Tag = $action
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Location = '0,0'; $bar.Size = '5,84'; $bar.BackColor = $script:Theme.Accent
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image = New-GlyphBitmap $glyph 28 $script:Theme.Accent; $pic.Location = '16,26'; $pic.Size = '32,32'; $pic.SizeMode = 'CenterImage'
    $t = New-Object System.Windows.Forms.Label
    $t.Text = $title; $t.Location = '58,10'; $t.Size = '306,22'
    $t.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5); $t.ForeColor = $script:Theme.Accent2
    $d = New-Object System.Windows.Forms.Label
    $d.Text = $desc; $d.Location = '58,34'; $d.Size = '306,44'; $d.ForeColor = $script:Theme.Muted
    $p.Controls.AddRange(@($bar, $pic, $t, $d))
    foreach ($c in @($p, $bar, $pic, $t, $d)) {
        $c.Cursor = [System.Windows.Forms.Cursors]::Hand
        # 12.7 : ouvrir une carte efface le bilan de la zone de progression
        $c.Add_Click({ $card = Get-HomeCard $this; if ($card -and $card.Tag) { Clear-HomeProgress; & $card.Tag } })
        $c.Add_MouseEnter({ $card = Get-HomeCard $this; if ($card) { $card.BackColor = [System.Drawing.Color]::FromArgb(234, 241, 251) } })
        $c.Add_MouseLeave({
            $card = Get-HomeCard $this
            if ($card -and -not $card.ClientRectangle.Contains($card.PointToClient([System.Windows.Forms.Cursor]::Position))) { $card.BackColor = [System.Drawing.Color]::White }
        })
    }
    $p.Add_Paint({
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205, 212, 224))
        $_.Graphics.DrawRectangle($pen, 0, 0, $this.Width - 1, $this.Height - 1); $pen.Dispose()
    })
    return $p
}

function Update-TabSet {
    $want = if ($chkExpert.Checked) { $script:AllTabs } else { $script:NoviceTabs }
    $sel = $tabs.SelectedTab
    $tabs.SuspendLayout()
    $tabs.TabPages.Clear()
    $tabs.TabPages.AddRange([System.Windows.Forms.TabPage[]]$want)
    if ($sel -and $want -contains $sel) { $tabs.SelectedTab = $sel }
    $tabs.ResumeLayout()
}
function Show-Tab($page) {
    # Onglet technique masque (mode expert decoche) : le mode expert est active pour l afficher
    if (-not $tabs.TabPages.Contains($page)) { $chkExpert.Checked = $true }
    if ($tabs.TabPages.Contains($page)) { $tabs.SelectedTab = $page }
}

function New-BarButton($text, $width) {
    $b = New-Object System.Windows.Forms.Button
    # 12.8 (lot 5) : 34 px (deux hauteurs de bouton, 34 et 40 px), dans la barre de 44 px (marges 4 et 2)
    $b.Text = $text; $b.Size = New-Object System.Drawing.Size($width, 34); $b.Margin = New-Object System.Windows.Forms.Padding(0,0,8,0)
    return $b
}

function Set-LogVisible([bool]$visible) {
    $split.Panel2Collapsed = -not $visible
    $btnLogToggle.Text = if ($visible) { (T 'Masquer journal') } else { (T 'Afficher journal') }
}

# --- Largeurs ajustees au texte (police, langue) : plus de libelles tronques --------
function Fit-ControlText($parent) {
    foreach ($c in @($parent.Controls)) {
        if ($c -is [System.Windows.Forms.CheckBox] -or $c -is [System.Windows.Forms.RadioButton]) {
            if ($c.Text) { $c.AutoSize = $true }
        } elseif ($c -is [System.Windows.Forms.Button] -and $c.Text -and $c.Text -ne '...') {
            $extra = if ($c.Image) { 46 } else { 24 }
            $need = [System.Windows.Forms.TextRenderer]::MeasureText($c.Text, $c.Font).Width + $extra
            if ($c.Width -lt $need) {
                $delta = $need - $c.Width
                $right = [bool]($c.Anchor -band [System.Windows.Forms.AnchorStyles]::Right)
                $left  = [bool]($c.Anchor -band [System.Windows.Forms.AnchorStyles]::Left)
                if ($right -and -not $left) { $c.Left -= $delta }
                $c.Width = $need
            }
        }
        if ($c.Controls.Count -gt 0) { Fit-ControlText $c }
    }
}

# --- Fenetre de confirmation commune (12.8, D3) : frmConfirm --------------------------
function New-ConfirmPicto([string]$kind) {
    # Pictogramme 120 x 84 du bandeau de frmConfirm (affiche en 100 x 70), dessine en GDI+ comme les vignettes du
    # nettoyage : warn (triangle d avertissement), erase (disquette de donnees barree d une croix), data (disquette de
    # donnees inseree dans le lecteur) ; tout autre nom : vignette du nettoyage (New-CleanPicto : forbid, insert...)
    if (@('warn', 'erase', 'data') -notcontains $kind) { return (New-CleanPicto $kind) }
    $bmp = New-Object System.Drawing.Bitmap(120, 84, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    switch ($kind) {
        'warn' {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(60, 5)), (New-Object System.Drawing.PointF(106, 79)), (New-Object System.Drawing.PointF(14, 79))))
            $b = New-Object System.Drawing.SolidBrush($script:Theme.Warn); $g.FillPath($b, $p); $b.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 92, 10), [single]3)
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round; $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
            $bw = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $rr = New-RoundRect 55 28 10 32 4; $g.FillPath($bw, $rr); $rr.Dispose()
            $g.FillEllipse($bw, [single]54.5, [single]64, [single]11, [single]11); $bw.Dispose()
        }
        'erase' {
            Draw-PictoFloppy $g 24 2 72 $false
            $pen = New-Object System.Drawing.Pen($script:Theme.Danger, [single]8)
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawLine($pen, [single]32, [single]12, [single]88, [single]72); $g.DrawLine($pen, [single]88, [single]12, [single]32, [single]72)
            $pen.Dispose()
        }
        'data' {
            Draw-PictoFloppy $g 38 0 44 $false $true
            Draw-PictoDrive $g $false
            Draw-PictoArrow $g $script:Theme.Accent 98 10 98 50
        }
    }
    $g.Dispose()
    return $bmp
}

function Set-ConfirmGo([bool]$on) {
    # Bouton principal de frmConfirm : bleu et actif seulement case cochee (comme Set-CleanGo) ; style refait, et ancienne
    # icone liberee, seulement quand il change
    $s = $script:ConfirmDlg
    if (-not $s) { return }
    $b = $s.Go; $b.Enabled = $on
    $st = if ($on) { 'primary' } else { 'normal' }
    if ($s.GoStyle -ne $st) { $s.GoStyle = $st; $old = $b.Image; Set-Btn $b $s.Glyph $st; if ($old) { $old.Dispose() } }
}

function Get-ConfirmShort([string]$heading, [string]$text, [int]$max = 100) {
    # 12.8 : question de frmConfirm en court pour le journal (Show-AppConfirm) : titre du bandeau, sinon premiere phrase du
    # texte ; sur une ligne, $max caracteres au plus (coupe au dernier espace, points de suspension)
    $q = ("$heading" -replace '\s+', ' ').Trim()
    if (-not $q) {
        $t = ("$text" -replace '\s+', ' ').Trim()
        $m = [regex]::Match($t, '^.+?[.!?](?=\s|$)')
        $q = if ($m.Success) { $m.Value } else { $t }
    }
    if ($q.Length -gt $max) {
        $cut = $q.Substring(0, $max - 1); $sp = $cut.LastIndexOf(' ')
        if ($sp -gt $max / 2) { $cut = $cut.Substring(0, $sp) }
        $q = $cut.TrimEnd(' ', ',', ';', ':') + [char]0x2026
    }
    return $q
}

function Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) {
    # 12.8 (S3) : AltText : second bouton d action (btnConfirmAlt), a gauche du bouton principal, soumis a la meme case ;
    # Combo = @{ Label ; Items ; Text ; Tip ; Map } : liste modifiable sous la case (cmbConfirmCombo, marque de la disquette).
    # Reponse dans $script:ConfirmChoice ('go', 'alt', 'close') et texte de la liste dans $script:ConfirmComboText ; la
    # fonction renvoie toujours $true pour le seul bouton principal
    # Confirmation d une action qui engage une disquette ou le materiel (frmConfirm), au modele de frmClean (A4 § 2.4,
    # R1 a R8) : bandeau de la couleur du niveau (danger, warn, info), avec pictogramme GDI+, titre et texte ; case de
    # confirmation en gras si $Check, qui nomme le lecteur ou la disquette (bouton principal actif et bleu seulement case
    # cochee) ; bouton principal, puis Fermer (CancelButton : Fermer, Echap et la croix refusent). Aucun AcceptButton et
    # focus sur la case, ou sur Fermer sans case : Entree ne confirme rien. Renvoie $true seulement pour le bouton
    # principal, case cochee. Banc : Name frmConfirm, chkConfirm, btnConfirmGo, btnConfirmClose (fins de test par
    # OpenForms ; minuteur de securite de make-test : Fermer). 12.8 (validation du 19/10) : chaque reponse est notee au
    # journal, en une ligne : question en court (Get-ConfirmShort) et reponse, confirmee ou refusee (Fermer, Echap, croix,
    # ou bouton principal sans la case).
    if (-not $GoText) { $GoText = (T 'Continuer') }
    $W = 600; $tw = $W - 128
    # 12.8 (S3) : second bouton : fenetre elargie pour que les trois boutons tiennent sur la ligne (memes largeurs que plus bas)
    if ($AltText) {
        $wGo = [math]::Max(170, [System.Windows.Forms.TextRenderer]::MeasureText($GoText, $script:BtnFontBold).Width + $(if ($GoGlyph) { 56 } else { 32 }))
        $wAlt = [math]::Max(150, [System.Windows.Forms.TextRenderer]::MeasureText($AltText, $script:BtnFont).Width + 32)
        $W = [int][math]::Max($W, $wAlt + 8 + $wGo + 8 + 110); $tw = $W - 128
    }
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $gdi = New-Object System.Collections.Generic.List[object]       # images et polices liberees avec la fenetre
    $pal = switch ($Level) {
        'danger' { @{ Back = [System.Drawing.Color]::FromArgb(253, 236, 234); Edge = $script:Theme.Danger; Ink = [System.Drawing.Color]::FromArgb(160, 32, 26); Body = [System.Drawing.Color]::FromArgb(110, 24, 20) } }
        'info'   { @{ Back = [System.Drawing.Color]::FromArgb(234, 241, 251); Edge = $script:Theme.Accent; Ink = $script:Theme.Accent2; Body = [System.Drawing.Color]::FromArgb(40, 46, 58) } }
        default  { @{ Back = [System.Drawing.Color]::FromArgb(253, 243, 228); Edge = $script:Theme.Warn; Ink = [System.Drawing.Color]::FromArgb(138, 74, 0); Body = [System.Drawing.Color]::FromArgb(88, 52, 8) } }
    }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Name = 'frmConfirm'; $dlg.Text = $Title
    $dlg.FormBorderStyle = 'FixedDialog'; $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false; $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'; $dlg.Icon = $form.Icon; $dlg.Font = $form.Font; $dlg.BackColor = [System.Drawing.Color]::White
    # Bandeau : pictogramme, titre Semibold 11 et texte, hauteurs mesurees dans la langue de l interface
    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.Name = 'pnlConfirmBanner'; $pnl.Location = New-Object System.Drawing.Point(16, 16); $pnl.BackColor = $pal.Back; $pnl.Tag = $pal.Edge
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Name = 'picConfirm'; $pic.Image = New-ConfirmPicto $Picto; $gdi.Add($pic.Image); $pic.SizeMode = 'Zoom'
    $pic.Location = New-Object System.Drawing.Point(8, 10); $pic.Size = New-Object System.Drawing.Size(100, 70)
    $fH = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $gdi.Add($fH)
    $lblH = New-Object System.Windows.Forms.Label
    $lblH.Name = 'lblConfirmTitle'; $lblH.Text = $Heading; $lblH.UseMnemonic = $false; $lblH.Font = $fH; $lblH.ForeColor = $pal.Ink
    $hH = [System.Windows.Forms.TextRenderer]::MeasureText($Heading, $fH, (New-Object System.Drawing.Size($tw, 10000)), $tf).Height
    $lblH.Location = New-Object System.Drawing.Point(118, 10); $lblH.Size = New-Object System.Drawing.Size($tw, ($hH + 2))
    $lblT = New-Object System.Windows.Forms.Label
    $lblT.Name = 'lblConfirmText'; $lblT.Text = $Text; $lblT.UseMnemonic = $false; $lblT.ForeColor = $pal.Body
    $hT = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $dlg.Font, (New-Object System.Drawing.Size($tw, 10000)), $tf).Height
    $lblT.Location = New-Object System.Drawing.Point(118, ($lblH.Bottom + 4)); $lblT.Size = New-Object System.Drawing.Size($tw, ($hT + 4))
    $pnl.Size = New-Object System.Drawing.Size($W, [math]::Max(90, $lblT.Bottom + 10))
    $pnl.Controls.AddRange(@($pic, $lblH, $lblT))
    $pnl.Add_Paint({ $pen = New-Object System.Drawing.Pen([System.Drawing.Color]$this.Tag, [single]2); $_.Graphics.DrawRectangle($pen, 1, 1, $this.Width - 2, $this.Height - 2); $pen.Dispose() })
    $y = $pnl.Bottom + 14
    # Case de confirmation physique, en gras, sur plusieurs lignes si besoin
    $chk = $null
    if ($Check) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Name = 'chkConfirm'; $chk.Text = $Check; $chk.Font = $bold; $chk.UseMnemonic = $false
        $chk.CheckAlign = 'TopLeft'; $chk.TextAlign = 'TopLeft'
        $hC = [System.Windows.Forms.TextRenderer]::MeasureText($Check, $bold, (New-Object System.Drawing.Size(($W - 24), 10000)), $tf).Height
        $chk.Location = New-Object System.Drawing.Point(16, $y); $chk.Size = New-Object System.Drawing.Size($W, ($hC + 6))
        $y = $chk.Bottom + 12
    }
    # 12.8 (S3) : liste modifiable (marque de la disquette inseree), libelle a gauche, sous la case
    $cmb = $null; $lblCmb = $null
    if ($Combo) {
        $lblCmb = New-Object System.Windows.Forms.Label
        $lblCmb.Name = 'lblConfirmCombo'; $lblCmb.AutoSize = $true; $lblCmb.UseMnemonic = $false; $lblCmb.Text = [string]$Combo.Label; $lblCmb.Font = $dlg.Font
        $lblCmb.Location = New-Object System.Drawing.Point(16, ($y + 4))
        $cmb = New-Object System.Windows.Forms.ComboBox
        $cmb.Name = 'cmbConfirmCombo'; $cmb.DropDownStyle = 'DropDown'
        foreach ($it in @($Combo.Items)) { if ($it) { [void]$cmb.Items.Add([string]$it) } }
        $cmb.Text = [string]$Combo.Text
        $lx = 16 + $lblCmb.PreferredWidth + 8
        $cmb.Location = New-Object System.Drawing.Point($lx, $y); $cmb.Width = [math]::Max(160, 16 + $W - $lx)
        if ($Combo.Tip -and $tip) { $tip.SetToolTip($cmb, [string]$Combo.Tip) }
        $y = $cmb.Bottom + 12
    }
    # Boutons en bas a droite : action principale avec glyphe, puis Fermer (110 px, CancelButton)
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Name = 'btnConfirmGo'; $btnGo.Text = $GoText; $btnGo.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnGo.Size = New-Object System.Drawing.Size([math]::Max(170, [System.Windows.Forms.TextRenderer]::MeasureText($GoText, $script:BtnFontBold).Width + $(if ($GoGlyph) { 56 } else { 32 })), 34)
    $btnCl = New-Object System.Windows.Forms.Button
    $btnCl.Name = 'btnConfirmClose'; $btnCl.Text = (T 'Fermer'); $btnCl.Size = New-Object System.Drawing.Size(110, 34)
    $btnCl.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    Set-Btn $btnCl '' 'normal'
    $btnCl.Location = New-Object System.Drawing.Point((16 + $W - $btnCl.Width), $y)
    $btnGo.Location = New-Object System.Drawing.Point(($btnCl.Left - 8 - $btnGo.Width), $y)
    # 12.8 (S3) : second bouton d action, style normal, a gauche du bouton principal ; inactif tant que la case n est pas cochee
    $btnAlt = $null
    if ($AltText) {
        $btnAlt = New-Object System.Windows.Forms.Button
        $btnAlt.Name = 'btnConfirmAlt'; $btnAlt.Text = $AltText; $btnAlt.DialogResult = [System.Windows.Forms.DialogResult]::Retry
        $btnAlt.Size = New-Object System.Drawing.Size([math]::Max(150, [System.Windows.Forms.TextRenderer]::MeasureText($AltText, $script:BtnFont).Width + 32), 34)
        Set-Btn $btnAlt '' 'normal'
        $btnAlt.Location = New-Object System.Drawing.Point(($btnGo.Left - 8 - $btnAlt.Width), $y)
        $btnAlt.Enabled = (-not $chk)
    }
    $dlg.ClientSize = New-Object System.Drawing.Size(($W + 32), ($y + $btnCl.Height + 16))
    $dlg.CancelButton = $btnCl                        # pas d AcceptButton : Entree ne confirme rien
    $dlg.Controls.Add($pnl); if ($chk) { $dlg.Controls.Add($chk) }; $dlg.Controls.AddRange(@($btnGo, $btnCl))
    if ($btnAlt) { $dlg.Controls.Add($btnAlt) }
    if ($cmb) { $dlg.Controls.Add($lblCmb); $dlg.Controls.Add($cmb) }
    [void](Set-CleanDlgFit $dlg ([System.Windows.Forms.Screen]::FromControl($form).WorkingArea))
    $prev = $script:ConfirmDlg
    $script:ConfirmDlg = @{ Go = $btnGo; Glyph = $GoGlyph; GoStyle = ''; Alt = $btnAlt }
    Set-ConfirmGo (-not $chk)
    if ($chk) { $chk.Add_CheckedChanged({ Set-ConfirmGo $this.Checked; if ($script:ConfirmDlg.Alt) { $script:ConfirmDlg.Alt.Enabled = $this.Checked } }); $dlg.ActiveControl = $chk }
    else { $dlg.ActiveControl = $btnCl }
    $script:ConfirmChoice = 'close'; $script:ConfirmComboText = $null
    try {
        $dr = if ($form.Visible) { $dlg.ShowDialog($form) } else { $dlg.ShowDialog() }
        $ok = [bool]($dr -eq [System.Windows.Forms.DialogResult]::OK -and (-not $chk -or $chk.Checked))
        $alt = [bool]($btnAlt -and $dr -eq [System.Windows.Forms.DialogResult]::Retry -and (-not $chk -or $chk.Checked))
        $script:ConfirmChoice = if ($ok) { 'go' } elseif ($alt) { 'alt' } else { 'close' }
        if ($cmb) { $script:ConfirmComboText = [string]$cmb.Text }
        $ans = if ($ok) { (T 'confirmée') } elseif ($alt) { (T 'autre choix : « {0} »') -f "$AltText" } else { (T 'refusée (Fermer)') }
        Append-Log ((T "Confirmation : {0} : {1}") -f (Get-ConfirmShort $Heading $Text), $ans)
        return $ok
    } finally {
        $script:ConfirmDlg = $prev
        foreach ($b in @($btnGo, $btnCl, $btnAlt)) { if ($b -and $b.Image) { $i = $b.Image; $b.Image = $null; $i.Dispose() } }
        $dlg.Dispose()
        foreach ($o in $gdi) { try { $o.Dispose() } catch { } }
    }
}

# --- Fenetres de decision (12.8, lot 5) : composants communs au modele de frmClean (A4 § 2.4, R1 a R8) ---------------
# frmCalibConfirm, frmReinsert et frmCalibRedo (Show-TimedConfirm), frmCalibSurface, frmCalibReview, frmOldCalib, frmJitter.
# frmConfirm et frmClean gardent leurs propres fonctions (Set-ConfirmGo, Set-CleanGo, Set-CleanDlgFit), au comportement identique.
function Get-DlgPalette([string]$Level) {
    # Couleurs d un bandeau selon le niveau (A4 R2), celles de frmConfirm : fond, cadre, encre du titre, encre du texte
    switch ($Level) {
        'danger' { return @{ Back = [System.Drawing.Color]::FromArgb(253, 236, 234); Edge = $script:Theme.Danger; Ink = [System.Drawing.Color]::FromArgb(160, 32, 26); Body = [System.Drawing.Color]::FromArgb(110, 24, 20) } }
        'info'   { return @{ Back = [System.Drawing.Color]::FromArgb(234, 241, 251); Edge = $script:Theme.Accent; Ink = $script:Theme.Accent2; Body = [System.Drawing.Color]::FromArgb(40, 46, 58) } }
        default  { return @{ Back = [System.Drawing.Color]::FromArgb(253, 243, 228); Edge = $script:Theme.Warn; Ink = [System.Drawing.Color]::FromArgb(138, 74, 0); Body = [System.Drawing.Color]::FromArgb(88, 52, 8) } }
    }
}

function Draw-DlgBadge($g, [string]$kind, [single]$x, [single]$y, [single]$s) {
    # Icone d etat du lot 3 (D15 : h0 ✓, h1 !, h2 ✗ ; Draw-QualityState) de $s pixels en ($x, $y), avec son liseré blanc
    $st = $g.Save()
    $g.TranslateTransform($x, $y); $g.ScaleTransform([single]($s / 64.0), [single]($s / 64.0))
    Draw-QualityState $g $kind ([single]6)
    $g.Restore($st)
}

function New-DlgPicto([string]$kind, [string]$badge = '') {
    # Pictogramme 120 x 84 d un bandeau de fenetre de decision (affiche en 100 x 70), en GDI+ comme ceux de frmConfirm et du
    # nettoyage : disk (disquette de donnees du logo), drive (disquette inseree dans le lecteur), avec l icone d etat $badge
    # (h0, h1, h2) ; curve (courbes de precompensation A et B) ; jitter (disquette et les trois etats SAIN, A SURVEILLER,
    # CRITIQUE) ; tout autre nom : New-ConfirmPicto (warn, data, erase, vignettes du nettoyage). Libere par l appelant
    if (@('disk', 'drive', 'curve', 'jitter') -notcontains $kind) { return (New-ConfirmPicto $kind) }
    $bmp = New-Object System.Drawing.Bitmap(120, 84, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        switch ($kind) {
            'disk' {
                Draw-PictoFloppy $g 18 4 72 $false
                if ($badge) { Draw-DlgBadge $g $badge 74 40 40 }
            }
            'drive' {
                Draw-PictoFloppy $g 38 0 44 $false $true
                Draw-PictoDrive $g $true
                if ($badge) { Draw-DlgBadge $g $badge 82 2 34 }
            }
            'curve' {
                $rr = New-RoundRect 6 4 108 76 6
                $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White); $g.FillPath($b, $rr); $b.Dispose()
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(205, 212, 224), [single]1.5); $g.DrawPath($pen, $rr); $pen.Dispose(); $rr.Dispose()
                $pen = New-Object System.Drawing.Pen($script:Theme.Muted, [single]2)
                $g.DrawLines($pen, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(20, 14)), (New-Object System.Drawing.PointF(20, 68)), (New-Object System.Drawing.PointF(104, 68)))); $pen.Dispose()
                $pa = @((New-Object System.Drawing.PointF(24, 62)), (New-Object System.Drawing.PointF(38, 55)), (New-Object System.Drawing.PointF(52, 50)), (New-Object System.Drawing.PointF(66, 41)), (New-Object System.Drawing.PointF(80, 36)), (New-Object System.Drawing.PointF(100, 24)))
                $pb = @((New-Object System.Drawing.PointF(24, 58)), (New-Object System.Drawing.PointF(38, 53)), (New-Object System.Drawing.PointF(52, 42)), (New-Object System.Drawing.PointF(66, 38)), (New-Object System.Drawing.PointF(80, 29)), (New-Object System.Drawing.PointF(100, 18)))
                $pen = New-Object System.Drawing.Pen($script:Theme.Accent, [single]3); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                $g.DrawLines($pen, [System.Drawing.PointF[]]$pa); $pen.Dispose()
                $pen = New-Object System.Drawing.Pen($script:Theme.Flux, [single]3); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
                $g.DrawLines($pen, [System.Drawing.PointF[]]$pb); $pen.Dispose()
            }
            'jitter' {
                Draw-PictoFloppy $g 4 10 64 $false
                Draw-DlgBadge $g 'h0' 82 3 24; Draw-DlgBadge $g 'h1' 82 30 24; Draw-DlgBadge $g 'h2' 82 57 24
            }
        }
    } finally { $g.Dispose() }
    return $bmp
}

function New-DlgBanner($dlg, [int]$Y, [int]$W, [string]$Heading, [string]$Text, [string]$Level, $Image, $Gdi, [string]$TextName = '') {
    # Bandeau d une fenetre de decision (A4 R2), au modele de frmConfirm : rectangle en (16, $Y), de largeur $W, fond et
    # cadre de la couleur du niveau (Get-DlgPalette : danger, warn, info), pictogramme GDI+ $Image (New-DlgPicto) en 100 x 70,
    # titre $Heading en Semibold 11, texte $Text ; hauteurs mesurees dans la langue de l interface. Fond, cadre, pictogramme
    # et titre sont dessines par la fenetre elle-meme (Draw-DlgBanner, donnees dans $dlg.Tag.Banner) ; le texte est le seul
    # controle du bandeau : un Label de PREMIER NIVEAU de $dlg (Name $TextName), du fond du bandeau. Les fins de test lisent
    # les Label de premier niveau des fenetres de calibration (.Controls, non recursif) et y comptent les PictureBox
    # (« courbe affichee ») : ni titre ni pictogramme n y entrent, et aucun controle ne se superpose a un autre (DrawToBitmap,
    # captures du wiki, dessine les controles superposes dans l ordre inverse). Image et police rangees dans $Gdi (liberees
    # avec la fenetre, Clear-DlgGdi). Renvoie @{ Bottom ; Text }.
    $pal = Get-DlgPalette $Level
    $tw = $W - 128
    $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    if ($Image) { $Gdi.Add($Image) }
    $fH = New-Object System.Drawing.Font('Segoe UI Semibold', 11); $Gdi.Add($fH)
    $hH = if ($Heading) { [System.Windows.Forms.TextRenderer]::MeasureText($Heading, $fH, (New-Object System.Drawing.Size($tw, 10000)), $tf).Height + 2 } else { 0 }
    $lbl = New-Object System.Windows.Forms.Label
    if ($TextName) { $lbl.Name = $TextName }
    $lbl.AutoSize = $false; $lbl.UseMnemonic = $false; $lbl.Text = $Text; $lbl.ForeColor = $pal.Body; $lbl.BackColor = $pal.Back; $lbl.Font = $dlg.Font
    # Hauteur : la plus grande de la mesure du texte et de celle du Label (son propre decoupage des lignes, qui peut en
    # compter une de plus sur un texte long)
    $hT = [math]::Max([System.Windows.Forms.TextRenderer]::MeasureText($Text, $dlg.Font, (New-Object System.Drawing.Size($tw, 10000)), $tf).Height, $lbl.GetPreferredSize((New-Object System.Drawing.Size($tw, 0))).Height)
    $lbl.Location = New-Object System.Drawing.Point((16 + 118), ($Y + 10 + $hH + $(if ($hH) { 4 } else { 0 }))); $lbl.Size = New-Object System.Drawing.Size($tw, ($hT + 4))
    $rect = New-Object System.Drawing.Rectangle(16, $Y, $W, [math]::Max(90, $lbl.Bottom - $Y + 10))
    $dlg.Tag = @{ Banner = @{ Rect = $rect; Back = $pal.Back; Edge = $pal.Edge; Ink = $pal.Ink; Image = $Image; Heading = $Heading; Font = $fH; HeadH = $hH; TW = $tw } }
    $dlg.Add_Paint({ Draw-DlgBanner $this $_.Graphics })
    $dlg.Controls.Add($lbl)
    return @{ Bottom = $rect.Bottom; Text = $lbl }
}

function Draw-DlgBanner($dlg, $g) {
    # Dessin du bandeau de New-DlgBanner (Paint de la fenetre), decale du defilement (Set-DlgFit) : fond, cadre de 2 px,
    # pictogramme et titre
    $b = if ($dlg.Tag -is [hashtable]) { $dlg.Tag.Banner } else { $null }
    if (-not $b) { return }
    $o = $dlg.AutoScrollPosition
    $r = $b.Rect; $x = $r.X + $o.X; $y = $r.Y + $o.Y
    $br = New-Object System.Drawing.SolidBrush($b.Back); $g.FillRectangle($br, $x, $y, $r.Width, $r.Height); $br.Dispose()
    $pen = New-Object System.Drawing.Pen($b.Edge, [single]2); $g.DrawRectangle($pen, ($x + 1), ($y + 1), ($r.Width - 2), ($r.Height - 2)); $pen.Dispose()
    if ($b.Image) {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($b.Image, (New-Object System.Drawing.Rectangle(($x + 8), ($y + 10), 100, 70)))
    }
    if ($b.Heading) {
        $tf = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
        [System.Windows.Forms.TextRenderer]::DrawText($g, [string]$b.Heading, $b.Font, (New-Object System.Drawing.Rectangle(($x + 118), ($y + 10), $b.TW, $b.HeadH)), $b.Ink, $tf)
    }
}

function Get-DlgButtonWidth([string]$text, [string]$glyph = '', [int]$min = 110) {
    # Largeur d un bouton de fenetre de decision (A4 R1, R6) : texte mesure en gras (style principal ou danger), glyphe compris
    return [int][math]::Max($min, [System.Windows.Forms.TextRenderer]::MeasureText($text, $script:BtnFontBold).Width + $(if ($glyph) { 56 } else { 32 }))
}

function Set-BtnFitWidth($btn, [switch]$KeepRight) {
    # 12.8 (FIX5) : bouton d onglet elargi a sa taille preferee (texte, icone et marges de Set-Btn, a appeler apres lui),
    # jamais retreci : texte entier dans les deux langues. $KeepRight : bord droit garde (bouton ancre a droite)
    $w = $btn.GetPreferredSize([System.Drawing.Size]::Empty).Width
    if ($w -le $btn.Width) { return }
    if ($KeepRight) { $btn.Left -= ($w - $btn.Width) }
    $btn.Width = $w
}

function Set-PrimaryEnabled($btn, [bool]$on, [string]$glyph = '') {
    # Bouton principal d une fenetre de decision (A4 R5, R6) : bleu et actif seulement quand son action est permise (case de
    # confirmation cochee), sinon style normal grise (generalisation de Set-ConfirmGo et Set-CleanGo, sans couleur codee en
    # dur). Style et icone refaits seulement quand ils changent (style courant dans Tag), ancienne icone liberee
    if (-not $btn) { return }
    $btn.Enabled = $on
    $st = if ($on) { 'primary' } else { 'normal' }
    if ([string]$btn.Tag -ne $st) { $btn.Tag = $st; $old = $btn.Image; Set-Btn $btn $glyph $st; if ($old) { $old.Dispose() } }
}

function Set-DlgFit($dlg, [System.Drawing.Rectangle]$wa) {
    # Fenetre de decision plus haute que la zone de travail $wa (A4 R1, generalisation de Set-CleanDlgFit) : hauteur ramenee a
    # celle de l ecran avec un defilement vertical, largeur augmentee de la barre de defilement. $true si ajustee
    if ($dlg.Height -le $wa.Height) { return $false }
    $dlg.AutoScroll = $true
    $dlg.Size = New-Object System.Drawing.Size(($dlg.Width + [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth), $wa.Height)
    return $true
}

function Clear-DlgGdi($dlg, $gdi) {
    # Fermeture d une fenetre de decision (A4 R3) : icones des boutons (Set-Btn) retirees, fenetre liberee, puis images et
    # polices de $gdi. Les icones d etat de qualite (Get-QualityIcon) restent a leur cache : jamais dans $gdi
    $todo = New-Object System.Collections.Generic.Stack[object]
    $todo.Push($dlg)
    while ($todo.Count -gt 0) {
        $c = $todo.Pop()
        foreach ($k in @($c.Controls)) { $todo.Push($k) }
        if ($c -is [System.Windows.Forms.Button] -and $c.Image) { $i = $c.Image; $c.Image = $null; $gdi.Add($i) }
    }
    $dlg.Dispose()
    foreach ($o in $gdi) { try { $o.Dispose() } catch { } }
}
