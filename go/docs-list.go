// abstraction-provenance: {"artifact_sha256": "97d7e7c15433a3caaa2ad74b06a7aa0092e8822dcfcfb0e3e69f24557739a7b5", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "go"}
// docs-list.js — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const DOCS_DIR = "docs"

var EXCLUDED_DIRS = map[string]bool{
	"archive":  true,
	"research": true,
}

func main() {
	// Handle broken pipe errors gracefully
	stdout := bufio.NewWriter(os.Stdout)
	defer func() {
		if err := stdout.Flush(); err != nil {
			if strings.Contains(err.Error(), "broken pipe") {
				os.Exit(0)
			}
			panic(err)
		}
	}()

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "docs:list: failed to get current directory: %v\n", err)
		os.Exit(1)
	}

	docsPath := filepath.Join(cwd, DOCS_DIR)
	if _, err := os.Stat(docsPath); os.IsNotExist(err) {
		fmt.Fprintln(os.Stderr, "docs:list: missing docs directory. Run from repo root.")
		os.Exit(1)
	} else if err != nil {
		fmt.Fprintf(os.Stderr, "docs:list: failed to access docs directory: %v\n", err)
		os.Exit(1)
	}

	if info, err := os.Stat(docsPath); !info.IsDir() {
		fmt.Fprintln(os.Stderr, "docs:list: docs path is not a directory.")
		os.Exit(1)
	}

	fmt.Fprintln(stdout, "Listing all markdown files in docs folder:")

	markdownFiles := walkMarkdownFiles(docsPath, docsPath)
	sort.Slice(markdownFiles, func(i, j int) bool {
		return markdownFiles[i] < markdownFiles[j]
	})

	for _, relativePath := range markdownFiles {
		fullPath := filepath.Join(docsPath, relativePath)
		metadata := extractMetadata(fullPath)

		if metadata.summary != "" {
			fmt.Fprintf(stdout, "%s - %s\n", relativePath, metadata.summary)
			if len(metadata.readWhen) > 0 {
				fmt.Fprintf(stdout, "  Read when: %s\n", strings.Join(metadata.readWhen, "; "))
			}
		} else {
			reason := ""
			if metadata.error != "" {
				reason = fmt.Sprintf(" - [%s]", metadata.error)
			}
			fmt.Fprintf(stdout, "%s%s\n", relativePath, reason)
		}
	}

	fmt.Fprintln(stdout, "\nReminder: keep docs up to date as behavior changes. When your task matches any \"Read when\" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing.")
}

// compactStrings filters out empty or nil values and trims whitespace
func compactStrings(values []string) []string {
	var result []string
	for _, value := range values {
		if value == "" {
			continue
		}
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

// walkMarkdownFiles recursively finds all .md files, excluding hidden files and directories in EXCLUDED_DIRS
func walkMarkdownFiles(dir string, base string) []string {
	var files []string
	entries, err := os.ReadDir(dir)
	if err != nil {
		return files
	}

	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}

		fullPath := filepath.Join(dir, entry.Name())

		if entry.IsDir() {
			if EXCLUDED_DIRS[entry.Name()] {
				continue
			}
			files = append(files, walkMarkdownFiles(fullPath, base)...)
		} else if strings.HasSuffix(entry.Name(), ".md") {
			relPath, _ := filepath.Rel(base, fullPath)
			files = append(files, relPath)
		}
	}
	return files
}

type Metadata struct {
	summary  string
	readWhen []string
	error    string
}

// extractMetadata parses YAML front matter from a markdown file
func extractMetadata(fullPath string) Metadata {
	contentBytes, err := os.ReadFile(fullPath)
	if err != nil {
		return Metadata{error: "failed to read file"}
	}
	content := string(contentBytes)

	if !strings.HasPrefix(content, "---") {
		return Metadata{readWhen: []string{}, error: "missing front matter"}
	}

	endIndex := strings.Index(content[3:], "\n---")
	if endIndex == -1 {
		return Metadata{readWhen: []string{}, error: "unterminated front matter"}
	}
	endIndex += 3 // Adjust for slice offset

	frontMatter := strings.TrimSpace(content[3:endIndex])
	lines := strings.Split(frontMatter, "\n")

	var summaryLine string
	var readWhen []string
	collectingField := ""

	for _, rawLine := range lines {
		line := strings.TrimSpace(rawLine)

		if strings.HasPrefix(line, "summary:") {
			summaryLine = line
			collectingField = ""
			continue
		}

		if strings.HasPrefix(line, "read_when:") {
			collectingField = "read_when"
			inline := strings.TrimSpace(strings.TrimPrefix(line, "read_when:"))
			if strings.HasPrefix(inline, "[") && strings.HasSuffix(inline, "]") {
				// Convert single quotes to double quotes for valid JSON parsing
				jsonStr := strings.ReplaceAll(inline, "'", "\"")
				parsed := parseStringArray(jsonStr)
				if parsed != nil {
					readWhen = append(readWhen, compactStrings(parsed)...)
				}
			}
			continue
		}

		if collectingField == "read_when" {
			if strings.HasPrefix(line, "- ") {
				hint := strings.TrimSpace(strings.TrimPrefix(line, "- "))
				if hint != "" {
					readWhen = append(readWhen, hint)
				}
			} else if line == "" {
				// Allow blank lines inside the list
			} else {
				collectingField = ""
			}
		}
	}

	if summaryLine == "" {
		return Metadata{readWhen: readWhen, error: "summary key missing"}
	}

	summaryValue := strings.TrimSpace(strings.TrimPrefix(summaryLine, "summary:"))
	// Remove surrounding quotes and normalize spaces
	normalized := strings.TrimSpace(regexp.MustCompile(`^['"]|['"]$`).ReplaceAllString(summaryValue, ""))
	normalized = regexp.MustCompile(`\s+`).ReplaceAllString(normalized, " ")

	if normalized == "" {
		return Metadata{readWhen: readWhen, error: "summary is empty"}
	}

	return Metadata{summary: normalized, readWhen: readWhen}
}

// Helper function to parse string array from JSON-like format
func parseStringArray(s string) []string {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, "[") || !strings.HasSuffix(s, "]") {
		return nil
	}

	// Remove brackets
	s = s[1 : len(s)-1]
	if s == "" {
		return []string{}
	}

	// Split by comma and clean each element
	parts := strings.Split(s, ",")
	var result []string
	for _, part := range parts {
		// Trim space and remove quotes
		cleaned := strings.TrimSpace(part)
		cleaned = strings.Trim(cleaned, "'\"")
		if cleaned != "" {
			result = append(result, cleaned)
		}
	}
	return result
}
