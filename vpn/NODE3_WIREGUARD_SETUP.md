# Node 3 WireGuard Setup (Pending - Kernel Modul Problem)

## Status
Node 3 (CentOS Stream 8) hat keinen WireGuard Kernel-Support verfügbar:
- Kernel module `wireguard` nicht in 4.18.0-301.1.el8.x86_64
- `wireguard-dkms` nicht in Repositories
- `wireguard-go` kann nicht gebaut werden (nicht genug Disk Space für golang)
- Alternative: Nutze bestehende SSH-Tunnel für Node 3

## Vorbereitete Konfiguration

### Node 3 Keys
- PrivateKey: `QN0IpCUdp1nT7f+w07mFC9IxASJ1xjZ5gpZpx+ilaXo=`
- PublicKey: `Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA=`

### Node 3 WireGuard Config (/etc/wireguard/wg0.conf)
```ini
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

### Setup Commands (auszuführen auf Node 3)
```bash
# Create WireGuard directory
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Create config
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.10.0.3/24
PrivateKey = QN0IpCUdp1nT7f+w07mFC9IxASJ1xjZ5gpZpx+ilaXo=
ListenPort = 51820

[Peer]
PublicKey = Tkqb+IHDsyHTBw/nKWQ91WFRF9/51XrLZe1FjC+zqzk=
AllowedIPs = 10.10.0.0/24
Endpoint = 152.53.145.65:51820
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/wg0.conf

# Check if WireGuard is installed
rpm -qa | grep wireguard || yum install -y wireguard-tools

# Start WireGuard
wg-quick up wg0

# Enable on boot
systemctl enable wg-quick@wg0

# Setup Firewall (CentOS/RHEL with firewalld)
firewall-cmd --permanent --add-port=51820/udp
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.10.0.0/24" accept'
firewall-cmd --reload

# OR with iptables (if no firewalld)
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -s 10.10.0.0/24 -j ACCEPT
```

## Gateway Config Status
Gateway hat Node 3 Peer bereits eingetragen:
```
peer: Wvjr1b5Df3wjzl5XR156gtlD7N5y6/68Qc7sMo+wIBA=
  allowed ips: 10.10.0.3/32
```

## Post-Setup Verification
```bash
# On Gateway
ping 10.10.0.3
wg show

# On Node 3
ping 10.10.0.1
wg show
```
