# Symlink-Konsolidierung Dokumentation
**Datum:** 2026-04-18
**Durchgeführt von:** Artif

## Übersicht
Zentrale Verwaltung von Dokumentationen durch Konsolidierung und Symlinks.

## 1. INFRASTRUCTURE.md
- **Zentrale Datei:** `/home/openclaw/.openclaw/workspace/INFRASTRUCTURE.md`
- **Symlinks in:** `nodes/`, `hardware/`, `cluster/`
- **Backup:** `INFRASTRUCTURE.md.backup.20260418_164926`
- **Status:** ✅ Alle 4 Versionen konsolidiert, aktuelle Infos übernommen

## 2. DATASHEET_NODE*.md (7 Dateien)
- **Zentrale Dateien:** `/home/openclaw/.openclaw/workspace/DATASHEET_NODE[1-7].md`
- **Symlinks in:** `archive/`, `cluster/`, `hardware/`, `nodes/`
- **Backup:** `backup-datasheets-20260418_181418/`
- **Besonderheiten:**
  - NODE2: Cluster-Version übernommen (GitHub CLI v2.90.0 Status)
  - NODE7: Cluster-Version übernommen (aktuellere Daten)
- **Status:** ✅ Aktuellste Versionen identifiziert und konsolidiert

## 3. OPS-HUB-*.md (7 Dateien)
- **Zentrale Dateien:** `/home/openclaw/.openclaw/workspace/OPS-HUB-*.md`
- **Symlinks in:** `docs/ops-hub/`
- **Backup:** `backup-opshub-20260418_181952/` und `backup-opshub-20260418_182003/`
- **Besonderheiten:** 
  - OPS-HUB-SKILL.md: Root-Version war neuer (17:41)
  - Kleingeschriebene Dateien bleiben erhalten (andere Inhalte)
- **Status:** ✅ Neueste Versionen als zentrale Dateien verwendet

## 4. CRON*.md (4 Dateien)
- **Zentrale Dateien:** `/home/openclaw/.openclaw/workspace/CRON_*.md`
- **Symlinks in:** `archive/`, `crons/`
- **Backup:** `backup-crons-20260418_182705/`
- **Besonderheiten:** 
  - Alle Versionen waren identisch
  - Zusätzliche Symlinks in crons/ für Template-Sichtbarkeit
- **Status:** ✅ Identische Versionen konsolidiert

## Wichtige Hinweise
1. Bei zukünftigen Änderungen immer die zentralen Dateien im Workspace-Root bearbeiten
2. Symlinks zeigen automatisch auf die aktuellen Versionen
3. Backups sind für Rollback verfügbar
4. Cron-Templates bleiben in `crons/` für manuelle Installation

## Gespartes Speichervolumen
- Vorher: ~80 redundante Dateien
- Jetzt: ~25 zentrale Dateien + Symlinks
- Ersparnis: ~55 Dateien / ~200KB