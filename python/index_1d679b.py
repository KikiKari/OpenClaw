#!/usr/bin/env python3
# index.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

def create_html_document():
    # Create the root element
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
        'content': 'Dokumentation für TikTok LIVE Companion 0.7.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.'
    })
    meta_theme_color = SubElement(head, 'meta', {
        'name': 'theme-color',
        'content': '#ffffff'
    })
    
    # Add title
    title = SubElement(head, 'title')
    title.text = 'TikTok LIVE Companion – Dokumentation'
    
    # Create body section
    body = SubElement(html, 'body')
    
    # Add div with id root
    div_root = SubElement(body, 'div', {'id': 'root'})
    
    # Add script tag
    script = SubElement(body, 'script', {
        'type': 'module',
        'src': '/src/main.tsx'
    })
    
    return html

def prettify_xml(element):
    """Return a pretty-printed XML string for the Element."""
    rough_string = tostring(element, encoding='unicode')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ").strip()

def main():
    # Add doctype declaration manually
    doctype = '<!doctype html>'
    
    # Create HTML structure
    html_element = create_html_document()
    
    # Convert to pretty XML/HTML
    html_content = prettify_xml(html_element)
    
    # Remove the XML declaration that minidom adds
    if html_content.startswith('<?xml'):
        html_content = '\n'.join(html_content.split('\n')[1:])
    
    # Combine doctype and HTML content
    full_html = f"{doctype}\n{html_content}"
    
    # Write to file or stdout
    if len(sys.argv) > 1:
        filename = sys.argv[1]
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(full_html)
    else:
        print(full_html)

if __name__ == '__main__':
    main()
