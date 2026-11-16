#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "5d5c1352e6248821c2076cec374da02c9c38d734d9354b0720487a4e63c53b71", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "tcl"}
# channel_status.py — portiert nach tcl
# Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Channel Status Agent - Automatische Status-Updates

package require json
package require cmdline

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

array set NODE_NAMES {
    node2 {openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122}
    node3 {openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125}
    node4 {openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39}
    node5 {openclaw-node5 lenovo-node7 lenovo-node7.taild25fea.ts.net 100.103.140.35}
}

proc fetch_node_status {} {
    # Return mapped OpenClaw connection states; None indicates lookup failure.
    if {[catch {exec openclaw nodes status --json} result]} {
        return ""
    }
    
    if {[catch {::json::json2dict $result} payload]} {
        return ""
    }
    
    if {![dict exists $payload nodes]} {
        return ""
    }
    
    set nodes [dict get $payload nodes]
    if {![llength $nodes]} {
        return ""
    }
    
    array set states {}
    foreach node [array names ::NODE_NAMES] {
        set states($node) false
    }
    
    foreach item $nodes {
        if {![dict size $item]} {
            continue
        }
        
        set names {}
        foreach key {displayName nodeId remoteIp} {
            if {[dict exists $item $key]} {
                lappend names [string tolower [dict get $item $key]]
            } else {
                lappend names ""
            }
        }
        
        foreach node [array names ::NODE_NAMES] {
            set aliases $::NODE_NAMES($node)
            foreach name $names {
                if {$name in $aliases && [dict exists $item connected] && [dict get $item connected]} {
                    set states($node) true
                }
            }
        }
    }
    
    set states(node1) true
    return [array get states]
}

proc get_system_status {} {
    # Sammelt System-Status
    set status [dict create]
    dict set status timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    dict set status nodes [dict create]
    dict set status agents [dict create]
    dict set status system [dict create]
    
    # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    set state_array [fetch_node_status]
    if {$state_array eq ""} {
        set states ""
    } else {
        array set states $state_array
    }
    
    array set names {
        node1 Gateway
        node2 Node2
        node3 Node3
        node4 Redmi
        node5 Lenovo
    }
    
    set nodes_dict [dict create]
    foreach {node name} [array get names] {
        set node_status unknown
        if {$state_array ne ""} {
            if {[info exists states($node)] && $states($node)} {
                set node_status online
            } else {
                set node_status offline
            }
        }
        dict set nodes_dict $node [dict create name $name status $node_status]
    }
    dict set status nodes $nodes_dict
    
    # Agent-Status aus Cron
    if {[catch {exec crontab -l} result]} {
        dict set status agents active_crons unknown
    } else {
        set lines [split $result \n]
        set count 0
        foreach line $lines {
            if {![string match "#*" $line] && $line ne ""} {
                incr count
            }
        }
        dict set status agents active_crons $count
    }
    
    # System-Metriken
    if {![catch {exec df -h /} df_result]} {
        set lines [split $df_result \n]
        foreach line $lines {
            if {[string match "*/*" $line] && [string match "*%*" $line]} {
                set parts [split $line]
                if {[llength $parts] >= 5} {
                    set disk_used [lindex $parts 4]
                    dict set status system disk_used $disk_used
                }
                break
            }
        }
    }
    
    if {![catch {exec free -h} free_result]} {
        set lines [split $free_result \n]
        foreach line $lines {
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
            "online" {
                set emoji "🟢"
            }
            "offline" {
                set emoji "🔴"
            }
            default {
                set emoji "🟡"
            }
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
    set nodes [dict get $status nodes]
    dict for {node_id info} $nodes {
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
        log "Channel type $channel_type not implemented" WARN
        return false
    }
    
    if {[catch {exec {*}$cmd} result]} {
        log "Send error: $result" ERROR
        return false
    } else {
        log "Message sent to $channel_type $channel_id"
        return true
    }
}

proc main {} {
    # Hauptfunktion
    set options {
        {type.arg "" "Type of status update (daily, weekly, alert)"}
        {message.arg "" "Alert message"}
        {channel.arg "-1002381931352" "Channel ID"}
        {dry-run "Dry run mode"}
    }
    
    set usage ": $::argv0 \[--type daily|weekly|alert\] \[options...\]"
    if {[catch {cmdline::typedGetoptions ::argv $options $usage} optlist]} {
        puts stderr "$optlist"
        exit 1
    }
    
    array set opts $optlist
    
    if {$opts(type) eq ""} {
        puts stderr "Error: --type is required"
        exit 1
    }
    
    log "Starting $opts(type) status update"
    
    # Status sammeln
    set status [get_system_status]
    
    # Message formatieren
    switch $opts(type) {
        daily {
            set message [format_daily_status $status]
        }
        weekly {
            set message [format_weekly_status $status]
        }
        alert {
            set msg_content "Manual alert"
            if {$opts(message) ne ""} {
                set msg_content $opts(message)
            }
            set message "🚨 **ALERT**\n$msg_content"
        }
        default {
            puts stderr "Unknown type: $opts(type)"
            exit 1
        }
    }
    
    # Senden oder Dry-Run
    if {$opts(dry-run)} {
        puts "\n--- DRY RUN ---"
        puts $message
        puts "--- END ---"
    } else {
        send_to_channel $message telegram $opts(channel)
    }
    
    log "Status update completed"
}

# Create log directory if it doesn't exist
set log_dir [file dirname $LOG_FILE]
if {![file exists $log_dir]} {
    file mkdir $log_dir
}

if {[info script] eq $::argv0} {
    main
}
