#!/usr/bin/env bash
# Bounded fallback used by the enhanced extractor. Output is normalized again
# by tiktok-get-stream.js; standalone success must remain URL-only unless
# --json is requested. Exit 75 means preflight overload.
set -u

USERNAME="${1#@}"
QUALITY="${2:-best}"
JSON_FLAG="${3:-}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

emit_json() {
    python3 - "$@" <<'PY'
import json
import sys
keys = ("success", "method", "username", "url", "quality", "author", "title", "error", "timestamp", "status")
values = sys.argv[1:]
payload = {key: value for key, value in zip(keys, values) if value != ""}
if "success" in payload:
    payload["success"] = payload["success"].lower() == "true"
print(json.dumps(payload, ensure_ascii=False))
PY
}

if [[ ! "$USERNAME" =~ ^[A-Za-z0-9._]{1,24}$ ]]; then
    echo "Invalid TikTok username" >&2
    exit 64
fi
if [[ ! "$QUALITY" =~ ^(best|worst|ld|sd|hd|origin|auto|[0-9]+p)$ ]]; then
    echo "Invalid stream quality" >&2
    exit 64
fi

LOAD_PER_CPU=$(python3 -c 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))')
MAX_LOAD="${TIKTOK_MAX_LOAD_PER_CPU:-1.5}"
if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)' "$LOAD_PER_CPU" "$MAX_LOAD"; then
    emit_json "false" "streamlink" "$USERNAME" "" "$QUALITY" "" "" \
        "host overloaded" "$TIMESTAMP" "overloaded" >&2
    exit 75
fi

if ! command -v streamlink >/dev/null 2>&1; then
    emit_json "false" "streamlink" "$USERNAME" "" "$QUALITY" "" "" \
        "streamlink not installed" "$TIMESTAMP" "dependency_missing" >&2
    exit 2
fi

LIVE_URL="https://www.tiktok.com/@${USERNAME}/live"
OUTPUT=$(streamlink --json "$LIVE_URL" "$QUALITY" 2>/dev/null)
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ] || [ -z "$OUTPUT" ]; then
    URL=$(streamlink --stream-url "$LIVE_URL" "$QUALITY" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$URL" ]; then
        emit_json "false" "streamlink" "$USERNAME" "" "$QUALITY" "" "" \
            "streamlink failed or no stream found" "$TIMESTAMP" "offline" >&2
        exit 1
    fi
    if [ "$JSON_FLAG" = "--json" ]; then
        emit_json "true" "streamlink" "$USERNAME" "$URL" "$QUALITY" "" "" "" "$TIMESTAMP" "live"
    else
        printf '%s\n' "$URL"
    fi
    exit 0
fi

PARSED=$(python3 -c '
import json, sys
data = json.load(sys.stdin)
url = data.get("url", "")
streams = data.get("streams", {})
if not url and isinstance(streams, dict):
    for key in ("best", "worst", *streams.keys()):
        value = streams.get(key)
        if isinstance(value, dict) and value.get("url"):
            url = value["url"]
            break
metadata = data.get("metadata", {})
print(json.dumps({"url": url, "author": metadata.get("author", ""), "title": metadata.get("title", "")}))
' <<<"$OUTPUT" 2>/dev/null)
if [ $? -ne 0 ]; then
    emit_json "false" "streamlink" "$USERNAME" "" "$QUALITY" "" "" \
        "invalid streamlink JSON" "$TIMESTAMP" "technical_error" >&2
    exit 2
fi

readarray -t FIELDS < <(python3 -c '
import json, sys
d=json.load(sys.stdin)
print(d.get("url",""))
print(d.get("author",""))
print(d.get("title",""))
' <<<"$PARSED")
URL="${FIELDS[0]:-}"
AUTHOR="${FIELDS[1]:-}"
TITLE="${FIELDS[2]:-}"
if [ -z "$URL" ]; then
    emit_json "false" "streamlink" "$USERNAME" "" "$QUALITY" "$AUTHOR" "$TITLE" \
        "could not extract stream URL" "$TIMESTAMP" "offline" >&2
    exit 1
fi
if [ "$JSON_FLAG" = "--json" ]; then
    emit_json "true" "streamlink" "$USERNAME" "$URL" "$QUALITY" "$AUTHOR" "$TITLE" "" "$TIMESTAMP" "live"
else
    printf '%s\n' "$URL"
fi
