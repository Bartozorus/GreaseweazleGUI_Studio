<#
.SYNOPSIS
    Controles de la source et tests logiques hors ligne de Greaseweazle Studio.

.DESCRIPTION
    Lance, un processus par etape, avec l edition de PowerShell qui execute ce script :
      1. tools\Assemble-Source.ps1 -Check (fichier assemble a jour) ;
      2. tests\check-source.ps1 (encodage, analyse syntaxique, constructions interdites, blocs Add-Type, cles I18n) ;
      3. chaque tests\logic-*.ps1, par ordre de nom (fonctions reelles des modules, bouchons pour le reste).
    Aucun gw, aucun materiel, aucune fenetre. Sorties dans tests\out (ignore par git) : <etape>.txt et tests.log.
    Une etape reussit si son code de sortie est 0 et, pour un test, si sa derniere ligne « === bilan ... : N conformes
    sur M » compte autant de cas conformes que de cas. Un code 0 sans ligne de bilan est un echec (« bilan absent »).
    Code de sortie : 0 tout est conforme, 1 sinon, 9 si une sortie contient la marque d alerte du poste (arret immediat).
    Compatible Windows PowerShell 5.1 (CI) et PowerShell 7.

.PARAMETER Root
    Depot a tester. Par defaut : le dossier parent de tests.

.PARAMETER Filter
    Nom des tests a lancer, sans le prefixe logic-, jokers admis (exemple : 'calib-*').

.PARAMETER Out
    Dossier des sorties. Par defaut : tests\out.

.PARAMETER Wiki
    Copie locale du wiki : active les cas qui controlent ses pages (sautes sans elle).

.PARAMETER NoChecks
    Tests seuls, sans les etapes 1 et 2.

.PARAMETER Ci
    Lance par la CI : active les cas reserves au runner (compilation des blocs C#, marque d alerte).

.EXAMPLE
    pwsh -NoProfile -File tests\Run-Tests.ps1

.EXAMPLE
    pwsh -NoProfile -File tests\Run-Tests.ps1 -Filter 'calib-*' -NoChecks
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$Filter = '*',
    [string]$Out = '',
    [string]$Wiki = '',
    [switch]$NoChecks,
    [switch]$Ci
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $here }
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
if (-not $Out) { $Out = Join-Path $here 'out' }
if (-not (Test-Path -LiteralPath $Out)) { [void](New-Item -ItemType Directory -Path $Out -Force) }
$Out = (Resolve-Path -LiteralPath $Out).ProviderPath
if ($Wiki) {
    if (-not (Test-Path -LiteralPath $Wiki -PathType Container)) { throw "copie du wiki introuvable : $Wiki" }
    $Wiki = (Resolve-Path -LiteralPath $Wiki).ProviderPath
}
$exeName = 'powershell.exe'; if ($PSVersionTable.PSEdition -eq 'Core') { $exeName = 'pwsh.exe' }
$exe = Join-Path $PSHOME $exeName
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ansi = [string][char]27 + '\[[0-9;]*m'
# Marque d ordre des octets qu une sortie en UTF-8 peut porter (Windows PowerShell 5.1) : retiree avant l analyse
$bomChar = [string][char]0xFEFF
# Marque ecrite par les outils du poste de developpement quand sa protection bloque une etape ; en deux morceaux, pour
# qu une recherche de la marque dans le depot ou dans une sortie ne trouve jamais ce script
$mark = 'ALERTE' + ' EDR'
$log = New-Object System.Collections.Generic.List[string]
function Write-Line([string]$s) { $log.Add($s); $s }
function Save-Log { [System.IO.File]::WriteAllLines((Join-Path $Out 'tests.log'), [string[]]$log.ToArray(), $utf8) }
$total = [System.Diagnostics.Stopwatch]::StartNew()
Write-Line "tests : $Root ; $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion) ; sorties : $Out"

$steps = New-Object System.Collections.Generic.List[object]
if (-not $NoChecks) {
    $steps.Add(@{ Name = 'assemblage'; File = (Join-Path $Root 'tools\Assemble-Source.ps1'); Args = @('-Root', $Root, '-Check'); Bilan = $false })
    $steps.Add(@{ Name = 'source'; File = (Join-Path $here 'check-source.ps1'); Args = @('-Root', $Root); Bilan = $true })
}
foreach ($f in @(Get-ChildItem -LiteralPath $here -Filter 'logic-*.ps1' -File | Sort-Object Name)) {
    if ($f.BaseName.Substring(6) -notlike $Filter) { continue }
    $a = @('-Wt', $Root, '-Work', (Join-Path $Out $f.BaseName))
    if ($Wiki) { $a += @('-Wiki', $Wiki) }
    if ($Ci) { $a += '-Ci' }
    $steps.Add(@{ Name = $f.BaseName; File = $f.FullName; Args = $a; Bilan = $true })
}
if ($steps.Count -eq 0) { Write-Line "aucune etape (filtre $Filter)"; Save-Log; exit 1 }

$nFail = 0; $sumOk = 0; $sumAll = 0; $nSkip = 0
foreach ($s in $steps) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $a = @($s.Args)
    # 'Continue' : sous Windows PowerShell 5.1, une ligne ecrite sur la sortie d erreur d un programme, reprise par 2>&1,
    # arrete le script quand la preference est 'Stop'
    $ErrorActionPreference = 'Continue'
    $lines = @(& $exe -NoProfile -File $s.File @a 2>&1 | ForEach-Object { "$_" })
    $rc = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    [System.IO.File]::WriteAllLines((Join-Path $Out ($s.Name + '.txt')), [string[]]$lines, $utf8)
    if (@($lines | Where-Object { $_ -like "*$mark*" }).Count -gt 0) { Write-Line "$mark dans $($s.Name) : arret"; Save-Log; exit 9 }
    $clean = @($lines | ForEach-Object { [regex]::Replace($_, $ansi, '').Replace($bomChar, '') } | Where-Object { $_.Trim() })
    $bil = [string](@($clean | Where-Object { $_ -match '^=== bilan ' }) | Select-Object -Last 1)
    $ok = ($rc -eq 0); $why = ''
    if ($s.Bilan) {
        $m = [regex]::Match($bil, '(\d+) conformes sur (\d+)')
        if (-not $m.Success) { $ok = $false; $why = 'bilan absent : ' + ((@($clean | Select-Object -Last 3) | ForEach-Object { $_.Trim() }) -join ' | ') }
        else {
            $sumOk += [int]$m.Groups[1].Value; $sumAll += [int]$m.Groups[2].Value
            if ($m.Groups[1].Value -ne $m.Groups[2].Value) { $ok = $false }
        }
    }
    $sk = @($clean | Where-Object { $_ -match '\bsaute' }).Count; $nSkip += $sk
    if (-not $ok) { $nFail++ }
    $txt = $bil
    if ($why) { $txt = $why } elseif (-not $txt) { $txt = [string](@($clean) | Select-Object -Last 1) }
    if ($txt.Length -gt 150) { $txt = $txt.Substring(0, 150) }
    $verdict = 'ok'; if (-not $ok) { $verdict = 'ECHEC' }
    $skTxt = ''; if ($sk) { $skTxt = " ; lignes saute : $sk" }
    Write-Line ('{0,-38} {1,-5} rc={2} {3,4:0} s  {4}{5}' -f $s.Name, $verdict, $rc, $sw.Elapsed.TotalSeconds, $txt.Trim(), $skTxt)
    if (-not $ok) {
        # Detail d un echec dans le journal (lisible dans la sortie de la CI sans ouvrir les fichiers) : cas non conformes,
        # sinon fin de la sortie
        $det = @($clean | Where-Object { $_ -cmatch 'NON CONFORME' -and $_ -notmatch '^=== bilan ' } | Select-Object -First 12)
        if ($det.Count -eq 0) { $det = @($clean | Select-Object -Last 8) }
        foreach ($d in $det) { $d1 = $d.Trim(); if ($d1.Length -gt 300) { $d1 = $d1.Substring(0, 300) + '...' }; Write-Line "      | $d1" }
    }
}
$end = 'TOUT VERT'; if ($nFail) { $end = "ECHEC : $nFail etape(s)" }
Write-Line ('fin : {0} etape(s) ; {1} conformes sur {2} ; lignes saute : {3} ; {4:0} s ; {5}' -f $steps.Count, $sumOk, $sumAll, $nSkip, $total.Elapsed.TotalSeconds, $end)
Save-Log
if ($nFail) { exit 1 }
exit 0
