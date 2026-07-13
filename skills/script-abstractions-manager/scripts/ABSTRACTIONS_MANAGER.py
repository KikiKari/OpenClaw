#!/usr/bin/env python3
"""Compatibility entry point for the canonical Abstractions Manager."""

from pathlib import Path
import runpy


CANONICAL_MANAGER = Path("/home/openclaw/.openclaw/workspace/abstraction-manager/ABSTRACTIONS_MANAGER.py")


if __name__ == "__main__":
    if not CANONICAL_MANAGER.is_file():
        raise SystemExit(f"Kanonischer Abstraction-Manager fehlt: {CANONICAL_MANAGER}")
    runpy.run_path(str(CANONICAL_MANAGER), run_name="__main__")
