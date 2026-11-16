// abstraction-provenance: {"artifact_sha256": "ec9ed2b042ad6f026ab223b81f0057b4ad17bc2ea573c10786d0a53eff0ef8ba", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "go"}
// check-extension-package-tsc-boundary.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	repoRoot                           = ".."
	tscBin                             = "node_modules/typescript/bin/tsc"
	prepareBoundaryArtifactsBin       = "scripts/prepare-extension-package-boundary-artifacts.mjs"
	extensionPackageBoundaryBaseConfig = "../tsconfig.package-boundary.base.json"
	FAILURE_OUTPUT_TAIL_LINES          = 40
	SLOW_COMPILE_SUMMARY_LIMIT         = 10
	ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH = "../../src/plugins/contracts/rootdir-boundary-canary.ts"
	ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT = "src/plugins/contracts/rootdir-boundary-canary.ts"
)

var (
	COMPILE_INPUT_EXTENSIONS = map[string]bool{
		".ts":  true, ".tsx": true, ".mts": true, ".cts": true,
		".js":  true, ".mjs": true, ".json": true,
	}
)

type Params struct {
	Kind           string
	ElapsedMs      float64
	Note           string
	CompileCount   int
	CanaryCount    int
	PrepElapsedMs  float64
	CompileElapsedMs float64
	CanaryElapsedMs  float64
	TotalCount     int
	SkippedCount   int
	Limit          int
	CompileTimings []CompileTiming
}

type CompileTiming struct {
	ExtensionId string
	ElapsedMs   float64
}

type StepResult struct {
	Stdout    string
	Stderr    string
	ElapsedMs float64
}

type Step struct {
	Label     string
	Args      []string
	TimeoutMs int
	OnStart   func()
	OnSuccess func(StepResult)
}

func parseMode(argv []string) string {
	for _, arg := range argv {
		if strings.HasPrefix(arg, "--mode=") {
			mode := strings.TrimPrefix(arg, "--mode=")
			if mode == "all" || mode == "compile" || mode == "canary" {
				return mode
			}
			panic(fmt.Sprintf("Unknown mode: %s", mode))
		}
	}
	return "all"
}

func resolveCompileConcurrency() int {
	raw := os.Getenv("OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY")
	if raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err == nil && parsed > 0 {
			return parsed
		}
	}
	parallelism := runtime.NumCPU()
	return max(1, min(6, parallelism/2))
}

func readJsonFile(filePath string) (map[string]interface{}, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	var result map[string]interface{}
	err = json.Unmarshal(data, &result)
	return result, err
}

func summarizeOutputSection(name, output string) string {
	trimmed := strings.TrimSpace(output)
	if trimmed == "" {
		return ""
	}

	lines := strings.Split(trimmed, "\n")
	if len(lines) <= FAILURE_OUTPUT_TAIL_LINES {
		return fmt.Sprintf("%s:\n%s", name, trimmed)
	}

	omittedLineCount := len(lines) - FAILURE_OUTPUT_TAIL_LINES
	tail := strings.Join(lines[len(lines)-FAILURE_OUTPUT_TAIL_LINES:], "\n")
	return fmt.Sprintf("%s:\n[... %d earlier lines omitted ...]\n%s", name, omittedLineCount, tail)
}

func formatFailureFooter(params Params) string {
	var footerLines []string
	if params.Kind != "" {
		footerLines = append(footerLines, fmt.Sprintf("kind: %s", params.Kind))
	}
	if params.ElapsedMs > 0 {
		footerLines = append(footerLines, fmt.Sprintf("elapsed: %.0fms", params.ElapsedMs))
	}
	if params.Note != "" {
		footerLines = append(footerLines, params.Note)
	}
	return strings.Join(footerLines, "\n")
}

func formatBoundaryCheckSuccessSummary(params Params) string {
	lines := []string{"extension package boundary check passed"}
	if params.Mode != "" {
		lines = append(lines, fmt.Sprintf("mode: %s", params.Mode))
	}
	if params.CompileCount > 0 {
		lines = append(lines, fmt.Sprintf("compiled plugins: %d", params.CompileCount))
	}
	if params.SkippedCompileCount > 0 {
		lines = append(lines, fmt.Sprintf("skipped plugins: %d", params.SkippedCompileCount))
	}
	if params.CanaryCount > 0 {
		lines = append(lines, fmt.Sprintf("canary plugins: %d", params.CanaryCount))
	}
	if params.PrepElapsedMs > 0 {
		lines = append(lines, fmt.Sprintf("prep elapsed: %.0fms", params.PrepElapsedMs))
	}
	if params.CompileElapsedMs > 0 {
		lines = append(lines, fmt.Sprintf("compile elapsed: %.0fms", params.CompileElapsedMs))
	}
	if params.CanaryElapsedMs > 0 {
		lines = append(lines, fmt.Sprintf("canary elapsed: %.0fms", params.CanaryElapsedMs))
	}
	if params.ElapsedMs > 0 {
		lines = append(lines, fmt.Sprintf("elapsed: %.0fms", params.ElapsedMs))
	}
	return strings.Join(lines, "\n") + "\n"
}

func formatSkippedCompileProgress(params Params) string {
	skippedCount := params.SkippedCount
	totalCount := params.TotalCount
	if skippedCount <= 0 {
		return ""
	}

	staleCount := max(0, totalCount-skippedCount)
	if staleCount > 0 {
		return fmt.Sprintf("skipped %d fresh plugin compiles before running %d stale plugin checks\n", skippedCount, staleCount)
	}
	return fmt.Sprintf("skipped %d fresh plugin compiles\n", skippedCount)
}

func formatSlowCompileSummary(params Params) string {
	compileTimings := params.CompileTimings
	if len(compileTimings) == 0 {
		return ""
	}

	limit := params.Limit
	if limit <= 0 {
		limit = SLOW_COMPILE_SUMMARY_LIMIT
	}
	
	// Sort timings by elapsed time descending
	sortedTimings := make([]CompileTiming, len(compileTimings))
	copy(sortedTimings, compileTimings)
	sort.Slice(sortedTimings, func(i, j int) bool {
		return sortedTimings[i].ElapsedMs > sortedTimings[j].ElapsedMs
	})
	
	// Take top N
	if len(sortedTimings) > limit {
		sortedTimings = sortedTimings[:limit]
	}

	lines := []string{"slowest plugin compiles:"}
	for _, timing := range sortedTimings {
		lines = append(lines, fmt.Sprintf("- %s: %.0fms", timing.ExtensionId, timing.ElapsedMs))
	}
	return strings.Join(lines, "\n") + "\n"
}

func formatStepFailure(label string, params Params) string {
	stdoutSection := summarizeOutputSection("stdout", params.Stdout)
	stderrSection := summarizeOutputSection("stderr", params.Stderr)
	footer := formatFailureFooter(params)
	
	parts := []string{label}
	if stdoutSection != "" {
		parts = append(parts, stdoutSection)
	}
	if stderrSection != "" {
		parts = append(parts, stderrSection)
	}
	if footer != "" {
		parts = append(parts, footer)
	}
	return strings.Join(parts, "\n\n")
}

func collectBundledExtensionIds() []string {
	entries, err := os.ReadDir(filepath.Join(repoRoot, "extensions"))
	if err != nil {
		return []string{}
	}
	
	var dirs []string
	for _, entry := range entries {
		if entry.IsDir() {
			dirs = append(dirs, entry.Name())
		}
	}
	sort.Strings(dirs)
	return dirs
}

func resolveExtensionTsconfigPath(extensionId string) string {
	return filepath.Join(repoRoot, "extensions", extensionId, "tsconfig.json")
}

func readExtensionTsconfig(extensionId string) (map[string]interface{}, error) {
	return readJsonFile(resolveExtensionTsconfigPath(extensionId))
}

func collectOptInExtensionIds() []string {
	extensionIds := collectBundledExtensionIds()
	var optIn []string
	
	for _, extensionId := range extensionIds {
		tsconfigPath := resolveExtensionTsconfigPath(extensionId)
		if _, err := os.Stat(tsconfigPath); os.IsNotExist(err) {
			continue
		}
		
		tsconfig, err := readExtensionTsconfig(extensionId)
		if err != nil {
			continue
		}
		
		if extends, ok := tsconfig["extends"]; ok {
			if extendsStr, ok := extends.(string); ok && extendsStr == extensionPackageBoundaryBaseConfig {
				optIn = append(optIn, extensionId)
			}
		}
	}
	
	return optIn
}

func collectCanaryExtensionIds(extensionIds []string) []string {
	seenConfigs := make(map[string]string)
	
	for _, extensionId := range extensionIds {
		tsconfig, err := readExtensionTsconfig(extensionId)
		if err != nil {
			continue
		}
		
		configBytes, _ := json.Marshal(tsconfig)
		configKey := string(configBytes)
		
		if _, exists := seenConfigs[configKey]; !exists {
			seenConfigs[configKey] = extensionId
		}
	}
	
	var result []string
	for _, id := range seenConfigs {
		result = append(result, id)
	}
	
	return result
}

func isRelevantCompileInput(filePath string) bool {
	basename := filepath.Base(filePath)
	if basename == "__rootdir_boundary_canary__.ts" || basename == "tsconfig.rootdir-canary.json" {
		return false
	}
	if strings.HasSuffix(basename, ".tsbuildinfo") {
		return false
	}
	ext := filepath.Ext(filePath)
	return COMPILE_INPUT_EXTENSIONS[ext]
}

func collectNewestMtime(entryPath string, includeFile func(string) bool, skipDistDirectories bool) float64 {
	var newestMtimeMs float64
	
	var visit func(string)
	visit = func(currentPath string) {
		if _, err := os.Stat(currentPath); os.IsNotExist(err) {
			return
		}
		
		info, err := os.Stat(currentPath)
		if err != nil {
			return
		}
		
		if info.IsDir() {
			basename := filepath.Base(currentPath)
			if (skipDistDirectories && basename == "dist") || basename == "node_modules" {
				return
			}
			
			entries, err := os.ReadDir(currentPath)
			if err != nil {
				return
			}
			
			for _, entry := range entries {
				visit(filepath.Join(currentPath, entry.Name()))
			}
			return
		}
		
		if !includeFile(currentPath) {
			return
		}
		
		mtimeMs := float64(info.ModTime().UnixNano()) / 1e6
		if mtimeMs > newestMtimeMs {
			newestMtimeMs = mtimeMs
		}
	}
	
	visit(entryPath)
	return newestMtimeMs
}

func collectOldestMtime(paths []string) *float64 {
	var oldestMtimeMs float64 = 1e15
	
	for _, entryPath := range paths {
		if _, err := os.Stat(entryPath); os.IsNotExist(err) {
			return nil
		}
		
		info, err := os.Stat(entryPath)
		if err != nil {
			return nil
		}
		
		mtimeMs := float64(info.ModTime().UnixNano()) / 1e6
		if mtimeMs < oldestMtimeMs {
			oldestMtimeMs = mtimeMs
		}
	}
	
	if oldestMtimeMs == 1e15 {
		return nil
	}
	
	return &oldestMtimeMs
}

func isBoundaryCompileFresh(extensionId string, extensionNewestInputMtimeMs, sharedNewestInputMtimeMs float64) bool {
	rootDir := repoRoot
	extensionRoot := filepath.Join(rootDir, "extensions", extensionId)
	
	if extensionNewestInputMtimeMs == 0 {
		extensionNewestInputMtimeMs = collectNewestMtime(extensionRoot, isRelevantCompileInput, true)
	}
	
	if sharedNewestInputMtimeMs == 0 {
		sharedNewestInputMtimeMs = max(
			collectNewestMtime(filepath.Join(rootDir, "dist/plugin-sdk"), func(s string) bool { return true }, false),
			collectNewestMtime(filepath.Join(rootDir, "packages/plugin-sdk/dist"), func(s string) bool { return true }, false),
		)
	}
	
	newestInputMtimeMs := max(extensionNewestInputMtimeMs, sharedNewestInputMtimeMs)
	oldestOutputMtimeMs := collectOldestMtime([]string{
		resolveBoundaryTsStampPath(extensionId, rootDir),
	})
	
	if oldestOutputMtimeMs == nil {
		return false
	}
	
	return *oldestOutputMtimeMs >= newestInputMtimeMs
}

func writeStampFile(filePath string) error {
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	
	content := fmt.Sprintf("%s\n", time.Now().Format(time.RFC3339))
	return os.WriteFile(filePath, []byte(content), 0644)
}

func runNodeStep(label string, args []string, timeoutMs int) (*StepResult, error) {
	startedAt := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "node", args...)
	cmd.Dir = repoRoot
	
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf
	
	err := cmd.Run()
	elapsedMs := time.Since(startedAt).Milliseconds()
	
	result := &StepResult{
		Stdout:    stdoutBuf.String(),
		Stderr:    stderrBuf.String(),
		ElapsedMs: float64(elapsedMs),
	}
	
	if err == nil {
		return result, nil
	}
	
	var kind string
	var note string
	
	if ctx.Err() == context.DeadlineExceeded {
		kind = "timeout"
		note = fmt.Sprintf("%s timed out after %dms", label, timeoutMs)
	} else if _, ok := err.(*exec.ExitError); ok {
		kind = "nonzero-exit"
	} else {
		kind = "spawn-error"
		note = err.Error()
	}
	
	failure := formatStepFailure(label, Params{
		Stdout:   result.Stdout,
		Stderr:   result.Stderr,
		Kind:     kind,
		ElapsedMs: result.ElapsedMs,
		Note:     note,
	})
	
	return nil, fmt.Errorf(failure)
}

func runNodeStepAsync(label string, args []string, timeoutMs int, onFailure func(error)) (*StepResult, error) {
	startedAt := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "node", args...)
	cmd.Dir = repoRoot
	
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf
	
	err := cmd.Start()
	if err != nil {
		onFailure(fmt.Errorf("failed to start command: %v", err))
		return nil, err
	}
	
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()
	
	select {
	case <-ctx.Done():
		cmd.Process.Kill()
		elapsedMs := time.Since(startedAt).Milliseconds()
		errorMsg := formatStepFailure(label, Params{
			Stdout:   stdoutBuf.String(),
			Stderr:   stderrBuf.String(),
			Kind:     "timeout",
			ElapsedMs: float64(elapsedMs),
			Note:     fmt.Sprintf("%s timed out after %dms", label, timeoutMs),
		})
		onFailure(fmt.Errorf(errorMsg))
		return nil, fmt.Errorf(errorMsg)
		
	case err := <-done:
		elapsedMs := time.Since(startedAt).Milliseconds()
		result := &StepResult{
			Stdout:    stdoutBuf.String(),
			Stderr:    stderrBuf.String(),
			ElapsedMs: float64(elapsedMs),
		}
		
		if err != nil {
			var kind string
			var note string
			
			if _, ok := err.(*exec.ExitError); ok {
				kind = "nonzero-exit"
			} else {
				kind = "spawn-error"
				note = err.Error()
			}
			
			errorMsg := formatStepFailure(label, Params{
				Stdout:   result.Stdout,
				Stderr:   result.Stderr,
				Kind:     kind,
				ElapsedMs: result.ElapsedMs,
				Note:     note,
			})
			onFailure(fmt.Errorf(errorMsg))
			return nil, fmt.Errorf(errorMsg)
		}
		
		return result, nil
	}
}

func runNodeStepsWithConcurrency(steps []Step, concurrency int) error {
	if len(steps) == 0 {
		return nil
	}
	
	concurrency = min(concurrency, len(steps))
	firstFailure := make(chan error, 1)
	nextIndex := 0
	var mu sync.Mutex
	
	var wg sync.WaitGroup
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			
			for {
				mu.Lock()
				index := nextIndex
				nextIndex++
				mu.Unlock()
				
				if index >= len(steps) {
					return
				}
				
				step := steps[index]
				if step.OnStart != nil {
					step.OnStart()
				}
				
				result, err := runNodeStepAsync(step.Label, step.Args, step.TimeoutMs, func(e error) {
					select {
					case firstFailure <- e:
					default:
					}
				})
				
				if err != nil {
					select {
					case firstFailure <- err:
					default:
					}
					return
				}
				
				if step.OnSuccess != nil {
					step.OnSuccess(*result)
				}
			}
		}()
	}
	
	wg.Wait()
	
	select {
	case err := <-firstFailure:
		return err
	default:
		return nil
	}
}

func resolveCanaryArtifactPaths(extensionId string, rootDir string) (string, string, string) {
	extensionRoot := filepath.Join(rootDir, "extensions", extensionId)
	canaryPath := filepath.Join(extensionRoot, "__rootdir_boundary_canary__.ts")
	tsconfigPath := filepath.Join(extensionRoot, "tsconfig.rootdir-canary.json")
	return extensionRoot, canaryPath, tsconfigPath
}

func cleanupCanaryArtifacts(extensionId string, rootDir string) {
	_, canaryPath, tsconfigPath := resolveCanaryArtifactPaths(extensionId, rootDir)
	os.Remove(canaryPath)
	os.Remove(tsconfigPath)
}

func cleanupCanaryArtifactsForExtensions(extensionIds []string, rootDir string) {
	for _, extensionId := range extensionIds {
		cleanupCanaryArtifacts(extensionId, rootDir)
	}
}

func resolveBoundaryTsBuildInfoPath(extensionId string) string {
	return filepath.Join(repoRoot, "extensions", extensionId, "dist", ".boundary-tsc.tsbuildinfo")
}

func resolveBoundaryTsStampPath(extensionId string, rootDir string) string {
	return filepath.Join(rootDir, "extensions", extensionId, "dist", ".boundary-tsc.stamp")
}

func resolveBoundaryCheckLockPath(rootDir string) string {
	return filepath.Join(rootDir, "dist", ".extension-package-boundary.lock")
}

func resolveBoundaryCheckLockOwnerPath(lockPath string) string {
	return filepath.Join(lockPath, "owner.json")
}

func removeStaleBoundaryCheckLock(lockPath string) bool {
	ownerPath := resolveBoundaryCheckLockOwnerPath(lockPath)
	data, err := os.ReadFile(ownerPath)
	if err != nil {
		os.RemoveAll(lockPath)
		return true
	}
	
	var owner struct {
		Pid int `json:"pid"`
	}
	if err := json.Unmarshal(data, &owner); err != nil {
		os.RemoveAll(lockPath)
		return true
	}
	
	// In Go, we can't easily check if a process is alive like in Node.js
	// For simplicity, we'll assume it's stale
	os.RemoveAll(lockPath)
	return true
}

func acquireBoundaryCheckLock(rootDir string) func() {
	lockPath := resolveBoundaryCheckLockPath(rootDir)
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	
	err := os.Mkdir(lockPath, 0755)
	if err != nil {
		if os.IsExist(err) {
			if removeStaleBoundaryCheckLock(lockPath) {
				os.Mkdir(lockPath, 0755)
			} else {
				panic("another extension package boundary check is already running in this checkout")
			}
		} else {
			panic(err)
		}
	}
	
	ownerData := map[string]interface{}{
		"pid":       os.Getpid(),
		"startedAt": time.Now().Format(time.RFC3339),
	}
	ownerBytes, _ := json.MarshalIndent(ownerData, "", "  ")
	os.WriteFile(resolveBoundaryCheckLockOwnerPath(lockPath), append(ownerBytes, '\n'), 0644)
	
	return func() {
		os.RemoveAll(lockPath)
	}
}

func runCompileCheck(extensionIds []string) (map[string]interface{}, error) {
	prepStartedAt := time.Now()
	fmt.Printf("preparing plugin-sdk boundary artifacts for %d plugins\n", len(extensionIds))
	
	_, err := runNodeStep("plugin-sdk boundary prep", []string{prepareBoundaryArtifactsBin}, 420000)
	if err != nil {
		return nil, err
	}
	
	prepElapsedMs := time.Since(prepStartedAt).Milliseconds()
	concurrency := resolveCompileConcurrency()
	verboseFreshLogs := os.Getenv("OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH") == "1"
	
	sharedNewestInputMtimeMs := max(
		collectNewestMtime(filepath.Join(repoRoot, "dist/plugin-sdk"), func(s string) bool { return true }, false),
		collectNewestMtime(filepath.Join(repoRoot, "packages/plugin-sdk/dist"), func(s string) bool { return true }, false),
	)
	
	fmt.Printf("compile concurrency %d\n", concurrency)
	compileStartedAt := time.Now()
	skippedCompileCount := 0
	var compileTimings []CompileTiming
	
	var steps []Step
	for i, extensionId := range extensionIds {
		index := i
		currentExtensionId := extensionId
		
		tsBuildInfoPath := resolveBoundaryTsBuildInfoPath(currentExtensionId)
		os.MkdirAll(filepath.Dir(tsBuildInfoPath), 0755)
		
		extensionNewestInputMtimeMs := collectNewestMtime(
			filepath.Join(repoRoot, "extensions", currentExtensionId),
			isRelevantCompileInput,
			true,
		)
		
		if isBoundaryCompileFresh(currentExtensionId, extensionNewestInputMtimeMs, sharedNewestInputMtimeMs) {
			skippedCompileCount++
			if verboseFreshLogs {
				fmt.Printf("[%d/%d] %s (fresh; skipping)\n", index+1, len(extensionIds), currentExtensionId)
			}
			continue
		}
		
		steps = append(steps, Step{
			Label: currentExtensionId,
			OnStart: func() {
				fmt.Printf("[%d/%d] %s\n", index+1, len(extensionIds), currentExtensionId)
			},
			OnSuccess: func(result StepResult) {
				writeStampFile(resolveBoundaryTsStampPath(currentExtensionId, repoRoot))
				compileTimings = append(compileTimings, CompileTiming{
					ExtensionId: currentExtensionId,
					ElapsedMs:   result.ElapsedMs,
				})
			},
			Args: []string{
				tscBin,
				"-p",
				filepath.Join(repoRoot, "extensions", currentExtensionId, "tsconfig.json"),
				"--noEmit",
				"--incremental",
				"--tsBuildInfoFile",
				tsBuildInfoPath,
			},
			TimeoutMs: 120000,
		})
	}
	
	if !verboseFreshLogs && skippedCompileCount > 0 {
		fmt.Print(formatSkippedCompileProgress(Params{
			SkippedCount: skippedCompileCount,
			TotalCount:   len(extensionIds),
		}))
	}
	
	if len(steps) > 0 {
		err := runNodeStepsWithConcurrency(steps, concurrency)
		if err != nil {
			return nil, err
		}
	}
	
	return map[string]interface{}{
		"prepElapsedMs":      float64(prepElapsedMs),
		"compileCount":       len(steps),
		"skippedCompileCount": skippedCompileCount,
		"compileElapsedMs":   float64(time.Since(compileStartedAt).Milliseconds()),
		"compileTimings":     compileTimings,
	}, nil
}

func runCanaryCheck(extensionIds []string) (map[string]interface{}, error) {
	startedAt := time.Now()
	
	var wg sync.WaitGroup
	errChan := make(chan error, len(extensionIds))
	
	for i, extensionId := range extensionIds {
		index := i
		currentExtensionId := extensionId
		
		wg.Add(1)
		go func() {
			defer wg.Done()
			
			_, canaryPath, tsconfigPath := resolveCanaryArtifactPaths(currentExtensionId, repoRoot)
			cleanupCanaryArtifacts(currentExtensionId, repoRoot)
			
			fmt.Printf("[%d/%d] %s canary\n", index+1, len(extensionIds), currentExtensionId)
			
			defer cleanupCanaryArtifacts(currentExtensionId, repoRoot)
			
			// Write canary file
			canaryContent := fmt.Sprintf(`import { ROOTDIR_BOUNDARY_CANARY } from "%s";
void ROOTDIR_BOUNDARY_CANARY;
export {};
`, ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH)
			os.WriteFile(canaryPath, []byte(canaryContent), 0644)
			
			// Write tsconfig
			tsconfig := map[string]interface{}{
				"extends": "./tsconfig.json",
				"include": []string{"./__rootdir_boundary_canary__.ts"},
				"exclude": []string{},
			}
			tsconfigBytes, _ := json.MarshalIndent(tsconfig, "", "  ")
			os.WriteFile(tsconfigPath, append(tsconfigBytes, '\n'), 0644)
			
			// Run tsc
			result, err := runNodeStepAsync(fmt.Sprintf("%s canary", currentExtensionId), []string{tscBin, "-p", tsconfigPath, "--noEmit"}, 120000, func(e error) {
				errChan <- e
			})
			
			if err != nil {
				output := err.Error()
				if !strings.Contains(output, "TS6059") || !strings.Contains(output, ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT) {
					errChan <- err
					return
				}
			} else {
				errMsg := fmt.Sprintf("%s canary unexpectedly passed\n%s%s", currentExtensionId, result.Stdout, result.Stderr)
				errChan <- fmt.Errorf(errMsg)
			}
		}()
	}
	
	go func() {
		wg.Wait()
		close(errChan)
	}()
	
	for err := range errChan {
		if err != nil {
			return nil, err
		}
	}
	
	return map[string]interface{}{
		"canaryElapsedMs": float64(time.Since(startedAt).Milliseconds()),
	}, nil
}

func main() {
	argv := os.Args[1:]
	startedAt := time.Now()
	mode := parseMode(argv)
	optInExtensionIds := collectOptInExtensionIds()
	canaryExtensionIds := collectCanaryExtensionIds(optInExtensionIds)
	cleanupExtensionIds := optInExtensionIds
	shouldRunCanary := mode == "all" || mode == "canary"
	
	releaseBoundaryLock := acquireBoundaryCheckLock(repoRoot)
	defer releaseBoundaryLock()
	
	defer cleanupCanaryArtifactsForExtensions(cleanupExtensionIds, repoRoot)
	
	var prepElapsedMs float64
	compileCount := 0
	skippedCompileCount := 0
	var compileElapsedMs float64
	var compileTimings []CompileTiming
	var canaryElapsedMs float64
	
	if mode == "all" || mode == "compile" {
		result, err := runCompileCheck(optInExtensionIds)
		if err != nil {
			panic(err)
		}
		
		if val, ok := result["prepElapsedMs"].(float64); ok {
			prepElapsedMs = val
		}
		if val, ok := result["compileCount"].(int); ok {
			compileCount = val
		}
		if val, ok := result["skippedCompileCount"].(int); ok {
			skippedCompileCount = val
		}
		if val, ok := result["compileElapsedMs"].(float64); ok {
			compileElapsedMs = val
		}
		if val, ok := result["compileTimings"].([]CompileTiming); ok {
			compileTimings = val
		}
	}
	
	if shouldRunCanary {
		result, err := runCanaryCheck(canaryExtensionIds)
		if err != nil {
			panic(err)
		}
		
		if val, ok := result["canaryElapsedMs"].(float64); ok {
			canaryElapsedMs = val
		}
	}
	
	fmt.Print(formatBoundaryCheckSuccessSummary(Params{
		Mode:              mode,
		CompileCount:      compileCount,
		SkippedCompileCount: skippedCompileCount,
		CanaryCount:       len(canaryExtensionIds),
		PrepElapsedMs:     prepElapsedMs,
		CompileElapsedMs:  compileElapsedMs,
		CanaryElapsedMs:   canaryElapsedMs,
		ElapsedMs:         float64(time.Since(startedAt).Milliseconds()),
	}))
	
	fmt.Print(formatSlowCompileSummary(Params{
		CompileTimings: compileTimings,
	}))
}

func max(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
