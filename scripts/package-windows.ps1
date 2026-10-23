# Build Windows release + NSIS setup.exe into dist/.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\package-windows.ps1
#
# Needs makensis: system install, or portable under .tools\nsis\ (script can fetch NuGet NSIS-Tool).

param([switch] $NoPub)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Find-Makensis {
  $candidates = @(
    (Join-Path $Root '.tools\nsis\nuget\tools\makensis.exe'),
    (Join-Path $Root '.tools\nsis\makensis.exe'),
    'C:\Program Files (x86)\NSIS\makensis.exe',
    'C:\Program Files\NSIS\makensis.exe'
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return (Resolve-Path $c).Path }
  }
  $fromPath = Get-Command makensis -ErrorAction SilentlyContinue
  if ($fromPath) { return $fromPath.Source }
  return $null
}

function Ensure-Makensis {
  $exe = Find-Makensis
  if ($exe) { return $exe }

  Write-Host '==> makensis not found; downloading NuGet NSIS-Tool (portable)...'
  $tools = Join-Path $Root '.tools\nsis'
  New-Item -ItemType Directory -Force -Path $tools | Out-Null
  $nupkg = Join-Path $tools 'NSIS.nuget.zip'
  curl.exe --fail -L --retry 3 -o $nupkg 'https://www.nuget.org/api/v2/package/NSIS-Tool/3.0.8'
  if ($LASTEXITCODE -ne 0) { throw 'Failed to download NSIS-Tool from nuget.org' }
  $expectedHash = 'a1181620e6e4473a655e83f4e0c9abdee24d2656b0caec97ef7b35f8e65bbcf7'
  if ((Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'NSIS-Tool archive checksum mismatch'
  }
  $extract = Join-Path $tools 'nuget'
  # Expand in place: there is no need to recursively delete a computed tool path.
  Expand-Archive -Force -Path $nupkg -DestinationPath $extract
  $exe = Find-Makensis
  if (-not $exe) { throw 'makensis.exe still missing after NuGet extract' }
  return $exe
}

$pubspec = Get-Content -Raw 'pubspec.yaml'
if ($pubspec -notmatch '(?m)^version:\s*([^\s#+]+)') {
  throw 'Could not parse version from pubspec.yaml'
}
$ver = $Matches[1]

New-Item -ItemType Directory -Force -Path 'dist' | Out-Null

Write-Host '==> flutter build windows --release'
$buildArgs = @('build', 'windows', '--release')
if ($NoPub) { $buildArgs += '--no-pub' }
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$releaseCandidates = @(
  'build\windows\x64\runner\Release',
  'build\windows\runner\Release'
)
$releaseDir = $releaseCandidates | Where-Object { Test-Path (Join-Path $_ 'xmu_rollcall.exe') } | Select-Object -First 1
if (-not $releaseDir) {
  throw 'Flutter Release folder with xmu_rollcall.exe not found under build\windows\'
}
$releaseDir = (Resolve-Path $releaseDir).Path

$makensis = Ensure-Makensis
Write-Host "Using makensis: $makensis"

$outFile = Join-Path $Root "dist\xmu-rollcall-$ver-windows-x64-setup.exe"
$nsi = Join-Path $Root 'packaging\windows\installer.nsi'
$icon = Join-Path $Root 'windows\runner\resources\app_icon.ico'

$args = @(
  # Unicode output still needs an explicit charset for UTF-8 source scripts.
  "/INPUTCHARSET", "UTF8",
  "/DPRODUCT_VERSION=$ver",
  "/DRELEASE_DIR=$releaseDir",
  "/DOUT_FILE=$outFile",
  "/V2",
  $nsi
)
if (Test-Path $icon) {
  $args = @("/DINSTALLER_ICON=$icon") + $args
}

Write-Host "==> makensis → $outFile"
& $makensis @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path $outFile)) { throw "Setup exe not found: $outFile" }

$zipFile = Join-Path $Root "dist\xmu-rollcall-$ver-windows-x64.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $zipFile) { Remove-Item -LiteralPath $zipFile -Force }
[IO.Compression.ZipFile]::CreateFromDirectory($releaseDir, $zipFile)

Write-Host "OK: $((Resolve-Path $outFile).Path)"
Write-Host "OK: $((Resolve-Path $zipFile).Path)"
Write-Host 'Tip: double-click the setup.exe (NSIS, current-user). No publisher certificate needed.'
