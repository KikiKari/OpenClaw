# DataSheet: Node 6 (Lenovo)

## Hardware & Hosting

| Attribut | Wert |
|----------|------|
| **Hostname** | Lenovo |
| **Modell** | Lenovo IdeaPad Slim 3 15AMN8 |
| **Prozessor** | AMD Ryzen 5 7520U with Radeon Graphics (2.80 GHz) |
| **RAM** | 8,00 GB (5,83 GB verwendbar) |
| **Speicher** | 477 GB (91 GB von 477 GB verwendet) |
| **Grafikkarte** | AMD Radeon 610M (2 GB) |
| **Systemtyp** | 64-Bit, x64-basierter Prozessor |
| **Geräte-ID** | 028E704D-26C0-4E79-85CD-C3074CC7D33E |
| **Produkt-ID** | 00342-21108-36530-AAOEM |
| **Standort** | Lokal (Notebook) |

## Betriebssystem

| Attribut | Wert |
|----------|------|
| **OS** | Windows 11 Home |
| **Version** | 25H2 |
| **Build** | 26200.8037 |
| **Installiert am** | 22.09.2025 |

## Netzwerk

| Attribut | Wert |
|----------|------|
| **Verbindung zum Gateway** | SSH-Tunnel → localhost:18789 |
| **Gateway-Host** | 152.53.145.65:18789 |
| **SSH-Tunnel** | `ssh -N -L 18789:127.0.0.1:18789 openclaw@152.53.145.65` |
| **WireGuard** | — (nicht konfiguriert) |

## OpenClaw

| Attribut | Wert |
|----------|------|
| **Rolle** | Node |
| **Node-ID** | 5c0bd3382ead6bde902e96cdd573da437715d39d9e648b6ae1d2bbf00c361fa5 |
| **Version** | 2026.4.10 |
| **Node.js** | v25.9.0 |
| **Paketmanager** | pnpm |
| **Config** | C:\Users\Admin\.openclaw\openclaw.json |
| **Service** | Scheduled Task: "OpenClaw Node" |
| **Service Script** | C:\Users\Admin\.openclaw\node.cmd |
| **Capabilities** | browser, system |

## Status

| Komponente | Status |
|------------|--------|
| **OpenClaw Node** | ✅ Paired & Connected |
| **SSH-Tunnel** | ⚠️ Manuell (Automatisierung via Aufgabenplanung ausstehend) |
| **Scheduled Task** | ✅ Registriert |
| **Node.js** | ✅ v25.9.0 |

## Aufgabenplanung (Scheduled Task)

### SSH-Tunnel Task (ausstehend)
```
Name: OpenClaw SSH Tunnel
Trigger: Bei Anmeldung
Aktion: ssh -N -L 18789:127.0.0.1:18789 openclaw@152.53.145.65
```

### OpenClaw Node Task (bereits registriert)
```
Name: OpenClaw Node
Trigger: Bei Anmeldung
Aktion: C:\Users\Admin\.openclaw\node.cmd
```

## Notizen
- Erstverbindung: 2026-04-11
- SSH-Passwort-Auth erforderlich (kein SSH-Key auf Windows konfiguriert)
- SSH-Tunnel muss vor dem Node-Dienst gestartet werden
- Kein WireGuard konfiguriert — SSH-Tunnel als Verbindungsmethode
