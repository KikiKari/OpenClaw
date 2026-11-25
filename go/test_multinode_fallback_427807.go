// abstraction-provenance: {"artifact_sha256": "e545b57aafa29b5947d3827a9022ac1e4821698c878b1c2bb1c4dc31b430278f", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "go"}
// test_multinode_fallback.py — portiert nach go
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
*/

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var WORKSPACE = "/home/openclaw/.openclaw/workspace"

type NodeStatus struct {
	Nodes []struct {
		DisplayName string `json:"displayName"`
		Connected   bool   `json:"connected"`
	} `json:"nodes"`
}

func checkNodeReachable(nodeId string) bool {
	/* Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe. */
	aliases := map[string]bool{strings.ToLower(nodeId): true}
	node2Names := map[string]bool{
		"openclaw-node2":                              true,
		"arm64-node":                                  true,
		"v2202604104722449961":                        true,
		"v2202604104722449961.taild25fea.ts.net":      true,
	}
	if node2Names[strings.ToLower(nodeId)] {
		for k := range node2Names {
			aliases[k] = true
		}
	}
	cmd := exec.Command("openclaw", "nodes", "status", "--json")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd = exec.CommandContext(ctx, "openclaw", "nodes", "status", "--json")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	var payload NodeStatus
	err = json.Unmarshal(output, &payload)
	if err != nil {
		return false
	}
	for _, node := range payload.Nodes {
		if aliases[strings.ToLower(node.DisplayName)] && node.Connected {
			return true
		}
	}
	return false
}

func spawnOnNode(nodeId string, task string) bool {
	/* Versucht Task auf Node auszuführen */
	fmt.Printf("Versuche Task auf Node %s zu starten...\n", nodeId)
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("❌ Node %s nicht erreichbar: %v\n", nodeId, r)
		}
	}()
	// Simuliert: openclaw agent spawn --node {node_id}
	cmd := exec.Command("echo", fmt.Sprintf("Spawned on %s: %s", nodeId, task))
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd = exec.CommandContext(ctx, "echo", fmt.Sprintf("Spawned on %s: %s", nodeId, task))
	_, err := cmd.Output()
	if err != nil {
		panic(err)
	}
	fmt.Printf("✅ Erfolgreich delegiert an %s\n", nodeId)
	return true
}

func executeLocally(task string) bool {
	/* Führt Task lokal aus (Fallback) */
	fmt.Println("🔄 Fallback: Führe Task lokal aus...")
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("❌ Lokale Ausführung fehlgeschlagen: %v\n", r)
		}
	}()
	if task == "db_maintainer" {
		scriptPath := filepath.Join(WORKSPACE, "skills", "db-maintainer", "scripts", "db_maintainer.py")
		cmd := exec.Command("python3", scriptPath)
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		cmd = exec.CommandContext(ctx, "python3", scriptPath)
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("❌ Fehler: %s\n", string(output)[:200])
			return false
		}
		fmt.Println("✅ Lokale Ausführung erfolgreich")
		return true
	}
	return false
}

func main() {
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println("MULTI-NODE FALLBACK TEST")
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println()

	// Konfiguration
	primaryNode := "v2202604104722449961.taild25fea.ts.net" // Node 2
	task := "db_maintainer"

	fmt.Printf("Primärer Node: %s\n", primaryNode)
	fmt.Printf("Task: %s\n", task)
	fmt.Println()

	// 1. Prüfe Node-Erreichbarkeit
	fmt.Println("--- 1. Prüfe Node-Erreichbarkeit ---")
	if checkNodeReachable(primaryNode) {
		fmt.Printf("✅ Node %s ist erreichbar\n", primaryNode)

		// 2. Versuche Delegation
		fmt.Println("\n--- 2. Versuche Delegation ---")
		if spawnOnNode(primaryNode, task) {
			fmt.Println("\n✅ MULTI-NODE: Task erfolgreich delegiert")
			os.Exit(0)
		} else {
			fmt.Println("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...")
		}
	} else {
		fmt.Printf("❌ Node %s nicht erreichbar\n", primaryNode)
		fmt.Println("🔄 Fallback wird aktiviert...")
	}

	// 3. Lokale Ausführung (Fallback)
	fmt.Println("\n--- 3. Lokale Ausführung (Fallback) ---")
	if executeLocally(task) {
		fmt.Println("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt")
		os.Exit(0)
	} else {
		fmt.Println("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich")
		os.Exit(1)
	}
}
