// abstraction-provenance: {"artifact_sha256": "c8e87a4d2690aa8de486db007e605d4057dc930467346100bf8909b28ce89b64", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "go"}
// test-extension.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// printUsage prints the usage information to stderr
func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: pnpm test:extension <extension-name|path> [vitest args...]")
	fmt.Fprintln(os.Stderr, "       node scripts/test-extension.mjs [extension-name|path] [vitest args...]")
}

// printNoTestsMessage prints a message when no tests are found
func printNoTestsMessage(plan extensionTestPlan) {
	fmt.Printf("[test-extension] No tests found for %s. Skipping.\n", plan.extensionDir)
}

// isDirectScriptRun checks if this script is being run directly
func isDirectScriptRun() bool {
	// In Go, we assume it's always run directly when executed
	return true
}

// formatErrorMessage formats an error message (placeholder implementation)
func formatErrorMessage(err error) string {
	return err.Error()
}

// resolveExtensionTestPlan resolves the test plan for an extension (placeholder implementation)
func resolveExtensionTestPlan(cwd, targetArg string) (extensionTestPlan, error) {
	// This is a simplified placeholder - actual implementation would need to be ported
	plan := extensionTestPlan{
		extensionDir:  targetArg,
		extensionId:   targetArg,
		hasTests:      true,
		testFileCount: 1,
		config:        "vitest.config.js",
		roots:         []string{"./tests"},
	}
	return plan, nil
}

// runVitestBatch runs vitest with the provided configuration (placeholder implementation)
func runVitestBatch(args []string, config string, env []string, targets []string) int {
	// This is a simplified placeholder - actual implementation would need to be ported
	fmt.Printf("[test-extension] Would run vitest with args: %v, config: %s, targets: %v\n", args, config, targets)
	return 0
}

// extensionTestPlan represents the test plan structure
type extensionTestPlan struct {
	extensionDir  string
	extensionId   string
	hasTests      bool
	testFileCount int
	config        string
	roots         []string
}

// run executes the main logic
func run() int {
	rawArgs := os.Args[1:]
	
	for _, arg := range rawArgs {
		if arg == "--help" || arg == "-h" {
			printUsage()
			return 0
		}
	}

	passthroughArgs := []string{}
	var targetArg string
	
	argsProcessed := false
	for _, arg := range rawArgs {
		if arg == "--" {
			continue
		}
		
		if !argsProcessed && targetArg == "" && !strings.HasPrefix(arg, "-") {
			targetArg = arg
			argsProcessed = true
			continue
		}
		passthroughArgs = append(passthroughArgs, arg)
	}

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error getting current working directory:", err)
		return 1
	}

	plan, err := resolveExtensionTestPlan(cwd, targetArg)
	if err != nil {
		printUsage()
		fmt.Fprintln(os.Stderr, formatErrorMessage(err))
		return 1
	}

	if !plan.hasTests {
		printNoTestsMessage(plan)
		return 0
	}

	fmt.Printf("[test-extension] Running %d test files for %s\n", plan.testFileCount, plan.extensionId)
	exitCode := runVitestBatch(passthroughArgs, plan.config, os.Environ(), plan.roots)
	return exitCode
}

func main() {
	if isDirectScriptRun() {
		exitCode := run()
		os.Exit(exitCode)
	}
}
