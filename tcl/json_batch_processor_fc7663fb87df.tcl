#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "46ea6624520bd25d1238977376cdc64f75148de519cf213ee9e9fc597e3ea4cf", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "tcl"}
# json_batch_processor.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

package require json
package require cmdline

# Globale Variablen
set HAS_PYDANTIC false

# Hilfsfunktionen fuer JSON-Verarbeitung
proc parse_json {content repair} {
    # Vereinfachte JSON-Parsing-Funktion ohne Reparatur
    if {$repair} {
        # Entferne fuehrende/abschliessende Leerzeichen
        set content [string trim $content]
    }
    if {[catch {::json::json2dict $content} result]} {
        error "JSON parsing failed: $result"
    }
    return $result
}

proc parse_and_validate {content model repair} {
    # Vereinfachte Version ohne Pydantic-Validierung
    return [parse_json $content $repair]
}

# BatchResult-Klasse als Dict
proc create_batch_result {index source success {data ""} {error ""}} {
    return [dict create \
        index $index \
        source $source \
        success $success \
        data $data \
        error $error]
}

proc batch_result_to_dict {result} {
    return $result
}

# Liest JSON-Lines (NDJSON) Datei Zeile fuer Zeile
proc read_jsonl {file_path} {
    set results {}
    if {[catch {open $file_path r} fd]} {
        lappend results [create_batch_result 0 $file_path false "" "Cannot open file: $fd"]
        return $results
    }
    
    set line_num 0
    while {[gets $fd line] >= 0} {
        incr line_num
        set line [string trim $line]
        if {$line eq ""} {
            continue
        }
        
        if {[catch {::json::json2dict $line} parsed]} {
            lappend results [create_batch_result $line_num "$file_path:$line_num" false "" "JSON decode error: $parsed"]
        } else {
            lappend results [create_batch_result $line_num "$file_path:$line_num" true $parsed ""]
        }
    }
    close $fd
    return $results
}

# Verarbeitet eine Liste von Inputs sequentiell (kein echtes Multithreading in Tcl)
proc process_batch {inputs processor} {
    set results {}
    set idx 0
    foreach inp $inputs {
        if {[catch {eval $processor [list $inp $idx]} result]} {
            lappend results [create_batch_result $idx $inp false "" "Unexpected error: $result"]
        } else {
            lappend results $result
        }
        incr idx
    }
    
    # Sortiere nach Index
    set sorted_results {}
    foreach result [lsort -integer -index 0 [lmap r $results {list [dict get $r index] $r}]] {
        lappend sorted_results [lindex $result 1]
    }
    return $sorted_results
}

# Verarbeitet mehrere JSON-Dateien im Batch
proc process_file_batch {file_paths repair validate_model max_workers} {
    proc file_processor {path idx} {
        upvar repair rep
        upvar validate_model model
        
        if {[catch {read_file_content $path} content]} {
            return [create_batch_result $idx $path false "" "Cannot read file: $content"]
        }
        
        if {[catch {
            if {$model ne "" && $::HAS_PYDANTIC} {
                set data [parse_and_validate $content $model $rep]
            } else {
                set data [parse_json $content $rep]
            }
            return [create_batch_result $idx $path true $data ""]
        } result]} {
            return [create_batch_result $idx $path false "" $result]
        }
    }
    
    return [process_batch $file_paths file_processor]
}

# Liest den Inhalt einer Datei
proc read_file_content {path} {
    if {[catch {open $path r} fd]} {
        error "Cannot open file: $fd"
    }
    set content [read $fd]
    close $fd
    return $content
}

# Verarbeitet eine JSON-Lines Datei
proc process_jsonl_file {file_path repair validate_model} {
    set results {}
    set line_num 0
    
    if {[catch {open $file_path r} fd]} {
        lappend results [create_batch_result 0 $file_path false "" "Cannot open file: $fd"]
        return $results
    }
    
    while {[gets $fd line] >= 0} {
        incr line_num
        set line [string trim $line]
        if {$line eq ""} {
            continue
        }
        
        if {[catch {
            if {$validate_model ne "" && $::HAS_PYDANTIC} {
                set data [parse_and_validate $line $validate_model $repair]
            } else {
                set data [parse_json $line $repair]
            }
            return [create_batch_result $line_num "$file_path:$line_num" true $data ""]
        } result]} {
            lappend results [create_batch_result $line_num "$file_path:$line_num" false "" $result]
        }
    }
    close $fd
    return $results
}

# Schreibt BatchResult-Liste als JSON-Lines
proc write_jsonl {results output_path only_successful} {
    if {[catch {open $output_path w} fd]} {
        error "Cannot write to file: $fd"
    }
    
    foreach result $results {
        if {$only_successful && ![dict get $result success]} {
            continue
        }
        puts $fd [::json::dict2json [batch_result_to_dict $result]]
    }
    close $fd
}

# Hauptprogramm
proc main {} {
    global argv argc
    
    # Kommandozeilenoptionen
    set options {
        {"jsonl l" "" "Treat inputs as JSON-Lines files"}
        {"repair r" "true" "Enable JSON repair"}
        {"workers w" "4" "Parallel workers"}
        {"output o" "" "Output JSON-Lines file"}
        {"summary s" "" "Show summary only"}
    }
    
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr "Error parsing options: $result"
        exit 1
    }
    
    array set opts $result
    
    if {$argc < 1} {
        puts stderr "Usage: $argv0 \[-options\] input_files..."
        exit 1
    }
    
    set inputs $argv
    
    set all_results {}
    
    if {$opts(jsonl)} {
        # JSON-Lines Modus
        foreach input_path $inputs {
            set results [read_jsonl $input_path]
            set all_results [concat $all_results $results]
        }
    } else {
        # Standard JSON Batch
        set all_results [process_file_batch $inputs $opts(repair) "" $opts(workers)]
    }
    
    # Statistik
    set successful 0
    set failed 0
    foreach result $all_results {
        if {[dict get $result success]} {
            incr successful
        } else {
            incr failed
        }
    }
    
    if {$opts(summary)} {
        puts "Processed: [llength $all_results]"
        puts "Successful: $successful"
        puts "Failed: $failed"
    } else {
        foreach result $all_results {
            if {[dict get $result success]} {
                puts [::json::dict2json [dict get $result data]]
            } else {
                puts stderr "ERROR \[[dict get $result source]\]: [dict get $result error]"
            }
        }
    }
    
    # Optional: JSONL Output
    if {$opts(output) ne ""} {
        if {[catch {write_jsonl $all_results $opts(output) false} err]} {
            puts stderr "Error writing output: $err"
        } else {
            puts stderr "\nResults written to: $opts(output)"
        }
    }
    
    # Exit code
    if {$failed > 0} {
        exit 1
    } else {
        exit 0
    }
}

# Starte das Programm
main
