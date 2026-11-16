#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "4e3639a3583eeae598010eaf40a7d9abeb1712a697b67eb30dd113812c5b5ba7", "source_sha256": "e290d06e27f18dbd9a54def6168fe32ba54f3cdb01ec2175510727f412ff6a70", "target_language": "python"}
# check-docs-i18n-glossary.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-docs-i18n-glossary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()
GLOSSARY_PATH = ROOT / "docs" / ".i18n" / "glossary.zh-CN.json"
DOC_FILE_RE = re.compile(r"^docs\/(?!zh-CN\/).+\.(md|mdx)$", re.IGNORECASE)
LIST_ITEM_LINK_RE = re.compile(r"^\s*(?:[-*]|\d+\.)\s+\[([^\]]+)\]\((\/[^)]+)\)")
MAX_TITLE_WORDS = 8
MAX_LABEL_WORDS = 6
MAX_TERM_LENGTH = 80


class TermMatch:
    def __init__(self, file, line, kind, term):
        self.file = file
        self.line = line
        self.kind = kind
        self.term = term


def parse_args(argv):
    args = {"base": "", "head": ""}
    i = 0
    while i < len(argv):
        if argv[i] == "--base":
            args["base"] = argv[i + 1] if i + 1 < len(argv) else ""
            i += 2
            continue
        if argv[i] == "--head":
            args["head"] = argv[i + 1] if i + 1 < len(argv) else ""
            i += 2
            continue
        i += 1
    return args


def run_git(args):
    result = subprocess.run(
        ["git"] + args,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True
    )
    return result.stdout.strip()


def resolve_base(explicit_base):
    if explicit_base:
        return explicit_base

    env_base = os.environ.get("DOCS_I18N_GLOSSARY_BASE", "").strip()
    if env_base:
        return env_base

    for candidate in ["origin/main", "fork/main", "main"]:
        try:
            return run_git(["merge-base", candidate, "HEAD"])
        except subprocess.CalledProcessError:
            # Try the next candidate.
            pass

    return ""


def list_changed_docs(base, head):
    args = ["diff", "--name-only", "--diff-filter=ACMR", base]
    if head:
        args.append(head)
    args.append("--")
    args.append("docs")

    output = run_git(args)
    lines = [line.strip() for line in output.split("\n")]
    return [line for line in lines if DOC_FILE_RE.match(line)]


def load_glossary_sources():
    with open(GLOSSARY_PATH, "r", encoding="utf-8") as f:
        data = f.read()
    entries = json.loads(data)
    sources = set()
    for entry in entries:
        source = str(entry.get("source", "")).strip()
        if source:
            sources.add(source)
    return sources


def contains_latin(text):
    return bool(re.search(r"[A-Za-z]", text))


def word_count(text):
    return len([word for word in text.strip().split(" ") if word])


def unquote_scalar(raw):
    value = raw.strip()
    if ((value.startswith('"') and value.endswith('"')) or
            (value.startswith("'") and value.endswith("'"))):
        return value[1:-1].strip()
    return value


def is_glossary_candidate(term, max_words):
    if not term:
        return False
    if not contains_latin(term):
        return False
    if "`" in term:
        return False
    if len(term) > MAX_TERM_LENGTH:
        return False
    return word_count(term) <= max_words


def read_git_file(base, rel_path):
    try:
        return run_git(["show", f"{base}:{rel_path}"])
    except subprocess.CalledProcessError:
        return ""


def extract_terms(file, text):
    terms = {}
    lines = text.split("\n")

    if lines and lines[0].strip() == "---":
        for index in range(1, len(lines)):
            line = lines[index]
            if line.strip() == "---":
                break

            match = re.match(r"^title:\s*(.+)\s*$", line)
            if not match:
                continue

            title = unquote_scalar(match.group(1))
            if is_glossary_candidate(title, MAX_TITLE_WORDS):
                terms[title] = TermMatch(file, index + 1, "title", title)
            break

    for index, line in enumerate(lines):
        match = LIST_ITEM_LINK_RE.match(line)
        if not match:
            continue

        label = match.group(1).strip()
        if not is_glossary_candidate(label, MAX_LABEL_WORDS):
            continue

        if label not in terms:
            terms[label] = TermMatch(file, index + 1, "link label", label)

    return terms


def main():
    args = parse_args(sys.argv[1:])
    base = resolve_base(args["base"])

    if not base:
        print("docs:check-i18n-glossary: no merge base found; skipping glossary coverage check.", file=sys.stderr)
        sys.exit(0)

    changed_docs = list_changed_docs(base, args["head"])
    if not changed_docs:
        sys.exit(0)

    glossary = load_glossary_sources()
    missing = []

    for rel_path in changed_docs:
        abs_path = ROOT / rel_path
        if not abs_path.exists():
            continue

        with open(abs_path, "r", encoding="utf-8") as f:
            content = f.read()
        current_terms = extract_terms(rel_path, content)
        
        base_content = read_git_file(base, rel_path)
        base_terms = extract_terms(rel_path, base_content)

        for term, match in current_terms.items():
            if term in base_terms:
                continue
            if term in glossary:
                continue
            missing.append(match)

    if not missing:
        sys.exit(0)

    print("docs:check-i18n-glossary: missing zh-CN glossary entries for changed doc labels:", file=sys.stderr)
    for match in missing:
        print(f"- {match.file}:{match.line} {match.kind} \"{match.term}\"", file=sys.stderr)
    print("", file=sys.stderr)
    print("Add exact source terms to docs/.i18n/glossary.zh-CN.json before rerunning docs-i18n.", file=sys.stderr)
    print(f"Checked changed English docs relative to {base}.", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
