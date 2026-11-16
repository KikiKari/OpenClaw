// abstraction-provenance: {"artifact_sha256": "c02d1701d85754107af2691910f7322c6d106a0c6d92ee34f4d5c0c206b97e29", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "go"}
// channel_status.py — portiert nach go
// Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/*
Channel Status Agent - Automatische Status-Updates
*/

package main

import (
	"bytes"
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
	WORKSPACE  = "/home/openclaw/.openclaw/workspace"
	LOGS_DB    = filepath.Join(WORKSPACE, "db/logs.db")
	CONFIG_FILE = filepath.Join(WORKSPACE, "config/channel-status.json")
	LOG_FILE   = filepath.Join(WORKSPACE, "logs/channel-status.log")
)

func init() {
	os.MkdirAll(filepath.Dir(LOG_FILE), 0755)
}

func logMessage(message string, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	f.WriteString(entry + "\n")
}

var NODE_NAMES = map[string]map[string]bool{
	"node2": {"openclaw-node2": true, "arm64-node": true, "v2202604104722449961": true, "v2202604104722449961.taild25fea.ts.net": true, "100.82.198.122": true},
	"node3": {"openclaw-node3": true, "openclaw-node3.taild25fea.ts.net": true, "100.73.154.125": true},
	"node4": {"openclaw-node4": true, "redmi-note-11s": true, "redmi-note-11s.taild25fea.ts.net": true, "100.94.134.39": true},
	"node5": {"openclaw-node5": true},
	"node6": {"openclaw-node6": true},
}

func fetchNodeStatus() map[string]bool {
	cmd := exec.Command("openclaw", "nodes", "status", "--json")
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Start()
	if err != nil {
		return nil
	}

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		return nil
	case err := <-done:
		if err != nil {
			return nil
		}
	}

	var payload struct {
		Nodes []struct {
			DisplayName string `json:"displayName"`
			NodeId      string `json:"nodeId"`
			RemoteIp    string `json:"remoteIp"`
			Connected   bool   `json:"connected"`
		} `json:"nodes"`
	}

	if err := json.Unmarshal(out.Bytes(), &payload); err != nil {
		return nil
	}

	states := make(map[string]bool)
	for node := range NODE_NAMES {
		states[node] = false
	}

	for _, item := range payload.Nodes {
		names := map[string]bool{
			strings.ToLower(item.DisplayName): true,
			strings.ToLower(item.NodeId):       true,
			strings.ToLower(item.RemoteIp):    true,
		}
		for node, aliases := range NODE_NAMES {
			for alias := range names {
				if aliases[alias] && item.Connected {
					states[node] = true
				}
			}
		}
	}
	states["node1"] = true // successful Gateway status request
	return states
}

func getSystemStatus() map[string]interface{} {
	status := map[string]interface{}{
		"timestamp": time.Now().Format(time.RFC3339),
		"nodes":     map[string]interface{}{},
		"agents":    map[string]interface{}{},
		"system":    map[string]interface{}{},
	}

	states := fetchNodeStatus()
	names := map[string]string{
		"node1": "Gateway",
		"node2": "Node2",
		"node3": "Node3",
		"node4": "Redmi",
		"node5": "Lenovo",
		"node6": "Lenovo (Docker)",
	}

	nodes := make(map[string]interface{})
	for node, name := range names {
		nodeStatus := "unknown"
		if states != nil {
			if val, ok := states[node]; ok && val {
				nodeStatus = "online"
			} else {
				nodeStatus = "offline"
			}
		}
		nodes[node] = map[string]interface{}{
			"name":   name,
			"status": nodeStatus,
		}
	}
	status["nodes"] = nodes

	// Agent-Status aus Cron
	cronCmd := exec.Command("crontab", "-l")
	cronOut, err := cronCmd.Output()
	activeCrons := "unknown"
	if err == nil {
		lines := strings.Split(string(cronOut), "\n")
		count := 0
		for _, line := range lines {
			if !strings.HasPrefix(line, "#") && strings.TrimSpace(line) != "" {
				count++
			}
		}
		activeCrons = strconv.Itoa(count)
	}
	status["agents"].(map[string]interface{})["active_crons"] = activeCrons

	// System-Metriken
	dfCmd := exec.Command("df", "-h", "/")
	dfOut, err := dfCmd.Output()
	if err == nil {
		lines := strings.Split(string(dfOut), "\n")
		for _, line := range lines {
			if strings.Contains(line, "/") && strings.Contains(line, "%") {
				parts := strings.Fields(line)
				if len(parts) >= 5 {
					status["system"].(map[string]interface{})["disk_used"] = parts[4]
				}
				break
			}
		}
	}

	freeCmd := exec.Command("free", "-h")
	freeOut, err := freeCmd.Output()
	if err == nil {
		lines := strings.Split(string(freeOut), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Mem:") {
				parts := strings.Fields(line)
				if len(parts) >= 3 {
					status["system"].(map[string]interface{})["ram_total"] = parts[1]
					status["system"].(map[string]interface{})["ram_used"] = parts[2]
				}
				break
			}
		}
	}

	return status
}

func formatDailyStatus(status map[string]interface{}) string {
	nodes := status["nodes"].(map[string]interface{})
	online := 0
	for _, n := range nodes {
		info := n.(map[string]interface{})
		if info["status"] == "online" {
			online++
		}
	}

	message := fmt.Sprintf("📊 **Täglicher Status-Report**\n🗓️ %s\n\n**🖥️ Nodes (%d/%d online):**\n",
		time.Now().Format("2006-01-02 15:04"),
		online,
		len(nodes))

	for nodeID, infoInterface := range nodes {
		info := infoInterface.(map[string]interface{})
		emoji := "🟡"
		switch info["status"] {
		case "online":
			emoji = "🟢"
		case "offline":
			emoji = "🔴"
		}
		message += fmt.Sprintf("%s %s: %s", emoji, info["name"], info["status"])
		if reason, exists := info["reason"]; exists {
			message += fmt.Sprintf(" (%s)", reason)
		}
		message += "\n"
	}

	message += fmt.Sprintf("\n**🤖 Agents:**\nAktive Cron-Jobs: %s\n", status["agents"].(map[string]interface{})["active_crons"])

	system := status["system"].(map[string]interface{})
	if diskUsed, exists := system["disk_used"]; exists {
		message += fmt.Sprintf("\n**💾 System:**\nDisk: %s belegt\n", diskUsed)
		if ramUsed, exists := system["ram_used"]; exists {
			if ramTotal, exists := system["ram_total"]; exists {
				message += fmt.Sprintf("RAM: %s / %s\n", ramUsed, ramTotal)
			}
		}
	}

	return message
}

func formatWeeklyStatus(status map[string]interface{}) string {
	lines := []string{
		"📈 **Wöchentlicher Report**",
		fmt.Sprintf("📅 Woche %s - %s", time.Now().Format("02"), time.Now().Format("2006")),
		"",
		"**Nodes:**",
	}

	nodes := status["nodes"].(map[string]interface{})
	for _, infoInterface := range nodes {
		info := infoInterface.(map[string]interface{})
		lines = append(lines, fmt.Sprintf("- %s: %s", info["name"], info["status"]))
	}

	return strings.Join(lines, "\n") + "\n"
}

func sendToChannel(message string, channelType string, channelID string) bool {
	if channelType == "telegram" {
		cmd := exec.Command("openclaw", "message", "send", "--target", channelID, "--message", message)
		output, err := cmd.CombinedOutput()
		if err != nil {
			logMessage(fmt.Sprintf("Failed to send: %s", string(output)), "ERROR")
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
		fmt.Println("Usage: channel_status.go --type <daily|weekly|alert> [--message <msg>] [--channel <id>] [--dry-run]")
		os.Exit(1)
	}

	var reportType, alertMessage, channelID string
	dryRun := false

	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
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
		log.Fatal("--type is required")
	}

	if channelID == "" {
		channelID = "-1002381931352"
	}

	logMessage(fmt.Sprintf("Starting %s status update", reportType), "INFO")

	status := getSystemStatus()

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
		log.Fatalf("Unknown type: %s", reportType)
	}

	if dryRun {
		fmt.Println("\n--- DRY RUN ---")
		fmt.Println(message)
		fmt.Println("--- END ---")
	} else {
		sendToChannel(message, "telegram", channelID)
	}

	logMessage("Status update completed", "INFO")
}
