$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$captureFlags = @('CAPTURE_DESKTOP_UI', 'CAPTURE_DESKTOP_WORKSPACE', 'CAPTURE_MOBILE_CAMPUS', 'CAPTURE_GPA_UI', 'CAPTURE_README')
$previous = @{}
foreach ($name in $captureFlags + @('NO_PROXY')) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
Push-Location $repo
try {
    foreach ($name in $captureFlags) {
        [Environment]::SetEnvironmentVariable($name, '1', 'Process')
    }
    $env:NO_PROXY = (@($previous['NO_PROXY'], 'localhost', '127.0.0.1', '::1') | Where-Object { $_ }) -join ','
    & "$repo/tool/flutter.ps1" test --no-pub --reporter expanded `
        test/widget/desktop_workspace_test.dart `
        test/widget/mobile_campus_design_test.dart `
        test/widget/readme_preview_test.dart `
        test/widget/gpa_page_test.dart
    if ($LASTEXITCODE -ne 0) { throw "Preview tests failed ($LASTEXITCODE); screenshots were not copied." }

    $sources = @{
        'android-rollcall.png' = 'build/mobile-campus-design/active-light.png'
        'android-rollcall-dark.png' = 'build/mobile-campus-design/done-dark.png'
        'android-homework.png' = 'build/readme-preview/android-homework.png'
        'android-homework-dark.png' = 'build/readme-preview/android-homework-dark.png'
        'windows-rollcall.png' = '.tools/desktop-workspace/rollcall-1120-light-1.0-dpr1.0.png'
        'windows-homework.png' = 'build/readme-preview/windows-homework.png'
        'windows-history.png' = '.tools/desktop-workspace/签到记录-1120-light-1.0-dpr1.0.png'
        'windows-tools.png' = '.tools/desktop-workspace/工具-1120-light-1.0-dpr1.0.png'
        'windows-gpa.png' = 'build/gpa-ui-review/gpa-960.0-false.png'
    }
    foreach ($source in $sources.Values) {
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing preview: $source" }
    }
    foreach ($name in $sources.Keys) {
        Copy-Item -LiteralPath $sources[$name] -Destination "assets/screenshots/$name"
    }
    Write-Host 'README previews updated. Inspect the images before committing.'
} finally {
    Pop-Location
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
