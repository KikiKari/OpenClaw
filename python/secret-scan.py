#!/usr/bin/env python3
# secret-scan.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import asyncio
import os
import re
from pathlib import Path


root = Path(__file__).parent.parent
skipped = {
    "node_modules",
    ".next",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "media-production/raw",
    "media-production/private",
}
patterns = [
    re.compile(r"sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}"),
    re.compile(r"ELEVENLABS_API_KEY\s*=\s*[\"']?[A-Za-z0-9]{20,}"),
    re.compile(r"WAVESPEED_API_KEY\s*=\s*[\"']?[A-Za-z0-9]{20,}"),
]
findings = []


async def walk(directory, relative=""):
    for entry in os.listdir(directory):
        rel = os.path.join(relative, entry)
        if (
            entry == ".env"
            or (entry.startswith(".env.") and entry != ".env.example")
            or any(
                rel == item
                or rel.startswith(f"{item}{os.sep}")
                or item in rel.split(os.sep)
                for item in skipped
            )
        ):
            continue
        target = os.path.join(directory, entry)
        if os.path.isdir(target):
            await walk(target, rel)
        elif os.path.getsize(target) < 2_000_000:
            try:
                with open(target, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                content = ""
            for pattern in patterns:
                if pattern.search(content):
                    findings.append(rel)


async def main():
    await walk(root)
    unique_findings = list(set(findings))
    if unique_findings:
        print(f"Secret-Scan fehlgeschlagen: {', '.join(unique_findings)}", file=sys.stderr)
        sys.exit(1)
    print("Secret-Scan bestanden.")


if __name__ == "__main__":
    import sys
    asyncio.run(main())
