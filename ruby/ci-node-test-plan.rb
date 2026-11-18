#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a2efd16363e5526938da6fe5ad35500162ea6bbbca3b6a95cd5874b789a3ba4a", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "ruby"}
# ci-node-test-plan.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require_relative '../../test/vitest/vitest.test-shards.mjs'

EXCLUDED_FULL_SUITE_SHARDS = Set.new([
  'test/vitest/vitest.full-core-contracts.config.ts',
  'test/vitest/vitest.full-core-bundled.config.ts',
  'test/vitest/vitest.full-extensions.config.ts'
])

EXCLUDED_PROJECT_CONFIGS = Set.new(['test/vitest/vitest.channels.config.ts'])

def format_node_test_shard_check_name(shard_name)
  normalized_shard_name = shard_name.start_with?('core-unit-') ? 
    "core-#{shard_name['core-unit-'.length..-1]}" : 
    shard_name
  "checks-node-#{normalized_shard_name}"
end

def create_node_test_shards
  $full_suite_vitest_shards.flat_map do |shard|
    if EXCLUDED_FULL_SUITE_SHARDS.include?(shard[:config])
      next []
    end

    configs = shard[:projects].filter { |config| !EXCLUDED_PROJECT_CONFIGS.include?(config) }
    if configs.empty?
      next []
    end

    [{
      check_name: format_node_test_shard_check_name(shard[:name]),
      shard_name: shard[:name],
      configs: configs
    }]
  end
end
