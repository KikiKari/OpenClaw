# SUB-AGENTS & WORKERS - Cluster-Dokumentation

**Erstellt:** 2026-04-11 16:53 GMT+2  
**DIESE DATEI SOLLTE ALS EINE DER ERSTEN GELESEN WERDEN!**

## Übersicht

Im OpenClaw-Cluster können Aufgaben an Sub-Agents oder Worker-Nodes delegiert werden. Dies entlastet den Main-Agent und ermöglicht parallele Bearbeitung.

## Verfügbare Sub-Agent Typen

### Aktive Sub-Agents (Stand: 2026-04-18)

#### Mit Cron-Job aktiviert (Stand: 2026-04-18 22:25)

| Agent | Aufgabe | Intervall | Log-Datei | Status |
|-------|---------|-----------|-----------|--------|
| **openclaw-maintenance** | System-Updates, Checks | 20min, täglich | server-maintenance.log | ✅ Root |
| **db-maintainer** | Datenbank-Wartung, Tree | 30min | db-maintainer.log | ✅ Root |
| **log-collector** | Multi-Node Log-Sammlung | 3h | log-collector.log | ✅ Root |
| **abstractions-manager** | vollständige Modellübersetzungen | 6h | manager.log | ✅ OpenClaw-Scheduler (`main`, isoliert) |
| **clawhub-git-sync** | ClawHub↔Git Sync | 1h | sync-agent.log | ✅ Root |
| **node-health-monitor** | Node-Überwachung | 45min | node-health.log | ✅ Root |
| **channel-status-agent** | Status-Updates | 12h (9,21 Uhr) | channel-status.log | ✅ Root |
| **reports-creator** | Reports generieren | Täglich 6h, So 8h | reports-creator.log | ✅ Root |

#### Weitere Skills (ohne Cron/Event-basiert)

| Agent | Aufgabe | Status | Nutzung |
|-------|---------|--------|-------------|
| **tiktok-live-mon** | TikTok LIVE Klassifikation/URL | ✅ Dispatcher bereit | Gateway lokal oder agent-gesteuert auf gepaartem Node |
| **git-publish-agent** | Git/ClawHub Publishing | 📦 Skill bereit | Manuell/Event-basiert |
| **server-maintenance** | Node-spezifische Wartung | 📦 Skill bereit | Teilweise in openclaw-maintenance |
| **sync-utils** | Sync-Hilfsfunktionen | ✅ Skill erstellt | Manuell für Bulk/Konflikte |

#### Zusammenfassung

**Historischer Gesamtstand:** 8 Cron-Agents. Der Abstractions Manager läuft
seit 2026-08-08 als isolierter Command-Job des OpenClaw-Agents `main`, nicht
als Root-Cron oder eigener Sub-Agent.
- **System-Wartung:** openclaw-maintenance
- **Datenbanken:** db-maintainer, log-collector
- **Code/Skills:** abstractions-manager, clawhub-git-sync
- **Monitoring:** node-health-monitor
- **Kommunikation:** channel-status-agent, reports-creator

**Hinweis:** Duplikate in der Crontab wurden bereinigt. Die Agents laufen mit den korrekten Intervallen.

## Verfügbare Sub-Agent Typen

### 1. Coding Agents
- **Codex** - OpenAI Coding Agent
- **Claude Code** - Anthropic Coding Agent  
- **Pi** - Inflection AI Agent
- **OpenCode** - Open-Source Alternative

**Verwendung:**
```bash
# Spawn coding agent für neue Features
sessions_spawn --agent codex --task "Build REST API"

# Claude Code für Code-Reviews
sessions_spawn --agent claude-code --print --permission-mode bypassPermissions
```

### 2. Spezialisierte Worker

**Dokumentations-Worker:**
- Können laufende Übersichten pflegen
- Automatische Index-Updates
- Changelog-Generierung

**Monitoring-Worker:**
- Heartbeat-Checks
- System-Status
- Alert-Verarbeitung

## Node-basierte Aufgabenverteilung

### Gateway (Node 1)
- Main Agent läuft hier
- Koordiniert Sub-Agents
- Verwaltet Sessions

### Worker Nodes (2, 3, 5)
- Können Playwright-Tasks übernehmen
- Browser-Automation
- Parallel-Processing

## Delegation von Aufgaben

### Für laufende Dokumentation:
```bash
# Spawn sub-agent für Workspace-Index
sessions_spawn --agent maintainer --task "Update WORKSPACE-INDEX.md daily" --cron "0 */6 * * *"
```

### Für parallele Browser-Tasks:
```bash
# Der OpenClaw-Agent wählt verbundene gepaarte Nodes und nutzt exec host=node.
# Auf jedem gewählten Node läuft derselbe portable Einstieg lokal:
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  check example_creator --execution local --json
```

Bei fehlender Eignung, Überlast (Exit 75), Timeout oder Invoke-Fehler übernimmt
der Gateway. Direkte SSH- oder `openclaw nodes run`-Aufrufe gehören nicht zum
TikTok-Routing.

## Best Practices

1. **Langläufige Tasks** → Sub-Agent spawnen
2. **Dokumentations-Updates** → Dedizierter Worker
3. **Browser-Automation** → Auf Nodes verteilen
4. **Cron-Jobs** → Als Sub-Agent mit Schedule

## Wichtige Befehle

```bash
# Sub-Agent spawnen
sessions_spawn --agent <type> --task "<description>"

# Sessions auflisten
sessions_list

# Sub-Agent Ergebnisse abrufen
sessions_yield

# Node-Task ausführen
# Über das OpenClaw-exec-Tool: host=node, node=<node-id>, command=<argv>
```

## Warum Sub-Agents nutzen?

- **Performance**: Main Agent bleibt responsiv
- **Parallelität**: Mehrere Tasks gleichzeitig
- **Spezialisierung**: Jeder Agent für seine Stärke
- **Fehler-Isolation**: Crashes betreffen nur Sub-Agent

## Integration mit Nodes

Die physischen Nodes (2, 3, 5) können als Worker für:
- Playwright/Browser-Tasks
- Rechenintensive Aufgaben
- Geo-verteilte Checks
- Backup-Processing

**TIPP:** Diese Dokumentation erklärt, wie der Cluster WIRKLICH genutzt werden sollte!
