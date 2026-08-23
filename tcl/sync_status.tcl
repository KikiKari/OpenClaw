#!/usr/bin/env tclsh8.6
# sync_status.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Sync Status - Zeigt Status aller Skills

package require json

# Konfiguration
set CLAWHUB_DIR "/home/openclaw/.openclaw/workspace/skills"
set GIT_DIR "/home/openclaw/.openclaw/workspace/git/skills"
set STATE_FILE "/home/openclaw/.openclaw/workspace/db/sync_state.json"

# Hilfsfunktion zur Berechnung des maximalen mtime eines Verzeichnisses
proc get_max_mtime {path exclude_pattern} {
    set max_time 0
    catch {
        set files [glob -nocomplain -directory $path -types f {*}]
        foreach file $files {
            if {![string match $exclude_pattern $file]} {
                set mtime [file mtime $file]
                if {$mtime > $max_time} {
                    set max_time $mtime
                }
            }
        }
        set dirs [glob -nocomplain -directory $path -types d {*}]
        foreach dir $dirs {
            set sub_max [get_max_mtime $dir $exclude_pattern]
            if {$sub_max > $max_time} {
                set max_time $sub_max
            }
        }
    }
    return $max_time
}

# Prüft Status eines Skills
proc check_skill_status {skill_name} {
    global CLAWHUB_DIR GIT_DIR
    
    set clawhub_path [file join $CLAWHUB_DIR $skill_name]
    set git_path [file join $GIT_DIR $skill_name]
    
    set status [dict create \
        name $skill_name \
        in_clawhub [file isdirectory $clawhub_path] \
        in_git [file isdirectory $git_path] \
        has_git_repo [file isdirectory [file join $git_path .git]] \
        status "unknown" \
        last_modified [dict create] \
    ]
    
    # Status bestimmen
    if {[dict get $status in_clawhub] && ![dict get $status in_git]} {
        dict set status status "only_clawhub"
    } elseif {[dict get $status in_git] && ![dict get $status in_clawhub]} {
        dict set status status "only_git"
    } elseif {[dict get $status in_clawhub] && [dict get $status in_git]} {
        # Timestamps vergleichen
        if {[catch {
            set clawhub_mtime [get_max_mtime $clawhub_path ""]
            set git_mtime [get_max_mtime $git_path "*/.git*"]
            
            dict set status last_modified clawhub [clock format $clawhub_mtime -format "%Y-%m-%d %H:%M:%S"]
            dict set status last_modified git [clock format $git_mtime -format "%Y-%m-%d %H:%M:%S"]
            
            if {abs($clawhub_mtime - $git_mtime) < 60} {
                dict set status status "synced"
            } elseif {$clawhub_mtime > $git_mtime} {
                dict set status status "clawhub_newer"
            } else {
                dict set status status "git_newer"
            }
        } err]} {
            dict set status status "error"
        }
    }
    
    return $status
}

# Hauptfunktion
proc main {} {
    global CLAWHUB_DIR GIT_DIR STATE_FILE
    
    puts [string repeat "=" 80]
    puts "ClawHub ↔ Git Sync Status"
    puts [string repeat "=" 80]
    puts "Zeitpunkt: [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
    puts ""
    
    # Alle Skills finden
    set all_skills [dict create]
    
    if {[file isdirectory $CLAWHUB_DIR]} {
        foreach item [glob -nocomplain -directory $CLAWHUB_DIR *] {
            if {[file isdirectory $item] && ![string match .* [file tail $item]]} {
                dict set all_skills [file tail $item] 1
            }
        }
    }
    
    if {[file isdirectory $GIT_DIR]} {
        foreach item [glob -nocomplain -directory $GIT_DIR *] {
            if {[file isdirectory $item] && ![string match .* [file tail $item]]} {
                dict set all_skills [file tail $item] 1
            }
        }
    }
    
    # Status-Kategorien
    set categories [dict create \
        synced [list] \
        clawhub_newer [list] \
        git_newer [list] \
        only_clawhub [list] \
        only_git [list] \
        error [list] \
    ]
    
    # Status für jeden Skill prüfen
    foreach skill [lsort [dict keys $all_skills]] {
        set status [check_skill_status $skill]
        set cat [dict get $status status]
        dict set categories $cat [concat [dict get $categories $cat] [list $status]]
    }
    
    # Ausgabe
    set total_count [llength [dict keys $all_skills]]
    puts "📊 Gesamt: $total_count Skills\n"
    
    # Synchronisiert
    set synced_list [dict get $categories synced]
    if {[llength $synced_list] > 0} {
        puts "✅ Synchronisiert ([llength $synced_list])"
        foreach s $synced_list {
            puts "   - [dict get $s name]"
        }
        puts ""
    }
    
    # ClawHub neuer
    set clawhub_newer_list [dict get $categories clawhub_newer]
    if {[llength $clawhub_newer_list] > 0} {
        puts "🔄 ClawHub neuer ([llength $clawhub_newer_list])"
        foreach s $clawhub_newer_list {
            set name [dict get $s name]
            set time [dict get $s last_modified clawhub]
            puts "   - $name (ClawHub: $time)"
        }
        puts ""
    }
    
    # Git neuer
    set git_newer_list [dict get $categories git_newer]
    if {[llength $git_newer_list] > 0} {
        puts "🔄 Git neuer ([llength $git_newer_list])"
        foreach s $git_newer_list {
            set name [dict get $s name]
            set time [dict get $s last_modified git]
            puts "   - $name (Git: $time)"
        }
        puts ""
    }
    
    # Nur in ClawHub
    set only_clawhub_list [dict get $categories only_clawhub]
    if {[llength $only_clawhub_list] > 0} {
        puts "📦 Nur in ClawHub ([llength $only_clawhub_list])"
        foreach s $only_clawhub_list {
            puts "   - [dict get $s name]"
        }
        puts ""
    }
    
    # Nur in Git
    set only_git_list [dict get $categories only_git]
    if {[llength $only_git_list] > 0} {
        puts "📁 Nur in Git ([llength $only_git_list])"
        foreach s $only_git_list {
            puts "   - [dict get $s name]"
        }
        puts ""
    }
    
    # Fehler
    set error_list [dict get $categories error]
    if {[llength $error_list] > 0} {
        puts "❌ Fehler ([llength $error_list])"
        foreach s $error_list {
            puts "   - [dict get $s name]"
        }
        puts ""
    }
    
    # State-File Info
    if {[file exists $STATE_FILE]} {
        if {[catch {set fp [open $STATE_FILE r]}]} {
            puts "Fehler beim Öffnen der State-Datei"
        } else {
            if {[catch {
                set content [read $fp]
                close $fp
                set state [::json::json2dict $content]
                if {[dict exists $state last_sync]} {
                    set last_sync_dict [dict get $state last_sync]
                    set last_runs [lsort [dict keys $last_sync_dict]]
                    if {[llength $last_runs] > 0} {
                        set last_run [lindex $last_runs end]
                        puts "📅 Letzter automatischer Sync: $last_run"
                    }
                }
            } err]} {
                if {[info exists fp]} {close $fp}
                puts "Fehler beim Lesen der State-Datei: $err"
            }
        }
    }
    
    puts [string repeat "=" 80]
}

# Skript ausführen
main
