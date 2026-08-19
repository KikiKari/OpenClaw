#!/usr/bin/env tclsh8.6
# node_health.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

#
# Node Health Monitor - Multi-Node Gesundheitsüberwachung
#

package require json
package require fileutil

# Konfiguration
set WORKSPACE "/home/openclaw/.openclaw/workspace"
set HEALTH_DB "$WORKSPACE/db/health.db"
set LOG_FILE "$WORKSPACE/logs/node-health.log"

# Node-Definitionen
array set NODES {
    node1 {name "Gateway" host "localhost" user "openclaw" critical true}
    node2 {name "Worker" host "100.92.155.34" user "root" ssh_key "~/.ssh/id_rsa"}
    node3 {name "Relay" host "185.242.xxx.xxx" user "root" disk_warning 85}
    node5 {name "Redmi" host "192.168.1.x" user "openclaw" optional true}
}

proc log {message {level "INFO"}} {
    # Logging
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    
    set log_dir [file dirname $::LOG_FILE]
    file mkdir $log_dir
    set f [open $::LOG_FILE a]
    puts $f $entry
    close $f
}

proc check_ping {host {timeout 5}} {
    # Prüft Erreichbarkeit
    if {[catch {exec ping -c 1 -W $timeout $host}]} {
        return false
    } else {
        return true
    }
}

proc check_ssh {node_config} {
    # Prüft SSH-Verbindung
    set host [dict get $node_config host]
    set user [expr {[dict exists $node_config user] ? [dict get $node_config user] : "root"}]
    
    set cmd [list ssh -o ConnectTimeout=10 -o BatchMode=yes ${user}@${host} echo "OK"]
    
    if {[catch {exec {*}$cmd} result]} {
        return false
    } else {
        return [string match "*OK*" $result]
    }
}

proc get_node_metrics {node_config} {
    # Holt Metriken via SSH
    set host [dict get $node_config host]
    set user [expr {[dict exists $node_config user] ? [dict get $node_config user] : "root"}]
    
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
        echo \"CPU:\$(top -bn1 | grep \\\"Cpu(s)\\\" | awk \\\"{print \\\$2}\\\" | cut -d\\\"%\\\" -f1)\"
        
        # RAM
        echo \"RAM:\$(free | grep Mem | awk \\\"{print (\\\$3/\\\$2) * 100.0}\\\")\"
        
        # Disk
        echo \"DISK:\$(df -h / | tail -1 | awk \\\"{print \\\$5}\\\" | tr -d \\\"%\\\")\"
        
        # Load
        echo \"LOAD:\$(uptime | awk -F\\\"load average:\\\" \\\"{print \\\$2}\\\" | awk \\\"{print \\\$1}\\\" | tr -d \\\",\\\")\"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"
        fi
    '"
    
    if {[catch {exec /bin/sh -c $cmd} result]} {
        log "Error checking [dict get $node_config name]: $result" ERROR
        return [array get metrics]
    }
    
    set metrics(available) true
    
    foreach line [split $result \n] {
        if {[regexp {^([^:]+):(.*)$} $line -> key value]} {
            switch $key {
                CPU {
                    if {$value ne "" && [string is double $value]} {
                        set metrics(cpu) [expr {double($value)}]
                    }
                }
                RAM {
                    if {$value ne "" && [string is double $value]} {
                        set metrics(ram) [expr {double($value)}]
                    }
                }
                DISK {
                    if {$value ne "" && [string is integer $value]} {
                        set metrics(disk) [expr {int($value)}]
                    }
                }
                LOAD {
                    if {$value ne "" && [string is double $value]} {
                        set metrics(load) [expr {double($value)}]
                    }
                }
                GATEWAY {
                    set metrics(gateway_status) $value
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
        if {![dict exists $node_config optional] || ![dict get $node_config optional]} {
            lappend alerts [dict create level CRITICAL message "Node [dict get $node_config name] nicht erreichbar!"]
        }
    } else {
        # CPU
        if {[dict exists $metrics cpu] && [dict get $metrics cpu] ne "" && [dict get $metrics cpu] > 90} {
            lappend alerts [dict create level WARNING message "Node [dict get $node_config name]: CPU bei [format %.1f [dict get $metrics cpu]]%"]
        }
        
        # RAM
        if {[dict exists $metrics ram] && [dict get $metrics ram] ne "" && [dict get $metrics ram] > 90} {
            lappend alerts [dict create level WARNING message "Node [dict get $node_config name]: RAM bei [format %.1f [dict get $metrics ram]]%"]
        }
        
        # Disk
        set disk_threshold [expr {[dict exists $node_config disk_warning] ? [dict get $node_config disk_warning] : 85}]
        if {[dict exists $metrics disk] && [dict get $metrics disk] ne "" && [dict get $metrics disk] > $disk_threshold} {
            set level [expr {[dict get $metrics disk] > 95 ? "CRITICAL" : "WARNING"}]
            lappend alerts [dict create level $level message "Node [dict get $node_config name]: Disk bei [dict get $metrics disk]%"]
        }
        
        # Gateway
        if {[dict exists $node_config critical] && [dict get $node_config critical] && 
            [dict exists $metrics gateway_status] && [dict get $metrics gateway_status] eq "inactive"} {
            lappend alerts [dict create level CRITICAL message "Node [dict get $node_config name]: OpenClaw Gateway nicht aktiv!"]
        }
    }
    
    return $alerts
}

proc send_alert {alert} {
    # Sendet Alert via channel-status-agent
    if {[catch {
        set cmd [list python3 "$::WORKSPACE/skills/channel-status-agent/scripts/channel_status.py" \
                 --type alert \
                 --message "[dict get $alert level]: [dict get $alert message]"]
        exec {*}$cmd
        log "Alert sent: [dict get $alert message]"
    } result]} {
        log "Failed to send alert: $result" ERROR
    }
}

proc main {} {
    # Hauptfunktion
    global argv
    array set args {
        node all
        check all
        alert false
    }
    
    # Argumente parsen
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            --node {
                incr i
                set args(node) [lindex $argv $i]
            }
            --check {
                incr i
                set args(check) [lindex $argv $i]
            }
            --alert {
                set args(alert) true
            }
        }
    }
    
    # Nodes bestimmen
    if {$args(node) eq "all"} {
        set nodes_to_check [array get ::NODES]
    } else {
        if {[info exists ::NODES($args(node))]} {
            set nodes_to_check [list $args(node) $::NODES($args(node))]
        } else {
            log "Unknown node: $args(node)" ERROR
            exit 1
        }
    }
    
    # Health-Checks durchführen
    set all_alerts {}
    
    foreach {node_id node_config} $nodes_to_check {
        log "Checking [dict get $node_config name] ($node_id)"
        
        # Ping
        if {$args(check) in {ping all}} {
            if {[dict get $node_config host] ne "localhost"} {
                set ping_ok [check_ping [dict get $node_config host]]
                log "  Ping: [expr {$ping_ok ? "OK" : "FAILED"}]"
            }
        }
        
        # SSH
        if {$args(check) in {ssh all}} {
            set ssh_ok [check_ssh $node_config]
            log "  SSH: [expr {$ssh_ok ? "OK" : "FAILED"}]"
        }
        
        # Metriken
        if {$args(check) in {metrics all}} {
            set metrics [get_node_metrics $node_config]
            
            if {[dict get $metrics available]} {
                log "  CPU: [expr {[dict exists $metrics cpu] && [dict get $metrics cpu] ne "" ? [format %.1f [dict get $metrics cpu]]% : "N/A"}]"
                log "  RAM: [expr {[dict exists $metrics ram] && [dict get $metrics ram] ne "" ? [format %.1f [dict get $metrics ram]]% : "N/A"}]"
                log "  Disk: [expr {[dict exists $metrics disk] && [dict get $metrics disk] ne "" ? [dict get $metrics disk]% : "N/A"}]"
                log "  Load: [expr {[dict exists $metrics load] && [dict get $metrics load] ne "" ? [dict get $metrics load] : "N/A"}]"
            } else {
                log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            set alerts [check_alerts $node_id $node_config $metrics]
            set all_alerts [concat $all_alerts $alerts]
        }
    }
    
    # Alerts senden
    if {$args(alert) && [llength $all_alerts] > 0} {
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

if {[info script] eq $argv0} {
    main
}
