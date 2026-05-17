# WireGuard VPN Setup - Zusammenfassung

## Übersicht

| Node | Hostname | IP | WireGuard IP | Status | OS |
|------|----------|-----|--------------|--------|-----|
| **Gateway** | v2202604104722446711 | 152.53.145.65 | 10.10.0.1/24 | ✅ Gateway / Hub | Ubuntu 22.04 |
| **Node 2** | v2202603104722445775 | 159.195.78.116 | 10.10.0.2/32 | ✅ Verbunden | Ubuntu 24.04 |
| **Node 3** | xnetx | 185.162.248.90 | 10.10.0.3/32 | ⚠️ Kernel-Problem | CentOS Stream 8 |

## Konfiguration

### Gateway (Node 1) - 152.53.145.65
**Interface:** `10.10.0.1/24`
**PublicKey:** `Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=`

```bash
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.1/24
PrivateKey = yMEOy95a7UiuqDi951H/3sZYNkXflB6du5lT84EcTFI=
ListenPort = 51820

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Node 2 (Netcup)
[Peer]
PublicKey = LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0=
AllowedIPs = 10.10.0.2/32

# Node 3 (xNetX) - Wartet auf Kernel Support
[Peer]
PublicKey = Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA=
AllowedIPs = 10.10.0.3/32
```

**Firewall (UFW):**
```bash
ufw allow 51820/udp comment 'WireGuard VPN'
```

---

### Node 2 (Netcup) - 159.195.78.116
**Interface:** `10.10.0.2/24`
**PublicKey:** `LD8yJw5Inkvz19B+KW1jUGdhGn0izPUp+q5kMyvDwU0=`

```bash
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.2/24
PrivateKey = iBU0tDKT5xqxfsHV2Lo2a1+PZ1cx+mxNINyU4n/hN3c=
ListenPort = 51820

[Peer]
PublicKey = Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
AllowedIPs = 10.10.0.0/24
Endpoint = 152.53.145.65:51820
PersistentKeepalive = 25
```

**Firewall (UFW):**
```bash
ufw allow 51820/udp comment 'WireGuard VPN'
ufw allow from 10.10.0.0/24 comment 'WireGuard Network'
ufw allow 22/tcp comment 'SSH'
ufw allow from 10.10.0.0/24 to any port 18789 comment 'OpenClaw Gateway via VPN'
ufw enable
```

**Status:** ✅ Handshake erfolgreich, Ping funktioniert

---

### Node 3 (xNetX) - 185.162.248.90
**Problem:** Kein Kernel-Support für WireGuard
- Kernel: `4.18.0-301.1.el8.x86_64`
- WireGuard kernel module nicht verfügbar
- DKMS nicht in Repositories
- `wireguard-go` kann nicht kompiliert werden (zu wenig Speicher)

**Alternative Lösung:** SSH-Tunnel (bereits eingerichtet und funktionsfähig)

---

## Netzwerk-Tests

### Von Gateway zu Node 2
```
ping 10.10.0.2
64 bytes from 10.10.0.2: icmp_seq=1 ttl=64 time=0.760 ms
```

### Von Node 2 zu Gateway
```
ping 10.10.0.1
64 bytes from 10.10.0.1: icmp_seq=1 ttl=64 time=0.822 ms
```

---

## Firewall-Status

### Gateway (UFW)
- Status: ✅ aktiv
- Port 51820/udp: ✅ erlaubt (WireGuard)
- Port 18789/tcp: ✅ erlaubt (OpenClaw Gateway)
- Port 22/tcp: ✅ erlaubt (SSH)

### Node 2 (UFW)
- Status: ✅ aktiv
- Port 51820/udp: ✅ erlaubt (WireGuard)
- 10.10.0.0/24: ✅ erlaubt (WireGuard Network)
- Port 18789/tcp: ✅ erlaubt vom VPN
- Port 22/tcp: ✅ erlaubt (SSH)

### Node 3 (iptables/firewalld)
- Alternative: SSH-Tunnel

---

## Persistenz

Alle WireGuard-Konfigurationen sind als Systemd-Services eingerichtet:
```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

Dienste starten automatisch beim Boot.
