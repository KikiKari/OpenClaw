# Retired TikTok Port-5001 API

This directory archives the legacy systemd unit and compatibility launcher.
The service is not part of the canonical TikTok architecture. The old
workspace unit invoked a missing `app.py` with `Restart=on-failure`; the host
unit worked around that incomplete state by selecting `server.js` through the
launcher.

Canonical one-shot requests use `tiktok-monitor/tiktok_dispatch.py` and
long-running requests use `tiktok-monitor/tiktok-monitorctl.sh`.
