// abstraction-provenance: {"artifact_sha256": "907a0546a94e824d4237bf5e5fa6ceb54a555f87e86efc49dc5d71056608825c", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "go"}
// termux-sync-widget.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
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
	showToast("Syncing OpenClaw auth...")

	server := os.Getenv("OPENCLAW_SERVER")
	if server == "" {
		server = "l36"
	}

	cmd := exec.Command("ssh", server, "/home/admin/openclaw/scripts/sync-claude-code-auth.sh")
	result, err := cmd.CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		} else {
			exitCode = 1
		}
	}

	if exitCode == 0 {
		expiry := ""
		lines := strings.Split(string(result), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Token expires:") {
				parts := strings.SplitN(line, ":", 2)
				if len(parts) > 1 {
					expiry = strings.TrimSpace(parts[1])
				}
				break
			}
		}

		vibrate(100)
		showToast(fmt.Sprintf("OpenClaw synced! Expires:%s", expiry))

		restartCmd := exec.Command("ssh", server, "systemctl --user restart openclaw")
		restartCmd.Run()
	} else {
		vibrate(300)
		showToast(fmt.Sprintf("Sync failed: %s", string(result)))
	}
}

func showToast(message string) {
	cmd := exec.Command("termux-toast", message)
	cmd.Run()
}

func vibrate(duration int) {
	cmd := exec.Command("termux-vibrate", "-d", fmt.Sprintf("%d", duration))
	cmd.Run()
}
