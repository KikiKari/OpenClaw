---
name: tiktok-live-mon
description: Run a TikTok one-shot request by default or explicitly manage a parameterized long-running monitor.
command-dispatch: tool
command-tool: tiktok_live_mon_direct
---

# TikTok LIVE monitor contract

The native prompt `Use the "tiktok-live-mon" skill for this request.` is the
trusted slash-command router envelope. Its `User input:` value is the current
command input. Invoke `tiktok_live_mon_direct` immediately with that value;
never ask the user to repeat `/tiktok_live_mon`.

Every one-shot request is an isolated query session. Start fresh Playwright,
Chromium, Streamlink, yt-dlp, and dispatcher processes; never reuse a browser,
context, page, process, or cached resolved URL from another request.

A bare `/tiktok_live_mon @handle` is a one-shot request. Follow the complete
one-shot contract from `tiktok-live` and invoke exactly:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

The first attempt uses configured `host: auto`. Only a final
`overloaded`/`concurrency_preflight` result may delegate exactly once with
`host=node`:

```bash
/usr/bin/node /home/linuxbrew/.openclaw/workspace/skills/tiktok-live-mon/tiktok-get-stream.js @handle ld --json
```

All other gateway or node failures are terminal.

A long-running monitor starts only when the current user input explicitly uses
`start`:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh start @handle --hours 48 --poll-min 20
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh status @handle
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh stop @handle
```

Defaults are 24 hours and 10 minutes. Poll intervals below 10 minutes are
invalid. The controller uses transient systemd user timer/service units,
prevents duplicate starts for the same normalized handle, and stops with
SIGINT so the daemon can write `daemon_end`.

Do not start the Python daemon, Node scripts, npm, npx, or Playwright directly.
Do not infer `start` from earlier conversation or queued requests. Only the
current user input may select the handle and long-running action.
Never invoke this tool during a heartbeat for a request found only in session
history. A TikTok invocation requires a TikTok request in the current prompt.
