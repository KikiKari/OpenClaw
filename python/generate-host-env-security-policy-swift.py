#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "5b61099394b36dfd350f78c9d31f8f4b144f2c0b29c47769fe116d7a6772e2a6", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "python"}
# generate-host-env-security-policy-swift.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import sys
from pathlib import Path

def load_host_env_security_policy(raw_policy):
    # This function mimics the JavaScript version's behavior
    # In the original JS, this likely just returns the object as-is
    # We'll do the same here - validate structure if needed
    required_fields = ['blockedInheritedKeys', 'blockedInheritedPrefixes', 
                       'blockedKeys', 'blockedPrefixes']
    
    for field in required_fields:
        if field not in raw_policy:
            raise ValueError(f"Missing required field: {field}")
            
    return raw_policy

def main():
    args = set(sys.argv[1:])
    check_only = "--check" in args
    write_mode = "--write" in args or not check_only

    if check_only and "--write" in args:
        print("Use either --check or --write, not both.", file=sys.stderr)
        sys.exit(1)

    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    policy_path = repo_root / "src" / "infra" / "host-env-security-policy.json"
    output_path = repo_root / "apps" / "macos" / "Sources" / "OpenClaw" / "HostEnvSecurityPolicy.generated.swift"

    with open(policy_path, 'r', encoding='utf-8') as f:
        raw_policy = json.load(f)
        
    policy = load_host_env_security_policy(raw_policy)

    def render_swift_string_array(items):
        return ",\n".join([f'        "{item}"' for item in items])

    generated = f"""// Generated file. Do not edit directly.
// Source: src/infra/host-env-security-policy.json
// Regenerate: node scripts/generate-host-env-security-policy-swift.mjs --write

import Foundation

enum HostEnvSecurityPolicy {{
    static let blockedInheritedKeys: Set<String> = [
{render_swift_string_array(policy['blockedInheritedKeys'])}
    ]

    static let blockedInheritedPrefixes: [String] = [
{render_swift_string_array(policy['blockedInheritedPrefixes'])}
    ]

    static let blockedKeys: Set<String> = [
{render_swift_string_array(policy['blockedKeys'])}
    ]

    static let blockedOverrideKeys: Set<String> = [
{render_swift_string_array(policy.get('blockedOverrideKeys', []))}
    ]

    static let blockedOverridePrefixes: [String] = [
{render_swift_string_array(policy.get('blockedOverridePrefixes', []))}
    ]

    static let blockedPrefixes: [String] = [
{render_swift_string_array(policy['blockedPrefixes'])}
    ]
}}
"""

    current = None
    if output_path.exists():
        with open(output_path, 'r', encoding='utf-8') as f:
            current = f.read()

    if check_only:
        if current == generated:
            print(f"OK {output_path.relative_to(repo_root)}")
            sys.exit(0)
        print(
            f"""Out of date {output_path.relative_to(repo_root)}.
Run: node scripts/generate-host-env-security-policy-swift.mjs --write""",
            file=sys.stderr
        )
        sys.exit(1)

    if write_mode:
        if current != generated:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(generated)
        print(f"Wrote {output_path.relative_to(repo_root)}")

if __name__ == "__main__":
    main()
