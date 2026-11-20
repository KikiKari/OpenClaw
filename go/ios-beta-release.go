// abstraction-provenance: {"artifact_sha256": "a351eb522b25d5ff6552056860f311c28b555b19ba64df6e22fa9d750715a5cb", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "go"}
// ios-beta-release.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// usage prints the help message
func usage() {
	fmt.Printf(`Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
`)
}

func main() {
	var buildNumber string
	
	// Define flags
	flag.StringVar(&buildNumber, "build-number", "", "")
	help := flag.Bool("h", false, "")
	helpLong := flag.Bool("help", false, "")
	
	// Custom usage function
	flag.Usage = usage
	
	// Parse flags
	flag.Parse()
	
	if *help || *helpLong {
		usage()
		os.Exit(0)
	}
	
	// Get root directory (equivalent to the bash script's method)
	executable, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting executable path: %v\n", err)
		os.Exit(1)
	}
	
	scriptDir := filepath.Dir(executable)
	rootDir := filepath.Join(scriptDir, "..")
	
	// Change to iOS directory
	iosDir := filepath.Join(rootDir, "apps", "ios")
	if err := os.Chdir(iosDir); err != nil {
		fmt.Fprintf(os.Stderr, "Error changing to iOS directory: %v\n", err)
		os.Exit(1)
	}
	
	// Set environment variable and run fastlane command
	cmd := exec.Command("fastlane", "ios", "beta")
	
	// Handle build number from environment variable if not provided via flag
	envBuildNumber := os.Getenv("IOS_BETA_BUILD_NUMBER")
	if buildNumber == "" && envBuildNumber != "" {
		buildNumber = envBuildNumber
	}
	
	// Set environment variables for the command
	env := os.Environ()
	if buildNumber != "" {
		env = append(env, fmt.Sprintf("IOS_BETA_BUILD_NUMBER=%s", buildNumber))
	}
	cmd.Env = env
	
	// Connect command to stdout/stderr
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	// Run the command
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error running fastlane: %v\n", err)
		os.Exit(1)
	}
}
