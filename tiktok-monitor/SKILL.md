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
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

Use the exec tool directly with the absolute dispatcher command before
discussing permissions. In OpenClaw Control, set `elevated: true` and omit the
`host` and `node` fields so `tools.exec.host: auto` selects the normal local
execution path.
The dispatcher is already covered by a gateway allowlist entry with a strict
argument rule. Call exec immediately; do not ask for approval, wait for
approval, or return an `/approve ...` command as chat text. Only report an
approval error if the exec tool itself returns one.
For handle-only slash-command requests and VLC-link requests, run
`url ... --json` and answer with live/offline/restricted status plus the
resolved URL or a compact failure reason.
Use `check ... --json` only for diagnostics when no playback URL is needed.
Start exactly one dispatcher exec per request. Do not start a named
long-running process manually. If exec yields `Command still running (session
NAME, pid PID)`, do not rerun exec: poll the existing process using the textual
`NAME` as `sessionId`, never the numeric PID. Continue polling that same name
until completion. The dispatcher owns browser startup, fallback timeouts,
process cleanup, and final JSON output.
Do not translate the dispatcher path to `/workspace/...` in OpenClaw Control.
Use the documented `/home/openclaw/.openclaw/workspace/...` path and never
substitute `~`, `$HOME`, or `/workspace` in OpenClaw Control. Keep
`tools.exec.host: auto`; do not force the first invocation to gateway or node.
If the local result is `technical_error`, `dependency_missing`, or
`overloaded`, or has no valid final JSON, the caller may retry exactly once on
the least-loaded connected paired node using explicit per-call `host=node`,
`--execution local`, and the node execution-context environment. OpenClaw
2026.6.11 allows that per-call node request from the global `auto` default.
Never change the global host for routing and never retry a failed node run.
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

One agent request starts exactly one dispatcher process. Inside that process,
Python/Webcast/API runs first because it is cheaper, but Python `offline` is
tentative and must be confirmed by the fixed Node/Playwright fallback.
Node/Playwright also runs after Python dependency/technical failure, for
restriction checks, or when LIVE was detected without a playback URL. An
authoritative Node result or valid Python URL is final; no later method runs.
Every child command uses bounded timeout and process-group cleanup.

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

The gateway is always a valid local executor. In node mode, the calling
OpenClaw agent uses `exec host=node` to run the exact same direct-Shebang
dispatcher command on a connected paired node. Node execution is not SSH and
not direct CLI `system.run`. OpenClaw 2026.6.11 rejects an `auto` to `node`
per-call override while the agent sandbox is active, before Node allowlist
evaluation. Do not bypass that runtime policy by changing the global host.

The load threshold is the 1-minute load divided by CPU count. Its default is
`1.5`; set `TIKTOK_MAX_LOAD_PER_CPU` to override it.
Each executor also accepts one active dispatcher by default. A concurrent
additional request exits `75` with method `concurrency_preflight`, allowing
the caller to send it to another node immediately instead of waiting for the
1-minute load average. Set `TIKTOK_MAX_CONCURRENT` to tune per-host capacity.

## Stateful Python component

Use the wrapper for identity/state persistence or daemon monitoring:

```bash
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" check example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" url example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" daemon example_creator --hours 24 --poll-min 10
```

The Python component uses `secUid` as the stable primary key and stores
handle pointers/history in `tiktok-names`. It is a data provider and does not
send notifications.

### Component scope

- `check`: Webcast/profile status and identity update; when live, the JSON
  additionally carries best-effort `room` metadata (title, viewers, likes,
  start/duration, owner nickname/followers, hashtag) and a `qualities` map
  with every available HLS/FLV URL (see docs/SCHEMA.md §6.1);
- `url`: cached/direct API playback URL resolution through the dispatcher;
  with `--json` it emits one compact JSON line including `room`/`qualities`;
- `daemon`: transition polling and append-only events;
- `get_room_id.py`: standalone profile/room probe;
- `check_alive.py`: standalone room liveness probe.

Dispatcher `live` payloads pass `room` and `qualities` through top-level keys;
when only Playwright fallback data exists, a qualities map is synthesized from
the captured URLs. Identity records additionally keep a capped
`nickname_history` alongside `rename_history`.

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

Identity records are upserted by stable `secUid`; handle pointers are upserted
by normalized `uniqueId`. Repeated checks update the existing files rather
than creating duplicates. Both `tiktok-live` and `tiktok-live-mon` use this
shared store through the dispatcher. Identity and pointer records not observed
for 90 days are removed during a later successful identity update. Stream URL
history remains governed separately by the three-day URL retention.

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
- ten-minute minimum daemon poll interval;
- Python resolver targets a bounded 360p HLS format;
- no recording and no outbound notification integration;
- validated handles only; `secUid` remains the durable identity key;
- use the dispatcher for node routing and public-access classification.

See `docs/README.md`, `docs/ARCHITECTURE.md`, `docs/SCHEMA.md`, and
`docs/DAEMON.md` for component-level details.
