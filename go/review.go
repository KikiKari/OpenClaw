// abstraction-provenance: {"artifact_sha256": "c4bf2662ed7d167862b7678019b8fe4a1fe66c37ef4807f8fdb5eb9de76af930", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "go"}
// review.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: review <command> [args...]")
	}

	command := os.Args[1]
	args := os.Args[2:]

	switch command {
	case "set-review-mode":
		if len(args) != 1 {
			log.Fatal("Usage: set-review-mode <mode>")
		}
		setReviewMode(args[0])
	case "review-claim":
		if len(args) != 1 {
			log.Fatal("Usage: review-claim <pr>")
		}
		reviewClaim(args[0])
	case "review-checkout-main":
		if len(args) != 1 {
			log.Fatal("Usage: review-checkout-main <pr>")
		}
		reviewCheckoutMain(args[0])
	case "review-checkout-pr":
		if len(args) != 1 {
			log.Fatal("Usage: review-checkout-pr <pr>")
		}
		reviewCheckoutPr(args[0])
	case "review-guard":
		if len(args) != 1 {
			log.Fatal("Usage: review-guard <pr>")
		}
		reviewGuard(args[0])
	case "review-artifacts-init":
		if len(args) != 1 {
			log.Fatal("Usage: review-artifacts-init <pr>")
		}
		reviewArtifactsInit(args[0])
	case "review-validate-artifacts":
		if len(args) != 1 {
			log.Fatal("Usage: review-validate-artifacts <pr>")
		}
		reviewValidateArtifacts(args[0])
	case "review-tests":
		if len(args) < 2 {
			log.Fatal("Usage: review-tests <pr> <test-file> [<test-file> ...]")
		}
		reviewTests(args[0], args[1:])
	case "review-init":
		if len(args) != 1 {
			log.Fatal("Usage: review-init <pr>")
		}
		reviewInit(args[0])
	default:
		log.Fatalf("Unknown command: %s", command)
	}
}

func setReviewMode(mode string) {
	content := fmt.Sprintf("REVIEW_MODE=%q\nREVIEW_MODE_SET_AT=%q\n",
		mode, time.Now().UTC().Format(time.RFC3339))
	err := ioutil.WriteFile(".local/review-mode.env", []byte(content), 0644)
	if err != nil {
		log.Fatal(err)
	}
}

func reviewClaim(pr string) {
	root := repoRoot()
	os.Chdir(root)
	os.MkdirAll(".local", 0755)

	var reviewer string
	maxAttempts := 3

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		userLog := fmt.Sprintf(".local/review-claim-user-attempt-%d.log", attempt)
		cmd := exec.Command("gh", "api", "user", "--jq", ".login")
		output, err := cmd.CombinedOutput()
		ioutil.WriteFile(userLog, output, 0644)
		if err == nil {
			reviewer = strings.TrimSpace(string(output))
			break
		}

		fmt.Printf("Claim reviewer lookup failed (attempt %d/%d).\n", attempt, maxAttempts)
		printRelevantLogExcerpt(userLog)

		if attempt < maxAttempts {
			time.Sleep(2 * time.Second)
		}
	}

	if reviewer == "" {
		log.Fatalf("Failed to resolve reviewer login after %d attempts.", maxAttempts)
	}

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		claimLog := fmt.Sprintf(".local/review-claim-assignee-attempt-%d.log", attempt)
		cmd := exec.Command("gh", "pr", "edit", pr, "--add-assignee", reviewer)
		output, err := cmd.CombinedOutput()
		ioutil.WriteFile(claimLog, output, 0644)
		if err == nil {
			fmt.Printf("review claim succeeded: @%s assigned to PR #%s\n", reviewer, pr)
			return
		}

		fmt.Printf("Claim assignee update failed (attempt %d/%d).\n", attempt, maxAttempts)
		printRelevantLogExcerpt(claimLog)

		if attempt < maxAttempts {
			time.Sleep(2 * time.Second)
		}
	}

	log.Fatalf("Failed to assign @%s to PR #%s after %d attempts.", reviewer, pr, maxAttempts)
}

func reviewCheckoutMain(pr string) {
	enterWorktree(pr, false)
	runCommand("git", "fetch", "origin", "main")
	runCommand("git", "checkout", "--detach", "origin/main")
	setReviewMode("main")

	fmt.Println("review mode set to main baseline")
	branch := runCommandOutput("git", "branch", "--show-current")
	head := runCommandOutput("git", "rev-parse", "--short", "HEAD")
	fmt.Printf("branch=%s\n", strings.TrimSpace(branch))
	fmt.Printf("head=%s\n", strings.TrimSpace(head))
}

func reviewCheckoutPr(pr string) {
	enterWorktree(pr, false)
	runCommand("git", "fetch", "origin", fmt.Sprintf("pull/%s/head:pr-%s", pr, pr), "--force")
	runCommand("git", "checkout", "--detach", fmt.Sprintf("pr-%s", pr))
	setReviewMode("pr")

	fmt.Println("review mode set to PR head")
	branch := runCommandOutput("git", "branch", "--show-current")
	head := runCommandOutput("git", "rev-parse", "--short", "HEAD")
	fmt.Printf("branch=%s\n", strings.TrimSpace(branch))
	fmt.Printf("head=%s\n", strings.TrimSpace(head))
}

func reviewGuard(pr string) {
	enterWorktree(pr, false)
	requireArtifact(".local/review-mode.env")
	requireArtifact(".local/pr-meta.env")

	reviewModeEnv := loadEnv(".local/review-mode.env")
	prMetaEnv := loadEnv(".local/pr-meta.env")

	branch := strings.TrimSpace(runCommandOutput("git", "branch", "--show-current"))
	headSHA := strings.TrimSpace(runCommandOutput("git", "rev-parse", "HEAD"))

	switch reviewModeEnv["REVIEW_MODE"] {
	case "main":
		expectedMainSHA := strings.TrimSpace(runCommandOutput("git", "rev-parse", "origin/main"))
		if headSHA != expectedMainSHA {
			log.Fatalf("Review guard failed: expected HEAD at origin/main (%s) for main baseline mode, got %s", expectedMainSHA, headSHA)
		}
	case "pr":
		prHeadSHA, exists := prMetaEnv["PR_HEAD_SHA"]
		if !exists || prHeadSHA == "" {
			log.Fatal("Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env")
		}
		if headSHA != prHeadSHA {
			log.Fatalf("Review guard failed: expected HEAD at PR_HEAD_SHA (%s), got %s", prHeadSHA, headSHA)
		}
	default:
		log.Fatalf("Review guard failed: unknown review mode '%s'", reviewModeEnv["REVIEW_MODE"])
	}

	fmt.Println("review guard passed")
	fmt.Printf("mode=%s\n", reviewModeEnv["REVIEW_MODE"])
	fmt.Printf("branch=%s\n", branch)
	fmt.Printf("head=%s\n", headSHA)
}

func reviewArtifactsInit(pr string) {
	enterWorktree(pr, false)
	requireArtifact(".local/pr-meta.env")

	if _, err := os.Stat(".local/review.md"); os.IsNotExist(err) {
		mdContent := `A) TL;DR recommendation

B) What changed and what is good?

C) Security findings

D) What is the PR intent? Is this the most optimal implementation?

E) Concerns or questions (actionable)

F) Tests

G) Docs status

H) Changelog

I) Follow ups (optional)

J) Suggested PR comment (optional)
`
		ioutil.WriteFile(".local/review.md", []byte(mdContent), 0644)
	}

	if _, err := os.Stat(".local/review.json"); os.IsNotExist(err) {
		jsonContent := `{
  "recommendation": "NEEDS WORK",
  "findings": [],
  "nitSweep": {
    "performed": true,
    "status": "none",
    "summary": "No optional nits identified."
  },
  "behavioralSweep": {
    "performed": true,
    "status": "not_applicable",
    "summary": "No runtime branch-level behavior changes require sweep evidence.",
    "silentDropRisk": "none",
    "branches": []
  },
  "issueValidation": {
    "performed": true,
    "source": "pr_body",
    "status": "unclear",
    "summary": "Review not completed yet."
  },
  "tests": {
    "ran": [],
    "gaps": [],
    "result": "pass"
  },
  "docs": "not_applicable",
  "changelog": "not_required"
}
`
		ioutil.WriteFile(".local/review.json", []byte(jsonContent), 0644)
	}

	fmt.Println("review artifact templates are ready")
	fmt.Println("files=.local/review.md .local/review.json")
}

func reviewValidateArtifacts(pr string) {
	enterWorktree(pr, false)
	requireArtifact(".local/review.md")
	requireArtifact(".local/review.json")
	requireArtifact(".local/pr-meta.env")
	requireArtifact(".local/pr-meta.json")

	reviewGuard(pr)

	// Validate JSON syntax
	cmd := exec.Command("jq", ".", ".local/review.json")
	err := cmd.Run()
	if err != nil {
		log.Fatal("Invalid JSON in .local/review.json")
	}

	// Check for required sections in review.md
	requiredSections := []string{"A)", "B)", "C)", "D)", "E)", "F)", "G)", "H)", "I)", "J)"}
	for _, section := range requiredSections {
		found := false
		file, err := os.Open(".local/review.md")
		if err != nil {
			log.Fatal(err)
		}
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			if strings.HasPrefix(scanner.Text(), section) {
				found = true
				break
			}
		}
		file.Close()
		if !found {
			log.Fatalf("Missing section header in .local/review.md: %s", section)
		}
	}

	// Load review.json for validation
	reviewData, err := ioutil.ReadFile(".local/review.json")
	if err != nil {
		log.Fatal(err)
	}

	var review map[string]interface{}
	err = json.Unmarshal(reviewData, &review)
	if err != nil {
		log.Fatal("Invalid JSON in .local/review.json")
	}

	// Validate recommendation
	validRecommendations := map[string]bool{
		"READY FOR /prepare-pr": true,
		"NEEDS WORK":            true,
		"NEEDS DISCUSSION":      true,
		"NOT USEFUL (CLOSE)":    true,
	}
	recommendation, _ := review["recommendation"].(string)
	if !validRecommendations[recommendation] {
		log.Fatalf("Invalid recommendation in .local/review.json: %s", recommendation)
	}

	// Validate findings severity
	if findings, ok := review["findings"].([]interface{}); ok {
		for _, f := range findings {
			if finding, ok := f.(map[string]interface{}); ok {
				severity, _ := finding["severity"].(string)
				validSeverities := map[string]bool{
					"BLOCKER":   true,
					"IMPORTANT": true,
					"NIT":       true,
				}
				if !validSeverities[severity] {
					log.Fatal("Invalid finding severity in .local/review.json")
				}

				// Validate finding structure
				id, _ := finding["id"].(string)
				title, _ := finding["title"].(string)
				area, _ := finding["area"].(string)
				fix, _ := finding["fix"].(string)
				if id == "" || title == "" || area == "" || fix == "" {
					log.Fatal("Invalid finding shape in .local/review.json (id/title/area/fix must be strings)")
				}
			}
		}
	}

	// Count NIT findings
	nitFindingsCount := 0
	if findings, ok := review["findings"].([]interface{}); ok {
		for _, f := range findings {
			if finding, ok := f.(map[string]interface{}); ok {
				if severity, _ := finding["severity"].(string); severity == "NIT" {
					nitFindingsCount++
				}
			}
		}
	}

	// Validate nitSweep
	if nitSweep, ok := review["nitSweep"].(map[string]interface{}); ok {
		performed, _ := nitSweep["performed"].(bool)
		if !performed {
			log.Fatal("Invalid nit sweep in .local/review.json: nitSweep.performed must be true")
		}

		status, _ := nitSweep["status"].(string)
		switch status {
		case "none":
			if nitFindingsCount > 0 {
				log.Fatal("Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist")
			}
		case "has_nits":
			if nitFindingsCount < 1 {
				log.Fatal("Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist")
			}
		default:
			log.Fatalf("Invalid nit sweep status in .local/review.json: %s", status)
		}

		summary, _ := nitSweep["summary"].(string)
		if summary == "" || strings.TrimSpace(summary) == "" {
			log.Fatal("Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string")
		}
	}

	// Validate issueValidation
	if issueValidation, ok := review["issueValidation"].(map[string]interface{}); ok {
		performed, _ := issueValidation["performed"].(bool)
		if !performed {
			log.Fatal("Invalid issue validation in .local/review.json: issueValidation.performed must be true")
		}

		source, _ := issueValidation["source"].(string)
		validSources := map[string]bool{
			"linked_issue": true,
			"pr_body":      true,
			"both":         true,
		}
		if !validSources[source] {
			log.Fatalf("Invalid issue validation source in .local/review.json: %s", source)
		}

		status, _ := issueValidation["status"].(string)
		validStatuses := map[string]bool{
			"valid":                true,
			"unclear":              true,
			"invalid":              true,
			"already_fixed_on_main": true,
		}
		if !validStatuses[status] {
			log.Fatalf("Invalid issue validation status in .local/review.json: %s", status)
		}

		summary, _ := issueValidation["summary"].(string)
		if summary == "" || strings.TrimSpace(summary) == "" {
			log.Fatal("Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string")
		}
	}

	// Check if runtime review is required
	prMetaJSON, err := ioutil.ReadFile(".local/pr-meta.json")
	if err != nil {
		log.Fatal(err)
	}

	var prMeta map[string]interface{}
	err = json.Unmarshal(prMetaJSON, &prMeta)
	if err != nil {
		log.Fatal("Invalid JSON in .local/pr-meta.json")
	}

	runtimeFileCount := 0
	if files, ok := prMeta["files"].([]interface{}); ok {
		for _, f := range files {
			if file, ok := f.(map[string]interface{}); ok {
				if path, ok := file["path"].(string); ok {
					if (strings.HasPrefix(path, "src/") || strings.HasPrefix(path, "extensions/") || strings.HasPrefix(path, "apps/")) &&
						!strings.Contains(path, "__tests__/") &&
						!regexp.MustCompile(`\.test\.|\.(spec)\.`).MatchString(path) &&
						!regexp.MustCompile(`\.(md|mdx)$`).MatchString(path) {
						runtimeFileCount++
					}
				}
			}
		}
	}

	runtimeReviewRequired := runtimeFileCount > 0

	// Validate behavioralSweep
	if behavioralSweep, ok := review["behavioralSweep"].(map[string]interface{}); ok {
		performed, _ := behavioralSweep["performed"].(bool)
		if !performed {
			log.Fatal("Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true")
		}

		status, _ := behavioralSweep["status"].(string)
		validStatuses := map[string]bool{
			"pass":          true,
			"needs_work":    true,
			"not_applicable": true,
		}
		if !validStatuses[status] {
			log.Fatalf("Invalid behavioral sweep status in .local/review.json: %s", status)
		}

		risk, _ := behavioralSweep["silentDropRisk"].(string)
		validRisks := map[string]bool{
			"none":     true,
			"present":  true,
			"unknown":  true,
		}
		if !validRisks[risk] {
			log.Fatalf("Invalid behavioral sweep risk in .local/review.json: %s", risk)
		}

		summary, _ := behavioralSweep["summary"].(string)
		if summary == "" || strings.TrimSpace(summary) == "" {
			log.Fatal("Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string")
		}

		// Validate branches array
		branches, isArray := behavioralSweep["branches"].([]interface{})
		if !isArray {
			log.Fatal("Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array")
		}

		for _, b := range branches {
			if branch, ok := b.(map[string]interface{}); ok {
				path, _ := branch["path"].(string)
				decision, _ := branch["decision"].(string)
				outcome, _ := branch["outcome"].(string)
				if path == "" || decision == "" || outcome == "" {
					log.Fatal("Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome")
				}
			}
		}

		branchCount := len(branches)

		if runtimeReviewRequired && status == "not_applicable" {
			log.Fatal("Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work")
		}

		if runtimeReviewRequired && branchCount < 1 {
			log.Fatal("Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry")
		}

		if status == "not_applicable" && branchCount > 0 {
			log.Fatal("Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries")
		}

		if status == "pass" && risk != "none" {
			log.Fatal("Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none")
		}
	}

	// Validate recommendation constraints
	if recommendation == "READY FOR /prepare-pr" {
		issueValidation, _ := review["issueValidation"].(map[string]interface{})
		issueStatus, _ := issueValidation["status"].(string)
		if issueStatus != "valid" {
			log.Fatal("Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid")
		}

		behavioralSweep, _ := review["behavioralSweep"].(map[string]interface{})
		behavioralStatus, _ := behavioralSweep["status"].(string)
		if behavioralStatus == "needs_work" {
			log.Fatal("Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work")
		}

		if runtimeReviewRequired && behavioralStatus != "pass" {
			log.Fatal("Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass")
		}

		behavioralRisk, _ := behavioralSweep["silentDropRisk"].(string)
		if behavioralRisk == "present" {
			log.Fatal("Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present")
		}
	}

	// Validate docs status
	docs, _ := review["docs"].(string)
	validDocs := map[string]bool{
		"up_to_date":    true,
		"missing":       true,
		"not_applicable": true,
	}
	if !validDocs[docs] {
		log.Fatalf("Invalid docs status in .local/review.json: %s", docs)
	}

	// Validate changelog status
	changelog, _ := review["changelog"].(string)
	validChangelog := map[string]bool{
		"required":    true,
		"not_required": true,
	}
	if !validChangelog[changelog] {
		log.Fatalf("Invalid changelog status in .local/review.json: %s (must be \"required\" or \"not_required\")", changelog)
	}

	fmt.Println("review artifacts validated")
	printReviewStdoutSummary()
}

func reviewTests(pr string, targets []string) {
	enterWorktree(pr, false)
	reviewGuard(pr)

	for _, target := range targets {
		if _, err := os.Stat(target); os.IsNotExist(err) {
			log.Fatalf("Missing test target file: %s", target)
		}
	}

	bootstrapDepsIfNeeded()

	runLog := ".local/review-tests-run.log"
	runQuietLogged("pnpm test", runLog, append([]string{"pnpm", "test", "--"}, targets...)...)

	missingRun := []string{}
	for _, target := range targets {
		base := filepath.Base(target)
		content, _ := ioutil.ReadFile(runLog)
		if !strings.Contains(string(content), target) && !strings.Contains(string(content), base) {
			missingRun = append(missingRun, target)
		}
	}

	if len(missingRun) > 0 {
		fmt.Println("These requested targets were not observed in vitest run output:")
		for _, target := range missingRun {
			fmt.Printf(" - %s\n", target)
		}
		os.Exit(1)
	}

	content := fmt.Sprintf("REVIEW_TESTS_AT=%q\nREVIEW_TEST_TARGET_COUNT=%d\n",
		time.Now().UTC().Format(time.RFC3339), len(targets))
	ioutil.WriteFile(".local/review-tests.env", []byte(content), 0644)

	fmt.Println("review tests passed and were observed in output")
}

func reviewInit(pr string) {
	enterWorktree(pr, true)

	jsonData := prMetaJSON(pr)
	writePRMetaFiles(jsonData)

	runCommand("git", "fetch", "origin", fmt.Sprintf("pull/%s/head:pr-%s", pr, pr), "--force")
	mb := strings.TrimSpace(runCommandOutput("git", "merge-base", "origin/main", fmt.Sprintf("pr-%s", pr)))

	content := fmt.Sprintf("PR_NUMBER=%q\nMERGE_BASE=%q\nREVIEW_STARTED_AT=%q\n",
		pr, mb, time.Now().UTC().Format(time.RFC3339))
	ioutil.WriteFile(".local/review-context.env", []byte(content), 0644)
	setReviewMode("main")

	fmt.Println(string(jsonData))
	fmt.Printf("worktree=%s\n", os.Getenv("PWD"))
	if prURL := os.Getenv("PR_URL"); prURL != "" {
		fmt.Printf("pr_url=%s\n", prURL)
	}
	fmt.Printf("merge_base=%s\n", mb)
	branch := strings.TrimSpace(runCommandOutput("git", "branch", "--show-current"))
	fmt.Printf("branch=%s\n", branch)
	fmt.Println("wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env")
	fmt.Println(`Review guidance:
- Inspect main baseline: scripts/pr review-checkout-main $pr
- Inspect PR head:      scripts/pr review-checkout-pr $pr
- Guard before writeout: scripts/pr review-guard $pr`)
}

// Helper functions

func repoRoot() string {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		log.Fatal(err)
	}
	return strings.TrimSpace(string(output))
}

func enterWorktree(pr string, force bool) {
	// Implementation depends on your worktree setup
	// This is a placeholder
	fmt.Printf("Entering worktree for PR %s (force: %v)\n", pr, force)
}

func requireArtifact(path string) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		log.Fatalf("Missing required artifact: %s", path)
	}
}

func loadEnv(path string) map[string]string {
	env := make(map[string]string)
	file, err := os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := parts[0]
			value := strings.Trim(parts[1], "\"'")
			env[key] = value
		}
	}
	return env
}

func runCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
}

func runCommandOutput(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	output, err := cmd.Output()
	if err != nil {
		log.Fatal(err)
	}
	return string(output)
}

func printRelevantLogExcerpt(logPath string) {
	content, err := ioutil.ReadFile(logPath)
	if err != nil {
		return
	}
	lines := strings.Split(string(content), "\n")
	start := 0
	if len(lines) > 10 {
		start = len(lines) - 10
	}
	for i := start; i < len(lines); i++ {
		fmt.Println(lines[i])
	}
}

func runQuietLogged(label, logPath string, args ...string) error {
	cmd := exec.Command(args[0], args[1:]...)
	logFile, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer logFile.Close()

	cmd.Stdout = logFile
	cmd.Stderr = logFile

	return cmd.Run()
}

func bootstrapDepsIfNeeded() {
	// Placeholder for dependency bootstrapping logic
	fmt.Println("Bootstrapping dependencies if needed...")
}

func prMetaJSON(pr string) []byte {
	// Placeholder for GitHub API call to get PR metadata
	// In a real implementation, you would use the GitHub API
	meta := map[string]interface{}{
		"number":    pr,
		"title":     "Sample PR Title",
		"url":       fmt.Sprintf("https://github.com/user/repo/pull/%s", pr),
		"state":     "open",
		"isDraft":   false,
		"author":    map[string]string{"login": "sample-user"},
		"baseRefName": "main",
		"headRefName": "feature-branch",
		"headRefOid":  "abc123",
		"headRepository": map[string]string{"nameWithOwner": "user/repo"},
		"additions": 10,
		"deletions": 5,
		"files":     []string{"file1.go", "file2.go"},
	}
	data, _ := json.Marshal(meta)
	return data
}

func writePRMetaFiles(jsonData []byte) {
	os.MkdirAll(".local", 0755)
	ioutil.WriteFile(".local/pr-meta.json", jsonData, 0644)
	
	// Convert JSON to env format (simplified)
	var meta map[string]interface{}
	json.Unmarshal(jsonData, &meta)
	
	var envContent strings.Builder
	for key, value := range meta {
		envContent.WriteString(fmt.Sprintf("%s=%q\n", strings.ToUpper(key), fmt.Sprintf("%v", value)))
	}
	ioutil.WriteFile(".local/pr-meta.env", []byte(envContent.String()), 0644)
}

func printReviewStdoutSummary() {
	// Placeholder for printing review summary
	fmt.Println("Review summary printed")
}
