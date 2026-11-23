#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a5895552e997834eea4fb239671ee0252973227285cbd3470fa33328a535e7de", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "powershell"}
# test-cli-startup-bench-budget.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Baseline = "test/fixtures/cli-startup-bench.json",
    [string]$Report = "",
    [string]$Entry = "openclaw.mjs",
    [string]$Preset = "all",
    [int]$Runs = 1,
    [int]$Warmup = 0,
    [int]$TimeoutMs = 30000,
    [float]$MaxDurationRegressionPct = $(if ($env:OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT) { [float]$env:OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT } else { 20 }),
    [float]$MaxRssRegressionPct = $(if ($env:OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT) { [float]$env:OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT } else { 20 }),
    [switch]$Help
)

function Format-Ms($value) {
    return "$('{0:F1}' -f $value)ms"
}

function Format-Mb($value) {
    return "$('{0:F1}' -f $value)MB"
}

function Read-JsonFile($path) {
    if (Test-Path $path) {
        return Get-Content $path | ConvertFrom-Json
    }
    return $null
}

function Index-Cases($report) {
    $map = @{}
    if ($report -and $report.primary -and $report.primary.cases) {
        foreach ($case in $report.primary.cases) {
            $map[$case.id] = $case
        }
    }
    return $map
}

if ($Help) {
    Write-Output @"
Usage: test-cli-startup-bench-budget.ps1 [options]

Compare current CLI benchmark results against the checked-in fixture.

Options:
  --Baseline <path>             Baseline fixture path
  --Report <path>               Reuse an existing current benchmark report
  --Entry <path>                CLI entry to benchmark when report is omitted
  --Preset <name>               startup | real | all (default: all)
  --Runs <n>                    Measured runs per case (default: 1)
  --Warmup <n>                  Warmup runs per case (default: 0)
  --TimeoutMs <ms>              Per-run timeout (default: 30000)
  --MaxDurationRegressionPct <n>
                                Fail if avg duration regresses more than this percent
  --MaxRssRegressionPct <n>     Fail if avg RSS regresses more than this percent
  --Help                        Show this help text

Example:
  test-cli-startup-bench-budget.ps1 --Preset real --MaxDurationRegressionPct 15
"@
    exit 0
}

function Resolve-CurrentReportPath {
    if ($Report) {
        return $Report
    }
    $reportPath = ".artifacts/cli-startup-bench.current.json"
    $null = New-Item -ItemType Directory -Path ".artifacts" -Force
    $argsList = @(
        "--import"
        "tsx"
        "scripts/bench-cli-startup.ts"
        "--entry"
        $Entry
        "--preset"
        $Preset
        "--runs"
        $Runs.ToString()
        "--warmup"
        $Warmup.ToString()
        "--timeout-ms"
        $TimeoutMs.ToString()
        "--output"
        $reportPath
    )
    $process = Start-Process -FilePath "node" -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
    return $reportPath
}

$baseline = Read-JsonFile $Baseline
$current = Read-JsonFile (Resolve-CurrentReportPath)
$baselineCases = Index-Cases $baseline
$currentCases = Index-Cases $current

$failed = $false

foreach ($kv in $baselineCases.GetEnumerator()) {
    $id = $kv.Key
    $baselineCase = $kv.Value
    $currentCase = $currentCases[$id]
    if (-not $currentCase) {
        Write-Error "[test-cli-startup-bench-budget] missing current case $id"
        $failed = $true
        continue
    }

    $baselineDuration = $baselineCase.summary.durationMs.avg
    $currentDuration = $currentCase.summary.durationMs.avg
    if ([double]::IsFinite($baselineDuration) -and [double]::IsFinite($currentDuration) -and $baselineDuration -gt 0) {
        $allowedDuration = $baselineDuration * (1 + $MaxDurationRegressionPct / 100)
        if ($currentDuration -gt $allowedDuration) {
            Write-Error "[test-cli-startup-bench-budget] $($baselineCase.name) avg duration $(Format-Ms $currentDuration) exceeded $(Format-Ms $allowedDuration) (baseline $(Format-Ms $baselineDuration), +$MaxDurationRegressionPct%)."
            $failed = $true
        }
    }

    $baselineRss = $baselineCase.summary.maxRssMb.avg
    $currentRss = $currentCase.summary.maxRssMb.avg
    if ([double]::IsFinite($baselineRss) -and [double]::IsFinite($currentRss) -and $baselineRss -gt 0) {
        $allowedRss = $baselineRss * (1 + $MaxRssRegressionPct / 100)
        if ($currentRss -gt $allowedRss) {
            Write-Error "[test-cli-startup-bench-budget] $($baselineCase.name) avg RSS $(Format-Mb $currentRss) exceeded $(Format-Mb $allowedRss) (baseline $(Format-Mb $baselineRss), +$MaxRssRegressionPct%)."
            $failed = $true
        }
    }

    $durationStr = if ([double]::IsFinite($currentDuration)) { Format-Ms $currentDuration } else { "n/a" }
    $baselineDurationStr = if ([double]::IsFinite($baselineDuration)) { Format-Ms $baselineDuration } else { "n/a" }
    $rssStr = if ([double]::IsFinite($currentRss)) { Format-Mb $currentRss } else { "n/a" }
    $baselineRssStr = if ([double]::IsFinite($baselineRss)) { Format-Mb $baselineRss } else { "n/a" }
    
    Write-Output "[test-cli-startup-bench-budget] $($baselineCase.name) duration=$durationStr baseline=$baselineDurationStr rss=$rssStr baselineRss=$baselineRssStr"
}

if ($failed) {
    exit 1
}
