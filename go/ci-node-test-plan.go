// abstraction-provenance: {"artifact_sha256": "6732790997703db97d41f6b36d61325512f8d4848271a0849e9a497a98e8678b", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "go"}
// ci-node-test-plan.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"path/filepath"
	"strings"
)

type Shard struct {
	Name     string
	Config   string
	Projects []string
}

type NodeTestShard struct {
	CheckName  string
	ShardName  string
	Configs    []string
}

var fullSuiteVitestShards = []Shard{
	// This would need to be populated with the actual shard data
	// For now, including a sample structure
	{"core-unit-1", "test/vitest/vitest.core-unit-1.config.ts", []string{"test/vitest/vitest.core-unit-1.config.ts"}},
	{"core-unit-2", "test/vitest/vitest.core-unit-2.config.ts", []string{"test/vitest/vitest.core-unit-2.config.ts"}},
	{"full-core-contracts", "test/vitest/vitest.full-core-contracts.config.ts", []string{"test/vitest/vitest.full-core-contracts.config.ts"}},
	{"channels", "test/vitest/vitest.channels.config.ts", []string{"test/vitest/vitest.channels.config.ts"}},
}

var EXCLUDED_FULL_SUITE_SHARDS = map[string]bool{
	"test/vitest/vitest.full-core-contracts.config.ts":     true,
	"test/vitest/vitest.full-core-bundled.config.ts":       true,
	"test/vitest/vitest.full-extensions.config.ts":        true,
}

var EXCLUDED_PROJECT_CONFIGS = map[string]bool{
	"test/vitest/vitest.channels.config.ts": true,
}

func formatNodeTestShardCheckName(shardName string) string {
	normalizedShardName := shardName
	if strings.HasPrefix(shardName, "core-unit-") {
		normalizedShardName = "core-" + shardName[len("core-unit-"):]
	}
	return fmt.Sprintf("checks-node-%s", normalizedShardName)
}

func createNodeTestShards() []NodeTestShard {
	var result []NodeTestShard
	
	for _, shard := range fullSuiteVitestShards {
		if EXCLUDED_FULL_SUITE_SHARDS[shard.Config] {
			continue
		}
		
		var configs []string
		for _, config := range shard.Projects {
			if !EXCLUDED_PROJECT_CONFIGS[config] {
				configs = append(configs, config)
			}
		}
		
		if len(configs) == 0 {
			continue
		}
		
		result = append(result, NodeTestShard{
			CheckName: formatNodeTestShardCheckName(shard.Name),
			ShardName: shard.Name,
			Configs:   configs,
		})
	}
	
	return result
}

func main() {
	shards := createNodeTestShards()
	
	for _, shard := range shards {
		fmt.Printf("Check Name: %s\n", shard.CheckName)
		fmt.Printf("Shard Name: %s\n", shard.ShardName)
		fmt.Printf("Configs: %v\n\n", shard.Configs)
	}
}
