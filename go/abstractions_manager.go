// abstraction-provenance: {"artifact_sha256": "479ac61359bad5bf4b94c4e187a088f4d7ccb34e965cdd9bfcb8cf2951cd396c", "source_sha256": "b4ecb634df9abcb3ea24bb1e77312cf63d5b68316b035fcee5ca400dc06e5200", "target_language": "go"}
// abstractions_manager.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Script Abstractions Manager - Multi-Node Edition
*/

package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Konfiguration
var (
	WORKSPACE         = "/home/openclaw/.openclaw/workspace"
	ABSTRACTIONS_REPO = filepath.Join(WORKSPACE, "git", "Abstraktionen")
	LOG_DIR           = filepath.Join(WORKSPACE, "logs", "abstractions-manager")
	STATE_FILE        = filepath.Join(WORKSPACE, "db", "abstractions_state.json")
)

// Node-Konfiguration mit Prioritäten
type NodeConfig struct {
	AlwaysAvailable bool   `json:"always_available"`
	Capacity        string `json:"capacity"`
	Priority        int    `json:"priority"`
	Device          string `json:"device,omitempty"`
	Condition       string `json:"condition,omitempty"`
}

var NODES = map[string]NodeConfig{
	"node1": {"true", "medium", 2, "", ""}, // Gateway-Master
	"node2": {"true", "medium", 3, "", ""}, // Stable Worker
	"node3": {"false", "medium", 4, "", ""}, // Bald verfügbar
	"node5": {"false", "low", 5, "Redmi Note 11S", "mobile_internet"}, // Mobile Node
	"node7": {"true", "high", 1, "", ""},   // Docker Hauptarbeitspferd
}

var AVAILABLE_MODELS = []string{
	"openrouter/moonshotai/kimi-k2.5",
	"openrouter/openai/gpt-4o",
	"openrouter/anthropic/claude-3-5-sonnet-20241022",
	"openrouter/google/gemini-2.0-flash-001",
	"openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
	"openrouter/qwen/qwen-2.5-coder-32b-instruct",
}

type TargetLanguage struct {
	Ext     string
	Shebang string
	Header  string
}

var TARGET_LANGUAGES = map[string]TargetLanguage{
	"perl5":      {".pl", "#!/usr/bin/env perl", "use strict;\nuse warnings;\n"},
	"perl6":      {".raku", "#!/usr/bin/env raku", "use v6;\n"},
	"javascript": {".js", "#!/usr/bin/env node", ""},
	"python":     {".py", "#!/usr/bin/env python3", ""},
	"shell":      {".sh", "#!/bin/bash", "set -euo pipefail\n"},
	"powershell": {".ps1", "#!/usr/bin/env pwsh", "#Requires -Version 7\n"},
	"tcl":        {".tcl", "#!/usr/bin/env tclsh", "package require Tcl 8.6\n"},
	"ruby":       {".rb", "#!/usr/bin/env ruby", "require 'json'\nrequire 'fileutils'\n"},
	"lua":        {".lua", "#!/usr/bin/env lua", ""},
	"go":         {".go", "// +build ignore", "package main\n"},
}

type State struct {
	Processed       map[string]interface{} `json:"processed"`
	Queue           []interface{}          `json:"queue"`
	CurrentPriority string                 `json:"current_priority"`
	Stats           map[string]interface{} `json:"stats"`
}

func logMessage(message string, level string) {
	os.MkdirAll(LOG_DIR, 0755)
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] [%s] %s", timestamp, level, message)
	fmt.Println(line)
	
	logFile := filepath.Join(LOG_DIR, time.Now().Format("2006-01-02")+".log")
	f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	f.WriteString(line + "\n")
}

func getNodeByPriority(jobWeight string) string {
	var preferredOrder []string
	
	// Prioritäts-Matrix
	if jobWeight == "heavy" {
		// Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
		preferredOrder = []string{"node7", "node2", "node1"}
	} else if jobWeight == "medium" {
		// Mittlere Jobs → Stable Nodes
		preferredOrder = []string{"node2", "node1", "node7"}
	} else { // light
		// Leichte Jobs → Mobile/verfügbare Nodes
		preferredOrder = []string{"node5", "node1", "node2"}
	}
	
	// Prüfe Verfügbarkeit
	for _, nodeID := range preferredOrder {
		if _, exists := NODES[nodeID]; !exists {
			continue
		}
		
		node := NODES[nodeID]
		
		// Skip nicht immer verfügbare Nodes wenn nicht explizit requested
		if !node.AlwaysAvailable && jobWeight != "light" {
			continue
		}
		
		// Prüfe ob Node online
		if checkNodeStatus(nodeID) {
			return nodeID
		}
	}
	
	// Fallback zu Node 1
	return "node1"
}

func checkNodeStatus(nodeID string) bool {
	cmd := exec.Command("openclaw", "nodes", "status", nodeID)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	
	err := cmd.Start()
	if err != nil {
		// Bei Timeout/Error: Prüfe letzten bekannten Status
		if node, exists := NODES[nodeID]; exists {
			return node.AlwaysAvailable
		}
		return false
	}
	
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()
	
	select {
	case <-time.After(5 * time.Second):
		// Timeout
		if node, exists := NODES[nodeID]; exists {
			return node.AlwaysAvailable
		}
		return false
	case err := <-done:
		if err != nil {
			// Bei Timeout/Error: Prüfe letzten bekannten Status
			if node, exists := NODES[nodeID]; exists {
				return node.AlwaysAvailable
			}
			return false
		}
		output := strings.ToLower(out.String())
		return strings.Contains(output, "online") || strings.Contains(output, "active")
	}
}

func getJobWeight(scriptSize int64, targetLangsCount int) string {
	totalWork := scriptSize * int64(targetLangsCount)
	
	if totalWork > 50000 { // Große Scripts, viele Sprachen
		return "heavy"
	} else if totalWork > 10000 { // Mittlere Last
		return "medium"
	} else {
		return "light"
	}
}

func loadState() State {
	state := State{
		Processed:       make(map[string]interface{}),
		Queue:           []interface{}{},
		CurrentPriority: "high",
		Stats:           map[string]interface{}{"total_scripts": 0, "abstractions_created": 0},
	}
	
	if _, err := os.Stat(STATE_FILE); err == nil {
		data, err := os.ReadFile(STATE_FILE)
		if err == nil {
			json.Unmarshal(data, &state)
		}
	}
	
	return state
}

func saveState(state State) {
	os.MkdirAll(filepath.Dir(STATE_FILE), 0755)
	data, _ := json.MarshalIndent(state, "", "  ")
	os.WriteFile(STATE_FILE, data, 0644)
}

func findScriptsInDir(directory string, excludePatterns []string) []string {
	if excludePatterns == nil {
		excludePatterns = []string{"node_modules", ".git", "__pycache__", "dist", "build"}
	}
	
	var scripts []string
	if _, err := os.Stat(directory); err == nil {
		filepath.WalkDir(directory, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			
			if d.IsDir() {
				// Check if directory should be excluded
				for _, pattern := range excludePatterns {
					if strings.Contains(path, pattern) {
						return filepath.SkipDir
					}
				}
				return nil
			}
			
			ext := filepath.Ext(path)
			validExts := []string{".py", ".js", ".sh", ".pl", ".rb"}
			for _, validExt := range validExts {
				if ext == validExt {
					scripts = append(scripts, path)
					break
				}
			}
			
			return nil
		})
	}
	
	return scripts
}

func createAbstraction(scriptPath string, targetLang string) bool {
	content, err := os.ReadFile(scriptPath)
	if err != nil {
		logMessage(fmt.Sprintf("Failed: %s - %v", scriptPath, err), "ERROR")
		return false
	}
	
	originalContent := string(content)
	ext := filepath.Ext(scriptPath)
	if len(ext) > 0 {
		ext = ext[1:] // Remove the dot
	}
	
	sourceLangMap := map[string]string{
		"py": "Python",
		"js": "JavaScript",
		"sh": "Shell",
		"pl": "Perl",
		"rb": "Ruby",
	}
	
	sourceLang := sourceLangMap[ext]
	if sourceLang == "" {
		sourceLang = ext
	}
	
	targetDir := filepath.Join(ABSTRACTIONS_REPO, targetLang)
	os.MkdirAll(targetDir, 0755)
	
	template := TARGET_LANGUAGES[targetLang]
	targetFile := filepath.Join(targetDir, filepath.Base(scriptPath[:len(scriptPath)-len(filepath.Ext(scriptPath))])+template.Ext)
	
	if _, err := os.Stat(targetFile); err == nil {
		return false
	}
	
	lines := strings.Split(originalContent, "\n")
	if len(lines) > 15 {
		lines = lines[:15]
	}
	
	headerComment := ""
	if template.Header != "" {
		headerComment = template.Header + "\n"
	}
	
	newContent := fmt.Sprintf(`%s
# %s - %s Version
# Portiert von %s
# Original: %s
# Erstellt: %s
#
%s
# Original-Code-Referenz:
# %s

func main() {
	// TODO: Implementiere %s Funktionalität in %s
	pass
}

if __name__ == "__main__" {
	main()
}`, 
		template.Shebang,
		strings.TrimSuffix(filepath.Base(scriptPath), filepath.Ext(scriptPath)),
		strings.Title(targetLang),
		sourceLang,
		scriptPath,
		time.Now().Format("2006-01-02"),
		headerComment,
		strings.Join(lines, "\n# "),
		sourceLang,
		strings.Title(targetLang))
	
	err = os.WriteFile(targetFile, []byte(newContent), 0644)
	if err != nil {
		logMessage(fmt.Sprintf("Failed: %s - %v", scriptPath, err), "ERROR")
		return false
	}
	
	logMessage(fmt.Sprintf("Created: %s", targetFile), "INFO")
	return true
}

func processOnNode(nodeID string, scripts []string, targetLangs []string) int {
	created := 0
	
	if nodeID == "node1" {
		// Lokale Verarbeitung
		for _, script := range scripts {
			for _, lang := range targetLangs {
				if createAbstraction(script, lang) {
					created++
				}
			}
		}
	} else {
		// Remote-Verarbeitung
		logMessage(fmt.Sprintf("Dispatching %d jobs to %s", len(scripts), nodeID), "INFO")
		// TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
		// Für jetzt: Lokale Verarbeitung mit Node-Logging
		for _, script := range scripts {
			for _, lang := range targetLangs {
				if createAbstraction(script, lang) {
					created++
					logMessage(fmt.Sprintf("Processed on %s: %s -> %s", nodeID, filepath.Base(script), lang), "INFO")
				}
			}
		}
	}
	
	return created
}

func processPriorityHigh() int {
	created := 0
	targets := [][]string{
		{"skill-creator", filepath.Join(WORKSPACE, "skills", "skill-creator", "scripts")},
		{"json-utils", filepath.Join(WORKSPACE, "skills", "json-utils", "scripts")},
		{"scripting-utils", filepath.Join(WORKSPACE, "skills", "scripting-utils", "scripts")},
		{"model-usage", filepath.Join(WORKSPACE, "skills", "model-usage", "scripts")},
		{"tiktok-live", filepath.Join(WORKSPACE, "skills", "tiktok-live", "scripts")},
	}
	
	for _, target := range targets {
		skillName := target[0]
		scriptsDir := target[1]
		
		excludePatterns := []string{"node_modules", ".git", "test", "tests"}
		scripts := findScriptsInDir(scriptsDir, excludePatterns)
		logMessage(fmt.Sprintf("%s: %d scripts found", skillName, len(scripts)), "INFO")
		
		// Limit für erste Durchläufe
		limit := 10
		if len(scripts) < limit {
			limit = len(scripts)
		}
		
		for i := 0; i < limit; i++ {
			script := scripts[i]
			scriptInfo, _ := os.Stat(script)
			var scriptSize int64
			if scriptInfo != nil {
				scriptSize = scriptInfo.Size()
			}
			
			targetLangs := []string{"perl5", "javascript", "python", "shell", "tcl"}
			jobWeight := getJobWeight(scriptSize, len(targetLangs))
			
			// Wähle Node basierend auf Job-Gewicht
			selectedNode := getNodeByPriority(jobWeight)
			logMessage(fmt.Sprintf("Processing %s (%s) on %s", filepath.Base(script), jobWeight, selectedNode), "INFO")
			
			created += processOnNode(selectedNode, []string{script}, targetLangs)
		}
	}
	
	return created
}

func processPriorityMedium() int {
	created := 0
	targets := [][]string{
		{"workspace-scripts", filepath.Join(WORKSPACE, "scripts")},
		{"db-maintainer", filepath.Join(WORKSPACE, "skills", "db-maintainer", "scripts")},
		{"log-collector", filepath.Join(WORKSPACE, "skills", "log-collector", "scripts")},
	}
	
	for _, target := range targets {
		dirName := target[0]
		scriptsDir := target[1]
		
		excludePatterns := []string{"node_modules", ".git"}
		scripts := findScriptsInDir(scriptsDir, excludePatterns)
		
		// Limit für erste Durchläufe
		limit := 10
		if len(scripts) < limit {
			limit = len(scripts)
		}
		
		for i := 0; i < limit; i++ {
			script := scripts[i]
			scriptInfo, _ := os.Stat(script)
			var scriptSize int64
			if scriptInfo != nil {
				scriptSize = scriptInfo.Size()
			}
			
			targetLangs := []string{"perl5", "javascript", "powershell", "python"}
			jobWeight := getJobWeight(scriptSize, len(targetLangs))
			
			// Mittlere Priority → eher leichtere Jobs
			priority := "medium"
			if jobWeight == "heavy" {
				priority = jobWeight
			}
			selectedNode := getNodeByPriority(priority)
			logMessage(fmt.Sprintf("Processing %s (%s) on %s", filepath.Base(script), jobWeight, selectedNode), "INFO")
			
			created += processOnNode(selectedNode, []string{script}, targetLangs)
		}
	}
	
	return created
}

func gitCommit(message string) {
	oldDir, _ := os.Getwd()
	os.Chdir(ABSTRACTIONS_REPO)
	
	cmd := exec.Command("git", "add", ".")
	cmd.Run()
	
	cmd = exec.Command("git", "commit", "-m", message)
	cmd.Run()
	
	os.Chdir(oldDir)
	logMessage(fmt.Sprintf("Git commit: %s", message), "INFO")
}

func createStatusReport(state State) {
	reportFile := filepath.Join(ABSTRACTIONS_REPO, "STATUS.md")
	langCounts := make(map[string]int)
	
	if _, err := os.Stat(ABSTRACTIONS_REPO); err == nil {
		entries, _ := os.ReadDir(ABSTRACTIONS_REPO)
		for _, entry := range entries {
			if entry.IsDir() {
				lang := entry.Name()
				if _, exists := TARGET_LANGUAGES[lang]; exists {
					files, _ := os.ReadDir(filepath.Join(ABSTRACTIONS_REPO, lang))
					count := 0
					for _, file := range files {
						if !file.IsDir() {
							count++
						}
					}
					langCounts[lang] = count
				}
			}
		}
	}
	
	f, err := os.Create(reportFile)
	if err != nil {
		return
	}
	defer f.Close()
	
	writer := bufio.NewWriter(f)
	fmt.Fprintf(writer, "# Script Abstractions - Status Report\n\n")
	fmt.Fprintf(writer, "**Letzte Aktualisierung:** %s\n\n", time.Now().Format("2006-01-02 15:04"))
	fmt.Fprintf(writer, "- Aktuelle Priorität: %s\n", state.CurrentPriority)
	fmt.Fprintf(writer, "- Verarbeitete Scripts: %d\n", len(state.Processed))
	
	abstractionsCreated := 0
	if val, ok := state.Stats["abstractions_created"]; ok {
		if count, err := strconv.Atoi(fmt.Sprintf("%v", val)); err == nil {
			abstractionsCreated = count
		}
	}
	fmt.Fprintf(writer, "- Abstraktionen gesamt: %d\n\n", abstractionsCreated)
	
	fmt.Fprintf(writer, "## Abstraktionen pro Sprache\n\n")
	keys := make([]string, 0, len(langCounts))
	for k := range langCounts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	
	for _, lang := range keys {
		fmt.Fprintf(writer, "- %s: %d\n", lang, langCounts[lang])
	}
	
	fmt.Fprintf(writer, "\n## Verfügbare Modelle\n\n")
	for i, model := range AVAILABLE_MODELS {
		if i < 3 {
			fmt.Fprintf(writer, "- `%s`\n", model)
		}
	}
	if len(AVAILABLE_MODELS) > 3 {
		fmt.Fprintf(writer, "- ... und %d weitere\n", len(AVAILABLE_MODELS)-3)
	}
	
	fmt.Fprintf(writer, "\n## Multi-Node Support\n\n")
	fmt.Fprintf(writer, "| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |\n")
	fmt.Fprintf(writer, "|------|---------------|-----------|-----------|-------|\n")
	
	nodeKeys := make([]string, 0, len(NODES))
	for k := range NODES {
		nodeKeys = append(nodeKeys, k)
	}
	sort.Strings(nodeKeys)
	
	for _, nodeID := range nodeKeys {
		config := NODES[nodeID]
		avail := "✅ Immer"
		if !config.AlwaysAvailable {
			avail = "📱 Bedingt"
		}
		device := "Server"
		if config.Device != "" {
			device = config.Device
		}
		fmt.Fprintf(writer, "| %s | %s | %s | %d | %s |\n", nodeID, avail, config.Capacity, config.Priority, device)
	}
	
	fmt.Fprintf(writer, "\n### Job-Verteilung\n\n")
	fmt.Fprintf(writer, "- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)\n")
	fmt.Fprintf(writer, "- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)\n")
	fmt.Fprintf(writer, "- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)\n")
	
	writer.Flush()
}

func main() {
	logMessage("Script Abstractions Manager (Multi-Node) gestartet", "INFO")
	
	state := loadState()
	logMessage(fmt.Sprintf("State loaded: %d processed", len(state.Processed)), "INFO")
	
	currentPriority := state.CurrentPriority
	if currentPriority == "" {
		currentPriority = "high"
	}
	
	created := 0
	
	if currentPriority == "high" {
		logMessage("Processing HIGH priority: Top 5 Skills", "INFO")
		created = processPriorityHigh()
		if created > 0 {
			gitCommit(fmt.Sprintf("High priority: %d abstractions", created))
		}
		state.CurrentPriority = "medium"
	} else if currentPriority == "medium" {
		logMessage("Processing MEDIUM priority: Workspace Scripts", "INFO")
		created = processPriorityMedium()
		if created > 0 {
			gitCommit(fmt.Sprintf("Medium priority: %d abstractions", created))
		}
		state.CurrentPriority = "high" // Zyklus
	}
	
	state.Stats["last_run"] = time.Now().Format(time.RFC3339)
	
	// Count abstractions
	totalAbstractions := 0
	if _, err := os.Stat(ABSTRACTIONS_REPO); err == nil {
		for lang := range TARGET_LANGUAGES {
			langDir := filepath.Join(ABSTRACTIONS_REPO, lang)
			if _, err := os.Stat(langDir); err == nil {
				files, _ := os.ReadDir(langDir)
				for _, file := range files {
					if !file.IsDir() {
						totalAbstractions++
					}
				}
			}
		}
	}
	state.Stats["abstractions_created"] = totalAbstractions
	
	saveState(state)
	createStatusReport(state)
	
	logMessage(fmt.Sprintf("Abgeschlossen. %d neue Abstraktionen erstellt.", created), "INFO")
}
