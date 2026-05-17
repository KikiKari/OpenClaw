# OpenClaw Provider: MiniMax

Quelle: https://docs.openclaw.ai/providers/minimax.md
Gescrapt: 2026-04-21

## Provider IDs
| Provider ID | Auth | Capabilities |
|-------------|------|-------------|
| `minimax` | API key | Text, Image Gen, Image Understanding, Speech, Web Search |
| `minimax-portal` | OAuth | Text, Image Gen, Image Understanding |

## Modelle
| Model | Typ | Beschreibung |
|-------|-----|-------------|
| `MiniMax-M2.7` | Chat (reasoning) | Default Reasoning Model |
| `MiniMax-M2.7-highspeed` | Chat (reasoning) | Schnellere Version |
| `MiniMax-VL-01` | Vision | Image Understanding |
| `image-01` | Image Gen | Text-to-Image, Image-to-Image |
| `music-2.5+` | Music Gen | Default Music Model |
| `MiniMax-Hailuo-2.3` | Video Gen | Text-to-Video, Image Reference |

## Setup (Onboarding)

### OAuth
```bash
# International
openclaw onboard --auth-choice minimax-global-oauth

# China
openclaw onboard --auth-choice minimax-cn-oauth

# Verify
openclaw models list --provider minimax-portal
```

### API Key
```bash
# International
openclaw onboard --auth-choice minimax-global-api

# China
openclaw onboard --auth-choice minimax-cn-api

# Verify
openclaw models list --provider minimax
```

## Config Beispiel (API Key, Anthropic-kompatibel)
```json5
{
  env: { MINIMAX_API_KEY: "sk-..." },
  agents: { defaults: { model: { primary: "minimax/MiniMax-M2.7" } } },
  models: {
    mode: "merge",
    providers: {
      minimax: {
        baseUrl: "https://api.minimax.io/anthropic",
        apiKey: "${MINIMAX_API_KEY}",
        api: "anthropic-messages",
        models: [
          {
            id: "MiniMax-M2.7",
            name: "MiniMax M2.7",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 0.3, output: 1.2, cacheRead: 0.06, cacheWrite: 0.375 },
            contextWindow: 204800,
            maxTokens: 131072,
          },
          {
            id: "MiniMax-M2.7-highspeed",
            name: "MiniMax M2.7 Highspeed",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 0.6, output: 2.4, cacheRead: 0.06, cacheWrite: 0.375 },
            contextWindow: 204800,
            maxTokens: 131072,
          },
        ],
      },
    },
  },
}
```

## Konfigurationsoptionen
| Option | Beschreibung |
|--------|-------------|
| `models.providers.minimax.baseUrl` | `https://api.minimax.io/anthropic` (Anthropic) oder `.../v1` (OpenAI) |
| `models.providers.minimax.api` | `anthropic-messages` (empfohlen) oder `openai-completions` |
| `models.providers.minimax.apiKey` | API Key (`MINIMAX_API_KEY`) |
| `models.mode` | `merge` um MiniMax neben Built-ins zu nutzen |

## Image Generation
```json5
{
  agents: {
    defaults: {
      imageGenerationModel: { primary: "minimax/image-01" },
    },
  },
}
```
- Unterstützt: Text-to-Image, Image-to-Image (Subject Reference)
- Bis zu 9 Output-Bilder, 1 Reference-Bild
- Aspect Ratios: 1:1, 16:9, 4:3, 3:2, 2:3, 3:4, 9:16, 21:9

## Music Generation
```json5
{
  agents: {
    defaults: {
      musicGenerationModel: { primary: "minimax/music-2.5+" },
    },
  },
}
```

## Video Generation
```json5
{
  agents: {
    defaults: {
      videoGenerationModel: { primary: "minimax/MiniMax-Hailuo-2.3" },
    },
  },
}
```

## Web Search
- Provider ID: `minimax`
- Env Var: `MINIMAX_CODE_PLAN_KEY` (bevorzugt) oder `MINIMAX_CODING_API_KEY`
- Config: `plugins.entries.minimax.config.webSearch.*`

## Thinking Defaults
- Bei `api: "anthropic-messages"` wird Thinking standardmäßig deaktiviert
- Grund: MiniMax streamt `reasoning_content` im OpenAI-Format statt Anthropic Thinking Blocks

## Fast Mode
- `/fast on` oder `params.fastMode: true` → M2.7 wird zu M2.7-highspeed

## Fallback Beispiel
```json5
{
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-opus-4-6",
        fallbacks: ["minimax/MiniMax-M2.7"],
      },
    },
  },
}
```

## Model Refs
- API Key: `minimax/<model>` (z.B. `minimax/MiniMax-M2.7`)
- OAuth: `minimax-portal/<model>` (z.B. `minimax-portal/MiniMax-M2.7`)
- Case-sensitive!

## Troubleshooting
- "Unknown model" → Provider nicht konfiguriert, Fix ab v2026.1.12
- `openclaw models list` zur Prüfung

## Weiterführende Links
- [Model Selection](https://docs.openclaw.ai/concepts/model-providers)
- [Image Generation](https://docs.openclaw.ai/tools/image-generation)
- [Music Generation](https://docs.openclaw.ai/tools/music-generation)
- [Video Generation](https://docs.openclaw.ai/tools/video-generation)
- [MiniMax Search](https://docs.openclaw.ai/tools/minimax-search)
- [Troubleshooting](https://docs.openclaw.ai/help/troubleshooting)
