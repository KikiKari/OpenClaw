#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "9b077f4188e9da183f29080e397ed80c92c509dba4a70a566b9e08a14ba09283", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "javascript"}
// github_publisher.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/** Publish queued, provenance-checked artifacts without staging unrelated files. */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');

function queueArtifact(state, root, filePath) {
    root = path.resolve(root);
    const resolvedPath = path.resolve(filePath);
    
    const stat = fs.lstatSync(resolvedPath);
    if (stat.isSymbolicLink()) {
        throw new Error("artifact must not be a symlink");
    }
    
    const relative = path.relative(root, resolvedPath);
    const parts = relative.split(path.sep).filter(part => part !== '');
    
    if (!parts.length || !["perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"].includes(parts[0])) {
        throw new Error("artifact is outside a language directory");
    }
    
    const fileData = fs.readFileSync(resolvedPath);
    const hash = crypto.createHash('sha256').update(fileData).digest('hex');
    
    if (!state.ausstehende_veroeffentlichungen) {
        state.ausstehende_veroeffentlichungen = {};
    }
    state.ausstehende_veroeffentlichungen[relative.split(path.sep).join('/')] = hash;
}

function publishPending(root, state, save, token, options = {}) {
    const opener = options.opener || https.request;
    
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
    
    root = path.resolve(root);
    const headers = {
        "Authorization": "Bearer " + token.trim(),
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "abstractions-manager"
    };
    
    let success = true;
    const pendingEntries = Object.entries(pending);
    
    function processNext(index) {
        if (index >= pendingEntries.length) {
            return Promise.resolve(success);
        }
        
        const [name, expected] = pendingEntries[index];
        
        return new Promise((resolve) => {
            try {
                const fullPath = path.join(root, ...name.split('/'));
                
                const stat = fs.lstatSync(fullPath);
                if (stat.isSymbolicLink()) {
                    throw new Error("invalid queued path");
                }
                
                const resolvedPath = path.resolve(fullPath);
                const relative = path.relative(root, resolvedPath).split(path.sep).join('/');
                if (relative !== name) {
                    throw new Error("invalid queued path");
                }
                
                const data = fs.readFileSync(fullPath);
                const hash = crypto.createHash('sha256').update(data).digest('hex');
                if (hash !== expected) {
                    throw new Error("queued artifact changed");
                }
                
                function lookup(remoteName) {
                    return new Promise((lookupResolve, lookupReject) => {
                        const endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + 
                            encodeURIComponent(remoteName);
                        
                        const url = new URL(endpoint + "?ref=gateway1-abstractions");
                        const requestOptions = {
                            hostname: url.hostname,
                            port: url.port,
                            path: url.pathname + url.search,
                            method: 'GET',
                            headers: headers,
                            timeout: 60000
                        };
                        
                        const req = https.request(requestOptions, (response) => {
                            let responseData = '';
                            response.on('data', chunk => responseData += chunk);
                            response.on('end', () => {
                                if (response.statusCode === 200) {
                                    try {
                                        const jsonData = JSON.parse(responseData);
                                        lookupResolve([endpoint, jsonData]);
                                    } catch (e) {
                                        lookupReject(e);
                                    }
                                } else if (response.statusCode === 404) {
                                    lookupResolve([endpoint, null]);
                                } else {
                                    lookupReject(new Error(`HTTP ${response.statusCode}: ${responseData}`));
                                }
                            });
                        });
                        
                        req.on('error', lookupReject);
                        req.on('timeout', () => {
                            req.destroy();
                            lookupReject(new Error('Request timeout'));
                        });
                        
                        req.end();
                    });
                }
                
                function same(existing) {
                    if (!existing || typeof existing !== 'object') return false;
                    if (existing.encoding !== "base64") return false;
                    
                    try {
                        const contentBuffer = Buffer.from(existing.content || "", 'base64');
                        return Buffer.compare(contentBuffer, data) === 0;
                    } catch (e) {
                        return false;
                    }
                }
                
                lookup(name)
                    .then(([endpoint, existing]) => {
                        if (existing !== null && !same(existing)) {
                            const parsedPath = path.parse(name);
                            const alternate = path.join(parsedPath.dir, parsedPath.name + "_" + expected.substring(0, 12) + parsedPath.ext);
                            
                            return lookup(alternate)
                                .then(([altEndpoint, altExisting]) => {
                                    if (altExisting !== null && !same(altExisting)) {
                                        throw new Error("remote artifact conflict");
                                    }
                                    return [altEndpoint, altExisting];
                                });
                        }
                        return [endpoint, existing];
                    })
                    .then(([endpoint, existing]) => {
                        if (existing === null) {
                            const contentBase64 = data.toString('base64');
                            const body = JSON.stringify({
                                message: "Publish script abstraction",
                                branch: "gateway1-abstractions",
                                content: contentBase64
                            });
                            
                            const url = new URL(endpoint);
                            const requestOptions = {
                                hostname: url.hostname,
                                port: url.port,
                                path: url.pathname,
                                method: 'PUT',
                                headers: {
                                    ...headers,
                                    "Content-Type": "application/json",
                                    "Content-Length": Buffer.byteLength(body)
                                },
                                timeout: 60000
                            };
                            
                            return new Promise((putResolve, putReject) => {
                                const req = https.request(requestOptions, (response) => {
                                    let responseData = '';
                                    response.on('data', chunk => responseData += chunk);
                                    response.on('end', () => {
                                        if (response.statusCode >= 200 && response.statusCode < 300) {
                                            try {
                                                JSON.parse(responseData);
                                                putResolve();
                                            } catch (e) {
                                                putReject(e);
                                            }
                                        } else {
                                            putReject(new Error(`HTTP ${response.statusCode}: ${responseData}`));
                                        }
                                    });
                                });
                                
                                req.on('error', putReject);
                                req.on('timeout', () => {
                                    req.destroy();
                                    putReject(new Error('Request timeout'));
                                });
                                
                                req.write(body);
                                req.end();
                            });
                        }
                    })
                    .then(() => {
                        delete pending[name];
                        save(state);
                        return processNext(index + 1);
                    })
                    .then(result => {
                        success = result;
                        resolve();
                    })
                    .catch(error => {
                        success = false;
                        resolve(processNext(index + 1));
                    });
            } catch (error) {
                success = false;
                resolve(processNext(index + 1));
            }
        });
    }
    
    return processNext(0).then(finalSuccess => finalSuccess);
}

module.exports = { queueArtifact, publishPending };
