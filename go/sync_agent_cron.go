// abstraction-provenance: {"artifact_sha256": "97bdbdeb97fc15321648828a5630f8e88f1cfb2f54bf8b31ebc107bec06b8bf5", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "go"}
// sync_agent_cron.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
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
)

const (
	CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
	GIT_DIR     = "/home/openclaw/.openclaw/workspace/git/skills"
	LOG_FILE    = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"
	STATE_FILE  = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
)

type ChangeDetection struct {
	NewInClawHub   []string      `json:"new_in_clawhub"`
	NewInGit       []string      `json:"new_in_git"`
	ClawHubNewer   []ChangeEntry `json:"clawhub_newer"`
	GitNewer       []ChangeEntry `json:"git_newer"`
	Synced         []string      `json:"synced"`
}

type ChangeEntry struct {
	Skill string  `json:"skill"`
	Diff  float64 `json:"diff"`
}

type Results struct {
	SyncedToGit     []string `json:"synced_to_git"`
	SyncedToClawHub []string `json:"synced_to_clawhub"`
	UpToDate        []string `json:"up_to_date"`
	Errors          []string `json:"errors"`
}

type State struct {
	LastRun         string                 `json:"last_run"`
	Results         Results                `json:"results"`
	ChangesDetected map[string]interface{} `json:"changes_detected"`
}

func fileMtime(path string) (int64, error) {
	var latestTime int64 = 0
	
	err := filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // Continue walking despite errors
		}
		
		if strings.Contains(p, ".git") {
			return filepath.SkipDir
		}
		
		if !d.IsDir() {
			info, err := d.Info()
			if err == nil && info.ModTime().Unix() > latestTime {
				latestTime = info.ModTime().Unix()
			}
		}
		return nil
	})
	
	return latestTime, err
}

func writeToLog(message string, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s\n", timestamp, level, message)
	fmt.Print(entry)
	
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	
	f.WriteString(entry)
}

func validateSkill(path string) bool {
	// Placeholder implementation - replace with actual validation logic
	if _, err := os.Stat(filepath.Join(path, "skill.json")); err == nil {
		return true
	}
	return false
}

func syncToGit(skill string, dryRun bool) bool {
	// Placeholder implementation - replace with actual sync logic
	clawhubPath := filepath.Join(CLAWHUB_DIR, skill)
	gitPath := filepath.Join(GIT_DIR, skill)
	
	if dryRun {
		return true
	}
	
	// Copy directory
	cmd := exec.Command("cp", "-r", clawhubPath, gitPath)
	if err := cmd.Run(); err != nil {
		return false
	}
	
	return true
}

func syncToClawHub(skill string, dryRun bool) bool {
	// Placeholder implementation - replace with actual sync logic
	gitPath := filepath.Join(GIT_DIR, skill)
	clawhubPath := filepath.Join(CLAWHUB_DIR, skill)
	
	if dryRun {
		return true
	}
	
	// Copy directory
	cmd := exec.Command("cp", "-r", gitPath, clawhubPath)
	if err := cmd.Run(); err != nil {
		return false
	}
	
	return true
}

func getDirectories(dir string) ([]string, error) {
	var dirs []string
	
	entries, err := os.ReadDir(dir)
	if err != nil {
		return dirs, err
	}
	
	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
			dirs = append(dirs, entry.Name())
		}
	}
	
	sort.Strings(dirs)
	return dirs, nil
}

func main() {
	writeToLog(strings.Repeat("=", 70), "INFO")
	writeToLog("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF", "INFO")
	writeToLog(fmt.Sprintf("Zeitstempel: %s", time.Now().Format(time.RFC3339)), "INFO")
	writeToLog(strings.Repeat("=", 70), "INFO")

	// Get skill directories
	clawhubSkills, err := getDirectories(CLAWHUB_DIR)
	if err != nil {
		writeToLog(fmt.Sprintf("Fehler beim Lesen von ClawHub: %v", err), "ERROR")
		os.Exit(1)
	}
	
	gitSkills, err := getDirectories(GIT_DIR)
	if err != nil {
		writeToLog(fmt.Sprintf("Fehler beim Lesen von Git: %v", err), "ERROR")
		os.Exit(1)
	}

	// Convert to sets
	clawhubSet := make(map[string]bool)
	gitSet := make(map[string]bool)
	
	for _, skill := range clawhubSkills {
		clawhubSet[skill] = true
	}
	
	for _, skill := range gitSkills {
		gitSet[skill] = true
	}

	// DRY-RUN: Analysiere Änderungen
	writeToLog("\n[DRY-RUN] Analysiere Änderungen...", "INFO")

	changesDetected := ChangeDetection{
		NewInClawHub: []string{},
		NewInGit:     []string{},
		ClawHubNewer: []ChangeEntry{},
		GitNewer:     []ChangeEntry{},
		Synced:       []string{},
	}

	// 1. Neue Skills finden
	var newInClawHub []string
	var newInGit []string
	
	for _, skill := range clawhubSkills {
		if !gitSet[skill] {
			newInClawHub = append(newInClawHub, skill)
		}
	}
	
	for _, skill := range gitSkills {
		if !clawhubSet[skill] {
			newInGit = append(newInGit, skill)
		}
	}
	
	sort.Strings(newInClawHub)
	sort.Strings(newInGit)
	
	changesDetected.NewInClawHub = newInClawHub
	changesDetected.NewInGit = newInGit

	// 2. Existierende prüfen
	var inBoth []string
	for skill := range clawhubSet {
		if gitSet[skill] {
			inBoth = append(inBoth, skill)
		}
	}
	sort.Strings(inBoth)
	
	for _, skill := range inBoth {
		cMtime, _ := fileMtime(filepath.Join(CLAWHUB_DIR, skill))
		gMtime, _ := fileMtime(filepath.Join(GIT_DIR, skill))
		diff := float64(cMtime - gMtime)
		
		if abs(diff) > 60 {
			if diff > 0 {
				changesDetected.ClawHubNewer = append(changesDetected.ClawHubNewer, ChangeEntry{Skill: skill, Diff: diff})
			} else {
				changesDetected.GitNewer = append(changesDetected.GitNewer, ChangeEntry{Skill: skill, Diff: abs(diff)})
			}
		} else {
			changesDetected.Synced = append(changesDetected.Synced, skill)
		}
	}

	// Report
	totalChanges := len(newInClawHub) + len(newInGit) + len(changesDetected.ClawHubNewer) + len(changesDetected.GitNewer)
	writeToLog(fmt.Sprintf("Neu in ClawHub: %d", len(newInClawHub)), "INFO")
	writeToLog(fmt.Sprintf("Neu in Git: %d", len(newInGit)), "INFO")
	writeToLog(fmt.Sprintf("ClawHub neuer: %d", len(changesDetected.ClawHubNewer)), "INFO")
	writeToLog(fmt.Sprintf("Git neuer: %d", len(changesDetected.GitNewer)), "INFO")
	writeToLog(fmt.Sprintf("Synchron: %d", len(changesDetected.Synced)), "INFO")

	if totalChanges == 0 {
		writeToLog("\n✅ Keine Änderungen erkannt. Sync nicht nötig.", "INFO")
		writeToLog(strings.Repeat("=", 70), "INFO")
		os.Exit(0)
	}

	writeToLog(fmt.Sprintf("\n🔄 %d Änderungen erkannt - starte Synchronisation...", totalChanges), "INFO")

	// ECHTE SYNCHRONISATION
	results := Results{
		SyncedToGit:     []string{},
		SyncedToClawHub: []string{},
		UpToDate:        []string{},
		Errors:          []string{},
	}

	// 1. NEU in ClawHub → zu Git
	for _, skill := range newInClawHub {
		func() {
			defer func() {
				if r := recover(); r != nil {
					writeToLog(fmt.Sprintf("  ✗ ERROR: %s - panic recovered", skill), "ERROR")
					results.Errors = append(results.Errors, skill)
				}
			}()
			
			if validateSkill(filepath.Join(CLAWHUB_DIR, skill)) {
				writeToLog(fmt.Sprintf("→ Synchronisiere %s zu Git...", skill), "INFO")
				if syncToGit(skill, false) {
					gitPath := filepath.Join(GIT_DIR, skill)
					os.Chdir(gitPath)
					
					exec.Command("git", "init", "-q").Run()
					exec.Command("git", "add", ".", "-f").Run()
					dt := time.Now().Format("2006-01-02 15:04")
					exec.Command("git", "commit", "-m", fmt.Sprintf("Initial: %s", skill), "-q").Run()
					
					results.SyncedToGit = append(results.SyncedToGit, skill)
					writeToLog(fmt.Sprintf("  ✓ %s synchronisiert", skill), "INFO")
				}
			} else {
				results.Errors = append(results.Errors, fmt.Sprintf("%s (invalid)", skill))
			}
		}()
	}

	// 2. NEU in Git → zu ClawHub
	for _, skill := range newInGit {
		func() {
			defer func() {
				if r := recover(); r != nil {
					writeToLog(fmt.Sprintf("  ✗ ERROR: %s - panic recovered", skill), "ERROR")
					results.Errors = append(results.Errors, skill)
				}
			}()
			
			if validateSkill(filepath.Join(GIT_DIR, skill)) {
				writeToLog(fmt.Sprintf("→ Synchronisiere %s zu ClawHub...", skill), "INFO")
				if syncToClawHub(skill, false) {
					results.SyncedToClawHub = append(results.SyncedToClawHub, skill)
					writeToLog(fmt.Sprintf("  ✓ %s synchronisiert", skill), "INFO")
				}
			} else {
				results.Errors = append(results.Errors, fmt.Sprintf("%s (invalid)", skill))
			}
		}()
	}

	// 3. Updates
	for _, entry := range changesDetected.ClawHubNewer {
		func() {
			defer func() {
				if r := recover(); r != nil {
					writeToLog(fmt.Sprintf("  ✗ ERROR: %s - panic recovered", entry.Skill), "ERROR")
					results.Errors = append(results.Errors, entry.Skill)
				}
			}()
			
			writeToLog(fmt.Sprintf("→ Update %s (ClawHub +%ds neuer)...", entry.Skill, int(entry.Diff)), "INFO")
			if syncToGit(entry.Skill, false) {
				gitPath := filepath.Join(GIT_DIR, entry.Skill)
				os.Chdir(gitPath)
				
				exec.Command("git", "add", ".", "-f").Run()
				dt := time.Now().Format("2006-01-02 15:04")
				exec.Command("git", "commit", "-m", fmt.Sprintf("Sync from ClawHub: %s", dt), "-q").Run()
				
				results.SyncedToGit = append(results.SyncedToGit, entry.Skill)
				writeToLog(fmt.Sprintf("  ✓ %s aktualisiert", entry.Skill), "INFO")
			}
		}()
	}

	for _, entry := range changesDetected.GitNewer {
		func() {
			defer func() {
				if r := recover(); r != nil {
					writeToLog(fmt.Sprintf("  ✗ ERROR: %s - panic recovered", entry.Skill), "ERROR")
					results.Errors = append(results.Errors, entry.Skill)
				}
			}()
			
			writeToLog(fmt.Sprintf("→ Update %s (Git +%ds neuer)...", entry.Skill, int(entry.Diff)), "INFO")
			if syncToClawHub(entry.Skill, false) {
				results.SyncedToClawHub = append(results.SyncedToClawHub, entry.Skill)
				writeToLog(fmt.Sprintf("  ✓ %s aktualisiert", entry.Skill), "INFO")
			}
		}()
	}

	results.UpToDate = changesDetected.Synced

	// ZUSAMMENFASSUNG
	writeToLog("\n"+strings.Repeat("=", 70), "INFO")
	writeToLog("SYNCHRONISATION ABGESCHLOSSEN", "INFO")
	writeToLog(strings.Repeat("=", 70), "INFO")
	writeToLog(fmt.Sprintf("Zu Git synchronisiert:     %d", len(results.SyncedToGit)), "INFO")
	writeToLog(fmt.Sprintf("Zu ClawHub synchronisiert: %d", len(results.SyncedToClawHub)), "INFO")
	writeToLog(fmt.Sprintf("Bereits aktuell:           %d", len(results.UpToDate)), "INFO")
	writeToLog(fmt.Sprintf("Fehler:                    %d", len(results.Errors)), "INFO")
	if len(results.Errors) > 0 {
		writeToLog(fmt.Sprintf("  Fehlerhafte: %s", strings.Join(results.Errors, ", ")), "INFO")
	}
	writeToLog(strings.Repeat("=", 70), "INFO")

	// State speichern
	os.MkdirAll(filepath.Dir(STATE_FILE), 0755)
	
	state := State{
		LastRun: time.Now().Format(time.RFC3339),
		Results: results,
		ChangesDetected: map[string]interface{}{
			"new_in_clawhub": len(changesDetected.NewInClawHub),
			"new_in_git":     len(changesDetected.NewInGit),
			"clawhub_newer":  len(changesDetected.ClawHubNewer),
			"git_newer":      len(changesDetected.GitNewer),
			"synced":         len(changesDetected.Synced),
		},
	}
	
	file, _ := json.MarshalIndent(state, "", "  ")
	os.WriteFile(STATE_FILE, file, 0644)
	writeToLog(fmt.Sprintf("State gespeichert: %s", STATE_FILE), "INFO")
}

func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}
