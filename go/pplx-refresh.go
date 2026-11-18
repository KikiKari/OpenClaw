// abstraction-provenance: {"artifact_sha256": "507972510e8aff87638b06c30d2d81bf256c890e409fffd86a42fed41656b617", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "go"}
// pplx-refresh.sh — portiert nach go
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

// Refresh the codespace Perplexity session from a locally-exported cookie.
//
// Usage:
//   go run pplx-refresh.go [cookie-file]
//
// cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
// __Secure-next-auth.session-token value (raw), or the whole Cookie header,
// or a JSON cookie export, into that file first.
//
// Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
//        -> trigger reinit -> verify authenticated.

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

func main() {
	if len(os.Args) > 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s [cookie-file]\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}

	cfg := getEnvOrDefault("PERPLEXITY_CONFIG_DIR", filepath.Join(os.Getenv("HOME"), ".perplexity-mcp"))
	profile := getEnvOrDefault("PERPLEXITY_PROFILE", "codespace")
	cookieFile := filepath.Join(os.Getenv("HOME"), "pplx-cookies.txt")
	if len(os.Args) == 2 {
		cookieFile = os.Args[1]
	}

	if _, err := os.Stat(cookieFile); os.IsNotExist(err) || isEmptyFile(cookieFile) {
		fmt.Fprintf(os.Stderr, "✗ Cookie file empty/missing: %s\n", cookieFile)
		fmt.Fprintln(os.Stderr, "  Export __Secure-next-auth.session-token from your local browser")
		fmt.Fprintln(os.Stderr, "  (DevTools → Application → Cookies → www.perplexity.ai) into that file.")
		os.Exit(1)
	}

	here, _ := filepath.Abs(filepath.Dir(os.Args[0]))

	// 1. ensure the extension daemon has a usable browser (idempotent)
	cmd := exec.Command("bash", filepath.Join(here, "pplx-setup.sh"))
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "✗ Failed to run pplx-setup.sh: %v\n", err)
		os.Exit(1)
	}

	// 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
	lock := filepath.Join(cfg, "daemon.lock")
	if _, err := os.Stat(lock); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "✗ no daemon.lock at %s — is the extension running?\n", lock)
		os.Exit(1)
	}

	pid, err := getPidFromLock(lock)
	if err != nil {
		fmt.Fprintf(os.Stderr, "✗ failed to read pid from lock: %v\n", err)
		os.Exit(1)
	}

	if !isProcessRunning(pid) {
		fmt.Fprintf(os.Stderr, "✗ daemon pid %d not running\n", pid)
		os.Exit(1)
	}

	pass, err := getPassphraseFromProc(pid)
	if err != nil || pass == "" {
		fmt.Fprintln(os.Stderr, "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env")
		os.Exit(1)
	}

	// 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
	dist := findDist()
	if dist == "" {
		cmd = exec.Command("npx", "-y", "perplexity-user-mcp", "--version")
		cmd.Stdout = io.Discard
		cmd.Stderr = io.Discard
		_ = cmd.Run()
		dist = findDist()
	}
	if dist == "" {
		fmt.Fprintln(os.Stderr, "✗ could not find perplexity-user-mcp dist")
		os.Exit(1)
	}

	// 4. inject
	env := []string{
		fmt.Sprintf("PERPLEXITY_VAULT_PASSPHRASE=%s", pass),
		fmt.Sprintf("PERPLEXITY_CONFIG_DIR=%s", cfg),
		fmt.Sprintf("PERPLEXITY_PROFILE=%s", profile),
		fmt.Sprintf("PPLX_DIST=%s", dist),
	}
	injectScript := filepath.Join(here, "pplx-inject.mjs")
	cmd = exec.Command("node", injectScript, cookieFile)
	cmd.Env = append(os.Environ(), env...)
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "✗ Failed to run pplx-inject.mjs: %v\n", err)
		os.Exit(1)
	}

	// 5. trigger daemon reinit
	reinitPath := filepath.Join(cfg, "profiles", profile, ".reinit")
	if err := os.WriteFile(reinitPath, []byte(fmt.Sprintf("%d", time.Now().Unix())), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "✗ Failed to write .reinit: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("→ reinit triggered, waiting for daemon...")

	// 6. verify
	stat := filepath.Join(cfg, "profiles", profile, "daemon-status.json")
	for i := 1; i <= 20; i++ {
		time.Sleep(1500 * time.Millisecond)
		auth, tier := getStatus(stat)
		if auth == "true" {
			fmt.Printf("✅ authenticated — tier: %s\n", tier)
			return
		}
	}
	fmt.Printf("⚠️  not authenticated yet. Check: tail -20 %s\n", filepath.Join(cfg, "daemon.log"))
	os.Exit(1)
}

func getEnvOrDefault(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}

func isEmptyFile(path string) bool {
	info, err := os.Stat(path)
	return os.IsNotExist(err) || info.Size() == 0
}

func getPidFromLock(lockPath string) (int, error) {
	data, err := os.ReadFile(lockPath)
	if err != nil {
		return 0, err
	}
	var lockData map[string]interface{}
	if err := json.Unmarshal(data, &lockData); err != nil {
		return 0, err
	}
	pidFloat, ok := lockData["pid"].(float64)
	if !ok {
		return 0, fmt.Errorf("invalid pid in lock file")
	}
	return int(pidFloat), nil
}

func isProcessRunning(pid int) bool {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("tasklist", "/fi", fmt.Sprintf("PID eq %d", pid))
	} else {
		cmd = exec.Command("ps", "-p", strconv.Itoa(pid), "-o", "pid=")
	}
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), strconv.Itoa(pid))
}

func getPassphraseFromProc(pid int) (string, error) {
	environPath := fmt.Sprintf("/proc/%d/environ", pid)
	file, err := os.Open(environPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	reader := bufio.NewReader(file)
	data, err := io.ReadAll(reader)
	if err != nil {
		return "", err
	}

	lines := strings.Split(string(data), "\x00")
	for _, line := range lines {
		if strings.HasPrefix(line, "PERPLEXITY_VAULT_PASSPHRASE=") {
			return strings.TrimPrefix(line, "PERPLEXITY_VAULT_PASSPHRASE="), nil
		}
	}
	return "", nil
}

func findDist() string {
	npxDir := filepath.Join(os.Getenv("HOME"), ".npm", "_npx")
	err := filepath.Walk(npxDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && strings.Contains(path, "perplexity-user-mcp/dist") {
			// Found it, stop walking
			return filepath.SkipDir
		}
		return nil
	})
	if err != nil {
		return ""
	}
	
	// Try to find the path again after walk
	var result string
	_ = filepath.Walk(npxDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && strings.HasSuffix(path, "perplexity-user-mcp/dist") {
			result = path
			return filepath.SkipDir
		}
		return nil
	})
	return result
}

func getStatus(statusFile string) (auth, tier string) {
	data, err := os.ReadFile(statusFile)
	if err != nil {
		return "", ""
	}
	var status map[string]interface{}
	if err := json.Unmarshal(data, &status); err != nil {
		return "", ""
	}
	authVal, _ := status["authenticated"].(bool)
	tierVal, _ := status["tier"].(string)
	return strconv.FormatBool(authVal), tierVal
}
