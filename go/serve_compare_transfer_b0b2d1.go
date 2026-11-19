// abstraction-provenance: {"artifact_sha256": "d9dec7f1558afa58998a4699ae4f8e464934043ad866a4a4163b6233a0126805", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "go"}
// serve_compare_transfer.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	COMPARE_DIR  = "/home/openclaw/.openclaw/workspace/vscode/compare"
	TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
	HOST_IP      = "89.58.15.220"
	PORT         = "80"
)

func main() {
	// Get current executable path to exclude it from the file list
	selfPath, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	selfPath, err = filepath.EvalSymlinks(selfPath)
	if err != nil {
		log.Fatal(err)
	}

	// Find all files in COMPARE_DIR (not subdirectories) excluding self
	var files []string
	err = filepath.WalkDir(COMPARE_DIR, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if path == COMPARE_DIR {
				return nil // Continue into directory
			}
			return filepath.SkipDir // Don't recurse into subdirectories
		}
		if path == selfPath {
			return nil // Skip self
		}
		rel, err := filepath.Rel(COMPARE_DIR, path)
		if err != nil {
			return err
		}
		if strings.Contains(rel, string(filepath.Separator)) {
			return nil // Skip files in subdirectories
		}
		files = append(files, path)
		return nil
	})
	if err != nil {
		log.Fatal(err)
	}

	// Sort files
	sort.Strings(files)

	if len(files) == 0 {
		fmt.Printf("Keine Dateien in %s gefunden.\n", COMPARE_DIR)
		os.Exit(1)
	}

	fmt.Println()
	fmt.Printf("Bereitgestellte Dateien aus %s:\n", COMPARE_DIR)
	for _, src := range files {
		fmt.Printf("- %s\n", filepath.Base(src))
	}

	fmt.Println()
	fmt.Printf("Copy/Paste auf anderem Gateway (Download nach %s):\n", TRANSFER_DIR)
	for _, src := range files {
		file := filepath.Base(src)
		fmt.Printf("curl -fL --retry 3 --connect-timeout 10 -o %s/%s http://%s:%s/%s\n", TRANSFER_DIR, file, HOST_IP, PORT, file)
	}

	fmt.Println()
	fmt.Printf("Server auf Port %s aktiv. Beenden mit STRG+C.\n", PORT)
	fmt.Println()

	// Change to COMPARE_DIR and start HTTP server
	err = os.Chdir(COMPARE_DIR)
	if err != nil {
		log.Fatal(err)
	}

	http.Handle("/", http.FileServer(http.Dir(".")))
	log.Fatal(http.ListenAndServe("0.0.0.0:"+PORT, nil))
}
