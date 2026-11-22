// abstraction-provenance: {"artifact_sha256": "743f9495de70da1c8acee8bf89092acf64a08d4900c4ab076f7e2b5ddd1d573d", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "go"}
// run-tsgo.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	finalArgs, env := applyLocalTsgoPolicy(os.Args[1:], os.Environ())

	tsgoPath := filepath.Join("node_modules", ".bin", "tsgo")
	tsBuildInfoFile := readFlagValue(finalArgs, "--tsBuildInfoFile")
	if tsBuildInfoFile != "" {
		buildInfoDir := filepath.Dir(filepath.Clean(tsBuildInfoFile))
		if err := os.MkdirAll(buildInfoDir, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "Error creating directory: %v\n", err)
			os.Exit(1)
		}
	}

	releaseLock := acquireLocalHeavyCheckLockSync(map[string]interface{}{
		"cwd":      getCwd(),
		"env":      envToMap(env),
		"toolName": "tsgo",
	})

	defer releaseLock()

	cmd := exec.Command(tsgoPath, finalArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	// Set environment variables
	envMap := envToMap(env)
	for k, v := range envMap {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}
	
	// Handle shell execution on Windows
	if isWindows() {
		cmd = exec.Command(getShell(), tsgoPath)
		cmd.Args = append([]string{getShell()}, tsgoPath)
		cmd.Args = append(cmd.Args, finalArgs...)
	}

	err := cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		} else {
			fmt.Fprintf(os.Stderr, "Error running command: %v\n", err)
			os.Exit(1)
		}
	}
	
	// If we get here without an error, the process completed successfully
	os.Exit(0)
}

func readFlagValue(args []string, name string) string {
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == name {
			if i+1 < len(args) {
				return args[i+1]
			}
			return ""
		}
		if strings.HasPrefix(arg, name+"=") {
			return arg[len(name)+1:]
		}
	}
	return ""
}

// Helper functions that would need to be implemented based on the JavaScript versions
func applyLocalTsgoPolicy(args []string, env []string) ([]string, []string) {
	// This function needs to be implemented based on your specific policy logic
	// For now, returning unchanged args and env
	return args, env
}

func acquireLocalHeavyCheckLockSync(config map[string]interface{}) func() {
	// This function needs to be implemented based on your locking mechanism
	// For now, returning a no-op function
	return func() {}
}

func getCwd() string {
	cwd, _ := os.Getwd()
	return cwd
}

func envToMap(env []string) map[string]string {
	envMap := make(map[string]string)
	for _, e := range env {
		parts := strings.SplitN(e, "=", 2)
		if len(parts) == 2 {
			envMap[parts[0]] = parts[1]
		}
	}
	return envMap
}

func isWindows() bool {
	return strings.Contains(strings.ToLower(os.Getenv("OS")), "windows") || 
		   strings.HasSuffix(strings.ToLower(os.Getenv("SHELL")), "cmd.exe") ||
		   strings.Contains(strings.ToLower(os.Getenv("PATH")), "\\windows\\")
}

func getShell() string {
	if shell := os.Getenv("SHELL"); shell != "" {
		return shell
	}
	if isWindows() {
		return "cmd.exe"
	}
	return "/bin/sh"
}
