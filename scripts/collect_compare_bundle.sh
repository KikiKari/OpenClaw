#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/openclaw/.openclaw"
OUT_DIR="${ROOT}/workspace/vscode/compare"
TRANSFER_DIR="${OUT_DIR}/transfer"
MD_FILE="${OUT_DIR}/local-gateway-config.md"
TREE_FILE="${OUT_DIR}/tree.txt"
BACKUP_FILE="/home/openclaw/openclaw-backup.tar.gz"
NOW_LOCAL="$(date '+%Y-%m-%d %H:%M:%S %Z')"
NOW_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
HOST="$(hostname -f 2>/dev/null || hostname)"

OPENCLAW_JSON="${ROOT}/openclaw.json"
EXEC_APPROVALS_JSON="${ROOT}/exec-approvals.json"
GATEWAY_SYSTEMD_ENV="${ROOT}/gateway.systemd.env"
DOT_ENV="${ROOT}/.env"
CONFIG_DIR="${ROOT}/.config"
AGENTS_DIR="${ROOT}/agents"

mkdir -p "${OUT_DIR}"
mkdir -p "${TRANSFER_DIR}"

if ! command -v tree >/dev/null 2>&1; then
  echo "Fehler: 'tree' ist nicht installiert."
  exit 1
fi

append_file_verbatim() {
  local label="$1"
  local path="$2"
  local lang="${3:-text}"
  {
    echo
    echo "## ${label}"
    echo
    echo "Pfad: \`${path}\`"
    echo
    echo "\`\`\`${lang}"
    if [[ -f "${path}" ]]; then
      cat "${path}"
    else
      echo "[FEHLT] ${path}"
    fi
    echo
    echo "\`\`\`"
  } >> "${MD_FILE}"
}

append_env_verbatim() {
  {
    echo
    echo "## Umgebungsvariablen (env)"
    echo
    echo "\`\`\`text"
    env
    echo "\`\`\`"
  } >> "${MD_FILE}"
}

append_dir_files_verbatim() {
  local section="$1"
  local dir="$2"
  {
    echo
    echo "## ${section}"
    echo
    if [[ ! -d "${dir}" ]]; then
      echo "[FEHLT] ${dir}"
      return
    fi
    echo "Basisverzeichnis: \`${dir}\`"
  } >> "${MD_FILE}"

  while IFS= read -r -d '' f; do
    {
      echo
      echo "### Datei: \`${f}\`"
      echo
      echo "\`\`\`text"
      cat "${f}"
      echo
      echo "\`\`\`"
    } >> "${MD_FILE}"
  done < <(find "${dir}" -type f -print0 | sort -z)
}

cat > "${MD_FILE}" <<EOF2
# Lokaler Gateway-Konfigurationsstand

Generiert: ${NOW_LOCAL}
UTC: ${NOW_UTC}
Host: ${HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
EOF2

append_file_verbatim "openclaw.json" "${OPENCLAW_JSON}" "json"
append_file_verbatim "exec-approvals.json" "${EXEC_APPROVALS_JSON}" "json"
append_file_verbatim "gateway.systemd.env" "${GATEWAY_SYSTEMD_ENV}" "dotenv"
append_file_verbatim ".env" "${DOT_ENV}" "dotenv"
append_env_verbatim
append_dir_files_verbatim ".config (alle Dateien rekursiv)" "${CONFIG_DIR}"
append_dir_files_verbatim "agents (alle Dateien rekursiv)" "${AGENTS_DIR}"

tree -a -L 6 "${ROOT}" > "${TREE_FILE}"
openclaw backup create --output "${BACKUP_FILE}" --verify
cp "${BACKUP_FILE}" "${OUT_DIR}"

echo "OK"
echo "Erzeugt:"
echo "- ${MD_FILE}"
echo "- ${TREE_FILE}"
echo "- ${BACKUP_FILE}"
echo "- ${TRANSFER_DIR} (leer)"
