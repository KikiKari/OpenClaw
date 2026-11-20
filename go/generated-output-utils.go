// abstraction-provenance: {"artifact_sha256": "3259669d3fe8f27f49488e237999acc16352fb44e8681d2971f7780066dd357c", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "go"}
// generated-output-utils.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// writeGeneratedOutput writes the generated output to a file if it has changed.
func writeGeneratedOutput(params WriteGeneratedOutputParams) GeneratedOutputResult {
	outputPath := filepath.Join(params.RepoRoot, params.OutputPath)
	current := readIfExists(outputPath)
	changed := current != params.Next

	if params.Check {
		return GeneratedOutputResult{
			Changed:    changed,
			Wrote:      false,
			OutputPath: outputPath,
		}
	}

	wrote := writeTextFileIfChanged(outputPath, params.Next)
	return GeneratedOutputResult{
		Changed:    changed,
		Wrote:      wrote,
		OutputPath: outputPath,
	}
}

// reportGeneratedOutputCli reports the generated output to the CLI.
func reportGeneratedOutputCli(params ReportGeneratedOutputCliParams) {
	// Get the current executable path
	executable, err := os.Executable()
	if err != nil {
		return
	}

	// Compare with the importMetaUrl equivalent
	if params.ImportMetaUrl != "file://"+executable {
		return
	}

	check := false
	for _, arg := range os.Args {
		if arg == "--check" {
			check = true
			break
		}
	}

	result := params.Run(check)
	if !result.Changed {
		return
	}

	relativeOutputPath, err := filepath.Rel(os.Getenv("PWD"), result.OutputPath)
	if err != nil {
		relativeOutputPath = result.OutputPath
	}

	if check {
		fmt.Fprintf(os.Stderr, "[%s] stale generated output at %s\n", params.Label, relativeOutputPath)
		os.Exit(1)
		return
	}

	fmt.Printf("[%s] wrote %s\n", params.Label, relativeOutputPath)
}

// Helper functions (these would need to be implemented based on your specific requirements)

type WriteGeneratedOutputParams struct {
	RepoRoot   string
	OutputPath string
	Next       string
	Check      bool
}

type GeneratedOutputResult struct {
	Changed    bool
	Wrote      bool
	OutputPath string
}

type ReportGeneratedOutputCliParams struct {
	ImportMetaUrl string
	Label         string
	Run           func(check bool) GeneratedOutputResult
}

func readIfExists(path string) string {
	content, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(content)
}

func writeTextFileIfChanged(path, content string) bool {
	existingContent := readIfExists(path)
	if existingContent == content {
		return false
	}
	
	err := os.WriteFile(path, []byte(content), 0644)
	return err == nil
}
