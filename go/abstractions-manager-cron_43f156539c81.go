// abstraction-provenance: {"artifact_sha256": "88d0c54b1472bf71f0e291bd270ab72aa9e35a2fe2165135bdca1f9864e07beb", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "go"}
// abstractions-manager-cron.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

func main() {
	// Set PATH
	os.Setenv("PATH", "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin")

	// Load environment variables from file
	envFile := "/home/openclaw/.openclaw/.env"
	if _, err := os.Stat(envFile); err == nil {
		loadEnvFile(envFile)
	}

	// Check required environment variable
	if os.Getenv("OPENROUTER_API_KEY") == "" {
		fmt.Fprintf(os.Stderr, "OPENROUTER_API_KEY fehlt\n")
		os.Exit(1)
	}

	// Set GITHUB_TOKEN with fallback values
	if os.Getenv("GITHUB_TOKEN") == "" {
		if ghToken := os.Getenv("GH_TOKEN"); ghToken != "" {
			os.Setenv("GITHUB_TOKEN", ghToken)
		} else if ghAccessToken := os.Getenv("GH_ACCESS_TOKEN"); ghAccessToken != "" {
			os.Setenv("GITHUB_TOKEN", ghAccessToken)
		}
	}

	// Execute with flock
	lockFile := "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
	scriptPath := "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"

	// Try to acquire lock non-blocking
	flockCmd := exec.Command("flock", "--nonblock", lockFile, "python3", scriptPath)
	flockCmd.Stdout = os.Stdout
	flockCmd.Stderr = os.Stderr
	flockCmd.Stdin = os.Stdin

	// Pass through arguments
	flockCmd.Args = append(flockCmd.Args, os.Args[1:]...)

	err := flockCmd.Run()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Fehler beim Ausführen: %v\n", err)
		os.Exit(1)
	}
}

func loadEnvFile(filename string) {
	file, err := os.Open(filename)
	if err != nil {
		return
	}
	defer file.Close()

	// In a real implementation, you would parse the .env file format
	// For now, we'll use the system's approach by sourcing via shell
	cmd := exec.Command("/bin/sh", "-c", fmt.Sprintf(". %s && env", filename))
	output, err := cmd.Output()
	if err != nil {
		return
	}

	// Parse and set environment variables
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "=") && !strings.HasPrefix(line, "#") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				os.Setenv(parts[0], parts[1])
			}
		}
	}
}
