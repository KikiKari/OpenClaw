// abstraction-provenance: {"artifact_sha256": "3a3b884bedf0946f962e83dff008093b1c00c765d351293ff7403b7c9b30d574", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "go"}
// styles.css — portiert nach go
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

type Stylesheet struct {
	Imports []string
	Vars    map[string]string
	Classes map[string]map[string]string
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <output-file>")
		os.Exit(1)
	}

	outputFile := os.Args[1]
	
	stylesheet := &Stylesheet{
		Imports: []string{
			"./styles/base.css",
			"./styles/layout.css",
			"./styles/layout.mobile.css",
			"./styles/components.css",
			"./styles/chat.css",
			"./styles/config.css",
			"./styles/usage.css",
			"./styles/dreams.css",
			"@create-markdown/preview/themes/system.css",
		},
		Vars: map[string]string{},
		Classes: map[string]map[string]string{
			".cm-preview": {
				"--cm-mono":   "var(--mono)",
				"--cm-link":   "var(--accent)",
				"--cm-info":   "var(--info)",
				"--cm-warning": "var(--warn)",
				"--cm-success": "var(--ok)",
				"--cm-danger":  "var(--danger)",
			},
		},
	}

	cssContent := generateCSS(stylesheet)
	
	err := os.WriteFile(outputFile, []byte(cssContent), 0644)
	if err != nil {
		fmt.Printf("Error writing to file: %v\n", err)
		os.Exit(1)
	}
}

func generateCSS(s *Stylesheet) string {
	tmpl := `{{range .Imports}}@import "{{.}}";
{{end}}
{{range $class, $rules := .Classes}}{{$class}} {
{{range $prop, $val := $rules}}  {{$prop}}: {{$val}};
{{end}}}
{{end}}`
	
	t := template.Must(template.New("css").Parse(tmpl))
	var buf []byte
	writer := &buf
	
	err := t.Execute(&buf, s)
	if err != nil {
		panic(err)
	}
	
	return string(*writer)
}
