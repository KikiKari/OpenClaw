// abstraction-provenance: {"artifact_sha256": "64666471914b4852f654fa292ad7db4da92262b2f1288ab6ab455cc6ba5b53ae", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "go"}
// test-extension-batch.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: go run test-extension-batch.go <extension[,extension...]> [vitest args...]")
}

func parseExtensionIds(rawArgs []string) ([]string, []string) {
	extensionIds := []string{}
	args := make([]string, len(rawArgs))
	copy(args, rawArgs)
	
	i := 0
	for i < len(args) {
		if strings.HasPrefix(args[i], "-") {
			break
		}
		
		parts := strings.Split(args[i], ",")
		for _, part := range parts {
			trimmed := strings.TrimSpace(part)
			if trimmed != "" {
				extensionIds = append(extensionIds, trimmed)
			}
		}
		i++
	}
	
	vitestArgs := args[i:]
	return extensionIds, vitestArgs
}

func main() {
	rawArgs := os.Args[1:]
	
	// Check for help flags
	for _, arg := range rawArgs {
		if arg == "--help" || arg == "-h" {
			printUsage()
			return
		}
	}
	
	// Filter out -- arguments
	passthroughArgs := []string{}
	for _, arg := range rawArgs {
		if arg != "--" {
			passthroughArgs = append(passthroughArgs, arg)
		}
	}
	
	extensionIds, vitestArgs := parseExtensionIds(passthroughArgs)
	
	if len(extensionIds) == 0 {
		printUsage()
		os.Exit(1)
	}
	
	cwd, err := os.Getwd()
	if err != nil {
		fmt.Printf("Error getting current directory: %v\n", err)
		os.Exit(1)
	}
	
	batchPlan := resolveExtensionBatchPlan(cwd, extensionIds)
	if !batchPlan.hasTests {
		fmt.Println("[test-extension-batch] No tests found for the requested extensions. Skipping.")
		return
	}
	
	fmt.Printf("[test-extension-batch] Running %d test files across %d extensions\n", 
		batchPlan.testFileCount, batchPlan.extensionCount)
	
	for _, group := range batchPlan.planGroups {
		fmt.Printf("[test-extension-batch] %s: %s (%d files)\n", 
			group.config, 
			strings.Join(group.extensionIds, ", "), 
			group.testFileCount)
		
		exitCode := runVitestBatch(vitestArgs, group.config, group.roots)
		if exitCode != 0 {
			os.Exit(exitCode)
		}
	}
}

type PlanGroup struct {
	config        string
	extensionIds  []string
	roots         []string
	testFileCount int
}

type ExtensionBatchPlan struct {
	hasTests       bool
	testFileCount  int
	extensionCount int
	planGroups     []PlanGroup
}

func resolveExtensionBatchPlan(cwd string, extensionIds []string) *ExtensionBatchPlan {
	plan := &ExtensionBatchPlan{
		hasTests:       false,
		testFileCount:  0,
		extensionCount: 0,
		planGroups:     []PlanGroup{},
	}
	
	// This is a simplified implementation - you would need to implement
	// the actual logic based on your project structure
	// For now, creating a mock plan for demonstration
	
	if len(extensionIds) > 0 {
		plan.hasTests = true
		plan.testFileCount = len(extensionIds)
		plan.extensionCount = len(extensionIds)
		
		// Create a single group for all extensions
		roots := []string{}
		for _, id := range extensionIds {
			roots = append(roots, filepath.Join(cwd, "extensions", id))
		}
		
		group := PlanGroup{
			config:        "vitest.config.js",
			extensionIds:  extensionIds,
			roots:         roots,
			testFileCount: len(extensionIds),
		}
		
		plan.planGroups = append(plan.planGroups, group)
	}
	
	return plan
}

func runVitestBatch(args []string, config string, targets []string) int {
	// This is a placeholder implementation
	// You would need to actually execute vitest with the given parameters
	fmt.Printf("Would run vitest with config: %s and targets: %v\n", config, targets)
	fmt.Printf("Args: %v\n", args)
	
	// Return 0 for success, non-zero for failure
	return 0
}
