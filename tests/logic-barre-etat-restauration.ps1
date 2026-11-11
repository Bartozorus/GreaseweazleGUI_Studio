param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-rc11) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# 12.10 RC11 (10/11/2026, v1210\rc11\make_rc11_test.py) : copie de v1210\rc10\logic-1210-rc10, qui la remplace dans la
# campagne : R9 a R12 (barre d etat quand gw.exe n a pas pu etre lance : Set-GwLaunchFailedStatus, 110 ; Start-Progress
# reel apres l attente) ; libelles de R3 et R7 (commande gw et echec simules).
# 12.10 RC10 (10/11/2026, v1210\rc10) : remplace logic-1210-rc9 dans la campagne (memes cas E1 a E8, R1, R4, R4b, R5 ;
# cas de la relecture de la RC9 repris de v1210\rc9\revue\revue-rc9.ps1 sur les chemins reels).
#  E  Get-CalibEnvBlock (260) : refus, titre et icone (module d analyse SCP : Warning ; gw.exe : Error), ordre quand les deux
#     manquent ; Test-CalibImage et Start-CrossCalib (270) reels : icone transmise ; refus d occupation, calibration B et
#     « aucun autre lecteur » avant le refus d installation ;
#  R  Enter-RestoreWait, Close-Restore, Fail-Restore, Stop-Restore, Resume-Restore reels et gestionnaire reel de « Annuler »
#     (540) : compteur de pistes et barre effaces, icone neutre, consigne entiere (fr, en) ; « Annuler » pendant l attente :
#     « Pret. », icone neutre ; confirmation de « Continuer » refusee puis « Annuler » : idem ; « Ecraser quand meme » puis
#     echec avant toute commande gw : idem (RC10) ; « Continuer » puis echec apres une commande gw : barre d etat intacte ;
#     « Arreter » inactif pendant l attente (Set-Busy et Get-AppBusy reels).
# Fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans des fichiers de travail puis chargees par
# dot-source (son de Enter-RestoreWait retire) ; controles WinForms reels jamais affiches ; bouchons pour le reste.
# Aucun gw, aucune fenetre, aucun Add-Type, aucune evaluation de texte.
# Attendu NON CONFORME : sur 9c1d1ee (RC10) R9, R10, R12, R13 ; sur 0a06387 (RC9) R1, R7, R9, R10, R12, R13 ; sur fa64535
# (RC8) R1, R2, R4b, R6, R7, R9, R10, R12, R13. (11/11/2026, relecture de la RC11, m2 : compteur rempli avant R9, R13.)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src/modules'
if (-not (Test-Path -LiteralPath (Join-Path $m '260-fn-calib-rapide.ps1'))) { throw "modules introuvables sous $Wt" }
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
function Get-Ast([string]$file) { $tok = $null; $err = $null; return [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tok, [ref]$err) }
$all = @{}; $allAst = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '*.ps1')) {
    foreach ($fn in @((Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))) { $all[$fn.Name] = $fn.Extent.Text; $allAst[$fn.Name] = $fn }
}
# Gestionnaire Click reel de « Annuler » (540)
$ui = Get-Ast (Join-Path $m '540-ui-accueil-restauration-barre.ps1')
$hit = @($ui.FindAll({ param($x) $x -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]$x.Expression -eq '$btnRsCancel' -and [string]$x.Member -eq 'Add_Click' }, $true))
if ($hit.Count -ne 1) { throw "Add_Click de btnRsCancel : $($hit.Count)" }
$cancelBody = $hit[0].Arguments[0].ScriptBlock.Extent.Text.Trim().TrimStart('{').TrimEnd('}')

$want = @('Test-CalibImage', 'Start-CrossCalib', 'Enter-RestoreWait', 'Close-Restore', 'Fail-Restore', 'Stop-Restore', 'Resume-Restore', 'Get-RestoreKeepCyls', 'Start-Progress')
$wantNew = @('Get-CalibEnvBlock', 'Set-GwLaunchFailedStatus')
$snd = '[System.Media.SystemSounds]::Exclamation.Play()'
$ew = [string]$all['Enter-RestoreWait']
$nSnd = ([regex]::Matches($ew, [regex]::Escape($snd))).Count
if ($nSnd -ne 1) { throw "son de Enter-RestoreWait : $nSnd fois" }
$all['Enter-RestoreWait'] = $ew.Replace($snd, '$script:Sound++')
$code = (@($want | ForEach-Object { if (-not $all.ContainsKey($_)) { throw "fonction $_ introuvable" }; $all[$_] }) -join "`r`n`r`n")
$code += "`r`n`r`n" + (@($wantNew | Where-Object { $all.ContainsKey($_) } | ForEach-Object { $all[$_] }) -join "`r`n`r`n")
$code += "`r`n`r`nfunction Invoke-RsCancelClick {`r`n" + $cancelBody + "`r`n}`r`n"
$gen = Join-Path $here 'gen-1210-rc11.ps1'
[System.IO.File]::WriteAllText($gen, $code, (New-Object System.Text.UTF8Encoding($true)))
# Set-Busy et Get-AppBusy reels, charges seulement pour R8 (les cas E simulent l occupation)
foreach ($x in 'Set-Busy', 'Get-AppBusy') { if (-not $all.ContainsKey($x)) { throw "fonction $x introuvable" } }
$gen2 = Join-Path $here 'gen-1210-rc11-busy.ps1'
[System.IO.File]::WriteAllText($gen2, ($all['Set-Busy'] + "`r`n`r`n" + $all['Get-AppBusy'] + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
$hasNew = @($wantNew | Where-Object { $all.ContainsKey($_) })
"source : $Wt ; nouvelles fonctions presentes : $($hasNew.Count) sur $($wantNew.Count) ($($hasNew -join ', '))"

# --- Bouchons ------------------------------------------------------------------------------------------------------
$script:Calls = New-Object System.Collections.Generic.List[string]
$script:Sound = 0
$script:Busy = ''
function Show-AppMessage($t, $c, $b = 'OK', $i = '') { $script:Calls.Add("Show-AppMessage[$c][$i] $t"); return 'OK' }
$script:ConfirmAnswer = $true
function Show-AppConfirm { $script:Calls.Add('Show-AppConfirm'); return $script:ConfirmAnswer }
function Get-AppBusy([switch]$Text) { return $script:Busy }
function Get-CrossCalibTargets($items, $src) { return @($items | Where-Object { $_ -ne $src }) }
function Get-CalibSettingBlock { $script:Calls.Add('Get-CalibSettingBlock'); return 'STOP-SB' }
function Get-CalibImageCheck($Geom = $null) { $script:Calls.Add('Get-CalibImageCheck'); return @{ Ok = $false; Why = 'STOP-IC' } }
function Set-RsStep([int]$i, [string]$state, [string]$detail = '') { $script:Calls.Add("Set-RsStep $i $state"); if ($script:Restore -and $state -eq 'run') { $script:Restore.Cur = $i } }
function Show-Tab($t) { $script:Calls.Add('Show-Tab') }
function Append-Log($t) { $script:Calls.Add("Append-Log $t") }
function Exit-OpOverride([switch]$Keep) { $script:Calls.Add('Exit-OpOverride') }
function Restore-WriteTabState($s) { $script:Calls.Add('Restore-WriteTabState') }
function Save-Config { $script:Calls.Add('Save-Config'); return $true }
function Set-RsLock($b) { $script:Calls.Add("Set-RsLock $b") }
function Update-RsCalib { $script:Calls.Add('Update-RsCalib') }
function Stop-WriteWarmup { }
function Write-RestoreReport([bool]$ok, [string]$verdict) { $script:Calls.Add("Write-RestoreReport $verdict") }
function Show-RestoreResult([bool]$ok, [string]$text, [string]$icon = '') { $script:Calls.Add("Show-RestoreResult $text") }
function Format-CylList($c) { return (@($c) -join ',') }
function Format-TrackList($c) { return (@($c) -join ',') }
function Sort-TrackKeys($c) { return @($c) }
function Start-RestoreProbe { $script:Calls.Add('Start-RestoreProbe'); $script:Restore.Stage = 'probe' }
$script:WriteFails = $false
function Start-RestoreWrite { $script:Calls.Add('Start-RestoreWrite'); $script:Restore.Stage = 'write'; if ($script:WriteFails) { Fail-Restore 4 (T 'l''écriture n''a pas démarré (calibration refusée ou annulée ? voir le journal)') } }
. $gen
function Get-Calls([string]$like) { return @($script:Calls | Where-Object { $_ -like $like }) }
function Get-CallsPre([string]$pre) { return @($script:Calls | Where-Object { ([string]$_).StartsWith($pre, [System.StringComparison]::Ordinal) }) }

# Controles reels, jamais affiches
$status = New-Object System.Windows.Forms.StatusStrip
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $stTrack = New-Object System.Windows.Forms.ToolStripStatusLabel
$stBar = New-Object System.Windows.Forms.ToolStripProgressBar
[void]$status.Items.AddRange(@($stOp, $stTrack, $stBar))
$script:StIcons = @{ idle = New-Object System.Drawing.Bitmap(16, 16); run = New-Object System.Drawing.Bitmap(16, 16); ok = New-Object System.Drawing.Bitmap(16, 16); err = New-Object System.Drawing.Bitmap(16, 16) }
$tabRs = New-Object System.Windows.Forms.TabPage; $tabRs.AutoScroll = $true; $tabRs.Size = New-Object System.Drawing.Size(800, 500)
$pnlRsWait = New-Object System.Windows.Forms.Panel; $pnlRsWait.Size = New-Object System.Drawing.Size(760, 120); $tabRs.Controls.Add($pnlRsWait)
$lblRsWait = New-Object System.Windows.Forms.Label; $lblRsWait.Size = New-Object System.Drawing.Size(740, 60); $pnlRsWait.Controls.Add($lblRsWait)
$btnRsGo = New-Object System.Windows.Forms.Button; $btnRsCancel = New-Object System.Windows.Forms.Button; $btnRsForce = New-Object System.Windows.Forms.Button
$pnlRsWait.Controls.AddRange(@($btnRsGo, $btnRsCancel, $btnRsForce))
$lblRsRules = New-Object System.Windows.Forms.Label; $lblRsNow = New-Object System.Windows.Forms.Label
$cmbDrive = New-Object System.Windows.Forms.ComboBox
$tabs = New-Object System.Windows.Forms.TabControl
$btnStop = New-Object System.Windows.Forms.Button; $btnCfgSave = New-Object System.Windows.Forms.Button; $btnCfgReset = New-Object System.Windows.Forms.Button
$script:CalRedo = $null; $script:OpOverride = $null; $script:GwProc = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null
$script:Detect = $null; $script:AlignLoop = $false; $script:QualPauseBar = $false; $script:FmtDetect = $null; $script:EraseLog = $null
$script:Chain = New-Object System.Collections.Queue; $script:WriteQueue = New-Object System.Collections.Queue
$script:QualView = @{ State = 'idle'; Kind = '' }; $script:AfterCalib = ''; $script:GwCapture = $null

$scpMsg = (T 'Calibration : module d''analyse SCP indisponible (Add-Type).')
$gwOk = $MyInvocation.MyCommand.Path
$gwAbs = Join-Path $here 'gw-absent-rc11\gw.exe'
function Set-Env([bool]$scp, [bool]$gw) { $script:ScpStatsOk = $scp; $script:GwExe = $(if ($gw) { $gwOk } else { $gwAbs }); $script:Calls.Clear(); $script:Busy = ''; $script:CalRedo = $null }
function Set-Drives([string[]]$ids) { $cmbDrive.Items.Clear(); foreach ($x in $ids) { [void]$cmbDrive.Items.Add($x) }; $cmbDrive.Text = $ids[0] }
$gwMsg = (T "gw.exe introuvable : {0}`n`nPlacez ce script dans le même répertoire que gw.exe.") -f "$gwAbs"

# --- E : refus d installation ---------------------------------------------------------------------------------------
$hasEb = [bool](Get-Command Get-CalibEnvBlock -ErrorAction SilentlyContinue)
Set-Env $true $true
Chk 'E1' ($hasEb -and $null -eq (Get-CalibEnvBlock)) "installation complete : aucun refus"
Set-Env $false $true; $e = if ($hasEb) { Get-CalibEnvBlock } else { $null }
Chk 'E2' ($e -and [string]$e.Why -eq $scpMsg -and [string]$e.Title -eq (T 'Calibration precomp') -and [string]$e.Icon -eq 'Warning') "module d analyse SCP indisponible : message, titre « Calibration precomp », icone Warning"
Set-Env $true $false; $e = if ($hasEb) { Get-CalibEnvBlock } else { $null }
Chk 'E3' ($e -and [string]$e.Why -eq $gwMsg -and [string]$e.Title -eq (T 'Erreur') -and [string]$e.Icon -eq 'Error') "gw.exe introuvable : message avec le chemin, titre « Erreur », icone Error"
Set-Env $false $false; $e = if ($hasEb) { Get-CalibEnvBlock } else { $null }
Chk 'E4' ($e -and [string]$e.Why -eq $scpMsg) "les deux manquent : refus du module d analyse SCP d abord (ordre de Test-CalibImage d avant)"
Set-Env $false $true; $t = Test-CalibImage
$ok5a = ($null -eq $t -and (Get-CallsPre "Show-AppMessage[$(T 'Calibration precomp')][Warning] $scpMsg").Count -eq 1 -and @(Get-Calls 'Show-AppMessage*').Count -eq 1 -and (Get-Calls 'Get-CalibImageCheck').Count -eq 0)
Set-Env $true $false; $t = Test-CalibImage
$ok5b = ($null -eq $t -and (Get-CallsPre "Show-AppMessage[$(T 'Erreur')][Error] $gwMsg").Count -eq 1 -and @(Get-Calls 'Show-AppMessage*').Count -eq 1 -and (Get-Calls 'Get-CalibImageCheck').Count -eq 0)
Chk 'E5' ($ok5a -and $ok5b) "Test-CalibImage : titre et icone du refus transmis (Warning, Error), image non controlee"
Set-Drives @('0', 'A'); Set-Env $false $false; $script:Busy = 'écriture'
$r = Start-CrossCalib
Chk 'E6' (-not $r.Started -and $r.Why -eq 'écriture' -and @(Get-Calls 'Show-AppMessage*').Count -eq 1 -and @(Get-Calls "Show-AppMessage*$scpMsg").Count -eq 0) "Start-CrossCalib, operation en cours et installation incomplete : refus d occupation seul ($($script:Calls -join ' | '))"
Set-Drives @('0'); Set-Env $false $false
$r = Start-CrossCalib
Chk 'E7' (-not $r.Started -and $r.Why -eq (T 'aucun autre lecteur') -and @(Get-Calls 'Show-AppMessage*').Count -eq 1) "Start-CrossCalib, aucun autre lecteur et installation incomplete : refus « aucun autre lecteur » seul ($($script:Calls -join ' | '))"
Set-Drives @('0', 'A'); Set-Env $false $true
$r = Start-CrossCalib; $okA = (-not $r.Started -and $r.Why -eq $scpMsg -and (Get-CallsPre "Show-AppMessage[$(T 'Calibration precomp')][Warning] $scpMsg").Count -eq 1 -and (Get-Calls 'Get-CalibSettingBlock').Count -eq 0)
Set-Env $true $false
$r = Start-CrossCalib; $okB = (-not $r.Started -and $r.Why -eq $gwMsg -and (Get-CallsPre "Show-AppMessage[$(T 'Erreur')][Error] $gwMsg").Count -eq 1 -and (Get-Calls 'Get-CalibSettingBlock').Count -eq 0)
Set-Env $true $true
$r = Start-CrossCalib; $okC = (-not $r.Started -and $r.Why -eq 'STOP-SB' -and (Get-Calls 'Get-CalibSettingBlock').Count -eq 1)
Chk 'E8' ($okA -and $okB -and $okC) "Start-CrossCalib : titre et icone du refus d installation (Warning, Error), avant Get-CalibSettingBlock ; installation complete : suite jusqu a Get-CalibSettingBlock"
Set-Drives @('0', 'A'); Set-Env $false $false; $script:CalRedo = @{ State = 'wait' }
$r = Start-CrossCalib
Chk 'E9' (-not $r.Started -and $r.Why -eq (T 'calibration B') -and @(Get-Calls 'Show-AppMessage*').Count -eq 1 -and @(Get-Calls "Show-AppMessage*$scpMsg").Count -eq 0) "Start-CrossCalib, calibration B en cours et installation incomplete : refus de la calibration B seul ($($script:Calls -join ' | '))"
$script:CalRedo = $null

# --- R : barre d etat de la restauration -----------------------------------------------------------------------------
$waitFr = (T 'Restauration : changez de disquette, puis cliquez sur « Continuer ».')
$ready = (T 'Prêt.')
function New-Rs([string]$mode = 'sector') {
    $script:Restore = @{ Drive = '0'; SwapBack = $false; Mode = $mode; Read = $null; Override = $false; Stage = 'read'; Waiting = $false
                         Saved = $null; Cur = 1; Finger = $null; OnOriginal = $false; Steps = @{}; Idle = (Get-Date); Orig = 'orig.adf' }
}
function Enter-Wait([switch]$Override) {
    $stOp.Text = 'Lecture terminé(e)  -  21:00:00'; $stOp.Image = $script:StIcons.ok
    $stTrack.Text = 'piste 79.1  (160/160, 100 %)'; $stBar.Visible = $true
    if ($Override) { $script:Restore.Override = $true }
    Enter-RestoreWait ''
}
function Test-Idle { return ($stOp.Text -eq $ready -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.idle)) }

New-Rs; Enter-Wait
Chk 'R1' ($stTrack.Text -eq '' -and -not $stBar.Available -and $stOp.Text -eq $waitFr -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.idle) -and $script:Sound -eq 1 -and $script:Restore.Waiting) "attente de la destination : compteur vide, barre masquee, icone neutre, consigne « $($stOp.Text) »"
$script:Calls.Clear()
Invoke-RsCancelClick
Chk 'R2' ((Test-Idle) -and $stTrack.Text -eq '' -and -not $stBar.Available -and $null -eq $script:Restore -and (Get-Calls "Show-RestoreResult*$(T 'annulée par l''utilisateur')*").Count -eq 1 -and (Get-Calls 'Set-RsLock False').Count -eq 1) "« Annuler » pendant l attente (gestionnaire reel, Stop-Restore, Fail-Restore, Close-Restore) : barre d etat « $($stOp.Text) », icone neutre"
$script:Lang = 'en'
New-Rs; Enter-Wait
$enWait = [string]$stOp.Text
Invoke-RsCancelClick
$enIdle = [string]$stOp.Text
$script:Lang = 'fr'
Chk 'R4' ($enWait -eq 'Restore: swap disks, then click "Continue".') "consigne en anglais : « $enWait »"
Chk 'R4b' ($enIdle -eq 'Ready.') "« Annuler » pendant l attente, en anglais : « $enIdle »"
New-Rs; Enter-Wait
Resume-Restore $false
$wf = (-not $script:Restore.Waiting -and (Get-Calls 'Start-RestoreProbe').Count -ge 1)
$stOp.Text = 'Lecture terminé(e)  -  21:05:00'; $stOp.Image = $script:StIcons.ok
Stop-Restore 'essai'
Chk 'R3' ($wf -and $stOp.Text -eq 'Lecture terminé(e)  -  21:05:00' -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.ok)) "« Continuer » (sonde, commande gw simulee) puis echec : barre d etat de la sonde intacte (« $($stOp.Text) »)"
New-Rs 'flux'; Enter-Wait
$script:ConfirmAnswer = $false
Resume-Restore $false
$keep = ($script:Restore -and $script:Restore.Waiting -and $stOp.Text -eq $waitFr)
$script:ConfirmAnswer = $true
Invoke-RsCancelClick
Chk 'R6' ($keep -and (Test-Idle)) "« Continuer » puis confirmation refusee : attente gardee ($keep) ; puis « Annuler » : « $($stOp.Text) »"
New-Rs 'sector'; Enter-Wait -Override
$script:WriteFails = $true
Resume-Restore $true
$script:WriteFails = $false
Chk 'R7' ($null -eq $script:Restore -and (Test-Idle)) "« Ecraser quand meme » puis echec simule avant toute commande gw (comme une fenetre « Calibration precomp » annulee) : « $($stOp.Text) »"
$fr = $allAst['Fail-Restore']
$callsFr = @($fr.Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Close-Restore' }, $true)).Count
$sr = $allAst['Stop-Restore']
$callsSr = @($sr.Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Fail-Restore' }, $true)).Count
Chk 'R5' ($callsFr -eq 1 -and $callsSr -eq 1) "Stop-Restore appelle Fail-Restore ($callsSr), qui appelle Close-Restore ($callsFr) : toute fin de restauration passe par Close-Restore"
# R9 a R12 : gw.exe n a pas pu etre lance (Process.Start en echec apres Start-Progress, catch de Start-Gw)
$hasLf = [bool](Get-Command Set-GwLaunchFailedStatus -ErrorAction SilentlyContinue)
$lfFr = ''; $lfEn = ''; $okLf = $false
if ($hasLf) {
    $script:Restore = $null
    Start-Progress (T 'Lecture'); $stTrack.Text = 'piste 3.0  (7/160, 4 %)'
    Set-GwLaunchFailedStatus
    $lfFr = [string]$stOp.Text
    $okLf = ($lfFr -match ('^' + [regex]::Escape((T 'Lecture') + " : gw n'a pas pu être lancé, voir le journal  -  ") + '\d\d:\d\d:\d\d$') -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.err) -and $stTrack.Text -eq '' -and -not $stBar.Available -and [string]$stBar.Style -eq 'Continuous')
    $script:Lang = 'en'
    Start-Progress (T 'Lecture'); $stTrack.Text = 'track 3.0  (7/160, 4 %)'; Set-GwLaunchFailedStatus; $lfEn = [string]$stOp.Text
    $okLf = $okLf -and $stTrack.Text -eq ''
    $script:Lang = 'fr'
}
Chk 'R9' ($okLf -and $lfEn -match '^Read: gw could not be started, see the log  -  \d\d:\d\d:\d\d$') "Set-GwLaunchFailedStatus : « $lfFr » / « $lfEn », icone err, compteur vide, barre masquee et arretee"
$sg = $allAst['Start-Gw']
$try = @($sg.Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.TryStatementAst] }, $true) | Where-Object { $_.Body.Extent.Text.Contains('$p.Start()') })
$seq = @()
if ($try.Count -eq 1 -and $try[0].CatchClauses.Count -eq 1) {
    $seq = @($try[0].CatchClauses[0].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -in 'Reset-GwSequence', 'Set-GwLaunchFailedStatus', 'Set-Busy' })
}
Chk 'R10' (($seq -join ',') -eq 'Reset-GwSequence,Set-GwLaunchFailedStatus,Set-Busy') "catch du lancement de Start-Gw : Reset-GwSequence, puis Set-GwLaunchFailedStatus, puis Set-Busy ($($seq -join ', '))"
# R13 (relecture de la RC11, m2) : Set-GwLaunchFailedStatus appelee une seule fois dans tout le code des modules (fonctions
# et gestionnaires), dans le catch du lancement de Start-Gw (ni « gw.exe introuvable », ni « gw deja en cours », ni ailleurs)
$nLf = 0
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '*.ps1')) { $nLf += @((Get-Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Set-GwLaunchFailedStatus' }, $true)).Count }
Chk 'R13' ($nLf -eq 1 -and ($seq -contains 'Set-GwLaunchFailedStatus')) "Set-GwLaunchFailedStatus appelee une seule fois dans les modules, dans le catch du lancement de Start-Gw ($nLf)"
New-Rs; Enter-Wait
Start-Progress (T 'Lecture')
Chk 'R11' ($stOp.Text -eq ((T "{0} en cours...") -f (T 'Lecture')) -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.run) -and $stTrack.Text -eq '' -and $stBar.Available) "commande gw apres l attente (Start-Progress reel) : « $($stOp.Text) », icone run, barre visible"
$script:Restore.Waiting = $false
Stop-Restore (T 'gw n''a pas pu être lancé')
$afterClose = [string]$stOp.Text
if ($hasLf) { Set-GwLaunchFailedStatus }
Chk 'R12' ($hasLf -and $afterClose -eq ((T "{0} en cours...") -f (T 'Lecture')) -and [string]$stOp.Text -match "gw n'a pas pu être lancé, voir le journal" -and [object]::ReferenceEquals($stOp.Image, $script:StIcons.err)) "restauration, gw non lance apres « Continuer » : Close-Restore laisse la barre (« $afterClose »), puis Set-GwLaunchFailedStatus : « $($stOp.Text) »"
. $gen2
New-Rs; Enter-Wait
$btnStop.Enabled = $true
Set-Busy $false
Chk 'R8' (-not $btnStop.Enabled -and [string](Get-AppBusy) -eq 'restore') "« Arreter » inactif pendant l attente (Set-Busy et Get-AppBusy reels : « $(Get-AppBusy) », btnStop.Enabled $($btnStop.Enabled)) : seule « Annuler » la termine"

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-1210-rc11 : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
