#!/usr/bin/env tclsh
# tree_fallback.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:db-maintainer/scripts/tree_fallback.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Fallback tree generator for when the `tree` binary is unavailable.
#
# Produces output similar to `tree -a -L <depth>` and writes it to
# important/openclaw-tree.txt with a timestamp header.

package require fileutil

set WORKSPACE "/workspace"
set DEPTH 6
array set SKIP [list .git 1 node_modules 1 __pycache__ 1 venv 1 .cache 1 .npm 1 .local 1]
set OUT [file join $WORKSPACE important openclaw-tree.txt]

proc walk {path prefix depth} {
    global DEPTH SKIP
    set lines {}
    if {$depth >= $DEPTH} {
        return $lines
    }
    if {[catch {lsort -dictionary [glob -nocomplain -dir $path *]} entries]} {
        return $lines
    }
    set filtered_entries {}
    foreach entry $entries {
        set basename [file tail $entry]
        if {![info exists SKIP($basename)]} {
            lappend filtered_entries $entry
        }
    }
    set entries $filtered_entries
    set count [llength $entries]
    for {set i 0} {$i < $count} {incr i} {
        set entry [lindex $entries $i]
        set last [expr {$i == $count - 1}]
        set connector [expr {$last ? "└── " : "├── "}]
        set suffix [expr {[file isdirectory $entry] ? "/" : ""}]
        set basename [file tail $entry]
        lappend lines "${prefix}${connector}${basename}${suffix}"
        if {[file isdirectory $entry] && ![file type $entry eq "link"]} {
            set extension [expr {$last ? "    " : "│   "}]
            set sublines [walk $entry ${prefix}${extension} [expr {$depth + 1}]]
            set lines [concat $lines $sublines]
        }
    }
    return $lines
}

proc main {} {
    global WORKSPACE DEPTH OUT
    set lines [list $WORKSPACE]
    set walk_result [walk $WORKSPACE "" 0]
    set lines [concat $lines $walk_result]
    set body [join $lines "\n"]
    append body "\n"
    set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    set header "# OpenClaw Workspace Tree\n"
    append header "# Generiert: ${timestamp}\n"
    append header "# Fallback (tree binary nicht verfuegbar), Tiefe ${DEPTH}\n"
    append header "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
    set dir [file dirname $OUT]
    file mkdir $dir
    set fd [open $OUT w]
    puts -nonewline $fd $header
    puts -nonewline $fd $body
    close $fd
    
    set count [llength $lines]
    puts "openclaw-tree.txt aktualisiert (Fallback): $OUT ($count Eintraege)"
}

main
