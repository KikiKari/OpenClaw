#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a55d009bc24caf086a05a0e0e6a9462f3d664269fa7fe54f09534880273a0844", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "javascript"}
// check-composite-action-input-interpolation.py — portiert nach javascript
// Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';

const INPUT_INTERPOLATION_RE = /\$\{\{\s*inputs\./;
const RUN_LINE_RE = /^(\s*)run:\s*(.*)$/;
const USING_COMPOSITE_RE = /^\s*using:\s*composite\s*$/m;

function indentation(line) {
    return line.length - line.trimStart().length;
}

function scanFile(filePath) {
    const text = fs.readFileSync(filePath, 'utf8');
    if (!USING_COMPOSITE_RE.test(text)) {
        return [];
    }

    const lines = text.split('\n');
    const violations = [];
    const lineCount = lines.length;
    let index = 0;

    while (index < lineCount) {
        const line = lines[index];
        const match = RUN_LINE_RE.exec(line);
        if (!match) {
            index++;
            continue;
        }

        const runIndent = match[1].length;
        const runValue = match[2].trim();
        const lineNo = index + 1;

        if (runValue && !runValue.startsWith('|') && !runValue.startsWith('>')) {
            if (INPUT_INTERPOLATION_RE.test(runValue)) {
                violations.push([lineNo, line.trim()]);
            }
            index++;
            continue;
        }

        index++;
        while (index < lineCount) {
            const scriptLine = lines[index];
            if (scriptLine.trim() === '') {
                index++;
                continue;
            }
            if (indentation(scriptLine) <= runIndent) {
                break;
            }
            if (INPUT_INTERPOLATION_RE.test(scriptLine)) {
                violations.push([index + 1, scriptLine.trim()]);
            }
            index++;
        }
    }

    return violations;
}

function main() {
    const root = '.github/actions';
    const files = [];

    function walkDir(dir) {
        const entries = fs.readdirSync(dir);
        for (const entry of entries) {
            const entryPath = path.join(dir, entry);
            const stat = fs.statSync(entryPath);
            if (stat.isDirectory()) {
                walkDir(entryPath);
            } else if (entry.startsWith('action.y') && entry.includes('ml')) {
                files.push(entryPath);
            }
        }
    }

    try {
        walkDir(root);
    } catch (err) {
        if (err.code === 'ENOENT') {
            console.log('No .github/actions directory found.');
            return 0;
        }
        throw err;
    }

    files.sort();
    const allViolations = [];

    for (const filePath of files) {
        const violations = scanFile(filePath);
        for (const [lineNo, line] of violations) {
            allViolations.push([filePath, lineNo, line]);
        }
    }

    if (allViolations.length > 0) {
        console.log('Disallowed direct inputs interpolation in composite run blocks:');
        for (const [filePath, lineNo, line] of allViolations) {
            console.log(`- ${filePath}:${lineNo}: ${line}`);
        }
        console.log('Use env: and reference shell variables instead.');
        return 1;
    }

    console.log('No direct inputs interpolation found in composite run blocks.');
    return 0;
}

process.exit(main());
