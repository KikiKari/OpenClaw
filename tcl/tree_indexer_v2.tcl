#!/usr/bin/env tclsh8.6
# tree_indexer_v2.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/tree_indexer_v2.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Tree Indexer v2 - Erweitertes Tracking mit Metadaten

package require sqlite3

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_DIR "$WORKSPACE/db"

proc connect_db {} {
    global DB_DIR
    set db_path "$DB_DIR/tree.db"
    sqlite3 db $db_path
    db eval {PRAGMA foreign_keys = ON}
    return db
}

proc init_schema_v2 {} {
    set db [connect_db]
    
    # Haupttabelle mit erweiterten Metadaten
    $db eval {
        CREATE TABLE IF NOT EXISTS tree_entries_v2 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT UNIQUE,
            root_path TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
            depth INTEGER,
            parent_path TEXT,
            
            size_bytes INTEGER,
            previous_size_bytes INTEGER,
            size_change_bytes INTEGER,
            
            mtime_timestamp REAL,
            mtime_iso TEXT,
            first_seen_timestamp REAL,
            last_seen_timestamp REAL,
            
            change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
            
            original_name TEXT,
            original_path TEXT,
            previous_path TEXT,
            
            content_hash TEXT,
            
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    }
    
    # Historie-Tabelle für alle Änderungen
    $db eval {
        CREATE TABLE IF NOT EXISTS file_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            change_type TEXT NOT NULL,
            old_path TEXT,
            new_path TEXT,
            old_size INTEGER,
            new_size INTEGER,
            FOREIGN KEY (file_id) REFERENCES tree_entries_v2(file_id)
        )
    }
    
    # Index für schnelle Suchen
    $db eval {
        CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id);
        CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path);
        CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp);
        CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type);
    }
    
    puts "✅ tree.db Schema v2 erstellt/aktualisiert"
    return $db
}

proc get_file_metadata {full_path} {
    if {[catch {file stat $full_path stat_info}]} {
        return [dict create size 0 mtime 0 mtime_iso ""]
    }
    
    set size [dict get $stat_info size]
    set mtime [dict get $stat_info mtime]
    set mtime_iso [clock format $mtime -format "%Y-%m-%dT%H:%M:%S"]
    
    return [dict create size $size mtime $mtime mtime_iso $mtime_iso]
}

proc generate_file_id {relative_path} {
    set hash [md5 $relative_path]
    return [string range $hash 0 15]
}

proc scan_directory_detailed {root_path max_depth} {
    set entries {}
    set root_len [string length $root_path]
    if {[string index $root_path end] ne "/"} {
        incr root_len
    }
    
    proc walk_dir {dir root_path max_depth current_depth entries_var} {
        upvar $entries_var entries
        
        if {$current_depth > $max_depth} {
            return
        }
        
        if {![file exists $dir]} {
            return
        }
        
        set items [glob -nocomplain -dir $dir *]
        foreach item $items {
            if {[file isdirectory $item]} {
                walk_dir $item $root_path $max_depth [expr {$current_depth + 1}] entries
            }
            
            set rel_path [string range $item $::root_len end]
            if {$rel_path eq ""} continue
            
            set depth [llength [split $rel_path "/"]]
            if {$depth > $max_depth} continue
            
            set metadata [get_file_metadata $item]
            set file_id [generate_file_id $rel_path]
            
            set entry [dict create \
                file_id $file_id \
                root_path $root_path \
                relative_path $rel_path \
                name [file tail $item] \
                type [expr {[file isdirectory $item] ? "directory" : [expr {[file islink $item] ? "symlink" : "file"}]}] \
                depth $depth \
                parent_path [file dirname $rel_path] \
                size_bytes [dict get $metadata size] \
                mtime_timestamp [dict get $metadata mtime] \
                mtime_iso [dict get $metadata mtime_iso] \
            ]
            
            lappend entries $entry
        }
    }
    
    walk_dir $root_path $root_path $max_depth 0 entries
    return $entries
}

proc update_database {entries} {
    set db [connect_db]
    set now [clock seconds]
    set now_timestamp [expr {double($now)}]
    
    # Alle bestehenden Einträge als "potentiell gelöscht" markieren
    $db eval {UPDATE tree_entries_v2 SET change_type = NULL}
    
    array set stats [list new 0 modified 0 unchanged 0 moved 0]
    
    foreach entry $entries {
        set file_id [dict get $entry file_id]
        
        set existing [$db eval {
            SELECT * FROM tree_entries_v2 WHERE file_id = $file_id
        }]
        
        if {[llength $existing] > 0} {
            # Konvertiere das Ergebnis in ein dict
            set colnames [$db eval {PRAGMA table_info(tree_entries_v2)}] 
            set columns {}
            foreach col $colnames {
                lappend columns [lindex $col 1]
            }
            
            set existing_dict {}
            for {set i 0} {$i < [llength $columns]} {incr i} {
                dict set existing_dict [lindex $columns $i] [lindex $existing $i]
            }
            
            set old_mtime [expr {[dict get $existing_dict mtime_timestamp] ne "" ? [dict get $existing_dict mtime_timestamp] : 0}]
            set old_size [expr {[dict get $existing_dict size_bytes] ne "" ? [dict get $existing_dict size_bytes] : 0}]
            set old_path [dict get $existing_dict relative_path]
            
            set size_change [expr {[dict get $entry size_bytes] - $old_size}]
            
            set change_type "UNCHANGED"
            if {$old_path ne [dict get $entry relative_path]} {
                set change_type "MOVED"
                incr stats(moved)
            } elseif {$old_mtime != [dict get $entry mtime_timestamp] || $old_size != [dict get $entry size_bytes]} {
                set change_type "MODIFIED"
                incr stats(modified)
            } else {
                incr stats(unchanged)
            }
            
            $db eval {
                UPDATE tree_entries_v2 SET
                    size_bytes = $entry(size_bytes),
                    previous_size_bytes = $old_size,
                    size_change_bytes = $size_change,
                    mtime_timestamp = $entry(mtime_timestamp),
                    mtime_iso = $entry(mtime_iso),
                    last_seen_timestamp = $now_timestamp,
                    change_type = $change_type,
                    previous_path = CASE WHEN $change_type = 'MOVED' THEN $old_path ELSE NULL END,
                    original_path = COALESCE(original_path, $old_path),
                    updated_at = CURRENT_TIMESTAMP
                WHERE file_id = $file_id
            }
            
            if {$change_type in {"MODIFIED" "MOVED"}} {
                $db eval {
                    INSERT INTO file_history
                    (file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
                    VALUES ($file_id, $now_timestamp, $change_type, $old_path, $entry(relative_path), $old_size, $entry(size_bytes))
                }
            }
        } else {
            incr stats(new)
            $db eval {
                INSERT INTO tree_entries_v2
                (file_id, root_path, relative_path, name, type, depth, parent_path,
                 size_bytes, previous_size_bytes, size_change_bytes,
                 mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                 change_type, content_hash)
                VALUES (:file_id, :root_path, :relative_path, :name, :type, :depth, :parent_path,
                        :size_bytes, :size_bytes, 0,
                        :mtime_timestamp, :mtime_iso, :now_timestamp, :now_timestamp,
                        'NEW', NULL)
            } $entry
        }
    }
    
    set deleted [$db eval {
        SELECT * FROM tree_entries_v2 
        WHERE change_type IS NULL OR last_seen_timestamp < :cutoff
    } "" set cutoff [expr {$now_timestamp - 3600}]]
    
    set deleted_count 0
    foreach row $deleted {
        set file_id [lindex $row 1]  ;# file_id ist die zweite Spalte
        $db eval {
            UPDATE tree_entries_v2 
            SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP
            WHERE file_id = $file_id
        }
        incr deleted_count
    }
    
    set stats(deleted) $deleted_count
    
    $db close
    return [array get stats]
}

proc export_changes {since_hours} {
    global WORKSPACE
    set db [connect_db]
    set since [expr {[clock seconds] - ($since_hours * 3600)}]
    
    set changes [$db eval {
        SELECT * FROM tree_entries_v2 
        WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
        AND last_seen_timestamp > $since
        ORDER BY last_seen_timestamp DESC
    }]
    
    set export_file "$WORKSPACE/tree_changes_last_${since_hours}h.json"
    
    set json_data \[
    set first true
    foreach row $changes {
        if {!$first} {
            append json_data ,\n
        } else {
            set first false
        }
        append json_data \ \ \{
        set col_names [list id file_id root_path relative_path name type depth parent_path \
                      size_bytes previous_size_bytes size_change_bytes mtime_timestamp mtime_iso \
                      first_seen_timestamp last_seen_timestamp change_type original_name \
                      original_path previous_path content_hash created_at updated_at]
        for {set i 0} {$i < [llength $row]} {incr i} {
            set col_name [lindex $col_names $i]
            set value [lindex $row $i]
            if {$value eq ""} {
                set value null
            } elseif {![string is double -strict $value] && ![string is integer -strict $value]} {
                set value "\"[string map {\" \\\"} $value]\""
            }
            if {$i > 0} {
                append json_data ,
            }
            append json_data \n\ \ \ \ \"$col_name\":\ $value
        }
        append json_data \n\ \ \}
    }
    append json_data \n\]
    
    set fh [open $export_file w]
    puts $fh $json_data
    close $fh
    
    puts "✅ Änderungen exportiert: $export_file ([llength $changes] Einträge)"
    $db close
    return $export_file
}

proc md5 {data} {
    if {[catch {exec echo -n $data | md5sum} result]} {
        error "Failed to compute MD5 hash"
    }
    return [lindex [split $result " "] 0]
}

proc main {} {
    puts [string repeat "=" 60]
    puts "TREE INDEXER v2 - Erweitertes Tracking"
    puts [string repeat "=" 60]
    
    init_schema_v2
    
    puts "\n--- Scanning Workspace ---"
    set entries [scan_directory_detailed "/home/openclaw/.openclaw/workspace/" 8]
    puts "Gefunden: [llength $entries] Einträge"
    
    puts "\n--- Aktualisiere Datenbank ---"
    set stats_array [update_database $entries]
    array set stats $stats_array
    
    puts "Statistiken:"
    puts "  NEU:        [expr {[info exists stats(new)] ? $stats(new) : 0}]"
    puts "  MODIFIED:   [expr {[info exists stats(modified)] ? $stats(modified) : 0}]"
    puts "  MOVED:      [expr {[info exists stats(moved)] ? $stats(moved) : 0}]"
    puts "  UNCHANGED:  [expr {[info exists stats(unchanged)] ? $stats(unchanged) : 0}]"
    puts "  DELETED:    [expr {[info exists stats(deleted)] ? $stats(deleted) : 0}]"
    
    puts "\n--- Exportiere Änderungen (24h) ---"
    export_changes 24
    
    puts "\n[string repeat "=" 60]"
    puts "TREE INDEXING ABGESCHLOSSEN"
    puts [string repeat "=" 60]
}

main
