#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "a49af86475d44eeb390b4a02fcee8e79abbd9504cc8616cff820b86723661251", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "tcl"}
# sync_agent_run.py — portiert nach tcl
# Quelle: python, workspace@local:scripts/sync_agent_run.py
# auch in: workspace@local:scripts/sync_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

package require Tcl 8.6
package require json
package require fileutil

# Globale Konfiguration
set CLAWHUB_DIR "/workspace/skills"
set GIT_DIR "/workspace/git/skills"
set STATE_FILE "/workspace/db/sync_state.json"
set BACKUP_ROOT "/workspace/backups/sync_agent"

# Lade externe Funktionen
source /workspace/scripts/sync_clawhub_git.tcl

proc load_state {} {
    # Lädt den Sync-State
    global STATE_FILE
    if {[file exists $STATE_FILE]} {
        set fd [open $STATE_FILE r]
        set data [read $fd]
        close $fd
        return [::json::json2dict $data]
    }
    return {"sync_history" {} "pending" {}}
}

proc save_state {state} {
    # Speichert den Sync-State
    global STATE_FILE
    set dir [file dirname $STATE_FILE]
    file mkdir $dir
    set fd [open $STATE_FILE w]
    puts $fd [::json::dict2json $state]
    close $fd
}

proc get_all_skills {} {
    # Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen.
    global CLAWHUB_DIR GIT_DIR
    
    set clawhub_skills {}
    foreach d [glob -nocomplain -directory $CLAWHUB_DIR *] {
        if {[file isdirectory $d] && 
            ![string match .* [file tail $d]] && 
            ![string match _* [file tail $d]] &&
            [file exists [file join $d SKILL.md]]} {
            lappend clawhub_skills [file tail $d]
        }
    }
    
    set git_skills {}
    foreach d [glob -nocomplain -directory $GIT_DIR *] {
        if {[file isdirectory $d] && 
            ![string match .* [file tail $d]] && 
            ![string match _* [file tail $d]] &&
            [file exists [file join $d SKILL.md]]} {
            lappend git_skills [file tail $d]
        }
    }
    
    return [lsort -unique [concat $clawhub_skills $git_skills]]
}

proc init_git_repo {skill_path skill_name} {
    # Initialisiert Git-Repo wenn nötig
    set git_dir [file join $skill_path .git]
    if {![file exists $git_dir]} {
        set oldpwd [pwd]
        cd $skill_path
        exec git init
        exec git add .
        exec git commit -m "Initial commit: ${skill_name} skill"
        log "Git initialized for ${skill_name}"
        cd $oldpwd
    }
}

proc backup_skill_dir {skill_path skill_name} {
    # Creates a timestamped tar.gz backup of a skill directory.
    global BACKUP_ROOT
    if {![file exists $skill_path]} {
        return
    }
    set timestamp [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    set backup_dir [file join $BACKUP_ROOT $timestamp]
    file mkdir $backup_dir
    set archive_name "${skill_name}_${timestamp}.tar.gz"
    set archive_path [file join $backup_dir $archive_name]
    set oldpwd [pwd]
    cd [file dirname $skill_path]
    exec tar czf $archive_path [file tail $skill_path]
    log "Backup created for ${skill_name} at ${archive_path}"
    cd $oldpwd
}

proc get_hashes {skill_dir} {
    # Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
    array set hashes {}
    foreach file [glob -nocomplain -directory $skill_dir -types f **] {
        # Ignoriere .git Verzeichnisse
        if {[string first ".git" $file] == -1} {
            set rel_path [fileutil::stripPath $skill_dir $file]
            set hashes($rel_path) [get_file_hash $file]
        }
    }
    return [array get hashes]
}

proc sync_skill_bidirectional {skill_name {dry_run false}} {
    # Bidirektionale Synchronisation eines Skills
    global CLAWHUB_DIR GIT_DIR
    
    set clawhub_path [file join $CLAWHUB_DIR $skill_name]
    set git_path [file join $GIT_DIR $skill_name]
    
    # Fall 1: Nur in ClawHub → zu Git
    if {[file exists $clawhub_path] && ![file exists $git_path]} {
        log "NEW in ClawHub: ${skill_name} → syncing to Git"
        if {!$dry_run} {
            backup_skill_dir $clawhub_path "${skill_name}_clawhub"
        }
        if {[sync_to_git $skill_name $dry_run]} {
            if {!$dry_run} {
                init_git_repo $git_path $skill_name
            }
            return "synced_to_git"
        }
    } elseif {[file exists $git_path] && ![file exists $clawhub_path]} {
        # Fall 2: Nur in Git → zu ClawHub
        log "NEW in Git: ${skill_name} → syncing to ClawHub"
        if {!$dry_run} {
            backup_skill_dir $git_path "${skill_name}_git"
        }
        if {[sync_to_clawhub $skill_name $dry_run]} {
            return "synced_to_clawhub"
        }
    } elseif {[file exists $clawhub_path] && [file exists $git_path]} {
        # Fall 3: In beiden vorhanden → Vergleiche Timestamps
        
        # Stelle sicher, dass beide als gültige Skills validiert werden
        if {![validate_skill $clawhub_path]} {
            log "Validation failed for ClawHub skill: ${skill_name}" "ERROR"
            return "error"
        }
        if {![validate_skill $git_path]} {
            log "Validation failed for Git skill: ${skill_name}" "ERROR"
            return "error"
        }
        
        # Berechne Hashes für clawhub und git
        array set clawhub_hashes [get_hashes $clawhub_path]
        array set git_hashes [get_hashes $git_path]
        
        set hash_diff 0
        foreach key [array names clawhub_hashes] {
            if {![info exists git_hashes($key)] || $clawhub_hashes($key) ne $git_hashes($key)} {
                set hash_diff 1
                break
            }
        }
        if {!$hash_diff} {
            foreach key [array names git_hashes] {
                if {![info exists clawhub_hashes($key)] || $git_hashes($key) ne $clawhub_hashes($key)} {
                    set hash_diff 1
                    break
                }
            }
        }
        
        if {$hash_diff} {
            log "Content difference detected for: ${skill_name}"
            
            # Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
            # Eine detailliertere Strategie (z.B. welche Version von Git übernehmen)
            # könnte hier implementiert werden, falls nötig.
            # Für jetzt: Wenn sie sich unterscheiden, priorisieren wir ClawHub > Git
            # und aktualisieren Git.
            
            set clawhub_time [file mtime $clawhub_path]
            set git_time [file mtime $git_path]
            set direction [expr {$clawhub_time >= $git_time ? "to-git" : "to-clawhub"}]
            log "UPDATE: ${skill_name} → syncing ${direction}"
            if {!$dry_run} {
                backup_skill_dir $clawhub_path "${skill_name}_clawhub"
                backup_skill_dir $git_path "${skill_name}_git"
            }
            set sync_func [expr {$direction eq "to-git" ? "sync_to_git" : "sync_to_clawhub"}]
            if {[$sync_func $skill_name $dry_run]} {
                if {!$dry_run && $direction eq "to-git"} {
                    set oldpwd [pwd]
                    cd $git_path
                    exec git add .
                    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
                    exec git commit -m "Sync from ClawHub content diff: ${timestamp}"
                    cd $oldpwd
                }
                return [expr {$direction eq "to-git" ? "updated_git" : "updated_clawhub"}]
            } else {
                log "Failed to sync ${skill_name} to Git after content diff" "ERROR"
                return "error"
            }
        } else {
            log "Content is identical for: ${skill_name}"
            return "no_change"
        }
    }
    
    return "no_change"
}

proc main {argv} {
    # Hauptfunktion des Sync-Agents
    set dry_run false
    if {[lsearch -exact $argv "--dry-run"] != -1} {
        set dry_run true
    }
    
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    set state [load_state]
    set all_skills [get_all_skills]
    log "Gefundene Skills: [llength $all_skills]"
    
    array set results {
        synced_to_git {}
        synced_to_clawhub {}
        updated_git {}
        updated_clawhub {}
        no_change {}
        errors {}
    }
    
    foreach skill [lsort $all_skills] {
        if {[catch {
            set result [sync_skill_bidirectional $skill $dry_run]
            lappend results($result) $skill
        } error]} {
            log "ERROR syncing ${skill}: ${error}" "ERROR"
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
    
    # Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
    if {!$dry_run} {
        if {![info exists state(sync_history)]} {
            set state(sync_history) {}
        }
        lappend state(sync_history) [dict create \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
            results [array get results]]
        # Nur letzte 100 Einträge behalten
        set state(sync_history) [lrange $state(sync_history) end-99 end]
        save_state $state
    }
    
    log "=== Sync Agent beendet ===\n"
}

# Starte das Programm
main $argv
