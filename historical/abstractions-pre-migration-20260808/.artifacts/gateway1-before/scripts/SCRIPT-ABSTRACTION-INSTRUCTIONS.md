# Script Abstraction Agent - Instruktionen

## ⚠️ WICHTIGE EINSCHRÄNKUNGEN

**Du darfst NUR in einem NEUEN Git-Repository arbeiten!**
- Arbeitsverzeichnis: `/home/openclaw/.openclaw/workspace/git/script-abstractions/`
- KEINE Änderungen an produktiven Scripts
- KEINE Änderungen an bestehenden Repositories
- NUR Lesen der Original-Scripts (keine Modifikation)

## Deine Aufgabe

1. **Repository erstellen**
   ```bash
   mkdir -p /home/openclaw/.openclaw/workspace/git/script-abstractions
   cd /home/openclaw/.openclaw/workspace/git/script-abstractions
   git init
   ```

2. **Struktur anlegen**
   ```
   script-abstractions/
   ├── original/      # Kopien der Original-Scripts (nur als Referenz)
   ├── python/        # Python-Versionen
   ├── perl5/         # Perl 5 Versionen
   ├── perl6/         # Perl 6/Raku Versionen
   ├── javascript/    # JavaScript/Node.js Versionen
   ├── tcl/           # Tcl Versionen
   ├── bash/          # Bash Versionen
   ├── powershell/    # PowerShell Versionen
   └── README.md      # Übersicht und Dokumentation
   ```

3. **Scripts zu portieren** (Priorität)
   - `db_maintainer.py` → Perl, JS, Bash
   - `json_processor.py` → Perl, JS, Tcl
   - `websearch-crawl.sh` → Python, Perl, PowerShell

4. **Git Commits**
   - Commit nach jeder Portierung
   - Aussagekräftige Commit-Messages
   - Beispiel: "Add Perl 5 version of db_maintainer"

## VERBOTEN
- Produktive Scripts ändern
- Scripts außerhalb von git/script-abstractions/ speichern
- Scripts aktiv ausführen oder deployen
- Änderungen am Hauptworkspace

## Zeitrahmen
- Arbeite 2-3 Stunden an den Portierungen
- Fokus auf Qualität statt Quantität
- Dokumentiere alle Besonderheiten