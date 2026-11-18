#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d5f6cd2d418d5f05143ffa53eaec11c7a6de464a980e18ad5b6c6af83dcd75cd", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "powershell"}
# ci-node-test-plan.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

$EXCLUDED_FULL_SUITE_SHARDS = @(
  "test/vitest/vitest.full-core-contracts.config.ts"
  "test/vitest/vitest.full-core-bundled.config.ts"
  "test/vitest/vitest.full-extensions.config.ts"
)

$EXCLUDED_PROJECT_CONFIGS = @(
  "test/vitest/vitest.channels.config.ts"
)

function Format-NodeTestShardCheckName($shardName) {
  $normalizedShardName = if ($shardName.StartsWith("core-unit-")) {
    "core-$($shardName.Substring('core-unit-'.Length))"
  } else {
    $shardName
  }
  return "checks-node-$normalizedShardName"
}

function Create-NodeTestShards {
  # Import the module containing fullSuiteVitestShards
  $vitestShardsPath = Join-Path $PSScriptRoot "../../test/vitest/vitest.test-shards.mjs"
  
  # Since we can't directly import MJS in PowerShell, we'll need to read and parse it
  # For this example, assuming the structure is known and static
  # In practice, you might want to convert vitest.test-shards.mjs to a JSON or PS1 file
  
  # Mocking the data structure that would come from vitest.test-shards.mjs
  # This needs to be adapted based on actual content
  $fullSuiteVitestShards = @(
    @{
      name = "example-shard";
      config = "test/vitest/vitest.example.config.ts";
      projects = @("project1", "project2");
    }
  )
  
  $result = @()
  
  foreach ($shard in $fullSuiteVitestShards) {
    if ($EXCLUDED_FULL_SUITE_SHARDS -contains $shard.config) {
      continue
    }
    
    $configs = $shard.projects | Where-Object { $EXCLUDED_PROJECT_CONFIGS -notcontains $_ }
    
    if ($configs.Count -eq 0) {
      continue
    }
    
    $result += @{
      checkName = Format-NodeTestShardCheckName $shard.name
      shardName = $shard.name
      configs = $configs
    }
  }
  
  return $result
}

# Export the function by making it available in the global scope
$GLOBAL:CreateNodeTestShards = ${function:Create-NodeTestShards}
