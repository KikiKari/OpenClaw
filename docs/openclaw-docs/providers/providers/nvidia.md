# OpenClaw Provider: NVIDIA

Quelle: https://docs.openclaw.ai/providers/nvidia.md
Gescrapt: 2026-04-21

## Übersicht
- OpenAI-kompatible API: `https://integrate.api.nvidia.com/v1`
- **Kostenlos** für gelistete Modelle
- API Key: https://build.nvidia.com/settings/api-keys

## Setup
```bash
export NVIDIA_API_KEY="nvapi-..."
openclaw onboard --auth-choice skip
openclaw models set nvidia/nvidia/nemotron-3-super-120b-a12b
```

## Config Beispiel
```json5
{
  env: { NVIDIA_API_KEY: "nvapi-..." },
  models: {
    providers: {
      nvidia: {
        baseUrl: "https://integrate.api.nvidia.com/v1",
        api: "openai-completions",
      },
    },
  },
  agents: {
    defaults: {
      model: { primary: "nvidia/nvidia/nemotron-3-super-120b-a12b" },
    },
  },
}
```

## Built-in Katalog
| Model Ref | Name | Context | Max Output |
|-----------|------|---------|------------|
| `nvidia/nvidia/nemotron-3-super-120b-a12b` | NVIDIA Nemotron 3 Super 120B | 262,144 | 8,192 |
| `nvidia/moonshotai/kimi-k2.5` | Kimi K2.5 | 262,144 | 8,192 |
| `nvidia/minimaxai/minimax-m2.5` | MiniMax M2.5 | 196,608 | 8,192 |
| `nvidia/z-ai/glm5` | GLM 5 | 202,752 | 8,192 |

## Wichtige Hinweise
- Auto-Enable: Provider aktiviert sich automatisch wenn `NVIDIA_API_KEY` gesetzt
- Kosten: Alle $0 (kostenlos)
- Standard OpenAI `/v1` Endpoint → jedes OpenAI-kompatible Tool funktioniert

## Weiterführende Links
- [Model Selection](https://docs.openclaw.ai/concepts/model-providers)
- [Configuration Reference](https://docs.openclaw.ai/gateway/configuration-reference)
