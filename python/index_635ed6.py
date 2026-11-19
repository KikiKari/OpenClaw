#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "037b5d80fc7a7b16ea288df1d32277cb89b2b9b0a46a3592b025b1d6881ec499", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "python"}
# index.html — portiert nach python
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import sys
import argparse
from pathlib import Path

def generate_html():
    """Generiert das HTML-Dokument als String"""
    lines = [
        '<!doctype html>',
        '<html lang="en">',
        '  <head>',
        '    <meta charset="utf-8" />',
        '    <meta name="viewport" content="width=device-width, initial-scale=1" />',
        '    <meta name="color-scheme" content="light dark" />',
        '    <title>QA Lab</title>',
        '  </head>',
        '  <body>',
        '    <div id="app"></div>',
        '    <script type="module" src="/src/main.ts"></script>',
        '  </body>',
        '</html>'
    ]
    return '\n'.join(lines) + '\n'

def main():
    parser = argparse.ArgumentParser(description='Erzeuge HTML-Datei')
    parser.add_argument('output_file', help='Ausgabedatei')
    args = parser.parse_args()
    
    html_content = generate_html()
    
    try:
        with open(args.output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
    except IOError as e:
        print(f"Fehler beim Schreiben der Datei: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
