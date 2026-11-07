# The end-to-end suite: everything that needs the app running.
#
#   powershell -ExecutionPolicy Bypass -File tool\e2e_suite.ps1 [-Device emulator-5554] [-Quick]
#
#  1. integration_test/e2e_test.dart: one reader from guest to deleted
#     account, through the real screens, the real firestore.rules and the
#     dashboard's own pages, on the local Firebase emulators.
#  2. The other local-Firebase tests (journey, board, sending a message).
#  3. Every device suite in integration_test/, each with a time limit.
#     Notifications are granted from outside every few seconds, since the
#     system dialog would otherwise wait forever for a tap.
#  4. The real notification tap: a reminder is posted, the shade is opened
#     and the notification tapped with adb, and the app must land on the
#     hadith it names.
#  5. The release APK (verified) and the web dashboard build.
#
# Never touches the live project: every Firebase test points at the
# emulators, project demo-journey. Needs an Android emulator running and
# Java 21 (Android Studio's jbr) for the Firebase emulators. -Quick skips
# steps 3 to 5. Exits non-zero if anything failed, after running it all.
param(
  [string]$Device = 'emulator-5554',
  [switch]$Quick
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$logs = Join-Path $root 'build\e2e_logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$failed = @()

function Show($log) {
  Select-String -Path $log -Pattern 'All tests passed|Some tests failed|Expected:|Actual:|\[E\]' -Encoding UTF8 |
    Select-Object -Last 8 | ForEach-Object { '  ' + $_.Line.Substring(0, [Math]::Min(170, $_.Line.Length)) }
}

# Runs [command] as a job with a time limit, granting notifications to the
# app every few seconds while it runs.
function Run($name, $command, $minutes) {
  "=== $name"
  $log = Join-Path $logs "$name.txt"
  Remove-Item $log -ErrorAction SilentlyContinue
  $job = Start-Job -ScriptBlock {
    param($wd, $log, $command, $java)
    $env:JAVA_HOME = $java; $env:PATH = "$java\bin;$env:PATH"
    Set-Location $wd
    Invoke-Expression $command 2>&1 | Out-File -Encoding utf8 $log
  } -ArgumentList $root, $log, $command, $env:JAVA_HOME
  $deadline = (Get-Date).AddMinutes($minutes)
  while ((Get-Date) -lt $deadline -and $job.State -eq 'Running') {
    Start-Sleep -Seconds 4
    & $adb -s $Device shell pm grant com.prodktstudio.tayebqalbak android.permission.POST_NOTIFICATIONS 2>$null | Out-Null
  }
  if ($job.State -eq 'Running') { "  TIMED OUT after $minutes min"; $script:failed += $name }
  Stop-Job $job -ErrorAction SilentlyContinue
  Remove-Job $job -Force
  Show $log
  if (-not (Select-String -Path $log -Pattern 'All tests passed' -Quiet)) {
    if ($script:failed -notcontains $name) { $script:failed += $name }
  }
}

function RunWithFirebase($test, $minutes = 10) {
  Run $test "firebase emulators:exec --only firestore,auth --project demo-journey 'flutter test integration_test/$test.dart -d $Device --no-pub'" $minutes
}

RunWithFirebase 'e2e_test' 12
RunWithFirebase 'journey_firestore_test'
RunWithFirebase 'board_firestore_test'
RunWithFirebase 'send_message_test'

if (-not $Quick) {
  $suites = [ordered]@{
    'memo_test' = 6; 'board_test' = 6; 'points_test' = 6; 'ui_suite_test' = 22
    'journey_test' = 6; 'journey_reading_flow_test' = 8; 'journey_posters_test' = 6
    'notification_planner_test' = 6; 'smart_reminders_test' = 8
    'notification_scheduler_test' = 8; 'notification_lifecycle_test' = 6
    'notification_device_test' = 8; 'regression_test' = 10
    'submission_approval_test' = 6; 'daily_message_reveal_test' = 8
  }
  foreach ($suite in $suites.Keys) {
    Run $suite "flutter test integration_test/$suite.dart -d $Device --no-pub" $suites[$suite]
  }

  '=== reminder_tap_test (a real notification, tapped with adb)'
  $log = Join-Path $logs 'reminder_tap_test.txt'
  $ui = Join-Path $logs 'ui.xml'
  $job = Start-Job -ScriptBlock {
    param($wd, $log, $device)
    Set-Location $wd
    flutter test integration_test/reminder_tap_test.dart -d $device --no-pub 2>&1 | Out-File -Encoding utf8 $log
  } -ArgumentList $root, $log, $Device
  # The word for hadith, as escapes: Windows PowerShell reads this file as ANSI.
  $word = '\u062d\u062f\u064a\u062b'
  $deadline = (Get-Date).AddMinutes(5)
  while ((Get-Date) -lt $deadline -and $job.State -eq 'Running') {
    Start-Sleep -Seconds 4
    & $adb -s $Device shell pm grant com.prodktstudio.tayebqalbak android.permission.POST_NOTIFICATIONS 2>$null | Out-Null
    $posted = & $adb -s $Device shell "dumpsys notification --noredact | grep -c reading_journey" 2>$null
    if ("$posted".Trim() -eq '0') { continue }
    & $adb -s $Device shell cmd statusbar expand-notifications 2>$null | Out-Null
    Start-Sleep -Seconds 2
    & $adb -s $Device shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    & $adb -s $Device pull /sdcard/ui.xml $ui 2>$null | Out-Null
    $xml = Get-Content $ui -Raw -Encoding UTF8
    $m = [regex]::Match($xml, "text=""[^""]*$word[^""]*""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""")
    if ($m.Success) {
      $x = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
      $y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
      & $adb -s $Device shell input tap $x $y
      # A tap can land on the group header and only expand it.
      Start-Sleep -Seconds 6
      continue
    }
    & $adb -s $Device shell cmd statusbar collapse 2>$null | Out-Null
  }
  Wait-Job $job -Timeout 100 | Out-Null
  Stop-Job $job -ErrorAction SilentlyContinue
  Remove-Job $job -Force
  & $adb -s $Device shell cmd statusbar collapse 2>$null | Out-Null
  Show $log
  if (-not (Select-String -Path $log -Pattern 'All tests passed' -Quiet)) { $failed += 'reminder_tap_test' }

  '=== release build'
  git checkout -- android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java 2>$null
  flutter build apk --release --no-pub 2>&1 | Select-Object -Last 1 | ForEach-Object { "  $_" }
  if ($LASTEXITCODE -ne 0) { $failed += 'release build' }
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\verify_release_apk.ps1 2>&1 | Select-Object -Last 1 | ForEach-Object { "  $_" }
  if ($LASTEXITCODE -ne 0) { $failed += 'release verify' }

  '=== web dashboard build'
  flutter build web --no-pub -t lib/main_dashboard.dart 2>&1 | Select-Object -Last 1 | ForEach-Object { "  $_" }
  if ($LASTEXITCODE -ne 0) { $failed += 'dashboard build' }
}

# Integration runs regenerate this file with a line release builds reject.
git checkout -- android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java 2>$null

''
"Logs: $logs"
if ($failed.Count -gt 0) {
  "End-to-end suite FAILED: $($failed -join ', ')"
  exit 1
}
'End-to-end suite passed.'
