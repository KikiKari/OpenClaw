#!/usr/bin/env bash
set -euo pipefail

COMPARE_DIR="/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR="/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP="89.58.15.220"
PORT="80"
SELF_PATH="$(realpath "$0")"

mapfile -d '' FILES < <(
  find "${COMPARE_DIR}" -maxdepth 1 -type f \
    ! -path "${SELF_PATH}" \
    -print0 | sort -z
)

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "Keine Dateien in ${COMPARE_DIR} gefunden."
  exit 1
fi

echo
echo "Bereitgestellte Dateien aus ${COMPARE_DIR}:"
for src in "${FILES[@]}"; do
  echo "- $(basename "${src}")"
done

echo
echo "Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):"
for src in "${FILES[@]}"; do
  file="$(basename "${src}")"
  echo "curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}"
done

echo
echo "Server auf Port ${PORT} aktiv. Beenden mit STRG+C."
echo

cd "${COMPARE_DIR}"
exec python3 -m http.server "${PORT}" --bind 0.0.0.0
