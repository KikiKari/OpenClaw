// abstraction-provenance: {"artifact_sha256": "f481d5a3b9a46560becba77b18d203762f98134d562c627cd46325f107937b7f", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "go"}
// style.css — portiert nach go
// Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

// CSSRule represents a CSS rule with selector and properties
type CSSRule struct {
	Selector   string
	Properties map[string]string
}

// CSSGroup represents a group of related CSS rules
type CSSGroup struct {
	Comment string
	Rules   []CSSRule
}

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: go run script.go <output-file>")
		os.Exit(1)
	}

	filename := os.Args[1]
	
	// Define CSS structure
	cssGroups := []CSSGroup{
		{
			Comment: "#content > h1:first-of-type",
			Rules: []CSSRule{
				{
					Selector: "#content > h1:first-of-type",
					Properties: map[string]string{
						"display": "none !important",
					},
				},
			},
		},
		{
			Comment: ".nav-tabs positioning",
			Rules: []CSSRule{
				{
					Selector: ".nav-tabs",
					Properties: map[string]string{
						"position": "relative",
					},
				},
			},
		},
		{
			Comment: ".nav-tabs-item opacity",
			Rules: []CSSRule{
				{
					Selector: ".nav-tabs-item > div",
					Properties: map[string]string{
						"opacity": "0",
					},
				},
			},
		},
		{
			Comment: ".nav-tabs-underline base styles",
			Rules: []CSSRule{
				{
					Selector: ".nav-tabs-underline",
					Properties: map[string]string{
						"position":        "absolute",
						"left":            "0",
						"bottom":          "0",
						"height":          "1.5px",
						"width":           "var(--nav-tab-underline-width, 0)",
						"transform":       "translateX(var(--nav-tab-underline-x, 0))",
						"background-color": "rgb(var(--primary))",
						"border-radius":   "999px",
						"pointer-events":  "none",
						"opacity":         "0",
						"transition":      "transform 260ms ease-in-out,\n    width 260ms ease-in-out,\n    opacity 160ms ease-in-out",
						"will-change":     "transform, width",
					},
				},
			},
		},
		{
			Comment: ".nav-tabs-underline dark theme",
			Rules: []CSSRule{
				{
					Selector: "html.dark .nav-tabs-underline",
					Properties: map[string]string{
						"background-color": "rgb(var(--primary-light))",
					},
				},
			},
		},
		{
			Comment: ".nav-tabs-underline ready state",
			Rules: []CSSRule{
				{
					Selector: ".nav-tabs-underline-ready .nav-tabs-underline",
					Properties: map[string]string{
						"opacity": "1",
					},
				},
			},
		},
	}

	// Template for CSS output
	cssTemplate := `{{range .}}/* {{.Comment}} */
{{range .Rules}}{{.Selector}} {
{{range $prop, $val := .Properties}}  {{$prop}}: {{$val}};
{{end}}}
{{end}}
{{end}}`

	tmpl, err := template.New("css").Parse(cssTemplate)
	if err != nil {
		fmt.Printf("Error parsing template: %v\n", err)
		os.Exit(1)
	}

	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	err = tmpl.Execute(file, cssGroups)
	if err != nil {
		fmt.Printf("Error executing template: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("CSS file written to %s\n", filename)
}
