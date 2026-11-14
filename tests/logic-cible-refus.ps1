param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-fix1-rc5-d) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Cas W1 saute sans -Wiki.
# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_tests.py) : copie de logic-1210-fix1-rc5-c.ps1 ; passages du wiki d apres le commit 54f3e91 ; Get-CalibEnvBlock extraite.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-fix1-rc5-b.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (B1, D3 ; I1 : cles de 018 de la RC6).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites ; phrase du cadre d un refus faute de courbe croisee : refus de la restauration au lancement (B1).
# Correction fix1 de la RC5 12.10 (10/11/2026, v1210\rc5\fix1), d apres la relecture r10 (v1210\rc5\revue\r10-14c276c,
# r10-logique.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un
# fichier de travail puis chargees par dot-source ; controles WinForms reels jamais affiches ; bouchons pour l interface et
# gw ; fichiers d essai factices dans img\ ; instructions reelles de 520 enveloppees dans gen-1210-fix1-rc5-ui.ps1).
# Un cas par correction, qui echoue sur la source d avant :
#  A  m-CROISEE-SECTEURS-DURS : Start-CrossCalib reel, refus avant la fenetre quelle que soit l image (Get-CalibSettingBlock) ;
#  B  B-RS-REGLES-SANS-COURBE : Get-RestorePlan 'refused' pour tout refus, regles, cadre et bouton « Courbe » de la
#     restauration (Update-RsCalib, Update-RsRules, Get-RsCalibText, Get-RsCurveSet reels) ; copie de flux sans courbe ;
#  K  m-COURBE-REFUS-CIBLE : bouton « Courbe » de l onglet Ecriture (Update-CurveButton, Get-WCurveSet) sur un refus ;
#  F  m-COURBE-CASE-PRECOMP : gestionnaire reel de la case --precomp (520) ;
#  C  m-HD-CIBLE-TEXTES : affectation reelle de $head de Show-CalibReview et journal reel de Complete-PrecompCalib ;
#  D  m-RAPPORT-REFUS-NON-ATTEINT : Write-RestoreReport reel ;
#  R  m-RESET-INFOBULLE : Reset-CalibProfiles reel et instruction reelle de l infobulle du bouton (520) ;
#  L  m-INFOBULLE-LECTEUR-CIBLE : Update-TargetDriveUi reel ; I traductions ; X CHANGELOG ; W wiki (B-WIKI-COURBE,
#     m-WIKI-CASE-MESURE) ; S mesure hors ecran des regles du refus faute de courbe croisee (372 px).
# Sur la source d avant (14c276c, old-14c276c ; wiki d avant : wiki-avant-fix1) : NON CONFORME attendu pour A1 a A3, A6,
# B1-*, B2-*, B4, K1 a K3, F-True, F-False, C1, C2, D1, D3, R1, R2-*, L1-*, I1, X1, W1 ; conformes, car inchanges :
# A4, A5, B3-*, K4, C3, D2, S1 (fix1-test-14c276c.txt : 8 conformes sur 38).
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '260-fn-calib-rapide.ps1'))) { throw "modules introuvables sous $Wt" }
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
. (Join-Path $m '040-etat-formats.ps1')

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Get-Ast([string]$file) { $tok = $null; $err = $null; return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err) }
$all = @{}; $allAst = @{}; $modOf = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '*.ps1')) {
    foreach ($fn in @((Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))) { $all[$fn.Name] = $fn.Extent.Text; $allAst[$fn.Name] = $fn; $modOf[$fn.Name] = $f.Name }
}
function Get-Stmt([string]$fn, [string]$typeName, [string]$startsWith, [string]$contains = '') {
    # Texte de l instruction la plus large de la fonction $fn, par son type et son debut ; '' si absente
    if (-not $allAst.ContainsKey($fn)) { return '' }
    $hits = @($allAst[$fn].Body.FindAll({ param($x) $x.GetType().Name -eq $typeName -and $x.Extent.Text.StartsWith($startsWith) -and (-not $contains -or $x.Extent.Text.Contains($contains)) }, $true) | Sort-Object { $_.Extent.Text.Length } -Descending)
    if ($hits.Count -eq 0) { return '' }
    return $hits[0].Extent.Text
}
$want = @('Update-SlowUi', 'Get-WarmMinutesText', 'Get-TargetDrive', 'Set-TargetDrive', 'Get-DriveIds', 'Get-TargetWriteInfo', 'Get-TargetWriteBlock',
          'Test-TargetWriteAllowed', 'Test-RawFluxWrite', 'Test-FluxImage', 'Get-ImageEncoding', 'Test-NonMfmWrite', 'Get-HighDensityReason', 'Test-HdFormat',
          'Get-ImageFamily', 'Get-HdCalibFamily', 'Get-FormatCalibInfo', 'Get-HfeCellInfo', 'Get-IpfCellInfo', 'Get-ScpCellInfo', 'Get-BE32', 'Test-AdfHd',
          'Get-TargetCurves', 'Get-DriveFamilyCurves', 'Get-DriveCurve', 'Get-DriveCurveKey', 'Set-DriveCurve', 'Split-DriveCurveKey', 'Get-CurveDate',
          'Get-CalibFamilyName', 'Get-FamilyCurves', 'Test-HeadCurvesCurrent', 'Update-CurveButton', 'Show-RsCurve', 'Update-RsCalib', 'Get-RsCalibText',
          'Get-RestoreTargetInfo', 'Get-RestoreFormat', 'Get-RestorePlan', 'Update-RsRules', 'Start-WriteTabWrite', 'Test-WriteLevelWanted', 'Get-WriteLevelKind',
          'Get-LevelWriteSkip', 'Test-NeedsFormat', 'Get-CellOutOfRange', 'Start-LevelBeforeWrite', 'Start-CrossCalib', 'Get-WriteTabFamily',
          'Get-CrossSwapEstimate', 'Get-CrossCalibTargets', 'Test-CalibImage', 'Get-CalibCylinders', 'Test-ManualPrecomp', 'Start-PresetWrite',
          'Get-CalibState', 'Reset-CalibProfiles', 'Get-DriveCurveKeys', 'Get-DriveCurveLabel', 'Split-CrossDrive', 'Get-CurveKeyLabel', 'Sync-PrecompCurves',
          'Get-Setting', 'Get-FaceSafeWrite', 'Start-LevelCalibButton', 'Get-HomeCalibInfo', 'Write-RestoreReport', 'Get-RestoreStem', 'Update-TargetDriveUi',
          'Get-TargetDriveItems', 'Set-TargetDriveLayout')
$wantNew = @('Get-CalibImageCheck', 'Get-LevelBeforeWriteKind', 'Update-WLevelUi', 'Get-WCurveSet', 'Show-WCurve', 'Get-RsCurveSet', 'Get-CalibSettingBlock', 'Get-CalibEnvBlock', 'Get-CalibResetAfterText', 'Get-WriteImageFamily')
$code = (@($want | ForEach-Object { if (-not $all.ContainsKey($_)) { throw "fonction $_ introuvable" }; $all[$_] }) -join "`r`n`r`n")
# 12.11 (lot L10) : decisions extraites de Start-WriteTabWrite, Start-LevelBeforeWrite et Start-ImageWrite (140, 260),
# chargees quand la source les a (une source d avant le lot n en a pas)
$code += "`r`n`r`n" + (@(@('Get-WriteLevelPlan', 'Get-LevelBeforeWritePlan', 'Get-WriteHeads', 'Get-WriteErasePlan', 'Get-WriteSpecPlan', 'Get-WriteHeadSpecs', 'Get-WriteCheckPlan') | Where-Object { $all.ContainsKey($_) } | ForEach-Object { $all[$_] }) -join "`r`n`r`n")
$code += "`r`n`r`n" + (@($wantNew | Where-Object { $all.ContainsKey($_) } | ForEach-Object { $all[$_] }) -join "`r`n`r`n")
# Instructions reelles enveloppees : fin de calibration complete (270), fenetre de decision (250), calibration rapide (260)
$sTgtC = Get-Stmt 'Complete-PrecompCalib' 'AssignmentStatementAst' '$tgtC = '
$sTgtCIf = Get-Stmt 'Complete-PrecompCalib' 'IfStatementAst' 'if ($tgtC -and (Get-TargetWriteInfo'
$sJrn = Get-Stmt 'Complete-PrecompCalib' 'IfStatementAst' 'if ($cal.Cross) {' 'Profil enregistré dans la configuration et appliqué par le mode Auto à toute image {0}.'
if (-not $sJrn) { throw 'journal de fin de Complete-PrecompCalib introuvable' }
$code += "`r`n`r`nfunction Invoke-EndText(`$cal) {`r`n    `$famTxt = Get-CalibFamilyName `$cal.Family`r`n    `$showLbl = `$true`r`n    $sTgtC`r`n    $sTgtCIf`r`n    $sJrn`r`n    return `$showLbl`r`n}`r`n"
$sTgtR = Get-Stmt 'Show-CalibReview' 'AssignmentStatementAst' '$tgtR = '
$sHead = Get-Stmt 'Show-CalibReview' 'AssignmentStatementAst' '$head = if ('
if (-not $sHead) { throw '$head de Show-CalibReview introuvable' }
$code += "`r`n`r`nfunction Get-RevHead(`$cal, [bool]`$toWrite, [bool]`$noFields) {`r`n    `$lvl = (`$cal.Mode -eq 'level'); `$infoWin = `$false; `$lvl2 = `$null`r`n    $sTgtR`r`n    $sHead`r`n    return `$head`r`n}`r`n"
$sTgtL = Get-Stmt 'Complete-LevelCalib' 'AssignmentStatementAst' '$tgtL = '
$sToF = Get-Stmt 'Complete-LevelCalib' 'AssignmentStatementAst' '$toFields = '
$sToFIf = Get-Stmt 'Complete-LevelCalib' 'IfStatementAst' 'if ($toFields) {' "Calibration rapide depuis l'Accueil"
if (-not $sToF -or -not $sToFIf) { throw 'instructions de Complete-LevelCalib introuvables' }
$code += "`r`n`r`nfunction Invoke-LevelFields(`$cal) {`r`n    `$famTxt = Get-CalibFamilyName `$cal.Family`r`n    $sTgtL`r`n    $sToF`r`n    if (`$toFields) { return `$true }`r`n    $sToFIf`r`n    return `$false`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-fix1-rc5-d.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
$hasNew = @($wantNew | Where-Object { $all.ContainsKey($_) })
"source : $Wt ; nouvelles fonctions presentes : $($hasNew.Count) sur $($wantNew.Count) ($($hasNew -join ', '))"

# --- Etat, controles et bouchons -----------------------------------------------------------------------------------
$script:Settings = @{ levelBeforeWrite = $true; levelBeforeWriteMode = 'content'; restoreFormat = 'auto'; calMode = 'std'; warmFullCalib = $true }
$script:CalWarmupMinutes = 5.0; $script:ScpStatsOk = $true; $script:DriveCurves = @{}; $script:PrecompCurves = @{}; $script:TargetDrives = @{}
$rr = (Get-Content -LiteralPath (Join-Path $m '580-etat-restauration.ps1') -Encoding UTF8 -Raw)
if ($rr -notmatch '\$script:RestoreRules = @\{ ReadRevs = (\d+); ReadRetries = (\d+); SeekRetries = (\d+); WriteRetries = (\d+); RepairPasses = (\d+)') { throw 'RestoreRules introuvable' }
$script:RestoreRules = @{ ReadRevs = [int]$Matches[1]; ReadRetries = [int]$Matches[2]; SeekRetries = [int]$Matches[3]; WriteRetries = [int]$Matches[4]; RepairPasses = [int]$Matches[5] }
$script:Restore = $null; $script:GwProc = $null; $script:GwExe = $PSCommandPath; $script:CalRedo = $null; $script:OpOverride = $null
$script:CurveKeys = @('std', 'std_h0', 'std_h1', 'long', 'long_h0', 'long_h1', 'hd', 'hd_h0', 'hd_h1')
$script:SettingDefs['drive'] = @{ Codes = @('A', 'B', '0', '1', '2', '3') }
$script:Version = '12.10'; $script:LastCheck = $null; $script:RsStepNames = @('Lire', 'Verifier', 'Changer', 'Sonder', 'Calibrer', 'Ecrire', 'Controler', 'Comparer')
$script:PrecompThresholdNs = 1950
$form = New-Object System.Windows.Forms.Form; $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$tip = New-Object System.Windows.Forms.ToolTip
function New-Chk([bool]$c) { $x = New-Object System.Windows.Forms.CheckBox; $x.Checked = $c; return $x }
$chkWSlow = New-Chk $true; $chkWPrecomp = New-Chk $true; $chkWLevel = New-Chk $true; $chkWWarm = New-Chk $true; $chkWCalWarm = New-Chk $true
$chkWLevel.AutoSize = $true; $chkWLevel.Font = $form.Font
$chkWHard = New-Chk $false; $chkWTG43 = New-Chk $false; $chkWEraseEmpty = New-Chk $true; $chkWPostCheck = New-Chk $true
$txtWPrecomp1 = New-Object System.Windows.Forms.TextBox; $lblWPrecomp1 = New-Object System.Windows.Forms.Label
$numWWarmMin = New-Object System.Windows.Forms.NumericUpDown
$cmbWCalMode = New-Object System.Windows.Forms.ComboBox; [void]$cmbWCalMode.Items.AddRange(@('std', 'fine', 'level')); $cmbWCalMode.SelectedIndex = 0
$cmbWLevelMode = New-Object System.Windows.Forms.ComboBox; $lblWLevelMode = New-Object System.Windows.Forms.Label
$cmbWProfile = New-Object System.Windows.Forms.ComboBox; [void]$cmbWProfile.Items.AddRange(@((T 'Auto (selon image)'), (T 'Standard 2 us'), (T 'Long track 1,89 us'), (T 'Manuel'))); $cmbWProfile.SelectedIndex = 0
$cmbWFmt = New-Object System.Windows.Forms.ComboBox; [void]$cmbWFmt.Items.AddRange([object[]]$Formats); $cmbWFmt.SelectedIndex = 0
$txtWFile = New-Object System.Windows.Forms.TextBox; $txtWTracks = New-Object System.Windows.Forms.TextBox
$cmbDrive = New-Object System.Windows.Forms.ComboBox; [void]$cmbDrive.Items.AddRange(@('A', 'B', '0', '1', '2', '3')); $cmbDrive.Text = 'A'
$cmbWTarget = New-Object System.Windows.Forms.ComboBox; $lblWTarget = New-Object System.Windows.Forms.Label
$btnWCurve = New-Object System.Windows.Forms.Button; $btnRsCurve = New-Object System.Windows.Forms.Button
$lblRsCal = New-Object System.Windows.Forms.Label
$lblRsRules = New-Object System.Windows.Forms.Label; $lblRsRules.Font = $form.Font; $lblRsRules.UseCompatibleTextRendering = $true
$lblRsRules.AutoSize = $true; $lblRsRules.MinimumSize = New-Object System.Drawing.Size(372, 0); $lblRsRules.MaximumSize = New-Object System.Drawing.Size(372, 0)
$script:UiReady = $true
$script:WLevelTip = 'INFOBULLE D ORIGINE'
$script:Log = New-Object System.Collections.Generic.List[string]
$script:Calls = New-Object System.Collections.Generic.List[string]
$script:Shown = New-Object System.Collections.Generic.List[object]
function Append-Log([string]$t) { $script:Log.Add($t) }
function Show-AppMessage($t, $c, $b = 'OK', $i = '') { $script:Calls.Add("Show-AppMessage[$c] $t"); $script:Log.Add($t); if ($b -eq 'YesNo') { return $script:MsgAnswer } ; return 'OK' }
function Show-AppConfirm { $script:Calls.Add('Show-AppConfirm'); return $false }
function Start-ImageWrite { $script:Calls.Add('Start-ImageWrite') }
function Start-LevelCalib($lr) { $script:Calls.Add('Start-LevelCalib'); $script:Cal = @{ Mode = 'level' } }
function Start-DiskMeasure($lr, $b) { $script:Calls.Add('Start-DiskMeasure') }
function Start-ContentMeasure($c) { $script:Calls.Add('Start-ContentMeasure') }
function Start-PrecompCalib { param([switch]$ForceFine, $Geom = $null, [string]$Test = '')
    # Debut fidele de Start-PrecompCalib (270:25-26) : Test-CalibImage reel, refus = rien n est lance
    $script:Calls.Add("Start-PrecompCalib(Geom=$(if ($Geom) { $Geom.Fmt } else { '' }))")
    $chk = Test-CalibImage $Geom
    if ($chk) { $script:Calls.Add("Test-CalibImage accepte ($($chk.Family), $($chk.NCyl))"); $script:Cal = @{ Cross = $script:CalCrossAsk } } else { $script:Calls.Add('Test-CalibImage REFUS') }
}
function Show-CrossCalibDialog($src, $targets, $family, $fine, $imgInfo, $slow, $min, $max) { $script:Calls.Add("Show-CrossCalibDialog[$family] $imgInfo"); return @{ Ok = $true; Target = '0'; Family = $family; Fine = $false } }
function Get-LevelRef { return @{ Ok = $true; Units = @(); Class = ''; Why = '' } }
function Confirm-PartialWrite { return $true }
function Get-ImageTrackSet($p) { return @{ '0.0' = $true; '0.1' = $true } }
function Get-ImageCylinders($p) { if ("$p" -match '\.adf$') { return 80 }; return $null }
$script:CalCoarse = @(0, 30, 100); $script:CalMaxVerify = 2; $script:CalMaxRetest = 1
function Get-AppBusy([switch]$Text) { return '' }
function Get-CurveCalcText($cv, [switch]$Plain) { return 'v12.10' }
function Show-PrecompCurve([string]$fam, [bool]$h) { $cv = Get-FamilyCurves $fam $h; $script:Shown.Add(@{ Via = 'Show-PrecompCurve'; Curves = $cv }) }
function Show-CurvesWindow($cvs, $Owner = $null) { $script:Shown.Add(@{ Via = 'Show-CurvesWindow'; Curves = @($cvs | Where-Object { $_ }) }) }
function Test-ContentMeasurable($i, $f) { return @{ Ok = $true } }
function Backup-ConfigBeforeRef { }
function Update-PrecompForImage($p) { }
function Save-Config { }
function Get-CurveCalc($cv) { return '12.10' }
function Get-CurveCalcRef($cv) { return '12.10' }
$script:GeomPath = ''
function New-CalibGeometry($i, $n) { $script:Calls.Add("New-CalibGeometry($($i.Name))"); return $script:GeomPath }
$script:LevelShifts = @{}; $script:ContentMeasures = @(); $script:LevelBrands = @(); $script:OldCalib = $null; $script:CurveForm = $null
$pbWCal = New-Object System.Windows.Forms.ProgressBar; $lblWCal = New-Object System.Windows.Forms.Label
$script:ConfigFile = 'GreaseweazleGUI.json'; $script:MsgAnswer = 'No'

# Fichiers d essai (contenu factice, aucune donnee reelle)
$img = Join-Path $here 'img'; if (-not (Test-Path -LiteralPath $img)) { New-Item -ItemType Directory -Path $img | Out-Null }
$adf = Join-Path $img 'essai.adf'; [System.IO.File]::WriteAllBytes($adf, (New-Object byte[] 901120))
$geomF = Join-Path $img 'geometrie.adf'; [System.IO.File]::WriteAllBytes($geomF, (New-Object byte[] 901120)); $script:GeomPath = $geomF
$scp = Join-Path $img 'essai.scp'; $b = New-Object byte[] 4096; [System.Text.Encoding]::ASCII.GetBytes('SCP').CopyTo($b, 0); [System.IO.File]::WriteAllBytes($scp, $b)
$d64 = Join-Path $img 'essai.d64'; [System.IO.File]::WriteAllBytes($d64, (New-Object byte[] 174848))
$hfe = Join-Path $img 'essai-fm.hfe'; $h = New-Object byte[] 1024; [System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($h, 0); $h[9] = 80; $h[10] = 2; $h[11] = 2; [BitConverter]::GetBytes([uint16]250).CopyTo($h, 12); [System.IO.File]::WriteAllBytes($hfe, $h)
$imgf = Join-Path $img 'essai.img'; [System.IO.File]::WriteAllBytes($imgf, (New-Object byte[] 737280))

function New-Curve([string]$drv, [string]$tgt, [string]$spec) { return @{ Family = 'Standard 2 us'; Drive = $drv; Target = $tgt; Date = '01/11/2026 17:49'; Spec = $spec; Method = 'motif'; Values = [int[]]@(1..80); Test = 'fine'; Converged = $true } }
function Set-Scn([string]$file, [string]$fmt, [int]$prof, [bool]$pc, [bool]$slow, [int]$calMode, [bool]$own, [bool]$cross, [string]$tgt) {
    $script:DriveCurves = @{}; $script:PrecompCurves = @{}
    if ($own) { Set-DriveCurve 'A' 'std' (New-Curve 'A' '' '0=60:40=90:79=130'); Set-DriveCurve 'A' 'std_h0' (New-Curve 'A' '' '0=61:79=131'); Set-DriveCurve 'A' 'std_h1' (New-Curve 'A' '' '0=62:79=132') }
    if ($cross) { Set-DriveCurve 'A>0' 'std' (New-Curve 'A' '0' '0=90:40=120:79=170') }
    Sync-PrecompCurves
    $script:TargetDrives = @{}; if ($tgt) { $script:TargetDrives['A'] = $tgt }
    $txtWFile.Text = $file; $cmbWFmt.Text = $fmt; $cmbWProfile.SelectedIndex = $prof; $chkWPrecomp.Checked = $pc; $chkWSlow.Checked = $slow
    $cmbWCalMode.SelectedIndex = $calMode; $chkWHard.Checked = $false; $script:Calls.Clear(); $script:Log.Clear(); $script:Shown.Clear(); $script:Cal = $null
    $script:Settings.levelBeforeWriteMode = 'content'; $script:Settings.restoreFormat = 'auto'; $script:Settings.calMode = @('std', 'fine', 'level')[$calMode]
}
function Get-Calls([string]$like) { return @($script:Calls | Where-Object { $_ -like $like }) }
function Get-CallsPre([string]$pre) { return @($script:Calls | Where-Object { ([string]$_).StartsWith($pre, [System.StringComparison]::Ordinal) }) }
$NONE = "Aucune image calibrable dans l'onglet Écriture : 80 cylindres, à la densité de la famille choisie."

# =====================================================================================================================
# Correction fix1 de la RC5 (10/11/2026) : cas propres a cette correction. Le cadre ci-dessus (fonctions reelles extraites
# par l AST, bouchons, fichiers d essai factices) est celui de la relecture r10 (v1210\rc5\revue\r10-14c276c\r10-logique.ps1),
# lui-meme repris de fixB. Instructions de l interface (520) enveloppees ci-dessous dans un second fichier de travail.
# =====================================================================================================================
$adfHd = Join-Path $img 'essai-hd.adf'; [System.IO.File]::WriteAllBytes($adfHd, (New-Object byte[] 1802240))
$hardMsg = (T 'Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43) : l''analyse de flux est calibrée pour le MFM double densité.')
$btnWCalReset = New-Object System.Windows.Forms.Button
$a520 = Get-Ast (Join-Path $m '520-ui-ecriture.ps1')
function Get-UiStmt([string]$prefix) {
    $h = @($a520.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith($prefix, [System.StringComparison]::Ordinal) })
    if ($h.Count -ne 1) { throw "instruction de 520 « $prefix » : $($h.Count) trouvee(s)" }
    return $h[0]
}
$stPc = Get-UiStmt '$chkWPrecomp.Add_CheckedChanged('
$sbPc = @($stPc.FindAll({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))[0].Extent.Text
$stRt = (Get-UiStmt '$tip.SetToolTip($btnWCalReset,').Extent.Text
$genUi = Join-Path $here 'gen-1210-fix1-rc5-d-ui.ps1'
$uiCode = "function Invoke-PrecompHandler {`r`n" + $sbPc.Substring(1, $sbPc.Length - 2) + "`r`n}`r`n`r`nfunction Invoke-ResetTip {`r`n    $stRt`r`n}`r`n"
[System.IO.File]::WriteAllText($genUi, $uiCode, (New-Object System.Text.UTF8Encoding($true)))
. $genUi
if (-not (Get-Command Sync-WTargetHead -CommandType Function -ErrorAction SilentlyContinue)) { function Sync-WTargetHead([switch]$IfOwn) { } }
if (-not (Get-Command Update-WriteFactorNote -CommandType Function -ErrorAction SilentlyContinue)) { function Update-WriteFactorNote { } }
function Get-CvT($cs) { return (@($cs | ForEach-Object { "$($_.Drive)>$($_.Target)" }) -join ';') }

# ================================================================ A. m-CROISEE-SECTEURS-DURS
"--- A : Start-CrossCalib reel, secteurs durs / TG43 coches : refus avant la fenetre quelle que soit l image (Get-CalibSettingBlock)"
foreach ($c in @(@{ Id = 'A1'; N = 'aucune image, secteurs durs'; F = ''; Fmt = '(auto)'; Hard = $true },
                 @{ Id = 'A2'; N = 'D64 (GCR), TG43'; F = $d64; Fmt = '(auto)'; Hard = $false },
                 @{ Id = 'A3'; N = 'flux SCP, secteurs durs'; F = $scp; Fmt = '(auto)'; Hard = $true },
                 @{ Id = 'A4'; N = 'ADF haute densite (famille hd), TG43'; F = $adfHd; Fmt = 'amiga.amigados_hd'; Hard = $false },
                 @{ Id = 'A5'; N = 'temoin ADF standard calibrable, secteurs durs'; F = $adf; Fmt = 'amiga.amigados'; Hard = $true })) {
    Set-Scn $c.F $c.Fmt 0 $true $false 0 $true $false ''
    if ($c.Hard) { $chkWHard.Checked = $true } else { $chkWTG43.Checked = $true }
    $r = Start-CrossCalib
    $dl = @(Get-Calls 'Show-CrossCalibDialog*').Count
    $msg = @(Get-CallsPre "Show-AppMessage[Calibration precomp] $hardMsg").Count
    $sp = @(Get-Calls 'Start-PrecompCalib*').Count
    Chk $c.Id (-not $r.Started -and $dl -eq 0 -and $msg -eq 1 -and $sp -eq 0 -and [string]$r.Why -eq $hardMsg) "$($c.N) : fenetre de choix $dl fois, message secteurs durs/TG43 $msg fois, Start-PrecompCalib $sp fois, Why « $($r.Why) »"
    $chkWHard.Checked = $false; $chkWTG43.Checked = $false
}
# Ordre des controles de « Calibrer » (Test-CalibImage) inchange : sans image, le message de l image d abord
Set-Scn '' '(auto)' 0 $true $false 0 $true $false ''; $chkWHard.Checked = $true
$ic = Get-CalibImageCheck; $t6 = Test-CalibImage; $m6 = @(Get-Calls 'Show-AppMessage*')
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $false ''; $chkWHard.Checked = $true
$ic2 = Get-CalibImageCheck
$chkWHard.Checked = $false
$sbOk = $false; if (Get-Command Get-CalibSettingBlock -CommandType Function -ErrorAction SilentlyContinue) { $b0 = Get-CalibSettingBlock; $chkWTG43.Checked = $true; $b1 = Get-CalibSettingBlock; $chkWTG43.Checked = $false; $sbOk = ($b0 -eq '' -and $b1 -eq $hardMsg) }
Chk 'A6' (-not $ic.Ok -and $ic.Scope -eq 'image' -and $null -eq $t6 -and $m6.Count -eq 1 -and $m6[0] -like '*Choisissez d''abord l''image*' -and -not $ic2.Ok -and $ic2.Scope -eq 'setting' -and $ic2.Why -eq $hardMsg -and $sbOk) "Test-CalibImage sans image, secteurs durs : « $($m6[0]) » (ordre inchange) ; ADF standard : Scope « $($ic2.Scope) » ; Get-CalibSettingBlock : '' sans case, message avec TG43 ($sbOk)"

# ================================================================ B. B-RS-REGLES-SANS-COURBE, m-COURBE-REFUS-CIBLE (restauration)
"--- B : restauration (Update-RsCalib, Get-RestorePlan, Update-RsRules, Get-RsCalibText, Get-RsCurveSet reels)"
$exp = @{
    fr = @{ Rules = "Règles appliquées à la copie : aucune avec le lecteur cible 0 : sans courbe croisée standard A → 0, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture."
            Cadre = 'Lecteur cible 0 : aucune courbe croisée standard A → 0, la restauration sera refusée au lancement. '
            HdRules = "Règles appliquées à la copie : aucune avec le lecteur cible 0, la restauration au format haute densité amiga.amigados_hd sera refusée au lancement"
            HdCadre = "Lecteur cible 0 : aucune calibration croisée en haute densité, la restauration au format amiga.amigados_hd sera refusée. "
            Cross = "Règles appliquées à la copie : écriture tête par tête par le lecteur A avec la courbe croisée A → 0, telle quelle," }
    en = @{ Rules = 'Rules applied to the copy: none with target drive 0: without a standard cross curve A → 0, the restore will be refused at start. Run "Calibrate for a target drive…", or choose "(same drive)" in the "Target drive" list of the Write tab.'
            Cadre = 'Target drive 0: no standard cross curve A → 0, the restore will be refused at start. '
            HdRules = 'Rules applied to the copy: none with target drive 0, the restore in high-density format amiga.amigados_hd will be refused at start'
            HdCadre = 'Target drive 0: no cross calibration in high density, the restore in format amiga.amigados_hd will be refused. '
            Cross = 'Rules applied to the copy: head-by-head write by drive A with the cross curve A → 0, as is,' }
}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg; $e = $exp[$lg]
    foreach ($fmt in 'amiga.amigados', 'auto', 'ibm.720') {
        Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'
        $script:Settings.restoreFormat = $fmt
        Update-RsCalib
        $pl = Get-RestorePlan 'A' '0' (Get-RestoreFormat)
        $cal = [string]$lblRsCal.Text; $rul = [string]$lblRsRules.Text; $tt = [string]$tip.GetToolTip($lblRsCal); $cs = Get-RsCurveSet
        Chk "B1-$lg-$fmt" ($pl.Kind -eq 'refused' -and $pl.Ti.BlockKind -eq 'none' -and [bool]$pl.Ti.Block -and $rul -ceq $e.Rules -and $cal.StartsWith($e.Cadre, [System.StringComparison]::Ordinal) -and $tt -ceq $cal -and -not $btnRsCurve.Enabled -and @($cs).Count -eq 0) "aucune courbe croisee A -> 0 : Kind $($pl.Kind), BlockKind « $($pl.Ti.BlockKind) » ; regles « $rul » ; cadre en tete du refus $($cal.StartsWith($e.Cadre, [System.StringComparison]::Ordinal)) ; infobulle = cadre $($tt -ceq $cal) ; bouton Courbe actif $($btnRsCurve.Enabled), courbes $(@($cs).Count)"
    }
    Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; Set-DriveCurve 'A' 'hd' (New-Curve 'A' '' '0=40:79=60'); Sync-PrecompCurves
    $script:Settings.restoreFormat = 'amiga.amigados_hd'; Update-RsCalib
    $pl = Get-RestorePlan 'A' '0' (Get-RestoreFormat); $cal = [string]$lblRsCal.Text; $rul = [string]$lblRsRules.Text; $cs = Get-RsCurveSet
    Chk "B2-$lg" ($pl.Kind -eq 'refused' -and $pl.Ti.BlockKind -eq 'hd' -and $rul.StartsWith($e.HdRules, [System.StringComparison]::Ordinal) -and $cal.StartsWith($e.HdCadre, [System.StringComparison]::Ordinal) -and -not $btnRsCurve.Enabled -and @($cs).Count -eq 0) "format haute densite, lecteur cible 0 (courbe haute densite propre presente) : Kind $($pl.Kind) $($pl.Ti.BlockKind) ; regles et cadre du refus haute densite ; bouton Courbe actif $($btnRsCurve.Enabled), courbes $(@($cs).Count) (avant : courbe haute densite du lecteur, que rien n ecrit)"
    Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; $script:Settings.restoreFormat = 'amiga.amigados'; Update-RsCalib
    $pl = Get-RestorePlan 'A' '0' (Get-RestoreFormat); $rul = [string]$lblRsRules.Text; $cs = Get-RsCurveSet
    Chk "B3-$lg" ($pl.Kind -eq 'target' -and -not $pl.Ti.Block -and $rul.StartsWith($e.Cross, [System.StringComparison]::Ordinal) -and $btnRsCurve.Enabled -and (Get-CvT $cs) -eq 'A>0') "temoin : courbe croisee A -> 0 : Kind $($pl.Kind) ; regles de l ecriture avec la courbe croisee ; bouton Courbe actif $($btnRsCurve.Enabled), courbes $(Get-CvT $cs)"
}
$script:Lang = 'fr'
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false ''; $script:Settings.restoreFormat = 'flux'; Update-RsCalib
$csF = Get-RsCurveSet; $enF = [bool]$btnRsCurve.Enabled
$script:Settings.restoreFormat = 'amiga.amigados'; Update-RsCalib
$csS = Get-RsCurveSet; $enS = [bool]$btnRsCurve.Enabled
Chk 'B4' (@($csF).Count -eq 0 -and -not $enF -and $enS -and @($csS).Count -eq 2 -and (Get-CvT $csS) -eq 'A>;A>') "sans lecteur cible : copie exacte du flux, bouton Courbe actif $enF, courbes $(@($csF).Count) (aucune ne s applique) ; copie secteur, actif $enS, courbes $(Get-CvT $csS) (courbes par tete du lecteur)"

# ================================================================ K. m-COURBE-REFUS-CIBLE (onglet Ecriture)
"--- K : bouton « Courbe » de l onglet Ecriture (Update-CurveButton, Get-WCurveSet reels) sur un refus du lecteur cible"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'; Update-CurveButton $adf
$tw = Get-TargetWriteInfo $adf 'amiga.amigados' $true; $wc = Get-WCurveSet $adf 'std'
Chk 'K1' ($tw.BlockKind -eq 'none' -and @($wc).Count -eq 0 -and -not $btnWCurve.Enabled) "aucune courbe croisee (refus « none ») : courbes $(@($wc).Count), bouton actif $($btnWCurve.Enabled) (avant : courbes propres du lecteur A)"
Set-Scn $adfHd 'amiga.amigados_hd' 0 $true $false 0 $true $true '0'; Set-DriveCurve 'A' 'hd' (New-Curve 'A' '' '0=40:79=60'); Sync-PrecompCurves; Update-CurveButton $adfHd
$tw = Get-TargetWriteInfo $adfHd 'amiga.amigados_hd' $false; $wc = Get-WCurveSet $adfHd 'hd'
Chk 'K2' ($tw.BlockKind -eq 'hd' -and @($wc).Count -eq 0 -and -not $btnWCurve.Enabled) "image haute densite, profil Auto (refus « hd ») : courbes $(@($wc).Count), bouton actif $($btnWCurve.Enabled) (avant : courbe haute densite propre)"
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $false '0'; Set-DriveCurve 'A>0' 'std_h0' (New-Curve 'A' '0' '0=91:79=171'); Set-DriveCurve 'A>0' 'std_h1' (New-Curve 'A' '0' '0=92:79=172'); Sync-PrecompCurves; Update-CurveButton $adf
$tw = Get-TargetWriteInfo $adf 'amiga.amigados' $false; $wc = Get-WCurveSet $adf 'std'
Chk 'K3' ($tw.BlockKind -eq 'head' -and @($wc).Count -eq 0 -and -not $btnWCurve.Enabled) "ecriture rapide, courbes croisees par tete seules (refus « head ») : courbes $(@($wc).Count), bouton actif $($btnWCurve.Enabled)"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; Update-CurveButton $adf; $wc = Get-WCurveSet $adf 'std'; $en4 = [bool]$btnWCurve.Enabled
Set-Scn $adf 'amiga.amigados' 3 $true $true 0 $true $false '0'; Update-CurveButton $adf; $wc5 = Get-WCurveSet $adf 'std'; $en5 = [bool]$btnWCurve.Enabled
Chk 'K4' ($en4 -and (Get-CvT $wc) -eq 'A>0' -and $en5 -and (Get-CvT $wc5) -eq 'A>;A>') "temoins : courbe croisee presente : actif $en4, $(Get-CvT $wc) ; profil Manuel (lecteur cible sans effet), sans courbe croisee : actif $en5, $(Get-CvT $wc5)"

# ================================================================ F. m-COURBE-CASE-PRECOMP
"--- F : gestionnaire reel de la case --precomp (520, enveloppe) et bouton « Courbe »"
"  gestionnaire : $($stPc.Extent.Text)"
foreach ($start in $true, $false) {
    Set-Scn $adf 'amiga.amigados' 0 $start $true 0 $false $true '0'      # aucune courbe propre, courbe croisee commune A -> 0
    Update-CurveButton $adf
    $en0 = [bool]$btnWCurve.Enabled
    $chkWPrecomp.Checked = (-not $start)
    Invoke-PrecompHandler
    $en1 = [bool]$btnWCurve.Enabled; $n1 = (Get-WCurveSet $adf 'std').Count
    Chk "F-$start" (($en1 -eq ($n1 -gt 0)) -and $en0 -ne $en1) ("case --precomp {0} -> {1} : bouton actif {2} -> {3} ; courbes que montrerait le clic : {4}" -f $start, (-not $start), $en0, $en1, $n1)
}
$chkWPrecomp.Checked = $true

# ================================================================ C. m-HD-CIBLE-TEXTES
"--- C : fenetre de decision (affectation reelle de `$head de Show-CalibReview) et journal (Complete-PrecompCalib reel), lecteur cible 0"
Set-Scn $adfHd 'amiga.amigados_hd' 0 $true $false 0 $true $true '0'
$twHd = Get-TargetWriteInfo $adfHd 'amiga.amigados_hd' $false
$h = Get-RevHead @{ Mode = 'full'; Drive = 'A'; Family = 'hd'; Cross = $null } $false $false
$script:Log.Clear(); [void](Invoke-EndText @{ Family = 'hd'; Drive = 'A'; Slow = $false; Cross = $null; Units = @() }); $lj = @($script:Log) -join ' / '
$script:Log.Clear(); [void](Invoke-EndText @{ Family = 'hd'; Drive = 'A'; Slow = $true; Cross = $null; Units = @() }); $ljS = @($script:Log) -join ' / '
"  fenetre : « $(($h -replace "`n", ' / ')) »"
"  journal : « $lj »"
$hdRef = 'ses écritures haute densité en profil Auto sont refusées'
Chk 'C1' ($twHd.BlockKind -eq 'hd' -and $h.Contains($hdRef) -and -not $h.Contains('appliquent la courbe croisée A → 0')) "calibration haute densite : fenetre « ... $hdRef ... », sans « appliquent la courbe croisee A -> 0 »"
Chk 'C2' ($lj.Contains($hdRef) -and -not $lj.Contains('appliquent la courbe croisée A → 0') -and $ljS.StartsWith('Profils par tête', [System.StringComparison]::Ordinal) -and $ljS.Contains($hdRef)) "journal haute densite, profil commun et profils par tete : refus en profil Auto, sans courbe croisee appliquee"
$hS = Get-RevHead @{ Mode = 'full'; Drive = 'A'; Family = 'std'; Cross = $null } $false $false
$script:Log.Clear(); [void](Invoke-EndText @{ Family = 'std'; Drive = 'A'; Slow = $false; Cross = $null; Units = @() }); $ljD = @($script:Log) -join ' / '
Chk 'C3' ($hS.Contains('ses écritures appliquent la courbe croisée A → 0 (refusées sans elle)') -and $ljD.Contains('ses écritures précompensées appliquent la courbe croisée A → 0, et sont refusées sans elle')) "temoin double densite : fenetre et journal nomment la courbe croisee appliquee (inchanges)"

# ================================================================ D. m-RAPPORT-REFUS-NON-ATTEINT
"--- D : Write-RestoreReport reel, ligne « Regles »"
$outR = Join-Path $here 'out-rapports'; if (-not (Test-Path -LiteralPath $outR)) { New-Item -ItemType Directory -Path $outR | Out-Null }
function Get-RepRules([string]$id, [string]$mode, [string]$fmt, [string]$plan, [string]$target, [string]$choice) {
    $script:Restore = @{ Mode = $mode; Fmt = $fmt; Choice = $choice; Plan = $plan; Target = $target; TgtChoice = '0'; Drive = 'A'; Name = $id; Dir = $outR; Found = $fmt
                         Orig = ''; Back = (Join-Path $outR "$id - copie.img"); Report = (Join-Path $outR "$id - rapport.txt"); Stem = (Join-Path $outR $id); SectorRead = $null; Read = $null
                         Level = $null; Preserved = @(); Start = (Get-Date); Steps = @{} }
    Remove-Item -LiteralPath $script:Restore.Report -ErrorAction SilentlyContinue
    Write-RestoreReport $false 'RESTAURATION ÉCHOUÉE'
    $rl = [string](@(Get-Content -LiteralPath $script:Restore.Report -Encoding UTF8 | Where-Object { $_ -like 'Règles *' }) -join '')
    $script:Restore = $null
    return $rl
}
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'
$d1 = Get-RepRules 'D1' 'sector' 'ibm.1440' '' '' 'auto'
$d2 = Get-RepRules 'D2' 'sector' 'ibm.1440' 'refused' '0' 'auto'
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'
$d3 = Get-RepRules 'D3' 'sector' 'amiga.amigados' '' '' 'amiga.amigados'
"  D1 « $d1 »"; "  D2 « $d2 »"; "  D3 « $d3 »"
Chk 'D1' ($d1 -ceq "Règles      : lecture 5 tours, 10 essais x 3 séries ; écriture pour le lecteur cible 0 non atteinte (elle serait refusée en haute densité : la calibration croisée n'existe qu'en double densité).") "arret avant l ecriture, original detecte haute densite : « non atteinte », et non « refusee, rien n a ete ecrit »"
Chk 'D2' ($d2 -ceq "Règles      : lecture 5 tours, 10 essais x 3 séries ; écriture pour le lecteur cible 0 refusée, rien n'a été écrit.") "temoin : refus de Start-RestoreWrite (Plan 'refused') : « refusee, rien n a ete ecrit » (inchange)"
Chk 'D3' ($d3 -ceq "Règles      : lecture 5 tours, 10 essais x 3 séries ; écriture pour le lecteur cible 0 non atteinte (elle serait refusée sans courbe croisée standard A → 0).") "decision refaite sans courbe croisee (refus « none ») : « non atteinte », et non l ecriture avec la courbe croisee"

# ================================================================ R. m-RESET-INFOBULLE
"--- R : « Effacer les calibrations » : message (Reset-CalibProfiles reel) et infobulle (instruction reelle de 520)"
$after = @{ fr = (T "Ensuite, le mode Auto applique les profils d'origine :`n- « Test standard » ou « Test fin » : « Écriture rapide » et « Écriture lente » de la Bibliothèque calibrent d'abord le lecteur ; « ÉCRIRE LA DISQUETTE » écrit sans calibrer ;`n- « Test rapide » : l'écriture d'une image calibrable en double densité est refusée sans nouvelle calibration complète du lecteur, à faire sur une disquette sacrifiée depuis la carte « Calibrer le lecteur » de l'Accueil ;`n- restauration d'une copie secteur par secteur en double densité : chaque tête est d'abord calibrée en test fin.") }
$script:Lang = 'en'; $after.en = (T "Ensuite, le mode Auto applique les profils d'origine :`n- « Test standard » ou « Test fin » : « Écriture rapide » et « Écriture lente » de la Bibliothèque calibrent d'abord le lecteur ; « ÉCRIRE LA DISQUETTE » écrit sans calibrer ;`n- « Test rapide » : l'écriture d'une image calibrable en double densité est refusée sans nouvelle calibration complète du lecteur, à faire sur une disquette sacrifiée depuis la carte « Calibrer le lecteur » de l'Accueil ;`n- restauration d'une copie secteur par secteur en double densité : chaque tête est d'abord calibrée en test fin."); $script:Lang = 'fr'
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; $script:MsgAnswer = 'No'
Reset-CalibProfiles
$rm = [string](@(Get-Calls 'Show-AppMessage*')[0])
$keptNew = "`n- lecteur cible gardé (A → 0) : les écritures précompensées pour ce lecteur cible (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée (« Calibrer pour un lecteur cible… »), ou choisissez « (même lecteur) » dans la liste « Lecteur cible »."
Chk 'R1' ($rm.Contains($keptNew) -and $rm.Contains($after.fr)) "message de confirmation : suite de l effacement (restauration comprise) et lecteur cible garde, refus limites aux ecritures precompensees hors profil Manuel et aux restaurations en copie secteur"
$tipKept = @{ fr = "Le lecteur cible choisi est gardé : les écritures précompensées pour lui (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée."
              en = 'The chosen target drive is kept: precompensated writes for it (except with the Manual profile) and sector-copy restores for it are refused until a new cross calibration.' }
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Invoke-ResetTip
    $rt = [string]$tip.GetToolTip($btnWCalReset)
    Chk "R2-$lg" ($rt.Contains($after[$lg]) -and $rt.EndsWith($tipKept[$lg], [System.StringComparison]::Ordinal) -and -not $rt.Contains('seules') -and -not $rt.Contains('et au « Test rapide » l''écriture est refusée') -and -not $rt.Contains('and with "Quick test" the write is refused')) "infobulle du bouton ($lg) : suite de l effacement identique au message (restauration, images calibrables en double densite), lecteur cible garde dit avec ses cas ; $($rt.Length) caracteres"
}
$script:Lang = 'fr'

# ================================================================ L. m-INFOBULLE-LECTEUR-CIBLE
"--- L : infobulle de la liste « Lecteur cible » (Update-TargetDriveUi reel)"
$lt = @{ fr = @('écriture refusée en haute densité avec le profil Auto', 'une image FM, GCR ou à codage propre', "pour la famille de l'image (ou du profil forcé)")
         en = @('write refused in high density with the Auto profile', 'an FM, GCR or system-specific-encoding image', 'for the image family (or that of the forced profile)') }
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; Update-TargetDriveUi
    $ttL = [string]$tip.GetToolTip($cmbWTarget)
    $okL = @($lt[$lg] | Where-Object { -not $ttL.Contains($_) }).Count -eq 0
    Chk "L1-$lg" ($okL -and $ttL -ceq [string]$tip.GetToolTip($lblWTarget)) "infobulle ($lg) : refus haute densite en profil Auto, codage propre parmi les cas sans effet, famille du profil force"
}
$script:Lang = 'fr'

# ================================================================ I. traductions
"--- I : textes T(...) des fonctions et instructions modifiees : tous traduits, cles nouvelles traduites"
$fI = @('Get-RsCalibText', 'Get-RestorePlan', 'Update-RsRules', 'Write-RestoreReport', 'Get-RsCurveSet', 'Update-RsCalib', 'Get-WCurveSet', 'Update-CurveButton',
        'Get-CalibSettingBlock', 'Get-CalibImageCheck', 'Start-CrossCalib', 'Complete-PrecompCalib', 'Show-CalibReview', 'Reset-CalibProfiles', 'Get-CalibResetAfterText', 'Update-TargetDriveUi')
$miss = @(); $nT = 0
foreach ($fn in $fI) {
    if (-not $allAst.ContainsKey($fn)) { $miss += "$fn absente"; continue }
    foreach ($c in @($allAst[$fn].FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' }, $true))) {
        $a = @($c.CommandElements)[1]
        if ($a -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $nT++; if (-not $script:I18n.ContainsKey($a.Value)) { $miss += "$fn : $($a.Value.Substring(0, [math]::Min(70, $a.Value.Length)))" } }
    }
}
foreach ($st in @($stRt, [string](@($a520.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('$tip.SetToolTip($btnWCurve, $tip.GetToolTip($btnWCurve)', [System.StringComparison]::Ordinal) }) | ForEach-Object { $_.Extent.Text }), [System.IO.File]::ReadAllText((Join-Path $m '540-ui-accueil-restauration-barre.ps1')))) {
    foreach ($x in @([regex]::Matches($st, '\(T "([^"]*(?:lecteur cible|Efface toutes|courbe croisée|Affiche la courbe de précompensation appliquée par la restauration)[^"]*)"\)'))) { $nT++; $k = $x.Groups[1].Value.Replace('`n', "`n"); if (-not $script:I18n.ContainsKey($k)) { $miss += "UI : $($k.Substring(0, [math]::Min(70, $k.Length)))" } }
}
$newK = @("Règles appliquées à la copie : aucune avec le lecteur cible {0} : sans courbe croisée standard {1} → {0}, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture.",
          "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {3} non atteinte (elle serait refusée en haute densité : la calibration croisée n'existe qu'en double densité).",
          "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {3} non atteinte (elle serait refusée sans courbe croisée standard {4} → {3}).",
          "Le lecteur cible choisi est gardé : les écritures précompensées pour lui (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée.")
$nk = @($newK | Where-Object { -not $script:I18n.ContainsKey($_) -or [string]$script:I18n[$_] -eq $_ -or [string]$script:I18n[$_] -match '[éèàù«»]' })
$hasAll = @('Get-CalibSettingBlock', 'Get-CalibEnvBlock', 'Get-CalibResetAfterText', 'Get-WCurveSet', 'Get-RsCurveSet') | Where-Object { -not $all.ContainsKey($_) }
Chk 'I1' ($miss.Count -eq 0 -and $nk.Count -eq 0 -and @($hasAll).Count -eq 0) "$nT textes lus : tous traduits ; nouvelles cles traduites ($($newK.Count - $nk.Count) sur $($newK.Count))$(if ($miss.Count) { ' ; manquants : ' + (($miss | Select-Object -First 4) -join ' | ') })$(if (@($hasAll).Count) { ' ; fonctions absentes : ' + ($hasAll -join ', ') })"

# ================================================================ X, W : CHANGELOG et wiki
"--- X, W"
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
$xOk = $cl.Contains('Get-CalibSettingBlock') -and $cl.Contains('Get-CalibResetAfterText') -and $cl.Contains("refusée avant cette fenêtre, quelle que soit l'image de l'onglet") -and $cl.Contains('format haute densité choisi ou aucune courbe croisée standard, le cadre et le texte des règles annoncent ce refus') -and -not $cl.Contains('dit que seules « Écriture rapide »') -and $cl.Contains('une restauration en copie secteur double densité calibre d''abord chaque tête en test fin') -and $cl.Contains("n'a pas été atteinte")
Chk 'X1' $xOk "CHANGELOG : refus de la restauration faute de courbe croisee, secteurs durs quelle que soit l image, infobulle de l effacement (sans « seules », restauration comprise), rapport « non atteinte », notes des developpeurs"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
    function Get-Wk([string]$n) { $p = Join-Path $Wiki $n; if (Test-Path -LiteralPath $p) { return [System.IO.File]::ReadAllText($p) }; return '' }
    $wE = Get-Wk 'Écriture.md'; $wP = Get-Wk 'Précompensation-et-calibration.md'; $wR = Get-Wk 'Restaurer-une-disquette.md'; $wD = Get-Wk 'Dépannage.md'; $wC = Get-Wk 'Configuration-et-fichiers.md'
    $gone = @(
        @('Écriture.md', $wE, "Les courbes croisées ne s'affichent qu'à la fin de leur calibration"),
        @('Écriture.md', $wE, "pas avec le lecteur cible. La case « Mesurer la disquette avant l'écriture lente (…) » et la liste « Mesure : » sont inactives"),
        @('Précompensation-et-calibration.md', $wP, "montrent les courbes propres du lecteur choisi dans le bandeau ; avec un lecteur cible choisi"),
        @('Précompensation-et-calibration.md', $wP, "| Vous écrivez pour un lecteur cible | Sans effet"),
        @('Restaurer-une-disquette.md', $wR, "sinon double densité. Inactif sans aucune courbe. |"),
        @('Restaurer-une-disquette.md', $wR, "dans ce second cas, le texte gris des règles annonce aussi le refus"),
        @('Restaurer-une-disquette.md', $wR, "| Mesure de la destination | Calibration rapide de la disquette de destination avant l'écriture, sauf"),
        @('Dépannage.md', $wD, "| Un lecteur cible est choisi dans la liste « Lecteur cible : » : la mesure relirait"),
        @('Écriture.md', $wE, "les écritures pour lui sont refusées jusqu'à"),
        @('Précompensation-et-calibration.md', $wP, "les écritures pour ce lecteur cible sont refusées."),
        @('Configuration-et-fichiers.md', $wC, "les écritures pour un lecteur cible sont refusées jusqu'à"))
    $left = @($gone | Where-Object { $_[1].Contains($_[2]) } | ForEach-Object { "$($_[0]) : $($_[2].Substring(0, [math]::Min(50, $_[2].Length)))" })
    $here2 = @(
        @($wR, 'dans les deux cas, le texte gris des règles annonce aussi le refus'), @($wR, 'non atteinte (elle serait refusée'),
        @($wE, 'la courbe croisée que l''écriture applique (titre « … (croisée : écriture par le lecteur A, relecture par le lecteur 0) »)'), @($wP, 'Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43)'))
    $absent = @($here2 | Where-Object { -not $_[0].Contains($_[1]) } | ForEach-Object { $_[1] })
    Chk 'W1' ($left.Count -eq 0 -and $absent.Count -eq 0) "wiki : passages d avant fix1 retires ($($left.Count) restant(s)$(if ($left.Count) { ' : ' + ($left -join ' | ') })), nouveaux passages presents ($($absent.Count) absent(s)$(if ($absent.Count) { ' : ' + ($absent -join ' | ') }))"
} else { "  W1 saute (wiki absent)" }

# ================================================================ S. mesures hors ecran
"--- S : regles de la restauration sans courbe croisee (372 px, rendu GDI+ compatible, Segoe UI 9,75)"
function Get-Lines([string]$text, [int]$dpi) {
    $sc = $dpi / 96.0; $w = [int][math]::Round(372 * $sc)
    $font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $bmp.SetResolution($dpi, $dpi); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $cf = 0; $lf = 0; $hh = $g.MeasureString($text, $font, (New-Object System.Drawing.SizeF($w, 10000)), $sf, [ref]$cf, [ref]$lf).Height
    $sf.Dispose(); $g.Dispose(); $bmp.Dispose(); $font.Dispose()
    return @{ Lines = $lf; Bottom = 232 + $hh / $sc }
}
$sOut = @(); $sOk = $true
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($tg in '0', '3') {
        Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false $tg; $script:Settings.restoreFormat = 'auto'; $lblRsRules.Text = ''; Update-RsRules
        foreach ($d in 96, 120, 144) { $x = Get-Lines ([string]$lblRsRules.Text) $d; $sOut += ("{0} cible {1} {2} ppp : {3} lignes, bas {4:N1}" -f $lg, $tg, $d, $x.Lines, $x.Bottom); if ($x.Bottom -ge 516 -or $x.Lines -gt 8) { $sOk = $false } }
    }
}
$script:Lang = 'fr'
Chk 'S1' $sOk "regles du refus faute de courbe croisee (372 px) : bas sous 516 px, 8 lignes au plus ($($sOut -join ' ; '))"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-fix1-rc5-d : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
