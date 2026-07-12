---
name: tiktok-live
description: Check a TikTok account's current LIVE status and return a validated three-line TikTok LIVE response with an optional VLC/MPV URL. Use for one-shot /tiktok_live live, offline, restricted, overloaded, or technical-error checks; not for monitoring, recording, notifications, analytics, or recorded videos.
---

# TikTok LIVE

## Normal one-shot flow

For a normal `/tiktok_live @handle` request, take the handle from the current `User input:`, remove whitespace and one leading `@`, and validate it against `^[A-Za-z0-9._]{1,24}$`.

Make the existing dispatcher the first action:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

Use an elevated exec call and omit the host field so the existing gateway allowlist and routing remain effective. If exec returns a running session, poll that same session until completion. If the user reports an expired URL, run the same dispatcher command again for a fresh URL.

The dispatcher retains its complete internal method and fallback sequence. Node, browser, file, directory, configuration, dependency, and diagnostic tools remain available with their existing behavior; this normal-flow preference does not remove, block, or redefine any capability. Use additional diagnostics when the user explicitly requests diagnosis or when handling a separate diagnostic task.

## Public response

Read the dispatcher JSON and produce exactly these three public text lines:

```text
@<handle> is currently <LIVE|OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.
VLC/MPV: <validated URL or not available>
Method: <validated method>
```

- Map `live`, `offline`, `restricted`, and `overloaded` to their uppercase labels; map `dependency_missing` and `technical_error` to `TECHNICAL_ERROR`.
- Use the top-level `method`; if absent, use the decisive or successful `attempts[]` method, otherwise `unknown`.
- Print the returned URL only for `live`; otherwise print `not available`.
- Keep internal reasoning and tool diagnostics in their dedicated channels. Do not copy them into the public three-line text.
- If the dispatcher cannot run or its JSON is invalid, use `TECHNICAL_ERROR`, `not available`, and `dispatcher_error` in the same three-line format.

## Existing capabilities

The skill's scripts and runtime details remain available for explicitly requested troubleshooting and other existing supported workflows:

- Runtime reference: `references/TIKTOK.md`
- Basic profile and stream scripts: `scripts/tiktok-check-profile.js` and `scripts/tiktok-get-stream.js`
- Enhanced extractor: `$HOME/.openclaw/workspace/skills/tiktok-live-mon/SKILL.md`
- Dispatcher and monitor reference: `$HOME/.openclaw/workspace/tiktok-monitor/SKILL.md`
