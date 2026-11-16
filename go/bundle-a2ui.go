// abstraction-provenance: {"artifact_sha256": "6500ecdad1027c432348ae4b2f5c4f88f11253b37351227adc0f485b38503820", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "go"}
// bundle-a2ui.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

var (
	rootDir                  string
	hashFile                 string
	outputFile               string
	a2uiRendererDir          string
	a2uiAppDir               string
	inputPaths               []string
	ignoredBundleHashInputPrefixes = []string{"vendor/a2ui/renderers/lit/dist"}
	relativeInputPaths       []string
)

func init() {
	var err error
	_, filename, _, _ := runtime.Caller(0)
	rootDir = filepath.Join(filepath.Dir(filename), "..")
	hashFile = filepath.Join(rootDir, "src", "canvas-host", "a2ui", ".bundle.hash")
	outputFile = filepath.Join(rootDir, "src", "canvas-host", "a2ui", "a2ui.bundle.js")
	a2uiRendererDir = filepath.Join(rootDir, "vendor", "a2ui", "renderers", "lit")
	a2uiAppDir = filepath.Join(rootDir, "apps", "shared", "OpenClawKit", "Tools", "CanvasA2UI")
	
	inputPaths = []string{
		filepath.Join(rootDir, "package.json"),
		filepath.Join(rootDir, "pnpm-lock.yaml"),
		a2uiRendererDir,
		a2uiAppDir,
	}
	
	for _, inputPath := range inputPaths {
		relPath, _ := filepath.Rel(rootDir, inputPath)
		relativeInputPaths = append(relativeInputPaths, normalizePath(relPath))
	}
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	fmt.Fprintln(os.Stderr, "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle")
	fmt.Fprintln(os.Stderr, "If this persists, verify pnpm deps and try again.")
	os.Exit(1)
}

func pathExists(targetPath string) bool {
	_, err := os.Stat(targetPath)
	return !os.IsNotExist(err)
}

func normalizePath(filePath string) string {
	return strings.ReplaceAll(filePath, string(os.PathSeparator), "/")
}

func isBundleHashInputPath(filePath string, repoRoot string) bool {
	relPath, _ := filepath.Rel(repoRoot, filePath)
	relativePath := normalizePath(relPath)
	
	for _, ignoredPath := range ignoredBundleHashInputPrefixes {
		if relativePath == ignoredPath || strings.HasPrefix(relativePath, ignoredPath+"/") {
			return false
		}
	}
	return true
}

func getLocalRolldownCliCandidates(repoRoot string) []string {
	return []string{
		filepath.Join(repoRoot, "node_modules", "rolldown", "bin", "cli.mjs"),
		filepath.Join(repoRoot, "node_modules", ".pnpm", "node_modules", "rolldown", "bin", "cli.mjs"),
		filepath.Join(repoRoot, "node_modules", ".pnpm", "rolldown@1.0.0-rc.12", "node_modules", "rolldown", "bin", "cli.mjs"),
	}
}

func walkFiles(entryPath string, files *[]string) error {
	if !isBundleHashInputPath(entryPath, rootDir) {
		return nil
	}
	
	stat, err := os.Stat(entryPath)
	if err != nil {
		return err
	}
	
	if !stat.IsDir() {
		*files = append(*files, entryPath)
		return nil
	}
	
	entries, err := os.ReadDir(entryPath)
	if err != nil {
		return err
	}
	
	for _, entry := range entries {
		err := walkFiles(filepath.Join(entryPath, entry.Name()), files)
		if err != nil {
			return err
		}
	}
	return nil
}

func listTrackedInputFiles() []string {
	cmd := exec.Command("git", append([]string{"ls-files", "--"}, relativeInputPaths...)...)
	cmd.Dir = rootDir
	output, err := cmd.Output()
	if err != nil {
		return nil
	}
	
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var result []string
	
	for _, line := range lines {
		if line != "" {
			fullPath := filepath.Join(rootDir, line)
			if isBundleHashInputPath(fullPath, rootDir) {
				result = append(result, fullPath)
			}
		}
	}
	
	return result
}

func computeHash() (string, error) {
	files := listTrackedInputFiles()
	if files == nil {
		files = []string{}
		for _, inputPath := range inputPaths {
			var tempFiles []string
			err := walkFiles(inputPath, &tempFiles)
			if err != nil {
				return "", err
			}
			files = append(files, tempFiles...)
		}
	}
	
	sort.Slice(files, func(i, j int) bool {
		return normalizePath(files[i]) < normalizePath(files[j])
	})
	
	hash := sha256.New()
	
	for _, filePath := range files {
		relPath, _ := filepath.Rel(rootDir, filePath)
		hash.Write([]byte(normalizePath(relPath)))
		hash.Write([]byte("\x00"))
		
		content, err := os.ReadFile(filePath)
		if err != nil {
			return "", err
		}
		hash.Write(content)
		hash.Write([]byte("\x00"))
	}
	
	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func runStep(command string, args []string, options map[string]interface{}) {
	cmd := exec.Command(command, args...)
	cmd.Dir = rootDir
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	if env, ok := options["env"]; ok {
		cmd.Env = env.([]string)
	} else {
		cmd.Env = os.Environ()
	}
	
	err := cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		}
		os.Exit(1)
	}
}

func runPnpm(pnpmArgs []string) {
	// Simplified pnpm runner - in practice you might need more complex logic
	args := append([]string{"run"}, pnpmArgs...)
	runStep("pnpm", args, nil)
}

func main() {
	hasRendererDir := pathExists(a2uiRendererDir)
	hasAppDir := pathExists(a2uiAppDir)
	hasOutputFile := pathExists(outputFile)
	
	if !hasRendererDir || !hasAppDir {
		if hasOutputFile {
			fmt.Println("A2UI sources missing; keeping prebuilt bundle.")
			return
		}
		
		if os.Getenv("OPENCLAW_SPARSE_PROFILE") != "" || os.Getenv("OPENCLAW_A2UI_SKIP_MISSING") == "1" {
			fmt.Fprintln(os.Stderr, "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set.")
			return
		}
		
		fail(fmt.Sprintf("A2UI sources missing and no prebuilt bundle found at: %s", outputFile))
	}
	
	currentHash, err := computeHash()
	if err != nil {
		fail(err.Error())
	}
	
	if pathExists(hashFile) {
		previousHashBytes, err := os.ReadFile(hashFile)
		if err != nil {
			fail(err.Error())
		}
		
		previousHash := strings.TrimSpace(string(previousHashBytes))
		if previousHash == currentHash && hasOutputFile {
			fmt.Println("A2UI bundle up to date; skipping.")
			return
		}
	}
	
	runPnpm([]string{"-s", "exec", "tsc", "-p", filepath.Join(a2uiRendererDir, "tsconfig.json")})
	
	localRolldownCliCandidates := getLocalRolldownCliCandidates(rootDir)
	var localRolldownCli string
	
	for _, candidate := range localRolldownCliCandidates {
		if pathExists(candidate) {
			localRolldownCli = candidate
			break
		}
	}
	
	if localRolldownCli != "" {
		runStep("node", []string{localRolldownCli, "-c", filepath.Join(a2uiAppDir, "rolldown.config.mjs")}, nil)
	} else {
		runPnpm([]string{"-s", "exec", "rolldown", "-c", filepath.Join(a2uiAppDir, "rolldown.config.mjs")})
	}
	
	err = os.WriteFile(hashFile, []byte(currentHash+"\n"), 0644)
	if err != nil {
		fail(err.Error())
	}
}

func init() {
	// Check if this file is being run directly
	if len(os.Args) > 0 {
		// In Go, we don't have the same import.meta.url check,
		// but we can assume the main function will be called when run directly
	}
}
