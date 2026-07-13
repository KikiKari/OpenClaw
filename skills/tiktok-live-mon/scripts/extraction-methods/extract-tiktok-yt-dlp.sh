#!/usr/bin/env bash
# Bounded fallback used by the enhanced extractor. Temporary files are cleaned
# on every exit and output is normalized again by tiktok-get-stream.js.
# Standalone overload exits 75 before yt-dlp starts.
set -u

USERNAME="${1#@}"
FORMAT="${2:-best}"
JSON_FLAG="${3:-}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP_DIR=$(mktemp -d /tmp/tiktok-yt-dlp.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

emit_json() {
    python3 - "$@" <<'PY'
import json
import sys
keys = ("success", "method", "username", "url", "format", "error", "timestamp", "status")
payload = {k: v for k, v in zip(keys, sys.argv[1:]) if v != ""}
if "success" in payload:
    payload["success"] = payload["success"].lower() == "true"
print(json.dumps(payload, ensure_ascii=False))
PY
}

if [[ ! "$USERNAME" =~ ^[A-Za-z0-9._]{1,24}$ ]]; then
    echo "Invalid TikTok username" >&2
    exit 64
fi
case "$FORMAT" in
    hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld|\
    hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld|\
    hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld|\
    hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld|\
    hls-sd/hls-ld/flv-sd/flv-ld|hls-ld/flv-ld|\
    hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld) ;;
    *)
    echo "Invalid yt-dlp format" >&2
    exit 64
    ;;
esac

LOAD_PER_CPU=$(python3 -c 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))')
MAX_LOAD="${TIKTOK_MAX_LOAD_PER_CPU:-1.5}"
if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)' "$LOAD_PER_CPU" "$MAX_LOAD"; then
    emit_json "false" "yt-dlp" "$USERNAME" "" "$FORMAT" "host overloaded" "$TIMESTAMP" "overloaded" >&2
    exit 75
fi
if ! command -v yt-dlp >/dev/null 2>&1; then
    emit_json "false" "yt-dlp" "$USERNAME" "" "$FORMAT" "yt-dlp not installed" "$TIMESTAMP" "dependency_missing" >&2
    exit 2
fi

LIVE_URL="https://www.tiktok.com/@${USERNAME}/live"
yt-dlp --no-warnings --dump-single-json --skip-download --format "$FORMAT" "$LIVE_URL" \
    >"$TMP_DIR/stdout.json" 2>"$TMP_DIR/stderr.log"
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then
    if grep -Eqi 'not currently live|No live cdn found|not available|private video' "$TMP_DIR/stderr.log"; then
        STATUS=offline
        CODE=1
    else
        STATUS=technical_error
        CODE=2
    fi
    emit_json "false" "yt-dlp" "$USERNAME" "" "$FORMAT" \
        "$(head -c 1000 "$TMP_DIR/stderr.log")" "$TIMESTAMP" "$STATUS" >&2
    exit "$CODE"
fi

URL=$(python3 -c '
import json, sys
d=json.load(sys.stdin)
candidates=[]
if isinstance(d.get("url"), str):
    candidates.append(d["url"])
for item in d.get("formats", []) or []:
    if isinstance(item, dict) and isinstance(item.get("url"), str):
        candidates.append(item["url"])
for value in candidates:
    low = value.lower()
    if value.startswith("https://") and (".m3u8" in low or ".flv" in low) and "only_audio=1" not in low:
        print(value)
        break
' <"$TMP_DIR/stdout.json" 2>/dev/null)
if [ -z "$URL" ]; then
    emit_json "false" "yt-dlp" "$USERNAME" "" "$FORMAT" \
        "could not extract HTTPS video URL" "$TIMESTAMP" "offline" >&2
    exit 1
fi
if [ "$JSON_FLAG" = "--json" ]; then
    emit_json "true" "yt-dlp" "$USERNAME" "$URL" "$FORMAT" "" "$TIMESTAMP" "live"
else
    printf '%s\n' "$URL"
fi
