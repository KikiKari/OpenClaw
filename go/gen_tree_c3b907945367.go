// abstraction-provenance: {"artifact_sha256": "554fcdf57fcdef880c1a4c3d9ef6b32bbc5dedd9ef728fdc6410e7cef0f5d4ac", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "go"}
// gen_tree.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

// Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
// (used because the `tree` binary is unavailable in this sandbox).

package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	ROOT     = "/workspace"
	OUT      = "/workspace/important/openclaw-tree.txt"
	MAX_DEPTH = 6
)

func collect(path string, prefix string, depth int) []string {
	var lines []string
	
	entries, err := os.ReadDir(path)
	if err != nil {
		return lines
	}
	
	// Sort entries
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})
	
	total := len(entries)
	for i, entry := range entries {
		isLast := (i == total - 1)
		var connector string
		if isLast {
			connector = "└── "
		} else {
			connector = "├── "
		}
		
		lines = append(lines, prefix+connector+entry.Name())
		
		if depth < MAX_DEPTH && entry.IsDir() {
			var nextPrefix string
			if isLast {
				nextPrefix = prefix + "    "
			} else {
				nextPrefix = prefix + "│   "
			}
			
			fullPath := filepath.Join(path, entry.Name())
			subLines := collect(fullPath, nextPrefix, depth+1)
			lines = append(lines, subLines...)
		}
	}
	
	return lines
}

func main() {
	body := collect(ROOT, "", 1)
	
	now := time.Now().Format(time.RFC3339)
	header := fmt.Sprintf(
		"# OpenClaw Workspace Tree\n"+
		"# Generiert: %s\n"+
		"# Befehl: tree -a -L 6 %s (emuliert via gen_tree.go)\n"+
		"# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n",
		now, ROOT)
	
	content := header + ".\n" + strings.Join(body, "\n") + "\n"
	
	err := os.WriteFile(OUT, []byte(content), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}
	
	lineCount := len(body) + 1
	byteCount := len(content)
	fmt.Printf("written %s: %d lines, %d bytes\n", OUT, lineCount, byteCount)
}
