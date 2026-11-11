param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 (lot L5) : decalage commun de l ecriture de verification sur un lecteur a fort besoin. Aucun changement du calcul
# (CalibCalc 12.10) : le test fige ce que la 12.10 a mis en place. Avec les niveaux de mesure de la famille (0/60/200 ns
# en long track), le decalage s estime sur les cylindres ecrits a 200 ns au plus ; avec ceux du standard (0/30/100 ns),
# un lecteur dont tout le besoin depasse 100 ns ne laissait aucun cylindre exploitable (« non evalue »).
#  S1 a S3  statique (arbre syntaxique de 270) : Invoke-CalibAnalysis transmet $cal.MaxCoarse a Get-VerifyOffset et a
#           Get-VerifySlope ; $cal.MaxCoarse y est recalcule une fois, d apres $cal.Values ;
#  E1 a E3  etat reel de Start-PrecompCalib (litteral extrait) par famille : niveaux, niveau maximal, drapeaux ;
#  P1 a P7  Get-VerifyOffset reelle sur une unite factice « fort besoin en long track » : decalage retire au niveau de la
#           famille, contre-epreuve au niveau du standard et sans niveau transmis, et trois limites connues, epinglees pour
#           qu un changement se voie : besoin encore plus fort (P4), test standard (P5), ecart entre les deux zones de la
#           piste (P6, P7) ;
#  F0 a F4  calibration long track factice menee de bout en bout par les fonctions reelles (file des commandes,
#           New-CalibPass, Invoke-CalibAnalysis, Complete-PrecompCalib) : deroule sans erreur et courbe egale au besoin
#           (F0), niveaux et encadrement (F1), decalage retire par tete (F2), contre-epreuve au facteur de famille 1 et sa
#           consequence (F3, F3b), profil final identique avec et sans decalage (F4).
# Donnees factices seulement : besoin 112 + 2,8 c (c0 a c43) puis 113 + 5,1 (c - 44) (c44 a c79), 7 ns de plus pour la
# tete 1 ; reponse lineaire de -1,25 ns de decalage par ns ecrit ; bruit antisymetrique par paire de cylindres (2i, 2i+1) :
# 1 ns aux verifications (la mediane des residus d une verification complete vaut le decalage commun), 0,2 ns aux passes
# de mesure et d encadrement (les zeros valent le besoin a moins de 0,2 ns : la courbe le retrouve a l entier pres, sans
# cylindre a la limite d une decision). Aucune valeur d un lecteur.
# Premiere execution (11/11/2026), avec 1 ns de bruit aux passes de mesure et 6 ns de plus pour la tete 1 : la courbe
# s ecartait du besoin de 1 ns au plus ; tete 0 : +4,0 ns retire sur 50 cylindres ; tete 1 : -0,6 ns mesure pour -1,1 ns,
# dans le bruit, non retire (47 cylindres). Les attendus de F2 supposent une courbe egale au besoin (F0) : d ou le bruit
# de 0,2 ns des passes de mesure, et 7 ns pour la tete 1 (aucun besoin a 201 ns, a la limite de l encadrement).
# Fonctions reelles extraites par l arbre syntaxique, ecrites dans un fichier de travail, chargees par dot-source ; type C#
# CurveFit : instruction Add-Type de 030 recopiee telle quelle, comme logic-calib-croisee. Bouchons de F : journal, gw
# (Start-Gw : la relecture fabrique les pistes), configuration, fenetres, Accueil. Aucun gw, aucune fenetre.
# Non couvert : un decalage retire sur materiel en long track a fort besoin (jamais observe) ; le test standard et les
# mesures complementaires de bout en bout ; la courbe commune (une unite pour les deux tetes) en long track.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
. (Join-Path $PSScriptRoot 'cal2-commun.ps1')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$simDir = Join-Path $here 'sim'
if (-not (Test-Path -LiteralPath $simDir)) { [void](New-Item -ItemType Directory -Path $simDir -Force) }
$mods = Get-Cal2Modules $Wt
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()

# ---------------------------------------------------------------- fonctions reelles
# Jeu « pur » (S, E, P) : fonctions du calcul seules ; jeu « flux » (F) : tout ce que la calibration complete appelle
function New-FbGenPur([string]$m, [string]$outFn, [string]$outConst) {
    $parts = New-Object System.Collections.Generic.List[string]; $found = @{}
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '230-fn-calib-courbe.ps1')) @('Get-Median', 'Set-CalibScale', 'Get-SpecValue', 'Format-CylList') $found '230'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '240-fn-calib-mesure.ps1')) @('Get-VerifyOffset', 'Get-VerifySlope', 'Get-CalLevels') $found '240'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '260-fn-calib-rapide.ps1')) @('Format-LevelNum') $found '260'
    Test-Cal2Missing @('Get-Median', 'Set-CalibScale', 'Get-SpecValue', 'Format-CylList', 'Get-VerifyOffset', 'Get-VerifySlope', 'Get-CalLevels', 'Format-LevelNum') $found
    $parts.Add((Get-Cal2CalStateFn $m))
    Write-Cal2Gen $outFn $parts
    Write-Cal2Gen $outConst (Get-Cal2Consts $m)
}
function New-FbGenFlux([string]$m, [string]$out) {
    $parts = New-Object System.Collections.Generic.List[string]; $found = @{}
    foreach ($f in '150-fn-pistes-densite.ps1', '220-fn-profil-precomp.ps1', '230-fn-calib-courbe.ps1', '240-fn-calib-mesure.ps1', '250-fn-calib-fenetres.ps1', '270-fn-calib-complete.ps1', '280-fn-calib-surface.ps1') { Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m $f)) @('*') $found $f }
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '260-fn-calib-rapide.ps1')) @('Format-LevelNum') $found '260'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '274-fn-contenu-calcul.ps1')) @('Solve-ContentLinear') $found '274'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '276-fn-contenu-mesure.ps1')) @('Format-CylRanges') $found '276'
    Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $m '110-fn-coeur-gw.ps1')) @('Get-GwDriveKey') $found '110'
    Test-Cal2Missing @('New-CalibPass', 'Invoke-CalibAnalysis', 'Complete-PrecompCalib', 'Start-CalibWarmup', 'Set-CalibScale', 'New-CalibUnit', 'Get-VerifyOffset', 'Get-CalLevels', 'Format-LevelNum') $found
    $parts.Add((Get-Cal2CalStateFn $m))
    foreach ($s in (Get-Cal2Consts $m)) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '565-etat-contenu.ps1') @('$script:EraseEstTrack'))) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '560-etat-calibration.ps1') @('$script:CurveKeys', '$script:DriveActivity', '$script:DriveCurves', '$script:PrecompCurves', '$script:LevelShifts'))) { $parts.Add($s) }
    foreach ($s in (Get-Cal2Assign (Join-Path $m '040-etat-formats.ps1') @('$script:PrecompStd', '$script:PrecompLong', '$script:PrecompStdDefault', '$script:PrecompLongDefault'))) { $parts.Add($s) }
    Write-Cal2Gen $out $parts
    return $found
}
$genP = Join-Path $here 'gen-decalage-pur.ps1'; $genC = Join-Path $here 'gen-decalage-const.ps1'; $genF = Join-Path $here 'gen-decalage-flux.ps1'; $genCf = Join-Path $here 'gen-decalage-cf.ps1'
New-FbGenPur $mods $genP $genC
$fnF = New-FbGenFlux $mods $genF
Write-Cal2Gen $genCf @((Get-Cal2CurveFit $mods))
. $genCf
. $genC
. $genP
function T([string]$s) { return $s }
"logic-calib-decalage-fort-besoin : modules $mods ; $($fnF.Count) fonctions pour le deroule ; CalibCalc $($script:CalibCalc) ; PowerShell $($PSVersionTable.PSVersion)"

# ---------------------------------------------------------------- S : statique
'--- S. Statique : niveau maximal de la famille transmis a l estimation du decalage et de la pente'
$tFn = [System.Management.Automation.Language.FunctionDefinitionAst]
$tCmd = [System.Management.Automation.Language.CommandAst]
$tAsg = [System.Management.Automation.Language.AssignmentStatementAst]
$ast270 = Get-Cal2Ast (Join-Path $mods '270-fn-calib-complete.ps1')
$fdA = @($ast270.FindAll({ param($x) $x -is $tFn -and $x.Name -eq 'Invoke-CalibAnalysis' }, $false))
if ($fdA.Count -ne 1) { throw "Invoke-CalibAnalysis : $($fdA.Count) definition(s)" }
$callsO = @($fdA[0].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Get-VerifyOffset' }, $true))
$a5 = ''; if ($callsO.Count -eq 1 -and $callsO[0].CommandElements.Count -ge 6) { $a5 = $callsO[0].CommandElements[5].Extent.Text }
Chk 'S1' ($callsO.Count -eq 1 -and $a5 -match '^\(\[double\]\$cal\.MaxCoarse\)$') "Invoke-CalibAnalysis : $($callsO.Count) appel de Get-VerifyOffset, 5e argument « $a5 » (attendu : ([double]`$cal.MaxCoarse))"
$callsS = @($fdA[0].Body.FindAll({ param($x) $x -is $tCmd -and $x.GetCommandName() -eq 'Get-VerifySlope' }, $true))
$b2 = ''; if ($callsS.Count -eq 1 -and $callsS[0].CommandElements.Count -ge 3) { $b2 = $callsS[0].CommandElements[2].Extent.Text }
Chk 'S2' ($callsS.Count -eq 1 -and $b2 -match '^\(\[double\]\$cal\.MaxCoarse\)$') "Invoke-CalibAnalysis : $($callsS.Count) appel de Get-VerifySlope, 2e argument « $b2 » (attendu : ([double]`$cal.MaxCoarse))"
$asg = @($fdA[0].Body.FindAll({ param($x) $x -is $tAsg -and $x.Left.Extent.Text -eq '$cal.MaxCoarse' }, $true))
$asgTxt = ''; if ($asg.Count) { $asgTxt = $asg[0].Right.Extent.Text }
# Hors d Invoke-CalibAnalysis, le niveau maximal n est pose que par le litteral de l etat (E1 a E3) : aucune autre
# fonction de 270 ne l affecte
$asgAll = @($ast270.FindAll({ param($x) $x -is $tAsg -and $x.Left.Extent.Text -match 'MaxCoarse' }, $true))
Chk 'S3' ($asg.Count -eq 1 -and $asgTxt -eq '[int](@($cal.Values) | Measure-Object -Maximum).Maximum' -and $asgAll.Count -eq 1) "fin des passes de mesure : `$cal.MaxCoarse recalcule $($asg.Count) fois, d apres « $asgTxt » (attendu : le maximum de `$cal.Values) ; affectations de MaxCoarse dans tout 270 : $($asgAll.Count) (1 attendue)"

# ---------------------------------------------------------------- E : etat reel par famille
'--- E. Etat de Start-PrecompCalib (litteral reel) par famille'
$cmbDrive = [pscustomobject]@{ Text = '0' }
$script:TempDir = $simDir
function Get-StateOf([string]$family) {
    Set-CalibScale $(if ($family -eq 'hd') { 'hd' } else { '' })
    $cyls = [int[]]@(0..79)
    New-Cal2CalState $true $cyls 79 $family $true 'x.hfe' @{ Path = 'x'; Bits = 105808 } '0-79' @() @{ Swap = $false; Auto = $false } $false 5 0.1 $false 8 $true $false $null
    return $script:Cal
}
$st = Get-StateOf 'long'
Chk 'E1' ((@($st.Values) -join '/') -eq '0/60/200' -and [int]$st.MaxCoarse -eq 200 -and [bool]$st.VOff -and [bool]$st.Slope) "long track : Values $(@($st.Values) -join '/'), MaxCoarse $($st.MaxCoarse), VOff $($st.VOff), Slope $($st.Slope) (attendu 0/60/200, 200, True, True)"
$st = Get-StateOf 'standard'
Chk 'E2' ((@($st.Values) -join '/') -eq '0/30/100' -and [int]$st.MaxCoarse -eq 100 -and [bool]$st.VOff) "standard : Values $(@($st.Values) -join '/'), MaxCoarse $($st.MaxCoarse), VOff $($st.VOff) (attendu 0/30/100, 100, True)"
$st = Get-StateOf 'hd'
Chk 'E3' ((@($st.Values) -join '/') -eq '0/50/100' -and [int]$st.MaxCoarse -eq 100 -and -not [bool]$st.VOff) "haute densite : Values $(@($st.Values) -join '/'), MaxCoarse $($st.MaxCoarse), VOff $($st.VOff) (attendu 0/50/100, 100, False)"
Set-CalibScale ''
$script:Cal = $null

# ---------------------------------------------------------------- besoin et bruit factices
function Get-FbNeed([int]$c) { if ($c -le 43) { return [int](112 + [math]::Round(2.8 * $c)) }; return [int](113 + [math]::Round(5.1 * ($c - 44))) }
function Get-FbNeedH([int]$c, [int]$h) { return (Get-FbNeed $c) + 7 * $h }
function Get-FbNoise([int]$c, [int]$h = 0, [int]$k = 0, [double]$amp = 1.0) {
    # Antisymetrique par paire de cylindres (2i, 2i+1) ; h : tete ; k : passe (0 : unite factice de P) ; amp : amplitude (ns)
    $s = [math]::Sin(12.9898 * [math]::Floor($c / 2) + 4.1 + 78.233 * $h + 37.1 * $k)
    if ($c % 2 -eq 1) { $s = -$s }
    return [math]::Round($amp * $s, 2)
}

# ---------------------------------------------------------------- P : fonction pure, unite factice
'--- P. Get-VerifyOffset sur une unite factice a fort besoin en long track'
function New-FbUnit([double]$off, [double]$k = 1.0, [int[]]$only = $null, [double]$zone = 0.0) {
    # Unite verifiee : profil = besoin x k, zeros tous interpoles, residu = decalage commun + ecart de zone (c0-c43 : +zone,
    # c44 et plus : -zone) + bruit ; $only : cylindres verifies (test standard)
    $vals = New-Object 'int[]' 80
    $u = @{ Fit = @{ Values = $vals }; Verify = @{}; VerifyP = @{}; Kind = @{}; Outliers = @() }
    foreach ($c in 0..79) {
        $p = [int][math]::Round((Get-FbNeed $c) * $k); $vals[$c] = $p
        if ($null -ne $only -and -not (@($only) -contains $c)) { continue }
        $z = if ($c -le 43) { $zone } else { -$zone }
        $u.Verify[[int]$c] = @{ Shift = ($off + $z + (Get-FbNoise $c)); SE = 0.6; Score = [double]::NaN }
        $u.VerifyP[[int]$c] = $p; $u.Kind[[int]$c] = 'interp'
    }
    return $u
}
function Format-Vo($vo) {
    $e = '-'; if (-not [double]::IsNaN([double]$vo.E)) { $e = ([double]$vo.E).ToString('0.00', $inv) }
    return ('N {0}, M {1}, E {2}, Ok {3}, Why [{4}], Dz {5}' -f $vo.N, ([double]$vo.M).ToString('+0.00;-0.00;0.00', $inv), $e, $vo.Ok, $vo.Why, ([double]$vo.Dz).ToString('0.00', $inv))
}
function Test-Near([double]$x, [double]$ref, [double]$tol = 0.005) { return ([math]::Abs($x - $ref) -le $tol) }
$mc = [int]$script:CalVOffMinCyl; $sk = [double]$script:CalVOffSigK; $mx = [double]$script:CalVOffMaxNs
$lvLong = [double](@(Get-CalLevels 'long') | Measure-Object -Maximum).Maximum
$lvStd = [double](@(Get-CalLevels 'standard') | Measure-Object -Maximum).Maximum
"    constantes : CalVOffMinCyl $mc, CalVOffSigK $sk, CalVOffMaxNs $mx, CalVOffHomNs $($script:CalVOffHomNs) ; niveau maximal : long track $lvLong ns, standard $lvStd ns ; besoin factice : $(Get-FbNeed 0) a $(Get-FbNeed 43) ns (c0-c43), $(Get-FbNeed 44) a $(Get-FbNeed 79) ns (c44-c79)"
$u = New-FbUnit 3.85
$vo = Get-VerifyOffset $u $mc $sk $mx $lvLong
Chk 'P1' ($vo.Ok -and $vo.N -eq 50 -and (Test-Near $vo.M 3.85) -and (Test-Near $vo.E 0.20 0.006) -and (Test-Near $vo.Dz 0.24 0.006)) "niveau de la famille long track ($lvLong ns), decalage +3,85 : $(Format-Vo $vo) (attendu N 50, M +3,85, E 0,20, retire)"
$vo = Get-VerifyOffset $u $mc $sk $mx $lvStd
Chk 'P2' (-not $vo.Ok -and $vo.N -eq 0 -and $vo.Why -eq 'cylindres') "contre-epreuve, niveau du standard ($lvStd ns) : $(Format-Vo $vo) (attendu N 0, 'cylindres' : le defaut d avant les niveaux par famille)"
$vo = Get-VerifyOffset $u $mc $sk $mx
Chk 'P3' (-not $vo.Ok -and $vo.N -eq 0 -and $vo.Why -eq 'cylindres') "sans niveau transmis (CalCoarse du bareme, sans la famille) : $(Format-Vo $vo) (attendu N 0 : l appelant doit transmettre le niveau de la famille, S1)"
$v14 = Get-VerifyOffset (New-FbUnit 3.85 1.4) $mc $sk $mx $lvLong
$v16 = Get-VerifyOffset (New-FbUnit 3.85 1.6) $mc $sk $mx $lvLong
$v18 = Get-VerifyOffset (New-FbUnit 3.85 1.8) $mc $sk $mx $lvLong
Chk 'P4' ($v14.Ok -and $v14.N -eq 18 -and (Test-Near $v14.M 3.85) -and -not $v16.Ok -and $v16.N -eq 8 -and $v16.Why -eq 'cylindres' -and -not $v18.Ok -and $v18.N -eq 0 -and $v18.Why -eq 'cylindres') "besoin plus fort (limite connue) : x 1,4 : $(Format-Vo $v14) (attendu N 18, retire) ; x 1,6 : $(Format-Vo $v16) (attendu N 8, 'cylindres') ; x 1,8 : $(Format-Vo $v18) (attendu N 0, 'cylindres')"
$std = [int[]]@(0, 10, 20, 30, 40, 50, 60, 70, 79)
$vo = Get-VerifyOffset (New-FbUnit 3.85 1.0 $std) $mc $sk $mx $lvLong
Chk 'P5' (-not $vo.Ok -and $vo.N -eq 6 -and $vo.Why -eq 'cylindres') "test standard, 9 cylindres (limite connue) : $(Format-Vo $vo) (attendu N 6, 'cylindres')"
$vo = Get-VerifyOffset (New-FbUnit 3.0 1.0 $null 1.75) $mc $sk $mx $lvLong
Chk 'P6' (-not $vo.Ok -and $vo.N -eq 50 -and $vo.Why -eq 'regional' -and (Test-Near $vo.Dz 2.95 0.006)) "ecart de zone +1,75 / -1,75 ns et decalage +3 (limite connue) : $(Format-Vo $vo) (attendu N 50, 'regional', Dz 2,95)"
$vo = Get-VerifyOffset (New-FbUnit 3.0 1.0 $null 1.0) $mc $sk $mx $lvLong
Chk 'P7' ($vo.Ok -and $vo.N -eq 50 -and (Test-Near $vo.Dz 1.45 0.006)) "ecart de zone +1 / -1 ns et decalage +3 : $(Format-Vo $vo) (attendu retire, Dz 1,45)"

# ---------------------------------------------------------------- F : calibration long track factice de bout en bout
function Get-UnitHeads($u) { if ($null -eq $u.Head) { return @(0, 1) }; return @([int]$u.Head) }
function New-FbTrack([double]$s) {
    # Piste relue : 3 tours identiques ; erreur-type d un tour 1,04 ns, soit 0,6 ns pour la piste (Get-CalibTrackMeasure)
    $l = @()
    foreach ($rev in 1..3) { $l += [pscustomobject]@{ Shift = $s; ShiftSE = 1.04; Jitter = 40.0; R3 = 1.5; R4 = 2.0; OutOfClass = 0; NFlux = 50000 } }
    return ,$l
}
function Get-FbShift([double]$w, [int]$c, [int]$h, [double]$off, [int]$k, [double]$amp) { return [math]::Round(-1.25 * ($w - (Get-FbNeedH $c $h)) + $off + (Get-FbNoise $c $h $k $amp), 2) }
function New-FbPass {
    # Pistes relues a l etape en cours. Passes de mesure : bruit de 0,2 ns propre a la passe (k = 1 a 3) ; encadrement :
    # 0,2 ns, k = 4 ; verifications : 1 ns, k = 9 (meme bruit a chaque verification : un cylindre relu a la meme valeur
    # repete sa mesure). Decalage commun de l ecriture : a la verification complete seulement (verification 1), par tete
    # (FbO1)
    $cal = $script:Cal; $tr = @{}
    if ($cal.Stage -eq 'coarse') {
        foreach ($c in @($cal.Cyls)) { foreach ($h in 0, 1) { $tr[2 * [int]$c + $h] = New-FbTrack (Get-FbShift ([double]$cal.PassW[[int]$c]) ([int]$c) $h 0.0 ([int]$cal.Index + 1) 0.2) } }
    }
    elseif ($cal.Stage -eq 'bracket') {
        foreach ($u in @($cal.Units)) { foreach ($c in @($u.Bracket.Keys)) { foreach ($h in (Get-UnitHeads $u)) { $tr[2 * [int]$c + $h] = New-FbTrack (Get-FbShift ([double]$u.Bracket[$c]) ([int]$c) $h 0.0 4 0.2) } } }
    }
    elseif ($cal.Stage -eq 'verify') {
        foreach ($u in @($cal.Units)) {
            if ([int]$cal.Retests -gt 0 -and -not $u.InRetest) { continue }
            $full = ($null -eq $u.VerifyList)
            $rc = if ($full) { @($cal.Cyls) } else { @($u.VerifyList) }
            foreach ($c in $rc) {
                $w = [double](Get-SpecValue $u.Profile ([int]$c))
                foreach ($h in (Get-UnitHeads $u)) { $off = if ($full) { [double]$script:FbO1[$h] } else { 0.0 }; $tr[2 * [int]$c + $h] = New-FbTrack (Get-FbShift $w ([int]$c) $h $off 9 1.0) }
            }
        }
    }
    else { throw "etape non simulee : $($cal.Stage)" }
    $script:SimTracks = $tr
}
function Invoke-FbCalib($o) {
    # $o : @{ O1 = @{ 0 = ns ; 1 = ns } (decalage de l ecriture de la verification 1, par tete) ; KLong (facteur des niveaux
    # du long track ; $null : celui de 560) }. Calibration complete long track, test fin, une courbe par tete, menee par la
    # file reelle des commandes jusqu a Complete-PrecompCalib reel
    . $genF
    function T([string]$s) { return $s }
    function Format-UiNum([double]$v, [string]$fmt = '0.#') { return $v.ToString($fmt, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
    function Append-Log([string]$text) { $script:CLog.Add($text) }
    function Get-CommonArgs { return @('--drive=A') }
    function Get-CalibDriveArgs { return @() }
    function Get-DriveReadArgs { return @() }
    function Get-EraseDriveArgs { return @() }
    function Get-EraseMode([bool]$hd) { if ($hd) { return 'pre' }; return 'hfreq' }
    function Update-CalibProgress { }
    function Update-HomeCalibCard { }
    function Set-HomeProgDone($a, $b, $c) { }
    function Get-WProfileText { return '' }
    function Get-WriteTabFamily { return 'long' }
    function Get-LevelBrandsOfRef($k, $d, $dr) { return @() }
    function Backup-ConfigBeforeRef([string[]]$keys, [string]$why = 'replace') { return $null }
    function Save-Config { $script:NSave++; return $true }
    function Update-PrecompForImage([string]$path) { }
    function Update-CurveButton([string]$path) { }
    function Update-WLevelUi { }
    function Show-CurvesWindow($cvs, $Owner = $null) { $script:NShown++ }
    function Show-PrecompCurve([string]$family, [bool]$preferHeads, $Owner = $null) { $script:NShown++ }
    function Show-CalibReview($cal, [string[]]$issues, [bool]$toWrite, [bool]$offerFull = $false, [bool]$noFields = $false, [bool]$offerRedo = $false, $compare = $null, [bool]$warnKeep = $false, $lvl2 = $null) { $script:CReview.Add(@($issues) -join ' | '); return 'keep' }
    function Restore-CalibState($prev) { }
    function Stop-PrecompCalib([switch]$GwError) { $script:NStop++; $script:Cal = $null }
    function Read-ScpFile([string]$path, [int]$cellsPerRev = 0, [switch]$Finger, [switch]$NoIndexZone) { return $script:SimTracks }
    function Start-Gw([string[]]$gwArgs, [switch]$Soft) {
        $script:CCmds.Add((@($gwArgs) -join ' '))
        if ([string]@($gwArgs)[0] -eq 'read') { [System.IO.File]::WriteAllText([string]$script:Cal.Scp, 'x'); New-FbPass }
    }
    function Invoke-NextChainStep {
        if ($script:Chain.Count -eq 0) { return }
        & ($script:Chain.Dequeue())
    }
    $script:FbO1 = $o.O1
    if ($null -ne $o.KLong) { $script:CalLevelKLong = [double]$o.KLong }
    $script:SimTracks = @{}
    $script:TempDir = $simDir; $script:Chain = New-Object System.Collections.Queue; $script:Restore = $null; $script:CalRedo = $null; $script:AfterCalib = ''
    $script:CurveForm = $null; $script:OldCalib = $null; $script:CurveFitOk = $true; $script:Lang = 'fr'; $script:CalWarmupMinutes = 0.0; $script:TargetDrives = $null; $script:GwProc = $null
    $script:CCmds = New-Object System.Collections.Generic.List[string]; $script:CLog = New-Object System.Collections.Generic.List[string]
    $script:CReview = New-Object System.Collections.Generic.List[string]
    $script:NSave = 0; $script:NShown = 0; $script:NStop = 0
    $cmbDrive = [pscustomobject]@{ Text = 'A' }; $txtDev = [pscustomobject]@{ Text = '' }
    $pbWCal = [pscustomobject]@{ Value = 0; Visible = $false }; $lblWCal = [pscustomobject]@{ Text = ''; Visible = $false }; $lblWProfileInfo = [pscustomobject]@{ Text = '' }
    $cmbWProfile = [pscustomobject]@{ SelectedIndex = 0 }; $chkWPrecomp = [pscustomobject]@{ Checked = $true }; $txtWPrecomp = [pscustomobject]@{ Text = '' }; $txtWPrecomp1 = [pscustomobject]@{ Text = '' }
    $txtWFile = [pscustomobject]@{ Text = 'C:\x\image.ipf' }; $cmbWFmt = [pscustomobject]@{ Text = '' }; $chkWSlow = [pscustomobject]@{ Checked = $true }
    $script:DriveCurves = @{}
    $script:PrecompCurves = @{ std = $null; long = $null; std_h0 = $null; std_h1 = $null; long_h0 = $null; long_h1 = $null; hd = $null; hd_h0 = $null; hd_h1 = $null }
    $script:LevelShifts = @{}
    $script:PrecompStd = $script:PrecompStdDefault; $script:PrecompLong = $script:PrecompLongDefault
    $fam = 'long'; $maxCyl = 79
    Set-CalibScale $fam
    $cyls = @(0..$maxCyl)
    $units = @((New-CalibUnit 0), (New-CalibUnit 1))
    foreach ($u in $units) { foreach ($c in $cyls) { $u.Results[[int]$c] = @{} } }
    $cond = [bool]$script:CalScaleDd.CalCondPass
    $nPassEst = $script:CalCoarse.Count + $script:CalMaxVerify
    $nPassMax = $nPassEst + 1 + $(if ($cond) { 1 } else { 0 }) + $(if ($cond) { [int]$script:CalMaxRetest } else { 0 })
    $pat = @{ Path = 'C:\x\precomp-pattern.hfe'; Bits = 105808; CellNs = 1890.2; Source = 'image' }
    $cylList = Format-CylList $cyls
    New-Cal2CalState $true $cyls $maxCyl $fam $true 'C:\x\image.ipf' $pat $cylList $units @{ Ok = $true; Swap = $false; Auto = $false } $false $nPassEst (Get-CalibEraseEst $false) $true $nPassMax $cond $false $null
    $script:Cal.SurfDone = $true
    $cal0 = $script:Cal
    $st0 = @{ Values = (@($cal0.Values) -join '/'); MaxCoarse = [int]$cal0.MaxCoarse; VOff = [bool]$cal0.VOff; Latin = [bool]$cal0.Latin; Family = [string]$cal0.Family }
    $err = ''; $g = 0
    try {
        Start-CalibWarmup
        while ($script:Chain.Count -gt 0 -and $script:Cal -and $g -lt 900) { $g++; Invoke-NextChainStep }
    }
    catch { $err = "$($_.Exception.Message) (ligne $($_.InvocationInfo.ScriptLineNumber) : $($_.InvocationInfo.Line.Trim()))" }
    $r = @{ Err = $err; Guard = $g; Done = (-not $script:Cal); State0 = $st0; Cal = $cal0; Log = $script:CLog.ToArray(); Cmds = $script:CCmds.ToArray()
            Review = $script:CReview.ToArray(); NSave = $script:NSave; NShown = $script:NShown; NStop = $script:NStop; Units = @{}; Curves = @{} }
    foreach ($u in @($cal0.Units)) { $r.Units[[int]$u.Head] = $u }
    foreach ($k in @($script:PrecompCurves.Keys)) { $r.Curves[$k] = $script:PrecompCurves[$k] }
    $script:Cal = $null
    return $r
}
function Write-FbLog($r, [string]$name) {
    # Journal d un deroule, pour inspection (dossier de travail du test, UTF-8 sans BOM)
    $p = Join-Path $here "$name-journal.txt"
    [System.IO.File]::WriteAllLines($p, [string[]]@(@("etapes $($r.Guard) ; termine $($r.Done) ; erreur « $($r.Err) » ; $(@($r.Cmds).Count) commandes") + @($r.Log)), (New-Object System.Text.UTF8Encoding($false)))
}
$ord = [System.StringComparison]::Ordinal
function Get-LogStart($log, [string]$start) { return ,@(@($log) | Where-Object { $_.StartsWith($start, $ord) }) }
function Get-FbV1Profiles($log) {
    # Profils ecrits par la verification 1 (ligne de New-CalibPass, ecriture lente) : tete -> profil
    foreach ($l in @($log)) {
        $m = [regex]::Match($l, '^Calibration : passe de vérification 1/\d+, tête 0 puis tête 1, profils (\S+) et (\S+)$')
        if ($m.Success) { return @{ 0 = $m.Groups[1].Value; 1 = $m.Groups[2].Value } }
    }
    return $null
}
# Les deux fonctions suivantes rendent leurs cylindres un par un : l appelant les reunit par @()
function Get-FbNeedDiff([string]$spec, [int]$h) {
    # Cylindres dont la valeur du profil differe du besoin factice de la tete
    foreach ($c in 0..79) { if ([int](Get-SpecValue $spec $c) -ne (Get-FbNeedH $c $h)) { $c } }
}
function Get-FbSpecDiff([string]$a, [string]$b) { foreach ($c in 0..79) { if ([int](Get-SpecValue $a $c) -ne [int](Get-SpecValue $b $c)) { $c } } }
function Format-M([double]$x) { if ([double]::IsNaN($x)) { return '-' }; return $x.ToString('+0.000;-0.000;0.000', $inv) }

'--- F. Calibration long track factice de bout en bout (fonctions reelles, Complete-PrecompCalib reel)'
$o1 = @{ 0 = 3.85; 1 = -1.10 }
$fA = Invoke-FbCalib @{ O1 = $o1 }
$f0 = Invoke-FbCalib @{ O1 = @{ 0 = 0.0; 1 = 0.0 } }
$fK = Invoke-FbCalib @{ O1 = $o1; KLong = 1.0 }
Write-FbLog $fA 'f-avec-decalage'; Write-FbLog $f0 'f-sans-decalage'; Write-FbLog $fK 'f-facteur-1'
$tol = [double]$script:CalResidual
$fmtO = '{0:+0.0;-0.0;0.0}'      # format des decalages des lignes de journal de 270 (culture courante)
$txtRem = "Vérification {0} : décalage commun de l'écriture {1} ns de décalage (médiane des résidus de {2} cylindres, erreur-type {3}) : retiré des résidus avant le jugement et toute correction ; la courbe n'est pas déplacée."
$txtNo = "Vérification {0} : décalage commun de l'écriture non évalué ({1} cylindres exploitables, {2} au moins nécessaires) : les résidus sont jugés tels quels."

# F0 : chaque deroule va a son terme sans erreur, et la courbe envoyee a la verification 1 vaut le besoin factice a tous
# les cylindres (condition des attendus de F2 et de F4 : le residu d un cylindre est alors decalage + bruit)
$pV1 = @{}
foreach ($x in @(@('F0a', 'avec decalage (+3,85 / -1,10 ns)', $fA), @('F0b', 'sans decalage', $f0), @('F0c', 'facteur de famille 1, avec decalage', $fK))) {
    $r = $x[2]; $p = Get-FbV1Profiles $r.Log; $pV1[$x[0]] = $p
    $d0 = -1; $d1 = -1; $dTxt = 'ligne de la verification 1 absente'
    if ($p) { $x0 = @(Get-FbNeedDiff $p[0] 0); $x1 = @(Get-FbNeedDiff $p[1] 1); $d0 = $x0.Count; $d1 = $x1.Count; $dTxt = "tete 0 : $(Format-Set $x0), tete 1 : $(Format-Set $x1)" }
    Chk $x[0] ($r.Err -eq '' -and $r.Done -and $r.NStop -eq 0 -and $r.NSave -eq 1 -and $r.NShown -eq 1 -and @($r.Review).Count -eq 0 -and $r.Guard -lt 900 -and $d0 -eq 0 -and $d1 -eq 0) "$($x[1]) : $($r.Guard) etapes, $(@($r.Cmds).Count) commandes gw, termine $($r.Done), erreur « $($r.Err) », arrets $($r.NStop), configuration enregistree $($r.NSave) fois, fenetre Courbe $($r.NShown) fois, fenetre de decision $(@($r.Review).Count) ; cylindres ou la courbe de la verification 1 differe du besoin : $dTxt (attendu : aucun)"
}

# F1 : niveaux de la famille au journal et dans l etat ; encadrement des seuls cylindres dont le besoin depasse 200 ns
$lm = Get-LogStart $fA.Log 'Calibration : passe de mesure '
$expM1 = 'Calibration : passe de mesure 1/3, niveaux 0/60/200 ns répartis sur les cylindres (chaque cylindre reçoit chaque niveau une fois en 3 passes)'
$nLv = @($lm | Where-Object { $_.Contains(', niveaux 0/60/200 ns répartis sur les cylindres ') }).Count
Chk 'F1a' ($lm.Count -eq 3 -and $lm[0] -ceq $expM1 -and $nLv -eq 3 -and $fA.State0.Values -eq '0/60/200' -and $fA.State0.MaxCoarse -eq 200 -and $fA.State0.Latin -and [int]$fA.Cal.MaxCoarse -eq 200) "famille long track : $($lm.Count) passes de mesure, $nLv aux niveaux 0/60/200 ns, premiere ligne au texte exact : $($lm.Count -gt 0 -and $lm[0] -ceq $expM1) ; etat : niveaux $($fA.State0.Values), niveau maximal $($fA.State0.MaxCoarse) au depart et $($fA.Cal.MaxCoarse) a la fin (attendu 200)"
$expBr = @{}; foreach ($h in 0, 1) { $expBr[$h] = [int[]]@(0..79 | Where-Object { (Get-FbNeedH $_ $h) -gt 200 }) }
$union = [int[]]@(@($expBr[0]) + @($expBr[1]) | Sort-Object -Unique)
$lb = Get-LogStart $fA.Log "Calibration : passe d'encadrement des cylindres "
$expB = "Calibration : passe d'encadrement des cylindres $(Format-CylList $union), encore sous-compensés à 200 ns : precomp "
$okBr = $true; $brTxt = @()
foreach ($h in 0, 1) {
    $u = $fA.Units[$h]
    $got = Format-Set @($u.Bracket.Keys)
    $vals = @($u.Bracket.Values | ForEach-Object { [int]$_ })
    $out = @($vals | Where-Object { $_ -le 200 -or $_ -gt [int]$script:CalMaxNs }).Count
    if ($got -ne (Format-Set $expBr[$h]) -or $out -ne 0 -or @($expBr[$h]).Count -ne @(30, 34)[$h]) { $okBr = $false }
    $brTxt += "tete $h : $(@($u.Bracket.Keys).Count) cylindres encadres ($(@($expBr[$h]).Count) de besoin au-dela de 200 ns, ensembles egaux : $($got -eq (Format-Set $expBr[$h]))), valeurs ecrites hors de 201 a $($script:CalMaxNs) ns : $out"
}
Chk 'F1b' ($lb.Count -eq 1 -and $lb[0].StartsWith($expB, $ord) -and $okBr) "une passe d encadrement ($($lb.Count) ligne), des cylindres $(Format-CylList $union), « encore sous-compensés à 200 ns » : $($lb.Count -eq 1 -and $lb[0].StartsWith($expB, $ord)) ; $($brTxt -join ' ; ') (attendu : 30 et 34 cylindres, aucun de besoin a 200 ns au plus)"

# F2 : decalage commun evalue et retire a la verification 1, par tete ; residus juges centres ; courbe enregistree
$pinN = @(50, 46)      # cylindres du profil a 200 ns au plus : valeurs constatees a la premiere execution (11/11/2026)
foreach ($h in 0, 1) {
    $u = $fA.Units[$h]; $vo = $u.VOff; $isH = ($vo -is [hashtable])
    $m = [double]::NaN; $e = [double]::NaN; $n = -1
    if ($isH) { $m = [double]$vo.M; $e = [double]$vo.E; $n = [int]$vo.N }
    $expN = @(0..79 | Where-Object { (Get-FbNeedH $_ $h) -le 200 }).Count
    $line = "[tête $h] " + ($txtRem -f '1', ($fmtO -f $m), "$n", (Format-LevelNum $e))
    $nLine = @($fA.Log | Where-Object { $_ -ceq $line }).Count
    # Jugement : chaque residu est centre (Shift = brut - M, brut garde dans Raw), donc dans le bruit de 1 ns
    $nBad = 0; $maxAbs = 0.0; $nOver = 0
    foreach ($k in @($u.Verify.Keys)) {
        $mv = $u.Verify[$k]
        if ($null -eq $mv.Raw -or [math]::Abs(([double]$mv.Raw - [double]$mv.Shift) - $m) -gt 1e-9) { $nBad++ }
        $maxAbs = [math]::Max($maxAbs, [math]::Abs([double]$mv.Shift))
        if ($null -ne $mv.Raw -and [math]::Abs([double]$mv.Raw) -gt $tol) { $nOver++ }
    }
    $lr = Get-LogStart $fA.Log "[tête $h] Résidu après vérification (ns, tolérance "
    $note = " Résidus bruts, décalage commun de chaque écriture compris (vérification 1 : $($fmtO -f $m) ns, retiré avant le jugement)."
    $okNote = ($lr.Count -eq 1 -and $lr[0].EndsWith($note, $ord))
    $cv = $fA.Curves["long_h$h"]
    $resMax = [double]::NaN
    if ($cv -and $cv.Res) { $resMax = [double](@($cv.Res | ForEach-Object { [math]::Abs([double]$_) }) | Measure-Object -Maximum).Maximum }
    $okCv = ($cv -and [string]$cv.Calc -eq [string]$script:CalibCalc -and [string]$cv.Calc -eq '12.10' -and @($cv.Res).Count -eq 80 -and $resMax -le 1.05)
    Chk "F2-$h" ($isH -and [int]$vo.V -eq 1 -and [bool]$vo.Removed -and $n -eq $pinN[$h] -and $n -eq $expN -and (Test-Near $m ([double]$o1[$h])) -and $nLine -eq 1 -and @($u.Verify.Keys).Count -eq 80 -and $nBad -eq 0 -and $maxAbs -le 1.005 -and $okNote -and $okCv) "tete $h : decalage de l ecriture $(Format-M ([double]$o1[$h])) ns : M $(Format-M $m), E $(Format-M $e), N $n (attendu $($pinN[$h]) = cylindres du profil a 200 ns au plus : $expN), retire $(if ($isH) { $vo.Removed }) ; ligne « retiré » au texte exact : $nLine ; 80 residus juges centres (brut - M) : ecarts $nBad, plus grand $(Format-M $maxAbs) ns ; $nOver residus bruts au-dela de la tolerance de $tol ns ; rappel en fin de « Résidu après vérification » : $okNote ; courbe enregistree : calcul $(if ($cv) { $cv.Calc }), plus grand residu enregistre $(Format-M $resMax) ns"
    if ($nLine -eq 1) { "    | $line" }
}
$nNo = @($fA.Log | Where-Object { $_.Contains('non évalué') }).Count
Chk 'F2-n' ($nNo -eq 0) "aucune ligne « non évalué » dans le journal de la calibration long track ($nNo)"

# F3 : contre-epreuve : facteur des niveaux du long track a 1 (niveaux du standard, 0/30/100 ns) : tout le besoin depasse
# le niveau mesure, aucun cylindre exploitable
$lmK = Get-LogStart $fK.Log 'Calibration : passe de mesure '
$nLvK = @($lmK | Where-Object { $_.Contains(', niveaux 0/30/100 ns répartis sur les cylindres ') }).Count
$okNoK = $true; $noTxt = @()
foreach ($h in 0, 1) {
    $u = $fK.Units[$h]; $vo = $u.VOff
    $line = "[tête $h] " + ($txtNo -f '1', '0', "$([int]$script:CalVOffMinCyl)")
    $nLine = @($fK.Log | Where-Object { $_ -ceq $line }).Count
    if ($nLine -ne 1 -or -not ($vo -is [hashtable]) -or [int]$vo.N -ne 0 -or [bool]$vo.Removed) { $okNoK = $false }
    $noTxt += "tete $h : ligne « non évalué (0 cylindres exploitables, $([int]$script:CalVOffMinCyl) au moins nécessaires) » $nLine, N $(if ($vo -is [hashtable]) { $vo.N } else { '-' })"
}
$nRemK = @($fK.Log | Where-Object { $_.Contains('retiré des résidus avant le jugement') }).Count
Chk 'F3' ($fK.State0.Values -eq '0/30/100' -and $fK.State0.MaxCoarse -eq 100 -and $lmK.Count -eq 3 -and $nLvK -eq 3 -and $okNoK -and $nRemK -eq 0) "facteur 1 : niveaux $($fK.State0.Values), niveau maximal $($fK.State0.MaxCoarse), $nLvK passes de mesure aux niveaux 0/30/100 ns ; $($noTxt -join ' ; ') ; lignes « retiré » : $nRemK (attendu 0)"
# F3b : consequence, celle que les niveaux par famille ont levee : le decalage non evalue de la tete 0 (+3,85 ns, au
# bord de la tolerance de 4 ns) est juge comme une erreur de la courbe, des cylindres sont deplaces et une verification 2
# les relit ; la tete 1 (-1,10 ns) reste dans la tolerance
$pK = $pV1['F0c']
$chg0 = @(); $chg1 = @()
if ($pK) { $chg0 = @(Get-FbSpecDiff $fK.Units[0].Profile $pK[0]); $chg1 = @(Get-FbSpecDiff $fK.Units[1].Profile $pK[1]) }
$lv2K = Get-LogStart $fK.Log 'Calibration : passe de vérification 2/2 ciblée sur les cylindres modifiés : [tête 0] '
Chk 'F3b' ($pK -and $chg0.Count -gt 0 -and $chg1.Count -eq 0 -and $lv2K.Count -eq 1) "facteur 1, sans evaluation : tete 0 : $($chg0.Count) cylindre(s) deplace(s) d apres le decalage de l ecriture ($(Format-Set $chg0)), verification 2 ciblee : $($lv2K.Count) ligne ; tete 1 : $($chg1.Count) deplace (attendu 0)"

# F4 : avec les niveaux de la famille, le profil final ne depend pas du decalage de l ecriture de verification
$okSame = $true; $sameTxt = @()
foreach ($h in 0, 1) {
    $ua = $fA.Units[$h]; $ub = $f0.Units[$h]
    $ca = $fA.Curves["long_h$h"]; $cb = $f0.Curves["long_h$h"]
    $same = ([string]$ua.Profile -ceq [string]$ub.Profile) -and $ua.Profile -and ((@($ua.Fit.Values) -join ',') -eq (@($ub.Fit.Values) -join ','))
    $kept = ($pV1['F0a'] -and [string]$ua.Profile -ceq [string]$pV1['F0a'][$h])
    $saved = ($ca -and $cb -and [string]$ca.Spec -ceq [string]$cb.Spec -and [string]$ca.Spec -ceq [string]$ua.Profile)
    $vb = $ub.VOff
    $none = ($vb -is [hashtable]) -and -not [bool]$vb.Removed -and (Test-Near ([double]$vb.M) 0.0)
    if (-not ($same -and $kept -and $saved -and $none)) { $okSame = $false }
    $sameTxt += "tete $h : profil final identique $same, egal a celui de la verification 1 $kept, courbes enregistrees identiques $saved ; sans decalage : M $(if ($vb -is [hashtable]) { Format-M ([double]$vb.M) } else { '-' }), rien de retire $none"
}
$nV2 = @(@($fA.Log) + @($f0.Log) | Where-Object { $_.Contains('passe de vérification 2/') }).Count
$nCorr = @(@($fA.Log) + @($f0.Log) | Where-Object { $_.Contains('hors tolérance, ') }).Count
Chk 'F4' ($okSame -and $nV2 -eq 0 -and $nCorr -eq 0 -and @($fA.Cmds).Count -eq @($f0.Cmds).Count) "avec et sans decalage de l ecriture : $($sameTxt -join ' ; ') ; verifications 2 : $nV2, lignes de correction : $nCorr (attendu 0 et 0) ; commandes gw : $(@($fA.Cmds).Count) et $(@($f0.Cmds).Count)"

"=== bilan logic-calib-decalage-fort-besoin : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$(if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') }) ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
