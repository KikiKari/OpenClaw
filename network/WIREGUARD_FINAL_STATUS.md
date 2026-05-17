# ✅ WireGuard VPN Setup - FINAler STATUS

## Zusammenfassung

| Node | Hostname | Externe IP | WireGuard IP | Status | OS | Firewall |
|------|----------|------------|--------------|--------|-----|----------|
| **Gateway** | v2202604104722446711 | 152.53.145.65 | 10.10.0.1/24 | ✅ **AKTIV** | Ubuntu 22.04 | UFW aktiviert |
| **Node 2** | v2202603104722445775 | 159.195.78.116 | 10.10.0.2/32 | ✅ **VERBUNDEN** | Ubuntu 24.04 | UFW aktiviert |
| **Node 3** | xnetx | 185.162.248.90 | 10.10.0.3/32 | ⚠️ **Kernel-Fehler** | CentOS Stream 8 | firewalld aktiviert |

---

## ✅ Gateway (Node 1) - Vollständig Eingerichtet

```bash
# Interface Status
$ sudo wg show
interface: wg0
  public key: Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
  listening port: 51820
  
peer: LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0=
  endpoint: 159.195.78.116:51820
  allowed ips: 10.10.0.2/32
  latest handshake: Aktiv
  transfer: 1.87 KiB received, 552 B sent

peer: Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA=
  allowed ips: 10.10.0.3/32
```

**Firewall (UFW):**
```
Status: active
51820/udp                  ALLOW       Anywhere                   # WireGuard VPN
```

**Config:** `/etc/wireguard/wg0.conf`

---

## ✅ Node 2 (Netcup) - Vollständig Eingerichtet

```bash
# Interface Status
$ wg show
interface: wg0
  public key: LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0=
  listening port: 51820

peer: Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
  endpoint: 152.53.145.65:51820
  allowed ips: 10.10.0.0/24
  latest handshake: Aktiv
  persistent keepalive: every 25 seconds
```

**Firewall (UFW):**
```
Status: active
[ 1] 51820/udp                  ALLOW IN    Anywhere                   # WireGuard VPN
[ 2] Anywhere                   ALLOW IN    10.10.0.0/24               # WireGuard Network
[ 4] 18789                      ALLOW IN    10.10.0.0/24               # OpenClaw Gateway via VPN
```

**Config:** `/etc/wireguard/wg0.conf`

**Ping Test:**
```
$ ping 10.10.0.1
--- 10.10.0.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
rtt avg 1.535 ms
```

---

## ⚠️ Node 3 (xNetX) - Kernel Modul Fehler

**Problem:** CentOS Stream 8 (Kernel 4.18.0-301.1.el8.x86_64) hat keinen WireGuard Support

```
modprobe: FATAL: Module wireguard not found
```

**Versuchte Lösungen:**
- ❌ `wireguard-dkms` - Nicht in Repositories verfügbar
- ❌ `wireguard-go` bauen - Nicht genug Speicher (134MB erforderlich)

**Alternative Lösung:** SSH-Tunnel (bereits eingerichtet und aktiv)

**Firewall (firewalld):**
```
public (active)
  ports: ... 51820/udp
  rich rules: 
    rule family="ipv4" source address="10.10.0.0/24" accept
```

**Falls Kernel-Update verfügbar wird:**
```bash
# Config vorbereitet in /etc/wireguard/wg0.conf
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

---

## Netzwerk-Topologie

```
                    ┌──────────────────────────────────┐
                    │         GATEWAY (Node 1)         │
                    │      152.53.145.65 (public)      │
                    │        10.10.0.1 (wg)            │
                    │         Port 51820/udp           │
                    └──────────────┬───────────────────┘
                                   │
           ┌───────────────────────┴───────────────────────┐
           │                       │                       │
           │ WireGuard             │ WireGuard             │ SSH Tunnel
           ▼                       ▼                       ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│   Node 2 (Netcup)   │   │   Node 3 (xNetX)    │   │   Node 3 (xNetX)    │
│ 159.195.78.116:51820│   │ 185.162.248.90:51820│   │ 185.162.248.90:22   │
│    10.10.0.2/32     │   │    10.10.0.3/32     │   │   (via SSH-Proxy)   │
│      ✅ AKTIV       │   │   ⚠️ Kernel-Fehler  │   │      ✅ AKTIV       │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
```

---

## Persistenz

Alle Dienste sind als Systemd-Services konfiguriert:

```bash
# Gateway & Node 2
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Status prüfen
systemctl status wg-quick@wg0
wg show
```

**Autostart bei Boot:** ✅ Aktiviert auf Gateway und Node 2

---

## Ergebnis

- ✅ **Gateway:** WireGuard Gateway + Firewall (UFW) - AKTIV
- ✅ **Node 2:** WireGuard Client + Firewall (UFW) - VERBUNDEN
- ⚠️ **Node 3:** Firewall (firewalld) konfiguriert, WireGuard wartet auf Kernel-Support
- ✅ **Alle Nodes:** SSH-Tunnel als Fallback aktiv

**WireGuard VPN ist einsatzbereit für Node 1 und Node 2!**
