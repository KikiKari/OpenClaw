# Node Start Vorlage

**Gültig für:** Node 2 (Netcup), Node 3 (xNetX), Node 4+, Mobile Clients  
**Verbindung:** OpenClaw Node Mode via VPN-Tunnel

## Übersicht

| Node | Lokaler Befehl | VPN IP | Externer Zugriff |
|------|----------------|--------|------------------|
| **Node 1** | `openclaw gateway start` | 10.10.0.1 | Haupt-Gateway |
| **Node 2** | `openclaw node run --host 10.10.0.2 --port 18789` | 10.10.0.2 | Via Node 1 |
| **Node 3** | `openclaw node run --host 10.10.0.3 --port 18789` | 10.10.0.3 | Via Node 1 |
| **Node 4+** | `openclaw node run --host 10.10.0.X --port 18789` | 10.10.0.X | Via Node 1 |

## Voraussetzungen

1. **WireGuard VPN** verbunden
2. **OpenClaw** installiert
3. **Token/Auth** mit Gateway konfiguriert

## Node 2: Netcup (Ubuntu 24.04)

### VPN-Check

```bash
# WireGuard Status prüfen
sudo wg show

# Sollte zeigen: latest handshake: ...
# iface: wg0, peer: Node 1 PublicKey

# VPN IP verifizieren
ip addr show wg0 | grep "inet 10.10.0.2"
```

### Node Start (direkt)

```bash
# Als openclaw (nicht root!)
su openclaw

# Node starten
openclaw node run --host 10.10.0.2 --port 18789
```

### Als Service (systemd)

```bash
# Service-Datei erstellen
sudo tee /etc/systemd/system/openclaw-node2.service << 'EOF'
[Unit]
Description=OpenClaw Node 2 (Netcup)
After=network-online.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
Environment="PATH=/home/openclaw/.npm-global/bin:/usr/bin:/bin"
Environment="HOME=/home/openclaw"

ExecStart=/home/openclaw/.npm-global/bin/openclaw node run --host 10.10.0.2 --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Aktivieren
sudo systemctl daemon-reload
sudo systemctl enable openclaw-node2.service
sudo systemctl start openclaw-node2.service

# Status
sudo systemctl status openclaw-node2.service
```

### Als Cron (alternativ)

```bash
# Als openclaw
crontab -e

# Einfügen:
# Starte Node 2 (mit PID-Check)
*/20 * * * * pgrep -f "openclaw node.*10.10.0.2" > /dev/null || /home/openclaw/.npm-global/bin/openclaw node run --host 10.10.0.2 --port 18789 >> /tmp/openclaw-node2.log 2>&1 &
```

## Node 3: xNetX (CentOS 8)

### VPN-Check

```bash
# WireGuard (wg-quick auf CentOS)
sudo wg show

# VPN IP
ip addr show wg0 | grep "inet 10.10.0.3"
```

### Node Start

```bash
# Als openclaw
su openclaw

# Node starten
openclaw node run --host 10.10.0.3 --port 18789
```

### Als Service

```bash
sudo tee /etc/systemd/system/openclaw-node3.service << 'EOF'
[Unit]
Description=OpenClaw Node 3 (xNetX)
After=network-online.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
Environment="PATH=/home/openclaw/.npm-global/bin:/usr/bin:/bin"
Environment="HOME=/home/openclaw"

ExecStart=/home/openclaw/.npm-global/bin/openclaw node run --host 10.10.0.3 --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw-node3.service
sudo systemctl start openclaw-node3.service
```

## Node 4+: Weitere Nodes

### Vorlage (anpassen: NODE_NUM, VPN_IP)

```bash
# Variablen setzen
NODE_NUM=5
VPN_IP="10.10.0.5"
NODE_NAME="node5-mobile"

# Service erstellen
sudo tee /etc/systemd/system/openclaw-node${NODE_NUM}.service << EOF
[Unit]
Description=OpenClaw Node ${NODE_NUM} (${NODE_NAME})
After=network-online.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
Environment="PATH=/home/openclaw/.npm-global/bin:/usr/bin:/bin"
Environment="HOME=/home/openclaw"

ExecStart=/home/openclaw/.npm-global/bin/openclaw node run --host ${VPN_IP} --port 18789
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw-node${NODE_NUM}.service
sudo systemctl start openclaw-node${NODE_NUM}.service
```

## Verifizierung

### Auf Node selbst

```bash
# Prozess läuft?
ps aux | grep "openclaw node"

# Port belegt?
netstat -tlnp | grep 18789

# Logs
journalctl -u openclaw-node2 -f
```

### Auf Gateway (Node 1)

```bash
# Node-Status
openclaw nodes status

# Sollte zeigen:
# Node 2: paired · connected
# Node 3: paired · connected
```

## Troubleshooting

### Problem: "Cannot connect to Gateway"

**Lösung:**
```bash
# 1. VPN prüfen
ping 10.10.0.1  # Gateway über VPN erreichbar?

# 2. WireGuard neustarten
sudo systemctl restart wg-quick@wg0

# 3. Token überprüfen
cat ~/.config/openclaw/env | grep TOKEN
```

### Problem: "Address already in use"

**Lösung:**
```bash
# Prozess killen
pkill -f "openclaw node"

# Neu starten
openclaw node run --host 10.10.0.X --port 18789
```

### Problem: Node zeigt "disconnected"

**Lösung:**
```bash
# Auf Gateway: Node re-pairen
openclaw nodes remove <node-id>
# Auf Node: Neu starten
openclaw node run --host 10.10.0.X --port 18789
```

## Links

- [INFRASTRUCTURE.md](../../INFRASTRUCTURE.md) - VPN-Setup
- [WIREGUARD_FINAL_STATUS.md](../../WIREGUARD_FINAL_STATUS.md) - WireGuard Details
- [SYSTEM.md](../../SYSTEM.md) - Cron-Jobs
