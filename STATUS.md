# Script Abstractions - Status Report

**Letzte Aktualisierung:** 2026-05-23 18:04

- Aktuelle Priorität: medium
- Verarbeitete Scripts: 0
- Abstraktionen gesamt: 70

## Abstraktionen pro Sprache

- javascript: 14
- perl5: 14
- python: 14
- shell: 14
- tcl: 14

## Verfügbare Modelle

- `openrouter/moonshotai/kimi-k2.5`
- `openrouter/openai/gpt-4o`
- `openrouter/anthropic/claude-3-5-sonnet-20241022`
- ... und 3 weitere

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
| node1 | ✅ Immer | medium | 2 | Server |
| node2 | ✅ Immer | medium | 3 | Server |
| node3 | 📱 Bedingt | medium | 4 | Server |
| node5 | 📱 Bedingt | low | 5 | Redmi Note 11S |
| node7 | ✅ Immer | high | 1 | Server |

### Job-Verteilung

- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)
- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)
- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)
