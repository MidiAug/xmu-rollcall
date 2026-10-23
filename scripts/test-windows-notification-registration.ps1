# Native isolated registration test. Does not start Flutter or modify app shortcuts.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot '.tools\native-notification-tests'
$cmake = Get-Command cmake -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $cmake) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  $cmake = Join-Path $installation 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
if (-not (Test-Path -LiteralPath $cmake)) { throw 'CMake / Visual Studio C++ tools not found.' }
& $cmake -S (Join-Path $projectRoot 'test\native') -B $buildDirectory -A x64
if ($LASTEXITCODE -ne 0) { throw 'Native test configuration failed.' }
& $cmake --build $buildDirectory --config Debug
if ($LASTEXITCODE -ne 0) { throw 'Native test build failed.' }
$ctest = Join-Path (Split-Path -Parent $cmake) 'ctest.exe'
& $ctest --test-dir $buildDirectory -C Debug --output-on-failure
if ($LASTEXITCODE -ne 0) { throw 'Native notification registration test failed.' }
