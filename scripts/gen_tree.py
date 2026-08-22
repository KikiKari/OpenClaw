#!/usr/bin/env python3
"""Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
(used because the `tree` binary is unavailable in this sandbox)."""
import os
from datetime import datetime

ROOT = "/workspace"
OUT = "/workspace/important/openclaw-tree.txt"
MAX_DEPTH = 6


def collect(path, prefix="", depth=1):
    lines = []
    try:
        entries = sorted(os.listdir(path))
    except OSError:
        return lines
    total = len(entries)
    for i, name in enumerate(entries):
        is_last = (i == total - 1)
        connector = "\u2514\u2500\u2500 " if is_last else "\u251c\u2500\u2500 "
        lines.append(prefix + connector + name)
        full = os.path.join(path, name)
        if depth < MAX_DEPTH and os.path.isdir(full) and not os.path.islink(full):
            next_prefix = prefix + ("    " if is_last else "\u2502   ")
            lines.extend(collect(full, next_prefix, depth + 1))
    return lines


body = collect(ROOT)
header = (
    "# OpenClaw Workspace Tree\n"
    f"# Generiert: {datetime.now().isoformat()}\n"
    f"# Befehl: tree -a -L 6 {ROOT} (emuliert via gen_tree.py)\n"
    "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
)
content = header + ".\n" + "\n".join(body) + "\n"

with open(OUT, "w", encoding="utf-8") as f:
    f.write(content)

print(f"written {OUT}: {len(body)+1} lines, {len(content)} bytes")