#!/usr/bin/env bash
set -euo pipefail

: "${PERPLEXITY_API_KEY:?PERPLEXITY_API_KEY is required}"

out="${TMPDIR:-/tmp}/perplexity-embeddings-test.json"

payload="$(
  jq -nc '{
    input: [
      "Scientists explore the universe driven by curiosity.",
      "Curiosity compels us to seek explanations, not just observations.",
      "Historical discoveries began with curious questions.",
      "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
      "Philosophy examines the nature of curiosity."
    ],
    model: "pplx-embed-v1-4b"
  }'
)"

code="$(
  curl -sS -o "$out" -w '%{http_code}' \
    -X POST 'https://api.perplexity.ai/v1/embeddings' \
    -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$payload"
)"

echo "embeddings_http=${code}"
jq '{keys: keys, model:(.model // null), item_count:((.data // []) | length), first_dim:(((.data // [])[0].embedding // []) | length), error:(.error // null)}' "$out"
