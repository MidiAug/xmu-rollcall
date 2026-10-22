param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not $SkipBuild) {
        flutter build windows --debug
        if ($LASTEXITCODE -ne 0) { throw 'Windows debug build failed' }
    }
    $previewExe = Join-Path $projectRoot 'build/windows/x64/runner/Debug/xmu_rollcall.exe'
    if (-not (Test-Path -LiteralPath $previewExe)) { throw 'Build the Windows debug app first' }
    Start-Process -FilePath $previewExe -ArgumentList '--preview-desktop-qr' -WorkingDirectory (Split-Path $previewExe) -WindowStyle Normal
} finally {
    Pop-Location
}
