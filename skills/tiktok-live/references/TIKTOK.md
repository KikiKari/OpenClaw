# TikTok LIVE Runtime Reference

Stand: 2026-06-21.

This document describes the active gateway/node implementation. Older
Port-5001, SSH, fixed-account, cron, and `/opt/tiktok-api` instructions are
historical and must not be used.

## Components

| Component | Purpose |
|---|---|
| `tiktok-monitor/tiktok_dispatch.py` | Canonical orchestration, result normalization, timeouts, routing metadata |
| `skills/tiktok-live/` | Basic account-specific profile check and Playwright URL extraction |
| `skills/tiktok-live-mon/` | Enhanced accessible/restricted/offline classification and extractor fallbacks |
| `tiktok-monitor/tt-live.sh` | Stateful Python/Webcast monitor and daemon |
| `tiktok-names/` | Durable identity/address-book history; not runtime configuration |

All paths are below `$HOME/.openclaw/workspace/`.

## Dispatcher examples

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py check @example_creator --json
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

`@example_creator` and `example_creator` identify the same account. No account
is hardcoded in active code or operational documentation.

JSON output contains at least:

```json
{
  "status": "live",
  "execution": "gateway",
  "node": null,
  "method": "playwright",
  "url": "https://<allowed-tiktok-cdn>/<stream>.flv?<signed-query>",
  "exit_code": 0
}
```

Valid statuses are `live`, `offline`, `restricted`, `overloaded`,
`dependency_missing`, and `technical_error`.

## Detection

The profile check is scoped to the requested account. Exact account LIVE links,
profile-header/avatar state, and the direct `/@example_creator/live` page are
used. Sidebar recommendations and unrelated `LIVE` labels do not count.

The enhanced checker treats a direct LIVE page as:

- `live` after an allowed TikTok CDN `.flv` response succeeds with HTTP `2xx`;
- `restricted` when account-specific LIVE/gating text is present but no
  accessible stream response is available;
- `offline` when exact ended/offline evidence is present or account-specific
  LIVE evidence is absent;
- `technical_error` when navigation or classification cannot complete safely.

The Python/Webcast result `live=true` is tentative until the Playwright direct
page check has ruled out restriction.

## URL validation

An extractor success must satisfy all of these conditions:

1. Output is a single normalized URL.
2. Scheme is HTTPS.
3. Host is an allowed TikTok/TikTok-CDN host.
4. Path represents an observed `.flv` stream.
5. The Playwright response status is HTTP `2xx`.

Do not accept arbitrary URLs returned by a fallback, redirect, node response,
or temporary file. Do not synthesize quality variants by modifying a signed
URL.

## Execution and fallback order

The dispatcher runs bounded attempts and preserves method attribution. It
always tries the lightweight Python/Webcast/API component first. A valid
Python playback URL is final, while Python `offline` remains tentative because
the Webcast path can produce false negatives. The fixed Node/Playwright path
then handles confirmation, restriction classification, technical/dependency
failures, and missing URLs.

Within the enhanced Node URL extractor, the order is:

1. Playwright response interception;
2. `streamlink`;
3. `yt-dlp`.

Fallback executables receive fixed argument arrays. Their stdout/stderr is
bounded and their whole process group is terminated on timeout.

The Port-5001 legacy API is retired and never runs in parallel with this path.
One user request starts one dispatcher process. Internal methods may run
sequentially, but no method runs after an authoritative final result.

## Gateway/node routing

The gateway remains a complete local executor. With `--execution auto`, the
caller may select a connected paired node that supports `system.run`, has the
required workspace/runtime, and is below the load threshold.

The OpenClaw agent invokes the node through `exec host=node`. On that node it
runs:

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py \
url @example_creator --json
```

The caller validates the returned JSON, status, URL, exit code, and node
identity. It falls back to the gateway for no suitable node, overload, missing
dependencies, timeout, or invocation failure unless fallback was disabled for
diagnosis.

Direct SSH and direct CLI `system.run` invocation are not part of this design.

## Load and exit codes

The gateway and every node apply the same preflight:

```text
1-minute load / CPU count <= TIKTOK_MAX_LOAD_PER_CPU
```

The default limit is `1.5`. Overload stops before browser launch with empty
non-JSON stdout and exit `75`.

| Result | Exit |
|---|---:|
| accessible LIVE / URL found | 0 |
| offline, restricted, or no URL | 1 |
| dependency or technical failure | 2 |
| invalid CLI usage | 64 |
| overload | 75 |

## VLC

```bash
/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @example_creator --json
```

Signed URLs may expire or be revoked at any time. Resolve again instead of
reusing documented links. Logs and documentation must contain placeholders,
not working signed URLs.

## Node prerequisites

Each executing node must provide:

- the synchronized workspace at `$HOME/.openclaw/workspace/`;
- Python 3 and Node.js;
- Playwright and its Chromium executable in the skill installation;
- optional `streamlink` and `yt-dlp` if those fallbacks are expected;
- outbound HTTPS connectivity.

If a prerequisite is absent, return `dependency_missing`; do not install
software implicitly during a check.
