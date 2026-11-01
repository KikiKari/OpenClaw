#!/usr/bin/env python3
# status-overview.css — portiert nach python
# Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.css
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

import sys
import argparse

def generate_css():
    """Generate the CSS content as a multi-line string."""
    css_content = [
        "*{box-sizing:border-box}",
        "html,body{margin:0;min-height:100%;background:#101015;color:#fff;font:14px system-ui,sans-serif}",
        "body{display:flex;flex-direction:column;height:100vh}",
        "header{display:flex;gap:1em;align-items:baseline;padding:0 12px}",
        "h1{font-size:17px;margin:8px 0}",
        "header p{font-size:12px;color:#bbb;margin:0}",
        "main{flex:1;min-height:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));grid-template-rows:repeat(3,minmax(0,1fr));gap:4px;padding:0}",
        ".tile{min-width:0;min-height:0;display:flex;flex-direction:column;background:#202026;border:1px solid #393940}",
        ".tile h2{font-size:13px;margin:3px 8px}",
        ".tile video{min-height:0;width:100%;flex:1;object-fit:contain;background:#000}",
        ".tile p{font-size:11px;margin:3px 8px;color:#ddd}",
        "",
        "main.grid2{grid-template-columns:repeat(2,minmax(0,1fr));grid-template-rows:repeat(2,minmax(0,1fr))}",
        ".tile[hidden]{display:none}"
    ]
    return "\n".join(css_content)

def write_css_to_file(filename):
    """Write the generated CSS to a file."""
    css_content = generate_css()
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(css_content)

def main():
    parser = argparse.ArgumentParser(description='Generate status-overview.css file')
    parser.add_argument('output_file', help='Output CSS file path')
    args = parser.parse_args()
    
    write_css_to_file(args.output_file)
    print(f"CSS file written to {args.output_file}")

if __name__ == "__main__":
    main()
