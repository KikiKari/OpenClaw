# Skills und Scripts Inventar
**Erstellt:** 2026-04-18
**Status:** In Bearbeitung

> **Historischer Snapshot:** Die TikTok-Einträge bilden den Stand vom
> 2026-04-18 ab. Aktuell sind
> `$HOME/.openclaw/workspace/skills/tiktok-live/`,
> `$HOME/.openclaw/workspace/skills/tiktok-live-mon/` und
> `$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py` maßgeblich.
> Alte `tiktok-live-app`-/Backup-Pfade sind keine Laufzeitkomponenten.

## Übersicht
- **Skills gesamt:** 21
- **Script-Dateien:** ~61 (ohne node_modules)
- **Git Repositories:** 1 (workspace selbst)

## Aufgabe
Vollständige Katalogisierung aller:
1. Skills in `/workspace/skills/`
2. Scripts in `/workspace/` und Unterverzeichnissen
3. Git-Repositories und deren Inhalte
4. Verwendete Programmiersprachen

## Methodik
- Automatische Erkennung via Dateiendung
- Shebang-Analyse für Scripts
- package.json/requirements.txt für Dependencies
- SKILL.md Analyse für Skill-Beschreibungen

---

## Skills Übersicht (21 Skills)

### Python-basierte Skills (7)
1. **db-maintainer** - Datenbank-Wartung
   - `db_maintainer.py` - Hauptskript
   - `install_cron.py` - Cron-Installation

2. **git-publish-agent** - Git Publishing Automation
   - `git_publish.py` - Hauptskript

3. **json-utils** - JSON Verarbeitung
   - `json_batch_processor.py` - Batch-Verarbeitung
   - `json_processor.py` - JSON-Verarbeitung
   - `json_schema_validator.py` - Schema-Validierung
   - `validate_tool_output.py` - Tool-Output-Validierung

4. **log-collector** - Log-Sammlung
   - `log_collector.py` - Hauptskript

5. **model-usage** - Model-Nutzungs-Analyse
   - `model_usage.py` - Hauptskript

6. **scripting-utils** - Scripting Utilities
   - `irc_bot_syntax.py` - IRC Bot Syntax
   - `json_websearch.py` - JSON WebSearch
   - `language_validator.py` - Sprach-Validator
   - `system_manager.py` - System-Manager

7. **workspace-db** - Workspace Datenbank (SQLite-basiert)

### JavaScript-basierte Skills (1)
1. **tiktok-live-mon** - TikTok Live Monitoring
   - 2 JavaScript-Dateien

### Markdown/Dokumentations-Skills (13)
- cluster-gateway
- cluster-management
- doc-scraper
- documentation
- mcp-tool-utils
- relay-node
- reports-creator
- resource-manager
- server-maintenance
- sherpa-onnx-tts
- spotify-player
- web-scraper
- worker-node

## Scripts im Workspace

### Shell Scripts (13)
1. **Gateway/Installation**
   - `gateway-config-package/install.sh`
   - `gateway-config-package/cron/jobs-import.sh`
   - `gateway-config-package/scripts/server-maintenance.sh`

2. **Setup Scripts**
   - `scripts/setup-secret-write.sh`
   - `scripts/setup-xvfb-node2.sh`
   - `scripts/setup-xvfb-node3.sh`
   - `scripts/openclaw-node-autostart-termux.sh`

3. **Maintenance**
   - `scripts/server-maintenance.sh`
   - `scripts/test_node3.sh`

4. **WebSearch Scripts**
   - `scripts/websearch-crawl.sh`
   - `scripts/websearch-monitor.sh`
   - `scripts/websearch-research.sh`

### Python Scripts (6)
1. **Datenbank-Management**
   - `scripts/db_manager.py`
   - `scripts/update_docs_db.py`
   - `scripts/tree_indexer.py`
   - `scripts/tree_indexer_v2.py`

2. **Testing**
   - `scripts/test_multinode_fallback.py`

### JavaScript Scripts (10)
1. **Node Reports**
   - `scripts/post-nodes-report.js`
   - `scripts/update-nodes-report.js`

2. **Utilities**
   - `scripts/gemini-ask.js`
   - `scripts/ops-hub-heartbeat.js`
   - `scripts/wavespeed-image.js`
   - `wavespeed-image.js` (root)

3. **TikTok Scripts**
   - `tiktok-live-app/check-dieanonyme.js`
   - `tiktok-live-app/check-live.js`
   - `tiktok-backup-*/scripts/tiktok-check-profile.js`
   - `tiktok-backup-*/scripts/tiktok-get-stream.js`

## Programmiersprachen-Verteilung

| Sprache | Skills | Scripts | Gesamt | Verwendung |
|---------|--------|---------|--------|-----------|
| Python | 7 | 11 | 18 | Datenbank, Automation, Validierung |
| JavaScript | 1 | 10 | 11 | Web-Scraping, API-Calls, Reports |
| Shell/Bash | 0 | 13 | 13 | Setup, Maintenance, Installation |
| Markdown | 13 | - | 13 | Dokumentation, Konfiguration |

## Git Repository
- **Workspace selbst** ist ein Git-Repository
- Pfad: `/home/openclaw/.openclaw/workspace/git/`
- Typ: Bare Repository (nur .git Struktur)

## Empfehlungen
1. Python dominiert bei komplexen Aufgaben (Datenbank, Validierung)
2. JavaScript für Web-bezogene Aufgaben (TikTok, APIs)
3. Shell für System-Setup und Maintenance
4. Viele Skills sind reine Dokumentation (Markdown-basiert)
