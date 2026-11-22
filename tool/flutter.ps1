$ErrorActionPreference = 'Stop'
if (-not $env:PUB_HOSTED_URL) {
  $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
}
if (-not $env:FLUTTER_STORAGE_BASE_URL) {
  $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
}
& "D:\Dev\Flutter-xmu\bin\flutter.bat" @args
exit $LASTEXITCODE
