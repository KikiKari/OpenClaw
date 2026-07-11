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

After the final result, call no additional extraction tool. User output is:

```text
@<handle> is currently <STATUS> on TikTok.
VLC/MPV: <URL or not available>
Method: <actual dispatcher method>
```

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

Identity and pointer writes are atomic. Identity retention is 90 days from the
last successful observation; cleanup is passive during a later successful
upsert. Stream URL retention remains three days.

See `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, and `docs/DAEMON.md`.
