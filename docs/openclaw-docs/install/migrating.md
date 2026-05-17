# OpenClaw Migration Guide

Quelle: https://docs.openclaw.ai/install/migrating
Gescrapt: 2026-04-21

## Was wird migriert
- Config: openclaw.json
- Auth: auth-profiles.json (API Keys + OAuth), credentials/
- Sessions: Conversation History + Agent State
- Channel State: WhatsApp Login, Telegram Session etc.
- Workspace: MEMORY.md, USER.md, Skills, Prompts

## Schritte
```bash
# 1. Alt: Gateway stoppen + Backup
openclaw gateway stop
cd ~
tar -czf openclaw-state.tgz .openclaw

# 2. Neu: OpenClaw installieren
curl -fsSL https://openclaw.ai/install.sh | bash

# 3. Archiv übertragen + entpacken
scp openclaw-state.tgz user@newhost:~
cd ~
tar -xzf openclaw-state.tgz

# 4. Doctor + Verify
openclaw doctor
openclaw gateway restart
openclaw status
```

## Checkliste
- [ ] openclaw status zeigt Gateway running
- [ ] Channels verbunden (kein Re-Pairing)
- [ ] Dashboard zeigt Sessions
- [ ] Workspace-Dateien vorhanden

## Wichtig
- Immer GESAMTES ~/.openclaw migrieren, nicht nur openclaw.json
- Berechtigungen prüfen (chown)
- Backups verschlüsselt speichern
