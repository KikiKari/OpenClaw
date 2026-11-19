// abstraction-provenance: {"artifact_sha256": "78a17bdb05f426fd7ac70df6fca760a18af98c03bc20e62507f41c292c205a5e", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "go"}
// serve_compare_transfer.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
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
	HOST_IP      = "152.53.145.65"
	PORT         = "80"
)

func main() {
	// Get the absolute path of this script to exclude it from the file list
	selfPath, err := os.Executable()
	if err != nil {
		log.Fatal("Cannot determine self path:", err)
	}

	// Find all files in COMPARE_DIR excluding directories and self
	var files []string
	err = filepath.WalkDir(COMPARE_DIR, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		// Only process files directly in COMPARE_DIR (not subdirectories)
		if d.IsDir() && path != COMPARE_DIR {
			return filepath.SkipDir
		}
		// Skip directories and self
		if !d.IsDir() && path != selfPath {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		log.Fatal("Error walking directory:", err)
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
		log.Fatal("Cannot change directory:", err)
	}

	// Start HTTP server
	http.Handle("/", http.FileServer(http.Dir(".")))
	log.Fatal(http.ListenAndServe("0.0.0.0:"+PORT, nil))
}
