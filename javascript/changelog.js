#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "e88a301afad628e6a3360e2dc2e14049d9bd267daed7dbe91dd21348bf447949", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "javascript"}
// changelog.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const { spawnSync } = require('child_process');
const readline = require('readline');

function normalizePrChangelogEntries(pr) {
  const changelogPath = 'CHANGELOG.md';
  
  if (!fs.existsSync(changelogPath)) {
    return;
  }

  const original = fs.readFileSync(changelogPath, 'utf8');
  const lines = original.split('\n');
  const prPattern = new RegExp(`(?:\\(#${pr}\\)|openclaw#${pr})`, 'i');

  function findActiveSectionIndex(arr) {
    return arr.findIndex((line) => line.trim() === '## Unreleased');
  }

  function findSectionEnd(arr, start) {
    for (let i = start + 1; i < arr.length; i += 1) {
      if (/^## /.test(arr[i])) {
        return i;
      }
    }
    return arr.length;
  }

  function ensureActiveSection(arr) {
    let activeIndex = findActiveSectionIndex(arr);
    if (activeIndex !== -1) {
      return activeIndex;
    }

    let insertAt = arr.findIndex((line, idx) => idx > 0 && /^## /.test(line));
    if (insertAt === -1) {
      insertAt = arr.length;
    }

    const block = ['## Unreleased', '', '### Changes', ''];
    if (insertAt > 0 && arr[insertAt - 1] !== '') {
      block.unshift('');
    }
    arr.splice(insertAt, 0, ...block);
    return findActiveSectionIndex(arr);
  }

  function contextFor(arr, index) {
    let major = '';
    let minor = '';
    for (let i = index; i >= 0; i -= 1) {
      const line = arr[i];
      if (!minor && /^### /.test(line)) {
        minor = line.trim();
      }
      if (/^## /.test(line)) {
        major = line.trim();
        break;
      }
    }
    return { major, minor };
  }

  function ensureSubsection(arr, subsection) {
    const activeIndex = ensureActiveSection(arr);
    const activeEnd = findSectionEnd(arr, activeIndex);
    const desired = subsection && /^### /.test(subsection) ? subsection : '### Changes';
    for (let i = activeIndex + 1; i < activeEnd; i += 1) {
      if (arr[i].trim() === desired) {
        return i;
      }
    }

    let insertAt = activeEnd;
    while (insertAt > activeIndex + 1 && arr[insertAt - 1] === '') {
      insertAt -= 1;
    }
    const block = ['', desired, ''];
    arr.splice(insertAt, 0, ...block);
    return insertAt + 1;
  }

  function sectionTailInsertIndex(arr, subsectionIndex) {
    let nextHeading = arr.length;
    for (let i = subsectionIndex + 1; i < arr.length; i += 1) {
      if (/^### /.test(arr[i]) || /^## /.test(arr[i])) {
        nextHeading = i;
        break;
      }
    }

    let insertAt = nextHeading;
    while (insertAt > subsectionIndex + 1 && arr[insertAt - 1] === '') {
      insertAt -= 1;
    }
    return insertAt;
  }

  ensureActiveSection(lines);

  const moved = [];
  for (let i = 0; i < lines.length; i += 1) {
    if (!prPattern.test(lines[i])) {
      continue;
    }
    const ctx = contextFor(lines, i);
    if (ctx.major === '## Unreleased') {
      continue;
    }
    moved.push({
      line: lines[i],
      subsection: ctx.minor || '### Changes',
      index: i,
    });
  }

  if (moved.length === 0) {
    return;
  }

  const removeIndexes = new Set(moved.map((entry) => entry.index));
  const nextLines = lines.filter((_, idx) => !removeIndexes.has(idx));

  for (const entry of moved) {
    const subsectionIndex = ensureSubsection(nextLines, entry.subsection);
    const insertAt = sectionTailInsertIndex(nextLines, subsectionIndex);

    let nextHeading = nextLines.length;
    for (let i = subsectionIndex + 1; i < nextLines.length; i += 1) {
      if (/^### /.test(nextLines[i]) || /^## /.test(nextLines[i])) {
        nextHeading = i;
        break;
      }
    }

    const alreadyPresent = nextLines
      .slice(subsectionIndex + 1, nextHeading)
      .some((line) => line === entry.line);
    if (alreadyPresent) {
      continue;
    }
    nextLines.splice(insertAt, 0, entry.line);
  }

  const updated = nextLines.join('\n');
  if (updated !== original) {
    fs.writeFileSync(changelogPath, updated);
  }
}

function validateChangelogEntryForPr(pr, contrib) {
  const gitResult = spawnSync('git', ['diff', '--unified=0', 'origin/main...HEAD', '--', 'CHANGELOG.md'], { encoding: 'utf8' });
  if (gitResult.status !== 0) {
    console.error('Failed to get git diff');
    process.exit(1);
  }

  const diffOutput = gitResult.stdout;
  const addedLines = diffOutput
    .split('\n')
    .filter(line => !line.startsWith('+++'))
    .filter(line => line.startsWith('+'))
    .map(line => line.substring(1));

  if (addedLines.length === 0) {
    console.log('CHANGELOG.md is in diff but no added lines were detected.');
    process.exit(1);
  }

  const prPattern = `(#${pr}|openclaw#${pr})`;
  const withPr = addedLines.filter(line => new RegExp(prPattern, 'i').test(line));

  if (withPr.length === 0) {
    console.log(`CHANGELOG.md update must reference PR #${pr} (for example, (#${pr})).`);
    process.exit(1);
  }

  const tmpFile = require('os').tmpdir() + '/changelog_diff_' + Date.now();
  fs.writeFileSync(tmpFile, diffOutput);

  try {
    const awkScript = `
BEGIN {
  line_no = 0
  file_line_count = 0
  issue_count = 0
}
FNR == NR {
  if ($0 ~ /^@@ /) {
    if (match($0, /\\+[0-9]+/)) {
      line_no = substr($0, RSTART + 1, RLENGTH - 1) + 0
    } else {
      line_no = 0
    }
    next
  }
  if ($0 ~ /^\\+\\+\\+/) {
    next
  }
  if ($0 ~ /^\\+/) {
    if (line_no > 0) {
      added[line_no] = 1
      added_text = substr($0, 2)
      if (added_text ~ pr_pattern) {
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }
      line_no++
    }
    next
  }
  if ($0 ~ /^-/) {
    next
  }
  if (line_no > 0) {
    line_no++
  }
  next
}
{
  changelog[FNR] = $0
  file_line_count = FNR
}
END {
  for (idx = 1; idx <= pr_added_count; idx++) {
    entry_line = pr_added_lines[idx]
    release_line = 0
    section_line = 0
    for (i = entry_line; i >= 1; i--) {
      if (section_line == 0 && changelog[i] ~ /^### /) {
        section_line = i
        continue
      }
      if (changelog[i] ~ /^## /) {
        release_line = i
        break
      }
    }
    if (release_line == 0 || changelog[release_line] != "## Unreleased") {
      printf "CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }
    if (section_line == 0) {
      printf "CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }

    section_name = changelog[section_line]
    next_heading = file_line_count + 1
    for (i = entry_line + 1; i <= file_line_count; i++) {
      if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) {
        next_heading = i
        break
      }
    }

    for (i = entry_line + 1; i < next_heading; i++) {
      line_text = changelog[i]
      if (line_text ~ /^[[:space:]]*$/) {
        continue
      }
      if (i in added) {
        continue
      }
      printf "CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\\n", section_name, entry_line, pr_added_text[entry_line]
      printf "Found existing non-added line below it at line %d: %s\\n", i, line_text
      issue_count++
      break
    }
  }

  if (issue_count > 0) {
    print "Move this PR changelog entry to the end of its section (just before the next heading)."
    exit 1
  }
}
`;

    const awkProcess = spawnSync('awk', ['-v', `pr_pattern=${prPattern}`, awkScript, tmpFile, 'CHANGELOG.md'], { 
      encoding: 'utf8',
      input: fs.readFileSync('CHANGELOG.md', 'utf8')
    });

    if (awkProcess.status !== 0) {
      console.log(awkProcess.stderr || awkProcess.stdout);
      process.exit(1);
    }

    if (awkProcess.stdout.trim()) {
      console.log(awkProcess.stdout);
      process.exit(1);
    }
  } finally {
    if (fs.existsSync(tmpFile)) {
      fs.unlinkSync(tmpFile);
    }
  }

  console.log('changelog placement validated: PR-linked entries are appended at section tail');

  if (contrib && contrib !== 'null') {
    const withPrAndThanks = withPr.filter(line => /thanks @/i.test(line) && new RegExp(`@${contrib}`, 'i').test(line));
    
    if (withPrAndThanks.length === 0) {
      console.log(`CHANGELOG.md update must include both PR #${pr} and thanks @${contrib} on the changelog entry line.`);
      process.exit(1);
    }
    
    console.log(`changelog validated: found PR #${pr} + thanks @${contrib}`);
    return;
  }

  console.log(`changelog validated: found PR #${pr} (contributor handle unavailable, skipping thanks check)`);
}

function validateChangelogMergeHygiene() {
  const gitResult = spawnSync('git', ['diff', '--unified=0', 'origin/main...HEAD', '--', 'CHANGELOG.md'], { encoding: 'utf8' });
  if (gitResult.status !== 0) {
    return;
  }

  const diffOutput = gitResult.stdout;
  const removedLines = diffOutput
    .split('\n')
    .filter(line => !line.startsWith('---'))
    .filter(line => line.startsWith('-'))
    .map(line => line.substring(1));

  if (removedLines.length === 0) {
    return;
  }

  const removedRefs = [...new Set(
    removedLines
      .join('\n')
      .match(/#[0-9]+/g) || []
  )];

  if (removedRefs.length === 0) {
    return;
  }

  const addedLines = diffOutput
    .split('\n')
    .filter(line => !line.startsWith('+++'))
    .filter(line => line.startsWith('+'))
    .map(line => line.substring(1));

  for (const ref of removedRefs) {
    if (!addedLines.some(line => line.includes(ref))) {
      console.log(`CHANGELOG.md drops existing entry reference ${ref} without re-adding it.`);
      console.log('Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).');
      process.exit(1);
    }
  }

  console.log('changelog merge hygiene validated: no dropped PR references');
}

// Main execution
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args[0] === 'normalize') {
    if (!args[1]) {
      console.error('PR number required for normalize');
      process.exit(1);
    }
    normalizePrChangelogEntries(args[1]);
  } else if (args[0] === 'validate-entry') {
    if (!args[1]) {
      console.error('PR number required for validate-entry');
      process.exit(1);
    }
    validateChangelogEntryForPr(args[1], args[2] || null);
  } else if (args[0] === 'validate-hygiene') {
    validateChangelogMergeHygiene();
  } else {
    console.error('Usage: node changelog.js [normalize <pr>|validate-entry <pr> [contrib]|validate-hygiene]');
    process.exit(1);
  }
}

module.exports = {
  normalizePrChangelogEntries,
  validateChangelogEntryForPr,
  validateChangelogMergeHygiene
};
