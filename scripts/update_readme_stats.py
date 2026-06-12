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
    ("Cluster Gateway",           "cluster-gateway"),
    ("MCP Tool Utils",            "mcp-tool-utils"),
    ("Reports Creator",           "reports-creator"),
    ("Relay Node",                "relay-node"),
    ("JSON Utils",                "json-utils"),
    ("Log Collector",             "log-collector"),
    ("TikTok Live Monitor",       "tiktok-live-monitor"),
    ("Doc Scraper",               "doc-scraper"),
    ("Workspace Database Manager","workspace-database-manager"),
    ("Scripting Utils",           "scripting-utils"),
]


def fetch_skill(slug):
    url = f"{API_BASE}/skills/{slug}"
    req = urllib.request.Request(url)
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/json")
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def parse_skill(data):
    skill   = data.get("skill", {})
    stats   = skill.get("stats", {})
    version = data.get("latestVersion", {}).get("version", "1.0.0")
    mod     = data.get("moderation")

    downloads = stats.get("downloads", 0)

    if mod is None:
        security = "✅ Pass"
    elif mod.get("isMalwareBlocked"):
        security = "🚫 Blocked"
    else:
        security = "🔍 Review"

    return {
        "downloads": downloads,
        "version":   f"v{version}" if not version.startswith("v") else version,
        "security":  security,
    }


def main():
    stats = {}
    errors = 0
    for name, slug in SKILLS:
        try:
            data = fetch_skill(slug)
            s = parse_skill(data)
            stats[slug] = s
            print(f"  OK  {slug}: {s['downloads']} downloads, {s['version']}, {s['security']}")
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
        dl = stats[slug]["downloads"]
        pattern     = rf"(\|\s*\[?{re.escape(name)}\]?[^|]*\|[^|]*\|)\s*\d+\s*(\|)"
        replacement = rf"\g<1> {dl} \2"
        new_content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)
        if new_content != content:
            content = new_content
            print(f"  Updated: {name} -> {dl}")

    with open("README.md", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Done: {len(stats)} skills, {errors} errors.")


if __name__ == "__main__":
    main()
