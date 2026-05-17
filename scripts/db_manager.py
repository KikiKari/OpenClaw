#!/usr/bin/env python3
"""
Workspace Documentation Database Manager
Erstellt und verwaltet docs.db und tree.db
"""

import sqlite3
import json
import csv
from pathlib import Path
from datetime import datetime

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
DB_DIR = WORKSPACE / "db"

# Sicherstellen dass db/ existiert
DB_DIR.mkdir(exist_ok=True)

class DocsDatabase:
    """Verwaltet Dokumentationen, Links und Indexe"""
    
    def __init__(self):
        self.db_path = DB_DIR / "docs.db"
        self.conn = None
        
    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self.conn
        
    def init_schema(self):
        """Erstellt Tabellenstruktur"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Hauptdokumente
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                path TEXT NOT NULL,
                category TEXT,
                description TEXT,
                type TEXT CHECK(type IN ('config', 'doc', 'guide', 'script', 'symlink')),
                has_symlink BOOLEAN DEFAULT FALSE,
                symlink_path TEXT,
                last_update TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Kategorien
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                priority INTEGER DEFAULT 0
            )
        ''')
        
        # Symlinks
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS symlinks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                target TEXT NOT NULL,
                source_path TEXT NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Skills
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS skills (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                version TEXT,
                status TEXT CHECK(status IN ('installed', 'local', 'published')),
                description TEXT,
                path TEXT
            )
        ''')
        
        conn.commit()
        print(f"✅ docs.db erstellt: {self.db_path}")
        return self
        
    def populate_from_workspace(self):
        """Füllt DB aus bestehenden Dateien"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Kategorien einfügen
        categories = [
            ('main', 'Hauptverzeichnis Dateien', 1),
            ('memory', 'Memory und Protokolle', 2),
            ('reports', 'Berichte und Analysen', 3),
            ('cluster', 'Cluster und Infrastruktur', 4),
            ('skills', 'Installierte Skills', 5),
            ('websearch', 'WebSearch Dokumentationen', 6),
            ('mcp', 'MCP Integration', 7),
            ('links', 'Symbolische Links', 8),
        ]
        cursor.executemany(
            'INSERT OR IGNORE INTO categories (name, description, priority) VALUES (?,?,?)',
            categories
        )
        
        # Dokumente einfügen (Basierend auf DOCUMENTATION-INDEX.md)
        docs = [
            ('AGENTS.md', '/', 'main', 'Agent-Konfiguration, Memory-Regeln', 'config', False, None, '2026-04-11'),
            ('SOUL.md', '/', 'main', 'Agent-Persönlichkeit und Kernwahrheiten', 'config', False, None, '2026-04-11'),
            ('IDENTITY.md', '/', 'main', 'Agent-Name und Eigenschaften', 'config', False, None, '2026-04-11'),
            ('USER.md', '/', 'main', 'Benutzerinformationen', 'config', False, None, '2026-04-11'),
            ('TOOLS.md', '/', 'main', 'Tool-spezifische Konfigurationen', 'config', False, None, '2026-04-18'),
            ('MEMORY.md', '/', 'main', 'Langzeitspeicher, System-Konfiguration', 'config', False, None, '2026-04-11'),
            ('DOCUMENTATION-INDEX.md', '/', 'main', 'Übersicht aller Dokumentationen', 'doc', False, None, '2026-04-18'),
            ('WORKSPACE-INDEX.md', '/', 'main', 'Symlink zu DOCUMENTATION-INDEX.md', 'symlink', True, 'DOCUMENTATION-INDEX.md', '2026-04-18'),
            
            ('WEBSEARCH_README.md', 'websearch/', 'websearch', 'Schnellstart Guide', 'guide', True, 'websearch/WEBSEARCH_README.md', '2026-04-18'),
            ('WEBSEARCH_MCP_GUIDE.md', 'websearch/', 'websearch', 'Vollständige technische Dokumentation', 'guide', True, 'websearch/WEBSEARCH_MCP_GUIDE.md', '2026-04-18'),
            ('WEBSEARCH_CONFIG.md', 'websearch/', 'websearch', 'Konfigurations-Referenz', 'config', True, 'websearch/WEBSEARCH_CONFIG.md', '2026-04-18'),
            ('WEBSEARCH_PRIORITY_CONFIG.md', 'websearch/', 'websearch', 'Provider-Priorität', 'config', True, 'websearch/WEBSEARCH_PRIORITY_CONFIG.md', '2026-04-18'),
            ('WEBSEARCH_SCRIPTS.md', 'websearch/', 'websearch', 'Automation & Scripting', 'script', True, 'websearch/WEBSEARCH_SCRIPTS.md', '2026-04-18'),
            ('WEBSEARCH_OPS.md', 'websearch/', 'websearch', 'IT-Operations', 'guide', True, 'websearch/WEBSEARCH_OPS.md', '2026-04-18'),
            ('MCP_GUIDE.md', 'mcp/', 'mcp', 'Symlink zu websearch/WEBSEARCH_MCP_GUIDE.md', 'symlink', False, 'websearch/WEBSEARCH_MCP_GUIDE.md', '2026-04-18'),
        ]
        
        cursor.executemany('''
            INSERT OR REPLACE INTO documents 
            (name, path, category, description, type, has_symlink, symlink_path, last_update)
            VALUES (?,?,?,?,?,?,?,?)
        ''', docs)
        
        # Skills einfügen
        skills = [
            ('json-utils', '1.0.0', 'installed', 'JSON parsing and validation', 'skills/json-utils/'),
            ('scripting-utils', '1.0.0', 'installed', 'Multi-language scripting support', 'skills/scripting-utils/'),
            ('tiktok-live-mon', '1.0.0', 'installed', 'TikTok stream monitoring', 'skills/tiktok-live-mon/'),
            ('cluster-management', '1.0.0', 'installed', 'Cluster topology management', 'skills/cluster-management/'),
            ('worker-node', '-', 'local', 'Worker node configuration', 'skills/worker-node/'),
            ('resource-manager', '-', 'local', 'Resource management', 'skills/resource-manager/'),
            ('git-publish-agent', '1.0.0', 'local', 'Git publishing automation', 'skills/git-publish-agent/'),
        ]
        cursor.executemany('''
            INSERT OR REPLACE INTO skills (name, version, status, description, path)
            VALUES (?,?,?,?,?)
        ''', skills)
        
        # Symlinks einfügen
        symlinks = [
            ('openclaw.env', '/home/openclaw/.config/openclaw/env', '/', 'API-Keys Shortcut'),
            ('openclaw.json', '/home/openclaw/.openclaw/openclaw.json', '/', 'Konfig Shortcut'),
            ('links/config/openclaw-env', '/home/openclaw/.config/openclaw/env', 'links/config/', 'API-Keys'),
            ('links/dotfiles/.tavily', '/home/openclaw/.tavily/', 'links/dotfiles/', 'Tavily Config'),
            ('links/dotfiles/.claude', '/home/openclaw/.claude/', 'links/dotfiles/', 'Claude Config'),
            ('links/dotfiles/.mcporter', '/home/openclaw/.mcporter/', 'links/dotfiles/', 'MCPorter Config'),
            ('links/dotfiles/.ssh', '/home/openclaw/.ssh/', 'links/dotfiles/', 'SSH Keys'),
        ]
        cursor.executemany('''
            INSERT OR REPLACE INTO symlinks (name, target, source_path, description)
            VALUES (?,?,?,?)
        ''', symlinks)
        
        conn.commit()
        print(f"✅ docs.db befüllt mit {len(docs)} Dokumenten, {len(skills)} Skills, {len(symlinks)} Symlinks")
        return self
        
    def export_csv(self, table):
        """Exportiert Tabelle als CSV"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute(f'SELECT * FROM {table}')
        rows = cursor.fetchall()
        
        if not rows:
            return None
            
        csv_path = WORKSPACE / f"export_{table}.csv"
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([col[0] for col in cursor.description])
            writer.writerows(rows)
        
        print(f"✅ CSV exportiert: {csv_path}")
        return csv_path
        
    def export_json(self, table):
        """Exportiert Tabelle als JSON"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute(f'SELECT * FROM {table}')
        rows = cursor.fetchall()
        
        data = [dict(row) for row in rows]
        json_path = WORKSPACE / f"export_{table}.json"
        
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        
        print(f"✅ JSON exportiert: {json_path}")
        return json_path


class TreeDatabase:
    """Verwaltet Verzeichnisbaum-Strukturen"""
    
    def __init__(self):
        self.db_path = DB_DIR / "tree.db"
        self.conn = None
        
    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self.conn
        
    def init_schema(self):
        """Erstellt Tabellenstruktur für Tree-Daten"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tree_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                name TEXT NOT NULL,
                type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
                depth INTEGER,
                parent_path TEXT,
                size INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tree_scans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path TEXT NOT NULL,
                max_depth INTEGER,
                total_files INTEGER,
                total_dirs INTEGER,
                total_symlinks INTEGER,
                scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        print(f"✅ tree.db erstellt: {self.db_path}")
        return self
        
    def add_entry(self, root_path, relative_path, name, entry_type, depth, parent_path, size=0):
        """Fügt einzelnen Eintrag hinzu"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO tree_entries 
            (root_path, relative_path, name, type, depth, parent_path, size)
            VALUES (?,?,?,?,?,?,?)
        ''', (root_path, relative_path, name, entry_type, depth, parent_path, size))
        conn.commit()
        
    def export_csv(self, root_path_filter=None):
        """Exportiert Tree als CSV"""
        conn = self.connect()
        cursor = conn.cursor()
        
        if root_path_filter:
            cursor.execute('SELECT * FROM tree_entries WHERE root_path = ?', (root_path_filter,))
        else:
            cursor.execute('SELECT * FROM tree_entries')
            
        rows = cursor.fetchall()
        
        if not rows:
            return None
            
        suffix = f"_{root_path_filter.replace('/', '_')}" if root_path_filter else "_all"
        csv_path = WORKSPACE / f"export_tree{suffix}.csv"
        
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([col[0] for col in cursor.description])
            writer.writerows(rows)
        
        print(f"✅ Tree CSV exportiert: {csv_path}")
        return csv_path


def main():
    """Hauptfunktion - Initialisierung und Export"""
    print("="*60)
    print("WORKSPACE DATABASE MANAGER")
    print("="*60)
    print()
    
    # docs.db erstellen
    docs_db = DocsDatabase()
    docs_db.init_schema()
    docs_db.populate_from_workspace()
    
    # Exports erstellen
    print("\n--- Exporte docs.db ---")
    docs_db.export_csv('documents')
    docs_db.export_csv('skills')
    docs_db.export_csv('symlinks')
    docs_db.export_json('documents')
    
    # tree.db erstellen
    print("\n--- tree.db Initialisierung ---")
    tree_db = TreeDatabase()
    tree_db.init_schema()
    print("   (Tree-Daten werden via tree.py Script befüllt)")
    
    print("\n" + "="*60)
    print("DATENBANKEN BEREIT")
    print("="*60)
    print(f"\nDatenbanken befinden sich in: {DB_DIR}/")
    print("Exporte befinden sich im Workspace-Root")


if __name__ == "__main__":
    main()
