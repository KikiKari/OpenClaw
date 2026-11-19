// abstraction-provenance: {"artifact_sha256": "f0dfac54907f8cede95b37af7ec4a0555a4e53b200a4584ada4068e4efc70c83", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "go"}
// sidebar.css — portiert nach go
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", os.Args[0])
		os.Exit(1)
	}

	filename := os.Args[1]
	content := generateCSS()

	if err := os.WriteFile(filename, []byte(content), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}
}

func generateCSS() string {
	var builder strings.Builder

	builder.WriteString("/* Split View Layout */\n")
	builder.WriteString(".chat-split-container {\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  gap: 0;\n")
	builder.WriteString("  flex: 1;\n")
	builder.WriteString("  min-height: 0;\n")
	builder.WriteString("  height: 100%;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".chat-main {\n")
	builder.WriteString("  min-width: 312px;\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  flex-direction: column;\n")
	builder.WriteString("  overflow: hidden;\n")
	builder.WriteString("  /* Smooth transition when sidebar opens/closes */\n")
	builder.WriteString("  transition: flex 250ms ease-out;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".chat-sidebar {\n")
	builder.WriteString("  flex: 1;\n")
	builder.WriteString("  min-width: 300px;\n")
	builder.WriteString("  border-left: 1px solid var(--border);\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  flex-direction: column;\n")
	builder.WriteString("  overflow: hidden;\n")
	builder.WriteString("  animation: slide-in 200ms ease-out;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("@keyframes slide-in {\n")
	builder.WriteString("  from {\n")
	builder.WriteString("    opacity: 0;\n")
	builder.WriteString("    transform: translateX(20px);\n")
	builder.WriteString("  }\n")
	builder.WriteString("  to {\n")
	builder.WriteString("    opacity: 1;\n")
	builder.WriteString("    transform: translateX(0);\n")
	builder.WriteString("  }\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* Sidebar Panel */\n")
	builder.WriteString(".sidebar-panel {\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  flex-direction: column;\n")
	builder.WriteString("  height: 100%;\n")
	builder.WriteString("  background: var(--panel);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-header {\n")
	builder.WriteString("  display: flex;\n")
	builder.WriteString("  justify-content: space-between;\n")
	builder.WriteString("  align-items: center;\n")
	builder.WriteString("  padding: 12px 16px;\n")
	builder.WriteString("  border-bottom: 1px solid var(--border);\n")
	builder.WriteString("  flex-shrink: 0;\n")
	builder.WriteString("  position: sticky;\n")
	builder.WriteString("  top: 0;\n")
	builder.WriteString("  z-index: 10;\n")
	builder.WriteString("  background: var(--panel);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* Smaller close button for sidebar */\n")
	builder.WriteString(".sidebar-header .btn {\n")
	builder.WriteString("  padding: 4px 8px;\n")
	builder.WriteString("  font-size: 14px;\n")
	builder.WriteString("  min-width: auto;\n")
	builder.WriteString("  line-height: 1;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-title {\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  font-size: 14px;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-content {\n")
	builder.WriteString("  flex: 1;\n")
	builder.WriteString("  overflow: auto;\n")
	builder.WriteString("  padding: 16px;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown {\n")
	builder.WriteString("  font-size: 14px;\n")
	builder.WriteString("  line-height: 1.6;\n")
	builder.WriteString("  color: var(--text);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Headings ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(h1) {\n")
	builder.WriteString("  font-size: 1.65em;\n")
	builder.WriteString("  font-weight: 700;\n")
	builder.WriteString("  letter-spacing: -0.025em;\n")
	builder.WriteString("  margin: 1.6em 0 0.6em;\n")
	builder.WriteString("  padding-bottom: 0.35em;\n")
	builder.WriteString("  border-bottom: 1px solid var(--border);\n")
	builder.WriteString("  line-height: 1.25;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(h2) {\n")
	builder.WriteString("  font-size: 1.35em;\n")
	builder.WriteString("  font-weight: 650;\n")
	builder.WriteString("  letter-spacing: -0.02em;\n")
	builder.WriteString("  margin: 1.4em 0 0.5em;\n")
	builder.WriteString("  padding-bottom: 0.25em;\n")
	builder.WriteString("  border-bottom: 1px solid var(--border);\n")
	builder.WriteString("  line-height: 1.3;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(h3) {\n")
	builder.WriteString("  font-size: 1.15em;\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  letter-spacing: -0.01em;\n")
	builder.WriteString("  margin: 1.2em 0 0.4em;\n")
	builder.WriteString("  line-height: 1.35;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(h4, h5, h6) {\n")
	builder.WriteString("  font-size: 1em;\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  margin: 1em 0 0.35em;\n")
	builder.WriteString("  line-height: 1.4;\n")
	builder.WriteString("  color: var(--text-strong);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child {\n")
	builder.WriteString("  margin-top: 0;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Paragraphs & spacing ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details) {\n")
	builder.WriteString("  margin: 0;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details) {\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p) {\n")
	builder.WriteString("  margin-top: 0;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Lists ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(ul, ol) {\n")
	builder.WriteString("  padding-left: 1.6em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(li + li) {\n")
	builder.WriteString("  margin-top: 0.3em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(li > p) {\n")
	builder.WriteString("  margin-top: 0.25em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(li > ul, li > ol) {\n")
	builder.WriteString("  margin-top: 0.25em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Links ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(a) {\n")
	builder.WriteString("  color: var(--accent);\n")
	builder.WriteString("  text-decoration: underline;\n")
	builder.WriteString("  text-underline-offset: 2px;\n")
	builder.WriteString("  text-decoration-color: color-mix(in srgb, var(--accent) 40%, transparent);\n")
	builder.WriteString("  transition: text-decoration-color var(--duration-fast) ease;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(a:hover) {\n")
	builder.WriteString("  text-decoration-color: var(--accent);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Inline code ── */\n\n")

	builder.WriteString(".sidebar-markdown code {\n")
	builder.WriteString("  font-family: var(--mono);\n")
	builder.WriteString("  font-size: 0.88em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(:not(pre) > code) {\n")
	builder.WriteString("  padding: 0.15em 0.4em;\n")
	builder.WriteString("  border-radius: var(--radius-sm);\n")
	builder.WriteString("  background: rgba(0, 0, 0, 0.12);\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(":root[data-theme-mode=\"light\"] .sidebar-markdown :where(:not(pre) > code) {\n")
	builder.WriteString("  background: rgba(0, 0, 0, 0.06);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Code blocks ── */\n\n")

	builder.WriteString(".sidebar-markdown pre {\n")
	builder.WriteString("  background: rgba(0, 0, 0, 0.12);\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("  border-radius: var(--radius-md);\n")
	builder.WriteString("  padding: 14px 16px;\n")
	builder.WriteString("  overflow-x: auto;\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(":root[data-theme-mode=\"light\"] .sidebar-markdown pre {\n")
	builder.WriteString("  background: rgba(0, 0, 0, 0.04);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(pre code) {\n")
	builder.WriteString("  background: none;\n")
	builder.WriteString("  border: none;\n")
	builder.WriteString("  padding: 0;\n")
	builder.WriteString("  font-size: 12.5px;\n")
	builder.WriteString("  line-height: 1.55;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Blockquotes ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(blockquote) {\n")
	builder.WriteString("  border-left: 3px solid var(--border-strong);\n")
	builder.WriteString("  padding: 8px 14px;\n")
	builder.WriteString("  margin-left: 0;\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("  color: var(--muted);\n")
	builder.WriteString("  background: rgba(255, 255, 255, 0.02);\n")
	builder.WriteString("  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(":root[data-theme-mode=\"light\"] .sidebar-markdown :where(blockquote) {\n")
	builder.WriteString("  background: rgba(0, 0, 0, 0.025);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(blockquote blockquote) {\n")
	builder.WriteString("  margin-top: 8px;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Tables ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(table) {\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("  border-collapse: collapse;\n")
	builder.WriteString("  width: 100%;\n")
	builder.WriteString("  font-size: 13px;\n")
	builder.WriteString("  display: block;\n")
	builder.WriteString("  overflow-x: auto;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(th, td) {\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("  padding: 8px 12px;\n")
	builder.WriteString("  text-align: left;\n")
	builder.WriteString("  vertical-align: top;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(th) {\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  font-size: 12px;\n")
	builder.WriteString("  color: var(--muted);\n")
	builder.WriteString("  background: var(--secondary);\n")
	builder.WriteString("  text-transform: uppercase;\n")
	builder.WriteString("  letter-spacing: 0.03em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(tbody tr:hover) {\n")
	builder.WriteString("  background: var(--bg-hover);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Horizontal rules ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(hr) {\n")
	builder.WriteString("  border: none;\n")
	builder.WriteString("  border-top: 1px solid var(--border);\n")
	builder.WriteString("  margin: 1.5em 0;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Bold / italic ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(strong) {\n")
	builder.WriteString("  font-weight: 600;\n")
	builder.WriteString("  color: var(--text-strong);\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Images ── */\n\n")

	builder.WriteString(".sidebar-markdown .markdown-inline-image {\n")
	builder.WriteString("  display: block;\n")
	builder.WriteString("  max-width: 100%;\n")
	builder.WriteString("  max-height: 420px;\n")
	builder.WriteString("  width: auto;\n")
	builder.WriteString("  height: auto;\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("  border-radius: var(--radius-md);\n")
	builder.WriteString("  background: color-mix(in srgb, var(--secondary) 70%, transparent);\n")
	builder.WriteString("  object-fit: contain;\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* ── Details / summary ── */\n\n")

	builder.WriteString(".sidebar-markdown :where(details) {\n")
	builder.WriteString("  margin-top: 0.75em;\n")
	builder.WriteString("  border: 1px solid var(--border);\n")
	builder.WriteString("  border-radius: var(--radius-md);\n")
	builder.WriteString("  background: var(--bg-elevated);\n")
	builder.WriteString("  overflow: hidden;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(summary) {\n")
	builder.WriteString("  cursor: pointer;\n")
	builder.WriteString("  padding: 8px 12px;\n")
	builder.WriteString("  font-weight: 500;\n")
	builder.WriteString("  font-size: 13px;\n")
	builder.WriteString("  user-select: none;\n")
	builder.WriteString("  transition: background var(--duration-fast) ease;\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(summary:hover) {\n")
	builder.WriteString("  background: var(--bg-hover);\n")
	builder.WriteString("}\n\n")

	builder.WriteString(".sidebar-markdown :where(details[open] > :not(summary)) {\n")
	builder.WriteString("  padding: 0 12px 10px;\n")
	builder.WriteString("}\n\n")

	builder.WriteString("/* Mobile: Full-screen modal */\n")
	builder.WriteString("@media (max-width: 768px) {\n")
	builder.WriteString("  .chat-split-container--open {\n")
	builder.WriteString("    position: fixed;\n")
	builder.WriteString("    top: 0;\n")
	builder.WriteString("    left: 0;\n")
	builder.WriteString("    right: 0;\n")
	builder.WriteString("    bottom: 0;\n")
	builder.WriteString("    z-index: 1000;\n")
	builder.WriteString("  }\n\n")

	builder.WriteString("  .chat-split-container--open .chat-main {\n")
	builder.WriteString("    display: none; /* Hide chat on mobile when sidebar open */\n")
	builder.WriteString("  }\n\n")

	builder.WriteString("  .chat-split-container--open .chat-sidebar {\n")
	builder.WriteString("    width: 100%;\n")
	builder.WriteString("    min-width: 0;\n")
	builder.WriteString("    border-left: none;\n")
	builder.WriteString("  }\n")
	builder.WriteString("}\n")

	return builder.String()
}
