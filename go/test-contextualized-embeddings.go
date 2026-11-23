// abstraction-provenance: {"artifact_sha256": "c794c1cb4a1ab4614c074c5462d6e7df96e086c25313a54a1c6eb1089473dd19", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "go"}
// test-contextualized-embeddings.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"context"
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

	tmpDir := os.TempDir()
	if tmpDirOverride := os.Getenv("TMPDIR"); tmpDirOverride != "" {
		tmpDir = tmpDirOverride
	}
	outPath := filepath.Join(tmpDir, "perplexity-contextualized-embeddings-test.json")

	payloadData := map[string]interface{}{
		"input": [][]string{
			{
				"OpenClaw can route web search through Perplexity.",
				"The Perplexity MCP server exposes search and reasoning tools.",
				"Contextualized embeddings improve document chunk retrieval.",
			},
		},
		"model": "pplx-embed-context-v1-4b",
	}

	jsonPayload, err := json.Marshal(payloadData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	req, err := http.NewRequest("POST", "https://api.perplexity.ai/v1/contextualizedembeddings", bytes.NewBuffer(jsonPayload))
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

	err = os.WriteFile(outPath, body, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("contextualized_embeddings_http=%d\n", resp.StatusCode)

	// Process the response similar to the jq command
	var responseData map[string]interface{}
	if err := json.Unmarshal(body, &responseData); err != nil {
		fmt.Fprintf(os.Stderr, "Error unmarshaling response: %v\n", err)
		os.Exit(1)
	}

	result := make(map[string]interface{})
	
	// Get all top-level keys
	keys := make([]string, 0, len(responseData))
	for k := range responseData {
		keys = append(keys, k)
	}
	result["keys"] = keys
	
	// Get model if exists
	if model, exists := responseData["model"]; exists {
		result["model"] = model
	} else {
		result["model"] = nil
	}
	
	// Count documents in data array
	documentCount := 0
	if data, exists := responseData["data"]; exists {
		if dataArray, ok := data.([]interface{}); ok {
			documentCount = len(dataArray)
		}
	}
	result["document_count"] = documentCount
	
	// Count chunks in first document
	firstChunkCount := 0
	if data, exists := responseData["data"]; exists {
		if dataArray, ok := data.([]interface{}); ok && len(dataArray) > 0 {
			if firstDoc, ok := dataArray[0].(map[string]interface{}); ok {
				if docData, exists := firstDoc["data"]; exists {
					if docDataArray, ok := docData.([]interface{}); ok {
						firstChunkCount = len(docDataArray)
					}
				}
			}
		}
	}
	result["first_chunk_count"] = firstChunkCount
	
	// Get error if exists
	if errorVal, exists := responseData["error"]; exists {
		result["error"] = errorVal
	} else {
		result["error"] = nil
	}

	// Print the result as JSON
	output, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling output: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(output))
}
