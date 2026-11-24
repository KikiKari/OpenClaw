// abstraction-provenance: {"artifact_sha256": "59032dc8fca2ebee504f419a5c8eac52fc48c373212fdd194731a3b8f24b34e8", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "go"}
// test-embeddings.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

func main() {
	apiKey := os.Getenv("PERPLEXITY_API_KEY")
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "PERPLEXITY_API_KEY is required")
		os.Exit(1)
	}

	tmpDir := "/tmp"
	if t := os.Getenv("TMPDIR"); t != "" {
		tmpDir = t
	}
	outFile := tmpDir + "/perplexity-embeddings-test.json"

	payloadData := map[string]interface{}{
		"input": []string{
			"Scientists explore the universe driven by curiosity.",
			"Curiosity compels us to seek explanations, not just observations.",
			"Historical discoveries began with curious questions.",
			"The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
			"Philosophy examines the nature of curiosity.",
		},
		"model": "pplx-embed-v1-4b",
	}

	jsonPayload, err := json.Marshal(payloadData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	req, err := http.NewRequest("POST", "https://api.perplexity.ai/v1/embeddings", bytes.NewBuffer(jsonPayload))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating request: %v\n", err)
		os.Exit(1)
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error making request: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading response body: %v\n", err)
		os.Exit(1)
	}

	err = os.WriteFile(outFile, body, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("embeddings_http=%d\n", resp.StatusCode)

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		fmt.Fprintf(os.Stderr, "Error unmarshaling response: %v\n", err)
		os.Exit(1)
	}

	keys := make([]string, 0, len(result))
	for k := range result {
		keys = append(keys, k)
	}

	model := interface{}(nil)
	if m, ok := result["model"]; ok {
		model = m
	}

	dataArray := make([]interface{}, 0)
	if data, ok := result["data"].([]interface{}); ok {
		dataArray = data
	}

	itemCount := len(dataArray)

	firstDim := 0
	if len(dataArray) > 0 {
		if firstItem, ok := dataArray[0].(map[string]interface{}); ok {
			if embedding, ok := firstItem["embedding"].([]interface{}); ok {
				firstDim = len(embedding)
			}
		}
	}

	errorField := interface{}(nil)
	if e, ok := result["error"]; ok {
		errorField = e
	}

	output := map[string]interface{}{
		"keys":       keys,
		"model":      model,
		"item_count": itemCount,
		"first_dim":  firstDim,
		"error":      errorField,
	}

	outputJSON, err := json.Marshal(output)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling output: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(outputJSON))
}
