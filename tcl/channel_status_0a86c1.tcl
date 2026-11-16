#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "40cf0245a69f762935faa800803f7e600c0e2b383ed4d1e35638836b496ea30c", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "tcl"}
# channel_status.py — portiert nach tcl
# Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Channel Status Agent - Automatische Status-Updates

package require json
package require fileutil

# Konfiguration
set WORKSPACE "/home/openclaw/.openclaw/workspace"
set LOGS_DB "$WORKSPACE/db/logs.db"
set CONFIG_FILE "$WORKSPACE/config/channel-status.json"
set LOG_FILE "$WORKSPACE/logs/channel-status.log"

proc log {message {level "INFO"}} {
    # Logging
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    set fh [open $::LOG_FILE a]
    puts $fh $entry
    close $fh
}

array set NODE_NAMES {
    node2 {openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122}
    node3 {openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125}
    node4 {openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39}
    node5 {openclaw-node5}
    node6 {openclaw-node6}
}

proc fetch_node_status {} {
    # Return mapped OpenClaw connection states; None indicates lookup failure.
    if {[catch {exec openclaw nodes status --json} result]} {
        return ""
    }
    
    if {[catch {::json::json2dict $result} payload]} {
        return ""
    }
    
    if {![dict exists $payload nodes] || ![llength [dict get $payload nodes]]} {
        return ""
    }
    
    array set states {}
    foreach node [array names ::NODE_NAMES] {
        set states($node) false
    }
    
    foreach item [dict get $payload nodes] {
        if {![dict size $item]} continue
        
        set names {}
        foreach key {displayName nodeId remoteIp} {
            if {[dict exists $item $key]} {
                lappend names [string tolower [dict get $item $key]]
            } else {
                lappend names ""
            }
        }
        
        foreach node [array names ::NODE_NAMES] {
            set found 0
            foreach alias $::NODE_NAMES($node) {
                if {$alias in $names} {
                    set found 1
                    break
                }
            }
            if {$found && [dict exists $item connected] && [dict get $item connected]} {
                set states($node) true
            }
        }
    }
    
    set states(node1) true ;# successful Gateway status request
    
    set result_dict {}
    foreach node [array names states] {
        dict set result_dict $node $states($node)
    }
    return $result_dict
}

proc get_system_status {} {
    # Sammelt System-Status
    set status [dict create \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
        nodes [dict create] \
        agents [dict create] \
        system [dict create] \
    ]
    
    # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    set states [fetch_node_status]
    array set names {
        node1 "Gateway"
        node2 "Node2"
        node3 "Node3"
        node4 "Redmi"
        node5 "Lenovo"
        node6 "Lenovo (Docker)"
    }
    
    set nodes_dict {}
    foreach node [array names names] {
        set node_status "unknown"
        if {$states ne "" && [dict exists $states $node]} {
            set node_status [expr {[dict get $states $node] ? "online" : "offline"}]
        } elseif {$states eq ""} {
            set node_status "unknown"
        } else {
            set node_status "offline"
        }
        dict set nodes_dict $node [dict create name $names($node) status $node_status]
    }
    dict set status nodes $nodes_dict
    
    # Agent-Status aus Cron
    if {[catch {exec crontab -l} result]} {
        dict set status agents active_crons "unknown"
    } else {
        set count 0
        foreach line [split $result \n] {
            if {![string match "#*" $line] && $line ne ""} {
                incr count
            }
        }
        dict set status agents active_crons $count
    }
    
    # System-Metriken
    if {![catch {exec df -h /} df_result]} {
        foreach line [split $df_result \n] {
            if {[string match "*%*" $line] && [string match "*/ *" $line]} {
                set parts [split $line]
                if {[llength $parts] >= 5} {
                    dict set status system disk_used [lindex $parts 4]
                }
                break
            }
        }
    }
    
    if {![catch {exec free -h} free_result]} {
        foreach line [split $free_result \n] {
            if {[string match "*Mem:*" $line]} {
                set parts [split $line]
                if {[llength $parts] >= 3} {
                    dict set status system ram_total [lindex $parts 1]
                    dict set status system ram_used [lindex $parts 2]
                }
                break
            }
        }
    }
    
    return $status
}

proc format_daily_status {status} {
    # Formatiert täglichen Status
    set nodes [dict get $status nodes]
    set online_count 0
    dict for {node_id info} $nodes {
        if {[dict get $info status] eq "online"} {
            incr online_count
        }
    }
    
    set message "📊 **Täglicher Status-Report**\n"
    append message "🗓️ [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]\n\n"
    append message "**🖥️ Nodes ($online_count/[dict size $nodes] online):**\n"
    
    dict for {node_id info} $nodes {
        set status_val [dict get $info status]
        switch $status_val {
            "online" { set emoji "🟢" }
            "offline" { set emoji "🔴" }
            default { set emoji "🟡" }
        }
        append message "$emoji [dict get $info name]: $status_val"
        if {[dict exists $info reason]} {
            append message " ([dict get $info reason])"
        }
        append message "\n"
    }
    
    append message "\n**🤖 Agents:**\n"
    append message "Aktive Cron-Jobs: [dict get $status agents active_crons]\n"
    
    if {[dict exists $status system disk_used]} {
        append message "\n**💾 System:**\n"
        append message "Disk: [dict get $status system disk_used] belegt\n"
        append message "RAM: [dict get $status system ram_used] / [dict get $status system ram_total]\n"
    }
    
    return $message
}

proc format_weekly_status {status} {
    # Format the weekly report from current node data.
    set lines [list "📈 **Wöchentlicher Report*" "📅 Woche [clock format [clock seconds] -format "%V"] - [clock format [clock seconds] -format "%Y"]" "" "**Nodes:**"]
    
    dict for {node_id info} [dict get $status nodes] {
        lappend lines "- [dict get $info name]: [dict get $info status]"
    }
    
    return [join $lines \n]\n
}

proc send_to_channel {message {channel_type "telegram"} {channel_id "-1002381931352"}} {
    # Sendet Nachricht an Channel
    if {$channel_type eq "telegram"} {
        # Nutze OpenClaw message tool
        set cmd [list openclaw message send --target $channel_id --message $message]
    } else {
        log "Channel type $channel_type not implemented" "WARN"
        return false
    }
    
    if {[catch {exec {*}$cmd} result]} {
        log "Send error: $result" "ERROR"
        return false
    } else {
        log "Message sent to $channel_type $channel_id"
        return true
    }
}

proc main {} {
    # Hauptfunktion
    package require cmdline
    
    set options {
        {type.arg "" "Type of report (daily, weekly, alert)"}
        {message.arg "" "Alert message"}
        {channel.arg "-1002381931352" "Channel ID"}
        {dry-run "Dry run mode"}
    }
    
    set usage "Usage: channel_status.tcl --type <daily|weekly|alert> \[options\]"
    
    if {[catch {cmdline::typedGetoptions argv $options} optlist]} {
        puts stderr [cmdline::usage $options $usage]
        exit 1
    }
    
    set type [dict get $optlist type]
    if {$type eq ""} {
        puts stderr "Error: --type is required"
        puts stderr [cmdline::usage $options $usage]
        exit 1
    }
    
    if {$type ni {daily weekly alert}} {
        puts stderr "Error: --type must be one of daily, weekly, alert"
        puts stderr [cmdline::usage $options $usage]
        exit 1
    }
    
    set message_val [dict get $optlist message]
    set channel [dict get $optlist channel]
    set dry_run [dict get $optlist dry-run]
    
    log "Starting $type status update"
    
    # Status sammeln
    set status [get_system_status]
    
    # Message formatieren
    switch $type {
        daily {
            set message [format_daily_status $status]
        }
        weekly {
            set message [format_weekly_status $status]
        }
        alert {
            set msg_text "Manual alert"
            if {$message_val ne ""} {
                set msg_text $message_val
            }
            set message "🚨 **ALERT**\n$msg_text"
        }
    }
    
    # Senden oder Dry-Run
    if {$dry_run} {
        puts "\n--- DRY RUN ---"
        puts $message
        puts "--- END ---"
    } else {
        send_to_channel $message $channel
    }
    
    log "Status update completed"
}

# Create log directory if it doesn't exist
file mkdir [file dirname $LOG_FILE]

# Run main function
if {[info script] eq $argv0} {
    main
}
