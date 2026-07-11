---
name: tiktok-live-mon
description: Run a TikTok one-shot request by default or explicitly manage a parameterized long-running monitor.
command-dispatch: tool
command-tool: tiktok_live_mon_direct
---

# TikTok LIVE monitor contract

A bare `/tiktok_live_mon @handle` is a one-shot request. Follow the complete
one-shot contract from `tiktok-live` and invoke exactly:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

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
