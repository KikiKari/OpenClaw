// abstraction-provenance: {"artifact_sha256": "a5f3462509a091aad8aabd7310d1d965c54fd064a59acd6b9e0e039e255a55f0", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "go"}
// setup-xvfb-node2.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
)

func main() {
	fmt.Println("=== Xvfb + Chromium Setup für Node 2 ===")

	// Update & Install
	updateCmd := exec.Command("sudo", "apt-get", "update")
	if err := runCommand(updateCmd); err != nil {
		log.Fatalf("Fehler beim Update: %v", err)
	}

	installCmd := exec.Command("sudo", "apt-get", "install", "-y",
		"xvfb",
		"chromium-browser",
		"chromium-chromedriver",
		"fonts-liberation",
		"libappindicator3-1",
		"libasound2",
		"libatk-bridge2.0-0",
		"libatk1.0-0",
		"libcups2",
		"libgtk-3-0",
		"libnspr4",
		"libnss3",
		"libxss1",
		"xdg-utils")
	if err := runCommand(installCmd); err != nil {
		log.Fatalf("Fehler bei der Installation: %v", err)
	}

	// Xvfb Systemd Service erstellen
	xvfbService := `[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`

	if err := os.WriteFile("/etc/systemd/system/xvfb.service", []byte(xvfbService), 0644); err != nil {
		log.Fatalf("Fehler beim Erstellen der Service-Datei: %v", err)
	}

	// Service aktivieren
	daemonReloadCmd := exec.Command("sudo", "systemctl", "daemon-reload")
	if err := runCommand(daemonReloadCmd); err != nil {
		log.Fatalf("Fehler beim Neuladen des Daemons: %v", err)
	}

	enableCmd := exec.Command("sudo", "systemctl", "enable", "xvfb")
	if err := runCommand(enableCmd); err != nil {
		log.Fatalf("Fehler beim Aktivieren des Services: %v", err)
	}

	startCmd := exec.Command("sudo", "systemctl", "start", "xvfb")
	if err := runCommand(startCmd); err != nil {
		log.Fatalf("Fehler beim Starten des Services: %v", err)
	}

	fmt.Println("=== Xvfb läuft auf DISPLAY :99 ===")
	
	// Chromium Version anzeigen
	fmt.Println("Chromium Version:")
	versionCmd := exec.Command("chromium-browser", "--version")
	if err := runCommand(versionCmd); err != nil {
		fmt.Println("Chromium nicht gefunden")
	}

	fmt.Println("=== Setup abgeschlossen ===")
}

func runCommand(cmd *exec.Cmd) error {
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
