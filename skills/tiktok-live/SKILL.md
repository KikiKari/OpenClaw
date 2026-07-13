---
name: tiktok-live
description: MANDATORY for /tiktok_live, TikTok LIVE status, or playback URL requests. Read this SKILL.md first and run its canonical dispatcher; never refuse or execute the skill name as a shell command.
command-dispatch: tool
command-tool: tiktok_live_direct
---

# TikTok LIVE one-shot contract

The native prompt `Use the "tiktok-live" skill for this request.` is the
trusted slash-command router envelope. Its `User input:` value is the current
command input. Invoke `tiktok_live_direct` immediately with that value; never
ask the user to repeat `/tiktok_live`.

For `/tiktok_live @handle`, handle-only requests, and VLC/MPV requests, invoke
exactly this command once, using the handle from the current user input:

```bash
/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

- `tiktok-live` is a skill name, not a shell executable. Never run
  `tiktok-live`, `tiktok_live`, or a similarly named command directly.
- The dispatcher is invoked by its executable absolute path. Do not prefix it
  with `python3` or another general interpreter.

- Do not invoke Node, npm, npx, Playwright, `which`, `dir_list`, a sandbox
  diagnostic, or any old TikTok script before a dispatcher error.
- Do not derive or replace the handle from queued messages, reasoning, memory,
  or session history.
- Never invoke this tool during a heartbeat for a request found only in session
  history. A TikTok invocation requires a TikTok request in the current prompt.
- Keep the first `exec` call on the configured host; do not override `host`.
- If and only if that dispatcher returns `status: overloaded`, exit code `75`,
  and `method: concurrency_preflight`, run exactly once with `host=node`:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

  Let OpenClaw process routing select the connected node; do not run node
  diagnostics or retry another node.
- Gateway failures, node failures, denials, and approval errors are terminal.
  Never create a fallback or approval loop.
- Start at most one dispatcher process per host for a request. If it runs in the
  background, poll its textual session name, never its PID. Never rerun the
  dispatcher on that host during that request.
- A running poll is not a result. Continue polling the same textual session
  until it reaches a terminal state and emits final JSON. Do not end the turn,
  do not ask the user to wait, and do not write progress prose such as “still
  running” between Exec and Process calls; the Activity cards already expose
  that progress.
- After final dispatcher JSON, do not run further Node or extraction attempts.
- Never expose raw JSON, tool logs, fallback attempts, or reasoning.

Reply with exactly these three populated lines:

```text
@<handle> is currently <STATUS> on TikTok.
VLC/MPV: <URL or not available>
Method: <dispatcher method>
```

`Method` must come from the dispatcher result and must not be generalized to
`playwright`. The dispatcher internally owns Python-first resolution, bounded
Node/Playwright fallbacks, timeouts, and process cleanup.

The dispatcher probes cached and freshly resolved media URLs before returning
them. A cached URL that answers with HTTP 403 or does not contain valid HLS
content is discarded and resolved again. Never describe such a failure as a
VLC, expiry, or regional problem without an actual probe result.

If the user reports that VLC cannot open the immediately preceding URL, rerun
this same direct command for the same handle. Do not introduce any handle that
was not present in the user's request or the direct command result.

Decision contract: Python live plus URL is final. Python offline is only
provisional and must be confirmed by Enhanced Node/Playwright. Python live
without URL and Python technical/dependency failures require Node fallback.
An unambiguous Enhanced Node live/offline/restricted result is final; only an
Enhanced Node technical failure or missing required URL advances to the next
Node fallback.
