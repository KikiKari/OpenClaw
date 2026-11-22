// abstraction-provenance: {"artifact_sha256": "4933e56f54b42efd91ce092e43e3e8fe4bac9a24d967967bdf2d4041b90b363b", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "go"}
// spawn_agent.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

// Config represents the configuration structure
type Config struct {
	Agents struct {
		Defaults struct {
			Model struct {
				Primary   string   `json:"primary"`
				Fallbacks []string `json:"fallbacks"`
			} `json:"model"`
		} `json:"defaults"`
	} `json:"agents"`
}

// SubAgentConfig represents the configuration for spawning sub-agents
type SubAgentConfig struct {
	Task              string `json:"task"`
	Label             string `json:"label,omitempty"`
	Model             string `json:"model,omitempty"`
	Thinking          string `json:"thinking,omitempty"`
	RunTimeoutSeconds int    `json:"runTimeoutSeconds,omitempty"`
	Thread            bool   `json:"thread,omitempty"`
	Mode              string `json:"mode,omitempty"`
}

var models []string

func loadModels() ([]string, error) {
	configPath := os.Getenv("OPENCLAW_CONFIG")
	if configPath == "" {
		configPath = "/home/openclaw/.openclaw/openclaw.json"
	}

	data, err := ioutil.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("Modellkonfiguration kann nicht geladen werden: %s: %v", configPath, err)
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("Modellkonfiguration kann nicht geladen werden: %s: %v", configPath, err)
	}

	modelConfig := config.Agents.Defaults.Model
	candidates := append([]string{modelConfig.Primary}, modelConfig.Fallbacks...)

	// Filter out empty strings and anthropic models
	modelMap := make(map[string]bool)
	var result []string
	for _, model := range candidates {
		if model != "" && !strings.HasPrefix(model, "anthropic/") {
			if !modelMap[model] {
				modelMap[model] = true
				result = append(result, model)
			}
		}
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("Keine allgemein verfügbaren Modelle in %s", configPath)
	}

	return result, nil
}

// SubAgentSpawner helps with spawning sub-agents
type SubAgentSpawner struct{}

// GetSpawnConfig creates configuration for sessions_spawn
func (s *SubAgentSpawner) GetSpawnConfig(
	task, label, model, thinking string,
	timeout int,
	thread bool,
	mode string,
) SubAgentConfig {

	config := SubAgentConfig{
		Task: task,
	}

	if label != "" {
		config.Label = label
	}

	if model != "" {
		// Check if model is in available models
		for _, m := range models {
			if m == model {
				config.Model = model
				break
			}
		}
	}

	if thinking != "" {
		config.Thinking = thinking
	}

	if timeout > 0 {
		config.RunTimeoutSeconds = timeout
	}

	if thread {
		config.Thread = true
		if mode == "run" {
			config.Mode = "session" // thread requires session mode
		}
	} else {
		config.Mode = mode
	}

	return config
}

// PrintSpawnCommand prints the equivalent tool command
func (s *SubAgentSpawner) PrintSpawnCommand(config SubAgentConfig) {
	fmt.Println("\n🛠️  Tool-Aufruf:")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("sessions_spawn(")
	
	// Print each field that has a value
	v := fmt.Sprintf("%+v", config)
	// This is a simplified approach - in practice you'd use reflection
	// to properly iterate over struct fields
	
	// For now we'll just marshal to JSON and parse it back to show the values
	jsonData, _ := json.MarshalIndent(config, "", "    ")
	lines := strings.Split(string(jsonData), "\n")
	for _, line := range lines[1 : len(lines)-1] { // Skip first and last braces
		if strings.Contains(line, ":") {
			parts := strings.SplitN(line, ":", 2)
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			// Remove trailing comma if present
			if strings.HasSuffix(value, ",") {
				value = value[:len(value)-1]
			}
			// Remove quotes from keys
			key = strings.Trim(key, "\"")
			fmt.Printf("    %s=%s\n", key, value)
		}
	}
	
	fmt.Println(")")
	fmt.Println(strings.Repeat("=", 50))
}

// PrintSlashCommand prints the equivalent slash command
func (s *SubAgentSpawner) PrintSlashCommand(config SubAgentConfig) {
	task := config.Task
	label := "agent"
	if config.Label != "" {
		label = config.Label
	}
	model := config.Model

	cmd := fmt.Sprintf("/subagents spawn %s \"%s\"", label, task)
	if model != "" {
		cmd += fmt.Sprintf(" --model %s", model)
	}
	if config.Thinking != "" {
		cmd += fmt.Sprintf(" --thinking %s", config.Thinking)
	}

	fmt.Println("\n💬 Slash Command:")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println(cmd)
	fmt.Println(strings.Repeat("=", 50))
}

func main() {
	// Load models at startup
	var err error
	models, err = loadModels()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Laden der Modelle: %v\n", err)
		os.Exit(1)
	}

	// Parse command line arguments manually since Go doesn't have argparse
	args := os.Args[1:]
	
	var task, label, model, thinking, output, mode string
	var timeout int
	var thread bool
	
	// Simple argument parsing
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--task", "-t":
			i++
			if i < len(args) {
				task = args[i]
			}
		case "--label", "-l":
			i++
			if i < len(args) {
				label = args[i]
			}
		case "--model", "-m":
			i++
			if i < len(args) {
				model = args[i]
			}
		case "--thinking":
			i++
			if i < len(args) {
				thinking = args[i]
			}
		case "--timeout":
			i++
			if i < len(args) {
				fmt.Sscanf(args[i], "%d", &timeout)
			}
		case "--thread":
			thread = true
		case "--mode":
			i++
			if i < len(args) {
				mode = args[i]
			}
		case "--output", "-o":
			i++
			if i < len(args) {
				output = args[i]
			}
		case "--help", "-h":
			fmt.Println(`Sub-Agent Spawn Helper

Beispiele:
  spawn_agent.go -t "Analyze logs" 
  spawn_agent.go -t "Code review" -m openai/gpt-5.6-sol --timeout 1800
  spawn_agent.go -t "Batch process" -l "batch-worker" --thread`)
			os.Exit(0)
		}
	}

	// Validate required arguments
	if task == "" {
		fmt.Fprintln(os.Stderr, "Fehler: --task/-t ist erforderlich")
		os.Exit(1)
	}

	// Set defaults
	if timeout == 0 {
		timeout = 900
	}
	if mode == "" {
		mode = "run"
	}
	if output == "" {
		output = "tool"
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
	)

	// Print configuration
	fmt.Println("✅ Sub-Agent Konfiguration:")
	jsonData, _ := json.MarshalIndent(config, "", "  ")
	fmt.Println(string(jsonData))

	switch output {
	case "tool":
		spawner.PrintSpawnCommand(config)
	case "slash":
		spawner.PrintSlashCommand(config)
	case "json":
		fmt.Println("\n📄 JSON:")
		fmt.Println(string(jsonData))

		// Save to file
		filename := "spawn.json"
		if config.Label != "" {
			filename = fmt.Sprintf("subagent_%s.json", config.Label)
		}
		outputFile := filepath.Join("/tmp", filename)
		
		file, err := os.Create(outputFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der Datei: %v\n", err)
			os.Exit(1)
		}
		defer file.Close()
		
		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(config); err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der Datei: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("💾 Gespeichert: %s\n", outputFile)
	}
}
