#!/usr/bin/env python3
# collect_ist_gateway_b.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import json
import urllib.request
from datetime import datetime
from pathlib import Path

def run_command(cmd, shell=False):
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            shell=shell,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None
    except Exception:
        return None

def get_hostname_fqdn():
    fqdn = run_command(['hostname', '-f'])
    if not fqdn:
        fqdn = run_command(['hostname'])
    return fqdn

def get_os_pretty_name():
    try:
        with open('/etc/os-release', 'r') as f:
            for line in f:
                if line.startswith('PRETTY_NAME='):
                    return line.split('=', 1)[1].strip().strip('"')
    except FileNotFoundError:
        pass
    return ''

def get_public_ip():
    try:
        req = urllib.request.Request(
            'http://ifconfig.me',
            headers={'User-Agent': 'curl/7.0'}
        )
        with urllib.request.urlopen(req, timeout=4) as response:
            return response.read().decode().strip()
    except Exception:
        return None

def get_tailscale_ip():
    ip = run_command(['tailscale', 'ip', '-4'])
    if ip:
        return ip.split('\n')[0]
    return None

def main():
    home = os.path.expanduser('~')
    base_dir = os.path.join(home, '.openclaw')
    out_dir = os.path.join(base_dir, 'workspace', 'vscode')
    
    os.makedirs(out_dir, exist_ok=True)
    
    now_utc = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    now_local = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    
    ist_file = os.path.join(out_dir, 'IST-ZUSTAND_GATEWAY-B_NODE7.md')
    inv_file = os.path.join(out_dir, 'ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md')
    cfg_file = os.path.join(out_dir, 'OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md')
    env_file = os.path.join(out_dir, 'ENV-STATUS_GATEWAY-B_NODE7.md')
    run_file = os.path.join(out_dir, f'RUN-{ts}.md')
    
    openclaw_json = os.path.join(base_dir, 'openclaw.json')
    env_dot = os.path.join(base_dir, '.env')
    env_systemd = os.path.join(base_dir, 'gateway.systemd.env')
    vscode_dir = os.path.join(base_dir, '.vscode')
    
    hostname_fqdn = get_hostname_fqdn() or ''
    hostname_short = run_command(['hostname']) or ''
    arch = run_command(['uname', '-m']) or ''
    kernel = run_command(['uname', '-r']) or ''
    os_pretty = get_os_pretty_name()
    ipv4_all = run_command(['hostname', '-I'])
    if ipv4_all:
        ipv4_all = ' '.join(ipv4_all.split())
    else:
        ipv4_all = ''
    
    public_ip = get_public_ip()
    tailscale_ip = get_tailscale_ip()
    openclaw_ver = run_command(['openclaw', '--version'])
    node_ver = run_command(['node', '-v'])
    
    if not public_ip:
        public_ip = '(nicht ermittelt)'
    if not tailscale_ip:
        tailscale_ip = '(nicht ermittelt)'
    if not openclaw_ver:
        openclaw_ver = '(nicht ermittelt)'
    if not node_ver:
        node_ver = '(nicht ermittelt)'
    
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

- `{openclaw_json}`: {"vorhanden" if os.path.isfile(openclaw_json) else "fehlt"}
- `{env_dot}`: {"vorhanden" if os.path.isfile(env_dot) else "fehlt"}
- `{env_systemd}`: {"vorhanden" if os.path.isfile(env_systemd) else "fehlt"}
- `{base_dir}/plugins/installs.json`: {"vorhanden" if os.path.isfile(os.path.join(base_dir, 'plugins', 'installs.json')) else "fehlt"}
- `{base_dir}/plugin-skills`: {"vorhanden" if os.path.isdir(os.path.join(base_dir, 'plugin-skills')) else "fehlt"}

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt.
''')
    
    # Artefakt-Inventar
    def safe_listdir(path):
        try:
            return sorted(os.listdir(path))
        except OSError:
            return []
    
    def safe_listdir_detailed(path):
        try:
            result = subprocess.run(
                ['ls', '-la', path],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError:
            return "(nicht vorhanden)"
        except Exception:
            return "(nicht vorhanden)"
    
    with open(inv_file, 'w') as f:
        f.write(f'''# Artefakt-Inventar: Gateway B / Node 7

Stand: {now_local}

## Top-Level in ~/.openclaw

```
''')
        for item in safe_listdir(base_dir):
            f.write(f'{item}\n')
        
        f.write('''```

## ~/.openclaw/.vscode

```
''')
        if os.path.isdir(vscode_dir):
            f.write(safe_listdir_detailed(vscode_dir))
        else:
            f.write("(nicht vorhanden)")
        
        f.write('''```

## plugin-skills/

```
''')
        plugin_skills_dir = os.path.join(base_dir, 'plugin-skills')
        if os.path.isdir(plugin_skills_dir):
            for item in safe_listdir(plugin_skills_dir):
                f.write(f'{item}\n')
        else:
            f.write("(nicht vorhanden)")
        
        f.write('''```

## openclaw.json Backups

```
''')
        backup_files = []
        try:
            for file in os.listdir(base_dir):
                if file.startswith('openclaw.json.bak'):
                    backup_files.append(file)
            backup_files.sort()
        except OSError:
            pass
        
        if backup_files:
            for bf in backup_files:
                f.write(f'{bf}\n')
        else:
            f.write("(keine gefunden)")
        
        f.write('```\n')
    
    # Config Snapshot
    def extract_lines_from_file(filepath, start, end):
        try:
            with open(filepath, 'r') as file:
                lines = file.readlines()
                return ''.join(lines[start-1:end])
        except Exception:
            return ''
    
    with open(cfg_file, 'w') as f:
        f.write(f'''# OpenClaw Config Snapshot: Gateway B / Node 7

Stand: {now_local}

## Schlüsselpositionen (grep)

```
''')
        if os.path.isfile(openclaw_json):
            try:
                result = subprocess.run(
                    ['grep', '-nE', '"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"', openclaw_json],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    check=True
                )
                f.write(result.stdout)
            except subprocess.CalledProcessError:
                pass
            except Exception:
                pass
        else:
            f.write("openclaw.json fehlt\n")
        
        f.write('''```

## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)

```json
''')
        if os.path.isfile(openclaw_json):
            snippet = extract_lines_from_file(openclaw_json, 580, 780)
            if snippet:
                f.write(snippet)
            else:
                f.write("{}\n")
        else:
            f.write('{{ "error": "openclaw.json fehlt" }}\n')
        
        f.write('```\n')
    
    # ENV-Status
    def safe_ls_la(files):
        try:
            cmd = ['ls', '-la'] + [f for f in files if os.path.exists(f)]
            if not cmd[2:]:  # no existing files
                return ""
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError:
            return ""
        except Exception:
            return ""
    
    def safe_cat(filepath):
        try:
            with open(filepath, 'r') as file:
                return file.read()
        except Exception:
            return ""
    
    with open(env_file, 'w') as f:
        f.write(f'''# ENV-Status: Gateway B / Node 7

Stand: {now_local}

## Dateien

```
''')
        ls_output = safe_ls_la([env_dot, env_systemd])
        if ls_output:
            f.write(ls_output)
        
        f.write('''```

## .env (vollständig, ungefiltert)

```dotenv
''')
        if os.path.isfile(env_dot):
            f.write(safe_cat(env_dot))
        else:
            f.write("# .env fehlt\n")
        
        f.write('''```

## gateway.systemd.env (vollständig, ungefiltert)

```dotenv
''')
        if os.path.isfile(env_systemd):
            f.write(safe_cat(env_systemd))
        else:
            f.write("# gateway.systemd.env fehlt\n")
        
        f.write('```\n')
    
    # Run File
    script_path = os.path.realpath(__file__)
    with open(run_file, 'w') as f:
        f.write(f'''# Laufprotokoll Gateway B / Node 7

- Zeit (lokal): {now_local}
- Zeit (UTC): {now_utc}
- Script: {script_path}

## Erzeugte Dateien

- {os.path.basename(ist_file)}
- {os.path.basename(inv_file)}
- {os.path.basename(cfg_file)}
- {os.path.basename(env_file)}

''')
    
    print("OK: IST-Zustand erfasst.")
    print(f"Ausgabeordner: {out_dir}")
    print("Dateien:")
    try:
        for item in sorted(os.listdir(out_dir)):
            print(f"- {item}")
    except OSError:
        pass

if __name__ == '__main__':
    main()
