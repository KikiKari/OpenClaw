#!/bin/bash
# post-nodes-report.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Pfade
DASHBOARD_PATH="../dashboards/nodes-overview.md"
REPORT_LOG="../logs/nodes-report.log"

# Farbcodes
readonly GREEN=$'\x1b[32m'
readonly YELLOW=$'\x1b[33m'
readonly RED=$'\x1b[31m'
readonly RESET=$'\x1b[0m'

post_report() {
  local content
  if ! content=$(<"$DASHBOARD_PATH"); then
    echo "${RED}❌ Fehler beim Lesen der Dashboard-Datei:${RESET}" >&2
    echo "Konnte $DASHBOARD_PATH nicht lesen" >&2
    return
  fi

  # Nachricht über OpenClaw message senden
  # JSON-kompatiblen String erstellen und neue Zeilen escapen
  local escaped_content
  escaped_content=$(printf '%s' "$content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')

  local message_cmd=(openclaw message send --target=main --message "$escaped_content")

  if "${message_cmd[@]}" >/dev/null 2>&1; then
    echo "${GREEN}✅ Report erfolgreich im 'main'-Channel gepostet.${RESET}"
    echo "[${(T)$(date -Iseconds)}] Report posted." >> "$REPORT_LOG"
  else
    local error_msg="Fehler beim Ausführen von openclaw"
    echo "${RED}❌ Fehler beim Senden der Nachricht:${RESET}" >&2
    echo "$error_msg" >&2
    echo "[${(T)$(date -Iseconds)}] Failed to post: $error_msg" >> "$REPORT_LOG"
  fi
}

# Hauptausführung
echo "${YELLOW}📤 Sende Nodes-Übersicht in 'main'...${RESET}"
post_report
