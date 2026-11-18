// abstraction-provenance: {"artifact_sha256": "2fd130a820ea735cb89424c64866b7705e9f05adf94a09e478fd25fcdef2abab", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "go"}
// openclaw-node-autostart-termux.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

const (
	session    = "openclaw-node"
	gateway    = "10.10.0.1"
	port       = "18789"
	logDir     = ".openclaw"
	logFile    = "node.log"
	retryDelay = 10 * time.Second
	restartDelay = 5 * time.Second
	pingTimeout = 3 * time.Second
)

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatalf("Konnte Home-Verzeichnis nicht finden: %v", err)
	}

	logPath := filepath.Join(home, logDir, logFile)
	
	// Log-Verzeichnis erstellen
	if err := os.MkdirAll(filepath.Join(home, logDir), 0755); err != nil {
		log.Fatalf("Konnte Log-Verzeichnis nicht erstellen: %v", err)
	}

	// Prüfen ob tmux Session bereits läuft
	if checkTmuxSession(session) {
		logMessage(logPath, "OpenClaw Node läuft bereits in tmux Session '%s'", session)
		return
	}

	// Neue tmux Session erstellen
	if err := createTmuxSession(session, logPath); err != nil {
		log.Fatalf("Konnte tmux Session nicht erstellen: %v", err)
	}

	logMessage(logPath, "OpenClaw Node Autostart aktiviert (tmux Session: %s)", session)

	// Optional: Hinweis falls interaktiv gestartet
	if isTerminal() {
		fmt.Printf("OpenClaw Node Mode gestartet in tmux Session '%s'\n", session)
		fmt.Printf("Zum Anschauen: tmux attach -t %s\n", session)
		fmt.Printf("Log-Datei: %s\n", logPath)
	}
}

func checkTmuxSession(session string) bool {
	cmd := exec.Command("tmux", "has-session", "-t", session)
	return cmd.Run() == nil
}

func createTmuxSession(session, logPath string) error {
	script := fmt.Sprintf(`while true; do
	echo '[%s] Starting OpenClaw Node Mode...' | tee -a '%s'
	
	# Prüfe WireGuard Verbindung
	if ! ping -c 1 -W 3 %s >/dev/null 2>&1; then
		echo '[%s] FEHLER: WireGuard Gateway %s nicht erreichbar!' | tee -a '%s'
		echo '[%s] Warte 10 Sekunden...' | tee -a '%s'
		sleep 10
		continue
	fi
	
	# OpenClaw Node Mode starten
	openclaw node run --host %s --port %s 2>&1 | tee -a '%s'
	
	# Wenn der Prozess endet, warte und neustarten
	echo '[%s] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '%s'
	sleep 5
done`, "$(date)", logPath, gateway, "$(date)", gateway, logPath, "$(date)", logPath, gateway, port, logPath, "$(date)", logPath)

	cmd := exec.Command("tmux", "new-session", "-d", "-s", session, "-n", "node", "bash", "-c", script)
	return cmd.Run()
}

func logMessage(logPath, format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	logEntry := fmt.Sprintf("[%s] %s\n", timestamp, message)

	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("Konnte Log-Datei nicht öffnen: %v", err)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(logEntry); err != nil {
		log.Printf("Konnte nicht in Log-Datei schreiben: %v", err)
	}
}

func isTerminal() bool {
	fileInfo, _ := os.Stdout.Stat()
	return (fileInfo.Mode() & os.ModeCharDevice) != 0
}
