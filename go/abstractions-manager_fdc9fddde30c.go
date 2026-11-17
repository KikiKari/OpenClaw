// abstraction-provenance: {"artifact_sha256": "383bdcd83457f89358aae37179a4035b408a93ab4f245eaeb2c861b6d204c1cf", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "go"}
// abstractions-manager.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"os"
	"os/exec"
	"syscall"
)

func main() {
	// Execute the cron script with all passed arguments
	cmd := exec.Command("/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh", os.Args[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	// Replace current process (exec behavior)
	if err := syscall.Exec(cmd.Path, cmd.Args, os.Environ()); err != nil {
		panic(err)
	}
}
