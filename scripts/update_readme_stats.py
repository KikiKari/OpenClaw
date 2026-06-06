#!/usr/bin/env python3
"""Fetch ClawHub stats and update README.md download counts and security status."""

import os
import re
import urllib.request
import json
import sys

API_BASE = "https://clawhub.ai/api/v1"
TOKEN = os.environ.get("CLAWHUB_TOKEN", "")

SKILLS = [
    ("Cluster Gateway",          "cluster-gateway"),
    ("MCP Tool Utils",           "mcp-tool-utils"),
    ("Reports Creator",          "reports-creator"),
    ("Relay Node",               "relay-node"),
    ("JSON Utils",               "json-utils"),
    ("Log Collector",            "log-collector"),
    ("TikTok Live Monitor",      "tiktok-live-monitor"),
    ("Doc Scraper",              "doc-scraper"),
    ("Workspace Database Manager","workspace-database-manager"),
    ("Scripting Utils",          "scripting-utils"),
]

def fetch_skill(slug):
    url = f"{API_BASE}/skills/{slug}"
    req = urllib.request.Request(url)
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/json")
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())

def security_badge(data):
    state = data.get("moderationState", data.get("moderation_state", "review"))
    return "✅ Pass" if state in ("approved", "pass") else "🔍 Review"

def main():
    stats = {}
    errors = 0
    for name, slug in SKILLS:
        try:
            data = fetch_skill(slug)
            downloads = data.get("downloads", data.get("download_count", 0))
            version   = data.get("version", data.get("latest_version", "v1.0.0"))
            stats[slug] = {
                "name":      name,
                "downloads": downloads,
                "version":   version,
                "security":  security_badge(data),
            }
            print(f"  OK  {slug}: {downloads} downloads, {version}, {stats[slug][\"security\"]}")
        except Exception as exc:
            print(f"  ERR {slug}: {exc}", file=sys.stderr)
            errors += 1

    if not stats:
        print("No data fetched — aborting.", file=sys.stderr)
        sys.exit(1)

    with open("README.md", encoding="utf-8") as f:
        content = f.read()

    for name, slug in SKILLS:
        if slug not in stats:
            continue
        s = stats[slug]
        # Update download count in table row (matches | Name | v... | 123 | )
        pattern = rf"(\|\s*\[?{re.escape(name)}\]?[^|]*\|[^|]*\|)\s*\d+\s*(\|)"
        replacement = rf"\g<1> {s[\"downloads\"]} \2"
        new_content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)
        if new_content != content:
            content = new_content
            print(f"  Updated row: {name}")

    with open("README.md", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"README.md updated ({len(stats)} skills, {errors} errors).")

if __name__ == "__main__":
    main()