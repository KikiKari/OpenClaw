// abstraction-provenance: {"artifact_sha256": "b48b5a4923f4485f4ac3e6a01c437b930f3eca79d0fe69609066ed1eadbb2670", "source_sha256": "a5de51b02b40bbdeafb7fb0f4da19091ec351b10a9160307085ebcef403cdd67", "target_language": "go"}
// offscreen.html — portiert nach go
// Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
// auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
// auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/browser-extension/offscreen.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

const htmlTemplate = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>TikTok LIVE Companion Sprachausgabe</title>
</head>
<body>
  <script src="offscreen.js"></script>
</body>
</html>
`

func main() {
	// Prüfe Kommandozeilenargumente
	if len(os.Args) != 2 {
		fmt.Println("Verwendung: go run script.go <output-file>")
		os.Exit(1)
	}

	filename := os.Args[1]

	// Erstelle Template
	tmpl, err := template.New("offscreen").Parse(htmlTemplate)
	if err != nil {
		fmt.Printf("Fehler beim Erstellen des Templates: %v\n", err)
		os.Exit(1)
	}

	// Öffne Datei zum Schreiben
	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("Fehler beim Erstellen der Datei %s: %v\n", filename, err)
		os.Exit(1)
	}
	defer file.Close()

	// Führe Template aus und schreibe in Datei
	err = tmpl.Execute(file, nil)
	if err != nil {
		fmt.Printf("Fehler beim Schreiben in die Datei: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("HTML-Datei wurde erfolgreich erstellt: %s\n", filename)
}
