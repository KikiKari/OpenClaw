# SYNC-SYSTEM - ClawHub ↔ Git Bidirektionale Synchronisation

**Erstellt:** 2026-04-18  
**Version:** 1.0.0  
**Status:** ✅ Aktiv  

---

## Übersicht

Automatische bidirektionale Synchronisation zwischen:
- **ClawHub**: `/workspace/skills/*/` (Aktive Skills)
- **Git**: `/workspace/git/skills/*/` (Versionskontrolle)

---

## Komponenten

### 1. Sync-Script
**Pfad:** `/workspace/scripts/sync_clawhub_git.py`  
**Funktion:** Kern-Synchronisationslogik  
**Features:**
- Bidirektional (to-git, to-clawhub)
- Validierung (SKILL.md + scripts/)
- Backup vor Änderungen
- Hash-basierter Vergleich

### 2. Sync-Agent (Sub-Agent)
**Skill:** `clawhub-git-sync-agent`  
**Script:** `/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py`  
**Cron:** Stündlich (0 * * * *)  
**Features:**
- Automatische Erkennung neuer Skills
- Git-Initialisierung bei Bedarf
- Konfliktbehandlung
- State-Management

### 3. Alle aktiven Sub-Agents

#### Cron-aktivierte Agents (Stand: 2026-04-18)

| Agent | Zweck | Intervall | Script/Datei | Status |
|-------|-------|-----------|-------------|--------|
| **openclaw-maintenance** | System-Wartung (root) | 20min + täglich | `/crons/openclaw-maintenance.cron` | ✅ |
| **db-maintainer** | DB-Wartung, Tree-Updates | 30min | `db_maintainer.py` | ✅ |
| **log-collector** | Log-Sammlung via SSH | 3h | `log_collector.py` | ✅ |
| **abstractions-manager** | vollständige Modellübersetzungen | 6h | `abstractions/ABSTRACTIONS_MANAGER.py` | ✅ OpenClaw-Scheduler |
| **clawhub-git-sync** | ClawHub↔Git Sync | 1h | `sync_agent.py` | ✅ |
| **node-health-monitor** | Node-Überwachung | 45min | `node_health.py` | ✅ NEU |
| **channel-status-agent** | Status-Updates | 12h (9,21) | `channel_status.py` | ✅ NEU |
| **reports-creator** | Report-Generierung | täglich 6h | `daily_report.py` | ✅ NEU |

#### Skills ohne Cron (Event-basiert/Manuell)

| Agent | Zweck | Nutzung |
|-------|-------|---------|
| **sync-utils** | Sync-Hilfsfunktionen | Manuell für Bulk/Konflikte |
| **tiktok-live-mon** | `live|restricted|offline` und URL-Extraktion | Gateway lokal oder agent-gesteuert via `exec host=node` |
| **git-publish-agent** | Git Publishing | Event-basiert |
| **server-maintenance** | Node-Wartung | Teilweise in openclaw-maintenance |

---

## Sync-Richtungen

### ClawHub → Git
- Neue Skills werden als Git-Repos initialisiert
- Updates werden committed
- Backup vor Überschreibung

### Git → ClawHub
- Nur bei expliziter Anforderung
- Backup der ClawHub-Version
- Validierung der Skill-Struktur

---

## Validierung

Skills müssen haben:
- `SKILL.md` (Dokumentation)
- `scripts/` (Verzeichnis für Scripte)

Skills ohne diese Struktur werden übersprungen.

---

## Konfliktbehandlung

| Situation | Aktion |
|-----------|--------|
| Nur in ClawHub | → Git (automatisch) |
| Nur in Git | → ClawHub (automatisch) |
| Beide modifiziert | Timestamp-Vergleich |
| Konflikt | Backup + Log |

---

## Multi-Node Fähigkeiten

Der Sync-Agent kann auf verschiedenen Nodes laufen:
- Node 1: Gateway (Standard)
- Node 2: Stable Worker
- Node 7: Docker (wenn verfügbar)

---

## Logs & State

| Datei | Zweck |
|-------|-------|
| `/workspace/logs/sync.log` | Sync-Operationen |
| `/workspace/logs/sync-agent.log` | Agent-Ausführungen |
| `/workspace/db/sync_state.json` | Sync-Status |
| `/workspace/backups/sync/` | Automatische Backups |

---

## Verwendung

### Manueller Sync
```bash
# Einzelner Skill zu Git
python3 /workspace/scripts/sync_clawhub_git.py --skill db-maintainer --direction to-git

# Dry-Run
python3 /workspace/scripts/sync_clawhub_git.py --skill db-maintainer --direction to-git --dry-run
```

### Status prüfen
```bash
# Sync-State
cat /workspace/db/sync_state.json

# Letzte Logs
tail -20 /workspace/logs/sync-agent.log
```

---

## Integration mit anderen Systemen

### Abstractions-Manager
- Erstellt geprüfte Übersetzungen in `/workspace/git/Abstraktionen/`
- Veröffentlicht direkt nach `OpenClaw@gateway2-abstractions`
- Der alte Skill-/Stub-Bestand ist stillgelegt und wird nicht synchronisiert

### Skill-Publishing
- ClawHub-Skills können via `git-publish-agent` veröffentlicht werden
- Sync hält Git-Version aktuell

---

## Sicherheit

- Keine automatischen Löschungen
- Backup vor jeder Änderung
- Validierung verhindert fehlerhafte Syncs
- Logs für Audit-Trail

---

## Nächste Schritte

1. **sync-utils** Skill erstellen für:
   - Manuelle Sync-Operationen
   - Konfliktauflösung
   - Bulk-Operationen
   
2. **Monitoring** einrichten:
   - Fehlerbenachrichtigungen
   - Sync-Statistiken

---

**Hinweis:** Diese Dokumentation ist Teil des Core-Systems und wird bei Änderungen am Sync-System aktualisiert.
