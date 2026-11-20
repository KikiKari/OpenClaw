#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "21775b9846e30aee250ffa6452018728525dec51522db790fc8e357d1850f377", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "python"}
# glossary.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import os
from typing import List, Optional, Tuple

class GlossaryEntry:
    def __init__(self, source: str, target: str):
        self.source = source
        self.target = target

def load_glossary(path: str) -> Tuple[Optional[List[GlossaryEntry]], Optional[str]]:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = f.read()
    except FileNotFoundError:
        return (None, None)
    except Exception as e:
        return (None, str(e))
    
    try:
        entries_data = json.loads(data)
        entries = [GlossaryEntry(entry['source'], entry['target']) for entry in entries_data]
        return (entries, None)
    except json.JSONDecodeError as e:
        return (None, f"glossary parse failed: {str(e)}")
    except KeyError as e:
        return (None, f"glossary parse failed: missing key {str(e)}")
