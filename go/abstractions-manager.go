// abstraction-provenance: {"artifact_sha256": "1d2cd737547c607e7b1696e11f34b1dd4b7ba3c35f374aa56ff613008a6b85f0", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "go"}
// abstractions-manager.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"os"
	"os/exec"
	"syscall"
)

func main() {
	// Execute the cron script with the same arguments
	scriptPath := "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh"
	
	// Prepare the command with all arguments
	args := append([]string{scriptPath}, os.Args[1:]...)
	
	// Execute the script and replace current process
	err := syscall.Exec(scriptPath, args, os.Environ())
	if err != nil {
		// If exec fails, try running it through shell
		cmd := exec.Command(scriptPath, os.Args[1:]...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		
		// Exit with the same code as the subprocess
		if err := cmd.Run(); err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				os.Exit(exitError.ExitCode())
			}
			os.Exit(1)
		}
	}
}
