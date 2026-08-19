#!/usr/bin/env tclsh8.6
# node_health.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

#
# Node Health Monitor - Multi-Node Gesundheitsüberwachung
#

package require json

# Konfiguration
set WORKSPACE "/home/openclaw/.openclaw/workspace"
set HEALTH_DB "$WORKSPACE/db/health.db"
set LOG_FILE "$WORKSPACE/logs/node-health.log"

# Node-Definitionen
array set NODES {
    node1 {name "Node 1" host "localhost" user "openclaw" critical true}
    node2 {name "Node 2" host "10.10.0.2" user "root" ssh_key "~/.ssh/id_rsa" ssh_opts "-o ConnectTimeout=10 -o BatchMode=yes"}
    node3 {name "Node 3" host "localhost" user "root" port 18794 ssh_opts "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes" disk_warning 85}
    node5 {name "Redmi" host "192.168.1.x" user "openclaw" optional true}
}

proc log {message {level "INFO"}} {
    # Logging
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    
    global LOG_FILE
    file mkdir [file dirname $LOG_FILE]
    set f [open $LOG_FILE a]
    puts $f $entry
    close $f
}

proc check_ping {host {timeout 10}} {
    # Prüft Erreichbarkeit (Timeout seconds)
    if {[catch {exec ping -c 1 -W $timeout $host} result]} {
        return 0
    } else {
        return [expr {[lindex [split $result] 0] eq "0"}]
    }
}

proc check_ssh {node_config} {
    # Prüft SSH-Verbindung
    set host [dict get $node_config host]
    set user [dict get $node_config user]
    if {$user eq ""} {set user "root"}
    
    set ssh_opts ""
    if {[dict exists $node_config ssh_opts]} {
        set ssh_opts [dict get $node_config ssh_opts]
    }
    
    set port ""
    if {[dict exists $node_config port]} {
        set port [dict get $node_config port]
    }
    
    set cmd "ssh"
    if {$ssh_opts ne ""} {
        append cmd " $ssh_opts"
    }
    if {$port ne ""} {
        append cmd " -p $port"
    }
    append cmd " -o ConnectTimeout=10 -o BatchMode=yes ${user}@${host} echo \"OK\""
    
    if {[catch {exec {*}$cmd} result]} {
        return 0
    } else {
        return [expr {[string match "*OK*" $result]}]
    }
}

proc get_node_metrics {node_config} {
    # Holt Metriken via SSH
    set host [dict get $node_config host]
    set user [dict get $node_config user]
    if {$user eq ""} {set user "root"}
    
    array set metrics {
        timestamp ""
        available false
        cpu ""
        ram ""
        disk ""
        load ""
        gateway_status ""
    }
    set metrics(timestamp) [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    
    # SSH-Command für alle Metriken
    set cmd "ssh -o ConnectTimeout=10 ${user}@${host} '
        # CPU
        echo \"CPU:\$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\\$2}\" | cut -d\"%\" -f1)\"
        
        # RAM
        echo \"RAM:\$(free | grep Mem | awk \"{print (\\\$3/\\\$2) * 100.0}\")\"
        
        # Disk
        echo \"DISK:\$(df -h / | tail -1 | awk \"{print \\\$5}\" | tr -d \"%\")\"
        
        # Load
        echo \"LOAD:\$(uptime | awk -F\"load average:\" \"{print \\\$2}\" | awk \"{print \\\$1}\" | tr -d \",\")\"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"
        fi
    '"
    
    if {[catch {exec /bin/sh -c $cmd} result]} {
        log "Error checking metrics: $result" "ERROR"
        return [array get metrics]
    } else {
        set metrics(available) true
        
        foreach line [split $result "\n"] {
            if {[string first ":" $line] != -1} {
                set parts [split $line ":"]
                set key [lindex $parts 0]
                set value [join [lrange $parts 1 end] ":"]
                
                switch $key {
                    "CPU" {
                        if {$value ne ""} {set metrics(cpu) [expr {double($value)}]}
                    }
                    "RAM" {
                        if {$value ne ""} {set metrics(ram) [expr {double($value)}]}
                    }
                    "DISK" {
                        if {$value ne ""} {set metrics(disk) [expr {int($value)}]}
                    }
                    "LOAD" {
                        if {$value ne ""} {set metrics(load) [expr {double($value)}]}
                    }
                    "GATEWAY" {
                        set metrics(gateway_status) $value
                    }
                }
            }
        }
    }
    
    return [array get metrics]
}

proc check_alerts {node_id node_config metrics} {
    # Prüft Schwellwerte und generiert Alerts
    set alerts {}
    
    # Verfügbarkeit
    if {![dict get $metrics available]} {
        set optional false
        if {[dict exists $node_config optional]} {
            set optional [dict get $node_config optional]
        }
        if {!$optional} {
            lappend alerts [list level "CRITICAL" message "Node [dict get $node_config name] nicht erreichbar!"]
        }
    } else {
        # CPU
        if {[dict exists $metrics cpu] && [dict get $metrics cpu] ne "" && [dict get $metrics cpu] > 90} {
            lappend alerts [list level "WARNING" message "Node [dict get $node_config name]: CPU bei [format "%.1f" [dict get $metrics cpu]]%"]
        }
        
        # RAM
        if {[dict exists $metrics ram] && [dict get $metrics ram] ne "" && [dict get $metrics ram] > 90} {
            lappend alerts [list level "WARNING" message "Node [dict get $node_config name]: RAM bei [format "%.1f" [dict get $metrics ram]]%"]
        }
        
        # Disk
        set disk_threshold 85
        if {[dict exists $node_config disk_warning]} {
            set disk_threshold [dict get $node_config disk_warning]
        }
        if {[dict exists $metrics disk] && [dict get $metrics disk] ne "" && [dict get $metrics disk] > $disk_threshold} {
            set level "WARNING"
            if {[dict get $metrics disk] > 95} {
                set level "CRITICAL"
            }
            lappend alerts [list level $level message "Node [dict get $node_config name]: Disk bei [dict get $metrics disk]%"]
        }
        
        # Gateway
        set critical false
        if {[dict exists $node_config critical]} {
            set critical [dict get $node_config critical]
        }
        if {$critical && [dict exists $metrics gateway_status] && [dict get $metrics gateway_status] eq "inactive"} {
            lappend alerts [list level "CRITICAL" message "Node [dict get $node_config name]: OpenClaw Gateway nicht aktiv!"]
        }
    }
    
    return $alerts
}

proc send_alert {alert} {
    # Sendet Alert via channel-status-agent
    global WORKSPACE
    set script "$WORKSPACE/skills/channel-status-agent/scripts/channel_status.py"
    
    if {[file exists $script]} {
        set cmd [list python3 $script --type alert --message "[dict get $alert level]: [dict get $alert message]"]
        if {[catch {exec {*}$cmd} result]} {
            log "Failed to send alert: $result" "ERROR"
        } else {
            log "Alert sent: [dict get $alert message]"
        }
    } else {
        log "Channel status script not found: $script" "ERROR"
    }
}

proc main {} {
    # Hauptfunktion
    global argv argc NODES WORKSPACE
    
    # Default Werte
    set node "all"
    set check "all"
    set alert 0
    
    # Argumente parsen
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            "--node" {
                incr i
                set node [lindex $argv $i]
            }
            "--check" {
                incr i
                set check [lindex $argv $i]
            }
            "--alert" {
                set alert 1
            }
            default {
                if {[string match "-*" $arg]} {
                    log "Unbekanntes Argument: $arg" "ERROR"
                    exit 1
                }
            }
        }
    }
    
    # Nodes bestimmen
    set nodes_to_check {}
    if {$node eq "all"} {
        set nodes_to_check [array get NODES]
    } else {
        if {[info exists NODES($node)]} {
            lappend nodes_to_check $node $NODES($node)
        } else {
            log "Unknown node: $node" "ERROR"
            exit 1
        }
    }
    
    # Health-Checks durchführen
    set all_alerts {}
    
    foreach {node_id node_config} $nodes_to_check {
        log "Checking [dict get $node_config name] ($node_id)"
        
        # Ping
        if {$check in {"ping" "all"}} {
            if {[dict get $node_config host] ne "localhost"} {
                set ping_ok [check_ping [dict get $node_config host]]
                log "  Ping: [expr {$ping_ok ? "OK" : "FAILED"}]"
            }
        }
        
        # SSH
        if {$check in {"ssh" "all"}} {
            set ssh_ok [check_ssh $node_config]
            log "  SSH: [expr {$ssh_ok ? "OK" : "FAILED"}]"
        }
        
        # Metriken
        if {$check in {"metrics" "all"}} {
            set metrics [get_node_metrics $node_config]
            
            if {[dict get $metrics available]} {
                if {[dict exists $metrics cpu] && [dict get $metrics cpu] ne ""} {
                    log "  CPU: [format "%.1f" [dict get $metrics cpu]]%"
                } else {
                    log "  CPU: N/A"
                }
                if {[dict exists $metrics ram] && [dict get $metrics ram] ne ""} {
                    log "  RAM: [format "%.1f" [dict get $metrics ram]]%"
                } else {
                    log "  RAM: N/A"
                }
                if {[dict exists $metrics disk] && [dict get $metrics disk] ne ""} {
                    log "  Disk: [dict get $metrics disk]%"
                } else {
                    log "  Disk: N/A"
                }
                if {[dict exists $metrics load] && [dict get $metrics load] ne ""} {
                    log "  Load: [dict get $metrics load]"
                } else {
                    log "  Load: N/A"
                }
            } else {
                log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            set alerts [check_alerts $node_id $node_config $metrics]
            foreach alert $alerts {
                lappend all_alerts $alert
            }
        }
    }
    
    # Alerts senden
    if {$alert && [llength $all_alerts] > 0} {
        log "\nSending [llength $all_alerts] alerts..."
        foreach alert $all_alerts {
            send_alert $alert
        }
    } elseif {[llength $all_alerts] > 0} {
        log "\n[llength $all_alerts] alerts found (use --alert to send)"
    } else {
        log "\nAll nodes healthy!"
    }
}

# Skript starten
if {[info script] eq $argv0} {
    main
}
