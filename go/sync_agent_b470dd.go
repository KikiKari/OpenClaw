// abstraction-provenance: {"artifact_sha256": "ed8cc788eb6aa586a5a5c0411dcf446fb1d69044af3e5943a70b46cf36a7a1f9", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "go"}
// sync_agent.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

/*
Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung
*/

package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	// Assuming these are available as Go packages or will be implemented below
	"./sync_clawhub_git" // This would need to be a proper Go package
)

const (
	CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
	GIT_DIR     = "/home/openclaw/.openclaw/workspace/git/skills"
	STATE_FILE  = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
)

type State struct {
	SyncHistory []SyncHistory `json:"sync_history"`
	Pending     []interface{} `json:"pending"` // Using interface{} for flexibility
}

type SyncHistory struct {
	Timestamp string                 `json:"timestamp"`
	Results   map[string][]string    `json:"results"`
}

type Results struct {
	SyncedToGit      []string
	SyncedToClawhub  []string
	UpdatedGit       []string
	UpdatedClawhub   []string
	NoChange         []string
	Errors           []string
}

func loadState() State {
	var state State
	if _, err := os.Stat(STATE_FILE); os.IsNotExist(err) {
		return State{SyncHistory: []SyncHistory{}, Pending: []interface{}{}}
	}

	data, err := os.ReadFile(STATE_FILE)
	if err != nil {
		sync_clawhub_git.Log(fmt.Sprintf("Error reading state file: %v", err), "ERROR")
		return State{SyncHistory: []SyncHistory{}, Pending: []interface{}{}}
	}

	if err := json.Unmarshal(data, &state); err != nil {
		sync_clawhub_git.Log(fmt.Sprintf("Error unmarshaling state: %v", err), "ERROR")
		return State{SyncHistory: []SyncHistory{}, Pending: []interface{}{}}
	}

	return state
}

func saveState(state State) {
	// Ensure the parent directory exists
	parentDir := filepath.Dir(STATE_FILE)
	if _, err := os.Stat(parentDir); os.IsNotExist(err) {
		os.MkdirAll(parentDir, 0755)
	}

	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		sync_clawhub_git.Log(fmt.Sprintf("Error marshaling state: %v", err), "ERROR")
		return
	}

	if err := os.WriteFile(STATE_FILE, data, 0644); err != nil {
		sync_clawhub_git.Log(fmt.Sprintf("Error writing state file: %v", err), "ERROR")
	}
}

func getAllSkills() map[string]bool {
	clawhubSkills := make(map[string]bool)
	gitSkills := make(map[string]bool)

	// Get skills from ClawHub
	if dir, err := os.ReadDir(CLAWHUB_DIR); err == nil {
		for _, entry := range dir {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") && 
				!contains(sync_clawhub_git.RESERVED_SKILL_NAMES, entry.Name()) {
				skillPath := filepath.Join(CLAWHUB_DIR, entry.Name(), "SKILL.md")
				if _, err := os.Stat(skillPath); err == nil {
					clawhubSkills[entry.Name()] = true
				}
			}
		}
	}

	// Get skills from Git
	if dir, err := os.ReadDir(GIT_DIR); err == nil {
		for _, entry := range dir {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") && 
				!contains(sync_clawhub_git.RESERVED_SKILL_NAMES, entry.Name()) {
				skillPath := filepath.Join(GIT_DIR, entry.Name(), "SKILL.md")
				if _, err := os.Stat(skillPath); err == nil {
					gitSkills[entry.Name()] = true
				}
			}
		}
	}

	// Union of both sets
	allSkills := make(map[string]bool)
	for skill := range clawhubSkills {
		allSkills[skill] = true
	}
	for skill := range gitSkills {
		allSkills[skill] = true
	}

	return allSkills
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func initGitRepo(skillPath, skillName string) {
	gitDir := filepath.Join(skillPath, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		os.Chdir(skillPath)
		exec.Command("git", "init").Run()
		exec.Command("git", "add", ".").Run()
		exec.Command("git", "commit", "-m", fmt.Sprintf("Initial commit: %s skill", skillName)).Run()
		sync_clawhub_git.Log(fmt.Sprintf("Git initialized for %s", skillName))
	}
}

func syncSkillBidirectional(skillName string) string {
	clawhubPath := filepath.Join(CLAWHUB_DIR, skillName)
	gitPath := filepath.Join(GIT_DIR, skillName)

	// Check existence
	clawhubExists := dirExists(clawhubPath)
	gitExists := dirExists(gitPath)

	// Case 1: Only in ClawHub → to Git
	if clawhubExists && !gitExists {
		sync_clawhub_git.Log(fmt.Sprintf("NEW in ClawHub: %s → syncing to Git", skillName))
		if sync_clawhub_git.SyncToGit(skillName, false) {
			initGitRepo(gitPath, skillName)
			return "synced_to_git"
		}
	}

	// Case 2: Only in Git → to ClawHub
	if gitExists && !clawhubExists {
		sync_clawhub_git.Log(fmt.Sprintf("NEW in Git: %s → syncing to ClawHub", skillName))
		if sync_clawhub_git.SyncToClawhub(skillName, false) {
			return "synced_to_clawhub"
		}
	}

	// Case 3: In both
	if clawhubExists && gitExists {
		if !sync_clawhub_git.ValidateSkill(clawhubPath) {
			sync_clawhub_git.Log(fmt.Sprintf("Validation failed for ClawHub skill: %s", skillName), "ERROR")
			return "error"
		}
		if !sync_clawhub_git.ValidateSkill(gitPath) {
			sync_clawhub_git.Log(fmt.Sprintf("Validation failed for Git skill: %s", skillName), "ERROR")
			return "error"
		}

		clawhubChanges := previewChanges(clawhubPath, gitPath)
		gitChanges := previewChanges(gitPath, clawhubPath)

		if len(clawhubChanges) == 0 && len(gitChanges) == 0 {
			sync_clawhub_git.Log(fmt.Sprintf("Content is identical for: %s", skillName))
			return "no_change"
		}

		if len(clawhubChanges) > 0 && len(gitChanges) == 0 {
			sync_clawhub_git.Log(fmt.Sprintf("Content difference detected for: %s", skillName))
			sync_clawhub_git.Log(fmt.Sprintf("UPDATE: %s ClawHub content is newer or different → syncing to Git", skillName))
			if sync_clawhub_git.SyncToGit(skillName, false) {
				os.Chdir(gitPath)
				exec.Command("git", "add", ".").Run()
				exec.Command("git", "commit", "-m", fmt.Sprintf("Sync from ClawHub content diff: %s", time.Now().Format("2006-01-02 15:04"))).Run()
				return "updated_git"
			}
			sync_clawhub_git.Log(fmt.Sprintf("Failed to sync %s to Git after content diff", skillName), "ERROR")
			return "error"
		}

		if len(gitChanges) > 0 && len(clawhubChanges) == 0 {
			sync_clawhub_git.Log(fmt.Sprintf("Content difference detected for: %s", skillName))
			sync_clawhub_git.Log(fmt.Sprintf("UPDATE: %s Git content is newer or different → syncing to ClawHub", skillName))
			if sync_clawhub_git.SyncToClawhub(skillName, false) {
				return "updated_clawhub"
			}
			sync_clawhub_git.Log(fmt.Sprintf("Failed to sync %s to ClawHub after content diff", skillName), "ERROR")
			return "error"
		}

		sync_clawhub_git.Log(fmt.Sprintf("Content difference detected for: %s", skillName))
		if newestMtime(clawhubPath) >= newestMtime(gitPath) {
			sync_clawhub_git.Log(fmt.Sprintf("UPDATE: %s ClawHub content is newer or different → syncing to Git", skillName))
			if sync_clawhub_git.SyncToGit(skillName, false) {
				os.Chdir(gitPath)
				exec.Command("git", "add", ".").Run()
				exec.Command("git", "commit", "-m", fmt.Sprintf("Sync from ClawHub content diff: %s", time.Now().Format("2006-01-02 15:04"))).Run()
				return "updated_git"
			}
		} else {
			sync_clawhub_git.Log(fmt.Sprintf("UPDATE: %s Git content is newer or different → syncing to ClawHub", skillName))
			if sync_clawhub_git.SyncToClawhub(skillName, false) {
				return "updated_clawhub"
			}
		}

		sync_clawhub_git.Log(fmt.Sprintf("Failed to resolve content diff for %s", skillName), "ERROR")
		return "error"
	}

	return "no_change"
}

func getHashes(skillDir string) map[string]string {
	hashes := make(map[string]string)
	for filePath, relPath := range iterSyncFiles(skillDir) {
		hashes[relPath] = sync_clawhub_git.GetFileHash(filePath)
	}
	return hashes
}

func previewChanges(sourceDir, targetDir string) []string {
	changes := []string{}
	for srcFile, relPath := range iterSyncFiles(sourceDir) {
		tgtFile := filepath.Join(targetDir, relPath)
		if _, err := os.Stat(tgtFile); os.IsNotExist(err) {
			changes = append(changes, fmt.Sprintf("ADD %s", relPath))
		} else if sync_clawhub_git.GetFileHash(srcFile) != sync_clawhub_git.GetFileHash(tgtFile) {
			changes = append(changes, fmt.Sprintf("UPDATE %s", relPath))
		}
	}
	return changes
}

func newestMtime(skillDir string) float64 {
	mtimes := []float64{}
	for filePath := range iterSyncFiles(skillDir) {
		if info, err := os.Stat(filePath); err == nil {
			mtimes = append(mtimes, float64(info.ModTime().Unix()))
		}
	}
	
	if len(mtimes) == 0 {
		return 0.0
	}
	
	max := mtimes[0]
	for _, m := range mtimes {
		if m > max {
			max = m
		}
	}
	return max
}

func iterSyncFiles(dir string) map[string]string {
	files := make(map[string]string)
	filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || strings.HasPrefix(d.Name(), ".") {
			return nil
		}
		
		relPath, _ := filepath.Rel(dir, path)
		// Exclude certain files like .git directories
		if !strings.Contains(relPath, ".git") {
			files[path] = relPath
		}
		return nil
	})
	return files
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func main() {
	sync_clawhub_git.Log("=== ClawHub ↔ Git Sync Agent gestartet ===")

	// Load previous state
	state := loadState()
	allSkillsMap := getAllSkills()
	
	// Convert map to slice for sorting
	allSkills := make([]string, 0, len(allSkillsMap))
	for skill := range allSkillsMap {
		allSkills = append(allSkills, skill)
	}
	sort.Strings(allSkills)
	
	sync_clawhub_git.Log(fmt.Sprintf("Gefundene Skills: %d", len(allSkills)))

	// Dry-Run Phase: only report changes, no actual modifications
	sync_clawhub_git.Log("--- Dry-Run Phase Start ---")
	for _, skill := range allSkills {
		// Perform dry-run sync in both directions to capture potential changes
		sync_clawhub_git.SyncToGit(skill, true)
		sync_clawhub_git.SyncToClawhub(skill, true)
	}
	sync_clawhub_git.Log("--- Dry-Run Phase End ---")

	results := Results{
		SyncedToGit:     []string{},
		SyncedToClawhub: []string{},
		UpdatedGit:      []string{},
		UpdatedClawhub:  []string{},
		NoChange:        []string{},
		Errors:          []string{},
	}

	// Actual Sync Phase
	for _, skill := range allSkills {
		func() {
			defer func() {
				if r := recover(); r != nil {
					sync_clawhub_git.Log(fmt.Sprintf("ERROR syncing %s: %v", skill, r), "ERROR")
					results.Errors = append(results.Errors, skill)
				}
			}()
			
			result := syncSkillBidirectional(skill)
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
		}()
	}

	// Zusammenfassung
	sync_clawhub_git.Log("\n=== SYNC ZUSAMMENFASSUNG ===")
	sync_clawhub_git.Log(fmt.Sprintf("Neu in Git: %d - %v", len(results.SyncedToGit), results.SyncedToGit))
	sync_clawhub_git.Log(fmt.Sprintf("Neu in ClawHub: %d - %v", len(results.SyncedToClawhub), results.SyncedToClawhub))
	sync_clawhub_git.Log(fmt.Sprintf("Git aktualisiert: %d - %v", len(results.UpdatedGit), results.UpdatedGit))
	sync_clawhub_git.Log(fmt.Sprintf("ClawHub aktualisiert: %d - %v", len(results.UpdatedClawhub), results.UpdatedClawhub))
	sync_clawhub_git.Log(fmt.Sprintf("Keine Änderung: %d", len(results.NoChange)))
	sync_clawhub_git.Log(fmt.Sprintf("Fehler: %d - %v", len(results.Errors), results.Errors))

	// State speichern
	if state.SyncHistory == nil {
		state.SyncHistory = []SyncHistory{}
	}
	
	newHistory := SyncHistory{
		Timestamp: time.Now().Format(time.RFC3339),
		Results: map[string][]string{
			"synced_to_git":      results.SyncedToGit,
			"synced_to_clawhub":  results.SyncedToClawhub,
			"updated_git":        results.UpdatedGit,
			"updated_clawhub":    results.UpdatedClawhub,
			"no_change":          results.NoChange,
			"errors":             results.Errors,
		},
	}
	
	state.SyncHistory = append(state.SyncHistory, newHistory)
	
	// Nur letzte 100 Einträge behalten
	if len(state.SyncHistory) > 100 {
		state.SyncHistory = state.SyncHistory[len(state.SyncHistory)-100:]
	}
	
	saveState(state)
	
	sync_clawhub_git.Log("=== Sync Agent beendet ===\n")
}
