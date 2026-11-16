// abstraction-provenance: {"artifact_sha256": "51445270ff94d56ed9d47b4f3321ae5a0820a0d6a9f66a4836f925336388bcfb", "source_sha256": "e290d06e27f18dbd9a54def6168fe32ba54f3cdb01ec2175510727f412ff6a70", "target_language": "go"}
// check-docs-i18n-glossary.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-docs-i18n-glossary.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const (
	ROOT             = "."
	GLOSSARY_PATH    = "docs/.i18n/glossary.zh-CN.json"
	MAX_TITLE_WORDS  = 8
	MAX_LABEL_WORDS  = 6
	MAX_TERM_LENGTH  = 80
)

var (
	DOC_FILE_RE       = regexp.MustCompile(`^docs/(?!zh-CN/).+\.(md|mdx)$`)
	LIST_ITEM_LINK_RE = regexp.MustCompile(`^\s*(?:[-*]|\d+\.)\s+\[([^\]]+)\]\((\/[^)]+)\)`)
)

type Args struct {
	Base string
	Head string
}

type GlossaryEntry struct {
	Source interface{} `json:"source"`
}

type TermMatch struct {
	File string
	Line int
	Kind string
	Term string
}

func parseArgs(args []string) Args {
	result := Args{}
	for i := 0; i < len(args); i++ {
		if args[i] == "--base" {
			if i+1 < len(args) {
				result.Base = args[i+1]
				i++
			}
			continue
		}
		if args[i] == "--head" {
			if i+1 < len(args) {
				result.Head = args[i+1]
				i++
			}
		}
	}
	return result
}

func runGit(args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = ROOT
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func resolveBase(explicitBase string) string {
	if explicitBase != "" {
		return explicitBase
	}

	envBase := os.Getenv("DOCS_I18N_GLOSSARY_BASE")
	envBase = strings.TrimSpace(envBase)
	if envBase != "" {
		return envBase
	}

	candidates := []string{"origin/main", "fork/main", "main"}
	for _, candidate := range candidates {
		if output, err := runGit("merge-base", candidate, "HEAD"); err == nil {
			return output
		}
	}

	return ""
}

func listChangedDocs(base, head string) ([]string, error) {
	args := []string{"diff", "--name-only", "--diff-filter=ACMR", base}
	if head != "" {
		args = append(args, head)
	}
	args = append(args, "--", "docs")

	output, err := runGit(args...)
	if err != nil {
		return nil, err
	}

	lines := strings.Split(output, "\n")
	var result []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if DOC_FILE_RE.MatchString(line) {
			result = append(result, line)
		}
	}
	return result, nil
}

func loadGlossarySources() (map[string]bool, error) {
	data, err := os.ReadFile(GLOSSARY_PATH)
	if err != nil {
		return nil, err
	}

	var entries []GlossaryEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, err
	}

	result := make(map[string]bool)
	for _, entry := range entries {
		source := ""
		if entry.Source != nil {
			source = fmt.Sprintf("%v", entry.Source)
		}
		source = strings.TrimSpace(source)
		if source != "" {
			result[source] = true
		}
	}
	return result, nil
}

func containsLatin(text string) bool {
	for _, r := range text {
		if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
			return true
		}
	}
	return false
}

func wordCount(text string) int {
	text = strings.TrimSpace(text)
	if text == "" {
		return 0
	}
	parts := strings.Fields(text)
	return len(parts)
}

func unquoteScalar(raw string) string {
	value := strings.TrimSpace(raw)
	if len(value) >= 2 {
		if (value[0] == '"' && value[len(value)-1] == '"') ||
			(value[0] == '\'' && value[len(value)-1] == '\'') {
			return strings.TrimSpace(value[1 : len(value)-1])
		}
	}
	return value
}

func isGlossaryCandidate(term string, maxWords int) bool {
	if term == "" {
		return false
	}
	if !containsLatin(term) {
		return false
	}
	if strings.Contains(term, "`") {
		return false
	}
	if len(term) > MAX_TERM_LENGTH {
		return false
	}
	return wordCount(term) <= maxWords
}

func readGitFile(base, relPath string) string {
	output, err := runGit("show", base+":"+relPath)
	if err != nil {
		return ""
	}
	return output
}

func extractTerms(file, text string) map[string]TermMatch {
	terms := make(map[string]TermMatch)
	lines := strings.Split(text, "\n")

	if len(lines) > 0 && strings.TrimSpace(lines[0]) == "---" {
		for index := 1; index < len(lines); index++ {
			line := lines[index]
			if strings.TrimSpace(line) == "---" {
				break
			}

			matches := regexp.MustCompile(`^title:\s*(.+)\s*$`).FindStringSubmatch(line)
			if matches == nil {
				continue
			}

			title := unquoteScalar(matches[1])
			if isGlossaryCandidate(title, MAX_TITLE_WORDS) {
				terms[title] = TermMatch{
					File: file,
					Line: index + 1,
					Kind: "title",
					Term: title,
				}
			}
			break
		}
	}

	for index, line := range lines {
		matches := LIST_ITEM_LINK_RE.FindStringSubmatch(line)
		if matches == nil {
			continue
		}

		label := strings.TrimSpace(matches[1])
		if !isGlossaryCandidate(label, MAX_LABEL_WORDS) {
			continue
		}

		if _, exists := terms[label]; !exists {
			terms[label] = TermMatch{
				File: file,
				Line: index + 1,
				Kind: "link label",
				Term: label,
			}
		}
	}

	return terms
}

func main() {
	args := parseArgs(os.Args[1:])
	base := resolveBase(args.Base)

	if base == "" {
		fmt.Fprintln(os.Stderr, "docs:check-i18n-glossary: no merge base found; skipping glossary coverage check.")
		os.Exit(0)
	}

	changedDocs, err := listChangedDocs(base, args.Head)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing changed docs: %v\n", err)
		os.Exit(1)
	}

	if len(changedDocs) == 0 {
		os.Exit(0)
	}

	glossary, err := loadGlossarySources()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading glossary: %v\n", err)
		os.Exit(1)
	}

	var missing []TermMatch

	for _, relPath := range changedDocs {
		absPath := filepath.Join(ROOT, relPath)
		if _, err := os.Stat(absPath); os.IsNotExist(err) {
			continue
		}

		currentData, err := os.ReadFile(absPath)
		if err != nil {
			continue
		}
		currentTerms := extractTerms(relPath, string(currentData))

		baseText := readGitFile(base, relPath)
		baseTerms := extractTerms(relPath, baseText)

		for term, match := range currentTerms {
			if _, exists := baseTerms[term]; exists {
				continue
			}
			if glossary[term] {
				continue
			}
			missing = append(missing, match)
		}
	}

	if len(missing) == 0 {
		os.Exit(0)
	}

	fmt.Fprintln(os.Stderr, "docs:check-i18n-glossary: missing zh-CN glossary entries for changed doc labels:")
	for _, match := range missing {
		fmt.Fprintf(os.Stderr, "- %s:%d %s \"%s\"\n", match.File, match.Line, match.Kind, match.Term)
	}
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Add exact source terms to docs/.i18n/glossary.zh-CN.json before rerunning docs-i18n.")
	fmt.Fprintf(os.Stderr, "Checked changed English docs relative to %s.\n", base)
	os.Exit(1)
}
