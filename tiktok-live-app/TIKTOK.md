# Legacy TikTok LIVE App

Stand: 2026-06-21.

The former Port-5001/Flask TikTok app is retired. This directory is retained
for historical context only and is not an active service, API, monitor, or
source of playable URLs.

Use the current dispatcher:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url @example_creator
```

Current implementation:

- uses portable `$HOME/.openclaw/workspace/...` paths;
- normalizes handles with or without `@`;
- returns `live`, `offline`, `restricted`, `dependency_missing`,
  `technical_error`, or `overloaded`;
- ignores unrelated sidebar `LIVE` labels;
- accepts only validated HTTPS TikTok CDN stream URLs;
- can run on the gateway or through `exec host=node` on a paired node;
- falls back to the gateway when a node cannot complete the job.

No account is hardcoded. Operational documentation uses `example_creator`.
Working signed stream URLs must not be stored here.
