// abstraction-provenance: {"artifact_sha256": "17e2472f2b8fb93ab207d77d97daf557124139c70204f6f7f2ea1bf0bd91462f", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "go"}
// setup-auth-system.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	scriptDir := filepath.Dir(os.Args[0])
	
	fmt.Println("=== OpenClaw Auth System Setup ===")
	fmt.Println("")
	
	// Step 1: Check current auth status
	fmt.Println("Step 1: Checking current auth status...")
	cmd := exec.Command(filepath.Join(scriptDir, "claude-auth-status.sh"), "full")
	cmd.Run() // ignore error like in original
	fmt.Println("")
	
	// Step 2: Set up long-lived token
	fmt.Println("Step 2: Long-lived token setup")
	fmt.Println("")
	fmt.Println("Option A: Use 'claude setup-token' (recommended)")
	fmt.Println("  - Creates a long-lived API token")
	fmt.Println("  - No daily re-auth needed")
	fmt.Println("  - Run: claude setup-token")
	fmt.Println("")
	fmt.Print("Would you like to set up a long-lived token now? [y/N] ")
	reader := bufio.NewReader(os.Stdin)
	setupToken, _ := reader.ReadString('\n')
	setupToken = strings.TrimSpace(setupToken)
	
	if strings.ToLower(setupToken) == "y" {
		fmt.Println("")
		fmt.Println("Opening https://console.anthropic.com/settings/api-keys")
		fmt.Println("Create a new key or copy existing one, then paste below.")
		fmt.Println("")
		cmd = exec.Command("claude", "setup-token")
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Run()
	}
	
	fmt.Println("")
	
	// Step 3: Set up auth monitoring
	fmt.Println("Step 3: Auth monitoring setup")
	fmt.Println("")
	fmt.Println("The auth monitor checks expiry every 30 minutes and notifies you.")
	fmt.Println("")
	fmt.Println("Configure notification channels:")
	fmt.Println("")
	
	// Check for ntfy
	fmt.Println("  ntfy.sh: Free push notifications to your phone")
	fmt.Println("  1. Install ntfy app on your phone")
	fmt.Println("  2. Subscribe to a topic (e.g., 'openclaw-alerts')")
	fmt.Println("")
	fmt.Print("Enter ntfy.sh topic (or leave blank to skip): ")
	ntfyTopic, _ := reader.ReadString('\n')
	ntfyTopic = strings.TrimSpace(ntfyTopic)
	
	// Phone notification
	fmt.Println("")
	fmt.Println("  OpenClaw message: Send warning via OpenClaw itself")
	fmt.Print("Enter your phone number for alerts (or leave blank to skip): ")
	phoneNumber, _ := reader.ReadString('\n')
	phoneNumber = strings.TrimSpace(phoneNumber)
	
	// Update service file
	serviceFile := filepath.Join(scriptDir, "systemd", "openclaw-auth-monitor.service")
	serviceContent, err := os.ReadFile(serviceFile)
	if err != nil {
		panic(err)
	}
	
	serviceLines := strings.Split(string(serviceContent), "\n")
	for i, line := range serviceLines {
		if strings.HasPrefix(line, "# Environment=NOTIFY_NTFY=") && ntfyTopic != "" {
			serviceLines[i] = fmt.Sprintf("Environment=NOTIFY_NTFY=%s", ntfyTopic)
		}
		if strings.HasPrefix(line, "# Environment=NOTIFY_PHONE=") && phoneNumber != "" {
			serviceLines[i] = fmt.Sprintf("Environment=NOTIFY_PHONE=%s", phoneNumber)
		}
	}
	
	err = os.WriteFile(serviceFile, []byte(strings.Join(serviceLines, "\n")), 0644)
	if err != nil {
		panic(err)
	}
	
	// Install systemd units
	fmt.Println("")
	fmt.Println("Installing systemd timer...")
	configDir := filepath.Join(os.Getenv("HOME"), ".config", "systemd", "user")
	os.MkdirAll(configDir, 0755)
	
	sourceService := filepath.Join(scriptDir, "systemd", "openclaw-auth-monitor.service")
	destService := filepath.Join(configDir, "openclaw-auth-monitor.service")
	copyFile(sourceService, destService)
	
	sourceTimer := filepath.Join(scriptDir, "systemd", "openclaw-auth-monitor.timer")
	destTimer := filepath.Join(configDir, "openclaw-auth-monitor.timer")
	copyFile(sourceTimer, destTimer)
	
	cmd = exec.Command("systemctl", "--user", "daemon-reload")
	cmd.Run()
	
	cmd = exec.Command("systemctl", "--user", "enable", "--now", "openclaw-auth-monitor.timer")
	cmd.Run()
	
	fmt.Println("Auth monitor installed and running.")
	fmt.Println("")
	
	// Step 4: Termux widget setup
	fmt.Println("Step 4: Termux widget setup (for phone)")
	fmt.Println("")
	fmt.Println("To set up quick auth from your phone:")
	fmt.Println("")
	fmt.Println("1. Install Termux and Termux:Widget from F-Droid")
	fmt.Println("2. Create ~/.shortcuts/ directory in Termux:")
	fmt.Println("   mkdir -p ~/.shortcuts")
	fmt.Println("")
	fmt.Printf("3. Copy the widget scripts:\n")
	fmt.Printf("   scp %s/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth\n", scriptDir)
	fmt.Printf("   scp %s/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full\n", scriptDir)
	fmt.Println("")
	fmt.Println("4. Make them executable on phone:")
	fmt.Println("   ssh phone 'chmod +x ~/.shortcuts/Clawd*'")
	fmt.Println("")
	fmt.Println("5. Add Termux:Widget to your home screen")
	fmt.Println("6. Tap the widget to see your auth scripts")
	fmt.Println("")
	fmt.Println("The quick widget (ClawdAuth) shows status and opens auth URL if needed.")
	fmt.Println("The full widget (ClawdAuth-Full) provides guided re-auth flow.")
	fmt.Println("")
	
	// Summary
	fmt.Println("=== Setup Complete ===")
	fmt.Println("")
	fmt.Println("What's configured:")
	fmt.Printf("  - Auth status: %s/claude-auth-status.sh\n", scriptDir)
	fmt.Printf("  - Mobile re-auth: %s/mobile-reauth.sh\n", scriptDir)
	fmt.Println("  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer")
	fmt.Println("")
	fmt.Println("Quick commands:")
	fmt.Printf("  Check auth:  %s/claude-auth-status.sh\n", scriptDir)
	fmt.Printf("  Re-auth:     %s/mobile-reauth.sh\n", scriptDir)
	fmt.Printf("  Test monitor: %s/auth-monitor.sh\n", scriptDir)
	fmt.Println("")
}

func copyFile(src, dst string) {
	input, err := os.ReadFile(src)
	if err != nil {
		panic(err)
	}
	
	err = os.WriteFile(dst, input, 0644)
	if err != nil {
		panic(err)
	}
}
