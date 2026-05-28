# Michele0303 tiktok-live-recorder Issue #428 - URL Retrieval Problem
**Quelle:** https://github.com/Michele0303/tiktok-live-recorder/issues/428
**Titel:** Live not found: Unable to retrieve live streaming url

## Problem
"Unable to retrieve live streaming url" - betrifft besonders 18+ Streams (nicht Superfan-privat, aber 18+ gesetzt).

## Ursache
- cookies.json editieren hilft NICHT
- Proxy/VPN hilft NICHT
- 18+ Streams haben eingeschränkte API-Antworten

## TikTok API Fallback-Logik (aus tiktok_api.py)
```python
if not sdk_data_str:
    # Fallback zu Legacy URLs
    return (
        stream_url.get("flv_pull_url", {}).get("FULL_HD1")
        or stream_url.get("flv_pull_url", {}).get("HD1")
        or stream_url.get("flv_pull_url", {}).get("SD2")
        or stream_url.get("flv_pull_url", {}).get("SD1")
        or stream_url.get("rtmp_pull_url", "")
    )

# Normale Extraktion
sdk_data = json.loads(sdk_data_str).get("data", {})
qualities = (
    stream_url.get("live_core_sdk_data", {})
    .get("pull_data", {})
    .get("options", {})
    .get("qualities", [])
)
```

## Wichtig
- `flv_pull_url` Keys: FULL_HD1, HD1, SD2, SD1
- `live_core_sdk_data.pull_data.options.qualities` für SDK-Streams
- Playwright-Methode (Network Traffic) umgeht diese API-Limitierungen komplett
