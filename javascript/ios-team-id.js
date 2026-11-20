#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "e7918aab71b3146b5c295e56d3571cae92322548f737f3a2db1b46ef2e1c974d", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "javascript"}
// ios-team-id.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync, execSync } = require('child_process');

// Environment variables with defaults
const IOS_DEVELOPMENT_TEAM = process.env.IOS_DEVELOPMENT_TEAM || '';
const IOS_PREFERRED_TEAM_ID = process.env.IOS_PREFERRED_TEAM_ID || '';
const OPENCLAW_IOS_DEFAULT_TEAM_ID = process.env.OPENCLAW_IOS_DEFAULT_TEAM_ID || 'Y5PE65HELJ';
const IOS_PREFERRED_TEAM_NAME = process.env.IOS_PREFERRED_TEAM_NAME || '';
const IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK = process.env.IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK || '0';
const IOS_PREFER_NON_FREE_TEAM = process.env.IOS_PREFER_NON_FREE_TEAM || '1';

if (IOS_DEVELOPMENT_TEAM) {
  console.log(IOS_DEVELOPMENT_TEAM);
  process.exit(0);
}

let preferred_team = IOS_PREFERRED_TEAM_ID || OPENCLAW_IOS_DEFAULT_TEAM_ID;
let preferred_team_name = IOS_PREFERRED_TEAM_NAME;

// Remove carriage returns
preferred_team = preferred_team.replace(/\r/g, '');
preferred_team_name = preferred_team_name.replace(/\r/g, '');

let team_ids = [];
let team_is_free = [];
let team_names = [];

function detectPython() {
  const candidates = [
    process.env.IOS_PYTHON_BIN,
    'python3',
    'python',
    '/usr/bin/python3'
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      const result = spawnSync('command', ['-v', candidate], { stdio: 'pipe' });
      if (result.status === 0) {
        return candidate;
      }
    } catch (e) {
      // Continue to next candidate
    }
  }
  return null;
}

const python_cmd = detectPython();

function appendTeam(candidate_id, candidate_is_free, candidate_name) {
  // Remove carriage returns
  candidate_id = candidate_id.replace(/\r/g, '');
  candidate_is_free = candidate_is_free.replace(/\r/g, '');
  candidate_name = candidate_name.replace(/\r/g, '');

  if (!candidate_id) return;

  // Check if team already exists
  if (team_ids.includes(candidate_id)) {
    return;
  }

  team_ids.push(candidate_id);
  team_is_free.push(candidate_is_free);
  team_names.push(candidate_name);
}

function loadTeamsFromXcodePreferences() {
  if (!python_cmd) return;
  
  const plistPath = path.join(process.env.HOME, 'Library', 'Preferences', 'com.apple.dt.Xcode.plist');
  if (!fs.existsSync(plistPath)) return;

  try {
    const plutilResult = spawnSync('plutil', ['-extract', 'IDEProvisioningTeams', 'json', '-o', '-', plistPath], {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });

    if (plutilResult.status !== 0) return;

    const pythonScript = `
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
        team_name = str(team.get("teamName", "")).replace("\\t", " ").strip()
        print(f"{team_id}\\t{is_free}\\t{team_name}")
`;

    const pythonResult = spawnSync(python_cmd, ['-c', pythonScript], {
      input: plutilResult.stdout,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });

    if (pythonResult.status === 0 && pythonResult.stdout) {
      const lines = pythonResult.stdout.trim().split('\n');
      for (const line of lines) {
        if (line) {
          const [team_id, is_free, team_name] = line.split('\t');
          if (team_id) {
            appendTeam(team_id, is_free || '0', team_name || '');
          }
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }
}

function loadTeamsFromLegacyDefaultsKey() {
  try {
    const result = spawnSync('defaults', ['read', 'com.apple.dt.Xcode', 'IDEProvisioningTeamIdentifiers'], {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });

    if (result.status === 0 && result.stdout) {
      const matches = result.stdout.match(/[A-Z0-9]{10}/g);
      if (matches) {
        for (const team of matches) {
          appendTeam(team, '0', '');
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }
}

function loadTeamsFromXcodeManagedProfiles() {
  if (!python_cmd) return;
  
  const profilesDir = path.join(process.env.HOME, 'Library', 'MobileDevice', 'Provisioning Profiles');
  if (!fs.existsSync(profilesDir)) return;

  try {
    const profileFiles = fs.readdirSync(profilesDir).filter(f => f.endsWith('.mobileprovision'));
    const teams = new Set();

    for (const profile of profileFiles) {
      const profilePath = path.join(profilesDir, profile);
      try {
        const securityResult = spawnSync('security', ['cms', '-D', '-i', profilePath], {
          stdio: ['pipe', 'pipe', 'ignore']
        });

        if (securityResult.status === 0) {
          const pythonScript = `
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
`;

          const pythonResult = spawnSync(python_cmd, ['-c', pythonScript], {
            input: securityResult.stdout,
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'ignore']
          });

          if (pythonResult.status === 0 && pythonResult.stdout) {
            const lines = pythonResult.stdout.trim().split('\n');
            for (const team of lines) {
              if (team) {
                teams.add(team);
              }
            }
          }
        }
      } catch (e) {
        // Continue to next profile
      }
    }

    for (const team of teams) {
      appendTeam(team, '0', '');
    }
  } catch (e) {
    // Ignore errors
  }
}

function hasXcodeAccount() {
  const plistPath = path.join(process.env.HOME, 'Library', 'Preferences', 'com.apple.dt.Xcode.plist');
  if (!fs.existsSync(plistPath)) return false;

  try {
    const result = spawnSync('defaults', ['read', 'com.apple.dt.Xcode', 'DVTDeveloperAccountManagerAppleIDLists'], {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });

    if (result.status === 0 && result.stdout) {
      const output = result.stdout;
      return output.includes('identifier') && !output.includes('does not exist');
    }
  } catch (e) {
    return false;
  }
  return false;
}

// Load teams
loadTeamsFromXcodePreferences();
loadTeamsFromLegacyDefaultsKey();

if (team_ids.length === 0) {
  loadTeamsFromXcodeManagedProfiles();
}

if (team_ids.length === 0 && IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK === '1') {
  try {
    const result = spawnSync('security', ['find-identity', '-p', 'codesigning', '-v'], {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });

    if (result.status === 0 && result.stdout) {
      const matches = result.stdout.match(/\([A-Z0-9]{10}\)/g);
      if (matches) {
        for (const match of matches) {
          const team = match.replace(/[()]/g, '');
          appendTeam(team, '0', '');
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }
}

if (team_ids.length === 0) {
  if (hasXcodeAccount()) {
    console.error("An Apple account is signed in to Xcode, but no Team ID could be resolved.");
    console.error("");
    console.error("On Xcode 16+, team data is not written until you build a project.");
    console.error("To fix this, do ONE of the following:");
    console.error("");
    console.error("  1. Open the iOS project in Xcode, select your Team in Signing &");
    console.error("     Capabilities, and build once. Then re-run this script.");
    console.error("");
    console.error("  2. Set your Team ID directly:");
    console.error("       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>");
    console.error("     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard");
  } else if (IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK === '1') {
    console.error("No Apple Team ID found. Open Xcode or install signing certificates first.");
  } else {
    console.error("No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry.");
    console.error("(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)");
  }
  process.exit(1);
}

// Try to find preferred team by ID
for (let i = 0; i < team_ids.length; i++) {
  if (team_ids[i] === preferred_team) {
    console.log(team_ids[i]);
    process.exit(0);
  }
}

// Try to find preferred team by name
if (preferred_team_name) {
  const preferred_team_name_lc = preferred_team_name.toLowerCase();
  for (let i = 0; i < team_names.length; i++) {
    const team_name_lc = team_names[i].toLowerCase();
    if (team_name_lc === preferred_team_name_lc) {
      console.log(team_ids[i]);
      process.exit(0);
    }
  }
}

// Prefer non-free team if enabled
if (IOS_PREFER_NON_FREE_TEAM === '1') {
  for (let i = 0; i < team_is_free.length; i++) {
    if (team_is_free[i] === '0') {
      console.log(team_ids[i]);
      process.exit(0);
    }
  }
}

// Return first team
console.log(team_ids[0]);
