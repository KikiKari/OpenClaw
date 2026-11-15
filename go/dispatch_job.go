// abstraction-provenance: {"artifact_sha256": "4cff3c658449192eab9913d334b6379194a2447304c45d5205e165079cdfbf19", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "go"}
// dispatch_job.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Job Dispatcher - Verteilt Jobs auf passende Nodes
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
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/spf13/cobra"
)

// Node configuration
var NODES = map[string]map[string]interface{}{
	"node1": {"always_available": true, "capacity": "medium", "priority": 3, "description": "Gateway"},
	"node2": {"always_available": false, "capacity": "high", "priority": 1, "description": "ARM Server"},
	"node3": {"always_available": false, "capacity": "medium", "priority": 4, "description": "AMD Server"},
	"node4": {"always_available": false, "capacity": "low", "priority": 5, "device": "Redmi Note 11S"},
	"node5": {"always_available": false, "capacity": "high", "priority": 2, "device": "Lenovo"},
	"node6": {"always_available": false, "device": "Lenovo (Docker)"},
}

var NODE_NAMES = map[string]map[string]bool{
	"node2": {"openclaw-node2": true, "arm64-node": true, "v2202604104722449961": true, "v2202604104722449961.taild25fea.ts.net": true, "100.82.198.122": true},
	"node3": {"openclaw-node3": true, "openclaw-node3.taild25fea.ts.net": true, "100.73.154.125": true},
	"node4": {"openclaw-node4": true, "redmi-note-11s": true, "redmi-note-11s.taild25fea.ts.net": true, "100.94.134.39": true},
	"node5": {"openclaw-node5": true, "windows node (lenovo-7)": true},
	"node6": {"openclaw-node6": true},
}

func jobWeightBytes(scriptPath string, targetLangsCount int) int64 {
	stat, err := os.Stat(scriptPath)
	if err != nil {
		return 0
	}
	return stat.Size() * int64(targetLangsCount)
}

type NodeStatus struct {
	Nodes []struct {
		DisplayName string `json:"displayName"`
		NodeId      string `json:"nodeId"`
		RemoteIp    string `json:"remoteIp"`
		Connected   bool   `json:"connected"`
	} `json:"nodes"`
}

func fetchNodeStatus() (map[string]bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "openclaw", "nodes", "status", "--json")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	var status NodeStatus
	err = json.Unmarshal(out.Bytes(), &status)
	if err != nil {
		return nil, err
	}

	states := make(map[string]bool)
	for node := range NODE_NAMES {
		states[node] = false
	}

	for _, item := range status.Nodes {
		names := map[string]bool{
			strings.ToLower(item.DisplayName): true,
			strings.ToLower(item.NodeId):       true,
			strings.ToLower(item.RemoteIp):     true,
		}
		for node, aliases := range NODE_NAMES {
			for alias := range aliases {
				if names[alias] && item.Connected {
					states[node] = true
					break
				}
			}
		}
	}
	states["node1"] = true // successful Gateway status request
	return states, nil
}

type JobDispatcher struct{}

func (jd *JobDispatcher) GetJobWeight(scriptPath string, targetLangsCount int) string {
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		return "medium"
	}

	totalWork := jobWeightBytes(scriptPath, targetLangsCount)

	if totalWork > 50000 { // > 50KB
		return "heavy"
	} else if totalWork > 10000 { // > 10KB
		return "medium"
	} else {
		return "light"
	}
}

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
		return "", fmt.Errorf("Unknown job weight: %s", jobWeight)
	}

	states, err := fetchNodeStatus()
	if err != nil {
		return "", err
	}

	for _, nodeId := range preferred {
		if val, exists := states[nodeId]; exists && val {
			return nodeId, nil
		}
	}
	return "", nil // no verified reachable node
}

func (jd *JobDispatcher) CheckNodeAvailable(nodeId string) (bool, error) {
	states, err := fetchNodeStatus()
	if err != nil {
		return false, err
	}
	if val, exists := states[nodeId]; exists {
		return val, nil
	}
	return false, nil
}

func (jd *JobDispatcher) CheckMobileOnline() (bool, error) {
	return jd.CheckNodeAvailable("node4")
}

type Job struct {
	JobID          string `json:"job_id"`
	Source         string `json:"source"`
	TargetLanguage string `json:"target_language"`
	SelectedNode   string `json:"selected_node"`
	SourceText     string `json:"source_text,omitempty"`
	SourceLanguage string `json:"source_language,omitempty"`
}

type TransportFunc func(job map[string]interface{}) (map[string]interface{}, error)

func executeTranslation(job map[string]interface{}, transport TransportFunc) (string, error) {
	if job["selected_node"] == nil || transport == nil {
		return "", fmt.Errorf("no verified node or authorized translation transport")
	}
	response, err := transport(job)
	if err != nil {
		return "", err
	}
	
	for _, key := range []string{"job_id", "selected_node", "target_language"} {
		if response[key] != job[key] {
			return "", fmt.Errorf("transport response does not match job")
		}
	}
	
	code, ok := response["code"].(string)
	if !ok || strings.TrimSpace(code) == "" {
		return "", fmt.Errorf("translation did not complete with code")
	}
	
	status, ok := response["status"].(string)
	if !ok || status != "ok" {
		return "", fmt.Errorf("translation did not complete successfully")
	}
	
	return code, nil
}

func (jd *JobDispatcher) Dispatch(jobScript string, targetLangs []string, sourceText, sourceLanguage *string) (map[string]interface{}, error) {
	if targetLangs == nil {
		targetLangs = []string{"perl5"}
	}

	weight := jd.GetJobWeight(jobScript, len(targetLangs))
	selectedNode, err := jd.SelectNode(weight)
	if err != nil {
		return nil, err
	}

	var translationJobs []map[string]interface{}
	for _, language := range targetLangs {
		job := map[string]interface{}{
			"job_id":          uuid.New().String(),
			"source":          jobScript,
			"target_language": language,
			"selected_node":   selectedNode,
		}
		if sourceText != nil {
			job["source_text"] = *sourceText
		}
		if sourceLanguage != nil {
			job["source_language"] = *sourceLanguage
		}
		translationJobs = append(translationJobs, job)
	}

	status := "selected"
	if selectedNode == "" {
		status = "unavailable"
	}

	result := map[string]interface{}{
		"job":              jobScript,
		"weight":           weight,
		"selected_node":    selectedNode,
		"target_langs":     targetLangs,
		"translation_jobs": translationJobs,
		"status":           status,
	}

	return result, nil
}

func dispatchAbstractionJob(jobScript string, targetLangs []string) (map[string]interface{}, error) {
	dispatcher := &JobDispatcher{}
	return dispatcher.Dispatch(jobScript, targetLangs, nil, nil)
}

func main() {
	var rootCmd = &cobra.Command{
		Use:   "dispatch-job",
		Short: "Dispatch job to optimal node",
		RunE: func(cmd *cobra.Command, args []string) error {
			jobPath, _ := cmd.Flags().GetString("job")
			langs, _ := cmd.Flags().GetString("langs")
			weightFlag, _ := cmd.Flags().GetString("weight")
			execute, _ := cmd.Flags().GetBool("execute")

			if _, err := os.Stat(jobPath); os.IsNotExist(err) {
				fmt.Printf("❌ Job not found: %s\n", jobPath)
				os.Exit(1)
			}

			dispatcher := &JobDispatcher{}
			targetLangs := strings.Split(langs, ",")

			var weight string
			if weightFlag != "" {
				weight = weightFlag
			} else {
				weight = dispatcher.GetJobWeight(jobPath, len(targetLangs))
			}

			selectedNode, err := dispatcher.SelectNode(weight)
			if err != nil {
				return err
			}

			fmt.Println("📦 Job Dispatch Information")
			fmt.Println("==================================================")
			fmt.Printf("Job: %s\n", jobPath)
			
			if stat, err := os.Stat(jobPath); err == nil {
				fmt.Printf("Size: %d bytes\n", stat.Size())
			}
			fmt.Printf("Target langs: %s\n", strings.Join(targetLangs, ", "))
			fmt.Printf("Job weight: %s\n", weight)
			fmt.Printf("Selected node: %s\n", selectedNode)
			fmt.Println("==================================================")

			if execute {
				fmt.Fprintf(os.Stderr, "\nTranslation dispatch on %s is not implemented.\n", selectedNode)
				os.Exit(1)
			} else {
				executable, _ := os.Executable()
				fmt.Printf("\n💡 To execute: %s --job %s --execute\n", filepath.Base(executable), jobPath)
			}
			return nil
		},
	}

	rootCmd.Flags().StringP("job", "j", "", "Path to job script")
	rootCmd.Flags().StringP("langs", "l", "perl5", "Comma-separated target languages")
	rootCmd.Flags().StringP("weight", "w", "", "Force job weight (light|medium|heavy)")
	rootCmd.Flags().BoolP("execute", "x", false, "Actually execute on selected node")
	
	rootCmd.MarkFlagRequired("job")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
