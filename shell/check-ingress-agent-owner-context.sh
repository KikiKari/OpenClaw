#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "c6e0c2a307debcc6959964bba58baa30ae07454a537957458d29b916ce6f5381", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "shell"}
# check-ingress-agent-owner-context.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
declare -a source_roots=("src/gateway" "plugins/discord/src/voice")
declare -a enforced_files=(
  "plugins/discord/src/voice/manager.ts"
  "src/gateway/openai-http.ts"
  "src/gateway/openresponses-http.ts"
  "src/gateway/server-methods/agent.ts"
  "src/gateway/server-node-events.ts"
)

# Funktion zur Überprüfung, ob eine Datei erzwungen ist
is_enforced_file() {
  local file_path="$1"
  for ef in "${enforced_files[@]}"; do
    if [[ "$file_path" == "$ef" ]]; then
      return 0
    fi
  done
  return 1
}

# Funktion zum Finden von Zeilen mit agentCommand-Aufrufen
find_legacy_agent_command_call_lines() {
  local file_content="$1"
  echo "$file_content" | grep -n "agentCommand(" | cut -d: -f1 || true
}

# Hauptfunktion
main() {
  local header="Found ingress callsites using local agentCommand() (must be explicit owner-aware):"
  local footer="Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
  local found_issues=0

  # Durchlaufe alle Quellverzeichnisse
  for root in "${source_roots[@]}"; do
    if [[ ! -d "$root" ]]; then
      continue
    fi

    # Finde alle .ts Dateien im Verzeichnisbaum
    while IFS= read -r -d '' file; do
      # Berechne relativen Pfad
      rel_path="${file#./}"
      
      # Überspringe nicht erzwungene Dateien
      if ! is_enforced_file "$rel_path"; then
        continue
      fi

      # Lese Dateiinhalt
      content=$(cat "$file")

      # Suche nach legacy agentCommand Aufrufen
      call_lines=$(find_legacy_agent_command_call_lines "$content")
      
      if [[ -n "$call_lines" ]]; then
        if [[ $found_issues -eq 0 ]]; then
          echo "$header"
          found_issues=1
        fi
        
        echo "In file: $rel_path"
        while IFS= read -r line_num; do
          if [[ -n "$line_num" ]]; then
            echo "  Line $line_num: $(sed -n "${line_num}p" "$file" | xargs)"
          fi
        done <<< "$call_lines"
        echo ""
      fi
    done < <(find "$root" -name "*.ts" -type f -print0 2>/dev/null)
  done

  if [[ $found_issues -eq 1 ]]; then
    echo "$footer"
    exit 1
  fi
}

# Skript als Hauptprogramm ausführen
main "$@"
