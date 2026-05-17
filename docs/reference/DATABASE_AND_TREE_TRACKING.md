# Datenbank und Tree Tracking System

**Version:** 2.0  
**Stand:** 2026-04-18  
**Autor:** OpenClaw Agent System

## Übersicht

Hybride Datenbanklösung für OpenClaw-Workspaces mit vollständigem Datei-Tracking und Revisionshistorie.

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│  WORKSPACE                                                  │
│  ├── db/                                                    │
│  │   ├── docs.db           ← Dokumentations-Index           │
│  │   ├── tree.db           ← Datei-Tracking (v2)            │
│  │   └── backups/          ← 3-Tage Backup-Historie         │
│  │                                                          │
│  ├── important/                                             │
│  │   └── openclaw-tree.txt ← Aktueller tree -L 8 Output    │
│  │                                                          │
│  └── scripts/                                               │
│      ├── db_manager.py     ← docs.db Initialisierung        │
│      ├── tree_indexer_v2.py← tree.db mit Metadaten          │
│      └── update_docs_db.py ← Dokumentation-Scanner          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  db-maintainer (Sub-Agent)                                  │
│  • 30min: Änderungs-Check                                   │
│  • 30min: DB-Updates                                        │
│  • 1h: Backups (3 Tage Retention)                          │
│  • Multi-Node fähig mit Fallback                           │
└─────────────────────────────────────────────────────────────┘
```

## docs.db Schema

### documents Tabelle
```sql
CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    name TEXT,              -- Dateiname
    path TEXT,              -- Relativer Pfad
    category TEXT,          -- main, websearch, mcp, docs/...
    description TEXT,       -- Kurzbeschreibung
    type TEXT,              -- doc, config, guide, symlink
    has_symlink BOOLEAN,    -- Hat Symlink im Root?
    symlink_path TEXT,      -- Zielpfad
    last_update TEXT        -- YYYY-MM-DD
);
```

### skills Tabelle
```sql
CREATE TABLE skills (
    id INTEGER PRIMARY KEY,
    name TEXT,
    version TEXT,
    status TEXT,           -- installed, local, published
    description TEXT,
    path TEXT
);
```

## tree.db v2 Schema

### tree_entries_v2 Tabelle
```sql
CREATE TABLE tree_entries_v2 (
    id INTEGER PRIMARY KEY,
    file_id TEXT UNIQUE,              -- Eindeutige ID (MD5 Hash)
    root_path TEXT NOT NULL,
    relative_path TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT,                        -- file, directory, symlink
    depth INTEGER,
    parent_path TEXT,
    
    -- Größen-Tracking
    size_bytes INTEGER,
    previous_size_bytes INTEGER,      -- Für Delta
    size_change_bytes INTEGER,        -- Änderung +/-
    
    -- Zeitstempel
    mtime_timestamp REAL,             -- Unix timestamp
    mtime_iso TEXT,                   -- ISO 8601
    first_seen_timestamp REAL,        -- Erstsichtung
    last_seen_timestamp REAL,         -- Letztsichtung
    
    -- Änderungs-Tracking
    change_type TEXT,                 -- NEW, MODIFIED, MOVED, RENAMED, UNCHANGED, DELETED
    
    -- Historie
    original_name TEXT,               -- Ursprünglicher Name
    original_path TEXT,               -- Ursprünglicher Pfad
    previous_path TEXT,               -- Vorheriger Pfad
    
    -- Integrität
    content_hash TEXT                 -- Optional: MD5 der Datei
);
```

### file_history Tabelle
```sql
CREATE TABLE file_history (
    id INTEGER PRIMARY KEY,
    file_id TEXT NOT NULL,
    timestamp REAL NOT NULL,
    change_type TEXT NOT NULL,        -- MODIFIED, MOVED, RENAMED
    old_path TEXT,
    new_path TEXT,
    old_size INTEGER,
    new_size INTEGER
);
```

## Tracking-Features

| Feature | Beschreibung |
|---------|--------------|
| **file_id** | Eindeutige Datei-ID basierend auf Pfad-Hash |
| **Größen-Delta** | `size_change_bytes` zeigt +/- Änderung |
| **Änderungs-Typ** | NEW, MODIFIED, MOVED, RENAMED, UNCHANGED, DELETED |
| **Historie** | Vollständige Änderungshistorie in `file_history` |
| **Umbenennung** | `original_name` behält ursprünglichen Namen |
| **Verschiebung** | `original_path` + `previous_path` für Tracking |
| **Zeitstempel** | Erst- und Letztsichtung in Unix + ISO Format |

## Verwendung

### Abfragen

```bash
# Alle geänderten Dateien letzte 24h
sqlite3 db/tree.db "
  SELECT name, relative_path, size_change_bytes, mtime_iso
  FROM tree_entries_v2
  WHERE change_type IN ('NEW', 'MODIFIED')
  AND last_seen_timestamp > (strftime('%s', 'now') - 86400)
"

# Datei-Größen-Entwicklung
sqlite3 db/tree.db "
  SELECT timestamp, old_size, new_size, change_type
  FROM file_history
  WHERE file_id = 'abc123def4567890'
  ORDER BY timestamp DESC
"

# Verschobene Dateien
sqlite3 db/tree.db "
  SELECT name, original_path, relative_path
  FROM tree_entries_v2
  WHERE change_type = 'MOVED'
"
```

### Exporte

```bash
# JSON Export
tree_changes_last_24h.json

# CSV Export
export_tree_*.csv
```

## Backup-Strategie

| Intervall | Retention | Ort |
|-----------|-----------|-----|
| Stündlich | 3 Tage (72h) | `db/backups/` |
| Automatisch | Vor DB-Update | Temporär |

```
db/backups/
├── 2026-04-18_11-00_docs.db.bak
├── 2026-04-18_11-00_tree.db.bak
├── 2026-04-18_12-00_docs.db.bak
├── ...
(Alle Backups der letzten 72 Stunden)
```

## Revisionssicherheit

Die Kombination aus docs.db und tree.db v2 ermöglicht:

1. **Vollständige Nachvollziehbarkeit** aller Dateiänderungen
2. **Historie** über beliebige Zeiträume (begrenzt durch Backup-Retention)
3. **Integritätsprüfung** durch Content-Hashes
4. **Beweissicherung** für Audit-Trail

## Multi-Node Operation

```python
# Node-Prüfung vor Ausführung
if alternate_node.available():
    spawn_subagent(node=alternate_node, task=task)
else:
    execute_locally(task)  # Fallback
```

## Zugehörige Skills

| Skill | Zweck | Veröffentlicht |
|-------|-------|----------------|
| **workspace-db** | Öffentliche Datenbank-API | ✅ ClawHub |
| **db-maintainer** | Interner Wartungs-Agent | 🔒 Lokal |

## Links

- [SKILL-INDEX.md](../../SKILL-INDEX.md) - Übersicht aller Skills
- [WORKSPACE-INDEX.md](../../WORKSPACE-INDEX.md) - Dateistruktur
- [WEBSEARCH_MCP_GUIDE.md](../websearch-mcp/WEBSEARCH_MCP_GUIDE.md) - WebSearch Integration
