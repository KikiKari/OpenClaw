#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "522d640550d938ec066dbf70f1435302f889b5e3eb099b2ec0731b9303355a33", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "python"}
# changelog-to-html.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import re

def extract_version_section(version, file_path):
    """Extract the section for a specific version from the changelog file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    found = False
    result_lines = []
    
    version_pattern = re.compile(r'^##\s+' + re.escape(version) + r'(\s.*|$)')
    
    for line in lines:
        if line.startswith('## '):
            if version_pattern.match(line):
                found = True
                continue  # Skip the version header itself
            elif found:
                break  # We've reached the next version section
        elif found:
            result_lines.append(line)
    
    return ''.join(result_lines).strip()

def markdown_to_html(text):
    """Convert markdown-like syntax to HTML."""
    # Convert headers
    text = re.sub(r'^##### (.*)$', r'<h5>\1</h5>', text)
    text = re.sub(r'^#### (.*)$', r'<h4>\1</h4>', text)
    text = re.sub(r'^### (.*)$', r'<h3>\1</h3>', text)
    text = re.sub(r'^## (.*)$', r'<h2>\1</h2>', text)
    
    # Convert list items with bold text
    text = re.sub(r'^- \*\*([^*]*)\*\*(.*)$', r'<li><strong>\1</strong>\2</li>', text)
    # Convert regular list items
    text = re.sub(r'^- ([^*].*)$', r'<li>\1</li>', text)
    
    # Convert bold text
    text = re.sub(r'\*\*([^*]*)\*\*', r'<strong>\1</strong>', text)
    
    # Convert inline code
    text = re.sub(r'`([^`]*)`', r'<code>\1</code>', text)
    
    # Convert links
    text = re.sub(r'\[([^\]]*)\]\(([^)]*)\)', r'<a href="\2">\1</a>', text)
    
    return text

def main():
    if len(sys.argv) < 2:
        print("Usage: {} <version> [changelog_file]".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)
    
    version = sys.argv[1]
    changelog_file = sys.argv[2] if len(sys.argv) > 2 else ""
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if not changelog_file:
        possible_paths = [
            os.path.join(script_dir, "..", "CHANGELOG.md"),
            "CHANGELOG.md",
            os.path.join("..", "CHANGELOG.md")
        ]
        
        for path in possible_paths:
            if os.path.isfile(path):
                changelog_file = path
                break
        
        if not changelog_file:
            print("Error: Could not find CHANGELOG.md", file=sys.stderr)
            sys.exit(1)
    
    if not os.path.isfile(changelog_file):
        print("Error: Changelog file '{}' not found".format(changelog_file), file=sys.stderr)
        sys.exit(1)
    
    version_content = extract_version_section(version, changelog_file)
    
    if not version_content:
        print("<h2>OpenClaw {}</h2>".format(version))
        print("<p>Latest OpenClaw update.</p>")
        print("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")
        return
    
    print("<h2>OpenClaw {}</h2>".format(version))
    
    lines = version_content.split('\n')
    in_list = False
    
    for line in lines:
        if line.strip().startswith('-'):
            if not in_list:
                print("<ul>")
                in_list = True
            print(markdown_to_html(line))
        else:
            if in_list:
                print("</ul>")
                in_list = False
            if line.strip():
                print(markdown_to_html(line))
    
    if in_list:
        print("</ul>")
    
    print("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")

if __name__ == "__main__":
    main()
