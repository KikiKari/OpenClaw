#!/usr/bin/env tclsh8.6
# db_maintainer_run.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer_run.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

package require Tcl 8.6
package require sqlite3

set WORKSPACE "/workspace"
set DB_DIR "$WORKSPACE/db"
set BACKUP_DIR "$DB_DIR/backups"
set LOG_DIR "$WORKSPACE/logs/db-maintainer"
set IMPORTANT_DIR "$WORKSPACE/important"

# Verzeichnisse erstellen
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR


# Einfacher Logger mit Datei-Ausgabe
proc init_logger {} {
    global LOG_DIR
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set log_file "$LOG_DIR/$today.log"
    return $log_file
}

proc log_message {level message} {
    global logger_fd
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set line "\[$timestamp\] \[$level\] $message"
    puts $line
    if {[info exists logger_fd]} {
        puts $logger_fd $line
        flush $logger_fd
    }
}

proc log_info {msg} { log_message "INFO" $msg }
proc log_warn {msg} { log_message "WARN" $msg }
proc log_error {msg} { log_message "ERROR" $msg }


# Klasse für den Database Maintainer
namespace eval DatabaseMaintainer {
    variable state_file "$::DB_DIR/maintainer_state.json"
    variable retention_days 3
    variable logger_fd ""
    
    proc init {} {
        variable logger_fd
        set logger_file [init_logger]
        if {[catch {open $logger_file a} fd]} {
            puts "Cannot open log file: $fd"
            exit 1
        }
        set logger_fd $fd
    }
    
    proc close_logger {} {
        variable logger_fd
        if {[info exists logger_fd] && $logger_fd ne ""} {
            close $logger_fd
        }
    }
    
    proc load_state {} {
        variable state_file
        if {[file exists $state_file]} {
            if {[catch {open $state_file r} fd]} {
                log_error "Cannot read state file: $fd"
                return [dict create last_check {} last_backup {} last_tree_update {} file_hashes {}]
            }
            set content [read $fd]
            close $fd
            
            if {[catch {::json::json2dict $content} data]} {
                log_error "Cannot parse state JSON: $data"
                return [dict create last_check {} last_backup {} last_tree_update {} file_hashes {}]
            }
            return $data
        }
        return [dict create last_check {} last_backup {} last_tree_update {} file_hashes {}]
    }
    
    proc save_state {state} {
        variable state_file
        if {[catch {open $state_file w} fd]} {
            log_error "Cannot write state file: $fd"
            return
        }
        set json_data [::json::dict2json $state]
        puts $fd $json_data
        close $fd
    }
    
    proc get_file_hash {filepath} {
        if {![file readable $filepath]} {
            return ""
        }
        
        if {[catch {open $filepath rb} fd]} {
            return ""
        }
        
        set md5 [md5::md5 -hex -channel $fd]
        close $fd
        return $md5
    }
    
    proc run_tree_command {} {
        global WORKSPACE
        set cmd [list exec tree -a -L 6 $WORKSPACE]
        
        if {[catch {eval $cmd} result]} {
            log_error "tree command failed: $result"
            return ""
        }
        
        log_info "tree -a -L 6 erfolgreich ausgeführt"
        return $result
    }
    
    proc update_tree_file {tree_output} {
        global IMPORTANT_DIR
        if {$tree_output eq ""} {
            return 0
        }
        
        set tree_file "$IMPORTANT_DIR/openclaw-tree.txt"
        set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        
        set header "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 6 $WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
        
        if {[catch {open $tree_file w} fd]} {
            log_error "Fehler beim Öffnen von openclaw-tree.txt: $fd"
            return 0
        }
        
        puts -nonewline $fd $header
        puts -nonewline $fd $tree_output
        close $fd
        
        log_info "openclaw-tree.txt aktualisiert: $tree_file"
        return 1
    }
    
    proc scan_documentations {} {
        global WORKSPACE
        set docs {}
        
        # Find all .md files recursively, excluding some paths
        set cmd [list find $WORKSPACE -type f -name "*.md"]
        if {[catch {eval $cmd} files]} {
            log_error "Error finding .md files: $files"
            return $docs
        }
        
        foreach filepath [split $files "\n"] {
            if {$filepath eq ""} continue
            
            # Skip excluded directories
            if {[string match "*db/backups*" $filepath] || 
                [string match "*node_modules*" $filepath]} {
                continue
            }
            
            if {[file isfile $filepath] && ![file islink $filepath]} {
                set relpath [string range $filepath [string length $WORKSPACE]+1 end]
                set hash [get_file_hash $filepath]
                set mtime [file mtime $filepath]
                
                lappend docs [dict create path $relpath hash $hash mtime $mtime]
            }
        }
        
        return $docs
    }
    
    proc check_for_changes {} {
        set state [load_state]
        set current_docs [scan_documentations]
        
        set changes {}
        set current_hashes {}
        
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
        if {[dict exists $state file_hashes]} {
            foreach old_path [dict keys [dict get $state file_hashes]] {
                if {![dict exists $current_hashes $old_path]} {
                    lappend changes "DELETED: $old_path"
                }
            }
        }
        
        return [list $changes $current_hashes]
    }
    
    proc update_databases {} {
        global WORKSPACE
        set script "$WORKSPACE/scripts/update_docs_db.py"
        
        if {![file exists $script]} {
            log_error "Update script not found: $script"
            return 0
        }
        
        set cmd [list exec python3 $script]
        if {[catch {eval $cmd} result options]} {
            log_error "DB-Update Exception: $result"
            return 0
        }
        
        log_info "docs.db aktualisiert"
        return 1
    }
    
    proc update_tree_db_v2 {} {
        global WORKSPACE
        set script "$WORKSPACE/scripts/tree_indexer_v2.py"
        
        if {![file exists $script]} {
            log_error "Tree indexer script not found: $script"
            return 0
        }
        
        set cmd [list exec python3 $script]
        if {[catch {eval $cmd} result options]} {
            log_error "Tree-DB v2 Exception: $result"
            return 0
        }
        
        log_info "tree.db v2 aktualisiert"
        return 1
    }
    
    proc create_backup {} {
        global DB_DIR BACKUP_DIR
        set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H-%M"]
        
        foreach db_name [list "docs.db" "tree.db"] {
            set source "$DB_DIR/$db_name"
            if {[file exists $source]} {
                set backup_name "${timestamp}_${db_name}.bak"
                set backup_path "$BACKUP_DIR/$backup_name"
                
                if {[catch {file copy -force $source $backup_path} err]} {
                    log_error "Failed to create backup $backup_name: $err"
                } else {
                    log_info "Backup erstellt: $backup_name"
                }
            }
        }
        
        return $timestamp
    }
    
    proc cleanup_old_backups {} {
        variable retention_days
        global BACKUP_DIR
        
        set cutoff [expr {[clock seconds] - ($retention_days * 24 * 60 * 60)}]
        set deleted 0
        
        foreach db_name [list "docs.db" "tree.db"] {
            set pattern "*_${db_name}.bak"
            foreach backup [glob -nocomplain -directory $BACKUP_DIR $pattern] {
                # Extrahiere Datum aus Filename (Format: YYYY-MM-DD_HH-MM)
                set basename [file tail $backup]
                if {[regexp {^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_} $basename match date_part time_part]} {
                    if {[catch {
                        set backup_time [clock scan "$date_part $time_part" -format "%Y-%m-%d %H-%M"]
                        if {$backup_time < $cutoff} {
                            file delete $backup
                            incr deleted
                            log_info "Altes Backup gelöscht: $basename"
                        }
                    } err]} {
                        log_warn "Konnte Backup-Datum nicht parsen: $basename"
                    }
                } else {
                    log_warn "Ungültiges Backup-Dateiname-Format: $basename"
                }
            }
        }
        
        if {$deleted == 0} {
            log_info "Keine alten Backups zum Löschen"
        } else {
            log_info "$deleted alte Backups gelöscht (< 3 Tage)"
        }
    }
    
    proc run_cycle {} {
        log_info "============================================================"
        log_info "DB MAINTAINER CYCLE START"
        log_info "============================================================"
        
        set state [load_state]
        
        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        log_info "Führe tree -a -L 8 aus..."
        set tree_output [run_tree_command]
        if {$tree_output ne ""} {
            update_tree_file $tree_output
            dict set state last_tree_update [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        }
        
        # 2. tree.db aktualisieren (intern v2)
        log_info "Aktualisiere tree.db v2..."
        update_tree_db_v2
        
        # 3. Änderungen prüfen
        log_info "Prüfe auf Dokumentations-Änderungen..."
        foreach {changes current_hashes} [check_for_changes] break
        
        if {[llength $changes] > 0} {
            log_info "[llength $changes] Änderungen gefunden:"
            set count 0
            foreach change [lrange $changes 0 9] {
                log_info "  - $change"
                incr count
            }
            if {[llength $changes] > 10} {
                set remaining [expr {[llength $changes] - 10}]
                log_info "  ... und $remaining weitere"
            }
            
            # 4. docs.db aktualisieren
            log_info "Aktualisiere docs.db..."
            if {[update_databases]} {
                dict set state last_check [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
                dict set state file_hashes $current_hashes
            }
        } else {
            log_info "Keine Dokumentations-Änderungen gefunden"
        }
        
        # 5. Prüfe ob Backup fällig (stündlich)
        set last_backup [dict get $state last_backup]
        set do_backup 1
        
        if {$last_backup ne ""} {
            if {[catch {
                set last_backup_time [clock scan $last_backup -format "%Y-%m-%dT%H:%M:%S"]
                set diff [expr {[clock seconds] - $last_backup_time}]
                set do_backup [expr {$diff >= 3600}] ;# 1 hour in seconds
            } err]} {
                # If parsing fails, force backup
                log_warn "Could not parse last backup time, forcing backup"
            }
        }
        
        if {$do_backup} {
            log_info "Erstelle stündliches Backup..."
            set timestamp [create_backup]
            dict set state last_backup [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
            
            # 6. Alte Backups aufräumen (3 Tage Retention)
            log_info "Räume alte Backups auf (3 Tage Retention)..."
            cleanup_old_backups
        } else {
            log_info "Backup nicht nötig (letztes < 1h)"
        }
        
        save_state $state
        
        log_info "============================================================"
        log_info "DB MAINTAINER CYCLE END"
        log_info "============================================================"
    }
}


proc main {} {
    DatabaseMaintainer::init
    
    if {[catch {
        DatabaseMaintainer::run_cycle
    } err]} {
        log_error "CRITICAL ERROR: $err"
        DatabaseMaintainer::close_logger
        exit 1
    }
    
    DatabaseMaintainer::close_logger
}


# Load required packages
if {[catch {package require json}]} {
    # Fallback implementation for basic JSON handling
    namespace eval json {
        proc json2dict {json} {
            # Very basic JSON parser - only handles simple objects
            regsub -all {^\s*\{\s*|\s*\}\s*$} $json "" content
            set result [dict create]
            
            # Split by commas but respect nesting
            set parts {}
            set current ""
            set brace_count 0
            set in_string 0
            
            for {set i 0} {$i < [string length $content]} {incr i} {
                set char [string index $content $i]
                if {$char eq "\"" && ($i == 0 || [string index $content [expr {$i-1}]] ne "\\" )} {
                    set in_string [expr {!$in_string}]
                }
                
                if {!$in_string} {
                    if {$char eq "{"} {
                        incr brace_count
                    } elseif {$char eq "}"} {
                        incr brace_count -1
                    } elseif {$char eq "," && $brace_count == 0} {
                        lappend parts $current
                        set current ""
                        continue
                    }
                }
                append current $char
            }
            if {$current ne ""} {
                lappend parts $current
            }
            
            foreach part $parts {
                if {[regexp {^\s*"([^"]+)"\s*:\s*(.*)$} $part match key value]} {
                    # Remove quotes from string values
                    if {[regexp {^\s*"(.*)"\s*$} $value match str_val]} {
                        dict set result $key $str_val
                    } else {
                        dict set result $key $value
                    }
                }
            }
            return $result
        }
        
        proc dict2json {dict_val} {
            set parts {}
            foreach {key value} $dict_val {
                if {[string is double $value] || $value eq "true" || $value eq "false" || $value eq "null"} {
                    lappend parts "\"$key\":$value"
                } else {
                    lappend parts "\"$key\":\"$value\""
                }
            }
            return "\{[join $parts ,]\}"
        }
    }
}

# Run main function
main
