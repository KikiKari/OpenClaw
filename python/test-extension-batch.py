#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "c784747d620aa9d7e78927cb5b9a24365a309babde76d88909d3e39e0bb431e2", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "python"}
# test-extension-batch.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import sys
import os
from pathlib import Path
from lib.extension_test_plan import resolve_extension_batch_plan
from lib.vitest_batch_runner import is_direct_script_run, run_vitest_batch


def print_usage():
    print("Usage: pnpm test:extensions:batch <extension[,extension...]> [vitest args...]", file=sys.stderr)
    print("       node scripts/test-extension-batch.mjs <extension[,extension...]> [vitest args...]", file=sys.stderr)


def parse_extension_ids(raw_args):
    args = list(raw_args)
    extension_ids = []

    while args and not args[0].startswith("-"):
        extension_ids.extend(
            filter(None, map(str.strip, args.pop(0).split(",")))
        )

    return {"extension_ids": extension_ids, "passthrough_args": args}


async def run():
    raw_args = sys.argv[1:]
    if "--help" in raw_args or "-h" in raw_args:
        print_usage()
        return

    passthrough_args = [arg for arg in raw_args if arg != "--"]
    parsed = parse_extension_ids(passthrough_args)
    extension_ids = parsed["extension_ids"]
    vitest_args = parsed["passthrough_args"]

    if len(extension_ids) == 0:
        print_usage()
        sys.exit(1)

    batch_plan = resolve_extension_batch_plan({"cwd": os.getcwd(), "extension_ids": extension_ids})
    if not batch_plan["has_tests"]:
        print("[test-extension-batch] No tests found for the requested extensions. Skipping.")
        return

    print(f"[test-extension-batch] Running {batch_plan['test_file_count']} test files across {batch_plan['extension_count']} extensions")

    for group in batch_plan["plan_groups"]:
        print(f"[test-extension-batch] {group['config']}: {', '.join(group['extension_ids'])} ({group['test_file_count']} files)")
        exit_code = await run_vitest_batch({
            "args": vitest_args,
            "config": group["config"],
            "env": os.environ.copy(),
            "targets": group["roots"]
        })
        if exit_code != 0:
            sys.exit(exit_code)


if __name__ == "__main__":
    if is_direct_script_run(__file__):
        import asyncio
        asyncio.run(run())
