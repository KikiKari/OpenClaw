#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "645b8106da044e2527a99180996a0bff63a250f0739f16e05b6e7ce3cbe84856", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "shell"}
# check-cli-startup-memory.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Plattform prüfen
if [[ "$(uname)" != "Linux" && "$(uname)" != "Darwin" ]]; then
  echo "[startup-memory] Skipping on unsupported platform: $(uname)"
  exit 0
fi

# Temporäres Verzeichnis erstellen
tmp_home=$(mktemp -d "${TMPDIR:-/tmp}/openclaw-startup-memory-XXXXXX")
trap 'rm -rf "$tmp_home"' EXIT

# RSS Hook Skript erstellen
rss_hook_path="$tmp_home/measure-rss.mjs"
cat >"$rss_hook_path" <<'EOF'
process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('__OPENCLAW_MAX_RSS_KB__=' + String(usage.maxRSS));
});
EOF

# Maximale RSS Markierung
MAX_RSS_MARKER="__OPENCLAW_MAX_RSS_KB__="

# Standardlimits in MB
declare -A DEFAULT_LIMITS_MB=(
  [help]=100
  [statusJson]=400
  [gatewayStatus]=500
)

# Limits aus Umgebungsvariablen laden oder Standardwerte verwenden
LIMIT_HELP=${OPENCLAW_STARTUP_MEMORY_HELP_MB:-${DEFAULT_LIMITS_MB[help]}}
LIMIT_STATUS_JSON=${OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB:-${DEFAULT_LIMITS_MB[statusJson]}}
LIMIT_GATEWAY_STATUS=${OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB:-${DEFAULT_LIMITS_MB[gatewayStatus]}}

# Testfälle definieren
test_cases=(
  "help|--help|$LIMIT_HELP"
  "statusJson|status --json|$LIMIT_STATUS_JSON"
  "gatewayStatus|gateway status|$LIMIT_GATEWAY_STATUS"
)

# Funktion zur Formatierung der Fehlerbehebungsanleitung
format_fix_guidance() {
  local case_label="$1"
  local command_args="$2"
  local details="$3"

  local command="node $command_args"
  cat <<EOF
[startup-memory] Fix guidance
Case: $case_label
Command: $command
Next steps:
1. Run \`$command\` locally on the built tree.
2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path.
3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory.
LLM prompt:
"OpenClaw startup-memory CI failed for '$case_label'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:
$details"
EOF
}

# Funktion zur Formatierung von Fehlernachrichten
format_failure() {
  local case_label="$1"
  local message="$2"
  local details="${3:-}"

  echo "$message"
  if [[ -n "$details" ]]; then
    echo "$details"
  fi
  format_fix_guidance "$case_label" "openclaw.mjs $case_label" "$details"
}

# Funktion zum Parsen der maximalen RSS in MB
parse_max_rss_mb() {
  local stderr="$1"
  local regex="^${MAX_RSS_MARKER}([0-9]+)[[:space:]]*$"
  local kb_value=""

  while IFS= read -r line; do
    if [[ $line =~ $regex ]]; then
      kb_value="${BASH_REMATCH[1]}"
    fi
  done <<< "$stderr"

  if [[ -n "$kb_value" ]]; then
    echo "scale=3; $kb_value / 1024" | bc -l
  else
    echo ""
  fi
}

# Funktion zum Erstellen der Benchmark-Umgebung
build_bench_env() {
  export HOME="$tmp_home"
  export USERPROFILE="$tmp_home"
  export XDG_CONFIG_HOME="$tmp_home/.config"
  export XDG_DATA_HOME="$tmp_home/.local/share"
  export XDG_CACHE_HOME="$tmp_home/.cache"
  export TMPDIR="${TMPDIR:-/tmp}"
  export TEMP="${TEMP:-$TMPDIR}"
  export TMP="${TMP:-$TMPDIR}"
  export LANG="${LANG:-C.UTF-8}"
  export TERM="${TERM:-dumb}"
  
  # Optional: LC_ALL, CI, NODE_DISABLE_COMPILE_CACHE
  if [[ -n "${LC_ALL:-}" ]]; then
    export LC_ALL="$LC_ALL"
  fi
  if [[ -n "${CI:-}" ]]; then
    export CI="$CI"
  fi
  if [[ -n "${NODE_DISABLE_COMPILE_CACHE:-}" ]]; then
    export NODE_DISABLE_COMPILE_CACHE="$NODE_DISABLE_COMPILE_CACHE"
  else
    export NODE_DISABLE_COMPILE_CACHE="1"
  fi
  
  # Keep the benchmark on a single process
  export OPENCLAW_NO_RESPAWN="1"
}

# Funktion zum Ausführen eines Testfalls
run_case() {
  local case_id="$1"
  local label="$2"
  local args="$3"
  local limit_mb="$4"

  # Umgebungsvariablen setzen
  build_bench_env

  # Befehl ausführen
  local full_command="node --import \"$rss_hook_path\" openclaw.mjs $args"
  local output_file="$tmp_home/output.txt"
  local error_file="$tmp_home/error.txt"

  if eval "$full_command" >"$output_file" 2>"$error_file"; then
    local exit_code=0
  else
    local exit_code=$?
  fi

  local stdout_content=""
  local stderr_content=""

  if [[ -f "$output_file" ]]; then
    stdout_content=$(<"$output_file")
  fi

  if [[ -f "$error_file" ]]; then
    stderr_content=$(<"$error_file")
  fi

  local combined_output="$stderr_content"
  if [[ -n "$stdout_content" ]]; then
    combined_output="$combined_output"$'\n'"$stdout_content"
  fi

  # Prüfung auf Exit-Code
  if [[ $exit_code -ne 0 ]]; then
    format_failure "$label" "$label exited with $exit_code" "$combined_output"
    return 1
  fi

  # Maximale RSS parsen
  local max_rss_mb
  max_rss_mb=$(parse_max_rss_mb "$stderr_content")

  if [[ -z "$max_rss_mb" ]]; then
    format_failure "$label" "$label did not report max RSS" "$stderr_content"
    return 1
  fi

  # Prüfung auf Matrix Bootstrap Warnung
  if grep -qi "matrix: crypto runtime bootstrap failed" <<< "$stderr_content"; then
    format_failure "$label" "$label triggered Matrix crypto bootstrap during startup"
    return 1
  fi

  # RSS-Limit prüfen
  local comparison_result
  comparison_result=$(echo "$max_rss_mb > $limit_mb" | bc -l)

  if [[ "$comparison_result" -eq 1 ]]; then
    format_failure "$label" "$label used $max_rss_mb MB RSS (limit $limit_mb MB)"
    return 1
  fi

  printf "[startup-memory] %s: %.1f MB RSS (limit %s MB)\n" "$label" "$max_rss_mb" "$limit_mb"
}

# Hauptausführung
repo_root=$(pwd)
cd "$repo_root" || exit 1

for test_case in "${test_cases[@]}"; do
  IFS='|' read -r case_id label args limit_mb <<< "$test_case"
  if ! run_case "$case_id" "$label" "$args" "$limit_mb"; then
    exit 1
  fi
done
