#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f653015f96cad568e820536daf3f622d7d66215e721e2952c0f64c690fc8c08e", "source_sha256": "e3a70dc12204181e113d6bd10329e4a0d699a4c3922e73906b5348e1fc3fd07a", "target_language": "python"}
# check-no-raw-channel-fetch.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-channel-fetch.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
from pathlib import Path
from typing import Set, List, Optional
import ast
import asyncio

# Import local modules
sys.path.append(str(Path(__file__).parent))
from lib.bundled_plugin_paths import bundled_plugin_callsite
from lib.callsite_guard import run_callsite_guard
from lib.ts_guard_utils import collect_call_expression_lines, run_as_script, unwrap_expression


source_roots = ["src/channels", "src/routing", "src/line", "extensions"]

# Temporary allowlist for legacy callsites. New raw fetch callsites in channel/plugin runtime
# code should be rejected and migrated to fetchWithSsrFGuard/shared channel helpers.
allowed_raw_fetch_callsites: Set[str] = {
    bundled_plugin_callsite("bluebubbles", "src/test-harness.ts", 128),
    bundled_plugin_callsite("bluebubbles", "src/types.ts", 181),
    bundled_plugin_callsite("browser", "src/browser/cdp.helpers.ts", 268),
    bundled_plugin_callsite("browser", "src/browser/client-fetch.ts", 192),
    bundled_plugin_callsite("browser", "src/browser/test-fetch.ts", 24),
    bundled_plugin_callsite("browser", "src/browser/test-fetch.ts", 27),
    bundled_plugin_callsite("chutes", "models.ts", 535),
    bundled_plugin_callsite("chutes", "models.ts", 542),
    bundled_plugin_callsite("discord", "src/monitor/gateway-plugin.ts", 322),
    bundled_plugin_callsite("discord", "src/monitor/gateway-plugin.ts", 360),
    bundled_plugin_callsite("discord", "src/voice-message.ts", 298),
    bundled_plugin_callsite("discord", "src/voice-message.ts", 333),
    bundled_plugin_callsite("elevenlabs", "speech-provider.ts", 295),
    bundled_plugin_callsite("elevenlabs", "tts.ts", 116),
    bundled_plugin_callsite("feishu", "src/monitor.webhook.test-helpers.ts", 25),
    bundled_plugin_callsite("github-copilot", "login.ts", 48),
    bundled_plugin_callsite("github-copilot", "login.ts", 80),
    bundled_plugin_callsite("googlechat", "src/auth.ts", 83),
    bundled_plugin_callsite("huggingface", "models.ts", 142),
    bundled_plugin_callsite("kilocode", "provider-models.ts", 130),
    bundled_plugin_callsite("matrix", "src/matrix/sdk/transport.ts", 112),
    bundled_plugin_callsite("microsoft-foundry", "onboard.ts", 479),
    bundled_plugin_callsite("microsoft", "speech-provider.ts", 132),
    bundled_plugin_callsite("minimax", "oauth.ts", 66),
    bundled_plugin_callsite("minimax", "oauth.ts", 107),
    bundled_plugin_callsite("minimax", "tts.ts", 52),
    bundled_plugin_callsite("msteams", "src/graph.ts", 47),
    bundled_plugin_callsite("msteams", "src/sdk.ts", 329),
    bundled_plugin_callsite("msteams", "src/sdk.ts", 370),
    bundled_plugin_callsite("ollama", "src/stream.ts", 649),
    bundled_plugin_callsite("openai", "tts.ts", 133),
    bundled_plugin_callsite("qa-channel", "src/bus-client.ts", 41),
    bundled_plugin_callsite("qa-channel", "src/bus-client.ts", 221),
    bundled_plugin_callsite("qa-lab", "src/docker-up.runtime.ts", 274),
    bundled_plugin_callsite("qa-lab", "src/gateway-child.ts", 489),
    bundled_plugin_callsite("qa-lab", "src/suite.ts", 330),
    bundled_plugin_callsite("qa-lab", "src/suite.ts", 341),
    bundled_plugin_callsite("qa-lab", "web/src/app.ts", 15),
    bundled_plugin_callsite("qa-lab", "web/src/app.ts", 23),
    bundled_plugin_callsite("qa-lab", "web/src/app.ts", 31),
    bundled_plugin_callsite("qqbot", "src/api.ts", 102),
    bundled_plugin_callsite("qqbot", "src/api.ts", 237),
    bundled_plugin_callsite("qqbot", "src/stt.ts", 81),
    bundled_plugin_callsite("qqbot", "src/tools/channel.ts", 180),
    bundled_plugin_callsite("qqbot", "src/utils/audio-convert.ts", 377),
    bundled_plugin_callsite("signal", "src/install-signal-cli.ts", 224),
    bundled_plugin_callsite("slack", "src/monitor/media.ts", 96),
    bundled_plugin_callsite("slack", "src/monitor/media.ts", 115),
    bundled_plugin_callsite("slack", "src/monitor/media.ts", 120),
    bundled_plugin_callsite("tlon", "src/tlon-api.ts", 185),
    bundled_plugin_callsite("tlon", "src/tlon-api.ts", 235),
    bundled_plugin_callsite("tlon", "src/tlon-api.ts", 289),
    bundled_plugin_callsite("venice", "models.ts", 552),
    bundled_plugin_callsite("vercel-ai-gateway", "models.ts", 181),
    bundled_plugin_callsite("voice-call", "src/providers/twilio/api.ts", 23),
}


def is_raw_fetch_call(expression: ast.expr) -> bool:
    """Check if the expression represents a raw fetch call"""
    callee = unwrap_expression(expression)
    
    # Check for simple identifier 'fetch'
    if isinstance(callee, ast.Name):
        return callee.id == "fetch"
    
    # Check for property access like globalThis.fetch
    if isinstance(callee, ast.Attribute):
        return (
            isinstance(callee.value, ast.Name) and
            callee.value.id == "globalThis" and
            callee.attr == "fetch"
        )
    
    return False


def find_raw_fetch_call_lines(content: str, file_name: str = "source.ts") -> List[int]:
    """Find line numbers where raw fetch calls occur in TypeScript content"""
    try:
        # Parse the TypeScript-like content with AST
        tree = ast.parse(content)
        
        def extract_fetch_expressions(node):
            """Extract fetch expressions from AST nodes"""
            if isinstance(node, ast.Call) and is_raw_fetch_call(node.func):
                return node.func
            return None
        
        return collect_call_expression_lines(tree, extract_fetch_expressions)
    except SyntaxError:
        # If parsing fails, return empty list (similar to TypeScript behavior)
        return []


async def main():
    """Main entry point"""
    await run_callsite_guard(
        source_roots=source_roots,
        extra_test_suffixes=[".browser.test.ts", ".node.test.ts"],
        find_call_lines=find_raw_fetch_call_lines,
        allow_callsite=lambda callsite: callsite in allowed_raw_fetch_callsites,
        header="Found raw fetch() usage in channel/plugin runtime sources outside allowlist:",
        footer="Use fetchWithSsrFGuard() or existing channel/plugin SDK wrappers for network calls."
    )


if __name__ == "__main__":
    run_as_script(main())
