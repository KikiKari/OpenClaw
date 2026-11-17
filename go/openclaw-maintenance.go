// abstraction-provenance: {"artifact_sha256": "5ac108c23fce265b906621e91adb9e9ca1a3e53503d8c131d5e7fffa8a764087", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "go"}
// openclaw-maintenance.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	// === 1. Service-/Config-Drift ===
	runCommand("openclaw", "doctor")

	// === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
	runCommand("openclaw", "plugins", "registry", "--refresh")
	runCommand("openclaw", "plugins", "update", "--all")

	// === 3. Tasks ===
	runCommand("openclaw", "tasks", "maintenance", "--apply")

	// === 4. Sessions – alle Agents auf einmal ===
	runCommand("openclaw", "sessions", "cleanup", "--enforce", "--all-agents")

	// === 5. Memory – status/index decken alle Agents ab ===
	runCommand("openclaw", "memory", "status", "--deep", "--fix")
	runCommand("openclaw", "memory", "index", "--force")

	// === 6. Memory promote – MUSS pro Agent ===
	agents := []string{"main", "knecht", "docs", "ops-hub", "cron"}
	for _, agent := range agents {
		runCommand("openclaw", "memory", "promote", "--apply", "--agent", agent)
	}

	// === 7. Secrets ===
	runCommand("openclaw", "secrets", "reload")
}

func runCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Ausführen von %s %v: %v\n", name, args, err)
		os.Exit(1)
	}
}
