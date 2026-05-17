# DataSheet: Node 5 (Redmi Note 11S)

**Status:** ✅ Verbunden und aktiv

---

## Hardware

| Attribut | Wert |
|----------|------|
| **Gerät** | Xiaomi Redmi Note 11S |
| **Modell** | 2201117SG |
| **Typ** | Mobile Client / Worker Node |
| **OS** | Android 13 (TP1A.220624.014) |
| **HyperOS** | Xiaomi HyperOS 1.0.9.0.TKEMIXM |
| **Kernel** | 4.19.191-g6e5440f6a542 |
| **Baseband** | MOLY.LR13.R2.MP.V16.1.P89 |
| **Sicherheitsupdate** | 2024-12-01 |
| **CPU** | 8 Core (ARM) |
| **RAM** | 6 GB |
| **Storage** | 128 GB |

---

## Netzwerk-Konfiguration

| Attribut | Wert |
|----------|------|
| **WireGuard IP** | 10.10.0.5/32 |
| **WireGuard App** | v1.0.20260315 |
| **Gateway** | 10.10.0.1:51820 |
| **Endpoint** | 152.53.145.65:51820 |
| **Status** | ✅ Aktiv und verbunden |

---

## Software / Apps

### Android Apps
| App | Version | Status |
|-----|---------|--------|
| **Termux** | 0.118.3 | ✅ Aktiv |
| **WireGuard** | 1.0.20260315 | ✅ Aktiv |
| **OpenClaw Node** (Android App) | 2026.3.29 | ⚠️ Kein Google-Account, veraltet |
| **Spotify** | Installiert | ✅ Angemeldet |

### In Termux (Debian proot)
| Software | Version | Status |
|----------|---------|--------|
| **Debian** | Root-Zugang | ✅ Aktiv |
| **OpenClaw Node** (npm) | v2026.4.11 | ✅ Aktuell |

**Hinweis:** Die OpenClaw Android App (v2026.3.29) erfordert Google-Account-Anmeldung, die derzeit nicht vorhanden ist. Der aktive Node läuft über Termux/Debian mit der aktuellen npm-Version.

---

## OpenClaw Node

| Attribut | Wert |
|----------|------|
| **Node-Name** | localhost |
| **Rolle** | Worker Node / Mobile Client |
| **Verbindung** | WireGuard → 10.10.0.1:18789 |
| **Node-Befehl** | `openclaw node run --host 10.10.0.1 --port 18789` |
| **Status** | ✅ Verbunden (paired · connected) |
| **Caps** | browser, system |

---

## Wichtige Hinweise

- **`am start` Befehle** funktionieren NUR in der nativen Termux-Shell, NICHT in Debian proot
- **Node im Hintergrund:** `nohup openclaw node run --host 10.10.0.1 --port 18789 > /dev/null 2>&1 &`
- **exec-policy** noch nicht synchronisiert (`openclaw exec-policy sync --accept` ausstehend)

---

## Anwendungsfälle

- Remote Monitoring (Cluster-Status von unterwegs)
- Mobile Worker (kleine Tasks)
- Spotify-Steuerung (über Android Intents)
- Backup Client (Fotos/Daten syncen)
- Alert Empfänger (Push-Benachrichtigungen, zukünftig)

---

## Offene Punkte

- [ ] exec-policy synchronisieren
- [ ] OpenClaw Android App aktualisieren (Google-Account benötigt)
- [ ] Termux Autostart einrichten (Node persistent)

---

**Historie:**
- 2026-04-06: Ursprünglich als Node 4 angelegt
- 2026-04-10: Umnummeriert zu Node 5 (Node 4 = Webhosting)
- 2026-04-12: Datasheet aktualisiert mit vollständigen Hardware/Software-Details

**Zuletzt aktualisiert:** 2026-04-12
