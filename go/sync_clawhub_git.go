// abstraction-provenance: {"artifact_sha256": "20b592489faaee47f415b225e17008b12439b557d15c84b86042103ba9d1321f", "source_sha256": "61022646f18bff569b8abac746e220ff7bb0333624b5b9fe62e2210671ee2acc", "target_language": "go"}
// sync_clawhub_git.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Bidirektionale ClawHub ↔ Git Synchronisation
*/

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// Konfiguration
var (
	CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
	GIT_DIR     = "/home/openclaw/.openclaw/workspace/git/skills"
	BACKUP_DIR  = "/home/openclaw/.openclaw/workspace/backups/sync"
	LOG_FILE    = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"
)

func init() {
	// Erstelle Verzeichnisse
	os.MkdirAll(GIT_DIR, 0755)
	os.MkdirAll(BACKUP_DIR, 0755)
	os.MkdirAll(filepath.Dir(LOG_FILE), 0755)
}

// Logging
func logMessage(message string, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s\n", timestamp, level, message)
	fmt.Print(entry)
	
	file, err := os.OpenFile(LOG_FILE, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return
	}
	defer file.Close()
	
	file.WriteString(entry)
}

// Validierung
func validateSkill(skillDir string) bool {
	/* Prüft Skill-Struktur - SKILL.md required, scripts/ optional */
	skillMdPath := filepath.Join(skillDir, "SKILL.md")
	if _, err := os.Stat(skillMdPath); os.IsNotExist(err) {
		logMessage(fmt.Sprintf("Validation failed: %s missing SKILL.md", filepath.Base(skillDir)), "ERROR")
		return false
	}
	return true
}

// Backup
func createBackup(source string, skillName string) bool {
	/* Erstellt Backup eines Skills */
	timestamp := time.Now().Format("20060102_150405")
	backupPath := filepath.Join(BACKUP_DIR, fmt.Sprintf("%s_%s", skillName, timestamp))
	
	// Backup verzeichnis löschen falls es existiert
	if _, err := os.Stat(backupPath); err == nil {
		err := os.RemoveAll(backupPath)
		if err != nil {
			logMessage(fmt.Sprintf("Failed to remove existing backup %s: %v", backupPath, err), "ERROR")
			return false
		}
		logMessage(fmt.Sprintf("Removed existing backup: %s", backupPath), "INFO")
	}
	
	err := copyDir(source, backupPath)
	if err != nil {
		logMessage(fmt.Sprintf("Backup failed: %v", err), "ERROR")
		return false
	}
	logMessage(fmt.Sprintf("Backup created: %s", backupPath), "INFO")
	return true
}

// Hash-Vergleich
func getFileHash(filePath string) (string, error) {
	/* SHA256-Hash einer Datei */
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}
	
	return hex.EncodeToString(hasher.Sum(nil)), nil
}

// Hilfsfunktion zum Kopieren eines Verzeichnisses
func copyDir(src string, dst string) error {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}
	
	err = os.MkdirAll(dst, srcInfo.Mode())
	if err != nil {
		return err
	}
	
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		
		if entry.IsDir() {
			err = copyDir(srcPath, dstPath)
			if err != nil {
				return err
			}
		} else {
			err = copyFile(srcPath, dstPath)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

// Hilfsfunktion zum Kopieren einer Datei
func copyFile(src string, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()
	
	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()
	
	_, err = io.Copy(dstFile, srcFile)
	return err
}

// Sync Richtung ClawHub → Git
func syncToGit(skillName string, dryRun bool) bool {
	/* Synchronisiert ClawHub Skill zu Git */
	source := filepath.Join(CLAWHUB_DIR, skillName)
	target := filepath.Join(GIT_DIR, skillName)
	
	if !validateSkill(source) {
		return false
	}
	
	// Backup vor Änderungen (nur wenn target existiert)
	if !dryRun && exists(target) {
		createBackup(target, skillName)
	}
	
	// Änderungen erkennen
	changes := []string{}
	err := filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		relPath, _ := filepath.Rel(source, path)
		
		if !info.IsDir() {
			tgtFile := filepath.Join(target, relPath)
			
			// Vergleich
			if !exists(tgtFile) {
				changes = append(changes, fmt.Sprintf("ADD %s", relPath))
			} else {
				srcHash, err1 := getFileHash(path)
				tgtHash, err2 := getFileHash(tgtFile)
				
				if err1 != nil || err2 != nil {
					return fmt.Errorf("error calculating hash")
				}
				
				if srcHash != tgtHash {
					changes = append(changes, fmt.Sprintf("UPDATE %s", relPath))
				}
			}
		}
		return nil
	})
	
	if err != nil {
		logMessage(fmt.Sprintf("Error walking directory: %v", err), "ERROR")
		return false
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
	if exists(target) {
		copyDirWithIgnore(source, target, ".git")
	} else {
		copyDirWithIgnore(source, target, ".git")
	}
	logMessage(fmt.Sprintf("SYNC: %s - Complete", skillName), "INFO")
	return true
}

// Sync Richtung Git → ClawHub
func syncToClawhub(skillName string, dryRun bool) bool {
	/* Synchronisiert Git Skill zu ClawHub */
	source := filepath.Join(GIT_DIR, skillName)
	target := filepath.Join(CLAWHUB_DIR, skillName)
	
	if !validateSkill(source) {
		return false
	}
	
	// Backup vor Änderungen (nur wenn target existiert)
	if !dryRun && exists(target) {
		createBackup(target, skillName)
	}
	
	// Änderungen erkennen (gleiche Logik wie oben)
	changes := []string{}
	err := filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		relPath, _ := filepath.Rel(source, path)
		
		if !info.IsDir() {
			tgtFile := filepath.Join(target, relPath)
			
			if !exists(tgtFile) {
				changes = append(changes, fmt.Sprintf("ADD %s", relPath))
			} else {
				srcHash, err1 := getFileHash(path)
				tgtHash, err2 := getFileHash(tgtFile)
				
				if err1 != nil || err2 != nil {
					return fmt.Errorf("error calculating hash")
				}
				
				if srcHash != tgtHash {
					changes = append(changes, fmt.Sprintf("UPDATE %s", relPath))
				}
			}
		}
		return nil
	})
	
	if err != nil {
		logMessage(fmt.Sprintf("Error walking directory: %v", err), "ERROR")
		return false
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
	if exists(target) {
		copyDirWithIgnore(source, target, ".git")
	} else {
		copyDirWithIgnore(source, target, ".git")
	}
	logMessage(fmt.Sprintf("SYNC: %s - Complete", skillName), "INFO")
	return true
}

// Hilfsfunktion zum Prüfen ob ein Pfad existiert
func exists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

// Hilfsfunktion zum Kopieren mit Ignorieren bestimmter Dateien
func copyDirWithIgnore(src string, dst string, ignorePattern string) error {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}
	
	err = os.MkdirAll(dst, srcInfo.Mode())
	if err != nil {
		return err
	}
	
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	
	for _, entry := range entries {
		if entry.Name() == ignorePattern {
			continue
		}
		
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		
		if entry.IsDir() {
			err = copyDirWithIgnore(srcPath, dstPath, ignorePattern)
			if err != nil {
				return err
			}
		} else {
			err = copyFile(srcPath, dstPath)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func main() {
	var skill string
	var direction string
	var dryRun bool
	var force bool
	
	rootCmd := &cobra.Command{
		Use:   "sync_clawhub_git",
		Short: "Bidirektionaler Sync ClawHub ↔ Git",
		Run: func(cmd *cobra.Command, args []string) {
			logMessage(fmt.Sprintf("Starting sync: %s (%s)", skill, direction), "INFO")
			
			var success bool
			if direction == "to-git" {
				success = syncToGit(skill, dryRun)
			} else {
				success = syncToClawhub(skill, dryRun)
			}
			
			if !success {
				logMessage("Sync failed", "ERROR")
				os.Exit(1)
			}
			
			logMessage("Sync completed", "INFO")
		},
	}
	
	rootCmd.Flags().StringVar(&skill, "skill", "", "Skill name")
	rootCmd.Flags().StringVar(&direction, "direction", "", "Direction (to-git or to-clawhub)")
	rootCmd.Flags().BoolVar(&dryRun, "dry-run", false, "Nur Änderungen anzeigen")
	rootCmd.Flags().BoolVar(&force, "force", false, "Ohne Backup")
	
	rootCmd.MarkFlagRequired("skill")
	rootCmd.MarkFlagRequired("direction")
	
	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
