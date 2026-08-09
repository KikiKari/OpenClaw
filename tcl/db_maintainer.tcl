#!/usr/bin/env tclsh8.6
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

#
# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt
#

package require sqlite3
package require json
package require fileutil

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_DIR [file join $WORKSPACE "db"]
set BACKUP_DIR [file join $DB_DIR "backups"]
set LOG_DIR [file join $WORKSPACE "logs" "db-maintainer"]
set IMPORTANT_DIR [file join $WORKSPACE "important"]

# Verzeichnisse erstellen
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR

# Logger Klasse
proc Logger_new {} {
    variable loggers
    if {![info exists loggers]} {
        set loggers 0
    }
    set id logger[incr loggers]
    namespace eval ::$id {
        variable log_file
        set today [clock format [clock seconds] -format {%Y-%m-%d}]
        set log_file [file join $::LOG_DIR "${today}.log"]
    }
    return $id
}

proc Logger_log {logger level message} {
    variable ${logger}::log_file
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set line "\[${timestamp}\] \[$level\] $message"
    puts $line
    set f [open $log_file a]
    puts $f $line
    close $f
}

proc Logger_info {logger msg} { Logger_log $logger INFO $msg }
proc Logger_warn {logger msg} { Logger_log $logger WARN $msg }
proc Logger_error {logger msg} { Logger_log $logger ERROR $msg }

# DatabaseMaintainer Klasse
proc DatabaseMaintainer_new {} {
    set obj [namespace current]::maintainer_[clock clicks]
    namespace eval $obj {
        variable logger
        variable state_file
        variable retention_days
        
        set logger [Logger_new]
        set state_file [file join $::DB_DIR "maintainer_state.json"]
        set retention_days 3
    }
    return $obj
}

proc DatabaseMaintainer_load_state {self} {
    variable ${self}::state_file
    if {[file exists $state_file]} {
        set f [open $state_file r]
        set content [read $f]
        close $f
        if {$content eq ""} {
            return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
        }
        if {[catch {json::json2dict $content} result]} {
            return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
        }
        return $result
    }
    return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
}

proc DatabaseMaintainer_save_state {self state} {
    variable ${self}::state_file
    set f [open $state_file w]
    puts $f [json::dict2json $state]
    close $f
}

proc DatabaseMaintainer_get_file_hash {self filepath} {
    if {![file exists $filepath]} {
        return ""
    }
    if {[catch {set f [open $filepath rb]}]} {
        return ""
    }
    set data [read $f]
    close $f
    return [md5::md5 -hex $data]
}

proc DatabaseMaintainer_run_tree_command {self} {
    variable ${self}::logger
    if {[catch {exec tree -a -L 8 $::WORKSPACE} result]} {
        Logger_error $logger "tree command Exception: $result"
        return ""
    }
    Logger_info $logger "tree -a -L 8 erfolgreich ausgeführt"
    return $result
}

proc DatabaseMaintainer_update_tree_file {self tree_output} {
    if {$tree_output eq ""} {
        return 0
    }
    
    variable ${self}::logger
    set tree_file [file join $::IMPORTANT_DIR "openclaw-tree.txt"]
    
    # Header mit Timestamp
    set timestamp [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    set header "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 8 $::WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
    if {[catch {
        set f [open $tree_file w]
        puts -nonewline $f $header
        puts -nonewline $f $tree_output
        close $f
        Logger_info $logger "openclaw-tree.txt aktualisiert: $tree_file"
        return 1
    } err]} {
        Logger_error $logger "Fehler beim Schreiben von openclaw-tree.txt: $err"
        return 0
    }
}

proc DatabaseMaintainer_scan_documentations {self} {
    set docs [list]
    
    foreach pattern [list "*.md" "*/*.md"] {
        set files [glob -nocomplain -dir $::WORKSPACE -types f -- $pattern]
        foreach md_file $files {
            set relative_path [fileutil::stripPath $::WORKSPACE $md_file]
            if {![string match "*/node_modules/*" $relative_path] && ![string match "db/backups*" $relative_path]} {
                lappend docs [dict create \
                    path $relative_path \
                    hash [$self get_file_hash $md_file] \
                    mtime [file mtime $md_file]]
            }
        }
    }
    
    return $docs
}

proc DatabaseMaintainer_check_for_changes {self} {
    set state [$self load_state]
    set current_docs [$self scan_documentations]
    
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

proc DatabaseMaintainer_update_databases {self} {
    variable ${self}::logger
    if {[catch {
        set result [exec python3 [file join $::WORKSPACE scripts update_docs_db.py]]
        Logger_info $logger "docs.db aktualisiert"
        return 1
    } err]} {
        Logger_error $logger "DB-Update Exception: $err"
        return 0
    }
}

proc DatabaseMaintainer_update_tree_db_v2 {self} {
    variable ${self}::logger
    if {[catch {
        set result [exec python3 [file join $::WORKSPACE scripts tree_indexer_v2.py]]
        Logger_info $logger "tree.db v2 aktualisiert"
        return 1
    } err]} {
        Logger_error $logger "Tree-DB v2 Exception: $err"
        return 0
    }
}

proc DatabaseMaintainer_create_backup {self} {
    variable ${self}::logger
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d_%H-%M}]
    
    foreach db_name [list "docs.db" "tree.db"] {
        set source [file join $::DB_DIR $db_name]
        if {[file exists $source]} {
            set backup_name "${timestamp}_${db_name}.bak"
            set backup_path [file join $::BACKUP_DIR $backup_name]
            file copy -force $source $backup_path
            Logger_info $logger "Backup erstellt: $backup_name"
        }
    }
    
    return $timestamp
}

proc DatabaseMaintainer_cleanup_old_backups {self} {
    variable ${self}::logger
    variable ${self}::retention_days
    set cutoff [expr {[clock seconds] - ($retention_days * 24 * 60 * 60)}]
    set deleted 0
    
    foreach db_name [list "docs.db" "tree.db"] {
        set pattern [file join $::BACKUP_DIR "*_${db_name}.bak"]
        foreach backup [glob -nocomplain -- $pattern] {
            # Extrahiere Datum aus filename (Format: YYYY-MM-DD_HH-MM)
            set basename [file tail $backup]
            if {[regexp {^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})_} $basename match date_part time_part]} {
                if {[catch {
                    set backup_time [clock scan "$date_part $time_part" -format "%Y-%m-%d %H-%M"]
                    if {$backup_time < $cutoff} {
                        file delete $backup
                        incr deleted
                        Logger_info $logger "Altes Backup gelöscht: $basename"
                    }
                } err]} {
                    Logger_warn $logger "Konnte Backup-Datum nicht parsen: $basename"
                }
            } else {
                Logger_warn $logger "Konnte Backup-Datum nicht parsen: $basename"
            }
        }
    }
    
    if {$deleted == 0} {
        Logger_info $logger "Keine alten Backups zum Löschen"
    } else {
        Logger_info $logger "$deleted alte Backups gelöscht (< 3 Tage)"
    }
}

proc DatabaseMaintainer_run_cycle {self} {
    variable ${self}::logger
    Logger_info $logger [string repeat "=" 60]
    Logger_info $logger "DB MAINTAINER CYCLE START"
    Logger_info $logger [string repeat "=" 60]
    
    set state [$self load_state]
    
    # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    Logger_info $logger "Führe tree -a -L 8 aus..."
    set tree_output [$self run_tree_command]
    if {$tree_output ne ""} {
        $self update_tree_file $tree_output
        dict set state last_tree_update [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    }
    
    # 2. tree.db aktualisieren (intern v2)
    Logger_info $logger "Aktualisiere tree.db v2..."
    $self update_tree_db_v2
    
    # 3. Änderungen prüfen
    Logger_info $logger "Prüfe auf Dokumentations-Änderungen..."
    lassign [$self check_for_changes] changes current_hashes
    
    if {[llength $changes] > 0} {
        Logger_info $logger "[llength $changes] Änderungen gefunden:"
        set count 0
        foreach change [lrange $changes 0 9] {
            Logger_info $logger "  - $change"
            incr count
        }
        if {[llength $changes] > 10} {
            Logger_info $logger "  ... und [expr {[llength $changes] - 10}] weitere"
        }
        
        # 4. docs.db aktualisieren
        Logger_info $logger "Aktualisiere docs.db..."
        if {[$self update_databases]} {
            dict set state last_check [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
            dict set state file_hashes $current_hashes
        }
    } else {
        Logger_info $logger "Keine Dokumentations-Änderungen gefunden"
    }
    
    # 5. Prüfe ob Backup fällig (stündlich)
    set last_backup [dict get $state last_backup]
    
    set do_backup 0
    if {$last_backup eq ""} {
        set do_backup 1
    } else {
        if {[catch {clock scan $last_backup} last_backup_time]} {
            set do_backup 1
        } else {
            set diff [expr {[clock seconds] - $last_backup_time}]
            if {$diff >= 3600} {
                set do_backup 1
            }
        }
    }
    
    if {$do_backup} {
        Logger_info $logger "Erstelle stündliches Backup..."
        set timestamp [$self create_backup]
        dict set state last_backup [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
        
        # 6. Alte Backups aufräumen (3 Tage Retention)
        Logger_info $logger "Räume alte Backups auf (3 Tage Retention)..."
        $self cleanup_old_backups
    } else {
        Logger_info $logger "Backup nicht nötig (letztes < 1h)"
    }
    
    $self save_state $state
    
    Logger_info $logger [string repeat "=" 60]
    Logger_info $logger "DB MAINTAINER CYCLE END"
    Logger_info $logger [string repeat "=" 60]
}

proc main {} {
    set maintainer [DatabaseMaintainer_new]
    
    if {[catch {
        $maintainer run_cycle
    } err]} {
        $maintainer logger error "CRITICAL ERROR: $err"
        exit 1
    }
}

if {[info script] eq $argv0} {
    main
}
