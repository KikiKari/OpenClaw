#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "49687f518e0ee649ee3ab254f5962b71a1b69ed6ae8d84bc9eb1dda6eff862a2", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "powershell"}
# check-cli-startup-memory.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Plattformüberprüfung
$isLinux = $IsLinux
$isMac = $IsMacOS

if (-not ($isLinux -or $isMac)) {
    Write-Host "[startup-memory] Skipping on unsupported platform: $((Get-Variable IsLinux -ErrorAction SilentlyContinue).Value ? 'Linux' : (Get-Variable IsMacOS -ErrorAction SilentlyContinue).Value ? 'macOS' : 'Windows')"
    exit 0
}

# Pfade und Umgebungsvariablen
$repoRoot = Get-Location
$tmpHome = Join-Path ([System.IO.Path]::GetTempPath()) "openclaw-startup-memory-$([System.Guid]::NewGuid().ToString())"
New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
$tmpDir = $env:TMPDIR ?? $env:TEMP ?? [System.IO.Path]::GetTempPath()
$rssHookPath = Join-Path $tmpHome "measure-rss.mjs"
$MAX_RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="

# RSS Hook Script erstellen
$rssHookContent = @"
process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('${MAX_RSS_MARKER}' + String(usage.maxRSS));
});
"@
Set-Content -Path $rssHookPath -Value $rssHookContent -Encoding UTF8

# Standardlimits definieren
$DEFAULT_LIMITS_MB = @{
    help = 100
    statusJson = 400
    gatewayStatus = 500
}

# Testfälle definieren
$cases = @(
    @{
        id = "help"
        label = "--help"
        args = @("openclaw.mjs", "--help")
        limitMb = [int](($env:OPENCLAW_STARTUP_MEMORY_HELP_MB ?? $DEFAULT_LIMITS_MB.help))
    },
    @{
        id = "statusJson"
        label = "status --json"
        args = @("openclaw.mjs", "status", "--json")
        limitMb = [int](($env:OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB ?? $DEFAULT_LIMITS_MB.statusJson))
    },
    @{
        id = "gatewayStatus"
        label = "gateway status"
        args = @("openclaw.mjs", "gateway", "status")
        limitMb = [int](($env:OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB ?? $DEFAULT_LIMITS_MB.gatewayStatus))
    }
)

function Format-FixGuidance {
    param (
        [hashtable]$testCase,
        [string]$details
    )
    
    $command = "node $($testCase.args -join ' ')"
    $guidance = @(
        "[startup-memory] Fix guidance"
        "Case: $($testCase.label)"
        "Command: $command"
        "Next steps:"
        "1. Run `$command` locally on the built tree."
        "2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path."
        "3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory."
        "LLM prompt:"
        '"OpenClaw startup-memory CI failed for ''$($testCase.label)''. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:'
        "$details"
        '"'
    )
    return ($guidance -join "`n") + "`n"
}

function Format-Failure {
    param (
        [hashtable]$testCase,
        [string]$message,
        [string]$details = ""
    )
    
    $trimmedDetails = $details.Trim()
    $sections = @($message)
    if ($trimmedDetails) {
        $sections += $trimmedDetails
    }
    $sections += Format-FixGuidance -testCase $testCase -details ($trimmedDetails ?? $message)
    return ($sections -join "`n`n")
}

function Parse-MaxRssMb {
    param ([string]$stderr)
    
    $matches = [regex]::Matches($stderr, "^${MAX_RSS_MARKER}(\d+)\s*$", "Multiline")
    if ($matches.Count -eq 0) {
        return $null
    }
    $lastMatch = $matches[$matches.Count - 1]
    return [double]($lastMatch.Groups[1].Value) / 1024
}

function Build-BenchEnv {
    $envVars = @{
        HOME = $tmpHome
        USERPROFILE = $tmpHome
        XDG_CONFIG_HOME = Join-Path $tmpHome ".config"
        XDG_DATA_HOME = Join-Path $tmpHome ".local" "share"
        XDG_CACHE_HOME = Join-Path $tmpHome ".cache"
        PATH = $env:PATH ?? ""
        TMPDIR = $tmpDir
        TEMP = $tmpDir
        TMP = $tmpDir
        LANG = $env:LANG ?? "C.UTF-8"
        TERM = $env:TERM ?? "dumb"
    }
    
    if ($env:LC_ALL) {
        $envVars["LC_ALL"] = $env:LC_ALL
    }
    if ($env:CI) {
        $envVars["CI"] = $env:CI
    }
    if ($env:NODE_DISABLE_COMPILE_CACHE) {
        $envVars["NODE_DISABLE_COMPILE_CACHE"] = $env:NODE_DISABLE_COMPILE_CACHE
    } else {
        # Keep the regression check focused on app/runtime startup, not Node's
        # one-shot compile cache overhead, which varies across runner builds.
        $envVars["NODE_DISABLE_COMPILE_CACHE"] = "1"
    }
    # Keep the benchmark on a single process so RSS reflects the actual command
    # path rather than the warning-suppression respawn wrapper.
    $envVars["OPENCLAW_NO_RESPAWN"] = "1"
    
    return $envVars
}

function Run-Case {
    param ([hashtable]$testCase)
    
    $env = Build-BenchEnv
    
    # Umgebungsvariablen für den Prozess setzen
    $originalEnv = @{}
    foreach ($key in $env.Keys) {
        $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $env[$key])
    }
    
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = "node"
        $startInfo.Arguments = "--import `"$rssHookPath`" " + ($testCase.args -join " ")
        $startInfo.WorkingDirectory = $repoRoot
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        
        $maxRssMb = Parse-MaxRssMb -stderr $stderr
        $matrixBootstrapWarning = $stderr -match "matrix: crypto runtime bootstrap failed"
        
        if ($process.ExitCode -ne 0) {
            throw (Format-Failure -testCase $testCase -message "$($testCase.label) exited with $($process.ExitCode)" -details ($stderr.Trim() ?? $stdout ?? ""))
        }
        if ($null -eq $maxRssMb) {
            throw (Format-Failure -testCase $testCase -message "$($testCase.label) did not report max RSS" -details $stderr)
        }
        if ($matrixBootstrapWarning) {
            throw (Format-Failure -testCase $testCase -message "$($testCase.label) triggered Matrix crypto bootstrap during startup")
        }
        if ($maxRssMb -gt $testCase.limitMb) {
            throw (Format-Failure -testCase $testCase -message "$($testCase.label) used $($maxRssMb.ToString('F1')) MB RSS (limit $($testCase.limitMb) MB)")
        }
        
        Write-Host "[startup-memory] $($testCase.label): $($maxRssMb.ToString('F1')) MB RSS (limit $($testCase.limitMb) MB)"
    }
    finally {
        # Umgebungsvariablen zurücksetzen
        foreach ($key in $originalEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
        }
    }
}

try {
    foreach ($testCase in $cases) {
        Run-Case -testCase $testCase
    }
}
finally {
    if (Test-Path $tmpHome) {
        Remove-Item -Path $tmpHome -Recurse -Force
    }
}
