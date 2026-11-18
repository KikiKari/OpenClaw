// abstraction-provenance: {"artifact_sha256": "3334daa54b8842616ea0d65d51d7962a6d4e3f5b89a4d9dd61b615d8922199dc", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "go"}
// check_conflicts.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

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

// getFileHash berechnet den SHA256-Hash einer Datei
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

// listDirs listet alle Unterverzeichnisse eines Pfades auf
func listDirs(root string) ([]string, error) {
	var dirs []string
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, entry.Name())
		}
	}

	return dirs, nil
}

// getAllFiles sammelt rekursiv alle Dateien in einem Verzeichnis (ohne .git)
func getAllFiles(root string) (map[string]string, error) {
	files := make(map[string]string)

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Überspringe .git Verzeichnisse
		if strings.Contains(path, ".git") {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if !info.IsDir() {
			relPath, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			files[relPath] = path
		}

		return nil
	})

	return files, err
}

// checkConflicts prüft auf Konflikte zwischen ClawHub und Git
func checkConflicts() {
	conflicts := []map[string]interface{}{}

	// Prüfe ob beide Verzeichnisse existieren
	if _, err := os.Stat(CLAWHUB_DIR); os.IsNotExist(err) {
		fmt.Println("ClawHub Verzeichnis nicht gefunden")
		return
	}
	if _, err := os.Stat(GIT_DIR); os.IsNotExist(err) {
		fmt.Println("Git Verzeichnis nicht gefunden")
		return
	}

	// Hole alle Skills aus beiden Verzeichnissen
	clawhubSkillsList, err := listDirs(CLAWHUB_DIR)
	if err != nil {
		fmt.Printf("Fehler beim Lesen von ClawHub: %v\n", err)
		return
	}

	gitSkillsList, err := listDirs(GIT_DIR)
	if err != nil {
		fmt.Printf("Fehler beim Lesen von Git: %v\n", err)
		return
	}

	// Erstelle Sets für schnelleren Lookup
	clawhubSkills := make(map[string]bool)
	gitSkills := make(map[string]bool)

	for _, skill := range clawhubSkillsList {
		clawhubSkills[skill] = true
	}
	for _, skill := range gitSkillsList {
		gitSkills[skill] = true
	}

	// Finde gemeinsame Skills
	commonSkills := []string{}
	for skill := range clawhubSkills {
		if gitSkills[skill] {
			commonSkills = append(commonSkills, skill)
		}
	}

	sort.Strings(commonSkills)
	fmt.Printf("Prüfe %d Skills auf Konflikte...\n\n", len(commonSkills))

	// Prüfe jeden gemeinsamen Skill
	for _, skill := range commonSkills {
		clawhubPath := filepath.Join(CLAWHUB_DIR, skill)
		gitPath := filepath.Join(GIT_DIR, skill)

		skillConflicts := []map[string]interface{}{}

		// Hole alle Dateien beider Verzeichnisse
		clawhubFiles, err := getAllFiles(clawhubPath)
		if err != nil {
			fmt.Printf("Fehler beim Durchsuchen von ClawHub/%s: %v\n", skill, err)
			continue
		}

		gitFiles, err := getAllFiles(gitPath)
		if err != nil {
			fmt.Printf("Fehler beim Durchsuchen von Git/%s: %v\n", skill, err)
			continue
		}

		// Finde gemeinsame Dateien
		commonFiles := []string{}
		for file := range clawhubFiles {
			if _, exists := gitFiles[file]; exists {
				commonFiles = append(commonFiles, file)
			}
		}

		// Vergleiche Dateien
		for _, relPath := range commonFiles {
			clawhubFile := clawhubFiles[relPath]
			gitFile := gitFiles[relPath]

			clawhubHash, err1 := getFileHash(clawhubFile)
			gitHash, err2 := getFileHash(gitFile)

			if err1 != nil || err2 != nil {
				fmt.Printf("Fehler beim Hash-Berechnung für %s: %v, %v\n", relPath, err1, err2)
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

				skillConflicts = append(skillConflicts, map[string]interface{}{
					"file":             relPath,
					"clawhub_modified": clawhubMtime.Format("2006-01-02 15:04:05"),
					"git_modified":     gitMtime.Format("2006-01-02 15:04:05"),
					"newer":            newer,
				})
			}
		}

		if len(skillConflicts) > 0 {
			conflicts = append(conflicts, map[string]interface{}{
				"skill":     skill,
				"conflicts": skillConflicts,
			})
		}
	}

	// Ausgabe
	if len(conflicts) > 0 {
		fmt.Println("⚠️  KONFLIKTE GEFUNDEN:")
		fmt.Println(strings.Repeat("=", 80))

		for _, conflict := range conflicts {
			fmt.Printf("\n📦 Skill: %s\n", conflict["skill"])
			fmt.Println(strings.Repeat("-", 40))

			conflictList := conflict["conflicts"].([]map[string]interface{})
			for _, fileConflict := range conflictList {
				fmt.Printf("  📄 %s\n", fileConflict["file"])
				fmt.Printf("     ClawHub: %s\n", fileConflict["clawhub_modified"])
				fmt.Printf("     Git:     %s\n", fileConflict["git_modified"])
				fmt.Printf("     Neuer:   %s\n", strings.ToUpper(fileConflict["newer"].(string)))
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
