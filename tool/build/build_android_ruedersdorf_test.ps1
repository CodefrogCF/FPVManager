# Build an opt-in Ruedersdorf Android test APK with experimental BKG 3D-Beta.
# The public release intentionally does NOT enable this test-only service.
# Run from PowerShell on the Windows development machine.
[CmdletBinding()]
param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    $required = @(
        'web/assets/scenery/local_reference.glb',
        'web/assets/scenery/local_reference.fpc',
        'web/assets/scenery/ruedersdorf_r11_ground.glb',
        'web/assets/scenery/ruedersdorf_r11_ground.fpc'
    )
    foreach ($name in $required) {
        if (-not (Test-Path -LiteralPath $name -PathType Leaf)) {
            throw "Ruedersdorf asset missing: $name (files may be excluded by .gitignore)"
        }
    }
    if (-not $SkipTests) {
        & node --test test/js/scenery_manager.test.cjs test/js/scenery_height_mode.test.cjs
        if ($LASTEXITCODE -ne 0) { throw 'Scenery unit tests failed.' }
    }
    & flutter build apk --release --dart-define=FPV_REGIONAL_3D_TEST=true
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
    $apk = 'build/app/outputs/flutter-apk/app-release.apk'
    & python tool/quality/check_release_artifacts.py --apk $apk
    if ($LASTEXITCODE -ne 0) { throw 'The built APK is missing or differs from the local scenery assets.' }
    Write-Host 'Android experimental BKG test APK validated:' $apk
}
finally {
    Pop-Location
}
