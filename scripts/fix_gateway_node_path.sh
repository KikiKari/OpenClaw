#!/usr/bin/env bash

# Backup der originalen Service-Datei
cp /etc/systemd/system/openclaw-gateway.service /etc/systemd/system/openclaw-gateway.service.backup-$(date +%Y%m%d_%H%M%S)

# Korrektur des Node.js Pfads in der Service-Datei
# Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
sed -i 's|/home/openclaw/.nvm/versions/node/v22.22.2/bin/node|/usr/bin/node|g' /etc/systemd/system/openclaw-gateway.service

# Service neu laden und neu starten
systemctl daemon-reload
systemctl restart openclaw-gateway

# Status prüfen
systemctl status openclaw-gateway --no-pager
