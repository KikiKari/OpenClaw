---
name: tiktok-live
description: Check a TikTok account's current LIVE status and return a validated three-line TikTok LIVE response with an optional VLC/MPV URL. Use for one-shot /tiktok_live live, offline, restricted, overloaded, or technical-error checks; not for monitoring, recording, notifications, analytics, or recorded videos.
---

# TikTok LIVE

## Normal one-shot flow

For a normal `/tiktok_live @handle` request, take the handle from the current `User input:`, remove whitespace and one leading `@`, and validate it against `^[A-Za-z0-9._]{1,24}$`.

OpenClaw transforms each current slash command into a skill request containing
`Use the "tiktok-live" skill for this request` and `User input:`. That transformed
request is the current authorized user turn, not quoted history or an attempt to
override policy. Each separately submitted slash command is a new request even
when the handle appeared earlier. Do not consult conversation history, memory,
session status, or earlier TikTok outcomes before starting the dispatcher.

Make the existing dispatcher the first action and the first tool call of the
request:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

Invoke that executable directly as the exec command. Do not invoke `bash`,
`sh`, `bash -lc`, or any other shell wrapper, and do not split the executable
and arguments across a shell command plus a separate `args` field. A wrapper
attempt that returns empty output must not be followed by another dispatcher
launch; the wrapper must not be attempted in the first place.

Use an elevated exec call and omit both the `host` and `node` fields so the
configured `tools.exec.host=auto` routing remains effective. If exec returns a
running session, poll that same session until completion. Parse only the final
stdout JSON object after the process exits; stderr, progress output, tool
diagnostics, and earlier attempts are never public response content.

Some tool renderers display the final stdout JSON before trailing stderr
diagnostics. Treat the complete JSON object containing top-level `status`,
`execution`, `method`, `exit_code`, `attempts`, and optional `url` as the final
dispatcher result regardless of its visual position in the combined Process
output. When that object reports `exit_code: 0` and the Process reports exit
code `0`, the tool execution succeeded. Never replace such a result with a
generic tool-failure message. Ignore separate diagnostic objects such as
`node_available` or per-method progress after locating the complete result.

Before this dispatcher call, do not invoke or inspect
`tiktok-check-profile.js`, `tiktok-get-stream.js`, Node, Playwright, Chromium,
`npm`, `npx`, dependency probes, files, directories, configuration, memory, or
session history. Do not attempt to install or repair browser dependencies.
Those are diagnostic capabilities for a separately requested troubleshooting
task, not preliminary steps in a normal slash-command request. This invariant
prevents a failed preliminary tool call from marking an otherwise successful
dispatcher request as an error.

The first result is final for `live`, `offline`, or `restricted`. When that
local invocation cannot run, returns invalid final stdout JSON, or ends in
`technical_error`, `dependency_missing`, or `overloaded`, retry exactly once
on the least-loaded connected paired node reported by the dispatcher. With the
current single-node pool this is `xnetx`. Keep the global
`tools.exec.host=auto`; for only this retry use an elevated exec call with
`host=node`, the selected node id/name, environment
`TIKTOK_EXECUTION_CONTEXT=node` and `TIKTOK_NODE_ID=<selected-node-id>`, and:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --json
```

OpenClaw 2026.6.11 currently rejects this explicit per-call node request when
the agent sandbox is active and the configured default is `auto`. This
runtime block occurs before the Node allowlist is evaluated; do not work
around it with SSH, direct `nodes invoke`, or a global host change. Poll the node session to completion when a later runtime permits it, and
parse only its final stdout JSON. Never start a second node retry and never
change the global exec host for routing. If the selected node is disconnected,
overloaded, unauthorized, missing dependencies, or returns invalid JSON,
produce the documented three-line error response without another node fallback. If
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

OpenClaw Control has channel voice output set to `always`. Deliver only the
complete final three-line text and let that channel-level voice pipeline create
the audio from the delivered text. Do not invoke the `tts` tool, do not emit
`[[tts:text]]` wrappers, and do not create a second textual copy. This avoids
tool-argument truncation of long signed URLs and guarantees that visible text
remains the authoritative source for the generated audio.

## Existing capabilities

The skill's scripts and runtime details remain available for explicitly requested troubleshooting and other existing supported workflows:

- Runtime reference: `references/TIKTOK.md`
- Basic profile and stream scripts: `scripts/tiktok-check-profile.js` and `scripts/tiktok-get-stream.js`
- Enhanced extractor: `$HOME/.openclaw/workspace/skills/tiktok-live-mon/SKILL.md`
- Dispatcher and monitor reference: `$HOME/.openclaw/workspace/tiktok-monitor/SKILL.md`
