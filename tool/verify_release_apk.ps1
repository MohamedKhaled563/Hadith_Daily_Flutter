# Checks a built release APK for things the test suite structurally cannot.
#
# Why this exists
# ---------------
# `flutter test integration_test` always builds in DEBUG, and there is no
# `--release` flag for it. Debug builds do not run the resource shrinker, so
# a whole class of release only breakage is invisible to every test in this
# repo, on a real device or otherwise.
#
# That is not hypothetical. The notification status bar icon
# (drawable/ic_stat_notify) is referenced only as the *string*
# '@drawable/ic_stat_notify' passed from Dart, which the shrinker cannot
# see, so it stripped the drawable from the release APK. Every reschedule
# then threw invalid_icon before scheduling anything and release builds
# armed zero reminders, while all 56 tests passed against debug. See
# android/app/src/main/res/raw/keep.xml.
#
# Run this against the APK you are about to ship.
#
# Usage
# -----
#   pwsh tool/verify_release_apk.ps1
#   pwsh tool/verify_release_apk.ps1 -Apk path\to\app-release.apk

param(
    [string]$Apk = "build/app/outputs/flutter-apk/app-release.apk",
    [string]$Aapt2
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Apk)) {
    Write-Error "APK not found: $Apk  (run: flutter build apk --release)"
    exit 1
}

if (-not $Aapt2) {
    $bt = Get-ChildItem "$env:LOCALAPPDATA\Android\sdk\build-tools" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($bt) { $Aapt2 = Join-Path $bt.FullName "aapt2.exe" }
}
if (-not $Aapt2 -or -not (Test-Path $Aapt2)) {
    Write-Error "aapt2 not found - pass -Aapt2 <path to aapt2.exe>"
    exit 1
}

$resources = & $Aapt2 dump resources $Apk 2>&1 | Out-String

# Resources that only Dart references by name, so nothing in the Android
# build graph keeps them alive. Add to this list whenever a new one appears.
$required = @(
    @{ Name = "drawable/ic_stat_notify"; Why = "notification status bar icon (NotificationScheduler)" }
)

$failed = $false
foreach ($r in $required) {
    if ($resources -match [regex]::Escape($r.Name)) {
        Write-Host ("OK      {0}" -f $r.Name)
    } else {
        Write-Host ("MISSING {0}  <- {1}" -f $r.Name, $r.Why) -ForegroundColor Red
        $failed = $true
    }
}

if ($failed) {
    Write-Host ""
    Write-Error ("A resource the app loads by name was shrunk out of the release APK. " +
        "Add it to android/app/src/main/res/raw/keep.xml and rebuild.")
    exit 1
}

Write-Host ""
Write-Host "Release APK looks shippable: $Apk"
