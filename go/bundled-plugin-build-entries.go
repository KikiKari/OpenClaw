// abstraction-provenance: {"artifact_sha256": "42a370aa89945dd65b7dddb5f86f30b45daca75ca0d230b952dade06d56add86", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "go"}
// bundled-plugin-build-entries.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var (
	TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = map[string]bool{
		".ts":  true, ".js": true, ".mts": true, ".cts": true, ".mjs": true, ".cjs": true,
	}
	NON_PACKAGED_BUNDLED_PLUGIN_DIRS = map[string]bool{
		"qa-channel": true, "qa-lab": true,
	}
	BUNDLED_PLUGIN_ROOT_DIR = "plugins"
)

type PackageJSON struct {
	Name        string `json:"name"`
	Openclaw    *struct {
		Extensions              []string          `json:"extensions,omitempty"`
		SetupEntry              string            `json:"setupEntry,omitempty"`
		Bundle                  *BundleConfig     `json:"bundle,omitempty"`
	} `json:"openclaw,omitempty"`
	Dependencies          map[string]string `json:"dependencies,omitempty"`
	OptionalDependencies  map[string]string `json:"optionalDependencies,omitempty"`
}

type BundleConfig struct {
	StageRuntimeDependencies bool `json:"stageRuntimeDependencies,omitempty"`
}

type BundledPluginBuildEntry struct {
	ID               string       `json:"id"`
	HasManifest      bool         `json:"hasManifest"`
	HasPackageJson   bool         `json:"hasPackageJson"`
	PackageJson      *PackageJSON `json:"packageJson"`
	SourceEntries    []string     `json:"sourceEntries"`
}

func toPosixPath(value string) string {
	return strings.ReplaceAll(value, "\\", "/")
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func readBundledPluginPackageJson(packageJsonPath string) (*PackageJSON, error) {
	if !fileExists(packageJsonPath) {
		return nil, nil
	}
	
	data, err := os.ReadFile(packageJsonPath)
	if err != nil {
		return nil, err
	}
	
	var pkg PackageJSON
	if err := json.Unmarshal(data, &pkg); err != nil {
		return nil, err
	}
	
	return &pkg, nil
}

func isManifestlessBundledRuntimeSupportPackage(dirName string, packageJson *PackageJSON, topLevelPublicSurfaceEntries []string) bool {
	packageName := ""
	if packageJson != nil && packageJson.Name != "" {
		packageName = packageJson.Name
	}
	if packageName != fmt.Sprintf("@openclaw/%s", dirName) {
		return false
	}
	return len(topLevelPublicSurfaceEntries) > 0
}

func collectPluginSourceEntries(packageJson *PackageJSON) []string {
	entries := []string{}
	
	if packageJson != nil && packageJson.Openclaw != nil {
		for _, entry := range packageJson.Openclaw.Extensions {
			if strings.TrimSpace(entry) != "" {
				entries = append(entries, entry)
			}
		}
		
		if strings.TrimSpace(packageJson.Openclaw.SetupEntry) != "" {
			entries = append(entries, packageJson.Openclaw.SetupEntry)
		}
	}
	
	if len(entries) > 0 {
		unique := make(map[string]bool)
		result := []string{}
		for _, entry := range entries {
			if !unique[entry] {
				unique[entry] = true
				result = append(result, entry)
			}
		}
		return result
	}
	
	return []string{"./index.ts"}
}

func shouldStageBundledPluginRuntimeDependencies(packageJson *PackageJSON) bool {
	return packageJson != nil && 
		   packageJson.Openclaw != nil && 
		   packageJson.Openclaw.Bundle != nil && 
		   packageJson.Openclaw.Bundle.StageRuntimeDependencies
}

func collectTopLevelPublicSurfaceEntries(pluginDir string) []string {
	if !fileExists(pluginDir) {
		return []string{}
	}
	
	entries := []string{}
	files, err := os.ReadDir(pluginDir)
	if err != nil {
		return []string{}
	}
	
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		
		name := file.Name()
		ext := filepath.Ext(name)
		
		if !TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS[ext] {
			continue
		}
		
		normalizedName := strings.ToLower(name)
		if strings.HasSuffix(normalizedName, ".d.ts") ||
		   (strings.HasPrefix(normalizedName, "config-api.") && 
		    (strings.HasSuffix(normalizedName, ".ts") || strings.HasSuffix(normalizedName, ".js"))) ||
		   strings.Contains(normalizedName, ".test.") ||
		   strings.Contains(normalizedName, ".spec.") ||
		   strings.Contains(normalizedName, ".fixture.") ||
		   strings.Contains(normalizedName, ".snap") {
			continue
		}
		
		entries = append(entries, fmt.Sprintf("./%s", name))
	}
	
	sort.Strings(entries)
	return entries
}

func collectBundledPluginBuildEntries(cwd string, env map[string]string) []BundledPluginBuildEntry {
	if cwd == "" {
		cwd, _ = os.Getwd()
	}
	if env == nil {
		env = make(map[string]string)
		for _, e := range os.Environ() {
			pair := strings.SplitN(e, "=", 2)
			if len(pair) == 2 {
				env[pair[0]] = pair[1]
			}
		}
	}
	
	extensionsRoot := filepath.Join(cwd, BUNDLED_PLUGIN_ROOT_DIR)
	entries := []BundledPluginBuildEntry{}
	
	files, err := os.ReadDir(extensionsRoot)
	if err != nil {
		return entries
	}
	
	for _, file := range files {
		if !file.IsDir() {
			continue
		}
		
		direntName := file.Name()
		pluginDir := filepath.Join(extensionsRoot, direntName)
		manifestPath := filepath.Join(pluginDir, "openclaw.plugin.json")
		hasManifest := fileExists(manifestPath)
		
		packageJsonPath := filepath.Join(pluginDir, "package.json")
		packageJson, _ := readBundledPluginPackageJson(packageJsonPath)
		topLevelPublicSurfaceEntries := collectTopLevelPublicSurfaceEntries(pluginDir)
		
		isManifestless := !hasManifest && isManifestlessBundledRuntimeSupportPackage(direntName, packageJson, topLevelPublicSurfaceEntries)
		
		if !hasManifest && !isManifestless {
			continue
		}
		
		if !shouldBuildBundledCluster(direntName, env, packageJson) {
			continue
		}
		
		sourceEntries := []string{}
		if hasManifest {
			sourceEntries = collectPluginSourceEntries(packageJson)
		}
		sourceEntries = append(sourceEntries, topLevelPublicSurfaceEntries...)
		
		uniqueEntries := make(map[string]bool)
		uniqueSourceEntries := []string{}
		for _, entry := range sourceEntries {
			if !uniqueEntries[entry] {
				uniqueEntries[entry] = true
				uniqueSourceEntries = append(uniqueSourceEntries, entry)
			}
		}
		
		entries = append(entries, BundledPluginBuildEntry{
			ID:              direntName,
			HasManifest:     hasManifest,
			HasPackageJson:  packageJson != nil,
			PackageJson:     packageJson,
			SourceEntries:   uniqueSourceEntries,
		})
	}
	
	return entries
}

func bundledPluginFile(id, base string) string {
	return fmt.Sprintf("%s/%s", id, base)
}

func bundledDistPluginFile(id, filename string) string {
	return fmt.Sprintf("dist/plugins/%s/%s", id, filename)
}

func listBundledPluginBuildEntries(cwd string, env map[string]string) map[string]string {
	entries := collectBundledPluginBuildEntries(cwd, env)
	result := make(map[string]string)
	
	for _, entry := range entries {
		for _, sourceEntry := range entry.SourceEntries {
			normalizedEntry := strings.TrimPrefix(sourceEntry, "./")
			baseName := strings.TrimSuffix(normalizedEntry, filepath.Ext(normalizedEntry))
			entryKey := bundledPluginFile(entry.ID, baseName)
			path := filepath.Join(BUNDLED_PLUGIN_ROOT_DIR, entry.ID, normalizedEntry)
			result[entryKey] = toPosixPath(path)
		}
	}
	
	return result
}

func listBundledPluginPackArtifacts(cwd string, env map[string]string) []string {
	allEntries := collectBundledPluginBuildEntries(cwd, env)
	filteredEntries := []BundledPluginBuildEntry{}
	
	for _, entry := range allEntries {
		if !NON_PACKAGED_BUNDLED_PLUGIN_DIRS[entry.ID] {
			filteredEntries = append(filteredEntries, entry)
		}
	}
	
	artifacts := make(map[string]bool)
	
	for _, entry := range filteredEntries {
		if entry.HasManifest {
			artifacts[bundledDistPluginFile(entry.ID, "openclaw.plugin.json")] = true
		}
		if entry.HasPackageJson {
			artifacts[bundledDistPluginFile(entry.ID, "package.json")] = true
		}
		for _, sourceEntry := range entry.SourceEntries {
			normalizedEntry := strings.TrimPrefix(sourceEntry, "./")
			baseName := strings.TrimSuffix(normalizedEntry, filepath.Ext(normalizedEntry))
			artifacts[bundledDistPluginFile(entry.ID, fmt.Sprintf("%s.js", baseName))] = true
		}
	}
	
	result := []string{}
	for artifact := range artifacts {
		result = append(result, artifact)
	}
	
	sort.Strings(result)
	return result
}

func listBundledPluginRuntimeDependencies(cwd string, env map[string]string) []string {
	entries := collectBundledPluginBuildEntries(cwd, env)
	runtimeDependencies := make(map[string]bool)
	
	for _, entry := range entries {
		if !shouldStageBundledPluginRuntimeDependencies(entry.PackageJson) {
			continue
		}
		
		if entry.PackageJson != nil {
			if entry.PackageJson.Dependencies != nil {
				for dep := range entry.PackageJson.Dependencies {
					runtimeDependencies[dep] = true
				}
			}
			if entry.PackageJson.OptionalDependencies != nil {
				for dep := range entry.PackageJson.OptionalDependencies {
					runtimeDependencies[dep] = true
				}
			}
		}
	}
	
	result := []string{}
	for dep := range runtimeDependencies {
		result = append(result, dep)
	}
	
	sort.Strings(result)
	return result
}

// Placeholder functions that would need to be implemented based on the imported modules
func shouldBuildBundledCluster(name string, env map[string]string, packageJson *PackageJSON) bool {
	// This would implement the logic from optional-bundled-clusters.mjs
	return true // placeholder
}

func main() {
	// Example usage
	fmt.Println("Bundled Plugin Build Entries Tool")
	
	// You can add command-line argument parsing here if needed
	// For now, this just demonstrates the structure
	
	cwd, _ := os.Getwd()
	env := make(map[string]string)
	for _, e := range os.Environ() {
		pair := strings.SplitN(e, "=", 2)
		if len(pair) == 2 {
			env[pair[0]] = pair[1]
		}
	}
	
	// Example calls
	entries := collectBundledPluginBuildEntries(cwd, env)
	fmt.Printf("Found %d build entries\n", len(entries))
	
	buildEntries := listBundledPluginBuildEntries(cwd, env)
	fmt.Printf("Build entries mapping: %+v\n", buildEntries)
	
	artifacts := listBundledPluginPackArtifacts(cwd, env)
	fmt.Printf("Pack artifacts: %+v\n", artifacts)
	
	dependencies := listBundledPluginRuntimeDependencies(cwd, env)
	fmt.Printf("Runtime dependencies: %+v\n", dependencies)
}
