#!/bin/bash
# Web Search Script: Deep Research für Incidents
# Verwendung: ./websearch-research.sh "Beschreibung des Problems"

QUERY="$1"
OUTPUT_DIR="${2:-./research}"

if [ -z "$QUERY" ]; then
  echo "Verwendung: $0 \"Problem Beschreibung\" [OUTPUT_DIR]"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/incident_$(date +%Y%m%d_%H%M%S).md"

echo "# Incident Research" > "$OUTPUT_FILE"
echo "Datum: $(date)" >> "$OUTPUT_FILE"
echo "Query: $QUERY" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 1. EXA für schnelle Recherche
echo "## 1. Schnelle Recherche (EXA)" >> "$OUTPUT_FILE"
curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"openai/gpt-4.1\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$QUERY\"}],
    \"plugins\": [{\"id\": \"web\", \"engine\": \"exa\", \"max_results\": 5}]
  }" 2>/dev/null | jq -r '.choices[0].message.content // "Keine Ergebnisse"' >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"

# 2. Verifizierte Quellen (Perplexity) falls verfügbar
echo "## 2. Verifizierte Fakten (Perplexity)" >> "$OUTPUT_FILE"
curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -d "{
    \"model\": \"perplexity/sonar:online\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$QUERY troubleshooting\"}]
  }" 2>/dev/null | jq -r '.choices[0].message.content // "Keine Ergebnisse"' >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "Gespeichert in: $OUTPUT_FILE"
