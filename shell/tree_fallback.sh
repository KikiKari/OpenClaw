#!/usr/bin/env bash
# tree_fallback.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:db-maintainer/scripts/tree_fallback.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Fallback tree generator for when the `tree` binary is unavailable.
#
# Produces output similar to `tree -a -L <depth>` and writes it to
# important/openclaw-tree.txt with a timestamp header.

WORKSPACE="/workspace"
DEPTH=6
OUT="$WORKSPACE/important/openclaw-tree.txt"

# Skip directories
SKIP=(".git" "node_modules" "__pycache__" "venv" ".cache" ".npm" ".local")

# Check if item is in skip array
in_skip() {
    local item="$1"
    for s in "${SKIP[@]}"; do
        [[ "$item" == "$s" ]] && return 0
    done
    return 1
}

# Recursive function to walk directory tree
walk() {
    local path="$1"
    local prefix="${2:-}"
    local depth="${3:-0}"
    local lines=()

    (( depth >= DEPTH )) && return 0

    local entries=()
    local entry
    for entry in "$path"/.* "$path"/*; do
        # Skip current and parent directory
        [[ "${entry##*/}" == "." || "${entry##*/}" == ".." ]] && continue
        # Check if glob didn't match anything (bash behavior)
        [[ ! -e "$entry" && ! -L "$entry" ]] && continue
        entries+=("$entry")
    done

    # Sort entries: directories first, then alphabetically
    IFS=$'\n' entries=($(printf '%s\n' "${entries[@]}" | sort -t'/' -k1,1 -k2,2))

    local i=0
    local total=${#entries[@]}
    for entry in "${entries[@]}"; do
        local name="${entry##*/}"
        in_skip "$name" && continue

        local last=$((i+1==total ? 1 : 0))
        local connector="├── "
        [[ $last -eq 1 ]] && connector="└── "

        local suffix=""
        [[ -d "$entry" && ! -L "$entry" ]] && suffix="/"

        lines+=("${prefix}${connector}${name}${suffix}")

        if [[ -d "$entry" && ! -L "$entry" ]]; then
            local extension="│   "
            [[ $last -eq 1 ]] && extension="    "
            walk "$entry" "${prefix}${extension}" $((depth+1))
        fi
        ((i++))
    done

    printf '%s\n' "${lines[@]}"
}

main() {
    mkdir -p "$(dirname "$OUT")"

    local lines=("$WORKSPACE")
    mapfile -t lines < <(walk "$WORKSPACE")

    {
        echo "# OpenClaw Workspace Tree"
        echo "# Generiert: $(date --iso-8601=seconds)"
        echo "# Fallback (tree binary nicht verfuegbar), Tiefe $DEPTH"
        echo "# Diese Datei wird automatisch von db-maintainer aktualisiert"
        echo
        echo "$WORKSPACE"
        printf '%s\n' "${lines[@]}"
    } > "$OUT"

    echo "openclaw-tree.txt aktualisiert (Fallback): $OUT (${#lines[@]} Eintraege)"
}

main "$@"
