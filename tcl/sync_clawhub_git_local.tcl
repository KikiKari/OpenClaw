#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "f234e33227cf9e43c12bb467700bd9542c438b3e1959e83f7ebe2882a13ef9e9", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "tcl"}
# sync_clawhub_git_local.py — portiert nach tcl
# Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
# auch in: workspace@local:scripts/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Bidirektionale ClawHub ↔ Git Synchronisation

package require sha256
package require fileutil
package require cmdline

# Konfiguration
set scriptDir [file normalize [file dirname [info script]]]
set WORKSPACE_DIR [file dirname [file dirname $scriptDir]]
set CLAWHUB_DIR [file join $WORKSPACE_DIR skills]
set GIT_DIR [file join $WORKSPACE_DIR git skills]
set BACKUP_DIR [file join $WORKSPACE_DIR backups sync]
set LOG_FILE [file join $WORKSPACE_DIR logs sync-agent.log]

# Erstelle Verzeichnisse
file mkdir $GIT_DIR
file mkdir $BACKUP_DIR
file mkdir [file dirname $LOG_FILE]

# Logging
proc log {message {level "INFO"}} {
    global LOG_FILE
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    set fh [open $LOG_FILE a]
    puts $fh $entry
    close $fh
}

# Validierung
proc validate_skill {skill_dir} {
    if {![file exists [file join $skill_dir SKILL.md]]} {
        log "Validation failed: [file tail $skill_dir] missing SKILL.md" ERROR
        return 0
    }
    return 1
}

# Backup
proc create_backup {source skill_name} {
    global BACKUP_DIR
    set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
    set backup_path [file join $BACKUP_DIR ${skill_name}_$timestamp]
    
    # Backup verzeichnis löschen falls es existiert
    if {[file exists $backup_path]} {
        if {[catch {file delete -force $backup_path} error]} {
            log "Failed to remove existing backup $backup_path: $error" ERROR
            return 0
        } else {
            log "Removed existing backup: $backup_path"
        }
    }
    
    if {[catch {file copy -force $source $backup_path} error]} {
        log "Backup failed: $error" ERROR
        return 0
    } else {
        log "Backup created: $backup_path"
        return 1
    }
}

# Hash-Vergleich
proc get_file_hash {file_path} {
    if {[catch {open $file_path rb} fh]} {
        return ""
    }
    set hash [sha2::sha256 -channel $fh]
    close $fh
    return $hash
}

# Sync Richtung ClawHub → Git
proc sync_to_git {skill_name dry_run} {
    global CLAWHUB_DIR GIT_DIR
    set source [file join $CLAWHUB_DIR $skill_name]
    set target [file join $GIT_DIR $skill_name]
    
    if {![validate_skill $source]} {
        return 0
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if {!$dry_run && [file exists $target]} {
        create_backup $target $skill_name
    }
    
    # Änderungen erkennen
    set changes {}
    foreach item [glob -nocomplain -dir $source *] {
        set rel_items [list]
        lappend rel_items [fileutil::stripPath $source $item]
        while {[llength $rel_items] > 0} {
            set new_rel_items {}
            foreach rel_item $rel_items {
                set src_item [file join $source $rel_item]
                set tgt_item [file join $target $rel_item]
                
                if {[file isdirectory $src_item]} {
                    # Für Verzeichnisse alle Inhalte hinzufügen
                    foreach subitem [glob -nocomplain -dir $src_item *] {
                        lappend new_rel_items [file join $rel_item [file tail $subitem]]
                    }
                } else {
                    # Vergleich für Dateien
                    if {![file exists $tgt_item]} {
                        lappend changes "ADD $rel_item"
                    } elseif {[get_file_hash $src_item] ne [get_file_hash $tgt_item]} {
                        lappend changes "UPDATE $rel_item"
                    }
                }
            }
            set rel_items $new_rel_items
        }
    }
    
    # Dry-Run Report
    if {$dry_run} {
        log "DRY-RUN: $skill_name - [llength $changes] changes"
        foreach change $changes {
            log "  $change"
        }
        return 1
    }
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying [llength $changes] changes"
    if {[file exists $target]} {
        # Kopiere rekursiv und überspringe .git Ordner
        file delete -force $target
    }
    if {[catch {file copy -force $source $target} error]} {
        log "Sync failed: $error" ERROR
        return 0
    }
    log "SYNC: $skill_name - Complete"
    return 1
}

# Sync Richtung Git → ClawHub
proc sync_to_clawhub {skill_name dry_run} {
    global GIT_DIR CLAWHUB_DIR
    set source [file join $GIT_DIR $skill_name]
    set target [file join $CLAWHUB_DIR $skill_name]
    
    if {![validate_skill $source]} {
        return 0
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if {!$dry_run && [file exists $target]} {
        create_backup $target $skill_name
    }
    
    # Änderungen erkennen
    set changes {}
    foreach item [glob -nocomplain -dir $source *] {
        set rel_items [list]
        lappend rel_items [fileutil::stripPath $source $item]
        while {[llength $rel_items] > 0} {
            set new_rel_items {}
            foreach rel_item $rel_items {
                set src_item [file join $source $rel_item]
                set tgt_item [file join $target $rel_item]
                
                if {[file isdirectory $src_item]} {
                    # Für Verzeichnisse alle Inhalte hinzufügen
                    foreach subitem [glob -nocomplain -dir $src_item *] {
                        lappend new_rel_items [file join $rel_item [file tail $subitem]]
                    }
                } else {
                    # Vergleich für Dateien
                    if {![file exists $tgt_item]} {
                        lappend changes "ADD $rel_item"
                    } elseif {[get_file_hash $src_item] ne [get_file_hash $tgt_item]} {
                        lappend changes "UPDATE $rel_item"
                    }
                }
            }
            set rel_items $new_rel_items
        }
    }
    
    # Dry-Run Report
    if {$dry_run} {
        log "DRY-RUN: $skill_name - [llength $changes] changes"
        foreach change $changes {
            log "  $change"
        }
        return 1
    }
    
    # Echte Synchronisation
    log "SYNC: $skill_name - Applying [llength $changes] changes"
    if {[file exists $target]} {
        # Kopiere rekursiv 
        file delete -force $target
    }
    if {[catch {file copy -force $source $target} error]} {
        log "Sync failed: $error" ERROR
        return 0
    }
    log "SYNC: $skill_name - Complete"
    return 1
}

# Hauptfunktion
proc main {} {
    global argv
    array set options {
        skill ""
        direction ""
        {dry-run 0}
        force 0
    }
    
    set optionSpec {
        {skill.arg "" "Skill name"}
        {direction.arg "" "Direction: to-git or to-clawhub"}
        {dry-run "Nur Änderungen anzeigen"}
        {force "Ohne Backup"}
    }
    
    if {[catch {cmdline::typedGetoptions argv $optionSpec} result]} {
        puts stderr $result
        exit 1
    }
    
    array set options $result
    
    if {$options(skill) eq "" || $options(direction) eq ""} {
        puts stderr "Missing required arguments: --skill and --direction"
        exit 1
    }
    
    if {$options(direction) ni {"to-git" "to-clawhub"}} {
        puts stderr "Invalid direction. Use 'to-git' or 'to-clawhub'"
        exit 1
    }
    
    log "Starting sync: $options(skill) ($options(direction))"
    
    set success 0
    if {$options(direction) eq "to-git"} {
        set success [sync_to_git $options(skill) $options(dry-run)]
    } else {
        set success [sync_to_clawhub $options(skill) $options(dry-run)]
    }
    
    if {!$success} {
        log "Sync failed" ERROR
        exit 1
    }
    
    log "Sync completed"
}

if {[info script] eq $argv0} {
    main
}
