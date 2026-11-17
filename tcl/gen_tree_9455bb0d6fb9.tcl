#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "0a1b08b5551c400c8318ee705f9a4ab137e1fb5cdf22e2c0e197e310bd1e51f8", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "tcl"}
# gen_tree.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

set ROOT "/workspace"
set OUT "/workspace/important/openclaw-tree.txt"
set MAX_DEPTH 6

# Procedure to collect directory tree structure
proc collect {path {prefix ""} {depth 1}} {
    global MAX_DEPTH
    set lines {}
    
    if {[catch {lsort [glob -nocomplain -dir $path *]} entries]} {
        return $lines
    }
    
    set total [llength $entries]
    for {set i 0} {$i < $total} {incr i} {
        set entry [lindex $entries $i]
        set name [file tail $entry]
        set is_last [expr {$i == $total - 1}]
        
        set connector ""
        if {$is_last} {
            set connector "\u2514\u2500\u2500 "
        } else {
            set connector "\u251c\u2500\u2500 "
        }
        
        lappend lines "${prefix}${connector}${name}"
        
        if {$depth < $MAX_DEPTH && [file isdirectory $entry] && ![file type $entry eq "link"]} {
            set next_prefix ""
            if {$is_last} {
                set next_prefix "${prefix}    "
            } else {
                set next_prefix "${prefix}\u2502   "
            }
            set sublines [collect $entry $next_prefix [expr {$depth + 1}]]
            set lines [concat $lines $sublines]
        }
    }
    
    return $lines
}

# Generate the tree content
set body [collect $ROOT]

# Create ISO format timestamp
set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
set header "# OpenClaw Workspace Tree\n"
append header "# Generiert: ${timestamp}\n"
append header "# Befehl: tree -a -L 6 ${ROOT} (emuliert via gen_tree.py)\n"
append header "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"

set content "$header.\n[join $body \n]\n"

# Write to file
set f [open $OUT w]
puts -nonewline $f $content
close $f

# Print summary
set line_count [expr {[llength $body] + 1}]
set byte_count [string length $content]
puts "written ${OUT}: ${line_count} lines, ${byte_count} bytes"
