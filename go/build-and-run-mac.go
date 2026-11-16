// abstraction-provenance: {"artifact_sha256": "438d243ecdedfba0dbfc7727cde501f8f4fed109665751aaddf22606b197479b", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "go"}
// build-and-run-mac.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	// Get the directory of the current script and navigate to the target directory
	scriptDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		panic(err)
	}
	targetDir := filepath.Join(scriptDir, "..", "apps", "macos")
	
	if err := os.Chdir(targetDir); err != nil {
		panic(err)
	}

	BUILD_PATH := ".build-local"
	PRODUCT := "OpenClaw"
	BIN := filepath.Join(BUILD_PATH, "debug", PRODUCT)

	fmt.Printf("\n▶️  Building %s (debug, build path: %s)\n", PRODUCT, BUILD_PATH)
	
	// Build the product
	buildCmd := exec.Command("swift", "build", "-c", "debug", "--product", PRODUCT, "--build-path", BUILD_PATH)
	if output, err := buildCmd.CombinedOutput(); err != nil {
		fmt.Printf("Build failed: %s\n%s", err, string(output))
		os.Exit(1)
	}

	fmt.Printf("\n⏹  Stopping existing %s...\n", PRODUCT)
	
	// Kill any existing instances
	killCmd := exec.Command("killall", "-q", PRODUCT)
	_ = killCmd.Run() // Ignore errors as the process might not be running

	fmt.Printf("\n🚀 Launching %s ...\n", BIN)
	
	// Start the application in background
	appCmd := exec.Command(BIN)
	
	// Redirect output to log file
	logFile, err := os.Create("/tmp/openclaw.log")
	if err != nil {
		panic(err)
	}
	defer logFile.Close()
	
	appCmd.Stdout = logFile
	appCmd.Stderr = logFile
	
	if err := appCmd.Start(); err != nil {
		panic(err)
	}
	
	pid := appCmd.Process.Pid
	fmt.Printf("Started %s (PID %d). Logs: /tmp/openclaw.log\n", PRODUCT, pid)
}
