// abstraction-provenance: {"artifact_sha256": "068f6ff6f80f25a81b61d0259aec270453b0f0dea64869d84c5c718a57dc69ec", "source_sha256": "f0a06da41ce49899ff38006fbb000208dc616b2b3aa7114e02d1872712549a43", "target_language": "go"}
// run_sync_agent.py — portiert nach go
// Quelle: python, gateway-workspace
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
)

const (
	SRC = "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py"
)

func main() {
	// Read the Python script
	content, err := ioutil.ReadFile(SRC)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file %s: %v\n", SRC, err)
		os.Exit(1)
	}

	// Replace paths
	code := strings.ReplaceAll(string(content), "/home/openclaw/.openclaw/workspace", "/workspace")

	// Create temporary file for modified script
	tmpFile, err := ioutil.TempFile("", "sync_agent_*.py")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating temp file: %v\n", err)
		os.Exit(1)
	}
	defer os.Remove(tmpFile.Name())

	// Write modified code to temp file
	if _, err := tmpFile.Write([]byte(code)); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to temp file: %v\n", err)
		os.Exit(1)
	}
	tmpFile.Close()

	// Prepare arguments: python script path + original args
	args := append([]string{tmpFile.Name()}, os.Args[1:]...)

	// Execute python script with arguments
	cmd := exec.Command("python3", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			fmt.Fprintf(os.Stderr, "Error executing script: %v\n", err)
			os.Exit(1)
		}
	}
}
