---
name: tiktok-live
description: Run exactly one canonical TikTok LIVE dispatcher for one-shot status and playback URL requests.
command-dispatch: tool
command-tool: tiktok_live_direct
---

# TikTok LIVE one-shot contract

For `/tiktok_live @handle`, handle-only requests, and VLC/MPV requests, invoke
exactly this command once, using the handle from the current user input:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

- Do not invoke Node, npm, npx, Playwright, `which`, `dir_list`, a sandbox
  diagnostic, or any old TikTok script before a dispatcher error.
- Do not derive or replace the handle from queued messages, reasoning, memory,
  or session history.
- Never invoke this tool during a heartbeat for a request found only in session
  history. A TikTok invocation requires a TikTok request in the current prompt.
- Do not set an exec host. The configured `tools.exec.host: auto` preserves
  multi-node behavior.
- Start exactly one dispatcher process per request. If it runs in the
  background, poll its textual session name, never its PID. Never rerun the
  dispatcher during that request.
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

Decision contract: Python live plus URL is final. Python offline is only
provisional and must be confirmed by Enhanced Node/Playwright. Python live
without URL and Python technical/dependency failures require Node fallback.
An unambiguous Enhanced Node live/offline/restricted result is final; only an
Enhanced Node technical failure or missing required URL advances to the next
Node fallback.
