#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "b316bacc63632cfd716cc9dbd398a947cc3301c67323bdd2c1688f9c828f69f0", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "tcl"}
# test_multinode_fallback.py — portiert nach tcl
# Quelle: python, workspace@local:scripts/test_multinode_fallback.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# 
# Testet Multi-Node Fallback-Logik des db-maintainer
# Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
# 

package require json

set WORKSPACE "/home/openclaw/.openclaw/workspace"

proc check_node_reachable {node_id} {
    # Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
    set aliases [list [string tolower $node_id]]
    set node2_names [list "openclaw-node2" "arm64-node" "v2202604104722449961" "v2202604104722449961.taild25fea.ts.net"]
    if {[lsearch -nocase $node2_names $node_id] != -1} {
        foreach name $node2_names {
            lappend aliases [string tolower $name]
        }
    }
    if {[catch {
        set result [exec openclaw nodes status --json]
        set payload [::json::json2dict $result]
        foreach node [dict get $payload nodes] {
            if {[dict exists $node displayName] && [dict exists $node connected]} {
                set display_name [string tolower [dict get $node displayName]]
                set connected [dict get $node connected]
                if {$connected && [lsearch -nocase $aliases $display_name] != -1} {
                    return true
                }
            }
        }
    } err]} {
        return false
    }
    return false
}

proc spawn_on_node {node_id task} {
    # Versucht Task auf Node auszuführen
    puts "Versuche Task auf Node $node_id zu starten..."
    if {[catch {
        # Simuliert: openclaw agent spawn --node {node_id}
        set result [exec echo "Spawned on $node_id: $task"]
        puts "✅ Erfolgreich delegiert an $node_id"
        return true
    } err]} {
        puts "❌ Node $node_id nicht erreichbar: $err"
        return false
    }
}

proc execute_locally {task} {
    # Führt Task lokal aus (Fallback)
    global WORKSPACE
    puts "🔄 Fallback: Führe Task lokal aus..."
    if {[catch {
        if {$task eq "db_maintainer"} {
            set script_path "$WORKSPACE/skills/db-maintainer/scripts/db_maintainer.py"
            if {[catch {exec python3 $script_path} result]} {
                puts "❌ Fehler: [string range $result 0 199]"
                return false
            } else {
                puts "✅ Lokale Ausführung erfolgreich"
                return true
            }
        }
    } err]} {
        puts "❌ Lokale Ausführung fehlgeschlagen: $err"
        return false
    }
}

proc main {} {
    puts [string repeat "=" 60]
    puts "MULTI-NODE FALLBACK TEST"
    puts [string repeat "=" 60]
    puts ""
    
    # Konfiguration
    set primary_node "v2202604104722449961.taild25fea.ts.net"  ;# Node 2
    set task "db_maintainer"
    
    puts "Primärer Node: $primary_node"
    puts "Task: $task"
    puts ""
    
    # 1. Prüfe Node-Erreichbarkeit
    puts "--- 1. Prüfe Node-Erreichbarkeit ---"
    if {[check_node_reachable $primary_node]} {
        puts "✅ Node $primary_node ist erreichbar"
        
        # 2. Versuche Delegation
        puts "\n--- 2. Versuche Delegation ---"
        if {[spawn_on_node $primary_node $task]} {
            puts "\n✅ MULTI-NODE: Task erfolgreich delegiert"
            return 0
        } else {
            puts "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback..."
        }
    } else {
        puts "❌ Node $primary_node nicht erreichbar"
        puts "🔄 Fallback wird aktiviert..."
    }
    
    # 3. Lokale Ausführung (Fallback)
    puts "\n--- 3. Lokale Ausführung (Fallback) ---"
    if {[execute_locally $task]} {
        puts "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt"
        return 0
    } else {
        puts "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
        return 1
    }
}

exit [main]
