// abstraction-provenance: {"artifact_sha256": "1f98e5a4b1df3ccd721fd8289e8b6251558c9fc4becfa914bf3df9d59de6eff3", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "go"}
// sync_bulk.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Bulk Sync - Synchronisiert alle Skills
*/

package main

import (
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
	GIT_DIR     = "/home/openclaw/.openclaw/workspace/git/skills"
)

// syncToGit simulates syncing to git (replace with actual implementation)
func syncToGit(skill string, dryRun bool) bool {
	// Placeholder implementation - replace with actual sync logic
	if !dryRun {
		log.Printf("Actually syncing %s to Git\n", skill)
	}
	return true
}

// syncToClawHub simulates syncing to clawhub (replace with actual implementation)
func syncToClawHub(skill string, dryRun bool) bool {
	// Placeholder implementation - replace with actual sync logic
	if !dryRun {
		log.Printf("Actually syncing %s to ClawHub\n", skill)
	}
	return true
}

// validateSkill checks if a skill is valid (replace with actual validation)
func validateSkill(path string) bool {
	// Placeholder implementation - replace with actual validation logic
	_, err := os.Stat(path)
	return err == nil
}

// logMessage logs messages with optional level
func logMessage(message string, level ...string) {
	if len(level) > 0 && level[0] == "ERROR" {
		log.Printf("ERROR: %s\n", message)
	} else {
		log.Println(message)
	}
}

// getMaxModTime finds the latest modification time in a directory
func getMaxModTime(dir string) (time.Time, error) {
	var maxTime time.Time
	
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
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
			info, err := d.Info()
			if err != nil {
				return err
			}
			
			if info.ModTime().After(maxTime) {
				maxTime = info.ModTime()
			}
		}
		return nil
	})
	
	return maxTime, err
}

func syncAllSkills(dryRun bool) {
	// Alle Skills finden
	allSkills := make(map[string]bool)
	
	// Check CLAWHUB_DIR
	if _, err := os.Stat(CLAWHUB_DIR); err == nil {
		entries, _ := os.ReadDir(CLAWHUB_DIR)
		for _, entry := range entries {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
				allSkills[entry.Name()] = true
			}
		}
	}
	
	// Check GIT_DIR
	if _, err := os.Stat(GIT_DIR); err == nil {
		entries, _ := os.ReadDir(GIT_DIR)
		for _, entry := range entries {
			if entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
				allSkills[entry.Name()] = true
			}
		}
	}
	
	skillList := make([]string, 0, len(allSkills))
	for skill := range allSkills {
		skillList = append(skillList, skill)
	}
	sort.Strings(skillList)
	
	logMessage(fmt.Sprintf("Bulk Sync: %d Skills gefunden", len(skillList)))
	
	results := struct {
		Synced   []string
		Skipped  []string
		Failed   []string
	}{
		Synced:  make([]string, 0),
		Skipped: make([]string, 0),
		Failed:  make([]string, 0),
	}
	
	for _, skill := range skillList {
		clawhubPath := filepath.Join(CLAWHUB_DIR, skill)
		gitPath := filepath.Join(GIT_DIR, skill)
		
		clawhubExists := false
		gitExists := false
		
		if _, err := os.Stat(clawhubPath); err == nil {
			clawhubExists = true
		}
		
		if _, err := os.Stat(gitPath); err == nil {
			gitExists = true
		}
		
		func() {
			defer func() {
				if r := recover(); r != nil {
					logMessage(fmt.Sprintf("Error processing %s: %v", skill, r), "ERROR")
					results.Failed = append(results.Failed, skill)
				}
			}()
			
			// Nur in ClawHub → zu Git
			if clawhubExists && !gitExists {
				if validateSkill(clawhubPath) {
					logMessage(fmt.Sprintf("Syncing %s to Git...", skill))
					if syncToGit(skill, dryRun) {
						results.Synced = append(results.Synced, fmt.Sprintf("%s → Git", skill))
					} else {
						results.Failed = append(results.Failed, skill)
					}
				} else {
					results.Skipped = append(results.Skipped, fmt.Sprintf("%s (validation failed)", skill))
				}
			} else if gitExists && !clawhubExists {
				// Nur in Git → zu ClawHub
				if validateSkill(gitPath) {
					logMessage(fmt.Sprintf("Syncing %s to ClawHub...", skill))
					if syncToClawHub(skill, dryRun) {
						results.Synced = append(results.Synced, fmt.Sprintf("%s → ClawHub", skill))
					} else {
						results.Failed = append(results.Failed, skill)
					}
				} else {
					results.Skipped = append(results.Skipped, fmt.Sprintf("%s (validation failed)", skill))
				}
			} else if clawhubExists && gitExists {
				// In beiden - prüfe ob Update nötig
				clawhubTime, err1 := getMaxModTime(clawhubPath)
				gitTime, err2 := getMaxModTime(gitPath)
				
				if err1 == nil && err2 == nil {
					diff := clawhubTime.Sub(gitTime)
					if diff < -diff {
						diff = -diff
					}
					
					if diff > 60*time.Second {
						if clawhubTime.After(gitTime) {
							logMessage(fmt.Sprintf("Updating %s in Git...", skill))
							if syncToGit(skill, dryRun) {
								results.Synced = append(results.Synced, fmt.Sprintf("%s → Git (update)", skill))
							} else {
								results.Failed = append(results.Failed, skill)
							}
						} else {
							logMessage(fmt.Sprintf("Updating %s in ClawHub...", skill))
							if syncToClawHub(skill, dryRun) {
								results.Synced = append(results.Synced, fmt.Sprintf("%s → ClawHub (update)", skill))
							} else {
								results.Failed = append(results.Failed, skill)
							}
						}
					} else {
						results.Skipped = append(results.Skipped, fmt.Sprintf("%s (already synced)", skill))
					}
				}
			}
		}()
	}
	
	// Zusammenfassung
	fmt.Println("\n" + strings.Repeat("=", 60))
	if dryRun {
		fmt.Println("Bulk Sync DRY-RUN - Zusammenfassung")
	} else {
		fmt.Println("Bulk Sync EXECUTED - Zusammenfassung")
	}
	fmt.Println(strings.Repeat("=", 60))
	fmt.Printf("✅ Synchronisiert: %d\n", len(results.Synced))
	for _, item := range results.Synced {
		fmt.Printf("   - %s\n", item)
	}
	fmt.Printf("\n⏭️  Übersprungen: %d\n", len(results.Skipped))
	if len(results.Skipped) <= 10 {
		for _, item := range results.Skipped {
			fmt.Printf("   - %s\n", item)
		}
	} else {
		fmt.Printf("   - %d Skills (bereits synchron oder Validierung fehlgeschlagen)\n", len(results.Skipped))
	}
	fmt.Printf("\n❌ Fehlgeschlagen: %d\n", len(results.Failed))
	for _, item := range results.Failed {
		fmt.Printf("   - %s\n", item)
	}
	fmt.Println(strings.Repeat("=", 60))
}

func main() {
	dryRun := flag.Bool("dry-run", false, "Nur Änderungen anzeigen")
	execute := flag.Bool("execute", false, "Sync ausführen")
	
	flag.Parse()
	
	if !*dryRun && !*execute {
		fmt.Println("Bitte --dry-run oder --execute angeben")
		os.Exit(1)
	}
	
	syncAllSkills(*dryRun)
}
