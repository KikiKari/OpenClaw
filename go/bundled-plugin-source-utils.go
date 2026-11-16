// abstraction-provenance: {"artifact_sha256": "fa27f65384c295aa789ca1148e7647013839c3f742b92262da6d826def067e8c", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "go"}
// bundled-plugin-source-utils.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

// readIfExists reads a file and returns its content as string.
// Returns nil if the file does not exist or cannot be read.
func readIfExists(filePath string) ([]byte, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	return content, nil
}

// BundledPluginEntry represents a bundled plugin entry
type BundledPluginEntry struct {
	DirName         string                 `json:"dirName"`
	PluginDir       string                 `json:"pluginDir"`
	ManifestPath    string                 `json:"manifestPath"`
	Manifest        map[string]interface{} `json:"manifest"`
	PackageJsonPath string                 `json:"packageJsonPath,omitempty"`
	PackageJson     map[string]interface{} `json:"packageJson,omitempty"`
}

// CollectBundledPluginSourcesParams are the parameters for collecting bundled plugin sources
type CollectBundledPluginSourcesParams struct {
	RepoRoot           string `json:"repoRoot"`
	RequirePackageJson bool   `json:"requirePackageJson"`
}

// collectBundledPluginSources collects information about bundled plugins
func collectBundledPluginSources(params *CollectBundledPluginSourcesParams) ([]BundledPluginEntry, error) {
	repoRoot := params.RepoRoot
	if repoRoot == "" {
		cwd, err := os.Getwd()
		if err != nil {
			return nil, err
		}
		repoRoot = cwd
	}

	extensionsRoot := filepath.Join(repoRoot, "extensions")
	if _, err := os.Stat(extensionsRoot); os.IsNotExist(err) {
		return []BundledPluginEntry{}, nil
	}

	entries := make([]BundledPluginEntry, 0)
	
	// Read directory entries
	dirEntries, err := os.ReadDir(extensionsRoot)
	if err != nil {
		return nil, err
	}

	for _, dirent := range dirEntries {
		if !dirent.IsDir() {
			continue
		}

		pluginDir := filepath.Join(extensionsRoot, dirent.Name())
		manifestPath := filepath.Join(pluginDir, "openclaw.plugin.json")
		packageJsonPath := filepath.Join(pluginDir, "package.json")

		// Check if manifest exists
		if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
			continue
		}

		// Check if package.json is required and exists
		if params.RequirePackageJson {
			if _, err := os.Stat(packageJsonPath); os.IsNotExist(err) {
				continue
			}
		}

		entry := BundledPluginEntry{
			DirName:      dirent.Name(),
			PluginDir:    pluginDir,
			ManifestPath: manifestPath,
		}

		// Read manifest
		manifestContent, err := readIfExists(manifestPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read manifest %s: %v", manifestPath, err)
		}
		
		if err := json.Unmarshal(manifestContent, &entry.Manifest); err != nil {
			return nil, fmt.Errorf("failed to parse manifest %s: %v", manifestPath, err)
		}

		// Read package.json if it exists
		if _, err := os.Stat(packageJsonPath); err == nil {
			packageJsonContent, err := readIfExists(packageJsonPath)
			if err != nil {
				return nil, fmt.Errorf("failed to read package.json %s: %v", packageJsonPath, err)
			}
			
			if err := json.Unmarshal(packageJsonContent, &entry.PackageJson); err != nil {
				return nil, fmt.Errorf("failed to parse package.json %s: %v", packageJsonPath, err)
			}
			entry.PackageJsonPath = packageJsonPath
		} else if !os.IsNotExist(err) {
			return nil, fmt.Errorf("error checking package.json %s: %v", packageJsonPath, err)
		}

		entries = append(entries, entry)
	}

	// Sort entries by directory name
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].DirName < entries[j].DirName
	})

	return entries, nil
}
