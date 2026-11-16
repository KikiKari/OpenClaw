// abstraction-provenance: {"artifact_sha256": "bdfb632e2bd234f18bba8e89e691e46984566833c646d8f75fa64042b4bb9e36", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "go"}
// changelog-to-html.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func main() {
	var version string
	var changelogFile string

	if len(os.Args) > 1 {
		version = os.Args[1]
	} else {
		fmt.Fprintln(os.Stderr, "Usage: changelog-to-html <version> [changelog_file]")
		os.Exit(1)
	}

	if len(os.Args) > 2 {
		changelogFile = os.Args[2]
	} else {
		scriptDir := filepath.Dir(os.Args[0])
		possiblePaths := []string{
			filepath.Join(scriptDir, "..", "CHANGELOG.md"),
			"CHANGELOG.md",
			filepath.Join("..", "CHANGELOG.md"),
		}
		for _, path := range possiblePaths {
			if _, err := os.Stat(path); err == nil {
				changelogFile = path
				break
			}
		}
		if changelogFile == "" {
			fmt.Fprintln(os.Stderr, "Error: Could not find CHANGELOG.md")
			os.Exit(1)
		}
	}

	if _, err := os.Stat(changelogFile); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Changelog file '%s' not found\n", changelogFile)
		os.Exit(1)
	}

	versionContent := extractVersionSection(version, changelogFile)
	if versionContent == "" {
		fmt.Printf("<h2>OpenClaw %s</h2>\n", version)
		fmt.Println("<p>Latest OpenClaw update.</p>")
		fmt.Println("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")
		return
	}

	fmt.Printf("<h2>OpenClaw %s</h2>\n", version)

	inList := false
	scanner := bufio.NewScanner(strings.NewReader(versionContent))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "-") {
			if !inList {
				fmt.Println("<ul>")
				inList = true
			}
			fmt.Println(markdownToHTML(line))
		} else {
			if inList {
				fmt.Println("</ul>")
				inList = false
			}
			if strings.TrimSpace(line) != "" {
				fmt.Println(markdownToHTML(line))
			}
		}
	}

	if inList {
		fmt.Println("</ul>")
	}

	fmt.Println("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")
}

func extractVersionSection(version string, file string) string {
	f, err := os.Open(file)
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	found := false
	var content strings.Builder
	versionRegex := regexp.MustCompile(fmt.Sprintf(`^##\s+%s(\s.*)?$`, regexp.QuoteMeta(version)))

	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "## ") {
			if versionRegex.MatchString(line) {
				found = true
				continue
			}
			if found {
				break
			}
		} else if found {
			content.WriteString(line + "\n")
		}
	}

	if !found {
		return ""
	}
	return strings.TrimSpace(content.String())
}

func markdownToHTML(text string) string {
	// Convert headers
	text = regexp.MustCompile(`^##### (.*)$`).ReplaceAllString(text, "<h5>$1</h5>")
	text = regexp.MustCompile(`^#### (.*)$`).ReplaceAllString(text, "<h4>$1</h4>")
	text = regexp.MustCompile(`^### (.*)$`).ReplaceAllString(text, "<h3>$1</h3>")
	text = regexp.MustCompile(`^## (.*)$`).ReplaceAllString(text, "<h2>$1</h2>")

	// Convert list items with bold text
	text = regexp.MustCompile(`^- \*\*([^*]*)\*\*(.*)$`).ReplaceAllString(text, "<li><strong>$1</strong>$2</li>")

	// Convert regular list items
	text = regexp.MustCompile(`^- ([^*].*)$`).ReplaceAllString(text, "<li>$1</li>")

	// Convert bold text
	text = regexp.MustCompile(`\*\*([^*]*)\*\*`).ReplaceAllString(text, "<strong>$1</strong>")

	// Convert inline code
	text = regexp.MustCompile("`([^`]*)`").ReplaceAllString(text, "<code>$1</code>")

	// Convert links
	text = regexp.MustCompile(`\[([^\]]*)\]\(([^)]*)\)`).ReplaceAllString(text, `<a href="$2">$1</a>`)

	return text
}
