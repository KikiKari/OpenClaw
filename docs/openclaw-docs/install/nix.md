# OpenClaw Nix Installation

Quelle: https://docs.openclaw.ai/install/nix
Gescrapt: 2026-04-21

## Repo: https://github.com/openclaw/nix-openclaw

## Was man bekommt
- Gateway + macOS App + Tools — alles gepinnt
- Launchd Service (überlebt Reboots)
- Plugin System mit deklarativer Config
- Instant Rollback: `home-manager switch --rollback`

## Quick Start
```bash
# 1. Determinate Nix installieren
# 2. Lokales Flake erstellen (templates/agent-first/)
# 3. Secrets konfigurieren (~/.secrets/)
# 4. home-manager switch
```

## Nix Mode
```bash
export OPENCLAW_NIX_MODE=1
# macOS GUI:
defaults write ai.openclaw.mac openclaw.nixMode -bool true
```

## Umgebungsvariablen
| Variable | Default |
|----------|---------|
| OPENCLAW_HOME | HOME |
| OPENCLAW_STATE_DIR | ~/.openclaw |
| OPENCLAW_CONFIG_PATH | $STATE_DIR/openclaw.json |
