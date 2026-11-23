// abstraction-provenance: {"artifact_sha256": "1c39567a5fdaf576efdd127ad11c20ee4eeb49bf9da5c3d0e763e80ec4498673", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "go"}
// sync_clawhub_git_local.py — portiert nach go
// Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
// auch in: workspace@local:scripts/sync_clawhub_git.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Bidirektionale ClawHub ↔ Git Synchronisation
*/

package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// Konfiguration
var (
	WORKSPACE_DIR string
	CLAWHUB_DIR   string
	GIT_DIR       string
	BACKUP_DIR    string
	LOG_FILE      string
)

func init() {
	ex, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	WORKSPACE_DIR = filepath.Dir(filepath.Dir(ex))
	CLAWHUB_DIR = filepath.Join(WORKSPACE_DIR, "skills")
	GIT_DIR = filepath.Join(WORKSPACE_DIR, "git", "skills")
	BACKUP_DIR = filepath.Join(WORKSPACE_DIR, "backups", "sync")
	LOG_FILE = filepath.Join(WORKSPACE_DIR, "logs", "sync-agent.log")

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
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Println("Failed to open log file:", err)
		return
	}
	defer f.Close()
	f.WriteString(entry)
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
	if _, err := os.Stat(backupPath); !os.IsNotExist(err) {
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

	return fmt.Sprintf("%x", hasher.Sum(nil)), nil
}

// Hilfsfunktion zum Kopieren von Verzeichnissen
func copyDir(src string, dst string) error {
	var err error
	var fds []fs.FileInfo
	var srcinfo fs.FileInfo

	if srcinfo, err = os.Stat(src); err != nil {
		return err
	}

	if err = os.MkdirAll(dst, srcinfo.Mode()); err != nil {
		return err
	}

	if fds, err = os.ReadDir(src); err != nil {
		return err
	}
	for _, fd := range fds {
		if fd.Name() == ".git" {
			continue
		}
		srcfp := filepath.Join(src, fd.Name())
		dstfp := filepath.Join(dst, fd.Name())

		if fd.IsDir() {
			if err = copyDir(srcfp, dstfp); err != nil {
				return err
			}
		} else {
			if err = copyFile(srcfp, dstfp); err != nil {
				return err
			}
		}
	}
	return nil
}

// Hilfsfunktion zum Kopieren von Dateien
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
	if err != nil {
		return err
	}

	srcInfo, _ := srcFile.Stat()
	return os.Chmod(dst, srcInfo.Mode())
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
	if !dryRun && func() bool {
		_, err := os.Stat(target)
		return !os.IsNotExist(err)
	}() {
		createBackup(target, skillName)
	}

	// Änderungen erkennen
	changes := []string{}
	err := filepath.Walk(source, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if !info.IsDir() {
			relPath, _ := filepath.Rel(source, path)
			tgtFile := filepath.Join(target, relPath)

			if _, statErr := os.Stat(tgtFile); os.IsNotExist(statErr) {
				changes = append(changes, fmt.Sprintf("ADD %s", relPath))
			} else {
				srcHash, srcErr := getFileHash(path)
				tgtHash, tgtErr := getFileHash(tgtFile)
				if srcErr != nil || tgtErr != nil {
					return fmt.Errorf("error calculating hash: %v, %v", srcErr, tgtErr)
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
	if _, err := os.Stat(target); !os.IsNotExist(err) {
		// Remove existing target directory
		err := os.RemoveAll(target)
		if err != nil {
			logMessage(fmt.Sprintf("Failed to remove existing target: %v", err), "ERROR")
			return false
		}
	}
	err = copyDir(source, target)
	if err != nil {
		logMessage(fmt.Sprintf("Sync failed during copy: %v", err), "ERROR")
		return false
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
	if !dryRun && func() bool {
		_, err := os.Stat(target)
		return !os.IsNotExist(err)
	}() {
		createBackup(target, skillName)
	}

	// Änderungen erkennen (gleiche Logik wie oben)
	changes := []string{}
	err := filepath.Walk(source, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if !info.IsDir() {
			relPath, _ := filepath.Rel(source, path)
			tgtFile := filepath.Join(target, relPath)

			if _, statErr := os.Stat(tgtFile); os.IsNotExist(statErr) {
				changes = append(changes, fmt.Sprintf("ADD %s", relPath))
			} else {
				srcHash, srcErr := getFileHash(path)
				tgtHash, tgtErr := getFileHash(tgtFile)
				if srcErr != nil || tgtErr != nil {
					return fmt.Errorf("error calculating hash: %v, %v", srcErr, tgtErr)
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
	if _, err := os.Stat(target); !os.IsNotExist(err) {
		// Remove existing target directory
		err := os.RemoveAll(target)
		if err != nil {
			logMessage(fmt.Sprintf("Failed to remove existing target: %v", err), "ERROR")
			return false
		}
	}
	err = copyDir(source, target)
	if err != nil {
		logMessage(fmt.Sprintf("Sync failed during copy: %v", err), "ERROR")
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

	rootCmd := &cobra.Command{
		Use:   "sync_clawhub_git_local",
		Short: "Bidirektionaler Sync ClawHub ↔ Git",
		Run: func(cmd *cobra.Command, args []string) {
			logMessage(fmt.Sprintf("Starting sync: %s (%s)", skill, direction), "INFO")

			var success bool
			if strings.ToLower(direction) == "to-git" {
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
	rootCmd.Flags().StringVar(&direction, "direction", "", "Direction of sync (to-git or to-clawhub)")
	rootCmd.Flags().BoolVar(&dryRun, "dry-run", false, "Nur Änderungen anzeigen")
	rootCmd.Flags().BoolVar(&force, "force", false, "Ohne Backup")

	rootCmd.MarkFlagRequired("skill")
	rootCmd.MarkFlagRequired("direction")

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
