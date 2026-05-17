# OpenClaw Provider: OpenRouter

Quelle: https://docs.openclaw.ai/providers/openrouter.md
Gescrapt: 2026-04-21

## Übersicht
- Unified API für viele Modelle über einen Endpoint + API Key
- OpenAI-kompatibel

## Setup
```bash
# API Key erstellen: https://openrouter.ai/keys

openclaw onboard --auth-choice openrouter-api-key

# Optional: Modell wechseln (Standard: openrouter/auto)
openclaw models set openrouter/<provider>/<model>
```

## Config Beispiel
```json5
{
  env: { OPENROUTER_API_KEY: "sk-or-..." },
  agents: {
    defaults: {
      model: { primary: "openrouter/auto" },
    },
  },
}
```

## Model Refs
- Pattern: `openrouter/<provider>/<model>`
- Beispiel: `openrouter/anthropic/claude-3-haiku`

## Auth Headers (automatisch)
| Header | Wert |
|--------|------|
| `HTTP-Referer` | `https://openclaw.ai` |
| `X-OpenRouter-Title` | `OpenClaw` |
| `X-OpenRouter-Categories` | `cli-agent` |

## Wichtige Hinweise
- **Anthropic Cache Markers**: Auf verifizierten OpenRouter-Routen werden Anthropic `cache_control` Marker beibehalten
- **Thinking/Reasoning**: Auf unterstützten non-`auto` Routen wird Thinking-Level zu OpenRouter Reasoning Payloads gemappt
- **OpenAI-only Shaping**: `serviceTier`, `store`, Reasoning-compat Payloads werden NICHT weitergeleitet
- **Gemini-Routen**: Bleiben auf Proxy-Gemini-Pfad, mit Thought-Signature Sanitation
- **Provider Routing**: OpenRouter Routing Metadata wird weitergeleitet

## Weiterführende Links
- [Model Selection](https://docs.openclaw.ai/concepts/model-providers)
- [Configuration Reference](https://docs.openclaw.ai/gateway/configuration-reference)
