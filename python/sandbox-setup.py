#!/usr/bin/env python3
# sandbox-setup.sh — portiert nach python
# Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import shutil
import tempfile
import time

def log(message):
    print(f'[sandbox-setup] {message}')

def run_command(cmd, check=True, capture_output=False):
    try:
        if capture_output:
            result = subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True)
            return result.stdout.strip()
        else:
            subprocess.run(cmd, shell=True, check=check)
            return None
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return None

def command_exists(command):
    return shutil.which(command) is not None

def get_command_version(command, version_flag='--version'):
    try:
        result = subprocess.run([command, version_flag], capture_output=True, text=True)
        return result.stdout.split('\n')[0] if result.stdout else 'unknown version'
    except:
        return 'unknown version'

def apt_install(pkg, binary_name):
    if command_exists(binary_name):
        version_info = get_command_version(binary_name)
        log(f"{pkg} bereits vorhanden ({version_info})")
        return True
    
    log(f"Installiere {pkg} …")
    
    # Update package list if not already done
    if not hasattr(apt_install, 'apt_updated'):
        apt_install.apt_updated = False
    
    if not apt_install.apt_updated:
        env = os.environ.copy()
        env['DEBIAN_FRONTEND'] = 'noninteractive'
        try:
            subprocess.run(['apt-get', 'update', '-qq'], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            apt_install.apt_updated = True
        except subprocess.CalledProcessError:
            log("WARNUNG: apt-get update fehlgeschlagen")
            return False
    
    # Install package
    env = os.environ.copy()
    env['DEBIAN_FRONTEND'] = 'noninteractive'
    try:
        subprocess.run(['apt-get', 'install', '-y', '-qq', pkg], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        log(f"WARNUNG: {pkg} konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt")
        return False

def main():
    skip_heavy = len(sys.argv) > 1 and sys.argv[1] == "--skip-heavy"
    
    # Change to parent directory of this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(os.path.join(script_dir, ".."))
    
    # Node dependencies
    log("Node-Dependencies (npm install) …")
    try:
        run_command("npm install --no-audit --no-fund")
    except subprocess.CalledProcessError:
        log("FEHLER: npm install fehlgeschlagen")
        sys.exit(1)
    
    # Python dependencies
    log("Python-Dependencies (backend/requirements-dev.txt) …")
    try:
        run_command("pip3 install --quiet -r backend/requirements-dev.txt")
    except subprocess.CalledProcessError:
        log("FEHLER: pip install fehlgeschlagen")
        sys.exit(1)
    
    # Media tools
    apt_install('ffmpeg', 'ffmpeg')
    apt_install('imagemagick', 'convert')
    
    if not skip_heavy:
        apt_install('gimp', 'gimp')
        apt_install('blender', 'blender')
    
    # Visual QA tools
    apt_install('xvfb', 'Xvfb')
    apt_install('x11-utils', 'xdpyinfo')
    apt_install('libnss3-tools', 'certutil')
    
    if not command_exists('google-chrome-stable'):
        log("Installiere Google Chrome Stable …")
        with tempfile.NamedTemporaryFile(suffix='.deb', delete=False) as tmp_deb:
            tmp_deb_path = tmp_deb.name
        
        try:
            subprocess.run(['curl', '-fsSL', '-o', tmp_deb_path, 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'], check=True)
            env = os.environ.copy()
            env['DEBIAN_FRONTEND'] = 'noninteractive'
            subprocess.run(['apt-get', 'install', '-y', '-qq', tmp_deb_path], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            chrome_version = run_command("google-chrome-stable --version", capture_output=True)
            log(f"Chrome installiert: {chrome_version}")
        except subprocess.CalledProcessError:
            log("WARNUNG: Chrome-Installation fehlgeschlagen")
        finally:
            if os.path.exists(tmp_deb_path):
                os.unlink(tmp_deb_path)
    
    # Proxy CA import for Chrome
    if command_exists('certutil') and os.path.exists('/root/.ccr/ca-bundle.crt'):
        nssdb_path = os.path.expanduser('~/.pki/nssdb')
        os.makedirs(nssdb_path, exist_ok=True)
        
        try:
            subprocess.run(['certutil', '-d', f'sql:{nssdb_path}', '-N', '--empty-password'], 
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass  # Ignore errors
        
        try:
            result = subprocess.run(['certutil', '-d', f'sql:{nssdb_path}', '-L'], 
                                  capture_output=True, text=True)
            if 'ccr-proxy-ca' not in result.stdout:
                subprocess.run(['certutil', '-d', f'sql:{nssdb_path}', '-A', '-t', 'C,,', '-n', 'ccr-proxy-ca', '-i', '/root/.ccr/ca-bundle.crt'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                log("Proxy-CA in Chrome-NSS-Store importiert")
        except:
            pass  # Ignore errors
    
    # Playwright installation
    if os.path.exists('node_modules') and not os.path.exists('node_modules/playwright'):
        if command_exists('npm'):
            try:
                subprocess.run(['npm', 'install', '--no-audit', '--no-fund', '--no-save', 'playwright'],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                log("Playwright (Node) installiert")
            except subprocess.CalledProcessError:
                log("WARNUNG: Playwright-npm-Install fehlgeschlagen")
    
    # Git push configuration
    try:
        if subprocess.run(['git', 'rev-parse', '--is-inside-work-tree'], 
                          capture_output=True, check=True).returncode == 0:
            current_dir = os.getcwd()
            credential_helper = f"!{current_dir}/.claude/git-credential-pat.sh"
            
            subprocess.run(['git', 'config', f'credential.https://x-access-token@github.com.helper', credential_helper])
            subprocess.run(['git', 'remote', 'set-url', '--push', 'origin', 'https://x-access-token@github.com/KikiKari/Onboarding.git'])
            log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)")
    except:
        pass  # Ignore git configuration errors
    
    # Docker daemon setup
    if command_exists('dockerd') and not command_exists('docker') or not run_command("docker info", check=False, capture_output=True):
        log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …")
        os.makedirs('/etc/docker', exist_ok=True)
        
        daemon_config = '/etc/docker/daemon.json'
        if not os.path.exists(daemon_config):
            with open(daemon_config, 'w') as f:
                f.write('{"registry-mirrors":["https://mirror.gcr.io"]}')
        
        # Start docker daemon in background
        subprocess.Popen(['dockerd'], stdout=open('/tmp/dockerd.log', 'w'), stderr=subprocess.STDOUT)
        
        # Wait for docker to start
        for _ in range(15):
            try:
                subprocess.run(['docker', 'info'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                break
            except subprocess.CalledProcessError:
                time.sleep(1)
        
        try:
            subprocess.run(['docker', 'info'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            log("Docker-Daemon laeuft")
        except subprocess.CalledProcessError:
            log("WARNUNG: Docker-Daemon nicht gestartet")
    
    # Print versions summary
    log("Fertig. Versionen:")
    try:
        node_version = run_command("node --version", capture_output=True)
        log(f"  node {node_version}")
    except:
        pass
    
    try:
        python_version = run_command("python3 --version", capture_output=True)
        log(f"  {python_version}")
    except:
        pass
    
    if command_exists('ffmpeg'):
        try:
            ffmpeg_version = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
            log(f"  {ffmpeg_version.stdout.split(chr(10))[0]}")
        except:
            pass
    
    if command_exists('convert'):
        try:
            convert_version = subprocess.run(['convert', '-version'], capture_output=True, text=True)
            log(f"  {convert_version.stdout.split(chr(10))[0]}")
        except:
            pass
    
    if command_exists('gimp'):
        try:
            gimp_version = subprocess.run(['gimp', '--version'], capture_output=True, text=True)
            log(f"  {gimp_version.stdout.split(chr(10))[0]}")
        except:
            pass
    
    if command_exists('blender'):
        try:
            blender_version = subprocess.run(['blender', '--version'], capture_output=True, text=True)
            log(f"  {blender_version.stdout.split(chr(10))[0]}")
        except:
            pass

if __name__ == "__main__":
    main()
