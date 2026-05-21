#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/.openclaw"
OUT_DIR="${BASE_DIR}/workspace/vscode"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
NOW_LOCAL="$(date +"%Y-%m-%d %H:%M:%S %Z")"
TS="$(date +"%Y%m%d-%H%M%S")"

mkdir -p "${OUT_DIR}"

IST_FILE="${OUT_DIR}/IST-ZUSTAND_GATEWAY-B_NODE7.md"
INV_FILE="${OUT_DIR}/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
CFG_FILE="${OUT_DIR}/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
ENV_FILE="${OUT_DIR}/ENV-STATUS_GATEWAY-B_NODE7.md"
RUN_FILE="${OUT_DIR}/RUN-${TS}.md"

OPENCLAW_JSON="${BASE_DIR}/openclaw.json"
ENV_DOT="${BASE_DIR}/.env"
ENV_SYSTEMD="${BASE_DIR}/gateway.systemd.env"
VSCODE_DIR="${BASE_DIR}/.vscode"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
HOSTNAME_SHORT="$(hostname)"
ARCH="$(uname -m)"
KERNEL="$(uname -r)"
OS_PRETTY="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
IPV4_ALL="$(hostname -I 2>/dev/null | xargs || true)"
PUBLIC_IP="$(curl -4 -s --max-time 4 ifconfig.me 2>/dev/null || true)"
TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
OPENCLAW_VER="$(openclaw --version 2>/dev/null || true)"
NODE_VER="$(node -v 2>/dev/null || true)"

if [[ -z "${PUBLIC_IP}" ]]; then
  PUBLIC_IP="(nicht ermittelt)"
fi
if [[ -z "${TAILSCALE_IP}" ]]; then
  TAILSCALE_IP="(nicht ermittelt)"
fi
if [[ -z "${OPENCLAW_VER}" ]]; then
  OPENCLAW_VER="(nicht ermittelt)"
fi
if [[ -z "${NODE_VER}" ]]; then
  NODE_VER="(nicht ermittelt)"
fi

cat > "${IST_FILE}" <<EOF
# IST-Zustand: Gateway B / Node 7

Stand (lokal): ${NOW_LOCAL}  
Stand (UTC): ${NOW_UTC}

## 1) Identität & System

- Gateway: **B**
- Node: **7**
- Hostname (short): \`${HOSTNAME_SHORT}\`
- Hostname (FQDN): \`${HOSTNAME_FQDN}\`
- Architektur: \`${ARCH}\`
- Kernel: \`${KERNEL}\`
- OS: \`${OS_PRETTY}\`
- IPv4 (lokal): \`${IPV4_ALL}\`
- Public IPv4: \`${PUBLIC_IP}\`
- Tailscale IPv4: \`${TAILSCALE_IP}\`
- OpenClaw Version: \`${OPENCLAW_VER}\`
- Node.js Version: \`${NODE_VER}\`

## 2) Arbeitsverzeichnisse

- Basis: \`${BASE_DIR}\`
- Funktionell VSCode: \`${VSCODE_DIR}\`
- Workspace Doku: \`${OUT_DIR}\`

## 3) Kernartefakte (Existenz)

- \`${OPENCLAW_JSON}\`: $( [[ -f "${OPENCLAW_JSON}" ]] && echo "vorhanden" || echo "fehlt" )
- \`${ENV_DOT}\`: $( [[ -f "${ENV_DOT}" ]] && echo "vorhanden" || echo "fehlt" )
- \`${ENV_SYSTEMD}\`: $( [[ -f "${ENV_SYSTEMD}" ]] && echo "vorhanden" || echo "fehlt" )
- \`${BASE_DIR}/plugins/installs.json\`: $( [[ -f "${BASE_DIR}/plugins/installs.json" ]] && echo "vorhanden" || echo "fehlt" )
- \`${BASE_DIR}/plugin-skills\`: $( [[ -d "${BASE_DIR}/plugin-skills" ]] && echo "vorhanden" || echo "fehlt" )

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt.
EOF

{
  echo "# Artefakt-Inventar: Gateway B / Node 7"
  echo
  echo "Stand: ${NOW_LOCAL}"
  echo
  echo "## Top-Level in ~/.openclaw"
  echo
  echo '```text'
  ls -1 "${BASE_DIR}" 2>/dev/null || true
  echo '```'
  echo
  echo "## ~/.openclaw/.vscode"
  echo
  echo '```text'
  if [[ -d "${VSCODE_DIR}" ]]; then
    ls -la "${VSCODE_DIR}"
  else
    echo "(nicht vorhanden)"
  fi
  echo '```'
  echo
  echo "## plugin-skills/"
  echo
  echo '```text'
  if [[ -d "${BASE_DIR}/plugin-skills" ]]; then
    ls -1 "${BASE_DIR}/plugin-skills" || true
  else
    echo "(nicht vorhanden)"
  fi
  echo '```'
  echo
  echo "## openclaw.json Backups"
  echo
  echo '```text'
  ls -1 "${BASE_DIR}"/openclaw.json.bak* 2>/dev/null || echo "(keine gefunden)"
  echo '```'
} > "${INV_FILE}"

{
  echo "# OpenClaw Config Snapshot: Gateway B / Node 7"
  echo
  echo "Stand: ${NOW_LOCAL}"
  echo
  echo "## Schlüsselpositionen (grep)"
  echo
  echo '```text'
  if [[ -f "${OPENCLAW_JSON}" ]]; then
    grep -nE '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"' "${OPENCLAW_JSON}" || true
  else
    echo "openclaw.json fehlt"
  fi
  echo '```'
  echo
  echo "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
  echo
  echo '```json'
  if [[ -f "${OPENCLAW_JSON}" ]]; then
    sed -n '580,780p' "${OPENCLAW_JSON}" || true
  else
    echo "{ \"error\": \"openclaw.json fehlt\" }"
  fi
  echo '```'
} > "${CFG_FILE}"

{
  echo "# ENV-Status: Gateway B / Node 7"
  echo
  echo "Stand: ${NOW_LOCAL}"
  echo
  echo "## Dateien"
  echo
  echo '```text'
  ls -la "${ENV_DOT}" "${ENV_SYSTEMD}" 2>/dev/null || true
  echo '```'
  echo
  echo "## .env (vollständig, ungefiltert)"
  echo
  echo '```dotenv'
  [[ -f "${ENV_DOT}" ]] && cat "${ENV_DOT}" || echo "# .env fehlt"
  echo '```'
  echo
  echo "## gateway.systemd.env (vollständig, ungefiltert)"
  echo
  echo '```dotenv'
  [[ -f "${ENV_SYSTEMD}" ]] && cat "${ENV_SYSTEMD}" || echo "# gateway.systemd.env fehlt"
  echo '```'
} > "${ENV_FILE}"

cat > "${RUN_FILE}" <<EOF
# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): ${NOW_LOCAL}
- Zeit (UTC): ${NOW_UTC}
- Script: $(realpath "$0")

## Erzeugte Dateien

- $(basename "${IST_FILE}")
- $(basename "${INV_FILE}")
- $(basename "${CFG_FILE}")
- $(basename "${ENV_FILE}")

EOF

echo "OK: IST-Zustand erfasst."
echo "Ausgabeordner: ${OUT_DIR}"
echo "Dateien:"
ls -1 "${OUT_DIR}" | sed 's/^/- /'
