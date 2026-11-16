// abstraction-provenance: {"artifact_sha256": "2822d3d4945f11eeefbf8413fcba2bf9d3cbab85d0b05255cdc4be42fe76c787", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "go"}
// changelog.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: changelog.go <command> [args...]")
		os.Exit(1)
	}

	command := os.Args[1]
	switch command {
	case "normalize_pr_changelog_entries":
		if len(os.Args) < 3 {
			fmt.Println("Missing PR number")
			os.Exit(1)
		}
		normalizePRChangelogEntries(os.Args[2])
	case "validate_changelog_entry_for_pr":
		if len(os.Args) < 4 {
			fmt.Println("Missing PR number and contributor")
			os.Exit(1)
		}
		validateChangelogEntryForPR(os.Args[2], os.Args[3])
	case "validate_changelog_merge_hygiene":
		validateChangelogMergeHygiene()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		os.Exit(1)
	}
}

func normalizePRChangelogEntries(pr string) {
	changelogPath := "CHANGELOG.md"
	if _, err := os.Stat(changelogPath); os.IsNotExist(err) {
		return
	}

	content, err := os.ReadFile(changelogPath)
	if err != nil {
		fmt.Printf("Error reading %s: %v\n", changelogPath, err)
		os.Exit(1)
	}

	lines := strings.Split(string(content), "\n")
	prPattern := regexp.MustCompile(fmt.Sprintf(`(?:\(#%s\)|openclaw#%s)`, pr, pr))

	findActiveSectionIndex := func(arr []string) int {
		for i, line := range arr {
			if strings.TrimSpace(line) == "## Unreleased" {
				return i
			}
		}
		return -1
	}

	findSectionEnd := func(arr []string, start int) int {
		for i := start + 1; i < len(arr); i++ {
			if regexp.MustCompile(`^## `).MatchString(arr[i]) {
				return i
			}
		}
		return len(arr)
	}

	ensureActiveSection := func(arr *[]string) int {
		activeIndex := findActiveSectionIndex(*arr)
		if activeIndex != -1 {
			return activeIndex
		}

		insertAt := -1
		for i, line := range *arr {
			if i > 0 && regexp.MustCompile(`^## `).MatchString(line) {
				insertAt = i
				break
			}
		}
		if insertAt == -1 {
			insertAt = len(*arr)
		}

		block := []string{"## Unreleased", "", "### Changes", ""}
		if insertAt > 0 && (*arr)[insertAt-1] != "" {
			block = append([]string{""}, block...)
		}
		*arr = append((*arr)[:insertAt], append(block, (*arr)[insertAt:]...)...)
		return findActiveSectionIndex(*arr)
	}

	contextFor := func(arr []string, index int) map[string]string {
		major := ""
		minor := ""
		for i := index; i >= 0; i-- {
			line := arr[i]
			if minor == "" && regexp.MustCompile(`^### `).MatchString(line) {
				minor = strings.TrimSpace(line)
			}
			if regexp.MustCompile(`^## `).MatchString(line) {
				major = strings.TrimSpace(line)
				break
			}
		}
		return map[string]string{"major": major, "minor": minor}
	}

	ensureSubsection := func(arr *[]string, subsection string) int {
		activeIndex := ensureActiveSection(arr)
		activeEnd := findSectionEnd(*arr, activeIndex)
		desired := "### Changes"
		if subsection != "" && regexp.MustCompile(`^### `).MatchString(subsection) {
			desired = subsection
		}
		for i := activeIndex + 1; i < activeEnd; i++ {
			if strings.TrimSpace((*arr)[i]) == desired {
				return i
			}
		}

		insertAt := activeEnd
		for insertAt > activeIndex+1 && (*arr)[insertAt-1] == "" {
			insertAt--
		}
		block := []string{"", desired, ""}
		*arr = append((*arr)[:insertAt], append(block, (*arr)[insertAt:]...)...)
		return insertAt + 1
	}

	sectionTailInsertIndex := func(arr []string, subsectionIndex int) int {
		nextHeading := len(arr)
		for i := subsectionIndex + 1; i < len(arr); i++ {
			if regexp.MustCompile(`^### `).MatchString(arr[i]) || regexp.MustCompile(`^## `).MatchString(arr[i]) {
				nextHeading = i
				break
			}
		}

		insertAt := nextHeading
		for insertAt > subsectionIndex+1 && arr[insertAt-1] == "" {
			insertAt--
		}
		return insertAt
	}

	ensureActiveSection(&lines)

	type movedEntry struct {
		line       string
		subsection string
		index      int
	}

	moved := []movedEntry{}
	for i, line := range lines {
		if !prPattern.MatchString(line) {
			continue
		}
		ctx := contextFor(lines, i)
		if ctx["major"] == "## Unreleased" {
			continue
		}
		subsection := "### Changes"
		if ctx["minor"] != "" {
			subsection = ctx["minor"]
		}
		moved = append(moved, movedEntry{
			line:       line,
			subsection: subsection,
			index:      i,
		})
	}

	if len(moved) == 0 {
		os.Exit(0)
	}

	removeIndexes := make(map[int]bool)
	for _, entry := range moved {
		removeIndexes[entry.index] = true
	}

	nextLines := []string{}
	for i, line := range lines {
		if !removeIndexes[i] {
			nextLines = append(nextLines, line)
		}
	}

	for _, entry := range moved {
		subsectionIndex := ensureSubsection(&nextLines, entry.subsection)
		insertAt := sectionTailInsertIndex(nextLines, subsectionIndex)

		nextHeading := len(nextLines)
		for i := subsectionIndex + 1; i < len(nextLines); i++ {
			if regexp.MustCompile(`^### `).MatchString(nextLines[i]) || regexp.MustCompile(`^## `).MatchString(nextLines[i]) {
				nextHeading = i
				break
			}
		}

		alreadyPresent := false
		for i := subsectionIndex + 1; i < nextHeading; i++ {
			if nextLines[i] == entry.line {
				alreadyPresent = true
				break
			}
		}
		if !alreadyPresent {
			nextLines = append(nextLines[:insertAt], append([]string{entry.line}, nextLines[insertAt:]...)...)
		}
	}

	updated := strings.Join(nextLines, "\n")
	if updated != string(content) {
		err := os.WriteFile(changelogPath, []byte(updated), 0644)
		if err != nil {
			fmt.Printf("Error writing %s: %v\n", changelogPath, err)
			os.Exit(1)
		}
	}
}

func validateChangelogEntryForPR(pr, contrib string) {
	cmd := exec.Command("git", "diff", "--unified=0", "origin/main...HEAD", "--", "CHANGELOG.md")
	output, err := cmd.Output()
	if err != nil {
		fmt.Printf("Error running git diff: %v\n", err)
		os.Exit(1)
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	addedLines := []string{}
	inAdded := false
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "+++ ") {
			continue
		}
		if strings.HasPrefix(line, "+") {
			addedLines = append(addedLines, strings.TrimPrefix(line, "+"))
			inAdded = true
		} else if inAdded {
			inAdded = false
		}
	}

	if len(addedLines) == 0 {
		fmt.Println("CHANGELOG.md is in diff but no added lines were detected.")
		os.Exit(1)
	}

	prPattern := fmt.Sprintf(`(#%s|openclaw#%s)`, pr, pr)
	foundPR := false
	for _, line := range addedLines {
		if matched, _ := regexp.MatchString(prPattern, line); matched {
			foundPR = true
			break
		}
	}
	if !foundPR {
		fmt.Printf("CHANGELOG.md update must reference PR #%s (for example, (#%s)).\n", pr, pr)
		os.Exit(1)
	}

	tmpFile, err := os.CreateTemp("", "changelog_diff")
	if err != nil {
		fmt.Printf("Error creating temp file: %v\n", err)
		os.Exit(1)
	}
	defer os.Remove(tmpFile.Name())

	_, err = tmpFile.Write(output)
	if err != nil {
		fmt.Printf("Error writing to temp file: %v\n", err)
		os.Exit(1)
	}
	tmpFile.Close()

	validateChangelogPlacement(prPattern, tmpFile.Name())

	if contrib != "" && contrib != "null" {
		foundPRAndThanks := false
		for _, line := range addedLines {
			if matched, _ := regexp.MatchString(prPattern, line); matched {
				if matched, _ := regexp.MatchString(fmt.Sprintf(`(?i)thanks @%s`, contrib), line); matched {
					foundPRAndThanks = true
					break
				}
			}
		}
		if !foundPRAndThanks {
			fmt.Printf("CHANGELOG.md update must include both PR #%s and thanks @%s on the changelog entry line.\n", pr, contrib)
			os.Exit(1)
		}
		fmt.Printf("changelog validated: found PR #%s + thanks @%s\n", pr, contrib)
		return
	}

	fmt.Printf("changelog validated: found PR #%s (contributor handle unavailable, skipping thanks check)\n", pr)
}

func validateChangelogPlacement(prPattern, diffFile string) {
	fileContent, err := os.ReadFile("CHANGELOG.md")
	if err != nil {
		fmt.Printf("Error reading CHANGELOG.md: %v\n", err)
		os.Exit(1)
	}

	diffContent, err := os.ReadFile(diffFile)
	if err != nil {
		fmt.Printf("Error reading diff file: %v\n", err)
		os.Exit(1)
	}

	type addedLine struct {
		lineNo int
		text   string
	}
	added := make(map[int]*addedLine)
	prAddedLines := []int{}
	prAddedText := make(map[int]string)

	// Parse diff to get added lines
	scanner := bufio.NewScanner(strings.NewReader(string(diffContent)))
	lineNo := 0
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "@@ ") {
			re := regexp.MustCompile(`\+([0-9]+)`)
			matches := re.FindStringSubmatch(line)
			if len(matches) > 1 {
				lineNo, _ = strconv.Atoi(matches[1])
			} else {
				lineNo = 0
			}
			continue
		}
		if strings.HasPrefix(line, "+++ ") {
			continue
		}
		if strings.HasPrefix(line, "+") {
			if lineNo > 0 {
				added[lineNo] = &addedLine{lineNo: lineNo, text: strings.TrimPrefix(line, "+")}
				addedText := strings.TrimPrefix(line, "+")
				re := regexp.MustCompile(prPattern)
				if re.MatchString(addedText) {
					prAddedLines = append(prAddedLines, lineNo)
					prAddedText[lineNo] = addedText
				}
				lineNo++
			}
			continue
		}
		if strings.HasPrefix(line, "-") {
			continue
		}
		if lineNo > 0 {
			lineNo++
		}
	}

	// Read changelog file into array
	changelog := strings.Split(string(fileContent), "\n")
	fileLineCount := len(changelog)

	issueCount := 0
	for _, entryLine := range prAddedLines {
		releaseLine := 0
		sectionLine := 0
		
		// Find section boundaries
		for i := entryLine; i >= 1; i-- {
			if i > len(changelog) {
				continue
			}
			line := changelog[i-1]
			if sectionLine == 0 && regexp.MustCompile(`^### `).MatchString(line) {
				sectionLine = i
				continue
			}
			if regexp.MustCompile(`^## `).MatchString(line) {
				releaseLine = i
				break
			}
		}
		
		if releaseLine == 0 || (releaseLine <= len(changelog) && changelog[releaseLine-1] != "## Unreleased") {
			fmt.Printf("CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\n", entryLine, prAddedText[entryLine])
			issueCount++
			continue
		}
		if sectionLine == 0 {
			fmt.Printf("CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\n", entryLine, prAddedText[entryLine])
			issueCount++
			continue
		}

		sectionName := changelog[sectionLine-1]
		nextHeading := fileLineCount + 1
		for i := entryLine + 1; i <= fileLineCount; i++ {
			if i > len(changelog) {
				continue
			}
			if regexp.MustCompile(`^### `).MatchString(changelog[i-1]) || regexp.MustCompile(`^## `).MatchString(changelog[i-1]) {
				nextHeading = i
				break
			}
		}

		for i := entryLine + 1; i < nextHeading; i++ {
			if i > len(changelog) {
				continue
			}
			lineText := changelog[i-1]
			if regexp.MustCompile(`^[[:space:]]*$`).MatchString(lineText) {
				continue
			}
			if _, exists := added[i]; exists {
				continue
			}
			fmt.Printf("CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\n", sectionName, entryLine, prAddedText[entryLine])
			fmt.Printf("Found existing non-added line below it at line %d: %s\n", i, lineText)
			issueCount++
			break
		}
	}

	if issueCount > 0 {
		fmt.Println("Move this PR changelog entry to the end of its section (just before the next heading).")
		os.Exit(1)
	}
	
	fmt.Println("changelog placement validated: PR-linked entries are appended at section tail")
}

func validateChangelogMergeHygiene() {
	cmd := exec.Command("git", "diff", "--unified=0", "origin/main...HEAD", "--", "CHANGELOG.md")
	output, err := cmd.Output()
	if err != nil {
		return
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	removedLines := []string{}
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "---") {
			continue
		}
		if strings.HasPrefix(line, "-") {
			removedLines = append(removedLines, strings.TrimPrefix(line, "-"))
		}
	}

	if len(removedLines) == 0 {
		return
	}

	removedRefs := []string{}
	refRegex := regexp.MustCompile(`#[0-9]+`)
	for _, line := range removedLines {
		matches := refRegex.FindAllString(line, -1)
		removedRefs = append(removedRefs, matches...)
	}
	
	if len(removedRefs) == 0 {
		return
	}

	// Remove duplicates and sort
	uniqueRefs := make(map[string]bool)
	for _, ref := range removedRefs {
		uniqueRefs[ref] = true
	}
	sortedRefs := []string{}
	for ref := range uniqueRefs {
		sortedRefs = append(sortedRefs, ref)
	}
	sort.Strings(sortedRefs)

	addedLines := []string{}
	scanner = bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "+++ ") {
			continue
		}
		if strings.HasPrefix(line, "+") {
			addedLines = append(addedLines, strings.TrimPrefix(line, "+"))
		}
	}

	for _, ref := range sortedRefs {
		found := false
		for _, line := range addedLines {
			if strings.Contains(line, ref) {
				found = true
				break
			}
		}
		if !found {
			fmt.Printf("CHANGELOG.md drops existing entry reference %s without re-adding it.\n", ref)
			fmt.Println("Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).")
			os.Exit(1)
		}
	}

	fmt.Println("changelog merge hygiene validated: no dropped PR references")
}
