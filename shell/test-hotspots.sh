#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "52fc37cfe2d52fd570bab65c2173ee8b440975587697afe28e799daec010c3ab", "source_sha256": "4252ea2457fcacdde20bb203479a1fcfbb9fa70ecf111838b7f2ac7c0902a093", "target_language": "shell"}
# test-hotspots.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-hotspots.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Funktionen zur Formatierung und Hilfsausgabe
format_ms() {
  local ms=$1
  if (( ms >= 60000 )); then
    printf "%dm%ds" $((ms / 60000)) $(((ms % 60000) / 1000))
  elif (( ms >= 1000 )); then
    printf "%ds" $((ms / 1000))
  else
    printf "%dms" "$ms"
  fi
}

show_help() {
  cat <<EOF
Usage: $0 [options]

Print the slowest test files from a Vitest JSON report.

Options:
  --config <path>    Vitest config to run when no report is supplied
  --report <path>    Reuse an existing Vitest JSON report
  --limit <count>    Number of files to print (default: 20)
  --help             Show this help text

Examples:
  $0
  $0 --config test/vitest/vitest.channels.config.ts --limit 10
  $0 --report /tmp/vitest-report.json
EOF
  exit 0
}

# Standardoptionen
CONFIG="test/vitest/vitest.unit.config.ts"
REPORT=""
LIMIT=20

# Argumente parsen
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      ;;
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --report)
      REPORT="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# Wenn kein Report angegeben ist, fuehre vitest aus und generiere einen
if [[ -z "$REPORT" ]]; then
  REPORT_FILE=$(mktemp)
  trap 'rm -f "$REPORT_FILE"' EXIT
  npx vitest --config "$CONFIG" --reporter=json >"$REPORT_FILE"
  REPORT="$REPORT_FILE"
fi

# Extrahiere Datei-Dauer und Testanzahl aus dem JSON-Report
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Konvertiere das JSON in ein flaches Format fuer die Verarbeitung
jq -r '.testResults[] | "\(.file) \(.endTime - .startTime) \(.assertionResults | length)"' "$REPORT" >"$TMP_DIR/durations.txt"

# Sortiere nach Dauer absteigend
sort -k2 -n -r "$TMP_DIR/durations.txt" >"$TMP_DIR/sorted.txt"

# Hole die Top-Einträge
TOP_FILE="$TMP_DIR/top.txt"
head -n "$LIMIT" "$TMP_DIR/sorted.txt" >"$TOP_FILE"

# Berechne Gesamtdauer
TOTAL_DURATION_MS=$(awk '{sum += $2} END {print int(sum)}' "$TMP_DIR/sorted.txt")

# Ausgabe
echo
echo "[test-hotspots] top $(wc -l <"$TOP_FILE" | tr -d ' ') by file duration ($(format_ms "$TOTAL_DURATION_MS") total)"

INDEX=1
while IFS=' ' read -r FILE DURATION TEST_COUNT; do
  LABEL=$(printf "%2d" "$INDEX")
  DURATION_STR=$(format_ms "$DURATION")
  DURATION_PADDED=$(printf "%10s" "$DURATION_STR")
  TESTS_PADDED=$(printf "%4s" "$TEST_COUNT")
  echo "$LABEL. $DURATION_PADDED | tests=$TESTS_PADDED | $FILE"
  ((INDEX++))
done <"$TOP_FILE"
