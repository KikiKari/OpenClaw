#!/usr/bin/env python3
# index.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
import argparse
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom


def create_html_document():
    """Create the HTML document structure"""
    # Create root element
    html = Element('html', {'lang': 'de'})
    
    # Create head section
    head = SubElement(html, 'head')
    
    # Add meta tags
    meta_charset = SubElement(head, 'meta', {'charset': 'UTF-8'})
    meta_viewport = SubElement(head, 'meta', {
        'name': 'viewport',
        'content': 'width=device-width, initial-scale=1.0'
    })
    meta_description = SubElement(head, 'meta', {
        'name': 'description',
        'content': 'Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.'
    })
    meta_theme_color = SubElement(head, 'meta', {
        'name': 'theme-color',
        'content': '#ffffff'
    })
    
    # Add link tags
    link_icon = SubElement(head, 'link', {
        'rel': 'icon',
        'type': 'image/png',
        'href': '/branding/staenderglobus-ios.png'
    })
    link_apple_touch = SubElement(head, 'link', {
        'rel': 'apple-touch-icon',
        'href': '/branding/staenderglobus-ios.png'
    })
    
    # Add title
    title = SubElement(head, 'title')
    title.text = 'TikTok LIVE Companion – Dokumentation'
    
    # Create body section
    body = SubElement(html, 'body')
    
    # Add div with id root
    root_div = SubElement(body, 'div', {'id': 'root'})
    
    # Add script tag
    script = SubElement(body, 'script', {
        'type': 'module',
        'src': '/src/main.tsx'
    })
    
    return html


def prettify_xml(element):
    """Return a pretty-printed XML string for the Element"""
    rough_string = tostring(element, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")[23:]  # Remove XML declaration


def main():
    parser = argparse.ArgumentParser(description='Generate HTML documentation file')
    parser.add_argument('output_file', help='Output file path')
    
    args = parser.parse_args()
    
    # Create HTML document
    html_doc = create_html_document()
    
    # Convert to pretty formatted string
    html_string = '<!doctype html>\n' + prettify_xml(html_doc)
    
    # Write to file
    with open(args.output_file, 'w', encoding='utf-8') as f:
        f.write(html_string)


if __name__ == '__main__':
    main()
