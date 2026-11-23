#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "6718f9005c61c929bf1b90e4547cdcde4b4be9402a4ad7f69278f24ee414933d", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "tcl"}
# setup-secret-write.sh — portiert nach tcl
# Quelle: shell, workspace@local:scripts/setup-secret-write.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have a direct equivalent to bash's set -euo pipefail,
# but we can use error handling and strict variable checking.

# Source environment variables from file
if {[catch {source /home/openclaw/.config/openclaw/env}]} {
    puts stderr "Failed to source environment file"
    exit 1
}

set SECRETS_DIR "/secret-store"
set YAML "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

# Create directory with appropriate permissions
if {[catch {exec sudo mkdir -p $SECRETS_DIR} result]} {
    puts stderr "Failed to create directory: $result"
    exit 1
}

if {[catch {exec sudo chmod 750 $SECRETS_DIR} result]} {
    puts stderr "Failed to set directory permissions: $result"
    exit 1
}

if {[catch {exec sudo chown openclaw:openclaw $SECRETS_DIR} result]} {
    puts stderr "Failed to change directory ownership: $result"
    exit 1
}

# Write default-model.json
set default_content "{ \"provider\": \"openrouter\", \"token\": \"$::env(OPENROUTER_API_KEY)\" }"
if {[catch {set fd [open "|sudo tee $SECRETS_DIR/default-model.json" w]} result]} {
    puts stderr "Failed to open default-model.json for writing: $result"
    exit 1
}
puts $fd $default_content
close $fd

# Write proxy-model.json
set proxy_content "{ \"provider\": \"openai\", \"token\": \"$::env(OPENAI_API_KEY)\" }"
if {[catch {set fd [open "|sudo tee $SECRETS_DIR/proxy-model.json" w]} result]} {
    puts stderr "Failed to open proxy-model.json for writing: $result"
    exit 1
}
puts $fd $proxy_content
close $fd

# Set file permissions
if {[catch {exec sudo chmod 600 $SECRETS_DIR/default-model.json $SECRETS_DIR/proxy-model.json} result]} {
    puts stderr "Failed to set file permissions: $result"
    exit 1
}

# Write YAML content
set yaml_content {pools:
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
      allow: [read]}

if {[catch {set fd [open $YAML w]} result]} {
    puts stderr "Failed to open YAML file for writing: $result"
    exit 1
}
puts $fd $yaml_content
close $fd

puts "=== ERLEDIGT ==="
puts "Secrets:"
if {[catch {exec sudo ls -la $SECRETS_DIR/} result]} {
    puts stderr "Failed to list secrets directory: $result"
} else {
    puts $result
}

puts ""
puts "YAML: $YAML"
if {[catch {exec ls -la $YAML} result]} {
    puts stderr "Failed to list YAML file: $result"
} else {
    puts $result
}
