#!/usr/bin/env tclsh8.6
# dispatch_job.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

#
# Job Dispatcher - Verteilt Jobs auf passende Nodes
#

package require cmdline
package require fileutil

# Node-Konfiguration
array set NODES {
    node1 {always_available true capacity medium priority 2}
    node2 {always_available true capacity medium priority 3}
    node3 {always_available false capacity medium priority 4}
    node5 {always_available false capacity low priority 5 device {Redmi Note 11S}}
    node7 {always_available true capacity high priority 1}
}

# Hilfsfunktionen
proc dict_get_default {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    }
    return $default
}

proc file_size {filename} {
    if {[catch {file size $filename} size]} {
        return 0
    }
    return $size
}

# JobDispatcher Klasse
oo::class create JobDispatcher {
    # Bewertet Job-Gewicht
    method get_job_weight {script_path target_langs_count} {
        if {![file exists $script_path]} {
            return "medium"
        }
        
        set script_size [file_size $script_path]
        set total_work [expr {$script_size * $target_langs_count}]
        
        if {$total_work > 50000} {  # > 50KB
            return "heavy"
        } elseif {$total_work > 10000} {  # > 10KB
            return "medium"
        } else {
            return "light"
        }
    }
    
    # Wählt besten Node basierend auf Job-Gewicht
    method select_node {job_weight} {
        switch $job_weight {
            "heavy" {
                set preferred [list "node7" "node2" "node1"]
            }
            "medium" {
                set preferred [list "node2" "node1" "node7"]
            }
            default {  # light
                set preferred [list "node5" "node1" "node2"]
            }
        }
        
        # Prüfe Verfügbarkeit
        foreach node_id $preferred {
            if {[my check_node_available $node_id]} {
                return $node_id
            }
        }
        
        # Fallback
        return "node1"
    }
    
    # Prüft ob Node erreichbar ist
    method check_node_available {node_id} {
        global NODES
        
        if {![info exists NODES($node_id)]} {
            return false
        }
        
        array set node $NODES($node_id)
        
        # Nicht immer-verfügbare Nodes nur wenn explizit requested
        if {![dict_get_default [array get node] "always_available" false]} {
            # Für light-jobs prüfen wir ob online
            if {$node_id eq "node5"} {  # Redmi
                return [my _check_mobile_online]
            }
            return false
        }
        
        # Für immer-verfügbare Nodes: prüfe ob wirklich online
        if {[catch {
            set result [exec openclaw nodes status $node_id]
            return [expr {[llength [split $result "\n"]] > 0}]
        } error]} {
            return [dict_get_default [array get node] "always_available" false]
        }
    }
    
    # Prüft ob Redmi (Node 5) Internet hat
    method _check_mobile_online {} {
        if {[catch {
            set result [exec openclaw nodes status node5]
            return [string match "*online*" [string tolower $result]]
        } error]} {
            return false
        }
    }
    
    # Dispatched Job und gibt Info zurück
    method dispatch {job_script target_langs} {
        if {$target_langs eq ""} {
            set target_langs [list "perl5"]
        }
        
        set weight [my get_job_weight $job_script [llength $target_langs]]
        set selected_node [my select_node $weight]
        
        return [dict create \
            job $job_script \
            weight $weight \
            selected_node $selected_node \
            target_langs $target_langs \
            status dispatched]
    }
}

proc main {} {
    # Kommandozeilenargumente parsen
    set options {
        {job.arg "" "Path to job script"}
        {langs.arg "perl5" "Comma-separated target languages"}
        {weight.arg "" "Force job weight"}
        {execute "Actually execute on selected node"}
    }
    
    set usage ": $argv0 \[--job\] \[-j\] \[--langs\] \[-l\] \[--weight\] \[-w\] \[--execute\] \[-x\]"
    
    if {[catch {array set params [cmdline::getoptions argv $options $usage]} error]} {
        puts stderr $error
        exit 1
    }
    
    set job_path $params(job)
    if {$job_path eq "" || ![file exists $job_path]} {
        puts stderr "❌ Job not found: $job_path"
        exit 1
    }
    
    set dispatcher [JobDispatcher new]
    set target_langs [split $params(langs) ","]
    
    # Determine weight
    if {$params(weight) ne ""} {
        set weight $params(weight)
    } else {
        set weight [$dispatcher get_job_weight $job_path [llength $target_langs]]
    }
    
    # Select node
    set selected_node [$dispatcher select_node $weight]
    
    # Output
    puts "📦 Job Dispatch Information"
    puts [string repeat "=" 50]
    puts "Job: $job_path"
    puts "Size: [file_size $job_path] bytes"
    puts "Target langs: [join $target_langs ", "]"
    puts "Job weight: $weight"
    puts "Selected node: $selected_node"
    puts [string repeat "=" 50]
    
    if {$params(execute)} {
        puts "\n🚀 Executing on $selected_node..."
        # TODO: Implement remote execution
        puts "(Remote execution not yet implemented)"
    } else {
        puts "\n💡 To execute: [info nameofexecutable] [info script] --job $params(job) --execute"
    }
    
    $dispatcher destroy
}

if {[info script] eq $argv0} {
    main
}
