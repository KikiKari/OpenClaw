---
name: cluster-management
description: Generic cluster topology and resource management for OpenClaw deployments. Visual network diagrams, service matrices, port management, domain mapping, worker delegation, and cron job scheduling. Templates for multi-node setups with Tailscale + WireGuard VPN abstraction.
---

# Cluster Management

Generic cluster topology and resource management for OpenClaw deployments.

## Templates

### Visual Topology Template

```
                               INTERNET
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
              [Gateway]      [Relay]      [Webhosting]
                 Node 1      Node 2         Node 4
              10.10.0.1    10.10.0.2      [Public]
                  │             │
                  └──────┬──────┘
                         │
                    [Worker Nodes]
                         │
                    [Mobile Clients]
                         10.10.0.5
```

### Service Matrix Template

| Node | Service | Port | Protocol | Purpose |
|------|---------|------|----------|---------|
| Gateway | OpenClaw | 18789 | TCP | Node Management |
| Gateway | WireGuard | 51820 | UDP | VPN Hub |
| Gateway | Tailscale | 41641 | UDP | Mesh Network |
| Relay | SSH Tunnel | 22 | TCP | Fallback/Management |
| Webhosting | HTTPS | 443 | TCP | Public Services |

### Domain Mapping Template

| Domain | Target | Purpose |
|--------|--------|---------|
| example.com | Gateway/LB | Main Entry |
| *.internal | VPN Only | Private Services |
| status.example.com | Monitoring | Health Checks |

## Sub-Agent & Worker Delegation

Based on: `tools/SUB-AGENTS-WORKERS.md` (Master in workspace/tools/)

### Sub-Agent Types

| Agent | Purpose | Language |
|-------|---------|----------|
| **coding-agent** | Feature development, Code review | Multi |
| **claude-code** | Anthropic native | Python |
| **codex** | OpenAI native | Multi |
| **documentation** | Index updates, Changelogs | Multi |
| **monitoring** | Heartbeat, Status, Alerts | Multi |

### Delegation Patterns

```bash
# Long-running Tasks -> Sub-Agent
sessions_spawn --agent <type> --task "<description>"

# Browser Automation -> Worker Nodes
openclaw nodes run <node-id> -- node <script>.js

# Documentation Updates -> Scheduled Worker
# Cron: 0 */6 * * *

# Parallel Processing -> Multiple Nodes
openclaw nodes run node2 -- <task1> &
openclaw nodes run node3 -- <task2> &
```

### Worker Distribution Logic

| Task Type | Best Node | Reason |
|-----------|-----------|--------|
| Playwright/Browser | Node 2, 3 | Less main load |
| Documentation | Any available | CPU-light |
| API calls | Node 1 (Gateway) | Direct connection |
| File processing | Node with storage | Disk I/O |
| Geo-distributed | Closest node | Latency |

## Resource Management

Based on: `tools/SYSTEM.md` (Master in workspace/tools/)

### Node Roles Template

| Role | Responsibilities | Examples |
|------|------------------|----------|
| **Gateway** | Main coordination, Sub-Agent spawn, Session mgmt | Node 1 |
| **Relay** | Forwarding, Proxy, NAT traversal | Node 2 |
| **Worker** | Task execution, Compute, Playwright | Node 3, 5 |
| **Storage** | Databases, File hosting, Web | Node 4 |

### Cron Job Categories

| Category | Frequency | Examples |
|----------|-----------|----------|
| **Live Monitoring** | 20/45 min | TikTok, Streams |
| **System Health** | 3h | Disk, Memory, Network |
| **Daily Maintenance** | 06-08h | Cleanup, Security, Memory |
| **Communications** | hourly | Email, Notifications |

### Model Fallback Chain

```
Primary Model
├── Fallback 1 (Claude/Sonnet)
├── Fallback 2 (DeepSeek)
├── Fallback 3 (Llama)
└── Emergency (OpenRouter/auto)
```

## Configuration Templates

### openclaw.json Template

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/moonshotai/kimi-k2.5",
        "fallbacks": [
          "openrouter/anthropic/claude-3.5-sonnet",
          "openrouter/deepseek/deepseek-v3",
          "openrouter/meta-llama/llama-3.3-70b"
        ]
      }
    }
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "bind": "lan"
  }
}
```

### Cron Jobs Template

```json
{
  "jobs": {
    "live-check": {
      "schedule": "*/20 * * * *",
      "command": "node check-live.js"
    },
    "health-check": {
      "schedule": "0 */3 * * *",
      "command": "bin/health.sh"
    }
  }
}
```

## Usage

```bash
# Generate topology for current setup
openclaw cluster topology generate --format markdown

# Service matrix with port checks
openclaw cluster services matrix --validate

# Delegate task to best available worker
openclaw cluster delegate --task "browser-check" --type playwrighth

# Spawn documentation sub-agent
openclaw cluster spawn-doc-agent --schedule "0 */6 * * *"

# List available workers
openclaw cluster workers list

# Check resource usage across nodes
openclaw cluster resources status
```

## References

- **Concrete Examples:** `tools/SUB-AGENTS-WORKERS.md`
- **System Details:** `tools/SYSTEM.md`
- **Infrastructure:** `INFRASTRUCTURE.md`

## Integration

```python
from scripting_utils.system_manager import SystemManager
from scripting_utils.language_validator import LanguageValidator

# Validate deployment scripts
validator = LanguageValidator("bash")
result = validator.validate("deploy.sh")

# Generate service matrix for OS
manager = SystemManager("ubuntu")
commands = manager.get_commands(["install", "service_start"])
```
