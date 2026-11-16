#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "15a5f2a97cdea74b1f7f13e61ae0ab56dd23c575602eead712d997e1aeca4add", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "python"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import asyncio
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# Import TypeScript-like functionality
import ast
import importlib.util

# Constants - these would need to be imported or defined
BUNDLED_PLUGIN_PATH_PREFIX = "src/extensions/"
BUNDLED_PLUGIN_ROOT_DIR = "src/extensions"

def normalize_repo_path(repo_root: str, full_path: str) -> str:
    """Normalize a path relative to the repository root"""
    return os.path.relpath(full_path, repo_root).replace("\\", "/")

def resolve_repoSpecifier(repo_root: str, specifier: str, file_path: str) -> Optional[str]:
    """Resolve a module specifier to a path"""
    if specifier.startswith("."):
        # Resolve relative path
        base_dir = os.path.dirname(file_path)
        resolved = os.path.normpath(os.path.join(base_dir, specifier))
        # Check if it's within repo
        try:
            rel_path = os.path.relpath(resolved, repo_root).replace("\\", "/")
            if not rel_path.startswith(".."):
                return rel_path
        except ValueError:
            # Paths on different drives (Windows)
            pass
    elif specifier.startswith("openclaw/"):
        # This is likely an alias - convert to actual path
        return specifier.replace("openclaw/", "src/")
    return None

def visit_module_specifiers(source_code: str, file_path: str, callback):
    """Visit all import/export statements in a Python file"""
    try:
        tree = ast.parse(source_code)
    except SyntaxError:
        return
    
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                callback({
                    'kind': 'import',
                    'specifier': alias.name,
                    'specifierNode': node
                })
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                callback({
                    'kind': 'import',
                    'specifier': node.module,
                    'specifierNode': node
                })
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == '__import__':
                # Dynamic import
                if node.args and isinstance(node.args[0], ast.Constant):
                    callback({
                        'kind': 'dynamic-import',
                        'specifier': str(node.args[0].value),
                        'specifierNode': node
                    })

def write_line(stream, text: str):
    """Write a line to a stream"""
    stream.write(text + "\n")

def to_line(source_file_content: str, node) -> int:
    """Get line number from AST node"""
    return getattr(node, 'lineno', 0)

def classify_bundled_extension_source_path(relative_path: str) -> Dict[str, bool]:
    """Classify if a path is test-like"""
    is_test_like = any(part in relative_path for part in [
        "__tests__", "__mocks__", "__test__", ".test.", ".spec."
    ])
    return {"isTestLike": is_test_like}

def diff_inventory_entries(expected, actual, compare_func) -> Dict[str, list]:
    """Diff two inventory lists"""
    missing = []
    unexpected = []
    
    # Convert to sets for comparison
    expected_set = {(e['file'], e['line'], e['kind'], e['specifier']) for e in expected}
    actual_set = {(a['file'], a['line'], a['kind'], a['specifier']) for a in actual}
    
    # Find missing entries
    for entry in expected:
        key = (entry['file'], entry['line'], entry['kind'], entry['specifier'])
        if key not in actual_set:
            missing.append(entry)
    
    # Find unexpected entries
    for entry in actual:
        key = (entry['file'], entry['line'], entry['kind'], entry['specifier'])
        if key not in expected_set:
            unexpected.append(entry)
            
    return {"missing": missing, "unexpected": unexpected}

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
extensions_root = os.path.join(repo_root, BUNDLED_PLUGIN_ROOT_DIR)

MODES: Set[str] = {
    "src-outside-plugin-sdk",
    "plugin-sdk-internal",
    "relative-outside-package",
}

baseline_path_by_mode = {
    "src-outside-plugin-sdk": os.path.join(
        repo_root,
        "test",
        "fixtures",
        "extension-src-outside-plugin-sdk-inventory.json",
    ),
    "plugin-sdk-internal": os.path.join(
        repo_root,
        "test",
        "fixtures",
        "extension-plugin-sdk-internal-inventory.json",
    ),
    "relative-outside-package": os.path.join(
        repo_root,
        "test",
        "fixtures",
        "extension-relative-outside-package-inventory.json",
    ),
}

all_inventory_by_mode_promise = None
parsed_extension_source_files_promise = None

rule_text_by_mode = {
    "src-outside-plugin-sdk":
        "Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**",
    "plugin-sdk-internal":
        "Rule: production bundled plugins must not import src/plugin-sdk-internal/**",
    "relative-outside-package":
        "Rule: production bundled plugins must not use relative imports that escape their own package root",
}

def is_code_file(file_name: str) -> bool:
    return re.search(r"\.(py)$", file_name) is not None

def is_boundary_canary_file(file_name: str) -> bool:
    return "__rootdir_boundary_canary__" in file_name

async def collect_extension_source_files(root_dir: str) -> List[str]:
    out = []
    
    def walk(dir_path: str):
        try:
            entries = os.listdir(dir_path)
        except OSError:
            return
            
        for entry in entries:
            if entry == "dist" or entry == "node_modules":
                continue
            full_path = os.path.join(dir_path, entry)
            if os.path.isdir(full_path):
                walk(full_path)
                continue
            if not os.path.isfile(full_path) or not is_code_file(entry) or is_boundary_canary_file(entry):
                continue
            relative_path = normalize_repo_path(repo_root, full_path)
            if classify_bundled_extension_source_path(relative_path)["isTestLike"]:
                continue
            out.append(full_path)
    
    walk(root_dir)
    
    # Sort by normalized repo path
    return sorted(out, key=lambda x: normalize_repo_path(repo_root, x))

async def collect_parsed_extension_source_files():
    global parsed_extension_source_files_promise
    if parsed_extension_source_files_promise is None:
        async def inner():
            files = await collect_extension_source_files(extensions_root)
            result = []
            for file_path in files:
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        source = f.read()
                    result.append({
                        "filePath": file_path,
                        "sourceFile": source,
                    })
                except Exception:
                    pass
            return result
        parsed_extension_source_files_promise = asyncio.create_task(inner())
    return await parsed_extension_source_files_promise

def resolve_extension_root(file_path: str) -> Optional[str]:
    relative_path = normalize_repo_path(repo_root, file_path)
    segments = relative_path.split("/")
    if len(segments) < 2 or segments[0] != BUNDLED_PLUGIN_ROOT_DIR:
        return None
    return f"{segments[0]}/{segments[1]}"

def classify_reason(mode: str, kind: str, resolved_path: Optional[str], specifier: str) -> str:
    verb = ""
    if kind == "export":
        verb = "re-exports"
    elif kind == "dynamic-import":
        verb = "dynamically imports"
    else:
        verb = "imports"
        
    if mode == "relative-outside-package":
        if resolved_path and resolved_path.startswith("src/plugin-sdk/"):
            return f"{verb} plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>"
        if resolved_path and resolved_path.startswith("src/"):
            return f"{verb} core src path via relative path outside the extension package"
        if resolved_path and resolved_path.startswith(BUNDLED_PLUGIN_PATH_PREFIX):
            return f"{verb} another bundled plugin via relative path outside the extension package"
        return f"{verb} relative path {specifier} outside the extension package"
    if mode == "plugin-sdk-internal":
        return f"{verb} src/plugin-sdk-internal from an extension"
    if resolved_path and resolved_path.startswith("src/plugin-sdk/"):
        return f"{verb} allowed plugin-sdk path"
    return f"{verb} core src path outside plugin-sdk from an extension"

def compare_entries(left: Dict, right: Dict) -> int:
    file_cmp = (left['file'] > right['file']) - (left['file'] < right['file'])
    if file_cmp != 0:
        return file_cmp
    line_diff = left['line'] - right['line']
    if line_diff != 0:
        return line_diff
    kind_cmp = (left['kind'] > right['kind']) - (left['kind'] < right['kind'])
    if kind_cmp != 0:
        return kind_cmp
    spec_cmp = (left['specifier'] > right['specifier']) - (left['specifier'] < right['specifier'])
    if spec_cmp != 0:
        return spec_cmp
    res_cmp = (left['resolvedPath'] > right['resolvedPath']) - (left['resolvedPath'] < right['resolvedPath'])
    if res_cmp != 0:
        return res_cmp
    reason_cmp = (left['reason'] > right['reason']) - (left['reason'] < right['reason'])
    return reason_cmp

def should_report(mode: str, resolved_path: Optional[str]) -> bool:
    if mode == "relative-outside-package":
        return False
    if not resolved_path or not resolved_path.startswith("src/"):
        return False
    if mode == "plugin-sdk-internal":
        return resolved_path.startswith("src/plugin-sdk-internal/")
    return not resolved_path.startswith("src/plugin-sdk/")

def collect_entries_by_mode_from_source_file(source_file: str, file_path: str) -> Dict[str, List]:
    entries_by_mode = {
        "src-outside-plugin-sdk": [],
        "plugin-sdk-internal": [],
        "relative-outside-package": [],
    }
    extension_root = resolve_extension_root(file_path)
    relative_file = normalize_repo_path(repo_root, file_path)

    def push(kind: str, specifier_node, specifier: str):
        resolved_path = resolve_repoSpecifier(repo_root, specifier, file_path)
        base_entry = {
            "file": relative_file,
            "line": to_line(source_file, specifier_node),
            "kind": kind,
            "specifier": specifier,
            "resolvedPath": resolved_path or "",
        }

        if specifier.startswith(".") and resolved_path and extension_root:
            if not (resolved_path == extension_root or resolved_path.startswith(f"{extension_root}/")):
                entries_by_mode["relative-outside-package"].append({
                    **base_entry,
                    "reason": classify_reason("relative-outside-package", kind, resolved_path, specifier),
                })

        for mode in ["src-outside-plugin-sdk", "plugin-sdk-internal"]:
            if not should_report(mode, resolved_path):
                continue
            entries_by_mode[mode].append({
                **base_entry,
                "reason": classify_reason(mode, kind, resolved_path, specifier),
            })

    def callback(data):
        push(data['kind'], data['specifierNode'], data['specifier'])
        
    visit_module_specifiers(source_file, file_path, callback)
    return entries_by_mode

async def collect_extension_plugin_sdk_boundary_inventory(mode: str) -> List:
    global all_inventory_by_mode_promise
    if mode not in MODES:
        raise ValueError(f"Unknown mode: {mode}")
    if all_inventory_by_mode_promise is None:
        async def inner():
            files = await collect_parsed_extension_source_files()
            inventory_by_mode = {
                "src-outside-plugin-sdk": [],
                "plugin-sdk-internal": [],
                "relative-outside-package": [],
            }
            for item in files:
                file_path = item["filePath"]
                source_file = item["sourceFile"]
                entries_by_mode = collect_entries_by_mode_from_source_file(source_file, file_path)
                for inventory_mode in MODES:
                    inventory_by_mode[inventory_mode].extend(entries_by_mode[inventory_mode])
            
            # Sort each mode's entries
            for inventory_mode in MODES:
                inventory_by_mode[inventory_mode].sort(key=lambda x: (
                    x['file'], x['line'], x['kind'], x['specifier'], x['resolvedPath'], x['reason']
                ))
            return inventory_by_mode
        all_inventory_by_mode_promise = asyncio.create_task(inner())
    inventory_by_mode = await all_inventory_by_mode_promise
    return inventory_by_mode[mode]

async def read_expected_inventory(mode: str) -> List:
    try:
        with open(baseline_path_by_mode[mode], 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        if mode in ["plugin-sdk-internal", "src-outside-plugin-sdk", "relative-outside-package"]:
            return []
        raise
    except Exception:
        raise

def diff_inventory(expected: List, actual: List) -> Dict[str, list]:
    return diff_inventory_entries(expected, actual, compare_entries)

def format_inventory_human(mode: str, inventory: List) -> str:
    lines = [rule_text_by_mode[mode]]
    if len(inventory) == 0:
        lines.append("No extension plugin-sdk boundary violations found.")
        return "\n".join(lines)
    lines.append("Extension boundary inventory:")
    active_file = ""
    for entry in inventory:
        if entry['file'] != active_file:
            active_file = entry['file']
            lines.append(active_file)
        lines.append(f"  - line {entry['line']} [{entry['kind']}] {entry['reason']}")
        lines.append(f"    specifier: {entry['specifier']}")
        lines.append(f"    resolved: {entry['resolvedPath']}")
    return "\n".join(lines)

async def run_extension_plugin_sdk_boundary_check(argv=None, io=None) -> int:
    if argv is None:
        argv = sys.argv[2:]
    if io is None:
        io = {"stdout": sys.stdout, "stderr": sys.stderr}
    
    streams = io
    json_flag = "--json" in argv
    mode_arg = next((arg for arg in argv if arg.startswith("--mode=")), None)
    mode = mode_arg[len("--mode="):] if mode_arg else "src-outside-plugin-sdk"
    if mode not in MODES:
        raise ValueError(f"Unknown mode: {mode}")

    actual = await collect_extension_plugin_sdk_boundary_inventory(mode)
    if json_flag:
        write_line(streams["stdout"], json.dumps(actual, indent=2))
        return 0

    write_line(streams["stdout"], format_inventory_human(mode, actual))
    if mode == "relative-outside-package":
        if len(actual) == 0:
            return 0
        write_line(
            streams["stderr"],
            f"Relative outside-package violations found ({len(actual)}); this mode no longer uses a baseline.",
        )
        return 1

    expected = await read_expected_inventory(mode)
    diff = diff_inventory(expected, actual)
    if len(diff["missing"]) == 0 and len(diff["unexpected"]) == 0:
        write_line(streams["stdout"], f"Baseline matches ({len(actual)} entries).")
        return 0
    if len(diff["missing"]) > 0:
        write_line(streams["stderr"], f"Missing baseline entries ({len(diff['missing'])}):")
        for entry in diff["missing"]:
            write_line(streams["stderr"], f"  - {entry['file']}:{entry['line']} {entry['reason']}")
    if len(diff["unexpected"]) > 0:
        write_line(streams["stderr"], f"Unexpected inventory entries ({len(diff['unexpected'])}):")
        for entry in diff["unexpected"]:
            write_line(streams["stderr"], f"  - {entry['file']}:{entry['line']} {entry['reason']}")
    return 1

async def main(argv=None, io=None) -> int:
    exit_code = await run_extension_plugin_sdk_boundary_check(argv, io)
    if io is None:
        sys.exit(exit_code)
    return exit_code

if __name__ == "__main__":
    asyncio.run(main())
