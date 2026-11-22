// abstraction-provenance: {"artifact_sha256": "8ae9a1c64eff458d07666b7ad5b879c5ccca59f67ed22309595c7398431e9ee6", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "go"}
// run.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

func main() {
	installURL := getEnvOrDefault("OPENCLAW_INSTALL_URL", "https://openclaw.bot/install.sh")
	defaultPackage := "openclaw"
	packageName := getEnvOrDefault("OPENCLAW_INSTALL_PACKAGE", defaultPackage)
	scriptDir := getScriptDir()

	// Load cli-verify.sh functions
	cliVerifyPath := filepath.Join(scriptDir, "..", "install-sh-common", "cli-verify.sh")
	if _, err := os.Stat(cliVerifyPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "cli-verify.sh not found at %s\n", cliVerifyPath)
		os.Exit(1)
	}

	fmt.Println("==> Pre-flight: ensure git absent")
	if _, err := exec.LookPath("git"); err == nil {
		fmt.Fprintln(os.Stderr, "git is present unexpectedly")
		os.Exit(1)
	}

	fmt.Println("==> Pre-flight: ensure supported Node is already present")
	nodeCmd := exec.Command("node", "-e", `
  const version = process.versions.node.split(".").map(Number);
  const ok =
    version.length >= 2 &&
    (version[0] > 22 || (version[0] === 22 && version[1] >= 16));
  if (!ok) {
    process.stderr.write("unsupported node " + process.versions.node + "\n");
    process.exit(1);
  }
`)
	if err := nodeCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Node version check failed: %v\n", err)
		os.Exit(1)
	}

	npmPath, err := exec.LookPath("npm")
	if err != nil {
		fmt.Fprintln(os.Stderr, "npm not found")
		os.Exit(1)
	}

	fmt.Println("==> Run installer (non-root user)")
	curlCmd := exec.Command("curl", "-fsSL", installURL)
	bashCmd := exec.Command("bash")

	pipe, err := curlCmd.StdoutPipe()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create pipe: %v\n", err)
		os.Exit(1)
	}

	bashCmd.Stdin = pipe
	bashCmd.Stdout = os.Stdout
	bashCmd.Stderr = os.Stderr

	if err := curlCmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to start curl: %v\n", err)
		os.Exit(1)
	}

	if err := bashCmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to start bash: %v\n", err)
		os.Exit(1)
	}

	if err := curlCmd.Wait(); err != nil {
		fmt.Fprintf(os.Stderr, "Curl command failed: %v\n", err)
		os.Exit(1)
	}

	if err := bashCmd.Wait(); err != nil {
		fmt.Fprintf(os.Stderr, "Bash command failed: %v\n", err)
		os.Exit(1)
	}

	// Ensure PATH picks up user npm prefix
	currentPath := os.Getenv("PATH")
	newPath := fmt.Sprintf("%s/.npm-global/bin:%s", os.Getenv("HOME"), currentPath)
	os.Setenv("PATH", newPath)

	fmt.Println("==> Verify git installed")
	if _, err := exec.LookPath("git"); err != nil {
		fmt.Fprintln(os.Stderr, "git not installed")
		os.Exit(1)
	}

	expectedVersion := os.Getenv("OPENCLAW_INSTALL_EXPECT_VERSION")
	var latestVersion string
	if expectedVersion != "" {
		latestVersion = expectedVersion
	} else {
		latestVersion = getNpmLatestVersion(npmPath, packageName)
	}

	fmt.Println("==> Verify CLI installed")
	verifyInstalledCLI(packageName, latestVersion)

	fmt.Println("OK")
}

func getEnvOrDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func getScriptDir() string {
	executable, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get executable path: %v\n", err)
		os.Exit(1)
	}
	dir := filepath.Dir(executable)
	return dir
}

func getNpmLatestVersion(npmPath, packageName string) string {
	cmd := exec.Command(npmPath, "view", packageName, "version")
	output, err := cmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get npm version: %v\n", err)
		os.Exit(1)
	}
	version := strings.TrimSpace(string(output))
	// Remove any extra whitespace or newlines
	re := regexp.MustCompile(`\s+`)
	version = re.ReplaceAllString(version, "")
	return version
}

func verifyInstalledCLI(packageName, expectedVersion string) {
	// This replicates the logic from cli-verify.sh
	// In a real implementation, you would need to implement the full verification logic
	cmd := exec.Command("npm", "list", "-g", packageName)
	output, err := cmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to verify package installation: %v\n", err)
		os.Exit(1)
	}

	// Check if the output contains the package name and version
	outputStr := string(output)
	if !strings.Contains(outputStr, packageName) {
		fmt.Fprintf(os.Stderr, "Package %s not found in global packages\n", packageName)
		os.Exit(1)
	}

	if expectedVersion != "" {
		// Simple version check - in reality you might want more sophisticated version comparison
		if !strings.Contains(outputStr, expectedVersion) {
			fmt.Fprintf(os.Stderr, "Expected version %s not found\n", expectedVersion)
			os.Exit(1)
		}
	}
}
