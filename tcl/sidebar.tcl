#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "45fbbf4a0452f68f24cb617a34db4f38bb5cd3499e6cd5bf10a2d72863558866", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "tcl"}
# sidebar.css — portiert nach tcl
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Procedure to generate the CSS content
proc generateCSS {} {
    set css ""

    # Split View Layout
    append css "/* Split View Layout */\n"
    append css ".chat-split-container {\n"
    append css "  display: flex;\n"
    append css "  gap: 0;\n"
    append css "  flex: 1;\n"
    append css "  min-height: 0;\n"
    append css "  height: 100%;\n"
    append css "}\n\n"

    append css ".chat-main {\n"
    append css "  min-width: 312px;\n"
    append css "  display: flex;\n"
    append css "  flex-direction: column;\n"
    append css "  overflow: hidden;\n"
    append css "  /* Smooth transition when sidebar opens/closes */\n"
    append css "  transition: flex 250ms ease-out;\n"
    append css "}\n\n"

    append css ".chat-sidebar {\n"
    append css "  flex: 1;\n"
    append css "  min-width: 300px;\n"
    append css "  border-left: 1px solid var(--border);\n"
    append css "  display: flex;\n"
    append css "  flex-direction: column;\n"
    append css "  overflow: hidden;\n"
    append css "  animation: slide-in 200ms ease-out;\n"
    append css "}\n\n"

    append css "@keyframes slide-in {\n"
    append css "  from {\n"
    append css "    opacity: 0;\n"
    append css "    transform: translateX(20px);\n"
    append css "  }\n"
    append css "  to {\n"
    append css "    opacity: 1;\n"
    append css "    transform: translateX(0);\n"
    append css "  }\n"
    append css "}\n\n"

    # Sidebar Panel
    append css "/* Sidebar Panel */\n"
    append css ".sidebar-panel {\n"
    append css "  display: flex;\n"
    append css "  flex-direction: column;\n"
    append css "  height: 100%;\n"
    append css "  background: var(--panel);\n"
    append css "}\n\n"

    append css ".sidebar-header {\n"
    append css "  display: flex;\n"
    append css "  justify-content: space-between;\n"
    append css "  align-items: center;\n"
    append css "  padding: 12px 16px;\n"
    append css "  border-bottom: 1px solid var(--border);\n"
    append css "  flex-shrink: 0;\n"
    append css "  position: sticky;\n"
    append css "  top: 0;\n"
    append css "  z-index: 10;\n"
    append css "  background: var(--panel);\n"
    append css "}\n\n"

    # Smaller close button for sidebar
    append css "/* Smaller close button for sidebar */\n"
    append css ".sidebar-header .btn {\n"
    append css "  padding: 4px 8px;\n"
    append css "  font-size: 14px;\n"
    append css "  min-width: auto;\n"
    append css "  line-height: 1;\n"
    append css "}\n\n"

    append css ".sidebar-title {\n"
    append css "  font-weight: 600;\n"
    append css "  font-size: 14px;\n"
    append css "}\n\n"

    append css ".sidebar-content {\n"
    append css "  flex: 1;\n"
    append css "  overflow: auto;\n"
    append css "  padding: 16px;\n"
    append css "}\n\n"

    append css ".sidebar-markdown {\n"
    append css "  font-size: 14px;\n"
    append css "  line-height: 1.6;\n"
    append css "  color: var(--text);\n"
    append css "}\n\n"

    # Headings
    append css "/* ── Headings ── */\n\n"

    append css ".sidebar-markdown :where(h1) {\n"
    append css "  font-size: 1.65em;\n"
    append css "  font-weight: 700;\n"
    append css "  letter-spacing: -0.025em;\n"
    append css "  margin: 1.6em 0 0.6em;\n"
    append css "  padding-bottom: 0.35em;\n"
    append css "  border-bottom: 1px solid var(--border);\n"
    append css "  line-height: 1.25;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(h2) {\n"
    append css "  font-size: 1.35em;\n"
    append css "  font-weight: 650;\n"
    append css "  letter-spacing: -0.02em;\n"
    append css "  margin: 1.4em 0 0.5em;\n"
    append css "  padding-bottom: 0.25em;\n"
    append css "  border-bottom: 1px solid var(--border);\n"
    append css "  line-height: 1.3;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(h3) {\n"
    append css "  font-size: 1.15em;\n"
    append css "  font-weight: 600;\n"
    append css "  letter-spacing: -0.01em;\n"
    append css "  margin: 1.2em 0 0.4em;\n"
    append css "  line-height: 1.35;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(h4, h5, h6) {\n"
    append css "  font-size: 1em;\n"
    append css "  font-weight: 600;\n"
    append css "  margin: 1em 0 0.35em;\n"
    append css "  line-height: 1.4;\n"
    append css "  color: var(--text-strong);\n"
    append css "}\n\n"

    append css ".sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child {\n"
    append css "  margin-top: 0;\n"
    append css "}\n\n"

    # Paragraphs & spacing
    append css "/* ── Paragraphs & spacing ── */\n\n"

    append css ".sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details) {\n"
    append css "  margin: 0;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details) {\n"
    append css "  margin-top: 0.75em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p) {\n"
    append css "  margin-top: 0;\n"
    append css "}\n\n"

    # Lists
    append css "/* ── Lists ── */\n\n"

    append css ".sidebar-markdown :where(ul, ol) {\n"
    append css "  padding-left: 1.6em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(li + li) {\n"
    append css "  margin-top: 0.3em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(li > p) {\n"
    append css "  margin-top: 0.25em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(li > ul, li > ol) {\n"
    append css "  margin-top: 0.25em;\n"
    append css "}\n\n"

    # Links
    append css "/* ── Links ── */\n\n"

    append css ".sidebar-markdown :where(a) {\n"
    append css "  color: var(--accent);\n"
    append css "  text-decoration: underline;\n"
    append css "  text-underline-offset: 2px;\n"
    append css "  text-decoration-color: color-mix(in srgb, var(--accent) 40%, transparent);\n"
    append css "  transition: text-decoration-color var(--duration-fast) ease;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(a:hover) {\n"
    append css "  text-decoration-color: var(--accent);\n"
    append css "}\n\n"

    # Inline code
    append css "/* ── Inline code ── */\n\n"

    append css ".sidebar-markdown code {\n"
    append css "  font-family: var(--mono);\n"
    append css "  font-size: 0.88em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(:not(pre) > code) {\n"
    append css "  padding: 0.15em 0.4em;\n"
    append css "  border-radius: var(--radius-sm);\n"
    append css "  background: rgba(0, 0, 0, 0.12);\n"
    append css "  border: 1px solid var(--border);\n"
    append css "}\n\n"

    append css ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(:not(pre) > code) {\n"
    append css "  background: rgba(0, 0, 0, 0.06);\n"
    append css "}\n\n"

    # Code blocks
    append css "/* ── Code blocks ── */\n\n"

    append css ".sidebar-markdown pre {\n"
    append css "  background: rgba(0, 0, 0, 0.12);\n"
    append css "  border: 1px solid var(--border);\n"
    append css "  border-radius: var(--radius-md);\n"
    append css "  padding: 14px 16px;\n"
    append css "  overflow-x: auto;\n"
    append css "  margin-top: 0.75em;\n"
    append css "}\n\n"

    append css ":root[data-theme-mode=\"light\"] .sidebar-markdown pre {\n"
    append css "  background: rgba(0, 0, 0, 0.04);\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(pre code) {\n"
    append css "  background: none;\n"
    append css "  border: none;\n"
    append css "  padding: 0;\n"
    append css "  font-size: 12.5px;\n"
    append css "  line-height: 1.55;\n"
    append css "}\n\n"

    # Blockquotes
    append css "/* ── Blockquotes ── */\n\n"

    append css ".sidebar-markdown :where(blockquote) {\n"
    append css "  border-left: 3px solid var(--border-strong);\n"
    append css "  padding: 8px 14px;\n"
    append css "  margin-left: 0;\n"
    append css "  margin-top: 0.75em;\n"
    append css "  color: var(--muted);\n"
    append css "  background: rgba(255, 255, 255, 0.02);\n"
    append css "  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;\n"
    append css "}\n\n"

    append css ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(blockquote) {\n"
    append css "  background: rgba(0, 0, 0, 0.025);\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(blockquote blockquote) {\n"
    append css "  margin-top: 8px;\n"
    append css "}\n\n"

    # Tables
    append css "/* ── Tables ── */\n\n"

    append css ".sidebar-markdown :where(table) {\n"
    append css "  margin-top: 0.75em;\n"
    append css "  border-collapse: collapse;\n"
    append css "  width: 100%;\n"
    append css "  font-size: 13px;\n"
    append css "  display: block;\n"
    append css "  overflow-x: auto;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(th, td) {\n"
    append css "  border: 1px solid var(--border);\n"
    append css "  padding: 8px 12px;\n"
    append css "  text-align: left;\n"
    append css "  vertical-align: top;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(th) {\n"
    append css "  font-weight: 600;\n"
    append css "  font-size: 12px;\n"
    append css "  color: var(--muted);\n"
    append css "  background: var(--secondary);\n"
    append css "  text-transform: uppercase;\n"
    append css "  letter-spacing: 0.03em;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(tbody tr:hover) {\n"
    append css "  background: var(--bg-hover);\n"
    append css "}\n\n"

    # Horizontal rules
    append css "/* ── Horizontal rules ── */\n\n"

    append css ".sidebar-markdown :where(hr) {\n"
    append css "  border: none;\n"
    append css "  border-top: 1px solid var(--border);\n"
    append css "  margin: 1.5em 0;\n"
    append css "}\n\n"

    # Bold / italic
    append css "/* ── Bold / italic ── */\n\n"

    append css ".sidebar-markdown :where(strong) {\n"
    append css "  font-weight: 600;\n"
    append css "  color: var(--text-strong);\n"
    append css "}\n\n"

    # Images
    append css "/* ── Images ── */\n\n"

    append css ".sidebar-markdown .markdown-inline-image {\n"
    append css "  display: block;\n"
    append css "  max-width: 100%;\n"
    append css "  max-height: 420px;\n"
    append css "  width: auto;\n"
    append css "  height: auto;\n"
    append css "  border: 1px solid var(--border);\n"
    append css "  border-radius: var(--radius-md);\n"
    append css "  background: color-mix(in srgb, var(--secondary) 70%, transparent);\n"
    append css "  object-fit: contain;\n"
    append css "  margin-top: 0.75em;\n"
    append css "}\n\n"

    # Details / summary
    append css "/* ── Details / summary ── */\n\n"

    append css ".sidebar-markdown :where(details) {\n"
    append css "  margin-top: 0.75em;\n"
    append css "  border: 1px solid var(--border);\n"
    append css "  border-radius: var(--radius-md);\n"
    append css "  background: var(--bg-elevated);\n"
    append css "  overflow: hidden;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(summary) {\n"
    append css "  cursor: pointer;\n"
    append css "  padding: 8px 12px;\n"
    append css "  font-weight: 500;\n"
    append css "  font-size: 13px;\n"
    append css "  user-select: none;\n"
    append css "  transition: background var(--duration-fast) ease;\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(summary:hover) {\n"
    append css "  background: var(--bg-hover);\n"
    append css "}\n\n"

    append css ".sidebar-markdown :where(details[open] > :not(summary)) {\n"
    append css "  padding: 0 12px 10px;\n"
    append css "}\n\n"

    # Mobile: Full-screen modal
    append css "/* Mobile: Full-screen modal */\n"
    append css "@media (max-width: 768px) {\n"
    append css "  .chat-split-container--open {\n"
    append css "    position: fixed;\n"
    append css "    top: 0;\n"
    append css "    left: 0;\n"
    append css "    right: 0;\n"
    append css "    bottom: 0;\n"
    append css "    z-index: 1000;\n"
    append css "  }\n\n"

    append css "  .chat-split-container--open .chat-main {\n"
    append css "    display: none; /* Hide chat on mobile when sidebar open */\n"
    append css "  }\n\n"

    append css "  .chat-split-container--open .chat-sidebar {\n"
    append css "    width: 100%;\n"
    append css "    min-width: 0;\n"
    append css "    border-left: none;\n"
    append css "  }\n"
    append css "}\n"

    return $css
}

# Main execution
if {$argc != 1} {
    puts stderr "Usage: $argv0 <output-file>"
    exit 1
}

set outputFile [lindex $argv 0]
set cssContent [generateCSS]

# Write to file
set fh [open $outputFile w]
puts -nonewline $fh $cssContent
close $fh

puts "CSS file generated successfully: $outputFile"
