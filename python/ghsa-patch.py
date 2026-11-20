#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "252ea34f12186cb62d45ed25f2e456ea119cb2c7b492c36132179ebe2b0513ec", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "python"}
# ghsa-patch.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

def usage():
    print(
        "\n".join([
            "Usage:",
            "  node scripts/ghsa-patch.mjs --ghsa <GHSA-id-or-url> [--repo owner/name]",
            "    --summary <text> --severity <low|medium|high|critical>",
            "    --description-file <path>",
            "    --vulnerable-version-range <range>",
            "    --patched-versions <range-or-null>",
            "    [--package openclaw] [--ecosystem npm] [--cvss <vector>]",
        ]),
        file=sys.stderr,
    )

def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)

def parse_args(argv):
    out = {}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if not arg.startswith("--"):
            fail(f"Unexpected argument: {arg}")
        key = arg[2:]
        if i + 1 >= len(argv) or argv[i + 1].startswith("--"):
            fail(f"Missing value for --{key}")
        value = argv[i + 1]
        out[key] = value
        i += 2
    return out

def run_gh(args):
    try:
        result = subprocess.run(
            ["gh"] + args,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        error_msg = e.stderr.strip() or e.stdout.strip() or f"gh {' '.join(args)} failed"
        fail(error_msg)

def derive_repo_from_origin():
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            check=True
        )
        remote = result.stdout.strip()
        https_match = re.search(r"github\.com[/:]([^/]+)/([^/.]+)(?:\.git)?$", remote)
        if not https_match:
            fail(f"Could not parse origin remote: {remote}")
        return f"{https_match.group(1)}/{https_match.group(2)}"
    except subprocess.CalledProcessError:
        fail("Failed to get git remote URL")

def parse_ghsa_id(value):
    match = re.search(r"GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}", value, re.IGNORECASE)
    if not match:
        fail(f"Could not parse GHSA id from: {value}")
    return match.group(0)

def write_temp_json(data):
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
        return f.name

def main():
    args = parse_args(sys.argv[1:])
    
    if not all(key in args for key in ['ghsa', 'summary', 'severity', 'description-file']):
        usage()
        sys.exit(1)

    repo = args.get('repo') or derive_repo_from_origin()
    ghsa_id = parse_ghsa_id(args['ghsa'])
    advisory_path = f"/repos/{repo}/security-advisories/{ghsa_id}"
    description_path = Path(args['description-file']).resolve()

    if not description_path.exists():
        fail(f"Description file does not exist: {description_path}")

    current = json.loads(run_gh(["api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisory_path]))
    restored_cvss = args.get('cvss') or (current.get('cvss', {}).get('vector_string') if current else None)

    ecosystem = args.get('ecosystem', 'npm')
    package_name = args.get('package', 'openclaw')
    vulnerable_range = args.get('vulnerable-version-range')
    patched_versions_raw = args.get('patched-versions')

    if not vulnerable_range:
        fail("Missing --vulnerable-version-range")
    if patched_versions_raw is None:
        fail("Missing --patched-versions")

    patched_versions = None if patched_versions_raw == "null" else patched_versions_raw
    
    try:
        with open(description_path, 'r', encoding='utf-8') as f:
            description = f.read()
    except IOError as e:
        fail(f"Could not read description file: {e}")

    payload = {
        "summary": args['summary'],
        "severity": args['severity'],
        "description": description,
        "vulnerabilities": [
            {
                "package": {
                    "ecosystem": ecosystem,
                    "name": package_name,
                },
                "vulnerable_version_range": vulnerable_range,
                "patched_versions": patched_versions,
                "vulnerable_functions": [],
            },
        ],
    }

    patch_file = write_temp_json(payload)
    
    try:
        run_gh([
            "api",
            "-H",
            "X-GitHub-Api-Version: 2022-11-28",
            "-X",
            "PATCH",
            advisory_path,
            "--input",
            patch_file,
        ])
        
        if restored_cvss:
            run_gh([
                "api",
                "-H",
                "X-GitHub-Api-Version: 2022-11-28",
                "-X",
                "PATCH",
                advisory_path,
                "-f",
                f"cvss_vector_string={restored_cvss}",
            ])
            
        refreshed = json.loads(run_gh(["api", "-H", "X-GitHub-Api-Version: 2022-11-28", advisory_path]))
        
        output = {
            "html_url": refreshed.get("html_url"),
            "state": refreshed.get("state"),
            "severity": refreshed.get("severity"),
            "summary": refreshed.get("summary"),
            "vulnerabilities": refreshed.get("vulnerabilities"),
            "cvss": refreshed.get("cvss"),
            "updated_at": refreshed.get("updated_at"),
        }
        
        print(json.dumps(output, indent=2))
        
    finally:
        # Clean up temp file
        try:
            os.unlink(patch_file)
        except OSError:
            pass

if __name__ == "__main__":
    main()
