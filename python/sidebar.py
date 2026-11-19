#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "1a8165b7296e250f0d96b2d7c9edc75e639bea59049345fa676687be6be2f400", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "python"}
# sidebar.css — portiert nach python
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_css():
    """Generate the sidebar.css content programmatically."""
    
    # Split View Layout
    css = "/* Split View Layout */\n"
    css += ".chat-split-container {\n"
    css += "  display: flex;\n"
    css += "  gap: 0;\n"
    css += "  flex: 1;\n"
    css += "  min-height: 0;\n"
    css += "  height: 100%;\n"
    css += "}\n\n"
    
    css += ".chat-main {\n"
    css += "  min-width: 312px;\n"
    css += "  display: flex;\n"
    css += "  flex-direction: column;\n"
    css += "  overflow: hidden;\n"
    css += "  /* Smooth transition when sidebar opens/closes */\n"
    css += "  transition: flex 250ms ease-out;\n"
    css += "}\n\n"
    
    css += ".chat-sidebar {\n"
    css += "  flex: 1;\n"
    css += "  min-width: 300px;\n"
    css += "  border-left: 1px solid var(--border);\n"
    css += "  display: flex;\n"
    css += "  flex-direction: column;\n"
    css += "  overflow: hidden;\n"
    css += "  animation: slide-in 200ms ease-out;\n"
    css += "}\n\n"
    
    css += "@keyframes slide-in {\n"
    css += "  from {\n"
    css += "    opacity: 0;\n"
    css += "    transform: translateX(20px);\n"
    css += "  }\n"
    css += "  to {\n"
    css += "    opacity: 1;\n"
    css += "    transform: translateX(0);\n"
    css += "  }\n"
    css += "}\n\n"
    
    # Sidebar Panel
    css += "/* Sidebar Panel */\n"
    css += ".sidebar-panel {\n"
    css += "  display: flex;\n"
    css += "  flex-direction: column;\n"
    css += "  height: 100%;\n"
    css += "  background: var(--panel);\n"
    css += "}\n\n"
    
    css += ".sidebar-header {\n"
    css += "  display: flex;\n"
    css += "  justify-content: space-between;\n"
    css += "  align-items: center;\n"
    css += "  padding: 12px 16px;\n"
    css += "  border-bottom: 1px solid var(--border);\n"
    css += "  flex-shrink: 0;\n"
    css += "  position: sticky;\n"
    css += "  top: 0;\n"
    css += "  z-index: 10;\n"
    css += "  background: var(--panel);\n"
    css += "}\n\n"
    
    css += "/* Smaller close button for sidebar */\n"
    css += ".sidebar-header .btn {\n"
    css += "  padding: 4px 8px;\n"
    css += "  font-size: 14px;\n"
    css += "  min-width: auto;\n"
    css += "  line-height: 1;\n"
    css += "}\n\n"
    
    css += ".sidebar-title {\n"
    css += "  font-weight: 600;\n"
    css += "  font-size: 14px;\n"
    css += "}\n\n"
    
    css += ".sidebar-content {\n"
    css += "  flex: 1;\n"
    css += "  overflow: auto;\n"
    css += "  padding: 16px;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown {\n"
    css += "  font-size: 14px;\n"
    css += "  line-height: 1.6;\n"
    css += "  color: var(--text);\n"
    css += "}\n\n"
    
    # Headings
    css += "/* ── Headings ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(h1) {\n"
    css += "  font-size: 1.65em;\n"
    css += "  font-weight: 700;\n"
    css += "  letter-spacing: -0.025em;\n"
    css += "  margin: 1.6em 0 0.6em;\n"
    css += "  padding-bottom: 0.35em;\n"
    css += "  border-bottom: 1px solid var(--border);\n"
    css += "  line-height: 1.25;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(h2) {\n"
    css += "  font-size: 1.35em;\n"
    css += "  font-weight: 650;\n"
    css += "  letter-spacing: -0.02em;\n"
    css += "  margin: 1.4em 0 0.5em;\n"
    css += "  padding-bottom: 0.25em;\n"
    css += "  border-bottom: 1px solid var(--border);\n"
    css += "  line-height: 1.3;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(h3) {\n"
    css += "  font-size: 1.15em;\n"
    css += "  font-weight: 600;\n"
    css += "  letter-spacing: -0.01em;\n"
    css += "  margin: 1.2em 0 0.4em;\n"
    css += "  line-height: 1.35;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(h4, h5, h6) {\n"
    css += "  font-size: 1em;\n"
    css += "  font-weight: 600;\n"
    css += "  margin: 1em 0 0.35em;\n"
    css += "  line-height: 1.4;\n"
    css += "  color: var(--text-strong);\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child {\n"
    css += "  margin-top: 0;\n"
    css += "}\n\n"
    
    # Paragraphs & spacing
    css += "/* ── Paragraphs & spacing ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details) {\n"
    css += "  margin: 0;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details) {\n"
    css += "  margin-top: 0.75em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p) {\n"
    css += "  margin-top: 0;\n"
    css += "}\n\n"
    
    # Lists
    css += "/* ── Lists ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(ul, ol) {\n"
    css += "  padding-left: 1.6em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(li + li) {\n"
    css += "  margin-top: 0.3em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(li > p) {\n"
    css += "  margin-top: 0.25em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(li > ul, li > ol) {\n"
    css += "  margin-top: 0.25em;\n"
    css += "}\n\n"
    
    # Links
    css += "/* ── Links ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(a) {\n"
    css += "  color: var(--accent);\n"
    css += "  text-decoration: underline;\n"
    css += "  text-underline-offset: 2px;\n"
    css += "  text-decoration-color: color-mix(in srgb, var(--accent) 40%, transparent);\n"
    css += "  transition: text-decoration-color var(--duration-fast) ease;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(a:hover) {\n"
    css += "  text-decoration-color: var(--accent);\n"
    css += "}\n\n"
    
    # Inline code
    css += "/* ── Inline code ── */\n"
    css += "\n"
    css += ".sidebar-markdown code {\n"
    css += "  font-family: var(--mono);\n"
    css += "  font-size: 0.88em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(:not(pre) > code) {\n"
    css += "  padding: 0.15em 0.4em;\n"
    css += "  border-radius: var(--radius-sm);\n"
    css += "  background: rgba(0, 0, 0, 0.12);\n"
    css += "  border: 1px solid var(--border);\n"
    css += "}\n\n"
    
    css += ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(:not(pre) > code) {\n"
    css += "  background: rgba(0, 0, 0, 0.06);\n"
    css += "}\n\n"
    
    # Code blocks
    css += "/* ── Code blocks ── */\n"
    css += "\n"
    css += ".sidebar-markdown pre {\n"
    css += "  background: rgba(0, 0, 0, 0.12);\n"
    css += "  border: 1px solid var(--border);\n"
    css += "  border-radius: var(--radius-md);\n"
    css += "  padding: 14px 16px;\n"
    css += "  overflow-x: auto;\n"
    css += "  margin-top: 0.75em;\n"
    css += "}\n\n"
    
    css += ":root[data-theme-mode=\"light\"] .sidebar-markdown pre {\n"
    css += "  background: rgba(0, 0, 0, 0.04);\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(pre code) {\n"
    css += "  background: none;\n"
    css += "  border: none;\n"
    css += "  padding: 0;\n"
    css += "  font-size: 12.5px;\n"
    css += "  line-height: 1.55;\n"
    css += "}\n\n"
    
    # Blockquotes
    css += "/* ── Blockquotes ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(blockquote) {\n"
    css += "  border-left: 3px solid var(--border-strong);\n"
    css += "  padding: 8px 14px;\n"
    css += "  margin-left: 0;\n"
    css += "  margin-top: 0.75em;\n"
    css += "  color: var(--muted);\n"
    css += "  background: rgba(255, 255, 255, 0.02);\n"
    css += "  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;\n"
    css += "}\n\n"
    
    css += ":root[data-theme-mode=\"light\"] .sidebar-markdown :where(blockquote) {\n"
    css += "  background: rgba(0, 0, 0, 0.025);\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(blockquote blockquote) {\n"
    css += "  margin-top: 8px;\n"
    css += "}\n\n"
    
    # Tables
    css += "/* ── Tables ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(table) {\n"
    css += "  margin-top: 0.75em;\n"
    css += "  border-collapse: collapse;\n"
    css += "  width: 100%;\n"
    css += "  font-size: 13px;\n"
    css += "  display: block;\n"
    css += "  overflow-x: auto;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(th, td) {\n"
    css += "  border: 1px solid var(--border);\n"
    css += "  padding: 8px 12px;\n"
    css += "  text-align: left;\n"
    css += "  vertical-align: top;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(th) {\n"
    css += "  font-weight: 600;\n"
    css += "  font-size: 12px;\n"
    css += "  color: var(--muted);\n"
    css += "  background: var(--secondary);\n"
    css += "  text-transform: uppercase;\n"
    css += "  letter-spacing: 0.03em;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(tbody tr:hover) {\n"
    css += "  background: var(--bg-hover);\n"
    css += "}\n\n"
    
    # Horizontal rules
    css += "/* ── Horizontal rules ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(hr) {\n"
    css += "  border: none;\n"
    css += "  border-top: 1px solid var(--border);\n"
    css += "  margin: 1.5em 0;\n"
    css += "}\n\n"
    
    # Bold / italic
    css += "/* ── Bold / italic ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(strong) {\n"
    css += "  font-weight: 600;\n"
    css += "  color: var(--text-strong);\n"
    css += "}\n\n"
    
    # Images
    css += "/* ── Images ── */\n"
    css += "\n"
    css += ".sidebar-markdown .markdown-inline-image {\n"
    css += "  display: block;\n"
    css += "  max-width: 100%;\n"
    css += "  max-height: 420px;\n"
    css += "  width: auto;\n"
    css += "  height: auto;\n"
    css += "  border: 1px solid var(--border);\n"
    css += "  border-radius: var(--radius-md);\n"
    css += "  background: color-mix(in srgb, var(--secondary) 70%, transparent);\n"
    css += "  object-fit: contain;\n"
    css += "  margin-top: 0.75em;\n"
    css += "}\n\n"
    
    # Details / summary
    css += "/* ── Details / summary ── */\n"
    css += "\n"
    css += ".sidebar-markdown :where(details) {\n"
    css += "  margin-top: 0.75em;\n"
    css += "  border: 1px solid var(--border);\n"
    css += "  border-radius: var(--radius-md);\n"
    css += "  background: var(--bg-elevated);\n"
    css += "  overflow: hidden;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(summary) {\n"
    css += "  cursor: pointer;\n"
    css += "  padding: 8px 12px;\n"
    css += "  font-weight: 500;\n"
    css += "  font-size: 13px;\n"
    css += "  user-select: none;\n"
    css += "  transition: background var(--duration-fast) ease;\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(summary:hover) {\n"
    css += "  background: var(--bg-hover);\n"
    css += "}\n\n"
    
    css += ".sidebar-markdown :where(details[open] > :not(summary)) {\n"
    css += "  padding: 0 12px 10px;\n"
    css += "}\n\n"
    
    # Mobile: Full-screen modal
    css += "/* Mobile: Full-screen modal */\n"
    css += "@media (max-width: 768px) {\n"
    css += "  .chat-split-container--open {\n"
    css += "    position: fixed;\n"
    css += "    top: 0;\n"
    css += "    left: 0;\n"
    css += "    right: 0;\n"
    css += "    bottom: 0;\n"
    css += "    z-index: 1000;\n"
    css += "  }\n\n"
    
    css += "  .chat-split-container--open .chat-main {\n"
    css += "    display: none; /* Hide chat on mobile when sidebar open */\n"
    css += "  }\n\n"
    
    css += "  .chat-split-container--open .chat-sidebar {\n"
    css += "    width: 100%;\n"
    css += "    min-width: 0;\n"
    css += "    border-left: none;\n"
    css += "  }\n"
    css += "}\n"
    
    return css

def main():
    if len(sys.argv) != 2:
        print("Usage: python sidebar_css_generator.py <output_file>")
        sys.exit(1)
    
    output_file = Path(sys.argv[1])
    css_content = generate_css()
    
    try:
        output_file.write_text(css_content, encoding='utf-8')
        print(f"CSS file generated successfully: {output_file}")
    except Exception as e:
        print(f"Error writing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
