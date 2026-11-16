#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "206e7d7db8f690c4ccac10f20e0f91997b3df6b51bf3e2c5fff46c173ba92b64", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "python"}
# check-no-pairing-store-group-auth.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import argparse
import os
import re
import sys
from pathlib import Path

# Since we don't have TypeScript AST parsing in Python, we'll use regex-based analysis
# This is a simplified approximation that captures the core logic

def create_pairing_guard_context(script_path):
    """Create context similar to the JS version"""
    script_dir = Path(script_path).parent.absolute()
    repo_root = script_dir.parent
    source_roots = [str(repo_root / "src")]
    
    def resolve_from_repo(rel_path):
        return str(repo_root / rel_path)
    
    return {
        'repoRoot': str(repo_root),
        'sourceRoots': source_roots,
        'resolveFromRepo': resolve_from_repo
    }

# Configuration constants
ALLOWED_FILES = set([
    "src/security/dm-policy-shared.ts",
    "src/channels/allow-from.ts",
    "src/security/fix.ts",
    "src/security/audit-channel.ts",
])

STORE_IDENTIFIER_RE = re.compile(r'^(?:storeAllowFrom|storedAllowFrom|storeAllowList)$', re.IGNORECASE)
GROUP_NAME_RE = re.compile(r'(?:groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender)', re.IGNORECASE)

STORE_SOURCE_CALL_NAMES = set([
    "readChannelAllowFromStore",
    "readChannelAllowFromStoreSync", 
    "readStoreAllowFromForDmPolicy",
])

ALLOWED_RESOLVER_CALL_NAMES = set([
    "resolveEffectiveAllowFromLists",
    "resolveDmGroupAccessWithLists", 
    "resolveMattermostEffectiveAllowFromLists",
    "resolveIrcEffectiveAllowlists",
])

def get_property_name_text(name_node):
    """Extract property name text - simplified for regex approach"""
    return name_node

def contains_pairing_store_source(code_segment):
    """Check if code segment contains pairing store references"""
    # Simple regex check for store identifiers
    if STORE_IDENTIFIER_RE.search(code_segment):
        return True
    
    # Check for store source call names
    for call_name in STORE_SOURCE_CALL_NAMES:
        if call_name in code_segment:
            return True
            
    return False

def is_suspicious_normalize_with_store_call(line):
    """Check for suspicious normalizeAllowFromWithStore calls"""
    if "normalizeAllowFromWithStore" not in line:
        return False
        
    # This is a very simplified check - would need proper parsing for accuracy
    return "storeAllowFrom" in line and GROUP_NAME_RE.search(line)

def find_violations_in_file(file_path):
    """Find violations in a single file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return []
    
    violations = []
    in_object_literal = False
    
    for i, line in enumerate(lines, 1):
        line_stripped = line.strip()
        
        # Skip empty lines and comments
        if not line_stripped or line_stripped.startswith('//'):
            continue
            
        # Check for group-scoped variable declarations with store references
        if GROUP_NAME_RE.search(line_stripped):
            # Look for variable assignments
            if '=' in line_stripped and contains_pairing_store_source(line_stripped):
                # Check if it's an allowed resolver call
                allowed = False
                for resolver_name in ALLOWED_RESOLVER_CALL_NAMES:
                    if resolver_name in line_stripped:
                        allowed = True
                        break
                        
                if not allowed:
                    var_match = re.search(r'(?:let|const|var)\s+(\w+)', line_stripped)
                    if var_match:
                        var_name = var_match.group(1)
                        violations.append({
                            'line': i,
                            'reason': f'group-scoped variable "{var_name}" references pairing-store identifiers',
                            'path': file_path
                        })
        
        # Check for object properties with group names and store references
        if '{' in line_stripped:
            in_object_literal = True
        elif '}' in line_stripped:
            in_object_literal = False
        elif in_object_literal and GROUP_NAME_RE.search(line_stripped) and contains_pairing_store_source(line_stripped):
            prop_match = GROUP_NAME_RE.search(line_stripped)
            if prop_match:
                prop_name = prop_match.group(0)
                violations.append({
                    'line': i,
                    'reason': f'group-scoped property "{prop_name}" references pairing-store identifiers',
                    'path': file_path
                })
        
        # Check for suspicious normalize calls
        if is_suspicious_normalize_with_store_call(line_stripped):
            violations.append({
                'line': i,
                'reason': "group allowlist uses normalizeAllowFromWithStore(...) with pairing-store entries",
                'path': file_path
            })
            
    return violations

def collect_file_violations(source_roots, repo_root, skip_file_func):
    """Collect violations from all files"""
    violations = []
    
    for root in source_roots:
        root_path = Path(root)
        if not root_path.exists():
            continue
            
        for file_path in root_path.rglob("*.ts"):
            # Skip .d.ts files and node_modules
            if ".d.ts" in str(file_path) or "node_modules" in str(file_path):
                continue
                
            relative_path = str(file_path.relative_to(Path(repo_root)))
            if skip_file_func(relative_path):
                continue
                
            file_violations = find_violations_in_file(str(file_path))
            for violation in file_violations:
                violation['path'] = str(file_path)
                violations.append(violation)
                
    return violations

def skip_file(file_path):
    """Check if file should be skipped"""
    normalized_path = file_path.replace('\\', '/')
    for allowed_file in ALLOWED_FILES:
        if allowed_file in normalized_path:
            return True
    return False

def main():
    context = create_pairing_guard_context(__file__)
    repo_root = context['repoRoot']
    source_roots = context['sourceRoots']
    
    violations = collect_file_violations(
        source_roots=source_roots,
        repo_root=repo_root,
        skip_file_func=skip_file
    )
    
    if not violations:
        return 0
    
    print("Found pairing-store identifiers referenced in group auth composition:", file=sys.stderr)
    for violation in violations:
        print(f"- {violation['path']}:{violation['line']} ({violation['reason']})", file=sys.stderr)
    
    print("Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists).", file=sys.stderr)
    return 1

if __name__ == "__main__":
    sys.exit(main())
