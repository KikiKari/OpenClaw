># SKILL-INDEX.md - Zentraler Skill-Index für alle Agenten

**Letzte Aktualisierung:** 2026-04-18 14:45 CET  
**Zweck:** Skill-Discovery für alle OpenClaw Agenten  
**Wichtig:** Diese Datei muss von allen Agenten beim Start gelesen werden!

---

## 📋 Verfügbare Skills

### Core Skills (System)

| Skill | Pfad | Beschreibung | Emoji |
|-------|------|--------------|-------|
| **ops-hub** | `~/.openclaw/skills/ops-hub/` | Zentraler Operations-Hub | 🎛️ |
| himalaya-email | `~/.openclaw/skills/himalaya/` | E-Mail via IMAP/SMTP | 📧 |
| healthcheck | `~/.openclaw/skills/healthcheck/` | Sicherheitsaudits | 🔒 |

### Workspace Skills (Projektspezifisch)

| Skill | Pfad | Beschreibung |
|-------|------|--------------|
| **cluster-management** | `~/.openclaw/workspace/skills/cluster-management/` | Cluster-Topologie & VPN |
| **db-maintainer** | `~/.openclaw/workspace/skills/db-maintainer/` | Datenbank-Wartung |
| **doc-scraper** | `~/.openclaw/workspace/skills/doc-scraper/` | Dokumentations-Extraktion |
| **git-publish-agent** | `~/.openclaw/workspace/skills/git-publish-agent/` | Git Publishing |
| **json-utils** | `~/.openclaw/workspace/skills/json-utils/` | JSON Parsing & Validation |
| **log-collector** | `~/.openclaw/workspace/skills/log-collector/` | Log-Sammlung via SSH |
| **mcp-tool-utils** | `~/.openclaw/workspace/skills/mcp-tool-utils/` | MCP Server Management |
| **reports-creator** | `~/.openclaw/workspace/skills/reports-creator/` | Automatische Berichte |
| **resource-manager** | `~/.openclaw/workspace/skills/resource-manager/` | Ressourcen-Management |
| **scripting-utils** | `~/.openclaw/workspace/skills/scripting-utils/` | Multi-Lang Scripting |
| **tiktok-live-mon** | `~/.openclaw/workspace/skills/tiktok-live-mon/` | TikTok Live-Monitoring |
| **web-scraper** | `~/.openclaw/workspace/skills/web-scraper/` | Gezielte Web-Extraktion |
| **workspace-db** | `~/.openclaw/workspace/skills/workspace-db/` | Dokumentations-DB & Index |
| model-usage | `~/.openclaw/workspace/skills/model-usage/` | Modell-Nutzungsstatistiken |
| spotify-player | `~/.openclaw/workspace/skills/spotify-player/` | Spotify Steuerung |

### Globale Skills (npm)

| Skill | Pfad | Beschreibung |
|-------|------|--------------|
| github | `~/.npm-global/lib/node_modules/openclaw/skills/github/` | GitHub Integration |
| taskflow | `~/.npm-global/lib/node_modules/openclaw/skills/taskflow/` | Task-Management |
| session-logs | `~/.npm-global/lib/node_modules/openclaw/skills/session-logs/` | Log-Analyse |
| gh-issues | `~/.npm-global/lib/node_modules/openclaw/skills/gh-issues/` | GitHub Issues |

---

## 🔍 Skill-Finder (für Agenten)

### Automatische Discovery

Jeder Agent SOLLTE beim Start folgende Pfade prüfen:

```bash
# 1. Lokale Skills (höchste Priorität)
ls -la ~/.openclaw/skills/*/SKILL.md 2>/dev/null

# 2. Workspace Skills
ls -la ~/.openclaw/workspace/skills/*/SKILL.md 2>/dev/null

# 3. Globale Skills
ls -la ~/.npm-global/lib/node_modules/openclaw/skills/*/SKILL.md 2>/dev/null

# 4. Diesen Index lesen
cat ~/.openclaw/SKILL-INDEX.md
```

### Manuelle Skill-Suche

Wenn ein Skill nicht gefunden wird:

```bash
# Skill-Name in Skill-Index suchen
grep -i "skill-name" ~/.openclaw/SKILL-INDEX.md

# Oder im Dateisystem suchen
find ~/.openclaw ~/.npm-global -name "SKILL.md" 2>/dev/null | xargs grep -l "skill-name"
```

---

## 🎛️ OPS-HUB Spezial

**Wichtig für alle Agenten:**

Der **ops-hub** ist der zentrale Koordinationspunkt. Alle Agenten müssen:

1. **Dokumentation lesen:** `~/.openclaw/skills/ops-hub/SKILL.md`
2. **Workspace kennen:** `~/.openclaw/workspace/docs/ops-hub/`
3. **Arbeitsfortschritt melden:** In `docs/ops-hub/agent-log.md`
4. **Status prüfen:** `docs/ops-hub/status.md`

### Schnellzugriff

| Ressource | Pfad |
|-----------|------|
| Skill-Doku | `~/.openclaw/skills/ops-hub/SKILL.md` |
| Workspace | `~/.openclaw/workspace/docs/ops-hub/README.md` |
| Aufgaben | `~/.openclaw/workspace/docs/ops-hub/tasks.md` |
| Redundanz | `OPS-HUB-*.md` Dateien im Root |

---

## 📝 Pflichten für Agenten

### Beim Start:
- [ ] SKILL-INDEX.md lesen
- [ ] Verfügbare Skills identifizieren
- [ ] Bei Unklarheiten: ops-hub konsultieren

### Bei Unbekannten Anfragen:
- [ ] NICHT wild Verzeichnisse erstellen
- [ ] Skill-Index prüfen
- [ ] Ops-hub dokumentation lesen
- [ ] Bei Bedarf: User um Klärung bitten

### Arbeitsfortschritt:
- [ ] In `docs/ops-hub/agent-log.md` eintragen
- [ ] Bei Delegation: `docs/ops-hub/delegation.md` aktualisieren

---

## 🆘 Problem: "Ich kenne ops-hub nicht"

**Wenn ein Agent das sagt:**

1. **Skill vorhanden?**
   ```bash
   ls ~/.openclaw/skills/ops-hub/SKILL.md
   ```

2. **Index vorhanden?**
   ```bash
   ls ~/.openclaw/SKILL-INDEX.md
   ```

3. **Workspace vorhanden?**
   ```bash
   ls ~/.openclaw/workspace/docs/ops-hub/
   ```

4. **Falls nein:** User informieren dass Setup fehlt

---

## 🔄 Aktualisierung

Dieser Index wird aktualisiert bei:
- Neuen Skills
- Skill-Updates
- Strukturänderungen

**Verantwortlich:** ops-hub Agent

---

**Erstellt:** 2026-04-17  
**Version:** 1.0.0  
**Nächste Überprüfung:** Bei neuen Skills