#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "946c8bcaa652aa98976bffccf572988c5add9ce38e70cc587bcb0e2b8c7685b3", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "tcl"}
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

#
# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt
#

package require json
package require fileutil

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
    variable logger_obj
    set obj [namespace current]::logger_[incr logger_obj]
    namespace eval $obj {
        variable log_file
        set today [clock format [clock seconds] -format "%Y-%m-%d"]
        set log_file "$::LOG_DIR/${today}.log"
    }
    proc ${obj}::log {level message} {
        variable log_file
        set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
        set line "\[${timestamp}\] \[$level\] $message"
        puts $line
        set fh [open $log_file a]
        puts $fh $line
        close $fh
    }
    proc ${obj}::info {msg} {
        log INFO $msg
    }
    proc ${obj}::warn {msg} {
        log WARN $msg
    }
    proc ${obj}::error {msg} {
        log ERROR $msg
    }
    return $obj
}

# DatabaseMaintainer Klasse
proc DatabaseMaintainer_new {} {
    variable maintainer_obj
    set obj [namespace current]::maintainer_[incr maintainer_obj]
    namespace eval $obj {
        variable logger
        variable state_file
        variable retention_days
        set logger [Logger_new]
        set state_file "$::DB_DIR/maintainer_state.json"
        set retention_days 3
    }
    
    proc ${obj}::load_state {} {
        variable state_file
        if {[file exists $state_file]} {
            set fh [open $state_file r]
            set content [read $fh]
            close $fh
            if {[catch {::json::json2dict $content} state]} {
                return [dict create last_check {} last_backup {} last_tree_update {} file_hashes {}]
            }
            return $state
        }
        return [dict create last_check {} last_backup {} last_tree_update {} file_hashes {}]
    }
    
    proc ${obj}::save_state {state} {
        variable state_file
        set fh [open $state_file w]
        puts $fh [::json::dict2json $state]
        close $fh
    }
    
    proc ${obj}::get_file_hash {filepath} {
        if {[catch {set fh [open $filepath r]}]} {
            return ""
        }
        fconfigure $fh -translation binary
        set data [read $fh]
        close $fh
        return [::md5::md5 -hex $data]
    }
    
    proc ${obj}::run_tree_command {} {
        variable logger
        if {[catch {exec tree -a -L 8 $::WORKSPACE} result]} {
            $logger error "tree command fehlgeschlagen: $result"
            return ""
        }
        $logger info "tree -a -L 8 erfolgreich ausgeführt"
        return $result
    }
    
    proc ${obj}::update_tree_file {tree_output} {
        variable logger
        if {$tree_output eq ""} {
            return 0
        }
        
        set tree_file "$::IMPORTANT_DIR/openclaw-tree.txt"
        set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        set header "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 8 $::WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
        
        if {[catch {set fh [open $tree_file w]}]} {
            $logger error "Fehler beim Öffnen von openclaw-tree.txt zum Schreiben"
            return 0
        }
        puts -nonewline $fh $header
        puts -nonewline $fh $tree_output
        close $fh
        $logger info "openclaw-tree.txt aktualisiert: $tree_file"
        return 1
    }
    
    proc ${obj}::scan_documentations {} {
        set docs [list]
        foreach pattern {"*.md" "*/*.md"} {
            foreach md_file [glob -nocomplain -directory $::WORKSPACE $pattern] {
                if {[file isfile $md_file] && ![file islink $md_file]} {
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
    
    proc ${obj}::check_for_changes {} {
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
    
    proc ${obj}::update_databases {} {
        variable logger
        if {[catch {exec python3 $::WORKSPACE/scripts/update_docs_db.py} result]} {
            $logger error "DB-Update fehlgeschlagen: $result"
            return 0
        }
        $logger info "docs.db aktualisiert"
        return 1
    }
    
    proc ${obj}::update_tree_db_v2 {} {
        variable logger
        if {[catch {exec python3 $::WORKSPACE/scripts/tree_indexer_v2.py} result]} {
            $logger error "Tree-DB v2 fehlgeschlagen: $result"
            return 0
        }
        $logger info "tree.db v2 aktualisiert"
        return 1
    }
    
    proc ${obj}::create_backup {} {
        variable logger
        set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H-%M"]
        
        foreach db_name [list "docs.db" "tree.db"] {
            set source "$::DB_DIR/$db_name"
            if {[file exists $source]} {
                set backup_name "${timestamp}_${db_name}.bak"
                set backup_path "$::BACKUP_DIR/$backup_name"
                file copy -force $source $backup_path
                $logger info "Backup erstellt: $backup_name"
            }
        }
        return $timestamp
    }
    
    proc ${obj}::cleanup_old_backups {} {
        variable logger
        variable retention_days
        set cutoff [expr {[clock seconds] - ($retention_days * 86400)}]
        set deleted 0
        
        foreach db_name [list "docs.db" "tree.db"] {
            set pattern "$::BACKUP_DIR/*_${db_name}.bak"
            foreach backup [glob -nocomplain $pattern] {
                # Extrahiere Datum aus Filename (Format: YYYY-MM-DD_HH-MM)
                set basename [file tail $backup]
                if {[regexp {^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_} $basename -> date_str time_str]} {
                    if {[catch {clock scan "$date_str $time_str" -format "%Y-%m-%d %H-%M"} backup_time]} {
                        $logger warn "Konnte Backup-Datum nicht parsen: $basename"
                        continue
                    }
                    
                    if {$backup_time < $cutoff} {
                        file delete $backup
                        incr deleted
                        $logger info "Altes Backup gelöscht: $basename"
                    }
                } else {
                    $logger warn "Konnte Backup-Datum nicht parsen: $basename"
                }
            }
        }
        
        if {$deleted == 0} {
            $logger info "Keine alten Backups zum Löschen"
        } else {
            $logger info "$deleted alte Backups gelöscht (< 3 Tage)"
        }
    }
    
    proc ${obj}::run_cycle {} {
        variable logger
        $logger info "============================================================"
        $logger info "DB MAINTAINER CYCLE START"
        $logger info "============================================================"
        
        set state [load_state]
        
        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        $logger info "Führe tree -a -L 8 aus..."
        set tree_output [run_tree_command]
        if {$tree_output ne ""} {
            update_tree_file $tree_output
            dict set state last_tree_update [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        }
        
        # 2. tree.db aktualisieren (intern v2)
        $logger info "Aktualisiere tree.db v2..."
        update_tree_db_v2
        
        # 3. Änderungen prüfen
        $logger info "Prüfe auf Dokumentations-Änderungen..."
        foreach {changes current_hashes} [check_for_changes] break
        
        if {[llength $changes] > 0} {
            $logger info "[llength $changes] Änderungen gefunden:"
            set count 0
            foreach change [lrange $changes 0 9] {
                $logger info "  - $change"
                incr count
            }
            if {[llength $changes] > 10} {
                set remaining [expr {[llength $changes] - 10}]
                $logger info "  ... und $remaining weitere"
            }
            
            # 4. docs.db aktualisieren
            $logger info "Aktualisiere docs.db..."
            if {[update_databases]} {
                dict set state last_check [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
                dict set state file_hashes $current_hashes
            }
        } else {
            $logger info "Keine Dokumentations-Änderungen gefunden"
        }
        
        # 5. Prüfe ob Backup fällig (stündlich)
        set last_backup [dict get $state last_backup]
        
        set do_backup 1
        if {$last_backup ne ""} {
            if {[catch {clock scan $last_backup -format "%Y-%m-%dT%H:%M:%S"} last_backup_time]} {
                set do_backup 1
            } else {
                set diff [expr {[clock seconds] - $last_backup_time}]
                set do_backup [expr {$diff >= 3600}]
            }
        }
        
        if {$do_backup} {
            $logger info "Erstelle stündliches Backup..."
            set timestamp [create_backup]
            dict set state last_backup [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
            
            # 6. Alte Backups aufräumen (3 Tage Retention)
            $logger info "Räume alte Backups auf (3 Tage Retention)..."
            cleanup_old_backups
        } else {
            $logger info "Backup nicht nötig (letztes < 1h)"
        }
        
        save_state $state
        
        $logger info "============================================================"
        $logger info "DB MAINTAINER CYCLE END"
        $logger info "============================================================"
    }
    
    return $obj
}

proc main {} {
    set maintainer [DatabaseMaintainer_new]
    
    if {[catch {${maintainer}::run_cycle} error]} {
        set logger [${maintainer}::logger]
        $logger error "CRITICAL ERROR: $error"
        exit 1
    }
}

if {[info script] eq $argv0} {
    main
}
