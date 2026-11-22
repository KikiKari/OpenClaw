// abstraction-provenance: {"artifact_sha256": "aa3e2340f0ad6fa447e8a77bd24d83152057ef15f2a66072a7bda1832df75c92", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "go"}
// run.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	repoDir := "/repo"
	if err := os.Chdir(repoDir); err != nil {
		log.Fatalf("Failed to change directory to %s: %v", repoDir, err)
	}

	openClawStateDir := "/tmp/openclaw-test"
	openClawConfigPath := filepath.Join(openClawStateDir, "openclaw.json")

	os.Setenv("OPENCLAW_STATE_DIR", openClawStateDir)
	os.Setenv("OPENCLAW_CONFIG_PATH", openClawConfigPath)

	fmt.Println("==> Build")
	if err := runCommand("pnpm", "build"); err != nil {
		printAndExit("/tmp/openclaw-cleanup-build.log")
	}

	fmt.Println("==> Seed state")
	createDirs(
		filepath.Join(openClawStateDir, "credentials"),
		filepath.Join(openClawStateDir, "agents/main/sessions"),
	)
	writeFile(openClawConfigPath, "{}")
	writeFile(filepath.Join(openClawStateDir, "credentials", "marker.txt"), "creds")
	writeFile(filepath.Join(openClawStateDir, "agents/main/sessions", "sessions.json"), "session")

	fmt.Println("==> Reset (config+creds+sessions)")
	if err := runCommand("pnpm", "openclaw", "reset", "--scope", "config+creds+sessions", "--yes", "--non-interactive"); err != nil {
		printAndExit("/tmp/openclaw-cleanup-reset.log")
	}

	testFileNotExists(openClawConfigPath)
	testDirNotExists(filepath.Join(openClawStateDir, "credentials"))
	testDirNotExists(filepath.Join(openClawStateDir, "agents/main/sessions"))

	fmt.Println("==> Recreate minimal config")
	createDirs(filepath.Join(openClawStateDir, "credentials"))
	writeFile(openClawConfigPath, "{}")

	fmt.Println("==> Uninstall (state only)")
	if err := runCommand("pnpm", "openclaw", "uninstall", "--state", "--yes", "--non-interactive"); err != nil {
		printAndExit("/tmp/openclaw-cleanup-uninstall.log")
	}

	testDirNotExists(openClawStateDir)

	fmt.Println("OK")
}

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func printAndExit(logFile string) {
	content, err := ioutil.ReadFile(logFile)
	if err != nil {
		log.Printf("Failed to read log file %s: %v", logFile, err)
	} else {
		fmt.Print(string(content))
	}
	os.Exit(1)
}

func createDirs(dirs ...string) {
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			log.Fatalf("Failed to create directory %s: %v", dir, err)
		}
	}
}

func writeFile(path, content string) {
	if err := ioutil.WriteFile(path, []byte(content), 0644); err != nil {
		log.Fatalf("Failed to write file %s: %v", path, err)
	}
}

func testFileNotExists(path string) {
	if _, err := os.Stat(path); err == nil {
		log.Fatalf("File %s should not exist", path)
	}
}

func testDirNotExists(path string) {
	if _, err := os.Stat(path); err == nil {
		log.Fatalf("Directory %s should not exist", path)
	}
}
