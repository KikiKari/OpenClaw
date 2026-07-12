---
name: tiktok-live
description: Check a TikTok account's current LIVE status and return a validated three-line TikTok LIVE response with an optional VLC/MPV URL. Use for one-shot /tiktok_live live, offline, restricted, overloaded, or technical-error checks; not for monitoring, recording, notifications, analytics, or recorded videos.
---

# TikTok LIVE

## Normal one-shot flow

For a normal `/tiktok_live @handle` request, take the handle from the current `User input:`, remove whitespace and one leading `@`, and validate it against `^[A-Za-z0-9._]{1,24}$`.

Make the existing dispatcher the first action:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

Use an elevated exec call and omit both the `host` and `node` fields so the
configured `tools.exec.host=auto` routing remains effective. If exec returns a
running session, poll that same session until completion. Parse only the final
stdout JSON object after the process exits; stderr, progress output, tool
diagnostics, and earlier attempts are never public response content.

The first result is final for `live`, `offline`, or `restricted`. When that
local invocation cannot run, returns invalid final stdout JSON, or ends in
`technical_error`, `dependency_missing`, or `overloaded`, retry exactly once
on the least-loaded connected paired node reported by the dispatcher. With the
current single-node pool this is `xnetx`. Keep the global
`tools.exec.host=auto`; for only this retry use an elevated exec call with
`host=node`, the selected node id/name, environment
`TIKTOK_EXECUTION_CONTEXT=node` and `TIKTOK_NODE_ID=<selected-node-id>`, and:

```bash
python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json --execution local
```

OpenClaw 2026.6.11 permits this explicit per-call node request while the
configured default remains `auto`. Poll the node session to completion and
parse only its final stdout JSON. Never start a second node retry and never
change the global exec host for routing. If the selected node is disconnected,
overloaded, unauthorized, missing dependencies, or returns invalid JSON,
produce the documented three-line error response without another fallback. If
the user reports an expired URL, start one fresh local-first flow.

Always use the literal absolute path shown above. Never replace it with
`~/.openclaw/...`, `$HOME/.openclaw/...`, or `/workspace/...` in OpenClaw
Control; those forms do not match the strict gateway/node approval rules.

The dispatcher retains its complete internal method and fallback sequence. Node, browser, file, directory, configuration, dependency, and diagnostic tools remain available with their existing behavior; this normal-flow preference does not remove, block, or redefine any capability. Use additional diagnostics when the user explicitly requests diagnosis or when handling a separate diagnostic task.

## Public response

Read the dispatcher JSON and produce exactly these three public text lines:

```text
@<handle> is currently <LIVE|OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.
VLC/MPV: <validated URL or not available>
Method: <validated method>
```

- Map `live`, `offline`, `restricted`, and `overloaded` to their uppercase labels; map `dependency_missing` and `technical_error` to `TECHNICAL_ERROR`.
- Use the top-level `method`; if absent, use the decisive or successful `attempts[]` method, otherwise `unknown`.
- Print the returned URL only for `live`; otherwise print `not available`.
- Construct all three lines in memory and send them atomically in one public
  text response. Preserve a returned URL byte-for-byte as one unshortened
  string; do not stream, summarize, link-label, or reformat it.
- Keep internal reasoning, stderr, progress, fallback history, and tool
  diagnostics in their dedicated channels. Do not copy them into the public
  three-line text.
- If the dispatcher cannot run or its JSON is invalid, use `TECHNICAL_ERROR`, `not available`, and `dispatcher_error` in the same three-line format.

## Synchronized audio

After the complete three-line text has been constructed, pass exactly that
same text to TTS. The audio must read the same three lines with no preface,
summary, translation, omission, or added explanation. Emit the public text
once and the audio attachment once; an audio placeholder such as `Audio reply`
is not a second copy of the textual result. Never invoke TTS before the final
text is complete.

## Existing capabilities

The skill's scripts and runtime details remain available for explicitly requested troubleshooting and other existing supported workflows:

- Runtime reference: `references/TIKTOK.md`
- Basic profile and stream scripts: `scripts/tiktok-check-profile.js` and `scripts/tiktok-get-stream.js`
- Enhanced extractor: `$HOME/.openclaw/workspace/skills/tiktok-live-mon/SKILL.md`
- Dispatcher and monitor reference: `$HOME/.openclaw/workspace/tiktok-monitor/SKILL.md`
