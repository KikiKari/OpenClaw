// abstraction-provenance: {"artifact_sha256": "93d74f435cddfb3be1e37dd70da9c286de964a993dd198c390f99585f80abe5b", "source_sha256": "b32d66307e1a3da0f8c6d75edd5baa6dc5d44def64694504db90e3150bc4ac19", "target_language": "go"}
// sync_agent.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// auch in: workspace@local:git/skills/clawhub-git-sync-agent/scripts/sync_agent.py
// auch in: workspace@local:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

const (
	CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
	GIT_DIR     = "/home/openclaw/.openclaw/workspace/git/skills"
	STATE_FILE  = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
	BACKUP_ROOT = "/home/openclaw/.openclaw/workspace/backups/sync_agent"
)

type State struct {
	SyncHistory []SyncHistoryEntry `json:"sync_history"`
	Pending     []interface{}      `json:"pending"`
}

type SyncHistoryEntry struct {
	Timestamp string                 `json:"timestamp"`
	Results   map[string]interface{} `json:"results"`
}

type SyncResult struct {
	SyncedToGit      []string
	SyncedToClawHub  []string
	UpdatedGit       []string
	UpdatedClawHub   []string
	NoChange         []string
	Errors           []string
	ErrorMessages    map[string]string
}

func main() {
	var dryRun bool

	rootCmd := &cobra.Command{
		Use:   "sync-agent",
		Short: "ClawHub ↔ Git Sync Agent",
		Run: func(cmd *cobra.Command, args []string) {
			runSync(dryRun)
		},
	}

	rootCmd.Flags().BoolVar(&dryRun, "dry-run", false, "Perform a dry run without making changes.")
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func runSync(dryRun bool) {
	logMessage("=== ClawHub ↔ Git Sync Agent gestartet ===")

	state := loadState()
	allSkills := getAllSkills()
	logMessage(fmt.Sprintf("Gefundene Skills: %d", len(allSkills)))

	results := &SyncResult{
		SyncedToGit:     []string{},
		SyncedToClawHub: []string{},
		UpdatedGit:      []string{},
		UpdatedClawHub:  []string{},
		NoChange:        []string{},
		Errors:          []string{},
		ErrorMessages:   make(map[string]string),
	}

	for _, skill := range sortedKeys(allSkills) {
		result, err := syncSkillBidirectional(skill, dryRun)
		if err != nil {
			logMessage(fmt.Sprintf("ERROR syncing %s: %v", skill, err))
			results.Errors = append(results.Errors, skill)
			results.ErrorMessages[skill] = err.Error()
		} else {
			switch result {
			case "synced_to_git":
				results.SyncedToGit = append(results.SyncedToGit, skill)
			case "synced_to_clawhub":
				results.SyncedToClawHub = append(results.SyncedToClawHub, skill)
			case "updated_git":
				results.UpdatedGit = append(results.UpdatedGit, skill)
			case "updated_clawhub":
				results.UpdatedClawHub = append(results.UpdatedClawHub, skill)
			case "no_change":
				results.NoChange = append(results.NoChange, skill)
			case "error":
				results.Errors = append(results.Errors, skill)
			}
		}
	}

	// Zusammenfassung
	logMessage("\n=== SYNC ZUSAMMENFASSUNG ===")
	logMessage(fmt.Sprintf("Neu in Git: %d - %v", len(results.SyncedToGit), results.SyncedToGit))
	logMessage(fmt.Sprintf("Neu in ClawHub: %d - %v", len(results.SyncedToClawHub), results.SyncedToClawHub))
	logMessage(fmt.Sprintf("Git aktualisiert: %d - %v", len(results.UpdatedGit), results.UpdatedGit))
	logMessage(fmt.Sprintf("ClawHub aktualisiert: %d - %v", len(results.UpdatedClawHub), results.UpdatedClawHub))
	logMessage(fmt.Sprintf("Keine Änderung: %d", len(results.NoChange)))
	logMessage(fmt.Sprintf("Fehler: %d - %v", len(results.Errors), results.Errors))

	// Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
	if !dryRun {
		if state.SyncHistory == nil {
			state.SyncHistory = []SyncHistoryEntry{}
		}
		entry := SyncHistoryEntry{
			Timestamp: time.Now().Format(time.RFC3339),
			Results: map[string]interface{}{
				"synced_to_git":      results.SyncedToGit,
				"synced_to_clawhub":  results.SyncedToClawHub,
				"updated_git":        results.UpdatedGit,
				"updated_clawhub":    results.UpdatedClawHub,
				"no_change":          results.NoChange,
				"errors":             results.Errors,
				"error_messages":     results.ErrorMessages,
			},
		}
		state.SyncHistory = append(state.SyncHistory, entry)
		// Nur letzte 100 Einträge behalten
		if len(state.SyncHistory) > 100 {
			state.SyncHistory = state.SyncHistory[len(state.SyncHistory)-100:]
		}
		saveState(state)
	}

	logMessage("=== Sync Agent beendet ===\n")
}

func loadState() State {
	if _, err := os.Stat(STATE_FILE); os.IsNotExist(err) {
		return State{SyncHistory: []SyncHistoryEntry{}, Pending: []interface{}{}}
	}

	data, err := os.ReadFile(STATE_FILE)
	if err != nil {
		log.Fatalf("Failed to read state file: %v", err)
	}

	var state State
	if err := json.Unmarshal(data, &state); err != nil {
		log.Fatalf("Failed to parse state file: %v", err)
	}

	return state
}

func saveState(state State) {
	os.MkdirAll(filepath.Dir(STATE_FILE), 0755)
	file, err := os.Create(STATE_FILE)
	if err != nil {
		log.Fatalf("Failed to create state file: %v", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(state); err != nil {
		log.Fatalf("Failed to write state file: %v", err)
	}
}

func getAllSkills() map[string]bool {
	clawhubSkills := getValidSkills(CLAWHUB_DIR)
	gitSkills := getValidSkills(GIT_DIR)
	allSkills := make(map[string]bool)

	for skill := range clawhubSkills {
		allSkills[skill] = true
	}
	for skill := range gitSkills {
		allSkills[skill] = true
	}

	return allSkills
}

func getValidSkills(dir string) map[string]bool {
	skills := make(map[string]bool)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return skills
	}

	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") && !strings.HasPrefix(entry.Name(), "_") {
			skillPath := filepath.Join(dir, entry.Name())
			skillMdPath := filepath.Join(skillPath, "SKILL.md")
			if _, err := os.Stat(skillMdPath); err == nil {
				skills[entry.Name()] = true
			}
		}
	}

	return skills
}

func initGitRepo(skillPath string, skillName string) error {
	gitDir := filepath.Join(skillPath, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		oldDir, _ := os.Getwd()
		defer os.Chdir(oldDir)

		if err := os.Chdir(skillPath); err != nil {
			return err
		}

		if err := exec.Command("git", "init").Run(); err != nil {
			return err
		}
		if err := exec.Command("git", "add", ".").Run(); err != nil {
			return err
		}
		if err := exec.Command("git", "commit", "-m", fmt.Sprintf("Initial commit: %s skill", skillName)).Run(); err != nil {
			return err
		}
		logMessage(fmt.Sprintf("Git initialized for %s", skillName))
	}
	return nil
}

func backupSkillDir(skillPath string, skillName string) error {
	if _, err := os.Stat(skillPath); os.IsNotExist(err) {
		return nil
	}

	timestamp := time.Now().Format("20060102150405")
	backupDir := filepath.Join(BACKUP_ROOT, timestamp)
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return err
	}

	archiveName := fmt.Sprintf("%s_%s.tar.gz", skillName, timestamp)
	archivePath := filepath.Join(backupDir, strings.TrimSuffix(archiveName, ".tar.gz"))

	if err := createTarGz(archivePath, skillPath); err != nil {
		return err
	}

	logMessage(fmt.Sprintf("Backup created for %s at %s", skillName, archivePath+".tar.gz"))
	return nil
}

func createTarGz(archivePath string, sourceDir string) error {
	// This is a simplified version. In practice, you might want to use a library like github.com/mholt/archiver
	cmd := exec.Command("tar", "-czf", archivePath+".tar.gz", "-C", filepath.Dir(sourceDir), filepath.Base(sourceDir))
	return cmd.Run()
}

func syncSkillBidirectional(skillName string, dryRun bool) (string, error) {
	clawhubPath := filepath.Join(CLAWHUB_DIR, skillName)
	gitPath := filepath.Join(GIT_DIR, skillName)

	clawhubExists := dirExists(clawhubPath)
	gitExists := dirExists(gitPath)

	// Fall 1: Nur in ClawHub → zu Git
	if clawhubExists && !gitExists {
		logMessage(fmt.Sprintf("NEW in ClawHub: %s → syncing to Git", skillName))
		if !dryRun {
			if err := backupSkillDir(clawhubPath, skillName+"_clawhub"); err != nil {
				return "error", err
			}
		}
		if syncToGit(skillName, dryRun) {
			if !dryRun {
				if err := initGitRepo(gitPath, skillName); err != nil {
					return "error", err
				}
			}
			return "synced_to_git", nil
		}
	}

	// Fall 2: Nur in Git → zu ClawHub
	if gitExists && !clawhubExists {
		logMessage(fmt.Sprintf("NEW in Git: %s → syncing to ClawHub", skillName))
		if !dryRun {
			if err := backupSkillDir(gitPath, skillName+"_git"); err != nil {
				return "error", err
			}
		}
		if syncToClawHub(skillName, dryRun) {
			return "synced_to_clawhub", nil
		}
	}

	// Fall 3: In beiden vorhanden → Vergleiche Timestamps
	if clawhubExists && gitExists {
		// Stelle sicher, dass beide als gültige Skills validiert werden
		if !validateSkill(clawhubPath) {
			logMessage(fmt.Sprintf("Validation failed for ClawHub skill: %s", skillName), "ERROR")
			return "error", nil
		}
		if !validateSkill(gitPath) {
			logMessage(fmt.Sprintf("Validation failed for Git skill: %s", skillName), "ERROR")
			return "error", nil
		}

		// Berechne Hashes für clawhub und git
		clawhubHashes, err1 := getHashes(clawhubPath)
		gitHashes, err2 := getHashes(gitPath)
		if err1 != nil || err2 != nil {
			return "error", fmt.Errorf("failed to get hashes: %v, %v", err1, err2)
		}

		if !hashMapsEqual(clawhubHashes, gitHashes) {
			logMessage(fmt.Sprintf("Content difference detected for: %s", skillName))

			// Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
			clawhubInfo, _ := os.Stat(clawhubPath)
			gitInfo, _ := os.Stat(gitPath)
			direction := "to-git"
			if gitInfo.ModTime().After(clawhubInfo.ModTime()) {
				direction = "to-clawhub"
			}

			logMessage(fmt.Sprintf("UPDATE: %s → syncing %s", skillName, direction))
			if !dryRun {
				if err := backupSkillDir(clawhubPath, skillName+"_clawhub"); err != nil {
					return "error", err
				}
				if err := backupSkillDir(gitPath, skillName+"_git"); err != nil {
					return "error", err
				}
			}

			var syncFunc func(string, bool) bool
			if direction == "to-git" {
				syncFunc = syncToGit
			} else {
				syncFunc = syncToClawHub
			}

			if syncFunc(skillName, dryRun) {
				if !dryRun && direction == "to-git" {
					oldDir, _ := os.Getwd()
					defer os.Chdir(oldDir)

					if err := os.Chdir(gitPath); err != nil {
						return "error", err
					}
					if err := exec.Command("git", "add", ".").Run(); err != nil {
						return "error", err
					}
					commitMsg := fmt.Sprintf("Sync from ClawHub content diff: %s", time.Now().Format("2006-01-02 15:04"))
					if err := exec.Command("git", "commit", "-m", commitMsg).Run(); err != nil {
						return "error", err
					}
				}
				if direction == "to-git" {
					return "updated_git", nil
				} else {
					return "updated_clawhub", nil
				}
			} else {
				logMessage(fmt.Sprintf("Failed to sync %s to Git after content diff", skillName), "ERROR")
				return "error", nil
			}
		} else {
			logMessage(fmt.Sprintf("Content is identical for: %s", skillName))
			return "no_change", nil
		}
	}

	return "no_change", nil
}

func getHashes(skillDir string) (map[string]string, error) {
	hashes := make(map[string]string)
	err := filepath.Walk(skillDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && strings.Contains(path, ".git") {
			return filepath.SkipDir
		}
		if !info.IsDir() && !strings.Contains(path, ".git") {
			relPath, _ := filepath.Rel(skillDir, path)
			hash, err := getFileHash(path)
			if err != nil {
				return err
			}
			hashes[relPath] = hash
		}
		return nil
	})
	return hashes, err
}

func getFileHash(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}

func hashMapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if bv, ok := b[k]; !ok || bv != v {
			return false
		}
	}
	return true
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func logMessage(message string, level ...string) {
	levelStr := "INFO"
	if len(level) > 0 {
		levelStr = level[0]
	}
	log.Printf("[%s] %s\n", levelStr, message)
}

// Mock functions for sync operations - these would need to be implemented based on your actual logic
func syncToGit(skillName string, dryRun bool) bool {
	// Implementation would depend on your specific sync logic
	// This is just a placeholder
	if !dryRun {
		src := filepath.Join(CLAWHUB_DIR, skillName)
		dst := filepath.Join(GIT_DIR, skillName)
		// Copy directory logic here
		_ = copyDir(src, dst)
	}
	return true
}

func syncToClawHub(skillName string, dryRun bool) bool {
	// Implementation would depend on your specific sync logic
	// This is just a placeholder
	if !dryRun {
		src := filepath.Join(GIT_DIR, skillName)
		dst := filepath.Join(CLAWHUB_DIR, skillName)
		// Copy directory logic here
		_ = copyDir(src, dst)
	}
	return true
}

func validateSkill(skillPath string) bool {
	// Implementation would depend on your validation logic
	// This is just a placeholder that checks if SKILL.md exists
	skillMdPath := filepath.Join(skillPath, "SKILL.md")
	_, err := os.Stat(skillMdPath)
	return err == nil
}

func copyDir(src string, dst string) error {
	// Simple directory copy implementation
	// In practice, you might want to use a more robust solution
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		
		dstPath := filepath.Join(dst, relPath)
		
		if info.IsDir() {
			return os.MkdirAll(dstPath, info.Mode())
		} else {
			return copyFile(path, dstPath)
		}
	})
}

func copyFile(src, dst string) error {
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

func sortedKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
