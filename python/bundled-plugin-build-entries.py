#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "28b138d2d78ca9d1fcfac69c524bb23248cb89249ba8ecad50e0f181da967b76", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "python"}
# bundled-plugin-build-entries.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Union

from bundled_plugin_paths import (
    BUNDLED_PLUGIN_ROOT_DIR,
    bundled_dist_plugin_file,
    bundled_plugin_file,
)
from optional_bundled_clusters import should_build_bundled_cluster

TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS: Set[str] = {".ts", ".js", ".mts", ".cts", ".mjs", ".cjs"}
NON_PACKAGED_BUNDLED_PLUGIN_DIRS: Set[str] = {"qa-channel", "qa-lab"}

def to_posix_path(value: str) -> str:
    return value.replace("\\", "/")

def read_bundled_plugin_package_json(package_json_path: str) -> Optional[Dict[str, Any]]:
    if not os.path.exists(package_json_path):
        return None
    try:
        with open(package_json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def is_manifestless_bundled_runtime_support_package(params: Dict[str, Any]) -> bool:
    package_name = ""
    if isinstance(params.get("packageJson", {}).get("name"), str):
        package_name = params["packageJson"]["name"]
    
    if package_name != f"@openclaw/{params['dirName']}":
        return False
    
    return len(params["topLevelPublicSurfaceEntries"]) > 0

def collect_plugin_source_entries(package_json: Optional[Dict[str, Any]]) -> List[str]:
    package_entries = []
    if isinstance(package_json, dict) and isinstance(package_json.get("openclaw", {}).get("extensions"), list):
        package_entries = [
            entry for entry in package_json["openclaw"]["extensions"]
            if isinstance(entry, str) and entry.strip()
        ]
    
    setup_entry = None
    if (isinstance(package_json, dict) and 
        isinstance(package_json.get("openclaw", {}).get("setupEntry"), str) and
        package_json["openclaw"]["setupEntry"].strip()):
        setup_entry = package_json["openclaw"]["setupEntry"]
    
    if setup_entry:
        package_entries = list(set(package_entries + [setup_entry]))
    
    return package_entries if package_entries else ["./index.ts"]

def should_stage_bundled_plugin_runtime_dependencies(package_json: Optional[Dict[str, Any]]) -> bool:
    if not isinstance(package_json, dict):
        return False
    return package_json.get("openclaw", {}).get("bundle", {}).get("stageRuntimeDependencies") is True

def collect_top_level_public_surface_entries(plugin_dir: str) -> List[str]:
    if not os.path.exists(plugin_dir):
        return []
    
    entries = []
    try:
        for item in os.listdir(plugin_dir):
            item_path = os.path.join(plugin_dir, item)
            if not os.path.isfile(item_path):
                continue
            
            ext = os.path.splitext(item)[1]
            if ext not in TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS:
                continue
            
            normalized_name = item.lower()
            if (normalized_name.endswith(".d.ts") or
                normalized_name.startswith("config-api.") and normalized_name.endswith((".ts", ".js", ".mts", ".cts", ".mjs", ".cjs")) or
                ".test." in normalized_name or
                ".spec." in normalized_name or
                ".fixture." in normalized_name or
                ".snap" in normalized_name):
                continue
            
            entries.append(f"./{item}")
    except OSError:
        return []
    
    return sorted(entries)

def collect_bundled_plugin_build_entries(params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    if params is None:
        params = {}
    
    cwd = params.get("cwd", os.getcwd())
    env = params.get("env", os.environ)
    extensions_root = os.path.join(cwd, BUNDLED_PLUGIN_ROOT_DIR)
    entries = []
    
    try:
        dirents = os.listdir(extensions_root)
    except OSError:
        return entries
    
    for item in dirents:
        item_path = os.path.join(extensions_root, item)
        if not os.path.isdir(item_path):
            continue
        
        plugin_dir = os.path.join(extensions_root, item)
        manifest_path = os.path.join(plugin_dir, "openclaw.plugin.json")
        has_manifest = os.path.exists(manifest_path)
        package_json_path = os.path.join(plugin_dir, "package.json")
        package_json = read_bundled_plugin_package_json(package_json_path)
        top_level_public_surface_entries = collect_top_level_public_surface_entries(plugin_dir)
        
        if not has_manifest and not is_manifestless_bundled_runtime_support_package({
            "dirName": item,
            "packageJson": package_json,
            "topLevelPublicSurfaceEntries": top_level_public_surface_entries,
        }):
            continue
        
        if not should_build_bundled_cluster(item, env, {"packageJson": package_json}):
            continue
        
        source_entries_set = set()
        if has_manifest:
            source_entries_set.update(collect_plugin_source_entries(package_json))
        source_entries_set.update(top_level_public_surface_entries)
        
        entries.append({
            "id": item,
            "hasManifest": has_manifest,
            "hasPackageJson": package_json is not None,
            "packageJson": package_json,
            "sourceEntries": list(source_entries_set),
        })
    
    return entries

def list_bundled_plugin_build_entries(params: Optional[Dict[str, Any]] = None) -> Dict[str, str]:
    entries = collect_bundled_plugin_build_entries(params)
    result = {}
    
    for entry in entries:
        entry_id = entry["id"]
        for source_entry in entry["sourceEntries"]:
            normalized_entry = source_entry.lstrip("./")
            base_name = ".".join(normalized_entry.split(".")[:-1]) if "." in normalized_entry else normalized_entry
            entry_key = bundled_plugin_file(entry_id, base_name)
            full_path = os.path.join(BUNDLED_PLUGIN_ROOT_DIR, entry_id, normalized_entry)
            result[entry_key] = to_posix_path(full_path)
    
    return result

def list_bundled_plugin_pack_artifacts(params: Optional[Dict[str, Any]] = None) -> List[str]:
    if params is None:
        params = {}
    
    entries = [
        entry for entry in collect_bundled_plugin_build_entries(params)
        if entry["id"] not in NON_PACKAGED_BUNDLED_PLUGIN_DIRS
    ]
    artifacts = set()
    
    for entry in entries:
        entry_id = entry["id"]
        has_manifest = entry["hasManifest"]
        has_package_json = entry["hasPackageJson"]
        source_entries = entry["sourceEntries"]
        
        if has_manifest:
            artifacts.add(bundled_dist_plugin_file(entry_id, "openclaw.plugin.json"))
        if has_package_json:
            artifacts.add(bundled_dist_plugin_file(entry_id, "package.json"))
        
        for source_entry in source_entries:
            normalized_entry = source_entry.lstrip("./")
            base_name = ".".join(normalized_entry.split(".")[:-1]) if "." in normalized_entry else normalized_entry
            artifacts.add(bundled_dist_plugin_file(entry_id, f"{base_name}.js"))
    
    return sorted(list(artifacts))

def list_bundled_plugin_runtime_dependencies(params: Optional[Dict[str, Any]] = None) -> List[str]:
    if params is None:
        params = {}
    
    runtime_dependencies = set()
    
    for entry in collect_bundled_plugin_build_entries(params):
        package_json = entry["packageJson"]
        if not should_stage_bundled_plugin_runtime_dependencies(package_json):
            continue
        
        dependencies = package_json.get("dependencies", {}) if isinstance(package_json, dict) else {}
        optional_dependencies = package_json.get("optionalDependencies", {}) if isinstance(package_json, dict) else {}
        
        for dep_name in dependencies.keys():
            runtime_dependencies.add(dep_name)
        for dep_name in optional_dependencies.keys():
            runtime_dependencies.add(dep_name)
    
    return sorted(list(runtime_dependencies))
