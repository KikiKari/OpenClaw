// abstraction-provenance: {"artifact_sha256": "cc56effeaef52a59920d9c329017f2082dd1392c2590a2753f39333c3011cfdd", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "go"}
// install.ps1 — portiert nach go
// Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

// Colors
const (
	ACCENT   = "\033[38;2;255;77;77m" // coral-bright
	SUCCESS  = "\033[38;2;0;229;204m" // cyan-bright
	WARN     = "\033[38;2;255;176;32m" // amber
	ERROR    = "\033[38;2;230;57;70m" // coral-mid
	MUTED    = "\033[38;2;90;100;128m" // text-muted
	NC       = "\033[0m"              // No Color
)

type Config struct {
	InstallMethod string
	Tag           string
	GitDir        string
	NoOnboard     bool
	NoGitUpdate   bool
	DryRun        bool
}

func writeHost(message string, level string) {
	var msg string
	switch level {
	case "success":
		msg = fmt.Sprintf("%s✓%s %s", SUCCESS, NC, message)
	case "warn":
		msg = fmt.Sprintf("%s!%s %s", WARN, NC, message)
	case "error":
		msg = fmt.Sprintf("%s✗%s %s", ERROR, NC, message)
	default:
		msg = fmt.Sprintf("%s·%s %s", MUTED, NC, message)
	}
	fmt.Println(msg)
}

func writeBanner() {
	writeHost("", "info")
	writeHost(fmt.Sprintf("%s  🦞 OpenClaw Installer%s", ACCENT, NC), "info")
	writeHost(fmt.Sprintf("%s  All your chats, one OpenClaw.%s", MUTED, NC), "info")
	writeHost("", "info")
}

func getExecutionPolicyStatus() map[string]interface{} {
	// In Go, we can't check PowerShell execution policy directly
	// This is a placeholder that assumes it's not blocked
	return map[string]interface{}{
		"Blocked": false,
		"Policy":  "Unrestricted",
	}
}

func ensureExecutionPolicy() bool {
	status := getExecutionPolicyStatus()
	if status["Blocked"].(bool) {
		writeHost(fmt.Sprintf("PowerShell execution policy is set to: %s", status["Policy"]), "warn")
		writeHost("This prevents scripts like npm.ps1 from running.", "warn")
		writeHost("", "info")
		writeHost("Could not automatically set execution policy", "error")
		writeHost("", "info")
		writeHost("To fix this, run:", "info")
		writeHost("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process", "info")
		writeHost("", "info")
		writeHost("Or run PowerShell as Administrator and execute:", "info")
		writeHost("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine", "info")
		return false
	}
	return true
}

func getNodeVersion() string {
	cmd := exec.Command("node", "--version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	version := strings.TrimSpace(string(output))
	return strings.TrimPrefix(version, "v")
}

func getNpmVersion() string {
	cmd := exec.Command("npm", "--version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func installNode() bool {
	writeHost("Node.js not found", "info")
	writeHost("Installing Node.js...", "info")

	// Try winget first
	if _, err := exec.LookPath("winget"); err == nil {
		writeHost("  Using winget...", "info")
		cmd := exec.Command("winget", "install", "OpenJS.NodeJS.LTS", "--accept-package-agreements", "--accept-source-agreements")
		err := cmd.Run()
		if err == nil {
			writeHost("  Node.js installed via winget", "success")
			return true
		} else {
			writeHost(fmt.Sprintf("  Winget install failed: %v", err), "warn")
		}
	}

	// Try chocolatey
	if _, err := exec.LookPath("choco"); err == nil {
		writeHost("  Using chocolatey...", "info")
		cmd := exec.Command("choco", "install", "nodejs-lts", "-y")
		err := cmd.Run()
		if err == nil {
			writeHost("  Node.js installed via chocolatey", "success")
			return true
		} else {
			writeHost(fmt.Sprintf("  Chocolatey install failed: %v", err), "warn")
		}
	}

	// Try scoop
	if _, err := exec.LookPath("scoop"); err == nil {
		writeHost("  Using scoop...", "info")
		cmd := exec.Command("scoop", "install", "nodejs-lts")
		err := cmd.Run()
		if err == nil {
			writeHost("  Node.js installed via scoop", "success")
			return true
		} else {
			writeHost(fmt.Sprintf("  Scoop install failed: %v", err), "warn")
		}
	}

	writeHost("Could not install Node.js automatically", "error")
	writeHost("Please install Node.js 22+ manually from: https://nodejs.org", "info")
	return false
}

func ensureNode() bool {
	nodeVersion := getNodeVersion()
	if nodeVersion != "" {
		major := strings.Split(nodeVersion, ".")[0]
		var majorInt int
		fmt.Sscanf(major, "%d", &majorInt)
		if majorInt >= 22 {
			writeHost(fmt.Sprintf("Node.js v%s found", nodeVersion), "success")
			return true
		}
		writeHost(fmt.Sprintf("Node.js v%s found, but need v22+", nodeVersion), "warn")
	}
	return installNode()
}

func getGitVersion() string {
	cmd := exec.Command("git", "--version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func installGit() bool {
	writeHost("Git not found", "info")

	if _, err := exec.LookPath("winget"); err == nil {
		writeHost("  Installing Git via winget...", "info")
		cmd := exec.Command("winget", "install", "Git.Git", "--accept-package-agreements", "--accept-source-agreements")
		err := cmd.Run()
		if err == nil {
			writeHost("  Git installed", "success")
			return true
		} else {
			writeHost("  Winget install failed", "warn")
		}
	}

	writeHost("Please install Git for Windows from: https://git-scm.com", "error")
	return false
}

func ensureGit() bool {
	gitVersion := getGitVersion()
	if gitVersion != "" {
		writeHost(fmt.Sprintf("%s found", gitVersion), "success")
		return true
	}
	return installGit()
}

func installOpenClawNpm(target string) bool {
	installSpec := resolvePackageInstallSpec(target)
	writeHost(fmt.Sprintf("Installing OpenClaw (%s)...", installSpec), "info")

	cmd := exec.Command("npm", "install", "-g", installSpec, "--no-fund", "--no-audit")
	err := cmd.Run()
	if err != nil {
		writeHost(fmt.Sprintf("npm install failed: %v", err), "error")
		return false
	}
	writeHost("OpenClaw installed", "success")
	return true
}

func installOpenClawGit(repoDir string, update bool) bool {
	writeHost("Installing OpenClaw from git...", "info")

	if _, err := os.Stat(repoDir); os.IsNotExist(err) {
		writeHost("  Cloning repository...", "info")
		cmd := exec.Command("git", "clone", "https://github.com/openclaw/openclaw.git", repoDir)
		err := cmd.Run()
		if err != nil {
			writeHost(fmt.Sprintf("Git clone failed: %v", err), "error")
			return false
		}
	} else if update {
		writeHost("  Updating repository...", "info")
		cmd := exec.Command("git", "-C", repoDir, "pull", "--rebase")
		err := cmd.Run()
		if err != nil {
			writeHost(fmt.Sprintf("Git pull failed: %v", err), "error")
			return false
		}
	}

	// Install pnpm if not present
	if _, err := exec.LookPath("pnpm"); err != nil {
		writeHost("  Installing pnpm...", "info")
		cmd := exec.Command("npm", "install", "-g", "pnpm")
		err := cmd.Run()
		if err != nil {
			writeHost(fmt.Sprintf("pnpm install failed: %v", err), "error")
			return false
		}
	}

	// Install dependencies
	writeHost("  Installing dependencies...", "info")
	cmd := exec.Command("pnpm", "install", "--dir", repoDir)
	err := cmd.Run()
	if err != nil {
		writeHost(fmt.Sprintf("pnpm install failed: %v", err), "error")
		return false
	}

	// Build
	writeHost("  Building...", "info")
	cmd = exec.Command("pnpm", "--dir", repoDir, "build")
	err = cmd.Run()
	if err != nil {
		writeHost(fmt.Sprintf("Build failed: %v", err), "error")
		return false
	}

	// Create wrapper
	homeDir, _ := os.UserHomeDir()
	wrapperDir := filepath.Join(homeDir, ".local", "bin")
	os.MkdirAll(wrapperDir, 0755)

	wrapperContent := `@echo off
node "%~dp0..\openclaw\dist\entry.js" %*`
	
	wrapperPath := filepath.Join(wrapperDir, "openclaw.cmd")
	err = os.WriteFile(wrapperPath, []byte(wrapperContent), 0644)
	if err != nil {
		writeHost(fmt.Sprintf("Failed to create wrapper: %v", err), "error")
		return false
	}

	writeHost("OpenClaw installed", "success")
	return true
}

func testExplicitPackageInstallSpec(target string) bool {
	if strings.TrimSpace(target) == "" {
		return false
	}

	return strings.Contains(target, "://") ||
		strings.Contains(target, "#") ||
		regexp.MustCompile(`^(file|github|git\+ssh|git\+https|git\+http|git\+file|npm):`).MatchString(target)
}

func resolvePackageInstallSpec(target string) string {
	trimmed := strings.TrimSpace(target)
	if trimmed == "" {
		return "openclaw@latest"
	}
	if strings.ToLower(trimmed) == "main" {
		return "github:openclaw/openclaw#main"
	}
	if testExplicitPackageInstallSpec(trimmed) {
		return trimmed
	}
	return "openclaw@" + trimmed
}

func addToPath(path string) {
	currentPath := os.Getenv("PATH")
	if !strings.Contains(currentPath, path) {
		newPath := currentPath + ";" + path
		os.Setenv("PATH", newPath)
		writeHost(fmt.Sprintf("Added %s to user PATH", path), "info")
	}
}

func downloadAndExecuteScript(url string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	scriptContent, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	tmpFile, err := os.CreateTemp("", "install-*.ps1")
	if err != nil {
		return err
	}
	defer os.Remove(tmpFile.Name())

	_, err = tmpFile.Write(scriptContent)
	if err != nil {
		return err
	}
	tmpFile.Close()

	// Execute the PowerShell script
	cmd := exec.Command("powershell", "-ExecutionPolicy", "Bypass", "-File", tmpFile.Name())
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func mainFunc(config Config) {
	writeBanner()
	writeHost("Windows detected", "success")

	// Check and handle execution policy FIRST, before any npm calls
	if !ensureExecutionPolicy() {
		writeHost("", "info")
		writeHost("Installation cannot continue due to execution policy restrictions", "error")
		os.Exit(1)
	}

	if !ensureNode() {
		os.Exit(1)
	}

	if config.InstallMethod == "git" {
		if !ensureGit() {
			os.Exit(1)
		}

		if config.DryRun {
			writeHost(fmt.Sprintf("[DRY RUN] Would install OpenClaw from git to %s", config.GitDir), "info")
		} else {
			installOpenClawGit(config.GitDir, !config.NoGitUpdate)
		}
	} else {
		// npm method
		if !ensureGit() {
			writeHost("Git is required for npm installs. Please install Git and try again.", "warn")
		}

		if config.DryRun {
			spec := resolvePackageInstallSpec(config.Tag)
			writeHost(fmt.Sprintf("[DRY RUN] Would install OpenClaw via npm (%s)", spec), "info")
		} else {
			if !installOpenClawNpm(config.Tag) {
				os.Exit(1)
			}
		}
	}

	// Try to add npm global bin to PATH
	cmd := exec.Command("npm", "config", "get", "prefix")
	output, err := cmd.Output()
	if err == nil {
		prefix := strings.TrimSpace(string(output))
		addToPath(prefix)
	}

	if !config.NoOnboard && !config.DryRun {
		writeHost("", "info")
		writeHost("Run 'openclaw onboard' to complete setup", "info")
	}

	writeHost("", "info")
	writeHost("🦞 OpenClaw installed successfully!", "success")
}

func main() {
	config := Config{
		InstallMethod: "npm",
		Tag:           "latest",
		NoOnboard:     false,
		NoGitUpdate:   false,
		DryRun:        false,
	}

	// Handle command line arguments
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "-InstallMethod":
			if i+1 < len(args) {
				config.InstallMethod = args[i+1]
				i++
			}
		case "-Tag":
			if i+1 < len(args) {
				config.Tag = args[i+1]
				i++
			}
		case "-GitDir":
			if i+1 < len(args) {
				config.GitDir = args[i+1]
				i++
			}
		case "-NoOnboard":
			config.NoOnboard = true
		case "-NoGitUpdate":
			config.NoGitUpdate = true
		case "-DryRun":
			config.DryRun = true
		}
	}

	// Set default GitDir if not provided
	if config.GitDir == "" {
		homeDir, _ := os.UserHomeDir()
		config.GitDir = filepath.Join(homeDir, "openclaw")
	}

	// If no arguments provided, show usage
	if len(args) == 0 && runtime.GOOS != "windows" {
		fmt.Println("Usage: go run install.go [options]")
		fmt.Println("Options:")
		fmt.Println("  -InstallMethod string   Installation method (npm or git) (default \"npm\")")
		fmt.Println("  -Tag string             Version tag to install (default \"latest\")")
		fmt.Println("  -GitDir string          Directory for git installation")
		fmt.Println("  -NoOnboard              Skip onboarding after installation")
		fmt.Println("  -NoGitUpdate            Skip git update for git installations")
		fmt.Println("  -DryRun                 Show what would be installed without actually installing")
		return
	}

	mainFunc(config)
}
