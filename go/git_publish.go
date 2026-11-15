// abstraction-provenance: {"artifact_sha256": "2bc4c65e2ece5264a701f5678067814366b43fd41830c05719bdecf11d20bd07", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "go"}
// git_publish.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
// auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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

	"github.com/spf13/cobra"
)

var (
	skillsDir = filepath.Join(os.Getenv("HOME"), ".openclaw", "workspace", "skills")
)

func gitCommit(skillPath string, message string) bool {
	if message == "" {
		message = fmt.Sprintf("[skill] Auto-update %s - %s", filepath.Base(skillPath), time.Now().Format(time.RFC3339))
	}

	cmd := exec.Command("git", "add", skillPath)
	cmd.Dir = filepath.Dir(skillsDir)
	err := cmd.Run()
	if err != nil {
		return false
	}

	cmd = exec.Command("git", "commit", "-m", message)
	cmd.Dir = filepath.Dir(skillsDir)
	err = cmd.Run()
	return err == nil
}

func clawhubPublish(skillName string) (bool, string) {
	skillPath := filepath.Join(skillsDir, skillName)
	cmd := exec.Command("clawhub", "publish", skillPath, "--slug", skillName, "--version", "1.0.0")
	output, err := cmd.CombinedOutput()
	return err == nil, string(output)
}

func batchPublish() {
	cmd := exec.Command("git", "status", "--short", skillsDir)
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error getting git status:", err)
		return
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	changed := make(map[string]bool)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && strings.Contains(line, "skills/") {
			parts := strings.Split(line, "skills/")
			if len(parts) > 1 {
				skillPart := strings.Split(parts[1], "/")[0]
				changed[skillPart] = true
			}
		}
	}

	changedList := make([]string, 0, len(changed))
	for skill := range changed {
		changedList = append(changedList, skill)
	}

	fmt.Printf("Changed skills: %v\n", changedList)

	for i, skill := range changedList[:min(5, len(changedList))] {
		if i > 0 {
			fmt.Println("Waiting 15min for rate limit...")
			// In real: time.Sleep(15 * time.Minute)
		}

		fmt.Printf("Publishing %s...\n", skill)
		commitOk := gitCommit(filepath.Join(skillsDir, skill), "")
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

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func main() {
	var rootCmd = &cobra.Command{
		Use:   "git-publish",
		Short: "Git Publish Agent",
		Run: func(cmd *cobra.Command, args []string) {
			skill, _ := cmd.Flags().GetString("skill")
			all, _ := cmd.Flags().GetBool("all")
			noPublish, _ := cmd.Flags().GetBool("no-publish")
			message, _ := cmd.Flags().GetString("message")

			if skill != "" {
				skillPath := filepath.Join(skillsDir, skill)
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
		},
	}

	rootCmd.Flags().String("skill", "", "Single skill to publish")
	rootCmd.Flags().Bool("all", false, "Publish all changed")
	rootCmd.Flags().Bool("no-publish", false, "Commit only")
	rootCmd.Flags().String("message", "", "Custom commit message")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
