---
name: perplexity-pro-search
description: Use Perplexity Pro APIs and OpenClaw Perplexity search/MCP setup. Use when testing or operating native Perplexity Search API, Agent API, embeddings, contextualized embeddings, OpenClaw web_search provider, or mcp.servers.perplexity. Requires PERPLEXITY_API_KEY and must not print secrets.
metadata: {"openclaw":{"emoji":"P","primaryEnv":"PERPLEXITY_API_KEY","requires":{"env":["PERPLEXITY_API_KEY"],"bins":["curl","jq","npx"],"config":["plugins.entries.perplexity.enabled","tools.web.search.provider"]}}}
---

# Perplexity Pro Search

Use this skill when working with the native Perplexity Search API, direct Perplexity Pro APIs, or the OpenClaw Perplexity MCP/search configuration.

## Safety

- Never print `PERPLEXITY_API_KEY`.
- Prefer reading the key from the environment.
- Summarize API responses instead of dumping full embeddings or large agent outputs.
- Keep OpenClaw config secrets out of `openclaw.json`; use `.env`, `workspace/.env`, or the gateway service environment.
- Never hardcode `pplx-` tokens in skill files, scripts, examples, prompts, or MCP config.
- Rotate Perplexity API keys regularly, for example every 90 days, and update the gateway environment atomically.
- When generating new Perplexity keys, use descriptive token names such as `OpenClaw-Production` or `OpenClaw-Testing` because the full token is not visible after creation.

## Expected OpenClaw Setup

Native Perplexity Search API should use the `perplexity` web search provider without OpenRouter compatibility fields:

```json
{
  "tools": {
    "web": {
      "search": {
        "provider": "perplexity"
      }
    }
  },
  "plugins": {
    "entries": {
      "perplexity": {
        "enabled": true,
        "config": {
          "webSearch": {}
        }
      }
    }
  }
}
```

For the native OpenClaw path, `tools.web.search.provider` must be `perplexity` and the Gateway process must see `PERPLEXITY_API_KEY`. Keep `plugins.entries.perplexity.config.webSearch` empty when the key comes from the environment.

Do not set `plugins.entries.perplexity.config.webSearch.baseUrl` or `model` for the native Search API path. Those fields, an `OPENROUTER_API_KEY`, or an `sk-or-` key switch OpenClaw into the OpenRouter/Sonar compatibility path, which returns synthesized answers with citations instead of structured result rows.

The MCP server can be registered under `mcp.servers.perplexity`:

```json
{
  "mcp": {
    "servers": {
      "perplexity": {
        "command": "npx",
        "args": ["-y", "@perplexity-ai/mcp-server"]
      }
    }
  }
}
```

The official Perplexity MCP server expects `PERPLEXITY_API_KEY` in the MCP process environment. On this gateway, keep the key in the Gateway environment instead of writing plaintext into `mcp.servers.perplexity.env`.

## Direct API Modes

- Search API: `POST https://api.perplexity.ai/search`; returns ranked raw results.
- Agent API direct reference path: `POST https://api.perplexity.ai/v1/agent`; supports `input`, `preset`, `model`, `models`, `tools`, `stream`, and response `status`.
- OpenClaw Agent provider path: `baseUrl: "https://api.perplexity.ai/v1"` with `api: "openai-responses"`; OpenClaw appends its Responses endpoint.
- Embeddings API: `POST https://api.perplexity.ai/v1/embeddings`.
- Contextualized Embeddings API: `POST https://api.perplexity.ai/v1/contextualizedembeddings`.

## Quick Checks

Run these from the OpenClaw state directory:

```bash
{baseDir}/scripts/test-search.sh
{baseDir}/scripts/test-agent.sh
{baseDir}/scripts/test-embeddings.sh
{baseDir}/scripts/test-contextualized-embeddings.sh
```

OpenClaw checks:

```bash
openclaw config validate
openclaw mcp show perplexity
openclaw mcp list
```

## API Coverage

- Search API: `POST https://api.perplexity.ai/search`
- Agent API: direct `POST https://api.perplexity.ai/v1/agent`; OpenClaw provider uses `https://api.perplexity.ai/v1` plus `api: "openai-responses"`
- Embeddings API: `POST https://api.perplexity.ai/v1/embeddings` with `pplx-embed-v1-4b`
- Contextualized Embeddings API: `POST https://api.perplexity.ai/v1/contextualizedembeddings` with `pplx-embed-context-v1-4b`

## OpenClaw Web Search Parameters

Native Perplexity Search supports `query`, `count`, `country`, `language`, `freshness`, `date_after`, `date_before`, `domain_filter`, `max_tokens`, and `max_tokens_per_page`.

For `domain_filter`, use at most 20 domains and do not mix allowlist and denylist entries in one request.

Direct Search API uses `max_results`, `search_language_filter`, `search_domain_filter`, `search_recency_filter`, `search_after_date_filter`, and `search_before_date_filter`; OpenClaw maps its web-search parameters onto the provider path.

## Cookbook Fit

Use Search API patterns for news monitoring and domain-filtered lookup. Use Agent API for research assistants, model comparison, file/image Q&A, and generated reports. Use contextualized embeddings for document Q&A/RAG where chunks from the same document should share context.

## ClawHub

Before publishing, validate that no secrets are present:

```bash
rg -n "pplx-[A-Za-z0-9]{20,}|PERPLEXITY_API_KEY=" .
```

Publish from the parent workspace:

```bash
clawhub publish ./workspace/skills/perplexity-pro-search \
  --slug perplexity-pro-search \
  --name "Perplexity Pro Search" \
  --version 1.0.0 \
  --changelog "Initial Perplexity Pro API and MCP workflow skill"
```
