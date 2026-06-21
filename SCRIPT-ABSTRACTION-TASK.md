# Script Abstraction Task für Sub-Agent

## Aufgabe
Erstelle Abstraktionen/Portierungen der vorhandenen Scripts in alternative Programmiersprachen und veröffentliche diese auf Git.

## Zielsprachen für Portierung
1. **Python** → Perl 5/6, JavaScript, Tcl, Bash/PowerShell, JSON (wo sinnvoll)
2. **JavaScript** → Python, Perl 5/6, Tcl, Bash/PowerShell
3. **Shell/Bash** → Python, Perl 5/6, JavaScript, PowerShell, Tcl
4. **JSON** → Python, Perl 5/6, JavaScript, Tcl, Bash/PowerShell

## Prioritäre Scripts für Abstraktion

### Python Scripts (Höchste Priorität)
1. `db_maintainer.py` - Datenbankwartung
2. `json_processor.py` - JSON-Verarbeitung
3. `log_collector.py` - Log-Sammlung
4. `model_usage.py` - Model-Nutzungsanalyse
5. `tree_indexer.py` - Verzeichnisbaum-Indizierung

### JavaScript Scripts
1. `check-live.js` - Historischer TikTok-Prototyp; nicht mit dem aktiven Dispatcher verwechseln
2. `post-nodes-report.js` - Node-Reports
3. `wavespeed-image.js` - Bildverarbeitung

### Shell Scripts
1. `setup-secret-write.sh` - Secret-Verwaltung
2. `websearch-crawl.sh` - Web-Crawling
3. `server-maintenance.sh` - Server-Wartung

## Vorgehensweise
1. Analysiere die Funktionalität jedes Scripts
2. Identifiziere Core-Logik und Dependencies
3. Erstelle äquivalente Implementierungen in Zielsprachen
4. Behalte Funktionalität und Schnittstellen bei
5. Dokumentiere Unterschiede und Besonderheiten
6. Teste Grundfunktionalität (wo möglich)

Für TikTok gilt zusätzlich: keine Portierung gilt als gleichwertig, solange
Handle-Normalisierung, accountgenaue Selektoren, Restricted-Erkennung,
2xx/CDN-URL-Validierung, Exit `75`, Timeout/Prozess-Cleanup und der
stdout-Vertrag nicht vollständig übernommen und getestet sind. Maßgeblich ist
`$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py`.

## Git-Repository Struktur
```
workspace/git/script-abstractions/
├── original/           # Original-Scripts als Referenz
├── python/            # Python-Versionen
├── perl5/             # Perl 5 Versionen
├── perl6/             # Perl 6/Raku Versionen
├── javascript/        # JavaScript/Node.js Versionen
├── tcl/               # Tcl Versionen
├── bash/              # Bash Versionen
├── powershell/        # PowerShell Versionen
└── README.md          # Übersicht und Dokumentation
```

## Beispiel-Abstraktion
Original (Python):
```python
def process_json(data):
    return json.dumps(data, indent=2)
```

Perl 5:
```perl
use JSON;
sub process_json {
    my $data = shift;
    return encode_json($data);
}
```

JavaScript:
```javascript
function processJson(data) {
    return JSON.stringify(data, null, 2);
}
```

## Zeitrahmen
- Geschätzte Dauer: 2-3 Stunden
- Priorisierung: Erst die wichtigsten/meistgenutzten Scripts
- Dokumentation parallel zur Implementierung
