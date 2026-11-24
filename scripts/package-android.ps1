# Build release APK into dist/.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\package-android.ps1

param(
  [switch] $Preview,
  [switch] $RequireSigning,
  [switch] $NoPub,
  [switch] $SplitPerAbi
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$pubspec = Get-Content -Raw 'pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*([^\s#+]+)') {
  throw 'Could not parse version from pubspec.yaml'
}
$ver = $Matches[1]

if ($Preview -and $RequireSigning) { throw 'Preview and RequireSigning cannot be combined' }
if ($RequireSigning) {
  foreach ($name in @('XMU_ANDROID_KEYSTORE_PATH', 'XMU_ANDROID_KEYSTORE_PASSWORD', 'XMU_ANDROID_KEY_ALIAS', 'XMU_ANDROID_KEY_PASSWORD')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
      throw "Missing signing setting: $name"
    }
  }
}

New-Item -ItemType Directory -Force -Path 'dist' | Out-Null
New-Item -ItemType Directory -Force -Path 'build/symbols/android' | Out-Null

Write-Host '==> flutter build apk --release'
$previousPreview = $env:XMU_ANDROID_PREVIEW
$previousRequireSigning = $env:XMU_ANDROID_REQUIRE_SIGNING
try {
  $env:XMU_ANDROID_PREVIEW = if ($Preview) { 'true' } else { 'false' }
  $env:XMU_ANDROID_REQUIRE_SIGNING = if ($RequireSigning) { 'true' } else { 'false' }
  $buildArgs = @('build', 'apk', '--release', '--split-debug-info=build/symbols/android')
  if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }
  if ($NoPub) { $buildArgs += '--no-pub' }
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) { throw "Flutter APK build failed (exit $LASTEXITCODE)" }
} finally {
  $env:XMU_ANDROID_PREVIEW = $previousPreview
  $env:XMU_ANDROID_REQUIRE_SIGNING = $previousRequireSigning
}

$apkDir = Join-Path $Root 'build/app/outputs/flutter-apk'
$suffix = if ($Preview) { '-preview' } else { '' }
if ($SplitPerAbi) {
  if (-not (Test-Path $apkDir)) { throw "APK directory not found: $apkDir" }
  $apks = Get-ChildItem -LiteralPath $apkDir -Filter 'app-*-release.apk' -File | Sort-Object Name
  if (-not $apks) { throw "No split APKs found under: $apkDir" }
  foreach ($apk in $apks) {
    if ($apk.Name -match '^app-(.+)-release\.apk$') {
      $abi = $Matches[1]
      $dest = Join-Path $Root "dist/xmu-rollcall-$ver-android-$abi$suffix.apk"
    } else {
      $dest = Join-Path $Root "dist/$($apk.Name)"
    }
    Copy-Item -Force $apk.FullName $dest
    Write-Host "OK: $((Resolve-Path $dest).Path)"
  }
} else {
  $src = Join-Path $apkDir 'app-release.apk'
  if (-not (Test-Path $src)) { throw "APK not found: $src" }

  $dest = Join-Path $Root "dist/xmu-rollcall-$ver-android$suffix.apk"
  Copy-Item -Force $src $dest
  Write-Host "OK: $((Resolve-Path $dest).Path)"
}
