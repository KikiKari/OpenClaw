// abstraction-provenance: {"artifact_sha256": "94dad6d1365e400bf7a160ec62bda9a466d4f11bed6fea84e9a35672246eef2c", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "go"}
// fix_gateway_node_path.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
// auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
	"strings"
)

func main() {
	// Backup der originalen Service-Datei
	backupFile := fmt.Sprintf("/etc/systemd/system/openclaw-gateway.service.backup-%s", 
		time.Now().Format("20060102_150405"))
	
	// Kopiere die Datei
	input, err := os.ReadFile("/etc/systemd/system/openclaw-gateway.service")
	if err != nil {
		fmt.Printf("Fehler beim Lesen der Service-Datei: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile(backupFile, input, 0644)
	if err != nil {
		fmt.Printf("Fehler beim Erstellen des Backups: %v\n", err)
		os.Exit(1)
	}

	// Korrektur des Node.js Pfads in der Service-Datei
	// Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
	serviceContent, err := os.ReadFile("/etc/systemd/system/openclaw-gateway.service")
	if err != nil {
		fmt.Printf("Fehler beim Lesen der Service-Datei: %v\n", err)
		os.Exit(1)
	}

	// Ersetze den alten Pfad mit dem neuen
	newContent := strings.ReplaceAll(string(serviceContent), 
		"/home/openclaw/.nvm/versions/node/v22.22.2/bin/node", 
		"/usr/bin/node")

	err = os.WriteFile("/etc/systemd/system/openclaw-gateway.service", []byte(newContent), 0644)
	if err != nil {
		fmt.Printf("Fehler beim Schreiben der korrigierten Service-Datei: %v\n", err)
		os.Exit(1)
	}

	// Service neu laden und neu starten
	cmd := exec.Command("systemctl", "daemon-reload")
	err = cmd.Run()
	if err != nil {
		fmt.Printf("Fehler beim Neuladen des Daemons: %v\n", err)
		os.Exit(1)
	}

	cmd = exec.Command("systemctl", "restart", "openclaw-gateway")
	err = cmd.Run()
	if err != nil {
		fmt.Printf("Fehler beim Neustarten des Services: %v\n", err)
		os.Exit(1)
	}

	// Status prüfen
	cmd = exec.Command("systemctl", "status", "openclaw-gateway", "--no-pager")
	output, err := cmd.Output()
	if err != nil {
		fmt.Printf("Fehler beim Abfragen des Status: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Print(string(output))
}
