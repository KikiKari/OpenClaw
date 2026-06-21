# TikTok LIVE Check Notes

Legacy account-specific check logs were removed from this active documentation.
Use `example_creator` in examples and pass real handles only at runtime.

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  check example_creator --execution auto --json
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  url example_creator --execution auto
```

Expected behavior:

- accessible LIVE: exit `0`;
- offline or restricted: exit `1`;
- dependency/technical failure: exit `2`;
- overload: exit `75`;
- non-JSON URL failure: empty stdout;
- non-JSON URL success: one naked, freshly resolved URL.

Do not paste working signed URLs into this file.
