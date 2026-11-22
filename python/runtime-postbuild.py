#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "b9c502602f801e451e7de5f4d3af7719d0333132bf59fc542f9a8c3f2149ffe2", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "python"}
# runtime-postbuild.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import re
import sys
import shutil
from pathlib import Path

# Import required modules
sys.path.append(str(Path(__file__).parent))
from copy_bundled_plugin_metadata import copy_bundled_plugin_metadata
from copy_plugin_sdk_root_alias import copy_plugin_sdk_root_alias
from runtime_postbuild_shared import write_text_file_if_changed
from stage_bundled_plugin_runtime_deps import stage_bundled_plugin_runtime_deps
from stage_bundled_plugin_runtime import stage_bundled_plugin_runtime
from write_official_channel_catalog import write_official_channel_catalog

ROOT = Path(__file__).parent.parent.absolute()
ROOT_RUNTIME_ALIAS_PATTERN = re.compile(r"^(?P<base>.+\.(?:runtime|contract))-[A-Za-z0-9_-]+\.js$")

"""
Copy static (non-transpiled) runtime assets that are referenced by their
source-relative path inside bundled extension code.

Each entry: { src: repo-root-relative source, dest: dist-relative dest }
"""
STATIC_EXTENSION_ASSETS = [
    # acpx MCP proxy — co-deployed alongside the acpx index bundle so that
    # `path.resolve(dirname(import.meta.url), "mcp-proxy.mjs")` resolves correctly
    # at runtime from the built ACPX extension directory.
    {
        "src": "extensions/acpx/src/runtime-internals/mcp-proxy.mjs",
        "dest": "dist/extensions/acpx/mcp-proxy.mjs",
    },
    # diffs viewer runtime bundle — co-deployed inside the plugin package so the
    # built bundle can resolve `./assets/viewer-runtime.js` from dist.
    {
        "src": "extensions/diffs/assets/viewer-runtime.js",
        "dest": "dist/extensions/diffs/assets/viewer-runtime.js",
    },
]

def list_static_extension_asset_outputs(assets=None):
    if assets is None:
        assets = STATIC_EXTENSION_ASSETS
    outputs = [asset["dest"].replace("\\", "/") for asset in assets]
    return sorted(outputs)

def copy_static_extension_assets(root_dir=None, assets=None, warn=None):
    if root_dir is None:
        root_dir = ROOT
    if assets is None:
        assets = STATIC_EXTENSION_ASSETS
    if warn is None:
        warn = lambda msg: print(msg, file=sys.stderr)
    
    for asset in assets:
        src = asset["src"]
        dest = asset["dest"]
        src_path = Path(root_dir) / src
        dest_path = Path(root_dir) / dest
        if src_path.exists():
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_path, dest_path)
        else:
            warn(f"[runtime-postbuild] static asset not found, skipping: {src}")

def write_stable_root_runtime_aliases(root_dir=None):
    if root_dir is None:
        root_dir = ROOT
    dist_dir = Path(root_dir) / "dist"
    
    try:
        entries = list(dist_dir.iterdir())
    except FileNotFoundError:
        return
    
    for entry in entries:
        if not entry.is_file():
            continue
        match = ROOT_RUNTIME_ALIAS_PATTERN.match(entry.name)
        if not match or not match.group("base"):
            continue
        base = match.group("base")
        alias_path = dist_dir / f"{base}.js"
        write_text_file_if_changed(str(alias_path), f'export * from "./{entry.name}";\n')

def run_runtime_post_build(root_dir=None):
    params = {"root_dir": root_dir} if root_dir else {}
    copy_plugin_sdk_root_alias(**params)
    copy_bundled_plugin_metadata(**params)
    write_official_channel_catalog(**params)
    stage_bundled_plugin_runtime_deps(**params)
    stage_bundled_plugin_runtime(**params)
    write_stable_root_runtime_aliases(**params)
    copy_static_extension_assets(**params)

if __name__ == "__main__":
    run_runtime_post_build()
