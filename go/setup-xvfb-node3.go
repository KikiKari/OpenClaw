// abstraction-provenance: {"artifact_sha256": "42343c07d588a6b2a7dc809b917b37a5aee7c1bc70f0f908a92d710f67182581", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "go"}
// setup-xvfb-node3.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

// Xvfb Setup für Node 3 (xNetX VPS)
// Erstellt: 2026-04-09
// Hinweis: Altes VNC-Setup wird entfernt

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	fmt.Println("=== Xvfb + Chromium Setup für Node 3 ===")
	fmt.Println("=== Entferne altes VNC-Setup ===")

	// Altes VNC stoppen & entfernen (falls vorhanden)
	runCommandIgnoreError("sudo", "systemctl", "stop", "vncserver@*")
	runCommandIgnoreError("sudo", "systemctl", "disable", "vncserver@*")
	runCommandIgnoreError("sudo", "apt-get", "remove", "-y", "tightvncserver", "tigervnc-standalone-server")
	runCommandIgnoreError("sudo", "rm", "-rf", "~/.vnc", "/tmp/.X11-unix/X*")

	fmt.Println("=== Installiere Xvfb + Chromium ===")

	// Update & Install
	runCommand("sudo", "apt-get", "update")
	runCommand("sudo", "apt-get", "install", "-y",
		"xvfb",
		"chromium",
		"chromium-driver",
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

	// Xvfb Systemd Service erstellen
	xvfbService := `[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`
	err := os.WriteFile("/etc/systemd/system/xvfb.service", []byte(xvfbService), 0644)
	if err != nil {
		fmt.Printf("Fehler beim Schreiben der Service-Datei: %v\n", err)
		os.Exit(1)
	}

	// Service aktivieren
	runCommand("sudo", "systemctl", "daemon-reload")
	runCommand("sudo", "systemctl", "enable", "xvfb")
	runCommand("sudo", "systemctl", "start", "xvfb")

	fmt.Println("=== Xvfb läuft auf DISPLAY :99 ===")
	fmt.Println("Chromium Version:")

	cmd := exec.Command("chromium", "--version")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Chromium nicht gefunden")
	} else {
		fmt.Print(string(output))
	}

	fmt.Println("=== Setup abgeschlossen ===")
	fmt.Println("=== Altes VNC-Setup wurde entfernt ===")
}

func runCommand(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		fmt.Printf("Fehler beim Ausführen von %s: %v\n", name, err)
		os.Exit(1)
	}
}

func runCommandIgnoreError(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		// Fehler ignorieren
	}
}
