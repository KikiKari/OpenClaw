#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "6571175164916e0d8de4f7255a3e27bc47055caf0a8da983f3113c132014fdb0", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "tcl"}
# dispatch_job.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Job Dispatcher - Verteilt Jobs auf passende Nodes

package require json

# Node-Konfiguration
array set NODES {
    node1 {always_available true capacity medium priority 3 description "Gateway"}
    node2 {always_available false capacity high priority 1 description "ARM Server"}
    node3 {always_available false capacity medium priority 4 description "AMD Server"}
    node4 {always_available false capacity low priority 5 device "Redmi Note 11S"}
    node5 {always_available false capacity high priority 2 device "Lenovo"}
    node6 {always_available false device "Lenovo (Docker)"}
}

array set NODE_NAMES {
    node2 {openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122}
    node3 {openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125}
    node4 {openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39}
    node5 {openclaw-node5 "windows node (lenovo-7)"}
    node6 {openclaw-node6}
}

proc _job_weight_bytes {script_path target_langs_count} {
    # Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen
    if {[catch {file size $script_path} size]} {
        return 0
    }
    return [expr {$size * $target_langs_count}]
}

proc fetch_node_status {} {
    # Return mapped OpenClaw connection states; empty indicates lookup failure
    if {[catch {exec openclaw nodes status --json} result]} {
        return ""
    }
    
    if {[catch {::json::json2dict $result} payload]} {
        return ""
    }
    
    # Initialize all nodes as disconnected
    array set states {}
    foreach node [array names ::NODE_NAMES] {
        set states($node) false
    }
    
    # Parse the JSON response
    if {![info exists payload(nodes)]} {
        return ""
    }
    
    foreach item $payload(nodes) {
        if {![dict exists $item displayName] && ![dict exists $item nodeId] && ![dict exists $item remoteIp]} {
            continue
        }
        
        # Collect all names for this item
        set names {}
        if {[dict exists $item displayName]} {
            lappend names [string tolower [dict get $item displayName]]
        }
        if {[dict exists $item nodeId]} {
            lappend names [string tolower [dict get $item nodeId]]
        }
        if {[dict exists $item remoteIp]} {
            lappend names [string tolower [dict get $item remoteIp]]
        }
        
        # Check each node against its aliases
        foreach {node_id aliases} [array get ::NODE_NAMES] {
            foreach name $names {
                if {$name in $aliases && [dict exists $item connected] && [dict get $item connected]} {
                    set states($node_id) true
                }
            }
        }
    }
    
    # Gateway always available if we got here
    set states(node1) true
    
    # Convert array to dict for return
    set result_dict {}
    foreach {key value} [array get states] {
        dict set result_dict $key $value
    }
    return $result_dict
}

proc get_job_weight {script_path target_langs_count} {
    # Bewertet Job-Gewicht
    if {![file exists $script_path]} {
        return "medium"
    }
    
    set total_work [_job_weight_bytes $script_path $target_langs_count]
    
    if {$total_work > 50000} {  # > 50KB
        return "heavy"
    } elseif {$total_work > 10000} {  # > 10KB
        return "medium"
    } else {
        return "light"
    }
}

proc select_node {job_weight} {
    # Wählt besten Node basierend auf Job-Gewicht
    switch $job_weight {
        heavy {
            set preferred [list node1 node2 node5 node6]
        }
        medium {
            set preferred [list node1 node2 node3 node6]
        }
        light {
            set preferred [list node2 node1 node3 node4]
        }
        default {
            error "Unknown job weight: $job_weight"
        }
    }
    
    set states [fetch_node_status]
    if {$states eq ""} {
        return ""
    }
    
    foreach node_id $preferred {
        if {[dict exists $states $node_id] && [dict get $states $node_id]} {
            return $node_id
        }
    }
    
    return ""  # no verified reachable node
}

proc check_node_available {node_id} {
    # Use the live connection state rather than static availability
    set states [fetch_node_status]
    if {$states eq ""} {
        return false
    }
    if {[dict exists $states $node_id]} {
        return [dict get $states $node_id]
    }
    return false
}

proc _check_mobile_online {} {
    # Check Node4 (Redmi)
    return [check_node_available node4]
}

proc execute_translation {job transport} {
    # Execute via a supplied transport and verify its result belongs to the job
    if {![dict exists $job selected_node] || $transport eq ""} {
        error "no verified node or authorized translation transport"
    }
    
    set response [$transport $job]
    if {![dict size $response]} {
        error "invalid transport response"
    }
    
    foreach key {job_id selected_node target_language} {
        if {![dict exists $response $key] || [dict get $response $key] ne [dict get $job $key]} {
            error "transport response does not match job"
        }
    }
    
    set code [dict get $response code]
    if {[dict get $response status] ne "ok" || ![string length [string trim $code]]} {
        error "translation did not complete with code"
    }
    
    return $code
}

proc dispatch {job_script target_langs {source_text ""} {source_language ""}} {
    # Dispatched Job und gibt Info zurück
    if {$target_langs eq ""} {
        set target_langs [list perl5]
    }
    
    set weight [get_job_weight $job_script [llength $target_langs]]
    set selected_node [select_node $weight]
    
    set translation_jobs [list]
    foreach language $target_langs {
        set job [dict create \
            job_id [exec uuidgen] \
            source $job_script \
            target_language $language \
            selected_node $selected_node]
            
        if {$source_text ne ""} {
            dict set job source_text $source_text
        }
        if {$source_language ne ""} {
            dict set job source_language $source_language
        }
        
        lappend translation_jobs $job
    }
    
    set status "unavailable"
    if {$selected_node ne ""} {
        set status "selected"
    }
    
    return [dict create \
        job $job_script \
        weight $weight \
        selected_node $selected_node \
        target_langs $target_langs \
        translation_jobs $translation_jobs \
        status $status]
}

proc dispatch_abstraction_job {job_script target_langs} {
    # Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag
    return [dispatch $job_script $target_langs]
}

proc main {} {
    global argv
    
    # Simple argument parsing
    set job ""
    set langs "perl5"
    set weight ""
    set execute false
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            --job -
            -j {
                incr i
                set job [lindex $argv $i]
            }
            --langs -
            -l {
                incr i
                set langs [lindex $argv $i]
            }
            --weight -
            -w {
                incr i
                set weight [lindex $argv $i]
            }
            --execute -
            -x {
                set execute true
            }
        }
    }
    
    if {$job eq ""} {
        puts stderr "Usage: [info script] --job JOB_FILE \[OPTIONS\]"
        puts stderr "Options:"
        puts stderr "  -j, --job PATH       Path to job script"
        puts stderr "  -l, --langs LIST     Comma-separated target languages (default: perl5)"
        puts stderr "  -w, --weight WEIGHT  Force job weight (light|medium|heavy)"
        puts stderr "  -x, --execute        Actually execute on selected node"
        return 1
    }
    
    if {![file exists $job]} {
        puts stderr "❌ Job not found: $job"
        return 1
    }
    
    set target_langs [split $langs ","]
    
    # Determine weight
    if {$weight eq ""} {
        set weight [get_job_weight $job [llength $target_langs]]
    }
    
    # Select node
    set selected_node [select_node $weight]
    
    # Output
    puts "📦 Job Dispatch Information"
    puts [string repeat "=" 50]
    puts "Job: $job"
    puts "Size: [file size $job] bytes"
    puts "Target langs: [join $target_langs ", "]"
    puts "Job weight: $weight"
    puts "Selected node: $selected_node"
    puts [string repeat "=" 50]
    
    if {$execute} {
        puts stderr "\nTranslation dispatch on $selected_node is not implemented."
        return 1
    } else {
        puts "\n💡 To execute: [info nameofexecutable] [info script] --job $job --execute"
    }
    
    return 0
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    exit [main]
}
