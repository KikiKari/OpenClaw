#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4da3906733727ef8991bca6b0ebe1bdecc3329682ce7a879f0938be6699d7c63", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "lua"}
-- ci-node-test-plan.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local fullSuiteVitestShards = require("../../test/vitest/vitest.test-shards.mjs")

local EXCLUDED_FULL_SUITE_SHARDS = {
  ["test/vitest/vitest.full-core-contracts.config.ts"] = true,
  ["test/vitest/vitest.full-core-bundled.config.ts"] = true,
  ["test/vitest/vitest.full-extensions.config.ts"] = true,
}

local EXCLUDED_PROJECT_CONFIGS = {
  ["test/vitest/vitest.channels.config.ts"] = true,
}

local function formatNodeTestShardCheckName(shardName)
  local normalizedShardName = shardName
  if string.sub(shardName, 1, #"core-unit-") == "core-unit-" then
    normalizedShardName = "core-" .. string.sub(shardName, #"core-unit-" + 1)
  end
  return "checks-node-" .. normalizedShardName
end

local function createNodeTestShards()
  local result = {}
  for _, shard in ipairs(fullSuiteVitestShards) do
    if not EXCLUDED_FULL_SUITE_SHARDS[shard.config] then
      local configs = {}
      for _, config in ipairs(shard.projects) do
        if not EXCLUDED_PROJECT_CONFIGS[config] then
          table.insert(configs, config)
        end
      end
      if #configs > 0 then
        table.insert(result, {
          checkName = formatNodeTestShardCheckName(shard.name),
          shardName = shard.name,
          configs = configs,
        })
      end
    end
  end
  return result
end

return {
  createNodeTestShards = createNodeTestShards,
}
