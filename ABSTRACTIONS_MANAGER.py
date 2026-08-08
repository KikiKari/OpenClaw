#!/usr/bin/env python3
"""Kompatibilitaetseinstieg fuer den kanonischen Abstractions Manager."""

from pathlib import Path
import runpy


KANONISCHER_MANAGER = Path(
    "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"
)


if __name__ == "__main__":
    if not KANONISCHER_MANAGER.is_file():
        raise SystemExit(f"Kanonischer Abstractions Manager fehlt: {KANONISCHER_MANAGER}")
    runpy.run_path(str(KANONISCHER_MANAGER), run_name="__main__")
