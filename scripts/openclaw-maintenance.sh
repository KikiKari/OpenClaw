#!/usr/bin/env bash

# === 1. Service-/Config-Drift ===
openclaw doctor

# === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
openclaw plugins registry --refresh
openclaw plugins update --all

# === 3. Tasks ===
openclaw tasks maintenance --apply

# === 4. Sessions – alle Agents auf einmal ===
openclaw sessions cleanup --enforce --all-agents

# === 5. Memory – status/index decken alle Agents ab ===
openclaw memory status --deep --fix
openclaw memory index --force

# === 6. Memory promote – MUSS pro Agent ===
for AGENT in main knecht docs ops-hub cron; do
  openclaw memory promote --apply --agent "$AGENT"
done

# === 7. Secrets ===
openclaw secrets reload
