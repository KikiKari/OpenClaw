#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "7dea3c0a4589357442f9d37fb49f73efecd3020f45fd7c80283fbd4ec681bc12", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "shell"}
# glossary.go — portiert nach shell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variable für Glossar-Einträge (als assoziatives Array simuliert)
declare -a GLOSSARY_ENTRIES=()

# Funktion zum Laden des Glossars aus einer JSON-Datei
# Parameter:
#   $1: Pfad zur JSON-Datei
# Rückgabe:
#   0 bei Erfolg, 1 bei Fehler
#   GLOSSARY_ENTRIES wird mit den geladenen Einträgen gefüllt
load_glossary() {
    local path="$1"
    
    # Prüfen ob Datei existiert
    if [[ ! -f "$path" ]]; then
        # Wenn Datei nicht existiert, leeres Array zurückgeben (kein Fehler)
        GLOSSARY_ENTRIES=()
        return 0
    fi
    
    # JSON parsen mit jq (wenn verfügbar) oder alternativ mit python3
    if command -v jq >/dev/null 2>&1; then
        # Mit jq parsen
        mapfile -t GLOSSARY_ENTRIES < <(jq -c '.[]' "$path" 2>/dev/null) || {
            echo "glossary parse failed: invalid json format" >&2
            return 1
        }
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback mit Python3
        local python_script='
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    for entry in data:
        print(json.dumps(entry))
except Exception as e:
    print("glossary parse failed:", str(e), file=sys.stderr)
    sys.exit(1)
'
        mapfile -t GLOSSARY_ENTRIES < <(python3 -c "$python_script" "$path" 2>/dev/null) || {
            echo "glossary parse failed: invalid json format" >&2
            return 1
        }
    else
        echo "glossary parse failed: neither jq nor python3 available for json parsing" >&2
        return 1
    fi
    
    return 0
}
