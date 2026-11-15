// abstraction-provenance: {"artifact_sha256": "1ba19357dfaca56d9756881b9ee20fa5e986b00e4126c9d22b7b7b7a65a693b6", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "go"}
// node_health.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Node Health Monitor - Multi-Node Gesundheitsüberwachung
*/

package main

import (
	"bufio"
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
	WORKSPACE = "/home/openclaw/.openclaw/workspace"
	HEALTH_DB = filepath.Join(WORKSPACE, "db/health.db")
	LOG_FILE  = filepath.Join(WORKSPACE, "logs/node-health.log")
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
	Timestamp      string  `json:"timestamp"`
	Available      bool    `json:"available"`
	CPU            *float64 `json:"cpu,omitempty"`
	RAM            *float64 `json:"ram,omitempty"`
	Disk           *int     `json:"disk,omitempty"`
	Load           *float64 `json:"load,omitempty"`
	GatewayStatus  string   `json:"gateway_status,omitempty"`
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

func logMessage(message, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)
	
	// Stelle sicher, dass das Log-Verzeichnis existiert
	logDir := filepath.Dir(LOG_FILE)
	os.MkdirAll(logDir, 0755)
	
	file, err := os.OpenFile(LOG_FILE, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer file.Close()
	
	file.WriteString(entry + "\n")
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
	
	args := []string{"-o", "ConnectTimeout=10", "-o", "BatchMode=yes"}
	if nodeConfig.SSHKey != "" {
		args = append(args, "-i", nodeConfig.SSHKey)
	}
	args = append(args, fmt.Sprintf("%s@%s", user, host), "echo \"OK\"")
	
	cmd := exec.Command("ssh", args...)
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
        echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%%" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%%")"
        
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
		logMessage(fmt.Sprintf("Error executing SSH command: %v", err), "ERROR")
		return metrics
	}
	
	metrics.Available = true
	
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
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
		if diskThreshold == 0 {
			diskThreshold = 85
		}
		
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
	
	scriptPath := filepath.Join(WORKSPACE, "skills/channel-status-agent/scripts/channel_status.py")
	cmd := exec.Command("python3", scriptPath, "--type", "alert", "--message", fmt.Sprintf("%s: %s", alert.Level, alert.Message))
	
	err := cmd.Run()
	if err != nil {
		panic(err)
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
		case "-h", "--help":
			fmt.Println("Node Health Monitor")
			fmt.Println("Usage: node_health.go [--node NODE] [--check CHECK] [--alert]")
			fmt.Println("  --node NODE     Node ID oder \"all\"")
			fmt.Println("  --check CHECK   ping, ssh, metrics, or all")
			fmt.Println("  --alert         Sende Alerts")
			os.Exit(0)
		}
	}
	
	// Nodes bestimmen
	nodesToCheck := make(map[string]NodeConfig)
	if node == "all" {
		nodesToCheck = NODES
	} else {
		if config, exists := NODES[node]; exists {
			nodesToCheck[node] = config
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
				pingOk := checkPing(nodeConfig.Host, 5)
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
	if alert && len(allAlerts) > 0 {
		logMessage(fmt.Sprintf("\nSending %d alerts...", len(allAlerts)), "INFO")
		for _, alertItem := range allAlerts {
			sendAlert(alertItem)
		}
	} else if len(allAlerts) > 0 {
		logMessage(fmt.Sprintf("\n%d alerts found (use --alert to send)", len(allAlerts)), "INFO")
	} else {
		logMessage("\nAll nodes healthy!", "INFO")
	}
}
