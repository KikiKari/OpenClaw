#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f7093d9f24c779b35f51fec7acfbc7c73af426fbd44b95b8b29a6906345cedd8", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "python"}
# collect_ist_gateway_b.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import socket
import platform
import subprocess
import urllib.request
from datetime import datetime
from pathlib import Path

def run_command(cmd, shell=False, default=''):
    try:
        if isinstance(cmd, str):
            cmd = cmd.split()
        result = subprocess.run(cmd, capture_output=True, text=True, shell=shell)
        return result.stdout.strip() if result.returncode == 0 else default
    except Exception:
        return default

def get_hostname_fqdn():
    try:
        return socket.getfqdn()
    except:
        return platform.node()

def get_public_ip():
    try:
        with urllib.request.urlopen('https://ifconfig.me', timeout=4) as response:
            return response.read().decode().strip()
    except:
        return '(nicht ermittelt)'

def get_tailscale_ip():
    try:
        result = subprocess.run(['tailscale', 'ip', '-4'], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip().split('\n')[0]
        return '(nicht ermittelt)'
    except:
        return '(nicht ermittelt)'

def main():
    base_dir = Path(os.environ.get('HOME')) / '.openclaw'
    out_dir = base_dir / 'workspace' / 'vscode'
    out_dir.mkdir(parents=True, exist_ok=True)
    
    now_utc = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    now_local = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    
    ist_file = out_dir / f'IST-ZUSTAND_GATEWAY-B_NODE7.md'
    inv_file = out_dir / f'ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md'
    cfg_file = out_dir / f'OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md'
    env_file = out_dir / f'ENV-STATUS_GATEWAY-B_NODE7.md'
    run_file = out_dir / f'RUN-{ts}.md'
    
    openclaw_json = base_dir / 'openclaw.json'
    env_dot = base_dir / '.env'
    env_systemd = base_dir / 'gateway.systemd.env'
    vscode_dir = base_dir / '.vscode'
    
    hostname_fqdn = get_hostname_fqdn()
    hostname_short = platform.node()
    arch = platform.machine()
    kernel = platform.release()
    
    os_pretty = '(nicht ermittelt)'
    try:
        with open('/etc/os-release', 'r') as f:
            for line in f:
                if line.startswith('PRETTY_NAME='):
                    os_pretty = line.split('=', 1)[1].strip().strip('"')
                    break
    except:
        pass
    
    ipv4_all = run_command('hostname -I').replace('\n', ' ').strip()
    public_ip = get_public_ip()
    tailscale_ip = get_tailscale_ip()
    openclaw_ver = run_command(['openclaw', '--version'], default='(nicht ermittelt)')
    node_ver = run_command(['node', '-v'], default='(nicht ermittelt)')
    
    # IST-Zustand
    with open(ist_file, 'w') as f:
        f.write(f'''# IST-Zustand: Gateway B / Node 7

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

- `{openclaw_json}`: {"vorhanden" if openclaw_json.exists() else "fehlt"}
- `{env_dot}`: {"vorhanden" if env_dot.exists() else "fehlt"}
- `{env_systemd}`: {"vorhanden" if env_systemd.exists() else "fehlt"}
- `{base_dir}/plugins/installs.json`: {"vorhanden" if (base_dir / 'plugins/installs.json').exists() else "fehlt"}
- `{base_dir}/plugin-skills`: {"vorhanden" if (base_dir / 'plugin-skills').exists() else "fehlt"}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
''')
    
    # Artefakt-Inventar
    with open(inv_file, 'w') as f:
        f.write(f'''# Artefakt-Inventar: Gateway B / Node 7

Stand: {now_local}

## Top-Level in ~/.openclaw

```
''')
        try:
            for item in sorted(base_dir.iterdir()):
                f.write(f'{item.name}\n')
        except:
            pass
        f.write('''```

## ~/.openclaw/.vscode

```
''')
        if vscode_dir.exists():
            try:
                result = subprocess.run(['ls', '-la', str(vscode_dir)], capture_output=True, text=True)
                f.write(result.stdout)
            except:
                f.write('(Fehler beim Lesen)\n')
        else:
            f.write('(nicht vorhanden)\n')
        f.write('''```

## plugin-skills/

```
''')
        plugin_skills = base_dir / 'plugin-skills'
        if plugin_skills.exists():
            try:
                result = subprocess.run(['ls', '-1', str(plugin_skills)], capture_output=True, text=True)
                f.write(result.stdout)
            except:
                f.write('(Fehler beim Lesen)\n')
        else:
            f.write('(nicht vorhanden)\n')
        f.write('''```

## openclaw.json Backups

```
''')
        try:
            backup_files = list(base_dir.glob('openclaw.json.bak*'))
            if backup_files:
                for file in sorted(backup_files):
                    f.write(f'{file.name}\n')
            else:
                f.write('(keine gefunden)\n')
        except:
            f.write('(keine gefunden)\n')
        f.write('```')
    
    # Config Snapshot
    with open(cfg_file, 'w') as f:
        f.write(f'''# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: {now_local}

## Schlüsselpositionen (grep)

```
''')
        if openclaw_json.exists():
            try:
                with open(openclaw_json, 'r') as json_file:
                    content = json_file.read()
                    keywords = ['"gateway"', '"session"', '"dmScope"', '"auth"', '"secrets"', '"tools"', '"plugins"', '"profile"', '"alsoAllow"', '"denyCommands"']
                    lines = content.split('\n')
                    for i, line in enumerate(lines, 1):
                        for keyword in keywords:
                            if keyword in line:
                                f.write(f'{i}:{line}\n')
            except:
                pass
        else:
            f.write('openclaw.json fehlt\n')
        f.write('''```

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

```json
''')
        if openclaw_json.exists():
            try:
                with open(openclaw_json, 'r') as json_file:
                    lines = json_file.readlines()
                    for line in lines[579:780]:  # 580-780 lines (0-indexed)
                        f.write(line)
            except:
                f.write('{ "error": "openclaw.json fehlt" }\n')
        else:
            f.write('{ "error": "openclaw.json fehlt" }\n')
        f.write('```')
    
    # ENV-Status
    with open(env_file, 'w') as f:
        f.write(f'''# ENV-Status: Gateway B / Node 7

Stand: {now_local}

## Dateien

```
''')
        try:
            result = subprocess.run(['ls', '-la', str(env_dot), str(env_systemd)], capture_output=True, text=True)
            f.write(result.stdout)
        except:
            pass
        f.write('''```

## .env (vollständig, ungefiltert)

```dotenv
''')
        if env_dot.exists():
            try:
                with open(env_dot, 'r') as env_file_content:
                    f.write(env_file_content.read())
            except:
                f.write('# Fehler beim Lesen\n')
        else:
            f.write('# .env fehlt\n')
        f.write('''```

## gateway.systemd.env (vollständig, ungefiltert)

```dotenv
''')
        if env_systemd.exists():
            try:
                with open(env_systemd, 'r') as systemd_env_content:
                    f.write(systemd_env_content.read())
            except:
                f.write('# Fehler beim Lesen\n')
        else:
            f.write('# gateway.systemd.env fehlt\n')
        f.write('```')
    
    # Run File
    script_path = os.path.realpath(__file__)
    with open(run_file, 'w') as f:
        f.write(f'''# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): {now_local}
- Zeit (UTC): {now_utc}
- Script: {script_path}

## Erzeugte Dateien

- {ist_file.name}
- {inv_file.name}
- {cfg_file.name}
- {env_file.name}
''')
    
    print("OK: IST-Zustand erfasst.")
    print(f"Ausgabeordner: {out_dir}")
    print("Dateien:")
    try:
        for item in sorted(out_dir.iterdir()):
            print(f"- {item.name}")
    except:
        pass

if __name__ == '__main__':
    main()
