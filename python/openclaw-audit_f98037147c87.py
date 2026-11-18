#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d2a61c64e59c49c447bca6fb990a886a841554c80b20d690f2146bd03c5b9428", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "python"}
# openclaw-audit.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import datetime
import socket

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def get_date_stamp():
    return datetime.datetime.now().strftime("%Y-%m-%d")

def get_out_file(script_dir, date_stamp):
    return os.path.join(script_dir, f"openclaw-audit-{date_stamp}.log")

def write_header(out_file):
    with open(out_file, 'w') as f:
        f.write("================================================================\n")
        f.write("OpenClaw audit run\n")
        f.write(f"Started:  {datetime.datetime.now().isoformat()}\n")
        f.write(f"Host:     {socket.gethostname()}\n")
        f.write(f"User:     {os.getenv('USER') or os.getenv('USERNAME')}\n")
        try:
            version = subprocess.check_output(["openclaw", "--version"], stderr=subprocess.STDOUT, text=True).strip()
        except subprocess.CalledProcessError:
            version = "unknown"
        f.write(f"Version:  {version}\n")
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
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, text=True)
            exit_code = result.returncode
        except Exception as e:
            f.write(f"[error: {str(e)}]\n")
            exit_code = 1
        
        f.write(f"[exit: {exit_code}]\n")

def main():
    script_dir = get_script_dir()
    date_stamp = get_date_stamp()
    out_file = get_out_file(script_dir, date_stamp)
    
    write_header(out_file)
    
    oc_base = ["openclaw", "--no-color"]
    
    commands = [
        ("tasks audit --severity error", oc_base + ["tasks", "audit", "--severity", "error"]),
        ("secrets audit", oc_base + ["secrets", "audit"]),
        ("security audit", oc_base + ["security", "audit"]),
        ("plugins doctor", oc_base + ["plugins", "doctor"]),
        ("plugins deps", oc_base + ["plugins", "deps"]),
        ("plugins registry", oc_base + ["plugins", "registry"]),
        ("skills check", oc_base + ["skills", "check"]),
        ("hooks check", oc_base + ["hooks", "check"]),
        ("gateway status --deep", oc_base + ["gateway", "status", "--deep"]),
        ("channels status --probe", oc_base + ["channels", "status", "--probe"]),
        ("memory status --deep", oc_base + ["memory", "status", "--deep"]),
        ("sessions --all-agents", oc_base + ["sessions", "--all-agents"]),
        ("tasks list", oc_base + ["tasks", "list"]),
        ("cron list", oc_base + ["cron", "list"])
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
