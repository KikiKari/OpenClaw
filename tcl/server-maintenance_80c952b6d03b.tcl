#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "2f5a56b9898a46ed86e974dd1e8fba4c90945026348615bbc696d75d2bf1a163", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "tcl"}
# server-maintenance.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
# auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Server Maintenance Script
# RAM: 8GB, Uhr: Europe/Berlin

set LOG_FILE "/var/log/server-maintenance.log"
set DATE [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
set HOST [exec hostname]

# Farben für Terminal
set RED "\033\[0;31m"
set GREEN "\033\[0;32m"
set YELLOW "\033\[1;33m"
set NC "\033\[0m"

proc log_message {message} {
    global LOG_FILE DATE
    set msg "\[$DATE\] $message"
    puts $msg
    set fh [open $LOG_FILE a]
    puts $fh $msg
    close $fh
}

log_message "=== Server Maintenance Check ==="

# 1. APT Update Check
log_message "Checking for updates..."
set apt_update [exec apt update -qq 2>@1]
set lines [split $apt_update "\n"]
set last_lines [lrange $lines end-4 end]
foreach line $last_lines {
    if {$line ne ""} {
        log_message $line
    }
}
if {[catch {exec apt list --upgradable 2>@/dev/null} apt_list]} {
    set UPDATES 0
} else {
    set apt_lines [split $apt_list "\n"]
    set UPDATES [llength $apt_lines]
}
if {$UPDATES > 1} {
    log_message "⚠️ $UPDATES packages can be upgraded"
}

# 2. RAM Check (8GB total)
log_message "Checking RAM usage..."
set RAM_TOTAL 8192  ;# 8GB in MB
set free_output [exec free -m]
set mem_line ""
foreach line [split $free_output "\n"] {
    if {[string match "Mem:*" $line]} {
        set mem_line $line
        break
    }
}
if {$mem_line ne ""} {
    set mem_fields [regexp -all -inline {\S+} $mem_line]
    set RAM_USED [lindex $mem_fields 2]
    set RAM_PERCENT [expr {$RAM_USED * 100 / $RAM_TOTAL}]
    log_message "RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)"
    if {$RAM_PERCENT > 90} {
        log_message "🔴 WARNING: RAM usage > 90%!"
    } elseif {$RAM_PERCENT > 80} {
        log_message "🟡 WARNING: RAM usage > 80%"
    }
}

# 3. Disk Space Check
log_message "Checking disk space..."
set df_output [exec df -h /]
set df_lines [split $df_output "\n"]
set disk_line [lindex $df_lines end]
set disk_fields [regexp -all -inline {\S+} $disk_line]
set used [lindex $disk_fields 2]
set total [lindex $disk_fields 1]
set percent [lindex $disk_fields 4]
log_message "Disk: $used / $total ($percent used)"
set DISK_PERCENT [string trim $percent "%"]
if {$DISK_PERCENT > 90} {
    log_message "🔴 WARNING: Disk > 90%!"
} elseif {$DISK_PERCENT > 80} {
    log_message "🟡 WARNING: Disk > 80%"
}

# 4. NTP Check
log_message "Checking NTP sync..."
if {[catch {exec timedatectl status} timedatectl_output]} {
    log_message "⚠️ Could not check NTP status"
} else {
    if {[string first "NTP synchronized: yes" $timedatectl_output] != -1} {
        log_message "✅ NTP synchronized"
    } else {
        log_message "⚠️ NTP not synchronized"
    }
}

# 5. OpenClaw Gateway Status
log_message "Checking OpenClaw Gateway..."
if {[catch {exec systemctl is-active openclaw-gateway} result]} {
    set active_status ""
} else {
    set active_status $result
}
if {$active_status eq "active"} {
    log_message "✅ OpenClaw Gateway running"
} else {
    log_message "🔴 OpenClaw Gateway NOT running!"
    if {[catch {exec systemctl restart openclaw-gateway}]} {
        log_message "Failed to restart OpenClaw Gateway"
    }
}

# 6. Load Average
set uptime_output [exec uptime]
set load_avg ""
if {[regexp {load average: ([0-9.]+)} $uptime_output match load_val]} {
    set LOAD $load_val
} else {
    set LOAD "unknown"
}
log_message "Load Average: $LOAD"

log_message "=== Maintenance Complete ==="
log_message ""
