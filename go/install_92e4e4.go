// abstraction-provenance: {"artifact_sha256": "df08fb6bebda61725cc9ba9cf2eb6ade919f59c603940c26d02a7efe97526811", "source_sha256": "92e4e42c094acdc50020eef437d7e6411d917a345927787d9c87ff5e7e69ae45", "target_language": "go"}
// install.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/install.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/google/uuid"
	"golang.org/x/term"
)

const (
	defaultTagline          = "All your chats, one OpenClaw."
	nodeDefaultMajor        = 24
	nodeMinMajor            = 22
	nodeMinMinor            = 14
	gumVersion              = "0.17.0"
	openclawRepoURL         = "https://github.com/openclaw/openclaw.git"
	homebrewInstallURL      = "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
	nodeSourceSetupBaseURL  = "https://deb.nodesource.com/setup_%d.x"
	nodeSourceRPMSetupURL   = "https://rpm.nodesource.com/setup_%d.x"
	openclawNPMRegistry     = "https://registry.npmjs.org"
)

var (
	boldStyle          = lipgloss.NewStyle().Bold(true)
	accentStyle        = lipgloss.NewStyle().Foreground(lipgloss.Color("#ff4d4d"))
	infoStyle          = lipgloss.NewStyle().Foreground(lipgloss.Color("#8892b0"))
	successStyle       = lipgloss.NewStyle().Foreground(lipgloss.Color("#00e5cc"))
	warnStyle          = lipgloss.NewStyle().Foreground(lipgloss.Color("#ffb020"))
	errorStyle         = lipgloss.NewStyle().Foreground(lipgloss.Color("#e63946"))
	mutedStyle         = lipgloss.NewStyle().Foreground(lipgloss.Color("#5a6480"))
	noStyle            = lipgloss.NewStyle()
	
	taglines = []string{
		"Your terminal just grew claws—type something and let the bot pinch the busywork.",
		"Welcome to the command line: where dreams compile and confidence segfaults.",
		"I run on caffeine, JSON5, and the audacity of \"it worked on my machine.\"",
		"Gateway online—please keep hands, feet, and appendages inside the shell at all times.",
		"I speak fluent bash, mild sarcasm, and aggressive tab-completion energy.",
		"One CLI to rule them all, and one more restart because you changed the port.",
		"If it works, it's automation; if it breaks, it's a \"learning opportunity.\"",
		"Pairing codes exist because even bots believe in consent—and good security hygiene.",
		"Your .env is showing; don't worry, I'll pretend I didn't see it.",
		"I'll do the boring stuff while you dramatically stare at the logs like it's cinema.",
		"I'm not saying your workflow is chaotic... I'm just bringing a linter and a helmet.",
		"Type the command with confidence—nature will provide the stack trace if needed.",
		"I don't judge, but your missing API keys are absolutely judging you.",
		"I can grep it, git blame it, and gently roast it—pick your coping mechanism.",
		"Hot reload for config, cold sweat for deploys.",
		"I'm the assistant your terminal demanded, not the one your sleep schedule requested.",
		"I keep secrets like a vault... unless you print them in debug logs again.",
		"Automation with claws: minimal fuss, maximal pinch.",
		"I'm basically a Swiss Army knife, but with more opinions and fewer sharp edges.",
		"If you're lost, run doctor; if you're brave, run prod; if you're wise, run tests.",
		"Your task has been queued; your dignity has been deprecated.",
		"I can't fix your code taste, but I can fix your build and your backlog.",
		"I'm not magic—I'm just extremely persistent with retries and coping strategies.",
		"It's not \"failing,\" it's \"discovering new ways to configure the same thing wrong.\"",
		"Give me a workspace and I'll give you fewer tabs, fewer toggles, and more oxygen.",
		"I read logs so you can keep pretending you don't have to.",
		"If something's on fire, I can't extinguish it—but I can write a beautiful postmortem.",
		"I'll refactor your busywork like it owes me money.",
		"Say \"stop\" and I'll stop—say \"ship\" and we'll both learn a lesson.",
		"I'm the reason your shell history looks like a hacker-movie montage.",
		"I'm like tmux: confusing at first, then suddenly you can't live without me.",
		"I can run local, remote, or purely on vibes—results may vary with DNS.",
		"If you can describe it, I can probably automate it—or at least make it funnier.",
		"Your config is valid, your assumptions are not.",
		"I don't just autocomplete—I auto-commit (emotionally), then ask you to review (logically).",
		"Less clicking, more shipping, fewer \"where did that file go\" moments.",
		"Claws out, commit in—let's ship something mildly responsible.",
		"I'll butter your workflow like a lobster roll: messy, delicious, effective.",
		"Shell yeah—I'm here to pinch the toil and leave you the glory.",
		"If it's repetitive, I'll automate it; if it's hard, I'll bring jokes and a rollback plan.",
		"Because texting yourself reminders is so 2024.",
		"WhatsApp, but make it ✨engineering✨.",
		"Turning \"I'll reply later\" into \"my bot replied instantly\".",
		"The only crab in your contacts you actually want to hear from. 🦞",
		"Chat automation for people who peaked at IRC.",
		"Because Siri wasn't answering at 3AM.",
		"IPC, but it's your phone.",
		"The UNIX philosophy meets your DMs.",
		"curl for conversations.",
		"WhatsApp Business, but without the business.",
		"Meta wishes they shipped this fast.",
		"End-to-end encrypted, Zuck-to-Zuck excluded.",
		"The only bot Mark can't train on your DMs.",
		"WhatsApp automation without the \"please accept our new privacy policy\".",
		"Chat APIs that don't require a Senate hearing.",
		"Because Threads wasn't the answer either.",
		"Your messages, your servers, Meta's tears.",
		"iMessage green bubble energy, but for everyone.",
		"Siri's competent cousin.",
		"Works on Android. Crazy concept, we know.",
		"No $999 stand required.",
		"We ship features faster than Apple ships calculator updates.",
		"Your AI assistant, now without the $3,499 headset.",
		"Think different. Actually think.",
		"Ah, the fruit tree company! 🍎",
	}
)

type InstallerConfig struct {
	NoOnboard        bool
	NoPrompt         bool
	DryRun           bool
	InstallMethod    string
	OpenClawVersion  string
	UseBeta          bool
	GitDir           string
	GitUpdate        bool
	Verbose          bool
	VerifyInstall    bool
	Help             bool
}

type GumState struct {
	Path     string
	Status   string
	Reason   string
}

type Installer struct {
	config      InstallerConfig
	gum         GumState
	tagline     string
	os          string
	arch        string
	tmpFiles    []string
	originalPath string
	httpClient  *http.Client
}

func NewInstaller(cfg InstallerConfig) *Installer {
	return &Installer{
		config:      cfg,
		originalPath: os.Getenv("PATH"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSHandshakeTimeout: 10 * time.Second,
			},
		},
	}
}

func (i *Installer) cleanup() {
	for _, f := range i.tmpFiles {
		os.RemoveAll(f)
	}
}

func (i *Installer) mktempfile() (string, error) {
	f, err := os.CreateTemp("", "openclaw-install-*")
	if err != nil {
		return "", err
	}
	f.Close()
	i.tmpFiles = append(i.tmpFiles, f.Name())
	return f.Name(), nil
}

func (i *Installer) downloadFile(urlStr, outputPath string) error {
	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "OpenClaw-Installer/1.0")

	resp, err := i.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed with status: %s", resp.Status)
	}

	outFile, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer outFile.Close()

	_, err = io.Copy(outFile, resp.Body)
	return err
}

func (i *Installer) runRemoteBash(urlStr string) error {
	tmpFile, err := i.mktempfile()
	if err != nil {
		return err
	}

	if err := i.downloadFile(urlStr, tmpFile); err != nil {
		return err
	}

	cmd := exec.Command("/bin/bash", tmpFile)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (i *Installer) isNonInteractiveShell() bool {
	if i.config.NoPrompt {
		return true
	}
	return !term.IsTerminal(int(os.Stdin.Fd())) || !term.IsTerminal(int(os.Stdout.Fd()))
}

func (i *Installer) gumIsTTY() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	if term := os.Getenv("TERM"); term == "dumb" {
		return false
	}
	return term.IsTerminal(int(os.Stdout.Fd())) || term.IsTerminal(int(os.Stderr.Fd()))
}

func (i *Installer) detectOS() string {
	switch runtime.GOOS {
	case "darwin":
		return "Darwin"
	case "linux":
		return "Linux"
	default:
		return "unsupported"
	}
}

func (i *Installer) detectArch() string {
	switch runtime.GOARCH {
	case "amd64":
		return "x86_64"
	case "arm64":
		return "arm64"
	case "386":
		return "i386"
	default:
		return "unknown"
	}
}

func (i *Installer) verifySHA256sumFile(checksumsPath string) error {
	data, err := os.ReadFile(checksumsPath)
	if err != nil {
		return err
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		parts := strings.Fields(line)
		if len(parts) < 2 {
			continue
		}
		expectedHash := parts[0]
		filename := parts[1]

		fileData, err := os.ReadFile(filename)
		if err != nil {
			continue
		}

		hash := sha256.Sum256(fileData)
		actualHash := hex.EncodeToString(hash[:])
		if actualHash != expectedHash {
			return fmt.Errorf("hash mismatch for %s", filename)
		}
	}
	return nil
}

func (i *Installer) bootstrapGumTemp() error {
	i.gum = GumState{}

	if i.isNonInteractiveShell() {
		i.gum.Reason = "non-interactive shell (auto-disabled)"
		return fmt.Errorf(i.gum.Reason)
	}

	if !i.gumIsTTY() {
		i.gum.Reason = "terminal does not support gum UI"
		return fmt.Errorf(i.gum.Reason)
	}

	if path, err := exec.LookPath("gum"); err == nil {
		i.gum.Path = path
		i.gum.Status = "found"
		i.gum.Reason = "already installed"
		return nil
	}

	if _, err := exec.LookPath("tar"); err != nil {
		i.gum.Reason = "tar not found"
		return fmt.Errorf(i.gum.Reason)
	}

	osType := i.detectOS()
	archType := i.detectArch()
	if osType == "unsupported" || archType == "unknown" {
		i.gum.Reason = fmt.Sprintf("unsupported os/arch (%s/%s)", osType, archType)
		return fmt.Errorf(i.gum.Reason)
	}

	asset := fmt.Sprintf("gum_%s_%s_%s.tar.gz", gumVersion, osType, archType)
	baseURL := fmt.Sprintf("https://github.com/charmbracelet/gum/releases/download/v%s", gumVersion)

	gumTmpDir, err := os.MkdirTemp("", "gum-temp-*")
	if err != nil {
		i.gum.Reason = "temp dir creation failed"
		return fmt.Errorf(i.gum.Reason)
	}
	i.tmpFiles = append(i.tmpFiles, gumTmpDir)

	assetPath := filepath.Join(gumTmpDir, asset)
	if err := i.downloadFile(baseURL+"/"+asset, assetPath); err != nil {
		i.gum.Reason = "download failed"
		return fmt.Errorf(i.gum.Reason)
	}

	checksumsPath := filepath.Join(gumTmpDir, "checksums.txt")
	if err := i.downloadFile(baseURL+"/checksums.txt", checksumsPath); err != nil {
		i.gum.Reason = "checksum unavailable or failed"
		return fmt.Errorf(i.gum.Reason)
	}

	if err := i.verifySHA256sumFile(checksumsPath); err != nil {
		i.gum.Reason = "checksum verification failed"
		return fmt.Errorf(i.gum.Reason)
	}

	cmd := exec.Command("tar", "-xzf", assetPath, "-C", gumTmpDir)
	if err := cmd.Run(); err != nil {
		i.gum.Reason = "extract failed"
		return fmt.Errorf(i.gum.Reason)
	}

	err = filepath.Walk(gumTmpDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.Name() == "gum" && !info.IsDir() {
			i.gum.Path = path
			return filepath.SkipAll
		}
		return nil
	})
	if err != nil || i.gum.Path == "" {
		i.gum.Reason = "gum binary missing after extract"
		return fmt.Errorf(i.gum.Reason)
	}

	if err := os.Chmod(i.gum.Path, 0755); err != nil {
		i.gum.Reason = "gum binary is not executable"
		return fmt.Errorf(i.gum.Reason)
	}

	i.gum.Status = "installed"
	i.gum.Reason = "temp, verified"
	return nil
}

func (i *Installer) printGumStatus() {
	switch i.gum.Status {
	case "found":
		i.uiSuccess(fmt.Sprintf("gum available (%s)", i.gum.Reason))
	case "installed":
		i.uiSuccess(fmt.Sprintf("gum bootstrapped (%s, v%s)", i.gum.Reason, gumVersion))
	default:
		if i.gum.Reason != "" && i.gum.Reason != "non-interactive shell (auto-disabled)" {
			i.uiInfo(fmt.Sprintf("gum skipped (%s)", i.gum.Reason))
		}
	}
}

func (i *Installer) printInstallerBanner() {
	if i.gum.Path != "" {
		title := lipgloss.NewStyle().Foreground(lipgloss.Color("#ff4d4d")).Bold(true).Render("🦞 OpenClaw Installer")
		tagline := lipgloss.NewStyle().Foreground(lipgloss.Color("#8892b0")).Render(i.tagline)
		hint := lipgloss.NewStyle().Foreground(lipgloss.Color("#5a6480")).Render("modern installer mode")
		card := lipgloss.JoinVertical(lipgloss.Left, title, tagline, hint)
		bordered := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("#ff4d4d")).Padding(1, 2).Render(card)
		fmt.Println(bordered)
		fmt.Println()
		return
	}

	fmt.Println(accentStyle.Render(boldStyle.Render("  🦞 OpenClaw Installer")))
	fmt.Println(infoStyle.Render("  " + i.tagline))
	fmt.Println()
}

func (i *Installer) detectOSOrDie() {
	switch runtime.GOOS {
	case "darwin":
		i.os = "macos"
	case "linux":
		i.os = "linux"
	default:
		i.uiError("Unsupported operating system")
		fmt.Println("This installer supports macOS and Linux (including WSL).")
		fmt.Println("For Windows, use: iwr -useb https://openclaw.ai/install.ps1 | iex")
		os.Exit(1)
	}
	i.uiSuccess(fmt.Sprintf("Detected: %s", i.os))
}

func (i *Installer) uiInfo(msg string) {
	if i.gum.Path != "" {
		cmd := exec.Command(i.gum.Path, "log", "--level", "info", msg)
		cmd.Run()
	} else {
		fmt.Printf("%s %s\n", mutedStyle.Render("·"), msg)
	}
}

func (i *Installer) uiWarn(msg string) {
	if i.gum.Path != "" {
		cmd := exec.Command(i.gum.Path, "log", "--level", "warn", msg)
		cmd.Run()
	} else {
		fmt.Printf("%s %s\n", warnStyle.Render("!"), msg)
	}
}

func (i *Installer) uiSuccess(msg string) {
	if i.gum.Path != "" {
		mark := lipgloss.NewStyle().Foreground(lipgloss.Color("#00e5cc")).Bold(true).Render("✓")
		fmt.Printf("%s %s\n", mark, msg)
	} else {
		fmt.Printf("%s %s\n", successStyle.Render("✓"), msg)
	}
}

func (i *Installer) uiError(msg string) {
	if i.gum.Path != "" {
		cmd := exec.Command(i.gum.Path, "log", "--level", "error", msg)
		cmd.Run()
	} else {
		fmt.Printf("%s %s\n", errorStyle.Render("✗"), msg)
	}
}

func (i *Installer) pickTagline() string {
	if len(taglines) == 0 {
		return defaultTagline
	}
	idx := time.Now().Unix() % int64(len(taglines))
	return taglines[idx]
}

func (i *Installer) checkNode() (bool, error) {
	cmd := exec.Command("node", "-v")
	output, err := cmd.Output()
	if err != nil {
		return false, nil
	}

	version := strings.TrimSpace(string(output))
	re := regexp.MustCompile(`v?(\d+)\.(\d+)\.(\d+)`)
	matches := re.FindStringSubmatch(version)
	if len(matches) < 4 {
		return false, nil
	}

	major, _ := strconv.Atoi(matches[1])
	minor, _ := strconv.Atoi(matches[2])

	if major > nodeMinMajor || (major == nodeMinMajor && minor >= nodeMinMinor) {
		i.uiSuccess(fmt.Sprintf("Node.js %s found", version))
		return true, nil
	}

	i.uiInfo(fmt.Sprintf("Node.js %s found, upgrading to v%d.%d+", version, nodeMinMajor, nodeMinMinor))
	return false, nil
}

func (i *Installer) installNode() error {
	switch i.os {
	case "macos":
		return i.installNodeMacOS()
	case "linux":
		return i.installNodeLinux()
	default:
		return fmt.Errorf("unsupported OS for Node.js installation")
	}
}

func (i *Installer) installNodeMacOS() error {
	i.uiInfo("Installing Node.js via Homebrew")
	
	if err := i.runCommand("brew", "install", fmt.Sprintf("node@%d", nodeDefaultMajor)); err != nil {
		return err
	}
	
	if err := i.runCommand("brew", "link", fmt.Sprintf("node@%d", nodeDefaultMajor), "--overwrite", "--force"); err != nil {
		i.uiWarn("brew link failed, continuing")
	}
	
	i.uiSuccess("Node.js installed")
	return nil
}

func (i *Installer) installNodeLinux() error {
	i.uiInfo("Installing Node.js via NodeSource")
	
	tmpFile, err := i.mktempfile()
	if err != nil {
		return err
	}

	setupURL := fmt.Sprintf(nodeSourceSetupBaseURL, nodeDefaultMajor)
	if err := i.downloadFile(setupURL, tmpFile); err != nil {
		return err
	}

	if err := i.runCommand("bash", tmpFile); err != nil {
		return err
	}

	if err := i.runCommand("apt-get", "install", "-y", "nodejs"); err != nil {
		return err
	}

	i.uiSuccess("Node.js installed")
	return nil
}

func (i *Installer) runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (i *Installer) runQuietStep(title string, name string, args ...string) error {
	if i.config.Verbose {
		i.uiInfo(title)
		return i.runCommand(name, args...)
	}

	output, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		i.uiError(fmt.Sprintf("%s failed — re-run with --verbose for details", title))
		if len(output) > 0 {
			lines := strings.Split(string(output), "\n")
			if len(lines) > 80 {
				lines = lines[len(lines)-80:]
			}
			fmt.Println(strings.Join(lines, "\n"))
		}
		return err
	}
	return nil
}

func (i *Installer) installOpenClawNPM() error {
	spec := "openclaw"
	if i.config.OpenClawVersion != "latest" {
		spec = fmt.Sprintf("openclaw@%s", i.config.OpenClawVersion)
	}

	i.uiInfo(fmt.Sprintf("Installing OpenClaw (%s)", spec))
	
	env := os.Environ()
	env = append(env, "SHARP_IGNORE_GLOBAL_LIBVIPS=1")
	
	cmd := exec.Command("npm", "install", "-g", spec)
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("npm install failed: %v", err)
	}

	i.uiSuccess("OpenClaw npm package installed")
	return nil
}

func (i *Installer) installOpenClawGit() error {
	repoDir := i.config.GitDir
	if repoDir == "" {
		repoDir = filepath.Join(os.Getenv("HOME"), "openclaw")
	}

	i.uiInfo(fmt.Sprintf("Installing OpenClaw from GitHub (%s)", openclawRepoURL))

	if _, err := exec.LookPath("git"); err != nil {
		if err := i.installGit(); err != nil {
			return err
		}
	}

	if _, err := os.Stat(repoDir); os.IsNotExist(err) {
		if err := i.runCommand("git", "clone", openclawRepoURL, repoDir); err != nil {
			return err
		}
	} else if i.config.GitUpdate {
		cmd := exec.Command("git", "-C", repoDir, "pull", "--rebase")
		if err := cmd.Run(); err != nil {
			i.uiWarn("git pull failed, continuing with existing checkout")
		}
	}

	if _, err := exec.LookPath("pnpm"); err != nil {
		if err := i.runCommand("npm", "install", "-g", "pnpm"); err != nil {
			return err
		}
	}

	cmd := exec.Command("pnpm", "install")
	cmd.Dir = repoDir
	cmd.Env = append(os.Environ(), "SHARP_IGNORE_GLOBAL_LIBVIPS=1")
	if err := cmd.Run(); err != nil {
		return err
	}

	cmd = exec.Command("pnpm", "build")
	cmd.Dir = repoDir
	if err := cmd.Run(); err != nil {
		return err
	}

	localBin := filepath.Join(os.Getenv("HOME"), ".local", "bin")
	if err := os.MkdirAll(localBin, 0755); err != nil {
		return err
	}

	wrapperScript := `#!/bin/bash
set -euo pipefail
exec node "` + repoDir + `/dist/entry.js" "$@"
`

	wrapperPath := filepath.Join(localBin, "openclaw")
	if err := os.WriteFile(wrapperPath, []byte(wrapperScript), 0755); err != nil {
		return err
	}

	i.uiSuccess("OpenClaw wrapper installed to ~/.local/bin/openclaw")
	return nil
}

func (i *Installer) installGit() error {
	switch i.os {
	case "macos":
		return i.runCommand("brew", "install", "git")
	case "linux":
		return i.runCommand("apt-get", "install", "-y", "git")
	default:
		return fmt.Errorf("unsupported OS for Git installation")
	}
}

func (i *Installer) installHomebrew() error {
	if i.os != "macos" {
		return nil
	}

	if _, err := exec.LookPath("brew"); err == nil {
		i.uiSuccess("Homebrew already installed")
		return nil
	}

	i.uiInfo("Homebrew not found, installing")
	return i.runRemoteBash(homebrewInstallURL)
}

func (i *Installer) main() error {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		i.cleanup()
		os.Exit(1)
	}()
	defer i.cleanup()

	if i.config.Help {
		i.printUsage()
		return nil
	}

	if err := i.bootstrapGumTemp(); err != nil {
		i.uiWarn(fmt.Sprintf("Gum bootstrap failed: %v", err))
	}
	i.printInstallerBanner()
	i.printGumStatus()

	i.detectOSOrDie()
	i.tagline = i.pickTagline()

	if i.config.DryRun {
		i.uiSuccess("Dry run complete (no changes made)")
		return nil
	}

	i.uiInfo("Preparing environment")
	if err := i.installHomebrew(); err != nil {
		return err
	}

	nodeOk, err := i.checkNode()
	if err != nil {
		return err
	}
	if !nodeOk {
		if err := i.installNode(); err != nil {
			return err
		}
	}

	i.uiInfo("Installing OpenClaw")
	switch i.config.InstallMethod {
	case "git":
		if err := i.installOpenClawGit(); err != nil {
			return err
		}
	case "npm", "":
		if err := i.installOpenClawNPM(); err != nil {
			return err
		}
	default:
		return fmt.Errorf("invalid install method: %s", i.config.InstallMethod)
	}

	i.uiInfo("Finalizing setup")
	i.uiSuccess("🦞 OpenClaw installed successfully!")

	if i.config.VerifyInstall {
		if err := i.verifyInstallation(); err != nil {
			return err
		}
	}

	return nil
}

func (i *Installer) verifyInstallation() error {
	cmd := exec.Command("openclaw", "--version")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("openclaw not found: %v", err)
	}
	i.uiSuccess(fmt.Sprintf("OpenClaw version: %s", strings.TrimSpace(string(output))))
	return nil
}

func (i *Installer) printUsage() {
	fmt.Println(`OpenClaw installer (macOS + Linux)

Usage:
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- [options]

Options:
  --install-method, --method npm|git   Install via npm (default) or from a git checkout
  --npm                               Shortcut for --install-method npm
  --git, --github                     Shortcut for --install-method git
  --version <version|dist-tag|spec>    npm install target (default: latest; use "main" for GitHub main)
  --beta                               Use beta if available, else latest
  --git-dir, --dir <path>             Checkout directory (default: ~/openclaw)
  --no-git-update                      Skip git pull for existing checkout
  --no-onboard                          Skip onboarding (non-interactive)
  --no-prompt                           Disable prompts (required in CI/automation)
  --verify                              Run a post-install smoke verify
  --dry-run                             Print what would happen (no changes)
  --verbose                             Print debug output (set -x, npm verbose)
  --help, -h                            Show this help

Environment variables:
  OPENCLAW_INSTALL_METHOD=git|npm
  OPENCLAW_VERSION=latest|next|main|<semver>|<spec>
  OPENCLAW_BETA=0|1
  OPENCLAW_GIT_DIR=...
  OPENCLAW_GIT_UPDATE=0|1
  OPENCLAW_NO_PROMPT=1
  OPENCLAW_VERIFY_INSTALL=1
  OPENCLAW_DRY_RUN=1
  OPENCLAW_NO_ONBOARD=1
  OPENCLAW_VERBOSE=1
  OPENCLAW_NPM_LOGLEVEL=error|warn|notice  Default: error (hide npm deprecation noise)
  SHARP_IGNORE_GLOBAL_LIBVIPS=0|1    Default: 1 (avoid sharp building against global libvips)

Examples:
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard --verify
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --version main
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --install-method git --no-onboard`)
}

func parseArgs() InstallerConfig {
	cfg := InstallerConfig{
		OpenClawVersion: "latest",
		GitDir:          filepath.Join(os.Getenv("HOME"), "openclaw"),
		GitUpdate:       true,
	}

	for i := 1; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--no-onboard":
			cfg.NoOnboard = true
		case "--dry-run":
			cfg.DryRun = true
		case "--verbose":
			cfg.Verbose = true
		case "--verify":
			cfg.VerifyInstall = true
		case "--no-prompt":
			cfg.NoPrompt = true
		case "--help", "-h":
			cfg.Help = true
		case "--install-method", "--method":
			if i+1 < len(os.Args) {
				cfg.InstallMethod = os.Args[i+1]
				i++
			}
		case "--version":
			if i+1 < len(os.Args) {
				cfg.OpenClawVersion = os.Args[i+1]
				i++
			}
		case "--beta":
			cfg.UseBeta = true
		case "--npm":
			cfg.InstallMethod = "npm"
		case "--git", "--github":
			cfg.InstallMethod = "git"
		case "--git-dir", "--dir":
			if i+1 < len(os.Args) {
				cfg.GitDir = os.Args[i+1]
				i++
			}
		case "--no-git-update":
			cfg.GitUpdate = false
		}
	}

	if cfg.UseBeta && cfg.OpenClawVersion == "latest" {
		cfg.OpenClawVersion = "next"
	}

	return cfg
}

func main() {
	cfg := parseArgs()
	installer := NewInstaller(cfg)
	if err := installer.main(); err != nil {
		installer.uiError(err.Error())
		os.Exit(1)
	}
}
