# =============================================================================
# Build-Exe.ps1 - Compile src\GreaseweazleGUI.ps1 en executable (PS2EXE) dans dist\,
#                 avec l icone src\GreaseweazleGUI.ico, puis signe l exe en option
#                 avec un certificat auto-signe.
#
# ATTENTION - CADRE D USAGE DE -Sign :
#   La signature auto-signee n'est de confiance QUE sur une machine ou tu es
#   legitime a definir ce qui est approuve (ton PC personnel). Sur un poste
#   d'entreprise manage, faire accepter un binaire auto-signe en l'ajoutant aux
#   autorites de confiance contourne la politique de securite : n'utilise PAS
#   le mode -Sign sur un tel poste ; demande une signature au certificat interne
#   via ton equipe securite.
#
# Prerequis : Windows PowerShell 5.1 et module PS2EXE
#             (Install-Module -Name ps2exe -Scope CurrentUser).
#
# Usage :
#   Compiler seulement (comportement par defaut) :
#     powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
#   Compiler + signer (PC personnel uniquement) :
#     powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1 -Sign
#   La 1re execution avec -Sign cree le certificat et le declare de confiance
#   (magasins utilisateur, pas besoin d'admin). Les suivantes le reutilisent.
#
# La version de l exe est lue dans src\GreaseweazleGUI.ps1 ($script:Version = 'X.Y').
# =============================================================================
param(
    [switch]$Sign,                                   # signer l'exe apres compilation
    [string]$CertSubject = 'CN=Greaseweazle Studio', # sujet du certificat auto-signe
    [string]$TimestampServer = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'
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

Write-Host "Compilation de src\GreaseweazleGUI.ps1 (version $version) ..." -ForegroundColor Cyan
$common = @{
    InputFile = $src; OutputFile = $out
    noConsole = $true; STA = $true
    title = 'Greaseweazle Studio'
    description = 'Preservation, ecriture et controle de disquettes Amiga'
    product = 'Greaseweazle Studio'; version = $fileVersion
}
if (Test-Path -LiteralPath $ico) { $common.iconFile = $ico } else { Write-Warning "Icone absente : compilation sans icone." }
Invoke-ps2exe @common

if (-not (Test-Path -LiteralPath $out)) { throw "La compilation n'a pas produit $out." }
$size = [math]::Round((Get-Item -LiteralPath $out).Length / 1KB, 0)
Write-Host "OK -> $out ($size Ko)" -ForegroundColor Green

# --- Signature (optionnelle, PC personnel) -----------------------------------
if ($Sign) {
    Write-Host ''
    Write-Host 'Signature de code (certificat auto-signe, confiance locale uniquement).' -ForegroundColor Yellow

    # 1. Recupere un certificat de signature de code existant pour ce sujet, ou en cree un.
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object NotAfter -Descending | Select-Object -First 1

    if (-not $cert) {
        Write-Host "Creation d'un certificat auto-signe : $CertSubject" -ForegroundColor Cyan
        $cert = New-SelfSignedCertificate `
            -Subject $CertSubject `
            -Type CodeSigningCert -KeyUsage DigitalSignature `
            -KeyAlgorithm RSA -KeyLength 2048 `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -NotAfter (Get-Date).AddYears(5)

        # Declare le certificat de confiance sur CETTE machine (magasins utilisateur).
        $store = Get-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)"
        foreach ($name in 'Root','TrustedPublisher') {
            $s = New-Object System.Security.Cryptography.X509Certificates.X509Store($name,'CurrentUser')
            $s.Open('ReadWrite'); $s.Add($store); $s.Close()
        }
        Write-Host "Certificat cree et declare de confiance (Root + TrustedPublisher, utilisateur)." -ForegroundColor Green
        Write-Host "Empreinte : $($cert.Thumbprint)" -ForegroundColor Gray
    } else {
        Write-Host "Certificat existant reutilise (empreinte $($cert.Thumbprint))." -ForegroundColor Gray
    }

    # 2. Signe l'exe (horodatage pour une validite au-dela de l'expiration du certificat).
    $sig = Set-AuthenticodeSignature -FilePath $out -Certificate $cert `
               -TimestampServer $TimestampServer -HashAlgorithm SHA256

    if ($sig.Status -eq 'Valid') {
        Write-Host "Signature : VALIDE ($($sig.SignerCertificate.Subject))" -ForegroundColor Green
    } else {
        Write-Warning "Signature : etat $($sig.Status) - $($sig.StatusMessage)"
        Write-Warning "Sans horodatage accessible (proxy ?), relance sans -TimestampServer : la signature reste valide mais expire avec le certificat."
    }
}

Write-Host ''
Write-Host "Deploiement : copier dist\GreaseweazleGUI.exe dans le repertoire de gw.exe." -ForegroundColor Gray
if (-not $Sign) {
    Write-Host "Pour signer (PC personnel uniquement) : .\Build-Exe.ps1 -Sign" -ForegroundColor Gray
}
