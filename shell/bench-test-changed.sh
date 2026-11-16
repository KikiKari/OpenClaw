#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "c6e41908df542f0a9412f5c7e9fe8ba5a7d10c4fc0afca299e7730926324ccae", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "shell"}
# bench-test-changed.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Default values
cwd="$(pwd)"
ref="origin/main"
rss=false
mode="ref"
max_workers=""

# Parse arguments
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd)
      cwd="$2"
      shift 2
      ;;
    --ref)
      ref="$2"
      shift 2
      ;;
    --max-workers)
      max_workers="$2"
      shift 2
      ;;
    --no-rss)
      rss=false
      shift
      ;;
    --worktree)
      mode="worktree"
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

# Resolve cwd to absolute path
cwd=$(realpath "$cwd")

# Function to run git commands and capture output
run_git_list() {
  local git_args=("$@")
  local output
  output=$(git "${git_args[@]}" 2>&1)
  if [[ $? -ne 0 ]]; then
    echo "Error running git ${git_args[*]}: $output" >&2
    exit 1
  fi
  echo "$output" | grep -v '^$'
}

# List changed paths based on mode
list_changed_paths() {
  if [[ "$mode" == "worktree" ]]; then
    # Combine diff and untracked files, sort and deduplicate
    {
      run_git_list -C "$cwd" diff --name-only --relative HEAD --
      run_git_list -C "$cwd" ls-files --others --exclude-standard
    } | sort -u
  else
    run_git_list -C "$cwd" diff --name-only "$ref...HEAD"
  fi
}

# Parse maximum RSS from time output
parse_max_rss_kb() {
  local output="$1"
  if [[ "$output" =~ ([0-9]+)[[:space:]]+maximum[[:space:]]+resident[[:space:]]+set[[:space:]]+size ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# Format RSS value
format_rss() {
  local value_kb="$1"
  if [[ -z "$value_kb" ]]; then
    echo "n/a"
  else
    local mb
    mb=$(awk "BEGIN {printf \"%.1f\", $value_kb / 1024}")
    echo "${mb}MB"
  fi
}

# Format milliseconds
format_ms() {
  local ms="$1"
  if (( $(echo "$ms >= 1000" | bc -l) )); then
    local s
    s=$(awk "BEGIN {printf \"%.2f\", $ms / 1000}")
    echo "${s}s"
  else
    printf "%.0fms" "$ms"
  fi
}

# Run benchmark command
run_bench_command() {
  local command=("$@")
  local started_at output result_status elapsed_ms max_rss_kb
  
  started_at=$(date +%s%3N)
  
  if [[ "$rss" == true ]]; then
    output=$(/usr/bin/time -l "${command[@]}" 2>&1)
    result_status=$?
    max_rss_kb=$(parse_max_rss_kb "$output")
  else
    output=$("${command[@]}" 2>&1)
    result_status=$?
  fi
  
  local ended_at
  ended_at=$(date +%s%3N)
  elapsed_ms=$((ended_at - started_at))
  
  echo "ELAPSED_MS:$elapsed_ms"
  echo "MAX_RSS_KB:$max_rss_kb"
  echo "STATUS:$result_status"
  echo "OUTPUT_START"
  echo "$output"
  echo "OUTPUT_END"
}

# Print run summary
print_run_summary() {
  local label="$1"
  local elapsed_ms="$2"
  local max_rss_kb="$3"
  
  local formatted_elapsed formatted_rss
  formatted_elapsed=$(format_ms "$elapsed_ms")
  formatted_rss=$(format_rss "$max_rss_kb")
  
  printf "%-8s wall=%9s rss=%9s\n" "$label" "$formatted_elapsed" "$formatted_rss"
}

# Main logic
changed_paths=$(list_changed_paths)

if [[ -z "$changed_paths" ]]; then
  if [[ "$mode" == "worktree" ]]; then
    echo "[bench-test-changed] no changed paths in worktree"
  else
    echo "[bench-test-changed] no changed paths for $ref...HEAD"
  fi
  exit 0
fi

if [[ "$mode" == "worktree" ]]; then
  echo "[bench-test-changed] mode=worktree"
else
  echo "[bench-test-changed] ref=$ref"
fi

echo "[bench-test-changed] changed paths:"
echo "$changed_paths" | while read -r path; do
  echo "- $path"
done

# Build commands
if [[ "$mode" == "worktree" ]]; then
  mapfile -t routed_command < <(echo "$changed_paths")
  routed_command=("$PWD/scripts/test-projects.mjs" "${routed_command[@]}")
  root_command=("$PWD/scripts/run-vitest.mjs" "run" "--config" "vitest.config.ts")
  mapfile -t changed_array < <(echo "$changed_paths")
  root_command+=("${changed_array[@]}")
else
  routed_command=("$PWD/scripts/test-projects.mjs" "--changed" "$ref")
  root_command=("$PWD/scripts/run-vitest.mjs" "run" "--config" "vitest.config.ts")
  mapfile -t changed_array < <(echo "$changed_paths")
  root_command+=("${changed_array[@]}")
fi

# Quote arguments for display
quote_arg() {
  local arg="$1"
  if [[ "$arg" =~ [^A-Za-z0-9_./:-] ]]; then
    printf '%q' "$arg"
  else
    echo "$arg"
  fi
}

# Display and run routed command
echo -n "[bench-test-changed] routed: "
for arg in "${routed_command[@]}"; do
  echo -n "$(quote_arg "$arg") "
done
echo

# Prepare environment
env_vars=()
if [[ -n "$max_workers" ]]; then
  export OPENCLAW_VITEST_MAX_WORKERS="$max_workers"
fi

# Run routed command
routed_output=$(run_bench_command "${routed_command[@]}")
routed_elapsed_ms=$(echo "$routed_output" | grep "ELAPSED_MS:" | cut -d: -f2)
routed_max_rss_kb=$(echo "$routed_output" | grep "MAX_RSS_KB:" | cut -d: -f2)
routed_status=$(echo "$routed_output" | grep "STATUS:" | cut -d: -f2)
routed_cmd_output=$(echo "$routed_output" | sed -n '/OUTPUT_START/,/OUTPUT_END/p' | sed '1d;$d')

if [[ "$routed_status" -ne 0 ]]; then
  echo "$routed_cmd_output" >&2
  exit "$routed_status"
fi

# Display and run root command
echo -n "[bench-test-changed] root:   "
for arg in "${root_command[@]}"; do
  echo -n "$(quote_arg "$arg") "
done
echo

root_output=$(run_bench_command "${root_command[@]}")
root_elapsed_ms=$(echo "$root_output" | grep "ELAPSED_MS:" | cut -d: -f2)
root_max_rss_kb=$(echo "$root_output" | grep "MAX_RSS_KB:" | cut -d: -f2)
root_status=$(echo "$root_output" | grep "STATUS:" | cut -d: -f2)
root_cmd_output=$(echo "$root_output" | sed -n '/OUTPUT_START/,/OUTPUT_END/p' | sed '1d;$d')

if [[ "$root_status" -ne 0 ]]; then
  echo "$root_cmd_output" >&2
  exit "$root_status"
fi

# Print summaries
print_run_summary "routed" "$routed_elapsed_ms" "$routed_max_rss_kb"
print_run_summary "root" "$root_elapsed_ms" "$root_max_rss_kb"

# Calculate delta
delta_wall=$((root_elapsed_ms - routed_elapsed_ms))
delta_rss=""
if [[ -n "$routed_max_rss_kb" && -n "$root_max_rss_kb" ]]; then
  delta_rss=$((root_max_rss_kb - routed_max_rss_kb))
fi

formatted_delta_wall=$(format_ms "$delta_wall")
formatted_delta_rss=$(format_rss "$delta_rss")

echo "[bench-test-changed] delta wall=$formatted_delta_wall rss=$formatted_delta_rss"
