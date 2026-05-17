# OpenClaw Cluster Node-Konfiguration

**Dokumentation:** Vollständige Übersicht aller Cluster-Nodes  
**Erstellt:** 2026-04-08  
**Status:** ✅ Aktuell

---

## Übersicht

| Node | Provider | Standort | Rolle | Status |
|------|----------|----------|-------|--------|
| Node 1 | Hetzner | Deutschland | Gateway/Main | ✅ Online |
| Node 2 | Netcup | Deutschland | Worker | ✅ Online |
| Node 3 | xNetX | Deutschland | Worker | ✅ Online |

---

## Node 1 (Main/Gateway)

### Hardware & System
| Eigenschaft | Wert |
|-------------|------|
| Hostname | v2202604104722446711 |
| IP (Public) | 152.53.145.65 |
| IP (Tailscale) | 100.111.216.40 |
| IP (WireGuard) | 10.10.0.1 |
| OS | Ubuntu 24.04 LTS |
| Kernel | 6.8.0-107-generic |
| RAM | 16 GB |
| Disk | 500 GB SSD |

### Dienste
| Dienst | Port | Status |
|--------|------|--------|
| OpenClaw Gateway | 18789 | ✅ Running |
| NGINX | 16000 | ✅ Running |
| Tailscale | - | ✅ Active |
| WireGuard | 51820 | ✅ Active |

### VPN-Verbindungen
| Typ | Ziel | Status |
|-----|------|--------|
| Tailscale | Node 2 (100.92.155.34) | ✅ 1ms |
| Tailscale | Node 3 (100.73.154.125) | ✅ 1ms |
| WireGuard | Node 2 (10.10.0.2) | ✅ Active |
| SSH Tunnel | Node 2 (18790, 15000) | ✅ Active |
| SSH Tunnel | Node 3 (18792) | ✅ Active |

---

## Node 2 (Netcup)

### Hardware & System
| Eigenschaft | Wert |
|-------------|------|
| Hostname | v2202603104722445775 |
| IP (Public) | 159.195.78.116 |
| IP (Tailscale) | 100.92.155.34 |
| IP (WireGuard) | 10.10.0.2 |
| OS | Ubuntu 24.04 LTS (Noble) |
| Kernel | 6.8.x |
| RAM | 8 GB |
| Disk | 200 GB SSD |

### Dienste
| Dienst | Port | Status |
|--------|------|--------|
| OpenClaw Node | 18788 | ✅ Running |
| Tailscale | - | ✅ Active |
| WireGuard | 51820 | ✅ Active |
| TikTok API | 5000 | ✅ Running |

### VPN-Verbindungen
| Typ | Ziel | Status |
|-----|------|--------|
| Tailscale | Node 1 (100.111.216.40) | ✅ 1ms |
| Tailscale | Node 3 (100.73.154.125) | ✅ 1ms |
| WireGuard | Node 1 (10.10.0.1) | ✅ Active |
| SSH Reverse | Node 1 (18790, 15000) | ✅ Active |

---

## Node 3 (xNetX)

### Hardware & System
| Eigenschaft | Wert |
|-------------|------|
| Hostname | xnetx |
| IP (Public) | 185.162.248.90 |
| IP (Tailscale) | 100.73.154.125 |
| OS | CentOS Stream 8 |
| Kernel | 4.18.0-301.el8.x86_64 |
| RAM | 4 GB |
| Disk | 40 GB SSD |

### Einschränkungen
- ❌ Kein WireGuard (Kernel zu alt: 4.18.0)
- ❌ Kein Kernel-Modul für WireGuard verfügbar
- ✅ Tailscale funktioniert (userspace-Modus)

### Dienste
| Dienst | Port | Status |
|--------|------|--------|
| OpenClaw Node | 18788 | ✅ Running |
| Tailscale | - | ✅ Active |
| ZNC IRC | - | ✅ Running |
| pbot (IRC) | - | ✅ Running |

### VPN-Verbindungen
| Typ | Ziel | Status |
|-----|------|--------|
| Tailscale | Node 1 (100.111.216.40) | ✅ 1ms |
| Tailscale | Node 2 (100.92.155.34) | ✅ 1ms |
| SSH Reverse | Node 1 (18792) | ✅ Active |

---

## Netzwerk-Topologie

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         OPENCLAW CLUSTER                                 │
│                     (Multi-Layer VPN Architektur)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────┐                                                    │
│   │   INTERNET      │                                                    │
│   └────────┬────────┘                                                    │
│            │                                                             │
│   ┌────────▼────────┐                                                    │
│   │  Tailscale      │◄─────────────────────────────────────────────┐     │
│   │  Control Plane  │                                             │     │
│   └─────────────────┘                                             │     │
│                                                                   │     │
│  ┌──────────────────────────────────────────────────────────────┐ │     │
│  │                    TAILSCALE MESH (100.x.x.x)                │ │     │
│  │  ┌──────────────┐      ┌──────────────┐      ┌────────────┐  │ │     │
│  │  │ 100.111.216.40│◄────►│ 100.92.155.34│◄────►│100.73.154.│  │ │     │
│  │  │ openclaw-node1│ 1ms  │ openclaw-node2│ 1ms  │  openclaw  │  │ │     │
│  │  │ (Hetzner)     │      │ (Netcup)      │      │  -node3    │  │ │     │
│  │  │ Node 1 Gateway│      │ TikTok API    │      │  (xNetX)   │  │ │     │
│  │  └──────┬────────┘      └──────────────┘      └────────────┘  │ │     │
│  └─────────┼────────────────────────────────────────────────────┘ │     │
│            │                                                      │     │
│  ┌─────────▼────────────────────────────────────────────────────┐ │     │
│  │              WIREGUARD BACKUP (10.10.0.x/24)                 │ │     │
│  │  ┌──────────────┐              ┌──────────────┐              │ │     │
│  │  │ 10.10.0.1    │◄────────────►│ 10.10.0.2    │              │ │     │
│  │  │ openclaw-node1│   UDP 51820  │ openclaw-node2│              │ │     │
│  │  └──────────────┘              └──────────────┘              │ │     │
│  └──────────────────────────────────────────────────────────────┘ │     │
│            │                                                      │     │
│  ┌─────────▼────────────────────────────────────────────────────┐ │     │
│  │              SSH-TUNNEL BACKUP (localhost)                   │ │     │
│  │  Port 18790 ─────► Node 2 (OpenClaw)                         │ │     │
│  │  Port 15000 ─────► Node 2 (TikTok API)                       │ │     │
│  │  Port 18792 ─────► Node 3 (OpenClaw)                         │ │     │
│  └──────────────────────────────────────────────────────────────┘ │     │
│                                                                   │     │
└───────────────────────────────────────────────────────────────────┴─────┘
```

---

## VPN-Prioritäten

| Priorität | VPN | Nodes | Latenz | Status |
|-----------|-----|-------|--------|--------|
| 1 | Tailscale | Alle 3 | 1ms | ✅ Primär |
| 2 | WireGuard | Node 1-2 | <1ms | 🔄 Backup |
| 3 | SSH-Tunnel | Alle 3 | 1-5ms | 🔄 Notfall |

---

## Wartung & Monitoring

### Tägliche Checks
```bash
# Tailscale Status
openclaw nodes status
tailscale status

# VPN-Konnektivität
tailscale ping openclaw-node2
tailscale ping openclaw-node3

# Dienst-Status
systemctl is-active tailscaled
systemctl is-active wg-quick@wg0
```

### Wöchentliche Checks
- [ ] Tailscale Versionen prüfen
- [ ] WireGuard Handshakes prüfen
- [ ] SSH-Tunnel Logs prüfen
- [ ] Bandbreitennutzung analysieren

### Monatliche Checks
- [ ] Key-Rotation planen
- [ ] ACL-Regeln überprüfen
- [ ] Backup-Strategie testen
- [ ] Dokumentation aktualisieren

---

## Fehlerbehebung

### Node nicht erreichbar
1. **Tailscale prüfen:** `tailscale status`
2. **WireGuard prüfen:** `sudo wg show`
3. **SSH-Tunnel prüfen:** `ss -tlnp | grep 1879`
4. **Netzwerk prüfen:** `ping <node-ip>`

### VPN-Verbindung langsam
1. **Pfad analysieren:** `tailscale ping --verbose <node>`
2. **DERP-Relay prüfen:** `tailscale netcheck`
3. **Alternative VPN testen:** WireGuard oder SSH

---

## Dokumentationsverlauf

| Datum | Änderung | Autor |
|-------|----------|-------|
| 2026-04-08 | Dokumentation erstellt | @rt11 |
| 2026-04-08 | Tailscale auf allen Nodes aktiviert | @rt11 |
| 2026-04-08 | Multi-Layer VPN dokumentiert | @rt11 |

---

**Nächste Überprüfung:** 2026-05-08 (monatlich)
