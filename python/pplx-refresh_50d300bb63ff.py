#!/usr/bin/env python3.12
# abstraction-provenance: {"artifact_sha256": "76202af8dbd9b0d6c36ae2e2d36ea3fddaede9ccc46e2ebf5de0b4b943fb819c", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "python"}
# pplx-refresh.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import json
import os
import subprocess
import sys
import time
from pathlib import Path

def main():
    if len(sys.argv) > 2:
        print("Usage: pplx-refresh.py [cookie-file]")
        sys.exit(1)
    
    cookie_file = Path(sys.argv[1]) if len(sys.argv) == 2 else Path.home() / "pplx-cookies.txt"
    
    if not cookie_file.exists() or cookie_file.stat().st_size == 0:
        print(f"✗ Cookie file empty/missing: {cookie_file}")
        print("  Export __Secure-next-auth.session-token from your local browser")
        print("  (DevTools → Application → Cookies → www.perplexity.ai) into that file.")
        sys.exit(1)
    
    here = Path(__file__).parent.resolve()
    cfg_dir = Path(os.environ.get("PERPLEXITY_CONFIG_DIR", Path.home() / ".perplexity-mcp"))
    profile = os.environ.get("PERPLEXITY_PROFILE", "codespace")
    
    # 1. Ensure the extension daemon has a usable browser
    subprocess.run([here / "pplx-setup.sh"], check=True)
    
    # 2. Get daemon pid + vault passphrase
    lock_file = cfg_dir / "daemon.lock"
    if not lock_file.exists():
        print(f"✗ no daemon.lock at {lock_file} — is the extension running?")
        sys.exit(1)
    
    with open(lock_file) as f:
        pid = json.load(f)["pid"]
    
    try:
        subprocess.run(["ps", "-p", str(pid), "-o", "pid="], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print(f"✗ daemon pid {pid} not running")
        sys.exit(1)
    
    try:
        with open(f"/proc/{pid}/environ", "rb") as f:
            env_data = f.read().replace(b'\x00', b'\n').decode()
            pass_line = [line for line in env_data.split('\n') if line.startswith("PERPLEXITY_VAULT_PASSPHRASE=")]
            if not pass_line:
                print("✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env")
                sys.exit(1)
            passphrase = pass_line[0].split("=", 1)[1]
    except FileNotFoundError:
        print(f"✗ cannot read environment for pid {pid}")
        sys.exit(1)
    
    # 3. Locate the perplexity-user-mcp dist
    npx_cache = Path.home() / ".npm" / "_npx"
    dist_dirs = []
    if npx_cache.exists():
        for root, dirs, files in os.walk(npx_cache):
            if "perplexity-user-mcp" in root and "dist" in dirs:
                dist_dirs.append(Path(root) / "dist")
    
    if not dist_dirs:
        try:
            subprocess.run(["npx", "-y", "perplexity-user-mcp", "--version"], 
                          check=True, capture_output=True)
        except subprocess.CalledProcessError:
            pass
        
        if npx_cache.exists():
            for root, dirs, files in os.walk(npx_cache):
                if "perplexity-user-mcp" in root and "dist" in dirs:
                    dist_dirs.append(Path(root) / "dist")
    
    if not dist_dirs:
        print("✗ could not find perplexity-user-mcp dist directory")
        sys.exit(1)
    
    dist_path = dist_dirs[0]
    
    # 4. Inject
    env = os.environ.copy()
    env.update({
        "PERPLEXITY_VAULT_PASSPHRASE": passphrase,
        "PERPLEXITY_CONFIG_DIR": str(cfg_dir),
        "PERPLEXITY_PROFILE": profile,
        "PPLX_DIST": str(dist_path)
    })
    
    subprocess.run(["node", str(here / "pplx-inject.mjs"), str(cookie_file)], 
                  env=env, check=True)
    
    # 5. Trigger daemon reinit
    reinit_file = cfg_dir / "profiles" / profile / ".reinit"
    reinit_file.parent.mkdir(parents=True, exist_ok=True)
    reinit_file.write_text(str(int(time.time())))
    print("→ reinit triggered, waiting for daemon...")
    
    # 6. Verify
    status_file = cfg_dir / "profiles" / profile / "daemon-status.json"
    for i in range(20):
        time.sleep(1.5)
        try:
            if status_file.exists():
                with open(status_file) as f:
                    status_data = json.load(f)
                authenticated = status_data.get("authenticated")
                tier = status_data.get("tier")
                if authenticated is True:
                    print(f"✅ authenticated — tier: {tier}")
                    sys.exit(0)
        except (json.JSONDecodeError, IOError):
            pass
    
    print(f"⚠️  not authenticated yet. Check: tail -20 {cfg_dir / 'daemon.log'}")
    sys.exit(1)

if __name__ == "__main__":
    main()
