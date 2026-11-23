param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-129-cal2-retest-1210) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out. Harnais cal2-commun.ps1 a cote du test.
# Copie 12.10 (mission rebase du lot 1, 01/11/2026) : la reserve 'sat' de Complete-PrecompCalib tient sur plusieurs lignes depuis le lot 1 (A13a) : condition « une seule ligne » levee pour 'sat' ; cal2-commun.ps1 lu dans le dossier d origine ; aucun attendu change. Original : v129\cal2\impl\tests\logic-129-cal2-retest.ps1.
# 12.9, corrections du calcul de calibration (spec-finale.md § 11.5, § 6 et § 7) : ligne du nouvel essai a valeur
# inchangee (Get-CalibRetestPlan : Bound, Raw, Same ; Start-CalibRetest : lignes du journal) et correctif de repli D-L2c
# (ligne de derive non retiree ecrite apres le choix des temoins du nouvel essai, Add-DriftWitnesses). Fonctions reelles
# de 230, 240 et 270 (extraites par l arbre syntaxique, dot-source), dont Get-CalibWarnings ; remplacants nommes :
# Get-ResidualFlags (cylindres retenus = cibles du cas), Get-VerifyDrift (derive non mesuree), New-CalibPass,
# Append-Log, T. Unite synthetique (tete 0) : valeurs 34 de c59 a c69, cibles c60, c61, c65-c67 a residu -6 ns de
# decalage (pente -1,5 : valeur visee 30), voisins verifies dans la tolerance. Aucun gw, aucune fenetre.
# fix2 (banc cal2, G4-02, 01/11/2026) : cas G1 a G5, avec Get-ResidualFlags reel (Get-ResidualFlagsReal) et une passe du
# nouvel essai simulee (cylindres de VerifyList relus : cibles a 0,5 x bruit, autres a leur residu d avant). G1 : cylindre
# non converge exclu du nouvel essai, piste deja ecrite WriteMax fois, voisins convergents : NON CONVERGE (RtFull), reserve
# « non convergée » qui ouvre la fenetre de decision (instructions de Complete-PrecompCalib extraites par l arbre
# syntaxique), courbe inchangee. G2 : valeur visee hors des limites et absent de la relecture : meme garde. G3 : valeur
# visee hors des limites mais relu comme voisin : juge sur sa mesure fraiche (comportement d avant fix2 garde). G4 : RtFull
# ne passe ni a la calibration suivante (unites de Start-PrecompCalib, instruction extraite) ni a la reprise sur une autre
# disquette (Restart-PrecompCalib reel), n est lu que par Get-CalibWarnings et ecrit que par Start-CalibRetest (jamais
# enregistre). G5 : RtKept = @(0) (c0 seul retabli) pris en compte par Get-CalibWarnings.
# Revue fix2 (01/11/2026, constats C1 et C2) : cas P1 a P3 et M. P1 (cylindre non reproductible voisin), P2 (zone
# contradictoire voisine), P3 (mesure complete, deuxieme nouvel essai, valeur visee inchangee) : cylindre non converge exclu
# pour un autre motif que WriteMax ou les limites, ni vise ni relu : NON CONVERGE (RtFull) ; P3 : union avec le RtFull d un
# nouvel essai precedent. M : deux unites (ecriture lente) : seule la relecture du plan de la meme unite compte. Le
# remplacant de Get-VerifyDrift rend les cylindres non reproductibles et la zone contradictoire du cas (FxNR, FxContra).
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
. (Join-Path $PSScriptRoot 'cal2-commun.ps1')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Get-Cal2Modules $Wt
$parts = New-Object System.Collections.Generic.List[string]; $found = @{}
foreach ($f in '230-fn-calib-courbe.ps1', '240-fn-calib-mesure.ps1', '270-fn-calib-complete.ps1') { Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $mods $f)) @('*') $found $f }
function Get-RtGenFns([string]$p270) {
    # fix2 : fonctions de travail tirees de 270 par l arbre syntaxique, instructions recopiees telles quelles.
    # New-Cal2Units($slow) : affectation « $units = » de Start-PrecompCalib (unites de toute nouvelle calibration : bouton,
    # Accueil, avant une ecriture, restauration, calibration B, mesure complete). Get-Cal2UnitIssues($u) : instructions de
    # Complete-PrecompCalib qui ajoutent les reserves 'nonconv', 'sat', 'floor' et 'dev' d une unite ; la fenetre de
    # decision s ouvre s il y a une reserve (« if ($issues.Count -gt 0) », qui appelle Show-CalibReview : ligne rendue)
    $ast = Get-Cal2Ast $p270
    $fds = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $sp = @($fds | Where-Object { $_.Name -eq 'Start-PrecompCalib' }); $cp = @($fds | Where-Object { $_.Name -eq 'Complete-PrecompCalib' })
    if ($sp.Count -ne 1 -or $cp.Count -ne 1) { throw "Start-PrecompCalib ($($sp.Count)) ou Complete-PrecompCalib ($($cp.Count)) introuvable" }
    $us = @($sp[0].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$units' }, $true))
    if ($us.Count -ne 1) { throw "affectation des unites dans Start-PrecompCalib : $($us.Count) (1 attendue)" }
    $ifs = @($cp[0].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.IfStatementAst] }, $true))
    $iss = New-Object System.Collections.Generic.List[string]; $issL = New-Object System.Collections.Generic.List[string]
    foreach ($k in 'nonconv', 'sat', 'floor', 'dev') {
        $st = @($ifs | Where-Object { $_.Extent.Text.Contains("`$kinds.Add('$k')") -and ($k -eq 'sat' -or -not $_.Extent.Text.Contains("`n")) })
        if ($st.Count -ne 1) { throw "reserve '$k' de Complete-PrecompCalib : $($st.Count) instruction(s) (1 attendue)" }
        $iss.Add($st[0].Extent.Text); $issL.Add([string]$st[0].Extent.StartLineNumber)
    }
    $win = @($ifs | Where-Object { $_.Clauses[0].Item1.Extent.Text -eq '$issues.Count -gt 0' -and $_.Clauses[0].Item2.Extent.Text.Contains('Show-CalibReview') })
    if ($win.Count -ne 1) { throw "fenetre de decision de Complete-PrecompCalib : $($win.Count) (1 attendue)" }
    $t1 = "function New-Cal2Units(`$slow) {`r`n" + $us[0].Extent.Text + "`r`nreturn ,`$units`r`n}"
    $t2 = "function Get-Cal2UnitIssues(`$u) {`r`n`$issues = New-Object System.Collections.Generic.List[string]; `$kinds = New-Object System.Collections.Generic.List[string]`r`n" + (@($iss) -join "`r`n") + "`r`nreturn @{ Issues = @(`$issues); Kinds = @(`$kinds) }`r`n}"
    return @{ Texts = @($t1, $t2); UnitsLine = $us[0].Extent.StartLineNumber; IssLines = (@($issL) -join ', '); WinLine = $win[0].Extent.StartLineNumber }
}
Add-Cal2Fns $parts (Get-Cal2FnDefs (Join-Path $mods '260-fn-calib-rapide.ps1')) @('Format-LevelNum') $found '260'
Test-Cal2Missing @('Get-FitDents', 'Get-CalibRetestPlan', 'Start-CalibRetest', 'Get-CalibWarnings', 'Add-DriftWitnesses', 'Get-ResidualFlags', 'New-CalibUnit', 'Restart-PrecompCalib') $found
# fix2 (cas G) : Get-ResidualFlags reel sous un autre nom (le remplacant du meme nom choisit selon le cas), unites d une
# nouvelle calibration et reserves de fin de calibration (Get-RtGenFns)
$parts.Add((Get-Cal2Renamed (Get-Cal2FnDefs (Join-Path $mods '240-fn-calib-mesure.ps1')) 'Get-ResidualFlags' 'Get-ResidualFlagsReal'))
$fnG = Get-RtGenFns (Join-Path $mods '270-fn-calib-complete.ps1')
foreach ($tx in $fnG.Texts) { $parts.Add($tx) }
foreach ($s in (Get-Cal2Consts $mods)) { $parts.Add($s) }
$gen = Join-Path $here 'gen-cal2-retest.ps1'
Write-Cal2Gen $gen $parts
. $gen
function T([string]$s) { return $s }
function Format-UiNum([double]$v, [string]$fmt = '0.#') { return $v.ToString($fmt, [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')) }
$script:RLog = New-Object System.Collections.Generic.List[string]
function Append-Log([string]$text) { $script:RLog.Add($text) }
function New-CalibPass { $script:NPass++ }
function Get-ResidualFlags($u) {
    # Remplacant (cas R : cylindres retenus = cibles du cas) ; fix2 (cas G) : Get-ResidualFlags reel
    if ($script:FxReal) { return (Get-ResidualFlagsReal $u) }
    return @{ Bad = $script:FxBad; Spot = @(); Sigma = 1.0; NDiff = 50; Hard = 12.0; HardPair = 8.5 }
}
function Update-CalibProgress { }
function Start-CalibWarmup { $script:NWarm++ }
$pbWCal = [pscustomobject]@{ Value = 0; Visible = $false }
$script:FxReal = $false; $script:NWarm = 0; $script:FxNR = @{}; $script:FxContra = @{}
function Get-VerifyDrift($u) { return @{ Use = $false; D = 0.0; S = [double]::NaN; SRaw = [double]::NaN; E = [double]::NaN; NW = 0; NC = 0; DC = [double]::NaN; NonRepro = $script:FxNR.Clone(); Sys = @{}; Contra = $script:FxContra.Clone(); ContraNoDrift = $false } }
$script:Lang = 'fr'; $script:NPass = 0
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
"logic-129-cal2-retest : $(@($found.Keys).Count) fonctions ; PowerShell $($PSVersionTable.PSVersion) ; $gen"
"fix2 : unites de Start-PrecompCalib (270:$($fnG.UnitsLine)), reserves de Complete-PrecompCalib (270:$($fnG.IssLines)), fenetre de decision (270:$($fnG.WinLine))"
$tg = [int[]]@(60, 61, 65, 66, 67)

function New-RtCal([bool]$dent, [bool]$prev, [int]$wOther, [bool]$nonRelu) {
    $vals = New-Object int[] 80
    for ($c = 0; $c -lt 80; $c++) { $vals[$c] = $(if ($c -ge 59 -and $c -le 69) { 34 } elseif ($c -lt 59) { [int](34 - (59 - $c) * 0.5) } else { 34 + ($c - 69) }) }
    $segs = if ($dent) { @(@{ Lo = 0; Hi = 64; Dir = 1 }, @{ Lo = 65; Hi = 65; Dir = -1 }, @{ Lo = 66; Hi = 79; Dir = 1 }) } else { @(@{ Lo = 0; Hi = 79; Dir = 1 }) }
    $dl = if ($dent) { @(@{ C1 = 64; C2 = 65; Drop = 6.5; Min = 5.0; Conf = $true; V = 1; DV = 7.0 }) } else { @() }
    $u = New-CalibUnit 0
    $u.Fit = @{ Model = 'seg'; A = $null; B = $null; Chi = 1.0; Values = $vals; Breaks = @(); Segs = $segs; Outliers = @(); Dents = $dl }
    $u.Profile = Build-CurveProfile $vals; $u.Slope = -1.5
    foreach ($c in 50..75) {
        $u.Est[$c] = [double]$vals[$c]; $u.Sig[$c] = 1.0; $u.Kind[$c] = 'interp'; $u.Own[$c] = $true
        $u.Results[$c] = @{ ([int]$vals[$c]) = @{ Shift = 0.0; SE = 0.5; Score = 40.0 } }
        if ($nonRelu -and $c -eq 70) { continue }
        $u.Verify[$c] = @{ Shift = $(if ($tg -contains $c) { -6.0 } else { 0.0 }); SE = 0.5; Score = 40.0 }
        $u.VerifyP[$c] = [int]$vals[$c]
    }
    for ($c = 0; $c -lt 80; $c++) { $u.Writes[$c] = $(if ($tg -contains $c -or ($nonRelu -and $c -eq 70)) { 3 } else { $wOther }) }
    if ($prev) { $u.VerifyPrev = @{ 52 = @{ Shift = 0.0; P = [double]$vals[52]; Meas = @{ Shift = 0.0; SE = 0.5; Score = 40.0 } } } }
    $u.VerifyList = @()
    $script:FxBad = @{}; foreach ($c in $tg) { $script:FxBad[$c] = $true }
    return @{ Units = @($u); MaxCyl = 79; WriteMax = 7; Retests = 0; VerifyCount = 2; PassesDone = 6; TotalPasses = 6; Mode = 'fine'; Densified = $false
              SurfKept = $false; Surf = $null; SurfGross = $false; Medium = $null; DiskOnly = $false; Stage = 'verify' }
}
function Invoke-Rt([bool]$dent, [bool]$prev, [int]$wOther, [bool]$nonRelu) {
    $cal = New-RtCal $dent $prev $wOther $nonRelu
    $script:Cal = $cal
    $plan = Get-CalibRetestPlan $cal
    $script:RLog.Clear(); $script:NPass = 0
    $go = Start-CalibRetest $cal
    $u = @($cal.Units)[0]
    $p = @($plan.Go)[0]
    $r = @{ Go = $go; NGo = @($plan.Go).Count; Skip = @($plan.Skip); P = $p; Log = @($script:RLog); NPass = $script:NPass; U = $u
            Same = $(if ($p) { Format-Set $p.Same } else { '-' })
            Bound = $(if ($p -and $p.Bound) { (@($p.Bound.Keys | Sort-Object | ForEach-Object { "c$_<-c$($p.Bound[$_])" })) -join ' ' } else { '-' })
            Raw = $(if ($p -and $p.Raw) { (@($p.Raw.Keys | Sort-Object | ForEach-Object { "c$_=$(F ([double]$p.Raw[$_]) '0.#')" })) -join ' ' } else { '-' }) }
    $script:Cal = $null
    return $r
}
function Get-LineIdx($log, [string]$like) { for ($i = 0; $i -lt @($log).Count; $i++) { if ($log[$i] -like $like) { return $i } }; return -1 }
function Get-LineEq($log, [string]$s) { for ($i = 0; $i -lt @($log).Count; $i++) { if ($log[$i] -ceq $s) { return $i } }; return -1 }
$lBound = '[tête 0] Calibration : nouvel essai des cylindres {0} à leur valeur inchangée (34 ns) : valeur visée 30 ns, ramenée à la valeur écrite par les cylindres vérifiés voisins {1}, pour que la courbe reste monotone dans ce segment ; ils sont relus pour confirmer leur résidu, sans correction possible à ce nouvel essai.'
$lDriftW = '[tête 0] Calibration : dérive du lecteur non retirée à la dernière vérification (témoins insuffisants) : le nouvel essai est jugé sur ses propres témoins de dérive.'
$lDriftN = '[tête 0] Calibration : dérive du lecteur non retirée à la dernière vérification (témoins insuffisants), et aucun témoin possible pour le nouvel essai : il est jugé sans correction de dérive.'

# ---------------------------------------------------------------- R1. sans dent
"--- R1. Sans dent : un segment croissant, cibles bornees par c59 et c64"
$r1 = Invoke-Rt $false $false 3 $false
$r1.Log | ForEach-Object { "    | $_" }
"    Same $($r1.Same) ; bornes $($r1.Bound) ; valeurs visees $($r1.Raw)"
Chk 'R1a' ($r1.Go -and $r1.NGo -eq 1 -and (Format-Set $r1.P.Targets) -eq '60,61,65,66,67' -and $r1.Same -eq '60,61,65,66,67' -and $r1.Bound -eq 'c60<-c59 c61<-c59 c65<-c64 c66<-c64 c67<-c64' -and $r1.Raw -eq 'c60=30 c61=30 c65=30 c66=30 c67=30') "plan : cibles $(Format-Set $r1.P.Targets), Same $($r1.Same), Bound $($r1.Bound), Raw $($r1.Raw)"
$e1 = $lBound -f '60,61,65,66,67', 'c59, c64'
$nSame = @($r1.Log | Where-Object { $_ -like '*à leur valeur inchangée*' }).Count
Chk 'R1b' ((Get-LineEq $r1.Log $e1) -ge 0 -and $nSame -eq 1 -and (Get-LineIdx $r1.Log '*nouvel essai automatique des cylindres non convergés*') -ge 0 -and (Get-LineIdx $r1.Log '*dérive du lecteur non retirée*') -lt 0 -and $r1.NPass -eq 1) "journal : une ligne « valeur inchangée » ($nSame), voisins c59, c64, valeur visee 30 ns ; aucune ligne de derive (derive mesuree ou sans verification precedente) ; passe lancee ($($r1.NPass))"

# ---------------------------------------------------------------- R2. dent c64/c65
"--- R2. Avec la dent c64/c65 (segments [0-64 +][65-65 -][66-79 +]) : seules c60-c61 restent bornees"
$r2 = Invoke-Rt $true $false 3 $false
$r2.Log | ForEach-Object { "    | $_" }
$v2 = @($r2.P.Values)
"    Same $($r2.Same) ; bornes $($r2.Bound) ; valeurs c64-c68 $(@($v2[64..68]) -join ' ')"
Chk 'R2a' ($r2.Same -eq '60,61' -and $r2.Bound -eq 'c60<-c59 c61<-c59' -and (@($v2[65..67]) -join ' ') -eq '30 30 30' -and [int]$v2[64] -eq 34 -and [int]$v2[68] -eq 34 -and [int]$v2[60] -eq 34) "Same $($r2.Same) ; c65 (segment d un cylindre), c66 et c67 (bornes par c68 a 34, au-dessus de 30) passent a 30"
$e2 = $lBound -f '60-61', 'c59'
Chk 'R2b' ((Get-LineEq $r2.Log $e2) -ge 0 -and @($r2.Log | Where-Object { $_ -like '*à leur valeur inchangée*' }).Count -eq 1) "journal : ligne « valeur inchangée » de c60-c61 seulement, voisin c59"
$fd = @(Get-FitDents $r2.U.Fit)
Chk 'R2c' ($fd.Count -eq 1 -and [int]$fd[0].C1 -eq 64 -and (Get-SegTxt $r2.U.Fit) -eq '[0-64 +][65-65 -][66-79 +]' -and $r2.U.Fit.Model -eq 'seg+c') "courbe corrigee du nouvel essai (270:1443, § 5.7) : dent gardee ($($fd.Count)), segments $(Get-SegTxt $r2.U.Fit), modele $($r2.U.Fit.Model)"

# ---------------------------------------------------------------- R6. cible non relue (revue m6)
"--- R6. Cible non relue (c70, sans residu) : relue a sa valeur par construction, jamais decrite comme bornee ou lissee"
$r6 = Invoke-Rt $false $false 3 $true
"    cibles $(Format-Set $r6.P.Targets) ; Same $($r6.Same)"
Chk 'R6' (@($r6.P.Targets) -contains 70 -and $r6.Same -eq '60,61,65,66,67' -and @($r6.Log | Where-Object { $_ -like '*à leur valeur inchangée*' -and $_ -match '\b70\b' }).Count -eq 0) "c70 vise ($(@($r6.P.Targets) -contains 70)), hors de Same et des lignes « valeur inchangée »"

# ---------------------------------------------------------------- R3, R4. D-L2c
"--- R3, R4. D-L2c : derive non retiree a la derniere verification (aucun temoin), ligne ecrite apres le choix des temoins du nouvel essai"
$r3 = Invoke-Rt $false $true 3 $false
$r3.Log | ForEach-Object { "    | $_" }
$iA = Get-LineIdx $r3.Log '*nouvel essai automatique des cylindres non convergés*'; $iS = Get-LineIdx $r3.Log '*à leur valeur inchangée*'; $iD = Get-LineEq $r3.Log $lDriftW
$nD = @($r3.Log | Where-Object { $_ -like '*dérive du lecteur non retirée*' }).Count
Chk 'R3' ($r3.P.NoDrift -and $iD -gt $iS -and $iS -gt $iA -and $nD -eq 1 -and @($r3.U.Witness).Count -gt 0) "temoins possibles ($(@($r3.U.Witness).Count) : $(Format-Set $r3.U.Witness)) : une ligne ($nD) « jugé sur ses propres témoins », apres la ligne « valeur inchangée » (lignes $iA < $iS < $iD)"
$r4 = Invoke-Rt $false $true 7 $false
$r4.Log | ForEach-Object { "    | $_" }
$nD4 = @($r4.Log | Where-Object { $_ -like '*dérive du lecteur non retirée*' }).Count
Chk 'R4' ($r4.Go -and $r4.P.NoDrift -and (Get-LineEq $r4.Log $lDriftN) -ge 0 -and $nD4 -eq 1 -and @($r4.U.Witness).Count -eq 0) "pistes voisines deja ecrites WriteMax fois : aucun temoin possible ($(@($r4.U.Witness).Count)) : une ligne ($nD4) « aucun témoin possible pour le nouvel essai : il est jugé sans correction de dérive »"

# ---------------------------------------------------------------- G. fix2 (banc cal2, G4-02) : cylindre exclu du nouvel essai sans etre relu
"--- G. fix2 (G4-02, RtFull) : Get-ResidualFlags reel, passe du nouvel essai simulee, jugement et reserves de fin de calibration reels"
$script:FxReal = $true
function Get-Noise([int]$c) { return 0.3 * ((($c * 37) % 7) - 3) }
function Set-GState($u, [int[]]$vals, $res, $writes, [int]$wDef) {
    # Etat de la derniere verification, test fin c0-c79 : courbe $vals (un segment croissant, pente -1,5), residus $res
    # (bruit de 0,9 ns au plus ailleurs), ecritures par piste $writes (sinon $wDef)
    $u.Fit = @{ Model = 'seg'; A = $null; B = $null; Chi = 1.0; Values = $vals; Breaks = @(); Segs = @(@{ Lo = 0; Hi = 79; Dir = 1 }); Outliers = @(); Dents = @() }
    $u.Profile = Build-CurveProfile $vals; $u.Slope = -1.5
    for ($c = 0; $c -lt 80; $c++) {
        $u.Est[$c] = [double]$vals[$c]; $u.Sig[$c] = 1.0; $u.Kind[$c] = 'interp'; $u.Own[$c] = $true
        $u.Results[$c] = @{ ([int]$vals[$c]) = @{ Shift = 0.0; SE = 0.5; Score = 40.0 } }
        $u.Verify[$c] = @{ Shift = $(if ($res.ContainsKey($c)) { [double]$res[$c] } else { Get-Noise $c }); SE = 0.5; Score = 40.0 }
        $u.VerifyP[$c] = [int]$vals[$c]
        $u.Writes[$c] = $(if ($writes.ContainsKey($c)) { [int]$writes[$c] } else { $wDef })
    }
    $u.VerifyList = @()
}
function New-GCal($units, [int]$wmax) {
    return @{ Units = @($units); MaxCyl = 79; WriteMax = $wmax; Retests = 0; VerifyCount = 2; PassesDone = 6; TotalPasses = 6; Mode = 'fine'; Densified = $false
              SurfKept = $false; Surf = $null; SurfGross = $false; Medium = $null; DiskOnly = $false; Stage = 'verify' }
}
function Get-GJudge($u) {
    # Fin de calibration d une unite : Get-CalibWarnings reel, puis reserves de Complete-PrecompCalib (Get-Cal2UnitIssues)
    $w = Get-CalibWarnings $u 79
    $u.Warn = $w
    $iss = Get-Cal2UnitIssues $u
    return @{ NC = (Format-Set $w.NonConvC); NCTxt = (@($w.NonConv) -join ', '); Spot = (@($w.Spot) -join ', '); Issues = @($iss.Issues); Kinds = (@($iss.Kinds) -join ',') }
}
function Invoke-G($cal) {
    # Plan et Start-CalibRetest reels ; passe simulee : cylindres de VerifyList relus (cibles a 0,5 x bruit, autres a leur
    # residu d avant), les autres gardent leur mesure ; jugement final (Get-GJudge)
    $u = @($cal.Units)[0]
    $script:Cal = $cal; $script:RLog.Clear(); $script:NPass = 0
    $w0 = Get-CalibWarnings $u 79
    $v0 = [int[]]@($u.Fit.Values)
    $plan = Get-CalibRetestPlan $cal
    $tg = @(); $pl = @(); foreach ($p in @($plan.Go)) { $tg += @($p.Targets); $pl += @($p.List) }
    $go = Start-CalibRetest $cal
    $relus = [int[]]@(@($u.VerifyList) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    foreach ($c in $relus) {
        $r = if ($tg -contains $c) { 0.5 * (Get-Noise $c) } else { [double]$u.Verify[$c].Shift }
        $u.Verify[$c] = @{ Shift = $r; SE = 0.5; Score = 40.0 }
        $u.VerifyP[$c] = [int]$u.Fit.Values[$c]
    }
    $j = Get-GJudge $u
    $script:Cal = $null
    $o = @{ Cal = $cal; U = $u; Go = $go; NPass = $script:NPass; Pre = (Format-Set $w0.NonConvC); Targets = (Format-Set $tg); PlanList = (Format-Set $pl)
            PlanVals = $(if (@($plan.Go).Count) { [int[]]@(@($plan.Go)[0].Values) } else { $null }); Relus = (Format-Set $relus); Wit = (Format-Set $u.Witness)
            RtFull = (Format-Set $u.RtFull); V0 = $v0; V1 = [int[]]@($u.Fit.Values); J = $j; Log = @($script:RLog)
            Skip = (@(@($plan.Skip) | ForEach-Object { "c$(Format-Set $_.NonConv) ($($_.Why) ; Full $([bool]$_.Full) ; Lim $([bool]$_.Lim))" }) -join ' | ') }
    $ln = New-Object System.Collections.Generic.List[string]
    $ln.Add("    avant le nouvel essai : NonConv $($o.Pre) ; plan : exclus $($o.Skip) ; cibles $($o.Targets) ; relus du plan $($o.PlanList)")
    $ln.Add("    passe lancee $($o.Go) ($($o.NPass)) ; relus a la passe $($o.Relus) (temoins $($o.Wit)) ; RtFull $($o.RtFull)")
    $ln.Add("    jugement final : NonConv $(if ($j.NCTxt) { $j.NCTxt } else { '-' }) ; Spot $(if ($j.Spot) { $j.Spot } else { '-' }) ; reserves $(if (@($j.Issues).Count) { (@($j.Issues) -join ' | ') + ' : fenetre de decision' } else { 'aucune : pas de fenetre' })")
    foreach ($l in @($script:RLog)) { $ln.Add("    | $(if ($l.Length -gt 220) { $l.Substring(0, 220) + '...' } else { $l })") }
    $o.Lines = $ln.ToArray()
    return $o
}

"--- G1. Test fin, tete 1, WriteMax 6 (test fin haute densite ; depuis l option A, la garde WriteMax ne joue plus qu en haute densite, test fin ou standard) : c40-c46 non converges, c40 deja ecrit 6 fois (encadrement), c41-c46 convergent au nouvel essai"
$vA = New-Object int[] 80; for ($c = 0; $c -lt 80; $c++) { $vA[$c] = 50 + $c }
$uA = New-CalibUnit 1
Set-GState $uA $vA @{ 40 = 9.0; 41 = 10.0; 42 = 11.0; 43 = 12.0; 44 = 12.0; 45 = 13.0; 46 = 14.0 } @{ 40 = 6 } 5
$g1 = Invoke-G (New-GCal @($uA) 6)
$g1.Lines
"    courbe c38-c48 avant / apres : $(@($g1.V0[38..48]) -join ' ') / $(@($g1.V1[38..48]) -join ' ')"
$lFull = '[tête 1] Calibration : pas de nouvel essai automatique des cylindres non convergés 40 : pistes déjà écrites le nombre maximal de fois annoncé (6).'
Chk 'G1a' ($g1.Pre -eq '40,41,42,43,44,45,46' -and $g1.Skip -eq 'c40 (pistes déjà écrites le nombre maximal de fois annoncé (6) ; Full True ; Lim False)' -and $g1.Targets -eq '41,42,43,44,45,46' -and $g1.Go -eq $true -and $g1.NPass -eq 1 -and (Get-LineEq $g1.Log $lFull) -ge 0) "plan : c40 exclu par WriteMax (drapeau Full), cibles $($g1.Targets), passe lancee ($($g1.NPass)) ; ligne « pas de nouvel essai ... 40 ... (6) »"
Chk 'G1b' ($g1.RtFull -eq '40' -and @($g1.PlanList -split ',') -notcontains '40' -and @($g1.Relus -split ',') -notcontains '40') "RtFull $($g1.RtFull) ; c40 ni reecrit ni relu : absent des relus du plan ($($g1.PlanList)) et de la passe ($($g1.Relus), temoins compris)"
Chk 'G1c' ($g1.J.NC -eq '40' -and $g1.J.NCTxt -like 'c40 (+9?0)' -and $g1.J.Spot -notlike '*c40 *') "tete 1 NON CONVERGEE : NonConv $($g1.J.NCTxt) ; c40 hors des ecarts locaux (Spot '$($g1.J.Spot)')"
Chk 'G1d' ((@($g1.J.Issues) -join ' | ') -like '[[]tête 1] non convergée aux cylindres c40 (+9?0)' -and $g1.J.Kinds -eq 'nonconv') "reserve de Complete-PrecompCalib « $(@($g1.J.Issues) -join ' | ') » ($($g1.J.Kinds)) : la fenetre de decision s ouvre (270:$($fnG.WinLine), Show-CalibReview)"
$chg1 = @(0..79 | Where-Object { @(41..46) -notcontains $_ -and [int]$g1.V1[$_] -ne [int]$g1.V0[$_] }).Count
$up1 = @(41..46 | Where-Object { [int]$g1.V1[$_] -gt [int]$g1.V0[$_] }).Count
Chk 'G1e' ($chg1 -eq 0 -and [int]$g1.V1[40] -eq 90 -and (@($g1.V1) -join ',') -eq (@($g1.PlanVals) -join ',') -and $up1 -eq 6) "courbe : celle du plan, cibles c41-c46 corrigees ($up1 : $(@($g1.V1[41..46]) -join ' ') ns) ; c40 a $($g1.V1[40]) ns comme avant le nouvel essai ; autres cylindres inchanges ($chg1 ecart) : fix2 ne change que le verdict"

"--- G2. Test fin, tete 0 : c3 non converge, valeur visee sous 0 (drapeau Lim), absent de la relecture du plan (cibles c5-c9)"
$vB = New-Object int[] 80; for ($c = 0; $c -lt 80; $c++) { $vB[$c] = 4 + $c }
$uB = New-CalibUnit 0
Set-GState $uB $vB @{ 3 = -11.0; 5 = -12.0; 6 = -12.0; 7 = -12.0; 8 = -12.0; 9 = -12.0 } @{} 5
$g2 = Invoke-G (New-GCal @($uB) 6)
$g2.Lines
Chk 'G2a' ($g2.Skip -eq 'c3 (précompensation visée hors de ses limites (0 ou 400 ns) ; Full False ; Lim True)' -and $g2.Targets -eq '5,6,7,8,9' -and @($g2.PlanList -split ',') -notcontains '3' -and $g2.RtFull -eq '3') "c3 exclu (drapeau Lim), absent des relus du plan ($($g2.PlanList)) : RtFull $($g2.RtFull) (temoins de la passe : $($g2.Wit), un temoin est juge sur sa mesure precedente)"
Chk 'G2b' ($g2.J.NC -eq '3' -and $g2.J.NCTxt -like 'c3 (-11?0)' -and $g2.J.Spot -notlike '*c3 *' -and (@($g2.J.Issues) -join ' | ') -like '[[]tête 0] non convergée aux cylindres c3 (-11?0)') "NON CONVERGEE : NonConv $($g2.J.NCTxt) ; reserve « $(@($g2.J.Issues) -join ' | ') » : fenetre de decision"

"--- G3. Test fin, tete 0 : c3 non converge, valeur visee sous 0, mais relu comme voisin de la cible c4 (cibles c4-c8)"
$uC = New-CalibUnit 0
Set-GState $uC $vB @{ 3 = -11.0; 4 = -10.0; 5 = -10.0; 6 = -10.0; 7 = -10.0; 8 = -10.0 } @{} 5
$g3 = Invoke-G (New-GCal @($uC) 6)
$g3.Lines
Chk 'G3' ($g3.Skip -like 'c3 (précompensation visée hors de ses limites (0 ou 400 ns) ;*' -and @($g3.PlanList -split ',') -contains '3' -and $g3.RtFull -eq '-' -and $g3.J.NC -eq '-' -and $g3.J.Spot -like '*c3 (-11?0)*' -and @($g3.J.Issues).Count -eq 0) "c3 exclu mais relu comme voisin ($($g3.PlanList)) : pas de RtFull ($($g3.RtFull)), juge sur sa mesure fraiche : ecart local (Spot $($g3.J.Spot)), aucune reserve ; comportement d avant fix2 garde (rapport fix2\code § 5.4 ; cas ouvert pour la 12.10)"

"--- G4. RtFull ne passe ni a la calibration suivante ni a la reprise sur une autre disquette ; ou il est lu et ecrit"
# Etat juge : c40 seul hors tolerance (+9 ns), voisins dans le bruit : ecart local pour une unite sans RtFull
$isoRes = @{ 40 = 9.0 }
$nu = New-Cal2Units $true
$uN = @($nu)[1]
$keysN = @(@($nu) | ForEach-Object { @($_.Keys) } | Where-Object { "$_" -like 'Rt*' })
Set-GState $uN $vA $isoRes @{} 5
$jN = Get-GJudge $uN
Set-GState $uA $vA $isoRes @{} 5
$jA = Get-GJudge $uA
"    nouvelle calibration (unites de Start-PrecompCalib:$($fnG.UnitsLine)) : NonConv $(if ($jN.NCTxt) { $jN.NCTxt } else { '-' }) ; Spot $($jN.Spot) ; unite de G1 (RtFull $(Format-Set $uA.RtFull)) dans le meme etat : NonConv $(if ($jA.NCTxt) { $jA.NCTxt } else { '-' })"
Chk 'G4a' (@($nu).Count -eq 2 -and [int]$uN.Head -eq 1 -and $keysN.Count -eq 0 -and -not [object]::ReferenceEquals($uN, $uA) -and $jN.NC -eq '-' -and $jN.Spot -like '*c40 (+9?0)*' -and @($jN.Issues).Count -eq 0 -and $jA.NC -eq '40') "calibration suivante (toutes les entrees passent par Start-PrecompCalib:$($fnG.UnitsLine)) : unites neuves sans champ Rt* ($($keysN.Count)) ; c40 seul a +9 ns : ecart local, aucune reserve ; temoin : l unite de G1, qui garde RtFull, le jugerait NON CONVERGE ($($jA.NCTxt))"
$calR = $g1.Cal
$calR.Family = 'std'; $calR.Slow = $true; $calR.Cyls = @(0..79); $calR.CylList = '0-79'; $calR.Disk = 1; $calR.Swap = $false
$script:RLog.Clear(); $script:NWarm = 0
Restart-PrecompCalib $calR $false
$ur = @($calR.Units)
$keysR = @($ur | ForEach-Object { @($_.Keys) } | Where-Object { "$_" -like 'Rt*' })
$uRep = $ur[1]
Set-GState $uRep $vA $isoRes @{} 5
$jR = Get-GJudge $uRep
Chk 'G4b' ($ur.Count -eq 2 -and $keysR.Count -eq 0 -and -not [object]::ReferenceEquals($uRep, $uA) -and [int]$calR.Retests -eq 0 -and [int]$calR.Disk -eq 2 -and $script:NWarm -eq 1 -and (Get-LineIdx $script:RLog '=== Calibration precomp reprise sur une autre disquette (disquette 2)*') -ge 0 -and $jR.NC -eq '-' -and $jR.Spot -like '*c40 (+9?0)*') "reprise sur une autre disquette (Restart-PrecompCalib reel, calibration de G1) : unites recreees sans champ Rt* ($($keysR.Count)), Retests $($calR.Retests), disquette $($calR.Disk) ; c40 seul a +9 ns : ecart local (Spot $($jR.Spot))"
$rfMods = @(); $rfUse = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $mods -Filter '*.ps1' | Where-Object { $_.Name -match '^\d{3}-' } | Sort-Object Name)) {
    if (-not ([System.IO.File]::ReadAllText($f.FullName)).Contains('RtFull')) { continue }
    $rfMods += $f.Name.Substring(0, 3)
    foreach ($m in @((Get-Cal2Ast $f.FullName).FindAll({ param($x) $x -is [System.Management.Automation.Language.MemberExpressionAst] -and $x.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $x.Member.Value -eq 'RtFull' }, $true))) {
        $pa = $m.Parent; while ($pa -and $pa -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $pa = $pa.Parent }
        $isW = ($m.Parent -is [System.Management.Automation.Language.AssignmentStatementAst] -and [object]::ReferenceEquals($m.Parent.Left, $m))
        $rfUse["$(if ($pa) { $pa.Name } else { '(niveau du script)' }) ($(if ($isW) { 'ecriture' } else { 'lecture' }))"] = $true
    }
}
$rfTxt = (@($rfUse.Keys | Sort-Object) -join ', ')
Chk 'G4c' (($rfMods -join ',') -eq '240,270' -and $rfTxt -eq 'Get-CalibWarnings (lecture), Start-CalibRetest (ecriture), Start-CalibRetest (lecture)') "RtFull dans les modules $(if ($rfMods.Count) { $rfMods -join ', ' } else { 'aucun' }) ; references : $(if ($rfTxt) { $rfTxt } else { 'aucune' }) (ni New-CalibUnit, ni Complete-PrecompCalib, ni configuration : jamais enregistre)"

"--- G5. RtKept = @(0) (c0 seul retabli par une correction sans effet) : garde de Get-CalibWarnings"
$script:FxReal = $false; $script:FxBad = @{}
$u5 = New-CalibUnit $null
Set-GState $u5 $vA @{ 0 = 9.0 } @{} 5
$u5.RtKept = [int[]]@(0)
$j5 = Get-GJudge $u5
Chk 'G5' ($j5.NC -eq '0' -and $j5.Spot -notlike '*c0 *') "c0 retabli (RtKept = @(0)), hors tolerance (+9 ns), non retenu par Get-ResidualFlags (remplacant) : NonConv $(if ($j5.NCTxt) { $j5.NCTxt } else { '-' }) ; Spot '$($j5.Spot)' (avant fix2 : ecart local, la garde « if (`$u.RtKept) » ignorait @(0))"

# ---------------------------------------------------------------- P, M. Revue fix2 (C1, C2) : autres motifs d exclusion
"--- P. Revue fix2 (C1) : cylindre non converge exclu du nouvel essai pour un autre motif que WriteMax ou les limites, ni vise ni relu : NON CONVERGE (RtFull)"
$script:FxReal = $true; $script:FxBad = @{}
$vP = New-Object int[] 80; for ($c = 0; $c -lt 80; $c++) { $vP[$c] = 50 + $c }
$resP = @{ 31 = 9.0; 32 = 3.0; 33 = 10.0; 34 = 11.0; 35 = 12.0; 36 = 12.0 }
"    P1. Test fin, tete 1, WriteMax 8 : c30 non reproductible ; c31 (+9) non converge, a 1 cylindre de c30 ; c32 (+3) dans la tolerance ; c33-c36 non converges, convergent au nouvel essai"
$uP1 = New-CalibUnit 1
$rP1 = $resP.Clone(); $rP1[30] = 12.0
Set-GState $uP1 $vP $rP1 @{} 5
$script:FxNR = @{ 30 = @{ Z1 = 74.0; Z2 = 88.0 } }; $script:FxContra = @{}
$p1 = Invoke-G (New-GCal @($uP1) 8)
$p1.Lines
$sk1 = 'c31 (à 2 cylindres au plus de cylindres non reproductibles d''une vérification à l''autre (c30) ; Full False ; Lim False)'
Chk 'P1a' ($p1.Skip -eq $sk1 -and $p1.Targets -eq '33,34,35,36' -and $p1.Go -eq $true -and $p1.NPass -eq 1 -and @($p1.PlanList -split ',') -notcontains '31' -and @($p1.Relus -split ',') -notcontains '31' -and $p1.RtFull -eq '31') "plan : c31 exclu (proximite de c30, ni Full ni Lim), cibles $($p1.Targets), passe lancee ($($p1.NPass)) ; c31 ni reecrit ni relu (relus du plan $($p1.PlanList), passe $($p1.Relus)) : RtFull $($p1.RtFull)"
Chk 'P1b' ($p1.J.NC -eq '31' -and $p1.J.NCTxt -like 'c31 (+9?0)' -and $p1.J.Spot -notlike '*c31 *' -and (@($p1.J.Issues) -join ' | ') -like '[[]tête 1] non convergée aux cylindres c31 (+9?0)') "NON CONVERGEE : NonConv $($p1.J.NCTxt) ; Spot '$($p1.J.Spot)' ; reserve « $(@($p1.J.Issues) -join ' | ') » : fenetre de decision (avant la revue : ecart local, tete convergee)"
"    P2. Meme cas avec une zone contradictoire c29-c30 au lieu du cylindre non reproductible c30"
$uP2 = New-CalibUnit 1
$rP2 = $resP.Clone(); $rP2[29] = 12.0; $rP2[30] = -12.0
Set-GState $uP2 $vP $rP2 @{} 5
$script:FxNR = @{}; $script:FxContra = @{ 29 = @{ Z = 79.0; E = 6.0 }; 30 = @{ Z = 80.0; E = 6.0 } }
$p2 = Invoke-G (New-GCal @($uP2) 8)
$p2.Lines
$sk2 = 'c31 (à 2 cylindres au plus de la zone non reproductible d''une vérification à l''autre (c29-30) ; Full False ; Lim False)'
Chk 'P2' ($p2.Skip -eq $sk2 -and $p2.Targets -eq '33,34,35,36' -and @($p2.PlanList -split ',') -notcontains '31' -and @($p2.Relus -split ',') -notcontains '31' -and $p2.RtFull -eq '31' -and $p2.J.NC -eq '31' -and $p2.J.Spot -notlike '*c31 *' -and (@($p2.J.Issues) -join ' | ') -like '[[]tête 1] non convergée aux cylindres c31 (+9?0)') "c31 exclu (zone c29-c30), ni reecrit ni relu : RtFull $($p2.RtFull) ; NonConv $($p2.J.NCTxt) ; reserve : fenetre de decision"
$script:FxNR = @{}; $script:FxContra = @{}
"    P3. Mesure complete (DiskOnly), deuxieme nouvel essai (Retests 1), WriteMax 11 : c39-c40 (+8) bornes par c41 (meme valeur 88 ns), valeur visee inchangee ; c42-c46 non converges ; RtFull = 12 laisse par le nouvel essai precedent (c12 dans la tolerance)"
$v3 = [int[]]$vP.Clone(); $v3[39] = 88; $v3[40] = 88; $v3[41] = 88
$uP3 = New-CalibUnit 1
Set-GState $uP3 $v3 @{ 39 = 8.0; 40 = 8.0; 41 = 0.0; 42 = 10.0; 43 = 10.0; 44 = 11.0; 45 = 12.0; 46 = 12.0 } @{} 6
$uP3.RtFull = [int[]]@(12)
$calP3 = New-GCal @($uP3) 11; $calP3.DiskOnly = $true; $calP3.Retests = 1; $calP3.VerifyCount = 3
$p3 = Invoke-G $calP3
$p3.Lines
$sk3 = 'c39,40 (valeur visée inchangée, bornée par les cylindres vérifiés voisins : aucun progrès ; Full False ; Lim False)'
Chk 'P3a' ($p3.Skip -eq $sk3 -and $p3.Targets -eq '42,43,44,45,46' -and $p3.Go -eq $true -and [int]$calP3.Retests -eq 2 -and @($p3.PlanList -split ',') -notcontains '39' -and @($p3.PlanList -split ',') -notcontains '40' -and $p3.RtFull -eq '12,39,40') "plan : c39-c40 exclus (valeur visee inchangee), cibles $($p3.Targets), deuxieme nouvel essai lance (Retests $($calP3.Retests)), relus du plan $($p3.PlanList) ; RtFull $($p3.RtFull) : union avec le nouvel essai precedent (c12)"
Chk 'P3b' ($p3.J.NC -eq '39,40' -and $p3.J.Spot -notlike '*c39 *' -and $p3.J.Spot -notlike '*c40 *' -and (@($p3.J.Issues) -join ' | ') -like '[[]tête 1] non convergée aux cylindres c39 (+8?0), c40 (+8?0)') "NON CONVERGEE : NonConv $($p3.J.NCTxt) (temoins de la passe : $($p3.Wit)) ; c12 dans la tolerance, sans effet ; reserve : fenetre de decision"

"--- M. Revue fix2 (C2) : deux unites (ecriture lente, une courbe par tete) ; seule la relecture du plan de la meme unite compte"
function Invoke-GM($cal) {
    # Invoke-G pour plusieurs unites : plan et Start-CalibRetest reels ; passe simulee unite par unite (cibles de l unite a
    # 0,5 x bruit, autres cylindres de son VerifyList a leur residu d avant) ; jugement final de chaque unite (Get-GJudge)
    $script:Cal = $cal; $script:RLog.Clear(); $script:NPass = 0
    $plan = Get-CalibRetestPlan $cal
    $go = Start-CalibRetest $cal
    $o = @{ Go = $go; NPass = $script:NPass; Log = @($script:RLog); H = @{}
            Skip = (@(@($plan.Skip) | ForEach-Object { "$($_.U.Prefix)c$(Format-Set $_.NonConv) ($($_.Why) ; Full $([bool]$_.Full) ; Lim $([bool]$_.Lim))" }) -join ' | ') }
    foreach ($u in @($cal.Units)) {
        $tg = @(); $pl = @()
        foreach ($p in @($plan.Go)) { if ([object]::ReferenceEquals($p.U, $u)) { $tg += @($p.Targets); $pl += @($p.List) } }
        $relus = [int[]]@(@($u.VerifyList) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
        foreach ($c in $relus) {
            $r = if ($tg -contains $c) { 0.5 * (Get-Noise $c) } else { [double]$u.Verify[$c].Shift }
            $u.Verify[$c] = @{ Shift = $r; SE = 0.5; Score = 40.0 }
            $u.VerifyP[$c] = [int]$u.Fit.Values[$c]
        }
        $o.H[[int]$u.Head] = @{ Targets = (Format-Set $tg); PlanList = (Format-Set $pl); Relus = (Format-Set $relus); RtFull = (Format-Set $u.RtFull); J = (Get-GJudge $u) }
    }
    $script:Cal = $null
    return $o
}
$uM0 = New-CalibUnit 0
Set-GState $uM0 $vA @{ 2 = -10.0; 3 = -10.0; 4 = -10.0 } @{} 5
$uM1 = New-CalibUnit 1
Set-GState $uM1 $vB @{ 3 = -11.0; 5 = -12.0; 6 = -12.0; 7 = -12.0; 8 = -12.0; 9 = -12.0 } @{} 5
$gm = Invoke-GM (New-GCal @($uM0, $uM1) 8)
"    plan : exclus $($gm.Skip) ; passe lancee $($gm.Go) ($($gm.NPass))"
foreach ($h in 0, 1) { $x = $gm.H[$h]; "    tete $h : cibles $($x.Targets) ; relus du plan $($x.PlanList) ; relus a la passe $($x.Relus) ; RtFull $($x.RtFull) ; jugement final : NonConv $(if ($x.J.NCTxt) { $x.J.NCTxt } else { '-' }) ; Spot $(if ($x.J.Spot) { $x.J.Spot } else { '-' })" }
foreach ($l in @($gm.Log)) { "    | $(if ($l.Length -gt 220) { $l.Substring(0, 220) + '...' } else { $l })" }
$m0 = $gm.H[0]; $m1 = $gm.H[1]
Chk 'M1' ($gm.Skip -eq '[tête 1] c3 (précompensation visée hors de ses limites (0 ou 400 ns) ; Full False ; Lim True)' -and $gm.Go -eq $true -and $gm.NPass -eq 1 -and $m0.Targets -eq '2,3,4' -and $m1.Targets -eq '5,6,7,8,9' -and @($m0.PlanList -split ',') -contains '3' -and @($m1.PlanList -split ',') -notcontains '3' -and $m1.RtFull -eq '3' -and $m0.RtFull -eq '-' -and $m1.J.NC -eq '3' -and $m1.J.NCTxt -like 'c3 (-11?0)' -and $m0.J.NC -eq '-') "c3 de la tete 1 exclu (Lim), relu au plan de la tete 0 ($($m0.PlanList)) mais pas a celui de la tete 1 ($($m1.PlanList)) : RtFull tete 1 $($m1.RtFull), tete 0 $($m0.RtFull) ; tete 1 NON CONVERGEE ($($m1.J.NCTxt)), tete 0 convergee"

Get-Cal2Bilan 'logic-129-cal2-retest'
"duree : $(F $sw.Elapsed.TotalSeconds '0') s"
exit $(if ($script:Fail) { 1 } else { 0 })
