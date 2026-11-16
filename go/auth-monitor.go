// abstraction-provenance: {"artifact_sha256": "cbc5e61af8263b9eee9d3913d5ce1a1f57ae15203144eb3e5e1f9d97069bfda4", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "go"}
// auth-monitor.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

// Auth Expiry Monitor
// Run via cron or systemd timer to get proactive notifications
// before Claude Code auth expires.
//
// Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.sh
//
// Environment variables:
//   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
//   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
//   WARN_HOURS   - Hours before expiry to warn (default: 2)

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Credentials struct {
	ClaudeAiOauth struct {
		ExpiresAt int64 `json:"expiresAt"`
	} `json:"claudeAiOauth"`
}

func main() {
	scriptDir := filepath.Dir(os.Args[0])
	claudeCreds := filepath.Join(os.Getenv("HOME"), ".claude", ".credentials.json")
	stateFile := filepath.Join(os.Getenv("HOME"), ".openclaw", "auth-monitor-state")

	// Configuration
	warnHoursStr := getEnvOrDefault("WARN_HOURS", "2")
	warnHours, _ := strconv.Atoi(warnHoursStr)
	notifyPhone := os.Getenv("NOTIFY_PHONE")
	notifyNtfy := os.Getenv("NOTIFY_NTFY")

	// State tracking to avoid spam
	os.MkdirAll(filepath.Dir(stateFile), 0755)
	lastNotifiedContent, _ := ioutil.ReadFile(stateFile)
	lastNotified, _ := strconv.ParseInt(strings.TrimSpace(string(lastNotifiedContent)), 10, 64)
	now := time.Now().Unix()
	minInterval := int64(3600)

	sendNotification := func(message string, priority string) {
		fmt.Printf("%s - %s\n", time.Now().Format("2006-01-02 15:04:05"), message)

		// Check if we notified recently
		if now-lastNotified < minInterval {
			fmt.Println("Skipping notification (sent recently)")
			return
		}

		// Send via OpenClaw if phone configured and auth still valid
		if notifyPhone != "" {
			// Check if we can still use openclaw
			cmd := exec.Command(filepath.Join(scriptDir, "claude-auth-status.sh"), "simple")
			var out bytes.Buffer
			cmd.Stdout = &out
			err := cmd.Run()
			if err == nil {
				output := out.String()
				if strings.Contains(output, "OK") || strings.Contains(output, "EXPIRING") {
					fmt.Printf("Sending via OpenClaw to %s...\n", notifyPhone)
					openclawCmd := exec.Command("openclaw", "send", "--to", notifyPhone, "--message", message)
					openclawCmd.Run()
				}
			}
		}

		// Send via ntfy.sh if configured
		if notifyNtfy != "" {
			fmt.Printf("Sending via ntfy.sh to %s...\n", notifyNtfy)
			payload := strings.NewReader(message)
			req, _ := http.NewRequest("POST", "https://ntfy.sh/"+notifyNtfy, payload)
			req.Header.Set("Title", "OpenClaw Auth Alert")
			req.Header.Set("Priority", priority)
			req.Header.Set("Tags", "warning,key")
			client := &http.Client{}
			client.Do(req)
		}

		// Update state
		ioutil.WriteFile(stateFile, []byte(strconv.FormatInt(now, 10)), 0644)
	}

	// Check auth status
	if _, err := os.Stat(claudeCreds); os.IsNotExist(err) {
		sendNotification("Claude Code credentials missing! Run: claude setup-token", "high")
		os.Exit(1)
	}

	credsData, err := ioutil.ReadFile(claudeCreds)
	if err != nil {
		sendNotification("Failed to read Claude Code credentials!", "high")
		os.Exit(1)
	}

	var creds Credentials
	if err := json.Unmarshal(credsData, &creds); err != nil {
		sendNotification("Failed to parse Claude Code credentials!", "high")
		os.Exit(1)
	}

	expiresAt := creds.ClaudeAiOauth.ExpiresAt
	nowMs := now * 1000
	diffMs := expiresAt - nowMs
	hoursLeft := diffMs / 3600000
	minsLeft := (diffMs % 3600000) / 60000

	if diffMs < 0 {
		sendNotification("Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'", "urgent")
		os.Exit(1)
	} else if hoursLeft < int64(warnHours) {
		sendNotification(fmt.Sprintf("Claude Code auth expires in %dh %dm. Consider re-auth soon.", hoursLeft, minsLeft), "high")
		os.Exit(0)
	} else {
		fmt.Printf("%s - Auth OK: %dh %dm remaining\n", time.Now().Format("2006-01-02 15:04:05"), hoursLeft, minsLeft)
		os.Exit(0)
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
