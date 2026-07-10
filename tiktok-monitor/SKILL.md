---
name: tt-live
description: Dispatch one-shot TikTok LIVE checks and URL extraction, or run the stateful Python monitor/daemon. Use for live/offline/restricted classification, playable URL resolution, identity history, and timed transition monitoring.
---

# tt-live — Dispatcher and Stateful Monitor

The canonical one-shot entry is `tiktok_dispatch.py`. The lower-level
`tt-live.sh`/`tt_live.py` component maintains identity, state, cache, and daemon
events.

## One-shot dispatcher

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

Use the exec tool directly with the absolute dispatcher command before
discussing permissions. In OpenClaw Control, set the exec tool parameter
`elevated: true` for this dispatcher call and do not set the `host` field.
For handle-only slash-command requests and VLC-link requests, run
`url ... --json` and answer with live/offline/restricted status plus the
resolved URL or a compact failure reason.
Use `check ... --json` only for diagnostics when no playback URL is needed.
Do not use Process/session tools for one-shot TikTok checks. Do not start a
named long-running process. The dispatcher owns browser startup, fallback
timeouts, process cleanup, and final JSON output.
Do not translate the dispatcher path to `/workspace/...` in OpenClaw Control.
Use the documented `/home/openclaw/.openclaw/workspace/...` path and do not
set `host` to `gateway`; set `elevated: true` and leave exec host unset so
OpenClaw uses the configured `tools.exec.host: auto` behavior.
This preserves multi-node behavior: do not force gateway and do not force a
specific node for a handle-only request; let OpenClaw and the dispatcher keep
their automatic gateway/node routing.
If the user says a previous URL failed, re-run the same dispatcher command
once for a fresh signed URL. Do not run dependency probes such as
`which streamlink`, `which yt-dlp`, `command -v`, `dir_list`, `read`, `sed`,
`rg`, `node`, `npm`, or `npx` during normal slash-command handling. Optional
fallback tools are internal to the dispatcher and must not appear as visible
tool errors for handle-only requests.
Do not use `~/.openclaw/...` in exec commands.
Terminal rule: if any dispatcher run returns JSON with `status: "live"` and
a non-empty `url`, the next action must be the final user reply containing
that URL. Do not call any other tool after that result. Do not search for a
better format, inspect scripts, read files, run Node, or verify fallbacks.

Outside OpenClaw Control only: for a sandbox that mounts this workspace at
`/workspace`, issue one exec call using
`/workspace/tiktok-monitor/tiktok_dispatch.py` and set the exec tool's
`OPENCLAW_WORKSPACE` environment field to `/workspace`. Do not use a shell
assignment, do not derive the path from `$HOME`, and do not combine the sandbox
command path with `~/.openclaw/workspace`.
Do not use this sandbox fallback in OpenClaw Control when elevated exec is
available; the TikTok dispatcher needs gateway Playwright/Chromium and network
access. If elevated exec is unavailable or denied, report
`technical_error: elevated host exec required for TikTok dispatcher`.
If the absolute `/home/openclaw/.openclaw/workspace/...` command fails with
`can't open file` or `No such file or directory` outside OpenClaw Control,
treat that as an execution path mismatch, not as a TikTok result. Retry once
with the `/workspace/...` command and `OPENCLAW_WORKSPACE=/workspace`, then
answer from that result. In OpenClaw Control, do not retry with `/workspace`;
the corrected path is elevated gateway exec with the absolute
`/home/openclaw/.openclaw/workspace/...` command.

The dispatcher normalizes the handle, runs bounded Python and Playwright
methods, distinguishes restricted LIVE from offline, validates extractor
output, and reports the method that established the result.

### Exit/status contract

| Status | Exit |
|---|---:|
| `live` | 0 |
| `offline` | 1 |
| `restricted` | 1 |
| `dependency_missing` | 2 |
| `technical_error` | 2 |
| `overloaded` | 75 |

For non-JSON URL extraction, stdout contains only the naked URL on success and
is empty otherwise.

### Execution modes

```text
--execution auto|local|node
--node <id|name>
--no-local-fallback
```

The gateway is always a valid local executor, and `auto` remains multi-node
capable. In node mode, the calling OpenClaw agent uses `exec host=node` to run
the same dispatcher with `--execution local` on a connected paired node. Node
execution is not SSH and not direct CLI `system.run`. Missing dependencies,
overload, timeout, or invoke failure fall back to the gateway unless disabled.

The load threshold is the 1-minute load divided by CPU count. Its default is
`1.5`; set `TIKTOK_MAX_LOAD_PER_CPU` to override it.

## Stateful Python component

Use the wrapper for identity/state persistence or daemon monitoring:

```bash
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" check example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" url example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" daemon example_creator --hours 12 --poll-min 5
```

The Python component uses `secUid` as the stable primary key and stores
handle pointers/history in `tiktok-names`. It is a data provider and does not
send notifications.

### Component scope

- `check`: Webcast/profile status and identity update;
- `url`: cached/direct API playback URL resolution through the dispatcher;
- `daemon`: transition polling and append-only events;
- `get_room_id.py`: standalone profile/room probe;
- `check_alive.py`: standalone room liveness probe.

A Python `live=true` result is tentative for public accessibility. Use the
dispatcher or enhanced Playwright checker to identify `restricted`.

## Workspace

```text
$HOME/.openclaw/workspace/
├── tiktok-names/
│   ├── identities/<sec_uid>.json
│   └── pointers/<unique_id>.json
└── tiktok-monitor/
    ├── state/tt-live/<sec_uid>.state.json
    ├── state/tt-live/<sec_uid>.events
    └── logs/daemon-<user>-<UTC-ts>.log
```

`TT_LIVE_WORKSPACE` and `TT_LIVE_IDENTITY_DIR` override these defaults.
Identity/address-book/history data is preserved independently of active
runtime examples.

## Daemon event contract

Events are appended one per line:

```text
ts=<iso> evt=<type> sec_uid=<...> unique_id=<...> [k=v ...] [stream_url=...]
```

`stream_url` is last because its signed query contains `&` and `=`. Event
types are `daemon_start`, `daemon_end`, `poll_ok`, `poll_err`, `go_live`,
`go_offline`, and `rename_detected`.

The caller owns announcements. The daemon emits data only.

## Cache and signed URLs

The state store may retain a URL for three days as history/cache metadata.
Retention does not guarantee playability. A URL can expire, be revoked, or
become invalid when a LIVE session ends. Resolve a fresh URL for playback and
do not place working signed URLs in documentation.

## Constraints

- one handle per daemon;
- five-minute minimum daemon poll interval;
- Python resolver targets a bounded 360p HLS format;
- no recording and no outbound notification integration;
- validated handles only; `secUid` remains the durable identity key;
- use the dispatcher for node routing and public-access classification.

See `docs/README.md`, `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, and
`docs/DAEMON.md` for component-level details.
