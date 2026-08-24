#!/usr/bin/env python3
"""Scan documentation files and refresh docs.db for the mounted workspace."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import sqlite3
from pathlib import Path
from time import time

WORKSPACE = Path(os.environ.get('OPENCLAW_WORKSPACE', Path(__file__).resolve().parents[1]))
DB_PATH = WORKSPACE / 'db' / 'docs.db'


def iter_docs():
    for md_file in WORKSPACE.rglob('*.md'):
        if not md_file.is_file() or md_file.is_symlink():
            continue
        rel = md_file.relative_to(WORKSPACE)
        if any(part in {'node_modules', '.git', 'backups'} for part in rel.parts):
            continue
        yield md_file


def file_hash(path: Path) -> str:
    digest = hashlib.md5()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(8192), b''):
            digest.update(chunk)
    return digest.hexdigest()


def word_count(path: Path) -> int:
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return 0
    return len(text.split())


def build_rows():
    indexed = time()
    rows = []
    for md_file in iter_docs():
        rows.append(
            {
                'path': str(md_file.relative_to(WORKSPACE)),
                'content_hash': file_hash(md_file),
                'last_indexed': indexed,
                'word_count': word_count(md_file),
            }
        )
    return rows


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        '''
        CREATE TABLE IF NOT EXISTS documents (
            path TEXT PRIMARY KEY,
            content_hash TEXT,
            last_indexed REAL,
            word_count INTEGER
        )
        '''
    )
    conn.execute(
        '''
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT,
            tag TEXT
        )
        '''
    )


def update_database(rows):
    conn = sqlite3.connect(DB_PATH)
    try:
        ensure_schema(conn)
        cur = conn.cursor()
        cur.execute('DELETE FROM documents')
        cur.executemany(
            'INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (?, ?, ?, ?)',
            [(row['path'], row['content_hash'], row['last_indexed'], row['word_count']) for row in rows],
        )
        conn.commit()
    finally:
        conn.close()


def export_table(table: str):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(f'SELECT * FROM {table}').fetchall()
        data = [dict(row) for row in rows]
        json_path = WORKSPACE / f'db_{table}.json'
        csv_path = WORKSPACE / f'db_{table}.csv'
        json_path.write_text(json.dumps(data, indent=2, default=str))
        with csv_path.open('w', newline='') as fh:
            writer = csv.writer(fh)
            if rows:
                writer.writerow(rows[0].keys())
                writer.writerows([row[key] for key in rows[0].keys()] for row in rows)
            else:
                writer.writerow([])
    finally:
        conn.close()


def main():
    print('=' * 60)
    print('DOCS.DB UPDATER')
    print('=' * 60)
    rows = build_rows()
    print(f'Gefunden: {len(rows)} Dokumente')
    update_database(rows)
    print(f'✅ {len(rows)} Dokumente in docs.db aktualisiert')
    export_table('documents')
    export_table('tags')
    print('✅ Exporte aktualisiert')
    print('\n' + '=' * 60)
    print('DOCS.DB AKTUALISIERT')
    print('=' * 60)


if __name__ == '__main__':
    main()
