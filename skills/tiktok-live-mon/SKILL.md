---
name: tiktok-live-mon
description: Check TikTok live status or extract TikTok Live stream URLs by running the local Playwright scripts. Never use Tavily, Perplexity, web_search, browser search, or general web search for this skill. If the user supplies only a TikTok handle, username, or profile URL, run the live-status check immediately without asking a clarifying question.
command-dispatch: tool
command-tool: tiktok_live_mon_direct
---

# TikTok Live Monitor

Automated TikTok Live monitoring with profile-scoped Playwright detection.

## Mandatory Tool Routing

This is not a web-search skill. Do not use Tavily, Perplexity, `web_search`,
browser search, or general internet search to check TikTok live status.

If the user supplies only a TikTok handle, username, or profile URL, the
default intent is: check whether that profile is currently live. Do not ask a
clarifying question for this case; run the status command immediately.

Replace `@username` in the command examples with the supplied handle.

After reading this skill, execute the Gateway script directly:

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live-mon/tiktok-check-profile.js @username
```

For stream extraction, execute:

```bash
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live-mon/tiktok-get-stream.js @username
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

## Features

- **Live Detection:** Uses only profile-scoped Live icons, badges, avatar
  borders, or the exact `/@<username>/live` link
- **Stream URL Extraction:** Captures FLV stream URLs from network traffic
- **Automatic Recording:** Saves streams to disk when live
- **Notifications:** Alerts when stream goes live/offline

## Usage

```bash
# Check if user is live
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live-mon/tiktok-check-profile.js @username

# Get stream URL
/usr/bin/node /home/openclaw/.openclaw/workspace/skills/tiktok-live-mon/tiktok-get-stream.js @username
```

Both commands accept usernames with or without a leading `@`.

The stream command performs the status check as a mandatory preflight. It does
not output a URL unless the profile is confirmed live. A page-wide `LIVE` text
selector is forbidden because it matches TikTok's permanent navigation.

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
   `/home/openclaw/.openclaw/workspace/skills/tiktok-live-mon/` path on every worker node.

The skill may be presented to the agent from a generated
`/workspace/.openclaw/sandbox-skills/...` path. That path is only a sandbox skill
copy and must not be used for Gateway or node execution. Do not use
`nodes invoke` or the removed legacy `nodes run` command for shell execution;
remote shell commands must use the OpenClaw `exec` tool with `host=node`.

## Requirements

- Node.js 16+
- Playwright with Chromium

See `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md` for the canonical
architecture, selector rules and component boundaries.
