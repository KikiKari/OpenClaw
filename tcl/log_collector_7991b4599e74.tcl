#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "4014a0003cb1a9769f67b03916b69e6bcac188e4f6f361d2b6eb01d4ca4db69f", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "tcl"}
# log_collector.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
# auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Log Collector Sub-Agent
# Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden

package require sqlite3
package require json

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_PATH "$WORKSPACE/db/logs.db"
set LOG_DIR "$WORKSPACE/logs/log-collector"

# Create log directory if it doesn't exist
file mkdir $LOG_DIR

proc log {level msg} {
    global LOG_DIR
    set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    set line "\[$timestamp\] \[$level\] $msg"
    puts $line
    
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set log_file "$LOG_DIR/$today.log"
    set fh [open $log_file a]
    puts $fh $line
    close $fh
}

proc info {msg} {
    log "INFO" $msg
}

proc error {msg} {
    log "ERROR" $msg
}

proc connect_db {} {
    global DB_PATH WORKSPACE
    sqlite3 db $DB_PATH
    
    # Initialize schema if database is empty
    init_schema
    return db
}

proc init_schema {} {
    global WORKSPACE
    # Check if any tables exist
    set tables [db eval {SELECT name FROM sqlite_master WHERE type='table'}]
    if {[llength $tables] == 0} {
        set schema_path "$WORKSPACE/db/logs.db.schema.sql"
        if {[file exists $schema_path]} {
            set fh [open $schema_path r]
            set schema [read $fh]
            close $fh
            db eval $schema
            db eval {COMMIT}
        }
    }
}

proc get_nodes {} {
    set nodes {}
    db eval {SELECT * FROM nodes} row {
        lappend nodes [array get row]
    }
    return $nodes
}

proc check_vpn {ip} {
    if {[catch {exec ping -c 1 -W 3 $ip} result]} {
        return 0
    } else {
        return [regexp {0 received} $result] == 0
    }
}

proc ssh_connect_and_collect {node_dict} {
    global node_id vpn_ip
    
    # Extract values from dict
    array set node $node_dict
    set node_id $node(node_id)
    
    # Get VPN IP
    if {[info exists node(vpn_ip)] && $node(vpn_ip) ne ""} {
        set vpn_ip $node(vpn_ip)
    } elseif {[info exists node(tailscale_ip)] && $node(tailscale_ip) ne ""} {
        set vpn_ip $node(tailscale_ip)
    } elseif {[info exists node(wireguard_ip)] && $node(wireguard_ip) ne ""} {
        set vpn_ip $node(wireguard_ip)
    } else {
        error "$node_id: Keine VPN-IP konfiguriert"
        return
    }
    
    # 1. VPN-Check
    info "$node_id: Prüfe VPN $vpn_ip..."
    if {![check_vpn $vpn_ip]} {
        error "$node_id: VPN nicht erreichbar"
        log_ssh_connection $node_id "tailscale" 0 "VPN unreachable"
        return
    }
    
    # 2. SSH-Verbindung
    info "$node_id: Verbinde via SSH..."
    set logs_collected {}
    
    # Commands to collect logs
    set log_commands {
        "journalctl -n 500 --no-pager"
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
    }
    
    foreach cmd $log_commands {
        if {[catch {
            set result [exec ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no openclaw@$vpn_ip $cmd]
            lappend logs_collected [dict create command $cmd output $result timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]]
        } err]} {
            error "$node_id: SSH Fehler bei Kommando '$cmd': $err"
            log_ssh_connection $node_id "ssh" 0 $err
            return
        }
    }
    
    # Success logging
    log_ssh_connection $node_id "ssh" 1 ""
    
    # Save to database
    insert_logs $node_id $logs_collected
    
    return [llength $logs_collected]
}

proc log_ssh_connection {node_id conn_type success error} {
    db eval {
        INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
        VALUES ($node_id, $conn_type, $success, $error)
    }
}

proc insert_logs {node_id logs} {
    set retention [expr {[clock seconds] + 30*24*60*60}]
    set retention_iso [clock format $retention -format "%Y-%m-%dT%H:%M:%S"]
    
    set count 0
    foreach log_entry $logs {
        set cmd [dict get $log_entry command]
        set output [dict get $log_entry output]
        
        # Truncate command and output
        if {[string length $cmd] > 50} {
            set cmd [string range $cmd 0 49]
        }
        if {[string length $output] > 10000} {
            set output [string range $output 0 9999]
        }
        
        db eval {
            INSERT INTO logs (node_id, log_type, source, content, severity, 
                            collected_by, collection_method, retention_until)
            VALUES ($node_id, 'system', $cmd, $output, 'info', 'node1', 'ssh', $retention_iso)
        }
        incr count
    }
    
    info "$node_id: $count Log-Einträge gespeichert"
}

proc cleanup_retention {} {
    set deleted [db eval {
        DELETE FROM logs WHERE retention_until < datetime('now');
        SELECT changes();
    }]
    info "Retention-Cleanup: $deleted alte Logs gelöscht"
    return $deleted
}

proc run_collection_cycle {} {
    info "============================================================"
    info "LOG COLLECTOR CYCLE START"
    info "============================================================"
    
    connect_db
    
    # 1. Nodes holen
    set nodes [get_nodes]
    info "Gefunden: [llength $nodes] Nodes"
    
    # 2. Collection-Run starten
    db eval {
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (CURRENT_TIMESTAMP, [llength $nodes])
    }
    set run_id [db last_insert_rowid]
    
    # 3. Für jeden Node sammeln
    set success_count 0
    set failed_count 0
    set total_logs 0
    
    foreach node $nodes {
        array set node_data $node
        if {$node_data(node_id) eq "node1"} {
            # Lokale Logs (Gateway selbst)
            info "node1: Lokale Collection (Gateway)"
            incr success_count
        } else {
            # Remote-Node abfragen
            if {[catch {set result [ssh_connect_and_collect $node]} err]} {
                error "$node_data(node_id): $err"
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
            finished_at = CURRENT_TIMESTAMP,
            nodes_success = $success_count,
            nodes_failed = $failed_count,
            logs_collected = $total_logs
        WHERE run_id = $run_id
    }
    
    # 5. Retention-Cleanup
    info "Retention-Cleanup (30 Tage)..."
    cleanup_retention
    
    info "============================================================"
    info "SUMMARY: $success_count OK, $failed_count Failed, $total_logs Logs"
    info "============================================================"
}

proc main {} {
    puts "============================================================"
    puts "LOG COLLECTOR"
    puts "============================================================"
    
    if {[catch {
        run_collection_cycle
    } err]} {
        puts "CRITICAL ERROR: $err"
        puts $::errorInfo
        exit 1
    }
}

# Start the program
main
