#!/usr/bin/tclsh
# abstraction-provenance: {"artifact_sha256": "da871e6a8ed8accdacb63d81901d36e2630e6703a4b066c5f8b006b579c82f10", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "tcl"}
# termux-sync-widget.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw OAuth Sync Widget
# Syncs Claude Code tokens to OpenClaw on l36 server
# Place in ~/.shortcuts/ on phone for Termux:Widget

# Function to show toast notification
proc termux_toast {message} {
    exec termux-toast $message
}

# Function to vibrate device
proc termux_vibrate {duration} {
    exec termux-vibrate -d $duration
}

# Main script
termux_toast "Syncing OpenClaw auth..."

# Get server name from environment or default to l36
set server "l36"
if {[info exists ::env(OPENCLAW_SERVER)] && $::env(OPENCLAW_SERVER) ne ""} {
    set server $::env(OPENCLAW_SERVER)
}

# Run sync on remote server
if {[catch {
    set result [exec ssh $server /home/admin/openclaw/scripts/sync-claude-code-auth.sh]
    set exit_code 0
} error]} {
    set result $error
    set exit_code 1
}

if {$exit_code == 0} {
    # Extract expiry time from output
    set expiry ""
    foreach line [split $result \n] {
        if {[string match "*Token expires:*" $line]} {
            set expiry [string range $line [string first ":" $line]+1 end]
            break
        }
    }

    termux_vibrate 100
    termux_toast "OpenClaw synced! Expires:$expiry"

    # Optional: restart openclaw service
    catch {exec ssh $server systemctl --user restart openclaw}
} else {
    termux_vibrate 300
    termux_toast "Sync failed: $result"
}
