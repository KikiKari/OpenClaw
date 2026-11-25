#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f9c1132209fc49ff5763c838b9460489a91e485f5e91ffbb4d24c922d011a24c", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "ruby"}
# test_node3.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
# auch in: OpenClaw@gateway2:scripts/test_node3.sh
# auch in: workspace@local:scripts/test_node3.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Test Node 3 Connection
ENV['OPENCLAW_ALLOW_INSECURE_PRIVATE_WS'] = '1'
puts "Starting node connection test..."
result = system("timeout 15 /usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789")
puts "Exit code: #{$?.exitstatus}"
