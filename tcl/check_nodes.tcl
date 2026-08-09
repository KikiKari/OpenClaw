#!/usr/bin/env tclsh8.6
# check_nodes.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

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

proc dict_get_default {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    } else {
        return $default
    }
}

proc check_node_status {node_id} {
    global NODES
    # Prüft Status eines einzelnen Nodes
    set config [dict get $NODES $node_id]
    set always_available [dict_get_default $config "always_available" false]
    
    if {[catch {
        set result [exec -timeout 5 openclaw nodes status $node_id]
        set return_code 0
    } error]} {
        if {[string match "*timeout*" $error]} {
            return [dict create \
                id $node_id \
                online false \
                available $always_available \
                response "Timeout"]
        } else {
            return [dict create \
                id $node_id \
                online false \
                available $always_available \
                response "Error: $error"]
        }
    }
    
    set is_online [expr {$return_code == 0 && ([string match -nocase "*online*" $result] || [string match -nocase "*active*" $result])}]
    set response [string range [string trim $result] 0 99]
    if {$response eq ""} {set response "No response"}
    
    return [dict create \
        id $node_id \
        online $is_online \
        available $always_available \
        response $response]
}

proc print_table {nodes_status} {
    global NODES
    # Gibt Node-Status als Tabelle aus
    puts ""
    puts [string repeat "=" 90]
    puts [format "%-8s %-12s %-12s %-10s %-10s %s" "Node" "Status" "Verfügbar" "Kapazität" "Priorität" "Gerät/Beschreibung"]
    puts [string repeat "=" 90]
    
    foreach status $nodes_status {
        set node_id [dict get $status id]
        set config [dict get $NODES $node_id]
        
        set status_icon [expr {[dict get $status online] ? "🟢 Online" : "🔴 Offline"}]
        set avail_icon [expr {[dict get $status available] ? "✅ Immer" : "📱 Bedingt"}]
        set capacity [dict_get_default $config "capacity" "unknown"]
        set priority [dict_get_default $config "priority" "-"]
        set device [dict_get_default $config "device" [dict_get_default $config "description" ""]]
        
        puts [format "%-8s %-12s %-12s %-10s %-10s %s" $node_id $status_icon $avail_icon $capacity $priority $device]
    }
    
    puts [string repeat "=" 90]
    puts ""
    puts "Geprüft am: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
}

proc print_json {nodes_status} {
    global NODES
    # Gibt Node-Status als JSON aus
    set output [dict create]
    dict set output timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S} -gmt true]
    dict set output nodes [dict create]
    
    foreach status $nodes_status {
        set node_id [dict get $status id]
        dict set output nodes $node_id [dict create \
            status $status \
            config [dict get $NODES $node_id]]
    }
    
    puts [::json::write indented $output]
}

proc main {} {
    global argv NODES
    
    # Simple argument parsing
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
        }
    }
    
    puts "🔍 Prüfe Node-Status..."
    
    # Prüfe alle Nodes
    set nodes_status {}
    set sorted_keys [lsort [dict keys $NODES]]
    
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
        set output [dict create]
        dict set output timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S} -gmt true]
        dict set output nodes [dict create]
        
        foreach status $nodes_status {
            dict set output nodes [dict get $status id] $status
        }
        
        set fh [open $save_file w]
        puts $fh [::json::write indented $output]
        close $fh
        puts ""
        puts "💾 Gespeichert: $save_file"
    }
    
    # Zusammenfassung
    set online_count 0
    foreach status $nodes_status {
        if {[dict get $status online]} {
            incr online_count
        }
    }
    puts ""
    puts "📊 Zusammenfassung: $online_count/[llength $nodes_status] Nodes online"
}

main
