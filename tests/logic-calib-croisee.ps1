# 12.10 RC8 (10/11/2026, v1210\rc8\make_rc8_cross.py) : copie de logic-1210-cross-j ; bouchon de Get-CalibEnvBlock.
param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci, [int]$Seed = 1210)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-cross-k) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Harnais cal2-commun.ps1 a cote du test ; variables locales « ci » renommees
# ($calI, $crI) : Ci est un parametre de l en-tete commun.
# Copie adaptee par la correction fix2 de la RC5 (10/11/2026, v1210\rc5\fix2\make_fix2_copies.py) : bouchons d Update-CurveButton et d Update-WLevelUi, appeles par Complete-PrecompCalib a la fin d une calibration croisee.
# 12.10 (v1210\croisee, etape 2) : calibration croisee (conception-croisee.md § 3) : la source (lecteur du bandeau) ecrit le
# motif, la cible le relit, la disquette passe de l un a l autre a la main. Fonctions reelles de 150, 220, 230, 240, 250, 270
# et 280 (Format-LevelNum de 260, Solve-ContentLinear de 274, Format-CylRanges de 276, Get-GwDriveKey de 110,
# Get-HomeProgTitle de 200) extraites par l arbre syntaxique (gen-1210-cross.ps1) ; etat de la calibration construit par
# l affectation reelle de Start-PrecompCalib (New-Cal2CalState), puis par son bloc « if ($cx) » reel (Set-Cal2CrossState) ;
# avertissement croise par son bloc reel (Get-Cal2CrossConfirm). Remplacants nommes : fenetres (Show-TimedConfirm : invites
# d echange repondues par OK ou Annuler selon le scenario ; Show-CalibReview, Show-CurvesWindow, Show-PrecompCurve,
# Show-AppMessage, Show-CrossCalibDialog), configuration (Backup-ConfigBeforeRef, Save-Config), gw (Start-Gw enregistre la
# commande et le lecteur ou se trouve la disquette ; relecture simulee : pistes de New-SimPass, modele de logic-129-cal2-e2e),
# Invoke-NextChainStep (une etape de la file par appel, comme l application). Aucun gw, aucune application, aucune fenetre.
# Blocs : U unites ; S blocs de Start-PrecompCalib ; C Start-CrossCalib ; K commandes et invites par la file reelle (analyse
# factice de 3 passes) ; E calibration croisee simulee de bout en bout (analyse et fin reelles, courbe « A>0|std_hN ») ;
# P barre de progression ; H titre de l Accueil. Relecture de l etape 2 : R texte « Conserver la courbe » de la fenetre de
# decision (affectation reelle de $head de Show-CalibReview, 250) ; I configuration (Import-DriveCurves et Export-DriveCurves
# reels, 120 : cle croisee sans champs drive ni target, deux lecteurs, vue par lecteur) ; D copie d etat et retablissement
# sur des cles croisees (Get-CalibSnapshot, Restore-CalibState reels), fenetre Courbe sans courbe (Show-CurvesWindow reel).
# Petits defauts du banc (09/11/2026) : copie adaptee de etape2\logic-1210-cross.ps1, qui la remplace dans la campagne.
# Adaptes : C6 et l etat croise du bloc S (origine des cylindres sans parentheses : « 80 cylindres, faute d image de
# cette famille dans l onglet Ecriture »). Ajoutes : S3b (ligne « Cylindres de test » a un seul niveau de parentheses),
# K2b (annulation a l invite d echange : aucun Save-Config), K2c (statique : ni Invoke-CalibSwap, ni Stop-PrecompCalib,
# ni Set-HomeProgDone n appellent Save-Config ; Start-Gw l appelle une fois, avant chaque commande gw).
# Correction fixB de la RC5 (10/11/2026, v1210\rc5\fixB) : copie adaptee de v1210\rc2\fix2\logic-1210-cross-g, qui la remplace dans la
# campagne : Start-CrossCalib (270) tire l image de l onglet de Get-CalibImageCheck (260, remplacant selon le
# scenario : famille ImgFam, refus ImgWhy et ImgScope) ; S2 attend la ligne de journal de la calibration croisee qui dit le
# controle apres ecriture relu par le lecteur qui ecrit ; ajoutes : C11 (image refusee par le controle : fenetre « aucune
# image calibrable », image de geometrie), C12 (secteurs durs : refus avant la fenetre). Autres cas inchanges.
# Correction fix1 de la RC5 (10/11/2026, v1210\rc5\fix1) : copie adaptee de v1210\rc5\fixB\logic-1210-cross-h, qui la
# remplace dans la campagne : Start-CrossCalib (270) tire les reglages refuses de Get-CalibSettingBlock (260, remplacant
# selon le scenario : SetBlock), avant le controle de l image. C12 joue le refus par SetBlock ; ajoute : C13 (secteurs
# durs et image refusee : refus avant la fenetre, sans controle de l image). Autres cas inchanges.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Correction tour 2 de la relecture des captures (10/11/2026, v1210\rc2\fix2) : copie adaptee de v1210\doc\logic-1210-cross-g,
# qui la remplace dans la campagne. P2 : texte court de l attente d un echange (270 Update-CalibProgress, une ligne de
# lblWCal a la taille minimale de la fenetre).
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
. (Join-Path $PSScriptRoot 'cal2-commun.ps1')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$simDir = Join-Path $here 'sim-cross'
New-Item -ItemType Directory -Force $simDir | Out-Null

function Get-CrossBlockFn([string]$m, [string]$kind) {
    # Blocs « if ($cx) » de Start-PrecompCalib (270), recopies tels quels dans une fonction de travail : 'state' (etat
    # croise et journal, apres le litteral $script:Cal) ou 'confirm' (avertissement frmCalibConfirm, reponse $ans)
    $ast = Get-Cal2Ast (Join-Path $m '270-fn-calib-complete.ps1')
    $fd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Start-PrecompCalib' }, $false))
    if ($fd.Count -ne 1) { throw 'Start-PrecompCalib introuvable' }
    $ifs = @($fd[0].Body.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.IfStatementAst] -and $_.Clauses[0].Item1.Extent.Text -eq '$cx' })
    $sel = @($ifs | Where-Object { if ($kind -eq 'state') { $_.Extent.Text -like '*Cal.Cross = @{*' } else { $_.Extent.Text -like "*'frmCalibConfirm'*" } })
    if ($sel.Count -ne 1) { throw "bloc if (`$cx) '$kind' de Start-PrecompCalib : $($sel.Count) trouve(s)" }
    if ($kind -eq 'state') { return ('function Set-Cal2CrossState($cx, $do, $Geom, $chk, $famTxt, $modeTxt, $img, $pat, $cylList, $cylSrc, $nCyl) {' + "`r`n" + $sel[0].Extent.Text + "`r`n}") }
    return ('function Get-Cal2CrossConfirm($cx, $redo, $do, $fb, $Intro, $body, $wear, $nPassEst, $fine, $toWrite, $target, $cfSec, $swapLabel, $auto, $choice, $family, $minutes, $nCyl, $minDisk, $mxDisk) {' + "`r`n" + $sel[0].Extent.Text + "`r`n" + 'return $ans' + "`r`n}")
}
function New-CrossGen([string]$m, [string]$out) {
    $parts = New-Object System.Collections.Generic.List[string]; $found = @{}
    foreach ($f in '150-fn-pistes-densite.ps1', '220-fn-profil-precomp.ps1', '230-fn-calib-courbe.ps1', '240-fn-calib-mesure.ps1', '250-fn-calib-fenetres.ps1', '270-fn-calib-complete.ps1', '280-fn-calib-surface.ps1') { Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m $f)) @('*') $found $f }
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '260-fn-calib-rapide.ps1')) @('Format-LevelNum') $found '260'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '274-fn-contenu-calcul.ps1')) @('Solve-ContentLinear') $found '274'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '276-fn-contenu-mesure.ps1')) @('Format-CylRanges') $found '276'
    # 12.11 (lot L8) : progression par piste : les vraies Start-CalibCondition et New-CalibPass posent le plan de leur etape
    # (New-ProgPlan, poids de Get-GwCmdUnits et de $script:ProgCost) ; Update-CalibProgress reel lit Get-ProgPlanFrac
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '110-fn-coeur-gw.ps1')) @('Get-GwDriveKey', 'Get-SpecCount', 'Get-GwCmdUnits', 'New-ProgPlan', 'Get-GwProgress', 'Get-ProgPlanFrac') $found '110'
    # 12.11 (lot LN-a) : Get-CalibDriveArgsFor donne a --drive la connexion du lecteur (Get-DriveConn, 112, avec les codes
    # du reglage drive de 040) ; sans lecteur enregistre, une connexion y rend elle-meme : aucun attendu ne change
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '112-fn-lecteurs.ps1')) @('Get-DriveConn') $found '112'
    foreach ($s in (Get-Cal2Assign (Join-Path $m '040-etat-formats.ps1') @('$script:ProgCost', '$script:SettingDefs'))) { $parts.Add($s) }
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '200-fn-accueil-calibration.ps1')) @('Get-HomeProgTitle') $found '200'
    $parts.Add((Get-Cal2Renamed (Get-Cal2FnDefs (Join-Path $m '270-fn-calib-complete.ps1')) 'Update-CalibProgress' 'Update-CalibProgressReal'))
    $parts.Add((Get-Cal2CalStateFn $m))
    $parts.Add((Get-CrossBlockFn $m 'state')); $parts.Add((Get-CrossBlockFn $m 'confirm'))
    foreach ($s in (Get-Cal2Consts $m)) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '565-etat-contenu.ps1') @('$script:EraseEstTrack'))) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '560-etat-calibration.ps1') @('$script:CurveKeys', '$script:DriveActivity', '$script:DriveCurves', '$script:PrecompCurves', '$script:LevelShifts'))) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '040-etat-formats.ps1') @('$script:PrecompStd', '$script:PrecompLong', '$script:PrecompStdDefault', '$script:PrecompLongDefault'))) { $parts.Add($s) }
    Write-Cal2Gen $out $parts
    return $found
}
$mods = Get-Cal2Modules $Wt
$gen = Join-Path $here 'gen-1210-cross-k.ps1'
$fn = New-CrossGen $mods $gen
Test-Cal2Missing @('Get-CalibDriveArgsFor', 'Get-CalibStoreDrive', 'Split-CrossDrive', 'Get-CrossCalibTargets', 'Get-CrossSwapEstimate', 'Invoke-CalibSwap', 'Start-CrossCalib', 'Show-CrossCalibDialog', 'Get-DriveFamilyCurves', 'Show-CurvesWindow', 'Get-DriveCurveLabel', 'Set-DriveCurve', 'Get-CalibSnapshot') $fn
$genCf = Join-Path $here 'gen-1210-cross-cf.ps1'
Write-Cal2Gen $genCf @((Get-Cal2CurveFit $mods))
. $genCf
"logic-1210-cross : $($fn.Count) fonctions (wt-1210) ; graine $Seed ; PowerShell $($PSVersionTable.PSVersion)"
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Get-LogIdx($log, [string]$like) { for ($i = 0; $i -lt @($log).Count; $i++) { if ($log[$i] -like $like) { return $i } }; return -1 }
function Get-LogN($log, [string]$like) { return @(@($log) | Where-Object { $_ -like $like }).Count }

# ---------------------------------------------------------------- gw simule (modele de logic-129-cal2-e2e : besoin du lecteur A, dent)
function Get-SimZ([int]$c, [int]$h) { $z = Get-NeedA $c $h $true; if ($script:SimHd) { $z = 0.5 * $z }; return $z }
function New-SimTrack([double]$w, [double]$z, [int]$h, [double]$extra) {
    $kap = 6.4; $lam = 40.0
    if ($script:SimHd) { $kap = 3.2; $lam = 20.0 }
    $sg = if ($h -eq 0) { 2.0 } else { 1.75 }
    $s = (Get-Cal2Shift $w $z 1.55 $kap $lam) + $extra + $sg * (Get-N01)
    $l = @()
    foreach ($rev in 1..3) { $l += [pscustomobject]@{ Shift = $s + 0.3 * (Get-U11); ShiftSE = 0.95; Jitter = 40.0; R3 = 1.5; R4 = 2.0; OutOfClass = 0; NFlux = 50000 } }
    return ,$l
}
function Get-UnitHeads($u) { if ($null -eq $u.Head) { return @(0, 1) }; return @([int]$u.Head) }
function New-SimPass {
    # Pistes relues a l etape en cours (passe de mesure, encadrement, verification), comme logic-129-cal2-e2e
    $cal = $script:Cal; $tr = @{}
    if ($cal.Stage -eq 'coarse') {
        $a0 = Get-N01; $a1 = 0.35 * $a0 + [math]::Sqrt(1.0 - 0.35 * 0.35) * (Get-N01)
        foreach ($c in @($cal.Cyls)) {
            $w = if ($cal.PassW -and $cal.PassW.ContainsKey([int]$c)) { [double]$cal.PassW[[int]$c] } else { [double]$cal.Value }
            foreach ($h in 0, 1) { $tr[2 * [int]$c + $h] = New-SimTrack $w (Get-SimZ ([int]$c) $h) $h $(if ($h -eq 0) { $a0 } else { $a1 }) }
        }
    }
    elseif ($cal.Stage -eq 'bracket') {
        foreach ($u in @($cal.Units)) {
            $a = Get-N01
            foreach ($c in @($u.Bracket.Keys)) { foreach ($h in (Get-UnitHeads $u)) { $tr[2 * [int]$c + $h] = New-SimTrack ([double]$u.Bracket[$c]) (Get-SimZ ([int]$c) $h) $h $a } }
        }
    }
    elseif ($cal.Stage -eq 'verify') {
        foreach ($u in @($cal.Units)) {
            if ([int]$cal.Retests -gt 0 -and -not $u.InRetest) { continue }
            $aV = 2.0 * (Get-N01)
            $rc = if ($null -ne $u.VerifyList) { @($u.VerifyList) } else { @($cal.Cyls) }
            foreach ($c in $rc) { $w = [double](Get-SpecValue $u.Profile ([int]$c)); foreach ($h in (Get-UnitHeads $u)) { $tr[2 * [int]$c + $h] = New-SimTrack $w (Get-SimZ ([int]$c) $h) $h $aV } }
        }
    }
    else { throw "etape non simulee : $($cal.Stage)" }
    $script:SimTracks = $tr
}

function New-OwnCurve([int]$head) {
    # Courbe propre du lecteur A deja en magasin (calibration anterieure) : elle ne doit pas bouger en croise
    $cs = [int[]]@(0..79)
    return @{ Family = 'Standard 2 us'; Head = $head; Drive = 'A'; Target = ''; Date = '01/11/2026 10:00'; Model = 'seg'; Spec = '0=50'; Method = 'motif'
              Version = '12.10'; Algo = 'v2'; Calc = '12.10'; Breaks = [int[]]@(); Values = [int[]]@(0..79 | ForEach-Object { 50 }); Cyls = $cs
              Ys = [double[]]@($cs | ForEach-Object { 50.0 }); Sig = [double[]]@($cs | ForEach-Object { 1.0 }); Kinds = [string[]]@($cs | ForEach-Object { 'interp' })
              Res = [double[]]@($cs | ForEach-Object { 0.0 }); Converged = $true; MaxX = 100; MaxNs = 400; Slope = -1.55; Bits = 101344; Test = 'fine' }
}

# ---------------------------------------------------------------- calibration par la file reelle (commandes, invites, fin)
function Invoke-CrossCase($o) {
    # $o : @{ Cross ; Fam ; Fine ; Slow ; MaxCyl ; Answers (reponses aux invites, vrai par defaut) ; Device ; Fake (analyse
    # factice : 3 passes de mesure) ; Restart ; Geom }. Renvoie commandes, lecteur de la disquette a chaque commande, etapes,
    # journal, invites, etat final
    . $gen
    function T([string]$s) { return $s }
    function Format-UiNum([double]$v, [string]$fmt = '0.#') { return $v.ToString($fmt, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
    function Append-Log([string]$text) { $script:CLog.Add($text) }
    function Get-CommonArgs { return @('--drive=A') }
    function Get-CalibDriveArgs { return @() }
    function Get-DriveReadArgs { return @() }
    function Get-EraseDriveArgs { return @() }
    function Get-EraseMode([bool]$hd) { if ($hd) { return 'pre' }; return 'hfreq' }
    function Update-CalibProgress { $script:NProg++ }
    function Update-HomeCalibCard { }
    function Set-HomeProgDone($a, $b, $c) { }
    function Get-WProfileText { return '' }
    function Get-WriteTabFamily { return 'std' }
    function Get-LevelBrandsOfRef($k, $d, $dr) { return @() }
    function Backup-ConfigBeforeRef([string[]]$keys, [string]$why = 'replace') { $script:CBackup.Add(@{ Keys = @($keys); Why = $why }); return $null }
    function Save-Config { $script:NSave++; return $true }
    function Update-PrecompForImage([string]$path) { $script:NUpd++ }
    # fix2 (RC5) : fin d une calibration croisee : bouton « Courbe » et case de la mesure recalcules (270)
    function Update-CurveButton([string]$path) { $script:NCurveBtn++ }
    function Update-WLevelUi { $script:NWLevelUi++ }
    function Show-CurvesWindow($cvs, $Owner = $null) { $script:CShown.Add(@{ Kind = 'cross'; Curves = @($cvs) }) }
    function Show-PrecompCurve([string]$family, [bool]$preferHeads, $Owner = $null) { $script:CShown.Add(@{ Kind = 'view'; Curves = @(Get-FamilyCurves $family $preferHeads) }) }
    function Show-CalibReview($cal, [string[]]$issues, [bool]$toWrite, [bool]$offerFull = $false, [bool]$noFields = $false, [bool]$offerRedo = $false, $compare = $null, [bool]$warnKeep = $false, $lvl2 = $null) { $script:CReview.Add(@{ Issues = @($issues); OfferRedo = $offerRedo }); return 'keep' }
    function Restore-CalibState($prev) { $script:NRestore++ }
    function Stop-PrecompCalib([switch]$GwError) { $script:CStop.Add(@{ GwError = [bool]$GwError; Swaps = $(if ($script:Cal) { [int]$script:Cal.Swaps } else { -1 }); DiskAt = $(if ($script:Cal) { [string]$script:Cal.DiskAt } else { '' }) }); $script:Cal = $null }
    function Show-TimedConfirm([string]$name, [string]$title, [string]$text, [string]$okText, [string]$okGlyph, [string]$countFmt, [string]$checkLabel, [string]$stopOn, [string]$stopOff, [int]$Seconds = 0, [switch]$NeedCheck, $Combo = $null, [string]$Heading = '', [string]$Level = 'warn', [string]$Picto = 'warn') {
        $n = $script:CPrompts.Count
        $hold = if ($script:Cal -and $script:Cal.SwapHold) { @{ From = [string]$script:Cal.SwapHold.From; To = [string]$script:Cal.SwapHold.To } } else { $null }
        $ans = if ($n -lt @($script:CAnswers).Count) { [bool]$script:CAnswers[$n] } else { $true }
        $script:CPrompts.Add(@{ Name = $name; Title = $title; Text = $text; Ok = $okText; Glyph = $okGlyph; Heading = $Heading; Level = $Level; Picto = $Picto; Seconds = $Seconds; NeedCheck = [bool]$NeedCheck; Check = $checkLabel; Hold = $hold; CmdIdx = $script:CCmds.Count; Answer = $ans })
        return @{ Ok = $ans; Checked = $true; Auto = $false }
    }
    function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger, [switch]$NoIndexZone) { return $script:SimTracks }
    function Start-Gw([string[]]$gwArgs, [switch]$Soft) {
        $script:CCmds.Add((@($gwArgs) -join ' ')); $script:CSteps.Add('gw ' + [string]@($gwArgs)[0])
        $script:CAt.Add($(if ($script:Cal -and $script:Cal.ContainsKey('DiskAt')) { [string]$script:Cal.DiskAt } else { '-' }))
        $script:CPlanOf.Add($script:ProgPlan)    # 12.11 (lot L8) : plan de l etape pose au lancement de la commande (cas E10)
        if ([string]@($gwArgs)[0] -eq 'read' -and -not $script:CFake) { [System.IO.File]::WriteAllText([string]$script:Cal.Scp, 'x'); New-SimPass }
    }
    function Invoke-NextChainStep {
        if ($script:Chain.Count -eq 0) { return }
        $txt = ([string]$script:Chain.Peek()).Trim()
        if ($txt -notmatch 'Start-Gw') { $script:CSteps.Add($txt) }
        & ($script:Chain.Dequeue())
    }
    if ($o.Fake) {
        function Invoke-CalibAnalysis {
            # Analyse factice : trois passes de mesure (New-CalibPass reel entre elles), puis fin de l essai
            $cal = $script:Cal
            if (-not $cal) { return }
            $cal.PassesDone++; $script:NAna++
            if ($cal.Stage -eq 'coarse') { $cal.Index++; if ([int]$cal.Index -lt @($cal.Values).Count) { New-CalibPass; return } }
            $script:Analysed = $true
        }
    }
    function Invoke-Drive { $g = 0; while ($script:Chain.Count -gt 0 -and $script:Cal -and -not $script:Analysed -and $g -lt 900) { $g++; Invoke-NextChainStep }; $script:CGuard = $g }
    Set-Cal2Rng $Seed
    $script:SimHd = ([string]$o.Fam -eq 'hd'); $script:SimTracks = @{}; $script:CFake = [bool]$o.Fake; $script:CAnswers = @(@($o.Answers) | Where-Object { $null -ne $_ })
    $script:TempDir = $simDir; $script:Chain = New-Object System.Collections.Queue; $script:Restore = $null; $script:CalRedo = $null; $script:AfterCalib = ''
    $script:CurveForm = $null; $script:OldCalib = $null; $script:CurveFitOk = $true; $script:Lang = 'fr'; $script:CalWarmupMinutes = 0.0
    $script:CCmds = New-Object System.Collections.Generic.List[string]; $script:CSteps = New-Object System.Collections.Generic.List[string]; $script:CAt = New-Object System.Collections.Generic.List[string]
    $script:CLog = New-Object System.Collections.Generic.List[string]; $script:CPrompts = New-Object System.Collections.Generic.List[object]
    $script:CBackup = New-Object System.Collections.Generic.List[object]; $script:CShown = New-Object System.Collections.Generic.List[object]; $script:CReview = New-Object System.Collections.Generic.List[object]; $script:CStop = New-Object System.Collections.Generic.List[object]
    $script:Analysed = $false; $script:NProg = 0; $script:NAna = 0; $script:NSave = 0; $script:NUpd = 0; $script:NRestore = 0; $script:CGuard = 0
    $script:CPlanOf = New-Object System.Collections.Generic.List[object]; $script:ProgPlan = $null; $script:ProgCmd = $null
    $cmbDrive = [pscustomobject]@{ Text = 'A' }; $txtDev = [pscustomobject]@{ Text = [string]$o.Device }
    $pbWCal = [pscustomobject]@{ Value = 0; Visible = $false }; $lblWCal = [pscustomobject]@{ Text = ''; Visible = $false }; $lblWProfileInfo = [pscustomobject]@{ Text = '' }
    $cmbWProfile = [pscustomobject]@{ SelectedIndex = 0 }; $chkWPrecomp = [pscustomobject]@{ Checked = $true }; $txtWPrecomp = [pscustomobject]@{ Text = '' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '' }
    # Magasin : courbes propres du lecteur A (tetes 0 et 1) deja mesurees, vue du lecteur A a l identique ; un niveau de la
    # calibration rapide attache a la courbe propre std_h0 du lecteur A
    $script:DriveCurves = @{ 'A|std_h0' = (New-OwnCurve 0); 'A|std_h1' = (New-OwnCurve 1) }
    $script:PrecompCurves = @{ std = $null; long = $null; std_h0 = $script:DriveCurves['A|std_h0']; std_h1 = $script:DriveCurves['A|std_h1']; long_h0 = $null; long_h1 = $null; hd = $null; hd_h0 = $null; hd_h1 = $null }
    $script:LevelShifts = @{ 'std_h0|c|0|1' = @{ RefKey = 'std_h0'; Drive = 'A'; Date = '01/11/2026 10:00' } }
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    $fam = [string]$o.Fam; $fine = [bool]$o.Fine; $slow = [bool]$o.Slow; $maxCyl = [int]$o.MaxCyl
    Set-CalibScale $fam
    if ($fine) { $cyls = @(0..$maxCyl) } else { $cyls = @(0..$maxCyl | Where-Object { $_ % 10 -eq 0 }); if ($cyls -notcontains $maxCyl) { $cyls += $maxCyl } }
    $cyls = @($cyls | Sort-Object -Unique)
    $units = @(if ($slow) { (New-CalibUnit 0), (New-CalibUnit 1) } else { New-CalibUnit $null })
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $cond = [bool]$(if ($fam -eq 'hd') { $script:CalScaleHd.CalCondPass } else { $script:CalScaleDd.CalCondPass })
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    $nPassMax = $nPassEst + 1 + $(if ($fine) { 0 } else { 2 }) + $(if ($cond) { 1 } else { 0 }) + $(if ($cond) { [int]$script:CalMaxRetest } else { 0 })
    $pat = @{ Path = 'C:\x\precomp-pattern.hfe'; Bits = $(if ($fam -eq 'hd') { 200000 } else { 101344 }); CellNs = $(if ($fam -eq 'hd') { 1000.0 } else { 1973.5 }); Source = 'image' }
    $cylList = Format-CylList $cyls
    $geom = $o.Geom
    New-Cal2CalState $fine $cyls $maxCyl $fam $slow 'C:\x\image.adf' $pat $cylList $units @{ Ok = $true; Swap = $false; Auto = $false } $false $nPassEst (Get-CalibEraseEst ($fam -eq 'hd')) $true $nPassMax $cond $false $geom
    $modeTxt = if ($fine) { 'test fin, tous les cylindres' } else { 'test standard, un cylindre sur 10' }
    if ($slow) { $modeTxt += ', une courbe par tête (écriture lente)' }
    if ($o.Cross) { Set-Cal2CrossState @{ Src = 'A'; Tgt = '0' } $null $geom @{ Label = $(if ($geom) { [string]$geom.Label } else { 'image.adf' }) } (Get-CalibFamilyName $fam) $modeTxt 'C:\x\image.adf' $pat $cylList $(if ($geom) { [string]$geom.CylSrc } else { "cylindres de l'image" }) ($maxCyl + 1) }
    $script:Cal.SurfDone = $true
    $st0 = @{ Cross = $script:Cal.Cross; DiskAt = $script:Cal.DiskAt; Swaps = $script:Cal.Swaps; Home = $script:Cal.Home; HasSwapHold = $script:Cal.ContainsKey('SwapHold'); Latin = $script:Cal.Latin; Cond = $script:Cal.Cond; Value = $script:Cal.Value; ValueTxt = $script:Cal.ValueTxt; Spec = $script:Cal.Spec; HasValue = $script:Cal.ContainsKey('Value'); Drive = $script:Cal.Drive }
    Start-CalibWarmup
    Invoke-Drive
    $r = @{ Cmds = $script:CCmds.ToArray(); At = $script:CAt.ToArray(); Steps = $script:CSteps.ToArray(); Log = $script:CLog.ToArray(); Prompts = $script:CPrompts.ToArray(); State0 = $st0
            Backup = $script:CBackup.ToArray(); Shown = $script:CShown.ToArray(); Review = $script:CReview.ToArray(); Stop = $script:CStop.ToArray(); NSave = $script:NSave; NUpd = $script:NUpd; NRestore = $script:NRestore; Guard = $script:CGuard; NAna = $script:NAna
            Done = (-not $script:Cal); Cal = $script:Cal; LblCal = [string]$lblWCal.Text; LblInfo = [string]$lblWProfileInfo.Text
            End = $(if ($script:Cal) { @{ Swaps = [int]$script:Cal.Swaps; DiskAt = [string]$script:Cal.DiskAt; HoldNull = ($null -eq $script:Cal.SwapHold) } } else { $null })
            Store = @{}; View = @{}; Levels = @($script:LevelShifts.Keys); PrecompStd = $script:PrecompStd; PlanOf = $script:CPlanOf.ToArray() }
    foreach ($k in @($script:DriveCurves.Keys)) { $r.Store[$k] = $script:DriveCurves[$k] }
    foreach ($k in @($script:PrecompCurves.Keys)) { $r.View[$k] = $script:PrecompCurves[$k] }
    if ($o.Restart -and $script:Cal) {
        $script:CCmds.Clear(); $script:CSteps.Clear(); $script:CAt.Clear(); $script:CLog.Clear(); $script:CPrompts.Clear(); $script:Analysed = $false
        $script:Cal.Index = 2
        Restart-PrecompCalib $script:Cal $false
        $r.R0 = @{ DiskAt = [string]$script:Cal.DiskAt; Swaps = [int]$script:Cal.Swaps; Disk = [int]$script:Cal.Disk; Log = $script:CLog.ToArray() }
        Invoke-Drive
        $r.R = @{ Cmds = $script:CCmds.ToArray(); At = $script:CAt.ToArray(); Steps = $script:CSteps.ToArray(); Log = $script:CLog.ToArray(); Prompts = $script:CPrompts.ToArray(); Cal = $script:Cal }
    }
    $script:Cal = $null
    return $r
}
function Test-DriveOf($cmds, $at, [string]$verb, [string]$drive, [string]$disk) {
    # Toutes les commandes du verbe portent --drive=$drive et trouvent la disquette dans le lecteur $disk ('S' ou 'T')
    $n = 0
    for ($i = 0; $i -lt @($cmds).Count; $i++) {
        if (-not ([string]$cmds[$i]).StartsWith("$verb ")) { continue }
        $n++
        if ([string]$cmds[$i] -notmatch "^$verb --drive=$([regex]::Escape($drive))( |$)") { return $false }
        if ([string]$at[$i] -ne $disk) { return $false }
    }
    return ($n -gt 0)
}

# ================================================================ U. unites (240, 220)
"--- U. Get-CalibDriveArgsFor, Get-CalibStoreDrive, Split-CrossDrive, Get-CrossCalibTargets, Get-CrossSwapEstimate, Get-DriveFamilyCurves, Get-DriveCurveLabel"
function Invoke-UnitCases {
    . $gen
    function T([string]$s) { return $s }
    function Get-CommonArgs { return @('--drive=B', '--device=COM9') }
    $cmbDrive = [pscustomobject]@{ Text = 'A' }; $txtDev = [pscustomobject]@{ Text = '' }
    $o = @{}
    $script:Cal = $null
    $o.NoCal = @(Get-CalibDriveArgsFor 'read')
    $script:Cal = @{ Drive = 'A' }
    $o.NoCross = @(Get-CalibDriveArgsFor 'read')
    $script:Cal = @{ Drive = 'A'; Cross = @{ Src = 'A'; Tgt = '0' } }
    $o.Read = @(Get-CalibDriveArgsFor 'read'); $o.Write = @(Get-CalibDriveArgsFor 'write'); $o.Erase = @(Get-CalibDriveArgsFor 'erase'); $o.Warm = @(Get-CalibDriveArgsFor 'warmup')
    $txtDev.Text = ' COM5 '
    $o.ReadDev = @(Get-CalibDriveArgsFor 'read'); $o.WriteDev = @(Get-CalibDriveArgsFor 'write')
    $o.StoreX = Get-CalibStoreDrive $script:Cal; $o.StoreA = Get-CalibStoreDrive @{ Drive = 'A' }
    $script:Cal = $null
    $o.SplitX = Split-CrossDrive 'A>0'; $o.SplitA = Split-CrossDrive 'A'; $o.SplitBad = Split-CrossDrive 'A>0>1'; $o.SplitEmpty = Split-CrossDrive ''
    # Tableaux proteges par la virgule : pas de @() autour des appels
    $o.T3 = Get-CrossCalibTargets @('A', '0', '1') 'A'; $o.T1 = Get-CrossCalibTargets @('A') 'A'; $o.TNull = Get-CrossCalibTargets @('0', '', $null, 'A') 'A'; $o.T0 = Get-CrossCalibTargets @() 'A'
    $o.EF = Get-CrossSwapEstimate 5 $true 1; $o.ES = Get-CrossSwapEstimate 5 $false 1; $o.E0 = Get-CrossSwapEstimate 0 $true 0
    # Magasin : courbes croisees A>0 par tete (recentes) et commune (ancienne), courbe propre A
    $h0 = @{ Family = 'Standard 2 us'; Head = 0; Drive = 'A'; Target = '0'; Date = '08/11/2026 12:00'; Spec = '0=20' }
    $h1 = @{ Family = 'Standard 2 us'; Head = 1; Drive = 'A'; Target = '0'; Date = '08/11/2026 12:00'; Spec = '0=22' }
    $one = @{ Family = 'Standard 2 us'; Head = $null; Drive = 'A'; Target = '0'; Date = '07/11/2026 12:00'; Spec = '0=21' }
    $script:DriveCurves = @{ 'A>0|std_h0' = $h0; 'A>0|std_h1' = $h1; 'A>0|std' = $one; 'A|std' = @{ Family = 'Standard 2 us'; Drive = 'A'; Date = '06/11/2026 12:00'; Spec = '0=50' } }
    $o.FHeads = Get-DriveFamilyCurves 'A>0' 'std' $true; $o.FOne = Get-DriveFamilyCurves 'A>0' 'std' $false; $o.FNone = Get-DriveFamilyCurves 'A>0' 'long' $true; $o.FOwn = Get-DriveFamilyCurves 'A' 'std' $true
    $one.Date = '09/11/2026 12:00'
    $o.FNewer = Get-DriveFamilyCurves 'A>0' 'std' $true
    $script:DriveCurves['A>0|std'] = $null
    $o.FNoOne = Get-DriveFamilyCurves 'A>0' 'std' $true
    $o.LblX = Get-DriveCurveLabel 'A>0|std_h0'; $o.LblA = Get-DriveCurveLabel 'A|std'; $o.LblK = Get-DriveCurveLabel 'long_h1'
    $script:DriveCurves = @{}
    return $o
}
$u = Invoke-UnitCases
Chk 'U1' ((($u.NoCal -join ' ') -eq '--drive=B --device=COM9') -and (($u.NoCross -join ' ') -eq '--drive=B --device=COM9')) "sans calibration ou sans Cross : Get-CommonArgs tel quel ($($u.NoCal -join ' '))"
Chk 'U2' ((($u.Read -join ' ') -eq '--drive=0') -and (($u.Write -join ' ') -eq '--drive=A') -and (($u.Erase -join ' ') -eq '--drive=A') -and (($u.Warm -join ' ') -eq '--drive=A')) "croise : read --drive=0 (cible), write/erase/warmup --drive=A (source), sans --device quand le champ est vide"
Chk 'U3' ((($u.ReadDev -join ' ') -eq '--drive=0 --device=COM5') -and (($u.WriteDev -join ' ') -eq '--drive=A --device=COM5')) "port du bandeau ajoute, blancs retires : $($u.ReadDev -join ' ') / $($u.WriteDev -join ' ')"
Chk 'U4' ($u.StoreX -eq 'A>0' -and $u.StoreA -eq 'A') "Get-CalibStoreDrive : $($u.StoreX) (croise), $($u.StoreA) (ordinaire)"
Chk 'U5' ($u.SplitX.Src -eq 'A' -and $u.SplitX.Tgt -eq '0' -and $null -eq $u.SplitA -and $null -eq $u.SplitBad -and $null -eq $u.SplitEmpty) "Split-CrossDrive : A>0 -> $($u.SplitX.Src)/$($u.SplitX.Tgt) ; A, A>0>1 et vide -> null"
Chk 'U6' ((($u.T3 -join ',') -eq '0,1') -and $u.T1.Count -eq 0 -and (($u.TNull -join ',') -eq '0') -and $u.T0.Count -eq 0) "Get-CrossCalibTargets : A,0,1 sauf A -> $($u.T3 -join ',') ; A seul -> aucun ; vides et nuls ecartes -> $($u.TNull -join ',')"
# 12.11 (lot L6) : minimum de 7 et non 9 (une seule verification quand elle ne corrige rien) ; maximum inchange
Chk 'U7' ([int]$u.EF.Min -eq 7 -and [int]$u.EF.Max -eq 13 -and [int]$u.ES.Min -eq 7 -and [int]$u.ES.Max -eq 17 -and [int]$u.E0.Min -eq 1 -and [int]$u.E0.Max -eq 3) "Get-CrossSwapEstimate : 5 passes, test fin $($u.EF.Min)/$($u.EF.Max), test standard $($u.ES.Min)/$($u.ES.Max) (CHANGELOG 12.11 : 7, 13, 17) ; 0 passe -> $($u.E0.Min)/$($u.E0.Max)"
Chk 'U8' ($u.FHeads.Count -eq 2 -and $u.FHeads[0].Spec -eq '0=20' -and $u.FHeads[1].Spec -eq '0=22' -and $u.FOne.Count -eq 1 -and $u.FOne[0].Spec -eq '0=21' -and $u.FNone.Count -eq 0 -and $u.FOwn.Count -eq 1 -and $u.FOwn[0].Spec -eq '0=50') "Get-DriveFamilyCurves A>0 : par tete a jour -> 2 courbes ; sans preference -> commune ; famille sans courbe -> aucune ; lecteur A (courbe propre) -> 1 courbe"
Chk 'U9' ($u.FNewer.Count -eq 1 -and $u.FNewer[0].Spec -eq '0=21' -and $u.FNoOne.Count -eq 2) "courbe commune plus recente que les courbes par tete -> commune seule ; sans courbe commune -> les deux tetes"
Chk 'U10' ($u.LblX -eq 'Standard 2 us (tête 0), écriture par le lecteur A pour le lecteur 0' -and $u.LblA -eq 'Standard 2 us (commune), lecteur A' -and $u.LblK -eq 'Long track 1,89 us (tête 1), lecteur A') "Get-DriveCurveLabel : « $($u.LblX) » ; « $($u.LblA) » ; cle sans lecteur -> « $($u.LblK) »"

# ================================================================ S. blocs reels de Start-PrecompCalib
"--- S. Start-PrecompCalib : bloc d etat croise et avertissement frmCalibConfirm (blocs if (`$cx) reels)"
function Invoke-StartBlocks {
    . $gen
    function T([string]$s) { return $s }
    function Append-Log([string]$text) { $script:SLog.Add($text) }
    function Show-TimedConfirm([string]$name, [string]$title, [string]$text, [string]$okText, [string]$okGlyph, [string]$countFmt, [string]$checkLabel, [string]$stopOn, [string]$stopOff, [int]$Seconds = 0, [switch]$NeedCheck, $Combo = $null, [string]$Heading = '', [string]$Level = 'warn', [string]$Picto = 'warn') {
        $script:SConf.Add(@{ Name = $name; Title = $title; Text = $text; Ok = $okText; Heading = $Heading; Check = $checkLabel; NeedCheck = [bool]$NeedCheck; Seconds = $Seconds; StopOff = $stopOff; Level = $Level })
        return @{ Ok = $script:SAnsOk; Checked = $script:SAnsChk; Auto = $false }
    }
    $o = @{}
    $pat = @{ Path = 'C:\x\precomp-pattern.hfe'; Bits = 101344; CellNs = 1973.5; Source = 'HFE, bits par piste de l image' }
    # Etat croise avec une image de l onglet
    $script:SLog = New-Object System.Collections.Generic.List[string]
    $script:Cal = @{ Drive = 'A'; Home = $true }
    Set-Cal2CrossState @{ Src = 'A'; Tgt = '0' } $null $null @{ Label = 'img.adf' } 'Standard 2 us' 'test fin, tous les cylindres' 'C:\x\speedball2.adf' $pat '0-79' "cylindres de l'image" 80
    $o.Img = @{ Cal = $script:Cal; Log = $script:SLog.ToArray(); Pat = $pat }
    # Etat croise avec une image de geometrie (famille sans image dans l onglet)
    $script:SLog = New-Object System.Collections.Generic.List[string]
    $script:Cal = @{ Drive = 'A'; Home = $true }
    $pat2 = @{ Path = 'C:\x\precomp-pattern.hfe'; Bits = 105808; CellNs = 1890.2; Source = 'HFE' }
    Set-Cal2CrossState @{ Src = 'A'; Tgt = '0' } $null @{ Img = 'C:\x\geom.hfe'; Label = 'Amiga longues pistes (IPF, HFE)'; BitsSrc = 'long track, 1,89 us par cellule'; CylSrc = '80 cylindres, faute d''image de cette famille dans l''onglet Écriture' } @{ Label = 'Amiga longues pistes (IPF, HFE)' } 'Long track 1,89 us' 'test standard, un cylindre sur 10' 'C:\x\geom.hfe' $pat2 '0,10,20,30,40,50,60,70,79' '80 cylindres, faute d''image de cette famille dans l''onglet Écriture' 80
    $o.Geom = @{ Cal = $script:Cal; Log = $script:SLog.ToArray(); Pat = $pat2 }
    # Sans demande croisee ni mesure ni geometrie : branche ordinaire (journal « === Calibration precomp : lecteur A, image ... »)
    $script:SLog = New-Object System.Collections.Generic.List[string]
    $script:Cal = @{ Drive = 'A'; Home = $false }
    $cmbDrive = [pscustomobject]@{ Text = 'A' }
    Set-Cal2CrossState $null $null $null @{ Label = 'img.adf' } 'Standard 2 us' 'test fin, tous les cylindres' 'C:\x\speedball2.adf' $pat '0-79' "cylindres de l'image" 80
    $o.Plain = @{ Cal = $script:Cal; Log = $script:SLog.ToArray() }
    $script:Cal = $null
    # Avertissement croise : case cochee, puis non cochee, puis Annuler
    $script:CalMaxRetest = 1
    foreach ($case in @(@{ Id = 'Ok'; Ok = $true; Chk = $true; Fine = $true }, @{ Id = 'NoChk'; Ok = $true; Chk = $false; Fine = $true }, @{ Id = 'Cancel'; Ok = $false; Chk = $false; Fine = $false })) {
        $script:SLog = New-Object System.Collections.Generic.List[string]; $script:SConf = New-Object System.Collections.Generic.List[object]
        $script:SAnsOk = [bool]$case.Ok; $script:SAnsChk = [bool]$case.Chk
        $ans = Get-Cal2CrossConfirm @{ Src = 'A'; Tgt = '0' } $false $null $null '' 'CORPS' 'USURE' 5 ([bool]$case.Fine) $false 'la disquette à écrire' 0 '' '' 'CHOIX' 'std' 26 80 0 0
        $id = [string]$case.Id
        $o[$id] = @{ Ans = $ans; Conf = $script:SConf.ToArray(); Log = $script:SLog.ToArray() }
    }
    return $o
}
$s = Invoke-StartBlocks
$s.Img.Log | ForEach-Object { "    | $_" }
$calI = $s.Img.Cal
Chk 'S1' ($calI.Cross.Src -eq 'A' -and $calI.Cross.Tgt -eq '0' -and $calI.DiskAt -eq 'S' -and [int]$calI.Swaps -eq 0 -and $calI.ContainsKey('SwapHold') -and $null -eq $calI.SwapHold -and $calI.Home -eq $false) "etat croise : Cross A>0, DiskAt S, Swaps 0, SwapHold null, Home faux (meme pose vrai avant)"
Chk 'S2' ($s.Img.Log.Count -eq 4 -and $s.Img.Log[0] -eq '=== Calibration croisée : écriture par le lecteur A, relecture par le lecteur 0, image speedball2.adf (Standard 2 us, test fin, tous les cylindres) ===' -and $s.Img.Log[1] -eq "Cylindres de test : 0-79 (cylindres de l'image)" -and $s.Img.Log[2] -like 'Motif de test : HFE de données pseudo-aléatoires généré, 80 cylindres, 101344 cellules par piste (HFE, bits par piste de l image), soit 1973?5 ns par cellule*' -and $s.Img.Log[3] -eq "Calibration croisée : la courbe mesure le besoin du lecteur 0 à la relecture des écritures du lecteur A ; elle est enregistrée sous la clé « A>0 », pour les écritures du lecteur A destinées au lecteur 0. Pour ces écritures, le contrôle après écriture relit avec le lecteur A (pas avec le lecteur cible) ; la mesure de la disquette et la calibration rapide ne sont pas faites.") "journal avec une image de l onglet : en-tete « image speedball2.adf », cylindres, motif, explication (4 lignes) : $($s.Img.Log[0])"
Chk 'S3' ($s.Geom.Log.Count -eq 4 -and $s.Geom.Log[0] -eq '=== Calibration croisée : écriture par le lecteur A, relecture par le lecteur 0, type Amiga longues pistes (IPF, HFE) (Long track 1,89 us, test standard, un cylindre sur 10) ===' -and $s.Geom.Pat.Source -eq 'long track, 1,89 us par cellule' -and $s.Geom.Log[2] -like '*105808 cellules par piste (long track, 1,89 us par cellule)*' -and $s.Geom.Cal.Home -eq $false) "journal avec une image de geometrie : en-tete « type ... », source des cellules du type, Home faux"
Chk 'S3b' ($s.Geom.Log[1] -eq "Cylindres de test : 0,10,20,30,40,50,60,70,79 (80 cylindres, faute d'image de cette famille dans l'onglet Écriture)" -and ($s.Geom.Log[1].Split('(').Count - 1) -eq 1) "ligne des cylindres de test avec une image de geometrie : un seul niveau de parentheses : $($s.Geom.Log[1])"
Chk 'S4' ($null -eq $s.Plain.Cal.Cross -and $s.Plain.Log.Count -eq 3 -and $s.Plain.Log[0] -eq '=== Calibration precomp : lecteur A, image speedball2.adf (Standard 2 us, test fin, tous les cylindres) ===') "sans demande croisee : branche ordinaire inchangee (3 lignes, pas de Cross)"
$c1 = $s.Ok.Conf[0]
Chk 'S5' ($s.Ok.Conf.Count -eq 1 -and $c1.Name -eq 'frmCalibConfirm' -and $c1.Title -eq 'Calibration precomp' -and $c1.NeedCheck -and [int]$c1.Seconds -eq 0 -and $c1.Ok -eq 'Lancer la calibration' -and $c1.Heading -eq 'Calibration croisée : la disquette sacrifiée reçoit le motif de test' -and $c1.Check -eq "J'ai inséré une disquette sacrifiée (sans valeur, jamais l'original) dans le lecteur A, celui qui écrit" -and $c1.StopOff -eq 'Pas de démarrage automatique : cochez la case, puis cliquez sur « Lancer la calibration ».' -and $c1.Level -eq 'warn') "avertissement : frmCalibConfirm, case obligatoire (NeedCheck), sans compte a rebours, case « ... dans le lecteur A, celui qui écrit », en-tete croise"
Chk 'S6' ($c1.Text -like 'Calibration croisée : le lecteur A écrit le motif de test, le lecteur 0 le relit. Avant chaque relecture, puis avant l''écriture suivante, l''application vous demande de déplacer la disquette d''un lecteur à l''autre : 7 échanges au moins, 13 au plus. La durée estimée ne compte pas ces échanges.*courbe propre du lecteur A n''est pas modifiée.*CORPS*USURE' -and $s.Cancel.Conf[0].Text -like '*7 échanges au moins, 17 au plus.*') "texte : lecteurs, 7 a 13 echanges (test fin), puis corps et usure ; test standard : 7 a 17 (12.11 : 7 et non 9)"
Chk 'S7' ($s.Ok.Ans.Ok -eq $true -and $s.Ok.Ans.Swap -eq $false -and $s.Ok.Ans.Auto -eq $false -and $s.NoChk.Ans.Ok -eq $false -and $s.Cancel.Ans.Ok -eq $false) "reponse : OK et case cochee -> Ok ; OK sans case -> refus ; Annuler -> refus ; jamais Swap ni Auto"
Chk 'S8' ($s.Ok.Log.Count -eq 1 -and $s.Ok.Log[0] -eq 'Calibration croisée : lancée (case « disquette sacrifiée dans le lecteur A » cochée).' -and $s.NoChk.Log[0] -eq 'Calibration croisée : annulée.' -and $s.Cancel.Log[0] -eq 'Calibration croisée : annulée.') "journal de la reponse : « lancée (case ... cochée) » / « annulée »"

# ================================================================ C. Start-CrossCalib (270) : refus, fenetre de choix, demande posee
"--- C. Start-CrossCalib : refus (occupation, calibration B, aucun autre lecteur), fenetre de choix, famille de l image ou image de geometrie"
function Invoke-CrossStart($o) {
    . $gen
    function T([string]$s) { return $s }
    function Append-Log([string]$text) { $script:XLog.Add($text) }
    function Get-AppBusy([switch]$Text) { return [string]$o.Busy }
    function Show-AppMessage([string]$text, [string]$title, [string]$buttons = 'OK', [string]$icon = 'Information') { $script:XMsg.Add(@{ Text = $text; Title = $title; Icon = $icon }); return 'OK' }
    # 12.11 (lot L6) : neuvieme argument, lecteur cible de l onglet Ecriture a preselectionner (Get-TargetDrive, 140, remplace
    # selon le scenario : TabTarget ; lecteur source demande releve dans XTgtAsk)
    function Show-CrossCalibDialog([string]$src, [string[]]$targets, [string]$family, [bool]$fine, [string]$imgInfo, [bool]$slow, [int]$minSwaps, [int]$maxSwaps, [string]$preselect = '') {
        $script:XDlg.Add(@{ Src = $src; Targets = @($targets); Family = $family; Fine = $fine; ImgInfo = $imgInfo; Slow = $slow; Min = $minSwaps; Max = $maxSwaps; Pre = $preselect; NArg = $PSBoundParameters.Count })
        return @{ Ok = [bool]$o.DlgOk; Target = [string]$o.DlgTarget; Family = [string]$o.DlgFamily; Fine = [bool]$o.DlgFine }
    }
    function Get-TargetDrive([string]$src = '') { $script:XTgtAsk.Add($src); return [string]$o.TabTarget }
    function Start-PrecompCalib([switch]$ForceFine, [string]$Intro = '', [switch]$LevelAfter, $Geom = $null, $Heads = $null, [string]$Test = '', [switch]$NoWarmup) {
        $script:XStart.Add(@{ Ask = $script:CalCrossAsk; Geom = $Geom; Test = $Test; Heads = $Heads; ForceFine = [bool]$ForceFine })
        $ask = $script:CalCrossAsk; $script:CalCrossAsk = $null
        if ($ask -and -not $o.StartFails) { $script:Cal = @{ Cross = @{ Src = $ask.Src; Tgt = $ask.Tgt } } }
    }
    function Get-WriteTabFamily { return $o.ImgFam }
    # fixB (RC5) : controle de l image de la calibration (Get-CalibImageCheck, 260), selon le scenario
    # fix1 (RC5) : reglages qui refusent toute calibration (Get-CalibSettingBlock, 260), selon le scenario
    # RC8 : installation complete (module d analyse SCP et gw.exe) : Get-CalibEnvBlock, 260, sans refus
    function Get-CalibEnvBlock { return $null }
    function Get-CalibSettingBlock { return [string]$o.SetBlock }
    function Get-CalibImageCheck($Geom = $null) { $script:XImgChk++; if ($o.ImgWhy) { return @{ Ok = $false; Why = [string]$o.ImgWhy; Scope = [string]$o.ImgScope } }; return @{ Ok = $true; Why = ''; Scope = ''; Family = [string]$o.ImgFam } }
    function Get-HomeCalibInfo([string]$name) { return @{ Name = $name; Label = "type $name"; Cal = $(if ($name -eq 'app.long') { 'long' } else { 'std' }); Bits = $(if ($name -eq 'app.long') { 105808 } else { 101344 }); BitsSrc = "source $name"; NCyl = 80 } }
    function New-CalibGeometry($info, [int]$nCyl) { $script:XGeom.Add(@{ Name = $info.Name; NCyl = $nCyl }); if ($o.GeomFails) { throw 'disque plein' }; return 'C:\x\precomp-geometry.hfe' }
    function Get-ImageFamily([string]$path, [string]$fmt = '') { return [string]$o.GeomFam }
    $script:XImgChk = 0; $script:XTgtAsk = New-Object System.Collections.Generic.List[string]
    $script:XLog = New-Object System.Collections.Generic.List[string]; $script:XMsg = New-Object System.Collections.Generic.List[object]; $script:XDlg = New-Object System.Collections.Generic.List[object]
    $script:XStart = New-Object System.Collections.Generic.List[object]; $script:XGeom = New-Object System.Collections.Generic.List[object]
    $script:CalRedo = $o.Redo; $script:Cal = $null; $script:CalCrossAsk = $null; $script:AfterCalib = 'write'; $script:PrecompThresholdNs = 1950; $script:CalMaxRetest = 1
    $cmbDrive = [pscustomobject]@{ Text = 'A'; Items = @($o.Drives) }; $cmbWCalMode = [pscustomobject]@{ SelectedIndex = [int]$o.Mode }; $chkWSlow = [pscustomobject]@{ Checked = [bool]$o.Slow }; $txtWFile = [pscustomobject]@{ Text = 'C:\x\speedball2.adf' }
    $res = Start-CrossCalib
    $r = @{ TgtAsk = $script:XTgtAsk.ToArray(); ImgChk = $script:XImgChk; Res = $res; Log = $script:XLog.ToArray();Msg = $script:XMsg.ToArray(); Dlg = $script:XDlg.ToArray(); Start = $script:XStart.ToArray(); Geom = $script:XGeom.ToArray(); AskAfter = $script:CalCrossAsk; After = $script:AfterCalib }
    $script:Cal = $null
    return $r
}
function Merge-Opt($b, $x) { $h = $b.Clone(); foreach ($k in @($x.Keys)) { $h[$k] = $x[$k] }; return $h }
$base = @{ Busy = ''; Redo = $null; Drives = @('A', '0'); Mode = 1; Slow = $true; ImgFam = 'std'; DlgOk = $true; DlgTarget = '0'; DlgFamily = 'std'; DlgFine = $true; GeomFam = 'long' }
$cB = Invoke-CrossStart (Merge-Opt $base @{ Busy = 'calibration' })
Chk 'C1' (-not $cB.Res.Started -and $cB.Res.Why -eq 'calibration' -and $cB.Msg.Count -eq 1 -and $cB.Msg[0].Text -eq 'Calibration croisée impossible : opération en cours (calibration).' -and $cB.Dlg.Count -eq 0) "occupation : refus par message, sans fenetre de choix : $($cB.Msg[0].Text)"
$cR = Invoke-CrossStart (Merge-Opt $base @{ Redo = @{ Stage = 'confirm' } })
Chk 'C2' (-not $cR.Res.Started -and $cR.Res.Why -eq 'calibration B' -and $cR.Msg.Count -eq 1 -and $cR.Msg[0].Text -like 'Calibration croisée impossible : une calibration B*' -and $cR.Dlg.Count -eq 0) "calibration B en cours : refus"
$cD = Invoke-CrossStart (Merge-Opt $base @{ Drives = @('A') })
Chk 'C3' (-not $cD.Res.Started -and $cD.Res.Why -eq 'aucun autre lecteur' -and $cD.Msg[0].Text -eq 'Calibration croisée impossible : aucun autre lecteur dans la liste du bandeau.' -and $cD.Dlg.Count -eq 0) "un seul lecteur dans le bandeau : refus"
$cC = Invoke-CrossStart (Merge-Opt $base @{ DlgOk = $false })
$d0 = $cC.Dlg[0]
Chk 'C4' (-not $cC.Res.Started -and $cC.Res.Why -eq 'annulée' -and $cC.Msg.Count -eq 0 -and $cC.Start.Count -eq 0 -and $cC.Log[-1] -eq "Calibration croisée : fenêtre de choix fermée, rien n'est lancé." -and $cC.Dlg.Count -eq 1 -and $d0.Src -eq 'A' -and ($d0.Targets -join ',') -eq '0' -and $d0.Family -eq 'std' -and $d0.Fine -eq $true -and $d0.Slow -eq $true -and [int]$d0.Min -eq 7 -and [int]$d0.Max -eq 17 -and $d0.ImgInfo -like "Image de l'onglet Écriture : speedball2.adf (Standard 2 us)*") "fenetre de choix fermee : rien lance, journal ; fenetre appelee avec source A, cible 0, famille de l image (std), test fin (liste), ecriture lente, 7 a 17 echanges (12.11 : 7 et non 9), info de l image"
$crI = Invoke-CrossStart ($base.Clone())
$st = $crI.Start[0]
Chk 'C5' ($crI.Res.Started -and $crI.Start.Count -eq 1 -and $st.Ask.Src -eq 'A' -and $st.Ask.Tgt -eq '0' -and $null -eq $st.Geom -and $st.Test -eq 'fine' -and $null -eq $st.Heads -and $crI.Geom.Count -eq 0 -and $null -eq $crI.AskAfter -and $crI.After -eq '' -and $crI.Log[-1] -eq 'Calibration croisée demandée : écriture par le lecteur A, relecture par le lecteur 0, famille Standard 2 us, test fin.') "famille de l image choisie : Start-PrecompCalib sans Geom, -Test fine, demande @{ Src A ; Tgt 0 } lue, AfterCalib vide, journal « demandée »"
$cG = Invoke-CrossStart (Merge-Opt $base @{ DlgFamily = 'long'; DlgFine = $false })
$sg = $cG.Start[0]
Chk 'C6' ($cG.Res.Started -and $sg.Test -eq 'std' -and $sg.Geom -and $sg.Geom.Img -eq 'C:\x\precomp-geometry.hfe' -and $sg.Geom.Fmt -eq 'app.long' -and $sg.Geom.Label -eq 'type app.long' -and $sg.Geom.BitsSrc -eq 'source app.long' -and $sg.Geom.CylSrc -eq '80 cylindres, faute d''image de cette famille dans l''onglet Écriture' -and $cG.Geom.Count -eq 1 -and $cG.Geom[0].Name -eq 'app.long' -and [int]$cG.Geom[0].NCyl -eq 80) "autre famille que l image (long track) : image de geometrie app.long de 80 cylindres, -Test std, CylSrc croise"
$cT = Invoke-CrossStart (Merge-Opt $base @{ DlgFamily = 'long'; GeomFam = 'std' })
Chk 'C7' (-not $cT.Res.Started -and $cT.Res.Why -eq 'seuil de famille' -and $cT.Msg.Count -eq 1 -and $cT.Msg[0].Text -eq 'Calibration croisée impossible : avec le seuil de famille precompThresholdNs de 1950 ns, ce type serait calibré dans une autre famille que Long track 1,89 us.' -and $cT.Start.Count -eq 0) "seuil de famille qui range la geometrie ailleurs : refus, rien lance"
$cE = Invoke-CrossStart (Merge-Opt $base @{ DlgFamily = 'long'; GeomFails = $true })
Chk 'C8' (-not $cE.Res.Started -and $cE.Res.Why -eq 'disque plein' -and $cE.Msg[0].Text -eq 'Calibration croisée impossible : image de géométrie impossible à créer : disque plein' -and $cE.Msg[0].Icon -eq 'Error' -and $cE.Start.Count -eq 0) "image de geometrie impossible : refus avec la cause"
$cN = Invoke-CrossStart (Merge-Opt $base @{ ImgFam = 'hd'; Mode = 0; GeomFam = 'std' })
Chk 'C9' ($cN.Dlg[0].ImgInfo -eq "Aucune image calibrable dans l'onglet Écriture : 80 cylindres, à la densité de la famille choisie." -and $cN.Dlg[0].Family -eq 'std' -and $cN.Dlg[0].Fine -eq $false -and $cN.Start[0].Geom -and $cN.Start[0].Geom.Fmt -eq 'amiga.amigados') "image haute densite dans l onglet (hors familles croisees) : info « aucune image calibrable », standard preselectionne, test standard (liste), geometrie amiga.amigados"
$cF = Invoke-CrossStart (Merge-Opt $base @{ StartFails = $true })
Chk 'C10' (-not $cF.Res.Started -and $cF.Res.Why -eq '' -and $null -eq $cF.AskAfter) "avertissement refuse dans Start-PrecompCalib : Started faux, demande effacee"
# fixB (RC5) : image refusee par le controle de la calibration (Get-CalibImageCheck : FM, GCR, hors plage) : fenetre « aucune
# image calibrable » et image de geometrie ; secteurs durs ou lecteur 8 pouces (Scope setting) : refus avant la fenetre
$cK = Invoke-CrossStart (Merge-Opt $base @{ ImgWhy = 'Image x.d64 en codage GCR : pas de calibration'; ImgScope = 'image'; GeomFam = 'std' })
Chk 'C11' ($cK.Res.Started -and $cK.Dlg.Count -eq 1 -and $cK.Dlg[0].ImgInfo -eq "Aucune image calibrable dans l'onglet Écriture : 80 cylindres, à la densité de la famille choisie." -and $cK.Start.Count -eq 1 -and $cK.Start[0].Geom -and $cK.Start[0].Geom.Fmt -eq 'amiga.amigados' -and $cK.Msg.Count -eq 0) "image de l onglet refusee par le controle de la calibration : fenetre « aucune image calibrable », image de geometrie amiga.amigados"
$cS = Invoke-CrossStart (Merge-Opt $base @{ SetBlock = 'Calibration non prise en charge avec secteurs durs' })
Chk 'C12' (-not $cS.Res.Started -and $cS.Res.Why -eq 'Calibration non prise en charge avec secteurs durs' -and $cS.Dlg.Count -eq 0 -and $cS.Start.Count -eq 0 -and $cS.Msg.Count -eq 1 -and $cS.Msg[0].Text -eq 'Calibration non prise en charge avec secteurs durs') "secteurs durs ou lecteur 8 pouces : refus avant la fenetre de choix, message du controle"
# fix1 (RC5) : secteurs durs avec une image refusee (aucune image, flux, GCR) : refus avant la fenetre, image non controlee
$cS2 = Invoke-CrossStart (Merge-Opt $base @{ SetBlock = 'Calibration non prise en charge avec secteurs durs'; ImgWhy = 'Choisissez d abord l image'; ImgScope = 'image'; GeomFam = 'std' })
Chk 'C13' (-not $cS2.Res.Started -and $cS2.Res.Why -eq 'Calibration non prise en charge avec secteurs durs' -and $cS2.Dlg.Count -eq 0 -and $cS2.Start.Count -eq 0 -and $cS2.ImgChk -eq 0 -and $cS2.Msg.Count -eq 1 -and $cS2.Msg[0].Text -eq 'Calibration non prise en charge avec secteurs durs') "secteurs durs ou lecteur 8 pouces avec une image refusee : refus avant la fenetre de choix, image non controlee (Get-CalibImageCheck appele $($cS2.ImgChk) fois), un message"
# 12.11 (lot L6) : le lecteur cible de l onglet Ecriture (Get-TargetDrive du lecteur du bandeau) est transmis a la fenetre de
# choix pour y etre preselectionne ; sans lecteur cible, chaine vide (premier de la liste, comme en 12.10)
$cP = Invoke-CrossStart (Merge-Opt $base @{ Drives = @('A', 'B', '0'); TabTarget = '0'; DlgOk = $false })
Chk 'C14' ($cP.Dlg.Count -eq 1 -and $cP.Dlg[0].Pre -eq '0' -and ($cP.Dlg[0].Targets -join ',') -eq 'B,0' -and [int]$cP.Dlg[0].NArg -eq 9 -and ($cP.TgtAsk -join ',') -eq 'A' -and $cC.Dlg[0].Pre -eq '' -and [int]$cC.Dlg[0].NArg -eq 9 -and -not $cP.Res.Started -and $cP.Start.Count -eq 0) "lecteur cible 0 choisi dans l onglet : fenetre de choix appelee avec la preselection « $($cP.Dlg[0].Pre) » parmi $($cP.Dlg[0].Targets -join ','), lue par Get-TargetDrive du lecteur $($cP.TgtAsk -join ',') ; sans lecteur cible : preselection vide ; fenetre fermee : rien lance"

# ================================================================ K. commandes et invites par la file reelle
"--- K. File reelle : conditionnement, passes de mesure, invites d echange (analyse factice de 3 passes)"
$pat = '"C:\x\precomp-pattern.hfe"'; $scp = '"' + (Join-Path $simDir 'precomp-calib.scp') + '"'
$lv = @(0, 30, 100)
$p1 = (@(0..79 | ForEach-Object { "$_=$($lv[$_ % 3])" })) -join ':'
$k0 = Invoke-CrossCase @{ Cross = $false; Fam = 'std'; Fine = $true; Slow = $true; MaxCyl = 79; Fake = $true }
$k1 = Invoke-CrossCase @{ Cross = $true; Fam = 'std'; Fine = $true; Slow = $true; MaxCyl = 79; Fake = $true; Restart = $true }
$k1.Cmds | ForEach-Object { "    | $(if ($_.Length -gt 110) { $_.Substring(0, 110) + '...' } else { $_ })" }
$e1 = @("erase --drive=A --hfreq --tracks=c=0-79:h=0-1", "write --drive=A --no-verify --tracks=c=0-79:h=0-1 --precomp $p1 $pat",
        "erase --drive=A --hfreq --tracks=c=0-79:h=0-1", "write --drive=A --no-verify --tracks=c=0-79:h=0-1 --precomp $p1 $pat", "read --drive=0 --revs=3 --tracks=c=0-79:h=0-1 $scp")
Chk 'K1a' ($k1.Cmds.Count -eq 11 -and (@($k1.Cmds[0..4]) -join "`n") -eq ($e1 -join "`n") -and $k1.NAna -eq 3) "croise, test fin, ecriture lente, double densite : conditionnement (erase, write sur A), passe 1 (erase, write sur A, read sur 0), 3 passes analysees, $($k1.Cmds.Count) commandes (11 attendues)"
Chk 'K1b' ((Test-DriveOf $k1.Cmds $k1.At 'erase' 'A' 'S') -and (Test-DriveOf $k1.Cmds $k1.At 'write' 'A' 'S') -and (Test-DriveOf $k1.Cmds $k1.At 'read' '0' 'T')) "toutes les commandes : erase et write --drive=A avec la disquette dans la source, read --drive=0 avec la disquette dans la cible"
$st1 = (@($k1.Steps) -join ' > ')
$es1 = "Invoke-CalibSwap 'S' > gw erase > gw write > Complete-CalibCondition > Invoke-CalibSwap 'S' > gw erase > gw write > Invoke-CalibSwap 'T' > gw read > Invoke-CalibAnalysis > Invoke-CalibSwap 'S' > gw erase > gw write > Invoke-CalibSwap 'T' > gw read > Invoke-CalibAnalysis > Invoke-CalibSwap 'S' > gw erase > gw write > Invoke-CalibSwap 'T' > gw read > Invoke-CalibAnalysis"
Chk 'K1c' ($st1 -eq $es1) "etapes de la file : echange vers la source avant les ecritures (sans invite quand elle y est), vers la cible avant chaque relecture : $st1"
$pr = $k1.Prompts
$dests = (@($pr | ForEach-Object { $_.Hold.To }) -join ',')
Chk 'K1d' ($pr.Count -eq 5 -and $dests -eq '0,A,0,A,0' -and (@($pr | Where-Object { $_.Name -ne 'frmCalibSwap' -or $_.Title -ne 'Calibration precomp' -or $_.Ok -ne "J'ai déplacé la disquette" -or [int]$_.Seconds -ne 0 -or $_.NeedCheck -or $_.Check -or $_.Level -ne 'info' -or $_.Picto -ne 'drive' }).Count -eq 0)) "5 invites frmCalibSwap (2 x 3 passes - 1), destinations 0,A,0,A,0, bouton « J'ai déplacé la disquette », sans compte a rebours ni case, bandeau info"
Chk 'K1e' ($pr[0].Heading -eq 'Déplacez la disquette vers le lecteur 0' -and $pr[1].Heading -eq 'Déplacez la disquette vers le lecteur A' -and $pr[0].Text -eq "Échange 1 : retirez la disquette du lecteur A et insérez-la dans le lecteur 0, celui qui relit, puis cliquez sur « J'ai déplacé la disquette ».`nAnnuler : la calibration s'arrête, rien de plus n'est écrit." -and $pr[1].Text -like 'Échange 2 : retirez la disquette du lecteur 0 et insérez-la dans le lecteur A, celui qui écrit, puis cliquez sur*' -and $pr[0].Hold.From -eq 'A' -and $pr[0].Hold.To -eq '0' -and $pr[1].Hold.From -eq '0' -and $pr[1].Hold.To -eq 'A') "textes des invites 1 et 2 (lecteurs, role, numero), SwapHold pose pendant l invite (From/To)"
Chk 'K1f' ([int]$pr[0].CmdIdx -eq 4 -and [int]$pr[1].CmdIdx -eq 5 -and [int]$pr[2].CmdIdx -eq 7 -and [int]$pr[4].CmdIdx -eq 10) "invites placees apres la 4e commande (ecriture de la passe 1), avant la 5e (relecture), etc. : indices $(@($pr | ForEach-Object { $_.CmdIdx }) -join ',')"
Chk 'K1g' ([int]$k1.End.Swaps -eq 5 -and $k1.End.DiskAt -eq 'T' -and $k1.End.HoldNull -and (Get-LogN $k1.Log 'Calibration croisée, échange * : déplacez la disquette du lecteur * vers le lecteur * (*).') -eq 5 -and (Get-LogN $k1.Log 'Échange * fait : disquette dans le lecteur *.') -eq 5 -and (Get-LogIdx $k1.Log 'Échange 5 fait : disquette dans le lecteur 0.') -ge 0) "apres 3 passes : Swaps 5, disquette dans la cible, SwapHold efface ; journal : 5 demandes et 5 echanges faits"
$s0 = $k1.State0
Chk 'K1h' ($s0.Cross.Src -eq 'A' -and $s0.DiskAt -eq 'S' -and $s0.Home -eq $false -and $s0.HasSwapHold -and $s0.Latin -eq $true -and $s0.Cond -eq $true -and $s0.HasValue -and [int]$s0.Value -eq 0 -and $s0.ValueTxt -eq '' -and $s0.Spec -eq '' -and $s0.Drive -eq 'A') "etat initial : Cross, DiskAt S, Home faux, Latin et Cond ; litteral : Value 0, ValueTxt et Spec vides presents (champs retablis), Drive A (source)"
# Sans Cross : memes commandes avec read --drive=A, aucune invite, aucune etape d echange
$cmp = @(for ($i = 0; $i -lt $k1.Cmds.Count; $i++) { ([string]$k1.Cmds[$i]) -replace '^read --drive=0', 'read --drive=A' })
Chk 'K0' ($k0.Cmds.Count -eq 11 -and (($k0.Cmds -join "`n") -eq ($cmp -join "`n")) -and $k0.Prompts.Count -eq 0 -and (@($k0.Steps | Where-Object { $_ -like 'Invoke-CalibSwap*' }).Count -eq 0) -and (@($k0.At | Where-Object { $_ -ne '-' }).Count -eq 0) -and $null -eq $k0.State0.Cross) "calibration ordinaire (non-regression) : memes 11 commandes, read --drive=A, aucune invite ni etape d echange, pas de DiskAt"
# Reprise sur une autre disquette : disquette dans la source, echanges comptes gardes
$r0 = $k1.R0; $rr = $k1.R
Chk 'K3a' ($r0.DiskAt -eq 'S' -and [int]$r0.Swaps -eq 5 -and [int]$r0.Disk -eq 2 -and (Get-LogIdx $r0.Log 'Calibration croisée reprise : la nouvelle disquette est dans le lecteur A, celui qui écrit.') -ge 0 -and (Get-LogIdx $r0.Log '=== Calibration precomp reprise sur une autre disquette (disquette 2)*') -ge 0) "Restart-PrecompCalib en croise : DiskAt S, Swaps 5 gardes, disquette 2, journal de reprise"
Chk 'K3b' ((@($rr.Cmds[0..4]) -join "`n") -eq ($e1 -join "`n") -and $rr.Prompts.Count -eq 5 -and $rr.Prompts[0].Hold.To -eq '0' -and $rr.Prompts[0].Text -like 'Échange 6 :*' -and [int]$rr.Cal.Swaps -eq 10 -and (Test-DriveOf $rr.Cmds $rr.At 'read' '0' 'T')) "apres la reprise : nouveau conditionnement sur A sans invite, premiere invite « Échange 6 » vers 0, Swaps 10 a la fin"
# Annuler a la 2e invite : chaine videe, calibration arretee, disquette la ou elle est
$k2 = Invoke-CrossCase @{ Cross = $true; Fam = 'std'; Fine = $true; Slow = $true; MaxCyl = 79; Fake = $true; Answers = @($true, $false) }
Chk 'K2' ($k2.Cmds.Count -eq 5 -and $k2.Prompts.Count -eq 2 -and $k2.Stop.Count -eq 1 -and $k2.Stop[0].GwError -eq $false -and [int]$k2.Stop[0].Swaps -eq 1 -and $k2.Stop[0].DiskAt -eq 'T' -and $k2.Done -and $k2.NAna -eq 1 -and (Get-LogIdx $k2.Log 'Calibration croisée arrêtée à votre demande (échange 2 annulé) ; la disquette est dans le lecteur 0.') -ge 0 -and (Get-LogN $k2.Log 'Échange * fait*') -eq 1) "Annuler a l invite 2 : 5 commandes seulement (conditionnement, passe 1), Stop-PrecompCalib (Swaps 1, disquette dans la cible), journal « arrêtée à votre demande (échange 2 annulé) ; ... lecteur 0 »"
Chk 'K2b' ([int]$k2.NSave -eq 0) "Annuler a l invite 2 : aucun Save-Config pendant le deroule ni a l annulation (Invoke-CalibSwap reel ; Start-Gw et Stop-PrecompCalib remplaces, voir K2c) : $($k2.NSave)"
function Get-FnSaveN($ast, [string]$name) {
    $fd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $name }, $true))
    if ($fd.Count -ne 1) { return -1 }
    return @($fd[0].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] -and $x.GetCommandName() -eq 'Save-Config' }, $true)).Count
}
$a270 = Get-Cal2Ast (Join-Path $mods '270-fn-calib-complete.ps1'); $a110 = Get-Cal2Ast (Join-Path $mods '110-fn-coeur-gw.ps1'); $a200 = Get-Cal2Ast (Join-Path $mods '200-fn-accueil-calibration.ps1')
$svN = @{ Swap = (Get-FnSaveN $a270 'Invoke-CalibSwap'); Stop = (Get-FnSaveN $a270 'Stop-PrecompCalib'); Home = (Get-FnSaveN $a200 'Set-HomeProgDone'); Gw = (Get-FnSaveN $a110 'Start-Gw') }
Chk 'K2c' ($svN.Swap -eq 0 -and $svN.Stop -eq 0 -and $svN.Home -eq 0 -and $svN.Gw -eq 1) "configuration : appels de Save-Config dans Invoke-CalibSwap $($svN.Swap), Stop-PrecompCalib $($svN.Stop), Set-HomeProgDone $($svN.Home) (attendu 0 : l annulation n enregistre rien), Start-Gw $($svN.Gw) (attendu 1 : enregistrement avant chaque commande gw, cause de la reecriture vue au banc)"
# Haute densite : pas de conditionnement, --pre-erase, premiere invite avant la premiere relecture
$k3 = Invoke-CrossCase @{ Cross = $true; Fam = 'hd'; Fine = $false; Slow = $false; MaxCyl = 79; Fake = $true }
$tl = '0,10,20,30,40,50,60,70,79'
$e3 = @("write --drive=A --pre-erase --no-verify --tracks=c=${tl}:h=0-1 --precomp 0=0 $pat", "read --drive=0 --revs=3 --tracks=c=${tl}:h=0-1 $scp")
$st3 = (@($k3.Steps) -join ' > ')
Chk 'K4' ((@($k3.Cmds[0..1]) -join "`n") -eq ($e3 -join "`n") -and $st3 -like "Invoke-CalibSwap 'S' > gw write > Invoke-CalibSwap 'T' > gw read > Invoke-CalibAnalysis > Invoke-CalibSwap 'S' > gw write > Invoke-CalibSwap 'T' > gw read > *" -and $k3.Prompts.Count -eq 5 -and (Test-DriveOf $k3.Cmds $k3.At 'write' 'A' 'S') -and (Test-DriveOf $k3.Cmds $k3.At 'read' '0' 'T') -and $k3.State0.Cond -eq $false) "haute densite, test standard, courbe commune : write --pre-erase sur A, read sur 0, sans conditionnement ; 5 invites sur 3 passes"
# Port du bandeau
$k4 = Invoke-CrossCase @{ Cross = $true; Fam = 'std'; Fine = $false; Slow = $false; MaxCyl = 79; Fake = $true; Device = 'COM5' }
Chk 'K5' ($k4.Cmds[0] -like 'erase --drive=A --device=COM5 --hfreq *' -and $k4.Cmds[1] -like 'write --drive=A --device=COM5 --no-verify *' -and $k4.Cmds[4] -like 'read --drive=0 --device=COM5 --revs=3 *') "port du bandeau (--device=COM5) sur les deux lecteurs : $($k4.Cmds[4].Substring(0, 40))..."

# ================================================================ E. calibration croisee simulee de bout en bout
"--- E. Calibration croisee simulee de bout en bout (analyse reelle, Complete-PrecompCalib reel) : courbe « A>0|std_hN »"
$eX = Invoke-CrossCase @{ Cross = $true; Fam = 'std'; Fine = $true; Slow = $true; MaxCyl = 79; Fake = $false }
$eO = Invoke-CrossCase @{ Cross = $false; Fam = 'std'; Fine = $true; Slow = $true; MaxCyl = 79; Fake = $false }
"    croise : $($eX.Cmds.Count) commandes, $($eX.Prompts.Count) invites, $($eX.Guard) etapes ; fin : « $($eX.LblCal) »"
"    ordinaire : $($eO.Cmds.Count) commandes, $($eO.Prompts.Count) invites ; fin : « $($eO.LblCal) »"
$nReadX = @($eX.Cmds | Where-Object { $_ -like 'read *' }).Count
@($eX.Log | Where-Object { $_ -like '*Calibration croisée terminée*' -or $_ -like '*Courbe croisée*' }) | ForEach-Object { "    | $_" }
"    | info : $($eX.LblInfo)"
$shX = @($eX.Shown)
Chk 'E1' ($eX.Done -and $eX.Stop.Count -eq 0 -and $eX.NRestore -eq 0 -and $eX.Guard -lt 900 -and $shX.Count -eq 1 -and $shX[0].Kind -eq 'cross' -and $shX[0].Curves.Count -eq 2 -and $shX[0].Curves[0].Target -eq '0' -and $shX[0].Curves[1].Target -eq '0' -and $shX[0].Curves[0].Drive -eq 'A' -and [int]$shX[0].Curves[0].Head -eq 0 -and [int]$shX[0].Curves[1].Head -eq 1) "calibration terminee sans arret ni retablissement ; fenetre Courbe des courbes croisees (2 courbes, Drive A, Target 0, tetes 0 et 1)"
$cx0 = $eX.Store['A>0|std_h0']; $cx1 = $eX.Store['A>0|std_h1']
Chk 'E2' ($cx0 -and $cx1 -and $cx0.Target -eq '0' -and $cx0.Drive -eq 'A' -and $cx0.Family -eq 'Standard 2 us' -and [int]$cx0.Head -eq 0 -and [int]$cx1.Head -eq 1 -and $cx0.Calc -eq $script:CalibCalc -and $cx0.Method -eq 'motif' -and @($cx0.Values).Count -eq 80 -and $cx0.Test -eq 'fine' -and @($cx0.AsymCyl).Count -gt 0) "magasin : « A>0|std_h0 » et « A>0|std_h1 » (Drive A, Target 0, calcul $($cx0.Calc), 80 valeurs, test fin, releve d asymetrie de $(@($cx0.AsymCyl).Count) cylindres)"
Chk 'E3' ($eX.Store['A|std_h0'].Date -eq '01/11/2026 10:00' -and $eX.Store['A|std_h1'].Date -eq '01/11/2026 10:00' -and $eX.View['std_h0'].Date -eq '01/11/2026 10:00' -and $null -eq $eX.View['std'] -and $eX.PrecompStd -eq $script:PrecompStdDefault -and $eX.Store.Count -eq 4) "courbes propres du lecteur A et vue du lecteur courant inchangees, profil de famille inchange, magasin a 4 courbes"
Chk 'E4' ((Test-DriveOf $eX.Cmds $eX.At 'read' '0' 'T') -and (Test-DriveOf $eX.Cmds $eX.At 'write' 'A' 'S') -and (Test-DriveOf $eX.Cmds $eX.At 'erase' 'A' 'S') -and $eX.Prompts.Count -eq (2 * $nReadX - 1) -and (@($eX.Prompts | Where-Object { $_.Name -ne 'frmCalibSwap' }).Count -eq 0)) "toute la calibration : $nReadX relectures sur 0 (disquette dans la cible), ecritures et effacements sur A (disquette dans la source), $($eX.Prompts.Count) invites = 2 x $nReadX - 1"
$bil = Get-LogIdx $eX.Log "Courbe croisée Standard 2 us enregistrée dans la configuration (clé « A>0 ») pour les écritures du lecteur A destinées au lecteur 0 ; $($eX.Prompts.Count) échange(s) de disquette ; la disquette sacrifiée est dans le lecteur 0."
Chk 'E5' ($bil -ge 0 -and $eX.LblCal -like "Calibration croisée terminée en *, $($eX.Prompts.Count) échange(s) de disquette*" -and (Get-LogN $eX.Log '[[]tête ?] Calibration croisée terminée : courbe Standard 2 us A → 0 = *') -eq 2 -and (Get-LogIdx $eX.Log '[[]tête 1] Calibration croisée terminée : courbe Standard 2 us A → 0 = *') -ge 0 -and $eX.LblInfo -like 'Courbes croisées Standard 2 us par tête calibrées le *, écriture par le lecteur A pour le lecteur 0 : tête 0 de * à * ns, tête 1 de * à * ns ; courbe propre du lecteur A inchangée.*') "bilan : ligne « Courbe croisée ... enregistrée ... (clé « A>0 ») ... N échange(s) ... lecteur 0 », libelle de fin avec les echanges, lignes de fin par tete, libelle du profil croise"
Chk 'E6' ($eX.Levels.Count -eq 1 -and (Get-LogIdx $eX.Log 'Nouvelle référence de forme*') -lt 0 -and (Get-LogIdx $eX.Log 'Marques mémorisées*') -lt 0 -and $eX.NUpd -eq 0 -and $eX.NSave -eq 1 -and $eX.Backup.Count -eq 1 -and (($eX.Backup[0].Keys | Sort-Object) -join ',') -eq 'A>0|std_h0,A>0|std_h1' -and (@($eX.Review | Where-Object { $_.OfferRedo }).Count -eq 0) -and (Get-LogIdx $eX.Log 'Profils par tête enregistrés dans la configuration*') -lt 0) "niveaux de la calibration rapide gardes, ni marques ni nouvelle reference, profil de l image non recalcule, configuration enregistree une fois, copie .bak sur les cles croisees, pas de calibration B proposee ($($eX.Review.Count) fenetre(s) de decision)"
$co0 = $eO.Store['A|std_h0']
Chk 'E7' ($eO.Done -and $eO.Prompts.Count -eq 0 -and $eO.Store.Count -eq 2 -and $co0.Date -ne '01/11/2026 10:00' -and $co0.Target -eq '' -and $eO.View['std_h0'].Date -eq $co0.Date -and $eO.NUpd -eq 1 -and $eO.Levels.Count -eq 0 -and (Get-LogIdx $eO.Log 'Nouvelle référence de forme*') -ge 0 -and @($eO.Shown)[0].Kind -eq 'view' -and (Get-LogIdx $eO.Log 'Profils par tête enregistrés dans la configuration*') -ge 0 -and $eO.LblCal -like 'Calibration terminée en *' -and $eO.LblCal -notlike '*échange*') "calibration ordinaire (non-regression) : courbes propres remplacees (Target vide), vue mise a jour, profil de l image recalcule, niveaux abandonnes, fenetre Courbe du lecteur courant, libelles sans echange"
$pX = @($eX.Cmds | Where-Object { $_ -like 'read *' } | ForEach-Object { ($_ -replace '^read --drive=0', 'read --drive=A') })
$pO = @($eO.Cmds | Where-Object { $_ -like 'read *' })
Chk 'E8' (($pX -join "`n") -eq ($pO -join "`n") -and $eX.Cmds.Count -eq $eO.Cmds.Count) "meme graine : memes relectures (pistes) et meme nombre de commandes en croise et en ordinaire : le calcul ne change pas"
# 12.11 (lot L6) : minimum annonce des echanges (Get-CrossSwapEstimate, 240) confronte au deroule reel ci-dessus. Cette
# calibration croisee converge a la premiere verification, sans encadrement, mesure complementaire ni nouvel essai : ses
# invites d echange, repondues une a une par le remplacant de Show-TimedConfirm, sont comptees et comparees au minimum que
# rendent la fonction reelle et les constantes reelles de 560 (passes de mesure, verifications, nouvel essai)
function Get-RealSwapEstimate {
    . $gen
    Set-CalibScale 'std'
    $nPassEst = @($script:CalCoarse).Count + [int]$script:CalMaxVerify
    return @{ NCoarse = @($script:CalCoarse).Count; NPass = $nPassEst
              Fine = (Get-CrossSwapEstimate $nPassEst $true ([int]$script:CalMaxRetest) ([int]$script:CalMaxVerify)); Std = (Get-CrossSwapEstimate $nPassEst $false ([int]$script:CalMaxRetest) ([int]$script:CalMaxVerify)) }
}
$se = Get-RealSwapEstimate
$nMes = Get-LogN $eX.Log 'Calibration : passe de mesure */*'
$nVer = Get-LogN $eX.Log 'Calibration : passe de vérification */*'
$nV1 = Get-LogN $eX.Log 'Calibration : passe de vérification 1/*'
$nPlus = (Get-LogN $eX.Log "Calibration : passe d'encadrement*") + (Get-LogN $eX.Log 'Calibration : mesure complémentaire*') + (Get-LogN $eX.Log 'Calibration : passe de vérification */* du nouvel essai*')
$swapN = @($eX.Prompts | ForEach-Object { if ($_.Text -match '^Échange (\d+) :') { [int]$Matches[1] } })
"    | passes de mesure $nMes, verifications $nVer, passes en plus $nPlus, relectures $nReadX ; invites d echange : $($swapN -join ',') ; minimum annonce : test fin $($se.Fine.Min), test standard $($se.Std.Min) ; maximum : $($se.Fine.Max) et $($se.Std.Max)"
Chk 'E9' ($nMes -eq [int]$se.NCoarse -and $nVer -eq 1 -and $nV1 -eq 1 -and $nPlus -eq 0 -and $nReadX -eq ($nMes + 1) -and ($swapN -join ',') -eq '1,2,3,4,5,6,7' -and $eX.Prompts.Count -eq 7 -and [int]$se.Fine.Min -eq $eX.Prompts.Count -and [int]$se.Std.Min -eq $eX.Prompts.Count -and [int]$se.Fine.Max -eq 13 -and [int]$se.Std.Max -eq 17) "calibration croisee convergee a la premiere verification ($nMes passes de mesure, $nVer verification, ni encadrement, ni mesure complementaire, ni nouvel essai) : $($eX.Prompts.Count) invites d echange, numerotees $($swapN -join ','), soit le minimum annonce par Get-CrossSwapEstimate avec les constantes reelles ($($se.NPass) passes prevues : $($se.Fine.Min) au moins, et non 9)"
# 12.11 (lot L8) : plan de la progression par piste (110 : New-ProgPlan et Get-GwCmdUnits reels) pose par les vraies
# Start-CalibCondition et New-CalibPass : le remplacant de Start-Gw releve le plan en place a chaque commande. Chaque plan
# couvre exactement les commandes lancees pendant qu il etait en place : meme nombre, meme poids recalcule d apres la
# ligne de commande ; un plan par etape (conditionnement, puis chaque passe). Les commandes elles-memes sont celles des
# cas K1 a K5, E4 et E8 : poser le plan n en change aucune
function Test-PlanCover($cmds, $plans) {
    . $gen
    $i = 0; $n = 0; $bad = 0; $nc = @($cmds).Count
    while ($i -lt $nc) {
        $p = $plans[$i]; $j = $i; $u = 0.0
        while ($j -lt $nc -and [object]::ReferenceEquals($plans[$j], $p)) { $u += [double](Get-GwCmdUnits @([string]$cmds[$j])).Units; $j++ }
        $n++
        if ($null -eq $p -or @($p.Cmds).Count -ne ($j - $i) -or [double]$p.Units -le 0 -or [math]::Abs([double]$p.Units - $u) -gt 1e-6) { $bad++ }
        $i = $j
    }
    return @{ N = $n; Bad = $bad }
}
$pcX = Test-PlanCover $eX.Cmds $eX.PlanOf; $pcO = Test-PlanCover $eO.Cmds $eO.PlanOf
$nCondX = Get-LogN $eX.Log 'Calibration : conditionnement du lecteur * avant la première passe de mesure*'
Chk 'E10' ($eX.PlanOf.Count -eq $eX.Cmds.Count -and $pcX.Bad -eq 0 -and $pcO.Bad -eq 0 -and $nCondX -eq 1 -and $pcX.N -eq ($nReadX + $nCondX) -and $pcO.N -eq $pcX.N) "plan de la progression par piste : $($pcX.N) plans en croise et $($pcO.N) en ordinaire (conditionnement : $nCondX, passes : $nReadX), chacun egal aux commandes lancees pendant qu il etait en place (nombre et poids) ; plans en defaut : $($pcX.Bad) et $($pcO.Bad)"

# ================================================================ P. barre de progression (Update-CalibProgress reel)
"--- P. Update-CalibProgress reel : libelles croises et attente d un echange"
function Invoke-ProgCase {
    . $gen
    function T([string]$s) { return $s }
    function Get-EraseMode([bool]$hd) { if ($hd) { return 'pre' }; return 'hfreq' }
    $pbWCal = [pscustomobject]@{ Value = 0; Visible = $false }; $lblWCal = [pscustomobject]@{ Text = ''; Visible = $false }
    $o = @{}
    $script:Cal = @{ Hold = $false; SwapHold = $null; Stage = 'coarse'; Cyls = @(0..79); WriteDurs = @(); ReadDurs = @(); EstTrack = 0.7; EstErase = 0.37; PhaseStart = (Get-Date); Phase = 'write'
                     TotalPasses = 5; PassesDone = 0; Mode = 'fine'; ValueTxt = '0/30/100 ns'; Redo = $false; DiskOnly = $false; Drive = 'A'; Cross = @{ Src = 'A'; Tgt = '0' }
                     Cond = $true; CondRun = $true; CondDone = $false; CondSec = 0.0; CondTracks = 160 }
    Update-CalibProgressReal; $o.Cond = $lblWCal.Text
    $script:Cal.CondRun = $false; $script:Cal.CondDone = $true; $script:Cal.CondSec = 114.0; $script:Cal.PhaseStart = Get-Date
    Update-CalibProgressReal; $o.Pass = $lblWCal.Text; $o.PassPct = $pbWCal.Value
    $script:Cal.SwapHold = @{ From = 'A'; To = '0' }
    Update-CalibProgressReal; $o.Hold = $lblWCal.Text; $o.HoldPct = $pbWCal.Value
    $script:Cal.SwapHold = $null; $script:Cal.Cross = $null
    Update-CalibProgressReal; $o.Plain = $lblWCal.Text
    $script:Cal = $null
    return $o
}
$pp = Invoke-ProgCase
Chk 'P1' ($pp.Cond -like 'Calibration croisée : 0 %, reste environ * (conditionnement du lecteur, écriture sans relecture)' -and $pp.Pass -like 'Calibration croisée : 7 %, reste environ * (passe 1/5, 0/30/100 ns, écriture)') "libelles croises : conditionnement « $($pp.Cond) » ; passe « $($pp.Pass) »"
Chk 'P2' ($pp.Hold -eq 'Calibration croisée : déplacez la disquette du lecteur A vers le lecteur 0' -and [int]$pp.HoldPct -eq [int]$pp.PassPct -and $pp.Plain -like 'Calibration : 7 %, reste environ * (passe 1/5, 0/30/100 ns, écriture)') "attente d un echange : libelle fige, barre inchangee ; sans Cross : libelle ordinaire"

# ================================================================ H. titre de la zone de l Accueil
"--- H. Get-HomeProgTitle (200)"
function Invoke-HomeTitle {
    . $gen
    function T([string]$s) { return $s }
    $o = @{}
    $o.X = Get-HomeProgTitle @{ Mode = 'fine'; Family = 'std'; Slow = $true; Drive = 'A'; Cross = @{ Src = 'A'; Tgt = '0' }; Home = $false } $null
    $o.P = Get-HomeProgTitle @{ Mode = 'std'; Family = 'long'; Slow = $false; Drive = 'A'; Home = $false } $null
    return $o
}
$ht = Invoke-HomeTitle
Chk 'H1' ($ht.X -eq 'Calibration croisée en cours : écriture par le lecteur A, relecture par le lecteur 0, Standard 2 us, test fin, une courbe par tête' -and $ht.P -eq 'Calibration en cours : lecteur A, Long track 1,89 us, test standard, courbe commune') "titre croise « $($ht.X) » ; ordinaire inchange"

# ================================================================ R. relecture : fenetre de decision (texte reel de $head, Show-CalibReview, 250)
"--- R. Show-CalibReview : texte « Conserver la courbe » d une calibration croisee (affectation reelle de `$head)"
function Get-ReviewHeadFn([string]$m) {
    # Premiere affectation reelle « $head = if (...) » de Show-CalibReview (250), enveloppee dans une fonction de travail
    $ast = Get-Cal2Ast (Join-Path $m '250-fn-calib-fenetres.ps1')
    $fd = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Show-CalibReview' }, $false))
    if ($fd.Count -ne 1) { throw 'Show-CalibReview introuvable' }
    $st = @($fd[0].Body.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq '$head' -and $_.Operator -eq 'Equals' })
    if ($st.Count -lt 1) { throw 'affectation de $head introuvable' }
    return ('function Get-Cal2ReviewHead($cal, [bool]$toWrite, [bool]$lvl, [bool]$infoWin, $lvl2, [bool]$noFields) {' + "`r`n" + $st[0].Extent.Text + "`r`n" + 'return $head' + "`r`n}")
}
$genR = Join-Path $here 'gen-1210-cross-review.ps1'
Write-Cal2Gen $genR @((Get-ReviewHeadFn $mods))
function Invoke-ReviewHead {
    . $genR
    function T([string]$s) { return $s }
    $o = @{}
    $o.X = Get-Cal2ReviewHead @{ Mode = 'fine'; Cross = @{ Src = 'A'; Tgt = '0' }; DiskOnly = $false } $false $false $false $null $false
    $o.P = Get-Cal2ReviewHead @{ Mode = 'fine'; DiskOnly = $false } $false $false $false $null $false
    $o.W = Get-Cal2ReviewHead @{ Mode = 'fine'; DiskOnly = $false } $true $false $false $null $false
    $o.L = Get-Cal2ReviewHead @{ Mode = 'level' } $false $true $false $null $false
    return $o
}
$rh = Invoke-ReviewHead
Chk 'R1' ($rh.X -eq "Conserver la courbe : elle est enregistrée pour les écritures du lecteur A destinées au lecteur 0 (courbe croisée « A → 0 »), sans modifier la courbe propre du lecteur A.`nAbandonner la courbe : la courbe croisée précédente, s'il y en avait une, est rétablie.") "croise : « $(($rh.X -split "`n")[0]) » / « $(($rh.X -split "`n")[1]) »"
Chk 'R2' ($rh.P -eq "Conserver la courbe : elle est enregistrée et appliquée aux prochaines écritures.`nAbandonner la courbe : la calibration précédente est rétablie." -and $rh.W -like "Écrire l'image : la courbe est conservée et l'image est écrite avec elle.*" -and $rh.L -like 'Conserver le niveau : le profil décalé reste dans les champs --precomp*') "sans Cross : textes ordinaires inchanges (calibration complete, avant une ecriture, calibration rapide)"

# ================================================================ I. relecture : configuration (Import-DriveCurves, Export-DriveCurves reels, 120)
"--- I. Import-DriveCurves (120) : cle croisee « A>0|std » sans drive ni target, champs presents gardes, cle ordinaire sans drive ; deux lecteurs, vue par lecteur ; export"
$genI = Join-Path $here 'gen-1210-cross-import.ps1'
$partsI = New-Object System.Collections.Generic.List[string]; $foundI = @{}
Add-Cal2Fns $partsI (Get-Cal2FnDefs (Join-Path $mods '120-fn-configuration.ps1')) @('Import-DriveCurves', 'Export-DriveCurves', 'Get-Cfg') $foundI '120'
Write-Cal2Gen $genI $partsI
Test-Cal2Missing @('Import-DriveCurves', 'Export-DriveCurves', 'Get-Cfg') $foundI
function Invoke-ImportCase {
    . $gen
    . $genI
    function T([string]$s) { return $s }
    $cmbDrive = [pscustomobject]@{ Text = 'A' }
    $o = @{}
    function New-CfgCurve([string]$drive, [string]$target, $head, [string]$spec, [string]$date) {
        $c = New-OwnCurve 0; $c.Head = $head; $c.Drive = $drive; $c.Target = $target; $c.Spec = $spec; $c.Date = $date; $c.Calc = [string]$script:CalibCalc
        return (ConvertTo-CurveConfig $c)
    }
    # Bloc driveCurves comme relu du fichier (objets JSON) : cle croisee commune sans champs, par tete avec champs (tete 1 :
    # lecteur B garde tel quel, cible vide posee), cle ordinaire du lecteur 0 sans lecteur, cle du lecteur A complete
    $dcv = [ordered]@{ 'A>0|std' = (New-CfgCurve '' '' $null '0=21' '07/11/2026 12:00'); 'A>0|std_h0' = (New-CfgCurve 'A' '0' 0 '0=20' '08/11/2026 12:00')
                        'A>0|std_h1' = (New-CfgCurve 'B' '' 1 '0=22' '08/11/2026 12:00'); '0|std' = (New-CfgCurve '' '' $null '0=70' '06/11/2026 12:00'); 'A|std' = (New-CfgCurve 'A' '' $null '0=50' '05/11/2026 12:00') }
    $w = ([pscustomobject]@{ driveCurves = $dcv } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $imp = Import-DriveCurves $null (Get-Cfg $w 'driveCurves' $null) 'A'
    $o.Imp = @{ N = [int]$imp.N; Old = @($imp.Old.Keys).Count; Drives = @($imp.Drives); Migrated = [bool]$imp.Migrated }
    foreach ($k in 'A>0|std', 'A>0|std_h0', 'A>0|std_h1', '0|std', 'A|std') { $p = Split-DriveCurveKey $k; $cv = Get-DriveCurve $p.Drive $p.Key; $o[$k] = @{ Drive = [string]$cv.Drive; Target = [string]$cv.Target; Spec = [string]$cv.Spec } }
    $o.LblX = Get-DriveCurveLabel 'A>0|std'
    Sync-PrecompCurves 'A'; $o.ViewA = @{ Std = $script:PrecompCurves['std'].Spec; H0 = $script:PrecompCurves['std_h0']; PStd = $script:PrecompStd }
    Sync-PrecompCurves '0'; $o.View0 = @{ Std = $script:PrecompCurves['std'].Spec; H0 = $script:PrecompCurves['std_h0']; PStd = $script:PrecompStd }
    $o.FX = Get-DriveFamilyCurves 'A>0' 'std' $true
    $o.KeysA = @(Get-DriveCurveKeys 'A'); $o.Keys0 = @(Get-DriveCurveKeys '0'); $o.KeysX = @(Get-DriveCurveKeys 'A>0'); $o.KeysAll = @(Get-DriveCurveKeys)
    $ex = Export-DriveCurves $null
    $o.Ex = @{ Keys = @($ex.Keys); XDrive = [string]$ex['A>0|std'].drive; XTarget = [string]$ex['A>0|std'].target; H1Drive = [string]$ex['A>0|std_h1'].drive; H1Target = [string]$ex['A>0|std_h1'].target; ADrive = [string]$ex['A|std'].drive; ATarget = [string]$ex['A|std'].target }
    $script:DriveCurves = @{}; Sync-PrecompCurves 'A'
    return $o
}
$im = Invoke-ImportCase
Chk 'I1' ($im['A>0|std'].Drive -eq 'A' -and $im['A>0|std'].Target -eq '0' -and $im['A>0|std'].Spec -eq '0=21') "cle croisee « A>0|std » sans drive ni target : source A et cible 0 poses d apres la cle ($($im['A>0|std'].Drive) -> $($im['A>0|std'].Target))"
Chk 'I2' ($im['A>0|std_h0'].Drive -eq 'A' -and $im['A>0|std_h0'].Target -eq '0' -and $im['A>0|std_h1'].Drive -eq 'B' -and $im['A>0|std_h1'].Target -eq '0') "champs presents gardes (tete 0 : A/0 ; tete 1 : drive B garde, target vide -> 0)"
Chk 'I3' ($im['0|std'].Drive -eq '0' -and $im['0|std'].Target -eq '' -and $im['A|std'].Drive -eq 'A' -and $im['A|std'].Target -eq '' -and $im.Imp.N -eq 5 -and $im.Imp.Old -eq 0 -and -not $im.Imp.Migrated -and (($im.Imp.Drives | Sort-Object) -join ',') -eq ((@('0', 'A', 'A>0') | Sort-Object) -join ',')) "cle ordinaire sans drive : lecteur de la cle (0), cible vide ; 5 courbes reprises, aucune mise de cote, lecteurs 0, A, A>0"
Chk 'I4' ($im.LblX -eq 'Standard 2 us (commune), écriture par le lecteur A pour le lecteur 0' -and $im.ViewA.Std -eq '0=50' -and $null -eq $im.ViewA.H0 -and $im.ViewA.PStd -eq '0=50' -and $im.View0.Std -eq '0=70' -and $null -eq $im.View0.H0 -and $im.View0.PStd -eq '0=70' -and $im.FX.Count -eq 2 -and $im.FX[0].Spec -eq '0=20' -and (($im.KeysA) -join ',') -eq 'A|std' -and (($im.Keys0) -join ',') -eq '0|std' -and $im.KeysX.Count -eq 3 -and $im.KeysAll.Count -eq 5) "deux lecteurs : vue du lecteur A (0=50) et du lecteur 0 (0=70) sans les courbes croisees, profil de famille de chacun ; courbes croisees par tete ; cles par lecteur (A : 1, 0 : 1, A>0 : 3, toutes : 5)"
Chk 'I5' ($im.Ex.Keys.Count -eq 5 -and $im.Ex.XDrive -eq 'A' -and $im.Ex.XTarget -eq '0' -and $im.Ex.H1Drive -eq 'B' -and $im.Ex.H1Target -eq '0' -and $im.Ex.ADrive -eq 'A' -and $im.Ex.ATarget -eq '') "export : 5 cles, champs drive et target reecrits apres leur completion (A>0|std : A/0), courbe ordinaire sans cible"

# ================================================================ D. relecture : copie d etat et retablissement sur des cles croisees (250) ; fenetre Courbe sans courbe (230)
"--- D. Get-CalibSnapshot et Restore-CalibState reels sur « A>0|std_hN » (refus du resultat) ; Show-CurvesWindow sans courbe"
function Invoke-SnapCase {
    . $gen
    function T([string]$s) { return $s }
    function Update-PrecompForImage([string]$path) { $script:NUpd2++ }
    function Save-Config { $script:NSave2++; return $true }
    function Get-WProfileText { return '' }
    $cmbDrive = [pscustomobject]@{ Text = 'A' }; $txtWFile = [pscustomobject]@{ Text = '' }
    $cmbWProfile = [pscustomobject]@{ SelectedIndex = 0 }; $chkWPrecomp = [pscustomobject]@{ Checked = $true }; $txtWPrecomp = [pscustomobject]@{ Text = '0=10' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '' }; $lblWProfileInfo = [pscustomobject]@{ Text = '' }
    $script:CurveForm = $null; $script:Restore = $null; $script:NUpd2 = 0; $script:NSave2 = 0
    $script:LevelShifts = @{ 'std_h0|c|0|1' = @{ RefKey = 'std_h0'; Drive = 'A' } }
    $x0 = New-OwnCurve 0; $x0.Target = '0'; $x0.Spec = '0=20'; $x0.Date = '07/11/2026 10:00'
    $script:DriveCurves = @{ 'A|std_h0' = (New-OwnCurve 0); 'A|std_h1' = (New-OwnCurve 1); 'A>0|std_h0' = $x0 }
    Sync-PrecompCurves 'A'
    $script:PrecompStd = '0=50'
    $snap = Get-CalibSnapshot @('A>0|std_h0', 'A>0|std_h1')
    $o = @{ SnapDrive = [string]$snap.Drive; SnapH0 = [string]$snap.Curves['std_h0'].Spec; SnapH1Null = ($null -eq $snap.Curves['std_h1']); SnapKeys = ((@($snap.Curves.Keys) | Sort-Object) -join ','); SnapStd = [string]$snap.Std }
    # Nouvelles courbes croisees (fin de calibration), puis refus du resultat : retablissement
    $n0 = New-OwnCurve 0; $n0.Target = '0'; $n0.Spec = '0=25'; $n0.Date = '09/11/2026 10:00'
    $n1 = New-OwnCurve 1; $n1.Target = '0'; $n1.Spec = '0=27'; $n1.Date = '09/11/2026 10:00'
    Set-DriveCurve 'A>0' 'std_h0' $n0; Set-DriveCurve 'A>0' 'std_h1' $n1
    $o.AfterSet = @{ H0 = (Get-DriveCurve 'A>0' 'std_h0').Spec; H1 = (Get-DriveCurve 'A>0' 'std_h1').Spec; ViewH0 = $script:PrecompCurves['std_h0'].Spec; Keys = (@(Get-DriveCurveKeys) -join ',') }
    $script:PrecompStd = '0=99'   # profil de famille modifie entre-temps : un retablissement croise ne le touche pas (lecteur « A>0 » n est pas celui du bandeau)
    Restore-CalibState $snap
    $o.AfterRestore = @{ H0 = (Get-DriveCurve 'A>0' 'std_h0').Spec; H1Null = ($null -eq (Get-DriveCurve 'A>0' 'std_h1')); Keys = (@(Get-DriveCurveKeys) -join ','); ViewH0 = $script:PrecompCurves['std_h0'].Spec; Std = $script:PrecompStd; Levels = @($script:LevelShifts.Keys).Count; NUpd = $script:NUpd2; NSave = $script:NSave2; P0 = [string]$txtWPrecomp.Text }
    # Fenetre Courbe sans courbe (lecteur ou cle croisee sans courbe) : rien, aucune fenetre creee
    $script:CurveForm = $null
    $o.NoCurve = Show-CurvesWindow (Get-DriveFamilyCurves 'B>0' 'std' $true)
    $o.NoCurveNull = Show-CurvesWindow $null
    $o.NoForm = ($null -eq $script:CurveForm)
    $script:DriveCurves = @{}; Sync-PrecompCurves 'A'; $script:LevelShifts = @{}
    return $o
}
$sn = Invoke-SnapCase
Chk 'D1' ($sn.SnapDrive -eq 'A>0' -and $sn.SnapH0 -eq '0=20' -and $sn.SnapH1Null -and $sn.SnapKeys -eq 'std_h0,std_h1' -and $sn.SnapStd -eq '0=50') "copie d etat sur des cles croisees : lecteur de magasin A>0, courbe croisee precedente de la tete 0, aucune pour la tete 1, profil de famille copie"
Chk 'D2' ($sn.AfterSet.H0 -eq '0=25' -and $sn.AfterSet.H1 -eq '0=27' -and $sn.AfterSet.ViewH0 -eq '0=50' -and $sn.AfterSet.Keys -eq ((@('A>0|std_h0', 'A>0|std_h1', 'A|std_h0', 'A|std_h1') | Sort-Object) -join ',')) "nouvelles courbes croisees en magasin, vue du lecteur A inchangee (courbe propre 0=50), 4 cles"
Chk 'D3' ($sn.AfterRestore.H0 -eq '0=20' -and $sn.AfterRestore.H1Null -and $sn.AfterRestore.Keys -eq ((@('A>0|std_h0', 'A|std_h0', 'A|std_h1') | Sort-Object) -join ',') -and $sn.AfterRestore.ViewH0 -eq '0=50' -and $sn.AfterRestore.Std -eq '0=99' -and $sn.AfterRestore.Levels -eq 1 -and $sn.AfterRestore.NUpd -eq 1 -and $sn.AfterRestore.NSave -eq 1 -and $sn.AfterRestore.P0 -eq '0=10') "refus : courbe croisee precedente retablie (tete 0), entree de la tete 1 retiree, vue et profil de famille du lecteur du bandeau non touches, niveaux gardes, profil de l image recalcule, configuration enregistree"
Chk 'D4' ($null -eq $sn.NoCurve -and $null -eq $sn.NoCurveNull -and $sn.NoForm) "Show-CurvesWindow sans courbe (lecteur B>0 sans courbe, liste nulle) : rien, aucune fenetre"

Get-Cal2Bilan 'logic-1210-cross-j'
"duree : $(F $sw.Elapsed.TotalSeconds '0') s"
exit $(if ($script:Fail) { 1 } else { 0 })
