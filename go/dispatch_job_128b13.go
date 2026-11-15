// abstraction-provenance: {"artifact_sha256": "df29640749189ccd7f52c1ce8d118aee61af9ac4c53ea5d0652fa607fb22924f", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "go"}
// dispatch_job.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"flag"
	"time"
)

// Node-Konfiguration
var NODES = map[string]map[string]interface{}{
	"node1": {"always_available": true, "capacity": "medium", "priority": 2},
	"node2": {"always_available": true, "capacity": "medium", "priority": 3},
	"node3": {"always_available": false, "capacity": "medium", "priority": 4},
	"node5": {"always_available": false, "capacity": "low", "priority": 5, "device": "Redmi Note 11S"},
	"node7": {"always_available": true, "capacity": "high", "priority": 1},
}

type JobDispatcher struct{}

// Bewertet Job-Gewicht
func (jd *JobDispatcher) GetJobWeight(scriptPath string, targetLangsCount int) string {
	info, err := os.Stat(scriptPath)
	if os.IsNotExist(err) {
		return "medium"
	}
	
	scriptSize := info.Size()
	totalWork := scriptSize * int64(targetLangsCount)
	
	if totalWork > 50000 { // > 50KB
		return "heavy"
	} else if totalWork > 10000 { // > 10KB
		return "medium"
	} else {
		return "light"
	}
}

// Wählt besten Node basierend auf Job-Gewicht
func (jd *JobDispatcher) SelectNode(jobWeight string) string {
	var preferred []string
	
	if jobWeight == "heavy" {
		// Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
		preferred = []string{"node7", "node2", "node1"}
	} else if jobWeight == "medium" {
		// Mittlere Jobs → Stable Nodes
		preferred = []string{"node2", "node1", "node7"}
	} else { // light
		// Leichte Jobs → Mobile/verfügbare Nodes
		preferred = []string{"node5", "node1", "node2"}
	}
	
	// Prüfe Verfügbarkeit
	for _, nodeID := range preferred {
		if jd.CheckNodeAvailable(nodeID) {
			return nodeID
		}
	}
	
	// Fallback
	return "node1"
}

// Prüft ob Node erreichbar ist
func (jd *JobDispatcher) CheckNodeAvailable(nodeID string) bool {
	node, exists := NODES[nodeID]
	if !exists {
		return false
	}
	
	// Nicht immer-verfügbare Nodes nur wenn explizit requested
	if alwaysAvailable, ok := node["always_available"].(bool); !ok || !alwaysAvailable {
		// Für light-jobs prüfen wir ob online
		if nodeID == "node5" { // Redmi
			return jd.checkMobileOnline()
		}
		return false
	}
	
	// Für immer-verfügbare Nodes: prüfe ob wirklich online
	cmd := exec.Command("openclaw", "nodes", "status", nodeID)
	cmd.Stdout = nil
	cmd.Stderr = nil
	
	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()
	
	select {
	case err := <-done:
		if err != nil {
			// Timeout or other error
			if alwaysAvailable, ok := node["always_available"].(bool); ok {
				return alwaysAvailable
			}
			return false
		}
		return true
	case <-time.After(3 * time.Second):
		// Timeout
		if alwaysAvailable, ok := node["always_available"].(bool); ok {
			return alwaysAvailable
		}
		return false
	}
}

// Prüft ob Redmi (Node 5) Internet hat
func (jd *JobDispatcher) checkMobileOnline() bool {
	cmd := exec.Command("openclaw", "nodes", "status", "node5")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	
	return strings.Contains(strings.ToLower(string(output)), "online")
}

// Dispatched Job und gibt Info zurück
func (jd *JobDispatcher) Dispatch(jobScript string, targetLangs []string) map[string]interface{} {
	if targetLangs == nil {
		targetLangs = []string{"perl5"}
	}
	
	weight := jd.GetJobWeight(jobScript, len(targetLangs))
	selectedNode := jd.SelectNode(weight)
	
	return map[string]interface{}{
		"job":          jobScript,
		"weight":       weight,
		"selected_node": selectedNode,
		"target_langs": targetLangs,
		"status":       "dispatched",
	}
}

func main() {
	var jobPath string
	var langs string
	var weight string
	var execute bool
	
	flag.StringVar(&jobPath, "job", "", "Path to job script")
	flag.StringVar(&jobPath, "j", "", "Path to job script")
	flag.StringVar(&langs, "langs", "perl5", "Comma-separated target languages")
	flag.StringVar(&langs, "l", "perl5", "Comma-separated target languages")
	flag.StringVar(&weight, "weight", "", "Force job weight")
	flag.StringVar(&weight, "w", "", "Force job weight")
	flag.BoolVar(&execute, "execute", false, "Actually execute on selected node")
	flag.BoolVar(&execute, "x", false, "Actually execute on selected node")
	
	flag.Parse()
	
	if jobPath == "" {
		fmt.Println("❌ Job path is required")
		os.Exit(1)
	}
	
	if _, err := os.Stat(jobPath); os.IsNotExist(err) {
		fmt.Printf("❌ Job not found: %s\n", jobPath)
		os.Exit(1)
	}
	
	dispatcher := &JobDispatcher{}
	targetLangs := strings.Split(langs, ",")
	
	// Determine weight
	if weight == "" {
		weight = dispatcher.GetJobWeight(jobPath, len(targetLangs))
	}
	
	// Select node
	selectedNode := dispatcher.SelectNode(weight)
	
	// Output
	fmt.Println("📦 Job Dispatch Information")
	fmt.Println("==================================================")
	
	info, _ := os.Stat(jobPath)
	fmt.Printf("Job: %s\n", jobPath)
	fmt.Printf("Size: %d bytes\n", info.Size())
	fmt.Printf("Target langs: %s\n", strings.Join(targetLangs, ", "))
	fmt.Printf("Job weight: %s\n", weight)
	fmt.Printf("Selected node: %s\n", selectedNode)
	fmt.Println("==================================================")
	
	if execute {
		fmt.Printf("\n🚀 Executing on %s...\n", selectedNode)
		// TODO: Implement remote execution
		fmt.Println("(Remote execution not yet implemented)")
	} else {
		executable, _ := os.Executable()
		fmt.Printf("\n💡 To execute: %s --job %s --execute\n", filepath.Base(executable), jobPath)
	}
}
