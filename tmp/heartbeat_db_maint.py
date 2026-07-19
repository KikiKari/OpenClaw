#!/usr/bin/env python3
from __future__ import annotations

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


def refresh_docs_db(now_iso: str) -> dict[str, int]:
    conn = sqlite3.connect(DOCS_DB)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT UNIQUE,
                mtime REAL,
                size INTEGER,
                type TEXT,
                last_checked TEXT
            )
            """
        )

        old_rows: dict[str, tuple[float | None, int | None, str | None]] = {}
        if table_exists(conn, "documents"):
            for path, mtime, size, typ in conn.execute(
                "SELECT path, mtime, size, type FROM documents"
            ):
                old_rows[path] = (mtime, size, typ)

        rows: list[tuple[str, float, int, str, str]] = []
        for md_file in WORKSPACE.rglob("*.md"):
            if not md_file.is_file() or md_file.is_symlink():
                continue
            rel = md_file.relative_to(WORKSPACE)
            if any(part in {"node_modules", ".git", "backups"} for part in rel.parts):
                continue
            stat = md_file.stat()
            rows.append((str(rel), stat.st_mtime, stat.st_size, "doc", now_iso))

        new_rows = {path: (mtime, size, typ) for path, mtime, size, typ, _ in rows}
        added = sum(1 for path in new_rows if path not in old_rows)
        changed = sum(1 for path in new_rows if path in old_rows and old_rows[path] != new_rows[path])
        deleted = sum(1 for path in old_rows if path not in new_rows)

        conn.execute("DELETE FROM documents")
        conn.executemany(
            "INSERT INTO documents (path, mtime, size, type, last_checked) VALUES (?, ?, ?, ?, ?)",
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


def refresh_tree_db() -> dict[str, int]:
    conn = sqlite3.connect(TREE_DB)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tree_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                name TEXT NOT NULL,
                type TEXT CHECK(type IN ("file", "directory", "symlink")),
                depth INTEGER,
                parent_path TEXT,
                size INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tree_scans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                root_path TEXT NOT NULL,
                max_depth INTEGER,
                total_files INTEGER,
                total_dirs INTEGER,
                total_symlinks INTEGER,
                scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )

        old_count = 0
        if table_exists(conn, "tree_entries"):
            old_count = conn.execute("SELECT COUNT(*) FROM tree_entries").fetchone()[0]

        entries: list[tuple[str, str, str, str, int, str, int]] = []
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
                size = item.lstat().st_size
            elif item.is_dir():
                typ = "directory"
                total_dirs += 1
                size = 0
            else:
                typ = "file"
                total_files += 1
                size = item.stat().st_size

            parent_path = str(rel.parent) if rel.parent != Path(".") else ""
            entries.append(
                (
                    str(WORKSPACE),
                    str(rel),
                    item.name,
                    typ,
                    depth,
                    parent_path,
                    size,
                )
            )

        conn.execute("DELETE FROM tree_entries")
        conn.execute("DELETE FROM tree_scans")
        conn.execute(
            "INSERT INTO tree_scans (root_path, max_depth, total_files, total_dirs, total_symlinks) VALUES (?, ?, ?, ?, ?)",
            (str(WORKSPACE), 6, total_files, total_dirs, total_symlinks),
        )
        conn.executemany(
            "INSERT INTO tree_entries (root_path, relative_path, name, type, depth, parent_path, size) VALUES (?, ?, ?, ?, ?, ?, ?)",
            entries,
        )
        conn.commit()
        return {
            "count": len(entries),
            "old_count": old_count,
            "files": total_files,
            "dirs": total_dirs,
            "symlinks": total_symlinks,
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
    docs_stats = refresh_docs_db(now_iso)
    tree_stats = refresh_tree_db()
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
        f"previous={tree_stats['old_count']}"
    )
    print(f"backups_created={len(backups)} backups_deleted={len(deleted)}")


if __name__ == "__main__":
    main()
