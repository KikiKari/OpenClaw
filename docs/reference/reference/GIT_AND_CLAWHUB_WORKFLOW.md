# Git und ClawHub Workflow

**Version:** 1.0  
**Stand:** 2026-04-18  
**Autor:** OpenClaw Agent System

## Übersicht

Integrierter Workflow für Git-Versionierung und ClawHub-Veröffentlichung von Skills.

## Repository-Struktur

```
~/workspace/
├── git/                      ← Git Repository (legacy)
│   ├── .git/                ← Git internals
│   └── ...
│
└── NOW: Alles ist Skill-basiert
    └── skills/
        ├── workspace-db/    ← Eigenständiger Skill
        ├── db-maintainer/   ← Sub-Agent Skill
        └── ...
```

## Skill-zentrierte Entwicklung

### 1. Skill erstellen/lokal

```bash
# Skill-Verzeichnis erstellen
mkdir -p skills/mein-skill

# SKILL.md erstellen
# package.json erstellen
# scripts/ hinzufügen
```

### 2. Lokale Tests

```bash
# Skill testen
python3 skills/mein-skill/scripts/main.py

# Datenbanken prüfen
sqlite3 db/docs.db "SELECT * FROM skills WHERE name='mein-skill'"
```

### 3. Git-Commit (optional)

```bash
cd ~/.openclaw/workspace

# Änderungen prüfen
git status

# Skill-Dateien hinzufüfen
git add skills/mein-skill/

# Commit
git commit -m "[skill] mein-skill v1.0.0 - Beschreibung"
```

### 4. ClawHub-Veröffentlichung

```bash
# Skill veröffentlichen
clawhub publish skills/mein-skill \
  --slug mein-skill \
  --name "Mein Skill" \
  --version 1.0.0 \
  --tags "tag1,tag2,tag3"

# Oder: Automatisch via git-publish-agent
python3 skills/git-publish-agent/scripts/git_publish.py --skill mein-skill
```

### 5. Installation auf anderen Nodes

```bash
# Auf beliebigem Node
clawhub install mein-skill
```

## Automatisierung mit git-publish-agent

### Konfiguration

```json
{
  "git-publish-agent": {
    "enabled": true,
    "auto_commit": true,
    "auto_publish": false,
    "commit_prefix": "[skill]",
    "batch_delay_minutes": 15
  }
}
```

### Workflows

#### A) Einzelner Skill veröffentlichen

```bash
openclaw git-publish --skill workspace-db
```

#### B) Alle geänderten Skills

```bash
openclaw git-publish --all
```

#### C) Nur commit, nicht veröffentlichen

```bash
openclaw git-publish --skill mein-skill --no-publish
```

## Versions-Management

### Semantische Versionierung

| Version | Bedeutung | Beispiel |
|---------|-----------|----------|
| **1.0.0** | Erste stabile Version | Neue Skill-Erstellung |
| **1.1.0** | Neue Features | Zusätzliche Export-Formate |
| **1.1.1** | Bugfixes | Korrektur in Script |
| **2.0.0** | Breaking Changes | API-Änderung |

### In package.json

```json
{
  "name": "mein-skill",
  "version": "1.2.3",
  "description": "..."
}
```

## Integration mit docs.db

### Skills in Datenbank tracken

```sql
-- Alle veröffentlichten Skills
SELECT name, version, status, description
FROM skills
WHERE status = 'published';

-- Lokale vs. Veröffentlichte Skills
SELECT status, COUNT(*) as count
FROM skills
GROUP BY status;
```

### Automatische Skill-Erkennung

```python
# update_skills_db.py scannt skills/ Verzeichnis
for skill_dir in Path('skills/').iterdir():
    if (skill_dir / 'SKILL.md').exists():
        # Parse SKILL.md
        # Update docs.db
        pass
```

## Best Practices

### 1. Skill-Entwicklung

- Immer SKILL.md als erstes erstellen
- package.json mit korrekter Version
- Scripts in `scripts/` Unterverzeichnis
- Export-Funktionen bereitstellen

### 2. Versionierung

- **Ein Skill = Ein Git-Commit** (ideal)
- Commit-Message: `[skill] name vX.Y.Z - Beschreibung`
- Keine gemischten Commits (Skill A + Skill B)

### 3. Dokumentation

- README.md für öffentliche Skills
- docs/reference/ für interne Dokumente
- CHANGELOG.md für Versionshistorie

### 4. Testing

- Vor Veröffentlichung: Lokal testen
- Nach Installation: Auf Ziel-Node testen
- Multi-Node: Auf allen Ziel-Nodes installieren

## Troubleshooting

### Problem: Skill lässt sich nicht veröffentlichen

```bash
# Lösung: Metadaten prüfen
cat skills/mein-skill/SKILL.md
cat skills/mein-skill/package.json

# Fehlende Felder ergänzen
```

### Problem: ClawHub Installation fehlschlägt

```bash
# Lösung: Version prüfen
clawhub search mein-skill

# Alternative: Lokale Installation
clawhub install --local skills/mein-skill/
```

### Problem: Git-Konflikte

```bash
# Lösung: Rebase statt Merge
git pull --rebase

# Skill-Dateien sind meist konfliktfrei (isoliert)
```

## Zukunftsausblick

### Geplante Features

- [ ] Automatische Versions-Bump bei Änderungen
- [ ] CI/CD Integration für Skills
- [ ] Skill-Abhängigkeiten (Skill A benötigt Skill B)
- [ ] Skill-Marketplace UI

## Links

- [DATABASE_AND_TREE_TRACKING.md](DATABASE_AND_TREE_TRACKING.md)
- [SKILL-INDEX.md](../../SKILL-INDEX.md)
- [ClawHub Portal](https://clawhub.com)
