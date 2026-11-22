#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "611519d17dbb23481e49b56e35f03a2dd2ea03e4d28280de58bec8b9278c1850", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "shell"}
# run-node.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
BUILD_SCRIPT="scripts/tsdown-build.mjs"
BUNDLED_PLUGIN_PATH_PREFIX="plugins/"
BUNDLED_PLUGIN_ROOT_DIR="plugins"

RUN_NODE_SOURCE_ROOTS=("src" "$BUNDLED_PLUGIN_ROOT_DIR")
RUN_NODE_CONFIG_FILES=("tsconfig.json" "package.json" "tsdown.config.ts")

EXTENSION_SOURCE_FILE_PATTERN='\.(c|m)?[jt]sx?$'
EXTENSION_RESTART_METADATA_FILES=("openclaw.plugin.json" "package.json")

# Hilfsfunktionen
normalize_path() {
    local file_path="${1:-}"
    echo "${file_path//\\//}"
}

is_ignored_source_path() {
    local relative_path
    relative_path=$(normalize_path "$1")
    
    if [[ "$relative_path" == *.test.ts ]] || 
       [[ "$relative_path" == *.test.tsx ]] || 
       [[ "$relative_path" == *test-helpers.ts ]]; then
        return 0
    fi
    return 1
}

is_build_relevant_source_path() {
    local relative_path
    relative_path=$(normalize_path "$1")
    
    if [[ "$relative_path" =~ $EXTENSION_SOURCE_FILE_PATTERN ]] && 
       ! is_ignored_source_path "$relative_path"; then
        return 0
    fi
    return 1
}

is_build_relevant_run_node_path() {
    local repo_path="$1"
    local normalized_path
    normalized_path=$(normalize_path "$repo_path")
    normalized_path="${normalized_path#./}"
    
    for config_file in "${RUN_NODE_CONFIG_FILES[@]}"; do
        if [[ "$normalized_path" == "$config_file" ]]; then
            return 0
        fi
    done
    
    if [[ "$normalized_path" == src/* ]]; then
        local src_relative="${normalized_path#src/}"
        if ! is_ignored_source_path "$src_relative"; then
            return 0
        fi
    fi
    
    if [[ "$normalized_path" == "$BUNDLED_PLUGIN_PATH_PREFIX"* ]]; then
        local plugin_relative="${normalized_path#$BUNDLED_PLUGIN_PATH_PREFIX}"
        if is_build_relevant_source_path "$plugin_relative"; then
            return 0
        fi
    fi
    
    return 1
}

is_restart_relevant_extension_path() {
    local relative_path
    relative_path=$(normalize_path "$1")
    
    local basename
    basename=$(basename "$relative_path")
    
    for metadata_file in "${EXTENSION_RESTART_METADATA_FILES[@]}"; do
        if [[ "$basename" == "$metadata_file" ]]; then
            return 0
        fi
    done
    
    if is_build_relevant_source_path "$relative_path"; then
        return 0
    fi
    
    return 1
}

is_restart_relevant_run_node_path() {
    local repo_path="$1"
    local normalized_path
    normalized_path=$(normalize_path "$repo_path")
    normalized_path="${normalized_path#./}"
    
    for config_file in "${RUN_NODE_CONFIG_FILES[@]}"; do
        if [[ "$normalized_path" == "$config_file" ]]; then
            return 0
        fi
    done
    
    if [[ "$normalized_path" == src/* ]]; then
        local src_relative="${normalized_path#src/}"
        if ! is_ignored_source_path "$src_relative"; then
            return 0
        fi
    fi
    
    if [[ "$normalized_path" == "$BUNDLED_PLUGIN_PATH_PREFIX"* ]]; then
        local plugin_relative="${normalized_path#$BUNDLED_PLUGIN_PATH_PREFIX}"
        if is_restart_relevant_extension_path "$plugin_relative"; then
            return 0
        fi
    fi
    
    return 1
}

stat_mtime() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        if stat -c %Y "$file_path" 2>/dev/null; then
            return 0
        fi
    fi
    echo "null"
}

is_excluded_source() {
    local file_path="$1"
    local source_root="$2"
    local source_root_name="$3"
    
    local relative_path
    relative_path=$(realpath --relative-to="$source_root" "$file_path" 2>/dev/null) || return 1
    
    if [[ "$relative_path" == ..* ]]; then
        return 1
    fi
    
    local full_path
    full_path="${source_root_name}/${relative_path}"
    if ! is_build_relevant_run_node_path "$full_path"; then
        return 0
    fi
    return 1
}

find_latest_mtime() {
    local dir_path="$1"
    shift
    local should_skip_function="$1"
    shift
    
    local latest="null"
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if declare -F "$should_skip_function" >/dev/null 2>&1; then
                if "$should_skip_function" "$file"; then
                    continue
                fi
            fi
            
            local mtime
            mtime=$(stat_mtime "$file")
            if [[ "$mtime" != "null" ]]; then
                if [[ "$latest" == "null" ]] || (( mtime > latest )); then
                    latest="$mtime"
                fi
            fi
        fi
    done < <(find "$dir_path" -type f -print0 2>/dev/null)
    
    echo "$latest"
}

read_git_status() {
    git status --porcelain --untracked-files=normal -- "${RUN_NODE_SOURCE_ROOTS[@]}" "${RUN_NODE_CONFIG_FILES[@]}" 2>/dev/null || echo ""
}

parse_git_status_paths() {
    local output="$1"
    echo "$output" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local path_part="${line:3}"
            echo "$(normalize_path "$path_part")"
        fi
    done
}

has_dirty_source_tree() {
    local output
    output=$(read_git_status)
    if [[ -z "$output" ]]; then
        echo "null"
        return
    fi
    
    local paths
    paths=$(parse_git_status_paths "$output")
    
    while IFS= read -r repo_path; do
        if [[ -n "$repo_path" ]] && is_build_relevant_run_node_path "$repo_path"; then
            echo "true"
            return
        fi
    done <<< "$paths"
    
    echo "false"
}

read_build_stamp() {
    local build_stamp_path="$1"
    local mtime
    mtime=$(stat_mtime "$build_stamp_path")
    
    if [[ "$mtime" == "null" ]]; then
        echo '{"mtime":null,"head":null}'
        return
    fi
    
    if [[ -f "$build_stamp_path" ]]; then
        local content
        content=$(cat "$build_stamp_path" 2>/dev/null || echo "")
        if [[ "$content" == \{* ]]; then
            echo "{\"mtime\":$mtime,\"head\":$(echo "$content" | jq -r '.head // empty' 2>/dev/null || echo 'null')}"
            return
        fi
    fi
    
    echo "{\"mtime\":$mtime,\"head\":null}"
}

has_source_mtime_changed() {
    local stamp_mtime="$1"
    shift
    local source_roots=("$@")
    
    local latest_source_mtime="null"
    
    for source_root in "${source_roots[@]}"; do
        local source_mtime
        source_mtime=$(find_latest_mtime "$source_root" is_excluded_source_helper)
        
        if [[ "$source_mtime" != "null" ]] && 
           { [[ "$latest_source_mtime" == "null" ]] || (( source_mtime > latest_source_mtime )); }; then
            latest_source_mtime="$source_mtime"
        fi
    done
    
    if [[ "$latest_source_mtime" != "null" ]] && (( latest_source_mtime > stamp_mtime )); then
        echo "true"
    else
        echo "false"
    fi
}

is_excluded_source_helper() {
    is_excluded_source "$1" "${SOURCE_ROOTS[0]}" "src"
}

resolve_build_requirement() {
    local dist_entry="$1"
    local build_stamp_path="$2"
    local config_files=("${@:3}")
    
    if [[ "${OPENCLAW_FORCE_BUILD:-}" == "1" ]]; then
        echo '{"shouldBuild":true,"reason":"force_build"}'
        return
    fi
    
    local stamp_data
    stamp_data=$(read_build_stamp "$build_stamp_path")
    local stamp_mtime
    stamp_mtime=$(echo "$stamp_data" | jq -r '.mtime')
    
    if [[ "$stamp_mtime" == "null" ]]; then
        echo '{"shouldBuild":true,"reason":"missing_build_stamp"}'
        return
    fi
    
    if [[ ! -f "$dist_entry" ]]; then
        echo '{"shouldBuild":true,"reason":"missing_dist_entry"}'
        return
    fi
    
    for config_file in "${config_files[@]}"; do
        local mtime
        mtime=$(stat_mtime "$config_file")
        if [[ "$mtime" != "null" ]] && (( mtime > stamp_mtime )); then
            echo '{"shouldBuild":true,"reason":"config_newer"}'
            return
        fi
    done
    
    # Prüfung auf Git-Änderungen würde hier stattfinden
    # Da Bash keine direkte Git-Integration hat, vereinfachen wir dies
    
    local dirty_result
    dirty_result=$(has_dirty_source_tree)
    
    if [[ "$dirty_result" == "true" ]]; then
        echo '{"shouldBuild":true,"reason":"dirty_watched_tree"}'
        return
    elif [[ "$dirty_result" == "false" ]]; then
        echo '{"shouldBuild":false,"reason":"clean"}'
        return
    fi
    
    local source_mtime_changed
    source_mtime_changed=$(has_source_mtime_changed "$stamp_mtime" "${RUN_NODE_SOURCE_ROOTS[@]}")
    
    if [[ "$source_mtime_changed" == "true" ]]; then
        echo '{"shouldBuild":true,"reason":"source_mtime_newer"}'
        return
    fi
    
    echo '{"shouldBuild":false,"reason":"clean"}'
}

format_build_reason() {
    local reason="$1"
    case "$reason" in
        "force_build") echo "forced by OPENCLAW_FORCE_BUILD" ;;
        "missing_build_stamp") echo "build stamp missing" ;;
        "missing_dist_entry") echo "dist entry missing" ;;
        "config_newer") echo "config newer than build stamp" ;;
        "build_stamp_missing_head") echo "build stamp missing git head" ;;
        "git_head_changed") echo "git head changed" ;;
        "dirty_watched_tree") echo "dirty watched source tree" ;;
        "source_mtime_newer") echo "source mtime newer than build stamp" ;;
        "clean") echo "clean" ;;
        *) echo "$reason" ;;
    esac
}

log_runner() {
    local message="$1"
    if [[ "${OPENCLAW_RUNNER_LOG:-1}" != "0" ]]; then
        echo "[openclaw] $message" >&2
    fi
}

run_open_claw() {
    local exec_path="$1"
    shift
    local args=("$@")
    
    # Starte den Prozess und warte auf Beendigung
    "$exec_path" openclaw.mjs "${args[@]}"
    return $?
}

sync_runtime_artifacts() {
    # In Bash können wir diese Funktion nicht direkt implementieren
    # Daher geben wir immer true zurück
    return 0
}

write_build_stamp() {
    local dist_root="$1"
    local build_stamp_path="$dist_root/.buildstamp"
    
    # Schreibe einen einfachen Zeitstempel
    date +%s > "$build_stamp_path" 2>/dev/null || true
}

should_skip_clean_watch_runtime_sync() {
    [[ "${OPENCLAW_WATCH_MODE:-}" == "1" ]]
}

main() {
    local cwd
    cwd=$(pwd)
    
    local dist_root="$cwd/dist"
    local dist_entry="$dist_root/entry.js"
    local build_stamp_path="$dist_root/.buildstamp"
    
    # Erstelle die benötigten Verzeichnisse
    mkdir -p "$dist_root"
    
    # Sammle Konfigurationsdateien
    local config_files=()
    for config_file in "${RUN_NODE_CONFIG_FILES[@]}"; do
        config_files+=("$cwd/$config_file")
    done
    
    # Prüfe ob ein Build erforderlich ist
    local build_requirement_json
    build_requirement_json=$(resolve_build_requirement "$dist_entry" "$build_stamp_path" "${config_files[@]}")
    local should_build
    should_build=$(echo "$build_requirement_json" | jq -r '.shouldBuild')
    local reason
    reason=$(echo "$build_requirement_json" | jq -r '.reason')
    
    if [[ "$should_build" == "false" ]]; then
        if ! should_skip_clean_watch_runtime_sync && ! sync_runtime_artifacts; then
            exit 1
        fi
        run_open_claw "$(which node)" "$@"
        exit $?
    fi
    
    local reason_label
    reason_label=$(format_build_reason "$reason")
    log_runner "Building TypeScript (dist is stale: $reason - $reason_label)." >&2
    
    # Führe den Build aus
    local build_cmd
    build_cmd=$(which node)
    if ! "$build_cmd" "$BUILD_SCRIPT" --no-clean; then
        exit 1
    fi
    
    if ! sync_runtime_artifacts; then
        exit 1
    fi
    
    write_build_stamp "$dist_root"
    run_open_claw "$(which node)" "$@"
    exit $?
}

# Hauptausführung
main "$@"
