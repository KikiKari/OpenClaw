#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "f2e62efd988b0b8d2bbf64977aaf50beaf0902d1c2995aa258deb2651bd29a53", "source_sha256": "8d48f51942bb1c171bbd41e0696beb0722cb4b94d6596233f54b32928b645086", "target_language": "tcl"}
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

package require Tcl 8.6
package require sqlite3
package require md5
package require fileutil
package require json

# Determine workspace directory
set env_workspace ""
if {[info exists ::env(OPENCLAW_WORKSPACE)]} {
    set env_workspace $::env(OPENCLAW_WORKSPACE)
} else {
    set script_dir [file dirname [file normalize [info script]]]
    set env_workspace [file dirname $script_dir]
}
set WORKSPACE [file normalize $env_workspace]
set DB_DIR $WORKSPACE
set BACKUP_DIR [file join $WORKSPACE "db" "backups"]
set LOG_DIR [file join $WORKSPACE "logs" "db-maintainer"]
set IMPORTANT_DIR [file join $WORKSPACE "important"]

# Create directories
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR
file mkdir $IMPORTANT_DIR


# Logger Class
proc Logger_new {} {
    set obj [dict create]
    dict set obj log_file [file join $::LOG_DIR "[clock format [clock seconds] -format {%Y-%m-%d}].log"]
    return $obj
}

proc Logger_log {logger level message} {
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set line "\[$timestamp\] \[$level\] $message"
    puts $line
    set fd [open [dict get $logger log_file] a]
    puts $fd $line
    close $fd
}

proc Logger_info {logger msg} { Logger_log $logger INFO $msg }
proc Logger_warn {logger msg} { Logger_log $logger WARN $msg }
proc Logger_error {logger msg} { Logger_log $logger ERROR $msg }


# DatabaseMaintainer Class
proc DatabaseMaintainer_new {} {
    set obj [dict create]
    dict set obj logger [Logger_new]
    dict set obj state_file [file join $::DB_DIR "maintainer_state.json"]
    dict set obj retention_days 3
    return $obj
}

proc DatabaseMaintainer_load_state {self} {
    set state_file [dict get $self state_file]
    if {[file exists $state_file]} {
        set fd [open $state_file r]
        set content [read $fd]
        close $fd
        if {[catch {::json::json2dict $content} data]} {
            return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
        }
        return $data
    }
    return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
}

proc DatabaseMaintainer_save_state {self state} {
    set state_file [dict get $self state_file]
    set fd [open $state_file w]
    puts $fd [::json::dict2json $state]
    close $fd
}

proc DatabaseMaintainer_get_file_hash {filepath} {
    if {![file exists $filepath] || [file size $filepath] == 0} {
        return ""
    }
    set fd [open $filepath r]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd
    return [::md5::md5 -hex $data]
}

proc DatabaseMaintainer_python_tree_fallback {root max_depth} {
    set lines [list $root]
    
    proc walk {dirpath prefix depth max_depth lines_var} {
        if {$depth > $max_depth} {
            return
        }
        if {[catch {glob -nocomplain -dir $dirpath *} entries]} {
            return
        }
        set entries [lsort -dictionary $entries]
        set count [llength $entries]
        for {set i 0} {$i < $count} {incr i} {
            set entry [lindex $entries $i]
            set name [file tail $entry]
            set is_last [expr {$i == $count - 1}]
            set connector [expr {$is_last ? "└── " : "├── "}]
            lappend lines "$prefix$connector$name"
            upvar $lines_var lines_up
            if {[file isdirectory $entry] && ![file type $entry] eq "link"} {
                set extension [expr {$is_last ? "    " : "│   "}]
                walk $entry "$prefix$extension" [expr {$depth + 1}] $max_depth lines_up
            }
        }
    }
    
    walk $root "" 1 $max_depth lines
    return [join $lines "\n"]\n
}

proc DatabaseMaintainer_run_tree_command {self} {
    set logger [dict get $self logger]
    if {[catch {exec tree -a -L 8 $::WORKSPACE} result]} {
        Logger_warn $logger "tree-Binary nicht installiert – nutze Python-Fallback"
        return [DatabaseMaintainer_python_tree_fallback $::WORKSPACE 8]
    } else {
        Logger_info $logger "tree -a -L 8 erfolgreich ausgeführt"
        return $result
    }
}

proc DatabaseMaintainer_update_tree_file {self tree_output} {
    if {$tree_output eq ""} {
        return 0
    }
    
    set logger [dict get $self logger]
    set tree_file [file join $::IMPORTANT_DIR "openclaw-tree.txt"]
    set header "# OpenClaw Workspace Tree\n# Generiert: [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]\n# Befehl: tree -a -L 8 $::WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
    if {[catch {
        set fd [open $tree_file w]
        puts -nonewline $fd $header
        puts -nonewline $fd $tree_output
        close $fd
        Logger_info $logger "openclaw-tree.txt aktualisiert: $tree_file"
        return 1
    } error]} {
        Logger_error $logger "Fehler beim Schreiben von openclaw-tree.txt: $error"
        return 0
    }
}

proc DatabaseMaintainer_scan_documentations {self} {
    set docs [list]
    foreach pattern {"*.md" "**/*.md"} {
        set files [glob -nocomplain -dir $::WORKSPACE $pattern]
        foreach md_file $files {
            if {[file isfile $md_file] && [file type $md_file] ne "link"} {
                set rel_path [string range $md_file [string length $::WORKSPACE]+1 end]
                if {![string match "*db/backups*" $rel_path] && ![string match "*node_modules*" $rel_path]} {
                    lappend docs [dict create \
                        path $rel_path \
                        hash [DatabaseMaintainer_get_file_hash $md_file] \
                        mtime [file mtime $md_file]]
                }
            }
        }
    }
    return $docs
}

proc DatabaseMaintainer_check_for_changes {self} {
    set state [DatabaseMaintainer_load_state $self]
    set current_docs [DatabaseMaintainer_scan_documentations $self]
    
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
    
    # Check for deleted files
    dict for {old_path old_hash} [dict get $state file_hashes] {
        if {![dict exists $current_hashes $old_path]} {
            lappend changes "DELETED: $old_path"
        }
    }
    
    return [list $changes $current_hashes]
}

proc DatabaseMaintainer_update_databases {self} {
    set logger [dict get $self logger]
    if {[catch {
        set result [exec python3 [file join $::WORKSPACE scripts update_docs_db.py]]
        Logger_info $logger "docs.db aktualisiert"
        return 1
    } error]} {
        Logger_error $logger "DB-Update fehlgeschlagen: $error"
        return 0
    }
}

proc DatabaseMaintainer_update_tree_db_v2 {self} {
    set logger [dict get $self logger]
    if {[catch {
        set result [exec python3 [file join $::WORKSPACE scripts tree_indexer_v2.py]]
        Logger_info $logger "tree.db v2 aktualisiert"
        return 1
    } error]} {
        Logger_error $logger "Tree-DB v2 fehlgeschlagen: $error"
        return 0
    }
}

proc DatabaseMaintainer_create_backup {self} {
    set logger [dict get $self logger]
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
    set logger [dict get $self logger]
    set retention_days [dict get $self retention_days]
    set cutoff [expr {[clock seconds] - ($retention_days * 86400)}]
    set deleted 0
    
    foreach db_name [list "docs.db" "tree.db"] {
        set pattern [file join $::BACKUP_DIR "*_${db_name}.bak"]
        set backups [glob -nocomplain $pattern]
        
        foreach backup $backups {
            set basename [file tail $backup]
            if {[regexp {^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2})_} $basename -> date_part time_part]} {
                if {[catch {
                    set backup_time [clock scan "${date_part} ${time_part}" -format "%Y-%m-%d %H-%M"]
                    if {$backup_time < $cutoff} {
                        file delete $backup
                        incr deleted
                        Logger_info $logger "Altes Backup gelöscht: $basename"
                    }
                } error]} {
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
    set logger [dict get $self logger]
    Logger_info $logger "="*60
    Logger_info $logger "DB MAINTAINER CYCLE START"
    Logger_info $logger "="*60
    
    set state [DatabaseMaintainer_load_state $self]
    
    # 1. Run tree command and write to openclaw-tree.txt
    Logger_info $logger "Führe tree -a -L 8 aus..."
    set tree_output [DatabaseMaintainer_run_tree_command $self]
    if {$tree_output ne ""} {
        DatabaseMaintainer_update_tree_file $self $tree_output
        dict set state last_tree_update [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
    }
    
    # 2. Update tree.db (internal v2)
    Logger_info $logger "Aktualisiere tree.db v2..."
    DatabaseMaintainer_update_tree_db_v2 $self
    
    # 3. Check for changes
    Logger_info $logger "Prüfe auf Dokumentations-Änderungen..."
    set result [DatabaseMaintainer_check_for_changes $self]
    set changes [lindex $result 0]
    set current_hashes [lindex $result 1]
    
    if {[llength $changes] > 0} {
        Logger_info $logger "[llength $changes] Änderungen gefunden:"
        set count 0
        foreach change $changes {
            if {$count < 10} {
                Logger_info $logger "  - $change"
            }
            incr count
        }
        if {$count > 10} {
            Logger_info $logger "  ... und [expr {$count-10}] weitere"
        }
        
        # 4. Update docs.db
        Logger_info $logger "Aktualisiere docs.db..."
        if {[DatabaseMaintainer_update_databases $self]} {
            dict set state last_check [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
            dict set state file_hashes $current_hashes
        }
    } else {
        Logger_info $logger "Keine Dokumentations-Änderungen gefunden"
    }
    
    # 5. Check if backup is due (hourly)
    set last_backup [dict get $state last_backup]
    set do_backup 0
    
    if {$last_backup ne ""} {
        set last_backup_time [clock scan $last_backup -format {%Y-%m-%dT%H:%M:%S}]
        set do_backup [expr {[clock seconds] - $last_backup_time >= 3600}]
    } else {
        set do_backup 1
    }
    
    if {$do_backup} {
        Logger_info $logger "Erstelle stündliches Backup..."
        set timestamp [DatabaseMaintainer_create_backup $self]
        dict set state last_backup [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
        
        # 6. Clean up old backups (3 days retention)
        Logger_info $logger "Räume alte Backups auf (3 Tage Retention)..."
        DatabaseMaintainer_cleanup_old_backups $self
    } else {
        Logger_info $logger "Backup nicht nötig (letztes < 1h)"
    }
    
    DatabaseMaintainer_save_state $self $state
    
    Logger_info $logger "="*60
    Logger_info $logger "DB MAINTAINER CYCLE END"
    Logger_info $logger "="*60
}


# Main function
proc main {} {
    set maintainer [DatabaseMaintainer_new]
    
    if {[catch {
        DatabaseMaintainer_run_cycle $maintainer
    } error]} {
        set logger [dict get $maintainer logger]
        Logger_error $logger "CRITICAL ERROR: $error"
        exit 1
    }
}

# Run main if this script is executed directly
if {[info script] eq $argv0} {
    main
}
