# Build Windows release + MSIX into dist/.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\package-windows.ps1
#
# First install may prompt to trust the msix self-signed test certificate.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$pubspec = Get-Content -Raw 'pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*([^\s#+]+)') {
  throw 'Could not parse version from pubspec.yaml'
}
$ver = $Matches[1]

New-Item -ItemType Directory -Force -Path 'dist' | Out-Null

Write-Host '==> dart run msix:create (builds windows + packs MSIX)'
dart run msix:create `
  --output-path dist `
  --output-name "xmu-rollcall-$ver-windows"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dest = "dist\xmu-rollcall-$ver-windows.msix"
if (-not (Test-Path $dest)) {
  # msix may emit slightly different casing/extension; list dist for debugging
  Get-ChildItem dist | Format-Table Name, Length
  throw "MSIX not found: $dest"
}

Write-Host "OK: $((Resolve-Path $dest).Path)"
Write-Host 'Tip: double-click the .msix to install. Trust the test certificate if Windows asks.'
