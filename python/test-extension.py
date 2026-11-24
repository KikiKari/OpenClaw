#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8cf66285f706fd272201c07bc79c25a36ed93738f325f6f8fb32cda4f1320e35", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "python"}
# test-extension.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import subprocess
from pathlib import Path

# Importiere die entsprechenden Module
# Da es sich um eine Portierung handelt, müssen wir annehmen, 
# dass diese Module ebenfalls in Python verfügbar sind
try:
    from lib.error_format import format_error_message
    from lib.extension_test_plan import resolve_extension_test_plan
    from lib.vitest_batch_runner import is_direct_script_run, run_vitest_batch
except ImportError as e:
    print(f"Fehler beim Importieren der Module: {e}", file=sys.stderr)
    sys.exit(1)

def print_usage():
    print("Usage: pnpm test:extension <extension-name|path> [vitest args...]", file=sys.stderr)
    print("       python scripts/test-extension.py [extension-name|path] [vitest args...]", file=sys.stderr)

def print_no_tests_message(plan):
    print(f"[test-extension] No tests found for {plan['extensionDir']}. Skipping.")

async def run():
    raw_args = sys.argv[1:]
    
    if "--help" in raw_args or "-h" in raw_args:
        print_usage()
        return

    passthrough_args = [arg for arg in raw_args if arg != "--"]
    
    target_arg = None
    if passthrough_args and not passthrough_args[0].startswith("-"):
        target_arg = passthrough_args.pop(0)

    try:
        plan = resolve_extension_test_plan({"cwd": os.getcwd(), "targetArg": target_arg})
    except Exception as error:
        print_usage()
        print(format_error_message(error), file=sys.stderr)
        sys.exit(1)

    if not plan.get("hasTests", False):
        print_no_tests_message(plan)
        return

    extension_id = plan.get("extensionId", "unknown")
    test_file_count = plan.get("testFileCount", 0)
    print(f"[test-extension] Running {test_file_count} test files for {extension_id}")
    
    exit_code = await run_vitest_batch({
        "args": passthrough_args,
        "config": plan.get("config"),
        "env": os.environ.copy(),
        "targets": plan.get("roots", [])
    })
    
    sys.exit(exit_code)

if __name__ == "__main__":
    if is_direct_script_run(__file__):
        import asyncio
        asyncio.run(run())
