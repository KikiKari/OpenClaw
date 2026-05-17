# OpenClaw Update Guide

Quelle: https://docs.openclaw.ai/install/updating
Gescrapt: 2026-04-21

## Empfohlen: openclaw update
```bash
openclaw update
openclaw update --channel beta
openclaw update --tag main
openclaw update --dry-run   # Vorschau ohne Anwendung
```

## Alternative: Installer erneut ausführen
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
# Mit --no-onboard um Onboarding zu überspringen
```

## Manuell (npm/pnpm/bun)
```bash
npm i -g openclaw@latest
pnpm add -g openclaw@latest
bun add -g openclaw@latest
```

## Auto-Updater Config
```json5
{
  update: {
    channel: "stable",    // stable | beta | dev
    auto: {
      enabled: true,
      stableDelayHours: 6,
      stableJitterHours: 12,
      betaCheckIntervalHours: 1,
    },
  },
}
```

## Nach dem Update
```bash
openclaw doctor
openclaw gateway restart
openclaw health
```

## Rollback
```bash
# Pin auf Version
npm i -g openclaw@<version>
openclaw doctor
openclaw gateway restart

# Pin auf Commit (Source)
git checkout "$(git rev-list -n 1 --before=\"2026-01-01\" origin/main)"
pnpm install && pnpm build
openclaw gateway restart
```
