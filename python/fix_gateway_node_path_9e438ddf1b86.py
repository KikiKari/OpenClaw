#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "1d3a9e57798499c192d5304437a40681bc75830cf846d08566249659f4c165d1", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "python"}
# fix_gateway_node_path.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
# auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
