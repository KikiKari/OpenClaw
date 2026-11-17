// abstraction-provenance: {"artifact_sha256": "e5c269633df463713c354d7091bab8bdd47fc97aad95e2a032e7778e09c5c9ac", "source_sha256": "62685d1bad45f2dffb79d4424a8a668a222d4008e157a9d6b51a3e2a1d1d204d", "target_language": "go"}
// db_manager.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:scripts/db_manager.py
// auch in: OpenClaw@gateway2:scripts/db_manager.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/*
Workspace Documentation Database Manager

Erstellt und verwaltet docs.db und tree.db im Workspace-Datenbankverzeichnis.
Beide Datenbanken liegen unter $OPENCLAW_WORKSPACE/db/.

Verwendung:
    go run db_manager.go

Konfiguration:
    OPENCLAW_WORKSPACE (Umgebungsvariable) — Standard: /home/openclaw/.openclaw/workspace
*/

package main

import (
	"context"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

// ---------------------------------------------------------------------------
// Konfiguration
// ---------------------------------------------------------------------------

var (
	WORKSPACE string
	DB_DIR    string
)

func init() {
	WORKSPACE = os.Getenv("OPENCLAW_WORKSPACE")
	if WORKSPACE == "" {
		WORKSPACE = "/home/openclaw/.openclaw/workspace"
	}
	DB_DIR = filepath.Join(WORKSPACE, "db")
}

// Erlaubte Tabellennamen für Export-Methoden (verhindert SQL-Injection)
var DOCS_EXPORT_TABLES = map[string]bool{
	"documents": true,
	"categories": true,
	"symlinks": true,
	"skills": true,
}

var TREE_EXPORT_TABLES = map[string]bool{
	"tree_entries": true,
	"tree_scans": true,
}

// ---------------------------------------------------------------------------
// Logger
// ---------------------------------------------------------------------------

type Logger struct {
	prefix string
}

func NewLogger(prefix string) *Logger {
	return &Logger{prefix: prefix}
}

func (l *Logger) Info(format string, v ...interface{}) {
	log.Printf("%s | INFO     | %s | %s", time.Now().Format("2006-01-02 15:04:05"), l.prefix, fmt.Sprintf(format, v...))
}

func (l *Logger) Error(format string, v ...interface{}) {
	log.Printf("%s | ERROR    | %s | %s", time.Now().Format("2006-01-02 15:04:05"), l.prefix, fmt.Sprintf(format, v...))
}

var logger = NewLogger("db_manager")

// ---------------------------------------------------------------------------
// DocsDatabase
// ---------------------------------------------------------------------------

type DocsDatabase struct {
	dbPath string
	logger *Logger
}

func NewDocsDatabase() *DocsDatabase {
	return &DocsDatabase{
		dbPath: filepath.Join(DB_DIR, "docs.db"),
		logger: NewLogger("DocsDatabase"),
	}
}

func (db *DocsDatabase) getConnection() (*sql.DB, error) {
	conn, err := sql.Open("sqlite3", db.dbPath)
	if err != nil {
		return nil, err
	}
	return conn, nil
}

func (db *DocsDatabase) InitSchema() error {
	conn, err := db.getConnection()
	if err != nil {
		return err
	}
	defer conn.Close()

	_, err = conn.Exec(`
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
	`)
	if err != nil {
		return err
	}

	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS categories (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			name        TEXT    UNIQUE NOT NULL,
			description TEXT,
			priority    INTEGER DEFAULT 0
		)
	`)
	if err != nil {
		return err
	}

	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS symlinks (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			name        TEXT    NOT NULL,
			target      TEXT    NOT NULL,
			source_path TEXT    NOT NULL,
			description TEXT,
			created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		return err
	}

	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS skills (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			name        TEXT    NOT NULL,
			version     TEXT,
			status      TEXT    CHECK(status IN ('installed', 'local', 'published')),
			description TEXT,
			path        TEXT
		)
	`)
	if err != nil {
		return err
	}

	db.logger.Info("docs.db Schema initialisiert: %s", db.dbPath)
	return nil
}

func (db *DocsDatabase) PopulateFromWorkspace() error {
	categories := [][]interface{}{
		{"main", "Hauptverzeichnis Dateien", 1},
		{"memory", "Memory und Protokolle", 2},
		{"reports", "Berichte und Analysen", 3},
		{"cluster", "Cluster und Infrastruktur", 4},
		{"skills", "Installierte Skills", 5},
		{"websearch", "WebSearch Dokumentationen", 6},
		{"mcp", "MCP Integration", 7},
		{"links", "Symbolische Links", 8},
	}

	docs := [][]interface{}{
		{"AGENTS.md", "/", "main", "Agent-Konfiguration, Memory-Regeln", "config", false, nil, "2026-04-11"},
		{"SOUL.md", "/", "main", "Agent-Persönlichkeit und Kernwahrheiten", "config", false, nil, "2026-04-11"},
		{"IDENTITY.md", "/", "main", "Agent-Name und Eigenschaften", "config", false, nil, "2026-04-11"},
		{"USER.md", "/", "main", "Benutzerinformationen", "config", false, nil, "2026-04-11"},
		{"TOOLS.md", "/", "main", "Tool-spezifische Konfigurationen", "config", false, nil, "2026-04-18"},
		{"MEMORY.md", "/", "main", "Langzeitspeicher, System-Konfiguration", "config", false, nil, "2026-04-11"},
		{"DOCUMENTATION-INDEX.md", "/", "main", "Übersicht aller Dokumentationen", "doc", false, nil, "2026-04-18"},
		{"WORKSPACE-INDEX.md", "/", "main", "Symlink zu DOCUMENTATION-INDEX.md", "symlink", true, "DOCUMENTATION-INDEX.md", "2026-04-18"},
		{"WEBSEARCH_README.md", "websearch/", "websearch", "Schnellstart Guide", "guide", true, "websearch/WEBSEARCH_README.md", "2026-04-18"},
		{"WEBSEARCH_MCP_GUIDE.md", "websearch/", "websearch", "Vollständige technische Dokumentation", "guide", true, "websearch/WEBSEARCH_MCP_GUIDE.md", "2026-04-18"},
		{"WEBSEARCH_CONFIG.md", "websearch/", "websearch", "Konfigurations-Referenz", "config", true, "websearch/WEBSEARCH_CONFIG.md", "2026-04-18"},
		{"WEBSEARCH_PRIORITY_CONFIG.md", "websearch/", "websearch", "Provider-Priorität", "config", true, "websearch/WEBSEARCH_PRIORITY_CONFIG.md", "2026-04-18"},
		{"WEBSEARCH_SCRIPTS.md", "websearch/", "websearch", "Automation & Scripting", "script", true, "websearch/WEBSEARCH_SCRIPTS.md", "2026-04-18"},
		{"WEBSEARCH_OPS.md", "websearch/", "websearch", "IT-Operations", "guide", true, "websearch/WEBSEARCH_OPS.md", "2026-04-18"},
		{"MCP_GUIDE.md", "mcp/", "mcp", "Symlink zu websearch/WEBSEARCH_MCP_GUIDE.md", "symlink", false, "websearch/WEBSEARCH_MCP_GUIDE.md", "2026-04-18"},
	}

	skills := [][]interface{}{
		{"json-utils", "1.0.0", "installed", "JSON parsing and validation", "skills/json-utils/"},
		{"scripting-utils", "1.0.0", "installed", "Multi-language scripting support", "skills/scripting-utils/"},
		{"tiktok-live-mon", "1.0.0", "installed", "TikTok stream monitoring", "skills/tiktok-live-mon/"},
		{"cluster-management", "1.0.0", "installed", "Cluster topology management", "skills/cluster-management/"},
		{"worker-node", "-", "local", "Worker node configuration", "skills/worker-node/"},
		{"resource-manager", "-", "local", "Resource management", "skills/resource-manager/"},
		{"git-publish-agent", "1.0.0", "local", "Git publishing automation", "skills/git-publish-agent/"},
	}

	symlinks := [][]interface{}{
		{"openclaw.env", "/home/openclaw/.config/openclaw/env", "/", "API-Keys Shortcut"},
		{"openclaw.json", "/home/openclaw/.openclaw/openclaw.json", "/", "Konfig Shortcut"},
		{"links/config/openclaw-env", "/home/openclaw/.config/openclaw/env", "links/config/", "API-Keys"},
		{"links/dotfiles/.tavily", "/home/openclaw/.tavily/", "links/dotfiles/", "Tavily Config"},
		{"links/dotfiles/.claude", "/home/openclaw/.claude/", "links/dotfiles/", "Claude Config"},
		{"links/dotfiles/.mcporter", "/home/openclaw/.mcporter/", "links/dotfiles/", "MCPorter Config"},
		{"links/dotfiles/.ssh", "/home/openclaw/.ssh/", "links/dotfiles/", "SSH Keys"},
	}

	conn, err := db.getConnection()
	if err != nil {
		return err
	}
	defer conn.Close()

	tx, err := conn.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare("INSERT OR IGNORE INTO categories (name, description, priority) VALUES (?,?,?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, category := range categories {
		_, err = stmt.Exec(category...)
		if err != nil {
			return err
		}
	}

	stmt, err = tx.Prepare(`INSERT OR REPLACE INTO documents 
		(name, path, category, description, type, has_symlink, symlink_path, last_update) 
		VALUES (?,?,?,?,?,?,?,?)`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, doc := range docs {
		_, err = stmt.Exec(doc...)
		if err != nil {
			return err
		}
	}

	stmt, err = tx.Prepare("INSERT OR REPLACE INTO skills (name, version, status, description, path) VALUES (?,?,?,?,?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, skill := range skills {
		_, err = stmt.Exec(skill...)
		if err != nil {
			return err
		}
	}

	stmt, err = tx.Prepare("INSERT OR REPLACE INTO symlinks (name, target, source_path, description) VALUES (?,?,?,?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, symlink := range symlinks {
		_, err = stmt.Exec(symlink...)
		if err != nil {
			return err
		}
	}

	err = tx.Commit()
	if err != nil {
		return err
	}

	db.logger.Info("docs.db befüllt: %d Dokumente, %d Skills, %d Symlinks", len(docs), len(skills), len(symlinks))
	return nil
}

func (db *DocsDatabase) validateTableName(table string, allowed map[string]bool) error {
	if !allowed[table] {
		keys := make([]string, 0, len(allowed))
		for k := range allowed {
			keys = append(keys, k)
		}
		return fmt.Errorf("Ungültiger Tabellenname: '%s'. Erlaubt: %v", table, keys)
	}
	return nil
}

func (db *DocsDatabase) ExportCSV(table string) (string, error) {
	err := db.validateTableName(table, DOCS_EXPORT_TABLES)
	if err != nil {
		return "", err
	}

	conn, err := db.getConnection()
	if err != nil {
		return "", err
	}
	defer conn.Close()

	query := fmt.Sprintf("SELECT * FROM %s", table)
	rows, err := conn.Query(query)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	columns, err := rows.Columns()
	if err != nil {
		return "", err
	}

	values := make([][]string, 0)
	for rows.Next() {
		row := make([]interface{}, len(columns))
		rowPtr := make([]interface{}, len(columns))
		for i := range row {
			rowPtr[i] = &row[i]
		}

		err = rows.Scan(rowPtr...)
		if err != nil {
			return "", err
		}

		strRow := make([]string, len(columns))
		for i, val := range row {
			strRow[i] = fmt.Sprintf("%v", val)
		}
		values = append(values, strRow)
	}

	if len(values) == 0 {
		db.logger.Info("Tabelle '%s' ist leer — kein CSV erzeugt", table)
		return "", nil
	}

	csvPath := filepath.Join(WORKSPACE, fmt.Sprintf("export_%s.csv", table))
	file, err := os.Create(csvPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	err = writer.Write(columns)
	if err != nil {
		return "", err
	}

	for _, row := range values {
		err = writer.Write(row)
		if err != nil {
			return "", err
		}
	}

	db.logger.Info("CSV exportiert: %s (%d Zeilen)", csvPath, len(values))
	return csvPath, nil
}

func (db *DocsDatabase) ExportJSON(table string) (string, error) {
	err := db.validateTableName(table, DOCS_EXPORT_TABLES)
	if err != nil {
		return "", err
	}

	conn, err := db.getConnection()
	if err != nil {
		return "", err
	}
	defer conn.Close()

	query := fmt.Sprintf("SELECT * FROM %s", table)
	rows, err := conn.Query(query)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	columns, err := rows.Columns()
	if err != nil {
		return "", err
	}

	values := make([]map[string]interface{}, 0)
	for rows.Next() {
		row := make([]interface{}, len(columns))
		rowPtr := make([]interface{}, len(columns))
		for i := range row {
			rowPtr[i] = &row[i]
		}

		err = rows.Scan(rowPtr...)
		if err != nil {
			return "", err
		}

		rowMap := make(map[string]interface{})
		for i, col := range columns {
			val := row[i]
			if val == nil {
				rowMap[col] = nil
			} else {
				rowMap[col] = val
			}
		}
		values = append(values, rowMap)
	}

	if len(values) == 0 {
		db.logger.Info("Tabelle '%s' ist leer — kein JSON erzeugt", table)
		return "", nil
	}

	jsonPath := filepath.Join(WORKSPACE, fmt.Sprintf("export_%s.json", table))
	file, err := os.Create(jsonPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	err = encoder.Encode(values)
	if err != nil {
		return "", err
	}

	db.logger.Info("JSON exportiert: %s (%d Einträge)", jsonPath, len(values))
	return jsonPath, nil
}

// ---------------------------------------------------------------------------
// TreeDatabase
// ---------------------------------------------------------------------------

type TreeDatabase struct {
	dbPath string
	logger *Logger
}

func NewTreeDatabase() *TreeDatabase {
	return &TreeDatabase{
		dbPath: filepath.Join(DB_DIR, "tree.db"),
		logger: NewLogger("TreeDatabase"),
	}
}

func (db *TreeDatabase) getConnection() (*sql.DB, error) {
	conn, err := sql.Open("sqlite3", db.dbPath)
	if err != nil {
		return nil, err
	}
	return conn, nil
}

func (db *TreeDatabase) InitSchema() error {
	conn, err := db.getConnection()
	if err != nil {
		return err
	}
	defer conn.Close()

	_, err = conn.Exec(`
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
	`)
	if err != nil {
		return err
	}

	_, err = conn.Exec(`
		CREATE TABLE IF NOT EXISTS tree_scans (
			id             INTEGER PRIMARY KEY AUTOINCREMENT,
			root_path      TEXT    NOT NULL,
			max_depth      INTEGER,
			total_files    INTEGER,
			total_dirs     INTEGER,
			total_symlinks INTEGER,
			scanned_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		return err
	}

	db.logger.Info("tree.db Schema initialisiert: %s", db.dbPath)
	return nil
}

func (db *TreeDatabase) AddEntry(rootPath, relativePath, name, entryType string, depth int, parentPath string, size int) error {
	conn, err := db.getConnection()
	if err != nil {
		return err
	}
	defer conn.Close()

	_, err = conn.Exec(`
		INSERT INTO tree_entries 
		(root_path, relative_path, name, type, depth, parent_path, size)
		VALUES (?,?,?,?,?,?,?)`,
		rootPath, relativePath, name, entryType, depth, parentPath, size)
	if err != nil {
		return err
	}

	return nil
}

func (db *TreeDatabase) ExportCSV(rootPathFilter *string) (string, error) {
	conn, err := db.getConnection()
	if err != nil {
		return "", err
	}
	defer conn.Close()

	var rows *sql.Rows
	if rootPathFilter != nil {
		rows, err = conn.Query("SELECT * FROM tree_entries WHERE root_path = ?", *rootPathFilter)
	} else {
		rows, err = conn.Query("SELECT * FROM tree_entries")
	}
	if err != nil {
		return "", err
	}
	defer rows.Close()

	columns, err := rows.Columns()
	if err != nil {
		return "", err
	}

	values := make([][]string, 0)
	for rows.Next() {
		row := make([]interface{}, len(columns))
		rowPtr := make([]interface{}, len(columns))
		for i := range row {
			rowPtr[i] = &row[i]
		}

		err = rows.Scan(rowPtr...)
		if err != nil {
			return "", err
		}

		strRow := make([]string, len(columns))
		for i, val := range row {
			strRow[i] = fmt.Sprintf("%v", val)
		}
		values = append(values, strRow)
	}

	if len(values) == 0 {
		db.logger.Info("Keine Tree-Einträge vorhanden — kein CSV erzeugt")
		return "", nil
	}

	suffix := "_all"
	if rootPathFilter != nil {
		suffix = "_" + strings.Replace(*rootPathFilter, "/", "_", -1)
	}
	csvPath := filepath.Join(WORKSPACE, fmt.Sprintf("export_tree%s.csv", suffix))

	file, err := os.Create(csvPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	err = writer.Write(columns)
	if err != nil {
		return "", err
	}

	for _, row := range values {
		err = writer.Write(row)
		if err != nil {
			return "", err
		}
	}

	db.logger.Info("Tree-CSV exportiert: %s (%d Einträge)", csvPath, len(values))
	return csvPath, nil
}

// ---------------------------------------------------------------------------
// Einstiegspunkt
// ---------------------------------------------------------------------------

func main() {
	fmt.Println("=" + strings.Repeat("=", 59))
	fmt.Println("WORKSPACE DATABASE MANAGER")
	fmt.Println("=" + strings.Repeat("=", 59))

	// DB-Verzeichnis hier (nicht auf Modulebene) anlegen
	err := os.MkdirAll(DB_DIR, 0755)
	if err != nil {
		logger.Error("DB-Verzeichnis konnte nicht erstellt werden: %v", err)
		os.Exit(1)
	}
	logger.Info("DB-Verzeichnis: %s", DB_DIR)

	// docs.db aufbauen
	docsDB := NewDocsDatabase()
	err = docsDB.InitSchema()
	if err != nil {
		logger.Error("Fehler bei der Initialisierung von docs.db: %v", err)
		os.Exit(1)
	}

	err = docsDB.PopulateFromWorkspace()
	if err != nil {
		logger.Error("Fehler beim Befüllen von docs.db: %v", err)
		os.Exit(1)
	}

	// Exporte
	fmt.Println("\n--- Exporte docs.db ---")
	for _, table := range []string{"documents", "skills", "symlinks"} {
		_, err = docsDB.ExportCSV(table)
		if err != nil {
			logger.Error("Fehler beim CSV-Export von %s: %v", table, err)
		}
	}

	_, err = docsDB.ExportJSON("documents")
	if err != nil {
		logger.Error("Fehler beim JSON-Export von documents: %v", err)
	}

	// tree.db aufbauen (Daten kommen via tree.py)
	fmt.Println("\n--- tree.db Initialisierung ---")
	treeDB := NewTreeDatabase()
	err = treeDB.InitSchema()
	if err != nil {
		logger.Error("Fehler bei der Initialisierung von tree.db: %v", err)
		os.Exit(1)
	}
	logger.Info("Tree-Daten werden via tree.py Script befüllt")

	fmt.Println("\n" + "=" + strings.Repeat("=", 59))
	fmt.Println("DATENBANKEN BEREIT")
	fmt.Println("=" + strings.Repeat("=", 59))
	fmt.Printf("\nDatenbanken: %s/\n", DB_DIR)
	fmt.Printf("Exporte:     %s/\n", WORKSPACE)
}
