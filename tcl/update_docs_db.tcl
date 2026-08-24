#!/usr/bin/env tclsh8.6
# update_docs_db.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

# Scan documentation files and refresh docs.db for the mounted workspace.

package require sqlite3
package require md5
package require json

# Determine workspace path
set WORKSPACE [expr {[info exists ::env(OPENCLAW_WORKSPACE)] ? $::env(OPENCLAW_WORKSPACE) : [file dirname [file dirname [info script]]]}]
set DB_PATH [file join $WORKSPACE "docs.db"]

proc iter_docs {} {
    global WORKSPACE
    set docs {}
    
    # Recursively find all .md files
    set files {}
    proc scan_dir {dir} {
        global files
        foreach item [glob -nocomplain -dir $dir *] {
            if {[file isdirectory $item]} {
                # Skip node_modules, .git, backups directories
                set basename [file tail $item]
                if {$basename ni {node_modules .git backups}} {
                    scan_dir $item
                }
            } elseif {[file extension $item] eq ".md" && [file isfile $item] && ![file type $item] eq "link"} {
                lappend files $item
            }
        }
    }
    
    # Initialize the scan
    set files {}
    scan_dir $WORKSPACE
    
    # Filter and return relative paths
    set result {}
    foreach filepath $files {
        set relpath [file normalize [string range $filepath [string length $WORKSPACE] end]]
        set relpath [string trimleft $relpath "/\\"]
        
        # Check if any part is in skip list
        set parts [split $relpath "/\\"]
        set skip false
        foreach part {node_modules .git backups} {
            if {[lsearch -exact $parts $part] != -1} {
                set skip true
                break
            }
        }
        
        if {!$skip} {
            lappend result $filepath
        }
    }
    
    return $result
}

proc file_hash {path} {
    set chan [open $path rb]
    set digest [md5::md5 -channel $chan]
    close $chan
    return $digest
}

proc word_count {path} {
    if {[catch {set chan [open $path r]}]} {
        return 0
    }
    
    if {[catch {set content [read $chan]}]} {
        close $chan
        return 0
    }
    
    close $chan
    
    # Split by whitespace and count words
    set words [regexp -all {\S+} $content]
    return $words
}

proc build_rows {} {
    set rows {}
    set indexed [clock seconds]
    
    foreach md_file [iter_docs] {
        global WORKSPACE
        set relpath [file normalize [string range $md_file [string length $WORKSPACE] end]]
        set relpath [string trimleft $relpath "/\\"]
        
        dict set row path $relpath
        dict set row content_hash [file_hash $md_file]
        dict set row last_indexed $indexed
        dict set row word_count [word_count $md_file]
        
        lappend rows $row
    }
    
    return $rows
}

proc ensure_schema {conn} {
    $conn eval {
        CREATE TABLE IF NOT EXISTS documents (
            path TEXT PRIMARY KEY,
            content_hash TEXT,
            last_indexed REAL,
            word_count INTEGER
        )
    }
    
    $conn eval {
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT,
            tag TEXT
        )
    }
}

proc update_database {rows} {
    global DB_PATH
    sqlite3 conn $DB_PATH
    
    ensure_schema conn
    conn eval {DELETE FROM documents}
    
    set stmt [conn prepare {
        INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (?, ?, ?, ?)
    }]
    
    foreach row $rows {
        $stmt bind 1 [dict get $row path]
        $stmt bind 2 [dict get $row content_hash]
        $stmt bind 3 [dict get $row last_indexed]
        $stmt bind 4 [dict get $row word_count]
        $stmt step
        $stmt reset
    }
    
    $stmt finalize
    conn close
}

proc export_table {table} {
    global DB_PATH WORKSPACE
    sqlite3 conn $DB_PATH
    conn eval "SELECT * FROM $table" rows {
        lappend all_rows $rows
    }
    
    # Convert to list of dicts for JSON export
    set data {}
    if {[info exists all_rows]} {
        set keys [lindex $all_rows 0]
        for {set i 1} {$i < [llength $all_rows]} {incr i} {
            set row_dict {}
            set values [lindex $all_rows $i]
            for {set j 0} {$j < [llength $keys]} {incr j} {
                dict set row_dict [lindex $keys $j] [lindex $values $j]
            }
            lappend data $row_dict
        }
    }
    
    # Write JSON
    set json_path [file join $WORKSPACE "db_${table}.json"]
    set json_fh [open $json_path w]
    puts $json_fh [json::write object {*}$data]
    close $json_fh
    
    # Write CSV
    set csv_path [file join $WORKSPACE "db_${table}.csv"]
    set csv_fh [open $csv_path w]
    
    if {[info exists all_rows] && [llength $all_rows] > 0} {
        # Write header
        set header [lindex $all_rows 0]
        puts $csv_fh [join $header ","]
        
        # Write data rows
        for {set i 1} {$i < [llength $all_rows]} {incr i} {
            set row [lindex $all_rows $i]
            puts $csv_fh [join $row ","]
        }
    } else {
        puts $csv_fh ""
    }
    
    close $csv_fh
    conn close
}

proc main {} {
    puts [string repeat "=" 60]
    puts "DOCS.DB UPDATER"
    puts [string repeat "=" 60]
    
    set rows [build_rows]
    puts "Gefunden: [llength $rows] Dokumente"
    
    update_database $rows
    puts "✅ [llength $rows] Dokumente in docs.db aktualisiert"
    
    export_table "documents"
    export_table "tags"
    puts "✅ Exporte aktualisiert"
    
    puts ""
    puts [string repeat "=" 60]
    puts "DOCS.DB AKTUALISIERT"
    puts [string repeat "=" 60]
}

main
