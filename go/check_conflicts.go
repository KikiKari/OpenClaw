// abstraction-provenance: {"artifact_sha256": "e3ae1d06040833fb49a2237b0212846fc6fd36aae31bebca9209083203a2d5a0", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "go"}
// check_conflicts.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Check Conflicts - Erkennt Sync-Konflikte
*/

package main

import (
	"crypto/sha256"
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
)

type Conflict struct {
	File             string
	ClawHubModified  string
	GitModified      string
	Newer            string
}

type SkillConflict struct {
	Skill     string
	Conflicts []Conflict
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

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func checkConflicts() {
	conflicts := []SkillConflict{}

	// Alle Skills die in beiden Orten existieren
	commonSkills := []string{}
	if _, err := os.Stat(CLAWHUB_DIR); err == nil {
		if _, err := os.Stat(GIT_DIR); err == nil {
			clawhubSkills := make(map[string]bool)
			gitSkills := make(map[string]bool)

			filepath.Walk(CLAWHUB_DIR, func(path string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() == false {
					return nil
				}
				relPath, _ := filepath.Rel(CLAWHUB_DIR, path)
				if strings.Contains(path, ".git") == false && len(strings.Split(relPath, string(filepath.Separator))) == 1 {
					clawhubSkills[info.Name()] = true
				}
				return nil
			})

			filepath.Walk(GIT_DIR, func(path string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() == false {
					return nil
				}
				relPath, _ := filepath.Rel(GIT_DIR, path)
				if strings.Contains(path, ".git") == false && len(strings.Split(relPath, string(filepath.Separator))) == 1 {
					gitSkills[info.Name()] = true
				}
				return nil
			})

			for skill := range clawhubSkills {
				if gitSkills[skill] {
					commonSkills = append(commonSkills, skill)
				}
			}
		}
	}

	fmt.Printf("Prüfe %d Skills auf Konflikte...\n\n", len(commonSkills))

	sort.Strings(commonSkills)
	for _, skill := range commonSkills {
		clawhubPath := filepath.Join(CLAWHUB_DIR, skill)
		gitPath := filepath.Join(GIT_DIR, skill)

		skillConflicts := []Conflict{}

		// ClawHub Dateien
		clawhubFiles := make(map[string]string)
		filepath.Walk(clawhubPath, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() || strings.Contains(path, ".git") {
				return nil
			}
			relPath, _ := filepath.Rel(clawhubPath, path)
			clawhubFiles[relPath] = path
			return nil
		})

		// Git Dateien
		gitFiles := make(map[string]string)
		filepath.Walk(gitPath, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() || strings.Contains(path, ".git") {
				return nil
			}
			relPath, _ := filepath.Rel(gitPath, path)
			gitFiles[relPath] = path
			return nil
		})

		// Vergleiche gemeinsame Dateien
		for relPath := range clawhubFiles {
			if gitFile, exists := gitFiles[relPath]; exists {
				clawhubFile := clawhubFiles[relPath]

				clawhubHash, err1 := getFileHash(clawhubFile)
				gitHash, err2 := getFileHash(gitFile)

				if err1 != nil || err2 != nil {
					continue
				}

				if clawhubHash != gitHash {
					clawhubStat, _ := os.Stat(clawhubFile)
					gitStat, _ := os.Stat(gitFile)

					clawhubMtime := clawhubStat.ModTime()
					gitMtime := gitStat.ModTime()

					newer := "git"
					if clawhubMtime.After(gitMtime) {
						newer = "clawhub"
					}

					skillConflicts = append(skillConflicts, Conflict{
						File:            relPath,
						ClawHubModified: clawhubMtime.Format("2006-01-02 15:04:05"),
						GitModified:     gitMtime.Format("2006-01-02 15:04:05"),
						Newer:           newer,
					})
				}
			}
		}

		if len(skillConflicts) > 0 {
			conflicts = append(conflicts, SkillConflict{
				Skill:     skill,
				Conflicts: skillConflicts,
			})
		}
	}

	// Ausgabe
	if len(conflicts) > 0 {
		fmt.Println("⚠️  KONFLIKTE GEFUNDEN:")
		fmt.Println(strings.Repeat("=", 80))

		for _, conflict := range conflicts {
			fmt.Printf("\n📦 Skill: %s\n", conflict.Skill)
			fmt.Println(strings.Repeat("-", 40))

			for _, fileConflict := range conflict.Conflicts {
				fmt.Printf("  📄 %s\n", fileConflict.File)
				fmt.Printf("     ClawHub: %s\n", fileConflict.ClawHubModified)
				fmt.Printf("     Git:     %s\n", fileConflict.GitModified)
				fmt.Printf("     Neuer:   %s\n", strings.ToUpper(fileConflict.Newer))
				fmt.Println()
			}
		}

		fmt.Println(strings.Repeat("=", 80))
		fmt.Printf("Gesamt: %d Skills mit Konflikten\n", len(conflicts))
		fmt.Println("\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.")
	} else {
		fmt.Println("✅ Keine Konflikte gefunden!")
		fmt.Println("Alle gemeinsamen Skills sind synchron.")
	}
}

func main() {
	checkConflicts()
}
