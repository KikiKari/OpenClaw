// abstraction-provenance: {"artifact_sha256": "cbf41dae5c2adc729381f4348bcac925a7605fd0dae1b44223d5eb589e60807c", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "go"}
// format.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Bestimme das Wurzelverzeichnis (zwei Ebenen über dem Skript-Verzeichnis)
	scriptDir := filepath.Dir(os.Args[0])
	root := filepath.Join(scriptDir, "..", "..")
	
	// Konfigurationsdatei und Zielverzeichnis
	config := filepath.Join(root, ".swiftformat")
	sources := filepath.Join(root, "Sources")
	
	// Führe swiftformat aus
	cmd := exec.Command("swiftformat", "--config", config, sources)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Ausführen von swiftformat: %v\n", err)
		os.Exit(1)
	}
}
