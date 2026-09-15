#Requires -Version 5.1
<#
.SYNOPSIS
  Build + cover-install APK to a connected Android phone WITHOUT wiping app data.

.DESCRIPTION
  Do NOT use `flutter install` for day-to-day phone updates: it uninstalls the
  old package first, which deletes SecureStore / SharedPreferences / cookies
  (login session and all settings).

  This script uses `adb install -r` (replace) so login + prefs survive.

.PARAMETER DeviceId
  adb / flutter device id. Default: first authorized Android device.

.PARAMETER Mode
  release (default) | debug | profile

.PARAMETER SkipBuild
  Install an already-built APK only.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\install-phone.ps1
#>
param(
  [string] $DeviceId = '',
  [ValidateSet('release', 'debug', 'profile')]
  [string] $Mode = 'release',
  [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Resolve-DeviceId {
  param([string] $Preferred)
  if ($Preferred) { return $Preferred }
  $lines = adb devices | Where-Object { $_ -match '^\S+\s+device$' }
  if (-not $lines) {
    throw 'No authorized Android device. Plug in USB, enable debugging, accept the prompt.'
  }
  if (@($lines).Count -gt 1 -and -not $Preferred) {
    Write-Host 'Multiple devices:'
    $lines | ForEach-Object { Write-Host "  $_" }
    throw 'Pass -DeviceId <id> when more than one device is connected.'
  }
  return ($lines | Select-Object -First 1) -replace '\s+device$', ''
}

$apkRel = switch ($Mode) {
  'debug' { 'build\app\outputs\flutter-apk\app-debug.apk' }
  'profile' { 'build\app\outputs\flutter-apk\app-profile.apk' }
  default { 'build\app\outputs\flutter-apk\app-release.apk' }
}
$apk = Join-Path $root $apkRel

$device = Resolve-DeviceId -Preferred $DeviceId
Write-Host "Device: $device"
Write-Host "Mode:   $Mode"
Write-Host "APK:    $apkRel"
Write-Host ''
Write-Host 'Note: cover-install (adb -r). Will NOT uninstall — login/settings kept.'
Write-Host '      Keep the same Mode as the currently installed build (debug vs release'
Write-Host '      use different signing keys; mismatch forces a wipe).'
Write-Host ''

if (-not $SkipBuild) {
  Write-Host "Building ($Mode)..."
  switch ($Mode) {
    'debug' { flutter build apk --debug }
    'profile' { flutter build apk --profile }
    default { flutter build apk --release }
  }
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
}

if (-not (Test-Path -LiteralPath $apk)) {
  throw "APK not found: $apk"
}

Write-Host 'Installing with adb install -r (replace, keep data)...'
adb -s $device install -r $apk
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'Install failed. Common cause: debug/release signature mismatch.'
  Write-Host 'Fix: install the SAME Mode as what is already on the phone,'
  Write-Host '     or only then uninstall once (data loss) and reinstall.'
  exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Done. App updated; local login and settings should still be there.'
