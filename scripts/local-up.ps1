$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath (Join-Path $RootDir ".env"))) {
    throw ".env is missing. Run scripts\init-env.ps1 first."
}

if (Select-String -LiteralPath (Join-Path $RootDir ".env") -Pattern "CHANGE_ME_" -Quiet) {
    throw ".env still contains placeholder secrets."
}

Push-Location $RootDir
try {
    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw "docker compose config failed." }
    docker compose pull
    if ($LASTEXITCODE -ne 0) { throw "docker compose pull failed." }
    docker compose up -d --remove-orphans
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed." }
    docker compose ps
}
finally {
    Pop-Location
}
