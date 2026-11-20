// abstraction-provenance: {"artifact_sha256": "bf9ded9c74c94bcf779f6b44f3be700563c2a8cf14bbbb75e9cd54fb5d489295", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "go"}
// ios-beta-archive.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func usage() {
	fmt.Fprintln(os.Stderr, `Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.`)
}

func main() {
	var buildNumber string
	var help bool

	flag.StringVar(&buildNumber, "build-number", "", "")
	flag.BoolVar(&help, "h", false, "")
	flag.BoolVar(&help, "help", false, "")
	flag.Usage = usage
	flag.Parse()

	if help {
		usage()
		os.Exit(0)
	}

	// Handle additional arguments that might be passed after --
	args := flag.Args()
	for len(args) > 0 && args[0] == "--" {
		args = args[1:]
	}

	if len(args) > 0 {
		fmt.Fprintf(os.Stderr, "Unknown argument: %s\n", args[0])
		usage()
		os.Exit(1)
	}

	// Get root directory (equivalent to the shell script's logic)
	executable, err := os.Executable()
	if err != nil {
		// Fallback to current working directory if we can't get executable path
		executable, _ = os.Getwd()
	}
	rootDir := filepath.Join(filepath.Dir(executable), "..")
	
	// Resolve to absolute path
	rootDir, err = filepath.Abs(rootDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving root directory: %v\n", err)
		os.Exit(1)
	}

	// Change to iOS app directory
	iosDir := filepath.Join(rootDir, "apps", "ios")
	if err := os.Chdir(iosDir); err != nil {
		fmt.Fprintf(os.Stderr, "Error changing to iOS directory: %v\n", err)
		os.Exit(1)
	}

	// Set environment variable for build number
	env := os.Environ()
	if buildNumber == "" {
		// Check if IOS_BETA_BUILD_NUMBER is set in environment
		if envBuildNumber := os.Getenv("IOS_BETA_BUILD_NUMBER"); envBuildNumber != "" {
			buildNumber = envBuildNumber
		}
	}

	// Add or replace IOS_BETA_BUILD_NUMBER in environment
	env = append(env, fmt.Sprintf("IOS_BETA_BUILD_NUMBER=%s", buildNumber))

	// Run fastlane command
	cmd := exec.Command("fastlane", "ios", "beta_archive")
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error running fastlane: %v\n", err)
		os.Exit(1)
	}
}
