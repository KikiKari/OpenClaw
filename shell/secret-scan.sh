#!/usr/bin/env bash
# secret-scan.mjs — portiert nach shell
# Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Wurzelverzeichnis bestimmen (übergeordnetes Verzeichnis des Skripts)
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verzeichnisse, die übersprungen werden sollen
skipped=(
  "node_modules"
  ".next"
  ".git"
  ".pytest_cache"
  "__pycache__"
  "media-production/raw"
  "media-production/private"
)

# Geheime Schlüssel-Muster (Regex-Patterns)
patterns=(
  'sk-(proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}'
  '(nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}'
  'ELEVENLABS_API_KEY[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9]{20,}'
  'WAVESPEED_API_KEY[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9]{20,}'
)

# Liste für Funde
findings=()

# Funktion zum Überprüfen, ob ein Pfad übersprungen werden soll
should_skip() {
  local rel_path="$1"
  local dir
  for dir in "${skipped[@]}"; do
    # Prüfe auf direkte Übereinstimmung, Präfix oder Teilpfad
    if [[ "$rel_path" == "$dir" ]] || [[ "$rel_path" == "$dir/"* ]] || [[ "$rel_path" == */"$dir"/* ]] || [[ "$rel_path" == */"$dir" ]]; then
      return 0
    fi
  done
  return 1
}

# Rekursives Durchsuchen von Verzeichnissen
walk() {
  local current_dir="$1"
  local rel_base="${2:-}"

  # Schleife durch alle Einträge im aktuellen Verzeichnis
  for entry in "$current_dir"/*; do
    # Falls das Glob nicht aufgelöst wird, überspringen
    [[ -e "$entry" ]] || continue

    local basename_entry="$(basename "$entry")"
    local rel_path="${rel_base:+$rel_base/}$basename_entry"

    # Überspringe .env-Dateien außer .env.example
    if [[ "$basename_entry" == ".env" ]] || { [[ "$basename_entry" == ".env."* ]] && [[ "$basename_entry" != ".env.example" ]]; }; then
      continue
    fi

    # Prüfe, ob der aktuelle Pfad übersprungen werden soll
    if should_skip "$rel_path"; then
      continue
    fi

    if [[ -d "$entry" ]]; then
      # Rekursiver Aufruf für Unterverzeichnisse
      walk "$entry" "$rel_path"
    elif [[ -f "$entry" ]]; then
      # Prüfe die Dateigröße (max. 2 MB)
      local size
      size=$(stat -c %s "$entry" 2>/dev/null || echo 0)
      if (( size < 2000000 )); then
        # Suche nach Mustern in der Datei
        local pattern
        for pattern in "${patterns[@]}"; do
          if grep -qE "$pattern" "$entry" 2>/dev/null; then
            findings+=("$rel_path")
            break
          fi
        done
      fi
    fi
  done
}

# Starte das Durchsuchen vom Wurzelverzeichnis
walk "$root"

# Entferne Duplikate aus den Funden
unique_findings=()
declare -A seen
for finding in "${findings[@]}"; do
  if [[ -z "${seen[$finding]+_}" ]]; then
    unique_findings+=("$finding")
    seen["$finding"]=1
  fi
done

# Ergebnisausgabe
if [[ ${#unique_findings[@]} -gt 0 ]]; then
  echo "Secret-Scan fehlgeschlagen: ${unique_findings[*]}" >&2
  exit 1
else
  echo "Secret-Scan bestanden."
fi
