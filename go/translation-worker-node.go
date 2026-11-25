// abstraction-provenance: {"artifact_sha256": "3b59de35ba2ad6e9bcf01a847fd9ccce277c96356a8cbd4ba8504ed375b1b5ce", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "go"}
// translation-worker-node.sh — portiert nach go
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"os/exec"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "Usage: translation-worker-node.go node2|node3|node4|node6 prepare|health|run")
		os.Exit(2)
	}

	node := os.Args[1]
	action := os.Args[2]

	var worker string
	var expected string

	switch node {
	case "node2":
		worker = "/home/node/.openclaw/workers/translation-worker"
		expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
	case "node3":
		worker = "/home/openclaw/.openclaw/workers/translation-worker"
		expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
	case "node4":
		worker = "/root/.openclaw/workers/translation-worker"
		expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
	case "node6":
		worker = "/home/node/.openclaw/workers/translation-worker"
		expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
	default:
		fmt.Fprintln(os.Stderr, "Unknown or non-POSIX node")
		os.Exit(2)
	}

	switch action {
	case "prepare", "health", "run":
		// valid actions
	default:
		fmt.Fprintln(os.Stderr, "Unknown action")
		os.Exit(2)
	}

	// Check if file exists and is not a symlink
	info, err := os.Lstat(worker)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Missing worker or symlink rejected: %s\n", worker)
		os.Exit(1)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		fmt.Fprintf(os.Stderr, "Missing worker or symlink rejected: %s\n", worker)
		os.Exit(1)
	}

	// Calculate SHA256 checksum
	file, err := os.Open(worker)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Worker checksum calculation failed: %s\n", worker)
		os.Exit(1)
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		fmt.Fprintf(os.Stderr, "Worker checksum calculation failed: %s\n", worker)
		os.Exit(1)
	}
	actual := fmt.Sprintf("%x", hash.Sum(nil))

	if actual != expected {
		fmt.Fprintf(os.Stderr, "Worker checksum mismatch: %s\n", worker)
		os.Exit(1)
	}

	// Make executable
	if err := os.Chmod(worker, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to make worker executable: %s\n", worker)
		os.Exit(1)
	}

	switch action {
	case "prepare":
		fmt.Printf("Worker verified and executable: %s\n", worker)
	case "health":
		cmd := exec.Command(worker, "--health")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				os.Exit(exitError.ExitCode())
			}
			os.Exit(1)
		}
	case "run":
		cmd := exec.Command(worker)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				os.Exit(exitError.ExitCode())
			}
			os.Exit(1)
		}
	}
}
