#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "66b83e1026e875b245610f440fd87b9785441c80cce75a8662ac249b0b4e457d", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "python"}
# chat.css — portiert nach python
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_chat_css(output_path):
    """Generiert die chat.css Datei mit den entsprechenden Imports."""
    
    # Liste der zu importierenden CSS-Dateien
    imports = [
        "./chat/layout.css",
        "./chat/text.css", 
        "./chat/grouped.css",
        "./chat/tool-cards.css",
        "./chat/sidebar.css"
    ]
    
    # Erzeuge den CSS-Inhalt
    css_content = ""
    for import_path in imports:
        css_content += f'@import "{import_path}";\n'
    
    # Schreibe den Inhalt in die Ausgabedatei
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(css_content)

def main():
    """Hauptfunktion - liest den Ausgabepfad aus den Kommandozeilenargumenten."""
    if len(sys.argv) != 2:
        print("Usage: python chat_css_generator.py <output_file>", file=sys.stderr)
        sys.exit(1)
    
    output_path = sys.argv[1]
    generate_chat_css(output_path)

if __name__ == "__main__":
    main()
