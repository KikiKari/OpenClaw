#!/usr/bin/env bash
set -euo pipefail

: "${PERPLEXITY_API_KEY:?PERPLEXITY_API_KEY is required}"

prompt="${1:-Compare recent open-source LLMs in terms of performance, licensing, and practical use.}"
out="${TMPDIR:-/tmp}/perplexity-agent-test.json"

code="$(
  curl -sS -o "$out" -w '%{http_code}' \
    https://api.perplexity.ai/v1/agent \
    -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg input "$prompt" '{preset:"fast-search",input:$input}')"
)"

echo "agent_http=${code}"
jq '{keys: keys, id:(.id // null), status:(.status // null), output_count:((.output // []) | length), error:(.error // null)}' "$out"
