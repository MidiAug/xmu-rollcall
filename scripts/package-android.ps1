# Build release APK into dist/.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\package-android.ps1

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$pubspec = Get-Content -Raw 'pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*([^\s#+]+)') {
  throw 'Could not parse version from pubspec.yaml'
}
$ver = $Matches[1]

New-Item -ItemType Directory -Force -Path 'dist' | Out-Null

Write-Host '==> flutter build apk --release'
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $src)) { throw "APK not found: $src" }

$dest = "dist\xmu-rollcall-$ver-android.apk"
Copy-Item -Force $src $dest
Write-Host "OK: $((Resolve-Path $dest).Path)"
