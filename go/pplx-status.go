// abstraction-provenance: {"artifact_sha256": "897b6b7c5f64023e4a084bb68675f1d64acf16c170c2cd23a1c835f8823bf11d", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "go"}
// pplx-status.sh — portiert nach go
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Quick status of the codespace Perplexity daemon session.
func main() {
	cfg := os.Getenv("PERPLEXITY_CONFIG_DIR")
	if cfg == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error getting home directory: %v\n", err)
			os.Exit(1)
		}
		cfg = filepath.Join(home, ".perplexity-mcp")
	}

	profile := os.Getenv("PERPLEXITY_PROFILE")
	if profile == "" {
		profile = "codespace"
	}

	stat := filepath.Join(cfg, "profiles", profile, "daemon-status.json")

	if _, err := os.Stat(stat); err == nil {
		file, err := os.Open(stat)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error opening %s: %v\n", stat, err)
			os.Exit(1)
		}
		defer file.Close()

		content, err := io.ReadAll(file)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading %s: %v\n", stat, err)
			os.Exit(1)
		}

		var data interface{}
		if err := json.Unmarshal(content, &data); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing JSON from %s: %v\n", stat, err)
			os.Exit(1)
		}

		pretty, err := json.MarshalIndent(data, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error formatting JSON: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(string(pretty))
	} else {
		fmt.Printf("no daemon-status.json at %s\n", stat)
	}

	fmt.Println("--- recent auth lines ---")

	logFile := filepath.Join(cfg, "daemon.log")
	file, err := os.Open(logFile)
	if err != nil {
		return
	}
	defer file.Close()

	content, err := io.ReadAll(file)
	if err != nil {
		return
	}

	lines := strings.Split(string(content), "\n")
	matches := []string{}

	for _, line := range lines {
		lowerLine := strings.ToLower(line)
		if strings.Contains(lowerLine, "authenticated as user") ||
			strings.Contains(lowerLine, "account tier") ||
			strings.Contains(lowerLine, "injected") && strings.Contains(lowerLine, "cookies") ||
			strings.Contains(lowerLine, "reinit requested") ||
			strings.Contains(lowerLine, "not-logged-in") {
			matches = append(matches, line)
		}
	}

	start := len(matches) - 6
	if start < 0 {
		start = 0
	}

	for i := start; i < len(matches); i++ {
		fmt.Println(matches[i])
	}
}
