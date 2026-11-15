#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "fcbcfce9f21991cfc8f7a586018025e1071fad220753c3a9d06c010d306f0e5b", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "tcl"}
# dispatch_job.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package require json
package require uuid

namespace eval ::dispatch_job {
    variable NODES
    array set NODES {
        node1 {always_available true capacity medium priority 3 description "Gateway"}
        node2 {always_available false capacity high priority 1 description "ARM Server"}
        node3 {always_available false capacity medium priority 4 description "AMD Server"}
        node4 {always_available false capacity low priority 5 device "Redmi Note 11S"}
        node5 {always_available false capacity high priority 2 device "Lenovo"}
        node6 {always_available false device "Lenovo (Docker)"}
    }

    variable NODE_NAMES
    array set NODE_NAMES {
        node2 {openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122}
        node3 {openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125}
        node4 {openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39}
        node5 {openclaw-node5 "windows node (lenovo-7)"}
        node6 {openclaw-node6}
    }

    proc _job_weight_bytes {script_path target_langs_count} {
        # Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen.
        if {[file exists $script_path]} {
            set size [file size $script_path]
            return [expr {$size * $target_langs_count}]
        }
        return 0
    }

    proc fetch_node_status {} {
        # Return mapped OpenClaw connection states; None indicates lookup failure.
        if [catch {
            set result [exec openclaw nodes status --json]
            set payload [::json::json2dict $result]
            if {![dict exists $payload nodes]} {
                return ""
            }
            set nodes_list [dict get $payload nodes]
            set states [dict create]
            
            # Initialize all nodes as disconnected
            foreach node [array names ::dispatch_job::NODE_NAMES] {
                dict set states $node false
            }
            dict set states node1 true ;# successful Gateway status request
            
            foreach item $nodes_list {
                if {![dict exists $item displayName] || ![dict exists $item nodeId] || ![dict exists $item remoteIp]} {
                    continue
                }
                set names [list [string tolower [dict get $item displayName]] \
                                [string tolower [dict get $item nodeId]] \
                                [string tolower [dict get $item remoteIp]]]
                
                foreach {node aliases} [array get ::dispatch_job::NODE_NAMES] {
                    foreach name $names {
                        if {$name in $aliases && [dict get $item connected]} {
                            dict set states $node true
                            break
                        }
                    }
                }
            }
            return $states
        } err] {
            return ""
        }
    }

    proc get_job_weight {script_path target_langs_count} {
        # Bewertet Job-Gewicht
        if {![file exists $script_path]} {
            return "medium"
        }
        
        set total_work [_job_weight_bytes $script_path $target_langs_count]
        
        if {$total_work > 50000} {  ;# > 50KB
            return "heavy"
        } elseif {$total_work > 10000} {  ;# > 10KB
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
        return ""  ;# no verified reachable node
    }

    proc check_node_available {node_id} {
        # Use the live connection state rather than static availability.
        set states [fetch_node_status]
        if {$states eq ""} {
            return false
        }
        if {[dict exists $states $node_id]} {
            return [dict get $states $node_id]
        }
        return false
    }

    proc execute_translation {job transport} {
        # Execute via a supplied transport and verify its result belongs to the job.
        if {![dict exists $job selected_node] || $transport eq ""} {
            error "no verified node or authorized translation transport"
        }
        set response [$transport $job]
        if {![dict exists $response job_id] || ![dict exists $response selected_node] || ![dict exists $response target_language]} {
            error "invalid transport response"
        }
        foreach key {job_id selected_node target_language} {
            if {[dict get $response $key] ne [dict get $job $key]} {
                error "transport response does not match job"
            }
        }
        set code [dict get $response code]
        if {[dict get $response status] ne "ok" || $code eq "" || [string trim $code] eq ""} {
            error "translation did not complete with code"
        }
        return $code
    }

    proc _check_mobile_online {} {
        # Check Node4 (Redmi).
        return [check_node_available node4]
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
                job_id [::uuid::uuid generate] \
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
        
        return [dict create \
            job $job_script \
            weight $weight \
            selected_node $selected_node \
            target_langs $target_langs \
            translation_jobs $translation_jobs \
            status [expr {$selected_node ne "" ? "selected" : "unavailable"}]]
    }

    proc dispatch_abstraction_job {job_script target_langs} {
        # Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag.
        return [dispatch $job_script $target_langs]
    }

    proc main {} {
        global argv
        set options [dict create]
        
        # Simple argument parsing
        set i 0
        while {$i < [llength $argv]} {
            set arg [lindex $argv $i]
            incr i
            switch -exact -- $arg {
                --job - -j {
                    if {$i <= [llength $argv]} {
                        dict set options job [lindex $argv $i]
                        incr i
                    }
                }
                --langs - -l {
                    if {$i <= [llength $argv]} {
                        dict set options langs [lindex $argv $i]
                        incr i
                    }
                }
                --weight - -w {
                    if {$i <= [llength $argv]} {
                        dict set options weight [lindex $argv $i]
                        incr i
                    }
                }
                --execute - -x {
                    dict set options execute true
                }
                default {
                    if {[string match -* $arg]} {
                        puts stderr "Unknown option: $arg"
                        return 1
                    }
                }
            }
        }
        
        if {![dict exists $options job]} {
            puts stderr "Usage: [info script] --job JOB_SCRIPT \[--langs LANGS\] \[--weight WEIGHT\] \[--execute\]"
            return 1
        }
        
        set job_path [dict get $options job]
        if {![file exists $job_path]} {
            puts "❌ Job not found: $job_path"
            return 1
        }
        
        set target_langs perl5
        if {[dict exists $options langs]} {
            set target_langs [split [dict get $options langs] ","]
        }
        
        # Determine weight
        set weight ""
        if {[dict exists $options weight]} {
            set weight [dict get $options weight]
        } else {
            set weight [get_job_weight $job_path [llength $target_langs]]
        }
        
        # Select node
        set selected_node [select_node $weight]
        
        # Output
        puts "📦 Job Dispatch Information"
        puts "=================================================="
        puts "Job: $job_path"
        puts "Size: [file size $job_path] bytes"
        puts "Target langs: [join $target_langs ", "]"
        puts "Job weight: $weight"
        puts "Selected node: $selected_node"
        puts "=================================================="
        
        if {[dict exists $options execute]} {
            puts stderr "\nTranslation dispatch on $selected_node is not implemented."
            return 1
        } else {
            puts "\n💡 To execute: [info nameofexecutable] [info script] --job [dict get $options job] --execute"
        }
        return 0
    }
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    exit [::dispatch_job::main]
}
