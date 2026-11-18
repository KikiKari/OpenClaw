#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "8a1e4f173f70b1a3037168b11ff01c56b4b511bdf79d1b63ff1bede975a856e2", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "javascript"}
// pplx-refresh.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

// Refresh the codespace Perplexity session from a locally-exported cookie.
//
// Usage:
//   ./pplx-refresh.js [cookie-file]
//
// cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
// __Secure-next-auth.session-token value (raw), or the whole Cookie header,
// or a JSON cookie export, into that file first.
//
// Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
//        -> trigger reinit -> verify authenticated.

import { spawnSync } from 'child_process';
import { existsSync, readFileSync, writeFileSync, statSync } from 'fs';
import { homedir } from 'os';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const HERE = __dirname;

const CFG = process.env.PERPLEXITY_CONFIG_DIR || join(homedir(), '.perplexity-mcp');
const PROFILE = process.env.PERPLEXITY_PROFILE || 'codespace';
const COOKIE_FILE = process.argv[2] || join(homedir(), 'pplx-cookies.txt');

function main() {
    if (!existsSync(COOKIE_FILE) || statSync(COOKIE_FILE).size === 0) {
        console.error('✗ Cookie file empty/missing: ' + COOKIE_FILE);
        console.error('  Export __Secure-next-auth.session-token from your local browser');
        console.error('  (DevTools → Application → Cookies → www.perplexity.ai) into that file.');
        process.exit(1);
    }

    // 1. ensure the extension daemon has a usable browser (idempotent)
    const setupResult = spawnSync('bash', [join(HERE, 'pplx-setup.sh')], { stdio: 'inherit' });
    if (setupResult.status !== 0) {
        process.exit(setupResult.status);
    }

    // 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
    const LOCK = join(CFG, 'daemon.lock');
    if (!existsSync(LOCK)) {
        console.error('✗ no daemon.lock at ' + LOCK + ' — is the extension running?');
        process.exit(1);
    }

    let pid;
    try {
        const lockData = JSON.parse(readFileSync(LOCK, 'utf8'));
        pid = lockData.pid;
    } catch (e) {
        console.error('✗ failed to parse daemon.lock');
        process.exit(1);
    }

    try {
        const psResult = spawnSync('ps', ['-p', pid.toString(), '-o', 'pid=']);
        if (psResult.status !== 0) {
            console.error('✗ daemon pid ' + pid + ' not running');
            process.exit(1);
        }
    } catch (e) {
        console.error('✗ failed to check daemon process');
        process.exit(1);
    }

    let pass;
    try {
        const envResult = spawnSync('tr', ['\0', '\n'], { input: readFileSync(`/proc/${pid}/environ`) });
        const envLines = envResult.stdout.toString().split('\n');
        const passLine = envLines.find(line => line.startsWith('PERPLEXITY_VAULT_PASSPHRASE='));
        if (!passLine) {
            console.error('✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env');
            process.exit(1);
        }
        pass = passLine.substring('PERPLEXITY_VAULT_PASSPHRASE='.length);
    } catch (e) {
        console.error('✗ failed to read daemon environment');
        process.exit(1);
    }

    // 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
    let dist;
    try {
        const findResult = spawnSync('find', [join(homedir(), '.npm', '_npx'), '-type', 'd', '-path', '*perplexity-user-mcp/dist'], { encoding: 'utf8' });
        if (findResult.stdout.trim()) {
            dist = findResult.stdout.split('\n')[0].trim();
        }
    } catch (e) {}

    if (!dist) {
        try {
            spawnSync('npx', ['-y', 'perplexity-user-mcp', '--version'], { stdio: 'ignore' });
            const findResult2 = spawnSync('find', [join(homedir(), '.npm', '_npx'), '-type', 'd', '-path', '*perplexity-user-mcp/dist'], { encoding: 'utf8' });
            if (findResult2.stdout.trim()) {
                dist = findResult2.stdout.split('\n')[0].trim();
            }
        } catch (e) {}
    }

    // 4. inject
    const env = {
        ...process.env,
        PERPLEXITY_VAULT_PASSPHRASE: pass,
        PERPLEXITY_CONFIG_DIR: CFG,
        PERPLEXITY_PROFILE: PROFILE,
        PPLX_DIST: dist || ''
    };

    const injectResult = spawnSync('node', [join(HERE, 'pplx-inject.mjs'), COOKIE_FILE], { env, stdio: 'inherit' });
    if (injectResult.status !== 0) {
        process.exit(injectResult.status);
    }

    // 5. trigger daemon reinit
    const reinitFile = join(CFG, 'profiles', PROFILE, '.reinit');
    writeFileSync(reinitFile, Math.floor(Date.now() / 1000).toString());
    console.log('→ reinit triggered, waiting for daemon...');

    // 6. verify
    const STAT = join(CFG, 'profiles', PROFILE, 'daemon-status.json');
    for (let i = 1; i <= 20; i++) {
        setTimeout(() => {}, 1500);
        try {
            if (existsSync(STAT)) {
                const statData = JSON.parse(readFileSync(STAT, 'utf8'));
                const auth = statData.authenticated;
                const tier = statData.tier;
                if (auth === true) {
                    console.log('✅ authenticated — tier: ' + tier);
                    process.exit(0);
                }
            }
        } catch (e) {}
    }

    console.error('⚠️  not authenticated yet. Check: tail -20 ' + join(CFG, 'daemon.log'));
    process.exit(1);
}

main();
