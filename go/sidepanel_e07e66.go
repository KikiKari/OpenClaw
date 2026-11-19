// abstraction-provenance: {"artifact_sha256": "272159042385ea9bcf0e386e1fdb9acec5183bbac935e97109ecf7d3bb0e284f", "source_sha256": "e07e663714dd74eaf25d7c73a2e4fae09e726ce450182ddaeb0637ae76e40ad5", "target_language": "go"}
// sidepanel.css — portiert nach go
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/sidepanel.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/sidepanel.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"text/template"
)

type CSSRule struct {
	Selector string
	Props    map[string]string
}

type MediaQuery struct {
	Query string
	Rules []CSSRule
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run script.go <output-file>")
		os.Exit(1)
	}

	filename := os.Args[1]
	file, err := os.Create(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	// Define CSS rules programmatically
	rules := []CSSRule{
		{
			Selector: ":root",
			Props: map[string]string{
				"color-scheme":                    "light dark",
				"font-family":                     `Inter, "Segoe UI", system-ui, sans-serif`,
				"--accent":                        "#fe2c55",
				"--accent-dark":                   "#d91f46",
				"--surface":                       "color-mix(in srgb, Canvas 94%, CanvasText 6%)",
				"--border":                        "color-mix(in srgb, CanvasText 18%, transparent)",
				"--muted":                         "color-mix(in srgb, CanvasText 65%, transparent)",
				"--good":                          "#147d45",
				"--warn":                          "#a65f00",
				"--bad":                           "#b42318",
			},
		},
		{Selector: "*", Props: map[string]string{"box-sizing": "border-box"}},
		{Selector: "body", Props: map[string]string{
			"margin":       "0",
			"background":   "Canvas",
			"color":        "CanvasText",
			"min-width":    "300px",
		}},
		{Selector: "header", Props: map[string]string{
			"padding":          "11px 18px",
			"background":       "linear-gradient(135deg, color-mix(in srgb, var(--accent) 18%, Canvas), Canvas)",
			"border-bottom":    "1px solid var(--border)",
		}},
		{Selector: "h2", Props: map[string]string{
			"margin":     "0",
			"font-size":  "15px",
		}},
		{Selector: "main", Props: map[string]string{
			"padding":                 "14px",
			"display":                 "grid",
			"grid-template-columns":   "minmax(0, 1fr)",
			"gap":                     "12px",
		}},
		{Selector: "section", Props: map[string]string{
			"min-width":    "0",
			"padding":     "14px",
			"background":   "var(--surface)",
			"border":       "1px solid var(--border)",
			"border-radius": "13px",
			"box-shadow":   "0 5px 20px color-mix(in srgb, CanvasText 6%, transparent)",
		}},
		{Selector: ".section-title, .button-row", Props: map[string]string{
			"display":         "flex",
			"align-items":     "center",
			"justify-content": "space-between",
			"gap":             "8px",
		}},
		{Selector: ".section-title", Props: map[string]string{
			"min-width":  "0",
			"flex-wrap":  "wrap",
		}},
		{Selector: ".title-actions", Props: map[string]string{
			"display":      "flex",
			"min-width":    "0",
			"max-width":    "100%",
			"align-items":  "center",
			"justify-content": "flex-end",
			"flex-wrap":    "wrap",
			"gap":          "6px",
		}},
		{Selector: ".status-led", Props: map[string]string{
			"width":        "11px",
			"height":       "11px",
			"flex":         "0 0 11px",
			"border-radius": "50%",
			"background":   "var(--bad)",
			"box-shadow":   "0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)",
		}},
		{Selector: ".status-led.on", Props: map[string]string{
			"background": "var(--good)",
			"box-shadow": "0 0 0 3px color-mix(in srgb, var(--good) 17%, transparent)",
		}},
		{Selector: ".status-led.off", Props: map[string]string{
			"background": "var(--bad)",
		}},
		{Selector: ".button-row", Props: map[string]string{
			"justify-content": "flex-start",
			"flex-wrap":       "wrap",
			"margin-top":      "10px",
		}},
		{Selector: "button", Props: map[string]string{
			"border":       "0",
			"border-radius": "9px",
			"padding":      "9px 11px",
			"font":         "inherit",
			"font-size":    "12px",
			"font-weight":  "700",
			"cursor":       "pointer",
		}},
		{Selector: "button:disabled", Props: map[string]string{
			"cursor":  "not-allowed",
			"opacity": ".55",
		}},
		{Selector: ".compact", Props: map[string]string{"padding": "7px 9px"}},
		{Selector: ".settings-button", Props: map[string]string{
			"min-width":  "34px",
			"font-size":  "17px",
			"line-height": "1",
		}},
		{Selector: ".primary", Props: map[string]string{
			"color":      "white",
			"background": "var(--accent)",
		}},
		{Selector: ".primary:hover", Props: map[string]string{
			"background": "var(--accent-dark)",
		}},
		{Selector: ".secondary", Props: map[string]string{
			"color":       "CanvasText",
			"background":  "color-mix(in srgb, CanvasText 9%, Canvas)",
			"border":      "1px solid var(--border)",
		}},
		{Selector: ".ghost", Props: map[string]string{
			"color":      "var(--muted)",
			"background": "transparent",
		}},
		{Selector: ".danger-outline", Props: map[string]string{
			"color":        "var(--bad)",
			"border-color": "color-mix(in srgb, var(--bad) 45%, transparent)",
		}},
		{Selector: "#enable-captions", Props: map[string]string{
			"width":      "100%",
			"margin-top": "11px",
		}},
		{Selector: ".muted", Props: map[string]string{"color": "var(--muted)"}},
		{Selector: ".small", Props: map[string]string{
			"font-size":   "12px",
			"line-height": "1.45",
		}},
		{Selector: "#page-title", Props: map[string]string{
			"margin":          "0",
			"font-size":       "12px",
			"white-space":     "nowrap",
			"overflow":        "hidden",
			"text-overflow":   "ellipsis",
		}},
		{Selector: ".status-grid", Props: map[string]string{
			"display":               "grid",
			"grid-template-columns": "1fr 1fr",
			"gap":                  "7px",
			"margin-top":           "11px",
		}},
		{Selector: ".status", Props: map[string]string{
			"padding":     "9px",
			"border":      "1px solid var(--border)",
			"border-radius": "9px",
			"background":  "Canvas",
		}},
		{Selector: ".status-label", Props: map[string]string{
			"display":      "block",
			"color":        "var(--muted)",
			"font-size":    "10px",
			"text-transform": "uppercase",
			"letter-spacing": ".06em",
		}},
		{Selector: ".status-value", Props: map[string]string{
			"display":    "block",
			"margin-top": "3px",
			"font-size":  "12px",
			"font-weight": "750",
		}},
		{Selector: ".good .status-value", Props: map[string]string{"color": "var(--good)"}},
		{Selector: ".warn .status-value", Props: map[string]string{"color": "var(--warn)"}},
		{Selector: ".bad .status-value", Props: map[string]string{"color": "var(--bad)"}},
		{Selector: ".count", Props: map[string]string{
			"min-width":      "25px",
			"padding":        "3px 7px",
			"border-radius":  "999px",
			"background":     "color-mix(in srgb, var(--accent) 15%, Canvas)",
			"color":          "var(--accent)",
			"text-align":     "center",
			"font-size":      "11px",
			"font-weight":    "800",
		}},
		{Selector: ".count-button", Props: map[string]string{
			"border":     "1px solid color-mix(in srgb, var(--accent) 30%, transparent)",
			"cursor":     "pointer",
		}},
		{Selector: ".count-button:hover, .count-button:focus-visible", Props: map[string]string{
			"background": "color-mix(in srgb, var(--accent) 25%, Canvas)",
		}},
		{Selector: ".live-indicator", Props: map[string]string{
			"padding":        "3px 7px",
			"border-radius":  "999px",
			"background":     "color-mix(in srgb, var(--muted) 15%, Canvas)",
			"color":          "var(--muted)",
			"font-size":      "10px",
			"font-weight":    "800",
			"text-transform": "uppercase",
		}},
		{Selector: ".live-indicator.active", Props: map[string]string{
			"background": "color-mix(in srgb, var(--good) 16%, Canvas)",
			"color":       "var(--good)",
		}},
		{Selector: ".stats-grid .status-value", Props: map[string]string{
			"font-size":            "16px",
			"font-variant-numeric": "tabular-nums",
		}},
		{Selector: ".chat-list", Props: map[string]string{
			"display":    "grid",
			"gap":        "6px",
			"margin-top": "11px",
		}},
		{Selector: ".chat-list.empty", Props: map[string]string{
			"color":      "var(--muted)",
			"font-size":  "12px",
		}},
		{Selector: ".chat-line", Props: map[string]string{
			"margin":        "0",
			"padding":       "7px 8px",
			"border-left":   "3px solid color-mix(in srgb, var(--accent) 45%, var(--border))",
			"border-radius": "6px",
			"background":    "Canvas",
			"font-size":     "12px",
			"line-height":   "1.4",
			"overflow-wrap": "anywhere",
		}},
		{Selector: ".chat-author", Props: map[string]string{"font-weight": "800"}},
		{Selector: ".player-controls", Props: map[string]string{
			"display":              "grid",
			"grid-template-columns": "repeat(2, minmax(0, 1fr))",
			"gap":                 "7px",
			"margin-top":          "11px",
		}},
		{Selector: ".player-controls button", Props: map[string]string{"width": "100%"}},
		{Selector: ".player-time", Props: map[string]string{
			"font-size":            "13px",
			"font-weight":          "800",
			"font-variant-numeric": "tabular-nums",
		}},
		{Selector: ".audio-controls", Props: map[string]string{
			"display":    "grid",
			"gap":        "7px",
			"margin-top": "12px",
			"padding-top": "11px",
			"border-top": "1px solid var(--border)",
		}},
		{Selector: ".control-label, .audio-meter-row", Props: map[string]string{
			"display":         "flex",
			"align-items":     "center",
			"justify-content": "space-between",
			"gap":             "8px",
			"font-size":       "11px",
		}},
		{Selector: ".control-label output, .audio-meter-row strong", Props: map[string]string{
			"font-variant-numeric": "tabular-nums",
		}},
		{Selector: `input[type="range"]`, Props: map[string]string{
			"width":        "100%",
			"accent-color": "var(--accent)",
		}},
		{Selector: ".settings-grid", Props: map[string]string{
			"display":    "grid",
			"gap":        "7px",
			"margin-top": "10px",
		}},
		{Selector: ".settings-grid label", Props: map[string]string{
			"display": "grid",
			"gap":     "4px",
			"color":   "var(--muted)",
			"font-size": "10px",
		}},
		{Selector: ".settings-grid label[hidden]", Props: map[string]string{
			"display": "none",
		}},
		{Selector: `input[type="url"], input[type="text"], input[type="password"], input[type="number"], select`, Props: map[string]string{
			"width":          "100%",
			"min-width":      "0",
			"padding":        "7px 8px",
			"border":         "1px solid var(--border)",
			"border-radius":  "7px",
			"background":     "Canvas",
			"color":          "CanvasText",
			"font":           "inherit",
			"font-size":      "11px",
		}},
		{Selector: ".top-chatters", Props: map[string]string{
			"display":    "grid",
			"gap":        "6px",
			"margin-top": "8px",
		}},
		{Selector: ".top-chatters.empty", Props: map[string]string{
			"color":      "var(--muted)",
			"font-size":  "12px",
		}},
		{Selector: ".top-chatters-actions", Props: map[string]string{
			"display":         "flex",
			"justify-content": "flex-end",
			"gap":             "9px",
			"margin-top":      "7px",
		}},
		{Selector: ".top-chatters-actions[hidden]", Props: map[string]string{
			"display": "none",
		}},
		{Selector: ".top-chatter-link", Props: map[string]string{
			"padding":       "0",
			"color":         "var(--accent)",
			"background":    "transparent",
			"border":        "0",
			"border-radius": "0",
			"font-weight":   "700",
		}},
		{Selector: ".top-chatter-link:hover", Props: map[string]string{
			"text-decoration": "underline",
		}},
		{Selector: ".chatter-row", Props: map[string]string{
			"display":              "grid",
			"grid-template-columns": "minmax(0, 1fr) auto auto",
			"align-items":         "center",
			"gap":                 "7px",
			"padding":             "7px 8px",
			"border":              "1px solid var(--border)",
			"border-radius":       "8px",
			"background":          "Canvas",
		}},
		{Selector: ".chatter-name", Props: map[string]string{
			"min-width":      "0",
			"overflow":       "hidden",
			"text-overflow":  "ellipsis",
			"white-space":    "nowrap",
			"font-size":      "11px",
			"font-weight":    "800",
		}},
		{Selector: ".chatter-metrics", Props: map[string]string{
			"color":       "var(--muted)",
			"font-size":   "10px",
			"white-space": "nowrap",
		}},
		{Selector: ".mute-toggle", Props: map[string]string{
			"display": "flex",
			"align-items": "center",
			"gap":     "4px",
			"color":   "var(--muted)",
			"font-size": "10px",
		}},
		{Selector: "#recognize-song", Props: map[string]string{
			"width":      "100%",
			"margin-top": "10px",
		}},
		{Selector: ".song-result", Props: map[string]string{
			"margin-top":     "9px",
			"padding":        "9px",
			"border":         "1px solid var(--border)",
			"border-radius":  "9px",
			"background":     "Canvas",
			"font-size":      "11px",
			"line-height":    "1.45",
		}},
		{Selector: ".song-result strong, .song-result span, .song-result a", Props: map[string]string{
			"display": "block",
		}},
		{Selector: ".song-result a", Props: map[string]string{
			"margin-top":  "4px",
			"color":       "var(--accent)",
			"overflow-wrap": "anywhere",
		}},
		{Selector: ".modal-backdrop", Props: map[string]string{
			"position":   "fixed",
			"inset":      "0",
			"z-index":    "100",
			"padding":    "14px",
			"background": "color-mix(in srgb, CanvasText 42%, transparent)",
			"overflow":   "auto",
		}},
		{Selector: ".modal", Props: map[string]string{
			"width":      "min(520px, 100%)",
			"max-height": "calc(100vh - 28px)",
			"margin":     "0 auto",
			"overflow":   "auto",
			"background": "Canvas",
		}},
		{Selector: ".audience-list, .chat-history-list, .recommendation-list", Props: map[string]string{
			"display":    "grid",
			"gap":        "7px",
			"margin-top": "9px",
		}},
		{Selector: ".chat-history-row", Props: map[string]string{
			"padding":       "8px 9px",
			"border":        "1px solid var(--border)",
			"border-radius": "9px",
			"background":    "var(--surface)",
			"font-size":     "11px",
			"line-height":   "1.4",
			"overflow-wrap": "anywhere",
		}},
		{Selector: ".chat-history-meta", Props: map[string]string{
			"display": "block",
			"margin-bottom": "3px",
			"color":   "var(--muted)",
			"font-size": "10px",
		}},
		{Selector: ".audience-row", Props: map[string]string{
			"display":       "grid",
			"gap":           "6px",
			"padding":       "9px",
			"border":        "1px solid var(--border)",
			"border-radius": "9px",
			"background":    "var(--surface)",
		}},
		{Selector: ".audience-row-head", Props: map[string]string{
			"display":         "flex",
			"align-items":     "center",
			"justify-content": "space-between",
			"gap":             "8px",
		}},
		{Selector: ".audience-row select", Props: map[string]string{
			"width":    "auto",
			"max-width": "170px",
		}},
		{Selector: ".audience-metrics", Props: map[string]string{
			"color":       "var(--muted)",
			"font-size":   "10px",
			"line-height": "1.45",
		}},
		{Selector: ".option-row", Props: map[string]string{
			"display": "flex",
			"align-items": "flex-start",
			"gap":     "7px",
			"margin-top": "8px",
			"color":   "var(--muted)",
			"font-size": "11px",
			"line-height": "1.35",
		}},
		{Selector: ".option-row input", Props: map[string]string{
			"margin":        "1px 0 0",
			"accent-color":  "var(--accent)",
		}},
		{Selector: ".auto-chat-refresh", Props: map[string]string{
			"align-items": "center",
		}},
		{Selector: ".external-speech-trigger-row", Props: map[string]string{
			"align-items": "center",
		}},
		{Selector: ".external-speech-trigger-row label", Props: map[string]string{
			"display": "flex",
			"align-items": "center",
			"gap":     "7px",
		}},
		{Selector: ".external-speech-trigger-row input[type=\"text\"]", Props: map[string]string{
			"width":         "48px",
			"margin-left":   "3px",
			"padding":       "3px 4px",
			"border":        "1px solid var(--border)",
			"border-radius": "6px",
			"background":    "Canvas",
			"color":         "CanvasText",
			"font":          "inherit",
			"font-size":     "11px",
		}},
		{Selector: ".auto-chat-refresh input[type=\"number\"]", Props: map[string]string{
			"width":         "48px",
			"margin-left":   "3px",
			"padding":       "3px 4px",
			"border":        "1px solid var(--border)",
			"border-radius": "6px",
			"background":    "Canvas",
			"color":         "CanvasText",
			"font":          "inherit",
			"font-size":     "11px",
		}},
		{Selector: ".quick-recover-setting input[type=\"number\"]", Props: map[string]string{
			"width":         "48px",
			"margin-left":   "3px",
			"padding":       "3px 4px",
			"border":        "1px solid var(--border)",
			"border-radius": "6px",
			"background":    "Canvas",
			"color":         "CanvasText",
			"font":          "inherit",
			"font-size":     "11px",
		}},
		{Selector: ".audio-note", Props: map[string]string{
			"margin": "1px 0 0",
		}},
		{Selector: ".profile-info", Props: map[string]string{
			"display":    "grid",
			"gap":        "8px",
			"margin-top": "11px",
		}},
		{Selector: ".profile-heading", Props: map[string]string{
			"margin":     "0",
			"font-size":  "14px",
			"font-weight": "800",
		}},
		{Selector: ".profile-handle, .profile-bio", Props: map[string]string{
			"margin":      "0",
			"color":       "var(--muted)",
			"font-size":   "11px",
			"line-height": "1.45",
			"white-space": "pre-wrap",
		}},
		{Selector: ".profile-stats", Props: map[string]string{
			"display":              "grid",
			"grid-template-columns": "repeat(3, minmax(0, 1fr))",
			"gap":                 "6px",
		}},
		{Selector: ".profile-stat", Props: map[string]string{
			"padding":       "7px",
			"border":        "1px solid var(--border)",
			"border-radius": "8px",
			"background":    "Canvas",
		}},
		{Selector: ".profile-stat strong, .profile-stat span", Props: map[string]string{
			"display": "block",
		}},
		{Selector: ".profile-stat span", Props: map[string]string{
			"margin-top":    "2px",
			"color":         "var(--muted)",
			"font-size":     "9px",
			"text-transform": "uppercase",
		}},
		{Selector: ".summary-info", Props: map[string]string{
			"margin-top":  "10px",
			"padding-top": "9px",
			"border-top":  "1px solid var(--border)",
			"font-size":   "11px",
			"line-height": "1.45",
		}},
		{Selector: ".summary-text", Props: map[string]string{
			"margin":      "6px 0 0",
			"white-space": "pre-wrap",
		}},
		{Selector: ".recommendation-controls", Props: map[string]string{
			"display":              "grid",
			"grid-template-columns": "minmax(70px, .7fr) minmax(150px, 1.3fr)",
			"gap":                 "8px",
			"margin-top":          "10px",
		}},
		{Selector: ".recommendation-controls label", Props: map[string]string{
			"display": "grid",
			"gap":     "4px",
			"color":   "var(--muted)",
			"font-size": "10px",
		}},
		{Selector: ".recommendation-list.empty", Props: map[string]string{
			"display": "block",
			"color":   "var(--muted)",
			"font-size": "12px",
		}},
		{Selector: ".recommendation-row", Props: map[string]string{
			"padding":       "9px",
			"border":        "1px solid var(--border)",
			"border-radius": "9px",
			"background":    "Canvas",
		}},
		{Selector: ".recommendation-head", Props: map[string]string{
			"display":         "flex",
			"align-items":     "flex-start",
			"justify-content": "space-between",
			"gap":             "8px",
		}},
		{Selector: ".recommendation-name", Props: map[string]string{
			"min-width":     "0",
			"margin":        "0",
			"font-size":     "11px",
			"font-weight":   "800",
			"overflow-wrap": "anywhere",
		}},
		{Selector: ".recommendation-viewers", Props: map[string]string{
			"flex":          "0 0 auto",
			"color":         "var(--muted)",
			"font-size":     "10px",
			"font-variant-numeric": "tabular-nums",
		}},
		{Selector: ".recommendation-description", Props: map[string]string{
			"margin":        "5px 0 0",
			"color":         "var(--muted)",
			"font-size":     "10px",
			"line-height":   "1.4",
			"overflow-wrap": "anywhere",
		}},
		{Selector: ".recommendation-link", Props: map[string]string{
			"display":    "inline-block",
			"margin-top": "6px",
			"color":      "var(--accent)",
			"font-size":  "11px",
			"font-weight": "700",
		}},
		{Selector: ".list", Props: map[string]string{
			"display":    "grid",
			"gap":        "8px",
			"margin-top": "11px",
			"max-height": "300px",
			"overflow":   "auto",
		}},
		{Selector: ".list.empty", Props: map[string]string{
			"display": "block",
			"color":   "var(--muted)",
			"font-size": "12px",
		}},
		{Selector: ".item", Props: map[string]string{
			"padding":       "10px",
			"border":        "1px solid var(--border)",
			"border-radius": "9px",
			"background":    "Canvas",
		}},
		{Selector: ".item-head", Props: map[string]string{
			"display":         "flex",
			"align-items":     "center",
			"justify-content": "space-between",
			"gap":             "8px",
		}},
		{Selector: ".item-title", Props: map[string]string{
			"font-size":   "12px",
			"font-weight": "800",
		}},
		{Selector: ".item-meta, .item-url, .caption-meta", Props: map[string]string{
			"color":       "var(--muted)",
			"font-size":   "10px",
		}},
		{Selector: ".item-url", Props: map[string]string{
			"margin-top":  "6px",
			"overflow-wrap": "anywhere",
			"max-height":  "42px",
			"overflow":    "hidden",
		}},
		{Selector: ".copy", Props: map[string]string{
			"flex":        "0 0 auto",
			"padding":     "6px 8px",
		}},
		{Selector: ".caption-text", Props: map[string]string{
			"margin":      "5px 0 0",
			"white-space": "pre-wrap",
			"font-size":   "12px",
			"line-height": "1.4",
		}},
		{Selector: ".inline-status, .notice", Props: map[string]string{
			"min-height":  "17px",
			"margin":      "9px 0 0",
			"color":       "var(--muted)",
			"font-size":   "11px",
		}},
		{Selector: ".action-status", Props: map[string]string{
			"line-height": "1.4",
		}},
		{Selector: ".reset-note", Props: map[string]string{
			"margin": "7px 0 0",
		}},
		{Selector: ".notice", Props: map[string]string{
			"margin": "0 3px 8px",
			"color":  "var(--bad)",
		}},
		{Selector: ".section-title.header-controls", Props: map[string]string{
			"flex-wrap":   "nowrap",
			"align-items": "flex-start",
		}},
		{Selector: ".header-controls > .title-actions", Props: map[string]string{
			"margin-inline-start": "auto",
			"flex-wrap":           "nowrap",
			"flex-shrink":         "0",
		}},
		{Selector: ".header-controls > .title-actions input[type=\"checkbox\"]", Props: map[string]string{
			"margin": "0",
		}},
		{Selector: ".connection-status", Props: map[string]string{
			"display":     "flex",
			"align-items": "center",
			"gap":         "8px",
		}},
	}

	mediaQueries := []MediaQuery{
		{
			Query: "@media (min-width: 430px)",
			Rules: []CSSRule{
				{Selector: ".speech-settings", Props: map[string]string{
					"grid-template-columns": "1fr 1fr",
				}},
				{Selector: ".speech-settings label:first-child", Props: map[string]string{
					"grid-column": "1 / -1",
				}},
			},
		},
		{
			Query: "@media (prefers-reduced-motion: reduce)",
			Rules: []CSSRule{
				{Selector: "*", Props: map[string]string{
					"scroll-behavior": "auto !important",
				}},
			},
		},
	}

	// Template for regular rules
	cssTemplate := `{{range .Rules}}{{.Selector} {
{{range $prop, $val := .Props}}  {{$prop}}: {{$val}};
{{end}}}
{{end}}`

	// Template for media queries
	mediaTemplate := `{{range .MediaQueries}}
{{.Query}} {
{{range .Rules}}{{.Selector} {
{{range $prop, $val := .Props}}  {{$prop}}: {{$val}};
{{end}}}
{{end}}}
{{end}}`

	tmpl := template.Must(template.New("css").Parse(cssTemplate))
	tmpl.Execute(file, map[string]interface{}{"Rules": rules})

	mediaTmpl := template.Must(template.New("media").Parse(mediaTemplate))
	mediaTmpl.Execute(file, map[string]interface{}{"MediaQueries": mediaQueries})
}
