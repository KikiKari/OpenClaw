#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sqlite3
import subprocess
import shutil
from datetime import datetime, timedelta
from pathlib import Path


WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
DB_DIR = WORKSPACE / "db"
BACKUP_DIR = DB_DIR / "backups"
IMPORTANT_DIR = WORKSPACE / "important"
TREE_FILE = IMPORTANT_DIR / "openclaw-tree.txt"
DOCS_DB = DB_DIR / "docs.db"
TREE_DB = DB_DIR / "tree.db"


def table_exists(conn: sqlite3.Connection, name: str) -> bool:
    row = conn.execute(
        'SELECT 1 FROM sqlite_master WHERE type="table" AND name=?',
        (name,),
    ).fetchone()
    return row is not None


def file_hash(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(8192), b""):
            digest.update(chunk)
    return digest.hexdigest()


def word_count(path: Path) -> int:
    try:
        return len(path.read_text(encoding="utf-8", errors="ignore").split())
    except Exception:
        return 0


def refresh_docs_db(now_ts: float) -> dict[str, int]:
    conn = sqlite3.connect(DOCS_DB)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                path TEXT PRIMARY KEY,
                content_hash TEXT,
                last_indexed REAL,
                word_count INTEGER
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doc_path TEXT,
                tag TEXT,
                FOREIGN KEY(doc_path) REFERENCES documents(path)
            )
            """
        )

        old_rows: dict[str, tuple[str | None, int | None]] = {}
        if table_exists(conn, "documents"):
            for path, content_hash, count in conn.execute(
                "SELECT path, content_hash, word_count FROM documents"
            ):
                old_rows[path] = (content_hash, count)

        rows: list[tuple[str, str, float, int]] = []
        for md_file in WORKSPACE.rglob("*.md"):
            if not md_file.is_file() or md_file.is_symlink():
                continue
            rel = md_file.relative_to(WORKSPACE)
            if any(part in {"node_modules", ".git", "backups"} for part in rel.parts):
                continue
            rows.append((str(rel), file_hash(md_file), now_ts, word_count(md_file)))

        new_rows = {path: (content_hash, count) for path, content_hash, _, count in rows}
        added = sum(1 for path in new_rows if path not in old_rows)
        changed = sum(
            1
            for path in new_rows
            if path in old_rows and old_rows[path] != new_rows[path]
        )
        deleted = sum(1 for path in old_rows if path not in new_rows)

        conn.execute("DELETE FROM documents")
        conn.executemany(
            "INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (?, ?, ?, ?)",
            rows,
        )
        conn.commit()
        return {
            "count": len(rows),
            "added": added,
            "changed": changed,
            "deleted": deleted,
        }
    finally:
        conn.close()


def refresh_tree_db(now_ts: float) -> dict[str, int]:
    conn = sqlite3.connect(TREE_DB)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tree_entries_v2 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_id TEXT UNIQUE,
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                name TEXT NOT NULL,
                type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
                depth INTEGER,
                parent_path TEXT,
                size_bytes INTEGER,
                previous_size_bytes INTEGER,
                size_change_bytes INTEGER,
                mtime_timestamp REAL,
                mtime_iso TEXT,
                first_seen_timestamp REAL,
                last_seen_timestamp REAL,
                change_type TEXT,
                original_name TEXT,
                original_path TEXT,
                previous_path TEXT,
                content_hash TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
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
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS scan_log (
                timestamp REAL,
                total_files INTEGER,
                total_dirs INTEGER,
                duration REAL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tree (
                path TEXT PRIMARY KEY,
                type TEXT,
                size INTEGER,
                mtime REAL,
                hash TEXT
            )
            """
        )

        old_rows: dict[str, tuple[int | None, float | None, str | None]] = {}
        if table_exists(conn, "tree_entries_v2"):
            for path, size_bytes, mtime_ts, typ in conn.execute(
                "SELECT relative_path, size_bytes, mtime_timestamp, type FROM tree_entries_v2"
            ):
                old_rows[path] = (size_bytes, mtime_ts, typ)

        entries_v2: list[tuple[object, ...]] = []
        legacy_tree_rows: list[tuple[str, str, int, float, str]] = []
        total_files = 0
        total_dirs = 0
        total_symlinks = 0

        for item in WORKSPACE.rglob("*"):
            rel = item.relative_to(WORKSPACE)
            depth = len(rel.parts)
            if depth > 6:
                continue

            if item.is_symlink():
                typ = "symlink"
                total_symlinks += 1
                stat = item.lstat()
                size = stat.st_size
                mtime_ts = stat.st_mtime
            elif item.is_dir():
                typ = "directory"
                total_dirs += 1
                size = 0
                mtime_ts = item.stat().st_mtime
            else:
                typ = "file"
                total_files += 1
                stat = item.stat()
                size = stat.st_size
                mtime_ts = stat.st_mtime

            rel_str = str(rel)
            file_id = hashlib.md5(rel_str.encode()).hexdigest()[:16]
            parent_path = str(rel.parent) if rel.parent != Path(".") else ""
            mtime_iso = datetime.fromtimestamp(mtime_ts).isoformat()
            entries_v2.append(
                (
                    file_id,
                    str(WORKSPACE),
                    rel_str,
                    item.name,
                    typ,
                    depth,
                    parent_path,
                    size,
                    size,
                    0,
                    mtime_ts,
                    mtime_iso,
                    now_ts,
                    now_ts,
                    "NEW",
                    None,
                    None,
                    None,
                    None,
                    now_ts,
                    now_ts,
                )
            )
            legacy_tree_rows.append(
                (rel_str, typ, size, mtime_ts, file_hash(item) if item.is_file() else "")
            )

        new_rows = {
            entry[2]: (entry[7], entry[10], entry[4]) for entry in entries_v2
        }
        added = sum(1 for path in new_rows if path not in old_rows)
        changed = sum(
            1
            for path in new_rows
            if path in old_rows and old_rows[path] != new_rows[path]
        )
        deleted = sum(1 for path in old_rows if path not in new_rows)

        conn.execute("DELETE FROM tree_entries_v2")
        conn.execute("DELETE FROM file_history")
        conn.execute("DELETE FROM scan_log")
        conn.execute("DELETE FROM tree")
        conn.executemany(
            """
            INSERT INTO tree_entries_v2 (
                file_id, root_path, relative_path, name, type, depth, parent_path,
                size_bytes, previous_size_bytes, size_change_bytes,
                mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                change_type, original_name, original_path, previous_path, content_hash,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            entries_v2,
        )
        conn.executemany(
            "INSERT INTO tree (path, type, size, mtime, hash) VALUES (?, ?, ?, ?, ?)",
            legacy_tree_rows,
        )
        conn.execute(
            "INSERT INTO scan_log (timestamp, total_files, total_dirs, duration) VALUES (?, ?, ?, ?)",
            (now_ts, total_files, total_dirs, 0.0),
        )
        conn.commit()
        return {
            "count": len(entries_v2),
            "old_count": len(old_rows),
            "files": total_files,
            "dirs": total_dirs,
            "symlinks": total_symlinks,
            "added": added,
            "changed": changed,
            "deleted": deleted,
        }
    finally:
        conn.close()


def write_tree_file(tree_output: str, now_iso: str) -> None:
    TREE_FILE.write_text(
        "# OpenClaw Workspace Tree\n"
        f"# Generiert: {now_iso}\n"
        f"# Befehl: tree -a -L 6 {WORKSPACE}\n"
        "# Diese Datei wird automatisch aktualisiert\n\n"
        + tree_output,
        encoding="utf-8",
    )


def create_backups(timestamp: str) -> list[str]:
    created: list[str] = []
    for db_path in (DOCS_DB, TREE_DB):
        if db_path.exists():
            backup_path = BACKUP_DIR / f"{timestamp}_{db_path.name}.bak"
            shutil.copy2(db_path, backup_path)
            created.append(backup_path.name)
    return created


def cleanup_backups() -> list[str]:
    cutoff = datetime.now() - timedelta(days=3)
    deleted: list[str] = []
    for backup in BACKUP_DIR.glob("*.bak"):
        if datetime.fromtimestamp(backup.stat().st_mtime) < cutoff:
            backup.unlink()
            deleted.append(backup.name)
    return deleted


def main() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    IMPORTANT_DIR.mkdir(parents=True, exist_ok=True)
    DB_DIR.mkdir(parents=True, exist_ok=True)

    now = datetime.now()
    now_iso = now.isoformat(timespec="seconds")
    now_ts = now.timestamp()
    timestamp = now.strftime("%Y-%m-%d_%H-%M")

    tree_run = subprocess.run(
        ["tree", "-a", "-L", "6", str(WORKSPACE)],
        capture_output=True,
        text=True,
        timeout=180,
    )
    if tree_run.returncode != 0:
        raise SystemExit(tree_run.stderr.strip() or "tree command failed")

    write_tree_file(tree_run.stdout, now_iso)
    docs_stats = refresh_docs_db(now_ts)
    tree_stats = refresh_tree_db(now_ts)
    backups = create_backups(timestamp)
    deleted = cleanup_backups()

    print(f"tree_output_lines={len(tree_run.stdout.splitlines())}")
    print(
        "docs_db_count="
        f"{docs_stats['count']} added={docs_stats['added']} "
        f"changed={docs_stats['changed']} deleted={docs_stats['deleted']}"
    )
    print(
        "tree_db_count="
        f"{tree_stats['count']} files={tree_stats['files']} "
        f"dirs={tree_stats['dirs']} symlinks={tree_stats['symlinks']} "
        f"previous={tree_stats['old_count']} added={tree_stats['added']} "
        f"changed={tree_stats['changed']} deleted={tree_stats['deleted']}"
    )
    print(f"backups_created={len(backups)} backups_deleted={len(deleted)}")


if __name__ == "__main__":
    main()
