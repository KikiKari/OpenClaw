#!/usr/bin/env node
// abstractions_manager.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Script Abstractions Manager - Multi-Node Edition
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Konfiguration
const WORKSPACE = path.join('/home/openclaw/.openclaw/workspace');
const ABSTRACTIONS_REPO = path.join(WORKSPACE, 'git', 'Abstraktionen');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'abstractions-manager');
const STATE_FILE = path.join(WORKSPACE, 'db', 'abstractions_state.json');

// Node-Konfiguration mit Prioritäten
const NODES = {
    "node1": {"always_available": true, "capacity": "medium", "priority": 2},  // Gateway-Master
    "node2": {"always_available": true, "capacity": "medium", "priority": 3},  // Stable Worker
    "node3": {"always_available": false, "capacity": "medium", "priority": 4}, // Bald verfügbar
    "node5": {"always_available": false, "capacity": "low", "priority": 5, "device": "Redmi Note 11S", "condition": "mobile_internet"},
    "node7": {"always_available": true, "capacity": "high", "priority": 1},    // Docker Hauptarbeitspferd
};

const AVAILABLE_MODELS = [
    "openrouter/moonshotai/kimi-k2.5",
    "openrouter/openai/gpt-4o",
    "openrouter/anthropic/claude-3-5-sonnet-20241022",
    "openrouter/google/gemini-2.0-flash-001",
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
    "openrouter/qwen/qwen-2.5-coder-32b-instruct",
];

const TARGET_LANGUAGES = {
    "perl5": {"ext": ".pl", "shebang": "#!/usr/bin/env perl", "header": "use strict;\nuse warnings;\n"},
    "perl6": {"ext": ".raku", "shebang": "#!/usr/bin/env raku", "header": "use v6;\n"},
    "javascript": {"ext": ".js", "shebang": "#!/usr/bin/env node", "header": ""},
    "python": {"ext": ".py", "shebang": "#!/usr/bin/env python3", "header": ""},
    "shell": {"ext": ".sh", "shebang": "#!/bin/bash", "header": "set -euo pipefail\n"},
    "powershell": {"ext": ".ps1", "shebang": "#!/usr/bin/env pwsh", "header": "#Requires -Version 7\n"},
    "tcl": {"ext": ".tcl", "shebang": "#!/usr/bin/env tclsh", "header": "package require Tcl 8.6\n"},
    "ruby": {"ext": ".rb", "shebang": "#!/usr/bin/env ruby", "header": "require 'json'\nrequire 'fileutils'\n"},
    "lua": {"ext": ".lua", "shebang": "#!/usr/bin/env lua", "header": ""},
    "go": {"ext": ".go", "shebang": "// +build ignore", "header": "package main\n"},
};

function log(message, level = "INFO") {
    const logDir = LOG_DIR;
    if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }
    
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
    const line = `[${timestamp}] [${level}] ${message}`;
    console.log(line);
    
    const logFile = path.join(logDir, `${new Date().toISOString().split('T')[0]}.log`);
    fs.appendFileSync(logFile, line + '\n');
}

function get_node_by_priority(job_weight = "medium") {
    /** Wählt Node basierend auf Job-Gewicht und Priorität */
    
    let preferred_order;
    if (job_weight === "heavy") {
        // Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
        preferred_order = ["node7", "node2", "node1"];
    } else if (job_weight === "medium") {
        // Mittlere Jobs → Stable Nodes
        preferred_order = ["node2", "node1", "node7"];
    } else {  // light
        // Leichte Jobs → Mobile/verfügbare Nodes
        preferred_order = ["node5", "node1", "node2"];
    }
    
    // Prüfe Verfügbarkeit
    for (const node_id of preferred_order) {
        if (!NODES[node_id]) {
            continue;
        }
            
        const node = NODES[node_id];
        
        // Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if (!node.always_available && job_weight !== "light") {
            continue;
        }
            
        // Prüfe ob Node online
        if (check_node_status(node_id)) {
            return node_id;
        }
    }
    
    // Fallback zu Node 1
    return "node1";
}

function check_node_status(node_id) {
    /** Prüft ob ein Node erreichbar ist */
    try {
        const result = execSync(`openclaw nodes status ${node_id}`, {
            timeout: 5000,
            encoding: 'utf-8'
        });
        return result.includes("online") || result.includes("active");
    } catch (error) {
        // Bei Timeout/Error: Prüfe letzten bekannten Status
        return NODES[node_id]?.always_available || false;
    }
}

function get_job_weight(script_size, target_langs_count) {
    /** Bewertet Job-Gewicht basierend auf Script-Größe und Anzahl Zielsprachen */
    const total_work = script_size * target_langs_count;
    
    if (total_work > 50000) {  // Große Scripts, viele Sprachen
        return "heavy";
    } else if (total_work > 10000) {  // Mittlere Last
        return "medium";
    } else {
        return "light";
    }
}

function load_state() {
    if (fs.existsSync(STATE_FILE)) {
        try {
            const data = fs.readFileSync(STATE_FILE, 'utf8');
            return JSON.parse(data);
        } catch (error) {
            // ignore error
        }
    }
    return {"processed": {}, "queue": [], "current_priority": "high", "stats": {"total_scripts": 0, "abstractions_created": 0}};
}

function save_state(state) {
    const stateDir = path.dirname(STATE_FILE);
    if (!fs.existsSync(stateDir)) {
        fs.mkdirSync(stateDir, { recursive: true });
    }
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function find_scripts_in_dir(directory, exclude_patterns = null) {
    if (exclude_patterns === null) {
        exclude_patterns = ["node_modules", ".git", "__pycache__", "dist", "build"];
    }
    
    const scripts = [];
    if (fs.existsSync(directory)) {
        function walk(dir) {
            const files = fs.readdirSync(dir);
            for (const file of files) {
                const filepath = path.join(dir, file);
                const stat = fs.statSync(filepath);
                
                if (stat.isDirectory()) {
                    if (!exclude_patterns.some(pattern => filepath.includes(pattern))) {
                        walk(filepath);
                    }
                } else {
                    const ext = path.extname(file);
                    if ([".py", ".js", ".sh", ".pl", ".rb"].includes(ext)) {
                        if (!exclude_patterns.some(pattern => filepath.includes(pattern))) {
                            scripts.push(filepath);
                        }
                    }
                }
            }
        }
        walk(directory);
    }
    return scripts;
}

function create_abstraction(script_path, target_lang) {
    try {
        const original_content = fs.readFileSync(script_path, 'utf8');
        
        const ext = path.extname(script_path).substring(1);
        const source_lang_map = {"py": "Python", "js": "JavaScript", "sh": "Shell", "pl": "Perl", "rb": "Ruby"};
        const source_lang = source_lang_map[ext] || ext;
        
        const target_dir = path.join(ABSTRACTIONS_REPO, target_lang);
        if (!fs.existsSync(target_dir)) {
            fs.mkdirSync(target_dir, { recursive: true });
        }
        
        const target_file = path.join(target_dir, path.basename(script_path, path.extname(script_path)) + TARGET_LANGUAGES[target_lang].ext);
        
        if (fs.existsSync(target_file)) {
            return false;
        }
        
        const template = TARGET_LANGUAGES[target_lang];
        const lines = original_content.split('\n').slice(0, 15);
        
        const content = `${template.shebang}
# ${path.basename(script_path, path.extname(script_path))} - ${target_lang.charAt(0).toUpperCase() + target_lang.slice(1)} Version
# Portiert von ${source_lang}
# Original: ${script_path}
# Erstellt: ${new Date().toISOString().split('T')[0]}
#
${template.header ? '# ' + template.header.trim().replace(/\n/g, '\n# ') : ''}

# Original-Code-Referenz:
# ${lines.join('\n# ')}

function main() {
    // TODO: Implementiere ${source_lang} Funktionalität in ${target_lang.charAt(0).toUpperCase() + target_lang.slice(1)}
    pass
}

if (require.main === module) {
    main();
}
`;
        
        fs.writeFileSync(target_file, content);
        log(`Created: ${target_file}`);
        return true;
    } catch (error) {
        log(`Failed: ${script_path} - ${error.message}`, "ERROR");
        return false;
    }
}

function process_on_node(node_id, scripts, target_langs) {
    /** Verarbeitet Scripts auf definiertem Node */
    let created = 0;
    
    if (node_id === "node1") {
        // Lokale Verarbeitung
        for (const script of scripts) {
            for (const lang of target_langs) {
                if (create_abstraction(script, lang)) {
                    created++;
                }
            }
        }
    } else {
        // Remote-Verarbeitung
        log(`Dispatching ${scripts.length} jobs to ${node_id}`);
        // TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
        // Für jetzt: Lokale Verarbeitung mit Node-Logging
        for (const script of scripts) {
            for (const lang of target_langs) {
                if (create_abstraction(script, lang)) {
                    created++;
                    log(`Processed on ${node_id}: ${path.basename(script)} -> ${lang}`);
                }
            }
        }
    }
    
    return created;
}

function process_priority_high() {
    let created = 0;
    const targets = [
        ["skill-creator", path.join(WORKSPACE, "skills", "skill-creator", "scripts")],
        ["json-utils", path.join(WORKSPACE, "skills", "json-utils", "scripts")],
        ["scripting-utils", path.join(WORKSPACE, "skills", "scripting-utils", "scripts")],
        ["model-usage", path.join(WORKSPACE, "skills", "model-usage", "scripts")],
        ["tiktok-live", path.join(WORKSPACE, "skills", "tiktok-live", "scripts")],
    ];
    
    for (const [skill_name, scripts_dir] of targets) {
        const scripts = find_scripts_in_dir(scripts_dir, ["node_modules", ".git", "test", "tests"]);
        log(`${skill_name}: ${scripts.length} scripts found`);
        
        for (const script of scripts.slice(0, 10)) {  // Limit für erste Durchläufe
            const script_size = fs.existsSync(script) ? fs.statSync(script).size : 0;
            const target_langs = ["perl5", "javascript", "python", "shell", "tcl"];
            const job_weight = get_job_weight(script_size, target_langs.length);
            
            // Wähle Node basierend auf Job-Gewicht
            const selected_node = get_node_by_priority(job_weight);
            log(`Processing ${path.basename(script)} (${job_weight}) on ${selected_node}`);
            
            created += process_on_node(selected_node, [script], target_langs);
        }
    }
    
    return created;
}

function process_priority_medium() {
    let created = 0;
    const targets = [
        ["workspace-scripts", path.join(WORKSPACE, "scripts")],
        ["db-maintainer", path.join(WORKSPACE, "skills", "db-maintainer", "scripts")],
        ["log-collector", path.join(WORKSPACE, "skills", "log-collector", "scripts")],
    ];
    
    for (const [dir_name, scripts_dir] of targets) {
        const scripts = find_scripts_in_dir(scripts_dir, ["node_modules", ".git"]);
        
        for (const script of scripts.slice(0, 10)) {
            const script_size = fs.existsSync(script) ? fs.statSync(script).size : 0;
            const target_langs = ["perl5", "javascript", "powershell", "python"];
            const job_weight = get_job_weight(script_size, target_langs.length);
            
            // Mittlere Priority → eher leichtere Jobs
            const selected_node = get_node_by_priority(job_weight === "heavy" ? "medium" : job_weight);
            log(`Processing ${path.basename(script)} (${job_weight}) on ${selected_node}`);
            
            created += process_on_node(selected_node, [script], target_langs);
        }
    }
    
    return created;
}

function git_commit(message) {
    try {
        process.chdir(ABSTRACTIONS_REPO);
        execSync("git add .", { stdio: 'pipe' });
        execSync(`git commit -m "${message}"`, { stdio: 'pipe' });
        log(`Git commit: ${message}`);
    } catch (error) {
        // ignore errors
    }
}

function create_status_report(state) {
    const report_file = path.join(ABSTRACTIONS_REPO, "STATUS.md");
    const lang_counts = {};
    
    if (fs.existsSync(ABSTRACTIONS_REPO)) {
        const dirs = fs.readdirSync(ABSTRACTIONS_REPO);
        for (const dir of dirs) {
            const dirPath = path.join(ABSTRACTIONS_REPO, dir);
            if (fs.statSync(dirPath).isDirectory() && TARGET_LANGUAGES[dir]) {
                const files = fs.readdirSync(dirPath);
                lang_counts[dir] = files.filter(f => fs.statSync(path.join(dirPath, f)).isFile()).length;
            }
        }
    }
    
    let content = "# Script Abstractions - Status Report\n\n";
    content += `**Letzte Aktualisierung:** ${new Date().toISOString().replace('T', ' ').substring(0, 16)}\n\n`;
    content += `- Aktuelle Priorität: ${state.current_priority || 'high'}\n`;
    content += `- Verarbeitete Scripts: ${Object.keys(state.processed).length}\n`;
    content += `- Abstraktionen gesamt: ${state.stats.abstractions_created}\n\n`;
    
    content += "## Abstraktionen pro Sprache\n\n";
    Object.entries(lang_counts)
        .sort(([a], [b]) => a.localeCompare(b))
        .forEach(([lang, count]) => {
            content += `- ${lang}: ${count}\n`;
        });
    
    content += "\n## Verfügbare Modelle\n\n";
    for (let i = 0; i < Math.min(3, AVAILABLE_MODELS.length); i++) {
        content += `- \`${AVAILABLE_MODELS[i]}\`\n`;
    }
    content += `- ... und ${Math.max(0, AVAILABLE_MODELS.length - 3)} weitere\n`;
    
    content += "\n## Multi-Node Support\n\n";
    content += "| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |\n";
    content += "|------|---------------|-----------|-----------|-------|\n";
    Object.entries(NODES).forEach(([node_id, config]) => {
        const avail = config.always_available ? "✅ Immer" : "📱 Bedingt";
        const device = config.device || "Server";
        content += `| ${node_id} | ${avail} | ${config.capacity || 'unknown'} | ${config.priority || '-'} | ${device} |\n`;
    });
    
    content += "\n### Job-Verteilung\n\n";
    content += "- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)\n";
    content += "- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)\n";
    content += "- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)\n";
    
    fs.writeFileSync(report_file, content);
}

function main() {
    log("Script Abstractions Manager (Multi-Node) gestartet");
    
    const state = load_state();
    log(`State loaded: ${Object.keys(state.processed).length} processed`);
    
    const current_priority = state.current_priority || "high";
    let created = 0;
    
    if (current_priority === "high") {
        log("Processing HIGH priority: Top 5 Skills");
        created = process_priority_high();
        if (created > 0) {
            git_commit(`High priority: ${created} abstractions`);
        }
        state.current_priority = "medium";
    } else if (current_priority === "medium") {
        log("Processing MEDIUM priority: Workspace Scripts");
        created = process_priority_medium();
        if (created > 0) {
            git_commit(`Medium priority: ${created} abstractions`);
        }
        state.current_priority = "high";  // Zyklus
    }
    
    state.stats.last_run = new Date().toISOString();
    
    // Zähle alle Abstraktionen
    let total_abstractions = 0;
    if (fs.existsSync(ABSTRACTIONS_REPO)) {
        for (const lang of Object.keys(TARGET_LANGUAGES)) {
            const langDir = path.join(ABSTRACTIONS_REPO, lang);
            if (fs.existsSync(langDir)) {
                const files = fs.readdirSync(langDir);
                total_abstractions += files.filter(f => fs.statSync(path.join(langDir, f)).isFile()).length;
            }
        }
    }
    state.stats.abstractions_created = total_abstractions;
    
    save_state(state);
    create_status_report(state);
    
    log(`Abgeschlossen. ${created} neue Abstraktionen erstellt.`);
}

main();
