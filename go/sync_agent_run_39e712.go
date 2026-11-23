// abstraction-provenance: {"artifact_sha256": "ef4f829c88cbea8a18892d2b4e20b916735e5ece9c66b259ebb676acbaf0b6b2", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "go"}
// sync_agent_run.py — portiert nach go
// Quelle: python, workspace@local:scripts/sync_agent_run.py
// auch in: workspace@local:scripts/sync_agent.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung
*/

package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
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
	CLAWHUB_DIR = "/workspace/skills"
	GIT_DIR     = "/workspace/git/skills"
	STATE_FILE  = "/workspace/db/sync_state.json"
	BACKUP_ROOT = "/workspace/backups/sync_agent"
)

type State struct {
	SyncHistory []SyncHistoryEntry `json:"sync_history"`
	Pending     []interface{}      `json:"pending"` // Placeholder for pending items if needed
}

type SyncHistoryEntry struct {
	Timestamp time.Time          `json:"timestamp"`
	Results   map[string][]string `json:"results"`
}

type Results struct {
	SyncedToGit       []string
	SyncedToClawhub   []string
	UpdatedGit        []string
	UpdatedClawhub    []string
	NoChange          []string
	Errors            []string
}

func loadState() State {
	var state State
	if _, err := os.Stat(STATE_FILE); os.IsNotExist(err) {
		return State{SyncHistory: make([]SyncHistoryEntry, 0), Pending: make([]interface{}, 0)}
	}

	file, err := os.Open(STATE_FILE)
	if err != nil {
		log.Printf("Error opening state file: %v", err)
		return State{}
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&state)
	if err != nil {
		log.Printf("Error decoding state: %v", err)
		return State{}
	}

	return state
}

func saveState(state State) {
	stateDir := filepath.Dir(STATE_FILE)
	if _, err := os.Stat(stateDir); os.IsNotExist(err) {
		os.MkdirAll(stateDir, 0755)
	}

	file, err := os.Create(STATE_FILE)
	if err != nil {
		log.Printf("Error creating state file: %v", err)
		return
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	err = encoder.Encode(state)
	if err != nil {
		log.Printf("Error encoding state: %v", err)
	}
}

func getAllSkills() ([]string, error) {
	clawhubSkills, err := getValidSkillDirs(CLAWHUB_DIR)
	if err != nil {
		return nil, fmt.Errorf("error getting clawhub skills: %v", err)
	}

	gitSkills, err := getValidSkillDirs(GIT_DIR)
	if err != nil {
		return nil, fmt.Errorf("error getting git skills: %v", err)
	}

	allSkillsMap := make(map[string]bool)
	for _, skill := range clawhubSkills {
		allSkillsMap[skill] = true
	}
	for _, skill := range gitSkills {
		allSkillsMap[skill] = true
	}

	var allSkills []string
	for skill := range allSkillsMap {
		allSkills = append(allSkills, skill)
	}
	sort.Strings(allSkills)

	return allSkills, nil
}

func getValidSkillDirs(dir string) ([]string, error) {
	var skills []string
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") || strings.HasPrefix(entry.Name(), "_") {
			continue
		}

		skillPath := filepath.Join(dir, entry.Name())
		skillMdPath := filepath.Join(skillPath, "SKILL.md")
		if _, err := os.Stat(skillMdPath); err == nil {
			skills = append(skills, entry.Name())
		}
	}

	return skills, nil
}

func initGitRepo(skillPath, skillName string) error {
	gitDir := filepath.Join(skillPath, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		oldDir, _ := os.Getwd()
		os.Chdir(skillPath)
		defer os.Chdir(oldDir)

		cmd := exec.Command("git", "init")
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to init git repo: %v", err)
		}

		cmd = exec.Command("git", "add", ".")
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to add files: %v", err)
		}

		cmd = exec.Command("git", "commit", "-m", fmt.Sprintf("Initial commit: %s skill", skillName))
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to commit: %v", err)
		}

		logMessage(fmt.Sprintf("Git initialized for %s", skillName))
	}
	return nil
}

func backupSkillDir(skillPath, skillName string) error {
	if _, err := os.Stat(skillPath); os.IsNotExist(err) {
		return nil
	}

	timestamp := time.Now().Format("20060102150405")
	backupDir := filepath.Join(BACKUP_ROOT, timestamp)
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return fmt.Errorf("failed to create backup directory: %v", err)
	}

	archiveName := fmt.Sprintf("%s_%s.tar.gz", skillName, timestamp)
	archivePath := filepath.Join(backupDir, archiveName)

	cmd := exec.Command("tar", "-czf", archivePath, "-C", filepath.Dir(skillPath), filepath.Base(skillPath))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create backup archive: %v", err)
	}

	logMessage(fmt.Sprintf("Backup created for %s at %s", skillName, archivePath))
	return nil
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
			if err := backupSkillDir(clawhubPath, fmt.Sprintf("%s_clawhub", skillName)); err != nil {
				logMessage(fmt.Sprintf("Warning: backup failed: %v", err))
			}
		}
		if syncToGit(skillName, dryRun) {
			if !dryRun {
				if err := initGitRepo(gitPath, skillName); err != nil {
					logMessage(fmt.Sprintf("Warning: git init failed: %v", err))
				}
			}
			return "synced_to_git", nil
		}
		return "no_change", nil
	}

	// Fall 2: Nur in Git → zu ClawHub
	if gitExists && !clawhubExists {
		logMessage(fmt.Sprintf("NEW in Git: %s → syncing to ClawHub", skillName))
		if !dryRun {
			if err := backupSkillDir(gitPath, fmt.Sprintf("%s_git", skillName)); err != nil {
				logMessage(fmt.Sprintf("Warning: backup failed: %v", err))
			}
		}
		if syncToClawhub(skillName, dryRun) {
			return "synced_to_clawhub", nil
		}
		return "no_change", nil
	}

	// Fall 3: In beiden vorhanden → Vergleiche Timestamps
	if clawhubExists && gitExists {
		// Validate skills
		if !validateSkill(clawhubPath) {
			logMessage(fmt.Sprintf("Validation failed for ClawHub skill: %s", skillName))
			return "error", nil
		}
		if !validateSkill(gitPath) {
			logMessage(fmt.Sprintf("Validation failed for Git skill: %s", skillName))
			return "error", nil
		}

		// Compare hashes
		clawhubHashes, err := getHashes(clawhubPath)
		if err != nil {
			logMessage(fmt.Sprintf("Error getting clawhub hashes: %v", err))
			return "error", nil
		}
		gitHashes, err := getHashes(gitPath)
		if err != nil {
			logMessage(fmt.Sprintf("Error getting git hashes: %v", err))
			return "error", nil
		}

		if !hashMapsEqual(clawhubHashes, gitHashes) {
			logMessage(fmt.Sprintf("Content difference detected for: %s", skillName))

			direction := "to-git"
			clawhubModTime, _ := getModTime(clawhubPath)
			gitModTime, _ := getModTime(gitPath)
			if gitModTime.After(clawhubModTime) {
				direction = "to-clawhub"
			}

			logMessage(fmt.Sprintf("UPDATE: %s → syncing %s", skillName, direction))
			if !dryRun {
				if err := backupSkillDir(clawhubPath, fmt.Sprintf("%s_clawhub", skillName)); err != nil {
					logMessage(fmt.Sprintf("Warning: backup failed: %v", err))
				}
				if err := backupSkillDir(gitPath, fmt.Sprintf("%s_git", skillName)); err != nil {
					logMessage(fmt.Sprintf("Warning: backup failed: %v", err))
				}
			}

			syncFunc := syncToGit
			if direction == "to-clawhub" {
				syncFunc = syncToClawhub
			}

			if syncFunc(skillName, dryRun) {
				if !dryRun && direction == "to-git" {
					oldDir, _ := os.Getwd()
					os.Chdir(gitPath)
					defer os.Chdir(oldDir)

					cmd := exec.Command("git", "add", ".")
					if err := cmd.Run(); err != nil {
						logMessage(fmt.Sprintf("Warning: git add failed: %v", err))
					}

					commitMsg := fmt.Sprintf("Sync from ClawHub content diff: %s", time.Now().Format("2006-01-02 15:04"))
					cmd = exec.Command("git", "commit", "-m", commitMsg)
					if err := cmd.Run(); err != nil {
						logMessage(fmt.Sprintf("Warning: git commit failed: %v", err))
					}
				}
				if direction == "to-git" {
					return "updated_git", nil
				} else {
					return "updated_clawhub", nil
				}
			} else {
				logMessage(fmt.Sprintf("Failed to sync %s to Git after content diff", skillName))
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
	err := filepath.WalkDir(skillDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Skip .git directories
		if strings.Contains(path, ".git") {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if !d.IsDir() {
			relPath, err := filepath.Rel(skillDir, path)
			if err != nil {
				return err
			}

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

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hasher.Sum(nil)), nil
}

func hashMapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}

func getModTime(path string) (time.Time, error) {
	info, err := os.Stat(path)
	if err != nil {
		return time.Time{}, err
	}
	return info.ModTime(), nil
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return false
	}
	return info.IsDir()
}

// External function placeholders - these would need actual implementation
func syncToGit(skillName string, dryRun bool) bool {
	// Implementation would depend on your specific sync logic
	// This is just a placeholder that returns true for demonstration
	if !dryRun {
		fmt.Printf("Syncing %s to Git\n", skillName)
		// Actual implementation here
	}
	return true
}

func syncToClawhub(skillName string, dryRun bool) bool {
	// Implementation would depend on your specific sync logic
	// This is just a placeholder that returns true for demonstration
	if !dryRun {
		fmt.Printf("Syncing %s to ClawHub\n", skillName)
		// Actual implementation here
	}
	return true
}

func validateSkill(skillPath string) bool {
	// Implementation would depend on your validation logic
	// This is just a placeholder that returns true for demonstration
	skillMdPath := filepath.Join(skillPath, "SKILL.md")
	if _, err := os.Stat(skillMdPath); err == nil {
		return true
	}
	return false
}

func logMessage(message string) {
	fmt.Println(message)
	// In a real implementation, you might want to write to a log file
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
	allSkills, err := getAllSkills()
	if err != nil {
		log.Fatalf("Error getting skills: %v", err)
	}
	logMessage(fmt.Sprintf("Gefundene Skills: %d", len(allSkills)))

	results := Results{
		SyncedToGit:     make([]string, 0),
		SyncedToClawhub: make([]string, 0),
		UpdatedGit:      make([]string, 0),
		UpdatedClawhub:  make([]string, 0),
		NoChange:        make([]string, 0),
		Errors:          make([]string, 0),
	}

	for _, skill := range allSkills {
		result, err := syncSkillBidirectional(skill, dryRun)
		if err != nil {
			logMessage(fmt.Sprintf("ERROR syncing %s: %v", skill, err))
			results.Errors = append(results.Errors, skill)
		} else {
			switch result {
			case "synced_to_git":
				results.SyncedToGit = append(results.SyncedToGit, skill)
			case "synced_to_clawhub":
				results.SyncedToClawhub = append(results.SyncedToClawhub, skill)
			case "updated_git":
				results.UpdatedGit = append(results.UpdatedGit, skill)
			case "updated_clawhub":
				results.UpdatedClawhub = append(results.UpdatedClawhub, skill)
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
	logMessage(fmt.Sprintf("Neu in ClawHub: %d - %v", len(results.SyncedToClawhub), results.SyncedToClawhub))
	logMessage(fmt.Sprintf("Git aktualisiert: %d - %v", len(results.UpdatedGit), results.UpdatedGit))
	logMessage(fmt.Sprintf("ClawHub aktualisiert: %d - %v", len(results.UpdatedClawhub), results.UpdatedClawhub))
	logMessage(fmt.Sprintf("Keine Änderung: %d", len(results.NoChange)))
	logMessage(fmt.Sprintf("Fehler: %d - %v", len(results.Errors), results.Errors))

	// Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
	if !dryRun {
		entry := SyncHistoryEntry{
			Timestamp: time.Now(),
			Results: map[string][]string{
				"synced_to_git":       results.SyncedToGit,
				"synced_to_clawhub":   results.SyncedToClawhub,
				"updated_git":         results.UpdatedGit,
				"updated_clawhub":     results.UpdatedClawhub,
				"no_change":           results.NoChange,
				"errors":              results.Errors,
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
