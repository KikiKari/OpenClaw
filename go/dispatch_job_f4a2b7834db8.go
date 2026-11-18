// abstraction-provenance: {"artifact_sha256": "39adde50a19cc4340669cde2cb84a71eed60641b1d050e56075a8dc45fb21f7a", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "go"}
// dispatch_job.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/*
Job Dispatcher - Verteilt Jobs auf passende Nodes
*/

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// NodeConfig represents the configuration of a node
type NodeConfig struct {
	AlwaysAvailable bool   `json:"always_available"`
	Capacity       string `json:"capacity,omitempty"`
	Priority       int    `json:"priority,omitempty"`
	Description    string `json:"description,omitempty"`
	Device         string `json:"device,omitempty"`
}

// NodeStatus represents the connection status of nodes
type NodeStatus map[string]bool

// Job represents a translation job
type Job struct {
	JobID          string `json:"job_id"`
	Source         string `json:"source"`
	TargetLanguage string `json:"target_language"`
	SelectedNode   string `json:"selected_node"`
	SourceText     string `json:"source_text,omitempty"`
	SourceLanguage string `json:"source_language,omitempty"`
}

// JobResponse represents the response from job execution
type JobResponse struct {
	JobID          string `json:"job_id"`
	SelectedNode   string `json:"selected_node"`
	TargetLanguage string `json:"target_language"`
	Status         string `json:"status"`
	Code           string `json:"code"`
}

// TransportFunc defines the function signature for job transport
type TransportFunc func(job Job) (JobResponse, error)

// jobWeightBytes calculates work volume: file size × number of target languages
func jobWeightBytes(scriptPath string, targetLangsCount int) (int64, error) {
	info, err := os.Stat(scriptPath)
	if err != nil {
		return 0, err
	}
	return info.Size() * int64(targetLangsCount), nil
}

// Node configuration
var NODES = map[string]NodeConfig{
	"node1": {"true", "medium", 3, "Gateway", ""},
	"node2": {"false", "high", 1, "ARM Server", ""},
	"node3": {"false", "medium", 4, "AMD Server", ""},
	"node4": {"false", "low", 5, "", "Redmi Note 11S"},
	"node5": {"false", "high", 2, "", "Lenovo"},
	"node6": {"false", "", 0, "", "Lenovo (Docker)"},
}

// Node names mapping
var NODE_NAMES = map[string][]string{
	"node2": {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"},
	"node3": {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"},
	"node4": {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"},
	"node5": {"openclaw-node5", "windows node (lenovo-7)"},
	"node6": {"openclaw-node6"},
}

// fetchNodeStatus returns mapped OpenClaw connection states; nil indicates lookup failure
func fetchNodeStatus() (NodeStatus, error) {
	cmd := exec.Command("openclaw", "nodes", "status", "--json")
	cmd.Stdout = nil
	cmd.Stderr = nil
	
	// Set timeout
	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()
	
	select {
	case <-time.After(10 * time.Second):
		return nil, fmt.Errorf("timeout")
	case err := <-done:
		if err != nil {
			return nil, err
		}
	}
	
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	
	var payload map[string]interface{}
	if err := json.Unmarshal(output, &payload); err != nil {
		return nil, err
	}
	
	nodes, ok := payload["nodes"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid payload structure")
	}
	
	states := make(NodeStatus)
	for node := range NODE_NAMES {
		states[node] = false
	}
	
	for _, item := range nodes {
		itemMap, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		
		names := make(map[string]bool)
		for _, key := range []string{"displayName", "nodeId", "remoteIp"} {
			if val, exists := itemMap[key]; exists {
				names[strings.ToLower(fmt.Sprintf("%v", val))] = true
			}
		}
		
		for node, aliases := range NODE_NAMES {
			for _, alias := range aliases {
				if names[strings.ToLower(alias)] {
					if connected, exists := itemMap["connected"]; exists {
						if connectedBool, ok := connected.(bool); ok && connectedBool {
							states[node] = true
						}
					}
					break
				}
			}
		}
	}
	
	// successful Gateway status request
	states["node1"] = true
	return states, nil
}

// JobDispatcher dispatches jobs to appropriate nodes based on weight
type JobDispatcher struct{}

// GetJobWeight bewertet Job-Gewicht
func (jd *JobDispatcher) GetJobWeight(scriptPath string, targetLangsCount int) (string, error) {
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		return "medium", nil
	}
	
	totalWork, err := jobWeightBytes(scriptPath, targetLangsCount)
	if err != nil {
		return "", err
	}
	
	if totalWork > 50000 { // > 50KB
		return "heavy", nil
	} else if totalWork > 10000 { // > 10KB
		return "medium", nil
	} else {
		return "light", nil
	}
}

// SelectNode wählt besten Node basierend auf Job-Gewicht
func (jd *JobDispatcher) SelectNode(jobWeight string) (string, error) {
	var preferred []string
	
	switch jobWeight {
	case "heavy":
		preferred = []string{"node1", "node2", "node5", "node6"}
	case "medium":
		preferred = []string{"node1", "node2", "node3", "node6"}
	case "light":
		preferred = []string{"node2", "node1", "node3", "node4"}
	default:
		return "", fmt.Errorf("unknown job weight: %s", jobWeight)
	}
	
	states, err := fetchNodeStatus()
	if err != nil {
		return "", nil // no verified reachable node
	}
	
	for _, nodeID := range preferred {
		if state, exists := states[nodeID]; exists && state {
			return nodeID, nil
		}
	}
	
	return "", nil // no verified reachable node
}

// CheckNodeAvailable uses the live connection state rather than static availability
func (jd *JobDispatcher) CheckNodeAvailable(nodeID string) (bool, error) {
	states, err := fetchNodeStatus()
	if err != nil {
		return false, err
	}
	
	if state, exists := states[nodeID]; exists {
		return state, nil
	}
	return false, nil
}

// CheckMobileOnline checks Node4 (Redmi)
func (jd *JobDispatcher) CheckMobileOnline() (bool, error) {
	return jd.CheckNodeAvailable("node4")
}

// ExecuteTranslation executes via a supplied transport and verify its result belongs to the job
func (jd *JobDispatcher) ExecuteTranslation(job Job, transport TransportFunc) (string, error) {
	if job.SelectedNode == "" || transport == nil {
		return "", fmt.Errorf("no verified node or authorized translation transport")
	}
	
	response, err := transport(job)
	if err != nil {
		return "", err
	}
	
	if response.JobID != job.JobID ||
		response.SelectedNode != job.SelectedNode ||
		response.TargetLanguage != job.TargetLanguage {
		return "", fmt.Errorf("transport response does not match job")
	}
	
	if response.Status != "ok" || response.Code == "" || strings.TrimSpace(response.Code) == "" {
		return "", fmt.Errorf("translation did not complete with code")
	}
	
	return response.Code, nil
}

// Dispatch dispatched Job und gibt Info zurück
func (jd *JobDispatcher) Dispatch(jobScript string, targetLangs []string, sourceText string, sourceLanguage string) (map[string]interface{}, error) {
	if targetLangs == nil {
		targetLangs = []string{"perl5"}
	}
	
	weight, err := jd.GetJobWeight(jobScript, len(targetLangs))
	if err != nil {
		return nil, err
	}
	
	selectedNode, err := jd.SelectNode(weight)
	if err != nil {
		return nil, err
	}
	
	var translationJobs []Job
	for _, language := range targetLangs {
		job := Job{
			JobID:          generateUUID(),
			Source:         jobScript,
			TargetLanguage: language,
			SelectedNode:   selectedNode,
		}
		
		if sourceText != "" {
			job.SourceText = sourceText
		}
		
		if sourceLanguage != "" {
			job.SourceLanguage = sourceLanguage
		}
		
		translationJobs = append(translationJobs, job)
	}
	
	status := "unavailable"
	if selectedNode != "" {
		status = "selected"
	}
	
	return map[string]interface{}{
		"job":              jobScript,
		"weight":           weight,
		"selected_node":    selectedNode,
		"target_langs":     targetLangs,
		"translation_jobs": translationJobs,
		"status":           status,
	}, nil
}

// generateUUID generates a UUID string (simplified version)
func generateUUID() string {
	// This is a simplified UUID generation - in production you might want to use a proper UUID library
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		time.Now().UnixNano()&0xFFFFFFFF,
		time.Now().UnixNano()>>32&0xFFFF,
		time.Now().UnixNano()>>16&0xFFFF,
		time.Now().UnixNano()&0xFFFF,
		time.Now().UnixNano()&0xFFFFFFFFFFFF)
}

// dispatchAbstractionJob erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag
func dispatchAbstractionJob(jobScript string, targetLangs []string) (map[string]interface{}, error) {
	dispatcher := JobDispatcher{}
	return dispatcher.Dispatch(jobScript, targetLangs, "", "")
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: dispatch_job.go [--job|-j JOB] [--langs|-l LANGS] [--weight|-w WEIGHT] [--execute|-x]")
		os.Exit(1)
	}
	
	var jobPath string
	var langs string
	var weight string
	execute := false
	
	// Simple argument parsing
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--job", "-j":
			if i+1 < len(os.Args) {
				jobPath = os.Args[i+1]
				i++
			}
		case "--langs", "-l":
			if i+1 < len(os.Args) {
				langs = os.Args[i+1]
				i++
			} else {
				langs = "perl5"
			}
		case "--weight", "-w":
			if i+1 < len(os.Args) {
				weight = os.Args[i+1]
				i++
			}
		case "--execute", "-x":
			execute = true
		}
	}
	
	if jobPath == "" {
		fmt.Println("❌ Job path is required")
		os.Exit(1)
	}
	
	if _, err := os.Stat(jobPath); os.IsNotExist(err) {
		fmt.Printf("❌ Job not found: %s\n", jobPath)
		os.Exit(1)
	}
	
	dispatcher := JobDispatcher{}
	var targetLangs []string
	
	if langs != "" {
		targetLangs = strings.Split(langs, ",")
		for i := range targetLangs {
			targetLangs[i] = strings.TrimSpace(targetLangs[i])
		}
	} else {
		targetLangs = []string{"perl5"}
	}
	
	// Determine weight
	var jobWeight string
	var err error
	if weight != "" {
		jobWeight = weight
	} else {
		jobWeight, err = dispatcher.GetJobWeight(jobPath, len(targetLangs))
		if err != nil {
			fmt.Printf("Error determining job weight: %v\n", err)
			os.Exit(1)
		}
	}
	
	// Select node
	selectedNode, err := dispatcher.SelectNode(jobWeight)
	if err != nil {
		fmt.Printf("Error selecting node: %v\n", err)
		os.Exit(1)
	}
	
	// Get file size
	fileInfo, err := os.Stat(jobPath)
	if err != nil {
		fmt.Printf("Error getting file info: %v\n", err)
		os.Exit(1)
	}
	
	// Output
	fmt.Println("📦 Job Dispatch Information")
	fmt.Println("==================================================")
	fmt.Printf("Job: %s\n", jobPath)
	fmt.Printf("Size: %d bytes\n", fileInfo.Size())
	fmt.Printf("Target langs: %s\n", strings.Join(targetLangs, ", "))
	fmt.Printf("Job weight: %s\n", jobWeight)
	fmt.Printf("Selected node: %s\n", selectedNode)
	fmt.Println("==================================================")
	
	if execute {
		fmt.Printf("\nTranslation dispatch on %s is not implemented.\n", selectedNode)
		os.Exit(1)
	} else {
		fmt.Printf("\n💡 To execute: go run %s --job %s --execute\n", os.Args[0], jobPath)
	}
}
