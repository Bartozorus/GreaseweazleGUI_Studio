# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_tests.py) : copie de logic-1210-rc6fix1-c.ps1 ; passages du wiki d apres le commit 54f3e91 ; Get-CalibEnvBlock extraite.
# 12.10 RC7 (10/11/2026, v1210\rc7\make_rc7_tests.py) : copie de logic-1210-rc6fix1-b ; texte du profil Manuel du bouton « Courbe » : « une courbe MFM du lecteur » (RC7).
param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-rc6fix1-d) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Cas D2 saute sans -Wiki.
# Copie adaptee par la correction fix2 de la RC6 (10/11/2026, v1210\rc6\fix2\make_fix2_tests.py, source v1210\rc6\fix1\logic-1210-rc6fix1.ps1) : T1 : cle de la ligne du profil Manuel completee ; D1 : CHANGELOG (profil Manuel complete, phrase des cas d inactivite reformulee) ; D2 : wiki (profil Manuel complete, libelle de la case avec son deux-points).
# Correction fix1 de la RC6 12.10 (relecture r13 de 2c1eb08, 10/11/2026) : bouton « Courbe » de l onglet Ecriture compare a ce
# que l ecriture transmet vraiment a gw. Cadre repris de la relecture r13 (v1210\rc6\revue\r13-2c1eb08\r13-logique.ps1) :
# fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par
# dot-source ; Update-PrecompForImage, Update-CurveButton, Get-WCurveSet, Show-WCurve et Start-ImageWrite reels ; controles
# WinForms reels jamais affiches ; bouchons pour l interface et gw (Start-Gw et Start-WriteWarmup relevent les commandes) ;
# fichiers d essai factices dans img\ (contenu nul ou en-tete minimal, aucune donnee reelle).
# Cas : C1 a C5 (temoins de la RC6 et du profil Auto) ; C6 profils forces sans lecteur cible (B1) ; C7 haute densite non
# calibrable en Auto (B1) ; C8 matrice hors profil Manuel ; C9 profil Manuel (m3) ; P1 a P3 case --precomp (m3) ; T1 cles
# i18n de l infobulle (m5) ; D1 CHANGELOG (B1, m1, m3) ; D2 wiki (B1, m3, m4).
# Sur 2c1eb08 (ancienne source), C6, C7, C8, P1, P2, T1, D1 et D2 sont NON. Aucun gw, aucune fenetre, aucun Add-Type,
# aucune evaluation de texte.
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
$gen = Join-Path $here 'gen-1210-rc6fix1-d.ps1'
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

# ================================================================ C. matrice du bouton « Courbe » contre Start-ImageWrite
"--- C : bouton « Courbe » (Update-PrecompForImage, Update-CurveButton, Show-WCurve reels) contre --precomp transmis par Start-ImageWrite reel"
"    courbes : A std $($SP.std) (tete 0 $($SP.std0), tete 1 $($SP.std1)), A long $($SP.long), A hd $($SP.hd), A>0 std $($SP.xstd), A>0 long $($SP.xlong) ; champs Manuel MAN0/MAN1"
$res = @{}
foreach ($im in $imgs) { foreach ($tg in '', '0') { foreach ($p in 0, 1, 2, 3) { foreach ($sl in $true, $false) {
    $r = Invoke-Scn $im[1] $im[2] $p $tg $sl
    $tag = "$($im[0])|cible=$(if ($tg) { $tg } else { '-' })|$($pn[$p])|$(if ($sl) { 'lente' } else { 'rapide' })"
    $res[$tag] = $r
} } } }
function Get-Row([string]$tag) { $r = $res[$tag]; return ("{0,-42} bouton {1,-5} clic [{2}] ; ecriture {3} [{4}] ; fam {5}" -f $tag, $r.En, $r.Click, $r.W.Kind, ($r.W.Pc -join '/'), $r.Fam) }
function Get-Tag($im, [string]$tg, [int]$p, [bool]$sl) { return "$($im[0])|cible=$(if ($tg) { $tg } else { '-' })|$($pn[$p])|$(if ($sl) { 'lente' } else { 'rapide' })" }
foreach ($k in @($res.Keys | Sort-Object)) { "  $(if ($k -like '*|Manuel|*' -or (Test-Match $res[$k] ($k -like '*|lente'))) { 'ok  ' } else { 'DIFF' }) $(Get-Row $k)" }

# C1 : FM, GCR, codage propre hors Manuel : bouton grise, ecriture sans --precomp
$c1 = @(); foreach ($im in $imgs) { if (-not (Test-NonMfmWrite $im[1] $im[2])) { continue }; foreach ($tg in '', '0') { foreach ($p in 0, 1, 2) { foreach ($sl in $true, $false) { $t = Get-Tag $im $tg $p $sl; $r = $res[$t]; if ($r.En -or $r.W.Kind -eq 'pc') { $c1 += $t } } } } }
Chk 'C1' ($c1.Count -eq 0) "temoin RC6 : image FM, GCR ou a codage propre (SCP+commodore.1541, SCP+mac.800, D64, HFE FM), profils Auto, Std, Long, avec et sans lecteur cible : bouton grise, ecriture sans --precomp ; ecarts : $($c1 -join ', ')"
# C2 : Manuel sur ces images : champ transmis, bouton actif
$c2 = @(); foreach ($im in $imgs) { if (-not (Test-NonMfmWrite $im[1] $im[2])) { continue }; foreach ($tg in '', '0') { foreach ($sl in $true, $false) { $t = Get-Tag $im $tg 3 $sl; $r = $res[$t]; if (-not ($r.En -and $r.W.Kind -eq 'pc' -and $r.W.Pc[0] -eq 'MAN0')) { $c2 += $t } } } }
Chk 'C2' ($c2.Count -eq 0) "temoin RC6 : profil Manuel sur image FM/GCR : champ MAN0 transmis tel quel, bouton actif ; ecarts : $($c2 -join ', ')"
# C3 : flux tel quel, tous profils : bouton grise, aucun --precomp
$c3 = @(); foreach ($tg in '', '0') { foreach ($p in 0, 1, 2, 3) { foreach ($sl in $true, $false) { $t = Get-Tag $imgs[2] $tg $p $sl; $r = $res[$t]; if ($r.En -or $r.W.Kind -eq 'pc') { $c3 += $t } } } }
Chk 'C3' ($c3.Count -eq 0) "temoin : SCP sans format (flux ecrit tel quel), 4 profils, avec et sans lecteur cible : bouton grise, aucun --precomp ; ecarts : $($c3 -join ', ')"
# C4 : Auto, images MFM calibrables ou double densite : bouton = ecriture
$c4 = @(); foreach ($im in $imgs) { if ((Test-NonMfmWrite $im[1] $im[2]) -or (Test-RawFluxWrite $im[1] $im[2]) -or $im[4]) { continue }; foreach ($tg in '', '0') { foreach ($sl in $true, $false) { $t = Get-Tag $im $tg 0 $sl; if (-not (Test-Match $res[$t] $sl)) { $c4 += $t } } } }
Chk 'C4' ($c4.Count -eq 0) "temoin : profil Auto, images MFM (secteur DD, flux + format MFM, long track, IPF, haute densite calibrable), avec et sans lecteur cible : clic = --precomp transmis, bouton grise sur refus ; ecarts : $($c4 -join ', ')"
# C5 : profils forces avec lecteur cible : courbes croisees de la famille du profil
$c5 = @(); foreach ($im in $imgs) { if ((Test-NonMfmWrite $im[1] $im[2]) -or (Test-RawFluxWrite $im[1] $im[2])) { continue }; foreach ($p in 1, 2) { foreach ($sl in $true, $false) { $t = Get-Tag $im '0' $p $sl; if (-not (Test-Match $res[$t] $sl)) { $c5 += $t } } } }
Chk 'C5' ($c5.Count -eq 0) "temoin : profils forces Std et Long, lecteur cible 0, images MFM : clic = --precomp transmis (courbe croisee du profil) ; ecarts : $($c5 -join ', ')"
# C6 (B1) : profils forces sans lecteur cible : courbe de la famille du profil, celle que l ecriture applique
$c6 = @(); foreach ($im in $imgs) { if ((Test-NonMfmWrite $im[1] $im[2]) -or (Test-RawFluxWrite $im[1] $im[2])) { continue }; foreach ($p in 1, 2) { foreach ($sl in $true, $false) { $t = Get-Tag $im '' $p $sl; $r = $res[$t]; $wantF = if ($p -eq 1) { 'std' } else { 'long' }; if (-not ((Test-Match $r $sl) -and $r.Fam -eq $wantF)) { $c6 += "$t : clic [$($r.Click)] ecriture [$($r.W.Pc -join '/')]" } } } }
Chk 'C6' ($c6.Count -eq 0) "B1 : profils forces Std et Long sans lecteur cible, images MFM (ADF, SCP+amiga, HFE long, IPF, haute densite) : famille du profil, clic = --precomp transmis ; ecarts ($($c6.Count)) : $(Cut ($c6 -join ' ; ') 600)"
# C7 (B1) : haute densite non calibrable en Auto : profil d origine ecrit (sans lecteur cible), refus (lecteur cible) : bouton grise
$c7 = @(); $c7s = @()
foreach ($im in @($imgs | Where-Object { $_[4] })) { foreach ($tg in '', '0') { foreach ($sl in $true, $false) {
    $t = Get-Tag $im $tg 0 $sl; $r = $res[$t]
    $wOk = if ($tg) { $r.W.Kind -eq 'refus' } else { $r.W.Kind -eq 'pc' -and @($r.W.Pc | Where-Object { $_ -ne '0=70:40=100:65=140' }).Count -eq 0 }
    if ($r.En -or -not $wOk) { $c7 += "$t : bouton $($r.En), clic [$($r.Click)], ecriture $($r.W.Kind) [$($r.W.Pc -join '/')]" }
    $c7s += "$t : bouton $($r.En), ecriture $($r.W.Kind) [$($r.W.Pc -join '/')]"
} } }
"  C7 : $($c7s -join ' ; ')"
Chk 'C7' ($c7.Count -eq 0) "B1 : haute densite non calibrable en Auto (IMG de 1 474 560 octets sans format, SCP + ibm.2880) : profil d origine ecrit sans lecteur cible, ecriture refusee avec le lecteur cible 0 : bouton grise dans tous les cas ; ecarts : $($c7 -join ' ; ')"
# C8 : matrice entiere hors profil Manuel : bouton = ecriture ; haute densite non calibrable en Auto sans lecteur cible
# (profil d origine ecrit, aucune courbe calibree : C7) : bouton grise
$hdoNames = @($imgs | Where-Object { $_[4] } | ForEach-Object { $_[0] })
$c8 = @($res.Keys | Where-Object { $_ -notlike '*|Manuel|*' } | Where-Object {
    $k = $_; $r = $res[$k]
    if ($hdoNames -contains ($k -split '\|')[0] -and $k -like '*|cible=-|Auto|*') { $r.En } else { -not (Test-Match $r ($k -like '*|lente')) } } | Sort-Object)
$nC8 = @($res.Keys | Where-Object { $_ -notlike '*|Manuel|*' }).Count
Chk 'C8' ($c8.Count -eq 0 -and $nC8 -eq 168) "matrice hors profil Manuel ($nC8 combinaisons : 14 images x 3 profils x lecteur cible x ecriture lente) : bouton actif si et seulement si l ecriture applique une courbe calibree (--precomp transmis, hors profil d origine de la haute densite non calibrable), clic = profils transmis ; ecarts ($($c8.Count)) : $(Cut ($c8 -join ', ') 400)"
# C9 (m3) : profil Manuel : champ transmis tel quel ; bouton actif (sauf flux tel quel) sur la courbe calibree du lecteur
# pour la famille de l image (attente ecrite dans $imgs), meme avec un lecteur cible (sans effet en Manuel)
$c9 = @(); $nC9 = 0
foreach ($im in $imgs) { foreach ($tg in '', '0') { foreach ($sl in $true, $false) {
    $t = Get-Tag $im $tg 3 $sl; $r = $res[$t]; $nC9++
    if (Test-RawFluxWrite $im[1] $im[2]) { if ($r.En -or $r.W.Kind -eq 'pc') { $c9 += "$t : flux tel quel" }; continue }
    $wantW = if ($sl) { 'MAN0/MAN1' } else { 'MAN0' }
    $wantC = Get-OwnSpec $im[3] $sl
    if (-not ($r.En -and $r.Click -eq $wantC -and $r.W.Kind -eq 'pc' -and ($r.W.Pc -join '/') -eq $wantW)) { $c9 += "$t : bouton $($r.En), clic [$($r.Click)] (attendu [$wantC]), ecriture [$($r.W.Pc -join '/')]" }
} } }
Chk 'C9' ($c9.Count -eq 0 -and $nC9 -eq 56) "m3 : profil Manuel ($nC9 combinaisons) : champ MAN0 (MAN0/MAN1 en ecriture lente) transmis tel quel ; bouton actif sur la courbe du lecteur pour la famille de l image (standard, long track, haute densite), lecteur cible sans effet ; flux tel quel grise ; ecarts : $(Cut ($c9 -join ' ; ') 500)"

# ================================================================ P. case « Precompensation (--precomp) »
"--- P : case « Precompensation (--precomp) » : decochee apres le profil (gestionnaire de 520 : Update-WLevelUi, Update-CurveButton) ; decochee avant le profil (Update-PrecompForImage la recoche)"
$p1 = @()
foreach ($im in @($imgs[0], $imgs[3], $imgs[8], $imgs[10])) { foreach ($tg in '', '0') { foreach ($p in 0, 1, 3) {
    Set-Curves; $script:TargetDrives = @{}; if ($tg) { $script:TargetDrives['A'] = $tg }
    $chkWSlow.Checked = $false; $chkWPrecomp.Checked = $true; $txtWFile.Text = $im[1]; $cmbWFmt.Text = $im[2]; $cmbWProfile.SelectedIndex = $p
    $txtWPrecomp.Text = 'MAN0'; $txtWPrecomp1.Text = 'MAN1'
    Update-PrecompForImage $im[1]
    $chkWPrecomp.Checked = $false; Update-WLevelUi; Update-CurveButton $im[1]
    $en = [bool]$btnWCurve.Enabled
    Reset-Run; Start-ImageWrite; $w = Get-WritePc
    $t = "$($im[0])|cible=$(if ($tg) { $tg } else { '-' })|$($pn[$p])"
    "  P1 $t : bouton $en ; ecriture $($w.Kind) [$($w.Pc -join '/')]"
    if ($en -or $w.Kind -eq 'pc') { $p1 += $t }
    $chkWPrecomp.Checked = $true
} } }
Chk 'P1' ($p1.Count -eq 0) "m3 : case --precomp decochee (ADF, SCP+amiga, HFE long, ADF HD ; profils Auto, Std, Manuel ; avec et sans lecteur cible 0) : aucun --precomp transmis, bouton grise ; ecarts : $($p1 -join ', ')"
# P2 : case decochee, puis image choisie de nouveau (Update-PrecompForImage) : case recochee par le profil, bouton = ecriture
# Magasins : complet ; sans courbe croisee (lecteur cible 0 : ecriture refusee, bouton grise) ; sans courbe propre (lecteur
# cible 0 : courbe croisee ecrite, bouton actif)
$p2 = @()
foreach ($cv in @(@('all', ''), @('all', '0'), @('nocross', '0'), @('noown', '0'))) { foreach ($sl in $true, $false) {
    $r = Invoke-Scn $adf 'amiga.amigados' 0 $cv[1] $sl $false $cv[0]
    $ok = $r.PcOn -and (Test-Match $r $sl)
    "  P2 ADF+amiga|courbes=$($cv[0])|cible=$(if ($cv[1]) { $cv[1] } else { '-' })|$(if ($sl) { 'lente' } else { 'rapide' }) : case recochee $($r.PcOn) ; bouton $($r.En), clic [$($r.Click)] ; ecriture $($r.W.Kind) [$($r.W.Pc -join '/')]"
    if (-not $ok) { $p2 += "$($cv[0])|cible=$($cv[1])|$sl" }
} }
Chk 'P2' ($p2.Count -eq 0) "m3 : case decochee avant le calcul du profil (image choisie de nouveau, Update-PrecompForImage) : case recochee, bouton recalcule apres elle = ecriture (actif sur la courbe du lecteur ; sur la courbe croisee XS=90 sans courbe propre ; grise sur le refus sans courbe croisee) ; ecarts : $($p2 -join ', ')"
# P3 : temoin : sans image, case decochee : bouton comme avant (courbe standard du lecteur)
Set-Curves; $script:TargetDrives = @{}; $chkWSlow.Checked = $false; $txtWFile.Text = ''; $cmbWFmt.Text = '(auto)'; $cmbWProfile.SelectedIndex = 0
$chkWPrecomp.Checked = $false; Update-CurveButton ''; $p3en = [bool]$btnWCurve.Enabled; $p3c = Get-Click; $chkWPrecomp.Checked = $true
Chk 'P3' ($p3en -and $p3c -eq $SP.std) "temoin : sans image, case --precomp decochee : bouton actif sur la courbe standard du lecteur, comme avant (bouton $p3en, clic [$p3c])"

# ================================================================ T. infobulle du bouton (520, cles i18n)
"--- T : infobulle du bouton « Courbe » (520) et cles i18n"
$src520 = [System.IO.File]::ReadAllText((Join-Path $m '520-ui-ecriture.ps1'), [System.Text.Encoding]::UTF8)
$kNew = "Affiche la courbe de précompensation calibrée que l'écriture applique, pour la famille du profil forcé, sinon de l'image (standard, long track ou haute densité) : mesures, courbe ajustée et valeur retenue pour chaque cylindre."
$kMan = "Profil Manuel : la courbe calibrée du lecteur pour la famille de l'image ; le champ --precomp est transmis tel quel. Pour une image FM, GCR, à codage propre ou haute densité non calibrable, c'est une courbe MFM du lecteur, sans objet pour cette image."
$kOld = "Affiche la courbe de précompensation calibrée pour la famille de l'image (standard ou long track) : mesures, courbe ajustée et valeur retenue pour chaque cylindre."
$tNew = $script:I18n.ContainsKey($kNew) -and $script:I18n[$kNew] -like '*standard, long track or high density*'
$tMan = $script:I18n.ContainsKey($kMan) -and $script:I18n[$kMan] -like 'Manual profile:*'
$cNew = $src520.Contains("(T '" + $kNew.Replace("'", "''") + "')"); $cMan = $src520.Contains('(T "' + $kMan + '")')
$oLeft = $script:I18n.ContainsKey($kOld) -or $src520.Contains($kOld.Replace("'", "''"))
"  cle de l infobulle traduite $tNew, appelee $cNew ; cle du profil Manuel traduite $tMan, appelee $cMan ; ancienne cle restante $oLeft"
if ($tNew) { "  anglais : $($script:I18n[$kNew])" }
Chk 'T1' ($tNew -and $tMan -and $cNew -and $cMan -and -not $oLeft) "m5 : infobulle « ... que l ecriture applique, pour la famille du profil force, sinon de l image (standard, long track ou haute densite) ... » et ligne du profil Manuel, appelees par 520 et traduites ; ancienne cle « (standard ou long track) » retiree"

# ================================================================ D. CHANGELOG et wiki
"--- D : CHANGELOG du worktree et pages du wiki ($Wiki)"
$cl = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'), [System.Text.Encoding]::UTF8)
$dNew = @("Avec le profil « Standard 2 us » ou « Long track 1,89 us », il montre la courbe de la famille du profil, celle que l'écriture applique, et non plus celle de l'image. En profil Manuel, il montre la courbe calibrée du lecteur pour la famille de l'image, le champ --precomp étant transmis tel quel ; pour une image FM, GCR, à codage propre ou haute densité non calibrable, c'est une courbe MFM du lecteur, sans objet pour cette image.",
          "Comme pour un flux écrit tel quel, sans format, il est maintenant inactif quand l'écriture n'applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; image FM, GCR ou à codage propre, écrite sans précompensation (sauf avec le profil Manuel) ; en profil Auto, image haute densité non calibrable, écrite avec le profil d'origine.",
          "``Update-CurveButton``, appelé en sortie d'``Update-PrecompForImage`` (case --precomp recochée) et par le gestionnaire de la case --precomp, prend la famille de la décision d'écriture (profil forcé, sinon ``Get-WriteImageFamily``)")
$dOld = @("et ne reste inactif que pour une image à laquelle l'écriture ne transmet pas --precomp", "qui ne grise plus qu'une image à laquelle l'écriture ne transmet pas --precomp")
$dMiss = @($dNew | Where-Object { -not $cl.Contains($_) } | ForEach-Object { Cut $_ 60 }); $dLeft = @($dOld | Where-Object { $cl.Contains($_) })
Chk 'D1' ($dMiss.Count -eq 0 -and $dLeft.Count -eq 0) "B1, m1, m3 : CHANGELOG : entree « Boutons « Courbe » » (profil force, profil Manuel, inactif quand l ecriture n applique aucune courbe calibree, changement annonce) et ligne des developpeurs ; $($dMiss.Count) passage(s) absent(s)$(if ($dMiss.Count) { ' : ' + ($dMiss -join ' | ') }) ; anciens restants : $($dLeft -join ' | ')"
if ($Wiki -and (Test-Path -LiteralPath $Wiki)) {
function Get-WikiText([string]$n) { $p = Join-Path $Wiki $n; if (-not (Test-Path -LiteralPath $p)) { return '' }; return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
$wk = @{ E = (Get-WikiText 'Écriture.md'); P = (Get-WikiText 'Précompensation-et-calibration.md') }
$wNew = @(@('E', "affiche la courbe de précompensation calibrée que l'écriture applique, pour le lecteur choisi dans « Lecteur : » : en profil « Auto », celle de la famille de l'image choisie, standard, long track ou haute densité ; avec « Standard 2 us » ou « Long track 1,89 us », celle de la famille du profil."),
          @('E', "En profil « Manuel », il montre la courbe calibrée du lecteur pour la famille de l'image ; le champ --precomp est transmis tel quel ; pour une image FM"),
          @('E', "Il reste grisé quand l'écriture n'applique aucune courbe calibrée : case « Précompensation (--precomp) : » (« Précomp. tête 0 (--precomp) : » en écriture lente) décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; en profil « Auto », image haute densité non calibrable (voir [Formats et limites](Formats-et-limites#détection-de-la-haute-densité)), écrite avec le profil d'origine."),
          @('P', "la courbe que l'écriture applique, de la famille de l'image choisie dans « Image : » en profil « Auto », de celle du profil avec « Standard 2 us » ou « Long track 1,89 us »."),
          @('P', "En profil « Manuel », il montre la courbe calibrée du lecteur pour la famille de l'image, le champ --precomp étant transmis tel quel ; pour une image FM, GCR, à codage propre ou haute densité non calibrable, c'est une courbe MFM du lecteur, sans objet pour cette image."),
          @('P', "Il est grisé quand l'écriture n'applique aucune courbe calibrée (case « Précompensation (--precomp) : », « Précomp. tête 0 (--precomp) : » en écriture lente, décochée ; flux écrit tel quel, sans format : SCP, RAW… ; image FM, GCR ou à codage propre, hors profil « Manuel » ; image haute densité non calibrable en profil « Auto », écrite avec le profil d'origine)"))
$wOld = @(@('E', 'sans format (SCP, RAW...)'), @('E', "pour la famille de l'image choisie, standard, long track ou haute densité, et pour le lecteur"), @('P', 'sans format, SCP, RAW…'),
          @('P', "« Profil précomp. : » : la courbe de la famille de l'image choisie dans « Image : »."))
$wMiss = @($wNew | Where-Object { -not $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $(Cut $_[1] 70)" })
$wLeft = @($wOld | Where-Object { $wk[$_[0]].Contains($_[1]) } | ForEach-Object { "$($_[0]) : $($_[1])" })
Chk 'D2' ($wk.E -and $wk.P -and $wMiss.Count -eq 0 -and $wLeft.Count -eq 0) "B1, m3, m4 : wiki Ecriture.md et Precompensation-et-calibration.md : profil force, profil Manuel, grisage (case decochee, flux tel quel « sans format : SCP, RAW… », FM/GCR, haute densite non calibrable) ; $($wMiss.Count) absent(s)$(if ($wMiss.Count) { ' : ' + ($wMiss -join ' | ') }) ; anciens restants : $($wLeft -join ' | ')"
} else { "  D2 saute (wiki absent)" }

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-rc6fix1-d : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
