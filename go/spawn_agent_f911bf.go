// abstraction-provenance: {"artifact_sha256": "680e5f7979fce4d0bcc46ac75cbcd258445b88000cb8ce1f2734a4b2b78e7937", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "go"}
// spawn_agent.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

/*
Sub-Agent spawner - Einfache CLI für sessions_spawn
*/

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var WORKSPACE = "/home/openclaw/.openclaw/workspace"

// Verfügbare Modelle - hier simuliert da keine Python-Bibliothek vorhanden
func configuredModels() []string {
	return []string{
		"openrouter/anthropic/claude-haiku-4.5",
		"openrouter/google/gemini-pro",
		"openai/gpt-4",
	}
}

type SubAgentSpawner struct{}

func (s *SubAgentSpawner) GetSpawnConfig(
	task string,
	label string,
	model string,
	thinking string,
	timeout int,
	thread bool,
	mode string,
	models []string,
) map[string]interface{} {
	config := make(map[string]interface{})
	config["task"] = task

	if label != "" {
		config["label"] = label
	}
	
	// Check if model is in models list
	modelFound := false
	for _, m := range models {
		if m == model {
			modelFound = true
			break
		}
	}
	
	if model != "" && modelFound {
		config["model"] = model
	}
	
	if thinking != "" {
		config["thinking"] = thinking
	}
	
	if timeout != 0 {
		config["runTimeoutSeconds"] = timeout
	}
	
	if thread {
		config["thread"] = true
		if mode == "run" {
			config["mode"] = "session" // thread requires session mode
		}
	} else {
		config["mode"] = mode
	}
	
	return config
}

func (s *SubAgentSpawner) PrintSpawnCommand(config map[string]interface{}) {
	fmt.Println("\n🛠️  Tool-Aufruf:")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("sessions_spawn(")
	
	// Sort keys for consistent output
	keys := make([]string, 0, len(config))
	for k := range config {
		keys = append(keys, k)
	}
	
	for _, key := range keys {
		value := config[key]
		switch v := value.(type) {
		case string:
			fmt.Printf("    %s=\"%s\"\n", key, v)
		default:
			fmt.Printf("    %s=%v\n", key, v)
		}
	}
	fmt.Println(")")
	fmt.Println(strings.Repeat("=", 50))
}

func (s *SubAgentSpawner) PrintSlashCommand(config map[string]interface{}) {
	task := ""
	if t, ok := config["task"].(string); ok {
		task = t
	}
	
	label := "agent"
	if l, ok := config["label"].(string); ok && l != "" {
		label = l
	}
	
	model := ""
	if m, ok := config["model"].(string); ok {
		model = m
	}
	
	cmd := fmt.Sprintf("/subagents spawn %s \"%s\"", label, task)
	if model != "" {
		cmd += fmt.Sprintf(" --model %s", model)
	}
	if thinking, ok := config["thinking"].(string); ok && thinking != "" {
		cmd += fmt.Sprintf(" --thinking %s", thinking)
	}
	
	fmt.Println("\n💬 Slash Command:")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println(cmd)
	fmt.Println(strings.Repeat("=", 50))
}

func main() {
	args := os.Args[1:]
	
	// Default values
	timeout := 900
	mode := "run"
	output := "tool"
	models := configuredModels()
	
	// Parse arguments manually since we don't have a full flag library
	var task, label, model, thinking string
	thread := false
	
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--task", "-t":
			if i+1 < len(args) {
				task = args[i+1]
				i++
			}
		case "--label", "-l":
			if i+1 < len(args) {
				label = args[i+1]
				i++
			}
		case "--model", "-m":
			if i+1 < len(args) {
				model = args[i+1]
				i++
			}
		case "--thinking":
			if i+1 < len(args) {
				thinking = args[i+1]
				i++
			}
		case "--timeout":
			if i+1 < len(args) {
				fmt.Sscanf(args[i+1], "%d", &timeout)
				i++
			}
		case "--thread":
			thread = true
		case "--mode":
			if i+1 < len(args) {
				mode = args[i+1]
				i++
			}
		case "--output", "-o":
			if i+1 < len(args) {
				output = args[i+1]
				i++
			}
		case "--help", "-h":
			fmt.Println(`Sub-Agent Spawn Helper

Usage:
  spawn_agent [options]

Options:
  --task, -t TASK       Aufgabenbeschreibung
  --label, -l LABEL     Optionaler Label
  --model, -m MODEL     KI-Modell
  --thinking THINKING   Thinking Level (low, medium, high)
  --timeout TIMEOUT     Timeout in Sekunden (default: 900)
  --thread              Thread-Binding aktivieren
  --mode MODE           Run mode (run, session)
  --output, -o OUTPUT   Output format (tool, slash, json)
  --help, -h            Show this help message

Beispiele:
  spawn_agent -t "Analyze logs" 
  spawn_agent -t "Code review" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800
  spawn_agent -t "Batch process" -l "batch-worker" --thread`)
			os.Exit(0)
		}
	}
	
	if task == "" {
		fmt.Fprintln(os.Stderr, "Fehler: --task ist erforderlich")
		os.Exit(1)
	}
	
	spawner := &SubAgentSpawner{}
	config := spawner.GetSpawnConfig(
		task,
		label,
		model,
		thinking,
		timeout,
		thread,
		mode,
		models,
	)
	
	fmt.Println("✅ Sub-Agent Konfiguration:")
	jsonData, _ := json.MarshalIndent(config, "", "  ")
	fmt.Println(string(jsonData))
	
	if output == "tool" {
		spawner.PrintSpawnCommand(config)
	} else if output == "slash" {
		spawner.PrintSlashCommand(config)
	} else if output == "json" {
		fmt.Println("\n📄 JSON:")
		jsonStr, _ := json.Marshal(config)
		fmt.Println(string(jsonStr))
		
		// Speichere als Datei
		labelForFile := "spawn"
		if l, ok := config["label"].(string); ok && l != "" {
			labelForFile = l
		}
		outputFile := filepath.Join("/tmp", fmt.Sprintf("subagent_%s.json", labelForFile))
		
		file, err := os.Create(outputFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der Datei: %v\n", err)
			os.Exit(1)
		}
		defer file.Close()
		
		jsonData, _ := json.MarshalIndent(config, "", "  ")
		file.Write(jsonData)
		
		fmt.Printf("💾 Gespeichert: %s\n", outputFile)
	}
}
