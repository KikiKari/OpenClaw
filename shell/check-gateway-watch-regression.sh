#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "dd37f16e8913028ed754df298a8f4b6706b572435f30c73a979f9a76f233ce64", "source_sha256": "08abd9802ec4316f1570b6eba8dd2d40356789759d4be8f3a0078e57999a841c", "target_language": "shell"}
# check-gateway-watch-regression.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-gateway-watch-regression.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Default values
OUTPUT_DIR=".local/gateway-watch-regression"
WINDOW_MS=10000
READY_TIMEOUT_MS=20000
READY_SETTLE_MS=500
SIGKILL_GRACE_MS=10000
CPU_WARN_MS=1000
CPU_FAIL_MS=8000
DIST_RUNTIME_FILE_GROWTH_MAX=200
DIST_RUNTIME_BYTE_GROWTH_MAX=2097152
KEEP_LOGS=true
SKIP_BUILD=false

# Environment variables to skip certain services
declare -A WATCH_GATEWAY_SKIP_ENV
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_DISABLE_BONJOUR"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_ACPX_RUNTIME"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_ACPX_RUNTIME_PROBE"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_BROWSER_CONTROL_SERVER"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_CANVAS_HOST"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_CHANNELS"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_CRON"]="1"
WATCH_GATEWAY_SKIP_ENV["OPENCLAW_SKIP_GMAIL_WATCHER"]="1"

# Parse command line arguments
parse_args() {
    local i=0
    while [[ $i -lt $# ]]; do
        local arg="${!i}"
        local next=""
        if [[ $((i + 1)) -lt $# ]]; then
            next="${!$((i + 1))}"
        fi
        
        case "$arg" in
            "--output-dir")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                OUTPUT_DIR="$(realpath "$next")"
                i=$((i + 1))
                ;;
            "--window-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                WINDOW_MS="$next"
                i=$((i + 1))
                ;;
            "--ready-timeout-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                READY_TIMEOUT_MS="$next"
                i=$((i + 1))
                ;;
            "--ready-settle-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                READY_SETTLE_MS="$next"
                i=$((i + 1))
                ;;
            "--sigkill-grace-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                SIGKILL_GRACE_MS="$next"
                i=$((i + 1))
                ;;
            "--cpu-warn-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                CPU_WARN_MS="$next"
                i=$((i + 1))
                ;;
            "--cpu-fail-ms")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                CPU_FAIL_MS="$next"
                i=$((i + 1))
                ;;
            "--dist-runtime-file-growth-max")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                DIST_RUNTIME_FILE_GROWTH_MAX="$next"
                i=$((i + 1))
                ;;
            "--dist-runtime-byte-growth-max")
                if [[ -z "$next" ]]; then
                    echo "Missing value for $arg" >&2
                    exit 1
                fi
                DIST_RUNTIME_BYTE_GROWTH_MAX="$next"
                i=$((i + 1))
                ;;
            "--skip-build")
                SKIP_BUILD=true
                ;;
            *)
                echo "Unknown argument: $arg" >&2
                exit 1
                ;;
        esac
        i=$((i + 1))
    done
}

# Ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# Remove path if it exists
remove_path_if_exists() {
    if [[ -e "$1" ]]; then
        rm -rf "$1"
    fi
}

# Normalize path separators
normalize_path() {
    echo "${1//\\//}"
}

# List tree entries
list_tree_entries() {
    local root_name="$1"
    local root_path="$PWD/$root_name"
    
    if [[ ! -e "$root_path" ]]; then
        echo "$root_name (missing)"
        return
    fi
    
    find "$root_name" -type f -o -type d | sed 's/\\/\//g' | sort
}

# Convert bytes to human readable format
human_bytes() {
    local bytes=$1
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.1fK\n" "$(echo "scale=1; $bytes/1024" | bc)"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.1fM\n" "$(echo "scale=1; $bytes/1048576" | bc)"
    else
        printf "%.1fG\n" "$(echo "scale=1; $bytes/1073741824" | bc)"
    fi
}

# Snapshot tree statistics
snapshot_tree() {
    local root_name="$1"
    local root_path="$PWD/$root_name"
    
    if [[ ! -e "$root_path" ]]; then
        echo "false 0 0 0 0 0"
        return
    fi
    
    local files=0
    local directories=0
    local symlinks=0
    local entries=0
    local apparent_bytes=0
    
    while IFS= read -r -d '' file; do
        entries=$((entries + 1))
        if [[ -d "$file" ]]; then
            directories=$((directories + 1))
        elif [[ -L "$file" ]]; then
            symlinks=$((symlinks + 1))
        elif [[ -f "$file" ]]; then
            files=$((files + 1))
            apparent_bytes=$((apparent_bytes + $(stat -c %s "$file" 2>/dev/null || echo 0)))
        fi
    done < <(find "$root_name" -print0 2>/dev/null || true)
    
    echo "true $files $directories $symlinks $entries $apparent_bytes"
}

# Write snapshot data
write_snapshot() {
    local snapshot_dir="$1"
    ensure_dir "$snapshot_dir"
    
    # Write paths
    {
        list_tree_entries "dist"
        list_tree_entries "dist-runtime"
    } > "$snapshot_dir/paths.txt"
    
    # Get snapshots
    local dist_stats
    dist_stats=$(snapshot_tree "dist")
    read -r dist_exists dist_files dist_directories dist_symlinks dist_entries dist_apparent_bytes <<< "$dist_stats"
    
    local dist_runtime_stats
    dist_runtime_stats=$(snapshot_tree "dist-runtime")
    read -r dist_runtime_exists dist_runtime_files dist_runtime_directories dist_runtime_symlinks dist_runtime_entries dist_runtime_apparent_bytes <<< "$dist_runtime_stats"
    
    # Write JSON snapshot
    cat > "$snapshot_dir/snapshot.json" <<EOF
{
  "generatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
  "dist": {
    "exists": $dist_exists,
    "files": $dist_files,
    "directories": $dist_directories,
    "symlinks": $dist_symlinks,
    "entries": $dist_entries,
    "apparentBytes": $dist_apparent_bytes
  },
  "distRuntime": {
    "exists": $dist_runtime_exists,
    "files": $dist_runtime_files,
    "directories": $dist_runtime_directories,
    "symlinks": $dist_runtime_symlinks,
    "entries": $dist_runtime_entries,
    "apparentBytes": $dist_runtime_apparent_bytes
  }
}
EOF
    
    # Write stats.txt
    cat > "$snapshot_dir/stats.txt" <<EOF
generated_at: $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

[dist]
files: $dist_files
directories: $dist_directories
symlinks: $dist_symlinks
entries: $dist_entries
apparent_bytes: $dist_apparent_bytes
apparent_human: $(human_bytes $dist_apparent_bytes)

[dist-runtime]
files: $dist_runtime_files
directories: $dist_runtime_directories
symlinks: $dist_runtime_symlinks
entries: $dist_runtime_entries
apparent_bytes: $dist_runtime_apparent_bytes
apparent_human: $(human_bytes $dist_runtime_apparent_bytes)

EOF
    
    echo "$dist_exists $dist_files $dist_directories $dist_symlinks $dist_entries $dist_apparent_bytes $dist_runtime_exists $dist_runtime_files $dist_runtime_directories $dist_runtime_symlinks $dist_runtime_entries $dist_runtime_apparent_bytes"
}

# Run checked command
run_checked_command() {
    if ! "$@"; then
        echo "$* failed with status $?" >&2
        exit 1
    fi
}

# Sleep function
sleep_ms() {
    sleep "$(echo "scale=3; $1/1000" | bc)"
}

# Parse ps CPU time to milliseconds
parse_ps_cpu_time_ms() {
    local time_text="$1"
    local days=0
    local hours=0
    local minutes=0
    local seconds=0
    
    if [[ "$time_text" == *-* ]]; then
        IFS='-' read -r days time_text <<< "$time_text"
    fi
    
    IFS=':' read -ra parts <<< "$time_text"
    if [[ ${#parts[@]} -eq 2 ]]; then
        minutes="${parts[0]}"
        seconds="${parts[1]}"
    elif [[ ${#parts[@]} -eq 3 ]]; then
        hours="${parts[0]}"
        minutes="${parts[1]}"
        seconds="${parts[2]}"
    else
        echo "null"
        return
    fi
    
    # Convert to milliseconds
    echo "$(( (days * 24 + hours) * 3600 + minutes * 60 + seconds ) * 1000))"
}

# Read process tree CPU milliseconds
read_process_tree_cpu_ms() {
    local root_pid="$1"
    
    if ! [[ "$root_pid" =~ ^[0-9]+$ ]] || [[ $root_pid -le 0 ]]; then
        echo "null"
        return
    fi
    
    if ! command -v ps >/dev/null 2>&1; then
        echo "null"
        return
    fi
    
    local ps_output
    ps_output=$(ps -eo pid=,ppid=,time= 2>/dev/null) || {
        echo "null"
        return
    }
    
    # Process the ps output to build parent-child relationships
    declare -A cpu_by_pid
    declare -A children_by_parent
    
    while IFS= read -r line; do
        line=$(echo "$line" | xargs)  # trim whitespace
        if [[ -z "$line" ]]; then
            continue
        fi
        
        local pid ppid cpu_time
        read -r pid ppid cpu_time <<< "$line"
        
        if ! [[ "$pid" =~ ^[0-9]+$ ]] || ! [[ "$ppid" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        local cpu_ms
        cpu_ms=$(parse_ps_cpu_time_ms "$cpu_time")
        if [[ "$cpu_ms" == "null" ]]; then
            continue
        fi
        
        cpu_by_pid["$pid"]="$cpu_ms"
        if [[ -z "${children_by_parent["$ppid"]:-}" ]]; then
            children_by_parent["$ppid"]="$pid"
        else
            children_by_parent["$ppid"]="${children_by_parent["$ppid"]} $pid"
        fi
    done <<< "$ps_output"
    
    if [[ -z "${cpu_by_pid["$root_pid"]:-}" ]]; then
        echo "null"
        return
    fi
    
    local total_cpu_ms=0
    declare -A seen
    local stack=("$root_pid")
    
    while [[ ${#stack[@]} -gt 0 ]]; do
        local pid="${stack[-1]}"
        unset 'stack[-1]'
        
        if [[ -n "${seen["$pid"]:-}" ]]; then
            continue
        fi
        
        seen["$pid"]=1
        total_cpu_ms=$((total_cpu_ms + ${cpu_by_pid["$pid"]:-0}))
        
        if [[ -n "${children_by_parent["$pid"]:-}" ]]; then
            for child_pid in ${children_by_parent["$pid"]}; do
                stack+=("$child_pid")
            done
        fi
    done
    
    echo "$total_cpu_ms"
}

# Wait for gateway ready
wait_for_gateway_ready() {
    local log_file="$1"
    local timeout_ms="$2"
    local deadline
    deadline=$(($(date +%s%3N) + timeout_ms))
    
    while [[ $(date +%s%3N) -lt $deadline ]]; do
        if grep -q "\[gateway\] ready (" "$log_file" 2>/dev/null; then
            return 0
        fi
        sleep_ms 100
    done
    
    return 1
}

# Allocate loopback port
allocate_loopback_port() {
    local port
    port=$(netstat -tnl | awk '/^tcp.*127\.0\.0\.1:[0-9]+.*LISTEN$/ {gsub(/.*:/, "", $4); print $4}' | sort -n | tail -1)
    if [[ -n "$port" ]]; then
        echo $((port + 1))
    else
        echo 3000
    fi
}

# Build timed watch command
build_timed_watch_command() {
    local pid_file_path="$1"
    local time_file_path="$2"
    local isolated_home_dir="$3"
    local port="$4"
    
    # Create shell script content
    cat > "$isolated_home_dir/run_watch.sh" <<'EOF'
echo $$ > "$OPENCLAW_WATCH_PID_FILE"
mkdir -p "$OPENCLAW_HOME/.openclaw"
printf '%s\n' '{"gateway":{"controlUi":{"enabled":false}}}' > "$OPENCLAW_HOME/.openclaw/openclaw.json"
exec node scripts/watch-node.mjs gateway --force --allow-unconfigured --port "$PORT" --token watch-regression-token
EOF
    
    chmod +x "$isolated_home_dir/run_watch.sh"
    
    # Prepare environment
    local env_vars=""
    for key in "${!WATCH_GATEWAY_SKIP_ENV[@]}"; do
        env_vars="$env_vars $key=${WATCH_GATEWAY_SKIP_ENV[$key]}"
    done
    
    echo "$env_vars PORT=$port OPENCLAW_WATCH_PID_FILE=$pid_file_path HOME=$isolated_home_dir OPENCLAW_HOME=$isolated_home_dir"
}

# Parse timing file
parse_timing_file() {
    local time_file_path="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local user_val sys_val elapsed_val
        user_val=$(grep "^user" "$time_file_path" | awk '{print $1}' || echo "NaN")
        sys_val=$(grep "^sys" "$time_file_path" | awk '{print $1}' || echo "NaN")
        elapsed_val=$(grep "^real" "$time_file_path" | awk '{print $1}' || echo "NaN")
        echo "$user_val $sys_val $elapsed_val"
    else
        if grep -q "__TIMING__" "$time_file_path"; then
            local line
            line=$(grep "__TIMING__" "$time_file_path")
            if [[ "$line" =~ __TIMING__\ user=([0-9.]+)\ sys=([0-9.]+)\ elapsed=([0-9.]+) ]]; then
                echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
                return
            fi
        fi
        echo "NaN NaN NaN"
    fi
}

# Run timed watch
run_timed_watch() {
    local output_dir="$1"
    local pid_file_path="$output_dir/watch.pid"
    local time_file_path="$output_dir/watch.time.log"
    local isolated_home_dir
    isolated_home_dir=$(mktemp -d "${TMPDIR:-/tmp}/openclaw-gateway-watch-XXXXXX")
    echo "$isolated_home_dir" > "$output_dir/watch.home.txt"
    local stdout_path="$output_dir/watch.stdout.log"
    local stderr_path="$output_dir/watch.stderr.log"
    
    # Clean up stale files
    remove_path_if_exists "$pid_file_path"
    remove_path_if_exists "$time_file_path"
    remove_path_if_exists "$stdout_path"
    remove_path_if_exists "$stderr_path"
    
    local port
    port=$(allocate_loopback_port)
    echo "$port" > "$output_dir/watch.port.txt"
    
    # Build command
    local env_vars
    env_vars=$(build_timed_watch_command "$pid_file_path" "$time_file_path" "$isolated_home_dir" "$port")
    
    # Start the process
    local cmd="/bin/sh"
    local args="-lc"
    local shell_source="echo \\$\$ > $pid_file_path; mkdir -p $isolated_home_dir/.openclaw; printf '%s\\n' '{\"gateway\":{\"controlUi\":{\"enabled\":false}}}' > $isolated_home_dir/.openclaw/openclaw.json; exec node scripts/watch-node.mjs gateway --force --allow-unconfigured --port $port --token watch-regression-token"
    
    # Run with time command
    if [[ "$OSTYPE" == "darwin"* ]]; then
        (/usr/bin/time -lp -o "$time_file_path" $cmd $args "$shell_source" 2>"$stderr_path") >"$stdout_path" &
    else
        (/usr/bin/time -f "__TIMING__ user=%U sys=%S elapsed=%e" -o "$time_file_path" $cmd $args "$shell_source" 2>"$stderr_path") >"$stdout_path" &
    fi
    
    local child_pid=$!
    
    # Wait for PID file
    local watch_pid=""
    for ((attempt=0; attempt<50; attempt++)); do
        if [[ -f "$pid_file_path" ]]; then
            watch_pid=$(cat "$pid_file_path")
            break
        fi
        sleep_ms 100
    done
    
    # Wait for ready state
    local ready_before_window=false
    if wait_for_gateway_ready "$stdout_path" "$READY_TIMEOUT_MS"; then
        ready_before_window=true
        if [[ $READY_SETTLE_MS -gt 0 ]]; then
            sleep_ms "$READY_SETTLE_MS"
        fi
    fi
    
    # Measure CPU usage
    local idle_cpu_start_ms=""
    local idle_cpu_end_ms=""
    if [[ -n "$watch_pid" ]]; then
        idle_cpu_start_ms=$(read_process_tree_cpu_ms "$watch_pid")
    fi
    
    sleep_ms "$WINDOW_MS"
    
    if [[ -n "$watch_pid" ]]; then
        idle_cpu_end_ms=$(read_process_tree_cpu_ms "$watch_pid")
    fi
    
    # Terminate process
    if [[ -n "$watch_pid" ]]; then
        kill -TERM "$watch_pid" 2>/dev/null || true
    fi
    
    # Wait for graceful exit or force kill
    local graceful_exit=false
    local timeout_occurred=false
    
    # Simple timeout implementation
    local start_time
    start_time=$(date +%s)
    while kill -0 "$child_pid" 2>/dev/null; do
        if [[ $(($(date +%s) - start_time)) -ge $((SIGKILL_GRACE_MS / 1000)) ]]; then
            timeout_occurred=true
            break
        fi
        sleep 0.1
    done
    
    if ! $timeout_occurred; then
        graceful_exit=true
    else
        if [[ -n "$watch_pid" ]]; then
            kill -KILL "$watch_pid" 2>/dev/null || true
        fi
        wait "$child_pid" 2>/dev/null || true
    fi
    
    # Wait for process to finish
    wait "$child_pid" 2>/dev/null || true
    
    # Parse timing
    local timing_result
    timing_result=$(parse_timing_file "$time_file_path")
    local user_seconds sys_seconds elapsed_seconds
    read -r user_seconds sys_seconds elapsed_seconds <<< "$timing_result"
    
    # Calculate idle CPU ms
    local idle_cpu_ms=""
    if [[ -n "$idle_cpu_start_ms" ]] && [[ "$idle_cpu_start_ms" != "null" ]] && \
       [[ -n "$idle_cpu_end_ms" ]] && [[ "$idle_cpu_end_ms" != "null" ]]; then
        idle_cpu_ms=$((idle_cpu_end_ms - idle_cpu_start_ms))
        if [[ $idle_cpu_ms -lt 0 ]]; then
            idle_cpu_ms=0
        fi
    fi
    
    echo "$ready_before_window $user_seconds $sys_seconds $elapsed_seconds $idle_cpu_ms $stdout_path $stderr_path $time_file_path"
}

# Parse path file
parse_path_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        grep -v '^$' "$file_path" | sed 's/[[:space:]]*$//'
    fi
}

# Write diff artifacts
write_diff_artifacts() {
    local output_dir="$1"
    local pre_dir="$2"
    local post_dir="$3"
    local diff_dir="$output_dir/diff"
    
    ensure_dir "$diff_dir"
    
    local pre_paths_file="$pre_dir/paths.txt"
    local post_paths_file="$post_dir/paths.txt"
    
    # Create temporary sorted files
    local pre_sorted post_sorted
    pre_sorted=$(mktemp)
    post_sorted=$(mktemp)
    
    parse_path_file "$pre_paths_file" | sort > "$pre_sorted"
    parse_path_file "$post_paths_file" | sort > "$post_sorted"
    
    # Find differences
    comm -13 "$pre_sorted" "$post_sorted" > "$diff_dir/added-paths.txt"
    comm -23 "$pre_sorted" "$post_sorted" > "$diff_dir/removed-paths.txt"
    
    local added_count removed_count
    added_count=$(wc -l < "$diff_dir/added-paths.txt" | tr -d ' ')
    removed_count=$(wc -l < "$diff_dir/removed-paths.txt" | tr -d ' ')
    
    rm -f "$pre_sorted" "$post_sorted"
    
    echo "$added_count $removed_count"
}

# Fail function
fail() {
    echo "FAIL: $*" >&2
}

# Warn function
warn() {
    echo "WARN: $*" >&2
}

# Detect watch build reason
detect_watch_build_reason() {
    local stdout="$1"
    local stderr="$2"
    
    local combined="$stdout"$'\n'"$stderr"
    if [[ "$combined" =~ Building\ TypeScript\ \(dist\ is\ stale:\ ([a-z_]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Main function
main() {
    parse_args "$@"
    
    ensure_dir "$OUTPUT_DIR"
    
    if [[ "$SKIP_BUILD" != "true" ]]; then
        run_checked_command pnpm build
        # Note: In bash we don't have writeBuildStamp functionality, so we skip this part
    fi
    
    # Take pre-snapshot
    local pre_dir="$OUTPUT_DIR/pre"
    local pre_snapshot
    pre_snapshot=$(write_snapshot "$pre_dir")
    read -r pre_dist_exists pre_dist_files pre_dist_directories pre_dist_symlinks pre_dist_entries pre_dist_apparent_bytes pre_dist_runtime_exists pre_dist_runtime_files pre_dist_runtime_directories pre_dist_runtime_symlinks pre_dist_runtime_entries pre_dist_runtime_apparent_bytes <<< "$pre_snapshot"
    
    # Run timed watch
    local watch_dir="$OUTPUT_DIR/watch"
    ensure_dir "$watch_dir"
    
    local watch_result
    watch_result=$(run_timed_watch "$watch_dir")
    read -r ready_before_window user_seconds sys_seconds elapsed_seconds idle_cpu_ms stdout_path stderr_path time_file_path <<< "$watch_result"
    
    # Take post-snapshot
    local post_dir="$OUTPUT_DIR/post"
    local post_snapshot
    post_snapshot=$(write_snapshot "$post_dir")
    read -r post_dist_exists post_dist_files post_dist_directories post_dist_symlinks post_dist_entries post_dist_apparent_bytes post_dist_runtime_exists post_dist_runtime_files post_dist_runtime_directories post_dist_runtime_symlinks post_dist_runtime_entries post_dist_runtime_apparent_bytes <<< "$post_snapshot"
    
    # Write diff artifacts
    local diff_result
    diff_result=$(write_diff_artifacts "$OUTPUT_DIR" "$pre_dir" "$post_dir")
    read -r added_paths_count removed_paths_count <<< "$diff_result"
    
    # Calculate metrics
    local dist_runtime_file_growth dist_runtime_byte_growth
    dist_runtime_file_growth=$((post_dist_runtime_files - pre_dist_runtime_files))
    dist_runtime_byte_growth=$((post_dist_runtime_apparent_bytes - pre_dist_runtime_apparent_bytes))
    
    # Count dist-runtime added paths
    local dist_runtime_added_paths=0
    if [[ -f "$OUTPUT_DIR/diff/added-paths.txt" ]]; then
        dist_runtime_added_paths=$(grep -c "^dist-runtime/" "$OUTPUT_DIR/diff/added-paths.txt" || echo 0)
    fi
    
    # Calculate CPU usage
    local total_cpu_ms cpu_ms
    if [[ "$user_seconds" != "NaN" ]] && [[ "$sys_seconds" != "NaN" ]]; then
        total_cpu_ms=$(echo "($user_seconds + $sys_seconds) * 1000" | bc | cut -d. -f1)
    else
        total_cpu_ms="NaN"
    fi
    
    if [[ -n "$idle_cpu_ms" ]]; then
        cpu_ms="$idle_cpu_ms"
    else
        cpu_ms="$total_cpu_ms"
    fi
    
    # Check if watch triggered build
    local watch_triggered_build=false
    local watch_build_reason=""
    if grep -q "Building TypeScript (dist is stale" "$stderr_path" || \
       grep -q "Building TypeScript (dist is stale" "$stdout_path"; then
        watch_triggered_build=true
        local stdout_content stderr_content
        stdout_content=$(cat "$stdout_path")
        stderr_content=$(cat "$stderr_path")
        watch_build_reason=$(detect_watch_build_reason "$stdout_content" "$stderr_content")
    fi
    
    # Create summary
    local summary_json
    summary_json=$(cat <<EOF
{
  "windowMs": $WINDOW_MS,
  "watchTriggeredBuild": $watch_triggered_build,
  "watchBuildReason": "$watch_build_reason",
  "cpuMs": $cpu_ms,
  "totalCpuMs": $total_cpu_ms,
  "readyBeforeWindow": $ready_before_window,
  "cpuWarnMs": $CPU_WARN_MS,
  "cpuFailMs": $CPU_FAIL_MS,
  "distRuntimeFileGrowth": $dist_runtime_file_growth,
  "distRuntimeFileGrowthMax": $DIST_RUNTIME_FILE_GROWTH_MAX,
  "distRuntimeByteGrowth": $dist_runtime_byte_growth,
  "distRuntimeByteGrowthMax": $DIST_RUNTIME_BYTE_GROWTH_MAX,
  "distRuntimeAddedPaths": $dist_runtime_added_paths,
  "addedPaths": $added_paths_count,
  "removedPaths": $removed_paths_count,
  "watchExit": null,
  "timing": {
    "userSeconds": $user_seconds,
    "sysSeconds": $sys_seconds,
    "elapsedSeconds": $elapsed_seconds
  }
}
EOF
)
    
    echo "$summary_json" > "$OUTPUT_DIR/summary.json"
    echo "$summary_json"
    
    # Check for failures
    local failures=()
    local warnings=()
    
    if [[ "$watch_triggered_build" == "true" ]] && [[ "$watch_build_reason" == "dirty_watched_tree" ]]; then
        failures+=("gateway:watch invalid local run: dirty watched source tree forced a rebuild during the watch window")
    fi
    
    if [[ $dist_runtime_file_growth -gt $DIST_RUNTIME_FILE_GROWTH_MAX ]]; then
        failures+=("dist-runtime file growth $dist_runtime_file_growth exceeded max $DIST_RUNTIME_FILE_GROWTH_MAX")
    fi
    
    if [[ $dist_runtime_byte_growth -gt $DIST_RUNTIME_BYTE_GROWTH_MAX ]]; then
        failures+=("dist-runtime apparent byte growth $dist_runtime_byte_growth exceeded max $DIST_RUNTIME_BYTE_GROWTH_MAX")
    fi
    
    if [[ "$cpu_ms" == "NaN" ]]; then
        failures+=("failed to parse CPU timing from the bounded gateway:watch run")
    elif [[ $cpu_ms -gt $CPU_FAIL_MS ]]; then
        failures+=("LOUD ALARM: gateway:watch used $cpu_ms ms CPU in $WINDOW_MS ms window, above loud-alarm threshold $CPU_FAIL_MS ms")
    elif [[ $cpu_ms -gt $CPU_WARN_MS ]]; then
        warnings+=("gateway:watch used $cpu_ms ms CPU in $WINDOW_MS ms window, above target $CPU_WARN_MS ms")
    fi
    
    # Output warnings
    for warning in "${warnings[@]}"; do
        warn "$warning"
    done
    
    # Output failures and exit if needed
    if [[ ${#failures[@]} -gt 0 ]]; then
        for failure in "${failures[@]}"; do
            fail "$failure"
        done
        
        local has_dirty_tree=false
        for failure in "${failures[@]}"; do
            if [[ "$failure" == *"dirty watched source tree"* ]]; then
                has_dirty_tree=true
                break
            fi
        done
        
        if [[ "$has_dirty_tree" == "false" ]]; then
            fail "Possible duplicate dist-runtime graph regression: this can reintroduce split runtime personalities where plugins and core observe different global state, including Telegram missing /voice, /phone, or /pair."
        fi
        
        exit 1
    fi
    
    exit 0
}

# Run main function
main "$@"
