# Retired TikTok API

The legacy localhost Port-5001/Port-16000 API and its tunnels are not part of
the current TikTok LIVE runtime.

Use the CLI dispatcher instead:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  check example_creator --json
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  url example_creator --json
```

JSON contains normalized `status`, `execution`, `node`, `method`, `url`, and
`exit_code` fields. Without `--json`, URL success writes only the naked URL to
stdout.

Remote work is initiated by an OpenClaw agent through `exec host=node`; there
is no replacement HTTP API or SSH dispatch layer.
