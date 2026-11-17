// abstraction-provenance: {"artifact_sha256": "6531098b6c2db8a48513364ec04283ccd2578d03872c9100dbfc18d63de77fec", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "go"}
// json_schema_validator.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
// auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/*
JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
Erweitert Pydantic mit externen Schema-Dateien.
*/

package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// JSONValidationError represents validation errors
type JSONValidationError struct {
	Message string
}

func (e *JSONValidationError) Error() string {
	return e.Message
}

// SchemaValidationError represents schema validation errors
type SchemaValidationError struct {
	Message string
}

func (e *SchemaValidationError) Error() string {
	return e.Message
}

// JSONProcessingError represents JSON processing errors
type JSONProcessingError struct {
	Message string
}

func (e *JSONProcessingError) Error() string {
	return e.Message
}

// parseJSON parses and optionally repairs JSON
func parseJSON(rawInput string, repair bool) (interface{}, error) {
	var data interface{}
	
	if err := json.Unmarshal([]byte(rawInput), &data); err != nil {
		if repair {
			// Try to repair common JSON issues
			repaired := repairJSON(rawInput)
			if err2 := json.Unmarshal([]byte(repaired), &data); err2 != nil {
				return nil, &JSONProcessingError{fmt.Sprintf("Failed to parse JSON even after repair: %v", err2)}
			}
			return data, nil
		}
		return nil, &JSONProcessingError{fmt.Sprintf("Invalid JSON: %v", err)}
	}
	return data, nil
}

// repairJSON attempts to fix common JSON formatting issues
func repairJSON(input string) string {
	// Remove trailing commas before } or ]
	re := regexp.MustCompile(`,\s*([\}\]])`)
	input = re.ReplaceAllString(input, "$1")
	
	// Fix single quotes to double quotes (basic approach)
	re = regexp.MustCompile(`'([^']*)':`)
	input = re.ReplaceAllString(input, "\"$1\":")
	
	// Add missing quotes around keys
	re = regexp.MustCompile(`([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:`)
	input = re.ReplaceAllString(input, `$1"$2":`)
	
	return input
}

// loadSchema loads a JSON schema from various sources
func loadSchema(schemaSource interface{}) (map[string]interface{}, error) {
	switch v := schemaSource.(type) {
	case map[string]interface{}:
		return v, nil
	case string:
		// Check if it's a file path
		if _, err := os.Stat(v); err == nil {
			content, err := ioutil.ReadFile(v)
			if err != nil {
				return nil, &SchemaValidationError{fmt.Sprintf("Could not read schema file: %v", err)}
			}
			
			var schema map[string]interface{}
			if err := json.Unmarshal(content, &schema); err != nil {
				return nil, &SchemaValidationError{fmt.Sprintf("Invalid JSON in schema file: %v", err)}
			}
			return schema, nil
		}
		
		// Try parsing as JSON string
		var schema map[string]interface{}
		if err := json.Unmarshal([]byte(v), &schema); err != nil {
			return nil, &SchemaValidationError{fmt.Sprintf("Schema not found or invalid: %s", v)}
		}
		return schema, nil
	default:
		return nil, &SchemaValidationError{"Unsupported schema source type"}
	}
}

// validateWithJSONSchema validates data against a JSON schema
func validateWithJSONSchema(data interface{}, schema interface{}) error {
	schemaDict, err := loadSchema(schema)
	if err != nil {
		return err
	}
	
	// Basic validation implementation
	if err := validateType(data, schemaDict); err != nil {
		return &SchemaValidationError{fmt.Sprintf("Schema validation failed: %v", err)}
	}
	
	return nil
}

// validateType performs basic type validation
func validateType(data interface{}, schema map[string]interface{}) error {
	if schemaType, ok := schema["type"]; ok {
		switch schemaType {
		case "object":
			if _, ok := data.(map[string]interface{}); !ok {
				return fmt.Errorf("expected object, got %T", data)
			}
			return validateObject(data.(map[string]interface{}), schema)
		case "array":
			if _, ok := data.([]interface{}); !ok {
				return fmt.Errorf("expected array, got %T", data)
			}
			return validateArray(data.([]interface{}), schema)
		case "string":
			if _, ok := data.(string); !ok {
				return fmt.Errorf("expected string, got %T", data)
			}
			return validateString(data.(string), schema)
		case "integer":
			switch v := data.(type) {
			case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
				return validateInteger(v, schema)
			case float64:
				if v == float64(int64(v)) {
					return validateInteger(int64(v), schema)
				}
				return fmt.Errorf("expected integer, got float")
			default:
				return fmt.Errorf("expected integer, got %T", data)
			}
		default:
			// For simplicity, we don't implement all types
			return nil
		}
	}
	return nil
}

// validateObject validates an object against schema
func validateObject(data map[string]interface{}, schema map[string]interface{}) error {
	if properties, ok := schema["properties"].(map[string]interface{}); ok {
		for key, propSchema := range properties {
			if value, exists := data[key]; exists {
				if ps, ok := propSchema.(map[string]interface{}); ok {
					if err := validateType(value, ps); err != nil {
						return fmt.Errorf("property '%s': %v", key, err)
					}
				}
			}
		}
	}
	
	if required, ok := schema["required"].([]interface{}); ok {
		for _, req := range required {
			if reqStr, ok := req.(string); ok {
				if _, exists := data[reqStr]; !exists {
					return fmt.Errorf("required property '%s' is missing", reqStr)
				}
			}
		}
	}
	
	return nil
}

// validateArray validates an array against schema
func validateArray(data []interface{}, schema map[string]interface{}) error {
	if items, ok := schema["items"].(map[string]interface{}); ok {
		for i, item := range data {
			if err := validateType(item, items); err != nil {
				return fmt.Errorf("array item [%d]: %v", i, err)
			}
		}
	}
	
	if minItems, ok := schema["minItems"].(float64); ok {
		if len(data) < int(minItems) {
			return fmt.Errorf("array must have at least %d items, got %d", int(minItems), len(data))
		}
	}
	
	return nil
}

// validateString validates a string against schema
func validateString(data string, schema map[string]interface{}) error {
	if enum, ok := schema["enum"].([]interface{}); ok {
		found := false
		for _, e := range enum {
			if eStr, ok := e.(string); ok && eStr == data {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("string '%s' not in enum %v", data, enum)
		}
	}
	
	if pattern, ok := schema["pattern"].(string); ok {
		re, err := regexp.Compile(pattern)
		if err != nil {
			return fmt.Errorf("invalid regex pattern: %v", err)
		}
		if !re.MatchString(data) {
			return fmt.Errorf("string '%s' does not match pattern '%s'", data, pattern)
		}
	}
	
	if minLength, ok := schema["minLength"].(float64); ok {
		if len(data) < int(minLength) {
			return fmt.Errorf("string length %d less than minimum %d", len(data), int(minLength))
		}
	}
	
	return nil
}

// validateInteger validates an integer against schema
func validateInteger(data interface{}, schema map[string]interface{}) error {
	var val int64
	
	switch v := data.(type) {
	case int:
		val = int64(v)
	case int8:
		val = int64(v)
	case int16:
		val = int64(v)
	case int32:
		val = int64(v)
	case int64:
		val = v
	case uint:
		val = int64(v)
	case uint8:
		val = int64(v)
	case uint16:
		val = int64(v)
	case uint32:
		val = int64(v)
	case uint64:
		val = int64(v)
	}
	
	if minimum, ok := schema["minimum"].(float64); ok {
		if float64(val) < minimum {
			return fmt.Errorf("value %d less than minimum %f", val, minimum)
		}
	}
	
	if maximum, ok := schema["maximum"].(float64); ok {
		if float64(val) > maximum {
			return fmt.Errorf("value %d greater than maximum %f", val, maximum)
		}
	}
	
	return nil
}

// validateAndConvert parses, repairs and validates JSON against schema
func validateAndConvert(rawInput string, schema interface{}, repair bool) (interface{}, error) {
	data, err := parseJSON(rawInput, repair)
	if err != nil {
		return nil, err
	}
	
	if err := validateWithJSONSchema(data, schema); err != nil {
		return nil, err
	}
	
	return data, nil
}

// SchemaBuilder helper for creating JSON schemas
type SchemaBuilder struct{}

// Object creates an object schema
func (sb *SchemaBuilder) Object(properties map[string]interface{}, required []string) map[string]interface{} {
	schema := map[string]interface{}{
		"type":       "object",
		"properties": properties,
	}
	
	if required != nil {
		requiredInterface := make([]interface{}, len(required))
		for i, r := range required {
			requiredInterface[i] = r
		}
		schema["required"] = requiredInterface
	}
	
	return schema
}

// String creates a string schema
func (sb *SchemaBuilder) String(enum []string, pattern string, minLength *int) map[string]interface{} {
	schema := map[string]interface{}{"type": "string"}
	
	if enum != nil {
		enumInterface := make([]interface{}, len(enum))
		for i, e := range enum {
			enumInterface[i] = e
		}
		schema["enum"] = enumInterface
	}
	
	if pattern != "" {
		schema["pattern"] = pattern
	}
	
	if minLength != nil {
		schema["minLength"] = *minLength
	}
	
	return schema
}

// Integer creates an integer schema
func (sb *SchemaBuilder) Integer(minimum *int, maximum *int) map[string]interface{} {
	schema := map[string]interface{}{"type": "integer"}
	
	if minimum != nil {
		schema["minimum"] = *minimum
	}
	
	if maximum != nil {
		schema["maximum"] = *maximum
	}
	
	return schema
}

// Array creates an array schema
func (sb *SchemaBuilder) Array(items map[string]interface{}, minItems *int) map[string]interface{} {
	schema := map[string]interface{}{
		"type":  "array",
		"items": items,
	}
	
	if minItems != nil {
		schema["minItems"] = *minItems
	}
	
	return schema
}

// Args represents command line arguments
type Args struct {
	Input  string
	Schema string
	File   bool
	Repair bool
}

// parseArgs parses command line arguments
func parseArgs() (*Args, error) {
	args := &Args{
		Repair: true,
	}
	
	if len(os.Args) < 2 {
		return nil, errors.New("not enough arguments")
	}
	
	// Simple argument parsing
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--schema", "-s":
			if i+1 < len(os.Args) {
				args.Schema = os.Args[i+1]
				i++
			}
		case "--file", "-f":
			args.File = true
		case "--repair", "-r":
			args.Repair = true
		default:
			if args.Input == "" {
				args.Input = arg
			}
		}
	}
	
	if args.Schema == "" {
		return nil, errors.New("--schema/-s is required")
	}
	
	return args, nil
}

func main() {
	args, err := parseArgs()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing arguments: %v\n", err)
		os.Exit(1)
	}
	
	// Load input (auto-detect file vs string)
	var rawInput string
	inputPath := args.Input
	
	if args.File || (func() bool {
		_, err := os.Stat(inputPath)
		return err == nil
	}()) {
		content, err := ioutil.ReadFile(inputPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "✗ Could not read input file: %v\n", err)
			os.Exit(1)
		}
		rawInput = string(content)
	} else {
		rawInput = args.Input
	}
	
	result, err := validateAndConvert(rawInput, args.Schema, args.Repair)
	if err != nil {
		fmt.Fprintf(os.Stderr, "✗ Validation failed: %v\n", err)
		os.Exit(1)
	}
	
	jsonResult, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "✗ Failed to format result: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Println(string(jsonResult))
	fmt.Fprintln(os.Stderr, "\n✓ Validation passed")
}
