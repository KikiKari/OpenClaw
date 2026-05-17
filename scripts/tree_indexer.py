#!/usr/bin/env python3
"""
Tree Indexer - Scannt Verzeichnisbäume und speichert in tree.db
"""

import sqlite3
import subprocess
import re
from pathlib import Path
from datetime import datetime

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
DB_DIR = WORKSPACE / "db"


class TreeIndexer:
    def __init__(self):
        self.db_path = DB_DIR / "tree.db"
        self.conn = None
        
    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        return self.conn
    
    def run_tree(self, root_path, max_depth):
        """Führt tree -a -L {depth} aus und parst Ausgabe"""
        try:
            result = subprocess.run(
                ['tree', '-a', f'-L', str(max_depth), str(root_path)],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout
        except Exception as e:
            print(f"❌ Fehler bei tree {root_path}: {e}")
            return None
    
    def parse_tree_output(self, tree_output, root_path):
        """Parst tree-Ausgabe und extrahiert Einträge"""
        entries = []
        lines = tree_output.strip().split('\n')
        
        # Regex für tree-Zeilen
        # Beispiel: "├── .bash_history" oder "│   ├── bin"
        pattern = r'^[│ ]*[├└]── (.+)$'
        
        for line in lines:
            match = re.match(pattern, line)
            if match:
                name = match.group(1).strip()
                # Tiefe bestimmen durch Anzahl der │ und Leerzeichen
                depth = line.count('│') + line.count('    ')
                
                # Typ bestimmen
                if name.endswith('/'):
                    entry_type = 'directory'
                    name = name[:-1]
                elif ' -> ' in name:
                    entry_type = 'symlink'
                    name = name.split(' -> ')[0]
                else:
                    entry_type = 'file'
                
                entries.append({
                    'name': name,
                    'type': entry_type,
                    'depth': depth,
                    'line': line
                })
        
        return entries
    
    def save_to_db(self, root_path, max_depth, entries):
        """Speichert Einträge in tree.db"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Scan-Metadaten
        total_files = sum(1 for e in entries if e['type'] == 'file')
        total_dirs = sum(1 for e in entries if e['type'] == 'directory')
        total_symlinks = sum(1 for e in entries if e['type'] == 'symlink')
        
        cursor.execute('''
            INSERT INTO tree_scans 
            (root_path, max_depth, total_files, total_dirs, total_symlinks)
            VALUES (?,?,?,?,?)
        ''', (str(root_path), max_depth, total_files, total_dirs, total_symlinks))
        
        scan_id = cursor.lastrowid
        
        # Einträge speichern
        for entry in entries:
            cursor.execute('''
                INSERT INTO tree_entries 
                (root_path, relative_path, name, type, depth, parent_path, size)
                VALUES (?,?,?,?,?,?,0)
            ''', (
                str(root_path),
                entry['name'],
                entry['name'],
                entry['type'],
                entry['depth'],
                str(root_path)
            ))
        
        conn.commit()
        print(f"✅ {len(entries)} Einträge gespeichert für {root_path}")
        return scan_id
    
    def index_directory(self, root_path, max_depth):
        """Komplette Indexierung eines Verzeichnisses"""
        print(f"\n--- Indexiere: {root_path} (Depth: {max_depth}) ---")
        tree_output = self.run_tree(root_path, max_depth)
        
        if tree_output:
            entries = self.parse_tree_output(tree_output, root_path)
            if entries:
                return self.save_to_db(root_path, max_depth, entries)
        return None
    
    def export_csv(self):
        """Exportiert alle Tree-Einträge als CSV"""
        conn = self.connect()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM tree_entries ORDER BY root_path, depth, name')
        rows = cursor.fetchall()
        
        if not rows:
            print("⚠️ Keine Tree-Daten vorhanden")
            return None
        
        import csv
        csv_path = WORKSPACE / "export_tree_all.csv"
        
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([col[0] for col in cursor.description])
            writer.writerows(rows)
        
        print(f"✅ Tree CSV exportiert: {csv_path} ({len(rows)} Einträge)")
        return csv_path
    
    def export_by_root(self):
        """Exportiert getrennt nach root_path"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute('SELECT DISTINCT root_path FROM tree_entries')
        roots = cursor.fetchall()
        
        exports = []
        for (root_path,) in roots:
            safe_name = str(root_path).replace('/', '_').replace('.', '')
            csv_path = WORKSPACE / f"export_tree{safe_name}.csv"
            
            cursor.execute(
                'SELECT * FROM tree_entries WHERE root_path = ? ORDER BY depth, name',
                (root_path,)
            )
            rows = cursor.fetchall()
            
            import csv
            with open(csv_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([col[0] for col in cursor.description])
                writer.writerows(rows)
            
            exports.append((root_path, csv_path, len(rows)))
            print(f"✅ Export {root_path}: {csv_path} ({len(rows)} Einträge)")
        
        return exports


def main():
    print("="*60)
    print("TREE INDEXER")
    print("="*60)
    
    indexer = TreeIndexer()
    
    # 1. /home/openclaw/ mit depth 3
    indexer.index_directory('/home/openclaw/', 3)
    
    # 2. Workspace mit depth 6
    indexer.index_directory('/home/openclaw/.openclaw/workspace/', 6)
    
    # Exporte erstellen
    print("\n--- Exporte ---")
    indexer.export_csv()
    indexer.export_by_root()
    
    print("\n" + "="*60)
    print("TREE INDEXIERUNG ABGESCHLOSSEN")
    print("="*60)


if __name__ == "__main__":
    main()
