# Fonctions communes des tests logiques du depot (tests\logic-*.ps1). Chaque test commence par :
#     param([string]$Wt = '', [string]$Wiki = '', [string]$Work = '', [switch]$Ci)
#     . (Join-Path $PSScriptRoot 'commun.ps1')
#     $Wt = Get-TestRoot $Wt
#     $here = Get-TestWorkDir $MyInvocation.MyCommand.Path $Work
# -Wt : racine du depot a tester (defaut : le depot du test) ; -Wiki : copie locale du wiki (controles des pages sautes sans
# elle) ; -Work : dossier de travail (defaut : tests\out\<nom du test>, ignore par git) ; -Ci : lance par la CI.
# Ces quatre noms sont des parametres types : un test ne s en sert pas comme variables locales.
# Compatible Windows PowerShell 5.1 et PowerShell 7. Aucun gw, aucune fenetre, aucune compilation.
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Set-TestCulture([string]$name = 'fr-FR') {
    # Le poste de developpement est en fr-FR, le runner GitHub en en-US : chaque test fixe sa culture
    $c = [System.Globalization.CultureInfo]::GetCultureInfo($name)
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $c
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = $c
}

function Get-TestRoot([string]$wt) {
    if (-not $wt) { $wt = Split-Path -Parent $PSScriptRoot }
    if (-not (Test-Path -LiteralPath (Join-Path $wt 'src\modules\000-entete.ps1'))) { throw "modules introuvables sous $wt" }
    return (Resolve-Path -LiteralPath $wt).ProviderPath
}

function Get-TestWorkDir([string]$testPath, [string]$work = '') {
    # Fichiers generes, images factices et rapports du test : jamais a cote des tests
    if (-not $work) { $work = Join-Path (Join-Path $PSScriptRoot 'out') ([System.IO.Path]::GetFileNameWithoutExtension($testPath)) }
    if (-not (Test-Path -LiteralPath $work)) { [void](New-Item -ItemType Directory -Path $work -Force) }
    return (Resolve-Path -LiteralPath $work).ProviderPath
}

function Import-TestWinForms {
    # System.Windows.Forms et System.Drawing sans Add-Type. Sous .NET Framework (Windows PowerShell 5.1), Assembly.Load
    # ne cherche pas un nom court dans le GAC : LoadWithPartialName y est la forme qui convient.
    foreach ($n in 'System.Windows.Forms', 'System.Drawing') {
        if ($PSVersionTable.PSEdition -eq 'Core') { [void][System.Reflection.Assembly]::Load($n) }
        else {
            $a = [System.Reflection.Assembly]::LoadWithPartialName($n)
            if ($null -eq $a) { throw "assembly $n introuvable" }
        }
    }
}

Set-TestCulture
