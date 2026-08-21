#!/usr/bin/env tclsh8.6
# sync_agent_cron.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync

lappend auto_path /home/openclaw/.openclaw/workspace/scripts
package require fileutil
package require json

set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
set LOG_FILE "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"

proc file_mtime {path} {
    set files {}
    catch {
        foreach item [glob -nocomplain -dir $path -types r *] {
            if {[file isdirectory $item]} {
                lappend files {*}[file_mtime $item]
            } elseif {[file isfile $item] && ![string match "*.git*" $item]} {
                lappend files $item
            }
        }
    }
    set mtimes {}
    foreach f $files {
        if {[catch {file mtime $f} mtime]} {
            continue
        }
        lappend mtimes $mtime
    }
    if {[llength $mtimes] > 0} {
        return [tcl::mathfunc::max {*}$mtimes]
    } else {
        return 0
    }
}

proc write_to_log {message {level "INFO"}} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    set fh [open $::LOG_FILE a]
    puts $fh $entry
    close $fh
}

proc log {msg {level INFO}} {
    write_to_log $msg $level
}

proc validate_skill {path} {
    # Placeholder - implementieren Sie Ihre Validierungslogik hier
    return [file isdirectory $path]
}

proc sync_to_git {skill dry_run} {
    # Placeholder - implementieren Sie Ihre Sync-Logik hier
    return 1
}

proc sync_to_clawhub {skill dry_run} {
    # Placeholder - implementieren Sie Ihre Sync-Logik hier
    return 1
}

write_to_log [string repeat "=" 70]
write_to_log "CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF"
write_to_log "Zeitstempel: [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
write_to_log [string repeat "=" 70]

proc get_skill_dirs {dir} {
    set skills {}
    catch {
        foreach item [glob -nocomplain -dir $dir *] {
            if {[file isdirectory $item] && ![string match ".*" [file tail $item]]} {
                lappend skills [file tail $item]
            }
        }
    }
    return $skills
}

set clawhub_skills [get_skill_dirs $::CLAWHUB_DIR]
set git_skills [get_skill_dirs $::GIT_DIR]

write_to_log ""
write_to_log "\[DRY-RUN\] Analysiere Änderungen..."

array set changes_detected [list \
    "new_in_clawhub" {} \
    "new_in_git" {} \
    "clawhub_newer" {} \
    "git_newer" {} \
    "synced" {} \
]

# Neue Skills finden
set new_in_clawhub {}
foreach skill $clawhub_skills {
    if {$skill ni $git_skills} {
        lappend new_in_clawhub $skill
    }
}
set new_in_clawhub [lsort $new_in_clawhub]

set new_in_git {}
foreach skill $git_skills {
    if {$skill ni $clawhub_skills} {
        lappend new_in_git $skill
    }
}
set new_in_git [lsort $new_in_git]

set changes_detected(new_in_clawhub) $new_in_clawhub
set changes_detected(new_in_git) $new_in_git

# Existierende prüfen
set in_both {}
foreach skill $clawhub_skills {
    if {$skill in $git_skills} {
        lappend in_both $skill
    }
}
set in_both [lsort $in_both]

set clawhub_newer {}
set git_newer {}
set synced {}

foreach skill $in_both {
    set c_mtime [file_mtime [file join $::CLAWHUB_DIR $skill]]
    set g_mtime [file_mtime [file join $::GIT_DIR $skill]]
    set diff [expr {$c_mtime - $g_mtime}]
    
    if {abs($diff) > 60} {
        if {$diff > 0} {
            lappend clawhub_newer [list $skill $diff]
        } else {
            lappend git_newer [list $skill [expr {abs($diff)}]]
        }
    } else {
        lappend synced $skill
    }
}

set changes_detected(clawhub_newer) $clawhub_newer
set changes_detected(git_newer) $git_newer
set changes_detected(synced) $synced

set total_changes [expr {[llength $new_in_clawhub] + [llength $new_in_git] + [llength $clawhub_newer] + [llength $git_newer]}]
write_to_log "Neu in ClawHub: [llength $new_in_clawhub]"
write_to_log "Neu in Git: [llength $new_in_git]"
write_to_log "ClawHub neuer: [llength $clawhub_newer]"
write_to_log "Git neuer: [llength $git_newer]"
write_to_log "Synchron: [llength $synced]"

if {$total_changes == 0} {
    write_to_log ""
    write_to_log "✅ Keine Änderungen erkannt. Sync nicht nötig."
    write_to_log [string repeat "=" 70]
    exit 0
}

write_to_log ""
write_to_log "🔄 $total_changes Änderungen erkannt - starte Synchronisation..."

array set results [list \
    "synced_to_git" {} \
    "synced_to_clawhub" {} \
    "up_to_date" {} \
    "errors" {} \
]

# NEU in ClawHub → zu Git
foreach skill $new_in_clawhub {
    if {[catch {
        if {[validate_skill [file join $::CLAWHUB_DIR $skill]]} {
            write_to_log "→ Synchronisiere $skill zu Git..."
            if {[sync_to_git $skill 0]} {
                set git_path [file join $::GIT_DIR $skill]
                cd $git_path
                exec git init -q 2>/dev/null
                exec git add . -f 2>/dev/null
                set dt [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
                exec git commit -m "Initial: $skill" -q 2>/dev/null
                lappend results(synced_to_git) $skill
                write_to_log "  ✓ $skill synchronisiert"
            }
        } else {
            lappend results(errors) "$skill (invalid)"
        }
    } err]} {
        write_to_log "  ✗ ERROR: $skill - $err" "ERROR"
        lappend results(errors) "$skill"
    }
}

# NEU in Git → zu ClawHub
foreach skill $new_in_git {
    if {[catch {
        if {[validate_skill [file join $::GIT_DIR $skill]]} {
            write_to_log "→ Synchronisiere $skill zu ClawHub..."
            if {[sync_to_clawhub $skill 0]} {
                lappend results(synced_to_clawhub) $skill
                write_to_log "  ✓ $skill synchronisiert"
            }
        } else {
            lappend results(errors) "$skill (invalid)"
        }
    } err]} {
        write_to_log "  ✗ ERROR: $skill - $err" "ERROR"
        lappend results(errors) "$skill"
    }
}

# Updates von ClawHub nach Git
foreach item $clawhub_newer {
    lassign $item skill diff
    if {[catch {
        write_to_log "→ Update $skill (ClawHub +[format "%.0f" $diff]s neuer)..."
        if {[sync_to_git $skill 0]} {
            set git_path [file join $::GIT_DIR $skill]
            cd $git_path
            exec git add . -f 2>/dev/null
            set dt [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
            exec git commit -m "Sync from ClawHub: $dt" -q 2>/dev/null
            lappend results(synced_to_git) $skill
            write_to_log "  ✓ $skill aktualisiert"
        }
    } err]} {
        write_to_log "  ✗ ERROR: $skill - $err" "ERROR"
        lappend results(errors) "$skill"
    }
}

# Updates von Git nach ClawHub
foreach item $git_newer {
    lassign $item skill diff
    if {[catch {
        write_to_log "→ Update $skill (Git +[format "%.0f" $diff]s neuer)..."
        if {[sync_to_clawhub $skill 0]} {
            lappend results(synced_to_clawhub) $skill
            write_to_log "  ✓ $skill aktualisiert"
        }
    } err]} {
        write_to_log "  ✗ ERROR: $skill - $err" "ERROR"
        lappend results(errors) "$skill"
    }
}

set results(up_to_date) $synced

write_to_log ""
write_to_log [string repeat "=" 70]
write_to_log "SYNCHRONISATION ABGESCHLOSSEN"
write_to_log [string repeat "=" 70]
write_to_log "Zu Git synchronisiert:     [llength $results(synced_to_git)]"
write_to_log "Zu ClawHub synchronisiert: [llength $results(synced_to_clawhub)]"
write_to_log "Bereits aktuell:           [llength $results(up_to_date)]"
write_to_log "Fehler:                    [llength $results(errors)]"
if {[llength $results(errors)] > 0} {
    write_to_log "  Fehlerhafte: [join $results(errors) ", "]"
}
write_to_log [string repeat "=" 70]

# State speichern
set STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"
file mkdir [file dirname $STATE_FILE]

# Konvertiere Arrays für JSON
array set changes_count {}
foreach key [array names changes_detected] {
    if {[llength $changes_detected($key)] > 0 && [llength [lindex $changes_detected($key) 0]] == 2} {
        set changes_count($key) [llength $changes_detected($key)]
    } else {
        set changes_count($key) [llength $changes_detected($key)]
    }
}

set state_dict [dict create \
    last_run [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
    results [dict create \
        synced_to_git $results(synced_to_git) \
        synced_to_clawhub $results(synced_to_clawhub) \
        up_to_date $results(up_to_date) \
        errors $results(errors) \
    ] \
    changes_detected [array get changes_count] \
]

set state_json [::json::encode $state_dict]
set fh [open $STATE_FILE w]
puts $fh $state_json
close $fh
write_to_log "State gespeichert: $STATE_FILE"
