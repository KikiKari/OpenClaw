// abstraction-provenance: {"artifact_sha256": "f562e0dc1c67efd5f9c562b768f62ef43fa608474f36bcef6699e1ca6bd1121f", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "go"}
// copy-plugin-sdk-root-alias.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
)

// writeTextFileIfChanged writes content to file only if it differs from existing content
func writeTextFileIfChanged(filename, content string) error {
	existingContent, err := ioutil.ReadFile(filename)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	
	if string(existingContent) != content {
		// Create directory if it doesn't exist
		dir := filepath.Dir(filename)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
		
		return ioutil.WriteFile(filename, []byte(content), 0644)
	}
	
	return nil
}

// copyPluginSdkRootAlias copies root-alias.cjs from src to dist
func copyPluginSdkRootAlias(cwd string) error {
	if cwd == "" {
		var err error
		cwd, err = os.Getwd()
		if err != nil {
			return err
		}
	}
	
	source := filepath.Join(cwd, "src", "plugin-sdk", "root-alias.cjs")
	target := filepath.Join(cwd, "dist", "plugin-sdk", "root-alias.cjs")
	
	content, err := ioutil.ReadFile(source)
	if err != nil {
		return err
	}
	
	return writeTextFileIfChanged(target, string(content))
}

func main() {
	cwd := ""
	if len(os.Args) > 1 {
		cwd = os.Args[1]
	}
	
	if err := copyPluginSdkRootAlias(cwd); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
