// abstraction-provenance: {"artifact_sha256": "8a4d7595a7790aa4d1d2e4983730ac751e791a4d8e657b1a6877800424130e44", "source_sha256": "4206ddea85e6e63865388488399d2e874412555d623d8758c0369a860e6a0315", "target_language": "go"}
// test-agent.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
)

func main() {
	apiKey := os.Getenv("PERPLEXITY_API_KEY")
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "PERPLEXITY_API_KEY is required")
		os.Exit(1)
	}

	prompt := "Compare recent open-source LLMs in terms of performance, licensing, and practical use."
	if len(os.Args) > 1 {
		prompt = os.Args[1]
	}

	tmpDir := os.Getenv("TMPDIR")
	if tmpDir == "" {
		tmpDir = "/tmp"
	}
	outFile := filepath.Join(tmpDir, "perplexity-agent-test.json")

	requestBody := map[string]interface{}{
		"preset": "fast-search",
		"input":  prompt,
	}
	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		panic(err)
	}

	req, err := http.NewRequest("POST", "https://api.perplexity.ai/v1/agent", bytes.NewBuffer(jsonBody))
	if err != nil {
		panic(err)
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	err = os.WriteFile(outFile, body, 0644)
	if err != nil {
		panic(err)
	}

	fmt.Printf("agent_http=%d\n", resp.StatusCode)

	var response map[string]interface{}
	err = json.Unmarshal(body, &response)
	if err != nil {
		panic(err)
	}

	output := make(map[string]interface{})
	output["keys"] = func() []string {
		keys := make([]string, 0, len(response))
		for k := range response {
			keys = append(keys, k)
		}
		return keys
	}()
	if id, ok := response["id"]; ok {
		output["id"] = id
	} else {
		output["id"] = nil
	}
	if status, ok := response["status"]; ok {
		output["status"] = status
	} else {
		output["status"] = nil
	}
	if outputData, ok := response["output"].([]interface{}); ok {
		output["output_count"] = len(outputData)
	} else {
		output["output_count"] = 0
	}
	if errorData, ok := response["error"]; ok {
		output["error"] = errorData
	} else {
		output["error"] = nil
	}

	result, err := json.MarshalIndent(output, "", "")
	if err != nil {
		panic(err)
	}
	fmt.Println(string(result))
}
