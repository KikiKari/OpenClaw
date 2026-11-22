#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "72dec2025035ae81d53f210589d0f3c42d8c4fa8a559bac4e9a492c8af582320", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "python"}
# run.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
import json

def run_command(command, log_file):
    """Führt einen Befehl aus und leitet die Ausgabe in eine Logdatei um"""
    with open(log_file, 'w') as f:
        result = subprocess.run(command, shell=True, stdout=f, stderr=subprocess.STDOUT)
    return result.returncode == 0

def main():
    # Arbeitsverzeichnis wechseln
    os.chdir('/repo')
    
    # Umgebungsvariablen setzen
    os.environ['OPENCLAW_STATE_DIR'] = '/tmp/openclaw-test'
    os.environ['OPENCLAW_CONFIG_PATH'] = os.path.join(os.environ['OPENCLAW_STATE_DIR'], 'openclaw.json')
    
    state_dir = os.environ['OPENCLAW_STATE_DIR']
    config_path = os.environ['OPENCLAW_CONFIG_PATH']
    
    print("==> Build")
    if not run_command('pnpm build', '/tmp/openclaw-cleanup-build.log'):
        with open('/tmp/openclaw-cleanup-build.log', 'r') as f:
            print(f.read())
        sys.exit(1)
    
    print("==> Seed state")
    os.makedirs(os.path.join(state_dir, 'credentials'), exist_ok=True)
    os.makedirs(os.path.join(state_dir, 'agents/main/sessions'), exist_ok=True)
    
    with open(config_path, 'w') as f:
        f.write('{}')
    
    with open(os.path.join(state_dir, 'credentials', 'marker.txt'), 'w') as f:
        f.write('creds')
        
    with open(os.path.join(state_dir, 'agents/main/sessions/sessions.json'), 'w') as f:
        f.write('session')
    
    print("==> Reset (config+creds+sessions)")
    if not run_command('pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive', '/tmp/openclaw-cleanup-reset.log'):
        with open('/tmp/openclaw-cleanup-reset.log', 'r') as f:
            print(f.read())
        sys.exit(1)
    
    # Tests
    if os.path.exists(config_path):
        print(f"Error: {config_path} still exists")
        sys.exit(1)
        
    if os.path.exists(os.path.join(state_dir, 'credentials')):
        print(f"Error: {os.path.join(state_dir, 'credentials')} still exists")
        sys.exit(1)
        
    if os.path.exists(os.path.join(state_dir, 'agents/main/sessions')):
        print(f"Error: {os.path.join(state_dir, 'agents/main/sessions')} still exists")
        sys.exit(1)
    
    print("==> Recreate minimal config")
    os.makedirs(os.path.join(state_dir, 'credentials'), exist_ok=True)
    with open(config_path, 'w') as f:
        f.write('{}')
    
    print("==> Uninstall (state only)")
    if not run_command('pnpm openclaw uninstall --state --yes --non-interactive', '/tmp/openclaw-cleanup-uninstall.log'):
        with open('/tmp/openclaw-cleanup-uninstall.log', 'r') as f:
            print(f.read())
        sys.exit(1)
    
    # Test
    if os.path.exists(state_dir):
        print(f"Error: {state_dir} still exists")
        sys.exit(1)
    
    print("OK")

if __name__ == '__main__':
    main()
