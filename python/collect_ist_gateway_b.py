#!/usr/bin/env python3
# collect_ist_gateway_b.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import json
import socket
from datetime import datetime
from pathlib import Path

def run_command(cmd, shell=False, fallback=None):
    try:
        if isinstance(cmd, str) and not shell:
            cmd = cmd.split()
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            shell=shell,
            timeout=10
        )
        return result.stdout.strip() if result.returncode == 0 else (fallback or "")
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        return fallback or ""

def check_file_exists(path):
    return "vorhanden" if Path(path).exists() else "fehlt"

def main():
    # Environment setup
    home = Path.home()
    base_dir = home / ".openclaw"
    out_dir = base_dir / "workspace" / "vscode"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    now_utc = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    now_local = datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # File paths
    ist_file = out_dir / "IST-ZUSTAND_GATEWAY-B_NODE7.md"
    inv_file = out_dir / "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
    cfg_file = out_dir / "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
    env_file = out_dir / "ENV-STATUS_GATEWAY-B_NODE7.md"
    run_file = out_dir / f"RUN-{ts}.md"
    
    openclaw_json = base_dir / "openclaw.json"
    env_dot = base_dir / ".env"
    env_systemd = base_dir / "gateway.systemd.env"
    vscode_dir = base_dir / ".vscode"
    
    # System information gathering
    hostname_fqdn = run_command(["hostname", "-f"], fallback=socket.gethostname())
    hostname_short = socket.gethostname()
    arch = run_command(["uname", "-m"])
    kernel = run_command(["uname", "-r"])
    
    os_pretty = "Unknown"
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    os_pretty = line.split("=", 1)[1].strip().strip('"')
                    break
    except FileNotFoundError:
        pass
    
    ipv4_all = run_command(["hostname", "-I"]).replace("\n", " ").strip()
    public_ip = run_command(["curl", "-4", "-s", "--max-time", "4", "ifconfig.me"], fallback="(nicht ermittelt)")
    tailscale_ip = run_command(["tailscale", "ip", "-4"], fallback="(nicht ermittelt)").split("\n")[0]
    openclaw_ver = run_command(["openclaw", "--version"], fallback="(nicht ermittelt)")
    node_ver = run_command(["node", "-v"], fallback="(nicht ermittelt)")
    
    # Ensure non-empty values
    public_ip = public_ip or "(nicht ermittelt)"
    tailscale_ip = tailscale_ip or "(nicht ermittelt)"
    openclaw_ver = openclaw_ver or "(nicht ermittelt)"
    node_ver = node_ver or "(nicht ermittelt)"
    
    # Generate IST-Zustand file
    with open(ist_file, "w") as f:
        f.write(f"""# IST-Zustand: Gateway B / Node 7

Stand (lokal): {now_local}  
Stand (UTC): {now_utc}

## 1) Identität & System

- Gateway: **B**
- Node: **7**
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

- `{openclaw_json}`: {check_file_exists(openclaw_json)}
- `{env_dot}`: {check_file_exists(env_dot)}
- `{env_systemd}`: {check_file_exists(env_systemd)}
- `{base_dir}/plugins/installs.json`: {check_file_exists(base_dir / "plugins/installs.json")}
- `{base_dir}/plugin-skills`: {check_file_exists(base_dir / "plugin-skills")}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
""")
    
    # Generate Artefakt-Inventar
    with open(inv_file, "w") as f:
        f.write(f"""# Artefakt-Inventar: Gateway B / Node 7

Stand: {now_local}

## Top-Level in ~/.openclaw

```text
""")
        try:
            for item in sorted(base_dir.iterdir()):
                f.write(f"{item.name}\n")
        except FileNotFoundError:
            pass
        f.write("""```

## ~/.openclaw/.vscode

```text
""")
        if vscode_dir.exists():
            try:
                for item in sorted(vscode_dir.iterdir()):
                    mode = "d" if item.is_dir() else "-"
                    f.write(f"{mode} {item.name}\n")
            except FileNotFoundError:
                f.write("(leer)\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## plugin-skills/

```text
""")
        skills_dir = base_dir / "plugin-skills"
        if skills_dir.exists():
            try:
                for item in sorted(skills_dir.iterdir()):
                    f.write(f"{item.name}\n")
            except FileNotFoundError:
                f.write("(leer)\n")
        else:
            f.write("(nicht vorhanden)\n")
        f.write("""```

## openclaw.json Backups

```text
""")
        backup_files = list(base_dir.glob("openclaw.json.bak*"))
        if backup_files:
            for bf in sorted(backup_files):
                f.write(f"{bf.name}\n")
        else:
            f.write("(keine gefunden)\n")
        f.write("```\n")
    
    # Generate Config Snapshot
    with open(cfg_file, "w") as f:
        f.write(f"""# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: {now_local}

## Schlüsselpositionen (grep)

```text
""")
        if openclaw_json.exists():
            try:
                with open(openclaw_json) as json_file:
                    lines = json_file.readlines()
                    for i, line in enumerate(lines, 1):
                        if any(keyword in line for keyword in [
                            '"gateway"', '"session"', '"dmScope"', '"auth"',
                            '"secrets"', '"tools"', '"plugins"', '"profile"',
                            '"alsoAllow"', '"denyCommands"'
                        ]):
                            f.write(f"{i:3d}: {line.rstrip()}\n")
            except Exception:
                f.write("(Fehler beim Lesen)\n")
        else:
            f.write("openclaw.json fehlt\n")
        f.write("""```

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

```json
""")
        if openclaw_json.exists():
            try:
                with open(openclaw_json) as json_file:
                    lines = json_file.readlines()
                    for line in lines[579:780]:  # 580-780 lines (0-indexed)
                        f.write(line)
            except Exception:
                f.write('{{ "error": "Lesefehler" }}\n')
        else:
            f.write('{{ "error": "openclaw.json fehlt" }}\n')
        f.write("```\n")
    
    # Generate ENV-Status
    with open(env_file, "w") as f:
        f.write(f"""# ENV-Status: Gateway B / Node 7

Stand: {now_local}

## Dateien

```text
""")
        try:
            stat_dot = env_dot.stat() if env_dot.exists() else None
            stat_systemd = env_systemd.stat() if env_systemd.exists() else None
            if stat_dot:
                f.write(f"-r--r--r-- 1 user group {stat_dot.st_size} {datetime.fromtimestamp(stat_dot.st_mtime):%b %d %H:%M} {env_dot.name}\n")
            if stat_systemd:
                f.write(f"-r--r--r-- 1 user group {stat_systemd.st_size} {datetime.fromtimestamp(stat_systemd.st_mtime):%b %d %H:%M} {env_systemd.name}\n")
        except Exception:
            pass
        f.write("""```

## .env (vollständig, ungefiltert)

```dotenv
""")
        if env_dot.exists():
            try:
                with open(env_dot) as env_file_content:
                    f.write(env_file_content.read())
            except Exception:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# .env fehlt\n")
        f.write("""```

## gateway.systemd.env (vollständig, ungefiltert)

```dotenv
""")
        if env_systemd.exists():
            try:
                with open(env_systemd) as systemd_env_content:
                    f.write(systemd_env_content.read())
            except Exception:
                f.write("# Fehler beim Lesen\n")
        else:
            f.write("# gateway.systemd.env fehlt\n")
        f.write("```\n")
    
    # Generate RUN file
    script_path = Path(__file__).resolve()
    with open(run_file, "w") as f:
        f.write(f"""# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): {now_local}
- Zeit (UTC): {now_utc}
- Script: {script_path}

## Erzeugte Dateien

- {ist_file.name}
- {inv_file.name}
- {cfg_file.name}
- {env_file.name}

""")
    
    # Output summary
    print("OK: IST-Zustand erfasst.")
    print(f"Ausgabeordner: {out_dir}")
    print("Dateien:")
    try:
        for item in sorted(out_dir.iterdir()):
            print(f"- {item.name}")
    except FileNotFoundError:
        pass

if __name__ == "__main__":
    main()
