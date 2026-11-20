// abstraction-provenance: {"artifact_sha256": "62d2a2f974c020eb3e6a299288b73c541559192458a9e58f81f8543cfca88056", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "go"}
// format-generated-module.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

func formatGeneratedModule(source string, repoRoot string, outputPath string, errorLabel string) (string, error) {
	resolvedRepoRoot, err := filepath.Abs(repoRoot)
	if err != nil {
		return "", fmt.Errorf("failed to resolve repo root: %v", err)
	}

	var resolvedOutputPath string
	if filepath.IsAbs(outputPath) {
		relPath, err := filepath.Rel(resolvedRepoRoot, outputPath)
		if err != nil {
			return "", fmt.Errorf("failed to compute relative path: %v", err)
		}
		resolvedOutputPath = filepath.Join(resolvedRepoRoot, relPath)
	} else {
		resolvedOutputPath = filepath.Join(resolvedRepoRoot, outputPath)
	}

	directFormatterPath := filepath.Join(resolvedRepoRoot, "node_modules", ".bin", "oxfmt")
	useDirectFormatter := runtime.GOOS != "windows"
	if useDirectFormatter {
		if _, err := os.Stat(directFormatterPath); os.IsNotExist(err) {
			useDirectFormatter = false
		}
	}

	var command string
	if useDirectFormatter {
		command = directFormatterPath
	} else {
		command = "pnpm"
	}

	tempDir, err := ioutil.TempDir("", "openclaw-generated-format-*")
	if err != nil {
		return "", fmt.Errorf("failed to create temporary directory: %v", err)
	}
	defer os.RemoveAll(tempDir)

	tempOutputPath := filepath.Join(tempDir, filepath.Base(resolvedOutputPath))
	
	err = ioutil.WriteFile(tempOutputPath, []byte(source), 0644)
	if err != nil {
		return "", fmt.Errorf("failed to write temporary file: %v", err)
	}

	var args []string
	if useDirectFormatter {
		args = []string{"--write", tempOutputPath}
	} else {
		args = []string{"exec", "oxfmt", "--write", tempOutputPath}
	}

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command(command, args...)
		cmd.Dir = resolvedRepoRoot
	} else {
		cmd = exec.Command(command, args...)
		cmd.Dir = resolvedRepoRoot
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		details := string(output)
		if details == "" {
			details = "unknown formatter failure"
		}
		return "", fmt.Errorf("failed to format generated %s: %s", errorLabel, details)
	}

	formattedContent, err := ioutil.ReadFile(tempOutputPath)
	if err != nil {
		return "", fmt.Errorf("failed to read formatted file: %v", err)
	}

	return string(formattedContent), nil
}
