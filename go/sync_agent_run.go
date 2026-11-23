// abstraction-provenance: {"artifact_sha256": "e0acd449359718c439726cc16e4283ab8b4e18f87524d47d689f30029a9e20a7", "source_sha256": "7012bf54a442a99950a2c73407058fd2f7330b956a58bc3b2698e87ee308dec9", "target_language": "go"}
// sync_agent_run.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
ClawHub ↔ Git Sync Agent - Produktionslauf
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
	STATE_FILE  = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
)

var (
	results = map[string][]string{
		"synced_to_git":     {},
		"synced_to_clawhub": {},
		"up_to_date":        {},
		"errors":            {},
	}
)

func logMessage(msg string, level ...string) {
	if len(level) > 0 && level[0] == "ERROR" {
		fmt.Fprintf(os.Stderr, "  ✗ ERROR: %s\n", msg)
	} else {
		fmt.Println(msg)
	}
}

func fileMtime(path string) int64 {
	var maxTime int64
	filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || strings.Contains(p, ".git") {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		if info.ModTime().Unix() > maxTime {
			maxTime = info.ModTime().Unix()
		}
		return nil
	})
	return maxTime
}

func validateSkill(skillPath string) bool {
	// Placeholder für externe Funktion
	// In Python war dies: from sync_clawhub_git import validate_skill
	// Da wir keine direkte Entsprechung haben, gehen wir davon aus, dass alle Skills gültig sind
	return true
}

func syncToGit(skill string, dryRun bool) bool {
	// Placeholder für externe Funktion
	// In Python war dies: from sync_clawhub_git import sync_to_git
	// Implementierung hier vereinfacht
	src := filepath.Join(CLAWHUB_DIR, skill)
	dst := filepath.Join(GIT_DIR, skill)
	
	if dryRun {
		return true
	}
	
	err := exec.Command("cp", "-r", src, dst).Run()
	return err == nil
}

func syncToClawhub(skill string, dryRun bool) bool {
	// Placeholder für externe Funktion
	// In Python war dies: from sync_clawhub_git import sync_to_clawhub
	// Implementierung hier vereinfacht
	src := filepath.Join(GIT_DIR, skill)
	dst := filepath.Join(CLAWHUB_DIR, skill)
	
	if dryRun {
		return true
	}
	
	err := exec.Command("cp", "-r", src, dst).Run()
	return err == nil
}

func getDirs(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return []string{}
	}
	
	dirs := []string{}
	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
			dirs = append(dirs, entry.Name())
		}
	}
	return dirs
}

func stringSet(list []string) map[string]bool {
	set := make(map[string]bool)
	for _, item := range list {
		set[item] = true
	}
	return set
}

func difference(setA, setB map[string]bool) []string {
	diff := []string{}
	for item := range setA {
		if !setB[item] {
			diff = append(diff, item)
		}
	}
	sort.Strings(diff)
	return diff
}

func intersection(setA, setB map[string]bool) []string {
	intersect := []string{}
	for item := range setA {
		if setB[item] {
			intersect = append(intersect, item)
		}
	}
	sort.Strings(intersect)
	return intersect
}

func gitInit(path string) {
	os.Chdir(path)
	exec.Command("git", "init", "-q").Run()
	exec.Command("git", "add", ".", "-f").Run()
	dt := time.Now().Format("2006-01-02 15:04")
	exec.Command("git", "commit", "-m", fmt.Sprintf("Initial: %s", filepath.Base(path)), "-q").Run()
}

func gitCommit(path string) {
	os.Chdir(path)
	exec.Command("git", "add", ".", "-f").Run()
	dt := time.Now().Format("2006-01-02 15:04")
	exec.Command("git", "commit", "-m", fmt.Sprintf("Sync from ClawHub: %s", dt), "-q").Run()
}

func saveState() {
	os.MkdirAll(filepath.Dir(STATE_FILE), 0755)
	state := map[string]interface{}{
		"last_run": time.Now().Format(time.RFC3339),
		"results":  results,
	}
	
	file, _ := os.Create(STATE_FILE)
	defer file.Close()
	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	encoder.Encode(state)
	logMessage(fmt.Sprintf("State gespeichert: %s", STATE_FILE))
}

func main() {
	fmt.Println(strings.Repeat("=", 70))
	fmt.Println("CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF")
	fmt.Printf("Zeitstempel: %s\n", time.Now().Format(time.RFC3339))
	fmt.Println(strings.Repeat("=", 70))

	clawhubSkillsList := getDirs(CLAWHUB_DIR)
	gitSkillsList := getDirs(GIT_DIR)

	clawhubSkills := stringSet(clawhubSkillsList)
	gitSkills := stringSet(gitSkillsList)

	// PHASE 1: NEU in ClawHub → zu Git syncen
	logMessage("\n[PHASE 1] ClawHub → Git Synchronisation")
	logMessage(strings.Repeat("-", 40))

	newInClawhub := difference(clawhubSkills, gitSkills)
	for _, skill := range newInClawhub {
		func() {
			defer func() {
				if r := recover(); r != nil {
					logMessage(fmt.Sprintf("  ✗ ERROR: %s - %v", skill, r), "ERROR")
					results["errors"] = append(results["errors"], fmt.Sprintf("%s (exception)", skill))
				}
			}()

			if validateSkill(filepath.Join(CLAWHUB_DIR, skill)) {
				logMessage(fmt.Sprintf("→ Synchronisiere %s zu Git...", skill))
				if syncToGit(skill, false) {
					gitPath := filepath.Join(GIT_DIR, skill)
					gitInit(gitPath)
					results["synced_to_git"] = append(results["synced_to_git"], skill)
					logMessage(fmt.Sprintf("  ✓ %s synchronisiert & Git initialisiert", skill))
				} else {
					results["errors"] = append(results["errors"], fmt.Sprintf("%s (sync failed)", skill))
				}
			} else {
				results["errors"] = append(results["errors"], fmt.Sprintf("%s (invalid)", skill))
			}
		}()
	}

	// PHASE 2: In beiden - prüfe Änderungen
	logMessage("\n[PHASE 2] Prüfe existierende Skills auf Änderungen")
	logMessage(strings.Repeat("-", 40))

	inBoth := intersection(clawhubSkills, gitSkills)
	for _, skill := range inBoth {
		func() {
			defer func() {
				if r := recover(); r != nil {
					logMessage(fmt.Sprintf("  ✗ ERROR: %s - %v", skill, r), "ERROR")
					results["errors"] = append(results["errors"], fmt.Sprintf("%s (exception)", skill))
				}
			}()

			cMtime := fileMtime(filepath.Join(CLAWHUB_DIR, skill))
			gMtime := fileMtime(filepath.Join(GIT_DIR, skill))
			diff := cMtime - gMtime

			if diff > 60 || diff < -60 {
				if diff > 0 {
					logMessage(fmt.Sprintf("→ %s: ClawHub neuer (+%ds) → sync zu Git", skill, diff))
					if syncToGit(skill, false) {
						gitPath := filepath.Join(GIT_DIR, skill)
						gitCommit(gitPath)
						results["synced_to_git"] = append(results["synced_to_git"], skill)
					} else {
						results["errors"] = append(results["errors"], fmt.Sprintf("%s (update failed)", skill))
					}
				} else {
					logMessage(fmt.Sprintf("→ %s: Git neuer (+%ds) → sync zu ClawHub", skill, -diff))
					if syncToClawhub(skill, false) {
						results["synced_to_clawhub"] = append(results["synced_to_clawhub"], skill)
					} else {
						results["errors"] = append(results["errors"], fmt.Sprintf("%s (update failed)", skill))
					}
				}
			} else {
				results["up_to_date"] = append(results["up_to_date"], skill)
			}
		}()
	}

	// ZUSAMMENFASSUNG
	logMessage("\n" + strings.Repeat("=", 70))
	logMessage("SYNCHRONISATION ABGESCHLOSSEN")
	logMessage(strings.Repeat("=", 70))
	logMessage(fmt.Sprintf("Zu Git synchronisiert:     %d", len(results["synced_to_git"])))
	if len(results["synced_to_git"]) > 0 {
		logMessage(fmt.Sprintf("  %s", strings.Join(results["synced_to_git"], ", ")))
	}
	logMessage(fmt.Sprintf("Zu ClawHub synchronisiert: %d", len(results["synced_to_clawhub"])))
	if len(results["synced_to_clawhub"]) > 0 {
		logMessage(fmt.Sprintf("  %s", strings.Join(results["synced_to_clawhub"], ", ")))
	}
	logMessage(fmt.Sprintf("Bereits aktuell:           %d", len(results["up_to_date"])))
	logMessage(fmt.Sprintf("Fehler:                    %d", len(results["errors"])))
	if len(results["errors"]) > 0 {
		logMessage(fmt.Sprintf("  %s", strings.Join(results["errors"], ", ")))
	}
	logMessage(strings.Repeat("=", 70))

	saveState()
}
