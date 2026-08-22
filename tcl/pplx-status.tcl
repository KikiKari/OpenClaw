#!/usr/bin/env tclsh8.6
# pplx-status.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.

package require json

# Get configuration directory and profile
set CFG [expr {[info exists ::env(PERPLEXITY_CONFIG_DIR)] ? $::env(PERPLEXITY_CONFIG_DIR) : "$::env(HOME)/.perplexity-mcp"}]
set PROFILE [expr {[info exists ::env(PERPLEXITY_PROFILE)] ? $::env(PERPLEXITY_PROFILE) : "codespace"}]
set STAT "$CFG/profiles/$PROFILE/daemon-status.json"

# Check if status file exists and display it
if {[file exists $STAT]} {
    set fh [open $STAT r]
    set content [read $fh]
    close $fh
    puts [::json::json_pretty_print $content]
} else {
    puts "no daemon-status.json at $STAT"
}

puts "--- recent auth lines ---"

# Display recent authentication lines from log
set LOG_FILE "$CFG/daemon.log"
if {[file exists $LOG_FILE]} {
    set fh [open $LOG_FILE r]
    set lines [split [read $fh] "\n"]
    close $fh
    
    # Filter lines matching the patterns
    set filtered_lines {}
    foreach line $lines {
        if {[regexp -nocase {Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in} $line]} {
            lappend filtered_lines $line
        }
    }
    
    # Show last 6 lines
    set total [llength $filtered_lines]
    set start_idx [expr {$total > 6 ? $total - 6 : 0}]
    set recent_lines [lrange $filtered_lines $start_idx end]
    
    foreach line $recent_lines {
        puts $line
    }
} else {
    # No action needed if log file doesn't exist
}
