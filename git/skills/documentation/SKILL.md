# Documentation Skill

**Status:** ✅ Aktiv - Verwendet für alle Cluster-Dokumentationen

## Zweck
Zentrale Verwaltung aller technischen Dokumentationen, DataSheets und Wissensdatenbank.

## Verwendung
```bash
# Neues DataSheet erstellen
openclaw docs datasheet --node <id> --type [vps|webhosting|mobile]

# Dokumentation aktualisieren
openclaw docs update --file <path> [--sync-cluster]

# Suche in Dokumentation
openclaw docs search "<query>"

# Index neu aufbauen
openclaw docs index [--all|--memory|--files]

# Versionskontrolle
openclaw docs changelog --since <date>
```

## Struktur

```
workspace/
├── DATASHEETS.md              # Master-Index
├── DATASHEET_NODE1.md         # Gateway
├── DATASHEET_NODE2.md         # Worker
├── DATASHEET_NODE3.md         # Relay
├── DATASHEET_NODE4.md         # Mobile (pending)
├── DATASHEET_NODE5.md         # Webhosting
├── INFRASTRUCTURE.md          # Netzwerk-Setup
├── TUNNELS.md                 # SSH-Tunnel
├── WIREGUARD_*.md             # VPN-Doku
├── README.md                  # Übersicht
└── skills/
    ├── documentation/
    ├── cluster-gateway/
    ├── worker-node/
    ├── relay-node/
    ├── resource-manager/
    └── server-maintenance/
```

## Dokumentations-Standards

### DataSheet Template

```markdown
# DataSheet: Node X (<name>)

## Hardware & Hosting
| Attribut | Wert |
|----------|------|
| **Hostname** | ... |
| **Server** | ... |
| **Standort** | ... |
| **IPv4** | ... |
| **IPv6** | ... |

## Netzwerk
...

## Services
...

## Status
| Komponente | Status |
|------------|--------|
| **Service X** | ✅/❌/⏳ |
```

### Änderungen Loggen

| Datei | Änderung | Datum |
|-------|----------|-------|
| DATASHEET_NODE3.md | +MAC, FQDN, Netzwerk-Details | 2026-04-06 |
| DATASHEETS.md | Erstellt als Master-Index | 2026-04-06 |
| skills/ | 5 neue Skill-Templates | 2026-04-06 |

## Auto-Update

```bash
# Nach Node-Changes automatisch aktualisieren
openclaw docs auto-update --on [change|daily|weekly]

# Beispiel: Nach Node 4 Pairing
openclaw datasheet node4 --fill-from-gateway
```

## Integration mit OpenClaw Memory

```bash
# Dokumentation in Memory indexieren
openclaw memory index --path workspace/ --recursive

# Suche über alle docs
openclaw memory search "WireGuard keys"
```

## Siehe auch
- Alle DATASHEET_*.md Dateien
- INFRASTRUCTURE.md
- MEMORY.md
