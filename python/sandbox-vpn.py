#!/usr/bin/env python3
# sandbox-vpn.sh — portiert nach python
# Quelle: shell, Onboarding@main:scripts/sandbox-vpn.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import time
import re
from pathlib import Path

def log(message):
    print(f'[sandbox-vpn] {message}')

def main():
    # Wechsel ins Projektverzeichnis
    script_dir = Path(__file__).parent.parent.resolve()
    os.chdir(script_dir)
    
    # Auth-Key aus .env lesen (ohne die gesamte .env zu laden)
    key = ""
    env_file = Path(".env")
    if env_file.exists():
        with open(env_file, 'r') as f:
            content = f.read()
            match = re.search(r'^TAILSCALE_AUTH_KEY="(.*)"', content, re.MULTILINE)
            if match:
                key = match.group(1)
    
    if not key:
        log("kein TAILSCALE_AUTH_KEY in .env — überspringe VPN")
        sys.exit(0)
    
    # Prüfen ob tailscale installiert ist, ansonsten installieren
    if not is_command_available("tailscale"):
        log("installiere Tailscale …")
        try:
            result = subprocess.run(
                ["curl", "-fsSL", "https://tailscale.com/install.sh"],
                capture_output=True,
                check=True
            )
            # Shell-Skript ausführen
            subprocess.run(
                ["sh"],
                input=result.stdout,
                capture_output=True,
                check=True
            )
        except subprocess.CalledProcessError:
            log("WARNUNG: Tailscale-Install fehlgeschlagen")
            sys.exit(0)
    
    # tailscaled im userspace-Modus starten (SOCKS5 + HTTP-Proxy)
    if not is_tailscale_up():
        log("starte tailscaled (userspace, SOCKS5 localhost:1055) …")
        
        # Verzeichnis erstellen
        statedir = Path("/var/lib/tailscale")
        statedir.mkdir(parents=True, exist_ok=True)
        
        # tailscaled im Hintergrund starten
        with open("/tmp/tailscaled.log", "w") as logfile:
            try:
                subprocess.Popen([
                    "tailscaled",
                    "--tun=userspace-networking",
                    "--socks5-server=localhost:1055",
                    "--outbound-http-proxy-listen=localhost:1056",
                    "--statedir=/var/lib/tailscale"
                ], stdout=logfile, stderr=logfile)
                
                # Wartezeit für den Start
                time.sleep(4)
            except Exception as e:
                logfile.write(f"Fehler beim Starten von tailscaled: {e}\n")
    
    # Ins Tailnet einbuchen, mit Tailscale-SSH
    try:
        result = subprocess.run(
            ["tailscale", "status"],
            capture_output=True,
            text=True
        )
        
        if "claude-sandbox" not in result.stdout:
            log("tailscale up (hostname=claude-sandbox, --ssh) …")
            subprocess.run([
                "tailscale", "up",
                f"--authkey={key}",
                "--hostname=claude-sandbox",
                "--ssh",
                "--accept-routes"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        else:
            subprocess.run([
                "tailscale", "set",
                "--ssh"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
    except subprocess.CalledProcessError:
        log("WARNUNG: tailscale up fehlgeschlagen")
    
    # Status anzeigen
    if is_tailscale_up():
        try:
            result = subprocess.run(
                ["tailscale", "ip", "-4"],
                capture_output=True,
                text=True,
                check=True
            )
            ip_lines = result.stdout.strip().split('\n')
            ip = ip_lines[0] if ip_lines else "?"
            log(f"im Tailnet: claude-sandbox {ip} · SSH aktiv · SOCKS5 localhost:1055")
        except subprocess.CalledProcessError:
            log("im Tailnet: claude-sandbox ? · SSH aktiv · SOCKS5 localhost:1055")

def is_command_available(command):
    """Prüft ob ein Kommando verfügbar ist"""
    try:
        subprocess.run(
            ["which", command],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False

def is_tailscale_up():
    """Prüft ob tailscale läuft"""
    try:
        subprocess.run(
            ["tailscale", "status"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return True
    except subprocess.CalledProcessError:
        return False

if __name__ == "__main__":
    main()
