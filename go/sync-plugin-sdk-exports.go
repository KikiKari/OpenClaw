// abstraction-provenance: {"artifact_sha256": "414f0ad88611a72274f456545155c18cac6eb887ea4d42d1ba90c099fa0c4639", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "go"}
// sync-plugin-sdk-exports.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
)

func main() {
	checkOnly := false
	for _, arg := range os.Args {
		if arg == "--check" {
			checkOnly = true
			break
		}
	}

	// Read package.json
	packageJsonPath := "package.json"
	packageJsonBytes, err := ioutil.ReadFile(packageJsonPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading package.json: %v\n", err)
		os.Exit(1)
	}

	var packageJson map[string]interface{}
	err = json.Unmarshal(packageJsonBytes, &packageJson)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing package.json: %v\n", err)
		os.Exit(1)
	}

	// Get current exports
	var currentExports map[string]interface{}
	if exports, exists := packageJson["exports"]; exists {
		if exportsMap, ok := exports.(map[string]interface{}); ok {
			currentExports = exportsMap
		} else {
			currentExports = make(map[string]interface{})
		}
	} else {
		currentExports = make(map[string]interface{})
	}

	// Build synced plugin SDK exports
	syncedPluginSdkExports := buildPluginSdkPackageExports()

	// Build next exports
	nextExports := make(map[string]interface{})
	insertedPluginSdkExports := false

	// Process current exports
	for key, value := range currentExports {
		if strings.HasPrefix(key, "./plugin-sdk") {
			if !insertedPluginSdkExports {
				for k, v := range syncedPluginSdkExports {
					nextExports[k] = v
				}
				insertedPluginSdkExports = true
			}
			continue
		}
		nextExports[key] = value
		if key == "." && !insertedPluginSdkExports {
			for k, v := range syncedPluginSdkExports {
				nextExports[k] = v
			}
			insertedPluginSdkExports = true
		}
	}

	// If we haven't inserted plugin SDK exports yet, do it now
	if !insertedPluginSdkExports {
		for k, v := range syncedPluginSdkExports {
			nextExports[k] = v
		}
	}

	// Check mode
	if checkOnly {
		currentExportsJson, _ := json.Marshal(currentExports)
		nextExportsJson, _ := json.Marshal(nextExports)
		
		if string(currentExportsJson) != string(nextExportsJson) {
			fmt.Fprintln(os.Stderr, "plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`.")
			os.Exit(1)
		}
		fmt.Println("plugin-sdk exports synced.")
		os.Exit(0)
	}

	// Update package.json
	packageJson["exports"] = nextExports
	updatedPackageJson, err := json.MarshalIndent(packageJson, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error serializing package.json: %v\n", err)
		os.Exit(1)
	}
	
	// Add newline at end
	updatedPackageJson = append(updatedPackageJson, '\n')
	
	err = ioutil.WriteFile(packageJsonPath, updatedPackageJson, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing package.json: %v\n", err)
		os.Exit(1)
	}
}

func buildPluginSdkPackageExports() map[string]interface{} {
	// This function should replicate the logic from ./lib/plugin-sdk-entries.mjs
	// Since we don't have access to that file, we'll create a placeholder
	// In a real implementation, this would read the plugin-sdk directory structure
	// and generate appropriate export mappings
	
	exports := make(map[string]interface{})
	
	// Example entries - replace with actual logic from plugin-sdk-entries.mjs
	exports["./plugin-sdk"] = map[string]interface{}{
		"types": "./dist/plugin-sdk/index.d.ts",
		"default": "./dist/plugin-sdk/index.js",
	}
	exports["./plugin-sdk/*"] = map[string]interface{}{
		"types": "./dist/plugin-sdk/*.d.ts",
		"default": "./dist/plugin-sdk/*.js",
	}
	
	return exports
}
