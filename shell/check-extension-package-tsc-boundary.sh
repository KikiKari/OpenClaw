#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "f6b1fdf7793113983befbf26b2e7b1a0674f6887a4d4562d55e303148fc85fdc", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "shell"}
# check-extension-package-tsc-boundary.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TSC_BIN="$REPO_ROOT/node_modules/typescript/bin/tsc"
readonly PREPARE_BOUNDARY_ARTIFACTS_BIN="$REPO_ROOT/scripts/prepare-extension-package-boundary-artifacts.mjs"
readonly EXTENSION_PACKAGE_BOUNDARY_BASE_CONFIG="../tsconfig.package-boundary.base.json"
readonly FAILURE_OUTPUT_TAIL_LINES=40
readonly SLOW_COMPILE_SUMMARY_LIMIT=10
readonly COMPILE_INPUT_EXTENSIONS_REGEX='\.(ts|tsx|mts|cts|js|mjs|json)$'
readonly ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH="../../src/plugins/contracts/rootdir-boundary-canary.ts"
readonly ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT="src/plugins/contracts/rootdir-boundary-canary.ts"

# Globale Variablen
declare -a COMPILE_TIMINGS=()
declare -i SKIPPED_COMPILE_COUNT=0
declare -i TOTAL_COMPILE_COUNT=0

# Funktionen

parse_mode() {
    local mode="all"
    for arg in "$@"; do
        if [[ $arg == --mode=* ]]; then
            mode="${arg#--mode=}"
            break
        fi
    done
    
    if [[ ! "$mode" =~ ^(all|compile|canary)$ ]]; then
        echo "Unknown mode: $mode" >&2
        exit 1
    fi
    
    echo "$mode"
}

resolve_compile_concurrency() {
    local raw="${OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY:-}"
    local parsed
    
    if [[ -n "$raw" ]] && [[ "$raw" =~ ^[0-9]+$ ]] && [[ $raw -gt 0 ]]; then
        echo "$raw"
        return
    fi
    
    # Ermittle verfügbare Parallelität (vereinfacht)
    local cpu_count
    cpu_count=$(nproc 2>/dev/null || echo 4)
    local half_cpu=$((cpu_count / 2))
    
    if [[ $half_cpu -lt 1 ]]; then
        echo 1
    elif [[ $half_cpu -gt 6 ]]; then
        echo 6
    else
        echo $half_cpu
    fi
}

read_json_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        echo "{}"
        return
    fi
    cat "$file_path"
}

summarize_output_section() {
    local name="$1"
    local output="$2"
    
    local trimmed
    trimmed=$(echo "$output" | sed '/^[[:space:]]*$/d')
    
    if [[ -z "$trimmed" ]]; then
        return
    fi
    
    local line_count
    line_count=$(echo "$trimmed" | wc -l)
    
    if [[ $line_count -le $FAILURE_OUTPUT_TAIL_LINES ]]; then
        echo "$name:"
        echo "$trimmed"
        return
    fi
    
    local omitted_line_count=$((line_count - FAILURE_OUTPUT_TAIL_LINES))
    echo "$name:"
    echo "[... $omitted_line_count earlier lines omitted ...]"
    echo "$trimmed" | tail -n "$FAILURE_OUTPUT_TAIL_LINES"
}

format_failure_footer() {
    local kind="${1:-}"
    local elapsed_ms="${2:-}"
    local note="${3:-}"
    
    local footer_lines=()
    
    if [[ -n "$kind" ]]; then
        footer_lines+=("kind: $kind")
    fi
    
    if [[ -n "$elapsed_ms" ]] && [[ "$elapsed_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        footer_lines+=("elapsed: ${elapsed_ms}ms")
    fi
    
    if [[ -n "$note" ]]; then
        footer_lines+=("$note")
    fi
    
    IFS=$'\n'
    echo "${footer_lines[*]}"
    unset IFS
}

format_boundary_check_success_summary() {
    local mode="${1:-}"
    local compile_count="${2:-}"
    local skipped_compile_count="${3:-}"
    local canary_count="${4:-}"
    local prep_elapsed_ms="${5:-}"
    local compile_elapsed_ms="${6:-}"
    local canary_elapsed_ms="${7:-}"
    local elapsed_ms="${8:-}"
    
    local lines=("extension package boundary check passed")
    
    if [[ -n "$mode" ]]; then
        lines+=("mode: $mode")
    fi
    
    if [[ -n "$compile_count" ]] && [[ "$compile_count" =~ ^[0-9]+$ ]]; then
        lines+=("compiled plugins: $compile_count")
    fi
    
    if [[ -n "$skipped_compile_count" ]] && [[ "$skipped_compile_count" =~ ^[0-9]+$ ]] && [[ $skipped_compile_count -gt 0 ]]; then
        lines+=("skipped plugins: $skipped_compile_count")
    fi
    
    if [[ -n "$canary_count" ]] && [[ "$canary_count" =~ ^[0-9]+$ ]]; then
        lines+=("canary plugins: $canary_count")
    fi
    
    if [[ -n "$prep_elapsed_ms" ]] && [[ "$prep_elapsed_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ $(echo "$prep_elapsed_ms > 0" | bc -l) -eq 1 ]]; then
        lines+=("prep elapsed: ${prep_elapsed_ms}ms")
    fi
    
    if [[ -n "$compile_elapsed_ms" ]] && [[ "$compile_elapsed_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ $(echo "$compile_elapsed_ms > 0" | bc -l) -eq 1 ]]; then
        lines+=("compile elapsed: ${compile_elapsed_ms}ms")
    fi
    
    if [[ -n "$canary_elapsed_ms" ]] && [[ "$canary_elapsed_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ $(echo "$canary_elapsed_ms > 0" | bc -l) -eq 1 ]]; then
        lines+=("canary elapsed: ${canary_elapsed_ms}ms")
    fi
    
    if [[ -n "$elapsed_ms" ]] && [[ "$elapsed_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        lines+=("elapsed: ${elapsed_ms}ms")
    fi
    
    IFS=$'\n'
    echo "${lines[*]}"
    unset IFS
}

format_skipped_compile_progress() {
    local skipped_count="${1:-0}"
    local total_count="${2:-0}"
    
    if [[ ! "$skipped_count" =~ ^[0-9]+$ ]] || [[ $skipped_count -le 0 ]]; then
        return
    fi
    
    local stale_count=$((total_count - skipped_count))
    if [[ $stale_count -gt 0 ]]; then
        echo "skipped $skipped_count fresh plugin compiles before running $stale_count stale plugin checks"
    else
        echo "skipped $skipped_count fresh plugin compiles"
    fi
}

format_slow_compile_summary() {
    local limit="${1:-$SLOW_COMPILE_SUMMARY_LIMIT}"
    
    if [[ ${#COMPILE_TIMINGS[@]} -eq 0 ]]; then
        return
    fi
    
    # Sortiere Compile-Timings (vereinfachte Version)
    local sorted_timings=()
    local i
    for ((i=0; i<${#COMPILE_TIMINGS[@]}; i+=2)); do
        sorted_timings+=("${COMPILE_TIMINGS[i+1]}:${COMPILE_TIMINGS[i]}")
    done
    
    IFS=$'\n' sorted_timings=($(sort -rn <<<"${sorted_timings[*]}"))
    unset IFS
    
    echo "slowest plugin compiles:"
    local count=0
    for entry in "${sorted_timings[@]}"; do
        if [[ $count -ge $limit ]]; then
            break
        fi
        local time="${entry%%:*}"
        local id="${entry#*:}"
        echo "- $id: ${time}ms"
        ((count++))
    done
}

format_step_failure() {
    local label="$1"
    local stdout_content="${2:-}"
    local stderr_content="${3:-}"
    local kind="${4:-}"
    local elapsed_ms="${5:-}"
    local note="${6:-}"
    
    local sections=()
    
    sections+=("$label")
    
    local stdout_section
    stdout_section=$(summarize_output_section "stdout" "$stdout_content")
    if [[ -n "$stdout_section" ]]; then
        sections+=("$stdout_section")
    fi
    
    local stderr_section
    stderr_section=$(summarize_output_section "stderr" "$stderr_content")
    if [[ -n "$stderr_section" ]]; then
        sections+=("$stderr_section")
    fi
    
    local footer
    footer=$(format_failure_footer "$kind" "$elapsed_ms" "$note")
    if [[ -n "$footer" ]]; then
        sections+=("$footer")
    fi
    
    IFS=$'\n\n'
    echo "${sections[*]}"
    unset IFS
}

collect_bundled_extension_ids() {
    local extensions_dir="$REPO_ROOT/extensions"
    if [[ ! -d "$extensions_dir" ]]; then
        return
    fi
    
    local ids=()
    local entry
    for entry in "$extensions_dir"/*; do
        if [[ -d "$entry" ]]; then
            ids+=("$(basename "$entry")")
        fi
    done
    
    IFS=$'\n' sorted_ids=($(sort <<<"${ids[*]}"))
    unset IFS
    echo "${sorted_ids[@]}"
}

resolve_extension_tsconfig_path() {
    local extension_id="$1"
    echo "$REPO_ROOT/extensions/$extension_id/tsconfig.json"
}

read_extension_tsconfig() {
    local extension_id="$1"
    local tsconfig_path
    tsconfig_path=$(resolve_extension_tsconfig_path "$extension_id")
    read_json_file "$tsconfig_path"
}

collect_opt_in_extension_ids() {
    local bundled_ids
    bundled_ids=($(collect_bundled_extension_ids))
    
    local opt_in_ids=()
    local extension_id
    for extension_id in "${bundled_ids[@]}"; do
        local tsconfig_path
        tsconfig_path=$(resolve_extension_tsconfig_path "$extension_id")
        
        if [[ ! -f "$tsconfig_path" ]]; then
            continue
        fi
        
        local extends_value
        extends_value=$(jq -r '.extends // empty' "$tsconfig_path" 2>/dev/null)
        
        if [[ "$extends_value" == "$EXTENSION_PACKAGE_BOUNDARY_BASE_CONFIG" ]]; then
            opt_in_ids+=("$extension_id")
        fi
    done
    
    echo "${opt_in_ids[@]}"
}

collect_canary_extension_ids() {
    local extension_ids=("$@")
    
    # Vereinfachte Implementierung: gib alle IDs zurück
    echo "${extension_ids[@]}"
}

is_relevant_compile_input() {
    local file_path="$1"
    local basename
    basename=$(basename "$file_path")
    
    if [[ "$basename" == "__rootdir_boundary_canary__.ts" ]] || [[ "$basename" == "tsconfig.rootdir-canary.json" ]]; then
        return 1
    fi
    
    if [[ "$basename" == *.tsbuildinfo ]]; then
        return 1
    fi
    
    local ext
    ext="${file_path##*.}"
    if [[ ".$ext" =~ $COMPILE_INPUT_EXTENSIONS_REGEX ]]; then
        return 0
    fi
    
    return 1
}

collect_newest_mtime() {
    local entry_path="$1"
    local skip_dist_directories="${2:-true}"
    
    if [[ ! -e "$entry_path" ]]; then
        echo 0
        return
    fi
    
    local newest_mtime=0
    
    find "$entry_path" -type f \( \
        \( -name "node_modules" -prune \) -o \
        \( "$skip_dist_directories" = true -a -name "dist" -prune \) -o \
        \( -exec bash -c 'is_relevant_compile_input "{}"' \; -print \) \
    \) 2>/dev/null | while read -r file; do
        if [[ -f "$file" ]]; then
            local mtime
            mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            if [[ $mtime -gt $newest_mtime ]]; then
                newest_mtime=$mtime
            fi
        fi
    done
    
    echo $newest_mtime
}

collect_oldest_mtime() {
    local paths=("$@")
    local oldest_mtime=""
    
    local path
    for path in "${paths[@]}"; do
        if [[ ! -f "$path" ]]; then
            echo "null"
            return
        fi
        
        local mtime
        mtime=$(stat -c %Y "$path" 2>/dev/null || echo "")
        
        if [[ -z "$oldest_mtime" ]] || [[ $mtime -lt $oldest_mtime ]]; then
            oldest_mtime=$mtime
        fi
    done
    
    if [[ -n "$oldest_mtime" ]]; then
        echo "$oldest_mtime"
    else
        echo "null"
    fi
}

is_boundary_compile_fresh() {
    local extension_id="$1"
    local root_dir="${2:-$REPO_ROOT}"
    
    local extension_root="$root_dir/extensions/$extension_id"
    
    # Diese Werte müssen übergeben werden oder berechnet werden
    local extension_newest_input_mtime_ms="${3:-$(collect_newest_mtime "$extension_root")}"
    local shared_newest_input_mtime_ms="${4:-$(collect_newest_mtime "$root_dir/dist/plugin-sdk" false)}"
    
    local newest_input_mtime_ms
    if [[ $extension_newest_input_mtime_ms -gt $shared_newest_input_mtime_ms ]]; then
        newest_input_mtime_ms=$extension_newest_input_mtime_ms
    else
        newest_input_mtime_ms=$shared_newest_input_mtime_ms
    fi
    
    local stamp_path
    stamp_path=$(resolve_boundary_ts_stamp_path "$extension_id" "$root_dir")
    
    local oldest_output_mtime_ms
    oldest_output_mtime_ms=$(collect_oldest_mtime "$stamp_path")
    
    if [[ "$oldest_output_mtime_ms" == "null" ]]; then
        echo "false"
        return
    fi
    
    if [[ $oldest_output_mtime_ms -ge $newest_input_mtime_ms ]]; then
        echo "true"
    else
        echo "false"
    fi
}

write_stamp_file() {
    local file_path="$1"
    local dir
    dir=$(dirname "$file_path")
    
    mkdir -p "$dir"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$file_path"
}

run_node_step() {
    local label="$1"
    shift
    local args=("$@")
    
    local timeout_ms=120000
    if [[ "$label" == "plugin-sdk boundary prep" ]]; then
        timeout_ms=420000
    fi
    
    local started_at
    started_at=$(date +%s%3N)
    
    local output_file
    output_file=$(mktemp)
    
    local result
    result=0
    
    timeout $((timeout_ms / 1000)) node "${args[@]}" >"$output_file" 2>&1 || result=$?
    
    local elapsed_ms
    elapsed_ms=$(( $(date +%s%3N) - started_at ))
    
    if [[ $result -eq 0 ]]; then
        cat "$output_file"
        rm -f "$output_file"
        return 0
    fi
    
    local stdout_content stderr_content
    stdout_content=$(cat "$output_file")
    stderr_content=""
    
    local kind="nonzero-exit"
    local note=""
    
    if [[ $result -eq 124 ]]; then  # timeout
        kind="timeout"
        note="$label timed out after $timeout_ms ms"
    elif [[ $result -ne 0 ]]; then
        kind="spawn-error"
        note="Process failed with code $result"
    fi
    
    local failure_message
    failure_message=$(format_step_failure "$label" "$stdout_content" "$stderr_content" "$kind" "$elapsed_ms" "$note")
    
    echo "$failure_message" >&2
    rm -f "$output_file"
    return 1
}

resolve_canary_artifact_paths() {
    local extension_id="$1"
    local root_dir="${2:-$REPO_ROOT}"
    
    local extension_root="$root_dir/extensions/$extension_id"
    echo "$extension_root"
    echo "$extension_root/__rootdir_boundary_canary__.ts"
    echo "$extension_root/tsconfig.rootdir-canary.json"
}

cleanup_canary_artifacts() {
    local extension_id="$1"
    local root_dir="${2:-$REPO_ROOT}"
    
    local extension_root="$root_dir/extensions/$extension_id"
    rm -f "$extension_root/__rootdir_boundary_canary__.ts"
    rm -f "$extension_root/tsconfig.rootdir-canary.json"
}

cleanup_canary_artifacts_for_extensions() {
    local extension_ids=("$@")
    local root_dir="${2:-$REPO_ROOT}"
    
    local extension_id
    for extension_id in "${extension_ids[@]}"; do
        cleanup_canary_artifacts "$extension_id" "$root_dir"
    done
}

resolve_boundary_ts_build_info_path() {
    local extension_id="$1"
    echo "$REPO_ROOT/extensions/$extension_id/dist/.boundary-tsc.tsbuildinfo"
}

resolve_boundary_ts_stamp_path() {
    local extension_id="$1"
    local root_dir="${2:-$REPO_ROOT}"
    echo "$root_dir/extensions/$extension_id/dist/.boundary-tsc.stamp"
}

resolve_boundary_check_lock_path() {
    local root_dir="${1:-$REPO_ROOT}"
    echo "$root_dir/dist/.extension-package-boundary.lock"
}

is_process_alive() {
    local pid="$1"
    
    if ! [[ "$pid" =~ ^[0-9]+$ ]] || [[ $pid -le 0 ]]; then
        return 1
    fi
    
    kill -0 "$pid" 2>/dev/null
}

remove_stale_boundary_check_lock() {
    local lock_path="$1"
    local owner_path="$lock_path/owner.json"
    
    if [[ ! -f "$owner_path" ]]; then
        rm -rf "$lock_path"
        return 0
    fi
    
    local pid
    pid=$(jq -r '.pid // empty' "$owner_path" 2>/dev/null)
    
    if [[ -n "$pid" ]] && is_process_alive "$pid"; then
        return 1
    fi
    
    rm -rf "$lock_path"
    return 0
}

acquire_boundary_check_lock() {
    local root_dir="${1:-$REPO_ROOT}"
    local lock_path
    lock_path=$(resolve_boundary_check_lock_path "$root_dir")
    
    mkdir -p "$(dirname "$lock_path")"
    
    if ! mkdir "$lock_path" 2>/dev/null; then
        if remove_stale_boundary_check_lock "$lock_path"; then
            mkdir "$lock_path"
        else
            local error_msg="extension package boundary check

kind: lock-contention
lock: $lock_path
another extension package boundary check is already running in this checkout"
            echo "$error_msg" >&2
            return 1
        fi
    fi
    
    cat > "$lock_path/owner.json" <<EOF
{
  "pid": $$
}
EOF
    
    # Speichere die Lock-Freigabe-Funktion
    echo "release_boundary_check_lock() { rm -rf '$lock_path'; }"
}

run_compile_check() {
    local extension_ids=("$@")
    
    local prep_started_at
    prep_started_at=$(date +%s%3N)
    
    echo "preparing plugin-sdk boundary artifacts for ${#extension_ids[@]} plugins"
    run_node_step "plugin-sdk boundary prep" "$PREPARE_BOUNDARY_ARTIFACTS_BIN"
    
    local prep_elapsed_ms
    prep_elapsed_ms=$(( $(date +%s%3N) - prep_started_at ))
    
    local concurrency
    concurrency=$(resolve_compile_concurrency)
    
    echo "compile concurrency $concurrency"
    
    local compile_started_at
    compile_started_at=$(date +%s%3N)
    
    local verbose_fresh_logs="${OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH:-}"
    
    local shared_newest_input_mtime_ms
    shared_newest_input_mtime_ms=$(collect_newest_mtime "$REPO_ROOT/dist/plugin-sdk" false)
    
    local index=0
    local total=${#extension_ids[@]}
    
    for extension_id in "${extension_ids[@]}"; do
        local ts_build_info_path
        ts_build_info_path=$(resolve_boundary_ts_build_info_path "$extension_id")
        
        local extension_newest_input_mtime_ms
        extension_newest_input_mtime_ms=$(collect_newest_mtime "$REPO_ROOT/extensions/$extension_id")
        
        mkdir -p "$(dirname "$ts_build_info_path")"
        
        if [[ "$(is_boundary_compile_fresh "$extension_id" "$REPO_ROOT" "$extension_newest_input_mtime_ms" "$shared_newest_input_mtime_ms")" == "true" ]]; then
            ((SKIPPED_COMPILE_COUNT++))
            if [[ "$verbose_fresh_logs" == "1" ]]; then
                echo "[$((++index))/$total] $extension_id (fresh; skipping)"
            fi
            continue
        fi
        
        echo "[$((++index))/$total] $extension_id"
        
        local compile_start
        compile_start=$(date +%s%3N)
        
        local result
        result=0
        node "$TSC_BIN" -p "$REPO_ROOT/extensions/$extension_id/tsconfig.json" --noEmit --incremental --tsBuildInfoFile "$ts_build_info_path" >/dev/null 2>&1 || result=$?
        
        local compile_end
        compile_end=$(date +%s%3N)
        local elapsed_ms=$((compile_end - compile_start))
        
        if [[ $result -ne 0 ]]; then
            echo "Compilation failed for $extension_id" >&2
            return 1
        fi
        
        write_stamp_file "$(resolve_boundary_ts_stamp_path "$extension_id")"
        
        COMPILE_TIMINGS+=("$extension_id")
        COMPILE_TIMINGS+=("$elapsed_ms")
        ((TOTAL_COMPILE_COUNT++))
    done
    
    local compile_elapsed_ms
    compile_elapsed_ms=$(( $(date +%s%3N) - compile_started_at ))
    
    if [[ "$verbose_fresh_logs" != "1" ]] && [[ $SKIPPED_COMPILE_COUNT -gt 0 ]]; then
        format_skipped_compile_progress "$SKIPPED_COMPILE_COUNT" "$total"
    fi
    
    echo "$prep_elapsed_ms:$compile_elapsed_ms"
}

run_canary_check() {
    local extension_ids=("$@")
    local started_at
    started_at=$(date +%s%3N)
    
    local index=0
    local total=${#extension_ids[@]}
    
    for extension_id in "${extension_ids[@]}"; do
        cleanup_canary_artifacts "$extension_id"
        echo "[$((++index))/$total] $extension_id canary"
        
        local canary_paths
        canary_paths=($(resolve_canary_artifact_paths "$extension_id"))
        local extension_root="${canary_paths[0]}"
        local canary_path="${canary_paths[1]}"
        local tsconfig_path="${canary_paths[2]}"
        
        cat > "$canary_path" <<EOF
import { ROOTDIR_BOUNDARY_CANARY } from "$ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH";
void ROOTDIR_BOUNDARY_CANARY;
export {};
EOF
        
        cat > "$tsconfig_path" <<EOF
{
  "extends": "./tsconfig.json",
  "include": ["./__rootdir_boundary_canary__.ts"],
  "exclude": []
}
EOF
        
        local result
        result=0
        node "$TSC_BIN" -p "$tsconfig_path" --noEmit >/dev/null 2>&1 || result=$?
        
        if [[ $result -eq 0 ]]; then
            echo "$extension_id canary unexpectedly passed" >&2
            cleanup_canary_artifacts "$extension_id"
            return 1
        fi
        
        # Prüfe auf TS6059 Fehler
        local output
        output=$(node "$TSC_BIN" -p "$tsconfig_path" --noEmit 2>&1 || true)
        
        if [[ ! "$output" =~ TS6059 ]] || [[ ! "$output" =~ $ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT ]]; then
            echo "$output" >&2
            cleanup_canary_artifacts "$extension_id"
            return 1
        fi
        
        cleanup_canary_artifacts "$extension_id"
    done
    
    local elapsed_ms
    elapsed_ms=$(( $(date +%s%3N) - started_at ))
    echo "$elapsed_ms"
}

main() {
    local started_at
    started_at=$(date +%s%3N)
    
    local mode
    mode=$(parse_mode "$@")
    
    local opt_in_extension_ids
    opt_in_extension_ids=($(collect_opt_in_extension_ids))
    
    local canary_extension_ids
    canary_extension_ids=($(collect_canary_extension_ids "${opt_in_extension_ids[@]}"))
    
    # Acquire lock
    local release_func
    release_func=$(acquire_boundary_check_lock)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # Setup cleanup
    trap 'cleanup_canary_artifacts_for_extensions "${opt_in_extension_ids[@]}"' EXIT
    
    local prep_elapsed_ms=""
    local compile_count=0
    local skipped_compile_count=0
    local compile_elapsed_ms=""
    local canary_elapsed_ms=""
    
    # Run checks based on mode
    if [[ "$mode" == "all" ]] || [[ "$mode" == "compile" ]]; then
        local times
        times=$(run_compile_check "${opt_in_extension_ids[@]}")
        prep_elapsed_ms="${times%%:*}"
        compile_elapsed_ms="${times##*:}"
        compile_count=$TOTAL_COMPILE_COUNT
        skipped_compile_count=$SKIPPED_COMPILE_COUNT
    fi
    
    if [[ "$mode" == "all" ]] || [[ "$mode" == "canary" ]]; then
        canary_elapsed_ms=$(run_canary_check "${canary_extension_ids[@]}")
    fi
    
    local elapsed_ms
    elapsed_ms=$(( $(date +%s%3N) - started_at ))
    
    local canary_count=0
    if [[ "$mode" == "all" ]] || [[ "$mode" == "canary" ]]; then
        canary_count=${#canary_extension_ids[@]}
    fi
    
    format_boundary_check_success_summary "$mode" "$compile_count" "$skipped_compile_count" "$canary_count" "$prep_elapsed_ms" "$compile_elapsed_ms" "$canary_elapsed_ms" "$elapsed_ms"
    format_slow_compile_summary
    
    # Release lock
    eval "$release_func"
}

# Starte das Hauptprogramm
main "$@"
