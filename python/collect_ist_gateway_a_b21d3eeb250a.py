#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "6f67af8df000f8c8029f930bb257741c473427c669b2c0dff62393a4ca147346", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "python"}
# collect_ist_gateway_a.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import json
import socket
from datetime import datetime
from pathlib import Path

def run_command(cmd, shell=False, timeout=4):
    """Helper function to run shell commands safely"""
    try:
        if isinstance(cmd, str) and not shell:
            cmd = cmd.split()
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            shell=shell,
            timeout=timeout
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        return ""

def get_hostname_info():
    """Get hostname information"""
    try:
        fqdn = socket.getfqdn()
    except:
        fqdn = socket.gethostname()
    short = socket.gethostname()
    return fqdn, short

def main():
    # Environment variables
    home_dir = Path.home()
    base_dir = home_dir / ".openclaw"
    out_dir = base_dir / "workspace" / "vscode"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    now_utc = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    now_local = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # File paths
    ist_file = out_dir / f"IST-ZUSTAND_GATEWAY-A_NODE1.md"
    inv_file = out_dir / f"ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"
    cfg_file = out_dir / f"OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"
    env_file = out_dir / f"ENV-STATUS_GATEWAY-A_NODE1.md"
    run_file = out_dir / f"RUN-{ts}.md"
    
    openclaw_json = base_dir / "openclaw.json"
    env_dot = base_dir / ".env"
    env_systemd = base_dir / "gateway.systemd.env"
    vscode_dir = base_dir / ".vscode"
    
    # System information gathering
    hostname_fqdn, hostname_short = get_hostname_info()
    arch = run_command(["uname", "-m"])
    kernel = run_command(["uname", "-r"])
    
    os_pretty = "(nicht ermittelt)"
    try:
        with open("/etc/os-release", "r") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    os_pretty = line.split("=", 1)[1].strip().strip('"')
                    break
    except FileNotFoundError:
        pass
    
    ipv4_all = run_command(["hostname", "-I"]).replace("\n", " ").strip()
    public_ip = run_command(["curl", "-4", "-s", "--max-time", "4", "ifconfig.me"]) or "(nicht ermittelt)"
    tailscale_ip = run_command(["tailscale", "ip", "-4"]) or "(nicht ermittelt)"
    
    openclaw_ver = run_command(["openclaw", "--version"]) or "(nicht ermittelt)"
    node_ver = run_command(["node", "-v"]) or "(nicht ermittelt)"
    
    # IST Zustand file
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

- `{openclaw_json}`: {"vorhanden" if openclaw_json.exists() else "fehlt"}
- `{env_dot}`: {"vorhanden" if env_dot.exists() else "fehlt"}
- `{env_systemd}`: {"vorhanden" if env_systemd.exists() else "fehlt"}
- `{base_dir}/plugins/installs.json`: {"vorhanden" if (base_dir / "plugins/installs.json").exists() else "fehlt"}
- `{base_dir}/plugin-skills`: {"vorhanden" if (base_dir / "plugin-skills").exists() else "fehlt"}
""")
    
    # Artefakt Inventar file
    def list_directory(path, show_hidden=False):
        try:
            entries = []
            p = Path(path)
            if p.exists() and p.is_dir():
                for item in sorted(p.iterdir()):
                    if show_hidden or not item.name.startswith('.'):
                        entries.append(item.name)
            return entries
        except:
            return []
    
    with open(inv_file, "w") as f:
        f.write(f"""# Artefakt-Inventar: Gateway A / Node 1

Stand: {now_local}

## Top-Level in ~/.openclaw

```text
""") 
        for entry in list_directory(base_dir):
            f.write(f"{entry}\n")
        f.write("""```

## ~/.openclaw/.vscode

```text
""")
        if vscode_dir.exists():
            try:
                for item in sorted(vscode_dir.iterdir()):
                    stat = item.stat()
                    f.write(f"{'d' if item.is_dir() else '-'} {stat.st_size:>8} {item.name}\n")
            except:
                f.write("(Fehler beim Lesen)\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## plugin-skills/

```text
""")
        plugin_skills = base_dir / "plugin-skills"
        if plugin_skills.exists():
            for entry in list_directory(plugin_skills):
                f.write(f"{entry}\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## openclaw.json Backups

```text
""")
        try:
            backup_files = list(base_dir.glob("openclaw.json.bak*"))
            if backup_files:
                for bf in sorted(backup_files):
                    f.write(f"{bf.name}\n")
            else:
                f.write("(keine gefunden)\n")
        except:
            f.write("(keine gefunden)\n")
        f.write("```\n")
    
    # Config Snapshot file
    with open(cfg_file, "w") as f:
        f.write(f"""# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: {now_local}

## Schluesselpositionen (grep)

```text
""")
        if openclaw_json.exists():
            try:
                with open(openclaw_json, "r") as config_file:
                    lines = config_file.readlines()
                    for i, line in enumerate(lines, 1):
                        if any(keyword in line for keyword in ['"gateway"', '"session"', '"dmScope"', '"auth"', '"secrets"', '"tools"', '"plugins"', '"profile"', '"alsoAllow"', '"denyCommands"']):
                            f.write(f"{i}:{line.rstrip()}\n")
            except:
                f.write("Fehler beim Lesen der Konfigurationsdatei\n")
        else:
            f.write("openclaw.json fehlt\n")
        f.write("""```

## Ausschnitt gateway/session/auth

```json
""")
        if openclaw_json.exists():
            try:
                with open(openclaw_json, "r") as config_file:
                    lines = config_file.readlines()
                    # Approximate lines 580-780
                    start = max(0, 580-1)
                    end = min(len(lines), 780)
                    for line in lines[start:end]:
                        f.write(line)
            except:
                f.write('{ "error": "Fehler beim Lesen der Konfigurationsdatei" }\n')
        else:
            f.write('{ "error": "openclaw.json fehlt" }\n')
        f.write("```\n")
    
    # ENV Status file
    with open(env_file, "w") as f:
        f.write(f"""# ENV-Status: Gateway A / Node 1

Stand: {now_local}

## Dateien

```text
""")
        try:
            for env_file_path in [env_dot, env_systemd]:
                if env_file_path.exists():
                    stat = env_file_path.stat()
                    f.write(f"{'d' if env_file_path.is_dir() else '-'} {stat.st_size:>8} {env_file_path.name}\n")
        except:
            pass
        f.write("""```

## .env (vollstaendig)

```dotenv
""")
        if env_dot.exists():
            try:
                with open(env_dot, "r") as ef:
                    f.write(ef.read())
            except:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# .env fehlt\n")
        f.write("""```

## gateway.systemd.env (vollstaendig)

```dotenv
""")
        if env_systemd.exists():
            try:
                with open(env_systemd, "r") as ef:
                    f.write(ef.read())
            except:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# gateway.systemd.env fehlt\n")
        f.write("```\n")
    
    # Run file
    script_path = os.path.realpath(__file__)
    with open(run_file, "w") as f:
        f.write(f"""# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): {now_local}
- Zeit (UTC): {now_utc}
- Script: {script_path}

## Erzeugte Dateien

- {ist_file.name}
- {inv_file.name}
- {cfg_file.name}
- {env_file.name}
""")
    
    print("OK: IST-Zustand erfasst.")
    try:
        for item in sorted(out_dir.iterdir()):
            print(f"- {item.name}")
    except:
        pass

if __name__ == "__main__":
    main()
