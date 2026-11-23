#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "66971984544a6f116cd4bd69a6a70ce046316576f09eff31477436a95ef715e3", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "tcl"}
# setup-auth-system.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Setup OpenClaw Auth Management System
# Run this once to set up:
# 1. Long-lived Claude Code token
# 2. Auth monitoring with notifications
# 3. Instructions for Termux widgets

package require Tcl 8.6

# Function to get script directory
proc getScriptDir {} {
    set scriptPath [info script]
    if {[string match "/*" $scriptPath]} {
        return [file dirname $scriptPath]
    } else {
        return [file normalize [file join [pwd] [file dirname $scriptPath]]]
    }
}

set SCRIPT_DIR [getScriptDir]

puts "=== OpenClaw Auth System Setup ==="
puts ""

# Step 1: Check current auth status
puts "Step 1: Checking current auth status..."
if {[catch {exec $SCRIPT_DIR/claude-auth-status.sh full} result]} {
    # Ignore errors, continue execution
}
puts ""

# Step 2: Set up long-lived token
puts "Step 2: Long-lived token setup"
puts ""
puts "Option A: Use 'claude setup-token' (recommended)"
puts "  - Creates a long-lived API token"
puts "  - No daily re-auth needed"
puts "  - Run: claude setup-token"
puts ""
puts -nonewline "Would you like to set up a long-lived token now? \[y/N\] "
flush stdout
set SETUP_TOKEN [gets stdin]

if {[regexp {^[Yy]} $SETUP_TOKEN]} {
    puts ""
    puts "Opening https://console.anthropic.com/settings/api-keys"
    puts "Create a new key or copy existing one, then paste below."
    puts ""
    exec claude setup-token
}

puts ""

# Step 3: Set up auth monitoring
puts "Step 3: Auth monitoring setup"
puts ""
puts "The auth monitor checks expiry every 30 minutes and notifies you."
puts ""
puts "Configure notification channels:"
puts ""

# Check for ntfy
puts "  ntfy.sh: Free push notifications to your phone"
puts "  1. Install ntfy app on your phone"
puts "  2. Subscribe to a topic (e.g., 'openclaw-alerts')"
puts ""
puts -nonewline "Enter ntfy.sh topic (or leave blank to skip): "
flush stdout
set NTFY_TOPIC [gets stdin]

# Phone notification
puts ""
puts "  OpenClaw message: Send warning via OpenClaw itself"
puts -nonewline "Enter your phone number for alerts (or leave blank to skip): "
flush stdout
set PHONE_NUMBER [gets stdin]

# Update service file
set SERVICE_FILE [file join $SCRIPT_DIR systemd openclaw-auth-monitor.service]

# Read the service file content
if {[file exists $SERVICE_FILE]} {
    set fp [open $SERVICE_FILE r]
    set content [read $fp]
    close $fp
    
    # Replace ntfy topic
    if {$NTFY_TOPIC ne ""} {
        regsub {# Environment=NOTIFY_NTFY=.*} $content "Environment=NOTIFY_NTFY=$NTFY_TOPIC" content
    }
    
    # Replace phone number
    if {$PHONE_NUMBER ne ""} {
        regsub {# Environment=NOTIFY_PHONE=.*} $content "Environment=NOTIFY_PHONE=$PHONE_NUMBER" content
    }
    
    # Write back the modified content
    set fp [open $SERVICE_FILE w]
    puts -nonewline $fp $content
    close $fp
}

# Install systemd units
puts ""
puts "Installing systemd timer..."

# Create user systemd directory
file mkdir [file join ~ .config systemd user]

# Copy service files
set source_service [file join $SCRIPT_DIR systemd openclaw-auth-monitor.service]
set dest_service [file join ~ .config systemd user openclaw-auth-monitor.service]
file copy -force $source_service $dest_service

set source_timer [file join $SCRIPT_DIR systemd openclaw-auth-monitor.timer]
set dest_timer [file join ~ .config systemd user openclaw-auth-monitor.timer]
file copy -force $source_timer $dest_timer

# Try to reload systemd and enable timer
if {![catch {exec systemctl --user daemon-reload}]} {
    if {![catch {exec systemctl --user enable --now openclaw-auth-monitor.timer}]} {
        puts "Auth monitor installed and running."
    } else {
        puts "Failed to start auth monitor timer."
    }
} else {
    puts "Failed to reload systemd daemon."
}

puts ""

# Step 4: Termux widget setup
puts "Step 4: Termux widget setup (for phone)"
puts ""
puts "To set up quick auth from your phone:"
puts ""
puts "1. Install Termux and Termux:Widget from F-Droid"
puts "2. Create ~/.shortcuts/ directory in Termux:"
puts "   mkdir -p ~/.shortcuts"
puts ""
puts "3. Copy the widget scripts:"
puts "   scp $SCRIPT_DIR/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth"
puts "   scp $SCRIPT_DIR/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full"
puts ""
puts "4. Make them executable on phone:"
puts "   ssh phone 'chmod +x ~/.shortcuts/Clawd*'"
puts ""
puts "5. Add Termux:Widget to your home screen"
puts "6. Tap the widget to see your auth scripts"
puts ""
puts "The quick widget (ClawdAuth) shows status and opens auth URL if needed."
puts "The full widget (ClawdAuth-Full) provides guided re-auth flow."
puts ""

# Summary
puts "=== Setup Complete ==="
puts ""
puts "What's configured:"
puts "  - Auth status: $SCRIPT_DIR/claude-auth-status.sh"
puts "  - Mobile re-auth: $SCRIPT_DIR/mobile-reauth.sh"
puts "  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer"
puts ""
puts "Quick commands:"
puts "  Check auth:  $SCRIPT_DIR/claude-auth-status.sh"
puts "  Re-auth:     $SCRIPT_DIR/mobile-reauth.sh"
puts "  Test monitor: $SCRIPT_DIR/auth-monitor.sh"
puts ""
