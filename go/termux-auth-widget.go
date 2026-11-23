// abstraction-provenance: {"artifact_sha256": "cb11fa4b7964ebad469c1a277c66f161547da438797fb6096e353932c1698f75", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "go"}
// termux-auth-widget.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

// Server hostname (via Tailscale or SSH config)
var server = func() string {
	if s := os.Getenv("OPENCLAW_SERVER"); s != "" {
		return s
	}
	return "l36"
}()

type DialogResponse struct {
	Text string `json:"text"`
}

type AuthStatus struct {
	ClaudeCode struct {
		Status string `json:"status"`
	} `json:"claude_code"`
}

func main() {
	// Check auth status
	termuxToast("Checking OpenClaw auth...")

	statusOutput, exitCode := runSSHCommand(fmt.Sprintf("$HOME/openclaw/scripts/claude-auth-status.sh simple"))
	
	switch strings.TrimSpace(statusOutput) {
	case "OK":
		// Get remaining time
		detailsOutput, _ := runSSHCommand(fmt.Sprintf("$HOME/openclaw/scripts/claude-auth-status.sh json"))
		
		var authStatus AuthStatus
		if err := json.Unmarshal([]byte(detailsOutput), &authStatus); err != nil {
			termuxToast("Error parsing JSON")
			return
		}
		
		re := regexp.MustCompile(`(\d+)h`)
		matches := re.FindStringSubmatch(authStatus.ClaudeCode.Status)
		hours := "?"
		if len(matches) > 1 {
			hours = matches[1]
		}
		
		termuxVibrate(50)
		termuxToast(fmt.Sprintf("Auth OK (%sh left)", hours))
		
	case "CLAUDE_EXPIRING", "OPENCLAW_EXPIRING":
		termuxVibrate(100)
		
		// Ask if user wants to re-auth now
		choice := termuxDialogRadio("Auth Expiring Soon", []string{"Re-auth now", "Check later", "Dismiss"})
		selected := parseDialogResponse(choice)
		
		switch selected {
		case "Re-auth now":
			termuxToast("Opening auth page...")
			termuxOpenURL("https://console.anthropic.com/settings/api-keys")
			
			// Show instructions
			termuxDialogConfirm("Re-auth Instructions", "1. Create/copy API key from browser\n2. Return here and tap OK\n3. SSH to server and paste key")
			
			// Open terminal to server
			startTermuxActivity()
			termuxToast(fmt.Sprintf("Run: ssh %s '$HOME/openclaw/scripts/mobile-reauth.sh'", server))
		default:
			termuxToast("Reminder: Auth expires soon")
		}
		
	case "CLAUDE_EXPIRED", "OPENCLAW_EXPIRED":
		termuxVibrate(300)
		
		choice := termuxDialogRadio("Auth Expired!", []string{"Re-auth now", "Dismiss"})
		selected := parseDialogResponse(choice)
		
		switch selected {
		case "Re-auth now":
			termuxToast("Opening auth page...")
			termuxOpenURL("https://console.anthropic.com/settings/api-keys")
			
			termuxDialogConfirm("Re-auth Steps", "1. Create/copy API key from browser\n2. Return here and tap OK to SSH")
			
			startTermuxActivity()
			termuxToast(fmt.Sprintf("Run: ssh %s '$HOME/openclaw/scripts/mobile-reauth.sh'", server))
		default:
			termuxToast("Warning: OpenClaw won't work until re-auth")
		}
		
	default:
		termuxVibrate(200)
		if exitCode != 0 {
			termuxToast(fmt.Sprintf("Error: %s", statusOutput))
		} else {
			termuxToast(fmt.Sprintf("Unknown status: %s", statusOutput))
		}
	}
}

func runSSHCommand(command string) (string, int) {
	cmd := exec.Command("ssh", server, command)
	output, err := cmd.CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		}
	}
	return string(output), exitCode
}

func termuxToast(message string) {
	cmd := exec.Command("termux-toast", message)
	cmd.Run()
}

func termuxVibrate(duration int) {
	cmd := exec.Command("termux-vibrate", "-d", fmt.Sprintf("%d", duration))
	cmd.Run()
}

func termuxDialogRadio(title string, values []string) string {
	valueStr := strings.Join(values, ",")
	cmd := exec.Command("termux-dialog", "radio", "-t", title, "-v", valueStr)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return string(output)
}

func termuxDialogConfirm(title, text string) {
	cmd := exec.Command("termux-dialog", "confirm", "-t", title, "-i", text)
	cmd.Run()
}

func termuxOpenURL(url string) {
	cmd := exec.Command("termux-open-url", url)
	cmd.Run()
}

func startTermuxActivity() {
	cmd := exec.Command("am", "start", "-n", "com.termux/com.termux.app.TermuxActivity", "-a", "android.intent.action.MAIN")
	cmd.Run()
}

func parseDialogResponse(response string) string {
	var dialogResp DialogResponse
	if err := json.Unmarshal([]byte(response), &dialogResp); err != nil {
		return "Dismiss"
	}
	if dialogResp.Text == "" {
		return "Dismiss"
	}
	return dialogResp.Text
}
