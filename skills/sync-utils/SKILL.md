# sync-utils Skill

**Name:** sync-utils  
**Beschreibung:** Utility-Tools für ClawHub ↔ Git Synchronisation  
**Version:** 1.0.0  
**Emoji:** 🔄  

## Zweck

Hilfs-Tools für manuelle Sync-Operationen, Konfliktauflösung und Bulk-Synchronisation zwischen ClawHub und Git.

## Verfügbare Scripts

| Script | Funktion |
|--------|----------|
| `sync_single.py` | Einzelnen Skill synchronisieren |
| `sync_bulk.py` | Alle Skills synchronisieren |
| `check_conflicts.py` | Konflikte erkennen und anzeigen |
| `resolve_conflict.py` | Konflikt manuell auflösen |
| `sync_status.py` | Sync-Status aller Skills anzeigen |

## Verwendung

### Einzelnen Skill synchronisieren
```bash
python3 scripts/sync_single.py --skill db-maintainer --direction to-git
```

### Alle Skills synchronisieren
```bash
python3 scripts/sync_bulk.py --dry-run
python3 scripts/sync_bulk.py --execute
```

### Konflikte prüfen
```bash
python3 scripts/check_conflicts.py
```

### Konflikt auflösen
```bash
python3 scripts/resolve_conflict.py --skill json-utils --keep clawhub
python3 scripts/resolve_conflict.py --skill json-utils --keep git
```

### Status anzeigen
```bash
python3 scripts/sync_status.py
```

## Features

- **Dry-Run Modus**: Zeigt Änderungen ohne auszuführen
- **Konfliktbehandlung**: Manuelle Auswahl bei Konflikten
- **Bulk-Operationen**: Alle Skills auf einmal
- **Status-Dashboard**: Übersicht aller Sync-Stati
- **Backup-Integration**: Automatische Backups

## Integration

Arbeitet mit:
- `sync_clawhub_git.py` (Core Sync-Script)
- `clawhub-git-sync-agent` (Automatischer Agent)
- Backup-System in `/workspace/backups/sync/`

## Logs

- Operationen: `/workspace/logs/sync-utils.log`
- Konflikte: `/workspace/logs/sync-conflicts.log`