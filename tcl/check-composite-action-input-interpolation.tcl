#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "53cc7332bae3a8aef6a53510a650074ae719f41f81f3f91af983e91108f9b5f9", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "tcl"}
# check-composite-action-input-interpolation.py — portiert nach tcl
# Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require fileutil
package require regexp

# Regular expressions
set INPUT_INTERPOLATION_RE {\$\{\{\s*inputs\.}
set RUN_LINE_RE {^(\s*)run:\s*(.*)$}
set USING_COMPOSITE_RE {\s*using:\s*composite\s*}

proc indentation {line} {
    set stripped [string trimleft $line " "]
    return [expr {[string length $line] - [string length $stripped]}]
}

proc scan_file {path} {
    global INPUT_INTERPOLATION_RE RUN_LINE_RE USING_COMPOSITE_RE
    
    if {![file exists $path]} {
        return {}
    }
    
    set text [read [set fh [open $path r]]]
    close $fh
    
    if {![regexp -- $USING_COMPOSITE_RE $text]} {
        return {}
    }
    
    set lines [split $text "\n"]
    set violations {}
    set line_count [llength $lines]
    set index 0
    
    while {$index < $line_count} {
        set line [lindex $lines $index]
        if {![regexp $RUN_LINE_RE $line -> indent run_value]} {
            incr index
            continue
        }
        
        set run_indent [string length $indent]
        set run_value [string trim $run_value]
        set line_no [expr {$index + 1}]
        
        if {$run_value ne "" && ![string match {|*} $run_value] && ![string match {>*} $run_value]} {
            if {[regexp $INPUT_INTERPOLATION_RE $run_value]} {
                lappend violations [list $line_no [string trim $line]]
            }
            incr index
            continue
        }
        
        incr index
        while {$index < $line_count} {
            set script_line [lindex $lines $index]
            if {[string trim $script_line] eq ""} {
                incr index
                continue
            }
            if {[indentation $script_line] <= $run_indent} {
                break
            }
            if {[regexp $INPUT_INTERPOLATION_RE $script_line]} {
                lappend violations [list [expr {$index + 1}] [string trim $script_line]]
            }
            incr index
        }
    }
    
    return $violations
}

proc main {} {
    set root ".github/actions"
    set files {}
    
    # Find all action.yml or action.yaml files
    foreach file [glob -nocomplain -directory $root -types f {*action.y*ml}] {
        lappend files $file
    }
    
    # Sort files
    set files [lsort $files]
    
    set all_violations {}
    
    foreach file_path $files {
        set violations [scan_file $file_path]
        foreach {line_info} $violations {
            lassign $line_info line_no line
            lappend all_violations [list $file_path $line_no $line]
        }
    }
    
    if {[llength $all_violations] > 0} {
        puts "Disallowed direct inputs interpolation in composite run blocks:"
        foreach violation $all_violations {
            lassign $violation file_path line_no line
            puts "- $file_path:$line_no: $line"
        }
        puts "Use env: and reference shell variables instead."
        return 1
    }
    
    puts "No direct inputs interpolation found in composite run blocks."
    return 0
}

exit [main]
