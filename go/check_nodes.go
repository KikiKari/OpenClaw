// abstraction-provenance: {"artifact_sha256": "43899e814ae50b9600935ace1e220daa3ed39f4eba0e54b74860cc107c68f491", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "go"}
// check_nodes.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
// auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Node-Status Checker - Prüft Verfügbarkeit aller Nodes
*/

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Node-Konfiguration (sollte aus config file geladen werden)
var NODES = map[string]map[string]interface{}{
	"node1": {
		"always_available": true,
		"capacity":         "medium",
		"priority":         2,
		"description":      "Gateway-Master",
	},
	"node2": {
		"always_available": true,
		"capacity":         "medium",
		"priority":         3,
		"description":      "Stable Worker",
	},
	"node3": {
		"always_available": false,
		"capacity":         "medium",
		"priority":         4,
		"description":      "Bald verfügbar (nach Reorganisation)",
	},
	"node5": {
		"always_available": false,
		"capacity":         "low",
		"priority":         5,
		"device":           "Redmi Note 11S",
		"description":      "Mobile (bei Internet verfügbar)",
	},
	"node7": {
		"always_available": true,
		"capacity":         "high",
		"priority":         1,
		"description":      "Docker Hauptarbeitspferd (bald verfügbar)",
	},
}

type NodeStatus struct {
	ID       string `json:"id"`
	Online   bool   `json:"online"`
	Available bool  `json:"available"`
	Response string `json:"response"`
}

func checkNodeStatus(nodeID string) NodeStatus {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "openclaw", "nodes", "status", nodeID)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	
	if ctx.Err() == context.DeadlineExceeded {
		return NodeStatus{
			ID:        nodeID,
			Online:    false,
			Available: getBoolValue(NODES[nodeID]["always_available"], false),
			Response:  "Timeout",
		}
	}

	if err != nil {
		return NodeStatus{
			ID:        nodeID,
			Online:    false,
			Available: getBoolValue(NODES[nodeID]["always_available"], false),
			Response:  fmt.Sprintf("Error: %v", err),
		}
	}

	output := string(stdout.Bytes())
	isOnline := strings.Contains(strings.ToLower(output), "online") || 
				strings.Contains(strings.ToLower(output), "active")

	response := strings.TrimSpace(output)
	if len(response) > 100 {
		response = response[:100]
	}
	if response == "" {
		response = "No response"
	}

	return NodeStatus{
		ID:        nodeID,
		Online:    isOnline,
		Available: getBoolValue(NODES[nodeID]["always_available"], false),
		Response:  response,
	}
}

func getBoolValue(value interface{}, defaultValue bool) bool {
	if value == nil {
		return defaultValue
	}
	if b, ok := value.(bool); ok {
		return b
	}
	return defaultValue
}

func getStringValue(value interface{}, defaultValue string) string {
	if value == nil {
		return defaultValue
	}
	if s, ok := value.(string); ok {
		return s
	}
	return defaultValue
}

func getIntValue(value interface{}, defaultValue int) int {
	if value == nil {
		return defaultValue
	}
	if i, ok := value.(int); ok {
		return i
	}
	if f, ok := value.(float64); ok {
		return int(f)
	}
	return defaultValue
}

func printTable(nodesStatus []NodeStatus) {
	fmt.Println()
	fmt.Println(strings.Repeat("=", 90))
	fmt.Printf("%-8s %-12s %-12s %-10s %-10s %s\n", "Node", "Status", "Verfügbar", "Kapazität", "Priorität", "Gerät/Beschreibung")
	fmt.Println(strings.Repeat("=", 90))

	for _, status := range nodesStatus {
		nodeID := status.ID
		config := NODES[nodeID]

		statusIcon := "🔴 Offline"
		if status.Online {
			statusIcon = "🟢 Online"
		}

		availIcon := "📱 Bedingt"
		if status.Available {
			availIcon = "✅ Immer"
		}

		capacity := getStringValue(config["capacity"], "unknown")
		priority := getIntValue(config["priority"], 0)
		device := getStringValue(config["device"], getStringValue(config["description"], ""))

		priorityStr := "-"
		if priority > 0 {
			priorityStr = fmt.Sprintf("%d", priority)
		}

		fmt.Printf("%-8s %-12s %-12s %-10s %-10s %s\n", nodeID, statusIcon, availIcon, capacity, priorityStr, device)
	}

	fmt.Println(strings.Repeat("=", 90))
	now := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("\nGeprüft am: %s\n", now)
}

func printJSON(nodesStatus []NodeStatus) {
	type OutputNode struct {
		Status NodeStatus                 `json:"status"`
		Config map[string]interface{}    `json:"config"`
	}

	output := struct {
		Timestamp string                   `json:"timestamp"`
		Nodes     map[string]OutputNode    `json:"nodes"`
	}{
		Timestamp: time.Now().Format(time.RFC3339),
		Nodes:     make(map[string]OutputNode),
	}

	for _, status := range nodesStatus {
		nodeID := status.ID
		output.Nodes[nodeID] = OutputNode{
			Status: status,
			Config: NODES[nodeID],
		}
	}

	jsonData, _ := json.MarshalIndent(output, "", "  ")
	fmt.Println(string(jsonData))
}

func saveToFile(nodesStatus []NodeStatus, filename string) error {
	type SavedNode struct {
		ID       string `json:"id"`
		Online   bool   `json:"online"`
		Available bool  `json:"available"`
		Response string `json:"response"`
	}

	output := struct {
		Timestamp string                `json:"timestamp"`
		Nodes     map[string]SavedNode `json:"nodes"`
	}{
		Timestamp: time.Now().Format(time.RFC3339),
		Nodes:     make(map[string]SavedNode),
	}

	for _, status := range nodesStatus {
		output.Nodes[status.ID] = SavedNode{
			ID:        status.ID,
			Online:    status.Online,
			Available: status.Available,
			Response:  status.Response,
		}
	}

	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	return encoder.Encode(output)
}

func main() {
	// Simple argument parsing
	format := "table"
	saveFile := ""
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		if arg == "--format" || arg == "-f" {
			if i+1 < len(os.Args) {
				format = os.Args[i+1]
				i++
			}
		} else if arg == "--save" || arg == "-s" {
			if i+1 < len(os.Args) {
				saveFile = os.Args[i+1]
				i++
			}
		} else if strings.HasPrefix(arg, "--format=") {
			format = strings.TrimPrefix(arg, "--format=")
		} else if strings.HasPrefix(arg, "-f=") {
			format = strings.TrimPrefix(arg, "-f=")
		} else if strings.HasPrefix(arg, "--save=") {
			saveFile = strings.TrimPrefix(arg, "--save=")
		} else if strings.HasPrefix(arg, "-s=") {
			saveFile = strings.TrimPrefix(arg, "-s=")
		}
	}

	if format != "table" && format != "json" {
		format = "table"
	}

	fmt.Println("🔍 Prüfe Node-Status...")

	// Get sorted node IDs
	var nodeIDs []string
	for id := range NODES {
		nodeIDs = append(nodeIDs, id)
	}
	sort.Strings(nodeIDs)

	// Prüfe alle Nodes
	var nodesStatus []NodeStatus
	for _, nodeID := range nodeIDs {
		fmt.Printf("  → %s... ", nodeID)
		status := checkNodeStatus(nodeID)
		nodesStatus = append(nodesStatus, status)
		if status.Online {
			fmt.Println("✓")
		} else {
			fmt.Println("✗")
		}
	}

	// Ausgabe
	if format == "table" {
		printTable(nodesStatus)
	} else {
		printJSON(nodesStatus)
	}

	// Speichern
	if saveFile != "" {
		err := saveToFile(nodesStatus, saveFile)
		if err != nil {
			fmt.Printf("Fehler beim Speichern: %v\n", err)
		} else {
			absPath, _ := filepath.Abs(saveFile)
			fmt.Printf("\n💾 Gespeichert: %s\n", absPath)
		}
	}

	// Zusammenfassung
	onlineCount := 0
	for _, status := range nodesStatus {
		if status.Online {
			onlineCount++
		}
	}
	fmt.Printf("\n📊 Zusammenfassung: %d/%d Nodes online\n", onlineCount, len(nodesStatus))
}
