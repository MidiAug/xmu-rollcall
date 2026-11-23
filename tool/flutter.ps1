$ErrorActionPreference = 'Stop'
if (-not $env:PUB_HOSTED_URL) {
  $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
}
if (-not $env:FLUTTER_STORAGE_BASE_URL) {
  $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
}

$flutterBin = $null
if ($env:FLUTTER_BIN -and (Test-Path -LiteralPath $env:FLUTTER_BIN)) {
  $flutterBin = $env:FLUTTER_BIN
} elseif ($cmd = Get-Command flutter -ErrorAction SilentlyContinue) {
  $flutterBin = $cmd.Source
} elseif (Test-Path -LiteralPath 'D:\Dev\Flutter-xmu\bin\flutter.bat') {
  $flutterBin = 'D:\Dev\Flutter-xmu\bin\flutter.bat'
} else {
  throw 'Flutter SDK not found. Add flutter to PATH or set FLUTTER_BIN.'
}

& $flutterBin @args
exit $LASTEXITCODE
