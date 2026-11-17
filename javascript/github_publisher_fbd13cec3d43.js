#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "bb98437d0d123c5a578e90ca64443b8d4070993d9c9ddd5e18462a1d72566e1d", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "javascript"}
// github_publisher.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/** Publish queued, provenance-checked artifacts without staging unrelated files. */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');

/**
 * Calculate SHA256 hash of given data
 * @param {Buffer} data 
 * @returns {string}
 */
function sha256(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Queue an artifact for publishing
 * @param {Object} state 
 * @param {string} root 
 * @param {string} artifactPath 
 */
function queueArtifact(state, root, artifactPath) {
    const resolvedRoot = path.resolve(root);
    const resolvedPath = path.resolve(artifactPath);
    
    const stat = fs.lstatSync(artifactPath);
    if (stat.isSymbolicLink()) {
        throw new Error("artifact must not be a symlink");
    }
    
    const relative = path.relative(resolvedRoot, resolvedPath);
    const parts = relative.split(path.sep).filter(p => p);
    
    if (!parts.length || ![
        "perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"
    ].includes(parts[0])) {
        throw new Error("artifact is outside a language directory");
    }
    
    if (!state.ausstehende_veroeffentlichungen) {
        state.ausstehende_veroeffentlichungen = {};
    }
    
    const data = fs.readFileSync(artifactPath);
    state.ausstehende_veroeffentlichungen[relative.replace(/\\/g, '/')] = sha256(data);
}

/**
 * Publish pending artifacts
 * @param {string} root 
 * @param {Object} state 
 * @param {Function} save 
 * @param {string} token 
 * @param {Object} options 
 * @returns {boolean}
 */
function publishPending(root, state, save, token, options = {}) {
    const opener = options.opener || httpsRequest;
    
    const pending = state.ausstehende_veroeffentlichungen || {};
    if (typeof pending !== 'object' || pending === null) {
        throw new Error("invalid publication queue");
    }
    
    if (Object.keys(pending).length === 0) {
        return true;
    }
    
    if (!token || !token.trim()) {
        return false;
    }
    
    const resolvedRoot = path.resolve(root);
    const headers = {
        "Authorization": "Bearer " + token.trim(),
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "abstractions-manager"
    };
    
    let success = true;
    const entries = Object.entries(pending);
    
    function processNext(index) {
        if (index >= entries.length) {
            return Promise.resolve(success);
        }
        
        const [name, expected] = entries[index];
        
        try {
            const fullPath = path.join(resolvedRoot, ...name.split('/'));
            const stat = fs.lstatSync(fullPath);
            
            if (stat.isSymbolicLink() || path.relative(resolvedRoot, path.resolve(fullPath)).replace(/\\/g, '/') !== name) {
                throw new Error("invalid queued path");
            }
            
            const data = fs.readFileSync(fullPath);
            if (sha256(data) !== expected) {
                throw new Error("queued artifact changed");
            }
            
            function lookup(remoteName) {
                const encodedName = encodeURIComponent(remoteName).replace(/%2F/g, '/');
                const endpoint = `https://api.github.com/repos/KikiKari/OpenClaw/contents/${encodedName}`;
                
                const options = {
                    hostname: 'api.github.com',
                    path: `/repos/KikiKari/OpenClaw/contents/${encodedName}?ref=gateway1-abstractions`,
                    headers: headers,
                    method: 'GET'
                };
                
                return opener(options, null, 60000)
                    .then(response => [endpoint, response])
                    .catch(error => {
                        if (error.statusCode === 404) {
                            return [endpoint, null];
                        }
                        throw error;
                    });
            }
            
            function same(existing) {
                return (existing && typeof existing === 'object' && existing.encoding === "base64" &&
                       Buffer.from(existing.content || "", 'base64').equals(data));
            }
            
            return lookup(name)
                .then(([endpoint, existing]) => {
                    if (existing !== null && !same(existing)) {
                        const parsed = path.parse(name);
                        const dir = parsed.dir ? parsed.dir.replace(/\\/g, '/') : '';
                        const baseName = parsed.name;
                        const ext = parsed.ext;
                        const alternate = dir ? `${dir}/${baseName}_${expected.substring(0, 12)}${ext}` : `${baseName}_${expected.substring(0, 12)}${ext}`;
                        
                        return lookup(alternate)
                            .then(([altEndpoint, altExisting]) => {
                                if (altExisting !== null && !same(altExisting)) {
                                    throw new Error("remote artifact conflict");
                                }
                                return [altEndpoint, altExisting, alternate];
                            });
                    }
                    return [endpoint, existing, name];
                })
                .then(([endpoint, existing, targetName]) => {
                    if (existing === null) {
                        const body = JSON.stringify({
                            message: "Publish script abstraction",
                            branch: "gateway1-abstractions",
                            content: data.toString('base64')
                        });
                        
                        const putOptions = {
                            hostname: 'api.github.com',
                            path: `/repos/KikiKari/OpenClaw/contents/${encodeURIComponent(targetName).replace(/%2F/g, '/')}`,
                            headers: {
                                ...headers,
                                "Content-Type": "application/json",
                                "Content-Length": Buffer.byteLength(body)
                            },
                            method: 'PUT'
                        };
                        
                        return opener(putOptions, body, 60000)
                            .then(() => {
                                delete pending[name];
                                save(state);
                            });
                    } else {
                        delete pending[name];
                        save(state);
                        return Promise.resolve();
                    }
                })
                .then(() => processNext(index + 1))
                .catch(error => {
                    success = false;
                    return processNext(index + 1);
                });
                
        } catch (error) {
            success = false;
            return processNext(index + 1);
        }
    }
    
    // Execute sequentially to maintain order and avoid race conditions
    return processNext(0).then(finalSuccess => finalSuccess);
}

/**
 * Make HTTPS request
 * @param {Object} options 
 * @param {string|null} postData 
 * @param {number} timeout 
 * @returns {Promise<Object>}
 */
function httpsRequest(options, postData, timeout) {
    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            
            res.on('data', chunk => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(JSON.parse(data));
                    } else {
                        const error = new Error(`HTTP ${res.statusCode}: ${res.statusMessage}`);
                        error.statusCode = res.statusCode;
                        reject(error);
                    }
                } catch (parseError) {
                    reject(parseError);
                }
            });
        });
        
        req.on('error', reject);
        
        if (timeout) {
            req.setTimeout(timeout, () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });
        }
        
        if (postData) {
            req.write(postData);
        }
        
        req.end();
    });
}

module.exports = {
    queueArtifact,
    publishPending
};
