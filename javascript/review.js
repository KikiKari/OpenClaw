#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "8b81da0ad947bbc2053ea8ab8969937823a2e2be11cb8e94abe658a39dac911d", "source_sha256": "24e3cb1dc8d717f90272134987f4b84a5137f1d8cacace1c6ccd6621b24e9566", "target_language": "javascript"}
// review.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/review.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { execSync, spawn } from 'child_process';
import { promisify } from 'util';

const exec = promisify(execSync);

function setReviewMode(mode) {
  const content = `REVIEW_MODE=${JSON.stringify(mode)}\n` +
                  `REVIEW_MODE_SET_AT=${JSON.stringify(new Date().toISOString())}\n`;
  fs.writeFileSync('.local/review-mode.env', content);
}

async function reviewClaim(pr) {
  const root = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
  process.chdir(root);
  fs.mkdirSync('.local', { recursive: true });

  let reviewer = '';
  const maxAttempts = 3;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const userLog = `.local/review-claim-user-attempt-${attempt}.log`;

    try {
      reviewer = execSync('gh api user --jq .login', { encoding: 'utf8' }).trim();
      fs.writeFileSync(userLog, reviewer + '\n');
      break;
    } catch (error) {
      fs.writeFileSync(userLog, error.message);
      console.error(`Claim reviewer lookup failed (attempt ${attempt}/${maxAttempts}).`);
      // printRelevantLogExcerpt(userLog); // Assuming this function exists elsewhere
      if (attempt < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
  }

  if (!reviewer) {
    console.error(`Failed to resolve reviewer login after ${maxAttempts} attempts.`);
    return false;
  }

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const claimLog = `.local/review-claim-assignee-attempt-${attempt}.log`;

    try {
      execSync(`gh pr edit ${pr} --add-assignee ${reviewer}`, { stdio: 'pipe' });
      console.log(`review claim succeeded: @${reviewer} assigned to PR #${pr}`);
      return true;
    } catch (error) {
      fs.writeFileSync(claimLog, error.message);
      console.error(`Claim assignee update failed (attempt ${attempt}/${maxAttempts}).`);
      // printRelevantLogExcerpt(claimLog); // Assuming this function exists elsewhere
      if (attempt < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
  }

  console.error(`Failed to assign @${reviewer} to PR #${pr} after ${maxAttempts} attempts.`);
  return false;
}

function reviewCheckoutMain(pr) {
  enterWorktree(pr, false);
  execSync('git fetch origin main');
  execSync('git checkout --detach origin/main');
  setReviewMode('main');

  console.log('review mode set to main baseline');
  console.log(`branch=${execSync('git branch --show-current', { encoding: 'utf8' }).trim()}`);
  console.log(`head=${execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim()}`);
}

function reviewCheckoutPr(pr) {
  enterWorktree(pr, false);
  execSync(`git fetch origin pull/${pr}/head:pr-${pr} --force`);
  execSync(`git checkout --detach pr-${pr}`);
  setReviewMode('pr');

  console.log('review mode set to PR head');
  console.log(`branch=${execSync('git branch --show-current', { encoding: 'utf8' }).trim()}`);
  console.log(`head=${execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim()}`);
}

function reviewGuard(pr) {
  enterWorktree(pr, false);
  requireArtifact('.local/review-mode.env');
  requireArtifact('.local/pr-meta.env');

  const reviewModeEnv = fs.readFileSync('.local/review-mode.env', 'utf8');
  eval(reviewModeEnv);
  const prMetaEnv = fs.readFileSync('.local/pr-meta.env', 'utf8');
  eval(prMetaEnv);

  const branch = execSync('git branch --show-current', { encoding: 'utf8' }).trim();
  const headSha = execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();

  switch (REVIEW_MODE) {
    case 'main': {
      const expectedMainSha = execSync('git rev-parse origin/main', { encoding: 'utf8' }).trim();
      if (headSha !== expectedMainSha) {
        console.error(`Review guard failed: expected HEAD at origin/main (${expectedMainSha}) for main baseline mode, got ${headSha}`);
        process.exit(1);
      }
      break;
    }
    case 'pr': {
      if (!PR_HEAD_SHA) {
        console.error('Review guard failed: missing PR_HEAD_SHA in .local/pr-meta.env');
        process.exit(1);
      }
      if (headSha !== PR_HEAD_SHA) {
        console.error(`Review guard failed: expected HEAD at PR_HEAD_SHA (${PR_HEAD_SHA}), got ${headSha}`);
        process.exit(1);
      }
      break;
    }
    default:
      console.error(`Review guard failed: unknown review mode '${REVIEW_MODE}'`);
      process.exit(1);
  }

  console.log('review guard passed');
  console.log(`mode=${REVIEW_MODE}`);
  console.log(`branch=${branch}`);
  console.log(`head=${headSha}`);
}

function reviewArtifactsInit(pr) {
  enterWorktree(pr, false);
  requireArtifact('.local/pr-meta.env');

  if (!fs.existsSync('.local/review.md')) {
    const mdContent = `A) TL;DR recommendation

B) What changed and what is good?

C) Security findings

D) What is the PR intent? Is this the most optimal implementation?

E) Concerns or questions (actionable)

F) Tests

G) Docs status

H) Changelog

I) Follow ups (optional)

J) Suggested PR comment (optional)
`;
    fs.writeFileSync('.local/review.md', mdContent);
  }

  if (!fs.existsSync('.local/review.json')) {
    const jsonContent = `{
  "recommendation": "NEEDS WORK",
  "findings": [],
  "nitSweep": {
    "performed": true,
    "status": "none",
    "summary": "No optional nits identified."
  },
  "behavioralSweep": {
    "performed": true,
    "status": "not_applicable",
    "summary": "No runtime branch-level behavior changes require sweep evidence.",
    "silentDropRisk": "none",
    "branches": []
  },
  "issueValidation": {
    "performed": true,
    "source": "pr_body",
    "status": "unclear",
    "summary": "Review not completed yet."
  },
  "tests": {
    "ran": [],
    "gaps": [],
    "result": "pass"
  },
  "docs": "not_applicable",
  "changelog": "not_required"
}`;
    fs.writeFileSync('.local/review.json', jsonContent);
  }

  console.log('review artifact templates are ready');
  console.log('files=.local/review.md .local/review.json');
}

function reviewValidateArtifacts(pr) {
  enterWorktree(pr, false);
  requireArtifact('.local/review.md');
  requireArtifact('.local/review.json');
  requireArtifact('.local/pr-meta.env');
  requireArtifact('.local/pr-meta.json');

  reviewGuard(pr);

  execSync('jq . .local/review.json', { stdio: 'ignore' });

  const sections = ['A)', 'B)', 'C)', 'D)', 'E)', 'F)', 'G)', 'H)', 'I)', 'J)'];
  for (const section of sections) {
    const found = execSync(`awk -v s="${section}" 'index($0, s) == 1 { found=1; exit } END { exit(found ? 0 : 1) }' .local/review.md`, { encoding: 'utf8' });
    if (found.trim() !== '0') {
      console.error(`Missing section header in .local/review.md: ${section}`);
      process.exit(1);
    }
  }

  const recommendation = JSON.parse(execSync('jq -r \'.recommendation // ""\' .local/review.json', { encoding: 'utf8' })).trim();
  const validRecommendations = ['READY FOR /prepare-pr', 'NEEDS WORK', 'NEEDS DISCUSSION', 'NOT USEFUL (CLOSE)'];
  if (!validRecommendations.includes(recommendation)) {
    console.error(`Invalid recommendation in .local/review.json: ${recommendation}`);
    process.exit(1);
  }

  const invalidSeverityCount = parseInt(execSync('jq \'[.findings[]? | select((.severity // "") != "BLOCKER" and (.severity // "") != "IMPORTANT" and (.severity // "") != "NIT")] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidSeverityCount > 0) {
    console.error('Invalid finding severity in .local/review.json');
    process.exit(1);
  }

  const invalidFindingsCount = parseInt(execSync('jq \'[.findings[]? | select((.id|type)!="string" or (.title|type)!="string" or (.area|type)!="string" or (.fix|type)!="string")] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidFindingsCount > 0) {
    console.error('Invalid finding shape in .local/review.json (id/title/area/fix must be strings)');
    process.exit(1);
  }

  const nitFindingsCount = parseInt(execSync('jq \'[.findings[]? | select((.severity // "") == "NIT")] | length\' .local/review.json', { encoding: 'utf8' }));
  const nitSweepPerformed = execSync('jq -r \'.nitSweep.performed // empty\' .local/review.json', { encoding: 'utf8' }).trim();
  if (nitSweepPerformed !== 'true') {
    console.error('Invalid nit sweep in .local/review.json: nitSweep.performed must be true');
    process.exit(1);
  }

  const nitSweepStatus = execSync('jq -r \'.nitSweep.status // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  switch (nitSweepStatus) {
    case 'none':
      if (nitFindingsCount > 0) {
        console.error('Invalid nit sweep in .local/review.json: nitSweep.status is none but NIT findings exist');
        process.exit(1);
      }
      break;
    case 'has_nits':
      if (nitFindingsCount < 1) {
        console.error('Invalid nit sweep in .local/review.json: nitSweep.status is has_nits but no NIT findings exist');
        process.exit(1);
      }
      break;
    default:
      console.error(`Invalid nit sweep status in .local/review.json: ${nitSweepStatus}`);
      process.exit(1);
  }

  const invalidNitSummaryCount = parseInt(execSync('jq \'[.nitSweep.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidNitSummaryCount > 0) {
    console.error('Invalid nit sweep summary in .local/review.json: nitSweep.summary must be a non-empty string');
    process.exit(1);
  }

  const issueValidationPerformed = execSync('jq -r \'.issueValidation.performed // empty\' .local/review.json', { encoding: 'utf8' }).trim();
  if (issueValidationPerformed !== 'true') {
    console.error('Invalid issue validation in .local/review.json: issueValidation.performed must be true');
    process.exit(1);
  }

  const issueValidationSource = execSync('jq -r \'.issueValidation.source // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validIssueSources = ['linked_issue', 'pr_body', 'both'];
  if (!validIssueSources.includes(issueValidationSource)) {
    console.error(`Invalid issue validation source in .local/review.json: ${issueValidationSource}`);
    process.exit(1);
  }

  const issueValidationStatus = execSync('jq -r \'.issueValidation.status // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validIssueStatuses = ['valid', 'unclear', 'invalid', 'already_fixed_on_main'];
  if (!validIssueStatuses.includes(issueValidationStatus)) {
    console.error(`Invalid issue validation status in .local/review.json: ${issueValidationStatus}`);
    process.exit(1);
  }

  const invalidIssueSummaryCount = parseInt(execSync('jq \'[.issueValidation.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidIssueSummaryCount > 0) {
    console.error('Invalid issue validation summary in .local/review.json: issueValidation.summary must be a non-empty string');
    process.exit(1);
  }

  const runtimeFileCount = parseInt(execSync('jq \'[.files[]? | (.path // "") | select(test("^(src|extensions|apps)/")) | select(test("(^|/)__tests__/|\\\\.test\\\\.|\\\\.spec\\\\.") | not) | select(test("\\\\.(md|mdx)$") | not)] | length\' .local/pr-meta.json', { encoding: 'utf8' }));
  const runtimeReviewRequired = runtimeFileCount > 0 ? 'true' : 'false';

  const behavioralSweepPerformed = execSync('jq -r \'.behavioralSweep.performed // empty\' .local/review.json', { encoding: 'utf8' }).trim();
  if (behavioralSweepPerformed !== 'true') {
    console.error('Invalid behavioral sweep in .local/review.json: behavioralSweep.performed must be true');
    process.exit(1);
  }

  const behavioralSweepStatus = execSync('jq -r \'.behavioralSweep.status // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validBehavioralStatuses = ['pass', 'needs_work', 'not_applicable'];
  if (!validBehavioralStatuses.includes(behavioralSweepStatus)) {
    console.error(`Invalid behavioral sweep status in .local/review.json: ${behavioralSweepStatus}`);
    process.exit(1);
  }

  const behavioralSweepRisk = execSync('jq -r \'.behavioralSweep.silentDropRisk // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validRisks = ['none', 'present', 'unknown'];
  if (!validRisks.includes(behavioralSweepRisk)) {
    console.error(`Invalid behavioral sweep risk in .local/review.json: ${behavioralSweepRisk}`);
    process.exit(1);
  }

  const invalidBehavioralSummaryCount = parseInt(execSync('jq \'[.behavioralSweep.summary | select((type != "string") or (gsub("^\\\\s+|\\\\s+$";"") | length == 0))] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidBehavioralSummaryCount > 0) {
    console.error('Invalid behavioral sweep summary in .local/review.json: behavioralSweep.summary must be a non-empty string');
    process.exit(1);
  }

  const behavioralBranchesIsArray = execSync('jq -r \'if (.behavioralSweep.branches | type) == "array" then "true" else "false" end\' .local/review.json', { encoding: 'utf8' }).trim();
  if (behavioralBranchesIsArray !== 'true') {
    console.error('Invalid behavioral sweep in .local/review.json: behavioralSweep.branches must be an array');
    process.exit(1);
  }

  const invalidBehavioralBranchCount = parseInt(execSync('jq \'[.behavioralSweep.branches[]? | select((.path|type)!="string" or (.decision|type)!="string" or (.outcome|type)!="string")] | length\' .local/review.json', { encoding: 'utf8' }));
  if (invalidBehavioralBranchCount > 0) {
    console.error('Invalid behavioral sweep branch entry in .local/review.json: each branch needs string path/decision/outcome');
    process.exit(1);
  }

  const behavioralBranchCount = parseInt(execSync('jq \'[.behavioralSweep.branches[]?] | length\' .local/review.json', { encoding: 'utf8' }));

  if (runtimeReviewRequired === 'true' && behavioralSweepStatus === 'not_applicable') {
    console.error('Invalid behavioral sweep in .local/review.json: runtime file changes require behavioralSweep.status=pass|needs_work');
    process.exit(1);
  }

  if (runtimeReviewRequired === 'true' && behavioralBranchCount < 1) {
    console.error('Invalid behavioral sweep in .local/review.json: runtime file changes require at least one branch entry');
    process.exit(1);
  }

  if (behavioralSweepStatus === 'not_applicable' && behavioralBranchCount > 0) {
    console.error('Invalid behavioral sweep in .local/review.json: not_applicable cannot include branch entries');
    process.exit(1);
  }

  if (behavioralSweepStatus === 'pass' && behavioralSweepRisk !== 'none') {
    console.error('Invalid behavioral sweep in .local/review.json: status=pass requires silentDropRisk=none');
    process.exit(1);
  }

  if (recommendation === 'READY FOR /prepare-pr' && issueValidationStatus !== 'valid') {
    console.error('Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires issueValidation.status=valid');
    process.exit(1);
  }

  if (recommendation === 'READY FOR /prepare-pr' && behavioralSweepStatus === 'needs_work') {
    console.error('Invalid recommendation in .local/review.json: READY FOR /prepare-pr requires behavioralSweep.status!=needs_work');
    process.exit(1);
  }

  if (recommendation === 'READY FOR /prepare-pr' && runtimeReviewRequired === 'true' && behavioralSweepStatus !== 'pass') {
    console.error('Invalid recommendation in .local/review.json: READY FOR /prepare-pr on runtime changes requires behavioralSweep.status=pass');
    process.exit(1);
  }

  if (recommendation === 'READY FOR /prepare-pr' && behavioralSweepRisk === 'present') {
    console.error('Invalid recommendation in .local/review.json: READY FOR /prepare-pr is not allowed when behavioralSweep.silentDropRisk=present');
    process.exit(1);
  }

  const docsStatus = execSync('jq -r \'.docs // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validDocsStatuses = ['up_to_date', 'missing', 'not_applicable'];
  if (!validDocsStatuses.includes(docsStatus)) {
    console.error(`Invalid docs status in .local/review.json: ${docsStatus}`);
    process.exit(1);
  }

  const changelogStatus = execSync('jq -r \'.changelog // ""\' .local/review.json', { encoding: 'utf8' }).trim();
  const validChangelogStatuses = ['required', 'not_required'];
  if (!validChangelogStatuses.includes(changelogStatus)) {
    console.error(`Invalid changelog status in .local/review.json: ${changelogStatus} (must be "required" or "not_required")`);
    process.exit(1);
  }

  console.log('review artifacts validated');
  printReviewStdoutSummary(); // Assuming this function exists elsewhere
}

function reviewTests(pr, ...targets) {
  if (targets.length < 1) {
    console.error('Usage: scripts/pr review-tests <PR> <test-file> [<test-file> ...]');
    process.exit(2);
  }

  enterWorktree(pr, false);
  reviewGuard(pr);

  for (const target of targets) {
    if (!fs.existsSync(target)) {
      console.error(`Missing test target file: ${target}`);
      process.exit(1);
    }
  }

  bootstrapDepsIfNeeded(); // Assuming this function exists elsewhere

  const runLog = '.local/review-tests-run.log';
  runQuietLogged('pnpm test', runLog, 'pnpm', 'test', '--', ...targets); // Assuming this function exists elsewhere

  const missingRun = [];
  for (const target of targets) {
    const base = path.basename(target);
    try {
      execSync(`rg -F -q ${JSON.stringify(target)} ${runLog}`, { stdio: 'ignore' });
    } catch {
      try {
        execSync(`rg -F -q ${JSON.stringify(base)} ${runLog}`, { stdio: 'ignore' });
      } catch {
        missingRun.push(target);
      }
    }
  }

  if (missingRun.length > 0) {
    console.error('These requested targets were not observed in vitest run output:');
    for (const item of missingRun) {
      console.error(` - ${item}`);
    }
    process.exit(1);
  }

  const content = `REVIEW_TESTS_AT=${JSON.stringify(new Date().toISOString())}\n` +
                  `REVIEW_TEST_TARGET_COUNT=${JSON.stringify(targets.length)}\n`;
  fs.writeFileSync('.local/review-tests.env', content);

  console.log('review tests passed and were observed in output');
}

function reviewInit(pr) {
  enterWorktree(pr, true);

  const json = prMetaJson(pr); // Assuming this function exists elsewhere
  writePrMetaFiles(json); // Assuming this function exists elsewhere

  execSync(`git fetch origin pull/${pr}/head:pr-${pr} --force`);
  const mb = execSync(`git merge-base origin/main pr-${pr}`, { encoding: 'utf8' }).trim();

  const content = `PR_NUMBER=${JSON.stringify(pr)}\n` +
                  `MERGE_BASE=${JSON.stringify(mb)}\n` +
                  `REVIEW_STARTED_AT=${JSON.stringify(new Date().toISOString())}\n`;
  fs.writeFileSync('.local/review-context.env', content);
  setReviewMode('main');

  console.log(JSON.stringify(JSON.parse(json), null, 2));
  console.log(`worktree=${process.cwd()}`);
  console.log(`pr_url=${process.env.PR_URL || ''}`);
  console.log(`merge_base=${mb}`);
  console.log(`branch=${execSync('git branch --show-current', { encoding: 'utf8' }).trim()}`);
  console.log('wrote=.local/pr-meta.json .local/pr-meta.env .local/review-context.env .local/review-mode.env');
  console.log(`Review guidance:
- Inspect main baseline: scripts/pr review-checkout-main ${pr}
- Inspect PR head:      scripts/pr review-checkout-pr ${pr}
- Guard before writeout: scripts/pr review-guard ${pr}`);
}

// Helper functions assumed to exist based on original script context
function enterWorktree(pr, force) {
  // Implementation would depend on specific project setup
}

function requireArtifact(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing required artifact: ${file}`);
  }
}

function prMetaJson(pr) {
  // Implementation would depend on how metadata is fetched
  return '{}';
}

function writePrMetaFiles(json) {
  // Implementation would depend on how files are written
}

function bootstrapDepsIfNeeded() {
  // Implementation would depend on dependency management
}

function runQuietLogged(cmd, logFile, ...args) {
  // Implementation would depend on logging requirements
}

function printReviewStdoutSummary() {
  // Implementation would depend on summary format
}
