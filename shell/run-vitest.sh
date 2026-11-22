#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "4c9a27882a78ee41b477c387d21ce716041e2f579a0fabbc3865bb2a2cdfb669", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "shell"}
# run-vitest.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konstanten
readonly TRUTHY_ENV_VALUES=("1" "true" "yes" "on")
readonly SUPPRESSED_VITEST_STDERR_PATTERNS=("[PLUGIN_TIMINGS] Warning:")

# Funktionen
is_truthy_env_value() {
    local value="${1:-}"
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]' | xargs)
    
    for truthy_value in "${TRUTHY_ENV_VALUES[@]}"; do
        if [[ "$value" == "$truthy_value" ]]; then
            return 0
        fi
    done
    
    return 1
}

resolve_vitest_node_args() {
    if is_truthy_env_value "${OPENCLAW_VITEST_ENABLE_MAGLEV:-}"; then
        echo ""
    else
        echo "--no-maglev"
    fi
}

resolve_vitest_cli_entry() {
    # In Bash können wir das Node.js-require nicht direkt verwenden
    # Daher versuchen wir, vitest über den PATH zu finden
    if command -v vitest &>/dev/null; then
        echo "vitest"
    else
        echo "Error: vitest not found in PATH" >&2
        exit 1
    fi
}

should_suppress_vitest_stderr_line() {
    local line="$1"
    
    for pattern in "${SUPPRESSED_VITEST_STDERR_PATTERNS[@]}"; do
        if [[ "$line" == *"$pattern"* ]]; then
            return 0
        fi
    done
    
    return 1
}

forward_vitest_output() {
    local input_fd="$1"
    local output_fd="$2"
    local suppress_function="${3:-}"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$suppress_function" ]] && "$suppress_function" "$line"; then
            continue
        fi
        printf '%s\n' "$line" >&"$output_fd"
    done <&"$input_fd"
}

main() {
    if [[ $# -eq 0 ]]; then
        echo "usage: $0 <vitest args...>" >&2
        exit 1
    fi
    
    # Vitest-Kommando zusammenbauen
    local vitest_cmd
    vitest_cmd="$(resolve_vitest_cli_entry)"
    
    local node_args
    node_args=$(resolve_vitest_node_args)
    
    # Prozessgruppe für detached mode setzen (ähnlich wie in JS)
    local pgid=""
    if [[ "${OSTYPE}" == "darwin"* ]] || [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        # Auf Unix-Systemen können wir setpgid verwenden
        pgid="setpgid --"
    fi
    
    # Kindprozess starten
    # Hier verwenden wir exec direkt, da wir die Ausgabe weiterleiten wollen
    # Wir müssen sicherstellen, dass wir stdout/stderr separat handhaben
    
    # Temporäre Dateien für stdout und stderr erstellen
    local stdout_temp stderr_temp
    stdout_temp=$(mktemp)
    stderr_temp=$(mktemp)
    
    # Aufräumen bei Beendigung
    trap 'rm -f "$stdout_temp" "$stderr_temp"' EXIT
    
    # Vitest im Hintergrund ausführen
    local cmd=($pgid node $node_args "$vitest_cmd" "$@")
    if ! "${cmd[@]}" >"$stdout_temp" 2>"$stderr_temp" & pid=$!; then
        echo "Failed to start vitest process" >&2
        exit 1
    fi
    
    # Ausgaben im Hintergrund weiterleiten
    forward_vitest_output "$stdout_temp" 1 &
    forward_vitest_output "$stderr_temp" 2 should_suppress_vitest_stderr_line &
    
    # Warten auf den Prozess
    wait "$pid"
    local exit_code=$?
    
    # Alle Hintergrundjobs beenden
    wait
    
    exit "$exit_code"
}

# Wenn dieses Skript direkt ausgeführt wird
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
