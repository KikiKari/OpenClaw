// abstraction-provenance: {"artifact_sha256": "9225399a73afeba7b893813a9cdda0d50cb561eef9d8c5c18e2d72445f458110", "source_sha256": "47d390b58fc734629c213c66e58cb7f0c68bbd896bac294215d12289e5e21c07", "target_language": "go"}
// gateway-styles.css — portiert nach go
// Quelle: css, OpenClaw@main:examples/gateway-styles.css
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
	
	// Build the CSS content
	var builder strings.Builder
	
	// Header comment
	builder.WriteString("/* OpenClaw Gateway Dashboard */\n\n")
	
	// Reset and variables
	builder.WriteString("*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }\n\n")
	builder.WriteString(":root {\n")
	builder.WriteString("  --bg:       #0d1117;\n")
	builder.WriteString("  --surface:  #161b22;\n")
	builder.WriteString("  --border:   #30363d;\n")
	builder.WriteString("  --text:     #e6edf3;\n")
	builder.WriteString("  --muted:    #8b949e;\n")
	builder.WriteString("  --green:    #3fb950;\n")
	builder.WriteString("  --yellow:   #d29922;\n")
	builder.WriteString("  --red:      #f85149;\n")
	builder.WriteString("  --accent:   #58a6ff;\n")
	builder.WriteString("}\n\n")
	
	// Body styles
	builder.WriteString("body {\n")
	builder.WriteString("  background: var(--bg);\n")
	builder.WriteString("  color: var(--text);\n")
	builder.WriteString("  font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;\n")
	builder.WriteString("  min-height: 100vh;\n")
	builder.WriteString("}\n\n")
	
	// Header styles
	builder.WriteString("header {\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  align-items: center;\n")
	builder.WriteString("  gap: 1rem;\n")
	builder.WriteString("  padding: 1.25rem 2rem;\n")
	builder.WriteString("  border-bottom: 1px solid var(--border);\n")
	builder.WriteString("  background: var(--surface);\n")
	builder.WriteString("}\n\n")
	
	builder.WriteString("header h1 { font-size: 1.25rem; color: var(--accent); }\n\n")
	
	// Badge styles
	builder.WriteString(".badge {\n")
	builder.WriteString("  padding: .25rem .75rem;\n")
	builder.WriteString("  border-radius: 999px;\n")
	builder.WriteString("  font-size: .75rem;\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  background: var(--border);\n")
	builder.WriteString("  color: var(--muted);\n")
	builder.WriteString("}\n")
	builder.WriteString(".badge.ok    { background: #1a3a2a; color: var(--green); }\n")
	builder.WriteString(".badge.warn  { background: #3a2e0a; color: var(--yellow); }\n")
	builder.WriteString(".badge.error { background: #3a1010; color: var(--red); }\n\n")
	
	// Main content styles
	builder.WriteString("main { padding: 2rem; max-width: 960px; margin: 0 auto; }\n\n")
	
	// Grid styles
	builder.WriteString(".grid {\n")
	builder.WriteString("  display: grid;\n")
	builder.WriteString("  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));\n")
	builder.WriteString("  gap: 1rem;\n")
	builder.WriteString("  margin-bottom: 2rem;\n")
	builder.WriteString("}\n\n")
	
	// Card styles
	builder.WriteString(".card {\n")
	builder.WriteString("  background: var(--surface);\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("  border-radius: 8px;\n")
	builder.WriteString("  padding: 1.25rem;\n")
	builder.WriteString("  position: relative;\n")
	builder.WriteString("}\n\n")
	
	builder.WriteString(".card h2   { font-size: 1rem; margin-bottom: .25rem; }\n")
	builder.WriteString(".card .endpoint { font-size: .8rem; color: var(--muted); }\n\n")
	
	// Status dot styles
	builder.WriteString(".status-dot {\n")
	builder.WriteString("  position: absolute;\n")
	builder.WriteString("  top: 1.25rem;\n")
	builder.WriteString("  right: 1.25rem;\n")
	builder.WriteString("  width: 10px;\n")
	builder.WriteString("  height: 10px;\n")
	builder.WriteString("  border-radius: 50%;\n")
	builder.WriteString("  background: var(--border);\n")
	builder.WriteString("}\n")
	builder.WriteString(".status-dot.green { background: var(--green); box-shadow: 0 0 6px var(--green); }\n")
	builder.WriteString(".status-dot.red   { background: var(--red);   box-shadow: 0 0 6px var(--red); }\n\n")
	
	// Metrics styles
	builder.WriteString(".metrics h2 { font-size: 1rem; margin-bottom: 1rem; }\n\n")
	
	// Table styles
	builder.WriteString("table {\n")
	builder.WriteString("  width: 100%;\n")
	builder.WriteString("  border-collapse: collapse;\n")
	builder.WriteString("  font-size: .875rem;\n")
	builder.WriteString("}\n")
	builder.WriteString("th, td {\n")
	builder.WriteString("  padding: .625rem 1rem;\n")
	builder.WriteString("  text-align: left;\n")
	builder.WriteString("  border-bottom: 1px solid var(--border);\n")
	builder.WriteString("}\n")
	builder.WriteString("th { color: var(--muted); font-weight: 500; }\n")
	builder.WriteString("tr:last-child td { border-bottom: none; }\n")
	
	// Write to file
	err := os.WriteFile(filename, []byte(builder.String()), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to file: %v\n", err)
		os.Exit(1)
	}
}
