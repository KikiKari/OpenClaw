# Web Search Scripts für Automation & Serverwartung

**Verwendung:** Shell-Scripts, Cron-Jobs, CI/CD, Serverwartung  
**Keine OpenClaw-Abhängigkeit:** Direkte API-Nutzung  
**Speicherort:** `~/workspace/scripts/` und `~/.openclaw/scripts/`

---

## Quick Reference

```bash
# 1. Firecrawl - Website crawlen und speichern
~/workspace/scripts/websearch-crawl.sh https://example.com ./backups/

# 2. EXA - Schnelle Recherche für Monitoring-Alerts
~/workspace/scripts/websearch-research.sh "CVE-2025-1234 vulnerability"

# 3. Tavily CLI - Dokumentation aktualisieren
tvly research "Kubernetes 1.32 release notes" --model pro

# 4. Lokale Suche (kein externes API)
~/workspace/scripts/websearch-monitor.sh "Linux security updates"
```

---

## Verfügbare Scripts

### `scripts/websearch-crawl.sh`
**Zweck:** Website komplett crawlen und als Markdown speichern  
**Provider:** Firecrawl (via OpenRouter)

```bash
# Verwendung
./scripts/websearch-crawl.sh <URL> [OUTPUT_DIR]

# Beispiel
./scripts/websearch-crawl.sh https://docs.example.com ./backups/docs/
```

### `scripts/websearch-monitor.sh`
**Zweck:** Automatische Recherche für Monitoring-Alerts  
**Provider:** Tavily CLI → SearXNG (Fallback)

```bash
# Standard: Linux kernel security updates
./scripts/websearch-monitor.sh

# Eigener Suchbegriff
./scripts/websearch-monitor.sh "PostgreSQL 17 performance tuning"
```

### `scripts/websearch-research.sh`
**Zweck:** Incident Response mit automatischer Recherche  
**Provider:** EXA (schnell) + Perplexity (verifiziert)

```bash
# Verwendung
./scripts/websearch-research.sh "Problem Beschreibung" [OUTPUT_DIR]

# Beispiel
./scripts/websearch-research.sh "MySQL high CPU production" ./incidents/
```

---

## Environment Setup

```bash
# ~/.profile oder /etc/environment

# API-Keys
export OPENROUTER_API_KEY=""
export TAVILY_API_KEY=""

# Pfade
export PATH="$PATH:/home/openclaw/.local/bin"  # für tvly, mcporter
```

---

## Cron-Job Beispiele

```bash
# /etc/cron.d/websearch-scripts

# Tägliche Website-Backups
0 2 * * * openclaw /home/openclaw/.openclaw/workspace/scripts/websearch-crawl.sh https://docs.example.com /backups/docs/

# Weekly Security-News
0 9 * * 1 openclaw /home/openclaw/.openclaw/workspace/scripts/websearch-monitor.sh "Linux kernel security"
```

---

## Integration: Wartung & Monitoring

Siehe auch: `WEBSEARCH_OPS.md` für:
- Incident Response Workflows
- Patch Management Automation
- Monitoring-Stack Integration
- Compliance-Checks

---

**Stand:** 2026-04-18  
**Scripts vorhanden in:**
- `/home/openclaw/.openclaw/workspace/scripts/`
- `/home/openclaw/.openclaw/scripts/`
