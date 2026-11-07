# The static suite: everything that can be checked without running the app.
#
#   powershell -ExecutionPolicy Bypass -File tool\static_checks.ps1
#
#  1. flutter analyze, with the strict rules in analysis_options.yaml.
#  2. dart format, which must have nothing left to change.
#  3. test/static: the project's own rules, read from the source (layers,
#     the reader-facing voice, firestore.rules, privacy parity, secrets,
#     assets, suite entries).
#
# Exits non-zero if any step fails, after running all of them.
$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)
$failed = @()

function Step($name, [scriptblock]$run) {
  "=== $name"
  $output = & $run 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  $output | Select-Object -Last 6 | ForEach-Object { "  $_" }
  if ($code -ne 0) { $script:failed += $name; "  FAILED ($code)" } else { "  ok" }
}

Step 'analyze (strict)' { flutter analyze --no-pub }
Step 'format' { dart format --output=none --set-exit-if-changed lib test integration_test tool }
Step 'project checks' { flutter test --no-pub test/static }

""
if ($failed.Count -gt 0) {
  "Static suite FAILED: $($failed -join ', ')"
  exit 1
}
"Static suite passed."
