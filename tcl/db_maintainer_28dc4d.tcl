#!/usr/bin/env tclsh8.6
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

package require sqlite3
package require fileutil
package require json

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_DIR "$WORKSPACE/db"
set BACKUP_DIR "$DB_DIR/backups"
set LOG_DIR "$WORKSPACE/logs/db-maintainer"
set IMPORTANT_DIR "$WORKSPACE/important"

# Verzeichnisse erstellen
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR

# Logger Klasse
proc Logger_new {} {
    variable log_file
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set log_file "$::LOG_DIR/$today.log"
    
    return ""
}

proc Logger_log {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set line "\[$timestamp\] \[$level\] $message"
    puts $line
    set fh [open $::Logger::log_file a]
    puts $fh $line
    close $fh
}

proc Logger_info {msg} { Logger_log "INFO" $msg }
proc Logger_warn {msg} { Logger_log "WARN" $msg }
proc Logger_error {msg} { Logger_log "ERROR" $msg }

# DatabaseMaintainer Klasse
namespace eval DatabaseMaintainer {
    variable logger
    variable state_file "$::DB_DIR/maintainer_state.json"
    variable retention_days 3
}

proc DatabaseMaintainer_new {} {
    set ::DatabaseMaintainer::logger [Logger_new]
    return ""
}

proc DatabaseMaintainer_load_state {} {
    if {[file exists $::DatabaseMaintainer::state_file]} {
        set fh [open $::DatabaseMaintainer::state_file r]
        set content [read $fh]
        close $fh
        if {$content eq ""} {
            return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
        }
        return [::json::json2dict $content]
    }
    return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
}

proc DatabaseMaintainer_save_state {state} {
    set fh [open $::DatabaseMaintainer::state_file w]
    puts $fh [::json::dict2json $state]
    close $fh
}

proc DatabaseMaintainer_get_file_hash {filepath} {
    if {![file exists $filepath]} {
        return ""
    }
    if {[catch {set fh [open $filepath r]}]} {
        return ""
    }
    set content [read $fh]
    close $fh
    return [::md5::md5 -hex $content]
}

proc DatabaseMaintainer_run_tree_command {} {
    if {[catch {exec tree -a -L 6 $::WORKSPACE} result]} {
        Logger_error "tree command fehlgeschlagen: $result"
        return ""
    } else {
        Logger_info "tree -a -L 6 erfolgreich ausgeführt"
        return $result
    }
}

proc DatabaseMaintainer_update_tree_file {tree_output} {
    if {$tree_output eq ""} {
        return 0
    }
    
    set tree_file "$::IMPORTANT_DIR/openclaw-tree.txt"
    set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    set header "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 6 $::WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
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

proc DatabaseMaintainer_scan_documentations {} {
    set docs [list]
    set files [glob -nocomplain -dir $::WORKSPACE *.md]
    lappend files {*}[glob -nocomplain -dir $::WORKSPACE -type f **/*.md]
    
    foreach md_file $files {
        if {[file isfile $md_file] && ![file isdirectory $md_file]} {
            set rel_path [string range $md_file [string length $::WORKSPACE]+1 end]
            if {![string match "*db/backups*" $rel_path] && ![string match "*node_modules*" $rel_path]} {
                set hash [DatabaseMaintainer_get_file_hash $md_file]
                set mtime [file mtime $md_file]
                lappend docs [dict create path $rel_path hash $hash mtime $mtime]
            }
        }
    }
    return $docs
}

proc DatabaseMaintainer_check_for_changes {} {
    set state [DatabaseMaintainer_load_state]
    set current_docs [DatabaseMaintainer_scan_documentations]
    
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

proc DatabaseMaintainer_update_databases {} {
    set script "$::WORKSPACE/scripts/update_docs_db.py"
    if {![file exists $script]} {
        Logger_error "Update script nicht gefunden: $script"
        return 0
    }
    
    if {[catch {exec python3 $script} result]} {
        Logger_error "DB-Update fehlgeschlagen: $result"
        return 0
    } else {
        Logger_info "docs.db aktualisiert"
        return 1
    }
}

proc DatabaseMaintainer_update_tree_db_v2 {} {
    set script "$::WORKSPACE/scripts/tree_indexer_v2.py"
    if {![file exists $script]} {
        Logger_error "Tree indexer script nicht gefunden: $script"
        return 0
    }
    
    if {[catch {exec python3 $script} result]} {
        Logger_error "Tree-DB v2 fehlgeschlagen: $result"
        return 0
    } else {
        Logger_info "tree.db v2 aktualisiert"
        return 1
    }
}

proc DatabaseMaintainer_create_backup {} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H-%M"]
    
    foreach db_name [list docs.db tree.db] {
        set source "$::DB_DIR/$db_name"
        if {[file exists $source]} {
            set backup_name "${timestamp}_${db_name}.bak"
            set backup_path "$::BACKUP_DIR/$backup_name"
            file copy -force $source $backup_path
            Logger_info "Backup erstellt: $backup_name"
        }
    }
    
    return $timestamp
}

proc DatabaseMaintainer_cleanup_old_backups {} {
    set cutoff [expr {[clock seconds] - ($::DatabaseMaintainer::retention_days * 86400)}]
    set deleted 0
    
    foreach db_name [list docs.db tree.db] {
        set pattern "$::BACKUP_DIR/*_${db_name}.bak"
        foreach backup [glob -nocomplain $pattern] {
            # Extrahiere Datum aus filename
            set basename [file tail $backup]
            if {[regexp {^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_} $basename match date_part time_part]} {
                if {[catch {
                    set backup_time [clock scan "$date_part $time_part" -format "%Y-%m-%d %H-%M"]
                    if {$backup_time < $cutoff} {
                        file delete $backup
                        incr deleted
                        Logger_info "Altes Backup gelöscht: $basename"
                    }
                }]} {
                    Logger_warn "Konnte Backup-Datum nicht parsen: $basename"
                }
            } else {
                Logger_warn "Ungültiges Backup-Dateiname-Format: $basename"
            }
        }
    }
    
    if {$deleted == 0} {
        Logger_info "Keine alten Backups zum Löschen"
    } else {
        Logger_info "$deleted alte Backups gelöscht (< 3 Tage)"
    }
}

proc DatabaseMaintainer_run_cycle {} {
    Logger_info [string repeat "=" 60]
    Logger_info "DB MAINTAINER CYCLE START"
    Logger_info [string repeat "=" 60]
    
    set state [DatabaseMaintainer_load_state]
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    Logger_info "Führe tree -a -L 8 aus..."
    set tree_output [DatabaseMaintainer_run_tree_command]
    if {$tree_output ne ""} {
        DatabaseMaintainer_update_tree_file $tree_output
        dict set state last_tree_update [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    }
    
    # 2. tree.db aktualisieren (intern v2)
    Logger_info "Aktualisiere tree.db v2..."
    DatabaseMaintainer_update_tree_db_v2
    
    # 3. Änderungen prüfen
    Logger_info "Prüfe auf Dokumentations-Änderungen..."
    lassign [DatabaseMaintainer_check_for_changes] changes current_hashes
    
    if {[llength $changes] > 0} {
        Logger_info "[llength $changes] Änderungen gefunden:"
        set count 0
        foreach change [lrange $changes 0 9] {
            Logger_info "  - $change"
            incr count
        }
        if {[llength $changes] > 10} {
            set remaining [expr {[llength $changes] - 10}]
            Logger_info "  ... und $remaining weitere"
        }
        
        # 4. docs.db aktualisieren
        Logger_info "Aktualisiere docs.db..."
        if {[DatabaseMaintainer_update_databases]} {
            dict set state last_check [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
            dict set state file_hashes $current_hashes
        }
    } else {
        Logger_info "Keine Dokumentations-Änderungen gefunden"
    }
    
    # 5. Prüfe ob Backup fällig (stündlich)
    set last_backup [dict get $state last_backup]
    set do_backup 1
    
    if {$last_backup ne ""} {
        set last_backup_time [clock scan $last_backup -format "%Y-%m-%dT%H:%M:%S"]
        set diff [expr {[clock seconds] - $last_backup_time}]
        set do_backup [expr {$diff >= 3600}]
    }
    
    if {$do_backup} {
        Logger_info "Erstelle stündliches Backup..."
        set timestamp [DatabaseMaintainer_create_backup]
        dict set state last_backup [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        Logger_info "Räume alte Backups auf (3 Tage Retention)..."
        DatabaseMaintainer_cleanup_old_backups
    } else {
        Logger_info "Backup nicht nötig (letztes < 1h)"
    }
    
    DatabaseMaintainer_save_state $state
    
    Logger_info [string repeat "=" 60]
    Logger_info "DB MAINTAINER CYCLE END"
    Logger_info [string repeat "=" 60]
}

proc main {} {
    DatabaseMaintainer_new
    
    if {[catch {
        DatabaseMaintainer_run_cycle
    } err]} {
        Logger_error "CRITICAL ERROR: $err"
        exit 1
    }
}

# Hauptprogramm starten
main
