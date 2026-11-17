// abstraction-provenance: {"artifact_sha256": "b9e394bd4d50c97066a851d50f120766fc4987b5c98d73c3ce41fcfbe62459a6", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "go"}
// language_validator.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ValidationResult represents the validation results
type ValidationResult struct {
	Language string
	Valid    bool
	Errors   []string
	Warnings []string
	DocURL   string
}

// LanguageConfig holds configuration for each supported language
type LanguageConfig struct {
	Cmd    string
	Args   []string
	Linter string
}

// LanguageValidator validates scripts in various languages
type LanguageValidator struct {
	language     string
	useWebSearch bool
	config       LanguageConfig
}

// NewLanguageValidator creates a new validator for the specified language
func NewLanguageValidator(language string, useWebSearch bool) (*LanguageValidator, error) {
	languages := map[string]LanguageConfig{
		"bash":       {"bash", []string{"-n"}, "shellcheck"},
		"sh":         {"sh", []string{"-n"}, "shellcheck"},
		"python":     {"python3", []string{"-m", "py_compile"}, "pylint"},
		"perl":       {"perl", []string{"-c"}, "perlcritic"},
		"raku":       {"raku", []string{"-c"}, ""},
		"powershell": {"pwsh", []string{"-Command", "Get-Command"}, ""},
		"javascript": {"node", []string{"--check"}, "eslint"},
		"tcl":        {"tclsh", []string{}, ""},
	}

	config, exists := languages[strings.ToLower(language)]
	if !exists {
		return nil, fmt.Errorf("unsupported language: %s", language)
	}

	return &LanguageValidator{
		language:     strings.ToLower(language),
		useWebSearch: useWebSearch,
		config:       config,
	}, nil
}

// Validate performs syntax and linter checks on the script
func (v *LanguageValidator) Validate(scriptPath string) ValidationResult {
	errors := []string{}
	warnings := []string{}

	// Syntax check
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, v.config.Cmd, append(v.config.Args, scriptPath)...)
	output, err := cmd.CombinedOutput()

	if ctx.Err() == context.DeadlineExceeded {
		errors = append(errors, "Validation timeout")
	} else if err != nil {
		if _, ok := err.(*exec.Error); ok {
			errors = append(errors, fmt.Sprintf("Command not found: %s", v.config.Cmd))
			docURL := v.fetchDocs()
			return ValidationResult{v.language, false, errors, warnings, docURL}
		}
		errors = append(errors, string(output))
	}

	// Linter check if available
	if v.config.Linter != "" {
		linterWarnings := v.runLinter(scriptPath)
		warnings = append(warnings, linterWarnings...)
	}

	return ValidationResult{
		Language: v.language,
		Valid:    len(errors) == 0,
		Errors:   errors,
		Warnings: warnings,
	}
}

// runLinter executes the appropriate linter for the language
func (v *LanguageValidator) runLinter(scriptPath string) []string {
	warnings := []string{}

	switch v.config.Linter {
	case "shellcheck":
		cmd := exec.Command("shellcheck", "-f", "gcc", scriptPath)
		output, err := cmd.Output()
		if err != nil && len(output) > 0 {
			scanner := bufio.NewScanner(strings.NewReader(string(output)))
			for scanner.Scan() {
				warnings = append(warnings, scanner.Text())
			}
		}
	case "pylint":
		cmd := exec.Command("pylint", "--output-format=parseable", scriptPath)
		output, err := cmd.Output()
		if err != nil && len(output) > 0 {
			scanner := bufio.NewScanner(strings.NewReader(string(output)))
			for scanner.Scan() {
				warnings = append(warnings, scanner.Text())
			}
		}
	default:
		// Check if linter exists
		_, err := exec.LookPath(v.config.Linter)
		if err != nil {
			warnings = append(warnings, fmt.Sprintf("Linter not installed: %s", v.config.Linter))
		}
	}

	return warnings
}

// fetchDocs returns documentation URLs when web search is enabled
func (v *LanguageValidator) fetchDocs() string {
	if !v.useWebSearch {
		return ""
	}

	docs := map[string]string{
		"powershell": "https://docs.microsoft.com/powershell/",
		"raku":       "https://docs.raku.org/",
		"tcl":        "https://www.tcl.tk/",
	}

	if url, exists := docs[v.language]; exists {
		return url
	}
	return ""
}

func main() {
	if len(os.Args) < 3 {
		fmt.Println("Usage: language_validator.go <script> --lang <language> [--no-websearch]")
		os.Exit(1)
	}

	scriptPath := os.Args[1]
	var language string
	useWebSearch := true

	for i, arg := range os.Args {
		if arg == "--lang" && i+1 < len(os.Args) {
			language = os.Args[i+1]
		}
		if arg == "--no-websearch" {
			useWebSearch = false
		}
	}

	if language == "" {
		fmt.Println("Error: --lang parameter is required")
		os.Exit(1)
	}

	// Check if script file exists
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		fmt.Printf("Error: Script file does not exist: %s\n", scriptPath)
		os.Exit(1)
	}

	validator, err := NewLanguageValidator(language, useWebSearch)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	result := validator.Validate(scriptPath)

	fmt.Printf("Language: %s\n", result.Language)
	fmt.Printf("Valid: %t\n", result.Valid)

	if len(result.Errors) > 0 {
		fmt.Printf("Errors: %d\n", len(result.Errors))
		for i, err := range result.Errors {
			if i >= 5 {
				break
			}
			fmt.Printf("  - %s\n", strings.TrimSpace(err))
		}
	}

	if len(result.Warnings) > 0 {
		fmt.Printf("Warnings: %d\n", len(result.Warnings))
		for i, warn := range result.Warnings {
			if i >= 5 {
				break
			}
			fmt.Printf("  - %s\n", strings.TrimSpace(warn))
		}
	}

	if result.DocURL != "" {
		fmt.Printf("Docs: %s\n", result.DocURL)
	}

	if result.Valid {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}
