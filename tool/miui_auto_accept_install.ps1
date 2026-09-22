# Auto-accepts MIUI's "تثبيت هذا التطبيق عبر USB؟" dialog so unattended adb
# installs (notably `flutter test integration_test`, which reinstalls the app
# once per test file) do not fail.
#
# Why this is needed
# ------------------
# With "Install via USB" (التثبيت عبر USB) enabled in Developer options, MIUI
# still raises com.miui.securitycenter/.permcenter.install.AdbInstallActivity
# for every adb install. That dialog has a countdown on its *reject* button —
# "رفض (٨)" — so leaving it alone does not mean "ask me later", it means the
# install is refused eight seconds later with:
#
#   Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
#
# which reads like a permissions problem and is really just a timeout.
#
# Two things make it awkward to automate:
#   * The dialog never becomes `mCurrentFocus` — it only appears in the full
#     `dumpsys window windows` list, so focus-based detection never sees it.
#   * Its "تذكر اختياري" (remember my choice) checkbox does not persist for
#     adb installs on MIUI 12.5 (verified: the dialog returns on the very next
#     install), so there is no one-time setting to flip instead of this.
#
# Usage
# -----
#   pwsh tool/miui_auto_accept_install.ps1 -Serial equobi59a6ijfyga
#
# Leave it running in its own terminal for the duration of a device test run,
# then Ctrl+C. It only ever taps this one MIUI dialog.

param(
    [Parameter(Mandatory = $true)][string]$Serial,
    [string]$Adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe",
    [int]$TimeoutMinutes = 30
)

if (-not (Test-Path $Adb)) {
    Write-Error "adb not found at $Adb - pass -Adb <path>"
    exit 1
}

Write-Host "Watching $Serial for MIUI's adb-install dialog. Ctrl+C to stop."

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$accepted = 0

while ((Get-Date) -lt $deadline) {
    $present = & $Adb -s $Serial shell dumpsys window windows 2>$null |
        Select-String -Pattern 'AdbInstallActivity'

    if ($present) {
        & $Adb -s $Serial shell uiautomator dump /sdcard/miui_install.xml 2>$null | Out-Null
        $xml = & $Adb -s $Serial shell cat /sdcard/miui_install.xml 2>$null | Out-String

        # NOTE: deliberately does NOT touch the "تذكر اختياري" (remember my
        # choice) checkbox. That box applies to whichever outcome the dialog
        # ends on — and this dialog ends on *reject* by itself after ~8s. Tick
        # it and lose the race even once and MIUI stores a permanent deny, at
        # which point every later install fails instantly with
        # INSTALL_FAILED_USER_RESTRICTED and no visible dialog at all. Undoing
        # that needs "Install via USB" toggled off and on again by hand. The
        # box does not persist an *accept* for adb installs on MIUI 12.5
        # anyway, so there is nothing to gain and a stuck device to lose.

        # Press "تثبيت". Matched last-to-first because the dialog's title
        # ("التثبيت عبر USB") contains the same word as the button.
        $btn = [regex]::Matches(
            $xml,
            '<node[^>]*?text="تثبيت"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        if ($btn.Count -gt 0) {
            $g = $btn[$btn.Count - 1].Groups
            $cx = [int]((([int]$g[1].Value) + ([int]$g[3].Value)) / 2)
            $cy = [int]((([int]$g[2].Value) + ([int]$g[4].Value)) / 2)
            & $Adb -s $Serial shell input tap $cx $cy 2>$null | Out-Null
            $accepted++
            Write-Host ("accepted install #{0} at {1},{2}" -f $accepted, $cx, $cy)
            # The install itself takes a moment; do not re-scan into it.
            Start-Sleep -Seconds 3
        }
    }

    # Must stay well inside the dialog's ~8s reject countdown.
    Start-Sleep -Milliseconds 400
}

Write-Host "Done. Accepted $accepted install dialog(s)."
