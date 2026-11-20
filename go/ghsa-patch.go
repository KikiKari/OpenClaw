// abstraction-provenance: {"artifact_sha256": "446627606e70684393b926831659e5659eb59316882232850e3564f9d096165c", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "go"}
// ghsa-patch.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type Args struct {
	Ghsa                    string
	Summary                 string
	Severity                string
	DescriptionFile         string
	VulnerableVersionRange  string
	PatchedVersions         string
	Repo                    string
	Package                 string
	Ecosystem               string
	Cvss                    string
}

type Advisory struct {
	HtmlUrl        string      `json:"html_url"`
	State          string      `json:"state"`
	Severity       string      `json:"severity"`
	Summary        string      `json:"summary"`
	Vulnerabilities []Vulnerability `json:"vulnerabilities"`
	Cvss           interface{} `json:"cvss"`
	UpdatedAt      string      `json:"updated_at"`
}

type Vulnerability struct {
	Package              Package  `json:"package"`
	VulnerableVersionRange string   `json:"vulnerable_version_range"`
	PatchedVersions        *string  `json:"patched_versions"`
	VulnerableFunctions    []string `json:"vulnerable_functions"`
}

type Package struct {
	Ecosystem string `json:"ecosystem"`
	Name      string `json:"name"`
}

func usage() {
	fmt.Fprintln(os.Stderr, "Usage:")
	fmt.Fprintln(os.Stderr, "  go run ghsa-patch.go --ghsa <GHSA-id-or-url> [--repo owner/name]")
	fmt.Fprintln(os.Stderr, "    --summary <text> --severity <low|medium|high|critical>")
	fmt.Fprintln(os.Stderr, "    --description-file <path>")
	fmt.Fprintln(os.Stderr, "    --vulnerable-version-range <range>")
	fmt.Fprintln(os.Stderr, "    --patched-versions <range-or-null>")
	fmt.Fprintln(os.Stderr, "    [--package openclaw] [--ecosystem npm] [--cvss <vector>]")
	os.Exit(1)
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(1)
}

func parseArgs(args []string) Args {
	result := Args{}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if !strings.HasPrefix(arg, "--") {
			fail(fmt.Sprintf("Unexpected argument: %s", arg))
		}
		key := strings.TrimPrefix(arg, "--")
		if i+1 >= len(args) || strings.HasPrefix(args[i+1], "--") {
			fail(fmt.Sprintf("Missing value for --%s", key))
		}
		value := args[i+1]
		switch key {
		case "ghsa":
			result.Ghsa = value
		case "summary":
			result.Summary = value
		case "severity":
			result.Severity = value
		case "description-file":
			result.DescriptionFile = value
		case "vulnerable-version-range":
			result.VulnerableVersionRange = value
		case "patched-versions":
			result.PatchedVersions = value
		case "repo":
			result.Repo = value
		case "package":
			result.Package = value
		case "ecosystem":
			result.Ecosystem = value
		case "cvss":
			result.Cvss = value
		}
		i++
	}
	return result
}

func runGh(args ...string) string {
	cmd := exec.Command("gh", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fail(strings.TrimSpace(string(output)))
	}
	return strings.TrimSpace(string(output))
}

func deriveRepoFromOrigin() string {
	cmd := exec.Command("git", "remote", "get-url", "origin")
	output, err := cmd.Output()
	if err != nil {
		fail(fmt.Sprintf("Failed to get git remote url: %v", err))
	}
	remote := strings.TrimSpace(string(output))
	
	re := regexp.MustCompile(`github\.com[/:]([^/]+)/([^/.]+)(?:\.git)?$`)
	matches := re.FindStringSubmatch(remote)
	if matches == nil {
		fail(fmt.Sprintf("Could not parse origin remote: %s", remote))
	}
	return fmt.Sprintf("%s/%s", matches[1], matches[2])
}

func parseGhsaId(value string) string {
	re := regexp.MustCompile(`GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}`)
	match := re.FindString(value)
	if match == "" {
		fail(fmt.Sprintf("Could not parse GHSA id from: %s", value))
	}
	return match
}

func writeTempJson(data interface{}) string {
	file, err := os.CreateTemp("", "ghsa-patch-*.json")
	if err != nil {
		fail(fmt.Sprintf("Failed to create temp file: %v", err))
	}
	defer file.Close()
	
	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		fail(fmt.Sprintf("Failed to write JSON: %v", err))
	}
	
	return file.Name()
}

func main() {
	args := parseArgs(os.Args[1:])
	
	if args.Ghsa == "" || args.Summary == "" || args.Severity == "" || args.DescriptionFile == "" {
		usage()
	}
	
	repo := args.Repo
	if repo == "" {
		repo = deriveRepoFromOrigin()
	}
	
	ghsaId := parseGhsaId(args.Ghsa)
	advisoryPath := fmt.Sprintf("/repos/%s/security-advisories/%s", repo, ghsaId)
	descriptionPath, err := filepath.Abs(args.DescriptionFile)
	if err != nil {
		fail(fmt.Sprintf("Failed to resolve description file path: %v", err))
	}
	
	if _, err := os.Stat(descriptionPath); os.IsNotExist(err) {
		fail(fmt.Sprintf("Description file does not exist: %s", descriptionPath))
	}
	
	currentJson := runGh("api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisoryPath)
	var current Advisory
	if err := json.Unmarshal([]byte(currentJson), &current); err != nil {
		fail(fmt.Sprintf("Failed to parse current advisory: %v", err))
	}
	
	restoredCvss := args.Cvss
	if restoredCvss == "" && current.Cvss != nil {
		// Try to extract CVSS vector from current.CVss
		if cvssMap, ok := current.Cvss.(map[string]interface{}); ok {
			if vector, exists := cvssMap["vector_string"].(string); exists {
				restoredCvss = vector
			}
		}
	}
	
	ecosystem := args.Ecosystem
	if ecosystem == "" {
		ecosystem = "npm"
	}
	
	packageName := args.Package
	if packageName == "" {
		packageName = "openclaw"
	}
	
	vulnerableRange := args.VulnerableVersionRange
	patchedVersionsRaw := args.PatchedVersions
	
	if vulnerableRange == "" {
		fail("Missing --vulnerable-version-range")
	}
	if patchedVersionsRaw == "" {
		fail("Missing --patched-versions")
	}
	
	var patchedVersions *string
	if patchedVersionsRaw != "null" {
		patchedVersions = &patchedVersionsRaw
	}
	
	descriptionBytes, err := os.ReadFile(descriptionPath)
	if err != nil {
		fail(fmt.Sprintf("Failed to read description file: %v", err))
	}
	description := string(descriptionBytes)
	
	payload := map[string]interface{}{
		"summary":  args.Summary,
		"severity": args.Severity,
		"description": description,
		"vulnerabilities": []map[string]interface{}{
			{
				"package": map[string]string{
					"ecosystem": ecosystem,
					"name":      packageName,
				},
				"vulnerable_version_range": vulnerableRange,
				"patched_versions":          patchedVersions,
				"vulnerable_functions":      []string{},
			},
		},
	}
	
	patchFile := writeTempJson(payload)
	defer os.Remove(patchFile)
	
	runGh("api", "-H", "X-GitHub-Api-Version: 2022-11-28", "-X", "PATCH", advisoryPath, "--input", patchFile)
	
	if restoredCvss != "" {
		runGh("api", "-H", "X-GitHub-Api-Version: 2022-11-28", "-X", "PATCH", advisoryPath, "-f", fmt.Sprintf("cvss_vector_string=%s", restoredCvss))
	}
	
	refreshedJson := runGh("api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisoryPath)
	var refreshed Advisory
	if err := json.Unmarshal([]byte(refreshedJson), &refreshed); err != nil {
		fail(fmt.Sprintf("Failed to parse refreshed advisory: %v", err))
	}
	
	result := map[string]interface{}{
		"html_url":      refreshed.HtmlUrl,
		"state":         refreshed.State,
		"severity":      refreshed.Severity,
		"summary":       refreshed.Summary,
		"vulnerabilities": refreshed.Vulnerabilities,
		"cvss":          refreshed.Cvss,
		"updated_at":    refreshed.UpdatedAt,
	}
	
	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal result: %v", err)
	}
	
	fmt.Println(string(output))
}
