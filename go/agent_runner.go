// abstraction-provenance: {"artifact_sha256": "f11658e38bb0338b90da25b24cb478ea9a946a7dc3b94ceb2b4eae2bd5574f15", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "go"}
// agent_runner.py — portiert nach go
// Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

// Run a gateway-only OpenClaw agent turn for a porting task.

package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
)

type Config struct {
	Agents struct {
		Defaults struct {
			Models map[string]interface{} `json:"models"`
			Model  interface{}            `json:"model"`
		} `json:"defaults"`
	} `json:"agents"`
}

func allowedModels(configPath string) (map[string]bool, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	models := make(map[string]bool)
	for model := range config.Agents.Defaults.Models {
		models[model] = true
	}

	selected := config.Agents.Defaults.Model
	switch v := selected.(type) {
	case string:
		models[v] = true
	case map[string]interface{}:
		if primary, ok := v["primary"].(string); ok {
			models[primary] = true
		}
		if fallbacks, ok := v["fallbacks"].([]interface{}); ok {
			for _, fb := range fallbacks {
				if fbStr, ok := fb.(string); ok {
					models[fbStr] = true
				}
			}
		}
	}

	return models, nil
}

func run(task, model string, timeout int) int {
	if strings.TrimSpace(task) == "" || len(task) > 500 {
		fmt.Fprintln(os.Stderr, "task must contain 1–500 characters")
		return 1
	}
	if timeout < 1 || timeout > 7200 {
		fmt.Fprintln(os.Stderr, "timeout must be between 1 and 7200 seconds")
		return 1
	}

	configPath := os.Getenv("OPENCLAW_CONFIG")
	if configPath == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintln(os.Stderr, "could not determine home directory")
			return 1
		}
		configPath = filepath.Join(homeDir, ".openclaw", "openclaw.json")
	}

	allowed, err := allowedModels(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not read config: %v\n", err)
		return 1
	}

	if !allowed[model] {
		fmt.Fprintln(os.Stderr, "model is not in the configured OpenClaw model allowlist")
		return 1
	}

	parts := strings.Split(model, "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		fmt.Fprintln(os.Stderr, "model must have provider/model form")
		return 1
	}
	provider, modelID := parts[0], parts[1]

	runID := uuid.New().String()
	params := map[string]interface{}{
		"message":         strings.TrimSpace(task),
		"provider":        provider,
		"model":           modelID,
		"sessionKey":      fmt.Sprintf("agent:main:abstraction-runner:%s", runID),
		"idempotencyKey":  runID,
		"timeout":         timeout,
		"deliver":         false,
	}

	paramsJSON, err := json.Marshal(params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to marshal params: %v\n", err)
		return 1
	}

	command := []string{
		"openclaw", "gateway", "call", "agent", "--params", string(paramsJSON),
		"--expect-final", "--json", "--timeout", strconv.Itoa((timeout + 10) * 1000),
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeout+20)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, command[0], command[1:]...)
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			fmt.Fprintln(os.Stderr, "command timed out")
			return 1
		}
		stderrContent := stderr.String()
		if stderrContent == "" {
			stderrContent = stdout.String()
		}
		if stderrContent == "" {
			stderrContent = "OpenClaw agent call failed"
		}
		fmt.Fprint(os.Stderr, stderrContent)
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return exitErr.ExitCode()
		}
		return 1
	}

	var response map[string]interface{}
	if err := json.Unmarshal([]byte(stdout.String()), &response); err != nil {
		fmt.Fprintln(os.Stderr, "OpenClaw returned invalid JSON")
		return 1
	}

	if status, ok := response["status"].(string); !ok || status != "ok" {
		fmt.Fprintln(os.Stderr, "OpenClaw did not return a completed agent result")
		return 1
	}

	agentResult, ok := response["result"].(map[string]interface{})
	if !ok {
		fmt.Fprintln(os.Stderr, "OpenClaw returned no agent result")
		return 1
	}

	meta, _ := agentResult["meta"].(map[string]interface{})
	if meta == nil {
		meta = make(map[string]interface{})
	}
	if aborted, _ := meta["aborted"].(bool); aborted {
		fmt.Fprintln(os.Stderr, "OpenClaw agent execution was aborted")
		return 1
	}
	if errorMsg, _ := meta["error"].(string); errorMsg != "" {
		fmt.Fprintf(os.Stderr, "OpenClaw agent error: %s\n", errorMsg)
		return 1
	}

	payloads, _ := agentResult["payloads"].([]interface{})
	if payloads == nil {
		payloads = []interface{}{}
	}

	hasValidText := false
	for _, item := range payloads {
		if itemMap, ok := item.(map[string]interface{}); ok {
			if isError, _ := itemMap["isError"].(bool); isError {
				fmt.Fprintln(os.Stderr, "OpenClaw agent returned an error")
				return 1
			}
			if text, ok := itemMap["text"].(string); ok && strings.TrimSpace(text) != "" {
				hasValidText = true
			}
		}
	}

	if !hasValidText {
		fmt.Fprintln(os.Stderr, "OpenClaw agent returned no text")
		return 1
	}

	jsonOutput, err := json.Marshal(response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to marshal response: %v\n", err)
		return 1
	}
	fmt.Println(string(jsonOutput))
	return 0
}

func main() {
	task := ""
	model := ""
	timeout := 1800
	gatewayOnly := false

	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		if arg == "--task" && i+1 < len(os.Args) {
			task = os.Args[i+1]
			i++
		} else if arg == "--model" && i+1 < len(os.Args) {
			model = os.Args[i+1]
			i++
		} else if arg == "--timeout" && i+1 < len(os.Args) {
			if t, err := strconv.Atoi(os.Args[i+1]); err == nil {
				timeout = t
			}
			i++
		} else if arg == "--gateway-only" {
			gatewayOnly = true
		}
	}

	if task == "" || model == "" {
		fmt.Fprintln(os.Stderr, "both --task and --model are required")
		os.Exit(1)
	}

	if !gatewayOnly {
		fmt.Fprintln(os.Stderr, "agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only")
		os.Exit(1)
	}

	os.Exit(run(task, model, timeout))
}
