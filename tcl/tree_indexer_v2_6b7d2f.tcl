#!/usr/bin/env tclsh8.6
# tree_indexer_v2.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:scripts/tree_indexer_v2.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Tree Indexer v2 - Erweitertes Tracking mit Metadaten

package require sqlite3
package require md5

set WORKSPACE "/workspace"
set DB_DIR $WORKSPACE

# Globale Variablen für die Datenbankverbindung
set conn ""

# Klasse TreeIndexerV2 (simuliert durch Prozeduren)
proc TreeIndexerV2 {} {
    variable db_path
    variable conn
    
    set db_path [file join $::WORKSPACE "db" "tree.db"]
    set conn ""
}

# Initialisierung der Datenbankverbindung
proc connect {} {
    variable db_path
    variable conn
    
    if {$conn eq ""} {
        sqlite3 db $db_path
        set conn "db"
        # Setze Row Factory auf dict (ähnlich zu Python's row_factory)
        $conn eval {PRAGMA foreign_keys = ON}
    }
    return $conn
}

# Erstellt erweiterte Tabellenstruktur
proc init_schema_v2 {} {
    set conn [connect]
    
    # Haupttabelle mit erweiterten Metadaten
    $conn eval {
        CREATE TABLE IF NOT EXISTS tree_entries_v2 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT UNIQUE,              -- Eindeutige Datei-ID (Hash von Pfad)
            root_path TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
            depth INTEGER,
            parent_path TEXT,
            
            -- Größen-Tracking
            size_bytes INTEGER,               -- Aktuelle Größe
            previous_size_bytes INTEGER,      -- Vorherige Größe (für Delta)
            size_change_bytes INTEGER,        -- Änderung (positiv/negativ)
            
            -- Zeitstempel
            mtime_timestamp REAL,             -- Letzte Änderung (Unix timestamp)
            mtime_iso TEXT,                   -- ISO-Format für Lesbarkeit
            first_seen_timestamp REAL,        -- Wann wurde Datei erste Mal gesehen
            last_seen_timestamp REAL,         -- Wann wurde Datei zuletzt gesehen
            
            -- Änderungs-Tracking
            change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
            
            -- Historie
            original_name TEXT,               -- Ursprünglicher Name wenn umbenannt
            original_path TEXT,               -- Ursprünglicher Pfad wenn verschoben
            previous_path TEXT,               -- Vorheriger Pfad
            
            -- Content-Hash (optionale Integritätsprüfung)
            content_hash TEXT,                -- MD5 der Datei (nur für kleine Dateien)
            
            -- Metadaten
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    }
    
    # Historie-Tabelle für alle Änderungen
    $conn eval {
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
    $conn eval {CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id)}
    $conn eval {CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path)}
    $conn eval {CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp)}
    $conn eval {CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type)}
    
    puts "✅ tree.db Schema v2 erstellt/aktualisiert"
    return "self"
}

# Extrahiert Metadaten einer Datei
proc get_file_metadata {full_path} {
    array set metadata [list size 0 mtime 0 mtime_iso ""]
    
    if {[catch {file stat $full_path stat_info}]} {
        return [array get metadata]
    }
    
    set metadata(size) $stat_info(size)
    set metadata(mtime) $stat_info(mtime)
    
    # Konvertiere Unix-Timestamp zu ISO-Format
    if {$stat_info(mtime) != 0} {
        set metadata(mtime_iso) [clock format $stat_info(mtime) -format "%Y-%m-%dT%H:%M:%S"]
    }
    
    return [array get metadata]
}

# Generiert eindeutige ID aus Pfad
proc generate_file_id {relative_path} {
    set hash [md5::md5 -hex $relative_path]
    return [string range $hash 0 15]
}

# Detailliertes Scanning mit Metadaten
proc scan_directory_detailed {root_path max_depth} {
    set entries [list]
    
    # Rekursives Durchsuchen des Verzeichnisses
    proc scan_recursive {current_path root_path depth max_depth entries_var} {
        upvar $entries_var entries
        
        if {$depth > $max_depth} {
            return
        }
        
        if {![file isdirectory $current_path]} {
            return
        }
        
        set dirlist [lsort [glob -nocomplain -dir $current_path *]]
        foreach item $dirlist {
            # Bestimme relativen Pfad
            set relative_path [file join {*}[lrange [file split $item] [llength [file split $root_path]] end]]
            
            # Tiefe berechnen
            set item_depth [llength [file split $relative_path]]
            
            if {$item_depth > $max_depth} {
                continue
            }
            
            set file_id [generate_file_id $relative_path]
            
            # Hole Metadaten
            array set metadata [get_file_metadata $item]
            
            # Bestimme Typ
            set item_type "file"
            if {[file isdirectory $item]} {
                set item_type "directory"
            } elseif {[file type $item] eq "link"} {
                set item_type "symlink"
            }
            
            # Elternpfad bestimmen
            set parent_path ""
            if {$relative_path ne "." && $relative_path ne ""} {
                set parent_path [file dirname $relative_path]
                if {$parent_path eq "." || $parent_path eq "/"} {
                    set parent_path ""
                }
            }
            
            lappend entries [dict create \
                file_id $file_id \
                root_path $root_path \
                relative_path $relative_path \
                name [file tail $item] \
                type $item_type \
                depth $item_depth \
                parent_path $parent_path \
                size_bytes $metadata(size) \
                mtime_timestamp $metadata(mtime) \
                mtime_iso $metadata(mtime_iso) \
            ]
            
            # Rekursive Abstieg bei Verzeichnissen
            if {[file isdirectory $item] && $item_type ne "symlink"} {
                scan_recursive $item $root_path [expr {$item_depth + 1}] $max_depth entries
            }
        }
    }
    
    scan_recursive $root_path $root_path 0 $max_depth entries
    return $entries
}

# Aktualisiert DB mit Änderungs-Erkennung
proc update_database {entries} {
    set conn [connect]
    set now [clock seconds]
    set now_timestamp [expr {double($now)}]
    
    array set stats [list new 0 modified 0 unchanged 0 moved 0 deleted 0]
    
    # Alle bestehenden Einträge als "potentiell gelöscht" markieren
    $conn eval {UPDATE tree_entries_v2 SET change_type = NULL}
    
    foreach entry $entries {
        set file_id [dict get $entry file_id]
        
        # Prüfe ob Datei bereits bekannt
        set existing [$conn eval {SELECT * FROM tree_entries_v2 WHERE file_id = $file_id}]
        
        if {[llength $existing] > 0} {
            # Konvertiere das Ergebnis in ein dict
            set colnames [$conn eval {PRAGMA table_info(tree_entries_v2)}]
            set existing_dict {}
            for {set i 0} {$i < [llength $colnames]} {incr i 2} {
                lappend existing_dict [lindex $colnames $i] [lindex $existing $i]
            }
            
            # Vergleiche Metadaten
            set old_mtime [expr {[dict exists $existing_dict mtime_timestamp] ? [dict get $existing_dict mtime_timestamp] : 0}]
            set old_size [expr {[dict exists $existing_dict size_bytes] ? [dict get $existing_dict size_bytes] : 0}]
            set old_path [expr {[dict exists $existing_dict relative_path] ? [dict get $existing_dict relative_path] : ""}]
            
            # Größenänderung berechnen
            set size_change [expr {[dict get $entry size_bytes] - $old_size}]
            
            # Änderungstyp bestimmen
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
            
            # Update
            $conn eval {
                UPDATE tree_entries_v2 SET
                    size_bytes = $size_bytes,
                    previous_size_bytes = $previous_size_bytes,
                    size_change_bytes = $size_change_bytes,
                    mtime_timestamp = $mtime_timestamp,
                    mtime_iso = $mtime_iso,
                    last_seen_timestamp = $last_seen_timestamp,
                    change_type = $change_type,
                    previous_path = $previous_path,
                    original_path = COALESCE(original_path, $original_path),
                    updated_at = CURRENT_TIMESTAMP
                WHERE file_id = $file_id
            } [dict create \
                size_bytes [dict get $entry size_bytes] \
                previous_size_bytes $old_size \
                size_change_bytes $size_change \
                mtime_timestamp [dict get $entry mtime_timestamp] \
                mtime_iso [dict get $entry mtime_iso] \
                last_seen_timestamp $now_timestamp \
                change_type $change_type \
                previous_path [expr {$change_type eq "MOVED" ? $old_path : ""}] \
                original_path [expr {$change_type eq "MOVED" ? $old_path : [dict exists $existing_dict original_path] ? [dict get $existing_dict original_path] : ""]}] \
                file_id $file_id \
            ]
            
            # Änderung in Historie loggen
            if {$change_type in {"MODIFIED" "MOVED"}} {
                $conn eval {
                    INSERT INTO file_history
                    (file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
                    VALUES ($file_id, $timestamp, $change_type, $old_path, $new_path, $old_size, $new_size)
                } [dict create \
                    file_id $file_id \
                    timestamp $now_timestamp \
                    change_type $change_type \
                    old_path $old_path \
                    new_path [dict get $entry relative_path] \
                    old_size $old_size \
                    new_size [dict get $entry size_bytes] \
                ]
            }
        } else {
            # Neue Datei
            incr stats(new)
            $conn eval {
                INSERT INTO tree_entries_v2
                (file_id, root_path, relative_path, name, type, depth, parent_path,
                 size_bytes, previous_size_bytes, size_change_bytes,
                 mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                 change_type, content_hash)
                VALUES ($file_id, $root_path, $relative_path, $name, $type, $depth, $parent_path,
                        $size_bytes, $previous_size_bytes, $size_change_bytes,
                        $mtime_timestamp, $mtime_iso, $first_seen_timestamp, $last_seen_timestamp,
                        $change_type, $content_hash)
            } [dict create \
                file_id [dict get $entry file_id] \
                root_path [dict get $entry root_path] \
                relative_path [dict get $entry relative_path] \
                name [dict get $entry name] \
                type [dict get $entry type] \
                depth [dict get $entry depth] \
                parent_path [dict get $entry parent_path] \
                size_bytes [dict get $entry size_bytes] \
                previous_size_bytes [dict get $entry size_bytes] \
                size_change_bytes 0 \
                mtime_timestamp [dict get $entry mtime_timestamp] \
                mtime_iso [dict get $entry mtime_iso] \
                first_seen_timestamp $now_timestamp \
                last_seen_timestamp $now_timestamp \
                change_type "NEW" \
                content_hash "" \
            ]
        }
    }
    
    # Markiere nicht aktualisierte Einträge als DELETED
    set deleted [$conn eval {
        SELECT * FROM tree_entries_v2 
        WHERE change_type IS NULL OR last_seen_timestamp < $cutoff
    } [dict create cutoff [expr {$now_timestamp - 3600}]]]
    
    foreach row $deleted {
        # Extrahiere file_id aus dem Ergebnis
        set file_id [lindex $row 1] ;# Annahme: file_id ist das zweite Feld
        $conn eval {
            UPDATE tree_entries_v2 
            SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP
            WHERE file_id = $file_id
        }
    }
    
    set stats(deleted) [llength $deleted]
    
    $conn eval {COMMIT}
    return [array get stats]
}

# Exportiert Änderungen der letzten X Stunden
proc export_changes {{since_hours 24}} {
    set conn [connect]
    set now [clock seconds]
    set since [expr {$now - ($since_hours * 3600)}]
    
    set changes [$conn eval {
        SELECT * FROM tree_entries_v2 
        WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
        AND last_seen_timestamp > $since
        ORDER BY last_seen_timestamp DESC
    }]
    
    # Export als JSON-ähnliches Format
    set export_data [list]
    set colnames [$conn eval {PRAGMA table_info(tree_entries_v2)}]
    
    foreach row $changes {
        set entry_dict {}
        for {set i 0} {$i < [llength $colnames]} {incr i 2} {
            lappend entry_dict [lindex $colnames $i] [lindex $row $i]
        }
        lappend export_data $entry_dict
    }
    
    set export_file [file join $::WORKSPACE "tree_changes_last_${since_hours}h.json"]
    
    # Schreibe Daten in eine Datei (vereinfachte Darstellung)
    set fp [open $export_file w]
    puts $fp "\[[join [lmap entry $export_data {
        set entry_str "{"
        foreach {key value} $entry {
            append entry_str "\"$key\": \"[string map {\" \\\"} $value]\", "
        }
        if {[string length $entry_str] > 1} {
            set entry_str [string range $entry_str 0 end-2]
        }
        append entry_str "}"
    }] ",\n"]]"
    close $fp
    
    puts "✅ Änderungen exportiert: $export_file ([llength $changes] Einträge)"
    return $export_file
}

# Hauptprogramm
proc main {} {
    puts [string repeat "=" 60]
    puts "TREE INDEXER v2 - Erweitertes Tracking"
    puts [string repeat "=" 60]
    
    TreeIndexerV2
    init_schema_v2
    
    puts "\n--- Scanning Workspace ---"
    set entries [scan_directory_detailed $::WORKSPACE 8]
    puts "Gefunden: [llength $entries] Einträge"
    
    puts "\n--- Aktualisiere Datenbank ---"
    array set stats [update_database $entries]
    puts "Statistiken:"
    puts "  NEU:        $stats(new)"
    puts "  MODIFIED:   $stats(modified)"
    puts "  MOVED:      $stats(moved)"
    puts "  UNCHANGED:  $stats(unchanged)"
    puts "  DELETED:    $stats(deleted)"
    
    puts "\n--- Exportiere Änderungen (24h) ---"
    export_changes 24
    
    puts "\n[string repeat "=" 60]"
    puts "TREE INDEXING ABGESCHLOSSEN"
    puts [string repeat "=" 60]
}

# Starte das Programm
main
