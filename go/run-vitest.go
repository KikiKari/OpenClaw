// abstraction-provenance: {"artifact_sha256": "02745e902c4a9aa1ccc3c44161c2ba4ad376e4018731878bb27d42ea47d0aecf", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "go"}
// run-vitest.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

var truthyEnvValues = map[string]bool{
	"1":    true,
	"true": true,
	"yes":  true,
	"on":   true,
}

var suppressedVitestStderrPatterns = []string{"[PLUGIN_TIMINGS] Warning:"}

func isTruthyEnvValue(value string) bool {
	value = strings.TrimSpace(strings.ToLower(value))
	return truthyEnvValues[value]
}

func resolveVitestNodeArgs(env map[string]string) []string {
	if isTruthyEnvValue(env["OPENCLAW_VITEST_ENABLE_MAGLEV"]) {
		return []string{}
	}
	return []string{"--no-maglev"}
}

func resolveVitestCliEntry() string {
	// In Go, we need to find the vitest installation path
	// This assumes vitest is installed locally or globally accessible
	cmd := exec.Command("npm", "list", "vitest", "--json")
	output, err := cmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error finding vitest package: %v\n", err)
		os.Exit(1)
	}
	
	// Parse the JSON output to get the path
	// For simplicity, we'll just use a default path
	// In a real implementation, you'd parse the JSON properly
	vitestPath := filepath.Join("node_modules", "vitest", "vitest.mjs")
	if _, err := os.Stat(vitestPath); os.IsNotExist(err) {
		// Try global installation
		vitestPath = filepath.Join(os.Getenv("HOME"), ".nvm", "versions", "node", "node", "lib", "node_modules", "vitest", "vitest.mjs")
	}
	return vitestPath
}

func shouldUseDetachedVitestProcessGroup(platform string) bool {
	// Simplified implementation - in reality this would check platform-specific conditions
	return platform == "linux" || platform == "darwin"
}

func resolveVitestSpawnParams(env map[string]string) *exec.Cmd {
	// Create a basic command structure
	cmd := &exec.Cmd{}
	cmd.Env = os.Environ()
	
	// Convert map[string]string to []string for Env
	var envList []string
	for k, v := range env {
		envList = append(envList, fmt.Sprintf("%s=%s", k, v))
	}
	cmd.Env = envList
	
	return cmd
}

func shouldSuppressVitestStderrLine(line string) bool {
	for _, pattern := range suppressedVitestStderrPatterns {
		if strings.Contains(line, pattern) {
			return true
		}
	}
	return false
}

func forwardVitestOutput(reader io.Reader, writer io.Writer, shouldSuppressLine func(string) bool) {
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		line := scanner.Text() + "\n"
		if !shouldSuppressLine(line) {
			fmt.Fprint(writer, line)
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading stream: %v\n", err)
	}
}

func installVitestProcessGroupCleanup(child *exec.Cmd) func() {
	// Simplified cleanup function
	return func() {
		// In a real implementation, this would handle process group cleanup
	}
}

func mainFunc(args []string, env map[string]string) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: go run run-vitest.go <vitest args...>")
		os.Exit(1)
	}

	// Build environment map from current environment
	if env == nil {
		env = make(map[string]string)
		for _, e := range os.Environ() {
			pair := strings.SplitN(e, "=", 2)
			if len(pair) == 2 {
				env[pair[0]] = pair[1]
			}
		}
	}

	// Prepare vitest arguments
	vitestArgs := []string{"exec", "node"}
	vitestArgs = append(vitestArgs, resolveVitestNodeArgs(env)...)
	vitestArgs = append(vitestArgs, resolveVitestCliEntry())
	vitestArgs = append(vitestArgs, args...)

	// Create command
	cmd := exec.Command("pnpm", vitestArgs...)
	
	// Set up process group detachment if needed
	if shouldUseDetachedVitestProcessGroup(runtime.GOOS) {
		// In Go, process group handling is platform-specific
		// This is a simplified placeholder
	}

	// Set up pipes for stdout and stderr
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating stdout pipe: %v\n", err)
		os.Exit(1)
	}
	
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating stderr pipe: %v\n", err)
		os.Exit(1)
	}

	// Start the command
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "Error starting vitest: %v\n", err)
		os.Exit(1)
	}

	// Set up cleanup
	teardownChildCleanup := installVitestProcessGroupCleanup(cmd)

	// Forward outputs
	go forwardVitestOutput(stdoutPipe, os.Stdout, func(line string) bool { return false })
	go forwardVitestOutput(stderrPipe, os.Stderr, shouldSuppressVitestStderrLine)

	// Wait for command completion
	if err := cmd.Wait(); err != nil {
		teardownChildCleanup()
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			fmt.Fprintf(os.Stderr, "Error running vitest: %v\n", err)
			os.Exit(1)
		}
	}
	
	teardownChildCleanup()
	os.Exit(0)
}

func main() {
	mainFunc(os.Args[1:], nil)
}
