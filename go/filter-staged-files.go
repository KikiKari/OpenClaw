// abstraction-provenance: {"artifact_sha256": "2f28ec538e0ccb12d806e660cc44104e7da9ef0e1ec6f941a3a2f4f573e2400c", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "go"}
// filter-staged-files.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

/*
 * Prints selected files as NUL-delimited tokens to stdout.
 *
 * Usage:
 *   go run filter-staged-files.go lint -- <files...>
 *   go run filter-staged-files.go format -- <files...>
 *
 * Keep this dependency-free: the pre-commit hook runs in many environments.
 */

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "usage: filter-staged-files.go <lint|format> -- <files...>\n")
		os.Exit(2)
	}

	mode := os.Args[1]
	rawArgs := os.Args[2:]
	
	var files []string
	if len(rawArgs) > 0 && rawArgs[0] == "--" {
		files = rawArgs[1:]
	} else {
		files = rawArgs
	}

	if mode != "lint" && mode != "format" {
		fmt.Fprintf(os.Stderr, "usage: filter-staged-files.go <lint|format> -- <files...>\n")
		os.Exit(2)
	}

	lintExts := map[string]bool{
		".ts": true, ".tsx": true, ".js": true, 
		".jsx": true, ".mjs": true, ".cjs": true,
	}
	
	formatExts := map[string]bool{
		".ts": true, ".tsx": true, ".js": true, 
		".jsx": true, ".mjs": true, ".cjs": true,
		".json": true, ".md": true, ".mdx": true,
	}
	
	formatIgnoredPaths := map[string]bool{
		"src/canvas-host/a2ui/a2ui.bundle.js": true,
	}

	shouldSelect := func(filePath string) bool {
		ext := strings.ToLower(filepath.Ext(filePath))
		if mode == "lint" {
			return lintExts[ext]
		}
		if formatIgnoredPaths[filePath] {
			return false
		}
		return formatExts[ext]
	}

	for _, file := range files {
		if shouldSelect(file) {
			fmt.Print(file)
			fmt.Print("\x00")
		}
	}
}
