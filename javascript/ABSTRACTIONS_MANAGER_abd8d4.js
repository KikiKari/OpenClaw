#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "94754dc20dd14921c4ad56526d74593f6198990b0d9a052b77d9a5e86901279a", "source_sha256": "abd8d4ba00ec9fdd77f25b23ab47e935f021988f065beaf326675ccb0ef53522", "target_language": "javascript"}
// ABSTRACTIONS_MANAGER.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

/**
 * Script Abstractions Manager
 *
 * Uebersetzt jede Quelldatei aus den drei Repositories KikiKari/OpenClaw,
 * KikiKari/Projects und KikiKari/Onboarding in zehn Zielsprachen und legt
 * das Ergebnis in den Sprachverzeichnissen des Abstraktions-Repositories ab.
 *
 * Es entstehen vollstaendige Uebersetzungen, keine Ruempfe: jede Datei geht
 * als Ganzes an ein Sprachmodell, das lauffaehigen Code in der Zielsprache
 * zurueckgibt. Erzeugnisse, deren Syntax sich nicht pruefen laesst oder die
 * erkennbar unfertig sind, werden verworfen statt abgelegt.
 *
 * Verwendung:
 *     node ABSTRACTIONS_MANAGER.js [--prioritaet high|medium|low|alle]
 *                                   [--anzahl N] [--probelauf]
 *
 * Umgebung:
 *     OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
 *     ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
 *                             /home/openclaw/.openclaw/workspace
 *     ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
 *     ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const child_process = require('child_process');
const https = require('https');
const http = require('http');
const os = require('os');
const { URL } = require('url');

// ---------------------------------------------------------------------------
// Konfiguration
// ---------------------------------------------------------------------------

const WORKSPACE = process.env.ABSTRACTIONS_WORKSPACE || '/home/openclaw/.openclaw/workspace';
const ABSTRACTIONS_REPO = path.join(WORKSPACE, 'git', 'OpenClaw-gateway1-abstractions');
const QUELLEN_DIR = path.join(WORKSPACE, 'git', 'quellen');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'abstractions-manager');
const STATE_FILE = path.join(WORKSPACE, 'db', 'abstractions_state.json');

const GITHUB_BENUTZER = "KikiKari";

// Herkunft der Quelldateien. Projects wird ueber alle Branches gelesen, weil
// dort jedes Projekt in einem eigenen verwaisten Branch liegt.
const QUELLEN = [
    {"repo": "OpenClaw",   "branches": ["main", "gateway1", "gateway2"]},
    {"repo": "Projects",   "branches": "alle"},
    {"repo": "Onboarding", "branches": ["main"]},
];

// Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
const QUELLSPRACHEN = {
    ".pl": "perl5", ".pm": "perl5",
    ".raku": "perl6", ".rakumod": "perl6",
    ".rb": "ruby", ".lua": "lua", ".go": "go",
    ".ps1": "powershell", ".psm1": "powershell",
    ".sh": "shell", ".bash": "shell",
    ".tcl": "tcl",
    ".html": "html", ".htm": "html",
    ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
    ".py": "python",
    ".css": "css",
    ".java": "java", ".c": "c", ".cpp": "cpp", ".cc": "cpp", ".cxx": "cpp",
    ".php": "php", ".fs": "fsharp", ".fsx": "fsharp",
};

// Die zehn Zielverzeichnisse, nach der Vorlage aus
// OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
// Abstraktions-Repositories.
const ZIELSPRACHEN = {
    "javascript": {"ext": ".js",  "bezeichnung": "JavaScript fuer Node 20"},
    "perl5":      {"ext": ".pl",  "bezeichnung": "Perl 5 mit use strict und use warnings"},
    "powershell": {"ext": ".ps1", "bezeichnung": "PowerShell 7"},
    "python":     {"ext": ".py",  "bezeichnung": "Python 3.12"},
    "shell":      {"ext": ".sh",  "bezeichnung": "Bash 5 mit set -euo pipefail"},
    "tcl":        {"ext": ".tcl", "bezeichnung": "Tcl 8.6"},
    "perl6":      {"ext": ".raku", "bezeichnung": "Raku"},
    "ruby":       {"ext": ".rb", "bezeichnung": "Ruby"},
    "lua":        {"ext": ".lua", "bezeichnung": "Lua"},
    "go":         {"ext": ".go", "bezeichnung": "Go"},
    "java":       {"ext": ".java", "bezeichnung": "Java"},
    "c":          {"ext": ".c", "bezeichnung": "C"},
    "cpp":        {"ext": ".cpp", "bezeichnung": "C++"},
    "php":        {"ext": ".php", "bezeichnung": "PHP"},
    "fsharp":     {"ext": ".fs", "bezeichnung": "F#"},
    "css":        {"ext": ".css", "bezeichnung": "CSS"},
};

// Verzeichnisse und Muster, die nie eingelesen werden.
const AUSSCHLUSS = [
    "node_modules/", "/.git/", "__pycache__/", "dist/", "build/", "vendor/",
    ".venv/", "site-packages/", "python-hardener-workspace/", ".artifacts/",
    "coverage/", ".next/", "target/", "/work/", "/backups/",
];
const MAX_BYTES = 200000;

// Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
// OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
// ausgeschlossen ("All providers have been ignored"), diese hier antworten.
const MODELLE = [
    "qwen/qwen3-coder",
    "deepseek/deepseek-chat-v3.1",
    "z-ai/glm-4.6",
    "mistralai/codestral-2508",
    "qwen/qwen-2.5-coder-32b-instruct",
];
const API_URL = "https://openrouter.ai/api/v1/chat/completions";
const ZEITLIMIT = 240;
const VERSUCHE = 3;

// Mindestreserven auf dem Gateway und auf den entfernten Nodes.
const GATEWAY_MIN_FREI = 40 * Math.pow(1024, 3);
const NODE_MIN_FREI = 4 * Math.pow(1024, 3);
const NODE_STATUS_MAX_ALTER_MS = 300000;

function node_speicherstatus() {
    /**Liefert nur aktuelle freie Bytes, keyed by paired device identity.*/
    try {
        const result = child_process.spawnSync("openclaw", ["nodes", "status", "--json"], {
            encoding: 'utf-8',
            timeout: 10000
        });
        if (result.error) throw result.error;
        const status = JSON.parse(result.stdout);
        const timestamp = status.ts;
        const nodes = status.nodes;
        if (typeof timestamp !== 'number' || !Array.isArray(nodes)) {
            return {};
        }
        if (Math.abs(Date.now() - timestamp) > NODE_STATUS_MAX_ALTER_MS) {
            return {};
        }
        const available = {};
        for (const node of nodes) {
            if (typeof node !== 'object' || node.connected !== true) {
                continue;
            }
            const nodeId = node.nodeId;
            const stats = node.hostStats;
            if (typeof nodeId !== 'string' || !nodeId || typeof stats !== 'object') {
                continue;
            }
            const free = stats.diskAvailableBytes;
            const updated = stats.updatedAtMs;
            if (typeof free !== 'number' || free < 0 ||
                typeof updated !== 'number' ||
                Math.abs(timestamp - updated) > NODE_STATUS_MAX_ALTER_MS) {
                continue;
            }
            available[nodeId] = free;
        }
        return available;
    } catch (error) {
        return {};
    }
}

function node_hat_reserve(node, deviceId, frei) {
    /**Unbekannte Werte sind nicht als ausreichender Speicher nachgewiesen.*/
    if (node === "node1") {
        try {
            const diskUsage = fs.statSync(WORKSPACE);
            return diskUsage.blocks * 512 >= GATEWAY_MIN_FREI;
        } catch (error) {
            return false;
        }
    }
    const wert = frei[deviceId];
    return typeof wert === 'number' && wert >= NODE_MIN_FREI;
}

// ---------------------------------------------------------------------------
// Protokoll
// ---------------------------------------------------------------------------

const logger = {
    info: (...args) => console.log(new Date().toISOString(), '| INFO    |', ...args),
    warning: (...args) => console.warn(new Date().toISOString(), '| WARNING |', ...args),
    error: (...args) => console.error(new Date().toISOString(), '| ERROR   |', ...args)
};

// ---------------------------------------------------------------------------
// Zustand
// ---------------------------------------------------------------------------

function zustand_laden() {
    /**Liest den Zustand. Er merkt sich je Quelldatei-Hash die bereits
    erzeugten Zielsprachen, damit ein erneuter Lauf nichts doppelt uebersetzt.*/
    if (fs.existsSync(STATE_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'));
        } catch (error) {
            logger.error("Zustand unlesbar (%s) — Lauf wird angehalten", error.message);
            throw error;
        }
    }
    return {"erledigt": {}, "statistik": {}};
}

function zustand_speichern(zustand) {
    /**Schreibt den Zustand atomar, damit ein Abbruch ihn nicht zerstoert.*/
    try {
        fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
        const tempPath = path.join(path.dirname(STATE_FILE), `.zustand_${Math.random().toString(36).substring(2, 15)}`);
        fs.writeFileSync(tempPath, JSON.stringify(zustand, null, 2), 'utf-8');
        fs.renameSync(tempPath, STATE_FILE);
    } catch (error) {
        logger.error("Zustand konnte nicht gespeichert werden: %s", error.message);
        throw error;
    }
}

// ---------------------------------------------------------------------------
// Quellen holen
// ---------------------------------------------------------------------------

function _git(...argumente) {
    /**Fuehrt einen Git-Befehl aus und gibt das Ergebnis zurueck, ohne zu werfen.*/
    const befehl = ["git", ...argumente];
    return child_process.spawnSync(befehl[0], befehl.slice(1), {
        encoding: 'utf-8',
        timeout: 1800000
    });
}

function _indizierter_quellbaum(spiegel, repo, branch) {
    /**Materialisiere nur erfasste Quelltypen aus genau einem Branch-Commit.*/
    const revision = _git("-C", spiegel, "rev-parse", "--verify", `refs/heads/${branch}^{commit}`);
    if (revision.status !== 0) {
        throw new Error("Branch-Commit nicht verfuegbar");
    }
    const sha = revision.stdout.trim();
    if (!/^[0-9a-f]{40}$/.test(sha)) {
        throw new Error("ungueltiger Branch-Commit");
    }
    const listing = child_process.spawnSync("git", ["-C", spiegel, "ls-tree", "-r", "-z", "--full-tree", sha], {
        encoding: 'buffer',
        timeout: 1800000
    });
    if (listing.error) throw listing.error;
    if (listing.status !== 0) throw new Error(`Git ls-tree failed: ${listing.stderr.toString()}`);
    
    const paths = [];
    const records = listing.stdout.toString('binary').split('\0');
    for (const record of records) {
        if (!record) continue;
        const parts = record.split('\t');
        if (parts.length < 2) continue;
        const metadata = parts[0];
        const filePath = parts[1];
        const metaParts = metadata.split(' ');
        if (metaParts[1] !== 'blob') continue;
        if (QUELLSPRACHEN[path.extname(filePath).toLowerCase()]) {
            paths.push(Buffer.from(filePath, 'binary'));
        }
    }
    
    const parent = path.join(QUELLEN_DIR, "indizierte-baeume", repo);
    fs.mkdirSync(parent, { recursive: true });
    const baum = fs.mkdtempSync(path.join(parent, "quelle-"));
    
    try {
        if (paths.length > 0) {
            const indexDir = fs.mkdtempSync(path.join(os.tmpdir(), "quellindex-"));
            const env = {...process.env, GIT_INDEX_FILE: path.join(indexDir, "index")};
            
            const readTreeResult = child_process.spawnSync("git", ["-C", spiegel, "read-tree", sha], {
                env: env,
                encoding: 'utf-8',
                timeout: 1800000
            });
            if (readTreeResult.error) throw readTreeResult.error;
            if (readTreeResult.status !== 0) throw new Error(`Git read-tree failed: ${readTreeResult.stderr}`);
            
            const checkoutIndexResult = child_process.spawnSync("git", ["-C", spiegel, "--work-tree", baum, "checkout-index", "--stdin", "-z", `--prefix=${baum}/`], {
                input: Buffer.concat([...paths, Buffer.from('\0')]),
                env: env,
                encoding: 'utf-8',
                timeout: 3000000
            });
            if (checkoutIndexResult.error) throw checkoutIndexResult.error;
            if (checkoutIndexResult.status !== 0) throw new Error(`Git checkout-index failed: ${checkoutIndexResult.stderr}`);
            
            fs.rmSync(indexDir, { recursive: true, force: true });
        }
        
        process.on('exit', () => {
            try {
                fs.rmSync(baum, { recursive: true, force: true });
            } catch (error) {
                // Ignore cleanup errors
            }
        });
        
        return baum;
    } catch (error) {
        try {
            fs.rmSync(baum, { recursive: true, force: true });
        } catch (cleanupError) {
            // Ignore cleanup errors
        }
        throw error;
    }
}

async function quellen_holen() {
    /**
     * Holt oder aktualisiert die Quell-Repositories und legt fuer jeden Branch
     * einen Arbeitsbaum an.
     *
     * Alle drei Repositories sind oeffentlich, es wird daher kein Token benoetigt.
     *
     * Returns:
     *     Liste aus (Repo, Branch, Pfad zum Arbeitsbaum).
     */
    fs.mkdirSync(QUELLEN_DIR, { recursive: true });
    const baeume = [];

    for (const eintrag of QUELLEN) {
        const repo = eintrag.repo;
        const spiegel = path.join(QUELLEN_DIR, `${repo}.git`);
        const url = `https://github.com/${GITHUB_BENUTZER}/${repo}.git`;

        if (!fs.existsSync(spiegel)) {
            logger.info("%s wird geholt", repo);
            const ergebnis = _git("clone", "--mirror", "--filter=blob:none", url, spiegel);
            if (ergebnis.status !== 0) {
                throw new Error(`${repo}: Quellspiegel konnte nicht geholt werden`);
            }
        } else {
            const ergebnis = _git("-C", spiegel, "remote", "update", "--prune");
            if (ergebnis.status !== 0) {
                throw new Error(`${repo}: Quellspiegel konnte nicht aktualisiert werden`);
            }
        }

        let branches;
        const gewuenscht = eintrag.branches;
        if (gewuenscht === "alle") {
            const aus = _git("-C", spiegel, "for-each-ref", "--format=%(refname:short)", "refs/heads");
            branches = aus.stdout.split('\n').filter(z => z.trim());
        } else {
            branches = [...gewuenscht];
        }

        for (const branch of branches) {
            try {
                const baum = _indizierter_quellbaum(spiegel, repo, branch);
                baeume.push([repo, branch, baum]);
            } catch (error) {
                throw new Error(`${repo}@${branch}: indizierter Checkout fehlgeschlagen: ${error.message}`);
            }
        }
    }

    // Lokale Gateway-Skripte gehören zum ursprünglichen Arbeitsumfang und
    // müssen auch dann erfasst werden, wenn der Git-Sync noch aussteht.
    if ((process.env.ABSTRACTIONS_EXECUTION || "gateway") === "gateway") {
        if (fs.existsSync(WORKSPACE) && fs.statSync(WORKSPACE).isDirectory()) {
            baeume.push(["workspace", "local", WORKSPACE]);
        }
        // CSS-Quellen ausserhalb des Workspace: gesamtes OpenClaw-Verzeichnis.
        if (fs.existsSync(path.dirname(WORKSPACE)) && fs.statSync(path.dirname(WORKSPACE)).isDirectory()) {
            baeume.push(["openclaw-css", "local", path.dirname(WORKSPACE)]);
        }
    }

    logger.info("Quellen bereit: %d Arbeitsbaeume", baeume.length);
    return baeume;
}

// ---------------------------------------------------------------------------
// Inventar
// ---------------------------------------------------------------------------

function _prioritaet(pfad, sprache) {
    /**
     * Ordnet einer Quelldatei ihre Dringlichkeit zu.
     *
     * high   Betriebsscripte — alles unterhalb eines scripts-Verzeichnisses.
     * medium uebriger ausfuehrbarer Code.
     * low    Markup und Stilvorlagen, die nur der Vollstaendigkeit halber
     *        mituebersetzt werden.
     */
    if (sprache in ("html", "css")) {
        return "low";
    }
    if (pfad.startsWith("scripts/") || pfad.includes("/scripts/")) {
        return "high";
    }
    return "medium";
}

function enthaelt_zugangsdaten(roh) {
    const muster = /(?:sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)/;
    if (muster.test(roh)) {
        return true;
    }
    for (const [name, wert] of Object.entries(process.env)) {
        if (["TOKEN", "SECRET", "PASSWORD", "API_KEY"].some(k => name.toUpperCase().includes(k)) && wert.length >= 12) {
            if (roh.includes(wert)) {
                return true;
            }
        }
    }
    return false;
}

function* css_html_dateien(baum) {
    /**Durchsucht lokale HTML-Quellen ohne ausgeschlossene Unterbaeume.*/
    const ausgeschlossen = new Set([".git", "node_modules", "__pycache__", "dist", "build", "vendor", ".venv", "site-packages", "python-hardener-workspace", ".artifacts", "coverage", ".next", "target", "work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", "secrets", "credentials", ".credentials", "private", ".private"]);
    const walkSync = function*(dir) {
        const files = fs.readdirSync(dir);
        for (const file of files) {
            const filePath = path.join(dir, file);
            const stat = fs.statSync(filePath);
            if (stat.isDirectory()) {
                if (!ausgeschlossen.has(file.toLowerCase())) {
                    yield* walkSync(filePath);
                }
            } else {
                yield filePath;
            }
        }
    };
    
    for (const filePath of walkSync(baum)) {
        if ([".html", ".htm"].includes(path.extname(filePath).toLowerCase())) {
            yield filePath;
        }
    }
}

function inventar_bauen(baeume) {
    /**
     * Erfasst alle Quelldateien und fasst inhaltsgleiche Fundstellen zusammen.
     *
     * Deduplizierung geschieht ueber den SHA-256 des Inhalts. Eine Datei, die in
     * mehreren Branches identisch vorliegt, wird genau einmal uebersetzt; alle
     * Fundstellen bleiben als Herkunft vermerkt.
     *
     * Returns:
     *     Nach Dringlichkeit und Name sortierte Liste von Eintraegen.
     */
    const dateien = {};

    for (const [repo, branch, baum] of baeume) {
        let pfade;
        if (repo === "openclaw-css") {
            pfade = css_html_dateien(baum);
        } else {
            const walkSync = function*(dir) {
                const files = fs.readdirSync(dir);
                for (const file of files) {
                    const filePath = path.join(dir, file);
                    const stat = fs.statSync(filePath);
                    if (stat.isDirectory()) {
                        yield* walkSync(filePath);
                    } else {
                        yield filePath;
                    }
                }
            };
            pfade = walkSync(baum);
        }
        
        for (const pfad of pfade) {
            try {
                if (!fs.statSync(pfad).isFile()) {
                    continue;
                }
            } catch (error) {
                continue;
            }
            
            const rel = path.relative(baum, pfad).replace(/\\/g, "/");
            
            if (repo === "openclaw-css") {
                // Dieser zusaetzliche Bestand dient ausschliesslich CSS.
                if (![".html", ".htm"].includes(path.extname(pfad).toLowerCase())) {
                    continue;
                }
                const teile = path.relative(baum, pfad).split(path.sep);
                if (teile.some(t => ["work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", "secrets", "credentials", ".credentials", "private", ".private"].includes(t.toLowerCase()))) {
                    continue;
                }
                if (teile.some((t, i) => i < teile.length - 1 && 
                    ((teile[i] === "git" && ["Abstraktionen", "OpenClaw-gateway1-abstractions", "quellen"].includes(teile[i+1]))))) {
                    continue;
                }
                try {
                    path.relative(baum, pfad);
                } catch (error) {
                    continue;
                }
            }
            
            if (repo === "workspace") {
                // Ausgaben nicht als neue Quellen erneut übersetzen; die
                // Repository-Arbeitsbäume werden separat erfasst.
                const teile = path.relative(baum, pfad).split(path.sep);
                if (teile.length >= 2 && teile[0] === "git" && 
                    ["Abstraktionen", "OpenClaw-gateway1-abstractions", "quellen"].includes(teile[1])) {
                    continue;
                }
                if (teile.some(t => ["work", "backups", "logs", "log", "db", "state", "tmp", "temp", "cache", ".cache", "artifacts", ".openclaw", "secrets", "credentials", ".credentials", "private", ".private"].includes(t.toLowerCase()))) {
                    continue;
                }
                try {
                    path.relative(baum, pfad);
                } catch (error) {
                    continue;
                }
            }
            
            if (AUSSCHLUSS.some(muster => `/${rel}`.includes(muster))) {
                continue;
            }
            
            const sprache = QUELLSPRACHEN[path.extname(pfad).toLowerCase()];
            if (sprache === undefined) {
                continue;
            }
            
            let roh;
            try {
                roh = fs.readFileSync(pfad);
            } catch (error) {
                continue;
            }
            
            if (!roh.toString().trim() || enthaelt_zugangsdaten(roh.toString())) {
                continue;
            }

            const schluessel = crypto.createHash('sha256').update(roh).digest('hex').substring(0, 16);
            let eintrag = dateien[schluessel];
            if (eintrag === undefined) {
                eintrag = {
                    "hash": schluessel,
                    "name": path.basename(pfad),
                    "stamm": path.basename(pfad, path.extname(pfad)),
                    "sprache": sprache,
                    "bytes": roh.length,
                    "pfad": pfad,
                    "herkunft": [],
                    "prioritaet": _prioritaet(rel, sprache),
                    "css_only": repo === "openclaw-css",
                };
                dateien[schluessel] = eintrag;
            } else if (repo !== "openclaw-css") {
                eintrag.css_only = false;
            }
            eintrag.herkunft.push(`${repo}@${branch}:${rel}`);
        }
    }

    const rang = {"high": 0, "medium": 1, "low": 2};
    const liste = Object.values(dateien).sort((a, b) => {
        if (rang[a.prioritaet] !== rang[b.prioritaet]) {
            return rang[a.prioritaet] - rang[b.prioritaet];
        }
        return a.name.localeCompare(b.name);
    });
    
    logger.info("Inventar: %d eindeutige Quelldateien aus %d Fundstellen",
                liste.length, liste.reduce((sum, e) => sum + e.herkunft.length, 0));
    return liste;
}

// ---------------------------------------------------------------------------
// Uebersetzung
// ---------------------------------------------------------------------------

const ANWEISUNG = `Du portierst Quellcode zwischen Programmiersprachen.

Regeln:
1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
   Erklaerung davor oder danach, keine Code-Zaeune.
2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein "hier waere",
   kein leerer Rumpf, kein Platzhalter.
3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
6. Beginne mit der passenden Shebang-Zeile.`;

const MARKUP_HINWEIS = `Das Original ist {sprache}. Erzeuge ein Programm in der
Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
nachvollziehbare Erzeugung der Struktur.`;

const CSS_HINWEIS = "Erzeuge ausschliesslich CSS aus den vorhandenen Stilinformationen des HTML-Dokuments. Erfinde keine Anwendungslogik.";

class _StilSuche {
    constructor() {
        this.gefunden = false;
        this.im_style = false;
    }

    handle_starttag(tag, attrs) {
        if (tag.toLowerCase() === "style") {
            this.im_style = true;
        }
        if (attrs.some(([k, v]) => k.toLowerCase() === "style" && v && v.trim())) {
            this.gefunden = true;
        }
    }

    handle_data(data) {
        if (this.im_style && data.trim()) {
            this.gefunden = true;
        }
    }

    handle_endtag(tag) {
        if (tag.toLowerCase() === "style") {
            this.im_style = false;
        }
    }
}

function zielsprachen_fuer(quellsprache, quelle = null) {
    /**CSS ist nur fuer HTML-Quellen vorgesehen, nicht fuer Skriptlogik.*/
    let css = quellsprache === "html";
    if (css && quelle !== null) {
        const parser = new _StilSuche();
        // Simple HTML parsing for style detection
        const styleTags = quelle.match(/<style[^>]*>[\s\S]*?<\/style>/gi) || [];
        const styleAttrs = quelle.match(/style\s*=\s*["'][^"']*["']/gi) || [];
        parser.gefunden = styleTags.length > 0 || styleAttrs.length > 0;
        css = parser.gefunden;
    }
    return Object.keys(ZIELSPRACHEN).filter(z => z !== quellsprache && (z !== "css" || css));
}

function system_anweisung(zielsprache) {
    if (["java", "c", "cpp", "php", "fsharp", "css"].includes(zielsprache)) {
        return ANWEISUNG.replace("6. Beginne mit der passenden Shebang-Zeile.",
                                 "6. Gib Quelltext im gueltigen Format der Zielsprache aus; verwende keine Shebang-Zeile.");
    }
    return ANWEISUNG;
}

function markup_hinweis(quellsprache, zielsprache) {
    if (zielsprache === "css") {
        return CSS_HINWEIS;
    }
    return ["html", "css"].includes(quellsprache) ? MARKUP_HINWEIS.replace("{sprache}", quellsprache.toUpperCase()) : "";
}

function _zaeune_entfernen(text) {
    /**Loest Code aus Markdown-Zaeunen, falls das Modell welche gesetzt hat.*/
    let zeilen = text.trim().split('\n');
    if (zeilen.length > 0 && zeilen[0].trim().startsWith("```")) {
        zeilen = zeilen.slice(1);
        while (zeilen.length > 0 && !zeilen[zeilen.length - 1].trim().startsWith("```")) {
            if (zeilen[zeilen.length - 1].trim()) {
                break;
            }
            zeilen.pop();
        }
        if (zeilen.length > 0 && zeilen[zeilen.length - 1].trim().startsWith("```")) {
            zeilen.pop();
        }
    }
    return zeilen.join('\n').trim() + '\n';
}

function _modell_code_bereinigen(text, zielsprache) {
    let code = _zaeune_entfernen(text);
    // Go source files cannot contain the shebang requested in the shared prompt.
    if (["go", "java", "c", "cpp", "fsharp", "css"].includes(zielsprache) && code.startsWith("#!")) {
        code = code.split('\n').slice(1).join('\n');
    }
    return code;
}

async function modell_fragen(quelle, quellsprache, zielsprache, name, schluessel) {
    /**
     * Laesst eine Quelldatei in die Zielsprache uebersetzen.
     *
     * Bei Fehlschlag wird mit wachsender Wartezeit wiederholt und danach auf
     * das naechste Modell der Liste ausgewichen.
     *
     * Returns:
     *     Der uebersetzte Code, oder None wenn kein Modell geantwortet hat.
     */
    const ziel = ZIELSPRACHEN[zielsprache].bezeichnung;
    let auftrag = `Portiere die folgende Datei ${name} von ${quellsprache} nach ${ziel}.\n`;
    const hinweis = markup_hinweis(quellsprache, zielsprache);
    if (hinweis) {
        auftrag += hinweis + "\n";
    }
    auftrag += `\n----- Beginn ${name} -----\n${quelle}\n----- Ende ${name} -----`;

    const modelle = process.env.ABSTRACTIONS_MODELL ? [process.env.ABSTRACTIONS_MODELL] : MODELLE;

    for (const modell of modelle) {
        for (let versuch = 1; versuch <= VERSUCHE; versuch++) {
            const body = JSON.stringify({
                "model": modell,
                "messages": [
                    {"role": "system", "content": system_anweisung(zielsprache)},
                    {"role": "user", "content": auftrag},
                ],
                "temperature": 0.1,
                "max_tokens": 8000,
            });
            
            const options = {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${schluessel}`,
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(body),
                    'HTTP-Referer': 'https://github.com/KikiKari/Projects',
                    'X-Title': 'Abstractions Manager',
                },
                timeout: ZEITLIMIT * 1000
            };
            
            try {
                const response = await new Promise((resolve, reject) => {
                    const req = https.request(new URL(API_URL), options, (res) => {
                        let data = '';
                        res.on('data', (chunk) => {
                            data += chunk;
                        });
                        res.on('end', () => {
                            resolve({statusCode: res.statusCode, data: data});
                        });
                    });
                    req.on('error', (err) => {
                        reject(err);
                    });
                    req.write(body);
                    req.end();
                });
                
                if (response.statusCode === 200) {
                    const daten = JSON.parse(response.data);
                    const inhalt = daten.choices[0].message.content;
                    if (inhalt && inhalt.trim()) {
                        return _modell_code_bereinigen(inhalt, zielsprache);
                    }
                    logger.warning("%s -> %s: leere Antwort von %s", name, zielsprache, modell);
                } else {
                    const text = response.data.substring(0, 200);
                    logger.warning("%s -> %s: HTTP %s von %s (%s)",
                                   name, zielsprache, response.statusCode, modell, text);
                    if ([400, 401, 402, 404].includes(response.statusCode)) {
                        break;
                    }
                }
            } catch (error) {
                logger.warning("%s -> %s: %s bei %s", name, zielsprache, error.constructor.name, modell);
            }
            
            await new Promise(resolve => setTimeout(resolve, Math.min(Math.pow(2, versuch) * 1000, 20000)));
        }
    }

    logger.error("%s -> %s: kein Modell hat geliefert", name, zielsprache);
    return null;
}

// ---------------------------------------------------------------------------
// Pruefung der Erzeugnisse
