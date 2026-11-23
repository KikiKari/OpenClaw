#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "0d1067d07670dea089a09c1db3171317c49ce34542ab2a863f0d4444a2b355fc", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "powershell"}
# termux-quick-auth.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Quick Auth Check - Minimal widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# One-tap: shows status toast
# If expired: directly opens auth URL

$SERVER = if ($env:OPENCLAW_SERVER) { $env:OPENCLAW_SERVER } else { "l36" }

try {
    $STATUS = ssh -o ConnectTimeout=5 $SERVER '$HOME/openclaw/scripts/claude-auth-status.sh simple' 2>&1
}
catch {
    $STATUS = "Connection error"
}

switch -Wildcard ($STATUS) {
    "OK" {
        termux-toast -s "Auth OK"
    }
    "*EXPIRING*" {
        termux-vibrate -d 100
        termux-toast "Auth expiring soon - tap again if needed"
    }
    {($_ -like "*EXPIRED*") -or ($_ -like "*MISSING*")} {
        termux-vibrate -d 200
        termux-toast "Auth expired - opening console..."
        termux-open-url "https://console.anthropic.com/settings/api-keys"
        Start-Sleep -Seconds 2
        termux-notification -t "OpenClaw Re-Auth" -c "After getting key, run: ssh $SERVER '~/openclaw/scripts/mobile-reauth.sh'" --id openclaw-auth
    }
    default {
        termux-toast "Connection error"
    }
}
