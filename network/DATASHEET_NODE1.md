# DataSheet: Node 1 (Gateway)

## Hardware & Hosting
| Attribut | Wert |
|----------|------|
| **Hostname** | v2202604104722446711 |
| **Server** | VPS (Hetzner) |
| **Standort** | Nürnberg |
| **IPv4** | 152.53.145.65 |
| **Tailscale IP** | 100.111.216.40 |
| **OS** | Ubuntu |
| **Rolle** | OpenClaw Gateway / WireGuard Hub / Tailscale Node |

## VPN
| Attribut | Wert |
|----------|------|
| **Tailscale IP** | 100.111.216.40 |
| **WireGuard IP** | 10.10.0.1/24 |
| **WireGuard PublicKey** | Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk= |
| **WireGuard Port** | 51820/udp |
| **Status** | ✅ Aktiv (Hub) |

## OpenClaw Gateway
| Attribut | Wert |
|----------|------|
| **Rolle** | Cluster Gateway |
| **Port** | 18789/tcp |
| **Autostart** | Cron @reboot (openclaw user) |
| **Status** | ✅ Aktiv |
| **Bound Nodes** | Node 2, Node 3, Node 5 |

## Services
| Service | Port | Status |
|---------|------|--------|
| OpenClaw Gateway | 18789 | ✅ |
| Tailscale | 41641 | ✅ |
| WireGuard | 51820 | ✅ |
| SSH | 22 | ✅ |

## Cron-Jobs (Serverwartung)

### Benutzer: openclaw
| Zeitplan | Befehl | Zweck |
|----------|--------|-------|
| `@reboot` (10s delay) | `/home/openclaw/.npm-global/bin/openclaw gateway start` | Gateway automatisch beim Systemstart starten |
| `0 3 * * *` (täglich 03:00) | `/home/openclaw/bin/daily-db-backup.sh` | Tägliches Datenbank-Backup |

### Benutzer: root
| Zeitplan | Befehl | Zweck |
|----------|--------|-------|
| `0 3 * * *` (täglich 03:00) | `/opt/backup/scripts/backup-node2.sh` | Backup von Node 2 |

## Sudo-Berechtigung
| Benutzer | Konfiguration | Passwort |
|----------|---------------|----------|
| openclaw | `/etc/sudoers.d/openclaw` — `ALL=(ALL) NOPASSWD: ALL` | Nicht erforderlich |

## Status
| Komponente | Status |
|------------|--------|
| Gateway | ✅ OK |
| Tailscale | ✅ OK |
| WireGuard Hub | ✅ OK |
| Node 2 (Worker) | ✅ paired · connected |
| Node 3 (Worker) | ✅ paired · connected |
| Node 5 (Mobile) | ✅ paired · connected |

---

**Zuletzt aktualisiert:** 2026-04-11
