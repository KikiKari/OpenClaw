// abstraction-provenance: {"artifact_sha256": "472d181dbe65383f24804dd2e31ed9e7af9a54cd6ff4c14e08deb3603a6a81fb", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "go"}
// run-node.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	BUNDLED_PLUGIN_PATH_PREFIX = "plugins/"
	BUNDLED_PLUGIN_ROOT_DIR    = "plugins"
	buildScript                = "scripts/tsdown-build.mjs"
)

var (
	runNodeSourceRoots     = []string{"src", BUNDLED_PLUGIN_ROOT_DIR}
	runNodeConfigFiles     = []string{"tsconfig.json", "package.json", "tsdown.config.ts"}
	runNodeWatchedPaths    = append(runNodeSourceRoots, runNodeConfigFiles...)
	compilerArgs           = []string{buildScript, "--no-clean"}
	extensionSourceFilePattern = regexp.MustCompile(`\.(?:[cm]?[jt]sx?)$`)
	extensionRestartMetadataFiles = map[string]bool{
		"openclaw.plugin.json": true,
		"package.json":         true,
	}
	SIGNAL_EXIT_CODES = map[string]int{
		"SIGINT":  130,
		"SIGTERM": 143,
	}
	BUILD_REASON_LABELS = map[string]string{
		"force_build":              "forced by OPENCLAW_FORCE_BUILD",
		"missing_build_stamp":     "build stamp missing",
		"missing_dist_entry":       "dist entry missing",
		"config_newer":             "config newer than build stamp",
		"build_stamp_missing_head": "build stamp missing git head",
		"git_head_changed":         "git head changed",
		"dirty_watched_tree":       "dirty watched source tree",
		"source_mtime_newer":       "source mtime newer than build stamp",
		"clean":                    "clean",
	}
)

type Dependencies struct {
	spawn              func(string, []string, *exec.Cmd) (*exec.Cmd, error)
	spawnSync          func(string, []string, *exec.Cmd) ([]byte, error)
	fs                 fs.FS
	stderr             io.Writer
	process            *os.Process
	execPath           string
	cwd                string
	args               []string
	env                map[string]string
	runRuntimePostBuild func(map[string]interface{}) error
	distRoot           string
	distEntry          string
	buildStampPath     string
	sourceRoots        []struct {
		name string
		path string
	}
	configFiles []string
}

type BuildStamp struct {
	Mtime float64 `json:"mtime"`
	Head  string  `json:"head"`
}

type BuildRequirement struct {
	ShouldBuild bool   `json:"shouldBuild"`
	Reason      string `json:"reason"`
}

func normalizePath(filePath string) string {
	return strings.ReplaceAll(filePath, "\\", "/")
}

func isIgnoredSourcePath(relativePath string) bool {
	normalizedPath := normalizePath(relativePath)
	return strings.HasSuffix(normalizedPath, ".test.ts") ||
		strings.HasSuffix(normalizedPath, ".test.tsx") ||
		strings.HasSuffix(normalizedPath, "test-helpers.ts")
}

func isBuildRelevantSourcePath(relativePath string) bool {
	normalizedPath := normalizePath(relativePath)
	return extensionSourceFilePattern.MatchString(normalizedPath) && !isIgnoredSourcePath(normalizedPath)
}

func isBuildRelevantRunNodePath(repoPath string) bool {
	normalizedPath := strings.TrimLeft(normalizePath(repoPath), "./")
	for _, configFile := range runNodeConfigFiles {
		if normalizedPath == configFile {
			return true
		}
	}
	if strings.HasPrefix(normalizedPath, "src/") {
		return !isIgnoredSourcePath(strings.TrimPrefix(normalizedPath, "src/"))
	}
	if strings.HasPrefix(normalizedPath, BUNDLED_PLUGIN_PATH_PREFIX) {
		return isBuildRelevantSourcePath(strings.TrimPrefix(normalizedPath, BUNDLED_PLUGIN_PATH_PREFIX))
	}
	return false
}

func isRestartRelevantExtensionPath(relativePath string) bool {
	normalizedPath := normalizePath(relativePath)
	if extensionRestartMetadataFiles[filepath.Base(normalizedPath)] {
		return true
	}
	return isBuildRelevantSourcePath(normalizedPath)
}

func isRestartRelevantRunNodePath(repoPath string) bool {
	normalizedPath := strings.TrimLeft(normalizePath(repoPath), "./")
	for _, configFile := range runNodeConfigFiles {
		if normalizedPath == configFile {
			return true
		}
	}
	if strings.HasPrefix(normalizedPath, "src/") {
		return !isIgnoredSourcePath(strings.TrimPrefix(normalizedPath, "src/"))
	}
	if strings.HasPrefix(normalizedPath, BUNDLED_PLUGIN_PATH_PREFIX) {
		return isRestartRelevantExtensionPath(strings.TrimPrefix(normalizedPath, BUNDLED_PLUGIN_PATH_PREFIX))
	}
	return false
}

func statMtime(filePath string) (float64, error) {
	info, err := os.Stat(filePath)
	if err != nil {
		return 0, err
	}
	return float64(info.ModTime().UnixNano()) / 1e6, nil
}

func isExcludedSource(filePath, sourceRoot, sourceRootName string) bool {
	relPath, err := filepath.Rel(sourceRoot, filePath)
	if err != nil {
		return false
	}
	relativePath := normalizePath(relPath)
	if strings.HasPrefix(relativePath, "..") {
		return false
	}
	return !isBuildRelevantRunNodePath(filepath.Join(sourceRootName, relativePath))
}

func findLatestMtime(dirPath string, shouldSkip func(string) bool) (float64, error) {
	var latest float64
	queue := []string{dirPath}

	for len(queue) > 0 {
		current := queue[len(queue)-1]
		queue = queue[:len(queue)-1]

		entries, err := os.ReadDir(current)
		if err != nil {
			continue
		}

		for _, entry := range entries {
			fullPath := filepath.Join(current, entry.Name())
			if entry.IsDir() {
				queue = append(queue, fullPath)
				continue
			}
			if !entry.Type().IsRegular() {
				continue
			}
			if shouldSkip != nil && shouldSkip(fullPath) {
				continue
			}
			mtime, err := statMtime(fullPath)
			if err != nil {
				continue
			}
			if latest == 0 || mtime > latest {
				latest = mtime
			}
		}
	}
	return latest, nil
}

func readGitStatus() (string, error) {
	cmd := exec.Command("git", append([]string{"status", "--porcelain", "--untracked-files=normal", "--"}, runNodeWatchedPaths...)...)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func parseGitStatusPaths(output string) []string {
	lines := strings.Split(output, "\n")
	var paths []string
	for _, line := range lines {
		if len(line) < 4 {
			continue
		}
		parts := strings.Split(line[3:], " -> ")
		for _, part := range parts {
			trimmed := strings.TrimSpace(part)
			if trimmed != "" {
				paths = append(paths, normalizePath(trimmed))
			}
		}
	}
	return paths
}

func hasDirtySourceTree() (bool, error) {
	output, err := readGitStatus()
	if err != nil {
		return false, err
	}
	paths := parseGitStatusPaths(output)
	for _, repoPath := range paths {
		if isBuildRelevantRunNodePath(repoPath) {
			return true, nil
		}
	}
	return false, nil
}

func readBuildStamp(buildStampPath string) (*BuildStamp, error) {
	content, err := os.ReadFile(buildStampPath)
	if err != nil {
		return &BuildStamp{Mtime: 0, Head: ""}, err
	}
	raw := strings.TrimSpace(string(content))
	if !strings.HasPrefix(raw, "{") {
		return &BuildStamp{Mtime: 0, Head: ""}, nil
	}
	var stamp BuildStamp
	err = json.Unmarshal([]byte(raw), &stamp)
	if err != nil {
		return &BuildStamp{Mtime: 0, Head: ""}, err
	}
	stamp.Head = strings.TrimSpace(stamp.Head)
	return &stamp, nil
}

func hasSourceMtimeChanged(stampMtime float64, sourceRoots []struct{ name, path string }) (bool, error) {
	var latestSourceMtime float64
	for _, sourceRoot := range sourceRoots {
		sourceMtime, err := findLatestMtime(sourceRoot.path, func(candidate string) bool {
			return isExcludedSource(candidate, sourceRoot.path, sourceRoot.name)
		})
		if err != nil {
			continue
		}
		if latestSourceMtime == 0 || sourceMtime > latestSourceMtime {
			latestSourceMtime = sourceMtime
		}
	}
	return latestSourceMtime > 0 && latestSourceMtime > stampMtime, nil
}

func resolveGitHead() (string, error) {
	cmd := exec.Command("git", "rev-parse", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func resolveBuildRequirement(deps *Dependencies) (*BuildRequirement, error) {
	if deps.env["OPENCLAW_FORCE_BUILD"] == "1" {
		return &BuildRequirement{ShouldBuild: true, Reason: "force_build"}, nil
	}

	stamp, err := readBuildStamp(deps.buildStampPath)
	if err != nil || stamp.Mtime == 0 {
		return &BuildRequirement{ShouldBuild: true, Reason: "missing_build_stamp"}, nil
	}

	if _, err := os.Stat(deps.distEntry); os.IsNotExist(err) {
		return &BuildRequirement{ShouldBuild: true, Reason: "missing_dist_entry"}, nil
	}

	for _, filePath := range deps.configFiles {
		mtime, err := statMtime(filePath)
		if err != nil {
			continue
		}
		if mtime > stamp.Mtime {
			return &BuildRequirement{ShouldBuild: true, Reason: "config_newer"}, nil
		}
	}

	currentHead, err := resolveGitHead()
	if err == nil {
		if stamp.Head == "" {
			return &BuildRequirement{ShouldBuild: true, Reason: "build_stamp_missing_head"}, nil
		}
		if currentHead != stamp.Head {
			return &BuildRequirement{ShouldBuild: true, Reason: "git_head_changed"}, nil
		}
		dirty, err := hasDirtySourceTree()
		if err == nil {
			if dirty {
				return &BuildRequirement{ShouldBuild: true, Reason: "dirty_watched_tree"}, nil
			} else {
				return &BuildRequirement{ShouldBuild: false, Reason: "clean"}, nil
			}
		}
	}

	sourceChanged, err := hasSourceMtimeChanged(stamp.Mtime, deps.sourceRoots)
	if err != nil {
		return nil, err
	}
	if sourceChanged {
		return &BuildRequirement{ShouldBuild: true, Reason: "source_mtime_newer"}, nil
	}
	return &BuildRequirement{ShouldBuild: false, Reason: "clean"}, nil
}

func formatBuildReason(reason string) string {
	if label, ok := BUILD_REASON_LABELS[reason]; ok {
		return label
	}
	return reason
}

func isSignalKey(signal string) bool {
	_, ok := SIGNAL_EXIT_CODES[signal]
	return ok
}

func getSignalExitCode(signal string) int {
	if code, ok := SIGNAL_EXIT_CODES[signal]; ok {
		return code
	}
	return 1
}

func logRunner(message string, deps *Dependencies) {
	if deps.env["OPENCLAW_RUNNER_LOG"] == "0" {
		return
	}
	fmt.Fprintf(deps.stderr, "[openclaw] %s\n", message)
}

func waitForSpawnedProcess(cmd *exec.Cmd) (int, error) {
	err := cmd.Wait()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			if status, ok := exitErr.Sys().(syscall.WaitStatus); ok {
				if status.Signaled() {
					sig := status.Signal().String()
					return getSignalExitCode(sig), nil
				}
				return exitErr.ExitCode(), nil
			}
		}
		return 1, err
	}
	return 0, nil
}

func runOpenClaw(deps *Dependencies) (int, error) {
	args := append([]string{"openclaw.mjs"}, deps.args...)
	cmd := exec.Command(deps.execPath, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = deps.cwd

	err := cmd.Start()
	if err != nil {
		return 1, err
	}

	return waitForSpawnedProcess(cmd)
}

func syncRuntimeArtifacts(deps *Dependencies) bool {
	err := deps.runRuntimePostBuild(map[string]interface{}{"cwd": deps.cwd})
	if err != nil {
		logRunner(fmt.Sprintf("Failed to write runtime build artifacts: %v", err), deps)
		return false
	}
	return true
}

func writeBuildStamp(deps *Dependencies) {
	head, err := resolveGitHead()
	if err != nil {
		logRunner(fmt.Sprintf("Failed to get git head: %v", err), deps)
		return
	}

	stamp := map[string]interface{}{
		"head": head,
		"time": time.Now().Format(time.RFC3339),
	}

	data, err := json.Marshal(stamp)
	if err != nil {
		logRunner(fmt.Sprintf("Failed to marshal build stamp: %v", err), deps)
		return
	}

	err = os.WriteFile(deps.buildStampPath, data, 0644)
	if err != nil {
		logRunner(fmt.Sprintf("Failed to write build stamp: %v", err), deps)
	}
}

func shouldSkipCleanWatchRuntimeSync(deps *Dependencies) bool {
	return deps.env["OPENCLAW_WATCH_MODE"] == "1"
}

func runNodeMain(params map[string]interface{}) (int, error) {
	deps := &Dependencies{
		spawn: func(name string, arg []string, cmd *exec.Cmd) (*exec.Cmd, error) {
			return exec.Command(name, arg...), nil
		},
		spawnSync: func(name string, arg []string, cmd *exec.Cmd) ([]byte, error) {
			return exec.Command(name, arg...).Output()
		},
		fs:      os.DirFS("."),
		stderr:  os.Stderr,
		process: os.Getpid(),
		execPath: func() string {
			if ep, ok := params["execPath"].(string); ok {
				return ep
			}
			return os.Args[0]
		}(),
		cwd: func() string {
			if c, ok := params["cwd"].(string); ok {
				return c
			}
			dir, _ := os.Getwd()
			return dir
		}(),
		args: func() []string {
			if a, ok := params["args"].([]string); ok {
				return a
			}
			return os.Args[1:]
		}(),
		env: func() map[string]string {
			if e, ok := params["env"].(map[string]string); ok {
				return e
			}
			envMap := make(map[string]string)
			for _, envVar := range os.Environ() {
				parts := strings.SplitN(envVar, "=", 2)
				if len(parts) == 2 {
					envMap[parts[0]] = parts[1]
				}
			}
			return envMap
		}(),
		runRuntimePostBuild: func(args map[string]interface{}) error {
			// Placeholder implementation
			return nil
		},
	}

	deps.distRoot = filepath.Join(deps.cwd, "dist")
	deps.distEntry = filepath.Join(deps.distRoot, "entry.js")
	deps.buildStampPath = filepath.Join(deps.distRoot, ".buildstamp")

	for _, sourceRoot := range runNodeSourceRoots {
		deps.sourceRoots = append(deps.sourceRoots, struct {
			name string
			path string
		}{
			name: sourceRoot,
			path: filepath.Join(deps.cwd, sourceRoot),
		})
	}

	for _, configFile := range runNodeConfigFiles {
		deps.configFiles = append(deps.configFiles, filepath.Join(deps.cwd, configFile))
	}

	buildRequirement, err := resolveBuildRequirement(deps)
	if err != nil {
		return 1, err
	}

	if !buildRequirement.ShouldBuild {
		if !shouldSkipCleanWatchRuntimeSync(deps) && !syncRuntimeArtifacts(deps) {
			return 1, nil
		}
		return runOpenClaw(deps)
	}

	logRunner(fmt.Sprintf("Building TypeScript (dist is stale: %s - %s).", buildRequirement.Reason, formatBuildReason(buildRequirement.Reason)), deps)

	buildCmd := deps.execPath
	buildArgs := compilerArgs
	cmd := exec.Command(buildCmd, buildArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = deps.cwd

	err = cmd.Start()
	if err != nil {
		return 1, err
	}

	exitCode, err := waitForSpawnedProcess(cmd)
	if err != nil {
		return 1, err
	}
	if exitCode != 0 {
		return exitCode, nil
	}

	if !syncRuntimeArtifacts(deps) {
		return 1, nil
	}

	writeBuildStamp(deps)
	return runOpenClaw(deps)
}

func main() {
	code, err := runNodeMain(make(map[string]interface{}))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	os.Exit(code)
}
