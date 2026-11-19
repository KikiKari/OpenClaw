// abstraction-provenance: {"artifact_sha256": "fd6ab5334582d910aca1af547d07d84863267a655c1aa19dbf6e8d875f40d945", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "go"}
// index.html — portiert nach go
// Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
// auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"text/template"
)

type MetaData struct {
	Charset     string
	Viewport    string
	Description string
	ThemeColor  string
	Favicon     string
	AppleIcon   string
	Title       string
}

type HTMLData struct {
	Lang string
	Meta MetaData
}

const htmlTemplate = `<!doctype html>
<html lang="{{.Lang}}">
  <head>
    <meta charset="{{.Meta.Charset}}" />
    <meta name="viewport" content="{{.Meta.Viewport}}" />
    <meta name="description" content="{{.Meta.Description}}" />
    <meta name="theme-color" content="{{.Meta.ThemeColor}}" />
    <link rel="icon" type="image/png" href="{{.Meta.Favicon}}" />
    <link rel="apple-touch-icon" href="{{.Meta.AppleIcon}}" />
    <title>{{.Meta.Title}}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>`

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: program <output-file>")
		os.Exit(1)
	}

	outputFile := os.Args[1]

	data := HTMLData{
		Lang: "de",
		Meta: MetaData{
			Charset:     "UTF-8",
			Viewport:    "width=device-width, initial-scale=1.0",
			Description: "Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.",
			ThemeColor:  "#ffffff",
			Favicon:     "/branding/staenderglobus-ios.png",
			AppleIcon:   "/branding/staenderglobus-ios.png",
			Title:       "TikTok LIVE Companion – Dokumentation",
		},
	}

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
}
