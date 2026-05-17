#!/usr/bin/env python3
"""
Node Health Monitor - Multi-Node Gesundheitsüberwachung
"""

import os
import sys
import json
import subprocess
import time
from datetime import datetime
from pathlib import Path

# Konfiguration
WORKSPACE = Path("/home/openclaw/.openclaw/workspace")
HEALTH_DB = WORKSPACE / "db/health.db"
LOG_FILE = WORKSPACE / "logs/node-health.log"

# Node-Definitionen
NODES = {
    "node1": {
        "name": "Node 1",
        "host": "localhost",
        "user": "openclaw",
        "critical": True
    },
    "node2": {
        "name": "Node 2",
        "host": "10.10.0.2",
        "user": "root",
        "ssh_key": "~/.ssh/id_rsa",
        "ssh_opts": "-o ConnectTimeout=10 -o BatchMode=yes"
    },
    "node3": {
        "name": "Node 3",
        "host": "localhost",
        "user": "root",
        "port": 18794,
        "ssh_opts": "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes",
        "disk_warning": 85
    },
    "node5": {
        "name": "Redmi",
        "host": "192.168.1.x",
        "user": "openclaw",
        "optional": True
    }
}

def log(message, level="INFO"):
    """Logging"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    entry = f"[{timestamp}] [{level}] {message}"
    print(entry)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, 'a') as f:
        f.write(entry + '\n')

def check_ping(host, timeout=10):
    """Prüft Erreichbarkeit (Timeout seconds)"""
    try:
        result = subprocess.run(
            ['ping', '-c', '1', '-W', str(timeout), host],
            capture_output=True
        )
        return result.returncode == 0
    except Exception:
        return False

def check_ssh(node_config):
    """Prüft SSH-Verbindung"""
    host = node_config["host"]
    user = node_config.get("user", "root")
    ssh_opts = node_config.get("ssh_opts", "")
    port = node_config.get("port")
    
    cmd = ['ssh']
    if ssh_opts:
        cmd.extend(ssh_opts.split())
    if port:
        cmd.extend(['-p', str(port)])
    cmd.extend(['-o', 'ConnectTimeout=10', '-o', 'BatchMode=yes',
                f'{user}@{host}', 'echo', '"OK"'])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0 and "OK" in result.stdout
    except Exception:
        return False

def get_node_metrics(node_config):
    """Holt Metriken via SSH"""
    host = node_config["host"]
    user = node_config.get("user", "root")
    
    metrics = {
        "timestamp": datetime.now().isoformat(),
        "available": False,
        "cpu": None,
        "ram": None,
        "disk": None,
        "load": None
    }
    
    # SSH-Command für alle Metriken
    cmd = f"""ssh -o ConnectTimeout=10 {user}@{host} '
        # CPU
        echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{{print \\$2}}" | cut -d"%" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk "{{print (\\$3/\\$2) * 100.0}}")"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk "{{print \\$5}}" | tr -d "%")"
        
        # Load
        echo "LOAD:$(uptime | awk -F"load average:" "{{print \\$2}}" | awk "{{print \\$1}}" | tr -d ",")"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
        fi
    '"""
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
        
        if result.returncode == 0:
            metrics["available"] = True
            
            for line in result.stdout.strip().split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    if key == "CPU":
                        metrics["cpu"] = float(value)
                    elif key == "RAM":
                        metrics["ram"] = float(value)
                    elif key == "DISK":
                        metrics["disk"] = int(value)
                    elif key == "LOAD":
                        metrics["load"] = float(value)
                    elif key == "GATEWAY":
                        metrics["gateway_status"] = value
        
    except subprocess.TimeoutExpired:
        log(f"SSH timeout for {node_config['name']}", "WARN")
    except Exception as e:
        log(f"Error checking {node_config['name']}: {e}", "ERROR")
    
    return metrics

def check_alerts(node_id, node_config, metrics):
    """Prüft Schwellwerte und generiert Alerts"""
    alerts = []
    
    # Verfügbarkeit
    if not metrics["available"]:
        if not node_config.get("optional", False):
            alerts.append({
                "level": "CRITICAL",
                "message": f"Node {node_config['name']} nicht erreichbar!"
            })
    else:
        # CPU
        if metrics["cpu"] and metrics["cpu"] > 90:
            alerts.append({
                "level": "WARNING",
                "message": f"Node {node_config['name']}: CPU bei {metrics['cpu']:.1f}%"
            })
        
        # RAM
        if metrics["ram"] and metrics["ram"] > 90:
            alerts.append({
                "level": "WARNING", 
                "message": f"Node {node_config['name']}: RAM bei {metrics['ram']:.1f}%"
            })
        
        # Disk
        disk_threshold = node_config.get("disk_warning", 85)
        if metrics["disk"] and metrics["disk"] > disk_threshold:
            level = "CRITICAL" if metrics["disk"] > 95 else "WARNING"
            alerts.append({
                "level": level,
                "message": f"Node {node_config['name']}: Disk bei {metrics['disk']}%"
            })
        
        # Gateway
        if node_config.get("critical") and metrics.get("gateway_status") == "inactive":
            alerts.append({
                "level": "CRITICAL",
                "message": f"Node {node_config['name']}: OpenClaw Gateway nicht aktiv!"
            })
    
    return alerts

def send_alert(alert):
    """Sendet Alert via channel-status-agent"""
    try:
        cmd = [
            "python3",
            str(WORKSPACE / "skills/channel-status-agent/scripts/channel_status.py"),
            "--type", "alert",
            "--message", f"{alert['level']}: {alert['message']}"
        ]
        subprocess.run(cmd, capture_output=True)
        log(f"Alert sent: {alert['message']}")
    except Exception as e:
        log(f"Failed to send alert: {e}", "ERROR")

def main():
    """Hauptfunktion"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Node Health Monitor')
    parser.add_argument('--node', default='all', help='Node ID oder "all"')
    parser.add_argument('--check', default='all', choices=['ping', 'ssh', 'metrics', 'all'])
    parser.add_argument('--alert', action='store_true', help='Sende Alerts')
    
    args = parser.parse_args()
    
    # Nodes bestimmen
    if args.node == 'all':
        nodes_to_check = NODES.items()
    else:
        if args.node in NODES:
            nodes_to_check = [(args.node, NODES[args.node])]
        else:
            log(f"Unknown node: {args.node}", "ERROR")
            sys.exit(1)
    
    # Health-Checks durchführen
    all_alerts = []
    
    for node_id, node_config in nodes_to_check:
        log(f"Checking {node_config['name']} ({node_id})")
        
        # Ping
        if args.check in ['ping', 'all']:
            if node_config["host"] != "localhost":
                ping_ok = check_ping(node_config["host"])
                log(f"  Ping: {'OK' if ping_ok else 'FAILED'}")
        
        # SSH
        if args.check in ['ssh', 'all']:
            ssh_ok = check_ssh(node_config)
            log(f"  SSH: {'OK' if ssh_ok else 'FAILED'}")
        
        # Metriken
        if args.check in ['metrics', 'all']:
            metrics = get_node_metrics(node_config)
            
            if metrics["available"]:
                log(f"  CPU: {metrics['cpu']:.1f}%" if metrics['cpu'] else "  CPU: N/A")
                log(f"  RAM: {metrics['ram']:.1f}%" if metrics['ram'] else "  RAM: N/A")
                log(f"  Disk: {metrics['disk']}%" if metrics['disk'] else "  Disk: N/A")
                log(f"  Load: {metrics['load']}" if metrics['load'] else "  Load: N/A")
            else:
                log("  Metrics: UNAVAILABLE")
            
            # Alerts prüfen
            alerts = check_alerts(node_id, node_config, metrics)
            all_alerts.extend(alerts)
    
    # Alerts senden
    if args.alert and all_alerts:
        log(f"\nSending {len(all_alerts)} alerts...")
        for alert in all_alerts:
            send_alert(alert)
    elif all_alerts:
        log(f"\n{len(all_alerts)} alerts found (use --alert to send)")
    else:
        log("\nAll nodes healthy!")

if __name__ == "__main__":
    main()