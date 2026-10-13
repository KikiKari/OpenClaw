#!/usr/bin/env tclsh8.6
# update_docs_db.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Scan documentation files and refresh docs.db for the mounted workspace.

package require sqlite3
package require json

set WORKSPACE "/workspace"
set DB_PATH "$WORKSPACE/db/docs.db"

proc iter_docs {} {
    global WORKSPACE
    set docs {}
    
    # Find all .md files recursively
    set cmd [list glob -nocomplain -dir $WORKSPACE -types {f r} "**/*.md"]
    if {[catch $cmd files]} {
        return {}
    }
    
    foreach md_file $files {
        # Check if it's a regular file and not a symlink
        if {![file isfile $md_file] || [file type $md_file] eq "link"} {
            continue
        }
        
        # Get relative path
        set rel_path [string range $md_file [string length $WORKSPACE]+1 end]
        
        # Skip certain directories
        set skip 0
        foreach part [split $rel_path "/"] {
            if {$part in {"node_modules" ".git" "backups"}} {
                set skip 1
                break
            }
        }
        
        if {!$skip} {
            lappend docs $md_file
        }
    }
    
    return $docs
}

proc file_hash {path} {
    if {[catch {open $path rb} fh]} {
        return ""
    }
    
    set digest [::md5::md5 -hex]
    while {![eof $fh]} {
        set chunk [read $fh 8192]
        if {$chunk ne ""} {
            $digest update $chunk
        }
    }
    close $fh
    
    set result [$digest digest]
    $digest destroy
    return $result
}

proc word_count {path} {
    if {[catch {open $path r} fh]} {
        return 0
    }
    
    set content [read $fh]
    close $fh
    
    # Split by whitespace and count words
    set words [regexp -all -inline {\S+} $content]
    return [llength $words]
}

proc build_rows {} {
    global WORKSPACE
    set indexed [clock seconds]
    set rows {}
    
    foreach md_file [iter_docs] {
        set rel_path [string range $md_file [string length $WORKSPACE]+1 end]
        lappend rows [dict create \
            path $rel_path \
            content_hash [file_hash $md_file] \
            last_indexed $indexed \
            word_count [word_count $md_file]]
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
    file mkdir [file dirname $DB_PATH]
    sqlite3 conn $DB_PATH
    
    ensure_schema conn
    
    conn transaction {
        conn eval {DELETE FROM documents}
        
        foreach row $rows {
            set path [dict get $row path]
            set content_hash [dict get $row content_hash]
            set last_indexed [dict get $row last_indexed]
            set word_count [dict get $row word_count]
            
            conn eval {
                INSERT INTO documents (path, content_hash, last_indexed, word_count) 
                VALUES ($path, $content_hash, $last_indexed, $word_count)
            }
        }
    }
    
    conn close
}

proc export_table {table} {
    global DB_PATH WORKSPACE
    sqlite3 conn $DB_PATH
    conn eval "SELECT * FROM $table" rows {
        set data {}
        foreach row $rows {
            lappend data $row
        }
    }
    
    # Export to JSON
    set json_data [json::write array]
    foreach row $rows {
        lappend json_data [json::write object {*}$row]
    }
    set json_output [json::write array {*}$json_data]
    
    set json_fh [open "$WORKSPACE/db_$table.json" w]
    puts $json_fh $json_output
    close $json_fh
    
    # Export to CSV
    set csv_fh [open "$WORKSPACE/db_$table.csv" w]
    if {[llength $rows] > 0} {
        # Write header
        set headers [dict keys [lindex $rows 0]]
        puts $csv_fh [join $headers ","]
        
        # Write data rows
        foreach row $rows {
            set values {}
            foreach header $headers {
                if {[dict exists $row $header]} {
                    lappend values [dict get $row $header]
                } else {
                    lappend values ""
                }
            }
            puts $csv_fh [join $values ","]
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
