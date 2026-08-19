#!/usr/bin/env tclsh
# json_batch_processor.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Port of json_batch_processor.py
# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

package require json
package require cmdline

# Globale Variablen
set HAS_PYDANTIC 0
set JSON_PROCESSOR_LOADED 0

# Versuche json_processor.tcl zu laden
if {[catch {source json_processor.tcl} err]} {
    puts stderr "Warning: Could not load json_processor.tcl: $err"
} else {
    set JSON_PROCESSOR_LOADED 1
}

# BatchResult Klasse
proc create_BatchResult {index source success {data ""} {error ""}} {
    return [list \
        index $index \
        source $source \
        success $success \
        data $data \
        error $error]
}

proc BatchResult_to_dict {batch_result} {
    return $batch_result
}

# Liest JSON-Lines (NDJSON) Datei Zeile für Zeile
proc read_jsonl {file_path} {
    set results {}
    if {[catch {open $file_path r} fd]} {
        lappend results [create_BatchResult 0 $file_path 0 "" "Could not open file: $fd"]
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
            lappend results [create_BatchResult $line_num "$file_path:$line_num" 0 "" "JSON decode error: $parsed"]
        } else {
            lappend results $parsed
        }
    }
    close $fd
    return $results
}

# Verarbeitet eine Liste von Inputs parallel (simuliert durch sequenzielle Abarbeitung)
proc process_batch {inputs processor max_workers} {
    set results {}
    set idx 0
    
    foreach inp $inputs {
        if {[catch {eval [list $processor $inp $idx]} result]} {
            lappend results [create_BatchResult $idx $inp 0 "" "Unexpected error: $result"]
        } else {
            lappend results $result
        }
        incr idx
    }
    
    # Sortiere nach Index
    set sorted_results {}
    foreach result [lsort -integer -index 0 $results] {
        lappend sorted_results $result
    }
    return $sorted_results
}

# Verarbeitet mehrere JSON-Dateien im Batch
proc process_file_batch {file_paths repair validate_model max_workers} {
    proc file_processor {path idx} {
        upvar repair repair_val
        upvar validate_model model_val
        
        if {[catch {open $path r} fd]} {
            return [create_BatchResult $idx $path 0 "" "Could not open file: $fd"]
        }
        set content [read $fd]
        close $fd
        
        if {$model_val ne "" && $::HAS_PYDANTIC} {
            # In Tcl gibt es kein Pydantic, daher verwenden wir normale Verarbeitung
            if {[catch {parse_and_validate $content $model_val $repair_val} data]} {
                return [create_BatchResult $idx $path 0 "" $data]
            }
        } else {
            if {$::JSON_PROCESSOR_LOADED} {
                if {[catch {parse_json $content $repair_val} data]} {
                    return [create_BatchResult $idx $path 0 "" $data]
                }
            } else {
                if {[catch {::json::json2dict $content} data]} {
                    return [create_BatchResult $idx $path 0 "" "JSON parsing failed: $data"]
                }
            }
        }
        
        return [create_BatchResult $idx $path 1 $data ""]
    }
    
    return [process_batch $file_paths file_processor $max_workers]
}

# Verarbeitet eine JSON-Lines Datei
proc process_jsonl_file {file_path repair validate_model} {
    set results {}
    
    if {[catch {open $file_path r} fd]} {
        lappend results [create_BatchResult 0 $file_path 0 "" "Could not open file: $fd"]
        return $results
    }
    
    set line_num 0
    while {[gets $fd line] >= 0} {
        incr line_num
        set line [string trim $line]
        if {$line eq ""} {
            continue
        }
        
        if {$validate_model ne "" && $::HAS_PYDANTIC} {
            # In Tcl gibt es kein Pydantic, daher verwenden wir normale Verarbeitung
            if {[catch {parse_and_validate $line $validate_model $repair} data]} {
                lappend results [create_BatchResult $line_num "$file_path:$line_num" 0 "" $data]
            }
        } else {
            if {$::JSON_PROCESSOR_LOADED} {
                if {[catch {parse_json $line $repair} data]} {
                    lappend results [create_BatchResult $line_num "$file_path:$line_num" 0 "" $data]
                }
            } else {
                if {[catch {::json::json2dict $line} data]} {
                    lappend results [create_BatchResult $line_num "$file_path:$line_num" 0 "" "JSON parsing failed: $data"]
                } else {
                    lappend results [create_BatchResult $line_num "$file_path:$line_num" 1 $data ""]
                }
            }
        }
    }
    close $fd
    return $results
}

# Schreibt BatchResult-Liste als JSON-Lines
proc write_jsonl {results output_path only_successful} {
    if {[catch {open $output_path w} fd]} {
        error "Could not open output file: $fd"
    }
    
    foreach result $results {
        set success [dict get $result success]
        if {$only_successful && !$success} {
            continue
        }
        puts $fd [::json::dict2json $result]
    }
    close $fd
}

# Hauptprogramm
proc main {} {
    # Kommandozeilenargumente parsen
    set options {
        {"jsonl.l" 0 "Treat inputs as JSON-Lines files"}
        {"repair.r" 1 "Enable JSON repair"}
        {"workers.w" 4 "Parallel workers"}
        {"output.o" "" "Output JSON-Lines file"}
        {"summary.s" 0 "Show summary only"}
    }
    
    set usage "Usage: json_batch_processor.tcl \[options\] inputs..."
    
    if {[catch {cmdline::typedGetopt argv $options} result]} {
        puts stderr "$usage"
        puts stderr "Error: $result"
        exit 1
    }
    
    array set opts $result
    set inputs $argv
    
    if {[llength $inputs] == 0} {
        puts stderr "$usage"
        puts stderr "Error: At least one input file required"
        exit 1
    }
    
    set all_results {}
    
    if {$opts(jsonl)} {
        # JSON-Lines Modus
        foreach input_path $inputs {
            set results [process_jsonl_file $input_path $opts(repair) ""]
            foreach result $results {
                lappend all_results $result
            }
        }
    } else {
        # Standard JSON Batch
        set all_results [process_file_batch $inputs $opts(repair) "" $opts(workers)]
    }
    
    # Ausgabe
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
        if {[catch {write_jsonl $all_results $opts(output) 0} err]} {
            puts stderr "Error writing output file: $err"
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
if {[info script] eq $argv0} {
    main
}
