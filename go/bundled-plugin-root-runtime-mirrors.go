// abstraction-provenance: {"artifact_sha256": "9a3cc857762888181bcd4a0ecbf412591bbc60d40891c3f8e11075fc96beae7c", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "go"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var jsExtensions = map[string]bool{
	".cjs": true,
	".js":  true,
	".mjs": true,
}

type DependencyRecord struct {
	Conflicts []ConflictInfo `json:"conflicts"`
	PluginIds []string       `json:"pluginIds"`
	Spec      string         `json:"spec"`
}

type ConflictInfo struct {
	PluginId string `json:"pluginId"`
	Spec     string `json:"spec"`
}

type MirrorRecord struct {
	Importers []string `json:"importers"`
	PluginIds []string `json:"pluginIds"`
	Spec      string   `json:"spec"`
}

func readJson(filePath string) (map[string]interface{}, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	var result map[string]interface{}
	err = json.Unmarshal(data, &result)
	return result, err
}

func collectRuntimeDependencySpecs(packageJson map[string]interface{}) map[string]string {
	specs := make(map[string]string)
	
	dependencies := make(map[string]interface{})
	if deps, ok := packageJson["dependencies"].(map[string]interface{}); ok {
		for k, v := range deps {
			dependencies[k] = v
		}
	}
	if optDeps, ok := packageJson["optionalDependencies"].(map[string]interface{}); ok {
		for k, v := range optDeps {
			dependencies[k] = v
		}
	}
	
	for name, spec := range dependencies {
		if specStr, ok := spec.(string); ok && len(specStr) > 0 {
			specs[name] = specStr
		}
	}
	
	return specs
}

func packageNameFromSpecifier(specifier string) string {
	if strings.HasPrefix(specifier, ".") ||
		strings.HasPrefix(specifier, "/") ||
		strings.HasPrefix(specifier, "node:") ||
		strings.HasPrefix(specifier, "#") {
		return ""
	}
	parts := strings.Split(specifier, "/")
	if len(parts) == 0 {
		return ""
	}
	if strings.HasPrefix(parts[0], "@") && len(parts) > 1 {
		return parts[0] + "/" + parts[1]
	}
	return parts[0]
}

func collectPackageJsonPaths(rootDir string) []string {
	if _, err := os.Stat(rootDir); os.IsNotExist(err) {
		return []string{}
	}
	
	entries, err := os.ReadDir(rootDir)
	if err != nil {
		return []string{}
	}
	
	var paths []string
	for _, entry := range entries {
		if entry.IsDir() {
			packageJsonPath := filepath.Join(rootDir, entry.Name(), "package.json")
			if _, err := os.Stat(packageJsonPath); err == nil {
				paths = append(paths, packageJsonPath)
			}
		}
	}
	
	sort.Strings(paths)
	return paths
}

func collectBundledPluginRuntimeDependencySpecs(bundledPluginsDir string) map[string]*DependencyRecord {
	specs := make(map[string]*DependencyRecord)
	
	packageJsonPaths := collectPackageJsonPaths(bundledPluginsDir)
	
	for _, packageJsonPath := range packageJsonPaths {
		packageJson, err := readJson(packageJsonPath)
		if err != nil {
			continue
		}
		
		pluginId := filepath.Base(filepath.Dir(packageJsonPath))
		
		depSpecs := collectRuntimeDependencySpecs(packageJson)
		for name, spec := range depSpecs {
			existing, exists := specs[name]
			if exists {
				if existing.Spec != spec {
					existing.Conflicts = append(existing.Conflicts, ConflictInfo{
						PluginId: pluginId,
						Spec:     spec,
					})
				} else {
					found := false
					for _, id := range existing.PluginIds {
						if id == pluginId {
							found = true
							break
						}
					}
					if !found {
						existing.PluginIds = append(existing.PluginIds, pluginId)
					}
				}
				continue
			}
			
			specs[name] = &DependencyRecord{
				Conflicts: []ConflictInfo{},
				PluginIds: []string{pluginId},
				Spec:      spec,
			}
		}
	}
	
	return specs
}

func walkJavaScriptFiles(rootDir string) []string {
	var files []string
	if _, err := os.Stat(rootDir); os.IsNotExist(err) {
		return files
	}
	
	queue := []string{rootDir}
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		
		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}
		
		for _, entry := range entries {
			fullPath := filepath.Join(current, entry.Name())
			
			if entry.IsDir() {
				if strings.Contains(fullPath, "extensions") {
					continue
				}
				queue = append(queue, fullPath)
				continue
			}
			
			if entry.Type().IsRegular() {
				ext := filepath.Ext(entry.Name())
				if jsExtensions[ext] {
					files = append(files, fullPath)
				}
			}
		}
	}
	
	sort.Strings(files)
	return files
}

func extractModuleSpecifiers(source string) []string {
	specifiers := make(map[string]bool)
	
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`\bfrom\s*["']([^"']+)["']`),
		regexp.MustCompile(`\bimport\s*["']([^"']+)["']`),
		regexp.MustCompile(`\bimport\s*\(\s*["']([^"']+)["']\s*\)`),
		regexp.MustCompile(`\brequire\s*\(\s*["']([^"']+)["']\s*\)`),
	}
	
	for _, pattern := range patterns {
		matches := pattern.FindAllStringSubmatch(source, -1)
		for _, match := range matches {
			if len(match) > 1 && match[1] != "" {
				specifiers[match[1]] = true
			}
		}
	}
	
	result := make([]string, 0, len(specifiers))
	for spec := range specifiers {
		result = append(result, spec)
	}
	
	return result
}

func collectRootDistBundledRuntimeMirrors(distDir string, bundledSpecs map[string]*DependencyRecord) map[string]*MirrorRecord {
	mirrors := make(map[string]*MirrorRecord)
	
	filePaths := walkJavaScriptFiles(distDir)
	
	for _, filePath := range filePaths {
		source, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}
		
		relPath, _ := filepath.Rel(distDir, filePath)
		relPath = filepath.ToSlash(relPath)
		
		specifiers := extractModuleSpecifiers(string(source))
		for _, specifier := range specifiers {
			dependencyName := packageNameFromSpecifier(specifier)
			if dependencyName == "" {
				continue
			}
			
			bundledSpec, exists := bundledSpecs[dependencyName]
			if !exists {
				continue
			}
			
			existing, exists := mirrors[dependencyName]
			if exists {
				found := false
				for _, imp := range existing.Importers {
					if imp == relPath {
						found = true
						break
					}
				}
				if !found {
					existing.Importers = append(existing.Importers, relPath)
				}
				continue
			}
			
			mirrors[dependencyName] = &MirrorRecord{
				Importers: []string{relPath},
				PluginIds: bundledSpec.PluginIds,
				Spec:      bundledSpec.Spec,
			}
		}
	}
	
	return mirrors
}

func collectBundledPluginRootRuntimeMirrorErrors(rootPackageJson map[string]interface{}, bundledRuntimeDependencySpecs map[string]*DependencyRecord, requiredRootMirrors map[string]*MirrorRecord) []string {
	rootRuntimeDeps := collectRuntimeDependencySpecs(rootPackageJson)
	var errors []string
	
	for dependencyName, record := range bundledRuntimeDependencySpecs {
		for _, conflict := range record.Conflicts {
			errors = append(errors, fmt.Sprintf(
				"bundled runtime dependency '%s' has conflicting plugin specs: %s use '%s', %s uses '%s'.",
				dependencyName,
				strings.Join(record.PluginIds, ", "),
				record.Spec,
				conflict.PluginId,
				conflict.Spec,
			))
		}
	}
	
	for dependencyName, mirror := range requiredRootMirrors {
		rootSpec, exists := rootRuntimeDeps[dependencyName]
		if !exists || rootSpec == "" {
			sort.Strings(mirror.Importers)
			importerLabel := strings.Join(mirror.Importers, ", ")
			sort.Strings(mirror.PluginIds)
			pluginLabel := strings.Join(mirror.PluginIds, ", ")
			errors = append(errors, fmt.Sprintf(
				"root dist imports bundled plugin runtime dependency '%s' from %s; mirror '%s: %s' in root package.json (declared by %s).",
				dependencyName,
				importerLabel,
				dependencyName,
				mirror.Spec,
				pluginLabel,
			))
			continue
		}
		if rootSpec != mirror.Spec {
			sort.Strings(mirror.Importers)
			importerLabel := strings.Join(mirror.Importers, ", ")
			sort.Strings(mirror.PluginIds)
			pluginLabel := strings.Join(mirror.PluginIds, ", ")
			errors = append(errors, fmt.Sprintf(
				"root dist imports bundled plugin runtime dependency '%s' from %s; root package.json has '%s' but plugin manifest declares '%s' (%s).",
				dependencyName,
				importerLabel,
				rootSpec,
				mirror.Spec,
				pluginLabel,
			))
		}
	}
	
	return errors
}

func main() {
	// This is a library translation, so no main execution logic is needed
	// The functions above can be called from other Go code
}
