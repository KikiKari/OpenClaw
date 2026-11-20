#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7101eb8b9c52deabc739eaa1c4ba509b8b8952cedf908cbf444f285c905af4a2", "source_sha256": "2ca708f3e5a694b78eb83d1e37cf5eefe3e601ebec3e31d771a7ebd4246aa33c", "target_language": "python"}
# ios-beta-prepare.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-prepare.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path


def usage():
    print("""Usage:
  OPENCLAW_PUSH_RELAY_BASE_URL=https://relay.example.com \\
    scripts/ios-beta-prepare.sh --build-number 7 [--team-id TEAMID]

Prepares local beta-release inputs without touching local signing overrides:
- reads apps/ios/version.json and writes apps/ios/build/Version.xcconfig
- writes apps/ios/build/BetaRelease.xcconfig with canonical bundle IDs
- configures the beta build for relay-backed APNs registration
- regenerates apps/ios/OpenClaw.xcodeproj via xcodegen""")


def write_generated_file(output_path, content):
    """Write content to a file, avoiding symlink overwrites"""
    path = Path(output_path)
    if path.is_symlink():
        print(f"Refusing to overwrite symlinked file: {output_path}", file=sys.stderr)
        sys.exit(1)
    
    # Create temporary file in the same directory
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as f:
        temp_path = f.name
        f.write(content)
    
    # Atomically replace the target file
    Path(temp_path).rename(path)


def validate_push_relay_base_url(value):
    """Validate the push relay base URL format"""
    if re.search(r'\s', value):
        print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: whitespace is not allowed.", file=sys.stderr)
        sys.exit(1)
    
    if re.search(r'[$()=]', value):
        print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: contains forbidden xcconfig characters.", file=sys.stderr)
        sys.exit(1)
    
    # Validate URL format
    parsed = urllib.parse.urlparse(value)
    if not (parsed.scheme == 'https' and parsed.netloc):
        print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: expected https://host[:port][/path].", file=sys.stderr)
        sys.exit(1)
    
    # Validate port number if present
    if ':' in parsed.netloc and not parsed.netloc.startswith('['):
        host_part, port_part = parsed.netloc.rsplit(':', 1)
        try:
            port = int(port_part)
            if not (1 <= port <= 65535):
                print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: port must be between 1 and 65535.", file=sys.stderr)
                sys.exit(1)
        except ValueError:
            print("Invalid OPENCLAW_PUSH_RELAY_BASE_URL: invalid port format.", file=sys.stderr)
            sys.exit(1)


def get_team_id(team_helper, allow_keychain_fallback=True):
    """Get Apple Team ID using the team helper script"""
    env = os.environ.copy()
    if allow_keychain_fallback:
        env['IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK'] = '1'
    
    try:
        result = subprocess.run(
            ['bash', str(team_helper)],
            capture_output=True,
            text=True,
            env=env
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def get_ios_version(root_dir, ios_version_helper):
    """Get iOS version using the version helper script"""
    try:
        result = subprocess.run(
            ['node', '--import', 'tsx', str(ios_version_helper), '--field', 'canonicalVersion'],
            cwd=root_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def check_version_sync(root_dir, version_sync_helper):
    """Check version synchronization"""
    try:
        subprocess.run(
            ['node', '--import', 'tsx', str(version_sync_helper), '--check'],
            cwd=root_dir,
            check=True
        )
    except subprocess.CalledProcessError:
        sys.exit(1)


def write_version_xcconfig(version_helper, build_number):
    """Write version xcconfig using the helper script"""
    try:
        subprocess.run(
            ['bash', str(version_helper), '--build-number', str(build_number)],
            check=True
        )
    except subprocess.CalledProcessError:
        sys.exit(1)


def run_xcodegen(ios_dir):
    """Run xcodegen to regenerate project files"""
    try:
        subprocess.run(
            ['xcodegen', 'generate'],
            cwd=ios_dir,
            check=True
        )
    except subprocess.CalledProcessError:
        sys.exit(1)
    except FileNotFoundError:
        print("xcodegen not found. Please install xcodegen.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--build-number', required=True)
    parser.add_argument('--team-id')
    parser.add_argument('-h', '--help', action='store_true')
    
    args, unknown = parser.parse_known_args()
    
    if args.help:
        usage()
        sys.exit(0)
    
    if unknown:
        print(f"Unknown argument: {unknown[0]}", file=sys.stderr)
        usage()
        sys.exit(1)
    
    # Setup paths
    script_path = Path(__file__).resolve()
    root_dir = script_path.parent.parent
    ios_dir = root_dir / 'apps' / 'ios'
    build_dir = ios_dir / 'build'
    beta_xcconfig = build_dir / 'BetaRelease.xcconfig'
    team_helper = root_dir / 'scripts' / 'ios-team-id.sh'
    version_helper = root_dir / 'scripts' / 'ios-write-version-xcconfig.sh'
    ios_version_helper = root_dir / 'scripts' / 'ios-version.ts'
    version_sync_helper = root_dir / 'scripts' / 'ios-sync-versioning.ts'
    
    build_number = args.build_number
    team_id = args.team_id or os.environ.get('IOS_DEVELOPMENT_TEAM', '')
    push_relay_base_url = os.environ.get('OPENCLAW_PUSH_RELAY_BASE_URL') or os.environ.get('IOS_PUSH_RELAY_BASE_URL', '')
    
    # Validate build directory
    if build_dir.is_symlink():
        print(f"Refusing to use symlinked build directory: {build_dir}", file=sys.stderr)
        sys.exit(1)
    
    build_dir.mkdir(parents=True, exist_ok=True)
    
    # Get team ID if not provided
    if not team_id:
        team_id = get_team_id(team_helper)
    
    if not team_id:
        print("Could not resolve Apple Team ID. Set IOS_DEVELOPMENT_TEAM or sign into Xcode.", file=sys.stderr)
        sys.exit(1)
    
    if not push_relay_base_url:
        print("Missing OPENCLAW_PUSH_RELAY_BASE_URL (or IOS_PUSH_RELAY_BASE_URL) for beta relay registration.", file=sys.stderr)
        sys.exit(1)
    
    validate_push_relay_base_url(push_relay_base_url)
    
    # Prepare push relay URL for xcconfig (escape // to avoid comments)
    push_relay_base_url_xcconfig = push_relay_base_url.replace('//', '$(OPENCLAW_URL_SLASH)$(OPENCLAW_URL_SLASH)')
    
    # Check version sync
    check_version_sync(root_dir, version_sync_helper)
    
    # Get iOS version
    ios_version = get_ios_version(root_dir, ios_version_helper)
    if not ios_version:
        print(f"Unable to resolve iOS version from {root_dir}/apps/ios/version.json.", file=sys.stderr)
        sys.exit(1)
    
    # Write version xcconfig
    write_version_xcconfig(version_helper, build_number)
    
    # Generate beta xcconfig content
    beta_config_content = f"""// Auto-generated by scripts/ios-beta-prepare.sh.
// Local beta-release override; do not commit.
OPENCLAW_CODE_SIGN_STYLE = Automatic
OPENCLAW_DEVELOPMENT_TEAM = {team_id}
OPENCLAW_IOS_SELECTED_TEAM = {team_id}
OPENCLAW_APP_BUNDLE_ID = ai.openclaw.client
OPENCLAW_SHARE_BUNDLE_ID = ai.openclaw.client.share
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = ai.openclaw.client.activitywidget
OPENCLAW_WATCH_APP_BUNDLE_ID = ai.openclaw.client.watchkitapp
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = ai.openclaw.client.watchkitapp.extension
OPENCLAW_APP_PROFILE =
OPENCLAW_SHARE_PROFILE =
OPENCLAW_PUSH_TRANSPORT = relay
OPENCLAW_PUSH_DISTRIBUTION = official
OPENCLAW_URL_SLASH = /
OPENCLAW_PUSH_RELAY_BASE_URL = {push_relay_base_url_xcconfig}
OPENCLAW_PUSH_APNS_ENVIRONMENT = production
"""
    
    write_generated_file(beta_xcconfig, beta_config_content)
    
    # Run xcodegen
    run_xcodegen(ios_dir)
    
    print(f"Prepared iOS beta release: version={ios_version} build={build_number} team={team_id}")
    print(f"XCODE_XCCONFIG_FILE={beta_xcconfig}")


if __name__ == '__main__':
    main()
