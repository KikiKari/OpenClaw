---
name: script-abstractions-manager
description: Uebersetzt Quelldateien per OpenRouter vollstaendig in sechs Zielsprachen und veroeffentlicht sie auf OpenClaw@gateway2-abstractions.
metadata:
  openclaw:
    emoji: "🔄"
    os: ["linux"]
    requires:
      bins: ["python3", "git"]
      env: ["OPENROUTER_API_KEY"]
---

# Script Abstractions Manager

Verwende ausschließlich den kanonischen Manager:

```bash
/home/openclaw/.openclaw/workspace/scripts/abstractions-manager.sh \
  --prioritaet high
```

Für eine unverändernde Inventarprüfung:

```bash
/home/openclaw/.openclaw/workspace/scripts/abstractions-manager.sh \
  --prioritaet high --anzahl 1 --probelauf
```

Der Manager erzeugt vollständige Modellübersetzungen in JavaScript, Perl 5,
PowerShell, Python, Bash und Tcl. Unfertige oder syntaktisch ungültige
Ergebnisse werden verworfen. Der alte Stub-Erzeuger, manuelle
`abstractions-utils`, Multi-Node- und Sub-Agent-Behauptungen sowie der separate
Publisher sind stillgelegt.

Ausgabe: `/home/openclaw/.openclaw/workspace/git/Abstraktionen`

Branch: `KikiKari/OpenClaw@gateway2-abstractions`

Dokumentation: `/home/openclaw/.openclaw/workspace/ABSTRACTIONS.md`
