# Git ↔ ClawHub Synchronisation Konzept

## Ziel
Bidirektionale Synchronisation zwischen:
- **ClawHub**: `~/.openclaw/skills/*/` (aktive Skills)
- **Git**: `~/workspace/git/` (Versionskontrolle, Backup)

## Richtlinien

### 1. Sub-Agent darf Abstraktionen erstellen
- Aber nur mit Validierung
- Keine Stubs, nur echte Portierungen
- Sub-Agent hat explizite Genehmigung über Config-Flag

### 2. Validierung (Punkt 2)
Vor jedem Sync:
- Prüfe Skill-Struktur (SKILL.md vorhanden?)
- Prüfe Scripts auf Syntax-Fehler
- Prüfe auf unbeabsichtigte Änderungen (Diff zu letztem Sync)

### 3. Backup (Punkt 3 - obligatorisch)
Vor jedem Sync-Vorgang:
- Timestamp-Backup des Git-Repo-Zustands
- Backup-Verzeichnis: `backups/sync-YYYYMMDD-HHMMSS/`
- 30-Tage Retention für Backups

### 4. Review durch Sub-Agent
- Sub-Agent prüft Änderungen vor Commit
- Keine automatischen Commits ohne Review
- Manuelle Freigabe erforderlich

## Sync-Richtungen

### ClawHub → Git (Push)
Wann: Nach Skill-Updates, täglich via Cron
Was: Original Skill-Dateien (nicht Abstraktionen)
Wo: `git/skills/{skill-name}/`

### Git → ClawHub (Pull)
Wann: Nach Git-Commits, manuell oder via Cron
Was: Aktualisierte Skill-Dateien
Wo: `~/.openclaw/skills/{skill-name}/`

## Verzeichnisstruktur

```
workspace/git/
├── skills/                    # <-- ClawHub-Skills als Git-Repos
│   ├── db-maintainer/
│   │   ├── .git/
│   │   ├── SKILL.md
│   │   └── scripts/
│   ├── log-collector/
│   └── ...
├── abstractions/              # <-- Abstraktionen (nur via Sub-Agent)
│   └── ...
└── abstractions-utils/        # <-- Helper-Skills (bereits vorhanden)
```

## Konfliktlösung

| Szenario | Lösung |
|----------|--------|
| ClawHub neuer als Git | Git aktualisieren |
| Git neuer als ClawHub | ClawHub aktualisieren |
| Beide modifiziert | Backup, dann manuelle Entscheidung |
| Skill in ClawHub gelöscht | In Git als "deprecated" markieren |

## Sicherheitsmaßnahmen

1. **Pre-Sync-Validierung**:
   ```bash
   validate_skill_structure(skill_dir)
   validate_scripts_syntax(skill_dir)
   create_backup(target_repo)
   ```

2. **Sync nur mit Flag**:
   ```bash
   sync_clawhub_to_git --validate --backup --target=skill-name
   ```

3. **Review-Pflicht**:
   - Sub-Agent prüft Änderungen
   - Kein `--auto-commit`
   - Manuelle Freigabe via Nachricht

## Abstraktionen-Regeln

| Wer | Was | Wie |
|-----|-----|-----|
| Sub-Agent | Echte Portierungen | Mit Modell-Interpolation |
| Haupt-Agent | Keine Abstraktionen | Nur Koordination |
| Automatik | Keine Stubs | Nur mit Freigabe |

## Test-Strategie

1. Dry-Run: Zeigt Änderungen ohne auszuführen
2. Single-Skill-Test: Ein Skill synchronisieren
3. Vollständiger Sync: Alle Skills
4. Rollback-Test: Wiederherstellung aus Backup

## Cron-Job

```bash
# Tägliche Synchronisation
0 2 * * * /workspace/scripts/sync_clawhub_git.py --validate --backup --dry-run
```

## Freigabe-Workflow

1. Sync-Script erstellt Report
2. Report wird dem User gezeigt
3. User gibt Freigabe (`/approve sync`)
4. Sync wird ausgeführt
5. Ergebnis wird dokumentiert
