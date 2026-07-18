# sub-agents-utils Skill

**Name:** sub-agents-utils  
**Beschreibung:** Tools für das Spawnen und Verwalten von Sub-Agents  
**Version:** 1.0.0  
**Emoji:** 👥  

## Schnellreferenz: Sub-Agents Spawnen

### Via Tool (sessions_spawn)
```python
# In Python-Code
result = sessions_spawn(
    task="Analyze logs for errors",
    label="log-analyzer",
    model="openrouter/moonshotai/kimi-k3"
)
```

### Via Slash Command
```
/subagents spawn my-agent "Task description" --model openai/gpt-5.4-mini
```

## Verfügbare Scripts

| Script | Funktion |
|--------|----------|
| `spawn_agent.py` | Sub-Agent mit Konfiguration spawnen |
| `list_agents.py` | Aktive Sub-Agents auflisten |
| `agent_monitor.py` | Überwacht Sub-Agent Status |
| `kill_agent.py` | Sub-Agent stoppen |

## Sub-Agent Konfiguration

### Minimale Konfiguration
```json
{
  "task": "Beschreibung der Aufgabe",
  "label": "optional-label"
}
```

### Vollständige Konfiguration
```json
{
  "task": "Aufgabenbeschreibung",
  "label": "mein-agent",
  "agentId": "optional-agent-id",
  "model": "openrouter/moonshotai/kimi-k3",
  "thinking": "high",
  "runTimeoutSeconds": 900,
  "thread": false,
  "mode": "run",
  "cleanup": "keep",
  "sandbox": "inherit"
}
```

## Wichtige Parameter

| Parameter | Werte | Beschreibung |
|-----------|-------|--------------|
| `mode` | `run`, `session` | Einmalig oder persistent |
| `thread` | `true`, `false` | Thread-Binding (Discord) |
| `cleanup` | `delete`, `keep` | Nach Abschluss löschen |
| `sandbox` | `inherit`, `require` | Sandbox-Anforderung |

## Nesting Tiefe

- **Standard:** `maxSpawnDepth: 1` (Keine Sub-Sub-Agents)
- **Orchestrator:** `maxSpawnDepth: 2` (Main → Orchestrator → Worker)

## Tools für Sub-Agents

Standardmäßig KEINE Session-Tools:
- `sessions_list`
- `sessions_history`
- `sessions_send`
- `sessions_spawn`

Bei `maxSpawnDepth >= 2` erhält der Orchestrator diese Tools.

## Beispiele

### Einfacher Task
```bash
python3 .../spawn_agent.py --task "Summarize yesterday's logs"
```

### Mit Modell-Auswahl
```bash
python3 .../spawn_agent.py \
  --task "Code review" \
  --model openrouter/anthropic/claude-haiku-4.5 \
  --timeout 1800
```

### Bulk-Spawn
```bash
python3 .../batch_spawn.py --file tasks.json
```
