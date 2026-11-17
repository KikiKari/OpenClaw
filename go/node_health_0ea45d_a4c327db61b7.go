// abstraction-provenance: {"artifact_sha256": "4ec3f348a9d362ed8218c51c8093df6539037c8244d3b22eff1fec54b2a9f27d", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "go"}
// node_health.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/*
Node Health Monitor - Multi-Node Gesundheitsüberwachung
*/

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Konfiguration
var (
	WORKSPACE = filepath.Join(os.Getenv("HOME"), ".openclaw", "workspace")
	HEALTH_DB = filepath.Join(WORKSPACE, "db", "health.db")
	LOG_FILE  = filepath.Join(WORKSPACE, "logs", "node-health.log")
)

// NodeConfig repräsentiert die Konfiguration eines Knotens
type NodeConfig struct {
	Name         string `json:"name"`
	Host         string `json:"host"`
	User         string `json:"user"`
	SSHOpts      string `json:"ssh_opts,omitempty"`
	Port         int    `json:"port,omitempty"`
	DiskWarning  int    `json:"disk_warning,omitempty"`
	Critical     bool   `json:"critical,omitempty"`
	Optional     bool   `json:"optional,omitempty"`
}

// Metrics enthält die Systemmetriken eines Knotens
type Metrics struct {
	Timestamp     string  `json:"timestamp"`
	Available     bool    `json:"available"`
	CPU           float64 `json:"cpu,omitempty"`
	RAM           float64 `json:"ram,omitempty"`
	Disk          int     `json:"disk,omitempty"`
	Load          float64 `json:"load,omitempty"`
	GatewayStatus string  `json:"gateway_status,omitempty"`
}

// Alert repräsentiert eine Warnmeldung
type Alert struct {
	Level   string `json:"level"`
	Message string `json:"message"`
}

// Node-Definitionen
var NODES = map[string]NodeConfig{
	"node1": {
		Name:     "Node 1",
		Host:     "localhost",
		User:     "openclaw",
		Critical: true,
	},
	"node2": {
		Name:    "Node 2",
		Host:    "10.10.0.2",
		User:    "root",
		SSHOpts: "-o ConnectTimeout=10 -o BatchMode=yes",
	},
	"node3": {
		Name:        "Node 3",
		Host:        "localhost",
		User:        "root",
		Port:        18794,
		SSHOpts:     "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes",
		DiskWarning: 85,
	},
	"node5": {
		Name:     "Redmi",
		Host:     "192.168.1.x",
		User:     "openclaw",
		Optional: true,
	},
}

func init() {
	// Setze Default-Werte
	for id, node := range NODES {
		if node.DiskWarning == 0 {
			NODES[id] = NodeConfig{
				Name:         node.Name,
				Host:         node.Host,
				User:         node.User,
				SSHOpts:      node.SSHOpts,
				Port:         node.Port,
				DiskWarning:  85,
				Critical:     node.Critical,
				Optional:     node.Optional,
			}
		}
	}
}

func logMessage(message, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)

	// Stelle sicher, dass das Log-Verzeichnis existiert
	logDir := filepath.Dir(LOG_FILE)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		log.Printf("Fehler beim Erstellen des Log-Verzeichnisses: %v", err)
		return
	}

	// Öffne die Log-Datei im Anhang-Modus
	file, err := os.OpenFile(LOG_FILE, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Printf("Fehler beim Öffnen der Log-Datei: %v", err)
		return
	}
	defer file.Close()

	if _, err := file.WriteString(entry + "\n"); err != nil {
		log.Printf("Fehler beim Schreiben in die Log-Datei: %v", err)
	}
}

func checkPing(host string, timeout int) bool {
	cmd := exec.Command("ping", "-c", "1", "-W", strconv.Itoa(timeout), host)
	err := cmd.Run()
	return err == nil
}

func checkSSH(nodeConfig NodeConfig) bool {
	host := nodeConfig.Host
	user := nodeConfig.User
	if user == "" {
		user = "root"
	}

	args := []string{"ssh"}
	if nodeConfig.SSHOpts != "" {
		opts := strings.Split(nodeConfig.SSHOpts, " ")
		args = append(args, opts...)
	}
	if nodeConfig.Port != 0 {
		args = append(args, "-p", strconv.Itoa(nodeConfig.Port))
	}
	args = append(args, "-o", "ConnectTimeout=10", "-o", "BatchMode=yes",
		fmt.Sprintf("%s@%s", user, host), "echo", "\"OK\"")

	cmd := exec.Command(args[0], args[1:]...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return false
	}
	return strings.Contains(string(output), "OK")
}

func getNodeMetrics(nodeConfig NodeConfig) Metrics {
	host := nodeConfig.Host
	user := nodeConfig.User
	if user == "" {
		user = "root"
	}

	metrics := Metrics{
		Timestamp: time.Now().Format(time.RFC3339),
		Available: false,
	}

	// SSH-Command für alle Metriken
	cmdStr := fmt.Sprintf(`ssh -o ConnectTimeout=10 %s@%s '
        # CPU
        echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%")"
        
        # Load
        echo "LOAD:$(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
        fi
    '`, user, host)

	cmd := exec.Command("sh", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		logMessage(fmt.Sprintf("Error checking %s: %v", nodeConfig.Name, err), "ERROR")
		return metrics
	}

	metrics.Available = true

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		if strings.Contains(line, ":") {
			parts := strings.SplitN(line, ":", 2)
			key := parts[0]
			value := parts[1]

			switch key {
			case "CPU":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.CPU = val
				}
			case "RAM":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.RAM = val
				}
			case "DISK":
				if val, err := strconv.Atoi(value); err == nil {
					metrics.Disk = val
				}
			case "LOAD":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.Load = val
				}
			case "GATEWAY":
				metrics.GatewayStatus = value
			}
		}
	}

	return metrics
}

func checkAlerts(nodeID string, nodeConfig NodeConfig, metrics Metrics) []Alert {
	var alerts []Alert

	// Verfügbarkeit
	if !metrics.Available {
		if !nodeConfig.Optional {
			alerts = append(alerts, Alert{
				Level:   "CRITICAL",
				Message: fmt.Sprintf("Node %s nicht erreichbar!", nodeConfig.Name),
			})
		}
	} else {
		// CPU
		if metrics.CPU > 90 {
			alerts = append(alerts, Alert{
				Level:   "WARNING",
				Message: fmt.Sprintf("Node %s: CPU bei %.1f%%", nodeConfig.Name, metrics.CPU),
			})
		}

		// RAM
		if metrics.RAM > 90 {
			alerts = append(alerts, Alert{
				Level:   "WARNING",
				Message: fmt.Sprintf("Node %s: RAM bei %.1f%%", nodeConfig.Name, metrics.RAM),
			})
		}

		// Disk
		diskThreshold := nodeConfig.DiskWarning
		if diskThreshold == 0 {
			diskThreshold = 85
		}
		if metrics.Disk > diskThreshold {
			level := "WARNING"
			if metrics.Disk > 95 {
				level = "CRITICAL"
			}
			alerts = append(alerts, Alert{
				Level:   level,
				Message: fmt.Sprintf("Node %s: Disk bei %d%%", nodeConfig.Name, metrics.Disk),
			})
		}

		// Gateway
		if nodeConfig.Critical && metrics.GatewayStatus == "inactive" {
			alerts = append(alerts, Alert{
				Level:   "CRITICAL",
				Message: fmt.Sprintf("Node %s: OpenClaw Gateway nicht aktiv!", nodeConfig.Name),
			})
		}
	}

	return alerts
}

func sendAlert(alert Alert) {
	defer func() {
		if r := recover(); r != nil {
			logMessage(fmt.Sprintf("Failed to send alert: %v", r), "ERROR")
		}
	}()

	scriptPath := filepath.Join(WORKSPACE, "skills", "channel-status-agent", "scripts", "channel_status.py")
	cmd := exec.Command("python3", scriptPath, "--type", "alert", "--message", fmt.Sprintf("%s: %s", alert.Level, alert.Message))
	err := cmd.Run()
	if err != nil {
		logMessage(fmt.Sprintf("Failed to send alert: %v", err), "ERROR")
		return
	}
	logMessage(fmt.Sprintf("Alert sent: %s", alert.Message), "INFO")
}

func main() {
	// Argumente parsen
	node := "all"
	check := "all"
	alert := false

	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--node":
			if i+1 < len(os.Args) {
				node = os.Args[i+1]
				i++
			}
		case "--check":
			if i+1 < len(os.Args) {
				check = os.Args[i+1]
				i++
			}
		case "--alert":
			alert = true
		}
	}

	// Nodes bestimmen
	var nodesToCheck map[string]NodeConfig
	if node == "all" {
		nodesToCheck = NODES
	} else {
		if config, exists := NODES[node]; exists {
			nodesToCheck = map[string]NodeConfig{node: config}
		} else {
			logMessage(fmt.Sprintf("Unknown node: %s", node), "ERROR")
			os.Exit(1)
		}
	}

	// Health-Checks durchführen
	var allAlerts []Alert

	for nodeID, nodeConfig := range nodesToCheck {
		logMessage(fmt.Sprintf("Checking %s (%s)", nodeConfig.Name, nodeID), "INFO")

		// Ping
		if check == "ping" || check == "all" {
			if nodeConfig.Host != "localhost" {
				pingOk := checkPing(nodeConfig.Host, 10)
				status := "FAILED"
				if pingOk {
					status = "OK"
				}
				logMessage(fmt.Sprintf("  Ping: %s", status), "INFO")
			}
		}

		// SSH
		if check == "ssh" || check == "all" {
			sshOk := checkSSH(nodeConfig)
			status := "FAILED"
			if sshOk {
				status = "OK"
			}
			logMessage(fmt.Sprintf("  SSH: %s", status), "INFO")
		}

		// Metriken
		if check == "metrics" || check == "all" {
			metrics := getNodeMetrics(nodeConfig)

			if metrics.Available {
				if metrics.CPU != 0 {
					logMessage(fmt.Sprintf("  CPU: %.1f%%", metrics.CPU), "INFO")
				} else {
					logMessage("  CPU: N/A", "INFO")
				}
				if metrics.RAM != 0 {
					logMessage(fmt.Sprintf("  RAM: %.1f%%", metrics.RAM), "INFO")
				} else {
					logMessage("  RAM: N/A", "INFO")
				}
				if metrics.Disk != 0 {
					logMessage(fmt.Sprintf("  Disk: %d%%", metrics.Disk), "INFO")
				} else {
					logMessage("  Disk: N/A", "INFO")
				}
				if metrics.Load != 0 {
					logMessage(fmt.Sprintf("  Load: %.2f", metrics.Load), "INFO")
				} else {
					logMessage("  Load: N/A", "INFO")
				}
			} else {
				logMessage("  Metrics: UNAVAILABLE", "INFO")
			}

			// Alerts prüfen
			alerts := checkAlerts(nodeID, nodeConfig, metrics)
			allAlerts = append(allAlerts, alerts...)
		}
	}

	// Alerts senden
	if alert && len(allAlerts) > 0 {
		logMessage(fmt.Sprintf("\nSending %d alerts...", len(allAlerts)), "INFO")
		for _, alert := range allAlerts {
			sendAlert(alert)
		}
	} else if len(allAlerts) > 0 {
		logMessage(fmt.Sprintf("\n%d alerts found (use --alert to send)", len(allAlerts)), "INFO")
	} else {
		logMessage("\nAll nodes healthy!", "INFO")
	}
}
