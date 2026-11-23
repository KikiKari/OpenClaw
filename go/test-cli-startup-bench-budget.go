// abstraction-provenance: {"artifact_sha256": "903e833094eb1ed7a630621c043f36d643e0e460ef91f54555064f7328a29099", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "go"}
// test-cli-startup-bench-budget.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const CLI_STARTUP_BENCH_FIXTURE_PATH = "test/fixtures/cli-startup-bench.json"

type Options struct {
	Baseline                 string
	Report                   string
	Entry                    string
	Preset                   string
	Runs                     int
	Warmup                   int
	TimeoutMs                int
	MaxDurationRegressionPct float64
	MaxRssRegressionPct      float64
}

type BenchmarkReport struct {
	Primary struct {
		Cases []BenchmarkCase `json:"cases"`
	} `json:"primary"`
}

type BenchmarkCase struct {
	ID      interface{} `json:"id"`
	Name    string      `json:"name"`
	Summary struct {
		DurationMs struct {
			Avg float64 `json:"avg"`
		} `json:"durationMs"`
		MaxRssMb struct {
			Avg float64 `json:"avg"`
		} `json:"maxRssMb"`
	} `json:"summary"`
}

func formatMs(value float64) string {
	return fmt.Sprintf("%.1fms", value)
}

func formatMb(value float64) string {
	return fmt.Sprintf("%.1fMB", value)
}

func showHelp() {
	helpText := `Usage: go run test-cli-startup-bench-budget.go [options]

Compare current CLI benchmark results against the checked-in fixture.

Options:
  --baseline <path>             Baseline fixture path
  --report <path>               Reuse an existing current benchmark report
  --entry <path>                CLI entry to benchmark when report is omitted
  --preset <name>               startup | real | all (default: all)
  --runs <n>                    Measured runs per case (default: 1)
  --warmup <n>                  Warmup runs per case (default: 0)
  --timeout-ms <ms>             Per-run timeout (default: 30000)
  --max-duration-regression-pct <n>
                                Fail if avg duration regresses more than this percent
  --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent
  --help                        Show this help text

Example:
  go run test-cli-startup-bench-budget.go --preset real --max-duration-regression-pct 15`
	fmt.Println(helpText)
}

func parseFloat(s string) (float64, error) {
	if s == "" {
		return 0, nil
	}
	return strconv.ParseFloat(s, 64)
}

func parseInt(s string) (int, error) {
	if s == "" {
		return 0, nil
	}
	return strconv.Atoi(s)
}

func readEnvNumber(envVar string, defaultValue float64) float64 {
	if val := os.Getenv(envVar); val != "" {
		if num, err := parseFloat(val); err == nil {
			return num
		}
	}
	return defaultValue
}

func parseFlagArgs(args []string, defaults Options) Options {
	opts := defaults
	
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--baseline":
			if i+1 < len(args) {
				opts.Baseline = args[i+1]
				i++
			}
		case "--report":
			if i+1 < len(args) {
				opts.Report = args[i+1]
				i++
			}
		case "--entry":
			if i+1 < len(args) {
				opts.Entry = args[i+1]
				i++
			}
		case "--preset":
			if i+1 < len(args) {
				opts.Preset = args[i+1]
				i++
			}
		case "--runs":
			if i+1 < len(args) {
				if val, err := parseInt(args[i+1]); err == nil && val >= 1 {
					opts.Runs = val
				}
				i++
			}
		case "--warmup":
			if i+1 < len(args) {
				if val, err := parseInt(args[i+1]); err == nil && val >= 0 {
					opts.Warmup = val
				}
				i++
			}
		case "--timeout-ms":
			if i+1 < len(args) {
				if val, err := parseInt(args[i+1]); err == nil && val >= 1 {
					opts.TimeoutMs = val
				}
				i++
			}
		case "--max-duration-regression-pct":
			if i+1 < len(args) {
				if val, err := parseFloat(args[i+1]); err == nil && val >= 0 {
					opts.MaxDurationRegressionPct = val
				}
				i++
			}
		case "--max-rss-regression-pct":
			if i+1 < len(args) {
				if val, err := parseFloat(args[i+1]); err == nil && val >= 0 {
					opts.MaxRssRegressionPct = val
				}
				i++
			}
		}
	}
	
	return opts
}

func readJsonFile(path string) (*BenchmarkReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	
	var report BenchmarkReport
	err = json.Unmarshal(data, &report)
	if err != nil {
		return nil, err
	}
	
	return &report, nil
}

func resolveCurrentReportPath(opts Options) string {
	if opts.Report != "" {
		return opts.Report
	}
	
	reportPath := ".artifacts/cli-startup-bench.current.json"
	os.MkdirAll(".artifacts", fs.ModePerm)
	
	args := []string{
		"--import",
		"tsx",
		"scripts/bench-cli-startup.ts",
		"--entry",
		opts.Entry,
		"--preset",
		opts.Preset,
		"--runs",
		strconv.Itoa(opts.Runs),
		"--warmup",
		strconv.Itoa(opts.Warmup),
		"--timeout-ms",
		strconv.Itoa(opts.TimeoutMs),
		"--output",
		reportPath,
	}
	
	cmd := exec.Command("node", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	
	if err := cmd.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			os.Exit(1)
		}
	}
	
	return reportPath
}

func indexCases(report *BenchmarkReport) map[interface{}]BenchmarkCase {
	cases := make(map[interface{}]BenchmarkCase)
	if report != nil {
		for _, c := range report.Primary.Cases {
			cases[c.ID] = c
		}
	}
	return cases
}

func main() {
	args := os.Args[1:]
	
	for _, arg := range args {
		if arg == "--help" {
			showHelp()
			os.Exit(0)
		}
	}
	
	defaults := Options{
		Baseline:                 CLI_STARTUP_BENCH_FIXTURE_PATH,
		Report:                   "",
		Entry:                    "openclaw.mjs",
		Preset:                   "all",
		Runs:                     1,
		Warmup:                   0,
		TimeoutMs:                30000,
		MaxDurationRegressionPct: readEnvNumber("OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT", 20),
		MaxRssRegressionPct:      readEnvNumber("OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT", 20),
	}
	
	opts := parseFlagArgs(args, defaults)
	
	currentReportPath := resolveCurrentReportPath(opts)
	
	baseline, err := readJsonFile(opts.Baseline)
	if err != nil {
		fmt.Printf("Error reading baseline file: %v\n", err)
		os.Exit(1)
	}
	
	current, err := readJsonFile(currentReportPath)
	if err != nil {
		fmt.Printf("Error reading current report file: %v\n", err)
		os.Exit(1)
	}
	
	baselineCases := indexCases(baseline)
	currentCases := indexCases(current)
	
	failed := false
	
	for id, baselineCase := range baselineCases {
		currentCase, exists := currentCases[id]
		if !exists {
			fmt.Printf("[test-cli-startup-bench-budget] missing current case %v\n", id)
			failed = true
			continue
		}
		
		baselineDuration := baselineCase.Summary.DurationMs.Avg
		currentDuration := currentCase.Summary.DurationMs.Avg
		
		if !math.IsNaN(baselineDuration) && !math.IsInf(baselineDuration, 0) &&
		   !math.IsNaN(currentDuration) && !math.IsInf(currentDuration, 0) &&
		   baselineDuration > 0 {
			
			allowedDuration := baselineDuration * (1 + opts.MaxDurationRegressionPct/100)
			if currentDuration > allowedDuration {
				fmt.Printf("[test-cli-startup-bench-budget] %s avg duration %s exceeded %s (baseline %s, +%v%%).\n",
					baselineCase.Name,
					formatMs(currentDuration),
					formatMs(allowedDuration),
					formatMs(baselineDuration),
					opts.MaxDurationRegressionPct)
				failed = true
			}
		}
		
		baselineRss := baselineCase.Summary.MaxRssMb.Avg
		currentRss := currentCase.Summary.MaxRssMb.Avg
		
		if !math.IsNaN(baselineRss) && !math.IsInf(baselineRss, 0) &&
		   !math.IsNaN(currentRss) && !math.IsInf(currentRss, 0) &&
		   baselineRss > 0 {
			
			allowedRss := baselineRss * (1 + opts.MaxRssRegressionPct/100)
			if currentRss > allowedRss {
				fmt.Printf("[test-cli-startup-bench-budget] %s avg RSS %s exceeded %s (baseline %s, +%v%%).\n",
					baselineCase.Name,
					formatMb(currentRss),
					formatMb(allowedRss),
					formatMb(baselineRss),
					opts.MaxRssRegressionPct)
				failed = true
			}
		}
		
		baselineRssStr := "n/a"
		if !math.IsNaN(baselineRss) && !math.IsInf(baselineRss, 0) {
			baselineRssStr = formatMb(baselineRss)
		}
		
		currentRssStr := "n/a"
		if !math.IsNaN(currentRss) && !math.IsInf(currentRss, 0) {
			currentRssStr = formatMb(currentRss)
		}
		
		fmt.Printf("[test-cli-startup-bench-budget] %s duration=%s baseline=%s rss=%s baselineRss=%s\n",
			baselineCase.Name,
			formatMs(currentDuration),
			formatMs(baselineDuration),
			currentRssStr,
			baselineRssStr)
	}
	
	if failed {
		os.Exit(1)
	}
}
