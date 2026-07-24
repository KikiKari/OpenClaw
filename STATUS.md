# Script Abstractions - Status Report

**Letzte Aktualisierung:** 2026-07-25 00:01

- Aktuelle Priorität: high
- Verarbeitete Scripts: 0
- Abstraktionen gesamt: 122

## Abstraktionen pro Sprache

- javascript: 27
- perl5: 27
- powershell: 13
- python: 27
- shell: 14
- tcl: 14

## Verfügbare Modelle

- `openrouter/auto`
- `openai/gpt-5.6-sol`
- `openai/gpt-5.6-terra`
- ... und 5 weitere

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
| node1 | ✅ Immer | medium | 2 | Server |
| node2 | ✅ Immer | medium | 3 | Server |
| node3 | 📱 Bedingt | medium | 4 | Server |
| node5 | 📱 Bedingt | low | 5 | Redmi Note 11S |
| node7 | ✅ Immer | high | 1 | Server |

### Job-Verteilung

- **Heavy Jobs** (>50 KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)
- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)
- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)
