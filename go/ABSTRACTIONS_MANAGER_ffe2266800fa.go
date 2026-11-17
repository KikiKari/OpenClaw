// abstraction-provenance: {"artifact_sha256": "2622e6e6a6e2cf705562351262bb7663f08d1929480f3ee0ad8c599e80e97a15", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "go"}
// ABSTRACTIONS_MANAGER.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/*
Skill-Einstieg fuer den kanonischen Abstractions Manager.
*/

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

const KANONISCHER_MANAGER = "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"

func main() {
	// Prüfe ob die Datei existiert
	if _, err := os.Stat(KANONISCHER_MANAGER); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Kanonischer Abstractions Manager fehlt: %s\n", KANONISCHER_MANAGER)
		os.Exit(1)
	}

	// Führe das Python-Skript aus
	cmd := exec.Command("python3", KANONISCHER_MANAGER)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	// Wechsle in das Verzeichnis des Skripts für konsistente Pfade
	dir := filepath.Dir(KANONISCHER_MANAGER)
	if dir != "" {
		cmd.Dir = dir
	}
	
	err := cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Fehler beim Ausführen des Skripts: %v\n", err)
		os.Exit(1)
	}
}
