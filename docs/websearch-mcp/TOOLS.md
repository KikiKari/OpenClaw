# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

## Web Search Stack (2026-04-18)

### Provider-Priorität
1. **Firecrawl** → Crawling + Markdown (OpenRouter)
2. **EXA** → Recherche + Quellen (OpenRouter)
3. **Tavily** → KI-Forschung (OpenClaw Plugin / MCP / CLI)
4. **Perplexity** → Präzise Recherche (OpenRouter)
5. **SearXNG** → Selbstgehostet (Fallback)

### Schnellreferenz

```bash
# OpenClaw nativ (tavily preferred)
openclaw tools web search --provider tavily

# mcporter (global MCP)
mcporter call tavily.tavily_search query="..." max_results=5

# Tavily CLI
tvly search "..." --depth advanced --max-results 5
tvly research "komplexe Frage" --model pro

# Claude Code (mit MCP)
claude
# Dann: /mcp oder @tavily
```

### API-Keys (in ~/.openclaw/openclaw.env)

| Service | Key | Zweck |
|---------|-----|-------|
| OpenRouter | `OPENROUTER_API_KEY` | Firecrawl, EXA, Perplexity |
| Tavily | `TAVILY_API_KEY` | Plugin, MCP, CLI |

### Konfigurationsdateien

- `~/.openclaw/openclaw.json` → OpenClaw Plugin + MCP
- `~/.claude.json` → Claude Code MCP
- `~/.mcporter/mcporter.json` → mcporter
- `~/.tavily/config.json` → Tavily CLI

### Detaillierte Dokumentation

- **Vollständige Referenz:** `WEBSEARCH_MCP_GUIDE.md`
- **Prioritäts-Implementierung:** `WEBSEARCH_PRIORITY_CONFIG.md`
- **Scripting & Automation:** `WEBSEARCH_SCRIPTS.md`
- **IT-Operations:** `WEBSEARCH_OPS.md`
- **Übersicht:** `DOCUMENTATION_INDEX.md`

### Für Serverwartung / Automation

```bash
# Scripts für Cron-Jobs, CI/CD:
./scripts/websearch-crawl.sh        # Website-Crawling
./scripts/websearch-monitor.sh      # Monitoring-Recherche
./scripts/websearch-research.sh     # Incident Response
```

**Dokumentation:**
- `WEBSEARCH_SCRIPTS.md` → Automation & Scripting
- `WEBSEARCH_OPS.md` → IT-Operations (Incident, Patch, Compliance)

---

Add whatever helps you do your job. This is your cheat sheet.
