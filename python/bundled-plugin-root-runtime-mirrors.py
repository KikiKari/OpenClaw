#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "26c846cf5d0399b74067aef4f1dbd291a156e8b068e2d1f9a1335e34a6c857c1", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "python"}
# bundled-plugin-root-runtime-mirrors.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import json
import os
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple, Any, Optional

JS_EXTENSIONS = {".cjs", ".js", ".mjs"}

def collect_runtime_dependency_specs(package_json: dict = None) -> Dict[str, str]:
    """
    Collect runtime dependencies from package.json dependencies and optionalDependencies.
    Returns a dictionary mapping dependency names to their version specifications.
    """
    if package_json is None:
        package_json = {}
    
    result = {}
    
    # Process dependencies
    deps = package_json.get("dependencies", {})
    for name, spec in deps.items():
        if isinstance(spec, str) and len(spec) > 0:
            result[name] = spec
    
    # Process optionalDependencies
    opt_deps = package_json.get("optionalDependencies", {})
    for name, spec in opt_deps.items():
        if isinstance(spec, str) and len(spec) > 0:
            result[name] = spec
            
    return result

def package_name_from_specifier(specifier: str) -> Optional[str]:
    """
    Extract package name from an import specifier.
    Returns None if the specifier is not a valid package name.
    """
    if (not isinstance(specifier, str) or 
        specifier.startswith(".") or 
        specifier.startswith("/") or 
        specifier.startswith("node:") or 
        specifier.startswith("#")):
        return None
    
    parts = specifier.split("/")
    if not parts[0]:
        return None
        
    if parts[0].startswith("@") and len(parts) >= 2:
        return f"{parts[0]}/{parts[1]}"
    else:
        return parts[0]

def read_json(file_path: str) -> dict:
    """Read and parse a JSON file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def collect_package_json_paths(root_dir: str) -> List[str]:
    """
    Collect paths to package.json files in subdirectories of root_dir.
    Returns sorted list of paths.
    """
    if not os.path.exists(root_dir):
        return []
    
    paths = []
    try:
        for entry in os.scandir(root_dir):
            if entry.is_dir():
                package_json_path = os.path.join(entry.path, "package.json")
                if os.path.exists(package_json_path):
                    paths.append(package_json_path)
    except OSError:
        return []
        
    return sorted(paths)

def collect_bundled_plugin_runtime_dependency_specs(bundled_plugins_dir: str) -> Dict[str, dict]:
    """
    Collect runtime dependency specifications from bundled plugins.
    Returns a dictionary with dependency information including conflicts.
    """
    specs = {}
    
    for package_json_path in collect_package_json_paths(bundled_plugins_dir):
        try:
            package_json = read_json(package_json_path)
            plugin_id = os.path.basename(os.path.dirname(package_json_path))
            
            for name, spec in collect_runtime_dependency_specs(package_json).items():
                existing = specs.get(name)
                if existing:
                    if existing["spec"] != spec:
                        existing["conflicts"].append({"pluginId": plugin_id, "spec": spec})
                    elif plugin_id not in existing["pluginIds"]:
                        existing["pluginIds"].append(plugin_id)
                    continue
                
                specs[name] = {
                    "conflicts": [],
                    "pluginIds": [plugin_id],
                    "spec": spec
                }
        except Exception:
            # Skip invalid package.json files
            continue
    
    return specs

def walk_java_script_files(root_dir: str) -> List[str]:
    """
    Walk directory tree and collect JavaScript files.
    Skips directories named 'extensions'.
    Returns sorted list of file paths.
    """
    files = []
    if not os.path.exists(root_dir):
        return files
    
    queue = [root_dir]
    while queue:
        current = queue.pop(0)
        try:
            for entry in os.scandir(current):
                full_path = os.path.join(current, entry.name)
                if entry.is_dir():
                    # Skip extensions directories
                    if "extensions" in full_path.split(os.sep):
                        continue
                    queue.append(full_path)
                    continue
                if entry.is_file() and os.path.splitext(entry.name)[1] in JS_EXTENSIONS:
                    files.append(full_path)
        except OSError:
            continue
            
    return sorted(files)

def extract_module_specifiers(source: str) -> Set[str]:
    """
    Extract module specifiers from JavaScript source code.
    Returns set of unique specifiers.
    """
    specifiers = set()
    
    patterns = [
        r'\bfrom\s*["\']([^"\']+)["\']',
        r'\bimport\s*["\']([^"\']+)["\']',
        r'\bimport\s*\(\s*["\']([^"\']+)["\']\s*\)',
        r'\brequire\s*\(\s*["\']([^"\']+)["\']\s*\)'
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, source)
        for match in matches:
            if match:
                specifiers.add(match)
                
    return specifiers

def collect_root_dist_bundled_runtime_mirrors(params: dict) -> Dict[str, dict]:
    """
    Collect information about bundled runtime dependencies used in root distribution.
    Returns mapping of dependency names to mirror information.
    """
    dist_dir = params["distDir"]
    bundled_specs = params["bundledRuntimeDependencySpecs"]
    mirrors = {}
    
    for file_path in walk_java_script_files(dist_dir):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                source = f.read()
        except Exception:
            continue
            
        relative_path = os.path.relpath(file_path, dist_dir).replace(os.sep, "/")
        
        for specifier in extract_module_specifiers(source):
            dependency_name = package_name_from_specifier(specifier)
            if not dependency_name or dependency_name not in bundled_specs:
                continue
                
            bundled_spec = bundled_specs[dependency_name]
            existing = mirrors.get(dependency_name)
            if existing:
                existing["importers"].add(relative_path)
                continue
                
            mirrors[dependency_name] = {
                "importers": {relative_path},
                "pluginIds": bundled_spec["pluginIds"],
                "spec": bundled_spec["spec"]
            }
    
    return mirrors

def collect_bundled_plugin_root_runtime_mirror_errors(params: dict) -> List[str]:
    """
    Collect errors related to bundled plugin runtime mirror configuration.
    Returns list of error messages.
    """
    root_runtime_deps = collect_runtime_dependency_specs(params["rootPackageJson"])
    errors = []
    
    # Check for conflicts in bundled dependencies
    for dependency_name, record in params["bundledRuntimeDependencySpecs"].items():
        for conflict in record["conflicts"]:
            errors.append(
                f"bundled runtime dependency '{dependency_name}' has conflicting plugin specs: {', '.join(record['pluginIds'])} use '{record['spec']}', {conflict['pluginId']} uses '{conflict['spec']}'."
            )
    
    # Check required root mirrors
    for dependency_name, mirror in params["requiredRootMirrors"].items():
        root_spec = root_runtime_deps.get(dependency_name)
        importers = sorted(list(mirror["importers"]))
        importer_label = ", ".join(importers)
        plugin_label = ", ".join(sorted(mirror["pluginIds"]))
        
        if not isinstance(root_spec, str) or len(root_spec) == 0:
            errors.append(
                f"root dist imports bundled plugin runtime dependency '{dependency_name}' from {importer_label}; mirror '{dependency_name}: {mirror['spec']}' in root package.json (declared by {plugin_label})."
            )
            continue
            
        if root_spec != mirror["spec"]:
            errors.append(
                f"root dist imports bundled plugin runtime dependency '{dependency_name}' from {importer_label}; root package.json has '{root_spec}' but plugin manifest declares '{mirror['spec']}' ({plugin_label})."
            )
    
    return errors
