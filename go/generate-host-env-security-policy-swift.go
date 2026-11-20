// abstraction-provenance: {"artifact_sha256": "bcf5fb5d8102f95dc690624b734a7e2132c305e9ceaacfdda79aa19595837cb2", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "go"}
// generate-host-env-security-policy-swift.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

type Policy struct {
	BlockedInheritedKeys       []string `json:"blockedInheritedKeys"`
	BlockedInheritedPrefixes   []string `json:"blockedInheritedPrefixes"`
	BlockedKeys                []string `json:"blockedKeys"`
	BlockedOverrideKeys        []string `json:"blockedOverrideKeys,omitempty"`
	BlockedOverridePrefixes    []string `json:"blockedOverridePrefixes,omitempty"`
	BlockedPrefixes            []string `json:"blockedPrefixes"`
}

func loadHostEnvSecurityPolicy(data map[string]interface{}) Policy {
	var policy Policy
	
	if keys, ok := data["blockedInheritedKeys"].([]interface{}); ok {
		for _, k := range keys {
			policy.BlockedInheritedKeys = append(policy.BlockedInheritedKeys, k.(string))
		}
	}
	
	if prefixes, ok := data["blockedInheritedPrefixes"].([]interface{}); ok {
		for _, p := range prefixes {
			policy.BlockedInheritedPrefixes = append(policy.BlockedInheritedPrefixes, p.(string))
		}
	}
	
	if keys, ok := data["blockedKeys"].([]interface{}); ok {
		for _, k := range keys {
			policy.BlockedKeys = append(policy.BlockedKeys, k.(string))
		}
	}
	
	if keys, ok := data["blockedOverrideKeys"].([]interface{}); ok {
		for _, k := range keys {
			policy.BlockedOverrideKeys = append(policy.BlockedOverrideKeys, k.(string))
		}
	}
	
	if prefixes, ok := data["blockedOverridePrefixes"].([]interface{}); ok {
		for _, p := range prefixes {
			policy.BlockedOverridePrefixes = append(policy.BlockedOverridePrefixes, p.(string))
		}
	}
	
	if prefixes, ok := data["blockedPrefixes"].([]interface{}); ok {
		for _, p := range prefixes {
			policy.BlockedPrefixes = append(policy.BlockedPrefixes, p.(string))
		}
	}
	
	return policy
}

func renderSwiftStringArray(items []string) string {
	if len(items) == 0 {
		return ""
	}
	
	var result []string
	for _, item := range items {
		result = append(result, fmt.Sprintf("        \"%s\"", item))
	}
	return strings.Join(result, ",\n")
}

func main() {
	args := make(map[string]bool)
	for _, arg := range os.Args[1:] {
		args[arg] = true
	}
	
	checkOnly := args["--check"]
	writeMode := args["--write"] || !checkOnly
	
	if checkOnly && args["--write"] {
		fmt.Fprintln(os.Stderr, "Use either --check or --write, not both.")
		os.Exit(1)
	}
	
	here, _ := filepath.Abs(filepath.Dir(os.Args[0]))
	repoRoot := filepath.Join(here, "..")
	policyPath := filepath.Join(repoRoot, "src", "infra", "host-env-security-policy.json")
	outputPath := filepath.Join(repoRoot, "apps", "macos", "Sources", "OpenClaw", "HostEnvSecurityPolicy.generated.swift")
	
	policyData, err := ioutil.ReadFile(policyPath)
	if err != nil {
		panic(err)
	}
	
	var rawData map[string]interface{}
	err = json.Unmarshal(policyData, &rawData)
	if err != nil {
		panic(err)
	}
	
	policy := loadHostEnvSecurityPolicy(rawData)
	
	generated := `// Generated file. Do not edit directly.
// Source: src/infra/host-env-security-policy.json
// Regenerate: node scripts/generate-host-env-security-policy-swift.mjs --write

import Foundation

enum HostEnvSecurityPolicy {
    static let blockedInheritedKeys: Set<String> = [
` + renderSwiftStringArray(policy.BlockedInheritedKeys) + `
    ]

    static let blockedInheritedPrefixes: [String] = [
` + renderSwiftStringArray(policy.BlockedInheritedPrefixes) + `
    ]

    static let blockedKeys: Set<String> = [
` + renderSwiftStringArray(policy.BlockedKeys) + `
    ]

    static let blockedOverrideKeys: Set<String> = [
` + renderSwiftStringArray(policy.BlockedOverrideKeys) + `
    ]

    static let blockedOverridePrefixes: [String] = [
` + renderSwiftStringArray(policy.BlockedOverridePrefixes) + `
    ]

    static let blockedPrefixes: [String] = [
` + renderSwiftStringArray(policy.BlockedPrefixes) + `
    ]
}
`
	
	var current []byte
	if _, err := os.Stat(outputPath); err == nil {
		current, _ = ioutil.ReadFile(outputPath)
	} else {
		current = nil
	}
	
	if checkOnly {
		if string(current) == generated {
			fmt.Printf("OK %s\n", filepath.Join("apps", "macos", "Sources", "OpenClaw", "HostEnvSecurityPolicy.generated.swift"))
			os.Exit(0)
		}
		fmt.Fprintf(os.Stderr, "Out of date %s.\nRun: node scripts/generate-host-env-security-policy-swift.mjs --write\n", 
			filepath.Join("apps", "macos", "Sources", "OpenClaw", "HostEnvSecurityPolicy.generated.swift"))
		os.Exit(1)
	}
	
	if writeMode {
		if string(current) != generated {
			err := ioutil.WriteFile(outputPath, []byte(generated), 0644)
			if err != nil {
				panic(err)
			}
		}
		fmt.Printf("Wrote %s\n", filepath.Join("apps", "macos", "Sources", "OpenClaw", "HostEnvSecurityPolicy.generated.swift"))
	}
}
