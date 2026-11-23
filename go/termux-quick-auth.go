// abstraction-provenance: {"artifact_sha256": "c3e18dfa09a54bfaabc60acbd8da1d69def3de655a0888daddf03a068d9d15f2", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "go"}
// termux-quick-auth.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	server := os.Getenv("OPENCLAW_SERVER")
	if server == "" {
		server = "l36"
	}

	status := getSshStatus(server)
	
	switch {
	case status == "OK":
		showToast(true, "Auth OK")
	case strings.Contains(status, "EXPIRING"):
		vibrate(100)
		showToast(false, "Auth expiring soon - tap again if needed")
	case strings.Contains(status, "EXPIRED") || strings.Contains(status, "MISSING"):
		vibrate(200)
		showToast(false, "Auth expired - opening console...")
		openUrl("https://console.anthropic.com/settings/api-keys")
		time.Sleep(2 * time.Second)
		showNotification("OpenClaw Re-Auth", fmt.Sprintf("After getting key, run: ssh %s '~/openclaw/scripts/mobile-reauth.sh'", server), "openclaw-auth")
	default:
		showToast(false, "Connection error")
	}
}

func getSshStatus(server string) string {
	cmd := exec.Command("ssh", "-o", "ConnectTimeout=5", server, "$HOME/openclaw/scripts/claude-auth-status.sh simple")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output)
	}
	return strings.TrimSpace(string(output))
}

func showToast(short bool, message string) {
	args := []string{}
	if short {
		args = append(args, "-s")
	}
	args = append(args, message)
	
	cmd := exec.Command("termux-toast", args...)
	cmd.Run()
}

func vibrate(duration int) {
	cmd := exec.Command("termux-vibrate", "-d", fmt.Sprintf("%d", duration))
	cmd.Run()
}

func openUrl(url string) {
	cmd := exec.Command("termux-open-url", url)
	cmd.Run()
}

func showNotification(title, content, id string) {
	cmd := exec.Command("termux-notification", "-t", title, "-c", content, "--id", id)
	cmd.Run()
}
