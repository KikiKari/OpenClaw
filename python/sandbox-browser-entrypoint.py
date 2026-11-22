#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "0f847adb5e110ae551f8228ad6cd01c873356c8958c2fd581a254ac1c0723942", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "python"}
# sandbox-browser-entrypoint.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import signal
import subprocess
import time
import re
from pathlib import Path

def validate_uint(name, value, min_val=0, max_val=4294967295):
    """Validate that value is an integer within the given range"""
    try:
        val = int(value)
        if not (min_val <= val <= max_val):
            print(f"[sandbox] ERROR: {name} out of range ({min_val}..{max_val}), got: {value}", file=sys.stderr)
            sys.exit(1)
    except ValueError:
        print(f"[sandbox] ERROR: {name} must be an integer, got: {value}", file=sys.stderr)
        sys.exit(1)

def get_current_time_ms():
    """Get current time in milliseconds"""
    return int(time.time() * 1000)

def cleanup(signum=None, frame=None):
    """Cleanup function to terminate all child processes"""
    global cleanup_called
    if cleanup_called:
        return
    
    cleanup_called = True
    
    # Remove signal handlers
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    
    pids = []
    for var_name in ['WEBSOCKIFY_PID', 'X11VNC_PID', 'SOCAT_PID', 'CHROME_PID', 'XVFB_PID']:
        pid_str = globals().get(var_name, '')
        if pid_str and pid_str.isdigit():
            pids.append(int(pid_str))
    
    if pids:
        # Send TERM signal
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        
        # Wait for processes to terminate (max 2 seconds)
        for _ in range(10):
            alive = False
            for pid in pids:
                try:
                    os.kill(pid, 0)  # Check if process exists
                    alive = True
                    break
                except ProcessLookupError:
                    pass
            
            if not alive:
                break
            time.sleep(0.2)
        
        # Force kill remaining processes
        for pid in pids:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    
    if signum is not None:
        sys.exit(128 + signum)

def main():
    global cleanup_called
    cleanup_called = False
    
    # Set environment variables
    os.environ['DBUS_SESSION_BUS_ADDRESS'] = '/dev/null'
    os.environ['DISPLAY'] = ':1'
    os.environ['HOME'] = '/tmp/openclaw-home'
    os.environ['XDG_CONFIG_HOME'] = f"{os.environ['HOME']}/.config"
    os.environ['XDG_CACHE_HOME'] = f"{os.environ['HOME']}/.cache"
    
    # Get configuration from environment
    CDP_PORT = int(os.environ.get('OPENCLAW_BROWSER_CDP_PORT', '9222'))
    CDP_SOURCE_RANGE = os.environ.get('OPENCLAW_BROWSER_CDP_SOURCE_RANGE', '')
    VNC_PORT = int(os.environ.get('OPENCLAW_BROWSER_VNC_PORT', '5900'))
    NOVNC_PORT = int(os.environ.get('OPENCLAW_BROWSER_NOVNC_PORT', '6080'))
    ENABLE_NOVNC = os.environ.get('OPENCLAW_BROWSER_ENABLE_NOVNC', '1')
    HEADLESS = os.environ.get('OPENCLAW_BROWSER_HEADLESS', '0')
    ALLOW_NO_SANDBOX = os.environ.get('OPENCLAW_BROWSER_NO_SANDBOX', '0')
    NOVNC_PASSWORD = os.environ.get('OPENCLAW_BROWSER_NOVNC_PASSWORD', '')
    
    DISABLE_GRAPHICS_FLAGS = os.environ.get('OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS', '1')
    DISABLE_EXTENSIONS = os.environ.get('OPENCLAW_BROWSER_DISABLE_EXTENSIONS', '1')
    RENDERER_PROCESS_LIMIT = os.environ.get('OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT', '2')
    AUTO_START_TIMEOUT_MS = int(os.environ.get('OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS', '12000'))
    
    # Validate ports and timeouts
    validate_uint("CDP_PORT", CDP_PORT, 1, 65535)
    validate_uint("VNC_PORT", VNC_PORT, 1, 65535)
    validate_uint("NOVNC_PORT", NOVNC_PORT, 1, 65535)
    validate_uint("AUTO_START_TIMEOUT_MS", AUTO_START_TIMEOUT_MS, 1, 2147483647)
    if RENDERER_PROCESS_LIMIT:
        validate_uint("RENDERER_PROCESS_LIMIT", RENDERER_PROCESS_LIMIT, 0, 2147483647)
    
    # Setup signal handlers
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    
    # Create directories
    dirs = [
        os.environ['HOME'],
        f"{os.environ['HOME']}/.chrome",
        os.environ['XDG_CONFIG_HOME'],
        os.environ['XDG_CACHE_HOME']
    ]
    for directory in dirs:
        Path(directory).mkdir(parents=True, exist_ok=True)
    
    # Start Xvfb
    xvfb_cmd = ['Xvfb', ':1', '-screen', '0', '1280x800x24', '-ac', '-nolisten', 'tcp']
    xvfb_process = subprocess.Popen(xvfb_cmd)
    XVFB_PID = str(xvfb_process.pid)
    print(f"[sandbox] Xvfb started (PID: {XVFB_PID})")
    
    # Calculate Chrome CDP port
    if CDP_PORT >= 65535:
        CHROME_CDP_PORT = CDP_PORT - 1
    else:
        CHROME_CDP_PORT = CDP_PORT + 1
    
    # Build Chrome arguments
    chrome_args = [
        '--remote-debugging-address=127.0.0.1',
        f'--remote-debugging-port={CHROME_CDP_PORT}',
        f"--user-data-dir={os.environ['HOME']}/.chrome",
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-dev-shm-usage',
        '--disable-background-networking',
        '--disable-breakpad',
        '--disable-crash-reporter',
        '--no-zygote',
        '--metrics-recording-only',
        '--password-store=basic',
        '--use-mock-keychain'
    ]
    
    if HEADLESS == '1':
        chrome_args.append('--headless=new')
    
    if ALLOW_NO_SANDBOX == '1':
        chrome_args.extend(['--no-sandbox', '--disable-setuid-sandbox'])
    
    # Handle graphics flags
    disable_graphics_lower = DISABLE_GRAPHICS_FLAGS.lower()
    if disable_graphics_lower in ('1', 'true', 'yes', 'on'):
        chrome_args.extend([
            '--disable-3d-apis',
            '--disable-gpu',
            '--disable-software-rasterizer'
        ])
    
    # Handle extensions
    disable_extensions_lower = DISABLE_EXTENSIONS.lower()
    if disable_extensions_lower in ('1', 'true', 'yes', 'on'):
        chrome_args.append('--disable-extensions')
    
    # Handle renderer process limit
    if RENDERER_PROCESS_LIMIT and RENDERER_PROCESS_LIMIT.isdigit() and int(RENDERER_PROCESS_LIMIT) > 0:
        chrome_args.append(f'--renderer-process-limit={RENDERER_PROCESS_LIMIT}')
    
    # Start Chromium
    print("[sandbox] Starting Chromium...")
    chrome_cmd = ['chromium'] + chrome_args + ['about:blank']
    chrome_process = subprocess.Popen(chrome_cmd)
    CHROME_PID = str(chrome_process.pid)
    print(f"[sandbox] Chromium started (PID: {CHROME_PID})")
    
    # Wait for CDP to be ready
    start_ms = get_current_time_ms()
    deadline_ms = start_ms + AUTO_START_TIMEOUT_MS
    cdp_ready = False
    probe_url = f"http://127.0.0.1:{CHROME_CDP_PORT}/json/version"
    
    print(f"[sandbox] Waiting up to {AUTO_START_TIMEOUT_MS}ms for CDP on port {CHROME_CDP_PORT}...")
    
    while get_current_time_ms() < deadline_ms:
        # Check if Chrome is still running
        if chrome_process.poll() is not None:
            print("[sandbox] ERROR: Chromium exited before CDP became ready.")
            sys.exit(1)
        
        # Try to connect to CDP endpoint
        try:
            import urllib.request
            response = urllib.request.urlopen(probe_url, timeout=0.5)
            if response.getcode() == 200:
                cdp_ready = True
                break
        except Exception:
            pass
        
        time.sleep(0.2)
    
    if not cdp_ready:
        print(f"[sandbox] ERROR: CDP failed to start within {AUTO_START_TIMEOUT_MS}ms.")
        sys.exit(1)
    
    print("[sandbox] CDP ready. Starting socat...")
    
    # Start socat if source range is set
    if not CDP_SOURCE_RANGE:
        print("[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.", file=sys.stderr)
        print("[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.", file=sys.stderr)
    else:
        socat_listen_addr = f"TCP-LISTEN:{CDP_PORT},fork,reuseaddr,bind=0.0.0.0,range={CDP_SOURCE_RANGE}"
        socat_cmd = ['socat', socat_listen_addr, f"TCP:127.0.0.1:{CHROME_CDP_PORT}"]
        socat_process = subprocess.Popen(socat_cmd)
        SOCAT_PID = str(socat_process.pid)
        print(f"[sandbox] socat started (PID: {SOCAT_PID})")
    
    # Start noVNC if enabled and not headless
    if ENABLE_NOVNC == '1' and HEADLESS != '1':
        # Generate password if not provided
        if not NOVNC_PASSWORD:
            import uuid
            novnc_password = str(uuid.uuid4()).replace('-', '')[:8]
        else:
            novnc_password = NOVNC_PASSWORD
        
        # Create VNC password file
        vnc_dir = f"{os.environ['HOME']}/.vnc"
        Path(vnc_dir).mkdir(parents=True, exist_ok=True)
        passwd_file = f"{vnc_dir}/passwd"
        
        with open(passwd_file, 'w') as f:
            f.write(novnc_password)
        os.chmod(passwd_file, 0o600)
        
        # Start x11vnc
        x11vnc_cmd = [
            'x11vnc', '-display', ':1', '-rfbport', str(VNC_PORT),
            '-shared', '-forever', '-rfbauth', passwd_file, '-localhost'
        ]
        x11vnc_process = subprocess.Popen(x11vnc_cmd)
        X11VNC_PID = str(x11vnc_process.pid)
        print(f"[sandbox] x11vnc started (PID: {X11VNC_PID})")
        
        # Start websockify
        websockify_cmd = [
            'websockify', '--web', '/usr/share/novnc/', 
            str(NOVNC_PORT), f"localhost:{VNC_PORT}"
        ]
        websockify_process = subprocess.Popen(websockify_cmd)
        WEBSOCKIFY_PID = str(websockify_process.pid)
        print(f"[sandbox] websockify started (PID: {WEBSOCKIFY_PID})")
    
    print("[sandbox] Container running. Monitoring all sub-processes...")
    
    # Monitor processes
    processes = [xvfb_process]
    if 'socat_process' in locals():
        processes.append(socat_process)
    if 'x11vnc_process' in locals():
        processes.append(x11vnc_process)
    if 'websockify_process' in locals():
        processes.append(websockify_process)
    processes.append(chrome_process)
    
    try:
        # Wait for any process to exit
        while True:
            for proc in processes:
                if proc.poll() is not None:
                    return
            time.sleep(0.1)
    finally:
        cleanup()

if __name__ == '__main__':
    main()
