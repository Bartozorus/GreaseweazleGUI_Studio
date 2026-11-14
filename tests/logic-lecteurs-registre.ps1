param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot LN-a) : lecteurs enregistres, socle sans interface (112-fn-lecteurs, et les lignes ajoutees a 040, 110, 120, 140
# et 240). Le nom d un lecteur enregistre est son identite (cle de rangement de ses courbes, champ Drive de ses donnees) ;
# sa connexion (A, B, 0 a 3) est un attribut de sa fiche, lu par la seule fonction Get-DriveConn.
#  H  harnais : fonctions reelles chargees, etat reel de 040, 560 et 565, controles WinForms reels jamais affiches.
#  M  migration : configuration 12.10 factice (courbes sous A et sous 0, courbes croisees, lecteur cible, niveaux, memoire
#     par marque, facteurs) chargee par la vraie Load-Config et reenregistree par la vraie Save-Config : registre vide, ni
#     bloc drives, ni copie de secours, ni ligne de journal ; fichier identique a l octet pres a celui que donne
#     Save-Config privee des lignes du lot ; arguments --drive de chaque connexion ; configuration 12.9 ; courbe d un autre
#     calcul en attente du choix.
#  N  nommer, renommer (correction de casse comprise), deplacer, retirer le nom : les huit porteurs, aucune courbe perdue
#     (comptees avant et apres, retrouvees dans la copie datee), jamais de fusion, copies datees et leur rotation,
#     refus pendant une operation, erreur pendant le calcul d Edit-DriveData.
#  S  supprimer. V  regles d un nom (mots reserves, textes francais et anglais), bloc modifie a la main, nom a accents.
#  C  configuration : bloc drives, copie de secours, registre relu dans la copie, noms sans fiche, copie illisible.
#  X  connexion des commandes gw et courbes croisees. E  lecteur d aujourd hui d une courbe d une copie datee
#     (Resolve-DriveOfEra, pour le retour a une calibration precedente).
#  I  statique : compositions de --drive=, textes anglais, registre ecrit par le seul module 112, Edit-DriveData seule a
#     changer l identite de donnees, tables reconstruites a partir de tables vides ; documents.
#  Q  avec -Before <copie de la source de la 12.10, ou de la source d avant le lot> (aucune dans le depot) : meme
#     configuration de depart passee par les fonctions de cette source : fichier ecrit identique a l octet pres, memes
#     arguments --drive, meme journal ; fonctions annoncees inchangees identiques ; cas C8 : fonctions de cette source
#     devant une configuration a lecteurs enregistres (elles gardent les courbes a nom sans les appliquer), puis retour.
# Fonctions et instructions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par
# dot-source. Aucun gw, aucune fenetre affichee, aucune compilation.
# Non couvert ici : l interface (liste du bandeau, fenetre, confirmation du lecteur branche, Get-CrossCalibTargets
# -OtherConn : lot LN-b, tests\logic-lecteurs-bandeau) ; un niveau de calibration rapide dont le lecteur n a aucune courbe
# ne survit pas a Load-Config (regle de la 12.10) : ce porteur est eprouve par un appel direct de Repair-DriveRegistry.
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
$tInv = [System.Management.Automation.Language.InvokeMemberExpressionAst]
$tIdx = [System.Management.Automation.Language.IndexExpressionAst]
$tMem = [System.Management.Automation.Language.MemberExpressionAst]
$tStr = [System.Management.Automation.Language.StringConstantExpressionAst]
$tExp = [System.Management.Automation.Language.ExpandableStringExpressionAst]
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ordinal = [System.StringComparer]::Ordinal
$mods = Join-Path $Wt 'src\modules'

# ---------------------------------------------------------------- arbres, fonctions, affectations
$script:AstOf = @{}
function Get-LnAst([string]$path) {
    if (-not $script:AstOf.ContainsKey($path)) {
        $tk = $null; $er = $null
        $a = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
        if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
        $script:AstOf[$path] = $a
    }
    return $script:AstOf[$path]
}
function Get-LnModule([string]$dir, [string]$prefix) {
    $f = @(Get-ChildItem -LiteralPath $dir -Filter "$prefix-*.ps1" -File)
    if ($f.Count -ne 1) { return '' }
    return $f[0].FullName
}
function Get-LnFnAsts([string]$path) { return @((Get-LnAst $path).FindAll({ param($x) $x -is $tFn }, $false)) }
function Get-LnFnAst([string]$dir, [string]$prefix, [string]$name) {
    $p = Get-LnModule $dir $prefix
    if (-not $p) { return $null }
    foreach ($fd in (Get-LnFnAsts $p)) { if ($fd.Name -eq $name) { return $fd } }
    return $null
}
function Get-LnSortedText($list) {
    $a = [string[]]@($list)
    [array]::Sort($a, $ordinal)
    return ($a -join "`n")
}
# Fonctions reelles voulues, par module ('*' : toutes celles du module)
$want = [ordered]@{
    '110' = @('Get-CommonArgs', 'Get-AppBusy')
    '112' = @('*')
    '120' = @('ConvertTo-SettingValue', 'Get-Setting', 'Set-SettingStore', 'Set-SettingCtlValue', 'Set-Setting', 'Register-SettingCtl', 'Update-SettingDependents', 'Get-SettingText', 'Import-Settings', 'Export-Settings',
              'Update-LegacyCleanDefault', 'Update-LegacyLevelMode', 'Update-LegacyEraseMode', 'Test-ContentLevelSettings', 'Backup-ConfigBeforeRef', 'Export-CurveView', 'Export-DriveCurves', 'Import-DriveCurves',
              'Export-TargetDrives', 'Import-TargetDrives', 'Save-Config', 'Get-Cfg', 'Set-Num', 'Set-Combo', 'Load-Config')
    '140' = @('Get-DriveIds', 'Get-TargetDrive', 'Set-TargetDrive', 'Get-TargetDriveItems', 'Get-TargetCurves', 'Get-TargetWriteInfo')
    '220' = @('Get-CurveDate', 'Get-DriveFamilyCurves')
    '230' = @('Test-CurveHd', 'Get-CalibFamilyName', 'Get-Median', 'Get-CurveCalc', 'Get-CurveCalcRef', 'Test-CurveCalcOk', 'Get-CurveCalcText', 'ConvertTo-CurveConfig', 'ConvertTo-LevelConfig', 'ConvertTo-LevelBrandConfig',
              'ConvertFrom-LevelBrandConfig', 'ConvertFrom-LevelConfig', 'ConvertFrom-CurveConfig')
    '240' = @('Get-CalibDriveArgsFor', 'Get-CalibStoreDrive', 'Split-CrossDrive', 'Get-CrossCalibTargets', 'Get-CurveKeyLabel', 'Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves',
              'Get-DriveCurveKeys', 'Get-DriveCurveLabel')
    '265' = @('Get-LevelBrandKey')
    '274' = @('Get-DriveK', 'Get-StaleDriveFactors', 'ConvertTo-FiniteOrNull', 'Get-ConfigDouble', 'Get-RecValues', 'ConvertTo-ContentConfig', 'ConvertFrom-ContentConfig')
}
function New-LnFnGen([string]$dir, [string]$out) {
    # Fichier des fonctions reelles d un dossier de modules ; rend @{ Found ; Missing }
    $parts = New-Object System.Collections.Generic.List[string]
    $found = @(); $missing = @()
    foreach ($px in @($want.Keys)) {
        $p = Get-LnModule $dir $px
        if (-not $p) { $missing += "module $px"; continue }
        $fds = Get-LnFnAsts $p
        if (@($want[$px]) -contains '*') { foreach ($fd in $fds) { $parts.Add($fd.Extent.Text); $found += $fd.Name }; continue }
        foreach ($n in @($want[$px])) {
            $hit = @($fds | Where-Object { $_.Name -eq $n })
            if ($hit.Count -ne 1) { $missing += $n; continue }
            $parts.Add($hit[0].Extent.Text); $found += $n
        }
    }
    [System.IO.File]::WriteAllText($out, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    return @{ Found = $found; Missing = $missing }
}
# Etat reel : affectations du niveau du script, dans l ordre du module
$wantState = [ordered]@{
    '000' = @('$script:Version', '$script:CalibCalc', '$script:CalibCalcHd', '$script:ContentCalc', '$script:CalibAlgo', '$script:OldCalib')
    '040' = @('$script:AlignRef', '$script:PrecompStd', '$script:PrecompLong', '$script:PrecompStdDefault', '$script:PrecompLongDefault', '$script:PrecompThresholdNs', '$script:JitterStdOk', '$script:JitterStdWatch',
              '$script:JitterOk', '$script:JitterWatch', '$script:AlignRefLabel', '$script:SettingDefs', '$script:Settings', '$script:SettingCtl', '$script:SettingOf', '$script:SettingSync', '$script:OpOverride',
              '$script:ContentKMid', '$script:ContentKLow', '$script:ContentKeepMeasures', '$script:HomeCalApp', '$script:HomeCalFmt',
              '$script:DriveReg', '$script:DriveLast', '$script:DriveChecked', '$script:DriveCur', '$script:DriveRescued', '$script:DriveRescueText', '$script:DriveRescuePairs', '$script:DriveBlockKeep',
              '$script:DriveNameMax', '$script:DriveListWidth', '$script:DriveBackupKeep', '$script:DriveReserved')
    '550' = @('$script:CleanPrefs')
    '560' = @('$script:CalRedo', '$script:CalHardNsDefault', '$script:CalHardMinNs', '$script:CalHardMaxNs', '$script:CalHardNs', '$script:CalWarmupDefault', '$script:CalWarmupMinutes', '$script:DriveCurves', '$script:PrecompCurves',
              '$script:CurveKeys', '$script:LevelFormat', '$script:LevelShifts', '$script:LevelBrand', '$script:LevelBrands', '$script:ConfigRefBackupKeep', '$script:TargetDrives', '$script:CalHardNsUser')
    '565' = @('$script:ContentKMax', '$script:ContentMeasures')
    '590' = @('$script:DetectNone')
}
$stateParts = New-Object System.Collections.Generic.List[string]
$stateMissing = @()
foreach ($px in @($wantState.Keys)) {
    $ast = Get-LnAst (Get-LnModule $mods $px)
    $names = @($wantState[$px]); $seen = @{}
    foreach ($st in $ast.EndBlock.Statements) {
        if ($st -is $tAsg -and $names -contains $st.Left.Extent.Text) { $stateParts.Add($st.Extent.Text); $seen[$st.Left.Extent.Text] = $true }
    }
    foreach ($n in $names) { if (-not $seen.ContainsKey($n)) { $stateMissing += "$px $n" } }
}
$genState = Join-Path $here 'gen-etat.ps1'
[System.IO.File]::WriteAllText($genState, ((@($stateParts) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
$genFn = Join-Path $here 'gen-fonctions.ps1'
$fnA = New-LnFnGen $mods $genFn

# ---------------------------------------------------------------- table I18n reelle, T et Format-UiNum reelles
$Language = 'fr'
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
. $genState
. $genFn

# ---------------------------------------------------------------- remplacants (interface, horloge)
$script:Log = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:Log.Add($text) }
function Get-LogN([string]$like) { return @($script:Log | Where-Object { $_ -like $like }).Count }
function Set-CalibScale([string]$fam) { }
function Update-SlowUi { }
function Update-TargetDriveUi { }
function Update-RsRules { }
function Update-RsDrive { }
function Update-RsFmtFound { }
function Update-RsCalib { }
function Update-CmpFmtFound { }
function Reset-LibDat { }
function Set-JitterThresholds([int]$ok, [int]$watch) { $script:JitterOk = $ok; $script:JitterWatch = $watch }
function Test-RawFluxWrite([string]$img, [string]$fmt) { return $false }
function Get-ImageEncoding([string]$path, [string]$fmt) { return @{ NonMfm = $false; Name = 'MFM' } }
# Horloge du test : dates des fiches, des copies et de _saved reproductibles
$script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
function Get-Date {
    param([string]$Format)
    if ($Format) { return $script:TNow.ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture) }
    return $script:TNow
}
function Step-LnClock([int]$seconds = 60) { $script:TNow = $script:TNow.AddSeconds($seconds) }

# ---------------------------------------------------------------- controles reels, jamais affiches
$form = New-Object System.Windows.Forms.Form
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$split = New-Object System.Windows.Forms.SplitContainer
$ctlNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($v in (Get-LnAst (Get-LnModule $mods '120')).FindAll({ param($x) $x -is $tVar }, $true)) {
    $n = [string]$v.VariablePath.UserPath
    if ($n -cmatch '^(txt|chk|cmb|num|lbl)[A-Z]\w*$') { [void]$ctlNames.Add($n) }
}
foreach ($n in @('cmbWProfile', 'chkWPrecomp', 'txtDev', 'cmbDrive')) { [void]$ctlNames.Add($n) }
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
# Liste du bandeau : celle de 510 (six connexions, liste fermee), liee au reglage drive par la vraie Register-SettingCtl
$cmbDrive.DropDownStyle = 'DropDownList'
[void]$cmbDrive.Items.AddRange([object[]]@($script:SettingDefs['drive'].Codes))
Register-SettingCtl 'drive' $cmbDrive
[void]$cmbWProfile.Items.AddRange([object[]]@('Auto', 'Standard 2 us', 'Long track', 'Manuel'))
$cmbWProfile.SelectedIndex = 0; $chkWPrecomp.Checked = $true
$script:DelayCtrls = [ordered]@{}
$script:GwFormats = @{ 'amiga.amigados' = $true }
$codes = [string[]]@($script:SettingDefs['drive'].Codes)
function Set-LnBanner([string]$id) {
    # Texte de la liste du bandeau : une connexion, ou le nom d un lecteur enregistre (element ajoute comme le fera le lot
    # LN-b), pose sous la garde des liaisons ; puis la vue, comme le gestionnaire du bandeau (520), et le reglage drive
    $sv = $script:SettingSync; $script:SettingSync = $true
    try {
        if (-not $cmbDrive.Items.Contains($id)) { [void]$cmbDrive.Items.Add($id) }
        $cmbDrive.SelectedItem = $id
    } finally { $script:SettingSync = $sv }
    if ([string]$cmbDrive.Text -cne $id) { throw "liste du bandeau : « $($cmbDrive.Text) » au lieu de « $id »" }
    $script:Settings['drive'] = Get-DriveConn $id
    Sync-PrecompCurves
}

# ---------------------------------------------------------------- donnees factices
function New-Cv([string]$drive, [string]$fam, $head, [string]$date, [string]$spec, [string]$target = '', [string]$calc = '') {
    # Courbe complete, sous la forme que rend ConvertFrom-CurveConfig ; profil ($spec) propre a chaque courbe du test
    if (-not $calc) { $calc = $script:CalibCalc }
    $v0 = [int](($spec -split '[=:]')[1])
    return @{ Family = (Get-CalibFamilyName $fam); Head = $head; Drive = $drive; Target = $target; Date = $date; Model = 'M1'; Spec = $spec; Method = 'motif'
              Version = '12.10'; Algo = 'seg1'; Calc = $calc; KeptFor = ''; Breaks = [int[]]@(); Values = [int[]]@(0..79 | ForEach-Object { $v0 + $_ }); Cyls = [int[]]@(0, 40, 79)
              Ys = [double[]]@(40.5, 80.5, 119.5); Sig = [double[]]@(3.5, 3.5, 3.5); Kinds = [string[]]@('zero', 'zero', 'zero'); Res = [double[]]@(0.5, -0.5, 0.25); Converged = $true
              MaxX = 300; MaxNs = 400; Slope = 0.8; Bits = 100000; Test = 'fine'; Contra = [int[]]@(); DentLo = [int[]]@(); DentHi = [int[]]@(); DentNs = [double[]]@() }
}
function New-Lv([string]$refKey, [string]$tag, [string]$drive, [string]$refDate) {
    return @{ RefKey = $refKey; Tag = $tag; Head = $null; Drive = $drive; Date = '08/11/2026 12:00'; RefDate = $refDate; RefTest = 'fine'; Delta = 3; Est = 3.5; SE = 0.5; Tau = 1.5; Verdict = 'ok'; Shape = 'ok'
              Reasons = [string[]]@(); Conv = $true; Passes = 2; Cyls = [int[]]@(0, 40); Zs = [double[]]@(1.5, 2.5); Ds = [double[]]@(0.1, 0.2); Sigs = [double[]]@(1.5, 1.5); Kinds = [string[]]@('zero', 'zero')
              Values = [int[]]@(10, 11); Spec = '0=10'; Sat = [int[]]@(); Floor = [int[]]@(); Hist = @(); Version = '12.10'; Algo = 'seg1'; LevelAlgo = 'lvl1'; S = 0.0; B = 0.0; Model = 'M0'; Mode = 'lvl1'
              Brand = ''; Ctl = [int[]]@(); K = $null }
}
function New-Br([string]$brand, [string]$drive, [string]$refKey, [string]$tag, [string]$refDate) {
    return @{ Brand = $brand; Drive = $drive; RefKey = $refKey; Tag = $tag; Head = $null; Family = 'std'; RefDate = $refDate; LevelAlgo = 'lvl2'; Model = 'M0'; A = 4.5; S = 0.0; B = 0.0; N = 1; Date = '08/11/2026 12:00'
              Levels = @(@{ Date = '08/11/2026 12:00'; Delta = 4 }); Shapes = @(); Curve = $null; CurveDate = ''; CurveCalc = ''; CurveMaxNs = 0; CurveSrc = '' }
}
function New-Cm([string]$drive, [int]$head, [double]$k) {
    $nan = [double]::NaN
    return @{ Model = 'contenu'; Drive = $drive; Family = 'std'; Head = $head; Date = '09/11/2026 10:00'; Image = 'image.adf'; K = $k; KVertex = $null; Bound = ''; Flat = $false; SeK = 0.05; B1 = $nan; B2 = $nan
              Gain = $nan; S = $nan; NCyl = 6; NObs = 12; NExcl = 0; Levels = [double[]]@(0.25, 0.6, 1.0); F = $k; Values = [int[]]@(10, 11); Spec = '0=10'; RefKey = 'std'; RefDate = '30/10/2026 09:00'
              Calc = [string]$script:CalibCalc; ContentCalc = [string]$script:ContentCalc; Version = '12.10'; Brand = ''; Etat = 'mesure'; Q = $nan; TQ = $nan; Chi2Ddl = $nan; NPass = 3; Zones = @() }
}
function Clear-LnMemory {
    # Memoire d une session neuve : aucune donnee, registre vide, application au repos
    $script:DriveCurves = @{}; foreach ($k in $script:CurveKeys) { $script:PrecompCurves[$k] = $null }
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    $script:OldCalib = $null; $script:LevelShifts = @{}; $script:LevelBrands = @(); $script:ContentMeasures = @(); $script:TargetDrives = @{}; $script:LevelBrand = ''
    $script:DriveReg = [ordered]@{}; $script:DriveLast = @{}; $script:DriveChecked = ''; $script:DriveCur = ''
    $script:DriveRescued = $false; $script:DriveRescueText = $null; $script:DriveRescuePairs = $null; $script:DriveBlockKeep = $false
    $script:Restore = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null; $script:Detect = $null; $script:GwProc = $null
    $script:Chain = New-Object 'System.Collections.Generic.Queue[scriptblock]'; $script:AlignLoop = $false; $script:CalRedo = $null
    $script:Log.Clear(); $txtDev.Text = ''
    Set-LnBanner 'A'
}
function Reset-LnWorld([string]$tag) {
    # Depart de chaque cas : memoire neuve, dossier de configuration neuf sous le dossier de travail du test
    $dir = Join-Path (Join-Path $here 'cfg') $tag
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $dir -Force)
    $script:ConfigFile = Join-Path $dir 'GreaseweazleGUI.json'
    $script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
    Clear-LnMemory
}
function Set-LnExample {
    # Exemple suivi de la specification : en 12.10, un Sony sur A (courbe commune, courbes par tete, courbes croisees vers
    # 0, lecteur cible 0) et un TEAC sur 0 (courbes par tete) ; niveaux, memoire par marque et facteurs des deux
    Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60')
    Set-DriveCurve 'A' 'std_h0' (New-Cv 'A' 'std' 0 '01/11/2026 17:49' '0=21:40=61')
    Set-DriveCurve 'A' 'std_h1' (New-Cv 'A' 'std' 1 '01/11/2026 17:49' '0=22:40=62')
    Set-DriveCurve '0' 'std_h0' (New-Cv '0' 'std' 0 '02/11/2026 10:00' '0=23:40=63')
    Set-DriveCurve '0' 'std_h1' (New-Cv '0' 'std' 1 '02/11/2026 10:00' '0=24:40=64')
    Set-DriveCurve 'A>0' 'std_h0' (New-Cv 'A' 'std' 0 '05/11/2026 10:00' '0=25:40=65' '0')
    Set-DriveCurve 'A>0' 'std_h1' (New-Cv 'A' 'std' 1 '05/11/2026 10:00' '0=26:40=66' '0')
    $script:TargetDrives['A'] = '0'
    $script:LevelShifts['std|c'] = New-Lv 'std' 'c' 'A' '30/10/2026 09:00'
    $script:LevelShifts['std_h0|0'] = New-Lv 'std_h0' '0' '0' '02/11/2026 10:00'
    $script:LevelBrands = @((New-Br 'Verbatim' 'A' 'std' 'c' '30/10/2026 09:00'), (New-Br 'Maxell' '0' 'std_h0' '0' '02/11/2026 10:00'))
    $script:ContentMeasures = @((New-Cm 'A' 0 0.8), (New-Cm 'A' 1 0.7), (New-Cm '0' 0 0.9))
    Sync-PrecompCurves
}
function Start-LnCase([string]$tag) { Reset-LnWorld $tag; Set-LnExample }
function Get-LnCvSig($cv) {
    # Signature d une courbe, sans son identite : ce qui doit se retrouver apres une action, et dans une copie
    if (-not $cv) { return 'null' }
    return ('{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}' -f [string]$cv.Family, [string]$cv.Head, [string]$cv.Date, [string]$cv.Spec, [string]$cv.Calc, [string]$cv.KeptFor, [string]$cv.Test, (@($cv['Values']) -join ','))
}
function Get-LnMemSigs {
    $l = @()
    foreach ($e in @($script:DriveCurves.GetEnumerator())) { $l += (Get-LnCvSig $e.Value) }
    if ($script:OldCalib -and $script:OldCalib.Curves) { foreach ($e in @($script:OldCalib.Curves.GetEnumerator())) { $l += (Get-LnCvSig $e.Value) } }
    return (Get-LnSortedText $l)
}
function Get-LnProp($o, [string]$name) {
    if ($null -eq $o) { return $null }
    $p = $o.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}
function Read-LnJson([string]$path) { return ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json) }
function Get-LnFileKeys([string]$path) {
    $dc = Get-LnProp (Get-LnProp (Read-LnJson $path) 'write') 'driveCurves'
    if ($null -eq $dc) { return '' }
    return (Get-LnSortedText @($dc.PSObject.Properties | ForEach-Object { [string]$_.Name }))
}
function Get-LnFileSigs([string]$path) {
    $dc = Get-LnProp (Get-LnProp (Read-LnJson $path) 'write') 'driveCurves'
    $l = @()
    if ($null -ne $dc) { foreach ($p in @($dc.PSObject.Properties)) { $o = $p.Value; $l += ('{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}' -f [string]$o.family, [string]$o.head, [string]$o.date, [string]$o.spec, [string]$o.calc, [string]$o.keptFor, [string]$o.test, (@($o.values) -join ',')) } }
    return (Get-LnSortedText $l)
}
function Get-LnState {
    # Etat complet des porteurs de l identite et du registre, en texte : deux etats egaux a la casse pres se comparent par -ceq
    $l = New-Object System.Collections.Generic.List[string]
    foreach ($e in @($script:DriveCurves.GetEnumerator())) { $l.Add("C $($e.Key) d=$($e.Value.Drive) t=$($e.Value.Target) $(Get-LnCvSig $e.Value)") }
    if ($script:OldCalib) {
        foreach ($e in @($script:OldCalib.Curves.GetEnumerator())) { $l.Add("O $($e.Key) d=$($e.Value.Drive) t=$($e.Value.Target) $(Get-LnCvSig $e.Value)") }
        foreach ($e in @($script:OldCalib.Levels.GetEnumerator())) { $l.Add("OL $($e.Key) d=$($e.Value.Drive) $($e.Value.RefKey) $($e.Value.RefDate)") }
    }
    foreach ($e in @($script:LevelShifts.GetEnumerator())) { $l.Add("L $($e.Key) d=$($e.Value.Drive) $($e.Value.RefKey) $($e.Value.RefDate) $($e.Value.Delta)") }
    foreach ($en in @($script:LevelBrands)) { $l.Add("B $($en.Brand) d=$($en.Drive) $($en.RefKey) $($en.Tag) $($en.A)") }
    foreach ($r in @($script:ContentMeasures)) { $l.Add("F d=$($r.Drive) $($r.Family) $($r.Head) $($r.Date) $($r.K)") }
    foreach ($e in @($script:TargetDrives.GetEnumerator())) { $l.Add("T $($e.Key) > $($e.Value)") }
    foreach ($e in @($script:DriveLast.GetEnumerator())) { $l.Add("S $($e.Key) = $($e.Value)") }
    $txt = Get-LnSortedText $l
    $i = 0
    foreach ($e in @($script:DriveReg.GetEnumerator())) { $r = $e.Value; $txt += "`nR$i $($e.Key) / $($r.Name) / $($r.Conn) / $($r.Id) / $($r.Created) / $($r.From) / $($r.At)"; $i++ }
    return $txt
}
function Get-LnRegNames { return ,@($script:DriveReg.GetEnumerator() | ForEach-Object { [string]$_.Key }) }
function Get-LnRec([string]$name) { foreach ($e in @($script:DriveReg.GetEnumerator())) { if ([string]$e.Key -ceq $name) { return $e.Value } }; return $null }
function Test-LnInv([string[]]$allow = @()) {
    # Controle commun (invariants de la specification) : chaque identite portee par une donnee est une connexion ou une
    # fiche ; champs Drive et Target d une courbe d accord avec sa cle ; dernier lecteur d une connexion : une fiche de
    # cette connexion ; aucun nom reserve ; $script:DriveReg.Count est un entier. Rend les ecarts
    $bad = @()
    $names = Get-LnRegNames
    $ids = @()
    $tabs = @($script:DriveCurves)
    if ($script:OldCalib -and $script:OldCalib.Curves) { $tabs += $script:OldCalib.Curves }
    foreach ($tb in $tabs) {
        foreach ($e in @($tb.GetEnumerator())) {
            $sk = [string]$e.Key; $i = $sk.LastIndexOf('|'); $d = $sk.Substring(0, $i); $cv = $e.Value
            if ($d.Contains('>')) {
                $p = $d.Split('>'); $ids += $p[0]; $ids += $p[1]
                if ([string]$cv.Drive -cne $p[0] -or [string]$cv.Target -cne $p[1]) { $bad += "courbe $sk : Drive « $($cv.Drive) », Target « $($cv.Target) »" }
            } else {
                $ids += $d
                if ([string]$cv.Drive -cne $d) { $bad += "courbe $sk : Drive « $($cv.Drive) »" }
            }
        }
    }
    foreach ($e in @($script:LevelShifts.GetEnumerator())) { $ids += [string]$e.Value.Drive }
    if ($script:OldCalib -and $script:OldCalib.Levels) { foreach ($e in @($script:OldCalib.Levels.GetEnumerator())) { $ids += [string]$e.Value.Drive } }
    foreach ($en in @($script:LevelBrands)) { $ids += [string]$en.Drive }
    foreach ($r in @($script:ContentMeasures)) { $ids += [string]$r.Drive }
    foreach ($e in @($script:TargetDrives.GetEnumerator())) { $ids += [string]$e.Key; $ids += [string]$e.Value }
    foreach ($id in @($ids | Sort-Object -Unique)) {
        if ($codes -ccontains $id -or $names -ccontains $id -or $allow -ccontains $id) { continue }
        $bad += "identite sans fiche : « $id »"
    }
    foreach ($e in @($script:DriveLast.GetEnumerator())) {
        $r = Get-LnRec ([string]$e.Value)
        if (-not $r -or [string]$r.Conn -cne [string]$e.Key) { $bad += "dernier lecteur de $($e.Key) : « $($e.Value) »" }
    }
    foreach ($n in $names) { if (@($script:DriveReserved) -contains $n) { $bad += "nom reserve : $n" } }
    if ($script:DriveReg.Count -isnot [int] -or $script:DriveReg.Count -ne $names.Count) { $bad += 'Count du registre' }
    return ,@($bad)
}
function Chk-Inv([string]$id, [string[]]$allow = @()) {
    $b = Test-LnInv $allow
    Chk $id ($b.Count -eq 0) "controle commun : aucune identite sans fiche, champs Drive et Target d accord avec les cles, dernier lecteur coherent, Count entier ; ecarts : $(if ($b.Count) { $b -join ' ; ' } else { 'aucun' })"
}
function Get-LnBaks { return ,@(Get-ChildItem -LiteralPath (Split-Path -Parent $script:ConfigFile) -File | Where-Object { $_.Name -like '*.lecteurs-*.bak' } | Sort-Object Name | ForEach-Object { $_.FullName }) }
function Get-LnRescue { return ($script:ConfigFile + '.lecteurs') }
function Get-LnBytesId([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ('{0} octets, SHA-256 {1}' -f $b.Length, ([System.BitConverter]::ToString($sha.ComputeHash($b)).Replace('-', '').ToLowerInvariant().Substring(0, 16))) } finally { $sha.Dispose() }
}
$rxId = '^L\d{14}-\d{2}$'

# Textes de la specification (§ 6.5), francais et anglais, mot pour mot
$TX = [ordered]@{
    T12  = @('{0} courbe(s), dernière : {1}', '{0} curve(s), latest: {1}')
    T13  = @('{0} courbe(s) dont {1} croisée(s), dernière : {2}', '{0} curve(s), {1} of them cross, latest: {2}')
    T18  = @('Donnez un nom au lecteur.', 'Give the drive a name.')
    T19  = @('Nom trop long : {0} caractères au plus.', 'Name too long: {0} characters at most.')
    T20  = @("Caractère non admis : « {0} ». Un nom se compose de lettres, de chiffres, d'espaces et des signes - . _ + # °", 'Character not allowed: "{0}". A name is made of letters, digits, spaces and the signs - . _ + # °')
    T21  = @('Un nom contient au moins une lettre sans accent ou un chiffre.', 'A name contains at least one unaccented letter or one digit.')
    T22  = @('« {0} » désigne une connexion : choisissez un autre nom.', '"{0}" designates a connection: choose another name.')
    T23  = @('Un lecteur enregistré porte déjà ce nom : {0}.', 'A registered drive already has this name: {0}.')
    T24  = @("Nom trop large pour s'afficher en entier dans les listes de lecteurs (environ 17 caractères) : raccourcissez-le.", 'Name too wide to be shown in full in the drive lists (about 17 characters): shorten it.')
    T69  = @('« {0} » est un mot réservé : choisissez un autre nom.', '"{0}" is a reserved word: choose another name.')
    T25  = @('Choisissez la connexion du lecteur.', 'Select the connection of the drive.')
    # 12.11 (relecture de LN-a) : T27 et T28 ecartes de la specification, qui disait « calibrations » : le refus part pour
    # toute donnee (Get-DriveData : Any), un lecteur cible choisi compris
    T27  = @('Le lecteur {0} a déjà des données (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : celles de la connexion {1} ne peuvent pas lui être attribuées.', 'Drive {0} already has data (curves, target drive, levels, per-brand memory or factors): those of connection {1} cannot be assigned to it.')
    T28  = @('La connexion {0} a déjà des données sans nom de lecteur (courbes, lecteur cible, niveaux, mémoire par marque ou facteurs) : le nom ne peut pas être retiré seul.', 'Connection {0} already has data without a drive name (curves, target drive, levels, per-brand memory or factors): the name cannot be removed on its own.')
    T29  = @("Configuration non sauvegardée : rien n'a été modifié (voir le journal).", 'Configuration not backed up: nothing was changed (see the log).')
    T30  = @("Calibration B en cours ou en attente de décision : terminez-la d'abord.", 'Calibration B in progress or awaiting a decision: finish it first.')
    T71  = @('Lecteurs enregistrés : opération en cours ({0}). Réessayez quand elle est terminée.', 'Registered drives: operation in progress ({0}). Try again when it has finished.')
    T57  = @('Configuration sauvegardée avant la modification des lecteurs enregistrés : {0}', 'Configuration backed up before changing the registered drives: {0}')
    T58  = @("Configuration non copiée avant la modification des lecteurs enregistrés : {0}. Modification annulée : rien n'est changé.", 'Configuration not copied before changing the registered drives: {0}. Change cancelled: nothing is modified.')
    T58b = @("Configuration non enregistrée avant la modification des lecteurs enregistrés. Modification annulée : rien n'est changé.", 'Configuration not saved before changing the registered drives. Change cancelled: nothing is modified.')
    T59  = @('Lecteurs enregistrés : {0} fiche(s) illisible(s), ignorée(s).', 'Registered drives: {0} unreadable record(s), ignored.')
    T59b = @('Lecteurs enregistrés : connexion illisible pour {0} : redonnez-la dans « Lecteurs enregistrés » (Accueil).', 'Registered drives: unreadable connection for {0}: set it again in "Registered drives" (Home).')
    T60  = @("Lecteurs enregistrés relus dans la copie de secours ({0}) : le fichier de configuration ne les contenait pas (enregistré par une version antérieure, ou copie plus ancienne remise à sa place). Calibrations rangées sous leurs noms : {1}. Lecteurs cibles rétablis depuis cette copie : {2}. Vérifiez le lecteur choisi et son lecteur cible avant d'écrire.",
             'Registered drives read back from the rescue copy ({0}): the configuration file did not contain them (saved by an earlier version, or an older copy put back in its place). Calibrations filed under their names: {1}. Target drives restored from this copy: {2}. Check the selected drive and its target drive before writing.')
    T61  = @("Lecteurs présents dans les calibrations, sans fiche : {0}. Redonnez leur connexion dans « Lecteurs enregistrés » (Accueil) ; d'ici là, ils ne sont pas proposés dans le bandeau et leurs calibrations ne servent à aucun autre lecteur.",
             'Drives present in the calibrations, without a record: {0}. Set their connection again in "Registered drives" (Home); until then, they are not offered in the banner and their calibrations are not used for any other drive.')
    T76  = @('Calibrations rangées sous un nom de lecteur non admis ({0}) : elles ne servent à aucun lecteur.', 'Calibrations filed under a drive name that is not allowed ({0}): they are not used for any drive.')
    T62  = @('Copie de secours des lecteurs enregistrés non écrite ({0}) : {1}', 'Rescue copy of the registered drives not written ({0}): {1}')
    T63  = @('Copie de secours des lecteurs enregistrés illisible ({0}) : {1}', 'Rescue copy of the registered drives unreadable ({0}): {1}')
    T66  = @('{0} (connexion à préciser)', '{0} (connection to be set)')
    TXa  = @('{0} : {1}', '{0}: {1}')
    TXb  = @('Copie de secours des lecteurs enregistrés de Greaseweazle Studio (noms, connexions, lecteurs cibles) - régénérée automatiquement.', 'Rescue copy of the registered drives of Greaseweazle Studio (names, connections, target drives) - regenerated automatically.')
}
function Fr([string]$k) { return [string]$TX[$k][0] }
function En([string]$k) { return [string]$TX[$k][1] }
function Invoke-En([scriptblock]$b) { $script:Lang = 'en'; try { return (& $b) } finally { $script:Lang = 'fr' } }

"logic-lecteurs-registre : $Wt ; $($fnA.Found.Count) fonctions reelles, $($stateParts.Count) affectations d etat, $nCtl controles jamais affiches ; PowerShell $($PSVersionTable.PSVersion)$(if ($Before) { ' ; source d avant fournie (-Before)' })"

# ================================================================ H. harnais
'--- H. harnais'
$fn112 = @((Get-LnFnAsts (Get-LnModule $mods '112')) | ForEach-Object { $_.Name })
Chk 'H1' ($fnA.Missing.Count -eq 0 -and $stateMissing.Count -eq 0 -and $fn112.Count -ge 30) "fonctions et etat reels trouves ($($fn112.Count) fonctions du module 112) ; absents : $(@($fnA.Missing + $stateMissing) -join ', ')"
Reset-LnWorld 'h'
Set-LnBanner 'B'; $hB = [string]$cmbDrive.Text; Set-LnBanner 'A'
Chk 'H2' ($hB -ceq 'B' -and [string]$cmbDrive.Text -ceq 'A' -and $cmbDrive.Items.Count -eq 6 -and -not $form.Visible -and $script:DriveReg.Count -eq 0 -and $script:CalibCalc -eq '12.10' -and $script:ContentCalc -eq '12.9') "liste du bandeau reelle a six elements, jamais affichee ; registre vide ; CalibCalc $($script:CalibCalc) et ContentCalc $($script:ContentCalc) inchanges"

# ================================================================ M. migration (scenario 1)
'--- M. migration : configuration 12.10, registre vide'
function New-LnStartJson {
    # Configuration 12.10 factice : l exemple suivi, ecrit par les fonctions de conversion (inchangees par le lot)
    Start-LnCase 'depart'
    $script:LevelBrand = 'Verbatim'
    $w = [ordered]@{
        file = ''; format = '(auto)'; preErase = $true; eraseEmpty = $true; eraseMode = 'hfreq'; noVerify = $false; reverse = $false; hardSectors = $false; genTg43 = $false; retries = 10
        precompOn = $true; precomp = '0=20:40=60'; precomp1 = '0=20:40=60'; postCheck = $true; repairMax = 3; precompStd = '0=20:40=60'; precompLong = [string]$script:PrecompLongDefault
        precompMaxNs = [int]$script:CalHardNsDefault; calibVersion = '12.10'; calibCalc = [string]$script:CalibCalc; calibAlgo = [string]$script:CalibAlgo
        precompCurves = (Export-CurveView $null); driveCurves = (Export-DriveCurves $null)
        levelAlgo = [string]$script:LevelFormat; levelShifts = @(@($script:LevelShifts.GetEnumerator() | Sort-Object { [string]$_.Key }) | ForEach-Object { ConvertTo-LevelConfig $_.Value })
        levelBrand = 'Verbatim'; levelBrands = @($script:LevelBrands | ForEach-Object { ConvertTo-LevelBrandConfig $_ })
        contentCalc = [string]$script:ContentCalc; driveFactors = @($script:ContentMeasures | ForEach-Object { ConvertTo-ContentConfig $_ }); targetDrive = (Export-TargetDrives)
        tracks = ''; densel = '(non)'; fakeIndex = ''; diskdefs = ''; calMode = 0; slowWrite = $false; slowWarmup = $true; calibWarmup = $true; calWarmupMinutes = 5.0; levelBeforeWrite = $true; levelBeforeWriteMode = 'content'
    }
    $cfg = [ordered]@{
        _comment = 'Configuration GreaseweazleGUI - régénérée automatiquement. Supprimable sans risque.'; _saved = '2026-11-10 10:00:00'
        global = [ordered]@{ device = 'COM7'; time = $false; detectNone = $false; drive = 'A' }
        write = $w
        ui = [ordered]@{ expert = $true; homeCalFormat = 'amiga.amigados'; homeCalHeads = $true; homeCalCyls = 0; curveTrend = $true }
    }
    return ($cfg | ConvertTo-Json -Depth 8)
}
function Get-LnDriveArgs {
    # Arguments de lecteur de toutes les commandes gw : Get-CommonArgs pour chaque connexion, avec et sans port ;
    # Get-CalibDriveArgsFor sans calibration, puis pour une calibration croisee A vers 0
    $l = @()
    foreach ($dev in '', 'COM7') {
        $txtDev.Text = $dev
        foreach ($c in $codes) { Set-LnBanner $c; $l += "$c/$dev : $((Get-CommonArgs) -join ' ')" }
        Set-LnBanner 'B'
        $script:Cal = $null; $l += "sans calibration/$dev : $((Get-CalibDriveArgsFor 'read') -join ' ')"
        $script:Cal = @{ Cross = @{ Src = 'A'; Tgt = '0' } }
        foreach ($v in 'read', 'write', 'erase', 'warmup') { $l += "croisee $v/$dev : $((Get-CalibDriveArgsFor $v) -join ' ')" }
        $script:Cal = $null
    }
    $txtDev.Text = ''; Set-LnBanner 'A'
    return ($l -join "`n")
}
function Invoke-LnRoundTrip([string]$tag, [string]$startJson) {
    # Meme configuration de depart : chargee par la vraie Load-Config, reenregistree par la vraie Save-Config (deux fois,
    # puis une troisieme apres rechargement de ce qu elle a ecrit)
    Reset-LnWorld $tag
    [System.IO.File]::WriteAllText($script:ConfigFile, $startJson, $utf8)
    $o = @{ Load = [bool](Load-Config) }
    Sync-PrecompCurves
    $o.LogLoad = (@($script:Log) -join "`n")
    $o.Keys = (Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key }))
    $o.View = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ',')
    $o.Target = Get-TargetDrive 'A'
    $o.Counts = "$($script:LevelShifts.Count)/$(@($script:LevelBrands).Count)/$(@($script:ContentMeasures).Count)"
    $o.Banner = [string]$cmbDrive.Text
    $o.Save1 = [bool](Save-Config); $o.B1 = [System.IO.File]::ReadAllBytes($script:ConfigFile)
    $o.Save2 = [bool](Save-Config); $o.B2 = [System.IO.File]::ReadAllBytes($script:ConfigFile)
    $o.Args = Get-LnDriveArgs
    Clear-LnMemory
    [void](Load-Config); Sync-PrecompCurves
    [void](Save-Config); $o.B3 = [System.IO.File]::ReadAllBytes($script:ConfigFile)
    $o.Log = (@($script:Log) -join "`n")
    $o.Files = (@(Get-ChildItem -LiteralPath (Split-Path -Parent $script:ConfigFile) -File | Sort-Object Name | ForEach-Object { $_.Name }) -join ',')
    return $o
}
$startJson = New-LnStartJson
$rtA = Invoke-LnRoundTrip 'm-apres' $startJson
$keys1210 = "0|std_h0`n0|std_h1`nA>0|std_h0`nA>0|std_h1`nA|std`nA|std_h0`nA|std_h1"
Reset-LnWorld 'm1'
[System.IO.File]::WriteAllText($script:ConfigFile, $startJson, $utf8)
$m1 = [bool](Load-Config); Sync-PrecompCurves
$idsM = Get-DriveIds
Chk 'M1' ($m1 -and $script:DriveReg.Count -eq 0 -and ($idsM -join ',') -ceq 'A,B,0,1,2,3' -and $rtA.Keys -ceq $keys1210 -and $rtA.View -ceq 'std,std_h0,std_h1' -and $rtA.Target -ceq '0' -and $rtA.Counts -ceq '2/2/3' -and $rtA.Banner -ceq 'A' -and (Get-DriveData 'A')['Any'] -and @((Get-DriveData 'A')['Keys']).Count -eq 3 -and @((Get-DriveData 'A')['Cross']).Count -eq 2) "configuration 12.10 chargee : registre vide, Get-DriveIds $($idsM -join ','), magasin ($($rtA.Keys -replace "`n", ', ')), vue de A ($($rtA.View)), lecteur cible de A : $($rtA.Target), niveaux/marques/facteurs $($rtA.Counts)"
function Get-LnBlockText($v) {
    # Bloc de la configuration en texte ; tableau : elements tries (l ordre des niveaux est celui d une table en memoire)
    if ($v -is [array]) { return (Get-LnSortedText @($v | ForEach-Object { $_ | ConvertTo-Json -Depth 8 -Compress })) }
    return ($v | ConvertTo-Json -Depth 8 -Compress)
}
function Get-LnCfgNorm([byte[]]$bytes) {
    # Fichier de configuration en texte de forme fixe, les niveaux de la calibration rapide tries
    $c = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    $lv = Get-LnBlockText $c.write.levelShifts
    $c.write.levelShifts = $null
    return (($c | ConvertTo-Json -Depth 8 -Compress) + "`n" + $lv)
}
$cfgStart = $startJson | ConvertFrom-Json
$cfg1 = [System.Text.Encoding]::UTF8.GetString($rtA.B1).TrimStart([char]0xFEFF) | ConvertFrom-Json
$blkSame = @()
foreach ($b in 'precompCurves', 'driveCurves', 'levelShifts', 'levelBrands', 'driveFactors', 'targetDrive') {
    $x = Get-LnBlockText $cfgStart.write.$b; $y = Get-LnBlockText $cfg1.write.$b
    if ($x -cne $y) { $blkSame += $b }
}
$top1 = @($cfg1.PSObject.Properties | ForEach-Object { [string]$_.Name })
Chk 'M2' ($rtA.Save1 -and $blkSame.Count -eq 0 -and [string]$cfg1.global.drive -ceq 'A' -and $top1 -notcontains 'drives' -and $rtA.Files -ceq 'GreaseweazleGUI.json' -and $rtA.Log -ceq '') "reenregistree : blocs precompCurves, driveCurves, levelShifts, levelBrands, driveFactors et targetDrive egaux a ceux lus (ecarts : $(if ($blkSame.Count) { $blkSame -join ', ' } else { 'aucun' })), global.drive A, aucun bloc drives ($($top1 -join ', ')), aucune copie de secours ni copie datee (fichiers : $($rtA.Files)), journal vide"
Chk 'M2b' ((Get-LnBytesId $rtA.B2) -ceq (Get-LnBytesId $rtA.B1) -and (Get-LnCfgNorm $rtA.B3) -ceq (Get-LnCfgNorm $rtA.B1)) "second enregistrement identique a l octet pres au premier ($(Get-LnBytesId $rtA.B1)) ; enregistrement apres rechargement du fichier ecrit : meme contenu (niveaux compares sans leur ordre, qui est celui d une table en memoire)"
# Save-Config privee des lignes du lot (les trois instructions qui citent $drCfg retirees de son texte reel) : meme fichier
$saveAst = Get-LnFnAst $mods '120' 'Save-Config'
$saveTxt = $saveAst.Extent.Text
$lotStmts = @($saveAst.Body.FindAll({ param($x) ($x -is $tAsg -and $x.Extent.Text.StartsWith('$drCfg = ')) -or ($x -is [System.Management.Automation.Language.IfStatementAst] -and $x.Extent.Text.StartsWith('if ($drCfg)')) }, $true) | Sort-Object { $_.Extent.StartOffset } -Descending)
$bare = $saveTxt
foreach ($st in $lotStmts) { $o0 = $st.Extent.StartOffset - $saveAst.Extent.StartOffset; $bare = $bare.Remove($o0, $st.Extent.Text.Length) }
$bare = $bare.Replace('function Save-Config {', 'function Save-ConfigSansLot {')
$genBare = Join-Path $here 'gen-save-sans-lot.ps1'
[System.IO.File]::WriteAllText($genBare, $bare + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
$bareAst = Get-LnAst $genBare
$bareLot = @($bareAst.FindAll({ param($x) ($x -is $tVar -and [string]$x.VariablePath.UserPath -eq 'drCfg') -or ($x -is $tCmd -and @('Export-DriveRegistry', 'Save-DriveRescue') -contains $x.GetCommandName()) }, $true)).Count
. $genBare
Reset-LnWorld 'm2c'
[System.IO.File]::WriteAllText($script:ConfigFile, $startJson, $utf8)
[void](Load-Config); Sync-PrecompCurves
$okBare = [bool](Save-ConfigSansLot); $bBare = [System.IO.File]::ReadAllBytes($script:ConfigFile)
Chk 'M2c' ($lotStmts.Count -eq 3 -and $bareLot -eq 0 -and $okBare -and (Get-LnBytesId $bBare) -ceq (Get-LnBytesId $rtA.B1)) "registre vide : Save-Config et la meme fonction privee des $($lotStmts.Count) instructions du lot ecrivent le meme fichier, a l octet pres ($(Get-LnBytesId $bBare))"
$argsWant = @()
foreach ($dev in '', 'COM7') {
    $sfx = if ($dev) { " --device=$dev" } else { '' }
    foreach ($c in $codes) { $argsWant += "$c/$dev : --drive=$c$sfx" }
    $argsWant += "sans calibration/$dev : --drive=B$sfx"
    $argsWant += "croisee read/$dev : --drive=0$sfx"
    foreach ($v in 'write', 'erase', 'warmup') { $argsWant += "croisee $v/$dev : --drive=A$sfx" }
}
Chk 'M2d' ($rtA.Args -ceq ($argsWant -join "`n")) "registre vide : --drive= de Get-CommonArgs pour chaque connexion (avec et sans port) et de Get-CalibDriveArgsFor (sans calibration, calibration croisee A vers 0) : ceux de la 12.10 ($(@($argsWant).Count) commandes)"
Chk-Inv 'M2e'

# M3 : configuration 12.9 (courbes sans champ drive, pas de bloc driveCurves), avec un bloc drives dont last designe un nom
Reset-LnWorld 'm3'
$cv129 = ConvertTo-CurveConfig (New-Cv '' 'std' $null '20/10/2026 12:00' '0=27:40=67'); $cv129.Remove('drive')
$cfgM3 = [ordered]@{
    global = [ordered]@{ drive = 'A' }
    write = [ordered]@{ eraseMode = 'hfreq'; contentCalc = '12.9'; calibWarmup = $true; precompStd = '0=27:40=67'; calibCalc = [string]$script:CalibCalc; precompCurves = [ordered]@{ std = $cv129 } }
    ui = [ordered]@{ homeCalHeads = $true }
    drives = [ordered]@{ list = @([ordered]@{ id = 'L20261120180211-01'; name = 'Sony MPF920'; conn = 'A'; created = '2026-11-20 18:02:11'; from = ''; at = '' }); last = [ordered]@{ A = 'sony mpf920' } }
}
[System.IO.File]::WriteAllText($script:ConfigFile, ($cfgM3 | ConvertTo-Json -Depth 8), $utf8)
$m3 = [bool](Load-Config); Sync-PrecompCurves
$kM3 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
Chk 'M3' ($m3 -and $kM3 -ceq 'A|std' -and [string]$script:DriveCurves['A|std'].Drive -ceq 'A' -and $script:DriveReg.Count -eq 1 -and (Get-DriveForConn 'A') -ceq 'Sony MPF920' -and @((Get-DriveData 'Sony MPF920')['Keys']).Count -eq 0 -and (Get-LogN '*rangée(s) par lecteur (A)*') -eq 1) "configuration 12.9 : la courbe sans lecteur reste rangee sous la connexion ($kM3, Drive A), jamais sous le nom que designe last ; last ramene a la casse de la fiche ($(Get-DriveForConn 'A'))"
Chk-Inv 'M3b'

# M4 : courbe d un autre calcul, en attente du choix, sous un nom
Reset-LnWorld 'm4'
$dcM4 = [ordered]@{}
$dcM4['Sony MPF920|std'] = ConvertTo-CurveConfig (New-Cv 'Sony MPF920' 'std' $null '30/10/2026 09:00' '0=20:40=60')
$dcM4['Sony MPF920|long'] = ConvertTo-CurveConfig (New-Cv 'Sony MPF920' 'long' $null '28/10/2026 09:00' '0=95:40=96' '' '12.9')
$cfgM4 = [ordered]@{
    global = [ordered]@{ drive = 'A' }
    write = [ordered]@{ eraseMode = 'hfreq'; contentCalc = '12.9'; calibWarmup = $true; calibCalc = [string]$script:CalibCalc; calibVersion = '12.11'; driveCurves = $dcM4 }
    ui = [ordered]@{ homeCalHeads = $true }
    drives = [ordered]@{ list = @([ordered]@{ id = 'L20261120180211-01'; name = 'Sony MPF920'; conn = 'A'; created = '2026-11-20 18:02:11'; from = 'A'; at = '2026-11-20 18:02:11' }); last = [ordered]@{ A = 'Sony MPF920' } }
}
[System.IO.File]::WriteAllText($script:ConfigFile, ($cfgM4 | ConvertTo-Json -Depth 8), $utf8)
$m4 = [bool](Load-Config); Sync-PrecompCurves
$oldK = if ($script:OldCalib) { @($script:OldCalib.Curves.GetEnumerator() | ForEach-Object { [string]$_.Key }) -join ',' } else { '' }
$dM4 = Get-DriveData 'Sony MPF920'
$r4 = Rename-NamedDrive 'Sony MPF920' 'Sony MPF-920'
$oldK2 = @($script:OldCalib.Curves.GetEnumerator() | ForEach-Object { [string]$_.Key }) -join ','
[void](Save-Config)
$kFile4 = Get-LnFileKeys $script:ConfigFile
Chk 'M4' ($m4 -and $oldK -ceq 'Sony MPF920|long' -and @($dM4['Keys']).Count -eq 2 -and $r4.Ok -and $r4.N -eq 2 -and $oldK2 -ceq 'Sony MPF-920|long' -and [string]$script:OldCalib.Curves['Sony MPF-920|long'].Drive -ceq 'Sony MPF-920' -and $kFile4 -ceq "Sony MPF-920|long`nSony MPF-920|std") "courbe d un autre calcul en attente du choix : gardee sous son identite ($oldK), comptee parmi les courbes du lecteur, renommee avec lui ($oldK2) et reecrite sous son nom ($($kFile4 -replace "`n", ', '))"
Chk-Inv 'M4b'

# ================================================================ N. nommer, renommer, deplacer, retirer le nom
'--- N. nommer, renommer, deplacer, retirer le nom (scenarios 2, 4, 7)'
Start-LnCase 'n1'
Set-DriveCurve '0>A' 'std' (New-Cv '0' 'std' $null '04/11/2026 08:00' '0=28:40=68' 'A')
$script:TargetDrives['0'] = 'A'
$sig0 = Get-LnMemSigs; $n0 = $script:DriveCurves.Count
$refs0 = @{}; foreach ($e in @($script:DriveCurves.GetEnumerator())) { $refs0[[string]$e.Key] = $e.Value }
$tb0 = @{ C = $script:DriveCurves; L = $script:LevelShifts; T = $script:TargetDrives; S = $script:DriveLast }
$n1 = Add-NamedDrive 'Sony MPF920' 'A' 'A'
$kN1 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
$kN1Want = "0>Sony MPF920|std`n0|std_h0`n0|std_h1`nSony MPF920>0|std_h0`nSony MPF920>0|std_h1`nSony MPF920|std`nSony MPF920|std_h0`nSony MPF920|std_h1"
Chk 'N1a' ($n1.Ok -and $n1.N -eq 6 -and $n1.Name -ceq 'Sony MPF920' -and $kN1 -ceq $kN1Want -and $script:DriveCurves.Count -eq $n0) "nommer A : chaque cle A|... devient Sony MPF920|..., A>0 devient Sony MPF920>0, 0>A devient 0>Sony MPF920 ; $($n1.N) courbes deplacees, $($script:DriveCurves.Count) enregistrements comme avant"
$sameObj = ([object]::ReferenceEquals($script:DriveCurves['Sony MPF920|std'], $refs0['A|std']) -and [object]::ReferenceEquals($script:DriveCurves['Sony MPF920>0|std_h1'], $refs0['A>0|std_h1']) -and [object]::ReferenceEquals($script:DriveCurves['0>Sony MPF920|std'], $refs0['0>A|std']) -and [object]::ReferenceEquals($script:DriveCurves['0|std_h0'], $refs0['0|std_h0']))
$cx = $script:DriveCurves['Sony MPF920>0|std_h0']; $cy = $script:DriveCurves['0>Sony MPF920|std']
Chk 'N1b' ($sameObj -and (Get-LnMemSigs) -ceq $sig0 -and [string]$script:DriveCurves['Sony MPF920|std'].Drive -ceq 'Sony MPF920' -and [string]$cx.Drive -ceq 'Sony MPF920' -and [string]$cx.Target -ceq '0' -and [string]$cy.Drive -ceq '0' -and [string]$cy.Target -ceq 'Sony MPF920') "memes courbes (valeurs, date, calcul et KeptFor egaux champ a champ) ; champs Drive et Target reecrits, la source comme la cible"
$brA = @($script:LevelBrands | Where-Object { $_.Brand -eq 'Verbatim' })[0]; $br0 = @($script:LevelBrands | Where-Object { $_.Brand -eq 'Maxell' })[0]
$cmN = @($script:ContentMeasures | ForEach-Object { [string]$_.Drive }) -join ','
$tdN = Get-LnSortedText @($script:TargetDrives.GetEnumerator() | ForEach-Object { "$($_.Key)>$($_.Value)" })
Chk 'N1c' ([string]$script:LevelShifts['std|c'].Drive -ceq 'Sony MPF920' -and [string]$script:LevelShifts['std_h0|0'].Drive -ceq '0' -and [string]$brA.Drive -ceq 'Sony MPF920' -and [string]$br0.Drive -ceq '0' -and $cmN -ceq 'Sony MPF920,Sony MPF920,0' -and $tdN -ceq "0>Sony MPF920`nSony MPF920>0" -and -not (Get-DriveData 'A')['Any']) "niveaux, memoire par marque, facteurs ($cmN) et lecteurs cibles, comme source et comme cible ($($tdN -replace "`n", ', ')) ; plus rien sous A"
Chk 'N1d' (-not [object]::ReferenceEquals($script:DriveCurves, $tb0.C) -and -not [object]::ReferenceEquals($script:LevelShifts, $tb0.L) -and -not [object]::ReferenceEquals($script:TargetDrives, $tb0.T) -and -not [object]::ReferenceEquals($script:DriveLast, $tb0.S) -and $tb0.C.ContainsKey('A|std') -and $tb0.T.ContainsKey('A')) 'tables reconstruites : magasin, niveaux, lecteurs cibles et derniers lecteurs sont des tables neuves, les anciennes n ont pas ete modifiees en place'
$recN1 = Get-LnRec 'Sony MPF920'
$bakN1 = Get-LnBaks
$bakCfg = if ($bakN1.Count) { Read-LnJson $bakN1[0] } else { $null }
$bakDrives = Get-LnProp $bakCfg 'drives'
Chk 'N1e' ($recN1 -and [string]$recN1.Conn -ceq 'A' -and [string]$recN1.Id -cmatch $rxId -and [string]$recN1.Created -ceq '2026-11-20 18:02:11' -and [string]$recN1.From -ceq 'A' -and [string]$recN1.At -ceq '2026-11-20 18:02:11' -and $script:DriveReg.Count -eq 1) "fiche : connexion A, identifiant date $($recN1.Id), creee le $($recN1.Created), From A et At poses"
Chk 'N1f' ($n1.Copy -and $bakN1.Count -eq 1 -and [System.IO.Path]::GetFileName($bakN1[0]) -ceq 'GreaseweazleGUI.json.lecteurs-20261120-180211.bak' -and $n1.Bak -eq $bakN1[0] -and (Get-LnFileSigs $bakN1[0]) -ceq $sig0 -and (Get-LnFileKeys $bakN1[0]) -cmatch '(?m)^A\|std$' -and $null -ne $bakDrives -and @(Get-LnProp $bakDrives 'list').Count -eq 0 -and (Get-LogN 'Configuration sauvegardée avant la modification des lecteurs enregistrés : *.lecteurs-20261120-180211.bak') -eq 1) "copie datee faite avant l action ($([System.IO.Path]::GetFileName("$($n1.Bak)"))) : les $n0 courbes d avant s y retrouvent sous leurs cles A|..., son bloc drives dit « aucun lecteur enregistre » (liste vide)"
Set-LnBanner 'Sony MPF920'
$aN1 = (Get-CommonArgs) -join ' '; $vN1 = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ','); $kdN = Get-DriveK 'Sony MPF920' 'std' 0 ''; $tgN = Get-TargetDrive
Set-LnBanner 'A'
$vA = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ','); $kdA = Get-DriveK 'A' 'std' 0 ''
Chk 'N1g' ($aN1 -ceq '--drive=A' -and $vN1 -ceq 'std,std_h0,std_h1' -and [string]$kdN.Src -eq 'lecteur' -and [double]$kdN.K -eq 0.8 -and $tgN -ceq '0' -and $vA -ceq '' -and $script:PrecompStd -ceq $script:PrecompStdDefault -and [string]$kdA.Src -eq 'defaut') "lecteur nomme dans le bandeau : --drive=A, vue de ses courbes ($vN1), son facteur ($($kdN.K)), son lecteur cible ($tgN) ; lecteur non enregistre de A : vue vide, profil d origine, facteur par defaut"
Chk-Inv 'N1h'

# N2 : jamais de fusion ; attribution a une fiche vide
Start-LnCase 'n2'
[void](Add-NamedDrive 'TEAC FD-235HF' '0' '0')
$st = Get-LnState; $nb = (Get-LnBaks).Count
$n2a = Add-NamedDrive 'teac fd-235hf' 'A' 'A'
Chk 'N2a' (-not $n2a.Ok -and $n2a.Why -ceq ((Fr 'T27') -f 'TEAC FD-235HF', 'A') -and (Get-LnState) -ceq $st -and (Get-LnBaks).Count -eq $nb) "nommer A du nom d une fiche qui a des donnees : refus sans effet ni copie (« $($n2a.Why) »)"
Start-LnCase 'n2b'
[void](Add-NamedDrive 'Mitsumi D359' 'B')
Set-DriveCurve 'A>Mitsumi D359' 'std' (New-Cv 'A' 'std' $null '06/11/2026 10:00' '0=29:40=69' 'Mitsumi D359')
$st = Get-LnState
$n2b = Add-NamedDrive 'Mitsumi D359' '0' '0'
$okB1 = (-not $n2b.Ok -and $n2b.Why -ceq ((Fr 'T27') -f 'Mitsumi D359', '0') -and (Get-LnState) -ceq $st)
Set-DriveCurve 'A>Mitsumi D359' 'std' $null
$script:TargetDrives['B'] = 'Mitsumi D359'
$st = Get-LnState
$n2c = Add-NamedDrive 'Mitsumi D359' '0' '0'
Chk 'N2b' ($okB1 -and -not $n2c.Ok -and $n2c.Why -ceq ((Fr 'T27') -f 'Mitsumi D359', '0') -and (Get-LnState) -ceq $st) 'fiche dont la seule donnee est une courbe croisee dont elle est la cible, puis le choix d un autre lecteur : refus sans effet dans les deux cas'
[void]$script:TargetDrives.Remove('B')
$idM = [string](Get-LnRec 'Mitsumi D359').Id
Step-LnClock 90
$sig0 = Get-LnMemSigs
$script:DriveChecked = '0'
$n2d = Add-NamedDrive 'mitsumi d359' '0' '0'
$recM = Get-LnRec 'Mitsumi D359'
Chk 'N2c' ($n2d.Ok -and $n2d.Name -ceq 'Mitsumi D359' -and $n2d.N -eq 4 -and [string]$recM.Id -ceq $idM -and [string]$recM.Conn -ceq '0' -and [string]$recM.From -ceq '0' -and [string]$recM.At -ceq '2026-11-20 18:03:41' -and [string]$recM.Created -ceq '2026-11-20 18:02:11' -and $script:DriveReg.Count -eq 1 -and $script:DriveCurves.ContainsKey('Mitsumi D359|std_h0') -and (Get-LnMemSigs) -ceq $sig0) "fiche sans aucune donnee : attribution a cette fiche, qui garde son identifiant ($idM) et son nom a sa casse ; From 0 et At poses ($($recM.At))"
Chk 'N2e' ($script:DriveChecked -ceq '') 'nommer le lecteur non enregistre confirme : confirmation de nouveau due'
Chk-Inv 'N2d'
# N2f (relecture de LN-a) : nom saisi avec des espaces repetes, ramenes a un seul (Test-DriveName) avant de chercher la fiche
Start-LnCase 'n2f'
[void](Add-NamedDrive 'Mitsumi D359' 'B')
$idF = [string](Get-LnRec 'Mitsumi D359').Id
$n2f = Add-NamedDrive 'mitsumi  d359' '0' '0'
$recF = Get-LnRec 'Mitsumi D359'
Chk 'N2f' ($n2f.Ok -and $n2f.Name -ceq 'Mitsumi D359' -and $recF -and [string]$recF.Id -ceq $idF -and [string]$recF.Conn -ceq '0' -and $script:DriveReg.Count -eq 1 -and $script:DriveCurves.ContainsKey('Mitsumi D359|std_h0')) "nom saisi « mitsumi  d359 » (deux espaces) : attribue a la fiche vide « Mitsumi D359 », jamais refuse comme doublon (« $($n2f.Why) »)"

# N3 : renommer, aller et retour ; N3b : correction de casse
Start-LnCase 'n3'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); [void](Add-NamedDrive 'TEAC FD-235HF' '0' '0')
$script:DriveLast = @{ 'A' = 'Sony MPF920'; '0' = 'TEAC FD-235HF' }
$st0 = Get-LnState; $sig0 = Get-LnMemSigs; $idS = [string](Get-LnRec 'Sony MPF920').Id
Step-LnClock 60
$script:DriveChecked = 'sony mpf920'
$n3 = Rename-NamedDrive 'Sony MPF920' 'Sony MPF-920 n°2'
$kN3 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
$rN3 = Get-LnRec 'Sony MPF-920 n°2'
$bakN3 = @((Get-LnBaks) | Where-Object { $_ -like '*-180311.bak' })
Chk 'N3a' ($n3.Ok -and $n3.N -eq 5 -and $kN3 -ceq "Sony MPF-920 n°2>TEAC FD-235HF|std_h0`nSony MPF-920 n°2>TEAC FD-235HF|std_h1`nSony MPF-920 n°2|std`nSony MPF-920 n°2|std_h0`nSony MPF-920 n°2|std_h1`nTEAC FD-235HF|std_h0`nTEAC FD-235HF|std_h1" -and $rN3 -and [string]$rN3.Id -ceq $idS -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF-920 n°2,TEAC FD-235HF' -and [string]$script:DriveLast['A'] -ceq 'Sony MPF-920 n°2' -and [string]$script:TargetDrives['Sony MPF-920 n°2'] -ceq 'TEAC FD-235HF' -and (Get-LnMemSigs) -ceq $sig0 -and $bakN3.Count -eq 1 -and (Get-LnFileSigs $bakN3[0]) -ceq $sig0) "renommer : les huit porteurs suivent ($($n3.N) courbes), identifiant et rang de la fiche gardes, last suit ; copie datee d abord, avec les memes courbes"
Chk 'N3h' ($script:DriveChecked -ceq '') 'renommer le lecteur confirme : confirmation de nouveau due ($script:DriveChecked vide)'
Chk-Inv 'N3b'
$n3r = Rename-NamedDrive 'sony mpf-920 N°2' 'Sony MPF920'
Chk 'N3c' ($n3r.Ok -and (Get-LnState) -ceq $st0) 'renommer en sens inverse : aller et retour = etat de depart (porteurs et registre, a la casse pres)'
$st = Get-LnState; $nb = (Get-LnBaks).Count
$n3x = Rename-NamedDrive 'Sony MPF920' 'teac FD-235hf'
Chk 'N3d' (-not $n3x.Ok -and $n3x.Why -ceq ((Fr 'T23') -f 'TEAC FD-235HF') -and (Get-LnState) -ceq $st -and (Get-LnBaks).Count -eq $nb) "renommer vers le nom d une autre fiche a la casse pres : refus sans effet ni copie (« $($n3x.Why) »)"
Start-LnCase 'n3b'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); [void](Add-NamedDrive 'teac fd-235hf' '0' '0')
$script:DriveLast = @{ '0' = 'teac fd-235hf' }
$nC = $script:DriveCurves.Count; $nL = $script:LevelShifts.Count; $nB = @($script:LevelBrands).Count; $nF = @($script:ContentMeasures).Count; $nT = $script:TargetDrives.Count; $sig0 = Get-LnMemSigs
$idT = [string](Get-LnRec 'teac fd-235hf').Id
$n3b = Rename-NamedDrive 'teac fd-235hf' 'TEAC FD-235HF'
$kC = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
$fC = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | Where-Object { [string]$_.Key -like '*teac*' } | ForEach-Object { "$($_.Value.Drive)/$($_.Value.Target)" })
$recT = Get-LnRec 'TEAC FD-235HF'
Chk 'N3e' ($n3b.Ok -and $n3b.N -eq 4 -and $script:DriveCurves.Count -eq $nC -and $script:LevelShifts.Count -eq $nL -and @($script:LevelBrands).Count -eq $nB -and @($script:ContentMeasures).Count -eq $nF -and $script:TargetDrives.Count -eq $nT -and $script:DriveReg.Count -eq 2 -and (Get-LnMemSigs) -ceq $sig0 -and $n3b.Copy -and (Get-LnFileSigs $n3b.Bak) -ceq $sig0) "correction de casse (teac fd-235hf en TEAC FD-235HF) : $($n3b.N) courbes deplacees, aucune perdue (les memes $nC qu avant, et dans la copie datee) ; nombres de cles, de niveaux, d entrees de marque, de facteurs, de lecteurs cibles et de fiches inchanges"
Chk 'N3f' ($kC -ceq "Sony MPF920>TEAC FD-235HF|std_h0`nSony MPF920>TEAC FD-235HF|std_h1`nSony MPF920|std`nSony MPF920|std_h0`nSony MPF920|std_h1`nTEAC FD-235HF|std_h0`nTEAC FD-235HF|std_h1" -and $fC -ceq "Sony MPF920/TEAC FD-235HF`nSony MPF920/TEAC FD-235HF`nTEAC FD-235HF/`nTEAC FD-235HF/" -and $recT -and [string]$recT.Id -ceq $idT -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920,TEAC FD-235HF' -and [string]$script:DriveLast['0'] -ceq 'TEAC FD-235HF' -and [string]$script:TargetDrives['Sony MPF920'] -ceq 'TEAC FD-235HF' -and [string]$script:LevelShifts['std_h0|0'].Drive -ceq 'TEAC FD-235HF' -and (Get-DriveConn 'teac FD-235hf') -ceq '0') 'cles du magasin, champs Drive et Target, lecteur cible, last et cle du registre a la nouvelle casse (comparaison exacte) ; rang et identifiant de la fiche inchanges'
Chk-Inv 'N3g'

# N4 : deplacer
Start-LnCase 'n4'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); [void](Add-NamedDrive 'TEAC FD-235HF' 'A')
$script:DriveLast = @{ 'A' = 'Sony MPF920' }; $script:DriveChecked = 'sony MPF920'
$idS = [string](Get-LnRec 'Sony MPF920').Id
function Get-LnDataState { return (@((Get-LnState) -split "`n" | Where-Object { $_ -cnotmatch '^(S |R\d)' }) -join "`n") }   # sans last ni registre
$stData = Get-LnDataState
$nb = (Get-LnBaks).Count
$n4 = Move-NamedDrive 'sony mpf920' '0'
Set-LnBanner 'Sony MPF920'; $aN4 = (Get-CommonArgs) -join ' '; Set-LnBanner 'A'
Chk 'N4' ($n4.Ok -and $n4.Old -ceq 'A' -and $n4.Name -ceq 'Sony MPF920' -and (Get-LnDataState) -ceq $stData -and [string](Get-LnRec 'Sony MPF920').Conn -ceq '0' -and [string](Get-LnRec 'Sony MPF920').Id -ceq $idS -and $script:DriveLast.Count -eq 0 -and $script:DriveChecked -ceq '' -and (Get-LnBaks).Count -eq $nb -and $aN4 -ceq '--drive=0' -and (Get-DriveForConn 'A') -ceq 'A') "deplacer de A vers 0 : aucune cle, aucun champ de donnee ne change ; connexion de la fiche 0, entree de last retiree, lecteur a confirmer de nouveau, aucune copie ; ses commandes portent $aN4"
$n4x = Move-NamedDrive 'Sony MPF920' 'a'
Chk 'N4b' (-not $n4x.Ok -and $n4x.Why -ceq (Fr 'T25') -and [string](Get-LnRec 'Sony MPF920').Conn -ceq '0') "connexion « a » (gw l accepterait, la liste du bandeau non) : refus (« $($n4x.Why) »)"
Chk-Inv 'N4c'

# N5 : retirer seulement le nom
Start-LnCase 'n5'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A')
[void](Move-NamedDrive 'Sony MPF920' 'B')
$script:DriveLast = @{ 'B' = 'Sony MPF920' }
$sig0 = Get-LnMemSigs
Step-LnClock 60
$n5 = Remove-NamedDrive 'Sony MPF920' -KeepData
$kN5 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
Chk 'N5a' ($n5.Ok -and $n5.N -eq 5 -and $n5.Conn -ceq 'B' -and $kN5 -ceq "0|std_h0`n0|std_h1`nB>0|std_h0`nB>0|std_h1`nB|std`nB|std_h0`nB|std_h1" -and [string]$script:TargetDrives['B'] -ceq '0' -and [string]$script:LevelShifts['std|c'].Drive -ceq 'B' -and $script:DriveReg.Count -eq 0 -and $script:DriveLast.Count -eq 0 -and (Get-LnMemSigs) -ceq $sig0 -and $n5.Copy -and (Get-LnFileSigs $n5.Bak) -ceq $sig0) "retirer seulement le nom : ses donnees vont sous le code de la connexion de sa fiche (B, ou qu il ait ete nomme), fiche disparue, last retire ; aucune courbe perdue, copie datee d abord"
Chk-Inv 'N5b'
Start-LnCase 'n5c'
[void](Add-NamedDrive 'Mitsumi D359' '0')
Set-DriveCurve 'Mitsumi D359' 'long' (New-Cv 'Mitsumi D359' 'long' $null '07/11/2026 10:00' '0=30:40=70')
$st = Get-LnState; $nb = (Get-LnBaks).Count
$n5c = Remove-NamedDrive 'Mitsumi D359' -KeepData
Chk 'N5c' (-not $n5c.Ok -and $n5c.Why -ceq ((Fr 'T28') -f '0') -and (Get-LnState) -ceq $st -and (Get-LnBaks).Count -eq $nb) "le code de sa connexion porte deja une donnee : refus sans effet ni copie (« $($n5c.Why) »)"
Start-LnCase 'n5d'
$script:DriveCurves = @{}; Set-DriveCurve 'Sans Fil' 'std' (New-Cv 'Sans Fil' 'std' $null '07/11/2026 10:00' '0=31:40=71')
$script:LevelShifts = @{}; $script:LevelBrands = @(); $script:ContentMeasures = @(); $script:TargetDrives = @{}
$rep5 = @(Repair-DriveRegistry)
$st = Get-LnState
$n5d = Remove-NamedDrive 'Sans Fil' -KeepData
Chk 'N5d' ($rep5.Count -eq 1 -and -not $n5d.Ok -and $n5d.Why -ceq (Fr 'T25') -and (Get-LnState) -ceq $st) "fiche sans connexion : le nom ne peut pas etre retire seul (« $($n5d.Why) »)"

# N6 : copies datees
$n6v = @()
foreach ($kind in 'facteur', 'marque', 'cible', 'cible-de') {
    Start-LnCase "n6-$kind"
    $script:DriveCurves = @{}; $script:LevelShifts = @{}; $script:LevelBrands = @(); $script:ContentMeasures = @(); $script:TargetDrives = @{}; Sync-PrecompCurves
    switch ($kind) {
        'facteur'  { $script:ContentMeasures = @((New-Cm 'A' 0 0.8)) }
        'marque'   { $script:LevelBrands = @((New-Br 'Verbatim' 'A' 'std' 'c' '30/10/2026 09:00')) }
        'cible'    { $script:TargetDrives['A'] = '0' }
        'cible-de' { $script:TargetDrives['0'] = 'A' }
    }
    $r6 = Add-NamedDrive 'Sony MPF920' 'A' 'A'
    $moved = switch ($kind) {
        'facteur'  { [string]$script:ContentMeasures[0].Drive -ceq 'Sony MPF920' }
        'marque'   { [string]$script:LevelBrands[0].Drive -ceq 'Sony MPF920' }
        'cible'    { [string]$script:TargetDrives['Sony MPF920'] -ceq '0' -and -not $script:TargetDrives.ContainsKey('A') }
        'cible-de' { [string]$script:TargetDrives['0'] -ceq 'Sony MPF920' }
    }
    if (-not ($r6.Ok -and $r6.N -eq 0 -and $r6.Copy -and (Get-LnBaks).Count -eq 1 -and $moved -and (Test-LnInv).Count -eq 0)) { $n6v += $kind }
}
Chk 'N6a' ($n6v.Count -eq 0) "lecteur sans courbe, qui n a qu un facteur mesure, qu une entree de la memoire par marque, qu un lecteur cible, ou qui n est que la cible d un autre : copie faite de meme, donnee attribuee ; ecarts : $(if ($n6v.Count) { $n6v -join ', ' } else { 'aucun' })"
Start-LnCase 'n6b'
$st = Get-LnState
$script:RealSave = ${function:Save-Config}
$script:LockAfterSave = $true; $script:Lock = $null
function Save-Config {
    # Vraie Save-Config, puis fichier de configuration tenu ouvert sans partage : la copie datee qui suit echoue
    $r = & $script:RealSave
    if ($script:LockAfterSave -and -not $script:Lock) { $script:Lock = [System.IO.File]::Open($script:ConfigFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
    return $r
}
$n6b = Add-NamedDrive 'Sony MPF920' 'A' 'A'
if ($script:Lock) { $script:Lock.Dispose(); $script:Lock = $null }
$script:LockAfterSave = $false
${function:Save-Config} = $script:RealSave
Chk 'N6b' (-not $n6b.Ok -and $n6b.Why -ceq (Fr 'T29') -and (Get-LnState) -ceq $st -and (Get-LnBaks).Count -eq 0 -and (Get-LogN 'Configuration non copiée avant la modification des lecteurs enregistrés : *. Modification annulée : rien n''est changé.') -eq 1) "copie en echec (fichier de configuration tenu ouvert) : action annulee, etat identique, aucune fiche (« $($n6b.Why) », une ligne de journal)"
$blkAfterFail = Get-LnProp (Read-LnJson $script:ConfigFile) 'drives'
[void](Save-Config)
$blkNext = Get-LnProp (Read-LnJson $script:ConfigFile) 'drives'
Chk 'N6c' ($null -ne $blkAfterFail -and @(Get-LnProp $blkAfterFail 'list').Count -eq 0 -and $null -eq $blkNext -and -not $script:DriveBlockKeep -and -not (Test-Path -LiteralPath (Get-LnRescue))) 'l enregistrement fait avant la copie ecrit un bloc drives a liste vide ; l enregistrement suivant, registre toujours vide, n en ecrit plus (cles de la 12.10), aucune copie de secours'
Start-LnCase 'n6d'
[void](Save-Config)
$bStale = [System.IO.File]::ReadAllBytes($script:ConfigFile)
Set-DriveCurve 'A' 'long' (New-Cv 'A' 'long' $null '10/11/2026 10:00' '0=34:40=74')
$st = Get-LnState
[System.IO.File]::SetAttributes($script:ConfigFile, [System.IO.FileAttributes]::ReadOnly)
# Comme dans l application, ou une erreur d ecriture de Set-Content est seulement affichee et laisse Save-Config rendre vrai
$ErrorActionPreference = 'Continue'
$n6d = $null; $errN6 = ''
try { $n6d = Add-NamedDrive 'Sony MPF920' 'A' 'A' } catch { $errN6 = [string]$_.Exception.Message } finally { $ErrorActionPreference = 'Stop'; [System.IO.File]::SetAttributes($script:ConfigFile, [System.IO.FileAttributes]::Normal) }
Chk 'N6d' ($errN6 -ceq '' -and $n6d -and -not $n6d.Ok -and $n6d.Why -ceq (Fr 'T29') -and (Get-LnState) -ceq $st -and (Get-LogN (Fr 'T58b')) -eq 1 -and (Get-LogN 'ERREUR sauvegarde configuration : *') -eq 1 -and (Get-LnBaks).Count -eq 0 -and (Get-LnBytesId ([System.IO.File]::ReadAllBytes($script:ConfigFile))) -ceq (Get-LnBytesId $bStale)) "enregistrement en echec (fichier de configuration en lecture seule, erreurs seulement affichees comme dans l application) : Save-Config rend faux, action annulee, etat identique, aucune copie d un fichier perime (« $(if ($n6d) { $n6d.Why }) », ligne « non enregistree » au journal)"
# Dossier du fichier de configuration disparu : sous PowerShell 7, Set-Content n y leve qu une erreur affichee, que seul
# l arret demande par Protect-DriveData fait passer par le catch de Save-Config
Start-LnCase 'n6d2'
$st = Get-LnState
$goodCfg = $script:ConfigFile
$script:ConfigFile = Join-Path (Join-Path (Split-Path -Parent $goodCfg) 'dossier-absent') 'GreaseweazleGUI.json'
$ErrorActionPreference = 'Continue'
$n6d2 = $null; $errN6 = ''
try { $n6d2 = Add-NamedDrive 'Sony MPF920' 'A' 'A' } catch { $errN6 = [string]$_.Exception.Message } finally { $ErrorActionPreference = 'Stop'; $script:ConfigFile = $goodCfg }
Chk 'N6d2' ($errN6 -ceq '' -and $n6d2 -and -not $n6d2.Ok -and $n6d2.Why -ceq (Fr 'T29') -and (Get-LnState) -ceq $st -and (Get-LogN (Fr 'T58b')) -eq 1 -and (Get-LogN 'ERREUR sauvegarde configuration : *') -eq 1 -and (Get-LogN 'Configuration non copiée*') -eq 0 -and (Get-LnBaks).Count -eq 0) 'enregistrement en echec (dossier du fichier de configuration disparu, erreurs seulement affichees) : l erreur d ecriture est arretee, Save-Config la note et rend faux, action annulee avant toute copie, etat identique'
Start-LnCase 'n6e'
$taken = $script:ConfigFile + '.lecteurs-20261120-180211.bak'
[System.IO.File]::WriteAllText($taken, 'copie existante', $utf8)
[System.IO.File]::SetLastWriteTime($taken, $script:TNow)
$n6e = Add-NamedDrive 'Sony MPF920' 'A' 'A'
Chk 'N6e' ($n6e.Ok -and [System.IO.Path]::GetFileName([string]$n6e.Bak) -ceq 'GreaseweazleGUI.json.lecteurs-20261120-180211-2.bak' -and [System.IO.File]::ReadAllText($taken, [System.Text.Encoding]::UTF8) -ceq 'copie existante') "nom de copie deja pris : suffixe -2 ($([System.IO.Path]::GetFileName([string]$n6e.Bak))), la copie existante est intacte"
$refBak = $script:ConfigFile + '.ref-std-20261030-0900.bak'
[System.IO.File]::WriteAllText($refBak, 'copie de calibration', $utf8)
$names6 = @('Sony MPF-920', 'Sony 3', 'Sony 4', 'Sony 5', 'Sony 6')
$cur6 = 'Sony MPF920'; $ok6 = $true
foreach ($nn in $names6) { Step-LnClock 60; $r6 = Rename-NamedDrive $cur6 $nn; if (-not $r6.Ok) { $ok6 = $false }; $cur6 = $nn }
$left6 = @((Get-LnBaks) | ForEach-Object { [System.IO.Path]::GetFileName($_) })
Chk 'N6f' ($ok6 -and $left6.Count -eq 5 -and $left6 -notcontains 'GreaseweazleGUI.json.lecteurs-20261120-180211.bak' -and $left6 -notcontains 'GreaseweazleGUI.json.lecteurs-20261120-180211-2.bak' -and $left6 -contains 'GreaseweazleGUI.json.lecteurs-20261120-180711.bak' -and (Test-Path -LiteralPath $refBak) -and (Get-LogN 'Ancienne sauvegarde de configuration supprimée (5 gardées) : *') -eq 2) "sept copies .lecteurs- successives : les cinq plus recentes gardees ($($left6.Count)), la copie .ref- de calibration n est ni comptee ni supprimee"
Chk-Inv 'N6g'

# N7 : refus pendant une operation, ou avec une calibration B en attente
Start-LnCase 'n7'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A')
$st = Get-LnState
$busyBad = @()
$busySet = [ordered]@{
    'restauration' = { $script:Restore = @{ Step = 1 } }; 'calibration' = { $script:Cal = @{ Drive = 'A' } }; 'contrôle après écriture' = { $script:Rep = @{ } }; 'préchauffage du lecteur' = { $script:WriteWarm = @{ } }
    'détection des lecteurs' = { $script:Detect = @{ } }; 'commande gw' = { $script:GwProc = [pscustomobject]@{ HasExited = $false } }; "séquence d'étapes" = { $script:Chain.Enqueue({ }) }; 'mesure continue de la qualité' = { $script:AlignLoop = $true }
}
foreach ($lbl in @($busySet.Keys)) {
    $script:Restore = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null; $script:Detect = $null; $script:GwProc = $null; $script:Chain.Clear(); $script:AlignLoop = $false
    . $busySet[$lbl]
    $wantWhy = (Fr 'T71') -f $lbl
    $rs = @((Add-NamedDrive 'TEAC FD-235HF' '0' '0'), (Rename-NamedDrive 'Sony MPF920' 'Sony 2'), (Move-NamedDrive 'Sony MPF920' '0'), (Remove-NamedDrive 'Sony MPF920'), (Remove-NamedDrive 'Sony MPF920' -KeepData))
    if (@($rs | Where-Object { -not $_.Ok -and [string]$_.Why -ceq $wantWhy }).Count -ne 5 -or (Get-AppBusy -Text) -cne $lbl -or (Get-LnState) -cne $st) { $busyBad += $lbl }
}
$script:Restore = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null; $script:Detect = $null; $script:GwProc = $null; $script:Chain.Clear(); $script:AlignLoop = $false
Chk 'N7a' ($busyBad.Count -eq 0) "les quatre actions refusent pendant une operation, pour chacune des $($busySet.Count) raisons de Get-AppBusy ; le texte porte le libelle rendu par Get-AppBusy -Text (« $((Fr 'T71') -f 'calibration') ») ; ecarts : $(if ($busyBad.Count) { $busyBad -join ', ' } else { 'aucun' })"
$script:CalRedo = @{ Stage = 'confirm' }
$rs = @((Add-NamedDrive 'TEAC FD-235HF' '0' '0'), (Rename-NamedDrive 'Sony MPF920' 'Sony 2'), (Move-NamedDrive 'Sony MPF920' '0'), (Remove-NamedDrive 'Sony MPF920'))
$script:CalRedo = $null
Chk 'N7b' (@($rs | Where-Object { -not $_.Ok -and [string]$_.Why -ceq (Fr 'T30') }).Count -eq 4 -and (Get-LnState) -ceq $st) "calibration B en attente de sa decision : les quatre actions refusent (« $(Fr 'T30') »), etat identique"

# N8 : erreur pendant le premier temps d Edit-DriveData
Start-LnCase 'n8'
$st = Get-LnState
$script:RealSplit = ${function:Split-CrossDrive}; $script:SplitN = 0
function Split-CrossDrive([string]$drive) { $script:SplitN++; if ($script:SplitN -ge 11) { throw 'erreur provoquee par le test' }; return (& $script:RealSplit $drive) }
$n8 = Edit-DriveData 'A' 'Sony MPF920'
$splitSeen = $script:SplitN
${function:Split-CrossDrive} = $script:RealSplit
Chk 'N8' (-not $n8.Ok -and $n8.Why -ceq 'erreur provoquee par le test' -and $splitSeen -eq 11 -and (Get-LnState) -ceq $st -and $script:DriveCurves.ContainsKey('A|std') -and [string]$script:DriveCurves['A|std'].Drive -ceq 'A') "erreur provoquee au milieu du calcul d Edit-DriveData (quatrieme cle du magasin, apres le controle de fusion) : rien n a change, ni table ni champ"
$n8b = Edit-DriveData 'A' 'Sony MPF920' -Check
Chk 'N8b' ($n8b.Ok -and $n8b.N -eq 5 -and (Get-LnState) -ceq $st) "Edit-DriveData -Check : decision et compte ($($n8b.N) courbes), sans aucun effet"

# N9 : nom fait de chiffres (jamais pris pour un rang de la table ordonnee)
Start-LnCase 'n9'
[void](Add-NamedDrive 'Sony MPF920' 'A'); [void](Add-NamedDrive 'TEAC FD-235HF' 'B')
$n9 = Add-NamedDrive '1541' '0' '0'
$r9 = Rename-NamedDrive '1541' '1571'
$ids9 = Get-DriveIds
Chk 'N9' ($n9.Ok -and $r9.Ok -and (Get-DriveConn '1571') -ceq '0' -and (Get-DriveConn '1') -ceq '1' -and (Get-DriveConn '1541') -ceq '' -and (Get-DriveLabel '1571') -ceq '1571 (0)' -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920,TEAC FD-235HF,1571' -and ($ids9 -join ',') -ceq 'A,B,0,1,2,3,Sony MPF920,TEAC FD-235HF,1571' -and $script:DriveCurves.ContainsKey('1571|std_h0')) "nom fait de chiffres (1541, renomme 1571) : fiche, connexion ($(Get-DriveConn '1571')), libelle ($(Get-DriveLabel '1571')) et courbes justes ; la connexion 1 reste la connexion 1"
Chk-Inv 'N9b'

# ================================================================ S. supprimer
'--- S. supprimer (scenario 7)'
Start-LnCase 's1'
Set-DriveCurve '0>A' 'std' (New-Cv '0' 'std' $null '04/11/2026 08:00' '0=28:40=68' 'A')
$script:TargetDrives['0'] = 'A'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A')
$script:DriveLast = @{ 'A' = 'Sony MPF920' }; $script:DriveChecked = 'Sony MPF920'
$sig0 = Get-LnMemSigs; $n0 = $script:DriveCurves.Count
Step-LnClock 60
$s1 = Remove-NamedDrive 'Sony MPF920'
$kS1 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
Chk 'S1a' ($s1.Ok -and $s1.N -eq 6 -and $kS1 -ceq "0|std_h0`n0|std_h1" -and $script:TargetDrives.Count -eq 0 -and $script:LevelShifts.Count -eq 1 -and @($script:LevelBrands).Count -eq 1 -and (@($script:ContentMeasures | ForEach-Object { [string]$_.Drive }) -join ',') -ceq '0' -and $script:DriveReg.Count -eq 0 -and $script:DriveLast.Count -eq 0 -and $script:DriveChecked -ceq '' -and -not (Get-DriveData 'A')['Any'] -and -not (Get-DriveData 'Sony MPF920')['Any']) "supprimer : ses $($s1.N) courbes (propres et croisees, des deux cotes), ses niveaux, sa memoire par marque, ses facteurs, son lecteur cible et le choix de ce lecteur comme cible d un autre sont retires ; rien sous la connexion ni sous un autre nom ; il reste $($script:DriveCurves.Count) courbes sur $n0"
Chk 'S1b' ($s1.Copy -and (Test-Path -LiteralPath $s1.Bak) -and (Get-LnFileSigs $s1.Bak) -ceq $sig0 -and @(Get-LnProp (Get-LnProp (Read-LnJson $s1.Bak) 'drives') 'list').Count -eq 1) "copie obligatoire faite d abord ($([System.IO.Path]::GetFileName([string]$s1.Bak))) : les $n0 courbes d avant la suppression s y retrouvent, avec la fiche"
Chk-Inv 'S1c'
Step-LnClock 60
$s2 = Add-NamedDrive 'Sony MPF920' 'A'
Chk 'S2' ($s2.Ok -and -not (Get-DriveData 'Sony MPF920')['Any'] -and (Get-DriveDataText (Get-DriveData 'Sony MPF920')) -ceq 'aucune' -and [string](Get-LnRec 'Sony MPF920').Id -cmatch $rxId) 'lecteur recree sous le meme nom : aucune donnee'
$nb = (Get-LnBaks).Count
$s3 = Remove-NamedDrive 'Sony MPF920'
Chk 'S3' ($s3.Ok -and -not $s3.Copy -and $s3.N -eq 0 -and (Get-LnBaks).Count -eq $nb -and $script:DriveReg.Count -eq 0) 'lecteur sans aucune donnee : supprime sans copie'
Start-LnCase 's4'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A')
$st = Get-LnState
$goodCfg = $script:ConfigFile
$script:ConfigFile = Join-Path (Join-Path (Split-Path -Parent $goodCfg) 'dossier-absent') 'GreaseweazleGUI.json'
$s4 = Remove-NamedDrive 'Sony MPF920'
$script:ConfigFile = $goodCfg
Chk 'S4' (-not $s4.Ok -and $s4.Why -ceq (Fr 'T29') -and (Get-LnState) -ceq $st) 'suppression d un lecteur qui a des donnees, enregistrement en echec : rien n est supprime'
Chk-Inv 'S4b'

# ================================================================ V. noms
'--- V. regles d un nom (scenario 8)'
Reset-LnWorld 'v'
function Get-Why([string]$name, [string]$self = '') { return [string](Test-DriveName $name $self).Why }
Chk 'V1' ((Get-Why '') -ceq (Fr 'T18') -and (Get-Why "  `t ") -ceq (Fr 'T18')) "vide, blancs : « $(Fr 'T18') »"
$v2 = @()
foreach ($ch in '|', '>', '&', '{', '}', '(', ')', '"', '«', "'", ',', '*', '?', '[', '/', '\') { $w = Get-Why "Sony${ch}MPF"; if ($w -cne ((Fr 'T20') -f $ch)) { $v2 += $ch } }
$wNl = Get-Why "Sony`nMPF"; $wTab = Get-Why "Sony`tMPF"
Chk 'V2' ($v2.Count -eq 0 -and $wNl -ceq ((Fr 'T20') -f 'U+000A') -and $wTab -ceq ((Fr 'T20') -f 'U+0009')) "signes non admis (| > & accolades, parentheses, guillemets, apostrophe, virgule, * ? [ / \), retour a la ligne et tabulation : refus qui cite le caractere ; ecarts : $(if ($v2.Count) { $v2 -join ' ' } else { 'aucun' })"
$v3 = @(); foreach ($c in 'a', 'B', '0', '1', '2', '3', 'A', 'b') { if ((Get-Why $c) -cne ((Fr 'T22') -f $c)) { $v3 += $c } }
Chk 'V3' ($v3.Count -eq 0) "a, B, 0 a 3 : « $((Fr 'T22') -f 'a') »"
$v3b = @(); foreach ($w in 'count', 'Keys', 'VALUES', 'SyncRoot', 'Item', 'isfixedsize', 'IsReadOnly', 'IsSynchronized', 'psobject', 'PSBase', 'PSAdapted', 'PSExtended', 'PSTypeNames') { if ((Get-Why $w) -cne ((Fr 'T69') -f $w)) { $v3b += $w } }
[void](Add-NamedDrive 'Counter' 'A'); [void](Add-NamedDrive 'Keystone' 'B'); [void](Add-NamedDrive 'Valuestar' '0')
[void](Set-TargetDrive 'Counter' 'Keystone'); [void](Set-TargetDrive 'A' 'Valuestar')
$etd = Export-TargetDrives; $idsV = Get-DriveIds
Chk 'V3b' ($v3b.Count -eq 0 -and @($script:DriveReserved).Count -eq 13 -and $script:DriveReg.Count -is [int] -and $script:DriveReg.Count -eq 3 -and ($idsV -join ',') -ceq 'A,B,0,1,2,3,Counter,Keystone,Valuestar' -and $etd.Count -eq 2 -and [string]$etd['Counter'] -ceq 'Keystone') "les 13 mots reserves refuses, casse ignoree (« $((Fr 'T69') -f 'count') ») ; registre peuple de noms admis voisins : Count entier ($($script:DriveReg.Count)), Get-DriveIds rend les six codes puis les noms, Export-TargetDrives rend $($etd.Count) entrees pour 2 lecteurs cibles choisis"
Chk 'V4' ((Get-Why 'counter') -ceq ((Fr 'T23') -f 'Counter') -and (Get-Why 'COUNTER' 'Counter') -ceq '' -and (Get-Why 'keystone' 'Counter') -ceq ((Fr 'T23') -f 'Keystone')) "doublon a la casse pres : « $((Fr 'T23') -f 'Counter') » ; la fiche modifiee n est pas un doublon d elle-meme"
$n24 = 'i' * 24; $n25 = 'i' * 25
Chk 'V5' ((Test-DriveName $n24).Ok -and (Get-Why $n25) -ceq ((Fr 'T19') -f '24')) "24 caracteres admis, 25 refuses (« $((Fr 'T19') -f '24') »)"
Chk 'V6' ((Get-Why 'Éé-°') -ceq (Fr 'T21') -and (Get-Why '. _ +') -ceq (Fr 'T21') -and (Test-DriveName 'É1').Ok) "nom sans lettre non accentuee ni chiffre : « $(Fr 'T21') »"
$v7 = Test-DriveName '   Sony    MPF920  '
Chk 'V7' ($v7.Ok -and $v7.Name -ceq 'Sony MPF920' -and -not (Test-DriveName ' Sony MPF920' '' -Load).Ok -and -not (Test-DriveName 'Sony  MPF920' '' -Load).Ok -and (Test-DriveName 'Sony MPF920' '' -Load).Ok) 'espaces des bords retires, espaces repetes ramenes a un seul ; au chargement, un nom doit etre deja normalise'
$fontOk = ($form.Font.Name -eq 'Segoe UI')
$pxTeac = [System.Windows.Forms.TextRenderer]::MeasureText('TEAC FD-235HF n°2', $form.Font).Width
Chk 'V8' ((Get-Why ('W' * 24)) -ceq (Fr 'T24') -and (Test-DriveName 'TEAC FD-235HF n°2').Ok -and (Test-DriveName ('W' * 24) '' -Load).Ok -and ([int]$script:DriveListWidth - 24) -eq 126) "largeur (police de la fenetre $($form.Font.Name) $($form.Font.SizeInPoints) pt, Segoe UI : $fontOk, controle jamais affiche) : 24 « W » refuses, « TEAC FD-235HF n°2 » admis ($pxTeac px pour 126) ; non controlee au chargement"
$v9 = @()
$cases9 = [ordered]@{ T18 = @('', @()); T19 = @(('i' * 25), @('24')); T20 = @('a|b', @('|')); T21 = @('É', @()); T22 = @('b', @('b')); T69 = @('keys', @('keys')); T23 = @('KEYSTONE', @('Keystone')); T24 = @(('W' * 20), @()) }
foreach ($k in @($cases9.Keys)) {
    $nm = [string]$cases9[$k][0]; $fa = @($cases9[$k][1])
    $wf = [string](Test-DriveName $nm).Why; $we = [string](Invoke-En { (Test-DriveName $nm).Why })
    if ($wf -cne ((Fr $k) -f $fa) -or $we -cne ((En $k) -f $fa)) { $v9 += $k }
}
Chk 'V9' ($v9.Count -eq 0) "chaque refus rend son texte, en francais et en anglais, mot pour mot ($(@($cases9.Keys) -join ', ')) ; ecarts : $(if ($v9.Count) { $v9 -join ', ' } else { 'aucun' })"
# V10 : bloc modifie a la main
Reset-LnWorld 'v10'
$blkV10 = @'
{ "drives": { "list": [
  { "id": "L20261120180211-01", "name": "Sony MPF920", "conn": "A", "created": "2026-11-20 18:02:11", "from": "A", "at": "2026-11-20 18:02:11" },
  { "id": "L20261120180340-01", "name": "sony mpf920", "conn": "0", "created": "2026-11-20 18:03:40", "from": "", "at": "" },
  { "id": "L20261120180341-01", "conn": "0" },
  { "id": "L20261120180342-01", "name": "Keys", "conn": "0" },
  { "id": "L20261120180211-01", "name": "Jumeau", "conn": "B" },
  "texte",
  { "name": "Sans Numero", "conn": "1", "created": "2026-11-19 08:00:00" },
  { "id": "X12", "name": "Autre Forme", "conn": "2", "created": "date illisible" },
  { "id": "L20261120180400-01", "name": "Quatre", "conn": "4", "created": "2026-11-20 18:04:00", "from": "Z", "at": "2026-11-20 18:04:00" },
  { "id": "L20261120180401-01", "name": "Lettre C", "conn": "C" },
  { "id": "L20261120180402-01", "name": "Minuscule a", "conn": "a" },
  { "id": "L20261120180403-01", "name": "Minuscule b", "conn": "b" }
], "last": { "A": "SONY MPF920", "0": "Quatre", "B": "Inconnu" } } }
'@
$errV10 = ''
try { Import-DriveRegistry ($blkV10 | ConvertFrom-Json) $null } catch { $errV10 = [string]$_.Exception.Message }
$namesV10 = (Get-LnRegNames) -join ','
$rSn = Get-LnRec 'Sans Numero'; $rAf = Get-LnRec 'Autre Forme'; $rQ = Get-LnRec 'Quatre'
$idsAll = @($script:DriveReg.GetEnumerator() | ForEach-Object { [string]$_.Value.Id })
Chk 'V10a' ($errV10 -ceq '' -and $namesV10 -ceq 'Sony MPF920,Sans Numero,Autre Forme,Quatre,Lettre C,Minuscule a,Minuscule b' -and (Get-LogN ((Fr 'T59') -f '5')) -eq 1) "bloc modifie a la main, aucune exception : doublon a la casse pres, entree sans nom, nom reserve, identifiant en double et entree qui n est pas un objet ignores et comptes (« $((Fr 'T59') -f '5') ») ; gardes : $namesV10"
Chk 'V10b' ([string]$rSn.Id -cmatch '^R\d{14}-\d{2}$' -and [string]$rAf.Id -cmatch '^R\d{14}-\d{2}$' -and [string]$rSn.Id -cne [string]$rAf.Id -and @($idsAll | Sort-Object -Unique).Count -eq $idsAll.Count -and [string]$rSn.Created -ceq '2026-11-19 08:00:00' -and [string]$rAf.Created -ceq '2026-11-20 18:02:11' -and [string]$rSn.Conn -ceq '1') "identifiant absent ou d une autre forme : fiche gardee avec un identifiant « R... » neuf ($($rSn.Id), $($rAf.Id)), tous distincts ; date de creation illisible : celle du chargement"
Chk 'V10c' ([string]$rQ.Conn -ceq '' -and [string]$rQ.Id -ceq 'L20261120180400-01' -and [string]$rQ.From -ceq '' -and [string](Get-LnRec 'Lettre C').Conn -ceq '' -and [string](Get-LnRec 'Minuscule a').Conn -ceq '' -and [string](Get-LnRec 'Minuscule b').Conn -ceq '' -and (Get-LogN ((Fr 'T59b') -f 'Quatre, Lettre C, Minuscule a, Minuscule b')) -eq 1 -and (Get-DriveLabel 'Quatre') -ceq ((Fr 'T66') -f 'Quatre') -and (Get-DriveConn 'Quatre') -ceq '') "connexion « 4 », « C », « a » ou « b » : fiche gardee sans connexion, avec son identifiant, citee par le journal ; libelle « $(Get-DriveLabel 'Quatre') »"
Chk 'V10d' ($script:DriveLast.Count -eq 1 -and [string]$script:DriveLast['A'] -ceq 'Sony MPF920' -and (Get-DriveForConn 'A') -ceq 'Sony MPF920' -and (Get-DriveForConn '0') -ceq '0' -and (Get-DriveForConn 'B') -ceq 'B') 'last : ramene au nom de la fiche, a sa casse ; entree qui cite une fiche d une autre connexion ou un nom inconnu ignoree'
# V11 : nom a accents et au signe ° par le fichier
Start-LnCase 'v11'
$nmV11 = 'Épson n°2 été'
$v11 = Add-NamedDrive $nmV11 'A' 'A'
$script:DriveLast = @{ 'A' = $nmV11 }
[void](Save-Config)
Clear-LnMemory
$lv11 = [bool](Load-Config); Sync-PrecompCurves
$kV11 = @($script:DriveCurves.GetEnumerator() | Where-Object { [string]$_.Key -ceq "$nmV11|std" }).Count
Chk 'V11' ($v11.Ok -and $lv11 -and ((Get-LnRegNames) -join ',') -ceq $nmV11 -and $kV11 -eq 1 -and (Get-DriveForConn 'A') -ceq $nmV11 -and [string]$script:TargetDrives[$nmV11] -ceq '0' -and (Get-DriveLabel $nmV11) -ceq "$nmV11 (A)" -and (Get-LogN '*illisible*') -eq 0) "aller et retour par le fichier d un nom a accents et au signe ° (« $nmV11 ») : fiche, cles du magasin, last et lecteur cible relus a l identique"
Chk-Inv 'V11b'

# ================================================================ C. configuration
'--- C. configuration et copie de secours (scenario 9)'
function Set-LnTwoDrives {
    # Sony nomme depuis A, TEAC nomme depuis 0 : lecteur cible Sony -> TEAC, courbes croisees Sony>TEAC ; derniers lecteurs de A et de 0
    [void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); Step-LnClock 89
    [void](Add-NamedDrive 'TEAC FD-235HF' '0' '0')
    $script:DriveLast = @{ 'A' = 'Sony MPF920'; '0' = 'TEAC FD-235HF' }
}
Start-LnCase 'c1'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A')
$script:DriveLast = @{ 'A' = 'Sony MPF920' }
[void](Save-Config)
$rawC1 = [System.IO.File]::ReadAllText($script:ConfigFile, [System.Text.Encoding]::UTF8)
$c1 = Read-LnJson $script:ConfigFile; $d1 = Get-LnProp $c1 'drives'; $l1 = $null; if ($d1) { $l1 = $d1.list }
Chk 'C1a' ($null -ne $d1 -and (@($d1.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq 'list,last' -and $l1 -is [array] -and @($l1).Count -eq 1 -and (@(@($l1)[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq 'id,name,conn,created,from,at' -and [string]@($l1)[0].id -cmatch $rxId -and [string]@($l1)[0].name -ceq 'Sony MPF920' -and [string]$d1.last.A -ceq 'Sony MPF920' -and $rawC1 -notmatch 'nextId' -and [string]$c1.global.drive -ceq 'A') "bloc drives ecrit avec un registre non vide : list (tableau, un seul lecteur compris) et last ; fiche a six champs (id, name, conn, created, from, at), identifiant date, aucun compteur"
Step-LnClock 89
[void](Add-NamedDrive 'TEAC FD-235HF' '0' '0'); $script:DriveLast = @{ 'A' = 'Sony MPF920'; '0' = 'TEAC FD-235HF' }
Step-LnClock 30
[void](Add-NamedDrive 'Mitsumi D359' '0')
[void](Save-Config)
$d1b = Get-LnProp (Read-LnJson $script:ConfigFile) 'drives'
$l1b = @(Get-LnProp $d1b 'list')
Chk 'C1b' ($l1b.Count -eq 3 -and (@($l1b | ForEach-Object { "$($_.name)/$($_.conn)/$($_.from)/$($_.at)" }) -join ' ; ') -ceq 'Sony MPF920/A/A/2026-11-20 18:02:11 ; TEAC FD-235HF/0/0/2026-11-20 18:03:40 ; Mitsumi D359/0//' -and (@($d1b.last.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ',') -ceq 'A=Sony MPF920,0=TEAC FD-235HF' -and @($l1b | ForEach-Object { [string]$_.id } | Sort-Object -Unique).Count -eq 3) "trois fiches dans l ordre d enregistrement, from et at vides pour un lecteur cree sans attribution ; last par connexion : $(@($d1b.last.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ')"
Chk-Inv 'C1c'

# C2 : copie de secours
$resc = Get-LnRescue
$r2 = Read-LnJson $resc
$savedR = [string]$r2._saved
$tg2 = @(Get-LnProp $r2 'targets')
Chk 'C2a' ((Test-Path -LiteralPath $resc) -and (@($r2.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq '_comment,_saved,version,drives,targets' -and [string]$r2._comment -ceq (Fr 'TXb') -and [string]$r2.version -ceq [string]$script:Version -and @(Get-LnProp $r2.drives 'list').Count -eq 3 -and $tg2.Count -eq 1 -and [string]$tg2[0].source -ceq 'Sony MPF920' -and [string]$tg2[0].target -ceq 'TEAC FD-235HF' -and [System.IO.File]::ReadAllText($resc, [System.Text.Encoding]::UTF8) -notmatch 'driveCurves|values|spec') "copie de secours $([System.IO.Path]::GetFileName($resc)) : _comment, _saved, version, drives, targets ; les couples dont un lecteur au moins est enregistre (Sony MPF920 vers TEAC FD-235HF) ; aucune courbe"
$bR = [System.IO.File]::ReadAllBytes($resc)
$savedMain = @()
foreach ($i in 1..10) { Step-LnClock 5; [void](Save-Config); $savedMain += [string](Read-LnJson $script:ConfigFile)._saved }
Chk 'C2b' ((Get-LnBytesId ([System.IO.File]::ReadAllBytes($resc))) -ceq (Get-LnBytesId $bR) -and @($savedMain | Sort-Object -Unique).Count -eq 10 -and [string](Read-LnJson $resc)._saved -ceq $savedR) "dix Save-Config de suite (_saved different a chaque fois dans le fichier principal) : la copie de secours n est pas reecrite (_saved $savedR)"
[void](Set-TargetDrive 'Mitsumi D359' 'A'); Step-LnClock 5; [void](Save-Config)
$tg2b = @(Get-LnProp (Read-LnJson $resc) 'targets')
[void](Move-NamedDrive 'Mitsumi D359' 'B'); Step-LnClock 5; [void](Save-Config)
$l2c = @(Get-LnProp (Read-LnJson $resc).drives 'list')
Chk 'C2c' ($tg2b.Count -eq 2 -and (@($tg2b | ForEach-Object { "$($_.source)>$($_.target)" }) -join ',') -ceq 'Mitsumi D359>A,Sony MPF920>TEAC FD-235HF' -and [string]@($l2c | Where-Object { $_.name -eq 'Mitsumi D359' })[0].conn -ceq 'B') 'reecrite quand un lecteur cible change (bloc targets), puis quand une fiche change (bloc drives)'
foreach ($nm in 'Mitsumi D359', 'TEAC FD-235HF', 'Sony MPF920') { Step-LnClock 60; [void](Remove-NamedDrive $nm) }
Step-LnClock 5; [void](Save-Config)
$r2d = Read-LnJson $resc; $c2d = Read-LnJson $script:ConfigFile
Chk 'C2d' ($script:DriveReg.Count -eq 0 -and (Test-Path -LiteralPath $resc) -and @(Get-LnProp $r2d.drives 'list').Count -eq 0 -and @(Get-LnProp $r2d 'targets').Count -eq 0 -and $null -ne (Get-LnProp $c2d 'drives') -and @(Get-LnProp $c2d.drives 'list').Count -eq 0) 'dernier lecteur supprime : copie de secours reecrite avec une liste vide, jamais supprimee ; le fichier principal garde un bloc drives a liste vide (une copie de secours a ete ecrite dans la session)'
Chk-Inv 'C2e'

# C3, C6 : bloc absent, copie presente (ce qu une 12.10 laisse apres avoir enregistre)
function Remove-LnDrivesBlock([string]$path, [switch]$NamedTargets) {
    # Ce qu une version anterieure retire a son premier enregistrement : le bloc drives, les lecteurs cibles a nom
    $c = Read-LnJson $path
    $c.PSObject.Properties.Remove('drives')
    if ($NamedTargets) { foreach ($p in @($c.write.targetDrive.PSObject.Properties)) { if ($codes -cnotcontains [string]$p.Name -or $codes -cnotcontains [string]$p.Value) { $c.write.targetDrive.PSObject.Properties.Remove($p.Name) } } }
    [System.IO.File]::WriteAllText($path, ($c | ConvertTo-Json -Depth 8), $utf8)
}
Start-LnCase 'c3'
Set-LnTwoDrives
[void](Set-TargetDrive '0' 'Sony MPF920')
$idS = [string](Get-LnRec 'Sony MPF920').Id; $idT = [string](Get-LnRec 'TEAC FD-235HF').Id
[void](Save-Config)
$sig0 = Get-LnMemSigs; $keys0 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
Remove-LnDrivesBlock $script:ConfigFile -NamedTargets
$c3f = Read-LnJson $script:ConfigFile
$c3f.write.targetDrive | Add-Member -NotePropertyName '0' -NotePropertyValue 'B'
[System.IO.File]::WriteAllText($script:ConfigFile, ($c3f | ConvertTo-Json -Depth 8), $utf8)
Clear-LnMemory
$l3 = [bool](Load-Config); Sync-PrecompCurves
$keys3 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
$t60 = @($script:Log | Where-Object { $_ -like 'Lecteurs enregistrés relus dans la copie de secours*' })
$t60Want = (Fr 'T60') -f (Get-LnRescue), 'Sony MPF920 : 5 courbe(s) dont 2 croisée(s), dernière : 05/11/2026 10:00 ; TEAC FD-235HF : 4 courbe(s) dont 2 croisée(s), dernière : 05/11/2026 10:00', 'Sony MPF920 → TEAC FD-235HF'
Chk 'C3a' ($l3 -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920,TEAC FD-235HF' -and [string](Get-LnRec 'Sony MPF920').Id -ceq $idS -and [string](Get-LnRec 'TEAC FD-235HF').Id -ceq $idT -and [string](Get-LnRec 'TEAC FD-235HF').Conn -ceq '0' -and $script:DriveRescued -and [string]$script:DriveLast['A'] -ceq 'Sony MPF920' -and [string]$script:DriveLast['0'] -ceq 'TEAC FD-235HF' -and $null -eq $script:DriveRescuePairs) 'bloc drives absent, copie de secours presente : fiches, connexions, identifiants et last relus dans la copie ; registre marque « relu dans la copie de secours » pour la session'
Chk 'C3b' ((Get-TargetDrive 'Sony MPF920') -ceq 'TEAC FD-235HF' -and (Get-TargetDrive '0') -ceq 'B' -and $t60.Count -eq 1 -and $t60[0] -ceq $t60Want) "lecteurs cibles : couple de la copie retabli (Sony MPF920 vers TEAC FD-235HF), sauf pour une source qui a aujourd hui un autre lecteur cible (0 vers B garde) ; une ligne de journal, mot pour mot, avec les calibrations de chaque fiche et les couples retablis"
Chk 'C6' ($keys3 -ceq $keys0 -and (Get-LnMemSigs) -ceq $sig0 -and @($script:DriveCurves.GetEnumerator() | Where-Object { $codes -ccontains ([string]$_.Key).Split('|')[0] }).Count -eq 0 -and (Get-LogN '*lecteur(s) cible illisible(s)*') -eq 0) "configuration privee de ce qu une 12.10 retire (bloc drives, lecteurs cibles a nom) : courbes intactes sous leurs noms ($(@($keys3 -split "`n").Count)), aucune courbe sous une lettre"
Chk-Inv 'C3c'
[void](Save-Config)
$c3s = Read-LnJson $script:ConfigFile
Chk 'C3d' (@(Get-LnProp (Get-LnProp $c3s 'drives') 'list').Count -eq 2 -and [string]$c3s.write.targetDrive.'Sony MPF920' -ceq 'TEAC FD-235HF') 'enregistrement suivant : le bloc drives et le lecteur cible retabli reviennent dans le fichier'
# Copie datee d avant le lot remise a sa place : courbes sous A, fiche Sony dans la copie de secours
Start-LnCase 'c3e'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); $script:DriveLast = @{ 'A' = 'Sony MPF920' }
[void](Save-Config)
[System.IO.File]::WriteAllText($script:ConfigFile, $startJson, $utf8)
Clear-LnMemory
$l3e = [bool](Load-Config); Sync-PrecompCurves
$t60e = @($script:Log | Where-Object { $_ -like 'Lecteurs enregistrés relus dans la copie de secours*' })
Chk 'C3e' ($l3e -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920' -and $script:DriveLast.Count -eq 0 -and (Get-DriveForConn 'A') -ceq 'A' -and [string]$cmbDrive.Text -ceq 'A' -and $script:PrecompCurves['std'] -and (Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })) -ceq $keys1210 -and $t60e.Count -eq 1 -and $t60e[0] -ceq ((Fr 'T60') -f (Get-LnRescue), 'Sony MPF920 : aucune', 'Sony MPF920 → 0') -and (Get-TargetDrive 'A') -ceq '0' -and (Get-TargetDrive 'Sony MPF920') -ceq '0') "copie datee sans bloc drives remise en place : la fiche revient sans courbe (« Sony MPF920 : aucune »), avec son lecteur cible ; le bandeau reste sur le lecteur non enregistre de A, qui porte les courbes ; aucune courbe n est attribuee"
Chk-Inv 'C3f'
# C3g (relecture de LN-a) : nommer A « Sony MPF920 » pour lui rendre ses courbes : refuse tant que la fiche garde son
# lecteur cible retabli (seule donnee de la fiche, qui n a aucune courbe) ; le texte du refus le dit, sans parler de
# calibrations que la fiche n a pas (comportement actuel ; un changement de Restore-DriveRescueTargets reste a decider)
$stG = Get-LnState; $nbG = (Get-LnBaks).Count
$c3g = Add-NamedDrive 'Sony MPF920' 'A' 'A'
$dG = Get-DriveDataText (Get-DriveData 'Sony MPF920')
Chk 'C3g' (-not $c3g.Ok -and $c3g.Why -ceq ((Fr 'T27') -f 'Sony MPF920', 'A') -and $c3g.Why -like '*lecteur cible*' -and $c3g.Why -notlike '*calibrations*' -and $dG -ceq 'aucune' -and (Get-LnState) -ceq $stG -and (Get-LnBaks).Count -eq $nbG) "fiche relue sans courbe, avec son lecteur cible (calibrations : « $dG ») : refus sans effet ni copie, texte qui nomme le lecteur cible (« $($c3g.Why) »)"

# C4 : ni bloc ni copie, noms dans les donnees
Reset-LnWorld 'c4'
$dc4 = [ordered]@{}
$dc4['Orphelin Un|std'] = ConvertTo-CurveConfig (New-Cv 'Orphelin Un' 'std' $null '30/10/2026 09:00' '0=20:40=60')
$dc4['A>Cible Deux|std'] = ConvertTo-CurveConfig (New-Cv 'A' 'std' $null '05/11/2026 10:00' '0=25:40=65' 'Cible Deux')
$dc4['Keys|std'] = ConvertTo-CurveConfig (New-Cv 'Keys' 'std' $null '06/11/2026 10:00' '0=32:40=72')
$cfgC4 = [ordered]@{
    global = [ordered]@{ drive = 'A' }
    write = [ordered]@{ eraseMode = 'hfreq'; contentCalc = '12.9'; calibWarmup = $true; calibCalc = [string]$script:CalibCalc; calibVersion = '12.11'; driveCurves = $dc4
                        levelBrands = @((ConvertTo-LevelBrandConfig (New-Br 'Verbatim' 'Marque Quatre' 'std' 'c' '30/10/2026 09:00'))); driveFactors = @((ConvertTo-ContentConfig (New-Cm 'Facteur Trois' 0 0.8)))
                        targetDrive = [ordered]@{ 'Source Cinq' = 'A' } }
    ui = [ordered]@{ homeCalHeads = $true }
}
[System.IO.File]::WriteAllText($script:ConfigFile, ($cfgC4 | ConvertTo-Json -Depth 8), $utf8)
$l4 = [bool](Load-Config); Sync-PrecompCurves
$n4r = (Get-LnRegNames) -join ','
$recs4 = @($script:DriveReg.GetEnumerator() | ForEach-Object { $_.Value })
$ids4 = Get-DriveIds
Chk 'C4a' ($l4 -and $recs4.Count -eq 5 -and @($recs4 | Where-Object { [string]$_.Conn -ceq '' -and [string]$_.Id -cmatch '^R\d{14}-\d{2}$' }).Count -eq 5 -and @($recs4 | ForEach-Object { [string]$_.Id } | Sort-Object -Unique).Count -eq 5 -and (Get-LogN ((Fr 'T61') -f ($n4r -replace ',', ', '))) -eq 1 -and @('Orphelin Un', 'Cible Deux', 'Facteur Trois', 'Marque Quatre', 'Source Cinq' | Where-Object { $ids4 -ccontains $_ }).Count -eq 5 -and (Get-TargetDrive 'Source Cinq') -ceq 'A' -and -not $script:DriveRescued) "ni bloc ni copie de secours : une fiche sans connexion, d identifiant « R... », pour chaque nom admis des donnees (cle, cible d une cle croisee, facteur seul, entree de marque seule, bloc targetDrive seul) : $n4r ; connues de Get-DriveIds, une ligne de journal"
Chk 'C4b' ($ids4 -cnotcontains 'Keys' -and $script:DriveCurves.ContainsKey('Keys|std') -and (Get-LogN ((Fr 'T76') -f 'Keys')) -eq 1 -and $script:DriveReg.Count -is [int] -and (Get-DriveConn 'Orphelin Un') -ceq '' -and -not (Test-Path -LiteralPath (Get-LnRescue))) "nom reserve trouve dans les donnees : aucune fiche, ses donnees restent hors de toute vue, cite par le journal (« $((Fr 'T76') -f 'Keys') ») ; la garde « registre non vide » reste un entier"
Chk-Inv 'C4c' @('Keys')
Reset-LnWorld 'c4d'
Set-DriveCurve 'A' 'std' (New-Cv 'A' 'std' $null '30/10/2026 09:00' '0=20:40=60')
$script:LevelShifts['std|c'] = New-Lv 'std' 'c' 'Niveau Six' '30/10/2026 09:00'
$rep4 = @(Repair-DriveRegistry)
Chk 'C4d' (($rep4 -join ',') -ceq 'Niveau Six' -and [string](Get-LnRec 'Niveau Six').Id -cmatch '^R') 'nom porte par un seul niveau de calibration rapide (appel direct : un tel niveau ne survit pas a Load-Config) : fiche sans connexion'
Start-LnCase 'c4e'
$rep4e = @(Repair-DriveRegistry $null ([pscustomobject]@{ A = '0' }))
Chk 'C4e' ($rep4e.Count -eq 0 -and $script:DriveReg.Count -eq 0 -and $script:Log.Count -eq 0) 'donnees qui ne citent que des connexions (12.10) : aucune fiche, aucune ligne'
# C4f (relecture de LN-a) : identite portee avec une espace en tete (retouche a la main) : jamais une fiche « Sony » vide
Reset-LnWorld 'c4f'
$script:DriveCurves[' Sony|std'] = New-Cv ' Sony' 'std' $null '07/11/2026 10:00' '0=31:40=71'
$rep4f = @(Repair-DriveRegistry)
Chk 'C4f' ($rep4f.Count -eq 0 -and $script:DriveReg.Count -eq 0 -and (Get-LogN ((Fr 'T76') -f ' Sony')) -eq 1 -and (Get-LogN ((Fr 'T61') -f '*')) -eq 0 -and $script:DriveCurves.ContainsKey(' Sony|std')) "courbe « ␣Sony|std » : aucune fiche, une ligne « $((Fr 'T76') -f ' Sony') », la courbe reste dans le magasin"
Chk-Inv 'C4g' @(' Sony')

# C5 : copie de secours illisible
Reset-LnWorld 'c5'
[System.IO.File]::WriteAllText($script:ConfigFile, $startJson, $utf8)
[System.IO.File]::WriteAllText((Get-LnRescue), '{ "drives": { "list": [ { "id": ', $utf8)
$errC5 = ''; $l5 = $false
try { $l5 = [bool](Load-Config); Sync-PrecompCurves } catch { $errC5 = [string]$_.Exception.Message }
[void](Save-Config)
Chk 'C5' ($errC5 -ceq '' -and $l5 -and $script:DriveReg.Count -eq 0 -and (Get-LogN ((Fr 'T63') -f (Get-LnRescue), '*')) -eq 1 -and $null -eq $script:DriveRescueText -and $null -eq (Get-LnProp (Read-LnJson $script:ConfigFile) 'drives') -and [System.IO.File]::ReadAllText((Get-LnRescue), [System.Text.Encoding]::UTF8) -ceq '{ "drives": { "list": [ { "id": ') 'copie de secours illisible : registre vide, une ligne de journal, aucune exception ; elle n est pas reecrite tant que le registre reste vide'
Step-LnClock 60
[void](Add-NamedDrive 'Sony MPF920' 'A'); [void](Save-Config)
Chk 'C5b' (@(Get-LnProp (Read-LnJson (Get-LnRescue)).drives 'list').Count -eq 1) 'elle est reecrite au premier changement du registre'
Chk-Inv 'C5c'

# C7 : global.drive et vue
Start-LnCase 'c7'
Set-LnTwoDrives
[void](Move-NamedDrive 'TEAC FD-235HF' '2')
$c7bad = @()
foreach ($id in @($codes) + @('Sony MPF920', 'TEAC FD-235HF')) {
    Set-LnBanner $id
    [void](Save-Config)
    $c7 = Read-LnJson $script:ConfigFile
    $gd = [string]$c7.global.drive
    $vw = (@($c7.write.precompCurves.PSObject.Properties | Where-Object { $null -ne $_.Value } | ForEach-Object { "$($_.Name):$($_.Value.drive)" }) -join ',')
    $wantV = if ($id -ceq 'Sony MPF920') { 'std:Sony MPF920,std_h0:Sony MPF920,std_h1:Sony MPF920' } elseif ($id -ceq 'TEAC FD-235HF') { 'std_h0:TEAC FD-235HF,std_h1:TEAC FD-235HF' } else { '' }
    if ($codes -cnotcontains $gd -or $gd -cne (Get-DriveConn $id) -or $vw -cne $wantV) { $c7bad += "$id (global.drive $gd, vue $vw)" }
}
Set-LnBanner 'A'
Chk 'C7' ($c7bad.Count -eq 0) "global.drive ecrit : toujours une des six connexions, celle du lecteur du bandeau (lecteur enregistre compris) ; precompCurves : vue du lecteur choisi ; ecarts : $(if ($c7bad.Count) { $c7bad -join ' ; ' } else { 'aucun' })"

# C9 : copie .lecteurs- d avant la premiere attribution remise a la place de la configuration
Start-LnCase 'c9'
$c9 = Add-NamedDrive 'Sony MPF920' 'A' 'A'; $script:DriveLast = @{ 'A' = 'Sony MPF920' }
[void](Save-Config)
[System.IO.File]::Copy([string]$c9.Bak, $script:ConfigFile, $true)
Clear-LnMemory
$l9 = [bool](Load-Config); Sync-PrecompCurves
$keys9 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
Chk 'C9a' ($l9 -and $script:DriveReg.Count -eq 0 -and $keys9 -ceq $keys1210 -and (Get-LogN 'Lecteurs enregistrés relus*') -eq 0 -and -not $script:DriveRescued -and $null -ne $script:DriveRescueText -and (Get-TargetDrive 'A') -ceq '0' -and $script:PrecompCurves['std']) 'copie d avant la premiere attribution remise en place : son bloc drives, present avec une liste vide, fait foi : registre vide, courbes sous la lettre, aucune ligne « relus dans la copie de secours »'
Step-LnClock 60; [void](Save-Config)
$c9f = Read-LnJson $script:ConfigFile
Chk 'C9b' (@(Get-LnProp (Read-LnJson (Get-LnRescue)).drives 'list').Count -eq 0 -and $null -ne (Get-LnProp $c9f 'drives') -and @(Get-LnProp $c9f.drives 'list').Count -eq 0) 'la copie de secours, qui citait encore le lecteur, est reecrite vide au premier enregistrement'
Chk-Inv 'C9c'

# C10 : aucun fichier de configuration, copie de secours presente
Start-LnCase 'c10'
[void](Add-NamedDrive 'Sony MPF920' 'A' 'A'); [void](Save-Config)
$bR10 = [System.IO.File]::ReadAllBytes((Get-LnRescue))
Remove-Item -LiteralPath $script:ConfigFile -Force
Clear-LnMemory
$l10 = [bool](Load-Config)
Step-LnClock 60; [void](Save-Config); Step-LnClock 60; [void](Save-Config)
Chk 'C10a' (-not $l10 -and $script:DriveReg.Count -eq 0 -and $null -eq (Get-LnProp (Read-LnJson $script:ConfigFile) 'drives') -and (Get-LnBytesId ([System.IO.File]::ReadAllBytes((Get-LnRescue)))) -ceq (Get-LnBytesId $bR10) -and $script:Log.Count -eq 0) 'sans fichier de configuration : registre vide pendant la session, copie de secours ni lue ni reecrite par les enregistrements'
Clear-LnMemory
$l10b = [bool](Load-Config); Sync-PrecompCurves
Chk 'C10b' ($l10b -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920' -and $script:DriveRescued -and @($script:Log | Where-Object { $_ -ceq ((Fr 'T60') -f (Get-LnRescue), 'Sony MPF920 : aucune', 'Sony MPF920 → 0') }).Count -eq 1 -and $script:DriveCurves.Count -eq 0) 'au demarrage suivant, le fichier reecrit n a pas de bloc drives : la copie de secours rend la fiche, sans calibration (le fichier qui les portait a disparu)'
Remove-Item -LiteralPath $script:ConfigFile -Force
Clear-LnMemory
[void](Load-Config)
Step-LnClock 60; [void](Add-NamedDrive 'Mitsumi D359' '0'); [void](Save-Config)
Chk 'C10c' ((@(Get-LnProp (Read-LnJson (Get-LnRescue)).drives 'list' | ForEach-Object { [string]$_.name }) -join ',') -ceq 'Mitsumi D359') 'sans fichier de configuration, la copie de secours est remplacee au premier lecteur enregistre'
Chk-Inv 'C10d'

# ================================================================ X. connexion et courbes croisees
'--- X. connexion des commandes gw, courbes croisees (scenario 5)'
Start-LnCase 'x'
Set-LnTwoDrives
$script:Cal = @{ Drive = 'Sony MPF920'; Cross = @{ Src = 'Sony MPF920'; Tgt = 'TEAC FD-235HF' } }
$txtDev.Text = 'COM7'
$xr = (Get-CalibDriveArgsFor 'read') -join ' '; $xw = (Get-CalibDriveArgsFor 'write') -join ' '; $xe = (Get-CalibDriveArgsFor 'erase') -join ' '; $xp = (Get-CalibDriveArgsFor 'warmup') -join ' '
$xk = Get-DriveCurveKey (Get-CalibStoreDrive $script:Cal) 'std_h0'
$txtDev.Text = ''; $script:Cal = $null
Chk 'X1' ($xr -ceq '--drive=0 --device=COM7' -and $xw -ceq '--drive=A --device=COM7' -and $xe -ceq '--drive=A --device=COM7' -and $xp -ceq '--drive=A --device=COM7' -and $xk -ceq 'Sony MPF920>TEAC FD-235HF|std_h0' -and $script:DriveCurves.ContainsKey($xk)) "calibration croisee entre Sony MPF920 (A) et TEAC FD-235HF (0) : --drive=A pour ecrire, effacer et prechauffer, --drive=0 pour relire ; cle $xk"
$xa = @()
foreach ($id in @($codes) + @('Sony MPF920', 'TEAC FD-235HF')) { Set-LnBanner $id; $xa += "$id : $((Get-CommonArgs) -join ' ')" }
Set-LnBanner 'A'
Chk 'X1b' (($xa -join ' ; ') -ceq 'A : --drive=A ; B : --drive=B ; 0 : --drive=0 ; 1 : --drive=1 ; 2 : --drive=2 ; 3 : --drive=3 ; Sony MPF920 : --drive=A ; TEAC FD-235HF : --drive=0' -and (Get-DriveConn 'Inconnu') -ceq '' -and (Get-DriveConn '') -ceq '' -and (Get-DriveConn 'a') -ceq '') 'Get-CommonArgs pour chaque lecteur du bandeau : une des six connexions, jamais un nom ; identite inconnue : aucune connexion (gw refuse la commande)'
$xt = (Get-CrossCalibTargets (Get-DriveIds) 'A') -join ','
$script:DriveReg = [ordered]@{}
$xt0 = (Get-CrossCalibTargets (Get-DriveIds) 'A') -join ','; $ti0 = (Get-TargetDriveItems 'A') -join ','
Chk 'X2' ($xt -ceq 'B,0,1,2,3,Sony MPF920,TEAC FD-235HF' -and $xt0 -ceq 'B,0,1,2,3' -and $ti0 -ceq '(même lecteur),B,0,1,2,3') "Get-CrossCalibTargets : registre vide, resultat de la 12.10 ($xt0 ; liste « Lecteur cible » : $ti0) ; avec des lecteurs enregistres, ils suivent les connexions"
# X3 : ecriture pour un lecteur cible
Start-LnCase 'x3'
Set-LnTwoDrives
[void](Add-NamedDrive 'Mitsumi D359' 'A')
$img = Join-Path $here 'image-factice.adf'; [System.IO.File]::WriteAllBytes($img, [byte[]]@(1, 2, 3))
$cmbWProfile.SelectedIndex = 1
Set-LnBanner 'Sony MPF920'
$wi1 = Get-TargetWriteInfo $img '(auto)' $true
[void](Set-TargetDrive 'Sony MPF920' 'Mitsumi D359')
$wi2 = Get-TargetWriteInfo $img '(auto)' $true
[void](Move-NamedDrive 'TEAC FD-235HF' 'A')
[void](Set-TargetDrive 'Sony MPF920' 'TEAC FD-235HF')
$wi3 = Get-TargetWriteInfo $img '(auto)' $true
Set-LnBanner 'Mitsumi D359'; [void](Set-TargetDrive 'Mitsumi D359' 'TEAC FD-235HF')
$wi4 = Get-TargetWriteInfo $img '(auto)' $true
Set-LnBanner 'A'; $cmbWProfile.SelectedIndex = 0
Chk 'X3' ($wi1.Tgt -ceq 'TEAC FD-235HF' -and $wi1.Block -ceq '' -and @($wi1.Curves).Count -eq 2 -and [string]@($wi1.Curves)[0].Spec -ceq '0=25:40=65' -and $wi2.Tgt -ceq 'Mitsumi D359' -and $wi2.BlockKind -ceq 'none' -and @($wi2.Curves).Count -eq 0 -and $wi2.Block -like 'Aucune courbe croisée Sony MPF920 → Mitsumi D359 *' -and $wi3.Block -ceq '' -and @($wi3.Curves).Count -eq 2 -and $wi4.BlockKind -ceq 'none' -and @($wi4.Curves).Count -eq 0) 'ecriture pour un lecteur cible : courbes croisees du couple Sony MPF920 vers TEAC FD-235HF ; cible sans courbe croisee de ce couple (Mitsumi D359), ou autre lecteur a la place du Sony sur A : refus, jamais la courbe d un autre couple ; cible de la meme connexion avec sa courbe croisee : admise'
# X4 : fiche sans connexion
Start-LnCase 'x4'
Set-LnTwoDrives
$script:DriveCurves['Sans Fil|std'] = New-Cv 'Sans Fil' 'std' $null '07/11/2026 10:00' '0=31:40=71'
[void]@(Repair-DriveRegistry)
$old4 = Set-TargetDrive 'Sony MPF920' 'Sans Fil'
$script:Cal = @{ Cross = @{ Src = 'Sony MPF920'; Tgt = 'Sans Fil' } }
$x4r = (Get-CalibDriveArgsFor 'read') -join ' '
$script:Cal = $null
Chk 'X4' ((Get-TargetDrive 'Sony MPF920') -ceq 'Sans Fil' -and (Get-TargetDriveItems 'Sony MPF920') -ccontains 'Sans Fil' -and @($cmbDrive.Items | Where-Object { [string]$_ -eq 'Sans Fil' }).Count -eq 0 -and $x4r -ceq '--drive=' -and @(Get-ConnDrives 'A') -cnotcontains 'Sans Fil') 'fiche sans connexion : admise comme lecteur cible d une ecriture ; absente de la liste du bandeau, donc des cibles d une calibration croisee ; aucune connexion pour une commande gw (« --drive= », que gw refuse)'
Chk 'X5' ((@(Get-ConnDrives 'A') -join ',') -ceq 'Sony MPF920,A' -and (@(Get-ConnDrives '0') -join ',') -ceq 'TEAC FD-235HF' -and (@(Get-ConnDrives 'B') -join ',') -ceq '' -and (@(Get-ConnDrives 'x') -join ',') -ceq '' -and (Get-DriveLabel 'Sony MPF920') -ceq 'Sony MPF920 (A)' -and (Get-DriveLabel 'B') -ceq 'B' -and (Get-DriveLabel 'Nulle Part') -ceq 'Nulle Part' -and (Test-DriveRegistered 'teac fd-235hf') -and -not (Test-DriveRegistered 'A')) "lecteurs d une connexion (Get-ConnDrives) : ceux qui y sont enregistres, puis son lecteur non enregistre s il a des donnees ou s il est le lecteur du bandeau (A : $(@(Get-ConnDrives 'A') -join ', ')) ; libelles (Get-DriveLabel)"
$dT = Get-DriveDataText (Get-DriveData 'Sony MPF920'); $dT0 = Get-DriveDataText (Get-DriveData 'Sans Fil'); $dTe = Invoke-En { Get-DriveDataText (Get-DriveData 'Sony MPF920') }
Chk 'X6' ($dT -ceq ((Fr 'T13') -f '5', '2', '05/11/2026 10:00') -and $dT0 -ceq ((Fr 'T12') -f '1', '07/11/2026 10:00') -and $dTe -ceq ((En 'T13') -f '5', '2', '05/11/2026 10:00') -and (Get-DriveDataText (Get-DriveData 'B')) -ceq 'aucune') "texte des calibrations d un lecteur : « $dT » ; « $dT0 » ; « aucune »"
Reset-LnWorld 'x6b'; $script:DriveCurves = @{}; Set-DriveCurve 'Sony MPF920>0' 'std' (New-Cv 'Sony MPF920' 'std' $null '05/11/2026 10:00' '0=25:40=65' '0')
Chk 'X6b' ((Get-DriveDataText (Get-DriveData '0')) -ceq ((Fr 'T13') -f '1', '1', '05/11/2026 10:00')) 'lecteur dont la seule courbe est croisee : jamais « aucune »'

# ================================================================ E. epoque
'--- E. lecteur d aujourd hui d une courbe d une copie datee (Resolve-DriveOfEra, pour le lot L7)'
function New-Era([object[]]$recs) {
    # Bloc drives d une copie datee, tel que ConvertFrom-Json le rend
    return ((([ordered]@{ list = @($recs | ForEach-Object { [ordered]@{ id = [string]$_[0]; name = [string]$_[1]; conn = [string]$_[2]; created = [string]$_[3]; from = ''; at = '' } }); last = [ordered]@{} }) | ConvertTo-Json -Depth 6) | ConvertFrom-Json)
}
function Set-LnReg([object[]]$recs) {
    # Registre d aujourd hui pose par le test : @(id, nom, connexion, created, from, at)
    $t = [ordered]@{}
    foreach ($r in $recs) { $t.Add([string]$r[1], @{ Id = [string]$r[0]; Name = [string]$r[1]; Conn = [string]$r[2]; Created = [string]$r[3]; From = [string]$r[4]; At = [string]$r[5] }) }
    $script:DriveReg = $t
}
function Get-Era([string]$d, $blk, [datetime]$when) { $r = Resolve-DriveOfEra $d $blk $when; return "$($r.Drive)|$($r.Sure)|$($r.Why)|$($r.Era)" }
$dOct = New-Object datetime(2026, 10, 30, 9, 0, 0); $dNov = New-Object datetime(2026, 11, 25, 9, 0, 0); $dDec = New-Object datetime(2026, 12, 10, 9, 0, 0)
Reset-LnWorld 'e'
$eraS = New-Era @(, @('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11'))
Set-LnReg @(, @('L20261120180211-01', 'Sony MPF-920', '0', '2026-11-20 18:02:11', 'A', '2026-11-20 18:02:11'))
$e1 = Get-Era 'Sony MPF920' $eraS $dNov
Set-LnReg @(, @('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11', 'A', '2026-11-20 18:02:11'))
$e1b = Get-Era 'sony mpf920' $eraS $dNov
Chk 'E1' ($e1 -ceq 'Sony MPF-920|True|id|Sony MPF920' -and $e1b -ceq 'Sony MPF920|True|id|sony mpf920') "copie a lecteur renomme depuis : meme identifiant de fiche, donc meme lecteur, sous son nom d aujourd hui ($e1) ; non renomme : $e1b"
Set-LnReg @(, @('L20261121093005-01', 'TEAC FD-235HF', '0', '2026-11-21 09:30:05', '', ''))
$e2 = Get-Era 'Sony MPF920' $eraS $dNov
Chk 'E2' ($e2 -ceq '|False|deleted|Sony MPF920') "lecteur supprime depuis : aucun lecteur d aujourd hui ($e2)"
Set-LnReg @(, @('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11', 'A', '2026-11-20 18:02:11'))
$e3a = Get-Era 'A' $null $dOct; $e3b = Get-Era 'A' $null $dNov; $e3c = Get-Era '0' $null $dOct
$script:DriveReg = [ordered]@{}
$e3d = Get-Era 'A' $null $dOct
Chk 'E3' ($e3a -ceq 'Sony MPF920|False|conn-named|A' -and $e3b -ceq 'A|True|conn|A' -and $e3c -ceq '0|True|conn|0' -and $e3d -ceq 'A|True|conn|A') "copie d avant le registre (lettres seules) : attribution posterieure a la courbe : la fiche qui a recu les calibrations de la connexion, sans certitude ($e3a) ; courbe posterieure a l attribution, autre connexion ou registre vide : le lecteur non enregistre ($e3b)"
Set-LnReg @(@('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11', 'A', '2026-11-20 18:02:11'), @('L20261201100000-01', 'TEAC FD-235HF', 'A', '2026-12-01 10:00:00', 'A', '2026-12-01 10:00:00'))
$e4a = Get-Era 'A' $null $dOct; $e4b = Get-Era 'A' $null $dNov; $e4c = Get-Era 'A' $null $dDec
Chk 'E4' ($e4a -ceq 'Sony MPF920|False|conn-named|A' -and $e4b -ceq 'TEAC FD-235HF|False|conn-named|A' -and $e4c -ceq 'A|True|conn|A') "deux attributions successives de la meme connexion : la premiere posterieure a la courbe ($e4a ; $e4b ; apres les deux : $e4c)"
# E5 : registre vide puis memes noms enregistres dans un autre ordre (un compteur aurait relie Sony au TEAC)
$eraTwo = New-Era @(@('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11'), @('L20261120180340-01', 'TEAC FD-235HF', 'A', '2026-11-20 18:03:40'))
Set-LnReg @(@('L20261205100000-01', 'TEAC FD-235HF', 'A', '2026-12-05 10:00:00', '', ''), @('L20261205100100-01', 'Sony MPF920', 'A', '2026-12-05 10:01:00', '', ''))
$e5a = Get-Era 'Sony MPF920' $eraTwo $dNov; $e5b = Get-Era 'TEAC FD-235HF' $eraTwo $dNov
Chk 'E5' ($e5a -ceq '|False|deleted|Sony MPF920' -and $e5b -ceq '|False|deleted|TEAC FD-235HF') "registre vide, puis les memes noms enregistres dans un autre ordre : aucune ligne reliee a un lecteur d un autre nom ; la copie d epoque donne « lecteur supprime depuis » ($e5a)"
$e6b = Get-Era 'Sony MPF920' $null $dNov; $e6c = Get-Era 'Sony MPF920' $null $dDec
Chk 'E6' ($e5a -ceq '|False|deleted|Sony MPF920' -and $e6b -ceq 'Sony MPF920|False|name-after|Sony MPF920' -and $e6c -ceq 'Sony MPF920|True|name|Sony MPF920') "lecteur supprime puis recree sous le meme nom : avec sa fiche d epoque, « supprime depuis » ; copie sans bloc drives : fiche creee apres la courbe, sans certitude ($e6b) ; creee avant : $e6c"
Set-LnReg @(, @('R20261205100000-01', 'Sony MPF920', '', '2026-12-05 10:00:00', '', ''))
$e7a = Get-Era 'Sony MPF920' $eraS $dNov
$eraR = New-Era @(, @('R20261205100000-01', 'Sony MPF920', 'A', '2026-12-05 10:00:00'))
$e7b = Get-Era 'Sony MPF920' $eraR $dDec
Chk 'E7' ($e7a -ceq 'Sony MPF920|False|name-after|Sony MPF920' -and $e7b -ceq 'Sony MPF920|True|id|Sony MPF920') "registre refait d apres les donnees (fiche « R... ») : copie d avant, reliee par le nom, sans certitude ($e7a) ; copie faite apres, avec la fiche « R... » : reliee par l identifiant ($e7b)"
Set-LnReg @(@('L20261120180211-01', 'Sony MPF-920', 'A', '2026-11-20 18:02:11', 'A', '2026-11-20 18:02:11'), @('L20261205100000-01', 'Sony MPF920', '0', '2026-12-05 10:00:00', '', ''))
$e8 = Get-Era 'Sony MPF920' $eraS $dNov
Reset-LnWorld 'e8'
Set-LnReg @(, @('L20261120180211-01', 'Sony MPF920', 'A', '2026-11-20 18:02:11', '', ''))
$script:TNow = New-Object datetime(2026, 11, 20, 18, 2, 11)
$id8a = New-DriveId; $id8r = New-DriveId 'R'
$script:TNow = New-Object datetime(2026, 12, 5, 10, 0, 0)
$id8b = New-DriveId
Chk 'E8' ($e8 -ceq '|False|ambiguous|Sony MPF920' -and $id8a -ceq 'L20261120180211-02' -and $id8r -ceq 'R20261120180211-02' -and $id8b -ceq 'L20261205100000-01') "nom de l epoque porte aujourd hui par une autre fiche : sans certitude, aucun lecteur ($e8) ; aucun identifiant reemploye : dans la meme seconde le rang suivant ($id8a), sinon la date ($id8b)"

# ================================================================ I. statique
'--- I. statique'
$modFiles = @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' -File | Sort-Object Name)
function Get-LnOwner($node) {
    # Fonction qui contient un noeud ('' : niveau du script)
    $p = $node.Parent
    while ($p) { if ($p -is $tFn) { return [string]$p.Name }; $p = $p.Parent }
    return ''
}
$drv = @()
foreach ($f in $modFiles) {
    if ($f.Name -match '^0') { continue }
    foreach ($s in (Get-LnAst $f.FullName).FindAll({ param($x) ($x -is $tStr -or $x -is $tExp) -and [string]$x.Value -like '--drive=*' }, $true)) { $drv += "$($f.Name.Substring(0, 3)) $(Get-LnOwner $s) : $($s.Extent.Text)" }
}
$drvWant = @('110 Get-CommonArgs : "--drive=$(Get-DriveConn ([string]$cmbDrive.Text))"', '110 Invoke-DriveProbe : "--drive=$d"', '210 Start-HeadClean : "--drive=$drive"', '240 Get-CalibDriveArgsFor : "--drive=$(Get-DriveConn $d)"')
$detTxt = (Get-LnFnAst $mods '110' 'Start-DriveDetect').Extent.Text
Chk 'I1' (($drv -join ' ; ') -ceq ($drvWant -join ' ; ') -and $detTxt.Contains('$cur = Get-DriveConn ([string]$cmbDrive.Text)')) "quatre compositions de --drive= dans les modules, pas une de plus : celles de Get-CommonArgs et de Get-CalibDriveArgsFor passent par Get-DriveConn, la sonde de la detection et le nettoyage recoivent une connexion ; la detection part de la connexion du lecteur du bandeau"
$i3 = @()
foreach ($k in @($TX.Keys)) {
    $fr = Fr $k; $en = En $k
    $got = Invoke-En { T $fr }
    $phF = (@([regex]::Matches($fr, '\{(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ','); $phE = (@([regex]::Matches($en, '\{(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ',')
    if ($got -cne $en -or $phF -cne $phE) { $i3 += $k }
}
$t019 = [System.IO.File]::ReadAllText((Get-LnModule $mods '019'), [System.Text.Encoding]::UTF8)
$used112 = @((Get-LnAst (Get-LnModule $mods '112')).FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'T' }, $true) | ForEach-Object { [string]$_.CommandElements[1].Value } | Sort-Object -Unique)
$known = @($TX.Keys | ForEach-Object { Fr $_ }) + @('aucune', 'aucun', 'Ancienne sauvegarde de configuration supprimée ({1} gardées) : {0}')
$unk = @($used112 | Where-Object { $known -cnotcontains $_ })
Chk 'I3' ($i3.Count -eq 0 -and $unk.Count -eq 0 -and $t019.Contains('# --- LN-a : lecteurs enregistres, socle sans interface')) "$(@($TX.Keys).Count) textes du socle : entree anglaise mot pour mot (section « LN-a » de 019), memes parametres {n} ; chaque cle de T() du module 112 est l un d eux ou une cle existante reemployee ; ecarts : $(@($i3 + $unk) -join ', ')"
# I5 : la vue n est ecrite que par 240 ; le registre et last ne sont ecrits que par les fonctions du module 112
$viewW = @(); $regW = @()
$regVars = @('script:DriveReg', 'script:DriveLast')
$mutators = @('Add', 'Remove', 'RemoveAt', 'Insert', 'Clear')
foreach ($f in $modFiles) {
    $ast = Get-LnAst $f.FullName
    foreach ($a in $ast.FindAll({ param($x) $x -is $tAsg }, $true)) {
        $lv = @($a.Left.FindAll({ param($y) $y -is $tVar }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath })
        if ($a.Left -is $tIdx -and $a.Left.Target -is $tVar -and [string]$a.Left.Target.VariablePath.UserPath -eq 'script:PrecompCurves') { $viewW += "$($f.Name.Substring(0, 3)) $(Get-LnOwner $a)" }
        $root = $a.Left; while ($root -is $tIdx -or $root -is $tMem) { if ($root -is $tIdx) { $root = $root.Target } else { $root = $root.Expression } }
        if ($root -is $tVar -and $regVars -contains [string]$root.VariablePath.UserPath) { $regW += "$($f.Name.Substring(0, 3)) $(Get-LnOwner $a) $($root.VariablePath.UserPath)" }
    }
    foreach ($m in $ast.FindAll({ param($x) $x -is $tInv -and $x.Expression -is $tVar -and $x.Member -is $tStr }, $true)) {
        if ($regVars -contains [string]$m.Expression.VariablePath.UserPath -and $mutators -contains [string]$m.Member.Value) { $regW += "$($f.Name.Substring(0, 3)) $(Get-LnOwner $m) $($m.Expression.VariablePath.UserPath).$($m.Member.Value)" }
    }
}
$regOut = @($regW | Where-Object { $_ -notlike '112 *' -and $_ -cne '040  script:DriveReg' -and $_ -cne '040  script:DriveLast' })
Chk 'I5' ((@($viewW | Sort-Object -Unique) -join ',') -ceq '240 Set-DriveCurve,240 Sync-PrecompCurves' -and $regOut.Count -eq 0 -and @($regW | Where-Object { $_ -like '112 *' }).Count -ge 6 -and @($regW | Where-Object { $_ -like '040 *' }).Count -eq 2) "vue des courbes ecrite par Set-DriveCurve et Sync-PrecompCurves seulement (240) ; `$script:DriveReg et `$script:DriveLast ecrits par les seules fonctions du module 112 (etat initial : 040) ; ecritures ailleurs : $(if ($regOut.Count) { $regOut -join ' ; ' } else { 'aucune' })"
# I5b : un nom n entre au registre que par une fonction qui passe par Test-DriveName (mots reserves compris)
$regOwners = Get-LnSortedText @($regW | Where-Object { $_ -like '112 * script:DriveReg' } | ForEach-Object { ($_ -split ' ')[1] } | Sort-Object -Unique)
$noCheck = @('Add-NamedDrive', 'Rename-NamedDrive', 'Import-DriveRegistry', 'Repair-DriveRegistry' | Where-Object { $fa = Get-LnFnAst $mods '112' $_; -not $fa -or @($fa.Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Test-DriveName' }, $true)).Count -eq 0 })
Chk 'I5b' ($regOwners -ceq "Add-NamedDrive`nImport-DriveRegistry`nRemove-NamedDrive`nRename-NamedDrive`nRepair-DriveRegistry" -and $noCheck.Count -eq 0) "registre affecte par cinq fonctions seulement ($($regOwners -replace "`n", ', ')) ; les quatre qui peuvent y faire entrer un nom passent par Test-DriveName, qui refuse les mots reserves : aucun nom ne peut masquer Count, Keys ou Values ; sans ce passage : $(if ($noCheck.Count) { $noCheck -join ', ' } else { 'aucune' })"
# I6 : Edit-DriveData est, dans le module 112, la seule fonction qui ecrit un porteur de l identite ; tables neuves
$carriers = @('script:DriveCurves', 'script:OldCalib', 'script:LevelShifts', 'script:LevelBrands', 'script:ContentMeasures', 'script:TargetDrives')
$ast112 = Get-LnAst (Get-LnModule $mods '112')
$carW = @(); $fieldW = @()
foreach ($a in $ast112.FindAll({ param($x) $x -is $tAsg }, $true)) {
    $root = $a.Left; while ($root -is $tIdx -or $root -is $tMem) { if ($root -is $tIdx) { $root = $root.Target } else { $root = $root.Expression } }
    if ($root -is $tVar -and $carriers -contains [string]$root.VariablePath.UserPath) { $carW += "$(Get-LnOwner $a) : $($a.Left.Extent.Text)" }
    # Champs Drive et Target d un enregistrement ($res.Drive : champ de la table de resultat de Resolve-DriveOfEra, pas une donnee)
    if ($a.Left -is $tMem -and $a.Left.Member -is $tStr -and @('Drive', 'Target') -contains [string]$a.Left.Member.Value -and $a.Left.Expression.Extent.Text -ne '$res') { $fieldW += "$(Get-LnOwner $a) : $($a.Left.Extent.Text)" }
    if ($a.Left -is $tIdx -and $a.Left.Target -is $tMem -and [string]$a.Left.Target.Extent.Text -eq '$f.O') { $fieldW += "$(Get-LnOwner $a) : $($a.Left.Extent.Text)" }
}
$carM = @($ast112.FindAll({ param($x) $x -is $tInv -and $x.Member -is $tStr -and $mutators -contains [string]$x.Member.Value }, $true) | Where-Object { $e = $_.Expression; while ($e -is $tIdx -or $e -is $tMem) { if ($e -is $tIdx) { $e = $e.Target } else { $e = $e.Expression } }; $e -is $tVar -and $carriers -contains [string]$e.VariablePath.UserPath } | ForEach-Object { "$(Get-LnOwner $_) : $($_.Extent.Text)" })
$carWant = @('$script:DriveCurves', '$script:OldCalib.Curves', '$script:OldCalib.Levels', '$script:LevelShifts', '$script:LevelBrands', '$script:ContentMeasures', '$script:TargetDrives')
$editAst = Get-LnFnAst $mods '112' 'Edit-DriveData'
$editAsg = @($editAst.Body.FindAll({ param($x) $x -is $tAsg }, $true))
$scriptAsg = @($editAsg | Where-Object { $_.Left.Extent.Text -like '$script:*' })
$newVars = @($scriptAsg | ForEach-Object { $_.Right.Extent.Text })
$inits = @{}
foreach ($a in $editAsg) { if ($a.Left -is $tVar -and $newVars -contains $a.Left.Extent.Text) { if (-not $inits.ContainsKey($a.Left.Extent.Text)) { $inits[$a.Left.Extent.Text] = @() }; $inits[$a.Left.Extent.Text] += $a.Right.Extent.Text } }
$badInit = @($newVars | Where-Object { -not $inits.ContainsKey($_) -or @($inits[$_] | Where-Object { @('@{}', '[ordered]@{}', '@()') -cnotcontains $_ -and $_ -notmatch '^\$n\w+ \+ |^,' }).Count -gt 0 -or @('@{}', '[ordered]@{}', '@()') -cnotcontains @($inits[$_])[0] })
$wholeOnly = @($scriptAsg | Where-Object { $_.Left -is $tIdx -or $_.Right -isnot [System.Management.Automation.Language.CommandExpressionAst] -or $_.Right.Expression -isnot $tVar }).Count
$carOwners = (@($carW | ForEach-Object { ($_ -split ' : ')[0] } | Sort-Object -Unique) -join ','); $fieldOwners = (@($fieldW | ForEach-Object { ($_ -split ' : ')[0] } | Sort-Object -Unique) -join ',')
Chk 'I6' ($carOwners -ceq 'Edit-DriveData' -and (@($carW | ForEach-Object { ($_ -split ' : ')[1] }) -join ',') -ceq ($carWant -join ',') -and $carM.Count -eq 0 -and $fieldOwners -ceq 'Edit-DriveData' -and $scriptAsg.Count -eq 8 -and $badInit.Count -eq 0 -and $wholeOnly -eq 0 -and $editAst.Extent.Text -notmatch '\$script:PrecompCurves\[') "dans le module 112, Edit-DriveData est la seule fonction qui ecrit un porteur de l identite ($($carWant.Count) tables et les champs Drive et Target ; avec `$script:DriveLast, les huit porteurs) : affectations de tables entieres seulement, chacune construite a partir d une table vide (@{}, [ordered]@{} ou @()), aucun ajout ni retrait dans une table en place ; la vue n y est jamais ecrite (tables : $carOwners ; champs : $fieldOwners ; $($scriptAsg.Count) affectations, $($carM.Count) retrait(s) ou ajout(s) en place, $($badInit.Count) table(s) non neuve(s), $wholeOnly affectation(s) partielle(s))"
$rd = [System.IO.File]::ReadAllText((Join-Path $mods 'README.md'), [System.Text.Encoding]::UTF8)
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$trd = [System.IO.File]::ReadAllText((Join-Path $Wt 'tests\README.md'), [System.Text.Encoding]::UTF8)
$sec1211 = ''
$mm = [regex]::Match($ch, '(?s)## \[12\.11\].*?(?=\n## \[)')
if ($mm.Success) { $sec1211 = $mm.Value }
$dev = ''
$md = [regex]::Match($sec1211, '(?s)### Pour les développeurs.*$')
if ($md.Success) { $dev = $md.Value }
$userPart = if ($dev) { $sec1211.Substring(0, $sec1211.Length - $dev.Length) } else { $sec1211 }
$entry = @($dev -split "`n" | Where-Object { $_.Contains('**Lecteurs enregistrés, socle.**') })
Chk 'I7' ($rd.Contains('| `112-fn-lecteurs.ps1` |') -and $rd.Contains('`Get-DriveConn`') -and $rd.Contains('`Edit-DriveData`') -and $entry.Count -eq 1 -and $entry[0].Contains('`Get-DriveConn($drive)`') -and $entry[0].Contains('`Edit-DriveData($from, $to, [switch]$Check)`') -and $entry[0] -notmatch 'matériel' -and $userPart -notmatch 'Lecteurs enregistrés|lecteur enregistré' -and $trd.Contains('| `logic-lecteurs-registre` |')) 'README des modules (module 112, fonctions du socle), README des tests, CHANGELOG : entree « Pour les développeurs » seulement (rien dans les rubriques de l utilisateur : rien n enregistre encore un lecteur) ; l entree ne dit aucun comportement verifie sur materiel'

# ================================================================ Q. equivalence avec la source d avant (-Before), cas C8
'--- Q. source d avant le lot (-Before) : meme fichier ecrit, memes arguments ; cas C8'
if (-not $Before) {
    'Q1-Q6    saute : sans -Before <copie de la source de la 12.10 ou de la source d avant le lot>, l equivalence a l octet pres avec cette source et le cas C8 ne sont pas rejoues (M2c compare Save-Config a elle-meme privee des lignes du lot ; M2d fixe les arguments)'
} else {
    $mb = Join-Path $Before 'src\modules'
    if (-not (Test-Path -LiteralPath (Join-Path $mb '120-fn-configuration.ps1'))) { throw "source d avant introuvable sous $Before" }
    $verAfter = [string]$script:Version
    $verBefore = ''
    foreach ($st in (Get-LnAst (Get-LnModule $mb '000')).EndBlock.Statements) { if ($st -is $tAsg -and $st.Left.Extent.Text -eq '$script:Version') { $verBefore = $st.Right.Extent.Text.Trim("'") } }
    $has112 = [bool](Get-LnModule $mb '112')
    # Fonctions que le lot annonce inchangees (specification, § 5.3) : texte identique dans la source d avant
    $same = [ordered]@{
        # 12.11 (lot L7) : Backup-ConfigBeforeRef recoit le parametre -Protect et le motif back : elle n est plus celle de la 12.10
        '120' = @('Export-CurveView','Export-DriveCurves', 'Import-DriveCurves', 'Export-TargetDrives', 'Import-TargetDrives', 'Export-Settings', 'Import-Settings', 'Set-Setting', 'Register-SettingCtl', 'Set-SettingCtlValue')
        '140' = @('Get-TargetDrive', 'Set-TargetDrive', 'Get-TargetDriveItems', 'Get-TargetCurves', 'Get-TargetWriteInfo')
        '240' = @('Get-CalibStoreDrive', 'Split-CrossDrive', 'Get-CrossCalibTargets', 'Get-DriveCurveKey', 'Split-DriveCurveKey', 'Get-DriveCurve', 'Set-DriveCurve', 'Sync-PrecompCurves', 'Get-DriveCurveKeys', 'Get-DriveCurveLabel')
        '110' = @('Invoke-DriveProbe', 'Get-GwDriveKey')
        '210' = @('Start-HeadClean')
    }
    $diff = @(); $nSame = 0
    foreach ($px in @($same.Keys)) { foreach ($n in @($same[$px])) { $a = Get-LnFnAst $mods $px $n; $b = Get-LnFnAst $mb $px $n; $nSame++; if (-not $a -or -not $b -or $a.Extent.Text -cne $b.Extent.Text) { $diff += $n } } }
    Chk 'Q1' ($diff.Count -eq 0 -and -not $has112) "source d avant (version $verBefore, sans module 112) : $nSame fonctions annoncees inchangees (magasin, vue, configuration des courbes, lecteurs cibles, liaisons des reglages, sonde et nettoyage) identiques mot pour mot ; ecarts : $(if ($diff.Count) { $diff -join ', ' } else { 'aucun' })"
    # Monde d avant : memes controles, meme etat, fonctions de la source d avant (le module 112 n y existe pas)
    $genFnB = Join-Path $here 'gen-fonctions-avant.ps1'
    $fnB = New-LnFnGen $mb $genFnB
    . $genFnB
    function Set-LnBannerBefore([string]$id) { $sv = $script:SettingSync; $script:SettingSync = $true; try { $cmbDrive.SelectedItem = $id } finally { $script:SettingSync = $sv }; $script:Settings['drive'] = $id; Sync-PrecompCurves }
    $script:RealBanner = ${function:Set-LnBanner}
    ${function:Set-LnBanner} = ${function:Set-LnBannerBefore}
    $script:Version = $verAfter
    $rtB = Invoke-LnRoundTrip 'q-avant' $startJson
    Chk 'Q2' ($rtB.Load -and $rtB.Save1 -and (Get-LnBytesId $rtB.B1) -ceq (Get-LnBytesId $rtA.B1) -and (Get-LnBytesId $rtB.B3) -ceq (Get-LnBytesId $rtA.B3) -and $rtB.Files -ceq $rtA.Files) "meme configuration 12.10 de depart, chargee et reenregistree par les fonctions de la source d avant (version $verBefore ; calibVersion ecrit $verAfter des deux cotes) puis par celles du lot : fichier identique a l octet pres ($(Get-LnBytesId $rtB.B1) ; lot : $(Get-LnBytesId $rtA.B1))"
    Chk 'Q3' ($rtB.Args -ceq $rtA.Args -and $rtB.Log -ceq $rtA.Log -and $rtB.LogLoad -ceq $rtA.LogLoad -and $rtB.Keys -ceq $rtA.Keys -and $rtB.View -ceq $rtA.View) "memes arguments --drive= de toutes les commandes ($(@($rtA.Args -split "`n").Count)), meme journal, meme magasin et meme vue"
    # C8 : la source d avant devant une configuration a lecteurs enregistres. Le fichier est ecrit par les fonctions du lot
    . $genFn
    ${function:Set-LnBanner} = $script:RealBanner
    Start-LnCase 'c8'
    Set-LnTwoDrives
    Set-DriveCurve 'B' 'long' (New-Cv 'B' 'long' $null '08/11/2026 10:00' '0=33:40=73')
    [void](Set-TargetDrive 'B' '1')
    [void](Save-Config)
    $keys8 = Get-LnFileKeys $script:ConfigFile; $sig8 = Get-LnFileSigs $script:ConfigFile
    $cfg8 = $script:ConfigFile
    . $genFnB
    ${function:Set-LnBanner} = ${function:Set-LnBannerBefore}
    $script:Version = $verAfter
    Clear-LnMemory
    $script:ConfigFile = $cfg8
    $err8 = ''; $l8 = $false; $s8 = $false
    try { $l8 = [bool](Load-Config); Sync-PrecompCurves } catch { $err8 = [string]$_.Exception.Message }
    $view8A = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ',')
    Set-LnBannerBefore 'B'; $view8B = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ','); $args8 = (Get-CommonArgs) -join ' '
    Set-LnBannerBefore 'A'
    $mem8 = Get-LnSortedText @($script:DriveCurves.GetEnumerator() | ForEach-Object { [string]$_.Key })
    $bad8 = Get-LogN 'Configuration : 1 lecteur(s) cible illisible(s) ou inconnu(s), ignoré(s).'
    $tg8 = (@($script:TargetDrives.GetEnumerator() | ForEach-Object { "$($_.Key)>$($_.Value)" }) -join ',')
    try { $s8 = [bool](Save-Config) } catch { $err8 += [string]$_.Exception.Message }
    $f8 = Read-LnJson $cfg8
    $keys8b = Get-LnFileKeys $cfg8; $sig8b = Get-LnFileSigs $cfg8
    $td8 = (@($f8.write.targetDrive.PSObject.Properties | ForEach-Object { "$($_.Name)>$($_.Value)" }) -join ',')
    Chk 'Q4' ($err8 -ceq '' -and $l8 -and $s8 -and $view8A -ceq '' -and $view8B -ceq 'long' -and $args8 -ceq '--drive=B' -and $mem8 -ceq $keys8) "C8, fonctions de la source d avant (version $verBefore) devant une configuration a lecteurs enregistres : aucune erreur ; vue de A vide (A a ete nomme : profil d origine), vue de B : sa courbe ; les $(@($keys8 -split "`n").Count) courbes, a nom comprises, gardees en memoire sans etre appliquees"
    Chk 'Q5' ($keys8b -ceq $keys8 -and $sig8b -ceq $sig8 -and $bad8 -eq 1 -and $tg8 -ceq 'B>1' -and $td8 -ceq 'B>1' -and $null -eq (Get-LnProp $f8 'drives') -and (Test-Path -LiteralPath ($cfg8 + '.lecteurs'))) "C8 : cles a nom reecrites telles quelles ($(@($keys8b -split "`n" | Where-Object { $_ -like '*Sony*' -or $_ -like '*TEAC*' }).Count) cles a nom, memes courbes) ; lecteur cible a nom compte ($bad8 ligne) puis absent du fichier (il reste $td8) ; bloc drives perdu, copie de secours intacte"
    # Retour : fonctions du lot devant le fichier que la source d avant a reecrit
    . $genFn
    ${function:Set-LnBanner} = $script:RealBanner
    Clear-LnMemory
    $script:ConfigFile = $cfg8
    $l8r = [bool](Load-Config); Sync-PrecompCurves
    Set-LnBanner 'Sony MPF920'; $view8S = (@($script:CurveKeys | Where-Object { $script:PrecompCurves[$_] }) -join ','); Set-LnBanner 'A'
    Chk 'Q6' ($l8r -and ((Get-LnRegNames) -join ',') -ceq 'Sony MPF920,TEAC FD-235HF' -and $script:DriveRescued -and (Get-TargetDrive 'Sony MPF920') -ceq 'TEAC FD-235HF' -and (Get-TargetDrive 'B') -ceq '1' -and $view8S -ceq 'std,std_h0,std_h1' -and (Get-LogN 'Lecteurs enregistrés relus dans la copie de secours*Sony MPF920 : 5 courbe(s) dont 2 croisée(s)*Lecteurs cibles rétablis depuis cette copie : Sony MPF920 → TEAC FD-235HF.*') -eq 1 -and (Test-LnInv).Count -eq 0) 'retour : registre relu dans la copie de secours, courbes retrouvees sous leurs noms, lecteur cible du lecteur nomme retabli, une ligne de journal qui le dit'
}

$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-lecteurs-registre : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
