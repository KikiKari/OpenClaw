// abstraction-provenance: {"artifact_sha256": "95502fb1b7a0d3acece469d8081d4fe2b27de4d27e2c8182a45fdf86eeae6999", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "go"}
// profile-extension-memory.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	DEFAULT_CONCURRENCY           = 6
	DEFAULT_TIMEOUT_MS           = 90000
	DEFAULT_COMBINED_TIMEOUT_MS   = 180000
	DEFAULT_TOP                   = 10
	RSS_MARKER                    = "__OPENCLAW_MAX_RSS_KB__="
)

type Options struct {
	Extensions         []string
	Concurrency        int
	TimeoutMs          int
	CombinedTimeoutMs  int
	Top                int
	JsonPath           string
	SkipCombined       bool
}

type Result struct {
	Name               string
	Code               *int
	Signal             *string
	TimedOut           bool
	Stdout             string
	Stderr             string
	MaxRssMb           *float64
}

type EntryResult struct {
	Dir                string
	File               string
	Status             string
	MaxRssMb           *float64
	DeltaFromBaselineMb *float64
	StderrPreview      string
}

type Report struct {
	GeneratedAt        string                 `json:"generatedAt"`
	RepoRoot           string                 `json:"repoRoot"`
	SelectedExtensions []string              `json:"selectedExtensions"`
	Baseline           map[string]interface{} `json:"baseline"`
	Combined           *CombinedResult        `json:"combined"`
	Counts             map[string]int         `json:"counts"`
	Options            map[string]interface{} `json:"options"`
	TopByDeltaMb       []EntryResult          `json:"topByDeltaMb"`
	Results            []EntryResult          `json:"results"`
}

type CombinedResult struct {
	Status          string `json:"status"`
	MaxRssMb        *float64 `json:"maxRssMb"`
	StderrPreview   string `json:"stderrPreview"`
}

func printHelp() {
	fmt.Printf(`Usage: go run profile-extension-memory.go [options]

Profiles peak RSS for built bundled plugin entrypoints.
Run pnpm build first if you want stats for the latest source changes.

Options:
  --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
  --concurrency <n>        Number of per-extension workers (default: %d)
  --timeout-ms <ms>        Per-extension timeout in milliseconds (default: %d)
  --combined-timeout-ms <ms>
                           Combined-import timeout in milliseconds (default: %d)
  --top <n>                Show top N entries by delta from baseline (default: %d)
  --json <path>            Write full JSON report to this path
  --skip-combined          Skip the combined all-imports measurement
  --help                   Show this help

Examples:
  go run profile-extension-memory.go
  go run profile-extension-memory.go --extension discord
  go run profile-extension-memory.go --extension discord --extension telegram --skip-combined
`, DEFAULT_CONCURRENCY, DEFAULT_TIMEOUT_MS, DEFAULT_COMBINED_TIMEOUT_MS, DEFAULT_TOP)
}

func parsePositiveInt(raw string, flagName string) (int, error) {
	parsed, err := strconv.Atoi(raw)
	if err != nil || parsed <= 0 {
		return 0, fmt.Errorf("%s must be a positive integer", flagName)
	}
	return parsed, nil
}

func parseArgs(args []string) (*Options, error) {
	options := &Options{
		Extensions:        []string{},
		Concurrency:       DEFAULT_CONCURRENCY,
		TimeoutMs:         DEFAULT_TIMEOUT_MS,
		CombinedTimeoutMs: DEFAULT_COMBINED_TIMEOUT_MS,
		Top:               DEFAULT_TOP,
		JsonPath:          "",
		SkipCombined:      false,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--":
			continue
		case "--extension", "-e":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("%s requires a value", arg)
			}
			options.Extensions = append(options.Extensions, args[i+1])
			i++
		case "--concurrency":
			val, err := parsePositiveInt(args[i+1], arg)
			if err != nil {
				return nil, err
			}
			options.Concurrency = val
			i++
		case "--timeout-ms":
			val, err := parsePositiveInt(args[i+1], arg)
			if err != nil {
				return nil, err
			}
			options.TimeoutMs = val
			i++
		case "--combined-timeout-ms":
			val, err := parsePositiveInt(args[i+1], arg)
			if err != nil {
				return nil, err
			}
			options.CombinedTimeoutMs = val
			i++
		case "--top":
			val, err := parsePositiveInt(args[i+1], arg)
			if err != nil {
				return nil, err
			}
			options.Top = val
			i++
		case "--json":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("%s requires a value", arg)
			}
			absPath, err := filepath.Abs(args[i+1])
			if err != nil {
				return nil, err
			}
			options.JsonPath = absPath
			i++
		case "--skip-combined":
			options.SkipCombined = true
		case "--help", "-h":
			printHelp()
			os.Exit(0)
		default:
			return nil, fmt.Errorf("Unknown argument: %s", arg)
		}
	}

	return options, nil
}

func parseMaxRssMb(stderr string) *float64 {
	re := regexp.MustCompile(fmt.Sprintf(`^%s(\d+)\s*$`, RSS_MARKER))
	lines := strings.Split(stderr, "\n")
	var lastMatch string
	for _, line := range lines {
		if re.MatchString(line) {
			lastMatch = line
		}
	}
	
	if lastMatch != "" {
		matches := re.FindStringSubmatch(lastMatch)
		if len(matches) > 1 {
			kb, err := strconv.ParseFloat(matches[1], 64)
			if err == nil {
				mb := kb / 1024
				return &mb
			}
		}
	}
	return nil
}

func summarizeStderr(stderr string, lines int) string {
	if lines <= 0 {
		lines = 8
	}
	scanner := bufio.NewScanner(strings.NewReader(stderr))
	result := []string{}
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			result = append(result, line)
			if len(result) >= lines {
				break
			}
		}
	}
	return strings.Join(result, "\n")
}

func runCase(repoRoot string, env []string, hookPath string, name string, body string, timeoutMs int) (*Result, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()

	cmd := exec.CommandContext(ctx, os.Args[0], "--import", hookPath, "--input-type=module", "--eval", body)
	cmd.Dir = repoRoot
	cmd.Env = env
	cmd.Stdin = nil
	
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	var stdoutBuf, stderrBuf strings.Builder
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		io.Copy(&stdoutBuf, stdoutPipe)
	}()

	go func() {
		defer wg.Done()
		io.Copy(&stderrBuf, stderrPipe)
	}()

	err = cmd.Start()
	if err != nil {
		return nil, err
	}

	wg.Wait()
	err = cmd.Wait()
	
	result := &Result{
		Name:     name,
		Stdout:   stdoutBuf.String(),
		Stderr:   stderrBuf.String(),
		MaxRssMb: parseMaxRssMb(stderrBuf.String()),
	}

	if ctx.Err() == context.DeadlineExceeded {
		result.TimedOut = true
	} else {
		result.TimedOut = false
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				code := exitError.ExitCode()
				result.Code = &code
				if exitError.ProcessState != nil && exitError.ProcessState.Sys() != nil {
					// Signal information is platform-specific
					signalStr := fmt.Sprintf("%v", exitError.ProcessState.Sys())
					result.Signal = &signalStr
				}
			} else {
				// Other error types
				code := -1
				result.Code = &code
			}
		} else {
			code := 0
			result.Code = &code
		}
	}

	return result, nil
}

func buildImportBody(entryFiles []string, label string) string {
	imports := []string{}
	for _, filePath := range entryFiles {
		imports = append(imports, fmt.Sprintf("await import(%s);", strconv.Quote(filePath)))
	}
	return strings.Join(imports, "\n") + fmt.Sprintf("\nconsole.log(%s);\nprocess.exit(0);\n", strconv.Quote(label))
}

func findExtensionEntries(repoRoot string) ([]map[string]string, error) {
	extensionsDir := filepath.Join(repoRoot, "dist", "extensions")
	if _, err := os.Stat(extensionsDir); os.IsNotExist(err) {
		return nil, fmt.Errorf("dist/extensions not found. Run pnpm build first.")
	}

	entries := []map[string]string{}
	dirEntries, err := os.ReadDir(extensionsDir)
	if err != nil {
		return nil, err
	}

	for _, dirEntry := range dirEntries {
		if dirEntry.IsDir() {
			filePath := filepath.Join(extensionsDir, dirEntry.Name(), "index.js")
			if _, err := os.Stat(filePath); err == nil {
				entries = append(entries, map[string]string{
					"dir":  dirEntry.Name(),
					"file": filePath,
				})
			}
		}
	}

	// Sort by directory name
	sort.Slice(entries, func(i, j int) bool {
		return entries[i]["dir"] < entries[j]["dir"]
	})

	if len(entries) == 0 {
		return nil, fmt.Errorf("No built bundled plugin entrypoints found in the dist plugin tree")
	}
	return entries, nil
}

func main() {
	options, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] %v\n", err)
		os.Exit(1)
	}

	repoRoot, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to get current directory: %v\n", err)
		os.Exit(1)
	}

	allEntries, err := findExtensionEntries(repoRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] %v\n", err)
		os.Exit(1)
	}

	selectedEntries := allEntries
	if len(options.Extensions) > 0 {
		selectedEntries = []map[string]string{}
		for _, entry := range allEntries {
			for _, ext := range options.Extensions {
				if entry["dir"] == ext {
					selectedEntries = append(selectedEntries, entry)
					break
				}
			}
		}
	}

	// Check for missing extensions
	missing := []string{}
	for _, ext := range options.Extensions {
		found := false
		for _, entry := range allEntries {
			if entry["dir"] == ext {
				found = true
				break
			}
		}
		if !found {
			missing = append(missing, ext)
		}
	}
	if len(missing) > 0 {
		fmt.Fprintf(os.Stderr, "[extension-memory] Unknown built extension ids: %s\n", strings.Join(missing, ", "))
		os.Exit(1)
	}
	if len(selectedEntries) == 0 {
		fmt.Fprintf(os.Stderr, "[extension-memory] No extensions selected for profiling\n")
		os.Exit(1)
	}

	tmpHome, err := os.MkdirTemp("", "openclaw-extension-memory-")
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to create temp directory: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmpHome)

	hookPath := filepath.Join(tmpHome, "measure-rss.mjs")
	jsonPath := options.JsonPath
	if jsonPath == "" {
		jsonPath = filepath.Join(os.TempDir(), "openclaw-extension-memory.json")
	}

	hookContent := `process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('` + RSS_MARKER + `' + String(usage.maxRSS));
});
`
	err = os.WriteFile(hookPath, []byte(hookContent), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to write hook file: %v\n", err)
		os.Exit(1)
	}

	env := os.Environ()
	newEnv := []string{}
	for _, e := range env {
		if !strings.HasPrefix(e, "HOME=") && 
		   !strings.HasPrefix(e, "USERPROFILE=") && 
		   !strings.HasPrefix(e, "XDG_CONFIG_HOME=") && 
		   !strings.HasPrefix(e, "XDG_DATA_HOME=") && 
		   !strings.HasPrefix(e, "XDG_CACHE_HOME=") && 
		   !strings.HasPrefix(e, "NODE_DISABLE_COMPILE_CACHE=") && 
		   !strings.HasPrefix(e, "OPENCLAW_NO_RESPAWN=") && 
		   !strings.HasPrefix(e, "TERM=") && 
		   !strings.HasPrefix(e, "LANG=") {
			newEnv = append(newEnv, e)
		}
	}
	
	newEnv = append(newEnv, "HOME="+tmpHome)
	newEnv = append(newEnv, "USERPROFILE="+tmpHome)
	newEnv = append(newEnv, "XDG_CONFIG_HOME="+filepath.Join(tmpHome, ".config"))
	newEnv = append(newEnv, "XDG_DATA_HOME="+filepath.Join(tmpHome, ".local", "share"))
	newEnv = append(newEnv, "XDG_CACHE_HOME="+filepath.Join(tmpHome, ".cache"))
	newEnv = append(newEnv, "NODE_DISABLE_COMPILE_CACHE=1")
	newEnv = append(newEnv, "OPENCLAW_NO_RESPAWN=1")
	
	if !hasEnv(env, "TERM") {
		newEnv = append(newEnv, "TERM=dumb")
	}
	if !hasEnv(env, "LANG") {
		newEnv = append(newEnv, "LANG=C.UTF-8")
	}

	env = newEnv

	baseline, err := runCase(repoRoot, env, hookPath, "baseline", "process.exit(0)", options.TimeoutMs)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to run baseline: %v\n", err)
		os.Exit(1)
	}

	var combined *Result = nil
	if !options.SkipCombined {
		entryFiles := []string{}
		for _, entry := range selectedEntries {
			entryFiles = append(entryFiles, entry["file"])
		}
		body := buildImportBody(entryFiles, "IMPORTED_ALL")
		combined, err = runCase(repoRoot, env, hookPath, "combined", body, options.CombinedTimeoutMs)
		if err != nil {
			fmt.Fprintf(os.Stderr, "[extension-memory] Failed to run combined: %v\n", err)
			os.Exit(1)
		}
	}

	pending := make(chan map[string]string, len(selectedEntries))
	for _, entry := range selectedEntries {
		pending <- entry
	}
	close(pending)

	resultsChan := make(chan EntryResult, len(selectedEntries))

	worker := func(wg *sync.WaitGroup) {
		defer wg.Done()
		for entry := range pending {
			body := buildImportBody([]string{entry["file"]}, "IMPORTED")
			result, err := runCase(repoRoot, env, hookPath, entry["dir"], body, options.TimeoutMs)
			if err != nil {
				fmt.Fprintf(os.Stderr, "[extension-memory] Failed to run %s: %v\n", entry["dir"], err)
				continue
			}

			status := "fail"
			if result.TimedOut {
				status = "timeout"
			} else if result.Code != nil && *result.Code == 0 {
				status = "ok"
			}

			deltaFromBaselineMb := (*float64)(nil)
			if result.MaxRssMb != nil && baseline.MaxRssMb != nil {
				diff := *result.MaxRssMb - *baseline.MaxRssMb
				deltaFromBaselineMb = &diff
			}

			entryResult := EntryResult{
				Dir:                entry["dir"],
				File:               entry["file"],
				Status:             status,
				MaxRssMb:           result.MaxRssMb,
				DeltaFromBaselineMb: deltaFromBaselineMb,
				StderrPreview:      summarizeStderr(result.Stderr, 0),
			}

			resultsChan <- entryResult

			rss := "n/a"
			if result.MaxRssMb != nil {
				rss = fmt.Sprintf("%.1f MB", *result.MaxRssMb)
			}
			fmt.Printf("[extension-memory] %s: %s %s\n", entry["dir"], status, rss)
		}
	}

	numWorkers := int(math.Min(float64(options.Concurrency), float64(len(selectedEntries))))
	var wg sync.WaitGroup
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go worker(&wg)
	}
	wg.Wait()
	close(resultsChan)

	results := []EntryResult{}
	for result := range resultsChan {
		results = append(results, result)
	}

	// Sort results by directory name
	sort.Slice(results, func(i, j int) bool {
		return results[i].Dir < results[j].Dir
	})

	// Filter and sort top entries
	top := []EntryResult{}
	okResults := []EntryResult{}
	for _, entry := range results {
		if entry.Status == "ok" && entry.DeltaFromBaselineMb != nil {
			okResults = append(okResults, entry)
		}
	}

	sort.Slice(okResults, func(i, j int) bool {
		return *okResults[i].DeltaFromBaselineMb > *okResults[j].DeltaFromBaselineMb
	})

	for i := 0; i < int(math.Min(float64(len(okResults)), float64(options.Top))); i++ {
		top = append(top, okResults[i])
	}

	// Count statuses
	counts := map[string]int{
		"totalEntries": len(selectedEntries),
		"ok":           0,
		"fail":         0,
		"timeout":      0,
	}
	for _, entry := range results {
		counts[entry.Status]++
	}

	// Build report
	report := Report{
		GeneratedAt:        time.Now().UTC().Format(time.RFC3339),
		RepoRoot:           repoRoot,
		SelectedExtensions: func() []string {
			exts := []string{}
			for _, entry := range selectedEntries {
				exts = append(exts, entry["dir"])
			}
			return exts
		}(),
		Baseline: map[string]interface{}{
			"status": func() string {
				if baseline.TimedOut {
					return "timeout"
				} else if baseline.Code != nil && *baseline.Code == 0 {
					return "ok"
				}
				return "fail"
			}(),
			"maxRssMb": baseline.MaxRssMb,
		},
		Combined: func() *CombinedResult {
			if combined == nil {
				return nil
			}
			status := "fail"
			if combined.TimedOut {
				status = "timeout"
			} else if combined.Code != nil && *combined.Code == 0 {
				status = "ok"
			}
			return &CombinedResult{
				Status:        status,
				MaxRssMb:      combined.MaxRssMb,
				StderrPreview: summarizeStderr(combined.Stderr, 12),
			}
		}(),
		Counts: counts,
		Options: map[string]interface{}{
			"concurrency":        options.Concurrency,
			"timeoutMs":          options.TimeoutMs,
			"combinedTimeoutMs":  options.CombinedTimeoutMs,
			"skipCombined":       options.SkipCombined,
		},
		TopByDeltaMb: top,
		Results:      results,
	}

	// Write JSON report
	reportData, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to marshal report: %v\n", err)
		os.Exit(1)
	}
	
	err = os.WriteFile(jsonPath, append(reportData, '\n'), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to write report: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("[extension-memory] report: %s\n", jsonPath)
	
	summary := map[string]interface{}{
		"baselineMb": func() interface{} {
			if baseline.MaxRssMb != nil {
				return *baseline.MaxRssMb
			}
			return nil
		}(),
		"combinedMb": func() interface{} {
			if report.Combined != nil && report.Combined.MaxRssMb != nil {
				return *report.Combined.MaxRssMb
			}
			return nil
		}(),
		"counts":     report.Counts,
		"topByDeltaMb": report.TopByDeltaMb,
	}
	
	summaryData, err := json.MarshalIndent(summary, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "[extension-memory] Failed to marshal summary: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(summaryData))
}

func hasEnv(env []string, key string) bool {
	for _, e := range env {
		if strings.HasPrefix(e, key+"=") {
			return true
		}
	}
	return false
}
