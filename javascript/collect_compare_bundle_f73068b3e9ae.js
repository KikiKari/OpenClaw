#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "ebad215d509db515c2bf21bbef182204d731cd2307bebb9fbd1b832bfccdc6d6", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "javascript"}
// collect_compare_bundle.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
// auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const ROOT = "/home/openclaw/.openclaw";
const OUT_DIR = path.join(ROOT, "workspace", "vscode", "compare");
const TRANSFER_DIR = path.join(OUT_DIR, "transfer");
const MD_FILE = path.join(OUT_DIR, "local-gateway-config.md");
const TREE_FILE = path.join(OUT_DIR, "tree.txt");
const BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz";

const NOW_LOCAL = new Date().toLocaleString('sv-SE', { timeZoneName: 'short' }).replace(' ', 'T').replace(/CEST|CET/, match => match === 'CEST' ? 'UTC+02:00' : 'UTC+01:00');
const NOW_UTC = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const HOST = execSync('hostname -f 2>/dev/null || hostname', { encoding: 'utf8' }).trim();

const OPENCLAW_JSON = path.join(ROOT, "openclaw.json");
const EXEC_APPROVALS_JSON = path.join(ROOT, "exec-approvals.json");
const GATEWAY_SYSTEMD_ENV = path.join(ROOT, "gateway.systemd.env");
const DOT_ENV = path.join(ROOT, ".env");
const CONFIG_DIR = path.join(ROOT, ".config");
const AGENTS_DIR = path.join(ROOT, "agents");

// Create directories
fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(TRANSFER_DIR, { recursive: true });

// Check if 'tree' command exists
try {
  execSync('which tree', { stdio: 'ignore' });
} catch (error) {
  console.error("Fehler: 'tree' ist nicht installiert.");
  process.exit(1);
}

function appendFileVerbatim(label, filePath, lang = "text") {
  let content = "";
  
  content += "\n";
  content += `## ${label}\n`;
  content += "\n";
  content += `Pfad: \`${filePath}\`\n`;
  content += "\n";
  content += `\`\`\`${lang}\n`;
  
  try {
    if (fs.existsSync(filePath)) {
      content += fs.readFileSync(filePath, 'utf8');
    } else {
      content += `[FEHLT] ${filePath}\n`;
    }
  } catch (err) {
    content += `[FEHLER] ${err.message}\n`;
  }
  
  content += "\n";
  content += "```\n";
  
  fs.appendFileSync(MD_FILE, content);
}

function appendEnvVerbatim() {
  let content = "";
  
  content += "\n";
  content += "## Umgebungsvariablen (env)\n";
  content += "\n";
  content += "```text\n";
  
  for (const [key, value] of Object.entries(process.env)) {
    content += `${key}=${value}\n`;
  }
  
  content += "```\n";
  
  fs.appendFileSync(MD_FILE, content);
}

function appendDirFilesVerbatim(section, dir) {
  let content = "";
  
  content += "\n";
  content += `## ${section}\n`;
  content += "\n";
  
  if (!fs.existsSync(dir)) {
    content += `[FEHLT] ${dir}\n`;
    fs.appendFileSync(MD_FILE, content);
    return;
  }
  
  content += `Basisverzeichnis: \`${dir}\`\n`;
  fs.appendFileSync(MD_FILE, content);
  
  const files = getAllFiles(dir).sort();
  
  for (const file of files) {
    let fileContent = "";
    
    fileContent += "\n";
    fileContent += `### Datei: \`${file}\`\n`;
    fileContent += "\n";
    fileContent += "```text\n";
    
    try {
      fileContent += fs.readFileSync(file, 'utf8');
    } catch (err) {
      fileContent += `[FEHLER] ${err.message}\n`;
    }
    
    fileContent += "\n";
    fileContent += "```\n";
    
    fs.appendFileSync(MD_FILE, fileContent);
  }
}

function getAllFiles(dirPath) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  const files = entries.filter(file => !file.isDirectory()).map(file => path.join(dirPath, file.name));
  const folders = entries.filter(folder => folder.isDirectory());
  
  for (const folder of folders) {
    files.push(...getAllFiles(path.join(dirPath, folder.name)));
  }
  
  return files;
}

// Write header to MD_FILE
let headerContent = `# Lokaler Gateway-Konfigurationsstand

Generiert: ${NOW_LOCAL}
UTC: ${NOW_UTC}
Host: ${HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
`;

fs.writeFileSync(MD_FILE, headerContent);

appendFileVerbatim("openclaw.json", OPENCLAW_JSON, "json");
appendFileVerbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json");
appendFileVerbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv");
appendFileVerbatim(".env", DOT_ENV, "dotenv");
appendEnvVerbatim();
appendDirFilesVerbatim(".config (alle Dateien rekursiv)", CONFIG_DIR);
appendDirFilesVerbatim("agents (alle Dateien rekursiv)", AGENTS_DIR);

// Generate tree and backup
execSync(`tree -a -L 6 "${ROOT}" > "${TREE_FILE}"`);

execSync(`openclaw backup create --output "${BACKUP_FILE}" --verify`);
fs.copyFileSync(BACKUP_FILE, path.join(OUT_DIR, path.basename(BACKUP_FILE)));

console.log("OK");
console.log("Erzeugt:");
console.log(`- ${MD_FILE}`);
console.log(`- ${TREE_FILE}`);
console.log(`- ${BACKUP_FILE}`);
console.log(`- ${TRANSFER_DIR} (leer)`);
