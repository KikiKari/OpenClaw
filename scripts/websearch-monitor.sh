#!/bin/bash
# Web Search Script: Server-Monitoring mit Tavily
# Verwendung: ./websearch-monitor.sh [TOPIC]

TOPIC="${1:-"Linux kernel security updates"}"

# Security-News prüfen
echo "Prüfe: $TOPIC"

# Versuche zuerst Tavily CLI
if command -v tvly &> /dev/null; then
  tvly search "$TOPIC" \
    --topic news \
    --time-range week \
    --max-results 5 \
    --include-answer advanced 2>/dev/null | jq -r '.answer // "Keine Zusammenfassung verfügbar"'
else
  # Fallback zu einfacher Web-Suche
  curl -s "http://localhost:8888/search?q=${TOPIC// /+}&format=json" 2>/dev/null | \
    jq -r '.results[:3] | .[] | "\(.title)\n\(.url)"' || \
    echo "SearXNG nicht verfügbar"
fi
