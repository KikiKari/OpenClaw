#!/usr/bin/env tclsh8.6
# log_collector.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
# auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Log Collector Sub-Agent
# Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden

package require sqlite3
package require json

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_PATH "$WORKSPACE/db/logs.db"
set LOG_DIR "$WORKSPACE/logs/log-collector"

file mkdir $LOG_DIR

proc logger_new {} {
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set log_file "$::LOG_DIR/$today.log"
    return [list $log_file]
}

proc logger_log {logger level msg} {
    lassign $logger log_file
    set ts [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    set line "\[$ts\] \[$level\] $msg"
    puts $line
    set fh [open $log_file a]
    puts $fh $line
    close $fh
}

proc logger_info {logger msg} {
    logger_log $logger INFO $msg
}

proc logger_error {logger msg} {
    logger_log $logger ERROR $msg
}

proc logcollector_new {} {
    set logger [logger_new]
    return [list $logger ""]
}

proc logcollector_connect_db {logcollector} {
    lassign $logcollector logger _
    sqlite3 db $::DB_PATH
    db eval {PRAGMA foreign_keys = ON}
    
    # Schema initialisieren falls nicht existiert
    set tables [db eval {SELECT name FROM sqlite_master WHERE type='table'}]
    if {$tables eq ""} {
        set schema_path "$::WORKSPACE/db/logs.db.schema.sql"
        if {[file exists $schema_path]} {
            set fh [open $schema_path r]
            set schema [read $fh]
            close $fh
            db eval $schema
        }
    }
    
    lset logcollector 1 db
    return $logcollector
}

proc logcollector_get_nodes {logcollector} {
    lassign $logcollector logger _
    set nodes {}
    db eval {SELECT * FROM nodes} row {
        lappend nodes [array get row]
    }
    return $nodes
}

proc logcollector_check_vpn {logcollector ip} {
    lassign $logcollector logger _
    if {[catch {exec ping -c 1 -W 3 $ip} result]} {
        return 0
    } else {
        return [expr {[lindex [split $result] end] eq "0"}]
    }
}

proc logcollector_ssh_connect_and_collect {logcollector node_dict} {
    lassign $logcollector logger _
    
    array set node $node_dict
    set node_id $node(node_id)
    
    set vpn_ip ""
    if {[info exists node(vpn_ip)] && $node(vpn_ip) ne ""} {
        set vpn_ip $node(vpn_ip)
    } elseif {[info exists node(tailscale_ip)] && $node(tailscale_ip) ne ""} {
        set vpn_ip $node(tailscale_ip)
    } elseif {[info exists node(wireguard_ip)] && $node(wireguard_ip) ne ""} {
        set vpn_ip $node(wireguard_ip)
    }
    
    if {$vpn_ip eq ""} {
        logger_error $logger "$node_id: Keine VPN-IP konfiguriert"
        return
    }
    
    # 1. VPN-Check
    logger_info $logger "$node_id: Prüfe VPN $vpn_ip..."
    if {![logcollector_check_vpn $logcollector $vpn_ip]} {
        logger_error $logger "$node_id: VPN nicht erreichbar"
        logcollector_log_ssh_connection $logcollector $node_id tailscale 0 "VPN unreachable"
        return
    }
    
    # 2. SSH-Verbindung
    logger_info $logger "$node_id: Verbinde via SSH..."
    set logs_collected {}
    
    set log_commands {
        "journalctl -n 500 --no-pager"
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
    }
    
    foreach cmd $log_commands {
        if {[catch {
            exec ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no openclaw@$vpn_ip $cmd
        } output]} {
            logger_error $logger "$node_id: SSH Fehler bei Kommando '$cmd': $output"
            continue
        }
        
        lappend logs_collected [dict create \
            command $cmd \
            output $output \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        }
    }
    
    # Erfolg loggen
    logcollector_log_ssh_connection $logcollector $node_id ssh 1 ""
    
    # In DB speichern
    logcollector_insert_logs $logcollector $node_id $logs_collected
    
    return [llength $logs_collected]
}

proc logcollector_log_ssh_connection {logcollector node_id conn_type success error} {
    lassign $logcollector logger db
    
    db eval {
        INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
        VALUES ($node_id, $conn_type, $success, $error)
    }
}

proc logcollector_insert_logs {logcollector node_id logs} {
    lassign $logcollector logger db
    
    set retention [expr {[clock seconds] + 30*24*60*60}]
    set retention_date [clock format $retention -format "%Y-%m-%d %H:%M:%S"]
    
    foreach log_entry $logs {
        set cmd [dict get $log_entry command]
        set output [dict get $log_entry output]
        
        # Begrenze Länge der Felder
        if {[string length $cmd] > 50} {
            set cmd [string range $cmd 0 49]
        }
        if {[string length $output] > 10000} {
            set output [string range $output 0 9999]
        }
        
        db eval {
            INSERT INTO logs (node_id, log_type, source, content, severity, 
                            collected_by, collection_method, retention_until)
            VALUES ($node_id, 'system', $cmd, $output, 'info', 'node1', 'ssh', $retention_date)
        }
    }
    
    logger_info $logger "$node_id: [llength $logs] Log-Einträge gespeichert"
}

proc logcollector_cleanup_retention {logcollector} {
    lassign $logcollector logger db
    
    set deleted [db eval {
        DELETE FROM logs WHERE retention_until < date('now');
        SELECT changes();
    }]
    
    logger_info $logger "Retention-Cleanup: $deleted alte Logs gelöscht"
    return $deleted
}

proc logcollector_run_collection_cycle {logcollector} {
    lassign $logcollector logger _
    
    logger_info $logger [string repeat "=" 60]
    logger_info $logger "LOG COLLECTOR CYCLE START"
    logger_info $logger [string repeat "=" 60]
    
    set logcollector [logcollector_connect_db $logcollector]
    
    # 1. Nodes holen
    set nodes [logcollector_get_nodes $logcollector]
    logger_info $logger "Gefunden: [llength $nodes] Nodes"
    
    # 2. Collection-Run starten
    db eval {
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (datetime('now'), [llength $nodes])
    }
    set run_id [db last_insert_rowid]
    
    # 3. Für jeden Node sammeln
    set success_count 0
    set failed_count 0
    set total_logs 0
    
    foreach node $nodes {
        array set node_data $node
        set node_id $node_data(node_id)
        
        if {$node_id eq "node1"} {
            # Lokale Logs (Gateway selbst)
            logger_info $logger "node1: Lokale Collection (Gateway)"
            incr success_count
        } else {
            # Remote-Node abfragen
            if {[catch {logcollector_ssh_connect_and_collect $logcollector $node} result]} {
                logger_error $logger "$node_id: Fehler beim Sammeln: $result"
                incr failed_count
            } else {
                if {$result ne ""} {
                    incr success_count
                    incr total_logs $result
                } else {
                    incr failed_count
                }
            }
        }
    }
    
    # 4. Run abschließen
    db eval {
        UPDATE collection_runs SET
            finished_at = datetime('now'),
            nodes_success = $success_count,
            nodes_failed = $failed_count,
            logs_collected = $total_logs
        WHERE run_id = $run_id
    }
    
    # 5. Retention-Cleanup
    logger_info $logger "Retention-Cleanup (30 Tage)..."
    logcollector_cleanup_retention $logcollector
    
    logger_info $logger [string repeat "=" 60]
    logger_info $logger "SUMMARY: $success_count OK, $failed_count Failed, $total_logs Logs"
    logger_info $logger [string repeat "=" 60]
}

proc main {} {
    puts [string repeat "=" 60]
    puts "LOG COLLECTOR"
    puts [string repeat "=" 60]
    
    set collector [logcollector_new]
    
    if {[catch {
        logcollector_run_collection_cycle $collector
    } err]} {
        puts "CRITICAL ERROR: $err"
        puts $::errorInfo
        exit 1
    }
}

main
