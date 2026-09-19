[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Domain = "finntrail.local"
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Requesting Administrator privileges to trust the local CA and update hosts..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ProjectRoot `"$ProjectRoot`" -Domain `"$Domain`""
    $process = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $arguments -Wait -PassThru
    exit $process.ExitCode
}

$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$CertificateDirectory = Join-Path $ProjectRoot "confs\nginx\certs\$Domain"
$CertificateFile = Join-Path $CertificateDirectory "fullchain.pem"
$PrivateKeyFile = Join-Path $CertificateDirectory "privkey.pem"

$mkcertCommand = Get-Command mkcert -ErrorAction SilentlyContinue
if ($null -ne $mkcertCommand) {
    $mkcert = $mkcertCommand.Source
}
else {
    $mkcertDirectory = Join-Path $env:LOCALAPPDATA "Programs\mkcert"
    $mkcert = Join-Path $mkcertDirectory "mkcert.exe"
    New-Item -ItemType Directory -Force -Path $mkcertDirectory | Out-Null

    if (-not (Test-Path -LiteralPath $mkcert)) {
        Write-Host "Downloading mkcert from the official distribution endpoint..."
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        try {
            Invoke-WebRequest `
                -Uri "https://dl.filippo.io/mkcert/latest?for=windows/amd64" `
                -OutFile $mkcert
        }
        finally {
            $ProgressPreference = $oldProgressPreference
        }
        Unblock-File -LiteralPath $mkcert
    }
}

& $mkcert -install
if ($LASTEXITCODE -ne 0) {
    throw "mkcert failed to install its local CA."
}

New-Item -ItemType Directory -Force -Path $CertificateDirectory | Out-Null
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("finntrail-mkcert-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null

try {
    $temporaryCertificate = Join-Path $temporaryDirectory "fullchain.pem"
    $temporaryKey = Join-Path $temporaryDirectory "privkey.pem"

    & $mkcert `
        -cert-file $temporaryCertificate `
        -key-file $temporaryKey `
        $Domain localhost 127.0.0.1 "::1"
    if ($LASTEXITCODE -ne 0) {
        throw "mkcert failed to generate the certificate."
    }

    Copy-Item -LiteralPath $temporaryCertificate -Destination $CertificateFile -Force
    Copy-Item -LiteralPath $temporaryKey -Destination $PrivateKeyFile -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

$hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$hostExists = $false
foreach ($line in Get-Content -LiteralPath $hostsPath) {
    $trimmed = ($line -replace '#.*$', '').Trim()
    if ($trimmed.Length -eq 0) { continue }
    $parts = $trimmed -split '\s+'
    if ($parts[0] -eq "127.0.0.1" -and $parts -contains $Domain) {
        $hostExists = $true
        break
    }
}

if (-not $hostExists) {
    Add-Content -LiteralPath $hostsPath -Value ("`r`n127.0.0.1`t{0}" -f $Domain) -Encoding ASCII
}

& ipconfig.exe /flushdns | Out-Null

Write-Host "Local HTTPS certificate is ready:"
Write-Host "  $CertificateFile"
Write-Host "  $PrivateKeyFile"
Write-Host "Open https://$Domain after Docker Compose starts."
