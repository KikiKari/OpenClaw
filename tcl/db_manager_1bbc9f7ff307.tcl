#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "be00d0b1e4920065c49cb93353f6a9be14b651e286cafb7903d6a9cc00726428", "source_sha256": "62685d1bad45f2dffb79d4424a8a668a222d4008e157a9d6b51a3e2a1d1d204d", "target_language": "tcl"}
# db_manager.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/db_manager.py
# auch in: OpenClaw@gateway2:scripts/db_manager.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Workspace Documentation Database Manager
#
# Erstellt und verwaltet docs.db und tree.db im Workspace-Datenbankverzeichnis.
# Beide Datenbanken liegen unter $OPENCLAW_WORKSPACE/db/.
#
# Verwendung:
#     tclsh8.6 db_manager.tcl
#
# Konfiguration:
#     OPENCLAW_WORKSPACE (Umgebungsvariable) — Standard: /home/openclaw/.openclaw/workspace

package require sqlite3
package require csv
package require json
package require fileutil

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

set WORKSPACE [expr {[info exists ::env(OPENCLAW_WORKSPACE)] ? $::env(OPENCLAW_WORKSPACE) : "/home/openclaw/.openclaw/workspace"}]
set DB_DIR [file join $WORKSPACE "db"]

# Erlaubte Tabellennamen für Export-Methoden (verhindert SQL-Injection)
set _DOCS_EXPORT_TABLES [list "documents" "categories" "symlinks" "skills"]
set _TREE_EXPORT_TABLES [list "tree_entries" "tree_scans"]

# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

proc log_message {level name message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "$timestamp | [string toupper [format "%-8s" $level]] | $name | $message"
}

proc log_info {name message} {
    log_message "INFO" $name $message
}

proc log_error {name message} {
    log_message "ERROR" $name $message
}

# ---------------------------------------------------------------------------
# DocsDatabase
# ---------------------------------------------------------------------------

namespace eval DocsDatabase {
    variable db_path [file join $::DB_DIR "docs.db"]
    
    proc _get_connection {} {
        variable db_path
        sqlite3 db $db_path
        db function row_factory {}
        return db
    }
    
    proc close_connection {conn} {
        ${conn} close
    }
    
    proc init_schema {} {
        variable db_path
        set conn [_get_connection]
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS documents (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                path        TEXT    NOT NULL,
                category    TEXT,
                description TEXT,
                type        TEXT    CHECK(type IN ('config', 'doc', 'guide', 'script', 'symlink')),
                has_symlink BOOLEAN DEFAULT FALSE,
                symlink_path TEXT,
                last_update TEXT,
                created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        }
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS categories (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    UNIQUE NOT NULL,
                description TEXT,
                priority    INTEGER DEFAULT 0
            )
        }
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS symlinks (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                target      TEXT    NOT NULL,
                source_path TEXT    NOT NULL,
                description TEXT,
                created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        }
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS skills (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                version     TEXT,
                status      TEXT    CHECK(status IN ('installed', 'local', 'published')),
                description TEXT,
                path        TEXT
            )
        }
        
        close_connection $conn
        log_info "db_manager" "docs.db Schema initialisiert: $db_path"
    }
    
    proc populate_from_workspace {} {
        variable db_path
        set conn [_get_connection]
        
        set categories {
            {main       "Hauptverzeichnis Dateien"        1}
            {memory     "Memory und Protokolle"           2}
            {reports    "Berichte und Analysen"           3}
            {cluster    "Cluster und Infrastruktur"       4}
            {skills     "Installierte Skills"             5}
            {websearch  "WebSearch Dokumentationen"       6}
            {mcp        "MCP Integration"                 7}
            {links      "Symbolische Links"               8}
        }
        
        set docs {
            {"AGENTS.md"             "/" "main" "Agent-Konfiguration, Memory-Regeln"      "config"  false ""                          "2026-04-11"}
            {"SOUL.md"               "/" "main" "Agent-Persönlichkeit und Kernwahrheiten" "config"  false ""                          "2026-04-11"}
            {"IDENTITY.md"           "/" "main" "Agent-Name und Eigenschaften"            "config"  false ""                          "2026-04-11"}
            {"USER.md"               "/" "main" "Benutzerinformationen"                   "config"  false ""                          "2026-04-11"}
            {"TOOLS.md"              "/" "main" "Tool-spezifische Konfigurationen"        "config"  false ""                          "2026-04-18"}
            {"MEMORY.md"             "/" "main" "Langzeitspeicher, System-Konfiguration"  "config"  false ""                          "2026-04-11"}
            {"DOCUMENTATION-INDEX.md" "/" "main" "Übersicht aller Dokumentationen"         "doc"     false ""                          "2026-04-18"}
            {"WORKSPACE-INDEX.md"    "/" "main" "Symlink zu DOCUMENTATION-INDEX.md"       "symlink" true  "DOCUMENTATION-INDEX.md"      "2026-04-18"}
            {"WEBSEARCH_README.md"        "websearch/" "websearch" "Schnellstart Guide"                    "guide"  true "websearch/WEBSEARCH_README.md"          "2026-04-18"}
            {"WEBSEARCH_MCP_GUIDE.md"     "websearch/" "websearch" "Vollständige technische Dokumentation" "guide"  true "websearch/WEBSEARCH_MCP_GUIDE.md"       "2026-04-18"}
            {"WEBSEARCH_CONFIG.md"        "websearch/" "websearch" "Konfigurations-Referenz"               "config" true "websearch/WEBSEARCH_CONFIG.md"          "2026-04-18"}
            {"WEBSEARCH_PRIORITY_CONFIG.md" "websearch/" "websearch" "Provider-Priorität"                    "config" true "websearch/WEBSEARCH_PRIORITY_CONFIG.md" "2026-04-18"}
            {"WEBSEARCH_SCRIPTS.md"       "websearch/" "websearch" "Automation & Scripting"                "script" true "websearch/WEBSEARCH_SCRIPTS.md"         "2026-04-18"}
            {"WEBSEARCH_OPS.md"           "websearch/" "websearch" "IT-Operations"                         "guide"  true "websearch/WEBSEARCH_OPS.md"             "2026-04-18"}
            {"MCP_GUIDE.md"               "mcp/"       "mcp"       "Symlink zu websearch/WEBSEARCH_MCP_GUIDE.md" "symlink" false "websearch/WEBSEARCH_MCP_GUIDE.md"  "2026-04-18"}
        }
        
        set skills {
            {"json-utils"          "1.0.0" "installed" "JSON parsing and validation"      "skills/json-utils/"}
            {"scripting-utils"     "1.0.0" "installed" "Multi-language scripting support" "skills/scripting-utils/"}
            {"tiktok-live-mon"     "1.0.0" "installed" "TikTok stream monitoring"         "skills/tiktok-live-mon/"}
            {"cluster-management"  "1.0.0" "installed" "Cluster topology management"      "skills/cluster-management/"}
            {"worker-node"         "-"     "local"     "Worker node configuration"        "skills/worker-node/"}
            {"resource-manager"    "-"     "local"     "Resource management"              "skills/resource-manager/"}
            {"git-publish-agent"   "1.0.0" "local"     "Git publishing automation"        "skills/git-publish-agent/"}
        }
        
        set symlinks {
            {"openclaw.env"               "/home/openclaw/.config/openclaw/env"  "/"             "API-Keys Shortcut"}
            {"openclaw.json"              "/home/openclaw/.openclaw/openclaw.json" "/"             "Konfig Shortcut"}
            {"links/config/openclaw-env"  "/home/openclaw/.config/openclaw/env"  "links/config/" "API-Keys"}
            {"links/dotfiles/.tavily"     "/home/openclaw/.tavily/"              "links/dotfiles/" "Tavily Config"}
            {"links/dotfiles/.claude"     "/home/openclaw/.claude/"              "links/dotfiles/" "Claude Config"}
            {"links/dotfiles/.mcporter"   "/home/openclaw/.mcporter/"            "links/dotfiles/" "MCPorter Config"}
            {"links/dotfiles/.ssh"        "/home/openclaw/.ssh/"                 "links/dotfiles/" "SSH Keys"}
        }
        
        foreach category $categories {
            ${conn} eval {
                INSERT OR IGNORE INTO categories (name, description, priority) VALUES ($name, $description, $priority)
            } [dict create name [lindex $category 0] description [lindex $category 1] priority [lindex $category 2]]
        }
        
        foreach doc $docs {
            ${conn} eval {
                INSERT OR REPLACE INTO documents
                (name, path, category, description, type, has_symlink, symlink_path, last_update)
                VALUES ($name, $path, $category, $description, $type, $has_symlink, $symlink_path, $last_update)
            } [dict create name [lindex $doc 0] path [lindex $doc 1] category [lindex $doc 2] description [lindex $doc 3] type [lindex $doc 4] has_symlink [lindex $doc 5] symlink_path [lindex $doc 6] last_update [lindex $doc 7]]
        }
        
        foreach skill $skills {
            ${conn} eval {
                INSERT OR REPLACE INTO skills (name, version, status, description, path) VALUES ($name, $version, $status, $description, $path)
            } [dict create name [lindex $skill 0] version [lindex $skill 1] status [lindex $skill 2] description [lindex $skill 3] path [lindex $skill 4]]
        }
        
        foreach symlink $symlinks {
            ${conn} eval {
                INSERT OR REPLACE INTO symlinks (name, target, source_path, description) VALUES ($name, $target, $source_path, $description)
            } [dict create name [lindex $symlink 0] target [lindex $symlink 1] source_path [lindex $symlink 2] description [lindex $symlink 3]]
        }
        
        close_connection $conn
        log_info "db_manager" "docs.db befüllt: [llength $docs] Dokumente, [llength $skills] Skills, [llength $symlinks] Symlinks"
    }
    
    proc _validate_table_name {table allowed} {
        if {$table ni $allowed} {
            error "Ungültiger Tabellenname: '$table'. Erlaubt: [lsort $allowed]"
        }
    }
    
    proc export_csv {table} {
        variable db_path
        _validate_table_name $table $::_DOCS_EXPORT_TABLES
        
        set conn [_get_connection]
        set rows [${conn} eval "SELECT * FROM $table"]
        set column_names [${conn} eval "PRAGMA table_info($table)" {lappend names $name}]
        set names {}
        close_connection $conn
        
        if {[llength $rows] == 0} {
            log_info "db_manager" "Tabelle '$table' ist leer — kein CSV erzeugt"
            return
        }
        
        set csv_path [file join $::WORKSPACE "export_${table}.csv"]
        set fh [open $csv_path w]
        csv::writer $fh [list {*}$column_names]
        foreach row $rows {
            csv::writer $fh [list {*}$row]
        }
        close $fh
        
        log_info "db_manager" "CSV exportiert: $csv_path ([llength $rows] Zeilen)"
        return $csv_path
    }
    
    proc export_json {table} {
        variable db_path
        _validate_table_name $table $::_DOCS_EXPORT_TABLES
        
        set conn [_get_connection]
        set rows [${conn} eval "SELECT * FROM $table"]
        set column_names [${conn} eval "PRAGMA table_info($table)" {lappend names $name}]
        set names {}
        close_connection $conn
        
        if {[llength $rows] == 0} {
            log_info "db_manager" "Tabelle '$table' ist leer — kein JSON erzeugt"
            return
        }
        
        set data {}
        foreach row $rows {
            set entry {}
            for {set i 0} {$i < [llength $column_names]} {incr i} {
                dict set entry [lindex $column_names $i] [lindex $row $i]
            }
            lappend data $entry
        }
        
        set json_path [file join $::WORKSPACE "export_${table}.json"]
        set fh [open $json_path w]
        puts $fh [json::encode $data]
        close $fh
        
        log_info "db_manager" "JSON exportiert: $json_path ([llength $data] Einträge)"
        return $json_path
    }
}

# ---------------------------------------------------------------------------
# TreeDatabase
# ---------------------------------------------------------------------------

namespace eval TreeDatabase {
    variable db_path [file join $::DB_DIR "tree.db"]
    
    proc _get_connection {} {
        variable db_path
        sqlite3 db $db_path
        db function row_factory {}
        return db
    }
    
    proc close_connection {conn} {
        ${conn} close
    }
    
    proc init_schema {} {
        variable db_path
        set conn [_get_connection]
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS tree_entries (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path     TEXT    NOT NULL,
                relative_path TEXT    NOT NULL,
                name          TEXT    NOT NULL,
                type          TEXT    CHECK(type IN ('file', 'directory', 'symlink')),
                depth         INTEGER,
                parent_path   TEXT,
                size          INTEGER,
                created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        }
        
        ${conn} eval {
            CREATE TABLE IF NOT EXISTS tree_scans (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path      TEXT    NOT NULL,
                max_depth      INTEGER,
                total_files    INTEGER,
                total_dirs     INTEGER,
                total_symlinks INTEGER,
                scanned_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        }
        
        close_connection $conn
        log_info "db_manager" "tree.db Schema initialisiert: $db_path"
    }
    
    proc add_entry {root_path relative_path name entry_type depth parent_path {size 0}} {
        set conn [_get_connection]
        ${conn} eval {
            INSERT INTO tree_entries
            (root_path, relative_path, name, type, depth, parent_path, size)
            VALUES ($root_path, $relative_path, $name, $entry_type, $depth, $parent_path, $size)
        } [dict create root_path $root_path relative_path $relative_path name $name entry_type $entry_type depth $depth parent_path $parent_path size $size]
        close_connection $conn
    }
    
    proc export_csv {{root_path_filter ""}} {
        set conn [_get_connection]
        
        if {$root_path_filter ne ""} {
            set rows [${conn} eval {
                SELECT * FROM tree_entries WHERE root_path = $root_path_filter
            } [dict create root_path_filter $root_path_filter]]
        } else {
            set rows [${conn} eval {SELECT * FROM tree_entries}]
        }
        
        set column_names [${conn} eval "PRAGMA table_info(tree_entries)" {lappend names $name}]
        set names {}
        close_connection $conn
        
        if {[llength $rows] == 0} {
            log_info "db_manager" "Keine Tree-Einträge vorhanden — kein CSV erzeugt"
            return
        }
        
        set suffix [expr {$root_path_filter ne "" ? "_[string map {"/" "_"} $root_path_filter]" : "_all"}]
        set csv_path [file join $::WORKSPACE "export_tree${suffix}.csv"]
        
        set fh [open $csv_path w]
        csv::writer $fh [list {*}$column_names]
        foreach row $rows {
            csv::writer $fh [list {*}$row]
        }
        close $fh
        
        log_info "db_manager" "Tree-CSV exportiert: $csv_path ([llength $rows] Einträge)"
        return $csv_path
    }
}

# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------

proc main {} {
    puts [string repeat "=" 60]
    puts "WORKSPACE DATABASE MANAGER"
    puts [string repeat "=" 60]
    
    # DB-Verzeichnis hier (nicht auf Modulebene) anlegen
    if {![file exists $::DB_DIR]} {
        if {[catch {file mkdir $::DB_DIR} err]} {
            log_error "db_manager" "DB-Verzeichnis konnte nicht erstellt werden: $err"
            exit 1
        }
    }
    log_info "db_manager" "DB-Verzeichnis: $::DB_DIR"
    
    # docs.db aufbauen
    DocsDatabase::init_schema
    DocsDatabase::populate_from_workspace
    
    # Exporte
    puts "\n--- Exporte docs.db ---"
    foreach table {documents skills symlinks} {
        DocsDatabase::export_csv $table
    }
    DocsDatabase::export_json "documents"
    
    # tree.db aufbauen (Daten kommen via tree.py)
    puts "\n--- tree.db Initialisierung ---"
    TreeDatabase::init_schema
    log_info "db_manager" "Tree-Daten werden via tree.py Script befüllt"
    
    puts "\n[string repeat "=" 60]"
    puts "DATENBANKEN BEREIT"
    puts [string repeat "=" 60]
    puts "\nDatenbanken: $::DB_DIR/"
    puts "Exporte:     $::WORKSPACE/"
}

if {[info script] eq $argv0} {
    main
}
