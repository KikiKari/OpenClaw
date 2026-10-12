#!/usr/bin/env python3
"""Fallback tree generator for when the `tree` binary is unavailable.

Produces output similar to `tree -a -L <depth>` and writes it to
important/openclaw-tree.txt with a timestamp header.
"""
import sys
from datetime import datetime
from pathlib import Path

WORKSPACE = Path("/workspace")
DEPTH = 6
SKIP = {".git", "node_modules", "__pycache__", "venv", ".cache", ".npm", ".local"}
OUT = WORKSPACE / "important" / "openclaw-tree.txt"


def walk(path, prefix="", depth=0):
    lines = []
    if depth >= DEPTH:
        return lines
    try:
        entries = sorted(path.iterdir(), key=lambda p: (not p.is_dir(), p.name))
    except (PermissionError, OSError):
        return lines
    entries = [e for e in entries if e.name not in SKIP]
    for i, entry in enumerate(entries):
        last = i == len(entries) - 1
        connector = "└── " if last else "├── "
        suffix = "/" if entry.is_dir() else ""
        lines.append(f"{prefix}{connector}{entry.name}{suffix}")
        if entry.is_dir() and not entry.is_symlink():
            extension = "    " if last else "│   "
            lines.extend(walk(entry, prefix + extension, depth + 1))
    return lines


def main():
    lines = [str(WORKSPACE)]
    lines.extend(walk(WORKSPACE))
    body = "\n".join(lines) + "\n"
    header = (
        f"# OpenClaw Workspace Tree\n"
        f"# Generiert: {datetime.now().isoformat()}\n"
        f"# Fallback (tree binary nicht verfuegbar), Tiefe {DEPTH}\n"
        f"# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(header + body)
    print(f"openclaw-tree.txt aktualisiert (Fallback): {OUT} ({len(lines)} Eintraege)")


if __name__ == "__main__":
    main()
