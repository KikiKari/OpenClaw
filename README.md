# Gateway 2 — Script Abstractions

Automatisch generierte und synchronisierte Abstraktionen der Scripts
von Gateway 2. Erstellt und verwaltet durch den Abstraction Manager.
Veröffentlicht auf GitHub und ClawHub (Skills).

## Aktueller Status

| Kennzahl | Wert |
| --- | --- |
| Abstraktionen gesamt | 398 |
| Letzte Synchronisation | 2026-08-09 |
| Aktuelle Priorität | medium |

## Verteilung nach Sprache

| Sprache | Anzahl | Verzeichnis |
| --- | --- | --- |
| JavaScript | 67 | `javascript/` |
| Perl 5 | 71 | `perl5/` |
| Python | 62 | `python/` |
| PowerShell | 59 | `powershell/` |
| Shell | 65 | `shell/` |
| Tcl | 74 | `tcl/` |

## Historische Job-Verteilung auf Nodes (stillgelegt)

Die folgende Verteilung stammt aus dem erhaltenen Gateway-2-Vorbestand. Der
aktuelle Abstraktionslauf verwendet sie nicht; sie bleibt hier dokumentiert,
statt die Vorarbeit zu entfernen.

| Node | Kapazität | Aufgaben |
| --- | --- | --- |
| node7 | High | Heavy Jobs (>50 KB × Sprache), Docker |
| node1 | Medium | Primary |
| node2 | Medium | Stable Fallback |
| node3–6 | Medium | Bedingt verfügbar |
| node5 | Low | Light Jobs (Redmi Note 11S) |

Beide Gateways nutzen denselben Node-Pool (2–8). Verfügbarkeit und Priorität
werden zur Laufzeit über das Tailscale VPN (Fallback: WireGuard) geprüft.

## Synchronisation

Die Erzeugnisse werden durch `ABSTRACTIONS_MANAGER.py` erstellt und auf diesem
Branch veröffentlicht. Detaillierter Status: [STATUS.md](STATUS.md)
