#!/usr/bin/env python3
# collect_ist_gateway_a.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import json
import urllib.request
from datetime import datetime
import socket

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""

def get_first_line_or_default(cmd, default="(nicht ermittelt)"):
    output = run_command(cmd)
    lines = output.split('\n')
    return lines[0] if lines and lines[0] else default

def file_exists(path):
    return "vorhanden" if os.path.isfile(path) else "fehlt"

def dir_exists(path):
    return "vorhanden" if os.path.isdir(path) else "fehlt"

def read_file_content(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return f"# {os.path.basename(path)} fehlt"

def main():
    # Environment variables and paths
    HOME = os.environ.get("HOME", "")
    BASE_DIR = os.path.join(HOME, ".openclaw")
    OUT_DIR = os.path.join(BASE_DIR, "workspace", "vscode")
    
    # Create output directory
    os.makedirs(OUT_DIR, exist_ok=True)
    
    # Timestamps
    NOW_UTC = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    NOW_LOCAL = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    TS = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # Output files
    IST_FILE = os.path.join(OUT_DIR, "IST-ZUSTAND_GATEWAY-A_NODE1.md")
    INV_FILE = os.path.join(OUT_DIR, "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md")
    CFG_FILE = os.path.join(OUT_DIR, "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md")
    ENV_FILE = os.path.join(OUT_DIR, "ENV-STATUS_GATEWAY-A_NODE1.md")
    RUN_FILE = os.path.join(OUT_DIR, f"RUN-{TS}.md")
    
    # File paths
    OPENCLAW_JSON = os.path.join(BASE_DIR, "openclaw.json")
    ENV_DOT = os.path.join(BASE_DIR, ".env")
    ENV_SYSTEMD = os.path.join(BASE_DIR, "gateway.systemd.env")
    VSCODE_DIR = os.path.join(BASE_DIR, ".vscode")
    
    # System information
    HOSTNAME_FQDN = socket.getfqdn()
    HOSTNAME_SHORT = socket.gethostname()
    
    ARCH = run_command("uname -m")
    KERNEL = run_command("uname -r")
    
    OS_PRETTY = "(nicht ermittelt)"
    try:
        with open("/etc/os-release", "r") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    OS_PRETTY = line.split("=", 1)[1].strip().strip('"')
                    break
    except FileNotFoundError:
        pass
    
    IPV4_ALL = run_command("hostname -I").replace('\n', ' ').strip()
    
    # Network information with timeout
    try:
        req = urllib.request.Request("http://ifconfig.me", headers={'User-Agent': 'curl/7.0'})
        with urllib.request.urlopen(req, timeout=4) as response:
            PUBLIC_IP = response.read().decode().strip()
    except Exception:
        PUBLIC_IP = "(nicht ermittelt)"
    
    TAILSCALE_IP = get_first_line_or_default("tailscale ip -4")
    
    OPENCLAW_VER = get_first_line_or_default("openclaw --version")
    NODE_VER = get_first_line_or_default("node -v")
    
    # Write IST file
    with open(IST_FILE, "w") as f:
        f.write(f"""# IST-Zustand: Gateway A / Node 1

Stand (lokal): {NOW_LOCAL}  
Stand (UTC): {NOW_UTC}

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `{HOSTNAME_SHORT}`
- Hostname (FQDN): `{HOSTNAME_FQDN}`
- Architektur: `{ARCH}`
- Kernel: `{KERNEL}`
- OS: `{OS_PRETTY}`
- IPv4 (lokal): `{IPV4_ALL}`
- Public IPv4: `{PUBLIC_IP}`
- Tailscale IPv4: `{TAILSCALE_IP}`
- OpenClaw Version: `{OPENCLAW_VER}`
- Node.js Version: `{NODE_VER}`

## 2) Arbeitsverzeichnisse

- Basis: `{BASE_DIR}`
- Funktionell VSCode: `{VSCODE_DIR}`
- Workspace Doku: `{OUT_DIR}`

## 3) Kernartefakte (Existenz)

- `{OPENCLAW_JSON}`: {file_exists(OPENCLAW_JSON)}
- `{ENV_DOT}`: {file_exists(ENV_DOT)}
- `{ENV_SYSTEMD}`: {file_exists(ENV_SYSTEMD)}
- `{os.path.join(BASE_DIR, "plugins/installs.json")}`: {file_exists(os.path.join(BASE_DIR, "plugins/installs.json"))}
- `{os.path.join(BASE_DIR, "plugin-skills")}`: {dir_exists(os.path.join(BASE_DIR, "plugin-skills"))}
""")
    
    # Write inventory file
    with open(INV_FILE, "w") as f:
        f.write(f"""# Artefakt-Inventar: Gateway A / Node 1

Stand: {NOW_LOCAL}

## Top-Level in ~/.openclaw

```
""")
        try:
            for item in sorted(os.listdir(BASE_DIR)):
                f.write(f"{item}\n")
        except FileNotFoundError:
            pass
        f.write("""```

## ~/.openclaw/.vscode

```
""")
        if os.path.isdir(VSCODE_DIR):
            try:
                for item in sorted(os.listdir(VSCODE_DIR)):
                    item_path = os.path.join(VSCODE_DIR, item)
                    stat = os.stat(item_path)
                    f.write(f"{stat.st_mode:06o} {stat.st_uid} {stat.st_gid} {stat.st_size} {datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M')} {item}\n")
            except Exception:
                f.write("(Fehler beim Lesen)\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## plugin-skills/

```
""")
        plugin_skills_dir = os.path.join(BASE_DIR, "plugin-skills")
        if os.path.isdir(plugin_skills_dir):
            try:
                for item in sorted(os.listdir(plugin_skills_dir)):
                    f.write(f"{item}\n")
            except Exception:
                pass
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## openclaw.json Backups

```
""")
        try:
            backup_files = [f for f in os.listdir(BASE_DIR) if f.startswith("openclaw.json.bak")]
            if backup_files:
                for bf in sorted(backup_files):
                    f.write(f"{bf}\n")
            else:
                f.write("(keine gefunden)\n")
        except FileNotFoundError:
            f.write("(keine gefunden)\n")
        f.write("```\n")
    
    # Write config snapshot
    with open(CFG_FILE, "w") as f:
        f.write(f"""# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: {NOW_LOCAL}

## Schluesselpositionen (grep)

```
""")
        if os.path.isfile(OPENCLAW_JSON):
            try:
                with open(OPENCLAW_JSON, "r") as json_file:
                    lines = json_file.readlines()
                    for i, line in enumerate(lines, 1):
                        if any(keyword in line for keyword in ['"gateway"', '"session"', '"dmScope"', '"auth"', '"secrets"', '"tools"', '"plugins"', '"profile"', '"alsoAllow"', '"denyCommands"']):
                            f.write(f"{i}: {line}")
            except Exception:
                pass
        else:
            f.write("openclaw.json fehlt\n")
        f.write("""```

## Ausschnitt gateway/session/auth

```json
""")
        if os.path.isfile(OPENCLAW_JSON):
            try:
                with open(OPENCLAW_JSON, "r") as json_file:
                    lines = json_file.readlines()
                    # Get lines 580 to 780 (1-indexed)
                    start = max(0, 580 - 1)
                    end = min(len(lines), 780)
                    for line in lines[start:end]:
                        f.write(line)
            except Exception:
                f.write('{{ "error": "Fehler beim Lesen von openclaw.json" }}\n')
        else:
            f.write('{{ "error": "openclaw.json fehlt" }}\n')
        f.write("```\n")
    
    # Write env status
    with open(ENV_FILE, "w") as f:
        f.write(f"""# ENV-Status: Gateway A / Node 1

Stand: {NOW_LOCAL}

## Dateien

```
""")
        env_files = [ENV_DOT, ENV_SYSTEMD]
        for ef in env_files:
            if os.path.exists(ef):
                try:
                    stat = os.stat(ef)
                    f.write(f"{stat.st_mode:06o} {stat.st_uid} {stat.st_gid} {stat.st_size} {datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M')} {ef}\n")
                except Exception:
                    pass
        f.write("""```

## .env (vollstaendig)

```dotenv
""")
        f.write(read_file_content(ENV_DOT))
        f.write("""
```

## gateway.systemd.env (vollstaendig)

```dotenv
""")
        f.write(read_file_content(ENV_SYSTEMD))
        f.write("\n```\n")
    
    # Write run file
    script_path = os.path.realpath(__file__)
    with open(RUN_FILE, "w") as f:
        f.write(f"""# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): {NOW_LOCAL}
- Zeit (UTC): {NOW_UTC}
- Script: {script_path}

## Erzeugte Dateien

- {os.path.basename(IST_FILE)}
- {os.path.basename(INV_FILE)}
- {os.path.basename(CFG_FILE)}
- {os.path.basename(ENV_FILE)}
""")
    
    # Print success message
    print("OK: IST-Zustand erfasst.")
    try:
        for item in sorted(os.listdir(OUT_DIR)):
            print(f"- {item}")
    except FileNotFoundError:
        pass

if __name__ == "__main__":
    main()
