#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "567f7826cafe436ee8d14afdd6296a9b683a908519a08175329aa4b687b06f1a", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "tcl"}
# dispatch_job.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Job Dispatcher - Verteilt Jobs auf passende Nodes

# Node-Konfiguration
array set NODES {
    node1 {always_available true capacity medium priority 2}
    node2 {always_available true capacity medium priority 3}
    node3 {always_available false capacity medium priority 4}
    node5 {always_available false capacity low priority 5 device "Redmi Note 11S"}
    node7 {always_available true capacity high priority 1}
}

# Hilfsfunktionen
proc file_size {path} {
    if {[catch {file size $path} size]} {
        return 0
    }
    return $size
}

proc file_exists {path} {
    return [file exists $path]
}

# JobDispatcher Klasse (simuliert durch Prozeduren)
proc get_job_weight {script_path target_langs_count} {
    # Bewertet Job-Gewicht
    if {![file_exists $script_path]} {
        return "medium"
    }
    
    set script_size [file_size $script_path]
    set total_work [expr {$script_size * $target_langs_count}]
    
    if {$total_work > 50000} {
        return "heavy"
    } elseif {$total_work > 10000} {
        return "medium"
    } else {
        return "light"
    }
}

proc check_node_available {node_id} {
    global NODES
    
    if {![info exists NODES($node_id)]} {
        return false
    }
    
    # Parse node config
    array set node_config {}
    foreach {key value} $NODES($node_id) {
        set node_config($key) $value
    }
    
    # Nicht immer-verfügbare Nodes nur wenn explizit requested
    if {![info exists node_config(always_available)] || !$node_config(always_available)} {
        # Für light-jobs prüfen wir ob online
        if {$node_id eq "node5"} {
            return [check_mobile_online]
        }
        return false
    }
    
    # Für immer-verfügbare Nodes: prüfe ob wirklich online
    if {[catch {exec openclaw nodes status $node_id} result]} {
        return $node_config(always_available)
    }
    
    return [expr {[lindex [catch {exec openclaw nodes status $node_id} result] 0] eq "0"}]
}

proc check_mobile_online {} {
    # Prüft ob Redmi (Node 5) Internet hat
    if {[catch {exec openclaw nodes status node5} result]} {
        return false
    }
    
    if {[lindex [catch {exec openclaw nodes status node5} result] 0] eq "0"} {
        if {[string match "*online*" [string tolower $result]]} {
            return true
        }
    }
    return false
}

proc select_node {job_weight} {
    # Wählt besten Node basierend auf Job-Gewicht
    switch $job_weight {
        heavy {
            set preferred [list node7 node2 node1]
        }
        medium {
            set preferred [list node2 node1 node7]
        }
        default {
            set preferred [list node5 node1 node2]
        }
    }
    
    # Prüfe Verfügbarkeit
    foreach node_id $preferred {
        if {[check_node_available $node_id]} {
            return $node_id
        }
    }
    
    # Fallback
    return "node1"
}

proc dispatch {job_script target_langs} {
    # Dispatched Job und gibt Info zurück
    if {$target_langs eq ""} {
        set target_langs [list perl5]
    } else {
        set target_langs [split $target_langs ","]
    }
    
    set weight [get_job_weight $job_script [llength $target_langs]]
    set selected_node [select_node $weight]
    
    return [dict create \
        job $job_script \
        weight $weight \
        selected_node $selected_node \
        target_langs $target_langs \
        status dispatched]
}

proc print_help {} {
    puts "Usage: [info script] \[options\]"
    puts "Options:"
    puts "  --job PATH, -j PATH       Path to job script (required)"
    puts "  --langs LIST, -l LIST     Comma-separated target languages (default: perl5)"
    puts "  --weight WEIGHT, -w       Force job weight (light|medium|heavy)"
    puts "  --execute, -x             Actually execute on selected node"
    puts "  --help, -h                Show this help message"
}

proc parse_args {argv} {
    array set args {
        job ""
        langs "perl5"
        weight ""
        execute false
    }
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            {-j} - {--job} {
                incr i
                set args(job) [lindex $argv $i]
            }
            {-l} - {--langs} {
                incr i
                set args(langs) [lindex $argv $i]
            }
            {-w} - {--weight} {
                incr i
                set args(weight) [lindex $argv $i]
            }
            {-x} - {--execute} {
                set args(execute) true
            }
            {-h} - {--help} {
                print_help
                exit 0
            }
            default {
                if {[string match "--*" $arg]} {
                    puts stderr "Unknown option: $arg"
                    exit 1
                }
            }
        }
    }
    
    return [array get args]
}

proc main {argv} {
    array set args [parse_args $argv]
    
    if {$args(job) eq ""} {
        puts stderr "❌ Job argument is required"
        print_help
        exit 1
    }
    
    if {![file exists $args(job)]} {
        puts stderr "❌ Job not found: $args(job)"
        exit 1
    }
    
    set job_path $args(job)
    
    # Determine weight
    if {$args(weight) ne ""} {
        set weight $args(weight)
    } else {
        set weight [get_job_weight $job_path [llength [split $args(langs) ","]]]
    }
    
    # Select node
    set selected_node [select_node $weight]
    
    # Output
    puts "📦 Job Dispatch Information"
    puts [string repeat "=" 50]
    puts "Job: $job_path"
    puts "Size: [file_size $job_path] bytes"
    puts "Target langs: [join [split $args(langs) ","] ", "]"
    puts "Job weight: $weight"
    puts "Selected node: $selected_node"
    puts [string repeat "=" 50]
    
    if {$args(execute)} {
        puts "\n🚀 Executing on $selected_node..."
        # TODO: Implement remote execution
        puts "(Remote execution not yet implemented)"
    } else {
        puts "\n💡 To execute: [info script] --job $args(job) --execute"
    }
}

# Program entry point
if {[info script] eq $::argv0} {
    main $::argv
}
