Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Chemins -------------------------------------------------------------------
if ($PSScriptRoot) {
    $script:AppDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    # Exe PS2EXE : repertoire de l executable (gw.exe est a cote), jamais le repertoire courant,
    # qui depend du raccourci et qui, sur un partage UNC, est rendu sous forme qualifiee par le
    # fournisseur (Microsoft.PowerShell.Core\FileSystem::\\serveur\...), inconnue de Process.Start.
    $exePath = $null
    try { $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { }
    if ($exePath -and $exePath -notmatch '(^|\\)(powershell|powershell_ise|pwsh)\.exe$') {
        $script:AppDir = Split-Path -Parent $exePath
    } else {
        $script:AppDir = (Get-Location).ProviderPath
    }
}
$script:AppDir = $script:AppDir -replace '^[^:]+::', ''   # retire un eventuel prefixe de fournisseur PowerShell
$script:GwExe      = Join-Path $script:AppDir 'gw.exe'
$script:ConfigFile = Join-Path $script:AppDir 'GreaseweazleGUI.json'
$script:TempDir    = Join-Path $env:TEMP 'GreaseweazleGUI'

$script:GwProc     = $null
$script:OutQueue   = $null      # file des lignes de sortie de gw.exe (remplie par Drain-GwReader)
$script:OutStdoutReader = $null
$script:OutStderrReader = $null
$script:OutStdoutTask   = $null
$script:OutStderrTask   = $null

# Recherche asynchrone de la bibliotheque
$script:LibRunspace = $null
$script:LibPS       = $null
$script:LibAsync    = $null

# Extensions image reconnues par gw 1.23 (suffixes listes par "gw write --help")
$script:ImgExt = @('.a2r','.adf','.ads','.adm','.adl','.ctr','.d1m','.d2m','.d4m','.d64','.d71',
                   '.d81','.d88','.dcp','.dim','.dmk','.do','.dsd','.dsk','.edsk','.fd','.fdi',
                   '.hdm','.hfe','.ima','.img','.imd','.ipf','.mgt','.msa','.nfd','.nsi','.po',
                   '.raw','.sf7','.scp','.ssd','.st','.td0','.xdf')
$script:DocExt = @('.txt','.pdf','.jpg','.jpeg','.png','.gif','.nfo','.md')

