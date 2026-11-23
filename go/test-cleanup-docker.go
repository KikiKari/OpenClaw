// abstraction-provenance: {"artifact_sha256": "f7384c37e186b8e83686cd35eaef3203265a95ef584e4b1082bd1c8d1106b4d0", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "go"}
// test-cleanup-docker.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Get root directory (equivalent to ROOT_DIR in bash)
	rootDir, err := filepath.Abs(filepath.Join(filepath.Dir(os.Args[0]), ".."))
	if err != nil {
		log.Fatal(err)
	}

	// Source the docker-e2e-logs.sh library functionality
	// In Go we implement the logging functionality directly
	
	// Get environment variables with defaults
	imageName := getEnvOrDefault("OPENCLAW_CLEANUP_SMOKE_IMAGE", "openclaw-cleanup-smoke:local")
	platform := getEnvOrDefault("OPENCLAW_CLEANUP_SMOKE_PLATFORM", "linux/amd64")

	fmt.Printf("==> Build image: %s\n", imageName)

	// Build the Docker image
	dockerfilePath := filepath.Join(rootDir, "scripts/docker/cleanup-smoke/Dockerfile")
	buildArgs := []string{
		"build",
		"-t", imageName,
		"-f", dockerfilePath,
		rootDir,
	}

	if err := runLogged("cleanup-build", "docker", buildArgs...); err != nil {
		log.Fatal(err)
	}

	fmt.Println("==> Run cleanup smoke test")
	
	// Run the Docker container
	runArgs := []string{
		"run", "--rm", "--platform", platform, "-t", imageName,
	}
	
	cmd := exec.Command("docker", runArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	
	if err := cmd.Run(); err != nil {
		log.Fatal(err)
	}
}

// getEnvOrDefault gets an environment variable or returns a default value
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// runLogged executes a command and logs its output (similar to run_logged function)
func runLogged(logPrefix, command string, args ...string) error {
	cmd := exec.Command(command, args...)
	
	// Create log file
	logFile, err := os.Create(fmt.Sprintf("%s.log", logPrefix))
	if err != nil {
		return fmt.Errorf("failed to create log file: %w", err)
	}
	defer logFile.Close()
	
	// Set output to both stdout/stderr and log file
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	
	// Run the command
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("command failed: %w", err)
	}
	
	return nil
}
