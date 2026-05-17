# Web Search & MCP Integration – README

**Übersicht und Einstiegspunkt**

---

## Schnellstart

```bash
# 1. Schnelle Suche (Tavily - Boardmittel)
mcporter call tavily.tavily_search query="aktuelle KI-Durchbrüche" max_results=5

# 2. Website crawlen (Firecrawl)
./scripts/websearch-crawl.sh https://example.com ./backups/

# 3. Deep Research
tvly research "komplexe Frage" --model pro

# 4. Verifizierte Fakten (Claude Code)
# In Claude Code: /mcp → tavily auswählen

# 5. Lokale Suche (Fallback)
curl http://localhost:8888/search?q=query&format=json
```

---

## Dokumentation (korrekte Pfade)

| Dokument | Pfad | Zweck |
|----------|------|-------|
| `TOOLS.md` | `./TOOLS.md` | Tägliche Schnellreferenz |
| `WEBSEARCH_MCP_GUIDE.md` | `./WEBSEARCH_MCP_GUIDE.md` | Vollständige technische Doku |
| `WEBSEARCH_PRIORITY_CONFIG.md` | `./WEBSEARCH_PRIORITY_CONFIG.md` | Prioritäts-Implementierung |
| `WEBSEARCH_SCRIPTS.md` | `./WEBSEARCH_SCRIPTS.md` | Automation & Scripting |
| `WEBSEARCH_OPS.md` | `./WEBSEARCH_OPS.md` | IT-Operations |
| `DOCUMENTATION_INDEX.md` | `./DOCUMENTATION_INDEX.md` | Master-Index |

---

## Verzeichnisstruktur

```
~/workspace/
│
├── TOOLS.md                     ← Schnellreferenz
├── WEBSEARCH_*.md               ← Alle WebSearch-Dokumentationen
├── DOCUMENTATION_INDEX.md       ← Übersicht
│
├── scripts/                     ← Ausführbare Scripts
│   ├── websearch-crawl.sh       ← Website-Crawling (Firecrawl)
│   ├── websearch-monitor.sh     ← Monitoring-Recherche
│   └── websearch-research.sh    ← Incident Response
│
├── git/                         ← Git Repository (korrigiert)
├── reports/                     ← Testberichte
└── memory/                      ← Tagesprotokolle

~/.openclaw/scripts/             ← Globale Scripts
├── websearch-crawl.sh
├── websearch-monitor.sh
└── websearch-research.sh
```

---

## Provider-Priorität

1. **Firecrawl** (Crawling) → OpenRouter `engine: "firecrawl"`
2. **EXA** (Recherche) → OpenRouter `engine: "exa"`
3. **Tavily** (KI-Forschung) → Plugin / MCP / CLI
4. **Perplexity** (Verifiziert) → OpenRouter `:online`
5. **SearXNG** (Fallback) → Lokal

---

## Konfiguration

```bash
# API-Keys in:
~/.openclaw/openclaw.env

# OpenClaw Konfiguration:
~/.openclaw/openclaw.json

# Claude Code MCP:
~/.claude.json

# Tavily CLI:
~/.tavily/config.json
```

---

## Support nach Rolle

- **Endnutzer:** TOOLS.md → Schnellreferenz
- **Entwickler:** WEBSEARCH_MCP_GUIDE.md → Technische Details
- **Systemadmin:** WEBSEARCH_OPS.md → Operations-Integration
- **Automation:** WEBSEARCH_SCRIPTS.md + scripts/ → Cron-Jobs

---

**Stand:** 2026-04-18 - Alle Pfade korrigiert
