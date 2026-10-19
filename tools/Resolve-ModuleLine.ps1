<#
.SYNOPSIS
    Convertit une ligne de src\GreaseweazleGUI.ps1 en module:ligne, ou l inverse, d apres src\GreaseweazleGUI.map.json.

.DESCRIPTION
    Les messages de PowerShell, de PS2EXE et du banc de test donnent les lignes du fichier assemble. Les modifications se
    font dans src\modules : ce script donne le module et la ligne correspondants, ou la ligne assemblee d une ligne de
    module. Il signale une table qui ne correspond plus au fichier assemble (lancer alors tools\Assemble-Source.ps1).

.PARAMETER Line
    Une ou plusieurs lignes de src\GreaseweazleGUI.ps1.

.PARAMETER Module
    Nom du module, avec ou sans .ps1, ou son seul numero d ordre (par exemple 200).

.PARAMETER At
    Une ou plusieurs lignes du module.

.EXAMPLE
    pwsh -NoProfile -File tools\Resolve-ModuleLine.ps1 -Line <N>[,<N2>...]
    GreaseweazleGUI.ps1:<N> -> <module>.ps1:<ligne du module>

.EXAMPLE
    pwsh -NoProfile -File tools\Resolve-ModuleLine.ps1 -Module 500 -At 22
    500-fenetre-theme.ps1:22 -> GreaseweazleGUI.ps1:<N>
    Les lignes du fichier assemble changent a chaque reassemblage qui ajoute ou retire des lignes : citer le module et
    sa ligne, jamais une ligne assemblee.
#>
[CmdletBinding(DefaultParameterSetName = 'Line')]
param(
    [Parameter(ParameterSetName = 'Line', Mandatory = $true, Position = 0)][string[]]$Line,
    [Parameter(ParameterSetName = 'Module', Mandatory = $true)][string]$Module,
    [Parameter(ParameterSetName = 'Module', Mandatory = $true)][string[]]$At,
    [string]$Root = ''
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$mapPath = Join-Path $Root 'src\GreaseweazleGUI.map.json'
$srcPath = Join-Path $Root 'src\GreaseweazleGUI.ps1'
if (-not (Test-Path -LiteralPath $mapPath)) { throw "Table introuvable : $mapPath (lancez tools\Assemble-Source.ps1)" }
function ConvertTo-LineList([string[]]$Items) {
    # liste '1,40 9643' admise aussi par pwsh -File, qui passe le texte tel quel
    return @($Items | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ } | ForEach-Object { [int]$_ })
}
$map = [System.IO.File]::ReadAllText($mapPath) | ConvertFrom-Json
$mods = @($map.modules)

if (Test-Path -LiteralPath $srcPath) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { $sha = ([System.BitConverter]::ToString($h.ComputeHash([System.IO.File]::ReadAllBytes($srcPath))) -replace '-', '').ToLowerInvariant() }
    finally { $h.Dispose() }
    if ($sha -ne $map.sha256) { Write-Warning 'src\GreaseweazleGUI.ps1 ne correspond pas à la table : lignes peut-être décalées. Lancez tools\Assemble-Source.ps1.' }
}

if ($PSCmdlet.ParameterSetName -eq 'Line') {
    foreach ($l in (ConvertTo-LineList $Line)) {
        $m = @($mods | Where-Object { $l -ge $_.first -and $l -le $_.last }) | Select-Object -First 1
        if ($m) { 'GreaseweazleGUI.ps1:{0} -> {1}:{2}' -f $l, $m.file, ($l - $m.first + 1) }
        else { 'GreaseweazleGUI.ps1:{0} -> hors du fichier ({1} lignes)' -f $l, $map.lines }
    }
} else {
    $key = $Module -replace '\.ps1$', ''
    $m = @($mods | Where-Object { ($_.file -replace '\.ps1$', '') -eq $key -or $_.file -like "$key-*" }) | Select-Object -First 1
    if (-not $m) { throw "Module inconnu : $Module (modules : $(@($mods | ForEach-Object { $_.file }) -join ', '))" }
    foreach ($a in (ConvertTo-LineList $At)) {
        $n = $m.last - $m.first + 1
        if ($a -lt 1 -or $a -gt $n) { '{0}:{1} -> hors du module ({2} lignes)' -f $m.file, $a, $n; continue }
        '{0}:{1} -> GreaseweazleGUI.ps1:{2}' -f $m.file, $a, ($m.first + $a - 1)
    }
}
