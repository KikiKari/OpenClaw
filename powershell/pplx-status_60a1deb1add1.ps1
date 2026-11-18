#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "3291053dbf3637d0e21bfaa5640c3f1a5830ba946cf56959fac2925e8ae0a25f", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "powershell"}
# pplx-status.sh — portiert nach powershell
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.
$ErrorActionPreference = 'Stop'
$CFG = if ($env:PERPLEXITY_CONFIG_DIR) { $env:PERPLEXITY_CONFIG_DIR } else { "$env:HOME/.perplexity-mcp" }
$PROFILE = if ($env:PERPLEXITY_PROFILE) { $env:PERPLEXITY_PROFILE } else { "codespace" }
$STAT = "$CFG/profiles/$PROFILE/daemon-status.json"
if (Test-Path $STAT) {
    Get-Content $STAT | ConvertFrom-Json | ConvertTo-Json -Depth 10
} else {
    Write-Output "no daemon-status.json at $STAT"
}
Write-Output "--- recent auth lines ---"
if (Test-Path "$CFG/daemon.log") {
    Select-String -Path "$CFG/daemon.log" -Pattern 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in' -CaseSensitive $false | 
        ForEach-Object { $_.Line } | 
        Select-Object -Last 6
}
