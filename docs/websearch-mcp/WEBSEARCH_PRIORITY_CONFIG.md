# Web Search Provider Priorität – Technische Umsetzung

**Stand:** 2026-04-18  
**Ziel:** Prioritätsreihenfolge Firecrawl → EXA → Tavily → Perplexity → SearXNG

---

## Architektur-Verständnis

OpenClaw unterscheidet zwischen **nativen Plugins** und **OpenRouter Engines**:

| Ebene | Mechanismus | Provider |
|-------|-------------|----------|
| **OpenClaw nativ** | `plugins.entries.*` | tavily, searxng, duckduckgo |
| **OpenRouter** | `plugins: [{"engine": "..."}]` | firecrawl, exa, parallel, native |
| **MCP** | `mcp.servers` | tavily (zusätzlich) |

---

## Konfiguration in `~/.openclaw/openclaw.json`

### Native Plugins (Boardmittel)

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
      "searxng": {
        "enabled": true,
        "config": {
          "webSearch": {
            "baseUrl": "http://127.0.0.1:8888"
          }
        }
      },
      "duckduckgo": {
        "enabled": true
      },
      "firecrawl": {
        "enabled": true
      },
      "exa": {
        "enabled": true
      },
      "parallel": {
        "enabled": false
      }
    }
  }
}
```

### MCP-Server (zusätzliche Services)

```json
{
  "mcp": {
    "servers": {
      "tavily": {
        "url": "https://mcp.tavily.com/mcp/?tavilyApiKey=..."
      }
    }
  }
}
```

### Web-Search Tool Konfiguration

```json
{
  "tools": {
    "web": {
      "search": {
        "provider": "openrouter",
        "enabled": true,
        "openaiCodex": {}
      }
    }
  }
}
```

---

## Prioritäts-Umsetzung

Da OpenClaw nur **einen** Provider für `web_search` unterstützt, wird die Priorität über **explizite Tool-Nutzung** gesteuert:

### Priorität 1: Firecrawl (Crawling/Markdown)

```javascript
// Direkte OpenRouter-Nutzung
const result = await callOpenRouter({
  model: "openai/gpt-4.1",
  messages: [{ role: "user", content: query }],
  plugins: [{ id: "web", engine: "firecrawl", max_results: 5 }]
});
```

### Priorität 2: EXA (Recherche)

```javascript
const result = await callOpenRouter({
  model: "openai/gpt-4.1",
  messages: [{ role: "user", content: query }],
  plugins: [{ id: "web", engine: "exa", max_results: 5 }]
});
```

### Priorität 3: Tavily (KI-Forschung)

```javascript
// OpenClaw nativ
const result = await tools.tavily_search({
  query: query,
  max_results: 5,
  search_depth: "advanced"
});

// ODER über MCP
const result = await mcporter.call("tavily.tavily_search", {
  query: query,
  max_results: 5
});
```

### Priorität 4: Perplexity (Präzise Recherche)

```javascript
const result = await callOpenRouter({
  model: "perplexity/sonar:online",  // :online aktiviert Web-Suche
  messages: [{ role: "user", content: query }]
});
```

### Priorität 5: SearXNG (Fallback)

```javascript
const result = await tools.web_search({
  query: query,
  count: 5
});
// Nutzt searxng wenn in openclaw.json als provider konfiguriert
```

---

## Entscheidungsbaum für Skills

```
Benötige ich:
├── Website-Crawling/Markdown? → Firecrawl (engine: "firecrawl")
├── Schnelle Recherche/Quellen? → EXA (engine: "exa")
├── Tiefgehende KI-Analyse? → Tavily (tavily_search)
├── Verifizierte Fakten? → Perplexity (perplexity/sonar:online)
└── Fallback/Datenschutz? → SearXNG (web_search)
```

---

## Empfohlener Skill-Wrapper

 Ein Skill-Wrapper, der die Priorität automatisch anwendet:

```javascript
// websearch-priority.js
async function searchWithPriority(query, options = {}) {
  const { needCrawl, needVerified, needDeepResearch } = options;
  
  // 1. Firecrawl für Crawling
  if (needCrawl) {
    return callOpenRouter({
      model: "openai/gpt-4.1",
      plugins: [{ id: "web", engine: "firecrawl", max_results: 5 }]
    });
  }
  
  // 2. EXA für schnelle Recherche
  if (!needVerified && !needDeepResearch) {
    return callOpenRouter({
      model: "openai/gpt-4.1",
      plugins: [{ id: "web", engine: "exa", max_results: 5 }]
    });
  }
  
  // 3. Tavily für KI-Forschung
  if (needDeepResearch) {
    return tools.tavily_search({
      query, max_results: 5, search_depth: "advanced"
    });
  }
  
  // 4. Perplexity für verifizierte Fakten
  if (needVerified) {
    return callOpenRouter({
      model: "perplexity/sonar:online",
      messages: [{ role: "user", content: query }]
    });
  }
  
  // 5. Fallback: SearXNG
  return tools.web_search({ query, count: 5 });
}
```

---

## Validierung

```bash
# 1. Firecrawl
openclaw tools web search --engine firecrawl "test"

# 2. EXA
openclaw tools web search --engine exa "test"

# 3. Tavily (nativ)
openclaw tools tavily search "test"

# 4. Perplexity
openclaw chat --model perplexity/sonar:online "test"

# 5. SearXNG
openclaw tools web search --provider searxng "test"
```

---

## Zusammenfassung

| Priorität | Provider | Technische Umsetzung |
|-----------|----------|---------------------|
| 1 | Firecrawl | OpenRouter `engine: "firecrawl"` |
| 2 | EXA | OpenRouter `engine: "exa"` |
| 3 | Tavily | OpenClaw `tools.tavily_search()` oder MCP |
| 4 | Perplexity | OpenRouter `:online` Modelle |
| 5 | SearXNG | OpenClaw `tools.web_search()` mit Provider |

Alle Provider sind aktiviert in `openclaw.json`, die Priorität wird durch **explizite Tool-Auswahl** gesteuert.
