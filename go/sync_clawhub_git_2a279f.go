// abstraction-provenance: {"artifact_sha256": "d589c98fb07f5e854fc2a68b143da986c4d61f610c761debe989231be209c30a", "source_sha256": "2a279f44187e822afbb6a0af5593a2890c8e99b41f885f5d063355b6ea20b921", "target_language": "go"}
// sync_clawhub_git.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
// auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
	"log"
	"flag"
	"io/fs"
)

// Konfiguration
var (
	WORKSPACE_ROOT string
	CLAWHUB_DIR    string
	GIT_DIR        string
	BACKUP_DIR     string
	LOG_FILE       string
)

var IGNORED_NAMES = map[string]bool{
	".git": true, ".clawhub": true, "node_modules": true,
	"__pycache__": true, ".pytest_cache": true,
}

var RESERVED_SKILL_NAMES = map[string]bool{
	"github-clones": true, "skills": true, "backups": true,
	".restore": true, "git": true, "Abstraktionen": true,
}

var PRESERVED_TARGET_NAMES = map[string]bool{
	".git": true, ".clawhub": true, "node_modules": true,
	"__pycache__": true, ".pytest_cache": true,
}

func init() {
	exe, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	WORKSPACE_ROOT = filepath.Dir(filepath.Dir(exe))
	CLAWHUB_DIR = filepath.Join(WORKSPACE_ROOT, "skills")
	GIT_DIR = filepath.Join(WORKSPACE_ROOT, "git", "skills")
	BACKUP_DIR = filepath.Join(WORKSPACE_ROOT, "backups", "sync")
	LOG_FILE = filepath.Join(WORKSPACE_ROOT, "logs", "sync-agent.log")

	os.MkdirAll(GIT_DIR, 0755)
	os.MkdirAll(BACKUP_DIR, 0755)
	os.MkdirAll(filepath.Dir(LOG_FILE), 0755)
}

// Logging
func logMessage(message string, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	f.WriteString(entry + "\n")
}

// Validierung
func validateSkill(skillDir string) bool {
	skillName := filepath.Base(skillDir)
	if RESERVED_SKILL_NAMES[skillName] {
		logMessage(fmt.Sprintf("Validation failed: %s is reserved and must not be synced as a skill", skillName), "ERROR")
		return false
	}
	if _, err := os.Stat(filepath.Join(skillDir, "SKILL.md")); os.IsNotExist(err) {
		logMessage(fmt.Sprintf("Validation failed: %s missing SKILL.md", skillName), "ERROR")
		return false
	}
	return true
}

func isIgnoredPath(parts []string) bool {
	for _, part := range parts {
		if IGNORED_NAMES[part] || strings.HasSuffix(part, ".pyc") {
			return true
		}
	}
	return false
}

func isGeneratedDuplicatePath(root string, relPath string) bool {
	parts := strings.Split(relPath, string(filepath.Separator))
	if len(parts) == 0 {
		return false
	}
	rootName := filepath.Base(root)
	if parts[0] == rootName {
		return true
	}
	for i := 1; i < len(parts); i++ {
		if parts[i] == parts[i-1] {
			return true
		}
	}
	return false
}

func iterSyncFiles(root string) ([]string, []string, error) {
	var files []string
	var relPaths []string
	
	err := filepath.WalkDir(root, func(currentPath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		
		relPath, err := filepath.Rel(root, currentPath)
		if err != nil {
			return err
		}
		
		relParts := strings.Split(relPath, string(filepath.Separator))
		
		if isIgnoredPath(relParts) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		
		if isGeneratedDuplicatePath(root, relPath) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		
		if !d.IsDir() && d.Name() == "SKILL.md" && relPath != "SKILL.md" {
			return nil
		}
		
		if !d.IsDir() {
			files = append(files, currentPath)
			relPaths = append(relPaths, relPath)
		}
		
		return nil
	})
	
	return files, relPaths, err
}

func resetSyncTarget(target string) error {
	err := os.MkdirAll(target, 0755)
	if err != nil {
		return err
	}
	
	entries, err := os.ReadDir(target)
	if err != nil {
		return err
	}
	
	for _, entry := range entries {
		if PRESERVED_TARGET_NAMES[entry.Name()] {
			continue
		}
		path := filepath.Join(target, entry.Name())
		if entry.IsDir() {
			err = os.RemoveAll(path)
		} else {
			err = os.Remove(path)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func copySyncFiles(source string, target string) error {
	err := resetSyncTarget(target)
	if err != nil {
		return err
	}
	
	files, relPaths, err := iterSyncFiles(source)
	if err != nil {
		return err
	}
	
	for i, srcFile := range files {
		relPath := relPaths[i]
		destFile := filepath.Join(target, relPath)
		
		err = os.MkdirAll(filepath.Dir(destFile), 0755)
		if err != nil {
			return err
		}
		
		src, err := os.Open(srcFile)
		if err != nil {
			return err
		}
		defer src.Close()
		
		dst, err := os.Create(destFile)
		if err != nil {
			return err
		}
		defer dst.Close()
		
		_, err = io.Copy(dst, src)
		if err != nil {
			return err
		}
		
		srcInfo, err := src.Stat()
		if err != nil {
			return err
		}
		
		err = os.Chmod(destFile, srcInfo.Mode())
		if err != nil {
			return err
		}
	}
	
	return nil
}

// Backup
func createBackup(source string, skillName string) bool {
	timestamp := time.Now().Format("20060102_150405")
	backupPath := filepath.Join(BACKUP_DIR, fmt.Sprintf("%s_%s", skillName, timestamp))
	
	if _, err := os.Stat(backupPath); err == nil {
		err = os.RemoveAll(backupPath)
		if err != nil {
			logMessage(fmt.Sprintf("Failed to remove existing backup %s: %v", backupPath, err), "ERROR")
			return false
		}
		logMessage(fmt.Sprintf("Removed existing backup: %s", backupPath), "INFO")
	}
	
	err := filepath.WalkDir(source, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		
		relPath, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		
		relParts := strings.Split(relPath, string(filepath.Separator))
		if isIgnoredPath(relParts) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		
		targetPath := filepath.Join(backupPath, relPath)
		if d.IsDir() {
			return os.MkdirAll(targetPath, 0755)
		} else {
			return copyFile(path, targetPath)
		}
	})
	
	if err != nil {
		logMessage(fmt.Sprintf("Backup failed: %v", err), "ERROR")
		return false
	}
	
	logMessage(fmt.Sprintf("Backup created: %s", backupPath), "INFO")
	return true
}

func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()
	
	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()
	
	_, err = io.Copy(destFile, sourceFile)
	return err
}

// Hash-Vergleich
func getFileHash(filePath string) string {
	file, err := os.Open(filePath)
	if err != nil {
		logMessage(fmt.Sprintf("Failed to hash %s: %v", filePath, err), "ERROR")
		return ""
	}
	defer file.Close()
	
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		logMessage(fmt.Sprintf("Failed to hash %s: %v", filePath, err), "ERROR")
		return ""
	}
	
	return fmt.Sprintf("%x", hasher.Sum(nil))
}

// Sync Richtung ClawHub → Git
func syncToGit(skillName string, dryRun bool) bool {
	source := filepath.Join(CLAWHUB_DIR, skillName)
	target := filepath.Join(GIT_DIR, skillName)
	
	if !validateSkill(source) {
		return false
	}
	
	// Backup vor Änderungen (nur wenn target existiert)
	if !dryRun {
		if _, err := os.Stat(target); err == nil {
			createBackup(target, skillName)
		}
	}
	
	// Änderungen erkennen
	var changes []string
	
	files, relPaths, err := iterSyncFiles(source)
	if err != nil {
		logMessage(fmt.Sprintf("Failed to iterate files: %v", err), "ERROR")
		return false
	}
	
	for i, srcFile := range files {
		relPath := relPaths[i]
		tgtFile := filepath.Join(target, relPath)
		
		if _, err := os.Stat(tgtFile); os.IsNotExist(err) {
			changes = append(changes, fmt.Sprintf("ADD %s", relPath))
		} else {
			srcHash := getFileHash(srcFile)
			tgtHash := getFileHash(tgtFile)
			if srcHash != tgtHash {
				changes = append(changes, fmt.Sprintf("UPDATE %s", relPath))
			}
		}
	}
	
	// Dry-Run Report
	if dryRun {
		logMessage(fmt.Sprintf("DRY-RUN: %s - %d changes", skillName, len(changes)), "INFO")
		for _, change := range changes {
			logMessage(fmt.Sprintf("  %s", change), "INFO")
		}
		return true
	}
	
	// Echte Synchronisation
	logMessage(fmt.Sprintf("SYNC: %s - Applying %d changes", skillName, len(changes)), "INFO")
	err = copySyncFiles(source, target)
	if err != nil {
		logMessage(fmt.Sprintf("Failed to copy files: %v", err), "ERROR")
		return false
	}
	logMessage(fmt.Sprintf("SYNC: %s - Complete", skillName), "INFO")
	return true
}

// Sync Richtung Git → ClawHub
func syncToClawhub(skillName string, dryRun bool) bool {
	source := filepath.Join(GIT_DIR, skillName)
	target := filepath.Join(CLAWHUB_DIR, skillName)
	
	if !validateSkill(source) {
		return false
	}
	
	// Backup vor Änderungen (nur wenn target existiert)
	if !dryRun {
		if _, err := os.Stat(target); err == nil {
			createBackup(target, skillName)
		}
	}
	
	// Änderungen erkennen (gleiche Logik wie oben)
	var changes []string
	
	files, relPaths, err := iterSyncFiles(source)
	if err != nil {
		logMessage(fmt.Sprintf("Failed to iterate files: %v", err), "ERROR")
		return false
	}
	
	for i, srcFile := range files {
		relPath := relPaths[i]
		tgtFile := filepath.Join(target, relPath)
		
		if _, err := os.Stat(tgtFile); os.IsNotExist(err) {
			changes = append(changes, fmt.Sprintf("ADD %s", relPath))
		} else {
			srcHash := getFileHash(srcFile)
			tgtHash := getFileHash(tgtFile)
			if srcHash != tgtHash {
				changes = append(changes, fmt.Sprintf("UPDATE %s", relPath))
			}
		}
	}
	
	// Dry-Run Report
	if dryRun {
		logMessage(fmt.Sprintf("DRY-RUN: %s - %d changes", skillName, len(changes)), "INFO")
		for _, change := range changes {
			logMessage(fmt.Sprintf("  %s", change), "INFO")
		}
		return true
	}
	
	// Echte Synchronisation
	logMessage(fmt.Sprintf("SYNC: %s - Applying %d changes", skillName, len(changes)), "INFO")
	err = copySyncFiles(source, target)
	if err != nil {
		logMessage(fmt.Sprintf("Failed to copy files: %v", err), "ERROR")
		return false
	}
	logMessage(fmt.Sprintf("SYNC: %s - Complete", skillName), "INFO")
	return true
}

// Hauptfunktion
func main() {
	var skill string
	var direction string
	var dryRun bool
	var force bool
	
	flag.StringVar(&skill, "skill", "", "Skill name")
	flag.StringVar(&direction, "direction", "", "Direction (to-git or to-clawhub)")
	flag.BoolVar(&dryRun, "dry-run", false, "Nur Änderungen anzeigen")
	flag.BoolVar(&force, "force", false, "Ohne Backup")
	
	flag.Parse()
	
	if skill == "" || direction == "" {
		fmt.Println("Error: --skill and --direction are required")
		os.Exit(1)
	}
	
	logMessage(fmt.Sprintf("Starting sync: %s (%s)", skill, direction), "INFO")
	
	var success bool
	if direction == "to-git" {
		success = syncToGit(skill, dryRun)
	} else if direction == "to-clawhub" {
		success = syncToClawhub(skill, dryRun)
	} else {
		fmt.Println("Error: invalid direction")
		os.Exit(1)
	}
	
	if !success {
		logMessage("Sync failed", "ERROR")
		os.Exit(1)
	}
	
	logMessage("Sync completed", "INFO")
}
