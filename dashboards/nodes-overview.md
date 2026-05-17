# Nodes Overview (Network Status)

| Node | Name          | OS           | IP             | Mode       | Primär WG IP       | Sekundär/SSH Tunnel | StatusVPN | StatusSSH | SSH Key (Deployed) | Letzter Check       |
|------|---------------|--------------|----------------|------------|--------------------|---------------------|-----------|-----------|---------------------|---------------------|
| 1    | Gateway | Ubuntu 22.04 | 152.53.145.65 | Gateway       | 10.10.0.1             | – | ⚠️ | ❌ | Local (id_ed25519) | – |
| 2    | Netcup Server | Ubuntu 22.04 | 78.46.123.10 | Node       | 10.10.0.2             | – | ⚠️ | ❌ | ❌ (Pending) | – |
| 3    | xNetX VPS | Debian 11 | 5.45.105.20 | Node       | –             | Port 18794 | ⚠️ | ✅ | ❌ (Pending) | – |
| 4    | Webhosting | Shared Linux | – | –       | –             | – | ⚠️ | ❌ | ❌ | – |
| 5    | Redmi Note 11 | Android | – | Node       | 10.10.0.5             | – | ⚠️ | ❌ | ❌ | – |
| 6    | Lenovo (Win) | Windows 11 | – | Node       | –             | – | ⚠️ | ❌ | ❌ | – |

> 💡 **Legende:** 
> - **Primär WG IP**: Die WireGuard-VPN-IP des Nodes
> - **Sekundär/SSH Tunnel**: Fallback-Mechanismus (z. B. Reverse-Tunnel)
> - **StatusVPN**: Verbunden über OpenClaw/WireGuard
> - **StatusSSH**: SSH-Zugriff via Reverse-Tunnel aktiv
> - **SSH Key (Deployed)**: Zeigt an, ob der Gateway-Schlüssel (`id_ed25519`) auf dem Ziel bereitgestellt ist
> - Letzter Stand: **18.4.2026, 18:00:01 CET**

*Größe: ~1.8 KB | Automatisch aktualisiert via `update-nodes-report.js`*