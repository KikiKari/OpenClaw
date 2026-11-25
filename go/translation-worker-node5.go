// abstraction-provenance: {"artifact_sha256": "3a408a2a16aa8f2d145b4b34c7c8593eb42277b8fd06061ac85cb724067abdea", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "go"}
// translation-worker-node5.ps1 — portiert nach go
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "Usage: translation-worker-node5.go <prepare|run>")
		os.Exit(1)
	}

	action := os.Args[1]
	if action != "prepare" && action != "run" {
		fmt.Fprintln(os.Stderr, "Action must be either 'prepare' or 'run'")
		os.Exit(1)
	}

	// Windows does not use chmod. The Python worker and Python 3 must already be
	// installed locally; no credentials are copied or placed on a command line.
	userProfile := os.Getenv("USERPROFILE")
	if userProfile == "" {
		fmt.Fprintln(os.Stderr, "USERPROFILE environment variable not set")
		os.Exit(1)
	}

	worker := filepath.Join(userProfile, ".openclaw", "workers", "translation_worker.py")
	expected := "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b"

	// Check if worker file exists
	if _, err := os.Stat(worker); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Worker missing: %s\n", worker)
		os.Exit(1)
	}

	// Check if it's a symlink (reparse point equivalent)
	// In Go, we check if it's a symlink by checking the file info
	fileInfo, err := os.Lstat(worker)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error accessing worker file: %v\n", err)
		os.Exit(1)
	}

	if fileInfo.Mode()&os.ModeSymlink != 0 {
		fmt.Fprintln(os.Stderr, "Worker link rejected")
		os.Exit(1)
	}

	// Calculate SHA256 hash of the worker file
	hash, err := calculateSHA256(worker)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error calculating checksum: %v\n", err)
		os.Exit(1)
	}

	if strings.ToLower(hash) != expected {
		fmt.Fprintln(os.Stderr, "Worker checksum mismatch")
		os.Exit(1)
	}

	// Find python executable
	pythonPath, err := exec.LookPath("python.exe")
	if err != nil {
		pythonPath, err = exec.LookPath("python")
		if err != nil {
			pythonPath, err = exec.LookPath("python3")
			if err != nil {
				fmt.Fprintln(os.Stderr, "Python executable not found")
				os.Exit(1)
			}
		}
	}

	if action == "prepare" {
		fmt.Printf("Worker verified: %s\n", worker)
		os.Exit(0)
	}

	// Run the python worker
	cmd := exec.Command(pythonPath, worker)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		}
		os.Exit(1)
	}
}

func calculateSHA256(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}
