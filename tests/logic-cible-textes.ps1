param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-fixB-f) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Cas W1 saute sans -Wiki.
# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_tests.py) : copie de logic-1210-fixB-e.ps1 ; passages du wiki d apres le commit 54f3e91 ; Get-CalibEnvBlock extraite ; cas C8 a C9c (calibration croisee sans module d analyse SCP ou sans gw.exe).
# Copie adaptee par la correction fix1 de la RC6 (10/11/2026, v1210\rc6\fix1\make_fix1_copies.py, source v1210\rc5\fix2\logic-1210-fixB-d.ps1) : L8 : sortie d Update-PrecompForImage qui refait aussi le bouton « Courbe » (Update-CurveButton $path, apres la case --precomp recochee).
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : Get-WriteImageFamily (140), appelee par Get-TargetWriteInfo, ajoutee aux fonctions extraites.
# Correction fixB de la RC5 12.10 (10/11/2026, v1210\rc5\fixB), d apres l audit a5 des textes du lecteur cible
# (v1210\rc5\audit\a5-logique.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique,
# ecrites dans un fichier de travail puis chargees par dot-source ; controles WinForms reels jamais affiches ; bouchons pour
# l interface et gw ; fichiers d essai factices dans img\). Un cas par correction, qui echoue sur la source d avant :
#  C  B-CROISEE-IMAGE : Start-CrossCalib reel, image de l onglet d apres Get-CalibImageCheck (celui de Test-CalibImage) ;
#  M  B-MESURE-COMPLETE : Get-LevelBeforeWriteKind, Start-LevelBeforeWrite reel, regles (Update-RsRules) et ligne « Regles »
#     du rapport (Write-RestoreReport reel), case de la mesure au « Test rapide », infobulles, Update-SettingDependents ;
#  T  B-CALIB-FIN-CIBLE : Start-LevelCalibButton reel, instructions reelles de Complete-PrecompCalib, Show-CalibReview et
#     Complete-LevelCalib (enveloppees) ;
#  K  m-COURBE-CIBLE : Update-CurveButton, Get-WCurveSet, Show-WCurve, Update-RsCalib, Get-RsCurveSet, Show-RsCurve reels ;
#  L  m-MESURE-CIBLE : Update-SlowUi et Update-WLevelUi reels, appels (220, 520), infobulle de la liste « Lecteur cible » ;
#  R  m-RESET-CIBLE : Reset-CalibProfiles reel, infobulle du bouton ; B m-BIB-INFOBULLES ; J m-CROISEE-JOURNAL ;
#  H  m-ACCUEIL-TYPES : Get-HomeCalibInfo reel ; I traductions ; X CHANGELOG ; W wiki (« 26 a 31 min ») ;
#  S  mesures hors ecran (regles de la restauration, case de la mesure).
# Sur la source d avant (fdef9f0, old-fdef9f0, wiki d avant wiki-avant-fixB) : NON CONFORME attendu pour C1 a C3, C5,
# C6, M1, M3 a M7, T1, T4, T4b, T5, T6, K1 a K3, L1 a L4, L6 a L9, R1, R3, B1, J1, H1, H2, I1, X1, W1 ; conformes, car
# inchanges : C4, M2, T2, K4, L5, S1, S2 (fixB-test-fdef9f0.txt : 7 conformes sur 43).
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
# Correction fix1 de la RC5 (10/11/2026, v1210\rc5\fix1) : copie adaptee de v1210\rc5\fixB\logic-1210-fixB, qui la remplace
# dans la campagne : Get-CalibSettingBlock (260, lu par Start-CrossCalib) et Get-CalibResetAfterText (240, lu par
# Reset-CalibProfiles) extraits ; R1 : lecteur cible garde, refus limites aux ecritures precompensees hors profil Manuel
# et aux restaurations en copie secteur (cle de fix1) ; L8 : gestionnaire de la case --precomp qui met aussi a jour le
# bouton « Courbe » ; L9 : infobulle de la liste « Lecteur cible » (haute densite en profil Auto, codage propre).
# Autres attentes inchangees.
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
$gen = Join-Path $here 'gen-1210-fixB-f.ps1'
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

# ================================================================ C. calibration croisee : image de l onglet
"--- C : Start-CrossCalib, image de l onglet d apres le controle de la calibration (Get-CalibImageCheck)"
$cc = @(@{ Id = 'C1'; N = 'D64 (GCR, format implicite)'; F = $d64; Fmt = '(auto)' }, @{ Id = 'C2'; N = 'HFE en FM'; F = $hfe; Fmt = '(auto)' },
        @{ Id = 'C3'; N = 'IMG au format raw.125 (cellule de 4 000 ns)'; F = $imgf; Fmt = 'raw.125' })
foreach ($c in $cc) {
    Set-Scn $c.F $c.Fmt 0 $true $false 0 $true $false ''
    $r = Start-CrossCalib
    $dl = @(Get-Calls 'Show-CrossCalibDialog*')
    "  [$($c.Id)] " + ($script:Calls -join ' | ')
    Chk $c.Id ($r.Started -and $dl.Count -eq 1 -and $dl[0] -eq "Show-CrossCalibDialog[std] $NONE" -and (Get-Calls 'New-CalibGeometry(amiga.amigados)').Count -eq 1 -and (Get-Calls 'Start-PrecompCalib(Geom=amiga.amigados)').Count -eq 1 -and (Get-Calls 'Test-CalibImage accepte*').Count -eq 1) "$($c.N) : fenetre « aucune image calibrable », image de geometrie amiga.amigados de 80 cylindres, calibration acceptee (avant : image annoncee, puis refus de Test-CalibImage)"
}
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''
$r = Start-CrossCalib
$dl = @(Get-Calls 'Show-CrossCalibDialog*')
Chk 'C4' ($r.Started -and $dl.Count -eq 1 -and $dl[0].StartsWith("Show-CrossCalibDialog[std] Image de l'onglet Écriture : essai.img (Standard 2 us) ; avec cette famille, ses cylindres sont ceux de la calibration", [System.StringComparison]::Ordinal) -and (Get-Calls 'Start-PrecompCalib(Geom=)').Count -eq 1 -and (Get-Calls 'New-CalibGeometry*').Count -eq 0) "temoin IMG au format ibm.720 : image annoncee et reprise, sans image de geometrie (inchange)"
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $false ''; $chkWHard.Checked = $true
$r = Start-CrossCalib
$hardMsg = (T 'Calibration non prise en charge avec secteurs durs ou lecteur 8 pouces (TG43) : l''analyse de flux est calibrée pour le MFM double densité.')
Chk 'C5' (-not $r.Started -and (Get-Calls 'Show-CrossCalibDialog*').Count -eq 0 -and (Get-CallsPre "Show-AppMessage[Calibration precomp] $hardMsg").Count -eq 1 -and (Get-Calls 'Start-PrecompCalib*').Count -eq 0) "secteurs durs coches : refus avant la fenetre de choix, message de Test-CalibImage (avant : fenetre, puis refus) : $($script:Calls -join ' | ')"
$chkWHard.Checked = $false
# 12.10 RC8 : installation sans module d analyse SCP ou sans gw.exe : calibration croisee refusee avant la fenetre de choix
# (Get-CalibEnvBlock, 260, celui de Test-CalibImage) ; Test-CalibImage : refus et message inchanges
$scpMsg = (T 'Calibration : module d''analyse SCP indisponible (Add-Type).')
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''; $script:ScpStatsOk = $false
$r = Start-CrossCalib
Chk 'C8' (-not $r.Started -and $r.Why -eq $scpMsg -and (Get-Calls 'Show-CrossCalibDialog*').Count -eq 0 -and (Get-CallsPre "Show-AppMessage[Calibration precomp] $scpMsg").Count -eq 1 -and (Get-Calls 'Start-PrecompCalib*').Count -eq 0) "module d analyse SCP indisponible : refus avant la fenetre de choix ($($script:Calls -join ' | '))"
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''; $script:ScpStatsOk = $false
$t8 = Test-CalibImage
Chk 'C8b' ($null -eq $t8 -and (Get-CallsPre "Show-AppMessage[Calibration precomp] $scpMsg").Count -eq 1 -and @(Get-Calls 'Show-AppMessage*').Count -eq 1) "Test-CalibImage, module d analyse SCP indisponible : refus, message inchange ($($script:Calls -join ' | '))"
$script:ScpStatsOk = $true; $svGw = $script:GwExe; $script:GwExe = Join-Path $here 'gw-absent-rc8\gw.exe'
$gwMsg = (T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$($script:GwExe)"
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''
$r = Start-CrossCalib
Chk 'C9' (-not $r.Started -and $r.Why -eq $gwMsg -and (Get-Calls 'Show-CrossCalibDialog*').Count -eq 0 -and (Get-CallsPre "Show-AppMessage[Erreur] $gwMsg").Count -eq 1 -and (Get-Calls 'Start-PrecompCalib*').Count -eq 0) "gw.exe introuvable : refus avant la fenetre de choix ($($script:Calls -join ' | '))"
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''
$t9 = Test-CalibImage
Chk 'C9b' ($null -eq $t9 -and (Get-CallsPre "Show-AppMessage[Erreur] $gwMsg").Count -eq 1 -and @(Get-Calls 'Show-AppMessage*').Count -eq 1) "Test-CalibImage, gw.exe introuvable : refus, message inchange ($($script:Calls -join ' | '))"
$script:GwExe = $svGw
Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''
$r = Start-CrossCalib
Chk 'C9c' ($r.Started -and (Get-Calls 'Show-CrossCalibDialog*').Count -eq 1) "installation complete retablie : la fenetre de choix s ouvre ($($script:Calls -join ' | '))"
$ok6 = $false; $d6 = 'Get-CalibImageCheck absente'
if ($hasNew -contains 'Get-CalibImageCheck') {
    Set-Scn $d64 '(auto)' 0 $true $false 0 $true $false ''
    $ic = Get-CalibImageCheck; $t6 = Test-CalibImage; $msg6 = @(Get-Calls 'Show-AppMessage*')
    Set-Scn $imgf 'ibm.720' 0 $true $false 0 $true $false ''
    $ic2 = Get-CalibImageCheck; $t7 = Test-CalibImage
    $ok6 = (-not $ic.Ok -and $ic.Scope -eq 'image' -and $null -eq $t6 -and $msg6.Count -eq 1 -and $msg6[0] -eq "Show-AppMessage[Calibration precomp] $($ic.Why)" -and $ic2.Ok -and $t7 -and $t7.Family -eq $ic2.Family -and $t7.NCyl -eq $ic2.NCyl -and $t7.Img -eq $ic2.Img -and $t7.Label -eq $ic2.Label -and $t7.CylSrc -eq $ic2.CylSrc)
    $d6 = "D64 : Why « $($ic.Why) » = message de Test-CalibImage ; ibm.720 : $($ic2.Family), $($ic2.NCyl) cylindres, memes champs que Test-CalibImage"
}
Chk 'C6' $ok6 "Get-CalibImageCheck : meme decision et meme message que Test-CalibImage ($d6)"

# ================================================================ M. mesure « complete, au motif »
"--- M : mesure complete (Get-LevelBeforeWriteKind, Start-LevelBeforeWrite, regles, rapport, case, infobulles)"
$ok1 = $false; $d1 = 'Get-LevelBeforeWriteKind absente'
if ($hasNew -contains 'Get-LevelBeforeWriteKind') {
    $tab = @()
    foreach ($lm in 'content', 'quick', 'complete') { foreach ($md in 'slow', 'fast') { foreach ($rs in $false, $true) { foreach ($ms in $false, $true) {
        $script:Settings.levelBeforeWriteMode = $lm
        $exp = if ($lm -eq 'content' -and $ms -and $md -eq 'slow' -and -not $rs) { 'content' } elseif ($lm -eq 'complete' -and $md -eq 'slow') { 'complete' } else { 'quick' }
        $got = Get-LevelBeforeWriteKind $md $rs $ms
        if ($got -ne $exp) { $tab += "$lm/$md/restore=$rs/measure=$ms : $got (attendu $exp)" }
    } } } }
    $ok1 = ($tab.Count -eq 0); $d1 = $(if ($tab.Count) { $tab -join ' ; ' } else { '24 combinaisons conformes' })
}
Chk 'M1' $ok1 "Get-LevelBeforeWriteKind : content (liste sur l image, ecriture lente, case, hors restauration), complete (liste complete, ecriture lente, Test rapide et restauration compris), sinon quick : $d1"
$m2 = @()
foreach ($x in @(@{ Lm = 'complete'; Md = 'slow'; Rs = $true; Ms = $false; E = 'Start-DiskMeasure' }, @{ Lm = 'complete'; Md = 'slow'; Rs = $false; Ms = $false; E = 'Start-DiskMeasure' },
                 @{ Lm = 'complete'; Md = 'fast'; Rs = $false; Ms = $false; E = 'Start-LevelCalib' }, @{ Lm = 'content'; Md = 'slow'; Rs = $false; Ms = $true; E = 'Start-ContentMeasure' },
                 @{ Lm = 'content'; Md = 'slow'; Rs = $true; Ms = $false; E = 'Start-LevelCalib' }, @{ Lm = 'quick'; Md = 'slow'; Rs = $false; Ms = $true; E = 'Start-LevelCalib' })) {
    Set-Scn $adf 'amiga.amigados' 0 $true $true 1 $true $false ''; $script:Settings.levelBeforeWriteMode = $x.Lm
    if ($x.Rs) { Start-LevelBeforeWrite $x.Md -Restore } elseif ($x.Ms) { Start-LevelBeforeWrite $x.Md -Measure } else { Start-LevelBeforeWrite $x.Md }
    if (@($script:Calls)[0] -ne $x.E) { $m2 += "$($x.Lm)/$($x.Md)/restore=$($x.Rs)/measure=$($x.Ms) : $($script:Calls -join ',') (attendu $($x.E))" }
}
Chk 'M2' ($m2.Count -eq 0) "Start-LevelBeforeWrite reel : mesure faite inchangee (complete en ecriture lente, restauration et Test rapide compris ; calibration rapide en ecriture rapide ; mesure sur l image) $(if ($m2.Count) { ': ' + ($m2 -join ' ; ') })"
$rulesTxt = @{}
foreach ($lm in 'content', 'complete') {
    Set-Scn $adf 'amiga.amigados' 0 $true $true 1 $true $false ''; $script:Settings.levelBeforeWriteMode = $lm
    $lblRsRules.Text = ''; Update-RsRules; $rulesTxt[$lm] = [string]$lblRsRules.Text
}
$FULLFR = "(mesure complète de cette disquette, liste « Mesure » de l'onglet Écriture)"
"  regles (complete) : « $($rulesTxt['complete']) »"
Chk 'M3' ($rulesTxt['complete'] -like "*mesurée avant l'écriture quand c'est possible $FULLFR, écriture tête par tête*" -and $rulesTxt['complete'] -notlike '*(calibration rapide)*' -and $rulesTxt['content'] -like "*quand c'est possible (calibration rapide), écriture tête par tête*") "regles de la restauration (Update-RsRules) : « complete, au motif » : mesure complete de la destination ; sinon calibration rapide (inchange)"
$outR = Join-Path $here 'out-rapports'; if (-not (Test-Path -LiteralPath $outR)) { New-Item -ItemType Directory -Path $outR | Out-Null }
$repL = @{}
foreach ($lm in 'content', 'complete') {
    $script:Settings.levelBeforeWriteMode = $lm
    $id = "M4-$lm"
    $script:Restore = @{ Mode = 'sector'; Fmt = 'ibm.720'; Choice = 'ibm.720'; Plan = 'sector'; Target = ''; TgtChoice = ''; Drive = 'A'; Name = $id; Dir = $outR; Found = ''
                         Orig = ''; Back = (Join-Path $outR "$id - copie.img"); Report = (Join-Path $outR "$id - rapport.txt"); Stem = (Join-Path $outR $id); SectorRead = $null; Read = $null
                         Level = $null; Preserved = @(); Start = (Get-Date); Steps = @{} }
    Remove-Item -LiteralPath $script:Restore.Report -ErrorAction SilentlyContinue
    Write-RestoreReport $true 'RESTAURATION RÉUSSIE'
    $repL[$lm] = [string](@(Get-Content -LiteralPath $script:Restore.Report -Encoding UTF8 | Where-Object { $_ -like 'Règles *' }) -join '')
}
$script:Restore = $null; $script:Settings.levelBeforeWriteMode = 'content'
Chk 'M4' ($repL['complete'] -like "*destination mesurée avant l'écriture quand c'est possible $FULLFR ; écriture tête par tête*" -and $repL['content'] -like "*quand c'est possible (calibration rapide) ; écriture tête par tête*") "ligne « Regles » du rapport (Write-RestoreReport reel), copie secteur : mesure complete avec « complete, au motif », calibration rapide sinon"
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $false ''; $script:Settings.levelBeforeWriteMode = 'complete'; Update-SlowUi; $tq = [string]$chkWLevel.Text
$chkWSlow.Checked = $false; Update-SlowUi; $tqf = [string]$chkWLevel.Text
Chk 'M5' ($tq -eq "Mesurer la disquette avant l'écriture : toujours en « Test rapide » (mesure complète de cette disquette en écriture lente)" -and $tqf -eq "Mesurer la disquette avant l'écriture : toujours en « Test rapide » (niveau de précompensation et état de la surface)") "case de la mesure au « Test rapide » : ecriture lente avec « complete, au motif » : mesure complete ; ecriture rapide : texte d avant ($tq | $tqf)"
$s520 = [System.IO.File]::ReadAllText((Join-Path $m '520-ui-ecriture.ps1'))
$s510 = [System.IO.File]::ReadAllText((Join-Path $m '510-ui-bandeau-bibliotheque.ps1'))
$okT = $s520.Contains('`n« Test rapide » et restauration : calibration rapide au motif, ou, avec « complète, au motif », mesure complète de cette disquette avant une écriture lente (une restauration écrit toujours en écriture lente).') -and -not $s520.Contains('toujours la calibration rapide au motif') -and $s520.Contains("« Test rapide » avant une écriture lente, avec « complète, au motif » dans la liste « Mesure : » : mesure complète de cette disquette") -and $s510.Contains("Avec « complète, au motif » dans la liste « Mesure : » de l'onglet Écriture, cette mesure est une mesure complète de cette disquette")
Chk 'M6' $okT "infobulles : liste « Mesure : » (fin), liste « Calibration precomp » (ligne ajoutee), « Ecriture lente » de la Bibliotheque (ligne ajoutee) : mesure complete au « Test rapide » et en restauration"
$sd = if ($all.ContainsKey('Update-SettingDependents')) { $all['Update-SettingDependents'] } else { '' }
Chk 'M7' ($sd -match "'levelBeforeWriteMode' \{ Update-SlowUi; Update-RsRules \}") "Update-SettingDependents : regles de la restauration refaites au changement de la liste « Mesure »"

# ================================================================ T. fin de calibration avec un lecteur cible
"--- T : calibration rapide (bouton Calibrer), fin de calibration complete, fenetre de decision, carte de l Accueil"
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $true '0'
Start-LevelCalibButton
Chk 'T1' ((Get-Calls 'Start-LevelCalib').Count -eq 0 -and (Get-CallsPre 'Show-AppMessage[Calibration precomp] Calibration rapide non faite pour le lecteur cible 0 : elle relirait avec le lecteur A').Count -eq 1) "« Calibrer » au Test rapide, lecteur cible 0 avec effet : refus qui le dit, rien de lance (avant : calibration rapide faite) : $($script:Calls -join ' | ')"
$t2 = @()
foreach ($x in @(@{ N = 'sans lecteur cible'; P = 0; T = '' }, @{ N = 'profil Manuel (lecteur cible sans effet)'; P = 3; T = '0' })) {
    Set-Scn $adf 'amiga.amigados' $x.P $true $true 2 $true $true $x.T
    Start-LevelCalibButton
    if ((Get-Calls 'Start-LevelCalib').Count -ne 1) { $t2 += "$($x.N) : $($script:Calls -join ',')" }
}
Chk 'T2' ($t2.Count -eq 0) "« Calibrer » au Test rapide sans lecteur cible, ou avec un lecteur cible sans effet : calibration rapide lancee (inchange) $($t2 -join ' ; ')"
$calF = @{ Family = 'std'; Drive = 'A'; Slow = $false; Cross = $null; Home = $false; Swaps = 0; DiskAt = 'S' }
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $true '0'
$sl4 = Invoke-EndText $calF; $lg4 = @($script:Log)
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $true ''
$sl4b = Invoke-EndText $calF; $lg4b = @($script:Log)
"  journal (lecteur cible 0) : $($lg4 -join ' / ')"
Chk 'T4' (-not $sl4 -and $lg4.Count -eq 1 -and $lg4[0] -eq "Profil enregistré dans la configuration et appliqué par le mode Auto à toute image Standard 2 us écrite par le lecteur A sans lecteur cible ; lecteur cible 0 choisi pour le lecteur A : ses écritures précompensées appliquent la courbe croisée A → 0, et sont refusées sans elle (liste « Lecteur cible » de l'onglet Écriture)." -and $sl4b -and $lg4b.Count -eq 1 -and $lg4b[0] -eq 'Profil enregistré dans la configuration et appliqué par le mode Auto à toute image Standard 2 us.') "fin de calibration complete (instructions reelles de Complete-PrecompCalib) : lecteur cible 0 avec effet : libelle d Update-PrecompForImage garde, journal qui nomme la courbe croisee ; sans lecteur cible : libelle de la calibration et journal d avant"
$calS = $calF.Clone(); $calS.Slow = $true
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'
$sl4c = Invoke-EndText $calS; $lg4c = @($script:Log)
Chk 'T4b' (-not $sl4c -and $lg4c.Count -eq 1 -and $lg4c[0] -like 'Profils par tête enregistrés dans la configuration et appliqués par le mode Auto en écriture lente à toute image Standard 2 us écrite par le lecteur A sans lecteur cible ; lecteur cible 0 choisi pour le lecteur A : *') "idem en ecriture lente (profils par tete)"
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $true '0'
$h5 = Get-RevHead @{ Mode = 'std'; Drive = 'A'; Cross = $null; Family = 'std' } $false $false
Set-Scn $adf 'amiga.amigados' 0 $true $false 0 $true $true ''
$h5b = Get-RevHead @{ Mode = 'std'; Drive = 'A'; Cross = $null; Family = 'std' } $false $false
Chk 'T5' ($h5 -eq "Conserver la courbe : elle est enregistrée comme courbe propre du lecteur A, appliquée à ses écritures sans lecteur cible ; avec le lecteur cible 0 choisi, ses écritures appliquent la courbe croisée A → 0 (refusées sans elle).`nAbandonner la courbe : la calibration précédente est rétablie." -and $h5b -eq "Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie.") "fenetre de decision (affectation reelle de `$head, Show-CalibReview) : « Conserver la courbe » avec un lecteur cible choisi ; texte d avant sans lui"
$calL = @{ Family = 'std'; Drive = 'A'; Slow = $true; Home = $true; Mode = 'level' }
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $true '0'
$f6 = Invoke-LevelFields $calL; $lg6 = @($script:Log)
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $true ''
$f6b = Invoke-LevelFields $calL
$calN = $calL.Clone(); $calN.Home = $false
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $true '0'
$f6c = Invoke-LevelFields $calN
Chk 'T6' (-not $f6 -and $lg6.Count -eq 1 -and $lg6[0] -like "Calibration rapide depuis l'Accueil : lecteur cible 0 choisi pour le lecteur A, dont l'écriture n'utilise pas cette mesure*" -and $f6b -and $f6c) "calibration rapide de la carte de l Accueil, lecteur cible 0 avec effet : profil non place dans les champs, journal qui le dit ; sans lecteur cible : champs (inchange) ; hors Accueil : champs (Start-LevelCalibButton refuse avant)"

# ================================================================ K. boutons « Courbe »
"--- K : boutons « Courbe » (onglet Ecriture, cadre 2 de la restauration) avec un lecteur cible"
function Invoke-WCurveClick {
    # Clic reel : gestionnaire de 520 (Show-WCurve, ou Show-PrecompCurve avant)
    if ($s520 -match '\$btnWCurve\.Add_Click\(\{ Show-WCurve \}\)') { Show-WCurve } else { Show-PrecompCurve $script:CurveFamily $chkWSlow.Checked }
}
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $false $true '0'
Update-CurveButton $adf; $e1 = $btnWCurve.Enabled; $er1 = $btnRsCurve.Enabled
Invoke-WCurveClick; $w1 = $script:Shown.ToArray(); $script:Shown.Clear(); Show-RsCurve; $r1 = $script:Shown.ToArray()
Chk 'K1' ($e1 -and $er1) "aucune courbe propre, courbe croisee A -> 0 ecrite : boutons « Courbe » actifs (onglet Ecriture : $e1, restauration : $er1 ; avant : grises)"
Chk 'K2' ($w1.Count -eq 1 -and @($w1[0].Curves).Count -eq 1 -and $w1[0].Curves[0].Target -eq '0' -and $w1[0].Curves[0].Spec -eq '0=90:40=120:79=170') "clic sur « Courbe » de l onglet Ecriture : courbe croisee ecrite (Target 0, $(if ($w1.Count) { (@($w1[0].Curves) | ForEach-Object { $_.Spec }) -join ' | ' } else { 'rien' }))"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'
Update-CurveButton $adf; Invoke-WCurveClick; $w3 = $script:Shown.ToArray(); $script:Shown.Clear(); Show-RsCurve; $r3 = $script:Shown.ToArray()
Chk 'K3' ($r1.Count -eq 1 -and $r1[0].Curves[0].Target -eq '0' -and $w3.Count -eq 1 -and @($w3[0].Curves).Count -eq 1 -and $w3[0].Curves[0].Target -eq '0' -and $r3.Count -eq 1 -and $r3[0].Curves[0].Target -eq '0') "courbe propre par tete presente : les deux boutons montrent la courbe croisee commune A -> 0 ecrite, et non les courbes par tete du lecteur A"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true ''
Update-CurveButton $adf; Invoke-WCurveClick; $w4 = $script:Shown.ToArray(); $script:Shown.Clear(); Show-RsCurve; $r4 = $script:Shown.ToArray()
Chk 'K4' ($btnWCurve.Enabled -and $w4.Count -eq 1 -and @($w4[0].Curves).Count -eq 2 -and -not $w4[0].Curves[0].Target -and $r4.Count -eq 1 -and @($r4[0].Curves).Count -eq 2) "sans lecteur cible : courbes par tete du lecteur A (inchange)"

# ================================================================ L. case de la mesure et lecteur cible
"--- L : case « Mesurer la disquette » d apres l effet du lecteur cible (Get-TargetWriteInfo)"
$lc = @(@{ Id = 'L1'; N = 'ADF, profil Manuel'; F = $adf; Fmt = 'amiga.amigados'; P = 3; Pc = $true; W = 'profil Manuel, champ --precomp transmis tel quel' },
        @{ Id = 'L2'; N = 'ADF, --precomp decoche'; F = $adf; Fmt = 'amiga.amigados'; P = 0; Pc = $false; W = 'précompensation désactivée' },
        @{ Id = 'L3'; N = 'SCP ecrit tel quel'; F = $scp; Fmt = '(auto)'; P = 0; Pc = $true; W = 'image flux écrite telle quelle, sans précompensation' },
        @{ Id = 'L4'; N = 'HFE en FM'; F = $hfe; Fmt = '(auto)'; P = 0; Pc = $true; W = 'image en codage FM, écrite sans précompensation' })
foreach ($c in $lc) {
    Set-Scn $c.F $c.Fmt $c.P $c.Pc $true 0 $true $true '0'
    Update-SlowUi
    $tt = [string]$tip.GetToolTip($chkWLevel)
    Chk $c.Id ($chkWLevel.Enabled -and $cmbWLevelMode.Enabled -and $tt -eq "Lecteur cible 0 sans effet sur cette écriture : $($c.W).`nINFOBULLE D ORIGINE") "$($c.N), lecteur cible 0 sans effet : case et liste actives, infobulle « sans effet » puis infobulle d origine (case $($chkWLevel.Enabled) ; « $($tt.Split("`n")[0]) »)"
}
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; Update-SlowUi
Chk 'L5' (-not $chkWLevel.Enabled -and -not $cmbWLevelMode.Enabled -and $tip.GetToolTip($chkWLevel) -eq "Mesure de la disquette non disponible pour un lecteur cible : elle relirait avec le lecteur A, pas avec le lecteur cible 0. L'image est écrite avec la courbe croisée telle quelle.") "ADF, Auto, courbe croisee : case et liste inactives, infobulle d avant (inchange)"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $false '0'; Update-SlowUi
Chk 'L6' (-not $chkWLevel.Enabled -and $tip.GetToolTip($chkWLevel) -like "Mesure de la disquette non disponible pour un lecteur cible : elle relirait avec le lecteur A, pas avec le lecteur cible 0. Écriture refusée : Aucune courbe croisée A → 0 pour la famille Standard 2 us*") "ADF, Auto, sans courbe croisee : infobulle qui dit le refus (avant : « ecrite avec la courbe croisee telle quelle »)"
Set-Scn $adf 'amiga.amigados' 0 $true $true 2 $true $true '0'; Update-SlowUi
Chk 'L7' ($chkWLevel.Text -eq "Mesurer la disquette avant l'écriture : toujours en « Test rapide », sauf pour le lecteur cible 0 (elle relirait avec le lecteur A)") "Test rapide, lecteur cible avec effet : texte de la case qui dit l exception ($($chkWLevel.Text))"
$s220 = if ($allAst.ContainsKey('Update-PrecompForImage')) { $allAst['Update-PrecompForImage'].Extent.Text } else { '' }
Chk 'L8' ($s220 -match 'finally \{ \$script:WProfileBuilding = \$false; Sync-WTargetHead; Update-WLevelUi; Update-CurveButton \$path \}' -and $s520.Contains('Sync-WTargetHead -IfOwn; Update-WriteFactorNote; Update-WLevelUi; Update-CurveButton $txtWFile.Text } })')) "case de la mesure refaite en sortie d Update-PrecompForImage (image, format, profil, lecteur cible) et au changement de la case --precomp (520)"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; Update-TargetDriveUi
Chk 'L9' ($tip.GetToolTip($cmbWTarget) -like "*`nSans effet sur l'écriture (le journal le dit) avec le profil Manuel, la case --precomp décochée, une image flux écrite telle quelle ou une image FM, GCR ou à codage propre ; écriture refusée en haute densité avec le profil Auto, et en écriture rapide quand les courbes croisées sont par tête seulement.`nLe choix est mémorisé pour le lecteur A.") "infobulle de la liste « Lecteur cible » : cas sans effet et refus"

# ================================================================ R. effacement des calibrations
"--- R : « Effacer les calibrations » avec un lecteur cible garde"
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true '0'; $script:MsgAnswer = 'No'
Reset-CalibProfiles
$rm = [string](@(Get-Calls 'Show-AppMessage*')[0])
Set-Scn $adf 'amiga.amigados' 0 $true $true 0 $true $true ''
Reset-CalibProfiles
$rm2 = [string](@(Get-Calls 'Show-AppMessage*')[0])
Chk 'R1' ($rm.Contains("`n- lecteur cible gardé (A → 0) : les écritures précompensées pour ce lecteur cible (hors profil Manuel) et les restaurations en copie secteur pour lui sont refusées jusqu'à une nouvelle calibration croisée (« Calibrer pour un lecteur cible… »), ou choisissez « (même lecteur) » dans la liste « Lecteur cible ».") -and -not $rm2.Contains('lecteur cible gardé')) "message de confirmation : lecteur cible garde (A -> 0) annonce dans le bloc « Ensuite » ; rien sans lecteur cible"
Chk 'R3' ($s520.Contains("Efface toutes les calibrations de précompensation, de tous les lecteurs : courbes communes et par tête de toutes les familles (standard, long track, haute densité) et courbes croisées") -and -not $s520.Contains('Une écriture rapide ou lente recalibre ensuite automatiquement')) "infobulle du bouton : toutes les courbes de tous les lecteurs, croisees comprises ; plus de recalibration automatique annoncee pour toute ecriture"

# ================================================================ B, J, H : infobulles de la Bibliotheque, journal de la calibration croisee, carte de l Accueil
"--- B, J, H"
$nocal = "Pas de calibration automatique avec un lecteur cible choisi dans l'onglet Écriture (écriture avec la courbe croisée, ou refus sans elle), au « Test rapide » (mesure de la disquette à la place, écriture refusée sans référence), en haute densité, ni pour une image que la calibration ne mesure pas (flux, FM, GCR, densité non établie)."
Chk 'B1' (([regex]::Matches($s510, [regex]::Escape('$tip.GetToolTip($btnLibFast) + "`n" + (T "' + $nocal + '"))'))).Count -eq 1 -and ([regex]::Matches($s510, [regex]::Escape('$tip.GetToolTip($btnLibSlow) + "`n" + (T "' + $nocal + '"))'))).Count -eq 1) "infobulles « Ecriture rapide » et « Ecriture lente » de la Bibliotheque : cas sans calibration automatique"
$s270 = if ($allAst.ContainsKey('Start-PrecompCalib')) { $allAst['Start-PrecompCalib'].Extent.Text } else { '' }
$cxNew = "Pour ces écritures, le contrôle après écriture relit avec le lecteur {0} (pas avec le lecteur cible) ; la mesure de la disquette et la calibration rapide ne sont pas faites."
$cxKey = @($script:I18n.Keys | Where-Object { $_ -like 'Calibration croisée : la courbe mesure le besoin du lecteur {1}*' })
$script:Lang = 'en'; $cxEn = if ($cxKey.Count -eq 1) { T $cxKey[0] } else { '' }; $script:Lang = 'fr'
Chk 'J1' ($s270.Contains($cxNew) -and -not $s270.Contains("Vérification après écriture, mesure de la disquette sur l'image") -and $cxKey.Count -eq 1 -and $cxEn -like '*the post-write check reads back with drive {0} (not with the target drive)*' -and $cxEn -notlike '*are not available for the target drive*') "journal du depart d une calibration croisee : controle apres ecriture relu par le lecteur qui ecrit, francais et anglais ($cxEn)"
$hf = (Get-HomeCalibInfo 'app.free').Why; $hx = (Get-HomeCalibInfo 'app.flux').Why
Chk 'H1' ($hf -like "*elle applique la courbe Standard 2 us (MFM), ou aucune précompensation pour un IMD ou un D88 en FM (codage lu dans l'en-tête)*") "carte de l Accueil, « Geometrie libre » : IMD et D88 en FM ecrits sans precompensation ($hf)"
Chk 'H2' ($hx -eq "flux écrit tel quel sans format choisi (gw ne lui applique pas la précompensation) ; avec un format choisi, gw le décode et l'écrit avec la précompensation de sa famille ; pas de calibration sur un flux") "carte de l Accueil, « Flux » : flux decode par un format choisi ecrit avec la precompensation ($hx)"

# ================================================================ I. traductions des textes des fonctions modifiees
"--- I : textes T(...) des fonctions modifiees : tous traduits"
$fI = @('Get-CalibImageCheck', 'Test-CalibImage', 'Start-CrossCalib', 'Get-LevelBeforeWriteKind', 'Start-LevelBeforeWrite', 'Start-LevelCalibButton', 'Complete-LevelCalib',
        'Complete-PrecompCalib', 'Show-CalibReview', 'Update-RsRules', 'Write-RestoreReport', 'Get-RsCurveSet', 'Update-RsCalib', 'Update-SlowUi', 'Update-WLevelUi',
        'Update-TargetDriveUi', 'Get-WCurveSet', 'Update-CurveButton', 'Reset-CalibProfiles', 'Get-HomeCalibInfo', 'Start-PrecompCalib')
$miss = @(); $nT = 0
foreach ($fn in $fI) {
    if (-not $allAst.ContainsKey($fn)) { $miss += "$fn absente"; continue }
    foreach ($c in @($allAst[$fn].FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'T' }, $true))) {
        $a = @($c.CommandElements)[1]
        if ($a -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $nT++; if (-not $script:I18n.ContainsKey($a.Value)) { $miss += "$fn : $($a.Value.Substring(0, [math]::Min(70, $a.Value.Length)))" } }
    }
}
foreach ($src in @($s510, $s520, [System.IO.File]::ReadAllText((Join-Path $m '540-ui-accueil-restauration-barre.ps1')))) {
    foreach ($x in @([regex]::Matches($src, '\(T "([^"]*(?:lecteur cible|complète, au motif|tous les lecteurs|Pas de calibration automatique|courbe croisée)[^"]*)"\)'))) { $nT++; $k = $x.Groups[1].Value.Replace('`n', "`n"); if (-not $script:I18n.ContainsKey($k)) { $miss += "UI : $($k.Substring(0, [math]::Min(70, $k.Length)))" } }
}
Chk 'I1' ($miss.Count -eq 0 -and $hasNew.Count -eq $wantNew.Count) "$nT textes lus : tous traduits$(if ($miss.Count) { ' ; manquants : ' + (($miss | Select-Object -First 5) -join ' | ') })"

# ================================================================ X, W : CHANGELOG et wiki
"--- X, W"
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
Chk 'X1' ($cl.Contains('**Mesure complète annoncée comme calibration rapide.**') -and $cl.Contains('Get-CalibImageCheck') -and $cl.Contains('Get-LevelBeforeWriteKind') -and $cl.Contains('Update-WLevelUi')) "CHANGELOG : correction de la mesure complete, notes des developpeurs"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
    $old = @(Get-ChildItem -LiteralPath $Wiki -Filter '*.md' | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match '25 à 30 min' })
    Chk 'W1' ($old.Count -eq 0) "wiki : plus de « 25 a 30 min » pour la mesure complete (fichiers restants : $(@($old | ForEach-Object { $_.Name }) -join ', '))"
} else { "  W1 saute (wiki absent)" }

# ================================================================ S. mesures hors ecran
"--- S : mesures hors ecran (rendu GDI+ compatible, Segoe UI 9,75)"
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
    Set-Scn $adf 'amiga.amigados' 0 $true $true 1 $true $false ''; $script:Settings.levelBeforeWriteMode = 'complete'; $lblRsRules.Text = ''; Update-RsRules
    foreach ($d in 96, 120, 144) { $x = Get-Lines ([string]$lblRsRules.Text) $d; $sOut += ("{0} {1} ppp : {2} lignes, bas {3:N1}" -f $lg, $d, $x.Lines, $x.Bottom); if ($x.Bottom -ge 516 -or $x.Lines -gt 8) { $sOk = $false } }
}
$script:Lang = 'fr'
Chk 'S1' $sOk "regles de la restauration, mesure complete (372 px) : bas sous 516 px, 8 lignes au plus ($($sOut -join ' ; '))"
$wOut = @(); $wOk = $true
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    foreach ($x in @(@{ Q = 2; Tg = '0'; Cr = $true; Lm = 'content' }, @{ Q = 2; Tg = ''; Cr = $false; Lm = 'complete' })) {
        Set-Scn $adf 'amiga.amigados' 0 $true $true $x.Q $true $x.Cr $x.Tg; $script:Settings.levelBeforeWriteMode = $x.Lm; Update-SlowUi
        $wd = [System.Windows.Forms.TextRenderer]::MeasureText([string]$chkWLevel.Text, $form.Font).Width + 17
        $wOut += "$lg $wd px"; if ($wd -gt 776) { $wOk = $false }
    }
}
$script:Lang = 'fr'
Chk 'S2' $wOk "case de la mesure (x = 12 dans l onglet de 800 px : 776 px au plus, case comprise) : $($wOut -join ' ; ')"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-fixB-f : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
