param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : test porte dans le depot (nom dans la campagne hors depot : logic-1210-asym-d) : en-tete commun de commun.ps1, aucun
# chemin du poste, fichiers de travail sous tests\out.
# 12.10 (v1210\asym) : niveaux des passes par famille (Get-CalLevels, 240) et asymetrie de reference du lecteur (Get-TracksAsym,
# Get-UnitAsymRef, 240 ; Get-AsymRefTable, Get-AsymRefs, Set-TrackAsymRef, Get-TrackScore, 190). Fonctions reelles extraites par
# l arbre syntaxique (gen-1210-asym.ps1) ; constantes CalCoarse, CalLevelKLong (560). Courbes simulees dans $script:PrecompCurves.
# Aucun gw, aucune application, aucune fenetre.
# Relecture du CHANGELOG (09/11/2026) : copie adaptee de v1210\asym\logic-1210-asym.ps1, qui la remplace dans la campagne.
# Adapte : S6 (l asymetrie de reference, correction livree desactivee, passe des Ameliorations a « A savoir » sous
# « Asymetrie en long track »).
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$mods = Join-Path $Wt 'src\modules'
function Get-AsAst([string]$path) {
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
    if (@($er).Count) { throw "erreurs de syntaxe dans $path : $(@($er)[0].Message)" }
    return $ast
}
function Get-AsFn([string]$path, [string]$name) {
    foreach ($fd in (Get-AsAst $path).FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { if ($fd.Name -eq $name) { return $fd.Extent.Text } }
    throw "fonction $name introuvable dans $path"
}
function Get-AsAssign([string]$path, [string]$left) {
    $st = @((Get-AsAst $path).EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq $left })
    if ($st.Count -ne 1) { throw "affectation $left dans $path : $($st.Count)" }
    return $st[0].Extent.Text
}
$parts = New-Object System.Collections.Generic.List[string]
foreach ($n in 'Get-CalLevels', 'Get-TracksAsym', 'Get-UnitAsymRef') { $parts.Add((Get-AsFn (Join-Path $mods '240-fn-calib-mesure.ps1') $n)) }
foreach ($n in 'Get-TrackScore', 'Get-AsymRefTable', 'Get-AsymRefs', 'Set-TrackAsymRef') { $parts.Add((Get-AsFn (Join-Path $mods '190-fn-qualite-alignement.ps1') $n)) }
foreach ($k in 'CalCoarse', 'CalLevelKLong', 'QualAsymRefOn') { $parts.Add((Get-AsAssign (Join-Path $mods '560-etat-calibration.ps1') "`$script:$k")) }
$gen = Join-Path $here 'gen-1210-asym.ps1'
[System.IO.File]::WriteAllText($gen, ((@($parts) -join "`r`n`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
. $gen

$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    if (-not $ok) { $script:Fail++; $script:FailIds += $id }
    '{0,-8} {1,-12} {2}' -f $id, $(if ($ok) { 'conforme' } else { 'NON CONFORME' }), $d
}
"logic-1210-asym : CalCoarse $($script:CalCoarse -join '/'), CalLevelKLong $($script:CalLevelKLong) ; PowerShell $($PSVersionTable.PSVersion)"

"--- L : niveaux des passes par famille"
$ls = Get-CalLevels 'std'; $ll = Get-CalLevels 'long'; $lh = Get-CalLevels 'hd'
Chk 'L1' (($ls -join '/') -eq '0/30/100' -and ($lh -join '/') -eq '0/30/100') "standard et autres familles : $($ls -join '/')"
Chk 'L2' (($ll -join '/') -eq '0/60/200' -and $ll[2].GetType().Name -eq 'Int32') "long track : $($ll -join '/')"

"--- A : releve d asymetrie sur le motif relu"
function New-Rev([double]$r3, [double]$r4) { return [pscustomobject]@{ R3 = $r3; R4 = $r4; Jitter = 40.0; OutOfClass = 0.0; Dropouts = 0.0; Cell = 1888.0; NFlux = 40000 } }
$tracks = @{}
$tracks[0] = @((New-Rev 1.51 2.03), (New-Rev 1.53 2.03), (New-Rev 1.52 2.03))     # c0 tete 0 : +0,02 / +0,03
$tracks[1] = @((New-Rev 1.50 2.00))                                               # c0 tete 1 : 0 / 0
$tracks[158] = @((New-Rev 1.54 2.04), (New-Rev ([double]::NaN) 2.0))              # c79 tete 0 : tour NaN ignore : +0,04 / +0,04
$tracks[159] = @((New-Rev ([double]::NaN) ([double]::NaN)))                       # c79 tete 1 : sans valeur : absente
$ar = Get-TracksAsym $tracks
Chk 'A1' ($ar.Count -eq 3 -and -not $ar.ContainsKey(159) -and [math]::Abs($ar[0][0] - 0.02) -lt 1e-9 -and [math]::Abs($ar[0][1] - 0.03) -lt 1e-9 -and [math]::Abs($ar[158][0] - 0.04) -lt 1e-9) "pistes relevees $($ar.Count) ; c0 t0 $($ar[0][0]) / $($ar[0][1]) ; c79 t0 $($ar[158][0])"
$cal = @{ AsymRef = $ar }
$u0 = Get-UnitAsymRef $cal @{ Head = 0 }; $u1 = Get-UnitAsymRef $cal @{ Head = 1 }; $uc = Get-UnitAsymRef $cal @{ Head = $null }
Chk 'A2' (($u0.Cyl -join ',') -eq '0,79' -and [math]::Abs($u0.D3[1] - 0.04) -lt 1e-9 -and ($u1.Cyl -join ',') -eq '0' -and $u1.D3[0] -eq 0.0) "tete 0 : c$($u0.Cyl -join ',c') ; tete 1 : c$($u1.Cyl -join ',c')"
Chk 'A3' (($uc.Cyl -join ',') -eq '0,79' -and [math]::Abs($uc.D3[0] - 0.01) -lt 1e-9 -and [math]::Abs($uc.D4[0] - 0.015) -lt 1e-9 -and [math]::Abs($uc.D3[1] - 0.04) -lt 1e-9) "unite commune : moyenne des tetes c0 $($uc.D3[0]) / $($uc.D4[0]), c79 tete 0 seule $($uc.D3[1])"
$ue = Get-UnitAsymRef @{ AsymRef = $null } @{ Head = 0 }
Chk 'A4' ($ue.Cyl.Count -eq 0 -and $ue.D3.Count -eq 0) 'sans releve : tableaux vides'

"--- R : reference par famille, tete et lecteur"
$script:PrecompCurves = @{
    'long_h0' = @{ Drive = '0'; AsymCyl = [int[]]@(0, 40, 79); AsymD3 = [double[]]@(0.02, 0.025, 0.04); AsymD4 = [double[]]@(0.03, 0.03, 0.045) }
    'long_h1' = @{ Drive = 'A'; AsymCyl = [int[]]@(0); AsymD3 = [double[]]@(0.01); AsymD4 = [double[]]@(0.01) }   # autre lecteur
    'long'    = @{ Drive = '0'; AsymCyl = [int[]]@(0, 79); AsymD3 = [double[]]@(0.015, 0.045); AsymD4 = [double[]]@(0.02, 0.05) }
    'std'     = @{ Drive = '0'; Values = [int[]]@(60) }                                                          # courbe 12.9 sans releve
}
$t0 = Get-AsymRefTable 'long' 0 '0'; $t1 = Get-AsymRefTable 'long' 1 '0'; $ts = Get-AsymRefTable 'std' 0 '0'; $tx = Get-AsymRefTable 'long' 0 'A'
Chk 'R1' ($null -ne $t0 -and $t0.Count -eq 3 -and [math]::Abs($t0[40][0] - 0.025) -lt 1e-9) "courbe par tete : $($t0.Count) cylindres, c40 $($t0[40][0]) / $($t0[40][1])"
Chk 'R2' ($null -ne $t1 -and $t1.Count -eq 2 -and [math]::Abs($t1[79][1] - 0.05) -lt 1e-9) "tete 1 : courbe par tete d un autre lecteur ignoree, courbe commune du lecteur 0 : $($t1.Count) cylindres"
Chk 'R3' ($null -eq $ts -and $null -eq $tx) 'courbe sans releve (12.9) et lecteur sans courbe : aucune reference'
$refs = Get-AsymRefs '0'
Chk 'R4' ($refs.Count -eq 4 -and $null -ne $refs['long0'] -and $null -ne $refs['long1'] -and $null -eq $refs['std0'] -and $null -eq $refs['std1']) "references du lecteur 0 : $(($refs.Keys | Sort-Object) -join ' ') ; long0 $(if ($refs['long0']) { 'oui' } else { 'non' }), std0 $(if ($refs['std0']) { 'oui' } else { 'non' })"

"--- C : correction d une piste"
function New-M([double]$r3, [double]$r4, [double]$cell, [double]$j = 70.0) {
    $m = @{ Bad = $false; Missing = $false; J = $j; R3 = $r3; R4 = $r4; Ooc = 1.0; Dr = 0.0; Cell = $cell; Stab = 0.0; Asym = 0.0; Score = 9999; Level = 0 }
    $m.Asym = [math]::Abs($r3 - 1.5) + [math]::Abs($r4 - 2.0); $m.Score = Get-TrackScore $m
    return $m
}
$m = New-M 1.539 2.041 1875.0 91.0            # c79 tete 1 de l export du 02/11 : +0,039 / +0,041, jitter 91, score 252
$s0 = $m.Score
# C0 : livree desactivee (QualAsymRefOn faux, 560 : constat du 02/11/2026 au soir) : aucune correction, piste inchangee
$ok0 = Set-TrackAsymRef $m 79 1 $refs
Chk 'C0' ($script:QualAsymRefOn -eq $false -and -not $ok0 -and $m.Score -eq $s0 -and -not $m.ContainsKey('AsymRef')) "desactivee par defaut (QualAsymRefOn $($script:QualAsymRefOn)) : rien ne change, score $($m.Score)"
$script:QualAsymRefOn = $true                   # cas suivants : correction activee
$ok = Set-TrackAsymRef $m 79 1 $refs
Chk 'C1' ($ok -and $s0 -eq 256 -and [math]::Abs($m.AsymRaw - 0.080) -lt 1e-9 -and [math]::Abs($m.Asym - 0.015) -lt 1e-9 -and $m.Score -eq 126 -and $m.AsymRef[0] -eq 0.045) "long track c79.1 : asymetrie 0,080 -> $($m.Asym) (reference commune 0,045 / 0,05), score $s0 -> $($m.Score)"
$m2 = New-M 1.52 2.03 1888.0
$ok2 = Set-TrackAsymRef $m2 0 0 $refs
Chk 'C2' ($ok2 -and [math]::Abs($m2.Asym) -lt 1e-9 -and $m2.Score -eq [math]::Round(70 + 5, 0)) "c0.0 egal a sa reference : asymetrie 0, score $($m2.Score)"
$m3 = New-M 1.52 2.03 2000.0; $ok3 = Set-TrackAsymRef $m3 0 0 $refs
Chk 'C3' (-not $ok3 -and [math]::Abs($m3.Asym - 0.05) -lt 1e-9 -and -not $m3.ContainsKey('AsymRef')) "standard (cellule 2000) sans reference 12.10 : inchangee $($m3.Asym)"
$m4 = New-M 1.52 2.03 1000.0; $ok4 = Set-TrackAsymRef $m4 0 0 $refs
$m5 = New-M 1.52 2.03 1888.0; $ok5 = Set-TrackAsymRef $m5 50 0 $refs
$m6 = New-M 1.52 2.03 1888.0; $m6.Bad = $true; $ok6 = Set-TrackAsymRef $m6 0 0 $refs
Chk 'C4' (-not $ok4 -and -not $ok5 -and -not $ok6 -and -not (Set-TrackAsymRef $m5 0 0 $null)) 'haute densite, cylindre sans reference, piste illisible, sans references : rien'

"--- S : cablage"
$s270 = [System.IO.File]::ReadAllText((Join-Path $mods '270-fn-calib-complete.ps1'))
Chk 'S1' (-not $s270.Contains('$lv = Get-CalLevels') -and $s270.Contains('MaxCoarse = [int](@(Get-CalLevels $family) | Measure-Object -Maximum).Maximum;') -and $s270.Contains("Values = @(Get-CalLevels `$family); Index = 0;") -and $s270.Contains('$cal.MaxCoarse = [int](@($cal.Values) | Measure-Object -Maximum).Maximum') -and -not $s270.Contains('Values = @($script:CalCoarse)')) 'niveaux de la famille dans le litteral de la creation (sans variable locale : bancs) et a l encadrement'
Chk 'S2' ($s270.Contains('([double]$script:CalVOffMaxNs) ([double]$cal.MaxCoarse)') -and $s270.Contains('Get-VerifySlope $u ([double]$cal.MaxCoarse) ([int]$script:CalSlopeMinCyl)')) 'niveau maximal de la famille passe au decalage commun et a la pente'
Chk 'S3' ($s270.Contains('$null -eq $cal.AsymRef) { $cal.AsymRef = Get-TracksAsym $tracks }') -and $s270.Contains('$asym = Get-UnitAsymRef $cal $u') -and $s270.Contains('AsymCyl = [int[]]@($asym.Cyl); AsymD3 = [double[]]@($asym.D3); AsymD4 = [double[]]@($asym.D4)')) 'releve a la verification 1, champs de la courbe'
$s190 = [System.IO.File]::ReadAllText((Join-Path $mods '190-fn-qualite-alignement.ps1'))
$s170 = [System.IO.File]::ReadAllText((Join-Path $mods '170-fn-controle-ecriture.ps1'))
Chk 'S4' ($s190.Contains('if (Set-TrackAsymRef $m $cyl $hd $arefs) { $nRef++ }') -and $s190.Contains('$m.Score = Get-TrackScore $m') -and $s190.Contains("(T 'Asymétrie'), ((T ") -and ([regex]::Matches($s170, '\[void\]\(Set-TrackAsymRef')).Count -eq 2) 'onglet Qualite, export et controle (2 appels, hors commentaire)'
$keys = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in (Get-ChildItem -LiteralPath $mods -Filter '01*-i18n*.ps1')) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\[`"([^`"]*)`"\]")) { [void]$keys.Add($mm.Groups[1].Value) }
    foreach ($mm in [regex]::Matches($t, "\`$script:I18n\['((?:[^']|'')*)'\]")) { [void]$keys.Add($mm.Groups[1].Value.Replace("''", "'")) }
}
Chk 'S5' ($keys.Contains("Mesure : asymétrie et score corrigés du biais de lecture du lecteur {0} sur {1} piste(s), d'après le motif de sa calibration (famille d'après la cellule mesurée).") -and $keys.Contains('Asymétrie') -and $keys.Contains("corrigée du biais de lecture du lecteur sur {0} piste(s), d'après le motif de sa calibration")) 'textes anglais des trois cles'
$ch = [System.IO.File]::ReadAllText((Join-Path $Wt 'CHANGELOG.md'))
Chk 'S6' ($ch.Contains('**Niveaux de mesure proportionnés à la famille.**') -and -not $ch.Contains('**Asymétrie corrigée du biais de lecture.**') -and $ch.Contains('- **Asymétrie en long track.**') -and $ch.IndexOf('- **Asymétrie en long track.**') -gt $ch.IndexOf('### À savoir pour la mise à jour') -and $ch.IndexOf('- **Asymétrie en long track.**') -lt $ch.IndexOf('### Pour les développeurs') -and $ch.Contains('cette correction est livrée désactivée') -and $ch.Contains('valeur livrée : correction désactivée') -and $ch.Contains('`Get-CalLevels($family)`') -and $ch.Contains('`Set-TrackAsymRef($m, $cyl, $hd, $refs)`')) 'CHANGELOG : deux ameliorations et notes developpeurs'

$nk = if ($script:Fail) { ' ; non conformes : ' + (@($script:FailIds) -join ', ') } else { '' }
"=== bilan logic-1210-asym-d : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
