#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8adc438199406ab2d7a23961bf364087632e6ad8ea7825a7ba8d5d45b20fb171", "source_sha256": "fb758d6839889536b8c614e3eeae8bf16b595283b7e0b680d6bbb9606448105e", "target_language": "python"}
# recover-orphaned-processes.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/recover-orphaned-processes.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import json
import os
import re
import subprocess
import sys
from datetime import datetime

def usage():
    print("Usage: recover-orphaned-processes.sh\n\nScans for likely orphaned coding agent processes and prints JSON.", file=sys.stderr)

def run_file(file, args):
    try:
        result = subprocess.run([file] + args, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        return result.stdout
    except Exception:
        return ""

def resolve_started(pid):
    started = run_file("ps", ["-o", "lstart=", "-p", str(pid)]).strip()
    return started if started else "unknown"

def resolve_cwd(pid):
    if sys.platform == "linux":
        try:
            return os.readlink(f"/proc/{pid}/cwd")
        except Exception:
            return "unknown"
    lsof = run_file("lsof", ["-a", "-d", "cwd", "-p", str(pid), "-Fn"])
    match = re.search(r"^n(.+)$", lsof, re.MULTILINE)
    return match.group(1) if match else "unknown"

def sanitize_command(cmd):
    cmd = re.sub(r"(--(?:token|api[-_]?key|password|secret|authorization)\s+)([^\s]+)", r"\1<redacted>", cmd, flags=re.IGNORECASE)
    cmd = re.sub(r"((?:token|api[-_]?key|password|secret|authorization)=)([^\s]+)", r"\1<redacted>", cmd, flags=re.IGNORECASE)
    cmd = re.sub(r"(Bearer\s+)[A-Za-z0-9._~+/=-]+", r"\1<redacted>", cmd)
    return cmd

def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--help", "-h"):
        usage()
        sys.exit(0)
    
    if len(sys.argv) > 1:
        usage()
        sys.exit(2)
    
    if not shutil.which("node"):
        ts = "unknown"
        try:
            ts = subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
        except Exception:
            pass
        print(json.dumps({"error": "node not found on PATH", "orphaned": [], "ts": ts}))
        sys.exit(0)
    
    username = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    if username and not re.match(r"^[a-zA-Z0-9._-]+$", username):
        username = ""
    
    pgrep_unavailable = False
    pgrep_result = ""
    args = ["-u", username, "-f", "codex|claude"] if username else ["-f", "codex|claude"]
    
    try:
        pgrep_result = subprocess.check_output(["pgrep"] + args, text=True, stdin=subprocess.DEVNULL)
    except FileNotFoundError:
        pgrep_unavailable = True
        pgrep_result = ""
    except subprocess.CalledProcessError as e:
        if isinstance(e.stdout, str):
            pgrep_result = e.stdout
    
    candidate_pids = [s.strip() for s in pgrep_result.split("\n") if s.strip() and s.strip().isdigit()]
    
    if candidate_pids:
        lines = run_file("ps", ["-o", "pid=,command=", "-p", ",".join(candidate_pids)]).split("\n")
    elif pgrep_unavailable and username:
        lines = run_file("ps", ["-U", username, "-o", "pid=,command="]).split("\n")
    elif pgrep_unavailable:
        lines = run_file("ps", ["-axo", "pid=,command="]).split("\n")
    else:
        lines = []
    
    include_pattern = re.compile(r"codex|claude", re.IGNORECASE)
    exclude_patterns = [
        re.compile(r"openclaw-gateway", re.IGNORECASE),
        re.compile(r"signal-cli", re.IGNORECASE),
        re.compile(r"node_modules/\.bin/openclaw", re.IGNORECASE),
        re.compile(r"recover-orphaned-processes\.sh", re.IGNORECASE),
    ]
    
    orphaned = []
    
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        match = re.match(r"^(\d+)\s+(.+)$", line)
        if not match:
            continue
        
        pid = int(match.group(1))
        cmd = match.group(2)
        if pid <= 0 or pid == os.getpid():
            continue
        if not include_pattern.search(cmd):
            continue
        if any(pattern.search(cmd) for pattern in exclude_patterns):
            continue
        
        orphaned.append({
            "pid": pid,
            "cmd": sanitize_command(cmd),
            "cwd": resolve_cwd(pid),
            "started": resolve_started(pid),
        })
    
    print(json.dumps({
        "orphaned": orphaned,
        "ts": datetime.utcnow().isoformat() + "Z",
    }))

if __name__ == "__main__":
    import shutil
    main()
