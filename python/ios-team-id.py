#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "77b1644bd24807e8bc297b56bf738b57e75bfb1777f946625483c12d0c8578a9", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "python"}
# ios-team-id.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import json
import plistlib
from typing import List, Tuple, Optional

def detect_python() -> Optional[str]:
    candidates = [
        os.environ.get('IOS_PYTHON_BIN', ''),
        'python3',
        'python',
        '/usr/bin/python3'
    ]
    
    for candidate in candidates:
        if not candidate:
            continue
        try:
            subprocess.run([candidate, '--version'], 
                         stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL,
                         check=True)
            return candidate
        except (subprocess.SubprocessError, FileNotFoundError):
            continue
    
    return None

def main():
    # Check if IOS_DEVELOPMENT_TEAM is set
    ios_development_team = os.environ.get('IOS_DEVELOPMENT_TEAM')
    if ios_development_team:
        print(ios_development_team)
        sys.exit(0)
    
    # Get configuration from environment
    preferred_team = os.environ.get('IOS_PREFERRED_TEAM_ID') or \
                    os.environ.get('OPENCLAW_IOS_DEFAULT_TEAM_ID', 'Y5PE65HELJ')
    preferred_team_name = os.environ.get('IOS_PREFERRED_TEAM_NAME', '')
    allow_keychain_fallback = os.environ.get('IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK', '0') == '1'
    prefer_non_free_team = os.environ.get('IOS_PREFER_NON_FREE_TEAM', '1') == '1'
    
    # Clean up potential carriage returns
    preferred_team = preferred_team.replace('\r', '')
    preferred_team_name = preferred_team_name.replace('\r', '')
    
    # Initialize team data storage
    team_ids: List[str] = []
    team_is_free: List[bool] = []
    team_names: List[str] = []
    
    # Detect Python interpreter
    python_cmd = detect_python()
    
    def append_team(candidate_id: str, candidate_is_free: str, candidate_name: str):
        candidate_id = candidate_id.replace('\r', '')
        candidate_is_free = candidate_is_free.replace('\r', '')
        candidate_name = candidate_name.replace('\r', '')
        
        if not candidate_id:
            return
        
        # Avoid duplicates
        if candidate_id in team_ids:
            return
            
        team_ids.append(candidate_id)
        team_is_free.append(candidate_is_free == '1')
        team_names.append(candidate_name)
    
    def load_teams_from_xcode_preferences():
        plist_path = os.path.expanduser('~/Library/Preferences/com.apple.dt.Xcode.plist')
        if not os.path.exists(plist_path) or not python_cmd:
            return
        
        try:
            result = subprocess.run([
                'plutil', '-extract', 'IDEProvisioningTeams', 'json', '-o', '-', plist_path
            ], capture_output=True, text=True, check=True)
            
            data = json.loads(result.stdout)
            if not isinstance(data, dict):
                return
                
            for teams in data.values():
                if not isinstance(teams, list):
                    continue
                for team in teams:
                    if not isinstance(team, dict):
                        continue
                    team_id = str(team.get('teamID', '')).strip()
                    if not team_id:
                        continue
                    is_free = '1' if bool(team.get('isFreeProvisioningTeam', False)) else '0'
                    team_name = str(team.get('teamName', '')).replace('\t', ' ').strip()
                    append_team(team_id, is_free, team_name)
                    
        except (subprocess.SubprocessError, json.JSONDecodeError, FileNotFoundError):
            pass
    
    def load_teams_from_legacy_defaults_key():
        try:
            result = subprocess.run([
                'defaults', 'read', 'com.apple.dt.Xcode', 'IDEProvisioningTeamIdentifiers'
            ], capture_output=True, text=True, check=True)
            
            import re
            matches = re.findall(r'[A-Z0-9]{10}', result.stdout)
            for match in matches:
                append_team(match, '0', '')
                
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
    
    def load_teams_from_xcode_managed_profiles():
        profiles_dir = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
        if not os.path.exists(profiles_dir) or not python_cmd:
            return
        
        try:
            profile_files = [f for f in os.listdir(profiles_dir) if f.endswith('.mobileprovision')]
            team_set = set()
            
            for profile_file in profile_files:
                profile_path = os.path.join(profiles_dir, profile_file)
                if not os.path.isfile(profile_path):
                    continue
                    
                try:
                    # Extract the plist from the mobileprovision file
                    result = subprocess.run([
                        'security', 'cms', '-D', '-i', profile_path
                    ], capture_output=True, check=True)
                    
                    plist_data = plistlib.loads(result.stdout)
                    team_identifiers = plist_data.get('TeamIdentifier', [])
                    for tid in team_identifiers:
                        team_set.add(str(tid))
                        
                except (subprocess.SubprocessError, Exception):
                    continue
            
            # Add all unique team IDs
            for team_id in sorted(team_set):
                append_team(team_id, '0', '')
                
        except Exception:
            pass
    
    def has_xcode_account() -> bool:
        plist_path = os.path.expanduser('~/Library/Preferences/com.apple.dt.Xcode.plist')
        if not os.path.exists(plist_path):
            return False
            
        try:
            result = subprocess.run([
                'defaults', 'read', 'com.apple.dt.Xcode', 'DVTDeveloperAccountManagerAppleIDLists'
            ], capture_output=True, text=True)
            
            if result.returncode == 0 and 'does not exist' not in result.stdout:
                return 'identifier' in result.stdout
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
            
        return False
    
    # Load teams from various sources
    load_teams_from_xcode_preferences()
    load_teams_from_legacy_defaults_key()
    
    if len(team_ids) == 0:
        load_teams_from_xcode_managed_profiles()
    
    if len(team_ids) == 0 and allow_keychain_fallback:
        try:
            result = subprocess.run([
                'security', 'find-identity', '-p', 'codesigning', '-v'
            ], capture_output=True, text=True, check=True)
            
            import re
            matches = re.findall(r'\(([A-Z0-9]{10})\)', result.stdout)
            for match in matches:
                append_team(match, '0', '')
                
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
    
    # Handle case when no teams found
    if len(team_ids) == 0:
        if has_xcode_account():
            print("An Apple account is signed in to Xcode, but no Team ID could be resolved.", file=sys.stderr)
            print("", file=sys.stderr)
            print("On Xcode 16+, team data is not written until you build a project.", file=sys.stderr)
            print("To fix this, do ONE of the following:", file=sys.stderr)
            print("", file=sys.stderr)
            print("  1. Open the iOS project in Xcode, select your Team in Signing &", file=sys.stderr)
            print("     Capabilities, and build once. Then re-run this script.", file=sys.stderr)
            print("", file=sys.stderr)
            print("  2. Set your Team ID directly:", file=sys.stderr)
            print("       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>", file=sys.stderr)
            print("     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard", file=sys.stderr)
        elif allow_keychain_fallback:
            print("No Apple Team ID found. Open Xcode or install signing certificates first.", file=sys.stderr)
        else:
            print("No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry.", file=sys.stderr)
            print("(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)", file=sys.stderr)
        sys.exit(1)
    
    # Look for exact team ID match
    for i, team_id in enumerate(team_ids):
        if team_id == preferred_team:
            print(team_id)
            sys.exit(0)
    
    # Look for team name match (case insensitive)
    if preferred_team_name:
        preferred_team_name_lc = preferred_team_name.lower()
        for i, team_name in enumerate(team_names):
            if team_name.lower() == preferred_team_name_lc:
                print(team_ids[i])
                sys.exit(0)
    
    # Prefer non-free team if requested
    if prefer_non_free_team:
        for i, is_free in enumerate(team_is_free):
            if not is_free:
                print(team_ids[i])
                sys.exit(0)
    
    # Return first team as fallback
    print(team_ids[0])

if __name__ == '__main__':
    main()
