# Web Search & MCP Service Guide

**Version:** 2026-04-18  
**Gültig für:** OpenClaw Gateway + alle verbundene Nodes

---

## Übersicht: Suchanbieter-Stack

```
┌─────────────────────────────────────────────────────────────┐
│  ANWENDUNGSEBENE (Skills, Scripts, CLI)                    │
├─────────────────────────────────────────────────────────────┤
│  1. OpenClaw Plugin (tavily)        ← Boardmittel          │
│     Tools: tavily_search, tavily_extract                   │
├─────────────────────────────────────────────────────────────┤
│  2. mcporter (global MCP Client)    ← Für MCP-fähige Tools │
│     Befehl: mcporter call tavily.tavily_search             │
├─────────────────────────────────────────────────────────────┤
│  3. Claude Code (MCP Client)        ← Alternative UI       │
│     Befehl: /mcp oder direkte Tool-Nutzung                 │
├─────────────────────────────────────────────────────────────┤
│  4. Tavily CLI (tvly)               ← Direkte API-Nutzung  │
│     Befehl: tvly search "query"                            │
├─────────────────────────────────────────────────────────────┤
│  SERVICE-EBENE (MCP-Server)                                │
├─────────────────────────────────────────────────────────────┤
│  • Tavily MCP-Server (HTTP)                                │
│    URL: https://mcp.tavily.com/mcp/?tavilyApiKey=...       │
│    Status: ✅ OpenClaw, mcporter, Claude Code              │
├─────────────────────────────────────────────────────────────┤
│  PROVIDER-EBENE (Web-Search Engines)                       │
├─────────────────────────────────────────────────────────────┤
│  1. Firecrawl  → Crawling + Markdown (OpenRouter)          │
│  2. EXA        → Recherche + Quellenfindung (OpenRouter)   │
│  3. Tavily     → KI-Agenten-Forschung (Plugin/MCP)         │
│  4. Perplexity → Präzise Recherche (OpenRouter)            │
│  5. SearXNG    → Selbstgehosteter Fallback                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Prioritätsreihenfolge (Empfohlen)

| Priorität | Provider | Wann nutzen? | Methode |
|-----------|----------|--------------|---------|
| 1 | **Firecrawl** | Vollständige Website-Crawling, Markdown-Extraktion | OpenRouter `engine: "firecrawl"` |
| 2 | **EXA** | Schnelle Recherche, relevanteste Quellen finden | OpenRouter `engine: "exa"` |
| 3 | **Tavily** | Tiefgehende KI-Forschung, strukturierte Daten | OpenClaw Plugin / MCP |
| 4 | **Perplexity** | Verifizierte Informationen, Zitationsketten | OpenRouter `:online` |
| 5 | **SearXNG** | Fallback, datenschutzkritische Szenarien | Lokal |

---

## Anbieter-Details

### 1. Firecrawl (OpenRouter)

**Verwendung:**
```json
{
  "model": "openai/gpt-4.1",
  "messages": [{"role": "user", "content": "Extrahiere Inhalte von example.com"}],
  "plugins": [{"id": "web", "engine": "firecrawl", "max_results": 5}]
}
```

**CLI-Alternative:**
```bash
curl -X POST https://api.firecrawl.dev/v1/scrape \
  -H "Authorization: Bearer $FIRECRAWL_API_KEY" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

---

### 2. EXA (OpenRouter)

**Verwendung:**
```json
{
  "model": "openai/gpt-4.1",
  "plugins": [{"id": "web", "engine": "exa", "max_results": 5}]
}
```

**Features:**
- Neural + Keyword Search (Auto-Modus)
- relevance-sortierte Ergebnisse
- Domain-Filterung (include/exclude)

---

### 3. Tavily (OpenClaw nativ + MCP)

#### A. OpenClaw Plugin (empfohlen für einfache Fälle)
```javascript
// In OpenClau-Skills verfügbar als:
tools.tavily_search({
  query: "Aktuelle KI-Durchbrüche",
  max_results: 5,
  search_depth: "basic" | "advanced",
  topic: "general" | "news" | "finance"
});

tools.tavily_extract({
  urls: ["https://example.com/article"],
  query: "optionaler Kontext für Chunking",
  extract_depth: "basic" | "advanced"
});
```

#### B. mcporter (global MCP)
```bash
# Alle Tavily-Tools verfügbar
mcporter call tavily.tavily_search query="..." max_results=5
mcporter call tavily.tavily_extract urls='["https://..."]'
mcporter call tavily.tavily_crawl url="https://..." max_depth=2
mcporter call tavily.tavily_map url="https://..."
mcporter call tavily.tavily_research query="..." model=auto
mcporter call tavily.tavily_skill query="..." library="python"
```

#### C. Tavily CLI (direkte API)
```bash
tvly search "query" --depth basic --max-results 5
tvly extract <url> --query "Kontext"
tvly crawl <url> --max-depth 2 --limit 50
tvly map <url>
tvly research "komplexe Frage" --model pro
tvly  # Interaktiver Modus
```

#### D. Claude Code (MCP-Integration)
```
# In Claude Code:
/mcp
# → Zeigt verfügbare MCP-Server
# → tavily ist gelistet und verbunden

# Direkte Nutzung:
@tavily Suche nach aktuellen KI-Durchbrüchen
```

**Tavily Tools-Übersicht:**
| Tool | Zweck | Rate Limit |
|------|-------|------------|
| `tavily_search` | Websuche mit Filtern | 20/min |
| `tavily_extract` | URL-Inhaltsextraktion | 20/min |
| `tavily_crawl` | Website-Crawling | 10/min |
| `tavily_map` | URL-Struktur-Discovery | 20/min |
| `tavily_research` | Deep Research Multi-Step | 5/min |
| `tavily_skill` | Dokumentations-Suche | 20/min |

---

### 4. Perplexity (OpenRouter nativ)

**Verwendung:**
```json
{
  "model": "perplexity/sonar:online",
  "messages": [{"role": "user", "content": "Frage?"}]
}
```

**Alternative Modelle:**
- `perplexity/sonar` — Standard
- `perplexity/sonar-deep-research` — Tiefenrecherche
- `perplexity/sonar-pro` — Pro-Version

---

### 5. SearXNG (lokal)

**Verwendung:**
```javascript
tools.web_search({ query: "...", count: 5 });
```

**Status:** Fallback, aktuell Rate-Limited (429)

---

## Konfigurationsreferenz

### API-Keys (in `~/.openclaw/openclaw.env`)

```bash
# OpenRouter (für Firecrawl, EXA, Perplexity)
OPENROUTER_API_KEY="sk-or-v1-..."

# Tavily (eigener Service + MCP)
TAVILY_API_KEY="tvly-dev-..."
TAVILY_MCP_LINK="https://mcp.tavily.com/mcp/?tavilyApiKey=..."
```

### OpenClaw-Konfiguration (`~/.openclaw/openclaw.json`)

```json
{
  "plugins": {
    "entries": {
      "tavily": {
        "enabled": true,
        "config": {
          "webSearch": {
            "apiKey": "tvly-dev-..."
          }
        }
      },
      "exa": { "enabled": true },
      "searxng": {
        "enabled": true,
        "config": {
          "webSearch": { "baseUrl": "http://127.0.0.1:8888" }
        }
      }
    }
  },
  "tools": {
    "web": {
      "search": {
        "provider": "tavily",
        "enabled": true
      }
    }
  },
  "mcp": {
    "servers": {
      "tavily": {
        "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=..."
      }
    }
  }
}
```

### Claude Code (`~/.claude.json`)

```json
{
  "mcpServers": {
    "tavily": {
      "type": "http",
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=..."
    }
  }
}
```

### mcporter (`~/.mcporter/mcporter.json` oder `~/workspace/config/mcporter.json`)

```json
{
  "servers": {
    "tavily": {
      "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=..."
    }
  }
}
```

---

## Skill-Entwicklung mit Web-Search

### Template: Tavily über mcporter nutzen

```javascript
// skill-example.js
const { execSync } = require('child_process');

function searchWithTavily(query, options = {}) {
  const args = [
    'call', 'tavily.tavily_search',
    `query="${query}"`,
    `max_results=${options.maxResults || 5}`,
    `--json`
  ];
  
  const result = execSync(`mcporter ${args.join(' ')}`, {
    encoding: 'utf8',
    timeout: 30000
  });
  
  return JSON.parse(result);
}

module.exports = { searchWithTavily };
```

### Template: OpenClaw nativ

```javascript
// In OpenClaw-Skills:
async function researchTopic(topic) {
  // Versuche zuerst Tavily (schnell, strukturiert)
  const tavilyResult = await tools.tavily_search({
    query: topic,
    max_results: 5,
    search_depth: 'advanced',
    include_answer: 'advanced'
  });
  
  // Fallback zu Perplexity (verifizierte Quellen)
  if (!tavilyResult || tavilyResult.results.length === 0) {
    const perplexityResult = await callOpenRouter({
      model: 'perplexity/sonar:online',
      messages: [{ role: 'user', content: topic }]
    });
    return perplexityResult;
  }
  
  return tavilyResult;
}
```

---

## Fehlerbehebung

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `web_search` liefert keine Ergebnisse | SearXNG Rate-Limit | Auf Tavily/Perplexity umschalten |
| `mcporter` findet Server nicht | Konfig im falschen Pfad | `mcporter config list` prüfen |
| Claude Code zeigt `/mcp` nicht | Server nicht verbunden | `claude mcp list` prüfen, ggf. reconnect |
| Tavily CLI: "Not authenticated" | Key nicht gesetzt | `tvly login --api-key ...` oder env var |
| Firecrawl/EXA: 402 Payment Required | OpenRouter-Credits aufgebraucht | Credits aufladen oder Tavily nutzen |

---

## Monitoring & Limits

| Service | Limit | Monitoring |
|---------|-------|------------|
| Tavily API | 1.000 Credits/Monat | https://app.tavily.com/dashboard |
| Tavily MCP | 20 req/min (search) | Logs in `~/.openclaw/logs/` |
| OpenRouter | Pro Query ($0.02-0.10) | https://openrouter.ai/settings |
| SearXNG | Lokal, keine Limits | Eigene Instanz |

---

## Zusammenfassung: Wann was nutzen?

| Szenario | Empfohlener Provider | Methode |
|----------|---------------------|---------|
| Schnelle Fakten-Abfrage | Tavily | OpenClaw Plugin |
| Website komplett crawlen | Firecrawl | OpenRouter |
| Akademische Recherche | Perplexity | OpenRouter `:online` |
 | Tiefgehende Untersuchung | Tavily Research | `tavily_research` oder `tvly research` |
| API-Dokumentation finden | Tavily Skill | `tavily_skill` |
| Fallback bei Ausfall | EXA → SearXNG | OpenRouter / Lokal |
| Automatisierung/Scripts | Tavily CLI | `tvly` direkt |
| Claude Code Integration | Tavily MCP | `@tavily` oder `/mcp` |

---

**Letzte Aktualisierung:** 2026-04-18 05:15 CET  
**Verantwortlich:** Artif (OpenClaw Agent)
