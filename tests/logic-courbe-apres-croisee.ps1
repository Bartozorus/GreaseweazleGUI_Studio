param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-rc5fix6) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Cas W1 saute sans -Wiki.
# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_tests.py) : copie de logic-1210-rc5fix5.ps1 ; passages du wiki d apres le commit 54f3e91 ; Get-CalibEnvBlock extraite.
# Copie adaptee par la correction fix2 de la RC6 (10/11/2026, v1210\rc6\fix2\make_fix2_tests.py, source v1210\rc6\fix1\logic-1210-rc5fix4.ps1) : W1 : libelle de la case cite avec son deux-points (« Precompensation (--precomp) : ») dans les passages du wiki sur le bouton « Courbe ».
# Copie adaptee par la correction fix1 de la RC6 (10/11/2026, v1210\rc6\fix1\make_fix1_copies.py, source v1210\rc6\logic-1210-rc5fix3.ps1) : W1 : passages du wiki sur le bouton « Courbe » reecrits par fix1 (profil force, profil Manuel, case --precomp, haute densite non calibrable), ceux de la RC6 retires.
# Copie adaptee par la RC6 (10/11/2026, v1210\rc6\make_rc6_copies.py, source v1210\rc5\fix2\logic-1210-rc5fix2.ps1) : refus de la restauration sans courbe croisee « standard » A -> 0 (2c1eb08) au lieu de « ... en double densite » (T1, T5) ; passages du wiki reecrits par la RC6 (W1 : nouveaux passages, ceux de la RC5 retires).
# Correction fix2 de la RC5 12.10 (10/11/2026, v1210\rc5\fix2), d apres la relecture r11 (v1210\rc5\revue\r11-8375a76,
# r11-logique.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un
# fichier de travail puis chargees par dot-source ; controles WinForms reels jamais affiches ; bouchons pour l interface et
# gw ; fichiers d essai factices dans img\ ; instruction reelle de rafraichissement de fin de Complete-PrecompCalib
# enveloppee dans Invoke-CalEndRefresh). Un cas par correction, qui echoue sur la source d avant :
#  P  B-COURBE-APRES-CROISEE : fin d une calibration croisee avec le lecteur cible deja choisi (bouton « Courbe » de l onglet,
#     infobulle de la case de la mesure, cadre de la restauration) ;
#  G  m-RS-COURBE-REPLI : bouton « Courbe » de la restauration sans lecteur cible (Get-RsCurveSet, Get-RestorePlan) ;
#  H  m-W-COURBE-FLUX-FORMAT : bouton « Courbe » de l onglet Ecriture pour un flux decode par un format (Update-CurveButton,
#     Get-WriteImageFamily, Get-TargetWriteInfo) ;
#  T  m-RS-CADRE-REFUS-LANCEMENT : cadre, regles et refus de Start-Restore ; rapport en anglais (T1, temoin) ;
#  M  mesure hors ecran de la phrase du cadre (262 x 54 px) ; X CHANGELOG (m-CHANGELOG-NON-ATTEINTE et corrections) ;
#  W  wiki.
# Sur la source d avant (8375a76, old-8375a76 ; wiki d avant : wiki-avant-fix2) : NON CONFORME attendu pour P1, G1, G2, H1,
# H3, H4, T5, X1, W1 ; conformes, car inchanges : P2, P3, G3 a G6, H2, T1, M1 (fix2-test-8375a76.txt).
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
# Correction fix2 : rafraichissement de fin de calibration complete (270), instruction reelle (calibration croisee ou non)
$sXEnd = Get-Stmt 'Complete-PrecompCalib' 'IfStatementAst' 'if (-not $cal.Cross) { Update-PrecompForImage'
if (-not $sXEnd) { throw 'rafraichissement de fin de Complete-PrecompCalib introuvable' }
$code += "`r`n`r`nfunction Invoke-CalEndRefresh(`$cal) {`r`n    $sXEnd`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-rc5fix6.ps1'
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
function Update-PrecompForImage($p) { $script:Calls.Add('Update-PrecompForImage') }
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
$genUi = Join-Path $here 'gen-1210-rc5fix6-ui.ps1'
$uiCode = "function Invoke-PrecompHandler {`r`n" + $sbPc.Substring(1, $sbPc.Length - 2) + "`r`n}`r`n`r`nfunction Invoke-ResetTip {`r`n    $stRt`r`n}`r`n"
[System.IO.File]::WriteAllText($genUi, $uiCode, (New-Object System.Text.UTF8Encoding($true)))
. $genUi
if (-not (Get-Command Sync-WTargetHead -CommandType Function -ErrorAction SilentlyContinue)) { function Sync-WTargetHead([switch]$IfOwn) { } }
if (-not (Get-Command Update-WriteFactorNote -CommandType Function -ErrorAction SilentlyContinue)) { function Update-WriteFactorNote { } }
function Get-CvT($cs) { return (@($cs | ForEach-Object { "$($_.Drive)>$($_.Target)" }) -join ';') }

# =====================================================================================================================
# Relecture r11 (10/11/2026) : aides de la relecture (cadre ci-dessus repris de fix1, logic-1210-fix1-rc5.ps1).
# =====================================================================================================================
function Get-Spec($cs) { return (@($cs | ForEach-Object { "$($_.Drive)>$($_.Target)[$($_.Spec)]" }) -join ' ; ') }
$hdSpec = '0=40:79=60'

# =====================================================================================================================
# Correction fix2 de la RC5 (10/11/2026) : cas de la relecture r11 (P1, G1 a G4, H1, H2, T1, T5, M1) repris et completes
# =====================================================================================================================
$lblWProfileInfo = New-Object System.Windows.Forms.Label; $txtWPrecomp = New-Object System.Windows.Forms.TextBox
function Get-TipW { return [string]$tip.GetToolTip($chkWLevel) }
function Cut([string]$t, [int]$n) { return $t.Substring(0, [math]::Min($n, $t.Length)) }

# ================================================================ P. fin d une calibration croisee (B-COURBE-APRES-CROISEE)
"--- P : bouton « Courbe », case de la mesure et cadre de la restauration a la fin d une calibration croisee (Invoke-CalEndRefresh : instruction reelle de Complete-PrecompCalib)"
# P1 : lecteur cible 0 choisi, courbes propres du lecteur A, aucune courbe croisee : etat de l onglet (Update-CurveButton,
# Update-WLevelUi, comme en sortie d Update-PrecompForImage) ; puis courbe croisee A>0 enregistree (Set-DriveCurve, comme
# Complete-PrecompCalib) et instruction reelle de rafraichissement de la fin de calibration, calibration croisee A -> 0
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'; $script:Settings.restoreFormat = 'auto'
Update-CurveButton $adf; Update-WLevelUi
$enB = [bool]$btnWCurve.Enabled; $ttB = Get-TipW; $rsB = [string]$lblRsCal.Text
$lblWProfileInfo.Text = 'BILAN DE LA CALIBRATION CROISEE'; $txtWPrecomp.Text = '0=60:40=90:79=130'
Set-DriveCurve 'A>0' 'std' (New-Curve 'A' '0' '0=90:40=120:79=170'); Sync-PrecompCurves
$script:Calls.Clear()
Invoke-CalEndRefresh @{ Cross = @{ Src = 'A'; Tgt = '0' }; Home = $false; Family = 'std'; Slow = $true; Drive = 'A' }
$enA = [bool]$btnWCurve.Enabled; $ttA = Get-TipW; $rsA = [string]$lblRsCal.Text; $wcA = Get-WCurveSet $adf ([string]$script:CurveFamily)
"  P1 avant : bouton actif $enB ; infobulle de la case « $(Cut $ttB 160)… » ; cadre « $(Cut $rsB 100)… »"
"     apres : bouton actif $enA, courbes du clic $(Get-Spec $wcA) ; infobulle « $(Cut $ttA 160)… » ; cadre « $(Cut $rsA 100)… »"
"     libelle « $($lblWProfileInfo.Text) », champ « $($txtWPrecomp.Text) » ; appels : $(@($script:Calls) -join ', ')"
Chk 'P1' (-not $enB -and $ttB.Contains('Écriture refusée') -and $enA -and (Get-Spec $wcA) -eq 'A>0[0=90:40=120:79=170]' -and -not $ttA.Contains('Écriture refusée') -and $ttA.Contains("L'image est écrite avec la courbe croisée telle quelle") -and $rsB.StartsWith('Lecteur cible 0 : aucune courbe croisée', [System.StringComparison]::Ordinal) -and $rsA.StartsWith('Lecteur cible 0 : courbe croisée A → 0 (commune', [System.StringComparison]::Ordinal)) "fin de la calibration croisee A -> 0 (lecteur cible 0 deja choisi) : bouton « Courbe » de l onglet inactif avant (refus), actif apres avec la courbe croisee que l ecriture applique ; infobulle de la case de la mesure qui ne dit plus « Ecriture refusee » ; cadre de la restauration qui nomme la courbe croisee"
Chk 'P2' ($lblWProfileInfo.Text -eq 'BILAN DE LA CALIBRATION CROISEE' -and $txtWPrecomp.Text -eq '0=60:40=90:79=130' -and @(Get-CallsPre 'Update-PrecompForImage').Count -eq 0) "temoin : calibration croisee : libelle du profil (bilan de la calibration) et champ --precomp inchanges, Update-PrecompForImage non appele"
# P3 : temoin, calibration ordinaire : Update-PrecompForImage (profil et champs refaits), comme avant
$script:Calls.Clear(); Invoke-CalEndRefresh @{ Cross = $null; Home = $false; Family = 'std'; Slow = $true; Drive = 'A' }
Chk 'P3' (@(Get-CallsPre 'Update-PrecompForImage').Count -eq 1) "temoin : calibration ordinaire : Update-PrecompForImage appele $(@(Get-CallsPre 'Update-PrecompForImage').Count) fois"

# ================================================================ G. bouton « Courbe » de la restauration sans lecteur cible (m-RS-COURBE-REPLI)
"--- G : bouton « Courbe » du cadre « Calibration du lecteur » sans lecteur cible (Update-RsCalib, Get-RsCurveSet, Get-RestorePlan reels)"
function Get-RsState { $pl = Get-RestorePlan 'A' '' (Get-RestoreFormat); $cs = Get-RsCurveSet; return @{ Kind = [string]$pl.Kind; En = [bool]$btnRsCurve.Enabled; Spec = (Get-Spec $cs); Rules = [string]$lblRsRules.Text } }
function Show-RsState([string]$id, $g) { "  $id : Kind $($g.Kind) ; bouton actif $($g.En) ; courbes du clic « $($g.Spec) » ; regles « $(Cut $g.Rules 120)… »" }
# G1 : format haute densite choisi, courbes double densite seulement : la copie haute densite n en applique aucune
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false ''
$script:Settings.restoreFormat = 'amiga.amigados_hd'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G1' $g
Chk 'G1' ($g.Kind -eq 'hd' -and -not $g.En -and -not $g.Spec -and $g.Rules.Contains("avec la courbe haute densité existante du lecteur, sinon le profil d'origine")) "format haute densite amiga.amigados_hd, courbes double densite seulement : bouton inactif, aucune courbe montree (la copie ecrit avec le profil d origine haute densite, comme le disent les regles)"
# G2 : format double densite ibm.720, courbe haute densite seulement : la copie calibre d abord chaque tete
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $false $false ''; Set-DriveCurve 'A' 'hd' (New-Curve 'A' '' $hdSpec); Sync-PrecompCurves
$script:Settings.restoreFormat = 'ibm.720'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G2' $g
Chk 'G2' ($g.Kind -eq 'sector' -and -not $g.En -and -not $g.Spec -and $g.Rules.Contains("(calibration par tête si aucune n'existe)")) "format double densite ibm.720, courbe haute densite seulement : bouton inactif, aucune courbe haute densite montree (la copie double densite calibre d abord le lecteur tete par tete)"
# G3 : temoin, detection automatique, courbe haute densite seulement : repli admis (format connu seulement a la lecture)
$script:Settings.restoreFormat = 'auto'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G3' $g
Chk 'G3' ($g.Kind -eq 'sector' -and $g.En -and $g.Spec -eq "A>[$hdSpec]") "temoin : detection automatique, courbe haute densite seulement : bouton actif, courbe haute densite (a defaut de double densite)"
# G4 : temoin, format haute densite, courbes haute densite et double densite : courbe haute densite
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false ''; Set-DriveCurve 'A' 'hd' (New-Curve 'A' '' $hdSpec); Sync-PrecompCurves
$script:Settings.restoreFormat = 'amiga.amigados_hd'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G4' $g
Chk 'G4' ($g.Kind -eq 'hd' -and $g.En -and $g.Spec -eq "A>[$hdSpec]") "temoin : format haute densite, courbe haute densite presente : bouton actif, courbe haute densite"
# G5 : temoin, format double densite ibm.720 et detection automatique, courbes double densite par tete et haute densite :
# courbes double densite par tete
$script:Settings.restoreFormat = 'ibm.720'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G5' $g
$script:Settings.restoreFormat = 'auto'; Update-RsCalib; $g6 = Get-RsState; Show-RsState 'G5-auto' $g6
Chk 'G5' ($g.Kind -eq 'sector' -and $g.En -and $g.Spec -eq 'A>[0=61:79=131] ; A>[0=62:79=132]' -and $g6.En -and $g6.Spec -eq $g.Spec) "temoin : format double densite et detection automatique, courbes double densite par tete et haute densite : courbes double densite par tete"
# G6 : temoin, copie exacte du flux : aucune courbe
$script:Settings.restoreFormat = 'flux'; Update-RsCalib; $g = Get-RsState; Show-RsState 'G6' $g
Chk 'G6' ($g.Kind -eq 'flux' -and -not $g.En) "temoin : copie exacte du flux : bouton inactif"
$script:Settings.restoreFormat = 'auto'

# ================================================================ H. bouton « Courbe » de l onglet Ecriture, images flux (m-W-COURBE-FLUX-FORMAT)
"--- H : bouton « Courbe » de l onglet Ecriture, images flux (Update-CurveButton, Get-WCurveSet, Get-TargetWriteInfo$(if ($all.ContainsKey('Get-WriteImageFamily')) { ', Get-WriteImageFamily' }) reels)"
$svScp = $script:ScpStatsOk; $script:ScpStatsOk = $false    # le fichier SCP d essai n a pas de flux : cellule de la famille standard
# H1 : SCP ecrit au format amiga.amigados pour le lecteur cible 0, courbe croisee A -> 0 : l ecriture applique la courbe croisee
Set-Scn $scp 'amiga.amigados' 0 $true $true 0 $false $true '0'; Update-CurveButton $scp
$tw = Get-TargetWriteInfo $scp 'amiga.amigados' $true; $wc = Get-WCurveSet $scp ([string]$script:CurveFamily)
"  H1 : Get-TargetWriteInfo : Applies $($tw.Applies), Fam $($tw.Fam), Block « $($tw.Block) », courbes ecrites $(Get-Spec $tw.Curves) ; Test-RawFluxWrite $(Test-RawFluxWrite $scp 'amiga.amigados') ; bouton actif $([bool]$btnWCurve.Enabled) ; courbes du clic $(Get-Spec $wc)"
Chk 'H1' ($tw.Applies -and -not $tw.Block -and [bool]$btnWCurve.Enabled -and (Get-Spec $wc) -eq 'A>0[0=90:40=120:79=170]' -and (Get-Spec $wc) -eq (Get-Spec $tw.Curves)) "SCP + format amiga.amigados, lecteur cible 0 avec courbe croisee : bouton actif, courbe croisee A -> 0 que l ecriture applique"
# H2 : temoin, SCP sans format : flux ecrit tel quel, lecteur cible sans effet, bouton inactif
Set-Scn $scp '(auto)' 0 $true $true 0 $true $true '0'; Update-CurveButton $scp
$tw2 = Get-TargetWriteInfo $scp '(auto)' $true
Chk 'H2' (-not $tw2.Applies -and -not $btnWCurve.Enabled) "temoin : SCP sans format (flux ecrit tel quel) : Applies $($tw2.Applies) (« $($tw2.Why) »), bouton actif $([bool]$btnWCurve.Enabled)"
# H3 : SCP + format, sans lecteur cible, courbes propres du lecteur A : courbes du lecteur (champs --precomp du mode Auto)
Set-Scn $scp 'amiga.amigados' 0 $true $true 0 $true $false ''; Update-CurveButton $scp; $wc3 = Get-WCurveSet $scp ([string]$script:CurveFamily)
"  H3 : famille $($script:CurveFamily) ; bouton actif $([bool]$btnWCurve.Enabled) ; courbes du clic $(Get-Spec $wc3)"
Chk 'H3' ([bool]$btnWCurve.Enabled -and $script:CurveFamily -eq 'std' -and (Get-Spec $wc3) -eq 'A>[0=61:79=131] ; A>[0=62:79=132]') "SCP + format amiga.amigados, sans lecteur cible, courbes propres du lecteur A : bouton actif, courbes du lecteur (ecriture lente : par tete)"
# H4 : SCP + format, cellule de flux long track (Get-ScpCellInfo remplace par un bouchon : 1 890 ns ; module d analyse
# present) : famille long track pour le bouton comme pour l ecriture (Get-TargetWriteInfo), sans puis avec lecteur cible
$script:ScpStatsOk = $true
function Get-ScpCellInfo([string]$path) { return @{ CellNs = 1890.0; Bits = 105820; Tracks = 4; DosTracks = -1; Source = 'SCP (flux mesuré)' } }
Set-Scn $scp 'amiga.amigados' 0 $true $true 0 $false $false ''; Set-DriveCurve 'A' 'long' (New-Curve 'A' '' '0=70:79=150'); Sync-PrecompCurves
Update-CurveButton $scp; $f4 = [string]$script:CurveFamily; $en4 = [bool]$btnWCurve.Enabled; $wc4 = Get-WCurveSet $scp $f4
Set-DriveCurve 'A>0' 'long' (New-Curve 'A' '0' '0=95:79=180'); Sync-PrecompCurves; $script:TargetDrives['A'] = '0'
Update-CurveButton $scp; $tw4 = Get-TargetWriteInfo $scp 'amiga.amigados' $true; $en4b = [bool]$btnWCurve.Enabled; $wc4b = Get-WCurveSet $scp ([string]$script:CurveFamily)
"  H4 : sans lecteur cible : famille $f4, bouton actif $en4, courbes $(Get-Spec $wc4) ; lecteur cible 0 : Fam $($tw4.Fam), bouton actif $en4b, courbes $(Get-Spec $wc4b)"
Chk 'H4' ($f4 -eq 'long' -and $en4 -and (Get-Spec $wc4) -eq 'A>[0=70:79=150]' -and $tw4.Fam -eq 'long' -and $en4b -and (Get-Spec $wc4b) -eq 'A>0[0=95:79=180]') "SCP + format, cellule long track : bouton actif avec la courbe long track du lecteur, puis la courbe croisee long track ecrite pour le lecteur cible 0 (meme famille que l ecriture)"
$script:ScpStatsOk = $svScp

# ================================================================ T. rapport en anglais, refus annonce par le cadre (m-RS-CADRE-REFUS-LANCEMENT)
"--- T : rapport en anglais (Write-RestoreReport reel) ; refus faute de courbe croisee dans le cadre, les regles et Start-Restore (Get-RsCalibText, Update-RsRules, Get-RestoreTargetInfo reels)"
$outR = Join-Path $here 'out-rapports'; if (-not (Test-Path -LiteralPath $outR)) { New-Item -ItemType Directory -Path $outR | Out-Null }
function Get-RepRules([string]$id, [string]$mode, [string]$fmt, [string]$plan, [string]$target, [string]$choice, [string]$pre) {
    $script:Restore = @{ Mode = $mode; Fmt = $fmt; Choice = $choice; Plan = $plan; Target = $target; TgtChoice = '0'; Drive = 'A'; Name = $id; Dir = $outR; Found = $fmt
                         Orig = ''; Back = (Join-Path $outR "$id - copie.img"); Report = (Join-Path $outR "$id - rapport.txt"); Stem = (Join-Path $outR $id); SectorRead = $null; Read = $null
                         Level = $null; Preserved = @(); Start = (Get-Date); Steps = @{} }
    Remove-Item -LiteralPath $script:Restore.Report -ErrorAction SilentlyContinue
    Write-RestoreReport $false 'X'
    $rl = [string](@(Get-Content -LiteralPath $script:Restore.Report -Encoding UTF8 | Where-Object { $_.StartsWith($pre, [System.StringComparison]::Ordinal) }) -join '')
    $script:Restore = $null
    return $rl
}
$script:Lang = 'en'
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'
$e1 = Get-RepRules 'T1' 'sector' 'ibm.1440' '' '' 'auto' 'Rules '
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'
$e3 = Get-RepRules 'T3' 'sector' 'amiga.amigados' '' '' 'amiga.amigados' 'Rules '
$script:Lang = 'fr'
"  T1 en « $e1 »"; "  T3 en « $e3 »"
Chk 'T1' ($e1 -ceq 'Rules       : read 5 revolutions, 10 retries x 3 series; write for target drive 0 not reached (it would be refused in high density: cross calibration exists in double density only).' -and $e3 -ceq 'Rules       : read 5 revolutions, 10 retries x 3 series; write for target drive 0 not reached (it would be refused without a standard cross curve A → 0).') "temoin : rapport en anglais : « not reached » (haute densite reconnue, sans courbe croisee)"
# T5 : detection automatique, lecteur cible 0 sans courbe croisee : refus de toute la restauration au lancement, dans le
# cadre comme dans les regles et le refus de Start-Restore (avant la lecture), en francais et en anglais
$t5 = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'; $script:Settings.restoreFormat = 'auto'; Update-RsCalib
    $t5[$lg] = @{ Cadre = [string]$lblRsCal.Text; Rules = [string]$lblRsRules.Text; Block = [string](Get-RestoreTargetInfo 'A' '0' 'auto').Block }
    "  T5 $lg : cadre « $(Cut $t5[$lg].Cadre 120)… » ; regles « $(Cut $t5[$lg].Rules 150)… » ; Start-Restore « $(Cut $t5[$lg].Block 60)… »"
}
$script:Lang = 'fr'
Chk 'T5' ($t5.fr.Cadre.StartsWith('Lecteur cible 0 : aucune courbe croisée standard A → 0, la restauration sera refusée au lancement. ', [System.StringComparison]::Ordinal) -and $t5.fr.Rules.Contains('la restauration sera refusée au lancement') -and $t5.fr.Block.StartsWith('Restauration refusée', [System.StringComparison]::Ordinal) -and $t5.en.Cadre.StartsWith('Target drive 0: no standard cross curve A → 0, the restore will be refused at start. ', [System.StringComparison]::Ordinal) -and $t5.en.Rules.Contains('the restore will be refused at start') -and -not $t5.fr.Cadre.Contains('copie secteur sera refusée')) "detection automatique sans courbe croisee : le cadre annonce, comme les regles et le refus de Start-Restore, le refus de la restauration au lancement (francais et anglais)"

# ================================================================ M. mesures hors ecran : cadre « Calibration du lecteur » (262 x 54 px, 3 lignes)
"--- M : phrase de refus en tete du cadre (262 x 54 px, AutoEllipsis, rendu GDI+ compatible, Segoe UI 9,75)"
function Get-Fit([string]$text, [int]$dpi, [int]$w, [int]$h) {
    $sc = $dpi / 96.0
    $font = New-Object System.Drawing.Font('Segoe UI', 9.75)
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $bmp.SetResolution($dpi, $dpi); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $cf = 0; $lf = 0; [void]$g.MeasureString($text, $font, (New-Object System.Drawing.SizeF(([float]($w * $sc)), ([float]($h * $sc)))), $sf, [ref]$cf, [ref]$lf)
    $sf.Dispose(); $g.Dispose(); $bmp.Dispose(); $font.Dispose()
    return @{ Chars = $cf; Lines = $lf }
}
$mOut = @(); $mOk = $true
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($case in @(@{ N = 'aucune courbe croisee'; Fmt = 'auto' }, @{ N = 'haute densite'; Fmt = 'amiga.amigados_hd' }, @{ N = 'haute densite ibm.1440'; Fmt = 'ibm.1440' })) {
        Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'; $script:Settings.restoreFormat = $case.Fmt
        $t = Get-RsCalibText; $first = $t.Substring(0, $t.IndexOf('. ') + 1)
        foreach ($d in 96, 120, 144) { $x = Get-Fit $t $d 262 54; $ok = $x.Chars -ge $first.Length; if (-not $ok) { $mOk = $false }; $mOut += ("{0} {1} {2} ppp : {3}/{4} car. visibles" -f $lg, $case.N, $d, $x.Chars, $first.Length) }
    }
}
$script:Lang = 'fr'; $script:Settings.restoreFormat = 'auto'
Chk 'M1' $mOk "phrase de refus entiere dans les 3 lignes du cadre ($($mOut -join ' ; '))"

# ================================================================ X, W. CHANGELOG et wiki
"--- X, W : CHANGELOG du worktree et pages du wiki"
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$xNew = @("la restauration d'un original reconnu haute densité, arrêtée avant l'écriture (lecture, changement de disquette), dit dans la ligne « Règles »",
          'en copie exacte du flux, le cadre et le texte des règles ne parlent pas du lecteur cible',
          "à la fin d'une calibration croisée qui lève le refus, il redevient actif",
          '- **Boutons « Courbe ».** Dans l''onglet « Écriture », le bouton « Courbe » restait inactif pour toute image flux',
          'il montre la courbe double densité, à défaut la courbe haute densité.',
          '`Get-RsCurveSet` tire les familles de `Get-RestorePlan`', 'sinon `Get-WriteImageFamily`, `Get-ImageFamily` et cellule des SCP')
$xOld = @("arrêtée avant l'écriture (lecture, changement de disquette) dit", 'en copie exacte du flux, ils ne parlent pas du lecteur cible')
$xMiss = @($xNew | Where-Object { -not $cl.Contains($_) }); $xLeft = @($xOld | Where-Object { $cl.Contains($_) })
Chk 'X1' ($xMiss.Count -eq 0 -and $xLeft.Count -eq 0) "CHANGELOG : rapport « non atteinte » limite a l original reconnu haute densite, sujet du flux explicite, bouton « Courbe » apres la calibration croisee, Corrections « Boutons « Courbe » », notes des developpeurs ($($xMiss.Count) passage(s) absent(s)$(if ($xMiss.Count) { ' : ' + ($xMiss -join ' | ') }) ; $($xLeft.Count) ancien(s) restant(s)$(if ($xLeft.Count) { ' : ' + ($xLeft -join ' | ') }))"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
function Get-WikiText([string]$n) { $p = Join-Path $Wiki $n; if (-not (Test-Path -LiteralPath $p)) { return '' }; return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
$wk = @{ P = (Get-WikiText 'Précompensation-et-calibration.md'); R = (Get-WikiText 'Restaurer-une-disquette.md'); E = (Get-WikiText 'Écriture.md') }
$wNew = @(@('P', 'montre dès la fin de la calibration la courbe croisée que l''écriture applique'),
          @('P', 'reçoivent la courbe croisée au lancement de l''écriture'),
          @('P', 'Il est grisé quand l''écriture n''applique aucune courbe calibrée (case « Précompensation (--precomp) : », « Précomp. tête 0 (--precomp) : » en écriture lente, décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; image haute densité non calibrable en profil « Auto », écrite avec le profil d''origine)'),
          @('R', '« Lecteur cible 0 : aucune courbe croisée standard A → 0, la restauration sera refusée au lancement. »'),
          @('R', 'en détection automatique, où le format n''est connu qu''à la lecture, double densité, à défaut haute densité'),
          @('R', 'avant une écriture qui serait refusée (original reconnu haute densité)'),
          @('E', 'Il reste grisé quand l''écriture n''applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; en profil « Auto », image haute densité non calibrable'),
          @('E', 'il redevient actif à la fin de la calibration croisée qui lève ce refus'))
$wOld = @(@('P', 'les champs de précompensation de l''onglet portent le profil de la courbe croisée'), @('P', 'Il est grisé pour un flux (SCP, RAW…)'),
          @('R', 'l''écriture d''une copie secteur sera refusée'), @('R', 'haute densité si le format choisi est haute densité, sinon double densité'),
          @('E', 'Il reste grisé pour un flux (SCP, RAW...)'),
          @('P', 'Il est grisé pour un flux écrit tel quel, sans format (SCP, RAW…)'), @('R', 'courbe croisée A → 0 en double densité'),
          @('E', 'Il reste grisé pour un flux écrit tel quel, sans format (SCP, RAW...)'),
          @('P', 'Il est grisé pour une image à laquelle l''écriture ne transmet pas --precomp (flux écrit tel quel, sans format, SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel »)'), @('E', 'Il reste grisé pour une image à laquelle l''écriture ne transmet pas --precomp : flux écrit tel quel, sans format (SCP, RAW...), ou image FM, GCR ou à codage propre, hors profil « Manuel »'))
$wMiss = @($wNew | Where-Object { -not $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $($_[1])" })
$wLeft = @($wOld | Where-Object { $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $($_[1])" })
Chk 'W1' ($wMiss.Count -eq 0 -and $wLeft.Count -eq 0) "wiki ($Wiki) : passages corriges presents ($($wMiss.Count) absent(s)$(if ($wMiss.Count) { ' : ' + ($wMiss -join ' | ') })), anciens retires ($($wLeft.Count) restant(s)$(if ($wLeft.Count) { ' : ' + ($wLeft -join ' | ') }))"
} else { "  W1 saute (wiki absent)" }

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-rc5fix6 : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
