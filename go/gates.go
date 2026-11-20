// abstraction-provenance: {"artifact_sha256": "578597a7b0de7bd21dacf19e67853bd89d30b922ce0d5a5a994cef452d08254c", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "go"}
// gates.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: gates.go <command> [args...]")
	}

	command := os.Args[1]
	args := os.Args[2:]

	switch command {
	case "run_prepare_push_retry_gates":
		if len(args) == 0 {
			runPreparePushRetryGates("false")
		} else {
			runPreparePushRetryGates(args[0])
		}
	case "prepare_gates":
		if len(args) == 0 {
			log.Fatal("prepare_gates requires a PR number")
		}
		prepareGates(args[0])
	default:
		log.Fatalf("Unknown command: %s", command)
	}
}

func runPreparePushRetryGates(docsOnly string) {
	bootstrapDepsIfNeeded()
	runQuietLogged("pnpm build (lease-retry)", ".local/lease-retry-build.log", "pnpm", "build")
	runQuietLogged("pnpm check (lease-retry)", ".local/lease-retry-check.log", "pnpm", "check")
	if docsOnly != "true" {
		runQuietLogged("pnpm test (lease-retry)", ".local/lease-retry-test.log", "pnpm", "test")
	}
}

func prepareGates(pr string) {
	enterWorktree(pr, "false")
	checkoutPrepBranch(pr)
	bootstrapDepsIfNeeded()
	requireArtifact(".local/pr-meta.env")

	// Source .local/pr-meta.env
	envVars := loadEnvFile(".local/pr-meta.env")
	for k, v := range envVars {
		os.Setenv(k, v)
	}

	changedFiles := gitDiffNameOnly("origin/main...HEAD")
	nonDocs := []string{}
	for _, path := range changedFiles {
		if !pathIsDocsish(path) {
			nonDocs = append(nonDocs, path)
		}
	}

	docsOnly := "false"
	if len(changedFiles) > 0 && len(nonDocs) == 0 {
		docsOnly = "true"
	}

	changelogRequired := "false"
	if changelogRequiredForChangedFiles(changedFiles) {
		changelogRequired = "true"
	}

	hasChangelogUpdate := containsString(changedFiles, "CHANGELOG.md")

	// Check for unsupported changelog fragments
	unsupportedRegex := regexp.MustCompile(`^changelog/fragments/`)
	unsupportedChangelogFragments := []string{}
	for _, file := range changedFiles {
		if unsupportedRegex.MatchString(file) {
			unsupportedChangelogFragments = append(unsupportedChangelogFragments, file)
		}
	}

	if len(unsupportedChangelogFragments) > 0 {
		fmt.Println("Unsupported changelog fragment files detected:")
		for _, frag := range unsupportedChangelogFragments {
			fmt.Println(frag)
		}
		fmt.Println("Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files.")
		os.Exit(1)
	}

	if changelogRequired == "true" && hasChangelogUpdate == "false" {
		fmt.Println("Missing changelog update. Add CHANGELOG.md changes.")
		os.Exit(1)
	}

	if hasChangelogUpdate == "true" {
		normalizePrChangelogEntries(pr)
	}

	if changelogRequired == "true" {
		contrib := os.Getenv("PR_AUTHOR")
		validateChangelogMergeHygiene()
		validateChangelogEntryForPr(pr, contrib)
	} else {
		fmt.Println("Changelog not required for this changed-file set.")
	}

	currentHead := gitRevParse("HEAD")
	previousLastVerifiedHead := ""
	previousFullGatesHead := ""

	if fileInfo, err := os.Stat(".local/gates.env"); err == nil && fileInfo.Size() > 0 {
		gatesEnv := loadEnvFile(".local/gates.env")
		previousLastVerifiedHead = gatesEnv["LAST_VERIFIED_HEAD_SHA"]
		previousFullGatesHead = gatesEnv["FULL_GATES_HEAD_SHA"]
	}

	gatesMode := "full"
	reuseGates := false

	if docsOnly == "true" && previousLastVerifiedHead != "" && gitMergeBaseIsAncestor(previousLastVerifiedHead, "HEAD") {
		deltaSinceVerified := gitDiffNameOnly(previousLastVerifiedHead + "..HEAD")
		if len(deltaSinceVerified) == 0 || fileListIsDocsishOnly(deltaSinceVerified) {
			reuseGates = true
		}
	}

	if reuseGates {
		gatesMode = "reused_docs_only"
		fmt.Printf("Docs/changelog-only delta since last verified head %s; reusing prior gates.\n", previousLastVerifiedHead)
	} else {
		runQuietLogged("pnpm build", ".local/gates-build.log", "pnpm", "build")
		runQuietLogged("pnpm check", ".local/gates-check.log", "pnpm", "check")

		if docsOnly == "true" {
			gatesMode = "docs_only"
			fmt.Println("Docs-only change detected with high confidence; skipping pnpm test.")
		} else {
			gatesMode = "full"
			maxWorkers := os.Getenv("OPENCLAW_VITEST_MAX_WORKERS")
			if maxWorkers == "" {
				maxWorkers = "4"
			}
			fmt.Printf("Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=%s.\n", maxWorkers)
			cmd := exec.Command("pnpm", "test")
			cmd.Env = append(os.Environ(), "OPENCLAW_VITEST_MAX_WORKERS="+maxWorkers)
			runQuietLoggedCmd("pnpm test", ".local/gates-test.log", cmd)
			previousFullGatesHead = currentHead
		}
	}

	// Write gates.env
	gatesEnv := map[string]string{
		"PR_NUMBER":                pr,
		"DOCS_ONLY":                docsOnly,
		"CHANGELOG_REQUIRED":       changelogRequired,
		"GATES_MODE":               gatesMode,
		"LAST_VERIFIED_HEAD_SHA":   currentHead,
		"FULL_GATES_HEAD_SHA":      previousFullGatesHead,
		"GATES_PASSED_AT":          time.Now().UTC().Format("2006-01-02T15:04:05Z"),
	}

	file, err := os.Create(".local/gates.env")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	for k, v := range gatesEnv {
		fmt.Fprintf(file, "%s=%q\n", k, v)
	}

	fmt.Printf("docs_only=%s\n", docsOnly)
	fmt.Printf("changelog_required=%s\n", changelogRequired)
	fmt.Printf("gates_mode=%s\n", gatesMode)
	fmt.Println("wrote=.local/gates.env")
}

// Helper functions
func runQuietLogged(name, logFile string, command ...string) {
	cmd := exec.Command(command[0], command[1:]...)
	runQuietLoggedCmd(name, logFile, cmd)
}

func runQuietLoggedCmd(name, logFile string, cmd *exec.Cmd) {
	logF, err := os.Create(logFile)
	if err != nil {
		log.Fatal(err)
	}
	defer logF.Close()

	cmd.Stdout = logF
	cmd.Stderr = logF

	fmt.Printf("Running %s...\n", name)
	if err := cmd.Run(); err != nil {
		log.Fatalf("Command failed: %s: %v", name, err)
	}
}

func bootstrapDepsIfNeeded() {
	// Implementation would depend on specific project needs
}

func enterWorktree(pr, force string) {
	// Implementation would depend on specific project needs
}

func checkoutPrepBranch(pr string) {
	// Implementation would depend on specific project needs
}

func requireArtifact(path string) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		log.Fatalf("Required artifact not found: %s", path)
	}
}

func loadEnvFile(path string) map[string]string {
	file, err := os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	env := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := parts[0]
			value := strings.Trim(parts[1], "\"'")
			env[key] = value
		}
	}
	return env
}

func gitDiffNameOnly(ref string) []string {
	cmd := exec.Command("git", "diff", "--name-only", ref)
	output, err := cmd.Output()
	if err != nil {
		log.Fatal(err)
	}
	lines := strings.Split(string(output), "\n")
	result := []string{}
	for _, line := range lines {
		if trimmed := strings.TrimSpace(line); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func pathIsDocsish(path string) bool {
	docsPaths := []string{"docs/", "README.md", "CHANGELOG.md"}
	for _, docPath := range docsPaths {
		if strings.HasPrefix(path, docPath) || filepath.Base(path) == docPath {
			return true
		}
	}
	return false
}

func changelogRequiredForChangedFiles(files []string) bool {
	// Implementation would depend on specific project needs
	// This is a placeholder implementation
	nonDocFiles := []string{}
	for _, file := range files {
		if !pathIsDocsish(file) {
			nonDocFiles = append(nonDocFiles, file)
		}
	}
	return len(nonDocFiles) > 0
}

func normalizePrChangelogEntries(pr string) {
	// Implementation would depend on specific project needs
}

func validateChangelogMergeHygiene() {
	// Implementation would depend on specific project needs
}

func validateChangelogEntryForPr(pr, contrib string) {
	// Implementation would depend on specific project needs
}

func gitRevParse(ref string) string {
	cmd := exec.Command("git", "rev-parse", ref)
	output, err := cmd.Output()
	if err != nil {
		log.Fatal(err)
	}
	return strings.TrimSpace(string(output))
}

func gitMergeBaseIsAncestor(ancestor, descendant string) bool {
	cmd := exec.Command("git", "merge-base", "--is-ancestor", ancestor, descendant)
	err := cmd.Run()
	return err == nil
}

func fileListIsDocsishOnly(files []string) bool {
	for _, file := range files {
		if !pathIsDocsish(file) {
			return false
		}
	}
	return true
}

func containsString(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
