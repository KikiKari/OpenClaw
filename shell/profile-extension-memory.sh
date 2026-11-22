#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "347b327cdef54e2863c54fd421d4580110954fca12173adcd605ec51665b82e8", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "shell"}
# profile-extension-memory.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
DEFAULT_CONCURRENCY=6
DEFAULT_TIMEOUT_MS=90000
DEFAULT_COMBINED_TIMEOUT_MS=180000
DEFAULT_TOP=10
RSS_MARKER="__OPENCLAW_MAX_RSS_KB__="

print_help() {
  cat <<EOF
Usage: $0 [options]

Profiles peak RSS for built bundled plugin entrypoints.
Run pnpm build first if you want stats for the latest source changes.

Options:
  --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
  --concurrency <n>        Number of per-extension workers (default: $DEFAULT_CONCURRENCY)
  --timeout-ms <ms>        Per-extension timeout in milliseconds (default: $DEFAULT_TIMEOUT_MS)
  --combined-timeout-ms <ms>
                           Combined-import timeout in milliseconds (default: $DEFAULT_COMBINED_TIMEOUT_MS)
  --top <n>                Show top N entries by delta from baseline (default: $DEFAULT_TOP)
  --json <path>            Write full JSON report to this path
  --skip-combined          Skip the combined all-imports measurement
  --help                   Show this help

Examples:
  pnpm test:extensions:memory
  pnpm test:extensions:memory -- --extension discord
  pnpm test:extensions:memory -- --extension discord --extension telegram --skip-combined
EOF
}

parse_positive_int() {
  local raw="$1"
  local flag_name="$2"
  
  if ! [[ "$raw" =~ ^[0-9]+$ ]] || [ "$raw" -le 0 ]; then
    echo "${flag_name} must be a positive integer" >&2
    exit 1
  fi
  
  echo "$raw"
}

parse_args() {
  local args=()
  local i=0
  
  while [ $i -lt $# ]; do
    local arg="${!i}"
    case "$arg" in
      --)
        ;;
      --extension|-e)
        i=$((i+1))
        if [ $i -gt $# ]; then
          echo "${arg} requires a value" >&2
          exit 1
        fi
        extensions+=("${!i}")
        ;;
      --concurrency)
        i=$((i+1))
        concurrency=$(parse_positive_int "${!i}" "$arg")
        ;;
      --timeout-ms)
        i=$((i+1))
        timeout_ms=$(parse_positive_int "${!i}" "$arg")
        ;;
      --combined-timeout-ms)
        i=$((i+1))
        combined_timeout_ms=$(parse_positive_int "${!i}" "$arg")
        ;;
      --top)
        i=$((i+1))
        top=$(parse_positive_int "${!i}" "$arg")
        ;;
      --json)
        i=$((i+1))
        if [ $i -gt $# ]; then
          echo "${arg} requires a value" >&2
          exit 1
        fi
        json_path="$(realpath "${!i}")"
        ;;
      --skip-combined)
        skip_combined=true
        ;;
      --help|-h)
        print_help
        exit 0
        ;;
      *)
        echo "Unknown argument: ${arg}" >&2
        exit 1
        ;;
    esac
    i=$((i+1))
  done
}

parse_max_rss_mb() {
  local stderr="$1"
  local match
  match=$(echo "$stderr" | grep "^${RSS_MARKER}[0-9]*$" | tail -n1 | sed "s/^${RSS_MARKER}//")
  
  if [ -n "$match" ]; then
    echo "scale=3; $match / 1024" | bc -l
  else
    echo "null"
  fi
}

summarize_stderr() {
  local stderr="$1"
  local lines="${2:-8}"
  echo "$stderr" | tr '\n' '\0' | xargs -0 | head -n "$lines"
}

run_case() {
  local repo_root="$1"
  local hook_path="$2"
  local name="$3"
  local body="$4"
  local timeout_ms="$5"
  
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local stdout_file="$tmp_dir/stdout"
  local stderr_file="$tmp_dir/stderr"
  
  local code=0
  local signal=""
  local timed_out=false
  
  # Starte den Prozess im Hintergrund
  (
    cd "$repo_root"
    NODE_PATH="$hook_path" node --input-type=module -e "$body" >"$stdout_file" 2>"$stderr_file"
  ) &
  
  local pid=$!
  
  # Timeout-Handler
  (
    sleep "$((timeout_ms / 1000))"
    kill -9 "$pid" 2>/dev/null || true
    timed_out=true
  ) &
  
  local timeout_pid=$!
  
  # Warte auf Beendigung
  if wait "$pid"; then
    kill "$timeout_pid" 2>/dev/null || true
  else
    timed_out=true
  fi
  
  local stdout_content
  local stderr_content
  stdout_content=$(cat "$stdout_file" 2>/dev/null || echo "")
  stderr_content=$(cat "$stderr_file" 2>/dev/null || echo "")
  
  local max_rss_mb
  max_rss_mb=$(parse_max_rss_mb "$stderr_content")
  
  echo "{"
  echo "  \"name\": \"$name\","
  echo "  \"code\": $code,"
  echo "  \"signal\": \"$signal\","
  echo "  \"timedOut\": $timed_out,"
  echo "  \"stdout\": $(printf '%q' "$stdout_content"),"
  echo "  \"stderr\": $(printf '%q' "$stderr_content"),"
  echo "  \"maxRssMb\": $max_rss_mb"
  echo "}"
  
  rm -rf "$tmp_dir"
}

build_import_body() {
  local files=("$@")
  local label="${files[-1]}"
  unset 'files[-1]'
  
  local imports=""
  for file in "${files[@]}"; do
    imports+="await import(\"$file\");"$'\n'
  done
  
  echo "${imports}console.log(\"$label\");process.exit(0);"
}

find_extension_entries() {
  local repo_root="$1"
  local extensions_dir="$repo_root/dist/extensions"
  
  if [ ! -d "$extensions_dir" ]; then
    echo "dist/extensions not found. Run pnpm build first." >&2
    exit 1
  fi
  
  local entries=()
  for dir in "$extensions_dir"/*/; do
    if [ -f "$dir/index.js" ]; then
      entries+=("$(basename "$dir"):$(realpath "$dir/index.js")")
    fi
  done
  
  if [ ${#entries[@]} -eq 0 ]; then
    echo "No built bundled plugin entrypoints found in the dist plugin tree" >&2
    exit 1
  fi
  
  printf '%s\n' "${entries[@]}" | sort
}

main() {
  local extensions=()
  local concurrency=$DEFAULT_CONCURRENCY
  local timeout_ms=$DEFAULT_TIMEOUT_MS
  local combined_timeout_ms=$DEFAULT_COMBINED_TIMEOUT_MS
  local top=$DEFAULT_TOP
  local json_path=""
  local skip_combined=false
  
  parse_args "$@"
  
  local repo_root
  repo_root=$(pwd)
  
  local all_entries
  all_entries=$(find_extension_entries "$repo_root")
  
  local selected_entries=()
  if [ ${#extensions[@]} -eq 0 ]; then
    mapfile -t selected_entries <<< "$all_entries"
  else
    for ext in "${extensions[@]}"; do
      while IFS=: read -r dir file; do
        if [[ " ${extensions[*]} " =~ " $dir " ]]; then
          selected_entries+=("$dir:$file")
        fi
      done <<< "$all_entries"
    done
  fi
  
  # Prüfe auf unbekannte Erweiterungen
  for ext in "${extensions[@]}"; do
    local found=false
    while IFS=: read -r dir _; do
      if [ "$dir" = "$ext" ]; then
        found=true
        break
      fi
    done <<< "$all_entries"
    
    if [ "$found" = false ]; then
      echo "Unknown built extension ids: $ext" >&2
      exit 1
    fi
  done
  
  if [ ${#selected_entries[@]} -eq 0 ]; then
    echo "No extensions selected for profiling" >&2
    exit 1
  fi
  
  local tmp_home
  tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/openclaw-extension-memory-XXXXXX")
  local hook_path="$tmp_home/measure-rss.mjs"
  local json_report_path="${json_path:-${TMPDIR:-/tmp}/openclaw-extension-memory.json}"
  
  cat > "$hook_path" <<'EOF'
process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('__OPENCLAW_MAX_RSS_KB__=' + String(usage.maxRSS));
});
EOF
  
  local env=(
    "HOME=$tmp_home"
    "USERPROFILE=$tmp_home"
    "XDG_CONFIG_HOME=$tmp_home/.config"
    "XDG_DATA_HOME=$tmp_home/.local/share"
    "XDG_CACHE_HOME=$tmp_home/.cache"
    "NODE_DISABLE_COMPILE_CACHE=1"
    "OPENCLAW_NO_RESPAWN=1"
    "TERM=${TERM:-dumb}"
    "LANG=${LANG:-C.UTF-8}"
  )
  
  # Baseline-Messung
  local baseline_result
  baseline_result=$(run_case "$repo_root" "$hook_path" "baseline" "process.exit(0)" "$timeout_ms")
  
  # Kombinierte Messung
  local combined_result=""
  if [ "$skip_combined" = false ]; then
    local combined_files=()
    for entry in "${selected_entries[@]}"; do
      IFS=: read -r _ file <<< "$entry"
      combined_files+=("$file")
    done
    combined_files+=("IMPORTED_ALL")
    local combined_body
    combined_body=$(build_import_body "${combined_files[@]}")
    combined_result=$(run_case "$repo_root" "$hook_path" "combined" "$combined_body" "$combined_timeout_ms")
  fi
  
  # Einzelne Messungen
  local results=()
  local pending=("${selected_entries[@]}")
  
  # Worker-Funktion (simuliert asynchrone Ausführung)
  worker() {
    local worker_id="$1"
    local count=0
    
    while [ $count -lt ${#pending[@]} ]; do
      if [ $((count % concurrency)) -eq $worker_id ]; then
        local entry="${pending[$count]}"
        IFS=: read -r dir file <<< "$entry"
        
        local single_body
        single_body=$(build_import_body "$file" "IMPORTED")
        local result
        result=$(run_case "$repo_root" "$hook_path" "$dir" "$single_body" "$timeout_ms")
        
        # Ergebnis verarbeiten
        local status
        local timed_out
        local code
        local stderr_preview
        local max_rss_mb
        
        eval "$(echo "$result" | jq -r '.timedOut,.code,.stderr' | awk '{print "timed_out=" ($1 == "true" ? "true" : "false") ";code=" $2 ";stderr=\"" $3 "\""}')"
        stderr_preview=$(summarize_stderr "$stderr")
        max_rss_mb=$(parse_max_rss_mb "$stderr")
        
        if [ "$timed_out" = true ]; then
          status="timeout"
        elif [ "$code" -eq 0 ]; then
          status="ok"
        else
          status="fail"
        fi
        
        local delta_from_baseline_mb="null"
        if [ "$max_rss_mb" != "null" ] && [ "$(echo "$baseline_result" | jq -r '.maxRssMb')" != "null" ]; then
          delta_from_baseline_mb=$(echo "scale=3; $max_rss_mb - $(echo "$baseline_result" | jq -r '.maxRssMb')" | bc -l)
        fi
        
        local rss_display
        if [ "$max_rss_mb" = "null" ]; then
          rss_display="n/a"
        else
          rss_display="$(printf "%.1f MB" "$max_rss_mb")"
        fi
        
        echo "[extension-memory] $dir: $status $rss_display"
        
        results+=("{\"dir\":\"$dir\",\"file\":\"$file\",\"status\":\"$status\",\"maxRssMb\":$max_rss_mb,\"deltaFromBaselineMb\":$delta_from_baseline_mb,\"stderrPreview\":\"$(printf '%q' "$stderr_preview")\"}")
      fi
      count=$((count + 1))
    done
  }
  
  # Starte Worker
  local workers=()
  for ((i=0; i<concurrency && i<${#pending[@]}; i++)); do
    worker "$i" &
    workers+=($!)
  done
  
  # Warte auf alle Worker
  for worker_pid in "${workers[@]}"; do
    wait "$worker_pid"
  done
  
  # Sortiere Ergebnisse
  local sorted_results=()
  IFS=$'\n' sorted_results=($(sort <<<"${results[*]}"))
  
  # Top-Ergebnisse
  local top_results=()
  local ok_count=0
  local fail_count=0
  local timeout_count=0
  
  for result in "${sorted_results[@]}"; do
    local status
    status=$(echo "$result" | jq -r '.status')
    
    case "$status" in
      ok) ok_count=$((ok_count + 1)) ;;
      fail) fail_count=$((fail_count + 1)) ;;
      timeout) timeout_count=$((timeout_count + 1)) ;;
    esac
    
    if [ "$status" = "ok" ]; then
      top_results+=("$result")
    fi
  done
  
  # Sortiere nach Delta
  IFS=$'\n' top_results=($(for result in "${top_results[@]}"; do
    echo "$(echo "$result" | jq -r '.deltaFromBaselineMb'),$result"
  done | sort -rn | cut -d',' -f2- | head -n "$top"))
  
  # Bericht erstellen
  local report="{"
  report+="\"generatedAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  report+="\"repoRoot\":\"$repo_root\","
  report+="\"selectedExtensions\":["
  
  local selected_dirs=()
  for entry in "${selected_entries[@]}"; do
    IFS=: read -r dir _ <<< "$entry"
    selected_dirs+=("\"$dir\"")
  done
  report+="$(IFS=,; echo "${selected_dirs[*]}")],"
  
  report+="\"baseline\":{"
  report+="\"status\":\"$(if [ "$(echo "$baseline_result" | jq -r '.timedOut')" = "true" ]; then echo "timeout"; elif [ "$(echo "$baseline_result" | jq -r '.code')" -eq 0 ]; then echo "ok"; else echo "fail"; fi)\","
  report+="\"maxRssMb\":$(echo "$baseline_result" | jq -r '.maxRssMb')"
  report+="},"
  
  if [ -n "$combined_result" ]; then
    report+="\"combined\":{"
    report+="\"status\":\"$(if [ "$(echo "$combined_result" | jq -r '.timedOut')" = "true" ]; then echo "timeout"; elif [ "$(echo "$combined_result" | jq -r '.code')" -eq 0 ]; then echo "ok"; else echo "fail"; fi)\","
    report+="\"maxRssMb\":$(echo "$combined_result" | jq -r '.maxRssMb'),"
    report+="\"stderrPreview\":\"$(printf '%q' "$(summarize_stderr "$(echo "$combined_result" | jq -r '.stderr')" 12)")\""
    report+="},"
  else
    report+="\"combined\":null,"
  fi
  
  report+="\"counts\":{"
  report+="\"totalEntries\":${#selected_entries[@]},"
  report+="\"ok\":$ok_count,"
  report+="\"fail\":$fail_count,"
  report+="\"timeout\":$timeout_count"
  report+="},"
  
  report+="\"options\":{"
  report+="\"concurrency\":$concurrency,"
  report+="\"timeoutMs\":$timeout_ms,"
  report+="\"combinedTimeoutMs\":$combined_timeout_ms,"
  report+="\"skipCombined\":$skip_combined"
  report+="},"
  
  report+="\"topByDeltaMb\":["
  report+="$(IFS=,; echo "${top_results[*]}")],"
  
  report+="\"results\":["
  report+="$(IFS=,; echo "${sorted_results[*]}")]" 
  report+="}"
  
  echo "$report" > "$json_report_path"
  
  echo "[extension-memory] report: $json_report_path"
  echo "$report" | jq '{
    baselineMb: .baseline.maxRssMb,
    combinedMb: .combined.maxRssMb,
    counts: .counts,
    topByDeltaMb: .topByDeltaMb
  }'
  
  # Aufräumen
  rm -rf "$tmp_home"
}

# Fehlerbehandlung
trap 'rm -rf "${tmp_home:-}"' EXIT

# Hauptprogramm aufrufen
main "$@"
