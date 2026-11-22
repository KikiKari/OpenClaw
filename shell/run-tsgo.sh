#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "cfdb46c8dcc564c2f0cf46de29aeb9e903a7e45ae96f99fddf7d8932a189c83a", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "shell"}
# run-tsgo.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Funktion zum Lesen eines Flag-Werts
read_flag_value() {
  local args=("$@")
  local name="$1"
  shift
  for ((index = 0; index < $#; index++)); do
    local arg="${args[$index]}"
    if [[ "$arg" == "$name" ]]; then
      echo "${args[$((index + 1))]}"
      return
    fi
    if [[ "$arg" == "$name="* ]]; then
      echo "${arg#$name=}"
      return
    fi
  done
  echo ""
}

# Dummy-Funktionen für lokale Heavy-Check-Lock und Policy (da nicht implementiert)
acquire_local_heavy_check_lock_sync() {
  # In einer echten Implementierung würde hier eine Lock-Datei erzeugt werden
  :
}

apply_local_tsgo_policy() {
  # In einer echten Implementierung würden hier Umgebungsvariablen angepasst
  :
}

release_lock() {
  # In einer echten Implementierung würde hier das Lock wieder freigegeben
  :
}

# Hauptskript beginnt hier
main() {
  # Anwenden der lokalen TSGO-Policy (Dummy)
  apply_local_tsgo_policy

  # Pfad zu tsgo bestimmen
  local tsgo_path="node_modules/.bin/tsgo"

  # Argumente verarbeiten
  local final_args=()
  local ts_build_info_file=""
  local i=0
  while [[ $i -lt $# ]]; do
    local arg="${!i}"
    if [[ "$arg" == "--tsBuildInfoFile" ]]; then
      ts_build_info_file="${!((i+1))}"
      mkdir -p "$(dirname "$ts_build_info_file")"
      break
    elif [[ "$arg" == --tsBuildInfoFile=* ]]; then
      ts_build_info_file="${arg#--tsBuildInfoFile=}"
      mkdir -p "$(dirname "$ts_build_info_file")"
      break
    fi
    ((i++))
  done

  # Lokales Heavy-Check-Lock akquirieren (Dummy)
  acquire_local_heavy_check_lock_sync

  # tsgo ausführen
  if command -v "$tsgo_path" >/dev/null 2>&1; then
    "$tsgo_path" "$@" || exit_code=$?
  else
    echo "Fehler: tsgo nicht gefunden unter $tsgo_path" >&2
    exit 1
  fi

  # Lock freigeben (Dummy)
  release_lock

  # Exit-Code setzen
  if [[ ${exit_code:-0} -ne 0 ]]; then
    exit "${exit_code:-1}"
  fi
}

main "$@"
