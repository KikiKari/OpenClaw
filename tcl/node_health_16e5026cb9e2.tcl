#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "d6df93af3ce0dd8b99d79a18dd5f2cd26c01e3af9693efa89140d3e39c50db2c", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "tcl"}
# node_health.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Node Health Monitor - Multi-Node Gesundheitsüberwachung

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
    
    global LOG_FILE
    set log_dir [file dirname $LOG_FILE]
    if {![file exists $log_dir]} {
        file mkdir $log_dir
    }
    
    if {[catch {open $LOG_FILE a} fd]} {
        puts "Failed to open log file: $fd"
        return
    }
    puts $fd $entry
    close $fd
}

proc check_ping {host {timeout 5}} {
    # Prüft Erreichbarkeit
    if {[catch {exec ping -c 1 -W $timeout $host} result]} {
        return 0
    } else {
        return 1
    }
}

proc check_ssh {node_config} {
    # Prüft SSH-Verbindung
    array set config $node_config
    set host $config(host)
    set user [expr {[info exists config(user)] ? $config(user) : "root"}]
    
    set cmd [list ssh -o ConnectTimeout=10 -o BatchMode=yes "$user@$host" echo "OK"]
    
    if {[catch {exec {*}$cmd} result]} {
        return 0
    } else {
        return [expr {[string match "*OK*" $result] ? 1 : 0}]
    }
}

proc get_node_metrics {node_config} {
    # Holt Metriken via SSH
    array set config $node_config
    set host $config(host)
    set user [expr {[info exists config(user)] ? $config(user) : "root"}]
    
    array set metrics {
        timestamp ""
        available false
        cpu ""
        ram ""
        disk ""
        load ""
    }
    set metrics(timestamp) [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    
    # SSH-Command für alle Metriken
    set cmd "ssh -o ConnectTimeout=10 $user@$host '
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
    }
    
    set metrics(available) true
    
    foreach line [split $result "\n"] {
        if {[string first ":" $line] != -1} {
            lassign [split $line ":"] key value
            switch $key {
                "CPU" {
                    if {$value ne ""} {
                        set metrics(cpu) [expr {double($value)}]
                    }
                }
                "RAM" {
                    if {$value ne ""} {
                        set metrics(ram) [expr {double($value)}]
                    }
                }
                "DISK" {
                    if {$value ne ""} {
                        set metrics(disk) [expr {int($value)}]
                    }
                }
                "LOAD" {
                    if {$value ne ""} {
                        set metrics(load) [expr {double($value)}]
                    }
                }
                "GATEWAY" {
                    set metrics(gateway_status) $value
                }
            }
        }
    }
    
    return [array get metrics]
}

proc check_alerts {node_id node_config metrics} {
    # Prüft Schwellwerte und generiert Alerts
    array set config $node_config
    array set metric_data $metrics
    
    set alerts {}
    
    # Verfügbarkeit
    if {!$metric_data(available)} {
        set optional [expr {[info exists config(optional)] ? $config(optional) : false}]
        if {!$optional} {
            lappend alerts [list level "CRITICAL" message "Node $config(name) nicht erreichbar!"]
        }
    } else {
        # CPU
        if {$metric_data(cpu) ne "" && $metric_data(cpu) > 90} {
            lappend alerts [list level "WARNING" message "Node $config(name): CPU bei $metric_data(cpu)%"]
        }
        
        # RAM
        if {$metric_data(ram) ne "" && $metric_data(ram) > 90} {
            lappend alerts [list level "WARNING" message "Node $config(name): RAM bei $metric_data(ram)%"]
        }
        
        # Disk
        set disk_warning [expr {[info exists config(disk_warning)] ? $config(disk_warning) : 85}]
        if {$metric_data(disk) ne "" && $metric_data(disk) > $disk_warning} {
            set level [expr {$metric_data(disk) > 95 ? "CRITICAL" : "WARNING"}]
            lappend alerts [list level $level message "Node $config(name): Disk bei $metric_data(disk)%"]
        }
        
        # Gateway
        set critical [expr {[info exists config(critical)] ? $config(critical) : false}]
        if {$critical && [info exists metric_data(gateway_status)] && $metric_data(gateway_status) eq "inactive"} {
            lappend alerts [list level "CRITICAL" message "Node $config(name): OpenClaw Gateway nicht aktiv!"]
        }
    }
    
    return $alerts
}

proc send_alert {alert} {
    # Sendet Alert via channel-status-agent
    global WORKSPACE
    array set alert_data $alert
    
    set cmd [list python3 "$WORKSPACE/skills/channel-status-agent/scripts/channel_status.py" \
             --type alert \
             --message "$alert_data(level): $alert_data(message)"]
    
    if {[catch {exec {*}$cmd} result]} {
        log "Failed to send alert: $result" "ERROR"
    } else {
        log "Alert sent: $alert_data(message)"
    }
}

proc main {} {
    global argv NODES WORKSPACE
    
    # Default-Werte für Argumente
    set node "all"
    set check "all"
    set alert 0
    
    # Argumente parsen (vereinfachte Version)
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        switch $arg {
            "--node" {
                set node [lindex $argv $i]
                incr i
            }
            "--check" {
                set check [lindex $argv $i]
                incr i
            }
            "--alert" {
                set alert 1
            }
        }
    }
    
    # Nodes bestimmen
    if {$node eq "all"} {
        set nodes_to_check [array get NODES]
    } else {
        if {[info exists NODES($node)]} {
            set nodes_to_check [list $node $NODES($node)]
        } else {
            log "Unknown node: $node" "ERROR"
            exit 1
        }
    }
    
    # Health-Checks durchführen
    set all_alerts {}
    
    foreach {node_id node_config} $nodes_to_check {
        array set config $node_config
        log "Checking $config(name) ($node_id)"
        
        # Ping
        if {$check in {ping all}} {
            if {$config(host) ne "localhost"} {
                set ping_ok [check_ping $config(host)]
                log "  Ping: [expr {$ping_ok ? "OK" : "FAILED"}]"
            }
        }
        
        # SSH
        if {$check in {ssh all}} {
            set ssh_ok [check_ssh $node_config]
            log "  SSH: [expr {$ssh_ok ? "OK" : "FAILED"}]"
        }
        
        # Metriken
        if {$check in {metrics all}} {
            set metrics [get_node_metrics $node_config]
            array set metric_data $metrics
            
            if {$metric_data(available)} {
                log [format "  CPU: %.1f%%" [expr {$metric_data(cpu) ne "" ? $metric_data(cpu) : "N/A"}]]
                log [format "  RAM: %.1f%%" [expr {$metric_data(ram) ne "" ? $metric_data(ram) : "N/A"}]]
                log [format "  Disk: %s%%" [expr {$metric_data(disk) ne "" ? $metric_data(disk) : "N/A"}]]
                log [format "  Load: %s" [expr {$metric_data(load) ne "" ? $metric_data(load) : "N/A"}]]
            } else {
                log "  Metrics: UNAVAILABLE"
            }
            
            # Alerts prüfen
            set alerts [check_alerts $node_id $node_config $metrics]
            set all_alerts [concat $all_alerts $alerts]
        }
    }
    
    # Alerts senden
    if {$alert && [llength $all_alerts] > 0} {
        log "\nSending [llength $all_alerts] alerts..."
        foreach alert_item $all_alerts {
            send_alert $alert_item
        }
    } elseif {[llength $all_alerts] > 0} {
        log "\n[llength $all_alerts] alerts found (use --alert to send)"
    } else {
        log "\nAll nodes healthy!"
    }
}

# Hauptprogramm starten
if {[info script] eq $argv0} {
    main
}
