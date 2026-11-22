#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "6b7b3dc05c3711f7ab3c9835231b61fbbead88a400547285a2824fe3b7e1bfb3", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "python"}
# restart-mac.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import hashlib
import time
import shutil
import signal
import tempfile
from pathlib import Path

def log(*args):
    print(*args)

def fail(*args):
    print('ERROR:', *args, file=sys.stderr)
    sys.exit(1)

def run_step(label, cmd, cwd=None, env=None):
    log(f"==> {label}")
    try:
        result = subprocess.run(cmd, cwd=cwd, env=env, check=True, capture_output=True, text=True)
        return result
    except subprocess.CalledProcessError as e:
        fail(f"{label} failed: {e}")

def cleanup():
    if os.path.exists(LOCK_DIR):
        shutil.rmtree(LOCK_DIR)

def acquire_lock():
    while True:
        try:
            os.mkdir(LOCK_DIR)
            with open(LOCK_PID_FILE, 'w') as f:
                f.write(str(os.getpid()))
            return
        except FileExistsError:
            pass

        existing_pid = None
        if os.path.exists(LOCK_PID_FILE):
            try:
                with open(LOCK_PID_FILE, 'r') as f:
                    existing_pid = int(f.read().strip())
            except (ValueError, IOError):
                pass

        if existing_pid and os.path.exists(f'/proc/{existing_pid}'):
            if WAIT_FOR_LOCK:
                log(f"==> Another restart is running (pid {existing_pid}); waiting...")
                while os.path.exists(f'/proc/{existing_pid}'):
                    time.sleep(1)
                continue
            log(f"==> Another restart is running (pid {existing_pid}); re-run with --wait.")
            sys.exit(0)

        if os.path.exists(LOCK_DIR):
            shutil.rmtree(LOCK_DIR)

def check_signing_keys():
    try:
        result = subprocess.run(['security', 'find-identity', '-p', 'codesigning', '-v'], 
                               capture_output=True, text=True)
        return bool(result.returncode == 0 and 
                   ('Developer ID Application' in result.stdout or 
                    'Apple Distribution' in result.stdout or 
                    'Apple Development' in result.stdout))
    except:
        return False

def kill_all_openclaw():
    patterns = [
        APP_PROCESS_PATTERN,
        DEBUG_PROCESS_PATTERN,
        LOCAL_PROCESS_PATTERN,
        RELEASE_PROCESS_PATTERN
    ]
    
    for _ in range(10):
        for pattern in patterns:
            try:
                subprocess.run(['pkill', '-f', pattern], capture_output=True)
            except:
                pass
        
        try:
            subprocess.run(['pkill', '-x', 'OpenClaw'], capture_output=True)
        except:
            pass
            
        all_dead = True
        for pattern in patterns:
            try:
                result = subprocess.run(['pgrep', '-f', pattern], capture_output=True)
                if result.returncode == 0:
                    all_dead = False
                    break
            except:
                pass
                
        try:
            result = subprocess.run(['pgrep', '-x', 'OpenClaw'], capture_output=True)
            if result.returncode == 0:
                all_dead = False
        except:
            pass
            
        if all_dead:
            return True
            
        time.sleep(0.3)
    
    return False

def stop_launch_agent():
    try:
        subprocess.run(['launchctl', 'bootout', f'gui/{os.getuid()}/ai.openclaw.mac'], 
                      capture_output=True)
    except:
        pass

def choose_app_bundle():
    global APP_BUNDLE
    
    if APP_BUNDLE and os.path.exists(APP_BUNDLE):
        return True
        
    if os.path.exists('/Applications/OpenClaw.app'):
        APP_BUNDLE = '/Applications/OpenClaw.app'
        return True
        
    dist_path = os.path.join(ROOT_DIR, 'dist/OpenClaw.app')
    if os.path.exists(dist_path):
        APP_BUNDLE = dist_path
        sparkle_path = os.path.join(APP_BUNDLE, 'Contents/Frameworks/Sparkle.framework')
        if not os.path.exists(sparkle_path):
            fail("dist/OpenClaw.app missing Sparkle after packaging")
        return True
        
    return False

if __name__ == '__main__':
    # Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.
    
    ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    APP_BUNDLE = os.environ.get('OPENCLAW_APP_BUNDLE', '')
    APP_PROCESS_PATTERN = "OpenClaw.app/Contents/MacOS/OpenClaw"
    DEBUG_PROCESS_PATTERN = f"{ROOT_DIR}/apps/macos/.build/debug/OpenClaw"
    LOCAL_PROCESS_PATTERN = f"{ROOT_DIR}/apps/macos/.build-local/debug/OpenClaw"
    RELEASE_PROCESS_PATTERN = f"{ROOT_DIR}/apps/macos/.build/release/OpenClaw"
    LAUNCH_AGENT = os.path.expanduser("~/Library/LaunchAgents/ai.openclaw.mac.plist")
    LOCK_KEY = hashlib.sha256(ROOT_DIR.encode()).hexdigest()[:8]
    TMPDIR = os.environ.get('TMPDIR', '/tmp')
    LOCK_DIR = f"{TMPDIR}/openclaw-restart-{LOCK_KEY}"
    LOCK_PID_FILE = f"{LOCK_DIR}/pid"
    WAIT_FOR_LOCK = False
    LOG_PATH = os.environ.get('OPENCLAW_RESTART_LOG', '/tmp/openclaw-restart.log')
    NO_SIGN = False
    SIGN = False
    AUTO_DETECT_SIGNING = True
    GATEWAY_WAIT_SECONDS = int(os.environ.get('OPENCLAW_GATEWAY_WAIT_SECONDS', '0'))
    LAUNCHAGENT_DISABLE_MARKER = os.path.expanduser("~/.openclaw/disable-launchagent")
    ATTACH_ONLY = True

    # Ensure local node binaries (rolldown, pnpm) are discoverable for the steps below.
    PATH = f"{ROOT_DIR}/node_modules/.bin:{os.environ.get('PATH', '')}"
    os.environ['PATH'] = PATH

    # Parse arguments
    for arg in sys.argv[1:]:
        if arg in ['--wait', '-w']:
            WAIT_FOR_LOCK = True
        elif arg == '--no-sign':
            NO_SIGN = True
            AUTO_DETECT_SIGNING = False
        elif arg == '--sign':
            SIGN = True
            AUTO_DETECT_SIGNING = False
        elif arg == '--attach-only':
            ATTACH_ONLY = True
        elif arg == '--no-attach-only':
            ATTACH_ONLY = False
        elif arg in ['--help', '-h']:
            log("Usage:", os.path.basename(sys.argv[0]), "[--wait] [--no-sign] [--sign] [--attach-only|--no-attach-only]")
            log("  --wait    Wait for other restart to complete instead of exiting")
            log("  --no-sign Force no code signing (fastest for development)")
            log("  --sign    Force code signing (will fail if no signing key available)")
            log("  --attach-only    Launch app with --attach-only (skip launchd install)")
            log("  --no-attach-only Launch app without attach-only override")
            log("")
            log("Env:")
            log("  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)")
            log("")
            log("Unsigned recovery:")
            log("  node openclaw.mjs daemon install --force --runtime node")
            log("  node openclaw.mjs daemon restart")
            log("")
            log("Reset unsigned overrides:")
            log("  rm ~/.openclaw/disable-launchagent")
            log("")
            log("Default behavior: Auto-detect signing keys, fallback to --no-sign if none found")
            sys.exit(0)

    if NO_SIGN and SIGN:
        fail("Cannot use --sign and --no-sign together")

    # Setup logging
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    if os.path.exists(LOG_PATH):
        os.remove(LOG_PATH)
        
    # Note: Python doesn't have direct equivalent of bash tee redirection
    # We'll just log to console and file separately
    
    log("==> Log:", LOG_PATH)
    if NO_SIGN:
        log("==> Using --no-sign (unsigned flow enabled)")
    if ATTACH_ONLY:
        log("==> Using --attach-only (skip launchd install)")

    acquire_lock()

    # Kill all running instances first.
    log("==> Killing existing OpenClaw instances")
    kill_all_openclaw()
    stop_launch_agent()

    # Bundle Gateway-hosted Canvas A2UI assets.
    run_step("bundle canvas a2ui", ['bash', '-lc', f"cd '{ROOT_DIR}' && pnpm canvas:a2ui:bundle"])

    # Rebuild into the same path the packager consumes (.build).
    apps_macos_dir = os.path.join(ROOT_DIR, 'apps/macos')
    build_dirs = ['.build', '.build-swift', '.swiftpm']
    for build_dir in build_dirs:
        build_path = os.path.join(apps_macos_dir, build_dir)
        if os.path.exists(build_path):
            shutil.rmtree(build_path)
            
    run_step("swift build", ['bash', '-lc', f"cd '{apps_macos_dir}' && swift build -q --product OpenClaw"])

    if AUTO_DETECT_SIGNING:
        if check_signing_keys():
            log("==> Signing keys detected, will code sign")
            SIGN = True
        else:
            log("==> No signing keys found, will skip code signing (--no-sign)")
            NO_SIGN = True

    if NO_SIGN:
        os.environ['ALLOW_ADHOC_SIGNING'] = '1'
        os.environ['SIGN_IDENTITY'] = '-'
        os.makedirs(os.path.expanduser('~/.openclaw'), exist_ok=True)
        run_step("disable launchagent writes", ['/usr/bin/touch', LAUNCHAGENT_DISABLE_MARKER])
    elif SIGN:
        if not check_signing_keys():
            fail("No signing identity found. Use --no-sign or install a signing key.")
        if 'ALLOW_ADHOC_SIGNING' in os.environ:
            del os.environ['ALLOW_ADHOC_SIGNING']
        if 'SIGN_IDENTITY' in os.environ:
            del os.environ['SIGN_IDENTITY']

    # Package app (no embedded gateway).
    run_step("package app", ['bash', '-lc', f"cd '{ROOT_DIR}' && SKIP_TSC={os.environ.get('SKIP_TSC', '1')} '{ROOT_DIR}/scripts/package-mac-app.sh'"])

    if not choose_app_bundle():
        fail("App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app")

    # When signed, clear any previous launchagent override marker.
    if not NO_SIGN and not ATTACH_ONLY and os.path.exists(LAUNCHAGENT_DISABLE_MARKER):
        run_step("clear launchagent disable marker", ['/bin/rm', '-f', LAUNCHAGENT_DISABLE_MARKER])

    # When unsigned, ensure the gateway LaunchAgent targets the repo CLI (before the app launches).
    # This reduces noisy "could not connect" errors during app startup.
    if NO_SIGN and not ATTACH_ONLY:
        run_step("install gateway launch agent (unsigned)", ['bash', '-lc', f"cd '{ROOT_DIR}' && node openclaw.mjs daemon install --force --runtime node"])
        run_step("restart gateway daemon (unsigned)", ['bash', '-lc', f"cd '{ROOT_DIR}' && node openclaw.mjs daemon restart"])
        
        if GATEWAY_WAIT_SECONDS > 0:
            run_step("wait for gateway (unsigned)", ['sleep', str(GATEWAY_WAIT_SECONDS)])
            
        try:
            gateway_port_result = subprocess.run([
                'node', '-e', '''
                  const fs = require("node:fs");
                  const path = require("node:path");
                  try {
                    const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
                    const cfg = JSON.parse(raw);
                    const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
                    process.stdout.write(String(port));
                  } catch {
                    process.stdout.write("18789");
                  }
                '''],
                capture_output=True, text=True, cwd=ROOT_DIR
            )
            GATEWAY_PORT = gateway_port_result.stdout.strip()
        except:
            GATEWAY_PORT = "18789"
            
        run_step(f"verify gateway port {GATEWAY_PORT} (unsigned)", ['bash', '-lc', f"lsof -iTCP:{GATEWAY_PORT} -sTCP:LISTEN | head -n 5 || true"])

    # Launch the installed app in the foreground so the menu bar extra appears.
    # LaunchServices can inherit a huge environment from this shell (secrets, prompt vars, etc.).
    # That can cause launchd spawn failures and is undesirable for a GUI app anyway.
    ATTACH_ONLY_ARGS = ['--args', '--attach-only'] if ATTACH_ONLY else []
    
    launch_env = {
        'HOME': os.environ['HOME'],
        'USER': os.environ.get('USER', subprocess.check_output(['id', '-un'], text=True).strip()),
        'LOGNAME': os.environ.get('LOGNAME', subprocess.check_output(['id', '-un'], text=True).strip()),
        'TMPDIR': os.environ.get('TMPDIR', '/tmp'),
        'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
        'LANG': os.environ.get('LANG', 'en_US.UTF-8')
    }
    
    cmd = ['/usr/bin/open', APP_BUNDLE] + ATTACH_ONLY_ARGS
    run_step("launch app", cmd, env=launch_env)

    # Verify the app is alive.
    time.sleep(1.5)
    try:
        result = subprocess.run(['pgrep', '-f', APP_PROCESS_PATTERN], capture_output=True)
        if result.returncode == 0:
            log("OK: OpenClaw is running.")
        else:
            fail(f"App exited immediately. Check {LOG_PATH} or Console.app (User Reports).")
    except:
        fail(f"App exited immediately. Check {LOG_PATH} or Console.app (User Reports).")

    if NO_SIGN and not ATTACH_ONLY:
        run_step("show gateway launch agent args (unsigned)", ['bash', '-lc', f"/usr/bin/plutil -p '{os.path.expanduser('~/Library/LaunchAgents/ai.openclaw.gateway.plist')}' | head -n 40 || true"])
