# =============================================================================
# Build-Exe.ps1 - Compile src\GreaseweazleGUI.ps1 en exécutable (PS2EXE) dans dist\,
#                 avec l'icône src\GreaseweazleGUI.ico, puis signe l'exe avec un
#                 certificat auto-signé (comportement par défaut sur un PC personnel).
#
# ATTENTION - CADRE D'USAGE DE LA SIGNATURE :
#   La signature auto-signée n'est de confiance QUE sur une machine où tu es
#   légitime à définir ce qui est approuvé (ton PC personnel). Sur un poste
#   d'entreprise managé, faire accepter un binaire auto-signé en l'ajoutant aux
#   autorités de confiance contourne la politique de sécurité : sur un tel poste,
#   compile avec -Sign:$false ou demande une signature au certificat interne via
#   ton équipe sécurité. Règle du projet : tout exe livré est signé.
#
# Prérequis : Windows PowerShell 5.1 et module PS2EXE
#             (Install-Module -Name ps2exe -Scope CurrentUser).
#             Lancé depuis PowerShell 7, le script se relance seul sous
#             Windows PowerShell 5.1, que PS2EXE exige pour compiler.
#
# Usage :
#   Compiler + signer (comportement par défaut) :
#     powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
#   Compiler sans signer (poste managé, test) :
#     powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1 -Sign:$false
#   La 1re signature crée le certificat et le déclare de confiance
#   (magasins utilisateur, pas besoin d'admin). Les suivantes le réutilisent.
#
# La version de l'exe est lue dans src\GreaseweazleGUI.ps1 ($script:Version = 'X.Y').
# =============================================================================
param(
    [switch]$Sign = $true,                           # signer l'exe après compilation (-Sign:$false pour désactiver)
    [string]$CertSubject = 'CN=Greaseweazle Studio', # sujet du certificat auto-signé
    [string]$TimestampServer = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# --- PowerShell 7 : relance sous Windows PowerShell 5.1 (exigé par PS2EXE) -----
# PS2EXE relance lui-même Windows PowerShell depuis PowerShell 7, mais sans
# -ExecutionPolicy Bypass : sur un poste en policy Restricted, son module ne se
# charge pas. On relance donc ici, en transmettant les paramètres explicites.
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host 'PowerShell 7 détecté : relance sous Windows PowerShell 5.1 (requis par PS2EXE).' -ForegroundColor Yellow
    $winPS = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $fwd = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) { $fwd += "-${k}:`$$([bool]$v)" } else { $fwd += "-$k"; $fwd += [string]$v }
    }
    & $winPS @fwd
    exit $LASTEXITCODE
}

if ($PSScriptRoot) { $here = $PSScriptRoot } else { $here = (Get-Location).Path }

$src    = Join-Path $here 'src\GreaseweazleGUI.ps1'
$ico    = Join-Path $here 'src\GreaseweazleGUI.ico'
$outDir = Join-Path $here 'dist'
$out    = Join-Path $outDir 'GreaseweazleGUI.exe'

if (-not (Test-Path -LiteralPath $src)) { throw "Introuvable : $src" }
if (-not (Test-Path -LiteralPath $outDir)) { [void](New-Item -ItemType Directory -Path $outDir) }

# --- Version : lue dans le script source ---------------------------------------
$m = Select-String -LiteralPath $src -Pattern '^\$script:Version\s*=\s*''([0-9.]+)''' | Select-Object -First 1
if (-not $m) { throw "Version introuvable dans $src (attendu : `$script:Version = 'X.Y')." }
$version     = $m.Matches[0].Groups[1].Value
$fileVersion = ((($version -split '\.') + @('0','0','0','0'))[0..3]) -join '.'   # X.Y -> X.Y.0.0 (format PS2EXE)

# --- Compilation -------------------------------------------------------------
if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Import-Module ps2exe -ErrorAction Stop
}

# Jamais de faux positif sur un exe précédent : on repart d'un dist\ vide.
if (Test-Path -LiteralPath $out) {
    try { Remove-Item -LiteralPath $out -Force -ErrorAction Stop }
    catch { throw "Impossible de supprimer $out : l'application est probablement ouverte. Ferme-la puis relance. ($($_.Exception.Message))" }
}

Write-Host "Compilation de src\GreaseweazleGUI.ps1 (version $version) ..." -ForegroundColor Cyan
$common = @{
    InputFile = $src; OutputFile = $out
    noConsole = $true; STA = $true
    title = 'Greaseweazle Studio'
    description = 'Préservation, écriture et contrôle de disquettes Amiga'
    product = 'Greaseweazle Studio'; version = $fileVersion
}
if (Test-Path -LiteralPath $ico) { $common.iconFile = $ico } else { Write-Warning "Icône absente : compilation sans icône." }
Invoke-ps2exe @common

if (-not (Test-Path -LiteralPath $out)) { throw "PS2EXE n'a produit aucun exécutable (voir les messages ci-dessus)." }
$size = [math]::Round((Get-Item -LiteralPath $out).Length / 1KB, 0)
Write-Host "OK -> $out ($size Ko)" -ForegroundColor Green

# --- Signature (par défaut sur PC personnel) ---------------------------------
if ($Sign) {
    Write-Host ''
    Write-Host 'Signature de code (certificat auto-signé, confiance locale uniquement).' -ForegroundColor Yellow

    # 1. Récupère un certificat de signature de code existant pour ce sujet, ou en crée un.
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object NotAfter -Descending | Select-Object -First 1

    if (-not $cert) {
        Write-Host "Création d'un certificat auto-signé : $CertSubject" -ForegroundColor Cyan
        $cert = New-SelfSignedCertificate `
            -Subject $CertSubject `
            -Type CodeSigningCert -KeyUsage DigitalSignature `
            -KeyAlgorithm RSA -KeyLength 2048 `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -NotAfter (Get-Date).AddYears(5)

        # Déclare le certificat de confiance sur CETTE machine (magasins utilisateur).
        $store = Get-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)"
        foreach ($name in 'Root','TrustedPublisher') {
            $s = New-Object System.Security.Cryptography.X509Certificates.X509Store($name,'CurrentUser')
            $s.Open('ReadWrite'); $s.Add($store); $s.Close()
        }
        Write-Host "Certificat créé et déclaré de confiance (Root + TrustedPublisher, utilisateur)." -ForegroundColor Green
        Write-Host "Empreinte : $($cert.Thumbprint)" -ForegroundColor Gray
    } else {
        Write-Host "Certificat existant réutilisé (empreinte $($cert.Thumbprint))." -ForegroundColor Gray
    }

    # 2. Signe l'exe (horodatage pour une validité au-delà de l'expiration du certificat).
    $sig = Set-AuthenticodeSignature -FilePath $out -Certificate $cert `
               -TimestampServer $TimestampServer -HashAlgorithm SHA256

    if ($sig.Status -eq 'Valid') {
        Write-Host "Signature : VALIDE ($($sig.SignerCertificate.Subject))" -ForegroundColor Green
    } else {
        Write-Warning "Signature : état $($sig.Status) - $($sig.StatusMessage)"
        Write-Warning "Sans horodatage accessible (proxy ?), relance sans -TimestampServer : la signature reste valide mais expire avec le certificat."
    }
} else {
    Write-Host 'Exe non signé.' -ForegroundColor Gray
}

Write-Host ''
Write-Host "Déploiement : copier dist\GreaseweazleGUI.exe dans le répertoire de gw.exe." -ForegroundColor Gray
