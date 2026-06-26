---
name: tiktok-live
description: Check TikTok live status or extract TikTok Live stream URLs by running the local Playwright scripts. Never use Tavily, Perplexity, web_search, browser search, or general web search for this skill. If the user supplies only a TikTok handle, username, or profile URL, run the live-status check immediately without asking a clarifying question.
command-dispatch: tool
command-tool: tiktok_live_direct
---

# TikTok Live Stream Extraction

Extract live stream URLs from TikTok using profile-scoped Playwright detection.

## Mandatory Tool Routing

This is not a web-search skill. Do not use Tavily, Perplexity, `web_search`,
browser search, or general internet search to check TikTok live status.

If the user supplies only a TikTok handle, username, or profile URL, the
default intent is: check whether that profile is currently live. Do not ask a
clarifying question for this case; run the status command immediately.

Replace `@username` in the command examples with the supplied handle.

After reading this skill, execute the Gateway script directly:

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-check-profile.js @username
```

For stream extraction, execute:

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-get-stream.js @username
```

For command responses, always send a concise user-facing reply. If an account
is live, resolve a VLC/MPV URL before replying. Do not stop at live status
alone. If URL extraction fails after all methods, say explicitly that the
account is LIVE but no VLC/MPV URL could be resolved, and include only the
compact failure reason. Do not paste full tool logs or repeated attempt output.
Use the exact absolute script paths above. Do not use `$HOME`, shell
substitutions, shell assignments, or approval-command text in normal replies.
Try the exec call first. If the exec tool itself returns an approval-pending
response, relay only that exact approval request.

Do not run `tiktok-live`, `tiktok-live-mon`, or any guessed skill name as a
shell command; these are skill names, not executables.

Do not spawn a subagent, background task, monitor session, or long-running child
run for a one-off live-status or stream-URL request. Execute the script command
in the current agent turn and report the JSON or URL result directly.

Never substitute these commands with a search query. If the script cannot run in
the current sandbox, retry on the Gateway or an eligible node as described below.

## Overview

This skill provides reliable TikTok Live stream extraction by:
1. Using Playwright + Chromium for profile-scoped live status detection
2. Capturing network traffic to extract FLV stream URLs
3. Supporting multiple playback methods (VLC, MPV, FFmpeg)

**Why profile-scoped detection?** API and page-wide text checks can be
ambiguous. In particular, TikTok's permanent navigation item “LIVE” is not a
creator status indicator.

## Prerequisites

```bash
# Install Playwright (if not present)
npm install playwright
npx playwright install chromium

# UFW Firewall (outgoing)
sudo ufw allow out 80/tcp
sudo ufw allow out 443/tcp
```

## Quick Start

### Check Live Status

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-check-profile.js <username>
```

The username may be supplied with or without a leading `@`.

**Output:** JSON with `isLive` boolean and detection indicators

### Extract Stream URL

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-get-stream.js <username>
```

The username may be supplied with or without a leading `@`.

**Output:** Nackte URL (eine Zeile), z.B.:
```
https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/stream-..._ld.flv?...
```
Bei Fehler oder nicht-live: leerer Output + exit code 1.

## How It Works

### Step 1: DSGVO Banner Handling
The cookie banner blocks the profile picture. Must be closed first:

```javascript
const verstandenButton = await page.$('button:has-text("Verstanden")');
if (verstandenButton) await verstandenButton.click();
```

### Step 2: Wait for Full Page Load
Wait for "Erneute Veröffentlichungen" tab to appear (indicates complete load).

### Step 3: Profile-Scoped Live Detection
Check only indicators belonging to the requested profile:
1. Live icon or badge inside the profile header
2. Live border around the profile avatar
3. Exact profile link (`a[href*="/@<username>/live"]`)

Never use a page-wide `LIVE` text selector; it matches TikTok navigation.

### Step 4: Stream URL Extraction
The stream extractor runs the status checker first. Only after a confirmed
live result does it navigate to `/live` and capture FLV/HLS traffic.

### Step 5: Browser Cleanup
**Critical:** Always close browser with `browser.close()` to ensure fresh sessions.

## Stream Playback Options

Das Skript gibt nur die nackte URL aus. Zum Abspielen:

```bash
# URL fuer VLC/MPV ermitteln
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-get-stream.js username

# FFmpeg (Download)
ffmpeg -i "URL" -c copy output.mp4

# FFmpeg (Restream zu RTMP)
ffmpeg -i "URL" -c copy -f flv rtmp://...
```

**Wichtig:** URLs immer als nackte URLs weitergeben — kein `vlc "..."` Prefix in Dokumentation oder Logs.

## Execution Routing

1. Run the command on the Gateway by default.
2. For load balancing, inspect paired and connected nodes and only select nodes
   that advertise `system.run`.
3. Run the same command through the OpenClaw `exec` tool with:
   - `host: "node"`
   - `node: "<selected-node>"`
   - `env: { "TIKTOK_MAX_LOAD_PER_CPU": "1.0" }`
4. Retry another eligible node or the Gateway if execution returns exit code 75
   (`NODE_BUSY`), the script or Playwright is missing, the command times out, the
   node disconnects, or execution is denied.
5. The skill must be synchronized to the same
   `/home/openclaw/.openclaw/workspace/skills/tiktok-live/` path on every worker node.

The skill may be presented to the agent from a generated
`/workspace/.openclaw/sandbox-skills/...` path. That path is only a sandbox skill
copy and must not be used for Gateway or node execution. Do not use
`nodes invoke` or the removed legacy `nodes run` command for shell execution;
remote shell commands must use the OpenClaw `exec` tool with `host=node`.

## Alternative Extraction Methods

| Method | Command | Pros | Cons |
|--------|---------|------|------|
| yt-dlp | `yt-dlp -g "https://tiktok.com/@user/live"` | Fast, no browser | Less reliable |
| streamlink | `streamlink "https://tiktok.com/@user/live" best` | Multi-platform | Experimental support |
| gallery-dl | `gallery-dl -g "https://..."` | Dedicated tool | Limited TikTok support |

## Critical Learnings

- **Scope selectors**: Generic page-wide `LIVE` text causes false positives
- **DSGVO banner**: Close supported variants before evaluating the profile
- **Page load**: Wait for "Erneute Veröffentlichungen" tab
- **Browser cleanup**: Essential for fresh sessions
- **Stream TTL**: URLs valid 2-4 hours (signature-based)
- **Quality levels**: `_ld.flv` (low), `_sd.flv` (standard), `_hd.flv` (high)

## Stream Restrictions

TikTok Live Streams können verschiedene Einschränkungen haben, die die Extraktion beeinflussen:

### 1. Age-Restricted / Age-Gated Streams
**Erkennungsmerkmale:**
- Kein roter Rahmen um Profilbild auf der Profilseite
- Kein LIVE-Badge auf der Profilseite
- Auf `/live` Seite: "Bei TikTok anmelden" + "Dieses LIVE enthält Themen, die von einigen als unangenehm empfunden werden können"
- Stream läuft technisch, ist aber ohne Login nicht zugänglich

**Auswirkungen:**
- FLV-URLs können nicht extrahiert werden (kein Netzwerk-Traffic ohne Auth)
- `tiktok-check-profile.js` zeigt möglicherweise `isLive: true` (technisch korrekt, aber nicht öffentlich)
- Alte FLV-Links funktionieren nicht (Signatur abgelaufen)

**Lösung:**
- Warten auf nächsten öffentlichen Stream
- Oder: Extraktion mit authentifiziertem TikTok-Account (Login-Cookies erforderlich)

### 2. [Weitere Einschränkungen - dokumentieren sobald reproduzierbar]
- Region-locked Streams
- Follower-only Streams
- Subscriber-only Streams

## Multi-Node Support

Use the routing procedure in **Execution Routing**. Node availability and
capabilities must be checked at runtime; static Node 2/Node 3 assumptions and
direct SSH examples are not authoritative.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| False positive from “LIVE” | Ensure every selector is scoped to the profile header |
| No profile Live indicator | Treat the profile as offline |
| Browser hangs | `pkill -f chromium` |
| 403 on stream URL | URL expired, re-extract |
| Session issues | Ensure `browser.close()` called |
| FFmpeg 403 | Add `-user_agent "Mozilla/5.0"` |
| Stream erkannt aber keine FLV URL | Prüfe auf Age-Restriction (siehe oben) |
| "Bei TikTok anmelden" auf /live | Stream ist age-restricted, Login erforderlich |
| SSH-Tunnel down (Node 3) | Restart: `ssh -f -N -R 18794:localhost:22 ...` |

## References

- Full documentation: `references/TIKTOK.md`
- Current-state documentation: `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`
- Session log: `/home/openclaw/.openclaw/workspace/memory/2026-04-06.md`
- MEMORY.md: Search "TikTok Live Stream Extraktion"

## Scripts

- `scripts/tiktok-check-profile.js` - Live status check
- `scripts/tiktok-get-stream.js` - Stream URL extraction
