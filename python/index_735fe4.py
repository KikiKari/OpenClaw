#!/usr/bin/env python3
# index.html — portiert nach python
# Quelle: html, OpenClaw@main:index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

def create_html_document():
    # Create the root element with DOCTYPE
    html = Element('html', {'lang': 'de'})
    
    # Head section
    head = SubElement(html, 'head')
    
    # Meta charset
    meta_charset = SubElement(head, 'meta', {'charset': 'utf-8'})
    
    # Link icon
    link_icon = SubElement(head, 'link', {'rel': 'icon', 'href': '/favicon.ico'})
    
    # Viewport meta
    meta_viewport = SubElement(head, 'meta', {
        'name': 'viewport',
        'content': 'width=device-width, initial-scale=1'
    })
    
    # Theme color meta
    meta_theme_color = SubElement(head, 'meta', {
        'name': 'theme-color',
        'content': '#0b1020'
    })
    
    # Description meta
    meta_description = SubElement(head, 'meta', {
        'name': 'description',
        'content': 'OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.'
    })
    
    # Apple touch icon
    link_apple_touch = SubElement(head, 'link', {
        'rel': 'apple-touch-icon',
        'href': '/logo192.png'
    })
    
    # Comment for manifest
    # Note: XML comments work differently, so we'll add a placeholder comment element
    # In real HTML this would be <!-- ... -->
    
    # Manifest link
    link_manifest = SubElement(head, 'link', {
        'rel': 'manifest',
        'href': '/manifest.json'
    })
    
    # Title
    title = SubElement(head, 'title')
    title.text = 'OpenClaw'
    
    # Body section
    body = SubElement(html, 'body')
    
    # Noscript message
    noscript = SubElement(body, 'noscript')
    noscript.text = 'You need to enable JavaScript to run this app.'
    
    # Root div
    root_div = SubElement(body, 'div', {'id': 'root'})
    
    # Second comment block
    # Another placeholder for the HTML comment
    
    # Script tag
    script = SubElement(body, 'script', {
        'type': 'module',
        'src': '/src/index.jsx'
    })
    
    return html

def prettify_xml(element):
    """Return a pretty-printed XML string for the Element."""
    rough_string = tostring(element, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ").replace('<?xml version="1.0" ?>\n', '')

def generate_html_file(output_path):
    """Generate the HTML file at the specified path."""
    html_doc = create_html_document()
    pretty_xml = prettify_xml(html_doc)
    
    # Manual adjustments to match HTML structure more closely
    # Replace xml declaration and adjust self-closing tags
    lines = pretty_xml.split('\n')
    # Remove empty lines that are artifacts of pretty printing
    lines = [line for line in lines if line.strip()]
    
    # Add DOCTYPE
    result_lines = ['<!DOCTYPE html>']
    
    for line in lines:
        # Adjust self-closing tags to match HTML style
        if '<meta ' in line and '/>' in line:
            line = line.replace('/>', '>')
        if '<link ' in line and '/>' in line:
            line = line.replace('/>', '>')
        result_lines.append(line)
    
    # Join and write to file
    html_content = '\n'.join(result_lines)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python script.py <output_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    generate_html_file(output_file)
    print(f"HTML file generated: {output_file}")
