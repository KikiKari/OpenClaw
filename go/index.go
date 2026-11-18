// abstraction-provenance: {"artifact_sha256": "7de87f7fbc1e645799fa69638e075f68c00af338f3f3bc3ebd1084779d33b59b", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "go"}
// index.css — portiert nach go
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	filename := os.Args[1]
	
	// Define the CSS rules as structured data
	cssRules := map[string]map[string]string{
		"body": {
			"margin": "0",
			"font-family": "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif",
			"-webkit-font-smoothing": "antialiased",
			"-moz-osx-font-smoothing": "grayscale",
		},
		"code": {
			"font-family": "source-code-pro, Menlo, Monaco, Consolas, 'Courier New', monospace",
		},
	}

	// Generate CSS content
	var cssBuilder strings.Builder
	
	for selector, properties := range cssRules {
		cssBuilder.WriteString(fmt.Sprintf("%s {\n", selector))
		for property, value := range properties {
			cssBuilder.WriteString(fmt.Sprintf("  %s: %s;\n", property, value))
		}
		cssBuilder.WriteString("}\n\n")
	}

	cssContent := cssBuilder.String()

	// Write to file
	err := os.WriteFile(filename, []byte(cssContent), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to file: %v\n", err)
		os.Exit(1)
	}
}
