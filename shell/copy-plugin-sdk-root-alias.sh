#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "f0ff970f22b2d6a339ad142eef1c2128ef41cabe159498873c436760de1b1734", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "shell"}
# copy-plugin-sdk-root-alias.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Importiere Funktionen aus runtime-postbuild-shared.sh
source "$(dirname "${BASH_SOURCE[0]}")/runtime-postbuild-shared.sh"

copyPluginSdkRootAlias() {
  local cwd="${1:-$(pwd)}"
  local source="$cwd/src/plugin-sdk/root-alias.cjs"
  local target="$cwd/dist/plugin-sdk/root-alias.cjs"

  # Prüfe ob die Quelldatei existiert
  if [[ ! -f "$source" ]]; then
    echo "Fehler: Quelldatei $source nicht gefunden" >&2
    return 1
  fi

  # Stelle sicher, dass das Zielverzeichnis existiert
  mkdir -p "$(dirname "$target")"

  # Lese den Inhalt der Quelldatei
  local content
  content=$(cat "$source")

  # Schreibe die Datei nur wenn sich der Inhalt geändert hat
  writeTextFileIfChanged "$target" "$content"
}

# Wenn das Skript direkt aufgerufen wird, führe die Funktion aus
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  copyPluginSdkRootAlias "$@"
fi
