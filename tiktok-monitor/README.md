# TikTok LIVE Monitor

Der gemeinsame Dispatcher ist der kanonische Einstieg für Status- und
URL-Abfragen:

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" check @example_creator
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" url example_creator
```

Er normalisiert Handles, unterscheidet `live`, `offline` und `restricted`,
validiert Stream-URLs und liefert Überlast als Exit `75`. Im URL-Modus steht
ohne `--json` ausschließlich die nackte URL auf stdout.

Der Gateway kann alle Abfragen lokal ausführen. Ein OpenClaw-Agent kann
denselben Befehl über `exec host=node` auf einem verbundenen gepaarten Node
mit `--execution local` starten. Fehlschlag, fehlende Abhängigkeiten, Timeout
oder Überlast führen standardmäßig zum Gateway-Fallback.

Für den zustandsbehafteten Monitor und Daemon:

```bash
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" help
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" check example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" url example_creator
"$HOME/.openclaw/workspace/tiktok-monitor/tt-live.sh" daemon example_creator --hours 24 --poll-min 10
```

Details stehen in `SKILL.md` und `docs/`.
