#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "2376e5df1ebfa706d793c900d407c931da2e11c7a58c772570f4b9a32f215f87", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "tcl"}
# termux-quick-auth.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Quick Auth Check - Minimal widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# One-tap: shows status toast
# If expired: directly opens auth URL

# Get server from environment or default
set SERVER [expr {[info exists ::env(OPENCLAW_SERVER)] ? $::env(OPENCLAW_SERVER) : "l36"}]

# Execute SSH command and capture output
if {[catch {exec ssh -o ConnectTimeout=5 $SERVER {$HOME/openclaw/scripts/claude-auth-status.sh simple}} STATUS]} {
    set STATUS $::errorInfo
}

# Process the result
switch -glob $STATUS {
    OK {
        exec termux-toast -s "Auth OK"
    }
    *EXPIRING* {
        exec termux-vibrate -d 100
        exec termux-toast "Auth expiring soon - tap again if needed"
    }
    *EXPIRED* - *MISSING* {
        exec termux-vibrate -d 200
        exec termux-toast "Auth expired - opening console..."
        exec termux-open-url "https://console.anthropic.com/settings/api-keys"
        after 2000
        exec termux-notification -t "OpenClaw Re-Auth" -c "After getting key, run: ssh $SERVER '~/openclaw/scripts/mobile-reauth.sh'" --id openclaw-auth
    }
    default {
        exec termux-toast "Connection error"
    }
}
