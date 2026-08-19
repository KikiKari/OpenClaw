#!/usr/bin/env node
// collect_compare_bundle.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
// auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = "/home/openclaw/.openclaw";
const OUT_DIR = path.join(ROOT, "workspace", "vscode", "compare");
const TRANSFER_DIR = path.join(OUT_DIR, "transfer");
const MD_FILE = path.join(OUT_DIR, "local-gateway-config.md");
const TREE_FILE = path.join(OUT_DIR, "tree.txt");
const BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz";

const NOW_LOCAL = new Date().toLocaleString("de-DE", { timeZoneName: "short" });
const NOW_UTC = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const HOST = execSync('hostname -f 2>/dev/null || hostname', { encoding: 'utf8' }).trim();

const OPENCLAW_JSON = path.join(ROOT, "openclaw.json");
const EXEC_APPROVALS_JSON = path.join(ROOT, "exec-approvals.json");
const GATEWAY_SYSTEMD_ENV = path.join(ROOT, "gateway.systemd.env");
const DOT_ENV = path.join(ROOT, ".env");
const CONFIG_DIR = path.join(ROOT, ".config");
const AGENTS_DIR = path.join(ROOT, "agents");

// Stelle sicher, dass die Verzeichnisse existieren
fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(TRANSFER_DIR, { recursive: true });

// Prüfe ob 'tree' installiert ist
try {
  execSync('which tree', { stdio: 'ignore' });
} catch (error) {
  console.error("Fehler: 'tree' ist nicht installiert.");
  process.exit(1);
}

function appendFileVerbatim(label, filePath, lang = "text") {
  let content = `\n## ${label}\n\nPfad: \`${filePath}\`\n\n\`\`\`${lang}\n`;
  if (fs.existsSync(filePath)) {
    content += fs.readFileSync(filePath, 'utf8');
  } else {
    content += `[FEHLT] ${filePath}`;
  }
  content += `\n\`\`\``;
  fs.appendFileSync(MD_FILE, content);
}

function appendEnvVerbatim() {
  const envContent = Object.entries(process.env)
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
  
  const content = `\n## Umgebungsvariablen (env)\n\n\`\`\`text\n${envContent}\n\`\`\``;
  fs.appendFileSync(MD_FILE, content);
}

function appendDirFilesVerbatim(section, dir) {
  let content = `\n## ${section}\n\n`;
  if (!fs.existsSync(dir)) {
    content += `[FEHLT] ${dir}\n`;
    fs.appendFileSync(MD_FILE, content);
    return;
  }
  content += `Basisverzeichnis: \`${dir}\`\n`;
  fs.appendFileSync(MD_FILE, content);

  const getAllFiles = (dirPath) => {
    let files = [];
    try {
      const items = fs.readdirSync(dirPath);
      for (const item of items) {
        const fullPath = path.join(dirPath, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
          files = files.concat(getAllFiles(fullPath));
        } else {
          files.push(fullPath);
        }
      }
    } catch (err) {
      console.error(`Fehler beim Lesen von ${dirPath}:`, err.message);
    }
    return files;
  };

  const files = getAllFiles(dir).sort();
  for (const file of files) {
    let fileContent = `\n### Datei: \`${file}\`\n\n\`\`\`text\n`;
    try {
      fileContent += fs.readFileSync(file, 'utf8');
    } catch (err) {
      fileContent += `[FEHLER BEIM LESEN] ${file}: ${err.message}`;
    }
    fileContent += `\n\`\`\``;
    fs.appendFileSync(MD_FILE, fileContent);
  }
}

// Initialisiere die Markdown-Datei
const initialContent = `# Lokaler Gateway-Konfigurationsstand

Generiert: ${NOW_LOCAL}
UTC: ${NOW_UTC}
Host: ${HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.`;

fs.writeFileSync(MD_FILE, initialContent);

appendFileVerbatim("openclaw.json", OPENCLAW_JSON, "json");
appendFileVerbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json");
appendFileVerbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv");
appendFileVerbatim(".env", DOT_ENV, "dotenv");
appendEnvVerbatim();
appendDirFilesVerbatim(".config (alle Dateien rekursiv)", CONFIG_DIR);
appendDirFilesVerbatim("agents (alle Dateien rekursiv)", AGENTS_DIR);

// Erstelle Baumansicht und Backup
execSync(`tree -a -L 6 "${ROOT}" > "${TREE_FILE}"`, { stdio: 'inherit' });

execSync(`openclaw backup create --output "${BACKUP_FILE}" --verify`, { stdio: 'inherit' });

fs.copyFileSync(BACKUP_FILE, path.join(OUT_DIR, path.basename(BACKUP_FILE)));

console.log("OK");
console.log("Erzeugt:");
console.log("- " + MD_FILE);
console.log("- " + TREE_FILE);
console.log("- " + BACKUP_FILE);
console.log("- " + TRANSFER_DIR + " (leer)");
