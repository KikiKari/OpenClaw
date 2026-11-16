// abstraction-provenance: {"artifact_sha256": "230363fce80e1071c010a6020957ff7878dc0ca54913b3ca908c8e2b46ea3ded", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "go"}
// check-no-conflict-markers.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func isBinaryBuffer(buffer []byte) bool {
	return bytes.ContainsRune(buffer, 0)
}

func findConflictMarkerLines(content string) []int {
	lines := strings.Split(content, "\n")
	var matches []int
	for index, line := range lines {
		trimmedLine := strings.TrimRight(line, "\r")
		if strings.HasPrefix(trimmedLine, "<<<<<<< ") ||
			strings.HasPrefix(trimmedLine, "||||||| ") ||
			trimmedLine == "=======" ||
			strings.HasPrefix(trimmedLine, ">>>>>>> ") {
			matches = append(matches, index+1)
		}
	}
	return matches
}

func listTrackedFiles(cwd string) ([]string, error) {
	cmd := exec.Command("git", "ls-files", "-z")
	cmd.Dir = cwd
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	paths := strings.Split(string(output), "\x00")
	var result []string
	for _, p := range paths {
		if p != "" {
			result = append(result, filepath.Join(cwd, p))
		}
	}
	return result, nil
}

func findConflictMarkersInFiles(filePaths []string) ([]map[string]interface{}, error) {
	var violations []map[string]interface{}
	for _, filePath := range filePaths {
		content, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}

		if isBinaryBuffer(content) {
			continue
		}

		lines := findConflictMarkerLines(string(content))
		if len(lines) > 0 {
			violation := map[string]interface{}{
				"filePath": filePath,
				"lines":    lines,
			}
			violations = append(violations, violation)
		}
	}
	return violations, nil
}

func mainFunc() error {
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}

	filePaths, err := listTrackedFiles(cwd)
	if err != nil {
		return err
	}

	violations, err := findConflictMarkersInFiles(filePaths)
	if err != nil {
		return err
	}

	if len(violations) == 0 {
		return nil
	}

	fmt.Fprintln(os.Stderr, "Found unresolved merge conflict markers:")
	for _, violation := range violations {
		filePath := violation["filePath"].(string)
		lines := violation["lines"].([]int)
		
		relPath, err := filepath.Rel(cwd, filePath)
		if err != nil || relPath == "" {
			relPath = filePath
		}
		
		lineStrs := make([]string, len(lines))
		for i, line := range lines {
			lineStrs[i] = fmt.Sprintf("%d", line)
		}
		fmt.Fprintf(os.Stderr, "- %s:%s\n", relPath, strings.Join(lineStrs, ","))
	}
	
	os.Exit(1)
	return nil
}

func main() {
	if err := mainFunc(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
