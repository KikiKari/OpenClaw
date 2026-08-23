#!/usr/bin/env tclsh8.6
# gen_tree.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

set ROOT "/workspace"
set OUT "/workspace/important/openclaw-tree.txt"
set MAX_DEPTH 6

# Function to collect directory tree
proc collect {path {prefix ""} {depth 1}} {
    set lines {}
    
    # Get directory entries
    if {[catch {lsort [glob -nocomplain -dir $path *]} entries]} {
        return $lines
    }
    
    set total [llength $entries]
    set index 0
    
    foreach full_path $entries {
        # Extract just the filename
        set name [file tail $full_path]
        
        set is_last [expr {$index == $total - 1}]
        set connector [expr {$is_last ? "\u2514\u2500\u2500 " : "\u251c\u2500\u2500 "}]
        
        lappend lines "${prefix}${connector}${name}"
        
        # Recursively process directories
        if {$depth < $::MAX_DEPTH && [file isdirectory $full_path] && ![file type $full_path eq "link"]} {
            set next_prefix [expr {$is_last ? "${prefix}    " : "${prefix}\u2502   "}]
            set sub_lines [collect $full_path $next_prefix [expr {$depth + 1}]]
            set lines [concat $lines $sub_lines]
        }
        
        incr index
    }
    
    return $lines
}

# Generate the tree content
set body [collect $ROOT]

# Create header with timestamp
set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
set header "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 6 $ROOT (emuliert via gen_tree.py)\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"

# Combine header and body
set content "$header.\n[join $body \n]\n"

# Write to file
set f [open $OUT w]
puts -nonewline $f $content
close $f

# Print summary
set line_count [expr {[llength $body] + 1}]
set byte_count [string length $content]
puts "written $OUT: $line_count lines, $byte_count bytes"
