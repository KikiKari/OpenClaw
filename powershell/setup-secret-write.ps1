#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e6fe17f853d6fb64a25d6bfc59745610fd68240d265e463512bc65ae307f64df", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "powershell"}
# setup-secret-write.sh — portiert nach powershell
# Quelle: shell, workspace@local:scripts/setup-secret-write.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "/home/openclaw/.config/openclaw/env"

$SECRETS_DIR = "/secret-store"
$YAML = "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

New-Item -ItemType Directory -Path $SECRETS_DIR -Force | Out-Null
chmod 750 "$SECRETS_DIR"
chown openclaw:openclaw "$SECRETS_DIR"

@"
{ "provider": "openrouter", "token": "$env:OPENROUTER_API_KEY" }
"@ | sudo tee "$SECRETS_DIR/default-model.json" > $null

@"
{ "provider": "openai", "token": "$env:OPENAI_API_KEY" }
"@ | sudo tee "$SECRETS_DIR/proxy-model.json" > $null

chmod 600 "$SECRETS_DIR/default-model.json" "$SECRETS_DIR/proxy-model.json"

@'
pools:
  - name: pool_default
    id: default
    model: openrouter/moonshotai/kimi-k3
    weight: 0.8
    secretsPath: /secret-store/default-model.json

  - name: pool_proxy
    id: proxy
    model: openrouter/auto
    weight: 0.2
    secretsPath: /secret-store/proxy-model.json

routing:
  - name: latency_and_error_based
    criteria:
      - latency_ms: "< 200"
      - error_rate_pct: "< 1"
    route_to: pool_default
  - name: fallback_if_issues
    criteria:
      - latency_ms: ">= 200"
      - error_rate_pct: ">= 1"
    route_to: pool_proxy

fallbacks:
  - model: openrouter/moonshotai/kimi-k3
  - model: openai/gpt-5.6-luna

logging:
  events:
    request_decisions: true
    memory_store_path: /memory/logs/model-routing.log
  retention_days: 14

security:
  secrets_encryption: true
  access_control:
    - role: model-operator
      allow: [read, write]
    - role: monitor
      allow: [read]
'@ | Set-Content -Path $YAML

Write-Output "=== ERLEDIGT ==="
Write-Output "Secrets:"
sudo ls -la "$SECRETS_DIR/"
Write-Output ""
Write-Output "YAML: $YAML"
ls -la "$YAML"
