// abstraction-provenance: {"artifact_sha256": "786a771b320256a53ca0a4f8918abb9f50d0d8f1b708e625f66e5ace7dfb34dc", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "go"}
// bundle-a2ui.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Bestimme das Stammverzeichnis analog zu "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	executable, err := os.Executable()
	if err != nil {
		panic(err)
	}
	
	dir := filepath.Dir(executable)
	rootDir := filepath.Join(dir, "..")
	
	// Pfade zur Node.js-Datei
	scriptPath := filepath.Join(rootDir, "scripts", "bundle-a2ui.mjs")
	
	// Führe das Node.js-Skript mit denselben Argumenten aus
	cmd := exec.Command("node", append([]string{scriptPath}, os.Args[1:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	err = cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			// Beende mit demselben Exit-Code wie das Node.js-Skript
			os.Exit(exitError.ExitCode())
		} else {
			fmt.Fprintf(os.Stderr, "Fehler beim Ausführen des Skripts: %v\n", err)
			os.Exit(1)
		}
	}
}
