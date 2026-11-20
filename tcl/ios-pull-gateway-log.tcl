#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "dfecdfbf2c6e56ac7489c0f2e2b9733e5ed0ece2ec7faf9fd356de6b09194e37", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "tcl"}
# ios-pull-gateway-log.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Default values
set DEVICE_UDID [expr {[info exists argv(0)] ? [lindex $argv 0] : "00008130-000630CE0146001C"}]
set BUNDLE_ID [expr {[info exists argv(1)] ? [lindex $argv 1] : "ai.openclaw.ios.dev.mariano.test"}]
set DEST [expr {[info exists argv(2)] ? [lindex $argv 2] : "/tmp/openclaw-gateway.log"}]

# Execute the xcrun command
if {[catch {
    exec xcrun devicectl device copy from \
        --device $DEVICE_UDID \
        --domain-type appDataContainer \
        --domain-identifier $BUNDLE_ID \
        --source Documents/openclaw-gateway.log \
        --destination $DEST \
        >@stdout 2>@stderr
} result]} {
    puts stderr "Error executing xcrun command: $result"
    exit 1
}

puts "Pulled to: $DEST"

# Display last 200 lines of the file
if {[file exists $DEST]} {
    set fh [open $DEST r]
    set lines [split [read $fh] "\n"]
    close $fh
    
    set total_lines [llength $lines]
    set start_index [expr {$total_lines - 200}]
    if {$start_index < 0} {
        set start_index 0
    }
    
    for {set i $start_index} {$i < $total_lines} {incr i} {
        puts [lindex $lines $i]
    }
} else {
    puts stderr "File not found: $DEST"
    exit 1
}
