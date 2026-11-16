#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "dad4394399da83a435eb9851c11ed15260e750d245280adc705c5fa3c742a5ac", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "javascript"}
// changelog-to-html.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

const VERSION = process.argv[2] || '';
const CHANGELOG_FILE_ARG = process.argv[3] || '';

if (!VERSION) {
  console.error(`Usage: ${process.argv[1]} <version> [changelog_file]`);
  process.exit(1);
}

let CHANGELOG_FILE = CHANGELOG_FILE_ARG;
const scriptDir = path.dirname(process.argv[1]);

if (!CHANGELOG_FILE) {
  const possiblePaths = [
    path.join(scriptDir, '..', 'CHANGELOG.md'),
    path.join('CHANGELOG.md'),
    path.join('..', 'CHANGELOG.md')
  ];
  
  for (const filePath of possiblePaths) {
    if (fs.existsSync(filePath)) {
      CHANGELOG_FILE = filePath;
      break;
    }
  }
  
  if (!CHANGELOG_FILE) {
    console.error('Error: Could not find CHANGELOG.md');
    process.exit(1);
  }
}

if (!fs.existsSync(CHANGELOG_FILE)) {
  console.error(`Error: Changelog file '${CHANGELOG_FILE}' not found`);
  process.exit(1);
}

function extractVersionSection(version, file) {
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n');
  let found = false;
  const result = [];
  
  for (const line of lines) {
    if (line.startsWith('## ')) {
      if (new RegExp(`^##\\s+${version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s.*|$)`).test(line)) {
        found = true;
        continue;
      }
      if (found) {
        break;
      }
    }
    if (found) {
      result.push(line);
    }
  }
  
  return result.join('\n');
}

function markdownToHtml(text) {
  let result = text;
  result = result.replace(/^##### (.*)$/gm, '<h5>$1</h5>');
  result = result.replace(/^#### (.*)$/gm, '<h4>$1</h4>');
  result = result.replace(/^### (.*)$/gm, '<h3>$1</h3>');
  result = result.replace(/^## (.*)$/gm, '<h2>$1</h2>');
  result = result.replace(/^- \*\*([^*]*)\*\*(.*)$/gm, '<li><strong>$1</strong>$2</li>');
  result = result.replace(/^- ([^*].*)$/gm, '<li>$1</li>');
  result = result.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  result = result.replace(/`([^`]+)`/g, '<code>$1</code>');
  result = result.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return result;
}

const versionContent = extractVersionSection(VERSION, CHANGELOG_FILE);

if (!versionContent.trim()) {
  console.log(`<h2>OpenClaw ${VERSION}</h2>`);
  console.log('<p>Latest OpenClaw update.</p>');
  console.log('<p><a href="https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md">View full changelog</a></p>');
  process.exit(0);
}

console.log(`<h2>OpenClaw ${VERSION}</h2>`);

let inList = false;
const lines = versionContent.split('\n');

for (const line of lines) {
  if (line.match(/^-/)) {
    if (!inList) {
      console.log('<ul>');
      inList = true;
    }
    console.log(markdownToHtml(line));
  } else {
    if (inList) {
      console.log('</ul>');
      inList = false;
    }
    if (line.trim()) {
      console.log(markdownToHtml(line));
    }
  }
}

if (inList) {
  console.log('</ul>');
}

console.log('<p><a href="https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md">View full changelog</a></p>');
