#!/usr/bin/env python3
# openclaw-audit.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import datetime
import os
import sys

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def get_date_stamp():
    return datetime.datetime.now().strftime('%Y-%m-%d')

def get_output_file():
    script_dir = get_script_dir()
    date_stamp = get_date_stamp()
    return os.path.join(script_dir, f'openclaw-audit-{date_stamp}.log')

def write_header(out_file):
    with open(out_file, 'w') as f:
        f.write("================================================================\n")
        f.write("OpenClaw audit run\n")
        f.write(f"Started:  {datetime.datetime.now().isoformat()}\n")
        f.write(f"Host:     {subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()}\n")
        f.write(f"User:     {subprocess.run(['whoami'], capture_output=True, text=True).stdout.strip()}\n")
        
        try:
            version = subprocess.run(['openclaw', '--version'], capture_output=True, text=True)
            version_str = version.stdout.strip() if version.returncode == 0 else 'unknown'
        except FileNotFoundError:
            version_str = 'unknown'
            
        f.write(f"Version:  {version_str}\n")
        f.write(f"Output:   {out_file}\n")
        f.write("================================================================\n")

def run_cmd(title, cmd, out_file):
    with open(out_file, 'a') as f:
        f.write("\n")
        f.write("----------------------------------------------------------------\n")
        f.write(f"### {title}\n")
        f.write(f"### $ {' '.join(cmd)}\n")
        f.write(f"### {datetime.datetime.now().isoformat()}\n")
        f.write("----------------------------------------------------------------\n")
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            f.write(result.stdout)
            if result.stderr:
                f.write(result.stderr)
            f.write(f"[exit: {result.returncode}]\n")
        except Exception as e:
            f.write(f"[error: {str(e)}]\n")

def main():
    out_file = get_output_file()
    write_header(out_file)
    
    oc_base = ['openclaw', '--no-color']
    
    commands = [
        ("tasks audit --severity error", oc_base + ['tasks', 'audit', '--severity', 'error']),
        ("secrets audit", oc_base + ['secrets', 'audit']),
        ("security audit", oc_base + ['security', 'audit']),
        ("plugins doctor", oc_base + ['plugins', 'doctor']),
        ("plugins deps", oc_base + ['plugins', 'deps']),
        ("plugins registry", oc_base + ['plugins', 'registry']),
        ("skills check", oc_base + ['skills', 'check']),
        ("hooks check", oc_base + ['hooks', 'check']),
        ("gateway status --deep", oc_base + ['gateway', 'status', '--deep']),
        ("channels status --probe", oc_base + ['channels', 'status', '--probe']),
        ("memory status --deep", oc_base + ['memory', 'status', '--deep']),
        ("sessions --all-agents", oc_base + ['sessions', '--all-agents']),
        ("tasks list", oc_base + ['tasks', 'list']),
        ("cron list", oc_base + ['cron', 'list'])
    ]
    
    for title, cmd in commands:
        run_cmd(title, cmd, out_file)
    
    with open(out_file, 'a') as f:
        f.write("\n")
        f.write("================================================================\n")
        f.write(f"Audit complete: {datetime.datetime.now().isoformat()}\n")
        f.write("================================================================\n")
    
    print(f"Audit complete. Output: {out_file}")

if __name__ == "__main__":
    main()
