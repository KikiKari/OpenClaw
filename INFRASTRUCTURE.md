# OpenClaw Infrastructure Documentation

> **Aktueller Netzwerkvertrag (2026-07-12):** OpenClaw-Pairing und Node-Traffic
> laufen ausschließlich über Tailscale. Ein Fallback über externe IP-Adressen
> oder historische SSH-/WireGuard-Reverse-Tunnel ist weder aktiv noch
> vorgesehen. Externe IPs und alte Tunnelbeispiele weiter unten sind
> historische Bestandsangaben und keine aktuelle Betriebsanweisung.

## Übersicht

Diese Dokumentation beschreibt die komplette OpenClaw-Infrastruktur mit WireGuard VPN, Node Mode und allen Verbindungen.

## Status Update 2026-04-18 (23:00)

### Kritische Konfigurationsfixes
- **OPENAI_API_KEY Fehler**: Behoben durch Änderung zu `${NVIDIA_API_KEY}` in openai provider
- **Memory Embeddings**: Korrekt konfiguriert mit OpenAI provider statt OpenRouter
  - Provider: `openai`
  - Model: `text-embedding-3-small`
  - API Key: `${OPENAI_API_KEY}` (aus env-Datei)
- **DeepSeek R1**: Reasoning auf "minimal" gesetzt (behebt "Reasoning is mandatory" Fehler)
- **Claude Opus**: Context-Limit angepasst (maxTokens: 4096, contextReserve: 50000)
- **Rate Limits**: Global erhöht (5 retries, 2s delay, 1.5x backoff)

### Node 2 Konfiguration
- **GitHub CLI**: Version 2.90.0 erfolgreich installiert
- **SSH-Zugriff**: 
  - Firewall: Port 22 geöffnet (ufw)
  - SSH-Config: PasswordAuthentication=yes, PubkeyAuthentication=yes, PermitRootLogin=yes
  - Tailscale SSH: Aktiviert mit `--ssh --accept-dns=false --accept-routes --hostname=openclaw-node2`
- **GitHub-Skill**: Status "ready" - erfolgreich getestet

### Aktuelle Netzwerk-Verbindungen
- **WireGuard VPN**: Alle Peers aktiv
  - Node 1 ↔ Node 2: 365.77 KiB received / 99.28 KiB sent
  - Node 1 ↔ localhost: 11.75 MiB received / 169.24 MiB sent
- **Tailscale**: 
  - openclaw-node1 (100.111.216.40): Online
  - openclaw-node2 (100.92.155.34): Active mit direkter Verbindung
  - v2202604104722449961 (100.104.68.51): Online

### OpenClaw Versionen
- Node 1 (Gateway): v2026.4.15 (aktualisiert)
- Node 2: v2026.4.9

## Netzwerk-Topologie

```
                               INTERNET
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
           152.53.145.65                  185.162.248.90
         ┌─────────────┐                ┌─────────────┐
         │  GATEWAY    │◄───────────────│   Node 3    │
         │  (Hetzner)  │  SSH Tunnel    │  (CentOS)   │
         │  10.10.0.1  │                │  10.10.0.3  │
         └──────┬──────┘                └─────────────┘
                │                              ▲
       WireGuard│                              │SSH
         VPN    │                              │Tunnel
                │                       159.195.78.116
                │                      ┌─────────────┐
                └──────────────────────│   Node 2    │
                                       │  (Netcup)   │
                                       │  10.10.0.2  │
                                       └─────────────┘
```

## Nodes

| Node | Hostname | Externe IP | WireGuard IP | Rolle | Status |
|------|----------|------------|--------------|-------|--------|
| Node 1 | v2202604104722446711 | 152.53.145.65 | 10.10.0.1/24 | Gateway | ✅ Aktiv |
| Node 2 | v2202603104722445775 | 159.195.78.116 | 10.10.0.2/32 | Node Host | ✅ Verbunden |
| Node 3 | xnetx | 185.162.248.90 | 10.10.0.3/32 | Node Host | ✅ Verbunden |
| Node 4 | xstoragex.de | 91.204.46.22 | - | Webhosting | ✅ Aktiv |
| Node 5 | Redmi Note 11 | DHCP/Mobil | 10.10.0.5/32 | Mobile Client | ⏳ Konfiguration erforderlich |

---

## Node 1: Gateway (Hetzner)

### OpenClaw Gateway
- **Port:** 18789/tcp (WebSocket Gateway)
- **Bind:** lan (0.0.0.0)
- **Auth:** Token-basiert
- **WireGuard:** 51820/udp

### WireGuard Konfiguration
```ini
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.1/24
PrivateKey = [GATEWAY_PRIVATE_KEY]
ListenPort = 51820

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Node 2 (Netcup)
[Peer]
PublicKey = LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0=
AllowedIPs = 10.10.0.2/32

# Node 3 (xNetX)
[Peer]
PublicKey = Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA=
AllowedIPs = 10.10.0.3/32

# Node 5 (Redmi Note 11)
[Peer]
PublicKey = IKaeGkYyBAabN2R+tPQCBKK1RBc1AIacNt9pATEZQRs=
AllowedIPs = 10.10.0.5/32
```

### Firewall (UFW)
```bash
ufw allow 22/tcp                    # SSH
ufw allow 51820/udp                 # WireGuard
ufw allow 18789/tcp                 # OpenClaw Gateway
ufw allow 80/tcp                    # HTTP (Control UI)
ufw allow 443/tcp                   # HTTPS
ufw allow from 10.10.0.0/24         # WireGuard Network
```

### Services
```bash
systemctl enable wg-quick@wg0
systemctl enable openclaw-gateway
```

---

## Node Start Vorlagen

Detaillierte Start-Anleitungen für alle Node-Typen:
- **[NODE_START_TEMPLATE.md](../docs/reference/NODE_START_TEMPLATE.md)** - Vollständige Vorlagen mit VPN-IP

Schnellstart:
```bash
# Node 2 (Netcup, 10.10.0.2)
openclaw node run --host 10.10.0.2 --port 18789

# Node 3 (xNetX, 10.10.0.3)
openclaw node run --host 10.10.0.3 --port 18789

# Als Service (empfohlen)
systemctl enable openclaw-node2.service
```

---

## Node 2: Netcup Server (Ubuntu 24.04)

### OpenClaw Node Mode
- **Verbindung:** Via SSH Tunnel zu Gateway
- **Host:** 127.0.0.1:18789 (lokaler Tunnel)
- **Mode:** remote

### SSH Tunnel Service
```bash
# /root/.config/systemd/user/openclaw-tunnel.service
[Unit]
Description=SSH Tunnel to OpenClaw Gateway
After=network-online.target

[Service]
ExecStart=/usr/bin/ssh -i /root/.ssh/node1_tunnel -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -N -L 18789:127.0.0.1:18789 root@152.53.145.65
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

### OpenClaw Node Service
```bash
# /root/.config/systemd/user/openclaw-node.service
[Unit]
Description=OpenClaw Node Host
cAfter=network-online.target openclaw-tunnel.service
Requires=openclaw-tunnel.service

[Service]
ExecStart=/usr/bin/openclaw node run --host 127.0.0.1 --port 18789
Restart=always
Environment=HOME=/root

[Install]
WantedBy=default.target
```

### WireGuard Konfiguration
```ini
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.2/24
PrivateKey = [NODE2_PRIVATE_KEY]
ListenPort = 51820

[Peer]
PublicKey = Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
AllowedIPs = 10.10.0.0/24
Endpoint = 152.53.145.65:51820
PersistentKeepalive = 25
```

### Firewall (UFW)
```bash
ufw allow 22/tcp                    # SSH
ufw allow 51820/udp                 # WireGuard
ufw allow from 10.10.0.0/24         # WireGuard Network
ufw allow 18789/tcp from 10.10.0.0/24  # OpenClaw via VPN
```

### Xvfb (Playwright-Support)
```bash
# Installation
apt-get install -y xvfb

# Verifikation
which Xvfb  # /usr/bin/Xvfb
```

### Tailscale (ohne DNS-Verwaltung)
```bash
# DNS nicht überschreiben (kritisch für externe Auflösung)
tailscale up --accept-dns=false --accept-routes --hostname=openclaw-node2
```

### Services
```bash
systemctl enable wg-quick@wg0
systemctl --user enable openclaw-tunnel
systemctl --user enable openclaw-node
```

---

## Node 3: xNetX (CentOS Stream 8)

### OpenClaw Node Mode
- **Verbindung:** Via SSH Tunnel zu Gateway
- **Host:** 127.0.0.1:18788 (lokaler Tunnel)
- **Mode:** remote

### SSH Tunnel Service
```bash
# /root/.config/systemd/user/node3-to-gateway.service
[Unit]
Description=SSH Tunnel from Node 3 to Gateway
After=network-online.target

[Service]
Type=simple
Environment=SSHPASS='1363Getin#'
ExecStart=/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -N -L 0.0.0.0:18788:127.0.0.1:18789 root@152.53.145.65
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

### OpenClaw Node Service
```bash
# /root/.config/systemd/user/openclaw-node.service
[Unit]
Description=OpenClaw Node Host
After=network-online.target node3-to-gateway.service
Requires=node3-to-gateway.service

[Service]
ExecStart=/usr/local/bin/openclaw node run --host 127.0.0.1 --port 18788
Restart=always

[Install]
WantedBy=default.target
```

### WireGuard Konfiguration (Wartet auf Kernel-Support)
```ini
# /etc/wireguard/wg0.conf (vorbereitet)
[Interface]
Address = 10.10.0.3/24
PrivateKey = QN0IpCUdp1nT7f+w07mFC9IxASJ1xjZ5gpZpx+ilaXo=
ListenPort = 51820

[Peer]
PublicKey = Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
AllowedIPs = 10.10.0.0/24
Endpoint = 152.53.145.65:51820
PersistentKeepalive = 25
```

### Firewall (firewalld)
```bash
firewall-cmd --permanent --add-port=51820/udp
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.10.0.0/24" accept'
firewall-cmd --reload
```

### Xvfb (Playwright-Support)
```bash
# Installation (Tailscale-DNS deaktivieren falls nötig)
echo -e 'nameserver 8.8.8.8\nnameserver 1.1.1.1' > /etc/resolv.conf
yum install -y xorg-x11-server-Xvfb

# Verifikation
which Xvfb  # /usr/bin/Xvfb
```

### Tailscale (ohne DNS-Verwaltung)
```bash
# DNS nicht überschreiben (kritisch für yum!)
tailscale up --accept-dns=false --accept-routes --hostname=openclaw-node3
```

### Services
```bash
systemctl --user enable node3-to-gateway
systemctl --user enable openclaw-node
```

---

## Node 4: Webhosting (Netcup)

### Übersicht
- **Provider:** Netcup Webhosting 1000 SE a1
- **Domain:** xstoragex.de
- **IP:** 91.204.46.22
- **Typ:** Shared Hosting (nicht VPS)

### Features
| Feature | Status |
|---------|--------|
| SSL-Zertifikate | ✅ Let's Encrypt (unbegrenzt) |
| Speicher | 25 GB SSD |
| Traffic | Unbegrenzt |
| PHP | 7.2 - 8.0 |
| MySQL | ✅ |
| SSH/FTP | ✅ |

### Aktuelle Nutzung
- Datei-Download-Seite (Link zu Node 3 /home/share)
- E-Mail-Hosting

### Zukünftige HTTPS-Verbindung zu Node 1
```
[User] → https://xstoragex.de → [Node 4 nginx] → [WireGuard/Tailscale] → [Node 1 Gateway]
         SSL terminieren                                          wss:// intern
```
**Voraussetzung:** Webhosting Upgrade auf 4000+ für nginx Reverse Proxy

---

## Node 5: Redmi Note 11 (Android)

### Voraussetzungen
- OpenClaw Android App installiert
- WireGuard Verbindung zum Gateway

### WireGuard Konfiguration
```ini
[Interface]
PrivateKey = [REDACTED]
Address = 10.10.0.5/24
DNS = 8.8.8.8

[Peer]
PublicKey = Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
AllowedIPs = 10.10.0.0/24
Endpoint = 152.53.145.65:51820
PersistentKeepalive = 25
```

### Verbindungsoptionen

#### Option 1: WireGuard VPN (Empfohlen)
1. WireGuard App auf dem Handy installieren
2. Konfiguration manuell eintragen (siehe DATASHEET_NODE5.md)
3. VPN aktivieren
4. OpenClaw App verbindet automatisch über `10.10.0.1:18789`

#### Option 2: HTTPS/WSS (Sicher)
Wenn Node 1 SSL eingerichtet hat:
```javascript
const ws = new WebSocket('wss://openclaw.lan');  // Domain via CERTBOT.md
```

#### Option 3: Tailscale
1. Tailscale auf dem Handy installieren
2. Zum gleichen Tailnet wie das Gateway verbinden
3. OpenClaw verbindet automatisch über Tailscale IP

### Sicherheitshinweis
Mobile Verbindungen über das Internet erfordern immer WSS (WebSocket Secure). WS funktioniert nur für:
- Lokale Verbindungen (localhost)
- Private LAN-Verbindungen
- VPN-Tunnel (WireGuard/Tailscale)

### Aufgaben
| Feature | Status |
|---------|--------|
| WireGuard Config | ⏳ Manuell eintragen |
| OpenClaw Pairing | ⏳ QR-Code scannen |
| Remote Monitoring | Geplant |
| Alert Empfänger | Geplant |

---

## SSH Keys & Zugänge

| Key | Pfad | Zweck | Node |
|-----|------|-------|------|
| node2_tunnel | /root/.ssh/node2_tunnel | Gateway → Node 2 | Node 1 |
| node1_tunnel | /root/.ssh/node1_tunnel | Node 2 → Gateway | Node 2 |
| Node 3 Passwort | - | Gateway → Node 3 | Node 1 |

---

## Troubleshooting

### Node nicht verbunden
```bash
# Auf dem Node:
openclaw node status
systemctl --user restart openclaw-node

# Auf dem Gateway:
openclaw nodes status
openclaw nodes approve --latest  # Falls pairing pending
```

### WireGuard Verbindungsprobleme
```bash
# Gateway
wg show
ping 10.10.0.2
ping 10.10.0.3

# Node
wg show
ping 10.10.0.1
```

### SSH Tunnel Probleme
```bash
# Tunnel-Status prüfen
systemctl --user status openclaw-tunnel

# Manuell testen
ssh -N -L 18789:127.0.0.1:18789 root@152.53.145.65
```

---

## Wartungsbefehle

### Alle Services neu starten
```bash
# Gateway
openclaw gateway restart
sudo systemctl restart wg-quick@wg0

# Node 2
systemctl --user restart openclaw-tunnel
systemctl --user restart openclaw-node

# Node 3  
systemctl --user restart node3-to-gateway
systemctl --user restart openclaw-node
```

### Status-Check
```bash
# Gateway
openclaw nodes status
openclaw gateway status
sudo wg show

# Nodes
openclaw node status
```

---

## Dokumentationsstruktur

```
~/workspace/
│
├── INFRASTRUCTURE.md           ← Diese Datei (Master)
├── INFRASTRUCTURE.md     ← Node-spezifische Details
├── INFRASTRUCTURE.md  ← Hardware-Dokumentation
├── INFRASTRUCTURE.md   ← Cluster-Konfiguration
│
├── docs/
│   ├── ops-hub/                ← Operations-Hub Dokumentation
│   ├── websearch-mcp/          ← WebSearch & MCP Integration
│   ├── memory-system/          ← Agent-Memory & Identität
│   ├── kommunikation/          ← Slack, Discord, etc.
│   ├── hardware/               ← Hardware-Datenblätter
│   ├── nodes/                  ← Node-spezifische Daten
│   └── cluster/                ← Cluster-Reports
│
├── scripts/                    ← Ausführbare Scripts (Master)
│   ├── *.sh                    ← Shell-Scripts
│   └── WEBSEARCH_SCRIPTS.md    ← Script-Dokumentation
│
├── services/                   ← Systemd Services (Master)
│   ├── *.service               ← Service-Dateien
│   └── *.cron → ../crons/      ← Symlinks zu Crons
│
├── crons/                      ← Cron-Jobs (Master)
│   └── *.cron                  ← Cron-Dateien
│
├── nodes/                      ← Node-Konfigurationen
├── hardware/                   ← Hardware-Inventar
├── cluster/                    ← Cluster-Verwaltung
├── dashboard/                  ← Dashboards
└── git/                        ← Git Repository

~/.openclaw/
│
├── scripts/ → ~/workspace/scripts/    ← Symlink
├── services/ → ~/workspace/services/  ← Symlink
├── crons/ → ~/workspace/crons/       ← Symlink
│
├── cron/                   ← Cron-Jobs (intern, nicht anfassen)
├── cache/                  ← Zwischenspeicher
├── canvas/                 ← Canvas-Daten
├── completions/            ← LLM Completions
├── credentials/            ← Authentifizierung
├── db/                     ← Datenbanken
├── delivery-queue/         ← Nachrichten-Queue
├── devices/                ← Geräteregistrierung
├── flows/                  ← Flow-Definitionen
├── identity/               ← Identitätsdaten
├── logs/                   ← System-Logs (≠ workspace/logs/)
├── media/                  ← Medien-Uploads
├── memory/                 ← SQLite Speicher (≠ workspace/memory/)
├── nodes/                  ← Node-Status JSON (≠ workspace/nodes/)
├── skills/                 ← OpenClaw-Skills (≠ workspace/skills/)
├── subagents/              ← Sub-Agenten
└── tasks/                  ← Task-Queue
```

## Dokumentation aktualisieren

Letzte Aktualisierung: 2026-04-18

**Änderungen 2026-04-18:**
- WebSearch & MCP Integration vollständig dokumentiert (docs/websearch-mcp/)
- Dokumentationsstruktur konsolidiert (alle .md im Root, Spiegelung in docs/)
- Verzeichnisse vereinheitlicht: hardware/, nodes/, cluster/, dashboard/
- files von ~/.openclaw/ nach ~/workspace/ verschoben (IDENTITY.md, USER.md, SKILL-INDEX.md)
- **Cron-Redundanz implementiert:** @reboot + */20 Rhythmus für Gateway-Start
- **Database Maintainer:** Automatische DB-Wartung alle 30 Minuten
- **docs.db + tree.db v2:** Vollständige Dokumentations- und Datei-Tracking-Datenbanken

---

## Cron-System & Redundanz

### Gateway-Start Redundanz

| Mechanismus | Intervall | Zweck |
|-------------|-----------|-------|
| **@reboot** | Boot-Zeit | Primärer Startversuch |
| ***/20 * * * *** | Alle 20 Min | Fallback + Überwachung |

**Funktionsweise:**
- @reboot versucht Gateway direkt nach Boot zu starten
- */20 Rhythmus prüft alle 20 Minuten ob Gateway läuft
- Falls nicht gestartet: Automatischer Neustart
- Falls gestartet: Keine Aktion (keine Multiplikation)

**Crontab (openclaw):**
```
# Primär: @reboot Startversuch
@reboot sleep 10 && /home/openclaw/.npm-global/bin/openclaw gateway start >> /tmp/openclaw-gateway.log 2>&1

# Fallback: Regelmäßige Überprüfung
*/20 * * * * /home/openclaw/.npm-global/bin/openclaw gateway start >> /tmp/openclaw-gateway.log 2>&1
```

### Database Maintainer

Automatische Wartung alle 30 Minuten:
- Tree-Scan (`tree -a -L 8`)
- docs.db Aktualisierung
- tree.db v2 Aktualisierung
- Stündliche Backups (3 Tage Retention)

**Crontab-Eintrag:**
```
*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1
```

**Änderungen 2026-04-10:**
- Node 4 = Webhosting (xstoragex.de), Node 5 = Redmi Note 11 korrigiert
- WireGuard Konfiguration Node 5 (10.10.0.5) hinzugefügt
- Node 4 Webhosting + Node 5 Mobile detailliert beschrieben
- CERTBOT.md für SSL/HTTPS erstellt
- Tailscale DNS-Konfiguration (accept-dns=false) dokumentiert
