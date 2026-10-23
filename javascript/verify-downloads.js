#!/usr/bin/env node
// verify-downloads.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:site/scripts/verify-downloads.py
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/scripts/verify-downloads.py
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

/** Verify the candidate's actual HTTP downloads against committed files. */
import fs from 'fs';
import crypto from 'crypto';
import https from 'https';
import http from 'http';
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';
import { Buffer } from 'buffer';

const require = createRequire(import.meta.url);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Simple command line argument parsing
const args = {};
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--base-url') {
    args.baseUrl = argv[++i];
  } else if (argv[i] === '--report') {
    args.report = argv[++i];
  }
}

if (!args.baseUrl || !args.report) {
  console.error('Missing required arguments');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const checksumPath = path.join(root, 'public/downloads/tiktok-live-companion-0.8.2-SHA256.txt');

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.get(url, { timeout: 30000 }, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error(`Request timeout for ${url}`));
    });
  });
}

function readFileSyncUtf8(filepath) {
  return fs.readFileSync(filepath, 'utf8');
}

function readFileSyncBinary(filepath) {
  return fs.readFileSync(filepath);
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

async function main() {
  const checksumContent = readFileSyncUtf8(checksumPath);
  const lines = checksumContent.split(/\r?\n/).filter(line => line.trim() !== '');
  const results = [];

  for (const line of lines) {
    const [expected, name] = line.split('  ');
    const url = args.baseUrl.replace(/\/$/, '') + '/downloads/' + name;
    
    const data = await fetchUrl(url);
    const actual = sha256(data);
    
    if (actual !== expected || !data.equals(readFileSyncBinary(path.join(root, 'public/downloads', name)))) {
      throw new Error('HTTP artifact mismatch: ' + name);
    }

    // Check ZIP integrity by trying to parse it
    try {
      const yauzl = require('yauzl');
      await new Promise((resolve, reject) => {
        yauzl.fromBuffer(data, { lazyEntries: true }, (err, zipfile) => {
          if (err) return reject(err);
          
          zipfile.readEntry();
          zipfile.on('entry', (entry) => {
            zipfile.readEntry(); // Continue reading entries
          });
          
          zipfile.on('end', () => resolve());
          zipfile.on('error', reject);
        });
      });
    } catch (err) {
      throw new Error('Corrupt archive: ' + name);
    }

    if (name.includes('-extension-')) {
      const AdmZip = require('adm-zip');
      const zip = new AdmZip(data);
      
      const manifestEntry = zip.getEntry('manifest.json');
      if (!manifestEntry) {
        throw new Error('Missing manifest.json in extension: ' + name);
      }
      
      const manifest = JSON.parse(manifestEntry.getData().toString('utf8'));
      if (manifest.version !== '0.8.2') {
        throw new Error('Wrong extension version');
      }
      
      const sources = ['background.js', 'content.js', 'sidepanel.js', 'sidepanel.html'];
      for (const source of sources) {
        const entry = zip.getEntry(source);
        if (!entry) {
          throw new Error(`Missing source file in extension: ${source}`);
        }
        
        const sourcePath = path.join(root, '..', 'plugin-source/browser-extension', source);
        if (!fs.existsSync(sourcePath)) {
          throw new Error(`Source file not found: ${sourcePath}`);
        }
        
        const expectedSource = readFileSyncBinary(sourcePath);
        if (!entry.getData().equals(expectedSource)) {
          throw new Error('Extension source mismatch: ' + source);
        }
      }
    }
    
    results.push({
      name: name,
      sha256: actual,
      bytes: data.length,
      verified: true
    });
  }

  const reportData = {
    base_url: args.baseUrl,
    artifacts: results
  };

  fs.writeFileSync(args.report, JSON.stringify(reportData, null, 2), 'utf8');
  console.log(JSON.stringify(results, null, 2));
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
