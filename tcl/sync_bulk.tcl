#!/usr/bin/env tclsh8.6
# sync_bulk.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Bulk Sync - Synchronisiert alle Skills

package require fileutil

# Globale Variablen
set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"

# Lade externe Funktionen
source "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.tcl"

proc sync_all_skills {dry_run} {
    global CLAWHUB_DIR GIT_DIR
    
    # Alle Skills finden
    set all_skills [dict create]
    
    # Skills aus ClawHub
    if {[file exists $CLAWHUB_DIR]} {
        foreach dir [glob -nocomplain -directory $CLAWHUB_DIR -type d *] {
            set skill_name [file tail $dir]
            if {![string match ".*" $skill_name]} {
                dict set all_skills $skill_name 1
            }
        }
    }
    
    # Skills aus Git
    if {[file exists $GIT_DIR]} {
        foreach dir [glob -nocomplain -directory $GIT_DIR -type d *] {
            set skill_name [file tail $dir]
            if {![string match ".*" $skill_name]} {
                dict set all_skills $skill_name 1
            }
        }
    }
    
    set skill_count [dict size $all_skills]
    log "Bulk Sync: $skill_count Skills gefunden"
    
    set results [dict create synced {} skipped {} failed {}]
    
    foreach skill [lsort [dict keys $all_skills]] {
        set clawhub_path [file join $CLAWHUB_DIR $skill]
        set git_path [file join $GIT_DIR $skill]
        
        if {[catch {
            # Nur in ClawHub → zu Git
            if {[file exists $clawhub_path] && ![file exists $git_path]} {
                if {[validate_skill $clawhub_path]} {
                    log "Syncing $skill to Git..."
                    if {[sync_to_git $skill $dry_run]} {
                        set current_synced [dict get $results synced]
                        lappend current_synced "$skill → Git"
                        dict set results synced $current_synced
                    } else {
                        set current_failed [dict get $results failed]
                        lappend current_failed $skill
                        dict set results failed $current_failed
                    }
                } else {
                    set current_skipped [dict get $results skipped]
                    lappend current_skipped "$skill (validation failed)"
                    dict set results skipped $current_skipped
                }
            }
            
            # Nur in Git → zu ClawHub
            elseif {[file exists $git_path] && ![file exists $clawhub_path]} {
                if {[validate_skill $git_path]} {
                    log "Syncing $skill to ClawHub..."
                    if {[sync_to_clawhub $skill $dry_run]} {
                        set current_synced [dict get $results synced]
                        lappend current_synced "$skill → ClawHub"
                        dict set results synced $current_synced
                    } else {
                        set current_failed [dict get $results failed]
                        lappend current_failed $skill
                        dict set results failed $current_failed
                    }
                } else {
                    set current_skipped [dict get $results skipped]
                    lappend current_skipped "$skill (validation failed)"
                    dict set results skipped $current_skipped
                }
            }
            
            # In beiden - prüfe ob Update nötig
            elseif {[file exists $clawhub_path] && [file exists $git_path]} {
                # Vereinfachte Prüfung
                set clawhub_files [glob -nocomplain -directory $clawhub_path -type f **/*]
                set clawhub_mtime 0
                foreach f $clawhub_files {
                    set mtime [file mtime $f]
                    if {$mtime > $clawhub_mtime} {
                        set clawhub_mtime $mtime
                    }
                }
                
                set git_files [glob -nocomplain -directory $git_path -type f **/*]
                set git_mtime 0
                foreach f $git_files {
                    if {![string match "*/.git/*" $f] && ![string match ".git" [file tail [file dirname $f]]]} {
                        set mtime [file mtime $f]
                        if {$mtime > $git_mtime} {
                            set git_mtime $mtime
                        }
                    }
                }
                
                if {abs($clawhub_mtime - $git_mtime) > 60} {
                    if {$clawhub_mtime > $git_mtime} {
                        log "Updating $skill in Git..."
                        if {[sync_to_git $skill $dry_run]} {
                            set current_synced [dict get $results synced]
                            lappend current_synced "$skill → Git (update)"
                            dict set results synced $current_synced
                        } else {
                            set current_failed [dict get $results failed]
                            lappend current_failed $skill
                            dict set results failed $current_failed
                        }
                    } else {
                        log "Updating $skill in ClawHub..."
                        if {[sync_to_clawhub $skill $dry_run]} {
                            set current_synced [dict get $results synced]
                            lappend current_synced "$skill → ClawHub (update)"
                            dict set results synced $current_synced
                        } else {
                            set current_failed [dict get $results failed]
                            lappend current_failed $skill
                            dict set results failed $current_failed
                        }
                    }
                } else {
                    set current_skipped [dict get $results skipped]
                    lappend current_skipped "$skill (already synced)"
                    dict set results skipped $current_skipped
                }
            }
        } err]} {
            log "Error processing $skill: $err" "ERROR"
            set current_failed [dict get $results failed]
            lappend current_failed $skill
            dict set results failed $current_failed
        }
    }
    
    # Zusammenfassung
    puts "\n[string repeat = 60]"
    set mode "DRY-RUN"
    if {!$dry_run} {
        set mode "EXECUTED"
    }
    puts "Bulk Sync $mode - Zusammenfassung"
    puts "[string repeat = 60]"
    
    set synced_list [dict get $results synced]
    set skipped_list [dict get $results skipped]
    set failed_list [dict get $results failed]
    
    puts "✅ Synchronisiert: [llength $synced_list]"
    foreach item $synced_list {
        puts "   - $item"
    }
    
    puts "\n⏭️  Übersprungen: [llength $skipped_list]"
    if {[llength $skipped_list] <= 10} {
        foreach item $skipped_list {
            puts "   - $item"
        }
    } else {
        puts "   - [llength $skipped_list] Skills (bereits synchron oder Validierung fehlgeschlagen)"
    }
    
    puts "\n❌ Fehlgeschlagen: [llength $failed_list]"
    foreach item $failed_list {
        puts "   - $item"
    }
    puts "[string repeat = 60]"
}

proc main {} {
    global argv
    
    set dry_run false
    set execute false
    
    # Argumente parsen
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            "--dry-run" {
                set dry_run true
            }
            "--execute" {
                set execute true
            }
        }
    }
    
    if {!$dry_run && !$execute} {
        puts "Bitte --dry-run oder --execute angeben"
        exit 1
    }
    
    sync_all_skills $dry_run
}

# Hauptprogramm starten
main
