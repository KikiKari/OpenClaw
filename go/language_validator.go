// abstraction-provenance: {"artifact_sha256": "d342fc9960df606e9ac97918a159bf283d2d0a6e736f9ad1dacb0fa8594f44ba", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "go"}
// language_validator.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
Multi-language script validator supporting 8+ languages.
WebSearch integration for documentation lookup.
*/

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type ValidationResult struct {
	Language string
	Valid    bool
	Errors   []string
	Warnings []string
	DocURL   string
}

type LanguageConfig struct {
	Cmd    string
	Args   []string
	Linter string
}

var Languages = map[string]LanguageConfig{
	"bash":       {"bash", []string{"-n"}, "shellcheck"},
	"sh":         {"sh", []string{"-n"}, "shellcheck"},
	"python":     {"python3", []string{"-m", "py_compile"}, "pylint"},
	"perl":       {"perl", []string{"-c"}, "perlcritic"},
	"raku":       {"raku", []string{"-c"}, ""},
	"powershell": {"pwsh", []string{"-Command", "Get-Command"}, ""},
	"javascript": {"node", []string{"--check"}, "eslint"},
	"tcl":        {"tclsh", []string{}, ""},
}

type LanguageValidator struct {
	language string
	useWebsearch bool
	config   LanguageConfig
}

func NewLanguageValidator(language string, useWebsearch bool) (*LanguageValidator, error) {
	language = strings.ToLower(language)
	config, exists := Languages[language]
	if !exists {
		return nil, fmt.Errorf("unsupported language: %s", language)
	}
	
	return &LanguageValidator{
		language: language,
		useWebsearch: useWebsearch,
		config:   config,
	}, nil
}

func (v *LanguageValidator) Validate(scriptPath string) ValidationResult {
	errors := []string{}
	warnings := []string{}
	
	// Syntax check
	cmd := exec.Command(v.config.Cmd, append(v.config.Args, scriptPath)...)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd.Dir = filepath.Dir(scriptPath)
	result, err := cmd.CombinedOutput()
	
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			errors = append(errors, "Validation timeout")
		} else if _, ok := err.(*exec.Error); ok {
			errors = append(errors, fmt.Sprintf("Command not found: %s", v.config.Cmd))
			if v.useWebsearch {
				docURL := v.fetchDocs()
				return ValidationResult{v.language, false, errors, warnings, docURL}
			}
		} else {
			errors = append(errors, string(result))
		}
	}
	
	// Linter check if available
	if v.config.Linter != "" {
		linterWarnings := v.runLinter(scriptPath)
		warnings = append(warnings, linterWarnings...)
	}
	
	valid := len(errors) == 0
	docURL := ""
	if !valid && v.useWebsearch {
		docURL = v.fetchDocs()
	}
	
	return ValidationResult{
		Language: v.language,
		Valid:    valid,
		Errors:   errors,
		Warnings: warnings,
		DocURL:   docURL,
	}
}

func (v *LanguageValidator) runLinter(scriptPath string) []string {
	warnings := []string{}
	
	switch v.config.Linter {
	case "shellcheck":
		cmd := exec.Command("shellcheck", "-f", "gcc", scriptPath)
		output, err := cmd.Output()
		if err != nil && len(output) > 0 {
			lines := strings.Split(strings.TrimSpace(string(output)), "\n")
			warnings = append(warnings, lines...)
		}
	case "pylint":
		cmd := exec.Command("pylint", "--output-format=parseable", scriptPath)
		output, err := cmd.Output()
		if err != nil && len(output) > 0 {
			lines := strings.Split(strings.TrimSpace(string(output)), "\n")
			warnings = append(warnings, lines...)
		}
	default:
		// For other linters or when not installed
		_, err := exec.LookPath(v.config.Linter)
		if err != nil {
			warnings = append(warnings, fmt.Sprintf("Linter not installed: %s", v.config.Linter))
		}
	}
	
	return warnings
}

func (v *LanguageValidator) fetchDocs() string {
	if !v.useWebsearch {
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
		fmt.Println("Usage: language_validator.go <script> --lang <language>")
		os.Exit(1)
	}
	
	scriptPath := ""
	language := ""
	useWebsearch := true
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		if arg == "--lang" && i+1 < len(os.Args) {
			language = os.Args[i+1]
			i++
		} else if arg == "--no-websearch" {
			useWebsearch = false
		} else if scriptPath == "" && !strings.HasPrefix(arg, "--") {
			scriptPath = arg
		}
	}
	
	if scriptPath == "" || language == "" {
		fmt.Println("Error: script path and language are required")
		os.Exit(1)
	}
	
	validator, err := NewLanguageValidator(language, useWebsearch)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	
	result := validator.Validate(scriptPath)
	
	fmt.Printf("Language: %s\n", result.Language)
	fmt.Printf("Valid: %t\n", result.Valid)
	
	if len(result.Errors) > 0 {
		errorCount := len(result.Errors)
		if errorCount > 5 {
			errorCount = 5
		}
		fmt.Printf("Errors: %d\n", len(result.Errors))
		for i := 0; i < errorCount; i++ {
			fmt.Printf("  - %s\n", strings.TrimSpace(result.Errors[i]))
		}
	}
	
	if len(result.Warnings) > 0 {
		warningCount := len(result.Warnings)
		if warningCount > 5 {
			warningCount = 5
		}
		fmt.Printf("Warnings: %d\n", len(result.Warnings))
		for i := 0; i < warningCount; i++ {
			fmt.Printf("  - %s\n", strings.TrimSpace(result.Warnings[i]))
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
