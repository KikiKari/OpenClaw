#!/usr/bin/env python3
# fix_gateway_node_path.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import shutil
import subprocess
from datetime import datetime

# Backup der originalen Service-Datei
service_file = "/etc/systemd/system/openclaw-gateway.service"
backup_suffix = datetime.now().strftime("%Y%m%d_%H%M%S")
backup_file = f"{service_file}.backup-{backup_suffix}"
shutil.copy2(service_file, backup_file)

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
with open(service_file, 'r') as file:
    content = file.read()

content = content.replace('/home/openclaw/.nvm/versions/node/v22.22.2/bin/node', '/usr/bin/node')

with open(service_file, 'w') as file:
    file.write(content)

# Service neu laden und neu starten
subprocess.run(['systemctl', 'daemon-reload'], check=True)
subprocess.run(['systemctl', 'restart', 'openclaw-gateway'], check=True)

# Status prüfen
subprocess.run(['systemctl', 'status', 'openclaw-gateway', '--no-pager'], check=True)
