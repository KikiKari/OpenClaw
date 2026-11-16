// abstraction-provenance: {"artifact_sha256": "b3b2252e89d8cad2f143e0c8e3ed5861071a4b3372070be160dbc66f0dcd92b9", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "go"}
// callsite-guard.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Diese Funktionen mÃ¼ssen aus ts-guard-utils implementiert werden
func collectTypeScriptFilesFromRoots(sourceRoots []string, extraTestSuffixes []string) ([]string, error) {
	var files []string
	
	for _, root := range sourceRoots {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			
			if info.IsDir() {
				return nil
			}
			
			if strings.HasSuffix(info.Name(), ".ts") || strings.HasSuffix(info.Name(), ".tsx") {
				shouldInclude := true
				for _, suffix := range extraTestSuffixes {
					if strings.Contains(info.Name(), suffix) {
						shouldInclude = false
						break
				}
			}
				if shouldInclude {
					files = append(files, path)
				}
			}
			return nil
		})
		
		if err != nil {
			return nil, err
		}
	}
	
	return files, nil
}

func resolveRepoRoot(importMetaUrl string) string {
	// Vereinfachte Implementierung - in der Praxis sollte der tatsÃ¤chliche Root ermittelt werden
	dir, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir
		}
		
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return dir
}

func resolveSourceRoots(repoRoot string, sourceRoots []string) []string {
	if len(sourceRoots) == 0 {
		return []string{filepath.Join(repoRoot, "src")}
	}
	
	var resolved []string
	for _, root := range sourceRoots {
		if !filepath.IsAbs(root) {
			resolved = append(resolved, filepath.Join(repoRoot, root))
		} else {
			resolved = append(resolved, root)
		}
	}
	return resolved
}

type Params struct {
	ImportMetaUrl       string
	SourceRoots         []string
	ExtraTestSuffixes   []string
	SkipRelativePath    func(string) bool
	FindCallLines       func(string, string) []int
	AllowCallsite       func(string) bool
	Header              string
	Footer              string
	SortViolations      *bool
}

func runCallsiteGuard(params Params) {
	repoRoot := resolveRepoRoot(params.ImportMetaUrl)
	sourceRoots := resolveSourceRoots(repoRoot, params.SourceRoots)
	
	files, err := collectTypeScriptFilesFromRoots(sourceRoots, params.ExtraTestSuffixes)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error collecting files: %v\n", err)
		os.Exit(1)
	}
	
	var violations []string
	
	for _, filePath := range files {
		relPath, _ := filepath.Rel(repoRoot, filePath)
		relPath = filepath.ToSlash(relPath)
		
		if params.SkipRelativePath != nil && params.SkipRelativePath(relPath) {
			continue
		}
		
		contentBytes, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}
		content := string(contentBytes)
		
		lines := params.FindCallLines(content, filePath)
		for _, line := range lines {
			callsite := fmt.Sprintf("%s:%d", relPath, line)
			if params.AllowCallsite != nil && params.AllowCallsite(callsite) {
				continue
			}
			violations = append(violations, callsite)
		}
	}
	
	if len(violations) == 0 {
		return
	}
	
	fmt.Fprintln(os.Stderr, params.Header)
	
	var output []string
	if params.SortViolations == nil || *params.SortViolations {
		output = make([]string, len(violations))
		copy(output, violations)
		sort.Strings(output)
	} else {
		output = violations
	}
	
	for _, violation := range output {
		fmt.Fprintf(os.Stderr, "- %s\n", violation)
	}
	
	if params.Footer != "" {
		fmt.Fprintln(os.Stderr, params.Footer)
	}
	
	os.Exit(1)
}

// Beispiel fÃ¼r eine FindCallLines-Funktion
func findCallLinesExample(content, filePath string) []int {
	var lines []int
	scanner := bufio.NewScanner(strings.NewReader(content))
	lineNum := 1
	
	for scanner.Scan() {
		line := scanner.Text()
		// Beispiel: Suche nach Funktionsaufrufen mit Klammern
		if strings.Contains(line, "(") && strings.Contains(line, ")") {
			lines = append(lines, lineNum)
		}
		lineNum++
	}
	
	return lines
}

func main() {
	// Beispielaufruf - muss entsprechend angepasst werden
	params := Params{
		ImportMetaUrl:     "",
		SourceRoots:       []string{},
		ExtraTestSuffixes: []string{},
		FindCallLines:     findCallLinesExample,
		Header:            "Callsite violations found:",
	}
	
	runCallsiteGuard(params)
}
