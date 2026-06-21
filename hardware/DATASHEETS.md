# DataSheets - Komplette Infrastruktur-Dokumentation

**Stand:** 2026-04-11

---

## Knoten-Übersicht

| Node | Typ | Standort | Primäre IP | Status |
|------|-----|----------|------------|--------|
| **Node 1** | Gateway (VPS) | Hetzner | 152.53.145.65 | ✅ Aktiv |
| **Node 2** | Node Host (VPS) | Netcup | 159.195.78.116 | ✅ Aktiv |
| **Node 3** | Node Host (VPS) | Netcup | 185.162.248.90 | ✅ Aktiv |
| **Node 4** | Webhosting | Netcup | 91.204.46.22 | ✅ Aktiv |
| **Node 5** | Mobile Client | - | (DHCP/Mobil) | ✅ Aktiv |
| **Node 6** | Notebook (Windows) | Lokal | (DHCP) | ✅ Aktiv |

---

## Detaillierte DataSheets

### [→ DATASHEET_NODE1.md](DATASHEET_NODE1.md) (Gateway + Certbot SSL)
### [→ DATASHEET_NODE2.md](DATASHEET_NODE2.md) (Netcup VPS)
### [→ DATASHEET_NODE3.md](DATASHEET_NODE3.md) (xnetx VPS)
### [→ DATASHEET_NODE4.md](DATASHEET_NODE4.md) (Webhosting xstoragex.de)
### [→ DATASHEET_NODE5.md](DATASHEET_NODE5.md) (Redmi Note 11 Mobile)
### [→ DATASHEET_NODE6.md](DATASHEET_NODE6.md) (Lenovo IdeaPad Slim 3 — Windows 11)

### [→ CERTBOT.md](CERTBOT.md) (SSL/HTTPS Konfiguration)

---

## Schnell-Referenz

### VPN-Tunnel (Multi-Layer)

**Priorität:** Tailscale (primär) → WireGuard (sekundär) → SSH-Tunnel (Notfall)

#### Tailscale (Primär)
| Node | Tailscale IP | Status |
|------|--------------|--------|
| Node 1 (Gateway) | 100.111.216.40 | ✅ Online |
| Node 2 (Netcup) | 100.92.155.34 | ✅ Online |
| Node 3 (xNetX) | 100.73.154.125 | ✅ Online |

#### WireGuard (Sekundär)
| Node | WG IP | PublicKey | Status |
|------|-------|-----------|--------|
| Node 1 (Gateway) | 10.10.0.1/24 | Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk= | ✅ Hub |
| Node 2 | 10.10.0.2/32 | LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0= | ✅ Aktiv |
| Node 3 | 10.10.0.3/32 | Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA= | ❌ Kernel-Fehler |
| Node 5 | 10.10.0.5/32 | IKaeGkYyBAabN2R+tPQCBKK1RBc1AIacNt9pATEZQRs= | ⏳ Ausstehend |

#### SSH-Tunnel (Notfall-Fallback)
| Node | Tunnel | Port | Status |
|------|--------|------|--------|
| Node 2 | Reverse SSH + Autossh | 18790 | ✅ Aktiv |
| Node 2 | Legacy TikTok API Tunnel (nicht vom Dispatcher genutzt) | 15000 | ✅ Aktiv |
| Node 3 | SSH-Tunnel | 18788 | ✅ Aktiv |

### OpenClaw Node Mode
| Node | Verbindung | Caps | Status |
|------|------------|------|--------|
| Node 2 | localhost:18789 (via Tunnel) | browser, system | ✅ paired · connected |
| Node 3 | localhost:18788 (via SSH-Tunnel) | browser, system | ✅ paired · connected |
| Node 5 | 10.10.0.5 (WireGuard) | browser, system | ✅ paired · connected |
| Node 6 | localhost:18789 (via SSH-Tunnel) | browser, system | ✅ paired · connected |

### SSL/HTTPS
| Node | Setup | Status |
|------|-------|--------|
| Node 1 | Certbot + nginx | ⏳ Domain nötig |
| Node 4 | Let's Encrypt (Plesk) | ✅ Aktiv |

---

## SSH-Zugang (Zentral verwaltet in ~/.config/openclaw/sud)

| Node | Benutzer | Methode | Key/Passwort |
|------|----------|---------|--------------|
| Node 1 | openclaw | key | ~/.ssh/id_ed25519 |
| Node 2 | root | key | ~/.ssh/id_ed25519 |
| Node 2 | openclaw | password | (siehe pws) |
| Node 3 | root | key | ~/.ssh/id_ed25519_node3 |
| Node 3 | openclaw | password | (siehe pws) |

---

## Node Monitoring (Cron-Jobs, eingerichtet 2026-04-11)

Alle 20 Minuten wird geprüft, ob der `openclaw-node` Prozess läuft. Falls nicht, wird er automatisch neu gestartet.

| Node | Cron-Datei | Startbefehl | Log |
|------|------------|-------------|-----|
| Node 2 | /etc/cron.d/openclaw-node-monitor | `openclaw node run --host 127.0.0.1 --port 18789` | /var/log/openclaw-node-monitor.log |
| Node 3 | /etc/cron.d/openclaw-node-monitor | `openclaw node run --host 127.0.0.1 --port 18788` | /var/log/openclaw-node-monitor.log |

---

## Dienste auf Node 2

| Dienst | Typ | Status |
|--------|-----|--------|
| tailscaled | systemd (system) | ✅ active |
| wg0 (WireGuard) | systemd (system) | ✅ active |
| openclaw-tunnel | systemd (system) | ✅ active |
| tunnel-18790 (Autossh) | systemd (system) | ✅ active |
| tunnel-15000 (Legacy TikTok API; nicht vom Dispatcher genutzt) | systemd (system) | ✅ active |
| openclaw-gateway | systemd (user/openclaw) | ✅ active |
| openclaw-node | root-Prozess + Cron-Monitor | ✅ active |

## Dienste auf Node 3

| Dienst | Typ | Status |
|--------|-----|--------|
| tailscaled | systemd (system) | ✅ active |
| openclaw-node | root-Prozess + Cron-Monitor | ✅ active |

---

## Netzwerk-Topologie

```
                        INTERNET
                           │
          ┌────────────────┼────────────────┬──────────────┐
          │                │                │              │
     ┌────▼────┐      ┌────▼────┐      ┌────▼────┐   ┌────▼────┐
     │ Node 1  │      │ Node 2  │      │ Node 3  │   │ Node 4  │
     │ Gateway │      │ Netcup  │      │ xnetx   │   │Webhostin│
     │152.53...│      │159.195..│      │185.162..│   │91.204...│
     │10.10.0.1│      │10.10.0.2│      │10.10.0.3│   │         │
     │TS:100.  │      │TS:100.  │      │TS:100.  │   │         │
     │111.216. │      │92.155.  │      │73.154.  │   │         │
     │40       │      │34       │      │125      │   │         │
     └────┬────┘      └────┬────┘      └────┬────┘   └────┬────┘
          │                │                │              │
          └────────────────┴────────────────┘              │
              Tailscale + WireGuard VPN                    │
           ┌──────────┐                                    │
           │ Node 5   │                                    │
           │ Redmi    │ (Mobil)                            │
           │10.10.0.5 │                                    │
           └──────────┘                                    │
                                                           │
                                            xstoragex.de (HTTPS)
```

---

## Services & Ports

| Node | Service | Port | Protokoll | Zweck |
|------|---------|------|-----------|-------|
| Node 1 | OpenClaw Gateway | 18789 | TCP | Node Management (intern) |
| Node 1 | nginx SSL | 443 | TCP | HTTPS für Clients (wss://) |
| Node 1 | certbot | 80 | TCP | Let's Encrypt Validation |
| Node 1 | WireGuard | 51820 | UDP | VPN Hub |
| Node 1 | Tailscale | 41641 | UDP | Tailscale Mesh |
| Node 2 | WireGuard | 51820 | UDP | VPN Client |
| Node 2 | Tailscale | 41641 | UDP | Tailscale Mesh |
| Node 2 | OpenClaw Gateway (lokal) | 18789 | TCP | Lokaler Gateway |
| Node 2 | SSH Reverse Tunnel | 18790 | TCP | Tunnel zu Node 1 |
| Node 2 | Legacy TikTok API Tunnel (nicht vom Dispatcher genutzt) | 15000 | TCP | Tunnel zu Node 1 |
| Node 3 | Tailscale | 41641 | UDP | Tailscale Mesh |
| Node 3 | SSH-Tunnel | 18788 | TCP | Tunnel zu Gateway |
| Node 4 | Webhosting | 443 | TCP | xstoragex.de (HTTPS) |
| Node 4 | MySQL | 3306 | TCP | Datenbank |
| Node 4 | Mail | 25/587/993 | TCP | SMTP/IMAP |

---

## Domain-Mapping

| Domain | Ziel | Zweck |
|--------|------|-------|
| xnetx.de | 185.162.248.90 | Node 3 Hauptdomain |
| xstoragex.de | 91.204.46.22 | Node 4 Webhosting |
| (offen) | 152.53.145.65 | Node 1 SSL Gateway (⏳) |

---

## Historie

| Datum | Änderung |
|-------|----------|
| 2026-04-06 | Ursprüngliche Dokumentation erstellt |
| 2026-04-10 | **Node-Nummern korrigiert**: 4=Webhosting, 5=Redmi |
| 2026-04-10 | CERTBOT.md hinzugefügt |
| 2026-04-10 | WireGuard IP für Node 5: 10.10.0.5 |
| 2026-04-11 | Tailscale IPs hinzugefügt, VPN Multi-Layer dokumentiert |
| 2026-04-11 | SSH-Zugangsreferenz hinzugefügt (sud/pws) |
| 2026-04-11 | Node 5 Status: ✅ Aktiv (paired · connected) |
| 2026-04-11 | Cron-Jobs für openclaw-node Monitoring auf Node 2+3 eingerichtet |
| 2026-04-11 | Dienste-Übersicht für Node 2+3 hinzugefügt |
| 2026-04-11 | Netzwerk-Topologie mit Tailscale IPs aktualisiert |
| 2026-04-11 | **Node 6 (Lenovo IdeaPad Slim 3, Windows 11) hinzugefügt** |

---

**Dokumentation aktualisiert am:** 2026-04-11
