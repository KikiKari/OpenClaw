#!/usr/bin/env python3
"""
Tree Indexer v2 - Erweitertes Tracking mit Metadaten
"""

import sqlite3
import subprocess
import re
import hashlib
from pathlib import Path
from datetime import datetime

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
DB_DIR = WORKSPACE / "db"


class TreeIndexerV2:
    def __init__(self):
        self.db_path = DB_DIR / "tree.db"
        self.conn = None
        
    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self.conn
    
    def init_schema_v2(self):
        """Erstellt erweiterte Tabellenstruktur"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Haupttabelle mit erweiterten Metadaten
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tree_entries_v2 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_id TEXT UNIQUE,              -- Eindeutige Datei-ID (Hash von Pfad)
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                name TEXT NOT NULL,
                type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
                depth INTEGER,
                parent_path TEXT,
                
                -- Größen-Tracking
                size_bytes INTEGER,               -- Aktuelle Größe
                previous_size_bytes INTEGER,      -- Vorherige Größe (für Delta)
                size_change_bytes INTEGER,        -- Änderung (positiv/negativ)
                
                -- Zeitstempel
                mtime_timestamp REAL,             -- Letzte Änderung (Unix timestamp)
                mtime_iso TEXT,                   -- ISO-Format für Lesbarkeit
                first_seen_timestamp REAL,        -- Wann wurde Datei erste Mal gesehen
                last_seen_timestamp REAL,         -- Wann wurde Datei zuletzt gesehen
                
                -- Änderungs-Tracking
                change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
                
                -- Historie
                original_name TEXT,               -- Ursprünglicher Name wenn umbenannt
                original_path TEXT,               -- Ursprünglicher Pfad wenn verschoben
                previous_path TEXT,               -- Vorheriger Pfad
                
                -- Content-Hash (optionale Integritätsprüfung)
                content_hash TEXT,                -- MD5 der Datei (nur für kleine Dateien)
                
                -- Metadaten
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Historie-Tabelle für alle Änderungen
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS file_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_id TEXT NOT NULL,
                timestamp REAL NOT NULL,
                change_type TEXT NOT NULL,
                old_path TEXT,
                new_path TEXT,
                old_size INTEGER,
                new_size INTEGER,
                FOREIGN KEY (file_id) REFERENCES tree_entries_v2(file_id)
            )
        ''')
        
        # Index für schnelle Suchen
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type)')
        
        conn.commit()
        print("✅ tree.db Schema v2 erstellt/aktualisiert")
        return self
    
    def get_file_metadata(self, full_path):
        """Extrahiert Metadaten einer Datei"""
        try:
            stat = full_path.stat()
            return {
                'size': stat.st_size,
                'mtime': stat.st_mtime,
                'mtime_iso': datetime.fromtimestamp(stat.st_mtime).isoformat(),
            }
        except:
            return {'size': 0, 'mtime': 0, 'mtime_iso': None}
    
    def generate_file_id(self, relative_path):
        """Generiert eindeutige ID aus Pfad"""
        return hashlib.md5(str(relative_path).encode()).hexdigest()[:16]
    
    def scan_directory_detailed(self, root_path, max_depth=8):
        """Detailliertes Scanning mit Metadaten"""
        entries = []
        root = Path(root_path)
        
        for item in root.rglob('*'):
            # Max depth prüfen
            depth = len(item.relative_to(root).parts)
            if depth > max_depth:
                continue
            
            relative_path = item.relative_to(root)
            file_id = self.generate_file_id(relative_path)
            metadata = self.get_file_metadata(item)
            
            entry = {
                'file_id': file_id,
                'root_path': str(root_path),
                'relative_path': str(relative_path),
                'name': item.name,
                'type': 'directory' if item.is_dir() else ('symlink' if item.is_symlink() else 'file'),
                'depth': depth,
                'parent_path': str(relative_path.parent) if relative_path.parent != Path('.') else '',
                'size_bytes': metadata['size'],
                'mtime_timestamp': metadata['mtime'],
                'mtime_iso': metadata['mtime_iso'],
            }
            entries.append(entry)
        
        return entries
    
    def update_database(self, entries):
        """Aktualisiert DB mit Änderungs-Erkennung"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Aktuelle Zeit
        now = datetime.now()
        now_timestamp = now.timestamp()
        
        # Alle bestehenden Einträge als "potentiell gelöscht" markieren
        cursor.execute("UPDATE tree_entries_v2 SET change_type = NULL")
        
        stats = {'new': 0, 'modified': 0, 'unchanged': 0, 'moved': 0}
        
        for entry in entries:
            # Prüfe ob Datei bereits bekannt
            cursor.execute(
                "SELECT * FROM tree_entries_v2 WHERE file_id = ?",
                (entry['file_id'],)
            )
            existing = cursor.fetchone()
            
            if existing:
                # Vergleiche Metadaten
                old_mtime = existing['mtime_timestamp'] or 0
                old_size = existing['size_bytes'] or 0
                old_path = existing['relative_path']
                
                # Größenänderung berechnen
                size_change = entry['size_bytes'] - old_size
                
                # Änderungstyp bestimmen
                if old_path != entry['relative_path']:
                    change_type = 'MOVED'
                    stats['moved'] += 1
                elif old_mtime != entry['mtime_timestamp'] or old_size != entry['size_bytes']:
                    change_type = 'MODIFIED'
                    stats['modified'] += 1
                else:
                    change_type = 'UNCHANGED'
                    stats['unchanged'] += 1
                
                # Update
                cursor.execute('''
                    UPDATE tree_entries_v2 SET
                        size_bytes = ?,
                        previous_size_bytes = ?,
                        size_change_bytes = ?,
                        mtime_timestamp = ?,
                        mtime_iso = ?,
                        last_seen_timestamp = ?,
                        change_type = ?,
                        previous_path = ?,
                        original_path = COALESCE(original_path, ?),
                        updated_at = CURRENT_TIMESTAMP
                    WHERE file_id = ?
                ''', (
                    entry['size_bytes'],
                    old_size,
                    size_change,
                    entry['mtime_timestamp'],
                    entry['mtime_iso'],
                    now_timestamp,
                    change_type,
                    old_path if change_type == 'MOVED' else None,
                    old_path if change_type == 'MOVED' else None,
                    entry['file_id']
                ))
                
                # Änderung in Historie loggen
                if change_type in ['MODIFIED', 'MOVED']:
                    cursor.execute('''
                        INSERT INTO file_history
                        (file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        entry['file_id'],
                        now_timestamp,
                        change_type,
                        old_path,
                        entry['relative_path'],
                        old_size,
                        entry['size_bytes']
                    ))
            else:
                # Neue Datei
                stats['new'] += 1
                cursor.execute('''
                    INSERT INTO tree_entries_v2
                    (file_id, root_path, relative_path, name, type, depth, parent_path,
                     size_bytes, previous_size_bytes, size_change_bytes,
                     mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                     change_type, content_hash)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    entry['file_id'],
                    entry['root_path'],
                    entry['relative_path'],
                    entry['name'],
                    entry['type'],
                    entry['depth'],
                    entry['parent_path'],
                    entry['size_bytes'],
                    entry['size_bytes'],
                    0,
                    entry['mtime_timestamp'],
                    entry['mtime_iso'],
                    now_timestamp,
                    now_timestamp,
                    'NEW',
                    None  # content_hash
                ))
        
        # Markiere nicht aktualisierte Einträge als DELETED
        cursor.execute('''
            SELECT * FROM tree_entries_v2 
            WHERE change_type IS NULL OR last_seen_timestamp < ?
        ''', (now_timestamp - 3600,))  # Älter als 1 Stunde
        
        deleted = cursor.fetchall()
        for item in deleted:
            cursor.execute('''
                UPDATE tree_entries_v2 
                SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP
                WHERE file_id = ?
            ''', (item['file_id'],))
        
        stats['deleted'] = len(deleted)
        
        conn.commit()
        return stats
    
    def export_changes(self, since_hours=24):
        """Exportiert Änderungen der letzten X Stunden"""
        conn = self.connect()
        cursor = conn.cursor()
        
        since = datetime.now().timestamp() - (since_hours * 3600)
        
        cursor.execute('''
            SELECT * FROM tree_entries_v2 
            WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
            AND last_seen_timestamp > ?
            ORDER BY last_seen_timestamp DESC
        ''', (since,))
        
        changes = cursor.fetchall()
        
        # Export als JSON
        import json
        export_file = WORKSPACE / f"tree_changes_last_{since_hours}h.json"
        
        data = [dict(row) for row in changes]
        with open(export_file, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        
        print(f"✅ Änderungen exportiert: {export_file} ({len(changes)} Einträge)")
        return export_file


def main():
    print("="*60)
    print("TREE INDEXER v2 - Erweitertes Tracking")
    print("="*60)
    
    indexer = TreeIndexerV2()
    indexer.init_schema_v2()
    
    print("\n--- Scanning Workspace ---")
    entries = indexer.scan_directory_detailed('/home/openclaw/.openclaw/workspace/', max_depth=8)
    print(f"Gefunden: {len(entries)} Einträge")
    
    print("\n--- Aktualisiere Datenbank ---")
    stats = indexer.update_database(entries)
    print(f"Statistiken:")
    print(f"  NEU:        {stats.get('new', 0)}")
    print(f"  MODIFIED:   {stats.get('modified', 0)}")
    print(f"  MOVED:      {stats.get('moved', 0)}")
    print(f"  UNCHANGED:  {stats.get('unchanged', 0)}")
    print(f"  DELETED:    {stats.get('deleted', 0)}")
    
    print("\n--- Exportiere Änderungen (24h) ---")
    indexer.export_changes(since_hours=24)
    
    print("\n" + "="*60)
    print("TREE INDEXING ABGESCHLOSSEN")
    print("="*60)


if __name__ == "__main__":
    main()
