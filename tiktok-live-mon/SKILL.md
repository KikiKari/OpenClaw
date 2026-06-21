# Legacy TikTok LIVE Monitor Location

Stand: 2026-06-21.

This directory contains retained background references. It is not the active
skill installation.

Use:

```text
$HOME/.openclaw/workspace/skills/tiktok-live-mon/
```

Canonical commands:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url example_creator
```

The active implementation uses exact account selectors, distinguishes
accessible LIVE from restricted LIVE, accepts only validated HTTPS TikTok CDN
FLV results, returns overload as exit `75`, and can be run locally or by an
OpenClaw agent on a paired node through `exec host=node`.

Do not copy scripts, dependencies, SSH examples, or signed URLs from this
legacy directory into production.
