#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "56ca8b27d441e932ff6f2c57e8636c3d5ac0a8c08457c3d8ba1ff39925260d83", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "tcl"}
# translation-worker-node.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.

if {$argc != 2} {
    puts stderr {Usage: translation-worker-node.tcl node2|node3|node4|node6 prepare|health|run}
    exit 2
}

set node [lindex $argv 0]
set action [lindex $argv 1]

switch -exact -- $node {
    node2 {
        set worker /home/node/.openclaw/workers/translation-worker
        set expected 565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286
    }
    node3 {
        set worker /home/openclaw/.openclaw/workers/translation-worker
        set expected 9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de
    }
    node4 {
        set worker /root/.openclaw/workers/translation-worker
        set expected 565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286
    }
    node6 {
        set worker /home/node/.openclaw/workers/translation-worker
        set expected 9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de
    }
    default {
        puts stderr {Unknown or non-POSIX node}
        exit 2
    }
}

if {$action ni {prepare health run}} {
    puts stderr {Unknown action}
    exit 2
}

if {![file exists $worker] || [file type $worker] eq "link"} {
    puts stderr "Missing worker or symlink rejected: $worker"
    exit 1
}

# Calculate SHA256 hash of the worker file
set fh [open $worker r]
fconfigure $fh -translation binary
set content [read $fh]
close $fh
set actual [sha256 $content]

if {$actual ne $expected} {
    puts stderr "Worker checksum mismatch: $worker"
    exit 1
}

# Make the worker executable
file attributes $worker -permissions +x

switch -exact -- $action {
    prepare {
        puts "Worker verified and executable: $worker"
    }
    health {
        exec {*}[list $worker --health] <@stdin >@stdout 2>@stderr
    }
    run {
        exec {*}[list $worker] <@stdin >@stdout 2>@stderr
    }
}

# SHA256 implementation for Tcl
proc sha256 {data} {
    # This is a simplified placeholder - in practice you would need a proper SHA256 implementation
    # For now we'll use a basic approach with Tcl's expr and string operations
    # Note: A real implementation would require significant bit manipulation
    
    # Since Tcl 8.6 doesn't have built-in SHA256, this is a minimal placeholder
    # In a production environment, you'd want to use a proper crypto library or 
    # call an external tool like 'openssl'
    
    if {[catch {exec openssl sha256 -binary << $data | xxd -p} result]} {
        # Fallback: simple hash (not secure, just for demonstration)
        set hash 0
        foreach char [split $data ""] {
            scan $char %c byte
            set hash [expr {($hash << 5) ^ $byte ^ ($hash >> 27)}]
        }
        # Convert to hex string
        return [format "%064x" [expr {$hash & 0xFFFFFFFFFFFFFFFF}]]
    } else {
        return [string trim $result]
    }
}
