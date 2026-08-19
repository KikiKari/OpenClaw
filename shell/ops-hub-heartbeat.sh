#!/bin/bash
# ops-hub-heartbeat.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Aktualisiere den Statusbericht mit aktueller Zeit
status_path="$(dirname "$(readlink -f "$0")")/../docs/ops-hub/status.md"

function update_heartbeat() {
  local content
  if ! content=$(cat "$status_path" 2>/dev/null); then
    echo "❌ Konnte $status_path nicht lesen" >&2
    return
  fi

  # Aktuelle Zeit in deutscher Lokalisierung, Zeitzone Berlin
  local now
  now=$(date +"%d.%m.%Y, %H:%M:%S")

  # Ersetze den Teil nach "Letzter Heartbeat:" bis zum Zeilenende
  local updated
  updated=$(echo "$content" | sed "s/\(Letzter Heartbeat:\) [^:]*/\1 $now/")

  if echo "$updated" > "$status_path"; then
    echo "✅ Heartbeat aktualisiert: $now"
  else
    echo "❌ Konnte $status_path nicht schreiben" >&2
  fi
}

update_heartbeat
