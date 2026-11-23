#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "676c9d09291d0198ba0db18c2fc9f3b46a2410ed5d7126c06b00a0fd967df866", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "javascript"}
// sync_agent_run.py — portiert nach javascript
// Quelle: python, workspace@local:scripts/sync_agent_run.py
// auch in: workspace@local:scripts/sync_agent.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Permanenter ClawHub ↔ Git Sync Agent
 * Multi-Node fähig, stündliche Ausführung
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const crypto = require('crypto');

// Import sync functions
const {
  syncToGit,
  syncToClawhub,
  log,
  validateSkill,
  getFileHash
} = require('/workspace/scripts/sync_clawhub_git.js');

const CLAWHUB_DIR = path.resolve("/workspace/skills");
const GIT_DIR = path.resolve("/workspace/git/skills");
const STATE_FILE = path.resolve("/workspace/db/sync_state.json");

// Root directory for backups
const BACKUP_ROOT = path.resolve("/workspace/backups/sync_agent");

function loadState() {
  /** Lädt den Sync-State */
  if (fs.existsSync(STATE_FILE)) {
    const data = fs.readFileSync(STATE_FILE, 'utf8');
    return JSON.parse(data);
  }
  return { sync_history: [], pending: [] };
}

function saveState(state) {
  /** Speichert den Sync-State */
  const dir = path.dirname(STATE_FILE);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function getAllSkills() {
  /** Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen. */
  const clawhubSkills = new Set();
  const gitSkills = new Set();

  if (fs.existsSync(CLAWHUB_DIR)) {
    const clawhubDirs = fs.readdirSync(CLAWHUB_DIR);
    for (const dir of clawhubDirs) {
      const fullPath = path.join(CLAWHUB_DIR, dir);
      const stat = fs.statSync(fullPath);
      if (
        stat.isDirectory() &&
        !dir.startsWith('.') &&
        !dir.startsWith('_') &&
        fs.existsSync(path.join(fullPath, "SKILL.md"))
      ) {
        clawhubSkills.add(dir);
      }
    }
  }

  if (fs.existsSync(GIT_DIR)) {
    const gitDirs = fs.readdirSync(GIT_DIR);
    for (const dir of gitDirs) {
      const fullPath = path.join(GIT_DIR, dir);
      const stat = fs.statSync(fullPath);
      if (
        stat.isDirectory() &&
        !dir.startsWith('.') &&
        !dir.startsWith('_') &&
        fs.existsSync(path.join(fullPath, "SKILL.md"))
      ) {
        gitSkills.add(dir);
      }
    }
  }

  const allSkills = new Set([...clawhubSkills, ...gitSkills]);
  return allSkills;
}

function initGitRepo(skillPath, skillName) {
  /** Initialisiert Git-Repo wenn nötig */
  const gitDir = path.join(skillPath, ".git");
  if (!fs.existsSync(gitDir)) {
    process.chdir(skillPath);
    spawnSync("git", ["init"], { stdio: 'ignore' });
    spawnSync("git", ["add", "."], { stdio: 'ignore' });
    spawnSync("git", ["commit", "-m", `Initial commit: ${skillName} skill`], { stdio: 'ignore' });
    log(`Git initialized for ${skillName}`);
  }
}

function backupSkillDir(skillPath, skillName) {
  /** Creates a timestamped tar.gz backup of a skill directory. */
  if (!fs.existsSync(skillPath)) {
    return;
  }
  const timestamp = new Date().toISOString().replace(/[:.]/g, '').replace('T', '').slice(0, 14);
  const backupDir = path.join(BACKUP_ROOT, timestamp);
  fs.mkdirSync(backupDir, { recursive: true });
  const archiveName = `${skillName}_${timestamp}.tar.gz`;
  const archivePath = path.join(backupDir, archiveName);

  // Create tar.gz using external command
  const tarResult = spawnSync(
    "tar",
    ["czf", archivePath, "-C", path.dirname(skillPath), path.basename(skillPath)],
    { stdio: 'ignore' }
  );

  if (tarResult.error) {
    console.error(`Failed to create backup for ${skillName}:`, tarResult.error.message);
  } else {
    log(`Backup created for ${skillName} at ${archivePath}`);
  }
}

function syncSkillBidirectional(skillName, dryRun = false) {
  /** Bidirektionale Synchronisation eines Skills */
  const clawhubPath = path.join(CLAWHUB_DIR, skillName);
  const gitPath = path.join(GIT_DIR, skillName);

  // Fall 1: Nur in ClawHub → zu Git
  if (fs.existsSync(clawhubPath) && !fs.existsSync(gitPath)) {
    log(`NEW in ClawHub: ${skillName} → syncing to Git`);
    if (!dryRun) {
      backupSkillDir(clawhubPath, `${skillName}_clawhub`);
    }
    if (syncToGit(skillName, dryRun)) {
      if (!dryRun) {
        initGitRepo(gitPath, skillName);
      }
      return "synced_to_git";
    }
  }

  // Fall 2: Nur in Git → zu ClawHub
  else if (fs.existsSync(gitPath) && !fs.existsSync(clawhubPath)) {
    log(`NEW in Git: ${skillName} → syncing to ClawHub`);
    if (!dryRun) {
      backupSkillDir(gitPath, `${skillName}_git`);
    }
    if (syncToClawhub(skillName, dryRun)) {
      return "synced_to_clawhub";
    }
  }

  // Fall 3: In beiden vorhanden → Vergleiche Timestamps
  else if (fs.existsSync(clawhubPath) && fs.existsSync(gitPath)) {
    // --- MODIFIZIERTE LOGIK: Robusterer Datei-Hash-Vergleich ---

    // Stelle sicher, dass beide als gültige Skills validiert werden
    if (!validateSkill(clawhubPath)) {
      log(`Validation failed for ClawHub skill: ${skillName}`, "ERROR");
      return "error";
    }
    if (!validateSkill(gitPath)) {
      log(`Validation failed for Git skill: ${skillName}`, "ERROR");
      return "error";
    }

    // Berechne Hashes für clawhub und git
    const clawhubHashes = getHashes(clawhubPath);
    const gitHashes = getHashes(gitPath);

    if (JSON.stringify(clawhubHashes) !== JSON.stringify(gitHashes)) {
      log(`Content difference detected for: ${skillName}`);

      // Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
      // Eine detailliertere Strategie (z.B. welche Version von Git übernehmen)
      // könnte hier implementiert werden, falls nötig.
      // Für jetzt: Wenn sie sich unterscheiden, priorisieren wir ClawHub > Git
      // und aktualisieren Git.

      const clawhubStat = fs.statSync(clawhubPath);
      const gitStat = fs.statSync(gitPath);
      const direction =
        clawhubStat.mtimeMs >= gitStat.mtimeMs ? "to-git" : "to-clawhub";
      log(`UPDATE: ${skillName} → syncing ${direction}`);
      if (!dryRun) {
        backupSkillDir(clawhubPath, `${skillName}_clawhub`);
        backupSkillDir(gitPath, `${skillName}_git`);
      }
      const sync = direction === "to-git" ? syncToGit : syncToClawhub;
      if (sync(skillName, dryRun)) {
        if (!dryRun && direction === "to-git") {
          process.chdir(gitPath);
          spawnSync("git", ["add", "."], { stdio: 'ignore' });
          spawnSync("git", [
            "commit",
            "-m",
            `Sync from ClawHub content diff: ${new Date().toISOString().split('T')[0]}`
          ], { stdio: 'ignore' });
        }
        return direction === "to-git" ? "updated_git" : "updated_clawhub";
      } else {
        log(`Failed to sync ${skillName} to Git after content diff`, "ERROR");
        return "error";
      }
    } else {
      log(`Content is identical for: ${skillName}`);
      return "no_change";
    }
  }

  return "no_change";
}

// --- Hinzufügen dieser Hilfsfunktion ---
function getHashes(skillDir) {
  /** Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner. */
  const hashes = {};

  function walkDir(currentDir) {
    const items = fs.readdirSync(currentDir);
    for (const item of items) {
      const itemPath = path.join(currentDir, item);
      const relativePath = path.relative(skillDir, itemPath);

      // Ignoriere .git Verzeichnisse
      if (item === '.git') continue;

      const stat = fs.statSync(itemPath);
      if (stat.isDirectory()) {
        walkDir(itemPath);
      } else {
        hashes[relativePath] = getFileHash(itemPath);
      }
    }
  }

  walkDir(skillDir);
  return hashes;
}

function main() {
  /** Hauptfunktion des Sync-Agents */
  const args = process.argv.slice(2);
  const DRY_RUN = args.includes('--dry-run');
  log("=== ClawHub ↔ Git Sync Agent gestartet ===");

  const state = loadState();
  const allSkills = getAllSkills();
  log(`Gefundene Skills: ${allSkills.size}`);

  const results = {
    synced_to_git: [],
    synced_to_clawhub: [],
    updated_git: [],
    updated_clawhub: [],
    no_change: [],
    errors: []
  };

  for (const skill of Array.from(allSkills).sort()) {
    try {
      const result = syncSkillBidirectional(skill, DRY_RUN);
      results[result].push(skill);
    } catch (e) {
      log(`ERROR syncing ${skill}: ${e.message || e}`, "ERROR");
      results.errors.push(skill);
    }
  }

  // Zusammenfassung
  log("\n=== SYNC ZUSAMMENFASSUNG ===");
  log(`Neu in Git: ${results.synced_to_git.length} - [${results.synced_to_git.join(', ')}]`);
  log(`Neu in ClawHub: ${results.synced_to_clawhub.length} - [${results.synced_to_clawhub.join(', ')}]`);
  log(`Git aktualisiert: ${results.updated_git.length} - [${results.updated_git.join(', ')}]`);
  log(`ClawHub aktualisiert: ${results.updated_clawhub.length} - [${results.updated_clawhub.join(', ')}]`);
  log(`Keine Änderung: ${results.no_change.length}`);
  log(`Fehler: ${results.errors.length} - [${results.errors.join(', ')}]`);

  // Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
  if (!DRY_RUN) {
    if (!state.sync_history) {
      state.sync_history = [];
    }
    state.sync_history.push({
      timestamp: new Date().toISOString(),
      results: results
    });
    // Nur letzte 100 Einträge behalten
    state.sync_history = state.sync_history.slice(-100);
    saveState(state);
  }

  log("=== Sync Agent beendet ===\n");
}

if (require.main === module) {
  main();
}

module.exports = {
  loadState,
  saveState,
  getAllSkills,
  initGitRepo,
  backupSkillDir,
  syncSkillBidirectional,
  getHashes
};
