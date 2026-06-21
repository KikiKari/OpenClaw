---
name: tiktok-live-mon
description: Classify a TikTok account as accessible LIVE, restricted LIVE, or offline and resolve an allowed TikTok CDN FLV URL through Playwright with bounded streamlink and yt-dlp fallbacks. Use for robust one-shot checks; not for recording or notifications.
---

# TikTok LIVE Enhanced Monitor

Use this skill for direct-page classification and resilient URL extraction.
It does not record streams and does not send notifications.

## Preferred usage

Run the shared dispatcher:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url @example_creator
```

Use the scripts directly only for method-level diagnosis:

```bash
node "$HOME/.openclaw/workspace/skills/tiktok-live-mon/scripts/tiktok-check-profile.js" example_creator
node "$HOME/.openclaw/workspace/skills/tiktok-live-mon/scripts/tiktok-get-stream.js" example_creator
```

## Classification

- `live`: the requested account's LIVE page produced an allowed HTTPS TikTok
  CDN `.flv` response with HTTP `2xx`;
- `restricted`: the requested account is LIVE but the anonymous page is gated
  by login, sensitive-content, age, or equivalent account-specific text;
- `offline`: no account-specific LIVE evidence or exact ended/offline evidence;
- `dependency_missing` or `technical_error`: the result is not a valid
  offline classification;
- `overloaded`: browser startup was skipped.

An unrelated sidebar `LIVE` label is ignored. Exact selectors for
`/@example_creator/live` and the direct account LIVE page are required.

## URL contract

The enhanced extractor tries Playwright, `streamlink`, then `yt-dlp`. It
normalizes every fallback result before use.

- success: naked URL on stdout, exit `0`;
- offline/restricted/no URL: empty stdout, exit `1`;
- dependency/technical failure: empty stdout, exit `2`;
- overload: empty stdout, exit `75`.

Fallback processes have fixed executable/argument lists, bounded output,
timeouts, process-group cleanup, and strict URL/schema validation.

## Gateway/node execution

The gateway can always run the dispatcher locally. A calling OpenClaw agent
may execute the same portable command on a connected paired node with
`exec host=node`. The node runs with `--execution local` and returns structured
stdout, stderr, and an exit code. No direct SSH or direct
`openclaw nodes invoke ... system.run` is used.

Each node needs the skill, Playwright/Chromium, and optional CLI fallbacks at
the same `$HOME/.openclaw/workspace/...` paths. Missing prerequisites,
overload, timeout, and invoke failure trigger gateway fallback unless disabled.

## Load limit

The 1-minute load divided by CPU count must not exceed `1.5` by default.
Override with `TIKTOK_MAX_LOAD_PER_CPU`. Overload exits `75` before Playwright
starts.

## Handling URLs

Only observed, allowed HTTPS TikTok CDN `.flv` URLs are accepted. Signed URLs
are temporary and revocable: resolve immediately before VLC/MPV playback and
never publish a working signed URL in documentation or logs.

## Requirements

- Node.js
- Playwright and Chromium
- Python 3 for the dispatcher
- optional `streamlink` and `yt-dlp`
- outbound HTTPS access
