// abstraction-provenance: {"artifact_sha256": "20c4c543558cdc69a84d8fdd0cb339060c112d5820c60727aee4e69d570df233", "source_sha256": "7fc810e8bcb817cb81407c2ad604d4bd70dce9f3ff8cb2bbfbcacfec00febd1c", "target_language": "go"}
// status-overview.html — portiert nach go
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

type PageData struct {
	Title       string
	Description string
	Stylesheet  string
	Scripts     []string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	outputFile := os.Args[1]

	data := PageData{
		Title:       "STATUS-Overview",
		Description: "LIVE-Übersicht",
		Stylesheet:  "status-overview.css",
		Scripts: []string{
			"vendor-mpegts.js",
			"status-overview-player.js",
		},
	}

	tmpl := `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{.Title}}</title>
<link rel="stylesheet" href="{{.Stylesheet}}">
</head>
<body>
<main id="grid" aria-label="{{.Description}}"></main>
{{range .Scripts}}<script src="{{.}}"></script>
{{end}}</body>
</html>`

	t, err := template.New("page").Parse(tmpl)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing template: %v\n", err)
		os.Exit(1)
	}

	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	err = t.Execute(file, data)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error executing template: %v\n", err)
		os.Exit(1)
	}
}
