// abstraction-provenance: {"artifact_sha256": "43de7d0828c5bff8f4b9b21f360e40382b65a998b91b1f5a27d9310a7c93ffdd", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "go"}
// chat.css — portiert nach go
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	outputFile := os.Args[1]
	
	// Define the imports that would normally be in chat.css
	imports := []string{
		"./chat/layout.css",
		"./chat/text.css",
		"./chat/grouped.css",
		"./chat/tool-cards.css",
		"./chat/sidebar.css",
	}

	// Create the content with proper CSS @import statements
	content := ""
	for _, importPath := range imports {
		content += fmt.Sprintf("@import \"%s\";\n", importPath)
	}

	// Ensure directory exists
	dir := filepath.Dir(outputFile)
	if err := os.MkdirAll(dir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating directory: %v\n", err)
		os.Exit(1)
	}

	// Write to file
	if err := os.WriteFile(outputFile, []byte(content), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}
}
