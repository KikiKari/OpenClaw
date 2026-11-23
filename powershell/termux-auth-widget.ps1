#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8e30b93a0c688fb247f39f09628747ab6fef5bb09dcfc9ff3b5615ad916c809d", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "powershell"}
# termux-auth-widget.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Auth Widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# This widget checks auth status and helps with re-auth if needed.
# It's designed for quick one-tap checking from phone home screen.

# Server hostname (via Tailscale or SSH config)
$SERVER = if ($env:OPENCLAW_SERVER) { $env:OPENCLAW_SERVER } else { "l36" }

# Check auth status
& termux-toast "Checking OpenClaw auth..."

# Execute SSH command and capture output and exit code
$sshResult = ssh $SERVER '$HOME/openclaw/scripts/claude-auth-status.sh simple' 2>&1
$EXIT_CODE = $LASTEXITCODE
$STATUS = $sshResult -join "`n"

switch ($STATUS) {
    "OK" {
        # Get remaining time
        $detailsResult = ssh $SERVER '$HOME/openclaw/scripts/claude-auth-status.sh json' 2>&1
        $DETAILS = $detailsResult -join "`n"
        
        # Extract hours using regex (PowerShell equivalent of grep -oP '\d+(?=h)')
        if ($DETAILS -match '"status":"(\d+)h') {
            $HOURS = $matches[1]
        } else {
            $HOURS = "?"
        }

        & termux-vibrate -d 50
        & termux-toast "Auth OK (${HOURS}h left)"
    }

    {($_ -eq "CLAUDE_EXPIRING") -or ($_ -eq "OPENCLAW_EXPIRING")} {
        & termux-vibrate -d 100

        # Ask if user wants to re-auth now
        $choiceResult = & termux-dialog radio -t "Auth Expiring Soon" -v "Re-auth now,Check later,Dismiss"
        $CHOICE = $choiceResult | ConvertFrom-Json
        $SELECTED = if ($CHOICE.text) { $CHOICE.text } else { "Dismiss" }

        switch ($SELECTED) {
            "Re-auth now" {
                & termux-toast "Opening auth page..."
                & termux-open-url "https://console.anthropic.com/settings/api-keys"

                # Show instructions
                & termux-dialog confirm -t "Re-auth Instructions" -i "1. Create/copy API key from browser`n2. Return here and tap OK`n3. SSH to server and paste key"

                # Open terminal to server
                & am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN
                & termux-toast "Run: ssh $SERVER '`$HOME/openclaw/scripts/mobile-reauth.sh'"
            }
            default {
                & termux-toast "Reminder: Auth expires soon"
            }
        }
    }

    {($_ -eq "CLAUDE_EXPIRED") -or ($_ -eq "OPENCLAW_EXPIRED")} {
        & termux-vibrate -d 300

        $choiceResult = & termux-dialog radio -t "Auth Expired!" -v "Re-auth now,Dismiss"
        $CHOICE = $choiceResult | ConvertFrom-Json
        $SELECTED = if ($CHOICE.text) { $CHOICE.text } else { "Dismiss" }

        switch ($SELECTED) {
            "Re-auth now" {
                & termux-toast "Opening auth page..."
                & termux-open-url "https://console.anthropic.com/settings/api-keys"

                & termux-dialog confirm -t "Re-auth Steps" -i "1. Create/copy API key from browser`n2. Return here and tap OK to SSH"

                & am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN
                & termux-toast "Run: ssh $SERVER '`$HOME/openclaw/scripts/mobile-reauth.sh'"
            }
            default {
                & termux-toast "Warning: OpenClaw won't work until re-auth"
            }
        }
    }

    default {
        & termux-vibrate -d 200
        & termux-toast "Error: $STATUS"
    }
}
