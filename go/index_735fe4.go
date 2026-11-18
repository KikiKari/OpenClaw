// abstraction-provenance: {"artifact_sha256": "2bd4bd7989b91fbe4f33279d1df6a7d8e961f5368ac8dd465454966a76af8efd", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "go"}
// index.html — portiert nach go
// Quelle: html, OpenClaw@main:index.html
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"html"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	filename := os.Args[1]
	
	// Create the HTML document structure
	doc := &HTMLDocument{
		Doctype: "html",
		Lang:    "de",
		Head: Head{
			Charset:     "utf-8",
			Title:       "OpenClaw",
			Description: "OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.",
			ThemeColor:  "#0b1020",
			Links: []Link{
				{Rel: "icon", Href: "/favicon.ico"},
				{Rel: "apple-touch-icon", Href: "/logo192.png"},
				{Rel: "manifest", Href: "/manifest.json"},
			},
			Viewport: "width=device-width, initial-scale=1",
		},
		Body: Body{
			NoScript: "You need to enable JavaScript to run this app.",
			RootDiv:  true,
			Comments: []string{
				"This HTML file is a template.\nIf you open it directly in the browser, you will see an empty page.\n\nYou can add webfonts, meta tags, or analytics to this file.\nThe build step will place the bundled scripts into the <body> tag.\n\nTo begin the development, run `npm start` or `yarn start`.\nTo create a production bundle, use `npm run build` or `yarn build`.",
			},
			Scripts: []Script{
				{Type: "module", Src: "/src/index.jsx"},
			},
		},
	}

	content := generateHTML(doc)
	
	err := os.WriteFile(filename, []byte(content), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}
}

// Data structures for HTML elements
type HTMLDocument struct {
	Doctype string
	Lang    string
	Head    Head
	Body    Body
}

type Head struct {
	Charset     string
	Title       string
	Description string
	ThemeColor  string
	Links       []Link
	Viewport    string
}

type Link struct {
	Rel  string
	Href string
}

type Body struct {
	NoScript string
	RootDiv  bool
	Comments []string
	Scripts  []Script
}

type Script struct {
	Type string
	Src  string
}

// Generate complete HTML document
func generateHTML(doc *HTMLDocument) string {
	result := fmt.Sprintf("<!DOCTYPE %s>\n", doc.Doctype)
	result += fmt.Sprintf("<html lang=\"%s\">\n", doc.Lang)
	result += generateHead(&doc.Head)
	result += generateBody(&doc.Body)
	result += "</html>\n"
	return result
}

func generateHead(head *Head) string {
	result := "  <head>\n"
	result += fmt.Sprintf("    <meta charset=\"%s\" />\n", head.Charset)
	
	for _, link := range head.Links {
		result += fmt.Sprintf("    <link rel=\"%s\" href=\"%s\" />\n", link.Rel, link.Href)
	}
	
	result += fmt.Sprintf("    <meta name=\"viewport\" content=\"%s\" />\n", head.Viewport)
	result += fmt.Sprintf("    <meta name=\"theme-color\" content=\"%s\" />\n", head.ThemeColor)
	result += fmt.Sprintf("    <meta name=\"description\" content=\"%s\" />\n", html.EscapeString(head.Description))
	result += fmt.Sprintf("    <title>%s</title>\n", head.Title)
	result += "  </head>\n"
	return result
}

func generateBody(body *Body) string {
	result := "  <body>\n"
	result += fmt.Sprintf("    <noscript>%s</noscript>\n", body.NoScript)
	
	if body.RootDiv {
		result += "    <div id=\"root\"></div>\n"
	}
	
	// Add comments
	for i, comment := range body.Comments {
		if i == 0 {
			result += "    <!--\n"
			result += fmt.Sprintf("      %s\n", comment)
			result += "    -->\n"
		} else {
			result += "    <!--\n"
			result += fmt.Sprintf("      %s\n", comment)
			result += "    -->\n"
		}
	}
	
	// Add scripts
	for _, script := range body.Scripts {
		result += fmt.Sprintf("  <script type=\"%s\" src=\"%s\"></script>\n", script.Type, script.Src)
	}
	
	result += "  </body>\n"
	return result
}
