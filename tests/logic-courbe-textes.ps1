# 12.10 RC7 (10/11/2026, v1210\rc7\make_rc7_tests.py) : copie de logic-1210-rc6fix2 ; texte du profil Manuel du bouton « Courbe » : « une courbe MFM du lecteur » (RC7).
param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-rc6fix3) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Sans -Wiki : L1 porte sur le CHANGELOG seul, W1 est saute.
# Correction fix2 de la RC6 12.10 (relecture r14 de 80a1bb6, 10/11/2026) : textes du bouton « Courbe » de l onglet Ecriture
# derives de sa decision. Cadre de v1210\rc6\fix1\logic-1210-rc6fix1.ps1 (repris par make_fix2_tests.py) : fonctions reelles
# extraites des modules par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par dot-source ;
# Update-PrecompForImage, Update-CurveButton, Show-WCurve et Start-ImageWrite reels ; controles WinForms reels jamais
# affiches ; bouchons pour l interface et gw ; fichiers d essai factices dans img\ (aucune donnee reelle).
# Cas : M1 (m3, decision que decrit le texte : profil Manuel sur une image FM, GCR, a codage propre ou haute densite non
# calibrable : courbe MFM double densite du lecteur), M2 temoin ; T1 et T2 (m3) ligne du profil Manuel de l infobulle
# (cle de 018, appel de 520 ; infobulle construite par les instructions de 520, en francais et en anglais) ; R1 (m4)
# commentaire du cas sans image d Update-CurveButton, R2 temoin du comportement decrit ; D1 (m1) et D2 (m3) CHANGELOG ;
# L1 (m2) libelle de la case --precomp cite tel que 520 le pose (CHANGELOG, wiki) ; W1 (m3) wiki. Sur 80a1bb6 avec le
# wiki d avant fix2 (v1210\rc6\fix2\src-80a1bb6, wiki-avant), T1, T2, R1, D1, D2, L1 et W1 sont NON. Aucun gw, aucune
# fenetre, aucun Add-Type, aucune evaluation de texte.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '230-fn-calib-courbe.ps1'))) { throw "modules introuvables sous $Wt" }
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
. (Join-Path $m '040-etat-formats.ps1')

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Cut([string]$t, [int]$n) { return $t.Substring(0, [math]::Min($n, $t.Length)) }
function Get-Ast([string]$file) { $tok = $null; $err = $null; return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err) }
$all = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '*.ps1')) {
    foreach ($fn in @((Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))) { $all[$fn.Name] = $fn.Extent.Text }
}
$want = @('Update-SlowUi', 'Get-WarmMinutesText', 'Get-TargetDrive', 'Set-TargetDrive', 'Get-DriveIds', 'Get-TargetWriteInfo', 'Get-TargetWriteBlock',
          'Test-TargetWriteAllowed', 'Test-RawFluxWrite', 'Test-FluxImage', 'Get-ImageEncoding', 'Test-NonMfmWrite', 'Get-HighDensityReason', 'Test-HdFormat',
          'Get-ImageFamily', 'Get-HdCalibFamily', 'Get-FormatCalibInfo', 'Get-HfeCellInfo', 'Get-IpfCellInfo', 'Get-ScpCellInfo', 'Get-BE32', 'Test-AdfHd',
          'Get-TargetCurves', 'Get-DriveFamilyCurves', 'Get-DriveCurve', 'Get-DriveCurveKey', 'Set-DriveCurve', 'Split-DriveCurveKey', 'Get-CurveDate',
          'Get-CalibFamilyName', 'Get-FamilyCurves', 'Test-HeadCurvesCurrent', 'Update-CurveButton', 'Show-RsCurve', 'Update-RsCalib', 'Get-RsCalibText',
          'Get-RestoreTargetInfo', 'Get-RestoreFormat', 'Get-RestorePlan', 'Update-RsRules', 'Get-Setting', 'Write-RestoreReport', 'Get-RestoreStem',
          'Get-CrossCalibTargets', 'Test-ManualPrecomp', 'Sync-PrecompCurves', 'Split-CrossDrive', 'Get-CurveKeyLabel', 'Get-DriveCurveKeys', 'Get-DriveCurveLabel',
          'Get-CalibState', 'Get-LevelBeforeWriteKind', 'Update-WLevelUi', 'Get-WCurveSet', 'Show-WCurve', 'Get-RsCurveSet', 'Get-WriteImageFamily',
          'Start-ImageWrite', 'Update-PrecompForImage', 'Set-PrecompFields', 'Get-TargetProfileText', 'Get-WProfileSpec', 'Set-WProfileText',
          'Get-WTargetHead', 'Sync-WTargetHead', 'Get-HdProfile', 'Get-HdCommonCurve', 'Get-HdAutoFields', 'Get-HeadSpec', 'Get-WriteFormatArgs',
          'Test-ImageHighDensity', 'Get-EraseMode', 'Get-EraseFallbackNote', 'Test-ScpDensityUnknown', 'Get-TSpecHeads', 'Get-TSpecExtras', 'Set-TSpecHead',
          'Test-ScpHighDensity')
$code = (@($want | ForEach-Object { if (-not $all.ContainsKey($_)) { throw "fonction $_ introuvable" }; $all[$_] }) -join "`r`n`r`n")
# 12.11 (lot L10) : decisions extraites de Start-WriteTabWrite, Start-LevelBeforeWrite et Start-ImageWrite (140, 260),
# chargees quand la source les a (une source d avant le lot n en a pas)
$code += "`r`n`r`n" + (@(@('Get-WriteLevelPlan', 'Get-LevelBeforeWritePlan', 'Get-WriteHeads', 'Get-WriteErasePlan', 'Get-WriteSpecPlan', 'Get-WriteHeadSpecs', 'Get-WriteCheckPlan') | Where-Object { $all.ContainsKey($_) } | ForEach-Object { $all[$_] }) -join "`r`n`r`n")
$gen = Join-Path $here 'gen-1210-rc6fix3.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
. $gen
"source : $Wt ; $($want.Count) fonctions reelles chargees ; wiki : $Wiki"

# --- Etat, controles et bouchons (repris de r13) --------------------------------------------------------------------
$script:Settings = @{ levelBeforeWrite = $true; levelBeforeWriteMode = 'content'; restoreFormat = 'auto'; calMode = 'std'; warmFullCalib = $true }
$script:CalWarmupMinutes = 5.0; $script:ScpStatsOk = $false; $script:DriveCurves = @{}; $script:PrecompCurves = @{}; $script:TargetDrives = @{}
$rr = (Get-Content -LiteralPath (Join-Path $m '580-etat-restauration.ps1') -Encoding UTF8 -Raw)
if ($rr -notmatch '\$script:RestoreRules = @\{ ReadRevs = (\d+); ReadRetries = (\d+); SeekRetries = (\d+); WriteRetries = (\d+); RepairPasses = (\d+)') { throw 'RestoreRules introuvable' }
$script:RestoreRules = @{ ReadRevs = [int]$Matches[1]; ReadRetries = [int]$Matches[2]; SeekRetries = [int]$Matches[3]; WriteRetries = [int]$Matches[4]; RepairPasses = [int]$Matches[5] }
$script:Restore = $null; $script:GwProc = $null; $script:GwExe = $PSCommandPath; $script:OpOverride = $null
$script:CurveKeys = @('std', 'std_h0', 'std_h1', 'long', 'long_h0', 'long_h1', 'hd', 'hd_h0', 'hd_h1')
$script:SettingDefs['drive'] = @{ Codes = @('A', 'B', '0', '1', '2', '3') }
$script:Version = '12.10'; $script:RsStepNames = @('Lire', 'Verifier', 'Changer', 'Sonder', 'Calibrer', 'Ecrire', 'Controler', 'Comparer')
$script:PrecompThresholdNs = 1950
$form = New-Object System.Windows.Forms.Form; $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)
$tip = New-Object System.Windows.Forms.ToolTip
function New-Chk([bool]$c) { $x = New-Object System.Windows.Forms.CheckBox; $x.Checked = $c; return $x }
$chkWSlow = New-Chk $true; $chkWPrecomp = New-Chk $true; $chkWLevel = New-Chk $true; $chkWWarm = New-Chk $true; $chkWCalWarm = New-Chk $true
$chkWHard = New-Chk $false; $chkWTG43 = New-Chk $false; $chkWEraseEmpty = New-Chk $false; $chkWPostCheck = New-Chk $false
$chkWPreErase = New-Chk $false; $chkWNoVerify = New-Chk $false; $chkWReverse = New-Chk $false
$numWRetries = New-Object System.Windows.Forms.NumericUpDown; $numWRetries.Value = 3
$numWRepair = New-Object System.Windows.Forms.NumericUpDown; $numWRepair.Value = 2
$cmbWDensel = New-Object System.Windows.Forms.ComboBox; $cmbWDensel.Text = '(non)'
$txtWFakeIdx = New-Object System.Windows.Forms.TextBox; $txtWDiskdefs = New-Object System.Windows.Forms.TextBox
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
$lblWProfileInfo = New-Object System.Windows.Forms.Label
$lblRsCal = New-Object System.Windows.Forms.Label; $lblRsCal.Font = $form.Font; $lblRsCal.Size = New-Object System.Drawing.Size(262, 54); $lblRsCal.AutoEllipsis = $true; $lblRsCal.UseCompatibleTextRendering = $true
$lblRsRules = New-Object System.Windows.Forms.Label; $lblRsRules.Font = $form.Font; $lblRsRules.UseCompatibleTextRendering = $true
$stOp = New-Object System.Windows.Forms.Label; $status = New-Object System.Windows.Forms.Label
$script:UiReady = $true
$script:WLevelTip = 'INFOBULLE D ORIGINE'
$script:Log = New-Object System.Collections.Generic.List[string]
$script:Calls = New-Object System.Collections.Generic.List[string]
$script:Shown = New-Object System.Collections.Generic.List[object]
$script:WriteQueue = New-Object 'System.Collections.Generic.Queue[object]'; $script:Chain = New-Object 'System.Collections.Generic.Queue[object]'
$script:LevelPostForce = $false; $script:WriteFactorNext = $null; $script:WFactorNote = $null; $script:WTargetHead = ''; $script:WProfileLabel = ''
$script:WProfilePath = ''; $script:WProfileBuilding = $false; $script:WProfileHd = $false
function Append-Log([string]$t) { $script:Log.Add($t) }
function Show-AppMessage($t, $c, $b = 'OK', $i = '') { $script:Calls.Add("Show-AppMessage[$c] $t"); $script:Log.Add($t); return 'OK' }
function Show-AppConfirm { $script:Calls.Add('Show-AppConfirm'); return $false }
function Get-ImageTrackSet($p) { return @{ '0.0' = $true; '0.1' = $true } }
function Get-AppBusy([switch]$Text) { return '' }
function Get-CurveCalcText($cv, [switch]$Plain) { return 'v12.10' }
function Show-CurvesWindow($cvs, $Owner = $null) { $script:Shown.Add(@{ Via = 'Show-CurvesWindow'; Curves = @($cvs | Where-Object { $_ }) }) }
function Save-Config { }
function Get-CurveCalc($cv) { return '12.10' }
function Get-CurveCalcRef($cv) { return '12.10' }
function Get-CommonArgs { return @('--drive=A') }
function Get-WriteFactorPlan { return @{ Apply = $false; Lines = @(); F0 = 1.0; F1 = 1.0; FMean = 1.0; Hard = 400 } }
function Get-WriteFactorNote([string]$p) { return '' }
function Update-WriteFactorNote { }
function Test-LevelAdaptedSpec($s) { return $false }
function Get-WriteCheckBlocker($i, $f) { return $null }
function Get-WriteWarmupTSpec { return $null }
function Get-WriteEraseKeys { return $null }
function Invoke-NextChainStep { }
$script:GwA = $null; $script:WQ = $null
function Start-Gw($a) { $script:GwA = @($a) }
function Start-WriteWarmup($ts, $nw) { $script:WQ = @($script:WriteQueue.ToArray()) }
# 12.11 (lot L11) : barre de l onglet pendant l ecriture (Start-WriteProgress, 160), affichage seulement, sans effet sur
# --precomp : bouchon (la file des commandes est relevee par Start-Gw et Start-WriteWarmup)
function Start-WriteProgress($cmds, $check) { }

# --- Fichiers d essai (contenu nul ou en-tete minimal, aucune donnee reelle) ----------------------------------------
$img = Join-Path $here 'img'; if (-not (Test-Path -LiteralPath $img)) { New-Item -ItemType Directory -Path $img | Out-Null }
$adf = Join-Path $img 'essai.adf'; [System.IO.File]::WriteAllBytes($adf, (New-Object byte[] 901120))
$adfHd = Join-Path $img 'essai-hd.adf'; [System.IO.File]::WriteAllBytes($adfHd, (New-Object byte[] 1802240))
$imgHd = Join-Path $img 'essai-hd.img'; [System.IO.File]::WriteAllBytes($imgHd, (New-Object byte[] 1474560))
$scp = Join-Path $img 'essai.scp'; $b = New-Object byte[] 4096; [System.Text.Encoding]::ASCII.GetBytes('SCP').CopyTo($b, 0); [System.IO.File]::WriteAllBytes($scp, $b)
$d64 = Join-Path $img 'essai.d64'; [System.IO.File]::WriteAllBytes($d64, (New-Object byte[] 174848))
$hfe = Join-Path $img 'essai-fm.hfe'; $h = New-Object byte[] 1024; [System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($h, 0); $h[9] = 80; $h[10] = 2; $h[11] = 2; [BitConverter]::GetBytes([uint16]250).CopyTo($h, 12); [System.IO.File]::WriteAllBytes($hfe, $h)
$hfeL = Join-Path $img 'essai-long.hfe'; $h = New-Object byte[] 1024; [System.Text.Encoding]::ASCII.GetBytes('HXCPICFE').CopyTo($h, 0); $h[9] = 80; $h[10] = 2; $h[11] = 0; [BitConverter]::GetBytes([uint16]265).CopyTo($h, 12); [System.IO.File]::WriteAllBytes($hfeL, $h)
$ipf = Join-Path $img 'essai.ipf'; $b = New-Object byte[] 2048; [System.Text.Encoding]::ASCII.GetBytes('CAPS').CopyTo($b, 0); [System.IO.File]::WriteAllBytes($ipf, $b)

function New-Curve([string]$drv, [string]$tgt, [string]$spec, [string]$fam = 'Standard 2 us') { return @{ Family = $fam; Drive = $drv; Target = $tgt; Date = '01/11/2026 17:49'; Spec = $spec; Method = 'motif'; Values = [int[]]@(1..80); Test = 'fine'; Converged = $true } }
$SP = @{ std = 'S=60'; std0 = 'S0=61'; std1 = 'S1=62'; long = 'L=70'; hd = 'H=40'; xstd = 'XS=90'; xlong = 'XL=95' }
function Set-Curves([string]$mode = 'all') {
    # all : courbes propres du lecteur A et courbes croisees A>0 ; nocross : sans courbe croisee ; noown : sans courbe propre
    $script:DriveCurves = @{}; $script:PrecompCurves = @{}
    if ($mode -ne 'noown') {
        Set-DriveCurve 'A' 'std' (New-Curve 'A' '' $SP.std); Set-DriveCurve 'A' 'std_h0' (New-Curve 'A' '' $SP.std0); Set-DriveCurve 'A' 'std_h1' (New-Curve 'A' '' $SP.std1)
        Set-DriveCurve 'A' 'long' (New-Curve 'A' '' $SP.long 'Long track 1,89 us'); Set-DriveCurve 'A' 'hd' (New-Curve 'A' '' $SP.hd 'Haute densité 1 us')
    }
    if ($mode -ne 'nocross') { Set-DriveCurve 'A>0' 'std' (New-Curve 'A' '0' $SP.xstd); Set-DriveCurve 'A>0' 'long' (New-Curve 'A' '0' $SP.xlong 'Long track 1,89 us') }
    Sync-PrecompCurves
}
function Get-Spec($cs) { return (@($cs | Where-Object { $_ } | ForEach-Object { [string]$_.Spec }) -join '/') }
function Get-Click {
    # Courbes du clic : Show-WCurve reel (fenetre remplacee par le releve de Show-CurvesWindow) ; '' si bouton grise
    $script:Shown.Clear()
    if (-not $btnWCurve.Enabled) { return '' }
    Show-WCurve
    if ($script:Shown.Count -eq 0) { return '' }
    return (Get-Spec $script:Shown[0].Curves)
}
function Get-WritePc {
    # --precomp transmis par Start-ImageWrite : 'refus' (Test-TargetWriteAllowed), sinon par commande ('-' : aucun)
    if (@($script:Calls | Where-Object { $_ -like 'Show-AppMessage*refus*' }).Count -gt 0) { return @{ Kind = 'refus'; Pc = @() } }
    $cmds = New-Object System.Collections.Generic.List[object]
    if ($null -ne $script:WQ) { foreach ($q in $script:WQ) { $cmds.Add($q) } } elseif ($null -ne $script:GwA) { $cmds.Add([object[]]$script:GwA) }
    if ($cmds.Count -eq 0) { return @{ Kind = 'rien'; Pc = @() } }
    $pcs = @()
    foreach ($c in $cmds) { $a = @($c); $i = [array]::IndexOf([object[]]$a, '--precomp'); $pcs += $(if ($i -ge 0) { [string]$a[$i + 1] } else { '-' }) }
    if (@($pcs | Where-Object { $_ -ne '-' }).Count -eq 0) { return @{ Kind = 'aucune'; Pc = $pcs } }
    return @{ Kind = 'pc'; Pc = $pcs }
}
function Reset-Run { $script:Calls.Clear(); $script:Log.Clear(); $script:Shown.Clear(); $script:WQ = $null; $script:GwA = $null; $script:WriteQueue.Clear(); $script:Chain.Clear() }
function Invoke-Scn([string]$file, [string]$fmt, [int]$prof, [string]$tgt, [bool]$slow, [bool]$precompBefore = $true, [string]$curves = 'all') {
    # Etat de l onglet, profil calcule par Update-PrecompForImage reel (image choisie ou profil change), bouton et clic,
    # puis ecriture par Start-ImageWrite reel ; $precompBefore : case --precomp avant le calcul du profil (P2) ; $curves :
    # magasin de courbes (Set-Curves)
    Set-Curves $curves
    $script:TargetDrives = @{}; if ($tgt) { $script:TargetDrives['A'] = $tgt }
    $chkWSlow.Checked = $slow; $chkWPrecomp.Checked = $precompBefore
    $txtWFile.Text = $file; $cmbWFmt.Text = $fmt; $cmbWProfile.SelectedIndex = $prof
    $txtWPrecomp.Text = 'MAN0'; $txtWPrecomp1.Text = 'MAN1'
    Reset-Run
    Update-PrecompForImage $file
    $en = [bool]$btnWCurve.Enabled
    $click = Get-Click
    $pcOn = [bool]$chkWPrecomp.Checked
    Reset-Run
    Start-ImageWrite
    $w = Get-WritePc
    return @{ En = $en; Click = $click; W = $w; Fam = [string]$script:CurveFamily; PcOn = $pcOn; NonMfm = (Test-NonMfmWrite $file $fmt); Raw = (Test-RawFluxWrite $file $fmt) }
}
function Test-Match($r, [bool]$slow) {
    # Bouton conforme a l ecriture : aucune precompensation (refus, aucune) -> bouton grise ; precompensation -> bouton actif,
    # courbes du clic = profils transmis (ecriture rapide : un profil ; lente : tete 0 / tete 1, ou commun aux deux)
    if ($r.W.Kind -ne 'pc') { return (-not $r.En) }
    if (-not $r.En) { return $false }
    $sp = @($r.Click -split '/' | Where-Object { $_ })
    if (-not $slow) { return ($sp.Count -eq 1 -and $sp[0] -eq $r.W.Pc[0]) }
    if ($sp.Count -eq 2) { return ($sp[0] -eq $r.W.Pc[0] -and $sp[1] -eq $r.W.Pc[1]) }
    if ($sp.Count -eq 1) { return (@($r.W.Pc | Where-Object { $_ -ne $sp[0] }).Count -eq 0) }
    return $false
}

# Images : nom, fichier, format, famille de l image attendue (ecrite ici, independante du code : profil Manuel, C9), haute
# densite non calibrable (profil d origine en Auto, C7)
$imgs = @(@('ADF', $adf, '(auto)', 'std', $false), @('ADF+amiga', $adf, 'amiga.amigados', 'std', $false), @('SCP brut', $scp, '(auto)', 'std', $false),
          @('SCP+amiga', $scp, 'amiga.amigados', 'std', $false), @('SCP+c1541', $scp, 'commodore.1541', 'std', $false), @('SCP+mac800', $scp, 'mac.800', 'std', $false),
          @('D64', $d64, '(auto)', 'std', $false), @('HFE FM', $hfe, '(auto)', 'std', $false), @('HFE long', $hfeL, '(auto)', 'long', $false), @('IPF', $ipf, '(auto)', 'std', $false),
          @('ADF HD', $adfHd, '(auto)', 'hd', $false), @('IMG HD', $imgHd, '(auto)', 'std', $true), @('IMG+ibm1440', $imgHd, 'ibm.1440', 'hd', $false),
          @('SCP+ibm2880', $scp, 'ibm.2880', 'std', $true))
$pn = @('Auto', 'Std', 'Long', 'Manuel')
function Get-OwnSpec([string]$fam, [bool]$slow) {
    # Courbes propres attendues du lecteur A pour une famille (magasin de Set-Curves) : std par tete en ecriture lente
    if ($fam -eq 'std') { if ($slow) { return "$($SP.std0)/$($SP.std1)" } else { return $SP.std } }
    return $SP[$fam]
}

# Phrase commune (infobulle, CHANGELOG, wiki) : courbe montree en profil Manuel pour les images que l ecriture Auto ou forcee
# ecrit sans courbe calibree
$sansFr = "pour une image FM, GCR, à codage propre ou haute densité non calibrable, c'est une courbe MFM du lecteur, sans objet pour cette image."
$sansFrP = 'P' + $sansFr.Substring(1)

# ================================================================ M. profil Manuel : courbe montree (m3)
"--- M : profil Manuel, ecriture rapide sans lecteur cible : courbe du bouton (Update-PrecompForImage, Update-CurveButton, Show-WCurve reels)"
$mDd = @(); $mOther = @(); $nSans = 0
foreach ($im in $imgs) {
    if (Test-RawFluxWrite $im[1] $im[2]) { continue }
    $r = Invoke-Scn $im[1] $im[2] 3 '' $false
    $sans = [bool]((Test-NonMfmWrite $im[1] $im[2]) -or $im[4])
    "  $($im[0]) : FM/GCR/codage propre ou haute densite non calibrable $sans ; bouton $($r.En) ; fam $($r.Fam) ; clic [$($r.Click)] ; ecriture $($r.W.Kind) [$($r.W.Pc -join '/')]"
    if ($sans) {
        $nSans++
        if (-not ($r.En -and ($r.Fam -eq 'std' -or $r.Fam -eq 'long') -and $r.Click -eq (Get-OwnSpec $r.Fam $false))) { $mDd += "$($im[0]) (fam $($r.Fam), clic [$($r.Click)])" }
    } elseif (-not ($r.En -and $r.Fam -eq $im[3] -and $r.Click -eq (Get-OwnSpec $im[3] $false))) { $mOther += "$($im[0]) (fam $($r.Fam), attendu $($im[3]))" }
}
Chk 'M1' ($mDd.Count -eq 0 -and $nSans -eq 6) "m3 (decision que decrit le texte) : profil Manuel, image FM, GCR, a codage propre ou haute densite non calibrable ($nSans images : SCP+commodore.1541, SCP+mac.800, D64, HFE FM, IMG HD, SCP+ibm.2880) : bouton actif sur une courbe MFM double densite du lecteur (famille standard ou long track) ; ecarts : $($mDd -join ', ')"
Chk 'M2' ($mOther.Count -eq 0) "temoin : profil Manuel, autres images (MFM double densite, haute densite calibrable) : courbe du lecteur pour la famille de l image (attente ecrite dans `$imgs) ; ecarts : $($mOther -join ', ')"

# ================================================================ T. infobulle : ligne du profil Manuel (m3)
"--- T : ligne du profil Manuel de l infobulle du bouton « Courbe » (520, cle de 018)"
$src520 = [System.IO.File]::ReadAllText((Join-Path $m '520-ui-ecriture.ps1'), [System.Text.Encoding]::UTF8)
$kOld = "Profil Manuel : la courbe calibrée du lecteur pour la famille de l'image ; le champ --precomp est transmis tel quel."
$kMan = $kOld + ' ' + $sansFrP
$tTr = $script:I18n.ContainsKey($kMan) -and $script:I18n[$kMan] -like 'Manual profile:*' -and $script:I18n[$kMan] -like '*an MFM curve of the drive, irrelevant to that image.'
$tCall = $src520.Contains('(T "' + $kMan + '")')
$tOld = $script:I18n.ContainsKey($kOld) -or $src520.Contains('(T "' + $kOld + '")')
"  cle traduite $tTr ; appelee par 520 $tCall ; ancienne cle restante $tOld"
if ($tTr) { "  anglais : $($script:I18n[$kMan])" }
Chk 'T1' ($tTr -and $tCall -and -not $tOld) "m3 : ligne du profil Manuel de l infobulle completee (courbe MFM double densite du lecteur, sans objet pour une image FM, GCR, a codage propre ou haute densite non calibrable) : cle de 018 traduite, appelee par 520, ancienne cle retiree"
# T2 : infobulle construite par les instructions reelles de 520 (extraites par l arbre syntaxique, fichier de travail charge
# par dot-source), en francais et en anglais
$ast520 = Get-Ast (Join-Path $m '520-ui-ecriture.ps1')
$tipSt = @($ast520.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('$tip.SetToolTip($btnWCurve, ') } | ForEach-Object { $_.Extent.Text })
$genTip = Join-Path $here 'gen-1210-rc6fix3-tip.ps1'
[System.IO.File]::WriteAllText($genTip, ("function Invoke-WCurveTip {`r`n    " + ($tipSt -join "`r`n    ") + "`r`n}`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $genTip
$tt = @{}
foreach ($lg in 'fr', 'en') { $script:Lang = $lg; Invoke-WCurveTip; $tt[$lg] = [string]$tip.GetToolTip($btnWCurve) }
$script:Lang = 'fr'
$nFr = @($tt.fr -split "`n").Count; $lastFr = @($tt.fr -split "`n")[-1]; $lastEn = @($tt.en -split "`n")[-1]
"  infobulle construite par 520 : $($tipSt.Count) instructions, $nFr lignes ; derniere ligne (fr) : $lastFr"
"  derniere ligne (en) : $lastEn"
Chk 'T2' ($tipSt.Count -eq 3 -and $nFr -eq 4 -and $lastFr -ceq $kMan -and $lastEn -ceq [string]$script:I18n[$kMan]) "m3 : infobulle du bouton « Courbe » construite par les instructions de 520 ($($tipSt.Count) instructions, $nFr lignes) : la derniere ligne est celle du profil Manuel completee, en francais et en anglais"

# ================================================================ R. bouton sans image (m4)
"--- R : bouton sans image (Update-CurveButton reel) et commentaire de ce cas"
$rDiff = @()
foreach ($p in 0, 1, 2, 3) {
    Set-Curves; $script:TargetDrives = @{}; $chkWSlow.Checked = $false; $chkWPrecomp.Checked = $true
    $txtWFile.Text = ''; $cmbWFmt.Text = '(auto)'; $cmbWProfile.SelectedIndex = $p
    Update-CurveButton ''
    $en = [bool]$btnWCurve.Enabled; $fam = [string]$script:CurveFamily; $c = Get-Click
    $want = if ($p -eq 2) { 'long' } else { 'std' }
    "  sans image|$($pn[$p]) : bouton $en ; fam $fam ; clic [$c]"
    if (-not ($en -and $fam -eq $want -and $c -eq (Get-OwnSpec $want $false))) { $rDiff += "$($pn[$p]) : fam $fam (attendu $want), clic [$c]" }
}
$cb = [string]$all['Update-CurveButton']
$rNew = 'une image seulement (sans image : courbe du lecteur pour la famille du profil force, sinon standard)'
$rOld = 'sans image, aucune ecriture a decrire : courbe du lecteur, comme avant'
Chk 'R1' ($cb.Contains($rNew) -and -not $cb.Contains($rOld)) "m4 : commentaire d Update-CurveButton (230) sur le cas sans image : famille du profil force, sinon standard (nouveau present $($cb.Contains($rNew)) ; ancien restant $($cb.Contains($rOld)))"
Chk 'R2' ($rDiff.Count -eq 0) "temoin (comportement que decrit R1) : sans image, case --precomp cochee : profil Long track : courbe long track du lecteur ; Auto, Standard et Manuel : courbe standard ; ecarts : $($rDiff -join ', ')"

# ================================================================ D. CHANGELOG (m1, m3)
"--- D : CHANGELOG du worktree, entree « Boutons « Courbe » »"
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$d1New = "Comme pour un flux écrit tel quel, sans format, il est maintenant inactif quand l'écriture n'applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; image FM, GCR ou à codage propre, écrite sans précompensation (sauf avec le profil Manuel) ; en profil Auto, image haute densité non calibrable, écrite avec le profil d'origine."
$d1Old = "comme il l'était pour un flux écrit tel quel, sans format :"
Chk 'D1' ($cl.Contains($d1New) -and -not $cl.Contains($d1Old)) "m1 : cas d inactivite du bouton introduits par « n applique aucune courbe calibree : », plus par « sans format : » (nouveau present $($cl.Contains($d1New)) ; ancien restant $($cl.Contains($d1Old)))"
$d2New = "et non plus celle de l'image. En profil Manuel, il montre la courbe calibrée du lecteur pour la famille de l'image, le champ --precomp étant transmis tel quel ; $sansFr"
$d2Old = "; en profil Manuel, la courbe calibrée du lecteur pour la famille de l'image, le champ --precomp étant transmis tel quel. Il devient"
Chk 'D2' ($cl.Contains($d2New) -and -not $cl.Contains($d2Old)) "m3 : profil Manuel du CHANGELOG complete comme l infobulle (nouveau present $($cl.Contains($d2New)) ; ancien restant $($cl.Contains($d2Old)))"

# ================================================================ L. libelle de la case cite tel que 520 le pose (m2)
"--- L : libelle de la case --precomp (520) cite dans le CHANGELOG et le wiki ($Wiki)"
if ($src520 -notmatch '\$chkWPrecomp\.Text = \(T ''([^'']+)''\)') { throw 'libelle de la case --precomp introuvable dans 520' }
$lab = $Matches[1]
"  libelle de 520 : « $lab »"
$docs = @(@{ N = 'CHANGELOG.md'; P = (Join-Path $Wt 'CHANGELOG.md') })
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) { foreach ($f in @(Get-ChildItem -LiteralPath $Wiki -Filter '*.md' | Sort-Object Name)) { $docs += @{ N = $f.Name; P = $f.FullName } } } else { '  wiki absent : L1 porte sur le CHANGELOG seul' }
$lBad = @(); $lOk = 0
foreach ($d in $docs) {
    $ln = 0
    foreach ($l in [System.IO.File]::ReadAllLines($d.P, [System.Text.Encoding]::UTF8)) {
        $ln++
        foreach ($x in [regex]::Matches($l, '«\s*(Précompensation \(--precomp\)[^»]*?)\s*»')) {
            if ($x.Groups[1].Value -ceq $lab) { $lOk++ } else { $lBad += "$($d.N):$ln « $($x.Groups[1].Value) »" }
        }
    }
}
"  citations conformes : $lOk ; autres : $($lBad.Count)"
Chk 'L1' ($lBad.Count -eq 0 -and $lOk -gt 0) "m2 : toute citation « Precompensation (--precomp)... » du CHANGELOG et du wiki ($($docs.Count) fichiers) reprend le libelle de la case tel que 520 le pose ; ecarts : $($lBad -join ' ; ')"

# ================================================================ W. wiki (m3)
"--- W : pages du wiki ($Wiki)"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
function Get-WikiText([string]$n) { $p = Join-Path $Wiki $n; if (-not (Test-Path -LiteralPath $p)) { return '' }; return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
$wk = @{ E = (Get-WikiText 'Écriture.md'); P = (Get-WikiText 'Précompensation-et-calibration.md') }
$wNew = @(@('E', "En profil « Manuel », il montre la courbe calibrée du lecteur pour la famille de l'image ; le champ --precomp est transmis tel quel ; $sansFr"),
          @('P', "En profil « Manuel », il montre la courbe calibrée du lecteur pour la famille de l'image, le champ --precomp étant transmis tel quel ; $sansFr"))
$wOld = @(@('E', 'le champ --precomp est transmis tel quel. Il reste grisé'), @('P', 'le champ --precomp étant transmis tel quel. Il est grisé'))
$wMiss = @($wNew | Where-Object { -not $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $(Cut $_[1] 70)" })
$wLeft = @($wOld | Where-Object { $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $($_[1])" })
Chk 'W1' ($wk.E -and $wk.P -and $wMiss.Count -eq 0 -and $wLeft.Count -eq 0) "m3 : wiki Ecriture.md et Precompensation-et-calibration.md : profil Manuel complete comme l infobulle ; $($wMiss.Count) absent(s)$(if ($wMiss.Count) { ' : ' + ($wMiss -join ' | ') }) ; $($wLeft.Count) ancien(s) restant(s)$(if ($wLeft.Count) { ' : ' + ($wLeft -join ' | ') })"
} else { "  W1 saute (wiki absent)" }

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-rc6fix3 : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
