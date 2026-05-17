# Web Search Scripts für Automation & Serverwartung

**Verwendung:** Shell-Scripts, Cron-Jobs, CI/CD, Serverwartung  
**Keine OpenClaw-Abhängigkeit:** Direkte API-Nutzung

---

## Quick Reference

```bash
# 1. Firecrawl - Website crawlen und speichern
./scripts/crawl-website.sh https://example.com ./backups/

# 2. EXA - Schnelle Recherche für Monitoring-Alerts
./scripts/research-alert.sh "CVE-2025-1234 vulnerability"

# 3. Tavily CLI - Dokumentation aktualisieren
./scripts/update-docs.sh "Kubernetes 1.32 release notes"

# 4. Perplexity - Technische Analysen (via curl)
./scripts/tech-analysis.sh "Log4j vulnerability impact"

# 5. SearXNG - Lokale Suche (kein externes API)
./scripts/local-search.sh "internal wiki documentation"
```

---

## 1. Firecrawl Scripts

### Website-Backup
```bash
#!/bin/bash
# scripts/crawl-website.sh
WEBSITE_URL="$1"
OUTPUT_DIR="${2:-./crawled}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-$(grep FIRECRAWL ~/.openclaw/openclaw.env | cut -d'"' -f2)}"

echo "Crawling $WEBSITE_URL..."
curl -X POST https://api.firecrawl.dev/v1/crawl \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"$WEBSITE_URL\",
    \"limit\": 100,
    \"scrapeOptions\": {
      \"formats\": [\"markdown\"]
    }
  }" | jq -r '.id' > /tmp/crawl_id.txt

CRAWL_ID=$(cat /tmp/crawl_id.txt)
echo "Crawl ID: $CRAWL_ID"

# Status prüfen und warten
while true; do
  STATUS=$(curl -s https://api.firecrawl.dev/v1/crawl/$CRAWL_ID \
    -H "Authorization: Bearer $FIRECRAWL_API_KEY" | jq -r '.status')
  echo "Status: $STATUS"
  [ "$STATUS" = "completed" ] && break
  sleep 5
done

# Ergebnisse speichern
curl -s https://api.firecrawl.dev/v1/crawl/$CRAWL_ID \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  > "$OUTPUT_DIR/$(date +%Y%m%d)_crawl.json"

echo "Gespeichert in $OUTPUT_DIR"
```

### Downtime-Monitoring
```bash
#!/bin/bash
# scripts/check-website.sh
URL="$1"
OUTPUT=$(curl -s -X POST https://api.firecrawl.dev/v1/scrape \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -d "{\"url\": \"$URL\", \"formats\": [\"html\"]}")

if echo "$OUTPUT" | jq -e '.data.html' > /dev/null; then
  echo "✅ $URL erreichbar"
  exit 0
else
  echo "❌ $URL NICHT erreichbar"
  echo "$OUTPUT" | jq '.error'
  exit 1
fi
```

---

## 2. EXA Scripts

### Security-Alert Recherche
```bash
#!/bin/bash
# scripts/research-alert.sh
QUERY="$1"
EXA_API_KEY="${EXA_API_KEY:-$OPENROUTER_API_KEY}"

echo "Recherche: $QUERY"
curl -s -X POST https://api.exa.ai/search \
  -H "Authorization: Bearer $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"$QUERY\",
    \"type\": \"auto\",
    \"useAutoprompt\": true,
    \"numResults\": 5,
    \"contents\": {
      \"text\": true,
      \"highlights\": true
    }
  }" | jq -r '.results[] | \"\(.title)\n\(.url)\n---\"'
```

### Konkurrenz-Analyse
```bash
#!/bin/bash
# scripts/competitor-watch.sh
DOMAIN="$1"
curl -s -X POST https://api.exa.ai/findSimilar \
  -H "Authorization: Bearer $EXA_API_KEY" \
  -d "{
    \"url\": \"https://$DOMAIN\",
    \"numResults\": 10,
    \"excludeDomains\": [\"$DOMAIN\"]
  }" | jq -r '.results[].url' > "competitors_${DOMAIN}.txt"
```

---

## 3. Tavily CLI Scripts

### Dokumentation Auto-Update
```bash
#!/bin/bash
# scripts/update-docs.sh
TOPIC="$1"
DOCS_DIR="${2:-./docs}"

echo "Update Docs für: $TOPIC"
tvly research "$TOPIC" --model pro -o "$DOCS_DIR/$(date +%Y%m%d)_${TOPIC// /_}.md"
git -C "$DOCS_DIR" add . && git commit -m "Auto-update: $TOPIC"
```

### Server-News Monitoring
```bash
#!/bin/bash
# scripts/server-news.sh
# Cron-Job: 0 9 * * * /path/to/scripts/server-news.sh

tvly search "Linux kernel security updates" \
  --topic news \
  --time-range week \
  --max-results 10 \
  --include-answer advanced \
  --json | jq -r '.answer' | mail -s "Weekly Server News" admin@example.com
```

### Wissensdatenbank aktualisieren
```bash
#!/bin/bash
# scripts/kb-update.sh
# Crawlt interne Wiki-Seiten und indiziert sie

URLS=$(tvly map "https://wiki.intern.example.com" --json | jq -r '.urls[]')

for URL in $URLS; do
  tvly extract "$URL" --json >> /var/lib/knowledgebase/raw/$(date +%s).json
done

# Indizierung (z.B. für Elasticsearch)
python3 /opt/scripts/index_kb.py /var/lib/knowledgebase/raw/
```

---

## 4. Perplexity Scripts (via OpenRouter)

### Root-Cause-Analysis
```bash
#!/bin/bash
# scripts/analyze-incident.sh
INCIDENT_DESC="$1"
OPENROUTER_KEY="${OPENROUTER_API_KEY}"

echo "Analysiere: $INCIDENT_DESC"
curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"perplexity/sonar-deep-research\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": \"Root cause analysis for: $INCIDENT_DESC. List similar incidents, best practices, and mitigation strategies.\"
    }]
  }" | jq -r '.choices[0].message.content' > "incident_$(date +%Y%m%d_%H%M).md"
```

### Technische Spezifikation prüfen
```bash
#!/bin/bash
# scripts/verify-spec.sh
TECH="$1"
REQUIREMENT="$2"

curl -s -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_KEY" \
  -d "{
    \"model\": \"perplexity/sonar\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": \"Does $TECH meet requirements: $REQUIREMENT? Provide sources.\"
    }]
  }" | jq -r '.choices[0].message.annotations[] | \"Source: \(.url_citation.url)\"'
```

---

## 5. SearXNG Scripts (lokal)

### Interne Suche
```bash
#!/bin/bash
# scripts/internal-search.sh
QUERY="$1"
SEARXNG_URL="http://localhost:8888"

curl -s "${SEARXNG_URL}/search?q=${QUERY// /+}&format=json" \
  | jq -r '.results[] | "\(.title)\n\(.url)\"'
```

### Compliance-Check (keine externen APIs)
```bash
#!/bin/bash
# scripts/compliance-check.sh
# Prüft nur interne Dokumentation, keine externen Anfragen

QUERY="$1"
./scripts/internal-search.sh "$QUERY" > /tmp/internal_results.txt

if [ -s /tmp/internal_results.txt ]; then
  echo "✅ Dokumentation gefunden"
else
  echo "⚠️ Keine interne Dokumentation - manuelle Prüfung nötig"
fi
```

---

## Cron-Job Beispiele

```bash
# /etc/cron.d/websearch-scripts

# Tägliche Website-Backups
0 2 * * * openclaw /home/openclaw/.openclaw/workspace/SCRIPTS/crawl-website.sh https://docs.example.com /backups/docs/

# Weekly Security-News
0 9 * * 1 openclaw /home/openclaw/.openclaw/workspace/SCRIPTS/server-news.sh

# Stündliche Downtime-Checks
*/5 * * * * openclaw /home/openclaw/.openclaw/workspace/SCRIPTS/check-website.sh https://critical-service.example.com || echo "ALERT" | wall
```

---

## Environment Setup

```bash
# ~/.profile oder /etc/environment

# API-Keys
export OPENROUTER_API_KEY=""
export TAVILY_API_KEY=""
export FIRECRAWL_API_KEY=""

# Pfade
export PATH="$PATH:/home/openclaw/.local/bin"  # für tvly, mcporter
export OPENCLAW_SCRIPTS="/home/openclaw/.openclaw/workspace/SCRIPTS"
```

---

## Fehlerbehandlung

```bash
# Wrapper mit Retry-Logik
function search_with_retry() {
  local cmd="$1"
  local retries=3
  local delay=5
  
  for i in $(seq 1 $retries); do
    if eval "$cmd"; then
      return 0
    fi
    echo "Retry $i/$retries..."
    sleep $delay
  done
  
  echo "FAILED: $cmd" >&2
  return 1
}

# Nutzung:
search_with_retry "tvly search 'test' --max-results 1"
```

---

**Stand:** 2026-04-18  
**Pfad:** `~/workspace/SCRIPTS/`
