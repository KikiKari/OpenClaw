#!/usr/bin/env tclsh8.6
# sync_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

package require json
package require json::write

set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
set STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"
set BACKUP_ROOT "/home/openclaw/.openclaw/workspace/backups/sync_agent"

# Lade externe Funktionen
source "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.tcl"

proc load_state {} {
    global STATE_FILE
    if {[file exists $STATE_FILE]} {
        set fh [open $STATE_FILE r]
        set data [read $fh]
        close $fh
        return [json::json2dict $data]
    }
    return [dict create sync_history {} pending {}]
}

proc save_state {state} {
    global STATE_FILE
    file mkdir [file dirname $STATE_FILE]
    set fh [open $STATE_FILE w]
    puts $fh [json::write::indented 2 [dict create {*}$state]]
    close $fh
}

proc get_all_skills {} {
    global CLAWHUB_DIR GIT_DIR
    set clawhub_skills [list]
    set git_skills [list]
    
    # Hole Skills aus ClawHub
    if {[file isdirectory $CLAWHUB_DIR]} {
        foreach item [glob -nocomplain -directory $CLAWHUB_DIR *] {
            if {[file isdirectory $item] && ![string match .* [file tail $item]] && ![string match _* [file tail $item]]} {
                if {[file exists "$item/SKILL.md"]} {
                    lappend clawhub_skills [file tail $item]
                }
            }
        }
    }
    
    # Hole Skills aus Git
    if {[file isdirectory $GIT_DIR]} {
        foreach item [glob -nocomplain -directory $GIT_DIR *] {
            if {[file isdirectory $item] && ![string match .* [file tail $item]] && ![string match _* [file tail $item]]} {
                if {[file exists "$item/SKILL.md"]} {
                    lappend git_skills [file tail $item]
                }
            }
        }
    }
    
    # Vereinige beide Listen
    set all_skills [concat $clawhub_skills $git_skills]
    return [lsort -unique $all_skills]
}

proc init_git_repo {skill_path skill_name} {
    if {![file exists "$skill_path/.git"]} {
        set cwd [pwd]
        cd $skill_path
        exec git init
        exec git add .
        exec git commit -m "Initial commit: $skill_name skill"
        log "Git initialized for $skill_name"
        cd $cwd
    }
}

proc backup_skill_dir {skill_path skill_name} {
    global BACKUP_ROOT
    if {![file exists $skill_path]} {
        return
    }
    set timestamp [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    set backup_dir "$BACKUP_ROOT/$timestamp"
    file mkdir $backup_dir
    set archive_name "${skill_name}_${timestamp}.tar.gz"
    set archive_path "$backup_dir/$archive_name"
    set cwd [pwd]
    cd [file dirname $skill_path]
    exec tar czf $archive_path [file tail $skill_path]
    log "Backup created for $skill_name at $archive_path"
    cd $cwd
}

proc get_hashes {skill_dir} {
    set hashes [dict create]
    foreach file [glob -nocomplain -directory $skill_dir -types {f} **/*] {
        # Ignoriere .git Verzeichnisse
        if {![string match "*.git*" $file]} {
            set rel_path [string range $file [string length $skill_dir]+1 end]
            dict set hashes $rel_path [get_file_hash $file]
        }
    }
    return $hashes
}

proc sync_skill_bidirectional {skill_name {dry_run false}} {
    global CLAWHUB_DIR GIT_DIR
    
    set clawhub_path "$CLAWHUB_DIR/$skill_name"
    set git_path "$GIT_DIR/$skill_name"
    
    # Fall 1: Nur in ClawHub → zu Git
    if {[file exists $clawhub_path] && ![file exists $git_path]} {
        log "NEW in ClawHub: $skill_name → syncing to Git"
        if {!$dry_run} {
            backup_skill_dir $clawhub_path "${skill_name}_clawhub"
        }
        if {[sync_to_git $skill_name $dry_run]} {
            if {!$dry_run} {
                init_git_repo $git_path $skill_name
            }
            return "synced_to_git"
        }
    } 
    # Fall 2: Nur in Git → zu ClawHub
    elseif {[file exists $git_path] && ![file exists $clawhub_path]} {
        log "NEW in Git: $skill_name → syncing to ClawHub"
        if {!$dry_run} {
            backup_skill_dir $git_path "${skill_name}_git"
        }
        if {[sync_to_clawhub $skill_name $dry_run]} {
            return "synced_to_clawhub"
        }
    } 
    # Fall 3: In beiden vorhanden → Vergleiche Timestamps
    elseif {[file exists $clawhub_path] && [file exists $git_path]} {
        # Validierung
        if {![validate_skill $clawhub_path]} {
            log "Validation failed for ClawHub skill: $skill_name" "ERROR"
            return "error"
        }
        if {![validate_skill $git_path]} {
            log "Validation failed for Git skill: $skill_name" "ERROR"
            return "error"
        }
        
        # Berechne Hashes
        set clawhub_hashes [get_hashes $clawhub_path]
        set git_hashes [get_hashes $git_path]
        
        if {$clawhub_hashes != $git_hashes} {
            log "Content difference detected for: $skill_name"
            
            # Vergleiche Modifikationszeit
            set clawhub_mtime [file mtime $clawhub_path]
            set git_mtime [file mtime $git_path]
            
            set direction [expr {$clawhub_mtime >= $git_mtime ? "to-git" : "to-clawhub"}]
            log "UPDATE: $skill_name → syncing $direction"
            
            if {!$dry_run} {
                backup_skill_dir $clawhub_path "${skill_name}_clawhub"
                backup_skill_dir $git_path "${skill_name}_git"
            }
            
            set sync_func [expr {$direction eq "to-git" ? "sync_to_git" : "sync_to_clawhub"}]
            if {[$sync_func $skill_name $dry_run]} {
                if {!$dry_run && $direction eq "to-git"} {
                    set cwd [pwd]
                    cd $git_path
                    exec git add .
                    exec git commit -m "Sync from ClawHub content diff: [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]"
                    cd $cwd
                }
                return [expr {$direction eq "to-git" ? "updated_git" : "updated_clawhub"}]
            } else {
                log "Failed to sync $skill_name to Git after content diff" "ERROR"
                return "error"
            }
        } else {
            log "Content is identical for: $skill_name"
            return "no_change"
        }
    }
    
    return "no_change"
}

proc main {argv} {
    set dry_run [expr {[lsearch -exact $argv "--dry-run"] != -1}]
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    set state [load_state]
    set all_skills [get_all_skills]
    log "Gefundene Skills: [llength $all_skills]"
    
    array set results [list \
        synced_to_git [list] \
        synced_to_clawhub [list] \
        updated_git [list] \
        updated_clawhub [list] \
        no_change [list] \
        errors [list] \
    ]
    
    foreach skill [lsort -dictionary $all_skills] {
        if {[catch {
            set result [sync_skill_bidirectional $skill $dry_run]
            lappend results($result) $skill
        } error]} {
            log "ERROR syncing $skill: $error" "ERROR"
            lappend results(errors) $skill
        }
    }
    
    # Zusammenfassung
    log "\n=== SYNC ZUSAMMENFASSUNG ==="
    log "Neu in Git: [llength $results(synced_to_git)] - $results(synced_to_git)"
    log "Neu in ClawHub: [llength $results(synced_to_clawhub)] - $results(synced_to_clawhub)"
    log "Git aktualisiert: [llength $results(updated_git)] - $results(updated_git)"
    log "ClawHub aktualisiert: [llength $results(updated_clawhub)] - $results(updated_clawhub)"
    log "Keine Änderung: [llength $results(no_change)]"
    log "Fehler: [llength $results(errors)] - $results(errors)"
    
    # Speichere State außer bei Dry-Run
    if {!$dry_run} {
        if {![dict exists $state sync_history]} {
            dict set state sync_history [list]
        }
        dict with state {
            lappend sync_history [dict create \
                timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
                results [array get results]
            ]
            # Nur letzte 100 Einträge behalten
            set sync_history [lrange $sync_history end-99 end]
        }
        save_state $state
    }
    
    log "=== Sync Agent beendet ===\n"
}

# Starte Hauptprogramm
main $argv
