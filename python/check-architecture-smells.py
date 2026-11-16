#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "63f7a9e62b66765fb97156191aca495ecd39573d77151e934eb2a867ac78eef5", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "python"}
# check-architecture-smells.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import re
from pathlib import Path
from typing import List, Dict, Any, Set, Tuple, Callable
import subprocess

# Import TypeScript parser library
try:
    import tree_sitter_typescript as tst
    from tree_sitter import Language, Parser
except ImportError:
    print("Error: tree-sitter-typescript not installed", file=sys.stderr)
    print("Install with: pip install tree-sitter tree-sitter-typescript", file=sys.stderr)
    sys.exit(1)

# Constants
BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
REPO_ROOT = Path(__file__).parent.parent.resolve()

def resolve_source_roots(repo_root: Path, paths: List[str]) -> List[Path]:
    """Resolve source roots to absolute paths."""
    return [repo_root / path for path in paths]

SCAN_ROOTS = resolve_source_roots(REPO_ROOT, ["src/plugin-sdk", "src/plugins/runtime"])

def normalize_repo_path(repo_root: Path, file_path: str) -> str:
    """Normalize a file path relative to the repository root."""
    try:
        return str(Path(file_path).relative_to(repo_root)).replace("\\", "/")
    except ValueError:
        return str(file_path).replace("\\", "/")

def resolve_repo_specifier(repo_root: Path, specifier: str, file_path: str) -> str:
    """Resolve a module specifier to a repository-relative path."""
    if specifier.startswith(".") or specifier.startswith(".."):
        # Relative import
        base_dir = Path(file_path).parent
        resolved = (base_dir / specifier).resolve()
        try:
            return normalize_repo_path(repo_root, str(resolved))
        except ValueError:
            return str(resolved)
    elif specifier.startswith(BUNDLED_PLUGIN_PATH_PREFIX):
        # Extension path
        return specifier
    else:
        # Absolute import - would need mapping logic here
        return specifier

def to_line(source_code: bytes, node) -> int:
    """Get line number from node."""
    return source_code[:node.start_byte].count(b'\n') + 1

def write_line(stream, text: str) -> None:
    """Write a line to output stream."""
    stream.write(text + "\n")

def collect_type_script_files_from_roots(roots: List[Path]) -> List[str]:
    """Collect all TypeScript files from given roots."""
    files = []
    for root in roots:
        if root.exists():
            for file_path in root.rglob("*.ts"):
                files.append(str(file_path))
    return sorted(files)

def visit_module_specifiers(parser_lib, source_file, source_bytes: bytes, visitor: Callable) -> None:
    """Visit all module specifiers in a source file."""
    def traverse(node):
        if node.type == 'import_statement' or node.type == 'export_statement':
            for child in node.children:
                if child.type == 'string':
                    specifier = child.text.decode('utf-8').strip('"\'')
                    visitor({
                        'kind': 'import' if node.type == 'import_statement' else 'export',
                        'specifier': specifier,
                        'specifier_node': child
                    })
        elif node.type == 'import_type':
            # Handle import types like `import("./path").Type`
            for child in node.children:
                if child.type == 'string':
                    specifier = child.text.decode('utf-8').strip('"\'')
                    visitor({
                        'kind': 'import-type',
                        'specifier': specifier,
                        'specifier_node': child
                    })
        
        for child in node.children:
            traverse(child)
    
    traverse(source_file.root_node)

def compare_entries(left: Dict, right: Dict) -> int:
    """Compare two inventory entries for sorting."""
    result = left['category'].localeCompare(right['category']) if hasattr(str, 'localeCompare') else \
             (1 if left['category'] > right['category'] else (-1 if left['category'] < right['category'] else 0))
    if result != 0:
        return result
    
    result = left['file'].localeCompare(right['file']) if hasattr(str, 'localeCompare') else \
             (1 if left['file'] > right['file'] else (-1 if left['file'] < right['file'] else 0))
    if result != 0:
        return result
    
    diff = left['line'] - right['line']
    if diff != 0:
        return diff
    
    result = left['kind'].localeCompare(right['kind']) if hasattr(str, 'localeCompare') else \
             (1 if left['kind'] > right['kind'] else (-1 if left['kind'] < right['kind'] else 0))
    if result != 0:
        return result
    
    result = left['specifier'].localeCompare(right['specifier']) if hasattr(str, 'localeCompare') else \
             (1 if left['specifier'] > right['specifier'] else (-1 if left['specifier'] < right['specifier'] else 0))
    if result != 0:
        return result
    
    result = left['reason'].localeCompare(right['reason']) if hasattr(str, 'localeCompare') else \
             (1 if left['reason'] > right['reason'] else (-1 if left['reason'] < right['reason'] else 0))
    return result

def push_entry(entries: List, entry: Dict) -> None:
    """Add an entry to the list."""
    entries.append(entry)

def scan_plugin_sdk_extension_facade_smells(parser_lib, source_file, source_bytes: bytes, file_path: str) -> List[Dict]:
    """Scan for plugin SDK extension facade smells."""
    relative_file = normalize_repo_path(REPO_ROOT, file_path)
    if not relative_file.startswith("src/plugin-sdk/"):
        return []

    entries = []

    def visitor(data):
        if data['kind'] != "export":
            return
        resolved_path = resolve_repo_specifier(REPO_ROOT, data['specifier'], file_path)
        if resolved_path and resolved_path.startswith(BUNDLED_PLUGIN_PATH_PREFIX):
            push_entry(entries, {
                'category': "plugin-sdk-extension-facade",
                'file': relative_file,
                'line': to_line(source_bytes, data['specifier_node']),
                'kind': data['kind'],
                'specifier': data['specifier'],
                'resolvedPath': resolved_path,
                'reason': "plugin-sdk public surface re-exports extension-owned implementation",
            })
    
    visit_module_specifiers(parser_lib, source_file, source_bytes, visitor)
    return entries

def scan_runtime_type_implementation_smells(parser_lib, source_file, source_bytes: bytes, file_path: str) -> List[Dict]:
    """Scan for runtime type implementation smells."""
    relative_file = normalize_repo_path(REPO_ROOT, file_path)
    if not re.match(r"^src/plugins/runtime/types(?:-[^/]+)?\.ts$", relative_file):
        return []

    entries = []

    def traverse(node):
        if node.type == 'import_type':
            # Look for string literals inside import types
            for child in node.children:
                if child.type == 'string':
                    specifier = child.text.decode('utf-8').strip('"\'')
                    resolved_path = resolve_repo_specifier(REPO_ROOT, specifier, file_path)
                    if resolved_path and (
                            re.match(r"^src/plugins/runtime/runtime-[^/]+\.ts$", resolved_path) or
                            re.match(r"^extensions/[^/]+/runtime-api\.[^/]+$", resolved_path)):
                        push_entry(entries, {
                            'category': "runtime-type-implementation-edge",
                            'file': relative_file,
                            'line': to_line(source_bytes, child),
                            'kind': "import-type",
                            'specifier': specifier,
                            'resolvedPath': resolved_path,
                            'reason': "runtime type file references implementation shim directly",
                        })
        
        for child in node.children:
            traverse(child)
    
    traverse(source_file.root_node)
    return entries

def scan_runtime_service_locator_smells(parser_lib, source_file, source_bytes: bytes, file_path: str) -> List[Dict]:
    """Scan for runtime service locator smells."""
    relative_file = normalize_repo_path(REPO_ROOT, file_path)
    if not (relative_file.startswith("src/plugin-sdk/") or relative_file.startswith("src/plugins/runtime/")):
        return []

    entries = []
    exported_names: Set[str] = set()
    runtime_store_calls = []
    mutable_state_nodes = []

    # Collect exported names and mutable state
    for node in source_file.root_node.children:
        if node.type == 'function_declaration':
            name_node = None
            is_exported = False
            
            for child in node.children:
                if child.type == 'identifier':
                    name_node = child
                elif child.type == 'export_keyword':
                    is_exported = True
            
            if name_node and is_exported:
                exported_names.add(name_node.text.decode('utf-8'))
                
        elif node.type == 'variable_declaration':
            is_exported = any(c.type == 'export_keyword' for c in node.children)
            is_let = any(c.type == 'let_keyword' for c in node.children)
            
            for child in node.children:
                if child.type == 'identifier':
                    name = child.text.decode('utf-8')
                    if is_exported:
                        exported_names.add(name)
                    if not is_exported and is_let:
                        mutable_state_nodes.append({'node': child, 'text': name})

    # Find createPluginRuntimeStore calls
    def traverse(node):
        if node.type == 'call_expression':
            # Check if it's calling createPluginRuntimeStore
            func_name = ""
            if len(node.children) > 0 and node.children[0].type == 'identifier':
                func_name = node.children[0].text.decode('utf-8')
            
            if func_name == "createPluginRuntimeStore":
                runtime_store_calls.append(node.children[0])
        
        for child in node.children:
            traverse(child)
    
    traverse(source_file.root_node)

    getter_names = [name for name in exported_names if re.match(r"^get[A-Z]", name)]
    setter_names = [name for name in exported_names if re.match(r"^set[A-Z]", name)]

    if runtime_store_calls and getter_names and setter_names:
        for call_node in runtime_store_calls:
            push_entry(entries, {
                'category': "runtime-service-locator",
                'file': relative_file,
                'line': to_line(source_bytes, call_node),
                'kind': "runtime-store",
                'specifier': "createPluginRuntimeStore",
                'resolvedPath': relative_file,
                'reason': f"exports paired runtime accessors ({', '.join(getter_names)} / {', '.join(setter_names)}) over module-global store state",
            })

    if mutable_state_nodes and getter_names and setter_names:
        for identifier in mutable_state_nodes:
            push_entry(entries, {
                'category': "runtime-service-locator",
                'file': relative_file,
                'line': to_line(source_bytes, identifier['node']),
                'kind': "mutable-state",
                'specifier': identifier['text'],
                'resolvedPath': relative_file,
                'reason': f"module-global mutable state backs exported runtime accessors ({', '.join(getter_names)} / {', '.join(setter_names)})",
            })

    return entries

async def collect_architecture_smells() -> List[Dict]:
    """Collect all architecture smells."""
    # Initialize parser
    PY_LANGUAGE = Language(tst.language(), "typescript")
    parser = Parser()
    parser.set_language(PY_LANGUAGE)
    
    files = collect_type_script_files_from_roots(SCAN_ROOTS)
    
    all_entries = []
    
    for file_path in files:
        try:
            with open(file_path, 'rb') as f:
                source_bytes = f.read()
                source_file = parser.parse(source_bytes)
                
                entries = []
                entries.extend(scan_plugin_sdk_extension_facade_smells(PY_LANGUAGE, source_file, source_bytes, file_path))
                entries.extend(scan_runtime_type_implementation_smells(PY_LANGUAGE, source_file, source_bytes, file_path))
                entries.extend(scan_runtime_service_locator_smells(PY_LANGUAGE, source_file, source_bytes, file_path))
                
                all_entries.extend(entries)
        except Exception as e:
            print(f"Warning: Could not parse {file_path}: {e}", file=sys.stderr)
    
    # Sort entries
    all_entries.sort(key=lambda x: (
        x['category'],
        x['file'],
        x['line'],
        x['kind'],
        x['specifier'],
        x['reason']
    ))
    
    return all_entries

def format_inventory_human(inventory: List[Dict]) -> str:
    """Format inventory in human-readable form."""
    if len(inventory) == 0:
        return "No architecture smells found for the configured checks."

    lines = ["Architecture smell inventory:"]
    active_category = ""
    active_file = ""
    
    for entry in inventory:
        if entry['category'] != active_category:
            active_category = entry['category']
            active_file = ""
            lines.append(entry['category'])
        if entry['file'] != active_file:
            active_file = entry['file']
            lines.append(f"  {active_file}")
        lines.append(f"    - line {entry['line']} [{entry['kind']}] {entry['reason']}")
        lines.append(f"      specifier: {entry['specifier']}")
        lines.append(f"      resolved: {entry['resolvedPath']}")
    
    return "\n".join(lines)

async def run_architecture_smells_check(argv=None, io=None) -> int:
    """Run the architecture smells check."""
    if argv is None:
        argv = sys.argv[1:]
    
    if io is None:
        io = {'stdout': sys.stdout, 'stderr': sys.stderr}
    
    json_flag = "--json" in argv
    inventory = await collect_architecture_smells()

    if json_flag:
        write_line(io['stdout'], json.dumps(inventory, indent=2))
        return 0

    write_line(io['stdout'], format_inventory_human(inventory))
    write_line(io['stdout'], f"{len(inventory)} smell{'s' if len(inventory) != 1 else ''} found.")
    return 0

async def main(argv=None, io=None) -> int:
    """Main entry point."""
    return await run_architecture_smells_check(argv, io)

if __name__ == "__main__":
    import asyncio
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
