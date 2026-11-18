#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "ab9354ef0c34b9bf569a8f9ac7030707f2e8c1c22673b75d88aa8d8d50d26ad2", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "tcl"}
# pplx-status.sh — portiert nach tcl
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Quick status of the codespace Perplexity daemon session.

package require json

# Get configuration directory and profile
set CFG [expr {[info exists ::env(PERPLEXITY_CONFIG_DIR)] ? $::env(PERPLEXITY_CONFIG_DIR) : "$::env(HOME)/.perplexity-mcp"}]
set PROFILE [expr {[info exists ::env(PERPLEXITY_PROFILE)] ? $::env(PERPLEXITY_PROFILE) : "codespace"}]
set STAT "$CFG/profiles/$PROFILE/daemon-status.json"

# Check if status file exists and display it
if {[file exists $STAT]} {
    # Read and pretty-print JSON content
    set fp [open $STAT r]
    set json_content [read $fp]
    close $fp
    
    # Parse and reformat JSON for pretty printing
    set parsed [::json::json2dict $json_content]
    puts [::json::dict2json $parsed]
} else {
    puts "no daemon-status.json at $STAT"
}

puts "--- recent auth lines ---"

# Show recent authentication-related lines from log
set LOG_FILE "$CFG/daemon.log"
if {[file exists $LOG_FILE]} {
    set fp [open $LOG_FILE r]
    set lines [split [read $fp] "\n"]
    close $fp
    
    # Filter lines matching the patterns (case insensitive)
    set filtered_lines {}
    foreach line $lines {
        if {[regexp -nocase {Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in} $line]} {
            lappend filtered_lines $line
        }
    }
    
    # Get last 6 lines
    set total [llength $filtered_lines]
    set start_idx [expr {$total - 6}]
    if {$start_idx < 0} { set start_idx 0 }
    
    set recent_lines [lrange $filtered_lines $start_idx end]
    foreach line $recent_lines {
        puts $line
    }
} else {
    # If log file doesn't exist, do nothing (equivalent to shell's || true)
}
