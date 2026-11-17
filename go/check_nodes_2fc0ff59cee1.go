// abstraction-provenance: {"artifact_sha256": "2d799bdbaf7264a0ff884f853c98438868a9effd82a9a7ebe472276489c417b0", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "go"}
// check_nodes.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
// auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/*
Node-Status Checker - Prüft Verfügbarkeit aller Nodes
*/

package main

import (
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
	cmd := exec.Command("openclaw", "nodes", "status", nodeID)
	cmd.Dir = filepath.Dir(os.Args[0])

	output, err := cmd.Output()
	if err != nil {
		if _, ok := err.(*exec.ExitError); !ok && strings.Contains(err.Error(), "signal:") {
			return NodeStatus{
				ID:        nodeID,
				Online:    false,
				Available: getBoolValue(NODES[nodeID]["always_available"]),
				Response:  fmt.Sprintf("Error: %v", err),
			}
		}
	}

	isOnline := cmd.ProcessState.Success() && (strings.Contains(strings.ToLower(string(output)), "online") ||
		strings.Contains(strings.ToLower(string(output)), "active"))

	response := "No response"
	if len(output) > 0 {
		responseStr := strings.TrimSpace(string(output))
		if len(responseStr) > 100 {
			response = responseStr[:100]
		} else {
			response = responseStr
		}
	}

	return NodeStatus{
		ID:        nodeID,
		Online:    isOnline,
		Available: getBoolValue(NODES[nodeID]["always_available"]),
		Response:  response,
	}
}

func getBoolValue(value interface{}) bool {
	if b, ok := value.(bool); ok {
		return b
	}
	return false
}

func getStringValue(value interface{}) string {
	if s, ok := value.(string); ok {
		return s
	}
	return ""
}

func getIntValue(value interface{}) int {
	if i, ok := value.(int); ok {
		return i
	}
	return 0
}

func printTable(nodesStatus []NodeStatus) {
	fmt.Println("\n" + strings.Repeat("=", 90))
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

		capacity := getStringValue(config["capacity"])
		priority := getIntValue(config["priority"])
		device := getStringValue(config["device"])
		description := getStringValue(config["description"])

		if device == "" {
			device = description
		}

		fmt.Printf("%-8s %-12s %-12s %-10s %-10d %s\n", nodeID, statusIcon, availIcon, capacity, priority, device)
	}

	fmt.Println(strings.Repeat("=", 90))
	fmt.Printf("\nGeprüft am: %s\n", time.Now().Format("2006-01-02 15:04:05"))
}

func printJSON(nodesStatus []NodeStatus) {
	output := make(map[string]interface{})
	output["timestamp"] = time.Now().Format(time.RFC3339)
	nodes := make(map[string]interface{})

	for _, status := range nodesStatus {
		nodeID := status.ID
		nodeData := make(map[string]interface{})
		nodeData["status"] = status
		nodeData["config"] = NODES[nodeID]
		nodes[nodeID] = nodeData
	}

	output["nodes"] = nodes

	jsonData, _ := json.MarshalIndent(output, "", "  ")
	fmt.Println(string(jsonData))
}

func saveToFile(filename string, nodesStatus []NodeStatus) error {
	output := make(map[string]interface{})
	output["timestamp"] = time.Now().Format(time.RFC3339)
	nodes := make(map[string]NodeStatus)

	for _, status := range nodesStatus {
		nodes[status.ID] = status
	}

	output["nodes"] = nodes

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
	format := "table"
	saveFile := ""

	// Simple argument parsing
	for i, arg := range os.Args[1:] {
		if arg == "--format" || arg == "-f" {
			if i+1 < len(os.Args)-1 {
				format = os.Args[i+2]
			}
		} else if arg == "--save" || arg == "-s" {
			if i+1 < len(os.Args)-1 {
				saveFile = os.Args[i+2]
			}
		}
	}

	fmt.Println("🔍 Prüfe Node-Status...")

	// Prüfe alle Nodes
	var nodesStatus []NodeStatus
	var keys []string
	for k := range NODES {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, nodeID := range keys {
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
		err := saveToFile(saveFile, nodesStatus)
		if err != nil {
			fmt.Printf("\n❌ Fehler beim Speichern: %v\n", err)
		} else {
			fmt.Printf("\n💾 Gespeichert: %s\n", saveFile)
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
