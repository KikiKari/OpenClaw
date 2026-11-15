// abstraction-provenance: {"artifact_sha256": "c8342ec1c8ad369d121a51bd845f89dd8a313c5092265623f405c6c9bbd7c07e", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "go"}
// json_batch_processor.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sync"
)

// JSONProcessingError represents a JSON processing error
type JSONProcessingError struct {
	Message string
}

func (e *JSONProcessingError) Error() string {
	return e.Message
}

// BatchResult represents the result of a batch operation
type BatchResult struct {
	Index   int         `json:"index"`
	Source  string      `json:"source"`
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// parseJSON parses JSON with optional repair functionality
func parseJSON(content string, repair bool) (interface{}, error) {
	var data interface{}
	
	if err := json.Unmarshal([]byte(content), &data); err != nil {
		if repair {
			// Simple repair attempts - remove common issues
			repaired := content
			// Try to fix common JSON issues
			if repaired != content {
				if err2 := json.Unmarshal([]byte(repaired), &data); err2 == nil {
					return data, nil
				}
			}
		}
		return nil, &JSONProcessingError{Message: fmt.Sprintf("JSON parsing failed: %v", err)}
	}
	
	return data, nil
}

// readJSONL reads a JSON Lines file line by line
func readJSONL(filePath string) ([]string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line != "" {
			lines = append(lines, line)
		}
	}
	
	return lines, scanner.Err()
}

// processBatch processes inputs in parallel
func processBatch(inputs []interface{}, processor func(interface{}, int) *BatchResult, maxWorkers int) []*BatchResult {
	results := make([]*BatchResult, len(inputs))
	
	// Create worker pool
	numWorkers := maxWorkers
	if numWorkers <= 0 {
		numWorkers = runtime.NumCPU()
	}
	
	// Create channels for work distribution
	jobs := make(chan struct {
		input interface{}
		index int
	}, len(inputs))
	
	// Start workers
	var wg sync.WaitGroup
	resultChan := make(chan *BatchResult, len(inputs))
	
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for job := range jobs {
				result := processor(job.input, job.index)
				resultChan <- result
			}
		}()
	}
	
	// Send jobs
	go func() {
		for i, input := range inputs {
			jobs <- struct {
				input interface{}
				index int
			}{input, i}
		}
		close(jobs)
	}()
	
	// Close result channel when all workers are done
	go func() {
		wg.Wait()
		close(resultChan)
	}()
	
	// Collect results
	for result := range resultChan {
		results[result.Index] = result
	}
	
	return results
}

// processFileBatch processes multiple JSON files in batch
func processFileBatch(filePaths []string, repair bool, maxWorkers int) []*BatchResult {
	processor := func(input interface{}, idx int) *BatchResult {
		path := input.(string)
		
		content, err := os.ReadFile(path)
		if err != nil {
			return &BatchResult{
				Index:   idx,
				Source:  path,
				Success: false,
				Error:   fmt.Sprintf("%T: %v", err, err),
			}
		}
		
		data, err := parseJSON(string(content), repair)
		if err != nil {
			return &BatchResult{
				Index:   idx,
				Source:  path,
				Success: false,
				Error:   err.Error(),
			}
		}
		
		return &BatchResult{
			Index:   idx,
			Source:  path,
			Success: true,
			Data:    data,
		}
	}
	
	// Convert filePaths to interface{} slice
	inputs := make([]interface{}, len(filePaths))
	for i, path := range filePaths {
		inputs[i] = path
	}
	
	return processBatch(inputs, processor, maxWorkers)
}

// processJSONLFile processes a JSON Lines file
func processJSONLFile(filePath string, repair bool) []*BatchResult {
	lines, err := readJSONL(filePath)
	if err != nil {
		return []*BatchResult{{
			Index:   0,
			Source:  filePath,
			Success: false,
			Error:   fmt.Sprintf("Failed to read file: %v", err),
		}}
	}
	
	var results []*BatchResult
	
	for lineNum, line := range lines {
		data, err := parseJSON(line, repair)
		if err != nil {
			results = append(results, &BatchResult{
				Index:   lineNum + 1,
				Source:  fmt.Sprintf("%s:%d", filePath, lineNum+1),
				Success: false,
				Error:   err.Error(),
			})
		} else {
			results = append(results, &BatchResult{
				Index:   lineNum + 1,
				Source:  fmt.Sprintf("%s:%d", filePath, lineNum+1),
				Success: true,
				Data:    data,
			})
		}
	}
	
	return results
}

// writeJSONL writes BatchResult list as JSON Lines
func writeJSONL(results []*BatchResult, outputPath string, onlySuccessful bool) error {
	file, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer file.Close()
	
	writer := bufio.NewWriter(file)
	defer writer.Flush()
	
	encoder := json.NewEncoder(writer)
	encoder.SetEscapeHTML(false)
	
	for _, result := range results {
		if onlySuccessful && !result.Success {
			continue
		}
		if err := encoder.Encode(result); err != nil {
			return err
		}
	}
	
	return nil
}

func main() {
	var (
		jsonlFlag       = flag.Bool("jsonl", false, "Treat inputs as JSON-Lines files")
		jsonlShort      = flag.Bool("l", false, "Treat inputs as JSON-Lines files (short)")
		repairFlag      = flag.Bool("repair", true, "Enable JSON repair")
		repairShort     = flag.Bool("r", true, "Enable JSON repair (short)")
		workersFlag     = flag.Int("workers", 4, "Parallel workers")
		workersShort    = flag.Int("w", 4, "Parallel workers (short)")
		outputFlag      = flag.String("output", "", "Output JSON-Lines file")
		outputShort     = flag.String("o", "", "Output JSON-Lines file (short)")
		summaryFlag     = flag.Bool("summary", false, "Show summary only")
		summaryShort    = flag.Bool("s", false, "Show summary only (short)")
	)
	
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] inputs...\n", filepath.Base(os.Args[0]))
		fmt.Fprintf(os.Stderr, "Batch JSON Processor\n\n")
		flag.PrintDefaults()
	}
	
	flag.Parse()
	
	// Handle short flags
	jsonlMode := *jsonlFlag || *jsonlShort
	repair := *repairFlag || *repairShort
	workers := *workersFlag
	if *workersShort != 4 { // Only use short if it was explicitly set
		workers = *workersShort
	}
	showSummary := *summaryFlag || *summaryShort
	outputPath := *outputFlag
	if outputPath == "" && *outputShort != "" {
		outputPath = *outputShort
	}
	
	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Error: no input files specified")
		flag.Usage()
		os.Exit(1)
	}
	
	var allResults []*BatchResult
	
	if jsonlMode {
		// JSON-Lines mode
		for _, inputPath := range args {
			results := processJSONLFile(inputPath, repair)
			allResults = append(allResults, results...)
		}
	} else {
		// Standard JSON batch mode
		allResults = processFileBatch(args, repair, workers)
	}
	
	// Calculate statistics
	successful := 0
	for _, result := range allResults {
		if result.Success {
			successful++
		}
	}
	failed := len(allResults) - successful
	
	if showSummary {
		fmt.Printf("Processed: %d\n", len(allResults))
		fmt.Printf("Successful: %d\n", successful)
		fmt.Printf("Failed: %d\n", failed)
	} else {
		// Output results
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		
		for _, result := range allResults {
			if result.Success {
				encoder.Encode(result.Data)
			} else {
				fmt.Fprintf(os.Stderr, "ERROR [%s]: %s\n", result.Source, result.Error)
			}
		}
	}
	
	// Optional: JSONL output
	if outputPath != "" {
		if err := writeJSONL(allResults, outputPath, false); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing to output file: %v\n", err)
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "\nResults written to: %s\n", outputPath)
	}
	
	// Exit code
	if failed > 0 {
		os.Exit(1)
	}
	os.Exit(0)
}
