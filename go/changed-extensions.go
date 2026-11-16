// abstraction-provenance: {"artifact_sha256": "573cd46d6a60a5d0789b33f31188ab96923dc86a29e4744e6a9e3bb9445bcacf", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "go"}
// changed-extensions.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
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
	"strings"
)

const (
	BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
	BUNDLED_PLUGIN_ROOT_DIR     = "extensions"
)

var repoRoot string

func init() {
	dir, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	repoRoot, _ = filepath.Abs(filepath.Join(dir, "..", ".."))
}

func runGit(args []string, options map[string]interface{}) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = repoRoot
	
	if options == nil {
		options = make(map[string]interface{})
	}
	
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return "", err
	}
	
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return "", err
	}
	
	err = cmd.Start()
	if err != nil {
		return "", err
	}
	
	scanner := bufio.NewScanner(stdout)
	var output strings.Builder
	for scanner.Scan() {
		output.WriteString(scanner.Text() + "\n")
	}
	
	errOut := bufio.NewScanner(stderr)
	var errOutput strings.Builder
	for errOut.Scan() {
		errOutput.WriteString(errOut.Text() + "\n")
	}
	
	err = cmd.Wait()
	if err != nil {
		return "", fmt.Errorf("git command failed: %v, stderr: %s", err, errOutput.String())
	}
	
	return strings.TrimSuffix(output.String(), "\n"), nil
}

func normalizeRelative(inputPath string) string {
	return filepath.ToSlash(inputPath)
}

func hasGitCommit(ref string) bool {
	if ref == "" || regexp.MustCompile(`^0+$`).MatchString(ref) {
		return false
	}
	
	_, err := runGit([]string{"rev-parse", "--verify", ref + "^{commit}"}, nil)
	return err == nil
}

func resolveChangedPathsBase(params map[string]interface{}) (string, error) {
	base := ""
	if b, ok := params["base"]; ok {
		base = b.(string)
	}
	head := "HEAD"
	if h, ok := params["head"]; ok {
		head = h.(string)
	}
	var fallbackBaseRef interface{}
	if f, ok := params["fallbackBaseRef"]; ok {
		fallbackBaseRef = f
	}
	
	if hasGitCommit(base) {
		return base, nil
	}
	
	if fallbackBaseRef != nil && fallbackBaseRef.(string) != "" {
		remoteBaseRef := fallbackBaseRef.(string)
		if !strings.HasPrefix(remoteBaseRef, "origin/") {
			remoteBaseRef = "origin/" + remoteBaseRef
		}
		if hasGitCommit(remoteBaseRef) {
			mergeBase, err := runGit([]string{"merge-base", remoteBaseRef, head}, nil)
			if err != nil {
				return "", err
			}
			mergeBase = strings.TrimSpace(mergeBase)
			if hasGitCommit(mergeBase) {
				return mergeBase, nil
			}
		}
	}
	
	if base == "" {
		return "", fmt.Errorf("A git base revision is required to list changed extensions.")
	}
	
	return "", fmt.Errorf("Git base revision is unavailable locally: %s", base)
}

func listChangedPaths(base string, head string) ([]string, error) {
	if base == "" {
		return nil, fmt.Errorf("A git base revision is required to list changed extensions.")
	}
	
	output, err := runGit([]string{"diff", "--name-only", base, head}, nil)
	if err != nil {
		return nil, err
	}
	
	lines := strings.Split(output, "\n")
	var result []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if len(trimmed) > 0 {
			result = append(result, trimmed)
		}
	}
	
	return result, nil
}

func hasExtensionPackage(extensionId string) bool {
	packagePath := filepath.Join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR, extensionId, "package.json")
	_, err := os.Stat(packagePath)
	return err == nil
}

func listAvailableExtensionIds() []string {
	extensionsDir := filepath.Join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR)
	if _, err := os.Stat(extensionsDir); os.IsNotExist(err) {
		return []string{}
	}
	
	entries, err := os.ReadDir(extensionsDir)
	if err != nil {
		return []string{}
	}
	
	var result []string
	for _, entry := range entries {
		if entry.IsDir() {
			extensionId := entry.Name()
			if hasExtensionPackage(extensionId) {
				result = append(result, extensionId)
			}
		}
	}
	
	sort.Strings(result)
	return result
}

func detectChangedExtensionIds(changedPaths []string) []string {
	extensionIds := make(map[string]bool)
	
	for _, rawPath := range changedPaths {
		relativePath := normalizeRelative(strings.TrimSpace(rawPath))
		if relativePath == "" {
			continue
		}
		
		// Create regex pattern similar to JS
		pattern := fmt.Sprintf(`^%s([^/]+)(?:/|$)`, strings.ReplaceAll(BUNDLED_PLUGIN_PATH_PREFIX, "/", "\\/"))
		re := regexp.MustCompile(pattern)
		extensionMatch := re.FindStringSubmatch(relativePath)
		if len(extensionMatch) > 1 {
			extensionId := extensionMatch[1]
			if hasExtensionPackage(extensionId) {
				extensionIds[extensionId] = true
			}
			continue
		}
		
		pairedCoreRe := regexp.MustCompile(`^src/([^/]+)(?:/|$)`)
		pairedCoreMatch := pairedCoreRe.FindStringSubmatch(relativePath)
		if len(pairedCoreMatch) > 1 && hasExtensionPackage(pairedCoreMatch[1]) {
			extensionIds[pairedCoreMatch[1]] = true
		}
	}
	
	var result []string
	for id := range extensionIds {
		result = append(result, id)
	}
	
	sort.Strings(result)
	return result
}

func listChangedExtensionIds(params map[string]interface{}) ([]string, error) {
	head := "HEAD"
	if h, ok := params["head"]; ok {
		head = h.(string)
	}
	unavailableBaseBehavior := "error"
	if u, ok := params["unavailableBaseBehavior"]; ok {
		unavailableBaseBehavior = u.(string)
	}
	
	defer func() {
		if r := recover(); r != nil {
			if unavailableBaseBehavior == "all" {
				// Return all available extensions
				// This would be handled in the calling code
			} else if unavailableBaseBehavior == "empty" {
				// Return empty slice
				// This would be handled in the calling code
			} else {
				// Re-throw error
				panic(r)
			}
		}
	}()
	
	base, err := resolveChangedPathsBase(params)
	if err != nil {
		if unavailableBaseBehavior == "all" {
			return listAvailableExtensionIds(), nil
		}
		if unavailableBaseBehavior == "empty" {
			return []string{}, nil
		}
		return nil, err
	}
	
	changedPaths, err := listChangedPaths(base, head)
	if err != nil {
		return nil, err
	}
	
	return detectChangedExtensionIds(changedPaths), nil
}

// Example usage function
func main() {
	// This would be used as a library, so main is just for demonstration
	fmt.Println("Library functions exported:")
	fmt.Println("- listAvailableExtensionIds")
	fmt.Println("- detectChangedExtensionIds")
	fmt.Println("- listChangedExtensionIds")
}
