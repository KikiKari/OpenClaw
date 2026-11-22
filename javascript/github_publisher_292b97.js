#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "3194cbbe38edf3648c05532e5b293fcd4d2e3190f8576dac3ee6a0720004d09d", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "javascript"}
// github_publisher.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

/** Publish queued, provenance-checked artifacts without staging unrelated files. */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const child_process = require('child_process');
const https = require('https');
const http = require('http');

const LANGUAGES = new Set(["perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"]);

function sha256(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
}

function synchronizeCheckout(root, options = {}) {
    const { remote = "https://github.com/KikiKari/OpenClaw.git", branch = "gateway1-abstractions" } = options;
    
    // Resolve root path
    root = path.resolve(root);
    
    // Create temporary directory
    const tmpDir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'abstractions-snapshot-'));
    try {
        const snapshot = path.join(tmpDir, 'repo');
        
        // Clone repository
        child_process.execFileSync('git', [
            'clone', '--quiet', '--depth=1', '--single-branch',
            '--branch', branch, '--', remote, snapshot
        ], { stdio: 'pipe', timeout: 300000 });
        
        // Get revision
        const revision = child_process.execFileSync('git', [
            '-C', snapshot, 'rev-parse', 'HEAD'
        ], { encoding: 'utf8', timeout: 30000 }).trim();
        
        const counts = {};
        
        for (const language of Array.from(LANGUAGES).sort()) {
            const source = path.join(snapshot, language);
            const target = path.join(root, language);
            
            // Check for symlinks
            if (fs.existsSync(source) && fs.lstatSync(source).isSymbolicLink()) {
                throw new Error("language directory is a symlink");
            }
            if (fs.existsSync(target) && fs.lstatSync(target).isSymbolicLink()) {
                throw new Error("language directory is a symlink");
            }
            
            // Validate source directory
            if (fs.existsSync(source)) {
                const stat = fs.statSync(source);
                if (!stat.isDirectory()) {
                    throw new Error("invalid remote language directory");
                }
            }
            
            // Create target directory
            fs.mkdirSync(target, { recursive: true });
            
            // Get known files
            const known = new Set();
            const targetFiles = fs.readdirSync(target);
            for (const file of targetFiles) {
                const filePath = path.join(target, file);
                const stat = fs.statSync(filePath);
                if (stat.isFile() && !stat.isSymbolicLink()) {
                    const data = fs.readFileSync(filePath);
                    known.add(sha256(data));
                }
            }
            
            // Process source files
            let files = [];
            if (fs.existsSync(source)) {
                files = fs.readdirSync(source).map(f => path.join(source, f));
                for (const file of files) {
                    const stat = fs.statSync(file);
                    if (stat.isSymbolicLink() || !stat.isFile()) {
                        throw new Error("invalid remote abstraction");
                    }
                }
            }
            
            counts[language] = files.length;
            
            for (const item of files) {
                const data = fs.readFileSync(item);
                const digest = sha256(data);
                
                if (known.has(digest)) {
                    continue;
                }
                
                const itemName = path.basename(item);
                let destination = path.join(target, itemName);
                
                if (fs.existsSync(destination) || 
                    (fs.existsSync(destination) && fs.lstatSync(destination).isSymbolicLink())) {
                    const parsedPath = path.parse(item);
                    destination = path.join(target, 
                        `${parsedPath.name}__pool_${digest}${parsedPath.ext}`);
                }
                
                try {
                    fs.writeFileSync(destination, data, { flag: 'wx' });
                } catch (error) {
                    if (error.code === 'EEXIST') {
                        const destStat = fs.statSync(destination);
                        if (destStat.isSymbolicLink() || !destStat.isFile() || 
                            !fs.readFileSync(destination).equals(data)) {
                            throw new Error("local abstraction conflict");
                        }
                    } else {
                        throw error;
                    }
                }
                
                known.add(digest);
            }
        }
        
        return [revision, counts];
    } finally {
        // Clean up temporary directory
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
}

function updateStatusCounts(filePath, revision, counts) {
    let text = fs.readFileSync(filePath, 'utf8');
    
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
    
    rows.push(`| **gesamt** | **${Object.values(counts).reduce((a, b) => a + b, 0)}** |`, "", "");
    
    const regex = /^## Bestand\n.*?(?=^## Quellen\n)/ms;
    const match = text.match(regex);
    
    if (!match) {
        throw new Error("status inventory section missing");
    }
    
    const updated = text.replace(regex, rows.join('\n'));
    fs.writeFileSync(filePath, updated, 'utf8');
}

function queueArtifact(state, root, artifactPath) {
    root = path.resolve(root);
    const resolvedPath = path.resolve(artifactPath);
    
    if (fs.lstatSync(artifactPath).isSymbolicLink()) {
        throw new Error("artifact must not be a symlink");
    }
    
    const relative = path.relative(root, resolvedPath);
    
    if (relative !== 'STATUS.md' && 
        (!relative.split(path.sep)[0] || 
         !LANGUAGES.has(relative.split(path.sep)[0]))) {
        throw new Error("artifact is outside a language directory");
    }
    
    if (!state.ausstehende_veroeffentlichungen) {
        state.ausstehende_veroeffentlichungen = {};
    }
    
    const data = fs.readFileSync(artifactPath);
    state.ausstehende_veroeffentlichungen[relative] = sha256(data);
}

function makeRequest(options, callback) {
    const protocol = options.protocol === 'https:' ? https : http;
    const req = protocol.request(options, callback);
    return req;
}

async function publishPending(root, state, save, token, options = {}) {
    const { opener = null, sync = null } = options;
    
    const pending = state.ausstehende_veroeffentlichungen || {};
    
    if (typeof pending !== 'object' || pending === null) {
        throw new Error("invalid publication queue");
    }
    
    if (Object.keys(pending).length === 0 && sync === null) {
        return true;
    }
    
    if (!token || !token.trim()) {
        return false;
    }
    
    root = path.resolve(root);
    
    const headers = {
        "Authorization": "Bearer " + token.trim(),
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "abstractions-manager"
    };
    
    let success = true;
    const entries = Object.entries(pending).sort((a, b) => {
        return (a[0] === 'STATUS.md' ? 0 : 1) - (b[0] === 'STATUS.md' ? 0 : 1);
    });
    
    let synced = false;
    
    for (const [name, expected] of entries) {
        try {
            const fullPath = path.join(root, name);
            
            if (fs.lstatSync(fullPath).isSymbolicLink() || 
                path.relative(root, path.resolve(fullPath)) !== name) {
                throw new Error("invalid queued path");
            }
            
            const data = fs.readFileSync(fullPath);
            if (sha256(data) !== expected) {
                throw new Error("queued artifact changed");
            }
            
            if (name === 'STATUS.md' && sync !== null) {
                if (!success) {
                    throw new Error("artifact publication incomplete");
                }
                
                const [revision, counts] = sync(root);
                synced = true;
                updateStatusCounts(fullPath, revision, counts);
                
                const newData = fs.readFileSync(fullPath);
                const newExpected = sha256(newData);
                pending[name] = newExpected;
                save(state);
            }
            
            async function lookup(remoteName) {
                const encodedName = encodeURIComponent(remoteName).replace(/%2F/g, '/');
                const endpoint = `https://api.github.com/repos/KikiKari/OpenClaw/contents/${encodedName}`;
                
                return new Promise((resolve, reject) => {
                    const url = new URL(endpoint + "?ref=gateway1-abstractions");
                    const req = https.get(url, {
                        headers: headers,
                        timeout: 60000
                    }, (response) => {
                        let data = '';
                        response.on('data', chunk => data += chunk);
                        response.on('end', () => {
                            if (response.statusCode >= 200 && response.statusCode < 300) {
                                resolve([endpoint, JSON.parse(data)]);
                            } else if (response.statusCode === 404) {
                                resolve([endpoint, null]);
                            } else {
                                reject(new Error(`HTTP ${response.statusCode}: ${data}`));
                            }
                        });
                    });
                    
                    req.on('error', reject);
                    req.on('timeout', () => {
                        req.destroy();
                        reject(new Error('Request timeout'));
                    });
                });
            }
            
            function same(existing) {
                return (existing && typeof existing === 'object' && 
                       existing.encoding === "base64" &&
                       Buffer.from(existing.content || '', 'base64').equals(data));
            }
            
            const [endpoint, existing] = await lookup(name);
            
            if (name === 'STATUS.md' && existing !== null && !same(existing)) {
                const sha = existing && typeof existing === 'object' ? existing.sha : null;
                if (typeof sha !== 'string' || !sha) {
                    throw new Error('missing remote status version');
                }
                
                const body = JSON.stringify({
                    'message': 'Update abstraction status',
                    'branch': 'gateway1-abstractions',
                    'content': data.toString('base64'),
                    'sha': sha
                });
                
                await new Promise((resolve, reject) => {
                    const req = https.request(endpoint, {
                        method: 'PUT',
                        headers: {...headers, 'Content-Length': Buffer.byteLength(body)},
                        timeout: 60000
                    }, (response) => {
                        let responseData = '';
                        response.on('data', chunk => responseData += chunk);
                        response.on('end', () => {
                            if (response.statusCode >= 200 && response.statusCode < 300) {
                                resolve(JSON.parse(responseData));
                            } else {
                                reject(new Error(`HTTP ${response.statusCode}: ${responseData}`));
                            }
                        });
                    });
                    
                    req.on('error', reject);
                    req.on('timeout', () => {
                        req.destroy();
                        reject(new Error('Request timeout'));
                    });
                    
                    req.write(body);
                    req.end();
                });
            } else if (existing !== null && !same(existing)) {
                const candidate = path.parse(name);
                const alternate = path.join(candidate.dir, 
                    `${candidate.name}_${expected.substring(0, 12)}${candidate.ext}`).replace(/\\/g, '/');
                
                const [altEndpoint, altExisting] = await lookup(alternate);
                if (altExisting !== null && !same(altExisting)) {
                    throw new Error("remote artifact conflict");
                }
            }
            
            if (existing === null) {
                const body = JSON.stringify({
                    "message": "Publish script abstraction",
                    "branch": "gateway1-abstractions",
                    "content": data.toString('base64')
                });
                
                await new Promise((resolve, reject) => {
                    const req = https.request(endpoint, {
                        method: 'PUT',
                        headers: {...headers, 'Content-Length': Buffer.byteLength(body)},
                        timeout: 60000
                    }, (response) => {
                        let responseData = '';
                        response.on('data', chunk => responseData += chunk);
                        response.on('end', () => {
                            if (response.statusCode >= 200 && response.statusCode < 300) {
                                resolve(JSON.parse(responseData));
                            } else {
                                reject(new Error(`HTTP ${response.statusCode}: ${responseData}`));
                            }
                        });
                    });
                    
                    req.on('error', reject);
                    req.on('timeout', () => {
                        req.destroy();
                        reject(new Error('Request timeout'));
                    });
                    
                    req.write(body);
                    req.end();
                });
            }
            
            delete pending[name];
            save(state);
        } catch (error) {
            console.error(error);
            success = false;
        }
    }
    
    if (sync !== null && !synced) {
        try {
            sync(root);
        } catch (error) {
            console.error(error);
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
