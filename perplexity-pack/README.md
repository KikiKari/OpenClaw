# Perplexity target Arbeitspaket - exakte source-Synchronisation

Dieses Paket ersetzt das vorherige Paket vollstaendig. Es enthaelt kein target-Installationsskript, keine automatische Ausfuehrung und keine Verbesserungslogik. Codex auf target soll die enthaltenen Artefakte lesen und die beschriebenen Schritte manuell/gezielt ausfuehren.

Ziel: Der Perplexity-Teil von target soll exakt denselben Zielzustand wie source erhalten, ohne host-spezifische Felder oder andere Konfigurationsbereiche zu veraendern.

## Paketinhalt

```text
perplexity-pack/
  README.md
  files/
    secrets.env
    env/
      dot-env.fragment
      workspace-dot-env.fragment
      gateway-systemd-env.fragment
    config/
      openclaw-perplexity-target.json
      openclaw-perplexity-jq-filter.txt
    skills/perplexity-pro-search/
    workspace/skills/perplexity-pro-search/
```

## Harte Regeln fuer target

1. Keine host-spezifischen Felder von source uebernehmen.
2. Nur diese `openclaw.json`-Pfade duerfen angepasst werden:
   - `tools.web.search`
   - `plugins.entries.perplexity`
   - `mcp.servers.perplexity`
   - `commands.mcp`
   - `skills.entries["perplexity-pro-search"]`
3. Keine `agents.defaults.skills` oder `agents.list[].skills` anlegen, ergaenzen oder entfernen. source hat diese Felder nicht. Falls target sie hat, zuerst stoppen und Rueckfrage halten, weil sonst keine 1:1-Synchronitaet zum source-Shape besteht.
4. Keine Keys im Chat, in Logs oder in Commits ausgeben.
5. `files/secrets.env` enthaelt den echten internen Perplexity-Key.
6. Nach jeder `openclaw.json`-Aenderung vorher das naechste freie Backup `openclaw.json.bak.N` erstellen.

## Zielwerte aus source

Die exakten Zielwerte stehen in:

```text
files/config/openclaw-perplexity-target.json
```

Erwarteter source-Shape fuer Agent-Skill-Allowlists:

```text
agents.defaults.skills: nicht vorhanden
agents.list[*].skills: nicht vorhanden
```

## Manuelle Umsetzung auf target

### 1. Entpacken

```bash
cd /home/openclaw/.openclaw/workspace
tar -xzf perplexity-pack.tar.gz
cd perplexity-pack
```

### 2. Vorpruefung

```bash
cd /home/openclaw/.openclaw
jq empty openclaw.json
jq '{
  defaults_has_skills: ((.agents.defaults? | type) == "object" and (.agents.defaults | has("skills"))),
  list_has_skills: [(.agents.list // [])[] | has("skills")]
}' openclaw.json
```

Wenn irgendein Wert fuer `defaults_has_skills` oder `list_has_skills[]` `true` ist: stoppen. Nicht automatisch korrigieren.

### 3. Perplexity-Key in die drei Env-Dateien uebernehmen

Den Wert aus `files/secrets.env` exakt in diese Dateien setzen oder aktualisieren:

```text
/home/openclaw/.openclaw/.env
/home/openclaw/.openclaw/workspace/.env
/home/openclaw/.openclaw/gateway.systemd.env
```

Dabei nur die Zeile `PERPLEXITY_API_KEY=...` anfassen. Andere Keys bleiben unveraendert.

### 4. openclaw.json sichern

```bash
cd /home/openclaw/.openclaw
# naechste freie Nummer selbst waehlen, keine Backups ueberschreiben
cp openclaw.json openclaw.json.bak.N
```

### 5. openclaw.json nur im Perplexity-Teil angleichen

Die Zielwerte stehen in:

```text
/home/openclaw/.openclaw/workspace/perplexity-pack/files/config/openclaw-perplexity-target.json
```

Der zu verwendende jq-Filter steht als Text in:

```text
/home/openclaw/.openclaw/workspace/perplexity-pack/files/config/openclaw-perplexity-jq-filter.txt
```

Er setzt ausschliesslich die fuenf erlaubten Pfade. Vor Anwendung den Filter lesen und pruefen.

### 6. Skill-Dateien exakt kopieren

```bash
cd /home/openclaw/.openclaw
mkdir -p skills workspace/skills
rm -rf skills/perplexity-pro-search workspace/skills/perplexity-pro-search
cp -a workspace/perplexity-pack/files/skills/perplexity-pro-search skills/perplexity-pro-search
cp -a workspace/perplexity-pack/files/workspace/skills/perplexity-pro-search workspace/skills/perplexity-pro-search
chmod +x skills/perplexity-pro-search/scripts/*.sh workspace/skills/perplexity-pro-search/scripts/*.sh
```

Diese beiden Zielorte sind absichtlich beide enthalten:

```text
/home/openclaw/.openclaw/skills/perplexity-pro-search
/home/openclaw/.openclaw/workspace/skills/perplexity-pro-search
```

### 7. Validieren

```bash
cd /home/openclaw/.openclaw
openclaw config validate
openclaw mcp show perplexity
set -a; . /home/openclaw/.openclaw/gateway.systemd.env; set +a
openclaw skills list --agent main --json | jq -r '.skills[] | select(.name=="perplexity-pro-search")'
```

Erwartung fuer den Skill:

```text
eligible: true
modelVisible: true
commandVisible: true
source: openclaw-managed
missing.env: []
missing.config: []
```

### 8. Direkte API-Tests

```bash
cd /home/openclaw/.openclaw
set -a; . /home/openclaw/.openclaw/gateway.systemd.env; set +a
skills/perplexity-pro-search/scripts/test-search.sh "Perplexity API Platform"
skills/perplexity-pro-search/scripts/test-agent.sh "Compare Perplexity Search API and Agent API briefly."
skills/perplexity-pro-search/scripts/test-embeddings.sh
skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
```

Erwartung: Alle vier Tests liefern HTTP 200.

### 9. Gateway neu laden

Erst nach erfolgreicher Validierung:

```bash
openclaw gateway restart
```

## Exakte source-Zielkonfiguration

Kurzform:

```json
{
  "tools.web.search": {
    "provider": "perplexity",
    "enabled": true,
    "openaiCodex": {}
  },
  "plugins.entries.perplexity": {
    "enabled": true,
    "config": {
      "webSearch": {}
    }
  },
  "mcp.servers.perplexity": {
    "command": "npx",
    "args": ["-y", "@perplexity-ai/mcp-server"]
  },
  "commands.mcp": true,
  "skills.entries.perplexity-pro-search": {
    "enabled": true
  }
}
```

## Sicherheit

- Dieses Paket enthaelt echte Secrets und ist nur fuer die interne Uebertragung source -> target gedacht.
- Keine Ausgabe von `files/secrets.env` im Chat.
- Keine Secrets in `openclaw.json` schreiben.
- Perplexity-Key nur als Environment-Variable in den drei genannten Env-Dateien setzen.
