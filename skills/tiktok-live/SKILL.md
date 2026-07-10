---
name: tiktok-live
description: Check a TikTok account's current LIVE status and resolve a playable stream URL with Playwright. Use for one-shot live/offline/restricted checks and VLC/MPV-compatible URL extraction. Do not use for recorded videos, account analytics, recording, or notifications.
---

# TikTok LIVE

## Mandatory slash-command behavior

For `/tiktok_live @name` and any handle-only request, the first normal action
is exactly this dispatcher exec with the exec tool parameter `elevated: true`:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --json
```

Do not read, inspect, copy, install, or execute files under `scripts/`. Do not
debug Playwright/Chromium before the dispatcher has failed. Standalone scripts
are diagnostics only after the dispatcher returns `dependency_missing` or
`technical_error`.
If the user says a previous URL failed, re-run this same dispatcher command
once for a fresh signed URL. Do not run dependency probes such as
`which streamlink`, `which yt-dlp`, `command -v`, `dir_list`, `read`, `sed`,
`rg`, `node`, `npm`, or `npx` during normal slash-command handling.
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

Use the portable installation under:

```text
$HOME/.openclaw/workspace/skills/tiktok-live/
```

Do not use the stale path `$HOME/.openclaw/skills/tiktok-live/`.

## Canonical entry point

Use the dispatcher. For normal slash-command requests with only a handle, run
`url ... --json` directly so the reply can include the VLC/MPV URL when the
account is live:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

Use `check ... --json` only for diagnostics when no playback URL is needed.

For `/tiktok_live @name`, the complete normal operation is this single exec
tool call:

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

Execution context rules:

- In OpenClaw Control, use the documented
  `/home/openclaw/.openclaw/workspace/...` command exactly as shown, set
  `elevated: true`, and omit any exec host override.
- Outside OpenClaw Control only: if the workspace is mounted at `/workspace`
  in a sandbox, make one exec call
  with command
  `python3 /workspace/tiktok-monitor/tiktok_dispatch.py url @name --json`
  and the exec tool environment
  `{"OPENCLAW_WORKSPACE":"/workspace"}`.
- Outside OpenClaw Control only: if the
  `/home/openclaw/.openclaw/workspace/...` command fails with `can't open file`
  or `No such file or directory`, treat that as an execution path mismatch,
  not as a TikTok result. Retry once with the `/workspace/...` command and
  `OPENCLAW_WORKSPACE=/workspace`, then answer from that result. In OpenClaw
  Control, do not retry with `/workspace`.
- Do not mix a `/workspace/...` command with an unset or host-style workspace
  root. Never construct `/workspace/.openclaw/workspace/...`.
- Do not probe the variable with `env | grep OPENCLAW_WORKSPACE`; an unset
  variable produces exit 1 and is displayed as a tool error.

Do not translate the dispatcher path to `/workspace/...` in OpenClaw Control.
Use the documented `/home/openclaw/.openclaw/workspace/...` path and leave
host selection to OpenClaw's configured `auto` mode. If elevated exec is not
available or is denied, report `technical_error: elevated host exec required
for TikTok dispatcher` instead of retrying with `/workspace`, Node scripts, or
sandbox probes.

Do not answer a handle-only `/tiktok_live` request from `check` output alone.
If the account is `live`, resolve a VLC/MPV URL before replying. Reply
concisely: status plus VLC/MPV URL, or LIVE plus compact failure reason.
When the dispatcher JSON contains `status: "live"` and `url`, that URL is the
resolved VLC/MPV URL for the response. Do not perform any additional
extraction or diagnostics.

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

`auto` remains multi-node capable. It selects a connected, paired, suitable
node when the calling OpenClaw agent can issue `exec host=node`; otherwise it
runs on the gateway. A remote node runs the same dispatcher with
`--execution local` and returns stdout, stderr, and the exit code. Missing
dependencies, overload, invoke failure, and timeout fall back to the gateway
unless `--no-local-fallback` is set.

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

The basic checker is intentionally profile-only. Use the dispatcher for normal
command responses. Run these standalone scripts only for manual method-level
diagnosis after the dispatcher path failed.

## Playback

Resolve a fresh URL immediately before playback:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url example_creator
```

Do not replace the absolute path with `~/.openclaw/...`.

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
- Outbound HTTPS access to TikTok and TikTok CDN hosts

## References

- Runtime details: `references/TIKTOK.md`
- Enhanced extractor: `$HOME/.openclaw/workspace/skills/tiktok-live-mon/SKILL.md`
- Dispatcher/stateful monitor:
  `$HOME/.openclaw/workspace/tiktok-monitor/SKILL.md`
