#!/usr/bin/env tclsh8.6
# db_maintainer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Database Maintainer Sub-Agent
# Automated database maintenance with 30min checks, hourly backups (3 days retention),
# band tree command execution for important/openclaw-tree.txt

package require sqlite3
package require json
package require fileutil

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_DIR [file join $WORKSPACE "db"]
set BACKUP_DIR [file join $DB_DIR "backups"]
set LOG_DIR [file join $WORKSPACE "logs" "db-maintainer"]
set IMPORTANT_DIR [file join $WORKSPACE "important"]

# Create directories
file mkdir $BACKUP_DIR
file mkdir $LOG_DIR

# Logger class equivalent
proc Logger_new {} {
    variable log_instance
    set log_instance [dict create]
    dict set log_instance log_file [file join $::LOG_DIR [clock format [clock seconds] -format "%Y-%m-%d"].log]
    return log_instance
}

proc Logger_log {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set line "\[${timestamp}\] \[$level\] $message"
    puts $line
    set fh [open [dict get $::logger log_file] a]
    puts $fh $line
    close $fh
}

proc Logger_info {msg} { Logger_log INFO $msg }
proc Logger_warn {msg} { Logger_log WARN $msg }
proc Logger_error {msg} { Logger_log ERROR $msg }

# DatabaseMaintainer class equivalent
proc DatabaseMaintainer_new {} {
    variable maintainer
    set maintainer [dict create]
    dict set maintainer logger [Logger_new]
    dict set maintainer state_file [file join $::DB_DIR "maintainer_state.json"]
    dict set maintainer retention_days 3
    return maintainer
}

proc DatabaseMaintainer_load_state {} {
    set state_file [dict get $::maintainer state_file]
    if {[file exists $state_file]} {
        set fh [open $state_file r]
        set content [read $fh]
        close $fh
        return [::json::json2dict $content]
    }
    return [dict create last_check {} last_backup {} last_tree_update {} file_hashes [dict create]]
}

proc DatabaseMaintainer_save_state {state} {
    set state_file [dict get $::maintainer state_file]
    set fh [open $state_file w]
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
    fconfigure $fh -translation binary
    set data [read $fh]
    close $fh
    return [::md5::md5 -hex $data]
}

proc DatabaseMaintainer_run_tree_command {} {
    if {[catch {exec tree -a -L 8 $::WORKSPACE} result]} {
        Logger_error "tree command failed: $result"
        return ""
    } else {
        Logger_info "tree -a -L 8 executed successfully"
        return $result
    }
}

proc DatabaseMaintainer_update_tree_file {tree_output} {
    if {$tree_output eq ""} {
        return 0
    }
    
    set tree_file [file join $::IMPORTANT_DIR "openclaw-tree.txt"]
    set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    set header "# OpenClaw Workspace Tree\n# Generated: $timestamp\n# Command: tree -a -L 8 $::WORKSPACE\n# This file is automatically updated by db-maintainer\n\n"
    
    if {[catch {set fh [open $tree_file w]}]} {
        Logger_error "Failed to write to openclaw-tree.txt"
        return 0
    }
    puts -nonewline $fh $header
    puts -nonewline $fh $tree_output
    close $fh
    Logger_info "Updated openclaw-tree.txt: $tree_file"
    return 1
}

proc DatabaseMaintainer_scan_documentations {} {
    set docs [list]
    foreach pattern {"*.md" "**/*.md"} {
        set files [glob -nocomplain -dir $::WORKSPACE $pattern]
        foreach md_file $files {
            if {[file isfile $md_file] && ![file islink $md_file]} {
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
    
    # Check for deleted files
    dict for {old_path old_hash} [dict get $state file_hashes] {
        if {![dict exists $current_hashes $old_path]} {
            lappend changes "DELETED: $old_path"
        }
    }
    
    return [list $changes $current_hashes]
}

proc DatabaseMaintainer_update_databases {} {
    set script_path [file join $::WORKSPACE scripts update_docs_db.py]
    if {[catch {exec python3 $script_path} result]} {
        Logger_error "DB update failed: $result"
        return 0
    } else {
        Logger_info "docs.db updated"
        return 1
    }
}

proc DatabaseMaintainer_update_tree_db_v2 {} {
    set script_path [file join $::WORKSPACE scripts tree_indexer_v2.py]
    if {[catch {exec python3 $script_path} result]} {
        Logger_error "Tree DB v2 update failed: $result"
        return 0
    } else {
        Logger_info "tree.db v2 updated"
        return 1
    }
}

proc DatabaseMaintainer_create_backup {} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H-%M"]
    
    foreach db_name {"docs.db" "tree.db"} {
        set source [file join $::DB_DIR $db_name]
        if {[file exists $source]} {
            set backup_name "${timestamp}_${db_name}.bak"
            set backup_path [file join $::BACKUP_DIR $backup_name]
            file copy -force $source $backup_path
            Logger_info "Created backup: $backup_name"
        }
    }
    
    return $timestamp
}

proc DatabaseMaintainer_cleanup_old_backups {} {
    set cutoff [expr {[clock seconds] - (3 * 24 * 60 * 60)}] ;# 3 days in seconds
    set deleted 0
    
    foreach db_name {"docs.db" "tree.db"} {
        set pattern "*_${db_name}.bak"
        set backups [glob -nocomplain -dir $::BACKUP_DIR $pattern]
        
        foreach backup $backups {
            set basename [file tail $backup]
            if {[regexp {^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})_} $basename match date_part time_part]} {
                if {[catch {clock scan "$date_part $time_part" -format "%Y-%m-%d %H-%M"} backup_time]} {
                    Logger_warn "Could not parse backup date: $basename"
                    continue
                }
                
                if {$backup_time < $cutoff} {
                    file delete $backup
                    incr deleted
                    Logger_info "Deleted old backup: $basename"
                }
            } else {
                Logger_warn "Could not parse backup filename: $basename"
            }
        }
    }
    
    if {$deleted == 0} {
        Logger_info "No old backups to delete"
    } else {
        Logger_info "Deleted $deleted old backups (< 3 days)"
    }
}

proc DatabaseMaintainer_run_cycle {} {
    Logger_info [string repeat "=" 60]
    Logger_info "DB MAINTAINER CYCLE START"
    Logger_info [string repeat "=" 60]
    
    set state [DatabaseMaintainer_load_state]
    
    # 1. Run tree command and write to openclaw-tree.txt
    Logger_info "Running tree -a -L 8..."
    set tree_output [DatabaseMaintainer_run_tree_command]
    if {$tree_output ne ""} {
        DatabaseMaintainer_update_tree_file $tree_output
        dict set state last_tree_update [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    }
    
    # 2. Update tree.db (internal v2)
    Logger_info "Updating tree.db v2..."
    DatabaseMaintainer_update_tree_db_v2
    
    # 3. Check for changes
    Logger_info "Checking for documentation changes..."
    lassign [DatabaseMaintainer_check_for_changes] changes current_hashes
    
    if {[llength $changes] > 0} {
        Logger_info "[llength $changes] changes found:"
        set count 0
        foreach change [lrange $changes 0 9] {
            Logger_info "  - $change"
            incr count
        }
        if {[llength $changes] > 10} {
            Logger_info "  ... and [expr {[llength $changes] - 10}] more"
        }
        
        # 4. Update docs.db
        Logger_info "Updating docs.db..."
        if {[DatabaseMaintainer_update_databases]} {
            dict set state last_check [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
            dict set state file_hashes $current_hashes
        }
    } else {
        Logger_info "No documentation changes found"
    }
    
    # 5. Check if backup is due (hourly)
    set last_backup [dict get $state last_backup]
    set do_backup 0
    
    if {$last_backup ne ""} {
        if {[catch {clock scan $last_backup -format "%Y-%m-%dT%H:%M:%S"} last_backup_time]} {
            set do_backup 1
        } else {
            set diff [expr {[clock seconds] - $last_backup_time}]
            if {$diff >= 3600} { ;# 1 hour in seconds
                set do_backup 1
            }
        }
    } else {
        set do_backup 1
    }
    
    if {$do_backup} {
        Logger_info "Creating hourly backup..."
        set timestamp [DatabaseMaintainer_create_backup]
        dict set state last_backup [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
        
        # 6. Clean up old backups (3 day retention)
        Logger_info "Cleaning up old backups (3 day retention)..."
        DatabaseMaintainer_cleanup_old_backups
    } else {
        Logger_info "Backup not needed (last < 1h)"
    }
    
    DatabaseMaintainer_save_state $state
    
    Logger_info [string repeat "=" 60]
    Logger_info "DB MAINTAINER CYCLE END"
    Logger_info [string repeat "=" 60]
}

# Main function
proc main {} {
    global maintainer logger
    set maintainer [DatabaseMaintainer_new]
    set logger [dict get $maintainer logger]
    
    if {[catch {DatabaseMaintainer_run_cycle} error]} {
        Logger_error "CRITICAL ERROR: $error"
        exit 1
    }
}

# Run main
main
