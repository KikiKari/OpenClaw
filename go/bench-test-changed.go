// abstraction-provenance: {"artifact_sha256": "fabea859bb1dfa9b86ff70afd51ff7595cc5783e3042827aa5ea7405eabb85e4", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "go"}
// bench-test-changed.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Options struct {
	Cwd       string
	Mode      string
	Ref       string
	Rss       bool
	MaxWorkers int
	Remaining []string
}

type Result struct {
	ElapsedMs float64
	MaxRssKb  *int
	Status    int
	Output    string
}

func main() {
	opts := parseArgs(os.Args[1:])
	changedPaths := listChangedPaths(opts)
	
	if len(changedPaths) == 0 {
		if opts.Mode == "worktree" {
			fmt.Println("[bench-test-changed] no changed paths in worktree")
		} else {
			fmt.Printf("[bench-test-changed] no changed paths for %s...HEAD\n", opts.Ref)
		}
		os.Exit(0)
	}

	if opts.Mode == "worktree" {
		fmt.Println("[bench-test-changed] mode=worktree")
	} else {
		fmt.Printf("[bench-test-changed] ref=%s\n", opts.Ref)
	}
	
	fmt.Println("[bench-test-changed] changed paths:")
	for _, changedPath := range changedPaths {
		fmt.Printf("- %s\n", changedPath)
	}

	var routedCommand []string
	if opts.Mode == "worktree" {
		routedCommand = append([]string{os.Args[0], "scripts/test-projects.mjs"}, changedPaths...)
	} else {
		routedCommand = []string{os.Args[0], "scripts/test-projects.mjs", "--changed", opts.Ref}
		routedCommand = append(routedCommand, changedPaths...)
	}
	
	rootCommand := []string{os.Args[0], "scripts/run-vitest.mjs", "run", "--config", "vitest.config.ts"}
	rootCommand = append(rootCommand, changedPaths...)

	fmt.Printf("[bench-test-changed] routed: %s\n", strings.Join(quoteArgs(routedCommand), " "))
	routed := runBenchCommand(routedCommand, opts.Cwd, opts.Rss, opts.MaxWorkers)
	if routed.Status != 0 {
		fmt.Fprint(os.Stderr, routed.Output)
		os.Exit(routed.Status)
	}

	fmt.Printf("[bench-test-changed] root:   %s\n", strings.Join(quoteArgs(rootCommand), " "))
	root := runBenchCommand(rootCommand, opts.Cwd, opts.Rss, opts.MaxWorkers)
	if root.Status != 0 {
		fmt.Fprint(os.Stderr, root.Output)
		os.Exit(root.Status)
	}

	printRunSummary("routed", routed)
	printRunSummary("root", root)
	
	deltaWall := root.ElapsedMs - routed.ElapsedMs
	var deltaRss string
	if routed.MaxRssKb != nil && root.MaxRssKb != nil {
		deltaRss = formatRss(*root.MaxRssKb - *routed.MaxRssKb)
	} else {
		deltaRss = "n/a"
	}
	
	fmt.Printf("[bench-test-changed] delta wall=%s rss=%s\n", formatMs(deltaWall), deltaRss)
}

func parseArgs(args []string) Options {
	opts := Options{
		Cwd:       getCurrentDir(),
		Ref:       "origin/main",
		Rss:       runtime.GOOS == "darwin",
		Mode:      "ref",
		MaxWorkers: 0,
		Remaining: []string{},
	}

	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--cwd":
			i++
			if i < len(args) {
				opts.Cwd, _ = filepath.Abs(args[i])
			}
		case "--ref":
			i++
			if i < len(args) {
				opts.Ref = args[i]
			}
		case "--max-workers":
			i++
			if i < len(args) {
				if val, err := strconv.ParseFloat(args[i], 64); err == nil {
					opts.MaxWorkers = int(math.Trunc(val))
				}
			}
		case "--no-rss":
			opts.Rss = false
		case "--worktree":
			opts.Mode = "worktree"
		default:
			opts.Remaining = append(opts.Remaining, arg)
		}
		i++
	}

	return opts
}

func quoteArgs(args []string) []string {
	result := make([]string, len(args))
	for i, arg := range args {
		result[i] = quoteArg(arg)
	}
	return result
}

func quoteArg(arg string) string {
	matched, _ := regexp.MatchString(`[^A-Za-z0-9_./:-]`, arg)
	if matched {
		return strconv.Quote(arg)
	}
	return arg
}

func runGitList(args []string, cwd string) ([]string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = cwd
	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("git %s failed: %s", strings.Join(args, " "), string(exitError.Stderr))
		}
		return nil, fmt.Errorf("git %s failed", strings.Join(args, " "))
	}
	
	lines := strings.Split(string(output), "\n")
	result := []string{}
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if len(trimmed) > 0 {
			result = append(result, trimmed)
		}
	}
	return result, nil
}

func listChangedPaths(opts Options) []string {
	if opts.Mode == "worktree" {
		changedHead, err := runGitList([]string{"diff", "--name-only", "--relative", "HEAD", "--"}, opts.Cwd)
		if err != nil {
			panic(err)
		}
		
		untracked, err := runGitList([]string{"ls-files", "--others", "--exclude-standard"}, opts.Cwd)
		if err != nil {
			panic(err)
		}
		
		// Combine and deduplicate
		unique := make(map[string]bool)
		result := []string{}
		for _, path := range append(changedHead, untracked...) {
			if !unique[path] {
				unique[path] = true
				result = append(result, path)
			}
		}
		
		// Sort
		for i := 0; i < len(result)-1; i++ {
			for j := i + 1; j < len(result); j++ {
				if result[i] > result[j] {
					result[i], result[j] = result[j], result[i]
				}
			}
		}
		
		return result
	}
	
	result, err := runGitList([]string{"diff", "--name-only", opts.Ref + "...HEAD"}, opts.Cwd)
	if err != nil {
		panic(err)
	}
	return result
}

func parseMaxRssKb(output string) *int {
	re := regexp.MustCompile(`(\d+)\s+maximum resident set size`)
	match := re.FindStringSubmatch(output)
	if match != nil {
		if val, err := strconv.Atoi(match[1]); err == nil {
			return &val
		}
	}
	return nil
}

func formatRss(valueKb int) string {
	return fmt.Sprintf("%.1fMB", float64(valueKb)/1024.0)
}

func formatMs(ms float64) string {
	return fmt.Sprintf("%.2fms", ms)
}

func runBenchCommand(command []string, cwd string, rss bool, maxWorkers int) Result {
	env := os.Environ()
	if maxWorkers > 0 {
		env = append(env, fmt.Sprintf("OPENCLAW_VITEST_MAX_WORKERS=%d", maxWorkers))
	}

	startedAt := time.Now()
	
	var cmd *exec.Cmd
	if rss {
		args := append([]string{"-l"}, command...)
		cmd = exec.Command("/usr/bin/time", args...)
	} else {
		cmd = exec.Command(command[0], command[1:]...)
	}
	
	cmd.Dir = cwd
	cmd.Env = env
	
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	
	err := cmd.Run()
	
	elapsedMs := float64(time.Since(startedAt)) / float64(time.Millisecond)
	output := stdout.String() + stderr.String()
	
	status := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			status = exitError.ExitCode()
		} else {
			status = 1
		}
	}
	
	var maxRssKb *int
	if rss {
		maxRssKb = parseMaxRssKb(output)
	}
	
	return Result{
		ElapsedMs: elapsedMs,
		MaxRssKb:  maxRssKb,
		Status:    status,
		Output:    output,
	}
}

func printRunSummary(label string, result Result) {
	wall := formatMs(result.ElapsedMs)
	rss := "n/a"
	if result.MaxRssKb != nil {
		rss = formatRss(*result.MaxRssKb)
	}
	
	fmt.Printf("%-8s wall=%9s rss=%9s\n", label, wall, rss)
}

func getCurrentDir() string {
	dir, err := os.Getwd()
	if err != nil {
		return "."
	}
	return dir
}
