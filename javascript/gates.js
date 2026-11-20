#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "bcd97079e408d4969e4fd8507e2ab9786456b51c42fff91cf3d932c04b849963", "source_sha256": "2831a8a242630f9e502bf810a5eba7959a0a033472a3dd6c333bc3178d2227d2", "target_language": "javascript"}
// gates.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/gates.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import { execSync, spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Helper to get __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Emulates shell's `source` by reading and setting environment variables
function sourceEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        const key = trimmed.substring(0, eqIndex);
        let value = trimmed.substring(eqIndex + 1);
        // Remove surrounding quotes if present
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        process.env[key] = value;
      }
    }
  }
}

// Mimics shell's run_quiet_logged function
function runQuietLogged(label, logFile, command, envVars = {}) {
  const logPath = path.resolve('.local', logFile);
  const env = { ...process.env, ...envVars };
  console.log(`Running: ${label}`);
  try {
    const out = execSync(command, { cwd: process.cwd(), env, stdio: ['pipe', 'pipe', 'pipe'] });
    fs.writeFileSync(logPath, out.toString());
  } catch (error) {
    fs.writeFileSync(logPath, error.stdout?.toString() + error.stderr?.toString());
    console.error(`Command failed: ${command}`);
    process.exit(1);
  }
}

// Mimics shell's require_artifact
function requireArtifact(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Required artifact missing: ${filePath}`);
    process.exit(1);
  }
}

// Mimics shell's path_is_docsish
function pathIsDocsish(filePath) {
  const docsPaths = [
    /^docs\//,
    /\.md$/,
    /^README/,
    /^CONTRIBUTING/,
    /^\.github\/workflows\/docs/,
    /^\.changeset\//
  ];
  return docsPaths.some(pattern => pattern.test(filePath));
}

// Mimics shell's file_list_is_docsish_only
function fileListIsDocsishOnly(fileList) {
  if (!fileList.trim()) return true;
  const files = fileList.split('\n').filter(f => f.trim());
  return files.every(pathIsDocsish);
}

// Mimics shell's changelog_required_for_changed_files
function changelogRequiredForChangedFiles(changedFiles) {
  if (!changedFiles.trim()) return false;
  const files = changedFiles.split('\n').filter(f => f.trim());
  const codeChangePatterns = [
    /\.(js|ts|jsx|tsx|json|yaml|yml|toml)$/,
    /^src\//,
    /^lib\//,
    /^packages\/[^/]+\/(src|lib)\//
  ];
  return files.some(file =>
    codeChangePatterns.some(pattern => pattern.test(file))
  );
}

// Mimics shell's enter_worktree
function enterWorktree(pr, flag) {
  // Placeholder implementation
  console.log(`enter_worktree called with pr=${pr}, flag=${flag}`);
}

// Mimics shell's checkout_prep_branch
function checkoutPrepBranch(pr) {
  // Placeholder implementation
  console.log(`checkout_prep_branch called with pr=${pr}`);
}

// Mimics shell's bootstrap_deps_if_needed
function bootstrapDepsIfNeeded() {
  // Placeholder implementation
  console.log('bootstrap_deps_if_needed called');
}

// Mimics shell's normalize_pr_changelog_entries
function normalizePrChangelogEntries(pr) {
  // Placeholder implementation
  console.log(`normalize_pr_changelog_entries called with pr=${pr}`);
}

// Mimics shell's validate_changelog_merge_hygiene
function validateChangelogMergeHygiene() {
  // Placeholder implementation
  console.log('validate_changelog_merge_hygiene called');
}

// Mimics shell's validate_changelog_entry_for_pr
function validateChangelogEntryForPr(pr, contrib) {
  // Placeholder implementation
  console.log(`validate_changelog_entry_for_pr called with pr=${pr}, contrib=${contrib}`);
}

// Main functions translated from shell script

export function runPreparePushRetryGates(docsOnly = false) {
  bootstrapDepsIfNeeded();
  runQuietLogged("pnpm build (lease-retry)", ".local/lease-retry-build.log", "pnpm build");
  runQuietLogged("pnpm check (lease-retry)", ".local/lease-retry-check.log", "pnpm check");
  if (docsOnly !== true) {
    runQuietLogged("pnpm test (lease-retry)", ".local/lease-retry-test.log", "pnpm test");
  }
}

export function prepareGates(pr) {
  enterWorktree(pr, false);
  checkoutPrepBranch(pr);
  bootstrapDepsIfNeeded();
  requireArtifact('.local/pr-meta.env');
  sourceEnv('.local/pr-meta.env');

  const changedFilesOutput = execSync('git diff --name-only origin/main...HEAD', { encoding: 'utf-8' }).trim();
  const changedFilesList = changedFilesOutput ? changedFilesOutput.split('\n') : [];
  
  const nonDocsFiles = changedFilesList.filter(file => file.trim() && !pathIsDocsish(file));

  const docsOnly = changedFilesList.length > 0 && nonDocsFiles.length === 0;

  const changelogRequired = changelogRequiredForChangedFiles(changedFilesOutput);

  const hasChangelogUpdate = changedFilesList.includes('CHANGELOG.md');

  const unsupportedFragments = changedFilesList.filter(file => file.startsWith('changelog/fragments/'));
  if (unsupportedFragments.length > 0) {
    console.error("Unsupported changelog fragment files detected:");
    unsupportedFragments.forEach(f => console.log(f));
    console.error("Move changelog fragment content into CHANGELOG.md and remove changelog/fragments files.");
    process.exit(1);
  }

  if (changelogRequired && !hasChangelogUpdate) {
    console.error("Missing changelog update. Add CHANGELOG.md changes.");
    process.exit(1);
  }

  if (hasChangelogUpdate) {
    normalizePrChangelogEntries(pr);
  }

  if (changelogRequired) {
    const contrib = process.env.PR_AUTHOR || '';
    validateChangelogMergeHygiene();
    validateChangelogEntryForPr(pr, contrib);
  } else {
    console.log("Changelog not required for this changed-file set.");
  }

  const currentHead = execSync('git rev-parse HEAD', { encoding: 'utf-8' }).trim();
  let previousLastVerifiedHead = "";
  let previousFullGatesHead = "";

  const gatesEnvPath = '.local/gates.env';
  if (fs.existsSync(gatesEnvPath) && fs.statSync(gatesEnvPath).size > 0) {
    sourceEnv(gatesEnvPath);
    previousLastVerifiedHead = process.env.LAST_VERIFIED_HEAD_SHA || "";
    previousFullGatesHead = process.env.FULL_GATES_HEAD_SHA || "";
  }

  let gatesMode = "full";
  let reuseGates = false;

  if (docsOnly && previousLastVerifiedHead) {
    try {
      execSync(`git merge-base --is-ancestor ${previousLastVerifiedHead} HEAD`, { stdio: 'ignore' });
      const deltaOutput = execSync(`git diff --name-only ${previousLastVerifiedHead}..HEAD`, { encoding: 'utf-8' }).trim();
      const deltaFiles = deltaOutput ? deltaOutput.split('\n') : [];
      if (deltaFiles.length === 0 || fileListIsDocsishOnly(deltaOutput)) {
        reuseGates = true;
      }
    } catch (e) {
      // Not an ancestor, continue
    }
  }

  if (reuseGates) {
    gatesMode = "reused_docs_only";
    console.log(`Docs/changelog-only delta since last verified head ${previousLastVerifiedHead}; reusing prior gates.`);
  } else {
    runQuietLogged("pnpm build", ".local/gates-build.log", "pnpm build");
    runQuietLogged("pnpm check", ".local/gates-check.log", "pnpm check");

    if (docsOnly) {
      gatesMode = "docs_only";
      console.log("Docs-only change detected with high confidence; skipping pnpm test.");
    } else {
      gatesMode = "full";
      const maxWorkers = process.env.OPENCLAW_VITEST_MAX_WORKERS || "4";
      console.log(`Running pnpm test with OPENCLAW_VITEST_MAX_WORKERS=${maxWorkers}.`);
      runQuietLogged(
        "pnpm test",
        ".local/gates-test.log",
        "pnpm test",
        { OPENCLAW_VITEST_MAX_WORKERS: maxWorkers }
      );
      previousFullGatesHead = currentHead;
    }
  }

  const gatesPassedAt = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
  const envContent = 
`PR_NUMBER='${pr}'
DOCS_ONLY='${docsOnly}'
CHANGELOG_REQUIRED='${changelogRequired}'
GATES_MODE='${gatesMode}'
LAST_VERIFIED_HEAD_SHA='${currentHead}'
FULL_GATES_HEAD_SHA='${previousFullGatesHead}'
GATES_PASSED_AT='${gatesPassedAt}'
`;

  fs.writeFileSync(gatesEnvPath, envContent);

  console.log(`docs_only=${docsOnly}`);
  console.log(`changelog_required=${changelogRequired}`);
  console.log(`gates_mode=${gatesMode}`);
  console.log("wrote=.local/gates.env");
}
