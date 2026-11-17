// abstraction-provenance: {"artifact_sha256": "a3111d61fd20a44f8b3db179643b3740f90db38f148fa107eef6a86d19b9b58e", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "go"}
// git_publish.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
// auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

// Git Publish Agent - Automatisierte Skill-Veröffentlichung

package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var SKILLS_DIR = filepath.Join(os.Getenv("HOME"), ".openclaw", "workspace", "skills")

func gitCommit(skillPath string, message string) bool {
	// Commit skill changes.
	if message == "" {
		now := time.Now().Format(time.RFC3339)
		message = fmt.Sprintf("[skill] Auto-update %s - %s", filepath.Base(skillPath), now)
	}

	// git add
	cmd := exec.Command("git", "add", skillPath)
	cmd.Dir = filepath.Dir(SKILLS_DIR)
	err := cmd.Run()
	if err != nil {
		fmt.Printf("git add failed: %v\n", err)
		return false
	}

	// git commit
	cmd = exec.Command("git", "commit", "-m", message)
	cmd.Dir = filepath.Dir(SKILLS_DIR)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("git commit failed: %v\n%s\n", err, string(output))
		return false
	}
	return true
}

func clawhubPublish(skillName string) (bool, string) {
	// Publish to ClawHub.
	skillPath := filepath.Join(SKILLS_DIR, skillName)
	cmd := exec.Command("clawhub", "publish", skillPath,
		"--slug", skillName,
		"--version", "1.0.0")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return false, string(output)
	}
	return true, string(output)
}

func batchPublish() {
	// Publish all changed skills with rate limiting.
	// Check git status
	cmd := exec.Command("git", "status", "--short", SKILLS_DIR)
	cmd.Dir = filepath.Dir(SKILLS_DIR)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("git status failed: %v\n", err)
		return
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	seen := make(map[string]bool)
	changed := []string{}

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && strings.Contains(line, "skills/") {
			parts := strings.Split(line, "skills/")
			if len(parts) > 1 {
				skillPart := strings.Split(parts[1], "/")[0]
				if !seen[skillPart] {
					seen[skillPart] = true
					changed = append(changed, skillPart)
				}
			}
		}
	}

	fmt.Printf("Changed skills: %v\n", changed)

	// Publish with delay
	limit := len(changed)
	if limit > 5 {
		limit = 5 // Max 5 per batch
	}
	for i := 0; i < limit; i++ {
		skill := changed[i]
		if i > 0 {
			fmt.Println("Waiting 15min for rate limit...")
			// In real: time.Sleep(15 * time.Minute)
		}

		fmt.Printf("Publishing %s...\n", skill)
		commitOk := gitCommit(filepath.Join(SKILLS_DIR, skill), "")
		if commitOk {
			pubOk, output := clawhubPublish(skill)
			status := "✗"
			if pubOk {
				status = "✓"
			}
			fmt.Printf("  %s %s\n", status, output)
		}
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Use --skill <name> or --all")
		return
	}

	args := os.Args[1:]
	skill := ""
	message := ""
	all := false
	noPublish := false

	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--skill":
			i++
			if i < len(args) {
				skill = args[i]
			}
		case "--all":
			all = true
		case "--no-publish":
			noPublish = true
		case "--message":
			i++
			if i < len(args) {
				message = args[i]
			}
		}
		i++
	}

	if skill != "" {
		skillPath := filepath.Join(SKILLS_DIR, skill)
		if noPublish {
			gitCommit(skillPath, message)
		} else {
			gitCommit(skillPath, message)
			clawhubPublish(skill)
		}
	} else if all {
		batchPublish()
	} else {
		fmt.Println("Use --skill <name> or --all")
	}
}
