# OpenClaw auf Linux VPS

Quelle: https://docs.openclaw.ai/vps
Gescrapt: 2026-04-21

## Provider-Übersicht
Railway, Northflank, DigitalOcean, Oracle Cloud (Free ARM), Fly.io, Hetzner, Hostinger, GCP, Azure, exe.dev, Raspberry Pi, AWS

## Startup Tuning (kleine VMs / ARM)
```bash
# Node Compile Cache
export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
mkdir -p /var/tmp/openclaw-compile-cache
export OPENCLAW_NO_RESPAWN=1
```

## systemd Tuning
```bash
systemctl --user edit openclaw-gateway.service
```
```ini
[Service]
Environment=OPENCLAW_NO_RESPAWN=1
Environment=NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
Restart=always
RestartSec=2
TimeoutStartSec=90
```

## Sicherheit
- Gateway auf Loopback halten → SSH-Tunnel oder Tailscale
- gateway.auth.token oder password setzen
- Dedicated VPS + Accounts für shared agents
