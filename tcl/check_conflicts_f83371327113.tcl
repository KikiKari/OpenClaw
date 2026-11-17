#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "9a1fde6e8341657320a05d189c5942d0b5b5756eb3f8e95917ffe9ceaf8ff60e", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "tcl"}
# check_conflicts.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Check Conflicts - Erkennt Sync-Konflikte

# Import sync functions
lappend auto_path /home/openclaw/.openclaw/workspace/scripts
package require sha256

set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"

proc get_file_hash {filename} {
    if {[catch {open $filename r} fh]} {
        return ""
    }
    set content [read $fh]
    close $fh
    return [sha256::sha256 -bin $content]
}

proc get_directories {path} {
    set dirs {}
    if {[file isdirectory $path]} {
        foreach item [glob -nocomplain -directory $path *] {
            if {[file isdirectory $item] && [file tail $item] ne ".git"} {
                lappend dirs [file tail $item]
            }
        }
    }
    return $dirs
}

proc get_all_files {base_path} {
    set files_dict [dict create]
    proc scan_recursive {current_path base_path} {
        upvar files_dict files_dict
        if {[file isdirectory $current_path]} {
            foreach item [glob -nocomplain -directory $current_path *] {
                if {[file isdirectory $item]} {
                    if {[file tail $item] ne ".git"} {
                        scan_recursive $item $base_path
                    }
                } elseif {[file isfile $item]} {
                    set rel_path [string range $item [string length $base_path] end]
                    if {[string index $rel_path 0] eq "/"} {
                        set rel_path [string range $rel_path 1 end]
                    }
                    dict set files_dict $rel_path $item
                }
            }
        }
    }
    scan_recursive $base_path $base_path
    return $files_dict
}

proc get_mtime {filepath} {
    return [clock format [file mtime $filepath] -format "%Y-%m-%d %H:%M:%S"]
}

proc check_conflicts {} {
    global CLAWHUB_DIR GIT_DIR
    
    # Prüft auf Konflikte zwischen ClawHub und Git
    set conflicts {}
    
    # Alle Skills die in beiden Orten existieren
    set common_skills {}
    if {[file isdirectory $CLAWHUB_DIR] && [file isdirectory $GIT_DIR]} {
        set clawhub_skills [get_directories $CLAWHUB_DIR]
        set git_skills [get_directories $GIT_DIR]
        
        foreach skill $clawhub_skills {
            if {$skill in $git_skills} {
                lappend common_skills $skill
            }
        }
    }
    
    puts "Prüfe [llength $common_skills] Skills auf Konflikte...\n"
    
    foreach skill [lsort $common_skills] {
        set clawhub_path [file join $CLAWHUB_DIR $skill]
        set git_path [file join $GIT_DIR $skill]
        
        # Alle Dateien vergleichen
        set skill_conflicts {}
        
        # ClawHub Dateien
        set clawhub_files [get_all_files $clawhub_path]
        
        # Git Dateien
        set git_files [get_all_files $git_path]
        
        # Vergleiche gemeinsame Dateien
        set common_files {}
        foreach rel_path [dict keys $clawhub_files] {
            if {[dict exists $git_files $rel_path]} {
                lappend common_files $rel_path
            }
        }
        
        foreach rel_path $common_files {
            set clawhub_file [dict get $clawhub_files $rel_path]
            set git_file [dict get $git_files $rel_path]
            
            if {[get_file_hash $clawhub_file] ne [get_file_hash $git_file]} {
                set clawhub_mtime [get_mtime $clawhub_file]
                set git_mtime [get_mtime $git_file]
                
                set newer "git"
                if {[file mtime $clawhub_file] > [file mtime $git_file]} {
                    set newer "clawhub"
                }
                
                lappend skill_conflicts [dict create \
                    file $rel_path \
                    clawhub_modified $clawhub_mtime \
                    git_modified $git_mtime \
                    newer $newer]
            }
        }
        
        if {[llength $skill_conflicts] > 0} {
            lappend conflicts [dict create skill $skill conflicts $skill_conflicts]
        }
    }
    
    # Ausgabe
    if {[llength $conflicts] > 0} {
        puts "⚠️  KONFLIKTE GEFUNDEN:"
        puts [string repeat "=" 80]
        
        foreach conflict $conflicts {
            set skill_name [dict get $conflict skill]
            puts "\n📦 Skill: $skill_name"
            puts [string repeat "-" 40]
            
            set file_conflicts [dict get $conflict conflicts]
            foreach file_conflict $file_conflicts {
                set filename [dict get $file_conflict file]
                set clawhub_time [dict get $file_conflict clawhub_modified]
                set git_time [dict get $file_conflict git_modified]
                set newer [dict get $file_conflict newer]
                
                puts "  📄 $filename"
                puts "     ClawHub: $clawhub_time"
                puts "     Git:     $git_time"
                puts "     Neuer:   [string toupper $newer]"
                puts ""
            }
        }
        
        puts [string repeat "=" 80]
        puts "Gesamt: [llength $conflicts] Skills mit Konflikten"
        puts "\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen."
    } else {
        puts "✅ Keine Konflikte gefunden!"
        puts "Alle gemeinsamen Skills sind synchron."
    }
}

proc main {} {
    # Hauptfunktion
    check_conflicts
}

if {[info script] eq $argv0} {
    main
}
