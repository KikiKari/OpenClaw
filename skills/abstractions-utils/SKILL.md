# abstractions-utils Skill

**Name:** abstractions-utils  
**Beschreibung:** Hilfs-Tools für manuelles Erstellen von Script-Abstraktionen  
**Version:** 1.0.0  
**Emoji:** 🔄  

## Schnelle Abstraktion

### Einzelnes Script portieren
```bash
# Python → Perl 5
python3 /openclaw/.openclaw/workspace/skills/abstractions-utils/scripts/create_abstraction.py \
  --source /workspace/skills/json-utils/scripts/json_processor.py \
  --target-lang perl5

# Shell → Python
python3 .../create_abstraction.py \
  --source /workspace/scripts/websearch-crawl.sh \
  --target-lang python \
  --use-model openrouter/moonshotai/kimi-k2.5
```

### Batch-Portierung
```bash
# Alle Scripts eines Skills
python3 .../batch_abstract.py \
  --skill json-utils \
  --langs perl5,javascript,python
```

## Verfügbare Scripts

| Script | Funktion |
|--------|----------|
| `create_abstraction.py` | Einzelne Portierung |
| `batch_abstract.py` | Batch-Verarbeitung |
| `compare_abstractions.py` | Vergleicht Original mit Portierung |
| `validate_syntax.py` | Syntax-Check für alle Sprachen |

## Unterstützte Sprachen

- `perl5` / `perl6` (Raku)
- `javascript` (Node.js)
- `python` (Python 3)
- `shell` (Bash)
- `powershell` (PowerShell 7)
- `tcl` (Tcl)
- `ruby` (Ruby)
- `lua` (Lua)
- `go` (Go)