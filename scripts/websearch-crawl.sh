#!/bin/bash
# Web Search Script: Website Crawling mit Firecrawl
# Verwendung: ./websearch-crawl.sh <URL> [OUTPUT_DIR]

WEBSITE_URL="$1"
OUTPUT_DIR="${2:-./crawled}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-$(grep OPENROUTER ~/.openclaw/openclaw.env 2>/dev/null | cut -d'"' -f2)}"

if [ -z "$WEBSITE_URL" ]; then
  echo "Verwendung: $0 <URL> [OUTPUT_DIR]"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo "Crawling $WEBSITE_URL..."

# Crawl starten
CRAWL_RESPONSE=$(curl -s -X POST https://api.firecrawl.dev/v1/crawl \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"$WEBSITE_URL\",
    \"limit\": 100,
    \"scrapeOptions\": {\"formats\": [\"markdown\"]}
  }")

CRAWL_ID=$(echo "$CRAWL_RESPONSE" | jq -r '.id // empty')
if [ -z "$CRAWL_ID" ]; then
  echo "Fehler: Crawl konnte nicht gestartet werden"
  echo "$CRAWL_RESPONSE" | jq '.'
  exit 1
fi

echo "Crawl ID: $CRAWL_ID"

# Status prüfen
while true; do
  STATUS_RESPONSE=$(curl -s "https://api.firecrawl.dev/v1/crawl/$CRAWL_ID" \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY")
  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"')
  echo "Status: $STATUS"
  
  if [ "$STATUS" = "completed" ]; then
    echo "$STATUS_RESPONSE" > "$OUTPUT_DIR/$(date +%Y%m%d)_crawl.json"
    echo "Gespeichert in $OUTPUT_DIR"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "Crawl fehlgeschlagen"
    exit 1
  fi
  sleep 5
done
