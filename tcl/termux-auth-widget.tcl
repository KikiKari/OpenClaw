#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "581d5b0a5848e2d43ae2b1e3c351b10f001aec3059baaf39edf2cb3f38e5271f", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "tcl"}
# termux-auth-widget.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Auth Widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# This widget checks auth status and helps with re-auth if needed.
# It's designed for quick one-tap checking from phone home screen.

# Server hostname (via Tailscale or SSH config)
set SERVER [expr {[info exists env(OPENCLAW_SERVER)] ? $env(OPENCLAW_SERVER) : "l36"}]

# Check auth status
exec termux-toast "Checking OpenClaw auth..."

if {[catch {exec ssh $SERVER {$HOME/openclaw/scripts/claude-auth-status.sh simple}} STATUS]} {
    set EXIT_CODE 1
} else {
    set EXIT_CODE 0
}

switch -glob -- $STATUS {
    OK {
        # Get remaining time
        if {[catch {exec ssh $SERVER {$HOME/openclaw/scripts/claude-auth-status.sh json}} DETAILS]} {
            set HOURS "?"
        } else {
            # Simple JSON parsing without external tools
            if {[regexp {\"status\":\s*\"(\d+)h} $DETAILS -> hours]} {
                set HOURS $hours
            } else {
                set HOURS "?"
            }
        }

        exec termux-vibrate -d 50
        exec termux-toast "Auth OK (${HOURS}h left)"
    }

    {CLAUDE_EXPIRING OPENCLAW_EXPIRING} {
        exec termux-vibrate -d 100

        # Ask if user wants to re-auth now
        if {[catch {exec termux-dialog radio -t "Auth Expiring Soon" -v "Re-auth now,Check later,Dismiss"} CHOICE]} {
            set SELECTED "Dismiss"
        } else {
            # Parse JSON response manually
            if {[regexp {\"text\":\s*\"([^\"]*)\"} $CHOICE -> text]} {
                set SELECTED $text
            } else {
                set SELECTED "Dismiss"
            }
        }

        switch -- $SELECTED {
            "Re-auth now" {
                exec termux-toast "Opening auth page..."
                exec termux-open-url "https://console.anthropic.com/settings/api-keys"

                # Show instructions
                catch {exec termux-dialog confirm -t "Re-auth Instructions" -i "1. Create/copy API key from browser\n2. Return here and tap OK\n3. SSH to server and paste key"}

                # Open terminal to server
                catch {exec am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN}
                exec termux-toast "Run: ssh $SERVER '\$HOME/openclaw/scripts/mobile-reauth.sh'"
            }
            default {
                exec termux-toast "Reminder: Auth expires soon"
            }
        }
    }

    {CLAUDE_EXPIRED OPENCLAW_EXPIRED} {
        exec termux-vibrate -d 300

        if {[catch {exec termux-dialog radio -t "Auth Expired!" -v "Re-auth now,Dismiss"} CHOICE]} {
            set SELECTED "Dismiss"
        } else {
            # Parse JSON response manually
            if {[regexp {\"text\":\s*\"([^\"]*)\"} $CHOICE -> text]} {
                set SELECTED $text
            } else {
                set SELECTED "Dismiss"
            }
        }

        switch -- $SELECTED {
            "Re-auth now" {
                exec termux-toast "Opening auth page..."
                exec termux-open-url "https://console.anthropic.com/settings/api-keys"

                catch {exec termux-dialog confirm -t "Re-auth Steps" -i "1. Create/copy API key from browser\n2. Return here and tap OK to SSH"}

                catch {exec am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN}
                exec termux-toast "Run: ssh $SERVER '\$HOME/openclaw/scripts/mobile-reauth.sh'"
            }
            default {
                exec termux-toast "Warning: OpenClaw won't work until re-auth"
            }
        }
    }

    default {
        exec termux-vibrate -d 200
        exec termux-toast "Error: $STATUS"
    }
}
