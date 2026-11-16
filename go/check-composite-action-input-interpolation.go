// abstraction-provenance: {"artifact_sha256": "4f97d7853f0f8619a2c6ec91c6b0c5163c9db9a8bb9f078a5f0fae3a13047b6d", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "go"}
// check-composite-action-input-interpolation.py — portiert nach go
// Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	inputInterpolationRe = regexp.MustCompile(`\$\{\{\s*inputs\.`)
	runLineRe            = regexp.MustCompile(`^(\s*)run:\s*(.*)$`)
	usingCompositeRe     = regexp.MustCompile(`^\s*using:\s*composite\s*$`)
)

func indentation(line string) int {
	return len(line) - len(strings.TrimLeft(line, " "))
}

func scanFile(path string) ([][2]string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	text := string(content)
	if !usingCompositeRe.MatchString(text) {
		return nil, nil
	}

	lines := strings.Split(text, "\n")
	var violations [][2]string
	lineCount := len(lines)
	index := 0

	for index < lineCount {
		line := lines[index]
		matches := runLineRe.FindStringSubmatch(line)
		if matches == nil {
			index++
			continue
		}

		runIndent := len(matches[1])
		runValue := strings.TrimSpace(matches[2])
		lineNo := index + 1

		if runValue != "" && runValue[0] != '|' && runValue[0] != '>' {
			if inputInterpolationRe.MatchString(runValue) {
				violations = append(violations, [2]string{fmt.Sprintf("%d", lineNo), strings.TrimSpace(line)})
			}
			index++
			continue
		}

		index++
		for index < lineCount {
			scriptLine := lines[index]
			if strings.TrimSpace(scriptLine) == "" {
				index++
				continue
			}
			if indentation(scriptLine) <= runIndent {
				break
			}
			if inputInterpolationRe.MatchString(scriptLine) {
				violations = append(violations, [2]string{fmt.Sprintf("%d", index+1), strings.TrimSpace(scriptLine)})
			}
			index++
		}
	}

	return violations, nil
}

func main() {
	root := ".github/actions"
	var files []string
	
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && (filepath.Base(path) == "action.yml" || filepath.Base(path) == "action.yaml") {
			files = append(files, path)
		}
		return nil
	})
	
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error walking directory: %v\n", err)
		os.Exit(1)
	}

	// Sort files
	sort.Strings(files)
	
	var allViolations [][3]string

	for _, filePath := range files {
		violations, err := scanFile(filePath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error scanning file %s: %v\n", filePath, err)
			os.Exit(1)
		}
		for _, violation := range violations {
			allViolations = append(allViolations, [3]string{filePath, violation[0], violation[1]})
		}
	}

	if len(allViolations) > 0 {
		fmt.Println("Disallowed direct inputs interpolation in composite run blocks:")
		for _, violation := range allViolations {
			fmt.Printf("- %s:%s: %s\n", violation[0], violation[1], violation[2])
		}
		fmt.Println("Use env: and reference shell variables instead.")
		os.Exit(1)
	}

	fmt.Println("No direct inputs interpolation found in composite run blocks.")
}
