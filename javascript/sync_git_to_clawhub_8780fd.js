#!/usr/bin/env node
// sync_git_to_clawhub.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/** Sync die 4 Git-Repos zu ClawHub */

const fs = require('fs');
const path = require('path');

// Füge das Verzeichnis zum Modulsuchpfad hinzu
const modulePath = '/home/openclaw/.openclaw/workspace/scripts';
const syncClawhubGit = require(path.join(modulePath, 'sync_clawhub_git.js'));

// Die 4 Git-Repos die zu ClawHub müssen
const gitRepos = [
    "abstractions-utils",
    "sub-agents-utils", 
    "multi-nodes-utils",
    "Abstraktionen"
];

// Check if in git/
const gitPath = "/home/openclaw/.openclaw/workspace/git";
for (const repo of gitRepos) {
    const repoPath = path.join(gitPath, repo);
    if (fs.existsSync(repoPath)) {
        syncClawhubGit.log(`Syncing ${repo} from Git to ClawHub...`);
        // Rename für sync function
        if (repo === "Abstraktionen") {
            continue;  // Skip - ist kein Skill
        }
        syncClawhubGit.syncToClawhub(repo, false);
        syncClawhubGit.log(`✅ ${repo} synced to ClawHub`);
    }
}
