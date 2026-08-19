#!/usr/bin/env tclsh
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

package require sqlite3
package require sha256
package require json
package require fileutil

# Set workspace directory
set WORKSPACE [expr {[info exists ::env(OPENCLAW_WORKSPACE)] ? $::env(OPENCLAW_WORKSPACE) : [file dirname [file dirname [info script]]]}]
set DB_DIR $WORKSPACE
set BACKUP_DIR [file join $WORKSPACE "db" "backups"]
set LOG_DIR [file join $WORKSPACE "logs" "db-maintainer"]
set IMPORTANT_DIR [file join $WORKSPACE "important"]

# Create directories
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR
file mkdir $IMPORTANT_DIR

# Logger class
proc Logger_new {} {
    variable log_file
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set log_file [file join $::LOG_DIR "${today}.log"]
    
    return ""
}

proc Logger_log {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set line "\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] \[$level\] $message"
    puts $line
    set fh [open $::Logger::log_file a]
    puts $fh $line
    close $fh
}

proc Logger_info {msg} { Logger_log "INFO" $msg }
proc Logger_warn {msg} { Logger_log "WARN" $msg }
proc Logger_error {msg} { Logger_log "ERROR" $msg }

# DatabaseMaintainer class
namespace eval DatabaseMaintainer {
    variable logger
    variable state_file
    variable retention_days 3
    
    proc new {} {
        set logger [Logger_new]
        set state_file [file join $::DB_DIR "maintainer_state.json"]
    }
    
    proc load_state {} {
        if {[file exists $state_file]} {
            set fh [open $state_file r]
            set data [read $fh]
            close $fh
            if {[catch {json::json2dict $data} result]} {
                return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
            } else {
                return $result
            }
        }
        return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
    }
    
    proc save_state {state} {
        set fh [open $state_file w]
        puts $fh [json::dict2json $state]
        close $fh
    }
    
    proc get_file_hash {filepath} {
        if {[catch {open $filepath r} fh]} {
            return ""
        }
        set content [read $fh]
        close $fh
        return [sha256::sha256 -hex $content]
    }
    
    proc _python_tree_fallback {{max_depth 8}} {
        set root $::WORKSPACE
        set lines [list $root]
        
        proc walk {dirpath prefix depth max_depth} {
            upvar lines lines
            if {$depth > $max_depth} {
                return
            }
            if {[catch {glob -nocomplain -dir $dirpath *} entries]} {
                return
            }
            set entries [lsort -dictionary $entries]
            set len [llength $entries]
            for {set i 0} {$i < $len} {incr i} {
                set entry [lindex $entries $i]
                set name [file tail $entry]
                set connector [expr {$i == $len - 1 ? "└── " : "├── "}]
                lappend lines "${prefix}${connector}${name}"
                if {[file isdirectory $entry] && ![file type $entry eq "link"]} {
                    set extension [expr {$i == $len - 1 ? "    " : "│   "}]
                    walk $entry "${prefix}${extension}" [expr {$depth + 1}] $max_depth
                }
            }
        }
        
        walk $root "" 1 $max_depth
        return "[join $lines \n]\n"
    }
    
    proc run_tree_command {} {
        if {[catch {exec tree -a -L 8 $::WORKSPACE} result]} {
            Logger_warn "tree-Binary nicht installiert – nutze Python-Fallback"
            return [_python_tree_fallback]
        } else {
            Logger_info "tree -a -L 8 erfolgreich ausgeführt"
            return $result
        }
    }
    
    proc update_tree_file {tree_output} {
        if {![string length $tree_output]} {
            return 0
        }
        
        set tree_file [file join $::IMPORTANT_DIR "openclaw-tree.txt"]
        set header "# OpenClaw Workspace Tree\n# Generiert: [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]\n# Befehl: tree -a -L 8 $::WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
        
        if {[catch {set fh [open $tree_file w]}]} {
            Logger_error "Fehler beim Öffnen von openclaw-tree.txt"
            return 0
        }
        puts -nonewline $fh $header
        puts -nonewline $fh $tree_output
        close $fh
        Logger_info "openclaw-tree.txt aktualisiert: $tree_file"
        return 1
    }
    
    proc scan_documentations {} {
        set docs [list]
        foreach pattern {"*.md" "**/*.md"} {
            foreach md_file [glob -nocomplain -dir $::WORKSPACE $pattern] {
                if {[file isfile $md_file] && ![file type $md_file eq "link"]} {
                    set rel_path [string range $md_file [string length $::WORKSPACE]+1 end]
                    if {![string match "*db/backups*" $rel_path] && ![string match "*node_modules*" $rel_path]} {
                        lappend docs [dict create \
                            path $rel_path \
                            hash [get_file_hash $md_file] \
                            mtime [file mtime $md_file]]
                    }
                }
            }
        }
        return $docs
    }
    
    proc check_for_changes {} {
        set state [load_state]
        set current_docs [scan_documentations]
        set changes [list]
        set current_hashes [dict create]
        
        foreach doc $current_docs {
            set path [dict get $doc path]
            set hash [dict get $doc hash]
            dict set current_hashes $path $hash
            
            if {![dict exists [dict get $state file_hashes] $path]} {
                lappend changes "NEW: $path"
            } elseif {[dict get [dict get $state file_hashes] $path] ne $hash} {
                lappend changes "CHANGED: $path"
            }
        }
        
        # Prüfe auf gelöschte Dateien
        dict for {old_path old_hash} [dict get $state file_hashes] {
            if {![dict exists $current_hashes $old_path]} {
                lappend changes "DELETED: $old_path"
            }
        }
        
        return [list $changes $current_hashes]
    }
    
    proc update_databases {} {
        if {[catch {exec python3 [file join $::WORKSPACE scripts update_docs_db.py]} result]} {
            Logger_error "DB-Update Exception: $result"
            return 0
        } else {
            Logger_info "docs.db aktualisiert"
            return 1
        }
    }
    
    proc update_tree_db_v2 {} {
        if {[catch {exec python3 [file join $::WORKSPACE scripts tree_indexer_v2.py]} result]} {
            Logger_error "Tree-DB v2 Exception: $result"
            return 0
        } else {
            Logger_info "tree.db v2 aktualisiert"
            return 1
        }
    }
    
    proc create_backup {} {
        set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H-%M"]
        
        foreach db_name {"docs.db" "tree.db"} {
            set source [file join $::DB_DIR $db_name]
            if {[file exists $source]} {
                set backup_name "${timestamp}_${db_name}.bak"
                set backup_path [file join $::BACKUP_DIR $backup_name]
                file copy -force $source $backup_path
                Logger_info "Backup erstellt: $backup_name"
            }
        }
        
        return $timestamp
    }
    
    proc cleanup_old_backups {} {
        set cutoff [clock add [clock seconds] -3 days]
        set deleted 0
        
        foreach db_name {"docs.db" "tree.db"} {
            set pattern "*_${db_name}.bak"
            foreach backup [glob -nocomplain -dir $::BACKUP_DIR $pattern] {
                set basename [file tail $backup]
                if {[regexp {^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_} $basename match date_part time_part]} {
                    if {[catch {clock scan "$date_part $time_part" -format "%Y-%m-%d %H-%M"} backup_time]} {
                        Logger_warn "Konnte Backup-Datum nicht parsen: $basename"
                        continue
                    }
                    
                    if {$backup_time < $cutoff} {
                        file delete $backup
                        incr deleted
                        Logger_info "Altes Backup gelöscht: $basename"
                    }
                } else {
                    Logger_warn "Konnte Backup-Datum nicht parsen: $basename"
                }
            }
        }
        
        if {$deleted == 0} {
            Logger_info "Keine alten Backups zum Löschen"
        } else {
            Logger_info "$deleted alte Backups gelöscht (< 3 Tage)"
        }
    }
    
    proc run_cycle {} {
        Logger_info [string repeat "=" 60]
        Logger_info "DB MAINTAINER CYCLE START"
        Logger_info [string repeat "=" 60]
        
        set state [load_state]
        
        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        Logger_info "Führe tree -a -L 8 aus..."
        set tree_output [run_tree_command]
        if {[string length $tree_output]} {
            update_tree_file $tree_output
            dict set state last_tree_update [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        }
        
        # 2. tree.db aktualisieren (intern v2)
        Logger_info "Aktualisiere tree.db v2..."
        update_tree_db_v2
        
        # 3. Änderungen prüfen
        Logger_info "Prüfe auf Dokumentations-Änderungen..."
        lassign [check_for_changes] changes current_hashes
        
        if {[llength $changes]} {
            Logger_info "[llength $changes] Änderungen gefunden:"
            set count 0
            foreach change [lrange $changes 0 9] {
                Logger_info "  - $change"
                incr count
            }
            if {[llength $changes] > 10} {
                Logger_info "  ... und [expr {[llength $changes] - 10}] weitere"
            }
            
            # 4. docs.db aktualisieren
            Logger_info "Aktualisiere docs.db..."
            if {[update_databases]} {
                dict set state last_check [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
                dict set state file_hashes $current_hashes
            }
        } else {
            Logger_info "Keine Dokumentations-Änderungen gefunden"
        }
        
        # 5. Prüfe ob Backup fällig (stündlich)
        set last_backup [dict get $state last_backup]
        set do_backup 0
        
        if {$last_backup ne ""} {
            if {[catch {clock scan $last_backup -format "%Y-%m-%dT%H:%M:%S"} last_backup_time]} {
                set do_backup 1
            } else {
                set diff [expr {[clock seconds] - $last_backup_time}]
                set do_backup [expr {$diff >= 3600}] ;# 1 hour in seconds
            }
        } else {
            set do_backup 1
        }
        
        if {$do_backup} {
            Logger_info "Erstelle stündliches Backup..."
            set timestamp [create_backup]
            dict set state last_backup [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
            
            # 6. Alte Backups aufräumen (3 Tage Retention)
            Logger_info "Räume alte Backups auf (3 Tage Retention)..."
            cleanup_old_backups
        } else {
            Logger_info "Backup nicht nötig (letztes < 1h)"
        }
        
        save_state $state
        
        Logger_info [string repeat "=" 60]
        Logger_info "DB MAINTAINER CYCLE END"
        Logger_info [string repeat "=" 60]
    }
}

proc main {} {
    DatabaseMaintainer::new
    if {[catch {DatabaseMaintainer::run_cycle} error]} {
        Logger_error "CRITICAL ERROR: $error"
        exit 1
    }
}

if {[info script] eq $argv0} {
    main
}
