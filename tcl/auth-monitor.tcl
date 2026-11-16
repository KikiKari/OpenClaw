#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "e0e53569c538cdd347e4ba5e9ca2b97c6ed4e6c3d9789600bb2704980e5c2cb9", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "tcl"}
# auth-monitor.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Auth Expiry Monitor
# Run via cron or systemd timer to get proactive notifications
# before Claude Code auth expires.
#
# Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.tcl
#
# Environment variables:
#   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
#   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
#   WARN_HOURS   - Hours before expiry to warn (default: 2)

# Configuration
set WARN_HOURS [expr {[info exists ::env(WARN_HOURS)] ? $::env(WARN_HOURS) : 2}]
set NOTIFY_PHONE [expr {[info exists ::env(NOTIFY_PHONE)] ? $::env(NOTIFY_PHONE) : ""}]
set NOTIFY_NTFY [expr {[info exists ::env(NOTIFY_NTFY)] ? $::env(NOTIFY_NTFY) : ""}]

# Paths
set SCRIPT_DIR [file dirname [info script]]
set CLAUDE_CREDS [file join $::env(HOME) .claude .credentials.json]
set STATE_FILE [file join $::env(HOME) .openclaw auth-monitor-state]

# State tracking to avoid spam
file mkdir [file dirname $STATE_FILE]
if {[catch {set LAST_NOTIFIED [exec cat $STATE_FILE]}]} {
    set LAST_NOTIFIED 0
}
set NOW [clock seconds]

# Only notify once per hour max
set MIN_INTERVAL 3600

proc send_notification {message {priority "default"}} {
    global NOW LAST_NOTIFIED MIN_INTERVAL NOTIFY_PHONE NOTIFY_NTFY SCRIPT_DIR
    puts "[clock format $NOW -format {%Y-%m-%d %H:%M:%S}] - $message"

    # Check if we notified recently
    if {($NOW - $LAST_NOTIFIED) < $MIN_INTERVAL} {
        puts "Skipping notification (sent recently)"
        return
    }

    # Send via OpenClaw if phone configured and auth still valid
    if {$NOTIFY_PHONE ne ""} {
        # Check if we can still use openclaw
        if {![catch {exec $SCRIPT_DIR/claude-auth-status.sh simple} result] && ([string match "*OK*" $result] || [string match "*EXPIRING*" $result])} {
            puts "Sending via OpenClaw to $NOTIFY_PHONE..."
            if {[catch {exec openclaw send --to $NOTIFY_PHONE --message $message} err]} {
                # Ignore errors
            }
        }
    }

    # Send via ntfy.sh if configured
    if {$NOTIFY_NTFY ne ""} {
        puts "Sending via ntfy.sh to $NOTIFY_NTFY..."
        if {[catch {
            exec curl -s -o /dev/null \
                -H "Title: OpenClaw Auth Alert" \
                -H "Priority: $priority" \
                -H "Tags: warning,key" \
                -d $message \
                "https://ntfy.sh/$NOTIFY_NTFY"
        } err]} {
            # Ignore errors
        }
    }

    # Update state
    set fh [open $::STATE_FILE w]
    puts $fh $NOW
    close $fh
}

# Check auth status
if {![file exists $CLAUDE_CREDS]} {
    send_notification "Claude Code credentials missing! Run: claude setup-token" "high"
    exit 1
}

# Read JSON file and extract expiration time
set fh [open $CLAUDE_CREDS r]
set json_data [read $fh]
close $fh

# Simple JSON parsing - assumes structure is consistent
if {[regexp {"claudeAiOauth":\{[^}]*"expiresAt":(\d+)} $json_data -> EXPIRES_AT] == 0} {
    set EXPIRES_AT 0
}

set NOW_MS [expr {$NOW * 1000}]
set DIFF_MS [expr {$EXPIRES_AT - $NOW_MS}]
set HOURS_LEFT [expr {$DIFF_MS / 3600000}]
set MINS_LEFT [expr {($DIFF_MS % 3600000) / 60000}]

if {$DIFF_MS < 0} {
    send_notification "Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'" "urgent"
    exit 1
} elseif {$HOURS_LEFT < $::WARN_HOURS} {
    send_notification "Claude Code auth expires in ${HOURS_LEFT}h ${MINS_LEFT}m. Consider re-auth soon." "high"
    exit 0
} else {
    puts "[clock format $NOW -format {%Y-%m-%d %H:%M:%S}] - Auth OK: ${HOURS_LEFT}h ${MINS_LEFT}m remaining"
    exit 0
}
