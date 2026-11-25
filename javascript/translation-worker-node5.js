#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "ab4e848e5f00a11b20fe7d9ffb4d9f52c31eeae9058234916b1dc09e47aa410a", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "javascript"}
// translation-worker-node5.ps1 — portiert nach javascript
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

// Validate command line argument
if (process.argv.length !== 3 || !['prepare', 'run'].includes(process.argv[2])) {
    console.error('Usage: node script.js <prepare|run>');
    process.exit(1);
}

const action = process.argv[2];

// Windows does not use chmod. The Python worker and Python 3 must already be
// installed locally; no credentials are copied or placed on a command line.
const worker = path.join(process.env.USERPROFILE, '.openclaw', 'workers', 'translation_worker.py');
const expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b';

// Check if worker file exists
if (!fs.existsSync(worker)) {
    throw new Error(`Worker missing: ${worker}`);
}

// Check if it's a symbolic link (Node.js doesn't have a direct equivalent to ReparsePoint, but we check for symbolic link)
const stats = fs.lstatSync(worker);
if (stats.isSymbolicLink()) {
    throw new Error('Worker link rejected');
}

// Calculate SHA256 hash of the worker file
const fileBuffer = fs.readFileSync(worker);
const hashSum = crypto.createHash('sha256');
hashSum.update(fileBuffer);
const actualHash = hashSum.digest('hex');

if (actualHash !== expected) {
    throw new Error('Worker checksum mismatch');
}

// Find python executable
const pythonPaths = process.env.PATH.split(path.delimiter)
    .map(dir => path.join(dir, 'python.exe'))
    .filter(p => fs.existsSync(p));

if (pythonPaths.length === 0) {
    throw new Error('Python executable not found');
}

const python = pythonPaths[0];

if (action === 'prepare') {
    console.log(`Worker verified: ${worker}`);
    process.exit(0);
}

// Execute the Python worker
try {
    const result = execFileSync(python, [worker], { stdio: 'inherit' });
    process.exit(0);
} catch (error) {
    process.exit(error.status || 1);
}
