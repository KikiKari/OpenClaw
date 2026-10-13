#!/usr/bin/env tclsh8.6
# tree_indexer.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/tree_indexer.py
# auch in: OpenClaw@gateway2:scripts/tree_indexer.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Tree Indexer - Scannt Verzeichnisbäume und speichert in tree.db

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_DIR [file join $WORKSPACE "db"]

proc connect {} {
    global DB_DIR
    set db_path [file join $DB_DIR "tree.db"]
    sqlite3 db $db_path
    db eval {PRAGMA foreign_keys = ON}
    return db
}

proc run_tree {root_path max_depth} {
    # Führt tree -a -L {depth} aus und parst Ausgabe
    if {[catch {exec timeout 30 tree -a -L $max_depth $root_path} result]} {
        puts "❌ Fehler bei tree $root_path: $result"
        return ""
    }
    return $result
}

proc parse_tree_output {tree_output root_path} {
    # Parst tree-Ausgabe und extrahiert Einträge
    set entries {}
    set lines [split [string trim $tree_output] "\n"]
    
    # Regex für tree-Zeilen
    # Beispiel: "├── .bash_history" oder "│   ├── bin"
    set pattern {^[│ ]*[├└]── (.+)$}
    
    foreach line $lines {
        if {[regexp $pattern $line match name]} {
            set name [string trim $name]
            # Tiefe bestimmen durch Anzahl der │ und Leerzeichen
            set depth [expr {[string count │ $line] + [expr {[string count "    " $line]}]}]
            
            # Typ bestimmen
            if {[string index $name end] eq "/"} {
                set entry_type "directory"
                set name [string range $name 0 end-1]
            } elseif {[string first " -> " $name] != -1} {
                set entry_type "symlink"
                set parts [split $name " -> "]
                set name [lindex $parts 0]
            } else {
                set entry_type "file"
            }
            
            lappend entries [dict create \
                name $name \
                type $entry_type \
                depth $depth \
                line $line]
        }
    }
    
    return $entries
}

proc save_to_db {root_path max_depth entries} {
    # Speichert Einträge in tree.db
    set conn [connect]
    
    # Scan-Metadaten
    set total_files 0
    set total_dirs 0
    set total_symlinks 0
    
    foreach entry $entries {
        switch [dict get $entry type] {
            file { incr total_files }
            directory { incr total_dirs }
            symlink { incr total_symlinks }
        }
    }
    
    $conn eval {
        INSERT INTO tree_scans 
        (root_path, max_depth, total_files, total_dirs, total_symlinks)
        VALUES ($root_path, $max_depth, $total_files, $total_dirs, $total_symlinks)
    }
    
    set scan_id [$conn last_insert_rowid]
    
    # Einträge speichern
    foreach entry $entries {
        $conn eval {
            INSERT INTO tree_entries 
            (root_path, relative_path, name, type, depth, parent_path, size)
            VALUES ($root_path, $relative_path, $name, $type, $depth, $parent_path, 0)
        } {
            set root_path $root_path
            set relative_path [dict get $entry name]
            set name [dict get $entry name]
            set type [dict get $entry type]
            set depth [dict get $entry depth]
            set parent_path $root_path
        }
    }
    
    $conn close
    puts "✅ [llength $entries] Einträge gespeichert für $root_path"
    return $scan_id
}

proc index_directory {root_path max_depth} {
    # Komplette Indexierung eines Verzeichnisses
    puts "\n--- Indexiere: $root_path (Depth: $max_depth) ---"
    set tree_output [run_tree $root_path $max_depth]
    
    if {$tree_output ne ""} {
        set entries [parse_tree_output $tree_output $root_path]
        if {[llength $entries] > 0} {
            return [save_to_db $root_path $max_depth $entries]
        }
    }
    return ""
}

proc export_csv {} {
    # Exportiert alle Tree-Einträge als CSV
    set conn [connect]
    set rows [$conn eval {SELECT * FROM tree_entries ORDER BY root_path, depth, name}]
    $conn close
    
    if {[llength $rows] == 0} {
        puts "⚠️ Keine Tree-Daten vorhanden"
        return ""
    }
    
    global WORKSPACE
    set csv_path [file join $WORKSPACE "export_tree_all.csv"]
    
    set f [open $csv_path w]
    set cols [list id root_path relative_path name type depth parent_path size created_at]
    puts $f [join $cols ","]
    
    foreach row $rows {
        puts $f [join $row ","]
    }
    
    close $f
    puts "✅ Tree CSV exportiert: $csv_path ([llength $rows] Einträge)"
    return $csv_path
}

proc export_by_root {} {
    # Exportiert getrennt nach root_path
    set conn [connect]
    set roots [$conn eval {SELECT DISTINCT root_path FROM tree_entries}]
    $conn close
    
    set exports {}
    foreach root_path $roots {
        set safe_name [regsub -all {[/\.]} $root_path "_"]
        global WORKSPACE
        set csv_path [file join $WORKSPACE "export_tree${safe_name}.csv"]
        
        set conn [connect]
        set rows [$conn eval {SELECT * FROM tree_entries WHERE root_path = $root_path ORDER BY depth, name}]
        $conn close
        
        set f [open $csv_path w]
        set cols [list id root_path relative_path name type depth parent_path size created_at]
        puts $f [join $cols ","]
        
        foreach row $rows {
            puts $f [join $row ","]
        }
        
        close $f
        
        lappend exports [list $root_path $csv_path [llength $rows]]
        puts "✅ Export $root_path: $csv_path ([llength $rows] Einträge)"
    }
    
    return $exports
}

proc main {} {
    puts [string repeat "=" 60]
    puts "TREE INDEXER"
    puts [string repeat "=" 60]
    
    # 1. /home/openclaw/ mit depth 3
    index_directory "/home/openclaw/" 3
    
    # 2. Workspace mit depth 6
    index_directory "/home/openclaw/.openclaw/workspace/" 6
    
    # Exporte erstellen
    puts "\n--- Exporte ---"
    export_csv
    export_by_root
    
    puts "\n[string repeat "=" 60]"
    puts "TREE INDEXIERUNG ABGESCHLOSSEN"
    puts [string repeat "=" 60]
}

# Hauptprogramm starten
main
