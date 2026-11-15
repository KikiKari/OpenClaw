// abstraction-provenance: {"artifact_sha256": "9f135ecd28c1341bdfa44ac7b61960c60f020b39cb4b810f1b7337b799c29fe7", "source_sha256": "8d48f51942bb1c171bbd41e0696beb0722cb4b94d6596233f54b32928b645086", "target_language": "go"}
// db_maintainer.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
*/

package main

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

var (
	WORKSPACE   string
	DB_DIR      string
	BACKUP_DIR  string
	LOG_DIR     string
	IMPORTANT_DIR string
)

func init() {
	if ws := os.Getenv("OPENCLAW_WORKSPACE"); ws != "" {
		WORKSPACE = ws
	} else {
		exe, _ := os.Executable()
		WORKSPACE = filepath.Dir(filepath.Dir(exe))
	}
	DB_DIR = WORKSPACE
	BACKUP_DIR = filepath.Join(WORKSPACE, "db", "backups")
	LOG_DIR = filepath.Join(WORKSPACE, "logs", "db-maintainer")
	IMPORTANT_DIR = filepath.Join(WORKSPACE, "important")

	os.MkdirAll(BACKUP_DIR, 0755)
	os.MkdirAll(LOG_DIR, 0755)
	os.MkdirAll(IMPORTANT_DIR, 0755)
}

type Logger struct {
	logFile *os.File
}

func NewLogger() *Logger {
	today := time.Now().Format("2006-01-02")
	logPath := filepath.Join(LOG_DIR, today+".log")
	file, _ := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	return &Logger{logFile: file}
}

func (l *Logger) Close() {
	if l.logFile != nil {
		l.logFile.Close()
	}
}

func (l *Logger) log(level, message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] [%s] %s\n", timestamp, level, message)
	fmt.Print(line)
	if l.logFile != nil {
		l.logFile.WriteString(line)
	}
}

func (l *Logger) Info(msg string)  { l.log("INFO", msg) }
func (l *Logger) Warn(msg string)  { l.log("WARN", msg) }
func (l *Logger) Error(msg string) { l.log("ERROR", msg) }

type State struct {
	LastCheck       *time.Time           `json:"last_check"`
	LastBackup      *time.Time           `json:"last_backup"`
	LastTreeUpdate  *time.Time           `json:"last_tree_update"`
	FileHashes      map[string]string    `json:"file_hashes"`
}

type Document struct {
	Path string `json:"path"`
	Hash string `json:"hash"`
	MTime int64 `json:"mtime"`
}

type DatabaseMaintainer struct {
	logger *Logger
	stateFile string
	retentionDays int
}

func NewDatabaseMaintainer() *DatabaseMaintainer {
	return &DatabaseMaintainer{
		logger: NewLogger(),
		stateFile: filepath.Join(DB_DIR, "maintainer_state.json"),
		retentionDays: 3,
	}
}

func (dm *DatabaseMaintainer) LoadState() *State {
	state := &State{
		FileHashes: make(map[string]string),
	}
	
	if _, err := os.Stat(dm.stateFile); err == nil {
		data, _ := os.ReadFile(dm.stateFile)
		json.Unmarshal(data, state)
	}
	
	return state
}

func (dm *DatabaseMaintainer) SaveState(state *State) {
	data, _ := json.MarshalIndent(state, "", "  ")
	os.WriteFile(dm.stateFile, data, 0644)
}

func (dm *DatabaseMaintainer) GetFileHash(filepath string) string {
	file, err := os.Open(filepath)
	if err != nil {
		return ""
	}
	defer file.Close()

	hash := md5.New()
	if _, err := io.Copy(hash, file); err != nil {
		return ""
	}
	
	return hex.EncodeToString(hash.Sum(nil))
}

func (dm *DatabaseMaintainer) pythonTreeFallback(maxDepth int) string {
	var lines []string
	lines = append(lines, WORKSPACE)
	
	var walk func(string, string, int)
	walk = func(dirpath, prefix string, depth int) {
		if depth > maxDepth {
			return
		}
		
		entries, err := os.ReadDir(dirpath)
		if err != nil {
			return
		}
		
		// Sort entries: directories first, then files, both alphabetically
		sort.Slice(entries, func(i, j int) bool {
			iIsDir := entries[i].IsDir()
			jIsDir := entries[j].IsDir()
			
			if iIsDir && !jIsDir {
				return true
			}
			if !iIsDir && jIsDir {
				return false
			}
			return entries[i].Name() < entries[j].Name()
		})
		
		for i, entry := range entries {
			connector := "├── "
			if i == len(entries)-1 {
				connector = "└── "
			}
			lines = append(lines, prefix+connector+entry.Name())
			
			if entry.IsDir() {
				extension := "│   "
				if i == len(entries)-1 {
					extension = "    "
				}
				walk(filepath.Join(dirpath, entry.Name()), prefix+extension, depth+1)
			}
		}
	}
	
	walk(WORKSPACE, "", 1)
	return strings.Join(lines, "\n") + "\n"
}

func (dm *DatabaseMaintainer) RunTreeCommand() string {
	cmd := exec.Command("tree", "-a", "-L", "8", WORKSPACE)
	output, err := cmd.Output()
	
	if err == nil {
		dm.logger.Info("tree -a -L 8 erfolgreich ausgeführt")
		return string(output)
	}
	
	dm.logger.Warn(fmt.Sprintf("tree command fehlgeschlagen: %v – nutze Python-Fallback", err))
	return dm.pythonTreeFallback(8)
}

func (dm *DatabaseMaintainer) UpdateTreeFile(treeOutput string) bool {
	if treeOutput == "" {
		return false
	}
	
	treeFile := filepath.Join(IMPORTANT_DIR, "openclaw-tree.txt")
	header := fmt.Sprintf(`# OpenClaw Workspace Tree
# Generiert: %s
# Befehl: tree -a -L 8 %s
# Diese Datei wird automatisch von db-maintainer aktualisiert

`, time.Now().Format(time.RFC3339), WORKSPACE)
	
	err := os.WriteFile(treeFile, []byte(header+treeOutput), 0644)
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Fehler beim Schreiben von openclaw-tree.txt: %v", err))
		return false
	}
	
	dm.logger.Info(fmt.Sprintf("openclaw-tree.txt aktualisiert: %s", treeFile))
	return true
}

func (dm *DatabaseMaintainer) ScanDocumentations() []Document {
	var docs []Document
	
	err := filepath.WalkDir(WORKSPACE, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		
		if strings.HasSuffix(d.Name(), ".md") {
			relPath, _ := filepath.Rel(WORKSPACE, path)
			
			// Skip backups and node_modules
			if strings.Contains(relPath, "db/backups") || strings.Contains(relPath, "node_modules") {
				return nil
			}
			
			info, _ := d.Info()
			doc := Document{
				Path: relPath,
				Hash: dm.GetFileHash(path),
				MTime: info.ModTime().Unix(),
			}
			docs = append(docs, doc)
		}
		
		return nil
	})
	
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Fehler beim Scannen der Dokumentationen: %v", err))
	}
	
	return docs
}

func (dm *DatabaseMaintainer) CheckForChanges() ([]string, map[string]string) {
	state := dm.LoadState()
	currentDocs := dm.ScanDocumentations()
	
	var changes []string
	currentHashes := make(map[string]string)
	
	for _, doc := range currentDocs {
		path := doc.Path
		currentHashes[path] = doc.Hash
		
		if _, exists := state.FileHashes[path]; !exists {
			changes = append(changes, "NEW: "+path)
		} else if state.FileHashes[path] != doc.Hash {
			changes = append(changes, "CHANGED: "+path)
		}
	}
	
	// Prüfe auf gelöschte Dateien
	for oldPath := range state.FileHashes {
		if _, exists := currentHashes[oldPath]; !exists {
			changes = append(changes, "DELETED: "+oldPath)
		}
	}
	
	return changes, currentHashes
}

func (dm *DatabaseMaintainer) UpdateDatabases() bool {
	scriptPath := filepath.Join(WORKSPACE, "scripts", "update_docs_db.py")
	cmd := exec.Command("python3", scriptPath)
	output, err := cmd.CombinedOutput()
	
	if err != nil {
		dm.logger.Error(fmt.Sprintf("DB-Update fehlgeschlagen: %s", string(output)))
		return false
	}
	
	dm.logger.Info("docs.db aktualisiert")
	return true
}

func (dm *DatabaseMaintainer) UpdateTreeDbV2() bool {
	scriptPath := filepath.Join(WORKSPACE, "scripts", "tree_indexer_v2.py")
	cmd := exec.Command("python3", scriptPath)
	output, err := cmd.CombinedOutput()
	
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Tree-DB v2 fehlgeschlagen: %s", string(output)))
		return false
	}
	
	dm.logger.Info("tree.db v2 aktualisiert")
	return true
}

func (dm *DatabaseMaintainer) CreateBackup() string {
	timestamp := time.Now().Format("2006-01-02_15-04")
	
	for _, dbName := range []string{"docs.db", "tree.db"} {
		source := filepath.Join(DB_DIR, dbName)
		if _, err := os.Stat(source); err == nil {
			backupName := fmt.Sprintf("%s_%s.bak", timestamp, dbName)
			backupPath := filepath.Join(BACKUP_DIR, backupName)
			
			input, _ := os.ReadFile(source)
			os.WriteFile(backupPath, input, 0644)
			dm.logger.Info(fmt.Sprintf("Backup erstellt: %s", backupName))
		}
	}
	
	return timestamp
}

func (dm *DatabaseMaintainer) CleanupOldBackups() {
	cutoff := time.Now().AddDate(0, 0, -dm.retentionDays)
	deleted := 0
	
	for _, dbName := range []string{"docs.db", "tree.db"} {
		pattern := filepath.Join(BACKUP_DIR, fmt.Sprintf("*_%s.bak", dbName))
		matches, _ := filepath.Glob(pattern)
		
		for _, backup := range matches {
			filename := filepath.Base(backup)
			parts := strings.Split(filename, "_")
			if len(parts) >= 2 {
				dateStr := parts[0]
				timeStr := parts[1]
				
				backupTime, err := time.Parse("2006-01-02_15-04", dateStr+"_"+strings.TrimSuffix(timeStr, ".bak"))
				if err != nil {
					dm.logger.Warn(fmt.Sprintf("Konnte Backup-Datum nicht parsen: %s", filename))
					continue
				}
				
				if backupTime.Before(cutoff) {
					os.Remove(backup)
					deleted++
					dm.logger.Info(fmt.Sprintf("Altes Backup gelöscht: %s", filename))
				}
			}
		}
	}
	
	if deleted == 0 {
		dm.logger.Info("Keine alten Backups zum Löschen")
	} else {
		dm.logger.Info(fmt.Sprintf("%d alte Backups gelöscht (< 3 Tage)", deleted))
	}
}

func (dm *DatabaseMaintainer) RunCycle() {
	dm.logger.Info(strings.Repeat("=", 60))
	dm.logger.Info("DB MAINTAINER CYCLE START")
	dm.logger.Info(strings.Repeat("=", 60))
	
	state := dm.LoadState()
	
	// 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
	dm.logger.Info("Führe tree -a -L 8 aus...")
	treeOutput := dm.RunTreeCommand()
	if treeOutput != "" {
		dm.UpdateTreeFile(treeOutput)
		now := time.Now()
		state.LastTreeUpdate = &now
	}
	
	// 2. tree.db aktualisieren (intern v2)
	dm.logger.Info("Aktualisiere tree.db v2...")
	dm.UpdateTreeDbV2()
	
	// 3. Änderungen prüfen
	dm.logger.Info("Prüfe auf Dokumentations-Änderungen...")
	changes, currentHashes := dm.CheckForChanges()
	
	if len(changes) > 0 {
		dm.logger.Info(fmt.Sprintf("%d Änderungen gefunden:", len(changes)))
		for i, change := range changes {
			if i >= 10 {
				dm.logger.Info(fmt.Sprintf("  ... und %d weitere", len(changes)-10))
				break
			}
			dm.logger.Info(fmt.Sprintf("  - %s", change))
		}
		
		// 4. docs.db aktualisieren
		dm.logger.Info("Aktualisiere docs.db...")
		if dm.UpdateDatabases() {
			now := time.Now()
			state.LastCheck = &now
			state.FileHashes = currentHashes
		}
	} else {
		dm.logger.Info("Keine Dokumentations-Änderungen gefunden")
	}
	
	// 5. Prüfe ob Backup fällig (stündlich)
	doBackup := state.LastBackup == nil
	if state.LastBackup != nil {
		duration := time.Since(*state.LastBackup)
		doBackup = duration >= time.Hour
	}
	
	if doBackup {
		dm.logger.Info("Erstelle stündliches Backup...")
		dm.CreateBackup()
		now := time.Now()
		state.LastBackup = &now
		
		// 6. Alte Backups aufräumen (3 Tage Retention)
		dm.logger.Info("Räume alte Backups auf (3 Tage Retention)...")
		dm.CleanupOldBackups()
	} else {
		dm.logger.Info("Backup nicht nötig (letztes < 1h)")
	}
	
	dm.SaveState(state)
	
	dm.logger.Info(strings.Repeat("=", 60))
	dm.logger.Info("DB MAINTAINER CYCLE END")
	dm.logger.Info(strings.Repeat("=", 60))
	
	dm.logger.Close()
}

func main() {
	maintainer := NewDatabaseMaintainer()
	
	defer func() {
		if r := recover(); r != nil {
			maintainer.logger.Error(fmt.Sprintf("CRITICAL ERROR: %v", r))
			os.Exit(1)
		}
	}()
	
	maintainer.RunCycle()
}
