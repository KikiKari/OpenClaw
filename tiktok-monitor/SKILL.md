---
name: tt-live
description: Canonical TikTok one-shot dispatcher and stateful long-running monitor.
---

# tt-live

## One-shot requests

Run exactly one public command per current user request:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

The dispatcher validates the current handle, tries the stateful Python/API
resolver first, and owns all bounded Node/Playwright fallbacks. Callers must
not directly invoke Node scripts or run dependency diagnostics. If exec returns
a background session, poll its textual session name and never rerun it.

The mandatory decision sequence is:

- Python live with a valid URL: final.
- Python offline: provisional; Enhanced Node/Playwright must confirm it.
- Python live without a URL: Node/Playwright resolves the URL.
- Python technical/dependency failure: Node/Playwright fallback.
- An unambiguous Enhanced Node live/offline/restricted result: final.
- Enhanced Node technical failure or live without the required URL: run the
  next Node fallback.

After the final result, call no additional extraction tool. The live user
output (rendered by the tiktok-live-dispatch plugin; lines without data are
omitted, every stream URL sits alone in its own fenced code block, one block
per quality and container, HLS before FLV, ordered Original → 360p) is:

```text
@<handle> is currently LIVE on TikTok.
Titel: <title>
Zuschauer: <viewers> aktuell · <total_viewers> gesamt
Likes: <likes>
Follower: <followers> · Gefolgt: <following>
Live seit: <HH:MM> UTC (<Xh Ym>)

Stream-URLs:

<Label> (HLS):
<fenced code block containing only the URL>
<Label> (FLV):
<fenced code block containing only the URL>

Method: <actual dispatcher method>
```

Without a resolvable quality list a single `Stream:` block carries the primary
URL. Offline/restricted output stays
`@<handle> is not currently live on TikTok.`

## Long-running monitor

Long-running behavior requires an explicit `start`:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh start @handle --hours 48 --poll-min 20
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh status @handle
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh stop @handle
```

Defaults are 24 hours and 10 minutes. Values below 10 minutes are rejected.
The controller creates transient systemd user timer/service units, rejects a
duplicate handle, and uses SIGINT on stop so `daemon_end` is emitted.

A bare `/tiktok_live_mon @handle` is a one-shot dispatcher request, not a
monitor start.

## Stateful data

- Shared identities: `../tiktok-names/identities/<sec_uid>.json`
- Normalized pointers: `../tiktok-names/pointers/<handle>.json`
- State/events: `state/tt-live/<sec_uid>.*`
- Logs: `logs/`

Identity and pointer writes are atomic. Identity retention defaults to 90 days
from the last successful observation and can be overridden via
`TT_LIVE_IDENTITY_RETENTION_DAYS` (0 = never delete); cleanup is passive during
a later successful upsert and every deletion is logged to
`../tiktok-names/cleanup.log`. Stream URL retention remains three days.
Identities are also recorded from Playwright fallback results (embedded
`identity`) and from webcast room-info `owner` data, not only from SIGI
scrapes.

See `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, and `docs/DAEMON.md`.
