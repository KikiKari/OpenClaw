#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "451d5c7d33642957d4fb0882e06eba0355bfd3f463c9d07aa2f049bbb9f12022", "source_sha256": "4683de03d118212741f1ba6fc6f25ee1cfaf247a9d136a0a5b33152bb39ce5a5", "target_language": "python"}
# ci-node-test-plan.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/ci-node-test-plan.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

from typing import List, Dict, Any, Set
from pathlib import Path

# Import the fullSuiteVitestShards
import sys
sys.path.append(str(Path(__file__).resolve().parent.parent / "test" / "vitest"))
from vitest_test_shards import fullSuiteVitestShards

EXCLUDED_FULL_SUITE_SHARDS: Set[str] = {
    "test/vitest/vitest.full-core-contracts.config.ts",
    "test/vitest/vitest.full-core-bundled.config.ts",
    "test/vitest/vitest.full-extensions.config.ts",
}

EXCLUDED_PROJECT_CONFIGS: Set[str] = {"test/vitest/vitest.channels.config.ts"}

def format_node_test_shard_check_name(shard_name: str) -> str:
    """
    Format the check name for a node test shard.
    """
    if shard_name.startswith("core-unit-"):
        normalized_shard_name = f"core-{shard_name[len('core-unit-'):]}"
    else:
        normalized_shard_name = shard_name
    return f"checks-node-{normalized_shard_name}"

def create_node_test_shards() -> List[Dict[str, Any]]:
    """
    Create node test shards configuration.
    """
    result = []
    
    for shard in fullSuiteVitestShards:
        if shard["config"] in EXCLUDED_FULL_SUITE_SHARDS:
            continue
            
        configs = [config for config in shard["projects"] if config not in EXCLUDED_PROJECT_CONFIGS]
        if not configs:
            continue
            
        result.append({
            "checkName": format_node_test_shard_check_name(shard["name"]),
            "shardName": shard["name"],
            "configs": configs,
        })
        
    return result
