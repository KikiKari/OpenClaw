#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8bb707f94150ee3df276681e56894dbc11b7543114f367cedee5fd5896e01998", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "python"}
# styles.css — portiert nach python
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import sys
from pathlib import Path

def generate_css_content() -> str:
    """Generiert den CSS-Inhalt dynamisch."""
    imports = [
        "./styles/base.css",
        "./styles/layout.css",
        "./styles/layout.mobile.css",
        "./styles/components.css",
        "./styles/chat.css",
        "./styles/config.css",
        "./styles/usage.css",
        "./styles/dreams.css",
        "@create-markdown/preview/themes/system.css"
    ]
    
    # Erstellen der @import Regeln
    css_imports = "\n".join(f'@import "{imp}";' for imp in imports)
    
    # Definition des cm-preview Blocks
    cm_preview = '''
.cm-preview {
  --cm-mono: var(--mono);
  --cm-link: var(--accent);
  --cm-info: var(--info);
  --cm-warning: var(--warn);
  --cm-success: var(--ok);
  --cm-danger: var(--danger);
}
'''.strip()
    
    # Kombinieren aller Teile
    return f"{css_imports}\n\n{cm_preview}\n"

def write_css_to_file(filepath: str) -> None:
    """Schreibt den generierten CSS-Inhalt in eine Datei."""
    content = generate_css_content()
    Path(filepath).write_text(content, encoding='utf-8')

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <output-file>")
        sys.exit(1)
        
    output_file = sys.argv[1]
    write_css_to_file(output_file)
