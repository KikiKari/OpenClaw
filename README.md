# OpenClaw Infrastruktur - Workspace Übersicht

**Stand:** 2026-04-06

## 📁 Wichtige Dokumente

| Dokument | Beschreibung | Status |
|----------|--------------|--------|
| **INFRASTRUCTURE.md** | Komplette Infrastruktur-Dokumentation mit allen Nodes, WireGuard, Firewalls | ✅ Aktuell |
| **TUNNELS.md** | SSH Tunnel Konfiguration und Port-Mapping | ✅ Aktuell |
| **WIREGUARD_FINAL_STATUS.md** | WireGuard VPN Status und Konfiguration | ✅ Aktuell |
| **SLACK.md** | Slack-Integration & Bot-Konfiguration | ✅ Aktuell |
| **HEARTBEAT.md** | Periodische Checks und Monitoring | ✅ Aktuell |
| **NODE3_WIREGUARD_SETUP.md** | Fallback-Doku für Node 3 WireGuard | ⚠️ Wartend |
| **NODES_CONNECT.md** | Verbindungsplan (historisch) | 📁 Archiv |

---

## 🖥️ Nodes Status (Live)

```
┌──────────┬──────────────────────┬──────────────┬─────────────────┬──────────┐
│ Node     │ Hostname             │ IP           │ Rolle           │ Status   │
├──────────┼──────────────────────┼──────────────┼─────────────────┼──────────┤
│ Node 1   │ v2202604104722446711 │ 152.53.145.65│ Gateway         │ ✅ Aktiv │
│ Node 2   │ v2202603104722445775 │ 159.195.78.116│ Node Host      │ ✅ Aktiv │
│ Node 3   │ xnetx                │ 185.162.248.90│ Node Host      │ ✅ Aktiv │
│ Node 4   │ Redmi Note 11        │ Mobil        │ Mobile Client  │ ⏳ Offen │
└──────────┴──────────────────────┴──────────────┴─────────────────┴──────────┘
```

**OpenClaw Node Mode:** ✅ 2/2 Nodes verbunden (Node 2 & Node 3)

**WireGuard VPN:** ✅ Gateway + Node 2 verbunden | ⚠️ Node 3 wartet auf Kernel

---

## 🔧 Schnellbefehle

### Status prüfen
```bash
# Alle Nodes
openclaw nodes status

# WireGuard
sudo wg show

# SSH Tunnel
ss -tlnp | grep -E '15000|18790|18792|18793|5002|51820'
```

### Services neu starten
```bash
# Auf Gateway
openclaw gateway restart

# Auf Node 2 (via SSH)
ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 \
  "systemctl --user restart openclaw-tunnel openclaw-node"

# Auf Node 3 (via Proxy)
ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 \
  "sshpass -p '1363Getin#' ssh root@185.162.248.90 \
  'systemctl --user restart node3-to-gateway openclaw-node'"
```

---

## 🌐 Netzwerk-Topologie

```
                    INTERNET
                       │
      ┌────────────────┼────────────────┐
      │                │                │
   Gateway         Node 2            Node 3
152.53.145.65   159.195.78.116    185.162.248.90
   10.10.0.1      10.10.0.2         10.10.0.3
      │
   WireGuard VPN (10.10.0.0/24)
      │              │                │
   SSH Tunnel    SSH Tunnel
                  (Nur Node 2)
```

---

## 📋 Aktuelle Konfigurationen

### WireGuard
- **Gateway (10.10.0.1):** Lauscht auf 51820/udp
- **Node 2 (10.10.0.2):** Verbunden via Endpoint 152.53.145.65:51820
- **Node 3 (10.10.0.3):** Konfiguriert aber kein Kernel-Support

### OpenClaw Node Mode
- **Node 2:** Verbindet via SSH Tunnel (127.0.0.1:18789) → ✅ Aktiv
- **Node 3:** Verbindet via SSH Tunnel (127.0.0.1:18788) → ✅ Aktiv

### Firewall
- **Gateway:** UFW aktiv, Ports 22, 51820/udp, 18789/tcp offen
- **Node 2:** UFW aktiv, WireGuard + VPN-Netzwerk erlaubt
- **Node 3:** firewalld aktiv, WireGuard Port + rich rules konfiguriert

---

## 📝 Nächste Schritte

1. **Node 4 (Redmi Note 11):**
   - WireGuard App installieren oder
   - Tailscale Einrichtung prüfen
   - OpenClaw Mobile App verbinden

2. **Node 3 WireGuard:**
   - Warten auf Kernel-Update oder
   - Kernel-Header installieren wenn verfügbar

3. **Monitoring:**
   - Heartbeat-Checks einrichten
   - Automatische Alerts bei Node-Ausfall

---

**Dokumentationen aktualisiert am:** 2026-04-06
