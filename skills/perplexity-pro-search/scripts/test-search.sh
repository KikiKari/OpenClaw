#!/usr/bin/env bash
set -euo pipefail

: "${PERPLEXITY_API_KEY:?PERPLEXITY_API_KEY is required}"

query="${1:-Perplexity API Platform}"
max_results="${PERPLEXITY_MAX_RESULTS:-3}"
max_tokens_per_page="${PERPLEXITY_MAX_TOKENS_PER_PAGE:-256}"
out="${TMPDIR:-/tmp}/perplexity-search-test.json"

code="$(
  curl -sS -o "$out" -w '%{http_code}' \
    -X POST 'https://api.perplexity.ai/search' \
    -H "Authorization: Bearer ${PERPLEXITY_API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc \
      --arg query "$query" \
      --argjson max_results "$max_results" \
      --argjson max_tokens_per_page "$max_tokens_per_page" \
      '{query:$query,max_results:$max_results,max_tokens_per_page:$max_tokens_per_page}')"
)"

echo "search_http=${code}"
jq '{keys: keys, result_count: ((.results // .data // []) | length), first: ((.results // .data // [])[0] // null)}' "$out"
