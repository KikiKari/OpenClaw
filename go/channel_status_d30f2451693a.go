// abstraction-provenance: {"artifact_sha256": "818d6edaf5785164f61ec1895c35da77b9f98c31b7ec7da973b343a1fbd6a7a5", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "go"}
// channel_status.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
// auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
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

func init() {
	// Stelle sicher, dass das Log-Verzeichnis existiert
	logDir := filepath.Dir(LOG_FILE)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen des Log-Verzeichnisses: %v\n", err)
		os.Exit(1)
	}
	
	// Öffne die Log-Datei zum Schreiben
	file, err := os.OpenFile(LOG_FILE, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Öffnen der Log-Datei: %v\n", err)
		os.Exit(1)
	}
	log.SetOutput(file)
	log.SetFlags(0) // Wir formatieren den Timestamp selbst
}

func logMessage(message, level string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	entry := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(entry)
	log.Println(entry)
}

func getSystemStatus() Status {
	status := Status{
		Timestamp: time.Now().Format(time.RFC3339),
		Nodes:     make(map[string]NodeInfo),
		Agents:    make(map[string]interface{}),
		System:    make(map[string]string),
	}
	
	// Node-Status (vereinfacht)
	nodes := map[string]NodeInfo{
		"node1": {"Gateway", "online", ""},
		"node2": {"Worker", "online", ""},
		"node3": {"Relay", "offline", "disk full"},
		"node5": {"Redmi", "intermittent", ""},
		"node7": {"Docker", "planned", ""},
	}
	status.Nodes = nodes
	
	// Agent-Status aus Cron
	cmd := exec.Command("crontab", "-l")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		status.Agents["active_crons"] = "unknown"
	} else {
		lines := strings.Split(out.String(), "\n")
		count := 0
		for _, line := range lines {
			if line != "" && !strings.HasPrefix(line, "#") {
				count++
			}
		}
		status.Agents["active_crons"] = count
	}
	
	// System-Metriken
	// Disk usage
	dfCmd := exec.Command("df", "-h", "/")
	var dfOut bytes.Buffer
	dfCmd.Stdout = &dfOut
	err = dfCmd.Run()
	if err == nil {
		lines := strings.Split(dfOut.String(), "\n")
		for _, line := range lines {
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
	var freeOut bytes.Buffer
	freeCmd.Stdout = &freeOut
	err = freeCmd.Run()
	if err == nil {
		lines := strings.Split(freeOut.String(), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Mem:") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					status.System["ram_total"] = parts[1]
				}
				if len(parts) >= 3 {
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
	
	message := fmt.Sprintf("📊 **Täglicher Status-Report**\n🗓️ %s\n\n**🖥️ Nodes (%d/5 online):**\n",
		time.Now().Format("2006-01-02 15:04"), online)
	
	for nodeID, info := range status.Nodes {
		emoji := "🟢"
		if info.Status == "offline" {
			emoji = "🔴"
		} else if info.Status == "intermittent" {
			emoji = "🟡"
		}
		
		line := fmt.Sprintf("%s %s: %s", emoji, info.Name, info.Status)
		if info.Reason != "" {
			line += fmt.Sprintf(" (%s)", info.Reason)
		}
		message += line + "\n"
	}
	
	message += fmt.Sprintf("\n**🤖 Agents:**\nAktive Cron-Jobs: %v\n", status.Agents["active_crons"])
	
	if diskUsed, exists := status.System["disk_used"]; exists {
		message += fmt.Sprintf("\n**💾 System:**\nDisk: %s belegt\n", diskUsed)
		if ramUsed, exists := status.System["ram_used"]; exists {
			if ramTotal, exists := status.System["ram_total"]; exists {
				message += fmt.Sprintf("RAM: %s / %s\n", ramUsed, ramTotal)
			}
		}
	}
	
	return message
}

func formatWeeklyStatus(status Status) string {
	_, week := time.Now().ISOWeek()
	message := fmt.Sprintf(`📈 **Wöchentlicher Report**
📅 Woche %d - %d

**Zusammenfassung:**
- 5 aktive Sub-Agents
- 11 Skills synchronisiert
- 3 neue Features implementiert

**Top-Ereignisse:**
1. ClawHub-Git Sync implementiert ✅
2. Node 3 Disk voll (95%%) ⚠️
3. Channel-Status-Agent aktiviert 🆕

**Geplante Wartungen:**
- Node 3: Disk-Cleanup erforderlich
- Node 7: Docker-Setup ausstehend
`, week, time.Now().Year())
	
	return message
}

func sendToChannel(message, channelType, channelID string) bool {
	if channelType != "telegram" {
		logMessage(fmt.Sprintf("Channel type %s not implemented", channelType), "WARN")
		return false
	}
	
	// Nutze OpenClaw message tool
	cmd := exec.Command("openclaw", "message", "send", "--target", channelID, "--message", message)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		logMessage(fmt.Sprintf("Failed to send: %s", string(output)), "ERROR")
		return false
	}
	
	logMessage(fmt.Sprintf("Message sent to %s %s", channelType, channelID), "INFO")
	return true
}

func main() {
	// Argumente parsen
	typeArg := ""
	messageArg := ""
	channelArg := "-1002381931352"
	dryRun := false
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--type":
			if i+1 < len(os.Args) {
				typeArg = os.Args[i+1]
				i++
			}
		case "--message":
			if i+1 < len(os.Args) {
				messageArg = os.Args[i+1]
				i++
			}
		case "--channel":
			if i+1 < len(os.Args) {
				channelArg = os.Args[i+1]
				i++
			}
		case "--dry-run":
			dryRun = true
		}
	}
	
	if typeArg == "" {
		fmt.Println("Usage: channel_status --type [daily|weekly|alert] [--message MSG] [--channel ID] [--dry-run]")
		os.Exit(1)
	}
	
	logMessage(fmt.Sprintf("Starting %s status update", typeArg), "INFO")
	
	// Status sammeln
	status := getSystemStatus()
	
	// Message formatieren
	var message string
	switch typeArg {
	case "daily":
		message = formatDailyStatus(status)
	case "weekly":
		message = formatWeeklyStatus(status)
	case "alert":
		if messageArg == "" {
			messageArg = "Manual alert"
		}
		message = fmt.Sprintf("🚨 **ALERT**\n%s", messageArg)
	default:
		fmt.Printf("Unbekannter Typ: %s\n", typeArg)
		os.Exit(1)
	}
	
	// Senden oder Dry-Run
	if dryRun {
		fmt.Println("\n--- DRY RUN ---")
		fmt.Println(message)
		fmt.Println("--- END ---")
	} else {
		sendToChannel(message, "telegram", channelArg)
	}
	
	logMessage("Status update completed", "INFO")
}
