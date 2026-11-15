#!/bin/sh
set -eu

: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY fehlt}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN fehlt}"
interval="${ABSTRACTIONS_INTERVAL_SECONDS:-43200}"
case "$interval" in
  ''|*[!0-9]*|0) echo 'Ungültiges Laufintervall' >&2; exit 1 ;;
esac

trap 'exit 0' INT TERM
while :; do
  if python3 /app/ABSTRACTIONS_MANAGER.py; then
    echo 'Abstraction-Manager-Lauf abgeschlossen'
  else
    echo 'Abstraction-Manager-Lauf fehlgeschlagen; Zustand bleibt erhalten' >&2
  fi
  sleep "$interval" &
  wait "$!" || exit 0
done
