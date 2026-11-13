param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [string]$Before = '')
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L8) : progression par piste, lot A. Une source, trois niveaux (110) : la ligne de gw (Get-GwLineInfo), la
# commande (Update-Progress tient l etat, Show-GwProgress peint la barre d etat), le plan d une etape de plusieurs
# commandes (New-ProgPlan, Get-ProgPlanFrac, lu par Update-CalibProgress a la place du temps ecoule) ; barre d etat en
# fin de sequence (Set-SeqEnd, Update-SeqEnd).
#  L  ligne : chaque format de gw 1.23 (annonces, lignes de piste, lignes sans effet), fonction pure ;
#  U  poids d une commande (Get-GwCmdUnits) et table $script:ProgCost reelle (040) ;
#  P  plan d une etape : $null sans plan ou sans commande recue, fraction croissante, credit a la fin d une commande,
#     commande non prevue, plan faux (plus de pistes vues que prevu), temps borne avant la premiere ligne de piste ;
#  S  barre d etat pendant une commande : pistes terminees, essais, conversion, regle de fin (instruction reelle du
#     minuteur, 600), un seul affichage par lot de lignes (Read-GwOutput reel), jamais de recul, echec ;
#  C  barre de la calibration (Update-CalibProgress reel) : sans plan valeurs de la 12.10, avec plan fraction du plan,
#     « effacement », conditionnement, attentes et prechauffage inchanges, passe comptee ;
#  E  fin de sequence : restauration (Finish-Restore, Fail-Restore, Show-RestoreResult, Close-Restore reels), calibration
#     (Set-HomeProgDone reel), controle apres ecriture (Complete-WriteCheck reel), recherche des lecteurs
#     (Complete-DriveDetect reel), echec de la derniere commande, regle generale ; corrections de relecture : E23, E24
#     restauration arretee pendant la calibration de son lecteur (Stop-Restore puis la vraie Stop-PrecompCalib, ordre du
#     minuteur et du bouton Arreter : « Restauration echouee » garde, Set-SeqEnd -IfNone) ; E25 limite connue de la
#     recherche des lecteurs interrompue sans lecteur trouve (vraie Complete-DriveProbe) ;
#  B  affichage seulement (arbre syntaxique de tous les modules) : lecteurs des variables de la progression, appelants de
#     ses fonctions, appels dont le resultat n est pas lu, commandes de Start-Gw et des passes non touchees ;
#  I  textes : entrees anglaises des cles nouvelles ; D CHANGELOG et README (D4 : l exemple de compteur du CHANGELOG
#     est rejoue par les fonctions reelles).
# Avec -Before <copie de la source de la 12.10> (aucune dans le depot) : cas Q, equivalence avec la 12.10 de l etat lu
# par la regle de fin (ProgTotal, ProgSeen), du compteur d une lecture et de la barre de calibration sans plan.
# Fonctions reelles extraites des modules par l arbre syntaxique, ecrites dans un fichier de travail puis chargees par
# dot-source ; controles WinForms reels jamais affiches ; bouchons pour le reste. Lignes de gw ecrites a la main d apres
# les formats de gw 1.23 : aucune copie de journal. Aucun gw, aucune fenetre, aucune compilation.
# Non couvert : le rythme reel de la barre sur materiel (poids releves dans les journaux d un seul utilisateur), l instant
# ou gw imprime une ligne de piste, le cout d affichage d une fenetre visible, le minuteur principal execute en entier.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Import-TestWinForms
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$m = Join-Path $Wt 'src\modules'
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' -File | Sort-Object Name)) { . $f.FullName }
$script:Lang = 'fr'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
function Get-Ast([string]$file) {
    $tk = $null; $er = $null
    $a = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $file : $(@($er)[0].Message)" }
    return $a
}
function Num([double]$x, [string]$f = '0.####') { return $x.ToString($f, $inv) }
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$tVar = [System.Management.Automation.Language.VariableExpressionAst]
$tMem = [System.Management.Automation.Language.MemberExpressionAst]
$tStr = [System.Management.Automation.Language.StringConstantExpressionAst]
$tPipe = [System.Management.Automation.Language.PipelineAst]
$tBlock = [System.Management.Automation.Language.StatementBlockAst]
$tNamed = [System.Management.Automation.Language.NamedBlockAst]

# --- Fonctions des modules -----------------------------------------------------------------------------------------
function Get-ModuleSet([string]$dir) {
    # Arbres des modules d un dossier, fonctions de premier niveau (texte, arbre, module)
    $s = @{ Ast = @{}; Text = @{}; Fn = @{}; Mod = @{} }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File | Sort-Object Name)) {
        $a = Get-Ast $f.FullName; $s.Ast[$f.Name] = $a
        foreach ($fd in @($a.FindAll({ param($x) $x -is $tFn }, $false))) { $s.Text[$fd.Name] = [string]$fd.Extent.Text; $s.Fn[$fd.Name] = $fd; $s.Mod[$fd.Name] = $f.Name }
    }
    return $s
}
$src = Get-ModuleSet $m
$want = @('Get-SpecCount', 'Start-Progress', 'Update-Progress', 'Stop-Progress', 'Set-GwLaunchFailedStatus', 'Drain-GwReader', 'Read-GwOutput', 'Get-GwEndRule', 'Get-AppBusy',
          'Get-GwLineInfo', 'Get-GwProgress', 'Show-GwProgress', 'Get-EndRuleTotal', 'Get-GwCmdUnits', 'New-ProgPlan', 'Get-ProgPlanFrac', 'Set-SeqEnd', 'Clear-SeqEnd', 'Update-SeqEnd', 'Complete-DriveDetect',
          'Update-CalibProgress', 'Format-CalDuration', 'Get-WarmupLeft', 'Get-CalibDoneTitle', 'Set-HomeProgDone', 'Get-ContentWriteArgs', 'Format-CylRanges',
          'Enter-RestoreWait', 'Close-Restore', 'Finish-Restore', 'Fail-Restore', 'Stop-Restore', 'Show-RestoreResult', 'Complete-WriteCheck',
          'Stop-PrecompCalib', 'Complete-DriveProbe')   # corrections de relecture : cas E23 a E25
$miss = @($want | Where-Object { -not $src.Text.ContainsKey($_) })
if ($miss.Count) { throw "fonctions introuvables dans les modules : $($miss -join ', ')" }
$parts = New-Object System.Collections.Generic.List[string]
# Son de Enter-RestoreWait retire (aucun son pendant les tests), comme dans logic-barre-etat-restauration
$snd = '[System.Media.SystemSounds]::Exclamation.Play()'
if (([regex]::Matches([string]$src.Text['Enter-RestoreWait'], [regex]::Escape($snd))).Count -ne 1) { throw 'son de Enter-RestoreWait introuvable' }
foreach ($n in $want) { $parts.Add($(if ($n -eq 'Enter-RestoreWait') { ([string]$src.Text[$n]).Replace($snd, '$script:Sound++') } else { $src.Text[$n] })) }
# Etat initial reel de la progression (040) : affectations du niveau du script, rejouees avant chaque scenario
$stState = @($src.Ast['040-etat-formats.ps1'].EndBlock.Statements | Where-Object { $_ -is $tAsg -and $_.Left.Extent.Text -match '^\$script:(Prog[A-Za-z]+|SeqEnd|SeqCmds)$' } | ForEach-Object { [string]$_.Extent.Text })
$parts.Add("function Reset-ProgState {`r`n" + ($stState -join "`r`n") + "`r`n}")
# Instruction reelle du minuteur principal (600) qui applique la regle de fin d une commande
$endAsg = @($src.Ast['600-minuteur-demarrage.ps1'].FindAll({ param($x) $x -is $tAsg -and $x.Left.Extent.Text -eq '$gwEnd' }, $true))
if ($endAsg.Count -ne 1) { throw "instruction de la regle de fin dans le minuteur : $($endAsg.Count)" }
$parts.Add("function Invoke-TimerEndRule([int]`$code, [bool]`$soft, [bool]`$eraseFailed) {`r`n" + [string]$endAsg[0].Extent.Text + "`r`nreturn `$gwEnd`r`n}")
# Instruction reelle de New-ContentPass (276) qui pose le plan d une passe de la mesure sur l image
$planStmt = @($src.Fn['New-ContentPass'].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'New-ProgPlan' }, $true))
if ($planStmt.Count -ne 1) { throw "appel de New-ProgPlan dans New-ContentPass : $($planStmt.Count)" }
$parts.Add("function Invoke-ContentPlanStmt(`$cal, `$ct) {`r`n" + [string]$planStmt[0].Extent.Text + "`r`n}")
$gen = Join-Path $here 'gen-progression.ps1'
[System.IO.File]::WriteAllText($gen, (($parts -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

# --- Bouchons ------------------------------------------------------------------------------------------------------
$script:Calls = New-Object System.Collections.Generic.List[string]
function Append-Log($t) { $script:Calls.Add("Append-Log $t") }
function Save-Config { return $true }
function Exit-OpOverride([switch]$Keep) { }
function Restore-WriteTabState($s) { }
function Set-RsLock($b) { }
function Update-RsCalib { }
function Stop-WriteWarmup { }
function Write-RestoreReport([bool]$ok, [string]$verdict) { }
function Set-RsStep([int]$i, [string]$state, [string]$detail = '') { }
function Format-CylList($c) { return (@($c) -join ',') }
function Format-TrackList($c) { return (@($c) -join ', ') }
function Sort-TrackKeys($c) { return @($c | Sort-Object) }
function Show-WriteCheckTable($rep) { }
function Set-QualityCheckState($lvl, $txt, $short, $n) { }
function Set-WCalVerdict($txt, $icon) { }
function Exit-CheckTab { }
function Invoke-RestoreNext { $script:Calls.Add('Invoke-RestoreNext') }
function Get-FamilyCurves($f, $s) { return @() }
function Set-Combo($c, $v) { }
function Get-GwVerifyStop($lines) { return $null }
function Get-CommonArgs { return @('--drive=A') }
function Get-WriteFormatArgs { return @() }
function Get-BracketSpec($sel) { return '0=100' }
function Show-Tab($t) { }
# Corrections de relecture : bouchons de la vraie Stop-PrecompCalib (aucune passe de nouvel essai a retablir, borne et
# JSON compagnon sans objet) et de la vraie Complete-DriveProbe (lecteur suivant de la recherche)
function Restore-CalibRetestPre($cal) { return $false }
function Reset-DiskHardNs { }
function Save-ContentCompanion($cal, $state) { }
function Invoke-DriveProbe { $script:Calls.Add('Invoke-DriveProbe') }
$script:Sound = 0
. $gen

# --- Controles reels, jamais affiches ------------------------------------------------------------------------------
$status = New-Object System.Windows.Forms.StatusStrip
$stOp = New-Object System.Windows.Forms.ToolStripStatusLabel; $stTrack = New-Object System.Windows.Forms.ToolStripStatusLabel
$stBar = New-Object System.Windows.Forms.ToolStripProgressBar
[void]$status.Items.AddRange(@($stOp, $stTrack, $stBar))
$script:StIcons = @{ idle = New-Object System.Drawing.Bitmap(16, 16); run = New-Object System.Drawing.Bitmap(16, 16); ok = New-Object System.Drawing.Bitmap(16, 16); err = New-Object System.Drawing.Bitmap(16, 16) }
$pbWCal = New-Object System.Windows.Forms.ProgressBar; $lblWCal = New-Object System.Windows.Forms.Label
$tabRs = New-Object System.Windows.Forms.TabPage; $tabRs.Size = New-Object System.Drawing.Size(800, 500)
$pnlRsWait = New-Object System.Windows.Forms.Panel; $lblRsResult = New-Object System.Windows.Forms.Label
$lblRsNow = New-Object System.Windows.Forms.Label; $lblRsRules = New-Object System.Windows.Forms.Label
$tabRs.Controls.AddRange(@($pnlRsWait, $lblRsResult, $lblRsNow, $lblRsRules))
$lblRsWait = New-Object System.Windows.Forms.Label; $btnRsGo = New-Object System.Windows.Forms.Button; $btnRsCancel = New-Object System.Windows.Forms.Button; $btnRsForce = New-Object System.Windows.Forms.Button
$pnlRsWait.Controls.AddRange(@($lblRsWait, $btnRsGo, $btnRsCancel, $btnRsForce))
$cmbDrive = New-Object System.Windows.Forms.ComboBox
$script:Theme = @{ WarnInk = [System.Drawing.Color]::FromArgb(138, 90, 0) }
$script:NPaint = 0
$stTrack.add_TextChanged({ $script:NPaint++ })

function Reset-All {
    # Etat initial reel de la progression, application au repos, barre d etat du demarrage
    Reset-ProgState
    $script:GwStart = Get-Date; $script:GwLines = 0; $script:OutQueue = $null; $script:OutPending = ''
    $script:OutStdoutReader = $null; $script:OutStderrReader = $null; $script:OutStdoutTask = $null; $script:OutStderrTask = $null
    $script:CleanRun = $null; $script:GwCapture = $null; $script:Detect = $null; $script:DetectNone = $false
    $script:GwIsWrite = $false; $script:GwIsErase = $false; $script:GwCmdFailed = $false; $script:GwWriteSummary = $false; $script:GwVerifyFail = $null
    $script:EraseLog = $null; $script:WriteRetries = @{}; $script:WriteTracks = @{}
    $script:Restore = $null; $script:Cal = $null; $script:Rep = $null; $script:WriteWarm = $null; $script:GwProc = $null; $script:AlignLoop = $false
    $script:Chain = New-Object System.Collections.Queue; $script:WriteQueue = New-Object System.Collections.Queue
    $script:OpOverride = $null; $script:AfterCalib = ''; $script:FmtDetect = $null; $script:LastCheck = $null; $script:RsResultIcon = $null; $script:HomeProgDone = $null
    $script:Lang = 'fr'; $script:Calls.Clear()
    $stOp.Text = (T 'Prêt.'); $stOp.Image = $script:StIcons.idle; $stTrack.Text = ''
    $stBar.Style = 'Continuous'; $stBar.Minimum = 0; $stBar.Maximum = 100; $stBar.Value = 0; $stBar.Visible = $false
    $pbWCal.Value = 0; $lblWCal.Text = ''
    $script:NPaint = 0
}
function New-TrackLines([string]$op, [int]$c0, [int]$c1, [int[]]$heads) {
    # Lignes de piste factices, dans l ordre de gw (cylindre, puis tete). 'pre' : ecriture avec --pre-erase (deux lignes)
    $o = New-Object System.Collections.Generic.List[string]
    for ($c = $c0; $c -le $c1; $c++) {
        foreach ($h in $heads) {
            if ($op -eq 'erase') { $o.Add("T$c.${h}: Erasing Track") }
            elseif ($op -eq 'write') { $o.Add("T$c.${h}: Writing Track (Flux: 199.9ms period, 219.8 ms total, Terminate at index)") }
            elseif ($op -eq 'pre') { $o.Add("T$c.${h}: Erasing Track"); $o.Add("T$c.${h}: Writing Track (Flux: 199.9ms period, 199.9 ms total, Write all)") }
            elseif ($op -eq 'conv') { $o.Add("T$c.${h}: AmigaDOS (11/11 sectors) from Bitcells (100150 bits)") }
            else { $o.Add("T$c.${h}: Raw Flux (128066 flux in 683.09ms)") }
        }
    }
    return ,$o.ToArray()
}
function Push-Lines([string[]]$lines) { foreach ($l in $lines) { Update-Progress $l } }
function Push-Batch([string[]]$lines) {
    # Un lot de lignes par la vraie Read-GwOutput (file de sortie de gw, lecteurs de flux absents)
    $script:OutQueue = New-Object System.Collections.Queue
    foreach ($l in $lines) { $script:OutQueue.Enqueue($l) }
    Read-GwOutput $false
}
function Test-Icon([string]$name) { return [object]::ReferenceEquals($stOp.Image, $script:StIcons[$name]) }
function Get-Bar { return "$([string]$stBar.Style) $($stBar.Value)/$($stBar.Maximum)" }
$rxTime = '  -  \d\d:\d\d:\d\d$'
"logic-progression : $Wt ; $($want.Count) fonctions reelles, $($stState.Count) variables d etat (040) ; PowerShell $($PSVersionTable.PSVersion)$(if ($Before) { ' ; source d avant fournie (-Before)' })"

# ================================================================ L. la ligne
'--- L. Get-GwLineInfo : une ligne de gw 1.23'
function Test-Line([string]$line, $exp) {
    $i = Get-GwLineInfo $line
    if ($null -eq $exp) { return ($null -eq $i) }
    if ($null -eq $i -or $i.Count -ne $exp.Count) { return $false }
    foreach ($k in @($exp.Keys)) { if ([string]$i[$k] -cne [string]$exp[$k]) { return $false } }
    return $true
}
function LHead([string]$verb, [int]$total) { return @{ Kind = 'head'; Verb = $verb; Total = $total } }
function LTrack([string]$key, [string]$op, [string]$retry = '') { return @{ Kind = 'track'; Key = $key; Op = $op; Retry = $retry } }
Reset-All
$lc = @(
    @('Reading c=0-81:h=0-1 revs=3', (LHead 'Reading' 164), 'annonce d une lecture : 164 pistes'),
    @('Writing c=69-81:h=0', (LHead 'Writing' 13), 'annonce d une ecriture : 13 pistes'),
    @('Erasing c=0-4,10-14:h=0-1, revs=1', (LHead 'Erasing' 20), 'annonce d un effacement, deux plages : 20 pistes'),
    @('Converting c=0-79:h=0-1 -> c=0-79:h=0-1', (LHead 'Converting' 160), 'annonce d une conversion : 160 pistes'),
    @('Reading c=0-39:h=0-1:step=2 revs=3', (LHead 'Reading' 80), 'annonce avec :step=2 : 80 pistes'),
    @('Writing c=5:h=1', (LHead 'Writing' 1), 'annonce d une seule piste'),
    @('T2.0: Raw Flux (128066 flux in 683.09ms)', (LTrack '2.0' 'read'), 'piste lue en flux'),
    @('T0.0: AmigaDOS (11/11 sectors) from Raw Flux (51078 flux in 200.21ms)', (LTrack '0.0' 'read'), 'piste lue et decodee'),
    @('T40.1: AmigaDOS (9/11 sectors) from Raw Flux (50000 flux in 200.10ms) (Retry #1.1)', (LTrack '40.1' 'read' '1'), 'lecture decodee, essai 1 de la serie 1'),
    @('T10.1: Raw Flux (60012 flux in 201.02ms) (Retry #2)', (LTrack '10.1' 'read' '2'), 'lecture, essai 2'),
    @('T79.0: Giving up: 11 sectors missing', (LTrack '79.0' 'read'), 'lecture abandonnee'),
    @('T0.0: IBM Empty from Raw Flux (0 flux in 199.90ms)', (LTrack '0.0' 'read'), 'piste vide'),
    @('T2.0: Writing Track (Flux: 199.9ms period, 219.8 ms total, Terminate at index)', (LTrack '2.0' 'write'), 'ecriture, « Terminate at index »'),
    @('T2.1: Writing Track (Flux: 199.9ms period, 199.9 ms total, Write all)', (LTrack '2.1' 'write'), 'ecriture, « Write all »'),
    @('T77.0: Writing Track (Verify Failure: Retry #3)', (LTrack '77.0' 'write' '3'), 'ecriture, essai 3 apres un echec de verification'),
    @('T2.0: Erasing Track', (LTrack '2.0' 'erase'), 'effacement'),
    @('T1.0 -> Drive 2.0: Writing Track (Flux: 199.9ms period, 219.8 ms total, Terminate at index)', (LTrack '1.0' 'write'), 'piste renumerotee a l ecriture : cle de la piste de l image'),
    @('T1.1 <- Drive 2.1: Raw Flux (128066 flux in 683.09ms)', (LTrack '1.1' 'read'), 'piste renumerotee a la lecture'),
    @("T82.0: WARNING: Out of range for format 'amiga.amigados': Track skipped", (LTrack '82.0' 'read'), 'piste hors format, que gw n ecrit pas : comptee comme en 12.10'),
    @('T0.0: AmigaDOS (11/11 sectors) from Bitcells (100150 bits)', (LTrack '0.0' 'read'), 'piste convertie'),
    @('All tracks verified', $null, 'bilan d une ecriture'),
    @('No tracks verified (Reason: Verify disabled)', $null, 'bilan sans verification'),
    @('Precomp MFM, 0-39:140ns, 40-79:125ns', $null, 'ligne de la precompensation'),
    @('IPF Image File: image.ipf', $null, 'bandeau d une image'),
    @('** FATAL ERROR:', $null, 'erreur fatale'),
    @('Failed to verify Track 69.1', $null, 'piste refusee a la verification'),
    @('Command Failed: GetFluxStatus: No Index', $null, 'commande en echec'),
    @('Cyl-> 0         1         2         3', $null, 'grille de synthese (C sans annonce)'),
    @('Pass 0: 0 10 20 30 40', $null, 'passe de nettoyage'),
    @('Rate: 300.000 rpm ; Period: 200.000 ms', $null, 'mesure de vitesse (R sans annonce)'),
    @('Track 3.0: No Index', $null, 'ligne « Track », sans numero colle au T'),
    @('T12.0 sans deux-points', $null, 'ligne de piste sans deux-points'),
    @('Writing Track', $null, 'W sans jeu de pistes'),
    @('Erasing c=:h=', $null, 'annonce sans pistes lisibles'),
    @('', $null, 'ligne vide'),
    @('T1', $null, 'ligne trop courte')
)
$iL = 0
foreach ($c in $lc) { $iL++; Chk "L$iL" (Test-Line ([string]$c[0]) $c[1]) "$($c[2]) : « $($c[0]) »" }
$fnL = $src.Fn['Get-GwLineInfo']
$vL = @($fnL.Body.FindAll({ param($x) $x -is $tVar }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Sort-Object -Unique)
$cL = @($fnL.Body.FindAll({ param($x) $x -is $tCmd }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Sort-Object -Unique)
$stateL = "$($script:ProgTotal)|$($script:ProgKey)|$($script:ProgDirty)|$($script:NPaint)|$($stTrack.Text)"
Chk 'L-pure' (@($vL | Where-Object { $_ -match '^script:|^global:|^st|^pb|^lbl' }).Count -eq 0 -and ($cL -join ',') -eq 'Get-SpecCount' -and $stateL -eq '0||False|0|') "fonction pure : aucune variable d etat ni controle (variables : $($vL -join ', ')), seule commande Get-SpecCount, etat et barre d etat intacts apres les $iL lignes ($stateL)"

# ================================================================ U. le poids d une commande
'--- U. Get-GwCmdUnits : poids d une commande dans un plan'
function Test-Units($u, [double]$fixed, [double]$per, [int]$tracks, [double]$units) {
    return ([math]::Abs([double]$u.Fixed - $fixed) -lt 1e-9 -and [math]::Abs([double]$u.Per - $per) -lt 1e-9 -and [int]$u.Tracks -eq $tracks -and [math]::Abs([double]$u.Units - $units) -lt 1e-9)
}
function U-Txt($u) { return "fixe $(Num $u.Fixed), par piste $(Num $u.Per), pistes $($u.Tracks), poids $(Num $u.Units)" }
$pc = $script:ProgCost
Chk 'U0' ($pc.Count -eq 8 -and [double]$pc.Fixed -eq 5.0 -and [double]$pc.Erase -eq 0.23 -and [double]$pc.Write -eq 0.40 -and [double]$pc.PreErase -eq 0.21 -and [double]$pc.Verify -eq 0.58 -and [double]$pc.ReadBase -eq 0.2 -and [double]$pc.ReadRev -eq 0.2 -and [double]$pc.ReadNoRevs -eq 0.3) "table reelle de 040 : $(@($pc.Keys | Sort-Object | ForEach-Object { "$_ $(Num $pc[$_])" }) -join ', ')"
$cE = @('erase', '--drive=A', '--hfreq', '--tracks=c=0-81:h=0-1')
$cW = @('write', '--drive=A', '--no-verify', '--tracks=c=0-81:h=0-1', '--precomp', '0=0', '"motif.hfe"')
$cR = @('read', '--drive=A', '--revs=3', '--tracks=c=0-81:h=0-1', '"releve.scp"')
$u = Get-GwCmdUnits $cE; Chk 'U1' (Test-Units $u 5 0.23 164 42.72) "effacement de 164 pistes : $(U-Txt $u)"
$u = Get-GwCmdUnits $cW; Chk 'U2' (Test-Units $u 5 0.40 164 70.6) "ecriture sans verification de 164 pistes : $(U-Txt $u)"
$u = Get-GwCmdUnits @('write', '--drive=A', '--pre-erase', '--retries=3', '--tracks=c=0-81:h=0', '"image.adf"'); Chk 'U3' (Test-Units $u 5 1.19 82 102.58) "ecriture verifiee avec pre-effacement de 82 pistes : $(U-Txt $u)"
$u = Get-GwCmdUnits $cR; Chk 'U4' (Test-Units $u 5 0.8 164 136.2) "relecture de 3 tours de 164 pistes : $(U-Txt $u)"
$u = Get-GwCmdUnits @('read', '--drive=A', '--tracks=c=0-79:h=0-1', '"x.scp"'); Chk 'U5' (Test-Units $u 5 0.3 160 53) "lecture sans --revs de 160 pistes : $(U-Txt $u)"
$u = Get-GwCmdUnits @('write', '--drive=A', '--tracks=h=0', '"image.adf"'); $u2 = Get-GwCmdUnits @('read', '--drive=A', '--revs=3', '"x.scp"'); $u3 = Get-GwCmdUnits @('erase', '--drive=A', '--tracks=c=0-79')
Chk 'U6' ((Test-Units $u 5 0.98 0 5) -and (Test-Units $u2 5 0.8 0 5) -and (Test-Units $u3 5 0.23 0 5)) "--tracks=h=0, pas de --tracks, c= sans h= : pistes non lues, poids de la part fixe ($(U-Txt $u) ; $(U-Txt $u2) ; $(U-Txt $u3))"
$u = Get-GwCmdUnits @('read --drive=A --revs=5 --tracks=c=0-9:h=0-1 "x.scp"'); Chk 'U7' (Test-Units $u 5 1.2 20 29) "arguments en une seule chaine, 5 tours : $(U-Txt $u)"
$uk = @('clean', 'rpm', 'info', 'seek', 'update', 'convert') | ForEach-Object { Get-GwCmdUnits @($_, '--drive=A', '--tracks=c=0-79:h=0-1') }
Chk 'U8' (@($uk | Where-Object { -not (Test-Units $_ 0 0 0 0) }).Count -eq 0 -and (Test-Units (Get-GwCmdUnits @()) 0 0 0 0)) "autre commande (clean, rpm, info, seek, update, convert) ou aucune : poids nul"
$u = Get-GwCmdUnits @('erase', '--drive=A', '--tracks=h=0') 40; Chk 'U9' (Test-Units $u 5 0.23 40 14.2) "nombre de pistes impose (40) : $(U-Txt $u)"
$u = Get-GwCmdUnits @('--time', 'write', '--drive=A', '--pre-erase', '--no-verify', '--tracks=c=0,10,20,30:h=0-1', '"m.hfe"'); $u2 = Get-GwCmdUnits @('read', '--revs=3', '--tracks=c=0-39:h=0-1:step=2', '"x.scp"')
Chk 'U10' ((Test-Units $u 5 0.61 8 9.88) -and (Test-Units $u2 5 0.8 80 69)) "--time en tete, liste de cylindres, pre-effacement sans verification : $(U-Txt $u) ; TSPEC avec :step=2 : $(U-Txt $u2)"

# ================================================================ P. le plan d une etape
'--- P. New-ProgPlan, Get-ProgPlanFrac : plan d une etape de plusieurs commandes'
$hE = 'Erasing c=0-81:h=0-1, revs=1'; $hW = 'Writing c=0-81:h=0-1'; $hR = 'Reading c=0-81:h=0-1 revs=3'
Reset-All
$p1 = Get-ProgPlanFrac
New-ProgPlan @($cE, $cW, $cR)
$p2 = Get-ProgPlanFrac; $pl = $script:ProgPlan
Chk 'P1' ($null -eq $p1 -and $null -eq $p2 -and @($pl.Cmds).Count -eq 3 -and [math]::Abs([double]$pl.Units - 249.52) -lt 1e-9 -and [int]$pl.Got -eq 0) "sans plan : `$null ; plan pose, aucune commande recue : `$null (plan de $(@($pl.Cmds).Count) commandes, poids $(Num $pl.Units))"
# Passe de trois commandes : effacement, ecriture, relecture
function Step-Frac { $f = Get-ProgPlanFrac; if ($null -ne $f) { if ($script:PFrac.Count -gt 0 -and $f -lt $script:PFrac[$script:PFrac.Count - 1] - 1e-12) { $script:PDrop++ }; $script:PFrac.Add([double]$f) } }
$script:PFrac = New-Object System.Collections.Generic.List[double]; $script:PDrop = 0
Start-Progress (T 'Effacement') $cE; $script:GwStart = Get-Date
$f0 = Get-ProgPlanFrac
Update-Progress $hE -Defer; foreach ($l in (New-TrackLines 'erase' 0 81 @(0, 1))) { Update-Progress $l -Defer; Step-Frac }
$fE1 = Get-ProgPlanFrac
Stop-Progress 0; Step-Frac; $fE = Get-ProgPlanFrac
Start-Progress (T 'Écriture') $cW; $script:GwStart = Get-Date; Step-Frac
Update-Progress $hW -Defer; foreach ($l in (New-TrackLines 'write' 0 81 @(0, 1))) { Update-Progress $l -Defer; Step-Frac }
Stop-Progress 0; Step-Frac; $fW = Get-ProgPlanFrac
Start-Progress (T 'Lecture') $cR; $script:GwStart = Get-Date; Step-Frac
Update-Progress $hR -Defer; foreach ($l in (New-TrackLines 'read' 0 81 @(0, 1))) { Update-Progress $l -Defer; Step-Frac }
$fR1 = Get-ProgPlanFrac
Stop-Progress 0; Step-Frac; $fEnd = Get-ProgPlanFrac
Chk 'P2' ($null -ne $f0 -and $f0 -ge 0 -and $f0 -lt 0.01 -and [int]$script:ProgPlan.Got -eq 3 -and $script:PDrop -eq 0 -and $script:PFrac.Count -gt 490) "passe de 3 commandes : fraction rendue des la premiere commande ($(Num $f0 '0.######')), jamais decroissante sur $($script:PFrac.Count) releves (reculs : $($script:PDrop))"
Chk 'P3' ([math]::Abs($fE - 42.72 / 249.52) -lt 1e-9 -and [math]::Floor(100 * $fE) -eq 17 -and [math]::Abs($fE1 - (5 + 163 * 0.23) / 249.52) -lt 1e-9 -and [math]::Abs($fW - (42.72 + 70.6) / 249.52) -lt 1e-9) "apres l effacement : $(Num (100 * $fE) '0.0') % (17 % attendu) ; pendant sa derniere piste : $(Num (100 * $fE1) '0.00') % (piste commencee, non finie) ; apres l ecriture : $(Num (100 * $fW) '0.0') %"
Chk 'P4' ($fEnd -eq 1.0 -and [math]::Abs($fR1 - 1.0) -lt 1e-9 -and [math]::Abs([double]$script:ProgPlan.Done - 249.52) -lt 1e-9 -and $null -eq $script:ProgCmd) "fin de la passe : fraction $(Num $fEnd) (derniere piste relue : $(Num $fR1 '0.####')), poids fini $(Num $script:ProgPlan.Done) sur $(Num $script:ProgPlan.Units)"
# Code non nul : credit partiel ; commande non prevue : jamais de recul
Reset-All
$cW0 = @('write', '--drive=A', '--retries=3', '--tracks=c=0-81:h=0', '"image.ipf"'); $cW0b = @('write', '--drive=A', '--retries=3', '--tracks=c=20-81:h=0', '"image.ipf"'); $cE0 = @('erase', '--drive=A', '--hfreq', '--tracks=c=0-81:h=0'); $cR0 = @('read', '--drive=A', '--revs=3', '--tracks=c=0-81:h=0', '"x.scp"')
New-ProgPlan @($cE0, $cW0, $cR0)
$script:PFrac = New-Object System.Collections.Generic.List[double]; $script:PDrop = 0
Start-Progress (T 'Effacement') $cE0; $script:GwStart = Get-Date; Update-Progress 'Erasing c=0-81:h=0, revs=1' -Defer; foreach ($l in (New-TrackLines 'erase' 0 81 @(0))) { Update-Progress $l -Defer; Step-Frac }; Stop-Progress 0; Step-Frac
Start-Progress (T 'Écriture') $cW0; $script:GwStart = Get-Date; Update-Progress 'Writing c=0-81:h=0' -Defer; foreach ($l in (New-TrackLines 'write' 0 19 @(0))) { Update-Progress $l -Defer; Step-Frac }
Update-Progress '** FATAL ERROR:' -Defer; Update-Progress 'Failed to verify Track 19.0' -Defer; Step-Frac
$fBefore = Get-ProgPlanFrac
Stop-Progress 1; Step-Frac
$doneW = [double]$script:ProgPlan.Done; $fAfter = Get-ProgPlanFrac
$unitsPlan = [double]$script:ProgPlan.Units
Chk 'P5' ([math]::Abs($doneW - (23.86 + 5 + 19 * 0.98)) -lt 1e-9 -and [math]::Abs($fAfter - $fBefore) -lt 1e-9 -and [math]::Abs($unitsPlan - 179.82) -lt 1e-9) "ecriture arretee a la 20e piste (code 1) : credit de la part fixe et des 19 pistes terminees (poids fini $(Num $doneW), et non $(Num (23.86 + 85.36))) ; fraction inchangee a l arret ($(Num $fBefore) -> $(Num $fAfter))"
Start-Progress (T 'Écriture') $cW0b; $script:GwStart = Get-Date; Step-Frac
Update-Progress 'Writing c=20-81:h=0' -Defer; foreach ($l in (New-TrackLines 'write' 20 81 @(0))) { Update-Progress $l -Defer; Step-Frac }
Stop-Progress 0; Step-Frac
$fPrev = Get-ProgPlanFrac
Start-Progress (T 'Lecture') $cR0; $script:GwStart = Get-Date; Step-Frac
$fHeld = Get-ProgPlanFrac; $rawNext = ([double]$script:ProgPlan.Done) / ([double]$script:ProgPlan.Done + 70.6)
Update-Progress 'Reading c=0-81:h=0 revs=3' -Defer; foreach ($l in (New-TrackLines 'read' 0 81 @(0))) { Update-Progress $l -Defer; Step-Frac }
Stop-Progress 0; Step-Frac
Chk 'P6' ($script:PDrop -eq 0 -and [int]$script:ProgPlan.Got -eq 4 -and @($script:ProgPlan.Cmds).Count -eq 3 -and [double]$script:ProgPlan.Done -gt $unitsPlan -and $rawNext -lt $fPrev -and [math]::Abs($fHeld - $fPrev) -lt 1e-12 -and (Get-ProgPlanFrac) -eq 1.0) "commande non prevue (reprise de la tete) : 4 commandes pour un plan de 3, poids fini $(Num $script:ProgPlan.Done) pour $(Num $unitsPlan) prevus ; aucun recul sur $($script:PFrac.Count) releves ; au debut de la relecture la barre attend sur place ($(Num $fHeld '0.####') au lieu de $(Num $rawNext '0.####')) ; 1 a la fin"
# Sans annonce ni ligne de piste : temps ecoule, borne a 98 % du poids de la commande, puis poids credite a la fin
Reset-All
New-ProgPlan @($cE, $cW)
Start-Progress (T 'Effacement') $cE
$script:GwStart = (Get-Date).AddSeconds(-2); $fT1 = Get-ProgPlanFrac
$script:GwStart = (Get-Date).AddSeconds(-1000); $fT2 = Get-ProgPlanFrac
$script:GwStart = (Get-Date).AddSeconds(-3); $fT3 = Get-ProgPlanFrac
Stop-Progress 0; $fT4 = Get-ProgPlanFrac
Chk 'P7' ($fT1 * 113.32 -ge 2.0 -and $fT1 * 113.32 -lt 5.0 -and [math]::Abs($fT2 - 0.98 * 42.72 / 113.32) -lt 1e-9 -and $fT3 -eq $fT2 -and [math]::Abs($fT4 - 42.72 / 113.32) -lt 1e-9 -and $script:ProgTotal -eq 0) "gw sans annonce ni ligne de piste : part de la commande = temps ecoule ($(Num ($fT1 * 113.32) '0.0') s apres 2 s), bornee a 98 % de son poids ($(Num $fT2 '0.####')) ; jamais de recul ($(Num $fT3 '0.####')) ; poids credite a la fin ($(Num $fT4 '0.####'))"
# Annonce tardive pour une commande sans pistes dans ses arguments
Reset-All
$cWh = @('write', '--drive=A', '--no-verify', '--tracks=h=0', '"image.adf"')
New-ProgPlan @(, $cWh)
$u0 = [double]$script:ProgPlan.Units
Start-Progress (T 'Écriture') $cWh; $script:GwStart = Get-Date
$w0 = [double]$script:ProgCmd.Units
Update-Progress 'Writing c=0-79:h=0' -Defer
$w1 = [double]$script:ProgCmd.Units; $u1 = [double]$script:ProgPlan.Units
foreach ($l in (New-TrackLines 'write' 0 39 @(0))) { Update-Progress $l -Defer }
$fH = Get-ProgPlanFrac
Chk 'P8' ($u0 -eq 5 -and $w0 -eq 5 -and [math]::Abs($w1 - 37) -lt 1e-9 -and [math]::Abs($u1 - 37) -lt 1e-9 -and [int]$script:ProgCmd.Tracks -eq 80 -and [math]::Abs($fH - (5 + 39 * 0.4) / 37) -lt 1e-9) "--tracks=h=0 : poids de $(Num $w0) avant l annonce de gw, complete a $(Num $w1) par « Writing c=0-79:h=0 » (plan : $(Num $u0) -> $(Num $u1)) ; fraction a la 40e piste : $(Num $fH '0.###')"
# Plan faux : plus de pistes vues que prevu ; l erreur de la commande reste affichee
Reset-All
$cRs = @('read', '--drive=A', '--revs=3', '--tracks=c=0-9:h=0-1', '"x.scp"')
New-ProgPlan @(, $cRs)
$script:PFrac = New-Object System.Collections.Generic.List[double]; $script:PDrop = 0
Start-Progress (T 'Lecture') $cRs; $script:GwStart = Get-Date
Update-Progress 'Reading c=0-19:h=0-1 revs=3'
foreach ($l in (New-TrackLines 'read' 0 19 @(0, 1))) { Update-Progress $l; Step-Frac }
$fOver = Get-ProgPlanFrac; $seenOver = $script:ProgSeen.Count; $trkOver = [string]$stTrack.Text
$ruleOver = Invoke-TimerEndRule 1 $false $false
Stop-Progress 1
Chk 'P9' ($script:PDrop -eq 0 -and $fOver -eq 1.0 -and @($script:PFrac | Where-Object { $_ -gt 1.0 }).Count -eq 0 -and $seenOver -eq 40 -and $trkOver -eq 'piste 19.1  (40/40, 100 %)' -and (Get-EndRuleTotal) -eq 40) "plan faux (20 pistes prevues, 40 lues) : fraction bornee a 1, sans recul (la barre de l etape attend a la fin de l etape) ; la barre d etat suit l annonce de gw : « $trkOver » ; regle de fin : total $(Get-EndRuleTotal), pistes vues $seenOver, sans lien avec le plan"
Chk 'P10' ($stOp.Text -match ('^' + [regex]::Escape((T 'Lecture') + ' en échec (code 1)') + $rxTime) -and (Test-Icon 'err') -and -not $stBar.Available -and [bool]$script:ProgFailed -and -not $ruleOver.Next -and [math]::Abs([double]$script:ProgPlan.Done - (5 + 40 * 0.8)) -lt 1e-9) "plan faux puis echec de la commande : « $($stOp.Text) », icone d erreur, barre masquee, la sequence ne continue pas (Next $($ruleOver.Next)) : l erreur n est pas masquee"
# Commandes hors plan : appel a un argument (prechauffage, detection), plan remplace, double fin de commande
Reset-All
New-ProgPlan @($cE, $cW)
Start-Progress (T 'Préchauffage'); $gotWarm = [int]$script:ProgPlan.Got; $cmdWarm = $script:ProgCmd; $fWarm = Get-ProgPlanFrac
Stop-Progress 0
Start-Progress (T 'Effacement') $cE; Update-Progress $hE -Defer; foreach ($l in (New-TrackLines 'erase' 0 81 @(0, 1))) { Update-Progress $l -Defer }
Stop-Progress 1; $d1 = [double]$script:ProgPlan.Done
Stop-Progress 0; $d2 = [double]$script:ProgPlan.Done
Chk 'P11' ($gotWarm -eq 0 -and $null -eq $cmdWarm -and $null -eq $fWarm -and $d1 -eq $d2 -and [math]::Abs($d1 - (5 + 163 * 0.23)) -lt 1e-9 -and -not $script:ProgFailed) "appel a un argument : commande hors du plan (recues $gotWarm, fraction `$null) ; fin de commande appelee deux fois (detection des lecteurs) : poids credite une seule fois ($(Num $d1) puis $(Num $d2))"
$fOld = Get-ProgPlanFrac
$aE = @($cE); $aW = @($cW); $aR = @($cR)
New-ProgPlan @($cE, $cW, $cR)
$same = ((@($cE) -join ' ') -eq ($aE -join ' ') -and (@($cW) -join ' ') -eq ($aW -join ' ') -and (@($cR) -join ' ') -eq ($aR -join ' ') -and $cE.Count -eq 4 -and $cW.Count -eq 7 -and $cR.Count -eq 5)
Chk 'P12' ($fOld -gt 0.3 -and $null -eq (Get-ProgPlanFrac) -and [double]$script:ProgPlan.Max -eq 0 -and [double]$script:ProgPlan.Done -eq 0 -and $same) "plan remplace : la nouvelle etape repart de zero (ancienne fraction $(Num $fOld '0.###'), puis `$null) ; arguments des commandes non modifies par New-ProgPlan : $same"

# ================================================================ S. la barre d etat pendant une commande
'--- S. barre d etat : Start-Progress, Update-Progress, Show-GwProgress, Stop-Progress'
Reset-All
Start-Progress (T 'Lecture') $cR
$s1a = "$($stOp.Text)|$([string]$stBar.Style)|$($stBar.Available)|$($stTrack.Text)|$(Test-Icon 'run')"
Update-Progress $hR; $s1b = Get-Bar
Push-Lines (New-TrackLines 'read' 0 0 @(0, 1))
Chk 'S1' ($s1a -eq 'Lecture en cours...|Marquee|True||True' -and $s1b -eq 'Continuous 0/164' -and (Get-Bar) -eq 'Continuous 2/164' -and $stTrack.Text -eq 'piste 0.1  (2/164, 1 %)') "lecture : « $($stOp.Text) », barre animee, puis $s1b a l annonce ; apres deux pistes lues : $(Get-Bar), « $($stTrack.Text) » (pistes lues = pistes terminees)"
# Ecriture avec pre-effacement et nouveaux essais : pistes distinctes, une de moins que les pistes vues
Reset-All
$cWp = @('write', '--drive=A', '--pre-erase', '--retries=3', '--tracks=c=0-81:h=0', '"image.adf"')
Start-Progress (T 'Écriture') $cWp
Update-Progress 'Writing c=0-81:h=0'
Push-Lines @('T0.0: Erasing Track', 'T0.0: Writing Track (Flux: 199.9ms period, 199.9 ms total, Write all)', 'T1.0: Erasing Track', 'T1.0: Writing Track (Flux: 199.9ms period, 199.9 ms total, Write all)', 'T1.0: Erasing Track', 'T1.0: Writing Track (Verify Failure: Retry #1)', 'T1.0: Erasing Track')
$s2a = "$(Get-Bar)|$($stTrack.Text)"
Update-Progress 'T1.0: Writing Track (Verify Failure: Retry #3)'
$s2b = "$(Get-Bar)|$($stTrack.Text)"; $seen2 = $script:ProgSeen.Count
Push-Lines (New-TrackLines 'pre' 2 81 @(0))
$s2c = "$(Get-Bar)|$($stTrack.Text)"
Stop-Progress 0
Chk 'S2' ($s2a -eq 'Continuous 1/82|piste 1.0  (1/82, 1 %)' -and $s2b -eq 'Continuous 1/82|piste 1.0  (1/82, 1 %)  -  essai 3' -and $seen2 -eq 2 -and $s2c -eq 'Continuous 81/82|piste 81.0  (81/82, 99 %)') "ecriture avec pre-effacement : 8 lignes pour 2 pistes, une terminee : « $($s2b.Split('|')[1]) » ; pendant la derniere piste : $($s2c.Replace('|', ', « '))» (99 %, et non 100 %)"
Chk 'S3' ((Get-Bar) -eq 'Continuous 82/82' -and $stTrack.Text -eq 'piste 81.0  (82/82, 100 %)' -and $stOp.Text -match ('^' + [regex]::Escape('Écriture terminé(e)') + $rxTime) -and (Test-Icon 'ok') -and $stBar.Available) "fin de l ecriture (code 0) : $(Get-Bar), « $($stTrack.Text) », « $($stOp.Text) », barre gardee"
Reset-All
Start-Progress (T 'Effacement') $cE; Update-Progress $hE
Push-Lines (New-TrackLines 'erase' 0 40 @(0, 1))
$s4 = "$(Get-Bar)|$($stTrack.Text)"
Chk 'S4' ($s4 -eq 'Continuous 81/164|piste 40.1  (81/164, 49 %)' -and $script:ProgSeen.Count -eq 82) "effacement : 82 pistes vues, 81 terminees : « $($stTrack.Text) »"
# Conversion : barre et compteur avec total ; la regle de fin ne compte pas ce total
Reset-All
Start-Progress 'Conversion' @('convert', '--format=amiga.amigados', '"a.ipf"', '"b.adf"')
$hC = 'Converting c=0-79:h=0-1 -> c=0-79:h=0-1'
Update-Progress $hC; Push-Lines (New-TrackLines 'conv' 0 79 @(0, 1))
$s5 = "$(Get-Bar)|$($stTrack.Text)"; $tot5 = [int]$script:ProgTotal; $ert5 = Get-EndRuleTotal
Stop-Progress 0
Chk 'S5' ($s5 -eq 'Continuous 160/160|piste 79.1  (160/160, 100 %)' -and $tot5 -eq 160 -and $ert5 -eq 0 -and $stBar.Available -and $stOp.Text -match ('^Conversion terminé\(e\)' + $rxTime)) "conversion : $($s5.Replace('|', ', « '))» ; total de la barre $tot5, total de la regle de fin $ert5 ; « $($stOp.Text) »"
# Regle de fin, instruction reelle du minuteur (600) : conversion d une image plus courte que le jeu annonce
function Get-EndCase([string]$verb, [string]$head, [string]$op, [int]$nCyl, [int]$code) {
    Reset-All
    Start-Progress $verb
    Update-Progress $head -Defer; foreach ($l in (New-TrackLines $op 0 ($nCyl - 1) @(0, 1))) { Update-Progress $l -Defer }
    $r = Invoke-TimerEndRule $code $false $false
    return @{ Inc = [bool]$r.Incomplete; Next = [bool]$r.Next; Total = [int]$script:ProgTotal; Seen = [int]$script:ProgSeen.Count; Old = [bool](Get-GwEndRule $code $false $false $false ([int]$script:ProgTotal) ([int]$script:ProgSeen.Count) $null '' $false).Incomplete }
}
$eC = Get-EndCase 'Conversion' $hC 'conv' 20 0
$eR = Get-EndCase (T 'Lecture') 'Reading c=0-79:h=0-1 revs=3' 'read' 20 0
$eR2 = Get-EndCase (T 'Lecture') 'Reading c=0-79:h=0-1 revs=3' 'read' 80 0
$eE = Get-EndCase (T 'Effacement') 'Erasing c=0-79:h=0-1, revs=1' 'erase' 20 0
Chk 'S6' (-not $eC.Inc -and $eC.Next -and $eC.Total -eq 160 -and $eC.Seen -eq 40 -and $eC.Old) "conversion de 40 pistes pour 160 annoncees, code 0 : complete pour le minuteur (Incomplete $($eC.Inc), suite $($eC.Next)) ; avec le total brut de la barre, la regle l aurait dite incomplete ($($eC.Old)) : Get-EndRuleTotal l en garde"
Chk 'S7' ($eR.Inc -and -not $eR2.Inc -and $eE.Inc -and $eR.Total -eq 160 -and $eR.Seen -eq 40) "regle de fin inchangee pour les autres commandes : lecture de 40 pistes sur 160 incomplete ($($eR.Inc)), lecture entiere complete ($(-not $eR2.Inc)), effacement de 40 pistes sur 160 incomplet ($($eE.Inc))"
$tArg = [string]$endAsg[0].Right.Extent.Text
$n600 = @($src.Ast['600-minuteur-demarrage.ps1'].FindAll({ param($x) $x -is $tVar -and [string]$x.VariablePath.UserPath -eq 'script:ProgTotal' }, $true)).Count
Chk 'S8' ($tArg.StartsWith('Get-GwEndRule $code $soft ([bool]$script:GwIsWrite) ([bool]$script:GwWriteSummary) (Get-EndRuleTotal) ([int]$script:ProgSeen.Count) ', [System.StringComparison]::Ordinal) -and $n600 -eq 0) "minuteur principal : le total passe a Get-GwEndRule est (Get-EndRuleTotal) ; lectures directes de `$script:ProgTotal dans 600 : $n600"
# « Command Failed » avec le code 0 : regle « incomplete » et affichage de la 12.10
Reset-All
Start-Progress (T 'Lecture') $cR; Update-Progress $hR
Push-Lines (New-TrackLines 'read' 0 0 @(0, 1)); Update-Progress 'Command Failed: GetFluxStatus: No Index'
$r9 = Invoke-TimerEndRule 0 $false $false
Stop-Progress 0
Chk 'S9' ($r9.Incomplete -and $stTrack.Text -eq 'piste 0.1  (2/164, 1 %)' -and (Get-Bar) -eq 'Continuous 164/164' -and $stOp.Text -match ('^Lecture terminé\(e\)' + $rxTime) -and -not $script:ProgFailed) "lecture arretee par « Command Failed », code 0 : operation incomplete pour le minuteur ($($r9.Incomplete)) ; barre d etat comme en 12.10 (« $($stOp.Text) », barre pleine) ; le compteur garde le compte reel : « $($stTrack.Text) »"
# Sans annonce reconnue : barre animee, piste seule
Reset-All
Start-Progress (T 'Lecture')
Push-Lines @('T3.0: Raw Flux (128066 flux in 683.09ms)')
$s10 = "$([string]$stBar.Style)|$($stTrack.Text)"
Stop-Progress 0
Chk 'S10' ($s10 -eq 'Marquee|piste 3.0' -and -not $stBar.Available -and $script:ProgTotal -eq 0) "sans annonce : barre animee, « piste 3.0 » ; a la fin, barre masquee (12.10)"
# Un lot de 500 lignes : un seul affichage (Read-GwOutput reel) ; ligne par ligne sans -Defer : affichage immediat
$big = New-TrackLines 'read' 0 249 @(0, 1)
Reset-All
Start-Progress (T 'Lecture'); Update-Progress 'Reading c=0-249:h=0-1 revs=3'
$script:NPaint = 0
Push-Batch $big
$nBatch = $script:NPaint; $tBatch = [string]$stTrack.Text; $bBatch = Get-Bar; $nLines = [int]$script:GwLines
Reset-All
Start-Progress (T 'Lecture'); Update-Progress 'Reading c=0-249:h=0-1 revs=3'
$script:NPaint = 0
Push-Lines $big
Chk 'S11' ($nBatch -eq 1 -and $nLines -eq 500 -and $tBatch -eq 'piste 249.1  (500/500, 100 %)' -and $bBatch -eq 'Continuous 500/500' -and $script:NPaint -eq 500 -and $stTrack.Text -eq $tBatch) "lot de 500 lignes par la vraie Read-GwOutput : $nBatch affichage du compteur (« $tBatch », $bBatch) ; les memes lignes une a une, sans -Defer : $($script:NPaint) affichages"
Reset-All
Start-Progress (T 'Lecture'); Update-Progress $hR -Defer; Update-Progress 'T0.0: Raw Flux (1 flux in 1.00ms)' -Defer
$s12a = "$([string]$stBar.Style)|$($stTrack.Text)|$($script:ProgDirty)"
Show-GwProgress; $n12 = $script:NPaint; Show-GwProgress
Chk 'S12' ($s12a -eq 'Marquee||True' -and $stTrack.Text -eq 'piste 0.0  (1/164, 1 %)' -and $n12 -eq 1 -and $script:NPaint -eq 1 -and -not $script:ProgDirty) "avec -Defer : etat mis a jour sans toucher a la barre d etat ($s12a) ; Show-GwProgress peint une fois, rien si l etat n a pas change ($($script:NPaint) affichage)"
# Nettoyage des tetes : branche inchangee
Reset-All
$script:CleanRun = @{ Done = 0; Lines = (New-Object System.Collections.Generic.List[string]) }
Start-Progress (T 'Nettoyage')
Update-Progress 'Pass 0: 0 10 20 30 40 50 60 70'; Update-Progress 'Pass 1: 0 10 20 Command Failed: x'; Update-Progress 'T1.0: Raw Flux (1 flux in 1.00ms)'
Chk 'S13' ([int]$script:CleanRun.Done -eq 1 -and $script:CleanRun.Lines.Count -eq 2 -and $script:ProgSeen.Count -eq 0 -and -not $script:ProgDirty -and $stTrack.Text -eq '' -and [string]$stBar.Style -eq 'Marquee') "nettoyage des tetes : passes comptees ($($script:CleanRun.Done)), autres lignes gardees ($($script:CleanRun.Lines.Count)), aucun compteur de piste"
$script:CleanRun = $null
# Plus de pistes vues qu annoncees ; jamais de recul de la barre d etat
Reset-All
Start-Progress (T 'Lecture'); Update-Progress 'Reading c=0-9:h=0-1 revs=3'
$vals = New-Object System.Collections.Generic.List[int]
foreach ($l in (New-TrackLines 'read' 0 14 @(0, 1))) { Update-Progress $l; $vals.Add([int]$stBar.Value) }
$r14 = Invoke-TimerEndRule 0 $false $false
Chk 'S14' ((Get-Bar) -eq 'Continuous 20/20' -and $stTrack.Text -eq 'piste 14.1  (20/20, 100 %)' -and $script:ProgSeen.Count -eq 30 -and -not $r14.Incomplete) "30 pistes vues pour 20 annoncees : barre et compteur au total annonce, la piste en cours continue de s afficher (« $($stTrack.Text) ») ; regle de fin : $($script:ProgSeen.Count) pistes vues, complete"
Reset-All
Start-Progress (T 'Écriture'); Update-Progress 'Writing c=0-9:h=0'
$vals = New-Object System.Collections.Generic.List[int]; $back = 0
foreach ($l in @('T0.0: Writing Track (x)', "T0.0: WARNING: Out of range for format 'x': Track skipped", 'T0.0: Writing Track (Verify Failure: Retry #1)', 'T1.0: Writing Track (x)', 'T1.0: Erasing Track', 'T1.0: Raw Flux (1 flux in 1.00ms)', 'T1.0: Writing Track (x)', 'T2.0: Erasing Track', 'T2.0: Writing Track (x)')) {
    Update-Progress $l
    if ($vals.Count -gt 0 -and [int]$stBar.Value -lt $vals[$vals.Count - 1]) { $back++ }
    $vals.Add([int]$stBar.Value)
}
Chk 'S15' ($back -eq 0 -and ($vals -join ',') -eq '0,1,1,1,1,2,2,2,2') "lignes de natures melees pour une meme piste : la barre ne recule jamais ($($vals -join ','))"
# Echec : texte, icone, compteur laisse a la piste en cours non finie
Reset-All
Start-Progress (T 'Écriture') $cW; Update-Progress $hW; Push-Lines (New-TrackLines 'write' 0 9 @(0, 1))
Stop-Progress 1
Chk 'S16' ($stOp.Text -match ('^' + [regex]::Escape('Écriture en échec (code 1)') + $rxTime) -and (Test-Icon 'err') -and -not $stBar.Available -and $stTrack.Text -eq 'piste 9.1  (19/164, 12 %)' -and [bool]$script:ProgFailed) "ecriture en echec (code 1) : « $($stOp.Text) », icone d erreur, barre masquee ; compteur laisse aux pistes terminees : « $($stTrack.Text) »"
Start-Progress (T 'Lecture')
Chk 'S17' ($stOp.Text -eq 'Lecture en cours...' -and (Test-Icon 'run') -and $stTrack.Text -eq '' -and [string]$stBar.Style -eq 'Marquee' -and $stBar.Available -and -not $script:ProgFailed -and $script:ProgSeen.Count -eq 0 -and [int]$script:ProgDone -eq 0 -and $script:ProgHead -eq '' -and $null -eq $script:ProgCmd) "commande suivante, appel a un argument : etat de la commande remis a zero, « $($stOp.Text) », barre animee"

# ================================================================ C. la barre de la calibration
'--- C. Update-CalibProgress reel : plan de l etape a la place du temps ecoule'
function New-CalState {
    return @{ Hold = $false; SwapHold = $null; Stage = 'coarse'; Cyls = @(0..9); WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; EstErase = 0.37
              Cond = $false; CondRun = $false; CondDone = $false; CondSec = 0.0; CondTracks = 0; TotalPasses = 5; PassesDone = 1; Phase = 'write'; PhaseStart = $null
              Mode = 'fine'; ValueTxt = '0/30/100 ns'; Redo = $false; DiskOnly = $false; Cross = $null; Drive = 'A'; WarmSkip = $false; WarmReads = 2 }
}
$cEs = @('erase', '--drive=A', '--hfreq', '--tracks=c=0-9:h=0-1'); $cWs = @('write', '--drive=A', '--no-verify', '--tracks=c=0-9:h=0-1', '--precomp', '0=30', '"m.hfe"'); $cRc = @('read', '--drive=A', '--revs=3', '--tracks=c=0-9:h=0-1', '"x.scp"')
$hEs = 'Erasing c=0-9:h=0-1, revs=1'; $hWs = 'Writing c=0-9:h=0-1'; $hRs = 'Reading c=0-9:h=0-1 revs=3'
Reset-All
$script:Cal = New-CalState
Update-CalibProgress; $c1a = "$($pbWCal.Value)|$($lblWCal.Text)"
$script:Cal.PhaseStart = (Get-Date).AddSeconds(-500); Update-CalibProgress; $c1b = [int]$pbWCal.Value
Chk 'C1' ($c1a -like '20|Calibration : 20 %, reste environ * (passe 2/5, 0/30/100 ns, écriture)' -and $c1b -eq 31) "sans plan : calcul par le temps de la 12.10 : $($c1a.Split('|')[1]) ; 500 s apres le debut de la phase : $c1b % (borne de 98 % de la phase)"
New-ProgPlan @($cEs, $cWs, $cRc)
Update-CalibProgress
Chk 'C2' ([int]$pbWCal.Value -eq 31 -and [int]$script:ProgPlan.Got -eq 0) "plan pose, aucune commande recue (Start-Gw remplace par un banc) : meme valeur que sans plan ($($pbWCal.Value) %)"
Start-Progress (T 'Effacement') $cEs; $script:GwStart = Get-Date; $script:GwProc = [pscustomobject]@{ HasExited = $false }; $script:GwIsErase = $true
Update-Progress $hEs -Defer; foreach ($l in (New-TrackLines 'erase' 0 4 @(0, 1))) { Update-Progress $l -Defer }
Update-CalibProgress; $c3a = "$($pbWCal.Value)|$($lblWCal.Text)"
$script:Lang = 'en'; Update-CalibProgress; $c3e = [string]$lblWCal.Text; $script:Lang = 'fr'
$expE = [int][math]::Floor(100 * (1 + (5 + 9 * 0.23) / 43.6) / 5)
Chk 'C3' ($c3a -like "$expE|Calibration : $expE %, reste environ * (passe 2/5, 0/30/100 ns, effacement)" -and $expE -eq 23 -and $c3e -like "Calibration: $expE %, about * left (pass 2/5, 0/30/100 ns, erasing)") "pendant le gw erase de la passe : « $($c3a.Split('|')[1]) » ; en anglais : « $c3e »"
foreach ($l in (New-TrackLines 'erase' 5 9 @(0, 1))) { Update-Progress $l -Defer }
Stop-Progress 0; $script:GwIsErase = $false; $script:GwProc = $null
Start-Progress (T 'Écriture') $cWs; $script:GwStart = Get-Date; $script:GwProc = [pscustomobject]@{ HasExited = $false }
Update-Progress $hWs -Defer; foreach ($l in (New-TrackLines 'write' 0 4 @(0, 1))) { Update-Progress $l -Defer }
Update-CalibProgress; $c4 = "$($pbWCal.Value)|$($lblWCal.Text)"
$expW = [int][math]::Floor(100 * (1 + (9.6 + 5 + 9 * 0.4) / 43.6) / 5)
Chk 'C4' ($c4 -like "$expW|Calibration : $expW %, reste environ * (passe 2/5, 0/30/100 ns, écriture)" -and $expW -eq 28) "pendant l ecriture, 10 pistes vues sur 20 : pct = floor(100 x (passes faites + fraction du plan) / passes) = $expW % (le calcul par le temps donnait 31 %) : « $($c4.Split('|')[1]) »"
foreach ($l in (New-TrackLines 'write' 5 9 @(0, 1))) { Update-Progress $l -Defer }
Stop-Progress 0; $script:GwProc = $null
$script:Cal.Phase = 'read'; $script:Cal.PhaseStart = Get-Date
Start-Progress (T 'Lecture') $cRc; $script:GwStart = Get-Date; $script:GwProc = [pscustomobject]@{ HasExited = $false }
$mono = New-Object System.Collections.Generic.List[int]; $mono.Add($expE); $mono.Add($expW)
Update-Progress $hRs -Defer; foreach ($l in (New-TrackLines 'read' 0 9 @(0, 1))) { Update-Progress $l -Defer; Update-CalibProgress; $mono.Add([int]$pbWCal.Value) }
$c5 = [string]$lblWCal.Text
Stop-Progress 0; $script:GwProc = $null
Update-CalibProgress; $mono.Add([int]$pbWCal.Value); $vEnd = [int]$pbWCal.Value
$dec = 0; for ($i = 1; $i -lt $mono.Count; $i++) { if ($mono[$i] -lt $mono[$i - 1]) { $dec++ } }
Chk 'C5' ($c5 -like 'Calibration : * (passe 2/5, 0/30/100 ns, relecture)' -and $dec -eq 0 -and $vEnd -eq 40) "relecture : « $c5 » ; valeurs de la barre sur la passe : $($mono[0]) a $vEnd %, jamais decroissantes ($($mono.Count) releves) ; passe finie : $vEnd % = 2 passes sur 5"
# Passe comptee : instructions reelles d Invoke-CalibAnalysis et d Invoke-ContentAnalysis ; plan retire, pas de double compte
function Get-AfterCount([string]$fn) {
    # Texte de l instruction qui suit « PassesDone++ » dans la fonction
    $st = @($src.Fn[$fn].Body.EndBlock.Statements)
    for ($i = 0; $i -lt $st.Count - 1; $i++) { if ([string]$st[$i].Extent.Text -match '^\$cal\.PassesDone\+\+$') { return [string]$st[$i + 1].Extent.Text } }
    return ''
}
$ac1 = Get-AfterCount 'Invoke-CalibAnalysis'; $ac2 = Get-AfterCount 'Invoke-ContentAnalysis'
$script:Cal.PassesDone++; $script:ProgPlan = $null
New-ProgPlan @($cEs, $cWs, $cRc); $script:Cal.Phase = 'write'; $script:Cal.PhaseStart = $null
Update-CalibProgress
Chk 'C6' ($ac1 -eq '$script:ProgPlan = $null' -and $ac2 -eq '$script:ProgPlan = $null' -and [int]$pbWCal.Value -eq 40 -and $lblWCal.Text -like '* (passe 3/5, *') "passe comptee : le plan est retire aussitot (Invoke-CalibAnalysis : « $ac1 » ; Invoke-ContentAnalysis : « $ac2 ») ; debut de la passe suivante : $($pbWCal.Value) %, sans double compte ni saut"
# Conditionnement du lecteur
Reset-All
$script:Cal = New-CalState; $script:Cal.PassesDone = 0; $script:Cal.Cond = $true; $script:Cal.CondRun = $true; $script:Cal.CondTracks = 164; $script:Cal.PhaseStart = Get-Date
New-ProgPlan @($cE, $cW)
Start-Progress (T 'Effacement') $cE; $script:GwStart = Get-Date; Update-Progress $hE -Defer; foreach ($l in (New-TrackLines 'erase' 0 81 @(0, 1))) { Update-Progress $l -Defer }
Stop-Progress 0
Update-CalibProgress
$condW = (164 * 1.07) / (20 * 1.07 + 20 * 0.7); $expC = [int][math]::Floor(100 * (42.72 / 113.32) * $condW / (5 + $condW))
Chk 'C7' ([int]$pbWCal.Value -eq $expC -and $expC -eq 18 -and $lblWCal.Text -like "Calibration : $expC %, reste environ * (conditionnement du lecteur, écriture sans relecture)") "conditionnement, effacement fini (fraction du plan $(Num (42.72 / 113.32) '0.###')) : « $($lblWCal.Text) »"
# Attentes et prechauffage : inchanges, plan ou non
$script:Cal.Hold = $true; $pbWCal.Value = 7; Update-CalibProgress; $c8a = "$($pbWCal.Value)|$($lblWCal.Text)"
$script:Cal.Hold = $false; $script:Cal.SwapHold = @{ From = 'A'; To = '0' }; Update-CalibProgress; $c8b = "$($pbWCal.Value)|$($lblWCal.Text)"
$script:Cal.SwapHold = $null; $script:Cal.Stage = 'warmup'; $script:Cal.WarmStart = (Get-Date).AddSeconds(-255); $script:Cal.WarmSec = 1000.0; $script:Cal.WarmDurs = @(); $script:Cal.WarmReadStart = $null
Update-CalibProgress; $c8c = "$($pbWCal.Value)|$($lblWCal.Text)"
Chk 'C8' ($c8a -eq '7|Calibration en attente : décision sur le contrôle de surface (lecteur A).' -and $c8b -eq '7|Calibration croisée : déplacez la disquette du lecteur A vers le lecteur 0' -and $c8c -like '25|Préchauffage avant la calibration : 25 %, reste environ * (lecteur A, lecture 2, sans écriture)') "avec un plan en place : attente du controle de surface et attente d un echange (libelle fige, barre inchangee), prechauffage par le temps ($($c8c.Split('|')[0]) % apres 255 s sur 1000)"
# Les textes de la barre gardent « reste environ » ; aucune duree n est tiree des poids
$keysC = @($src.Fn['Update-CalibProgress'].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'T' -and $x.CommandElements.Count -eq 2 -and $x.CommandElements[1] -is $tStr }, $true) | ForEach-Object { [string]$_.CommandElements[1].Value })
$pctKeys = @($keysC | Where-Object { $_ -match '%' })
Chk 'C9' ($pctKeys.Count -ge 10 -and @($pctKeys | Where-Object { $_ -notmatch 'reste environ' }).Count -eq 0) "les $($pctKeys.Count) libelles d avancement de la barre annoncent « reste environ » : aucune duree exacte"
# Passe de la mesure sur l image : instruction reelle de New-ContentPass, vraie Get-ContentWriteArgs (cases de l onglet
# Ecriture factices) : effacement, une ecriture par tete, relecture ; la file des commandes de la passe n est pas touchee
Reset-All
$chkWPreErase = [pscustomobject]@{ Checked = $true }; $chkWEraseEmpty = [pscustomobject]@{ Checked = $false }; $chkWNoVerify = [pscustomobject]@{ Checked = $false }; $numWRetries = [pscustomobject]@{ Value = 3 }
$wTab = @{}; foreach ($c in 0..39) { $wTab[$c] = 100 }
$ctT = @{ Pass = 0; EraseMode = 'hfreq'; Plan = @{ Pass = @(@{ H = @(@{ W = $wTab }, @{ W = $wTab }) }) }; Todo = (New-Object System.Collections.Generic.List[hashtable]) }
$ctT.Todo.Add(@{ Erase = [string[]]@('erase', '--drive=A', '--hfreq', '--tracks=c=0-39:h=0-1') }); $ctT.Todo.Add(@{ H = 0; Cyls = [int[]]@(0..39); Resume = $false }); $ctT.Todo.Add(@{ H = 1; Cyls = [int[]]@(0..39); Resume = $false })
$calT = @{ Content = $ctT; Image = 'image.ipf'; ReadArgs = @('read', '--drive=A', '--revs=3', '--tracks=c=0-39:h=0-1', '"x.scp"') }
Invoke-ContentPlanStmt $calT $ctT
$plc = $script:ProgPlan; $w0Args = (Get-ContentWriteArgs $calT $ctT.Todo[1]) -join ' '
$uPl = @($plc.Cmds | ForEach-Object { Num $_.Units })
Chk 'C10' (@($plc.Cmds).Count -eq 4 -and ($uPl -join ' ; ') -eq '23.4 ; 44.2 ; 44.2 ; 69' -and [math]::Abs([double]$plc.Units - 180.8) -lt 1e-9 -and $ctT.Todo.Count -eq 3 -and $w0Args -eq 'write --drive=A --retries=3 --precomp 0=100 --tracks=c=0-39:h=0 "image.ipf"' -and [int]$plc.Got -eq 0) "mesure sur l image, plan pose par l instruction reelle de New-ContentPass : effacement, ecriture de chaque tete (« $w0Args »), relecture : poids $($uPl -join ' ; '), total $(Num $plc.Units) ; file de la passe intacte ($($ctT.Todo.Count) commandes)"
$script:Cal = $null

# ================================================================ E. la barre d etat en fin de sequence
'--- E. Set-SeqEnd, Update-SeqEnd : barre d etat en fin de sequence'
function New-Rs([string]$mode = 'flux') {
    $script:Restore = @{ Drive = '0'; Mode = $mode; Read = $null; Preserved = @(); Cmp = $null; Waiting = $false; Saved = $null; Cur = 6; OnOriginal = $false; Stage = 'write'; Steps = @{}; Orig = 'orig.scp'; Start = (Get-Date) }
}
function Invoke-LastRead([int]$code = 0) {
    # Derniere commande gw de la sequence : relecture de 160 pistes, terminee avec le code donne
    Start-Progress (T 'Lecture') @('read', '--drive=0', '--revs=3', '--tracks=c=0-79:h=0-1', '"x.scp"'); Update-Progress 'Reading c=0-79:h=0-1 revs=3'
    Push-Batch (New-TrackLines 'read' 0 79 @(0, 1))
    Stop-Progress $code
}
function Get-St { return "$($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss')|$($stTrack.Text)|$($stBar.Available)" }
function Invoke-RsEnd([string]$kind, [string]$lang) {
    # Restauration menee a sa fin par les vraies Finish-Restore, Show-RestoreResult et Close-Restore, apres deux commandes gw
    Reset-All; $script:Lang = $lang
    Invoke-LastRead; Invoke-LastRead
    New-Rs
    $script:LastCheck = @{ Ok = ($kind -ne 'h2'); Short = (T 'contrôle interrompu par une erreur gw'); Text = '' }
    if ($kind -eq 'h1') { $script:Restore.Read = @{ WeakKeys = @{ '3.0' = $true } } }
    $before = Get-St
    Finish-Restore
    $o = @{ Before = $before; Pending = (Get-St); Icon0 = [string]$script:RsResultIcon; Posed = ($null -ne $script:SeqEnd); Rest = ($null -eq $script:Restore) }
    Update-SeqEnd
    $o.After = Get-St; $o.Ok = (Test-Icon 'ok'); $o.Idle = (Test-Icon 'idle'); $o.Err = (Test-Icon 'err'); $o.Left = ($null -eq $script:SeqEnd); $o.Raw = [string]$stOp.Text
    $script:Lang = 'fr'
    return $o
}
$e0 = Invoke-RsEnd 'h0' 'fr'; $e1 = Invoke-RsEnd 'h1' 'fr'; $e2 = Invoke-RsEnd 'h2' 'fr'
$stRead = 'Lecture terminé(e)  -  HH:mm:ss|piste 79.1  (160/160, 100 %)|True'
Chk 'E1' ($e0.Before -eq $stRead -and $e0.Pending -eq $stRead -and $e0.Icon0 -eq 'h0' -and $e0.Posed -and $e0.Rest -and $e0.After -eq 'Restauration réussie  -  HH:mm:ss||False' -and $e0.Ok -and $e0.Left -and $e0.Raw -match $rxTime) "restauration reussie : la barre d etat gardait « $($e0.Before.Split('|')[0]) », son compteur et sa barre ; une fois au repos : « $($e0.After.Split('|')[0]) », icone ok, compteur vide, barre masquee"
Chk 'E2' ($e1.Icon0 -eq 'h1' -and $e1.After -eq 'Restauration réussie avec réserve  -  HH:mm:ss||False' -and $e1.Idle) "restauration reussie avec reserve : « $($e1.After.Split('|')[0]) », icone neutre"
Chk 'E3' ($e2.Icon0 -eq 'h2' -and $e2.After -eq 'Restauration échouée  -  HH:mm:ss||False' -and $e2.Err) "restauration echouee, derniere commande reussie (controle) : « $($e2.After.Split('|')[0]) », icone d erreur"
$e0e = Invoke-RsEnd 'h0' 'en'; $e1e = Invoke-RsEnd 'h1' 'en'; $e2e = Invoke-RsEnd 'h2' 'en'
Chk 'E4' ($e0e.After -eq 'Restore succeeded  -  HH:mm:ss||False' -and $e1e.After -eq 'Restore succeeded with a reservation  -  HH:mm:ss||False' -and $e2e.After -eq 'Restore failed  -  HH:mm:ss||False') "en anglais : « $($e0e.After.Split('|')[0]) » ; « $($e1e.After.Split('|')[0]) » ; « $($e2e.After.Split('|')[0]) »"
# Echec sur une erreur gw : l etat de la commande reste affiche
Reset-All
Invoke-LastRead; Invoke-LastRead 1
New-Rs; $stFail = Get-St; $iconFail = Test-Icon 'err'
Stop-Restore 'gw a retourné le code 1, voir le journal'
$posed5 = ($null -ne $script:SeqEnd)
Update-SeqEnd
Chk 'E5' ($stFail -eq 'Lecture en échec (code 1)  -  HH:mm:ss|piste 79.1  (160/160, 100 %)|False' -and $posed5 -and (Get-St) -eq $stFail -and $iconFail -and (Test-Icon 'err') -and $null -eq $script:SeqEnd -and $null -eq $script:Restore) "restauration echouee sur une erreur gw : la barre d etat garde « $($stFail.Split('|')[0]) » (la cause), l etat pose par Close-Restore est abandonne"
# Annulation pendant l attente de la disquette de destination : « Pret. », rien en attente
Reset-All
Invoke-LastRead; New-Rs; $script:Restore.Waiting = $true
$stTrack.Text = ''; $stBar.Visible = $false; $stOp.Image = $script:StIcons.idle; $stOp.Text = (T 'Restauration : changez de disquette, puis cliquez sur « Continuer ».')
Stop-Restore (T 'annulée par l''utilisateur')
$st6 = "$(Get-St)|$($null -eq $script:SeqEnd)"
Update-SeqEnd
Chk 'E6' ($st6 -eq 'Prêt.||False|True' -and (Get-St) -eq 'Prêt.||False' -and (Test-Icon 'idle')) "annulation pendant l attente de la destination : « $($stOp.Text) » aussitot, icone neutre, rien en attente"
# gw non lance : Close-Restore pose l etat, Set-GwLaunchFailedStatus l annule
Reset-All
Invoke-LastRead; New-Rs
Start-Progress (T 'Écriture') $cW
Stop-Restore (T 'gw n''a pas pu être lancé')
$posed7 = ($null -ne $script:SeqEnd); $st7a = [string]$stOp.Text
Set-GwLaunchFailedStatus
$st7b = "$(Get-St)|$($null -eq $script:SeqEnd)|$([bool]$script:ProgFailed)"
Update-SeqEnd
Chk 'E7' ($posed7 -and $st7a -eq 'Écriture en cours...' -and $st7b -eq "Écriture : gw n'a pas pu être lancé, voir le journal  -  HH:mm:ss||False|True|True" -and (Get-St) -eq "Écriture : gw n'a pas pu être lancé, voir le journal  -  HH:mm:ss||False" -and (Test-Icon 'err')) "gw non lance pendant une restauration : etat pose par Close-Restore annule par Set-GwLaunchFailedStatus ; la barre d etat garde « $($stOp.Text) »"
# Calibration : memes titres que la zone de l Accueil, d une seule fonction
function Invoke-CalEnd($cal, [string]$kind, [string]$lang = 'fr') {
    Reset-All; $script:Lang = $lang
    Invoke-LastRead; Invoke-LastRead
    Set-HomeProgDone $cal $kind 'detail de la fenetre'
    $o = @{ Posed = ($null -ne $script:SeqEnd); Text = $(if ($script:SeqEnd) { [string]$script:SeqEnd.Text } else { '' }); Title = (Get-CalibDoneTitle $kind); Home = ($null -ne $script:HomeProgDone) }
    Update-SeqEnd
    $o.After = Get-St; $o.Ok = (Test-Icon 'ok'); $o.Idle = (Test-Icon 'idle')
    $script:Lang = 'fr'
    return $o
}
$calStd = @{ Mode = 'std'; DiskOnly = $false; Home = $false; Family = 'std'; Slow = $false }
$calFine = @{ Mode = 'fine'; DiskOnly = $false; Home = $true; Family = 'std'; Slow = $true }
$k1 = Invoke-CalEnd $calStd 'ok'; $k2 = Invoke-CalEnd $calFine 'warn'; $k3 = Invoke-CalEnd $calStd 'abandon'; $k4 = Invoke-CalEnd $calFine 'stop'
Chk 'E8' ($k1.After -eq 'Calibration terminée : courbe convergée  -  HH:mm:ss||False' -and $k1.Ok -and -not $k1.Home -and $k2.After -eq 'Calibration terminée avec réserves : voir le journal  -  HH:mm:ss||False' -and $k2.Idle -and $k2.Home -and $k3.After -eq 'Calibration abandonnée  -  HH:mm:ss||False' -and $k3.Idle -and $k4.After -eq 'Calibration arrêtée  -  HH:mm:ss||False' -and $k4.Idle -and $k1.Text -eq $k1.Title -and $k2.Text -eq $k2.Title -and $k3.Text -eq $k3.Title -and $k4.Text -eq $k4.Title) "calibration du lecteur (test standard ou fin, lancee de l Accueil ou non) : « $($k1.After.Split('|')[0]) » (icone ok) ; « $($k2.After.Split('|')[0]) » ; « $($k3.After.Split('|')[0]) » ; « $($k4.After.Split('|')[0]) »"
$k1e = Invoke-CalEnd $calStd 'ok' 'en'; $k4e = Invoke-CalEnd $calStd 'stop' 'en'
$calKeys = @('Calibration terminée : courbe convergée', 'Calibration terminée avec réserves : voir le journal', 'Calibration abandonnée', 'Calibration arrêtée')
$owners = @{}
foreach ($mn in @($src.Ast.Keys)) {
    if ($mn -like '01*-i18n*') { continue }
    foreach ($s in @($src.Ast[$mn].FindAll({ param($x) $x -is $tStr -and $calKeys -ccontains [string]$x.Value }, $true))) {
        $x = $s; $own = "($mn)"; while ($null -ne $x) { if ($x -is $tFn) { $own = [string]$x.Name }; $x = $x.Parent }
        $owners[$own] = 1 + [int]$owners[$own]
    }
}
$homeCall = @($src.Fn['Update-HomeProgress'].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Get-CalibDoneTitle' }, $true)).Count
Chk 'E9' ($k1e.After -eq 'Calibration finished: curve converged  -  HH:mm:ss||False' -and $k4e.After -eq 'Calibration stopped  -  HH:mm:ss||False' -and $owners.Count -eq 1 -and [int]$owners['Get-CalibDoneTitle'] -eq 4 -and $homeCall -eq 1) "memes textes que la zone de l Accueil : les quatre titres ne sont ecrits que dans Get-CalibDoneTitle ($(@($owners.Keys) -join ', ')), que Update-HomeProgress appelle ($homeCall) ; en anglais : « $($k1e.After.Split('|')[0]) »"
# m12 : calibration rapide, mesure sur l image, mesure complete d une seule disquette : rien de pose, regle generale
$stGen = 'Lecture terminé(e)  -  HH:mm:ss||False'
$m1 = Invoke-CalEnd @{ Mode = 'level'; DiskOnly = $false; Home = $false } 'ok'
$m2 = Invoke-CalEnd @{ Mode = 'fine'; DiskOnly = $true; Home = $false } 'ok'
$m3 = Invoke-CalEnd @{ Mode = 'content'; DiskOnly = $false; Home = $false } 'stop'
$m4 = Invoke-CalEnd $null 'stop'
Chk 'E10' (-not $m1.Posed -and $m1.After -eq $stGen -and $m1.Ok) "calibration rapide (mode level) : aucun titre de calibration pose ; regle generale : « $($m1.After.Split('|')[0]) », compteur efface, barre masquee"
Chk 'E11' (-not $m2.Posed -and $m2.After -eq $stGen -and -not $m3.Posed -and $m3.After -eq $stGen -and -not $m4.Posed -and $m4.After -eq $stGen) "mesure complete d une seule disquette (DiskOnly), mesure sur l image (mode content), calibration absente : rien de pose, regle generale"
# Une commande suit : l attente est annulee
Reset-All
Invoke-LastRead; Set-SeqEnd 'Calibration terminée : courbe convergée' 'ok'
Start-Progress (T 'Écriture') $cW
$p12 = ($null -eq $script:SeqEnd)
Update-Progress $hW; Push-Lines (New-TrackLines 'write' 0 81 @(0, 1)); Stop-Progress 0
Update-SeqEnd
Chk 'E12' ($p12 -and (Get-St) -eq 'Écriture terminé(e)  -  HH:mm:ss||False' -and (Test-Icon 'ok')) "calibration puis ecriture : l etat de la calibration est annule par la commande qui suit ; a la fin : « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') », compteur efface, barre masquee (regle generale)"
# Rien n est applique tant que l application est occupee
Reset-All
Invoke-LastRead; Invoke-LastRead; Set-SeqEnd 'Essai' 'ok'
$busy = New-Object System.Collections.Generic.List[string]
$script:Cal = @{ Mode = 'fine' }; Update-SeqEnd; $busy.Add("$(Get-AppBusy):$(Get-St)"); $script:Cal = $null
$script:Chain.Enqueue('etape'); Update-SeqEnd; $busy.Add("$(Get-AppBusy):$(Get-St)"); $script:Chain.Clear()
$script:GwProc = [pscustomobject]@{ HasExited = $false }; Update-SeqEnd; $busy.Add("$(Get-AppBusy):$(Get-St)"); $script:GwProc = $null
$script:Restore = @{ Waiting = $true }; Update-SeqEnd; $busy.Add("$(Get-AppBusy):$(Get-St)"); $script:Restore = $null
$script:AlignLoop = $true; Update-SeqEnd; $busy.Add("$(Get-AppBusy):$(Get-St)"); $script:AlignLoop = $false
$still = ($null -ne $script:SeqEnd)
Update-SeqEnd
Chk 'E13' (($busy -join ' ; ') -eq "calib:$stRead ; chain:$stRead ; gw:$stRead ; restore:$stRead ; quality:$stRead" -and $still -and (Get-St) -eq 'Essai  -  HH:mm:ss||False') "occupee (calibration, etapes en attente, gw, restauration, mesure continue ; vraie Get-AppBusy) : barre d etat intacte, etat garde en attente ; au repos : « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') »"
# Sans etat pose : deux commandes, compteur et barre retires ; une commande : affichage de la 12.10
Reset-All
Invoke-LastRead; Update-SeqEnd; $one = Get-St; $n1 = [int]$script:SeqCmds
Invoke-LastRead; Invoke-LastRead; $n2 = [int]$script:SeqCmds; Update-SeqEnd
Chk 'E14' ($one -eq $stRead -and $n1 -eq 0 -and $n2 -eq 2 -and (Get-St) -eq $stGen -and (Test-Icon 'ok') -and [int]$script:SeqCmds -eq 0) "commande isolee : affichage de la 12.10 (« $($one.Split('|')[1]) », barre gardee) ; sequence de deux commandes : texte de la derniere garde, compteur efface, barre masquee"
Reset-All
Invoke-LastRead; Invoke-LastRead 1; Update-SeqEnd
Chk 'E15' ((Get-St) -eq 'Lecture en échec (code 1)  -  HH:mm:ss|piste 79.1  (160/160, 100 %)|False' -and (Test-Icon 'err')) "sequence de deux commandes dont la derniere echoue : barre d etat laissee telle quelle (« $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') »)"
# Arret par l utilisateur pendant une calibration : etat pose, puis gw tue (code non nul) : l echec reste affiche
Reset-All
Invoke-LastRead; Start-Progress (T 'Écriture') $cW; Update-Progress $hW; Push-Lines (New-TrackLines 'write' 0 9 @(0, 1))
Set-HomeProgDone $calStd 'stop'; $posed16 = ($null -ne $script:SeqEnd)
Stop-Progress (-1); Update-SeqEnd
Chk 'E16' ($posed16 -and (Get-St) -eq 'Écriture en échec (code -1)  -  HH:mm:ss|piste 9.1  (19/164, 12 %)|False' -and (Test-Icon 'err') -and $null -eq $script:SeqEnd) "calibration arretee pendant une commande : gw interrompu (code -1), la barre d etat garde « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') »"
# Recherche des lecteurs : « Pret. », sans heure
Reset-All
$script:Detect = @{ Mode = 'auto'; Queue = (New-Object System.Collections.Queue); Found = @('A'); Tried = @('B', 'A'); Cur = 'A'; Drive = 'A' }
Start-Progress 'gw seek'; Stop-Progress 1; Stop-Progress 0
Start-Progress 'gw seek'; Stop-Progress 0; Stop-Progress 0
$st17a = Get-St
Complete-DriveDetect
$st17b = "$(Get-St)|$($null -ne $script:SeqEnd)"
Update-SeqEnd
Chk 'E17' ($st17a -eq 'gw seek terminé(e)  -  HH:mm:ss||False' -and $st17b -eq "$st17a|True" -and [string]$stOp.Text -eq 'Prêt.' -and (Test-Icon 'idle') -and $null -eq $script:Detect -and @($script:Calls | Where-Object { $_ -eq 'Append-Log Lecteur A détecté.' }).Count -eq 1) "recherche des lecteurs (vraie Complete-DriveDetect) : la barre d etat gardait « $($st17a.Split('|')[0]) » ; au repos : « $($stOp.Text) », sans heure, icone neutre"
Reset-All
$script:Detect = @{ Mode = 'auto'; Queue = (New-Object System.Collections.Queue); Found = @(); Tried = @('A'); Cur = 'A'; Drive = 'A' }
Start-Progress 'gw seek'; Stop-Progress 1; Stop-Progress 0
Complete-DriveDetect; Update-SeqEnd
Chk 'E18' ([string]$stOp.Text -eq 'Prêt.' -and [bool]$script:DetectNone) "aucun lecteur detecte : « $($stOp.Text) » aussi (la cause est au journal)"
# Controle apres ecriture : bilan court du controle
function Invoke-CheckEnd([int]$nWeak, [int]$max, [string]$lang = 'fr') {
    Reset-All; $script:Lang = $lang
    Invoke-LastRead; Invoke-LastRead
    $state = @{}; foreach ($k in '0.0', '0.1', '1.0', '1.1') { $state[$k] = @{ Bad = $false; Level = 0; Weak = $false; Unjudged = $false } }
    $weak = @(); if ($nWeak -gt 0) { $weak = @('0.1', '1.0', '1.1')[0..($nWeak - 1)] }
    $script:Rep = @{ State = $state; Weak = $weak; Rewrites = @{}; Ignore = @{}; SrcOver = @{}; Safety = $false; Max = $max; Round = $max; Target = '' }
    Complete-WriteCheck
    $o = @{ Posed = ($null -ne $script:SeqEnd); Level = [int]$script:LastCheck.Level }
    Update-SeqEnd
    $o.After = Get-St; $o.Ok = (Test-Icon 'ok'); $o.Idle = (Test-Icon 'idle'); $o.Err = (Test-Icon 'err')
    $script:Lang = 'fr'
    return $o
}
$w0 = Invoke-CheckEnd 0 2; $w2 = Invoke-CheckEnd 2 0; $w3 = Invoke-CheckEnd 3 2; $w0e = Invoke-CheckEnd 0 2 'en'
Chk 'E19' ($w0.Level -eq 0 -and $w0.After -eq 'Contrôle après écriture : 4/4 pistes saines  -  HH:mm:ss||False' -and $w0.Ok -and $w2.Level -eq 2 -and $w2.After -eq 'Contrôle après écriture : 2 piste(s) faible(s) : 0.1, 1.0  -  HH:mm:ss||False' -and $w2.Idle -and $w3.Level -eq 3 -and $w3.After -eq 'Contrôle après écriture : 3 piste(s) faible(s) : 0.1, 1.0, 1.1  -  HH:mm:ss||False' -and $w3.Err -and $w0e.After -eq 'Post-write check: 4/4 healthy tracks  -  HH:mm:ss||False') "controle apres ecriture (vraie Complete-WriteCheck) : « $($w0.After.Split('|')[0]) » (ok) ; « $($w2.After.Split('|')[0]) » (neutre) ; « $($w3.After.Split('|')[0]) » (erreur) ; « $($w0e.After.Split('|')[0]) »"
# En restauration, le verdict de la restauration remplace celui du controle
Reset-All
Invoke-LastRead; Invoke-LastRead; New-Rs
$state = @{}; foreach ($k in '0.0', '0.1') { $state[$k] = @{ Bad = $false; Level = 0; Weak = $false; Unjudged = $false } }
$script:Rep = @{ State = $state; Weak = @(); Rewrites = @{}; Ignore = @{}; SrcOver = @{}; Safety = $false; Max = 2; Round = 0; Target = '' }
Complete-WriteCheck
$t20 = [string]$script:SeqEnd.Text; $next20 = @($script:Calls | Where-Object { $_ -eq 'Invoke-RestoreNext' }).Count
Finish-Restore; Update-SeqEnd
Chk 'E20' ($t20 -eq 'Contrôle après écriture : 2/2 pistes saines' -and $next20 -eq 1 -and (Get-St) -eq 'Restauration réussie  -  HH:mm:ss||False') "controle dans une restauration : etat du controle pose (« $t20 »), puis remplace par le verdict de la restauration : « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') »"
# Calibration sur une disquette sacrifiee pendant une restauration, puis attente de la disquette de destination (vraie
# Enter-RestoreWait) : la consigne annule l etat de la calibration ; « Annuler » : « Pret. », qui reste au repos
Reset-All
Invoke-LastRead; Invoke-LastRead; New-Rs 'sector'
Set-HomeProgDone $calStd 'ok'; $posed22 = ($null -ne $script:SeqEnd)
$script:Restore.SwapBack = $true; $script:Restore.Override = $false
Enter-RestoreWait ''
$st22a = "$(Get-St)|$($null -eq $script:SeqEnd)|$([bool]$script:Restore.Waiting)"
Stop-Restore (T 'annulée par l''utilisateur'); Update-SeqEnd
Chk 'E22' ($posed22 -and $st22a -eq 'Restauration : changez de disquette, puis cliquez sur « Continuer ».||False|True|True' -and (Get-St) -eq 'Prêt.||False' -and (Test-Icon 'idle') -and $null -eq $script:SeqEnd) "calibration terminee puis attente de la disquette de destination : la consigne annule l etat de fin de la calibration ; « Annuler » : « $($stOp.Text) », garde au repos"
# Corrections de relecture (E23 a E25). Restauration arretee pendant la calibration de son lecteur : le minuteur (600,
# operation incomplete) et le bouton Arreter (540) appellent Stop-Restore, puis Stop-PrecompCalib. Close-Restore pose
# « Restauration echouee » ; le titre « Calibration arretee », que Set-HomeProgDone pose ensuite par Stop-PrecompCalib,
# ne le remplace pas (-IfNone). Cas du minuteur : disquette sacrifiee protegee en ecriture, gw erase rend le code 0 apres
# « Command Failed » : la derniere commande n est pas en echec, rien n abandonne l etat en attente. Vraies Stop-Restore,
# Fail-Restore, Show-RestoreResult, Close-Restore, Stop-PrecompCalib, Set-HomeProgDone et Update-SeqEnd
function Get-Pend { if ($script:SeqEnd) { return "$($script:SeqEnd.Text)|$($script:SeqEnd.Icon)" }; return 'aucun' }
function New-RsCal {
    # Restauration en copie secteur a l etape de la calibration du lecteur (test fin, ecriture lente, hors Accueil) ;
    # $etat, jamais $cal : au niveau du script, $cal et $script:Cal sont la meme variable (PowerShell ignore la casse)
    New-Rs 'sector'; $script:Restore.Stage = 'calib'; $script:Restore.Cur = 3
    $etat = @{ Mode = 'fine'; DiskOnly = $false; Home = $false; Family = 'std'; Slow = $true; PassesDone = 0 }
    $script:Cal = $etat
}
$t600 = [string]$src.Ast['600-minuteur-demarrage.ps1'].Extent.Text; $t540 = [string]$src.Ast['540-ui-accueil-restauration-barre.ps1'].Extent.Text
$iRsT = $t600.IndexOf('if ($script:Restore -and -not ($script:Rep -and $script:Rep.Round -gt 0)) { Stop-Restore $why }'); $iCalT = $t600.IndexOf('if ($script:Cal) { Stop-PrecompCalib -GwError }')
$iRsB = $t540.IndexOf("if (`$script:Restore) { Stop-Restore (T 'interrompue par l''utilisateur') }"); $iCalB = $t540.IndexOf('if ($script:Cal) { Stop-PrecompCalib }')
$okOrd23 = ($iRsT -ge 0 -and $iCalT -gt $iRsT -and $iRsB -ge 0 -and $iCalB -gt $iRsB)
Reset-All
Invoke-LastRead; New-RsCal
Start-Progress (T 'Effacement') @('erase', '--drive=0', '--hfreq', '--tracks=c=0-79:h=0-1'); Update-Progress 'Erasing c=0-79:h=0-1, revs=1'
Stop-Progress 0
$st23 = Get-St; $fail23 = [bool]$script:ProgFailed
Stop-Restore (T 'opération gw incomplète : disquette protégée en écriture, absente, ou lecteur en défaut ? Voir le journal')
$p23a = Get-Pend
Stop-PrecompCalib -GwError
$p23b = Get-Pend; $left23 = ($null -eq $script:Cal -and $null -eq $script:Restore -and $null -eq $script:ProgPlan)
Update-SeqEnd
Chk 'E23' ($okOrd23 -and $st23 -eq 'Effacement terminé(e)  -  HH:mm:ss||True' -and -not $fail23 -and $p23a -eq 'Restauration échouée|err' -and $p23b -eq 'Restauration échouée|err' -and $left23 -and (Get-St) -eq 'Restauration échouée  -  HH:mm:ss||False' -and (Test-Icon 'err') -and
           @($script:Calls | Where-Object { $_ -eq 'Append-Log Calibration precomp interrompue.' }).Count -eq 1) "restauration arretee pendant la calibration de son lecteur, effacement refuse par gw avec le code 0 : Stop-Restore puis Stop-PrecompCalib, dans l ordre du minuteur et du bouton Arreter (lu dans 600 et 540 : $okOrd23) ; fin de gw erase : « $($st23.Split('|')[0]) », derniere commande sans echec ; en attente apres Stop-Restore : « $p23a », apres la vraie Stop-PrecompCalib : « $p23b » ; au repos : « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') », icone d erreur, et non « Calibration arrêtée »"
# Bouton Arreter entre deux commandes (aucun gw en cours, derniere commande reussie) : meme ordre, meme resultat
Reset-All
Invoke-LastRead; Invoke-LastRead; New-RsCal
Stop-Restore (T 'interrompue par l''utilisateur'); Stop-PrecompCalib
$p24a = Get-Pend
Update-SeqEnd
$st24a = "$(Get-St)|$(Test-Icon 'err')"
# gw non lance (Reset-GwSequence, 110) : Stop-PrecompCalib d abord, qui arrete elle-meme la restauration : le verdict de
# la restauration, pose en dernier, remplace le titre de la calibration
Reset-All
Invoke-LastRead; Invoke-LastRead; New-RsCal
Stop-PrecompCalib -GwError
$p24b = Get-Pend; $left24 = ($null -eq $script:Restore)
# -IfNone seule : un etat en attente n est pas remplace, un etat absent est pose ; sans -IfNone, il est remplace. Seule
# la calibration arretee passe -IfNone : une calibration terminee remplace l etat en attente
Reset-All
Set-SeqEnd 'Premier' 'err'; Set-SeqEnd 'Second' 'idle' -IfNone; $p24c = Get-Pend
Set-SeqEnd 'Troisieme' 'ok'; $p24d = Get-Pend
Clear-SeqEnd; Set-SeqEnd 'Quatrieme' 'idle' -IfNone -NoTime; $p24e = "$(Get-Pend)|$([bool]$script:SeqEnd.NoTime)"
Set-HomeProgDone $calStd 'stop'; $p24f = Get-Pend
Set-HomeProgDone $calStd 'ok'; $p24g = Get-Pend
Clear-SeqEnd; Set-HomeProgDone $calStd 'stop'; $p24h = Get-Pend
Clear-SeqEnd
Chk 'E24' ($p24a -eq 'Restauration échouée|err' -and $st24a -eq 'Restauration échouée  -  HH:mm:ss||False|True' -and $p24b -eq 'Restauration échouée|err' -and $left24 -and $p24c -eq 'Premier|err' -and $p24d -eq 'Troisieme|ok' -and $p24e -eq 'Quatrieme|idle|True' -and
           $p24f -eq 'Quatrieme|idle' -and $p24g -eq 'Calibration terminée : courbe convergée|ok' -and $p24h -eq 'Calibration arrêtée|idle') "bouton Arreter entre deux commandes pendant la calibration d une restauration : « $($st24a.Split('|')[0]) », icone d erreur ; gw non lance (Stop-PrecompCalib d abord, qui arrete la restauration) : en attente « $p24b » ; Set-SeqEnd -IfNone ne remplace pas un etat en attente (« $p24c »), le pose s il n y en a pas (« $p24e ») ; calibration arretee : etat en attente garde (« $p24f »), pose sans etat en attente (« $p24h ») ; calibration terminee : etat remplace (« $p24g »)"
# Limite connue, gardee de la 12.10 : recherche des lecteurs interrompue sans lecteur trouve (carte absente, port occupe :
# vraie Complete-DriveProbe) : la recherche est abandonnee sans Complete-DriveDetect, la barre d etat garde « gw seek
# terminé(e) » ; le CHANGELOG ne promet « Prêt. » qu apres une recherche menee a son terme (cas D4)
Reset-All
$script:Detect = @{ Mode = 'auto'; Queue = (New-Object System.Collections.Queue); Found = @(); Tried = @('A'); Cur = 'A'; Drive = 'A' }
$script:GwCapture = New-Object System.Collections.Generic.List[string]; $script:GwCapture.Add('** FATAL ERROR:'); $script:GwCapture.Add('ligne d erreur factice : carte absente')
Start-Progress 'gw seek'; Stop-Progress 1; Stop-Progress 0
Complete-DriveProbe 1
$p25 = Get-Pend; $left25 = ($null -eq $script:Detect)
Update-SeqEnd
Chk 'E25' ($p25 -eq 'aucun' -and $left25 -and (Get-St) -eq 'gw seek terminé(e)  -  HH:mm:ss||False' -and (Test-Icon 'ok') -and @($script:Calls | Where-Object { $_ -like 'Append-Log Détection des lecteurs interrompue : *' }).Count -eq 1 -and @($script:Calls | Where-Object { $_ -eq 'Invoke-DriveProbe' }).Count -eq 0) "limite connue, comme en 12.10 : recherche des lecteurs interrompue sans lecteur trouve (vraie Complete-DriveProbe) : aucun etat pose, la barre d etat garde « $($stOp.Text -replace '\d\d:\d\d:\d\d$', 'HH:mm:ss') » ; la cause est au journal"
# Minuteur principal : Update-SeqEnd au premier niveau du gestionnaire, apres le traitement de la fin de gw
$tick =@($src.Ast['600-minuteur-demarrage.ps1'].FindAll({ param($x) $x -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]$x.Expression -eq '$timer' -and [string]$x.Member -eq 'Add_Tick' }, $true))
$tk = @(); if ($tick.Count -eq 1) { $tk = @($tick[0].Arguments[0].ScriptBlock.EndBlock.Statements) }
$iSeq = -1; $iGw = -1; $iRs = -1
for ($i = 0; $i -lt $tk.Count; $i++) {
    $t = [string]$tk[$i].Extent.Text
    if ($t -eq 'Update-SeqEnd') { $iSeq = $i }
    if ($t.StartsWith('if ($script:GwProc) {')) { $iGw = $i }
    if ($t -eq 'if ($script:Restore) { Update-RestoreProgress }') { $iRs = $i }
}
Chk 'E21' ($tick.Count -eq 1 -and $iSeq -gt $iGw -and $iGw -ge 0 -and $iSeq -eq $iRs + 1) "minuteur principal : Update-SeqEnd est une instruction du premier niveau du gestionnaire (rang $iSeq sur $($tk.Count)), apres le traitement de la fin de gw (rang $iGw) et l avancement de la restauration (rang $iRs)"

# ================================================================ B. affichage seulement
'--- B. la progression ne fait qu afficher (arbre syntaxique des modules)'
function Get-Owner($node, [string]$mod) {
    # Fonction de premier niveau qui contient le noeud ; « (module) » au niveau du script
    $x = $node; $own = "($($mod.Substring(0, 3)))"
    while ($null -ne $x) { if ($x -is $tFn) { $own = [string]$x.Name }; $x = $x.Parent }
    return $own
}
$stVars = @('ProgHead', 'ProgKey', 'ProgRetry', 'ProgDone', 'ProgDirty', 'ProgFailed', 'ProgCmd', 'ProgPlan', 'SeqEnd', 'SeqCmds', 'ProgCost')
$use = @{}; foreach ($v in $stVars) { $use[$v] = @{} }
$nullOnly = @{}
foreach ($mn in @($src.Ast.Keys)) {
    foreach ($v in @($src.Ast[$mn].FindAll({ param($x) $x -is $tVar }, $true))) {
        $p = [string]$v.VariablePath.UserPath
        if ($p -notmatch '^script:(.+)$') { continue }
        $name = @($stVars | Where-Object { $_ -eq $Matches[1] })
        if ($name.Count -ne 1) { continue }
        $own = Get-Owner $v $mn
        $use[$name[0]][$own] = $true
        # Affectation directe a $null (plan retire) : seul emploi admis hors de la progression
        $isNull = ($v.Parent -is $tAsg -and [object]::ReferenceEquals($v.Parent.Left, $v) -and [string]$v.Parent.Right.Extent.Text -eq '$null')
        if (-not $isNull) { $nullOnly["$($name[0])|$own"] = $false } elseif (-not $nullOnly.ContainsKey("$($name[0])|$own")) { $nullOnly["$($name[0])|$own"] = $true }
    }
}
$expUse = @{
    ProgHead   = '(040), Get-EndRuleTotal, Start-Progress, Update-Progress'
    ProgKey    = '(040), Get-GwProgress, Start-Progress, Update-Progress'
    ProgRetry  = '(040), Get-GwProgress, Start-Progress, Update-Progress'
    ProgDone   = '(040), Get-GwProgress, Start-Progress, Stop-Progress, Update-Progress'
    ProgDirty  = '(040), Show-GwProgress, Start-Progress, Stop-Progress, Update-Progress'
    ProgFailed = '(040), Set-GwLaunchFailedStatus, Start-Progress, Stop-Progress, Update-SeqEnd'
    ProgCmd    = '(040), Get-ProgPlanFrac, New-ProgPlan, Set-GwLaunchFailedStatus, Start-Progress, Stop-Progress, Update-Progress, Update-SeqEnd'
    ProgPlan   = '(040), Get-ProgPlanFrac, Invoke-CalibAnalysis, Invoke-ContentAnalysis, New-ProgPlan, Start-Progress, Stop-PrecompCalib, Stop-Progress, Update-CalibProgress, Update-Progress, Update-SeqEnd'
    SeqEnd     = '(040), Clear-SeqEnd, Set-GwLaunchFailedStatus, Set-SeqEnd, Start-Progress, Update-SeqEnd'
    SeqCmds    = '(040), Start-Progress, Update-SeqEnd'
    ProgCost   = '(040), Get-GwCmdUnits'
}
$badUse = @()
foreach ($v in $stVars) { $got = (@($use[$v].Keys | Sort-Object) -join ', '); if ($got -cne [string]$expUse[$v]) { $badUse += "$v : $got" } }
Chk 'B1' ($badUse.Count -eq 0) "les $($stVars.Count) variables de la progression ne sont lues ou ecrites que par les fonctions de la progression (110), l etat initial (040) et quatre fonctions de 270 et 276$(if ($badUse.Count) { ' ; ecarts : ' + ($badUse -join ' | ') })"
$outside = @('ProgPlan|Invoke-CalibAnalysis', 'ProgPlan|Invoke-ContentAnalysis', 'ProgPlan|Stop-PrecompCalib')
$guard = @($src.Fn['Update-CalibProgress'].Body.FindAll({ param($x) $x -is $tVar -and [string]$x.VariablePath.UserPath -eq 'script:ProgPlan' }, $true))
$guardTxt = if ($guard.Count -eq 1) { [string]$guard[0].Parent.Extent.Text } else { '' }
$x = $null; if ($guard.Count -eq 1) { $x = $guard[0]; while ($null -ne $x -and $x -isnot $tAsg) { $x = $x.Parent } }
$guardAsg = if ($x) { [string]$x.Extent.Text } else { '' }
Chk 'B2' (@($outside | Where-Object { $nullOnly[$_] -ne $true }).Count -eq 0 -and $guard.Count -eq 1 -and $guardAsg -ceq '$pf = if ($script:ProgPlan) { Get-ProgPlanFrac } else { $null }') "hors de 110 : le plan n est que remis a `$null (Invoke-CalibAnalysis, Invoke-ContentAnalysis, Stop-PrecompCalib) ; Update-CalibProgress ne le lit que dans « $guardAsg »"
# Appelants de chaque fonction de la progression
$fnProg = @('Get-GwLineInfo', 'Get-GwProgress', 'Show-GwProgress', 'Get-EndRuleTotal', 'Get-GwCmdUnits', 'New-ProgPlan', 'Get-ProgPlanFrac', 'Set-SeqEnd', 'Clear-SeqEnd', 'Update-SeqEnd', 'Get-CalibDoneTitle')
$callers = @{}; foreach ($f in $fnProg) { $callers[$f] = @{} }
$callNodes = @{}
foreach ($mn in @($src.Ast.Keys)) {
    foreach ($c in @($src.Ast[$mn].FindAll({ param($x) $x -is $tCmd }, $true))) {
        $cn = [string]$c.GetCommandName()
        if (-not $callers.ContainsKey($cn)) { continue }
        $own = Get-Owner $c $mn
        $callers[$cn][$own] = 1 + [int]$callers[$cn][$own]
        if (-not $callNodes.ContainsKey($cn)) { $callNodes[$cn] = @() }
        $callNodes[$cn] += $c
    }
}
$expCall = @{
    'Get-GwLineInfo'     = 'Update-Progress'
    'Get-GwProgress'     = 'Get-ProgPlanFrac, Show-GwProgress, Stop-Progress'
    'Show-GwProgress'    = 'Read-GwOutput, Stop-Progress, Update-Progress'
    'Get-EndRuleTotal'   = '(600)'
    'Get-GwCmdUnits'     = 'New-ProgPlan, Start-Progress'
    'New-ProgPlan'       = 'New-CalibPass, New-ContentPass, Start-CalibCondition'
    'Get-ProgPlanFrac'   = 'Update-CalibProgress'
    'Set-SeqEnd'         = 'Close-Restore, Complete-DriveDetect, Complete-WriteCheck, Set-HomeProgDone'
    'Clear-SeqEnd'       = 'Enter-RestoreWait'
    'Update-SeqEnd'      = '(600)'
    'Get-CalibDoneTitle' = 'Set-HomeProgDone, Update-HomeProgress'
}
$badCall = @()
foreach ($f in $fnProg) { $got = (@($callers[$f].Keys | Sort-Object) -join ', '); if ($got -cne [string]$expCall[$f]) { $badCall += "$f : $got" } }
Chk 'B3' ($badCall.Count -eq 0 -and [int]$callers['Get-EndRuleTotal']['(600)'] -eq 2 -and [int]$callers['Update-SeqEnd']['(600)'] -eq 1) "appelants des $($fnProg.Count) fonctions de la progression : affichage (barre d etat, barre de calibration), pose du plan, et le minuteur pour la regle de fin et la fin de sequence$(if ($badCall.Count) { ' ; ecarts : ' + ($badCall -join ' | ') })"
# Appels sans resultat lu : New-ProgPlan, Set-SeqEnd, Update-SeqEnd, Show-GwProgress sont des instructions entieres
$notStmt = @()
foreach ($f in 'New-ProgPlan', 'Set-SeqEnd', 'Clear-SeqEnd', 'Update-SeqEnd', 'Show-GwProgress') {
    foreach ($c in @($callNodes[$f])) {
        $pp = $c.Parent
        if (-not ($pp -is $tPipe -and @($pp.PipelineElements).Count -eq 1 -and ($pp.Parent -is $tBlock -or $pp.Parent -is $tNamed))) { $notStmt += "$f dans $([string]$c.Parent.Parent.Extent.Text)" }
    }
}
Chk 'B4' ($notStmt.Count -eq 0 -and @($callNodes['New-ProgPlan']).Count -eq 3 -and @($callNodes['Set-SeqEnd']).Count -eq 6) "New-ProgPlan (3 appels), Set-SeqEnd (6), Clear-SeqEnd, Update-SeqEnd et Show-GwProgress sont appelees comme des instructions entieres : aucun resultat n est lu, aucune condition n en depend$(if ($notStmt.Count) { ' ; ecarts : ' + ($notStmt -join ' | ') })"
# Update-CalibProgress : memes controles ecrits qu en 12.10 (valeur de la barre et libelle), memes commandes plus Get-ProgPlanFrac
function Get-FnWrites($fd) {
    return @($fd.Body.FindAll({ param($x) $x -is $tAsg -and $x.Left -is $tMem }, $true) | ForEach-Object { [string]$_.Left.Extent.Text } | Sort-Object -Unique)
}
function Get-FnCmds($fd) { return @($fd.Body.FindAll({ param($x) $x -is $tCmd }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Sort-Object -Unique) }
$wrC = Get-FnWrites $src.Fn['Update-CalibProgress']; $cmC = Get-FnCmds $src.Fn['Update-CalibProgress']
Chk 'B5' (($wrC -join ', ') -ceq '$lblWCal.Text, $pbWCal.Value' -and ($cmC -join ', ') -ceq 'Format-CalDuration, Get-Date, Get-ProgPlanFrac, Get-WarmupLeft, Measure-Object, T') "Update-CalibProgress n ecrit que $($wrC -join ' et ') ; commandes : $($cmC -join ', ')"
# Fonctions de la progression : seuls les controles de la barre d etat sont ecrits
$wrAll = @{}
foreach ($f in 'Start-Progress', 'Update-Progress', 'Stop-Progress', 'Get-GwLineInfo', 'Get-GwProgress', 'Show-GwProgress', 'Get-EndRuleTotal', 'Get-GwCmdUnits', 'New-ProgPlan', 'Get-ProgPlanFrac', 'Set-SeqEnd', 'Clear-SeqEnd', 'Update-SeqEnd') {
    foreach ($w in (Get-FnWrites $src.Fn[$f])) { $wrAll[($w -replace '^\$(script:)?', '' -replace '\..*$', '')] = $true }
}
$cmAll = @{}
foreach ($f in 'Get-GwLineInfo', 'Get-GwProgress', 'Show-GwProgress', 'Get-EndRuleTotal', 'Get-GwCmdUnits', 'New-ProgPlan', 'Get-ProgPlanFrac', 'Set-SeqEnd', 'Clear-SeqEnd', 'Update-SeqEnd') { foreach ($c in (Get-FnCmds $src.Fn[$f])) { $cmAll[$c] = $true } }
Chk 'B6' ((@($wrAll.Keys | Sort-Object) -join ', ') -ceq 'CleanRun, p, pc, ProgPlan, stBar, stOp, stTrack' -and (@($cmAll.Keys | Sort-Object) -join ', ') -ceq 'Get-AppBusy, Get-Date, Get-GwCmdUnits, Get-GwProgress, Get-SpecCount, New-Object, T, Where-Object') "fonctions de la progression : membres ecrits $(@($wrAll.Keys | Sort-Object) -join ', ') (barre d etat et etat de la progression) ; commandes des fonctions nouvelles : $(@($cmAll.Keys | Sort-Object) -join ', ') : rien ne lance, n arrete ni ne juge une operation"
# Start-Gw et les passes : la commande lancee n est pas touchee
$sgCalls = @($src.Fn['Start-Gw'].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Start-Progress' }, $true))
$sgArg = if ($sgCalls.Count -eq 1 -and $sgCalls[0].CommandElements.Count -eq 3) { [string]$sgCalls[0].CommandElements[2].Extent.Text } else { '' }
$tNew = [string]$src.Text['New-CalibPass']; $tCond = [string]$src.Text['Start-CalibCondition']; $tCont = [string]$src.Text['New-ContentPass']
$ordNew = @($tNew.IndexOf('Add-CalibWriteCmds $cal $writes'), $tNew.IndexOf('$cal.ReadArgs  ='), $tNew.IndexOf('New-ProgPlan (@($cal.Writes.ToArray()) + ,$cal.ReadArgs)'), $tNew.IndexOf('$script:Chain.Clear()'))
$ordCond = @($tCond.IndexOf('Add-CalibWriteCmds $cal @(,@($cal.CondTSpec, $cal.Spec))'), $tCond.IndexOf('New-ProgPlan @($cal.Writes.ToArray())'), $tCond.IndexOf('$script:Chain.Clear()'))
$ordCont = @($tCont.IndexOf('$ct.Todo.Insert(0, @{ Erase'), $tCont.IndexOf('New-ProgPlan (@(foreach ($w in $ct.Todo)'), $tCont.IndexOf('Invoke-ContentWriteNext'))
function Test-Order($a) { for ($i = 0; $i -lt $a.Count; $i++) { if ($a[$i] -lt 0 -or ($i -gt 0 -and $a[$i] -le $a[$i - 1])) { return $false } }; return $true }
Chk 'B7' ($sgArg -ceq '$(if ($warmRead -or $script:Detect) { $null } else { $gwArgs })' -and (Test-Order $ordNew) -and (Test-Order $ordCond) -and (Test-Order $ordCont)) "Start-Gw transmet ses arguments a Start-Progress, sauf prechauffage et detection (« $sgArg ») ; New-CalibPass, Start-CalibCondition et New-ContentPass posent le plan apres avoir construit leurs commandes et avant de lancer la premiere"

# ================================================================ I. textes
'--- I. textes : entrees anglaises des cles nouvelles'
$newKeys = [ordered]@{ 'effacement' = 'erasing'; 'Restauration réussie' = 'Restore succeeded'; 'Restauration réussie avec réserve' = 'Restore succeeded with a reservation'; 'Restauration échouée' = 'Restore failed' }
$t019 = [System.IO.File]::ReadAllText((Join-Path $m '019-i18n-1211.ps1'), [System.Text.Encoding]::UTF8)
$older = ''
foreach ($f in @(Get-ChildItem -LiteralPath $m -Filter '01*-i18n*.ps1' -File | Where-Object { $_.Name -ne '019-i18n-1211.ps1' })) { $older += [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) }
$badKey = @()
foreach ($k in $newKeys.Keys) {
    $def = "`$script:I18n['$k'] = '$($newKeys[$k])'"
    if ([string]$script:I18n[$k] -cne [string]$newKeys[$k] -or -not $t019.Contains($def) -or $older.Contains("`$script:I18n['$k']") -or $older.Contains("`$script:I18n[`"$k`"]")) { $badKey += $k }
}
Chk 'I1' ($badKey.Count -eq 0) "les $($newKeys.Count) cles nouvelles ont leur entree anglaise dans 019, mot pour mot, et ne redefinissent aucune cle de 010 a 018$(if ($badKey.Count) { ' ; ecarts : ' + ($badKey -join ', ') })"
# Cles comparees a la casse pres (« effacement » n est pas « Effacement », libelle d une commande gw dans Start-Gw)
$usedIn = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
$keyList = @($newKeys.Keys)
foreach ($mn in @($src.Ast.Keys | Sort-Object)) {
    foreach ($c in @($src.Ast[$mn].FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'T' -and $x.CommandElements.Count -eq 2 -and $x.CommandElements[1] -is $tStr }, $true))) {
        $k = [string]$c.CommandElements[1].Value
        if ($keyList -ccontains $k) { $usedIn[$k] = (@($usedIn[$k]) + @(Get-Owner $c $mn) | Where-Object { $_ }) -join ', ' }
    }
}
Chk 'I2' ($usedIn['effacement'] -ceq 'Update-CalibProgress' -and $usedIn['Restauration réussie'] -ceq 'Close-Restore' -and $usedIn['Restauration réussie avec réserve'] -ceq 'Close-Restore' -and $usedIn['Restauration échouée'] -ceq 'Close-Restore' -and [string]$script:I18n['Contrôle après écriture : {0}'] -eq 'Post-write check: {0}' -and [string]$script:I18n['Prêt.'] -eq 'Ready.') "cles nouvelles lues par T() dans Update-CalibProgress (« effacement ») et Close-Restore ; controle et recherche des lecteurs : cles existantes (« Contrôle après écriture : {0} », « Prêt. »)"

# ================================================================ D. documents
'--- D. CHANGELOG et README'
function Read-Doc([string]$rel) { return [System.IO.File]::ReadAllText((Join-Path $Wt $rel), [System.Text.Encoding]::UTF8) }
$cl = Read-Doc 'CHANGELOG.md'
$i11 = $cl.IndexOf('## [12.11]'); $i10 = $cl.IndexOf('## [12.10]')
$sec = if ($i11 -ge 0 -and $i10 -gt $i11) { $cl.Substring($i11, $i10 - $i11) } else { '' }
function Get-Rub([string]$title) {
    $a = $sec.IndexOf("### $title"); if ($a -lt 0) { return '' }
    $b = $sec.IndexOf("`n### ", $a + 4); if ($b -lt 0) { $b = $sec.Length }
    return $sec.Substring($a, $b - $a)
}
function Get-Entry([string]$rub, [string]$title) {
    foreach ($l in ($rub -split "`n")) { if ($l.StartsWith("- **$title")) { return $l } }
    return ''
}
$am = Get-Rub 'Améliorations'; $co = Get-Rub 'Corrections'; $dv = Get-Rub 'Pour les développeurs'
$en1 = Get-Entry $am 'Progression au rythme des pistes.'; $en2 = Get-Entry $am 'Conversion.'; $en3 = Get-Entry $co "Barre d'état en fin d'opération."; $en4 = Get-Entry $co 'Écriture et effacement.'
Chk 'D1' ($en1 -and $en2 -and $en3 -and $en4 -and $en1.Contains('avancent avec les pistes que gw efface, écrit puis relit') -and $en1.Contains('« effacement »') -and $en2.Contains('la piste en cours et le total pendant une conversion') -and $en3.Contains('annonce le résultat de l''opération') -and $en3.Contains('« Prêt. »') -and $en4.Contains('compte les pistes terminées')) "CHANGELOG 12.11 : « Progression au rythme des pistes » et « Conversion » en Améliorations, « Barre d'état en fin d'opération » et « Écriture et effacement » en Corrections"
$rxDur = '\d\s*(s|secondes?|min|minutes?|ms)\b'
$durs = @(@($en1, $en2, $en3, $en4) | Where-Object { $_ -match $rxDur })
$devEn = @($dv -split "`n" | Where-Object { $_ -like '- Progression par piste*' })
Chk 'D2' ($durs.Count -eq 0 -and $devEn.Count -eq 1 -and $devEn[0].Contains('un seul utilisateur') -and $devEn[0].Contains('$script:ProgCost') -and $devEn[0].Contains('Get-EndRuleTotal') -and $devEn[0].Contains('Update-SeqEnd') -and @(@($en1, $en2, $en3, $en4, $devEn[0]) | Where-Object { $_ -match 'matériel' }).Count -eq 0) "les quatre entrees n annoncent aucune duree ($($durs.Count)) ; « Pour les développeurs » dit que les poids viennent des journaux d un seul utilisateur et nomme la regle de fin et la fin de sequence ; aucune entree du lot ne dit un comportement verifie sur materiel"
$rm = Read-Doc 'src\modules\README.md'; $rt = Read-Doc 'tests\README.md'
Chk 'D3' ($rm.Contains('`Get-GwLineInfo`') -and $rm.Contains('`Get-ProgPlanFrac`') -and $rm.Contains('`Update-SeqEnd`') -and $rm.Contains('`Get-EndRuleTotal`') -and $rt.Contains('| `logic-progression` |')) "README des modules : fonctions de la progression (110) ; README des tests : ligne de logic-progression"
# D4 (corrections de relecture) : l exemple de compteur de l entree « Écriture et effacement » est rejoue par les vraies
# Start-Progress et Update-Progress : pendant la piste citee d une ecriture, puis d un effacement, du nombre de pistes
# annonce, la barre d etat affiche ce texte au caractere pres (l exemple « piste 12.1  (24/160, 15 %) » etait faux : 25
# pistes sont terminees pendant la piste 12.1). « 100 % a la fin d une commande qui a traite toutes les pistes
# annoncees » : commande complete 100 %, image plus courte que le jeu annonce (code 0) : compte reel. « Prêt. » apres
# une recherche des lecteurs menee a son terme seulement (cas E17, E18 et E25)
$mEx = [regex]::Match($en4, '« (piste (\d+)\.([01])  \((\d+)/(\d+), (\d+) %\)) »')
$exTxt = ''; $exW = ''; $exE = ''; $exFull = ''; $exShort = ''
if ($mEx.Success -and ([int]$mEx.Groups[5].Value % 2) -eq 0 -and [int]$mEx.Groups[5].Value -ge 2) {
    $exTxt = [string]$mEx.Groups[1].Value; $exC = [int]$mEx.Groups[2].Value; $exH = [int]$mEx.Groups[3].Value; $exN = [int]([int]$mEx.Groups[5].Value / 2)
    $exSet = "c=0-$($exN - 1):h=0-1"; $exArgW = [string[]]@('write', '--drive=A', "--tracks=$exSet", '"x.adf"'); $exArgE = [string[]]@('erase', '--drive=A', "--tracks=$exSet")
    foreach ($op in 'write', 'erase') {
        Reset-All
        # Sans @() autour de l appel : New-TrackLines rend son tableau en un seul objet
        $ls = New-TrackLines $op 0 $exC @(0, 1); if ($exH -eq 0) { $ls = [string[]]@($ls | Select-Object -First ($ls.Count - 1)) }
        if ($op -eq 'write') { Start-Progress (T 'Écriture') $exArgW; Update-Progress "Writing $exSet" }
        else { Start-Progress (T 'Effacement') $exArgE; Update-Progress "Erasing $exSet, revs=1" }
        Push-Lines $ls
        if ($op -eq 'write') { $exW = [string]$stTrack.Text } else { $exE = [string]$stTrack.Text }
    }
    # Ecriture complete, puis image de la moitie des cylindres annonces : compteur apres la fin de la commande (code 0)
    Reset-All
    Start-Progress (T 'Écriture') $exArgW; Update-Progress "Writing $exSet"
    Push-Lines (New-TrackLines 'write' 0 ($exN - 1) @(0, 1)); Stop-Progress 0; $exFull = [string]$stTrack.Text
    Reset-All
    Start-Progress (T 'Écriture') $exArgW; Update-Progress "Writing $exSet"
    Push-Lines (New-TrackLines 'write' 0 ([int]($exN / 2) - 1) @(0, 1)); Stop-Progress 0; $exShort = [string]$stTrack.Text
    Reset-All
}
Chk 'D4' ($mEx.Success -and $exTxt -and $exW -ceq $exTxt -and $exE -ceq $exTxt -and $en4.Contains("il atteint 100 % à la fin d'une commande qui a traité toutes les pistes annoncées") -and $exFull -match '\(\d+/\d+, 100 %\)$' -and $exShort -match ', 50 %\)$' -and
          $en3.Contains('Après une recherche des lecteurs menée à son terme, elle revient à « Prêt. »')) "CHANGELOG, « Écriture et effacement » : l exemple « $exTxt » est le compteur que la barre d etat affiche pendant cette piste (ecriture : « $exW » ; effacement : « $exE ») ; fin d une commande complete : « $exFull » ; image plus courte que le jeu annonce : « $exShort » ; « Barre d'état en fin d'opération » : « Prêt. » apres une recherche des lecteurs menee a son terme"

# ================================================================ Q. equivalence avec la 12.10 (-Before)
'--- Q. equivalence avec la 12.10 (-Before)'
if (-not $Before) {
    'Q1-Q3    saute : sans -Before <copie de la source de la 12.10>, l equivalence avec la 12.10 n est pas rejouee (S7, S9, S10, S13 et C1 en gardent les valeurs)'
} else {
    $mb = Join-Path $Before 'src\modules'
    if (-not (Test-Path -LiteralPath (Join-Path $mb '110-fn-coeur-gw.ps1'))) { throw "source d avant introuvable sous $Before" }
    $old = Get-ModuleSet $mb
    function Get-Renamed([string]$name, [string]$new) {
        $t = [string]$old.Text[$name]; $p = "function $name"
        if (-not $t.StartsWith($p)) { throw "fonction $name d avant introuvable" }
        return ("function $new" + $t.Substring($p.Length))
    }
    $po = @((Get-Renamed 'Start-Progress' 'Start-ProgressOld'), (Get-Renamed 'Update-Progress' 'Update-ProgressOld'), (Get-Renamed 'Stop-Progress' 'Stop-ProgressOld'), (Get-Renamed 'Update-CalibProgress' 'Update-CalibProgressOld'))
    $genOld = Join-Path $here 'gen-progression-avant.ps1'
    [System.IO.File]::WriteAllText($genOld, (($po -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    . $genOld
    $sets = @(
        @('lecture', (T 'Lecture'), (@($hR) + @(New-TrackLines 'read' 0 81 @(0, 1)))),
        @('lecture avec essais', (T 'Lecture'), (@($hR, 'T0.0: Raw Flux (1 flux in 1.00ms)', 'T0.1: AmigaDOS (9/11 sectors) from Raw Flux (1 flux in 1.00ms) (Retry #1.2)', 'T0.1: AmigaDOS (11/11 sectors) from Raw Flux (1 flux in 1.00ms)', 'T1.0: Giving up: 11 sectors missing'))),
        @('ecriture avec pre-effacement', (T 'Écriture'), (@('Writing c=0-81:h=0') + @(New-TrackLines 'pre' 0 81 @(0)) + @('All tracks verified'))),
        @('effacement', (T 'Effacement'), (@($hE) + @(New-TrackLines 'erase' 0 81 @(0, 1)))),
        @('lecture arretee', (T 'Lecture'), (@($hR) + @(New-TrackLines 'read' 0 9 @(0, 1)) + @('Command Failed: GetFluxStatus: No Index'))),
        @('sans annonce', (T 'Lecture'), (@(New-TrackLines 'read' 0 3 @(0, 1)))),
        @('conversion', 'Conversion', (@($hC) + @(New-TrackLines 'conv' 0 79 @(0, 1))))
    )
    $difState = @(); $difText = @(); $nCmp = 0; $convOld = -1
    foreach ($s in $sets) {
        Reset-All; Start-ProgressOld $s[1]
        $txtOld = New-Object System.Collections.Generic.List[string]
        foreach ($l in $s[2]) { Update-ProgressOld $l; $txtOld.Add("$(Get-Bar)|$($stTrack.Text)") }
        $o = "$($script:ProgTotal)|$(@($script:ProgSeen | Sort-Object) -join ',')"; $ro = Get-GwEndRule 0 $false $false $false ([int]$script:ProgTotal) ([int]$script:ProgSeen.Count) $null '' $false
        Stop-ProgressOld 0; $endOld = Get-St
        Reset-All; Start-Progress $s[1]
        $txtNew = New-Object System.Collections.Generic.List[string]
        foreach ($l in $s[2]) { Update-Progress $l; $txtNew.Add("$(Get-Bar)|$($stTrack.Text)") }
        $n = "$($script:ProgTotal)|$(@($script:ProgSeen | Sort-Object) -join ',')"; $rn = Invoke-TimerEndRule 0 $false $false
        Stop-Progress 0; $endNew = Get-St
        $nCmp++
        if ($s[0] -eq 'conversion') { $convOld = [int]$o.Split('|')[0]; if ($o.Split('|')[1] -ne $n.Split('|')[1] -or [bool]$ro.Incomplete -ne [bool]$rn.Incomplete) { $difState += $s[0] }; continue }
        if ($o -ne $n -or [bool]$ro.Incomplete -ne [bool]$rn.Incomplete -or [bool]$ro.Next -ne [bool]$rn.Next) { $difState += $s[0] }
        if ($s[0] -like 'lecture*' -or $s[0] -eq 'sans annonce') { if (($txtOld -join "`n") -ne ($txtNew -join "`n") -or $endOld -ne $endNew) { $difText += $s[0] } }
    }
    Chk 'Q1' ($difState.Count -eq 0 -and $convOld -eq 0) "etat lu par la regle de fin (total annonce, pistes vues) et verdict de la regle identiques a la 12.10 sur $nCmp series de lignes$(if ($difState.Count) { ' ; ecarts : ' + ($difState -join ', ') }) ; conversion : total de la 12.10 = $convOld = Get-EndRuleTotal"
    Chk 'Q2' ($difText.Count -eq 0) "lectures : barre et compteur identiques a la 12.10 a chaque ligne, et a la fin$(if ($difText.Count) { ' ; ecarts : ' + ($difText -join ', ') })"
    $difCal = @(); $nCal = 0
    foreach ($ph in 'write', 'read') {
        foreach ($cond in $false, $true) {
            foreach ($run in $false, $true) {
                if ($run -and -not $cond) { continue }
                Reset-All
                $script:Cal = New-CalState; $script:Cal.Phase = $ph; $script:Cal.Cond = $cond; $script:Cal.CondRun = $run; $script:Cal.CondTracks = $(if ($cond) { 164 } else { 0 })
                Update-CalibProgressOld; $o = "$($pbWCal.Value)|$($lblWCal.Text)"
                $pbWCal.Value = 0; $lblWCal.Text = ''
                Update-CalibProgress; $n = "$($pbWCal.Value)|$($lblWCal.Text)"
                $nCal++; if ($o -ne $n) { $difCal += "$ph/$cond/$run" }
            }
        }
    }
    Chk 'Q3' ($difCal.Count -eq 0 -and $nCal -eq 6) "barre de la calibration sans plan : valeur et libelle identiques a la 12.10 sur $nCal etats (phases, conditionnement)$(if ($difCal.Count) { ' ; ecarts : ' + ($difCal -join ', ') })"
    $script:Cal = $null
}

$nk = if ($script:Fail) { ' ; NON CONFORMES : ' + ($script:FailIds -join ', ') } else { '' }
"=== bilan logic-progression : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
exit $(if ($script:Fail) { 1 } else { 0 })
