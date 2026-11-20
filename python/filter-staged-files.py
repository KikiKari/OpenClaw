#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "5ca0ac13c322da07056a56c22d01db137bcd16f22bcc1597d69d68bf3b8210df", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "python"}
# filter-staged-files.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import sys
import os
from pathlib import Path

"""
Prints selected files as NUL-delimited tokens to stdout.

Usage:
  python3 scripts/pre-commit/filter-staged-files.py lint -- <files...>
  python3 scripts/pre-commit/filter-staged-files.py format -- <files...>

Keep this dependency-free: the pre-commit hook runs in many environments.
"""

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else None
    raw_args = sys.argv[2:]
    
    # Handle -- separator
    if raw_args and raw_args[0] == "--":
        files = raw_args[1:]
    else:
        files = raw_args

    if mode not in ("lint", "format"):
        sys.stderr.write("usage: filter-staged-files.py <lint|format> -- <files...>\n")
        sys.exit(2)

    lint_exts = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"}
    format_exts = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".md", ".mdx"}
    format_ignored_paths = {"src/canvas-host/a2ui/a2ui.bundle.js"}

    def should_select(file_path):
        ext = Path(file_path).suffix.lower()
        if mode == "lint":
            return ext in lint_exts
        if file_path in format_ignored_paths:
            return False
        return ext in format_exts

    for file in files:
        if should_select(file):
            sys.stdout.write(file)
            sys.stdout.write("\0")

if __name__ == "__main__":
    main()
