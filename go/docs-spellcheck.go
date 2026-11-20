// abstraction-provenance: {"artifact_sha256": "9673bccd7a5f686f073372379af3766e28c7b8b91be2aad444e9558d2f6bac37", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "go"}
// docs-spellcheck.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	mode := ""
	if len(os.Args) > 1 {
		mode = os.Args[1]
	}

	writeFlag := []string{}
	if mode == "--write" {
		writeFlag = []string{"-w"}
	}

	args := []string{
		"README.md",
		"docs",
		"--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg",
		"-D",
		"-",
		"-D",
		"scripts/codespell-dictionary.txt",
		"-I",
		"scripts/codespell-ignore.txt",
	}
	args = append(args, writeFlag...)

	// Check if codespell is available in PATH
	if _, err := exec.LookPath("codespell"); err == nil {
		cmd := exec.Command("codespell", args...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			os.Exit(1)
		}
		os.Exit(0)
	}

	// Check if python3 is available
	if _, err := exec.LookPath("python3"); err == nil {
		// Try to install codespell with pip
		installCmd := exec.Command("python3", "-m", "pip", "install", "--user", "--disable-pip-version-check", "--break-system-packages", "codespell")
		installCmd.Stdout = nil
		installCmd.Stderr = nil
		err := installCmd.Run()
		if err != nil {
			// If the first attempt fails, try without --break-system-packages
			installCmd = exec.Command("python3", "-m", "pip", "install", "--user", "--disable-pip-version-check", "codespell")
			installCmd.Stdout = nil
			installCmd.Stderr = nil
			installCmd.Run()
		}

		// Get user base directory using Python
		pythonScript := `
import site
print(f"{site.USER_BASE}/bin")
`
		getPathCmd := exec.Command("python3", "-c", pythonScript)
		output, err := getPathCmd.Output()
		if err != nil {
			fmt.Fprintln(os.Stderr, "codespell unavailable: install codespell or python3")
			os.Exit(1)
		}

		userBin := strings.TrimSpace(string(output))
		codespellPath := filepath.Join(userBin, "codespell")

		// Check if codespell is executable at the user bin location
		if _, err := os.Stat(codespellPath); err == nil {
			cmd := exec.Command(codespellPath, args...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			err := cmd.Run()
			if err != nil {
				os.Exit(1)
			}
			os.Exit(0)
		}
	}

	fmt.Fprintln(os.Stderr, "codespell unavailable: install codespell or python3")
	os.Exit(1)
}
