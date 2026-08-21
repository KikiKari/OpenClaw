#!/usr/bin/env tclsh8.6
# sync_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# Permanenter ClawHub ↔ Git Sync Agent
# Multi-Node fähig, stündliche Ausführung

package require json
package require fileutil

# Import sync functions
lappend auto_path "/home/openclaw/.openclaw/workspace/scripts"
namespace import ::tcl::mathop::*

set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
set STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"

source "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.tcl"

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
    # Ensure the parent directory exists (handle symlink to existing directory)
    set parent_dir [file dirname $STATE_FILE]
    if {![file isdirectory $parent_dir]} {
        file mkdir $parent_dir
    }
    set fd [open $STATE_FILE w]
    puts $fd [::json::dict2json $state]
    close $fd
}

proc get_all_skills {} {
    # Findet alle Skills in beiden Verzeichnissen
    global CLAWHUB_DIR GIT_DIR RESERVED_SKILL_NAMES
    
    set clawhub_skills {}
    foreach d [glob -nocomplain -directory $CLAWHUB_DIR *] {
        if {[file isdirectory $d] && 
            ![string match .* [file tail $d]] && 
            [lsearch -exact $RESERVED_SKILL_NAMES [file tail $d]] == -1 &&
            [file exists [file join $d SKILL.md]]} {
            lappend clawhub_skills [file tail $d]
        }
    }
    
    set git_skills {}
    foreach d [glob -nocomplain -directory $GIT_DIR *] {
        if {[file isdirectory $d] && 
            ![string match .* [file tail $d]] && 
            [lsearch -exact $RESERVED_SKILL_NAMES [file tail $d]] == -1 &&
            [file exists [file join $d SKILL.md]]} {
            lappend git_skills [file tail $d]
        }
    }
    
    # Union of both lists
    set all_skills {}
    foreach skill $clawhub_skills {
        if {[lsearch -exact $all_skills $skill] == -1} {
            lappend all_skills $skill
        }
    }
    foreach skill $git_skills {
        if {[lsearch -exact $all_skills $skill] == -1} {
            lappend all_skills $skill
        }
    }
    return $all_skills
}

proc init_git_repo {skill_path skill_name} {
    # Initialisiert Git-Repo wenn nötig
    set git_dir [file join $skill_path .git]
    if {![file exists $git_dir]} {
        cd $skill_path
        exec git init
        exec git add .
        exec git commit -m "Initial commit: $skill_name skill"
        log "Git initialized for $skill_name"
    }
}

proc sync_skill_bidirectional {skill_name} {
    # Bidirektionale Synchronisation eines Skills
    global CLAWHUB_DIR GIT_DIR
    
    set clawhub_path [file join $CLAWHUB_DIR $skill_name]
    set git_path [file join $GIT_DIR $skill_name]
    
    # Fall 1: Nur in ClawHub → zu Git
    if {[file exists $clawhub_path] && ![file exists $git_path]} {
        log "NEW in ClawHub: $skill_name → syncing to Git"
        if {[sync_to_git $skill_name 0]} {
            init_git_repo $git_path $skill_name
            return "synced_to_git"
        }
    } elseif {[file exists $git_path] && ![file exists $clawhub_path]} {
        # Fall 2: Nur in Git → zu ClawHub
        log "NEW in Git: $skill_name → syncing to ClawHub"
        if {[sync_to_clawhub $skill_name 0]} {
            return "synced_to_clawhub"
        }
    } elseif {[file exists $clawhub_path] && [file exists $git_path]} {
        # Fall 3: In beiden vorhanden
        if {![validate_skill $clawhub_path]} {
            log "Validation failed for ClawHub skill: $skill_name" "ERROR"
            return "error"
        }
        if {![validate_skill $git_path]} {
            log "Validation failed for Git skill: $skill_name" "ERROR"
            return "error"
        }

        set clawhub_changes [preview_changes $clawhub_path $git_path]
        set git_changes [preview_changes $git_path $clawhub_path]

        if {![llength $clawhub_changes] && ![llength $git_changes]} {
            log "Content is identical for: $skill_name"
            return "no_change"
        }

        if {[llength $clawhub_changes] && ![llength $git_changes]} {
            log "Content difference detected for: $skill_name"
            log "UPDATE: $skill_name ClawHub content is newer or different → syncing to Git"
            if {[sync_to_git $skill_name 0]} {
                cd $git_path
                exec git add .
                exec git commit -m "Sync from ClawHub content diff: [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]"
                return "updated_git"
            }
            log "Failed to sync $skill_name to Git after content diff" "ERROR"
            return "error"
        }

        if {[llength $git_changes] && ![llength $clawhub_changes]} {
            log "Content difference detected for: $skill_name"
            log "UPDATE: $skill_name Git content is newer or different → syncing to ClawHub"
            if {[sync_to_clawhub $skill_name 0]} {
                return "updated_clawhub"
            }
            log "Failed to sync $skill_name to ClawHub after content diff" "ERROR"
            return "error"
        }

        log "Content difference detected for: $skill_name"
        if {[newest_mtime $clawhub_path] >= [newest_mtime $git_path]} {
            log "UPDATE: $skill_name ClawHub content is newer or different → syncing to Git"
            if {[sync_to_git $skill_name 0]} {
                cd $git_path
                exec git add .
                exec git commit -m "Sync from ClawHub content diff: [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]"
                return "updated_git"
            }
        } else {
            log "UPDATE: $skill_name Git content is newer or different → syncing to ClawHub"
            if {[sync_to_clawhub $skill_name 0]} {
                return "updated_clawhub"
            }
        }

        log "Failed to resolve content diff for $skill_name" "ERROR"
        return "error"
    }
    
    return "no_change"
}

# --- Hinzufügen dieser Hilfsfunktion ---
proc get_hashes {skill_dir} {
    # Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
    array set hashes {}
    foreach {file_path rel_path} [iter_sync_files $skill_dir] {
        set hashes($rel_path) [get_file_hash $file_path]
    }
    return [array get hashes]
}

proc preview_changes {source_dir target_dir} {
    # Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben.
    set changes {}
    foreach {src_file rel_path} [iter_sync_files $source_dir] {
        set tgt_file [file join $target_dir $rel_path]
        if {![file exists $tgt_file]} {
            lappend changes "ADD $rel_path"
        } elseif {[get_file_hash $src_file] ne [get_file_hash $tgt_file]} {
            lappend changes "UPDATE $rel_path"
        }
    }
    return $changes
}

proc newest_mtime {skill_dir} {
    # Ermittelt die neueste mtime über alle relevanten Dateien.
    set mtimes {}
    foreach {file_path rel_path} [iter_sync_files $skill_dir] {
        lappend mtimes [file mtime $file_path]
    }
    if {[llength $mtimes] > 0} {
        return [tcl::mathfunc::max {*}$mtimes]
    } else {
        return 0.0
    }
}

proc main {} {
    # Hauptfunktion des Sync-Agents mit Dry-Run Phase
    log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    # Load previous state
    set state [load_state]
    set all_skills [get_all_skills]
    log "Gefundene Skills: [llength $all_skills]"
    
    # Dry-Run Phase: only report changes, no actual modifications
    log "--- Dry-Run Phase Start ---"
    foreach skill [lsort $all_skills] {
        # Perform dry-run sync in both directions to capture potential changes
        sync_to_git $skill 1
        sync_to_clawhub $skill 1
    }
    log "--- Dry-Run Phase End ---"
    
    array set results {
        synced_to_git {}
        synced_to_clawhub {}
        updated_git {}
        updated_clawhub {}
        no_change {}
        errors {}
    }
    
    # Actual Sync Phase
    foreach skill [lsort $all_skills] {
        if {[catch {
            set result [sync_skill_bidirectional $skill]
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
    
    # State speichern
    if {![dict exists $state sync_history]} {
        dict set state sync_history {}
    }
    dict lappend state sync_history [dict create \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
        results [array get results]]
    # Nur letzte 100 Einträge behalten
    set history [dict get $state sync_history]
    if {[llength $history] > 100} {
        dict set state sync_history [lrange $history end-99 end]
    }
    save_state $state
    
    log "=== Sync Agent beendet ===\n"
}

main
