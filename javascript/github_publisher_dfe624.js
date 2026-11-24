#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "5e6c24408c9d6294cd91eb21682e126009b417769c89feaab3496ad1d66c3125", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "javascript"}
// github_publisher.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

/** Publish queued, provenance-checked artifacts without staging unrelated files. */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const child_process = require('child_process');
const https = require('https');
const http = require('http');

const LANGUAGES = new Set(["perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go", "java", "c", "cpp", "php", "fsharp", "css"]);

function resolvePath(p) {
    return path.resolve(p);
}

function isFile(p) {
    try {
        return fs.statSync(p).isFile();
    } catch {
        return false;
    }
}

function isSymlink(p) {
    try {
        return fs.lstatSync(p).isSymbolicLink();
    } catch {
        return false;
    }
}

function readFileSync(p, encoding = null) {
    return fs.readFileSync(p, encoding);
}

function writeFileSync(p, data, encoding = null) {
    fs.writeFileSync(p, data, encoding);
}

function mkdirSync(p, options = {}) {
    fs.mkdirSync(p, options);
}

function readdirSync(p) {
    return fs.readdirSync(p);
}

function existsSync(p) {
    return fs.existsSync(p);
}

function rmdirSync(p) {
    fs.rmSync(p, { recursive: true, force: true });
}

function hashData(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
}

function hashFile(p) {
    return hashData(readFileSync(p));
}

async function synchronizeCheckout(root, { remote = "https://github.com/KikiKari/OpenClaw.git", branch = "gateway1-abstractions" } = {}) {
    root = resolvePath(root);
    const tmpDir = fs.mkdtempSync("abstractions-snapshot-");
    try {
        const snapshot = path.join(tmpDir, "repo");
        await new Promise((resolve, reject) => {
            const proc = child_process.spawn("git", [
                "clone", "--quiet", "--depth=1", "--single-branch",
                "--branch", branch, "--", remote, snapshot
            ], { timeout: 300000 });
            proc.on('close', (code) => {
                if (code === 0) resolve(); else reject(new Error(`git clone failed with code ${code}`));
            });
        });

        let revision;
        await new Promise((resolve, reject) => {
            const proc = child_process.execFile("git", ["-C", snapshot, "rev-parse", "HEAD"], { timeout: 30000 }, (error, stdout) => {
                if (error) reject(error); else { revision = stdout.trim(); resolve(); }
            });
        });

        const counts = {};
        const sortedLanguages = Array.from(LANGUAGES).sort();

        for (const language of sortedLanguages) {
            const source = path.join(snapshot, language);
            const target = path.join(root, language);

            if (isSymlink(source) || isSymlink(target)) {
                throw new Error("language directory is a symlink");
            }

            if (existsSync(source) && !fs.statSync(source).isDirectory()) {
                throw new Error("invalid remote language directory");
            }

            mkdirSync(target, { recursive: true });

            const known = new Set();
            for (const item of readdirSync(target)) {
                const p = path.join(target, item);
                if (isFile(p) && !isSymlink(p)) {
                    known.add(hashFile(p));
                }
            }

            let files = [];
            if (existsSync(source)) {
                files = readdirSync(source).map(item => path.join(source, item));
                if (files.some(p => isSymlink(p) || !isFile(p))) {
                    throw new Error("invalid remote abstraction");
                }
            }

            counts[language] = files.length;

            for (const item of files) {
                const data = readFileSync(item);
                const digest = hashData(data);
                if (known.has(digest)) {
                    continue;
                }

                let destination = path.join(target, path.basename(item));
                if (existsSync(destination) || isSymlink(destination)) {
                    const parsed = path.parse(destination);
                    destination = path.join(parsed.dir, `${parsed.name}__pool_${digest}${parsed.ext}`);
                }

                try {
                    writeFileSync(destination, data, { flag: 'wx' });
                } catch (error) {
                    if (error.code !== 'EEXIST') throw error;
                    if (isSymlink(destination) || !isFile(destination) || Buffer.compare(readFileSync(destination), data) !== 0) {
                        throw new Error("local abstraction conflict");
                    }
                }
                known.add(digest);
            }
        }

        return [revision, counts];
    } finally {
        rmdirSync(tmpDir);
    }
}

function updateStatusCounts(filePath, revision, counts) {
    let text = readFileSync(filePath, 'utf-8');
    const rows = [
        "## Bestand",
        "",
        `GitHub-Stand: \`${revision}\``,
        "",
        "| Zielsprache | Dateien |",
        "|---|---:|"
    ];
    
    for (const language of Array.from(LANGUAGES).sort()) {
        rows.push(`| ${language} | ${counts[language]} |`);
    }
    
    rows.push(`| **gesamt** | **${Array.from(LANGUAGES).reduce((sum, lang) => sum + (counts[lang] || 0), 0)}** |`, "", "");
    
    const pattern = /^## Bestand\n[\s\S]*?(?=^## Quellen\n)/m;
    const match = text.match(pattern);
    if (!match) {
        throw new Error("status inventory section missing");
    }
    
    const replacement = "\n" + rows.join("\n");
    text = text.replace(pattern, replacement);
    writeFileSync(filePath, text, 'utf-8');
}

function queueArtifact(state, root, filePath) {
    root = resolvePath(root);
    filePath = path.resolve(filePath);
    
    if (isSymlink(filePath)) {
        throw new Error("artifact must not be a symlink");
    }
    
    const relativePath = path.relative(root, filePath).replace(/\\/g, '/');
    if (relativePath !== 'STATUS.md' && (!relativePath.split('/').length || !LANGUAGES.has(relativePath.split('/')[0]))) {
        throw new Error("artifact is outside a language directory");
    }
    
    if (!state.ausstehende_veroeffentlichungen) {
        state.ausstehende_veroeffentlichungen = {};
    }
    
    state.ausstehende_veroeffentlichungen[relativePath] = hashFile(filePath);
}

function encodeBase64(data) {
    return Buffer.from(data).toString('base64');
}

function decodeBase64(encoded) {
    return Buffer.from(encoded, 'base64');
}

function makeRequest(options, postData = null) {
    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve({ statusCode: res.statusCode, headers: res.headers, data: JSON.parse(data) });
                } catch {
                    resolve({ statusCode: res.statusCode, headers: res.headers, data: data });
                }
            });
        });
        req.on('error', reject);
        if (postData) req.write(postData);
        req.end();
    });
}

async function publishPending(root, state, save, token, { opener = makeRequest, sync = null } = {}) {
    const pending = state.ausstehende_veroeffentlichungen || {};
    
    if (typeof pending !== 'object' || pending === null || Array.isArray(pending)) {
        throw new Error("invalid publication queue");
    }
    
    const pendingEntries = Object.entries(pending);
    if (pendingEntries.length === 0 && sync === null) {
        return true;
    }
    
    if (!token || !token.trim()) {
        return false;
    }
    
    root = resolvePath(root);
    const headers = {
        "Authorization": "Bearer " + token.trim(),
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "abstractions-manager"
    };
    
    let success = true;
    const entries = [...pendingEntries].sort((a, b) => (a[0] === 'STATUS.md' ? 0 : 1) - (b[0] === 'STATUS.md' ? 0 : 1));
    let synced = false;
    
    for (const [name, expected] of entries) {
        try {
            const filePath = path.join(root, name);
            
            if (isSymlink(filePath) || path.relative(root, resolvePath(filePath)).replace(/\\/g, '/') !== name) {
                throw new Error("invalid queued path");
            }
            
            const data = readFileSync(filePath);
            if (hashData(data) !== expected) {
                throw new Error("queued artifact changed");
            }
            
            if (name === 'STATUS.md' && sync !== null) {
                if (!success) {
                    throw new Error("artifact publication incomplete");
                }
                
                const [revision, counts] = await sync(root);
                synced = true;
                updateStatusCounts(filePath, revision, counts);
                
                const newData = readFileSync(filePath);
                const newExpected = hashData(newData);
                pending[name] = newExpected;
                save(state);
            }
            
            async function lookup(remoteName) {
                const endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + encodeURIComponent(remoteName);
                const url = new URL(endpoint + "?ref=gateway1-abstractions");
                const options = {
                    hostname: url.hostname,
                    port: url.port,
                    path: url.pathname + url.search,
                    method: 'GET',
                    headers: headers
                };
                
                try {
                    const response = await opener(options);
                    if (response.statusCode === 200) {
                        return [endpoint, response.data];
                    } else if (response.statusCode === 404) {
                        return [endpoint, null];
                    } else {
                        throw new Error(`HTTP ${response.statusCode}: ${response.data}`);
                    }
                } catch (error) {
                    if (error.statusCode === 404) {
                        return [endpoint, null];
                    }
                    throw error;
                }
            }
            
            function same(existing) {
                return (existing && typeof existing === 'object' && 
                       existing.encoding === "base64" && 
                       Buffer.compare(decodeBase64(existing.content || ""), data) === 0);
            }
            
            let [endpoint, existing] = await lookup(name);
            
            if (name === 'STATUS.md' && existing !== null && !same(existing)) {
                const sha = existing && typeof existing === 'object' ? existing.sha : null;
                if (typeof sha !== 'string' || !sha) {
                    throw new Error('missing remote status version');
                }
                
                const body = JSON.stringify({
                    message: 'Update abstraction status',
                    branch: 'gateway1-abstractions',
                    content: encodeBase64(data),
                    sha: sha
                });
                
                const url = new URL(endpoint);
                const putOptions = {
                    hostname: url.hostname,
                    port: url.port,
                    path: url.pathname,
                    method: 'PUT',
                    headers: { ...headers, 'Content-Length': Buffer.byteLength(body) }
                };
                
                const response = await opener(putOptions, body);
                if (response.statusCode < 200 || response.statusCode >= 300) {
                    throw new Error(`HTTP ${response.statusCode}: ${response.data}`);
                }
            } else if (existing !== null && !same(existing)) {
                const candidate = path.parse(name);
                const alternate = path.posix.join(candidate.dir, `${candidate.name}_${expected.substring(0, 12)}${candidate.ext}`);
                [endpoint, existing] = await lookup(alternate);
                if (existing !== null && !same(existing)) {
                    throw new Error("remote artifact conflict");
                }
            }
            
            if (existing === null) {
                const body = JSON.stringify({
                    message: "Publish script abstraction",
                    branch: "gateway1-abstractions",
                    content: encodeBase64(data)
                });
                
                const url = new URL(endpoint);
                const putOptions = {
                    hostname: url.hostname,
                    port: url.port,
                    path: url.pathname,
                    method: 'PUT',
                    headers: { ...headers, 'Content-Length': Buffer.byteLength(body) }
                };
                
                const response = await opener(putOptions, body);
                if (response.statusCode < 200 || response.statusCode >= 300) {
                    throw new Error(`HTTP ${response.statusCode}: ${response.data}`);
                }
            }
            
            delete pending[name];
            save(state);
        } catch (error) {
            success = false;
        }
    }
    
    if (sync !== null && !synced) {
        try {
            await sync(root);
        } catch {
            success = false;
        }
    }
    
    return success;
}

module.exports = {
    synchronizeCheckout,
    updateStatusCounts,
    queueArtifact,
    publishPending,
    LANGUAGES
};
