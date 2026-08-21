#!/usr/bin/env tclsh8.6
# sync_agent_run.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# ClawHub ↔ Git Sync Agent - Produktionslauf

lappend auto_path /home/openclaw/.openclaw/workspace/scripts
package require json

source /home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.tcl

set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"

proc file_mtime {path} {
    set files {}
    catch {
        set dirlist [glob -nocomplain -directory $path -types f **]
        foreach f $dirlist {
            if {![string match "*.git*" $f]} {
                lappend files $f
            }
        }
    }
    
    if {[llength $files] == 0} {
        return 0
    }
    
    set mtimes {}
    foreach f $files {
        catch {
            lappend mtimes [file mtime $f]
        }
    }
    
    if {[llength $mtimes] == 0} {
        return 0
    }
    
    return [tcl::mathfunc::max {*}$mtimes]
}

proc log_message {msg {level "INFO"}} {
    puts $msg
}

log_message [string repeat "=" 70]
log_message "CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF"
log_message "Zeitstempel: [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
log_message [string repeat "=" 70]

# Hole Skill-Verzeichnisse
set clawhub_skills {}
catch {
    foreach d [glob -nocomplain -directory $CLAWHUB_DIR *] {
        if {[file isdirectory $d] && ![string match ".*" [file tail $d]]} {
            lappend clawhub_skills [file tail $d]
        }
    }
}

set git_skills {}
catch {
    foreach d [glob -nocomplain -directory $GIT_DIR *] {
        if {[file isdirectory $d] && ![string match ".*" [file tail $d]]} {
            lappend git_skills [file tail $d]
        }
    }
}

array set results {
    synced_to_git {}
    synced_to_clawhub {}
    up_to_date {}
    errors {}
}

# 1. NEU in ClawHub → zu Git syncen
log_message "\n\[PHASE 1\] ClawHub → Git Synchronisation"
log_message [string repeat "-" 40]

set new_in_clawhub {}
foreach skill $clawhub_skills {
    if {$skill ni $git_skills} {
        lappend new_in_clawhub $skill
    }
}
set new_in_clawhub [lsort $new_in_clawhub]

foreach skill $new_in_clawhub {
    if {[catch {
        if {[validate_skill "$CLAWHUB_DIR/$skill"]} {
            log_message "→ Synchronisiere $skill zu Git..."
            if {[sync_to_git $skill 0]} {
                # Git init
                set git_path "$GIT_DIR/$skill"
                cd $git_path
                exec >/dev/null 2>@1 git init -q
                exec >/dev/null 2>@1 git add . -f
                set dt [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
                exec >/dev/null 2>@1 git commit -m "Initial: $skill" -q
                lappend results(synced_to_git) $skill
                log_message "  ✓ $skill synchronisiert & Git initialisiert"
            } else {
                lappend results(errors) "$skill (sync failed)"
            }
        } else {
            lappend results(errors) "$skill (invalid)"
        }
    } errmsg]} {
        log_message "  ✗ ERROR: $skill - $errmsg" "ERROR"
        lappend results(errors) "$skill (exception)"
    }
}

# 2. In beiden - prüfe Änderungen
log_message "\n\[PHASE 2\] Prüfe existierende Skills auf Änderungen"
log_message [string repeat "-" 40]

set in_both {}
foreach skill $clawhub_skills {
    if {$skill in $git_skills} {
        lappend in_both $skill
    }
}
set in_both [lsort $in_both]

foreach skill $in_both {
    if {[catch {
        set c_mtime [file_mtime "$CLAWHUB_DIR/$skill"]
        set g_mtime [file_mtime "$GIT_DIR/$skill"]
        set diff [expr {$c_mtime - $g_mtime}]
        
        if {abs($diff) > 60} {
            if {$diff > 0} {
                log_message "→ $skill: ClawHub neuer (+[format "%.0f" $diff]s) → sync zu Git"
                if {[sync_to_git $skill 0]} {
                    set git_path "$GIT_DIR/$skill"
                    cd $git_path
                    exec >/dev/null 2>@1 git add . -f
                    set dt [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
                    exec >/dev/null 2>@1 git commit -m "Sync from ClawHub: $dt" -q
                    lappend results(synced_to_git) $skill
                } else {
                    lappend results(errors) "$skill (update failed)"
                }
            } else {
                log_message "→ $skill: Git neuer (+[format "%.0f" [expr abs($diff)]]s) → sync zu ClawHub"
                if {[sync_to_clawhub $skill 0]} {
                    lappend results(synced_to_clawhub) $skill
                } else {
                    lappend results(errors) "$skill (update failed)"
                }
            }
        } else {
            lappend results(up_to_date) $skill
        }
    } errmsg]} {
        log_message "  ✗ ERROR: $skill - $errmsg" "ERROR"
        lappend results(errors) "$skill (exception)"
    }
}

# ZUSAMMENFASSUNG
log_message "\n[string repeat "=" 70]"
log_message "SYNCHRONISATION ABGESCHLOSSEN"
log_message [string repeat "=" 70]
log_message [format "Zu Git synchronisiert:     %d" [llength $results(synced_to_git)]]
if {[llength $results(synced_to_git)] > 0} {
    log_message "  [join $results(synced_to_git) ", "]"
}
log_message [format "Zu ClawHub synchronisiert: %d" [llength $results(synced_to_clawhub)]]
if {[llength $results(synced_to_clawhub)] > 0} {
    log_message "  [join $results(synced_to_clawhub) ", "]"
}
log_message [format "Bereits aktuell:           %d" [llength $results(up_to_date)]]
log_message [format "Fehler:                    %d" [llength $results(errors)]]
if {[llength $results(errors)] > 0} {
    log_message "  [join $results(errors) ", "]"
}
log_message [string repeat "=" 70]

# Speichere State
set STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"
file mkdir [file dirname $STATE_FILE]

set now [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
set state_dict [dict create \
    last_run $now \
    results [dict create \
        synced_to_git $results(synced_to_git) \
        synced_to_clawhub $results(synced_to_clawhub) \
        up_to_date $results(up_to_date) \
        errors $results(errors)]]

set fp [open $STATE_FILE w]
puts $fp [::json::write object \
    last_run $now \
    results [::json::write object \
        synced_to_git [::json::write array {*}$results(synced_to_git)] \
        synced_to_clawhub [::json::write array {*}$results(synced_to_clawhub)] \
        up_to_date [::json::write array {*}$results(up_to_date)] \
        errors [::json::write array {*}$results(errors)]]
close $fp

log_message "State gespeichert: $STATE_FILE"
