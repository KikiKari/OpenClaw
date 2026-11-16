#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9d05c00b90672d5b0cb70be193767f99c590bef5f5b9576b5c8b258332708a41", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "python"}
# check-no-random-messaging-tmp.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import ast
import os
import sys
from pathlib import Path
from typing import Set, List, Tuple, Callable, Optional
from urllib.parse import urlparse

# Import local modules (assuming they exist in the same directory structure)
from lib.bundled_plugin_paths import bundled_plugin_file
from lib.callsite_guard import run_callsite_guard
from lib.ts_guard_utils import run_as_script

messaging_tmpdir_guard_source_roots = [
    "src/channels",
    "src/infra/outbound",
    "src/line",
    "src/media",
    "src/media-understanding",
    "extensions",
]

allowed_relative_paths = {bundled_plugin_file("feishu", "src/dedup.ts")}

def collect_os_tmpdir_imports(tree: ast.AST) -> Tuple[Set[str], Set[str]]:
    """Collect imports of os module and tmpdir function"""
    os_module_specifiers = {"node:os", "os"}
    os_namespace_or_default = set()
    named_tmpdir = set()
    
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name in os_module_specifiers:
                    os_namespace_or_default.add(alias.asname or alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module in os_module_specifiers:
                for alias in node.names:
                    if (alias.name == "tmpdir"):
                        named_tmpdir.add(alias.asname or alias.name)
    
    return os_namespace_or_default, named_tmpdir

def find_messaging_tmpdir_call_lines(content: str, file_name: str = "source.py") -> List[int]:
    """Find lines with os.tmpdir() or tmpdir() calls"""
    try:
        tree = ast.parse(content, filename=file_name)
    except SyntaxError:
        return []
        
    os_namespace_or_default, named_tmpdir = collect_os_tmpdir_imports(tree)
    call_lines = []
    
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            # Check for property access like os.tmpdir()
            if (isinstance(node.func, ast.Attribute) and 
                node.func.attr == "tmpdir" and
                isinstance(node.func.value, ast.Name) and
                node.func.value.id in os_namespace_or_default):
                call_lines.append(node.lineno)
            
            # Check for direct function call like tmpdir()
            elif (isinstance(node.func, ast.Name) and 
                  node.func.id in named_tmpdir):
                call_lines.append(node.lineno)
    
    return call_lines

async def main():
    """Main function to run the callsite guard"""
    await run_callsite_guard(
        import_meta_url=__file__,
        source_roots=messaging_tmpdir_guard_source_roots,
        find_call_lines=find_messaging_tmpdir_call_lines,
        skip_relative_path=lambda relative_path: relative_path in allowed_relative_paths,
        header="Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:",
        footer="Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults.",
        sort_violations=False
    )

if __name__ == "__main__":
    run_as_script(__file__, main)
