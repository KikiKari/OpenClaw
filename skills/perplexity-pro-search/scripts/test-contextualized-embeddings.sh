#!/usr/bin/env bash
set -euo pipefail

: "${PERPLEXITY_API_KEY:?PERPLEXITY_API_KEY is required}"

out="${TMPDIR:-/tmp}/perplexity-contextualized-embeddings-test.json"

payload="$(
  jq -nc '{
    input: [[
      "OpenClaw can route web search through Perplexity.",
      "The Perplexity MCP server exposes search and reasoning tools.",
      "Contextualized embeddings improve document chunk retrieval."
    ]],
    model: "pplx-embed-context-v1-4b"
  }'
)"

code="$(
  curl -sS -o "$out" -w "%{http_code}" \
    -X POST "https://api.perplexity.ai/v1/contextualizedembeddings" \
    -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload"
)"

echo "contextualized_embeddings_http=${code}"
jq '{keys: keys, model:(.model // null), document_count:((.data // []) | length), first_chunk_count:(((.data // [])[0].data // []) | length), error:(.error // null)}' "$out"
