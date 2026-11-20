#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "fe4fe4e5243afff867f76fe49c019d89c175a932247587b685acbeb03bf731a7", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "powershell"}
# ios-team-id.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

if ($env:IOS_DEVELOPMENT_TEAM) {
    Write-Output $env:IOS_DEVELOPMENT_TEAM
    exit 0
}

$preferred_team = $env:IOS_PREFERRED_TEAM_ID ?? $env:OPENCLAW_IOS_DEFAULT_TEAM_ID ?? "Y5PE65HELJ"
$preferred_team_name = $env:IOS_PREFERRED_TEAM_NAME ?? ""
$allow_keychain_fallback = $env:IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK ?? "0"
$prefer_non_free_team = $env:IOS_PREFER_NON_FREE_TEAM ?? "1"
$preferred_team = $preferred_team -replace "`r", ""
$preferred_team_name = $preferred_team_name -replace "`r", ""

$team_ids = @()
$team_is_free = @()
$team_names = @()

function Detect-Python {
    foreach ($candidate in @($env:IOS_PYTHON_BIN, "python3", "python", "/usr/bin/python3")) {
        if (-not $candidate) { continue }
        try {
            $result = Get-Command $candidate -ErrorAction Stop
            if ($result) {
                return $candidate
            }
        } catch {
            continue
        }
    }
    return $null
}

$python_cmd = Detect-Python

function Append-Team {
    param(
        [string]$candidate_id,
        [string]$candidate_is_free,
        [string]$candidate_name
    )
    
    $candidate_id = $candidate_id -replace "`r", ""
    $candidate_is_free = $candidate_is_free -replace "`r", ""
    $candidate_name = $candidate_name -replace "`r", ""
    
    if (-not $candidate_id) { return }
    
    foreach ($existing_id in $team_ids) {
        if ($existing_id -eq $candidate_id) {
            return
        }
    }
    
    $script:team_ids += $candidate_id
    $script:team_is_free += $candidate_is_free
    $script:team_names += $candidate_name
}

function Load-TeamsFromXcodePreferences {
    $plist_path = "$env:HOME/Library/Preferences/com.apple.dt.Xcode.plist"
    if (-not (Test-Path $plist_path)) { return }
    if (-not $python_cmd) { return }
    
    try {
        $json_data = & plutil -extract IDEProvisioningTeams json -o - $plist_path 2>$null
        if (-not $json_data) { return }
        
        $python_script = @'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

if not isinstance(data, dict):
    raise SystemExit(0)

for teams in data.values():
    if not isinstance(teams, list):
        continue
    for team in teams:
        if not isinstance(team, dict):
            continue
        team_id = str(team.get("teamID", "")).strip()
        if not team_id:
            continue
        is_free = "1" if bool(team.get("isFreeProvisioningTeam", False)) else "0"
        team_name = str(team.get("teamName", "")).replace("\t", " ").strip()
        print(f"{team_id}\t{is_free}\t{team_name}")
'@
        
        $teams_output = $json_data | & $python_cmd -c $python_script 2>$null
        if ($teams_output) {
            $teams_output | ForEach-Object {
                $parts = $_ -split "`t"
                if ($parts.Count -ge 1 -and $parts[0]) {
                    Append-Team $parts[0] ($parts[1] ?? "0") ($parts[2] ?? "")
                }
            }
        }
    } catch {
        # Ignore errors
    }
}

function Load-TeamsFromLegacyDefaultsKey {
    try {
        $output = & defaults read com.apple.dt.Xcode IDEProvisioningTeamIdentifiers 2>$null
        if ($output -match '[A-Z0-9]{10}') {
            $matches = $output | Select-String -Pattern '[A-Z0-9]{10}' -AllMatches
            foreach ($match in $matches.Matches) {
                Append-Team $match.Value "0" ""
            }
        }
    } catch {
        # Ignore errors
    }
}

function Load-TeamsFromXcodeManagedProfiles {
    $profiles_dir = "$env:HOME/Library/MobileDevice/Provisioning Profiles"
    if (-not (Test-Path $profiles_dir)) { return }
    if (-not $python_cmd) { return }
    
    try {
        $teams = @()
        Get-ChildItem "$profiles_dir/*.mobileprovision" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile_file = $_.FullName
            if (Test-Path $profile_file) {
                try {
                    $decoded = & security cms -D -i $profile_file 2>$null
                    if ($decoded) {
                        $python_extract_script = @'
import plistlib, sys
try:
    raw = sys.stdin.buffer.read()
    if not raw:
        raise SystemExit(0)
    d = plistlib.loads(raw)
    for tid in d.get("TeamIdentifier", []):
        print(tid)
except Exception:
    pass
'@
                        $team_id = $decoded | & $python_cmd -c $python_extract_script 2>$null
                        if ($team_id) {
                            $teams += $team_id
                        }
                    }
                } catch {
                    # Ignore errors
                }
            }
        }
        
        $unique_teams = $teams | Sort-Object -Unique
        foreach ($team in $unique_teams) {
            Append-Team $team "0" ""
        }
    } catch {
        # Ignore errors
    }
}

function Has-XcodeAccount {
    $plist_path = "$env:HOME/Library/Preferences/com.apple.dt.Xcode.plist"
    if (-not (Test-Path $plist_path)) { return $false }
    
    try {
        $accts = & defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>$null
        if ($accts -and $accts -notlike "*does not exist*" -and $accts -like "*identifier*") {
            return $true
        }
    } catch {
        # Ignore errors
    }
    
    return $false
}

Load-TeamsFromXcodePreferences
Load-TeamsFromLegacyDefaultsKey

if ($team_ids.Count -eq 0) {
    Load-TeamsFromXcodeManagedProfiles
}

if ($team_ids.Count -eq 0 -and $allow_keychain_fallback -eq "1") {
    try {
        $identities = & security find-identity -p codesigning -v 2>$null
        if ($identities) {
            $matches = $identities | Select-String -Pattern '\([A-Z0-9]{10}\)' -AllMatches
            foreach ($match in $matches.Matches) {
                $team_id = $match.Value -replace '[()]', ''
                Append-Team $team_id "0" ""
            }
        }
    } catch {
        # Ignore errors
    }
}

if ($team_ids.Count -eq 0) {
    if (Has-XcodeAccount) {
        Write-Error "An Apple account is signed in to Xcode, but no Team ID could be resolved."
        Write-Error ""
        Write-Error "On Xcode 16+, team data is not written until you build a project."
        Write-Error "To fix this, do ONE of the following:"
        Write-Error ""
        Write-Error "  1. Open the iOS project in Xcode, select your Team in Signing &"
        Write-Error "     Capabilities, and build once. Then re-run this script."
        Write-Error ""
        Write-Error "  2. Set your Team ID directly:"
        Write-Error "       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>"
        Write-Error "     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard"
    } elseif ($allow_keychain_fallback -eq "1") {
        Write-Error "No Apple Team ID found. Open Xcode or install signing certificates first."
    } else {
        Write-Error "No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry."
        Write-Error "(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)"
    }
    exit 1
}

for ($i = 0; $i -lt $team_ids.Count; $i++) {
    if ($team_ids[$i] -eq $preferred_team) {
        Write-Output $team_ids[$i]
        exit 0
    }
}

if ($preferred_team_name) {
    $preferred_team_name_lc = $preferred_team_name.ToLower()
    for ($i = 0; $i -lt $team_ids.Count; $i++) {
        $team_name_lc = $team_names[$i].ToLower()
        if ($team_name_lc -eq $preferred_team_name_lc) {
            Write-Output $team_ids[$i]
            exit 0
        }
    }
}

if ($prefer_non_free_team -eq "1") {
    for ($i = 0; $i -lt $team_ids.Count; $i++) {
        if ($team_is_free[$i] -eq "0") {
            Write-Output $team_ids[$i]
            exit 0
        }
    }
}

Write-Output $team_ids[0]
