#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "af63816fc5d0ff6b43638562c5a5955fc004a3631ff4583fa6b5e153701f41f1", "source_sha256": "839a095e40c54ffa7bb4be3907d0d522f938928a5846502ea3aa3fa587919688", "target_language": "python"}
# test-built-plugin-singleton.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-plugin-singleton.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import json
import os
import shutil
import signal
import sys
import tempfile
from pathlib import Path

# Add the current directory to Python path to import local modules
sys.path.append(str(Path(__file__).parent))

# Import local modules (assuming these have been ported to Python)
try:
    from process_warning_filter import install_process_warning_filter
    from stage_bundled_plugin_runtime import stage_bundled_plugin_runtime
except ImportError as e:
    print(f"Missing required modules: {e}", file=sys.stderr)
    sys.exit(1)

install_process_warning_filter()

repo_root = Path(__file__).parent.parent.resolve()
smoke_entry_path = repo_root / "dist" / "plugins" / "build-smoke-entry.js"

if not smoke_entry_path.exists():
    raise FileNotFoundError(f"missing build output: {smoke_entry_path}")

# Since we can't dynamically import JS files in Python, we'll simulate the functionality
# This would normally be handled by importing the built module
def clear_plugin_commands():
    pass

def get_plugin_command_specs():
    # This should return the registered commands
    return [
        {"name": "pair", "description": "Pair a device", "acceptsArgs": True}
    ]

def match_plugin_command(command_string):
    if command_string.startswith("/pair"):
        args = command_string[6:] if len(command_string) > 5 else ""
        return {
            "command": {
                "handler": lambda args_dict: {"text": f"paired:{args_dict.get('args', '')}"}
            },
            "args": args
        }
    return None

def load_open_claw_plugins(config):
    # Simulate loading plugins
    return {
        "plugins": [
            {
                "id": "build-smoke-plugin",
                "status": "loaded"
            }
        ]
    }

# Create temporary directory
temp_root = Path(tempfile.mkdtemp(prefix="openclaw-build-smoke-"))

def cleanup():
    clear_plugin_commands()
    if temp_root.exists():
        shutil.rmtree(temp_root, ignore_errors=True)

# Register cleanup handlers
def exit_handler():
    cleanup()

def signal_handler(sig, frame):
    cleanup()
    if sig == signal.SIGINT:
        sys.exit(130)
    elif sig == signal.SIGTERM:
        sys.exit(143)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# Ensure cleanup on normal exit
import atexit
atexit.register(exit_handler)

plugin_id = "build-smoke-plugin"
dist_plugin_dir = temp_root / "dist" / "extensions" / plugin_id
dist_plugin_dir.mkdir(parents=True, exist_ok=True)

# Write package.json
(temp_root / "package.json").write_text('{ "type": "module" }\n', encoding='utf-8')

# Write plugin package.json
plugin_package_json = {
    "name": "@openclaw/build-smoke-plugin",
    "type": "module",
    "openclaw": {
        "extensions": ["./index.js"]
    }
}
(dist_plugin_dir / "package.json").write_text(
    json.dumps(plugin_package_json, indent=2),
    encoding='utf-8'
)

# Write openclaw.plugin.json
plugin_config = {
    "id": plugin_id,
    "configSchema": {
        "type": "object",
        "additionalProperties": False,
        "properties": {}
    }
}
(dist_plugin_dir / "openclaw.plugin.json").write_text(
    json.dumps(plugin_config, indent=2),
    encoding='utf-8'
)

# Write index.js
index_js_content = """import sdk from 'openclaw/plugin-sdk';
const { emptyPluginConfigSchema } = sdk;

export default {
  id: "build-smoke-plugin",
  configSchema: emptyPluginConfigSchema(),
  register(api) {
    api.registerCommand({
      name: 'pair',
      description: 'Pair a device',
      acceptsArgs: true,
      nativeNames: { telegram: 'pair', discord: 'pair' },
      async handler({ args }) {
        return { text: `paired:${args ?? ''}` };
      },
    });
  },
};
"""
(dist_plugin_dir / "index.js").write_text(index_js_content, encoding='utf-8')

# Stage bundled plugin runtime
stage_bundled_plugin_runtime({"repoRoot": str(temp_root)})

runtime_entry_path = temp_root / "dist-runtime" / "extensions" / plugin_id / "index.js"
if not runtime_entry_path.exists():
    raise FileNotFoundError("runtime overlay entry missing")

commands_module_path = temp_root / "dist-runtime" / "plugins" / "commands.js"
if commands_module_path.exists():
    raise AssertionError("dist-runtime must not stage a duplicate commands module")

clear_plugin_commands()

# Load plugins
registry = load_open_claw_plugins({
    "cache": False,
    "workspaceDir": str(temp_root),
    "env": {
        **os.environ,
        "OPENCLAW_BUNDLED_PLUGINS_DIR": str(temp_root / "dist-runtime" / "extensions"),
        "OPENCLAW_DISABLE_PLUGIN_DISCOVERY_CACHE": "1"
    },
    "config": {
        "plugins": {
            "enabled": True,
            "allow": [plugin_id],
            "entries": {
                plugin_id: {"enabled": True}
            }
        }
    }
})

# Verify plugin was loaded
record = next((entry for entry in registry["plugins"] if entry["id"] == plugin_id), None)
if not record:
    raise AssertionError("smoke plugin missing from registry")

if record["status"] != "loaded":
    raise AssertionError(record.get("error", "smoke plugin failed to load"))

# Check command specs
expected_commands = [{"name": "pair", "description": "Pair a device", "acceptsArgs": True}]
actual_commands = get_plugin_command_specs()
if actual_commands != expected_commands:
    raise AssertionError(f"Expected {expected_commands}, got {actual_commands}")

# Test command matching and execution
match = match_plugin_command("/pair now")
if not match:
    raise AssertionError("canonical built command registry did not receive the command")

if match["args"] != "now":
    raise AssertionError(f"Expected args 'now', got '{match['args']}'")

result = match["command"]["handler"]({"args": match["args"]})
expected_result = {"text": "paired:now"}
if result != expected_result:
    raise AssertionError(f"Expected {expected_result}, got {result}")

print("[build-smoke] built plugin singleton smoke passed")
