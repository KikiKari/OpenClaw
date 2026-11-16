// abstraction-provenance: {"artifact_sha256": "a529f463cecf907e26c3b8ca75bad77ac5b4b1533f9e882faafc18249c6ea584", "source_sha256": "d0e229aab6f22cce6a57639e2ffb6182fc50c823ca2adff745764d168dc70826", "target_language": "go"}
// audit-seams.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/audit-seams.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

const (
	BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
	BUNDLED_PLUGIN_ROOT_DIR    = "extensions"
	MAX_SCAN_BYTES            = 2 * 1024 * 1024
)

var (
	optionalBundledClusterSet = map[string]bool{
		// Populate with actual optional clusters
	}
	compareStrings = strings.Compare
	HELP_TEXT      = `Usage: go run scripts/audit-seams.go [--help]

Audit repo seam inventory and emit JSON to stdout.

Sections:
  duplicatedSeamFamilies       Plugin SDK seam families imported from multiple production files
  overlapFiles                 Production files that touch multiple seam families
  optionalClusterStaticLeaks   Optional extension/plugin clusters referenced from the static graph
  missingPackages              Workspace packages whose deps are not mirrored at the root
  seamTestInventory            High-signal seam candidates with nearby-test gap signals,
                               including cron orchestration seams for agent handoff,
                               outbound/media delivery, heartbeat/followup handoff,
                               and scheduler state crossings, plus subagent seams
                               for spawn/session handoff, announce delivery,
                               lifecycle registry, cleanup, and parent streaming

Notes:
  - Output is JSON only.
  - For clean redirected JSON through package scripts, prefer:
      pnpm --silent audit:seams > seam-inventory.json
`
)

type ImportEntry struct {
	Family       string `json:"family"`
	File         string `json:"file"`
	Kind         string `json:"kind"`
	Line         int    `json:"line"`
	ResolvedPath string `json:"resolvedPath"`
	Specifier    string `json:"specifier"`
}

type ClusterImportEntry struct {
	Cluster      string `json:"cluster"`
	File         string `json:"file"`
	Kind         string `json:"kind"`
	Line         int    `json:"line"`
	ResolvedPath string `json:"resolvedPath"`
	Specifier    string `json:"specifier"`
}

type DuplicatedSeamFamily struct {
	Count       int           `json:"count"`
	ImportCount int           `json:"importCount"`
	Files       []string      `json:"files"`
	Imports     []ImportEntry `json:"imports"`
}

type OverlapFile struct {
	File     string        `json:"file"`
	Families []string      `json:"families"`
	Imports  []ImportEntry `json:"imports"`
}

type OptionalClusterLeak struct {
	Count  int                 `json:"count"`
	Files  []string            `json:"files"`
	Imports []ClusterImportEntry `json:"imports"`
}

type MissingPackage struct {
	Cluster              string         `json:"cluster"`
	Decision             string         `json:"decision"`
	DecisionReason       string         `json:"decisionReason"`
	PackageName          string         `json:"packageName"`
	PackagePath          string         `json:"packagePath"`
	NpmSpec              interface{}    `json:"npmSpec"`
	Private              bool           `json:"private"`
	PluginSdkReachability *Reachability `json:"pluginSdkReachability,omitempty"`
	Missing              []string       `json:"missing"`
}

type Reachability struct {
	StaticEntryPoints []string `json:"staticEntryPoints"`
}

type SeamTestEntry struct {
	File               string   `json:"file"`
	SeamKinds          []string `json:"seamKinds"`
	RelatedTests       []string `json:"relatedTests"`
	RelatedTestMatches []string `json:"relatedTestMatches"`
	Status             string   `json:"status"`
	Reason             string   `json:"reason"`
}

type AuditResult struct {
	DuplicatedSeamFamilies      map[string]DuplicatedSeamFamily `json:"duplicatedSeamFamilies"`
	OverlapFiles                []OverlapFile                   `json:"overlapFiles"`
	OptionalClusterStaticLeaks  map[string]OptionalClusterLeak  `json:"optionalClusterStaticLeaks"`
	MissingPackages             []MissingPackage                `json:"missingPackages"`
	SeamTestInventory           []SeamTestEntry                 `json:"seamTestInventory"`
}

var (
	repoRoot       string
	srcRoot        string
	extensionsRoot string
	testRoot       string
)

func init() {
	exe, _ := os.Executable()
	repoRoot = filepath.Join(filepath.Dir(exe), "..")
	srcRoot = filepath.Join(repoRoot, "src")
	extensionsRoot = filepath.Join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR)
	testRoot = filepath.Join(repoRoot, "test")
}

func normalizePath(filePath string) string {
	rel, _ := filepath.Rel(repoRoot, filePath)
	return filepath.ToSlash(rel)
}

func readScannableText(filePath string, maxBytes int) (string, error) {
	info, err := os.Stat(filePath)
	if err != nil {
		return "", err
	}
	if info.Size() <= int64(maxBytes) {
		data, err := os.ReadFile(filePath)
		return string(data), err
	}
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	buffer := make([]byte, maxBytes)
	n, err := file.Read(buffer)
	if err != nil {
		return "", err
	}
	return string(buffer[:n]), nil
}

func redactNpmSpec(npmSpec interface{}) interface{} {
	if str, ok := npmSpec.(string); ok {
		re := regexp.MustCompile(`(https?://)([^/\s:@]+):([^/\s@]+)@`)
		str = re.ReplaceAllString(str, "${1}***:***@")
		re = regexp.MustCompile(`(https?://)([^/\s:@]+)@`)
		return re.ReplaceAllString(str, "${1}***@")
	}
	return npmSpec
}

func isCodeFile(fileName string) bool {
	matched, _ := regexp.MatchString(`\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$`, fileName)
	return matched
}

func isTestLikePath(relativePath string) bool {
	matched, _ := regexp.MatchString(`(^|/)(__tests__|fixtures|test-utils|test-fixtures)/`, relativePath)
	if matched {
		return true
	}
	matched, _ = regexp.MatchString(`(?:^|/)[^/]*(?:[.-](?:test|spec))(?:[.-][^/]+)?\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$`, relativePath)
	return matched
}

func isProductionLikeFile(relativePath string) bool {
	return !isTestLikePath(relativePath)
}

func walkCodeFiles(rootDir string) ([]string, error) {
	var files []string
	err := filepath.WalkDir(rootDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Name() == "dist" || d.Name() == "node_modules" {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return nil
		}
		if !isCodeFile(d.Name()) {
			return nil
		}
		relPath := normalizePath(path)
		if !isProductionLikeFile(relPath) {
			return nil
		}
		files = append(files, path)
		return nil
	})
	sort.Slice(files, func(i, j int) bool {
		return normalizePath(files[i]) < normalizePath(files[j])
	})
	return files, err
}

func walkAllCodeFiles(rootDir string, includeTests bool) ([]string, error) {
	var files []string
	err := filepath.WalkDir(rootDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Name() == "dist" || d.Name() == "node_modules" {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return nil
		}
		if !isCodeFile(d.Name()) {
			return nil
		}
		relPath := normalizePath(path)
		if !includeTests && !isProductionLikeFile(relPath) {
			return nil
		}
		files = append(files, path)
		return nil
	})
	sort.Slice(files, func(i, j int) bool {
		return normalizePath(files[i]) < normalizePath(files[j])
	})
	return files, err
}

func collectWorkspacePackagePaths() ([]string, error) {
	paths := []string{"ui/package.json"}
	entries, err := os.ReadDir(extensionsRoot)
	if err != nil {
		return nil, err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			paths = append(paths, filepath.Join("extensions", entry.Name(), "package.json"))
		}
	}
	return paths, nil
}

func main() {
	args := os.Args[1:]
	if len(args) > 0 && (args[0] == "--help" || args[0] == "-h") {
		fmt.Println(HELP_TEXT)
		return
	}

	workspacePaths, err := collectWorkspacePackagePaths()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error collecting workspace paths: %v\n", err)
		os.Exit(1)
	}

	// Placeholder for actual implementation
	result := AuditResult{
		DuplicatedSeamFamilies:     make(map[string]DuplicatedSeamFamily),
		OverlapFiles:               []OverlapFile{},
		OptionalClusterStaticLeaks: make(map[string]OptionalClusterLeak),
		MissingPackages:            []MissingPackage{},
		SeamTestInventory:          []SeamTestEntry{},
	}

	jsonData, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(jsonData))
}
