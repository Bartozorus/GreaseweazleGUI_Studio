param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
. (Join-Path $PSScriptRoot 'commun.ps1')
$Wt = Get-TestRoot $Wt
# 12.11 : verdicts du lanceur tests\Run-Tests.ps1. Une copie du lanceur est placee dans une arborescence factice du
# dossier de travail, a cote de tests factices ecrits par ce test ; elle est lancee comme le lanceur lance un test (un
# processus de la meme edition, -NoProfile -File), avec -NoChecks. Controles : code de sortie, ligne de l etape, ligne de
# fin, fichiers de sortie.
#  L1 cas non conforme (code 1) ; L2 erreur avant le bilan ; L3 code 0 sans bilan (faux vert ecarte : « bilan absent ») ;
#  L4 test conforme avec une ligne « saute » (comptee) ; L5 code 1 malgre un bilan conforme ; L5b ligne de bilan
#  precedee d une marque d ordre des octets (sortie UTF-8 sous Windows PowerShell 5.1) : lue quand meme ; L6 filtre sans
#  test ; L7 ensemble : sommes, nombre d echecs, tests.log et sorties par etape ; L8 marque d alerte du poste (code 9,
#  arret immediat), reserve a la CI : sur le poste de developpement, aucune sortie ne doit contenir la marque.
# Les sorties du lanceur factice ne sont pas recopiees ici (elles contiennent des lignes de bilan et « saute » qui
# fausseraient le decompte de ce test) : elles sont ecrites dans le dossier de travail (L1.txt, L2.txt...).
# Aucun gw, aucune fenetre.
$here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:NChk = 0; $script:Fail = 0; $script:FailIds = @()
function Chk([string]$id, [bool]$ok, [string]$d) {
    $script:NChk++
    $v = 'conforme'; if (-not $ok) { $script:Fail++; $script:FailIds += $id; $v = 'NON CONFORME' }
    '{0,-8} {1,-12} {2}' -f $id, $v, $d
}
$exeName = 'powershell.exe'; if ($PSVersionTable.PSEdition -eq 'Core') { $exeName = 'pwsh.exe' }
$exe = Join-Path $PSHOME $exeName
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------- arborescence factice
$fx = Join-Path $here 'faux'
if (Test-Path -LiteralPath $fx) { Remove-Item -LiteralPath $fx -Recurse -Force }
[void](New-Item -ItemType Directory -Path $fx)
$run = Join-Path $fx 'Run-Tests.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Run-Tests.ps1') -Destination $run
$head = "param([string]`$Wt = '', [string]`$Wiki = '', [string]`$Work = '', [switch]`$Ci)"
function Set-FakeTest([string]$name, [string[]]$body) {
    [System.IO.File]::WriteAllText((Join-Path $fx "logic-$name.ps1"), ((@($head) + $body) -join "`r`n") + "`r`n", $utf8Bom)
}
Set-FakeTest 'a-echec' @("'A1       conforme     cas factice'", "'A2       NON CONFORME cas factice'", "'=== bilan logic-a-echec : 1 conformes sur 2 ; non conformes : A2'", 'exit 1')
Set-FakeTest 'b-erreur' @("'B1       conforme     cas factice'", "throw 'erreur volontaire avant le bilan'")
Set-FakeTest 'c-faux-vert' @("'sortie sans bilan, code 0'", 'exit 0')
Set-FakeTest 'd-ok' @("'D1       conforme     cas factice'", "'  D2 saute (cas factice)'", "'=== bilan logic-d-ok : 3 conformes sur 3'", 'exit 0')
Set-FakeTest 'e-code' @("'=== bilan logic-e-code : 2 conformes sur 2'", 'exit 1')
Set-FakeTest 'f-bom' @("'F1       conforme     cas factice'", "([string][char]0xFEFF) + '=== bilan logic-f-bom : 1 conformes sur 1'", 'exit 0')
$script:NRun = 0
function Invoke-Launcher([string]$filter, [string]$outName) {
    # Lance la copie du lanceur ; rend le code de sortie, les lignes et le dossier des sorties
    $script:NRun++
    $o = Join-Path $fx $outName
    $a = @('-Root', $Wt, '-NoChecks', '-Filter', $filter, '-Out', $o)
    $ErrorActionPreference = 'Continue'
    $lines = @(& $exe -NoProfile -File $run @a 2>&1 | ForEach-Object { "$_" })
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    [System.IO.File]::WriteAllLines((Join-Path $here ("L$($script:NRun).txt")), [string[]]$lines, $utf8)
    return @{ Rc = $rc; Lines = $lines; Out = $o }
}
function Get-N($r, [string]$rx) { return @($r.Lines | Where-Object { $_ -match $rx }).Count }
"logic-lanceur : copie de Run-Tests.ps1 et 6 tests factices sous $fx ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

$r = Invoke-Launcher 'a-*' 'out-a'
Chk 'L1' ($r.Rc -eq 1 -and (Get-N $r '^logic-a-echec\s+ECHEC rc=1 .*1 conformes sur 2') -eq 1 -and (Get-N $r '^\s+\| A2\s+NON CONFORME') -eq 1 -and (Get-N $r '^fin : 1 etape\(s\) ; 1 conformes sur 2 ; .* ECHEC : 1 etape\(s\)$') -eq 1) "cas non conforme : code $($r.Rc) (1 attendu), etape en echec, cas non conforme repris dans le journal, ligne de fin"
$r = Invoke-Launcher 'b-*' 'out-b'
Chk 'L2' ($r.Rc -eq 1 -and (Get-N $r '^logic-b-erreur\s+ECHEC rc=1 .*bilan absent : ') -eq 1 -and (Get-N $r 'TOUT VERT') -eq 0) "erreur avant le bilan : code $($r.Rc) (1 attendu), « bilan absent »"
$r = Invoke-Launcher 'c-*' 'out-c'
Chk 'L3' ($r.Rc -eq 1 -and (Get-N $r '^logic-c-faux-vert\s+ECHEC rc=0 .*bilan absent : sortie sans bilan, code 0') -eq 1 -and (Get-N $r 'TOUT VERT') -eq 0) "code 0 sans ligne de bilan : code $($r.Rc) (1 attendu), « bilan absent » : pas de faux vert"
$r = Invoke-Launcher 'd-*' 'out-d'
Chk 'L4' ($r.Rc -eq 0 -and (Get-N $r '^logic-d-ok\s+ok\s+rc=0 .*3 conformes sur 3 ; lignes saute : 1$') -eq 1 -and (Get-N $r '^fin : 1 etape\(s\) ; 3 conformes sur 3 ; lignes saute : 1 ; .* TOUT VERT$') -eq 1) "test conforme avec un cas passe : code $($r.Rc) (0 attendu), saut compte, « TOUT VERT »"
$r = Invoke-Launcher 'e-*' 'out-e'
Chk 'L5' ($r.Rc -eq 1 -and (Get-N $r '^logic-e-code\s+ECHEC rc=1 .*2 conformes sur 2') -eq 1) "code 1 malgre un bilan conforme : code $($r.Rc) (1 attendu), etape en echec"
$r = Invoke-Launcher 'f-*' 'out-f'
Chk 'L5b' ($r.Rc -eq 0 -and (Get-N $r '^logic-f-bom\s+ok\s+rc=0 .*1 conformes sur 1$') -eq 1) "ligne de bilan precedee d une marque d ordre des octets : code $($r.Rc) (0 attendu), bilan lu"
$r = Invoke-Launcher 'zz*' 'out-z'
Chk 'L6' ($r.Rc -eq 1 -and (Get-N $r '^aucune etape \(filtre zz\*\)$') -eq 1) "filtre sans test : code $($r.Rc) (1 attendu), « aucune etape »"
$r = Invoke-Launcher '*' 'out-tous'
$logFile = Join-Path $r.Out 'tests.log'
# Comparaison sur les caracteres ASCII : le texte d une erreur de PowerShell (accents) depend du codage de la console
$ascii = '[^\x20-\x7E]'
$logOk = (Test-Path -LiteralPath $logFile) -and (((@([System.IO.File]::ReadAllLines($logFile)) -join "`n") -replace $ascii, '?') -eq ((@($r.Lines) -join "`n") -replace $ascii, '?'))
$outs = @('logic-a-echec', 'logic-b-erreur', 'logic-c-faux-vert', 'logic-d-ok', 'logic-e-code', 'logic-f-bom' | Where-Object { Test-Path -LiteralPath (Join-Path $r.Out "$_.txt") })
$dOut = ''; if ($outs -contains 'logic-d-ok') { $dOut = [System.IO.File]::ReadAllText((Join-Path $r.Out 'logic-d-ok.txt')) }
Chk 'L7' ($r.Rc -eq 1 -and (Get-N $r '^fin : 6 etape\(s\) ; 7 conformes sur 8 ; lignes saute : 1 ; .* ECHEC : 4 etape\(s\)$') -eq 1 -and $logOk -and $outs.Count -eq 6 -and $dOut.Contains('=== bilan logic-d-ok : 3 conformes sur 3')) "ensemble : code $($r.Rc) (1 attendu), 6 etapes, 7 conformes sur 8, 4 echecs ; tests.log identique a la sortie ($logOk) ; $($outs.Count) sorties par etape (6 attendues)"

if (-not $Ci) { '  L8 saute (marque d alerte du poste : jouee par la CI seulement, -Ci)' }
else {
    # Marque en deux morceaux, comme dans le lanceur : ce fichier ne la contient pas
    $mark = 'ALERTE' + ' EDR'
    Set-FakeTest 'c-alerte' @("'sortie avec la marque : $mark (factice)'", "'=== bilan logic-c-alerte : 1 conformes sur 1'", 'exit 0')
    $r = Invoke-Launcher '[c-d]-*' 'out-alerte'
    $nMark = @($r.Lines | Where-Object { $_ -like "*$mark dans logic-c-alerte : arret*" }).Count
    Chk 'L8' ($r.Rc -eq 9 -and $nMark -eq 1 -and (Get-N $r '^logic-c-faux-vert') -eq 0 -and (Get-N $r '^logic-d-ok') -eq 0 -and (Get-N $r '^fin : ') -eq 0 -and (Test-Path -LiteralPath (Join-Path $r.Out 'tests.log'))) "marque d alerte dans une sortie : code $($r.Rc) (9 attendu), arret immediat (etapes suivantes non lancees), journal ecrit"
}

$nk = ''; if ($script:Fail) { $nk = ' ; non conformes : ' + (@($script:FailIds) -join ', ') }
"=== bilan logic-lanceur : $($script:NChk - $script:Fail) conformes sur $($script:NChk)$nk ; $([int]$sw.Elapsed.TotalSeconds) s"
if ($script:Fail) { exit 1 }
exit 0
