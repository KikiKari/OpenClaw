#!/usr/bin/env python3
# offscreen.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: 2 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def create_offscreen_html(output_path):
    """Erstellt die offscreen.html Datei"""
    
    # HTML-Inhalt strukturiert erstellen
    html_content = [
        '<!doctype html>',
        '<html lang="de">',
        '<head>',
        '  <meta charset="utf-8">',
        '  <title>TikTok LIVE Companion Sprachausgabe</title>',
        '</head>',
        '<body>',
        '  <script src="offscreen.js"></script>',
        '</body>',
        '</html>'
    ]
    
    # Inhalt in Datei schreiben
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(html_content) + '\n')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python script.py <output_file>", file=sys.stderr)
        sys.exit(1)
    
    output_file = sys.argv[1]
    create_offscreen_html(output_file)
