#!/usr/bin/env node
// sync_git_to_clawhub.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Sync die aktiven Skill-Repositories zu ClawHub.
 */

const fs = require('fs');
const path = require('path');

// Füge das Verzeichnis zum Modulsuchpfad hinzu
const modulePath = '/home/openclaw/.openclaw/workspace/scripts';
const syncClawhubGit = require(path.join(modulePath, 'sync_clawhub_git.js'));

// Nur aktive Skill-Repositories synchronisieren.
const gitRepos = [
  "sub-agents-utils",
  "multi-nodes-utils",
];

// Check if in git/
const gitPath = "/home/openclaw/.openclaw/workspace/git";
for (const repo of gitRepos) {
  if (fs.existsSync(`${gitPath}/${repo}`)) {
    syncClawhubGit.log(`Syncing ${repo} from Git to ClawHub...`);
    syncClawhubGit.syncToClawHub(repo, false);
    syncClawhubGit.log(`✅ ${repo} synced to ClawHub`);
  }
}
