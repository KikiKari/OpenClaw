// abstraction-provenance: {"artifact_sha256": "5271e536b939ecfb409021af01d51e77a0d67c00d6e5a6ac269a6960782d5f79", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "go"}
// test_multinode_fallback.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
*/

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const WORKSPACE = "/home/openclaw/.openclaw/workspace"

func checkNodeReachable(nodeID string) bool {
	/*Prüft ob Node erreichbar ist*/
	cmd := exec.Command("openclaw", "nodes", "status")
	
	// Setze Timeout
	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()
	
	select {
	case err := <-done:
		if err != nil {
			return false
		}
		
		output, _ := cmd.Output()
		outputStr := string(output)
		return strings.Contains(outputStr, nodeID) && strings.Contains(outputStr, "connected")
	case <-time.After(10 * time.Second):
		return false
	}
}

func spawnOnNode(nodeID string, task string) bool {
	/*Versucht Task auf Node auszuführen*/
	fmt.Printf("Versuche Task auf Node %s zu starten...\n", nodeID)
	
	cmd := exec.Command("echo", fmt.Sprintf("Spawned on %s: %s", nodeID, task))
	
	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()
	
	select {
	case err := <-done:
		if err != nil {
			fmt.Printf("❌ Node %s nicht erreichbar: %v\n", nodeID, err)
			return false
		}
		
		fmt.Printf("✅ Erfolgreich delegiert an %s\n", nodeID)
		return true
	case <-time.After(5 * time.Second):
		fmt.Printf("❌ Node %s nicht erreichbar: Timeout\n", nodeID)
		return false
	}
}

func executeLocally(task string) bool {
	/*Führt Task lokal aus (Fallback)*/
	fmt.Println("🔄 Fallback: Führe Task lokal aus...")
	
	if task == "db_maintainer" {
		scriptPath := filepath.Join(WORKSPACE, "skills", "db-maintainer", "scripts", "db_maintainer.py")
		cmd := exec.Command("python3", scriptPath)
		
		done := make(chan error, 1)
		go func() {
			done <- cmd.Run()
		}()
		
		select {
		case err := <-done:
			if err != nil {
				fmt.Printf("❌ Fehler: %v\n", err)
				return false
			}
			
			fmt.Println("✅ Lokale Ausführung erfolgreich")
			return true
		case <-time.After(60 * time.Second):
			fmt.Println("❌ Fehler: Timeout bei lokaler Ausführung")
			return false
		}
	}
	
	return false
}

func main() {
	fmt.Println("============================================================")
	fmt.Println("MULTI-NODE FALLBACK TEST")
	fmt.Println("============================================================")
	fmt.Println()
	
	// Konfiguration
	primaryNode := "v2202603104722445775" // Node 2
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
