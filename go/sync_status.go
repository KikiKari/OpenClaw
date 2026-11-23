// abstraction-provenance: {"artifact_sha256": "fc1bc520915bb05bc4c79720521534b703f495115250da95857a16d9fabc5bb7", "source_sha256": "bdae82d3ec0fc4e8614fc802f7059942e7aba36bab0cd06bdf01f8376c3c863c", "target_language": "go"}
// sync_status.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_status.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_status.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Sync Status - Zeigt Status aller Skills
*/

package main

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"os"
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

type SkillStatus struct {
	Name         string            `json:"name"`
	InClawHub    bool              `json:"in_clawhub"`
	InGit        bool              `json:"in_git"`
	HasGitRepo   bool              `json:"has_git_repo"`
	Status       string            `json:"status"`
	LastModified map[string]string `json:"last_modified,omitempty"`
}

func getFileHash(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := md5.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func getMaxModTime(dir string, excludeGit bool) (time.Time, error) {
	var maxTime time.Time
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && strings.Contains(path, ".git") && excludeGit {
			return filepath.SkipDir
		}
		if info.Mode().IsRegular() {
			if excludeGit && strings.Contains(path, ".git") {
				return nil
			}
			if info.ModTime().After(maxTime) {
				maxTime = info.ModTime()
			}
		}
		return nil
	})
	return maxTime, err
}

func checkSkillStatus(skillName string) SkillStatus {
	clawhubPath := filepath.Join(CLAWHUB_DIR, skillName)
	gitPath := filepath.Join(GIT_DIR, skillName)

	status := SkillStatus{
		Name:         skillName,
		InClawHub:    exists(clawhubPath),
		InGit:        exists(gitPath),
		HasGitRepo:   exists(filepath.Join(gitPath, ".git")),
		Status:       "unknown",
		LastModified: make(map[string]string),
	}

	// Status bestimmen
	if status.InClawHub && !status.InGit {
		status.Status = "only_clawhub"
	} else if status.InGit && !status.InClawHub {
		status.Status = "only_git"
	} else if status.InClawHub && status.InGit {
		// Timestamps vergleichen
		clawhubTime, err1 := getMaxModTime(clawhubPath, false)
		gitTime, err2 := getMaxModTime(gitPath, true)

		if err1 != nil || err2 != nil {
			status.Status = "error"
		} else {
			status.LastModified["clawhub"] = clawhubTime.Format("2006-01-02 15:04:05")
			status.LastModified["git"] = gitTime.Format("2006-01-02 15:04:05")

			diff := clawhubTime.Sub(gitTime)
			if diff < time.Minute && diff > -time.Minute {
				status.Status = "synced"
			} else if clawhubTime.After(gitTime) {
				status.Status = "clawhub_newer"
			} else {
				status.Status = "git_newer"
			}
		}
	}

	return status
}

func main() {
	fmt.Println(strings.Repeat("=", 80))
	fmt.Println("ClawHub ↔ Git Sync Status")
	fmt.Println(strings.Repeat("=", 80))
	fmt.Printf("Zeitpunkt: %s\n\n", time.Now().Format("2006-01-02 15:04:05"))

	// Alle Skills finden
	allSkills := make(map[string]bool)

	// Skills aus ClawHub
	if entries, err := os.ReadDir(CLAWHUB_DIR); err == nil {
		for _, entry := range entries {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
				allSkills[entry.Name()] = true
			}
		}
	}

	// Skills aus Git
	if entries, err := os.ReadDir(GIT_DIR); err == nil {
		for _, entry := range entries {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
				allSkills[entry.Name()] = true
			}
		}
	}

	// Status-Kategorien
	categories := map[string][]SkillStatus{
		"synced":        {},
		"clawhub_newer": {},
		"git_newer":     {},
		"only_clawhub":  {},
		"only_git":      {},
		"error":         {},
	}

	// Status für jeden Skill prüfen
	skillNames := make([]string, 0, len(allSkills))
	for name := range allSkills {
		skillNames = append(skillNames, name)
	}
	sort.Strings(skillNames)

	for _, skill := range skillNames {
		status := checkSkillStatus(skill)
		categories[status.Status] = append(categories[status.Status], status)
	}

	// Ausgabe
	fmt.Printf("📊 Gesamt: %d Skills\n\n", len(allSkills))

	// Synchronisiert
	if len(categories["synced"]) > 0 {
		fmt.Printf("✅ Synchronisiert (%d)\n", len(categories["synced"]))
		for _, s := range categories["synced"] {
			fmt.Printf("   - %s\n", s.Name)
		}
		fmt.Println()
	}

	// ClawHub neuer
	if len(categories["clawhub_newer"]) > 0 {
		fmt.Printf("🔄 ClawHub neuer (%d)\n", len(categories["clawhub_newer"]))
		for _, s := range categories["clawhub_newer"] {
			fmt.Printf("   - %s (ClawHub: %s)\n", s.Name, s.LastModified["clawhub"])
		}
		fmt.Println()
	}

	// Git neuer
	if len(categories["git_newer"]) > 0 {
		fmt.Printf("🔄 Git neuer (%d)\n", len(categories["git_newer"]))
		for _, s := range categories["git_newer"] {
			fmt.Printf("   - %s (Git: %s)\n", s.Name, s.LastModified["git"])
		}
		fmt.Println()
	}

	// Nur in ClawHub
	if len(categories["only_clawhub"]) > 0 {
		fmt.Printf("📦 Nur in ClawHub (%d)\n", len(categories["only_clawhub"]))
		for _, s := range categories["only_clawhub"] {
			fmt.Printf("   - %s\n", s.Name)
		}
		fmt.Println()
	}

	// Nur in Git
	if len(categories["only_git"]) > 0 {
		fmt.Printf("📁 Nur in Git (%d)\n", len(categories["only_git"]))
		for _, s := range categories["only_git"] {
			fmt.Printf("   - %s\n", s.Name)
		}
		fmt.Println()
	}

	// Fehler
	if len(categories["error"]) > 0 {
		fmt.Printf("❌ Fehler (%d)\n", len(categories["error"]))
		for _, s := range categories["error"] {
			fmt.Printf("   - %s\n", s.Name)
		}
		fmt.Println()
	}

	// State-File Info
	if exists(STATE_FILE) {
		file, err := os.Open(STATE_FILE)
		if err == nil {
			defer file.Close()
			var state map[string]interface{}
			if err := json.NewDecoder(file).Decode(&state); err == nil {
				if lastSync, ok := state["last_sync"].(map[string]interface{}); ok {
					var dates []string
					for date := range lastSync {
						dates = append(dates, date)
					}
					sort.Strings(dates)
					if len(dates) > 0 {
						fmt.Printf("📅 Letzter automatischer Sync: %s\n", dates[len(dates)-1])
					}
				}
			}
		}
	}

	fmt.Println(strings.Repeat("=", 80))
}
