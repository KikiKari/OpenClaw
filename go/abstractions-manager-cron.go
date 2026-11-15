// abstraction-provenance: {"artifact_sha256": "be285ea8ab8dda56416f8998ea1efcac910516e420da079d6739877d328d736e", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "go"}
// abstractions-manager-cron.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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

	// Load environment variables from .env file
	envFile := "/home/openclaw/.openclaw/.env"
	if _, err := os.Stat(envFile); err == nil {
		if err := loadEnvFile(envFile); err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Laden der Umgebungsvariablen: %v\n", err)
			os.Exit(1)
		}
	}

	// Check required OPENROUTER_API_KEY
	if os.Getenv("OPENROUTER_API_KEY") == "" {
		fmt.Fprintln(os.Stderr, "OPENROUTER_API_KEY fehlt")
		os.Exit(1)
	}

	// Set GITHUB_TOKEN with fallback chain
	ghToken := os.Getenv("GITHUB_TOKEN")
	if ghToken == "" {
		ghToken = os.Getenv("GH_TOKEN")
		if ghToken == "" {
			ghToken = os.Getenv("GH_ACCESS_TOKEN")
		}
	}
	os.Setenv("GITHUB_TOKEN", ghToken)

	// Lock file path
	lockFile := "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
	
	// Create lock directory if it doesn't exist
	lockDir := filepath.Dir(lockFile)
	if err := os.MkdirAll(lockDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen des Sperrverzeichnisses: %v\n", err)
		os.Exit(1)
	}

	// Try to acquire lock
	fd, err := syscall.Open(lockFile, syscall.O_CREAT|syscall.O_RDWR, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Öffnen der Sperrdatei: %v\n", err)
		os.Exit(1)
	}
	defer syscall.Close(fd)

	err = syscall.Flock(fd, syscall.LOCK_EX|syscall.LOCK_NB)
	if err != nil {
		// Another instance is running
		fmt.Fprintln(os.Stderr, "Eine andere Instanz läuft bereits")
		os.Exit(1)
	}

	// Execute the Python script
	scriptPath := "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"
	pythonPath := "/usr/bin/python3"
	
	cmd := exec.Command(pythonPath, append([]string{scriptPath}, os.Args[1:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	if err := cmd.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			fmt.Fprintf(os.Stderr, "Fehler beim Ausführen des Skripts: %v\n", err)
			os.Exit(1)
		}
	}
}

func loadEnvFile(filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// In Go we need to manually parse the env file
	// This is a simplified parser that handles KEY=VALUE lines
	data, err := os.ReadFile(filename)
	if err != nil {
		return err
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		
		if equal := strings.Index(line, "="); equal > 0 {
			key := line[:equal]
			value := line[equal+1:]
			
			// Remove quotes if present
			if len(value) >= 2 && value[0] == '"' && value[len(value)-1] == '"' {
				value = value[1 : len(value)-1]
			}
			
			os.Setenv(key, value)
		}
	}
	
	return nil
}
