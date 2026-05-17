#!/usr/bin/env python3
"""
Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db
"""

import sqlite3
from pathlib import Path
from datetime import datetime

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
DB_PATH = WORKSPACE / "db" / "docs.db"


def scan_documentations():
    """Scannt alle .md Dateien im Workspace"""
    docs = []
    
    # Hauptverzeichnis
    for md_file in WORKSPACE.glob("*.md"):
        if md_file.is_file() and not md_file.is_symlink():
            docs.append({
                'name': md_file.name,
                'path': '/',
                'category': 'main',
                'description': get_description(md_file),
                'type': 'doc',
                'has_symlink': False,
                'symlink_path': None,
                'last_update': get_mtime(md_file)
            })
    
    # WebSearch Verzeichnis
    websearch_dir = WORKSPACE / "websearch"
    if websearch_dir.exists():
        for md_file in websearch_dir.glob("*.md"):
            docs.append({
                'name': md_file.name,
                'path': 'websearch/',
                'category': 'websearch',
                'description': get_description(md_file),
                'type': 'guide' if 'GUIDE' in md_file.name else 'config',
                'has_symlink': True,
                'symlink_path': f'websearch/{md_file.name}',
                'last_update': get_mtime(md_file)
            })
    
    # MCP Verzeichnis
    mcp_dir = WORKSPACE / "mcp"
    if mcp_dir.exists():
        for md_file in mcp_dir.glob("*.md"):
            docs.append({
                'name': md_file.name,
                'path': 'mcp/',
                'category': 'mcp',
                'description': get_description(md_file),
                'type': 'symlink' if md_file.is_symlink() else 'guide',
                'has_symlink': md_file.is_symlink(),
                'symlink_path': str(md_file.readlink()) if md_file.is_symlink() else None,
                'last_update': get_mtime(md_file)
            })
    
    # Docs-Unterverzeichnisse
    docs_dir = WORKSPACE / "docs"
    if docs_dir.exists():
        for subdir in docs_dir.iterdir():
            if subdir.is_dir():
                for md_file in subdir.glob("*.md"):
                    docs.append({
                        'name': md_file.name,
                        'path': f'docs/{subdir.name}/',
                        'category': subdir.name,
                        'description': get_description(md_file),
                        'type': 'doc',
                        'has_symlink': False,
                        'symlink_path': None,
                        'last_update': get_mtime(md_file)
                    })
    
    # Cluster, Memory, Reports, Skills
    for category in ['cluster', 'memory', 'reports', 'skills']:
        cat_dir = WORKSPACE / category
        if cat_dir.exists():
            for md_file in cat_dir.glob("*.md"):
                docs.append({
                    'name': md_file.name,
                    'path': f'{category}/',
                    'category': category,
                    'description': get_description(md_file),
                    'type': 'doc',
                    'has_symlink': False,
                    'symlink_path': None,
                    'last_update': get_mtime(md_file)
                })
    
    return docs


def get_description(md_file):
    """Extrahiert erste Zeile als Beschreibung"""
    try:
        with open(md_file, 'r') as f:
            first_line = f.readline().strip()
            if first_line.startswith('#'):
                return first_line.lstrip('#').strip()
            return first_line[:50] + '...' if len(first_line) > 50 else first_line
    except:
        return 'Dokumentation'


def get_mtime(md_file):
    """Gibt letzte Änderung zurück"""
    try:
        mtime = md_file.stat().st_mtime
        return datetime.fromtimestamp(mtime).strftime('%Y-%m-%d')
    except:
        return '2026-04-18'


def update_database(docs):
    """Aktualisiert docs.db mit allen gefundenen Dokumenten"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Lösche alte Einträge (außer config)
    cursor.execute("DELETE FROM documents WHERE category != 'config'")
    
    # Füge neue ein
    inserted = 0
    for doc in docs:
        cursor.execute('''
            INSERT INTO documents 
            (name, path, category, description, type, has_symlink, symlink_path, last_update)
            VALUES (?,?,?,?,?,?,?,?)
        ''', (
            doc['name'], doc['path'], doc['category'],
            doc['description'], doc['type'], doc['has_symlink'],
            doc['symlink_path'], doc['last_update']
        ))
        inserted += 1
    
    conn.commit()
    conn.close()
    
    return inserted


def export_all():
    """Erstellt alle Exporte"""
    import json
    import csv
    
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # JSON Export
    tables = ['documents', 'skills', 'symlinks']
    for table in tables:
        cursor.execute(f"SELECT * FROM {table}")
        rows = cursor.fetchall()
        
        data = [dict(row) for row in rows]
        json_path = WORKSPACE / f"db_{table}.json"
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        print(f"✅ {json_path}")
        
        # CSV Export
        csv_path = WORKSPACE / f"db_{table}.csv"
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([col[0] for col in cursor.description])
            writer.writerows(rows)
        print(f"✅ {csv_path}")
    
    conn.close()


def main():
    print("="*60)
    print("DOCS.DB UPDATER")
    print("="*60)
    
    print("\n--- Scanne Dokumentationen ---")
    docs = scan_documentations()
    print(f"Gefunden: {len(docs)} Dokumente")
    
    print("\n--- Aktualisiere docs.db ---")
    inserted = update_database(docs)
    print(f"✅ {inserted} Dokumente in docs.db aktualisiert")
    
    print("\n--- Erstelle Exporte ---")
    export_all()
    
    print("\n" + "="*60)
    print("DOCS.DB AKTUALISIERT")
    print("="*60)


if __name__ == "__main__":
    main()
