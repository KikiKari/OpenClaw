#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3291b5587e01dea12f803117dd198004486b64526b98299ccccbcbaa337143d0", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "python"}
# copy-plugin-sdk-root-alias.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from pathlib import Path

# Importiere die gemeinsam genutzte Funktion
from runtime_postbuild_shared import write_text_file_if_changed

def copy_plugin_sdk_root_alias(cwd=None):
    """
    Kopiert die root-alias.cjs Datei vom src zum dist Verzeichnis,
    falls sich der Inhalt geändert hat.
    """
    if cwd is None:
        cwd = Path.cwd()
    
    source = Path(cwd) / "src" / "plugin-sdk" / "root-alias.cjs"
    target = Path(cwd) / "dist" / "plugin-sdk" / "root-alias.cjs"
    
    # Lese den Inhalt der Quelldatei
    with open(source, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Schreibe die Datei nur, wenn sich der Inhalt geändert hat
    write_text_file_if_changed(str(target), content)

if __name__ == "__main__":
    # Prüfe, ob das Skript direkt ausgeführt wird
    if len(sys.argv) > 0 and sys.argv[0]:
        copy_plugin_sdk_root_alias()
