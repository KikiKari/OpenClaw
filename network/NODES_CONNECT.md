# Node Connection Plan

## Ziel: Alle Nodes mit Gateway im Node Mode verbinden

## Gateway Status
- Gateway läuft auf: 152.53.145.65:18789
- Mode: local (kann nicht auf "node" gesetzt werden - nur "local" oder "remote")

## Nodes verwalten über: `openclaw nodes`
- Listet gepairte Nodes: `openclaw nodes list`
- Zeigt Status: `openclaw nodes status`
- Pending approvals: `openclaw nodes pending`

## Verbindungs-Mechanismus
1. Gateway generiert Setup Code: `openclaw qr --json`
2. Node verbindet sich mit diesem Code
3. Gateway approved die Verbindung: `openclaw nodes approve --latest`

## Benötigte Informationen
- SSH Zugangsdaten für die Remote Nodes
- ODER: Nodes müssen manuell/lokal konfiguriert werden

## Gateway QR Code (für Node Pairing)
