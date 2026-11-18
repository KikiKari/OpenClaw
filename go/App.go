// abstraction-provenance: {"artifact_sha256": "1c25aa5addbb63a46446f32a3b8c36af6a747c37f03ea328ac0a16b588f4df7d", "source_sha256": "08fdd65a33a6ec90261b4ce48be82ca8338400da1b321dfc70a57bedabfa45aa", "target_language": "go"}
// App.css — portiert nach go
// Quelle: css, OpenClaw@main:src/App.css
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"strings"
)

// CSSRule represents a CSS rule with selector and properties
type CSSRule struct {
	Selector   string
	Properties map[string]string
}

// StyleSheet represents a collection of CSS rules
type StyleSheet struct {
	Rules []CSSRule
}

// NewStyleSheet creates a new StyleSheet
func NewStyleSheet() *StyleSheet {
	return &StyleSheet{Rules: make([]CSSRule, 0)}
}

// AddRule adds a new rule to the stylesheet
func (ss *StyleSheet) AddRule(selector string, properties map[string]string) {
	rule := CSSRule{
		Selector:   selector,
		Properties: properties,
	}
	ss.Rules = append(ss.Rules, rule)
}

// String returns the CSS representation of the stylesheet
func (ss *StyleSheet) String() string {
	var builder strings.Builder
	
	for _, rule := range ss.Rules {
		builder.WriteString(rule.Selector)
		builder.WriteString(" {\n")
		
		for prop, value := range rule.Properties {
			builder.WriteString("  ")
			builder.WriteString(prop)
			builder.WriteString(": ")
			builder.WriteString(value)
			builder.WriteString(";\n")
		}
		
		builder.WriteString("}\n\n")
	}
	
	return builder.String()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: program <output-file>")
		os.Exit(1)
	}
	
	outputFile := os.Args[1]
	
	// Create new stylesheet
	styleSheet := NewStyleSheet()
	
	// :root rule
	styleSheet.AddRule(":root", map[string]string{
		"color-scheme": "dark",
		"font-family": "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
		"background": "#0b1020",
		"color": "#eef2ff",
	})
	
	// Universal selector rule
	styleSheet.AddRule("*", map[string]string{
		"box-sizing": "border-box",
	})
	
	// Body rule
	styleSheet.AddRule("body", map[string]string{
		"margin": "0",
		"min-width": "320px",
		"min-height": "100vh",
		"background": "radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem), radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem), linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%)",
	})
	
	// Page shell rule
	styleSheet.AddRule(".page-shell", map[string]string{
		"min-height": "100vh",
		"display": "grid",
		"place-items": "center",
		"padding": "2rem",
	})
	
	// Hero card rule
	styleSheet.AddRule(".hero-card", map[string]string{
		"width": "min(100%, 56rem)",
		"padding": "clamp(2rem, 6vw, 4.5rem)",
		"border": "1px solid rgba(148, 163, 184, 0.28)",
		"border-radius": "2rem",
		"background": "rgba(15, 23, 42, 0.72)",
		"box-shadow": "0 2rem 6rem rgba(0, 0, 0, 0.35)",
		"backdrop-filter": "blur(18px)",
	})
	
	// Eyebrow rule
	styleSheet.AddRule(".eyebrow", map[string]string{
		"margin": "0 0 1rem",
		"color": "#67e8f9",
		"font-size": "0.8rem",
		"font-weight": "700",
		"letter-spacing": "0.18em",
		"text-transform": "uppercase",
	})
	
	// H1 rule
	styleSheet.AddRule("h1", map[string]string{
		"margin": "0",
		"max-width": "12ch",
		"font-size": "clamp(2.75rem, 8vw, 6rem)",
		"line-height": "0.95",
		"letter-spacing": "-0.06em",
	})
	
	// Lead rule
	styleSheet.AddRule(".lead", map[string]string{
		"margin": "1.5rem 0 0",
		"max-width": "42rem",
		"color": "#cbd5e1",
		"font-size": "clamp(1.05rem, 2vw, 1.35rem)",
		"line-height": "1.65",
	})
	
	// Link grid rule
	styleSheet.AddRule(".link-grid", map[string]string{
		"display": "grid",
		"gap": "0.85rem",
		"margin-top": "2rem",
	})
	
	// Link grid anchor rule
	styleSheet.AddRule(".link-grid a", map[string]string{
		"display": "flex",
		"align-items": "center",
		"justify-content": "space-between",
		"gap": "1rem",
		"padding": "1rem 1.15rem",
		"border": "1px solid rgba(148, 163, 184, 0.25)",
		"border-radius": "1rem",
		"color": "#f8fafc",
		"text-decoration": "none",
		"background": "rgba(255, 255, 255, 0.06)",
	})
	
	// Link grid hover/focus rule
	styleSheet.AddRule(".link-grid a:hover,\n.link-grid a:focus-visible", map[string]string{
		"border-color": "rgba(103, 232, 249, 0.75)",
		"outline": "none",
		"background": "rgba(103, 232, 249, 0.12)",
	})
	
	// Write to file
	err := os.WriteFile(outputFile, []byte(styleSheet.String()), 0644)
	if err != nil {
		fmt.Printf("Error writing to file: %v\n", err)
		os.Exit(1)
	}
	
	fmt.Printf("CSS written to %s\n", outputFile)
}
