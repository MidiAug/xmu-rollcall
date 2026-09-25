# Build Android APK + Windows MSIX into dist/.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\package-all.ps1

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

& "$PSScriptRoot\package-android.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\package-windows.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '==> dist/'
Get-ChildItem dist | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
