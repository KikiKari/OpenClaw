# OpenClaw Docker Installation

Quelle: https://docs.openclaw.ai/install/docker
Gescrapt: 2026-04-21

## Voraussetzungen
- Docker Desktop/Engine + Docker Compose v2
- Min. 2 GB RAM
- Genug Disk für Images + Logs

## Setup Script
```bash
./scripts/docker/setup.sh

# Mit Pre-Built Image
export OPENCLAW_IMAGE="ghcr.io/openclaw/openclaw:latest"
./scripts/docker/setup.sh
```

## Manueller Flow
```bash
docker build -t openclaw:local -f Dockerfile .
docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js onboard --mode local --no-install-daemon
docker compose up -d openclaw-gateway
```

## Umgebungsvariablen
| Variable | Zweck |
|----------|-------|
| OPENCLAW_IMAGE | Remote Image statt lokal bauen |
| OPENCLAW_DOCKER_APT_PACKAGES | Extra apt packages (space-separated) |
| OPENCLAW_EXTRA_MOUNTS | Extra Host Bind Mounts |
| OPENCLAW_HOME_VOLUME | /home/node in Docker Volume persistieren |
| OPENCLAW_SANDBOX | Sandbox Bootstrap aktivieren |

## Health Checks
```bash
curl -fsS http://127.0.0.1:18789/healthz   # liveness
curl -fsS http://127.0.0.1:18789/readyz     # readiness
```

## Sandbox aktivieren
```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main", // off | non-main | all
        scope: "agent",   // session | agent | shared
      },
    },
  },
}
```
```bash
scripts/sandbox-setup.sh
```

## Persistenz
- Config: OPENCLAW_CONFIG_DIR → /home/node/.openclaw
- Workspace: OPENCLAW_WORKSPACE_DIR → /home/node/.openclaw/workspace
- Container UID: 1000 (node user)
