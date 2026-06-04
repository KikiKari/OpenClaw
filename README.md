# Gateway 2 — Script Abstractions

Automatisch generierte und synchronisierte Abstraktionen der Scripts
von Gateway 2. Erstellt und verwaltet durch den Abstraction Manager.
Veröffentlicht auf GitHub und ClawHub (Skills).

## Aktueller Status

| Kennzahl | Wert |
| --- | --- |
| Abstraktionen gesamt | 122 |
| Letzte Synchronisation | 2026-05-30 |
| Aktuelle Priorität | medium |

## Verteilung nach Sprache

| Sprache | Anzahl | Verzeichnis |
| --- | --- | --- |
| JavaScript | 27 | `javascript/` |
| Perl 5 | 27 | `perl5/` |
| Python | 27 | `python/` |
| PowerShell | 13 | `powershell/` |
| Shell | 14 | `shell/` |
| Tcl | 14 | `tcl/` |

## Job-Verteilung auf Nodes

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

Automatischer Sync durch den Abstraction Manager, typisch 2× täglich
(`auto: abstractions-sync`). Detaillierter Status: [STATUS.md](STATUS.md)
