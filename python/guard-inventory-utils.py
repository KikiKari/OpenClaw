#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "5eb0de20a677c32fa38a22ad60854294cc023b7c57148d5f4ec7c512a9bc108a", "source_sha256": "f01a1a7ac46054c631b27d8f3e127238ed7417a0fe38ecb59857573bd355603f", "target_language": "python"}
# guard-inventory-utils.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/guard-inventory-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import os
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Set, TextIO, Tuple, Union


parsedTypeScriptSourceCache: Dict[str, Any] = {}


def normalize_repo_path(repo_root: str, file_path: str) -> str:
    """Normalize a file path relative to the repository root."""
    rel_path = os.path.relpath(file_path, repo_root)
    return rel_path.replace(os.sep, "/")


def resolve_repo_specifier(repo_root: str, specifier: str, importer_file: str) -> Optional[str]:
    """Resolve a module specifier to a repository-relative path."""
    if specifier.startswith("."):
        resolved = os.path.normpath(os.path.join(os.path.dirname(importer_file), specifier))
        return normalize_repo_path(repo_root, resolved)
    if specifier.startswith("/"):
        return normalize_repo_path(repo_root, specifier)
    return None


def visit_module_specifiers(ts: Any, source_file: Any, visit: Callable[[Dict[str, Any]], None]) -> None:
    """Visit all module specifiers in a TypeScript source file."""
    
    def walk(node: Any) -> None:
        if (hasattr(ts, 'isImportDeclaration') and ts.isImportDeclaration(node) and 
            hasattr(ts, 'isStringLiteral') and ts.isStringLiteral(node.moduleSpecifier)):
            visit({
                "kind": "import",
                "node": node,
                "specifier": node.moduleSpecifier.text,
                "specifierNode": node.moduleSpecifier,
            })
        elif (hasattr(ts, 'isExportDeclaration') and ts.isExportDeclaration(node) and
              node.moduleSpecifier and
              hasattr(ts, 'isStringLiteral') and ts.isStringLiteral(node.moduleSpecifier)):
            visit({
                "kind": "export",
                "node": node,
                "specifier": node.moduleSpecifier.text,
                "specifierNode": node.moduleSpecifier,
            })
        elif (hasattr(ts, 'isCallExpression') and ts.isCallExpression(node) and
              hasattr(node.expression, 'kind') and node.expression.kind == getattr(ts, 'SyntaxKind', {}).get('ImportKeyword', None) and
              len(node.arguments) == 1 and
              hasattr(ts, 'isStringLiteral') and ts.isStringLiteral(node.arguments[0])):
            visit({
                "kind": "dynamic-import",
                "node": node,
                "specifier": node.arguments[0].text,
                "specifierNode": node.arguments[0],
            })

        # Recursively walk child nodes
        if hasattr(ts, 'forEachChild'):
            ts.forEachChild(node, walk)

    walk(source_file)


def diff_inventory_entries(expected: List[Any], actual: List[Any], compare_entries: Callable[[Any, Any], int]) -> Dict[str, List[Any]]:
    """Compare expected and actual inventory entries."""
    expected_keys = {json.dumps(entry, sort_keys=True) for entry in expected}
    actual_keys = {json.dumps(entry, sort_keys=True) for entry in actual}
    
    missing = [entry for entry in expected if json.dumps(entry, sort_keys=True) not in actual_keys]
    unexpected = [entry for entry in actual if json.dumps(entry, sort_keys=True) not in expected_keys]
    
    # Sort using the comparison function
    missing.sort(key=lambda x: (compare_entries(x, x), json.dumps(x, sort_keys=True)))
    unexpected.sort(key=lambda x: (compare_entries(x, x), json.dumps(x, sort_keys=True)))
    
    return {
        "missing": missing,
        "unexpected": unexpected,
    }


def write_line(stream: TextIO, text: str) -> None:
    """Write a line of text to a stream."""
    stream.write(f"{text}\n")


async def collect_type_script_inventory(params: Dict[str, Any]) -> List[Any]:
    """Collect TypeScript inventory entries from files."""
    inventory = []
    script_kind = params.get("scriptKind", params["ts"].ScriptKind.TS)
    
    for file_path in params["files"]:
        cache_key = f"{script_kind}:{file_path}"
        source_file = parsedTypeScriptSourceCache.get(cache_key)
        
        if not source_file:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()
            
            should_parse_source = params.get("shouldParseSource")
            if should_parse_source and not should_parse_source(source, file_path):
                continue
                
            source_file = params["ts"].createSourceFile(
                file_path,
                source,
                params["ts"].ScriptTarget.Latest,
                True,
                script_kind,
            )
            parsedTypeScriptSourceCache[cache_key] = source_file
            
        inventory.extend(params["collectEntries"](source_file, file_path))
    
    # Sort inventory using compareEntries function
    compare_entries = params.get("compareEntries")
    if compare_entries:
        inventory.sort(key=lambda x: (compare_entries(x, x), json.dumps(x, sort_keys=True)))
    else:
        inventory.sort(key=lambda x: json.dumps(x, sort_keys=True))
        
    return inventory


async def run_baseline_inventory_check(params: Dict[str, Any]) -> int:
    """Run a baseline inventory check."""
    streams = params.get("io", {"stdout": sys.stdout, "stderr": sys.stderr})
    argv = params.get("argv", [])
    json_output = "--json" in argv
    
    actual = await params["collectActual"]()
    expected = await params["readExpected"]()
    diff_result = params["diffInventory"](expected, actual)
    missing = diff_result["missing"]
    unexpected = diff_result["unexpected"]
    matches_baseline = len(missing) == 0 and len(unexpected) == 0
    
    if json_output:
        write_line(streams["stdout"], json.dumps(actual, indent=2))
    else:
        write_line(streams["stdout"], params["formatInventoryHuman"](actual))
        status_msg = (
            f"Baseline matches ({len(actual)} entries)." 
            if matches_baseline 
            else f"Baseline mismatch ({len(unexpected)} unexpected, {len(missing)} missing)."
        )
        write_line(streams["stdout"], status_msg)
        
        if not matches_baseline:
            if len(unexpected) > 0:
                write_line(streams["stderr"], "Unexpected entries:")
                for entry in unexpected:
                    write_line(streams["stderr"], f"- {params['formatEntry'](entry)}")
            if len(missing) > 0:
                write_line(streams["stderr"], "Missing baseline entries:")
                for entry in missing:
                    write_line(streams["stderr"], f"- {params['formatEntry'](entry)}")
                    
    return 0 if matches_baseline else 1


# Import sys for default streams
import sys
