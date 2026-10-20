# --- Fenetre -------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Greaseweazle Studio v$($script:Version)"
# Largeur : cartes de l Accueil (colonne de droite jusqu a 770 px) sans defilement horizontal avec la barre verticale,
# a la taille par defaut comme a la taille minimale (12.6 : 790 et 800 px auparavant, 5 et 11 px de defilement)
$form.ClientSize = New-Object System.Drawing.Size(800, 682)
$form.MinimumSize = New-Object System.Drawing.Size(816, 620)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$form.BackColor = [System.Drawing.Color]::FromArgb(236, 239, 244)
$mono     = New-Object System.Drawing.Font('Consolas', 9.5)
$monoBig  = New-Object System.Drawing.Font('Consolas', 10.5)
$tip  = New-Object System.Windows.Forms.ToolTip
$bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)   # utilise des la bibliotheque
# Infobulles : delai de lecture suffisant pour les textes longs (5 s par defaut sous WinForms)
$tip.AutoPopDelay = 30000; $tip.InitialDelay = 400; $tip.ReshowDelay = 100

# Textes indicatifs gris dans les champs vides (EM_SETCUEBANNER) : appliques a l affichage de la fenetre, une fois
# les poignees Windows creees. Sans effet sur une zone multiligne.
$script:CueOk = $false
try {
    Add-Type -Namespace GwUi -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);' -ErrorAction Stop
    $script:CueOk = $true
} catch { }
$script:CueText = @{}

# Aide en ligne : page du wiki associee a l onglet courant (TabPage.Tag), touche F1 ou bouton Aide du bandeau
$script:WikiBase = 'https://github.com/Bartozorus/GreaseweazleGUI_Studio/wiki/'


# ============================== THEME, ICONES & LOGO ===========================
# Aucun fichier image externe : les icones sont rendues a l'execution a partir de la police
# d'icones de Windows (Segoe Fluent Icons sur Windows 11, Segoe MDL2 Assets sur Windows 10),
# le logo est dessine en GDI+.
$script:Theme = @{
    Accent  = [System.Drawing.Color]::FromArgb(37, 99, 168)
    Accent2 = [System.Drawing.Color]::FromArgb(22, 54, 98)
    Danger  = [System.Drawing.Color]::FromArgb(196, 60, 52)
    Ok      = [System.Drawing.Color]::FromArgb(46, 139, 87)
    Good    = [System.Drawing.Color]::FromArgb(96, 140, 44)    # 12.8 (D17) : niveau BON des icones de score ; 3,97:1 sur blanc (element graphique, >= 3:1)
    Warn    = [System.Drawing.Color]::FromArgb(214, 140, 30)
    WarnInk = [System.Drawing.Color]::FromArgb(156, 92, 8)     # 12.8 (D17) : texte d avertissement sur fond clair ; contraste WCAG 5,14:1 sur Page, 5,32:1 sur blanc, 4,61:1 sur Window (176,104,10 : 4,20:1 sur Page)
    Muted   = [System.Drawing.Color]::FromArgb(110, 116, 128)
    Page    = [System.Drawing.Color]::FromArgb(250, 251, 253)
    Window  = [System.Drawing.Color]::FromArgb(236, 239, 244)
    Floppy  = [System.Drawing.Color]::FromArgb(44, 58, 85)
    Flux    = [System.Drawing.Color]::FromArgb(255, 150, 50)
    Folder  = [System.Drawing.Color]::FromArgb(222, 170, 60)
    Zip     = [System.Drawing.Color]::FromArgb(130, 90, 170)
}
$script:IconFont = $null
try {
    $fams = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name })
    foreach ($f in @('Segoe Fluent Icons','Segoe MDL2 Assets')) { if ($fams -contains $f) { $script:IconFont = $f; break } }
} catch { }
$script:Glyph = @{
    Library=0xE8F1; Save=0xE74E; Download=0xE896; Switch=0xE8AB; Copy=0xE8C8; Diagnostic=0xE9D9
    Repair=0xE90F; Stopwatch=0xE916; Cmd=0xE756; Folder=0xE8B7; FolderOpen=0xE838; Search=0xE721
    Refresh=0xE72C; Sync=0xE895; OpenFile=0xE8E5; Document=0xE8A5; Package=0xE7B8; Page=0xE7C3
    Stop=0xE71A; Delete=0xE74D; Setting=0xE713; Info=0xE946; Error=0xE783; Check=0xE73E
    Play=0xE768; Pin=0xE718; Usb=0xE88E; Add=0xE710; Remove=0xE738; Home=0xE80F; Help=0xE897; History=0xE81C
}

$script:BtnHoverNormal = [System.Drawing.Color]::FromArgb(232, 238, 247)

$script:LogoBig   = New-LogoBitmap 48
$script:LogoIcon  = New-LogoBitmap 32

# Les TabPage recoivent une taille explicite AVANT l ajout des controles :
# WinForms calcule les decalages d ancrage a ce moment-la. Sans cela, un
# controle ancre a droite est positionne par rapport a une page de 200 px
# et se retrouve hors ecran une fois la page etiree.
$script:PageW = 782
$script:PageH = 340

