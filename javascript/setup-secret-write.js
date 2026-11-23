#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "ec97a29d9da9527d72243824b9befc8f87847c6e07cea2ef3112f5c684fad223", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "javascript"}
// setup-secret-write.sh — portiert nach javascript
// Quelle: shell, workspace@local:scripts/setup-secret-write.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Source environment variables
const envPath = '/home/openclaw/.config/openclaw/env';
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  const envLines = envContent.split('\n');
  for (const line of envLines) {
    if (line.trim() && !line.startsWith('#')) {
      const [key, ...valueParts] = line.split('=');
      const value = valueParts.join('=').replace(/^["']|["']$/g, '');
      process.env[key.trim()] = value.trim();
    }
  }
}

const SECRETS_DIR = "/secret-store";
const YAML = "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml";

// Create secrets directory with appropriate permissions
execSync(`mkdir -p "${SECRETS_DIR}"`, { stdio: 'inherit' });
execSync(`chmod 750 "${SECRETS_DIR}"`, { stdio: 'inherit' });
execSync(`chown ${process.env.USER || 'openclaw'}:${process.env.USER || 'openclaw'} "${SECRETS_DIR}"`, { stdio: 'inherit' });

// Write default-model.json
const defaultModelContent = JSON.stringify({
  provider: "openrouter",
  token: process.env.OPENROUTER_API_KEY
}, null, 2);

fs.writeFileSync(path.join(SECRETS_DIR, "default-model.json"), defaultModelContent);
execSync(`chmod 600 "${path.join(SECRETS_DIR, "default-model.json")}"`, { stdio: 'inherit' });

// Write proxy-model.json
const proxyModelContent = JSON.stringify({
  provider: "openai",
  token: process.env.OPENAI_API_KEY
}, null, 2);

fs.writeFileSync(path.join(SECRETS_DIR, "proxy-model.json"), proxyModelContent);
execSync(`chmod 600 "${path.join(SECRETS_DIR, "proxy-model.json")}"`, { stdio: 'inherit' });

// YAML content
const yamlContent = `pools:
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
`;

// Write YAML file
fs.writeFileSync(YAML, yamlContent);

console.log("=== ERLEDIGT ===");
console.log("Secrets:");
execSync(`ls -la "${SECRETS_DIR}/"`, { stdio: 'inherit' });
console.log("");
console.log(`YAML: ${YAML}`);
execSync(`ls -la "${YAML}"`, { stdio: 'inherit' });
