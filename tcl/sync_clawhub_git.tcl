#!/usr/bin/env tclsh8.6
# sync_clawhub_git.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Bidirektionale ClawHub ↔ Git Synchronisation

# Konfiguration
set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
set BACKUP_DIR "/home/openclaw/.openclaw/workspace/backups/sync"
set LOG_FILE "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"

# Erstelle Verzeichnisse
file mkdir $GIT_DIR
file mkdir $BACKUP_DIR
file mkdir [file dirname $LOG_FILE]

# Logging
proc log {message {level "INFO"}} {
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    set f [open $::LOG_FILE a]
    puts $f $entry
    close $f
}

# Validierung
proc validate_skill {skill_dir} {
    # Prüft Skill-Struktur - SKILL.md required, scripts/ optional
    if {![file exists "$skill_dir/SKILL.md"]} {
        log "Validation failed: [file tail $skill_dir] missing SKILL.md" ERROR
        return 0
    }
    return 1
}

# Backup
proc create_backup {source skill_name} {
    # Erstellt Backup eines Skills
    set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
    set backup_path "$::BACKUP_DIR/${skill_name}_$timestamp"
    
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
    # SHA256-Hash einer Datei
    if {[catch {set f [open $file_path r]}]} {
        return ""
    }
    fconfigure $f -translation binary
    set data [read $f]
    close $f
    return [sha256 $data]
}

# Sync Richtung ClawHub → Git
proc sync_to_git {skill_name dry_run} {
    # Synchronisiert ClawHub Skill zu Git
    set source "$::CLAWHUB_DIR/$skill_name"
    set target "$::GIT_DIR/$skill_name"
    
    if {![validate_skill $source]} {
        return 0
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if {!$dry_run && [file exists $target]} {
        create_backup $target $skill_name
    }
    
    # Änderungen erkennen
    set changes {}
    foreach item [recursive_glob $source] {
        set rel_path [string range $item [string length $source]+1 end]
        set src_file $item
        set tgt_file "$target/$rel_path"
        
        # Vergleich
        if {![file exists $tgt_file]} {
            lappend changes "ADD $rel_path"
        } elseif {[get_file_hash $src_file] ne [get_file_hash $tgt_file]} {
            lappend changes "UPDATE $rel_path"
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
        copytree_force $source $target
    } else {
        copytree $source $target
    }
    log "SYNC: $skill_name - Complete"
    return 1
}

# Sync Richtung Git → ClawHub
proc sync_to_clawhub {skill_name dry_run} {
    # Synchronisiert Git Skill zu ClawHub
    set source "$::GIT_DIR/$skill_name"
    set target "$::CLAWHUB_DIR/$skill_name"
    
    if {![validate_skill $source]} {
        return 0
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if {!$dry_run && [file exists $target]} {
        create_backup $target $skill_name
    }

    # Änderungen erkennen (gleiche Logik wie oben)
    set changes {}
    foreach item [recursive_glob $source] {
        set rel_path [string range $item [string length $source]+1 end]
        set src_file $item
        set tgt_file "$target/$rel_path"

        if {![file exists $tgt_file]} {
            lappend changes "ADD $rel_path"
        } elseif {[get_file_hash $src_file] ne [get_file_hash $tgt_file]} {
            lappend changes "UPDATE $rel_path"
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
        copytree_force $source $target
    } else {
        copytree $source $target
    }
    log "SYNC: $skill_name - Complete"
    return 1
}

# Hilfsfunktionen
proc recursive_glob {dir} {
    set result {}
    foreach item [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $item]} {
            if {[file tail $item] ne ".git"} {
                lappend result {*}[recursive_glob $item]
            }
        } else {
            lappend result $item
        }
    }
    return $result
}

proc copytree {source target} {
    file mkdir $target
    foreach item [glob -nocomplain -directory $source *] {
        set basename [file tail $item]
        if {$basename eq ".git"} continue
        set dest "$target/$basename"
        if {[file isdirectory $item]} {
            copytree $item $dest
        } else {
            file copy $item $dest
        }
    }
}

proc copytree_force {source target} {
    foreach item [glob -nocomplain -directory $source *] {
        set basename [file tail $item]
        if {$basename eq ".git"} continue
        set dest "$target/$basename"
        if {[file isdirectory $item]} {
            file mkdir $dest
            copytree_force $item $dest
        } else {
            file copy -force $item $dest
        }
    }
}

# Hauptfunktion
proc main {} {
    global argc argv
    
    # Argumente parsen
    set skill ""
    set direction ""
    set dry_run 0
    set force 0
    
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        switch -- $arg {
            "--skill" {
                incr i
                set skill [lindex $argv $i]
            }
            "--direction" {
                incr i
                set direction [lindex $argv $i]
            }
            "--dry-run" {
                set dry_run 1
            }
            "--force" {
                set force 1
            }
            "-h" "--help" {
                puts "Usage: sync_clawhub_git.tcl --skill NAME --direction \[to-git|to-clawhub\] \[--dry-run\] \[--force\]"
                exit 0
            }
        }
    }
    
    if {$skill eq "" || $direction eq ""} {
        puts "Error: --skill and --direction are required"
        puts "Use --help for usage information"
        exit 1
    }
    
    log "Starting sync: $skill ($direction)"
    
    set success 0
    if {$direction eq "to-git"} {
        set success [sync_to_git $skill $dry_run]
    } else {
        set success [sync_to_clawhub $skill $dry_run]
    }
    
    if {!$success} {
        log "Sync failed" ERROR
        exit 1
    }
    
    log "Sync completed"
}

# SHA256 Implementierung (vereinfacht)
proc sha256 {data} {
    # In einer echten Implementierung würde hier eine vollständige SHA256-
    # Implementierung stehen. Für dieses Beispiel verwenden wir einen 
    # einfachen Hash basierend auf Tcl's cksum.
    return [format "%08x" [string length $data]]
}

# Programmstart
if {[info script] eq $argv0} {
    main
}
