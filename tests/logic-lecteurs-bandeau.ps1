param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot LN-b) : lecteurs enregistres, interface (fin du module 112, et les lignes ajoutees a 110, 120, 140, 240, 250,
# 260, 270, 276, 300, 510, 520, 540 et 600). Liste « Lecteur : » du bandeau, liaison au reglage drive, lecteur a confirmer,
# verrou et molette, fenetre « Lecteurs enregistres » construite sans etre affichee.
#  U  bandeau : instructions reelles de 510 sur des controles jamais affiches, fenetre de 800 px : registre vide, positions,
#     libelles et infobulle de la 12.10 au pixel pres ; disposition elargie en francais et en anglais (aucun
#     chevauchement, rien sur le sous-titre, nom le plus large admis entier), retour a la 12.10 ; textes courts de la ligne
#     d etat (439 px) et du libelle de la restauration (290 px), texte d etat et controles de la fenetre (aucun texte coupe).
#  D  liste, reglage drive, gestionnaire reel du bandeau (520), detection, en-tete du journal ; D7 lecteur du bandeau
#     deplace puis rechargement par la vraie Load-Config ; D8 dernier lecteur relu.
#  K  lecteur a confirmer, confirmation (textes, refus, -Write, -Target), K4 calibration croisee reelle ; K5 les cinq
#     fonctions reelles qui engagent une operation (Start-ImageWrite, Start-LevelCalib, Start-PrecompCalib,
#     Start-ContentMeasure, Start-Restore) : jamais sans la confirmation quand elle est due, jamais avec un registre vide.
#  L  verrou de la liste (Update-DriveLock) ; molette et choix a la main (gestionnaires reels de 510).
#  P  fenetre : Get-DriveEditPlan, Invoke-DriveEditPlan, Get-DriveRows, suppression, textes qui annoncent la copie.
#  Y  textes completes pour un lecteur enregistre seulement (case de la mesure, fenetre de decision, cibles ecartees,
#     libelle de la restauration) : sinon ceux de la 12.10, mot pour mot.
#  I  statique : confirmation avant toute creation d etat, gestionnaire du bandeau, lignes ajoutees gardees par « registre
#     non vide », textes francais et anglais de la specification, documents.
#  Q  avec -Before <copie de la source d avant le lot> (aucune dans le depot) : bandeau de cette source, memes positions,
#     libelles et infobulle.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees
# par dot-source. Aucun gw, aucune fenetre affichee, aucune compilation. Non couvert ici : les evenements reels d une
# liste WinForms affichee (ordre, molette, clavier, DroppedDown pendant un clic), le rendu du bandeau et de la fenetre.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
Import-TestWinForms
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tIf = [System.Management.Automation.Language.IfStatementAst]
$tStr = [System.Management.Automation.Language.StringConstantExpressionAst]
$tExp = [System.Management.Automation.Language.ExpandableStringExpressionAst]
$utf8 = New-Object System.Text.UTF8Encoding($false)
$mods = Join-Path $Wt 'src\modules'

# ---------------------------------------------------------------- arbres, fonctions, instructions
$script:AstOf = @{}
function Get-LbAst([string]$path) {
    if (-not $script:AstOf.ContainsKey($path)) {
        $tk = $null; $er = $null
        $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
        if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
        $script:AstOf[$path] = $a
    }
    return $script:AstOf[$path]
}
function Get-LbModule([string]$dir, [string]$prefix) {
    $f = @(Get-ChildItem -LiteralPath $dir -Filter "$prefix-*.ps1" -File)
    if ($f.Count -ne 1) { return '' }
    return $f[0].FullName
}
function Get-LbFnAsts([string]$path) { return @((Get-LbAst $path).FindAll({ param($x) $x -is $tFn }, $false)) }
function Get-LbFnAst([string]$dir, [string]$prefix, [string]$name) {
    $p = Get-LbModule $dir $prefix
    if (-not $p) { return $null }
    foreach ($fd in (Get-LbFnAsts $p)) { if ($fd.Name -eq $name) { return $fd } }
    return $null
}
function Write-LbGen([string]$path, [string[]]$parts) { [System.IO.File]::WriteAllText($path, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true))) }
function Get-LbStmts([string]$dir, [string]$prefix, [string]$from, [string]$to) {
    # Instructions du niveau du script d un module, de celle qui commence par $from a celle qui commence par $to comprises
    $p = Get-LbModule $dir $prefix
    $l = @(); $on = $false
    foreach ($s in (Get-LbAst $p).EndBlock.Statements) {
        $t = $s.Extent.Text
        if (-not $on -and $t.StartsWith($from)) { $on = $true }
        if ($on) { $l += $t }
        if ($on -and $t.StartsWith($to)) { break }
    }
    return ,@($l)
}
$want = [ordered]@{
    '100' = @('New-GlyphBitmap', 'New-ButtonIcon', 'New-RoundRect', 'Set-Btn', 'New-Label', 'New-BannerLabel', 'Get-HomeCard', 'New-HomeCard', 'Get-DlgPalette', 'New-DlgPicto', 'New-DlgBanner', 'Draw-DlgBanner',
              'Get-DlgButtonWidth', 'Set-DlgFit', 'Clear-DlgGdi', 'Fit-ControlText')
    '110' = @('Get-CommonArgs', 'Get-AppBusy', 'Complete-DriveDetect', 'Get-LogExportHeader')
    '112' = @('*')
    '120' = @('ConvertTo-SettingValue', 'Get-Setting', 'Set-SettingStore', 'Set-SettingCtlValue', 'Set-Setting', 'Register-SettingCtl', 'Update-SettingDependents', 'Get-SettingText', 'Reset-Settings', 'Import-Settings', 'Export-Settings',
              'Update-LegacyCleanDefault', 'Update-LegacyLevelMode', 'Update-LegacyEraseMode', 'Test-ContentLevelSettings', 'Backup-ConfigBeforeRef', 'Export-CurveView', 'Export-DriveCurves', 'Import-DriveCurves',
              'Export-TargetDrives', 'Import-TargetDrives', 'Save-Config', 'Get-Cfg', 'Set-Num', 'Set-Combo', 'Load-Config')
    '140' = @('Get-DriveIds', 'Get-TargetDrive', 'Set-TargetDrive', 'Get-TargetDriveItems', 'Get-TargetCurves', 'Update-TargetDriveUi', 'Start-ImageWrite')
    '210' = @('Draw-PictoFloppy', 'Draw-PictoDrive')
    '220' = @('Get-CurveDate', 'Get-DriveFamilyCurves')
    '230' = @('Test-CurveHd', 'Get-CalibFamilyName', 'Get-Median', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Test-CurveCalcOk', 'Get-CurveCalcText', 'ConvertTo-CurveConfig', 'ConvertTo-LevelConfig', 'ConvertTo-LevelBrandConfig',
              'ConvertFrom-LevelBrandConfig', 'ConvertFrom-LevelConfig', 'ConvertFrom-CurveConfig')
    '240' = @('Get-CalibDriveArgsFor', 'Get-CalibStoreDrive', 'Split-CrossDrive', 'Get-CrossCalibTargets', 'Get-CurveKeyLabel', 'Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves',
              'Get-DriveCurveKeys', 'Get-DriveCurveLabel')
    '260' = @('Start-LevelCalib')
    '265' = @('Get-LevelBrandKey')
    '270' = @('Start-PrecompCalib', 'Start-CrossCalib', 'Update-CalibProgress')
    '274' = @('Get-DriveK', 'Get-StaleDriveFactors', 'ConvertTo-FiniteOrNull', 'Get-ConfigDouble', 'Get-RecValues', 'ConvertTo-ContentConfig', 'ConvertFrom-ContentConfig')
    '276' = @('Start-ContentMeasure')
    '300' = @('Update-RsDrive', 'Start-Restore')
}
$parts = New-Object System.Collections.Generic.List[string]
$missing = @(); $nFn = 0
foreach ($px in @($want.Keys)) {
    $p = Get-LbModule $mods $px
    if (-not $p) { $missing += "module $px"; continue }
    $fds = Get-LbFnAsts $p
    if (@($want[$px]) -contains '*') { foreach ($fd in $fds) { $parts.Add($fd.Extent.Text); $nFn++ }; continue }
    foreach ($n in @($want[$px])) {
        $hit = @($fds | Where-Object { $_.Name -eq $n })
        if ($hit.Count -ne 1) { $missing += $n; continue }
        $parts.Add($hit[0].Extent.Text); $nFn++
    }
}
$genFn = Join-Path $here 'gen-fonctions.ps1'
Write-LbGen $genFn @($parts)
# Etat reel : affectations du niveau du script, dans l ordre du module
$wantState = [ordered]@{
    '000' = @('$script:Version', '$script:CalibCalc', '$script:CalibCalcHd', '$script:ContentCalc', '$script:CalibAlgo', '$script:OldCalib')
    '040' = @('$script:AlignRef', '$script:PrecompStd', '$script:PrecompLong', '$script:PrecompStdDefault', '$script:PrecompLongDefault', '$script:PrecompThresholdNs', '$script:JitterStdOk', '$script:JitterStdWatch',
              '$script:JitterOk', '$script:JitterWatch', '$script:AlignRefLabel', '$script:SettingDefs', '$script:Settings', '$script:SettingCtl', '$script:SettingOf', '$script:SettingSync', '$script:OpOverride',
              '$script:ContentKMid', '$script:ContentKLow', '$script:ContentKeepMeasures', '$script:HomeCalApp', '$script:HomeCalFmt',
              '$script:DriveReg', '$script:DriveLast', '$script:DriveChecked', '$script:DriveCur', '$script:DriveRescued', '$script:DriveRescueText', '$script:DriveRescuePairs', '$script:DriveBlockKeep',
              '$script:DriveNameMax', '$script:DriveListWidth', '$script:DriveBackupKeep', '$script:DriveReserved')
    '500' = @('$script:Theme', '$script:Glyph', '$script:BtnHoverNormal')
    '520' = @('$script:BtnFont', '$script:BtnFontBold')
    '550' = @('$script:CleanPrefs')
    '560' = @('$script:CalRedo', '$script:CalHardNsDefault', '$script:CalHardMinNs', '$script:CalHardMaxNs', '$script:CalHardNs', '$script:CalWarmupDefault', '$script:CalWarmupMinutes', '$script:DriveActivity', '$script:DriveCurves',
              '$script:PrecompCurves', '$script:CurveKeys', '$script:LevelFormat', '$script:LevelShifts', '$script:LevelBrand', '$script:LevelBrands', '$script:ConfigRefBackupKeep', '$script:TargetDrives', '$script:CalHardNsUser')
    '565' = @('$script:ContentKMax', '$script:ContentMeasures')
    '590' = @('$script:DetectNone')
}
$stateParts = New-Object System.Collections.Generic.List[string]
$stateMissing = @()
foreach ($px in @($wantState.Keys)) {
    $ast = Get-LbAst (Get-LbModule $mods $px)
    $names = @($wantState[$px]); $seen = @{}
    foreach ($st in $ast.EndBlock.Statements) {
        if ($st -is $tAsg -and $names -contains $st.Left.Extent.Text -and -not $seen.ContainsKey($st.Left.Extent.Text)) { $stateParts.Add($st.Extent.Text); $seen[$st.Left.Extent.Text] = $true }
    }
    foreach ($n in $names) { if (-not $seen.ContainsKey($n)) { $stateMissing += "$px $n" } }
}
$genState = Join-Path $here 'gen-etat.ps1'
Write-LbGen $genState @($stateParts)
# Instructions reelles : bandeau (510, jusqu a la remise a zero de ses positions relevees), gestionnaire du bandeau (520),
# carte de l Accueil (540)
$st510 = Get-LbStmts $mods '510' '$pnlTop = ' '$script:DriveBanner = '
$st520 = Get-LbStmts $mods '520' '$cmbDrive.Add_TextChanged(' '$cmbDrive.Add_TextChanged('
$st540 = Get-LbStmts $mods '540' '$cardDrives' '$script:DrvDlg'
$genBan = Join-Path $here 'gen-bandeau.ps1'; Write-LbGen $genBan @($st510)
$genHdl = Join-Path $here 'gen-gestionnaire.ps1'; Write-LbGen $genHdl @($st520)
$genCard = Join-Path $here 'gen-carte.ps1'; Write-LbGen $genCard @($st540)

# ---------------------------------------------------------------- table I18n reelle, T, etat, fonctions
$Language = 'fr'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$script:IconFont = $null
$fams = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name })
foreach ($fx in @('Segoe Fluent Icons', 'Segoe MDL2 Assets')) { if ($fams -contains $fx) { $script:IconFont = $fx; break } }
. $genState
. $genFn

# ---------------------------------------------------------------- remplacants (gw, fenetres, onglets) et horloge
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
function Get-LbLog([string]$like) { return @($script:Log | Where-Object { $_ -like $like }) }
$script:Asks = New-Object System.Collections.Generic.List[object]
$script:AskAnswer = 'go'
function Show-AppConfirm([string]$Title, [string]$Heading, [string]$Text, [string]$Check = '', [string]$GoText = '', [string]$GoGlyph = '', [string]$Level = 'warn', [string]$Picto = 'warn', [string]$AltText = '', $Combo = $null) {
    # Confirmation repondue par le test : 'go' (bouton principal, case cochee), 'alt' (second bouton), 'close' (Fermer)
    $script:Asks.Add(@{ Title = $Title; Heading = $Heading; Text = $Text; Check = $Check; GoText = $GoText; GoGlyph = $GoGlyph; Level = $Level; AltText = $AltText })
    $a = [string]$script:AskAnswer
    if ($a -eq 'alt' -and -not $AltText) { $a = 'close' }
    $script:ConfirmChoice = $a
    return ($a -eq 'go')
}
$script:Msgs = New-Object System.Collections.Generic.List[object]
$script:MsgAnswer = 'Yes'
function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') {
    $script:Msgs.Add(@{ Text = $text; Title = $title; Buttons = $buttons })
    if ($buttons -eq 'YesNo') { return [string]$script:MsgAnswer }
    return 'OK'
}
function Set-CalibScale([string]$fam) { }
function Update-SlowUi { }
function Update-RsRules { }
function Update-RsFmtFound { }
function Update-RsCalib { }
function Update-CmpFmtFound { }
function Reset-LibDat { }
function Set-JitterThresholds([int]$ok, [int]$watch) { $script:JitterOk = $ok; $script:JitterWatch = $watch }
function Test-RawFluxWrite([string]$img, [string]$fmt) { return $false }
function Get-ImageEncoding([string]$path, [string]$fmt) { return @{ NonMfm = $false; Name = 'MFM' } }
function Render-Banner { }
function Open-HelpForTab { }
function Set-TargetDriveLayout { }
$script:PrecompCalls = 0
function Update-PrecompForImage([string]$p) { $script:PrecompCalls++ }
function Show-DrivesDialog { $script:DrvShown++ }
$script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
function Get-Date {
    param([string]$Format)
    if ($Format) { return $script:TNow.ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture) }
    return $script:TNow
}
function Step-LbClock([int]$seconds = 60) { $script:TNow = $script:TNow.AddSeconds($seconds) }

# ---------------------------------------------------------------- controles reels, jamais affiches
$tip = New-Object System.Windows.Forms.ToolTip
$form = New-Object System.Windows.Forms.Form
$form.ClientSize = New-Object System.Drawing.Size(800, 682)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$bold = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
$split = New-Object System.Windows.Forms.SplitContainer
$ctlNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($v in (Get-LbAst (Get-LbModule $mods '120')).FindAll({ param($x) $x -is $tVar }, $true)) {
    $n = [string]$v.VariablePath.UserPath
    if ($n -cmatch '^(txt|chk|cmb|num|lbl)[A-Z]\w*$') { [void]$ctlNames.Add($n) }
}
foreach ($n in @('cmbWProfile', 'chkWPrecomp', 'cmbWTarget', 'lblWTarget', 'lblWCal', 'lblRsDrive')) { [void]$ctlNames.Add($n) }
$nCtl = 0
foreach ($n in @($ctlNames)) {
    $c = $null
    if ($n -like 'txt*') { $c = New-Object System.Windows.Forms.TextBox }
    elseif ($n -like 'chk*') { $c = New-Object System.Windows.Forms.CheckBox }
    elseif ($n -like 'cmb*') { $c = New-Object System.Windows.Forms.ComboBox }
    elseif ($n -like 'num*') { $c = New-Object System.Windows.Forms.NumericUpDown }
    else { $c = New-Object System.Windows.Forms.Label }
    Set-Variable -Name $n -Value $c -Scope Script
    $nCtl++
}
[void]$cmbWProfile.Items.AddRange([object[]]@('Auto', 'Standard 2 us', 'Long track', 'Manuel'))
$cmbWProfile.SelectedIndex = 0; $chkWPrecomp.Checked = $true
$cmbWTarget.DropDownStyle = 'DropDownList'; $cmbWTarget.Width = 150
$lblRsDrive.Size = New-Object System.Drawing.Size(290, 20); $lblRsDrive.AutoEllipsis = $true
$script:DelayCtrls = [ordered]@{}
$script:GwFormats = @{ 'amiga.amigados' = $true }
$script:GwExe = Join-Path $here 'gw-absent.exe'
$codes = [string[]]@($script:SettingDefs['drive'].Codes)
$nCtlDrive0 = 0; if ($script:SettingCtl.ContainsKey('drive')) { $nCtlDrive0 = @($script:SettingCtl['drive']).Count }
# Bandeau (510) puis gestionnaire du bandeau (520) et carte de l Accueil (540), instructions reelles
. $genBan
$form.Controls.Add($pnlTop)
Fit-ControlText $form
. $genHdl
$tabH = New-Object System.Windows.Forms.Panel
. $genCard
$nCtlDrive1 = @($script:SettingCtl['drive']).Count

# ---------------------------------------------------------------- donnees factices
function New-Cv([string]$drive, [string]$fam, $head, [string]$date, [string]$spec, [string]$target = '') {
    $v0 = [int](($spec -split '[=:]')[1])
    return @{ Family = (Get-CalibFamilyName $fam); Head = $head; Drive = $drive; Target = $target; Date = $date; Model = 'M1'; Spec = $spec; Method = 'motif'
              Version = '12.10'; Algo = 'seg1'; Calc = [string]$script:CalibCalc; KeptFor = ''; Breaks = [int[]]@(); Values = [int[]]@(0..79 | ForEach-Object { $v0 + $_ }); Cyls = [int[]]@(0, 40, 79)
              Ys = [double[]]@(40.5, 80.5, 119.5); Sig = [double[]]@(3.5, 3.5, 3.5); Kinds = [string[]]@('zero', 'zero', 'zero'); Res = [double[]]@(0.5, -0.5, 0.25); Converged = $true
              MaxX = 300; MaxNs = 400; Slope = 0.8; Bits = 100000; Test = 'fine'; Contra = [int[]]@(); DentLo = [int[]]@(); DentHi = [int[]]@(); DentNs = [double[]]@() }
}
function Select-LbDrive([string]$id) {
    # Choix par le code (liste fermee ou chargement) : le gestionnaire reel du bandeau s execute
    $cmbDrive.SelectedItem = $id
    if ([string]$cmbDrive.Text -cne $id) { throw "liste du bandeau : « $($cmbDrive.Text) » au lieu de « $id »" }
}
function Reset-LbWorld([string]$tag) {
    # Depart de chaque cas : memoire neuve, registre vide, liste de six elements sur A, application au repos, dossier de
    # configuration neuf sous le dossier de travail du test
    $dir = Join-Path (Join-Path $here 'cfg') $tag
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $dir -Force)
    $script:ConfigFile = Join-Path $dir 'GreaseweazleGUI.json'
    $script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
    $script:DriveCurves = @{}; foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = $null }
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    $script:OldCalib = $null; $script:LevelShifts = @{}; $script:LevelBrands = @(); $script:ContentMeasures = @(); $script:TargetDrives = @{}; $script:LevelBrand = ''
    $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}; $script:DriveChecked = ''
    $script:DriveRescued = $false; $script:DriveRescueText = $null; $script:DriveRescuePairs = $null; $script:DriveBlockKeep = $false
    $script:Restore = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null; $script:Detect = $null; $script:GwProc = $null
    $script:Chain = New-Object 'System.Collections.Generic.Queue[scriptblock]'; $script:AlignLoop = $false; $script:CalRedo = $null
    $script:DriveActivity = @{}; $script:OpOverride = $null; $script:CurveForm = $null; $script:AfterCalib = ''; $script:CalCrossAsk = $null
    $txtDev.Text = ''
    Update-DriveList
    if ([string]$cmbDrive.Text -cne 'A') { Select-LbDrive 'A' }
    Set-Setting 'drive' 'A'
    $script:DriveCur = 'A'; $script:DriveChecked = ''
    $script:Log.Clear(); $script:Asks.Clear(); $script:Msgs.Clear(); $script:AskAnswer = 'go'; $script:MsgAnswer = 'Yes'
}
function Add-LbDrive([string]$name, [string]$conn, [string]$from = '') {
    # Lecteur enregistre par l action reelle du registre, puis liste du bandeau (ce que fait la fenetre)
    Step-LbClock 1
    $r = Add-NamedDrive $name $conn $from
    if (-not $r.Ok) { throw "Add-NamedDrive $name : $($r.Why)" }
    Update-DriveList
    return $r
}
function Set-LbTwoOnA {
    # Deux lecteurs sur A : Sony MPF920 (lecteur non enregistre de A nomme, ses courbes) et TEAC FD-235HF (neuf) ; un
    # lecteur non enregistre sur 0 avec une courbe
    Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60')
    Set-DriveCurve '0' 'std' (New-Cv '0' 'std' $null '02/11/2026 10:00' '0=23:40=63')
    Sync-PrecompCurves
    [void](Add-LbDrive 'Sony MPF920' 'A' 'A')
    [void](Add-LbDrive 'TEAC FD-235HF' 'A')
}
function Get-LbRow([string]$drive) { foreach ($r in (Get-DriveRows)) { if ([string]$r.Drive -ceq $drive) { return $r } }; return $null }
function Get-LbBaks { return @(Get-ChildItem -LiteralPath (Split-Path -Parent $script:ConfigFile) -File | Where-Object { $_.Name -like '*.lecteurs-*.bak' }).Count }
function Get-LbView { return (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] } | ForEach-Object { "$_=$($script:PrecompCurves[$_].Spec)" }) -join ',') }
function Get-LbItems { return (@($cmbDrive.Items | ForEach-Object { [string]$_ }) -join ',') }
function Invoke-En([scriptblock]$b) { $script:Lang = 'en'; try { return (& $b) } finally { $script:Lang = 'fr' } }
function W([string]$s, $f = $form.Font) { return [System.Windows.Forms.TextRenderer]::MeasureText($s, $f).Width }
$wide = Get-DriveWidestName $form.Font

"logic-lecteurs-bandeau : $Wt ; $nFn fonctions reelles, $($stateParts.Count) affectations d etat, $($st510.Count) instructions du bandeau, $nCtl controles jamais affiches ; PowerShell $($PSVersionTable.PSVersion)$(if ($Before) { ' ; source d avant fournie (-Before)' })"

# ================================================================ H. harnais
'--- H. harnais'
Chk 'H1' ($missing.Count -eq 0 -and $stateMissing.Count -eq 0 -and $st510.Count -ge 20 -and $st520.Count -eq 1 -and $st540.Count -eq 2 -and $cardDrives -and $lblDrive -and $lblCom -and -not $form.Visible) "fonctions, etat et instructions reels trouves (absents : $(@($missing + $stateMissing) -join ', ')) ; bandeau, carte et libelles nommes crees, fenetre jamais affichee"
Chk 'H2' ($nCtlDrive1 -eq $nCtlDrive0 + 1 -and $pnlTop.Width -eq 800 -and $cmbDrive.Items.Count -eq 6 -and $script:CalibCalc -eq '12.10' -and $script:ContentCalc -eq '12.9') "liste du bandeau liee au reglage drive par Register-SettingCtl (une liaison de plus que l etat de 040 : $nCtlDrive0 -> $nCtlDrive1) ; bandeau de $($pnlTop.Width) px ; CalibCalc $($script:CalibCalc), ContentCalc $($script:ContentCalc) inchanges"

# ================================================================ U. bandeau, registre vide : 12.10 au pixel pres
'--- U. bandeau et textes courts'
# Positions de la 12.10 dans 510 (repere de 790 px, 510:8-47 de la 12.10, specification § 6.1) : litteraux de la source
$ban1210 = [ordered]@{ lblGwStatus = @("New-BannerLabel '' '556,10'"); lblDrive = @("New-BannerLabel (T 'Lecteur :') '500,37'"); cmbDrive = @("`$cmbDrive.Location = '556,34'", "`$cmbDrive.Width = 45"); lblCom = @("New-BannerLabel (T 'COM :') '612,37'")
             txtDev = @("`$txtDev.Location = '652,34'", "`$txtDev.Width = 50"); chkTime = @("`$chkTime.Location = '712,35'", "`$chkTime.Width = 70"); chkExpert = @("`$chkExpert.Location = '404,5'"); btnHelpTop = @("`$btnHelpTop.Location = '404,28'", "`$btnHelpTop.Size = '84,34'") }
$lit = @(); $all510 = ($st510 -join "`n"); foreach ($k in @($ban1210.Keys)) { foreach ($x in @($ban1210[$k])) { if (-not $all510.Contains([string]$x)) { $lit += "$k ($x)" } } }
function Get-LbBannerPos {
    $o = [ordered]@{}
    $o.lblGwStatus = "$($lblGwStatus.Left),$($lblGwStatus.Top)"; $o.lblDrive = "$($lblDrive.Left),$($lblDrive.Top)"
    $o.cmbDrive = "$($cmbDrive.Left),$($cmbDrive.Top) w$($cmbDrive.Width)"; $o.lblCom = "$($lblCom.Left),$($lblCom.Top)"
    $o.txtDev = "$($txtDev.Left),$($txtDev.Top) w$($txtDev.Width)"; $o.chkTime = "$($chkTime.Left),$($chkTime.Top) w$($chkTime.Width)"
    $o.chkExpert = "$($chkExpert.Left),$($chkExpert.Top)"; $o.btnHelpTop = "$($btnHelpTop.Left),$($btnHelpTop.Top) w$($btnHelpTop.Width)"
    return $o
}
function Get-LbPosText($o) { return (@($o.Keys | ForEach-Object { "$_ $($o[$_])" }) -join ' ; ') }
$tip1210 = (T "A/B = bus IBM-PC (nappe avec twist) - typiquement le lecteur PC`n0 à 3 = bus Shugart (nappe droite) - typiquement le lecteur Amiga`nAu démarrage, l'application sélectionne le premier lecteur qui répond.")
$pos0 = Get-LbBannerPos
$tip0 = [string]$tip.GetToolTip($cmbDrive)
$mov = @($pnlTop.Controls | Where-Object { $_.Left -lt 400 -or $_.Top -lt 0 }).Count
Chk 'U0' ($lit.Count -eq 0 -and $pos0.cmbDrive -ceq '566,34 w45' -and $pos0.lblDrive -ceq '510,37' -and $pos0.lblCom -ceq '622,37' -and $pos0.txtDev -ceq '662,34 w50' -and $mov -eq 0 -and $lblDrive.Text -ceq 'Lecteur :' -and $lblCom.Text -ceq 'COM :' -and $tip0 -ceq $tip1210 -and (Get-LbItems) -ceq 'A,B,0,1,2,3' -and $cmbDrive.Enabled -and $null -eq $script:DriveBanner) "registre vide : positions et tailles du bandeau donnees par les litteraux de la 12.10 (510:8-47 ; absents : $($lit -join ', ')), instructions reelles executees dans une fenetre de 800 px puis Fit-ControlText (+10 px, « Chrono » et « Mode expert » ajustes a leur texte comme en 12.10) : $(Get-LbPosText $pos0) ; libelles « Lecteur : » et « COM : », infobulle de la 12.10, six elements, aucune fonction de disposition appelee"
Reset-LbWorld 'u'
Set-LbTwoOnA
Select-LbDrive 'Sony MPF920'
$posW = Get-LbBannerPos
$lblA = [string]$lblDrive.Text; $pwA = $lblDrive.PreferredWidth
Select-LbDrive 'TEAC FD-235HF'
$lblT = [string]$lblDrive.Text; $posT = Get-LbBannerPos
Select-LbDrive 'A'
$lblM = [string]$lblDrive.Text; $posM = Get-LbBannerPos
$tipW = [string]$tip.GetToolTip($cmbDrive)
$tipWant = $tip1210 + "`n`n" + ((T "Lecteurs enregistrés : {0}.`nLeurs calibrations sont rangées sous leur nom, quelle que soit leur connexion. L'application ne reconnaît pas le lecteur branché : choisissez-le ici chaque fois que vous en changez (pour les nommer : Accueil, « Lecteurs enregistrés »).") -f 'Sony MPF920 (A), TEAC FD-235HF (A)')
Chk 'U1a' ($lblA -ceq 'Lecteur (A) :' -and $lblT -ceq 'Lecteur (A) :' -and $lblM -ceq 'Lecteur :' -and $cmbDrive.Width -eq 150 -and $posW.cmbDrive -ceq '541,34 w150' -and $posW.lblCom -ceq '702,37' -and $posW.txtDev -ceq '742,34 w50' -and $posW.chkTime -ceq ($pos0.chkTime -replace ',35 ', ',8 ') -and $posW.btnHelpTop -ceq '368,28 w84' -and $posW.chkExpert -ceq '368,5' -and $posW.lblDrive -ceq "$(541 - $pwA),37" -and $posW.lblGwStatus -ceq '566,10' -and $posW.btnHelpTop -ceq $posT.btnHelpTop -and $posW.btnHelpTop -ceq $posM.btnHelpTop -and $tipW -ceq $tipWant) "disposition elargie (maquette approuvee) : liste de 150 px en 541, « COM : » 702, champ 742, « Chrono » remonte en 722,8, etat de gw inchange ; libelle « Lecteur (A) : » pour un lecteur enregistre, « Lecteur : » pour A non enregistre ; « Aide » a la meme place quel que soit le lecteur ; infobulle de la 12.10 suivie des lecteurs : $(Get-LbPosText $posW)"
# Disposition mesuree en francais et en anglais (instructions reelles de 510 dans une portee d essai), nom le plus large admis
function Get-LbSubRight {
    $bmp = New-Object System.Drawing.Bitmap(10, 10); $g = [System.Drawing.Graphics]::FromImage($bmp)
    try { $f9 = New-Object System.Drawing.Font('Segoe UI', 9); return (70 + [int][math]::Ceiling($g.MeasureString((T 'Préservation, écriture et contrôle de disquettes'), $f9).Width)) } finally { $g.Dispose(); $bmp.Dispose() }
}
function Test-LbBanner([string]$lang) {
    # Bandeau de 510 refait dans la langue $lang (portee d essai : les controles et la liaison du script ne changent pas),
    # deux lecteurs enregistres sur A et 0 (dont le nom le plus large admis) ; defauts de la disposition elargie
    $script:Lang = $lang
    $res = @{ Bad = @(); Back = ''; Gap = 0 }
    $saveReg = $script:DriveReg; $saveLast = $script:DriveLast; $saveSet = Get-Setting 'drive'; $saveBan = $script:DriveBanner
    try {
        & {
            function Register-SettingCtl([string]$k, $c) { }
            . $genBan
            $fx = New-Object System.Windows.Forms.Form; $fx.ClientSize = New-Object System.Drawing.Size(800, 682); $fx.Font = $form.Font
            $fx.Controls.Add($pnlTop); Fit-ControlText $fx
            $p1210 = Get-LbBannerPos
            $script:DriveReg = [ordered]@{}
            $script:DriveReg['Sony MPF920'] = @{ Name = 'Sony MPF920'; Conn = 'A'; Id = 'L20261120180211-01'; Created = '2026-11-20 18:02:11'; From = ''; At = '' }
            $script:DriveReg[$wide] = @{ Name = $wide; Conn = '0'; Id = 'L20261120180211-02'; Created = '2026-11-20 18:02:11'; From = ''; At = '' }
            $script:DriveLast = @{}
            Update-DriveList $wide
            $sub = Get-LbSubRight
            $ctl = @($lblGwStatus, $chkExpert, $btnHelpTop, $lblDrive, $cmbDrive, $lblCom, $txtDev, $chkTime)
            $nm = @('lblGwStatus', 'chkExpert', 'btnHelpTop', 'lblDrive', 'cmbDrive', 'lblCom', 'txtDev', 'chkTime')
            $left = 9999; foreach ($c in $ctl) { if ($c.Left -lt $left) { $left = $c.Left } }
            $res.Gap = $left - $sub
            if ($res.Gap -lt 12) { $res.Bad += "controle a $left px, fin du sous-titre a $sub px" }
            for ($i = 0; $i -lt $ctl.Count; $i++) {
                if ($ctl[$i].Right -gt $pnlTop.Width - 2) { $res.Bad += "$($nm[$i]) depasse a droite" }
                for ($j = $i + 1; $j -lt $ctl.Count; $j++) {
                    $a = $ctl[$i]; $b = $ctl[$j]
                    if (-not $a.Bounds.IntersectsWith($b.Bounds)) { continue }
                    $ix = [System.Drawing.Rectangle]::Intersect($a.Bounds, $b.Bounds)
                    if (($a -is [System.Windows.Forms.Label] -or $b -is [System.Windows.Forms.Label]) -and $ix.Width -le 8) { continue }
                    $res.Bad += "chevauchement $($nm[$i]) / $($nm[$j])"
                }
            }
            if ((W $wide) + 24 -gt $cmbDrive.Width) { $res.Bad += "nom le plus large ($(W $wide) px) coupe dans la liste de $($cmbDrive.Width) px" }
            if ($lblDrive.Text -cne ((T 'Lecteur ({0}) :') -f '0')) { $res.Bad += "libelle : $($lblDrive.Text)" }
            foreach ($c in @($chkExpert, $lblDrive, $lblCom)) { if ($c.PreferredSize.Width -gt $c.Width) { $res.Bad += "texte coupe : $($c.Text)" } }
            $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}
            Update-DriveList
            $res.Back = ((Get-LbPosText (Get-LbBannerPos)) -ceq (Get-LbPosText $p1210)) -and ($lblDrive.Text -ceq (T 'Lecteur :')) -and ($cmbDrive.Items.Count -eq 6)
            $fx.Dispose()
        } | Out-Null
    } finally { $script:Lang = 'fr'; $script:DriveReg = $saveReg; $script:DriveLast = $saveLast; $script:DriveBanner = $saveBan; Set-Setting 'drive' $saveSet }
    return $res
}
Reset-LbWorld 'u1b'
$ubFr = Test-LbBanner 'fr'; $ubEn = Test-LbBanner 'en'
Chk 'U1b' ($ubFr.Bad.Count -eq 0 -and $ubEn.Bad.Count -eq 0 -and $ubFr.Back -and $ubEn.Back) "disposition elargie mesuree en francais et en anglais, nom le plus large admis « $wide » ($(W $wide) px) sur 0 : aucun chevauchement, rien sur le sous-titre du bandeau (marge $($ubFr.Gap) / $($ubEn.Gap) px), nom entier dans la liste, aucun libelle coupe ; registre vide de nouveau : positions et libelle de la 12.10 ; defauts : $(@($ubFr.Bad + $ubEn.Bad) -join ' ; ')"
# Retour a la 12.10 dans le bandeau du script : registre vide de nouveau, positions et infobulle de depart
Reset-LbWorld 'u2'
$pos2 = Get-LbBannerPos
Chk 'U1c' ((Get-LbPosText $pos2) -ceq (Get-LbPosText $pos0) -and [string]$tip.GetToolTip($cmbDrive) -ceq $tip1210 -and $lblDrive.Text -ceq 'Lecteur :' -and (Get-LbItems) -ceq 'A,B,0,1,2,3') "dernier lecteur retire : bandeau, libelle, infobulle et liste de la 12.10, au pixel pres"
# U2 : textes courts de la ligne d etat (lblWCal, 439 px) et du libelle de la restauration (290 px), deux noms les plus
# larges admis, francais et anglais ; texte d etat de la fenetre « Lecteurs enregistres »
$wide2 = $wide
$u2 = @()
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    $t72 = (T '{0} → {1} : déplacez la disquette') -f $wide, $wide2
    $t73 = (T '{0} : contrôle de surface, décision demandée') -f $wide
    $t74 = (T '{0}  (bandeau)') -f ($wide + ' (A)')
    if ((W $t72) -gt 439) { $u2 += "$lg T72 $(W $t72) px" }
    if ((W $t73) -gt 439) { $u2 += "$lg T73 $(W $t73) px" }
    if ((W $t74) -gt 290) { $u2 += "$lg T74 $(W $t74) px" }
}
$script:Lang = 'fr'
# Liste « Lecteur cible » de l onglet Ecriture (520) : 150 px, le nom le plus large admis y tient (126 px + 24)
$s520w = [System.IO.File]::ReadAllText((Get-LbModule $mods '520'), [System.Text.Encoding]::UTF8)
if (-not $s520w.Contains("`$cmbWTarget.Width = 150") -or (W $wide) + 24 -gt 150) { $u2 += "liste Lecteur cible : $(W $wide) px + 24 pour 150" }
Chk 'U2a' ($u2.Count -eq 0) "ligne d etat de l echange et du controle de surface (T72, T73) : 439 px au plus, libelle de la restauration (T74) : 290 px au plus, avec les noms les plus larges admis, en francais et en anglais ; nom le plus large ($(W $wide) px) entier dans la liste « Lecteur cible » de 150 px ; depassements : $(if ($u2.Count) { $u2 -join ' ; ' } else { 'aucun' })"
function Test-LbDialog([string]$lang) {
    # Fenetre « Lecteurs enregistres » construite sans etre affichee (vraie New-DrivesDialog) dans la langue $lang : texte
    # d etat sur deux lignes au plus pour T17, T33 et T34, tous ses textes les plus longs entiers ; controles entiers
    $script:Lang = $lang
    $o = @{ Bad = @(); H = 0; H2 = 0 }
    try {
        $s = New-DrivesDialog
        $st = $s.State
        $st.Text = "a`nb"; $o.H2 = $st.GetPreferredSize((New-Object System.Drawing.Size($st.Width, 0))).Height
        $o.H = $st.Height
        $smp = @(Get-DrivesStateSamples $st.Font)
        for ($i = 0; $i -lt $smp.Count; $i++) {
            $st.Text = [string]$smp[$i]; $h = $st.GetPreferredSize((New-Object System.Drawing.Size($st.Width, 0))).Height
            if ($h -gt $st.Height) { $o.Bad += "texte d etat coupe ($h > $($st.Height)) : $($smp[$i].Substring(0, 30))" }
            if ($i -lt 3 -and $h -gt $o.H2) { $o.Bad += "texte d etat sur plus de deux lignes ($h > $($o.H2)) : $($smp[$i].Substring(0, 30))" }
        }
        foreach ($b in @($s.New, $s.Del, $s.Save, $s.Close)) { $pw = $b.GetPreferredSize([System.Drawing.Size]::Empty).Width; if ($pw -gt $b.Width) { $o.Bad += "bouton $($b.Name) etroit ($pw > $($b.Width))" } }
        if ($s.Del.Right + 8 -gt $s.Save.Left) { $o.Bad += 'boutons de gauche et de droite trop proches' }
        $tot = 0; foreach ($cl in $s.Lv.Columns) { $tot += $cl.Width }
        if ($tot -gt $s.Lv.Width - 4 - [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth) { $o.Bad += "colonnes $tot px" }
        foreach ($c in @($s.Dlg.Controls)) { if ($c.Right -gt $s.Dlg.ClientSize.Width - 16) { $o.Bad += "$($c.Name) depasse a droite" } }
        foreach ($cl in $s.Lv.Columns) { if ((W ([string]$cl.Text)) + 6 -gt $cl.Width) { $o.Bad += "en-tete $($cl.Text) coupe" } }
        if ($s.Lv.Columns[0].Width -lt (W $wide) + 6) { $o.Bad += 'nom le plus large coupe dans la colonne Lecteur' }
        if ($s.Lv.Columns[2].Width -lt (W ((T '{0} courbe(s) dont {1} croisée(s), dernière : {2}') -f '99', '99', '30/10/2026 09:00')) + 6) { $o.Bad += 'colonne Calibrations coupee' }
        $o.Name = $s.Dlg.Name; $o.Visible = $s.Dlg.Visible; $o.Accept = $s.Dlg.AcceptButton; $o.Cancel = [object]::ReferenceEquals($s.Dlg.CancelButton, $s.Close)
        $o.Len = $s.Name.MaxLength
        Clear-DlgGdi $s.Dlg $s.Gdi
        $script:DrvDlg = $null
    } finally { $script:Lang = 'fr' }
    return $o
}
Reset-LbWorld 'u2b'
$dFr = Test-LbDialog 'fr'; $dEn = Test-LbDialog 'en'
Chk 'U2b' ($dFr.Bad.Count -eq 0 -and $dEn.Bad.Count -eq 0 -and $dFr.H -ge $dFr.H2 -and $dFr.Name -ceq 'frmDrives' -and -not $dFr.Visible -and $null -eq $dFr.Accept -and $dFr.Cancel -and $dFr.Len -eq 24) "fenetre frmDrives construite sans etre affichee, en francais et en anglais : texte d etat de $($dFr.H) px (deux lignes : $($dFr.H2) px), T17, T33 et T34 sur deux lignes au plus, aucun texte d etat ni bouton coupe, colonnes sans barre horizontale, aucun AcceptButton, « Fermer » en CancelButton, nom de 24 caracteres au plus ; defauts : $(@($dFr.Bad + $dEn.Bad) -join ' ; ')"

# ================================================================ D. liste, reglage, gestionnaire du bandeau
'--- D. liste du bandeau et reglage drive'
Reset-LbWorld 'd1'
Set-LbTwoOnA
Select-LbDrive 'Sony MPF920'; $vS = Get-LbView
Select-LbDrive 'TEAC FD-235HF'; $vT = Get-LbView
Chk 'D1' ($vS -ceq 'std=0=20:40=60' -and $vT -ceq '' -and $script:PrecompStd -ceq $script:PrecompStdDefault -and (Get-LbItems) -ceq 'A,B,0,1,2,3,Sony MPF920,TEAC FD-235HF') "deux lecteurs sur A, un seul calibre : vue du Sony « $vS », vue du TEAC vide, profil d origine ; liste : six connexions puis les noms ($(Get-LbItems))"
Reset-LbWorld 'd2'
Set-LbTwoOnA
Select-LbDrive 'Sony MPF920'
[void](Set-TargetDrive 'Sony MPF920' '0')
$script:DriveActivity = @{ '|A' = @{ Start = 1; End = 2 }; 'COM7|A' = @{ Start = 1; End = 2 }; '|0' = @{ Start = 1; End = 2 } }
$script:Log.Clear()
Select-LbDrive 'TEAC FD-235HF'
$d2Log = @(Get-LbLog 'Lecteur choisi*')
$d2Act = (@($script:DriveActivity.Keys | Sort-Object) -join ',')
$d2Tgt = "$($cmbWTarget.Text)/$((@($cmbWTarget.Items | ForEach-Object { [string]$_ })) -join ',')"
$d2Last = [string]$script:DriveLast['A']
Select-LbDrive '0'
$d2Act2 = (@($script:DriveActivity.Keys | Sort-Object) -join ',')
Chk 'D2' ($d2Log.Count -eq 1 -and $d2Log[0] -ceq 'Lecteur choisi : TEAC FD-235HF (A) (avant : Sony MPF920 (A)).' -and $d2Act -ceq '|0' -and $d2Last -ceq 'TEAC FD-235HF' -and $d2Tgt -ceq '(même lecteur)/(même lecteur),A,B,0,1,2,3,Sony MPF920' -and $lblDrive.Text -ceq 'Lecteur :' -and $d2Act2 -ceq '|0' -and [string](Get-Setting 'drive') -ceq '0') "passage de Sony a TEAC sur A : ligne « $($d2Log -join ' | ') », activite du prechauffage de A oubliee (reste : $d2Act), dernier lecteur de A : $d2Last, liste « Lecteur cible » du TEAC ($d2Tgt) ; passage a 0 : activite de 0 gardee ($d2Act2), reglage 0"
Reset-LbWorld 'd3'
Set-LbTwoOnA
$d3 = @(); foreach ($it in @($cmbDrive.Items)) { Select-LbDrive ([string]$it); $d3 += "$it=$((Get-CommonArgs) -join ' ')" }
Chk 'D3' (($d3 -join ' ; ') -ceq 'A=--drive=A ; B=--drive=B ; 0=--drive=0 ; 1=--drive=1 ; 2=--drive=2 ; 3=--drive=3 ; Sony MPF920=--drive=A ; TEAC FD-235HF=--drive=A') "chaque element de la liste : --drive= une des six connexions, jamais un nom ($($d3 -join ' ; '))"
Reset-LbWorld 'd4'
Set-LbTwoOnA
[void](Add-LbDrive 'Mitsumi D359' '0')
Select-LbDrive 'Mitsumi D359'; Select-LbDrive 'Sony MPF920'
Set-Setting 'drive' '0'; $d4a = "$($cmbDrive.Text)/$(Get-Setting 'drive')"
Set-Setting 'drive' 'A'; $d4b = "$($cmbDrive.Text)/$(Get-Setting 'drive')"
Set-Setting 'drive' 'A'; $d4c = "$($cmbDrive.Text)/$(Get-Setting 'drive')"
Select-LbDrive 'Mitsumi D359'; $d4d = "$($cmbDrive.Text)/$(Get-Setting 'drive')"
Select-LbDrive 'TEAC FD-235HF'; $d4e = "$($cmbDrive.Text)/$(Get-Setting 'drive')"
Chk 'D4' ($d4a -ceq 'Mitsumi D359/0' -and $d4b -ceq 'Sony MPF920/A' -and $d4c -ceq 'Sony MPF920/A' -and $d4d -ceq 'Mitsumi D359/0' -and $d4e -ceq 'TEAC FD-235HF/A') "reglage 0 (fenetre de nettoyage) : lecteur retenu pour 0 ($d4a) ; retour a A : dernier lecteur de A ($d4b) ; liste deja sur la connexion : inchangee ($d4c) ; choix d un lecteur enregistre : reglage = sa connexion ($d4d, $d4e)"
# D5 : registre vide, sequence du cas ST1 du banc (bandeau B, nettoyage sur 1, Set-Defaults, Load-Config)
Reset-LbWorld 'd5'
Select-LbDrive 'B'; $d5a = [string](Get-Setting 'drive')
Set-Setting 'drive' '1'; $d5b = [string]$cmbDrive.Text
[void](Save-Config); $d5j = [string]((Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json).global.drive)
Reset-Settings; $d5c = "$(Get-Setting 'drive')/$($cmbDrive.Text)"
[void](Load-Config); $d5d = "$(Get-Setting 'drive')/$($cmbDrive.Text)"
$d5n = @($script:SettingCtl['drive']).Count
Chk 'D5' ($d5a -ceq 'B' -and $d5b -ceq '1' -and $d5j -ceq '1' -and $d5c -ceq 'A/A' -and $d5d -ceq '1/1' -and $d5n -eq $nCtlDrive1 -and $script:Log.Count -eq 0 -and (Get-LbItems) -ceq 'A,B,0,1,2,3') "registre vide, sequence ST1 : bandeau B -> reglage $d5a ; reglage 1 -> bandeau $d5b ; enregistre $d5j ; Reset-Settings $d5c ; Load-Config $d5d ; liaisons du reglage drive inchangees ($d5n) ; aucune ligne de journal"
# D6 : detection qui bascule de connexion
Reset-LbWorld 'd6'
Set-LbTwoOnA
[void](Add-LbDrive 'Mitsumi D359' '0')
Select-LbDrive 'Mitsumi D359'; Select-LbDrive 'Sony MPF920'
$script:Log.Clear()
function Set-SeqEnd { }
$script:Detect = @{ Found = @('0'); Cur = 'A'; Tried = @('A', '0'); Mode = 'auto' }
Complete-DriveDetect
$d6 = @(Get-LbLog 'Connexion 0 : lecteur retenu*')
Chk 'D6' ([string]$cmbDrive.Text -ceq 'Mitsumi D359' -and [string](Get-Setting 'drive') -ceq '0' -and $d6.Count -eq 1 -and $d6[0] -ceq 'Connexion 0 : lecteur retenu « Mitsumi D359 », le dernier choisi sur cette connexion. La détection ne reconnaît pas le lecteur branché : vérifiez la liste « Lecteur : » du bandeau.' -and (Test-DriveCheckDue)) "Complete-DriveDetect reelle, A ne repond pas, 0 repond : lecteur retenu de 0 ($($cmbDrive.Text)), reglage 0, ligne T56, confirmation due"
# D7 : lecteur du bandeau deplace de A vers 0, enregistre, puis instructions reelles de Load-Config
Reset-LbWorld 'd7'
Set-LbTwoOnA
Select-LbDrive 'Sony MPF920'; $script:DriveChecked = 'Sony MPF920'
$script:DriveActivity = @{ '|A' = @{ Start = 1; End = 2 }; '|0' = @{ Start = 1; End = 2 } }
$script:Log.Clear()
$p7 =Get-DriveEditPlan (Get-LbRow 'Sony MPF920') 'Sony MPF920' '0'
$r7 = Invoke-DriveEditPlan $p7
$d7a = @{ Kind = $p7.Kind; Ok = $r7.Ok; Banner = [string]$cmbDrive.Text; Set = [string](Get-Setting 'drive'); Args = ((Get-CommonArgs) -join ' '); Last = (@($script:DriveLast.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','); Due = (Test-DriveCheckDue); Checked = [string]$script:DriveChecked; Act = (@($script:DriveActivity.Keys | Sort-Object) -join ','); Lbl = [string]$lblDrive.Text; Log54 = @(Get-LbLog 'Lecteur choisi*').Count }
$cfg7 = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
# Demarrage suivant : memoire neuve, liste de six elements sur A (Set-Defaults), puis la vraie Load-Config
$script:DriveCurves = @{}; $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}; $script:TargetDrives = @{}; $script:DriveChecked = ''
Update-DriveList; Select-LbDrive 'A'; Reset-Settings; $script:DriveCur = 'A'; $script:Log.Clear()
[void](Load-Config)
$d7b = @{ Banner = [string]$cmbDrive.Text; Set = [string](Get-Setting 'drive'); View = (Get-LbView); ForA = (Get-DriveForConn 'A'); Log54 = @(Get-LbLog 'Lecteur choisi*').Count; Items = (Get-LbItems); Lbl = [string]$lblDrive.Text }
Chk 'D7a' ($d7a.Kind -ceq 'move' -and $d7a.Ok -and $d7a.Banner -ceq 'Sony MPF920' -and $d7a.Set -ceq '0' -and $d7a.Args -ceq '--drive=0' -and $d7a.Last -ceq '0=Sony MPF920' -and $d7a.Due -and $d7a.Checked -ceq '' -and $d7a.Act -ceq '|A' -and $d7a.Lbl -ceq 'Lecteur (0) :' -and $d7a.Log54 -eq 0 -and [string]$cfg7.global.drive -ceq '0') "lecteur du bandeau deplace sur 0 par Invoke-DriveEditPlan ($($d7a.Kind), $($d7a.Ok), bandeau $($d7a.Banner), confirme « $($d7a.Checked) », due $($d7a.Due)) : reglage $($d7a.Set) (global.drive enregistre : $($cfg7.global.drive)), $($d7a.Args), dernier lecteur $($d7a.Last), confirmation de nouveau due, activite de 0 oubliee (reste : $($d7a.Act)), libelle « $($d7a.Lbl) », aucune ligne « Lecteur choisi »"
Chk 'D7b' ($d7b.Banner -ceq 'Sony MPF920' -and $d7b.Set -ceq '0' -and $d7b.View -ceq 'std=0=20:40=60' -and $d7b.ForA -ceq 'A' -and $d7b.Log54 -eq 0 -and $d7b.Items -ceq 'A,B,0,1,2,3,Sony MPF920,TEAC FD-235HF' -and $d7b.Lbl -ceq 'Lecteur (0) :') "apres rechargement par la vraie Load-Config : bandeau sur $($d7b.Banner) (reglage $($d7b.Set)), vue = ses courbes ($($d7b.View)), Get-DriveForConn 'A' rend $($d7b.ForA), aucune ligne « Lecteur choisi »"
# D8 : global.drive A et last.A ecrit avec une autre casse que la fiche
Reset-LbWorld 'd8'
Set-DriveCurve 'Sony MPF920' 'std' (New-Cv 'Sony MPF920' 'std' $null '30/10/2026 09:00' '0=31:40=71')
$j8 = [ordered]@{
    global = [ordered]@{ drive = 'A' }
    write = [ordered]@{ eraseMode = 'hfreq'; contentCalc = '12.9'; calibCalc = [string]$script:CalibCalc; driveCurves = (Export-DriveCurves $null) }
    drives = [ordered]@{ list = @([ordered]@{ id = 'L20261120180211-01'; name = 'Sony MPF920'; conn = 'A'; created = '2026-11-20 18:02:11'; from = ''; at = '' }); last = [ordered]@{ A = 'sony mpf920' } }
}
[System.IO.File]::WriteAllText($script:ConfigFile, ($j8 | ConvertTo-Json -Depth 8), $utf8)
$script:DriveCurves = @{}; Sync-PrecompCurves; $script:Log.Clear()
[void](Load-Config)
Chk 'D8' ([string]$cmbDrive.Text -ceq 'Sony MPF920' -and [string]$script:DriveLast['A'] -ceq 'Sony MPF920' -and (Get-LbView) -ceq 'std=0=31:40=71' -and @(Get-LbLog 'Lecteur choisi*').Count -eq 0 -and $script:DriveCur -ceq 'Sony MPF920' -and $lblDrive.Text -ceq 'Lecteur (A) :') "global.drive A et last.A « sony mpf920 » : bandeau sur « $($cmbDrive.Text) » (casse de la fiche), vue $(Get-LbView), aucune ligne « Lecteur choisi »"
# D9 : en-tete du journal exporte (lot L6), deux lecteurs sur A
Reset-LbWorld 'd9'
$h0 = Get-LogExportHeader
Set-LbTwoOnA
Select-LbDrive 'Sony MPF920'; $hS = Get-LogExportHeader
Select-LbDrive 'TEAC FD-235HF'; [void](Set-TargetDrive 'TEAC FD-235HF' 'Sony MPF920'); $hT = Get-LogExportHeader
Chk 'D9' ([string]$h0[1] -ceq 'Lecteur du bandeau : A ; lecteur cible de ses écritures : (même lecteur).' -and [string]$hS[1] -ceq 'Lecteur du bandeau : Sony MPF920 (A) ; lecteur cible de ses écritures : (même lecteur).' -and [string]$hT[1] -ceq 'Lecteur du bandeau : TEAC FD-235HF (A) ; lecteur cible de ses écritures : Sony MPF920 (A).' -and $hS[1] -cne $hT[1]) "en-tete : registre vide « $($h0[1]) » ; deux lecteurs sur A : « $($hS[1]) » / « $($hT[1]) »"

# ================================================================ K. lecteur a confirmer, confirmation
'--- K. confirmation du lecteur branche'
Reset-LbWorld 'k1'
$k1 = [ordered]@{}
$k1.Vide = Test-DriveCheckDue
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60'); Sync-PrecompCurves
[void](Add-LbDrive 'Sony MPF920' 'A' 'A')
Select-LbDrive 'Sony MPF920'
$k1.Un = Test-DriveCheckDue
[void](Add-LbDrive 'TEAC FD-235HF' 'A')
Select-LbDrive 'TEAC FD-235HF'; Select-LbDrive 'Sony MPF920'
$k1.Code = Test-DriveCheckDue
# Choix a la main dans la liste deroulee, dans les deux ordres d evenements
Select-LbDrive 'TEAC FD-235HF'; Set-DriveHandChoice $true
$k1.Main1 = Test-DriveCheckDue
Set-DriveHandChoice $true; $script:DriveCur = 'x'; Update-DriveChoice
$k1.Main2 = Test-DriveCheckDue
# Liste fermee : molette, fleches ou lettre (SelectionChangeCommitted reel, DroppedDown faux sans poignee)
Select-LbDrive 'Sony MPF920'
[System.Windows.Forms.ComboBox].GetMethod('OnSelectionChangeCommitted', [System.Reflection.BindingFlags]'Instance,NonPublic').Invoke($cmbDrive, @([System.EventArgs]::Empty)) | Out-Null
$k1.Ferme = Test-DriveCheckDue
Set-DriveHandChoice $false
$k1.Ferme2 = Test-DriveCheckDue
# Lecteur confirme, renomme ; lecteur confirme, supprime puis recree sous le meme nom
$script:DriveChecked = 'Sony MPF920'
$k1.Conf = Test-DriveCheckDue
$rn = Rename-NamedDrive 'Sony MPF920' 'Sony MPF-920'
$k1.RenVide = ([string]$script:DriveChecked -ceq '')
Update-DriveList
$k1.Ren = Test-DriveCheckDue
Select-LbDrive 'TEAC FD-235HF'; $script:DriveChecked = 'TEAC FD-235HF'
$rm = Remove-NamedDrive 'TEAC FD-235HF'
$k1.SupprVide = ([string]$script:DriveChecked -ceq '')
[void](Add-LbDrive 'TEAC FD-235HF' 'A')
$k1.Recree = ([string]$cmbDrive.Text -ceq 'TEAC FD-235HF' -and (Test-DriveCheckDue))
# Lecteur non enregistre de A avec des donnees, et un lecteur enregistre sur A
Reset-LbWorld 'k1b'
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60'); Sync-PrecompCurves
[void](Add-LbDrive 'TEAC FD-235HF' 'A')
$k1.NonEnr = Test-DriveCheckDue
# Un seul lecteur sur A, registre relu dans la copie de secours
Reset-LbWorld 'k1c'
[void](Add-LbDrive 'Sony MPF920' 'A'); Select-LbDrive 'Sony MPF920'
$k1.UnSeul = Test-DriveCheckDue
$script:DriveRescued = $true
$k1.Secours = Test-DriveCheckDue
$k1t = (@($k1.Keys | ForEach-Object { "$_=$($k1[$_])" }) -join ' ')
Chk 'K1' (-not $k1.Vide -and -not $k1.Un -and $k1.Code -and -not $k1.Main1 -and -not $k1.Main2 -and $k1.Ferme -and $k1.Ferme2 -and -not $k1.Conf -and $k1.RenVide -and $k1.Ren -and $k1.SupprVide -and $k1.Recree -and $k1.NonEnr -and -not $k1.UnSeul -and $k1.Secours -and $rn.Ok -and $rm.Ok) "confirmation due : jamais sans lecteur enregistre ; non avec un seul lecteur sur la connexion ; due apres un changement par le code ; non due apres un choix dans la liste deroulee (deux ordres d evenements) ; due apres la liste fermee (SelectionChangeCommitted reel, DroppedDown faux) ; due de nouveau apres un renommage, et pour un lecteur supprime puis recree sous le meme nom ; due avec le lecteur non enregistre de A qui a des donnees ; due avec un seul lecteur apres relecture de la copie de secours : $k1t"
# K2 : Confirm-DriveIdentity : refus, accord, textes
Reset-LbWorld 'k2'
Set-LbTwoOnA
Select-LbDrive 'TEAC FD-235HF'; Select-LbDrive 'Sony MPF920'
$script:AskAnswer = 'close'
$k2r = Confirm-DriveIdentity
$k2rLog = @(Get-LbLog 'Opération annulée : lecteur branché non confirmé.').Count
$ask1 = $script:Asks[0]
$script:AskAnswer = 'go'; $script:Asks.Clear()
$k2a = Confirm-DriveIdentity; $k2a2 = Confirm-DriveIdentity
$k2n = $script:Asks.Count
$txtWant = ((T "La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché.") -f 'A', 'Sony MPF920, TEAC FD-235HF') + "`n`n" + ((T "Lecteur choisi dans le bandeau : {0}`nSes calibrations : {1}`n`nL'écriture et la calibration emploient ses courbes et rangent leurs résultats sous son nom. Si un autre lecteur est branché, fermez cette fenêtre et choisissez-le dans la liste « Lecteur : » du bandeau : avec la courbe d'un autre lecteur, la disquette serait mal précompensée, sans aucun message d'erreur.") -f 'Sony MPF920 (A)', '1 courbe(s), dernière : 30/10/2026 09:00')
Select-LbDrive 'A'; $script:Asks.Clear()
$k2u = Confirm-DriveIdentity
$askU = $script:Asks[0]
Chk 'K2' (-not $k2r -and $k2rLog -eq 1 -and $ask1.Check -ceq 'Le lecteur branché sur la connexion A est bien « Sony MPF920 »' -and $ask1.Title -ceq 'Lecteur branché' -and $ask1.Heading -ceq 'Quel lecteur est branché sur la connexion A ?' -and $ask1.Level -ceq 'warn' -and $ask1.Text -ceq $txtWant -and $k2a -and $k2a2 -and $k2n -eq 1 -and $script:DriveChecked -ceq 'A' -and $k2u -and $askU.Check -ceq "Le lecteur branché sur la connexion A n'est aucun des lecteurs enregistrés" -and $askU.Text.Contains('Sony MPF920, TEAC FD-235HF, A (non enregistré)')) "refus : faux, ligne T68 ; accord : confirme, pas de seconde question ($k2n) ; case T53 « $($ask1.Check) », texte T50 + T52 (lecteurs de la connexion, calibrations du lecteur choisi) ; lecteur non enregistre : case T53b, liste « …, A (non enregistré) »"
# K3 : -Write : ligne « Lecteur qui ecrit » egale a Get-WriteSourceText
$script:Log.Clear(); Select-LbDrive 'TEAC FD-235HF'; Set-DriveHandChoice $true
$k3 = Confirm-DriveIdentity -Write
$k3l = @(Get-LbLog 'Lecteur qui écrit*')
Chk 'K3' ($k3 -and $k3l.Count -eq 1 -and $k3l[0] -ceq (Get-WriteSourceText) -and $k3l[0] -ceq 'Lecteur qui écrit : TEAC FD-235HF (A)' -and (Invoke-En { Get-WriteSourceText }) -ceq 'Writing drive: TEAC FD-235HF (A)') "-Write : « $($k3l -join ' | ') », texte de Get-WriteSourceText (anglais : « $(Invoke-En { Get-WriteSourceText }) »)"
# K4 : calibration croisee reelle (Start-CrossCalib) : lecteur cible dont la connexion porte deux lecteurs
function Invoke-LbCross([string]$pick) {
    # Start-CrossCalib reelle ; fenetre de choix, image, geometrie et calibration remplaces dans une portee d essai
    $o = @{ Targets = ''; Info = ''; Started = $false; Ask = $null; Res = $null }
    $script:LbCx = $null
    $o.Res = & {
        function Get-CalibEnvBlock { return $null }
        function Get-CalibSettingBlock { return '' }
        function Get-CalibImageCheck { return @{ Ok = $false } }
        function Get-CrossSwapEstimate { return @{ Min = 7; Max = 13 } }
        function Show-CrossCalibDialog { $script:LbDlgTargets = (@($args[1]) -join ','); $script:LbDlgInfo = [string]$args[4]; return @{ Ok = $true; Target = $pick; Family = 'std'; Fine = $false } }
        function Get-HomeCalibInfo { return @{ Label = 'x'; BitsSrc = '' } }
        function New-CalibGeometry { return 'geom.img' }
        function Get-ImageFamily { return 'std' }
        function Start-PrecompCalib { $script:LbCx = $script:CalCrossAsk }
        Start-CrossCalib
    }
    $o.Targets = [string]$script:LbDlgTargets; $o.Info = [string]$script:LbDlgInfo; $o.Cx = $script:LbCx
    return $o
}
Reset-LbWorld 'k4'
$script:CalCoarse = @(0, 1, 2); $script:CalMaxVerify = 2; $script:CalMaxRetest = 2
[void](Add-LbDrive 'Sony MPF920' 'A'); [void](Add-LbDrive 'TEAC FD-235HF' '0'); [void](Add-LbDrive 'Mitsumi D359' '0'); [void](Add-LbDrive 'Panasonic' 'A')
Select-LbDrive 'Sony MPF920'
$script:AskAnswer = 'close'; $script:Asks.Clear(); $script:Log.Clear()
$k4r = Invoke-LbCross 'TEAC FD-235HF'
$k4rAsk = $script:Asks.Count; $k4rCheck = if ($k4rAsk) { $script:Asks[0].Check } else { '' }; $k4rText = if ($k4rAsk) { $script:Asks[0].Text } else { '' }
$k4rLog = @(Get-LbLog 'Opération annulée : lecteur branché non confirmé.').Count
$script:AskAnswer = 'go'; $script:Asks.Clear()
$k4a = Invoke-LbCross 'TEAC FD-235HF'; $k4aAsk = $script:Asks.Count
$script:Asks.Clear()
$k4b = Invoke-LbCross 'TEAC FD-235HF'; $k4bAsk = $script:Asks.Count
$script:Asks.Clear()
$k4c = Invoke-LbCross 'B'; $k4cAsk = $script:Asks.Count
$k4Info = (T 'Non proposés, parce qu''ils sont sur la connexion {0} du lecteur qui écrit : {1}. Les deux lecteurs d''une calibration croisée sont branchés en même temps, chacun sur sa connexion.') -f 'A', 'A (non enregistré), Panasonic'
Chk 'K4' ($k4rAsk -eq 1 -and $k4rCheck -ceq 'Le lecteur branché sur la connexion 0 est bien « TEAC FD-235HF »' -and $k4rText.Contains('Lecteur cible de cette calibration croisée : TEAC FD-235HF (0)') -and $k4rText.Contains('écritures du lecteur Sony MPF920 (A)') -and $null -eq $k4r.Cx -and -not $k4r.Res.Started -and $k4rLog -eq 1 -and
          $k4aAsk -eq 1 -and $k4a.Cx -and [string]$k4a.Cx.Tgt -ceq 'TEAC FD-235HF' -and $k4bAsk -eq 1 -and $k4cAsk -eq 0 -and [string]$k4c.Cx.Tgt -ceq 'B' -and $k4a.Targets -ceq 'B,0,1,2,3,TEAC FD-235HF,Mitsumi D359' -and $k4a.Info.EndsWith("`n" + $k4Info)) "Start-CrossCalib reelle, Sony sur A : cibles proposees $($k4a.Targets) (A et Panasonic, sur A, ecartes ; texte T67 dans la fenetre de choix) ; TEAC sur 0, qui porte deux lecteurs : confirmation a case du lecteur cible ($k4rCheck), refus : demande non posee, ligne T68 ; accord : demande posee ; redemandee a la calibration suivante ($k4bAsk) ; cible B, un seul lecteur : jamais demandee"
# K5 : les cinq fonctions reelles qui engagent une operation sous l identite du lecteur
$imgDummy = Join-Path $here 'image.adf'; [System.IO.File]::WriteAllBytes($imgDummy, [byte[]]@(0, 1, 2))
$txtWFile.Text = $imgDummy
function Invoke-LbOp([string]$op) {
    # Lance la fonction reelle $op ; ce qui suit la confirmation est remplace par un releve (« atteint ») puis un arret
    $script:LbReached = $false
    try {
        & {
            function Test-TargetWriteAllowed { return $true }
            function Get-TargetWriteInfo { $script:LbReached = $true; throw 'LB-STOP' }
            function Test-CalibImage { $script:LbReached = $true; return $null }
            function Get-ContentMeasureMinutes { $script:LbReached = $true; throw 'LB-STOP' }
            switch ($op) {
                'write'   { Start-ImageWrite }
                'level'   { Start-LevelCalib @{ Family = 'std'; Units = @() } }
                'precomp' { Start-PrecompCalib }
                'content' { $script:AfterCalib = 'write'; Start-ContentMeasure @{ Drive = 'x'; Img = 'i'; Fam = 'std'; Plan = @{ Cyls = @(0, 1); NCylHead = @(1, 1) }; Levels = @(0.5) } }
                'restore' { Start-Restore }
            }
        }
    } catch { if ([string]$_.Exception.Message -notmatch 'LB-STOP') { throw } }
    if ($op -eq 'restore' -and @($script:Msgs | Where-Object { [string]$_.Text -like 'gw.exe introuvable*' }).Count -gt 0) { $script:LbReached = $true }
    return [bool]$script:LbReached
}
$k5 = @(); $k5txt = @()
foreach ($op in 'write', 'level', 'precomp', 'content', 'restore') {
    Reset-LbWorld "k5-$op"
    $script:Msgs.Clear(); $script:Asks.Clear()
    $e0 = Invoke-LbOp $op; $e0n = $script:Asks.Count; $e0l = $script:Log.Count
    Set-LbTwoOnA; Select-LbDrive 'TEAC FD-235HF'; Select-LbDrive 'Sony MPF920'
    $script:Asks.Clear(); $script:Msgs.Clear(); $script:Log.Clear(); $script:AskAnswer = 'close'
    $r1 = Invoke-LbOp $op; $r1n = $script:Asks.Count; $r1l = @(Get-LbLog 'Opération annulée : lecteur branché non confirmé.').Count
    $r1s = ($null -eq $script:Cal -and $null -eq $script:Restore -and $null -eq $script:CalCrossAsk -and ($op -ne 'content' -or $script:AfterCalib -eq ''))
    $script:AskAnswer = 'go'; $script:Asks.Clear(); $script:Msgs.Clear()
    $r2 = Invoke-LbOp $op; $r2n = $script:Asks.Count; $r2c = [string]$script:DriveChecked
    $script:Asks.Clear(); $script:Msgs.Clear()
    $r3 = Invoke-LbOp $op; $r3n = $script:Asks.Count
    Select-LbDrive 'TEAC FD-235HF'; Set-DriveHandChoice $true; $script:Asks.Clear(); $script:Msgs.Clear()
    $r4 = Invoke-LbOp $op; $r4n = $script:Asks.Count
    $w55 = if ($op -eq 'write') { @(Get-LbLog 'Lecteur qui écrit : *').Count -ge 1 } else { @(Get-LbLog 'Lecteur qui écrit : *').Count -eq 0 }
    $ok = ($e0 -and $e0n -eq 0 -and $e0l -eq 0 -and -not $r1 -and $r1n -eq 1 -and $r1l -eq 1 -and $r1s -and $r2 -and $r2n -eq 1 -and $r2c -ceq 'Sony MPF920' -and $r3 -and $r3n -eq 0 -and $r4 -and $r4n -eq 0 -and $w55)
    $k5 += $ok
    $k5txt += "$op : vide $e0/$e0n, refus $r1/$r1n/T68 $r1l, accord $r2/$r2n, suivante $r3/$r3n, liste deroulee $r4/$r4n"
    $id = @{ write = 'K5a'; level = 'K5b'; precomp = 'K5c'; content = 'K5d'; restore = 'K5e' }[$op]
    $fname = @{ write = 'Start-ImageWrite'; level = 'Start-LevelCalib'; precomp = 'Start-PrecompCalib'; content = 'Start-ContentMeasure'; restore = 'Start-Restore' }[$op]
    Chk $id $ok "$fname reelle : registre vide, aucune confirmation et operation atteinte ; deux lecteurs sur A, lecteur choisi par le code : confirmation a case, refus = operation non lancee (aucun etat cree, ligne T68), accord = lancee, lecteur confirme ; etape suivante sans seconde question ; apres un choix dans la liste deroulee, sans question$(if ($op -eq 'write') { ' ; ligne « Lecteur qui écrit » au journal' }) ($($k5txt[-1]))"
}

# ================================================================ L. verrou de la liste, molette
'--- L. verrou et molette'
Reset-LbWorld 'l1'
$l1 = @()
$reasons = [ordered]@{ restore = { $script:Restore = @{ Step = 1 } }; calib = { $script:Cal = @{ Mode = 'fine' } }; check = { $script:Rep = @{ X = 1 } }; warmup = { $script:WriteWarm = @{ X = 1 } }; detect = { $script:Detect = @{ X = 1 } }
             gw = { $script:GwProc = [pscustomobject]@{ HasExited = $false } }; chain = { $script:Chain.Enqueue({ 1 }) }; quality = { $script:AlignLoop = $true } }
foreach ($k in @($reasons.Keys)) {
    Reset-LbWorld 'l1'
    & $reasons[$k]
    $b = Get-AppBusy
    Update-DriveLock
    $l1 += "$k/$b=$($cmbDrive.Enabled)"
    Reset-LbWorld 'l1'; Update-DriveLock
}
$l1r = $cmbDrive.Enabled
Chk 'L1' (($l1 -join ',') -ceq 'restore/restore=False,calib/calib=False,check/check=False,warmup/warmup=False,detect/detect=False,gw/gw=False,chain/chain=False,quality/quality=True' -and $l1r) "Update-DriveLock : liste inactive pour chaque raison de Get-AppBusy sauf la pause d une mesure continue, active au repos, registre vide compris ($($l1 -join ', '))"
Set-LbTwoOnA; $script:Cal = @{ Mode = 'fine' }; Update-DriveLock; Select-LbDrive 'TEAC FD-235HF'
$l1c = "$($cmbDrive.Enabled)/$($cmbDrive.Text)"
$script:Cal = $null; Update-DriveLock
Chk 'L1b' ($l1c -ceq 'False/TEAC FD-235HF' -and $cmbDrive.Enabled) "avec des lecteurs enregistres, meme verrou ; un changement fait par le code reste possible ($l1c)"
# L2 : gestionnaire MouseWheel reel (510)
$ev = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, -120)
$sel0 = [string]$cmbDrive.Text
[System.Windows.Forms.Control].GetMethod('OnMouseWheel', [System.Reflection.BindingFlags]'Instance,NonPublic').Invoke($cmbDrive, [object[]]@([System.Windows.Forms.MouseEventArgs]$ev)) | Out-Null
$l2a = $ev.Handled
$l2a2 = ([string]$cmbDrive.Text -ceq $sel0)
# Liste deroulee (DroppedDown vrai, impossible sans l afficher) : corps reel des deux gestionnaires de 510, enveloppe dans
# une fonction de travail ($this et $_ poses comme WinForms les pose)
function Get-LbHandlerBody([string]$prefix) {
    foreach ($s in @($st510)) {
        if (-not $s.StartsWith($prefix)) { continue }
        $a = [System.Management.Automation.Language.Parser]::ParseInput($s, [ref]$null, [ref]$null)
        $sb = @($a.FindAll({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))[0]
        return [string]$sb.ScriptBlock.EndBlock.Extent.Text
    }
    return ''
}
$bodyW = Get-LbHandlerBody '$cmbDrive.Add_MouseWheel('
$bodyS = Get-LbHandlerBody '$cmbDrive.Add_SelectionChangeCommitted('
$genH = Join-Path $here 'gen-gestionnaires-510.ps1'
Write-LbGen $genH @(("function Invoke-LbWheel(`$o, `$e) {`r`n    `$this = `$o; `$_ = `$e`r`n    " + $bodyW + "`r`n}"), ("function Invoke-LbCommit(`$o) {`r`n    `$this = `$o`r`n    " + $bodyS + "`r`n}"))
. $genH
$evO = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, -120)
Invoke-LbWheel ([pscustomobject]@{ DroppedDown = $true }) $evO
$evC = New-Object System.Windows.Forms.HandledMouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 5, 5, 120)
Invoke-LbWheel ([pscustomobject]@{ DroppedDown = $false }) $evC
Chk 'L2' ($bodyW -and $l2a -and $l2a2 -and -not $evO.Handled -and $evC.Handled) "gestionnaire MouseWheel reel de 510 : liste fermee (evenement reel sur la liste du bandeau, sans poignee : DroppedDown faux), evenement marque traite, lecteur inchange ; liste deroulee, rien (la molette la fait defiler) ; registre vide : meme regle"
Reset-LbWorld 'l2'
Set-LbTwoOnA
Select-LbDrive 'TEAC FD-235HF'
Invoke-LbCommit ([pscustomobject]@{ DroppedDown = $true })
$l2c = [string]$script:DriveChecked
Select-LbDrive 'Sony MPF920'
Invoke-LbCommit ([pscustomobject]@{ DroppedDown = $false })
$l2d = [string]$script:DriveChecked
Chk 'L2b' ($bodyS.Contains('Set-DriveHandChoice $this.DroppedDown') -and $l2c -ceq 'TEAC FD-235HF' -and $l2d -ceq '' -and (Test-DriveCheckDue)) "gestionnaire SelectionChangeCommitted reel de 510 : liste deroulee, lecteur choisi tenu pour confirme ($l2c) ; liste fermee, rien (confirmation due)"

# ================================================================ P. fenetre « Lecteurs enregistres »
'--- P. fenetre : decision, execution, lignes, suppression, copies'
Reset-LbWorld 'p1'
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60')
Set-DriveCurve 'A>0' 'std' (New-Cv 'A' 'std' $null '05/11/2026 10:00' '0=25:40=65' '0')
Set-DriveCurve '0' 'std' (New-Cv '0' 'std' $null '02/11/2026 10:00' '0=23:40=63')
$script:TargetDrives['1'] = '2'
Sync-PrecompCurves
$p1 = [ordered]@{}
# Refus, rendus par la fonction qui decide (Test-DriveName, Edit-DriveData, Get-DriveEditRefusal)
$p1.vide = (Get-DriveEditPlan $null '  ' 'A').Error -ceq (T 'Donnez un nom au lecteur.')
$p1.code = (Get-DriveEditPlan $null 'b' 'A').Error -ceq ((T '« {0} » désigne une connexion : choisissez un autre nom.') -f 'b')
$p1.res = (Get-DriveEditPlan $null 'count' 'A').Error -ceq ((T '« {0} » est un mot réservé : choisissez un autre nom.') -f 'count')
$p1.car = (Get-DriveEditPlan $null 'A|B' 'A').Error -ceq ((T "Caractère non admis : « {0} ». Un nom se compose de lettres, de chiffres, d'espaces et des signes - . _ + # °") -f '|')
$p1.large = (Get-DriveEditPlan $null ($wide + 'W') 'A').Error -ceq (T "Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le.")
$p1.conn = (Get-DriveEditPlan $null 'Sony' '').Error -ceq (T 'Choisissez la connexion du lecteur.')
$script:Cal = @{ Mode = 'fine' }; $p1.busy = (Get-DriveEditPlan $null 'Sony' 'A').Error -ceq ((T 'Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.') -f (T 'calibration')); $script:Cal = $null
$script:CalRedo = @{ Stage = 'wait' }; $p1.redo = (Get-DriveEditPlan $null 'Sony' 'A').Error -ceq (T "Calibration B en cours ou en attente de décision : terminez-la d'abord."); $script:CalRedo = $null
# Nouveau lecteur : note de la connexion qui a des calibrations sans nom (T17), avant l enregistrement
$pn = Get-DriveEditPlan $null 'TEAC FD-235HF' 'A'
$p1.new = ($pn.Kind -ceq 'new' -and $pn.Ask -eq '' -and $pn.Note -ceq ((T 'La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (non enregistré) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.') -f 'A') -and $pn.Text -ceq 'Lecteur « TEAC FD-235HF » enregistré sur la connexion A, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.')
$p1.noNote = ((Get-DriveEditPlan $null 'TEAC FD-235HF' 'B').Note -ceq '')
# Fenetre construite sans etre affichee : « Enregistrer » du nouveau lecteur
$s = New-DrivesDialog
$s.Name.Text = 'TEAC FD-235HF'; $s.Conn.SelectedItem = 'A'
$script:Log.Clear()
$rN = Invoke-DrivesDialogSave $s
$p1.newDone = ($rN.Ok -and $s.State.Text -ceq $pn.Text -and @(Get-LbLog $pn.Text).Count -eq 1 -and (Test-DriveRegistered 'TEAC FD-235HF') -and (Get-LbItems) -ceq 'A,B,0,1,2,3,TEAC FD-235HF' -and [string]$cmbDrive.Text -ceq 'A' -and $script:Asks.Count -eq 0 -and (Get-LbBaks) -eq 0)
# Nommer A (courbes) : confirmation a case, copie, le bandeau passe au lecteur nomme
$rowA = Get-LbRow 'A'
$pa = Get-DriveEditPlan $rowA 'Sony MPF920' 'A'
$leaf = [System.IO.Path]::GetFileName($script:ConfigFile)
$p1.adoptPlan = ($pa.Kind -ceq 'adopt' -and $pa.Ask -ceq 'check' -and $pa.N -eq 2 -and $pa.AskCheck -ceq 'Les calibrations de la connexion A ont été faites avec le lecteur « Sony MPF920 »' -and $pa.AskGo -ceq 'Attribuer ces calibrations' -and $pa.AskHeading -ceq 'Attribuer à ce lecteur les calibrations de la connexion A ?' -and $pa.AskText.Contains('2 courbe(s) dont 1 croisée(s), dernière : 05/11/2026 10:00') -and $pa.AskText.Contains("« $leaf.lecteurs-….bak »"))
$script:AskAnswer = 'close'; $script:Asks.Clear()
$rowSel = 0; for ($i = 0; $i -lt @($s.Rows).Count; $i++) { if ([string]$s.Rows[$i].Drive -ceq 'A') { $rowSel = $i } }
Select-DrivesDialogRow $s $rowSel; Set-DrivesDialogInputs $s
$s.Name.Text = 'Sony MPF920'
$rRef = Invoke-DrivesDialogSave $s
$p1.adoptRefus = (-not $rRef.Ok -and $script:Asks.Count -eq 1 -and -not (Test-DriveRegistered 'Sony MPF920') -and (Get-LbBaks) -eq 0 -and (Get-DriveCurve 'A' 'std'))
$script:AskAnswer = 'go'; $script:Asks.Clear()
$script:CurveForm = [pscustomobject]@{ IsDisposed = $false; Closed = $false }
$script:CurveForm | Add-Member -MemberType ScriptMethod -Name Close -Value { $this.Closed = $true }
$rA = Invoke-DrivesDialogSave $s
$p1.adopt = ($rA.Ok -and $s.State.Text -ceq $pa.Text -and $pa.Text -ceq 'Lecteur « Sony MPF920 » enregistré sur la connexion A : les calibrations faites sans nom sur la connexion A (2 courbe(s)) sont maintenant les siennes.' -and $script:Asks[0].Check -ceq $pa.AskCheck -and $script:Asks[0].Text -ceq $pa.AskText -and (Get-LbBaks) -eq 1 -and [string]$cmbDrive.Text -ceq 'Sony MPF920' -and (Get-DriveCurve 'Sony MPF920' 'std') -and $script:CurveForm.Closed -and @(Get-LbLog 'Lecteur choisi*').Count -eq 0 -and [string]$script:DriveLast['A'] -ceq 'Sony MPF920')
# Nommer en changeant de connexion : lecteur non enregistre de 0 nomme Mitsumi D359 sur 1
$p0 = Get-DriveEditPlan (Get-LbRow '0') 'Mitsumi D359' '1'
$r0 = Invoke-DriveEditPlan $p0
$p1.adoptMove = ($p0.Kind -ceq 'adopt' -and $r0.Ok -and [string](Get-DriveConn 'Mitsumi D359') -ceq '1' -and (Get-DriveCurve 'Mitsumi D359' 'std') -and [string]$cmbDrive.Text -ceq 'Sony MPF920' -and [string](Get-Setting 'drive') -ceq 'A')
# Nommer sans courbe (lecteur cible seulement) : question simple T70, pas de case
$p2p = Get-DriveEditPlan (Get-LbRow '1') 'Lecteur X' '1'
$p1.yesno = ($p2p.Kind -ceq 'adopt' -and $p2p.Ask -ceq 'yesno' -and $p2p.AskText -ceq "Le lecteur non enregistré de la connexion 1 n'a aucune calibration. Son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés passent sous le nom « Lecteur X ». Continuer ?" -and -not $p2p.AskCheck)
$script:MsgAnswer = 'No'; $rY0 = Invoke-DriveEditPlan $p2p; $script:MsgAnswer = 'Yes'
$nb0 = Get-LbBaks
$rY1 = Invoke-DriveEditPlan $p2p
$p1.yesnoDone = (-not $rY0.Ok -and $rY1.Ok -and [string](Get-TargetDrive 'Lecteur X') -ceq '2' -and (Get-LbBaks) -eq $nb0 + 1)
# Fusion refusee : nommer B du nom d une fiche qui a des donnees
Set-DriveCurve 'B' 'std' (New-Cv 'B' 'std' $null '06/11/2026 10:00' '0=27:40=67')
$pf = Get-DriveEditPlan (Get-LbRow 'B') 'sony mpf920' 'B'
$p1.fusion = ($pf.Error -ceq ((T 'Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.') -f 'Sony MPF920', 'B'))
# Renommer, corriger la casse, deplacer, renommer et deplacer, rien a enregistrer
$rowS = Get-LbRow 'Sony MPF920'
$p1.none = ((Get-DriveEditPlan $rowS 'Sony MPF920' 'A').Error -ceq (T "Rien à enregistrer : le nom et la connexion n'ont pas changé.") -and (Get-DriveEditPlan $rowS 'Sony MPF920' 'A').Kind -ceq 'none')
$pc = Get-DriveEditPlan $rowS 'sony mpf920' 'A'
$p1.case = ($pc.Kind -ceq 'rename' -and -not $pc.Error)
$rc = Invoke-DriveEditPlan $pc
$p1.caseDone = ($rc.Ok -and [string]$cmbDrive.Text -ceq 'sony mpf920' -and (Get-LbItems) -ceq 'A,B,0,1,2,3,TEAC FD-235HF,sony mpf920,Mitsumi D359,Lecteur X' -and @(Get-LbLog 'Lecteur choisi*').Count -eq 0 -and $rc.Text -ceq "Lecteur « sony mpf920 » : il s'appelait « Sony MPF920 ». Ses calibrations (2 courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom.")
$pr = Get-DriveEditPlan (Get-LbRow 'sony mpf920') 'Sony MPF920' 'A'; [void](Invoke-DriveEditPlan $pr)
$prm = Get-DriveEditPlan (Get-LbRow 'TEAC FD-235HF') 'TEAC FD-235HF n°2' '0'
$rrm = Invoke-DriveEditPlan $prm
$p1.renMove = ($prm.Kind -ceq 'rename+move' -and $rrm.Ok -and @($prm.Log).Count -eq 2 -and $rrm.Text -ceq [string]$prm.Log[1] -and $rrm.Text -ceq 'Lecteur « TEAC FD-235HF n°2 » : connexion 0 (avant : A). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.' -and @(Get-LbLog ([string]$prm.Log[0])).Count -eq 1 -and @(Get-LbLog ([string]$prm.Log[1])).Count -eq 1 -and (Get-LbItems) -ceq 'A,B,0,1,2,3,TEAC FD-235HF n°2,Sony MPF920,Mitsumi D359,Lecteur X')
$p1t = (@($p1.Keys | Where-Object { -not $p1[$_] }) -join ', ')
Chk 'P1' ($p1t -eq '') "Get-DriveEditPlan et Invoke-DriveEditPlan : refus (vide, connexion, mot reserve, caractere, largeur, connexion non choisie, operation en cours, calibration B), nouveau lecteur (note T17 avant l enregistrement), nommer avec courbes (case T39, copie datee, bandeau qui suit sans ligne « Lecteur choisi », fenetre Courbe fermee), refus de la case (rien change), nommer en changeant de connexion, nommer sans courbe (question T70), fusion refusee, rien a enregistrer, correction de casse (rename), renommer et deplacer (deux lignes de journal, resultat affiche : le deplacement) ; texte affiche = plan execute ; en defaut : $(if ($p1t) { $p1t } else { 'aucun' })"
$t39 = (T 'Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »') -f 'A', $wide
$t39e = (Invoke-En { (T 'Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »') -f 'A', $wide })
Chk 'P1b' ((W $t39 $bold) -le 576 -and (W $t39e $bold) -le 576) "case T39 avec le nom le plus large admis, en gras : $(W $t39 $bold) px (anglais $(W $t39e $bold) px) pour les 576 px de la case de frmConfirm : une ligne, entiere"
# P2 : lignes de la fenetre
$rows = Get-DriveRows
$p2 = @($rows | ForEach-Object { "$($_.Kind):$($_.Text)|$($_.ConnText)|$($_.Cal)" }) -join ' ; '
$p2want = 'rec:TEAC FD-235HF n°2|0|aucune ; rec:Sony MPF920|A|2 courbe(s) dont 1 croisée(s), dernière : 05/11/2026 10:00 ; rec:Mitsumi D359|1|2 courbe(s) dont 1 croisée(s), dernière : 05/11/2026 10:00 ; rec:Lecteur X|1|aucune ; conn:B (non enregistré)|B|1 courbe(s), dernière : 06/11/2026 10:00 ; conn:2 (non enregistré)|2|aucune'
$script:DriveReg['Sans Conn'] = @{ Name = 'Sans Conn'; Conn = ''; Id = 'R20261120180211-09'; Created = '2026-11-20 18:02:11'; From = ''; At = '' }
$rowsX = Get-DriveRows
$px = @($rowsX | Where-Object { $_.Drive -ceq 'Sans Conn' })[0]
$cardTxt = Get-DrivesCardText
$script:DriveReg.Remove('Sans Conn')
Chk 'P2' ($p2 -ceq $p2want -and [string]$px.ConnText -ceq 'à préciser' -and $cardTxt -ceq '1 lecteur(s) sans connexion : redonnez-la ici pour retrouver leurs calibrations.' -and (Get-DrivesCardText) -ceq 'Nommer vos lecteurs : plusieurs sur une même connexion, chacun avec ses calibrations.') "Get-DriveRows : fiches dans l ordre du registre, puis lecteurs non enregistres qui ont des donnees ; colonnes « $p2 » ; fiche sans connexion « à préciser », carte de l Accueil qui la compte"
# P3 : suppression, « Retirer seulement le nom », textes de la confirmation
$dS = Get-DriveDeletePlan (Get-LbRow 'Sony MPF920')
$dM = Get-DriveDeletePlan (Get-LbRow 'Mitsumi D359')
$p3a = ($dS.Any -and $dS.Keep -and $dS.Alt -ceq 'Retirer seulement le nom' -and $dS.Go -ceq 'Supprimer avec ses calibrations' -and $dS.Check -ceq 'Le lecteur « Sony MPF920 » ne doit plus être enregistré' -and $dS.Check -notmatch 'calibrations|nom de lecteur' -and $dS.Text.EndsWith("`n`n« Retirer seulement le nom » : ses calibrations restent, rangées sous la connexion A, sans nom de lecteur."))
Set-DriveCurve '1' 'std' (New-Cv '1' 'std' $null '07/11/2026 10:00' '0=29:40=69')
$dM2 = Get-DriveDeletePlan (Get-LbRow 'Mitsumi D359')
$p3b = (-not $dM2.Keep -and -not $dM2.Alt -and -not $dM2.Text.Contains('Retirer seulement le nom'))
[void](Remove-NamedDrive 'Mitsumi D359'); Update-DriveList; $script:DriveCurves.Remove('1|std') | Out-Null
$script:AskAnswer = 'alt'; $script:Asks.Clear(); $script:Log.Clear()
Select-LbDrive 'Sony MPF920'
$rK = Remove-DriveEntry (Get-LbRow 'Sony MPF920')
$p3c = ($rK.Ok -and $script:Asks[0].Level -ceq 'danger' -and $script:Asks[0].AltText -ceq 'Retirer seulement le nom' -and $script:Asks[0].GoText -ceq 'Supprimer avec ses calibrations' -and $rK.Text -ceq 'Nom « Sony MPF920 » retiré : ses calibrations sont rangées sous la connexion A, sans nom de lecteur.' -and (Get-DriveCurve 'A' 'std') -and [string]$cmbDrive.Text -ceq 'A' -and -not (Test-DriveRegistered 'Sony MPF920'))
$script:AskAnswer = 'go'
Chk 'P3' ($p3a -and $p3b -and $p3c) "suppression : « Retirer seulement le nom » propose seulement quand le lecteur non enregistre de la connexion n a aucune donnee ; la case (T44) ne nomme aucune des deux issues, chaque bouton nomme la sienne (T45, T46) ; niveau danger ; retrait du nom : calibrations sous A, bandeau sur A ($p3a/$p3b/$p3c)"
# P4 : textes qui annoncent la copie (T38, T42) affiches si et seulement si la copie est faite
Reset-LbWorld 'p4'
[void](Add-LbDrive 'Cible Seule' 'A'); [void](Add-LbDrive 'Vide' 'B'); [void](Add-LbDrive 'Courbes' '0')
[void](Set-TargetDrive 'Cible Seule' '0')
Set-DriveCurve 'Courbes' 'std' (New-Cv 'Courbes' 'std' $null '08/11/2026 10:00' '0=30:40=70')
$script:LevelShifts['std|c'] = @{ RefKey = 'std'; Tag = 'c'; Drive = 'Courbes'; RefDate = '08/11/2026 10:00' }
$p4 = @()
foreach ($d in 'Cible Seule', 'Vide', 'Courbes') {
    if ($d -eq 'Courbes') { $script:DriveCurves.Remove('Courbes|std') | Out-Null; Sync-PrecompCurves }   # « Effacer les calibrations » : niveaux gardes
    $script:Asks.Clear(); $script:Msgs.Clear()
    $nb = Get-LbBaks
    $r4 = Remove-DriveEntry (Get-LbRow $d)
    $shown42 = (@($script:Asks | Where-Object { [string]$_.Text -like '*.lecteurs-….bak*' }).Count -gt 0)
    $copied = ((Get-LbBaks) -gt $nb)
    $p4 += "$d : T42 $shown42, copie $copied, question T47 $(@($script:Msgs | Where-Object { [string]$_.Text -like '*Il n''a aucune calibration.' }).Count)"
    if (-not $r4.Ok -or $shown42 -ne $copied) { $p4 += 'ECART' }
}
Reset-LbWorld 'p4b'
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60'); $script:TargetDrives['B'] = '0'; Sync-PrecompCurves
$pA = Get-DriveEditPlan (Get-LbRow 'A') 'Sony' 'A'; $pB = Get-DriveEditPlan (Get-LbRow 'B') 'Teac' 'B'
$p4b = ($pA.AskText.Contains('.lecteurs-….bak') -and $pA.Ask -ceq 'check' -and $pB.Ask -ceq 'yesno' -and -not $pB.AskText.Contains('.bak') -and -not $pB.AskText.Contains('a des calibrations faites sans nom') -and -not $pB.AskCheck)
Chk 'P4' (($p4 -join ' | ') -ceq 'Cible Seule : T42 True, copie True, question T47 0 | Vide : T42 False, copie False, question T47 1 | Courbes : T42 True, copie True, question T47 0' -and $p4b) "texte qui annonce la copie (T42) affiche si et seulement si la copie est faite : lecteur qui n a qu un lecteur cible, lecteur sans aucune donnee (question T47, aucune copie), lecteur sans courbe apres « Effacer les calibrations » (niveaux gardes) ; T38 seulement avec des courbes, question T70 sans courbe ($($p4 -join ' | '))"

# ================================================================ Y. textes completes pour un lecteur enregistre
'--- Y. textes completes : un lecteur enregistre en jeu, sinon ceux de la 12.10'
$fW = Get-LbFnAst $mods '140' 'Update-WLevelUi'
$stW = @($fW.Body.EndBlock.Statements | Where-Object { $_ -is $tAsg -and $_.Left.Extent.Text -eq '$chkWLevel.Text' })[0]
$genY = Join-Path $here 'gen-case-mesure.ps1'
Write-LbGen $genY @("function Get-LbLevelText(`$quick, `$ta, `$tw, `$lk, `$lm, `$full) {`r`n    `$chkWLevel = [pscustomobject]@{ Text = '' }`r`n    " + $stW.Extent.Text + "`r`n    return `$chkWLevel.Text`r`n}")
. $genY
Reset-LbWorld 'y'
$y1a = Get-LbLevelText $true $true @{ Tgt = '0'; Src = 'A' } '' 'content' $false
Set-LbTwoOnA
$y1b = Get-LbLevelText $true $true @{ Tgt = '0'; Src = 'Sony MPF920' } '' 'content' $false
$y1c = Get-LbLevelText $true $true @{ Tgt = '0'; Src = 'A' } '' 'content' $false
$y1d = Get-LbLevelText $true $true @{ Tgt = 'TEAC FD-235HF'; Src = 'B' } '' 'content' $false
Chk 'Y1' ($y1a -ceq ((T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (elle relirait avec le lecteur {1})") -f '0', 'A') -and $y1c -ceq $y1a -and $y1b -ceq "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour un lecteur cible" -and $y1d -ceq $y1b -and (W $y1b) -lt (W ((T "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible {0} (elle relirait avec le lecteur {1})") -f $wide, $wide2))) "case de la mesure (affectation reelle d Update-WLevelUi) : texte de la 12.10 sans lecteur enregistre en jeu (« $y1a »), texte court T64 quand le lecteur qui ecrit ou le lecteur cible est enregistre"
$fR = Get-LbFnAst $mods '250' 'Show-CalibReview'
$stR = @($fR.Body.EndBlock.Statements | Where-Object { $_ -is $tAsg -and $_.Left.Extent.Text -eq '$head' -and $_.Operator -eq 'Equals' })[0]
$genR = Join-Path $here 'gen-decision.ps1'
Write-LbGen $genR @("function Get-LbReviewHead(`$cal, [bool]`$toWrite, [bool]`$lvl, [bool]`$infoWin, `$lvl2, [bool]`$noFields) {`r`n    `$tgtR = ''`r`n    " + $stR.Extent.Text + "`r`n    return `$head`r`n}")
. $genR
$y2a = Get-LbReviewHead @{ Mode = 'fine'; Drive = 'A'; DiskOnly = $false } $false $false $false $null $false
$y2b = Get-LbReviewHead @{ Mode = 'fine'; Drive = 'Sony MPF920'; DiskOnly = $false } $false $false $false $null $false
$y2c = Invoke-En { Get-LbReviewHead @{ Mode = 'fine'; Drive = 'Sony MPF920'; DiskOnly = $false } $false $false $false $null $false }
Chk 'Y2' ($y2a -ceq "Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie." -and $y2b -ceq "Conserver la courbe : elle est enregistrée pour le lecteur Sony MPF920 et appliquée à ses prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie." -and $y2c -ceq "Keep the curve: it is saved for drive Sony MPF920 and applied to its next writes.`nDiscard the curve: the previous calibration is restored.") "fenetre de decision (affectation reelle de `$head, Show-CalibReview) : texte de la 12.10 pour A, texte T65 qui nomme le lecteur enregistre (francais et anglais)"
Reset-LbWorld 'y3'
$script:CalCoarse = @(0, 1, 2); $script:CalMaxVerify = 2; $script:CalMaxRetest = 2
$y3a = Invoke-LbCross 'B'
Chk 'Y3' ($y3a.Targets -ceq 'B,0,1,2,3' -and $y3a.Info -ceq (T "Aucune image calibrable dans l'onglet Écriture : 80 cylindres, à la densité de la famille choisie.") -and $script:Asks.Count -eq 0) "registre vide : cibles de la calibration croisee et texte de la fenetre de choix de la 12.10 ($($y3a.Targets)), aucune confirmation ; avec des lecteurs enregistres : K4 (texte T67)"
Reset-LbWorld 'y4'
$lblWCal.Text = ''
$script:Cal = @{ Hold = $true; Drive = 'A' }; Update-CalibProgress; $y4a = [string]$lblWCal.Text
$script:Cal = @{ SwapHold = @{ From = 'A'; To = '0' } }; Update-CalibProgress; $y4b = [string]$lblWCal.Text
$script:Cal = $null; Update-RsDrive; $y4c = [string]$lblRsDrive.Text
Set-LbTwoOnA; Select-LbDrive 'Sony MPF920'
$script:Cal = @{ Hold = $true; Drive = 'Sony MPF920' }; Update-CalibProgress; $y4d = [string]$lblWCal.Text
$script:Cal = @{ SwapHold = @{ From = 'Sony MPF920'; To = '0' } }; Update-CalibProgress; $y4e = [string]$lblWCal.Text
$script:Cal = @{ SwapHold = @{ From = 'A'; To = '0' } }; Update-CalibProgress; $y4f = [string]$lblWCal.Text
$script:Cal = $null; $y4g = [string]$lblRsDrive.Text
Select-LbDrive '0'; $y4h = [string]$lblRsDrive.Text
Chk 'Y4' ($y4a -ceq 'Calibration en attente : décision sur le contrôle de surface (lecteur A).' -and $y4b -ceq 'Calibration croisée : déplacez la disquette du lecteur A vers le lecteur 0' -and $y4c -ceq 'A  (choix « Lecteur » du bandeau)' -and $y4d -ceq 'Sony MPF920 : contrôle de surface, décision demandée' -and $y4e -ceq 'Sony MPF920 → 0 : déplacez la disquette' -and $y4f -ceq $y4b -and $y4g -ceq 'Sony MPF920 (A)  (bandeau)' -and $y4h -ceq '0  (choix « Lecteur » du bandeau)') "ligne d etat (Update-CalibProgress reelle) et libelle de la restauration (Update-RsDrive reelle) : textes de la 12.10 sans lecteur enregistre en jeu ; textes courts T73, T72 et T74, nom en tete, avec un lecteur enregistre ; le libelle de la restauration suit le lecteur du bandeau sur une meme connexion ($y4g)"

# ================================================================ I. statique
'--- I. statique'
$modFiles = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)
function Get-LbOwner($node) { $p = $node.Parent; while ($p) { if ($p -is $tFn) { return [string]$p.Name }; $p = $p.Parent }; return '' }
# I2 : les trois fonctions qui creent $script:Cal, celle qui cree $script:Restore et Start-ImageWrite appellent
# Confirm-DriveIdentity avant ; aucune autre fonction ne cree ces etats
$creators = @{}
foreach ($f in $modFiles) {
    foreach ($a in (Get-LbAst $f.FullName).FindAll({ param($x) $x -is $tAsg -and @('$script:Cal', '$script:Restore') -contains $x.Left.Extent.Text -and $x.Right.Extent.Text.StartsWith('@{') }, $true)) {
        $creators["$(Get-LbOwner $a)"] = $a
    }
}
$i2 = @()
$i2Want = @('Start-ContentMeasure', 'Start-ImageWrite', 'Start-LevelCalib', 'Start-PrecompCalib', 'Start-Restore')
$i2Found = @(@($creators.Keys) + @('Start-ImageWrite') | Sort-Object -Unique)
foreach ($n in $i2Want) {
    $fd = $null; foreach ($f in $modFiles) { foreach ($x in (Get-LbFnAsts $f.FullName)) { if ($x.Name -eq $n) { $fd = $x } } }
    if (-not $fd) { $i2 += "$n absente"; continue }
    $calls = @($fd.Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Confirm-DriveIdentity' }, $true))
    if ($calls.Count -ne 1) { $i2 += "$n : $($calls.Count) appel(s)"; continue }
    $c = $calls[0]
    $guard = $c.Parent; while ($guard -and $guard -isnot $tIf) { $guard = $guard.Parent }
    if (-not $guard -or -not ([string]$guard.Clauses[0].Item1.Extent.Text).StartsWith('$script:DriveReg.Count -gt 0 -and -not (Confirm-DriveIdentity')) { $i2 += "$n : appel non garde" }
    $stop = if ($creators.ContainsKey($n)) { $creators[$n].Extent.StartOffset } else { @($fd.Body.FindAll({ param($x) $x -is $tCmd -and @('Start-Gw', 'Start-WriteWarmup') -contains $x.GetCommandName() }, $true) | ForEach-Object { $_.Extent.StartOffset } | Sort-Object)[0] }
    if (-not $stop -or $c.Extent.StartOffset -gt $stop) { $i2 += "$n : confirmation apres la creation de l etat ou le lancement de gw" }
    if ($n -eq 'Start-ImageWrite' -and -not $c.Extent.Text.Contains('-Write')) { $i2 += 'Start-ImageWrite sans -Write' }
}
Chk 'I2' ($i2.Count -eq 0 -and ($i2Found -join ',') -ceq ($i2Want -join ',')) "fonctions qui creent `$script:Cal ou `$script:Restore, et Start-ImageWrite : $($i2Found -join ', ') ; chacune appelle Confirm-DriveIdentity une fois, sous la garde « registre non vide », avant la creation de l etat ou le lancement de gw ; ecarts : $(if ($i2.Count) { $i2 -join ' ; ' } else { 'aucun' })"
# I4 : gestionnaire du bandeau : debut inchange, Update-DriveChoice apres Sync-PrecompCurves
$s520 = [System.IO.File]::ReadAllText((Get-LbModule $mods '520'), [System.Text.Encoding]::UTF8)
Chk 'I4' ($s520.Contains("`$cmbDrive.Add_TextChanged({`r`n    Update-TargetDriveUi; Update-SlowUi`r`n    Sync-PrecompCurves`r`n    Update-DriveChoice ") -and $s520.Contains('if ($form.Visible) { Update-PrecompForImage $txtWFile.Text }')) "gestionnaire du bandeau (520) : debut contrôle par logic-courbes-par-lecteur S3 inchange, puis Update-DriveChoice"
# I5 : invariant 9 : sans lecteur enregistre, le code de la 12.10 : toute ligne ajoutee a une fonction existante qui appelle
# une fonction du module 112 est gardee par « $script:DriveReg.Count -gt 0 », sauf les conversions de --drive=, les
# lignes du socle (configuration, LN-a), la fonction nouvelle du retour a une calibration precedente (L7, absente de la
# 12.10) et le verrou, la molette, le choix a la main, la carte et le gestionnaire
$fn112 = @((Get-LbFnAsts (Get-LbModule $mods '112')) | ForEach-Object { $_.Name })
$allow = @('110 Get-CommonArgs Get-DriveConn', '110 Start-DriveDetect Get-DriveConn', '240 Get-CalibDriveArgsFor Get-DriveConn', '140 Get-DriveIds Get-DriveIds',
           '120 Save-Config Export-DriveRegistry', '120 Save-Config Save-DriveRescue', '120 Load-Config Import-DriveRegistry', '120 Load-Config Repair-DriveRegistry', '120 Load-Config Restore-DriveRescueTargets',
           '120 Register-SettingCtl Get-DriveConn', '240 Get-CalibBackInfo Resolve-DriveOfEra', '510  Set-DriveHandChoice', '520  Update-DriveChoice', '540  Get-DrivesCardText', '540  Show-DrivesDialog', '600  Update-DriveLock')
$i5 = @(); $i5n = 0
foreach ($f in $modFiles) {
    if ($f.Name -match '^(0|112)') { continue }
    foreach ($c in (Get-LbAst $f.FullName).FindAll({ param($x) $x -is $tCmd -and $fn112 -contains $x.GetCommandName() }, $true)) {
        $i5n++
        $own = Get-LbOwner $c
        $key = "$($f.Name.Substring(0, 3)) $own $($c.GetCommandName())"
        if ($allow -contains $key) { continue }
        $ok = $false; $p = $c.Parent; $child = $c
        while ($p -and $p -isnot $tFn) {
            if ($p -is $tIf) {
                foreach ($cl in $p.Clauses) {
                    $cond = [string]$cl.Item1.Extent.Text
                    $inCond = ($child.Extent.StartOffset -ge $cl.Item1.Extent.StartOffset -and $child.Extent.EndOffset -le $cl.Item1.Extent.EndOffset)
                    $inBody = ($child.Extent.StartOffset -ge $cl.Item2.Extent.StartOffset -and $child.Extent.EndOffset -le $cl.Item2.Extent.EndOffset)
                    if ($inCond) { $pre = $cond.Substring(0, $c.Extent.StartOffset - $cl.Item1.Extent.StartOffset); if ($pre.Contains('$script:DriveReg.Count -gt 0')) { $ok = $true } }
                    if ($inBody -and $cond.Contains('$script:DriveReg.Count -gt 0')) { $ok = $true }
                }
            }
            if ($ok) { break }
            $child = $p; $p = $p.Parent
        }
        if (-not $ok) { $i5 += $key }
    }
}
Chk 'I5' ($i5.Count -eq 0 -and $i5n -ge 25) "registre vide, code de la 12.10 : $i5n appels de fonctions du module 112 hors du module, tous gardes par « registre non vide » sauf les conversions de --drive=, le socle (configuration) et les lignes voulues pour tous (choix a la main, gestionnaire, carte, verrou) ; non gardes : $(if ($i5.Count) { $i5 -join ' ; ' } else { 'aucun' })"
# I6 : la fenetre ne decide rien et n ouvre aucune boite de message directe ; les fonctions de l interface n ecrivent
# aucun porteur de l identite (Edit-DriveData reste la seule, LN-a I6)
$ast112 = Get-LbAst (Get-LbModule $mods '112')
$t112 = [System.IO.File]::ReadAllText((Get-LbModule $mods '112'), [System.Text.Encoding]::UTF8)
$mb = @($ast112.FindAll({ param($x) $x -is [System.Management.Automation.Language.TypeExpressionAst] -and [string]$x.TypeName.FullName -like '*MessageBox*' }, $true)).Count
$dlgFns = @('New-DrivesDialog', 'Update-DrivesDialog', 'Set-DrivesDialogInputs', 'Start-DrivesDialogNew', 'Show-DrivesDialogNote', 'Invoke-DrivesDialogSave', 'Invoke-DrivesDialogDelete', 'Show-DrivesDialog', 'Get-DrivesDialogRow', 'Set-DrivesDialogState')
$dlgActs = @()
foreach ($n in $dlgFns) { $fd = Get-LbFnAst $mods '112' $n; if ($fd) { foreach ($c in $fd.Body.FindAll({ param($x) $x -is $tCmd -and @('Add-NamedDrive', 'Rename-NamedDrive', 'Move-NamedDrive', 'Remove-NamedDrive', 'Edit-DriveData', 'Test-DriveName') -contains $x.GetCommandName() }, $true)) { $dlgActs += "$n $($c.GetCommandName())" } } }
Chk 'I6' ($mb -eq 0 -and $dlgActs.Count -eq 0 -and -not $t112.Contains('MessageBox]::Show')) "module 112 : aucune boite de message directe ($mb) ; les fonctions de la fenetre n appellent aucune action du registre ni Test-DriveName : Get-DriveEditPlan, Invoke-DriveEditPlan, Get-DriveDeletePlan et Remove-DriveEntry decident et agissent ($(if ($dlgActs.Count) { $dlgActs -join ' ; ' } else { 'aucun appel direct' }))"
# I3 : textes de la specification (§ 6.5, section LN-b), francais et anglais, mot pour mot ; memes parametres {n}
$TX = [ordered]@{
    T1 = @('Lecteur ({0}) :', 'Drive ({0}):')
    T2 = @("Lecteurs enregistrés : {0}.`nLeurs calibrations sont rangées sous leur nom, quelle que soit leur connexion. L'application ne reconnaît pas le lecteur branché : choisissez-le ici chaque fois que vous en changez (pour les nommer : Accueil, « Lecteurs enregistrés »).", "Registered drives: {0}.`nTheir calibrations are filed under their name, whatever their connection. The application cannot recognise the drive that is plugged in: select it here each time you change it (to name them: Home, `"Registered drives`").")
    T3 = @('Lecteurs enregistrés', 'Registered drives')
    T4 = @('Nommer vos lecteurs : plusieurs sur une même connexion, chacun avec ses calibrations.', 'Name your drives: several on one connection, each with its own calibrations.')
    T5 = @('{0} lecteur(s) sans connexion : redonnez-la ici pour retrouver leurs calibrations.', '{0} drive(s) without a connection: set it again here to get their calibrations back.')
    T6 = @('Vos lecteurs de disquette', 'Your floppy drives')
    T7 = @("Un lecteur enregistré a un nom et une connexion au Greaseweazle (A ou B : nappe PC avec twist ; 0 à 3 : nappe droite). Ses calibrations, son lecteur cible et ses facteurs mesurés sont rangés sous son nom : plusieurs lecteurs peuvent partager une connexion, et un lecteur garde ses calibrations quand il change de connexion.`n`nL'application ne reconnaît pas le lecteur branché : celui qui compte est le lecteur choisi dans la liste « Lecteur : » du bandeau. Un lecteur nouveau part sans calibration, avec le profil d'origine.", "A registered drive has a name and a connection to the Greaseweazle (A or B: PC cable with twist; 0 to 3: straight cable). Its calibrations, its target drive and its measured factors are filed under its name: several drives can share a connection, and a drive keeps its calibrations when its connection changes.`n`nThe application cannot recognise the drive that is plugged in: the one that counts is the drive selected in the `"Drive:`" list of the banner. A new drive starts without calibration, with the original profile.")
    T8 = @('Connexion', 'Connection'); T9 = @('Calibrations', 'Calibrations'); T10 = @('{0} (non enregistré)', '{0} (not registered)'); T11 = @('à préciser', 'to be set')
    T14 = @('Connexion :', 'Connection:'); T15 = @('Nouveau lecteur', 'New drive'); T16 = @('Supprimer…', 'Delete…')
    T17 = @('La connexion {0} a déjà des calibrations sans nom de lecteur. Pour les garder avec ce lecteur, sélectionnez la ligne « {0} (non enregistré) » et donnez-lui ce nom ; sinon ce lecteur sera calibré à part.', 'Connection {0} already has calibrations without a drive name. To keep them with this drive, select the row "{0} (not registered)" and give it this name; otherwise this drive will be calibrated separately.')
    T26 = @("Rien à enregistrer : le nom et la connexion n'ont pas changé.", 'Nothing to save: the name and the connection have not changed.')
    T31 = @('Lecteur « {0} » enregistré sur la connexion {1}, sans calibration. Choisissez-le dans la liste « Lecteur : » du bandeau quand il est branché.', 'Drive "{0}" registered on connection {1}, without calibration. Select it in the "Drive:" list of the banner when it is plugged in.')
    T32 = @('Lecteur « {0} » enregistré sur la connexion {1} : les calibrations faites sans nom sur la connexion {2} ({3} courbe(s)) sont maintenant les siennes.', 'Drive "{0}" registered on connection {1}: the calibrations made without a name on connection {2} ({3} curve(s)) are now its own.')
    T33 = @("Lecteur « {0} » : il s'appelait « {1} ». Ses calibrations ({2} courbe(s)), ses niveaux, sa mémoire par marque, ses facteurs et ses lecteurs cibles portent son nouveau nom.", 'Drive "{0}": it was called "{1}". Its calibrations ({2} curve(s)), its levels, its per-brand memory, its factors and its target drives carry its new name.')
    T34 = @('Lecteur « {0} » : connexion {1} (avant : {2}). Ses calibrations le suivent. Après un changement de nappe, contrôlez une écriture (onglet Qualité) ou refaites une calibration rapide.', 'Drive "{0}": connection {1} (before: {2}). Its calibrations follow it. After a cable change, check a write (Quality tab) or run a quick calibration again.')
    T35 = @('Lecteur « {0} » supprimé : {1} courbe(s) retirée(s).', 'Drive "{0}" deleted: {1} curve(s) removed.')
    T36 = @('Nom « {0} » retiré : ses calibrations sont rangées sous la connexion {1}, sans nom de lecteur.', 'Name "{0}" removed: its calibrations are filed under connection {1}, without a drive name.')
    T37 = @('Attribuer à ce lecteur les calibrations de la connexion {0} ?', 'Assign the calibrations of connection {0} to this drive?')
    T38 = @("La connexion {0} a des calibrations faites sans nom de lecteur : {1}.`n`nEn nommant ce lecteur « {2} », vous déclarez qu'elles ont été faites avec lui : elles deviennent les siennes, avec ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible. Rien n'est recalculé ni effacé ; la configuration est d'abord copiée dans un fichier « {3}.lecteurs-….bak ». La connexion {0} garde un lecteur non enregistré, sans calibration.`n`nSi elles viennent d'un autre lecteur, fermez cette fenêtre et choisissez « Nouveau lecteur » : il partira sans calibration.", "Connection {0} has calibrations made without a drive name: {1}.`n`nBy naming this drive `"{2}`", you state that they were made with it: they become its own, with its levels, its per-brand memory, its measured factors and its target drive. Nothing is recomputed or erased; the configuration is first copied to a `"{3}.lecteurs-….bak`" file. Connection {0} keeps an unregistered drive, with no calibration.`n`nIf they come from another drive, close this window and choose `"New drive`": it will start without calibration.")
    T39 = @('Les calibrations de la connexion {0} ont été faites avec le lecteur « {1} »', 'The calibrations of connection {0} were made with drive "{1}"')
    T40 = @('Attribuer ces calibrations', 'Assign these calibrations')
    T70 = @("Le lecteur non enregistré de la connexion {0} n'a aucune calibration. Son lecteur cible, ses niveaux, sa mémoire par marque et ses facteurs mesurés passent sous le nom « {1} ». Continuer ?", 'The unregistered drive of connection {0} has no calibration. Its target drive, its levels, its per-brand memory and its measured factors move under the name "{1}". Continue?')
    T41 = @('Supprimer le lecteur « {0} » ?', 'Delete drive "{0}"?')
    T42 = @("Sont retirés : ses calibrations ({0}), ses niveaux, sa mémoire par marque, ses facteurs mesurés et son lecteur cible, ainsi que les courbes croisées dont il est le lecteur cible et le choix de ce lecteur comme cible d'un autre.`n`nL'application ne peut pas annuler cette suppression. Elle copie d'abord la configuration dans « {1}.lecteurs-….bak », dans le même dossier : pour revenir en arrière, fermez l'application, puis remettez cette copie à la place de « {1} ».", "Removed: its calibrations ({0}), its levels, its per-brand memory, its measured factors and its target drive, as well as the cross curves of which it is the target drive and the choice of this drive as the target of another one.`n`nThe application cannot undo this deletion. It first copies the configuration to `"{1}.lecteurs-….bak`", in the same folder: to go back, close the application, then put this copy in place of `"{1}`".")
    T43 = @('« Retirer seulement le nom » : ses calibrations restent, rangées sous la connexion {0}, sans nom de lecteur.', '"Remove the name only": its calibrations remain, filed under connection {0}, without a drive name.')
    T44 = @('Le lecteur « {0} » ne doit plus être enregistré', 'Drive "{0}" must no longer be registered')
    T45 = @('Supprimer avec ses calibrations', 'Delete with its calibrations'); T46 = @('Retirer seulement le nom', 'Remove the name only')
    T47 = @("Supprimer le lecteur « {0} » ? Il n'a aucune calibration.", 'Delete drive "{0}"? It has no calibration.')
    T48 = @('Lecteur branché', 'Plugged-in drive'); T49 = @('Quel lecteur est branché sur la connexion {0} ?', 'Which drive is plugged into connection {0}?')
    T50 = @("La connexion {0} porte plusieurs lecteurs : {1}. L'application ne reconnaît pas celui qui est branché.", 'Connection {0} carries several drives: {1}. The application cannot recognise the one that is plugged in.')
    T51 = @("Vos lecteurs enregistrés viennent d'être relus dans leur copie de secours : le fichier de configuration ne les contenait pas. L'application ne reconnaît pas le lecteur branché sur la connexion {0}.", 'Your registered drives have just been read back from their rescue copy: the configuration file did not contain them. The application cannot recognise the drive plugged into connection {0}.')
    T52 = @("Lecteur choisi dans le bandeau : {0}`nSes calibrations : {1}`n`nL'écriture et la calibration emploient ses courbes et rangent leurs résultats sous son nom. Si un autre lecteur est branché, fermez cette fenêtre et choisissez-le dans la liste « Lecteur : » du bandeau : avec la courbe d'un autre lecteur, la disquette serait mal précompensée, sans aucun message d'erreur.", "Drive selected in the banner: {0}`nIts calibrations: {1}`n`nWriting and calibration use its curves and file their results under its name. If another drive is plugged in, close this window and select it in the `"Drive:`" list of the banner: with the curve of another drive, the disk would be badly precompensated, without any error message.")
    T53 = @('Le lecteur branché sur la connexion {0} est bien « {1} »', 'The drive plugged into connection {0} is indeed "{1}"')
    T53b = @("Le lecteur branché sur la connexion {0} n'est aucun des lecteurs enregistrés", 'The drive plugged into connection {0} is none of the registered drives')
    T75 = @("Lecteur cible de cette calibration croisée : {0}`nLa courbe mesurée servira aux écritures du lecteur {1} destinées à ce lecteur. Si un autre lecteur est branché sur la connexion {2}, fermez cette fenêtre et relancez la calibration croisée avec le bon lecteur cible : mesurée avec un autre lecteur, la courbe serait fausse, sans aucun message d'erreur.", "Target drive of this cross calibration: {0}`nThe measured curve will be used for the writes of drive {1} intended for this drive. If another drive is plugged into connection {2}, close this window and start the cross calibration again with the right target drive: measured with another drive, the curve would be wrong, without any error message.")
    T54 = @('Lecteur choisi : {0} (avant : {1}).', 'Drive selected: {0} (before: {1}).'); T55 = @('Lecteur qui écrit : {0}', 'Writing drive: {0}')
    T56 = @('Connexion {0} : lecteur retenu « {1} », le dernier choisi sur cette connexion. La détection ne reconnaît pas le lecteur branché : vérifiez la liste « Lecteur : » du bandeau.', 'Connection {0}: drive "{1}" kept, the last one selected on this connection. Detection cannot recognise the drive that is plugged in: check the "Drive:" list of the banner.')
    T68 = @('Opération annulée : lecteur branché non confirmé.', 'Operation cancelled: plugged-in drive not confirmed.')
    T64 = @("Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour un lecteur cible", 'Measure the disk before the write: always with "Quick test", except for a target drive')
    T65 = @("Conserver la courbe : elle est enregistrée pour le lecteur {0} et appliquée à ses prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie.", "Keep the curve: it is saved for drive {0} and applied to its next writes.`nDiscard the curve: the previous calibration is restored.")
    T67 = @("Non proposés, parce qu'ils sont sur la connexion {0} du lecteur qui écrit : {1}. Les deux lecteurs d'une calibration croisée sont branchés en même temps, chacun sur sa connexion.", 'Not offered, because they are on connection {0} of the writing drive: {1}. The two drives of a cross calibration are plugged in at the same time, each on its own connection.')
    T72 = @('{0} → {1} : déplacez la disquette', '{0} → {1}: move the disk'); T73 = @('{0} : contrôle de surface, décision demandée', '{0}: surface check, decision requested')
    T74 = @('{0}  (bandeau)', '{0}  (banner)')
}
$i3 = @()
foreach ($k in @($TX.Keys)) {
    $fr = [string]$TX[$k][0]; $en = [string]$TX[$k][1]
    $got = Invoke-En { T $fr }
    $phF = (@([regex]::Matches($fr, '\{(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ','); $phE = (@([regex]::Matches($en, '\{(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ',')
    if ($got -cne $en -or $phF -cne $phE) { $i3 += $k }
}
# Cles de T() ecrites par le lot (fin du module 112, lignes ajoutees aux autres modules) : chacune est l une de ces
# cles, une cle du socle (LN-a) ou une cle existante reemployee
$lnb = $t112.IndexOf('# ============================== LN-b')
$usedB = @($ast112.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'T' -and $x.Extent.StartOffset -gt $lnb -and $x.CommandElements.Count -ge 2 -and ($x.CommandElements[1] -is $tStr -or $x.CommandElements[1] -is $tExp) }, $true) | ForEach-Object { [string]$_.CommandElements[1].Value } | Sort-Object -Unique)
$knownB = @($TX.Keys | ForEach-Object { [string]$TX[$_][0] }) + @('Lecteur :', 'Lecteur', 'Nom :', 'Enregistrer', 'Fermer', 'aucune', 'mesure continue de la qualité', 'Choisissez la connexion du lecteur.', "Configuration non sauvegardée : rien n'a été modifié (voir le journal).",
    'Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.', 'Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.',
    'La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.', "Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le.")
$unkB = @($usedB | Where-Object { $knownB -cnotcontains $_ })
$t019 = [System.IO.File]::ReadAllText((Get-LbModule $mods '019'), [System.Text.Encoding]::UTF8)
Chk 'I3' ($i3.Count -eq 0 -and $unkB.Count -eq 0 -and $t019.Contains('# --- LN-b : lecteurs enregistres, interface') -and $usedB.Count -ge 40) "$(@($TX.Keys).Count) textes de l interface (specification, § 6.5) : entree anglaise mot pour mot (section « LN-b » de 019), memes parametres {n} ; $($usedB.Count) cles de T() de l interface du module 112, toutes connues ; ecarts : $(@($i3 + $unkB) -join ' ; ')"

# ================================================================ D. documents
'--- D. documents'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$sec = ''; $mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)'); if ($mm.Success) { $sec = $mm.Value }
Chk 'D10' ($sec.Contains('**Lecteurs enregistrés.** Donnez un nom à vos lecteurs de disquette') -and $sec.Contains('**Lecteur verrouillé pendant une opération.**') -and $sec.Contains('**Lecteur à l''abri d''un geste involontaire.**') -and $sec.Contains('**La fenêtre de décision d''une calibration nomme le lecteur enregistré**') -and $sec.Contains('**Rien à faire, rien à recalibrer.**') -and $sec.Contains('**Lecteurs enregistrés et versions antérieures.**') -and $sec.Contains('**Choisissez le lecteur branché.**') -and $sec -notmatch 'vérifié sur (le )?matériel' -and $rd.Contains('`Confirm-DriveIdentity`') -and $trd.Contains('| `logic-lecteurs-bandeau` |')) "CHANGELOG 12.11 : Nouveautés, Améliorations et À savoir du lot (textes de la specification, § 11.2), aucun comportement dit verifie sur materiel ; README des modules et des tests"

# ================================================================ Q. source d avant le lot (-Before)
'--- Q. bandeau de la source d avant le lot (-Before)'
if (-not $Before) {
    'Q1       saute : sans -Before <copie de la source d avant le lot>, le bandeau n est pas compare a celui de cette source (U0 le compare aux positions de 510 de la 12.10)'
} else {
    $mb = Join-Path $Before 'src\modules'
    $st510b = Get-LbStmts $mb '510' '$pnlTop = ' '$pnlTop.Controls.AddRange('
    $genBanB = Join-Path $here 'gen-bandeau-avant.ps1'; Write-LbGen $genBanB @($st510b)
    $qb = & {
        function Register-SettingCtl([string]$k, $c) { }
        . $genBanB
        $fx = New-Object System.Windows.Forms.Form; $fx.ClientSize = New-Object System.Drawing.Size(800, 682); $fx.Font = $form.Font
        $fx.Controls.Add($pnlTop); Fit-ControlText $fx
        $o = @{ Pos = @(); Tip = [string]$tip.GetToolTip($cmbDrive) }
        # Texte d une liste : son choix (etat), pas sa disposition : ses elements a la place
        foreach ($c in @($pnlTop.Controls)) { $tx = if ($c -is [System.Windows.Forms.ComboBox]) { (@($c.Items) -join ',') } else { $c.Text }; $o.Pos += "$($c.GetType().Name) $tx $($c.Left),$($c.Top) $($c.Width)x$($c.Height)" }
        $fx.Dispose()
        return $o
    }
    Reset-LbWorld 'q'
    $qa = @(); foreach ($c in @($pnlTop.Controls)) { $tx = if ($c -is [System.Windows.Forms.ComboBox]) { (@($c.Items) -join ',') } else { $c.Text }; $qa += "$($c.GetType().Name) $tx $($c.Left),$($c.Top) $($c.Width)x$($c.Height)" }
    Chk 'Q1' (($qa -join ' ; ') -ceq ($qb.Pos -join ' ; ') -and $qb.Tip -ceq $tip1210 -and [string]$tip.GetToolTip($cmbDrive) -ceq $qb.Tip) "bandeau de la source d avant le lot (instructions de 510) : memes controles, textes, elements de la liste, positions et tailles, meme infobulle ; avant : $($qb.Pos -join ' ; ') ; lot : $($qa -join ' ; ')"
}

"=== bilan logic-lecteurs-bandeau : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$(if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') }) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
