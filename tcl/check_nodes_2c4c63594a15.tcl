#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "36cc591f92aaed30812b8e3d310ead274e5331f3ced3bd8fb746f4d712d2a560", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "tcl"}
# check_nodes.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Node-Status Checker - Prüft Verfügbarkeit aller Nodes

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
    
    # Parse node config
    array set config {}
    foreach {key val} $NODES($node_id) {
        set config($key) $val
    }
    
    # Default values
    if {![info exists config(always_available)]} {
        set config(always_available) false
    }
    
    # Execute command
    if {[catch {exec openclaw nodes status $node_id} result]} {
        if {[string match "*timeout*" $result]} {
            return [dict create id $node_id online false available $config(always_available) response "Timeout"]
        } else {
            return [dict create id $node_id online false available $config(always_available) response "Error: $result"]
        }
    } else {
        set is_online [expr {[llength $result] > 0 && ([string first "online" [string tolower $result]] != -1 || [string first "active" [string tolower $result]] != -1)}]
        set response [string range $result 0 99]
        if {$response eq ""} {set response "No response"}
        return [dict create id $node_id online $is_online available $config(always_available) response $response]
    }
}

proc print_table {nodes_status} {
    global NODES
    
    puts "\n[string repeat "=" 90]"
    puts [format "%-8s %-12s %-12s %-10s %-10s %s" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"]
    puts "[string repeat "=" 90]"
    
    foreach status_dict $nodes_status {
        set node_id [dict get $status_dict id]
        set is_online [dict get $status_dict online]
        set available [dict get $status_dict available]
        
        # Parse node config
        array set config {}
        foreach {key val} $NODES($node_id) {
            set config($key) $val
        }
        
        set status_icon [expr {$is_online ? "🟢 Online" : "🔴 Offline"}]
        set avail_icon [expr {$available ? "✅ Immer" : "📱 Bedingt"}]
        set capacity [expr {[info exists config(capacity)] ? $config(capacity) : "unknown"}]
        set priority [expr {[info exists config(priority)] ? $config(priority) : "-"}]
        set device [expr {[info exists config(device)] ? $config(device) : ([info exists config(description)] ? $config(description) : "")}]
        
        puts [format "%-8s %-12s %-12s %-10s %-10s %s" $node_id $status_icon $avail_icon $capacity $priority $device]
    }
    
    puts "[string repeat "=" 90]"
    puts ""
    puts "Geprüft am: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
}

proc print_json {nodes_status} {
    global NODES
    
    set output [dict create timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] nodes [dict create]]
    
    foreach status_dict $nodes_status {
        set node_id [dict get $status_dict id]
        dict set output nodes $node_id [dict create status $status_dict config $NODES($node_id)]
    }
    
    puts [::json::write indented $output]
}

proc main {} {
    global argv argc NODES
    
    # Simple argument parsing
    set format "table"
    set save_file ""
    
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        if {$arg eq "--format" || $arg eq "-f"} {
            incr i
            set format [lindex $argv $i]
        } elseif {$arg eq "--save" || $arg eq "-s"} {
            incr i
            set save_file [lindex $argv $i]
        }
    }
    
    puts "🔍 Prüfe Node-Status..."
    
    # Prüfe alle Nodes
    set nodes_status {}
    set sorted_keys [lsort [array names NODES]]
    
    foreach node_id $sorted_keys {
        puts -nonewline "  → $node_id... "
        flush stdout
        set status [check_node_status $node_id]
        lappend nodes_status $status
        puts [expr {[dict get $status online] ? "✓" : "✗"}]
    }
    
    # Ausgabe
    if {$format eq "table"} {
        print_table $nodes_status
    } else {
        print_json $nodes_status
    }
    
    # Speichern
    if {$save_file ne ""} {
        set output [dict create timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] nodes [dict create]]
        foreach status_dict $nodes_status {
            set node_id [dict get $status_dict id]
            dict set output nodes $node_id $status_dict
        }
        
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
    puts "\n📊 Zusammenfassung: $online_count/[llength $nodes_status] Nodes online"
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
