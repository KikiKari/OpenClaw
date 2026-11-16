#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "0e6bf931374555ce2895775867a9d80453e3ee8ca0a54506bfc00b12951c7114", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "shell"}
# callsite-guard.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Importiere benötigte Funktionen aus ts-guard-utils.sh
# (Annahme: Diese sind bereits in einem gemeinsamen Utils-File definiert)
source "$(dirname "${BASH_SOURCE[0]}")/ts-guard-utils.sh"

# Globale Variablen für Parameter
declare -a SOURCE_ROOTS=()
declare -a EXTRA_TEST_SUFFIXES=()
declare SKIP_RELATIVE_PATH=""
declare ALLOW_CALLSITE=""
declare HEADER=""
declare FOOTER=""
declare SORT_VIOLATIONS="true"
declare FIND_CALL_LINES_CMD=""

# Funktion zur Ausführung des Callsite-Guards
run_callsite_guard() {
    local repo_root
    repo_root=$(resolve_repo_root "$IMPORT_META_URL")

    # Sammle TypeScript-Dateien aus den angegebenen Wurzeln
    local files
    mapfile -t files < <(collect_typescript_files_from_roots "${SOURCE_ROOTS[@]}" --extra-test-suffixes "${EXTRA_TEST_SUFFIXES[@]}")

    local violations=()

    for file_path in "${files[@]}"; do
        local rel_path
        rel_path=$(realpath --relative-to="$repo_root" "$file_path" | tr '\\' '/')

        # Prüfe, ob der relative Pfad übersprungen werden soll
        if [[ -n "$SKIP_RELATIVE_PATH" ]] && eval "$SKIP_RELATIVE_PATH" '"$rel_path"'; then
            continue
        fi

        # Lese den Inhalt der Datei
        local content
        content=$(<"$file_path")

        # Finde Call-Lines mithilfe des übergebenen Befehls
        while IFS= read -r line_number; do
            local callsite="$rel_path:$line_number"

            # Prüfe, ob der Callsite erlaubt ist
            if [[ -n "$ALLOW_CALLSITE" ]] && eval "$ALLOW_CALLSITE" '"$callsite"'; then
                continue
            fi

            violations+=("$callsite")
        done < <(eval "$FIND_CALL_LINES_CMD" <<<"$content")
    done

    # Wenn keine Verstöße gefunden wurden, beende erfolgreich
    if [[ ${#violations[@]} -eq 0 ]]; then
        return 0
    fi

    # Gebe Header aus
    if [[ -n "$HEADER" ]]; then
        echo "$HEADER" >&2
    fi

    # Sortiere Verstöße, falls gewünscht
    if [[ "$SORT_VIOLATIONS" == "true" ]]; then
        IFS=$'\n' violations=($(sort <<<"${violations[*]}"))
    fi

    # Gebe Verstöße aus
    for violation in "${violations[@]}"; do
        echo "- $violation" >&2
    done

    # Gebe Footer aus, falls vorhanden
    if [[ -n "$FOOTER" ]]; then
        echo "$FOOTER" >&2
    fi

    exit 1
}

# Beispiel für die Nutzung der Funktion (muss angepasst werden)
# run_callsite_guard
