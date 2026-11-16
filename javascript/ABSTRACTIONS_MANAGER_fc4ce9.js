#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "c512b279c8078a95337420a41bf36516a6c0260a66be4c16fb83538eb77193cc", "source_sha256": "fc4ce94d8389188be8aa35f040d616ca2baa44095f057fa78606f347d342ff4b", "target_language": "javascript"}
// ABSTRACTIONS_MANAGER.py — portiert nach javascript
// Quelle: python, workspace@local:git/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const { URL } = require('url');
const https = require('https');
const { setTimeout } = require('timers/promises');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const WORKSPACE = process.env.ABSTRACTIONS_WORKSPACE || '/home/openclaw/.openclaw/workspace';
const ABSTRACTIONS_REPO = path.join(WORKSPACE, 'git', 'OpenClaw-gateway1-abstractions');
const QUELLEN_DIR = path.join(WORKSPACE, 'git', 'quellen');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'abstractions-manager');
const STATE_FILE = path.join(WORKSPACE, 'db', 'abstractions_state.json');

const GITHUB_BENUTZER = 'KikiKari';

// Source repositories and branches
const QUELLEN = [
    { repo: 'OpenClaw', branches: ['main', 'gateway1', 'gateway2'] },
    { repo: 'Projects', branches: 'alle' },
    { repo: 'Onboarding', branches: ['main'] },
];

// File extensions to source languages
const QUELLSPRACHEN = {
    '.pl': 'perl5', '.pm': 'perl5',
    '.ps1': 'powershell', '.psm1': 'powershell',
    '.sh': 'shell', '.bash': 'shell',
    '.tcl': 'tcl',
    '.html': 'html', '.htm': 'html',
    '.js': 'javascript', '.mjs': 'javascript', '.cjs': 'javascript',
    '.py': 'python',
    '.css': 'css',
};

// Target languages and their details
const ZIELSPRACHEN = {
    'javascript': { ext: '.js', bezeichnung: 'JavaScript fuer Node 20' },
    'perl5': { ext: '.pl', bezeichnung: 'Perl 5 mit use strict und use warnings' },
    'powershell': { ext: '.ps1', bezeichnung: 'PowerShell 7' },
    'python': { ext: '.py', bezeichnung: 'Python 3.12' },
    'shell': { ext: '.sh', bezeichnung: 'Bash 5 mit set -euo pipefail' },
    'tcl': { ext: '.tcl', bezeichnung: 'Tcl 8.6' },
};

// Directories and patterns to exclude
const AUSSCHLUSS = [
    'node_modules/', '/.git/', '__pycache__/', 'dist/', 'build/', 'vendor/',
    '.venv/', 'site-packages/', 'python-hardener-workspace/', '.artifacts/',
    'coverage/', '.next/', 'target/',
];
const MAX_BYTES = 200000;

// Fallback models
const MODELLE = [
    'qwen/qwen3-coder',
    'deepseek/deepseek-chat-v3.1',
    'z-ai/glm-4.6',
    'mistralai/codestral-2508',
    'qwen/qwen-2.5-coder-32b-instruct',
];
const API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const ZEITLIMIT = 240;
const VERSUCHE = 3;

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

function _protokoll() {
    const log = {
        info: (message, ...args) => console.log(`INFO: ${message}`, ...args),
        warning: (message, ...args) => console.warn(`WARNING: ${message}`, ...args),
        error: (message, ...args) => console.error(`ERROR: ${message}`, ...args),
    };

    try {
        if (!fs.existsSync(LOG_DIR)) {
            fs.mkdirSync(LOG_DIR, { recursive: true });
        }
        const logFile = path.join(LOG_DIR, 'manager.log');
        const logStream = fs.createWriteStream(logFile, { flags: 'a' });
        const originalLog = console.log;
        console.log = function(message, ...args) {
            logStream.write(`${new Date().toISOString()} | ${message}\n`, ...args);
            originalLog.apply(console, [message, ...args]);
        };
    } catch (error) {
        log.warning(`Log file not available (${error.message}) — only logging to stdout`);
    }

    return log;
}

const logger = _protokoll();

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

function zustand_laden() {
    if (fs.existsSync(STATE_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
        } catch (error) {
            logger.warning(`State unreadable (${error.message}) — starting fresh`);
        }
    }
    return { erledigt: {}, statistik: {} };
}

function zustand_speichern(zustand) {
    try {
        if (!fs.existsSync(path.dirname(STATE_FILE))) {
            fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
        }
        const tempFile = path.join(path.dirname(STATE_FILE), `.zustand_${Date.now()}`);
        fs.writeFileSync(tempFile, JSON.stringify(zustand, null, 1), 'utf8');
        fs.renameSync(tempFile, STATE_FILE);
    } catch (error) {
        logger.error(`State could not be saved: ${error.message}`);
    }
}

// ---------------------------------------------------------------------------
// Fetch Sources
// ---------------------------------------------------------------------------

function _git(args, directory = null) {
    const command = directory ? `git -C ${directory} ${args}` : `git ${args}`;
    try {
        return { stdout: execSync(command, { encoding: 'utf8' }), stderr: '', returncode: 0 };
    } catch (error) {
        return { stdout: '', stderr: error.stderr, returncode: error.status };
    }
}

function quellen_holen() {
    if (!fs.existsSync(QUELLEN_DIR)) {
        fs.mkdirSync(QUELLEN_DIR, { recursive: true });
    }
    const baeume = [];

    for (const eintrag of QUELLEN) {
        const repo = eintrag.repo;
        const spiegel = path.join(QUELLEN_DIR, `${repo}.git`);
        const url = `https://github.com/${GITHUB_BENUTZER}/${repo}.git`;

        if (!fs.existsSync(spiegel)) {
            logger.info(`${repo} wird geholt`);
            const ergebnis = _git(`clone --mirror --filter=blob:none ${url} ${spiegel}`);
            if (ergebnis.returncode !== 0) {
                logger.error(`${repo} konnte nicht geholt werden: ${ergebnis.stderr.trim().substring(0, 200)}`);
                continue;
            }
        } else {
            const ergebnis = _git('remote update --prune', spiegel);
            if (ergebnis.returncode !== 0) {
                logger.warning(`${repo} konnte nicht aktualisiert werden: ${ergebnis.stderr.trim().substring(0, 200)}`);
            }
        }

        let branches = eintrag.branches;
        if (branches === 'alle') {
            const aus = _git('for-each-ref --format=%(refname:short) refs/heads', spiegel);
            branches = aus.stdout.split('\n').map(z => z.trim()).filter(z => z);
        }

        for (const branch of branches) {
            const baum = path.join(QUELLEN_DIR, 'baeume', repo, branch.replace(/\//g, '_'));
            if (!fs.existsSync(baum)) {
                fs.mkdirSync(baum, { recursive: true });
            }
            const ergebnis = _git(`--work-tree ${baum} checkout -f ${branch} -- .`, spiegel);
            if (ergebnis.returncode !== 0) {
                logger.warning(`${repo}@${branch}: Arbeitsbaum fehlgeschlagen: ${ergebnis.stderr.trim().substring(0, 160)}`);
                continue;
            }
            baeume.push([repo, branch, baum]);
        }
    }

    logger.info(`Quellen bereit: ${baeume.length} Arbeitsbaeume`);
    return baeume;
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

function _prioritaet(pfad, sprache) {
    if (sprache === 'html' || sprache === 'css') {
        return 'low';
    }
    if (pfad.startsWith('scripts/') || pfad.includes('/scripts/')) {
        return 'high';
    }
    return 'medium';
}

function inventar_bauen(baeume) {
    const dateien = {};

    for (const [repo, branch, baum] of baeume) {
        const files = fs.readdirSync(baum, { withFileTypes: true });
        for (const file of files) {
            if (!file.isFile()) continue;
            const pfad = path.join(baum, file.name);
            const rel = path.relative(baum, pfad).replace(/\\/g, '/');
            if (AUSSCHLUSS.some(muster => rel.includes(muster))) continue;
            const sprache = QUELLSPRACHEN[path.extname(pfad).toLowerCase()];
            if (!sprache) continue;
            try {
                const roh = fs.readFileSync(pfad);
                if (!roh.toString().trim() || roh.length > MAX_BYTES) continue;
                const schluessel = crypto.createHash('sha256').update(roh).digest('hex').substring(0, 16);
                let eintrag = dateien[schluessel];
                if (!eintrag) {
                    eintrag = {
                        hash: schluessel,
                        name: path.basename(pfad),
                        stamm: path.parse(pfad).name,
                        sprache: sprache,
                        bytes: roh.length,
                        pfad: pfad,
                        herkunft: [],
                        prioritaet: _prioritaet(rel, sprache),
                    };
                    dateien[schluessel] = eintrag;
                }
                eintrag.herkunft.push(`${repo}@${branch}:${rel}`);
            } catch (error) {
                continue;
            }
        }
    }

    const rang = { high: 0, medium: 1, low: 2 };
    const liste = Object.values(dateien).sort((a, b) => rang[a.prioritaet] - rang[b.prioritaet] || a.name.localeCompare(b.name));
    logger.info(`Inventar: ${liste.length} eindeutige Quelldateien aus ${liste.reduce((sum, e) => sum + e.herkunft.length, 0)} Fundstellen`);
    return liste;
}

// ---------------------------------------------------------------------------
// Translation
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

function _zaeune_entfernen(text) {
    const zeilen = text.trim().split('\n');
    if (zeilen.length > 0 && zeilen[0].trim().startsWith('```')) {
        zeilen.shift();
        while (zeilen.length > 0 && !zeilen[zeilen.length - 1].trim().startsWith('```')) {
            if (zeilen[zeilen.length - 1].trim()) break;
            zeilen.pop();
        }
        if (zeilen.length > 0 && zeilen[zeilen.length - 1].trim().startsWith('```')) {
            zeilen.pop();
        }
    }
    return zeilen.join('\n').trim() + '\n';
}

async function modell_fragen(quelle, quellsprache, zielsprache, name, schluessel) {
    const ziel = ZIELSPRACHEN[zielsprache].bezeichnung;
    let auftrag = `Portiere die folgende Datei ${name} von ${quellsprache} nach ${ziel}.\n`;
    if (quellsprache === 'html' || quellsprache === 'css') {
        auftrag += MARKUP_HINWEIS.replace('{sprache}', quellsprache.toUpperCase()) + '\n';
    }
    auftrag += `\n----- Beginn ${name} -----\n${quelle}\n----- Ende ${name} -----`;

    const modelle = process.env.ABSTRACTIONS_MODELL ? [process.env.ABSTRACTIONS_MODELL] : MODELLE;

    for (const modell of modelle) {
        for (let versuch = 1; versuch <= VERSUCHE; versuch++) {
            const rumpf = JSON.stringify({
                model: modell,
                messages: [
                    { role: 'system', content: ANWEISUNG },
                    { role: 'user', content: auftrag },
                ],
                temperature: 0.1,
                max_tokens: 8000,
            });

            const options = {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${schluessel}`,
                    'Content-Type': 'application/json',
                    'HTTP-Referer': 'https://github.com/KikiKari/Projects',
                    'X-Title': 'Abstractions Manager',
                },
            };

            try {
                const response = await new Promise((resolve, reject) => {
                    const req = https.request(new URL(API_URL), options, (res) => {
                        let data = '';
                        res.on('data', (chunk) => data += chunk);
                        res.on('end', () => resolve({ statusCode: res.statusCode, data }));
                    });
                    req.on('error', reject);
                    req.write(rumpf);
                    req.end();
                });

                if (response.statusCode !== 200) {
                    logger.warning(`${name} -> ${zielsprache}: HTTP ${response.statusCode} von ${modell} (${response.data.substring(0, 200)})`);
                    if ([400, 401, 402, 404].includes(response.statusCode)) break;
                    continue;
                }

                const daten = JSON.parse(response.data);
                const inhalt = daten.choices[0].message.content;
                if (inhalt && inhalt.trim()) {
                    return _zaeune_entfernen(inhalt);
                }
                logger.warning(`${name} -> ${zielsprache}: leere Antwort von ${modell}`);
            } catch (error) {
                logger.warning(`${name} -> ${zielsprache}: ${error.name} bei ${modell}`);
            }

            await setTimeout(Math.min(2 ** versuch, 20) * 1000);
        }
    }

    logger.error(`${name} -> ${zielsprache}: kein Modell hat geliefert`);
    return null;
}

// ---------------------------------------------------------------------------
// Check Generated Code
// ---------------------------------------------------------------------------

const PRUEFBEFEHLE = {
    'javascript': ['node', '--check'],
    'perl5': ['perl', '-c'],
    'powershell': ['pwsh', '-NoProfile', '-Command'],
    'shell': ['bash', '-n'],
    'tcl': ['tclsh'],
};

const VERDACHT = ['TODO: Implementiere', 'TODO: implement', 'not implemented', 'hier waere', 'Platzhalter', 'your code here', 'pass  # TODO'];

function erzeugnis_pruefen(code, zielsprache, quelle = '') {
    const quellzeilen = quelle.split('\n').length;
    const zeilen = code.trim().split('\n').filter(z => z.trim()).length;
    const mindestens = Math.max(2, Math.min(6, Math.floor(quellzeilen / 3))) || 5;
    if (zeilen < mindestens) {
        return [false, `zu kurz (${zeilen} statt mindestens ${mindestens} Zeilen)`];
    }

    const niedrig = quelle.toLowerCase();
    for (const muster of VERDACHT) {
        if (code.toLowerCase().includes(muster.toLowerCase()) && !niedrig.includes(muster.toLowerCase())) {
            return [false, `unfertig (${muster})`];
        }
    }

    if (zielsprache === 'python') {
        try {
            new Function(code);
            return [true, 'syntax ok'];
        } catch (error) {
            return [false, `Syntaxfehler Zeile ${error.lineNumber}`];
        }
    }

    const befehl = PRUEFBEFEHLE[zielsprache];
    if (!befehl) {
        return [true, 'ohne Syntaxpruefung angenommen'];
    }

    const endung = ZIELSPRACHEN[zielsprache].ext;
    try {
        const tempFile = path.join(os.tmpdir(), `temp${endung}`);
        fs.writeFileSync(tempFile, code, 'utf8');
        let aufruf;
        if (zielsprache === 'powershell') {
            aufruf = [...befehl, `$null = [ScriptBlock]::Create((Get-Content -Raw '${tempFile}'))`];
        } else if (zielsprache === 'tcl') {
            aufruf = ['tclsh'];
            const ergebnis = execSync(`if {[catch {info complete [read [open ${tempFile}]]}]} {exit 1}`, { encoding: 'utf8' });
            fs.unlinkSync(tempFile);
            return [ergebnis.returncode === 0, ergebnis.returncode === 0 ? 'syntax ok' : 'Syntaxfehler'];
        } else {
            aufruf = [...befehl, tempFile];
        }
        const ergebnis = execSync(aufruf.join(' '), { encoding: 'utf8' });
        fs.unlinkSync(tempFile);
        if (ergebnis.returncode === 0) {
            return [true, 'syntax ok'];
        }

        const meldung = (ergebnis.stderr || ergebnis.stdout).trim();
        if (meldung.includes("Can't locate") || meldung.includes('Cannot find module')) {
            return [true, 'Fremdmodul fehlt hier — Syntax nicht abschliessend geprueft'];
        }
        const erste = meldung.split('\n')[0].substring(0, 90) || 'unbekannt';
        return [false, `Syntaxfehler: ${erste}`];
    } catch (error) {
        if (error.code === 'ENOENT') {
            try {
                fs.unlinkSync(tempFile);
            } catch (e) {}
            return [true, 'Interpreter fehlt — ohne Syntaxpruefung angenommen'];
        }
        return [true, 'Pruefung nicht moeglich — angenommen'];
    }
}

// ---------------------------------------------------------------------------
// Save
// ---------------------------------------------------------------------------

function _zieldatei(eintrag, zielsprache, belegt) {
    const endung = ZIELSPRACHEN[zielsprache].ext;
    let stamm = eintrag.stamm;
    const schluessel = `${zielsprache}/${stamm}`;
    const vorher = belegt[schluessel];
    if (vorher !== undefined && vorher !== eintrag.hash) {
        stamm = `${stamm}_${eintrag.hash.substring(0, 6)}`;
    } else {
        belegt[schluessel] = eintrag.hash;
    }
    return path.join(ABSTRACTIONS_REPO, zielsprache, `${stamm}${endung}`);
}

function _kopf(eintrag, zielsprache) {
    const zeichen = zielsprache === 'javascript' ? '//' : '#';
    const heute = new Date().toISOString().split('T')[0];
    const zeilen = [
        `${zeichen} ${eintrag.name} — portiert nach ${zielsprache}`,
        `${zeichen} Quelle: ${eintrag.sprache}, ${eintrag.herkunft[0]}`,
    ];
    for (let i = 1; i < Math.min(eintrag.herkunft.length, 4); i++) {
        zeilen.push(`${zeichen} auch in: ${eintrag.herkunft[i]}`);
    }
    if (eintrag.herkunft.length > 4) {
        zeilen.push(`${zeichen} auch in: ${eintrag.herkunft.length - 4} weiteren Fundstellen`);
    }
    zeilen.push(`${zeichen} Erzeugt: ${heute} durch ABSTRACTIONS_MANAGER.py`);
    return zeilen.join('\n') + '\n';
}

function ablegen(eintrag, zielsprache, code, belegt) {
    const ziel = _zieldatei(eintrag, zielsprache, belegt);
    try {
        if (!fs.existsSync(path.dirname(ziel))) {
            fs.mkdirSync(path.dirname(ziel), { recursive: true });
        }
        const zeilen = code.split('\n');
        let inhalt;
        if (zeilen.length > 0 && zeilen[0].startsWith('#!')) {
            inhalt = zeilen[0] + '\n' + _kopf(eintrag, zielsprache) + '\n' + zeilen.slice(1).join('\n').replace(/^\n/, '') + '\n';
        } else {
            inhalt = _kopf(eintrag, zielsprache) + '\n' + code;
        }
        const tempFile = path.join(path.dirname(ziel), `.neu_${Date.now()}${ZIELSPRACHEN[zielsprache].ext}`);
        fs.writeFileSync(tempFile, inhalt, 'utf8');
        fs.renameSync(tempFile, ziel);
        return ziel;
    } catch (error) {
        logger.error(`${ziel} konnte nicht abgelegt werden: ${error.message}`);
        return null;
    }
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

async function uebersetzen(inventar, zustand, prioritaet, anzahl, probelauf, schluessel) {
    const zaehler = { erzeugt: 0, uebersprungen: 0, verworfen: 0, dateien: 0 };
    const belegt = {};
    const erledigt = zustand.erledigt || {};

    const offen = inventar.filter(e => prioritaet === 'alle' || e.prioritaet === prioritaet);
    logger.info(`Prioritaet ${prioritaet}: ${offen.length} Quelldateien im Bestand`);

    for (const eintrag of offen) {
        if (zaehler.dateien >= anzahl) {
            logger.info(`Kontingent von ${anzahl} Quelldateien erreicht`);
            break;
        }

        const fertig = new Set(erledigt[eintrag.hash] || []);
        const ziele = Object.keys(ZIELSPRACHEN).filter(z => z !== eintrag.sprache && !fertig.has(z));
        if (ziele.length === 0) continue;

        try {
            const quelle = fs.readFileSync(eintrag.pfad, 'utf8');
            zaehler.dateien += 1;
            logger.info(`[${eintrag.prioritaet}] ${eintrag.name} (${eintrag.sprache}, ${eintrag.bytes} B) -> ${ziele.join(', ')}`);

            for (const zielsprache of ziele) {
                if (probelauf) {
                    logger.info(`  ${zielsprache}: Probelauf, nichts gesendet`);
                    zaehler.uebersprungen += 1;
                    continue;
                }

                const code = await modell_fragen(quelle, eintrag.sprache, zielsprache, eintrag.name, schluessel);
                if (code === null) {
                    zaehler.verworfen += 1;
                    continue;
                }

                const [angenommen, grund] = erzeugnis_pruefen(code, zielsprache, quelle);
                if (!angenommen) {
                    logger.warning(`  ${zielsprache}: verworfen — ${grund}`);
                    zaehler.verworfen += 1;
                    continue;
                }

                const ziel = ablegen(eintrag, zielsprache, code, belegt);
                if (ziel === null) {
                    zaehler.verworfen += 1;
                    continue;
                }

                logger.info(`  ${zielsprache}: ${path.basename(ziel)} (${grund})`);
                zaehler.erzeugt += 1;
                fertig.add(zielsprache);
            }

            erledigt[eintrag.hash] = Array.from(fertig).sort();
        } catch (error) {
            logger.warning(`${eintrag.name} nicht lesbar: ${error.message}`);
            continue;
        }
    }

    return zaehler;
}

// ---------------------------------------------------------------------------
// Report and Publish
// ---------------------------------------------------------------------------

function bericht_schreiben(inventar, zustand, zaehler) {
    if (!fs.existsSync(ABSTRACTIONS_REPO)) {
        logger.warning(`Abstraktions-Repository fehlt: ${ABSTRACTIONS_REPO}`);
        return;
    }

    const je_sprache = {};
    for (const sprache of Object.keys(ZIELSPRACHEN)) {
        const verzeichnis = path.join(ABSTRACTIONS_REPO, sprache);
        je_sprache[sprache] = fs.existsSync(verzeichnis) ? fs.readdirSync(verzeichnis).filter(p => fs.statSync(path.join(verzeichnis, p)).isFile()).length : 0;
    }

    const rang = { high: 0, medium: 1, low: 2 };
    const je_prio = {};
    for (const p of Object.keys(rang)) {
        je_prio[p] = inventar.filter(e => e.prioritaet === p).length;
    }
    const erledigt = zustand.erledigt || {};
    const offen = inventar.reduce((sum, e) => sum + (Object.keys(ZIELSPRACHEN).filter(z => z !== e.sprache).length - (erledigt[e.hash] || []).length), 0);

    const zeilen = [
        '# Script Abstractions — Status',
        '',
        `**Letzter Lauf:** ${new Date().toISOString().replace('T', ' ').split('.')[0]} UTC`,
        '',
        'Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.',
        'Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige',
        'Syntax oder mit Platzhaltern werden verworfen.',
        '',
        '## Bestand',
        '',
        '| Zielsprache | Dateien |',
        '|---|---:|',
    ];
    for (const [s, a] of Object.entries(je_sprache).sort()) {
        zeilen.push(`| ${s} | ${a} |`);
    }
    zeilen.push(`| **gesamt** | **${Object.values(je_sprache).reduce((a, b) => a + b, 0)}** |`);
    zeilen.push('', '## Quellen', '', '| Prioritaet | Quelldateien | Bedeutung |', '|---|---:|---|');
    for (const [p, b] of Object.entries(je_prio)) {
        let bedeutung;
        if (p === 'high') bedeutung = 'Betriebsscripte aus scripts-Verzeichnissen';
        else if (p === 'medium') bedeutung = 'uebriger ausfuehrbarer Code';
        else if (p === 'low') bedeutung = 'Markup und Stilvorlagen';
        zeilen.push(`| ${p} | ${b} | ${bedeutung} |`);
    }
    zeilen.push(`| **gesamt** | **${inventar.length}** | nach Inhalt dedupliziert |`, '', `Noch offene Sprachpaare: **${offen}**`, '', '## Letzter Lauf', '', `- bearbeitete Quelldateien: ${zaehler.dateien}`, `- erzeugte Uebersetzungen: ${zaehler.erzeugt}`, `- verworfen: ${zaehler.verworfen}`, '', '## Herkunft', '', '- `KikiKari/OpenClaw` — main, gateway1, gateway2', '- `KikiKari/Projects` — alle Branches', '- `KikiKari/Onboarding` — main', '', 'Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.', '');

    try {
        fs.writeFileSync(path.join(ABSTRACTIONS_REPO, 'STATUS.md'), zeilen.join('\n'), 'utf8');
        logger.info('STATUS.md fortgeschrieben');
    } catch (error) {
        logger.error(`STATUS.md konnte nicht geschrieben werden: ${error.message}`);
    }
}

function veroeffentlichen(nachricht) {
    if (!fs.existsSync(path.join(ABSTRACTIONS_REPO, '.git'))) {
        logger.info(`Kein Git-Arbeitsbaum in ${ABSTRACTIONS_REPO} — nichts zu veroeffentlichen`);
        return;
    }

    const stand = _git('status --porcelain', ABSTRACTIONS_REPO);
    if (!stand.stdout.trim()) {
        logger.info('Keine Aenderungen zu veroeffentlichen');
        return;
    }

    for (const sprache of Object.keys(ZIELSPRACHEN)) {
        _git(`add ${sprache}`, ABSTRACTIONS_REPO);
    }
    _git('add STATUS.md', ABSTRACTIONS_REPO);

    const ergebnis = _git(`commit -m "${nachricht}"`, ABSTRACTIONS_REPO);
    if (ergebnis.returncode !== 0) {
        logger.warning(`Commit fehlgeschlagen: ${(ergebnis.stderr || ergebnis.stdout).trim().substring(0, 200)}`);
        return;
    }
    logger.info(`Commit gesetzt: ${nachricht}`);

    const token = process.env.GITHUB_TOKEN || process.env.ABSTRACTIONS_PUSH_TOKEN;
    if (!token) {
        logger.info('Kein Token in der Umgebung — Commit bleibt lokal');
        return;
    }

    const url = `https://x-access-token:${token}@github.com/${GITHUB_BENUTZER}/OpenClaw.git`;
    const pushErgebnis = _git(`push ${url} HEAD:gateway1-abstractions`, ABSTRACTIONS_REPO);
    if (pushErgebnis.returncode === 0) {
        logger.info('Nach OpenClaw@gateway1-abstractions veroeffentlicht');
    } else {
        logger.error(`Push fehlgeschlagen: ${(pushErgebnis.stderr || '').replace(token, '***').substring(0, 200)}`);
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
    const args = process.argv.slice(2);
    const argumente = { prioritaet: null, anzahl: parseInt(process.env.ABSTRACTIONS_ANZAHL || '40'), probelauf: false };

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--prioritaet' && i + 1 < args.length) {
            argumente.prioritaet = args[i + 1];
            i++;
        } else if (args[i] === '--anzahl' && i + 1 < args.length) {
            argumente.anzahl = parseInt(args[i + 1]);
            i++;
        } else if (args[i] === '--probelauf') {
            argumente.probelauf = true;
        }
    }

    logger.info(`Abstractions Manager gestartet — Arbeitsverzeichnis ${WORKSPACE}`);

    const schluessel = (process.env.OPENROUTER_API_KEY || '').trim();
    if (!argumente.probelauf) {
        if (!schluessel) {
            logger.error('OPENROUTER_API_KEY ist leer oder besteht nur aus Leerraum — ohne Schluessel keine Uebersetzung');
            return 2;
        }
        if (!schluessel.startsWith('sk-or-')) {
            logger.error(`OPENROUTER_API_KEY sieht nicht nach einem OpenRouter-Schluessel aus (${schluessel.length} Zeichen, beginnt mit ${schluessel.substring(0, 6)}) — erwartet wird sk-or-...`);
            return 2;
        }
        logger.info(`Schluessel erkannt: ${schluessel.length} Zeichen`);
    }

    const zustand = zustand_laden();
    const baeume = quellen_holen();
    if (!baeume.length) {
        logger.error('Keine Quellen verfuegbar');
        return 1;
    }

    const inventar = inventar_bauen(baeume);
    if (!inventar.length) {
        logger.error('Inventar leer');
        return 1;
    }

    const prioritaet = argumente.prioritaet || zustand.naechste_prioritaet || 'high';
    const zaehler = await uebersetzen(inventar, zustand, prioritaet, argumente.anzahl, argumente.probelauf, schluessel);

    const reihum = { high: 'medium', medium: 'low', low: 'high', alle: 'alle' };
    zustand.naechste_prioritaet = reihum[prioritaet];
    zustand.statistik = {
        letzter_lauf: new Date().toISOString(),
        quelldateien: inventar.length,
        ...zaehler,
    };

    bericht_schreiben(inventar, zustand, zaehler);
    zustand_speichern(zustand);

    if (zaehler.erzeugt && !argumente.probelauf) {
        veroeffentlichen(`auto: ${zaehler.erzeugt} Uebersetzungen (${prioritaet}) aus ${zaehler.dateien} Quelldateien`);
    }

    logger.info(`Abgeschlossen: ${zaehler.erzeugt} erzeugt, ${zaehler.verworfen} verworfen, ${zaehler.dateien} Quelldateien bearbeitet`);
    return 0;
}

main().then(code => process.exit(code)).catch(error => {
    logger.error(`Unerwarteter Fehler: ${error.message}`);
    process.exit(1);
});
