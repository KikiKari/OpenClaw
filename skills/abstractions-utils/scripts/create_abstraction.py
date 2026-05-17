#!/usr/bin/env python3
"""
Schnelle Abstraktion eines einzelnen Scripts
"""

import argparse
import sys
from pathlib import Path
from datetime import datetime

# Template-Definitionen
TEMPLATES = {
    "perl5": {"ext": ".pl", "shebang": "#!/usr/bin/env perl", "header": "use strict;\nuse warnings;\nuse feature 'say';\n"},
    "perl6": {"ext": ".raku", "shebang": "#!/usr/bin/env raku", "header": "use v6;\n"},
    "javascript": {"ext": ".js", "shebang": "#!/usr/bin/env node", "header": "const fs = require('fs');\nconst path = require('path');\n"},
    "python": {"ext": ".py", "shebang": "#!/usr/bin/env python3", "header": "import sys\nimport os\nfrom pathlib import Path\n"},
    "shell": {"ext": ".sh", "shebang": "#!/bin/bash", "header": "set -euo pipefail\n"},
    "powershell": {"ext": ".ps1", "shebang": "#!/usr/bin/env pwsh", "header": "#Requires -Version 7\n"},
    "tcl": {"ext": ".tcl", "shebang": "#!/usr/bin/env tclsh", "header": "package require Tcl 8.6\n"},
    "ruby": {"ext": ".rb", "shebang": "#!/usr/bin/env ruby", "header": "require 'json'\nrequire 'fileutils'\n"},
    "lua": {"ext": ".lua", "shebang": "#!/usr/bin/env lua", "header": ""},
    "go": {"ext": ".go", "shebang": "// +build ignore", "header": "package main\n\nimport (\n    \"fmt\"\n    \"os\"\n)\n"},
}

REPO_PATH = Path("/home/openclaw/.openclaw/workspace/git/Abstraktionen")

def get_source_lang(script_path: Path) -> str:
    ext_map = {
        "py": "Python", "js": "JavaScript", "sh": "Shell",
        "pl": "Perl", "rb": "Ruby", "ps1": "PowerShell"
    }
    return ext_map.get(script_path.suffix[1:], "Unknown")

def create_stub(source_path: Path, target_lang: str) -> Path:
    if target_lang not in TEMPLATES:
        raise ValueError(f"Unknown language: {target_lang}")
    
    template = TEMPLATES[target_lang]
    source_lang = get_source_lang(source_path)
    
    # Lese Original
    try:
        with open(source_path, 'r', encoding='utf-8', errors='ignore') as f:
            original = f.read()
            preview_lines = original.split('\n')[:10]
    except Exception as e:
        preview_lines = [f"# Error reading: {e}"]
    
    # Zielverzeichnis
    target_dir = REPO_PATH / target_lang
    target_dir.mkdir(parents=True, exist_ok=True)
    
    target_file = target_dir / f"{source_path.stem}{template['ext']}"
    
    if target_file.exists():
        print(f"⚠️  Already exists: {target_file}")
        return target_file
    
    # Generiere Content
    content = f"""{template['shebang']}
# {source_path.stem} - {target_lang.title()} Version
# Portiert von {source_lang}
# Original: {source_path}
# Erstellt: {datetime.now().strftime('%Y-%m-%d %H:%M')}
#

{template['header']}
# === ORIGINAL PREVIEW ===
# {'\n# '.join(preview_lines)}
# === END PREVIEW ===

# TODO: Implementiere {source_lang} Funktionalität in {target_lang.title()}
# Hinweise:
# - Achte auf idiomatischen Stil
# - Implementiere gleiche Fehlerbehandlung
# - Nutze sprach-spezifische Best Practices

def main():
    pass

if __name__ == "__main__":
    main()
"""
    
    with open(target_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Created: {target_file}")
    return target_file

def main():
    parser = argparse.ArgumentParser(description="Create script abstraction")
    parser.add_argument("--source", "-s", required=True, help="Source script path")
    parser.add_argument("--target-lang", "-l", required=True, help="Target language")
    parser.add_argument("--use-model", "-m", help="Use AI model for generation")
    
    args = parser.parse_args()
    
    source_path = Path(args.source)
    if not source_path.exists():
        print(f"❌ Source not found: {source_path}")
        sys.exit(1)
    
    target_file = create_stub(source_path, args.target_lang)
    
    if args.use_model:
        print(f"🤖 Model generation with {args.use_model} - not yet implemented")
    
    print(f"\n📁 Abstraction ready at: {target_file}")
    print(f"📝 Next steps:")
    print(f"   1. Edit {target_file}")
    print(f"   2. Implement functionality")
    print(f"   3. Test with: {TEMPLATES[args.target_lang]['shebang'].split()[-1]} {target_file}")

if __name__ == "__main__":
    main()