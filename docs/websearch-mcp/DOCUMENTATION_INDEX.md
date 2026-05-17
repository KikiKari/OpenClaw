# Web Search & MCP Dokumentation - Master Index

**Übersicht aller Dokumentationen und ihrer Verwendungszwecke**

---

## Schnellzugriff

| Wenn du... | Dann lies... | Pfad |
|------------|--------------|------|
| Schnell etwas nachschlagen willst | TOOLS.md | `./TOOLS.md` |
| Die komplette technische Referenz brauchst | WEBSEARCH_MCP_GUIDE.md | `./WEBSEARCH_MCP_GUIDE.md` |
| Genau verstehen willst, wie die Priorität funktioniert | WEBSEARCH_PRIORITY_CONFIG.md | `./WEBSEARCH_PRIORITY_CONFIG.md` |
| Scripts für Automation schreiben willst | WEBSEARCH_SCRIPTS.md | `./SCRIPTS/WEBSEARCH_SCRIPTS.md` |
| IT-Operations & Serverwartung machst | WEBSEARCH_OPS.md | `./OPS/WEBSEARCH_OPS.md` |
| Eine Skill-Entwicklung planst | Siehe unten "Skill Development" |

---

## Dokumentationsstruktur

```
~/workspace/
│
├── TOOLS.md                          ← Schnellreferenz ( tägliche Nutzung )
│
├── WEBSEARCH_MCP_GUIDE.md            ← Vollständige technische Dokumentation
│   ├── Alle 5 Provider
│   ├── Alle Zugriffsmethoden (Plugin, MCP, CLI)
│   ├── Code-Beispiele
│   └── Konfigurationsreferenz
│
├── WEBSEARCH_PRIORITY_CONFIG.md      ← Prioritäts-Implementierung
│   ├── Technische Architektur
│   ├── Entscheidungsbaum
│   └── Provider-Auswahl-Logik
│
├── SCRIPTS/
│   └── WEBSEARCH_SCRIPTS.md          ← Automation & Scripting
│       ├── Shell-Scripts
│       ├── Cron-Jobs
│       └── CI/CD Integration
│
├── OPS/
│   └── WEBSEARCH_OPS.md              ← IT-Operations
│       ├── Incident Response
│       ├── Patch Management
│       ├── Monitoring-Integration
│       └── Compliance
│
└── reports/
    ├── websearch-test-2026-04-18.md        ← Ursprünglicher Testbericht
    └── websearch-test-2026-04-18-FINAL.md  ← Abschlussbericht
```

---

## Nach Thema

### Für Endnutzer (Conversation Mode)

| Frage | Antwort finden in |
|-------|-------------------|
| "Welchen Provider soll ich nutzen?" | WEBSEARCH_PRIORITY_CONFIG.md → Entscheidungsbaum |
| "Wie rufe ich Tavily auf?" | WEBSEARCH_MCP_GUIDE.md → Tavily- |
| "Was ist mcporter?" | WEBSEARCH_MCP_GUIDE.md → mcporter- |
| "Geht das auch in Claude Code?" | WEBSEARCH_MCP_GUIDE.md → Claude Code- |

### Für Entwickler (Skill Development)

| Aufgabe | Dokumentation |
|---------|---------------|
| Neuen Skill erstellen | WEBSEARCH_MCP_GUIDE.md → "Skill-Entwicklung" |
| MCP in Skill nutzen | WEBSEARCH_MCP_GUIDE.md → "Skill-Entwicklung mit Web-Search" |
| Provider-Auswahl automatisieren | WEBSEARCH_PRIORITY_CONFIG.md → "Empfohlener Skill-Wrapper" |
| Fehlerbehandlung | WEBSEARCH_MCP_GUIDE.md → "Fehlerbehebung" |

### Für Systemadministratoren (Operations)

| Aufgabe | Dokumentation |
|---------|---------------|
| Server-Scripts schreiben | SCRIPTS/WEBSEARCH_SCRIPTS.md |
| Incident Response automatisieren | OPS/WEBSEARCH_OPS.md → "Incident Response" |
| Monitoring-Integration | OPS/WEBSEARCH_OPS.md → "Monitoring-Stack" |
| Patch-Management | OPS/WEBSEARCH_OPS.md → "Patch Management" |
| Compliance-Checks | OPS/WEBSEARCH_OPS.md → "Compliance & Audit" |

### Für CI/CD & Automation

| Aufgabe | Dokumentation |
|---------|---------------|
| Deployment-Scripts | SCRIPTS/WEBSEARCH_SCRIPTS.md → "Downtime-Monitoring" |
| Dokumentation auto-generieren | SCRIPTS/WEBSEARCH_SCRIPTS.md → "Dokumentation Auto-Update" |
| Testing & QA | SCRIPTS/WEBSEARCH_SCRIPTS.md → "Website-Backup" |

---

## Konfigurationsdateien (One-Liner)

| Datei | Zweck | Wichtige Einträge |
|-------|-------|-------------------|
| `~/.openclaw/openclaw.json` | OpenClaw Hauptkonfig | `plugins.entries.*`, `mcp.servers`, `tools.web.search` |
| `~/.openclaw/openclaw.env` | API-Keys | `OPENROUTER_API_KEY`, `TAVILY_API_KEY` |
| `~/.claude.json` | Claude Code MCP | `mcpServers.tavily` |
| `~/.mcporter/mcporter.json` | mcporter Global | Global verfügbare MCP-Server |
| `~/.tavily/config.json` | Tavily CLI Auth | API-Key für direkte CLI-Nutzung |

---

## Provider-Referenz (kurz)

| # | Provider | Best für | Methode | Rate Limit |
|---|----------|----------|---------|------------|
| 1 | Firecrawl | Crawling/Markdown | OpenRouter `engine: "firecrawl"` | BYOK |
| 2 | EXA | Recherche/Quellen | OpenRouter `engine: "exa"` | $4/1000 |
| 3 | Tavily | KI-Forschung | Plugin/MCP/CLI | 1000/mon |
| 4 | Perplexity | Verifizierte Fakten | OpenRouter `:online` | Pro Query |
| 5 | SearXNG | Lokale Suche | `tools.web_search()` | None |

---

## Cheatsheet: Häufigste Befehle

```bash
# 1. Schnelle Suche
mcporter call tavily.tavily_search query="..." max_results=5

# 2. Website crawlen
openclaw tools web search --engine firecrawl "https://..."

# 3. Deep Research
tvly research "komplexe Frage" --model pro

# 4. Verifizierte Fakten (in Claude Code)
# /mcp → tavily auswählen

# 5. Lokale Suche (kein API)
openclaw tools web search --provider searxng "..."
```

---

## Updates & Maintenance

- **Diese Index-Datei:** Bei neuen Dokumentationen aktualisieren
- **Letzte vollständige Überprüfung:** 2026-04-18
- **Nächste geplante Review:** Bei Provider-Änderungen oder neuen Features

---

**Fragen?** Starte mit TOOLS.md für schnelle Antworten, oder WEBSEARCH_MCP_GUIDE.md für Details.
