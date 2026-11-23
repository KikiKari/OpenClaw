// abstraction-provenance: {"artifact_sha256": "c7c025b66e9bfb8d6c77768dcc5de74eb930f987251c0e99e8f840648f78412b", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "go"}
// source-file-scan-cache.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

type Params struct {
	RepoRoot        string
	ScanRoots       []string
	ScanExtensions  map[string]bool
	IgnoredDirNames map[string]bool
}

type FileContent struct {
	FilePath     string
	RelativeFile string
	Content      string
}

var scanCache = make(map[string][]FileContent)
var cacheMutex sync.RWMutex

func normalizeRepoPath(repoRoot, filePath string) string {
	relPath, err := filepath.Rel(repoRoot, filePath)
	if err != nil {
		return filePath
	}
	return strings.ReplaceAll(relPath, string(filepath.Separator), "/")
}

func walkFiles(params Params, rootDir string) ([]string, error) {
	var out []string
	entries, err := os.ReadDir(rootDir)
	if err != nil {
		if os.IsNotExist(err) {
			return out, nil
		}
		return nil, err
	}

	// Sort entries by name
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		entryPath := filepath.Join(rootDir, entry.Name())
		if entry.IsDir() {
			if !params.IgnoredDirNames[entry.Name()] {
				subFiles, err := walkFiles(params, entryPath)
				if err != nil {
					return nil, err
				}
				out = append(out, subFiles...)
			}
			continue
		}
		if !entry.IsDir() {
			ext := filepath.Ext(entry.Name())
			if params.ScanExtensions[ext] {
				out = append(out, entryPath)
			}
		}
	}
	return out, nil
}

func collectSourceFileContents(params Params) ([]FileContent, error) {
	// Create cache key
	scanExts := make([]string, 0, len(params.ScanExtensions))
	for ext := range params.ScanExtensions {
		scanExts = append(scanExts, ext)
	}
	sort.Strings(scanExts)

	ignoredDirs := make([]string, 0, len(params.IgnoredDirNames))
	for dir := range params.IgnoredDirNames {
		ignoredDirs = append(ignoredDirs, dir)
	}
	sort.Strings(ignoredDirs)

	cacheKeyData := struct {
		RepoRoot        string
		ScanRoots       []string
		ScanExtensions  []string
		IgnoredDirNames []string
	}{
		RepoRoot:        params.RepoRoot,
		ScanRoots:       params.ScanRoots,
		ScanExtensions:  scanExts,
		IgnoredDirNames: ignoredDirs,
	}

	cacheKeyBytes, err := json.Marshal(cacheKeyData)
	if err != nil {
		return nil, err
	}
	cacheKey := string(cacheKeyBytes)

	// Check cache
	cacheMutex.RLock()
	cached, exists := scanCache[cacheKey]
	cacheMutex.RUnlock()

	if exists {
		return cached, nil
	}

	// Compute result
	var allFiles []string
	for _, root := range params.ScanRoots {
		fullPath := filepath.Join(params.RepoRoot, root)
		files, err := walkFiles(params, fullPath)
		if err != nil {
			return nil, err
		}
		allFiles = append(allFiles, files...)
	}

	// Sort files by relative path
	sort.Slice(allFiles, func(i, j int) bool {
		return normalizeRepoPath(params.RepoRoot, allFiles[i]) < normalizeRepoPath(params.RepoRoot, allFiles[j])
	})

	// Read file contents
	result := make([]FileContent, len(allFiles))
	for i, filePath := range allFiles {
		content, err := os.ReadFile(filePath)
		if err != nil {
			return nil, err
		}
		result[i] = FileContent{
			FilePath:     filePath,
			RelativeFile: normalizeRepoPath(params.RepoRoot, filePath),
			Content:      string(content),
		}
	}

	// Store in cache
	cacheMutex.Lock()
	scanCache[cacheKey] = result
	cacheMutex.Unlock()

	return result, nil
}

func main() {
	// Example usage
	params := Params{
		RepoRoot:  ".",
		ScanRoots: []string{"."},
		ScanExtensions: map[string]bool{
			".go":   true,
			".txt":  true,
			".json": true,
		},
		IgnoredDirNames: map[string]bool{
			"node_modules": true,
			".git":         true,
		},
	}

	files, err := collectSourceFileContents(params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	for _, file := range files {
		fmt.Printf("File: %s\n", file.RelativeFile)
		fmt.Printf("Content length: %d\n", len(file.Content))
		fmt.Println("---")
	}
}
