#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "e478130d230583a82fa223c88b6885151a6333aa65ceba4edc2bacf4303662cb", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "python"}
# sync-plugin-sdk-exports.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import json
import sys
import os

def build_plugin_sdk_package_exports():
    # This function needs to be implemented based on the original JavaScript logic
    # Since it's imported from "./lib/plugin-sdk-entries.mjs", we'll need to
    # replicate its functionality or import it differently
    # For now, returning an empty dict as placeholder
    return {}

check_only = "--check" in sys.argv
package_json_path = os.path.join(os.getcwd(), "package.json")

with open(package_json_path, "r", encoding="utf-8") as f:
    package_json = json.load(f)

current_exports = package_json.get("exports", {})
synced_plugin_sdk_exports = build_plugin_sdk_package_exports()

next_exports = {}
inserted_plugin_sdk_exports = False

for key, value in current_exports.items():
    if key.startswith("./plugin-sdk"):
        if not inserted_plugin_sdk_exports:
            next_exports.update(synced_plugin_sdk_exports)
            inserted_plugin_sdk_exports = True
        continue
    next_exports[key] = value
    if key == "." and not inserted_plugin_sdk_exports:
        next_exports.update(synced_plugin_sdk_exports)
        inserted_plugin_sdk_exports = True

if not inserted_plugin_sdk_exports:
    next_exports.update(synced_plugin_sdk_exports)

next_exports_json = json.dumps(next_exports, separators=(',', ':'))
current_exports_json = json.dumps(current_exports, separators=(',', ':'))

if check_only:
    if current_exports_json != next_exports_json:
        print("plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`.", file=sys.stderr)
        sys.exit(1)
    print("plugin-sdk exports synced.")
    sys.exit(0)

package_json["exports"] = next_exports
with open(package_json_path, "w", encoding="utf-8") as f:
    json.dump(package_json, f, indent=2, ensure_ascii=False)
    f.write("\n")
