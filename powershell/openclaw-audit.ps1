#!/usr/bin/env pwsh
# openclaw-audit.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent
$DATE_STAMP = Get-Date -Format "yyyy-MM-dd"
$OUT = Join-Path $SCRIPT_DIR "openclaw-audit-$DATE_STAMP.log"

$OC = @("openclaw", "--no-color")

# Create initial log content
@"
================================================================
OpenClaw audit run
Started:  $(Get-Date -Format "o")
Host:     $env:COMPUTERNAME
User:     $env:USERNAME
Version:  $(try { openclaw --version 2>$null } catch { "unknown" })
Output:   $OUT
================================================================
"@ | Set-Content -Path $OUT -Encoding UTF8

function run_cmd {
    param(
        [string]$title,
        [string[]]$command
    )
    
    $timestamp = Get-Date -Format "o"
    $cmdString = ($command | ForEach-Object { "'$_'" }) -join " "
    
    # Write header to log
    @"
----------------------------------------------------------------
### $title
### $ $cmdString
### $timestamp
----------------------------------------------------------------
"@ | Add-Content -Path $OUT -Encoding UTF8
    
    # Execute command and capture output
    try {
        $output = & $command 2>&1
        $output | Add-Content -Path $OUT -Encoding UTF8
        $rc = 0
    } catch {
        # In case of external command failure, we still want to log the exit code
        # PowerShell wraps native command errors differently than bash
        if ($LASTEXITCODE) {
            $rc = $LASTEXITCODE
        } else {
            $rc = 1
        }
        # Still add any output that was captured
        if ($output) {
            $output | Add-Content -Path $OUT -Encoding UTF8
        }
    } finally {
        # If we didn't set $rc in the catch block, get it from LASTEXITCODE
        if (-not (Test-Path Variable:\rc)) {
            $rc = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }
        }
    }
    
    "[exit: $rc]" | Add-Content -Path $OUT -Encoding UTF8
}

# Run all audit commands
run_cmd "tasks audit --severity error" ($OC + @("tasks", "audit", "--severity", "error"))
run_cmd "secrets audit" ($OC + @("secrets", "audit"))
run_cmd "security audit" ($OC + @("security", "audit"))
run_cmd "plugins doctor" ($OC + @("plugins", "doctor"))
run_cmd "plugins deps" ($OC + @("plugins", "deps"))
run_cmd "plugins registry" ($OC + @("plugins", "registry"))
run_cmd "skills check" ($OC + @("skills", "check"))
run_cmd "hooks check" ($OC + @("hooks", "check"))
run_cmd "gateway status --deep" ($OC + @("gateway", "status", "--deep"))
run_cmd "channels status --probe" ($OC + @("channels", "status", "--probe"))
run_cmd "memory status --deep" ($OC + @("memory", "status", "--deep"))
run_cmd "sessions --all-agents" ($OC + @("sessions", "--all-agents"))
run_cmd "tasks list" ($OC + @("tasks", "list"))
run_cmd "cron list" ($OC + @("cron", "list"))

# Write completion footer
@"
================================================================
Audit complete: $(Get-Date -Format "o")
================================================================
"@ | Add-Content -Path $OUT -Encoding UTF8

Write-Host "Audit complete. Output: $OUT"
