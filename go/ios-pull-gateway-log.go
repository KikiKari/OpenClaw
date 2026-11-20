// abstraction-provenance: {"artifact_sha256": "8bbfa765a113ee8510bbeea9febb9d1beca8dfc1954ef98c7fb82d333e3645a2", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "go"}
// ios-pull-gateway-log.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	deviceUDID := getEnvOrDefault("1", "00008130-000630CE0146001C")
	bundleID := getEnvOrDefault("2", "ai.openclaw.ios.dev.mariano.test")
	dest := getEnvOrDefault("3", "/tmp/openclaw-gateway.log")

	cmd := exec.Command("xcrun", "devicectl", "device", "copy", "from",
		"--device", deviceUDID,
		"--domain-type", "appDataContainer",
		"--domain-identifier", bundleID,
		"--source", "Documents/openclaw-gateway.log",
		"--destination", dest)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Command failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Pulled to: %s\n", dest)

	// Display last 200 lines of the file
	displayTail(dest, 200)
}

func getEnvOrDefault(argIndex string, defaultValue string) string {
	if len(os.Args) > 1 && argIndex == "1" {
		return os.Args[1]
	}
	if len(os.Args) > 2 && argIndex == "2" {
		return os.Args[2]
	}
	if len(os.Args) > 3 && argIndex == "3" {
		return os.Args[3]
	}
	return defaultValue
}

func displayTail(filename string, lines int) {
	file, err := os.Open(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not open file: %v\n", err)
		return
	}
	defer file.Close()

	// Get file info for size
	stat, err := file.Stat()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not get file stats: %v\n", err)
		return
	}

	fileSize := stat.Size()
	bufferSize := int64(1024)
	var buffer []byte
	var outputLines []string
	lineEnding := byte('\n')

	// Read file from end backwards to find last N lines
	pos := fileSize
	for len(outputLines) < lines && pos > 0 {
		// Determine how much to read
		readSize := bufferSize
		if pos < bufferSize {
			readSize = pos
		}
		
		// Create buffer and read
		buffer = make([]byte, readSize)
		pos -= readSize
		
		_, err := file.ReadAt(buffer, pos)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
			return
		}
		
		// Process buffer backwards
		for i := len(buffer) - 1; i >= 0; i-- {
			if buffer[i] == lineEnding {
				if len(outputLines) >= lines {
					break
				}
			}
		}
	}
	
	// Simpler approach: just read and split lines
	content, err := os.ReadFile(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Could not read file: %v\n", err)
		return
	}
	
	allLines := []string{}
	currentLine := ""
	
	// Split into lines manually to handle all line endings
	for _, b := range content {
		if b == '\n' {
			allLines = append(allLines, currentLine)
			currentLine = ""
		} else if b != '\r' {
			currentLine += string(b)
		}
	}
	// Add last line if it doesn't end with newline
	if currentLine != "" {
		allLines = append(allLines, currentLine)
	}
	
	// Print last 'lines' lines
	startIdx := len(allLines) - lines
	if startIdx < 0 {
		startIdx = 0
	}
	
	for i := startIdx; i < len(allLines); i++ {
		fmt.Println(allLines[i])
	}
}
