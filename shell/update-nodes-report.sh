#!/bin/bash
# update-nodes-report.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/update-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/update-nodes-report.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Pfade
DASHBOARD_PATH="$(dirname "$0")/../dashboards/nodes-overview.md"

# Farbcodes für Konsole
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'
C_BLUE=$'\e[34m'
C_RESET=$'\e[0m'

getNodeStatus() {
  if ! command -v openclaw >/dev/null 2>&1; then
    echo "${C_RED}❌ 'openclaw' Befehl nicht gefunden!${C_RESET}" >&2
    return 1
  fi

  local output
  if output=$(openclaw nodes status --json 2>/dev/null); then
    echo "$output"
  else
    echo "${C_RED}❌ Fehler beim Abrufen des Node-Status.${C_RESET}" >&2
    return 1
  fi
}

updateDashboard() {
  local nodes_json="$1"
  local now
  now=$(date +"%d.%m.%Y, %H:%M:%S")

  # Manuelle Ergänzung statischer Konfigurationen (da nicht alle Infos über CLI)
  declare -A NODE_CONFIG=(
    [1]="Gateway|Ubuntu 22.04|152.53.145.65|10.10.0.1|–|Gateway"
    [2]="Netcup Server|Ubuntu 22.04|78.46.123.10|10.10.0.2|–|Node"
    [3]="xNetX VPS|Debian 11|5.45.105.20|–|Port 18794|Node"
    [4]="Webhosting|Shared Linux|–|–|–|–"
    [5]="Redmi Note 11|Android|–|10.10.0.5|–|Node"
    [6]="Lenovo (Win)|Windows 11|–|–|–|Node"
  )

  local rows=()
  local nodeId
  for nodeId in "${!NODE_CONFIG[@]}"; do
    IFS='|' read -r name os ip wg tunnel mode <<< "${NODE_CONFIG[$nodeId]}"

    local node_entry=""
    local node_name_first_word="${name%% *}"
    while IFS= read -r line; do
      if [[ "$line" == *"\"nodeId\":\"$nodeId\""* ]] || [[ "$line" == *"\"name\":\"*$node_name_first_word"* ]]; then
        node_entry="$line"
        break
      fi
    done < <(echo "$nodes_json" | jq -c '.[]')

    local status_vpn="⚠️"
    local last_seen_ts=""
    if [[ -n "$node_entry" ]]; then
      local status_val
      status_val=$(echo "$node_entry" | jq -r '.status')
      if [[ "$status_val" == "paired" ]]; then
        status_vpn="✅"
      else
        status_vpn="🔴"
      fi
      last_seen_ts=$(echo "$node_entry" | jq -r '.lastSeen')
    fi

    local status_ssh="❌"
    if [[ "$tunnel" != "–" ]]; then
      status_ssh="✅"
    fi

    local ssh_key="❌"
    case "$nodeId" in
      1) ssh_key="Local (id_ed25519)" ;;
      2|3) ssh_key="❌ (Pending)" ;;
      *) ssh_key="❌" ;;
    esac

    local last_check="–"
    if [[ -n "$last_seen_ts" && "$last_seen_ts" != "null" ]]; then
      last_check=$(date -d "@$last_seen_ts" +"%d.%m.%Y, %H:%M:%S")
    fi

    rows+=("| $nodeId    | $name | $os | $ip | $mode       | $wg             | $tunnel | $status_vpn | $status_ssh | $ssh_key | $last_check |")
  done

  local content="# Nodes Overview (Network Status)

| Node | Name          | OS           | IP             | Mode       | Primär WG IP       | Sekundär/SSH Tunnel | StatusVPN | StatusSSH | SSH Key (Deployed) | Letzter Check       |
|------|---------------|--------------|----------------|------------|--------------------|---------------------|-----------|-----------|---------------------|---------------------|
$(printf '%s\n' "${rows[@]}")

> 💡 **Legende:** 
> - **Primär WG IP**: Die WireGuard-VPN-IP des Nodes
> - **Sekundär/SSH Tunnel**: Fallback-Mechanismus (z. B. Reverse-Tunnel)
> - **StatusVPN**: Verbunden über OpenClaw/WireGuard
> - **StatusSSH**: SSH-Zugriff via Reverse-Tunnel aktiv
> - **SSH Key (Deployed)**: Zeigt an, ob der Gateway-Schlüssel (\`id_ed25519\`) auf dem Ziel bereitgestellt ist
> - Letzter Stand: **$now CET**

*Größe: ~1.8 KB | Automatisch aktualisiert via \`update-nodes-report.sh\`*"

  if echo "$content" > "$DASHBOARD_PATH"; then
    echo "${C_GREEN}✅ Dashboard aktualisiert:${C_RESET} $DASHBOARD_PATH"
  else
    echo "${C_RED}❌ Fehler beim Schreiben der Datei.${C_RESET}" >&2
    return 1
  fi
}

main() {
  echo "${C_BLUE}🔄 Aktualisiere Nodes-Übersicht...${C_RESET}"
  local nodes_json
  if ! nodes_json=$(getNodeStatus); then
    exit 1
  fi
  updateDashboard "$nodes_json"
}

main "$@"
