#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "abaec63d65e700ba2991356df27b337c4861e8dd9dc24aea1a9d45ecf58fa4dd", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "python"}
# extension-test-plan.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

# Import helper modules
sys.path.append(str(Path(__file__).parent))
from bundled_plugin_paths import BUNDLED_PLUGIN_PATH_PREFIX, BUNDLED_PLUGIN_ROOT_DIR
from changed_extensions import list_available_extension_ids

repo_root = Path(__file__).resolve().parent.parent
DEFAULT_EXTENSION_TEST_SHARD_COUNT = 6


def normalize_relative(input_path: str) -> str:
    """Normalize path separators to forward slashes"""
    return input_path.replace(os.sep, "/")


def count_test_files(root_path: Path) -> int:
    """Count test files recursively in a directory"""
    total = 0
    stack = [root_path]
    
    while stack:
        current = stack.pop()
        if not current.exists():
            continue
            
        try:
            for entry in current.iterdir():
                if entry.is_dir():
                    if entry.name in ("node_modules", "dist"):
                        continue
                    stack.append(entry)
                    continue
                if entry.is_file() and (entry.name.endswith(".test.ts") or entry.name.endswith(".test.tsx")):
                    total += 1
        except PermissionError:
            continue
            
    return total


def resolve_extension_directory(target_arg: Optional[str], cwd: Path = None) -> Path:
    """Resolve the extension directory from target argument or current directory"""
    if cwd is None:
        cwd = Path.cwd()
        
    if target_arg:
        # Try as given path
        as_given = (cwd / target_arg).resolve()
        if (as_given / "package.json").exists():
            return as_given
            
        # Try by name in bundled plugins
        by_name = repo_root / BUNDLED_PLUGIN_ROOT_DIR / target_arg
        if (by_name / "package.json").exists():
            return by_name
            
        raise ValueError(
            f'Unknown extension target "{target_arg}". Use a plugin name like "slack" or a path inside the bundled plugin workspace tree.'
        )
        
    # Walk up from current directory to find extension
    current = cwd.resolve()
    while True:
        rel_path = normalize_relative(str(current.relative_to(repo_root)))
        if rel_path.startswith(BUNDLED_PLUGIN_PATH_PREFIX) and (current / "package.json").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
        
    raise ValueError(
        "No extension target provided, and current working directory is not inside the bundled plugin workspace tree."
    )


def resolve_extension_test_plan(params: Dict[str, Any] = None) -> Dict[str, Any]:
    """Resolve test plan for an extension"""
    if params is None:
        params = {}
        
    cwd = Path(params.get("cwd", Path.cwd()))
    target_arg = params.get("targetArg")
    
    extension_dir = resolve_extension_directory(target_arg, cwd)
    extension_id = extension_dir.name
    relative_extension_dir = normalize_relative(str(extension_dir.relative_to(repo_root)))
    
    roots = [relative_extension_dir]
    
    # Import path checking functions
    from vitest_channel_paths import channel_test_roots
    from vitest_extension_acpx_paths import is_acpx_extension_root
    from vitest_extension_bluebubbles_paths import is_blue_bubbles_extension_root
    from vitest_extension_diffs_paths import is_diffs_extension_root
    from vitest_extension_feishu_paths import is_feishu_extension_root
    from vitest_extension_irc_paths import is_irc_extension_root
    from vitest_extension_matrix_paths import is_matrix_extension_root
    from vitest_extension_mattermost_paths import is_mattermost_extension_root
    from vitest_extension_memory_paths import is_memory_extension_root
    from vitest_extension_messaging_paths import is_messaging_extension_root
    from vitest_extension_msteams_paths import is_ms_teams_extension_root
    from vitest_extension_provider_paths import is_provider_extension_root
    from vitest_extension_telegram_paths import is_telegram_extension_root
    from vitest_extension_voice_call_paths import is_voice_call_extension_root
    from vitest_extension_whatsapp_paths import is_whats_app_extension_root
    from vitest_extension_zalo_paths import is_zalo_extension_root
    
    # Check which config to use
    uses_channel_config = any(root in channel_test_roots for root in roots)
    uses_acpx_config = any(is_acpx_extension_root(root) for root in roots)
    uses_diffs_config = any(is_diffs_extension_root(root) for root in roots)
    uses_blue_bubbles_config = any(is_blue_bubbles_extension_root(root) for root in roots)
    uses_feishu_config = any(is_feishu_extension_root(root) for root in roots)
    uses_irc_config = any(is_irc_extension_root(root) for root in roots)
    uses_mattermost_config = any(is_mattermost_extension_root(root) for root in roots)
    uses_telegram_config = any(is_telegram_extension_root(root) for root in roots)
    uses_voice_call_config = any(is_voice_call_extension_root(root) for root in roots)
    uses_whats_app_config = any(is_whats_app_extension_root(root) for root in roots)
    uses_zalo_config = any(is_zalo_extension_root(root) for root in roots)
    uses_matrix_config = any(is_matrix_extension_root(root) for root in roots)
    uses_memory_config = any(is_memory_extension_root(root) for root in roots)
    uses_ms_teams_config = any(is_ms_teams_extension_root(root) for root in roots)
    uses_messaging_config = any(is_messaging_extension_root(root) for root in roots)
    uses_provider_config = any(is_provider_extension_root(root) for root in roots)
    
    # Determine config file
    if uses_channel_config:
        config = "test/vitest/vitest.extension-channels.config.ts"
    elif uses_acpx_config:
        config = "test/vitest/vitest.extension-acpx.config.ts"
    elif uses_diffs_config:
        config = "test/vitest/vitest.extension-diffs.config.ts"
    elif uses_blue_bubbles_config:
        config = "test/vitest/vitest.extension-bluebubbles.config.ts"
    elif uses_feishu_config:
        config = "test/vitest/vitest.extension-feishu.config.ts"
    elif uses_irc_config:
        config = "test/vitest/vitest.extension-irc.config.ts"
    elif uses_mattermost_config:
        config = "test/vitest/vitest.extension-mattermost.config.ts"
    elif uses_matrix_config:
        config = "test/vitest/vitest.extension-matrix.config.ts"
    elif uses_telegram_config:
        config = "test/vitest/vitest.extension-telegram.config.ts"
    elif uses_voice_call_config:
        config = "test/vitest/vitest.extension-voice-call.config.ts"
    elif uses_whats_app_config:
        config = "test/vitest/vitest.extension-whatsapp.config.ts"
    elif uses_zalo_config:
        config = "test/vitest/vitest.extension-zalo.config.ts"
    elif uses_memory_config:
        config = "test/vitest/vitest.extension-memory.config.ts"
    elif uses_ms_teams_config:
        config = "test/vitest/vitest.extension-msteams.config.ts"
    elif uses_messaging_config:
        config = "test/vitest/vitest.extension-messaging.config.ts"
    elif uses_provider_config:
        config = "test/vitest/vitest.extension-providers.config.ts"
    else:
        config = "test/vitest/vitest.extensions.config.ts"
        
    # Count test files
    test_file_count = sum(
        count_test_files(repo_root / root) 
        for root in roots
    )
    
    return {
        "config": config,
        "extensionDir": relative_extension_dir,
        "extensionId": extension_id,
        "hasTests": test_file_count > 0,
        "roots": roots,
        "testFileCount": test_file_count,
    }


def merge_test_plans(plans: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Merge multiple test plans into groups by config"""
    groups_by_config = {}
    
    for plan in plans:
        config = plan["config"]
        if config not in groups_by_config:
            groups_by_config[config] = {
                "config": config,
                "extensionIds": [],
                "roots": [],
                "testFileCount": 0,
            }
            
        current = groups_by_config[config]
        current["extensionIds"].append(plan["extensionId"])
        current["roots"].extend(plan["roots"])
        current["testFileCount"] += plan["testFileCount"]
        
    # Process groups
    plan_groups = []
    for group in groups_by_config.values():
        # Remove duplicate roots and sort
        group["roots"] = sorted(list(set(group["roots"])))
        group["extensionIds"].sort()
        plan_groups.append(group)
        
    # Sort by config
    plan_groups.sort(key=lambda x: x["config"])
    
    # Sort all extension IDs
    all_extension_ids = []
    for plan in plans:
        all_extension_ids.append(plan["extensionId"])
    all_extension_ids.sort()
    
    return {
        "extensionCount": len(plans),
        "extensionIds": all_extension_ids,
        "hasTests": len(plans) > 0,
        "planGroups": plan_groups,
        "testFileCount": sum(plan["testFileCount"] for plan in plans),
    }


def resolve_extension_batch_plan(params: Dict[str, Any] = None) -> Dict[str, Any]:
    """Resolve batch test plan for multiple extensions"""
    if params is None:
        params = {}
        
    cwd = Path(params.get("cwd", Path.cwd()))
    extension_ids = params.get("extensionIds", list_available_extension_ids())
    
    plans = []
    for extension_id in extension_ids:
        plan = resolve_extension_test_plan({"cwd": cwd, "targetArg": extension_id})
        if plan["hasTests"]:
            plans.append(plan)
            
    return merge_test_plans(plans)


def pick_least_loaded_shard(shards: List[Dict[str, Any]]) -> int:
    """Pick the shard with the least load"""
    if not shards:
        return -1
        
    best_index = 0
    for i, shard in enumerate(shards):
        best = shards[best_index]
        if shard["testFileCount"] != best["testFileCount"]:
            if shard["testFileCount"] < best["testFileCount"]:
                best_index = i
            continue
        if len(shard["plans"]) != len(best["plans"]):
            if len(shard["plans"]) < len(best["plans"]):
                best_index = i
            continue
        if i < best_index:
            best_index = i
            
    return best_index


def create_extension_test_shards(params: Dict[str, Any] = None) -> List[Dict[str, Any]]:
    """Create test shards for extensions"""
    if params is None:
        params = {}
        
    cwd = Path(params.get("cwd", Path.cwd()))
    extension_ids = params.get("extensionIds", list_available_extension_ids())
    
    try:
        shard_count = max(1, int(params.get("shardCount", 1)))
    except (ValueError, TypeError):
        shard_count = 1
        
    # Get plans and sort by test file count (descending) then by extension ID
    plans = []
    for extension_id in extension_ids:
        plan = resolve_extension_test_plan({"cwd": cwd, "targetArg": extension_id})
        if plan["hasTests"]:
            plans.append(plan)
            
    plans.sort(key=lambda p: (-p["testFileCount"], p["extensionId"]))
    
    # Create shards
    effective_shard_count = min(shard_count, max(1, len(plans)))
    shards = [{"plans": [], "testFileCount": 0} for _ in range(effective_shard_count)]
    
    # Distribute plans to shards
    for plan in plans:
        target_index = pick_least_loaded_shard(shards)
        shards[target_index]["plans"].append(plan)
        shards[target_index]["testFileCount"] += plan["testFileCount"]
        
    # Format shards
    result_shards = []
    for i, shard in enumerate(shards):
        merged = merge_test_plans(shard["plans"])
        if merged["hasTests"]:
            result_shards.append({
                "index": i,
                "checkName": f"checks-node-extensions-shard-{i + 1}",
                **merged
            })
            
    return result_shards
