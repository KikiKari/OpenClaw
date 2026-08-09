#!/usr/bin/env python3
# collect_ist_gateway_a.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import json
import urllib.request
from datetime import datetime
import platform
import socket

def run_command(cmd, shell=False):
    try:
        if isinstance(cmd, str) and not shell:
            cmd = cmd.split()
        result = subprocess.run(cmd, capture_output=True, text=True, shell=shell)
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""

def get_public_ip():
    try:
        req = urllib.request.Request("http://ifconfig.me", headers={'User-Agent': 'curl/7.0'})
        with urllib.request.urlopen(req, timeout=4) as response:
            return response.read().decode().strip()
    except Exception:
        return ""

def main():
    # Environment variables
    home_dir = os.path.expanduser("~")
    base_dir = os.path.join(home_dir, ".openclaw")
    out_dir = os.path.join(base_dir, "workspace", "vscode")
    
    # Create output directory
    os.makedirs(out_dir, exist_ok=True)
    
    # Time variables
    now_utc = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    now_local = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # File paths
    ist_file = os.path.join(out_dir, "IST-ZUSTAND_GATEWAY-A_NODE1.md")
    inv_file = os.path.join(out_dir, "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md")
    cfg_file = os.path.join(out_dir, "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md")
    env_file = os.path.join(out_dir, "ENV-STATUS_GATEWAY-A_NODE1.md")
    run_file = os.path.join(out_dir, f"RUN-{ts}.md")
    
    openclaw_json = os.path.join(base_dir, "openclaw.json")
    env_dot = os.path.join(base_dir, ".env")
    env_systemd = os.path.join(base_dir, "gateway.systemd.env")
    vscode_dir = os.path.join(base_dir, ".vscode")
    
    # System information
    hostname_fqdn = run_command("hostname -f") or platform.node()
    hostname_short = platform.node()
    arch = platform.machine()
    kernel = platform.release()
    
    os_pretty = ""
    try:
        with open("/etc/os-release", "r") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    os_pretty = line.split("=", 1)[1].strip().strip('"')
                    break
    except FileNotFoundError:
        pass
    
    ipv4_all = run_command("hostname -I")
    public_ip = get_public_ip()
    tailscale_ip = run_command(["tailscale", "ip", "-4"])
    openclaw_ver = run_command(["openclaw", "--version"])
    node_ver = run_command(["node", "-v"])
    
    # Handle empty values
    public_ip = public_ip or "(nicht ermittelt)"
    tailscale_ip = tailscale_ip or "(nicht ermittelt)"
    openclaw_ver = openclaw_ver or "(nicht ermittelt)"
    node_ver = node_ver or "(nicht ermittelt)"
    
    # IST-Zustand file
    with open(ist_file, "w") as f:
        f.write(f"""# IST-Zustand: Gateway A / Node 1

Stand (lokal): {now_local}  
Stand (UTC): {now_utc}

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `{hostname_short}`
- Hostname (FQDN): `{hostname_fqdn}`
- Architektur: `{arch}`
- Kernel: `{kernel}`
- OS: `{os_pretty}`
- IPv4 (lokal): `{ipv4_all}`
- Public IPv4: `{public_ip}`
- Tailscale IPv4: `{tailscale_ip}`
- OpenClaw Version: `{openclaw_ver}`
- Node.js Version: `{node_ver}`

## 2) Arbeitsverzeichnisse

- Basis: `{base_dir}`
- Funktionell VSCode: `{vscode_dir}`
- Workspace Doku: `{out_dir}`

## 3) Kernartefakte (Existenz)

- `{openclaw_json}`: {"vorhanden" if os.path.isfile(openclaw_json) else "fehlt"}
- `{env_dot}`: {"vorhanden" if os.path.isfile(env_dot) else "fehlt"}
- `{env_systemd}`: {"vorhanden" if os.path.isfile(env_systemd) else "fehlt"}
- `{base_dir}/plugins/installs.json`: {"vorhanden" if os.path.isfile(os.path.join(base_dir, "plugins", "installs.json")) else "fehlt"}
- `{base_dir}/plugin-skills`: {"vorhanden" if os.path.isdir(os.path.join(base_dir, "plugin-skills")) else "fehlt"}
""")
    
    # Artefakt-Inventar file
    with open(inv_file, "w") as f:
        f.write(f"""# Artefakt-Inventar: Gateway A / Node 1

Stand: {now_local}

## Top-Level in ~/.openclaw

```
""")
        try:
            for item in sorted(os.listdir(base_dir)):
                f.write(f"{item}\n")
        except FileNotFoundError:
            pass
        f.write("""```

## ~/.openclaw/.vscode

```
""")
        if os.path.isdir(vscode_dir):
            try:
                for item in sorted(os.listdir(vscode_dir)):
                    item_path = os.path.join(vscode_dir, item)
                    stat = os.stat(item_path)
                    f.write(f"{'d' if os.path.isdir(item_path) else '-'} {stat.st_size:>8} {item}\n")
            except Exception:
                f.write("(Fehler beim Lesen)\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## plugin-skills/

```
""")
        skills_dir = os.path.join(base_dir, "plugin-skills")
        if os.path.isdir(skills_dir):
            try:
                for item in sorted(os.listdir(skills_dir)):
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
            backups = [f for f in os.listdir(base_dir) if f.startswith("openclaw.json.bak")]
            if backups:
                for backup in sorted(backups):
                    f.write(f"{backup}\n")
            else:
                f.write("(keine gefunden)\n")
        except Exception:
            f.write("(keine gefunden)\n")
        f.write("```\n")
    
    # Config snapshot file
    with open(cfg_file, "w") as f:
        f.write(f"""# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: {now_local}

## Schluesselpositionen (grep)

```
""")
        if os.path.isfile(openclaw_json):
            try:
                with open(openclaw_json, "r") as json_file:
                    lines = json_file.readlines()
                    for i, line in enumerate(lines, 1):
                        if any(keyword in line for keyword in ['"gateway"', '"session"', '"dmScope"', '"auth"', '"secrets"', '"tools"', '"plugins"', '"profile"', '"alsoAllow"', '"denyCommands"']):
                            f.write(f"{i:3}: {line}")
            except Exception:
                pass
        else:
            f.write("openclaw.json fehlt\n")
        f.write("""```

## Ausschnitt gateway/session/auth

```json
""")
        if os.path.isfile(openclaw_json):
            try:
                with open(openclaw_json, "r") as json_file:
                    lines = json_file.readlines()
                    for line in lines[579:780]:  # 580-780 lines (0-indexed)
                        f.write(line)
            except Exception:
                f.write('{ "error": "Fehler beim Lesen" }\n')
        else:
            f.write('{ "error": "openclaw.json fehlt" }\n')
        f.write("```\n")
    
    # ENV-Status file
    with open(env_file, "w") as f:
        f.write(f"""# ENV-Status: Gateway A / Node 1

Stand: {now_local}

## Dateien

```
""")
        try:
            for env_file_path in [env_dot, env_systemd]:
                if os.path.exists(env_file_path):
                    stat = os.stat(env_file_path)
                    f.write(f"{'d' if os.path.isdir(env_file_path) else '-'} {stat.st_size:>8} {os.path.basename(env_file_path)}\n")
        except Exception:
            pass
        f.write("""```

## .env (vollstaendig)

```dotenv
""")
        if os.path.isfile(env_dot):
            try:
                with open(env_dot, "r") as ef:
                    f.write(ef.read())
            except Exception:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# .env fehlt\n")
        f.write("""```

## gateway.systemd.env (vollstaendig)

```dotenv
""")
        if os.path.isfile(env_systemd):
            try:
                with open(env_systemd, "r") as ef:
                    f.write(ef.read())
            except Exception:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# gateway.systemd.env fehlt\n")
        f.write("```\n")
    
    # Run file
    script_path = os.path.abspath(__file__)
    with open(run_file, "w") as f:
        f.write(f"""# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): {now_local}
- Zeit (UTC): {now_utc}
- Script: {script_path}

## Erzeugte Dateien

- {os.path.basename(ist_file)}
- {os.path.basename(inv_file)}
- {os.path.basename(cfg_file)}
- {os.path.basename(env_file)}
""")
    
    print("OK: IST-Zustand erfasst.")
    try:
        for item in sorted(os.listdir(out_dir)):
            print(f"- {item}")
    except Exception:
        pass

if __name__ == "__main__":
    main()
