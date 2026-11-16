// abstraction-provenance: {"artifact_sha256": "726b1003759744041b9e11f110a26ef7f99455f98b53da2db6b57a6d0b6f9470", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "go"}
// channel_status.py — portiert nach go
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py


/*
Channel Status Agent - Automatische Status-Updates
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
	"runtime"
	"strconv"
	"strings"
	"time"
)

// Konfiguration
var (
	WORKSPACE  = "/home/openclaw/.openclaw/workspace"
	LOGS_DB    = filepath.Join(WORKSPACE, "db", "logs.db")
	CONFIG_FILE = filepath.Join(WORKSPACE, "config", "channel-status.json")
	LOG_FILE   = filepath.Join(WORKSPACE, "logs", "channel-status.log")
)

func init() {
	// Create logs directory if it doesn't exist
	logDir := filepath.Dir(LOG_FILE)
	if _, err := os.Stat(logDir); os.IsNotExist(err) {
		os.MkdirAll(logDir, 0755)
	}
}

func logMessage(message string, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)
	
	file, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer file.Close()
	
	file.WriteString(entry + "\n")
}

var NODE_NAMES = map[string]map[string]bool{
	"node2": {"openclaw-node2": true, "arm64-node": true, "v2202604104722449961": true, "v2202604104722449961.taild25fea.ts.net": true, "100.82.198.122": true},
	"node3": {"openclaw-node3": true, "openclaw-node3.taild25fea.ts.net": true, "100.73.154.125": true},
	"node4": {"openclaw-node4": true, "redmi-note-11s": true, "redmi-note-11s.taild25fea.ts.net": true, "100.94.134.39": true},
	"node5": {"openclaw-node5": true, "lenovo-node7": true, "lenovo-node7.taild25fea.ts.net": true, "100.103.140.35": true},
}

type NodeStatus struct {
	DisplayName string `json:"displayName"`
	NodeId      string `json:"nodeId"`
	RemoteIp    string `json:"remoteIp"`
	Connected   bool   `json:"connected"`
}

type NodesResponse struct {
	Nodes []NodeStatus `json:"nodes"`
}

func fetchNodeStatus() map[string]bool {
	cmd := exec.Command("openclaw", "nodes", "status", "--json")
	output, err := cmd.Output()
	if err != nil {
		return nil
	}
	
	var response NodesResponse
	if err := json.Unmarshal(output, &response); err != nil {
		return nil
	}
	
	states := make(map[string]bool)
	for node := range NODE_NAMES {
		states[node] = false
	}
	
	for _, item := range response.Nodes {
		names := map[string]bool{
			strings.ToLower(item.DisplayName): true,
			strings.ToLower(item.NodeId):       true,
			strings.ToLower(item.RemoteIp):     true,
		}
		
		for node, aliases := range NODE_NAMES {
			for name := range names {
				if aliases[name] {
					if item.Connected {
						states[node] = true
					}
					break
				}
			}
		}
	}
	
	states["node1"] = true // successful Gateway status request
	return states
}

type Status struct {
	Timestamp string                 `json:"timestamp"`
	Nodes     map[string]NodeInfo    `json:"nodes"`
	Agents    map[string]interface{} `json:"agents"`
	System    map[string]string      `json:"system"`
}

type NodeInfo struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Reason string `json:"reason,omitempty"`
}

func getSystemStatus() Status {
	status := Status{
		Timestamp: time.Now().Format(time.RFC3339),
		Nodes:     make(map[string]NodeInfo),
		Agents:    make(map[string]interface{}),
		System:    make(map[string]string),
	}
	
	// Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
	states := fetchNodeStatus()
	names := map[string]string{
		"node1": "Gateway",
		"node2": "Node2",
		"node3": "Node3",
		"node4": "Redmi",
		"node5": "Lenovo",
	}
	
	for node, name := range names {
		nodeStatus := "unknown"
		if states != nil {
			if states[node] {
				nodeStatus = "online"
			} else {
				nodeStatus = "offline"
			}
		}
		status.Nodes[node] = NodeInfo{Name: name, Status: nodeStatus}
	}
	
	// Agent-Status aus Cron
	cmd := exec.Command("crontab", "-l")
	output, err := cmd.Output()
	if err != nil {
		status.Agents["active_crons"] = "unknown"
	} else {
		scanner := bufio.NewScanner(strings.NewReader(string(output)))
		count := 0
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line != "" && !strings.HasPrefix(line, "#") {
				count++
			}
		}
		status.Agents["active_crons"] = count
	}
	
	// System-Metriken
	// Disk usage
	dfCmd := exec.Command("df", "-h", "/")
	dfOutput, err := dfCmd.Output()
	if err == nil {
		scanner := bufio.NewScanner(strings.NewReader(string(dfOutput)))
		for scanner.Scan() {
			line := scanner.Text()
			if strings.Contains(line, "/") && strings.Contains(line, "%") {
				parts := strings.Fields(line)
				if len(parts) >= 5 {
					status.System["disk_used"] = parts[4]
					break
				}
			}
		}
	}
	
	// RAM usage
	freeCmd := exec.Command("free", "-h")
	freeOutput, err := freeCmd.Output()
	if err == nil {
		scanner := bufio.NewScanner(strings.NewReader(string(freeOutput)))
		for scanner.Scan() {
			line := scanner.Text()
			if strings.Contains(line, "Mem:") {
				parts := strings.Fields(line)
				if len(parts) >= 3 {
					status.System["ram_total"] = parts[1]
					status.System["ram_used"] = parts[2]
				}
				break
			}
		}
	}
	
	return status
}

func formatDailyStatus(status Status) string {
	online := 0
	for _, node := range status.Nodes {
		if node.Status == "online" {
			online++
		}
	}
	
	message := fmt.Sprintf("📊 **Täglicher Status-Report**\n🗓️ %s\n\n**🖥️ Nodes (%d/%d online):**\n",
		time.Now().Format("2006-01-02 15:04"),
		online,
		len(status.Nodes))
	
	for nodeID, info := range status.Nodes {
		emoji := "🟡"
		if info.Status == "online" {
			emoji = "🟢"
		} else if info.Status == "offline" {
			emoji = "🔴"
		}
		
		message += fmt.Sprintf("%s %s: %s", emoji, info.Name, info.Status)
		if info.Reason != "" {
			message += fmt.Sprintf(" (%s)", info.Reason)
		}
		message += "\n"
	}
	
	message += fmt.Sprintf("\n**🤖 Agents:**\nAktive Cron-Jobs: %v\n", status.Agents["active_crons"])
	
	if diskUsed, exists := status.System["disk_used"]; exists {
		message += "\n**💾 System:**\n"
		message += fmt.Sprintf("Disk: %s belegt\n", diskUsed)
		if ramUsed, exists := status.System["ram_used"]; exists {
			if ramTotal, exists := status.System["ram_total"]; exists {
				message += fmt.Sprintf("RAM: %s / %s\n", ramUsed, ramTotal)
			}
		}
	}
	
	return message
}

func formatWeeklyStatus(status Status) string {
	lines := []string{
		"📈 **Wöchentlicher Report**",
		fmt.Sprintf("📅 Woche %s - %s", time.Now().Format("02"), time.Now().Format("2006")),
		"",
		"**Nodes:**",
	}
	
	for _, node := range status.Nodes {
		lines = append(lines, fmt.Sprintf("- %s: %s", node.Name, node.Status))
	}
	
	return strings.Join(lines, "\n") + "\n"
}

func sendToChannel(message string, channelType string, channelID string) bool {
	if channelType == "telegram" {
		// Nutze OpenClaw message tool
		cmd := exec.Command("openclaw", "message", "send", "--target", channelID, "--message", message)
		result, err := cmd.CombinedOutput()
		if err != nil {
			logMessage(fmt.Sprintf("Failed to send: %s", string(result)), "ERROR")
			return false
		}
		logMessage(fmt.Sprintf("Message sent to %s %s", channelType, channelID), "INFO")
		return true
	} else {
		logMessage(fmt.Sprintf("Channel type %s not implemented", channelType), "WARN")
		return false
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: channel_status.go --type <daily|weekly|alert> [--message <message>] [--channel <id>] [--dry-run]")
		os.Exit(1)
	}
	
	var reportType, alertMessage, channelID string
	dryRun := false
	
	for i := 1; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--type":
			if i+1 < len(os.Args) {
				reportType = os.Args[i+1]
				i++
			}
		case "--message":
			if i+1 < len(os.Args) {
				alertMessage = os.Args[i+1]
				i++
			}
		case "--channel":
			if i+1 < len(os.Args) {
				channelID = os.Args[i+1]
				i++
			}
		case "--dry-run":
			dryRun = true
		}
	}
	
	if reportType == "" {
		fmt.Println("Error: --type is required")
		os.Exit(1)
	}
	
	if channelID == "" {
		channelID = "-1002381931352"
	}
	
	logMessage(fmt.Sprintf("Starting %s status update", reportType), "INFO")
	
	// Status sammeln
	status := getSystemStatus()
	
	// Message formatieren
	var message string
	switch reportType {
	case "daily":
		message = formatDailyStatus(status)
	case "weekly":
		message = formatWeeklyStatus(status)
	case "alert":
		if alertMessage == "" {
			alertMessage = "Manual alert"
		}
		message = fmt.Sprintf("🚨 **ALERT**\n%s", alertMessage)
	default:
		fmt.Printf("Unknown report type: %s\n", reportType)
		os.Exit(1)
	}
	
	// Senden oder Dry-Run
	if dryRun {
		fmt.Println("\n--- DRY RUN ---")
		fmt.Println(message)
		fmt.Println("--- END ---")
	} else {
		sendToChannel(message, "telegram", channelID)
	}
	
	logMessage("Status update completed", "INFO")
}
