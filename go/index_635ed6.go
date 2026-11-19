// abstraction-provenance: {"artifact_sha256": "287f367ff7c1b130c0e2f70a080413e76c71e13541434bfdf547fd14c7426129", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "go"}
// index.html — portiert nach go
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

type PageData struct {
	Lang    string
	Charset string
	Title   string
	AppDiv  string
	Script  string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: program <output-file>")
		os.Exit(1)
	}

	outputFile := os.Args[1]

	data := PageData{
		Lang:    "en",
		Charset: "utf-8",
		Title:   "QA Lab",
		AppDiv:  "app",
		Script:  "/src/main.ts",
	}

	htmlTemplate := `<!doctype html>
<html lang="{{.Lang}}">
  <head>
    <meta charset="{{.Charset}}" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <title>{{.Title}}</title>
  </head>
  <body>
    <div id="{{.AppDiv}}"></div>
    <script type="module" src="{{.Script}}"></script>
  </body>
</html>`

	tmpl, err := template.New("index").Parse(htmlTemplate)
	if err != nil {
		fmt.Printf("Error parsing template: %v\n", err)
		os.Exit(1)
	}

	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	err = tmpl.Execute(file, data)
	if err != nil {
		fmt.Printf("Error executing template: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("HTML file created: %s\n", outputFile)
}
