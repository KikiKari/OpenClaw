#!/usr/bin/env tclsh8.6
# check_nodes.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

#
# Node-Status Checker - Prüft Verfügbarkeit aller Nodes
#

package require json

# Node-Konfiguration (sollte aus config file geladen werden)
array set NODES {
    node1 {always_available true capacity medium priority 2 description "Gateway-Master"}
    node2 {always_available true capacity medium priority 3 description "Stable Worker"}
    node3 {always_available false capacity medium priority 4 description "Bald verfügbar (nach Reorganisation)"}
    node5 {always_available false capacity low priority 5 device "Redmi Note 11S" description "Mobile (bei Internet verfügbar)"}
    node7 {always_available true capacity high priority 1 description "Docker Hauptarbeitspferd (bald verfügbar)"}
}

proc check_node_status {node_id} {
    global NODES
    
    # Parse node configuration
    array set config $NODES($node_id)
    set always_available [expr {$config(always_available) eq "true"}]
    
    # Try to execute command
    if {[catch {
        set result [exec openclaw nodes status $node_id]
        set return_code 0
    } error]} {
        set result ""
        set return_code 1
    }
    
    # Check if online
    set is_online 0
    if {$return_code == 0} {
        set lower_result [string tolower $result]
        if {[string match "*online*" $lower_result] || [string match "*active*" $lower_result]} {
            set is_online 1
        }
    }
    
    # Handle different error cases
    set response ""
    if {$result ne ""} {
        set response [string range [string trim $result] 0 99]
    } elseif {$return_code != 0} {
        if {[info exists error]} {
            set response "Error: $error"
        } else {
            set response "No response"
        }
    } else {
        set response "No response"
    }
    
    # Return status dictionary
    return [dict create \
        id $node_id \
        online $is_online \
        available $always_available \
        response $response]
}

proc print_table {nodes_status} {
    global NODES
    
    puts "\n[string repeat "=" 90]"
    puts [format "%-8s %-12s %-12s %-10s %-10s %s" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"]
    puts [string repeat "=" 90]
    
    foreach status_dict $nodes_status {
        set node_id [dict get $status_dict id]
        array set config $NODES($node_id)
        
        set status_icon [expr {[dict get $status_dict online] ? "🟢 Online" : "🔴 Offline"}]
        set avail_icon [expr {[dict get $status_dict available] ? "✅ Immer" : "📱 Bedingt"}]
        set capacity [expr {[info exists config(capacity)] ? $config(capacity) : "unknown"}]
        set priority [expr {[info exists config(priority)] ? $config(priority) : "-"}]
        set device [expr {[info exists config(device)] ? $config(device) : [expr {[info exists config(description)] ? $config(description) : ""}]}]
        
        puts [format "%-8s %-12s %-12s %-10s %-10s %s" $node_id $status_icon $avail_icon $capacity $priority $device]
    }
    
    puts [string repeat "=" 90]
    
    # Get current time
    set now [clock seconds]
    set formatted_time [clock format $now -format "%Y-%m-%d %H:%M:%S"]
    puts "\nGeprüft am: $formatted_time"
}

proc print_json {nodes_status} {
    global NODES
    
    # Create timestamp
    set now [clock seconds]
    set iso_time [clock format $now -format "%Y-%m-%dT%H:%M:%S"]
    
    # Build output structure
    set output [dict create timestamp $iso_time]
    set nodes_dict [dict create]
    
    foreach status_dict $nodes_status {
        set node_id [dict get $status_dict id]
        dict set nodes_dict $node_id [dict create status $status_dict config $NODES($node_id)]
    }
    
    dict set output nodes $nodes_dict
    
    # Convert to JSON
    puts [::json::write indented $output]
}

proc main {} {
    global argv NODES
    
    # Parse command line arguments
    set format "table"
    set save_file ""
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch -- $arg {
            "--format" - "-f" {
                incr i
                set format [lindex $argv $i]
            }
            "--save" - "-s" {
                incr i
                set save_file [lindex $argv $i]
            }
            default {
                if {[string match "-*" $arg]} {
                    puts stderr "Unbekanntes Argument: $arg"
                    exit 1
                }
            }
        }
    }
    
    puts "🔍 Prüfe Node-Status..."
    
    # Prüfe alle Nodes
    set nodes_status [list]
    set sorted_keys [lsort [array names NODES]]
    
    foreach node_id $sorted_keys {
        puts -nonewline "  → $node_id... "
        flush stdout
        
        set status [check_node_status $node_id]
        lappend nodes_status $status
        
        if {[dict get $status online]} {
            puts "✓"
        } else {
            puts "✗"
        }
    }
    
    # Ausgabe
    if {$format eq "table"} {
        print_table $nodes_status
    } else {
        print_json $nodes_status
    }
    
    # Speichern
    if {$save_file ne ""} {
        # Create timestamp
        set now [clock seconds]
        set iso_time [clock format $now -format "%Y-%m-%dT%H:%M:%S"]
        
        # Build output structure
        set output [dict create timestamp $iso_time]
        set nodes_dict [dict create]
        
        foreach status_dict $nodes_status {
            set node_id [dict get $status_dict id]
            dict set nodes_dict $node_id $status_dict
        }
        
        dict set output nodes $nodes_dict
        
        # Write to file
        set fh [open $save_file w]
        puts $fh [::json::write indented $output]
        close $fh
        
        puts "\n💾 Gespeichert: $save_file"
    }
    
    # Zusammenfassung
    set online_count 0
    foreach status_dict $nodes_status {
        if {[dict get $status_dict online]} {
            incr online_count
        }
    }
    
    set total_count [llength $nodes_status]
    puts "\n📊 Zusammenfassung: $online_count/$total_count Nodes online"
}

# Run main function
main
