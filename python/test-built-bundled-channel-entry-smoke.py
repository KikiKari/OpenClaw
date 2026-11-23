#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "4441cdd25d53e3493d4e6967df8407c89705bbe41c748f6114263b98cb8e0c1c", "source_sha256": "cd0bfcd0719418f4f0877e7488a8136ca9e8ba296aaaf669b43c7da1dca0f581", "target_language": "python"}
# test-built-bundled-channel-entry-smoke.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-bundled-channel-entry-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import argparse
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional
from types import ModuleType

# Filter warnings - Python equivalent would use warnings module if needed
# For now we'll just ignore this functionality as it's not critical

# Set environment variable if not already set
if "OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK" not in os.environ:
    os.environ["OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK"] = "1"

def parse_args(argv: List[str]) -> Dict[str, str]:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-root", help="Package root directory")
    
    args = parser.parse_args(argv)
    
    package_root = args.package_root
    if not package_root:
        # Get the directory of this script file, then go up one level
        script_dir = Path(__file__).parent.absolute()
        package_root = script_dir.parent
    
    return {"packageRoot": str(Path(package_root).resolve())}

def read_json(pathname: str) -> Dict[str, Any]:
    with open(pathname, 'r', encoding='utf-8') as f:
        return json.load(f)

def extension_entry_to_dist_filename(entry: str) -> str:
    # Remove leading ./
    if entry.startswith("./"):
        entry = entry[2:]
    # Replace extension with .js
    parts = entry.split('.')
    if len(parts) > 1:
        parts[-1] = "js"
        return ".".join(parts)
    return entry + ".js"

def collect_bundled_channel_entry_files(package_root: str) -> List[Dict[str, str]]:
    files = []
    dist_extensions_root = Path(package_root) / "dist" / "extensions"
    
    if not dist_extensions_root.exists():
        return []
        
    for item in dist_extensions_root.iterdir():
        if not item.is_dir():
            continue
            
        extension_root = item
        package_json_path = extension_root / "package.json"
        if not package_json_path.exists():
            continue
            
        try:
            package_json = read_json(str(package_json_path))
        except Exception:
            continue
            
        if not package_json.get("openclaw", {}).get("channel"):
            continue

        extension_entries = package_json.get("openclaw", {}).get("extensions", [])
        if not isinstance(extension_entries, list) or len(extension_entries) == 0:
            extension_entries = ["./index.ts"]
            
        for entry in extension_entries:
            if not isinstance(entry, str) or not entry.strip():
                continue
            files.append({
                "id": item.name,
                "kind": "channel",
                "path": str(extension_root / extension_entry_to_dist_filename(entry))
            })

        setup_entry = package_json.get("openclaw", {}).get("setupEntry")
        if isinstance(setup_entry, str) and setup_entry.strip():
            files.append({
                "id": item.name,
                "kind": "setup",
                "path": str(extension_root / extension_entry_to_dist_filename(setup_entry))
            })

        channel_entry_path = extension_root / "channel-entry.js"
        if channel_entry_path.exists():
            files.append({
                "id": item.name,
                "kind": "channel",
                "path": str(channel_entry_path)
            })
    
    # Sort by id:kind:path
    return sorted(files, key=lambda x: f"{x['id']}:{x['kind']}:{x['path']}")

def assert_secret_contract_shape(secrets: Any, context: str) -> None:
    if not secrets or not isinstance(secrets, dict):
        raise AssertionError(f"{context}: missing secrets contract")
    
    if "collectRuntimeConfigAssignments" not in secrets or not callable(secrets["collectRuntimeConfigAssignments"]):
        raise AssertionError(f"{context}: collectRuntimeConfigAssignments must be a function")
        
    if "secretTargetRegistryEntries" not in secrets or not isinstance(secrets["secretTargetRegistryEntries"], list):
        raise AssertionError(f"{context}: secretTargetRegistryEntries must be an array")

def assert_entry_file_exists(entry: Dict[str, str]) -> None:
    if not Path(entry["path"]).exists():
        raise AssertionError(f"{entry['id']} {entry['kind']} entry missing from packed dist: {entry['path']}")

def import_built_module(absolute_path: str) -> ModuleType:
    """Dynamically import a Python module from a file path"""
    spec = __import__("importlib.util").util.spec_from_file_location("module", absolute_path)
    module = __import__("importlib.util").util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

async def smoke_channel_entry(entry_file: Dict[str, str]) -> None:
    assert_entry_file_exists(entry_file)
    
    try:
        module = import_built_module(entry_file["path"])
        entry = getattr(module, 'default', None)
        
        if entry is None:
            raise AssertionError(f"{entry_file['id']} channel entry missing default export")
            
        if getattr(entry, 'kind', None) != "bundled-channel-entry":
            raise AssertionError(f"{entry_file['id']} channel entry kind mismatch")
            
        if not hasattr(entry, 'loadChannelPlugin') or not callable(getattr(entry, 'loadChannelPlugin')):
            raise AssertionError(f"{entry_file['id']} channel entry missing loadChannelPlugin")
            
        plugin = entry.loadChannelPlugin()
        if not plugin or getattr(plugin, 'id', None) != entry_file['id']:
            raise AssertionError(f"{entry_file['id']} channel plugin failed to load")
            
        if hasattr(entry, 'loadChannelSecrets') and callable(getattr(entry, 'loadChannelSecrets')):
            secrets = entry.loadChannelSecrets()
            assert_secret_contract_shape(secrets, f"{entry_file['id']} channel entry packaged secrets")
            
    except Exception as e:
        if isinstance(e, AssertionError):
            raise
        raise AssertionError(f"{entry_file['id']} channel entry import failed: {str(e)}")

async def smoke_setup_entry(entry_file: Dict[str, str]) -> bool:
    assert_entry_file_exists(entry_file)
    
    try:
        module = import_built_module(entry_file["path"])
        entry = getattr(module, 'default', None)
        
        if entry is None or getattr(entry, 'kind', None) != "bundled-channel-setup-entry":
            return False
            
        if not hasattr(entry, 'loadSetupPlugin') or not callable(getattr(entry, 'loadSetupPlugin')):
            raise AssertionError(f"{entry_file['id']} setup entry missing loadSetupPlugin")
            
        plugin = entry.loadSetupPlugin()
        if not plugin or getattr(plugin, 'id', None) != entry_file['id']:
            raise AssertionError(f"{entry_file['id']} setup plugin failed to load")
            
        if hasattr(entry, 'loadSetupSecrets') and callable(getattr(entry, 'loadSetupSecrets')):
            secrets = entry.loadSetupSecrets()
            assert_secret_contract_shape(secrets, f"{entry_file['id']} setup entry packaged secrets")
            
        return True
        
    except Exception as e:
        if isinstance(e, AssertionError):
            raise
        raise AssertionError(f"{entry_file['id']} setup entry import failed: {str(e)}")

async def main() -> None:
    parsed_args = parse_args(sys.argv[1:])
    package_root = parsed_args["packageRoot"]
    
    entry_files = collect_bundled_channel_entry_files(package_root)
    channel_count = 0
    setup_count = 0
    legacy_setup_count = 0
    
    for entry_file in entry_files:
        if entry_file["kind"] == "channel":
            await smoke_channel_entry(entry_file)
            channel_count += 1
        else:
            if await smoke_setup_entry(entry_file):
                setup_count += 1
            else:
                legacy_setup_count += 1
    
    if channel_count == 0:
        raise AssertionError("no bundled channel entries found")
        
    print(f"[build-smoke] bundled channel entry smoke passed packageRoot={package_root} channel={channel_count} setup={setup_count} legacySetup={legacy_setup_count}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
