#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7df34734b4653aa8c624cf868741343768f326667ff6cdcb8f4046208f163381", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "python"}
# setup-secret-write.sh — portiert nach python
# Quelle: shell, workspace@local:scripts/setup-secret-write.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import yaml

# Source environment variables
env_file = "/home/openclaw/.config/openclaw/env"
if os.path.exists(env_file):
    with open(env_file) as f:
        for line in f:
            if line.strip() and not line.startswith("#"):
                key, value = line.strip().split("=", 1)
                os.environ[key] = value

SECRETS_DIR = "/secret-store"
YAML_FILE = "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

# Create secrets directory
subprocess.run(["sudo", "mkdir", "-p", SECRETS_DIR], check=True)
subprocess.run(["sudo", "chmod", "750", SECRETS_DIR], check=True)
subprocess.run(["sudo", "chown", "openclaw:openclaw", SECRETS_DIR], check=True)

# Write default-model.json
default_model_content = {
    "provider": "openrouter",
    "token": os.environ["OPENROUTER_API_KEY"]
}
with open("/tmp/default-model.json", "w") as f:
    yaml.dump(default_model_content, f, default_flow_style=False)
subprocess.run(["sudo", "mv", "/tmp/default-model.json", f"{SECRETS_DIR}/default-model.json"], check=True)

# Write proxy-model.json
proxy_model_content = {
    "provider": "openai",
    "token": os.environ["OPENAI_API_KEY"]
}
with open("/tmp/proxy-model.json", "w") as f:
    yaml.dump(proxy_model_content, f, default_flow_style=False)
subprocess.run(["sudo", "mv", "/tmp/proxy-model.json", f"{SECRETS_DIR}/proxy-model.json"], check=True)

# Set permissions
subprocess.run(["sudo", "chmod", "600", f"{SECRETS_DIR}/default-model.json", f"{SECRETS_DIR}/proxy-model.json"], check=True)

# YAML content
yaml_content = {
    "pools": [
        {
            "name": "pool_default",
            "id": "default",
            "model": "openrouter/moonshotai/kimi-k3",
            "weight": 0.8,
            "secretsPath": "/secret-store/default-model.json"
        },
        {
            "name": "pool_proxy",
            "id": "proxy",
            "model": "openrouter/auto",
            "weight": 0.2,
            "secretsPath": "/secret-store/proxy-model.json"
        }
    ],
    "routing": [
        {
            "name": "latency_and_error_based",
            "criteria": [
                {"latency_ms": "< 200"},
                {"error_rate_pct": "< 1"}
            ],
            "route_to": "pool_default"
        },
        {
            "name": "fallback_if_issues",
            "criteria": [
                {"latency_ms": ">= 200"},
                {"error_rate_pct": ">= 1"}
            ],
            "route_to": "pool_proxy"
        }
    ],
    "fallbacks": [
        {"model": "openrouter/moonshotai/kimi-k3"},
        {"model": "openai/gpt-5.6-luna"}
    ],
    "logging": {
        "events": {
            "request_decisions": True,
            "memory_store_path": "/memory/logs/model-routing.log"
        },
        "retention_days": 14
    },
    "security": {
        "secrets_encryption": True,
        "access_control": [
            {
                "role": "model-operator",
                "allow": ["read", "write"]
            },
            {
                "role": "monitor",
                "allow": ["read"]
            }
        ]
    }
}

# Write YAML file
os.makedirs(os.path.dirname(YAML_FILE), exist_ok=True)
with open(YAML_FILE, "w") as f:
    yaml.dump(yaml_content, f, default_flow_style=False, indent=2, allow_unicode=True)

print("=== ERLEDIGT ===")
print("Secrets:")
subprocess.run(["sudo", "ls", "-la", f"{SECRETS_DIR}/"])
print()
print(f"YAML: {YAML_FILE}")
subprocess.run(["ls", "-la", YAML_FILE])
