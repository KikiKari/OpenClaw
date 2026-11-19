// abstraction-provenance: {"artifact_sha256": "0a492f28b85be129539ece8f082e036c1312a783588953fbdb52db1d989e63fd", "source_sha256": "a243d1fdcbd0c82c97b2771c181438428885fd9c2feaed782f7e9eb8066fed59", "target_language": "go"}
// offscreen.html — portiert nach go
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	// Parameter für Ausgabedatei definieren
	output := flag.String("output", "", "Ausgabedatei (optional)")
	flag.Parse()

	// HTML-Inhalt generieren
	htmlContent := `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>TikTok LIVE Companion Sprachausgabe</title>
</head>
<body>
  <script src="offscreen.js"></script>
</body>
</html>`

	// Wenn Ausgabedatei angegeben, Inhalt schreiben
	if *output != "" {
		dir := filepath.Dir(*output)
		if dir != "." && dir != "/" {
			if err := os.MkdirAll(dir, 0755); err != nil {
				fmt.Fprintf(os.Stderr, "Fehler beim Erstellen des Verzeichnisses: %v\n", err)
				os.Exit(1)
			}
		}

		if err := os.WriteFile(*output, []byte(htmlContent), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der Datei: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Sonst auf stdout ausgeben
		fmt.Print(htmlContent)
	}
}
