#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "b8a335e4775e15acd45dc9fec5571d9a64929e5f44052068defbef42b3c7b504", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "shell"}
# github_publisher.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Publish queued, provenance-checked artifacts without staging unrelated files.

queue_artifact() {
    local state_file="$1"
    local root="$2"
    local path="$3"

    root=$(realpath "$root")
    if [[ -L "$path" ]]; then
        echo "artifact must not be a symlink" >&2
        return 1
    fi
    local resolved_path
    resolved_path=$(realpath "$path")
    local relative
    relative=$(realpath --relative-to="$root" "$resolved_path")
    if [[ -z "$relative" ]] || [[ "$relative" == "." ]] || [[ "$relative" == ".."* ]]; then
        echo "artifact is outside a language directory" >&2
        return 1
    fi
    local first_dir
    first_dir=$(echo "$relative" | cut -d'/' -f1)
    case "$first_dir" in
        perl5|powershell|perl6|tcl|javascript|ruby|python|lua|shell|go)
            ;;
        *)
            echo "artifact is outside a language directory" >&2
            return 1
            ;;
    esac
    local sha
    sha=$(sha256sum "$path" | awk '{print $1}')
    jq --arg rel "$relative" --arg hash "$sha" \
       '.ausstehende_veroeffentlichungen[$rel] = $hash' \
       "$state_file" > tmp.$$
    mv tmp.$$ "$state_file"
}

publish_pending() {
    local root="$1"
    local state_file="$2"
    local save_cmd="$3"
    local token="$4"

    if [[ -z "${token:-}" ]] || [[ -z "${token// }" ]]; then
        return 1
    fi

    root=$(realpath "$root")
    local headers=(
        "-H" "Authorization: Bearer ${token// }"
        "-H" "Accept: application/vnd.github+json"
        "-H" "X-GitHub-Api-Version: 2022-11-28"
        "-H" "User-Agent: abstractions-manager"
    )

    local success=0
    local pending
    pending=$(jq -r 'if .ausstehende_veroeffentlichungen | type == "object" then .ausstehende_veroeffentlichungen else {} end | to_entries[] | "\(.key):\(.value)"' "$state_file" 2>/dev/null || echo "")

    if [[ -z "$pending" ]]; then
        return 0
    fi

    while IFS=: read -r name expected; do
        if [[ -z "$name" ]] || [[ -z "$expected" ]]; then
            continue
        fi
        local path="$root/$name"
        if [[ ! -e "$path" ]] || [[ -L "$path" ]]; then
            echo "invalid queued path" >&2
            success=1
            continue
        fi
        local resolved_rel
        resolved_rel=$(realpath --relative-to="$root" "$path" 2>/dev/null || echo "")
        if [[ "$resolved_rel" != "$name" ]]; then
            echo "invalid queued path" >&2
            success=1
            continue
        fi
        local actual_hash
        actual_hash=$(sha256sum "$path" | awk '{print $1}')
        if [[ "$actual_hash" != "$expected" ]]; then
            echo "queued artifact changed" >&2
            success=1
            continue
        fi

        local encoded_data
        encoded_data=$(base64 -i "$path")

        lookup() {
            local remote_name="$1"
            local url="https://api.github.com/repos/KikiKari/OpenClaw/contents/$remote_name?ref=gateway1-abstractions"
            curl -s -f "${headers[@]}" "$url" 2>/dev/null || echo "null"
        }

        same() {
            local content="$1"
            if [[ "$content" == "null" ]]; then
                return 1
            fi
            local encoding
            encoding=$(echo "$content" | jq -r '.encoding // empty')
            if [[ "$encoding" != "base64" ]]; then
                return 1
            fi
            local remote_content
            remote_content=$(echo "$content" | jq -r '.content // empty')
            local decoded
            decoded=$(echo "$remote_content" | base64 -d 2>/dev/null || echo "")
            local original
            original=$(cat "$path")
            [[ "$decoded" == "$original" ]]
        }

        local existing
        existing=$(lookup "$name")
        if [[ "$existing" != "null" ]] && ! same "$existing"; then
            local candidate="$name"
            local dir
            dir=$(dirname "$candidate")
            local base
            base=$(basename "$candidate")
            local stem="${base%.*}"
            local ext="${base##*.}"
            if [[ "$stem" == "$ext" ]]; then
                ext=""
            fi
            local suffix="${expected:0:12}"
            local alternate="$dir/${stem}_${suffix}${ext:+.$ext}"
            existing=$(lookup "$alternate")
            if [[ "$existing" != "null" ]] && ! same "$existing"; then
                echo "remote artifact conflict" >&2
                success=1
                continue
            fi
            name="$alternate"
        fi

        if [[ "$existing" == "null" ]]; then
            local message='{"message":"Publish script abstraction","branch":"gateway1-abstractions","content":"'"$encoded_data"'"}'
            local url="https://api.github.com/repos/KikiKari/OpenClaw/contents/$name"
            if ! curl -s -f -X PUT "${headers[@]}" -d "$message" "$url" >/dev/null; then
                success=1
                continue
            fi
        fi

        jq --arg rel "$name" 'del(.ausstehende_veroeffentlichungen[$rel])' "$state_file" > tmp.$$
        mv tmp.$$ "$state_file"
        eval "$save_cmd"
    done <<< "$pending"

    return $success
}
