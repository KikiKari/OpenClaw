#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "4ed3f27fdbcafabac8394476d0f4e860d250458a5e26d1a6efad6ade433fa047", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "shell"}
# runtime-postbuild.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bestimme das Stammverzeichnis relativ zum Skriptverzeichnis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$ROOT/dist"

# Muster für Runtime-Alias-Dateien
ROOT_RUNTIME_ALIAS_PATTERN='^(.+\.runtime|.+\.contract)-[A-Za-z0-9_-]+\.js$'

# Liste der statischen Erweiterungs-Assets
STATIC_EXTENSION_ASSETS=(
  "extensions/acpx/src/runtime-internals/mcp-proxy.mjs:dist/extensions/acpx/mcp-proxy.mjs"
  "extensions/diffs/assets/viewer-runtime.js:dist/extensions/diffs/assets/viewer-runtime.js"
)

# Funktion zur Ausgabe aller Zieldateipfade der statischen Assets
list_static_extension_asset_outputs() {
  local outputs=()
  IFS=$'\n' sorted_assets=($(printf '%s\n' "${STATIC_EXTENSION_ASSETS[@]}" | sort))
  for asset in "${sorted_assets[@]}"; do
    dest="${asset#*:}"
    outputs+=("${dest//\\//}")
  done
  printf '%s\n' "${outputs[@]}"
}

# Funktion zum Kopieren statischer Erweiterungs-Assets
copy_static_extension_assets() {
  for asset in "${STATIC_EXTENSION_ASSETS[@]}"; do
    src="${asset%%:*}"
    dest="${asset#*:}"
    src_path="$ROOT/$src"
    dest_path="$ROOT/$dest"
    if [[ -f "$src_path" ]]; then
      mkdir -p "$(dirname "$dest_path")"
      cp "$src_path" "$dest_path"
    else
      echo "[runtime-postbuild] static asset not found, skipping: $src" >&2
    fi
  done
}

# Funktion zum Schreiben stabiler Root-Runtime-Aliase
write_stable_root_runtime_aliases() {
  if [[ ! -d "$DIST_DIR" ]]; then
    return
  fi

  for file in "$DIST_DIR"/*; do
    filename=$(basename "$file")
    if [[ "$filename" =~ $ROOT_RUNTIME_ALIAS_PATTERN ]]; then
      base="${BASH_REMATCH[1]}"
      alias_file="$DIST_DIR/${base}.js"
      content="export * from \"./${filename}\";\n"
      if [[ ! -f "$alias_file" ]] || [[ "$(cat "$alias_file")" != "$content" ]]; then
        printf "%s" "$content" > "$alias_file"
      fi
    fi
  done
}

# Hauptfunktion zum Ausführen aller Post-Build-Schritte
run_runtime_post_build() {
  # Diese Funktionen werden durch separate Skripte implementiert,
  # daher rufen wir sie hier nur auf, falls sie existieren.
  if [[ -f "$ROOT/copy-plugin-sdk-root-alias.sh" ]]; then
    "$ROOT/copy-plugin-sdk-root-alias.sh"
  fi

  if [[ -f "$ROOT/copy-bundled-plugin-metadata.sh" ]]; then
    "$ROOT/copy-bundled-plugin-metadata.sh"
  fi

  if [[ -f "$ROOT/write-official-channel-catalog.sh" ]]; then
    "$ROOT/write-official-channel-catalog.sh"
  fi

  if [[ -f "$ROOT/stage-bundled-plugin-runtime-deps.sh" ]]; then
    "$ROOT/stage-bundled-plugin-runtime-deps.sh"
  fi

  if [[ -f "$ROOT/stage-bundled-plugin-runtime.sh" ]]; then
    "$ROOT/stage-bundled-plugin-runtime.sh"
  fi

  write_stable_root_runtime_aliases
  copy_static_extension_assets
}

# Wenn das Skript direkt ausgeführt wird, führe den Hauptprozess aus
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_runtime_post_build
fi
