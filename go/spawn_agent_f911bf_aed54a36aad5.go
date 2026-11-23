// abstraction-provenance: {"artifact_sha256": "600da281739e8c1c53aca18b378fefe82ad7dec687845a1a762eb04ca90bffcd", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "go"}
// spawn_agent.py — portiert nach go
// Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

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

const WORKSPACE = "/home/openclaw/.openclaw/workspace"

// ModelConfigError represents an error in model configuration
type ModelConfigError struct {
	Message string
}

func (e *ModelConfigError) Error() string {
	return e.Message
}

// configured_models simulates loading available models
// In a real implementation this would load from configuration
func configuredModels() ([]string, error) {
	// This is a placeholder - in reality you'd load from your configuration system
	models := []string{
		"openrouter/anthropic/claude-haiku-4.5",
		"openai/gpt-4",
		"openai/gpt-3.5-turbo",
		"mistral/mistral-large",
	}
	
	// Simulate potential configuration error
	if len(models) == 0 {
		return nil, &ModelConfigError{Message: "no models configured"}
	}
	
	return models, nil
}

// SubAgentSpawner holds methods for spawning sub-agents
type SubAgentSpawner struct{}

// SpawnConfig represents the configuration for sessions_spawn
type SpawnConfig struct {
	Task              string `json:"task,omitempty"`
	Label             string `json:"label,omitempty"`
	Model             string `json:"model,omitempty"`
	Thinking          string `json:"thinking,omitempty"`
	RunTimeoutSeconds int    `json:"runTimeoutSeconds,omitempty"`
	Thread            bool   `json:"thread,omitempty"`
	Mode              string `json:"mode,omitempty"`
}

// getSpawnConfig creates configuration for sessions_spawn
func (s *SubAgentSpawner) getSpawnConfig(
	task string,
	label string,
	model string,
	thinking string,
	timeout int,
	thread bool,
	mode string,
	models []string,
) SpawnConfig {
	config := SpawnConfig{
		Task: task,
	}
	
	if label != "" {
		config.Label = label
	}
	
	// Check if model is valid
	modelValid := false
	for _, m := range models {
		if m == model {
			modelValid = true
			break
		}
	}
	
	if model != "" && modelValid {
		config.Model = model
	}
	
	if thinking != "" {
		config.Thinking = thinking
	}
	
	if timeout != 0 {
		config.RunTimeoutSeconds = timeout
	}
	
	if thread {
		config.Thread = true
		if mode == "run" {
			config.Mode = "session" // thread requires session mode
		} else {
			config.Mode = mode
		}
	} else {
		config.Mode = mode
	}
	
	return config
}

// printSpawnCommand prints the equivalent tool command
func (s *SubAgentSpawner) printSpawnCommand(config SpawnConfig) {
	fmt.Println("\n🛠️  Tool-Aufruf:")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("sessions_spawn(")
	
	// Convert to map for easier iteration
	configMap := make(map[string]interface{})
	configBytes, _ := json.Marshal(config)
	json.Unmarshal(configBytes, &configMap)
	
	for key, value := range configMap {
		if value == nil || (fmt.Sprintf("%v", value) == "" && key != "thread") {
			continue
		}
		
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

// printSlashCommand prints the equivalent slash command
func (s *SubAgentSpawner) printSlashCommand(config SpawnConfig) {
	task := config.Task
	if task == "" {
		task = ""
	}
	
	label := config.Label
	if label == "" {
		label = "agent"
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

// Args represents command line arguments
type Args struct {
	Task    string
	Label   string
	Model   string
	Thinking string
	Timeout int
	Thread  bool
	Mode    string
	Output  string
}

func main() {
	// Add workspace to PATH-like behavior (Go doesn't have PYTHONPATH equivalent)
	// but we can check if it's in our custom paths or handle accordingly
	
	// Load available models
	models, err := configuredModels()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Modellkonfiguration kann nicht geladen werden: %v\n", err)
		os.Exit(1)
	}
	
	// Parse command line arguments manually since we're not using flags package
	args := parseArgs(os.Args[1:])
	
	if args.Task == "" {
		fmt.Println("Fehler: --task/-t ist erforderlich")
		printUsage()
		os.Exit(1)
	}
	
	spawner := &SubAgentSpawner{}
	config := spawner.getSpawnConfig(
		args.Task,
		args.Label,
		args.Model,
		args.Thinking,
		args.Timeout,
		args.Thread,
		args.Mode,
		models,
	)
	
	fmt.Println("✅ Sub-Agent Konfiguration:")
	configJSON, _ := json.MarshalIndent(config, "", "  ")
	fmt.Println(string(configJSON))
	
	switch args.Output {
	case "tool":
		spawner.printSpawnCommand(config)
	case "slash":
		spawner.printSlashCommand(config)
	case "json":
		fmt.Println("\n📄 JSON:")
		fmt.Println(string(configJSON))
		
		// Save to file
		label := config.Label
		if label == "" {
			label = "spawn"
		}
		outputFile := filepath.Join("/tmp", fmt.Sprintf("subagent_%s.json", label))
		file, err := os.Create(outputFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der Datei: %v\n", err)
			os.Exit(1)
		}
		defer file.Close()
		
		json.NewEncoder(file).Encode(config)
		fmt.Printf("💾 Gespeichert: %s\n", outputFile)
	}
}

func parseArgs(args []string) Args {
	result := Args{
		Timeout: 900,
		Mode:    "run",
		Output:  "tool",
	}
	
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--task", "-t":
			if i+1 < len(args) {
				result.Task = args[i+1]
				i++
			}
		case "--label", "-l":
			if i+1 < len(args) {
				result.Label = args[i+1]
				i++
			}
		case "--model", "-m":
			if i+1 < len(args) {
				result.Model = args[i+1]
				i++
			}
		case "--thinking":
			if i+1 < len(args) {
				result.Thinking = args[i+1]
				i++
			}
		case "--timeout":
			if i+1 < len(args) {
				fmt.Sscanf(args[i+1], "%d", &result.Timeout)
				i++
			}
		case "--thread":
			result.Thread = true
		case "--mode":
			if i+1 < len(args) {
				result.Mode = args[i+1]
				i++
			}
		case "--output", "-o":
			if i+1 < len(args) {
				result.Output = args[i+1]
				i++
			}
		}
	}
	
	return result
}

func printUsage() {
	programName := filepath.Base(os.Args[0])
	fmt.Printf(`Usage: %s [OPTIONS]

Sub-Agent Spawn Helper

OPTIONAL ARGUMENTS:
  --task TASK, -t TASK     Aufgabenbeschreibung
  --label LABEL, -l LABEL  Optionaler Label
  --model MODEL, -m MODEL  KI-Modell (%s)
  --thinking {low,medium,high}
                           Thinking Level
  --timeout TIMEOUT        Timeout in Sekunden (default: 900)
  --thread                 Thread-Binding aktivieren
  --mode {run,session}     Run mode (default: run)
  --output {tool,slash,json}, -o {tool,slash,json}
                           Output format (default: tool)

BEISPIELE:
  %s -t "Analyze logs" 
  %s -t "Code review" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800
  %s -t "Batch process" -l "batch-worker" --thread
`, programName, "openrouter/anthropic/claude-haiku-4.5,openai/gpt-4,openai/gpt-3.5-turbo,mistral/mistral-large", programName, programName, programName)
}
