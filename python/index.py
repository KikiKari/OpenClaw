#!/usr/bin/env python3
# index.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_html():
    """Generates the HTML structure for TikTok LIVE Companion documentation."""
    html_content = '''<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
    <meta name="theme-color" content="#ffffff" />
    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />
    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />
    <title>TikTok LIVE Companion – Dokumentation</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>'''
    return html_content

def main(output_file=None):
    """Main function to write HTML content to a file or stdout."""
    html_content = generate_html()
    
    if output_file:
        # Write to specified file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
    else:
        # Write to stdout
        print(html_content)

if __name__ == "__main__":
    # Check if output file is provided as command line argument
    output_file = sys.argv[1] if len(sys.argv) > 1 else None
    main(output_file)
