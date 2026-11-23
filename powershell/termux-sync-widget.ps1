#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "725a32a7943de0b2bda344210b9b8a63e5909a8ce39cbfb1b4e0d109fb120b4f", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "powershell"}
# termux-sync-widget.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw OAuth Sync Widget
# Syncs Claude Code tokens to OpenClaw on l36 server
# Place in ~/.shortcuts/ on phone for Termux:Widget

# Function to simulate termux-toast using notify-send or Write-Host
function Show-Toast {
    param([string]$Message)
    if (Get-Command notify-send -ErrorAction SilentlyContinue) {
        notify-send "Termux Widget" $Message
    } else {
        Write-Host $Message
    }
}

# Function to simulate termux-vibrate using termux-api if available
function Invoke-Vibrate {
    param([int]$Duration)
    if (Get-Command termux-vibrate -ErrorAction SilentlyContinue) {
        termux-vibrate -d $Duration
    }
}

Show-Toast "Syncing OpenClaw auth..."

# Run sync on l36 server
$env:SERVER = if ($env:OPENCLAW_SERVER) { $env:OPENCLAW_SERVER } else { "l36" }

try {
    $result = ssh $env:SERVER '/home/admin/openclaw/scripts/sync-claude-code-auth.sh' 2>&1
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        # Extract expiry time from output
        $expiryLine = $result | Where-Object { $_ -match "Token expires:" }
        if ($expiryLine) {
            $expiry = ($expiryLine -split ":", 2)[1].Trim()
        } else {
            $expiry = ""
        }
        
        Invoke-Vibrate -Duration 100
        Show-Toast "OpenClaw synced! Expires:$expiry"
        
        # Optional: restart openclaw service
        ssh $env:SERVER 'systemctl --user restart openclaw' 2>$null
    } else {
        Invoke-Vibrate -Duration 300
        Show-Toast "Sync failed: $($result -join "`n")"
    }
} catch {
    Invoke-Vibrate -Duration 300
    Show-Toast "Sync failed: $($_.Exception.Message)"
}
