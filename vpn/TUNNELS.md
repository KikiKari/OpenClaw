# TUNNELS.md - SSH Tunnel Konfiguration

## Architektur

```
Node 2 (159.195.78.116) ──Reverse──→ Node 1 (152.53.145.65)
  Port 15000 (Legacy TikTok API (nicht vom aktuellen Dispatcher genutzt): localhost:5000)
  Port 18790 (OpenClaw Gateway: localhost:18789)

Node 3 (185.162.248.90) ──Reverse──→ Node 1 (152.53.145.65)
  Port 18792 (OpenClaw Gateway: localhost:18790)

Node 1 ──Local Forward──→ Node 2
  Port 5002 (Direct API: localhost:5000)

Node 1 ──Local Forward──→ Node 3
  Port 18793 (Direct SSH/Gateway: localhost:18789)
```

## Port-Mapping Übersicht

| Richtung | Port auf Node 1 | Quelle | Ziel | Service | Status |
|----------|-----------------|--------|------|---------|--------|
| Node2 → Node1 | 15000 | Node2:5000 | Node1 | tunnel-15000 (autossh) | ✅ enabled |
| Node2 → Node1 | 18790 | Node2:18789 | Node1 | tunnel-18790 (autossh) | ✅ enabled |
| Node3 → Node1 | 18792 | Node3:18790 | Node1 | sshd (reverse) | ⚠️ manuell |
| Node1 → Node2 | 5002 | Node1 | Node2:5000 | tunnel-to-node2 | ✅ enabled |
| Node1 → Node3 | 18793 | Node1 | Node3:18789 | tunnel-to-node3 (sshpass) | ✅ enabled |

## Systemd-Services

### Node 1 (Hetzner - 152.53.145.65, User: openclaw)

| Service | Typ | Befehl | Status |
|---------|-----|--------|--------|
| tunnel-to-node2 | Local Forward | ssh -i /root/.ssh/node2_tunnel -N -L 5002:localhost:5000 root@159.195.78.116 | ✅ enabled |
| tunnel-to-node3 | Local Forward | sshpass -e ssh -N -L 18793:localhost:18789 root@185.162.248.90 | ✅ enabled |

### Node 2 (Netcup - 159.195.78.116, User: openclaw)

| Service | Typ | Befehl | Status |
|---------|-----|--------|--------|
| tunnel-15000 | Reverse (autossh) | autossh -M 0 -N -R 15000:localhost:5000 -i /root/.ssh/node1_tunnel root@152.53.145.65 | ✅ enabled |
| tunnel-18790 | Reverse (autossh) | autossh -M 0 -N -R 18790:localhost:18789 -i /root/.ssh/node1_tunnel root@152.53.145.65 | ✅ enabled |
| openclaw-tunnel | Reverse (ssh) | ssh -N -R 18790:localhost:18789 -i /root/.ssh/node1_tunnel root@152.53.145.65 | ✅ enabled (Backup) |

### Node 3 (xNetX - 185.162.248.90, User: root)

| Service | Typ | Status |
|---------|-----|--------|
| Reverse Tunnel | sshd-initiated | ⚠️ Manuell/unklar |

## SSH Keys

| Key | Pfad | Zweck |
|-----|------|-------|
| node2_tunnel | /root/.ssh/node2_tunnel | Node 1 → Node 2 |
| node1_tunnel | /root/.ssh/node1_tunnel | Node 2 → Node 1 (Reverse) |
| node3_tunnel | /root/.ssh/node3_tunnel | Node 1 → Node 3 (nicht aktiv) |
| .node2_root | /home/openclaw/.ssh/.node2_root | Passwort für Node 3 |

## Restart-Anweisungen

### Node 1 - Tunnel-Services neustarten
```bash
# Einzeln
sudo systemctl restart tunnel-to-node2
sudo systemctl restart tunnel-to-node3

# Status prüfen
sudo systemctl is-active tunnel-to-node2 tunnel-to-node3
ss -tlnp | grep -E '5002|18793'
```

### Node 2 - Reverse-Tunnels neustarten
```bash
# Von Node 1 aus (Remote-Befehl)
sudo ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 "systemctl restart tunnel-15000 tunnel-18790"

# Status prüfen
sudo ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 "systemctl is-active tunnel-15000 tunnel-18790"
```

### Node 3 - fail2ban & iptables
```bash
# Über Webpanel/KVM-Konsole auf Node 3:
fail2ban-client set sshd unbanip 152.53.145.65

# iptables Regeln löschen
iptables -F f2b-pam-generic
iptables -F f2b-pass2allow-ftp

# Whitelist permanent hinzufügen:
# In /etc/fail2ban/jail.local: ignoreip = 152.53.145.65
```

### Alle Tunnel-Ports prüfen (von Node 1)
```bash
ss -tlnp | grep -E '15000|18790|18792|18793|5002'
```

### OpenClaw Node Mode Status
```bash
# Gateway (Node 1)
openclaw nodes status
openclaw gateway status

# Node 2 (via SSH)
ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 "openclaw node status"

# Node 3 (via Proxy)
ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 "sshpass -p '1363Getin#' ssh root@185.162.248.90 'openclaw node status'"
```

### Vollständiger Health-Check
```bash
echo "=== PORTS ==="
ss -tlnp | grep -E '15000|18790|18792|18793|5002|51820'
echo "=== WIREGUARD ==="
sudo wg show | grep -E "peer|endpoint|transfer"
echo "=== OPENCLAW NODES ==="
openclaw nodes status
echo "=== SERVICES NODE 1 ==="
sudo systemctl is-active tunnel-to-node2 tunnel-to-node3
echo "=== SERVICES NODE 2 (remote) ==="
sudo ssh -i /root/.ssh/node2_tunnel root@159.195.78.116 "systemctl is-active tunnel-15000 tunnel-18790 openclaw-tunnel openclaw-node" 2>/dev/null || echo "Node 2 nicht erreichbar"
echo "=== NGINX ==="
curl -s -o /dev/null -w "%{http_code}" localhost:16000/health
```

## Neustart-Sicherheit

- **Node 1:** ✅ tunnel-to-node2 und tunnel-to-node3 als Systemd-Services enabled
- **Node 2:** ✅ tunnel-15000, tunnel-18790, openclaw-tunnel als Systemd-Services enabled
- **Node 3:** ⚠️ Reverse-Tunnel nicht als Service bestätigt. Muss geprüft werden wenn Node 3 Zugang möglich

## Tailscale DNS Konfiguration (Cluster-weit)

**Problem:** Tailscale überschreibt `/etc/resolv.conf` mit `100.100.100.100`, blockiert externe DNS-Auflösung für yum/apt.

**Lösung:** `accept-dns=false` auf allen Nodes (Stand: 2026-04-10):

```bash
# Node 1 (Gateway)
sudo tailscale up --accept-dns=false --accept-routes --hostname=openclaw-node1

# Node 2 (Netcup)
tailscale up --accept-dns=false --accept-routes --hostname=openclaw-node2

# Node 3 (xNetX)
tailscale up --accept-dns=false --accept-routes --hostname=openclaw-node3
```

**Verifikation:**
```bash
tailscale status | grep "failed to fetch.*DNS"  # Sollte erscheinen = DNS nicht verwaltet
```

**Status:**
| Node | accept-dns | DNS-Verwaltung |
|------|------------|----------------|
| Node 1 | false ✅ | System-DNS (127.0.0.53) |
| Node 2 | false ✅ | System-DNS |
| Node 3 | false ✅ | 8.8.8.8 / 1.1.1.1 |

---

## Bekannte Probleme (Stand: 2026-04-10)
- ✅ Node 3 fail2ban blockt Node 1 IP - Regeln gelöscht, Whitelist hinzugefügt
- ✅ Node 3 hat SSH-Zugang via Proxy durch Node 2
- ✅ OpenClaw Node Mode auf allen Nodes aktiv
- ✅ Tailscale DNS deaktiviert (accept-dns=false) - Externe DNS funktioniert
- ⚠️ Node 3 WireGuard wartet auf Kernel-Support (CentOS Stream 8)
