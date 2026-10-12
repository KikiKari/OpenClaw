#!/usr/bin/env bash
# test_sync_real.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
# auch in: OpenClaw@gateway2:scripts/test_sync_real.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Test echte Synchronisation

# Füge das Verzeichnis zum Python-Pfad hinzu und importiere die Funktionen
export PYTHONPATH="/home/openclaw/.openclaw/workspace/scripts:$PYTHONPATH"

# Test: db-maintainer ClawHub → Git (ECHT)
echo "=== TEST: db-maintainer sync (REAL) ==="

# Führe die Python-Funktion aus und speichere das Ergebnis
if python3 -c "
import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git
result = sync_to_git('db-maintainer', dry_run=False)
print('SUCCESS' if result else 'FAILED')
sys.exit(0 if result else 1)
"; then
    echo "Result: SUCCESS"
    result=true
else
    echo "Result: FAILED"
    result=false
fi

# Prüfe Ergebnis
target="/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if [[ -d "$target" ]]; then
    echo ""
    echo "✅ Git-Repo erstellt: $target"
    
    # Zeige die Verzeichnisstruktur an
    find "$target" -type d -print | while read -r dir; do
        # Berechne die Tiefe relativ zum Zielverzeichnis
        relative_path="${dir#$target}"
        if [[ "$relative_path" == "" ]]; then
            echo "$(basename "$target")/"
        else
            # Entferne führenden Slash und zähle die Trennzeichen
            clean_path="${relative_path#/}"
            level=$(grep -o '/' <<< "$clean_path" | wc -l)
            indent=$(printf '  %.0s' $(seq 1 $((level+1))))
            echo "${indent}$(basename "$dir")/"
            
            # Zeige Dateien im Verzeichnis an
            find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | while read -r file; do
                file_indent=$(printf '  %.0s' $(seq 1 $((level+2))))
                echo "${file_indent}${file}"
            done
        fi
    done | grep -v "^$"
else
    # Wenn das Verzeichnis nicht existiert, zeige eine entsprechende Meldung
    if [[ "$result" == true ]]; then
        echo "❌ FEHLER: Sync erfolgreich, aber Repo nicht gefunden: $target"
    fi
fi
