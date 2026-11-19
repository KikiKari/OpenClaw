#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f20db81399872e43d7e3a3f68f62bba758e9b0a88097340eb9f8bdc6b9666a61", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "python"}
# style.css — portiert nach python
# Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_css():
    """Generiert das CSS-Dokument als strukturierte Python-Repräsentation"""
    
    # Definition der CSS-Regeln als Liste von Dictionaries
    css_rules = [
        {
            'selector': '#content > h1:first-of-type',
            'declarations': {
                'display': 'none !important'
            }
        },
        {
            'selector': '.nav-tabs',
            'declarations': {
                'position': 'relative'
            }
        },
        {
            'selector': '.nav-tabs-item > div',
            'declarations': {
                'opacity': '0'
            }
        },
        {
            'selector': '.nav-tabs-underline',
            'declarations': {
                'position': 'absolute',
                'left': '0',
                'bottom': '0',
                'height': '1.5px',
                'width': 'var(--nav-tab-underline-width, 0)',
                'transform': 'translateX(var(--nav-tab-underline-x, 0))',
                'background-color': 'rgb(var(--primary))',
                'border-radius': '999px',
                'pointer-events': 'none',
                'opacity': '0',
                'transition': '''transform 260ms ease-in-out,
    width 260ms ease-in-out,
    opacity 160ms ease-in-out''',
                'will-change': 'transform, width'
            }
        },
        {
            'selector': 'html.dark .nav-tabs-underline',
            'declarations': {
                'background-color': 'rgb(var(--primary-light))'
            }
        },
        {
            'selector': '.nav-tabs-underline-ready .nav-tabs-underline',
            'declarations': {
                'opacity': '1'
            }
        }
    ]
    
    # Konvertiere die strukturierte Repräsentation in CSS-Text
    css_output = []
    for rule in css_rules:
        selector = rule['selector']
        declarations = rule['declarations']
        
        css_output.append(f"{selector} {{")
        for property_name, value in declarations.items():
            # Behandle mehrzeilige Werte (z.B. transition)
            if '\n' in value:
                lines = value.split('\n')
                css_output.append(f"  {property_name}: {lines[0]}")
                for line in lines[1:]:
                    css_output.append(f"    {line}")
            else:
                css_output.append(f"  {property_name}: {value};")
        css_output.append("}")
        css_output.append("")  # Leerzeile nach jeder Regel
    
    return '\n'.join(css_output[:-1])  # Entferne letzte Leerzeile

def write_css_to_file(content: str, filepath: str):
    """Schreibt den CSS-Inhalt in eine Datei"""
    path = Path(filepath)
    path.write_text(content, encoding='utf-8')

def main():
    """Hauptfunktion: Generiert CSS und schreibt es in eine Datei"""
    if len(sys.argv) != 2:
        print("Verwendung: python script.py <ausgabedatei>", file=sys.stderr)
        sys.exit(1)
    
    output_file = sys.argv[1]
    css_content = generate_css()
    write_css_to_file(css_content, output_file)

if __name__ == "__main__":
    main()
