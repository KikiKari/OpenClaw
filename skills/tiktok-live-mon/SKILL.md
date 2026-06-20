---
name: tiktok-live-mon
description: TikTok Live stream monitoring and recording automation. Uses Playwright for visual detection and network traffic monitoring to capture FLV stream URLs. Supports automatic live status checks, stream recording to disk, and notification integration.
---

# TikTok Live Monitor

Automated TikTok Live stream monitoring with Playwright-based visual detection.

## Features

- **Visual Detection:** Uses Chromium/Playwright to detect live status (red border around profile)
- **Stream URL Extraction:** Captures FLV stream URLs from network traffic
- **Automatic Recording:** Saves streams to disk when live
- **Notifications:** Alerts when stream goes live/offline

## Usage

```bash
# Check if user is live
node "$HOME/.openclaw/workspace/skills/tiktok-live-mon/tiktok-check-profile.js" @username

# Get stream URL
node "$HOME/.openclaw/workspace/skills/tiktok-live-mon/tiktok-get-stream.js" @username
```

Both commands accept usernames with or without a leading `@`.

## Execution Routing

1. Run the command on the Gateway by default.
2. For load balancing, inspect paired and connected nodes and only select nodes
   that advertise `system.run`.
3. Run the same command through the OpenClaw `exec` tool with:
   - `host: "node"`
   - `node: "<selected-node>"`
   - `env: { "TIKTOK_MAX_LOAD_PER_CPU": "1.0" }`
4. Retry another eligible node or the Gateway if execution returns exit code 75
   (`NODE_BUSY`), the script or Playwright is missing, the command times out, the
   node disconnects, or execution is denied.
5. The skill must be synchronized to the same
   `$HOME/.openclaw/workspace/skills/tiktok-live-mon/` path on every worker node.

The skill may be presented to the agent from a generated
`/workspace/.openclaw/sandbox-skills/...` path. That path is only a sandbox skill
copy and must not be used for Gateway or node execution. Do not use
`nodes invoke` or the removed legacy `nodes run` command for shell execution;
remote shell commands must use the OpenClaw `exec` tool with `host=node`.

## Requirements

- Node.js 16+
- Playwright with Chromium
