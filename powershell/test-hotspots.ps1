#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "faea4c903148f8021c3754863fbcb812e0d67349cd68d66bf0dea994273043e0", "source_sha256": "4252ea2457fcacdde20bb203479a1fcfbb9fa70ecf111838b7f2ac7c0902a093", "target_language": "powershell"}
# test-hotspots.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-hotspots.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Import required functions
. "$PSScriptRoot/lib/vitest-report-cli-utils.ps1"
. "$PSScriptRoot/test-report-utils.ps1"

# Check for --help flag
if ($args -contains "--help") {
    Write-Output @"
Usage: pwsh scripts/test-hotspots.ps1 [options]

Print the slowest test files from a Vitest JSON report.

Options:
  --config <path>    Vitest config to run when no report is supplied
  --report <path>    Reuse an existing Vitest JSON report
  --limit <count>    Number of files to print (default: 20)
  --help             Show this help text

Examples:
  pwsh scripts/test-hotspots.ps1
  pwsh scripts/test-hotspots.ps1 --config test/vitest/vitest.channels.config.ts --limit 10
  pwsh scripts/test-hotspots.ps1 --report /tmp/vitest-report.json
"@
    exit 0
}

# Parse arguments
$opts = Parse-VitestReportArgs -args $args -defaults @{
    config = "test/vitest/vitest.unit.config.ts"
    limit = 20
}

# Load report
$report = Load-VitestReportFromArgs -opts $opts -cacheKey "openclaw-vitest-hotspots"

# Collect file durations and sort by duration descending
$fileResults = Collect-VitestFileDurations -report $report | Sort-Object { $_.durationMs } -Descending

# Get top results based on limit
$top = $fileResults | Select-Object -First $opts.limit

# Calculate total duration
$totalDurationMs = ($fileResults | Measure-Object -Property durationMs -Sum).Sum

# Output header
Write-Output ""
Write-Output "[test-hotspots] top $($top.Count) by file duration ($(Format-Ms $totalDurationMs) total)"

# Output each file result
for ($i = 0; $i -lt $top.Count; $i++) {
    $item = $top[$i]
    $label = ($i + 1).ToString().PadLeft(2)
    $duration = (Format-Ms $item.durationMs).PadLeft(10)
    $tests = $item.testCount.ToString().PadLeft(4)
    Write-Output "$label. $duration | tests=$tests | $($item.file)"
}
