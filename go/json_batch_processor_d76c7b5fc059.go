// abstraction-provenance: {"artifact_sha256": "6a8bb1faec19e1569c414431e8e4fd67a2dbfa6417c3b840ece9b08428c04f8d", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "go"}
// json_batch_processor.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/*
Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
*/

package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

// BatchResult represents the result of a batch processing operation
type BatchResult struct {
	Index   int         `json:"index"`
	Source  string      `json:"source"`
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// JSONProcessingError represents an error during JSON processing
type JSONProcessingError struct {
	Message string
}

func (e *JSONProcessingError) Error() string {
	return e.Message
}

// readJSONL reads a JSON-Lines (NDJSON) file line by line
func readJSONL(filePath string) ([]map[string]interface{}, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var results []map[string]interface{}
	scanner := bufio.NewScanner(file)
	lineNum := 0

	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var data map[string]interface{}
		if err := json.Unmarshal([]byte(line), &data); err != nil {
			return nil, &JSONProcessingError{Message: fmt.Sprintf("JSON decode error at line %d: %v", lineNum, err)}
		}
		results = append(results, data)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return results, nil
}

// processBatch processes a list of inputs in parallel
func processBatch(inputs []string, processor func(string, int) BatchResult, maxWorkers int) []BatchResult {
	results := make([]BatchResult, len(inputs))
	
	// Create worker pool
	numWorkers := maxWorkers
	if numWorkers <= 0 {
		numWorkers = runtime.NumCPU()
	}
	
	type workItem struct {
		input string
		index int
	}
	
	workChan := make(chan workItem, len(inputs))
	resultChan := make(chan BatchResult, len(inputs))
	
	var wg sync.WaitGroup
	
	// Start workers
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for item := range workChan {
				result := processor(item.input, item.index)
				resultChan <- result
			}
		}()
	}
	
	// Send work
	go func() {
		for i, input := range inputs {
			workChan <- workItem{input: input, index: i}
		}
		close(workChan)
	}()
	
	// Close result channel when all workers are done
	go func() {
		wg.Wait()
		close(resultChan)
	}()
	
	// Collect results
	collected := 0
	for result := range resultChan {
		results[result.Index] = result
		collected++
	}
	
	return results
}

// parseJSON parses JSON content with optional repair
func parseJSON(content string, repair bool) (interface{}, error) {
	var data interface{}
	
	if err := json.Unmarshal([]byte(content), &data); err != nil {
		if repair {
			// Simple repair: remove trailing commas
			fixedContent := strings.ReplaceAll(content, ",}", "}")
			fixedContent = strings.ReplaceAll(fixedContent, ",]", "]")
			
			if err2 := json.Unmarshal([]byte(fixedContent), &data); err2 != nil {
				return nil, &JSONProcessingError{Message: fmt.Sprintf("JSON parsing failed: %v", err)}
			}
			return data, nil
		}
		return nil, &JSONProcessingError{Message: fmt.Sprintf("JSON parsing failed: %v", err)}
	}
	
	return data, nil
}

// processFileBatch processes multiple JSON files in batch
func processFileBatch(filePaths []string, repair bool, maxWorkers int) []BatchResult {
	processor := func(path string, idx int) BatchResult {
		content, err := os.ReadFile(path)
		if err != nil {
			return BatchResult{
				Index:   idx,
				Source:  path,
				Success: false,
				Error:   fmt.Sprintf("File read error: %v", err),
			}
		}
		
		data, err := parseJSON(string(content), repair)
		if err != nil {
			return BatchResult{
				Index:   idx,
				Source:  path,
				Success: false,
				Error:   err.Error(),
			}
		}
		
		return BatchResult{
			Index:   idx,
			Source:  path,
			Success: true,
			Data:    data,
		}
	}
	
	return processBatch(filePaths, processor, maxWorkers)
}

// processJSONLFile processes a JSON-Lines file
func processJSONLFile(filePath string, repair bool) []BatchResult {
	file, err := os.Open(filePath)
	if err != nil {
		return []BatchResult{{
			Index:   0,
			Source:  filePath,
			Success: false,
			Error:   fmt.Sprintf("File open error: %v", err),
		}}
	}
	defer file.Close()
	
	var results []BatchResult
	reader := bufio.NewReader(file)
	lineNum := 0
	
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				break
			}
			results = append(results, BatchResult{
				Index:   lineNum,
				Source:  fmt.Sprintf("%s:%d", filePath, lineNum),
				Success: false,
				Error:   fmt.Sprintf("Read error: %v", err),
			})
			break
		}
		
		lineNum++
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		
		data, err := parseJSON(line, repair)
		if err != nil {
			results = append(results, BatchResult{
				Index:   lineNum,
				Source:  fmt.Sprintf("%s:%d", filePath, lineNum),
				Success: false,
				Error:   err.Error(),
			})
			continue
		}
		
		results = append(results, BatchResult{
			Index:   lineNum,
			Source:  fmt.Sprintf("%s:%d", filePath, lineNum),
			Success: true,
			Data:    data,
		})
	}
	
	return results
}

// writeJSONL writes BatchResult list as JSON-Lines
func writeJSONL(results []BatchResult, outputPath string, onlySuccessful bool) error {
	file, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer file.Close()
	
	writer := bufio.NewWriter(file)
	defer writer.Flush()
	
	for _, result := range results {
		if onlySuccessful && !result.Success {
			continue
		}
		
		jsonData, err := json.Marshal(result)
		if err != nil {
			return err
		}
		
		_, err = writer.WriteString(string(jsonData) + "\n")
		if err != nil {
			return err
		}
	}
	
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <input_files...>\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}
	
	// Parse arguments manually since we don't have a direct equivalent to argparse
	args := os.Args[1:]
	var inputs []string
	jsonlMode := false
	repair := true
	workers := 4
	output := ""
	summary := false
	
	// Simple argument parsing
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--jsonl", "-l":
			jsonlMode = true
		case "--repair", "-r":
			repair = true
		case "--no-repair":
			repair = false
		case "--workers", "-w":
			if i+1 < len(args) {
				workers, _ = strconv.Atoi(args[i+1])
				i++
			}
		case "--output", "-o":
			if i+1 < len(args) {
				output = args[i+1]
				i++
			}
		case "--summary", "-s":
			summary = true
		case "--help", "-h":
			fmt.Println("Batch JSON Processor")
			fmt.Println("Usage: json_batch_processor [options] <input_files...>")
			fmt.Println("")
			fmt.Println("Options:")
			fmt.Println("  --jsonl, -l          Treat inputs as JSON-Lines files")
			fmt.Println("  --repair, -r         Enable JSON repair (default)")
			fmt.Println("  --no-repair          Disable JSON repair")
			fmt.Println("  --workers, -w N      Parallel workers (default: 4)")
			fmt.Println("  --output, -o FILE    Output JSON-Lines file")
			fmt.Println("  --summary, -s        Show summary only")
			os.Exit(0)
		default:
			if !strings.HasPrefix(arg, "-") {
				inputs = append(inputs, arg)
			}
		}
	}
	
	if len(inputs) == 0 {
		fmt.Fprintln(os.Stderr, "Error: No input files specified")
		os.Exit(1)
	}
	
	var allResults []BatchResult
	
	if jsonlMode {
		// JSON-Lines mode
		for _, inputPath := range inputs {
			results := processJSONLFile(inputPath, repair)
			allResults = append(allResults, results...)
		}
	} else {
		// Standard JSON batch
		allResults = processFileBatch(inputs, repair, workers)
	}
	
	// Calculate statistics
	successful := 0
	for _, result := range allResults {
		if result.Success {
			successful++
		}
	}
	failed := len(allResults) - successful
	
	// Output results
	if summary {
		fmt.Printf("Processed: %d\n", len(allResults))
		fmt.Printf("Successful: %d\n", successful)
		fmt.Printf("Failed: %d\n", failed)
	} else {
		for _, result := range allResults {
			if result.Success {
				jsonData, _ := json.Marshal(result.Data)
				fmt.Println(string(jsonData))
			} else {
				fmt.Fprintf(os.Stderr, "ERROR [%s]: %s\n", result.Source, result.Error)
			}
		}
	}
	
	// Optional: JSONL Output
	if output != "" {
		err := writeJSONL(allResults, output, false)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error writing output file: %v\n", err)
		} else {
			fmt.Fprintf(os.Stderr, "\nResults written to: %s\n", output)
		}
	}
	
	// Exit code
	if failed > 0 {
		os.Exit(1)
	}
	os.Exit(0)
}
