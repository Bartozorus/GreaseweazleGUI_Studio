# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_tests.py) : copie de logic-1210-rc6-d.ps1 ; passages du wiki d apres le commit 54f3e91 ; Get-CalibEnvBlock extraite.
# 12.10 RC7 (10/11/2026, v1210\rc7\make_rc7_tests2.py) : copie de logic-1210-rc6-c ; passage du CHANGELOG avec le libelle de la case en ecriture lente (RC7).
param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-rc6-e) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Cas W1 saute sans -Wiki.
# Copie adaptee par la correction fix2 de la RC6 (10/11/2026, v1210\rc6\fix2\make_fix2_tests.py, source v1210\rc6\fix1\logic-1210-rc6-b.ps1) : W1 : libelle de la case avec son deux-points dans le wiki ; C1 : phrase des cas d inactivite du bouton « Courbe » reformulee dans le CHANGELOG (m1), l ancienne ajoutee aux passages retires.
# Copie adaptee par la correction fix1 de la RC6 (10/11/2026, v1210\rc6\fix1\make_fix1_copies.py, source v1210\rc6\logic-1210-rc6.ps1) : S3, M1 : famille attendue du bouton « Courbe » = famille de la decision d ecriture (profil force : famille du profil) ; W1, C1 : passages du wiki et du CHANGELOG de fix1, ceux de la RC6 retires.
# RC6 12.10 (2c1eb08, 10/11/2026) : cas propres a la RC6, d apres la relecture r12 de e52278e (v1210\rc5\revue\r12-e52278e,
# r12-logique.ps1, dont le cadre est repris : fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un
# fichier de travail puis chargees par dot-source ; controles WinForms reels jamais affiches ; bouchons pour l interface et
# gw ; fichiers d essai factices dans img-rc6\, contenu nul ou en-tete minimal, aucune donnee reelle).
#  W  bouton « Courbe » de l onglet Ecriture (Update-CurveButton reel) actif si et seulement si l ecriture transmet --precomp
#     et qu il existe des courbes a montrer (Get-WCurveSet reel). « Transmet --precomp » : instructions reelles de
#     Start-ImageWrite (140) enveloppees dans Invoke-WritePrecomp (refus du lecteur cible Test-TargetWriteAllowed, codage
#     Get-ImageEncoding, champs $pc0/$pc1, flux ecrit tel quel, image FM/GCR/codage propre hors profil Manuel). Cas nommes
#     (F1 a F5 de r12, HFE, IPF, secteur MFM, flux, haute densite, profils Auto, force, Manuel) avec une attente ecrite ici en
#     plus, puis matrice de toutes les combinaisons (M1) ;
#  L  courbe croisee long track seule (aucune standard) : cadre « Calibration du lecteur » et regles de la restauration
#     « aucune courbe croisee standard A -> 0 » (francais, anglais), phrase entiere dans 262 x 54 px, ligne « Regles » du
#     rapport ;
#  I, W, C  cles i18n de la RC6 (presentes, traduites, anciennes retirees), passages du wiki et du CHANGELOG.
# Sur e52278e, F1 a F3 et L1 sont NON (constats de r12). Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
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
# Instructions reelles de Start-ImageWrite (140) qui decident de --precomp, dans leur ordre : refus du lecteur cible (rien
# n est ecrit), codage de l image, champs, flux ecrit tel quel, image FM, GCR ou a codage propre (profil Manuel excepte).
# 12.11 (lot L10) : champs, flux et codage sont decides par Get-WriteSpecPlan (140), chargee plus haut ; Start-ImageWrite
# l appelle, ecrit les lignes de journal, puis prend les profils : ces instructions sont enveloppees a la place des quatre
# d origine, que garde une source d avant le lot
$sIwSp = Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$sp = Get-WriteSpecPlan'
if ($sIwSp) {
    $sIw = @(
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if (-not (Test-TargetWriteAllowed'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$ie = Get-ImageEncoding'),
        $sIwSp,
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if ($sp.Flux)'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$nt = @($sp.Nt)'),
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if ($nt.Count -gt 0)'),
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if ($sp.NonMfm)'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$pc0 = $sp.P0'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$pc1 = $sp.P1'))
} else {
    $sIw = @(
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if (-not (Test-TargetWriteAllowed'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$ie = Get-ImageEncoding'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$pc0 = if ($chkWPrecomp.Checked'),
        (Get-Stmt 'Start-ImageWrite' 'AssignmentStatementAst' '$pc1 = if ($chkWPrecomp.Checked'),
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if (($pc0 -or $pc1) -and (Test-RawFluxWrite'),
        (Get-Stmt 'Start-ImageWrite' 'IfStatementAst' 'if (($pc0 -or $pc1) -and $ie.NonMfm)'))
}
if (@($sIw | Where-Object { -not $_ }).Count) { throw "instructions de Start-ImageWrite introuvables ($(@($sIw | Where-Object { $_ }).Count) sur $($sIw.Count))" }
$code += "`r`n`r`nfunction Invoke-WritePrecomp {`r`n    `$slow = [bool]`$chkWSlow.Checked`r`n    " + ($sIw -join "`r`n    ") + "`r`n    return @{ Sent = [bool](`$pc0 -or `$pc1); P0 = `$pc0; P1 = `$pc1 }`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-rc6-e.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
$hasNew = @($wantNew | Where-Object { $all.ContainsKey($_) })
"source : $Wt ; nouvelles fonctions presentes : $($hasNew.Count) sur $($wantNew.Count) ; instructions de Start-ImageWrite enveloppees : $($sIw.Count)"

# --- Etat, controles et bouchons (repris de r12) --------------------------------------------------------------------
$script:Settings = @{ levelBeforeWrite = $true; levelBeforeWriteMode = 'content'; restoreFormat = 'auto'; calMode = 'std'; warmFullCalib = $true }
$script:CalWarmupMinutes = 5.0; $script:ScpStatsOk = $false; $script:DriveCurves = @{}; $script:PrecompCurves = @{}; $script:TargetDrives = @{}
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
$txtWPrecomp = New-Object System.Windows.Forms.TextBox; $txtWPrecomp1 = New-Object System.Windows.Forms.TextBox; $lblWPrecomp1 = New-Object System.Windows.Forms.Label
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
$lblWProfileInfo = New-Object System.Windows.Forms.Label
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
function Start-PrecompCalib { param([switch]$ForceFine, $Geom = $null, [string]$Test = '') $script:Calls.Add('Start-PrecompCalib') }
function Show-CrossCalibDialog($src, $targets, $family, $fine, $imgInfo, $slow, $min, $max) { return @{ Ok = $false } }
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
function New-CalibGeometry($i, $n) { return '' }
$script:LevelShifts = @{}; $script:ContentMeasures = @(); $script:LevelBrands = @(); $script:OldCalib = $null; $script:CurveForm = $null
$pbWCal = New-Object System.Windows.Forms.ProgressBar; $lblWCal = New-Object System.Windows.Forms.Label
$script:ConfigFile = 'GreaseweazleGUI.json'; $script:MsgAnswer = 'No'
if (-not (Get-Command Sync-WTargetHead -CommandType Function -ErrorAction SilentlyContinue)) { function Sync-WTargetHead([switch]$IfOwn) { } }
if (-not (Get-Command Update-WriteFactorNote -CommandType Function -ErrorAction SilentlyContinue)) { function Update-WriteFactorNote { } }
function Cut([string]$t, [int]$n) { return $t.Substring(0, [math]::Min($n, $t.Length)) }
function Get-Spec($cs) { return (@($cs | Where-Object { $_ } | ForEach-Object { "$($_.Drive)>$($_.Target)[$($_.Spec)]" }) -join ' ; ') }

# --- Fichiers d essai (contenu nul ou en-tete minimal, aucune donnee reelle) ------------------------------------------
$img = Join-Path $here 'img-rc6'; if (-not (Test-Path -LiteralPath $img)) { New-Item -ItemType Directory -Path $img | Out-Null }
$adf = Join-Path $img 'essai.adf'; [System.IO.File]::WriteAllBytes($adf, (New-Object byte[] 901120))
$adfHd = Join-Path $img 'essai-hd.adf'; [System.IO.File]::WriteAllBytes($adfHd, (New-Object byte[] 1802240))
$imgf = Join-Path $img 'essai.img'; [System.IO.File]::WriteAllBytes($imgf, (New-Object byte[] 737280))
$scp = Join-Path $img 'essai.scp'; $b = New-Object byte[] 4096; [System.Text.Encoding]::ASCII.GetBytes('SCP').CopyTo($b, 0); [System.IO.File]::WriteAllBytes($scp, $b)
$d64 = Join-Path $img 'essai.d64'; [System.IO.File]::WriteAllBytes($d64, (New-Object byte[] 174848))
function New-Hfe([string]$name, [int]$enc) {
    $h = New-Object byte[] 1024; [System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($h, 0); $h[9] = 80; $h[10] = 2; $h[11] = [byte]$enc
    [BitConverter]::GetBytes([uint16]250).CopyTo($h, 12); $p = Join-Path $img $name; [System.IO.File]::WriteAllBytes($p, $h); return $p
}
$hfeFm = New-Hfe 'essai-fm.hfe' 2; $hfeMfm = New-Hfe 'essai-mfm.hfe' 0
function Add-BE32([System.Collections.Generic.List[byte]]$l, [uint32]$v) { $x = [BitConverter]::GetBytes($v); [Array]::Reverse($x); $l.AddRange([byte[]]$x) }
function New-Ipf([string]$name, [uint32]$trkBits) {
    # En-tete CAPS puis 160 blocs IMGE de 80 octets (bits par piste a +48, blocs a +52 : Get-IpfCellInfo) ; aucune DATA
    $l = New-Object System.Collections.Generic.List[byte]
    $l.AddRange([byte[]][System.Text.Encoding]::ASCII.GetBytes('CAPS')); Add-BE32 $l 12; Add-BE32 $l 0
    for ($i = 0; $i -lt 160; $i++) {
        $l.AddRange([byte[]][System.Text.Encoding]::ASCII.GetBytes('IMGE')); Add-BE32 $l 80; Add-BE32 $l 0
        $d = New-Object byte[] 68
        $x = [BitConverter]::GetBytes($trkBits); [Array]::Reverse($x); [Array]::Copy($x, 0, $d, 36, 4)
        $x = [BitConverter]::GetBytes([uint32]11); [Array]::Reverse($x); [Array]::Copy($x, 0, $d, 40, 4)
        $l.AddRange([byte[]]$d)
    }
    $p = Join-Path $img $name; [System.IO.File]::WriteAllBytes($p, $l.ToArray()); return $p
}
$ipfStd = New-Ipf 'essai-std.ipf' 100000; $ipfLong = New-Ipf 'essai-long.ipf' 105820
"  fichiers d essai : cellule IPF standard $((Get-IpfCellInfo $ipfStd).CellNs) ns, IPF long track $([math]::Round((Get-IpfCellInfo $ipfLong).CellNs, 1)) ns ; codage HFE FM « $((Get-ImageEncoding $hfeFm '(auto)').Enc) », HFE MFM « $((Get-ImageEncoding $hfeMfm '(auto)').Enc) », D64 « $((Get-ImageEncoding $d64 '(auto)').Enc) »"

function New-Cv([string]$drv, [string]$tgt, [string]$fam, [string]$spec) { return @{ Family = $fam; Drive = $drv; Target = $tgt; Date = '01/11/2026 17:49'; Spec = $spec; Method = 'motif'; Values = [int[]]@(1..80); Test = 'fine'; Converged = $true } }
function Set-W([string]$file, [string]$fmt, [int]$prof, [string]$tgt, [string]$cross, [string]$own = 'all', [bool]$slow = $true) {
    # Etat de l onglet Ecriture : courbes propres du lecteur A (all : standard commune et par tete, long track, haute densite ;
    # none : aucune), courbe croisee A -> 0 (std, long ou aucune), lecteur cible, image, format, profil, case --precomp cochee
    # et champs remplis (champ de l utilisateur en profil Manuel)
    $script:DriveCurves = @{}; $script:PrecompCurves = @{}
    if ($own -eq 'all') {
        Set-DriveCurve 'A' 'std' (New-Cv 'A' '' 'Standard 2 us' '0=60:40=90:79=130'); Set-DriveCurve 'A' 'std_h0' (New-Cv 'A' '' 'Standard 2 us' '0=61:79=131'); Set-DriveCurve 'A' 'std_h1' (New-Cv 'A' '' 'Standard 2 us' '0=62:79=132')
        Set-DriveCurve 'A' 'long' (New-Cv 'A' '' 'Long track 1,89 us' '0=70:79=150'); Set-DriveCurve 'A' 'hd' (New-Cv 'A' '' 'Haute densité 1 us' '0=40:79=60')
    }
    if ($cross -eq 'std') { Set-DriveCurve 'A>0' 'std' (New-Cv 'A' '0' 'Standard 2 us' '0=90:40=120:79=170') }
    if ($cross -eq 'long') { Set-DriveCurve 'A>0' 'long' (New-Cv 'A' '0' 'Long track 1,89 us' '0=95:79=180') }
    Sync-PrecompCurves
    $script:TargetDrives = @{}; if ($tgt) { $script:TargetDrives['A'] = $tgt }
    $txtWFile.Text = $file; $cmbWFmt.Text = $fmt; $cmbWProfile.SelectedIndex = $prof; $chkWPrecomp.Checked = $true; $chkWSlow.Checked = $slow
    $txtWPrecomp.Text = '0=60:79=130'; $txtWPrecomp1.Text = '0=61:79=131'; $chkWHard.Checked = $false
    $script:Calls.Clear(); $script:Log.Clear(); $script:Shown.Clear(); $script:Cal = $null
    $script:Settings.restoreFormat = 'auto'
}
function Get-WState([string]$file, [string]$fmt) {
    # Bouton reel (Update-CurveButton), decision reelle de Start-ImageWrite (Invoke-WritePrecomp), courbes a montrer
    # (Get-WCurveSet pour la famille de l ecriture, Get-WriteImageFamily) et courbes du clic (Show-WCurve reel)
    Update-CurveButton $file
    $en = [bool]$btnWCurve.Enabled
    $script:Log.Clear(); $script:Calls.Clear()
    $r = Invoke-WritePrecomp; $sent = [bool]($null -ne $r -and $r.Sent); $refused = ($null -eq $r)
    $log = @($script:Log)
    $fam = 'std'; try { $fam = Get-WriteImageFamily $file $fmt } catch { $fam = 'std' }
    # Copie fix1 de la RC6 : famille de la decision d ecriture, attente ecrite ici : profil force « Standard 2 us » ou
    # « Long track 1,89 us » : famille du profil (Set-PrecompFields), sinon famille de l image
    if ($cmbWProfile.SelectedIndex -eq 1) { $fam = 'std' } elseif ($cmbWProfile.SelectedIndex -eq 2) { $fam = 'long' }
    $cs = Get-WCurveSet $file $fam
    $script:Shown.Clear(); if ($en) { Show-WCurve }
    $shown = if ($script:Shown.Count) { Get-Spec $script:Shown[0].Curves } else { '' }
    $exp = ($sent -and @($cs).Count -gt 0)
    return [pscustomobject]@{ En = $en; Sent = $sent; Refused = $refused; Fam = $fam; Cs = (Get-Spec $cs); NCs = @($cs).Count; Exp = $exp
        Shown = $shown; Ok = (($en -eq $exp) -and (-not $en -or $shown -eq (Get-Spec $cs))); Log = $log; NonMfm = (Test-NonMfmWrite $file $fmt); Raw = (Test-RawFluxWrite $file $fmt) }
}

# ================================================================ W. bouton « Courbe » de l onglet Ecriture : cas nommes
"--- W : bouton « Courbe » de l onglet Ecriture : actif <=> --precomp transmis par Start-ImageWrite et courbes a montrer (Get-WCurveSet)"
$cases = @(
    @{ Id = 'F1'; L = 'SCP + commodore.1541 (GCR), Auto, sans lecteur cible'; F = $scp; Fmt = 'commodore.1541'; P = 0; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F2'; L = 'SCP + mac.800 (GCR), Auto, sans lecteur cible'; F = $scp; Fmt = 'mac.800'; P = 0; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F3'; L = 'SCP + commodore.1541 (GCR), Auto, lecteur cible 0 avec courbe croisee'; F = $scp; Fmt = 'commodore.1541'; P = 0; Tgt = '0'; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F3b'; L = 'SCP + mac.800 (GCR), Auto, lecteur cible 0 avec courbe croisee'; F = $scp; Fmt = 'mac.800'; P = 0; Tgt = '0'; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F4'; L = 'temoin : SCP + amiga.amigados (MFM), Auto, sans lecteur cible'; F = $scp; Fmt = 'amiga.amigados'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'F5'; L = 'D64 (format implicite commodore.1541, GCR), Auto'; F = $d64; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F5b'; L = 'D64, profil force Standard 2 us'; F = $d64; Fmt = '(auto)'; P = 1; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'F6'; L = 'D64, profil Manuel : champ transmis tel quel, bouton actif comme avant'; F = $d64; Fmt = '(auto)'; P = 3; Tgt = ''; X = 'std'; Sent = $true; En = $true; Manual = $true },
    @{ Id = 'F7'; L = 'SCP + commodore.1541, profil Manuel, lecteur cible 0 (sans effet en Manuel)'; F = $scp; Fmt = 'commodore.1541'; P = 3; Tgt = '0'; X = 'std'; Sent = $true; En = $true; Manual = $true },
    @{ Id = 'H1'; L = 'HFE en FM (octet 11 = 2), Auto'; F = $hfeFm; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'H2'; L = 'HFE en FM, profil force Long track'; F = $hfeFm; Fmt = '(auto)'; P = 2; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'H3'; L = 'HFE en FM, profil Manuel'; F = $hfeFm; Fmt = '(auto)'; P = 3; Tgt = ''; X = 'std'; Sent = $true; En = $true; Manual = $true },
    @{ Id = 'H4'; L = 'temoin : HFE en MFM (octet 11 = 0), Auto'; F = $hfeMfm; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'P1'; L = 'IPF standard (cellule 2 000 ns), Auto'; F = $ipfStd; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true; Fam = 'std' },
    @{ Id = 'P2'; L = 'IPF long track (cellule 1 890 ns), Auto, courbe long track du lecteur'; F = $ipfLong; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true; Fam = 'long' },
    @{ Id = 'P3'; L = 'IPF long track, Auto, lecteur sans aucune courbe'; F = $ipfLong; Fmt = '(auto)'; P = 0; Tgt = ''; X = ''; Own = 'none'; Sent = $true; En = $false },
    @{ Id = 'S1'; L = 'ADF amiga.amigados (secteur MFM), Auto'; F = $adf; Fmt = 'amiga.amigados'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'S2'; L = 'ADF amiga.amigados, profil force Standard 2 us'; F = $adf; Fmt = 'amiga.amigados'; P = 1; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'S3'; L = 'ADF amiga.amigados, profil force Long track'; F = $adf; Fmt = 'amiga.amigados'; P = 2; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'S4'; L = 'ADF amiga.amigados, profil Manuel'; F = $adf; Fmt = 'amiga.amigados'; P = 3; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'S5'; L = 'IMG ibm.720 (secteur MFM), Auto'; F = $imgf; Fmt = 'ibm.720'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true },
    @{ Id = 'S6'; L = 'ADF amiga.amigados, Auto, lecteur sans aucune courbe'; F = $adf; Fmt = 'amiga.amigados'; P = 0; Tgt = ''; X = ''; Own = 'none'; Sent = $true; En = $false },
    @{ Id = 'S7'; L = 'ADF amiga.amigados, Auto, lecteur cible 0 avec courbe croisee (courbe croisee montree)'; F = $adf; Fmt = 'amiga.amigados'; P = 0; Tgt = '0'; X = 'std'; Sent = $true; En = $true; Cs = 'A>0[0=90:40=120:79=170]' },
    @{ Id = 'S8'; L = 'ADF amiga.amigados, Auto, lecteur cible 0 sans courbe croisee (ecriture refusee)'; F = $adf; Fmt = 'amiga.amigados'; P = 0; Tgt = '0'; X = ''; Sent = $false; En = $false },
    @{ Id = 'X1'; L = 'flux SCP ecrit tel quel (sans format), Auto'; F = $scp; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'X2'; L = 'flux SCP ecrit tel quel, profil Manuel'; F = $scp; Fmt = '(auto)'; P = 3; Tgt = ''; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'X3'; L = 'flux SCP + amiga.amigados, Auto, lecteur cible 0 avec courbe croisee'; F = $scp; Fmt = 'amiga.amigados'; P = 0; Tgt = '0'; X = 'std'; Sent = $true; En = $true; Cs = 'A>0[0=90:40=120:79=170]' },
    @{ Id = 'D1'; L = 'ADF haute densite, Auto, courbe haute densite du lecteur'; F = $adfHd; Fmt = '(auto)'; P = 0; Tgt = ''; X = 'std'; Sent = $true; En = $true; Fam = 'hd' },
    @{ Id = 'D2'; L = 'ADF haute densite, Auto, lecteur sans aucune courbe'; F = $adfHd; Fmt = '(auto)'; P = 0; Tgt = ''; X = ''; Own = 'none'; Sent = $true; En = $false },
    @{ Id = 'D3'; L = 'ADF haute densite, Auto, lecteur cible 0 (refus en haute densite)'; F = $adfHd; Fmt = '(auto)'; P = 0; Tgt = '0'; X = 'std'; Sent = $false; En = $false },
    @{ Id = 'D4'; L = 'ADF haute densite, profil force Standard 2 us, lecteur cible 0 avec courbe croisee'; F = $adfHd; Fmt = '(auto)'; P = 1; Tgt = '0'; X = 'std'; Sent = $true; En = $true; Cs = 'A>0[0=90:40=120:79=170]' })
foreach ($c in $cases) {
    $own = if ($c.Own) { $c.Own } else { 'all' }
    Set-W $c.F $c.Fmt $c.P $c.Tgt $c.X $own $true
    $s = Get-WState $c.F $c.Fmt
    $okW = ($s.Sent -eq $c.Sent -and $s.En -eq $c.En -and (-not $c.Fam -or $s.Fam -eq $c.Fam) -and (-not $c.Cs -or $s.Shown -eq $c.Cs))
    $okM = (-not $c.Manual -or @($s.Log | Where-Object { $_ -like '*est transmis tel quel*' }).Count -eq 1)
    "  $($c.Id) : $($c.L) : NonMfm $($s.NonMfm), flux tel quel $($s.Raw) ; Start-ImageWrite : $(if ($s.Refused) { 'ecriture refusee' } elseif ($s.Sent) { '--precomp transmis' } else { '--precomp non transmis' }) ; famille $($s.Fam), courbes a montrer « $($s.Cs) » ; bouton actif $($s.En)$(if ($s.En) { ", clic « $($s.Shown) »" })$(if ($c.Manual) { ' ; journal : ' + (Cut (@($s.Log | Where-Object { $_ -like '*tel quel*' }) -join ' | ') 150) })"
    Chk $c.Id ($s.Ok -and $okW -and $okM) "$($c.L) : bouton $(if ($c.En) { 'actif' } else { 'grise' }) attendu, --precomp $(if ($c.Sent) { 'transmis' } else { 'non transmis' }) attendu"
}

# ================================================================ M. matrice : toutes les combinaisons
"--- M : matrice (13 images x 4 profils x lecteur cible x courbes propres x ecriture lente)"
$imgs = @(
    @{ N = 'ADF amiga.amigados'; F = $adf; Fmt = 'amiga.amigados'; Nm = $false; Raw = $false }, @{ N = 'ADF (auto)'; F = $adf; Fmt = '(auto)'; Nm = $false; Raw = $false },
    @{ N = 'IMG ibm.720'; F = $imgf; Fmt = 'ibm.720'; Nm = $false; Raw = $false }, @{ N = 'ADF HD'; F = $adfHd; Fmt = '(auto)'; Nm = $false; Raw = $false },
    @{ N = 'SCP tel quel'; F = $scp; Fmt = '(auto)'; Nm = $false; Raw = $true }, @{ N = 'SCP + amiga.amigados'; F = $scp; Fmt = 'amiga.amigados'; Nm = $false; Raw = $false },
    @{ N = 'SCP + commodore.1541'; F = $scp; Fmt = 'commodore.1541'; Nm = $true; Raw = $false }, @{ N = 'SCP + mac.800'; F = $scp; Fmt = 'mac.800'; Nm = $true; Raw = $false },
    @{ N = 'D64'; F = $d64; Fmt = '(auto)'; Nm = $true; Raw = $false }, @{ N = 'HFE FM'; F = $hfeFm; Fmt = '(auto)'; Nm = $true; Raw = $false },
    @{ N = 'HFE MFM'; F = $hfeMfm; Fmt = '(auto)'; Nm = $false; Raw = $false }, @{ N = 'IPF standard'; F = $ipfStd; Fmt = '(auto)'; Nm = $false; Raw = $false },
    @{ N = 'IPF long track'; F = $ipfLong; Fmt = '(auto)'; Nm = $false; Raw = $false })
$mRows = @(); $mBad = @()
foreach ($im in $imgs) { foreach ($p in 0, 1, 2, 3) { foreach ($tc in @(@('', ''), @('0', 'std'), @('0', ''))) { foreach ($own in 'all', 'none') { foreach ($slow in $true, $false) {
    Set-W $im.F $im.Fmt $p $tc[0] $tc[1] $own $slow
    $s = Get-WState $im.F $im.Fmt
    # attente ecrite ici, independante du code : flux tel quel ou image FM/GCR hors profil Manuel : bouton grise
    $rule = -not ($im.Raw -or ($im.Nm -and $p -ne 3))
    $ok = $s.Ok -and ($rule -or -not $s.En) -and ($rule -or -not $s.Sent)
    $row = [pscustomobject]@{ Id = "$($im.N) | profil $p | cible $(if ($tc[0]) { "0/$(if ($tc[1]) { $tc[1] } else { 'aucune' })" } else { '-' }) | propres $own | lente $slow"; S = $s; Ok = $ok }
    $mRows += $row; if (-not $ok) { $mBad += $row }
} } } } }
foreach ($x in @($mBad | Select-Object -First 12)) { "  M ECART [$($x.Id)] : bouton actif $($x.S.En) ; --precomp transmis $($x.S.Sent) (refus $($x.S.Refused)) ; courbes « $($x.S.Cs) » ; clic « $($x.S.Shown) »" }
if ($mBad.Count -gt 12) { "  M ... $($mBad.Count - 12) autre(s) ecart(s)" }
$nEn = @($mRows | Where-Object { $_.S.En }).Count; $nSent = @($mRows | Where-Object { $_.S.Sent }).Count; $nRef = @($mRows | Where-Object { $_.S.Refused }).Count
"  combinaisons : $($mRows.Count) ; bouton actif $nEn ; --precomp transmis $nSent ; ecriture refusee (lecteur cible) $nRef ; ecarts $($mBad.Count)"
$mImg = @($mRows | Where-Object { -not $_.Ok } | ForEach-Object { ($_.Id -split ' \| ')[0] } | Sort-Object -Unique)
Chk 'M1' ($mRows.Count -eq 624 -and $mBad.Count -eq 0 -and $nEn -gt 0 -and $nEn -lt $mRows.Count) "$($mRows.Count) combinaisons : bouton actif si et seulement si Start-ImageWrite transmet --precomp et que Get-WCurveSet rend des courbes, clic = ces courbes ; flux tel quel et FM/GCR hors Manuel grises$(if ($mImg.Count) { ' ; images en ecart : ' + ($mImg -join ', ') })"
# Contexte (hors attente) : case --precomp decochee
Set-W $adf 'amiga.amigados' 0 '' '' 'all' $true; $chkWPrecomp.Checked = $false; $s0 = Get-WState $adf 'amiga.amigados'; $chkWPrecomp.Checked = $true
"  contexte (hors attente, comportement d avant la RC6) : ADF, case --precomp decochee : --precomp transmis $($s0.Sent), bouton actif $($s0.En) (courbes du lecteur « $(Cut $s0.Cs 60) »)"

# ================================================================ L. courbe croisee long track seule
"--- L : lecteur cible 0, courbe croisee A -> 0 long track seule (aucune standard) : cadre, regles, refus de Start-Restore, rapport (reels)"
$outR = Join-Path $here 'out-rapports-rc6'; if (-not (Test-Path -LiteralPath $outR)) { New-Item -ItemType Directory -Path $outR | Out-Null }
function Get-RepRules([string]$id, [string]$fmt, [string]$choice, [string]$pre) {
    $script:Restore = @{ Mode = 'sector'; Fmt = $fmt; Choice = $choice; Plan = ''; Target = ''; TgtChoice = '0'; Drive = 'A'; Name = $id; Dir = $outR; Found = $fmt
                         Orig = ''; Back = (Join-Path $outR "$id - copie.img"); Report = (Join-Path $outR "$id - rapport.txt"); Stem = (Join-Path $outR $id); SectorRead = $null; Read = $null
                         Level = $null; Preserved = @(); Start = (Get-Date); Steps = @{} }
    Remove-Item -LiteralPath $script:Restore.Report -ErrorAction SilentlyContinue
    Write-RestoreReport $false 'X'
    $rl = [string](@(Get-Content -LiteralPath $script:Restore.Report -Encoding UTF8 | Where-Object { $_.StartsWith($pre, [System.StringComparison]::Ordinal) }) -join '')
    $script:Restore = $null
    return $rl
}
$expL = @{
    fr = @{ Cadre = 'Lecteur cible 0 : aucune courbe croisée standard A → 0, la restauration sera refusée au lancement.'
            Rules = "Règles appliquées à la copie : aucune avec le lecteur cible 0 : sans courbe croisée standard A → 0, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture."
            Rep = 'Règles      : lecture 5 tours, 10 essais x 3 séries ; écriture pour le lecteur cible 0 non atteinte (elle serait refusée sans courbe croisée standard A → 0).'; Pre = 'Règles ' }
    en = @{ Cadre = 'Target drive 0: no standard cross curve A → 0, the restore will be refused at start.'
            Rules = 'Rules applied to the copy: none with target drive 0: without a standard cross curve A → 0, the restore will be refused at start. Run "Calibrate for a target drive…", or choose "(same drive)" in the "Target drive" list of the Write tab.'
            Rep = 'Rules       : read 5 revolutions, 10 retries x 3 series; write for target drive 0 not reached (it would be refused without a standard cross curve A → 0).'; Pre = 'Rules ' } }
$lOut = @{}
foreach ($lg in 'fr', 'en') {
    $script:Lang = $lg
    Set-W $adf 'amiga.amigados' 0 '0' 'long' 'all' $true
    $script:Settings.restoreFormat = 'auto'; $lblRsCal.Text = ''; $lblRsRules.Text = ''; Update-RsCalib
    $pl = Get-RestorePlan 'A' '0' (Get-RestoreFormat)
    $lOut[$lg] = @{ Cadre = [string]$lblRsCal.Text; Rules = [string]$lblRsRules.Text; Block = [string](Get-RestoreTargetInfo 'A' '0' 'auto').Block; Kind = [string]$pl.Kind; BK = [string]$pl.Ti.BlockKind
                    Long = @(Get-TargetCurves 'long' $true 'A' '0').Count; Std = @(Get-TargetCurves 'std' $true 'A' '0').Count; Rep = (Get-RepRules "L-$lg" 'amiga.amigados' 'amiga.amigados' $expL[$lg].Pre) }
    "  L $lg : courbes croisees A>0 long track $($lOut[$lg].Long), standard $($lOut[$lg].Std) ; decision $($lOut[$lg].Kind)/$($lOut[$lg].BK) ; cadre « $(Cut $lOut[$lg].Cadre 120)… »"
    "         regles « $(Cut $lOut[$lg].Rules 160)… »"
    "         Start-Restore « $(Cut $lOut[$lg].Block 200)… »"
    "         rapport « $($lOut[$lg].Rep) »"
}
$script:Lang = 'fr'
$okL = $true
foreach ($lg in 'fr', 'en') {
    $o = $lOut[$lg]; $e = $expL[$lg]
    if (-not ($o.Long -ge 1 -and $o.Std -eq 0 -and $o.Kind -eq 'refused' -and $o.BK -eq 'none' -and $o.Cadre.StartsWith($e.Cadre + ' ', [System.StringComparison]::Ordinal) -and $o.Rules -ceq $e.Rules -and $o.Block)) { $okL = $false }
}
Chk 'L1' $okL "courbe croisee long track A -> 0 seule : cadre « $($expL.fr.Cadre) » en tete et regles « ... sans courbe croisee standard A -> 0, ... » (francais et anglais), comme le refus de Start-Restore (« pour la famille Standard 2 us »)"
$okR = ($lOut.fr.Rep -ceq $expL.fr.Rep -and $lOut.en.Rep -ceq $expL.en.Rep)
Chk 'L3' $okR "rapport d une restauration arretee avant l ecriture (decision refaite) : « non atteinte (elle serait refusee sans courbe croisee standard A -> 0) », francais et anglais"
# L2 : phrase du cadre entiere dans lblRsCal (540 : 262 x 54 px, AutoEllipsis), rendu compatible (GDI+), LineLimit
$fPx = New-Object System.Drawing.Font('Segoe UI', [single]13.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
function Get-Fit([string]$text, [int]$dpi, [bool]$ell, [bool]$px) {
    $sc = $dpi / 96.0
    $font = if ($px) { $fPx } else { New-Object System.Drawing.Font('Segoe UI', 9.75) }
    $bmp = New-Object System.Drawing.Bitmap(4, 4); $bmp.SetResolution($dpi, $dpi); $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sf = New-Object System.Drawing.StringFormat; $sf.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $sf.Trimming = $(if ($ell) { [System.Drawing.StringTrimming]::EllipsisCharacter } else { [System.Drawing.StringTrimming]::None })
    $cf = 0; $lf = 0
    $sz = if ($px) { New-Object System.Drawing.SizeF(262, 54) } else { New-Object System.Drawing.SizeF(([float](262 * $sc)), ([float](54 * $sc))) }
    [void]$g.MeasureString($text, $font, $sz, $sf, [ref]$cf, [ref]$lf)
    $sf.Dispose(); $g.Dispose(); $bmp.Dispose(); if (-not $px) { $font.Dispose() }
    return @{ Chars = $cf; Lines = $lf }
}
$fOk = $true; $fOut = @()
foreach ($lg in 'fr', 'en') {
    $t = $lOut[$lg].Cadre; $ph = $expL[$lg].Cadre
    $r = @()
    foreach ($v in @(@(96, $true), @(96, $false), @(120, $false), @(144, $false))) { foreach ($ell in $true, $false) {
        $x = Get-Fit $t $v[0] $ell $v[1]
        if ($x.Chars -lt $ph.Length -or -not $t.StartsWith($ph)) { $fOk = $false }
        $r += "$($v[0]) ppp$(if ($v[1]) { ' 13 px' }) $(if ($ell) { '...' } else { 'sans' }) $($x.Chars)/$($ph.Length)"
    } }
    $fOut += "$lg : $($r -join ' ; ')"
}
foreach ($x in $fOut) { "  L2 $x" }
Chk 'L2' $fOk "phrase du cadre entiere dans 262 x 54 px (Segoe UI 9,75 = 13 px, rendu compatible GDI+, LineLimit, avec et sans points de suspension, 96 a 144 ppp ; caracteres dessines / longueur de la phrase)"

# ================================================================ I. cles i18n de la RC6
"--- I : cles i18n de la RC6 (018) et appels de 300"
$newK = @("Lecteur cible {0} : aucune courbe croisée standard {1} → {0}, la restauration sera refusée au lancement.",
          "Règles appliquées à la copie : aucune avec le lecteur cible {0} : sans courbe croisée standard {1} → {0}, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture.",
          "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {3} non atteinte (elle serait refusée sans courbe croisée standard {4} → {3}).")
$oldK = @("Lecteur cible {0} : aucune courbe croisée {1} → {0} en double densité, la restauration sera refusée au lancement.",
          "Règles appliquées à la copie : aucune avec le lecteur cible {0} : sans courbe croisée {1} → {0} en double densité, la restauration sera refusée au lancement. Lancez « Calibrer pour un lecteur cible… », ou choisissez « (même lecteur) » dans la liste « Lecteur cible » de l'onglet Écriture.",
          "Règles      : lecture {0} tours, {1} essais x {2} séries ; écriture pour le lecteur cible {3} non atteinte (elle serait refusée sans courbe croisée {4} → {3} en double densité).")
$s300 = [System.IO.File]::ReadAllText((Join-Path $m '300-fn-restauration.ps1'), [System.Text.Encoding]::UTF8)
$iRows = @(); $iOk = $true
foreach ($k in $newK) {
    $has = $script:I18n.ContainsKey($k); $en = if ($has) { [string]$script:I18n[$k] } else { '' }
    $tr = ($has -and $en -ne $k -and $en -notmatch '[éèàùêç«»]' -and $en.Contains('standard cross curve'))
    $used = $s300.Contains('(T "' + $k + '")')
    $nPh = ([regex]::Matches($k, '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ''; $nPhE = ([regex]::Matches($en, '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ''
    if (-not ($tr -and $used -and $nPh -eq $nPhE)) { $iOk = $false }
    $iRows += "  I « $(Cut $k 70)… » : presente $has, traduite $tr, appelee dans 300 $used, marques $nPh / $nPhE ; « $(Cut $en 90)… »"
}
$oldLeft = @($oldK | Where-Object { $script:I18n.ContainsKey($_) -or $s300.Contains($_) })
$iRows; "  anciennes cles encore presentes : $($oldLeft.Count)"
Chk 'I1' ($iOk -and $oldLeft.Count -eq 0) "3 nouvelles cles (cadre, regles, rapport) presentes, traduites (« standard cross curve »), memes marques {n}, appelees par 300 ; anciennes cles « ... en double densite » retirees de 018 et de 300"

# ================================================================ W, C. wiki et CHANGELOG
"--- W, C : pages du wiki ($Wiki) et CHANGELOG du worktree"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
function Get-WikiText([string]$n) { $p = Join-Path $Wiki $n; if (-not (Test-Path -LiteralPath $p)) { return '' }; return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
$wk = @{ P = (Get-WikiText 'Précompensation-et-calibration.md'); R = (Get-WikiText 'Restaurer-une-disquette.md'); E = (Get-WikiText 'Écriture.md') }
$wNew = @(@('E', "Il reste grisé quand l'écriture n'applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; en profil « Auto », image haute densité non calibrable"),
          @('E', 'Un flux écrit avec un format MFM, que gw décode et écrit avec la précompensation, montre la courbe de sa famille'),
          @('P', "Il est grisé quand l'écriture n'applique aucune courbe calibrée (case « Précompensation (--precomp) : », « Précomp. tête 0 (--precomp) : » en écriture lente, décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; image haute densité non calibrable en profil « Auto », écrite avec le profil d'origine)"),
          @('P', "un flux écrit avec un format MFM montre la courbe de sa famille, comme les autres images"),
          @('R', '« Lecteur cible 0 : aucune courbe croisée standard A → 0, la restauration sera refusée au lancement. »'),
          @('R', '« Règles appliquées à la copie : aucune avec le lecteur cible 0 : sans courbe croisée standard A → 0, la restauration sera refusée au lancement. … »'))
$wOld = @(@('E', 'Il reste grisé pour un flux écrit tel quel, sans format (SCP, RAW...), et tant que'), @('P', 'Il est grisé pour un flux écrit tel quel, sans format (SCP, RAW…), et tant'),
          @('R', 'courbe croisée A → 0 en double densité'),
          @('E', "Il reste grisé pour une image à laquelle l'écriture ne transmet pas --precomp : flux écrit tel quel, sans format (SCP, RAW...), ou image FM, GCR ou à codage propre, hors profil « Manuel »"), @('P', "Il est grisé pour une image à laquelle l'écriture ne transmet pas --precomp (flux écrit tel quel, sans format, SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel »)"))
$wMiss = @($wNew | Where-Object { -not $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $(Cut $_[1] 70)" })
$wLeft = @($wOld | Where-Object { $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $($_[1])" })
Chk 'W1' ($wk.P -and $wk.R -and $wk.E -and $wMiss.Count -eq 0 -and $wLeft.Count -eq 0) "wiki : passages de la RC6 presents ($($wMiss.Count) absent(s)$(if ($wMiss.Count) { ' : ' + ($wMiss -join ' | ') })), passages de la RC5 retires ($($wLeft.Count) restant(s)$(if ($wLeft.Count) { ' : ' + ($wLeft -join ' | ') }))"
} else { "  W1 saute (wiki absent)" }
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$cNew = @("Comme pour un flux écrit tel quel, sans format, il est maintenant inactif quand l'écriture n'applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; image FM, GCR ou à codage propre, écrite sans précompensation (sauf avec le profil Manuel) ; en profil Auto, image haute densité non calibrable, écrite avec le profil d'origine.",
          "courbe double densité pour un format haute densité, alors écrit avec le profil d'origine haute densité,",
          "et grise le bouton quand l'écriture n'applique aucune courbe calibrée (``Test-RawFluxWrite``, case --precomp décochée, ``Test-NonMfmWrite`` hors profil Manuel, haute densité non calibrable en Auto)")
$cOld = @("et ne reste inactif que pour un flux écrit tel quel, sans format.", "comme il l'était pour un flux écrit tel quel, sans format :", "qui ne grise plus qu'un flux écrit tel quel (``Test-RawFluxWrite``)",
          "et ne reste inactif que pour une image à laquelle l'écriture ne transmet pas --precomp", "qui ne grise plus qu'une image à laquelle l'écriture ne transmet pas --precomp")
$cMiss = @($cNew | Where-Object { -not $cl.Contains($_) }); $cLeft = @($cOld | Where-Object { $cl.Contains($_) })
Chk 'C1' ($cMiss.Count -eq 0 -and $cLeft.Count -eq 0) "CHANGELOG : entree « Boutons « Courbe » » et ligne des developpeurs de la RC6 ($($cMiss.Count) passage(s) absent(s)$(if ($cMiss.Count) { ' : ' + (($cMiss | ForEach-Object { Cut $_ 60 }) -join ' | ') }) ; $($cLeft.Count) ancien(s) restant(s))"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-rc6-e : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
