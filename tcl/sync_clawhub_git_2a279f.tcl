#!/usr/bin/env tclsh8.6
# sync_clawhub_git.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
# auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Bidirektionale ClawHub ↔ Git Synchronisation

package require fileutil
package require sha256

# Konfiguration
# Resolve paths relative to this repository so the helper works both in the
# hosted workspace and in environments without a /workspace mount.
set script_dir [file dirname [file normalize $argv0]]
set WORKSPACE_ROOT [file dirname $script_dir]
set CLAWHUB_DIR [file join $WORKSPACE_ROOT skills]
set GIT_DIR [file join $WORKSPACE_ROOT git skills]
set BACKUP_DIR [file join $WORKSPACE_ROOT backups sync]
set LOG_FILE [file join $WORKSPACE_ROOT logs sync-agent.log]
array set IGNORED_NAMES {}
foreach name {.git .clawhub node_modules __pycache__ .pytest_cache} {
    set IGNORED_NAMES($name) 1
}
array set RESERVED_SKILL_NAMES {}
foreach name {github-clones skills backups .restore git Abstraktionen} {
    set RESERVED_SKILL_NAMES($name) 1
}
array set PRESERVED_TARGET_NAMES {}
foreach name {.git .clawhub node_modules __pycache__ .pytest_cache} {
    set PRESERVED_TARGET_NAMES($name) 1
}

# Erstelle Verzeichnisse
file mkdir $GIT_DIR
file mkdir $BACKUP_DIR
file mkdir [file dirname $LOG_FILE]

# Logging
proc log {message {level INFO}} {
    global LOG_FILE
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set entry "\[$timestamp\] \[$level\] $message"
    puts $entry
    if {[info exists LOG_FILE]} {
        set f [open $LOG_FILE a]
        puts $f $entry
        close $f
    }
}

# Validierung
proc validate_skill {skill_dir} {
    global RESERVED_SKILL_NAMES
    set skill_name [file tail $skill_dir]
    if {[info exists RESERVED_SKILL_NAMES($skill_name)]} {
        log "Validation failed: $skill_name is reserved and must not be synced as a skill" ERROR
        return 0
    }
    if {![file exists [file join $skill_dir SKILL.md]]} {
        log "Validation failed: $skill_name missing SKILL.md" ERROR
        return 0
    }
    return 1
}

proc _is_ignored_path {path_parts} {
    global IGNORED_NAMES
    foreach part $path_parts {
        if {[info exists IGNORED_NAMES($part)] || [string match "*.pyc" $part]} {
            return 1
        }
    }
    return 0
}

proc _is_generated_duplicate_path {root rel_path_parts} {
    # Detect generated duplicate folders such as <skill>/<skill> or scripts/scripts.
    if {[llength $rel_path_parts] == 0} {
        return 0
    }
    set first_part [lindex $rel_path_parts 0]
    if {$first_part eq [file tail $root]} {
        return 1
    }
    for {set i 1} {$i < [llength $rel_path_parts]} {incr i} {
        if {[lindex $rel_path_parts $i] eq [lindex $rel_path_parts [expr {$i - 1}]]} {
            return 1
        }
    }
    return 0
}

proc iter_sync_files {root} {
    global IGNORED_NAMES
    set result {}
    set all_files [glob -nocomplain -dir $root -types {f d l} *]
    set queue [list $root]
    
    while {[llength $queue] > 0} {
        set current_dir [lindex $queue 0]
        set queue [lrange $queue 1 end]
        
        set rel_current [fileutil::stripPath $root $current_dir]
        set rel_parts [split $rel_current "/"]
        
        if {[_is_ignored_path $rel_parts]} {
            continue
        }
        
        set entries [glob -nocomplain -dir $current_dir *]
        foreach entry $entries {
            set basename [file tail $entry]
            if {[info exists IGNORED_NAMES($basename)] || [string match "*__pycache__*" $basename] || [string match "*.pyc" $basename]} {
                continue
            }
            
            set rel_entry_path [fileutil::stripPath $root $entry]
            set rel_entry_parts [split $rel_entry_path "/"]
            
            if {[_is_ignored_path $rel_entry_parts]} {
                continue
            }
            
            if {[_is_generated_duplicate_path $root $rel_entry_parts]} {
                continue
            }
            
            if {[file tail $entry] eq "SKILL.md" && $rel_entry_path ne "SKILL.md"} {
                continue
            }
            
            if {[file isfile $entry]} {
                lappend result [list $entry $rel_entry_path]
            } elseif {[file isdirectory $entry] && ![file islink $entry]} {
                lappend queue $entry
            }
        }
    }
    return $result
}

proc reset_sync_target {target} {
    global PRESERVED_TARGET_NAMES
    file mkdir $target
    set children [glob -nocomplain -dir $target *]
    foreach child $children {
        set child_name [file tail $child]
        if {[info exists PRESERVED_TARGET_NAMES($child_name)]} {
            continue
        }
        if {[file isdirectory $child] && ![file islink $child]} {
            file delete -force $child
        } else {
            file delete $child
        }
    }
}

proc copy_sync_files {source target} {
    reset_sync_target $target
    set files_to_copy [iter_sync_files $source]
    foreach item $files_to_copy {
        lassign $item src_file rel_path
        set dest_file [file join $target $rel_path]
        file mkdir [file dirname $dest_file]
        if {[file isfile $src_file]} {
            file copy -force $src_file $dest_file
        }
    }
}

# Backup
proc create_backup {source skill_name} {
    global BACKUP_DIR
    set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
    set backup_path [file join $BACKUP_DIR "${skill_name}_${timestamp}"]
    
    # Backup verzeichnis löschen falls es existiert
    if {[file exists $backup_path]} {
        if {[catch {file delete -force $backup_path} error]} {
            log "Failed to remove existing backup $backup_path: $error" ERROR
            return 0
        } else {
            log "Removed existing backup: $backup_path"
        }
    }
    
    if {[catch {file copy $source $backup_path} error]} {
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
    # Ensure the path points to a regular file.
    if {![file isfile $file_path]} {
        return ""
    }
    if {[catch {sha256::sha256 -file $file_path} hash]} {
        log "Failed to hash $file_path: $hash" ERROR
        return ""
    }
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
    set files_to_check [iter_sync_files $source]
    foreach item $files_to_check {
        lassign $item src_file rel_path
        set tgt_file [file join $target $rel_path]
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
    copy_sync_files $source $target
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

    # Änderungen erkennen (gleiche Logik wie oben)
    set changes {}
    set files_to_check [iter_sync_files $source]
    foreach item $files_to_check {
        lassign $item src_file rel_path
        set tgt_file [file join $target $rel_path]
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
    copy_sync_files $source $target
    log "SYNC: $skill_name - Complete"
    return 1
}

# Hauptfunktion
proc main {} {
    global argv
    array set args {}
    
    # Parse arguments manually since we don't have argparse in Tcl
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        switch -- $arg {
            --skill {
                if {$i >= [llength $argv]} {
                    puts "Error: --skill requires an argument"
                    exit 1
                }
                set args(skill) [lindex $argv $i]
                incr i
            }
            --direction {
                if {$i >= [llength $argv]} {
                    puts "Error: --direction requires an argument"
                    exit 1
                }
                set args(direction) [lindex $argv $i]
                incr i
            }
            --dry-run {
                set args(dry_run) 1
            }
            --force {
                set args(force) 1
            }
            default {
                puts "Unknown argument: $arg"
                exit 1
            }
        }
    }
    
    # Check required arguments
    if {![info exists args(skill)] || ![info exists args(direction)]} {
        puts "Usage: $argv0 --skill <skill> --direction <to-git|to-clawhub> \[--dry-run\] \[--force\]"
        exit 1
    }
    
    set skill $args(skill)
    set direction $args(direction)
    set dry_run [expr {[info exists args(dry_run)] ? 1 : 0}]
    
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

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
