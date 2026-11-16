#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "00b48b16c93a48af8de2af4725b2e6c6ff4ad8d99b2263cdcc095276a0a7f36b", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "python"}
# check-pairing-account-scope.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import ast
import os
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

# Utility functions equivalent to the imported ones


def get_property_name_text(node):
    """Get the text name of a property key node."""
    if isinstance(node, ast.Str):  # Python < 3.8
        return node.s
    elif isinstance(node, ast.Constant) and isinstance(node.value, str):  # Python >= 3.8
        return node.value
    elif isinstance(node, ast.Name):
        return node.id
    return None


def is_undefined_like_expression(node):
    """Check if an AST node represents undefined or null-like expression."""
    # For Python we'll treat None as our undefined/null equivalent
    if isinstance(node, ast.Constant) and node.value is None:
        return True
    return False


def has_required_account_id_property(node):
    """Check if object literal has non-null accountId property."""
    if not isinstance(node, ast.Dict):
        return False
    
    for key, value in zip(node.keys, node.values):
        prop_name = get_property_name_text(key)
        if prop_name == "accountId":
            # Check if value is not None/undefined
            if not is_undefined_like_expression(value):
                return True
            else:
                return False
    return False


def to_line(node):
    """Get line number from node."""
    return getattr(node, 'lineno', 0)


def collect_file_violations(source_roots, repo_root, find_violations_func):
    """Collect violations across files."""
    violations = []
    
    for source_root in source_roots:
        root_path = Path(repo_root).joinpath(source_root)
        if not root_path.exists():
            continue
            
        for py_file in root_path.rglob("*.py"):
            try:
                with open(py_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                file_violations = find_violations_func(content, str(py_file))
                for violation in file_violations:
                    violations.append({
                        'path': str(py_file.relative_to(repo_root)),
                        'line': violation['line'],
                        'reason': violation['reason']
                    })
            except Exception:
                # Skip files that can't be parsed
                pass
                
    return violations


def create_pairing_guard_context(script_path):
    """Create context similar to the JS version."""
    script_dir = Path(script_path).parent
    repo_root = script_dir.parent
    source_roots = ["."]
    return {'repoRoot': str(repo_root), 'sourceRoots': source_roots}


class PairingScopeVisitor(ast.NodeVisitor):
    """AST visitor to find pairing scope violations."""

    def __init__(self, source_file_content):
        self.source_lines = source_file_content.split('\n')
        self.violations = []

    def visit_Call(self, node):
        """Visit call expressions."""
        if isinstance(node.func, ast.Name):
            call_name = node.func.id
            
            if call_name == "readChannelAllowFromStore":
                # Check if third argument exists and is not None
                if len(node.args) < 3 or is_undefined_like_expression(node.args[2]):
                    self.violations.append({
                        'line': to_line(node),
                        'reason': "readChannelAllowFromStore call must pass explicit accountId as 3rd arg"
                    })
            
            elif call_name in ("readLegacyChannelAllowFromStore", "readLegacyChannelAllowFromStoreSync"):
                self.violations.append({
                    'line': to_line(node),
                    'reason': f"{call_name} is legacy-only; use account-scoped readChannelAllowFromStore* APIs"
                })
            
            elif call_name == "upsertChannelPairingRequest":
                first_arg = node.args[0] if node.args else None
                if not first_arg or not has_required_account_id_property(first_arg):
                    self.violations.append({
                        'line': to_line(node),
                        'reason': "upsertChannelPairingRequest call must include accountId in params"
                    })
        
        self.generic_visit(node)


def find_violations(content, file_path):
    """Find violations in the given file content."""
    try:
        tree = ast.parse(content)
        visitor = PairingScopeVisitor(content)
        visitor.visit(tree)
        return visitor.violations
    except SyntaxError:
        # Return empty list for syntax errors
        return []


async def main():
    """Main execution function."""
    context = create_pairing_guard_context(__file__)
    repo_root = context['repoRoot']
    source_roots = context['sourceRoots']
    
    violations = collect_file_violations(
        source_roots,
        repo_root,
        find_violations
    )
    
    if len(violations) == 0:
        return
    
    print("Found unscoped pairing-store calls:", file=sys.stderr)
    for violation in violations:
        print(f"- {violation['path']}:{violation['line']} ({violation['reason']})", file=sys.stderr)
    
    sys.exit(1)


def run_as_script(script_path, main_func):
    """Run the main function if this script is executed directly."""
    import asyncio
    if Path(script_path) == Path(__file__):
        asyncio.run(main_func())


if __name__ == "__main__":
    run_as_script(__file__, main)
