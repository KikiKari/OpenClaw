// abstraction-provenance: {"artifact_sha256": "2c84364613d3d618b25abeb26ee44c26ebe56fd29572c60dc27b4fa496feaa45", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "go"}
// run-extension-oxlint.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type Params struct {
	ToolName       string   `json:"toolName"`
	LockName       string   `json:"lockName"`
	TempDirPrefix  string   `json:"tempDirPrefix"`
	EmptyMessage   string   `json:"emptyMessage"`
	Roots          []string `json:"roots"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: run-extension-oxlint <params-json>")
		os.Exit(1)
	}

	var params Params
	if err := json.Unmarshal([]byte(os.Args[1]), &params); err != nil {
		panic(err)
	}

	repoRoot, err := os.Getwd()
	if err != nil {
		panic(err)
	}

	oxlintPath := filepath.Join("node_modules", ".bin", "oxlint")
	if _, err := os.Stat(oxlintPath); os.IsNotExist(err) {
		oxlintPath = "oxlint"
	}

	lockName := fmt.Sprintf("%s-%s", params.ToolName, params.LockName)
	tempDir, err := os.MkdirTemp("", params.TempDirPrefix+"*")
	if err != nil {
		panic(err)
	}
	defer os.RemoveAll(tempDir)

	tempConfigPath := filepath.Join(tempDir, "oxlint.json")
	exitCode := 0

	// Acquire lock
	acquireLocalHeavyCheckLock(lockName)
	defer releaseLocalHeavyCheckLock(lockName)

	// Prepare artifacts
	prepareExtensionPackageBoundaryArtifacts(repoRoot)

	// Collect TypeScript files
	var extensionFiles []string
	for _, root := range params.Roots {
		fullRoot := filepath.Join(repoRoot, root)
		files, err := collectTypeScriptFiles(fullRoot)
		if err != nil {
			panic(err)
		}
		extensionFiles = append(extensionFiles, files...)
	}

	if len(extensionFiles) == 0 {
		fmt.Println(params.EmptyMessage)
		os.Exit(1)
	}

	// Write temporary config
	writeTempOxlintConfig(repoRoot, tempConfigPath)

	// Build arguments
	baseArgs := []string{"-c", tempConfigPath}
	baseArgs = append(baseArgs, os.Args[2:]...)
	baseArgs = append(baseArgs, extensionFiles...)

	finalArgs, env := applyLocalOxlintPolicy(baseArgs, os.Environ())

	// Run oxlint
	cmd := exec.Command(oxlintPath, finalArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	
	if err := cmd.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		} else {
			panic(err)
		}
	}

	os.Exit(exitCode)
}

func prepareExtensionPackageBoundaryArtifacts(repoRoot string) {
	lockName := "extension-package-boundary-artifacts"
	acquireLocalHeavyCheckLock(lockName)
	defer releaseLocalHeavyCheckLock(lockName)

	scriptPath := filepath.Join(repoRoot, "scripts", "prepare-extension-package-boundary-artifacts.mjs")
	cmd := exec.Command("node", scriptPath)
	cmd.Dir = repoRoot
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()

	if err := cmd.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			panic(err)
		}
	}
}

func writeTempOxlintConfig(repoRoot, configPath string) {
	configFile := filepath.Join(repoRoot, ".oxlintrc.json")
	data, err := os.ReadFile(configFile)
	if err != nil {
		panic(err)
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		panic(err)
	}

	delete(config, "$schema")

	if ignorePatterns, ok := config["ignorePatterns"].([]interface{}); ok {
		for _, pattern := range ignorePatterns {
			if strPattern, ok := pattern.(string); ok {
				if isTopLevelExtensionsIgnorePattern(strPattern) {
					panic(fmt.Sprintf(
						"Refusing to run extension oxlint with .oxlintrc.json ignore pattern %q. Remove the top-level extensions ignore so root and focused lint agree.",
						strPattern))
				}
			}
		}
	}

	formatted, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		panic(err)
	}

	err = os.WriteFile(configPath, append(formatted, '\n'), 0644)
	if err != nil {
		panic(err)
	}
}

func isTopLevelExtensionsIgnorePattern(pattern string) bool {
	normalized := strings.ReplaceAll(strings.TrimSpace(pattern), "\\", "/")
	normalized = strings.TrimPrefix(normalized, "./")
	normalized = strings.TrimPrefix(normalized, "/")

	return normalized == "extensions" || normalized == "extensions/" || normalized == "extensions/**"
}

func collectTypeScriptFiles(directoryPath string) ([]string, error) {
	var files []string
	
	entries, err := os.ReadDir(directoryPath)
	if err != nil {
		return nil, err
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	cwd, _ := os.Getwd()

	for _, entry := range entries {
		entryPath := filepath.Join(directoryPath, entry.Name())
		
		if entry.IsDir() {
			subFiles, err := collectTypeScriptFiles(entryPath)
			if err != nil {
				return nil, err
			}
			files = append(files, subFiles...)
			continue
		}

		if !entry.Type().IsRegular() {
			continue
		}

		if !strings.HasSuffix(entry.Name(), ".ts") && !strings.HasSuffix(entry.Name(), ".tsx") {
			continue
		}

		relPath, err := filepath.Rel(cwd, entryPath)
		if err != nil {
			return nil, err
		}
		
		// Convert to forward slashes for consistency
		relPath = filepath.ToSlash(relPath)
		files = append(files, relPath)
	}

	return files, nil
}

// Placeholder functions - these would need actual implementation based on your local-heavy-check-runtime logic
func acquireLocalHeavyCheckLock(name string) {
	// Implementation depends on your locking mechanism
	fmt.Printf("Acquiring lock: %s\n", name)
}

func releaseLocalHeavyCheckLock(name string) {
	// Implementation depends on your locking mechanism
	fmt.Printf("Releasing lock: %s\n", name)
}

func applyLocalOxlintPolicy(args []string, env []string) ([]string, []string) {
	// This should implement the policy logic from your JavaScript version
	// For now, returning unchanged args and env
	return args, env
}
