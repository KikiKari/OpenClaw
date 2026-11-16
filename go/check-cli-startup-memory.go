// abstraction-provenance: {"artifact_sha256": "af766ff799a7da4a57f4a8493c8e8f5c4a1e2f56c58dc914e9c8ed6e7246e80e", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "go"}
// check-cli-startup-memory.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

const (
	MAX_RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="
)

type TestCase struct {
	ID       string
	Label    string
	Args     []string
	LimitMB  float64
}

type DefaultLimits struct {
	Help          float64
	StatusJSON    float64
	GatewayStatus float64
}

func main() {
	isLinux := runtime.GOOS == "linux"
	isMac := runtime.GOOS == "darwin"

	if !isLinux && !isMac {
		fmt.Printf("[startup-memory] Skipping on unsupported platform: %s\n", runtime.GOOS)
		os.Exit(0)
	}

	repoRoot, _ := os.Getwd()
	tmpHome, _ := ioutil.TempDir("", "openclaw-startup-memory-*")
	defer os.RemoveAll(tmpHome)

	tmpDir := getTempDir()
	rssHookPath := filepath.Join(tmpHome, "measure-rss.go")

	rssHookContent := `
package main

import (
	"fmt"
	"os"
	"runtime"
)

func main() {
	// This is a simplified version - Go doesn't have direct equivalent to process.resourceUsage
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	fmt.Fprintf(os.Stderr, "` + MAX_RSS_MARKER + `%d\n", m.Sys/1024)
}
`
	ioutil.WriteFile(rssHookPath, []byte(rssHookContent), 0644)

	// Build the RSS hook
	cmd := exec.Command("go", "build", "-o", filepath.Join(tmpHome, "measure-rss"), rssHookPath)
	cmd.Run()

	DEFAULT_LIMITS_MB := DefaultLimits{
		Help:          100,
		StatusJSON:    400,
		GatewayStatus: 500,
	}

	helpLimit := getEnvFloat("OPENCLAW_STARTUP_MEMORY_HELP_MB", DEFAULT_LIMITS_MB.Help)
	statusJSONLimit := getEnvFloat("OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB", DEFAULT_LIMITS_MB.StatusJSON)
	gatewayStatusLimit := getEnvFloat("OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB", DEFAULT_LIMITS_MB.GatewayStatus)

	cases := []TestCase{
		{
			ID:      "help",
			Label:   "--help",
			Args:    []string{"openclaw.go", "--help"},
			LimitMB: helpLimit,
		},
		{
			ID:      "statusJson",
			Label:   "status --json",
			Args:    []string{"openclaw.go", "status", "--json"},
			LimitMB: statusJSONLimit,
		},
		{
			ID:      "gatewayStatus",
			Label:   "gateway status",
			Args:    []string{"openclaw.go", "gateway", "status"},
			LimitMB: gatewayStatusLimit,
		},
	}

	for _, testCase := range cases {
		err := runCase(testCase, repoRoot, tmpHome, tmpDir)
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
	}
}

func getTempDir() string {
	tempDir := os.Getenv("TMPDIR")
	if tempDir == "" {
		tempDir = os.Getenv("TEMP")
	}
	if tempDir == "" {
		tempDir = os.Getenv("TMP")
	}
	if tempDir == "" {
		tempDir = os.TempDir()
	}
	return tempDir
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if val := os.Getenv(key); val != "" {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			return f
		}
	}
	return defaultValue
}

func formatFixGuidance(testCase TestCase, details string) string {
	command := "go run " + strings.Join(testCase.Args, " ")
	guidance := []string{
		"[startup-memory] Fix guidance",
		fmt.Sprintf("Case: %s", testCase.Label),
		fmt.Sprintf("Command: %s", command),
		"Next steps:",
		fmt.Sprintf("1. Run `%s` locally on the built tree.", command),
		"2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path.",
		"3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory.",
		"LLM prompt:",
		fmt.Sprintf("\"OpenClaw startup-memory CI failed for '%s'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:\n%s\"", testCase.Label, details),
	}
	return strings.Join(guidance, "\n") + "\n"
}

func formatFailure(testCase TestCase, message string, details string) string {
	sections := []string{message}
	if strings.TrimSpace(details) != "" {
		sections = append(sections, strings.TrimSpace(details))
	}
	sections = append(sections, formatFixGuidance(testCase, details))
	return strings.Join(sections, "\n\n")
}

func parseMaxRssMB(stderr string) *float64 {
	re := regexp.MustCompile(fmt.Sprintf(`^%s(\d+)\s*$`, MAX_RSS_MARKER))
	lines := strings.Split(stderr, "\n")
	
	for i := len(lines) - 1; i >= 0; i-- {
		line := lines[i]
		matches := re.FindStringSubmatch(line)
		if len(matches) > 1 {
			if kb, err := strconv.Atoi(matches[1]); err == nil {
				mb := float64(kb) / 1024.0
				return &mb
			}
		}
	}
	return nil
}

func buildBenchEnv(tmpHome, tmpDir string) []string {
	env := []string{
		fmt.Sprintf("HOME=%s", tmpHome),
		fmt.Sprintf("USERPROFILE=%s", tmpHome),
		fmt.Sprintf("XDG_CONFIG_HOME=%s", filepath.Join(tmpHome, ".config")),
		fmt.Sprintf("XDG_DATA_HOME=%s", filepath.Join(tmpHome, ".local", "share")),
		fmt.Sprintf("XDG_CACHE_HOME=%s", filepath.Join(tmpHome, ".cache")),
		fmt.Sprintf("PATH=%s", os.Getenv("PATH")),
		fmt.Sprintf("TMPDIR=%s", tmpDir),
		fmt.Sprintf("TEMP=%s", tmpDir),
		fmt.Sprintf("TMP=%s", tmpDir),
		fmt.Sprintf("LANG=%s", func() string {
			if lang := os.Getenv("LANG"); lang != "" {
				return lang
			}
			return "C.UTF-8"
		}()),
		fmt.Sprintf("TERM=%s", func() string {
			if term := os.Getenv("TERM"); term != "" {
				return term
			}
			return "dumb"
		}()),
	}

	if lcAll := os.Getenv("LC_ALL"); lcAll != "" {
		env = append(env, fmt.Sprintf("LC_ALL=%s", lcAll))
	}
	if ci := os.Getenv("CI"); ci != "" {
		env = append(env, fmt.Sprintf("CI=%s", ci))
	}
	
	// Keep the regression check focused on app/runtime startup
	env = append(env, "GODEBUG=allocfreetrace=0")
	
	// Keep the benchmark on a single process
	env = append(env, "OPENCLAW_NO_RESPAWN=1")

	return env
}

func runCase(testCase TestCase, repoRoot, tmpHome, tmpDir string) error {
	env := buildBenchEnv(tmpHome, tmpDir)
	
	cmd := exec.Command("go", append([]string{"run"}, testCase.Args...)...)
	cmd.Dir = repoRoot
	cmd.Env = env
	
	stderrPipe, _ := cmd.StderrPipe()
	stdoutPipe, _ := cmd.StdoutPipe()
	
	if err := cmd.Start(); err != nil {
		return fmt.Errorf(formatFailure(testCase, fmt.Sprintf("%s failed to start", testCase.Label), err.Error()))
	}
	
	var stderr, stdout strings.Builder
	go io.Copy(&stderr, stderrPipe)
	go io.Copy(&stdout, stdoutPipe)
	
	err := cmd.Wait()
	stderrStr := stderr.String()
	stdoutStr := stdout.String()
	
	maxRssMB := parseMaxRssMB(stderrStr)
	matrixBootstrapWarning := regexp.MustCompile(`(?i)matrix: crypto runtime bootstrap failed`).MatchString(stderrStr)

	if err != nil {
		return fmt.Errorf(formatFailure(
			testCase,
			fmt.Sprintf("%s exited with error", testCase.Label),
			strings.TrimSpace(stderrStr)+strings.TrimSpace(stdoutStr),
		))
	}
	
	if maxRssMB == nil {
		return fmt.Errorf(formatFailure(testCase, fmt.Sprintf("%s did not report max RSS", testCase.Label), stderrStr))
	}
	
	if matrixBootstrapWarning {
		return fmt.Errorf(formatFailure(testCase, fmt.Sprintf("%s triggered Matrix crypto bootstrap during startup", testCase.Label), ""))
	}
	
	if *maxRssMB > testCase.LimitMB {
		return fmt.Errorf(formatFailure(
			testCase,
			fmt.Sprintf("%s used %.1f MB RSS (limit %.0f MB)", testCase.Label, *maxRssMB, testCase.LimitMB),
			"",
		))
	}

	fmt.Printf("[startup-memory] %s: %.1f MB RSS (limit %.0f MB)\n", testCase.Label, *maxRssMB, testCase.LimitMB)
	return nil
}
