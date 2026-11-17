#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "3b358847b5d5e3d621ab81ffa0ebd8da07e156515b0be94ebe9ff86a40442a9b", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "powershell"}
# openclaw-audit.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DateStamp = Get-Date -Format "yyyy-MM-dd"
$Out = Join-Path $ScriptDir "openclaw-audit-$DateStamp.log"

$OC = @("openclaw", "--no-color")

# Initialize log file with header
@"
================================================================
OpenClaw audit run
Started:  $(Get-Date -Format "o")
Host:     $env:COMPUTERNAME
User:     $env:USERNAME
Version:  $(openclaw --version 2>$null || "unknown")
Output:   $Out
================================================================
"@ | Out-File -FilePath $Out -Encoding UTF8

function Run-Cmd {
    param(
        [string]$Title,
        [string[]]$Command
    )

    # Write section header to log
    @"
----------------------------------------------------------------
### $Title
### \$ $($Command -join " ")
### $(Get-Date -Format "o")
----------------------------------------------------------------
"@ | Out-File -FilePath $Out -Append -Encoding UTF8

    # Execute command and capture output and exit code
    try {
        $result = & $Command[0] $Command[1..($Command.Length - 1)] 2>&1
        $exitCode = 0
        if ($LASTEXITCODE) { $exitCode = $LASTEXITCODE }
    } catch {
        $result = $_.Exception.Message
        $exitCode = 1
    }

    # Append command output and exit code to log
    $result | Out-File -FilePath $Out -Append -Encoding UTF8
    "[exit: $exitCode]" | Out-File -FilePath $Out -Append -Encoding UTF8
}

Run-Cmd "tasks audit --severity error" ($OC + "tasks", "audit", "--severity", "error")
Run-Cmd "secrets audit" ($OC + "secrets", "audit")
Run-Cmd "security audit" ($OC + "security", "audit")
Run-Cmd "plugins doctor" ($OC + "plugins", "doctor")
Run-Cmd "plugins deps" ($OC + "plugins", "deps")
Run-Cmd "plugins registry" ($OC + "plugins", "registry")
Run-Cmd "skills check" ($OC + "skills", "check")
Run-Cmd "hooks check" ($OC + "hooks", "check")
Run-Cmd "gateway status --deep" ($OC + "gateway", "status", "--deep")
Run-Cmd "channels status --probe" ($OC + "channels", "status", "--probe")
Run-Cmd "memory status --deep" ($OC + "memory", "status", "--deep")
Run-Cmd "sessions --all-agents" ($OC + "sessions", "--all-agents")
Run-Cmd "tasks list" ($OC + "tasks", "list")
Run-Cmd "cron list" ($OC + "cron", "list")

# Finalize log file
@"
================================================================
Audit complete: $(Get-Date -Format "o")
================================================================
"@ | Out-File -FilePath $Out -Append -Encoding UTF8

Write-Host "Audit complete. Output: $Out"
