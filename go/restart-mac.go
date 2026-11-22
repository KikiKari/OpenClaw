// abstraction-provenance: {"artifact_sha256": "6fcc354a4dbd07d0952e19adabdfd46d7ce9d832389c3c3e1105383b9ef56b15", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "go"}
// restart-mac.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

// Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.

package main

import (
	"crypto/sha256"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var (
	rootDir                string
	appBundle              string
	appProcessPattern      string
	debugProcessPattern    string
	localProcessPattern    string
	releaseProcessPattern  string
	launchAgent            string
	lockKey                string
	lockDir                string
	lockPidFile            string
	waitForLock            bool
	logPath                string
	noSign                 bool
	sign                   bool
	autoDetectSigning      bool
	gatewayWaitSeconds     int
	launchagentDisableMarker string
	attachOnly             bool
)

func init() {
	var err error
	rootDir, err = os.Getwd()
	if err != nil {
		fail("Failed to get current directory: %v", err)
	}
	
	// Get script directory and go up one level
	scriptDir := filepath.Dir(os.Args[0])
	rootDir = filepath.Join(scriptDir, "..")
	
	appBundle = os.Getenv("OPENCLAW_APP_BUNDLE")
	appProcessPattern = "OpenClaw.app/Contents/MacOS/OpenClaw"
	debugProcessPattern = filepath.Join(rootDir, "apps/macos/.build/debug/OpenClaw")
	localProcessPattern = filepath.Join(rootDir, "apps/macos/.build-local/debug/OpenClaw")
	releaseProcessPattern = filepath.Join(rootDir, "apps/macos/.build/release/OpenClaw")
	launchAgent = filepath.Join(os.Getenv("HOME"), "Library/LaunchAgents/ai.openclaw.mac.plist")
	
	h := sha256.New()
	h.Write([]byte(rootDir))
	lockKey = fmt.Sprintf("%x", h.Sum(nil))[:8]
	tmpDir := os.Getenv("TMPDIR")
	if tmpDir == "" {
		tmpDir = "/tmp"
	}
	lockDir = filepath.Join(tmpDir, "openclaw-restart-"+lockKey)
	lockPidFile = filepath.Join(lockDir, "pid")
	waitForLock = false
	logPath = "/tmp/openclaw-restart.log"
	if envLogPath := os.Getenv("OPENCLAW_RESTART_LOG"); envLogPath != "" {
		logPath = envLogPath
	}
	noSign = false
	sign = false
	autoDetectSigning = true
	gatewayWaitSeconds = 0
	if envGatewayWait := os.Getenv("OPENCLAW_GATEWAY_WAIT_SECONDS"); envGatewayWait != "" {
		if gw, err := strconv.Atoi(envGatewayWait); err == nil {
			gatewayWaitSeconds = gw
		}
	}
	launchagentDisableMarker = filepath.Join(os.Getenv("HOME"), ".openclaw/disable-launchagent")
	attachOnly = true
}

func log(format string, args ...interface{}) {
	fmt.Printf(format+"\n", args...)
}

func fail(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}

func runStep(label string, cmd *exec.Cmd) {
	log("==> %s", label)
	if err := cmd.Run(); err != nil {
		fail("%s failed: %v", label, err)
	}
}

func cleanup() {
	if _, err := os.Stat(lockDir); err == nil {
		os.RemoveAll(lockDir)
	}
}

func acquireLock() {
	for {
		err := os.Mkdir(lockDir, 0755)
		if err == nil {
			ioutil.WriteFile(lockPidFile, []byte(fmt.Sprintf("%d", os.Getpid())), 0644)
			return
		}

		existingPidBytes, err := ioutil.ReadFile(lockPidFile)
		if err != nil {
			os.RemoveAll(lockDir)
			continue
		}

		existingPid, err := strconv.Atoi(strings.TrimSpace(string(existingPidBytes)))
		if err != nil {
			os.RemoveAll(lockDir)
			continue
		}

		process, err := os.FindProcess(existingPid)
		if err == nil && process.Signal(syscall.Signal(0)) == nil {
			if waitForLock {
				log("==> Another restart is running (pid %d); waiting...", existingPid)
				for {
					if process.Signal(syscall.Signal(0)) != nil {
						break
					}
					time.Sleep(time.Second)
				}
				continue
			}
			log("==> Another restart is running (pid %d); re-run with --wait.", existingPid)
			os.Exit(0)
		}

		os.RemoveAll(lockDir)
	}
}

func checkSigningKeys() bool {
	cmd := exec.Command("security", "find-identity", "-p", "codesigning", "-v")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	
	outputStr := string(output)
	return strings.Contains(outputStr, "Developer ID Application") ||
		   strings.Contains(outputStr, "Apple Distribution") ||
		   strings.Contains(outputStr, "Apple Development")
}

func parseArgs() {
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--wait", "-w":
			waitForLock = true
		case "--no-sign":
			noSign = true
			autoDetectSigning = false
		case "--sign":
			sign = true
			autoDetectSigning = false
		case "--attach-only":
			attachOnly = true
		case "--no-attach-only":
			attachOnly = false
		case "--help", "-h":
			showHelp()
			os.Exit(0)
		}
	}
	
	if noSign && sign {
		fail("Cannot use --sign and --no-sign together")
	}
}

func showHelp() {
	progName := filepath.Base(os.Args[0])
	log("Usage: %s [--wait] [--no-sign] [--sign] [--attach-only|--no-attach-only]", progName)
	log("  --wait    Wait for other restart to complete instead of exiting")
	log("  --no-sign Force no code signing (fastest for development)")
	log("  --sign    Force code signing (will fail if no signing key available)")
	log("  --attach-only    Launch app with --attach-only (skip launchd install)")
	log("  --no-attach-only Launch app without attach-only override")
	log("")
	log("Env:")
	log("  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)")
	log("")
	log("Unsigned recovery:")
	log("  node openclaw.mjs daemon install --force --runtime node")
	log("  node openclaw.mjs daemon restart")
	log("")
	log("Reset unsigned overrides:")
	log("  rm ~/.openclaw/disable-launchagent")
	log("")
	log("Default behavior: Auto-detect signing keys, fallback to --no-sign if none found")
}

func killAllOpenclaw() {
	for i := 0; i < 10; i++ {
		exec.Command("pkill", "-f", appProcessPattern).Run()
		exec.Command("pkill", "-f", debugProcessPattern).Run()
		exec.Command("pkill", "-f", localProcessPattern).Run()
		exec.Command("pkill", "-f", releaseProcessPattern).Run()
		exec.Command("pkill", "-x", "OpenClaw").Run()
		
		if !processExists(appProcessPattern) &&
		   !processExists(debugProcessPattern) &&
		   !processExists(localProcessPattern) &&
		   !processExists(releaseProcessPattern) &&
		   !processExistsByName("OpenClaw") {
			return
		}
		time.Sleep(300 * time.Millisecond)
	}
}

func processExists(pattern string) bool {
	cmd := exec.Command("pgrep", "-f", pattern)
	return cmd.Run() == nil
}

func processExistsByName(name string) bool {
	cmd := exec.Command("pgrep", "-x", name)
	return cmd.Run() == nil
}

func stopLaunchAgent() {
	exec.Command("launchctl", "bootout", fmt.Sprintf("gui/%d/ai.openclaw.mac", os.Getuid())).Run()
}

func chooseAppBundle() {
	if appBundle != "" {
		if _, err := os.Stat(appBundle); err == nil {
			return
		}
	}
	
	candidatePaths := []string{
		"/Applications/OpenClaw.app",
		filepath.Join(rootDir, "dist/OpenClaw.app"),
	}
	
	for _, path := range candidatePaths {
		if _, err := os.Stat(path); err == nil {
			appBundle = path
			if strings.Contains(path, "dist/OpenClaw.app") {
				sparkleFramework := filepath.Join(appBundle, "Contents/Frameworks/Sparkle.framework")
				if _, err := os.Stat(sparkleFramework); os.IsNotExist(err) {
					fail("dist/OpenClaw.app missing Sparkle after packaging")
				}
			}
			return
		}
	}
	
	fail("App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app")
}

func main() {
	parseArgs()
	
	// Setup logging
	logFile, err := os.Create(logPath)
	if err != nil {
		fail("Failed to create log file: %v", err)
	}
	defer logFile.Close()
	
	// Redirect stdout/stderr to log file
	oldStdout := os.Stdout
	oldStderr := os.Stderr
	os.Stdout = logFile
	os.Stderr = logFile
	
	// Also write to original stdout for immediate feedback
	multiWriter := &multiWriter{oldStdout, logFile}
	os.Stdout = multiWriter
	os.Stderr = multiWriter
	
	log("==> Log: %s", logPath)
	if noSign {
		log("==> Using --no-sign (unsigned flow enabled)")
	}
	if attachOnly {
		log("==> Using --attach-only (skip launchd install)")
	}
	
	acquireLock()
	defer cleanup()
	
	// Kill all running instances first
	log("==> Killing existing OpenClaw instances")
	killAllOpenclaw()
	stopLaunchAgent()
	
	// Bundle Gateway-hosted Canvas A2UI assets
	bundleCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s' && pnpm canvas:a2ui:bundle", rootDir))
	runStep("bundle canvas a2ui", bundleCmd)
	
	// Rebuild into the same path the packager consumes (.build)
	cleanCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s/apps/macos' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true", rootDir))
	runStep("clean build cache", cleanCmd)
	
	buildCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s/apps/macos' && swift build -q --product OpenClaw", rootDir))
	runStep("swift build", buildCmd)
	
	if autoDetectSigning {
		if checkSigningKeys() {
			log("==> Signing keys detected, will code sign")
			sign = true
		} else {
			log("==> No signing keys found, will skip code signing (--no-sign)")
			noSign = true
		}
	}
	
	if noSign {
		os.Setenv("ALLOW_ADHOC_SIGNING", "1")
		os.Setenv("SIGN_IDENTITY", "-")
		os.MkdirAll(filepath.Join(os.Getenv("HOME"), ".openclaw"), 0755)
		touchCmd := exec.Command("/usr/bin/touch", launchagentDisableMarker)
		runStep("disable launchagent writes", touchCmd)
	} else if sign {
		if !checkSigningKeys() {
			fail("No signing identity found. Use --no-sign or install a signing key.")
		}
		os.Unsetenv("ALLOW_ADHOC_SIGNING")
		os.Unsetenv("SIGN_IDENTITY")
	}
	
	// Package app (no embedded gateway)
	packageCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s' && SKIP_TSC=${SKIP_TSC:-1} '%s/scripts/package-mac-app.sh'", rootDir, rootDir))
	runStep("package app", packageCmd)
	
	chooseAppBundle()
	
	// When signed, clear any previous launchagent override marker
	if !noSign && !attachOnly {
		if _, err := os.Stat(launchagentDisableMarker); err == nil {
			rmCmd := exec.Command("/bin/rm", "-f", launchagentDisableMarker)
			runStep("clear launchagent disable marker", rmCmd)
		}
	}
	
	// When unsigned, ensure the gateway LaunchAgent targets the repo CLI
	if noSign && !attachOnly {
		installCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s' && node openclaw.mjs daemon install --force --runtime node", rootDir))
		runStep("install gateway launch agent (unsigned)", installCmd)
		
		restartCmd := exec.Command("bash", "-lc", fmt.Sprintf("cd '%s' && node openclaw.mjs daemon restart", rootDir))
		runStep("restart gateway daemon (unsigned)", restartCmd)
		
		if gatewayWaitSeconds > 0 {
			sleepCmd := exec.Command("sleep", strconv.Itoa(gatewayWaitSeconds))
			runStep("wait for gateway (unsigned)", sleepCmd)
		}
		
		// Get gateway port
		nodeCmd := exec.Command("node", "-e", `
			const fs = require("node:fs");
			const path = require("node:path");
			try {
				const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
				const cfg = JSON.parse(raw);
				const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
				process.stdout.write(String(port));
			} catch {
				process.stdout.write("18789");
			}
		`)
		portOutput, err := nodeCmd.Output()
		if err != nil {
			fail("Failed to get gateway port: %v", err)
		}
		gatewayPort := strings.TrimSpace(string(portOutput))
		
		lsofCmd := exec.Command("bash", "-lc", fmt.Sprintf("lsof -iTCP:%s -sTCP:LISTEN | head -n 5 || true", gatewayPort))
		runStep(fmt.Sprintf("verify gateway port %s (unsigned)", gatewayPort), lsofCmd)
	}
	
	// Launch the installed app
	var attachOnlyArgs []string
	if attachOnly {
		attachOnlyArgs = []string{"--args", "--attach-only"}
	}
	
	envCmd := exec.Command("/usr/bin/open", append([]string{appBundle}, attachOnlyArgs...)...)
	envCmd.Env = []string{
		"HOME=" + os.Getenv("HOME"),
		"USER=" + func() string {
			user := os.Getenv("USER")
			if user == "" {
				user = func() string {
					out, _ := exec.Command("id", "-un").Output()
					return strings.TrimSpace(string(out))
				}()
			}
			return user
		}(),
		"LOGNAME=" + func() string {
			logname := os.Getenv("LOGNAME")
			if logname == "" {
				logname = func() string {
					out, _ := exec.Command("id", "-un").Output()
					return strings.TrimSpace(string(out))
				}()
			}
			return logname
		}(),
		"TMPDIR=" + func() string {
			tmpdir := os.Getenv("TMPDIR")
			if tmpdir == "" {
				tmpdir = "/tmp"
			}
			return tmpdir
		}(),
		"PATH=/usr/bin:/bin:/usr/sbin:/sbin",
		"LANG=en_US.UTF-8",
	}
	runStep("launch app", envCmd)
	
	// Verify the app is alive
	time.Sleep(1500 * time.Millisecond)
	if processExists(appProcessPattern) {
		log("OK: OpenClaw is running.")
	} else {
		fail("App exited immediately. Check %s or Console.app (User Reports).", logPath)
	}
	
	if noSign && !attachOnly {
		plutilCmd := exec.Command("bash", "-lc", fmt.Sprintf("/usr/bin/plutil -p '%s/Library/LaunchAgents/ai.openclaw.gateway.plist' | head -n 40 || true", os.Getenv("HOME")))
		runStep("show gateway launch agent args (unsigned)", plutilCmd)
	}
}

type multiWriter struct {
	writers []interface{ Write([]byte) (int, error) }
}

func (mw *multiWriter) Write(p []byte) (int, error) {
	for _, w := range mw.writers {
		w.Write(p)
	}
	return len(p), nil
}
