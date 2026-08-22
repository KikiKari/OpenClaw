#!/usr/bin/env python3
# pplx-refresh.sh — portiert nach python
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.py [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

import os
import sys
import json
import subprocess
import time
import shutil

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    cfg = os.environ.get("PERPLEXITY_CONFIG_DIR", os.path.expanduser("~/.perplexity-mcp"))
    profile = os.environ.get("PERPLEXITY_PROFILE", "codespace")
    cookie_file = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/pplx-cookies.txt")

    if not os.path.isfile(cookie_file) or os.path.getsize(cookie_file) == 0:
        print("✗ Cookie file empty/missing:", cookie_file)
        print("  Export __Secure-next-auth.session-token from your local browser")
        print("  (DevTools → Application → Cookies → www.perplexity.ai) into that file.")
        sys.exit(1)

    # 1. ensure the extension daemon has a usable browser (idempotent)
    setup_script = os.path.join(here, "pplx-setup.sh")
    subprocess.run(["bash", setup_script], check=True)

    # 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
    lock = os.path.join(cfg, "daemon.lock")
    if not os.path.exists(lock):
        print(f"✗ no daemon.lock at {lock} — is the extension running?")
        sys.exit(1)

    with open(lock) as f:
        data = json.load(f)
        pid = data["pid"]

    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError):
        print(f"✗ daemon pid {pid} not running")
        sys.exit(1)

    # Read environment variables of process
    environ_path = f"/proc/{pid}/environ"
    if not os.path.exists(environ_path):
        print(f"✗ Cannot access /proc/{pid}/environ")
        sys.exit(1)

    with open(environ_path, "rb") as ef:
        env_vars = ef.read().decode("utf-8", errors="replace").split("\x00")

    passphrase = None
    for var in env_vars:
        if var.startswith("PERPLEXITY_VAULT_PASSPHRASE="):
            passphrase = var.split("=", 1)[1]
            break

    if not passphrase:
        print("✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env")
        sys.exit(1)

    # 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
    home_npx = os.path.expanduser("~/.npm/_npx")
    dist = None
    if os.path.isdir(home_npx):
        for root, dirs, files in os.walk(home_npx):
            if "perplexity-user-mcp/dist" in root:
                dist = root
                break

    if not dist:
        try:
            subprocess.run(
                ["npx", "-y", "perplexity-user-mcp", "--version"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            pass

        if os.path.isdir(home_npx):
            for root, dirs, files in os.walk(home_npx):
                if "perplexity-user-mcp/dist" in root:
                    dist = root
                    break

    # 4. inject
    env = os.environ.copy()
    env.update({
        "PERPLEXITY_VAULT_PASSPHRASE": passphrase,
        "PERPLEXITY_CONFIG_DIR": cfg,
        "PERPLEXITY_PROFILE": profile,
        "PPLX_DIST": dist or ""
    })

    inject_script = os.path.join(here, "pplx-inject.mjs")
    subprocess.run(["node", inject_script, cookie_file], env=env, check=True)

    # 5. trigger daemon reinit
    reinit_file = os.path.join(cfg, "profiles", profile, ".reinit")
    os.makedirs(os.path.dirname(reinit_file), exist_ok=True)
    with open(reinit_file, "w") as rf:
        rf.write(str(int(time.time())) + "\n")

    print("→ reinit triggered, waiting for daemon...")

    # 6. verify
    stat_file = os.path.join(cfg, "profiles", profile, "daemon-status.json")
    for _ in range(20):
        time.sleep(1.5)
        auth = None
        tier = None
        try:
            with open(stat_file) as sf:
                status_data = json.load(sf)
                auth = status_data.get("authenticated")
                tier = status_data.get("tier")
        except Exception:
            continue

        if auth is True:
            print(f"✅ authenticated — tier: {tier}")
            return

    print(f"⚠️  not authenticated yet. Check: tail -20 {os.path.join(cfg, 'daemon.log')}")
    sys.exit(1)

if __name__ == "__main__":
    main()
