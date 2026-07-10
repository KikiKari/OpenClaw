---
name: tiktok-live-mon
description: Classify a TikTok account as accessible LIVE, restricted LIVE, or offline and resolve an allowed TikTok CDN playback URL through the shared dispatcher. Use for robust one-shot checks; not for recording or notifications.
---

# TikTok LIVE Enhanced Monitor

## Mandatory slash-command behavior

For `/tiktok_live_mon @name` and any handle-only request, the first normal
action is exactly this dispatcher exec with the exec tool parameter
`elevated: true`:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --json
```

If the dispatcher returns `status: "live"` with a `url`, reply with that URL
immediately. Do not require `.flv`; TikTok may return a VLC/MPV-playable
`.m3u8` HLS URL. Do not search dispatcher or script files for `.flv`.
If the user says a previous URL failed, re-run this same dispatcher command
once for a fresh signed URL.
Do not use `~/.openclaw/...` in exec commands.
In OpenClaw Control, never run this dispatcher as a plain sandbox exec. Set the
exec tool field `elevated` to `true`; do not set the `host` field. This keeps
`tools.exec.host: auto` and multi-node routing intact while letting the
dispatcher run in the gateway environment where Playwright/Chromium and TikTok
network access work.
Terminal rule: if any dispatcher run returns JSON with `status: "live"` and
a non-empty `url`, the next action must be the final user reply containing
that URL. Do not call any other tool after that result. Do not search for a
better format, inspect scripts, read files, run Node, or verify fallbacks.

Do not read, inspect, copy, install, or execute files under `scripts/`. Do not
debug Playwright/Chromium before the dispatcher has failed. Standalone scripts
are diagnostics only after the dispatcher returns `dependency_missing` or
`technical_error`.
Do not run dependency probes during slash-command handling. In particular, do
not run `which streamlink`, `which yt-dlp`, `command -v`, `dir_list`, `read`,
`sed`, `rg`, `node`, `npm`, or `npx` to investigate TikTok playback. Optional
fallback tools are the dispatcher's internal concern; their absence must not
be surfaced as a tool error for a handle-only request.

Use this skill for direct-page classification and resilient URL extraction.
It does not record streams and does not send notifications.

## Preferred usage

Run the shared dispatcher. For normal slash-command requests with only a
handle, run `url ... --json` directly so the reply can include the VLC/MPV URL
when the account is live:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

Use `check ... --json` only for diagnostics when no playback URL is needed.

For `/tiktok_live_mon @name`, the complete normal operation is this single
exec tool call:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --json
```

Exec tool parameters:

```json
{"elevated": true}
```

Do not use Process/session tools for one-shot TikTok checks. Do not start a
named long-running process. The dispatcher owns browser startup, fallback
timeouts, process cleanup, and final JSON output.

Use the exec tool directly with the exact absolute dispatcher path above. Do
not render dispatcher commands as chat text. Do not use `$HOME`, shell
substitutions, `~`, or shell assignments.
Set `elevated: true` in the exec tool call. Do not set `host` to `gateway`.
Leave the exec host unset so OpenClaw uses the configured `tools.exec.host:
auto` behavior. This preserves multi-node behavior: do not force gateway and
do not force a specific node for a handle-only request; let OpenClaw and the
dispatcher keep their automatic gateway/node routing.
Do not translate the dispatcher path to `/workspace/...` in OpenClaw Control.
Use the documented `/home/openclaw/.openclaw/workspace/...` path and leave
host selection to OpenClaw's configured `auto` mode. If elevated exec is not
available or is denied, report `technical_error: elevated host exec required
for TikTok dispatcher` instead of retrying with sandbox probes.
If that absolute command fails with `can't open file` or
`No such file or directory` outside OpenClaw Control, treat it as an execution
path mismatch, not as a TikTok result. Retry once with
`python3 /workspace/tiktok-monitor/tiktok_dispatch.py url @name --json` and
the exec tool environment `{"OPENCLAW_WORKSPACE":"/workspace"}`, then answer
from that result.
In OpenClaw Control, do not retry with `/workspace`; if elevated exec is not
available or is denied, report `technical_error: elevated host exec required
for TikTok dispatcher`.

For command responses, always send a concise user-facing reply. If an account
is `live`, resolve a VLC/MPV URL before replying. A dispatcher-returned TikTok
CDN `.m3u8` or `.flv` URL satisfies this requirement. Do not stop at live
status alone. If URL extraction fails after all methods, say explicitly that
the account is LIVE but no VLC URL could be resolved, and include only the
compact failure reason. Do not paste full tool logs or repeated attempt
output.
When the dispatcher JSON contains `status: "live"` and `url`, that URL is the
resolved VLC/MPV URL for the response. Do not perform any additional
extraction or diagnostics.

Treat files under `skills/tiktok-live-mon/scripts/` as private implementation
details during normal slash-command handling. Do not read, inspect, or execute
those scripts unless the user explicitly asks for extractor debugging.

## Classification

- `live`: the requested account's LIVE page produced an allowed HTTPS TikTok
  CDN playback URL such as `.m3u8` or `.flv`;
- `restricted`: the requested account is LIVE but the anonymous page is gated
  by login, sensitive-content, age, or equivalent account-specific text;
- `offline`: no account-specific LIVE evidence or exact ended/offline evidence;
- `dependency_missing` or `technical_error`: the result is not a valid
  offline classification;
- `overloaded`: browser startup was skipped.

An unrelated sidebar `LIVE` label is ignored. Exact selectors for
`/@example_creator/live` and the direct account LIVE page are required.

## URL contract

The dispatcher owns extractor and fallback selection. The caller must not
probe or invoke extractor dependencies directly during normal command
handling.

- success: naked URL on stdout, exit `0`;
- offline/restricted/no URL: empty stdout, exit `1`;
- dependency/technical failure: empty stdout, exit `2`;
- overload: empty stdout, exit `75`.

Fallback processes have fixed executable/argument lists, bounded output,
timeouts, process-group cleanup, and strict URL/schema validation.

## Gateway/node execution

The gateway can always run the dispatcher locally, and `auto` remains
multi-node capable. A calling OpenClaw agent may execute the same portable
command on a connected paired node with `exec host=node`. The node runs with
`--execution local` and returns structured stdout, stderr, and an exit code.
No direct SSH or direct
`openclaw nodes invoke ... system.run` is used.

Each node needs the synchronized workspace at the same
`$HOME/.openclaw/workspace/...` paths. Missing prerequisites, overload,
timeout, and invoke failure trigger gateway fallback unless disabled.

## Load limit

The 1-minute load divided by CPU count must not exceed `1.5` by default.
Override with `TIKTOK_MAX_LOAD_PER_CPU`. Overload exits `75` before Playwright
starts.

## Handling URLs

Only observed, allowed HTTPS TikTok CDN playback URLs are accepted. Signed
URLs are temporary and revocable: resolve immediately before VLC/MPV playback
and never publish a working signed URL in documentation or logs.

## Requirements

- Node.js
- Playwright and Chromium
- Python 3 for the dispatcher
- outbound HTTPS access
