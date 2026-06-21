---
name: tiktok-live
description: Check a TikTok account's current LIVE status and resolve a playable stream URL with Playwright. Use for one-shot live/offline/restricted checks and VLC/MPV-compatible URL extraction. Do not use for recorded videos, account analytics, recording, or notifications.
---

# TikTok LIVE

Use the portable installation under:

```text
$HOME/.openclaw/workspace/skills/tiktok-live/
```

Do not use the stale path `$HOME/.openclaw/skills/tiktok-live/`.

## Canonical entry point

Use the dispatcher unless a single extractor must be diagnosed:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url @example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url example_creator --json
```

Whitespace and one leading `@` are removed. Valid TikTok handles contain only
letters, digits, `.`, and `_`, with a maximum length of 24 characters.

Without `--json`, a successful `url` command writes only the naked URL to
stdout. Diagnostics and routing information go to stderr.

## Result contract

| Status | Meaning | Exit |
|---|---|---:|
| `live` | Account-specific LIVE confirmed; URL may be present | 0 |
| `offline` | No account-specific LIVE evidence or URL | 1 |
| `restricted` | LIVE exists but requires login or is otherwise gated | 1 |
| `dependency_missing` | Required runtime or executable unavailable | 2 |
| `technical_error` | Navigation, parsing, timeout, or execution failure | 2 |
| `overloaded` | Load threshold exceeded before Playwright starts | 75 |

The standalone URL extractors follow the same stdout rule:

- success: one naked URL, exit `0`
- offline/restricted/no URL: empty stdout, exit `1`
- dependency or technical failure: empty stdout, exit `2`
- overload: empty stdout, exit `75`

## Gateway and paired nodes

The dispatcher is always executable locally on the gateway. Its execution
modes are:

```text
--execution auto|local|node
--node <id|name>
--no-local-fallback
```

`auto` selects a connected, paired, suitable node when the calling OpenClaw
agent can issue `exec host=node`; otherwise it runs on the gateway. A remote
node runs the same dispatcher with `--execution local` and returns stdout,
stderr, and the exit code. Missing dependencies, overload, invoke failure, and
timeout fall back to the gateway unless `--no-local-fallback` is set.

Remote execution is agent-managed. Do not use SSH or
`openclaw nodes invoke ... system.run`; OpenClaw reserves `system.run` for the
`exec` tool.

Each executing node needs the synchronized workspace, Node.js, Playwright, and
Chromium under the same portable paths.

## Load protection

Before browser startup, each extractor compares the 1-minute load average with
the CPU count:

```text
load_per_cpu = load_1m / cpu_count
```

The default limit is `1.5`; override it with
`TIKTOK_MAX_LOAD_PER_CPU`. Overload produces exit `75` without starting
Playwright.

## Detection rules

Only account-specific evidence counts:

- the profile header/avatar for the requested account;
- an exact link to `/@example_creator/live`;
- a successful HTTP `2xx` response for an allowed TikTok CDN HTTPS `.flv`
  URL on that account's LIVE page.

An isolated `LIVE` label in TikTok's sidebar or recommendations is ignored.
The enhanced checker opens `/@example_creator/live` to distinguish accessible
LIVE, restricted LIVE, and offline states.

## Standalone diagnostics

```bash
node "$HOME/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-check-profile.js" example_creator
node "$HOME/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-get-stream.js" example_creator
```

The basic checker is intentionally profile-only. Use the enhanced skill or the
dispatcher when `restricted` must be distinguished from `offline`.

## Playback

Resolve a fresh URL immediately before playback:

```bash
url="$(python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url example_creator)"
vlc "$url"
```

Stream URLs are signed and revocable. Do not document or log live signed URLs;
use placeholders. Re-resolve after expiration, HTTP rejection, or a new LIVE
session. Do not modify observed URLs to guess another quality.

## Security and cleanup

- Never interpolate handles into shell commands.
- Start fallbacks with fixed executables and argument arrays.
- Accept only normalized extractor output and allowed HTTPS TikTok CDN URLs.
- Bound child-process output and execution time.
- Terminate the complete fallback process group on timeout.
- Close browser, context, page, and temporary files on every path.
- Do not persist signed stream URLs outside the existing state/history
  mechanisms.

## Requirements

- Python 3
- Node.js
- Playwright with Chromium in both skill directories
- Optional `streamlink` and `yt-dlp` fallbacks for the enhanced extractor
- Outbound HTTPS access to TikTok and TikTok CDN hosts

## References

- Runtime details: `references/TIKTOK.md`
- Enhanced extractor: `$HOME/.openclaw/workspace/skills/tiktok-live-mon/SKILL.md`
- Dispatcher/stateful monitor:
  `$HOME/.openclaw/workspace/tiktok-monitor/SKILL.md`
