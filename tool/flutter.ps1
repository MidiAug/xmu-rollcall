$ErrorActionPreference = 'Stop'
if (-not $env:PUB_HOSTED_URL) {
  $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
}
if (-not $env:FLUTTER_STORAGE_BASE_URL) {
  $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$fvmFlutter = Join-Path $repoRoot '.fvm\flutter_sdk\bin\flutter.bat'
$flutterBin = $null
if ($env:FLUTTER_BIN -and (Test-Path -LiteralPath $env:FLUTTER_BIN)) {
  $flutterBin = $env:FLUTTER_BIN
} elseif (Test-Path -LiteralPath $fvmFlutter) {
  $flutterBin = $fvmFlutter
} elseif ($cmd = Get-Command flutter -ErrorAction SilentlyContinue) {
  $flutterBin = $cmd.Source
} else {
  throw 'Flutter SDK not found. Add flutter to PATH, run fvm use, or set FLUTTER_BIN.'
}

& $flutterBin @args
exit $LASTEXITCODE
