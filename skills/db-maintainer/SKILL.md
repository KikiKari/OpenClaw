---
name: db-maintainer
description: Permanent database maintenance sub-agent. 12h checks for documentation changes, updates docs.db, runs tree -L 8, writes to important/openclaw-tree.txt. 12h backups with 3-day retention. Multi-node capable. Model: kimi-k2.5.
---

# Database Maintainer Sub-Agent

Permanenter Wartungs-Agent für Workspace-Datenbanken und Tree-Index.

## Aufgaben

| Intervall | Aufgabe | Details |
|-----------|---------|---------|
| **30 Min** | Tree-Scan | `tree -a -L 8` auf Workspace |
| **30 Min** | Tree-Datei | Schreibt Ergebnis nach `important/openclaw-tree.txt` |
| **30 Min** | Tree-DB | Aktualisiert tree.db (intern) |
| **30 Min** | Änderungs-Check | Prüft auf neue/veränderte Dokumentationen |
| **30 Min** | DB-Update | Aktualisiert docs.db |
| **Stündlich** | Backup | Erstellt SQLite-Backups |
| **Stündlich** | Cleanup | Löscht Backups > 3 Tage |

## Berechtigungen

```yaml
exec: read_write
nodes: spawn_check_fallback
gitclaw: read_execute
```

## Node-Fallback Logik

```python
# Pseudocode für Node-Prüfung
def execute_task(task):
    # 1. Prüfe alternativen Node
    alt_node = find_available_worker_node()
    
    if alt_node and alt_node.is_reachable():
        # Delegiere an Worker-Node
        return spawn_subagent_on_node(alt_node, task)
    else:
        # Fallback: Selbst ausführen
        return execute_locally(task)
```

## Multi-Node Support

```bash
# Node 1 (Haupt)
openclaw agent spawn db-maintainer --node node1

# Node 2 (Redundanz/Backup) - optional
openclaw agent spawn db-maintainer --node node2
```

## Backup-Struktur (3 Tage Retention)

```
db/backups/
├── 2026-04-18_11-00_docs.db.bak
├── 2026-04-18_11-00_tree.db.bak
├── 2026-04-18_12-00_docs.db.bak
├── ...
(Alle Backbacks der letzten 72 Stunden)
```

## Wichtige Dateien

### Extern (öffentlich)
- `important/openclaw-tree.txt` - Aktueller tree -L 8 Output

### Intern (nur lokal)
- `db/docs.db` - Dokumentations-Index
- `db/tree.db` - Verzeichnisbaum-Index
- `logs/db-maintainer/` - Agent-Logs

## Installation

```bash
# Skill installieren
clawhub install db-maintainer

# Cron aktivieren
python3 skills/db-maintainer/scripts/install_cron.py
```

## Manuelle Ausführung

```bash
# Einzelner Durchlauf
python3 skills/db-maintainer/scripts/db_maintainer.py
```

## Konfiguration

```json
{
  "db-maintainer": {
    "enabled": true,
    "check_interval_minutes": 30,
    "backup_interval_hours": 1,
    "retention_days": 3,
    "backup_dir": "db/backups/",
    "nodes": ["node1", "node2"]
  }
}
```

## Logs

```
logs/db-maintainer/
├── 2026-04-18.log
├── 2026-04-17.log
└── ...
```

## Veröffentlichung

Dieser Skill kann zu ClawHub veröffentlicht werden:
```bash
clawhub publish skills/db-maintainer --slug db-maintainer --version 1.0.0
```
