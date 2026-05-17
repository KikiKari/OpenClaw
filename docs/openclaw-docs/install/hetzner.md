# OpenClaw auf Hetzner VPS

Quelle: https://docs.openclaw.ai/install/hetzner
Gescrapt: 2026-04-21

## Quick Path
1. Hetzner VPS provisionieren (Ubuntu/Debian)
2. Docker installieren
3. OpenClaw Repo klonen
4. Persistente Host-Verzeichnisse erstellen
5. .env + docker-compose.yml konfigurieren
6. Binaries in Image backen
7. docker compose up -d
8. SSH-Tunnel für Zugriff

## Setup
```bash
ssh root@YOUR_VPS_IP
apt-get update && apt-get install -y git curl ca-certificates
curl -fsSL https://get.docker.com | sh
git clone https://github.com/openclaw/openclaw.git && cd openclaw
mkdir -p /root/.openclaw/workspace
chown -R 1000:1000 /root/.openclaw
```

## .env
```bash
OPENCLAW_IMAGE=openclaw:latest
OPENCLAW_GATEWAY_TOKEN=
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_CONFIG_DIR=/root/.openclaw
OPENCLAW_WORKSPACE_DIR=/root/.openclaw/workspace
GOG_KEYRING_PASSWORD=   # openssl rand -hex 32
```

## Zugriff via SSH-Tunnel
```bash
ssh -N -L 18789:127.0.0.1:18789 root@YOUR_VPS_IP
# Dann: http://127.0.0.1:18789/
```

## Terraform (Community)
- https://github.com/andreesg/openclaw-terraform-hetzner
- https://github.com/andreesg/openclaw-docker-config
