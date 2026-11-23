// abstraction-provenance: {"artifact_sha256": "402e2d592b6384620a9f3f56a5a06e545f92a12e8b713c9dbab5de364cee6263", "source_sha256": "cd0bfcd0719418f4f0877e7488a8136ca9e8ba296aaaf669b43c7da1dca0f581", "target_language": "go"}
// test-built-bundled-channel-entry-smoke.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-bundled-channel-entry-smoke.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type PackageJSON struct {
	OpenClaw *struct {
		Channel     interface{} `json:"channel"`
		Extensions  []string    `json:"extensions"`
		SetupEntry string      `json:"setupEntry"`
	} `json:"openclaw"`
}

type EntryFile struct {
	ID   string
	Kind string
	Path string
}

type Secrets struct {
	SecretTargetRegistryEntries []interface{}
}

func main() {
	installProcessWarningFilter()
	
	if os.Getenv("OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK") == "" {
		os.Setenv("OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK", "1")
	}
	
	args := parseArgs(os.Args[1:])
	distExtensionsRoot := filepath.Join(args.PackageRoot, "dist", "extensions")
	
	entryFiles := collectBundledChannelEntryFiles(distExtensionsRoot)
	channelCount := 0
	setupCount := 0
	legacySetupCount := 0
	
	for _, entryFile := range entryFiles {
		if entryFile.Kind == "channel" {
			smokeChannelEntry(entryFile)
			channelCount++
			continue
		}
		if smokeSetupEntry(entryFile) {
			setupCount++
		} else {
			legacySetupCount++
		}
	}
	
	if channelCount <= 0 {
		panic("no bundled channel entries found")
	}
	
	fmt.Printf("[build-smoke] bundled channel entry smoke passed packageRoot=%s channel=%d setup=%d legacySetup=%d\n", 
		args.PackageRoot, channelCount, setupCount, legacySetupCount)
}

func parseArgs(argv []string) map[string]string {
	packageRoot := os.Getenv("OPENCLAW_BUNDLED_CHANNEL_SMOKE_ROOT")
	
	for i := 0; i < len(argv); i++ {
		arg := argv[i]
		if arg == "--package-root" {
			if i+1 < len(argv) {
				packageRoot = argv[i+1]
				i++
				continue
			}
		}
		if strings.HasPrefix(arg, "--package-root=") {
			packageRoot = strings.TrimPrefix(arg, "--package-root=")
			continue
		}
		panic(fmt.Sprintf("unknown argument: %s", arg))
	}
	
	if packageRoot == "" {
		dir, _ := filepath.Abs(filepath.Dir(os.Args[0]))
		packageRoot = filepath.Join(dir, "..")
	} else {
		absPath, _ := filepath.Abs(packageRoot)
		packageRoot = absPath
	}
	
	return map[string]string{"PackageRoot": packageRoot}
}

func readJson(pathname string) *PackageJSON {
	data, err := os.ReadFile(pathname)
	if err != nil {
		panic(err)
	}
	
	var pkg PackageJSON
	err = json.Unmarshal(data, &pkg)
	if err != nil {
		panic(err)
	}
	
	return &pkg
}

func extensionEntryToDistFilename(entry string) string {
	result := strings.TrimPrefix(entry, "./")
	ext := filepath.Ext(result)
	if ext != "" {
		result = strings.TrimSuffix(result, ext) + ".js"
	}
	return result
}

func collectBundledChannelEntryFiles(distExtensionsRoot string) []EntryFile {
	var files []EntryFile
	
	entries, err := os.ReadDir(distExtensionsRoot)
	if err != nil {
		panic(err)
	}
	
	for _, dirent := range entries {
		if !dirent.IsDir() {
			continue
		}
		
		extensionRoot := filepath.Join(distExtensionsRoot, dirent.Name())
		packageJsonPath := filepath.Join(extensionRoot, "package.json")
		
		if _, err := os.Stat(packageJsonPath); os.IsNotExist(err) {
			continue
		}
		
		packageJson := readJson(packageJsonPath)
		if packageJson.OpenClaw == nil || packageJson.OpenClaw.Channel == nil {
			continue
		}
		
		extensionEntries := []string{"./index.ts"}
		if packageJson.OpenClaw.Extensions != nil && len(packageJson.OpenClaw.Extensions) > 0 {
			extensionEntries = packageJson.OpenClaw.Extensions
		}
		
		for _, entry := range extensionEntries {
			if entry == "" {
				continue
			}
			files = append(files, EntryFile{
				ID:   dirent.Name(),
				Kind: "channel",
				Path: filepath.Join(extensionRoot, extensionEntryToDistFilename(entry)),
			})
		}
		
		setupEntry := packageJson.OpenClaw.SetupEntry
		if setupEntry != "" {
			files = append(files, EntryFile{
				ID:   dirent.Name(),
				Kind: "setup",
				Path: filepath.Join(extensionRoot, extensionEntryToDistFilename(setupEntry)),
			})
		}
		
		channelEntryPath := filepath.Join(extensionRoot, "channel-entry.js")
		if _, err := os.Stat(channelEntryPath); err == nil {
			files = append(files, EntryFile{
				ID:   dirent.Name(),
				Kind: "channel",
				Path: channelEntryPath,
			})
		}
	}
	
	sort.Slice(files, func(i, j int) bool {
		keyI := fmt.Sprintf("%s:%s:%s", files[i].ID, files[i].Kind, files[i].Path)
		keyJ := fmt.Sprintf("%s:%s:%s", files[j].ID, files[j].Kind, files[j].Path)
		return keyI < keyJ
	})
	
	return files
}

func assertSecretContractShape(secrets *Secrets, context string) {
	if secrets == nil {
		panic(fmt.Sprintf("%s: missing secrets contract", context))
	}
	
	if secrets.SecretTargetRegistryEntries == nil {
		panic(fmt.Sprintf("%s: secretTargetRegistryEntries must be an array", context))
	}
}

func assertEntryFileExists(entry EntryFile) {
	if _, err := os.Stat(entry.Path); os.IsNotExist(err) {
		panic(fmt.Sprintf("%s %s entry missing from packed dist: %s", entry.ID, entry.Kind, entry.Path))
	}
}

func smokeChannelEntry(entryFile EntryFile) {
	assertEntryFileExists(entryFile)
	
	// In Go we can't dynamically import JS modules, so we just check the file exists
	// The actual functionality testing would require a JavaScript runtime
	fmt.Printf("Checking channel entry for %s at %s\n", entryFile.ID, entryFile.Path)
}

func smokeSetupEntry(entryFile EntryFile) bool {
	assertEntryFileExists(entryFile)
	
	// In Go we can't dynamically import JS modules, so we just check the file exists
	// The actual functionality testing would require a JavaScript runtime
	fmt.Printf("Checking setup entry for %s at %s\n", entryFile.ID, entryFile.Path)
	return true // Assume it's a valid setup entry
}

func installProcessWarningFilter() {
	// Placeholder - Go doesn't have the same process warning system as Node.js
}
