#!/usr/bin/env tclsh8.6
# update_docs_db.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db

package require sqlite3

set WORKSPACE "/home/openclaw/.openclaw/workspace"
set DB_PATH "$WORKSPACE/db/docs.db"

proc scan_documentations {} {
    global WORKSPACE
    set docs {}
    
    # Hauptverzeichnis
    foreach md_file [glob -nocomplain "$WORKSPACE/*.md"] {
        if {[file isfile $md_file] && ![file type $md_file] eq "link"} {
            lappend docs [dict create \
                name [file tail $md_file] \
                path "/" \
                category "main" \
                description [get_description $md_file] \
                type "doc" \
                has_symlink false \
                symlink_path "" \
                last_update [get_mtime $md_file]]
        }
    }
    
    # WebSearch Verzeichnis
    set websearch_dir "$WORKSPACE/websearch"
    if {[file exists $websearch_dir]} {
        foreach md_file [glob -nocomplain "$websearch_dir/*.md"] {
            set basename [file tail $md_file]
            lappend docs [dict create \
                name $basename \
                path "websearch/" \
                category "websearch" \
                description [get_description $md_file] \
                type [expr {"GUIDE" in $basename ? "guide" : "config"}] \
                has_symlink true \
                symlink_path "websearch/$basename" \
                last_update [get_mtime $md_file]]
        }
    }
    
    # MCP Verzeichnis
    set mcp_dir "$WORKSPACE/mcp"
    if {[file exists $mcp_dir]} {
        foreach md_file [glob -nocomplain "$mcp_dir/*.md"] {
            set is_symlink [expr {[file type $md_file] eq "link"}]
            set symlink_path ""
            if {$is_symlink} {
                set symlink_path [file readlink $md_file]
            }
            lappend docs [dict create \
                name [file tail $md_file] \
                path "mcp/" \
                category "mcp" \
                description [get_description $md_file] \
                type [expr {$is_symlink ? "symlink" : "guide"}] \
                has_symlink $is_symlink \
                symlink_path $symlink_path \
                last_update [get_mtime $md_file]]
        }
    }
    
    # Docs-Unterverzeichnisse
    set docs_dir "$WORKSPACE/docs"
    if {[file exists $docs_dir]} {
        foreach subdir [glob -nocomplain -directory $docs_dir -type d *] {
            set dirname [file tail $subdir]
            foreach md_file [glob -nocomplain "$subdir/*.md"] {
                lappend docs [dict create \
                    name [file tail $md_file] \
                    path "docs/$dirname/" \
                    category $dirname \
                    description [get_description $md_file] \
                    type "doc" \
                    has_symlink false \
                    symlink_path "" \
                    last_update [get_mtime $md_file]]
            }
        }
    }
    
    # Cluster, Memory, Reports, Skills
    foreach category {cluster memory reports skills} {
        set cat_dir "$WORKSPACE/$category"
        if {[file exists $cat_dir]} {
            foreach md_file [glob -nocomplain "$cat_dir/*.md"] {
                lappend docs [dict create \
                    name [file tail $md_file] \
                    path "$category/" \
                    category $category \
                    description [get_description $md_file] \
                    type "doc" \
                    has_symlink false \
                    symlink_path "" \
                    last_update [get_mtime $md_file]]
            }
        }
    }
    
    return $docs
}

proc get_description {md_file} {
    # Extrahiert erste Zeile als Beschreibung
    if {[catch {open $md_file r} fh]} {
        return "Dokumentation"
    }
    set first_line [string trim [gets $fh]]
    close $fh
    
    if {[string match "#*" $first_line]} {
        return [string trim [string range $first_line 1 end]]
    }
    if {[string length $first_line] > 50} {
        return "[string range $first_line 0 49]..."
    }
    return $first_line
}

proc get_mtime {md_file} {
    # Gibt letzte Änderung zurück
    if {[catch {file mtime $md_file} mtime]} {
        return "2026-04-18"
    }
    return [clock format $mtime -format "%Y-%m-%d"]
}

proc update_database {docs} {
    global DB_PATH
    sqlite3 db $DB_PATH
    
    # Lösche alte Einträge (außer config)
    db eval {DELETE FROM documents WHERE category != 'config'}
    
    # Füge neue ein
    set inserted 0
    foreach doc $docs {
        db eval {
            INSERT INTO documents 
            (name, path, category, description, type, has_symlink, symlink_path, last_update)
            VALUES ($name, $path, $category, $description, $type, $has_symlink, $symlink_path, $last_update)
        } {
            set name [dict get $doc name]
            set path [dict get $doc path]
            set category [dict get $doc category]
            set description [dict get $doc description]
            set type [dict get $doc type]
            set has_symlink [dict get $doc has_symlink]
            set symlink_path [dict get $doc symlink_path]
            set last_update [dict get $doc last_update]
        }
        incr inserted
    }
    
    db close
    return $inserted
}

proc export_all {} {
    global DB_PATH WORKSPACE
    sqlite3 db $DB_PATH
    
    # JSON Export
    foreach table {documents skills symlinks} {
        set rows [db eval "SELECT * FROM $table" row {
            array set record $row
            lappend all_rows [array get record]
        }]
        
        # JSON Export
        set json_path "$WORKSPACE/db_${table}.json"
        set fh [open $json_path w]
        puts $fh "\["
        set first_row 1
        foreach row_data $all_rows {
            if {!$first_row} {
                puts $fh ","
            }
            puts -nonewline $fh "  \{"
            set first_col 1
            foreach {key value} $row_data {
                if {!$first_col} {
                    puts -nonewline $fh ", "
                }
                puts -nonewline $fh "\"$key\": \"[string map {\" \"\\\"} $value]\""
                set first_col 0
            }
            puts -nonewline $fh "\}"
            set first_row 0
        }
        puts $fh "\n\]"
        close $fh
        puts "✅ $json_path"
        
        # CSV Export
        set csv_path "$WORKSPACE/db_${table}.csv"
        set fh [open $csv_path w]
        set columns [db eval "PRAGMA table_info($table)" row {
            lappend cols [lindex $row 1]
        }]
        puts $fh [join $cols ","]
        
        db eval "SELECT * FROM $table" row {
            set values {}
            foreach col $cols {
                lappend values [dict get $row $col]
            }
            puts $fh [join $values ","]
        }
        close $fh
        puts "✅ $csv_path"
    }
    
    db close
}

proc main {} {
    puts [string repeat "=" 60]
    puts "DOCS.DB UPDATER"
    puts [string repeat "=" 60]
    
    puts "\n--- Scanne Dokumentationen ---"
    set docs [scan_documentations]
    puts "Gefunden: [llength $docs] Dokumente"
    
    puts "\n--- Aktualisiere docs.db ---"
    set inserted [update_database $docs]
    puts "✅ $inserted Dokumente in docs.db aktualisiert"
    
    puts "\n--- Erstelle Exporte ---"
    export_all
    
    puts "\n[string repeat "=" 60]"
    puts "DOCS.DB AKTUALISIERT"
    puts [string repeat "=" 60]
}

main
