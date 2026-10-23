#!/usr/bin/env python3
# offscreen.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import sys
import os

def create_offscreen_html(output_file):
    """Create the offscreen.html file with proper DOCTYPE and structure"""
    
    # Define the HTML content as a list of lines for better readability
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
    
    # Join the lines with newline characters
    html_string = '\n'.join(html_content) + '\n'
    
    # Write to the specified output file
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_string)
        print(f"Successfully created {output_file}")
    except IOError as e:
        print(f"Error writing to file {output_file}: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    # Check if output file path is provided as command line argument
    if len(sys.argv) != 2:
        print("Usage: python3 script.py <output_file_path>", file=sys.stderr)
        sys.exit(1)
    
    output_file = sys.argv[1]
    
    # Create directory if it doesn't exist
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
        except OSError as e:
            print(f"Error creating directory {output_dir}: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Generate the HTML file
    create_offscreen_html(output_file)

if __name__ == "__main__":
    main()
