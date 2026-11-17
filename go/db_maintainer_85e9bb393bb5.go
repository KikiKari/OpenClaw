// abstraction-provenance: {"artifact_sha256": "2bca64e1aed83e0b2f4ebfecff43fe92d439b47c05589ed36e484634af9d18f0", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "go"}
// db_maintainer.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

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
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var (
	WORKSPACE    = "/home/openclaw/.openclaw/workspace"
	DB_DIR       = WORKSPACE + "/db"
	BACKUP_DIR   = DB_DIR + "/backups"
	LOG_DIR      = WORKSPACE + "/logs/db-maintainer"
	IMPORTANT_DIR = WORKSPACE + "/important"
)

func initDirs() {
	os.MkdirAll(BACKUP_DIR, 0755)
	os.MkdirAll(LOG_DIR, 0755)
}

type Logger struct {
	logFile *os.File
}

func NewLogger() *Logger {
	today := time.Now().Format("2006-01-02")
	logPath := filepath.Join(LOG_DIR, today+".log")
	
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		panic(err)
	}
	
	return &Logger{logFile: file}
}

func (l *Logger) log(level string, message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] [%s] %s\n", timestamp, level, message)
	fmt.Print(line)
	l.logFile.WriteString(line)
}

func (l *Logger) Info(msg string)  { l.log("INFO", msg) }
func (l *Logger) Warn(msg string)  { l.log("WARN", msg) }
func (l *Logger) Error(msg string) { l.log("ERROR", msg) }

type State struct {
	LastCheck      *time.Time           `json:"last_check"`
	LastBackup     *time.Time           `json:"last_backup"`
	LastTreeUpdate *time.Time           `json:"last_tree_update"`
	FileHashes     map[string]string    `json:"file_hashes"`
}

type DatabaseMaintainer struct {
	logger    *Logger
	stateFile string
	retentionDays int
}

func NewDatabaseMaintainer() *DatabaseMaintainer {
	return &DatabaseMaintainer{
		logger:        NewLogger(),
		stateFile:     filepath.Join(DB_DIR, "maintainer_state.json"),
		retentionDays: 3,
	}
}

func (dm *DatabaseMaintainer) loadState() *State {
	state := &State{
		FileHashes: make(map[string]string),
	}
	
	if _, err := os.Stat(dm.stateFile); err == nil {
		data, err := os.ReadFile(dm.stateFile)
		if err != nil {
			dm.logger.Error(fmt.Sprintf("Failed to read state file: %v", err))
			return state
		}
		
		var savedState struct {
			LastCheck      *string            `json:"last_check"`
			LastBackup     *string            `json:"last_backup"`
			LastTreeUpdate *string            `json:"last_tree_update"`
			FileHashes     map[string]string  `json:"file_hashes"`
		}
		
		if err := json.Unmarshal(data, &savedState); err != nil {
			dm.logger.Error(fmt.Sprintf("Failed to parse state file: %v", err))
			return state
		}
		
		if savedState.LastCheck != nil {
			if t, err := time.Parse(time.RFC3339, *savedState.LastCheck); err == nil {
				state.LastCheck = &t
			}
		}
		
		if savedState.LastBackup != nil {
			if t, err := time.Parse(time.RFC3339, *savedState.LastBackup); err == nil {
				state.LastBackup = &t
			}
		}
		
		if savedState.LastTreeUpdate != nil {
			if t, err := time.Parse(time.RFC3339, *savedState.LastTreeUpdate); err == nil {
				state.LastTreeUpdate = &t
			}
		}
		
		state.FileHashes = savedState.FileHashes
	}
	
	return state
}

func (dm *DatabaseMaintainer) saveState(state *State) {
	savedState := struct {
		LastCheck      *string            `json:"last_check"`
		LastBackup     *string            `json:"last_backup"`
		LastTreeUpdate *string            `json:"last_tree_update"`
		FileHashes     map[string]string  `json:"file_hashes"`
	}{
		FileHashes: state.FileHashes,
	}
	
	if state.LastCheck != nil {
		str := state.LastCheck.Format(time.RFC3339)
		savedState.LastCheck = &str
	}
	
	if state.LastBackup != nil {
		str := state.LastBackup.Format(time.RFC3339)
		savedState.LastBackup = &str
	}
	
	if state.LastTreeUpdate != nil {
		str := state.LastTreeUpdate.Format(time.RFC3339)
		savedState.LastTreeUpdate = &str
	}
	
	data, err := json.MarshalIndent(savedState, "", "  ")
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Failed to marshal state: %v", err))
		return
	}
	
	if err := os.WriteFile(dm.stateFile, data, 0644); err != nil {
		dm.logger.Error(fmt.Sprintf("Failed to write state file: %v", err))
	}
}

func (dm *DatabaseMaintainer) getFileHash(filepath string) string {
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

func (dm *DatabaseMaintainer) runTreeCommand() string {
	cmd := exec.Command("tree", "-a", "-L", "8", WORKSPACE)
	cmd.Timeout = 60 * time.Second
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		dm.logger.Error(fmt.Sprintf("tree command failed: %v", err))
		return ""
	}
	
	dm.logger.Info("tree -a -L 8 successfully executed")
	return string(output)
}

func (dm *DatabaseMaintainer) updateTreeFile(treeOutput string) bool {
	if treeOutput == "" {
		return false
	}
	
	treeFile := filepath.Join(IMPORTANT_DIR, "openclaw-tree.txt")
	
	header := fmt.Sprintf(`# OpenClaw Workspace Tree
# Generated: %s
# Command: tree -a -L 8 %s
# This file is automatically updated by db-maintainer

`, time.Now().Format(time.RFC3339), WORKSPACE)
	
	content := header + treeOutput
	
	if err := os.WriteFile(treeFile, []byte(content), 0644); err != nil {
		dm.logger.Error(fmt.Sprintf("Error writing openclaw-tree.txt: %v", err))
		return false
	}
	
	dm.logger.Info(fmt.Sprintf("openclaw-tree.txt updated: %s", treeFile))
	return true
}

func (dm *DatabaseMaintainer) scanDocumentations() []map[string]interface{} {
	var docs []map[string]interface{}
	
	err := filepath.Walk(WORKSPACE, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		
		relPath, _ := filepath.Rel(WORKSPACE, path)
		
		if strings.HasSuffix(path, ".md") && 
		   !strings.Contains(relPath, "db/backups") && 
		   !strings.Contains(relPath, "node_modules") {
			
			doc := map[string]interface{}{
				"path":  relPath,
				"hash":  dm.getFileHash(path),
				"mtime": info.ModTime().Unix(),
			}
			docs = append(docs, doc)
		}
		
		return nil
	})
	
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Error scanning documentations: %v", err))
	}
	
	return docs
}

func (dm *DatabaseMaintainer) checkForChanges() ([]string, map[string]string) {
	state := dm.loadState()
	currentDocs := dm.scanDocumentations()
	
	var changes []string
	currentHashes := make(map[string]string)
	
	for _, doc := range currentDocs {
		path := doc["path"].(string)
		hash := doc["hash"].(string)
		currentHashes[path] = hash
		
		if _, exists := state.FileHashes[path]; !exists {
			changes = append(changes, fmt.Sprintf("NEW: %s", path))
		} else if state.FileHashes[path] != hash {
			changes = append(changes, fmt.Sprintf("CHANGED: %s", path))
		}
	}
	
	for oldPath := range state.FileHashes {
		if _, exists := currentHashes[oldPath]; !exists {
			changes = append(changes, fmt.Sprintf("DELETED: %s", oldPath))
		}
	}
	
	return changes, currentHashes
}

func (dm *DatabaseMaintainer) updateDatabases() bool {
	scriptPath := filepath.Join(WORKSPACE, "scripts", "update_docs_db.py")
	cmd := exec.Command("python3", scriptPath)
	cmd.Timeout = 60 * time.Second
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		dm.logger.Error(fmt.Sprintf("DB update failed: %v - %s", err, string(output)))
		return false
	}
	
	dm.logger.Info("docs.db updated")
	return true
}

func (dm *DatabaseMaintainer) updateTreeDbV2() bool {
	scriptPath := filepath.Join(WORKSPACE, "scripts", "tree_indexer_v2.py")
	cmd := exec.Command("python3", scriptPath)
	cmd.Timeout = 120 * time.Second
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		dm.logger.Error(fmt.Sprintf("Tree-DB v2 failed: %v - %s", err, string(output)))
		return false
	}
	
	dm.logger.Info("tree.db v2 updated")
	return true
}

func (dm *DatabaseMaintainer) createBackup() string {
	timestamp := time.Now().Format("2006-01-02_15-04")
	
	for _, dbName := range []string{"docs.db", "tree.db"} {
		source := filepath.Join(DB_DIR, dbName)
		if _, err := os.Stat(source); err == nil {
			backupName := fmt.Sprintf("%s_%s.bak", timestamp, dbName)
			backupPath := filepath.Join(BACKUP_DIR, backupName)
			
			sourceFile, err := os.Open(source)
			if err != nil {
				dm.logger.Error(fmt.Sprintf("Failed to open source file: %v", err))
				continue
			}
			
			destFile, err := os.Create(backupPath)
			if err != nil {
				sourceFile.Close()
				dm.logger.Error(fmt.Sprintf("Failed to create backup file: %v", err))
				continue
			}
			
			_, err = io.Copy(destFile, sourceFile)
			sourceFile.Close()
			destFile.Close()
			
			if err != nil {
				dm.logger.Error(fmt.Sprintf("Failed to copy file: %v", err))
				continue
			}
			
			dm.logger.Info(fmt.Sprintf("Backup created: %s", backupName))
		}
	}
	
	return timestamp
}

func (dm *DatabaseMaintainer) cleanupOldBackups() {
	cutoff := time.Now().AddDate(0, 0, -dm.retentionDays)
	deleted := 0
	
	for _, dbName := range []string{"docs.db", "tree.db"} {
		pattern := filepath.Join(BACKUP_DIR, fmt.Sprintf("*_%s.bak", dbName))
		matches, err := filepath.Glob(pattern)
		if err != nil {
			dm.logger.Warn(fmt.Sprintf("Failed to glob backups: %v", err))
			continue
		}
		
		for _, backup := range matches {
			base := filepath.Base(backup)
			parts := strings.Split(base, "_")
			if len(parts) < 2 {
				dm.logger.Warn(fmt.Sprintf("Could not parse backup date: %s", base))
				continue
			}
			
			dateStr := parts[0]
			timeStr := strings.Split(parts[1], ".")[0]
			
			backupTime, err := time.Parse("2006-01-02_15-04", fmt.Sprintf("%s_%s", dateStr, timeStr))
			if err != nil {
				dm.logger.Warn(fmt.Sprintf("Could not parse backup date: %s", base))
				continue
			}
			
			if backupTime.Before(cutoff) {
				if err := os.Remove(backup); err != nil {
					dm.logger.Error(fmt.Sprintf("Failed to delete backup: %v", err))
					continue
				}
				deleted++
				dm.logger.Info(fmt.Sprintf("Deleted old backup: %s", filepath.Base(backup)))
			}
		}
	}
	
	if deleted == 0 {
		dm.logger.Info("No old backups to delete")
	} else {
		dm.logger.Info(fmt.Sprintf("%d old backups deleted (< 3 days)", deleted))
	}
}

func (dm *DatabaseMaintainer) runCycle() {
	dm.logger.Info(strings.Repeat("=", 60))
	dm.logger.Info("DB MAINTAINER CYCLE START")
	dm.logger.Info(strings.Repeat("=", 60))
	
	state := dm.loadState()
	
	// 1. Run tree command and write to openclaw-tree.txt
	dm.logger.Info("Running tree -a -L 8...")
	treeOutput := dm.runTreeCommand()
	if treeOutput != "" {
		dm.updateTreeFile(treeOutput)
		now := time.Now()
		state.LastTreeUpdate = &now
	}
	
	// 2. Update tree.db (internal v2)
	dm.logger.Info("Updating tree.db v2...")
	dm.updateTreeDbV2()
	
	// 3. Check for changes
	dm.logger.Info("Checking for documentation changes...")
	changes, currentHashes := dm.checkForChanges()
	
	if len(changes) > 0 {
		dm.logger.Info(fmt.Sprintf("%d changes found:", len(changes)))
		for i, change := range changes {
			if i >= 10 {
				dm.logger.Info(fmt.Sprintf("  ... and %d more", len(changes)-10))
				break
			}
			dm.logger.Info(fmt.Sprintf("  - %s", change))
		}
		
		// 4. Update docs.db
		dm.logger.Info("Updating docs.db...")
		if dm.updateDatabases() {
			now := time.Now()
			state.LastCheck = &now
			state.FileHashes = currentHashes
		}
	} else {
		dm.logger.Info("No documentation changes found")
	}
	
	// 5. Check if backup is due (hourly)
	doBackup := true
	if state.LastBackup != nil {
		doBackup = time.Since(*state.LastBackup) >= time.Hour
	}
	
	if doBackup {
		dm.logger.Info("Creating hourly backup...")
		timestamp := dm.createBackup()
		now := time.Now()
		state.LastBackup = &now
		
		// 6. Clean up old backups (3 days retention)
		dm.logger.Info("Cleaning up old backups (3 days retention)...")
		dm.cleanupOldBackups()
	} else {
		dm.logger.Info("Backup not needed (last < 1h)")
	}
	
	dm.saveState(state)
	
	dm.logger.Info(strings.Repeat("=", 60))
	dm.logger.Info("DB MAINTAINER CYCLE END")
	dm.logger.Info(strings.Repeat("=", 60))
}

func main() {
	initDirs()
	maintainer := NewDatabaseMaintainer()
	
	defer func() {
		if r := recover(); r != nil {
			maintainer.logger.Error(fmt.Sprintf("CRITICAL ERROR: %v", r))
			os.Exit(1)
		}
	}()
	
	maintainer.runCycle()
}
