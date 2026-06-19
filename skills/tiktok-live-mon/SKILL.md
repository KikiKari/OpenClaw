---
name: tiktok-live-mon
description: TikTok Live stream monitoring and recording automation. Uses Playwright for visual detection and network traffic monitoring to capture FLV stream URLs. Supports automatic live status checks, stream recording to disk, and notification integration.
---

# TikTok Live Monitor

Automated TikTok Live stream monitoring with Playwright-based visual detection.

## Features

- **Visual Detection:** Uses Chromium/Playwright to detect live status (red border around profile)
- **Stream URL Extraction:** Captures FLV stream URLs from network traffic
- **Automatic Recording:** Saves streams to disk when live
- **Notifications:** Alerts when stream goes live/offline

## Usage

```bash
# Run all available methods with bounded retries/timeouts
python3 ~/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py check <username>
python3 ~/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url <username>

# Check if user is live
node ~/.openclaw/workspace/skills/tiktok-live-mon/scripts/tiktok-check-profile.js <username>

# Get stream URL
node ~/.openclaw/workspace/skills/tiktok-live-mon/scripts/tiktok-get-stream.js <username>
```

The dispatcher preserves Python/Webcast API, Playwright network capture,
streamlink, and yt-dlp. A failure or missing dependency in one method does not
disable the remaining methods.

## Requirements

- Node.js 16+
- Playwright with Chromium
