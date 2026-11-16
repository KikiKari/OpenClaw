#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "c853290f7588fba979fd06828a4a590309193fbf5cac00b89c98dcec5040a89c", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "python"}
# changed-extensions.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import subprocess
import os
import re
from pathlib import Path
from bundled_plugin_paths import BUNDLED_PLUGIN_PATH_PREFIX, BUNDLED_PLUGIN_ROOT_DIR

repo_root = Path(__file__).resolve().parent.parent

def run_git(args, options=None):
    if options is None:
        options = {}
    
    cwd = options.get('cwd', str(repo_root))
    stdin = options.get('stdin', subprocess.DEVNULL)
    
    result = subprocess.run(
        ['git'] + args,
        cwd=cwd,
        stdin=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    result.check_returncode()
    return result.stdout

def normalize_relative(input_path):
    return input_path.replace(os.sep, '/')

def has_git_commit(ref):
    if not ref or re.match(r'^0+$', ref):
        return False

    try:
        run_git(['rev-parse', '--verify', f'{ref}^{{commit}}'])
        return True
    except subprocess.CalledProcessError:
        return False

def resolve_changed_paths_base(params=None):
    if params is None:
        params = {}
        
    base = params.get('base')
    head = params.get('head', 'HEAD')
    fallback_base_ref = params.get('fallbackBaseRef')

    if has_git_commit(base):
        return base

    if fallback_base_ref:
        remote_base_ref = fallback_base_ref if fallback_base_ref.startswith('origin/') else f'origin/{fallback_base_ref}'
        if has_git_commit(remote_base_ref):
            merge_base = run_git(['merge-base', remote_base_ref, head]).strip()
            if has_git_commit(merge_base):
                return merge_base

    if not base:
        raise Exception('A git base revision is required to list changed extensions.')

    raise Exception(f'Git base revision is unavailable locally: {base}')

def list_changed_paths(base, head='HEAD'):
    if not base:
        raise Exception('A git base revision is required to list changed extensions.')

    output = run_git(['diff', '--name-only', base, head])
    lines = output.strip().split('\n')
    return [line.strip() for line in lines if line.strip()]

def has_extension_package(extension_id):
    package_path = repo_root / BUNDLED_PLUGIN_ROOT_DIR / extension_id / 'package.json'
    return package_path.exists()

def list_available_extension_ids():
    extensions_dir = repo_root / BUNDLED_PLUGIN_ROOT_DIR
    if not extensions_dir.exists():
        return []

    entries = [entry for entry in extensions_dir.iterdir() if entry.is_dir()]
    extension_ids = [entry.name for entry in entries if has_extension_package(entry.name)]
    return sorted(extension_ids)

def detect_changed_extension_ids(changed_paths):
    extension_ids = set()

    for raw_path in changed_paths:
        relative_path = normalize_relative(str(raw_path).strip())
        if not relative_path:
            continue

        # Escape forward slashes in the prefix for regex
        escaped_prefix = BUNDLED_PLUGIN_PATH_PREFIX.replace('/', '\\/')
        extension_match = re.match(rf'^{escaped_prefix}([^/]+)(?:/|$)', relative_path)
        if extension_match:
            extension_id = extension_match.group(1)
            if has_extension_package(extension_id):
                extension_ids.add(extension_id)
            continue

        paired_core_match = re.match(r'^src/([^/]+)(?:/|$)', relative_path)
        if paired_core_match and has_extension_package(paired_core_match.group(1)):
            extension_ids.add(paired_core_match.group(1))

    return sorted(list(extension_ids))

def list_changed_extension_ids(params=None):
    if params is None:
        params = {}
        
    head = params.get('head', 'HEAD')
    unavailable_base_behavior = params.get('unavailableBaseBehavior', 'error')

    try:
        base = resolve_changed_paths_base(params)
        return detect_changed_extension_ids(list_changed_paths(base, head))
    except Exception as error:
        if unavailable_base_behavior == 'all':
            return list_available_extension_ids()
        if unavailable_base_behavior == 'empty':
            return []
        raise error
