# A read-only check of رحلتي on a real phone, through the installed app.
#
#   powershell -ExecutionPolicy Bypass -File tool\phone_journey_check.ps1 -Serial <adb serial> [-Out build\phone_check]
#
# Install the build first with `adb install -r` (which keeps the phone's
# data). Never `flutter test` on a phone that holds real data: a test run
# reinstalls the app and uninstalls it at the end, and the data goes with it.
param([string]$Serial, [string]$Out = 'build\phone_check')
# Drives the installed release app on a real phone through adb, finding
# controls by their accessibility labels (Flutter semantics -> content-desc),
# taking a screenshot at each step and checking the expected labels are on
# screen. Read-only: it opens screens and sheets, it never joins, reviews or
# writes anything, so the phone's real journey and the live database are left
# as they were.
$ErrorActionPreference = 'Continue'
$adb = "$HOME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$pkg = 'com.prodktstudio.tayebqalbak'
New-Item -ItemType Directory -Force $Out | Out-Null
$script:results = @()

# The screen as uiautomator sees it. A dump can fail outright ("null root
# node"), or succeed before Flutter has built the labels a screen reader
# reads, which on a slow emulator comes back with none at all. Either way
# the old file is never reused, and the dump is tried again until it has
# labels in it.
function Dump {
  for ($try = 0; $try -lt 8; $try++) {
    & $adb -s $Serial shell rm -f /sdcard/ui.xml 2>&1 | Out-Null
    & $adb -s $Serial shell uiautomator dump /sdcard/ui.xml 2>&1 | Out-Null
    Remove-Item "$Out\ui.xml" -ErrorAction SilentlyContinue
    & $adb -s $Serial pull /sdcard/ui.xml "$Out\ui.xml" 2>&1 | Out-Null
    if (Test-Path "$Out\ui.xml") {
      $xml = [xml](Get-Content "$Out\ui.xml" -Raw -Encoding UTF8)
      $labelled = @($xml.SelectNodes('//node') | Where-Object { "$($_.'content-desc')".Trim() })
      if ($labelled.Count -gt 0) { return $xml }
    }
    Start-Sleep -Milliseconds 1000
  }
  return [xml]'<hierarchy/>'
}

function Nodes($xml) {
  $xml.SelectNodes('//node')
}

function Find([string]$text) {
  $xml = Dump
  foreach ($n in (Nodes $xml)) {
    # A card scrolled out of sight is still listed, at [0,0][0,0]: it is
    # not there to tap yet.
    if ($n.bounds -eq '[0,0][0,0]') { continue }
    $label = "$($n.'content-desc') $($n.text)"
    if ($label.Contains($text)) { return $n }
  }
  return $null
}

# Taps the first control whose label starts with one of [prefixes]: some
# words, like «حفظك», also sit inside hadith titles on the tree.
function TapStart([string[]]$prefixes, [int]$tries = 6) {
  for ($i = 0; $i -lt $tries; $i++) {
    $xml = Dump
    foreach ($n in (Nodes $xml)) {
      $label = "$($n.'content-desc')".Trim()
      foreach ($p in $prefixes) {
        if ($label.StartsWith($p)) {
          $c = Center $n
          & $adb -s $Serial shell input tap $c[0] $c[1]
          Start-Sleep -Milliseconds 1800
          return $true
        }
      }
    }
    & $adb -s $Serial shell input swipe 540 1500 540 900 400
    Start-Sleep -Milliseconds 900
  }
  return $false
}

function Center($node) {
  $m = [regex]::Match($node.bounds, '\[(\d+),(\d+)\]\[(\d+),(\d+)\]')
  $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
  $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
  return @([int]$x, [int]$y)
}

# The top of the floating bottom bar, from its first tab.
function BarTop($xml) {
  $homeTab = [string][char]0x0627 + [char]0x0644 + [char]0x0631 + [char]0x0626 + [char]0x064A + [char]0x0633 + [char]0x064A + [char]0x0629
  foreach ($n in (Nodes $xml)) {
    if ("$($n.'content-desc')".Trim() -eq $homeTab) {
      $m = [regex]::Match($n.bounds, '\[(\d+),(\d+)\]')
      return [int]$m.Groups[2].Value
    }
  }
  return 100000
}

# [content]: a card in the page, not the bottom bar. The bar floats over the
# lowest part of the screen, so a card that sits under it is scrolled up
# before it is tapped, or the tap lands on the bar.
function Tap([string]$text, [int]$tries = 6, [switch]$content) {
  for ($i = 0; $i -lt $tries; $i++) {
    $n = Find $text
    if ($n -and $content) {
      $bar = BarTop (Dump)
      $c = Center $n
      if ($c[1] -gt $bar - 60) {
        # Slowly, so the list does not glide on: a tap on a moving list
        # only stops it.
        & $adb -s $Serial shell input swipe 540 ($bar - 300) 540 ($bar - 1000) 1500
        Start-Sleep -Milliseconds 2500
        $n = Find $text
      }
    }
    if ($n) {
      $c = Center $n
      Write-Host "  tap '$text' at $($c[0]),$($c[1]) ($($n.bounds))"
      & $adb -s $Serial shell input tap $c[0] $c[1]
      Start-Sleep -Milliseconds 1800
      return $true
    }
    # Not on screen yet: scroll the page down a little and look again.
    & $adb -s $Serial shell input swipe 540 1500 540 900 400
    Start-Sleep -Milliseconds 900
  }
  return $false
}

function Shot([string]$name) {
  & $adb -s $Serial shell screencap -p /sdcard/e2e.png
  & $adb -s $Serial pull /sdcard/e2e.png "$Out\$name.png" 2>&1 | Out-Null
}

function Check([string]$step, [string[]]$expect) {
  $xml = Dump
  $all = (Nodes $xml | ForEach-Object { "$($_.'content-desc') $($_.text)" }) -join "`n"
  $missing = @($expect | Where-Object { -not $all.Contains($_) })
  $ok = $missing.Count -eq 0
  $script:results += [pscustomobject]@{ Step = $step; Pass = $ok; Missing = ($missing -join ' | ') }
  Shot ($step -replace '[^\w-]', '_')
}

function Back { & $adb -s $Serial shell input keyevent 4; Start-Sleep -Milliseconds 1500 }

# A clean start of the installed app, its data kept.
& $adb -s $Serial shell am force-stop $pkg
& $adb -s $Serial shell am start -n "$pkg/.MainActivity" | Out-Null
# Past the splash: until the ring or the first-launch offer is on screen.
$deadline = (Get-Date).AddSeconds(40)
do {
  Start-Sleep -Seconds 2
  $ready = (Find 'من ٣ خطوات اليوم') -or (Find 'ليس الآن')
} until ($ready -or (Get-Date) -gt $deadline)
# The home is built under the splash before the splash fades, so wait for
# the splash's own line to go as well; a tap before then lands on it.
$deadline = (Get-Date).AddSeconds(20)
while ((Find 'هدايات قلبية') -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
# A fresh install offers reminders first; decline, as a reader might.
if (Find 'ليس الآن') { Tap 'ليس الآن' 1 | Out-Null }

# 1. Home: the ring counts today's steps.
Check '01-home-ring' @('من ٣ خطوات اليوم')
# 2. The ring opens the day's steps.
if (Tap 'من ٣ خطوات اليوم') { Check '02-steps-page' @('خطوات اليوم', 'اقرأ رسالة اليوم', 'اكتب رسالتك') } else { $script:results += [pscustomobject]@{ Step = '02-steps-page'; Pass = $false; Missing = 'ring not found' } }
Back
# 3. رحلتي: tree, steps button, memo button, numbers, board.
if (Tap 'رحلتي') { Check '03-journey-top' @('خطوات اليوم', 'الحديث ١:', 'الحديث ٤٢:') }
& $adb -s $Serial shell input swipe 540 1700 540 700 500; Start-Sleep -Milliseconds 1200
Check '04-journey-numbers' @('حصاد الأسبوع', 'حصاد رحلتك', 'الاستمرارية', 'كل نقاطك', 'حفظت')
# 4. «كيف تُحسب؟» opens and closes.
if (Tap 'كيف تُحسب؟' -content) { Check '05-how-counted' @('كيف تُحسب أرقامك؟', 'النقاط') ; Back }
# 5. The memo page.
& $adb -s $Serial shell input swipe 540 900 540 1600 500; Start-Sleep -Milliseconds 1000
if (TapStart @('ابدأ حفظك', 'راجع حفظك')) { Check '06-memo-page' @('راجع حفظك'); Back }
# 6. The board.
if (Tap 'لوحة الأسبوع' -content) {
  # The reader's own card sits under the board: scroll down to it.
  & $adb -s $Serial shell input swipe 540 1700 540 800 500; Start-Sleep -Milliseconds 1200
  Check '07-board' @('لوحة الأسبوع', 'نقاطك هذا الأسبوع'); Back
}
# 7. The steps button on رحلتي opens the same page.
& $adb -s $Serial shell input swipe 540 700 540 1700 500; Start-Sleep -Milliseconds 1000
if (Tap 'خطوات اليوم،' -content) { Check '08-steps-from-journey' @('اقرأ رسالة اليوم'); Back }
# 8. Back home: nothing crashed along the way.
Back
$alive = (& $adb -s $Serial shell pidof $pkg)
$script:results += [pscustomobject]@{ Step = '09-still-running'; Pass = [bool]$alive; Missing = '' }

$script:results | Format-Table -AutoSize | Out-String -Width 200
$failed = @($script:results | Where-Object { -not $_.Pass }).Count
"passed: $(@($script:results).Count - $failed) / $(@($script:results).Count)"
