// abstraction-provenance: {"artifact_sha256": "85cdb5b54a62c398fae6dd89c06163bdcd9cdb75cb6dfda6b895203b07859a52", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "go"}
// fix_gateway_node_path.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
// auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py


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
	
	cpCmd := exec.Command("cp", "/etc/systemd/system/openclaw-gateway.service", backupFile)
	if err := cpCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen des Backups: %v\n", err)
		os.Exit(1)
	}
	
	// Korrektur des Node.js Pfads in der Service-Datei
	// Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
	sedCmd := exec.Command("sed", "-i", 
		"s|/home/openclaw/.nvm/versions/node/v22.22.2/bin/node|/usr/bin/node|g", 
		"/etc/systemd/system/openclaw-gateway.service")
	if err := sedCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Aktualisieren des Node-Pfads: %v\n", err)
		os.Exit(1)
	}
	
	// Service neu laden
	daemonReloadCmd := exec.Command("systemctl", "daemon-reload")
	if err := daemonReloadCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Neuladen des Daemons: %v\n", err)
		os.Exit(1)
	}
	
	// Service neu starten
	restartCmd := exec.Command("systemctl", "restart", "openclaw-gateway")
	if err := restartCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Neustarten des Services: %v\n", err)
		os.Exit(1)
	}
	
	// Status prüfen
	statusCmd := exec.Command("systemctl", "status", "openclaw-gateway", "--no-pager")
	output, err := statusCmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Abfragen des Status: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Print(string(output))
}
