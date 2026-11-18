// abstraction-provenance: {"artifact_sha256": "01f8bc0308153d58fb52a12f01e4e167c981262903f83ec95c247ebcc16633c4", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "go"}
// index.html — portiert nach go
// Quelle: html, Projects@Program-Derivation:public/index.html
// auch in: Projects@Vision-Check:public/index.html
// auch in: Projects@Weather-Check:public/index.html
// auch in: Projects@abstractions:public/index.html
// auch in: 5 weiteren Fundstellen
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"html/template"
	"os"
)

const htmlTemplate = `<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0; url={{.RedirectURL}}">
<title>{{.Title}}</title>
<link rel="canonical" href="{{.RedirectURL}}">
<script>location.replace('{{.RedirectURL}}');</script>
</head>
<body>
<p><a href="{{.RedirectURL}}">{{.LinkText}}</a></p>
</body>
</html>`

type PageData struct {
	RedirectURL string
	Title       string
	LinkText    string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	filename := os.Args[1]

	data := PageData{
		RedirectURL: "3d.html",
		Title:       "Weiterleitung zur 3D-Ansicht",
		LinkText:    "3D-Ansicht öffnen",
	}

	tmpl, err := template.New("index").Parse(htmlTemplate)
	if err != nil {
		panic(err)
	}

	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	err = tmpl.Execute(file, data)
	if err != nil {
		panic(err)
	}
}
