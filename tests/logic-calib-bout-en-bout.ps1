param(
    [string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci,
    # Modules d avant les corrections (scenario HD : meme graine, memes nombres attendus) ; vide : scenario HD saute
    [string]$Base = '',
    # Tirages par scenario (specification : 20, soit 40 couples tirage-tete) ; E : 50 au moins (100 couples, revue m1) ;
    # C : 5 au plus ; HD : 3 au plus par jeu ; RK0 : 3 au plus
    [int]$Draws = 20,
    [string[]]$Scenarios = @('A', 'E', 'E1r', 'N', 'R', 'C', 'U', 'HD', 'RK0'),
    [int]$Seed = 129
)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-129-cal2-e2e) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Harnais cal2-commun.ps1 a cote du test ; source d avant (-Base) facultative.
# 12.9, corrections du calcul de calibration (spec-finale.md § 11.3) : calibration simulee de bout en bout, test fin,
# 80 cylindres, ecriture lente (une unite par tete). Harnais de v129\c\fix\corriger\rt7\logic-rt7.ps1 : fonctions reelles
# de 230, 240 et 270 (entiers), Format-LevelNum (260), Solve-ContentLinear (274), constantes de 560 et versions de 000,
# extraites par l arbre syntaxique puis dot-source ; type C# CurveFit (statement Add-Type de 030 recopie tel quel, puis
# CurveFitOk vrai) ; etat initial construit par l affectation reelle de Start-PrecompCalib (§ 1.4). Remplacants :
# Append-Log, New-CalibPass (pose Pending ; a l etape 'coarse', ce que ferait la vraie : conditionnement par
# Complete-CalibCondition reel, puis Set-CalibCoarsePlan reel), Read-ScpFile (pistes simulees), Update-CalibProgress,
# Update-HomeCalibCard, Stop-PrecompCalib, Complete-PrecompCalib (Get-CalibWarnings et Write-CalibDentLog reels, courbe
# enregistree par ConvertTo-CurveConfig reel avec les champs de dents du § 5.8). Controle de surface neutralise
# (SurfDone vrai, revue m12). gw simule (fonctions nommees, graines fixes) : decalage lu = -1,55 (W - z) + 6,4 (exp(-W/40)
# - exp(-z/40)) + alpha + E1 + bruit N(0 ; 2,0 / 1,75 ns) par piste, 3 tours a +-0,3 ns ; alpha N(0 ; 1 ns) par commande des
# passes de mesure et d encadrement (correlation 0,35 entre tetes dans une commande), N(0 ; 2 ns) par commande de
# verification (une par tete) ; E1 : +6 max(0 ; 1 - t / 60) ns a la t-ieme piste ecrite de la premiere ecriture apres le
# prechauffage (conditionnement s il a lieu, sinon passe 1 ; E1r : 30 % restent sur la passe 1). Aucun gw, aucune fenetre.
# Revue du 31/10/2026 (v129\cal2\impl\revue\rapport.md) : M1, critere E7 (mediane de la courbe envoyee a la verification
# 1 moins le besoin sur c0-c19, |.| <= 0,4 ns : seul critere numerique qui separe l absence du conditionnement et la
# reference 12.8.2) et seuils E2 88 %, E1r 94 % (la reference 12.8.2 passait E1r a 90 %) ; m1, scenario E a 50 tirages
# au moins et E3 >= 85 % (100 couples ; a 40 couples, E3 dependait de la graine) ; m2, scenario RK0 (dent fausse retiree
# sur une courbe sans changement de sens : ligne « Courbe lissée sans la dent retirée », jamais « 0 cylindre(s)
# corrigé(s), résidu hors tolérance »)
# fix2 (banc cal2, option A, 01/11/2026) : WriteMax de l application (270:86 ; logic-129-cal2-cmd K8a) : en double densite,
# le nouvel essai est compte a part (+ CalMaxRetest sous $cond) : test fin 7 -> 8 ; E0 attend 8. Scenario A (indicateurs
# a faux, 12.8.2) et haute densite : 6, inchange
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
. (Join-Path $PSScriptRoot 'cal2-commun.ps1')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$simDir = Join-Path $here 'sim-e2e'
New-Item -ItemType Directory -Force $simDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $simDir 'precomp-calib.scp'), 'x')
function New-E2eGen([string]$m, [string]$outFn, [string]$outConst) {
    $parts = New-Object System.Collections.Generic.List[string]; $found = @{}
    foreach ($f in '230-fn-calib-courbe.ps1', '240-fn-calib-mesure.ps1', '270-fn-calib-complete.ps1') { Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m $f)) @('*') $found $f }
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '260-fn-calib-rapide.ps1')) @('Format-LevelNum') $found '260'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '274-fn-contenu-calcul.ps1')) @('Solve-ContentLinear') $found '274'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '280-fn-calib-surface.ps1')) @('Test-CalibSpeedOnly') $found '280'
    $parts.Add((Get-Cal2CalStateFn $m))
    Write-Cal2Gen $outFn $parts
    Write-Cal2Gen $outConst (Get-Cal2Consts $m)
    return $found
}
$mods = Get-Cal2Modules $Wt; $hasBase = [bool]($Base -and (Test-Path -LiteralPath $Base)); if ($hasBase) { $bmods = Get-Cal2Modules $Base } else { $Scenarios = @($Scenarios | Where-Object { $_ -ne 'HD' }); "  source de reference absente : scenario HD saute" }
$genFn = @{ 'new' = (Join-Path $here 'gen-cal2-e2e.ps1'); 'base' = (Join-Path $here 'gen-cal2-e2e-base.ps1') }
$genConst = @{ 'new' = (Join-Path $here 'gen-cal2-e2e-const.ps1'); 'base' = (Join-Path $here 'gen-cal2-e2e-const-base.ps1') }
$fn = New-E2eGen $mods $genFn['new'] $genConst['new']
$newNeeded = @($Scenarios | Where-Object { $_ -ne 'A' }).Count -gt 0
if ($newNeeded) { Test-Cal2Missing @('Set-CalibCoarsePlan', 'Complete-CalibCondition', 'Set-CalibPassOffsets', 'Get-CalibDents', 'Update-CalibDents', 'Get-FitDents', 'Write-CalibDentLog', 'Split-CurveDents') $fn }
if ($hasBase) { $null = New-E2eGen $bmods $genFn['base'] $genConst['base'] }
$genCf = Join-Path $here 'gen-cal2-e2e-cf.ps1'
Write-Cal2Gen $genCf @((Get-Cal2CurveFit $mods))
. $genCf
"logic-129-cal2-e2e : $($fn.Count) fonctions (wt-129) ; scenarios $($Scenarios -join ', ') ; $Draws tirages ; graine $Seed ; PowerShell $($PSVersionTable.PSVersion)"
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()

# ---------------------------------------------------------------- gw simule
function Test-SimDent([string]$scen) { return (@('A', 'E', 'E1r', 'C') -contains $scen) }
function Get-SimZ([int]$c, [int]$h, [bool]$withZone) {
    # Besoin vrai (ns) ; scenario C : zone c64-c66 vue 8 ns plus bas par la verification 1, 8 ns plus haut ensuite
    # RK0 (revue m2) : besoin lisse sans changement de sens (aucune rupture c43/c44), tete 1 : + 3 ns
    if ($script:SimScen -eq 'RK0') { return 7.0 + 0.45 * $c + 3.0 * $h }
    $z = Get-NeedA $c $h (Test-SimDent $script:SimScen)
    if ($script:SimHd) { $z = 0.5 * $z }
    if ($withZone -and $script:SimScen -eq 'C' -and $c -ge 64 -and $c -le 66 -and $script:Cal -and $script:Cal.Stage -eq 'verify') { if ([int]$script:Cal.VerifyCount -le 1) { $z -= 8.0 } else { $z += 8.0 } }
    return $z
}
function New-SimTrack([double]$w, [double]$z, [int]$h, [double]$extra) {
    $kap = 6.4; $lam = 40.0
    if ($script:SimHd) { $kap = 3.2; $lam = 20.0 }
    $sg = if ($h -eq 0) { 2.0 } else { 1.75 }
    $s = (Get-Cal2Shift $w $z 1.55 $kap $lam) + $extra + $script:SimNoise * $sg * (Get-N01)
    $l = @()
    foreach ($rev in 1..3) { $l += [pscustomobject]@{ Shift = $s + $script:SimNoise * 0.3 * (Get-U11); ShiftSE = 0.95; Jitter = 40.0; R3 = 1.5; R4 = 2.0; OutOfClass = 0; NFlux = 50000 } }
    return ,$l
}
function Get-UnitHeads($u) { if ($null -eq $u.Head) { return @(0, 1) }; return @([int]$u.Head) }
function New-SimPass {
    # Pistes relues a l etape en cours : passe de mesure (valeur par cylindre PassW, ou Value), encadrement (Bracket de
    # chaque unite, une commande par tete), verification (profil de chaque unite, VerifyList ; passe du nouvel essai :
    # unites concernees seulement)
    $cal = $script:Cal; $tr = @{}
    if ($cal.Stage -eq 'coarse') {
        $a0 = $script:SimNoise * (Get-N01); $a1 = 0.35 * $a0 + $script:SimNoise * [math]::Sqrt(1.0 - 0.35 * 0.35) * (Get-N01)
        foreach ($c in @($cal.Cyls)) {
            $w = if ($cal.PassW -and $cal.PassW.ContainsKey([int]$c)) { [double]$cal.PassW[[int]$c] } else { [double]$cal.Value }
            foreach ($h in 0, 1) {
                $e1 = if ($script:SimE1Left -gt 0) { $script:SimE1Left * [math]::Max(0.0, 1.0 - (2 * [int]$c + $h) / 60.0) } else { 0.0 }
                $tr[2 * [int]$c + $h] = New-SimTrack $w (Get-SimZ ([int]$c) $h $true) $h ($(if ($h -eq 0) { $a0 } else { $a1 }) + $e1)
            }
        }
        $script:SimE1Left = 0.0
    }
    elseif ($cal.Stage -eq 'bracket') {
        foreach ($u in @($cal.Units)) {
            $a = $script:SimNoise * (Get-N01)
            foreach ($c in @($u.Bracket.Keys)) { foreach ($h in (Get-UnitHeads $u)) { $tr[2 * [int]$c + $h] = New-SimTrack ([double]$u.Bracket[$c]) (Get-SimZ ([int]$c) $h $true) $h $a } }
        }
    }
    elseif ($cal.Stage -eq 'verify') {
        foreach ($u in @($cal.Units)) {
            if ([int]$cal.Retests -gt 0 -and -not $u.InRetest) { continue }
            $aV = 2.0 * $script:SimNoise * (Get-N01)
            $rc = if ($null -ne $u.VerifyList) { @($u.VerifyList) } else { @($cal.Cyls) }
            foreach ($c in $rc) { $w = [double](Get-SpecValue $u.Profile ([int]$c)); foreach ($h in (Get-UnitHeads $u)) { $tr[2 * [int]$c + $h] = New-SimTrack $w (Get-SimZ ([int]$c) $h $true) $h $aV } }
        }
    }
    else { throw "etape non simulee : $($cal.Stage)" }
    $script:SimTracks = $tr
}
function Get-Med($a) { $s = @(@($a) | ForEach-Object { [double]$_ } | Sort-Object); if ($s.Count -eq 0) { return [double]::NaN }; $m = [int][math]::Floor($s.Count / 2); if ($s.Count % 2) { return $s[$m] }; return ($s[$m - 1] + $s[$m]) / 2.0 }

# ---------------------------------------------------------------- calibrations simulees, par jeu de fonctions
function Invoke-SetRuns([string]$set, $jobs) {
    . $genFn[$set]
    function T([string]$s) { return $s }
    function Format-UiNum([double]$v, [string]$fmt = '0.#') { return $v.ToString($fmt, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
    function Append-Log([string]$text) { $script:SimLog.Add($text) }
    function Update-CalibProgress { }
    function Update-HomeCalibCard { }
    function Set-HomeProgDone($a, $b, $c) { }
    function Stop-PrecompCalib([switch]$GwError) { $script:SimStop = $true; $script:Cal = $null }
    function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger, [switch]$NoIndexZone) { return $script:SimTracks }
    function Get-SimDents($fit) { if (Get-Command Get-FitDents -CommandType Function -ErrorAction SilentlyContinue) { return @(Get-FitDents $fit) }; return @() }
    function New-CalibPass {
        $cal = $script:Cal
        if (-not $cal) { return }
        if ($cal.Stage -eq 'coarse') {
            if ($cal.Cond -and [int]$cal.Index -eq 0 -and -not $cal.CondDone) {
                # Conditionnement (§ 4.5) : ecriture sans relecture ; le transitoire E1 la touche (30 % restent en E1r)
                $script:SimCondN++
                $script:SimE1Left = if ($script:SimScen -eq 'E1r') { 0.3 * $script:SimE1 } else { 0.0 }
                $cal.CondRun = $true; $cal.CondStart = Get-Date
                Complete-CalibCondition
                return
            }
            if (Get-Command Set-CalibCoarsePlan -CommandType Function -ErrorAction SilentlyContinue) { Set-CalibCoarsePlan $cal }
            else { $cal.Value = [int]$cal.Values[$cal.Index]; $cal.Spec = "0=$($cal.Value)"; $cal.ValueTxt = "$($cal.Value) ns" }
        }
        $script:SimPending = $true
    }
    function Complete-PrecompCalib {
        $cal = $script:Cal; $script:Cal = $null
        if (-not $cal) { return }
        $us = @()
        foreach ($u in @($cal.Units)) {
            $u.Warn = Get-CalibWarnings $u ([int]$cal.MaxCyl)
            if (Get-Command Write-CalibDentLog -CommandType Function -ErrorAction SilentlyContinue) { Write-CalibDentLog $u }
            $cs = @($u.Est.Keys | ForEach-Object { [int]$_ } | Sort-Object)
            # Courbe enregistree (270:1842) : champs de dents du § 5.8 (toutes les dents de la courbe, regles de Contra)
            $rec = @{ Family = 'Standard 2 us'; Head = $u.Head; Drive = 'A'; Date = '31/10/2026 18:00'; Model = $u.Fit.Model; Spec = $u.Profile; Method = 'motif'
                      Version = $script:Version; Algo = $script:CalibAlgo; Calc = $script:CalibCalc; Breaks = [int[]]@($u.Fit.Breaks)
                      Values = [int[]]@($u.Fit.Values); Cyls = [int[]]$cs; Ys = [double[]]@($cs | ForEach-Object { [math]::Round([double]$u.Est[$_], 1) })
                      Sig = [double[]]@($cs | ForEach-Object { 1.0 }); Kinds = [string[]]@($cs | ForEach-Object { [string]$u.Kind[$_] }); Res = [double[]]@($cs | ForEach-Object { 0.0 })
                      Converged = (@($u.Warn.NonConv).Count -eq 0); MaxX = 100; MaxNs = 400; Slope = -1.55; Bits = 101344; Test = 'fine'
                      Contra = [int[]]@(@($u.Warn.Contra) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object)
                      DentLo = [int[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_.C1 })
                      DentHi = [int[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_.C2 })
                      DentNs = [double[]]@(@($u.Warn.Dents) | Where-Object { $null -ne $_ } | ForEach-Object { [math]::Round([double]$_.Drop, 1) }) }
            $cfg = ConvertTo-CurveConfig $rec
            $back = $null
            if ($cfg) { $back = ConvertFrom-CurveConfig (($cfg | ConvertTo-Json -Depth 6 -Compress) | ConvertFrom-Json) }
            $us += ,@{ Head = $u.Head; Prefix = $u.Prefix; Values = [int[]]@($u.Fit.Values); Breaks = [int[]]@($u.Fit.Breaks); Segs = (Get-SegTxt $u.Fit); Dents = @(Get-SimDents $u.Fit)
                       WarnHasDents = $u.Warn.ContainsKey('Dents'); WarnDentsNull = ($null -eq $u.Warn.Dents); WarnDentsArr = ($u.Warn.Dents -is [array]); WarnDents = @(@($u.Warn.Dents) | Where-Object { $null -ne $_ })
                       Conv = (@($u.Warn.NonConv).Count -eq 0); Steps = @(@($u.Warn.Steps) | Where-Object { $null -ne $_ }); Contra = [int[]]@($u.Warn.Contra)
                       Cfg = $cfg; Back = $back; Model = [string]$u.Fit.Model }
        }
        $script:SimOut = @{ Units = $us; Passes = [int]$cal.PassesDone; Retests = [int]$cal.Retests; CondDone = $cal.CondDone; Stop = $false }
    }
    function Add-SimFalseDent($cal) {
        # Scenario R : dent fausse c30/c31 dans la courbe envoyee a la verification 1 (besoin sans dent) : courbe refaite
        # par Fit-PrecompCurve -Dents reel (segments coupes), sinon champ Dents seul
        foreach ($u in @($cal.Units)) {
            $d = @{ C1 = 30; C2 = 31; Drop = 6.0; Min = 4.0; Conf = $null; V = 0; DV = [double]::NaN }
            $f = Fit-PrecompCurve $u.Est $u.Sig ([int]$cal.MaxCyl) $u.Kind $true -Dents @($d)
            if ($f -and @($f.Dents).Count -gt 0) { $u.Fit = $f; $u.Profile = Build-CurveProfile $f.Values }
            else { $u.Fit.Dents = @($d) }
        }
    }
    function Get-SimV1($cal) {
        # Residus de la verification 1 (toutes les pistes relues) et etat de la courbe apres son analyse
        return @(foreach ($u in @($cal.Units)) {
            $r = @{}; $tol = @{}; $p = @{}
            foreach ($k in @($u.Verify.Keys)) { $r[[int]$k] = [double]$u.Verify[$k].Shift; $tol[[int]$k] = [double](Get-ResidualTol $u.Verify[$k]); $p[[int]$k] = [int]$u.VerifyP[$k] }
            ,@{ R = $r; Tol = $tol; P = $p; Dents = @(Get-SimDents $u.Fit); Segs = (Get-SegTxt $u.Fit) }
        })
    }
    function Invoke-OneSim($job) {
        . $genConst[$set]
        $script:CurveFitOk = $true; $script:Lang = 'fr'
        Set-Cal2Rng ([int]$job.Seed)
        $scen = [string]$job.Scen; $fam = [string]$job.Fam
        $script:SimScen = $scen; $script:SimHd = ($fam -eq 'hd'); $script:SimE1 = 6.0; $script:SimE1Left = 6.0; $script:SimCondN = 0
        $script:SimNoise = $(if ($job.NoNoise) { 0.0 } else { 1.0 })
        $script:SimLog = New-Object System.Collections.Generic.List[string]; $script:SimPending = $false; $script:SimOut = $null; $script:SimStop = $false
        $script:TempDir = $simDir; $script:Restore = $null; $script:CalRedo = $null; $script:AfterCalib = ''; $script:Chain = New-Object System.Collections.Queue
        $script:PrecompCurves = @{}
        $cmbDrive = [pscustomobject]@{ Text = 'A' }; $pbWCal = [pscustomobject]@{ Value = 0; Visible = $false }; $lblWCal = [pscustomobject]@{ Text = ''; Visible = $false }
        Set-CalibScale $fam
        if ($scen -eq 'A') { $script:CalCondPass = $false; $script:CalLatin = $false; $script:CalDentOn = $false; $script:CalCoarse = @(0, 100, 200) }
        $cyls = @(0..79)
        $units = @((New-CalibUnit 0), (New-CalibUnit 1))
        foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
        $cond = if ($scen -eq 'A') { $false } else { [bool]$(if ($fam -eq 'hd') { $script:CalScaleHd.CalCondPass } else { $script:CalScaleDd.CalCondPass }) }
        $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
        $nPassMax = $nPassEst + 1 + $(if ($cond) { 1 } else { 0 }) + $(if ($cond) { [int]$script:CalMaxRetest } else { 0 })
        $pat = @{ Path = 'C:\x\precomp-pattern.hfe'; Bits = $(if ($fam -eq 'hd') { 200000 } else { 101344 }) }
        New-Cal2CalState $true $cyls 79 $fam $true 'C:\x\image.adf' $pat (Format-CylList $cyls) $units @{ Ok = $true; Swap = $false; Auto = $false } $false $nPassEst $(if ($fam -eq 'hd') { 0.0 } else { 0.37 }) $true $nPassMax $cond $false $null
        $script:Cal.SurfDone = $true
        $st0 = @{ Cond = $script:Cal.Cond; Latin = $script:Cal.Latin; Dent = $script:Cal.Dent; Values = (@($script:Cal.Values) -join '/'); WriteMax = $script:Cal.WriteMax }
        $cap = @{ V1 = $null; Fit0 = $null; Dents0 = $null; Passes = @(); Levels = @($script:Cal.Values) }
        New-CalibPass
        $guard = 0
        while ($script:SimPending -and $script:Cal -and $guard -lt 20) {
            $script:SimPending = $false; $guard++
            $cal = $script:Cal
            $isV1 = ($cal.Stage -eq 'verify' -and [int]$cal.VerifyCount -eq 1 -and [int]$cal.Retests -eq 0)
            if ($isV1 -and $null -eq $cap.Dents0) {
                if ($scen -eq 'R' -or $scen -eq 'RK0') { Add-SimFalseDent $cal }
                $cap.Dents0 = @(foreach ($u in @($cal.Units)) { ,@(Get-SimDents $u.Fit) })
                $cap.Fit0 = @(foreach ($u in @($cal.Units)) { ,[int[]]@($u.Fit.Values) })
            }
            $cap.Passes += "$($cal.Stage)$(if ($cal.Stage -eq 'coarse') { [int]$cal.Index + 1 } elseif ($cal.Stage -eq 'verify') { [int]$cal.VerifyCount })"
            New-SimPass
            Invoke-CalibAnalysis
            if ($isV1) { $cap.V1 = Get-SimV1 $cal }
        }
        if (-not $script:SimOut) { throw "calibration non terminee (etapes $($cap.Passes -join ' '), arret $($script:SimStop))" }
        $o = $script:SimOut; $o.Cap = $cap; $o.State0 = $st0; $o.Log = @($script:SimLog); $o.CondN = $script:SimCondN; $o.Job = $job
        return $o
    }
    $res = New-Object System.Collections.Generic.List[object]
    foreach ($j in $jobs) {
        try { $res.Add((Invoke-OneSim $j)) }
        catch { $res.Add(@{ Error = "$($_.Exception.Message) (ligne $($_.InvocationInfo.ScriptLineNumber) : $($_.InvocationInfo.Line.Trim()))"; Job = $j }) }
        $script:Cal = $null
    }
    return ,$res.ToArray()
}

# ---------------------------------------------------------------- mesures sur les resultats
function Get-OkRuns($rs) { return @($rs | Where-Object { -not $_.Error }) }
function Get-ErrTxt($rs) { $e = @($rs | Where-Object { $_.Error }); if ($e.Count -eq 0) { return '' }; return " ; ERREURS $($e.Count) : $($e[0].Error)" }
function Test-DentOk($un) { return (@($un.Dents | Where-Object { [int]$_.C1 -eq 64 -and [int]$_.C2 -eq 65 -and $_.Conf -eq $true }).Count -gt 0) }
function Get-CurveStats($rs, [bool]$dent, [double]$lim) {
    # |courbe - besoin| <= lim sur les cylindres de chaque tete (c64-c66 exclus quand la dent n est pas trouvee)
    $n = 0; $ok = 0
    foreach ($r in (Get-OkRuns $rs)) {
        $hd = [bool]($r.Job.Fam -eq 'hd')
        foreach ($un in @($r.Units)) {
            $h = [int]$un.Head; $found = Test-DentOk $un
            for ($c = 0; $c -lt 80; $c++) {
                if ($dent -and -not $found -and $c -ge 64 -and $c -le 66) { continue }
                $z = Get-NeedA $c $h $dent; if ($hd) { $z = 0.5 * $z }
                $n++; if ([math]::Abs([double]$un.Values[$c] - $z) -le $lim) { $ok++ }
            }
        }
    }
    return @{ N = $n; Ok = $ok; Pct = $(if ($n) { 100.0 * $ok / $n } else { 0.0 }) }
}
function Get-V1Stats($rs) {
    # Residus de la verification 1 : |r - mediane de la tete| dans la tolerance du cylindre
    $n = 0; $ok = 0; $avg = 0
    foreach ($r in (Get-OkRuns $rs)) {
        if (-not $r.Cap.V1) { continue }
        $lv = @($r.Cap.Levels | ForEach-Object { [int]$_ })
        foreach ($v in @($r.Cap.V1)) {
            $med = Get-Med @($v.R.Values)
            foreach ($k in @($v.R.Keys)) { $n++; if ([math]::Abs([double]$v.R[$k] - $med) -le [double]$v.Tol[$k]) { $ok++ } }
            $avg += @($v.P.Keys | Where-Object { $lv -contains [int]$v.P[$_] }).Count
        }
    }
    return @{ N = $n; Ok = $ok; Pct = $(if ($n) { 100.0 * $ok / $n } else { 0.0 }); Avg = $avg }
}
function Get-Jobs([string]$scen, [int]$n, [string]$fam, [bool]$noNoise, [int]$k) {
    return @(for ($d = 0; $d -lt $n; $d++) { @{ Scen = $scen; Seed = ($Seed + 1000 * $k + $d); Fam = $fam; NoNoise = $noNoise; Draw = $d } })
}
$all = @{}
$order = @('A', 'E', 'E1r', 'N', 'R', 'C', 'U', 'HD', 'RK0')
foreach ($sc in $order) {
    if ($Scenarios -notcontains $sc) { continue }
    $t0 = $sw.Elapsed.TotalSeconds; $k = [array]::IndexOf($order, $sc)
    switch ($sc) {
        'E'  { $all[$sc] = Invoke-SetRuns 'new' (Get-Jobs 'E' ([math]::Max($Draws, 50)) 'std' $false $k) }
        'C'  { $all[$sc] = Invoke-SetRuns 'new' (Get-Jobs 'C' ([math]::Min($Draws, 5)) 'std' $false $k) }
        'RK0' { $all[$sc] = Invoke-SetRuns 'new' (Get-Jobs 'RK0' ([math]::Min($Draws, 3)) 'std' $false $k) }
        'U'  { $all[$sc] = Invoke-SetRuns 'new' @(@((Get-Jobs 'U' 1 'std' $true $k)) + @((Get-Jobs 'U' 1 'hd' $true ($k + 10)))) }
        'HD' { $jh = Get-Jobs 'HD' ([math]::Min($Draws, 3)) 'hd' $false $k; $all['HD'] = Invoke-SetRuns 'new' $jh; $all['HDb'] = Invoke-SetRuns 'base' $jh }
        default { $all[$sc] = Invoke-SetRuns 'new' (Get-Jobs $sc $Draws 'std' $false $k) }
    }
    "  scenario $sc : $(@($all[$sc]).Count) calibration(s) simulee(s) en $(F ($sw.Elapsed.TotalSeconds - $t0) '0') s"
}

# ---------------------------------------------------------------- A : temoin du modele (12.8.2)
if ($all.ContainsKey('A')) {
    "--- A. Indicateurs a faux, 0/100/200 (12.8.2), transitoire E1 sur la passe 1 : temoin du modele, pas un critere du code"
    $rs = $all['A']; $ok = Get-OkRuns $rs
    # Courbe issue des passes de mesure (envoyee a la verification 1) et courbe finale (apres les verifications)
    $d0 = @(); $d = @()
    foreach ($r in $ok) {
        $i = 0
        foreach ($un in @($r.Units)) {
            $f0 = @(@($r.Cap.Fit0)[$i])
            for ($c = 0; $c -le 19; $c++) { $z = Get-NeedA $c ([int]$un.Head) $true; $d0 += [double]$f0[$c] - $z; $d += [double]$un.Values[$c] - $z }
            $i++
        }
    }
    $md0 = Get-Med $d0; $md = Get-Med $d
    $flags = @($ok | Where-Object { $_.State0.Cond -or $_.State0.Latin -or $_.State0.Dent -or $_.State0.Values -ne '0/100/200' -or $_.CondN -ne 0 }).Count
    Chk 'A-temoin' ($ok.Count -eq @($rs).Count -and $flags -eq 0 -and $md0 -ge 1.0) "$($ok.Count) calibrations ; mediane de (courbe - besoin) sur c0-c19 : $(F $md0 '+0.00;-0.00') ns pour la courbe des passes de mesure (>= +1,0 : le modele reproduit le biais des premiers cylindres), $(F $md '+0.00;-0.00') ns apres les verifications (information) ; etats ou conditionnements inattendus : $flags$(Get-ErrTxt $rs)"
}

# ---------------------------------------------------------------- E : 12.9 complete
if ($all.ContainsKey('E')) {
    "--- E. 12.9 complete, transitoire E1 sur le conditionnement"
    $rs = $all['E']; $ok = Get-OkRuns $rs
    foreach ($r in $ok) {
        $txt = (@($r.Units) | ForEach-Object { "t$($_.Head) dent $(if (Test-DentOk $_) { 'oui' } else { 'non' }) $($_.Segs) convergee $($_.Conv)" }) -join ' ; '
        "    tirage $($r.Job.Draw) : etapes $(@($r.Cap.Passes) -join ' ') ; $txt"
    }
    $st = $ok | Select-Object -First 1
    $struct = ($ok.Count -eq @($rs).Count -and @($ok | Where-Object { $_.CondN -ne 1 -or -not $_.CondDone -or -not $_.State0.Cond -or -not $_.State0.Latin -or -not $_.State0.Dent -or $_.State0.Values -ne '0/30/100' -or [int]$_.State0.WriteMax -ne 8 -or (@($_.Cap.Passes)[0..3] -join ' ') -ne 'coarse1 coarse2 coarse3 verify1' }).Count -eq 0)
    Chk 'E0' $struct "$($ok.Count) calibrations sur $(@($rs).Count) : etat (§ 1.4) Cond, Latin, Dent vrais, niveaux 0/30/100, WriteMax 8 (test fin : 5 passes, encadrement, conditionnement, nouvel essai compte a part : option A, fix2) ; un conditionnement ; etapes coarse1-3 puis verify1$(Get-ErrTxt $rs)"
    if ($st) {
        $lg = @($st.Log)
        $nOff = @($lg | Where-Object { $_ -like '`[tête ?`] Calibration : décalage propre à chaque passe de mesure, retiré des mesures avant le calcul des zéros*' }).Count
        $nCond = @($lg | Where-Object { $_ -like 'Calibration : conditionnement du lecteur terminé en *' }).Count
        $nDent = @($lg | Where-Object { $_ -like '`[tête ?`] Dent locale du besoin entre c64 et c65 : baisse de * ns mesurée par les passes de mesure*la vérification la contrôlera.' }).Count
        $nConf = @($lg | Where-Object { $_ -like '`[tête ?`] Dent entre c64 et c65 confirmée par la vérification 1 *' }).Count
        $nAdm = @($lg | Where-Object { $_ -like '`[tête ?`] Dent locale du besoin admise entre c64 et c65 *' }).Count
        Chk 'E-journal' ($nCond -eq 1 -and $nOff -eq 2 -and $nDent -eq $nConf -and $nConf -eq $nAdm -and $nDent -ge 1) "tirage 0 : fin du conditionnement $nCond, decalages de passe $nOff (un par tete), dent c64/c65 annoncee $nDent, confirmee $nConf, admise au bilan $nAdm"
    }
    $cs = Get-CurveStats $rs $true 2.5
    Chk 'E1' ($cs.Pct -ge 95.0) "|courbe - besoin| <= 2,5 ns sur $(F $cs.Pct '0.0') % des cylindres ($($cs.Ok) / $($cs.N), c64-c66 exclus sans dent trouvee ; >= 95 %)"
    $vs = Get-V1Stats $rs
    Chk 'E2' ($vs.Pct -ge 88.0) "residus de la verification 1 : |r - mediane| dans la tolerance sur $(F $vs.Pct '0.0') % des cylindres ($($vs.Ok) / $($vs.N) ; >= 88 %, revue M1 : reference 12.8.2 83,8 a 84,5 %)"
    $pairs = 0; $found = 0; $other = 0; $stepBad = 0
    foreach ($r in $ok) {
        $i = 0
        foreach ($un in @($r.Units)) {
            $pairs++
            if (Test-DentOk $un) { $found++; if (@($un.Steps | Where-Object { [int]$_.C1 -le 64 -and [int]$_.C2 -ge 65 }).Count -gt 0) { $stepBad++ } }
            $d0 = @(@($r.Cap.Dents0)[$i]) | Where-Object { $null -ne $_ -and [int]$_.C1 -ne 64 }
            if (@($d0).Count -gt 0) { $other++ }
            $i++
        }
    }
    Chk 'E3' ($pairs -gt 0 -and 100.0 * $found / $pairs -ge 85.0) "dent c64/c65 trouvee et confirmee dans $found couples sur $pairs ($(F (100.0 * $found / [math]::Max(1, $pairs)) '0') % ; >= 85 %, 100 couples au moins, revue m1 ; [E] 92,5 a 94 %)"
    Chk 'E4' ($other -le 2) "autre dent appliquee par la courbe (avant la verification 1) dans $other couple(s) (<= 2)"
    Chk 'E5' ($stepBad -eq 0) "dent admise : aucune « marche du besoin » c64/c65 dans Warn.Steps ($stepBad couple(s) en defaut)"
    # E7 (revue M1) : courbe envoyee a la verification 1 sur c0-c19, ou porte le transitoire de la premiere ecriture, sans
    # biais d ensemble (revue, 20 tirages : 12.9 -0,10 a +0,20 ns ; sans conditionnement +0,80 a +1,10 ; reference 12.8.2
    # +2,60 a +2,85 ; niveaux 0/100/200 avec carre latin +0,50)
    $rv0 = @()
    foreach ($r in $ok) { $i = 0; foreach ($un in @($r.Units)) { $f0 = @(@($r.Cap.Fit0)[$i]); for ($c = 0; $c -le 19; $c++) { $rv0 += [double]$f0[$c] - (Get-NeedA $c ([int]$un.Head) $true) }; $i++ } }
    $md7 = Get-Med $rv0
    Chk 'E7' ($rv0.Count -gt 0 -and [math]::Abs($md7) -le 0.4) "mediane de (courbe envoyee a la verification 1 - besoin) sur c0-c19 : $(F $md7 '+0.00;-0.00') ns ($($rv0.Count) valeurs ; |.| <= 0,4 ns)"
    "    E6 (compte, sans seuil) : cylindres dont la valeur ecrite a la verification 1 egale un niveau de mesure (point moyenne par Add-CalibPoint, § 3.9) : $($vs.Avg) sur $($vs.N)"
}

# ---------------------------------------------------------------- E1r : 30 % du transitoire restent
if ($all.ContainsKey('E1r')) {
    "--- E1r. 30 % du transitoire restent sur la passe 1 malgre le conditionnement"
    $rs = $all['E1r']; $ok = Get-OkRuns $rs
    $cs = Get-CurveStats $rs $true 2.5
    $nl = 0; foreach ($r in $ok) { $nl += @($r.Log | Where-Object { $_ -like '*la première passe de mesure lit un décalage plus fort de * ns que les suivantes*' }).Count }
    Chk 'E1r' ($ok.Count -eq @($rs).Count -and $cs.Pct -ge 94.0) "|courbe - besoin| <= 2,5 ns sur $(F $cs.Pct '0.0') % des cylindres (>= 94 %, revue M1 : reference 12.8.2 90,0 a 91,1 %)$(Get-ErrTxt $rs)"
    "    E1r (compte, sans seuil) : lignes « la première passe de mesure lit un décalage plus fort » : $nl sur $(2 * $ok.Count) tetes"
}

# ---------------------------------------------------------------- N : besoin sans dent
if ($all.ContainsKey('N')) {
    "--- N. Besoin sans dent"
    $rs = $all['N']; $ok = Get-OkRuns $rs
    $nd = 0; $wh = @()
    foreach ($r in $ok) { foreach ($dl in @($r.Cap.Dents0)) { foreach ($d in @($dl | Where-Object { $null -ne $_ })) { $nd++; $wh += "c$($d.C1)/c$($d.C2)" } } }
    $fin = 0; foreach ($r in $ok) { foreach ($un in @($r.Units)) { $fin += @($un.Dents).Count } }
    Chk 'N' ($ok.Count -eq @($rs).Count -and $nd -le 1) "dents appliquees par la courbe : $nd sur $(2 * $ok.Count) couples (<= 1)$(if ($wh.Count) { ' : ' + ($wh -join ', ') }) ; dents restees dans la courbe finale : $fin$(Get-ErrTxt $rs)"
}

# ---------------------------------------------------------------- R : dent fausse injectee avant la verification 1
if ($all.ContainsKey('R')) {
    "--- R. Dent fausse c30/c31 injectee dans la courbe avant la verification 1 (besoin sans dent)"
    $rs = $all['R']; $ok = Get-OkRuns $rs
    $inj = 0; $rem = 0; $merged = 0; $line = 0; $flat = 0; $remD = 0
    foreach ($r in $ok) {
        $i = 0
        $lg = @($r.Log)
        $byRemoved = $true
        foreach ($un in @($r.Units)) {
            $d0 = @(@($r.Cap.Dents0)[$i] | Where-Object { $null -ne $_ -and [int]$_.C1 -eq 30 })
            if ($d0.Count -gt 0) { $inj++ }
            $v1 = @($r.Cap.V1)[$i]
            $still = @($v1.Dents | Where-Object { [int]$_.C1 -eq 30 })
            if ($still.Count -eq 0) {
                $rem++
                if ($v1.Segs -notmatch '\[31-31 -\]') { $merged++ }
                if (@($lg | Where-Object { $_ -like "$([WildcardPattern]::Escape($un.Prefix))Dent entre c30 et c31 non confirmée par la vérification 1 : baisse de * ns entre leurs zéros mesurés, moins de * ns ; elle est retirée et la courbe est réajustée sans elle." }).Count -eq 1) { $line++ }
                if ([int]$un.Values[31] -ge [int]$un.Values[30]) { $flat++ }
            } else { $byRemoved = $false }
            $i++
        }
        if ($byRemoved) { $remD++ }
    }
    Chk 'R0' ($ok.Count -eq @($rs).Count -and $inj -eq 2 * $ok.Count) "dent injectee et appliquee par Fit-PrecompCurve dans $inj couples sur $(2 * $ok.Count)$(Get-ErrTxt $rs)"
    Chk 'R1' ($ok.Count -gt 0 -and 100.0 * $remD / $ok.Count -ge 90.0) "retiree a la verification 1 dans $remD tirages sur $($ok.Count) (les deux tetes ; >= 90 %) ; $rem couples sur $(2 * $ok.Count)"
    Chk 'R2' ($rem -gt 0 -and $merged -eq $rem -and $line -eq $rem -and $flat -eq $rem) "quand elle l est ($rem) : segments fusionnes $merged, ligne « non confirmée ... réajustée sans elle » $line, courbe finale sans baisse en c30/c31 $flat"
}

# ---------------------------------------------------------------- C : zone contradictoire sur la dent
if ($all.ContainsKey('C')) {
    "--- C. Zone contradictoire sur la dent (c64-c66 vus 8 ns plus bas par la verification 1, 8 ns plus haut ensuite)"
    $rs = $all['C']; $ok = Get-OkRuns $rs
    $pre = 0; $keep = 0; $seg = 0; $lines = 0; $tot = 0
    foreach ($r in $ok) {
        foreach ($un in @($r.Units)) {
            $tot++
            $z = @(@($un.Contra) | Where-Object { $_ -ge 64 -and $_ -le 66 })
            if ($z.Count -eq 0) { continue }
            $pre++
            if (@($un.Dents | Where-Object { [int]$_.C1 -eq 64 -and [int]$_.C2 -eq 65 }).Count -gt 0) { $keep++ }
            if ($un.Segs -match '\[65-65 -\]') { $seg++ }
            if (@($r.Log | Where-Object { $_ -like "$([WildcardPattern]::Escape($un.Prefix))Dent locale du besoin*entre c64 et c65*" }).Count -ge 1) { $lines++ }
        }
        "    tirage $($r.Job.Draw) : zone $(@($r.Units | ForEach-Object { "t$($_.Head) $(Format-Set $_.Contra)" }) -join ' ; ') ; dents $(@($r.Units | ForEach-Object { "t$($_.Head) $(@($_.Dents | ForEach-Object { "c$($_.C1)/c$($_.C2)" }) -join ',')" }) -join ' ; ')"
    }
    Chk 'C0' ($ok.Count -eq @($rs).Count -and $pre -gt 0) "aucune erreur ($($ok.Count) calibrations) ; precondition (zone c64-c66 classee Contra) remplie dans $pre couples sur $tot$(Get-ErrTxt $rs)"
    Chk 'C1' ($pre -gt 0 -and $keep -eq $pre -and $seg -eq $pre -and $lines -eq $pre) "zone sur la dent ($pre) : Fit.Dents garde c64/c65 $keep, segments conserves $seg, ligne du bilan de la dent $lines (la ligne de la zone est ecrite par Complete-PrecompCalib, remplace ici : Warn.Contra contient la zone)"
}

# ---------------------------------------------------------------- U : unite convergee sans dent (revue B1)
if ($all.ContainsKey('U')) {
    "--- U. Unite convergee sans dent (sans bruit), double et haute densite"
    $rs = $all['U']; $ok = Get-OkRuns $rs
    $nU = 0; $bad = @()
    foreach ($r in $ok) {
        foreach ($un in @($r.Units)) {
            if (-not $un.Conv -or @($un.Dents).Count -gt 0) { continue }
            $nU++
            $dl = @($r.Log | Where-Object { $_ -like "$([WildcardPattern]::Escape($un.Prefix))Dent*" })
            if (-not $un.WarnHasDents -or $un.WarnDentsNull -or -not $un.WarnDentsArr -or $un.WarnDents.Count -ne 0) { $bad += "$($r.Job.Fam) t$($un.Head) : Warn.Dents" }
            if ($dl.Count -gt 0) { $bad += "$($r.Job.Fam) t$($un.Head) : ligne « Dent »" }
            if (-not $un.Cfg -or $un.Cfg.Contains('dentLo')) { $bad += "$($r.Job.Fam) t$($un.Head) : dentLo enregistre" }
            if (-not $un.Back -or @($un.Back.DentLo).Count -ne 0) { $bad += "$($r.Job.Fam) t$($un.Head) : relecture" }
        }
    }
    Chk 'U' ($ok.Count -eq @($rs).Count -and $nU -ge 3 -and $bad.Count -eq 0) "$nU unites convergees sans dent (double et haute densite) : Warn.Dents tableau vide, aucune ligne « Dent », pas de champ dentLo dans la configuration ; defauts : $(if ($bad.Count) { $bad -join ' ; ' } else { 'aucun' })$(Get-ErrTxt $rs)"
    if ($all.ContainsKey('E')) {
        $eo = Get-OkRuns $all['E']; $nd = 0; $rt = 0
        foreach ($r in $eo) { foreach ($un in @($r.Units)) { if ((Test-DentOk $un) -and $un.Cfg) { $nd++; if ((@($un.Cfg.dentLo) -join ',') -eq '64' -and (@($un.Cfg.dentHi) -join ',') -eq '65' -and (@($un.Back.DentLo) -join ',') -eq '64' -and @($un.Back.DentNs).Count -eq 1) { $rt++ } } } }
        Chk 'U-cfg' ($nd -gt 0 -and $rt -eq $nd) "configuration d une courbe avec la dent admise (scenario E) : dentLo 64, dentHi 65, relue par ConvertFrom-CurveConfig dans $rt cas sur $nd"
    }
}

# ---------------------------------------------------------------- HD : identique a la reference
if ($all.ContainsKey('HD')) {
    "--- HD. Famille 'hd', motif de 200 000 cellules : meme graine, wt-129 contre la reference d avant les corrections"
    $rn = $all['HD']; $rb = $all['HDb']
    $same = 0; $logSame = 0; $n = @($rn).Count; $diff = @()
    for ($i = 0; $i -lt $n; $i++) {
        $a = $rn[$i]; $b = $rb[$i]
        if ($a.Error -or $b.Error) { $diff += "tirage $i : erreur $($a.Error)$($b.Error)"; continue }
        $va = (@($a.Units) | ForEach-Object { "$(@($_.Values) -join ',')|$(@($_.Breaks) -join ',')" }) -join ' ; '
        $vb = (@($b.Units) | ForEach-Object { "$(@($_.Values) -join ',')|$(@($_.Breaks) -join ',')" }) -join ' ; '
        if ($va -ceq $vb) { $same++ } else { $diff += "tirage $i : courbes differentes" }
        $la = @($a.Log | Where-Object { $_ -notlike '*à leur valeur inchangée*' -and $_ -notlike '*dérive du lecteur non retirée*' })
        $lb = @($b.Log | Where-Object { $_ -notlike '*à leur valeur inchangée*' -and $_ -notlike '*dérive du lecteur non retirée*' })
        if (($la -join "`n") -ceq ($lb -join "`n")) { $logSame++ }
        else {
            $j = 0; while ($j -lt [math]::Min($la.Count, $lb.Count) -and $la[$j] -ceq $lb[$j]) { $j++ }
            $diff += "tirage $i : journal different a la ligne $j : « $(if ($j -lt $la.Count) { $la[$j] }) » / « $(if ($j -lt $lb.Count) { $lb[$j] }) »"
        }
        $flags = $a.State0
        if ($flags.Cond -or $flags.Latin -or $flags.Dent) { $diff += "tirage $i : indicateurs vrais en haute densite" }
    }
    Chk 'HD' ($n -gt 0 -and $same -eq $n -and $logSame -eq $n -and $diff.Count -eq 0) "$n tirages : Values et Breaks identiques $same, journal identique hors lignes du nouvel essai (§ 6, § 7) $logSame ; $(if ($diff.Count) { $diff -join ' | ' } else { 'aucun ecart' })"
}

# ---------------------------------------------------------------- RK0 : dent fausse sur une courbe sans changement de sens (revue m2)
if ($all.ContainsKey('RK0')) {
    "--- RK0. Besoin lisse sans changement de sens (7 + 0,45 c ; tete 1 : + 3 ns), dent fausse c30/c31 injectee avant la verification 1 (revue m2)"
    $rs = $all['RK0']; $ok = Get-OkRuns $rs
    $inj = 0; $rem = 0; $flat = 0; $bad = 0; $smooth = 0
    foreach ($r in $ok) {
        $i = 0
        foreach ($un in @($r.Units)) {
            if (@(@($r.Cap.Dents0)[$i] | Where-Object { $null -ne $_ -and [int]$_.C1 -eq 30 }).Count -gt 0) { $inj++ }
            $v1 = @($r.Cap.V1)[$i]
            if (@($v1.Dents | Where-Object { [int]$_.C1 -eq 30 }).Count -eq 0) { $rem++; if ([int]$un.Values[31] -ge [int]$un.Values[30]) { $flat++ } }
            $i++
        }
        $bad += @($r.Log | Where-Object { $_ -like '`[tête ?`] 0 cylindre(s) corrigé(s), résidu hors tolérance*' }).Count
        $smooth += @($r.Log | Where-Object { $_ -like '`[tête ?`] Courbe lissée sans la dent retirée, nouveau profil : *' }).Count
    }
    Chk 'RK0' ($ok.Count -eq @($rs).Count -and $inj -eq 2 * $ok.Count -and $rem -gt 0 -and $flat -eq $rem -and $bad -eq 0 -and $smooth -ge 1) "$($ok.Count) calibrations : dent injectee et appliquee dans $inj couples, retiree a la verification 1 dans $rem, courbe finale sans baisse en c30/c31 $flat ; lignes « Courbe lissée sans la dent retirée » $smooth (>= 1) ; lignes « 0 cylindre(s) corrigé(s), résidu hors tolérance » $bad (0)$(Get-ErrTxt $rs)"
}

Get-Cal2Bilan 'logic-129-cal2-e2e'
"duree : $(F $sw.Elapsed.TotalSeconds '0') s"
exit $(if ($script:Fail) { 1 } else { 0 })
