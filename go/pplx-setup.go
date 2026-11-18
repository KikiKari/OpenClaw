// abstraction-provenance: {"artifact_sha256": "277ad491afacf9c2fc0496a1fb83f55c70c7fdcce9c9ef0fb25ca3b909c27cf9", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "go"}
// pplx-setup.sh — portiert nach go
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// One-time (idempotent): make sure the Perplexity VS Code extension daemon can
// find a Chromium. The daemon uses its OWN bundled patchright, which pins a
// specific chromium revision; install exactly that revision.
func main() {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "[setup] could not determine home directory\n")
		os.Exit(1)
	}

	// Find the latest patchright directory
	extPattern := filepath.Join(homeDir, ".vscode-remote", "extensions", "nskha.perplexity-vscode-*", "dist", "node_modules", "patchright")
	matches, err := filepath.Glob(extPattern)
	if err != nil {
		matches = []string{}
	}

	// Sort by version (similar to sort -V)
	sort.Slice(matches, func(i, j int) bool {
		return matches[i] < matches[j]
	})

	var extpr string
	if len(matches) > 0 {
		extpr = matches[len(matches)-1]
	}

	if extpr == "" {
		fmt.Println("[setup] extension patchright not found — is the Perplexity extension installed?")
		os.Exit(0)
	}

	// Get expected path
	exp := ""
	nodePath := filepath.Join(extpr, "index.js")
	cmd := exec.Command("node", "-e", fmt.Sprintf("const {chromium}=require('%s');console.log(chromium.executablePath())", nodePath))
	output, err := cmd.Output()
	if err == nil {
		exp = strings.TrimSpace(string(output))
		// Check if executable exists and is executable
		if stat, err := os.Stat(exp); err == nil && (stat.Mode()&0111) != 0 {
			fmt.Printf("[setup] daemon browser already present: %s\n", exp)
			os.Exit(0)
		}
	}

	fmt.Printf("[setup] installing matching chromium for the extension daemon (expected: %s)...\n", func() string {
		if exp == "" {
			return "unknown"
		}
		return exp
	}())
	
	// Install chromium
	cliPath := filepath.Join(extpr, "cli.js")
	installCmd := exec.Command("node", cliPath, "install", "chromium")
	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr
	
	if err := installCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "[setup] failed to install chromium\n")
		os.Exit(1)
	}
	
	fmt.Println("[setup] done.")
}
