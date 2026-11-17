// abstraction-provenance: {"artifact_sha256": "1069c4efabbae3ae483c26cf0998c0a80e523ae0878656550c7db03d628b7944", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "go"}
// node_health.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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

// Node-Konfiguration
type NodeConfig struct {
	Name         string `json:"name"`
	Host         string `json:"host"`
	User         string `json:"user"`
	Critical     bool   `json:"critical,omitempty"`
	SSHKey       string `json:"ssh_key,omitempty"`
	DiskWarning  int    `json:"disk_warning,omitempty"`
	Optional     bool   `json:"optional,omitempty"`
}

// Metrik-Struktur
type Metrics struct {
	Timestamp     string  `json:"timestamp"`
	Available     bool    `json:"available"`
	CPU           *float64 `json:"cpu,omitempty"`
	RAM           *float64 `json:"ram,omitempty"`
	Disk          *int    `json:"disk,omitempty"`
	Load          *float64 `json:"load,omitempty"`
	GatewayStatus string  `json:"gateway_status,omitempty"`
}

// Alert-Struktur
type Alert struct {
	Level   string `json:"level"`
	Message string `json:"message"`
}

var NODES = map[string]NodeConfig{
	"node1": {
		Name:     "Gateway",
		Host:     "localhost",
		User:     "openclaw",
		Critical: true,
	},
	"node2": {
		Name:    "Worker",
		Host:    "100.92.155.34",
		User:    "root",
		SSHKey:  "~/.ssh/id_rsa",
	},
	"node3": {
		Name:        "Relay",
		Host:        "185.242.xxx.xxx",
		User:        "root",
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
		if node.User == "" {
			node.User = "root"
		}
		if node.DiskWarning == 0 {
			node.DiskWarning = 85
		}
		NODES[id] = node
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

	// Schreibe in Log-Datei
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("Fehler beim Öffnen der Log-Datei: %v", err)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(entry + "\n"); err != nil {
		log.Printf("Fehler beim Schreiben in Log-Datei: %v", err)
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

	args := []string{
		"-o", "ConnectTimeout=10",
		"-o", "BatchMode=yes",
		fmt.Sprintf("%s@%s", user, host),
		"echo \"OK\"",
	}

	cmd := exec.Command("ssh", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return false
	}

	return strings.Contains(string(output), "OK")
}

func getNodeMetrics(nodeConfig NodeConfig) Metrics {
	metrics := Metrics{
		Timestamp: time.Now().Format(time.RFC3339),
		Available: false,
	}

	host := nodeConfig.Host
	user := nodeConfig.User

	// SSH-Command für alle Metriken
	script := `
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
    `

	cmd := exec.Command("sh", "-c", fmt.Sprintf("ssh -o ConnectTimeout=10 %s@%s '%s'", user, host, script))
	
	// Setze Timeout
	done := make(chan bool)
	go func() {
		<-time.After(15 * time.Second)
		done <- true
	}()

	result := make(chan struct {
		output []byte
		err    error
	})

	go func() {
		output, err := cmd.Output()
		result <- struct {
			output []byte
			err    error
		}{output, err}
	}()

	select {
	case res := <-result:
		if res.err != nil {
			logMessage(fmt.Sprintf("Error checking %s: %v", nodeConfig.Name, res.err), "ERROR")
			return metrics
		}

		metrics.Available = true
		
		lines := strings.Split(strings.TrimSpace(string(res.output)), "\n")
		for _, line := range lines {
			if !strings.Contains(line, ":") {
				continue
			}
			
			parts := strings.SplitN(line, ":", 2)
			key := parts[0]
			value := parts[1]

			switch key {
			case "CPU":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.CPU = &val
				}
			case "RAM":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.RAM = &val
				}
			case "DISK":
				if val, err := strconv.Atoi(value); err == nil {
					metrics.Disk = &val
				}
			case "LOAD":
				if val, err := strconv.ParseFloat(value, 64); err == nil {
					metrics.Load = &val
				}
			case "GATEWAY":
				metrics.GatewayStatus = value
			}
		}
		
	case <-done:
		logMessage(fmt.Sprintf("SSH timeout for %s", nodeConfig.Name), "WARN")
		return metrics
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
		if metrics.CPU != nil && *metrics.CPU > 90 {
			alerts = append(alerts, Alert{
				Level:   "WARNING",
				Message: fmt.Sprintf("Node %s: CPU bei %.1f%%", nodeConfig.Name, *metrics.CPU),
			})
		}

		// RAM
		if metrics.RAM != nil && *metrics.RAM > 90 {
			alerts = append(alerts, Alert{
				Level:   "WARNING",
				Message: fmt.Sprintf("Node %s: RAM bei %.1f%%", nodeConfig.Name, *metrics.RAM),
			})
		}

		// Disk
		diskThreshold := nodeConfig.DiskWarning
		if metrics.Disk != nil && *metrics.Disk > diskThreshold {
			level := "WARNING"
			if *metrics.Disk > 95 {
				level = "CRITICAL"
			}
			alerts = append(alerts, Alert{
				Level:   level,
				Message: fmt.Sprintf("Node %s: Disk bei %d%%", nodeConfig.Name, *metrics.Disk),
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
	var nodeFlag, checkFlag string
	var alertFlag bool
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--node":
			if i+1 < len(os.Args) {
				nodeFlag = os.Args[i+1]
				i++
			}
		case "--check":
			if i+1 < len(os.Args) {
				checkFlag = os.Args[i+1]
				i++
			}
		case "--alert":
			alertFlag = true
		case "-h", "--help":
			fmt.Println("Node Health Monitor - Multi-Node Gesundheitsüberwachung")
			fmt.Println("Usage: go run node_health.go [--node NODE] [--check CHECK] [--alert]")
			fmt.Println("  --node NODE    Node ID oder \"all\"")
			fmt.Println("  --check CHECK  ping, ssh, metrics, or all")
			fmt.Println("  --alert        Sende Alerts")
			os.Exit(0)
		}
	}
	
	if nodeFlag == "" {
		nodeFlag = "all"
	}
	if checkFlag == "" {
		checkFlag = "all"
	}

	// Nodes bestimmen
	var nodesToCheck map[string]NodeConfig
	if nodeFlag == "all" {
		nodesToCheck = NODES
	} else {
		if config, exists := NODES[nodeFlag]; exists {
			nodesToCheck = map[string]NodeConfig{nodeFlag: config}
		} else {
			logMessage(fmt.Sprintf("Unknown node: %s", nodeFlag), "ERROR")
			os.Exit(1)
		}
	}

	// Health-Checks durchführen
	var allAlerts []Alert

	for nodeID, nodeConfig := range nodesToCheck {
		logMessage(fmt.Sprintf("Checking %s (%s)", nodeConfig.Name, nodeID), "INFO")

		// Ping
		if checkFlag == "ping" || checkFlag == "all" {
			if nodeConfig.Host != "localhost" {
				pingOk := checkPing(nodeConfig.Host, 5)
				status := "FAILED"
				if pingOk {
					status = "OK"
				}
				logMessage(fmt.Sprintf("  Ping: %s", status), "INFO")
			}
		}

		// SSH
		if checkFlag == "ssh" || checkFlag == "all" {
			sshOk := checkSSH(nodeConfig)
			status := "FAILED"
			if sshOk {
				status = "OK"
			}
			logMessage(fmt.Sprintf("  SSH: %s", status), "INFO")
		}

		// Metriken
		if checkFlag == "metrics" || checkFlag == "all" {
			metrics := getNodeMetrics(nodeConfig)

			if metrics.Available {
				if metrics.CPU != nil {
					logMessage(fmt.Sprintf("  CPU: %.1f%%", *metrics.CPU), "INFO")
				} else {
					logMessage("  CPU: N/A", "INFO")
				}
				
				if metrics.RAM != nil {
					logMessage(fmt.Sprintf("  RAM: %.1f%%", *metrics.RAM), "INFO")
				} else {
					logMessage("  RAM: N/A", "INFO")
				}
				
				if metrics.Disk != nil {
					logMessage(fmt.Sprintf("  Disk: %d%%", *metrics.Disk), "INFO")
				} else {
					logMessage("  Disk: N/A", "INFO")
				}
				
				if metrics.Load != nil {
					logMessage(fmt.Sprintf("  Load: %.2f", *metrics.Load), "INFO")
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
	if alertFlag && len(allAlerts) > 0 {
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
