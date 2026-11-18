#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "0ada3bf6005ef6ef7d841de6181110b68b4406d918b92a6f044f6192a4c14b35", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "shell"}
# ops-hub-heartbeat.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Aktualisiere den Statusbericht mit aktueller Zeit
status_path="$(dirname "$(readlink -f "$0")")/../docs/ops-hub/status.md"

function update_heartbeat() {
  local content
  if ! content=$(<"$status_path"); then
    echo "❌ Konnte status.md nicht lesen" >&2
    return
  fi

  # Setze die Zeitzone auf Europe/Berlin und formatiere das Datum
  local now
  now=$(TZ='Europe/Berlin' date '+%d.%m.%Y, %H:%M:%S')

  # Ersetze den Heartbeat-Text
  local updated
  updated=$(echo "$content" | sed -E "s/(Letzter Heartbeat:) [^$]*/\1 $now/")

  # Schreibe die aktualisierten Inhalte zurück
  if echo "$updated" > "$status_path"; then
    echo "✅ Heartbeat aktualisiert: $now"
  else
    echo "❌ Konnte status.md nicht schreiben" >&2
  fi
}

update_heartbeat
