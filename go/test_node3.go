// abstraction-provenance: {"artifact_sha256": "c6bde2a48f2b35cdd24b81a8c9142c69ea8455bdef4337433ae9cf4923f3105b", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "go"}
// test_node3.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"
)

// Test Node 3 Connection
func main() {
	// Set environment variable
	os.Setenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", "1")
	
	fmt.Println("Starting node connection test...")
	
	// Create context with timeout of 15 seconds
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	
	// Prepare the command
	cmd := exec.CommandContext(ctx, "/usr/local/bin/openclaw", "node", "run", "--host", "152.53.145.65", "--port", "18789")
	
	// Redirect stderr to stdout (equivalent to 2>&1)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stdout
	
	// Run the command and capture exit code
	err := cmd.Run()
	
	// Determine exit code
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			// Command exited with non-zero status
			if status, ok := exitError.Sys().(syscall.WaitStatus); ok {
				exitCode = status.ExitStatus()
			}
		} else {
			// Command failed to start or timed out
			exitCode = 1
		}
	}
	
	fmt.Printf("Exit code: %d\n", exitCode)
}
