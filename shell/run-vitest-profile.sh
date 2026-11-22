#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "19722b2d797d58bde0823f0b390bab56d7bc4a2b5341ef28966776b57810b249", "source_sha256": "047c165dbfdfa71d13cb6cf0b23d2b60439a2e0ec23e6951411b25fd91c6dcab", "target_language": "shell"}
# run-vitest-profile.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest-profile.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
mode=""
output_dir="${OPENCLAW_VITEST_PROFILE_DIR:-}"

# Funktion zur Argumentenverarbeitung
parse_args() {
  local i=0
  while [[ $i -lt $# ]]; do
    local arg="${!i}"
    case "$arg" in
      --output-dir)
        i=$((i + 1))
        output_dir="${!i:-}"
        ;;
      *)
        if [[ -z "$mode" ]]; then
          mode="$arg"
        else
          echo "Unknown argument: $arg" >&2
          exit 1
        fi
        ;;
    esac
    i=$((i + 1))
  done

  if [[ "$mode" != "main" && "$mode" != "runner" ]]; then
    echo "Usage: $0 <main|runner> [--output-dir <dir>]" >&2
    exit 1
  fi
}

# Funktion zur Bestimmung des Profilverzeichnisses
resolve_vitest_profile_dir() {
  if [[ -n "${output_dir}" && -n "${output_dir// /}" ]]; then
    realpath -m "$output_dir"
  else
    mktemp -d "$(mktemp -u)/openclaw-vitest-${mode}-profile-XXXXXX"
  fi
}

# Funktion zum Aufbau des Vitest-Profil-Befehls
build_vitest_profile_command() {
  if [[ "$mode" == "main" ]]; then
    echo "node"
    echo "--cpu-prof"
    echo "--cpu-prof-dir=$output_dir"
    echo "./node_modules/vitest/vitest.mjs"
    echo "run"
    echo "--config"
    echo "test/vitest/vitest.unit.config.ts"
    echo "--no-file-parallelism"
  else
    echo "pnpm"
    echo "vitest"
    echo "run"
    echo "--config"
    echo "test/vitest/vitest.unit.config.ts"
    echo "--no-file-parallelism"
    echo "--execArgv=--cpu-prof"
    echo "--execArgv=--cpu-prof-dir=$output_dir"
    echo "--execArgv=--heap-prof"
    echo "--execArgv=--heap-prof-dir=$output_dir"
  fi
}

# Hauptfunktion
main() {
  parse_args "$@"
  output_dir=$(resolve_vitest_profile_dir)
  mkdir -p "$output_dir"

  echo "[run-vitest-profile] writing ${mode} profiles to ${output_dir}"

  # Befehl in Array speichern
  local cmd=()
  while IFS= read -r line; do
    cmd+=("$line")
  done < <(build_vitest_profile_command)

  # Befehl ausführen
  if [[ "${cmd[0]}" == "pnpm" ]]; then
    "${cmd[@]}"
  else
    "${cmd[@]}"
  fi

  local exit_code=$?
  exit $exit_code
}

# Skript ausführen
main "$@"
