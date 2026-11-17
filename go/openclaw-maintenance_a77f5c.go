// abstraction-provenance: {"artifact_sha256": "419a3e3936580834725edf8684580638096fce8ffab0b3b2a16f688790bfe7df", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "go"}
// openclaw-maintenance.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	openclawBin := os.Getenv("OPENCLAW_BIN")
	if openclawBin == "" {
		openclawBin = filepath.Join(os.Getenv("HOME"), ".local", "bin", "openclaw")
	}

	// Prüfe ob die Binary existiert und ausführbar ist
	if _, err := os.Stat(openclawBin); os.IsNotExist(err) || os.FileMode(0).IsDir() {
		fmt.Fprintf(os.Stderr, "ERROR: OpenClaw binary not found: %s\n", openclawBin)
		os.Exit(1)
	}

	// Zeige Version
	versionCmd := exec.Command(openclawBin, "--version")
	versionOutput, err := versionCmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Failed to get OpenClaw version: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Using OpenClaw: %s", string(versionOutput))

	// === 1. Service-/Config-Drift ===
	doctorCmd := exec.Command(openclawBin, "doctor")
	doctorCmd.Stdout = os.Stdout
	doctorCmd.Stderr = os.Stderr
	if err := doctorCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: doctor command failed: %v\n", err)
		os.Exit(1)
	}

	// === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
	registryCmd := exec.Command(openclawBin, "plugins", "registry", "--refresh")
	registryCmd.Stdout = os.Stdout
	registryCmd.Stderr = os.Stderr
	if err := registryCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: plugins registry command failed: %v\n", err)
		os.Exit(1)
	}

	runPluginUpdate := os.Getenv("RUN_PLUGIN_UPDATE")
	if runPluginUpdate == "1" {
		updateCmd := exec.Command(openclawBin, "plugins", "update", "--all")
		updateCmd.Stdout = os.Stdout
		updateCmd.Stderr = os.Stderr
		if err := updateCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: plugins update command failed: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Println("Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.")
	}

	// === 3. Tasks ===
	tasksCmd := exec.Command(openclawBin, "tasks", "maintenance", "--apply")
	tasksCmd.Stdout = os.Stdout
	tasksCmd.Stderr = os.Stderr
	if err := tasksCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: tasks maintenance command failed: %v\n", err)
		os.Exit(1)
	}

	// === 4. Sessions – alle Agents auf einmal ===
	sessionsCmd := exec.Command(openclawBin, "sessions", "cleanup", "--enforce", "--all-agents")
	sessionsCmd.Stdout = os.Stdout
	sessionsCmd.Stderr = os.Stderr
	if err := sessionsCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: sessions cleanup command failed: %v\n", err)
		os.Exit(1)
	}

	// === 5. Memory – status/index decken alle Agents ab ===
	memoryStatusCmd := exec.Command(openclawBin, "memory", "status", "--deep", "--fix")
	memoryStatusCmd.Stdout = os.Stdout
	memoryStatusCmd.Stderr = os.Stderr
	if err := memoryStatusCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: memory status command failed: %v\n", err)
		os.Exit(1)
	}

	memoryIndexCmd := exec.Command(openclawBin, "memory", "index", "--force")
	memoryIndexCmd.Stdout = os.Stdout
	memoryIndexCmd.Stderr = os.Stderr
	if err := memoryIndexCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: memory index command failed: %v\n", err)
		os.Exit(1)
	}

	// === 6. Memory promote – MUSS pro Agent ===
	agents := []string{"main", "knecht", "docs", "ops-hub", "cron"}
	for _, agent := range agents {
		promoteCmd := exec.Command(openclawBin, "memory", "promote", "--apply", "--agent", agent)
		promoteCmd.Stdout = os.Stdout
		promoteCmd.Stderr = os.Stderr
		if err := promoteCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: memory promote command failed for agent %s: %v\n", agent, err)
			os.Exit(1)
		}
	}

	// === 7. Secrets ===
	secretsCmd := exec.Command(openclawBin, "secrets", "reload")
	secretsCmd.Stdout = os.Stdout
	secretsCmd.Stderr = os.Stderr
	if err := secretsCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: secrets reload command failed: %v\n", err)
		os.Exit(1)
	}
}
