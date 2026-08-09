#!/usr/bin/env tclsh
# check_conflicts.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Check Conflicts - Erkennt Sync-Konflikte

package require Tcl 8.6
package require fileutil
package require cmdline

# Import sync functions
source "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.tcl"

set ::CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set ::GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"

proc get_file_hash {file_path} {
    return [::sync_clawhub_git::get_file_hash $file_path]
}

proc check_conflicts {} {
    # Prüft auf Konflikte zwischen ClawHub und Git
    set conflicts {}
    
    # Alle Skills die in beiden Orten existieren
    set common_skills {}
    if {[file exists $::CLAWHUB_DIR] && [file exists $::GIT_DIR]} {
        set clawhub_skills {}
        foreach d [glob -nocomplain -directory $::CLAWHUB_DIR -types d *] {
            lappend clawhub_skills [file tail $d]
        }
        
        set git_skills {}
        foreach d [glob -nocomplain -directory $::GIT_DIR -types d *] {
            lappend git_skills [file tail $d]
        }
        
        set common_skills [lsort [struct::set intersect $clawhub_skills $git_skills]]
    }
    
    puts "Prüfe [llength $common_skills] Skills auf Konflikte...\n"
    
    foreach skill $common_skills {
        set clawhub_path [file join $::CLAWHUB_DIR $skill]
        set git_path [file join $::GIT_DIR $skill]
        
        # Alle Dateien vergleichen
        set skill_conflicts {}
        
        # ClawHub Dateien
        set clawhub_files {}
        foreach f [fileutil::find $clawhub_path {file isfile}] {
            if {[string first ".git" $f] == -1} {
                set rel_path [fileutil::stripPath $clawhub_path $f]
                dict set clawhub_files $rel_path $f
            }
        }
        
        # Git Dateien
        set git_files {}
        foreach f [fileutil::find $git_path {file isfile}] {
            if {[string first ".git" $f] == -1} {
                set rel_path [fileutil::stripPath $git_path $f]
                dict set git_files $rel_path $f
            }
        }
        
        # Vergleiche gemeinsame Dateien
        set common_files [struct::set intersect [dict keys $clawhub_files] [dict keys $git_files]]
        foreach rel_path $common_files {
            set clawhub_file [dict get $clawhub_files $rel_path]
            set git_file [dict get $git_files $rel_path]
            
            if {[get_file_hash $clawhub_file] ne [get_file_hash $git_file]} {
                set clawhub_mtime [clock format [file mtime $clawhub_file] -format "%Y-%m-%d %H:%M:%S"]
                set git_mtime [clock format [file mtime $git_file] -format "%Y-%m-%d %H:%M:%S"]
                
                if {[file mtime $clawhub_file] > [file mtime $git_file]} {
                    set newer "clawhub"
                } else {
                    set newer "git"
                }
                
                lappend skill_conflicts [dict create \
                    file $rel_path \
                    clawhub_modified $clawhub_mtime \
                    git_modified $git_mtime \
                    newer $newer \
                ]
            }
        }
        
        if {[llength $skill_conflicts] > 0} {
            lappend conflicts [dict create \
                skill $skill \
                conflicts $skill_conflicts \
            ]
        }
    }
    
    # Ausgabe
    if {[llength $conflicts] > 0} {
        puts "⚠️  KONFLIKTE GEFUNDEN:"
        puts [string repeat "=" 80]
        
        foreach conflict $conflicts {
            puts "\n📦 Skill: [dict get $conflict skill]"
            puts [string repeat "-" 40]
            
            foreach file_conflict [dict get $conflict conflicts] {
                puts "  📄 [dict get $file_conflict file]"
                puts "     ClawHub: [dict get $file_conflict clawhub_modified]"
                puts "     Git:     [dict get $file_conflict git_modified]"
                puts "     Neuer:   [string toupper [dict get $file_conflict newer]]"
                puts ""
            }
        }
        
        puts [string repeat "=" 80]
        puts "Gesamt: [llength $conflicts] Skills mit Konflikten"
        puts "\nNutze 'sync_utils/scripts/resolve_conflict.tcl' zum Auflösen."
    } else {
        puts "✅ Keine Konflikte gefunden!"
        puts "Alle gemeinsamen Skills sind synchron."
    }
}

proc main {} {
    # Hauptfunktion
    check_conflicts
}

if {$argv0 eq [info script]} {
    main
}
