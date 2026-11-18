// abstraction-provenance: {"artifact_sha256": "b4065910151b3e282b7fb8fa605b53c33158017bb0e9c247422a29019e870fcd", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "go"}
// json_processor.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
)

var (
	ErrJSONProcessing = errors.New("JSON processing error")
	ErrJSONValidation = errors.New("JSON validation error")
	ErrJSONRepair     = errors.New("JSON repair error")
)

func repairJSONString(rawJSON string) (string, error) {
	cleaned := strings.TrimSpace(rawJSON)
	
	// Remove JavaScript comments
	reSingleLine := regexp.MustCompile(`//.*?\n`)
	cleaned = reSingleLine.ReplaceAllString(cleaned, "\n")
	
	reMultiLine := regexp.MustCompile(`/\*.*?\*/`)
	cleaned = reMultiLine.ReplaceAllString(cleaned, "")
	
	// Remove trailing commas before ] or }
	reTrailingComma := regexp.MustCompile(`,(\s*[}\]])`)
	cleaned = reTrailingComma.ReplaceAllString(cleaned, "$1")
	
	return cleaned, nil
}

func parseJSON(rawInput string, repair bool) (interface{}, error) {
	rawInput = strings.TrimSpace(rawInput)
	
	// Try direct parsing first
	var data interface{}
	if err := json.Unmarshal([]byte(rawInput), &data); err == nil {
		return data, nil
	}
	
	// Extract JSON from Markdown code blocks
	if strings.Contains(rawInput, "```") {
		patterns := []string{
			"```json\\s*(.*?)\\s*```",
			"```\\s*(\\{.*?\\})\\s*```",
			"```\\s*(\\[.*?\\])\\s*```",
		}
		
		for _, pattern := range patterns {
			re := regexp.MustCompile(pattern)
			matches := re.FindAllStringSubmatch(rawInput, -1)
			
			for _, match := range matches {
				if len(match) > 1 {
					if err := json.Unmarshal([]byte(match[1]), &data); err == nil {
						return data, nil
					}
				}
			}
		}
	}
	
	// Try repair
	if repair {
		repaired, err := repairJSONString(rawInput)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrJSONRepair, err)
		}
		
		if err := json.Unmarshal([]byte(repaired), &data); err != nil {
			return nil, fmt.Errorf("%w: could not parse JSON even after repair: %v", ErrJSONProcessing, err)
		}
		return data, nil
	}
	
	return nil, ErrJSONProcessing
}

func safeJSONLoads(rawInput string, defaultValue interface{}, repair bool) interface{} {
	result, err := parseJSON(rawInput, repair)
	if err != nil {
		return defaultValue
	}
	return result
}

func extractJSONFromText(text string) []interface{} {
	var results []interface{}
	
	patterns := []string{
		`\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}`,
		`\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\]`,
	}
	
	for _, pattern := range patterns {
		re := regexp.MustCompile(pattern)
		matches := re.FindAllString(text, -1)
		
		for _, match := range matches {
			data, err := parseJSON(match, true)
			if err == nil {
				results = append(results, data)
			}
		}
	}
	
	return results
}

func main() {
	fileFlag := flag.Bool("file", false, "Input is a file path")
	noRepairFlag := flag.Bool("no-repair", false, "Disable JSON repair")
	prettyFlag := flag.Bool("pretty", false, "Pretty print output")
	flag.Parse()
	
	args := flag.Args()
	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "Error: input required\n")
		os.Exit(1)
	}
	
	input := args[0]
	
	var content string
	if *fileFlag {
		data, err := ioutil.ReadFile(input)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
			os.Exit(1)
		}
		content = string(data)
	} else {
		content = input
	}
	
	result, err := parseJSON(content, !*noRepairFlag)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	
	var output []byte
	if *prettyFlag {
		output, err = json.MarshalIndent(result, "", "  ")
	} else {
		output, err = json.Marshal(result)
	}
	
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error formatting output: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Println(string(output))
}
