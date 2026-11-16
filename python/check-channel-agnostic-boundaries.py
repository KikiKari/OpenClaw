#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "041cdb698c46085ea81d60791d75ae01e6feccd0da25802cc7cd1822db05eb05", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "python"}
# check-channel-agnostic-boundaries.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import re
import json
from pathlib import Path
from typing import List, Set, Dict, Any, Callable, Optional, Tuple
import asyncio

# Since we don't have TypeScript AST parsing in Python, we'll use regex-based parsing
# This is a simplified approximation of the original functionality

def resolve_repo_root(script_path: str) -> str:
    """Resolve repository root from script path"""
    script_dir = Path(script_path).parent
    current = script_dir
    while current != current.parent:
        if (current / ".git").exists():
            return str(current)
        current = current.parent
    return str(script_dir)

repo_root = resolve_repo_root(__file__)

acp_core_protected_sources = [
    os.path.join(repo_root, "src", "acp"),
    os.path.join(repo_root, "src", "agents", "acp-spawn.ts"),
    os.path.join(repo_root, "src", "auto-reply", "reply", "commands-acp"),
    os.path.join(repo_root, "src", "infra", "outbound", "conversation-id.ts"),
]

channel_core_protected_sources = [
    os.path.join(repo_root, "src", "channels", "thread-bindings-policy.ts"),
    os.path.join(repo_root, "src", "channels", "thread-bindings-messages.ts"),
]

acp_user_facing_text_sources = [
    os.path.join(repo_root, "src", "auto-reply", "reply", "commands-acp"),
]

system_mark_literal_guard_sources = [
    os.path.join(repo_root, "src", "auto-reply", "reply", "commands-acp"),
    os.path.join(repo_root, "src", "auto-reply", "reply", "dispatch-acp.ts"),
    os.path.join(repo_root, "src", "auto-reply", "reply", "directive-handling.shared.ts"),
    os.path.join(repo_root, "src", "channels", "thread-bindings-messages.ts"),
]

channel_ids = [
    "bluebubbles", "discord", "googlechat", "imessage", "irc", "line",
    "matrix", "msteams", "signal", "slack", "telegram", "web",
    "whatsapp", "zalo", "zalouser"
]

channel_id_set = set(channel_ids)
channel_segment_re = re.compile(r'(^|[._/-])(?:' + '|'.join(channel_ids) + r')([._/-]|$)')
comparison_operators = {'===', '!==', '==', '!='}

allowed_violations = set()

def is_channels_property_access(text: str) -> bool:
    """Check if text represents channels property access"""
    return '.channels' in text or '[\"channels\"]' in text or "[\'channels\']" in text

def read_string_literal(text: str) -> Optional[str]:
    """Extract string content from string literal"""
    text = text.strip()
    if (text.startswith('"') and text.endswith('"')) or \
       (text.startswith("'") and text.endswith("'")) or \
       (text.startswith('`') and text.endswith('`')):
        return text[1:-1]
    return None

def is_channel_literal_node(text: str) -> bool:
    """Check if node contains channel literal"""
    string_content = read_string_literal(text)
    return string_content is not None and string_content in channel_id_set

def matches_channel_module_specifier(specifier: str) -> bool:
    """Check if specifier matches channel module pattern"""
    return channel_segment_re.search(specifier.replace('\\', '/')) is not None

user_facing_channel_name_re = re.compile(
    r'\b(?:discord|telegram|slack|signal|imessage|whatsapp|google\s*chat|irc|line|zalo|matrix|msteams|bluebubbles)\b',
    re.IGNORECASE
)

system_mark_literal = "⚙️"

def is_module_specifier_string_node(line: str, content_lines: List[str], line_index: int) -> bool:
    """Check if string node is part of module specifier"""
    # Check for import/export declarations
    if 'import' in line or 'export' in line:
        return True
    # Check for dynamic import
    if 'import(' in line:
        return True
    return False

def find_channel_agnostic_boundary_violations(
    content: str,
    file_name: str = "source.ts",
    options: Dict[str, Any] = None
) -> List[Dict[str, Any]]:
    """Find channel agnostic boundary violations"""
    if options is None:
        options = {}
    
    check_module_specifiers = options.get('checkModuleSpecifiers', True)
    check_config_paths = options.get('checkConfigPaths', True)
    check_channel_comparisons = options.get('checkChannelComparisons', True)
    check_channel_assignments = options.get('checkChannelAssignments', True)
    module_specifier_matcher = options.get('moduleSpecifierMatcher', matches_channel_module_specifier)
    
    lines = content.split('\n')
    violations = []
    
    for i, line in enumerate(lines):
        line_num = i + 1
        
        # Check import declarations
        if check_module_specifiers and ('import' in line and 'from' in line):
            match = re.search(r'from\s+["\']([^"\']+)["\']', line)
            if match:
                specifier = match.group(1)
                if module_specifier_matcher(specifier):
                    violations.append({
                        'line': line_num,
                        'reason': f'imports channel module "{specifier}"'
                    })
        
        # Check export declarations
        if check_module_specifiers and 'export' in line and 'from' in line:
            match = re.search(r'from\s+["\']([^"\']+)["\']', line)
            if match:
                specifier = match.group(1)
                if module_specifier_matcher(specifier):
                    violations.append({
                        'line': line_num,
                        'reason': f're-exports channel module "{specifier}"'
                    })
        
        # Check dynamic imports
        if check_module_specifiers and 'import(' in line:
            match = re.search(r'import\s*\(\s*["\']([^"\']+)["\']\s*\)', line)
            if match:
                specifier = match.group(1)
                if module_specifier_matcher(specifier):
                    violations.append({
                        'line': line_num,
                        'reason': f'dynamically imports channel module "{specifier}"'
                    })
        
        # Check config paths - property access
        if check_config_paths:
            for channel_id in channel_id_set:
                if f'.{channel_id}' in line and is_channels_property_access(line):
                    violations.append({
                        'line': line_num,
                        'reason': f'references config path "channels.{channel_id}"'
                    })
                
                # Check element access
                if f'[\"{channel_id}\"]' in line and '.channels' in line:
                    violations.append({
                        'line': line_num,
                        'reason': f'references config path "channels[\\"{channel_id}\\"]"'
                    })
                if f"[\'{channel_id}\']" in line and '.channels' in line:
                    violations.append({
                        'line': line_num,
                        'reason': f'references config path "channels[\\\'{channel_id}\\\']"'
                    })
        
        # Check channel comparisons
        if check_channel_comparisons:
            for op in comparison_operators:
                if op in line:
                    # Simple check for channel literals in comparisons
                    for channel_id in channel_id_set:
                        if f'"{channel_id}"' in line or f"'{channel_id}'" in line:
                            violations.append({
                                'line': line_num,
                                'reason': f'compares with channel id literal ({line.strip()})'
                            })
                            break
        
        # Check channel assignments
        if check_channel_assignments and ':' in line and 'channel' in line:
            # Look for channel property assignments
            match = re.search(r'channel\s*:.*["\'](.*?)["\']', line)
            if match:
                channel_value = match.group(1)
                if channel_value in channel_id_set:
                    violations.append({
                        'line': line_num,
                        'reason': f'assigns channel id literal to "channel" ({channel_value})'
                    })
    
    return violations

def find_channel_core_reverse_dependency_violations(content: str, file_name: str = "source.ts") -> List[Dict[str, Any]]:
    """Find channel core reverse dependency violations"""
    return find_channel_agnostic_boundary_violations(content, file_name, {
        'checkModuleSpecifiers': True,
        'checkConfigPaths': False,
        'checkChannelComparisons': False,
        'checkChannelAssignments': False,
        'moduleSpecifierMatcher': matches_channel_module_specifier,
    })

def find_acp_user_facing_channel_name_violations(content: str, file_name: str = "source.ts") -> List[Dict[str, Any]]:
    """Find ACP user facing channel name violations"""
    lines = content.split('\n')
    violations = []
    
    for i, line in enumerate(lines):
        line_num = i + 1
        # Look for string literals
        strings = re.findall(r'(["\'])(.*?)(\1)', line)
        for _, string_content, _ in strings:
            if user_facing_channel_name_re.search(string_content) and 'import' not in line and 'export' not in line:
                violations.append({
                    'line': line_num,
                    'reason': f'user-facing text references channel name ("{string_content}")'
                })
    
    return violations

def find_system_mark_literal_violations(content: str, file_name: str = "source.ts") -> List[Dict[str, Any]]:
    """Find system mark literal violations"""
    lines = content.split('\n')
    violations = []
    
    for i, line in enumerate(lines):
        line_num = i + 1
        # Look for string literals containing system mark
        strings = re.findall(r'(["\'])(.*?)(\1)', line)
        for _, string_content, _ in strings:
            if system_mark_literal in string_content and 'import' not in line and 'export' not in line:
                violations.append({
                    'line': line_num,
                    'reason': f'hardcoded system mark literal ("{string_content}")'
                })
    
    return violations

boundary_rule_sets = [
    {
        'id': 'acp-core',
        'sources': acp_core_protected_sources,
        'scan': lambda content, file_name: find_channel_agnostic_boundary_violations(content, file_name),
    },
    {
        'id': 'channel-core-reverse-deps',
        'sources': channel_core_protected_sources,
        'scan': lambda content, file_name: find_channel_core_reverse_dependency_violations(content, file_name),
    },
    {
        'id': 'acp-user-facing-text',
        'sources': acp_user_facing_text_sources,
        'scan': lambda content, file_name: find_acp_user_facing_channel_name_violations(content, file_name),
    },
    {
        'id': 'system-mark-literal-usage',
        'sources': system_mark_literal_guard_sources,
        'scan': lambda content, file_name: find_system_mark_literal_violations(content, file_name),
    },
]

async def collect_type_script_files(source_path: str, ignore_missing: bool = True) -> List[str]:
    """Collect TypeScript files from source path"""
    files = []
    path_obj = Path(source_path)
    
    if path_obj.is_file():
        if path_obj.suffix in ['.ts', '.tsx']:
            files.append(str(path_obj))
    elif path_obj.is_dir():
        for ext in ['.ts', '.tsx']:
            files.extend([str(p) for p in path_obj.rglob(f'*{ext}')])
    elif not ignore_missing:
        raise FileNotFoundError(f"Path not found: {source_path}")
    
    return files

async def main():
    """Main function"""
    violations = []
    
    for rule_set in boundary_rule_sets:
        all_files = []
        for source_path in rule_set['sources']:
            try:
                files = await collect_type_script_files(source_path, ignore_missing=True)
                all_files.extend(files)
            except Exception:
                if not any(ignore_phrase in source_path for ignore_phrase in ['ignoreMissing', 'ignore_missing']):
                    raise
        
        for file_path in all_files:
            relative_file = os.path.relpath(file_path, repo_root)
            if f"{rule_set['id']}:{relative_file}" in allowed_violations or relative_file in allowed_violations:
                continue
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                rule_violations = rule_set['scan'](content, relative_file)
                for violation in rule_violations:
                    violations.append(f"{rule_set['id']} {relative_file}:{violation['line']}: {violation['reason']}")
            except Exception as e:
                print(f"Error processing {file_path}: {e}", file=sys.stderr)
    
    if len(violations) == 0:
        return
    
    print("Found channel-specific references in channel-agnostic sources:", file=sys.stderr)
    for violation in violations:
        print(f"- {violation}", file=sys.stderr)
    print("Move channel-specific logic to channel adapters or add a justified allowlist entry.", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
