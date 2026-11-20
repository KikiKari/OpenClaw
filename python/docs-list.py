#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a1a0d18c636a5256807a68efa0e079c5d4b6f20de196c37bef11e0942f261479", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "python"}
# docs-list.js — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
from pathlib import Path


def setup_stdout_error_handler():
    """Handle EPIPE errors gracefully like in Node.js"""
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)


setup_stdout_error_handler()

DOCS_DIR = Path.cwd() / "docs"
if not DOCS_DIR.exists():
    print("docs:list: missing docs directory. Run from repo root.", file=sys.stderr)
    sys.exit(1)
if not DOCS_DIR.is_dir():
    print("docs:list: docs path is not a directory.", file=sys.stderr)
    sys.exit(1)

EXCLUDED_DIRS = {"archive", "research"}


def compact_strings(values):
    """Filter and normalize string values from a list"""
    result = []
    for value in values:
        if value is None:
            continue
        if isinstance(value, str):
            normalized = value.strip()
        elif isinstance(value, (int, float, bool)):
            normalized = str(value).strip()
        else:
            normalized = None

        if normalized and len(normalized) > 0:
            result.append(normalized)
    return result


def walk_markdown_files(directory, base=None):
    """Recursively find all .md files excluding certain directories"""
    if base is None:
        base = directory
    files = []
    try:
        entries = list(directory.iterdir())
    except PermissionError:
        return files

    # Sort entries for consistent ordering
    entries.sort(key=lambda x: x.name)

    for entry in entries:
        if entry.name.startswith('.'):
            continue
        if entry.is_dir():
            if entry.name in EXCLUDED_DIRS:
                continue
            files.extend(walk_markdown_files(entry, base))
        elif entry.is_file() and entry.name.endswith('.md'):
            files.append(str(entry.relative_to(base)))
    return files


def extract_metadata(full_path):
    """Extract summary and read_when metadata from markdown front matter"""
    try:
        content = Path(full_path).read_text(encoding='utf-8')
    except Exception as e:
        return {'summary': None, 'read_when': [], 'error': f'cannot read file: {str(e)}'}

    if not content.startswith('---'):
        return {'summary': None, 'read_when': [], 'error': 'missing front matter'}

    end_index = content.find('\n---', 3)
    if end_index == -1:
        return {'summary': None, 'read_when': [], 'error': 'unterminated front matter'}

    front_matter = content[3:end_index].strip()
    lines = front_matter.split('\n')

    summary_line = None
    read_when = []
    collecting_field = None

    for raw_line in lines:
        line = raw_line.strip()

        if line.startswith('summary:'):
            summary_line = line
            collecting_field = None
            continue

        if line.startswith('read_when:'):
            collecting_field = 'read_when'
            inline = line[len('read_when:'):].strip()
            if inline.startswith('[') and inline.endswith(']'):
                try:
                    # Replace single quotes with double quotes for valid JSON
                    json_str = inline.replace("'", '"')
                    parsed = json.loads(json_str)
                    if isinstance(parsed, list):
                        read_when.extend(compact_strings(parsed))
                except json.JSONDecodeError:
                    # ignore malformed inline arrays
                    pass
            continue

        if collecting_field == 'read_when':
            if line.startswith('- '):
                hint = line[2:].strip()
                if hint:
                    read_when.append(hint)
            elif line == '':
                # allow blank lines inside the list
                pass
            else:
                collecting_field = None

    if not summary_line:
        return {'summary': None, 'read_when': read_when, 'error': 'summary key missing'}

    summary_value = summary_line[len('summary:'):].strip()
    # Remove surrounding quotes and normalize whitespace
    normalized = summary_value.strip('"\'')
    normalized = ' '.join(normalized.split())

    if not normalized:
        return {'summary': None, 'read_when': read_when, 'error': 'summary is empty'}

    return {'summary': normalized, 'read_when': read_when}


print("Listing all markdown files in docs folder:")

markdown_files = walk_markdown_files(DOCS_DIR)

for relative_path in markdown_files:
    full_path = DOCS_DIR / relative_path
    metadata = extract_metadata(full_path)
    summary = metadata.get('summary')
    read_when = metadata.get('read_when', [])
    error = metadata.get('error')

    if summary:
        print(f"{relative_path} - {summary}")
        if read_when:
            print(f"  Read when: {'; '.join(read_when)}")
    else:
        reason = f" - [{error}]" if error else ""
        print(f"{relative_path}{reason}")

print('\nReminder: keep docs up to date as behavior changes. When your task matches any "Read when" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing.')
