# DataSheet: Node 2 (Netcup VPS)

## Hardware & Hosting
| Attribut | Wert |
|----------|------|
| **Hostname** | v2202603104722445775 |
| **Server** | VPS G8 (Netcup) |
| **Standort** | Nürnberg |
| **IPv4** | 159.195.78.116 |
| **OS** | Ubuntu |

## Netzwerk-Konfiguration
| Attribut | Wert |
|----------|------|
| **IPv4** | 159.195.78.116/22 |
| **Tailscale-Name** | openclaw-node2.taild25fea.ts.net |
| **Tailscale IP** | 100.109.255.27/32 |
| **WireGuard IP** | 10.10.0.2/32 |
| **PublicKey** | LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0= |
| **Gateway** | 10.10.0.1 |
| **Status** | ✅ Aktiv |

## OpenClaw - Pairing-Informationen

| Attribut | Wert |
|----------|------|
| **Node ID** | `ba35628cb796cf3e2fdb61df722593be7251a4c66008e99cc62cf24cdba2be72` |
| **Display Name** | openclaw-node2 |
| **Platform** | linux |
| **Client** | node-host/node |
| **Version** | 2026.4.5 |
| **Status** | ✅ paired · connected |
| **Verbunden seit** | ~6h |
| **Paired am** | 2026-04-06 |

### Aktuelle Capabilities
| Capability | Status | Verfügbare Commands |
|------------|--------|---------------------|
| `browser` | ✅ | `browser.proxy` |
| `system` | ✅ | `system.run`, `system.run.prepare`, `system.which` |

### PATH Environment
```
/usr/bin:/bin:/root/.local/bin:/root/.npm-global/bin:/root/bin:/root/.volta/bin:/root/.asdf/shims:/root/.bun/bin:/root/.nvm/current/bin:/root/.fnm/current/bin:/root/.local/share/pnpm:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin
```

## Erweiterbare Capabilities

| Capability | Beschreibung | Voraussetzungen |
|------------|--------------|-----------------|
| `compute` | CPU-intensive Tasks | node labels |
| `storage` | Datei-Speicherung/-Sync | volume mounts |
| `docker` | Container-Management | docker/podman install |
| `download` | Torrent/HTTP-Downloader | tools install |
| `build` | Compile/Build Tasks | build tools |
| `ai` | ML/Inference | GPU (nicht vorhanden) |
| `relay` | Proxy/Tunnel | - |

## Vergleich: Node 2 vs Node 3 Capabilities

| Capability | Node 2 | Node 3 |
|------------|--------|--------|
| `browser` | ✅ | ✅ |
| `system` | ✅ | ✅ |
| `docker` | ❓ unbekannt | ❓ unbekannt |
| `storage` | 160GB frei | 2GB frei (kritisch) |
| `compute` | ✅ geeignet | ⚠️ limitiert |

## Services
| Service | Port | Status |
|---------|------|--------|
| OpenClaw Node | (via WireGuard) | ✅ |
| WireGuard | 51820 | ✅ |
| SSH | 22 | ✅ |

## Status
| Komponente | Status |
|------------|--------|
| WireGuard | ✅ OK |
| OpenClaw Node | ✅ paired · connected |
| Tunnel zu Gateway | ✅ SSH Port 18789 |
| GitHub CLI | ✅ v2.90.0 (installiert 2026-04-18) |
| SSH-Zugriff | ✅ Aktiviert (Port 22, Password+Key Auth) |
| Tailscale | ✅ Systemweiter Dienst; direkter Peer zum Gateway |
| Tailscale SSH | ⚠️ Nicht für Administration verwendet; Zugriff erfolgt per Root-Key über das Tailscale-Netz |
| Tailscale IP | 100.109.255.27 |

## Zugriffs- und Diensttrennung (Stand 2026-07-12)

- Tailscale läuft systemweit und stellt nur die private Netzwerkverbindung bereit.
- Das OpenClaw-Pairing nutzt diese Verbindung unabhängig von administrativem SSH.
- Gateway- und Node-Dienste laufen jeweils unter `openclaw`.
- Updates und Dienstneustarts erfolgen per klassischem SSH als `root` mit dem
  dedizierten Gateway-Key `id_ed25519_openclaw_admin`.
