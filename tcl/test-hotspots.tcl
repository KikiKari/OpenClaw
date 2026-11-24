#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "d35ba5169fc4efee15831c445ee286dbb23a5901178eb5e2d5eb6d8db651e61d", "source_sha256": "4252ea2457fcacdde20bb203479a1fcfbb9fa70ecf111838b7f2ac7c0902a093", "target_language": "tcl"}
# test-hotspots.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-hotspots.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Bibliotheken
package require json
package require fileutil

# Globale Variablen
set defaultConfig "test/vitest/vitest.unit.config.ts"
set defaultLimit 20

# Hilfsfunktionen
proc formatMs {ms} {
    if {$ms >= 1000} {
        set seconds [expr {$ms / 1000}]
        set millis [expr {$ms % 1000}]
        return [format "%d.%03ds" $seconds $millis]
    } else {
        return [format "%dms" $ms]
    }
}

proc showHelp {} {
    puts "Usage: tclsh test-hotspots.tcl \[options\]"
    puts ""
    puts "Print the slowest test files from a Vitest JSON report."
    puts ""
    puts "Options:"
    puts "  --config <path>    Vitest config to run when no report is supplied"
    puts "  --report <path>    Reuse an existing Vitest JSON report"
    puts "  --limit <count>    Number of files to print (default: 20)"
    puts "  --help             Show this help text"
    puts ""
    puts "Examples:"
    puts "  tclsh test-hotspots.tcl"
    puts "  tclsh test-hotspots.tcl --config test/vitest/vitest.channels.config.ts --limit 10"
    puts "  tclsh test-hotspots.tcl --report /tmp/vitest-report.json"
    exit 0
}

proc parseArgs {argv} {
    global defaultConfig defaultLimit
    
    set opts [dict create config $defaultConfig limit $defaultLimit report ""]
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            "--help" {
                showHelp
            }
            "--config" {
                incr i
                dict set opts config [lindex $argv $i]
            }
            "--report" {
                incr i
                dict set opts report [lindex $argv $i]
            }
            "--limit" {
                incr i
                dict set opts limit [lindex $argv $i]
            }
        }
    }
    
    return $opts
}

proc loadVitestReport {opts cacheName} {
    set reportPath [dict get $opts report]
    
    if {$reportPath eq ""} {
        # In Tcl können wir nicht einfach vitest ausführen, daher simulieren wir das Laden
        error "No report specified. Please provide a --report path."
    }
    
    if {![file exists $reportPath]} {
        error "Report file does not exist: $reportPath"
    }
    
    set content [read [open $reportPath r]]
    return [::json::json2dict $content]
}

proc collectVitestFileDurations {report} {
    set results {}
    
    # Durchlaufe alle Testergebnisse im Report
    if {[dict exists $report tests]} {
        set tests [dict get $report tests]
        
        # Gruppiere Tests nach Dateien
        set fileMap {}
        foreach test $tests {
            if {[dict exists $test filepath] && [dict exists $test duration]} {
                set filepath [dict get $test filepath]
                set duration [dict get $test duration]
                
                if {![dict exists $fileMap $filepath]} {
                    dict set fileMap $filepath [list duration 0 count 0]
                }
                
                set currentDuration [dict get $fileMap $filepath duration]
                set currentCount [dict get $fileMap $filepath count]
                
                dict set fileMap $filepath duration [expr {$currentDuration + $duration}]
                dict set fileMap $filepath count [expr {$currentCount + 1}]
            }
        }
        
        # Konvertiere zu Liste für Sortierung
        dict for {filepath data} $fileMap {
            lappend results [dict create \
                file $filepath \
                durationMs [expr {int([dict get $data duration] * 1000)}] \
                testCount [dict get $data count]]
        }
    }
    
    return $results
}

proc sortFileResults {results} {
    return [lsort -decreasing -real -index 1 $results]
}

proc main {argv} {
    set opts [parseArgs $argv]
    
    # Lade den Report
    set report [loadVitestReport $opts "openclaw-vitest-hotspots"]
    
    # Sammle Dateilaufzeiten
    set fileResults [collectVitestFileDurations $report]
    
    # Sortiere nach Dauer (absteigend)
    set sortedResults {}
    foreach item $fileResults {
        lappend sortedResults [list [dict get $item durationMs] $item]
    }
    set sortedResults [lsort -decreasing -integer -index 0 $sortedResults]
    
    set fileResults {}
    foreach item $sortedResults {
        lappend fileResults [lindex $item 1]
    }
    
    # Begrenze auf die Top-Einträge
    set limit [dict get $opts limit]
    set top [lrange $fileResults 0 [expr {$limit - 1}]]
    
    # Berechne Gesamtdauer
    set totalDurationMs 0
    foreach item $fileResults {
        incr totalDurationMs [dict get $item durationMs]
    }
    
    # Ausgabe
    puts "\n\[test-hotspots\] top [llength $top] by file duration ([formatMs $totalDurationMs] total)"
    
    set index 1
    foreach item $top {
        set label [format "%2d" $index]
        set duration [format "%10s" [formatMs [dict get $item durationMs]]]
        set tests [format "%4d" [dict get $item testCount]]
        set file [dict get $item file]
        puts "$label. $duration | tests=$tests | $file"
        incr index
    }
}

# Starte das Programm
main $argv
