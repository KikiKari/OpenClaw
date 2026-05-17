#!/usr/bin/env python3
"""
Script Abstractions Manager - Multi-Node Edition
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple

# Konfiguration
WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
ABSTRACTIONS_REPO = WORKSPACE / "git" / "Abstraktionen"
LOG_DIR = WORKSPACE / "logs" / "abstractions-manager"
STATE_FILE = WORKSPACE / "db" / "abstractions_state.json"
# Node-Konfiguration mit Prioritäten
NODES = {
    "node1": {"always_available": True, "capacity": "medium", "priority": 2},  # Gateway-Master
    "node2": {"always_available": True, "capacity": "medium", "priority": 3},  # Stable Worker
    "node3": {"always_available": False, "capacity": "medium", "priority": 4}, # Bald verfügbar
    "node5": {"always_available": False, "capacity": "low", "priority": 5, "device": "Redmi Note 11S", "condition": "mobile_internet"},
    "node7": {"always_available": True, "capacity": "high", "priority": 1},    # Docker Hauptarbeitspferd
}

AVAILABLE_MODELS = [
    "openrouter/moonshotai/kimi-k2.5",
    "openrouter/openai/gpt-4o",
    "openrouter/anthropic/claude-3-5-sonnet-20241022",
    "openrouter/google/gemini-2.0-flash-001",
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
    "openrouter/qwen/qwen-2.5-coder-32b-instruct",
]

TARGET_LANGUAGES = {
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
}

def log(message: str, level: str = "INFO"):
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f"[{timestamp}] [{level}] {message}"
    print(line)
    log_file = LOG_DIR / f"{datetime.now().strftime('%Y-%m-%d')}.log"
    with open(log_file, 'a') as f:
        f.write(line + '\n')

def get_node_by_priority(job_weight: str = "medium") -> str:
    """Wählt Node basierend auf Job-Gewicht und Priorität"""
    
    # Prioritäts-Matrix
    if job_weight == "heavy":
        # Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
        preferred_order = ["node7", "node2", "node1"]
    elif job_weight == "medium":
        # Mittlere Jobs → Stable Nodes
        preferred_order = ["node2", "node1", "node7"]
    else:  # light
        # Leichte Jobs → Mobile/verfügbare Nodes
        preferred_order = ["node5", "node1", "node2"]
    
    # Prüfe Verfügbarkeit
    for node_id in preferred_order:
        if node_id not in NODES:
            continue
            
        node = NODES[node_id]
        
        # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if not node.get("always_available", False) and job_weight != "light":
            continue
            
        # Prüfe ob Node online
        if check_node_status(node_id):
            return node_id
    
    # Fallback zu Node 1
    return "node1"

def check_node_status(node_id: str) -> bool:
    """Prüft ob ein Node erreichbar ist"""
    try:
        result = subprocess.run(
            ["openclaw", "nodes", "status", node_id],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0 and ("online" in result.stdout.lower() or "active" in result.stdout.lower())
    except:
        # Bei Timeout/Error: Prüfe letzten bekannten Status
        return NODES.get(node_id, {}).get("always_available", False)

def get_job_weight(script_size: int, target_langs_count: int) -> str:
    """Bewertet Job-Gewicht basierend auf Script-Größe und Anzahl Zielsprachen"""
    total_work = script_size * target_langs_count
    
    if total_work > 50000:  # Große Scripts, viele Sprachen
        return "heavy"
    elif total_work > 10000:  # Mittlere Last
        return "medium"
    else:
        return "light"

def load_state() -> Dict:
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {"processed": {}, "queue": [], "current_priority": "high", "stats": {"total_scripts": 0, "abstractions_created": 0}}

def save_state(state: Dict):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def find_scripts_in_dir(directory: Path, exclude_patterns: List[str] = None) -> List[Path]:
    if exclude_patterns is None:
        exclude_patterns = ["node_modules", ".git", "__pycache__", "dist", "build"]
    scripts = []
    if directory.exists():
        for ext in ["*.py", "*.js", "*.sh", "*.pl", "*.rb"]:
            for script in directory.rglob(ext):
                if not any(pattern in str(script) for pattern in exclude_patterns):
                    scripts.append(script)
    return scripts

def create_abstraction(script_path: Path, target_lang: str) -> bool:
    try:
        with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
            original_content = f.read()
        
        ext = script_path.suffix[1:]
        source_lang_map = {"py": "Python", "js": "JavaScript", "sh": "Shell", "pl": "Perl", "rb": "Ruby"}
        source_lang = source_lang_map.get(ext, ext)
        
        target_dir = ABSTRACTIONS_REPO / target_lang
        target_dir.mkdir(parents=True, exist_ok=True)
        
        target_file = target_dir / f"{script_path.stem}{TARGET_LANGUAGES[target_lang]['ext']}"
        
        if target_file.exists():
            return False
        
        template = TARGET_LANGUAGES[target_lang]
        lines = original_content.split('\n')[:15]
        
        content = f"""{template['shebang']}
# {script_path.stem} - {target_lang.title()} Version
# Portiert von {source_lang}
# Original: {script_path}
# Erstellt: {datetime.now().strftime('%Y-%m-%d')}
#
# {template.get('header', '').strip()}

# Original-Code-Referenz:
# {'# '.join(lines)}

def main():
    # TODO: Implementiere {source_lang} Funktionalität in {target_lang.title()}
    pass

if __name__ == "__main__":
    main()
"""
        
        with open(target_file, 'w') as f:
            f.write(content)
        
        log(f"Created: {target_file}")
        return True
    except Exception as e:
        log(f"Failed: {script_path} - {e}", "ERROR")
        return False

def process_on_node(node_id: str, scripts: List[Path], target_langs: List[str]) -> int:
    """Verarbeitet Scripts auf definiertem Node"""
    created = 0
    
    if node_id == "node1":
        # Lokale Verarbeitung
        for script in scripts:
            for lang in target_langs:
                if create_abstraction(script, lang):
                    created += 1
    else:
        # Remote-Verarbeitung
        log(f"Dispatching {len(scripts)} jobs to {node_id}")
        # TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        for script in scripts:
            for lang in target_langs:
                if create_abstraction(script, lang):
                    created += 1
                    log(f"Processed on {node_id}: {script.name} -> {lang}")
    
    return created

def process_priority_high() -> int:
    created = 0
    targets = [
        ("skill-creator", WORKSPACE / "skills" / "skill-creator" / "scripts"),
        ("json-utils", WORKSPACE / "skills" / "json-utils" / "scripts"),
        ("scripting-utils", WORKSPACE / "skills" / "scripting-utils" / "scripts"),
        ("model-usage", WORKSPACE / "skills" / "model-usage" / "scripts"),
        ("tiktok-live", WORKSPACE / "skills" / "tiktok-live" / "scripts"),
    ]
    
    for skill_name, scripts_dir in targets:
        scripts = find_scripts_in_dir(scripts_dir, exclude_patterns=["node_modules", ".git", "test", "tests"])
        log(f"{skill_name}: {len(scripts)} scripts found")
        
        for script in scripts[:10]:  # Limit für erste Durchläufe
            script_size = script.stat().st_size if script.exists() else 0
            target_langs = ["perl5", "javascript", "python", "shell", "tcl"]
            job_weight = get_job_weight(script_size, len(target_langs))
            
            # Wähle Node basierend auf Job-Gewicht
            selected_node = get_node_by_priority(job_weight)
            log(f"Processing {script.name} ({job_weight}) on {selected_node}")
            
            created += process_on_node(selected_node, [script], target_langs)
    
    return created

def process_priority_medium() -> int:
    created = 0
    targets = [
        ("workspace-scripts", WORKSPACE / "scripts"),
        ("db-maintainer", WORKSPACE / "skills" / "db-maintainer" / "scripts"),
        ("log-collector", WORKSPACE / "skills" / "log-collector" / "scripts"),
    ]
    
    for dir_name, scripts_dir in targets:
        scripts = find_scripts_in_dir(scripts_dir, exclude_patterns=["node_modules", ".git"])
        
        for script in scripts[:10]:
            script_size = script.stat().st_size if script.exists() else 0
            target_langs = ["perl5", "javascript", "powershell", "python"]
            job_weight = get_job_weight(script_size, len(target_langs))
            
            # Mittlere Priority → eher leichtere Jobs
            selected_node = get_node_by_priority("medium" if job_weight == "heavy" else job_weight)
            log(f"Processing {script.name} ({job_weight}) on {selected_node}")
            
            created += process_on_node(selected_node, [script], target_langs)
    
    return created

def git_commit(message: str):
    try:
        os.chdir(ABSTRACTIONS_REPO)
        subprocess.run(["git", "add", "."], check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", message], check=True, capture_output=True)
        log(f"Git commit: {message}")
    except:
        pass

def create_status_report(state: Dict):
    report_file = ABSTRACTIONS_REPO / "STATUS.md"
    lang_counts = {}
    if ABSTRACTIONS_REPO.exists():
        for lang_dir in ABSTRACTIONS_REPO.iterdir():
            if lang_dir.is_dir() and lang_dir.name in TARGET_LANGUAGES:
                lang_counts[lang_dir.name] = len([f for f in lang_dir.iterdir() if f.is_file()])
    
    with open(report_file, 'w') as f:
        f.write("# Script Abstractions - Status Report\n\n")
        f.write(f"**Letzte Aktualisierung:** {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        f.write(f"- Aktuelle Priorität: {state.get('current_priority', 'high')}\n")
        f.write(f"- Verarbeitete Scripts: {len(state['processed'])}\n")
        f.write(f"- Abstraktionen gesamt: {state['stats']['abstractions_created']}\n\n")
        
        f.write("## Abstraktionen pro Sprache\n\n")
        for lang, count in sorted(lang_counts.items()):
            f.write(f"- {lang}: {count}\n")
        
        f.write("\n## Verfügbare Modelle\n\n")
        for model in AVAILABLE_MODELS[:3]:
            f.write(f"- `{model}`\n")
        f.write(f"- ... und {len(AVAILABLE_MODELS) - 3} weitere\n")
        
        f.write("\n## Multi-Node Support\n\n")
        f.write("| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |\n")
        f.write("|------|---------------|-----------|-----------|-------|\n")
        for node_id, config in NODES.items():
            avail = "✅ Immer" if config.get("always_available") else "📱 Bedingt"
            device = config.get("device", "Server")
            f.write(f"| {node_id} | {avail} | {config.get('capacity', 'unknown')} | {config.get('priority', '-')} | {device} |\n")
        
        f.write("\n### Job-Verteilung\n\n")
        f.write("- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)\n")
        f.write("- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)\n")
        f.write("- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)\n")

def main():
    log("Script Abstractions Manager (Multi-Node) gestartet")
    
    state = load_state()
    log(f"State loaded: {len(state['processed'])} processed")
    
    current_priority = state.get("current_priority", "high")
    created = 0
    
    if current_priority == "high":
        log("Processing HIGH priority: Top 5 Skills")
        created = process_priority_high()
        if created > 0:
            git_commit(f"High priority: {created} abstractions")
        state["current_priority"] = "medium"
    elif current_priority == "medium":
        log("Processing MEDIUM priority: Workspace Scripts")
        created = process_priority_medium()
        if created > 0:
            git_commit(f"Medium priority: {created} abstractions")
        state["current_priority"] = "high"  # Zyklus
    
    state["stats"]["last_run"] = datetime.now().isoformat()
    state["stats"]["abstractions_created"] = sum(
        len([f for f in (ABSTRACTIONS_REPO / lang).iterdir() if f.is_file()])
        for lang in TARGET_LANGUAGES if (ABSTRACTIONS_REPO / lang).exists()
    )
    
    save_state(state)
    create_status_report(state)
    
    log(f"Abgeschlossen. {created} neue Abstraktionen erstellt.")

if __name__ == "__main__":
    main()