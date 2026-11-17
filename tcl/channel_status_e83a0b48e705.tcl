#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "dd7c29161f0bbd33e7039ab93fc69aff90170ed9f000a5c64a23ec514ed508f3", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "tcl"}
# channel_status.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
# auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

#
# Channel Status Agent - Automatische Status-Updates
#

package require json
package require sqlite3

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
    set f [open $::LOG_FILE a]
    puts $f $entry
    close $f
}

proc get_system_status {} {
    # Sammelt System-Status
    array set status [list \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
        nodes [dict create] \
        agents [dict create] \
        system [dict create] \
    ]
    
    # Node-Status (vereinfacht)
    dict set status(nodes) node1 [dict create name "Gateway" status "online"]
    dict set status(nodes) node2 [dict create name "Worker" status "online"]
    dict set status(nodes) node3 [dict create name "Relay" status "offline" reason "disk full"]
    dict set status(nodes) node5 [dict create name "Redmi" status "intermittent"]
    dict set status(nodes) node7 [dict create name "Docker" status "planned"]
    
    # Agent-Status aus Cron
    if {[catch {exec crontab -l} result]} {
        dict set status(agents) active_crons "unknown"
    } else {
        set lines [split $result "\n"]
        set count 0
        foreach line $lines {
            if {![string match "#*" $line] && [string length [string trim $line]] > 0} {
                incr count
            }
        }
        dict set status(agents) active_crons $count
    }
    
    # System-Metriken
    if {![catch {exec df -h "/"} df_result]} {
        set lines [split $df_result "\n"]
        foreach line $lines {
            if {[string match "*/*" $line] && [string match "*%*" $line]} {
                set parts [split [string trim $line] " "]
                dict set status(system) disk_used [lindex $parts end-1]
                break
            }
        }
    }
    
    if {![catch {exec free -h} free_result]} {
        set lines [split $free_result "\n"]
        foreach line $lines {
            if {[string match "Mem:*" $line]} {
                set parts [split [string trim $line] " "]
                dict set status(system) ram_total [lindex $parts 1]
                dict set status(system) ram_used [lindex $parts 2]
                break
            }
        }
    }
    
    return [array get status]
}

proc format_daily_status {status_dict} {
    # Formatiert täglichen Status
    array set status $status_dict
    set nodes $status(nodes)
    
    set online 0
    dict for {key value} $nodes {
        if {[dict get $value status] eq "online"} {
            incr online
        }
    }
    
    set message "📊 **Täglicher Status-Report**\n"
    append message "🗓️ [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]\n\n"
    append message "**🖥️ Nodes ($online/5 online):**\n"
    
    dict for {node_id info} $nodes {
        set status_val [dict get $info status]
        if {$status_val eq "online"} {
            set emoji "🟢"
        } elseif {$status_val eq "offline"} {
            set emoji "🔴"
        } else {
            set emoji "🟡"
        }
        append message "$emoji [dict get $info name]: $status_val"
        if {[dict exists $info reason]} {
            append message " ([dict get $info reason])"
        }
        append message "\n"
    }
    
    append message "\n**🤖 Agents:**\n"
    append message "Aktive Cron-Jobs: [dict get $status(agents) active_crons]\n"
    
    if {[dict exists $status(system) disk_used]} {
        append message "\n**💾 System:**\n"
        append message "Disk: [dict get $status(system) disk_used] belegt\n"
        append message "RAM: [dict get $status(system) ram_used] / [dict get $status(system) ram_total]\n"
    }
    
    return $message
}

proc format_weekly_status {status_dict} {
    # Formatiert wöchentlichen Status
    set message "📈 **Wöchentlicher Report**\n"
    append message "📅 Woche [clock format [clock seconds] -format "%V"] - [clock format [clock seconds] -format "%Y"]\n\n"
    append message "**Zusammenfassung:**\n"
    append message "- 5 aktive Sub-Agents\n"
    append message "- 11 Skills synchronisiert\n"
    append message "- 3 neue Features implementiert\n\n"
    append message "**Top-Ereignisse:**\n"
    append message "1. ClawHub-Git Sync implementiert ✅\n"
    append message "2. Node 3 Disk voll (95%) ⚠️\n"
    append message "3. Channel-Status-Agent aktiviert 🆕\n\n"
    append message "**Geplante Wartungen:**\n"
    append message "- Node 3: Disk-Cleanup erforderlich\n"
    append message "- Node 7: Docker-Setup ausstehend\n"
    
    return $message
}

proc send_to_channel {message {channel_type "telegram"} {channel_id "-1002381931352"}} {
    # Sendet Nachricht an Channel
    if {$channel_type eq "telegram"} {
        # Nutze OpenClaw message tool
        set cmd [list openclaw message send --target $channel_id --message $message]
    } else {
        log "Channel type $channel_type not implemented" "WARN"
        return 0
    }
    
    if {[catch {exec {*}$cmd} result]} {
        log "Send error: $result" "ERROR"
        return 0
    } else {
        log "Message sent to $channel_type $channel_id"
        return 1
    }
}

proc main {} {
    # Hauptfunktion
    package require cmdline
    
    set options {
        {type.arg "" "Type of status update (daily, weekly, alert)"}
        {message.arg "" "Alert message"}
        {channel.arg "-1002381931352" "Channel ID"}
        {dry-run "Dry run mode"}
    }
    
    set usage "Usage: channel_status.tcl --type <daily|weekly|alert> \[options...\]"
    
    if {[catch {cmdline::getoptions argv $options $usage} result]} {
        puts stderr $result
        exit 1
    }
    
    set type ""
    set message ""
    set channel "-1002381931352"
    set dry_run 0
    
    foreach {key value} $result {
        switch $key {
            type { set type $value }
            message { set message $value }
            channel { set channel $value }
            dry-run { set dry_run 1 }
        }
    }
    
    if {$type eq ""} {
        puts stderr "Error: --type is required"
        puts stderr $usage
        exit 1
    }
    
    log "Starting $type status update"
    
    # Status sammeln
    set status [get_system_status]
    
    # Message formatieren
    if {$type eq "daily"} {
        set message [format_daily_status $status]
    } elseif {$type eq "weekly"} {
        set message [format_weekly_status $status]
    } elseif {$type eq "alert"} {
        if {$message eq ""} {
            set message "🚨 **ALERT**\nManual alert"
        } else {
            set message "🚨 **ALERT**\n$message"
        }
    }
    
    # Senden oder Dry-Run
    if {$dry_run} {
        puts "\n--- DRY RUN ---"
        puts $message
        puts "--- END ---"
    } else {
        send_to_channel $message "telegram" $channel
    }
    
    log "Status update completed"
}

# Create log directory if needed
file mkdir [file dirname $LOG_FILE]

# Run main function
if {[info script] eq $argv0} {
    main
}
