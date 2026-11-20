// abstraction-provenance: {"artifact_sha256": "927ed73cd3946874e15c8c6952819c3f2f83cc55ab1e5eefa3b0160602ad9686", "source_sha256": "f01a1a7ac46054c631b27d8f3e127238ed7417a0fe38ecb59857573bd355603f", "target_language": "go"}
// guard-inventory-utils.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/guard-inventory-utils.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ParsedTypeScriptSourceCache simulates the JS Map cache
var parsedTypeScriptSourceCache = make(map[string]interface{})

// normalizeRepoPath converts file paths to repo-relative paths with forward slashes
func normalizeRepoPath(repoRoot, filePath string) string {
	rel, _ := filepath.Rel(repoRoot, filePath)
	return strings.ReplaceAll(rel, string(os.PathSeparator), "/")
}

// resolveRepoSpecifier resolves module specifiers relative to importer
func resolveRepoSpecifier(repoRoot, specifier, importerFile string) *string {
	if strings.HasPrefix(specifier, ".") {
		dir := filepath.Dir(importerFile)
		resolved := filepath.Join(dir, specifier)
		result := normalizeRepoPath(repoRoot, resolved)
		return &result
	}
	if strings.HasPrefix(specifier, "/") {
		result := normalizeRepoPath(repoRoot, specifier)
		return &result
	}
	return nil
}

// diffInventoryEntries compares expected vs actual inventory entries
func diffInventoryEntries(expected, actual []interface{}, compareEntries func(a, b interface{}) bool) map[string][]interface{} {
	expectedKeys := make(map[string]bool)
	actualKeys := make(map[string]bool)
	
	for _, entry := range expected {
		jsonStr, _ := json.Marshal(entry)
		expectedKeys[string(jsonStr)] = true
	}
	
	for _, entry := range actual {
		jsonStr, _ := json.Marshal(entry)
		actualKeys[string(jsonStr)] = true
	}
	
	var missing []interface{}
	var unexpected []interface{}
	
	for _, entry := range expected {
		jsonStr, _ := json.Marshal(entry)
		if !actualKeys[string(jsonStr)] {
			missing = append(missing, entry)
		}
	}
	
	for _, entry := range actual {
		jsonStr, _ := json.Marshal(entry)
		if !expectedKeys[string(jsonStr)] {
			unexpected = append(unexpected, entry)
		}
	}
	
	// Sort results using compareEntries
	sort.Slice(missing, func(i, j int) bool {
		return compareEntries(missing[i], missing[j])
	})
	
	sort.Slice(unexpected, func(i, j int) bool {
		return compareEntries(unexpected[i], unexpected[j])
	})
	
	return map[string][]interface{}{
		"missing":     missing,
		"unexpected":  unexpected,
	}
}

// writeLine writes a line to the stream
func writeLine(writer io.Writer, text string) {
	fmt.Fprintln(writer, text)
}

// collectTypeScriptInventory collects inventory entries from TypeScript files
func collectTypeScriptInventory(params map[string]interface{}) ([]interface{}, error) {
	var inventory []interface{}
	
	files := params["files"].([]string)
	ts := params["ts"].(map[string]interface{})
	scriptKind := params["scriptKind"].(int)
	if scriptKind == 0 {
		scriptKind = ts["ScriptKind"].(map[string]int)["TS"]
	}
	
	shouldParseSource, hasShouldParse := params["shouldParseSource"].(func(string, string) bool)
	collectEntries := params["collectEntries"].(func(interface{}, string) []interface{})
	
	for _, filePath := range files {
		cacheKey := fmt.Sprintf("%d:%s", scriptKind, filePath)
		
		var sourceFile interface{}
		if cached, exists := parsedTypeScriptSourceCache[cacheKey]; exists {
			sourceFile = cached
		} else {
			content, err := os.ReadFile(filePath)
			if err != nil {
				return nil, err
			}
			
			source := string(content)
			if hasShouldParse && !shouldParseSource(source, filePath) {
				continue
			}
			
			// Simulate TypeScript source file creation
			sourceFile = map[string]interface{}{
				"fileName": filePath,
				"text":     source,
			}
			parsedTypeScriptSourceCache[cacheKey] = sourceFile
		}
		
		entries := collectEntries(sourceFile, filePath)
		inventory = append(inventory, entries...)
	}
	
	compareEntries := params["compareEntries"].(func(interface{}, interface{}) bool)
	sort.Slice(inventory, func(i, j int) bool {
		return compareEntries(inventory[i], inventory[j])
	})
	
	return inventory, nil
}

// runBaselineInventoryCheck runs the baseline inventory check
func runBaselineInventoryCheck(params map[string]interface{}) (int, error) {
	// Setup streams
	var stdout, stderr io.Writer = os.Stdout, os.Stderr
	if ioParam, exists := params["io"]; exists {
		ioMap := ioParam.(map[string]io.Writer)
		if s, ok := ioMap["stdout"]; ok {
			stdout = s
		}
		if s, ok := ioMap["stderr"]; ok {
			stderr = s
		}
	}
	
	// Check for --json flag
	argv := params["argv"].([]string)
	jsonFlag := false
	for _, arg := range argv {
		if arg == "--json" {
			jsonFlag = true
			break
		}
	}
	
	// Collect data
	collectActual := params["collectActual"].(func() ([]interface{}, error))
	actual, err := collectActual()
	if err != nil {
		return 1, err
	}
	
	readExpected := params["readExpected"].(func() ([]interface{}, error))
	expected, err := readExpected()
	if err != nil {
		return 1, err
	}
	
	diffInventory := params["diffInventory"].(func([]interface{}, []interface{}) map[string][]interface{})
	diffResult := diffInventory(expected, actual)
	missing := diffResult["missing"]
	unexpected := diffResult["unexpected"]
	matchesBaseline := len(missing) == 0 && len(unexpected) == 0
	
	formatInventoryHuman := params["formatInventoryHuman"].(func([]interface{}) string)
	formatEntry := params["formatEntry"].(func(interface{}) string)
	
	if jsonFlag {
		jsonData, _ := json.MarshalIndent(actual, "", "  ")
		writeLine(stdout, string(jsonData))
	} else {
		writeLine(stdout, formatInventoryHuman(actual))
		if matchesBaseline {
			writeLine(stdout, fmt.Sprintf("Baseline matches (%d entries).", len(actual)))
		} else {
			writeLine(stdout, fmt.Sprintf("Baseline mismatch (%d unexpected, %d missing).", len(unexpected), len(missing)))
			
			if len(unexpected) > 0 {
				writeLine(stderr, "Unexpected entries:")
				for _, entry := range unexpected {
					writeLine(stderr, "- "+formatEntry(entry))
				}
			}
			
			if len(missing) > 0 {
				writeLine(stderr, "Missing baseline entries:")
				for _, entry := range missing {
					writeLine(stderr, "- "+formatEntry(entry))
				}
			}
		}
	}
	
	if matchesBaseline {
		return 0, nil
	}
	return 1, nil
}

func main() {
	// This is a utility library, so main is just a placeholder
	// In practice, these functions would be called by other Go code
	fmt.Println("Guard Inventory Utils - Go Implementation")
}
