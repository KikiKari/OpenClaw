#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "cce1b030aabfdf08c26b64ebf0a91226f9cc2fe54525aec119ac56bcddcc9d99", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "python"}
# bundled-plugin-source-utils.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import json
import os


def read_if_exists(file_path):
    """Liest eine Datei, falls sie existiert, und gibt ihren Inhalt zurück."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return None


def collect_bundled_plugin_sources(params=None):
    """
    Sammelt Informationen über gebündelte Plugin-Quellen.

    Args:
        params (dict): Optionale Parameter.
                       - repo_root: Wurzelverzeichnis des Repositories.
                       - require_package_json: Ob package.json erforderlich ist.

    Returns:
        list: Liste der Plugin-Einträge, sortiert nach Verzeichnisname.
    """
    if params is None:
        params = {}

    repo_root = os.path.abspath(params.get('repo_root', os.getcwd()))
    extensions_root = os.path.join(repo_root, 'extensions')

    if not os.path.exists(extensions_root):
        return []

    require_package_json = params.get('require_package_json') is True
    entries = []

    try:
        dirents = os.listdir(extensions_root)
    except FileNotFoundError:
        return []

    for entry in dirents:
        plugin_dir = os.path.join(extensions_root, entry)
        if not os.path.isdir(plugin_dir):
            continue

        manifest_path = os.path.join(plugin_dir, 'openclaw.plugin.json')
        package_json_path = os.path.join(plugin_dir, 'package.json')

        if not os.path.exists(manifest_path):
            continue

        if require_package_json and not os.path.exists(package_json_path):
            continue

        manifest_content = read_if_exists(manifest_path)
        if manifest_content is None:
            continue

        try:
            manifest = json.loads(manifest_content)
        except json.JSONDecodeError:
            continue

        entry_data = {
            'dir_name': entry,
            'plugin_dir': plugin_dir,
            'manifest_path': manifest_path,
            'manifest': manifest
        }

        package_json_content = read_if_exists(package_json_path)
        if package_json_content is not None:
            try:
                package_json = json.loads(package_json_content)
                entry_data.update({
                    'package_json_path': package_json_path,
                    'package_json': package_json
                })
            except json.JSONDecodeError:
                pass

        entries.append(entry_data)

    # Sortieren nach Verzeichnisnamen
    entries.sort(key=lambda x: x['dir_name'])
    return entries
