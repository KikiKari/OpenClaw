#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "468f8d6712b710bbafbb2589dd9339c151d65c49bf8d347ab8695bbb2c56f5e8", "source_sha256": "51ab4d0a9d189c9eda9b410805bf753ea3df4406b70d58c8757e52b4551325b6", "target_language": "python"}
# docs-sync-publish.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-sync-publish.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Union

HERE = Path(__file__).parent.resolve()
ROOT = HERE.parent
SOURCE_DOCS_DIR = ROOT / "docs"
SOURCE_CONFIG_PATH = SOURCE_DOCS_DIR / "docs.json"
GENERATED_LOCALES = [
    {
        "language": "zh-Hans",
        "dir": "zh-CN",
        "navFile": "zh-Hans-navigation.json",
        "tmFile": "zh-CN.tm.jsonl",
        "navMode": "overlay",
    },
    {
        "language": "ja",
        "dir": "ja-JP",
        "navFile": "ja-navigation.json",
        "tmFile": "ja-JP.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "es",
        "dir": "es",
        "navFile": "es-navigation.json",
        "tmFile": "es.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "pt-BR",
        "dir": "pt-BR",
        "navFile": "pt-BR-navigation.json",
        "tmFile": "pt-BR.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "ko",
        "dir": "ko",
        "navFile": "ko-navigation.json",
        "tmFile": "ko.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "de",
        "dir": "de",
        "navFile": "de-navigation.json",
        "tmFile": "de.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "fr",
        "dir": "fr",
        "navFile": "fr-navigation.json",
        "tmFile": "fr.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "ar",
        "dir": "ar",
        "navFile": "ar-navigation.json",
        "tmFile": "ar.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "it",
        "dir": "it",
        "navFile": "it-navigation.json",
        "tmFile": "it.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "tr",
        "dir": "tr",
        "navFile": "tr-navigation.json",
        "tmFile": "tr.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "uk",
        "dir": "uk",
        "navFile": "uk-navigation.json",
        "tmFile": "uk.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "id",
        "dir": "id",
        "navFile": "id-navigation.json",
        "tmFile": "id.tm.jsonl",
        "navMode": "clone-en",
    },
    {
        "language": "pl",
        "dir": "pl",
        "navFile": "pl-navigation.json",
        "tmFile": "pl.tm.jsonl",
        "navMode": "clone-en",
    },
]


def parse_args(argv: List[str]) -> Dict[str, str]:
    args = {
        "target": "",
        "sourceRepo": "",
        "sourceSha": "",
    }

    index = 0
    while index < len(argv):
        part = argv[index]
        if part == "--target":
            args["target"] = argv[index + 1] if index + 1 < len(argv) else ""
            index += 2
        elif part == "--source-repo":
            args["sourceRepo"] = argv[index + 1] if index + 1 < len(argv) else ""
            index += 2
        elif part == "--source-sha":
            args["sourceSha"] = argv[index + 1] if index + 1 < len(argv) else ""
            index += 2
        else:
            raise ValueError(f"unknown arg: {part}")

    if not args["target"]:
        raise ValueError("missing --target")

    return args


def run(command: str, args: List[str], cwd: str = str(ROOT), **kwargs) -> None:
    subprocess.run([command] + args, cwd=cwd, check=True, **kwargs)


def ensure_dir(dir_path: Path) -> None:
    dir_path.mkdir(parents=True, exist_ok=True)


def read_json(file_path: Path) -> Any:
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_json(file_path: Path, value: Any) -> None:
    ensure_dir(file_path.parent)
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write("\n")


def prefix_locale_page(entry: Any, locale_dir: str) -> Any:
    if isinstance(entry, str):
        return f"{locale_dir}/{entry}"
    if isinstance(entry, list):
        return [prefix_locale_page(item, locale_dir) for item in entry]
    if not isinstance(entry, dict):
        return entry

    clone = entry.copy()
    if isinstance(clone.get("page"), str):
        clone["page"] = f"{locale_dir}/{clone['page']}"
    if isinstance(clone.get("pages"), list):
        clone["pages"] = [prefix_locale_page(item, locale_dir) for item in clone["pages"]]
    return clone


def clone_english_language_nav(english_nav: Dict[str, Any], locale: Dict[str, Any]) -> Dict[str, Any]:
    if not english_nav:
        raise ValueError("docs/docs.json is missing navigation.languages.en")
    
    result = english_nav.copy()
    result["language"] = locale["language"]
    
    if isinstance(result.get("tabs"), list):
        result["tabs"] = []
        for tab in english_nav["tabs"]:
            new_tab = tab.copy()
            if isinstance(tab.get("pages"), list):
                new_tab["pages"] = [prefix_locale_page(entry, locale["dir"]) for entry in tab["pages"]]
            if isinstance(tab.get("groups"), list):
                new_tab["groups"] = []
                for group in tab["groups"]:
                    new_group = group.copy()
                    if isinstance(group.get("pages"), list):
                        new_group["pages"] = [prefix_locale_page(entry, locale["dir"]) for entry in group["pages"]]
                    new_tab["groups"].append(new_group)
            result["tabs"].append(new_tab)
    
    return result


def compose_locale_nav(locale: Dict[str, Any], english_nav: Dict[str, Any]) -> Dict[str, Any]:
    if locale["navMode"] == "clone-en":
        return clone_english_language_nav(english_nav, locale)
    return read_json(SOURCE_DOCS_DIR / ".i18n" / locale["navFile"])


def compose_docs_config() -> Dict[str, Any]:
    source_config = read_json(SOURCE_CONFIG_PATH)
    languages = source_config.get("navigation", {}).get("languages", [])

    if not isinstance(languages, list):
        raise ValueError("docs/docs.json is missing navigation.languages")

    english_nav = next((entry for entry in languages if entry.get("language") == "en"), None)
    generated_language_set = {entry["language"] for entry in GENERATED_LOCALES}
    without_generated = [entry for entry in languages if entry.get("language") not in generated_language_set]
    
    generated = [compose_locale_nav(entry, english_nav) for entry in GENERATED_LOCALES]
    
    # Find the position of English language entry
    en_index = next((i for i, entry in enumerate(without_generated) if entry.get("language") == "en"), -1)
    
    if en_index == -1:
        without_generated.extend(generated)
    else:
        without_generated[en_index+1:en_index+1] = generated

    return {
        **source_config,
        "navigation": {
            **source_config.get("navigation", {}),
            "languages": without_generated,
        },
    }


def sync_docs_tree(target_root: Path) -> None:
    target_docs_dir = target_root / "docs"
    ensure_dir(target_docs_dir)

    locale_filters = []
    for entry in GENERATED_LOCALES:
        locale_filters.extend([
            "--filter",
            f"P {entry['dir']}/",
            "--filter",
            f"P .i18n/{entry['tmFile']}",
            "--exclude",
            f"{entry['dir']}/",
            "--exclude",
            f".i18n/{entry['tmFile']}",
        ])

    run("rsync", [
        "-a",
        "--delete",
        "--filter",
        "P .i18n/README.md",
        "--exclude",
        ".i18n/README.md",
        *locale_filters,
        f"{SOURCE_DOCS_DIR}/",
        f"{target_docs_dir}/",
    ])

    for locale in GENERATED_LOCALES:
        source_tm_path = SOURCE_DOCS_DIR / ".i18n" / locale["tmFile"]
        target_tm_path = target_docs_dir / ".i18n" / locale["tmFile"]
        if not target_tm_path.exists() and source_tm_path.exists():
            ensure_dir(target_tm_path.parent)
            target_tm_path.write_bytes(source_tm_path.read_bytes())

    write_json(target_docs_dir / "docs.json", compose_docs_config())


def write_sync_metadata(target_root: Path, args: Dict[str, str]) -> None:
    metadata = {
        "repository": args["sourceRepo"] or "",
        "sha": args["sourceSha"] or "",
        "syncedAt": __import__('datetime').datetime.utcnow().isoformat() + "Z",
    }
    write_json(target_root / ".openclaw-sync" / "source.json", metadata)


def main() -> None:
    args = parse_args(sys.argv[1:])
    target_root = Path(args["target"]).resolve()

    if not target_root.exists():
        raise FileNotFoundError(f"target does not exist: {target_root}")

    sync_docs_tree(target_root)
    write_sync_metadata(target_root, args)


if __name__ == "__main__":
    main()
